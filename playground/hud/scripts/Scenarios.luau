--!strict
-- PLAYGROUND ONLY (Lane 3 preview). Scripted, reproducible playback of synthetic fixtures through
-- the preview store, plus the RUN PREVIEW ADAPTER: while the mode is Run it advances a fixture run
-- state (distance in metres from a fixed fixture speed, heat, hop cooldown). None of this is a
-- game rule; in production Lane 1 (run state) and Lane 2 (Cash, ownership, rewards) supply these
-- values through agreed contracts (proposed, not agreed: vault/design/specs/hud-downtown-overnight.md).
--
--   scenarios:play(name) -> boolean      -- cancels the current scenario first
--   scenarios:cancel()
--   scenarios.list                       -- names in order

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Fixtures = require(Prototype:WaitForChild("Fixtures"))
local Motion = require(Prototype:WaitForChild("Motion"))

local Scenarios = {}
Scenarios.__index = Scenarios

local FIXTURE_SPEED_MPS = 18 -- fixture only: metres per second shown while previewing a run

local function car(id: string): any
	return Fixtures.byId(id) or Fixtures.Cars[1]
end

function Scenarios.new(api: any)
	local self = setmetatable({}, Scenarios)
	self.api = api
	self.store = api.store
	self._thread = nil :: thread?
	self._seq = 0
	self.current = nil :: string?
	self.list = {
		"Home tour",
		"Cash gains and spends",
		"Extreme balances",
		"Menus and badges",
		"Tutorial",
		"Toasts",
		"Lap Pay",
		"Prompts",
		"Settings",
		"Car cards",
		"Garage mock",
		"Portal card mock",
		"Welcome Back mock",
		"Shop mock",
		"Run: Heat",
		"Run: Keys capture",
		"Run: Already owned",
		"Run: Hop, Dash, milestones",
		"Run: Heat proposal variant",
		"Results: typical",
		"Results: no rewards",
		"Results: many cars",
		"Results: repeated clicks",
		"Stunt mock",
		"Reduced motion mid-effect",
		"Mode change mid-animation",
		"Stress: rapid events",
	}
	-- the run preview adapter
	-- updates at 10 Hz (a counter change must not redraw the HUD every frame)
	local acc = 0
	self._run = RunService.Heartbeat:Connect(function(step)
		acc += step
		if acc < 0.1 then
			return
		end
		local dt = acc
		acc = 0
		local state = self.store:get()
		if state.mode ~= "Run" or not state.run then
			return
		end
		local r = table.clone(state.run)
		r.distance += FIXTURE_SPEED_MPS * dt
		r.hopCooldown01 = math.max(0, r.hopCooldown01 - dt / 1.5)
		if r.dash then
			r.dash = math.max(0, r.dash - dt / 2.5)
			if r.dash <= 0 then
				r.dash = nil
			end
		end
		self.store:set("run", r)
	end)
	return self
end

function Scenarios.startRunState(self: any)
	self.store:set("run", {
		distance = 0,
		coins = 0,
		heat = 0.08,
		stage = "Calm",
		ride = car("puglet"),
		keys = nil,
		hop = "Available",
		hopCooldown01 = 0,
		dash = nil,
		best = 1100,
	})
end

function Scenarios.cancel(self: any)
	self._seq += 1
	if self._thread and coroutine.status(self._thread) ~= "dead" then
		pcall(task.cancel, self._thread)
	end
	self._thread = nil
	self.current = nil
end

local function emit(store: any, kind: string, fields: { [string]: any }?)
	local e = fields or {}
	e.id = kind .. "-" .. tostring(os.clock()) .. "-" .. tostring(math.random(1, 1e6))
	e.kind = kind
	store:emit(e)
end

local function setCash(store: any, value: number)
	store:set("exactCash", value)
	store:set("cash", value)
end

local function runPatch(store: any, patch: { [string]: any })
	local r = store:get().run
	if not r then
		return
	end
	local n = table.clone(r)
	for k, v in patch do
		n[k] = v
	end
	store:set("run", n)
end

local steps: { [string]: (self: any) -> () } = {}

