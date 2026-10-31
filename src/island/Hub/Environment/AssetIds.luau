--!strict
-- Uploaded island environment assets (Lane 3). On 2026-10-31 Adam re-imported every mesh, effect
-- texture, sign image and the palette below under the group LEGION STUDI0S (group 74306252) with
-- Studio's 3D Importer (Car-Hop-Art/upload-legion-island-2026-10-31; every id checked: group
-- creator, mesh sizes within 0.01 of KitManifest). The comments below give each asset's original
-- history; the earlier user-owned ids (peskaface) are listed in assets/island/kit/manifest.md.
-- Not re-imported (unused, still user-owned): SignArt BannerA to BannerD and Kiosk.
-- Sources and recipes: assets/island/kit/ (recipes in Git) and Car-Hop-Art/island-kit/ (art
-- outside Git). Full table with sizes, states and load checks: assets/island/kit/manifest.md.

local AssetIds = {}

local function id(n: number): string
	return "rbxassetid://" .. n
end

-- Effect textures (assets/island/kit/textures.js), uploaded 2026-10-21 through the Studio MCP.
AssetIds.Textures = {
	WaterBody = id(76448861868809),
	WaterStrandsFast = id(84198602448972),
	WaterStrandsSlow = id(126401069049014),
	WaterHighlights = id(126946943900205),
	WaterSpray = id(129096095057922),
	FoamTile = id(83639401265553),
	FoamPatch = id(133773604286652),
	Ripple = id(110000918142561),
	Droplet = id(104718015917348),
	Mist = id(100353530625667),
	Rainbow = id(92530769791430),
	Sparkle = id(124856660251107),
	Glow = id(104162855106857),
	Current = id(90799224483267),
	-- boost-lane chevron (textures.js chevron.png), uploaded 2026-10-21 (revision 2)
	-- (the first upload, 136467391577760, drew the chevron sideways on a beam; superseded)
	Chevron = id(131283501116373),
	-- Task 3 (2026-10-22): portal field layers and particles, track pennants and flag cloth
	PortalSwirlA = id(97184972304820),
	PortalSwirlB = id(121384250907605),
	PortalCloudTile = id(140374123745689),
	PortalCore = id(131487211688936),
	PortalVeil = id(133332175362123),
	PortalVeilB = id(106363486085507),
	PortalMask = id(132444414799690),
	PortalBeam = id(97082628992749),
	-- frameless field shapes (2026-10-22 review fix): soft oval depth and two cloudy bodies
	PortalDepth = id(122344255111090), -- v2 (smoother edge); v1 126970565337092 not referenced
	PortalCloudBall = id(102883150299572),
	PortalCloudBallB = id(134123364350479),
	PortalBand = id(95138204365042), -- the dark recess band inside the edge (review round 3)
	GroundPool = id(130753937124264),
	Mote = id(118165875852224),
	Ember = id(78738981505727),
	Shimmer = id(136941114758210),
	Pennants = id(109986080076934),
	FlagChecker = id(107933231350357),
	FlagStripesA = id(109705567230453),
	FlagStripesB = id(77641612149566),
	FlagStar = id(96696844387606),
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
	HeaderHotDog = id(125700113190099),
	HeaderIceCream = id(135153505969890),
	HeaderLemonade = id(108197480384893),
	HeaderPopcorn = id(107137808128779),
	BannerA = id(121463232337129), -- ZOOPA FIZZ
	BannerB = id(110246953719901), -- CRUNCHKIN PUFFS
	BannerC = id(78479045044254), -- STICKYTOE TYRES
	BannerD = id(140634403555411), -- WOBBLEBOT TOYS
	OwnerBanner = id(99028570616783), -- background; the name is a TextLabel
	Nameplate = id(121326877498191), -- background; the name is a TextLabel
	Kiosk = id(137428624345478),
	IconPortal = id(90391570744372),
	IconGarage = id(94562992202885),
	IconStunt = id(117013989776586),
	IconPlots = id(94122317601645),
	IconLake = id(120121071349820),
	IconArrow = id(121618950997210),
	IconCoin = id(83470451230913),
	IconTick = id(135235800672495),
	IconLock = id(133725466100857),
	IconWrench = id(92414956875461),
} :: { [string]: string }

