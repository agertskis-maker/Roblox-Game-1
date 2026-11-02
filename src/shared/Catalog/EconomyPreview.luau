--!strict
-- Economy PREVIEW numbers (Lane 2, Brian L). Every value is Tunable and comes from
-- vault/design/specs/economy-v1.md, which is a proposal: the real Catalog, save layout and
-- remotes change only after all three lane owners write "Agreed" on the board. Pure data and
-- maths, no Roblox services, so the same module runs on the server, the client and in tests.

export type Rarity = "COMMON" | "UNCOMMON" | "RARE" | "EPIC" | "LEGENDARY"

export type RarityInfo = {
	keysSeconds: number,
	lapPay: number,
	claimBonus: number,
	joyrideBonus: number,
}

export type EditionInfo = {
	name: string,
	multiplier: number,
}

local EconomyPreview = {}

EconomyPreview.LapSeconds = 15

EconomyPreview.Rarities = {
	COMMON = { keysSeconds = 3, lapPay = 10, claimBonus = 100, joyrideBonus = 30 },
	UNCOMMON = { keysSeconds = 3.5, lapPay = 50, claimBonus = 500, joyrideBonus = 150 },
	RARE = { keysSeconds = 4, lapPay = 250, claimBonus = 2_500, joyrideBonus = 750 },
	EPIC = { keysSeconds = 5, lapPay = 2_000, claimBonus = 20_000, joyrideBonus = 6_000 },
	LEGENDARY = { keysSeconds = 6, lapPay = 25_000, claimBonus = 250_000, joyrideBonus = 75_000 },
} :: { [Rarity]: RarityInfo }

-- Edition 1 is Normal. Every CopiesPerEdition copies at one edition merge into the next.
EconomyPreview.Editions = {
	{ name = "Normal", multiplier = 1 },
	{ name = "Gold", multiplier = 3 },
	{ name = "Diamond", multiplier = 10 },
	{ name = "Rainbow", multiplier = 50 },
	{ name = "Galaxy", multiplier = 250 },
} :: { EditionInfo }

EconomyPreview.CopiesPerEdition = 25

-- Index = Raceway level. Price[level] is the cost to reach that level (level 1 is the start).
EconomyPreview.RacewayMultiplier = { 1, 1.9, 3.5, 6.5, 12, 23, 43, 80, 150, 285, 535, 1_000 }
EconomyPreview.RacewayPrice = {
	0,
	1_000,
	5_000,
	25_000,
	150_000,
	1_000_000,
	7_000_000,
	50_000_000,
	400_000_000,
	3_000_000_000,
	25_000_000_000,
	2_000_000_000_000,
}
EconomyPreview.MaxRacewayLevel = 12

EconomyPreview.StartParkingSpots = 2
EconomyPreview.MaxParkingSpots = 15
EconomyPreview.FirstSpotPrice = 500
EconomyPreview.SpotGrowth = 3

EconomyPreview.OfflineRate = 0.5
EconomyPreview.OfflineCapSeconds = 8 * 60 * 60

-- Rounds down to 2 significant figures so prices read as friendly numbers ($365K, not $364.5K).
local function friendly(n: number): number
	if n < 100 then
		return math.floor(n)
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude) * magnitude
end

-- Price of buying spot number `spot` (3 to 15); nil when the spot cannot be bought.
function EconomyPreview.parkingSpotPrice(spot: number): number?
	if spot <= EconomyPreview.StartParkingSpots or spot > EconomyPreview.MaxParkingSpots then
		return nil
	end
	return friendly(EconomyPreview.FirstSpotPrice * EconomyPreview.SpotGrowth ^ (spot - 3))
end

-- Price of reaching Raceway `level` (2 to 12); nil when the level cannot be bought.
function EconomyPreview.racewayPrice(level: number): number?
	if level < 2 or level > EconomyPreview.MaxRacewayLevel then
		return nil
	end
	return EconomyPreview.RacewayPrice[level]
end

function EconomyPreview.racewayMultiplier(level: number): number
	local clamped = math.clamp(math.floor(level), 1, EconomyPreview.MaxRacewayLevel)
	return EconomyPreview.RacewayMultiplier[clamped]
end

function EconomyPreview.editionMultiplier(edition: number): number
	local info = EconomyPreview.Editions[math.clamp(math.floor(edition), 1, #EconomyPreview.Editions)]
	return info.multiplier
end

function EconomyPreview.editionName(edition: number): string
	local info = EconomyPreview.Editions[math.clamp(math.floor(edition), 1, #EconomyPreview.Editions)]
	return info.name
end

-- Total copies a car needs to reach `edition`: 1 for Normal, then CopiesPerEdition times more
-- for each step (25 merge into 1 Gold, 25 Gold into 1 Diamond, ...), so 25, 625, 15,625, 390,625.
function EconomyPreview.copiesForEdition(edition: number): number
	if edition <= 1 then
		return 0
	end
	return EconomyPreview.CopiesPerEdition ^ (edition - 1)
end

-- `copies` is the car's lifetime copy count. Adds `added` and returns the edition that total has
-- reached (never lower than the current one) and the new total. Copies are never thrown away.
function EconomyPreview.addCopies(edition: number, copies: number, added: number): (number, number)
	local total = copies + added
	local e = edition
	while e < #EconomyPreview.Editions and total >= EconomyPreview.copiesForEdition(e + 1) do
		e += 1
	end
	return e, total
end

function EconomyPreview.lapPay(rarity: Rarity, edition: number, racewayLevel: number): number
	local info = EconomyPreview.Rarities[rarity]
	if not info then
		return 0
	end
	return info.lapPay * EconomyPreview.editionMultiplier(edition) * EconomyPreview.racewayMultiplier(racewayLevel)
end

function EconomyPreview.joyrideBonus(rarity: Rarity, edition: number): number
	local info = EconomyPreview.Rarities[rarity]
	if not info then
		return 0
	end
	return info.joyrideBonus * EconomyPreview.editionMultiplier(edition)
end

-- Offline pay for `seconds` away, given the Lineup's total Lap Pay per lap.
function EconomyPreview.offlinePay(payPerLap: number, seconds: number): number
	local capped = math.clamp(seconds, 0, EconomyPreview.OfflineCapSeconds)
	local laps = math.floor(capped / EconomyPreview.LapSeconds)
	return math.floor(payPerLap * laps * EconomyPreview.OfflineRate)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }

-- "$950", "$1.2K", "$3.4M", "$5.6B", "$7.8T". One decimal, dropped when it is .0.
function EconomyPreview.formatCash(n: number): string
	local value = math.max(0, math.floor(n))
	local index = 1
	while value >= 1_000 and index < #SUFFIXES do
		value /= 1_000
		index += 1
	end
	if index == 1 then
		return "$" .. tostring(value)
	end
	local tenths = math.floor(value * 10) / 10
	local text = if tenths == math.floor(tenths) then string.format("%d", tenths) else string.format("%.1f", tenths)
	return "$" .. text .. SUFFIXES[index]
end

return EconomyPreview
