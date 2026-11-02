--!strict
-- Home HUD: the tutorial banner (Lane 3, BRIEF M11-02; redesigned Round 2 N8-02 / N8-02a from IMG-07, 2026-11-02).
--
-- Look (references: IMG-07-tutorial-banner.png and hud-tutorial-reference.png, in the Arcade kit): ONE dark rounded pill with
-- the thick dark boundary and a shallow lip, on a clear grid:
--
--     | pad | ICON COLUMN | gap | TEXT COLUMN ......................................... | pad |
--                                  HEADLINE   big yellow, 2 to 4 words, centred in the text column
--                                  GREEN BAR  one instruction, centred under the headline: same column, so its left and
--                                             right insets are equal; two lines are allowed on phones
--                                  [ progress strip with "2 / 12" ........ ] [ Skip ]
--
-- The icon sits in its OWN leading column, vertically centred in the pill (a kid who cannot read follows the picture). The
-- whole-tutorial progress strip and the Skip button share the bottom row of the text column, so neither can crowd the green
-- bar. The Skip hit box is 48 design px tall (the approved touch minimum) while its visible face is a calm grey pill; the
-- box hangs below the pill, never over the bar. ONE delayed hint (a small outlined note under the pill) is revealed by the
-- controller after 8 seconds without progress. A finished step shows a green check, plays the chime (Sounds "TutorialDone")
-- and, for big moments, a bounded confetti burst (16 pieces, none in reduced motion).
--
-- Contract: the banner draws store.tutorial and nothing else; it grants nothing and never writes the store. The fields it
-- reads (older fixtures without the optional ones still work):
--   step (1 based), steps (the progress strip and its "2 / 12"), objective (the headline), instruction (the green bar),
--   hint (the delayed note under the pill), state "Active" | "Hint" | "Done" (Done: green check, chime, the pill keeps
--   the headline and bar it is given), icons: { string }? (icon names to try, painter names), accent: Color3? (a glow
--   behind the icon, e.g. Downtown blue), iconLabel: string? (a caption on the icon, e.g. "HOME"), big: boolean? (confetti
--   when done). count / goal / counterText / controls are accepted and ignored (the Round 1 legend and per-step counter
--   were replaced by device-aware wording in the green bar and the hint, N8-01a).
--
-- Placement: "Home" (top centre: from Home/HomeHud's frame when one is attached, else Home/Layout) or "Run" (compact: just
-- under the run's distance pill, clear of the protected road view). Run placement is checked against the run's Heat, Hop and
-- Keys rectangles (getDebugState().runOverlap).
--
-- API: TutorialBanner.new(ctx, { onDoneShown: ((step: number) -> ())?, onSkip: (() -> ())? }?) -> TutorialBanner
--   :layout()  :setVisible(on)  :setPlacement("Home" | "Run")  :wiggle()  :getSkipButton() -> GuiObject
--   :setSkipHandler(fn?)  (shows or hides the Skip button; the tutorial controller sets it)  :celebrate()  (a confetti burst)
--   :setPinned(on)  (while pinned, setVisible(false) is ignored: the banner shows in Home, Run and Results)
--   :setHomeFrame(frame?)  (frame = { cx, y, width, compact? } in safe design px: HomeHud tells the banner where the top
--   centre is, between its side columns; nil goes back to Home/Layout)
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
local PILL = Color3.fromRGB(20, 26, 48)
local PILL_EDGE = Color3.fromRGB(70, 96, 170) -- the thin lighter ring inside the dark boundary
local CONFETTI_COLOURS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(90, 190, 255),
	Color3.fromRGB(110, 220, 120),
	Color3.new(1, 1, 1),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(170, 130, 255),
}

