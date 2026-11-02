--!strict
-- PREVIEW fixtures for the portal card (big round M12). Every number, name and rule here is made up for review.
-- Nothing in this file is an unlock rule, a price or an ownership record, and nothing grants anything.
--
-- THE SEAM FOR BRIAN L (the M18 message asks him for these fields; until he supplies them the card shows a State):
--   worldId, worldName            which World the portal leads to
--   status                        "Checking" while any of the below is unknown, "Ready" once all of it is known
--   open                          the authoritative lock verdict (the card never works it out from the requirement rows)
--   requirements[]                { id, label, kind = "cash" | "count", have, need } -- `have` nil = unknown (never zero)
--   roster[]                      { id, name, rarity, family, owned, loaner? } for the World (Peek and Start In)
-- In the beta every portal stays open (decision 0030): see PortalFixtures.betaOpen.
--
-- The requirement ROWS ("Downtown cars", "$5,000") are a fixture of the reviewed outline and the old PortalCardMock
-- (cars from the previous World). They are NOT a rule: BRIEF M12-03a keeps them labelled and asks Brian L for the real ones.

local Fixtures = require(script.Parent.Parent.Fixtures)

local PortalFixtures = {}

PortalFixtures.Source =
	"PREVIEW fixture (not a rule): the real requirements, owned cars and lock verdict come from Brian L"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type Status = "Checking" | "Ready" | "Error"

export type RosterCar = {
	id: string,
	name: string,
	rarity: Rarity,
	family: string,
	paint: Color3?,
	owned: boolean,
	loaner: boolean?,
}

export type Requirement = {
	id: string,
	icon: string,
	label: string,
	kind: "cash" | "count",
	have: number?, -- nil = unknown ("Checking...", never 0)
	need: number,
}

export type State = {
	source: string,
	worldId: string,
	worldName: string,
	worldTag: string,
	status: Status,
	open: boolean,
	requirements: { Requirement },
	roster: { RosterCar },
}

