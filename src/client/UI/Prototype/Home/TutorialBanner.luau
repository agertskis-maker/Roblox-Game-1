--!strict
-- Home HUD: the tutorial banner (Lane 3, BRIEF M11-02, restyled 2026-11-01 from the placeholder objective banner).
--
-- Look (reference: references/hud-tutorial-reference.png, in the Arcade kit): a dark rounded pill with the thick dark
-- boundary and a shallow lip. Left: the step's icon (a kid who cannot read follows the picture). Centre: a big yellow
-- headline of 2 to 4 words with the heavy dark outline, and under it ONE green instruction stripe with white outlined
-- text. Right: an optional small counter ("1/2") or the device's control legend (key caps / drag / tap), so the legend never
-- sits anywhere near the run's Heat bar, Keys ring or Hop button. A thin strip along the bottom shows the WHOLE tutorial's
-- progress. A 48 px Skip button sits beside the pill (inside the footprint Home/Layout reserves for the banner, so the
-- Mission tracker's room maths still holds). A new step slides in; a finished step shows a green check, plays the chime
-- (Sounds "TutorialDone") and, for big moments, a bounded confetti burst (16 pieces, none in reduced motion).
--
-- Contract: the banner draws store.tutorial and nothing else; it grants nothing and never writes the store. The fields it
-- reads (older fixtures without the optional ones still work):
--   step (1 based), steps, objective (the headline), count / goal (the small counter when `counterText` is nil and goal > 1),
--   hint (a small floating note under the banner), state "Active" | "Hint" | "Done" (Done: green check, chime, the pill keeps
--   the headline and stripe it is given),
--   icons: { string }? (icon names to try), instruction: string? (the green stripe), counterText: string?,
--   controls: { kind: "Steer" | "Hop", device: "Keyboard" | "Touch" | "Gamepad", left: boolean?, right: boolean? }?,
--   big: boolean? (confetti when done)
--
-- Placement: "Home" (top centre from Home/Layout) or "Run" (compact: just under the run's distance pill, clear of the
-- protected road view). Run placement is checked against the run's Heat, Hop and Keys rectangles (getDebugState().runOverlap).
--
-- API: TutorialBanner.new(ctx, { onDoneShown: ((step: number) -> ())?, onSkip: (() -> ())? }?) -> TutorialBanner
--   :layout()  :setVisible(on)  :setPlacement("Home" | "Run")  :wiggle()  :getSkipButton() -> GuiObject
--   :setSkipHandler(fn?)  (shows or hides the Skip button; the tutorial controller sets it)  :celebrate()  (a confetti burst)
--   :setPinned(on)  (while pinned, setVisible(false) is ignored: the banner shows in Home, Run and Results)
--   :getRect() -> (pos, size) in device px  :destroy()  :getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Arcade = require(script.Parent.Parent.Arcade)
local Fade = require(script.Parent.Fade)
local IconArt = require(script.Parent.IconArt)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local A = PreviewTokens.Arcade
local B = A.Button

local DONE_SECONDS = 1.6 -- only for the optional onDoneShown callback (the tutorial controller owns its own timing)
local CONFETTI = 16
local CONFETTI_SECONDS = 0.9
local MIN_TEXT = Tokens.TextSize.Minimum
local GAP = 8
local PILL = Color3.fromRGB(24, 28, 42)
local CAP_FILL = Color3.fromRGB(246, 248, 255)
local CAP_DONE = Color3.fromRGB(110, 224, 130)
local CONFETTI_COLOURS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(90, 190, 255),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(170, 130, 255),
}

type Variant = {
	pad: number,
	icon: number,
	head: number,
	headMax: number,
	headMin: number,
	stripe: number,
	stripeText: number,
	progress: number,
	skipW: number,
	skipH: number,
	cap: number,
}
local FULL: Variant = {
	pad = 10,
	icon = 56,
	head = 40,
	headMax = 32,
	headMin = 22,
	stripe = 26,
	stripeText = 18,
	progress = 6,
	skipW = 64,
	skipH = 48,
	cap = 34,
}
local COMPACT: Variant = {
	pad = 4,
	icon = 38,
	head = 24,
	headMax = 22,
	headMin = 18,
	stripe = 20,
	stripeText = 16,
	progress = 3,
	skipW = 48,
	skipH = 44,
	cap = 26,
}

