--!strict
-- EconomyPreview: every economy number a Lane 3 screen draws, in ONE place (Round 4, E-06, E-08, C-03). PREVIEW ONLY.
-- The values are Brian L's proposal, economy v1 (vault/design/specs/economy-v1.md on feature/lane2-economy-design), not
-- agreed numbers: screens tag them PREVIEW, and his server's values replace this module in one edit. Nothing here pays,
-- saves or checks anything; affordability on a screen always compares these numbers, never their text.
--
--   EconomyPreview.lapPay(rarity, edition?, racewayLevel?, world?) -> number   the Lap Pay of one car per lap
--   EconomyPreview.claimBonus(rarity, world?) -> number                 the Cash a first catch of a model pays
--   EconomyPreview.joyrideBonus(rarity, edition?, world?) -> number     the Cash a Joyride (an owned model again) pays
--   EconomyPreview.worldFactor(world?) -> number                        a World's pay factor (Round 6, E-01)
--   EconomyPreview.edition(n) -> Edition                                1 Normal .. 5 Galaxy
--   EconomyPreview.editionProgress(edition, copies) -> Progress         the "12 / 25 copies to GOLD" facts
--   EconomyPreview.racewayPrice(level) -> number?                       the price of reaching that level (nil for 1 and past 12)
--   EconomyPreview.spotPrice(spot) -> number?                           the price of parking spot 3..15
--   EconomyPreview.addCopy(edition, copies) -> (edition, copies, rose)  one Joyride copy on the edition ladder (lifetime)
--   EconomyPreview.lifetimeCopies(edition, copies) -> number            Round 5's per-edition Copies as a lifetime total
--   EconomyPreview.offlineCredit(payPerLap, seconds) -> number          the Welcome back credit (Round 5, L-06)
--   EconomyPreview.selfTest() -> { string }

local EconomyPreview = {}

