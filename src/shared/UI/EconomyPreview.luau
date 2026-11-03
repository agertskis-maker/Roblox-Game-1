--!strict
-- EconomyPreview: every economy number a Lane 3 screen draws, in ONE place (Round 4, E-06, E-08, C-03). PREVIEW ONLY.
-- The values are Brian L's proposal, economy v1 (vault/design/specs/economy-v1.md on feature/lane2-economy-design), not
-- agreed numbers: screens tag them PREVIEW, and his server's values replace this module in one edit. Nothing here pays,
-- saves or checks anything; affordability on a screen always compares these numbers, never their text.
--
--   EconomyPreview.lapPay(rarity, edition?, racewayLevel?) -> number    the Lap Pay of one car per lap
--   EconomyPreview.edition(n) -> Edition                                1 Normal .. 5 Galaxy
--   EconomyPreview.editionProgress(edition, copies) -> Progress         the "12 / 25 copies to GOLD" facts
--   EconomyPreview.racewayPrice(level) -> number?                       the price of reaching that level (nil for 1 and past 12)
--   EconomyPreview.spotPrice(spot) -> number?                           the price of parking spot 3..15
--   EconomyPreview.selfTest() -> { string }

local EconomyPreview = {}

-- Section 3: per rarity, Normal edition.
EconomyPreview.Rarity = table.freeze({
	Common = { lapPay = 10, claimBonus = 100, joyride = 30, keysSeconds = 3 },
	Uncommon = { lapPay = 50, claimBonus = 500, joyride = 150, keysSeconds = 3.5 },
	Rare = { lapPay = 250, claimBonus = 2500, joyride = 750, keysSeconds = 4 },
	Epic = { lapPay = 2000, claimBonus = 20000, joyride = 6000, keysSeconds = 5 },
	Legendary = { lapPay = 25000, claimBonus = 250000, joyride = 75000, keysSeconds = 6 },
}) :: { [string]: { lapPay: number, claimBonus: number, joyride: number, keysSeconds: number } }

-- Section 4: the five editions. `Edition` in the agreed Cars field is read as 1..5 in this order, and `Copies` as the copies
-- held at the current edition (0..24); both readings are questions for Brian L (economy-v1-answers-from-adam.md).
export type Edition =
	{ index: number, key: string, label: string, multiplier: number, colour: Color3, preview: boolean }
EconomyPreview.Editions = table.freeze({
	{
		index = 1,
		key = "Normal",
		label = "NORMAL",
		multiplier = 1,
		colour = Color3.fromRGB(214, 222, 236),
		preview = false,
	},
	{ index = 2, key = "Gold", label = "GOLD", multiplier = 3, colour = Color3.fromRGB(246, 190, 40), preview = false },
	{
		index = 3,
		key = "Diamond",
		label = "DIAMOND",
		multiplier = 10,
		colour = Color3.fromRGB(110, 210, 255),
		preview = false,
	},
	{
		index = 4,
		key = "Rainbow",
		label = "RAINBOW",
		multiplier = 50,
		colour = Color3.fromRGB(255, 120, 200),
		preview = false,
	},
	-- Galaxy's look is Brian L's to approve: a placeholder, deep purple with small stars, labelled PREVIEW
	{
		index = 5,
		key = "Galaxy",
		label = "GALAXY",
		multiplier = 250,
		colour = Color3.fromRGB(84, 40, 150),
		preview = true,
	},
}) :: { Edition }
EconomyPreview.CopiesToMerge = 25
EconomyPreview.EarnLine = "Fill the Keys on this car again to get a copy."

-- Section 5: Raceway levels. Price is what reaching the level costs (level 1 is the start).
EconomyPreview.RacewayMultiplier = table.freeze({ 1, 1.9, 3.5, 6.5, 12, 23, 43, 80, 150, 285, 535, 1000 }) :: { number }
EconomyPreview.RacewayPrice = table.freeze({
	[2] = 1e3,
	[3] = 5e3,
	[4] = 25e3,
	[5] = 150e3,
	[6] = 1e6,
	[7] = 7e6,
	[8] = 50e6,
	[9] = 400e6,
	[10] = 3e9,
	[11] = 25e9,
	[12] = 2e12,
}) :: { [number]: number }

-- Section 6: parking spots, start 2, max 15; spot k is the price of buying the k-th spot.
EconomyPreview.SpotPrice = table.freeze({
	[3] = 500,
	[4] = 1500,
	[5] = 4500,
	[6] = 13500,
	[7] = 40e3,
	[8] = 120e3,
	[9] = 365e3,
	[10] = 1.1e6,
	[11] = 3.3e6,
	[12] = 10e6,
	[13] = 30e6,
	[14] = 90e6,
	[15] = 265e6,
}) :: { [number]: number }
EconomyPreview.StartSpots = 2
EconomyPreview.MaxSpots = 15
-- C-03: Lane 3's recommendation, an open question for Brian L: the Expanded Paddock pass raises the maximum by 3, to 18.
EconomyPreview.ExpandedPaddockSpots = 3

