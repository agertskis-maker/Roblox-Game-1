--!strict
-- SYNTHETIC fixtures for the HUD prototype (Lane 3 preview). Every value here is made up for
-- review and is not an economy, reward or ownership rule. Car names come from the proposed roster
-- (vault/design/cars/roster.md, pending Adam's review); the cards show original part-built scale
-- proxies (ProxyCar), because no finished car model exists in ReplicatedStorage.Cars yet.

local Fixtures = {}

export type CarRef = {
	id: string,
	name: string,
	rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	variant: "None" | "Gold" | "Chrome" | "Rainbow",
	family: string,
	quirk: string,
	owned: boolean,
	unseen: boolean?,
	model: string?,
	paint: Color3?,
	length: number?, -- proxy size in studs (the Puglet reference is 12.47 x 5.66 x 4.71)
}

local function car(
	id: string,
	name: string,
	rarity: string,
	family: string,
	quirk: string,
	paint: Color3,
	length: number,
	owned: boolean
): CarRef
	return {
		id = id,
		name = name,
		rarity = rarity :: any,
		variant = "None",
		family = family,
		quirk = quirk,
		owned = owned,
		paint = paint,
		length = length,
		model = "Proxy",
	}
end

-- Downtown (World 1), from the proposed roster
Fixtures.Cars = {
	car("puglet", "Puglet", "Common", "Compact", "Nimble", Color3.fromRGB(40, 120, 232), 12.5, true),
	car("fishbowl", "Fishbowl Express", "Common", "Bus", "Plow", Color3.fromRGB(0, 166, 180), 26, true),
	car("waffle", "Citrine Waffle Van", "Uncommon", "Van", "Cool Runner", Color3.fromRGB(194, 24, 91), 15, true),
	car("rangy", "Rangy", "Uncommon", "Pickup", "Rugged", Color3.fromRGB(232, 179, 58), 16, false),
	car("rev6", "Revolution 6", "Rare", "Sedan", "Steady", Color3.fromRGB(30, 86, 200), 14.5, false),
	car("zoomurai", "Zoomurai", "Rare", "Motorcycle", "Slipstream", Color3.fromRGB(244, 194, 13), 7, false),
	car("hurrikan", "Hurrikan", "Epic", "Sports", "Long Jump", Color3.fromRGB(139, 203, 44), 14, false),
	car("hyperion", "Hyperion", "Legendary", "Special", "Magnet", Color3.fromRGB(238, 241, 245), 14.5, false),
} :: { CarRef }

-- Variant examples (finishes, not rarities)
Fixtures.Variants = {
	Gold = (function()
		local c = table.clone(Fixtures.Cars[1])
		c.id ..= "-gold"
		c.variant = "Gold"
		return c
	end)(),
	Chrome = (function()
		local c = table.clone(Fixtures.Cars[5])
		c.id ..= "-chrome"
		c.variant = "Chrome"
		c.owned = true
		return c
	end)(),
	Rainbow = (function()
		local c = table.clone(Fixtures.Cars[3])
		c.id ..= "-rainbow"
		c.variant = "Rainbow"
		return c
	end)(),
}

-- Edge cases for the card and grid
Fixtures.LongName = car(
	"longname",
	"Supercalifragilistic Snack Shack Deluxe",
	"Uncommon",
	"Van",
	"Cool Runner",
	Color3.fromRGB(255, 120, 60),
	15,
	true
)
Fixtures.Missing = (function()
	local c = car("missing", "Mystery Model", "Rare", "Sedan", "Steady", Color3.fromRGB(120, 120, 120), 14, true)
	c.model = nil -- loading / unavailable asset
	return c
end)()

function Fixtures.byId(id: string): CarRef?
	for _, c in Fixtures.Cars do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- Balances used by the scripted playback (display values only).
Fixtures.Balances = { 0, 7, 950, 9450, 12500, 116000, 999999, 1250000, 3400000000, 999999999999999 }

-- A placeholder tutorial list: NOT the real onboarding flow.
Fixtures.Tutorial = {
	{ objective = "Hop onto 3 cars", goal = 3, hint = "Tap HOP when the ring turns teal" },
	{ objective = "Drive 300 m", goal = 300, hint = "Stay in your lane" },
	{ objective = "Visit the Garage", goal = 1, hint = "Follow the arrows" },
}

-- Speedway earning line: a FIXTURE value per lap (Brian L owns the real rate, units and formula).
Fixtures.EarningPerLap = 120

-- Collectible card data (Round 2). SYNTHETIC preview values, labelled as such everywhere they show:
--   * quirk lines and Heat capacity (seconds, Tunable) are the outline v2 family table (section 07), the
--     documented values; the bar scale is the family range 0-14 s;
--   * Lap Pay is a made-up dollar amount; lapSeconds is nil because no lap duration is defined, so the
--     per-second row reads "unavailable (proposed)";
--   * flavour lines are original child-friendly preview jokes; collection numbers follow the roster order
--     (1 of 24 in the 8 families x 3 Worlds template); claimedAt is supplied for ONE card only, to show the path.
local FAMILY_HEAT =
	{ Compact = 8, Sedan = 11, Pickup = 11, Van = 14, Sports = 9, Motorcycle = 9, Truck = 12, Bus = 12, Special = 10 }
local FAMILY_QUIRK_LINE = {
	Compact = "Fastest lane changes; recovers from Slicks in half the time.",
	Sedan = "Baseline everything; the easiest car to claim from.",
	Pickup = "Potholes add no Heat and cause no jolt.",
	Van = "Longest Heat Capacity; the car to rest in.",
	Sports = "Hop range is 50% longer; can reach cars across a Gap.",
	Motorcycle = "Narrow body: rides between two cars in adjacent lanes.",
	Truck = "Smashes through Construction barriers and cones without ending the run.",
	Bus = "Smashes through Construction barriers and cones without ending the run.",
	Special = "Pulls in road coins from nearby lanes.",
}
local FLAVOUR = {
	puglet = "Wrinkly bumper, wagging exhaust.",
	fishbowl = "Everyone aboard is a little bit bubbly.",
	waffle = "Smells like Saturday morning.",
	rangy = "Has never met a puddle it did not like.",
	rev6 = "Parks in any spot, eventually.",
	zoomurai = "Brakes politely, accelerates dramatically.",
	hurrikan = "Leaves a tiny breeze wherever it goes.",
	hyperion = "Collects shiny things. Mostly coins.",
}
local LAP_PAY = {
	puglet = 80,
	fishbowl = 120,
	waffle = 150,
	rangy = 150,
	rev6 = 220,
	zoomurai = 260,
	hurrikan = 340,
	hyperion = 480,
}

export type CardInfo = {
	world: string?,
	family: string?,
	lapPay: number?,
	lapSeconds: number?,
	stats: { { label: string, value: string, bar: number?, scale: string? } }?,
	quirkLine: string?,
	variants: { Gold: boolean?, Chrome: boolean?, Rainbow: boolean? }?,
	flavour: string?,
	collectionNo: number?,
	collectionTotal: number?,
	claimedAt: string?,
	isNew: boolean?,
}

-- The preview card data for a roster car (nil for a car with no fixture).
function Fixtures.cardInfo(id: string): CardInfo?
	local c = Fixtures.byId(id)
	if not c then
		return nil
	end
	local base = string.gsub(id, "%-.*$", "") -- variant ids end in -gold / -chrome / -rainbow
	local index = 0
	for i, k in Fixtures.Cars do
		if k.id == base then
			index = i
		end
	end
	local heat = FAMILY_HEAT[c.family]
	return {
		world = "Downtown",
		lapPay = LAP_PAY[base],
		lapSeconds = nil, -- no lap duration is defined: the per-second row stays "unavailable (proposed)"
		stats = if heat
			then {
				{
					label = "Heat capacity",
					value = tostring(heat) .. " s (Tunable)",
					bar = heat / 14,
					scale = "0 to 14 s",
				},
			}
			else nil,
		quirkLine = FAMILY_QUIRK_LINE[c.family],
		variants = if c.variant == "None"
			then { Gold = if c.owned then false else nil, Chrome = nil, Rainbow = nil }
			else nil,
		flavour = FLAVOUR[base],
		collectionNo = if index > 0 then index else nil,
		collectionTotal = 24,
		claimedAt = if base == "rev6" and c.owned then "Oct 22" else nil,
		isNew = nil,
	}
end

-- Results fixtures
Fixtures.Results = {
	Typical = {
		distance = 1240,
		roadCoins = 35, -- FIXTURE: seven +$5 pickups, already inside earnings
		totalIncludesPickups = true,
		best = 1100,
		newBest = true,
		claimed = { "rev6" },
		earnings = 340,
		joyride = 50,
		milestones = 2,
	},
	NoRewards = {
		distance = 85,
		roadCoins = 0,
		totalIncludesPickups = true,
		best = 1100,
		newBest = false,
		claimed = {},
		earnings = 0,
		joyride = 0,
		milestones = 0,
	},
	Many = {
		distance = 4820,
		roadCoins = 120,
		totalIncludesPickups = true,
		best = 4100,
		newBest = true,
		claimed = { "rangy", "rev6", "zoomurai", "hurrikan", "hyperion" },
		earnings = 2150,
		joyride = 150,
		milestones = 5,
	},
}

return Fixtures
