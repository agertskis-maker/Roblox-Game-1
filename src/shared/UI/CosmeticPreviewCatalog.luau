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
--   Counts (Round 7, C-03 to C-06): 34 paints plus Factory Paint, 20 decals (plus "No decal"), 17 wheels (Round 8: Stock Five plus 16 designs), 13 trails (plus
--   "No trail"). The server (BetaStyle) prices every Cash item from this table and saves what a player owns and wears.
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

export type TabId = "Paint" | "Decals" | "Wheels" | "Trails"
export type MedalKey = "gold" | "silver" | "bronze"
export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type PaintKind =
	"solid"
	| "metallic"
	| "pearl"
	| "gradient"
	| "animated"
	| "flow"
	| "pulse"
	| "galaxy"
	| "rainbow"
	| "sparkle"
	| "chrome"
	| "holo"
	| "molten"
	| "electric"
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
	isNone: boolean?, -- the "No decal" and "No trail" entries (not counted)
	key: string?, -- the texture or mesh this item uses
	robux: number?, -- a Robux item: never sold for Cash, and not on sale while its real product price is unknown
	vip: boolean?, -- Round 7: free with the VIP pass
	design: string?, -- Round 8 (wheels only): the 3D rim design in Style/WheelKit.luau
}

CosmeticPreviewCatalog.Tabs = table.freeze({ "Paint", "Decals", "Wheels", "Trails" } :: { TabId })
CosmeticPreviewCatalog.TabLabels =
	table.freeze({ Paint = "PAINT", Decals = "DECALS", Wheels = "WHEELS", Trails = "TRAILS" })
-- the family-art icon for each tab (painter names)
CosmeticPreviewCatalog.TabIcons =
	table.freeze({ Paint = "PaintBucket", Decals = "Decal", Wheels = "Wheel", Trails = "Trail" })

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- TIERS ----------------------------------------------------------------------------------------------------------------------

local function tier(id: string, name: string, rarity: RarityName): Tier
	return { id = id, name = name, rarity = rarity }
end

CosmeticPreviewCatalog.Tiers = table.freeze({
	-- Round 7 (C-03): six paint tiers, each clearly fancier than the last, with the prices climbing hard
	Paint = table.freeze({
		tier("solid", "SOLID", "Common"),
		tier("metallic", "METALLIC", "Uncommon"),
		tier("twotone", "TWO-TONE", "Rare"),
		tier("animated", "ANIMATED", "Epic"),
		tier("legendary", "LEGENDARY", "Legendary"),
		tier("robux", "ROBUX", "Legendary"),
		tier("vip", "VIP", "Legendary"),
	}),
	-- Round 7 (C-04): simple shapes, then street designs, then designs that move
	Decals = table.freeze({
		tier("simple", "SIMPLE", "Common"),
		tier("street", "STREET", "Rare"),
		tier("animated", "ANIMATED", "Epic"),
	}),
	-- Round 7 (C-06): Cash trails, the four Robux trails, the VIP trail
	Trails = table.freeze({
		tier("street", "STREET", "Uncommon"),
		tier("track", "TRACK", "Rare"),
		tier("elite", "ELITE", "Epic"),
		tier("robux", "ROBUX", "Legendary"),
		tier("vip", "VIP", "Legendary"),
	}),
	-- Round 7 (C-05), Round 8 (W-05): rims and tyre styles; the last tier glows or moves
	Wheels = table.freeze({
		tier("stock", "STOCK", "Common"),
		tier("street", "STREET", "Uncommon"),
		tier("track", "TRACK", "Rare"),
		tier("elite", "ELITE", "Epic"),
		tier("showpiece", "SHOWPIECE", "Legendary"),
		tier("animated", "ANIMATED", "Legendary"),
	}),
} :: { [string]: { Tier } })

-- PAINT (34 plus Factory Paint) --------------------------------------------------------------------------------------------------
-- Round 7 (C-02, C-03): paint covers the body panels only (CarStyle's body masks), never the windows, tyres, lights or chrome.
-- PREVIEW price ladder (brief C-03): solid $500 to $5K, metallic $10K to $100K, two-tone $250K to $2M, animated $5M to $50M,
-- legendary $100M to $2B; three Robux paints (R$ shown only when the real product price is known) and two VIP paints.

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
	extra: { cycle: number?, robux: number?, vip: boolean? }?
): Item
	local e = extra or {}
	return {
		id = slug(name),
		name = name,
		tab = "Paint",
		tier = tierId,
		price = price,
		kind = kind,
		colours = colours,
		cycleSeconds = e.cycle,
		robux = e.robux,
		vip = e.vip,
		render = "car",
		note = note,
	}