steps["Cash gains and spends"] = function(self)
	local s = self.store
	setCash(s, 9450)
	task.wait(1)
	for _ = 1, 5 do -- frequent lap income: coalesced into one chip
		local v = s:get().cash + 120
		setCash(s, v)
		emit(s, "CashGain", { amount = 120 })
		task.wait(0.15)
	end
	task.wait(1.5)
	local v = s:get().cash + 5000
	setCash(s, v) -- a big gain (>= 10% of the balance and >= $500)
	emit(s, "CashGain", { amount = 5000 })
	task.wait(1.6)
	v = s:get().cash - 500
	setCash(s, v)
	emit(s, "CashSpend", { amount = 500 })
	task.wait(1.4)
	-- interrupted count-up: a new value arrives mid animation and wins
	setCash(s, v + 900)
	emit(s, "CashGain", { amount = 900 })
	task.wait(0.15)
	setCash(s, v + 2100)
	emit(s, "CashGain", { amount = 1200 })
	task.wait(1.5)
	-- from zero: a tiny gain must not trigger the big celebration
	setCash(s, 0)
	task.wait(0.8)
	setCash(s, 7)
	emit(s, "CashGain", { amount = 7 })
	task.wait(1.5)
end

steps["Extreme balances"] = function(self)
	for _, b in Fixtures.Balances do
		setCash(self.store, b)
		task.wait(1.1)
	end
end

steps["Menus and badges"] = function(self)
	local s = self.store
	for _, n in { 0, 1, 12, 3 } do
		s:set("garage", { owned = 3, total = 12, unseen = n })
		s:set("missionsClaimable", if n == 12 then 0 else n)
		task.wait(1.2)
	end
end

