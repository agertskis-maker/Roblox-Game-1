--!strict
-- CosmeticPreviewCatalog: the PREVIEW catalog of car paint, decals and wheels for the Stunt Circuit customization screen (Lane 3,
-- Round 2 N12-03b). EVERY price, tier name and medal condition here is a PREVIEW value: arbitrary starting Cash amounts for visual
-- and flow testing, NOT balanced live prices. It adds no currency, no debit, no persistence and no authoritative catalog; it is the
-- proposal Brian L reads when he calibrates the real one (price against verified net Cash per minute at early, middle and
-- advanced progression, and against Raceway upgrades at those points; no competitor prices are claimed).
--
-- A price follows the visual TECHNIQUE only: a higher price never adds speed, grip, jump, income or car rarity. The tier names are
-- Car Hop's own (Basic, Metallic, Pearl, Two-Tone, Animated; Starter, Street, Track, Elite; Stock, Street, Track, Elite,
-- Showpiece), shown as words as well as colour. The medal conditions are PRESENTATION states: Brian R supplies the achievement
-- evidence, Brian L approves the entitlement. An unknown medal stays locked; nothing is unlocked by a made-up race result.
--
--   Counts: 33 paints (8 free + 25), 15 decals (plus "No decal"), 10 wheels.
--   CosmeticPreviewCatalog.Items[tab] / .Tiers[tab] / .byId(tab, id) / .counts() / .tierItems(tab, tierId)
--   CosmeticPreviewCatalog.defaultOwnership() / .defaultEquipped() / .stateOf(item, ownership, equippedId)
--
-- HOW EACH ITEM IS SHOWN is recorded per item in `render` and `note`:
--   "car"     built from parts on the turntable car and from shapes on the card
--   "approx"  built, but an approximation of the idea (the note says how)
--   "swatch"  the CARD shows the design; the car shows no change (the screen says "Card preview only")
-- The turntable car is a neutral part-built preview rig, never one of Brian L's models.

local CosmeticPreviewCatalog = {}

CosmeticPreviewCatalog.Source =
	"PREVIEW catalog: prices, tiers and medal conditions are arbitrary starting values (Brian L calibrates the real ones)"
CosmeticPreviewCatalog.Caption = "PREVIEW"

export type TabId = "Paint" | "Decals" | "Wheels"
export type MedalKey = "gold" | "silver" | "bronze"
export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type PaintKind = "solid" | "metallic" | "pearl" | "gradient" | "animated"
export type Render = "car" | "approx" | "swatch"

export type Tier = {
	id: string,
	name: string,
	rarity: RarityName,
}

export type Item = {
	id: string,
	name: string,
	tab: TabId,
	tier: string, -- a Tier id of the same tab
	price: number, -- PREVIEW Cash, 0 = free
	medal: MedalKey?, -- the medal a medal-locked item also needs (a fixture condition)
	kind: PaintKind?, -- paints only
	colours: { Color3 }, -- paint colours, or the design's accent colours
	cycleSeconds: number?, -- animated paints: one full colour cycle
	render: Render,
	note: string, -- one honest line on how the preview shows it
	isNone: boolean?, -- the "No decal" entry (not counted)
}

CosmeticPreviewCatalog.Tabs = table.freeze({ "Paint", "Decals", "Wheels" } :: { TabId })
CosmeticPreviewCatalog.TabLabels = table.freeze({ Paint = "PAINT", Decals = "DECALS", Wheels = "WHEELS" })
-- the family-art icon for each tab (painter names)
CosmeticPreviewCatalog.TabIcons = table.freeze({ Paint = "PaintBucket", Decals = "Decal", Wheels = "Wheel" })

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TIERS ----------------------------------------------------------------------------------------------------------------------

local function tier(id: string, name: string, rarity: RarityName): Tier
	return { id = id, name = name, rarity = rarity }
end