end

local SOLID = "A clean solid colour on the body."
local METAL = "Metal flake: deeper shadows and a bright shine on the body."
local PEARL = "Pearl: the shadows one colour, the shine another."
local TWO = "Two colours across the body's light and shade."
local MOVE = "Colours that move across the body."

local paints: { Item } = {
	paint("Factory Paint", "solid", 0, "solid", { rgb(40, 120, 232) }, "The car's own colours."),
	-- SOLID (8)
	paint("Pit White", "solid", 500, "solid", { rgb(240, 242, 248) }, SOLID),
	paint("Asphalt Charcoal", "solid", 500, "solid", { rgb(58, 62, 74) }, SOLID),
	paint("Signal Red", "solid", 1000, "solid", { rgb(226, 40, 48) }, SOLID),
	paint("Downtown Blue", "solid", 1000, "solid", { rgb(30, 110, 240) }, SOLID),
	paint("Taxi Gold", "solid", 2000, "solid", { rgb(255, 196, 30) }, SOLID),
	paint("Fresh Lime", "solid", 2000, "solid", { rgb(110, 220, 60) }, SOLID),
	paint("Bubblegum Pink", "solid", 3500, "solid", { rgb(255, 120, 196) }, SOLID),
	paint("Plum Punch", "solid", 5000, "solid", { rgb(140, 50, 190) }, SOLID),
	-- METALLIC AND PEARL (6)
	paint("Brushed Steel", "metallic", 10000, "metallic", { rgb(190, 198, 214) }, METAL),
	paint("Copper Sprint", "metallic", 15000, "metallic", { rgb(220, 120, 60) }, METAL),
	paint("Cobalt Flake", "metallic", 25000, "metallic", { rgb(40, 90, 230) }, METAL),
	paint("Emerald Flake", "metallic", 40000, "metallic", { rgb(20, 170, 90) }, METAL),
	paint("Shell Pearl", "metallic", 60000, "pearl", { rgb(255, 170, 200), rgb(255, 250, 240) }, PEARL),
	paint("Glacier Pearl", "metallic", 100000, "pearl", { rgb(80, 150, 255), rgb(235, 250, 255) }, PEARL),
	-- TWO-TONE AND GRADIENT (6)
	paint("Citrus Split", "twotone", 250000, "gradient", { rgb(110, 210, 40), rgb(255, 220, 40) }, TWO),
	paint("Candy Horizon", "twotone", 400000, "gradient", { rgb(80, 140, 255), rgb(255, 110, 190) }, TWO),
	paint("Ocean Fade", "twotone", 600000, "gradient", { rgb(16, 50, 160), rgb(70, 230, 240) }, TWO),
	paint("Dusk Runner", "twotone", 900000, "gradient", { rgb(80, 40, 150), rgb(255, 150, 60) }, TWO),
	paint("Cherry Cola", "twotone", 1400000, "gradient", { rgb(90, 10, 30), rgb(255, 60, 80) }, TWO),
	paint("Mint Chip", "twotone", 2000000, "gradient", { rgb(40, 120, 90), rgb(190, 255, 220) }, TWO),
	-- ANIMATED (6)
	paint("Colour Shift", "animated", 5000000, "animated", {
		rgb(255, 72, 72),
		rgb(255, 200, 40),
		rgb(60, 210, 120),
		rgb(60, 140, 255),
		rgb(190, 80, 255),
	}, MOVE, { cycle = 6 }),
	paint("Aurora", "animated", 9000000, "flow", {
		rgb(40, 230, 140),
		rgb(30, 180, 220),
		rgb(140, 100, 240),
	}, "Northern-light bands drifting over the body.", { cycle = 8 }),
	paint("Lava Cruise", "animated", 14000000, "flow", {
		rgb(90, 10, 10),
		rgb(240, 70, 10),
		rgb(255, 190, 40),
	}, "Hot lava bands that ooze along the body.", { cycle = 7 }),
	paint("Ocean Waves", "animated", 20000000, "flow", {
		rgb(10, 50, 140),
		rgb(30, 150, 230),
		rgb(200, 245, 255),
	}, "Rolling waves of blue across the body.", { cycle = 6 }),
	paint(
		"Neon Pulse",
		"animated",
		32000000,
		"pulse",
		{ rgb(255, 40, 200), rgb(60, 255, 240) },
		"A neon glow that beats."
	),
	paint("Sunset Cruise", "animated", 50000000, "flow", {
		rgb(255, 90, 60),
		rgb(255, 180, 60),
		rgb(190, 70, 160),
	}, "A slow sunset sliding along the body.", { cycle = 9 }),
	-- LEGENDARY (4)
	paint("Galaxy Swirl", "legendary", 100000000, "galaxy", {
		rgb(20, 12, 60),
		rgb(110, 50, 200),
		rgb(255, 255, 255),
	}, "Deep space with stars that twinkle and drift."),
	paint("Rainbow", "legendary", 300000000, "rainbow", {
		rgb(255, 60, 70),
		rgb(255, 170, 30),
		rgb(255, 236, 60),
		rgb(70, 220, 110),
		rgb(60, 150, 255),
		rgb(170, 90, 255),
	}, "Every colour of the rainbow, cycling.", { cycle = 4 }),
	paint(
		"Sparkle",
		"legendary",
		800000000,
		"sparkle",
		{ rgb(255, 120, 210), rgb(255, 255, 255) },
		"Glitter that twinkles."
	),
	paint(
		"Chrome Mirror",
		"legendary",
		2000000000,
		"chrome",
		{ rgb(235, 240, 250) },
		"Bright chrome with hard highlights."
	),
	-- ROBUX (3): never on sale while the product price is unknown
	paint("Holographic", "robux", 0, "holo", {
		rgb(120, 255, 240),
		rgb(255, 140, 250),
		rgb(255, 250, 160),
	}, "A shimmering hologram finish.", { robux = 149, cycle = 3 }),
	paint(
		"Molten Gold",
		"robux",
		0,
		"molten",
		{ rgb(140, 70, 0), rgb(255, 200, 40), rgb(255, 250, 200) },
		"Liquid gold, glowing.",
		{
			robux = 199,
			cycle = 5,
		}
	),
	paint(
		"Electric",
		"robux",
		0,
		"electric",
		{ rgb(20, 40, 120), rgb(80, 220, 255), rgb(255, 255, 255) },
		"Crackling electric blue.",
		{
			robux = 249,
		}
	),
	-- VIP (2): free with the VIP pass (decision 0042 item 12)
	paint(
		"VIP Royal",
		"vip",
		0,
		"pearl",
		{ rgb(90, 30, 160), rgb(255, 210, 90) },
		"VIP PASS: royal purple with gold shine.",
		{
			vip = true,
		}
	),
	paint("VIP Neon", "vip", 0, "pulse", { rgb(255, 196, 40), rgb(170, 60, 255) }, "VIP PASS: gold and purple glow.", {
		vip = true,
	}),
}