export type Options = { onDoneShown: ((step: number) -> ())?, onSkip: (() -> ())? }

export type TutorialBanner = {
	root: Frame,
	layout: (self: TutorialBanner) -> (),
	setVisible: (self: TutorialBanner, on: boolean) -> (),
	setPlacement: (self: TutorialBanner, placement: string) -> (),
	wiggle: (self: TutorialBanner) -> (),
	getSkipButton: (self: TutorialBanner) -> GuiObject,
	celebrate: (self: TutorialBanner) -> (),
	setSkipHandler: (self: TutorialBanner, handler: (() -> ())?) -> (),
	setPinned: (self: TutorialBanner, pinned: boolean) -> (),
	getRect: (self: TutorialBanner) -> (Vector2, Vector2),
	destroy: (self: TutorialBanner) -> (),
	getDebugState: (self: TutorialBanner) -> { [string]: any },
}

local TutorialBanner = {}
TutorialBanner.__index = TutorialBanner

local function measure(text: string, size: number, width: number?): Vector2
	return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(width or 4096, 4096))
end

local function view(t: Store.Tutorial?): { [string]: any }?
	return t :: any
end

local function counterOf(v: { [string]: any }): string
	local text = v.counterText
	if type(text) == "string" and text ~= "" then
		return text
	end
	local goal = if type(v.goal) == "number" then v.goal else 0
	local count = if type(v.count) == "number" then v.count else 0
	if goal > 1 then
		if v.state == "Done" then
			count = goal
		end
		return string.format("%d/%d", math.clamp(count, 0, goal), goal)
	end
	return ""
end

