--!strict
-- Heat gauge for the run HUD. Lane 3 presentation only.
--
-- It displays what it is given: heat (0 to 1), the stage, and during
-- Meltdown the remaining escape time (meltdownRemaining01, 1 to 0). It runs no
-- timer that decides anything; Lane 1 owns Heat, the Meltdown window and
-- escape or crash (decision 0008). The only clock here is the visual pulse.
--
-- Stage values are PascalCase strings: "Calm", "Warning", "Critical",
-- "Meltdown". Player labels are "Cool", "Hot", "Too hot!", "Losing control!".
--
-- Non-colour cues per stage: fill length, the gauge growing, the label, steam
-- or smoke puffs on the icon, stripes (Critical and Meltdown), and in Meltdown
-- a dark track, a clock and "ESCAPE TIME" so the draining bar reads as time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type HeatStage = "Calm" | "Warning" | "Critical" | "Meltdown"

export type DebugState = {
	stage: HeatStage,
	label: string,
	tag: string,
	heat: number,
	fill: number,
	reducedMotion: boolean,
	pulsing: boolean,
	pulseHz: number,
	stageScale: number,
	labelFits: boolean,
	tagFits: boolean,
}

local WIDTH = 320
local HEIGHT = 76
local TRACK_X = 60
local TRACK_Y = 42
local TRACK_H = 24
local TRACK_W = WIDTH - TRACK_X - 14
local TRACK_INSET = 3

local HeatGauge = {}
HeatGauge.__index = HeatGauge

HeatGauge.Size = Vector2.new(WIDTH, HEIGHT)

-- Provisional copy of the outline's Proposed thresholds (decision 0008).
-- Lane 1 owns the real values; when Lane 1 supplies `stage`, these are only
-- used to place the tick marks.
HeatGauge.Thresholds = table.freeze({
	Warning = 0.6,
	Critical = 0.85,
})

HeatGauge.Labels = table.freeze({
	Calm = "Cool",
	Warning = "Hot",
	Critical = "Too hot!",
	Meltdown = "Losing control!",
})

local STAGE_SCALE: { [string]: number } = {
	Calm = 1,
	Warning = 1.08,
	Critical = 1.16,
	Meltdown = 1.16,
}

local PUFFS: { [string]: number } = {
	Calm = 0,
	Warning = 1,
	Critical = 2,
	Meltdown = 3,
}

-- Derives a stage from heat alone. Never returns "Meltdown": only Lane 1
-- knows when the escape window has started.
function HeatGauge.stageFor(heat01: number): HeatStage
	if heat01 >= HeatGauge.Thresholds.Critical then
		return "Critical"
	elseif heat01 >= HeatGauge.Thresholds.Warning then
		return "Warning"
	end
	return "Calm"
end

local function clamp01(value: number?): number
	if value == nil or value ~= value then
		return 0
	end
	return math.clamp(value, 0, 1)
end

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: UDim)
	make("UICorner", { CornerRadius = radius, Parent = parent })
end

-- Slanted stripe bars across the bar's full width (danger stripes).
local STRIPE_COUNT = 16
local STRIPE_WIDTH = 7