-- Section 7: World unlocks (World 1 is free).
EconomyPreview.WorldUnlock = table.freeze({
	DustyHighway = { cash = 5e6, cars = 5, from = "Downtown" },
	SummitPass = { cash = 1e9, cars = 5, from = "DustyHighway" },
}) :: { [string]: { cash: number, cars: number, from: string } }

-- Section 8: run Cash per World.
EconomyPreview.RoadCoin = table.freeze({ Downtown = 5, DustyHighway = 500, SummitPass = 50e3 }) :: { [string]: number }
EconomyPreview.RoadCoinCap = 100
EconomyPreview.Milestone =
	table.freeze({ Downtown = 100, DustyHighway = 10e3, SummitPass = 1e6 }) :: { [string]: number }
EconomyPreview.MilestoneMetres = 500

-- Section 9: Welcome back.
EconomyPreview.OfflineRate = 0.5
EconomyPreview.OfflineCapHours = 8
EconomyPreview.LapSeconds = 15

function EconomyPreview.edition(n: number?): Edition
	return EconomyPreview.Editions[math.clamp(math.floor(n or 1), 1, #EconomyPreview.Editions)]
end

function EconomyPreview.lapPay(rarity: string, edition: number?, racewayLevel: number?): number
	local r = EconomyPreview.Rarity[rarity] or EconomyPreview.Rarity.Common
	local level = math.clamp(math.floor(racewayLevel or 1), 1, #EconomyPreview.RacewayMultiplier)
	return r.lapPay * EconomyPreview.edition(edition).multiplier * EconomyPreview.RacewayMultiplier[level]
end

function EconomyPreview.racewayPrice(level: number): number?
	return EconomyPreview.RacewayPrice[level]
end

function EconomyPreview.spotPrice(spot: number): number?
	return EconomyPreview.SpotPrice[spot]
end

export type Progress = {
	edition: Edition, -- the best edition reached
	nextEdition: Edition?, -- nil at Galaxy (the top: no further tier, no bar)
	copies: number, -- copies at the current edition, clamped 0..24
	need: number, -- 25
	fraction: number, -- 0..1 for the bar
	text: string, -- "12 / 25 copies to GOLD", or "Top edition reached!" at Galaxy
}

function EconomyPreview.editionProgress(edition: number?, copies: number?): Progress
	local e = EconomyPreview.edition(edition)
	local nextEdition = EconomyPreview.Editions[e.index + 1]
	local need = EconomyPreview.CopiesToMerge
	local have = math.clamp(math.floor(copies or 0), 0, need - 1)
	if not nextEdition then
		return { edition = e, nextEdition = nil, copies = 0, need = need, fraction = 1, text = "Top edition reached!" }
	end
	return {
		edition = e,
		nextEdition = nextEdition,
		copies = have,
		need = need,
		fraction = have / need,
		text = string.format("%d / %d copies to %s", have, need, nextEdition.label),
	}
end

function EconomyPreview.selfTest(): { string }
	local failures: { string } = {}
	local function expect(name: string, got: any, want: any)
		if got ~= want then
			table.insert(failures, string.format("%s: got %s, want %s", name, tostring(got), tostring(want)))
		end
	end
	expect("Executive Gold lap", EconomyPreview.lapPay("Epic", 2, 1), 6000)
	expect("Common Normal lap", EconomyPreview.lapPay("Common"), 10)
	expect("Legendary Galaxy L12", EconomyPreview.lapPay("Legendary", 5, 12), 25000 * 250 * 1000)
	expect("Normal 0", EconomyPreview.editionProgress(1, 0).text, "0 / 25 copies to GOLD")
	expect("one short", EconomyPreview.editionProgress(1, 24).text, "24 / 25 copies to GOLD")
	expect("merged", EconomyPreview.editionProgress(2, 0).text, "0 / 25 copies to DIAMOND")
	expect("Gold to Diamond", EconomyPreview.editionProgress(2, 12).text, "12 / 25 copies to DIAMOND")
	expect("Galaxy top", EconomyPreview.editionProgress(5, 30).nextEdition, nil)
	expect("over 24 clamps", EconomyPreview.editionProgress(1, 99).copies, 24)
	expect("spot 15", EconomyPreview.spotPrice(15), 265e6)
	expect("level 12", EconomyPreview.racewayPrice(12), 2e12)
	expect("level 1 has no price", EconomyPreview.racewayPrice(1), nil)
	return failures
end

return table.freeze(EconomyPreview)
