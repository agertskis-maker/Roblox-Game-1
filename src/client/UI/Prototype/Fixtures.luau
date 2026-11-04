--!strict
-- PREVIEW fixtures for the Lane 3 screens. Round 4 (E-04, E-05): the cars are the 27 real showroom cars from the ONE roster
-- (src/shared/UI/RosterFixtures, a stand-in for Brian L's Catalog), drawn from their models in ReplicatedStorage.Cars, and
-- every economy number comes from src/shared/UI/EconomyPreview (Brian L's economy v1 proposal). The player's collection
-- (PreviewCollection) is a made-up example shaped like the agreed save field Cars { [carId]: { Edition, Copies } }: it
-- exercises the edition ladder's states and is not anyone's save. Nothing here is an ownership record or a reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyPreview = require(ReplicatedStorage.Shared.UI.EconomyPreview)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)

local Fixtures = {}

export type CarRef = {
	id: string,
	name: string,
	rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	variant: "None" | "Gold" | "Chrome" | "Diamond" | "Rainbow" | "Galaxy",
	family: string,
	quirk: string,
	owned: boolean,
	unseen: boolean?,
	model: string?,
	paint: Color3?,
	length: number?, -- proxy size in studs (part-built proxies only)
	edition: number?, -- 1 Normal .. 5 Galaxy; 0 = not owned (the card's five edition dots stay empty)
}

-- The example collection (agreed field shape: Edition 1..5, Copies at that edition). Downtown 6 / 9, Dusty Highway 3 / 9,
-- Summit Pass 1 / 9: Unlocked 10 / 27. Chosen so every edition-ladder case has a car: Normal with 0 copies (Putter), one copy
-- short of a merge (Pizza Runner), just merged (Minnow), Gold towards Diamond (Executive), Diamond (Bolt), Rainbow
-- (Surf Wagon) and the top edition (Rustbucket, Galaxy).
Fixtures.PreviewCollection = table.freeze({
	Putter = { Edition = 1, Copies = 0 },
	["Pizza Runner"] = { Edition = 1, Copies = 24 },
	Minnow = { Edition = 2, Copies = 0 },
	["Surf Wagon"] = { Edition = 4, Copies = 7 },
	Bolt = { Edition = 3, Copies = 3 },
	Executive = { Edition = 2, Copies = 12 },
	Rustbucket = { Edition = 5, Copies = 0 },
	["Old Faithful"] = { Edition = 1, Copies = 5 },
	["Beach Bug"] = { Edition = 1, Copies = 1 },
	Commuter = { Edition = 1, Copies = 0 },
}) :: { [string]: { Edition: number, Copies: number } }

local EDITION_VARIANT = { "None", "Gold", "Diamond", "Rainbow", "Galaxy" }

-- The old made-up fixture ids, kept only so the harness sheets keep working: each now names a real car.
local LEGACY: { [string]: string } = {
	puglet = "Putter",
	fishbowl = "Pizza Runner",
	waffle = "Surf Wagon",
	rangy = "Minnow",
	rev6 = "Bolt",
	zoomurai = "Brawler",
	hurrikan = "Executive",
	hyperion = "Street Kid",
}

-- A roster car as a card's CarRef, with the example collection's edition (owned cars show their best edition's model).
function Fixtures.carRef(
	car: RosterFixtures.Car,
	collection: { [string]: { Edition: number, Copies: number } }?
): CarRef
	local entry = (collection or Fixtures.PreviewCollection)[car.id]
	local edition = if entry then math.clamp(entry.Edition, 1, 5) else 0
	local model = car.model
	local folder = ReplicatedStorage:FindFirstChild("Cars")
	local editionModel = if edition >= 2 then RosterFixtures.modelFor(car, edition) else nil
	if editionModel and folder and folder:FindFirstChild(editionModel) then
		model = editionModel
	end
	return {
		id = car.id,
		name = car.name,
		rarity = car.rarity,
		variant = (EDITION_VARIANT[edition] or "None") :: any,
		family = RosterFixtures.WorldNames[car.world],
		quirk = if car.loaner then "Your first car here" else "Fill the Keys to claim it",
		owned = entry ~= nil,
		model = model,
		edition = edition,
	}
end

Fixtures.Cars = (function()
	local list: { CarRef } = {}
	for _, car in RosterFixtures.Cars do
		table.insert(list, Fixtures.carRef(car))
	end
	return list
end)()

-- Edition examples for the harness sheets (real cars at Gold, Diamond and Rainbow; the key "Chrome" is kept for old sheets).
Fixtures.Variants = {
	Gold = Fixtures.carRef(RosterFixtures.byId("Minnow") :: RosterFixtures.Car),
	Chrome = Fixtures.carRef(RosterFixtures.byId("Bolt") :: RosterFixtures.Car),
	Rainbow = Fixtures.carRef(RosterFixtures.byId("Surf Wagon") :: RosterFixtures.Car),
}

local function proxy(id: string, name: string, rarity: string, paint: Color3, length: number): CarRef
	return {
		id = id,
		name = name,
		rarity = rarity :: any,
		variant = "None",
		family = "Van",
		quirk = "Cool Runner",
		owned = true,
		paint = paint,
		length = length,
		model = "Proxy",
	}
end

-- Edge cases for the card and grid HARNESS SHEETS only (never listed in a game screen).
Fixtures.LongName =
	proxy("longname", "Supercalifragilistic Snack Shack Deluxe", "Uncommon", Color3.fromRGB(255, 120, 60), 15)
Fixtures.Missing = (function()
	local c = proxy("missing", "Mystery Model", "Rare", Color3.fromRGB(120, 120, 120), 14)
	c.model = nil -- loading / unavailable asset
	return c
end)()

function Fixtures.byId(id: string): CarRef?
	local real = LEGACY[id] or id
	for _, c in Fixtures.Cars do
		if c.id == real then
			return c
		end
	end
	return nil
end

-- Balances used by the scripted playback (display values only), up to the Qa range (E-07).
Fixtures.Balances = { 0, 7, 950, 9450, 12500, 116000, 999999, 1250000, 3400000000, 2e12, 999999999999999, 1.23e15 }

-- A placeholder tutorial list: NOT the real onboarding flow.
Fixtures.Tutorial = {
	{ objective = "Hop onto 3 cars", goal = 3, hint = "Tap HOP when the ring turns teal" },
	{ objective = "Drive 300 m", goal = 300, hint = "Stay in your lane" },
	{ objective = "Visit the Garage", goal = 1, hint = "Follow the arrows" },
}

-- Raceway earning line: one Common car's Normal Lap Pay at level 1 (EconomyPreview; Brian L owns the real rate).
Fixtures.EarningPerLap = EconomyPreview.lapPay("Common")

export type CardInfo = {
	world: string?,
	family: string?,
	lapPay: number?,
	lapSeconds: number?,
	stats: { { label: string, value: string, bar: number?, scale: string? } }?,
	quirkLine: string?,
	variants: { Gold: boolean?, Chrome: boolean?, Rainbow: boolean? }?,
	edition: number?, -- 1..5, the best edition reached (nil = not owned)
	copies: number?, -- copies held at that edition (the agreed Copies field, read as 0..24)
	flavour: string?,
	collectionNo: number?,
	collectionTotal: number?,
	claimedAt: string?,
	isNew: boolean?,
}

-- The preview card data for a roster car (nil for an id that is not in the roster). Lap Pay is the car's own pay per lap at
-- its best edition, before the Raceway level multiplies every car (EconomyPreview.lapPay with level 1).
function Fixtures.cardInfo(id: string): CardInfo?
	local car = RosterFixtures.byId(LEGACY[id] or id)
	if not car then
		return nil
	end
	local entry = Fixtures.PreviewCollection[car.id]
	local index = table.find(RosterFixtures.inWorld(car.world), car)
	return {
		world = car.world,
		lapPay = EconomyPreview.lapPay(car.rarity, if entry then entry.Edition else 1, 1),
		lapSeconds = EconomyPreview.LapSeconds,
		edition = if entry then entry.Edition else nil,
		copies = if entry then entry.Copies else nil,
		collectionNo = index,
		collectionTotal = 9,
		claimedAt = nil,
		isNew = nil,
	}
end

-- Results fixtures (real car ids; the Cash values are display examples)
Fixtures.Results = {
	Typical = {
		distance = 1240,
		roadCoins = 35, -- FIXTURE: seven $5 Downtown road coins, already inside earnings
		totalIncludesPickups = true,
		best = 1100,
		newBest = true,
		claimed = { "Bolt" },
		earnings = 2735,
		joyride = 30,
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
		claimed = { "Minnow", "Bolt", "Brawler", "Executive", "Street Kid" },
		earnings = 276620,
		joyride = 150,
		milestones = 9,
	},
}

return Fixtures
