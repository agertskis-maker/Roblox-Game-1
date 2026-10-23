--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, ledger R2-S1). The stand-in for the owner of the Stamina rule while the
-- team has not decided it. It exists so the meter can be shown and tested; nothing here is a game rule and
-- nothing runs unless switched on. OFF by default.
--
-- Proposal being demonstrated (documented for Brian R / Brian L, never sent): 10 Stamina per run; one is
-- spent per ACCEPTED hop; a rejected attempt (no target, cooldown, airborne) spends nothing; at zero no more
-- hops while the current ride continues; an optional restoring pickup (a separate switch, also off) adds one,
-- clamped to the maximum. Max-Stamina upgrades and pickup placement are unresolved team decisions.
--
--   local fx = StaminaFixture.new(store)
--   fx:setEnabled(true, max?)   fx:setRestore(true)   fx:reset()
--   fx:initial() -> StaminaState?   -- what a new run starts with (nil while off)
--   fx:getDebugState()
-- Events it reacts to (delivered through store:emit): "HopAccepted", "HopRejected" (reason), "StaminaPickup".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Store = require(Prototype:WaitForChild("Store"))
local Trove = require(ReplicatedStorage.Packages.Trove)

local StaminaFixture = {}
StaminaFixture.__index = StaminaFixture

function StaminaFixture.new(store: Store.StoreObject)
	local self = setmetatable({}, StaminaFixture)
	self._store = store
	self._trove = Trove.new()
	self.enabled = false
	self.restore = false
	self.max = 10
	self.counts = { spent = 0, rejected = 0, pickups = 0, clamped = 0, ignoredAtZero = 0 }
	self._trove:Connect(store.Event, function(event: Store.Event)
		self:_onEvent(event)
	end)
	return self
end

function StaminaFixture.initial(self: any): Store.StaminaState?
	if not self.enabled then
		return nil
	end
	return { value = self.max, max = self.max, lowAt = 3, restore = self.restore }
end

function StaminaFixture._patch(self: any, fn: (Store.StaminaState) -> Store.StaminaState)
	local run = self._store:get().run
	if not run or not run.stamina then
		return
	end
	local merged = table.clone(run) :: any
	merged.stamina = fn(run.stamina)
	self._store:set("run", merged)
end

function StaminaFixture._onEvent(self: any, event: Store.Event)
	if not self.enabled then
		return
	end
	local run = self._store:get().run
	if not run or not run.stamina then
		return
	end
	if event.kind == "HopAccepted" then
		if run.stamina.value <= 0 then
			self.counts.ignoredAtZero += 1 -- a hop cannot be accepted at zero; the proposal blocks it
			return
		end
		self.counts.spent += 1
		self:_patch(function(s)
			return { value = math.max(0, s.value - 1), max = s.max, lowAt = s.lowAt, restore = s.restore }
		end)
	elseif event.kind == "HopRejected" then
		self.counts.rejected += 1 -- no target, cooldown, airborne: nothing is spent
	elseif event.kind == "StaminaPickup" then
		if not self.restore then
			return
		end
		self.counts.pickups += 1
		self:_patch(function(s)
			local nextValue = s.value + 1
			if nextValue > s.max then
				self.counts.clamped += 1
				nextValue = s.max
			end
			return { value = nextValue, max = s.max, lowAt = s.lowAt, restore = s.restore }
		end)
	end
end

-- Switches the demo on or off for the current and later runs (off = the meter disappears).
function StaminaFixture.setEnabled(self: any, on: boolean, max: number?)
	self.enabled = on
	if max ~= nil then
		self.max = math.max(1, math.floor(max))
	end
	local run = self._store:get().run
	if run then
		local merged = table.clone(run) :: any
		merged.stamina = self:initial()
		self._store:set("run", merged)
	end
end

function StaminaFixture.setRestore(self: any, on: boolean)
	self.restore = on
	self:_patch(function(s)
		return { value = s.value, max = s.max, lowAt = s.lowAt, restore = on }
	end)
end

-- Back to a full meter (between fixture runs).
function StaminaFixture.reset(self: any)
	table.clear(self.counts)
	self.counts = { spent = 0, rejected = 0, pickups = 0, clamped = 0, ignoredAtZero = 0 }
	self:_patch(function(s)
		return { value = s.max, max = s.max, lowAt = s.lowAt, restore = s.restore }
	end)
end

function StaminaFixture.getDebugState(self: any): { [string]: any }
	local run = self._store:get().run
	return {
		enabled = self.enabled,
		restore = self.restore,
		max = self.max,
		value = run and run.stamina and run.stamina.value,
		counts = self.counts,
	}
end

function StaminaFixture.destroy(self: any)
	self._trove:Destroy()
end

return StaminaFixture
