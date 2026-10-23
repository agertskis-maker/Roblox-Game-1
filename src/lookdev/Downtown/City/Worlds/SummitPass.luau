--!strict
-- SUMMIT PASS (World 3; Lane 3 preview, Round 2, R2-SP1). Data only: five original districts on the shared road template
-- (vault/design/car-hop-outline-v2.md World 3: snowy mountain, pine, ice and a lodge at the top). Every name, sign and shape is
-- original and fictional. Lengths are explicit and unequal (fixture values for Lane 1 to accept or change).
--
-- Tier A (must appear in a chase): the chalet cluster (Pine Village), the ski lift (Ski Lift Ridge), the frozen lake and its
-- skaters, the glacier tunnel (a bridge-style span, opaque sculpted ice), the summit lodge, the observatory and the snowmen.
-- Pines, snowbanks and rock walls are roadside lots. Tier B (a labelled kit gallery, never planned): the festival stage and the
-- sledding hill. Hazards stay the planner's scenery previews (frost crack, ice patch, snowbank / plow debris); a collapsed-ice
-- GAP exists only in a marked hazard test area, never in this route.

local Make = require(script.Parent.Make)

local rgb = Color3.fromRGB
local palette, lot, landmark = Make.palette, Make.lot, Make.landmark

local SNOW = rgb(238, 244, 250)
local ICE = rgb(176, 214, 238)
local ICE_DEEP = rgb(118, 168, 208)
local WOOD = rgb(150, 98, 66)
local WOOD_DARK = rgb(104, 68, 50)
local PINE = rgb(52, 112, 84)
local RED = rgb(204, 72, 66)
local GOLD = rgb(242, 190, 78)
local SLATE = rgb(110, 124, 146)
local CREAM = rgb(250, 242, 226)

local ALL = { "PineVillage", "SkiLiftRidge", "FrozenLake", "GlacierTunnel", "SummitLodge" }

