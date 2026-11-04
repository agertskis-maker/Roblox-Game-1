--!strict
-- Tutorial banner, rebuilt in Round 3 (Adam: "much too big, it's literally blocking my entire screen"; reference R3-IMG-08). One slim pill:
-- an icon, a one-line headline, and the green instruction inside the same pill. No step counter. A small Skip sits beside the pill,
-- and the one delayed hint is a thin chip under it. About half the old height, and it never takes more width than its words need.
--
-- It reads store.tutorial and draws it; the tutorial controller owns the words and the timing.
--
-- Placement: "Home" (top centre, from HomeHud's frame when one is attached, else Home/Layout) or "Run" (under the run's distance pill,
-- clear of the road view).
--
-- API: TutorialBanner.new(ctx, { onDoneShown: ((step: number) -> ())?, onSkip: (() -> ())? }?) -> TutorialBanner
--   :layout()  :setVisible(on)  :setPlacement("Home" | "Run")  :wiggle()  :getSkipButton() -> GuiObject
--   :setSkipHandler(fn?)  :celebrate()  :setPinned(on)  :setHomeFrame(frame?)  :getRect() -> (pos, size)  :destroy()  :getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local CarKit = require(script.Parent.Parent.CarKit)
local GameIcons = require(script.Parent.Parent.GameIcons)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Parent.Motion)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

local make = CarKit.make

local DONE_SECONDS = 1.6
local CONFETTI = 14
local PILL = Color3.fromRGB(14, 20, 40)

type Size = { h: number, icon: number, head: number, chip: number, gap: number }
local FULL: Size = { h = 46, icon = 36, head = 28, chip = 15, gap = 8 }
local SMALL: Size = { h = 38, icon = 30, head = 22, chip = 14, gap = 6 }

export type Options = { onDoneShown: ((step: number) -> ())?, onSkip: (() -> ())? }
export type HomeFrame = { cx: number, y: number, width: number, compact: boolean? }
export type TutorialBanner = { [string]: any }

local TutorialBanner = {}
TutorialBanner.__index = TutorialBanner

local function textWidth(text: string, size: number, font: Font): number
	local p = Instance.new("GetTextBoundsParams")
	p.Text = text
	p.Size = size
	p.Font = font
	p.Width = 2000
	local ok, bounds = pcall(function()
		return TextService:GetTextBoundsAsync(p)
	end)
	return if ok then (bounds :: Vector2).X else #text * size * 0.5
end

function TutorialBanner.new(ctx: Types.Ctx, opts: Options?): TutorialBanner
	local self = setmetatable({}, TutorialBanner) :: any
	local trove = Trove.new()
	self._trove = trove
	self._ctx = ctx
	self._opts = opts or {}
	self._destroyed = false
	self._placement = "Home"
	self._homeFrame = nil :: HomeFrame?
	self._view = nil :: { [string]: any }?
	self._wanted = true
	self._pinned = false
	self._wiggles = 0
	self._size = FULL
	self._token = 0

	local root = trove:Add(make("Frame", {
		Name = "TutorialBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 80),
		Visible = false,
		ZIndex = 5,
	}, ctx.layer))
	self.root = root
	self._scale = make("UIScale", { Name = "HudScale", Scale = ctx.screen:uiScale() }, root)

	local pill = make("Frame", {
		Name = "Pill",
		BackgroundColor3 = PILL,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		ZIndex = 5,
	}, root)
	self._pill = pill
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
	make("UIStroke", { Thickness = 2.5, Color = CarKit.White, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pill)

	local iconHolder = make("Frame", { Name = "Icon", BackgroundTransparency = 1, ZIndex = 6 }, pill)
	self._iconHolder = iconHolder
	self._headline = make("TextLabel", {
		Name = "Headline",
		BackgroundTransparency = 1,
		FontFace = CarKit.display(),
		TextColor3 = CarKit.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Text = "",
	}, pill)
	local chip = make("Frame", { Name = "Chip", BackgroundColor3 = CarKit.GreenDeep, ZIndex = 6 }, pill)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, chip)
	self._chip = chip
	self._line = make("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		FontFace = CarKit.body(),
		TextColor3 = CarKit.White,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Text = "",
	}, chip)

	local skip = make("TextButton", {
		Name = "Skip",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0),
		FontFace = CarKit.body(),
		Text = "Skip",
		TextColor3 = CarKit.White,
		TextStrokeColor3 = CarKit.Ink,
		TextStrokeTransparency = 0.2,
		Size = UDim2.fromOffset(52, Tokens.Touch.Minimum),
		Visible = false,
		ZIndex = 6,
	}, root)
	self._skip = skip
	trove:Connect(skip.Activated, function()
		local h = self._skipHandler
		if h then
			h()
		end
	end)

	local hint = make("Frame", {
		Name = "Hint",
		BackgroundColor3 = PILL,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, hint)
	self._hint = hint
	self._hintText = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		FontFace = CarKit.body(),
		TextColor3 = CarKit.White,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Text = "",
	}, hint)

	trove:Add(ctx.store:subscribe("tutorial", function(value: any)
		self:_set(value)
	end))
	self:layout()
	return self :: TutorialBanner