CosmeticPreviewCatalog.Tiers = table.freeze({
	Paint = table.freeze({
		tier("basic", "BASIC", "Common"),
		tier("metallic", "METALLIC", "Uncommon"),
		tier("pearl", "PEARL", "Rare"),
		tier("twotone", "TWO-TONE", "Epic"),
		tier("animated", "ANIMATED", "Legendary"),
		tier("medal", "MEDAL", "Epic"),
	}),
	Decals = table.freeze({
		tier("starter", "STARTER", "Common"),
		tier("street", "STREET", "Uncommon"),
		tier("track", "TRACK", "Rare"),
		tier("elite", "ELITE", "Epic"),
	}),
	Wheels = table.freeze({
		tier("stock", "STOCK", "Common"),
		tier("street", "STREET", "Uncommon"),
		tier("track", "TRACK", "Rare"),
		tier("elite", "ELITE", "Epic"),
		tier("showpiece", "SHOWPIECE", "Legendary"),
	}),
} :: { [string]: { Tier } })

-- PAINT (33) -----------------------------------------------------------------------------------------------------------------

local function slug(name: string): string
	return (string.lower(name):gsub("[^%w]+", "_"))
end

local function paint(
	name: string,
	tierId: string,
	price: number,
	kind: PaintKind,
	colours: { Color3 },
	note: string,
	render: Render?,
	extra: { medal: MedalKey?, cycle: number? }?
): Item
	local e = extra or {}
	return {
		id = slug(name),
		name = name,
		tab = "Paint",
		tier = tierId,
		price = price,
		medal = e.medal,
		kind = kind,
		colours = colours,
		cycleSeconds = e.cycle,
		render = render or "car",
		note = note,
	}
end

local SOLID = "A clean solid colour on the body."
local METAL = "Metal body with a lighter roof highlight (no real reflections in the preview)."
local PEARL = "A soft two-colour sheen, shown as six smooth body bands (not a texture)."
local FADE = "A front-to-rear blend, shown as six body bands (not a texture)."
local FLOW = "A slow colour cycle across six body bands, about 12 updates a second (not a texture)."

