--!strict
-- Heat panel for the run HUD: a cartoon dashboard instrument. Lane 3
-- presentation only (decision 0008 and its amendment).
--
-- It shows what it is given: heat (0 to 1) and the stage from gameplay
-- (Lane 1). It never decides a stage change, a Meltdown, an escape or a
-- crash, and it shows no escape timer. Stage values are PascalCase strings:
-- "Calm", "Warning", "Critical", "Meltdown"; labels are "Cool", "Hot",
-- "Too hot!", "Losing control!".
--
-- All animation runs in one listener on the shared AlarmClock (one
-- RenderStepped connection for every alarm effect). Values are eased with
-- exponential smoothing, which is frame-rate independent. With reduced
-- motion, essential values (fill, colour, label, stage styling) snap and all
-- decorative movement (pulse, sirens alternating, rattle, jolt, slosh,
-- bubbles, heat lines, smoke drift, stripe travel, HOP NOW! pulse,
-- cross-fade) is removed.
--
-- Provisional interface (needs Lane 1 agreement, decision 0007):
--   gauge:set(heat01, stage)  -- a third argument (old meltdownRemaining01) is ignored
--   gauge:snap(heat01, stage) -- shows a state with no transition (first mount)
--   gauge:jolt(strength?)     -- presentation-only bump reaction; changes no Heat
--   gauge.Cue                 -- Signal(cue, stage) for future audio: "Stage" on a
--                               stage change, "AlarmPeak" once per alarm cycle

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlarmClock = require(script.Parent.Parent.AlarmClock)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type HeatStage = "Calm" | "Warning" | "Critical" | "Meltdown"

-- Panel geometry in design px.
local WIDTH = 320
local HEIGHT = 92
local TRACK_X = 70
local TRACK_Y = 54
local TRACK_H = 24
local TRACK_W = WIDTH - TRACK_X - 14
local TRACK_INSET = 3
local TAB_SIZE = Vector2.new(140, 26)
local HALO_MAX = 10 -- how far the alarm halo reaches outside the panel
local SMOKE_PUFFS = 7
local BUBBLES = 3
local HEAT_LINES = 2
-- Hazard stripes: STRIPE_COUNT spacings across the bar, plus two spare
-- stripes at each end so the diagonal pattern stays seamless while it moves.
local STRIPE_COUNT = 16
local STRIPE_SPARE = 2
local HOP_PULSE = 0.08 -- HOP NOW! grows 1.00 -> 1.08 -> 1.00 on each panel peak
local GLOW_REACH = 6 -- Meltdown edge glow beyond the bar's outline
-- Smoke puffs: varied sizes and irregular spacing along one plume, so the
-- puffs overlap into a connected cloud instead of an even chain of beads.
local PUFF_SIZE = { 1.0, 0.72, 1.18, 0.86, 1.08, 0.78, 0.96 }
local PUFF_OFFSET = { 0, 0.13, 0.31, 0.44, 0.6, 0.73, 0.87 }
-- Thermometer geometry (card coordinates, design px), about 20% smaller than
-- revision 2 so the whole instrument fits inside the card.
local THERMO_X = 30
local TUBE_TOP = 26
local TUBE_SIZE = Vector2.new(15, 38)
local BULB_Y = 68
local BULB_SIZE = 24
-- The bottom of the tube sits behind the bulb.
local LIQUID_HIDDEN = 10
local LIQUID_RANGE = 25
-- Siren layout: mirrored about the centre, one each side of the title tab,
-- centred on the card's top-border line (UIStroke draws outside the frame).
local SIREN_SIZE = Vector2.new(22, 18)
local SIREN_GAP = 10
local SIREN_OFFSET = TAB_SIZE.X / 2 + SIREN_GAP + SIREN_SIZE.X / 2
local BORDER_CENTRE = -Tokens.Stroke.Regular / 2

local RANK: { [string]: number } = { Calm = 0, Warning = 1, Critical = 2, Meltdown = 3 }

local HeatGauge = {}
HeatGauge.__index = HeatGauge

HeatGauge.Size = Vector2.new(WIDTH, HEIGHT)
-- How far effects can reach outside the panel, for layout margins.
HeatGauge.EffectMargin = HALO_MAX

-- Provisional copy of the outline's Proposed thresholds. Used only to place
-- the tick marks and, when no stage is supplied, to derive Calm, Warning or
-- Critical. Lane 1 owns the real values; Meltdown is never derived here.
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

