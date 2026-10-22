--!strict
-- Uploaded island environment assets (Lane 3). Every id here was uploaded for the island rework
-- under Adam's Roblox account peskaface (user 2393473976), authorised for Task 2 on 2026-10-21.
-- Sources and recipes: assets/island/kit/ (recipes in Git) and Car-Hop-Art/island-kit/ (art
-- outside Git). Full table with sizes, states and load checks: assets/island/kit/manifest.md.

local AssetIds = {}

local function id(n: number): string
	return "rbxassetid://" .. n
end

-- Effect textures (assets/island/kit/textures.js), uploaded 2026-10-21 through the Studio MCP.
AssetIds.Textures = {
	WaterBody = id(118829614143752),
	WaterStrandsFast = id(123432307138321),
	WaterStrandsSlow = id(80338760305637),
	WaterHighlights = id(111578838235188),
	WaterSpray = id(91396665960467),
	FoamTile = id(122795342152257),
	FoamPatch = id(99023600024403),
	Ripple = id(106407842749322),
	Droplet = id(109536997721772),
	Mist = id(114900109756669),
	Rainbow = id(72537598666370),
	Sparkle = id(87030054749344),
	Glow = id(109290330063558),
	Current = id(103576178978702),
	-- boost-lane chevron (textures.js chevron.png), uploaded 2026-10-21 (revision 2)
	-- (the first upload, 136467391577760, drew the chevron sideways on a beam; superseded)
	Chevron = id(96352143506498),
	-- Task 3 (2026-10-22): portal field layers and particles, track pennants and flag cloth
	PortalSwirlA = id(92093492199405),
	PortalSwirlB = id(108950429777685),
	PortalCloudTile = id(123976736191333),
	PortalCore = id(71006997459996),
	PortalVeil = id(80047315268792),
	PortalVeilB = id(122267435775183),
	PortalMask = id(112768234647366),
	PortalBeam = id(99849771860096),
	-- frameless field shapes (2026-10-22 review fix): soft oval depth and two cloudy bodies
	PortalDepth = id(77298104491687), -- v2 (smoother edge); v1 126970565337092 not referenced
	PortalCloudBall = id(98562926959140),
	PortalCloudBallB = id(85244900910059),
	PortalBand = id(90038845373360), -- the dark recess band inside the edge (review round 3)
	GroundPool = id(100675320642077),
	Mote = id(128577684526564),
	Ember = id(117732180184030),
	Shimmer = id(113969750355597),
	Pennants = id(129394675251472),
	FlagChecker = id(113814256495528),
	FlagStripesA = id(97908223611462),
	FlagStripesB = id(81318556896008),
	FlagStar = id(93044374349935),
}

