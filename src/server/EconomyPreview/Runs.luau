--!strict
-- Server side of the run report (Lane 2, PREVIEW), following decision 0021 (Agreed by Brian L and
-- Adam on 2026-10-28). The client asks to start a run in a World; the server checks the World is
-- unlocked, hands out a seed and rebuilds the same traffic with Lane 1's shared RunSequence. The
-- client then reports what happened (Hop, KeysComplete, RunEnd); it never sends an amount, a car
-- or a result. Every event is checked against the rebuilt traffic and the server clock, and
-- anything that fails is dropped and logged, never punished. Accepted events pay here:
--   KeysComplete on a car not owned = claim (car + claim bonus); on an owned car = Joyride (bonus
--   + one edition copy); RunEnd = distance Milestones.
-- Run traffic cars are placeholders (Family_Rarity); each becomes one of the World's showroom
-- cars (Catalog.CarWorld), picked from the spawn's own numbers so every machine agrees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog.EconomyPreview)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Cars = require(script.Parent.Cars)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)

local Runs = {}

-- Fires (player, result) for each payout, for a later client notice: result is a table with
-- kind ("Claim" | "Joyride" | "Milestone"), car (string?), amount (number), edition (number?).
Runs.Granted = Signal.new()

local MAX_EVENTS_PER_BATCH = 64
local CLOCK_TOLERANCE = 3 -- seconds a client clock may run ahead of the server's
local KEYS_TOLERANCE = 0.25 -- seconds short of the Keys time still accepted
local HOP_REACH = 90 -- studs between the reported position and the target car
local MAX_RUN_SECONDS = 60 * 60
-- Adam's review of 2026-11-05 (F1 to F3); the values match Lane 3's BetaRun.Caps.
local AHEAD_STUDS = 1_500 -- how far d may lead the run's own travelled distance (a Hop onto a car ahead)
local BACK_STUDS = 5 -- how far d may go backwards between events
local MAX_KEYS_PER_RUN = 5 -- claims plus Joyrides in one run: the Stamina bolt count
local START_COOLDOWN = 0.75 -- seconds between StartRun calls

type Ride = { index: number, since: number }

type Run = {
	id: string,
	worldId: string,
	seed: number,
	sequence: any,
	started: number,
	lastT: number,
	lastD: number,
	ride: Ride?,
	paid: { [number]: boolean },
	keys: number,
	ended: boolean,
}

local active: { [Player]: Run } = {}
local lastStart: { [Player]: number } = {}
local counter = 0

local function sharedRun(): Instance?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	return shared and shared:FindFirstChild("Run")
end

local function runModules(): (any, any)
	local folder = sharedRun()
	if not folder then
		return nil, nil
	end
	local seq = folder:FindFirstChild("RunSequence")
	local cfg = folder:FindFirstChild("RunConfig")
	if not (seq and seq:IsA("ModuleScript") and cfg and cfg:IsA("ModuleScript")) then
		return nil, nil
	end
	return require(seq) :: any, require(cfg) :: any
end

local function reject(player: Player, why: string)
	warn(string.format("[EconomyPreview] run event from %s dropped: %s", player.Name, why))
end

-- The showroom car a traffic spawn stands for in this World, or nil if the World has none.
local CATALOG_RARITY: { [string]: Catalog.Rarity } = {
	Common = "COMMON",
	Rare = "RARE",
	Epic = "EPIC",
	Legendary = "LEGENDARY",
}

local function carsOf(worldId: string, rarity: Catalog.Rarity): { string }
	local list: { string } = {}
	for id, world in Catalog.CarWorld do
		if world == worldId and Cars.rarity(id) == rarity then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

local FALLBACK: { [Catalog.Rarity]: { Catalog.Rarity } } = {
	COMMON = { "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY" },
	UNCOMMON = { "UNCOMMON", "COMMON", "RARE", "EPIC", "LEGENDARY" },
	RARE = { "RARE", "UNCOMMON", "EPIC", "COMMON", "LEGENDARY" },
	EPIC = { "EPIC", "RARE", "LEGENDARY", "UNCOMMON", "COMMON" },
	LEGENDARY = { "LEGENDARY", "EPIC", "RARE", "UNCOMMON", "COMMON" },
}