-- What the card asks the lead's callback to start: one request per activation.
export type GoRequest = {
	worldId: string,
	carId: string,
	isLoaner: boolean,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function car(id: string, name: string, rarity: Rarity, family: string, paint: Color3, loaner: boolean?): RosterCar
	return { id = id, name = name, rarity = rarity, family = family, paint = paint, owned = false, loaner = loaner }
end

-- The proposed rosters (vault/design/cars/roster.md), eight per World. Proposed names, not final.
local ROSTERS: { [string]: { RosterCar } } = {
	Downtown = {
		car("puglet", "Puglet", "Common", "Compact", rgb(40, 120, 232), true),
		car("fishbowl", "Fishbowl Express", "Common", "Truck", rgb(0, 166, 180)),
		car("waffle", "Citrine Waffle Van", "Uncommon", "Van", rgb(194, 24, 91)),
		car("rangy", "Rangy", "Uncommon", "Pickup", rgb(232, 179, 58)),
		car("rev6", "Revolution 6", "Rare", "Sedan", rgb(30, 86, 200)),
		car("zoomurai", "Zoomurai", "Rare", "Motorcycle", rgb(244, 194, 13)),
		car("hurrikan", "Hurrikan", "Epic", "Sports", rgb(139, 203, 44)),
		car("hyperion", "Hyperion", "Legendary", "Special", rgb(238, 241, 245)),
	},
	DustyHighway = {
		car("razzer", "Razzer", "Common", "Compact", rgb(25, 181, 176), true),
		car("peterbolt", "Peterbolt", "Common", "Truck", rgb(45, 91, 211)),
		car("winnie", "Winnie Bravo", "Uncommon", "Van", rgb(224, 165, 38)),
		car("chopsticks", "Chopsticks", "Uncommon", "Motorcycle", rgb(40, 44, 58)),
		car("recharger", "Recharger", "Rare", "Sedan", rgb(110, 47, 158)),
		car("baja", "Baja Bruiser", "Rare", "Pickup", rgb(226, 80, 60)),
		car("fortyniner", "Forty-Niner", "Epic", "Sports", rgb(196, 200, 210)),
		car("thunderfoot", "Thunderfoot", "Legendary", "Special", rgb(240, 120, 30)),
	},
	SummitPass = {
		car("resnow4", "Re-Snow 4", "Common", "Compact", rgb(252, 200, 40), true),
		car("hiice", "Hi-Ice", "Common", "Van", rgb(18, 146, 140)),
		car("snowmog", "Snowmog", "Uncommon", "Truck", rgb(160, 210, 50)),
		car("snowva", "Snowva", "Uncommon", "Pickup", rgb(183, 58, 46)),
		car("subaroo", "Subaroo", "Rare", "Sedan", rgb(40, 84, 200)),
		car("huskvarna", "Huskvarna", "Rare", "Motorcycle", rgb(45, 127, 249)),
		car("lancestratus", "Lance Stratus", "Epic", "Sports", rgb(224, 40, 140)),
		car("yeti6x6", "Yeti 6x6", "Legendary", "Special", rgb(226, 232, 244)),
	},
}

PortalFixtures.Worlds = table.freeze({
	Downtown = { name = "DOWNTOWN", tag = "World 1" },
	DustyHighway = { name = "DUSTY HIGHWAY", tag = "World 2" },
	SummitPass = { name = "SUMMIT PASS", tag = "World 3" },
})

PortalFixtures.WorldOrder = table.freeze({ "Downtown", "DustyHighway", "SummitPass" })

-- The header band colours of each World (preview identity colours, light -> deep).
PortalFixtures.Colours = table.freeze({
	Downtown = { light = rgb(120, 200, 255), mid = rgb(50, 150, 235), deep = rgb(30, 96, 200) },
	DustyHighway = { light = rgb(255, 200, 110), mid = rgb(246, 150, 60), deep = rgb(214, 96, 28) },
	SummitPass = { light = rgb(190, 230, 255), mid = rgb(110, 176, 236), deep = rgb(70, 120, 200) },
})

-- The previous World's name for the "cars from the previous World" fixture row.
local PREVIOUS: { [string]: string } = { DustyHighway = "Downtown", SummitPass = "Dusty Highway" }

local function roster(worldId: string, ownedIds: { string }): { RosterCar }
	local out: { RosterCar } = {}
	for _, source in ROSTERS[worldId] or ROSTERS.Downtown do
		local c = table.clone(source)
		c.owned = table.find(ownedIds, source.id) ~= nil
		table.insert(out, c)
	end
	return out
end

local function requirements(worldId: string, cash: number?, cars: number?): { Requirement }
	local previous = PREVIOUS[worldId]
	if not previous then
		return {}
	end
	return {
		{
			id = "cash",
			icon = "Coin",
			label = "Cash",
			kind = "cash",
			have = cash,
			need = if worldId == "SummitPass" then 20000 else 5000,
		},
		{
			id = "cars",
			icon = "Car",
			label = previous .. " cars",
			kind = "count",
			have = cars,
			need = if worldId == "SummitPass" then 5 else 3,
		},
	}
end

local function build(
	worldId: string,
	status: Status,
	open: boolean,
	cash: number?,
	cars: number?,
	owned: { string }
): State
	local info = (PortalFixtures.Worlds :: any)[worldId]
	return {
		source = PortalFixtures.Source,
		worldId = worldId,
		worldName = info.name,
		worldTag = info.tag,
		status = status,
		open = open,
		requirements = requirements(worldId, cash, cars),
		roster = roster(worldId, owned),
	}
end

-- A roster id list of cars that count as owned, by World (a few cars, then all of them).
local FEW: { [string]: { string } } = {
	Downtown = { "puglet", "waffle" },
	DustyHighway = { "winnie", "baja" },
	SummitPass = { "hiice" },
}

local function allIds(worldId: string): { string }
	local ids = {}
	for _, c in ROSTERS[worldId] do
		table.insert(ids, c.id)
	end
	return ids
end

local presets: { [string]: () -> State } = {}

-- BETA (decision 0030): every portal is open whatever the rows say. The rows still show their fixture progress.
for _, worldId in PortalFixtures.WorldOrder do
	presets["Beta_" .. worldId] = function(): State
		return build(worldId, "Ready", true, 1200, 1, FEW[worldId])
	end
end
presets.Dusty_Locked_BothUnmet = function(): State
	return build("DustyHighway", "Ready", false, 1200, 1, FEW.DustyHighway)
end
presets.Dusty_Locked_OneMet = function(): State
	return build("DustyHighway", "Ready", false, 5200, 2, FEW.DustyHighway)
end
presets.Dusty_Unlocked_AllMet = function(): State
	return build("DustyHighway", "Ready", true, 5200, 3, FEW.DustyHighway)
end
presets.Summit_Locked_BothUnmet = function(): State
	return build("SummitPass", "Ready", false, 8400, 2, FEW.SummitPass)
end
-- data unavailable: never LOCKED, never zero
presets.Dusty_Checking = function(): State
	return build("DustyHighway", "Checking", false, nil, nil, {})
end
presets.Dusty_Error = function(): State
	return build("DustyHighway", "Error", false, nil, nil, {})
end
-- zero owned cars (only the Loaner is selectable), and the same with a roster the player has not touched
presets.Dusty_NoCars = function(): State
	return build("DustyHighway", "Ready", true, 5200, 3, {})
end
-- many owned cars: the Start In picker scrolls
presets.Dusty_ManyCars = function(): State
	local state = build("DustyHighway", "Ready", true, 5200, 3, allIds("DustyHighway"))
	for i = 1, 6 do
		local copy = table.clone(ROSTERS.DustyHighway[1 + (i % 7)])
		copy.id = copy.id .. "-extra" .. i
		copy.name = copy.name .. " Mk " .. i
		copy.owned = true
		copy.loaner = nil
		table.insert(state.roster, copy)
	end
	return state
end
-- text 30 percent longer than the longest names, and a big Cash value
presets.Dusty_LongStrings = function(): State
	local state = build("DustyHighway", "Ready", false, 4820000, 2, FEW.DustyHighway)
	state.worldName = "DUSTY HIGHWAY EXPRESS"
	state.requirements[1].need = 5000000
	state.requirements[1].label = "Cash saved up so far"
	state.requirements[2].label = "Downtown cars you have collected"
	state.roster[3].name = "Winnie Bravo Grand Touring Deluxe"
	return state
end
-- a car whose art is missing: an unknown family and no paint
presets.Dusty_MissingArt = function(): State
	local state = build("DustyHighway", "Ready", true, 5200, 3, FEW.DustyHighway)
	state.roster[3].family = "Mystery"
	state.roster[3].paint = nil
	state.roster[3].owned = true
	return state
end

PortalFixtures.PresetNames = table.freeze({
	"Beta_Downtown",
	"Beta_DustyHighway",
	"Beta_SummitPass",
	"Dusty_Locked_BothUnmet",
	"Dusty_Locked_OneMet",
	"Dusty_Unlocked_AllMet",
	"Summit_Locked_BothUnmet",
	"Dusty_Checking",
	"Dusty_Error",
	"Dusty_NoCars",
	"Dusty_ManyCars",
	"Dusty_LongStrings",
	"Dusty_MissingArt",
})

-- A fresh State for a preset name (nil for an unknown name).
function PortalFixtures.preset(name: string): State?
	local make = presets[name]
	if not make then
		return nil
	end
	return make()
end

-- The beta portal for a World: open, with the Loaner always selectable.
function PortalFixtures.betaOpen(worldId: string): State
	return presets["Beta_" .. worldId]()
end

-- The Start In choices: the Loaner first (always, owned or not), then every other owned car in roster order.
function PortalFixtures.startChoices(state: State): { RosterCar }
	local out: { RosterCar } = {}
	for _, c in state.roster do
		if c.loaner then
			table.insert(out, c)
		end
	end
	if #out == 0 then
		-- a roster that names no Loaner still gets one: the first car stands in
		local first = state.roster[1]
		if first then
			table.insert(out, first)
		end
	end
	for _, c in state.roster do
		if c.owned and not c.loaner and c ~= out[1] then
			table.insert(out, c)
		end
	end
	return out
end

-- Downtown's cars as the full prototype CarRef the Garage uses (the Garage fixtures stay the source of those).
function PortalFixtures.downtownCarRef(id: string): Fixtures.CarRef?
	return Fixtures.byId(id)
end

return PortalFixtures