return {
	id = "SummitPass",
	name = "Summit Pass",
	colour = rgb(150, 130, 255),
	prefix = "SP_",
	paletteColumn = "SU",
	ground = rgb(236, 243, 250),
	-- asked of the planner: it finishes the district it is in, so five districts (about 3,150 studs) end the route
	length = 3000,
	landmarkSpacing = { 300, 440 },
	lighting = {
		props = {
			ClockTime = 10.6,
			Brightness = 2.3,
			Ambient = rgb(104, 118, 146),
			OutdoorAmbient = rgb(142, 158, 186),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 0.6,
			ExposureCompensation = 0.1,
			GlobalShadows = true,
			ShadowSoftness = 0.3,
			GeographicLatitude = 46,
			ColorShift_Top = rgb(228, 238, 255),
			ColorShift_Bottom = Color3.new(0, 0, 0),
		},
		atmosphere = {
			density = 0.26,
			offset = 0.18,
			colour = rgb(206, 222, 244),
			decay = rgb(150, 170, 206),
			haze = 1.2,
		},
		grade = { brightness = 0.02, contrast = 0.06, saturation = 0.06, tint = rgb(238, 244, 255) },
	},
	districts = {
		{
			id = "PineVillage",
			name = "Pine Village",
			order = 1,
			target = 648,
			palettes = {
				palette("PV-wood", WOOD, CREAM, RED, rgb(224, 232, 242)),
				palette("PV-dark", WOOD_DARK, CREAM, GOLD, rgb(214, 224, 238)),
				palette("PV-cream", CREAM, WOOD, PINE, rgb(206, 218, 234)),
			},
			heights = { low = 8, mid = 1, tall = 0 },
			finishes = { "wood", "cream" },
			intersections = 0,
			curves = 1,
			bridge = false,
			signature = "ChaletCluster",
			landmarks = { "ChaletCluster", "BellTower" },
			furniture = { "pine", "snowman", "fencePost", "pine", "barrel" },
			treatmentEvery = { 5, 8 },
			parkBias = 0.6,
			midHeight = { 28, 56 },
			skyHeight = { 100, 170 },
			signs = true,
			bunting = false,
			welcome = "WELCOME TO SUMMIT PASS",
			cart = false,
		},
		{
			id = "SkiLiftRidge",
			name = "Ski Lift Ridge",
			order = 2,
			target = 600,
			palettes = {
				palette("SL-snow", SNOW, SLATE, RED, rgb(200, 214, 232)),
				palette("SL-blue", ICE, SLATE, GOLD, rgb(200, 214, 232)),
				palette("SL-wood", WOOD, CREAM, RED, rgb(224, 232, 242)),
			},
			heights = { low = 6, mid = 3, tall = 0 },
			finishes = { "snow", "wood" },
			intersections = 0,
			curves = 2,
			bridge = false,
			signature = "SkiLift",
			landmarks = { "SkiLift", "WarmingHut" },
			furniture = { "pine", "fencePost", "pine", "rock", "snowman" },
			treatmentEvery = { 5, 8 },
			parkBias = 0.7,
			midHeight = { 48, 100 },
			skyHeight = { 120, 200 },
			signs = true,
			bunting = false,
			cart = false,
		},
		{
			id = "FrozenLake",
			name = "Frozen Lake",
			order = 3,
			target = 672,
			palettes = {
				palette("FL-ice", ICE, SNOW, RED, rgb(200, 214, 232)),
				palette("FL-deep", ICE_DEEP, SNOW, GOLD, rgb(190, 206, 228)),
				palette("FL-snow", SNOW, ICE_DEEP, RED, rgb(200, 214, 232)),
			},
			heights = { low = 7, mid = 2, tall = 0 },
			finishes = { "ice", "snow" },
			intersections = 0,
			curves = 1,
			bridge = false,
			signature = "FrozenLake",
			landmarks = { "FrozenLake", "SkateHut" },
			furniture = { "pine", "snowman", "rock", "barrel" },
			treatmentEvery = { 6, 9 },
			parkBias = 0.8,
			midHeight = { 40, 84 },
			skyHeight = { 120, 200 },
			signs = false,
			bunting = false,
			cart = false,
		},
		{
			id = "GlacierTunnel",
			name = "Glacier Tunnel",
			order = 4,
			target = 576,
			palettes = {
				palette("GT-ice", ICE, SNOW, GOLD, ICE_DEEP),
				palette("GT-deep", ICE_DEEP, SNOW, GOLD, rgb(90, 140, 186)),
				palette("GT-snow", SNOW, ICE_DEEP, RED, rgb(200, 214, 232)),
			},
			heights = { low = 2, mid = 6, tall = 0 },
			finishes = { "ice", "deep" },
			intersections = 0,
			curves = 0,
			bridge = true,
			signature = "GlacierTunnel",
			landmarks = { "GlacierTunnel" },
			furniture = { "rock", "pine", "fencePost" },
			treatmentEvery = { 6, 9 },
			parkBias = 0.8,
			midHeight = { 56, 110 },
			skyHeight = { 130, 210 },
			signs = false,
			bunting = false,
			cart = false,
		},
		{
			id = "SummitLodge",
			name = "Summit Lodge",
			order = 5,
			target = 680,
			palettes = {
				palette("SM-lodge", WOOD, CREAM, GOLD, rgb(224, 232, 242)),
				palette("SM-stone", SLATE, CREAM, GOLD, rgb(214, 224, 238)),
				palette("SM-snow", SNOW, WOOD, RED, rgb(206, 218, 234)),
			},
			heights = { low = 6, mid = 3, tall = 0 },
			finishes = { "wood", "stone" },
			intersections = 0,
			curves = 2,
			bridge = false,
			signature = "SummitLodge",
			landmarks = { "SummitLodge", "Observatory", "SnowmenRow" },
			required = { "Observatory", "SnowmenRow" },
			furniture = { "snowman", "pine", "fencePost", "barrel", "pine" },
			treatmentEvery = { 5, 8 },
			parkBias = 0.6,
			midHeight = { 48, 100 },
			skyHeight = { 130, 210 },
			signs = true,
			bunting = false,
			cart = false,
		},
	},
	lots = {
		lot(
			"SP_Lot_Chalet24_a",
			"building",
			24,
			22,
			16,
			"low",
			"chalet",
			{ "PineVillage", "SkiLiftRidge", "SummitLodge" },
			false
		),
		lot(
			"SP_Lot_Chalet36_b",
			"building",
			36,
			22,
			18,
			"low",
			"chalet",
			{ "PineVillage", "SkiLiftRidge", "SummitLodge" },
			false
		),
		lot(
			"SP_Lot_Cabin24_a",
			"building",
			24,
			20,
			12,
			"low",
			"cabin",
			{ "PineVillage", "FrozenLake", "SummitLodge" },
			false
		),
		lot("SP_Lot_Cafe36_a", "building", 36, 22, 16, "low", "cafe", { "PineVillage", "SkiLiftRidge" }, true),
		lot("SP_Lot_Shop24_a", "building", 24, 20, 14, "low", "shop", { "PineVillage", "SummitLodge" }, true),
		lot("SP_Lot_Lodge48_a", "building", 48, 24, 20, "low", "lodge", { "PineVillage", "SummitLodge" }, true),
		lot("SP_Lot_Pines36_a", "building", 36, 22, 24, "low", "pine", ALL, false),
		lot("SP_Lot_Pines24_b", "building", 24, 20, 20, "low", "pine", ALL, false),
		lot("SP_Lot_Bank36_a", "building", 36, 20, 8, "low", "snowbank", ALL, false),
		lot("SP_Lot_Bank24_b", "building", 24, 20, 7, "low", "snowbank", ALL, false),
		lot(
			"SP_Lot_Rocks36_a",
			"building",
			36,
			22,
			14,
			"low",
			"rock",
			{ "SkiLiftRidge", "GlacierTunnel", "SummitLodge" },
			false
		),
		lot("SP_Lot_Shed36_a", "building", 36, 22, 14, "low", "liftshed", { "SkiLiftRidge" }, false),
		lot("SP_Lot_Ice24_a", "building", 24, 20, 8, "low", "ice", { "FrozenLake", "GlacierTunnel" }, false),
		lot("SP_Lot_Ice36_b", "building", 36, 22, 10, "low", "ice", { "FrozenLake", "GlacierTunnel" }, false),
		lot("SP_Lot_Pier36_a", "building", 36, 22, 10, "low", "pier", { "FrozenLake" }, false),
		lot(
			"SP_Lot_Peak36_a",
			"building",
			36,
			24,
			40,
			"mid",
			"peak",
			{ "SkiLiftRidge", "FrozenLake", "SummitLodge" },
			false
		),
		lot(
			"SP_Lot_Peak48_b",
			"building",
			48,
			24,
			48,
			"mid",
			"peak",
			{ "SkiLiftRidge", "GlacierTunnel", "SummitLodge" },
			false
		),
		lot("SP_Lot_Crag24_a", "building", 24, 22, 34, "mid", "peak", { "SkiLiftRidge", "GlacierTunnel" }, false),
		lot("SP_Lot_Serac36_a", "building", 36, 24, 36, "mid", "ice", { "GlacierTunnel", "FrozenLake" }, false),
		lot("SP_Lot_Serac48_b", "building", 48, 24, 44, "mid", "ice", { "GlacierTunnel" }, false),
		lot("SP_Lot_Snowfield24", "park", 24, 24, 12, "low", "snowfield", ALL, false),
		lot("SP_Lot_Snowfield36", "park", 36, 24, 12, "low", "snowfield", ALL, false),
		lot(
			"SP_Lot_Firepit36_a",
			"courtyard",
			36,
			24,
			12,
			"mid",
			"firepit",
			{ "PineVillage", "SkiLiftRidge", "SummitLodge" },
			false
		),
	},
	landmarks = {
		landmark(
			"ChaletCluster",
			"SP_LM_ChaletCluster",
			"PINE VILLAGE CHALETS",
			60,
			26,
			28,
			{ "PineVillage" },
			"frontage"
		),
		landmark("BellTower", "SP_LM_BellTower", "VILLAGE BELL TOWER", 28, 28, 52, { "PineVillage" }, "frontage"),
		landmark("SkiLift", "SP_LM_SkiLift", "RIDGE SKI LIFT", 60, 24, 44, { "SkiLiftRidge" }, "frontage"),
		landmark("WarmingHut", "SP_LM_WarmingHut", "COCOA WARMING HUT", 36, 24, 18, { "SkiLiftRidge" }, "frontage"),
		landmark("FrozenLake", "SP_LM_FrozenLake", "SKATERS' FROZEN LAKE", 72, 40, 10, { "FrozenLake" }, "frontage"),
		landmark("SkateHut", "SP_LM_SkateHut", "SKATE RENTAL HUT", 36, 22, 16, { "FrozenLake" }, "frontage"),
		landmark(
			"GlacierTunnel",
			"SP_LM_GlacierTunnel384",
			"GLACIER TUNNEL",
			384,
			0,
			44,
			{ "GlacierTunnel" },
			"bridge"
		),
		landmark("SummitLodge", "SP_LM_SummitLodge", "SUMMIT LODGE", 72, 30, 40, { "SummitLodge" }, "frontage"),
		landmark("Observatory", "SP_LM_Observatory", "STAR OBSERVATORY", 36, 30, 46, { "SummitLodge" }, "frontage"),
		landmark("SnowmenRow", "SP_LM_SnowmenRow", "SNOWMAN ROW", 48, 20, 14, { "SummitLodge" }, "frontage"),
		-- tier B: the labelled kit gallery only (no district lists them, so the planner never places them)
		landmark("FestivalStage", "SP_LM_FestivalStage", "WINTER FESTIVAL STAGE", 60, 28, 22, {}, "frontage"),
		landmark("SledHill", "SP_LM_SledHill", "SLED HILL", 60, 36, 20, {}, "frontage"),
	},
	props = {
		lamp = "SP_Prop_Pole",
		bridgeLamp = "SP_Prop_Pole",
		busStop = "SP_Prop_BusShelter",
		pine = "SP_Prop_Pine",
		rock = "SP_Prop_Rock",
		snowman = "SP_Prop_Snowman",
		barrel = "SP_Prop_Barrel",
		fencePost = "SP_Prop_FencePost",
		tree = "SP_Prop_Pine",
		bench = "SP_Prop_Barrel",
		bin = "SP_Prop_Barrel",
	},
	signs = {
		"COCOA CORNER",
		"SNOWFLAKE SKIS",
		"PINE CONE CAFE",
		"MITTEN MARKET",
		"FROSTY FUEL",
		"WARM WAFFLES",
		"SLED AND BREAKFAST",
		"BOOT DRYER INN",
		"ICICLE ICE CREAM",
		"SUMMIT SNACKS",
		"TOBOGGAN TOYS",
		"HOT SOUP STOP",
	},
	midMeshes = {
		PineVillage = { "SP_Mid_Slope_1", "SP_Mid_Slope_2" },
		SkiLiftRidge = { "SP_Mid_Peak_1", "SP_Mid_Slope_2" },
		FrozenLake = { "SP_Mid_Slope_1", "SP_Mid_Peak_2" },
		GlacierTunnel = { "SP_Mid_Glacier_1", "SP_Mid_Peak_2" },
		SummitLodge = { "SP_Mid_Peak_1", "SP_Mid_Peak_2", "SP_Mid_Slope_1" },
	},
	skyMeshes = { "SP_Sky_Peak_1", "SP_Sky_Peak_2", "SP_Sky_Peak_3", "SP_Sky_Ridge_1", "SP_Sky_Ridge_2", "SP_Sky_Horn" },
	-- planner hazard kind -> kit mesh: a frost crack, an ice patch and a snowbank with plow debris stand in for pothole /
	-- oil / construction
	hazardMeshes = {
		pothole = "SP_Haz_FrostCrack",
		oil = "SP_Haz_IcePatch",
		construction = "SP_Haz_Snowbank",
	},
	under = { name = "IceCrevasse", colour = rgb(86, 138, 184) },
	tierA = { "ChaletCluster", "SkiLift", "FrozenLake", "GlacierTunnel", "SummitLodge", "Observatory", "SnowmenRow" },
	-- (BellTower, WarmingHut and SkateHut are supporting landmarks: planned when they fit, not required)
	tierB = { "FestivalStage", "SledHill" },
}