local paints: { Item } = {
	-- BASIC, free (8): immediately available in the preview
	paint("Pit White", "basic", 0, "solid", { rgb(236, 240, 248) }, SOLID),
	paint("Asphalt Charcoal", "basic", 0, "solid", { rgb(58, 62, 74) }, SOLID),
	paint("Downtown Blue", "basic", 0, "solid", { rgb(40, 120, 232) }, SOLID),
	paint("Signal Red", "basic", 0, "solid", { rgb(226, 56, 60) }, SOLID),
	paint("Taxi Gold", "basic", 0, "solid", { rgb(250, 196, 40) }, SOLID),
	paint("Fresh Lime", "basic", 0, "solid", { rgb(110, 210, 70) }, SOLID),
	paint("Bubblegum Pink", "basic", 0, "solid", { rgb(255, 140, 200) }, SOLID),
	paint("Cloud Cyan", "basic", 0, "solid", { rgb(120, 220, 240) }, SOLID),
	-- BASIC, additional (2)
	paint("Tangerine Pop", "basic", 250, "solid", { rgb(255, 138, 40) }, SOLID),
	paint("Plum Punch", "basic", 250, "solid", { rgb(150, 60, 170) }, SOLID),
	-- METALLIC (5): { highlight, base }
	paint("Brushed Steel", "metallic", 750, "metallic", { rgb(214, 220, 232), rgb(140, 150, 168) }, METAL),
	paint("Copper Sprint", "metallic", 750, "metallic", { rgb(232, 154, 100), rgb(160, 90, 48) }, METAL),
	paint("Midnight Alloy", "metallic", 900, "metallic", { rgb(96, 108, 160), rgb(26, 30, 62) }, METAL),
	paint("Cobalt Chrome", "metallic", 900, "metallic", { rgb(130, 172, 250), rgb(34, 70, 160) }, METAL),
	paint("Rose Metal", "metallic", 1100, "metallic", { rgb(250, 176, 196), rgb(176, 96, 118) }, METAL),
	-- PEARL (5): { front, rear }
	paint("Shell Pearl", "pearl", 1800, "pearl", { rgb(255, 240, 232), rgb(255, 196, 214) }, PEARL, "approx"),
	paint("Glacier Pearl", "pearl", 1800, "pearl", { rgb(226, 244, 255), rgb(150, 196, 250) }, PEARL, "approx"),
	paint("Mint Pearl", "pearl", 2100, "pearl", { rgb(214, 255, 238), rgb(120, 220, 186) }, PEARL, "approx"),
	paint("Sunset Pearl", "pearl", 2100, "pearl", { rgb(255, 212, 164), rgb(255, 130, 168) }, PEARL, "approx"),
	paint("Lavender Pearl", "pearl", 2400, "pearl", { rgb(236, 220, 255), rgb(164, 136, 240) }, PEARL, "approx"),
	-- TWO-TONE GRADIENT (5): { front, rear }
	paint("Citrus Split", "twotone", 3500, "gradient", { rgb(255, 214, 60), rgb(110, 210, 60) }, FADE, "approx"),
	paint("Candy Horizon", "twotone", 3500, "gradient", { rgb(255, 120, 190), rgb(110, 170, 255) }, FADE, "approx"),
	paint("Ocean Fade", "twotone", 4000, "gradient", { rgb(70, 220, 232), rgb(24, 66, 168) }, FADE, "approx"),
	paint("Dusk Runner", "twotone", 4000, "gradient", { rgb(255, 150, 70), rgb(92, 52, 156) }, FADE, "approx"),
	paint("Peach Skyline", "twotone", 4500, "gradient", { rgb(255, 196, 150), rgb(255, 104, 136) }, FADE, "approx"),
	-- ANIMATED (5): a slow colour cycle, body only
	paint("Rainbow Flow", "animated", 7500, "animated", {
		rgb(255, 72, 72),
		rgb(255, 170, 40),
		rgb(255, 230, 60),
		rgb(80, 220, 90),
		rgb(60, 170, 255),
		rgb(170, 90, 255),
	}, FLOW, "approx", { cycle = 6 }),
	paint("Galaxy Drift", "animated", 9000, "animated", {
		rgb(30, 22, 92),
		rgb(96, 52, 190),
		rgb(214, 70, 190),
		rgb(60, 170, 255),
	}, FLOW .. " No star texture.", "approx", { cycle = 8 }),
	paint("Lava Cruise", "animated", 10000, "animated", {
		rgb(110, 14, 20),
		rgb(230, 60, 20),
		rgb(255, 160, 30),
		rgb(230, 60, 20),
	}, FLOW .. " No lava texture.", "approx", { cycle = 7 }),
	paint("Aurora Ribbon", "animated", 12000, "animated", {
		rgb(60, 230, 140),
		rgb(40, 190, 210),
		rgb(130, 110, 240),
		rgb(60, 230, 140),
	}, FLOW .. " No ribbon pattern.", "approx", { cycle = 8 }),
	paint("Electric Tide", "animated", 12000, "animated", {
		rgb(20, 120, 255),
		rgb(60, 220, 255),
		rgb(235, 250, 255),
		rgb(60, 220, 255),
	}, FLOW .. " No wave pattern.", "approx", { cycle = 6 }),
	-- MEDAL-LOCKED (3): Cash AND a medal; both conditions are shown, and both are a fixture
	paint("Bronze Dash", "medal", 2500, "metallic", { rgb(236, 168, 100), rgb(150, 86, 36) }, METAL, "car", {
		medal = "bronze",
	}),
	paint("Silver Current", "medal", 5000, "metallic", { rgb(232, 238, 248), rgb(132, 144, 166) }, METAL, "car", {
		medal = "silver",
	}),
	paint("Gold Horizon", "medal", 10000, "metallic", { rgb(255, 232, 120), rgb(226, 150, 0) }, METAL, "car", {
		medal = "gold",
	}),
}

-- DECALS (15 plus "No decal") --------------------------------------------------------------------------------------------------

local function decal(
	name: string,
	tierId: string,
	price: number,
	colours: { Color3 },
	render: Render,
	note: string
): Item
	return {
		id = slug(name),
		name = name,
		tab = "Decals",
		tier = tierId,
		price = price,
		colours = colours,
		render = render,
		note = note,
	}
end

local WHITE = rgb(248, 248, 244)
local INK = rgb(26, 32, 56)
local GOLD = rgb(255, 206, 60)
local RED = rgb(232, 56, 64)
local CYAN = rgb(90, 220, 255)
local ORANGE = rgb(255, 140, 40)