function TutorialBanner.new(ctx: Types.Ctx, opts: Options?): TutorialBanner
	local self = setmetatable({}, TutorialBanner) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._opts = opts or {}
	self._destroyed = false
	self._placement = "Home"
	self._variant = FULL
	self._pillW = 300
	self._bodyH = 92
	self._groupW = 400
	self._view = nil :: { [string]: any }?
	self._doneToken = 0
	self._wanted = true
	self._pinned = false
	self._progress = 0
	self._wiggles = 0
	self._headSize = FULL.headMax
	self._runOverlap = {} :: { string }
	local make = Arcade.make

	local root = trove:Add(make("Frame", {
		Name = "TutorialBanner",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(400, 120),
		Visible = false,
		ZIndex = 5,
		Parent = ctx.layer,
	}))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale(), Parent = root })

	local all = make("Frame", {
		Name = "All",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = root,
	})
	self._all = all

	-- the pill: a shallow lip, then the dark body
	local lip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, B.DepthOffset),
		Size = UDim2.fromOffset(300, 92),
		BackgroundColor3 = A.Ink,
		ZIndex = 5,
		Parent = all,
	})
	Arcade.corner(lip, 24)
	self._lip = lip
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.fromOffset(300, 92),
		BackgroundColor3 = PILL,
		BackgroundTransparency = 0.06,
		ZIndex = 6,
		Parent = all,
	})
	Arcade.corner(body, 24)
	Arcade.outline(body, "Button")
	Arcade.gloss(body)
	self._body = body

	-- content that crossfades on a new step
	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = body,
	})
	self._content = content
	local iconHolder = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(FULL.icon, FULL.icon),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = content,
	})
	self._iconHolder = iconHolder
	-- the done check: a green disc that replaces the icon
	local check = make("Frame", {
		Name = "Check",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(FULL.icon, FULL.icon),
		BackgroundColor3 = Color3.fromRGB(30, 170, 70),
		Visible = false,
		ZIndex = 9,
		Parent = content,
	})
	Arcade.corner(check, 100)
	Arcade.outline(check, 2, Color3.new(1, 1, 1))
	local checkArt = make("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = check,
	})
	IconArt.draw(checkArt, { "Check" })
	self._check = check

	local headline = Arcade.text(content, {
		text = "",
		role = "Display",
		name = "Headline",
		face = "Keys",
		outline = "Major",
		xAlign = Enum.TextXAlignment.Left,
		z = 9,
	})
	headline.TextWrapped = true
	self._headline = headline
	local stripe = make("Frame", {
		Name = "Stripe",
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 9,
		Parent = content,
	})
	Arcade.corner(stripe, 8)
	Arcade.outline(stripe, "Minor")
	make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = stripe })
	self._stripe = stripe
	local stripeText = Arcade.text(stripe, {
		text = "",
		role = "Label",
		name = "Text",
		size = FULL.stripeText,
		z = 10,
	})
	stripeText.Size = UDim2.fromScale(1, 1)
	stripeText.TextWrapped = true
	self._stripeText = stripeText
	local counter = Arcade.text(content, {
		text = "",
		role = "Label",
		name = "Counter",
		italic = true,
		xAlign = Enum.TextXAlignment.Right,
		z = 9,
	})
	self._counter = counter
	local legend = make("Frame", {
		Name = "Legend",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(80, 36),
		Visible = false,
		ZIndex = 9,
		Parent = content,
	})
	self._legend = legend
	self._caps = {} :: { [string]: Frame }

	-- the whole-tutorial progress strip
	local track = make("Frame", {
		Name = "Strip",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.35,
		ZIndex = 9,
		Parent = body,
	})
	Arcade.corner(track, 4)
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 10,
		Parent = track,
	})
	Arcade.corner(fill, 4)
	make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = fill })
	self._track = track
	self._fill = fill

	-- the Skip button: a dark-ringed blue pill 44 px or taller, beside the banner
	local skipHolder = make("Frame", {
		Name = "SkipHolder",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(FULL.skipW, FULL.skipH),
		ZIndex = 7,
		Parent = all,
	})
	local skipLip = make("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, B.DepthOffset),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Ink,
		ZIndex = 7,
		Parent = skipHolder,
	})
	Arcade.corner(skipLip, 12)
	local skip: TextButton = make("TextButton", {
		Name = "Skip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 8,
		Parent = skipHolder,
	})
	Arcade.corner(skip, 12)
	-- a button defaults to a text outline: this one outlines the body
	Arcade.outline(skip, "Button").ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	make("UIGradient", { Color = A.Fill.Garage, Rotation = 90, Parent = skip })
	local skipLabel = Arcade.text(skip, { text = "Skip", role = "Label", name = "Text", z = 9 })
	skipLabel.Size = UDim2.fromScale(1, 1)
	self._skipHolder = skipHolder
	self._skip = skip
	self._skipLabel = skipLabel
	skip.Visible = self._opts.onSkip ~= nil
	skipLip.Visible = skip.Visible
	self._skipLip = skipLip
	trove:Connect(skip.Activated, function()
		local cb = self._opts.onSkip
		if cb then
			Sounds.play("Tap")
			cb()
		end
	end)
	trove:Connect(skip.InputBegan, function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Motion.press(skip, true)
		end
	end)
	trove:Connect(skip.InputEnded, function()
		Motion.press(skip, false)
	end)

	-- micro-hint: floating outlined text under the banner (kept for older fixtures and for short notes)
	local hint = make("Frame", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(200, Layout.HintHeight),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = all,
	})
	local hintText = Arcade.text(hint, { text = "", role = "Small", name = "Text", z = 7 })
	hintText.Size = UDim2.fromScale(1, 1)
	hintText.TextWrapped = true
	self._hint = hint
	self._hintText = hintText

	self._hintFade = Fade.capture(hint)
	self._contentFade = Fade.capture(content)
	self._allFade = Fade.capture(all)
	trove:Add(function()
		if self._doneThread then
			pcall(task.cancel, self._doneThread)
			self._doneThread = nil
		end
		self._hintFade:destroy()
		self._contentFade:destroy()
		self._allFade:destroy()
		Motion.cancelAll(content)
		Motion.cancelAll(fill)
		Motion.cancelAll(all)
		Motion.cancelAll(stripe)
		Motion.cancelAll(skip)
	end)

	self._confetti = {} :: { Frame }
	for i = 1, CONFETTI do
		local piece = make("Frame", {
			Name = "Confetti" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 2 == 0 then 8 else 6, if i % 2 == 0 then 5 else 9),
			BackgroundColor3 = CONFETTI_COLOURS[(i - 1) % #CONFETTI_COLOURS + 1],
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 12,
			Parent = root,
		})
		Arcade.corner(piece, 2)
		table.insert(self._confetti, piece)
	end
	trove:Add(function()
		for _, piece in self._confetti do
			Motion.cancelAll(piece)
		end
	end)

	trove:Add(ctx.store:subscribe("tutorial", function(t: Store.Tutorial?)
		self:_set(t)
	end))
	trove:Add(Motion.onReducedChanged(function(reduced: boolean)
		if reduced then
			self:_stopConfetti()
			Motion.cancelAll(content)
			Motion.cancelAll(all)
			content.Position = UDim2.new()
			all.Rotation = 0
		end
	end))
	trove:Connect(ctx.screen.Changed, function()
		self:layout()
	end)
	self:layout()
	self:_set(ctx.store:get().tutorial)
	return self :: TutorialBanner
