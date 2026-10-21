# Island kit asset manifest (Task 2 revision)

Every asset below is original work made for this project: geometry from the Blender recipes in
this folder, images from `textures.js` and `kitlib.py`. No Creator Store, Toolbox or generated
(`generate_*`) content. Owner: Adam's Roblox account **peskaface** (user 2393473976), no group,
as authorised in [[island-rework]] IRW-57. Licence: all rights held by the owner for this
project; no third-party licence applies. Binary sources live in `Car-Hop-Art/island-kit/`
(outside Git); the recipes and this record are in Git.

Asset ids are also in `src/island/Hub/Environment/AssetIds.luau`.

## Images (uploaded 2026-10-21 through the Studio MCP `upload_image`)

| Asset | Id | Source | State | Loads in the test experience |
|---|---|---|---|---|
| Palette (256 × 256, 16 × 16 swatches) | 112727480640146 | `kitlib.py` → `palette.png` | uploaded | yes (kit previews coloured) |
| WaterBody | 118829614143752 | `textures.js` | uploaded | yes |
| WaterStrandsFast | 123432307138321 | `textures.js` | uploaded | yes |
| WaterStrandsSlow | 80338760305637 | `textures.js` | uploaded | yes |
| WaterHighlights | 111578838235188 | `textures.js` | uploaded | yes |
| WaterSpray | 91396665960467 | `textures.js` | uploaded | yes |
| FoamTile | 122795342152257 | `textures.js` | uploaded | yes |
| FoamPatch | 99023600024403 | `textures.js` | uploaded | yes |
| Ripple | 106407842749322 | `textures.js` | uploaded | yes |
| Droplet | 109536997721772 | `textures.js` | uploaded | yes |
| Mist | 114900109756669 | `textures.js` | uploaded | yes |
| Rainbow | 72537598666370 | `textures.js` | uploaded | yes |
| Sparkle | 87030054749344 | `textures.js` | uploaded | yes |
| Glow | 109290330063558 | `textures.js` | uploaded | yes |
| Current | 103576178978702 | `textures.js` | uploaded | yes |

## Meshes (pending: 3D Importer upload of `island-kit.fbx`)

Script upload (`AssetService:CreateAssetAsync`) is not available in this Studio build, so the
meshes go up through the 3D Importer with Upload to Roblox on and Creator set to peskaface. The
FBX has no materials or textures, so the importer creates no image assets; colour comes from the
palette above. Expected: 137 mesh assets (names below, 81,226 triangles in total, largest
BirchB_Canopy at 3,440) plus one model asset named after the file. Ids, the model asset id, any
failed upload and the load check per mesh are filled in after the import.

| Group | Count | Meshes | State |
|---|---|---|---|
| Trees | 55 | Oak, Tiered, Umbrella, Birch, Blossom, Willow, Fruit and Pine in variants A to C, plus PineSapling, each as `_Trunk` and `_Canopy`; BushSmall, BushMedium, BushLarge, BerryBush, FloweringShrub | pending |
| Plants | 39 | GrassTuft, GrassTuftWide, TallGrass, Clover, FernA, FernB, MushroomsRed, MushroomsBrown, MossyRockA, MossyRockB, Stump, HollowLog, LeafLitter, TulipsRed, TulipsYellow, Daisies, Poppies, Lavender, BlueWildflowers, Sunflowers, RosesRed, RosesPink, Reeds, Cattails, Rushes, Arrowhead, Irises, LilyPadS, LilyPadM, LilyPadL, LilyFlowerWhite, LilyFlowerPink, Duckweed, WetRockA, WetRockB, Driftwood, SteppingStone, FloatingLeaf, FloatingPetal | pending |
| Props | 29 | BoulderA, BoulderB, BoulderC, Dock, Rowboat, Bench, LampPost, LampGlass, HotDogCart, PopcornCart, IceCreamStand, LemonadeStand, FountainTiered, FountainWater, HedgeStraight, HedgeLow, TopiaryBall, TopiaryCone, CarTopiary, Signpost, BridgeAvenue, BridgeLakeside, BridgeGarden, BridgeAvenueOpen, BedRound, BedOval, BuntingString, FenceSegment, Gazebo | pending |
| Animals | 14 | Duck, Duckling, Raccoon, RaccoonHead, ButterflyBody, ButterflyWingL, ButterflyWingR, ButterflyBlueWingL, ButterflyBlueWingR, DragonflyBody, DragonflyWings, Frog, FishOrange, FishSilver | pending |