-- DECALS (20 plus "No decal") --------------------------------------------------------------------------------------------------
-- Round 7 (C-04): drawn by the game (CarStyle's decal art), mirrored on both sides of the body. `key` names the design.

local function decal(name: string, tierId: string, price: number, key: string, colours: { Color3 }, note: string): Item
	return {
		id = slug(name),
		name = name,
		tab = "Decals",
		tier = tierId,
		price = price,
		key = key,
		colours = colours,
		render = "car",
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
		tier = "simple",
		price = 0,
		colours = { rgb(150, 160, 190) },
		render = "car",
		note = "Clears the decal.",
		isNone = true,
	},
	-- SIMPLE (8): $500 to $5K
	decal("Racing Stripe", "simple", 500, "stripe", { WHITE }, "One wide stripe down each side."),
	decal("Twin Stripes", "simple", 800, "twin", { WHITE, RED }, "Two stripes, nose to tail."),
	decal("Pinstripe", "simple", 1200, "pin", { GOLD }, "A thin gold line along each side."),
	decal("Checkers", "simple", 1800, "checkers", { WHITE, INK }, "A chequered band on each side."),
	decal("Number 7", "simple", 2500, "seven", { WHITE, INK }, "A race number on each door."),
	decal("Number 23", "simple", 3000, "twentythree", { GOLD, INK }, "Another race number on each door."),
	decal("Stars", "simple", 4000, "stars", { WHITE }, "Stars along each side."),
	decal("Polka Dots", "simple", 5000, "dots", { WHITE }, "Big friendly dots."),
	-- STREET (8): $10K to $2M
	decal("Flames", "street", 25000, "flames", { RED, ORANGE, GOLD }, "Hot-rod flames off the nose."),
	decal("Lightning Bolt", "street", 50000, "lightning", { CYAN, WHITE }, "A bolt down each side."),
	decal("Wings", "street", 100000, "wings", { GOLD, WHITE }, "Wings on each door."),
	decal("Swoosh", "street", 200000, "swoosh", { CYAN, rgb(60, 110, 255) }, "Two sweeping curves."),
	decal("Paint Splatter", "street", 400000, "splatter", { RED, GOLD, CYAN }, "Splashes of every colour."),
	decal("Circuit Lines", "street", 700000, "circuit", { rgb(90, 255, 160) }, "Glowing circuit-board lines."),
	decal("Shark Grin", "street", 1200000, "shark", { WHITE, RED }, "A friendly grin on the nose."),
	decal("Speed Chevrons", "street", 2000000, "chevrons", { GOLD }, "Arrows pointing forward."),
	-- ANIMATED (4): $5M to $100M (the pattern really moves: its texture scrolls or its glow pulses)
	decal(
		"Shimmer Flames",
		"animated",
		8000000,
		"flames",
		{ rgb(255, 60, 20), GOLD, rgb(255, 255, 200) },
		"Flames that flicker and run."
	),
	decal("Pulse Bolt", "animated", 20000000, "lightning", { CYAN, WHITE }, "A lightning bolt that pulses."),
	decal(
		"Chevron Run",
		"animated",
		45000000,
		"chevrons",
		{ rgb(255, 80, 200), GOLD },
		"Chevrons that scroll forward."
	),
	decal(
		"Rainbow Stripe",
		"animated",
		100000000,
		"stripe",
		{ rgb(255, 60, 70), rgb(60, 150, 255) },
		"A stripe cycling every colour."
	),
}