function Runs.carFor(worldId: string, spawn: any): string?
	local rarity = CATALOG_RARITY[spawn.rarity]
	if not rarity then
		return nil
	end
	if rarity == "COMMON" and (spawn.paint / 12) <= Catalog.UncommonShareOfCommons then
		rarity = "UNCOMMON"
	end
	for _, tier in FALLBACK[rarity] do
		local list = carsOf(worldId, tier)
		if #list > 0 then
			return list[(spawn.index - 1) % #list + 1]
		end
	end
	return nil
end

-- Starts a run. Returns { runId, seed } or nil when the World is unknown or locked.
function Runs.start(player: Player, worldId: unknown): { runId: string, seed: number }?
	local data = Data.get(player)
	local RunSequence = runModules()
	if not data or typeof(worldId) ~= "string" or not Catalog.world(worldId) then
		return nil
	end
	if not data.WorldsUnlocked[worldId] or not RunSequence then
		return nil
	end
	local now = os.clock()
	local last = lastStart[player]
	if last and now - last < START_COOLDOWN then
		return nil
	end
	lastStart[player] = now
	counter += 1
	local seed = Random.new():NextInteger(1, 2_000_000_000)
	local run: Run = {
		id = tostring(player.UserId) .. "-" .. counter,
		worldId = worldId,
		seed = seed,
		sequence = RunSequence.new(seed),
		started = os.clock(),
		lastT = 0,
		lastD = 0,
		ride = nil,
		paid = {},
		keys = 0,
		ended = false,
	}
	active[player] = run
	return { runId = run.id, seed = seed }
end

local function number(value: unknown, low: number, high: number): number?
	if typeof(value) ~= "number" or value ~= value or value < low or value > high then
		return nil
	end
	return value
end

local function grant(player: Player, result: { [string]: any })
	Runs.Granted:Fire(player, result)
end

-- The furthest the run's traffic has carried a rider by time `t`. Older copies of Lane 1's
-- RunSequence have no travelledAt, so the speed at `t` times `t` stands in (an over-estimate,
-- because the speed only rises).
local function travelledAt(run: Run, t: number): number
	local seq = run.sequence
	if typeof(seq.travelledAt) == "function" then
		return seq:travelledAt(math.max(t, 0))
	end
	return math.max(t, 0) * seq:speedAt(t)
end

-- F1 and F2: every event's distance must be one the run can have reached by its time, and may
-- not go backwards. Checked before the distance is used for anything (ensure, Milestones).
local function distanceOk(run: Run, t: number, d: number): boolean
	return d >= run.lastD - BACK_STUDS and d <= travelledAt(run, t) + AHEAD_STUDS
end

local function onKeys(player: Player, run: Run, t: number, index: number)
	local _, RunConfig = runModules()
	local ride = run.ride
	if not ride or ride.index ~= index then
		return reject(player, "Keys on a car the player is not riding")
	end
	if run.paid[index] then
		return reject(player, "Keys already paid for this car")
	end
	if run.keys >= MAX_KEYS_PER_RUN then
		return reject(player, "more Keys than the run's Stamina bolts")
	end
	local spawn = run.sequence:get(index)
	if not spawn or not RunConfig then
		return reject(player, "unknown car")
	end
	local keys = RunConfig.KEYS_TIME[spawn.rarity]
	if typeof(keys) ~= "number" or t - ride.since < keys - KEYS_TOLERANCE then
		return reject(player, "Keys filled faster than allowed")
	end
	run.paid[index] = true
	run.keys += 1
	local id = Runs.carFor(run.worldId, spawn)
	local data = Data.get(player)
	if not id or not data then
		return
	end
	if data.Cars[id] then
		local before = Economy.lapPayFor(player, id)
		Economy.joyride(player, id, 1)
		grant(player, { kind = "Joyride", car = id, edition = data.Cars[id].Edition, lapPay = before })
	else
		Economy.claimCar(player, id)
		grant(player, { kind = "Claim", car = id })
	end
end

local function onHop(player: Player, run: Run, t: number, d: number, target: number)
	if target == 0 then
		run.ride = nil
		return
	end
	run.sequence:ensure(d + 2_000)
	local spawn = run.sequence:get(target)
	if not spawn then
		return reject(player, "Hop onto a car that does not exist")
	end
	local along = run.sequence:alongAt(spawn, t)
	if math.abs(along - d) > HOP_REACH then
		return reject(player, "Hop onto a car too far away")
	end
	run.ride = { index = target, since = t }
end

local function onEnd(player: Player, run: Run, t: number, d: number)
	local _, RunConfig = runModules()
	run.ended = true
	active[player] = nil
	if not RunConfig then
		return
	end
	-- `d` already passed distanceOk; Milestones count only what the run itself travelled by `t`
	local distance = math.min(d, travelledAt(run, t))
	local info = Catalog.world(run.worldId)
	local milestones = math.floor(RunConfig.toMetres(distance) / Catalog.MilestoneMetres)
	if info and milestones > 0 then
		local amount = milestones * info.milestonePay
		Economy.addCash(player, amount, string.format("%d Milestones", milestones))
		grant(player, { kind = "Milestone", count = milestones, amount = amount })
	end
end

-- Handles one batch of events from the run's client (RunEvents remote, or KeysComplete alone).
function Runs.report(player: Player, runId: unknown, events: unknown)
	local run = active[player]
	if not run or run.ended or runId ~= run.id then
		return reject(player, "no such run")
	end
	if typeof(events) ~= "table" then
		return reject(player, "events is not a list")
	end
	local list = events :: { any }
	if #list > MAX_EVENTS_PER_BATCH then
		return reject(player, "too many events at once")
	end
	local now = os.clock() - run.started
	for _, event in list do
		if typeof(event) ~= "table" then
			return reject(player, "event is not a table")
		end
		local kind = event.kind
		local t = number(event.t, run.lastT - 0.001, math.min(now + CLOCK_TOLERANCE, MAX_RUN_SECONDS))
		local d = number(event.d, 0, 10_000_000)
		if not t or not d then
			return reject(player, "event time or distance out of range")
		end
		if not distanceOk(run, t, d) then
			return reject(player, "distance the run cannot have reached by then")
		end
		if kind == "Hop" then
			local target = number(event.target, 0, 1_000_000)
			if not target or target ~= math.floor(target) then
				return reject(player, "Hop target is not a car index")
			end
			onHop(player, run, t, d, target)
		elseif kind == "KeysComplete" then
			local index = number(event.index, 1, 1_000_000)
			if not index or index ~= math.floor(index) then
				return reject(player, "Keys index is not a car index")
			end
			onKeys(player, run, t, index)
		elseif kind == "RunEnd" then
			onEnd(player, run, t, d)
			return
		elseif kind ~= "Revive" then
			return reject(player, "unknown event kind")
		end
		run.lastT = t
		run.lastD = math.max(run.lastD, d)
	end
end

function Runs.active(player: Player): any
	return active[player]
end

Players.PlayerRemoving:Connect(function(player: Player)
	active[player] = nil
	lastStart[player] = nil
end)

return Runs
