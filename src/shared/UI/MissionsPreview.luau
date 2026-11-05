--!strict
-- MissionsPreview: the first set of Missions and Goals (Round 6, G-02). Lane 3 design, PREVIEW rewards. Fifteen missions in
-- three tiers that teach the loop in order: catch, park, earn, buy, grow the Raceway, fill a World, unlock the next one,
-- reach GOLD. Every line is one short sentence a five-year-old can follow. No daily anything, no timers, no streaks, nothing
-- lost for stopping (Adam, 2026-11-05, brief section 0 item 9).
--
-- Progress comes only from what the server really knows (MissionsPreview.progress(mission, facts)):
--   SAVED (survives a rejoin): cars owned, cars parked, Raceway level, parking spots, Worlds unlocked, cars per World, the
--     best edition. These come from the agreed save fields.
--   COUNTED THIS VISIT (starts again at 0 on a rejoin, because no save field holds it yet): Lap Pay earned, Joyrides,
--     runs, the longest run. A `Missions` save field that would keep them, and which missions were claimed, is proposed to
--     Brian L in vault/design/specs/robux-fields-for-brian-l.md.
-- Rewards are PREVIEW Cash, each about a tenth to a half of the purchase that mission leads to (EconomyPreview prices), so a
-- reward helps with the very next step and never skips a stage.
--
--   MissionsPreview.List                   { Mission } in order (tier 1 first)
--   MissionsPreview.Goals                  the six milestone ids shown on the GOALS tab
--   MissionsPreview.get(id) -> Mission?
--   MissionsPreview.progress(mission, facts) -> number    0..target
--   MissionsPreview.saved(mission) -> boolean             true when its progress survives a rejoin
--   MissionsPreview.selfTest() -> { string }              failures only

local EconomyPreview = require(script.Parent.EconomyPreview)

local MissionsPreview = {}

export type Facts = {
	cars: number, -- models owned (the Loaner counts)
	parked: number, -- cars in the Lineup
	racewayLevel: number,
	spots: number, -- bought parking spots (2..15)
	worlds: { [string]: boolean },
	carsIn: { [string]: number }, -- models owned per World
	bestEdition: number, -- 1 Normal .. 5 Galaxy
	lapCash: number, -- counted this visit
	joyrides: number, -- counted this visit
	runs: number, -- counted this visit
	bestMetres: number, -- counted this visit: the longest single run
}

export type Mission = {
	id: string,
	tier: number, -- 1, 2 or 3
	text: string, -- the one line the player reads
	icon: string, -- a GameIcons name the panel already has
	target: number,
	format: "count" | "cash",
	reward: number, -- PREVIEW Cash
	stat: string, -- which fact it reads
	world: string?, -- for carsIn / worlds
}

local function m(
	id: string,
	tier: number,
	text: string,
	icon: string,
	stat: string,
	target: number,
	reward: number,
	extra: { world: string?, format: ("count" | "cash")? }?
): Mission
	local e = extra or {}
	return table.freeze({
		id = id,
		tier = tier,
		text = text,
		icon = icon,
		stat = stat,
		target = target,
		reward = math.floor(reward),
		format = e.format or "count",
		world = e.world,
	})
end

local P = EconomyPreview
local dustyCash = P.WorldUnlock.DustyHighway.cash
local summitCash = P.WorldUnlock.SummitPass.cash

