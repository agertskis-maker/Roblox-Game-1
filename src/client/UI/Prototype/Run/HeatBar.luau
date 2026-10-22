--!strict
-- Heat for the rebuilt run HUD (Lane 3 preview, HUD rebuild worker HR; U-05, L-04). Bottom
-- centre, compact: a strong dark frame holding a SEGMENTED fill (10 segments, PROPOSAL within
-- the brief's 8–10), a readable Flame icon overhanging the left end, and the stage words of
-- decision 0008 (Cool / Hot / Too hot! / Losing control!). It replaces the overnight run Heat
-- look inside the prototype only; src/client/UI/RunHud (the approved production HUD) is not
-- touched.
--
-- Display only: it shows run.heat (0..1) and run.stage exactly as supplied by Lane 1; it never
-- derives a stage from the number and prints no threshold numbers. Stage marks (two notches) sit
-- at the outline's Proposed, Tunable thresholds (RunHud.HeatGauge.Thresholds), labelled with the
-- stage WORDS, never percentages.
--   * colour ramp: yellow -> orange -> red along the bar (the Arcade "Heat" face; V-05); no green;
--   * stage reads without colour: the current stage word (desktop: words at the marks, the
--     current one bright, the others dim; phones: the current word only), the lit segment count,
--     and at Meltdown the instruction HOP NOW! (decision 0008 amendment);
--   * one brief stage-change emphasis (a pop); nothing shakes. Critical and Meltdown add a
--     restrained red frame pulse (1.0 / 1.2 cycles per second, one visible peak per cycle, under
--     the 2.5 per second ceiling); reduced motion: a steady red frame, no pulse, no pop.
-- Placement: RunLayout.heatRect (bottom centre; shifted clear of the thumbstick zone or raised
-- above the Hop row when needed), outside the protected road-ahead region, leaving the space
-- above it for the rider and Keys.
--
--   local heat = HeatBar.new(ctx)
--   heat:layout(), heat:setVisible(on), heat:destroy(), heat:getDebugState()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(script.Parent.Parent.Arcade)
local HeatGauge = require(script.Parent.Parent.Parent.RunHud.HeatGauge)
local Motion = require(script.Parent.Parent.Motion)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local SEGMENTS = 10 -- TOKEN CANDIDATE (brief: 8–10)
local LABELS = table.freeze({
	Calm = "COOL",
	Warning = "HOT",
	Critical = "TOO HOT!",
	Meltdown = "LOSING CONTROL!",
})
local DANGER = Color3.fromRGB(232, 60, 50) -- the end of the Arcade Heat face
local PULSE_HZ = table.freeze({ Critical = 1.0, Meltdown = 1.2 })

local HeatBar = {}
HeatBar.__index = HeatBar
HeatBar.Segments = SEGMENTS
HeatBar.Labels = LABELS

-- Samples the Arcade Heat face (yellow -> orange -> red) at t in 0..1.
local function ramp(t: number): Color3
	local kps = A.Face.Heat.Keypoints
	t = math.clamp(t, 0, 1)
	for i = 1, #kps - 1 do
		local a, b = kps[i], kps[i + 1]
		if t <= b.Time then
			local f = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
			return a.Value:Lerp(b.Value, f)
		end
	end
	return kps[#kps].Value
end

function HeatBar.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, HeatBar)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._heat = 0
	self._stage = nil :: string?
	self._lit = 0
	self._emphases = 0
	self._compact = false
	self._pulse = nil :: RBXScriptConnection?
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?

	local root = self._trove:Add(RunLayout.canvas(ctx, "HeatBar"))
	self.root = root
	local holder = make("Frame", {
		Name = "Heat",
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	RunKit.nonInteractive(holder)
	self._holder = holder
	local inner = make("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = holder,
	})
	make("UIScale", { Name = "Pop", Parent = inner })
	self._inner = inner

	-- the dark frame (bar body)
	local frame = make("Frame", {
		Name = "Frame",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = A.Ink,
		ZIndex = 3,
		Parent = inner,
	})
	Arcade.corner(frame, A.Button.Radius)
	self._frameStroke = Arcade.outline(frame, "Button")
	self._frame = frame
	local segs = make("Frame", {
		Name = "Segments",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = frame,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = segs,
	})
	self._segs = segs
	self._slots = {} :: { Frame }
	self._fills = {} :: { Frame }
	for i = 1, SEGMENTS do
		local slot = make("Frame", {
			Name = "Seg" .. i,
			BackgroundColor3 = RunKit.Slot,
			LayoutOrder = i,
			ZIndex = 4,
			ClipsDescendants = true,
			Parent = segs,
		})
		Arcade.corner(slot, 3)
		local fill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = ramp((i - 0.5) / SEGMENTS),
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = slot,
		})
		Arcade.corner(fill, 3)
		-- a narrow gloss line on each lit segment
		local gloss = make("Frame", {
			Name = "Gloss",
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0.22, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = fill,
		})
		local _ = gloss
		table.insert(self._slots, slot)
		table.insert(self._fills, fill)
	end
	-- stage marks (notches at the Proposed thresholds) and their words
	self._marks = {} :: { Frame }
	self._markWords = {} :: { TextLabel }
	for i, stage in { "Warning", "Critical" } do
		local mark = make("Frame", {
			Name = "Mark" .. stage,
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(4, 10),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 7,
			Parent = inner,
		})
		Arcade.outline(mark, "Minor")
		self._marks[i] = mark
	end
	for i, stage in { "Calm", "Warning", "Critical" } do
		local word = Arcade.text(inner, {
			text = LABELS[stage],
			role = "Small",
			name = "Word" .. stage,
			face = "Heat",
			autoWidth = true,
			z = 8,
		})
		word.AnchorPoint = Vector2.new(if i == 1 then 0 else 0.5, 1)
		self._markWords[i] = word
	end
	-- the current stage word (phones; desktop at Meltdown) and HOP NOW!
	local current = Arcade.text(inner, {
		text = "",
		role = "Label",
		name = "Stage",
		face = "Heat",
		autoWidth = true,
		z = 8,
	})
	current.AnchorPoint = Vector2.new(0, 1)
	self._current = current
	local hopNow = Arcade.text(inner, {
		text = "HOP NOW!",
		role = "Label",
		name = "HopNow",
		face = "White",
		autoWidth = true,
		z = 8,
	})
	hopNow.AnchorPoint = Vector2.new(1, 1)
	hopNow.Visible = false
	self._hopNow = hopNow
	-- flame icon overhanging the left end
	local flame = make("Frame", {
		Name = "Flame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = inner,
	})
	Arcade.icon(flame, "Flame")
	self._flame = flame

	self._trove:Add(function()
		self:_stopPulse()
		Motion.cancelAll(inner:FindFirstChild("Pop") :: Instance)
	end)
	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function()
		self:_apply()
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		self:_applyAlarm()
	end))
	self:layout()
	return self