function HeatGauge.new(parent: Instance, palette: Tokens.Palette, reducedMotion: boolean)
	local self = setmetatable({}, HeatGauge)
	self._trove = Trove.new()
	self._pulseTrove = self._trove:Extend()
	self._palette = palette
	self._reduced = reducedMotion
	self._stage = "Calm" :: HeatStage
	self._heat = 0
	self._fill = 0
	self._pulseHz = 0
	self._phase = 0
	self._pulsing = false
	self._fillTween = nil :: Tween?
	self._scaleTween = nil :: Tween?

	local font = Tokens.font()

	-- Root keeps the gauge's footprint; the RunHud puts its device UIScale here.
	local root = make("Frame", {
		Name = "HeatGauge",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	self._trove:Add(root)
	self.Root = root

	-- Body grows with the stage (design emphasis), anchored at its bottom centre.
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._stageScale = make("UIScale", { Name = "StageScale", Scale = 1, Parent = body })

	local glow = make("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 16, 1, 16),
		BackgroundColor3 = palette.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = body,
	})
	corner(glow, UDim.new(0, 28))
	self._glow = glow

	local shadow = make("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, Tokens.Shadow.OffsetY),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Shadow,
		BackgroundTransparency = Tokens.Shadow.Transparency,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = body,
	})
	corner(shadow, Tokens.Radius.Panel)

	local card = make("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Card,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = body,
	})
	corner(card, Tokens.Radius.Panel)
	self._cardStroke = make("UIStroke", {
		Color = palette.Stroke,
		Thickness = Tokens.Stroke.Regular,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})

	-- Thermometer icon with steam or smoke puffs.
	local icon = make("Frame", {
		Name = "Icon",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(36, 60),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	self._puffs = {}
	local puffSpots = { { 22, -4, 14 }, { 30, -16, 16 }, { 16, -22, 12 } }
	for i, spot in puffSpots do
		local puff = make("Frame", {
			Name = "Puff" .. i,
			Position = UDim2.fromOffset(spot[1], spot[2]),
			Size = UDim2.fromOffset(spot[3], spot[3]),
			BackgroundColor3 = palette.Steam,
			Visible = false,
			ZIndex = 6,
			Parent = icon,
		})
		corner(puff, Tokens.Radius.Pill)
		make("UIStroke", { Color = palette.Stroke, Thickness = Tokens.Stroke.Thin, Parent = puff })
		table.insert(self._puffs, puff)
	end
	local tube = make("Frame", {
		Name = "Tube",
		Position = UDim2.fromOffset(9, 4),
		Size = UDim2.fromOffset(14, 36),
		BackgroundColor3 = palette.Track,
		ZIndex = 4,
		Parent = icon,
	})
	corner(tube, Tokens.Radius.Pill)
	make("UIStroke", { Color = palette.Stroke, Thickness = Tokens.Stroke.Regular, Parent = tube })
	self._mercury = make("Frame", {
		Name = "Mercury",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(0, 6, 0.2, 0),
		BackgroundColor3 = palette.Calm,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = tube,
	})
	corner(self._mercury, Tokens.Radius.Pill)
	self._bulb = make("Frame", {
		Name = "Bulb",
		Position = UDim2.fromOffset(4, 32),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = palette.Calm,
		ZIndex = 5,
		Parent = icon,
	})
	corner(self._bulb, Tokens.Radius.Pill)
	make("UIStroke", { Color = palette.Stroke, Thickness = Tokens.Stroke.Regular, Parent = self._bulb })

	self._label = make("TextLabel", {
		Name = "StageLabel",
		Position = UDim2.fromOffset(TRACK_X, 8),
		Size = UDim2.fromOffset(150, 26),
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = Tokens.TextSize.Label,
		TextColor3 = palette.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = HeatGauge.Labels.Calm,
		ZIndex = 4,
		Parent = card,
	})

	local tag = make("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(110, 26),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Tokens.Space.XS),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tag,
	})
	local clock = make("Frame", {
		Name = "Clock",
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = palette.Track,
		LayoutOrder = 1,
		Visible = false,
		ZIndex = 4,
		Parent = tag,
	})
	corner(clock, Tokens.Radius.Pill)
	make("UIStroke", { Color = palette.Stroke, Thickness = Tokens.Stroke.Thin, Parent = clock })
	make("Frame", {
		Name = "HandUp",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, 6),
		BackgroundColor3 = palette.Stroke,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = clock,
	})
	make("Frame", {
		Name = "HandRight",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(5, 2),
		BackgroundColor3 = palette.Stroke,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = clock,
	})
	self._clock = clock
	self._tagText = make("TextLabel", {
		Name = "TagText",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = palette.TextSecondary,
		Text = "HEAT",
		LayoutOrder = 2,
		ZIndex = 4,
		Parent = tag,
	})

	-- Track. The fill area is always full width and coloured; a mask in the
	-- track colour covers the empty part from the right, so stripes keep their
	-- size while the bar drains.
	local track = make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(TRACK_X, TRACK_Y),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
		BackgroundColor3 = palette.Track,
		ZIndex = 4,
		Parent = card,
	})
	corner(track, Tokens.Radius.Pill)
	make("UIStroke", { Color = palette.Stroke, Thickness = Tokens.Stroke.Regular, Parent = track })
	self._track = track
	-- A CanvasGroup clips everything inside it (including the slanted stripe
	-- bars) to the rounded pill shape.
	local fillArea = make("CanvasGroup", {
		Name = "FillArea",
		Position = UDim2.fromOffset(TRACK_INSET, TRACK_INSET),
		Size = UDim2.new(1, -2 * TRACK_INSET, 1, -2 * TRACK_INSET),
		BackgroundColor3 = palette.Calm,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})
	corner(fillArea, Tokens.Radius.Pill)
	self._fillArea = fillArea
	local stripes = make("Frame", {
		Name = "Stripes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = fillArea,
	})
	self._stripes = stripes
	self._stripeBars = {}
	for i = 0, STRIPE_COUNT - 1 do
		local bar = make("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((i + 0.5) / STRIPE_COUNT, 0.5),
			Size = UDim2.new(0, STRIPE_WIDTH, 2.5, 0),
			Rotation = 30,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = stripes,
		})
		table.insert(self._stripeBars, bar)
	end
	self._mask = make("Frame", {
		Name = "EmptyMask",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Track,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = fillArea,
	})

	-- Tick marks at the Warning and Critical thresholds (hidden in Meltdown,
	-- where the bar shows time instead of heat).
	self._ticks = {}
	for _, threshold in { HeatGauge.Thresholds.Warning, HeatGauge.Thresholds.Critical } do
		local x = TRACK_X + TRACK_INSET + threshold * (TRACK_W - 2 * TRACK_INSET)
		local mark = make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(x, TRACK_Y + 4),
			Size = UDim2.fromOffset(3, 9),
			BackgroundColor3 = palette.Stroke,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = card,
		})
		corner(mark, Tokens.Radius.Pill)
		table.insert(self._ticks, mark)
	end

	self:_applyStage()
	self:_setFill(0, true)
	return self