-- Stage emphasis (the panel grows a little). RunHud can lower the limit so
-- the panel and its effects stay 24 px inside the safe area.
local STAGE_SCALE: { [string]: number } = {
	Calm = 1,
	Warning = 1.05,
	Critical = 1.1,
	Meltdown = 1.12,
}

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

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Frame-rate-independent easing toward a target; snaps when close.
local function approach(current: number, target: number, dt: number, rate: number): number
	local value = target + (current - target) * math.exp(-dt * rate)
	if math.abs(value - target) < 0.001 then
		return target
	end
	return value
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

local function outline(parent: Instance, color: Color3, thickness: number): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function circle(parent: Instance, name: string, size: number, color: Color3, z: number): Frame
	local f = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	corner(f, Tokens.Radius.Pill)
	return f
end

function HeatGauge.new(parent: Instance, palette: Tokens.Palette, reducedMotion: boolean)
	local self = setmetatable({}, HeatGauge)
	self._trove = Trove.new()
	self._palette = palette
	self._reduced = reducedMotion
	self.Cue = Signal.new()
	self._trove:Add(function()
		self.Cue:Destroy()
	end)

	-- Supplied state.
	self._heat = 0
	self._stage = "Calm" :: HeatStage
	-- Presented (eased) state.
	self._shownHeat = 0
	self._glow = 0
	self._bubbles = 0
	self._lines = 0
	self._rattle = 0
	self._alarm = 0
	self._melt = 0
	self._scale = 1
	self._maxScale = STAGE_SCALE.Meltdown
	self._smokeScale = 1
	self._time = 0
	self._bumpAge = math.huge
	self._bumpStrength = 0
	self._labelFade = 1
	self._lastPhase = 0
	self._snapNext = false
	self._smokeShown = true
	self._updateCost = 0
	self._updateFrames = 0

	local font = Tokens.font()

	local root = make("Frame", {
		Name = "HeatGauge",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	self._trove:Add(root)
	self.Root = root

	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._body = body
	self._stageScale = make("UIScale", { Name = "StageScale", Scale = 1, Parent = body })

	-- Alarm halo behind the panel.
	self._halo = make("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundColor3 = palette.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = body,
	})
	corner(self._halo, UDim.new(0, 28))

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
	self._card = card
	self._cardStroke = outline(card, palette.Stroke, Tokens.Stroke.Regular)

	-- ENGINE HEAT title tab, centred on the panel's top edge. Constant size.
	local tab = make("Frame", {
		Name = "TitleTab",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(TAB_SIZE.X, TAB_SIZE.Y),
		BackgroundColor3 = palette.Card,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = body,
	})
	corner(tab, Tokens.Radius.Small)
	outline(tab, palette.Stroke, Tokens.Stroke.Regular)
	self._title = make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = Tokens.TextSize.Minimum,
		TextColor3 = palette.Text,
		Text = "ENGINE HEAT",
		ZIndex = 13,
		Parent = tab,
	})

	-- Siren lights: identical, mirrored about the panel centre on the
	-- straight top edge, one each side of the title tab, centred on the
	-- top-border line. Positions come from shared layout values only.
	self._sirens = {}
	for i, side in { -1, 1 } do
		local holder = make("Frame", {
			Name = if i == 1 then "SirenLeft" else "SirenRight",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * SIREN_OFFSET, BORDER_CENTRE / HEIGHT, 0),
			Size = UDim2.fromOffset(SIREN_SIZE.X, SIREN_SIZE.Y),
			BackgroundTransparency = 1,
			ZIndex = 10,
			Parent = body,
		})
		local glow = circle(holder, "Glow", 30, palette.Danger, 9)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.BackgroundTransparency = 1
		local dome = make("Frame", {
			Name = "Dome",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.fromOffset(16, 12),
			BackgroundColor3 = palette.SirenOff,
			BorderSizePixel = 0,
			ZIndex = 11,
			Parent = holder,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dome })
		local domeStroke = outline(dome, palette.Stroke, Tokens.Stroke.Thin)
		local base = make("Frame", {
			Name = "Base",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(SIREN_SIZE.X, 6),
			BackgroundColor3 = palette.Stroke,
			BorderSizePixel = 0,
			ZIndex = 11,
			Parent = holder,
		})
		corner(base, UDim.new(0, 2))
		table.insert(self._sirens, { holder = holder, dome = dome, glow = glow, base = base, stroke = domeStroke })
	end

	-- Thermometer instrument. Its frame covers the left of the card with the
	-- same coordinates as the card, so the numbers below are card positions.
	-- Everything in it moves together for rattle and jolt; its rest position
	-- is restored exactly. Clearance budget (design px at scale 1.0, strokes
	-- included): cap top at 13 and bulb bottom at 83 inside a 92 px card, so
	-- with the largest rattle, jiggle and jolt the gaps to the inner border
	-- stay at 8 px or more; the right edge (heat lines) stays 8 px or more
	-- from the stage text.
	local instrument = make("Frame", {
		Name = "Instrument",
		Size = UDim2.fromOffset(TRACK_X - 6, HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})
	self._instrument = instrument
	self._instrumentRest = instrument.Position

	-- Bulb glow behind the bulb.
	self._bulbGlow = circle(instrument, "BulbGlow", 34, palette.Calm, 4)
	self._bulbGlow.Position = UDim2.fromOffset(THERMO_X, BULB_Y)
	self._bulbGlow.BackgroundTransparency = 1

	-- Glass tube with a thick navy silhouette.
	local tube = make("Frame", {
		Name = "Tube",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(THERMO_X, TUBE_TOP),
		Size = UDim2.fromOffset(TUBE_SIZE.X, TUBE_SIZE.Y),
		BackgroundColor3 = palette.Glass,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = instrument,
	})
	corner(tube, Tokens.Radius.Pill)
	self._tubeStroke = outline(tube, palette.Stroke, Tokens.Stroke.Regular)
	self._tube = tube
	self._liquid = make("Frame", {
		Name = "Liquid",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(9, 0),
		BackgroundColor3 = palette.Calm,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = tube,
	})
	corner(self._liquid, UDim.new(0, 3))
	-- A navy surface line keeps the level readable when the liquid is pale.
	self._meniscus = make("Frame", {
		Name = "Surface",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = palette.Stroke,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = self._liquid,
	})
	self._bubbleFrames = {}
	for i = 1, BUBBLES do
		local b = circle(tube, "Bubble" .. i, 3, Color3.new(1, 1, 1), 7)
		b.BackgroundTransparency = 1
		table.insert(self._bubbleFrames, b)
	end
	-- Shine streak on the glass, kept quieter than the liquid.
	make("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(2, 5),
		Size = UDim2.fromOffset(2, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = tube,
	})
	-- Crack marks, shown only during Meltdown.
	self._cracks = {}
	for i, spec in { { 8, 10, 32 }, { 6, 19, -28 }, { 9, 28, 24 } } do
		local crack = make("Frame", {
			Name = "Crack" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spec[1], spec[2]),
			Size = UDim2.fromOffset(2, 7),
			Rotation = spec[3],
			BackgroundColor3 = palette.Stroke,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = tube,
		})
		table.insert(self._cracks, crack)
	end
	-- Tick marks beside the tube.
	for i = 1, 3 do
		make("Frame", {
			Name = "Tick" .. i,
			Position = UDim2.fromOffset(THERMO_X + 12, TUBE_TOP + 1 + i * 8),
			Size = UDim2.fromOffset(5, 2),
			BackgroundColor3 = palette.Stroke,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = instrument,
		})
	end
	-- Bulb.
	self._bulb = circle(instrument, "Bulb", BULB_SIZE, palette.Calm, 6)
	self._bulb.Position = UDim2.fromOffset(THERMO_X, BULB_Y)
	outline(self._bulb, palette.Stroke, Tokens.Stroke.Regular)
	local highlight = circle(self._bulb, "Highlight", 6, Color3.new(1, 1, 1), 7)
	highlight.Position = UDim2.fromOffset(8, 8)
	highlight.BackgroundTransparency = 0.3

	-- Radiator cap (chrome) on top of the tube; pivots at its bottom centre.
	local cap = make("Frame", {
		Name = "Cap",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(THERMO_X, TUBE_TOP + 2),
		Size = UDim2.fromOffset(22, 14),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = instrument,
	})
	self._cap = cap
	self._capRest = cap.Position
	local capBase = make("Frame", {
		Name = "Base",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(22, 7),
		BackgroundColor3 = palette.Chrome,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = cap,
	})
	corner(capBase, UDim.new(0, 3))
	outline(capBase, palette.Stroke, Tokens.Stroke.Thin)
	local capTop = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(13, 7),
		BackgroundColor3 = palette.Chrome,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = cap,
	})
	corner(capTop, UDim.new(0, 3))
	outline(capTop, palette.Stroke, Tokens.Stroke.Thin)
	make("Frame", {
		Name = "Shade",
		Position = UDim2.new(0, 2, 1, -3),
		Size = UDim2.new(1, -4, 0, 2),
		BackgroundColor3 = palette.ChromeShade,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = capBase,
	})
	make("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(3, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = capTop,
	})

	-- Heat lines rising beside the ticks (Hot and above), kept inside the panel.
	self._lineFrames = {}
	for i = 1, HEAT_LINES do
		local line = make("Frame", {
			Name = "HeatLine" .. i,
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(3, 9),
			BackgroundColor3 = palette.Warning,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = instrument,
		})
		corner(line, Tokens.Radius.Pill)
		table.insert(self._lineFrames, line)
	end

	-- Smoke: a fixed pool of puffs reused in a loop (same budget as revision
	-- 3: 7 puffs x 2 circles x their corners = 28 instances). Each puff is a
	-- light grey edge with a charcoal core; puffs grow, overlap and fade as
	-- they rise up and to the left, away from the left siren and the title tab.
	self._puffs = {}
	for i = 1, SMOKE_PUFFS do
		local puff = circle(instrument, "Smoke" .. i, 10, palette.SmokeLight, 12)
		puff.BackgroundTransparency = 1
		local core = circle(puff, "Core", 6, palette.SmokeCore, 13)
		core.Position = UDim2.fromScale(0.52, 0.56)
		core.Size = UDim2.fromScale(0.7, 0.7)
		core.BackgroundTransparency = 1
		table.insert(self._puffs, { outer = puff, inner = core })
	end

	-- Stage label (two layers for a short cross-fade) in a fixed-width area.
	local labelArea = make("Frame", {
		Name = "LabelArea",
		Position = UDim2.fromOffset(TRACK_X, 18),
		Size = UDim2.fromOffset(132, 26),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = card,
	})
	self._labels = {}
	for i = 1, 2 do
		table.insert(
			self._labels,
			make("TextLabel", {
				Name = "Label" .. i,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = font,
				TextSize = Tokens.TextSize.Label,
				TextColor3 = palette.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = HeatGauge.Labels.Calm,
				TextTransparency = if i == 1 then 0 else 1,
				ZIndex = 5,
				Parent = labelArea,
			})
		)
	end
	self._labelFront = 1

	-- HOP NOW! instruction (not a button): danger-red text with a navy
	-- outline, right-aligned and vertically centred with the stage label. It
	-- pulses in scale on the panel's alarm peaks; the frame is anchored at its
	-- right-centre, so the right edge stays still while it grows.
	local hop = make("Frame", {
		Name = "HopNow",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, 18 + 13),
		Size = UDim2.fromOffset(104, 26),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = card,
	})
	self._hop = hop
	self._hopPulse = make("UIScale", { Name = "Pulse", Scale = 1, Parent = hop })
	self._hopText = make("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = Tokens.TextSize.Label,
		TextColor3 = palette.Danger,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "HOP NOW!",
		TextTransparency = 1,
		ZIndex = 7,
		Parent = hop,
	})
	self._hopStroke = make("UIStroke", {
		Color = palette.Stroke,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Transparency = 1,
		Parent = self._hopText,
	})

	-- Meltdown edge glow behind the bar, pulsing with the panel.
	self._edgeGlow = make("Frame", {
		Name = "EdgeGlow",
		Position = UDim2.fromOffset(TRACK_X - GLOW_REACH, TRACK_Y - GLOW_REACH),
		Size = UDim2.fromOffset(TRACK_W + 2 * GLOW_REACH, TRACK_H + 2 * GLOW_REACH),
		BackgroundColor3 = palette.MeltdownGlow,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = card,
	})
	corner(self._edgeGlow, Tokens.Radius.Pill)

	-- Heat bar: a fixed temperature scale revealed from the left. A
	-- track-coloured mask covers the part above the current Heat.
	local track = make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(TRACK_X, TRACK_Y),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
		BackgroundColor3 = palette.Track,
		ZIndex = 4,
		Parent = card,
	})
	corner(track, Tokens.Radius.Pill)
	outline(track, palette.Stroke, Tokens.Stroke.Regular)
	local fillArea = make("CanvasGroup", {
		Name = "FillArea",
		Position = UDim2.fromOffset(TRACK_INSET, TRACK_INSET),
		Size = UDim2.new(1, -2 * TRACK_INSET, 1, -2 * TRACK_INSET),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})
	corner(fillArea, Tokens.Radius.Pill)
	-- The temperature scale lives on its own frame: a UIGradient on the
	-- CanvasGroup itself would tint the mask and stripes too.
	local scaleFrame = make("Frame", {
		Name = "TemperatureScale",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = fillArea,
	})
	self._gradient = make("UIGradient", { Color = Tokens.heatColorSequence(palette), Parent = scaleFrame })
	-- Meltdown wash: turns the full bar a saturated danger red (steady; the
	-- edge glow carries the pulse). The temperature scale stays underneath.
	self._barFlash = make("Frame", {
		Name = "OverheatWash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.MeltdownBar,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = fillArea,
	})
	-- Diagonal stripes, clipped by the CanvasGroup. In Meltdown they travel
	-- sideways one stripe spacing per alarm cycle; because the pattern repeats
	-- every spacing, the wrap from phase 1 back to 0 is invisible.
	local stripes = make("Frame", {
		Name = "Stripes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = fillArea,
	})
	self._stripeBars = {}
	for i = -STRIPE_SPARE, STRIPE_COUNT - 1 + STRIPE_SPARE do
		table.insert(self._stripeBars, {
			index = i,
			frame = make("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((i + 0.5) / STRIPE_COUNT, 0.5),
				Size = UDim2.new(0, 7, 2.5, 0),
				Rotation = 30,
				BackgroundColor3 = palette.Stroke,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = stripes,
			}),
		})
	end
	self._mask = make("Frame", {
		Name = "EmptyMask",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Track,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = fillArea,
	})
	-- Navy marker at the fill tip, so the level reads even where the scale is
	-- pale (the cream stop near 35%) against the white track.
	self._tipMarker = make("Frame", {
		Name = "TipMarker",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = palette.Stroke,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = self._mask,
	})
	for _, threshold in { HeatGauge.Thresholds.Warning, HeatGauge.Thresholds.Critical } do
		local mark = make("Frame", {
			Name = "ThresholdTick",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(TRACK_X + TRACK_INSET + threshold * (TRACK_W - 2 * TRACK_INSET), TRACK_Y + 4),
			Size = UDim2.fromOffset(3, 9),
			BackgroundColor3 = palette.Stroke,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = card,
		})
		corner(mark, Tokens.Radius.Pill)
	end

	self._trove:Add(AlarmClock.subscribe(function(dt: number, phase: number)
		self:_update(dt, phase)
	end))
	self._trove:Add(function()
		AlarmClock.setRate(0)
	end)

	self:_update(1, 0)
	return self
