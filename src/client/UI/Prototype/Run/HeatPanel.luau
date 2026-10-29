--!strict
-- The ORIGINAL ENGINE HEAT panel in the HUD playground (Lane 3 preview; Round 2, ledger R2-H3..H5; Round 3, R3-H).
-- Adam's approved rev-4 component (src/client/UI/RunHud/HeatGauge.luau, merged by PR #1) is instantiated
-- UNMODIFIED; this adapter only supplies what the production host (RunHud) supplies:
--   * the inputs: store.run.heat (0..1) and store.run.stage -> gauge:snap on the first state of a run,
--     gauge:set afterwards (Hop reset = a store patch back to Calm, which the gauge clears at once);
--   * "HeatBump" events (amount = strength 0..1.5) -> gauge:jolt (presentation only);
--   * reduced motion from Motion (GuiService.ReducedMotionEnabled + the preview override);
--   * placement and size from RunLayout.heatPlan: ONE uniform scale (the smallest at which the smallest Heat text
--     still reads at the approved floor) and ONE static anchor at the bottom centre of the full viewport. Only
--     uniform scaling and anchoring are applied; the silhouette, title tab, arrangement, typography, thresholds
--     and animation are the original's. The anchor is written when the layout changes (a profile or inset
--     change), never per frame, and the alarm shake moves only parts inside the panel, so it cannot accumulate
--     an offset. gauge:setLayout carries the stage-growth cap (safe edge, Hop clearance).
-- It never derives a stage from the number beyond what HeatGauge does itself, never ends a run, and shows
-- no escape timer (decision 0008). Thresholds are HeatGauge.Thresholds, a provisional copy of Lane 1's:
-- a fixture driven through them is NOT a live Lane 1 run.
--
-- One presentation-only rule is added here (ledger R2-S2): the panel's HOP NOW! instruction is hidden
-- once the rider is off the car (Dismounted / RunEnded) and while the Stamina demo says no Hop is
-- possible (run.stamina.value <= 0), because the instruction would invite an action that is gone. It
-- hides the panel's own "HopNow" child from outside; HeatGauge itself is untouched.
--
--   local heat = HeatPanel.new(ctx)
--   heat:layout(), heat:setVisible(on), heat:destroy(), heat:getDebugState()
--   heat:parts() -> the live instances a harness measures (read only)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeatGauge = require(script.Parent.Parent.Parent.RunHud.HeatGauge)
local Motion = require(script.Parent.Parent.Motion)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local HeatPanel = {}
HeatPanel.__index = HeatPanel

function HeatPanel.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, HeatPanel)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._mounted = false -- has the gauge been given its first state of this run?
	self._ended = false
	self._plan = nil :: RunLayout.HeatPlan?
	self._cues = { Stage = 0, AlarmPeak = 0 }
	self._connections = 0 -- the listeners this adapter registers (bookkeeping for getDebugState)
	self._destroyed = false

	local root = self._trove:Add(RunLayout.canvas(ctx, "HeatPanel"))
	self.root = root
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = root
	RunKit.nonInteractive(holder)
	self._holder = holder

	-- The one stable anchor: bottom centre of the canvas, shifted by the constant viewport / safe-area difference
	-- (layout sets it). The slot has the card's scaled size, so the original panel sits in it with no offset
	-- arithmetic: its root is anchored at the slot's bottom centre and scaled about that same point.
	local slot = Instance.new("Frame")
	slot.Name = "HeatSlot"
	slot.AnchorPoint = Vector2.new(0.5, 1)
	slot.BackgroundTransparency = 1
	slot.BorderSizePixel = 0
	slot.Parent = holder
	RunKit.nonInteractive(slot)
	self._slot = slot

	local gauge = HeatGauge.new(slot, Tokens.Color, Motion.reduced())
	RunKit.nonInteractive(gauge.Root)
	gauge.Root.Position = UDim2.fromScale(0.5, 1) -- the slot's bottom centre; never written again
	local fit = Instance.new("UIScale")
	fit.Name = "FitScale"
	fit.Parent = gauge.Root
	self._fit = fit
	self._gauge = gauge
	self._trove:Add(function()
		gauge:destroy()
	end)
	self._trove:Connect(gauge.Cue, function(cue: string)
		self._cues[cue] = (self._cues[cue] or 0) + 1
	end)
	self._connections += 1

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._connections += 1
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Run" and from ~= "Run" then
			self._ended = false
			self._mounted = false
		end
		self:_apply()
	end)
	self._connections += 1
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Dismounted" or event.kind == "RunEnded" then
			self._ended = true
			self:_syncHopNow()
		elseif event.kind == "HeatBump" and self._mounted then
			gauge:jolt(event.amount) -- presentation only: changes no Heat value
		end
	end)
	self._connections += 1
	self._trove:Add(Motion.onReducedChanged(function()
		gauge:setReducedMotion(Motion.reduced())
	end))
	self._connections += 1
	self:layout()
	return self
