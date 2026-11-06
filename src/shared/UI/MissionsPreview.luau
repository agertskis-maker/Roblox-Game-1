--!strict
-- MissionsPreview: the Missions and Goals (Round 6, G-02; Round 7, U-05). Lane 3 design, PREVIEW rewards. Forty-five missions
-- in five tabs: STARTER (the loop in order), RACER (runs, hops, distance), COLLECTOR (cars, rarities, editions), TYCOON (Raceway
-- levels, spots, Lap Pay, Worlds) and STYLE (the Style Shop). Every line is one short sentence a five-year-old can follow. No
-- timers, no daily resets, no streaks, nothing lost for stopping (Adam, 2026-11-05; brief section 0 item 9 and U-05).
--
-- Progress comes only from what the server really knows (MissionsPreview.progress(mission, facts)):
--   SAVED (survives a rejoin): cars owned, cars parked, Raceway level, parking spots, Worlds unlocked, cars per World, the
--     best edition, cars of each rarity, Worlds with a car caught, a Lineup of Rare or better, the Stamina level, what was
--     bought in the Style Shop and whether a full look is worn.
--   COUNTED THIS VISIT (starts again at 0 on a rejoin, because no save field holds it yet): Lap Pay earned, Joyrides, runs,
--     the longest run, hops, the longest hop chain without touching the road, the longest bump-free run. A `Missions` save
--     field that would keep them is proposed to Brian L (vault/design/specs/lane3-round7-for-brian-l.md).
-- Rewards are PREVIEW Cash scaled to the stage the mission belongs to, so a reward helps with the very next step and never
-- skips a stage.
--
--   MissionsPreview.Tabs                   the five tab names, in order
--   MissionsPreview.List                   { Mission } in order (by tab, then tier)
--   MissionsPreview.Goals                  the six milestone ids shown on the GOALS tab
--   MissionsPreview.get(id) -> Mission?
--   MissionsPreview.progress(mission, facts) -> number    0..target
--   MissionsPreview.saved(mission) -> boolean             true when its progress survives a rejoin
--   MissionsPreview.selfTest() -> { string }              failures only

local EconomyPreview = require(script.Parent.EconomyPreview)

local MissionsPreview = {}

MissionsPreview.Tabs = table.freeze({ "Starter", "Racer", "Collector", "Tycoon", "Style" }) :: { string }

export type Facts = {
	cars: number, -- models owned (the Loaner counts)
	parked: number, -- cars in the Lineup
	racewayLevel: number,
	spots: number, -- bought parking spots (2..15)
	worlds: { [string]: boolean },
	carsIn: { [string]: number }, -- models owned per World
	bestEdition: number, -- 1 Normal .. 5 Galaxy
	rare: number?, -- models owned that are Rare or better
	epic: number?, -- Epic or better
	legendary: number?,
	worldsWithCars: number?, -- Worlds with at least one car caught there
	lineupRare: number?, -- 1 when the Lineup has 3 or more cars and every one is Rare or better
	staminaLevel: number?,
	styleBought: number?, -- Style Shop items bought (any tab)
	paints: number?,
	decals: number?,
	wheels: number?,
	trails: number?,
	legendaryPaint: number?, -- 1 when a Legendary-tier paint is owned
	fullLook: number?, -- 1 when a paint, a decal, wheels and a trail are all worn (none of them the default)
	lapCash: number, -- counted this visit
	joyrides: number, -- counted this visit
	runs: number, -- counted this visit
	bestMetres: number, -- counted this visit: the longest single run
	hops: number?, -- counted this visit: leaps that landed on a car
	bestChain: number?, -- counted this visit: the most hops in a row without touching the road
	bumpFreeMetres: number?, -- counted this visit: the longest run with no bumps
}

export type Mission = {
	id: string,
	tab: string, -- one of MissionsPreview.Tabs
	tier: number, -- 1, 2 or 3 inside its tab
	text: string, -- the one line the player reads
	icon: string, -- a GameIcons name the panel already has
	target: number,
	format: "count" | "cash",
	reward: number, -- PREVIEW Cash
	stat: string, -- which fact it reads
	world: string?, -- for carsIn / worlds
}

local currentTab = "Starter"
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
		tab = currentTab,
		tier = tier,
		text = text,
		icon = icon,
		stat = stat,
		target = target,
		reward = math.max(math.floor(reward), 1),
		format = e.format or "count",
		world = e.world,
	})
end

local P = EconomyPreview
local function raceway(level: number, share: number): number
	return (P.racewayPrice(level) or 0) * share