end

function HeatGauge._applyStage(self: any)
	local palette: Tokens.Palette = self._palette
	local stage: HeatStage = self._stage
	local meltdown = stage == "Meltdown"
	local danger = stage == "Critical" or meltdown

	local stageColor = if stage == "Calm"
		then palette.Calm
		elseif stage == "Warning" then palette.Warning
		else palette.Danger

	self._label.Text = HeatGauge.Labels[stage]
	self._label.TextColor3 = if meltdown then palette.Danger else palette.Text
	self._tagText.Text = if meltdown then "ESCAPE TIME" else "HEAT"
	self._tagText.TextColor3 = if meltdown then palette.Text else palette.TextSecondary
	self._clock.Visible = meltdown

	self._bulb.BackgroundColor3 = stageColor
	self._mercury.BackgroundColor3 = stageColor
	self._glow.BackgroundColor3 = if stage == "Warning" then palette.Warning else palette.Danger

	-- Meltdown: dark track so the striped countdown cannot be mistaken for heat.
	local trackColor = if meltdown then palette.Stroke else palette.Track
	self._track.BackgroundColor3 = trackColor
	self._mask.BackgroundColor3 = trackColor
	self._fillArea.BackgroundColor3 = stageColor
	for _, mark in self._ticks do
		mark.Visible = not meltdown
	end

	-- Critical: faint navy stripes over red. Meltdown: cream danger stripes.
	self._stripes.Visible = danger
	for _, bar in self._stripeBars do
		bar.BackgroundColor3 = if meltdown then palette.StripeLight else palette.Stroke
		bar.BackgroundTransparency = if meltdown then 0 else 0.7
	end

	local puffCount = PUFFS[stage]
	for i, puff in self._puffs do
		puff.Visible = i <= puffCount
		puff.BackgroundColor3 = if meltdown then palette.Smoke else palette.Steam
	end

	local targetScale = STAGE_SCALE[stage]
	if self._scaleTween then
		self._scaleTween:Cancel()
		self._scaleTween = nil
	end
	if self._reduced then
		self._stageScale.Scale = targetScale
	else
		local tween = TweenService:Create(
			self._stageScale,
			TweenInfo.new(Tokens.Motion.Panel, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = targetScale }
		)
		self._scaleTween = tween
		tween:Play()
	end
end

function HeatGauge._setFill(self: any, fill: number, instant: boolean)
	local previous = self._fill
	self._fill = fill
	if self._fillTween then
		self._fillTween:Cancel()
		self._fillTween = nil
	end
	local target = UDim2.fromScale(1 - fill, 1)
	if instant or self._reduced then
		self._mask.Size = target
		return
	end
	local duration = if previous - fill > 0.3 then Tokens.Motion.HeatReset else Tokens.Motion.GaugeFill
	local tween = TweenService:Create(
		self._mask,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = target }
	)
	self._fillTween = tween
	tween:Play()
end

-- Pulse frequency for the current state, or 0 for no pulse.
function HeatGauge._targetPulseHz(self: any): number
	if self._reduced then
		return 0
	end
	local stage: HeatStage = self._stage
	local hz = 0
	if stage == "Warning" then
		hz = Tokens.Motion.WarningPulseHz
	elseif stage == "Critical" then
		local t = math.clamp((self._heat - HeatGauge.Thresholds.Critical) / (1 - HeatGauge.Thresholds.Critical), 0, 1)
		hz = Tokens.Motion.CriticalPulseStartHz + (Tokens.Motion.PulseMaxHz - Tokens.Motion.CriticalPulseStartHz) * t
	elseif stage == "Meltdown" then
		hz = Tokens.Motion.PulseMaxHz
	end
	-- Hard ceiling from decision 0008: never three or more flashes per second.
	return math.min(hz, Tokens.Motion.FlashCeilingHz - 0.01)