local decals: { Item } = {
	{
		id = "none",
		name = "No decal",
		tab = "Decals",
		tier = "starter",
		price = 0,
		colours = { rgb(150, 160, 190) },
		render = "car",
		note = "Clears the decal.",
		isNone = true,
	},
	decal("Twin Sprint", "starter", 400, { WHITE }, "car", "Two broad offset stripes on the hood."),
	decal("Side Slash", "starter", 500, { WHITE, GOLD }, "car", "An angular stripe on each door side."),
	decal("Checker Corner", "starter", 650, { WHITE, INK }, "car", "A small checker patch at the rear quarter."),
	decal("Lucky Seven", "starter", 650, { WHITE, INK }, "approx", "A round number 7, built from simple bars."),
	decal("Comet Tail", "street", 900, { GOLD, WHITE }, "approx", "A swept star with a tapering trail (flat blocks)."),
	decal("Zigzag Charge", "street", 900, { GOLD }, "car", "A bold broken lightning stroke on the hood."),
	decal(
		"Friendly Fangs",
		"street",
		1100,
		{ WHITE, RED },
		"approx",
		"Playful teeth along the hood edge (diamond shapes)."
	),
	decal("Bubble Burst", "street", 1100, { CYAN, WHITE }, "car", "Three overlapping round bubble marks."),
	decal("Summit Steps", "track", 1400, { WHITE, CYAN }, "car", "Layered mountain-step blocks."),
	decal(
		"Dust Devil",
		"track",
		1400,
		{ rgb(240, 190, 110), WHITE },
		"swatch",
		"A curling sand swirl. Card preview only."
	),
	decal("Star Scatter", "track", 1800, { GOLD, WHITE }, "car", "Sparse stars of different sizes on the hood."),
	decal("Circuit Lines", "track", 1800, { CYAN, WHITE }, "approx", "An electronic path pattern (straight segments)."),
	decal("Solar Flare", "elite", 2400, { ORANGE, GOLD, WHITE }, "approx", "Flame tongues drawn as slanted blocks."),
	decal("Night Orbit", "elite", 2800, { WHITE, GOLD }, "approx", "An offset ring with tiny moons (ring of blocks)."),
	decal("Checkered Comet", "elite", 3400, { WHITE, INK, GOLD }, "approx", "A checker patch blending into a tail."),
}

-- WHEELS (10) ---------------------------------------------------------------------------------------------------------------------

local function wheel(
	name: string,
	tierId: string,
	price: number,
	colours: { Color3 },
	render: Render,
	note: string
): Item
	return {
		id = slug(name),
		name = name,
		tab = "Wheels",
		tier = tierId,
		price = price,
		colours = colours,
		render = render,
		note = note,
	}
end

local STEEL = rgb(200, 206, 222)
local DARK = rgb(44, 48, 66)
local WHEELS_NOTE = "Same tyre size, mounts and handling: only the look changes."

local wheels: { Item } = {
	wheel(
		"Stock Five",
		"stock",
		0,
		{ STEEL, DARK, rgb(120, 126, 146) },
		"car",
		"A simple chunky five-spoke. " .. WHEELS_NOTE
	),
	wheel(
		"Rally Block",
		"street",
		900,
		{ rgb(226, 230, 240), DARK, rgb(226, 230, 240) },
		"car",
		"Squared spokes on a dark inset. " .. WHEELS_NOTE
	),
	wheel(
		"Classic Disc",
		"street",
		1200,
		{ rgb(236, 240, 250), rgb(60, 66, 90), rgb(150, 156, 176) },
		"car",
		"A clean disc with small vent cuts. " .. WHEELS_NOTE
	),
	wheel(
		"Split Six",
		"street",
		1600,
		{ STEEL, DARK, rgb(240, 244, 252) },
		"car",
		"Six paired spokes. " .. WHEELS_NOTE
	),
	wheel(
		"Trail Chunk",
		"track",
		2000,
		{ rgb(176, 182, 198), DARK, rgb(30, 34, 48) },
		"approx",
		"Off-road tread blocks inside the tyre size. " .. WHEELS_NOTE
	),
	wheel(
		"Star Runner",
		"track",
		2800,
		{ rgb(255, 214, 80), DARK, rgb(255, 244, 190) },
		"car",
		"A broad rounded star hub. " .. WHEELS_NOTE
	),
	wheel(
		"Golden Turbine",
		"elite",
		3500,
		{ rgb(255, 204, 60), DARK, rgb(255, 232, 140) },
		"car",
		"Swept gold spokes. " .. WHEELS_NOTE
	),
	wheel(
		"Neon Halo",
		"elite",
		4500,
		{ DARK, rgb(60, 70, 100), rgb(90, 240, 255) },
		"approx",
		"A thin steady neon ring, no flashing and no glow bloom in the preview. " .. WHEELS_NOTE
	),
	wheel(
		"Moon Dish",
		"elite",
		5000,
		{ rgb(232, 236, 255), rgb(190, 176, 240), rgb(250, 252, 255) },
		"approx",
		"A smooth pearly dish (no pearl sheen in the preview). " .. WHEELS_NOTE
	),
	wheel(
		"Monster Mini",
		"showpiece",
		6000,
		{ rgb(176, 182, 198), DARK, rgb(240, 90, 60) },
		"approx",
		"An exaggerated tread silhouette inside the fit envelope. A visual treatment only. " .. WHEELS_NOTE
	),
}