end

-- Clears every alarm and Meltdown effect immediately and returns all moving
-- parts to their rest state (used when a Hop resets Heat).
function HeatGauge._resetEffects(self: any)
	self._alarm = 0
	self._melt = 0
	self._rattle = 0
	self._bumpAge = math.huge
	self._instrument.Position = self._instrumentRest
	self._cap.Position = self._capRest
	self._cap.Rotation = 0
	AlarmClock.setRate(0)
	-- Apply the cleared state to every visual now, not on the next frame.
	self._lastPhase = 0
	self:_update(0, 0)
end

function HeatGauge.set(self: any, heat01: number, stage: HeatStage?, _ignoredLegacy: number?)
	local heat = clamp01(heat01)
	local resolved: HeatStage = stage or HeatGauge.stageFor(heat)
	local previous: HeatStage = self._stage
	self._heat = heat
	if resolved ~= previous then
		self._stage = resolved
		if RANK[resolved] < RANK[previous] and (resolved == "Calm" or RANK[previous] >= RANK.Critical) then
			self:_resetEffects()
		end
		-- Cross-fade the label (instant with reduced motion).
		local front = self._labels[self._labelFront]
		local backIndex = 3 - self._labelFront
		local back = self._labels[backIndex]
		back.Text = HeatGauge.Labels[resolved]
		self._labelFront = backIndex
		self._labelFade = if self._reduced then 1 else 0
		if self._reduced then
			front.TextTransparency = 1
			back.TextTransparency = 0
		end
		self.Cue:Fire("Stage", resolved)
	end
	if self._reduced then
		self:_update(0, AlarmClock.getPhase())
	end