end

-- LEGEND (key caps, drag, tap) ------------------------------------------------------------------------------------

local function cap(parent: Frame, name: string, text: string, w: number, h: number, x: number): Frame
	local f = Arcade.make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = CAP_FILL,
		ZIndex = 10,
		Parent = parent,
	})
	Arcade.corner(f, 7)
	Arcade.outline(f, "Button")
	local t = Arcade.text(f, { text = text, role = "Label", name = "Text", colour = A.Ink, outline = 1, z = 11 })
	t.Size = UDim2.fromScale(1, 1)
	t.TextSize = math.max(MIN_TEXT, math.min(h - 10, 18))
	-- a ghost check in the corner when this direction is done (colour is never the only signal)
	local tick = Arcade.make("Frame", {
		Name = "Tick",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 12,
		Parent = f,
	})
	IconArt.draw(tick, { "Check" })
	return f
end

function TutorialBanner._buildLegend(self: any, spec: { [string]: any }?)
	local legend: Frame = self._legend
	for _, child in legend:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(self._caps)
	if not spec then
		legend.Visible = false
		self._legendW = 0
		return
	end
	local v: Variant = self._variant
	local h = v.cap
	local device = spec.device
	local width = 0
	if spec.kind == "Steer" then
		local left = if device == "Keyboard" then "A" else "<"
		local right = if device == "Keyboard" then "D" else ">"
		self._caps.left = cap(legend, "Left", left, h, h, 0)
		self._caps.right = cap(legend, "Right", right, h, h, h + 6)
		width = 2 * h + 6
	else
		local text = if device == "Keyboard" then "Space" elseif device == "Touch" then "Tap" else "A"
		local w = if device == "Keyboard" then h * 2 else h + 8
		self._caps.hop = cap(legend, "Hop", text, w, h, 0)
		width = w
	end
	legend.Size = UDim2.fromOffset(width, h)
	legend.Visible = true
	self._legendW = width
	self:_refreshLegend(spec)
end

function TutorialBanner._refreshLegend(self: any, spec: { [string]: any }?)
	if not spec then
		return
	end
	local function mark(name: string, done: boolean?)
		local c: Frame? = self._caps[name]
		if c then
			c.BackgroundColor3 = if done then CAP_DONE else CAP_FILL
			local tick = c:FindFirstChild("Tick") :: Frame?
			if tick then
				tick.Visible = done == true
			end
		end
	end
	mark("left", spec.left)
	mark("right", spec.right)
	mark("hop", spec.done)
end

-- LAYOUT ----------------------------------------------------------------------------------------------------------

-- Fits the headline into its width: the largest size that stays on one line, else the smallest size on two lines.
local function fitHeadline(text: string, v: Variant, width: number): (number, number)
	local size = v.headMax
	while size >= v.headMin do
		if measure(text, size).X + 12 <= width then
			return size, 1
		end
		size -= 2
	end
	return v.headMin, 2