CosmeticPreviewCatalog.Items = table.freeze({
	Paint = table.freeze(paints),
	Decals = table.freeze(decals),
	Wheels = table.freeze(wheels),
} :: { [string]: { Item } })

-- QUERIES ------------------------------------------------------------------------------------------------------------------------

function CosmeticPreviewCatalog.itemsFor(tab: TabId): { Item }
	return CosmeticPreviewCatalog.Items[tab]
end

function CosmeticPreviewCatalog.byId(tab: TabId, id: string): Item?
	for _, item in CosmeticPreviewCatalog.Items[tab] do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- The items of one tier, in catalog order (cheapest first).
function CosmeticPreviewCatalog.tierItems(tab: TabId, tierId: string): { Item }
	local out: { Item } = {}
	for _, item in CosmeticPreviewCatalog.Items[tab] do
		if item.tier == tierId then
			table.insert(out, item)
		end
	end
	return out
end

function CosmeticPreviewCatalog.tierOf(tab: TabId, tierId: string): Tier?
	for _, t in CosmeticPreviewCatalog.Tiers[tab] do
		if t.id == tierId then
			return t
		end
	end
	return nil
end

-- 33 / 15 / 10 (the "No decal" entry is not a decal)
function CosmeticPreviewCatalog.counts(): { [string]: number }
	local out: { [string]: number } = {}
	for _, tab in CosmeticPreviewCatalog.Tabs do
		local n = 0
		for _, item in CosmeticPreviewCatalog.Items[tab] do
			if not item.isNone then
				n += 1
			end
		end
		out[tab] = n
	end
	return out
end

-- FIXTURE STATE --------------------------------------------------------------------------------------------------------------------

export type Ownership = {
	owned: { [string]: boolean }, -- item id -> bought already (a fixture; free items are always owned)
	medals: { [string]: boolean }, -- medal key -> earned
	unavailable: { [string]: boolean }, -- item id -> not available for this car
}

export type Equipped = { Paint: string, Decals: string, Wheels: string }

-- PREVIEW Cash the screen starts with (a fixture balance, never the player's real Cash).
CosmeticPreviewCatalog.DefaultBalance = 5000

function CosmeticPreviewCatalog.defaultOwnership(): Ownership
	return {
		owned = { tangerine_pop = true, brushed_steel = true, twin_sprint = true, rally_block = true },
		medals = { bronze = true, silver = false, gold = false },
		unavailable = { night_orbit = true },
	}
end

function CosmeticPreviewCatalog.defaultEquipped(): Equipped
	return { Paint = "downtown_blue", Decals = "none", Wheels = "stock_five" }
end

export type ItemState = "equipped" | "owned" | "locked" | "priced" | "unavailable"

-- The base state of an item. unavailable: not offered for this car (a different thing from locked). equipped: worn now. owned:
-- free, or bought in this preview. locked: needs a medal that is not earned. priced: can be bought with PREVIEW Cash.
function CosmeticPreviewCatalog.stateOf(item: Item, ownership: Ownership, equippedId: string): ItemState
	if ownership.unavailable[item.id] then
		return "unavailable"
	end
	if item.id == equippedId then
		return "equipped"
	end
	if item.price == 0 or ownership.owned[item.id] then
		return "owned"
	end
	local medal = item.medal
	if medal and not ownership.medals[medal] then
		return "locked"
	end
	return "priced"
end

return CosmeticPreviewCatalog