end

-- Shows a state as it is, with no entrance fill, eased effect build-up,
-- label cross-fade or stage cue (used when the HUD first mounts). An ongoing
-- Critical or Meltdown alarm, smoke and stripes keep running afterwards.
function HeatGauge.snap(self: any, heat01: number, stage: HeatStage?)
	local heat = clamp01(heat01)
	local resolved: HeatStage = stage or HeatGauge.stageFor(heat)
	self._heat = heat
	self._stage = resolved
	self._bumpAge = math.huge
	local front = self._labels[self._labelFront]
	front.Text = HeatGauge.Labels[resolved]
	front.TextTransparency = 0
	self._labels[3 - self._labelFront].TextTransparency = 1
	self._labelFade = 1
	self._snapNext = true
	self:_update(0, AlarmClock.getPhase())
end

-- Presentation-only bump reaction: a short jolt of the instrument and a
-- slosh of the liquid that settles back to the supplied Heat. Changes no
-- Heat value. Ignored with reduced motion.
function HeatGauge.jolt(self: any, strength: number?)
	if self._reduced then
		return
	end
	self._bumpAge = 0
	self._bumpStrength = math.clamp(strength or 1, 0, 1.5)
end

function HeatGauge.setReducedMotion(self: any, reduced: boolean)
	self._reduced = reduced
	if reduced then
		self._bumpAge = math.huge
		self._labelFade = 1
		for i, label in self._labels do
			label.TextTransparency = if i == self._labelFront then 0 else 1
		end
	end
	self:_update(0, AlarmClock.getPhase())