end

function TutorialBanner._arrange(self: any)
	local v: Variant = self._variant
	local pillW: number = self._pillW
	local viewNow = self._view
	local headText = if viewNow and type(viewNow.objective) == "string" then viewNow.objective else ""
	local lineText = if viewNow and type(viewNow.instruction) == "string" then viewNow.instruction else ""
	local counterText = if viewNow then counterOf(viewNow) else ""
	local textX = v.pad + v.icon + GAP
	local rightW = 0
	if self._legendW and self._legendW > 0 then
		rightW = self._legendW + GAP
	elseif counterText ~= "" then
		rightW = math.ceil(measure(counterText, A.Text.Label).X) + 16
	end
	local textW = pillW - textX - v.pad - rightW
	local size, lines = fitHeadline(headText, v, textW)
	self._headSize = size
	local headH = if lines == 2 then size * 2 + 6 else math.max(v.head, size + 4)
	local stripeVisible = lineText ~= ""
	local stripeW = pillW - textX - v.pad
	local stripeLines = 1
	local stripeH = v.stripe
	if stripeVisible then
		local wrapped = measure(lineText, v.stripeText, stripeW - 16)
		stripeLines = math.max(1, math.round(wrapped.Y / (v.stripeText * 1.2)))
		stripeH = math.max(v.stripe, stripeLines * (v.stripeText + 2) + 8)
	end
	local top = v.pad
	local bodyH = top + headH + (if stripeVisible then 2 + stripeH else 0) + 4 + v.progress + (v.pad - 1)
	bodyH = math.max(bodyH, v.icon + 2 * v.pad)
	self._bodyH = bodyH

	local headline: TextLabel = self._headline
	headline.TextSize = size
	headline.Position = UDim2.fromOffset(textX, top)
	headline.Size = UDim2.fromOffset(textW, headH)
	headline.TextYAlignment = Enum.TextYAlignment.Center
	local stripe: Frame = self._stripe
	stripe.Visible = stripeVisible
	stripe.Position = UDim2.fromOffset(textX, top + headH + 2)
	stripe.Size = UDim2.fromOffset(stripeW, stripeH)
	local stripeLabel: TextLabel = self._stripeText
	stripeLabel.TextSize = v.stripeText
	stripeLabel.Text = lineText
	local iconY = (bodyH - v.progress - 4) / 2
	self._iconHolder.Position = UDim2.fromOffset(v.pad, iconY)
	self._iconHolder.Size = UDim2.fromOffset(v.icon, v.icon)
	self._check.Position = UDim2.fromOffset(v.pad, iconY)
	self._check.Size = UDim2.fromOffset(v.icon, v.icon)

	local counter: TextLabel = self._counter
	counter.Visible = counterText ~= "" and not (self._legendW and self._legendW > 0)
	counter.TextSize = A.Text.Label
	counter.Position = UDim2.fromOffset(pillW - v.pad - rightW, top)
	counter.Size = UDim2.fromOffset(rightW, headH)
	local legend: Frame = self._legend
	legend.Position = UDim2.fromOffset(pillW - v.pad, top + headH / 2)

	self._body.Size = UDim2.fromOffset(pillW, bodyH)
	self._lip.Size = UDim2.fromOffset(pillW, bodyH)
	self._track.Position = UDim2.fromOffset(textX, bodyH - v.progress - 6)
	self._track.Size = UDim2.fromOffset(pillW - textX - v.pad, v.progress)

	-- Skip: beside the pill, top aligned
	self._skipHolder.Size = UDim2.fromOffset(v.skipW, v.skipH)
	self._skipHolder.Position = UDim2.fromOffset(pillW + GAP + v.skipW, 0)
	self._skipLabel.TextSize = math.max(MIN_TEXT, if v == FULL then 18 else 16)

	local hintTextValue = self._hintText.Text
	local hintW = math.min(self._groupW, math.ceil(measure(hintTextValue, A.Text.Small).X) + 24)
	self._hint.Size = UDim2.fromOffset(hintW, Layout.HintHeight)
	self._hint.Position = UDim2.fromOffset(pillW / 2, bodyH + B.DepthOffset + Layout.HintGap)
	self.root.Size = UDim2.fromOffset(self._groupW, bodyH + B.DepthOffset + Layout.HintGap + Layout.HintHeight)
