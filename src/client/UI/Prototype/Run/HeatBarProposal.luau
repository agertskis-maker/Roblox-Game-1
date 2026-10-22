--!strict
-- PROPOSAL variant of the run Heat display (Lane 3 preview, worker H3; conflict C1 in
-- vault/design/specs/hud-downtown-overnight.md). The approved design keeps the ENGINE HEAT panel
-- at the bottom centre; this is the overnight prompt's alternative, built only so Adam can
-- compare: a horizontal segmented bar at the top left that replaces Cash during the run.
--
-- It shows what it is given (heat 0..1 and the stage from Lane 1) and decides nothing.
--   * flame icon, 5 segments (fill length inside the segments), stage marks at the provisional
--     60% and 85% thresholds (HeatGauge.Thresholds), stage text and a segment count, so the
--     stage reads without colour;
--   * stage words: the approved panel's vocabulary in capitals ("COOL", "HOT", "TOO HOT!",
--     "LOSING CONTROL!"), so both variants say the same thing (lead's decision; one vocabulary);
--   * one brief emphasis (pop) on a stage change; nothing pulses at rest;
--   * a subtle warm edge tint on the screen edges only (8% of the width each side, 10% of the
--     height top and bottom, at most 16% opacity at the very edge, fading to nothing inward),
--     none at Calm, no strobe, shake or tunnel vision; it snaps in reduced motion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gloss = require(script.Parent.Parent.Gloss)
local HeatGauge = require(script.Parent.Parent.Parent.RunHud.HeatGauge)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local C = PreviewTokens.Color
local make = Gloss.make

local HeatBarProposal = {}
HeatBarProposal.__index = HeatBarProposal

HeatBarProposal.Segments = 5
HeatBarProposal.Labels = table.freeze({
	Calm = "COOL",
	Warning = "HOT",
	Critical = "TOO HOT!",
	Meltdown = "LOSING CONTROL!",
})
-- Edge tint opacity at the very edge, per stage (0 = none).
HeatBarProposal.EdgeAlpha = table.freeze({
	Calm = 0,
	Warning = 0.1,
	Critical = 0.14,
	Meltdown = 0.16,
})

local ICON = 40
local SEG_W = 40
local SEG_GAP = 4
local TRACK_H = 24
local TRACK_X = ICON + 8
local TRACK_W = HeatBarProposal.Segments * SEG_W + (HeatBarProposal.Segments - 1) * SEG_GAP
HeatBarProposal.Size = Vector2.new(TRACK_X + TRACK_W, 52)

local function outlinedLabel(parent: Instance, text: string, size: number, x: number, y: number, w: number): TextLabel
	local l = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, size + 4),
		FontFace = Tokens.font(),
		Text = text,
		TextSize = size,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = parent,
	})
	Gloss.stroke(l, 2, C.Ink, Enum.ApplyStrokeMode.Contextual)
	return l
end

function HeatBarProposal.new(parent: Instance, edgeParent: Instance)
	local self = setmetatable({}, HeatBarProposal)
	self._trove = Trove.new()
	self._heat = 0
	self._shown = 0
	self._stage = "Calm" :: HeatGauge.HeatStage
	self._mounted = false

	local root = self._trove:Add(make("Frame", {
		Name = "HeatBarProposal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(HeatBarProposal.Size.X, HeatBarProposal.Size.Y),
		Active = false,
		Parent = parent,
	}))
	self.root = root
	-- emphasis target (its own UIScale "Pop", via Motion.pop)
	local body = make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	self._body = body
	local flame = make("Frame", {
		Name = "Flame",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, (HeatBarProposal.Size.Y - ICON) / 2),
		Size = UDim2.fromOffset(ICON, ICON),
		ZIndex = 4,
		Parent = body,
	})
	Icons.draw(flame, "Flame", C.HeatMid)

	self._segments = {} :: { { frame: Frame, fill: Frame } }
	for i = 1, HeatBarProposal.Segments do
		local seg = make("Frame", {
			Name = "Segment" .. i,
			Position = UDim2.fromOffset(TRACK_X + (i - 1) * (SEG_W + SEG_GAP), 2),
			Size = UDim2.fromOffset(SEG_W, TRACK_H),
			BackgroundColor3 = C.InkSoft,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = body,
		})
		Gloss.corner(seg, 6)
		Gloss.stroke(seg, 2.5, C.Ink)
		local fill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Tokens.heatColor((i - 0.5) / HeatBarProposal.Segments),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = seg,
		})
		Gloss.corner(fill, 5)
		-- restrained top highlight on the fill
		local shine = make("Frame", {
			Name = "Shine",
			Position = UDim2.fromOffset(3, 2),
			Size = UDim2.new(1, -6, 0.35, 0),
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = fill,
		})
		Gloss.corner(shine, 3)
		table.insert(self._segments, { frame = seg, fill = fill })
	end
	-- stage marks at the provisional thresholds (Lane 1 owns the real values)
	for _, t in { HeatGauge.Thresholds.Warning, HeatGauge.Thresholds.Critical } do
		local x = TRACK_X + t * TRACK_W
		make("Frame", {
			Name = "StageMark",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(x, -2),
			Size = UDim2.fromOffset(3, TRACK_H + 8),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = body,
		})
	end
	self._label = outlinedLabel(body, "COOL", 18, TRACK_X, TRACK_H + 4, TRACK_W - 50)
	self._count = outlinedLabel(body, "0/5", 16, TRACK_X + TRACK_W - 48, TRACK_H + 5, 48)
	self._count.TextXAlignment = Enum.TextXAlignment.Right

	-- edge tint, on the canvas edges only
	local edge = self._trove:Add(make("Frame", {
		Name = "HeatEdgeTint",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		ZIndex = 1,
		Parent = edgeParent,
	}))
	self.edge = edge
	local fade = NumberSequence.new(0, 1)
	self._strips = {} :: { Frame }
	for _, spec in
		{
			{ "Left", UDim2.fromScale(0.08, 1), UDim2.new(), 0 },
			{ "Right", UDim2.fromScale(0.08, 1), UDim2.fromScale(0.92, 0), 180 },
			{ "Top", UDim2.fromScale(1, 0.1), UDim2.new(), 90 },
			{ "Bottom", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.9), 270 },
		}
	do
		local strip = make("Frame", {
			Name = spec[1],
			Size = spec[2],
			Position = spec[3],
			BackgroundColor3 = Tokens.Color.HeatOrange,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = edge,
		})
		make("UIGradient", { Transparency = fade, Rotation = spec[4], Parent = strip })
		table.insert(self._strips, strip)
	end

	self._value = self._trove:Add(Instance.new("NumberValue"))
	self._trove:Connect(self._value.Changed, function(v: number)
		self._shown = v
		self:_render()
	end)
	self._trove:Add(function()
		Motion.cancelAll(self._value)
		Motion.cancelAll(body)
		for _, s in self._strips do
			Motion.cancelAll(s)
		end
	end)
	self:_render()
	return self
