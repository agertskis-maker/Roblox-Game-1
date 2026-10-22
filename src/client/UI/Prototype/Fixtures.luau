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

-- Results fixtures
Fixtures.Results = {
	Typical = { distance = 1240, coins = 86, best = 1100, newBest = true, claimed = { "rev6" }, earnings = 340 },
	NoRewards = { distance = 85, coins = 0, best = 1100, newBest = false, claimed = {}, earnings = 0 },
	Many = {
		distance = 4820,
		coins = 412,
		best = 4100,
		newBest = true,
		claimed = { "rangy", "rev6", "zoomurai", "hurrikan", "hyperion" },
		earnings = 2150,
	},
}

return Fixtures