end

function TutorialBanner.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local home = Layout.forProfile(ctx.screen:profile(), scale)
	local b = home.banner
	if self._placement == "Run" then
		self._variant = COMPACT
		local v = COMPACT
		local d = RunLayout.design(ctx)
		local tray = RunLayout.trayRect(ctx)
		local gear = RunLayout.gearRect(ctx)
		local left = tray.pos.X + tray.size.X + 6
		local right = gear.pos.X - 6
		local widest = math.min(if home.phone then 330 else 420, d.X - 24)
		local group = math.max(220, math.min(widest, right - left))
		local cx = math.clamp(d.X / 2, left + group / 2, math.max(left + group / 2, right - group / 2))
		self._groupW = group
		self._pillW = group - GAP - v.skipW
		local y = RunLayout.upperY(ctx) - 4 -- six px under the distance pill: the road view below it is protected
		self.root.Position = UDim2.fromOffset((cx - group / 2) * scale, y * scale)
	else
		self._variant = FULL
		local v = FULL
		self._groupW = b.width
		self._pillW = b.width - GAP - v.skipW
		self.root.Position = UDim2.fromOffset((b.cx - b.width / 2) * scale, b.y * scale)
	end
	self:_buildLegend(if self._view then self._view.controls else nil)
	self:_arrange()
	self:_checkRunOverlap()
end

function TutorialBanner._checkRunOverlap(self: any)
	table.clear(self._runOverlap)
	if self._placement ~= "Run" or not self.root.Visible then
		return
	end
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	local pos = self.root.Position
	local mine = RunLayout.rect(
		pos.X.Offset / scale,
		pos.Y.Offset / scale,
		self._groupW,
		self._bodyH + B.DepthOffset,
		"TutorialBanner"
	)
	local function against(name: string, fn: any)
		local ok, rect = pcall(function()
			local r = fn(ctx)
			return r
		end)
		if ok and type(rect) == "table" and RunLayout.overlaps(mine, rect :: any) then
			table.insert(self._runOverlap, name)
		end
	end
	against("Heat", RunLayout.heatRect)
	against("Hop", RunLayout.hopRect)
	against("Keys", RunLayout.keysRect)
	against("Protected", RunLayout.protected)
end

function TutorialBanner.setPlacement(self: any, placement: string)
	local want = if placement == "Run" then "Run" else "Home"
	if want == self._placement then
		return
	end
	self._placement = want
	self:layout()
end

-- STATE -----------------------------------------------------------------------------------------------------------

function TutorialBanner._setProgress(self: any, p: number)
	local fill: Frame = self._fill
	self._progress = p
	if Motion.reduced() then
		Motion.cancelAll(fill)
		fill.Size = UDim2.fromScale(p, 1)
	else
		Motion.tween(fill, "fill", Motion.info(0.25), { Size = UDim2.fromScale(p, 1) })
	end
end

function TutorialBanner._applyContent(self: any, v: { [string]: any })
	local done = v.state == "Done"
	self._headline.Text = if type(v.objective) == "string" then v.objective else ""
	self._counter.Text = counterOf(v)
	local names: { string } = {}
	if type(v.icons) == "table" then
		names = table.clone(v.icons :: any)
	elseif type(v.icon) == "string" then
		names = { v.icon }
	end
	table.insert(names, "Flag")
	if self._iconKey ~= table.concat(names, ",") then
		self._iconKey = table.concat(names, ",")
		IconArt.draw(self._iconHolder, names)
	end
	self._iconHolder.Visible = not done
	self._check.Visible = done
	local hintOn = type(v.hint) == "string" and v.hint ~= ""
	if hintOn then
		self._hintText.Text = v.hint :: string
	end
	self:_buildLegend(v.controls)
	self:_arrange()
	local steps = if type(v.steps) == "number" and v.steps > 0 then v.steps else 1
	local step = if type(v.step) == "number" then v.step else 1
	local p = math.clamp((step - 1 + (if done then 1 else 0)) / steps, 0, 1)
	self:_setProgress(p)
	if hintOn and not self._hint.Visible then
		self._hint.Visible = true
		self._hintFade:set(1)
		self._hintFade:tween(0, 0.18)
	elseif not hintOn and self._hint.Visible then
		local tw = self._hintFade:tween(1, 0.15)
		if tw then
			tw.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					self._hint.Visible = false
				end
			end)
		else
			self._hint.Visible = false
		end
	end