MissionsPreview.List = table.freeze({
	-- Tier 1: Downtown, the first few minutes
	m("first-catch", 1, "Catch your first car!", "Keys", "cars", 2, P.spotPrice(3) :: number * 0.2),
	m("park-it", 1, "Park a car on your Raceway.", "Track", "parked", 2, P.spotPrice(3) :: number * 0.3),
	m(
		"earn-500",
		1,
		"Earn $500 from Lap Pay.",
		"Coin",
		"lapCash",
		500,
		P.spotPrice(4) :: number * 0.2,
		{ format = "cash" }
	),
	m("buy-spot", 1, "Buy a new parking spot.", "Track", "spots", 3, P.spotPrice(4) :: number * 0.3),
	m("joyride", 1, "Catch a car you already have.", "HopCar", "joyrides", 1, P.racewayPrice(2) :: number * 0.3),
	-- Tier 2: grow Downtown, open the second World
	m("level-3", 2, "Make your Raceway level 3.", "Medal", "racewayLevel", 3, P.racewayPrice(4) :: number * 0.1),
	m("run-1000", 2, "Go 1,000 m in one run.", "Flag", "bestMetres", 1000, P.racewayPrice(4) :: number * 0.1),
	m("downtown-5", 2, "Own 5 Downtown cars.", "GarageBook", "carsIn", 5, dustyCash * 0.01, { world = "Downtown" }),
	m("spots-6", 2, "Have 6 parking spots.", "Track", "spots", 6, P.spotPrice(7) :: number * 0.2),
	m("dusty", 2, "Unlock Dusty Highway!", "Portal", "worlds", 1, dustyCash * 0.02, { world = "DustyHighway" }),
	-- Tier 3: Dusty Highway, editions, the third World
	m(
		"dusty-catch",
		3,
		"Catch a car on Dusty Highway.",
		"Keys",
		"carsIn",
		2,
		dustyCash * 0.05,
		{ world = "DustyHighway" }
	),
	m("gold", 3, "Make a car GOLD.", "Star", "bestEdition", 2, P.racewayPrice(7) :: number * 0.1),
	m("level-6", 3, "Make your Raceway level 6.", "Medal", "racewayLevel", 6, P.racewayPrice(7) :: number * 0.1),
	m(
		"dusty-5",
		3,
		"Own 5 Dusty Highway cars.",
		"GarageBook",
		"carsIn",
		5,
		summitCash * 0.01,
		{ world = "DustyHighway" }
	),
	m("summit", 3, "Unlock Summit Pass!", "Portal", "worlds", 1, summitCash * 0.02, { world = "SummitPass" }),
}) :: { Mission }

-- The GOALS tab: six milestones, one-time, in order.
MissionsPreview.Goals =
	table.freeze({ "first-catch", "level-3", "downtown-5", "dusty", "gold", "summit" }) :: { string }

local SAVED =
	{ cars = true, parked = true, racewayLevel = true, spots = true, worlds = true, carsIn = true, bestEdition = true }

local byId: { [string]: Mission } = {}
for _, mission in MissionsPreview.List do
	byId[mission.id] = mission
end

function MissionsPreview.get(id: string): Mission?
	return byId[id]
end

function MissionsPreview.saved(mission: Mission): boolean
	return SAVED[mission.stat] == true
end

function MissionsPreview.progress(mission: Mission, facts: Facts): number
	local value: number
	if mission.stat == "worlds" then
		value = if mission.world and facts.worlds[mission.world] then 1 else 0
	elseif mission.stat == "carsIn" then
		value = if mission.world then facts.carsIn[mission.world] or 0 else 0
	else
		value = (facts :: any)[mission.stat] or 0
	end
	if type(value) ~= "number" or value ~= value then
		value = 0
	end
	return math.clamp(math.floor(value), 0, mission.target)
end

function MissionsPreview.selfTest(): { string }
	local failures: { string } = {}
	local function expect(name: string, got: any, want: any)
		if got ~= want then
			table.insert(failures, string.format("%s: got %s, want %s", name, tostring(got), tostring(want)))
		end
	end
	expect("fifteen missions", #MissionsPreview.List, 15)
	local facts: Facts = {
		cars = 3,
		parked = 2,
		racewayLevel = 2,
		spots = 3,
		worlds = { Downtown = true },
		carsIn = { Downtown = 3 },
		bestEdition = 1,
		lapCash = 9999,
		joyrides = 0,
		runs = 1,
		bestMetres = 400,
	}
	expect("first catch done", MissionsPreview.progress(byId["first-catch"], facts), 2)
	expect("lap cash clamps at the target", MissionsPreview.progress(byId["earn-500"], facts), 500)
	expect("Dusty not unlocked", MissionsPreview.progress(byId.dusty, facts), 0)
	expect("Downtown cars 3 of 5", MissionsPreview.progress(byId["downtown-5"], facts), 3)
	expect("a counted mission is not saved", MissionsPreview.saved(byId.joyride), false)
	expect("a level mission is saved", MissionsPreview.saved(byId["level-3"]), true)
	for i, mission in MissionsPreview.List do
		expect("reward is positive " .. mission.id, mission.reward > 0, true)
		local nextOne = MissionsPreview.List[i + 1]
		if nextOne then
			expect("tiers never go back " .. mission.id, mission.tier <= nextOne.tier, true)
		end
	end
	return failures
end

return table.freeze(MissionsPreview)