end

function HeatGauge._updateEmphasis(self: any)
	local palette: Tokens.Palette = self._palette
	local stage: HeatStage = self._stage
	local danger = stage == "Critical" or stage == "Meltdown"
	local hz = self:_targetPulseHz()
	self._pulseHz = hz

	if hz <= 0 then
		if self._pulsing then
			self._pulseTrove:Clean()
			self._pulsing = false
		end
		-- Steady styling: used for Calm, and for every stage with reduced motion.
		if danger then
			self._glow.BackgroundTransparency = 0.55
			self._cardStroke.Color = palette.Danger
			self._cardStroke.Thickness = Tokens.Stroke.Thick
		elseif stage == "Warning" then
			self._glow.BackgroundTransparency = 0.82
			self._cardStroke.Color = palette.Stroke
			self._cardStroke.Thickness = Tokens.Stroke.Regular
		else
			self._glow.BackgroundTransparency = 1
			self._cardStroke.Color = palette.Stroke
			self._cardStroke.Thickness = Tokens.Stroke.Regular
		end
		return
	end

	if not self._pulsing then
		self._pulsing = true
		self._phase = 0
		self._pulseTrove:Connect(RunService.RenderStepped, function(dt: number)
			self._phase = (self._phase + dt * self._pulseHz) % 1
			local wave = 0.5 - 0.5 * math.cos(self._phase * 2 * math.pi)
			local isDanger = self._stage == "Critical" or self._stage == "Meltdown"
			if isDanger then
				self._glow.BackgroundTransparency = 0.88 - 0.43 * wave
				self._cardStroke.Color = palette.Stroke:Lerp(palette.Danger, wave)
				self._cardStroke.Thickness = Tokens.Stroke.Regular + wave
			else
				self._glow.BackgroundTransparency = 0.94 - 0.14 * wave
				self._cardStroke.Color = palette.Stroke
				self._cardStroke.Thickness = Tokens.Stroke.Regular
			end
		end)
	end
end

-- heat01: 0 to 1. stage: from Lane 1; if nil it is derived from heat (never
-- Meltdown). meltdownRemaining01: escape time left, 1 to 0, used only when the
-- stage is "Meltdown".
function HeatGauge.set(self: any, heat01: number, stage: HeatStage?, meltdownRemaining01: number?)
	local heat = clamp01(heat01)
	local resolved: HeatStage = stage or HeatGauge.stageFor(heat)
	local changed = resolved ~= self._stage
	local crossesMeltdown = changed and (resolved == "Meltdown" or self._stage == "Meltdown")
	self._heat = heat
	self._stage = resolved
	if changed then
		self:_applyStage()
	end

	local meltdown = resolved == "Meltdown"
	local fill = if meltdown then clamp01(if meltdownRemaining01 == nil then 1 else meltdownRemaining01) else heat
	-- The countdown is streamed by Lane 1, so it is shown directly, not tweened.
	self:_setFill(fill, meltdown or crossesMeltdown)
	self._mercury.Size = UDim2.new(0, 6, if meltdown then 1 else 0.15 + 0.85 * heat, -4)
	self:_updateEmphasis()
end

function HeatGauge.setReducedMotion(self: any, reduced: boolean)
	if self._reduced == reduced then
		return
	end
	self._reduced = reduced
	self:_applyStage()
	self:_setFill(self._fill, true)
	self:_updateEmphasis()
end

function HeatGauge.getDebugState(self: any): DebugState
	return {
		stage = self._stage,
		label = self._label.Text,
		tag = self._tagText.Text,
		heat = self._heat,
		fill = self._fill,
		reducedMotion = self._reduced,
		pulsing = self._pulsing,
		pulseHz = self._pulseHz,
		stageScale = STAGE_SCALE[self._stage],
		labelFits = self._label.TextFits,
		tagFits = self._tagText.TextFits,
	}
end

-- Number of tweens still playing; used by the preview to prove cleanup.
function HeatGauge.activeTweens(self: any): number
	local count = 0
	for _, tween in { self._fillTween, self._scaleTween } do
		if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
			count += 1
		end
	end
	return count
end

function HeatGauge.destroy(self: any)
	-- Only the latest tween per slot is kept; cancel both before the
	-- instances they animate are destroyed.
	for _, tween in { self._fillTween, self._scaleTween } do
		if tween then
			tween:Cancel()
			tween:Destroy()
		end
	end
	self._fillTween = nil
	self._scaleTween = nil
	self._trove:Destroy()
end

return HeatGauge