end

export type HeatBar = typeof(HeatBar.new((nil :: any) :: RunLayout.Ctx))

function HeatBar._stopPulse(self: HeatBar)
	if self._pulse then
		self._pulse:Disconnect()
		self._pulse = nil
	end
end

-- Critical / Meltdown: a restrained red frame pulse (no shake), steady red in reduced motion.
function HeatBar._applyAlarm(self: HeatBar)
	self:_stopPulse()
	local stage = self._stage
	local stroke = self._frameStroke
	local hz = stage and (PULSE_HZ :: any)[stage]
	if not hz or not self:_shown() then
		stroke.Color = A.Ink
		return
	end
	if Motion.reduced() then
		stroke.Color = DANGER
		return
	end
	local t = 0
	self._pulse = RunService.Heartbeat:Connect(function(dt)
		t += dt
		-- one smooth peak per cycle (cosine), never an on/off flash
		local k = 0.5 - 0.5 * math.cos(t * hz * math.pi * 2)
		stroke.Color = A.Ink:Lerp(DANGER, k)
	end)
end

function HeatBar._shown(self: HeatBar): boolean
	local state = self._ctx.store:get()
	return self._visible and state.mode == "Run" and state.run ~= nil
end

function HeatBar._apply(self: HeatBar)
	local run = self._ctx.store:get().run
	local shown = self:_shown()
	if shown ~= self._holder.Visible then
		self._holder.Visible = shown
		self:_applyAlarm()
	end
	local heat = if run then math.clamp(if run.heat ~= run.heat then 0 else run.heat, 0, 1) else 0
	local stage: string? = if run then run.stage else nil
	if stage == "Meltdown" then
		heat = 1 -- the bar stays full in Meltdown (decision 0008 amendment)
	end
	self._heat = heat
	local lit = 0
	for i, fill in self._fills do
		local f = math.clamp(heat * SEGMENTS - (i - 1), 0, 1)
		fill.Size = UDim2.fromScale(f, 1)
		if f >= 0.999 then
			lit += 1
		end
	end
	self._lit = lit
	if stage ~= self._stage then
		local first = self._stage == nil
		self._stage = stage
		self:_applyWords()
		self:_applyAlarm()
		if not first and stage ~= nil then
			self._emphases += 1
			if not Motion.reduced() then
				Motion.pop(self._inner, 1.06)
			end
		end
	end