end

function TutorialBanner._arrange(self: any)
	local s: Size = self._size
	local head: TextLabel = self._headline
	local line: TextLabel = self._line
	head.TextSize = s.head
	line.TextSize = s.chip
	local headW = textWidth(head.Text, s.head, head.FontFace) + 4
	local chipW = if line.Text ~= "" then textWidth(line.Text, s.chip, line.FontFace) + 22 else 0
	local pad = (s.h - s.icon) / 2
	local total = pad + s.icon + s.gap + headW + (if chipW > 0 then s.gap + chipW else 0) + pad + 8
	local room = self._room or 640
	if total > room then
		-- on a narrow screen the headline comes down a little before anything is cut
		local k = math.max((room - pad * 2 - s.icon - s.gap * 2 - chipW) / math.max(headW, 1), 0.7)
		head.TextSize = math.max(math.floor(s.head * k), 16)
		headW = textWidth(head.Text, head.TextSize, head.FontFace) + 4
		total = math.min(room, pad + s.icon + s.gap + headW + s.gap + chipW + pad + 8)
	end
	local pill: Frame = self._pill
	pill.Size = UDim2.fromOffset(total, s.h)
	self._iconHolder.Size = UDim2.fromOffset(s.icon, s.icon)
	self._iconHolder.Position = UDim2.fromOffset(pad + 4, pad)
	head.Position = UDim2.fromOffset(pad + 4 + s.icon + s.gap, 0)
	head.Size = UDim2.new(0, headW, 1, 0)
	local chip: Frame = self._chip
	chip.Visible = chipW > 0
	chip.Size = UDim2.fromOffset(chipW, s.h - 14)
	chip.Position = UDim2.fromOffset(pad + 4 + s.icon + s.gap + headW + s.gap, 7)
	local skip: TextButton = self._skip
	skip.TextSize = s.chip
	skip.Position = UDim2.new(0.5, total / 2 + 4, 0, (s.h - Tokens.Touch.Minimum) / 2)
	local hint: Frame = self._hint
	local hintText: TextLabel = self._hintText
	hintText.TextSize = s.chip
	hint.Size = UDim2.fromOffset(textWidth(hintText.Text, s.chip, hintText.FontFace) + 24, s.chip + 10)
	hint.Position = UDim2.new(0.5, 0, 0, s.h + 4)
	self.root.Size = UDim2.fromOffset(math.max(total + 120, 200), s.h + s.chip + 14)
end

function TutorialBanner.layout(self: any)
	local ctx: Types.Ctx = self._ctx
	local scale = ctx.screen:uiScale()
	self._scale.Scale = scale
	local home = Layout.forProfile(ctx.screen:profile(), scale)
	local phone = home.phone
	self._size = if phone then SMALL else FULL
	if self._placement == "Run" then
		local d = RunLayout.design(ctx)
		self._room = math.min(if phone then 420 else 620, d.X - 24)
		self.root.Position = UDim2.fromOffset(d.X / 2 * scale, (RunLayout.upperY(ctx) - 4) * scale)
	else
		local frame: HomeFrame? = self._homeFrame
		local cx, y, width = home.banner.cx, home.banner.y, home.banner.width
		if frame then
			cx, y, width = frame.cx, frame.y, frame.width
		end
		self._room = width
		self.root.Position = UDim2.fromOffset(cx * scale, y * scale)
	end
	self:_arrange()
end

function TutorialBanner.setHomeFrame(self: any, frame: HomeFrame?)
	self._homeFrame = frame
	if not self._destroyed then
		self:layout()
	end
end