end
local function spot(n: number, share: number): number
	return (P.spotPrice(n) or 0) * share
end
local dustyCash = P.WorldUnlock.DustyHighway.cash
local summitCash = P.WorldUnlock.SummitPass.cash

local list: { Mission } = {}
local function add(mission: Mission)
	table.insert(list, mission)
end

-- STARTER (9): the first few minutes, in the order the loop is learned
currentTab = "Starter"
add(m("first-catch", 1, "Catch your first car!", "Keys", "cars", 2, spot(3, 0.2)))
add(m("first-hop", 1, "Hop onto a car.", "HopCar", "hops", 1, 100))
add(m("first-run", 1, "Finish a run.", "Flag", "runs", 1, 100))
add(m("park-it", 1, "Park a car on your Raceway.", "Track", "parked", 2, spot(3, 0.3)))
add(m("earn-500", 1, "Earn $500 from Lap Pay.", "Coin", "lapCash", 500, spot(4, 0.2), { format = "cash" }))
add(m("buy-spot", 2, "Buy a new parking spot.", "Track", "spots", 3, spot(4, 0.3)))
add(m("joyride", 2, "Catch a car you already have.", "HopCar", "joyrides", 1, raceway(2, 0.3)))
add(m("pit-stop", 2, "Buy a Stamina upgrade at the Pit Stop.", "Medal", "staminaLevel", 1, 500))
add(m("first-style", 2, "Buy something in the Style Shop.", "Star", "styleBought", 1, 400))

-- RACER (9): runs, hops and distance (counted this visit)
currentTab = "Racer"
add(m("run-500", 1, "Go 500 m in one run.", "Flag", "bestMetres", 500, 300))
add(m("run-1000", 1, "Go 1,000 m in one run.", "Flag", "bestMetres", 1000, raceway(4, 0.1)))
add(m("chain-3", 1, "Hop 3 cars without touching the road.", "HopCar", "bestChain", 3, 2000))
add(m("hops-25", 2, "Hop 25 cars.", "HopCar", "hops", 25, 5000))
add(m("bumpfree-1000", 2, "Drive 1,000 m in a run with no bumps.", "Flag", "bumpFreeMetres", 1000, 10000))
add(m("runs-10", 2, "Play 10 runs.", "Flag", "runs", 10, 12000))
add(m("run-2000", 2, "Go 2,000 m in one run.", "Flag", "bestMetres", 2000, 25000))
add(m("chain-8", 3, "Hop 8 cars without touching the road.", "HopCar", "bestChain", 8, 80000))
add(m("run-5000", 3, "Go 5,000 m in one run.", "Flag", "bestMetres", 5000, 250000))

-- COLLECTOR (10): cars, rarities and editions
currentTab = "Collector"
add(m("cars-5", 1, "Own 5 cars.", "GarageBook", "cars", 5, 1000))
add(m("rare-1", 1, "Own a Rare car.", "Star", "rare", 1, 3000))
add(m("downtown-5", 1, "Own 5 Downtown cars.", "GarageBook", "carsIn", 5, dustyCash * 0.01, { world = "Downtown" }))
add(m("epic-1", 2, "Own an Epic car.", "Star", "epic", 1, 20000))
add(m("gold", 2, "Make a car GOLD.", "Star", "bestEdition", 2, raceway(7, 0.1)))
add(
	m(
		"dusty-catch",
		2,
		"Catch a car on Dusty Highway.",
		"Keys",
		"carsIn",
		2,
		dustyCash * 0.05,
		{ world = "DustyHighway" }
	)
)
add(m("legendary-1", 3, "Own a Legendary car.", "Star", "legendary", 1, 250000))
add(
	m(
		"dusty-5",
		3,
		"Own 5 Dusty Highway cars.",
		"GarageBook",
		"carsIn",
		5,
		summitCash * 0.01,
		{ world = "DustyHighway" }
	)
)
add(m("diamond", 3, "Make a car DIAMOND.", "Star", "bestEdition", 3, 2000000))
add(m("every-world", 3, "Catch a car in every World.", "Portal", "worldsWithCars", 3, 5000000))