type Variant = {
	pad: number, -- the even outer padding of the pill
	icon: number, -- the icon column's square
	colGap: number, -- between the icon column and the text column
	head: number, -- the headline box height at its largest size
	headMax: number,
	headMin: number,
	gap: number, -- between the headline, the bar and the bottom row
	bar: number, -- the green bar's height for one line
	barText: number,
	row: number, -- the bottom row (progress strip and Skip)
	strip: number, -- the progress strip's height (its "2 / 12" is 16 px, so 22 at least)
	skipW: number,
	skipH: number, -- the visible Skip pill; its hit box is Tokens.Touch.Minimum tall
	corner: number,
}
local FULL: Variant = {
	pad = 10,
	icon = 60,
	colGap = 10,
	head = 34,
	headMax = 30,
	headMin = 20,
	gap = 3,
	bar = 28,
	barText = 18,
	row = 28,
	strip = 22,
	skipW = 68,
	skipH = 28,
	corner = 22,
}
local COMPACT: Variant = {
	pad = 6,
	icon = 44,
	colGap = 6,
	head = 26,
	headMax = 22,
	headMin = 18,
	gap = 2,
	bar = 22,
	barText = 16,
	row = 26,
	strip = 22,
	skipW = 60,
	skipH = 26,
	corner = 16,
}

export type Options = { onDoneShown: ((step: number) -> ())?, onSkip: (() -> ())? }
export type HomeFrame = { cx: number, y: number, width: number, compact: boolean? }