end

-- Layout limits from RunHud: the largest stage growth that keeps the panel
-- and its effects 24 px inside the safe area, and how far smoke may drift.
function HeatGauge.setLayout(self: any, maxStageScale: number, smokeScale: number)
	self._maxScale = math.max(1, maxStageScale)
	self._smokeScale = math.clamp(smokeScale, 0.3, 1)
end

function HeatGauge._update(self: any, dt: number, phase: number)
	local started = os.clock()
	local palette: Tokens.Palette = self._palette
	local reduced: boolean = self._reduced
	local stage: HeatStage = self._stage
	local meltdown = stage == "Meltdown"
	local critical = stage == "Critical"
	-- A snap (first mount) sets every eased value straight to its target.
	local snapping = reduced or self._snapNext
	self._snapNext = false
	self._time += dt

	-- 1. Heat level and colour (continuous). Meltdown shows a full bar.
	local target = if meltdown then 1 else self._heat
	self._shownHeat = if snapping then target else approach(self._shownHeat, target, dt, Tokens.Motion.HeatSmoothing)
	local level = self._shownHeat
	local color = Tokens.heatColor(level, palette)

	-- 2. Effect intensities, eased so they never pop in at full strength.
	local ease = Tokens.Motion.EffectSmoothing
	local function towards(current: number, goal: number): number
		return if snapping then goal else approach(current, goal, dt, ease)
	end
	self._glow = towards(self._glow, smoothstep(0.55, 1, level))
	self._bubbles = towards(self._bubbles, smoothstep(0.55, 0.85, level))
	self._lines = towards(self._lines, smoothstep(0.58, 0.85, level))
	local urgency = smoothstep(HeatGauge.Thresholds.Critical, 1, level)
	self._rattle = towards(self._rattle, if critical or meltdown then 0.4 + 0.6 * urgency else 0)
	self._alarm = towards(self._alarm, if meltdown then 1 elseif critical then 0.6 + 0.4 * urgency else 0)
	self._melt = towards(self._melt, if meltdown then 1 else 0)
	self._scale = towards(self._scale, math.min(STAGE_SCALE[stage], self._maxScale))

	-- 3. One alarm clock for the panel, sirens and later car effects.
	local rate = 0
	if not reduced then
		if meltdown then
			rate = Tokens.Motion.AlarmMeltdownHz
		elseif critical then
			rate = Tokens.Motion.AlarmCriticalStartHz
				+ (Tokens.Motion.AlarmCriticalEndHz - Tokens.Motion.AlarmCriticalStartHz) * urgency
		end
	end
	AlarmClock.setRate(rate)
	if rate > 0 and phase < self._lastPhase then
		self.Cue:Fire("AlarmPeak", stage)
	end
	self._lastPhase = phase
	local wave = if rate > 0 then AlarmClock.wave(0) else 0
	local waveRight = if rate > 0 then AlarmClock.wave(0.5) else 0
	local alarm = self._alarm

	-- 4. Panel alarm: background between cream and light alarm red, halo,
	-- thicker border. Text stays navy; the tint stays light.
	local pulse = if reduced then 1 else 0.35 + 0.65 * wave
	self._card.BackgroundColor3 = palette.Card:Lerp(palette.AlarmTint, alarm * pulse)
	self._cardStroke.Thickness = Tokens.Stroke.Regular + alarm * pulse
	-- Keep both sirens centred on the border line as the border thickens.
	-- UDim offsets are whole pixels, so the half-stroke goes in the scale.
	for i, siren in self._sirens do
		siren.holder.Position =
			UDim2.new(0.5, (if i == 1 then -1 else 1) * SIREN_OFFSET, -self._cardStroke.Thickness / (2 * HEIGHT), 0)
	end
	self._cardStroke.Color = palette.Stroke
	local haloReach = if reduced then 6 else 6 + 4 * wave
	self._halo.Size = UDim2.new(1, 2 * haloReach * alarm, 1, 2 * haloReach * alarm)
	self._halo.BackgroundTransparency = 1 - alarm * (if reduced then 0.3 else 0.15 + 0.35 * wave)

	-- 5. Siren lights: left on the panel's phase, right opposite; solid with
	-- reduced motion.
	for i, siren in self._sirens do
		local lit = if reduced then 1 else (if i == 1 then wave else waveRight)
		local show = alarm
		siren.dome.BackgroundColor3 = palette.SirenOff:Lerp(palette.Danger, lit)
		siren.dome.BackgroundTransparency = 1 - show
		siren.base.BackgroundTransparency = 1 - show
		siren.glow.BackgroundTransparency = 1 - show * lit * (if reduced then 0.25 else 0.45)
		siren.stroke.Transparency = 1 - show
	end

	-- 6. Bar: reveal, stripes, Meltdown hazard treatment. In Meltdown the
	-- full bar is a steady saturated red with darker-red stripes travelling
	-- sideways at constant speed (one spacing per alarm cycle, from the shared
	-- phase), and the edge glow peaks with the panel. Reduced motion: the
	-- same red bar and stripes, standing still, with a steady glow.
	self._mask.Size = UDim2.fromScale(1 - level, 1)
	self._tipMarker.Visible = level > 0.01 and level < 0.99
	local melt = self._melt
	local travel = if meltdown and not reduced and rate > 0 then phase else 0
	local stripeColor = palette.Stroke:Lerp(palette.MeltdownStripe, melt)
	local stripeOpacity = alarm * (0.55 + 0.4 * melt)
	for _, bar in self._stripeBars do
		bar.frame.Position = UDim2.fromScale((bar.index + 0.5 + travel) / STRIPE_COUNT, 0.5)
		bar.frame.BackgroundColor3 = stripeColor
		bar.frame.BackgroundTransparency = 1 - stripeOpacity
	end
	self._barFlash.BackgroundTransparency = 1 - melt
	self._edgeGlow.BackgroundTransparency = 1 - melt * (if reduced then 0.55 else 0.2 + 0.65 * wave)

	-- 7. Thermometer: liquid, bulb, glow, bubbles, heat lines.
	local slosh = 0
	local joltX, joltY = 0, 0
	if self._bumpAge < Tokens.Motion.BumpSeconds then
		self._bumpAge += dt
		local age = self._bumpAge
		local decay = math.exp(-age * 7) * self._bumpStrength
		slosh = 0.08 * math.sin(age * 26) * decay
		joltX = 4 * math.sin(age * 42) * decay
		joltY = -2 * math.abs(math.sin(age * 30)) * decay
	elseif self._bumpAge ~= math.huge then
		self._bumpAge = math.huge
	end
	local tubeLevel = math.clamp(level + slosh, 0, 1)
	-- The bottom of the tube sits behind the bulb, so 0% fills only that
	-- hidden part and 100% reaches the top of the visible glass.
	self._liquid.Size = UDim2.fromOffset(9, LIQUID_HIDDEN + tubeLevel * LIQUID_RANGE)
	self._meniscus.Visible = tubeLevel > 0.02
	self._liquid.BackgroundColor3 = color
	self._bulb.BackgroundColor3 = color
	self._bulbGlow.BackgroundColor3 = color
	self._bulbGlow.BackgroundTransparency = 1 - 0.55 * self._glow
	local t = self._time
	for i, bubble in self._bubbleFrames do
		local show = if reduced then 0 else self._bubbles
		local cycle = (t * (0.5 + 0.9 * self._bubbles) + i / BUBBLES) % 1
		-- Rise from the top of the bulb to just under the liquid surface.
		local depth = tubeLevel * LIQUID_RANGE
		local y = TUBE_SIZE.Y - LIQUID_HIDDEN - cycle * math.max(0, depth - 3)
		bubble.Position = UDim2.new(0.5, (i - 2) * 3, 0, y)
		bubble.BackgroundTransparency = 1 - show * 0.85 * (if depth > 6 then 1 else 0)
	end
	for i, line in self._lineFrames do
		local show = if reduced then 0 else self._lines
		local cycle = (t * 0.9 + i * 0.5) % 1
		line.Position = UDim2.fromOffset(THERMO_X + 20 + (i - 1) * 4, TUBE_TOP + 20 - cycle * 14)
		line.BackgroundColor3 = color
		line.BackgroundTransparency = 1 - show * (1 - cycle) * 0.9
	end

	-- 8. Rattle, jolt, cap jiggle, cap lift and tilt, cracks.
	local rattle = if reduced then 0 else self._rattle
	local shakeX = 1.6 * rattle * math.sin(t * 37) + joltX
	local shakeY = 0.8 * rattle * math.cos(t * 29) + joltY
	self._instrument.Position = self._instrumentRest + UDim2.fromOffset(shakeX, shakeY)
	local jiggle = if reduced then 0 else -1.5 * math.abs(math.sin(t * 18)) * self._rattle * (1 - melt)
	local wobble = if reduced then 0 else 3 * math.sin(t * 9) * melt
	self._cap.Position = self._capRest + UDim2.fromOffset(-3 * melt, -7 * melt + jiggle)
	self._cap.Rotation = -18 * melt + wobble
	for _, crack in self._cracks do
		crack.BackgroundTransparency = 1 - melt
	end

	-- 9. Smoke from the lifted cap: one plume from a fixed pool of puffs
	-- reused in a loop. Each puff is born small just above the cap, grows,
	-- drifts up and to the left with a gentle wobble, and fades out near the
	-- top; irregular spacing and varied sizes make the puffs overlap into one
	-- billowing cloud. Still cloud when reduced. When Meltdown ends the pool is
	-- hidden once and then skipped (no work while there is no smoke).
	local spread = self._smokeScale
	if melt > 0 or self._smokeShown then
		self._smokeShown = melt > 0
		for i, puff in self._puffs do
			local x, y, size, opacity
			if reduced then
				local still = {
					{ THERMO_X - 6, TUBE_TOP - 22, 15 },
					{ THERMO_X - 12, TUBE_TOP - 30, 17 },
					{ THERMO_X - 2, TUBE_TOP - 33, 12 },
				}
				local spec = still[i]
				if spec then
					x, y, size, opacity = spec[1], spec[2], spec[3], 0.75
				else
					x, y, size, opacity = THERMO_X, 0, 0, 0
				end
			else
				local life = (t * 0.5 + PUFF_OFFSET[i]) % 1
				local sway = 3 * math.sin(t * 2.3 + i * 1.7) * life
				-- The plume leans further left as it rises (a curve, not a column).
				x = THERMO_X - 2 - (19 * life ^ 1.3 + sway) * spread
				y = TUBE_TOP - 16 - 38 * life * (0.6 + 0.4 * spread)
				size = (11 + 21 * life * (0.7 + 0.3 * spread)) * PUFF_SIZE[i]
				-- Quick fade in at the cap, soft fade out toward the top.
				opacity = 0.9 * smoothstep(0, 0.1, life) * (1 - smoothstep(0.45, 1, life))
			end
			puff.outer.Position = UDim2.fromOffset(x, y)
			puff.outer.Size = UDim2.fromOffset(size, size)
			local shown = melt * opacity
			puff.outer.BackgroundTransparency = 1 - shown
			-- A soft charcoal core: overlapping cores darken the plume's middle
			-- while the light rims form its edge.
			puff.inner.BackgroundTransparency = 1 - shown * 0.6
		end
	end

	-- 10. HOP NOW! (scale pulse on the panel's peaks; steady when reduced)
	-- and the label cross-fade.
	local hopShow = melt
	self._hopText.TextTransparency = 1 - hopShow
	self._hopStroke.Transparency = 1 - hopShow
	self._hopPulse.Scale = if reduced then 1 else 1 + HOP_PULSE * wave * melt
	if self._labelFade < 1 then
		self._labelFade = math.min(1, self._labelFade + dt / Tokens.Motion.LabelFade)
		local front = self._labels[self._labelFront]
		local back = self._labels[3 - self._labelFront]
		front.TextTransparency = 1 - self._labelFade
		back.TextTransparency = self._labelFade
	end

	-- 11. Stage growth.
	self._stageScale.Scale = self._scale

	self._updateCost += os.clock() - started
	self._updateFrames += 1
end

function HeatGauge.getDebugState(self: any): { [string]: any }
	local count = 0
	for _ in self.Root:GetDescendants() do
		count += 1
	end
	-- Every instance allocated for smoke, child shapes and corners included.
	local smokeCount = 0
	for _, puff in self._puffs do
		smokeCount += 1 + #puff.outer:GetDescendants()
	end
	local avg = if self._updateFrames > 0 then self._updateCost / self._updateFrames else 0
	return {
		stage = self._stage,
		label = self._labels[self._labelFront].Text,
		heat = self._heat,
		shownHeat = self._shownHeat,
		liquidColor = self._liquid.BackgroundColor3,
		expectedColor = Tokens.heatColor(self._shownHeat, self._palette),
		maskScale = self._mask.Size.X.Scale,
		alarm = self._alarm,
		melt = self._melt,
		rattle = self._rattle,
		alarmRate = AlarmClock.getRate(),
		reducedMotion = self._reduced,
		stageScale = self._stageScale.Scale,
		capOffset = self._cap.Position - self._capRest,
		capRotation = self._cap.Rotation,
		instrumentOffset = self._instrument.Position - self._instrumentRest,
		cardColor = self._card.BackgroundColor3,
		bumpActive = self._bumpAge ~= math.huge,
		titleFits = self._title.TextFits,
		labelFits = self._labels[self._labelFront].TextFits,
		hopFits = self._hopText.TextFits,
		hopPulse = self._hopPulse.Scale,
		edgeGlow = 1 - self._edgeGlow.BackgroundTransparency,
		smokeInstances = smokeCount,
		labelFade = self._labelFade,
		instances = count,
		avgUpdateMs = avg * 1000,
		clock = AlarmClock.stats(),
	}
end

function HeatGauge.destroy(self: any)
	self._trove:Destroy()
end

return HeatGauge