end

export type HeatBarProposal = typeof(HeatBarProposal.new(Instance.new("Frame"), Instance.new("Frame")))

function HeatBarProposal.segmentsFor(heat01: number): number
	return math.clamp(math.ceil(heat01 * HeatBarProposal.Segments - 1e-6), 0, HeatBarProposal.Segments)
end

function HeatBarProposal._render(self: HeatBarProposal)
	local units = self._shown * HeatBarProposal.Segments
	for i, s in self._segments do
		s.fill.Size = UDim2.fromScale(math.clamp(units - (i - 1), 0, 1), 1)
	end
end

function HeatBarProposal._applyEdge(self: HeatBarProposal, instant: boolean)
	local alpha = HeatBarProposal.EdgeAlpha[self._stage] or 0
	local colour = if self._stage == "Warning" then Tokens.Color.HeatOrange else Tokens.Color.Danger
	for _, strip in self._strips do
		strip.BackgroundColor3 = colour
		if instant then
			Motion.cancelAll(strip)
			strip.BackgroundTransparency = 1 - alpha
		else
			Motion.tween(strip, "edge", Motion.info(0.4), { BackgroundTransparency = 1 - alpha })
		end
	end
end

-- Shows a supplied state. stage nil derives Calm / Warning / Critical from the provisional
-- thresholds (never Meltdown), the same rule as the approved gauge.
function HeatBarProposal.set(self: HeatBarProposal, heat01: number, stage: HeatGauge.HeatStage?)
	local heat = math.clamp(if heat01 ~= heat01 then 0 else heat01, 0, 1)
	local resolved: HeatGauge.HeatStage = stage or HeatGauge.stageFor(heat)
	local changed = resolved ~= self._stage
	local first = not self._mounted
	self._mounted = true
	self._heat = heat
	self._stage = resolved
	self._label.Text = HeatBarProposal.Labels[resolved]
	self._count.Text = string.format("%d/%d", HeatBarProposal.segmentsFor(heat), HeatBarProposal.Segments)
	local reduced = Motion.reduced()
	if first or reduced then
		Motion.cancelAll(self._value)
		self._value.Value = heat
		self._shown = heat
		self:_render()
	else
		Motion.tween(self._value, "fill", Motion.info(0.25), { Value = heat })
	end
	self:_applyEdge(first or reduced)
	if changed and not first and not reduced then
		Motion.pop(self._body, 1.08)
	end
end

-- Shows a state with no fill tween or stage emphasis (first mount, or a variant switch).
function HeatBarProposal.snap(self: HeatBarProposal, heat01: number, stage: HeatGauge.HeatStage?)
	self._mounted = false
	self:set(heat01, stage)
end

function HeatBarProposal.setVisible(self: HeatBarProposal, on: boolean)
	self.root.Visible = on
	self.edge.Visible = on
end

function HeatBarProposal.onReducedChanged(self: HeatBarProposal, reduced: boolean)
	if reduced then
		Motion.cancelAll(self._value)
		self._value.Value = self._heat
		self._shown = self._heat
		self:_render()
		local pop = self._body:FindFirstChild("Pop") :: UIScale?
		if pop then
			Motion.cancelAll(pop)
			pop.Scale = 1
		end
		self:_applyEdge(true)
	end
end

function HeatBarProposal.getDebugState(self: HeatBarProposal): { [string]: any }
	return {
		heat = self._heat,
		shownHeat = self._shown,
		stage = self._stage,
		label = self._label.Text,
		segmentsFilled = HeatBarProposal.segmentsFor(self._heat),
		countText = self._count.Text,
		edgeAlpha = 1 - self._strips[1].BackgroundTransparency,
		edgeTarget = HeatBarProposal.EdgeAlpha[self._stage],
		labelFits = self._label.TextFits,
	}
end

function HeatBarProposal.destroy(self: HeatBarProposal)
	self._trove:Destroy()
end

return HeatBarProposal
