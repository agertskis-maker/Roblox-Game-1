--!strict
-- The ORIGINAL ENGINE HEAT panel in the HUD playground (Lane 3 preview; Round 2, ledger R2-H3..H5).
-- Adam's approved rev-4 component (src/client/UI/RunHud/HeatGauge.luau, merged by PR #1) is instantiated
-- UNMODIFIED; this adapter only supplies what the production host (RunHud) supplies:
--   * the inputs: store.run.heat (0..1) and store.run.stage -> gauge:snap on the first state of a run,
--     gauge:set afterwards (Hop reset = a store patch back to Calm, which the gauge clears at once);
--   * "HeatBump" events (amount = strength 0..1.5) -> gauge:jolt (presentation only);
--   * reduced motion from Motion (GuiService.ReducedMotionEnabled + the preview override);
--   * placement and size from RunLayout.heatRect (bottom centre, scaled to fit between the thumbstick
--     zone and Hop), with gauge:setLayout capping stage growth so the panel stays inside its rectangle on
--     phones (no growth below scale 1.0).
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeatGauge = require(script.Parent.Parent.Parent.RunHud.HeatGauge)
local Motion = require(script.Parent.Parent.Motion)
local RunKit = require(script.Parent.RunKit)
local RunLayout = require(script.Parent.RunLayout)
local Store = require(script.Parent.Parent.Store)
local Tokens = require(ReplicatedStorage.Shared.UI.Tokens)
local Trove = require(ReplicatedStorage.Packages.Trove)

local STAGE_GROWTH_MAX = 1.12 -- HeatGauge's own Meltdown growth; allowed where there is room

local HeatPanel = {}
HeatPanel.__index = HeatPanel

function HeatPanel.new(ctx: RunLayout.Ctx)
	local self = setmetatable({}, HeatPanel)
	self._ctx = ctx
	self._trove = Trove.new()
	self._visible = true
	self._mounted = false -- has the gauge been given its first state of this run?
	self._ended = false
	self._rect = nil :: RunLayout.Rect?
	self._conflict = nil :: string?
	self._scale = 1
	self._cues = { Stage = 0, AlarmPeak = 0 }

	local root = self._trove:Add(RunLayout.canvas(ctx, "HeatPanel"))
	self.root = root
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = root
	RunKit.nonInteractive(holder)
	self._holder = holder

	local gauge = HeatGauge.new(holder, Tokens.Color, Motion.reduced())
	RunKit.nonInteractive(gauge.Root)
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

	self._trove:Add(ctx.store:subscribe("run", function()
		self:_apply()
	end))
	self._trove:Connect(ctx.store.ModeChanged, function(mode: string, from: string?)
		if mode == "Run" and from ~= "Run" then
			self._ended = false
			self._mounted = false
		end
		self:_apply()
	end)
	self._trove:Connect(ctx.store.Event, function(event: Store.Event)
		if event.kind == "Dismounted" or event.kind == "RunEnded" then
			self._ended = true
			self:_syncHopNow()
		elseif event.kind == "HeatBump" and self._mounted then
			gauge:jolt(event.amount) -- presentation only: changes no Heat value
		end
	end)
	self._trove:Add(Motion.onReducedChanged(function()
		gauge:setReducedMotion(Motion.reduced())
	end))
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

function HeatPanel.layout(self: HeatPanel)
	local ctx = self._ctx
	RunLayout.fit(ctx, self.root)
	local rect, conflict = RunLayout.heatRect(ctx)
	self._rect, self._conflict = rect, conflict
	local k = rect.size.X / RunLayout.HeatFull.X
	self._scale = k
	self._fit.Scale = k
	-- the gauge's root is anchored bottom-centre: put that point at the rect's bottom centre
	self._gauge.Root.Position = UDim2.fromOffset(rect.pos.X + rect.size.X / 2, rect.pos.Y + rect.size.Y)
	-- below scale 1.0 there is no room to grow: stage growth is off and the smoke drifts less
	self._gauge:setLayout(if k < 0.999 then 1 else STAGE_GROWTH_MAX, if k < 0.999 then 0.6 else 1)
	self:_apply()
end

function HeatPanel.setVisible(self: HeatPanel, on: boolean)
	self._visible = on
	self:_apply()
end

function HeatPanel.getDebugState(self: HeatPanel): { [string]: any }
	local g = self._gauge:getDebugState()
	local rect = self._rect
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
		cues = self._cues,
		ended = self._ended,
		hopNowShown = (function(): boolean?
			local body = self._gauge.Root:FindFirstChild("Body")
			local card = body and body:FindFirstChild("Card")
			local hopNow = card and card:FindFirstChild("HopNow")
			return if hopNow and hopNow:IsA("GuiObject") then hopNow.Visible else nil
		end)(),
		fitScale = self._scale,
		sizeMatches = HeatGauge.Size == RunLayout.HeatFull,
		box = rect and RunLayout.describe(rect),
		conflict = self._conflict,
		overlapsProtected = rect ~= nil and RunLayout.overlaps(rect, RunLayout.protected(self._ctx)),
		instances = g.instances,
		avgUpdateMs = g.avgUpdateMs,
	}
end

function HeatPanel.destroy(self: HeatPanel)
	self._trove:Destroy()
end

return HeatPanel