-- TYCOON (10): the Raceway, spots, Lap Pay and Worlds
currentTab = "Tycoon"
add(m("level-3", 1, "Make your Raceway level 3.", "Medal", "racewayLevel", 3, raceway(4, 0.1)))
add(m("earn-10k", 1, "Earn $10K from Lap Pay.", "Coin", "lapCash", 10000, 3000, { format = "cash" }))
add(m("spots-6", 1, "Have 6 parking spots.", "Track", "spots", 6, spot(7, 0.2)))
add(m("stamina-5", 2, "Upgrade Stamina 5 times.", "Medal", "staminaLevel", 5, 50000))
add(m("lineup-rare", 2, "Fill your Raceway with Rare or better.", "Track", "lineupRare", 1, 80000))
add(m("dusty", 2, "Unlock Dusty Highway!", "Portal", "worlds", 1, dustyCash * 0.02, { world = "DustyHighway" }))
add(m("level-6", 2, "Make your Raceway level 6.", "Medal", "racewayLevel", 6, raceway(7, 0.1)))
add(m("spots-10", 3, "Have 10 parking spots.", "Track", "spots", 10, spot(11, 0.2)))
add(m("earn-1m", 3, "Earn $1M from Lap Pay.", "Coin", "lapCash", 1000000, 300000, { format = "cash" }))
add(m("summit", 3, "Unlock Summit Pass!", "Portal", "worlds", 1, summitCash * 0.02, { world = "SummitPass" }))

-- STYLE (7): the Style Shop
currentTab = "Style"
add(m("paint-1", 1, "Buy a paint.", "Star", "paints", 1, 500))
add(m("decal-1", 1, "Buy a decal.", "Star", "decals", 1, 500))
add(m("wheels-1", 1, "Buy new wheels.", "Star", "wheels", 1, 1000))
add(m("trail-1", 2, "Buy a trail.", "Star", "trails", 1, 3000))
add(m("full-look", 2, "Wear a full look: paint, decal, wheels and trail.", "Medal", "fullLook", 1, 10000))
add(m("paints-5", 2, "Own 5 paints.", "Star", "paints", 5, 50000))
add(m("legendary-paint", 3, "Own a Legendary paint.", "Star", "legendaryPaint", 1, 5000000))

MissionsPreview.List = table.freeze(list) :: { Mission }

-- The GOALS tab: six milestones, one-time, in order.
MissionsPreview.Goals =
	table.freeze({ "first-catch", "level-3", "downtown-5", "dusty", "gold", "summit" }) :: { string }

local SAVED = {
	cars = true,
	parked = true,
	racewayLevel = true,
	spots = true,
	worlds = true,
	carsIn = true,
	bestEdition = true,
	rare = true,
	epic = true,
	legendary = true,
	worldsWithCars = true,
	lineupRare = true,
	staminaLevel = true,
	styleBought = true,
	paints = true,
	decals = true,
	wheels = true,
	trails = true,
	legendaryPaint = true,
	fullLook = true,
}

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
	local value: any
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
	expect("forty-five missions", #MissionsPreview.List, 45)
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
		bestChain = 3,
	}
	expect("first catch done", MissionsPreview.progress(byId["first-catch"], facts), 2)
	expect("lap cash clamps at the target", MissionsPreview.progress(byId["earn-500"], facts), 500)
	expect("Dusty not unlocked", MissionsPreview.progress(byId.dusty, facts), 0)
	expect("Downtown cars 3 of 5", MissionsPreview.progress(byId["downtown-5"], facts), 3)
	expect("a missing fact counts as 0", MissionsPreview.progress(byId["rare-1"], facts), 0)
	expect("a hop chain of 3 is done", MissionsPreview.progress(byId["chain-3"], facts), 3)
	expect("a counted mission is not saved", MissionsPreview.saved(byId.joyride), false)
	expect("a level mission is saved", MissionsPreview.saved(byId["level-3"]), true)
	local perTab: { [string]: number } = {}
	local lastTier: { [string]: number } = {}
	for _, mission in MissionsPreview.List do
		expect("reward is positive " .. mission.id, mission.reward > 1, true)
		expect("tab is known " .. mission.id, table.find(MissionsPreview.Tabs, mission.tab) ~= nil, true)
		perTab[mission.tab] = (perTab[mission.tab] or 0) + 1
		expect("tiers never go back " .. mission.id, mission.tier >= (lastTier[mission.tab] or 1), true)
		lastTier[mission.tab] = mission.tier
	end
	for _, name in MissionsPreview.Tabs do
		expect("tab " .. name .. " has 7 or more missions", (perTab[name] or 0) >= 7, true)
	end
	for _, id in MissionsPreview.Goals do
		expect("goal exists " .. id, byId[id] ~= nil, true)
	end
	return failures
end

return table.freeze(MissionsPreview)