-- WHEELS (17) ---------------------------------------------------------------------------------------------------------------------
-- Round 8 (W-01, W-05): the sixteen rim designs of R8-IMG-17 plus the car's own Stock Five. `design` names the 3D rim in
-- Style/WheelKit.luau (and its meshes in Style/AssetIds/Wheels.luau). `key` and `kind` are the Round 7 rim mesh and style words,
-- kept so RealCar's older wheel code still has something to draw until every caller goes through the WheelKit. A renamed design
-- KEEPS its Round 7 `id` (a player's saved Owned and Equipped values still match); a design whose id is gone is listed in
-- CosmeticPreviewCatalog.Legacy and resolves to the nearest new design.
-- PREVIEW price ladder, cheaper plain, pricier flashy: STREET $1.5K to $8K, TRACK $20K to $120K, ELITE $300K to $1.5M, SHOWPIECE
-- $4M and $10M, ANIMATED (glowing or moving rims) $25M to $75M. No Robux wheels (none were Robux in Round 7).

local function wheel(
	name: string,
	tierId: string,
	price: number,
	design: string,
	key: string,
	colours: { Color3 },
	note: string,
	style: string?,
	keepId: string?
): Item
	return {
		id = keepId or slug(name),
		name = name,
		tab = "Wheels",
		tier = tierId,
		price = price,
		design = design,
		key = key,
		kind = style :: any,
		colours = colours,
		render = "car",
		note = note,
	}
end

local STEEL = rgb(200, 206, 222)
local DARK = rgb(44, 48, 66)

local wheels: { Item } = {
	wheel("Stock Five", "stock", 0, "stock_five", "five", { STEEL, DARK }, "The car's own wheels."),
	-- STREET
	wheel("Split Five", "street", 1500, "split_five", "split", { STEEL, DARK }, "Five paired silver spokes."),
	wheel("Star Spoke", "street", 4000, "star_spoke", "star", { rgb(226, 230, 240), DARK }, "Five broad star spokes."),
	wheel(
		"White Wall",
		"street",
		8000,
		"white_wall",
		"disc",
		{ WHITE, DARK },
		"A chrome moon cap and white-wall tyres.",
		"whitewall"
	),
	-- TRACK
	wheel("Multi-Spoke", "track", 20000, "multi_spoke", "ten", { STEEL, DARK }, "Ten thin spokes with a polished lip."),
	wheel(
		"Mesh",
		"track",
		50000,
		"mesh",
		"y",
		{ rgb(230, 234, 246), DARK },
		"A fine criss-cross mesh with rivets.",
		nil,
		"mesh_lace"
	),
	wheel(
		"Stripe Tyre",
		"track",
		120000,
		"stripe_tyre",
		"split",
		{ STEEL, RED },
		"A red stripe round the tyre.",
		"stripe",
		"stripe_racer"
	),
	-- ELITE
	wheel("Deep Dish", "elite", 300000, "deep_dish", "deep", { STEEL, DARK }, "A deep polished dish with bolts."),
	wheel("Turbine", "elite", 700000, "turbine", "turbine", { STEEL, DARK }, "Twelve swept turbine blades."),
	wheel("Carbon", "elite", 1500000, "carbon", "twin", { rgb(40, 42, 50), DARK }, "Woven carbon spokes.", "carbon"),
	-- SHOWPIECE
	wheel(
		"Chrome Mirror",
		"showpiece",
		4000000,
		"chrome_mirror",
		"disc",
		{ rgb(240, 244, 255), DARK },
		"Mirror-bright chrome blades.",
		"chrome",
		"chrome_disc"
	),
	wheel(
		"Gold Crown",
		"showpiece",
		10000000,
		"gold_crown",
		"star",
		{ rgb(255, 204, 60), DARK },
		"A solid gold crown with ball tips.",
		"gold",
		"gold_star"
	),
	-- ANIMATED (glowing or moving rims)
	wheel(
		"Neon Ring",
		"animated",
		25000000,
		"neon_ring",
		"five",
		{ STEEL, CYAN },
		"A glowing ring in the rim that slowly pulses.",
		"neonring"
	),
	wheel(
		"Glowing Hub",
		"animated",
		35000000,
		"glowing_hub",
		"turbine",
		{ STEEL, CYAN },
		"A glowing hub that slowly pulses.",
		"glowhub",
		"glow_hub"
	),
	wheel(
		"Glowing Tread",
		"animated",
		50000000,
		"glowing_tread",
		"five",
		{ STEEL, CYAN },
		"Glowing tread lines on the tyre.",
		"glowtread"
	),
	wheel(
		"Flame Spoke",
		"animated",
		60000000,
		"flame_spoke",
		"star",
		{ rgb(255, 120, 30), DARK },
		"Eight flame blades that flicker.",
		"flame"
	),
	wheel(
		"Galaxy Disc",
		"animated",
		75000000,
		"galaxy_disc",
		"disc",
		{ rgb(120, 60, 230), DARK },
		"A swirling galaxy with drifting stars.",
		"galaxy"
	),
}

-- TRAILS (12 plus VIP, plus "No trail") ------------------------------------------------------------------------------------------
-- Round 7 (C-06): each a layered effect from two exhaust points (CarStyle's TrailFx): a hot core, a body, breakup particles and a
-- fading tail. Cosmetic only: a trail never changes Heat, Keys, Stamina or a race. The four Robux trails of earlier decisions stay.

local function trail(
	name: string,
	tierId: string,
	cash: number,
	robux: number?,
	key: string,
	colours: { Color3 },
	note: string,
	vip: boolean?
): Item
	return {
		id = slug(name),
		name = name,
		tab = "Trails",
		tier = tierId,
		price = cash,
		robux = robux,
		vip = vip,
		key = key,
		colours = colours,
		render = "car",
		note = note,
	}
end

local trails: { Item } = {
	{
		id = "no_trail",
		name = "No trail",
		tab = "Trails",
		tier = "street",
		price = 0,
		colours = { rgb(150, 160, 190) },
		render = "car",
		note = "No trail behind your car.",
		isNone = true,
	},
	trail(
		"Bubble Pop",
		"street",
		5000,
		nil,
		"bubble",
		{ rgb(150, 230, 255), rgb(255, 170, 230) },
		"Bubbles that pop into stars."
	),
	trail(
		"Pixel Blast",
		"street",
		20000,
		nil,
		"pixel",
		{ rgb(255, 60, 120), rgb(60, 220, 255), rgb(255, 230, 60) },
		"Arcade squares."
	),
	trail(
		"Neon Ribbon",
		"street",
		60000,
		nil,
		"neon",
		{ rgb(70, 240, 255), rgb(255, 70, 220) },
		"Two ribbons of light twisting."
	),
	trail(
		"Frost Bite",
		"track",
		250000,
		nil,
		"frost",
		{ rgb(200, 240, 255), rgb(120, 200, 255) },
		"Ice crystals and cold mist."
	),
	trail(
		"Toxic Slime",
		"track",
		900000,
		nil,
		"slime",
		{ rgb(120, 255, 60), rgb(30, 160, 40) },
		"Green goo and glowing bubbles."
	),
	trail(
		"Lightning",
		"track",
		3000000,
		nil,
		"lightning",
		{ rgb(120, 200, 255), rgb(255, 255, 255) },
		"Crackling bolts to the road."
	),
	trail(
		"Galaxy",
		"elite",
		12000000,
		nil,
		"galaxy",
		{ rgb(120, 70, 255), rgb(255, 90, 220), rgb(100, 220, 255) },
		"Stars in a nebula."
	),
	trail(
		"Golden Glory",
		"elite",
		60000000,
		nil,
		"gold",
		{ rgb(255, 210, 60), rgb(255, 250, 200) },
		"Gold sparks and coins."
	),
	-- the four Robux trails (earlier decisions): never on sale while the product price is unknown
	trail("Flame Rush", "robux", 0, 99, "flame", { rgb(255, 210, 60), rgb(240, 50, 20) }, "Flames, embers and sparks."),
	trail(
		"Confetti Party",
		"robux",
		0,
		129,
		"confetti",
		{ rgb(255, 80, 150), rgb(70, 220, 255), rgb(255, 214, 40) },
		"Confetti and streamers."
	),
	trail("Rainbow Runway", "robux", 0, 199, "rainbow", {
		rgb(255, 60, 70),
		rgb(255, 170, 30),
		rgb(255, 236, 60),
		rgb(70, 220, 110),
		rgb(60, 150, 255),
		rgb(170, 90, 255),
	}, "A rainbow ribbon on the road, with sparkles."),
	trail(
		"Comet Tail",
		"robux",
		0,
		249,
		"comet",
		{ rgb(180, 230, 255), rgb(90, 140, 255) },
		"A glowing head and a long tail of light."
	),
	-- VIP (decision 0042 item 12)
	trail(
		"VIP Gradient",
		"vip",
		0,
		nil,
		"vip",
		{ rgb(255, 196, 40), rgb(170, 60, 255) },
		"VIP PASS: a gold-to-purple ribbon.",
		true
	),
}

CosmeticPreviewCatalog.Items = table.freeze({
	Paint = table.freeze(paints),
	Decals = table.freeze(decals),
	Wheels = table.freeze(wheels),
	Trails = table.freeze(trails),
} :: { [string]: { Item } })

-- QUERIES ------------------------------------------------------------------------------------------------------------------------

function CosmeticPreviewCatalog.itemsFor(tab: TabId): { Item }
	return CosmeticPreviewCatalog.Items[tab]
end

-- Round 8 (W-05): ids that no longer exist in a tab, and the item that replaced them (a saved Equipped or Owned value keeps working).
CosmeticPreviewCatalog.Legacy = table.freeze({
	Wheels = table.freeze({ rally_block = "star_spoke" }),
} :: { [string]: { [string]: string } })

function CosmeticPreviewCatalog.byId(tab: TabId, id: string): Item?
	for _, item in CosmeticPreviewCatalog.Items[tab] do
		if item.id == id then
			return item
		end
	end
	local legacy = CosmeticPreviewCatalog.Legacy[tab]
	local now = legacy and legacy[id]
	if now then
		for _, item in CosmeticPreviewCatalog.Items[tab] do
			if item.id == now then
				return item
			end
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

-- 33 / 14 / 10 / 9 (the "No decal" and "No trail" entries are not items)
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

export type Equipped = { Paint: string, Decals: string, Wheels: string, Trails: string }

-- PREVIEW Cash the screen starts with (a fixture balance, never the player's real Cash).
CosmeticPreviewCatalog.DefaultBalance = 5000

function CosmeticPreviewCatalog.defaultOwnership(): Ownership
	return {
		owned = {}, -- Round 7: the server sends what this player owns (BetaStyle)
		medals = { bronze = true, silver = false, gold = false },
		unavailable = {},
	}
end

function CosmeticPreviewCatalog.defaultEquipped(): Equipped
	return { Paint = "factory_paint", Decals = "none", Wheels = "stock_five", Trails = "no_trail" }
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
	-- Round 7: a VIP item is owned only while the server says so (the VIP pass); otherwise it is locked
	if item.vip then
		return if ownership.owned[item.id] then "owned" else "locked"
	end
	if (item.price == 0 and item.robux == nil) or ownership.owned[item.id] then
		return "owned"
	end
	local medal = item.medal
	if medal and not ownership.medals[medal] then
		return "locked"
	end
	return "priced"
end

return CosmeticPreviewCatalog