end

function TutorialBanner._set(self: any, t: Store.Tutorial?)
	local previous = self._view :: { [string]: any }?
	local nextView = view(t)
	self._view = if nextView then table.clone(nextView) else nil
	if nextView == nil then
		self._doneToken += 1
		self:_stopConfetti()
		if self.root.Visible then
			local tw = self._allFade:tween(1, 0.2)
			if tw then
				tw.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed and self._view == nil then
						self.root.Visible = false
					end
				end)
			else
				self.root.Visible = false
			end
		end
		return
	end
	local v = self._view :: { [string]: any }
	if not self.root.Visible or previous == nil then
		self.root.Visible = self._wanted
		self._allFade:set(1)
		self._allFade:tween(0, 0.2)
	end
	local newStep = previous ~= nil and (previous.step ~= v.step or previous.objective ~= v.objective)
	if newStep then
		local content: Frame = self._content
		self._contentFade:set(0)
		self:_applyContent(v)
		self._contentFade:destroy()
		self._contentFade = Fade.capture(content)
		self._contentFade:set(1)
		if Motion.reduced() then
			content.Position = UDim2.new()
			self._contentFade:tween(0, 0.18)
		else
			content.Position = UDim2.fromOffset(12, 0)
			Motion.tween(content, "slide", Motion.info(0.22), { Position = UDim2.new() })
			self._contentFade:tween(0, 0.22)
		end
		if v.state ~= "Done" then
			Sounds.play("Toast")
		end
	else
		self:_applyContent(v)
	end
	self:_checkRunOverlap()
	local becameDone = v.state == "Done" and (previous == nil or previous.state ~= "Done" or newStep)
	if becameDone then
		Sounds.play("TutorialDone")
		Motion.pop(self._check, 1.12)
		if v.big == true then
			self:_confettiBurst()
		end
		self._doneToken += 1
		local token = self._doneToken
		local step = if type(v.step) == "number" then v.step else 0
		if self._doneThread then
			pcall(task.cancel, self._doneThread)
		end
		self._doneThread = task.delay(DONE_SECONDS, function()
			if self._destroyed or token ~= self._doneToken then
				return
			end
			local cb = self._opts.onDoneShown
			if cb then
				cb(step)
			end
		end)
	elseif v.state ~= "Done" then
		self._doneToken += 1
	end
end

-- A short "look here" wiggle (the 8 second hint). Reduced motion: the stripe brightens once instead.
function TutorialBanner.wiggle(self: any)
	if self._destroyed or not self.root.Visible then
		return
	end
	self._wiggles += 1
	local all: Frame = self._all
	if Motion.reduced() then
		local stripe: Frame = self._stripe
		stripe.BackgroundTransparency = 0.5
		Motion.tween(stripe, "flash", Motion.info(0.35), { BackgroundTransparency = 0 })
		return
	end
	local angles = { -3, 3, -2, 2, 0 }
	local function step(i: number)
		if self._destroyed then
			return
		end
		local tw = Motion.tween(all, "wiggle", Motion.info(0.07, Enum.EasingStyle.Sine), { Rotation = angles[i] })
		if i < #angles then
			tw.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					step(i + 1)
				end
			end)
		end
	end
	step(1)
end

function TutorialBanner._stopConfetti(self: any)
	for _, piece in self._confetti do
		Motion.cancelAll(piece)
		piece.Visible = false
	end
end

