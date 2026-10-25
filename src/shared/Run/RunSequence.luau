--!strict
-- Turns a run seed into the run's traffic, the same on the client and on the server
-- (run-report proposal: the server re-derives this list to spot-check what a client reports).
--
-- Rules that keep both sides identical:
--   * Cars are generated in one fixed order (always extend the lane whose next free spot is
--     nearest), each consuming the random stream the same way, so car N is the same car no
--     matter when or how far ahead anyone asked for it.
--   * A car's position depends only on its spawn values and run time: along = start + lane
--     speed x RunConfig.travelledAt(t); sideways = lane centre + a seeded weave. Nothing reads
--     the frame rate, input or os.clock.
--   * Traffic never reacts to the player. Bumps and the car the player rode are client-side
--     offsets on top of this schedule, never changes to it.
--   * Variants depend on ownership, which the server knows: the sequence only rolls a number
--     (variantRoll); RunSequence.variantFor turns it into a Variant for a given owner.

local Families = require(script.Parent.Families)
local RunConfig = require(script.Parent.RunConfig)

export type Spawn = {
	index: number,
	lane: number,
	start: number, -- studs along the road at run time 0
	family: Families.FamilyName,
	rarity: RunConfig.Rarity,
	size: RunConfig.Size,
	model: string, -- placeholder model id until the catalog exists: Family_Rarity
	paint: number, -- index into the client's proxy paint list
	phase: number, -- weave phase
	variantRoll: number, -- 0 to 1, see variantFor
	needs: number, -- Rider Level needed to claim
	odds: number, -- "1 in odds" for this model at this size, at this point of the run
}

export type RunSequence = {
	seed: number,
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
	local w = {
		Legendary = 0.006 + 0.024 * a,
		Epic = 0.03 + 0.07 * a,
		Rare = 0.15 + 0.1 * a,
	}
	w.Common = 1 - w.Legendary - w.Epic - w.Rare
	return w
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

local function pickSize(rng: Random): RunConfig.Size
	local roll = rng:NextNumber()
	local acc = 0
	for _, size: RunConfig.Size in RunConfig.SIZE_ORDER do
		if size == "Normal" then
			return "Normal"
		end
		acc += RunConfig.SIZE_CHANCE[size]
		if roll < acc then
			return size :: RunConfig.Size
		end
	end
	return "Normal"
end

local function sizeChance(size: RunConfig.Size): number
	if size ~= "Normal" then
		return RunConfig.SIZE_CHANCE[size]
	end
	local other = 0
	for _, s: RunConfig.Size in RunConfig.SIZE_ORDER do
		if s ~= "Normal" then
			other += RunConfig.SIZE_CHANCE[s]
		end
	end
	return 1 - other
end

local function allowedWeight(rarity: RunConfig.Rarity): number
	local total = 0
	for _, family in Families.LIST do
		if Families.allows(family, rarity) then
			total += family.weight
		end
	end
	return total
end

local function pickFamily(rng: Random, rarity: RunConfig.Rarity): Families.Family
	local roll = rng:NextNumber() * allowedWeight(rarity)
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

-- The chance of this exact model at this size appearing as one car at `distance`, as "1 in N".
function RunSequence.oddsFor(
	family: Families.Family,
	rarity: RunConfig.Rarity,
	size: RunConfig.Size,
	distance: number
): number
	local p = weightsAt(distance)[rarity] * (family.weight / allowedWeight(rarity)) * sizeChance(size)
	return math.max(1, math.round(1 / math.max(p, 1e-9)))
end

-- Which Variant a spawn shows for a player. Variants only appear on models the player owns.
function RunSequence.variantFor(spawn: Spawn, owned: boolean): RunConfig.Variant
	if not owned then
		return "None"
	end
	local roll = spawn.variantRoll
	local rainbow = RunConfig.VARIANT_CHANCE.Rainbow
	local chrome = rainbow + RunConfig.VARIANT_CHANCE.Chrome
	local gold = chrome + RunConfig.VARIANT_CHANCE.Gold
	if roll < rainbow then
		return "Rainbow"
	elseif roll < chrome then
		return "Chrome"
	elseif roll < gold then
		return "Gold"
	end
	return "None"
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
		local size: RunConfig.Size = pickSize(rng)
		local length = family.length * RunConfig.SIZE_SCALE[size]
		local spawn: Spawn = table.freeze({
			index = #self._spawns + 1,
			lane = lane,
			start = start + length / 2,
			family = family.name,
			rarity = rarity,
			size = size,
			model = family.name .. "_" .. rarity,
			paint = rng:NextInteger(1, PAINTS),
			phase = rng:NextNumber(0, 2 * math.pi),
			variantRoll = rng:NextNumber(),
			needs = RunConfig.needsFor(rarity, size),
			odds = RunSequence.oddsFor(family, rarity, size, start),
		})
		table.insert(self._spawns, spawn)
		-- Herds come in bunches: mostly short gaps, sometimes a long open stretch to steer through.
		local open = if rng:NextNumber() < 0.15 then rng:NextNumber(1.6, 3) else 1
		self._nextStart[lane] = start + length + gapAt(start) * rng:NextNumber(0.6, 1.5) * open
	end
	return self._spawns
end

function RunSequence.get(self: RunSequence, index: number): Spawn?
	return self._spawns[index]
end

function RunSequence.alongAt(_self: RunSequence, spawn: Spawn, t: number): number
	return spawn.start + RunConfig.LANE_SPEED[spawn.lane] * RunConfig.travelledAt(t)
end

function RunSequence.lateralAt(_self: RunSequence, spawn: Spawn, t: number): number
	return RunConfig.laneCenter(spawn.lane) + RunConfig.swayAt(spawn.phase, t)
end

return RunSequence
