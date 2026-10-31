--!strict
-- Asset ids the Speedway looks use (Lane 3). The images are the island's existing uploads (the
-- same ids as ServerStorage Island/Hub/Environment/AssetIds, repeated here because the Speedway
-- is assembled on each client). Meshes: the uploaded speedway kit (assets/island/kit/kit_speedway.py);
-- a mesh with no id falls back to a session-only preview from the mesh data that only
-- Adam's island preview project syncs (ReplicatedStorage.Lane3_SpeedwayKitData). After the
-- re-import, replace the ids in Meshes; nothing else changes.

local KitIds = {}

local function id(n: number): string
	return "rbxassetid://" .. n
end

-- the island kit palette (256 x 256 swatch image) every kit mesh is UV-mapped to
KitIds.Palette = id(128169045252325)

KitIds.Textures = {
	Pennants = id(109986080076934),
	FlagChecker = id(107933231350357),
	FlagStripesA = id(109705567230453),
	FlagStripesB = id(77641612149566),
	FlagStar = id(96696844387606),
}

-- name -> "rbxassetid://..." (61 meshes), group-owned: re-imported 2026-10-31 by Adam under the group
-- LEGION STUDI0S (group 74306252) with Studio's 3D Importer from
-- Car-Hop-Art/upload-legion-island-2026-10-31/3-raceway-meshes-61.obj (the full kit build of 2026-10-29).
-- Every id checked: group creator, sizes within 0.01 of the manifest. The palette and the textures above
-- were re-imported the same day (the same ids as Island/Hub/Environment/AssetIds). The earlier
-- user-owned ids (peskaface, 2026-10-28 and 2026-10-29) are listed in assets/island/kit/manifest.md.
KitIds.Meshes = {
	SwAnnouncerBooth = id(85280690019741),
	SwBayBarrierArm = id(102661645918978), -- Raceway round 2
	SwBayBarrierPost = id(72382460044152), -- Raceway round 2
	SwBigScreen = id(128201415244874),
	SwBleachers = id(107432199937261), -- Raceway round 2
	SwBlimp = id(96699312485170), -- Raceway round 2
	SwCatchFence = id(100543478185899),
	SwColumn = id(115247428990660),
	SwColumnCap = id(123422088082154),
	SwConfettiCannon = id(82865014588770),
	SwFanA = id(83121163075535),
	SwFanArmA = id(75049768549378),
	SwFanArmB = id(120825261111737),
	SwFanArmC = id(126747982610886),
	SwFanArmD = id(115678520260583),
	SwFanB = id(91123601332587),
	SwFanC = id(87393623373212),
	SwFanD = id(117245066153917),
	SwFireworkRack = id(129517648518270),
	SwFlameDecal = id(127373852109905),
	SwFloodTower = id(103538610674357),
	SwFoldingChair = id(115166621593495),
	SwGantry = id(91999865224306),
	SwGantryGold = id(120131138578527),
	SwGrandstandBay = id(103599785391659), -- Raceway round 2
	SwGuardRail = id(136867342464008),
	SwHayRun = id(140031111271962),
	SwKeeperArm = id(102504505914546), -- Raceway round 2
	SwKeeperBody = id(102350514652723), -- Raceway round 2
	SwLapBoard = id(136055088029366),
	SwLemonadeStand = id(97741292989096),
	SwLoopTrack = id(101864195807167),
	SwMechanic = id(135045771420514),
	SwOfficialArm = id(107245427682978),
	SwOfficialBody = id(79915609641268),
	SwOfficialPodium = id(140449945546404),
	SwOrangeBarrier = id(127964033639594),
	SwOwnerSign = id(124441916586855),
	SwPaintedShed = id(91248138191970),
	SwParkingSign = id(108613965243569), -- Raceway round 2
	SwPennantPole = id(78922292885261),
	SwPitGarage = id(123837917076829),
	SwPreviewCar = id(137630075868196),
	SwRacewayShop = id(88675832942368), -- Raceway round 2
	SwRollDoor = id(73057985208386),
	SwRoofSection = id(121872970793697),
	SwRopeFence = id(138483697478646),
	SwRustyShed = id(76838557009265),
	SwSnackCart = id(95141887124611),
	SwStartBoard = id(127792453703226),
	SwStartLights = id(104205558358843),
	SwStatueCar = id(128442367976976),
	SwStatuePedestal = id(102560465524845),
	SwToolChest = id(126048126880224),
	SwTyreRun = id(132481136278127),
	SwTyreStackTall = id(126825259786624),
	SwTyreWall = id(86760996331774),
	SwWaterBarrel = id(84553120810312),
	SwWheelbarrow = id(109677414305240),
	SwWonkyStick = id(101710054055028),
	SwWrench = id(106420477941889),
} :: { [string]: string }

-- Raceway round 2 (Adam, 2026-10-29): no advertising. The banked-wall banner images (ZOOPA FIZZ,
-- CRUNCHKIN PUFFS, STICKYTOE TYRES, WOBBLEBOT TOYS; ids in Island/Hub/Environment/AssetIds) are no
-- longer used by the Raceway. These three meshes were repainted (plain fascias, an unlettered
-- blimp) and re-imported on 2026-10-29 (ids in Meshes, sizes checked against the manifest). Their
-- earlier uploads carry the old paint but no lettering (the sponsor and blimp text were
-- SurfaceGuis); kept here for the record (vault/design/specs/raceway-round2-ledger.md).
KitIds.Superseded = {
	SwBleachers = id(116247810996339),
	SwBlimp = id(90422652853307),
	SwGrandstandBay = id(80000123062400),
} :: { [string]: string }

return KitIds
