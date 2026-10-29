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
KitIds.Palette = id(134121745235322)

KitIds.Textures = {
	Pennants = id(129394675251472),
	FlagChecker = id(113814256495528),
	FlagStripesA = id(97908223611462),
	FlagStripesB = id(81318556896008),
	FlagStar = id(93044374349935),
}

-- name -> "rbxassetid://..." (55 meshes imported, 52 in use). Imported 2026-10-28 with Studio's 3D Importer from
-- Car-Hop-Art/island-kit-speedway/island-kit.obj under Adam's user account (peskaface) for now,
-- on Adam's choice, because the account is not in a group yet; a group-owned re-import replaces
-- these ids (vault/design/specs/island-group-reimport.md). Checked with Preview/ImportCheck:
-- 55 found, none missing, extra or duplicated, sizes within 0.01 of the manifest.
KitIds.Meshes = {
	SwAnnouncerBooth = id(124453131187665),
	SwBigScreen = id(136313621591068),
	SwCatchFence = id(118467531984872),
	SwColumn = id(117122389431761),
	SwColumnCap = id(138360257717620),
	SwConfettiCannon = id(86449102782819),
	SwFanA = id(78659021360351),
	SwFanArmA = id(78174090582827),
	SwFanArmB = id(92288988788911),
	SwFanArmC = id(128032313986312),
	SwFanArmD = id(134667519052344),
	SwFanB = id(135244994677708),
	SwFanC = id(78827618381473),
	SwFanD = id(78662527393225),
	SwFireworkRack = id(125124780517169),
	SwFlameDecal = id(93193112513464),
	SwFloodTower = id(91154333937804),
	SwFoldingChair = id(118657963872263),
	SwGantry = id(74403998767331),
	SwGantryGold = id(84586293883784),
	SwGuardRail = id(118243041147792),
	SwHayRun = id(71403699224391),
	SwLapBoard = id(82939533196986),
	SwLemonadeStand = id(88358586428374),
	SwLoopTrack = id(125969216625674),
	SwMechanic = id(85414037662565),
	SwOfficialArm = id(127574675253827),
	SwOfficialBody = id(108302391421797),
	SwOfficialPodium = id(99851458414418),
	SwOrangeBarrier = id(116584146015210),
	SwOwnerSign = id(114585653931779),
	SwPaintedShed = id(100881923990640),
	SwPennantPole = id(133219469923618),
	SwPitGarage = id(85056047877073),
	SwPreviewCar = id(114289274081549),
	SwRollDoor = id(137736104496512),
	SwRoofSection = id(136803859882416),
	SwRopeFence = id(130736182708379),
	SwRustyShed = id(74007209717289),
	SwSnackCart = id(124620820513366),
	SwStartBoard = id(108638704239839),
	SwStartLights = id(91248060101322),
	SwStatueCar = id(107153665426811),
	SwStatuePedestal = id(84105899812591),
	SwToolChest = id(127404059896137),
	SwTyreRun = id(129182236325606),
	SwTyreStackTall = id(134733406920013),
	SwTyreWall = id(75467866278108),
	SwWaterBarrel = id(71014321583426),
	SwWheelbarrow = id(92646788953541),
	SwWonkyStick = id(107697770547663),
	SwWrench = id(75450568807779),
} :: { [string]: string }

-- Raceway round 2 (Adam, 2026-10-29): no advertising. The banked-wall banner images (ZOOPA FIZZ,
-- CRUNCHKIN PUFFS, STICKYTOE TYRES, WOBBLEBOT TOYS; ids in Island/Hub/Environment/AssetIds) are no
-- longer used by the Raceway. These three meshes were repainted (plain fascias, an unlettered
-- blimp); until the guided re-import they load from the preview mesh data. Their earlier uploads
-- carry the old paint but no lettering (the sponsor and blimp text were SurfaceGuis); kept here
-- until the replacements are verified (vault/design/specs/raceway-round2-ledger.md).
KitIds.Superseded = {
	SwBleachers = id(116247810996339),
	SwBlimp = id(90422652853307),
	SwGrandstandBay = id(80000123062400),
} :: { [string]: string }

return KitIds