function TutorialBanner.setPlacement(self: any, placement: string)
	local want = if placement == "Run" then "Run" else "Home"
	if want ~= self._placement then
		self._placement = want
		self:layout()
	end
end

function TutorialBanner._drawIcon(self: any, v: { [string]: any }, done: boolean)
	local holder: Frame = self._iconHolder
	local names = if done then { "Check" } elseif type(v.icons) == "table" then v.icons else { "Flag" }
	local key = table.concat(names :: { string }, ",")
	if key == self._iconKey then
		return
	end
	self._iconKey = key
	holder:ClearAllChildren()
	for _, name in names :: { string } do
		local art = GameIcons.Painter[name]
		if art and GameIcons.has(art) then
			CarKit.art(holder, art, { placeholder = false, z = 7 })
			return
		end
	end
end

function TutorialBanner._set(self: any, t: any)
	local previous = self._view
	self._view = t
	local root: Frame = self.root
	if t == nil then
		root.Visible = false
		self._token += 1
		return
	end
	root.Visible = self._wanted
	local done = t.state == "Done"
	self._headline.Text = string.upper(if type(t.objective) == "string" then t.objective else "")
	self._line.Text = if type(t.instruction) == "string" then t.instruction else ""
	self:_drawIcon(t, done)
	local hintOn = type(t.hint) == "string" and t.hint ~= ""
	self._hint.Visible = hintOn
	self._hintText.Text = if hintOn then t.hint else ""
	self:_arrange()
	local newStep = previous == nil or previous.step ~= t.step or previous.objective ~= t.objective
	if newStep and not done then
		Sounds.play("Toast")
		Motion.pop(self._pill, 0.92)
	end
	if done and (newStep or previous.state ~= "Done") then
		Sounds.play("TutorialDone")
		Motion.pop(self._pill, 1.08)
		if t.big == true then
			self:celebrate()
		end
		self._token += 1
		local token = self._token
		local step = if type(t.step) == "number" then t.step else 0
		task.delay(DONE_SECONDS, function()
			local cb = self._opts.onDoneShown
			if cb and not self._destroyed and token == self._token then
				cb(step)
			end
		end)
	end
end

-- One "look here" nudge when the hint arrives.
function TutorialBanner.wiggle(self: any)
	if self._destroyed or not self.root.Visible then
		return
	end
	self._wiggles += 1
	if not Motion.reduced() then
		Motion.pop(self._pill, 1.06)
	end
end

function TutorialBanner.celebrate(self: any)
	if self._destroyed or Motion.reduced() then
		return
	end
	local colours = { CarKit.Yellow, CarKit.Red, CarKit.Green, Color3.fromRGB(70, 170, 255), CarKit.White }
	for i = 1, CONFETTI do
		local piece = make("Frame", {
			Name = "Confetti",
			BorderSizePixel = 0,
			BackgroundColor3 = colours[i % #colours + 1],
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromOffset(8, 5),
			Rotation = math.random(0, 360),
			ZIndex = 8,
		}, self.root)
		Motion.tween(piece, "Fly", Motion.info(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.random(-220, 220), 0.3, math.random(-10, 110)),
			BackgroundTransparency = 1,
			Rotation = piece.Rotation + 180,
		})
		task.delay(0.9, function()
			piece:Destroy()
		end)
	end
end

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
end

function TutorialBanner.getSkipButton(self: any): GuiObject
	return self._skip
end

function TutorialBanner.setSkipHandler(self: any, handler: (() -> ())?)
	self._skipHandler = handler
	self._skip.Visible = handler ~= nil
end

function TutorialBanner.getRect(self: any): (Vector2, Vector2)
	return self._ctx.screen:rectOf(self._pill)
end

function TutorialBanner.getDebugState(self: any): { [string]: any }
	local v = self._view
	local pos, size = self._ctx.screen:rectOf(self._pill)
	return {
		visible = self.root.Visible,
		placement = self._placement,
		state = if v then v.state else nil,
		step = if v then v.step else nil,
		objective = self._headline.Text,
		instruction = self._line.Text,
		hint = self._hintText.Text,
		hintVisible = self._hint.Visible,
		wiggles = self._wiggles,
		skipVisible = self._skip.Visible,
		devicePos = pos,
		deviceSize = size,
		pillHeight = self._size.h,
		reservedOverlap = self._ctx.screen:overlapsReserved(pos, size),
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