export type TutorialBanner = {
	root: Frame,
	layout: (self: TutorialBanner) -> (),
	setVisible: (self: TutorialBanner, on: boolean) -> (),
	setPlacement: (self: TutorialBanner, placement: string) -> (),
	setHomeFrame: (self: TutorialBanner, frame: HomeFrame?) -> (),
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

-- "2 / 12": the whole tutorial's progress, nothing per step.
local function progressText(v: { [string]: any }): string
	local steps = if type(v.steps) == "number" and v.steps > 0 then math.floor(v.steps) else 0
	if steps == 0 then
		return ""
	end
	local step = if type(v.step) == "number" then math.floor(v.step) else 1
	return string.format("%d / %d", math.clamp(step, 1, steps), steps)
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
	self._homeFrame = nil :: HomeFrame?
	self._pillW = 300
	self._bodyH = 92
	self._groupW = 300
	self._view = nil :: { [string]: any }?
	self._doneToken = 0
	self._wanted = true
	self._pinned = false
	self._progress = 0
	self._wiggles = 0
	self._headSize = FULL.headMax
	self._barLines = 1
	self._runOverlap = {} :: { string }
	local make = Arcade.make

	local root = trove:Add(make("Frame", {
		Name = "TutorialBanner",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 120),
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
	local lipCorner = Arcade.corner(lip, 22)
	self._lip = lip
	local body = make("Frame", {
		Name = "Body",
		Size = UDim2.fromOffset(300, 92),
		BackgroundColor3 = PILL,
		BackgroundTransparency = 0.04,
		ZIndex = 6,
		Parent = all,
	})
	local bodyCorner = Arcade.corner(body, 22)
	Arcade.outline(body, "Button")
	-- a thin lighter ring just inside the boundary: the glow edge of IMG-07
	local ring = make("Frame", {
		Name = "Ring",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = body,
	})
	local ringCorner = Arcade.corner(ring, 19)
	make("UIStroke", {
		Thickness = 1.5,
		Color = PILL_EDGE,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ring,
	})
	Arcade.gloss(body)
	self._body = body
	self._corners = { lipCorner, bodyCorner, ringCorner }

	-- content that crossfades on a new step
	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = body,
	})
	self._content = content

	-- the icon column: an optional accent glow, the icon, an optional caption
	local glow = make("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		Visible = false,
		ZIndex = 8,
		Parent = content,
	})
	Arcade.corner(glow, 100)
	local glowStroke = make("UIStroke", {
		Thickness = 2,
		Color = Color3.new(1, 1, 1),
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = glow,
	})
	self._glow = glow
	self._glowStroke = glowStroke
	local iconHolder = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(FULL.icon, FULL.icon),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = content,
	})
	self._iconHolder = iconHolder
	local iconLabel = make("Frame", {
		Name = "IconLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 11,
		Parent = content,
	})
	Arcade.corner(iconLabel, 6)
	local iconLabelText = Arcade.text(iconLabel, { text = "", role = "Small", name = "Text", z = 12 })
	iconLabelText.Size = UDim2.fromScale(1, 1)
	self._iconLabel = iconLabel
	self._iconLabelText = iconLabelText
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

	-- the text column: headline over the green bar, both centred in the same column
	local headline = Arcade.text(content, {
		text = "",
		role = "Display",
		name = "Headline",
		face = "Keys",
		outline = "Major",
		xAlign = Enum.TextXAlignment.Center,
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
		size = FULL.barText,
		xAlign = Enum.TextXAlignment.Center,
		z = 10,
	})
	stripeText.Size = UDim2.fromScale(1, 1)
	stripeText.TextWrapped = true
	self._stripeText = stripeText

	-- the whole-tutorial progress strip, with "2 / 12" centred on it
	local track = make("Frame", {
		Name = "Strip",
		BackgroundColor3 = A.Ink,
		BackgroundTransparency = 0.25,
		ZIndex = 9,
		Parent = content,
	})
	Arcade.corner(track, 11)
	Arcade.outline(track, "Minor")
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 10,
		Parent = track,
	})
	Arcade.corner(fill, 11)
	make("UIGradient", { Color = A.Fill.Green, Rotation = 90, Parent = fill })
	local counter = Arcade.text(track, {
		text = "",
		role = "Small",
		name = "Counter",
		z = 11,
	})
	counter.Size = UDim2.fromScale(1, 1)
	self._counter = counter
	self._track = track
	self._fill = fill

	-- the Skip button: a 48 px tall hit box, a calm grey pill on its top part (the box hangs below the pill)
	local skipHolder = make("Frame", {
		Name = "SkipHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(FULL.skipW, Tokens.Touch.Minimum),
		ZIndex = 9,
		Parent = content,
	})
	local skipFace = make("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, FULL.skipH),
		Position = UDim2.fromOffset(0, 3),
		ZIndex = 9,
		Parent = skipHolder,
	})
	self._skipCorner = Arcade.corner(skipFace, 10)
	Arcade.outline(skipFace, "Minor")
	make("UIGradient", { Color = PreviewTokens.Shop.Fill.Steel, Rotation = 90, Parent = skipFace })
	local skipLabel = Arcade.text(skipFace, { text = "Skip", role = "Label", name = "Text", z = 10 })
	skipLabel.Size = UDim2.fromScale(1, 1)
	local skip: TextButton = make("TextButton", {
		Name = "Skip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 11,
		Parent = skipHolder,
	})
	self._skipHolder = skipHolder
	self._skipFace = skipFace
	self._skip = skip
	self._skipLabel = skipLabel
	skipHolder.Visible = self._opts.onSkip ~= nil
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
			Motion.press(skipFace, true)
		end
	end)
	trove:Connect(skip.InputEnded, function()
		Motion.press(skipFace, false)
	end)

	-- the delayed hint: floating outlined text under the pill (revealed by the controller after 8 seconds)
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
		Motion.cancelAll(skipFace)
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
	local progress = if viewNow then progressText(viewNow) else ""

	-- the grid: icon column, gap, text column. The headline and the green bar share the text column exactly.
	local textX = v.pad + v.icon + v.colGap
	local textW = math.max(120, pillW - textX - v.pad)
	local size, lines = fitHeadline(headText, v, textW)
	self._headSize = size
	local headH = if lines == 2 then size * 2 + 6 else math.max(v.head, size + 4)
	local barVisible = lineText ~= ""
	local barH = v.bar
	local barLines = 1
	if barVisible then
		local wrapped = measure(lineText, v.barText, textW - 16)
		barLines = math.max(1, math.round(wrapped.Y / (v.barText * 1.2)))
		barH = math.max(v.bar, barLines * (v.barText + 2) + 8)
	end
	self._barLines = barLines
	local top = v.pad
	local barTop = top + headH + v.gap
	local rowTop = barTop + (if barVisible then barH + v.gap + 1 else 0)
	local bodyH = math.max(rowTop + v.row + v.pad, v.icon + 2 * v.pad)
	self._bodyH = bodyH

	local headline: TextLabel = self._headline
	headline.TextSize = size
	headline.Position = UDim2.fromOffset(textX, top)
	headline.Size = UDim2.fromOffset(textW, headH)
	headline.TextXAlignment = Enum.TextXAlignment.Center
	headline.TextYAlignment = Enum.TextYAlignment.Center
	local stripe: Frame = self._stripe
	stripe.Visible = barVisible
	stripe.Position = UDim2.fromOffset(textX, barTop)
	stripe.Size = UDim2.fromOffset(textW, barH)
	local stripeLabel: TextLabel = self._stripeText
	stripeLabel.TextSize = v.barText
	stripeLabel.Text = lineText

	-- the icon column (centred on the whole pill)
	local iconY = bodyH / 2
	local iconHolder: Frame = self._iconHolder
	iconHolder.Position = UDim2.fromOffset(v.pad, iconY)
	iconHolder.Size = UDim2.fromOffset(v.icon, v.icon)
	local check: Frame = self._check
	check.Position = UDim2.fromOffset(v.pad, iconY)
	check.Size = UDim2.fromOffset(v.icon, v.icon)
	local glow: Frame = self._glow
	local glowSize = v.icon + 8
	glow.Position = UDim2.fromOffset(v.pad - 4, iconY)
	glow.Size = UDim2.fromOffset(glowSize, glowSize)
	local label: Frame = self._iconLabel
	local labelW = math.min(v.icon + 8, math.ceil(measure(self._iconLabelText.Text, MIN_TEXT).X) + 14)
	label.Size = UDim2.fromOffset(math.max(labelW, 30), 20)
	label.Position = UDim2.fromOffset(v.pad + v.icon / 2, iconY + v.icon / 2 + 4)

	-- the bottom row: the progress strip, then Skip at the right end of the same column
	local skipOn = self._skipHolder.Visible
	local skipW = if skipOn then v.skipW else 0
	local stripW = math.max(60, textW - (if skipOn then skipW + 8 else 0))
	local track: Frame = self._track
	track.Position = UDim2.fromOffset(textX, rowTop + (v.row - v.strip) / 2)
	track.Size = UDim2.fromOffset(stripW, v.strip)
	local counter: TextLabel = self._counter
	counter.Text = progress
	counter.Visible = progress ~= ""
	local skipHolder: Frame = self._skipHolder
	skipHolder.Size = UDim2.fromOffset(v.skipW, Tokens.Touch.Minimum)
	skipHolder.Position = UDim2.fromOffset(textX + textW - v.skipW, rowTop - 3)
	self._skipFace.Size = UDim2.new(1, 0, 0, v.skipH)
	self._skipLabel.TextSize = math.max(MIN_TEXT, if v == FULL then 18 else 16)
	for _, c in self._corners do
		c.CornerRadius = UDim.new(0, v.corner)
	end
	self._corners[3].CornerRadius = UDim.new(0, math.max(v.corner - 3, 4))

	self._body.Size = UDim2.fromOffset(pillW, bodyH)
	self._lip.Size = UDim2.fromOffset(pillW, bodyH)

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
	if self._placement == "Run" then
		self._variant = COMPACT
		local d = RunLayout.design(ctx)
		local tray = RunLayout.trayRect(ctx)
		local gear = RunLayout.gearRect(ctx)
		local left = tray.pos.X + tray.size.X + 6
		local right = gear.pos.X - 6
		local widest = math.min(if home.phone then 330 else 420, d.X - 24)
		local group = math.max(220, math.min(widest, right - left))
		local cx = math.clamp(d.X / 2, left + group / 2, math.max(left + group / 2, right - group / 2))
		self._groupW = group
		self._pillW = group
		local y = RunLayout.upperY(ctx) - 4 -- six px under the distance pill: the road view below it is protected
		self.root.Position = UDim2.fromOffset((cx - group / 2) * scale, y * scale)
	else
		local frame: HomeFrame? = self._homeFrame
		local cx, y, width, compact = home.banner.cx, home.banner.y, home.banner.width, home.phone
		if frame then
			cx, y, width = frame.cx, frame.y, frame.width
			compact = if frame.compact == nil then width < 400 else frame.compact
		end
		self._variant = if compact then COMPACT else FULL
		self._groupW = width
		self._pillW = width
		self.root.Position = UDim2.fromOffset((cx - width / 2) * scale, y * scale)
	end
	self:_arrange()
	self:_checkRunOverlap()
