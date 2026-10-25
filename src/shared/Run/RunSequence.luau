--!strict
-- Turns a run seed into the run's traffic, the same on the client and on the server
-- (run-report proposal: the server re-derives this list to spot-check what a client reports).
--
-- Rules that keep both sides identical:
--   * Cars are generated in one fixed order (always extend the lane whose next free spot is
--     nearest), each consuming the random stream the same way, so car N is the same car no
--     matter when or how far ahead anyone asked for it.
--   * A car's position depends only on its spawn values and run time: along = start + lane
--     speed x RunConfig.travelledAt(t). Nothing reads the frame rate, input or os.clock.
--   * Traffic never reacts to the player. Bumps and the car the player rode are client-side
--     offsets on top of this schedule, never changes to it.

local Families = require(script.Parent.Families)
local RunConfig = require(script.Parent.RunConfig)

export type Spawn = {
	index: number,
	lane: number,
	start: number, -- studs along the road at run time 0 (front of the queue grows from here)
	family: Families.FamilyName,
	rarity: RunConfig.Rarity,
	model: string, -- placeholder model id until the catalog exists: Family_Rarity
	paint: number, -- index into the client's proxy paint list
}

export type RunSequence = {
	seed: number,
	-- Every car whose start is below `distance`, generating more as needed. Read-only array.
	ensure: (self: RunSequence, distance: number) -> { Spawn },
	get: (self: RunSequence, index: number) -> Spawn?,
	alongAt: (self: RunSequence, spawn: Spawn, t: number) -> number,
	lateralAt: (self: RunSequence, spawn: Spawn, t: number) -> number,
	_rng: Random,
	_spawns: { Spawn },
	_nextStart: { number },
}

local PAINTS = 12

local RunSequence = {}
RunSequence.__index = RunSequence
RunSequence.PAINTS = PAINTS

local function weightsAt(distance: number): { [string]: number }
	local a = math.clamp(RunConfig.toMetres(distance) / 3000, 0, 1)
	return {
		Legendary = 0.006 + 0.024 * a,
		Epic = 0.03 + 0.07 * a,
		Rare = 0.15 + 0.1 * a,
		Common = 1,
	}
end

local RARITY_ORDER: { RunConfig.Rarity } = { "Legendary", "Epic", "Rare", "Common" }

local function pickRarity(rng: Random, distance: number): RunConfig.Rarity
	local w = weightsAt(distance)
	local roll = rng:NextNumber()
	local acc = 0
	for _, rarity: RunConfig.Rarity in RARITY_ORDER do
		if rarity == "Common" then
			return "Common"
		end
		acc += w[rarity]
		if roll < acc then
			return rarity :: RunConfig.Rarity
		end
	end
	return "Common"
end

local function pickFamily(rng: Random, rarity: RunConfig.Rarity): Families.Family
	local total = 0
	for _, family in Families.LIST do
		if Families.allows(family, rarity) then
			total += family.weight
		end
	end
	local roll = rng:NextNumber() * total
	local last: Families.Family? = nil
	for _, family in Families.LIST do
		if Families.allows(family, rarity) then
			last = family
			roll -= family.weight
			if roll < 0 then
				return family
			end
		end
	end
	assert(last, "no family allows " .. rarity)
	return last
end

local function gapAt(distance: number): number
	local a = math.clamp(distance / RunConfig.GAP_RAMP_DISTANCE, 0, 1)
	return RunConfig.GAP_START + (RunConfig.GAP_END - RunConfig.GAP_START) * a
end

function RunSequence.new(seed: number): RunSequence
	local rng = Random.new(seed)
	local nextStart = {}
	for lane = 1, RunConfig.LANES do
		nextStart[lane] = RunConfig.FIRST_CAR + rng:NextNumber(0, 40)
	end
	local self = setmetatable({
		seed = seed,
		_rng = rng,
		_spawns = {},
		_nextStart = nextStart,
	}, RunSequence)
	return (self :: any) :: RunSequence
end

function RunSequence.ensure(self: RunSequence, distance: number): { Spawn }
	while true do
		local lane, start = 1, self._nextStart[1]
		for l = 2, RunConfig.LANES do
			if self._nextStart[l] < start then
				lane, start = l, self._nextStart[l]
			end
		end
		if start >= distance then
			break
		end
		local rng = self._rng
		local rarity: RunConfig.Rarity = pickRarity(rng, start)
		local family = pickFamily(rng, rarity)
		local spawn: Spawn = table.freeze({
			index = #self._spawns + 1,
			lane = lane,
			start = start,
			family = family.name,
			rarity = rarity,
			model = family.name .. "_" .. rarity,
			paint = rng:NextInteger(1, PAINTS),
		})
		table.insert(self._spawns, spawn)
		-- Occasionally leave a long open stretch so there is always room to steer.
		local open = if rng:NextNumber() < 0.15 then rng:NextNumber(1.5, 3) else 1
		self._nextStart[lane] = start + family.length + gapAt(start) * rng:NextNumber(0.75, 1.6) * open
	end
	return self._spawns
end

function RunSequence.get(self: RunSequence, index: number): Spawn?
	return self._spawns[index]
end

function RunSequence.alongAt(_self: RunSequence, spawn: Spawn, t: number): number
	return spawn.start + RunConfig.LANE_SPEED[spawn.lane] * RunConfig.travelledAt(t)
end

function RunSequence.lateralAt(_self: RunSequence, spawn: Spawn, _t: number): number
	return RunConfig.laneCenter(spawn.lane)
end

return RunSequence