function TutorialBanner._confettiBurst(self: any)
	if Motion.reduced() or not self.root.Visible then
		return
	end
	local width: number = self._pillW
	local cy = self._bodyH / 2
	local rng = Random.new(self._doneToken + 7)
	for i, piece in self._confetti do
		Motion.cancelAll(piece)
		local sx = width * (0.15 + 0.7 * (i - 1) / (CONFETTI - 1))
		piece.Position = UDim2.fromOffset(sx, cy)
		piece.Rotation = rng:NextInteger(0, 90)
		piece.BackgroundTransparency = 0
		piece.Visible = true
		local gx = sx + rng:NextNumber(-40, 40)
		local gy = cy + rng:NextNumber(-46, 52)
		Motion.tween(piece, "move", Motion.info(CONFETTI_SECONDS), {
			Position = UDim2.fromOffset(gx, gy),
			Rotation = piece.Rotation + rng:NextNumber(-200, 200),
		})
		local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.55)
		local tw = Motion.tween(piece, "fade", fadeInfo, { BackgroundTransparency = 1 })
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				piece.Visible = false
			end
		end)
	end
end

-- While pinned the banner ignores setVisible(false): the tutorial must stay on screen in every mode (the HUD playground hides
-- its Home pieces in Run mode, but a run step needs its banner there).
function TutorialBanner.setPinned(self: any, pinned: boolean)
	self._pinned = pinned
	if pinned then
		self._wanted = true
		self.root.Visible = self._view ~= nil
	end
end

function TutorialBanner.setVisible(self: any, on: boolean)
	if self._pinned and not on then
		return
	end
	self._wanted = on
	self.root.Visible = on and self._view ~= nil
	if not on then
		self:_stopConfetti()
	end
end

function TutorialBanner.getSkipButton(self: any): GuiObject
	return self._skip
end

-- A bounded confetti burst on demand (the welcome pop, the finale). Nothing in reduced motion.
function TutorialBanner.celebrate(self: any)
	self._doneToken += 1
	self:_confettiBurst()
end

function TutorialBanner.setSkipHandler(self: any, handler: (() -> ())?)
	self._opts.onSkip = handler
	self._skip.Visible = handler ~= nil
	self._skipLip.Visible = handler ~= nil
end

-- The pill and Skip as drawn, in device px relative to the device frame.
function TutorialBanner.getRect(self: any): (Vector2, Vector2)
	local ctx: Types.Ctx = self._ctx
	return ctx.screen:rectOf(self._all)
end

function TutorialBanner.getDebugState(self: any): { [string]: any }
	local ctx: Types.Ctx = self._ctx
	local v = self._view :: { [string]: any }?
	local confetti = 0
	for _, piece in self._confetti do
		if piece.Visible then
			confetti += 1
		end
	end
	local pos, size = ctx.screen:rectOf(self._body)
	local skipPos, skipSize = ctx.screen:rectOf(self._skip)
	return {
		visible = self.root.Visible,
		placement = self._placement,
		state = if v then v.state else nil,
		step = if v then v.step else nil,
		objective = self._headline.Text,
		objectiveSize = self._headline.TextSize,
		instruction = self._stripeText.Text,
		stripeSize = self._stripeText.TextSize,
		counter = self._counter.Text,
		counterVisible = self._counter.Visible,
		legendVisible = self._legend.Visible,
		legendCaps = #self._legend:GetChildren(),
		hintSize = self._hintText.TextSize,
		progress = self._progress,
		hintVisible = self._hint.Visible,
		hint = self._hintText.Text,
		confettiVisible = confetti,
		confettiPool = CONFETTI,
		bodyHeight = self._bodyH,
		pillWidth = self._pillW,
		groupWidth = self._groupW,
		wiggles = self._wiggles,
		skipVisible = self._skip.Visible,
		skipPos = skipPos,
		skipSize = skipSize, -- the touch target: at least 44 in design px times the scale
		skipDesignHeight = self._variant.skipH,
		objectiveFits = self._headline.TextFits,
		devicePos = pos,
		deviceSize = size,
		reservedOverlap = ctx.screen:overlapsReserved(pos, size),
		runOverlap = table.clone(self._runOverlap),
	}
end

function TutorialBanner.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end

return TutorialBanner