end

export type HeatPanel = typeof(HeatPanel.new((nil :: any) :: RunLayout.Ctx))

function HeatPanel._shown(self: HeatPanel): boolean
	local state = self._ctx.store:get()
	return self._visible and state.mode == "Run" and state.run ~= nil
end

-- The panel's HOP NOW! child (HeatGauge builds it under Body.Card): hidden when no Hop is possible.
function HeatPanel._syncHopNow(self: HeatPanel)
	local body = self._gauge.Root:FindFirstChild("Body")
	local card = body and body:FindFirstChild("Card")
	local hopNow = card and card:FindFirstChild("HopNow")
	if hopNow and hopNow:IsA("GuiObject") then
		local run = self._ctx.store:get().run :: any
		local stamina = run and run.stamina
		local noHop = self._ended or (stamina ~= nil and stamina.value <= 0)
		hopNow.Visible = not noHop
	end
end

function HeatPanel._apply(self: HeatPanel)
	local run = self._ctx.store:get().run
	local shown = self:_shown()
	self.root.Visible = self._visible
	self._holder.Visible = shown
	if not shown or run == nil then
		if self._mounted then
			-- hidden (Home, Results, a hidden component): stop every alarm effect and the shared clock
			self._gauge:snap(0, "Calm")
			self._mounted = false
		end
		return
	end
	local heat = if run.heat ~= run.heat then 0 else math.clamp(run.heat, 0, 1)
	local stage = run.stage
	if not self._mounted then
		self._mounted = true
		self._gauge:snap(heat, stage)
	else
		self._gauge:set(heat, stage)
	end
	self:_syncHopNow()
end

-- Re-reads the plan and writes the anchor, the slot size, the one scale and the growth cap. Deterministic: the same
-- screen gives the same values, so any number of calls (resize, inset change, mode change) lands on the same anchor.
function HeatPanel.layout(self: HeatPanel)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local plan = RunLayout.heatPlan(ctx)
	self._plan = plan
	-- the shift is carried in the scale so a fractional value is not rounded to whole px (UDim offsets are integers);
	-- it is exactly 0 when the viewport and safe-area centres coincide. The slot's size is a measurement box only
	-- (whole px): the panel's centre is the anchor point, whatever the box size.
	self._slot.Position = UDim2.new(0.5 + plan.shift / RunLayout.design(ctx).X, 0, 1, -plan.gap)
	self._slot.Size = UDim2.fromOffset(math.round(plan.card.size.X), math.round(plan.card.size.Y))
	self._fit.Scale = plan.scale
	-- the original host's contract: a cap on stage growth (the safe edge, Hop) and how far smoke may drift
	self._gauge:setLayout(plan.maxGrowth, plan.smoke)
	self:_apply()
end

function HeatPanel.setVisible(self: HeatPanel, on: boolean)
	self._visible = on
	self:_apply()
end

