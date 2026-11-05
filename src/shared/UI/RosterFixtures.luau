--!strict
-- RosterFixtures: THE ONE car list every Lane 3 screen reads (Round 4, E-03 and E-04). A STAND-IN FOR BRIAN L'S CATALOG
-- (src/shared/Catalog, Lane 2): when his Catalog exists, it replaces this module and his placements win.
--
-- The 27 built showroom cars in ReplicatedStorage.Cars (assets/cars), nine per World, with the same rarity shape in each:
-- 2 Common, 2 Uncommon, 3 Rare or Epic, 2 Legendary. The first car of each World is its Loaner (the car a player starts that
-- World with). The split is Adam's decision of 2026-11-02, worked out in vault/decisions/0036-lane3-round4.md. Sparkster and
-- Polytruck are not built, so they have no entry yet (planned: Downtown and Dusty Highway).
--
-- `id` is the model's name in ReplicatedStorage.Cars, exactly as Brian L exported it (the showroom has no other id yet), so no
-- id is made up from a display name. `model` is the Normal model; the Gold, Diamond and Rainbow models are "<Edition> <model>".
--
--   RosterFixtures.Cars                       { Car }, World by World, Loaner first
--   RosterFixtures.byId(id) -> Car?           RosterFixtures.inWorld(world) -> { Car }   RosterFixtures.loaner(world) -> Car
--   RosterFixtures.Worlds                     { "Downtown", "DustyHighway", "SummitPass" }
--   RosterFixtures.selfTest() -> { string }   the failures (27 unique ids, 9 per World, one Loaner each, the E-03 names)

local RosterFixtures = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type World = "Downtown" | "DustyHighway" | "SummitPass"
export type Car = {
	id: string,
	name: string,
	rarity: Rarity,
	world: World,
	loaner: boolean,
	model: string,
}

RosterFixtures.Worlds = table.freeze({ "Downtown", "DustyHighway", "SummitPass" }) :: { World }
RosterFixtures.WorldNames = table.freeze({
	Downtown = "Downtown",
	DustyHighway = "Dusty Highway",
	SummitPass = "Summit Pass",
}) :: { [string]: string }
RosterFixtures.Rarities = table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) :: { Rarity }

local cars: { Car } = {}
local function add(world: World, rarity: Rarity, names: { string })
	for _, name in names do
		local loaner = true
		for _, c in cars do
			if c.world == world then
				loaner = false
			end
		end
		table.insert(
			cars,
			table.freeze({ id = name, name = name, rarity = rarity, world = world, loaner = loaner, model = name })
		)
	end
end

-- Downtown (city): city cars, delivery and luxury. Putter is the Downtown Loaner (Adam's tiny Italian city car starter).
add("Downtown", "Common", { "Putter", "Pizza Runner" })
add("Downtown", "Uncommon", { "Minnow", "Surf Wagon" })
add("Downtown", "Rare", { "Bolt", "Brawler" })
add("Downtown", "Epic", { "Executive" })
add("Downtown", "Legendary", { "Street Kid", "Cruiser" })
-- Dusty Highway (desert): junkers, the dune buggy, muscle, the desert truck and the speed-record hypercar
add("DustyHighway", "Common", { "Rustbucket", "Old Faithful" })
add("DustyHighway", "Uncommon", { "Beach Bug", "Workhorse" })
add("DustyHighway", "Rare", { "Thunder" })
add("DustyHighway", "Epic", { "Desert King", "Night Rider" })
add("DustyHighway", "Legendary", { "Viper Strike", "Apex" })
-- Summit Pass (mountains): family, ski, rally and 4x4 cars
add("SummitPass", "Common", { "Commuter", "Family Hauler" })
add("SummitPass", "Uncommon", { "Trailblazer", "Sunny Camper" })
add("SummitPass", "Rare", { "Rally Dog" })
add("SummitPass", "Epic", { "Monarch", "Velvet" })
add("SummitPass", "Legendary", { "Zip", "Phantom" })

RosterFixtures.Cars = table.freeze(cars)

local byId: { [string]: Car } = {}
for _, c in cars do
	byId[c.id] = c
end

function RosterFixtures.byId(id: string): Car?
	return byId[id]
end

function RosterFixtures.inWorld(world: string): { Car }
	local list = {}
	for _, c in cars do
		if c.world == world then
			table.insert(list, c)
		end
	end
	return list
end

function RosterFixtures.loaner(world: string): Car?
	for _, c in cars do
		if c.world == world and c.loaner then
			return c
		end
	end
	return nil
end

-- The model name for a car at an edition (1 Normal .. 5 Galaxy). Galaxy has no model of its own (its look is applied in
-- code later, Brian L approves it), so it shows the Rainbow model until then.
local EDITION_PREFIX = { "", "Gold ", "Diamond ", "Rainbow ", "Rainbow " }
function RosterFixtures.modelFor(car: Car, edition: number?): string
	local prefix = EDITION_PREFIX[math.clamp(math.floor(edition or 1), 1, 5)]
	return prefix .. car.model
end

local EXPECTED: { [string]: { string } } = {
	Downtown = {
		"Putter:Common",
		"Pizza Runner:Common",
		"Minnow:Uncommon",
		"Surf Wagon:Uncommon",
		"Bolt:Rare",
		"Brawler:Rare",
		"Executive:Epic",
		"Street Kid:Legendary",
		"Cruiser:Legendary",
	},
	DustyHighway = {
		"Rustbucket:Common",
		"Old Faithful:Common",
		"Beach Bug:Uncommon",
		"Workhorse:Uncommon",
		"Thunder:Rare",
		"Desert King:Epic",
		"Night Rider:Epic",
		"Viper Strike:Legendary",
		"Apex:Legendary",
	},
	SummitPass = {
		"Commuter:Common",
		"Family Hauler:Common",
		"Trailblazer:Uncommon",
		"Sunny Camper:Uncommon",
		"Rally Dog:Rare",
		"Monarch:Epic",
		"Velvet:Epic",
		"Zip:Legendary",
		"Phantom:Legendary",
	},
}
local LOANERS = { Downtown = "Putter", DustyHighway = "Rustbucket", SummitPass = "Commuter" }

-- The E-03a checks. `models` (optional) is ReplicatedStorage.Cars: then every car's Normal model must be there too.
function RosterFixtures.selfTest(models: Instance?): { string }
	local failures: { string } = {}
	local function expect(ok: boolean, text: string)
		if not ok then
			table.insert(failures, text)
		end
	end
	local seen: { [string]: boolean } = {}
	for _, c in cars do
		expect(not seen[c.id], "duplicate id " .. c.id)
		seen[c.id] = true
		if models then
			local m = models:FindFirstChild(c.model)
			expect(m ~= nil and m:IsA("Model"), "no model " .. c.model .. " in " .. models:GetFullName())
		end
	end
	expect(#cars == 27, "27 cars, got " .. #cars)
	for _, world in RosterFixtures.Worlds do
		local list = RosterFixtures.inWorld(world)
		expect(#list == 9, world .. ": 9 cars, got " .. #list)
		local loaners = 0
		for i, c in list do
			if c.loaner then
				loaners += 1
			end
			expect(
				EXPECTED[world][i] == c.name .. ":" .. c.rarity,
				world .. " #" .. i .. " is " .. c.name .. ":" .. c.rarity
			)
		end
		expect(loaners == 1, world .. ": one Loaner, got " .. loaners)
		local loaner = RosterFixtures.loaner(world)
		expect(loaner ~= nil and loaner.name == LOANERS[world], world .. ": Loaner should be " .. LOANERS[world])
	end
	return failures
end

return table.freeze(RosterFixtures)