end

function HeatBar._applyWords(self: HeatBar)
	local stage = self._stage or "Calm"
	local compact = self._compact
	local melt = stage == "Meltdown"
	for i, s in { "Calm", "Warning", "Critical" } do
		local word = self._markWords[i]
		word.Visible = not compact and not melt
		word.TextTransparency = if s == stage then 0 else 0.55
		local stroke = word:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if s == stage then 0 else 0.5
		end
	end
	self._current.Visible = compact or melt
	self._current.Text = LABELS[stage] or ""
	-- phones have room for one line: at Meltdown the instruction wins (the full bar and the red
	-- frame still say "losing control")
	self._hopNow.Visible = melt and not compact
	if melt and compact then
		self._current.Text = "HOP NOW!"
	end
end

function HeatBar.layout(self: HeatBar)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect, conflict = RunLayout.heatRect(ctx)
	self._rect = rect
	self._conflict = conflict
	local compact = RunLayout.compact(ctx)
	self._compact = compact
	RunLayout.place(self._holder, rect)
	local w, h = rect.size.X, rect.size.Y
	local barH = if compact then 24 else 30
	local icon = if compact then 38 else 46
	local barX = icon * 0.45
	local barW = w - barX
	self._frame.Position = UDim2.fromOffset(barX, h)
	self._frame.Size = UDim2.fromOffset(barW, barH)
	local pad = 5
	local segW = (barW - icon * 0.55 - pad - (SEGMENTS - 1) * 3 - pad) / SEGMENTS
	self._segs.AnchorPoint = Vector2.new(1, 0.5)
	self._segs.Position = UDim2.new(1, -pad, 0.5, 0)
	self._segs.Size = UDim2.fromOffset(SEGMENTS * segW + (SEGMENTS - 1) * 3, barH - 2 * pad)
	for _, slot in self._slots do
		slot.Size = UDim2.fromOffset(segW, barH - 2 * pad)
	end
	self._flame.Size = UDim2.fromOffset(icon, icon)
	self._flame.Position = UDim2.fromOffset(barX + 4, h - barH / 2)
	-- marks at the Proposed thresholds, along the segment run
	local segLeft = barX + barW - pad - (SEGMENTS * segW + (SEGMENTS - 1) * 3)
	local segRun = SEGMENTS * segW + (SEGMENTS - 1) * 3
	local wordsY = h - barH - 2
	for i, t in { HeatGauge.Thresholds.Warning, HeatGauge.Thresholds.Critical } do
		local mark = self._marks[i]
		mark.Position = UDim2.fromOffset(segLeft + t * segRun, h - barH + 4)
		mark.Size = UDim2.fromOffset(4, if compact then 8 else 10)
	end
	self._markWords[1].Position = UDim2.fromOffset(segLeft, wordsY)
	self._markWords[2].Position = UDim2.fromOffset(segLeft + HeatGauge.Thresholds.Warning * segRun, wordsY)
	self._markWords[3].Position = UDim2.fromOffset(segLeft + HeatGauge.Thresholds.Critical * segRun, wordsY)
	self._current.Position = UDim2.fromOffset(segLeft, wordsY)
	self._hopNow.Position = UDim2.fromOffset(w, wordsY)
	self:_applyWords()
	self:_apply()
end

function HeatBar.setVisible(self: HeatBar, on: boolean)
	self._visible = on
	self.root.Visible = on
	self:_applyAlarm()
end

function HeatBar.getDebugState(self: HeatBar): { [string]: any }
	local rect = self._rect
	return {
		visible = self._visible,
		heat = self._heat,
		stage = self._stage,
		segments = SEGMENTS,
		lit = self._lit,
		word = if self._stage then LABELS[self._stage] else nil,
		hopNow = self._stage == "Meltdown",
		emphases = self._emphases,
		pulsing = self._pulse ~= nil,
		compact = self._compact,
		box = rect and RunLayout.describe(rect),
		conflict = self._conflict,
		overlapsProtected = rect ~= nil and RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
	}
end

function HeatBar.destroy(self: HeatBar)
	self._trove:Destroy()
end

return HeatBar