end

function TutorialBanner.setHomeFrame(self: any, frame: HomeFrame?)
	self._homeFrame = frame
	if not self._destroyed then
		self:layout()
	end
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
	-- the accent glow (step 1: the Downtown portal in Downtown blue) and the icon caption (step 6: HOME)
	local accent = v.accent
	local glow: Frame = self._glow
	glow.Visible = typeof(accent) == "Color3" and not done
	if typeof(accent) == "Color3" then
		glow.BackgroundColor3 = accent
		self._glowStroke.Color = accent
	end
	local caption = if type(v.iconLabel) == "string" then v.iconLabel else ""
	self._iconLabelText.Text = caption
	self._iconLabel.Visible = caption ~= "" and not done
	local hintOn = type(v.hint) == "string" and v.hint ~= ""
	if hintOn then
		self._hintText.Text = v.hint :: string
	end
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

-- A short "look here" wiggle (the 8 second hint, ONCE per step). Reduced motion: the green bar brightens once instead.
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
	local angles = { -2, 2, -1.5, 1.5, 0 }
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
	self._skipHolder.Visible = handler ~= nil
	self:_arrange()
end

-- The pill as drawn, in device px relative to the device frame.
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
	local barPos, barSize = ctx.screen:rectOf(self._stripe)
	local headPos, headSize = ctx.screen:rectOf(self._headline)
	local stripPos, stripSize = ctx.screen:rectOf(self._track)
	local iconPos, iconSize = ctx.screen:rectOf(self._iconHolder)
	return {
		visible = self.root.Visible,
		placement = self._placement,
		state = if v then v.state else nil,
		step = if v then v.step else nil,
		objective = self._headline.Text,
		objectiveSize = self._headline.TextSize,
		instruction = self._stripeText.Text,
		stripeSize = self._stripeText.TextSize,
		barLines = self._barLines,
		counter = self._counter.Text,
		counterVisible = self._counter.Visible,
		legendVisible = false, -- the Round 1 legend is gone (N8-01a: the device words are in the green bar)
		legendCaps = 0,
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
		skipVisible = self._skipHolder.Visible,
		skipPos = skipPos,
		skipSize = skipSize, -- the touch target: Tokens.Touch.Minimum in design px times the scale
		skipDesignHeight = Tokens.Touch.Minimum,
		objectiveFits = self._headline.TextFits,
		-- the grid, device px relative to the device frame: the bar's centre must equal the headline's centre, and the
		-- icon column must sit left of both (N8-02a)
		barCentreX = barPos.X + barSize.X / 2,
		headlineCentreX = headPos.X + headSize.X / 2,
		barLeftInset = barPos.X - pos.X,
		barRightInset = (pos.X + size.X) - (barPos.X + barSize.X),
		iconRight = iconPos.X + iconSize.X,
		stripRect = { x = stripPos.X, y = stripPos.Y, w = stripSize.X, h = stripSize.Y },
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