-- Section 3: per rarity, Normal edition, Raceway level 1, inside ONE World (World factor 1).
-- Round 6 (E-01, Adam's decision of 2026-11-05, brief section 0 item 4): Claude's candidate numbers replace economy v1's here,
-- PREVIEW, until Brian L answers (economy-preview-review-for-brian-l.md). Lap Pay $10 / $25 / $60 / $150 / $400 by rarity;
-- the claim bonus is 10x and the Joyride Bonus 3x the Lap Pay; each World multiplies all three by its WorldPayFactor.
EconomyPreview.Rarity = table.freeze({
	Common = { lapPay = 10, claimBonus = 100, joyride = 30, keysSeconds = 3 },
	Uncommon = { lapPay = 25, claimBonus = 250, joyride = 75, keysSeconds = 3.5 },
	Rare = { lapPay = 60, claimBonus = 600, joyride = 180, keysSeconds = 4 },
	Epic = { lapPay = 150, claimBonus = 1500, joyride = 450, keysSeconds = 5 },
	Legendary = { lapPay = 400, claimBonus = 4000, joyride = 1200, keysSeconds = 6 },
}) :: { [string]: { lapPay: number, claimBonus: number, joyride: number, keysSeconds: number } }

-- Round 6 (E-01): the World pay factor, on Lap Pay, the claim bonus and the Joyride Bonus. Milestones keep their own
-- per-World pay (section 8 below, it already scales) and every price is unchanged. An unknown World pays like Downtown.
EconomyPreview.WorldPayFactor =
	table.freeze({ Downtown = 1, DustyHighway = 40, SummitPass = 1600 }) :: { [string]: number }

-- Section 4: the five editions. `Edition` in the agreed Cars field is read as 1..5 in this order. Round 6 (E-02, Adam's
-- decision of 2026-11-05): `Copies` is the LIFETIME total of copies (Brian L's meaning); it never starts again at 0.
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
EconomyPreview.CopiesToMerge = 25 -- the first step (Normal to Gold); see EditionSteps
-- Brian L's ladder (feature/lane2-economy-preview, a433e5c) read as LIFETIME totals (Round 6, E-02): 25 copies make GOLD,
-- 250 DIAMOND, 2,500 RAINBOW and 25,000 GALAXY. PREVIEW.
EconomyPreview.EditionSteps = table.freeze({ 25, 250, 2500, 25000 }) :: { number }
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

-- Round 5 (L-01): a one-time PREVIEW bonus paid when the tutorial ends (finished or skipped), so "Add a spot" ($500) is
-- affordable at the end of it. Paid only on the save's TutorialDone false -> true change, so it never repeats.
EconomyPreview.TutorialBonus = 500

function EconomyPreview.edition(n: number?): Edition
	return EconomyPreview.Editions[math.clamp(math.floor(n or 1), 1, #EconomyPreview.Editions)]
end

function EconomyPreview.worldFactor(world: string?): number
	return if world then EconomyPreview.WorldPayFactor[world] or 1 else 1
end

function EconomyPreview.lapPay(rarity: string, edition: number?, racewayLevel: number?, world: string?): number
	local r = EconomyPreview.Rarity[rarity] or EconomyPreview.Rarity.Common
	local level = math.clamp(math.floor(racewayLevel or 1), 1, #EconomyPreview.RacewayMultiplier)
	return r.lapPay
		* EconomyPreview.edition(edition).multiplier
		* EconomyPreview.RacewayMultiplier[level]
		* EconomyPreview.worldFactor(world)
end

function EconomyPreview.claimBonus(rarity: string, world: string?): number
	local r = EconomyPreview.Rarity[rarity] or EconomyPreview.Rarity.Common
	return r.claimBonus * EconomyPreview.worldFactor(world)
end

function EconomyPreview.joyrideBonus(rarity: string, edition: number?, world: string?): number
	local r = EconomyPreview.Rarity[rarity] or EconomyPreview.Rarity.Common
	return r.joyride * EconomyPreview.edition(edition).multiplier * EconomyPreview.worldFactor(world)
end

function EconomyPreview.racewayPrice(level: number): number?
	return EconomyPreview.RacewayPrice[level]
end

function EconomyPreview.spotPrice(spot: number): number?
	return EconomyPreview.SpotPrice[spot]
end

-- The lifetime copies that reach the edition after `edition` (nil at the top).
function EconomyPreview.stepAt(edition: number?): number?
	return EconomyPreview.EditionSteps[EconomyPreview.edition(edition).index]
end

-- The lifetime copies at which `edition` itself is reached (0 for Normal).
function EconomyPreview.thresholdOf(edition: number?): number
	local e = EconomyPreview.edition(edition).index
	return if e <= 1 then 0 else EconomyPreview.EditionSteps[e - 1]
end

-- One more copy of an owned car: the lifetime Copies count goes up by one, and the edition rises when the count reaches
-- the next step. Copies never starts again at 0, and nothing is thrown away at the top edition.
function EconomyPreview.addCopy(edition: number?, copies: number?): (number, number, boolean)
	local e = EconomyPreview.edition(edition).index
	local c = math.max(0, math.floor(copies or 0)) + 1
	local rose = false
	local step = EconomyPreview.stepAt(e)
	while step and c >= step do
		e += 1
		rose = true
		step = EconomyPreview.stepAt(e)
	end
	return e, c, rose
end

-- Round 6 (E-02): a Round 5 save counted Copies at the current edition (starting again at 0 after each step). As a lifetime
-- total that is the edition's own threshold plus those copies, kept below the next step so a converted save never jumps an
-- edition on load (Gold with 12 becomes 37: "37 / 250 copies to DIAMOND").
function EconomyPreview.lifetimeCopies(edition: number?, copies: number?): number
	local e = EconomyPreview.edition(edition).index
	local total = EconomyPreview.thresholdOf(e) + math.max(0, math.floor(copies or 0))
	local step = EconomyPreview.stepAt(e)
	return if step then math.min(total, step - 1) else total
end

-- Welcome back (outline section 08): the Lineup's Lap Pay per lap x laps in the time away (capped) x the offline rate,
-- rounded down once at the end. Bad or negative times pay nothing.
function EconomyPreview.offlineCredit(payPerLap: number, seconds: number): number
	if payPerLap ~= payPerLap or seconds ~= seconds or payPerLap <= 0 or seconds <= 0 then
		return 0
	end
	local capped = math.min(seconds, EconomyPreview.OfflineCapHours * 3600)
	return math.floor(payPerLap * capped / EconomyPreview.LapSeconds * EconomyPreview.OfflineRate)
end

export type Progress = {
	edition: Edition, -- the best edition reached
	nextEdition: Edition?, -- nil at Galaxy (the top: no further tier, no bar)
	copies: number, -- lifetime copies, clamped to the current edition's range
	need: number, -- the lifetime total for the next edition: 25, 250, 2,500 or 25,000
	fraction: number, -- 0..1 for the bar
	text: string, -- "12 / 25 copies to GOLD", or "Top edition reached!" at Galaxy
}

function EconomyPreview.editionProgress(edition: number?, copies: number?): Progress
	local e = EconomyPreview.edition(edition)
	local nextEdition = EconomyPreview.Editions[e.index + 1]
	local need = EconomyPreview.stepAt(e.index) or EconomyPreview.CopiesToMerge
	local floor = EconomyPreview.thresholdOf(e.index)
	if not nextEdition then
		local total = math.max(0, math.floor(copies or 0))
		return {
			edition = e,
			nextEdition = nil,
			copies = total,
			need = need,
			fraction = 1,
			text = "Top edition reached!",
		}
	end
	local have = math.clamp(math.floor(copies or 0), floor, need - 1)
	return {
		edition = e,
		nextEdition = nextEdition,
		copies = have,
		need = need,
		fraction = (have - floor) / (need - floor),
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
	expect("Executive Gold lap", EconomyPreview.lapPay("Epic", 2, 1), 450)
	expect("Common Normal lap", EconomyPreview.lapPay("Common"), 10)
	expect("Legendary Galaxy L12", EconomyPreview.lapPay("Legendary", 5, 12), 400 * 250 * 1000)
	-- E-01's three hand-checked values
	expect("E-01 Downtown Common L1", EconomyPreview.lapPay("Common", 1, 1, "Downtown"), 10)
	expect("E-01 Dusty Highway Rare L3", EconomyPreview.lapPay("Rare", 1, 3, "DustyHighway"), 8400)
	expect("E-01 Summit Pass Legendary Joyride", EconomyPreview.joyrideBonus("Legendary", 1, "SummitPass"), 1920000)
	expect("claim bonus is 10x Lap Pay", EconomyPreview.claimBonus("Uncommon", "DustyHighway"), 10000)
	expect("an unknown World pays like Downtown", EconomyPreview.worldFactor("Mars"), 1)
	-- E-02: lifetime Copies
	expect("Normal 0", EconomyPreview.editionProgress(1, 0).text, "0 / 25 copies to GOLD")
	expect("Normal 12", EconomyPreview.editionProgress(1, 12).text, "12 / 25 copies to GOLD")
	expect("one short", EconomyPreview.editionProgress(1, 24).text, "24 / 25 copies to GOLD")
	expect("Gold at 25", EconomyPreview.editionProgress(2, 25).text, "25 / 250 copies to DIAMOND")
	expect("Gold to Diamond", EconomyPreview.editionProgress(2, 37).text, "37 / 250 copies to DIAMOND")
	expect("Rainbow step", EconomyPreview.editionProgress(4, 2500).text, "2500 / 25000 copies to GALAXY")
	local e, c, rose = EconomyPreview.addCopy(1, 24)
	expect("25th copy makes Gold and keeps counting", e * 100 + c + (if rose then 1000 else 0), 1225)
	e, c = EconomyPreview.addCopy(2, 248)
	expect("249th copy stays Gold", e * 1000 + c, 2249)
	e, c, rose = EconomyPreview.addCopy(2, 249)
	expect("250th copy makes Diamond", e * 1000 + c + (if rose then 1e5 else 0), 103250)
	expect("convert Gold 12", EconomyPreview.lifetimeCopies(2, 12), 37)
	expect("convert Normal 7", EconomyPreview.lifetimeCopies(1, 7), 7)
	expect("convert never jumps an edition", EconomyPreview.lifetimeCopies(2, 240), 249)
	expect("convert Galaxy", EconomyPreview.lifetimeCopies(5, 3), 25003)
	expect("offline 1 h, $10 a lap", EconomyPreview.offlineCredit(10, 3600), 1200)
	expect("offline cap 8 h", EconomyPreview.offlineCredit(10, 24 * 3600), 9600)
	expect("offline negative", EconomyPreview.offlineCredit(10, -5), 0)
	expect("offline NaN", EconomyPreview.offlineCredit(0 / 0, 100), 0)
	expect("Galaxy top", EconomyPreview.editionProgress(5, 30).nextEdition, nil)
	expect("over 24 clamps at Normal", EconomyPreview.editionProgress(1, 99).copies, 24)
	expect("spot 15", EconomyPreview.spotPrice(15), 265e6)
	expect("level 12", EconomyPreview.racewayPrice(12), 2e12)
	expect("level 1 has no price", EconomyPreview.racewayPrice(1), nil)
	return failures
end

return table.freeze(EconomyPreview)
