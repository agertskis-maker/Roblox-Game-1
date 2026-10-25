--!strict
-- Collects what happened in a run in the shape of the run-report proposal (Lane 1 -> Lane 2),
-- so the Stage 1 prototype already produces the events Brian L's remotes will carry.
-- Nothing is sent anywhere yet: there are no remotes until the proposal is agreed. Batches go
-- out through the Batch signal (and KeysComplete events through Urgent) for whoever wires them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.Shared.Run.RunConfig)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type EventKind = "Hop" | "KeysComplete" | "RunEnd"

export type Event = {
	kind: EventKind,
	t: number, -- seconds since run start
	d: number, -- studs along the road
	x: number?, -- Hop: sideways position at launch
	target: number?, -- Hop: spawn index landed on, 0 = the road
	index: number?, -- KeysComplete: spawn index
	cause: string?, -- RunEnd: Meltdown | FootDash | Quit
}

export type RunReport = {
	seed: number,
	Batch: any, -- Signal(events: { Event })
	Urgent: any, -- Signal(event: Event)
	push: (self: RunReport, event: Event) -> (),
	step: (self: RunReport, t: number) -> (),
	flush: (self: RunReport) -> { Event },
	counts: (self: RunReport) -> { [string]: number },
	destroy: (self: RunReport) -> (),
	_pending: { Event },
	_all: { Event },
	_lastFlush: number,
	_trove: any,
}

local RunReport = {}
RunReport.__index = RunReport

local function round(n: number, places: number): number
	local m = 10 ^ places
	return math.round(n * m) / m
end

function RunReport.new(seed: number): RunReport
	local trove = Trove.new()
	local self = setmetatable({
		seed = seed,
		Batch = trove:Add(Signal.new()),
		Urgent = trove:Add(Signal.new()),
		_pending = {},
		_all = {},
		_lastFlush = 0,
		_trove = trove,
	}, RunReport)
	return (self :: any) :: RunReport
end

function RunReport.push(self: RunReport, event: Event)
	local e: Event = table.clone(event)
	e.t = round(e.t, 3)
	e.d = round(e.d, 2)
	if e.x then
		e.x = round(e.x, 2)
	end
	table.insert(self._all, e)
	if e.kind == "KeysComplete" then
		self.Urgent:Fire(e)
	else
		table.insert(self._pending, e)
	end
	if e.kind == "RunEnd" then
		self:flush()
	end
end

function RunReport.step(self: RunReport, t: number)
	if t - self._lastFlush >= RunConfig.EVENT_BATCH_INTERVAL then
		self._lastFlush = t
		self:flush()
	end
end

function RunReport.flush(self: RunReport): { Event }
	local batch = self._pending
	if #batch > 0 then
		self._pending = {}
		self.Batch:Fire(batch)
	end
	return batch
end

function RunReport.counts(self: RunReport): { [string]: number }
	local counts: { [string]: number } = {}
	for _, e in self._all do
		counts[e.kind] = (counts[e.kind] or 0) + 1
	end
	return counts
end

function RunReport.destroy(self: RunReport)
	self._trove:Destroy()
end

return RunReport
