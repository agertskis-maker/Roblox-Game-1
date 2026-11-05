--!strict
-- StuntCircuitFeed: the ONE adapter between the Stunt Circuit screens and whatever reports a Circuit lap (Round 6, C-01).
--
-- Brian R's Circuit (src/client/Run, profile "Circuit") has no start line, checkpoints or finish yet: a crash just ends the
-- run (read 2026-11-05, commit 38e7995). So the screens are built against the events Lane 3 proposed to him
-- (lane3-round6-for-brian-r.md, question 5), names only, no amounts:
--   CircuitStart { t, worldId = "StuntCircuit" }   CircuitCheckpoint { t, index }   CircuitFinish { t, lapTime }
--   CircuitEnd { t, cause }  (a crash)
-- Until his run raises them, `feed:fixtureLap()` plays a PREVIEW lap that raises the same events on a timer, labelled
-- PREVIEW wherever it shows. When his run reports them, it calls feed:emit(...) instead and nothing else changes.
-- Every event goes to the server (the beta's CircuitEvent remote), which keeps the clock: the client never sends a time.
-- With no server (previews) the time is measured here and marked as such.
--
--   local feed = StuntCircuitFeed.new({ onEvent = fn(kind, index?)?, onResult = fn(finished, time?, bestBefore?)? })
--   feed:emit(kind, index?)     feed:fixtureLap()     feed:cancel()     feed:best() -> number?     feed:destroy()
--   StuntCircuitFeed.Events     StuntCircuitFeed.Checkpoints     StuntCircuitFeed.source() -> "fixture" | "run"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local Trove = require(ReplicatedStorage.Packages.Trove)

local StuntCircuitFeed = {}
StuntCircuitFeed.__index = StuntCircuitFeed

StuntCircuitFeed.Events = table.freeze({
	Start = "CircuitStart",
	Checkpoint = "CircuitCheckpoint",
	Finish = "CircuitFinish",
	End = "CircuitEnd",
})
StuntCircuitFeed.Checkpoints = 5 -- the PREVIEW lap (the server's BetaCircuit.Checkpoints matches)
StuntCircuitFeed.EventRemote = "CircuitEvent"
StuntCircuitFeed.ResultRemote = "CircuitResult"
local SPLIT_MIN, SPLIT_MAX = 2.0, 3.4 -- seconds between the PREVIEW lap's checkpoints (Tunable)

-- "run" once Brian R's Circuit reports the events (then this returns "run" and fixtureLap is not used).
function StuntCircuitFeed.source(): string
	return "fixture"
end

export type Options = {
	onEvent: ((kind: string, index: number?) -> ())?,
	onResult: ((finished: boolean, time: number?, bestBefore: number?) -> ())?,
}

function StuntCircuitFeed.new(options: Options?)
	local self = setmetatable({}, StuntCircuitFeed)
	self._opts = options or {}
	self._trove = Trove.new()
	self._lap = nil :: thread?
	self._started = nil :: number?
	self._best = nil :: number?
	local result = LiveData.remote(StuntCircuitFeed.ResultRemote)
	if result then
		self._trove:Connect(result.OnClientEvent, function(finished: any, time: any, before: any)
			self:_result(
				finished == true,
				if type(time) == "number" then time else nil,
				if type(before) == "number" then before else nil
			)
		end)
	end
	return self
end

export type Feed = typeof(StuntCircuitFeed.new())

function StuntCircuitFeed._result(self: Feed, finished: boolean, time: number?, before: number?)
	if finished and time and (self._best == nil or time < (self._best :: number)) then
		self._best = time
	end
	local fn = self._opts.onResult
	if fn then
		fn(finished, time, before)
	end
end

function StuntCircuitFeed.best(self: Feed): number?
	return self._best
end

-- One event, from the PREVIEW lap now or Brian R's run later.
function StuntCircuitFeed.emit(self: Feed, kind: string, index: number?)
	local remote = LiveData.remote(StuntCircuitFeed.EventRemote)
	if remote then
		remote:FireServer(kind, index)
	end
	local fn = self._opts.onEvent
	if fn then
		fn(kind, index)
	end
	if remote then
		return -- the server answers with CircuitResult
	end
	-- no server (a preview): measured here, never shown as a server time
	if kind == StuntCircuitFeed.Events.Start then
		self._started = os.clock()
	elseif kind == StuntCircuitFeed.Events.Finish and self._started then
		local time = math.floor((os.clock() - (self._started :: number)) * 100) / 100
		local before = self._best
		self._started = nil
		self:_result(true, time, before)
	elseif kind == StuntCircuitFeed.Events.End then
		self._started = nil
		self:_result(false, nil, self._best)
	end
end

-- The PREVIEW lap: start, five checkpoints a few seconds apart, finish.
function StuntCircuitFeed.fixtureLap(self: Feed)
	self:cancel()
	local rng = Random.new()
	self._lap = task.spawn(function()
		self:emit(StuntCircuitFeed.Events.Start)
		for i = 1, StuntCircuitFeed.Checkpoints do
			task.wait(rng:NextNumber(SPLIT_MIN, SPLIT_MAX))
			self:emit(StuntCircuitFeed.Events.Checkpoint, i)
		end
		task.wait(rng:NextNumber(SPLIT_MIN, SPLIT_MAX))
		self._lap = nil
		self:emit(StuntCircuitFeed.Events.Finish)
	end)
end

-- Stops a lap that is still running (the player left the card): it ends with no time.
function StuntCircuitFeed.cancel(self: Feed)
	local lap = self._lap
	if lap then
		self._lap = nil
		pcall(task.cancel, lap)
		self:emit(StuntCircuitFeed.Events.End)
	end
end

function StuntCircuitFeed.destroy(self: Feed)
	self:cancel()
	self._trove:Destroy()
end

return StuntCircuitFeed