steps["Tutorial"] = function(self)
	local s = self.store
	local route = self.api.components.route
	if route and route.setRoute then
		-- a fixture route from the spawn toward the dummy Garage (no pathfinding)
		local g = self.api.backdrop.props.garage.Position
		local pts = {}
		for i = 0, 12 do
			table.insert(pts, Vector3.new(0, 0.3, 0):Lerp(Vector3.new(g.X, 0.3, g.Z + 8), i / 12))
		end
		route:setRoute(pts)
	end
	for i, step in Fixtures.Tutorial do
		for c = 0, step.goal, math.max(1, step.goal // 3) do
			s:set("tutorial", {
				step = i,
				steps = #Fixtures.Tutorial,
				objective = step.objective,
				count = c,
				goal = step.goal,
				hint = if c == 0 then step.hint else nil,
				state = if c == 0 then "Hint" else "Active",
			})
			task.wait(0.9)
		end
		s:set("tutorial", {
			step = i,
			steps = #Fixtures.Tutorial,
			objective = step.objective,
			count = step.goal,
			goal = step.goal,
			hint = nil,
			state = "Done",
		})
		emit(s, "TutorialComplete", { text = step.objective })
		task.wait(2)
	end
	s:set("tutorial", nil)
	if route and route.setRoute then
		route:setRoute(nil)
	end
end

steps["Toasts"] = function(self)
	local s = self.store
	emit(s, "Toast", { text = "Car added to your Garage", tone = "Success" })
	task.wait(0.3)
	emit(s, "Toast", { text = "Dusty Highway is coming soon", tone = "Info" })
	task.wait(0.3)
	emit(s, "Toast", { text = "New paint unlocked", tone = "Unlock" })
	task.wait(0.2)
	emit(s, "Toast", { text = "Car added to your Garage", tone = "Success" }) -- duplicate: merges
	task.wait(0.2)
	emit(s, "Toast", { text = "Lap complete", tone = "Info" })
	task.wait(0.2)
	emit(s, "Toast", { text = "Lap complete", tone = "Info" })
	task.wait(6)
end

steps["Lap Pay"] = function(self)
	local lap = self.api.components.lapPay
	for round = 1, 3 do
		for i, part in self.api.backdrop.lapCars do
			if lap and lap.pay then
				lap:pay(part, 120 + 40 * (i - 1))
			end
			task.wait(if round == 3 then 0.02 else 0.4) -- round 3: simultaneous, combined
		end
		task.wait(1.6)
	end
end

steps["Prompts"] = function(self)
	local p = self.api.components.prompts
	-- show the three dummy prompts without walking up to them (capture aid)
	for _, spec in self.api.promptsList or {} do
		local pp = spec[1]:FindFirstChildOfClass("ProximityPrompt")
		if pp and p and p.forceShow then
			p:forceShow(pp, true)
		end
	end
	for _, kind in { "Keyboard", "Gamepad", "Touch" } do
		if p and p.forceInputType then
			p:forceInputType(kind)
		end
		task.wait(2.5)
	end
	if p and p.forceInputType then
		p:forceInputType(nil)
	end
	for _, spec in self.api.promptsList or {} do
		local pp = spec[1]:FindFirstChildOfClass("ProximityPrompt")
		if pp and p and p.forceShow then
			p:forceShow(pp, false)
		end
	end
end

steps["Settings"] = function(self)
	self.api.open("settings")
	task.wait(4)
	self.api.close("settings")
	task.wait(1)
end

steps["Car cards"] = function(self)
	local g = self.api.components.garage
	self.api.open("garage")
	task.wait(4)
	if g and g.selectCar then
		g:selectCar("hyperion")
	end
	task.wait(2.5)
	if g and g.selectTab then
		g:selectTab("Dusty") -- empty case
		task.wait(1.5)
		g:selectTab("Summit") -- loading case
		task.wait(1.5)
		g:selectTab("Downtown")
	end
	task.wait(1)
	self.api.close("garage")
end

steps["Garage mock"] = steps["Car cards"]

steps["Portal card mock"] = function(self)
	local pc = self.api.components.portalCard
	if pc and pc.setLocked then
		pc:setLocked(true)
	end
	self.api.open("portalCard")
	task.wait(3.5)
	if pc and pc.setLocked then
		pc:setLocked(false) -- the open state with GO
	end
	task.wait(3)
	self.api.close("portalCard")
end

steps["Welcome Back mock"] = function(self)
	self.api.open("welcome")
	task.wait(5)
	self.api.close("welcome")
end

steps["Shop mock"] = function(self)
	self.api.open("shop")
	task.wait(5)
	self.api.close("shop")
end

local function enterRun(self: any)
	if self.store:get().mode ~= "Run" then
		if self.store:get().mode == "Results" then
			self.store:set("results", nil)
		end
		self.store:setMode("Run")
		self:startRunState()
	end
end

steps["Run: Heat"] = function(self)
	enterRun(self)
	local s = self.store
	for _, h in { { 0.1, "Calm" }, { 0.45, "Warning" }, { 0.72, "Warning" }, { 0.93, "Critical" } } do
		runPatch(s, { heat = h[1], stage = h[2] })
		task.wait(2)
	end
	-- rapid transitions
	for i = 1, 8 do
		runPatch(s, { heat = if i % 2 == 0 then 0.9 else 0.4, stage = if i % 2 == 0 then "Critical" else "Warning" })
		task.wait(0.25)
	end
	runPatch(s, { heat = 0.2, stage = "Calm" })
	task.wait(1.5)
end

steps["Run: Heat proposal variant"] = function(self)
	local run = self.api.components.run
	if run and run.setHeatVariant then
		run:setHeatVariant("Proposal")
	end
	steps["Run: Heat"](self)
	if run and run.setHeatVariant then
		run:setHeatVariant("Approved")
	end
end

steps["Run: Keys capture"] = function(self)
	enterRun(self)
	local s = self.store
	local target = car("rev6")
	for p = 0, 1, 0.1 do
		runPatch(s, { keys = { target = target, progress = p, status = "Holding" } })
		task.wait(0.25)
	end
	runPatch(s, { keys = { target = target, progress = 1, status = "Pending" } }) -- 100% is NOT ownership
	task.wait(1.4)
	runPatch(s, { keys = { target = target, progress = 1, status = "Confirmed" } })
	emit(s, "KeysConfirmed", { car = target }) -- the explicit confirmed-claim event
	task.wait(3)
	runPatch(s, { keys = nil, ride = target })
	task.wait(1)
end

steps["Run: Already owned"] = function(self)
	enterRun(self)
	local target = car("puglet")
	runPatch(self.store, { keys = { target = target, progress = 1, status = "Confirmed" } })
	emit(self.store, "AlreadyOwned", { car = target })
	task.wait(2.5)
	runPatch(self.store, { keys = nil })
end

steps["Run: Hop, Dash, milestones"] = function(self)
	enterRun(self)
	local s = self.store
	local ring = self.api.components.hopRing
	for _, st in { "Available", "Timing", "Unavailable", "Available" } do
		runPatch(s, { hop = st })
		if ring and ring.setState then
			ring:setState(st)
		end
		task.wait(1.6)
	end
	runPatch(s, { hopCooldown01 = 1 })
	emit(s, "Toast", { text = "Hop! (preview)", tone = "Info" })
	task.wait(1.8)
	runPatch(s, { dash = 1 })
	task.wait(3)
	emit(s, "Milestone", { text = "500 m!" })
	task.wait(1.6)
	emit(s, "Milestone", { text = "1 KM!" })
	task.wait(2)
end

local function results(self: any, key: string)
	enterRun(self)
	task.wait(1)
	local f = (Fixtures.Results :: any)[key]
	local claimed = {}
	for _, id in f.claimed do
		table.insert(claimed, car(id))
	end
	local res = {
		distance = f.distance,
		coins = f.coins,
		best = f.best,
		newBest = f.newBest,
		claimed = claimed,
		earnings = f.earnings,
	}
	self.store:set("results", res)
	self.store:setMode("Results")
	local card = self.api.components.results
	local capture = self.api.components.capture
	if capture and capture.takePendingCards then
		for _, c in capture:takePendingCards() do
			table.insert(claimed, c)
		end
	end
	if card and card.show then
		card:show(res, claimed)
	end
	task.wait(5)
end
steps["Results: typical"] = function(self)
	results(self, "Typical")
end
steps["Results: no rewards"] = function(self)
	results(self, "NoRewards")
end
steps["Results: many cars"] = function(self)
	results(self, "Many")
end
steps["Results: repeated clicks"] = function(self)
	results(self, "Typical")
	-- press Retry five times quickly: exactly one transition may happen
	local before = 0
	local conn = self.store.ModeChanged:Connect(function()
		before += 1
	end)
	local card = self.api.components.results
	for _ = 1, 5 do
		if card and card.pressRetry then
			card:pressRetry()
		end
		task.wait(0.05)
	end
	task.wait(0.5)
	conn:Disconnect()
	print("[Lane3Hud] repeated Retry presses produced " .. before .. " mode change(s)")
end

steps["Stunt mock"] = function(self)
	local st = self.api.components.stunt
	if st and st.open then
		st:open()
	end
	if st and st.play then
		st:play()
	end
	task.wait(5)
	if st and st.close then
		st:close()
	end
end

steps["Reduced motion mid-effect"] = function(self)
	local s = self.store
	local v = s:get().cash + 5000
	setCash(s, v)
	emit(s, "CashGain", { amount = 5000 })
	task.wait(0.15)
	Motion.setOverride(true)
	task.wait(2)
	emit(s, "Toast", { text = "Reduce Motion is on (preview)", tone = "Info" })
	enterRun(self)
	steps["Run: Keys capture"](self)
	Motion.setOverride(nil)
end

steps["Mode change mid-animation"] = function(self)
	local s = self.store
	setCash(s, s:get().cash + 5000)
	emit(s, "CashGain", { amount = 5000 })
	task.wait(0.1)
	enterRun(self)
	emit(s, "KeysConfirmed", { car = car("hurrikan") })
	task.wait(0.3)
	s:setMode("Home")
	task.wait(2)
end

steps["Stress: rapid events"] = function(self)
	-- a synthetic stress burst (not a valid game state; reported separately from normal load)
	local s = self.store
	for i = 1, 60 do
		setCash(s, s:get().cash + 37)
		emit(s, "CashGain", { amount = 37 })
		if i % 3 == 0 then
			emit(s, "Toast", { text = "Stress toast " .. (i % 4), tone = "Info" })
		end
		task.wait()
	end
	task.wait(3)
end

steps["Home tour"] = function(self)
	steps["Cash gains and spends"](self)
	steps["Menus and badges"](self)
	steps["Toasts"](self)
end

function Scenarios.play(self: any, name: string): boolean
	local fn = steps[name]
	if not fn then
		return false
	end
	self:cancel()
	local seq = self._seq
	self.current = name
	self._thread = task.spawn(function()
		local ok, err = pcall(fn, self)
		if not ok then
			warn("[Lane3Hud] scenario " .. name .. " failed: " .. tostring(err))
		end
		if self._seq == seq then
			self.current = nil
		end
	end)
	return true
end

function Scenarios.destroy(self: any)
	self:cancel()
	self._run:Disconnect()
end

return Scenarios