-- The live instances a harness measures (read only): the anchor slot, the original panel's root, its body, card and
-- title tab, and the title and stage-label text.
function HeatPanel.parts(self: HeatPanel): { [string]: any }
	local root = self._gauge.Root
	local body = root:FindFirstChild("Body")
	local card = body and body:FindFirstChild("Card")
	local tab = body and body:FindFirstChild("TitleTab")
	local labelArea = card and card:FindFirstChild("LabelArea")
	return {
		slot = self._slot,
		root = root,
		body = body,
		card = card,
		tab = tab,
		title = tab and tab:FindFirstChild("Title"),
		label = labelArea and labelArea:FindFirstChild("Label1"),
		label2 = labelArea and labelArea:FindFirstChild("Label2"),
	}
end

function HeatPanel.getDebugState(self: HeatPanel): { [string]: any }
	if self._destroyed then
		-- after destroy: what is still alive (all zero when nothing leaked)
		return {
			destroyed = true,
			instances = #self.root:GetDescendants(),
			ownInstances = #self.root:GetDescendants(),
			connections = self._connections,
			threads = 0,
		}
	end
	local g = self._gauge:getDebugState()
	local plan = self._plan
	local slot = self._slot
	local gauges = 0
	local total = 0
	for _, d in self.root:GetDescendants() do
		total += 1
		if d.Name == "HeatGauge" then
			gauges += 1
		end
	end
	local offset = g.instrumentOffset :: UDim2
	local capOffset = g.capOffset :: UDim2
	return {
		original = true, -- the unmodified RunHud.HeatGauge
		visible = self._visible,
		shown = self._holder.Visible,
		stage = g.stage,
		label = g.label,
		heat = g.heat,
		shownHeat = g.shownHeat,
		alarm = g.alarm,
		melt = g.melt,
		rattle = g.rattle,
		alarmRate = g.alarmRate,
		stageScale = g.stageScale,
		maskScale = g.maskScale,
		reducedMotion = g.reducedMotion,
		titleFits = g.titleFits,
		labelFits = g.labelFits,
		hopFits = g.hopFits,
		hopPulse = g.hopPulse,
		bumpActive = g.bumpActive,
		shakeX = offset.X.Offset, -- the inner instrument's shake; exactly 0 at rest
		shakeY = offset.Y.Offset,
		capLiftX = capOffset.X.Offset,
		capLiftY = capOffset.Y.Offset,
		cues = self._cues,
		ended = self._ended,
		hopNowShown = (function(): boolean?
			local body = self._gauge.Root:FindFirstChild("Body")
			local card = body and body:FindFirstChild("Card")
			local hopNow = card and card:FindFirstChild("HopNow")
			return if hopNow and hopNow:IsA("GuiObject") then hopNow.Visible else nil
		end)(),
		-- placement (design px on the canvas unless it says real px)
		scale = plan and plan.scale,
		fitScale = plan and plan.scale, -- the Round 2 name
		centre = plan and plan.centre,
		shift = plan and plan.shift,
		pulled = plan and plan.pulled,
		gap = plan and plan.gap,
		maxGrowth = plan and plan.maxGrowth,
		titleRealPx = plan and plan.title,
		labelRealPx = plan and plan.label,
		zone = plan and plan.zone,
		conflict = plan and plan.conflict,
		box = plan and RunLayout.describe(plan.card),
		bounds = plan and RunLayout.describe(plan.bounds),
		overlapsProtected = plan ~= nil and RunLayout.overlaps(plan.bounds, RunLayout.protected(self._ctx)),
		slotPosition = string.format(
			"%.3f,%.3f,%.3f,%.3f",
			slot.Position.X.Scale,
			slot.Position.X.Offset,
			slot.Position.Y.Scale,
			slot.Position.Y.Offset
		),
		sizeMatches = HeatGauge.Size == RunLayout.HeatFull,
		textMatches = Tokens.TextSize.Minimum == RunLayout.HeatSmallestText
			and Tokens.TextSize.Label == RunLayout.HeatLabelText,
		-- what this adapter holds alive (the original's own count is `instances`)
		gauges = gauges,
		instances = g.instances,
		ownInstances = total - g.instances,
		connections = self._connections,
		threads = 0, -- the adapter starts none
		avgUpdateMs = g.avgUpdateMs,
	}
end

function HeatPanel.destroy(self: HeatPanel)
	self._trove:Destroy()
	self._connections = 0
	self._destroyed = true
end

return HeatPanel