-- Creator Store audio under test (Roblox's licensed partners; not owned by this project). Adam
-- listens before any of these counts as final (assets/island/kit/manifest.md).
AssetIds.Sounds = {
	PortalHum = id(9125674114), -- Metallic Glow Constant Deep Ticking Bassy Hum 2 (SFX), Pro Sound Effects
	PortalShimmer = id(9125602541), -- Heavenly Harmonic Presence Glowing Crystal Ringing 2 (SFX), Pro Sound Effects
	FallsLoop = id(9120552550), -- Waterfall Steady Stream 1 (SFX), Pro Sound Effects
	ParkBirds = id(9113444360), -- Birds Park 2 (SFX), Pro Sound Effects
	Quack = id(1845012569), -- Quack Duck, APM (63.05 s; one quack is played with a playback region)
} :: { [string]: string }

-- Sign art from the Figma mocks (Car Hop UI, page "Island signs"; specs in vault/design/ui:
-- island-signs, plot-track-signs, portal-sign), uploaded under peskaface 2026-10-22 through the
-- Studio MCP. Text that will be live (names, numbers) is a TextLabel over a text-free background.
-- Files: Car-Hop-Art/island-kit/textures/signs/. Two were not direct Figma renders (see the asset
-- manifest): BannerWobblebotToys (stitched from two exports) and Kiosk (drawn by kiosk.js).
AssetIds.SignArt = {
	HeaderHotDog = id(111209092984557),
	HeaderIceCream = id(131134583059892),
	HeaderLemonade = id(89775297450442),
	HeaderPopcorn = id(132673341754270),
	BannerA = id(121463232337129), -- ZOOPA FIZZ
	BannerB = id(110246953719901), -- CRUNCHKIN PUFFS
	BannerC = id(78479045044254), -- STICKYTOE TYRES
	BannerD = id(140634403555411), -- WOBBLEBOT TOYS
	OwnerBanner = id(103587041167945), -- background; the name is a TextLabel
	Nameplate = id(101228763400140), -- background; the name is a TextLabel
	Kiosk = id(137428624345478),
	IconPortal = id(101447318056634),
	IconGarage = id(139283194336735),
	IconStunt = id(136778609492666),
	IconPlots = id(92929508456128),
	IconLake = id(135234520936833),
	IconArrow = id(75221826934795),
	IconCoin = id(99492109262754),
	IconTick = id(103260929176535),
	IconLock = id(125248424108608),
	IconWrench = id(125308628941246),
} :: { [string]: string }

-- The kit palette (assets/island/kit/kitlib.py, 16 x 16 swatches), uploaded 2026-10-21.
-- revision 3 (2026-10-22): four swatches appended (steel, brass, coral, mint); earlier cells
-- unchanged, so every older mesh looks the same. The first palette was 112727480640146.
-- Task 4 (2026-10-22): the kit palette with the Task 4 swatches appended (cells 101 to 126; the
-- older cells are byte-identical to the previous upload, 84613406678497)
AssetIds.Palette = id(134121745235322)

-- Kit meshes (assets/island/kit/, KitManifest), by mesh name, uploaded 2026-10-21 through the 3D
-- Importer from island-kit.obj (Creator "Me"). The importer stores each mesh turned 180 degrees
-- about Y from the recipe frame; KitAssets turns uploaded meshes back. A mesh not listed here is
-- built as a session-only preview from its mesh data (KitAssets).
AssetIds.Meshes = {
	Arrowhead = id(77734052464842),
	BedOval = id(75182510100315),
	BedRound = id(78898513024992),
	Bench = id(81472931283188),
	BerryBush = id(113381535893436),
	BirchA_Canopy = id(95358946867963),
	BirchA_Trunk = id(113392689229837),
	BirchB_Canopy = id(76466785156402), -- revision 2 (was 97117102116709)
	BirchB_Trunk = id(71794440829829),
	BirchC_Canopy = id(77471118350791), -- revision 2 (was 134755746106792)
	BirchC_Trunk = id(107504512366800),
	BlossomA_Canopy = id(85623663058251),
	BlossomA_Trunk = id(71890708802809),
	BlossomB_Canopy = id(115945038397849),
	BlossomB_Trunk = id(116376114509074),
	BlossomC_Canopy = id(70583076825211),
	BlossomC_Trunk = id(70593040224453),
	BlueWildflowers = id(140362334076502),
	BoulderA = id(73936552182889),
	BoulderB = id(108729967021241),
	BoulderC = id(99527827208631),
	BridgeAvenue = id(132499975394188),
	BridgeAvenueOpen = id(78688525290880),
	BridgeGarden = id(119984148857166),
	BridgeLakeside = id(74401136745211),
	BuntingString = id(90642820165813),
	BushLarge = id(107937719458701),
	BushMedium = id(112084388357819),
	BushSmall = id(89066567685874),
	ButterflyBlueWingL = id(84463884097172),
	ButterflyBlueWingR = id(96381297933560),
	ButterflyBody = id(83296309836118),
	ButterflyWingL = id(110344634719101),
	ButterflyWingR = id(77372830185761),
	CarTopiary = id(124108261960990),
	Cattails = id(96641977331650),
	Clover = id(119625716970260),
	Daisies = id(72553714073439),
	Dock = id(121994894630420),
	DragonflyBody = id(116300255540446),
	DragonflyWings = id(96240530729511),
	Driftwood = id(79754565581073),
	Duck = id(82641503340866),
	Duckling = id(114222618214481),
	Duckweed = id(96016381404577),
	FenceSegment = id(75883738881066),
	FernA = id(125414860170513),
	FernB = id(132864443197145),
	FishOrange = id(93198247823924),
	FishSilver = id(74193987938908),
	FloatingLeaf = id(117142848195882),
	FloatingPetal = id(102542786153320),
	FloweringShrub = id(97158756624560),
	FountainTiered = id(87095967163960),
	FountainWater = id(116528389038986),
	Frog = id(124872657363209),
	FruitA_Canopy = id(91617448874937),
	FruitA_Trunk = id(125813419406213),
	FruitB_Canopy = id(82529345438206),
	FruitB_Trunk = id(77808359429337),
	FruitC_Canopy = id(110918401683196),
	FruitC_Trunk = id(138730259128149),
	Gazebo = id(132930457317667),
	GrassTuft = id(87769624057571),
	GrassTuftWide = id(85162093459834),
	HedgeLow = id(94290153677107),
	HedgeStraight = id(115214796420911),
	HollowLog = id(133502513071015),
	HotDogCart = id(128077008495216),
	IceCreamStand = id(72102386161007),
	Irises = id(124819745705979),
	LampGlass = id(120377499915257),
	LampPost = id(139674403634313),
	Lavender = id(130846919850597),
	LeafLitter = id(134131919266803),
	LemonadeStand = id(125464775917653),
	LilyFlowerPink = id(76891640080088),
	LilyFlowerWhite = id(82425262882452),
	LilyPadL = id(111100338080785),
	LilyPadM = id(92817792476653),
	LilyPadS = id(75828509671473),
	MossyRockA = id(116711716740489),
	MossyRockB = id(100088279100790),
	MushroomsBrown = id(72630651084382),
	MushroomsRed = id(132931914368107),
	OakA_Canopy = id(125079363526751),
	OakA_Trunk = id(81838596725252),
	OakB_Canopy = id(114513892252367),
	OakB_Trunk = id(133799468476153),
	OakC_Canopy = id(137935820165648),
	OakC_Trunk = id(72640563796108),
	PineA_Canopy = id(86571721057312),
	PineA_Trunk = id(126489468362585), -- revision 2 (was 82143832617173)
	PineB_Canopy = id(119200173785375),
	PineB_Trunk = id(91453775827473), -- revision 2 (was 89643406488268)
	PineC_Canopy = id(96071087065535),
	PineC_Trunk = id(113986667544582), -- revision 2 (was 126729994654224)
	PineSapling_Canopy = id(108593342174832),
	PineSapling_Trunk = id(125052020212163), -- revision 2 (was 108644319441252)
	PopcornCart = id(140620817482021),
	Poppies = id(134198513847375),
	Raccoon = id(78064153570396), -- revision 2 (was 70443242208452)
	RaccoonHead = id(122251191819978), -- revision 2 (was 133875827596835)
	Reeds = id(138621409272637),
	RosesPink = id(133767793962188),
	RosesRed = id(137302351764375),
	Rowboat = id(111594792382992),
	Rushes = id(94073208976012),
	Signpost = id(75373199680961),
	SteppingStone = id(114567733775797),
	Stump = id(97538794770552),
	Sunflowers = id(70924896477467),
	TallGrass = id(96033594782233),
	TieredA_Canopy = id(72964718415062),
	TieredA_Trunk = id(73674256532039),
	TieredB_Canopy = id(88044922593595),
	TieredB_Trunk = id(128171113138801),
	TieredC_Canopy = id(70677452623426),
	TieredC_Trunk = id(109536531531788),
	TopiaryBall = id(89575297387819),
	TopiaryCone = id(72356799315602),
	TulipsRed = id(125564876170957),
	TulipsYellow = id(98770109311258),
	UmbrellaA_Canopy = id(91847269200413), -- revision 2 (was 104256844178578)
	UmbrellaA_Trunk = id(133742908940135),
	UmbrellaB_Canopy = id(74855981514851),
	UmbrellaB_Trunk = id(101735978642638),
	UmbrellaC_Canopy = id(108564507264176),
	UmbrellaC_Trunk = id(109121511812165),
	WetRockA = id(99844062490263),
	WetRockB = id(115292109378113),
	WillowA_Canopy = id(100724359605792), -- revision 2 (was 95230078901958)
	WillowA_Trunk = id(95619268368185),
	WillowB_Canopy = id(117793886163427),
	WillowB_Trunk = id(78855509300039),
	WillowC_Canopy = id(117322934216935),
	WillowC_Trunk = id(94489845710982),
	-- new in revision 2 (2026-10-21, island-kit-rev2.obj)
	FountainGrand = id(138476226884315),
	FountainGrandWater = id(118135225656541),
	PlazaMosaic = id(92746874626451),
	-- new in Task 3 (2026-10-22, island-kit-task3.obj, imported by Adam; creator peskaface)
	ChainAnchorPost = id(114737667930382),
	ChainLink = id(99515412067221),
	Flagpole = id(82002796817463),
	HeaderBoard = id(89758117345462),
	KioskBooth = id(137774673874849),
	PadlockBody = id(114107687304189),
	PadlockShackle = id(97927780932934),
	PlotGate = id(83397197959185),
	PortalSign = id(75612522407601),
	SignpostBoard = id(128562147587889),
	SignpostPost = id(70440998829645),
} :: { [string]: string }

return AssetIds