-- The kit palette (assets/island/kit/kitlib.py, 16 x 16 swatches), uploaded 2026-10-21.
-- revision 3 (2026-10-22): four swatches appended (steel, brass, coral, mint); earlier cells
-- unchanged, so every older mesh looks the same. The first palette was 112727480640146.
-- Task 4 (2026-10-22): the kit palette with the Task 4 swatches appended (cells 101 to 126; the
-- older cells are byte-identical to the previous upload, 84613406678497)
AssetIds.Palette = id(128169045252325)

-- Kit meshes (assets/island/kit/, KitManifest), by mesh name, uploaded 2026-10-21 through the 3D
-- Importer from island-kit.obj (Creator "Me"). The importer stores each mesh turned 180 degrees
-- about Y from the recipe frame; KitAssets turns uploaded meshes back. A mesh not listed here is
-- built as a session-only preview from its mesh data (KitAssets).
AssetIds.Meshes = {
	Arrowhead = id(138244067049295),
	BedOval = id(136099171822469),
	BedRound = id(123249717980851),
	Bench = id(123517872546619),
	BerryBush = id(99914521306375),
	BirchA_Canopy = id(100806252422298),
	BirchA_Trunk = id(120487144662684),
	BirchB_Canopy = id(103662231513650), -- revision 2 (was 97117102116709)
	BirchB_Trunk = id(81836875055169),
	BirchC_Canopy = id(106621954448856), -- revision 2 (was 134755746106792)
	BirchC_Trunk = id(112381046500417),
	BlossomA_Canopy = id(91241113693387),
	BlossomA_Trunk = id(82673324179312),
	BlossomB_Canopy = id(91244754126777),
	BlossomB_Trunk = id(132557397556033),
	BlossomC_Canopy = id(71195676597725),
	BlossomC_Trunk = id(74838286273378),
	BlueWildflowers = id(74966194657570),
	BoulderA = id(123763171923437),
	BoulderB = id(97554163859875),
	BoulderC = id(135204461703163),
	BridgeAvenue = id(103746904933957),
	BridgeAvenueOpen = id(79961433123556),
	BridgeGarden = id(132052014907256),
	BridgeLakeside = id(80321789639417),
	BuntingString = id(137727498083978),
	BushLarge = id(96440781051500),
	BushMedium = id(84665955701915),
	BushSmall = id(131556303922904),
	ButterflyBlueWingL = id(103115458033263),
	ButterflyBlueWingR = id(102194139048182),
	ButterflyBody = id(121749629890653),
	ButterflyWingL = id(92790805942751),
	ButterflyWingR = id(111632244403294),
	CarTopiary = id(99765473953877),
	Cattails = id(78963979739123),
	Clover = id(130464549817210),
	Daisies = id(119049798406520),
	Dock = id(123866895240112),
	DragonflyBody = id(96562316547990),
	DragonflyWings = id(122096696191279),
	Driftwood = id(137946365287756),
	Duck = id(99537883114657),
	Duckling = id(135443294412364),
	Duckweed = id(79018509318981),
	FenceSegment = id(103954822123918),
	FernA = id(105557009091999),
	FernB = id(106862977771018),
	FishOrange = id(85267243082735),
	FishSilver = id(98519047787114),
	FloatingLeaf = id(124766280568815),
	FloatingPetal = id(82754658171119),
	FloweringShrub = id(134148931332873),
	FountainTiered = id(131932970374170),
	FountainWater = id(79696989097258),
	Frog = id(83838167593408),
	FruitA_Canopy = id(138914998198618),
	FruitA_Trunk = id(75236867446405),
	FruitB_Canopy = id(108283244964258),
	FruitB_Trunk = id(132892254460984),
	FruitC_Canopy = id(126003894759778),
	FruitC_Trunk = id(107940472242898),
	Gazebo = id(133055578432871),
	GrassTuft = id(108426784312972),
	GrassTuftWide = id(107798705738594),
	HedgeLow = id(136175074613591),
	HedgeStraight = id(112315738239450),
	HollowLog = id(100906492502147),
	HotDogCart = id(118492261494970),
	IceCreamStand = id(138353957710700),
	Irises = id(76723241488075),
	LampGlass = id(76899708162034),
	LampPost = id(125125452765458),
	Lavender = id(76906490732445),
	LeafLitter = id(129518020398457),
	LemonadeStand = id(76858034399256),
	LilyFlowerPink = id(102119291559534),
	LilyFlowerWhite = id(129707095646286),
	LilyPadL = id(132427788258766),
	LilyPadM = id(112030292927211),
	LilyPadS = id(118763336299344),
	MossyRockA = id(85574033919182),
	MossyRockB = id(126736135358175),
	MushroomsBrown = id(74405672058131),
	MushroomsRed = id(88589283701831),
	OakA_Canopy = id(90068725660607),
	OakA_Trunk = id(106828885086436),
	OakB_Canopy = id(134749240337474),
	OakB_Trunk = id(89569880898707),
	OakC_Canopy = id(81252642857922),
	OakC_Trunk = id(120072789985855),
	PineA_Canopy = id(92692882264575),
	PineA_Trunk = id(102208994723568), -- revision 2 (was 82143832617173)
	PineB_Canopy = id(100564242489410),
	PineB_Trunk = id(138157650015202), -- revision 2 (was 89643406488268)
	PineC_Canopy = id(79276284052740),
	PineC_Trunk = id(111053653938671), -- revision 2 (was 126729994654224)
	PineSapling_Canopy = id(131316584239813),
	PineSapling_Trunk = id(136990516574113), -- revision 2 (was 108644319441252)
	PopcornCart = id(96408021272336),
	Poppies = id(75527608430305),
	Raccoon = id(92439139003226), -- revision 2 (was 70443242208452)
	RaccoonHead = id(125051843028649), -- revision 2 (was 133875827596835)
	Reeds = id(123368172491352),
	RosesPink = id(75042050246474),
	RosesRed = id(124625690855684),
	Rowboat = id(122970355945451),
	Rushes = id(95077880123937),
	Signpost = id(89954063283562),
	SteppingStone = id(88232267625126),
	Stump = id(125779606546056),
	Sunflowers = id(74211938713050),
	TallGrass = id(132002952081416),
	TieredA_Canopy = id(100114007581824),
	TieredA_Trunk = id(108201404836746),
	TieredB_Canopy = id(115154861337602),
	TieredB_Trunk = id(71984161373179),
	TieredC_Canopy = id(72869799411568),
	TieredC_Trunk = id(112721320223055),
	TopiaryBall = id(105781276915527),
	TopiaryCone = id(139714947194490),
	TulipsRed = id(70585910939414),
	TulipsYellow = id(140641152811990),
	UmbrellaA_Canopy = id(120894937018074), -- revision 2 (was 104256844178578)
	UmbrellaA_Trunk = id(137649536930632),
	UmbrellaB_Canopy = id(97435314449821),
	UmbrellaB_Trunk = id(122983901532353),
	UmbrellaC_Canopy = id(114164761665601),
	UmbrellaC_Trunk = id(121305472090972),
	WetRockA = id(114681583860533),
	WetRockB = id(140616452972253),
	WillowA_Canopy = id(126630738198123), -- revision 2 (was 95230078901958)
	WillowA_Trunk = id(75933431885207),
	WillowB_Canopy = id(127356487466250),
	WillowB_Trunk = id(83709653441289),
	WillowC_Canopy = id(113473301166191),
	WillowC_Trunk = id(99167092069684),
	-- new in revision 2 (2026-10-21, island-kit-rev2.obj)
	FountainGrand = id(134250858109840),
	FountainGrandWater = id(97077137017352),
	PlazaMosaic = id(137077011185169),
	-- new in Task 3 (2026-10-22, island-kit-task3.obj, imported by Adam; creator peskaface)
	ChainAnchorPost = id(116104471794716),
	ChainLink = id(114214302961113),
	Flagpole = id(129548914805122),
	HeaderBoard = id(131034066017721),
	KioskBooth = id(122977264336017),
	PadlockBody = id(126446131938774),
	PadlockShackle = id(80634870609051),
	PlotGate = id(132284962738302),
	PortalSign = id(96622363246047),
	SignpostBoard = id(71490569687047),
	SignpostPost = id(76170109920794),
	-- Task 4 (2026-10-22): the 97 park4, gates, stunt and garage meshes, one 3D Importer batch of
	-- Car-Hop-Art/island-kit-task4/all/island-kit.obj under peskaface (privacy settings not changed)
	AirPump = id(85075129657610),
	BedAvenueArc = id(83055271600743),
	BedAvenueStraight = id(111747692241584),
	BedCornerFillet = id(99237896497111),
	BedFountainArc = id(138519763827753),
	BedJunctionRound = id(127970609183087),
	Bollard = id(137304579092978),
	BridgeRiverApproach = id(99201813850591),
	BridgeRiverAvenue = id(80517554710181),
	CarLift = id(121987728120237),
	CheckeredBand = id(138048567006496),
	DrumRed = id(71870413657309),
	DrumTeal = id(75797387695559),
	ForecourtCurb = id(76405410501889),
	GarageBench = id(102867336577100),
	GarageFlagpole = id(105177158117178),
	GarageGlazing = id(132157148972532),
	GarageInterior = id(87185201084021),
	GarageLights = id(124692895162585),
	GarageShell = id(114734875520385),
	GarageSign = id(77309746815929),
	GarageStructure = id(79270006556493),
	GateChainLink = id(124272794650745),
	GateChainRun = id(95430339517072),
	GateChainWrap = id(110960492207804),
	GateDowntownColumns = id(108532592863645),
	GateDowntownCrest = id(125826091705271),
	GateDowntownCrown = id(78065550426898),
	GateDowntownInlayHigh = id(138236598259286),
	GateDowntownInlayLow = id(73978543922047),
	GateDowntownInlayMid = id(122317866532106),
	GateDowntownPlinth = id(107278482923295),
	GateDustyColumns = id(117297712279771),
	GateDustyCrest = id(80580172831278),
	GateDustyCrown = id(84029568732331),
	GateDustyInlayHigh = id(81946948345013),
	GateDustyInlayLow = id(87020772643400),
	GateDustyInlayMid = id(121012710941260),
	GateDustyPlinth = id(110839059652265),
	GateLockedPlaque = id(91281029170193),
	GatePadlockBody = id(140163082771569),
	GatePadlockShackle = id(112064977038149),
	GateRequirementPlaque = id(71624689678209),
	GateSummitColumns = id(116585945901808),
	GateSummitCrest = id(75609991349650),
	GateSummitCrown = id(87745284432156),
	GateSummitInlayHigh = id(121201737129889),
	GateSummitInlayLow = id(132503600474169),
	GateSummitInlayMid = id(122432717876953),
	GateSummitPlinth = id(123915058031834),
	HazardStrip = id(131308067592934),
	LeaderboardCapRail = id(112756730022409),
	LeaderboardFrame = id(113908519666761),
	LeaderboardLampLens = id(74675984162564),
	LeaderboardTextFace = id(94740208248666),
	LightPost = id(136240285485160),
	MarqueeBulb = id(107792494255734),
	OilCanDisplay = id(70684156665297),
	Parasol = id(96290961601445),
	ParasolTeal = id(137648743329802),
	ParkBin = id(105614179605967),
	ParkingArrow = id(131426764702576),
	PicnicTable = id(70679924563183),
	Planter = id(74716533726124),
	PlotGateAccent = id(116141689733548),
	PlotGateBeam = id(93468975278723),
	PlotGateChecker = id(136149495518732),
	PlotGateFenceStub = id(124053386639427),
	PlotGateFlagpoles = id(139021453048462),
	PlotGateHedgeStub = id(81661540109869),
	PlotGateLamps = id(101357819746042),
	PlotGatePillars = id(89083749317837),
	PlotGateStartLine = id(73549160337847),
	RarityRing = id(75126108953276),
	RollUpDoor = id(108434316528609),
	RoofVent = id(73487211272948),
	StuntApron = id(133474972767713),
	StuntCone = id(128735165623877),
	StuntEndBarrier = id(136763665082578),
	StuntFlag = id(90426133652776),
	StuntGantry = id(133362520173926),
	StuntGridMarkings = id(133704870770169),
	StuntLoop = id(73133440812210),
	StuntPodium = id(135352583697109),
	StuntSignFaceBoard = id(109317817309224),
	StuntSignFaceComingSoon = id(77108293711707),
	StuntSignFaceLettering = id(109878260834399),
	StuntStartLightHousing = id(91530788392427),
	StuntStartLightLens = id(98808475067412),
	StuntTireRow = id(123628473301675),
	TireRack = id(109408017259964),
	TireStack = id(80992238482595),
	ToolCart = id(102543773473842),
	ToolWall = id(117340040095286),
	TurntableDisc = id(135928862713310),
	WallLight = id(102100752450863),
	WrenchTireSculpture = id(107898777545853),
} :: { [string]: string }

return AssetIds
