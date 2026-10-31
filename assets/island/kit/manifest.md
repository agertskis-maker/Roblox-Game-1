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

## Meshes (uploaded 2026-10-21 through the 3D Importer)

Script upload (`AssetService:CreateAssetAsync`) is not available in this Studio build, so Adam
imported `island-kit.obj` (written by `build_kit.py`) with Upload to Roblox on, Creator "Me"
(peskaface), Import Only as a Model on, Scale Factor 1. The file has no materials, so no image
was uploaded; colour comes from the palette above.

How it went, including the attempts that uploaded nothing:
1. `island-kit.fbx` read at 100 times true size (centimetre units) with a size warning; Scale
   Factor 0.01 gave the right numbers but the warning stayed, and reloading resets the factor.
   Not imported.
2. A compact 12-wide grid layout and a pre-shrunk FBX did not clear the warning. Not imported.
3. `island-kit.obj` with one group per mesh: true size (418.16 × 35.06 × 408.83 for the grid),
   81,226 triangles, no warning. Imported once.

Checks in Studio after the import: 137 MeshParts with 137 distinct asset ids; MeshSize matches
the manifest bounds within 0.0014 studs for every mesh; `GetProductInfo` reports creator
peskaface (User 2393473976) and asset type 4 (Mesh); `ContentProvider:PreloadAsync` on the
parts reported Success for all 137 in the test experience. The importer stores each mesh turned
180 degrees about Y from the recipe frame (vertex centroids have x and z negated, not mirrored);
`KitAssets` turns uploaded meshes back. The imported copy was removed from the Workspace.

Also created by the import: one **Model** asset, "island-kit", id **76013790027052**, in
peskaface's inventory (created 2026-10-21 23:59 UTC). The game does not use it.

No duplicate uploads: one import, one model, one asset per mesh. A rebuilt mesh needs a new
upload (or the importer's Reimport) and a new row here.

| Mesh | Group | Triangles | Asset id | State | Loads |
|---|---|---|---|---|---|
| BerryBush | trees | 680 | 113381535893436 | uploaded | yes |
| BirchA_Canopy | trees | 1920 | 95358946867963 | uploaded | yes |
| BirchA_Trunk | trees | 480 | 113392689229837 | uploaded | yes |
| BirchB_Canopy | trees | 3440 | 97117102116709 | uploaded | yes |
| BirchB_Trunk | trees | 736 | 71794440829829 | uploaded | yes |
| BirchC_Canopy | trees | 2080 | 134755746106792 | uploaded | yes |
| BirchC_Trunk | trees | 752 | 107504512366800 | uploaded | yes |
| BlossomA_Canopy | trees | 1680 | 85623663058251 | uploaded | yes |
| BlossomA_Trunk | trees | 507 | 71890708802809 | uploaded | yes |
| BlossomB_Canopy | trees | 2080 | 115945038397849 | uploaded | yes |
| BlossomB_Trunk | trees | 515 | 116376114509074 | uploaded | yes |
| BlossomC_Canopy | trees | 1600 | 70583076825211 | uploaded | yes |
| BlossomC_Trunk | trees | 406 | 70593040224453 | uploaded | yes |
| BushLarge | trees | 560 | 107937719458701 | uploaded | yes |
| BushMedium | trees | 400 | 112084388357819 | uploaded | yes |
| BushSmall | trees | 240 | 89066567685874 | uploaded | yes |
| FloweringShrub | trees | 760 | 97158756624560 | uploaded | yes |
| FruitA_Canopy | trees | 2480 | 91617448874937 | uploaded | yes |
| FruitA_Trunk | trees | 416 | 125813419406213 | uploaded | yes |
| FruitB_Canopy | trees | 2780 | 82529345438206 | uploaded | yes |
| FruitB_Trunk | trees | 352 | 77808359429337 | uploaded | yes |
| FruitC_Canopy | trees | 2540 | 110918401683196 | uploaded | yes |
| FruitC_Trunk | trees | 556 | 138730259128149 | uploaded | yes |
| OakA_Canopy | trees | 2080 | 125079363526751 | uploaded | yes |
| OakA_Trunk | trees | 656 | 81838596725252 | uploaded | yes |
| OakB_Canopy | trees | 2160 | 114513892252367 | uploaded | yes |
| OakB_Trunk | trees | 619 | 133799468476153 | uploaded | yes |
| OakC_Canopy | trees | 2000 | 137935820165648 | uploaded | yes |
| OakC_Trunk | trees | 454 | 72640563796108 | uploaded | yes |
| PineA_Canopy | trees | 126 | 86571721057312 | uploaded | yes |
| PineA_Trunk | trees | 150 | 82143832617173 | uploaded | yes |
| PineB_Canopy | trees | 168 | 119200173785375 | uploaded | yes |
| PineB_Trunk | trees | 150 | 89643406488268 | uploaded | yes |
| PineC_Canopy | trees | 90 | 96071087065535 | uploaded | yes |
| PineC_Trunk | trees | 150 | 126729994654224 | uploaded | yes |
| PineSapling_Canopy | trees | 54 | 108593342174832 | uploaded | yes |
| PineSapling_Trunk | trees | 90 | 108644319441252 | uploaded | yes |
| TieredA_Canopy | trees | 640 | 72964718415062 | uploaded | yes |
| TieredA_Trunk | trees | 468 | 73674256532039 | uploaded | yes |
| TieredB_Canopy | trees | 560 | 88044922593595 | uploaded | yes |
| TieredB_Trunk | trees | 437 | 128171113138801 | uploaded | yes |
| TieredC_Canopy | trees | 960 | 70677452623426 | uploaded | yes |
| TieredC_Trunk | trees | 423 | 109536531531788 | uploaded | yes |
| UmbrellaA_Canopy | trees | 2720 | 104256844178578 | uploaded | yes |
| UmbrellaA_Trunk | trees | 573 | 133742908940135 | uploaded | yes |
| UmbrellaB_Canopy | trees | 2080 | 74855981514851 | uploaded | yes |
| UmbrellaB_Trunk | trees | 464 | 101735978642638 | uploaded | yes |
| UmbrellaC_Canopy | trees | 2800 | 108564507264176 | uploaded | yes |
| UmbrellaC_Trunk | trees | 682 | 109121511812165 | uploaded | yes |
| WillowA_Canopy | trees | 2040 | 95230078901958 | uploaded | yes |
| WillowA_Trunk | trees | 572 | 95619268368185 | uploaded | yes |
| WillowB_Canopy | trees | 2260 | 117793886163427 | uploaded | yes |
| WillowB_Trunk | trees | 591 | 78855509300039 | uploaded | yes |
| WillowC_Canopy | trees | 1900 | 117322934216935 | uploaded | yes |
| WillowC_Trunk | trees | 533 | 94489845710982 | uploaded | yes |
| Arrowhead | plants | 91 | 77734052464842 | uploaded | yes |
| BlueWildflowers | plants | 660 | 140362334076502 | uploaded | yes |
| Cattails | plants | 320 | 96641977331650 | uploaded | yes |
| Clover | plants | 381 | 119625716970260 | uploaded | yes |
| Daisies | plants | 852 | 72553714073439 | uploaded | yes |
| Driftwood | plants | 78 | 79754565581073 | uploaded | yes |
| Duckweed | plants | 350 | 96016381404577 | uploaded | yes |
| FernA | plants | 623 | 125414860170513 | uploaded | yes |
| FernB | plants | 801 | 132864443197145 | uploaded | yes |
| FloatingLeaf | plants | 4 | 117142848195882 | uploaded | yes |
| FloatingPetal | plants | 4 | 102542786153320 | uploaded | yes |
| GrassTuft | plants | 84 | 87769624057571 | uploaded | yes |
| GrassTuftWide | plants | 156 | 85162093459834 | uploaded | yes |
| HollowLog | plants | 212 | 133502513071015 | uploaded | yes |
| Irises | plants | 292 | 124819745705979 | uploaded | yes |
| Lavender | plants | 1032 | 130846919850597 | uploaded | yes |
| LeafLitter | plants | 240 | 134131919266803 | uploaded | yes |
| LilyFlowerPink | plants | 103 | 76891640080088 | uploaded | yes |
| LilyFlowerWhite | plants | 103 | 82425262882452 | uploaded | yes |
| LilyPadL | plants | 30 | 111100338080785 | uploaded | yes |
| LilyPadM | plants | 30 | 92817792476653 | uploaded | yes |
| LilyPadS | plants | 30 | 75828509671473 | uploaded | yes |
| MossyRockA | plants | 80 | 116711716740489 | uploaded | yes |
| MossyRockB | plants | 80 | 100088279100790 | uploaded | yes |
| MushroomsBrown | plants | 210 | 72630651084382 | uploaded | yes |
| MushroomsRed | plants | 575 | 132931914368107 | uploaded | yes |
| Poppies | plants | 441 | 134198513847375 | uploaded | yes |
| Reeds | plants | 180 | 138621409272637 | uploaded | yes |
| RosesPink | plants | 765 | 133767793962188 | uploaded | yes |
| RosesRed | plants | 765 | 137302351764375 | uploaded | yes |
| Rushes | plants | 234 | 94073208976012 | uploaded | yes |
| SteppingStone | plants | 80 | 114567733775797 | uploaded | yes |
| Stump | plants | 88 | 97538794770552 | uploaded | yes |
| Sunflowers | plants | 848 | 70924896477467 | uploaded | yes |
| TallGrass | plants | 220 | 96033594782233 | uploaded | yes |
| TulipsRed | plants | 363 | 125564876170957 | uploaded | yes |
| TulipsYellow | plants | 330 | 98770109311258 | uploaded | yes |
| WetRockA | plants | 80 | 99844062490263 | uploaded | yes |
| WetRockB | plants | 80 | 115292109378113 | uploaded | yes |
| BedOval | props | 429 | 75182510100315 | uploaded | yes |
| BedRound | props | 273 | 78898513024992 | uploaded | yes |
| Bench | props | 180 | 81472931283188 | uploaded | yes |
| BoulderA | props | 80 | 73936552182889 | uploaded | yes |
| BoulderB | props | 100 | 108729967021241 | uploaded | yes |
| BoulderC | props | 100 | 99527827208631 | uploaded | yes |
| BridgeAvenue | props | 1128 | 132499975394188 | uploaded | yes |
| BridgeAvenueOpen | props | 336 | 78688525290880 | uploaded | yes |
| BridgeGarden | props | 1128 | 119984148857166 | uploaded | yes |
| BridgeLakeside | props | 1128 | 74401136745211 | uploaded | yes |
| BuntingString | props | 131 | 90642820165813 | uploaded | yes |
| CarTopiary | props | 524 | 124108261960990 | uploaded | yes |
| Dock | props | 336 | 121994894630420 | uploaded | yes |
| FenceSegment | props | 196 | 75883738881066 | uploaded | yes |
| FountainTiered | props | 662 | 87095967163960 | uploaded | yes |
| FountainWater | props | 208 | 116528389038986 | uploaded | yes |
| Gazebo | props | 632 | 132930457317667 | uploaded | yes |
| HedgeLow | props | 172 | 94290153677107 | uploaded | yes |
| HedgeStraight | props | 252 | 115214796420911 | uploaded | yes |
| HotDogCart | props | 430 | 128077008495216 | uploaded | yes |
| IceCreamStand | props | 200 | 72102386161007 | uploaded | yes |
| LampGlass | props | 32 | 120377499915257 | uploaded | yes |
| LampPost | props | 216 | 139674403634313 | uploaded | yes |
| LemonadeStand | props | 184 | 125464775917653 | uploaded | yes |
| PopcornCart | props | 556 | 140620817482021 | uploaded | yes |
| Rowboat | props | 236 | 111594792382992 | uploaded | yes |
| Signpost | props | 86 | 75373199680961 | uploaded | yes |
| TopiaryBall | props | 119 | 89575297387819 | uploaded | yes |
| TopiaryCone | props | 94 | 72356799315602 | uploaded | yes |
| ButterflyBlueWingL | animals | 10 | 84463884097172 | uploaded | yes |
| ButterflyBlueWingR | animals | 10 | 96381297933560 | uploaded | yes |
| ButterflyBody | animals | 43 | 83296309836118 | uploaded | yes |
| ButterflyWingL | animals | 10 | 110344634719101 | uploaded | yes |
| ButterflyWingR | animals | 10 | 77372830185761 | uploaded | yes |
| DragonflyBody | animals | 75 | 116300255540446 | uploaded | yes |
| DragonflyWings | animals | 16 | 96240530729511 | uploaded | yes |
| Duck | animals | 293 | 82641503340866 | uploaded | yes |
| Duckling | animals | 293 | 114222618214481 | uploaded | yes |
| FishOrange | animals | 86 | 93198247823924 | uploaded | yes |
| FishSilver | animals | 86 | 74193987938908 | uploaded | yes |
| Frog | animals | 240 | 124872657363209 | uploaded | yes |
| Raccoon | animals | 182 | 70443242208452 | uploaded | yes |
| RaccoonHead | animals | 219 | 133875827596835 | uploaded | yes |

## Revision 2 uploads (2026-10-21 to 22)

Owner peskaface (Studio user 2393473976, checked before each upload); every final asset below
loads in the test experience (`ContentProvider:PreloadAsync`), sizes within 0.001 studs of the build.

| Asset | Id | Source | State |
|---|---|---|---|
| Chevron (boost lane), first version | 136467391577760 | `textures.js` chevron, 128 × 64 | uploaded; **superseded** (drawn sideways on a beam), not referenced |
| Chevron (boost lane) | 96352143506498 | `textures.js` chevron, 64 × 128 | uploaded, in use |
| Model "island-kit-rev2" | (importer model, not used by the game) | `island-kit-rev2.obj` via `export_subset.py` | created by the import |

Meshes in one 3D Importer import of `island-kit-rev2.obj` (13 meshes, only changed or new ones;
the replaced ids are kept in `AssetIds.luau` comments and are no longer referenced):

| Mesh | New id | Replaces | Why |
|---|---|---|---|
| BirchB_Canopy | 76466785156402 | 97117102116709 | canopy covers a branch tip |
| BirchC_Canopy | 77471118350791 | 134755746106792 | canopy covers a side branch |
| UmbrellaA_Canopy | 91847269200413 | 104256844178578 | canopy covers a branch tip |
| WillowA_Canopy | 100724359605792 | 95230078901958 | canopy covers a branch tip |
| PineA_Trunk | 126489468362585 | 82143832617173 | leader shortened inside the top tier |
| PineB_Trunk | 91453775827473 | 89643406488268 | as above |
| PineC_Trunk | 113986667544582 | 126729994654224 | as above |
| PineSapling_Trunk | 125052020212163 | 108644319441252 | as above |
| Raccoon | 78064153570396 | 70443242208452 | redesign: hunched body, ringed tail |
| RaccoonHead | 122251191819978 | 133875827596835 | redesign: mask, round ears |
| FountainGrand | 138476226884315 | (new) | the grand fountain |
| FountainGrandWater | 118135225656541 | (new) | its pools and spill sheets |
| PlazaMosaic | 92746874626451 | (new) | patterned plaza ring |

## Sounds under test (not uploaded; Creator Store audio)

| Use | Asset | Id | Owner / source | Licence or usage | In game |
|---|---|---|---|---|---|
| Falls loop | Waterfall Steady Stream 1 (SFX), 27.0 s | 9120552550 | ProSoundEffects (Roblox's licensed audio partner account) | free Creator Store audio for use in Roblox experiences; exact licence text **not verified** | test: positional at the lower falls, volume 0.55, roll-off 45 to 420 |
| Park birdsong | Birds Park 2 (SFX), 57.3 s | 9113444360 | ProSoundEffects | as above, **not verified** | test: plaza, volume 0.14, roll-off 160 to 650 |
| Duck quack | Quack Duck, **63.1 s** | 1845012569 | APMOfficial (Roblox's licensed music partner account) | as above, **not verified** | **off**: the asset is a 63-second track, not one quack |

All three play through one SoundGroup `Lane3Ambience` (no player volume setting exists in the
project yet). Loading and properties were checked in a playtest; nobody has listened yet.

## Asset privacy and future permissions (checked 2026-10-22)

Source: https://create.roblox.com/docs/projects/assets/privacy (read through the Studio MCP).

- **Current owner:** peskaface (user 2393473976) for every image and mesh above.
- **Privacy state: unverified.** Roblox creates Images, Decals and Meshes as **Open Use by
  default** unless the owner turned on "Opt-in to restrict assets on creation" (Creator
  Dashboard → Settings → Advanced → Asset Privacy) *before* uploading; the setting is not
  retroactive and **Open Use cannot be changed back to Restricted**. Whether peskaface had the
  opt-in on is visible only on the Creator Dashboard (Development Items → Images / Meshes → an
  asset → Asset Access). Nothing in this project set any asset to Open Use.
- **Asset-type limits:** the privacy setting covers Images, Decals and Meshes only. The importer's
  Model assets, Audio, MeshParts, Animations and Packages have their own defaults.
- **If the published game belongs to someone else or a group** and the assets are Restricted: a
  person who can edit that game grants it access (game Creator Dashboard → Configurations →
  Permissions → paste the asset ids), or the owner shares the assets per asset (Permissions →
  Collaborators, with a friend or a group where the owner has the required permission). Who:
  Adam (peskaface), as the asset owner. Game grants are permanent.
- **Open team decision (Adam, Brian R, Brian L):** who owns the published experience.

## Task 3 uploads (2026-10-22)

Owner peskaface, images uploaded through the Studio MCP. Privacy: unchanged (not checked, not
set). Load: all sign art and portal textures render in the Studio captures. PortalBeam, Mote
and Ember logged "Asset content representation is being generated" at the first playtest and
rendered later. Ids are also in `src/island/Hub/Environment/AssetIds.luau`.

### Palette

| Asset | Id | Source | State |
|---|---|---|---|
| Palette, revision 3 | 84613406678497 | `kitlib.py` → `palette.png` | uploaded, in use; four swatches appended (steel, brass, coral, mint), earlier cells unchanged; replaces 112727480640146 (no longer referenced) |

### Portal and track textures

Files: `Car-Hop-Art/island-kit/textures/` (drawn by `textures.js`).

| Asset | Id | File | State |
|---|---|---|---|
| PortalSwirlA | 92093492199405 | `portal-swirl-a.png` | in use |
| PortalSwirlB | 108950429777685 | `portal-swirl-b.png` | in use |
| PortalCloudTile | 123976736191333 | `portal-cloud-tile.png` | in use |
| PortalCore | 71006997459996 | `portal-core.png` | in use |
| PortalVeil | 80047315268792 | `portal-veil.png` | in use |
| PortalVeilB | 122267435775183 | `portal-veil-b.png` | in use |
| PortalMask | 112768234647366 | `portal-mask.png` | in use |
| PortalBeam | 99849771860096 | `portal-beam.png` | in use |
| PortalDepth, v1 | 126970565337092 | `portal-depth.png` | **superseded**, not referenced |
| PortalDepth, v2 | 77298104491687 | `portal-depth-v2.png` | in use (smoother edge) |
| PortalCloudBall | 98562926959140 | `portal-cloud-ball.png` | in use |
| PortalCloudBallB | 85244900910059 | `portal-cloud-ball-b.png` | in use |
| PortalBand | 90038845373360 | `portal-band.png` | in use (dark recess band) |
| GroundPool | 100675320642077 | `ground-pool.png` | in use |
| Mote | 128577684526564 | `mote.png` | in use |
| Ember | 117732180184030 | `ember.png` | in use |
| Shimmer | 113969750355597 | `shimmer.png` | in use |
| Pennants | 129394675251472 | `pennants.png` | in use (track bunting) |
| FlagChecker | 113814256495528 | `flag-checker.png` | in use |
| FlagStripesA | 97908223611462 | `flag-stripes-a.png` | in use |
| FlagStripesB | 81318556896008 | `flag-stripes-b.png` | in use |
| FlagStar | 93044374349935 | `flag-star.png` | in use |

### Sign art

From the Figma mocks (Car Hop UI, page "Island signs"; specs `vault/design/ui/island-signs.md`,
`plot-track-signs.md`, `portal-sign.md`). Files: `Car-Hop-Art/island-kit/textures/signs/`. Live
text (names, numbers) is a TextLabel over a text-free background.

| Asset | Id | File | Note |
|---|---|---|---|
| HeaderHotDog | 111209092984557 | `header-hotdog.png` | Figma export |
| HeaderIceCream | 131134583059892 | `header-icecream.png` | Figma export |
| HeaderLemonade | 89775297450442 | `header-lemonade.png` | Figma export |
| HeaderPopcorn | 132673341754270 | `header-popcorn.png` | Figma export |
| BannerA (ZOOPA FIZZ) | 121463232337129 | `banner-zoopa-fizz.png` | Figma export |
| BannerB (CRUNCHKIN PUFFS) | 110246953719901 | `banner-crunchkin-puffs.png` | Figma export |
| BannerC (STICKYTOE TYRES) | 78479045044254 | `banner-stickytoe-tyres.png` | Figma export |
| BannerD (WOBBLEBOT TOYS) | 140634403555411 | `banner-wobblebot-toys.png` | **stitched from two exports**, not a direct render |
| OwnerBanner background | 103587041167945 | `owner-banner-bg.png` | name is a TextLabel |
| Nameplate background | 101228763400140 | `nameplate-bg.png` | name is a TextLabel |
| Kiosk | 137428624345478 | `kiosk-bg.png` | **drawn by `kiosk.js`**, not a direct render |
| IconPortal | 101447318056634 | `icon-portal.png` | Figma export |
| IconGarage | 139283194336735 | `icon-garage.png` | Figma export |
| IconStunt | 136778609492666 | `icon-stunt.png` | Figma export |
| IconPlots | 92929508456128 | `icon-plots.png` | Figma export |
| IconLake | 135234520936833 | `icon-lake.png` | Figma export |
| IconArrow | 75221826934795 | `icon-arrow.png` | Figma export |
| IconCoin | 99492109262754 | `icon-coin.png` | Figma export |
| IconTick | 103260929176535 | `icon-tick.png` | Figma export |
| IconLock | 125248424108608 | `icon-lock.png` | Figma export |
| IconWrench | 125308628941246 | `icon-wrench.png` | Figma export |

### Meshes: 2 new recipes, 11 meshes waiting for the import

New recipes in `kit_props.py`: **SignpostPost** (38 triangles) and **SignpostBoard** (16
triangles). The full kit is now 151 meshes, 90,986 triangles; no existing mesh changed (the
manifest diff is additions only). Other new Task 3 recipes are in `kit_plot.py` and
`kit_portal.py`.

**Not uploaded (blocked):** `Car-Hop-Art/island-kit/island-kit-task3.obj` holds 11 meshes:
ChainLink, PadlockBody, PadlockShackle, ChainAnchorPost, PortalSign, PlotGate, KioskBooth,
Flagpole, HeaderBoard, SignpostPost, SignpostBoard. The 3D Importer needs UI clicks; the
session's attempt to click the Import Queue was denied by the auto-mode permission classifier,
so it stopped there. Until Adam imports the file: in edit mode they show as session previews;
in a playtest they render as plain white boxes, and the portal locks use part-built pieces (267
parts per lock instead of about 70).

### Sounds in use (Creator Store audio, not uploaded)

Licence text **not verified** for any of them. **Nobody has listened** yet.

| Use | Asset | Id | Source | In game |
|---|---|---|---|---|
| Portal hum | Metallic Glow Constant Deep Ticking Bassy Hum 2 (SFX) | 9125674114 | Pro Sound Effects | looped, positional per portal; volume 0.22 to 0.62 by proximity, halved and at 0.85 speed when locked; one load attempt, no retry |
| Portal shimmer | Heavenly Harmonic Presence Glowing Crystal Ringing 2 (SFX) | 9125602541 | Pro Sound Effects | layer over the hum; volume 0.06 to 0.22 by proximity, 0 when locked; one load attempt, no retry |
| Duck quack | Quack Duck (63.05 s track) | 1845012569 | APM | **now on** (was off in revision 2): `PlaybackRegion` 1.3 to 1.68 s (one clean quack, from the waveform), every 20 to 40 s at random on the mother duck while the family is near this client, volume 0.32, roll-off 8 to 70; a missed quack is skipped, not queued |

The falls loop (9120552550) and park birdsong (9113444360) are unchanged from the table above.

## Task 3 meshes imported (2026-10-22, Adam, 3D Importer, island-kit-task3.obj)

| Mesh | Id |
|---|---|
| ChainAnchorPost | 114737667930382 |
| ChainLink | 99515412067221 |
| Flagpole | 82002796817463 |
| HeaderBoard | 89758117345462 |
| KioskBooth | 137774673874849 |
| PadlockBody | 114107687304189 |
| PadlockShackle | 97927780932934 |
| PlotGate | 83397197959185 |
| PortalSign | 75612522407601 |
| SignpostBoard | 128562147587889 |
| SignpostPost | 70440998829645 |

Checked after the import: creator peskaface, asset type Mesh, all load in Studio. The importer also created one Model asset (not used by the game; its id was not recorded). Privacy setting not changed.


## Task 4 uploads (2026-10-22 to 23)

### Palette
- `Palette` 134121745235322: the kit palette with the Task 4 swatches appended (cells 101 to 126); the older cells are byte-identical to the previous upload (84613406678497).

### Meshes: 97 imported in one batch (Claude Code driving the 3D Importer, `island-kit-task4/all/island-kit.obj`)
Creator peskaface, asset type Mesh, Restricted (Asset Privacy not changed). Sources: `kit_park4.py`, `kit_gates.py`, `kit_garage.py`, `kit_stunt.py` (headless Blender, safe mode on); manifest from `write_manifest.js`. All 97 load in Play (2026-10-22: 4,094 MeshParts with meshes, no preview fallback).

Known issue from an earlier upload: `GrassTuftWide` (85162093459834, Task 2) began failing with "Failed to load mesh asset" during Task 4. `KitAssets` falls back to its preview data in Edit, so it needs a re-upload or a check before production.

| Mesh | Asset id |
|---|---|
| AirPump | 110204729376180 |
| BedAvenueArc | 103579632050241 |
| BedAvenueStraight | 135442988433072 |
| BedCornerFillet | 118604528597435 |
| BedFountainArc | 134390751624734 |
| BedJunctionRound | 88027591948797 |
| Bollard | 130288057862761 |
| BridgeRiverApproach | 72542935568044 |
| BridgeRiverAvenue | 80680695628375 |
| CarLift | 119346173440460 |
| CheckeredBand | 102866985026681 |
| DrumRed | 138825731788822 |
| DrumTeal | 124127388745386 |
| ForecourtCurb | 93062744759345 |
| GarageBench | 128621570342938 |
| GarageFlagpole | 114307514216865 |
| GarageGlazing | 74974275532912 |
| GarageInterior | 129388325886092 |
| GarageLights | 83123427499636 |
| GarageShell | 121491509701515 |
| GarageSign | 97116362523762 |
| GarageStructure | 98702145130383 |
| GateChainLink | 73207672300684 |
| GateChainRun | 76766417787279 |
| GateChainWrap | 130443776899054 |
| GateDowntownColumns | 100622023476660 |
| GateDowntownCrest | 136625187784489 |
| GateDowntownCrown | 76948856455160 |
| GateDowntownInlayHigh | 126374080453878 |
| GateDowntownInlayLow | 121860079564829 |
| GateDowntownInlayMid | 129558520019215 |
| GateDowntownPlinth | 86735613167602 |
| GateDustyColumns | 86245591782804 |
| GateDustyCrest | 102095830213239 |
| GateDustyCrown | 108965219161951 |
| GateDustyInlayHigh | 92396752854278 |
| GateDustyInlayLow | 88775367360936 |
| GateDustyInlayMid | 83749599509288 |
| GateDustyPlinth | 81607640523569 |
| GateLockedPlaque | 85776840996865 |
| GatePadlockBody | 114895657400713 |
| GatePadlockShackle | 95042551202674 |
| GateRequirementPlaque | 91408729218646 |
| GateSummitColumns | 101537543480464 |
| GateSummitCrest | 72855068822850 |
| GateSummitCrown | 76667204899795 |
| GateSummitInlayHigh | 135304094950228 |
| GateSummitInlayLow | 107433432392469 |
| GateSummitInlayMid | 115384570334359 |
| GateSummitPlinth | 103260941940716 |
| HazardStrip | 129733081613401 |
| LeaderboardCapRail | 118478916447686 |
| LeaderboardFrame | 91801326868428 |
| LeaderboardLampLens | 135435933408871 |
| LeaderboardTextFace | 127784702289834 |
| LightPost | 122928044538401 |
| MarqueeBulb | 125065021393580 |
| OilCanDisplay | 102895488946455 |
| Parasol | 129523374466942 |
| ParasolTeal | 117941484620466 |
| ParkBin | 136795891733710 |
| ParkingArrow | 138960354307095 |
| PicnicTable | 140641508048127 |
| Planter | 110833334763085 |
| PlotGateAccent | 108705556612994 |
| PlotGateBeam | 106966488738990 |
| PlotGateChecker | 77387230157770 |
| PlotGateFenceStub | 78019452229411 |
| PlotGateFlagpoles | 134605803320037 |
| PlotGateHedgeStub | 131465059707764 |
| PlotGateLamps | 71683574906675 |
| PlotGatePillars | 105347357049574 |
| PlotGateStartLine | 94199148538209 |
| RarityRing | 107953177744195 |
| RollUpDoor | 91711726836059 |
| RoofVent | 110708731255555 |
| StuntApron | 71107574763446 |
| StuntCone | 118093047831211 |
| StuntEndBarrier | 95306844036294 |
| StuntFlag | 86517682558438 |
| StuntGantry | 104817121227162 |
| StuntGridMarkings | 93445278377528 |
| StuntLoop | 75327562518478 |
| StuntPodium | 81526632499772 |
| StuntSignFaceBoard | 78604543460492 |
| StuntSignFaceComingSoon | 73999005641583 |
| StuntSignFaceLettering | 79167923727867 |
| StuntStartLightHousing | 81815017911080 |
| StuntStartLightLens | 118536850189116 |
| StuntTireRow | 90528486626324 |
| TireRack | 137956286102168 |
| TireStack | 105539546634049 |
| ToolCart | 116316038567016 |
| ToolWall | 82901783754911 |
| TurntableDisc | 138097925181855 |
| WallLight | 124235524460081 |
| WrenchTireSculpture | 129297331288501 |

## Speedway kit (imported 2026-10-28, Adam, 3D Importer, island-kit-speedway/island-kit.obj)

55 meshes, 16,827 triangles, recipe `assets/island/kit/kit_speedway.py`, existing palette only (no new image). Uploaded under Adam's user account (peskaface, 2393473976) on Adam's choice because the account is in no Roblox group yet; a group-owned re-import replaces these (`vault/design/specs/island-group-reimport.md`). Checked with `Hub/Preview/ImportCheck`: 55 found, none missing, extra or duplicated, sizes within 0.01. Ids also in `src/shared/Island/Speedway/KitIds.luau`.

| Mesh | Id |
|---|---|
| SwAnnouncerBooth | 124453131187665 |
| SwBigScreen | 136313621591068 |
| SwBleachers | 116247810996339 |
| SwBlimp | 90422652853307 |
| SwCatchFence | 118467531984872 |
| SwColumn | 117122389431761 |
| SwColumnCap | 138360257717620 |
| SwConfettiCannon | 86449102782819 |
| SwFanA | 78659021360351 |
| SwFanArmA | 78174090582827 |
| SwFanArmB | 92288988788911 |
| SwFanArmC | 128032313986312 |
| SwFanArmD | 134667519052344 |
| SwFanB | 135244994677708 |
| SwFanC | 78827618381473 |
| SwFanD | 78662527393225 |
| SwFireworkRack | 125124780517169 |
| SwFlameDecal | 93193112513464 |
| SwFloodTower | 91154333937804 |
| SwFoldingChair | 118657963872263 |
| SwGantry | 74403998767331 |
| SwGantryGold | 84586293883784 |
| SwGrandstandBay | 80000123062400 |
| SwGuardRail | 118243041147792 |
| SwHayRun | 71403699224391 |
| SwLapBoard | 82939533196986 |
| SwLemonadeStand | 88358586428374 |
| SwLoopTrack | 125969216625674 |
| SwMechanic | 85414037662565 |
| SwOfficialArm | 127574675253827 |
| SwOfficialBody | 108302391421797 |
| SwOfficialPodium | 99851458414418 |
| SwOrangeBarrier | 116584146015210 |
| SwOwnerSign | 114585653931779 |
| SwPaintedShed | 100881923990640 |
| SwPennantPole | 133219469923618 |
| SwPitGarage | 85056047877073 |
| SwPreviewCar | 114289274081549 |
| SwRollDoor | 137736104496512 |
| SwRoofSection | 136803859882416 |
| SwRopeFence | 130736182708379 |
| SwRustyShed | 74007209717289 |
| SwSnackCart | 124620820513366 |
| SwStartBoard | 108638704239839 |
| SwStartLights | 91248060101322 |
| SwStatueCar | 107153665426811 |
| SwStatuePedestal | 84105899812591 |
| SwToolChest | 127404059896137 |
| SwTyreRun | 129182236325606 |
| SwTyreStackTall | 134733406920013 |
| SwTyreWall | 75467866278108 |
| SwWaterBarrel | 71014321583426 |
| SwWheelbarrow | 92646788953541 |
| SwWonkyStick | 107697770547663 |
| SwWrench | 75450568807779 |

## Raceway round 2 meshes (2026-10-29, waiting for the guided import)

Recipe `assets/island/kit/kit_speedway.py`, existing palette only (no new image). Package `Car-Hop-Art/island-kit-speedway/raceway-round2.obj` (written by `export_subset.py`, only the 9 changed or new meshes). Until the import, they load from the session preview mesh data (`Lane3_SpeedwayKitData`, Adam's island preview project only). Ledger: `vault/design/specs/raceway-round2-ledger.md`.

| Mesh | Triangles | Why | Id |
|---|---|---|---|
| SwBleachers | 366 | repainted: plain cream fascia, navy lower stripe, teal end stripes; the sponsor plate removed | waiting (old 116247810996339 kept in `KitIds.Superseded`) |
| SwGrandstandBay | 932 | repainted: plain cream inset on the navy fascia; the sponsor plate removed | waiting (old 80000123062400 kept) |
| SwBlimp | 532 | repainted: cream, navy underside, coral side stripe, teal fins; the two text plaques removed | waiting (old 90422652853307 kept) |
| SwRacewayShop | 698 | new: the Raceway shop booth (9 x 7 x 8.5) | waiting |
| SwKeeperBody | 248 | new: the shopkeeper's body and head | waiting |
| SwKeeperArm | 56 | new: the shopkeeper's arm (both sides) | waiting |
| SwParkingSign | 142 | new: the parking sign board and post | waiting |
| SwBayBarrierPost | 88 | new: the next bay's barrier post | waiting |
| SwBayBarrierArm | 396 | new: the barrier arm with the ADD SPOT plaque | waiting |

No uploaded mesh in the Speedway kit carries lettering: every sponsor name and the blimp's CAR HOP were SurfaceGui text. The four banked-wall banner images (ZOOPA FIZZ, CRUNCHKIN PUFFS, STICKYTOE TYRES, WOBBLEBOT TOYS) have their names baked in; they stay uploaded but nothing references them.

## Speedway sounds under test (2026-10-28; Creator Store audio, not uploaded)

| Use | Asset | Id | Source | In game |
|---|---|---|---|---|
| Breeze (levels 1-2) | Barstow Wind Light Blustery Low Howl 1 (SFX), 11.9 s | 9113286782 | ProSoundEffects | loop, volume 0.12, two nearest plots |
| Crowd murmur (level 3 on) | Theatre Crowd 3 (SFX), 36 s | 9119996106 | ProSoundEffects | loop, volume 0.05 to 0.2 by level |
| Cheer (Rare or rarer finish) | Wrestling Crowd 3 (SFX), 4.3 s | 9120974378 | ProSoundEffects | one-shot, volume 0.22, at most every 4 s |
| Horn (level 12, Legendary finish) | Vehicle Horn Short Long Honks 4 (SFX), 0.7 s | 9120385769 | ProSoundEffects | one-shot, volume 0.25, at most every 12 s |

All play in SoundGroup `Lane3Speedway`; licence text **not verified** (same status as the island sounds above). Heard in the recorded review clips (mean -44 dB, peak -26 dB over the level 1 to 12 clip); Adam's listening check pending.

## Group-owned re-import (2026-10-31)

Adam re-imported every island and Raceway asset in use under the group **LEGION STUDI0S** (group 74306252) with Studio's 3D Importer, in his private island test place: four files in `Car-Hop-Art/upload-legion-island-2026-10-31/` (151 island meshes, 97 Task 4 meshes, 61 Raceway meshes, and 53 images carried as textures of flat squares). Checked by Claude Code the same day: one copy of each import; all 362 new ids report Creator Group 74306252 on economy.roblox.com (309 meshes, 53 images); all 309 mesh sizes within 0.01 of the two KitManifests. Ids swapped in `src/island/Hub/Environment/AssetIds.luau` and `src/shared/Island/Speedway/KitIds.luau`. The earlier ids below were uploaded under peskaface and are retired (not referenced). Not re-imported because nothing uses them: SignArt BannerA to BannerD (the removed sponsor banners) and Kiosk; the Creator Store sounds are not ours to upload.

| Name | Table | New id (group) | Retired id (peskaface) |
|---|---|---|---|
| WaterBody | Textures | 76448861868809 | 118829614143752 |
| WaterStrandsFast | Textures | 84198602448972 | 123432307138321 |
| WaterStrandsSlow | Textures | 126401069049014 | 80338760305637 |
| WaterHighlights | Textures | 126946943900205 | 111578838235188 |
| WaterSpray | Textures | 129096095057922 | 91396665960467 |
| FoamTile | Textures | 83639401265553 | 122795342152257 |
| FoamPatch | Textures | 133773604286652 | 99023600024403 |
| Ripple | Textures | 110000918142561 | 106407842749322 |
| Droplet | Textures | 104718015917348 | 109536997721772 |
| Mist | Textures | 100353530625667 | 114900109756669 |
| Rainbow | Textures | 92530769791430 | 72537598666370 |
| Sparkle | Textures | 124856660251107 | 87030054749344 |
| Glow | Textures | 104162855106857 | 109290330063558 |
| Current | Textures | 90799224483267 | 103576178978702 |
| Chevron | Textures | 131283501116373 | 96352143506498 |
| PortalSwirlA | Textures | 97184972304820 | 92093492199405 |
| PortalSwirlB | Textures | 121384250907605 | 108950429777685 |
| PortalCloudTile | Textures | 140374123745689 | 123976736191333 |
| PortalCore | Textures | 131487211688936 | 71006997459996 |
| PortalVeil | Textures | 133332175362123 | 80047315268792 |
| PortalVeilB | Textures | 106363486085507 | 122267435775183 |
| PortalMask | Textures | 132444414799690 | 112768234647366 |
| PortalBeam | Textures | 97082628992749 | 99849771860096 |
| PortalDepth | Textures | 122344255111090 | 77298104491687 |
| PortalCloudBall | Textures | 102883150299572 | 98562926959140 |
| PortalCloudBallB | Textures | 134123364350479 | 85244900910059 |
| PortalBand | Textures | 95138204365042 | 90038845373360 |
| GroundPool | Textures | 130753937124264 | 100675320642077 |
| Mote | Textures | 118165875852224 | 128577684526564 |
| Ember | Textures | 78738981505727 | 117732180184030 |
| Shimmer | Textures | 136941114758210 | 113969750355597 |
| Pennants | Textures | 109986080076934 | 129394675251472 |
| FlagChecker | Textures | 107933231350357 | 113814256495528 |
| FlagStripesA | Textures | 109705567230453 | 97908223611462 |
| FlagStripesB | Textures | 77641612149566 | 81318556896008 |
| FlagStar | Textures | 96696844387606 | 93044374349935 |
| HeaderHotDog | SignArt | 125700113190099 | 111209092984557 |
| HeaderIceCream | SignArt | 135153505969890 | 131134583059892 |
| HeaderLemonade | SignArt | 108197480384893 | 89775297450442 |
| HeaderPopcorn | SignArt | 107137808128779 | 132673341754270 |
| OwnerBanner | SignArt | 99028570616783 | 103587041167945 |
| Nameplate | SignArt | 121326877498191 | 101228763400140 |
| IconPortal | SignArt | 90391570744372 | 101447318056634 |
| IconGarage | SignArt | 94562992202885 | 139283194336735 |
| IconStunt | SignArt | 117013989776586 | 136778609492666 |
| IconPlots | SignArt | 94122317601645 | 92929508456128 |
| IconLake | SignArt | 120121071349820 | 135234520936833 |
| IconArrow | SignArt | 121618950997210 | 75221826934795 |
| IconCoin | SignArt | 83470451230913 | 99492109262754 |
| IconTick | SignArt | 135235800672495 | 103260929176535 |
| IconLock | SignArt | 133725466100857 | 125248424108608 |
| IconWrench | SignArt | 92414956875461 | 125308628941246 |
| Arrowhead | Meshes | 138244067049295 | 77734052464842 |
| BedOval | Meshes | 136099171822469 | 75182510100315 |
| BedRound | Meshes | 123249717980851 | 78898513024992 |
| Bench | Meshes | 123517872546619 | 81472931283188 |
| BerryBush | Meshes | 99914521306375 | 113381535893436 |
| BirchA_Canopy | Meshes | 100806252422298 | 95358946867963 |
| BirchA_Trunk | Meshes | 120487144662684 | 113392689229837 |
| BirchB_Canopy | Meshes | 103662231513650 | 76466785156402 |
| BirchB_Trunk | Meshes | 81836875055169 | 71794440829829 |
| BirchC_Canopy | Meshes | 106621954448856 | 77471118350791 |
| BirchC_Trunk | Meshes | 112381046500417 | 107504512366800 |
| BlossomA_Canopy | Meshes | 91241113693387 | 85623663058251 |
| BlossomA_Trunk | Meshes | 82673324179312 | 71890708802809 |
| BlossomB_Canopy | Meshes | 91244754126777 | 115945038397849 |
| BlossomB_Trunk | Meshes | 132557397556033 | 116376114509074 |
| BlossomC_Canopy | Meshes | 71195676597725 | 70583076825211 |
| BlossomC_Trunk | Meshes | 74838286273378 | 70593040224453 |
| BlueWildflowers | Meshes | 74966194657570 | 140362334076502 |
| BoulderA | Meshes | 123763171923437 | 73936552182889 |
| BoulderB | Meshes | 97554163859875 | 108729967021241 |
| BoulderC | Meshes | 135204461703163 | 99527827208631 |
| BridgeAvenue | Meshes | 103746904933957 | 132499975394188 |
| BridgeAvenueOpen | Meshes | 79961433123556 | 78688525290880 |
| BridgeGarden | Meshes | 132052014907256 | 119984148857166 |
| BridgeLakeside | Meshes | 80321789639417 | 74401136745211 |
| BuntingString | Meshes | 137727498083978 | 90642820165813 |
| BushLarge | Meshes | 96440781051500 | 107937719458701 |
| BushMedium | Meshes | 84665955701915 | 112084388357819 |
| BushSmall | Meshes | 131556303922904 | 89066567685874 |
| ButterflyBlueWingL | Meshes | 103115458033263 | 84463884097172 |
| ButterflyBlueWingR | Meshes | 102194139048182 | 96381297933560 |
| ButterflyBody | Meshes | 121749629890653 | 83296309836118 |
| ButterflyWingL | Meshes | 92790805942751 | 110344634719101 |
| ButterflyWingR | Meshes | 111632244403294 | 77372830185761 |
| CarTopiary | Meshes | 99765473953877 | 124108261960990 |
| Cattails | Meshes | 78963979739123 | 96641977331650 |
| Clover | Meshes | 130464549817210 | 119625716970260 |
| Daisies | Meshes | 119049798406520 | 72553714073439 |
| Dock | Meshes | 123866895240112 | 121994894630420 |
| DragonflyBody | Meshes | 96562316547990 | 116300255540446 |
| DragonflyWings | Meshes | 122096696191279 | 96240530729511 |
| Driftwood | Meshes | 137946365287756 | 79754565581073 |
| Duck | Meshes | 99537883114657 | 82641503340866 |
| Duckling | Meshes | 135443294412364 | 114222618214481 |
| Duckweed | Meshes | 79018509318981 | 96016381404577 |
| FenceSegment | Meshes | 103954822123918 | 75883738881066 |
| FernA | Meshes | 105557009091999 | 125414860170513 |
| FernB | Meshes | 106862977771018 | 132864443197145 |
| FishOrange | Meshes | 85267243082735 | 93198247823924 |
| FishSilver | Meshes | 98519047787114 | 74193987938908 |
| FloatingLeaf | Meshes | 124766280568815 | 117142848195882 |
| FloatingPetal | Meshes | 82754658171119 | 102542786153320 |
| FloweringShrub | Meshes | 134148931332873 | 97158756624560 |
| FountainTiered | Meshes | 131932970374170 | 87095967163960 |
| FountainWater | Meshes | 79696989097258 | 116528389038986 |
| Frog | Meshes | 83838167593408 | 124872657363209 |
| FruitA_Canopy | Meshes | 138914998198618 | 91617448874937 |
| FruitA_Trunk | Meshes | 75236867446405 | 125813419406213 |
| FruitB_Canopy | Meshes | 108283244964258 | 82529345438206 |
| FruitB_Trunk | Meshes | 132892254460984 | 77808359429337 |
| FruitC_Canopy | Meshes | 126003894759778 | 110918401683196 |
| FruitC_Trunk | Meshes | 107940472242898 | 138730259128149 |
| Gazebo | Meshes | 133055578432871 | 132930457317667 |
| GrassTuft | Meshes | 108426784312972 | 87769624057571 |
| GrassTuftWide | Meshes | 107798705738594 | 85162093459834 |
| HedgeLow | Meshes | 136175074613591 | 94290153677107 |
| HedgeStraight | Meshes | 112315738239450 | 115214796420911 |
| HollowLog | Meshes | 100906492502147 | 133502513071015 |
| HotDogCart | Meshes | 118492261494970 | 128077008495216 |
| IceCreamStand | Meshes | 138353957710700 | 72102386161007 |
| Irises | Meshes | 76723241488075 | 124819745705979 |
| LampGlass | Meshes | 76899708162034 | 120377499915257 |
| LampPost | Meshes | 125125452765458 | 139674403634313 |
| Lavender | Meshes | 76906490732445 | 130846919850597 |
| LeafLitter | Meshes | 129518020398457 | 134131919266803 |
| LemonadeStand | Meshes | 76858034399256 | 125464775917653 |
| LilyFlowerPink | Meshes | 102119291559534 | 76891640080088 |
| LilyFlowerWhite | Meshes | 129707095646286 | 82425262882452 |
| LilyPadL | Meshes | 132427788258766 | 111100338080785 |
| LilyPadM | Meshes | 112030292927211 | 92817792476653 |
| LilyPadS | Meshes | 118763336299344 | 75828509671473 |
| MossyRockA | Meshes | 85574033919182 | 116711716740489 |
| MossyRockB | Meshes | 126736135358175 | 100088279100790 |
| MushroomsBrown | Meshes | 74405672058131 | 72630651084382 |
| MushroomsRed | Meshes | 88589283701831 | 132931914368107 |
| OakA_Canopy | Meshes | 90068725660607 | 125079363526751 |
| OakA_Trunk | Meshes | 106828885086436 | 81838596725252 |
| OakB_Canopy | Meshes | 134749240337474 | 114513892252367 |
| OakB_Trunk | Meshes | 89569880898707 | 133799468476153 |
| OakC_Canopy | Meshes | 81252642857922 | 137935820165648 |
| OakC_Trunk | Meshes | 120072789985855 | 72640563796108 |
| PineA_Canopy | Meshes | 92692882264575 | 86571721057312 |
| PineA_Trunk | Meshes | 102208994723568 | 126489468362585 |
| PineB_Canopy | Meshes | 100564242489410 | 119200173785375 |
| PineB_Trunk | Meshes | 138157650015202 | 91453775827473 |
| PineC_Canopy | Meshes | 79276284052740 | 96071087065535 |
| PineC_Trunk | Meshes | 111053653938671 | 113986667544582 |
| PineSapling_Canopy | Meshes | 131316584239813 | 108593342174832 |
| PineSapling_Trunk | Meshes | 136990516574113 | 125052020212163 |
| PopcornCart | Meshes | 96408021272336 | 140620817482021 |
| Poppies | Meshes | 75527608430305 | 134198513847375 |
| Raccoon | Meshes | 92439139003226 | 78064153570396 |
| RaccoonHead | Meshes | 125051843028649 | 122251191819978 |
| Reeds | Meshes | 123368172491352 | 138621409272637 |
| RosesPink | Meshes | 75042050246474 | 133767793962188 |
| RosesRed | Meshes | 124625690855684 | 137302351764375 |
| Rowboat | Meshes | 122970355945451 | 111594792382992 |
| Rushes | Meshes | 95077880123937 | 94073208976012 |
| Signpost | Meshes | 89954063283562 | 75373199680961 |
| SteppingStone | Meshes | 88232267625126 | 114567733775797 |
| Stump | Meshes | 125779606546056 | 97538794770552 |
| Sunflowers | Meshes | 74211938713050 | 70924896477467 |
| TallGrass | Meshes | 132002952081416 | 96033594782233 |
| TieredA_Canopy | Meshes | 100114007581824 | 72964718415062 |
| TieredA_Trunk | Meshes | 108201404836746 | 73674256532039 |
| TieredB_Canopy | Meshes | 115154861337602 | 88044922593595 |
| TieredB_Trunk | Meshes | 71984161373179 | 128171113138801 |
| TieredC_Canopy | Meshes | 72869799411568 | 70677452623426 |
| TieredC_Trunk | Meshes | 112721320223055 | 109536531531788 |
| TopiaryBall | Meshes | 105781276915527 | 89575297387819 |
| TopiaryCone | Meshes | 139714947194490 | 72356799315602 |
| TulipsRed | Meshes | 70585910939414 | 125564876170957 |
| TulipsYellow | Meshes | 140641152811990 | 98770109311258 |
| UmbrellaA_Canopy | Meshes | 120894937018074 | 91847269200413 |
| UmbrellaA_Trunk | Meshes | 137649536930632 | 133742908940135 |
| UmbrellaB_Canopy | Meshes | 97435314449821 | 74855981514851 |
| UmbrellaB_Trunk | Meshes | 122983901532353 | 101735978642638 |
| UmbrellaC_Canopy | Meshes | 114164761665601 | 108564507264176 |
| UmbrellaC_Trunk | Meshes | 121305472090972 | 109121511812165 |
| WetRockA | Meshes | 114681583860533 | 99844062490263 |
| WetRockB | Meshes | 140616452972253 | 115292109378113 |
| WillowA_Canopy | Meshes | 126630738198123 | 100724359605792 |
| WillowA_Trunk | Meshes | 75933431885207 | 95619268368185 |
| WillowB_Canopy | Meshes | 127356487466250 | 117793886163427 |
| WillowB_Trunk | Meshes | 83709653441289 | 78855509300039 |
| WillowC_Canopy | Meshes | 113473301166191 | 117322934216935 |
| WillowC_Trunk | Meshes | 99167092069684 | 94489845710982 |
| FountainGrand | Meshes | 134250858109840 | 138476226884315 |
| FountainGrandWater | Meshes | 97077137017352 | 118135225656541 |
| PlazaMosaic | Meshes | 137077011185169 | 92746874626451 |
| ChainAnchorPost | Meshes | 116104471794716 | 114737667930382 |
| ChainLink | Meshes | 114214302961113 | 99515412067221 |
| Flagpole | Meshes | 129548914805122 | 82002796817463 |
| HeaderBoard | Meshes | 131034066017721 | 89758117345462 |
| KioskBooth | Meshes | 122977264336017 | 137774673874849 |
| PadlockBody | Meshes | 126446131938774 | 114107687304189 |
| PadlockShackle | Meshes | 80634870609051 | 97927780932934 |
| PlotGate | Meshes | 132284962738302 | 83397197959185 |
| PortalSign | Meshes | 96622363246047 | 75612522407601 |
| SignpostBoard | Meshes | 71490569687047 | 128562147587889 |
| SignpostPost | Meshes | 76170109920794 | 70440998829645 |
| AirPump | Meshes | 85075129657610 | 110204729376180 |
| BedAvenueArc | Meshes | 83055271600743 | 103579632050241 |
| BedAvenueStraight | Meshes | 111747692241584 | 135442988433072 |
| BedCornerFillet | Meshes | 99237896497111 | 118604528597435 |
| BedFountainArc | Meshes | 138519763827753 | 134390751624734 |
| BedJunctionRound | Meshes | 127970609183087 | 88027591948797 |
| Bollard | Meshes | 137304579092978 | 130288057862761 |
| BridgeRiverApproach | Meshes | 99201813850591 | 72542935568044 |
| BridgeRiverAvenue | Meshes | 80517554710181 | 80680695628375 |
| CarLift | Meshes | 121987728120237 | 119346173440460 |
| CheckeredBand | Meshes | 138048567006496 | 102866985026681 |
| DrumRed | Meshes | 71870413657309 | 138825731788822 |
| DrumTeal | Meshes | 75797387695559 | 124127388745386 |
| ForecourtCurb | Meshes | 76405410501889 | 93062744759345 |
| GarageBench | Meshes | 102867336577100 | 128621570342938 |
| GarageFlagpole | Meshes | 105177158117178 | 114307514216865 |
| GarageGlazing | Meshes | 132157148972532 | 74974275532912 |
| GarageInterior | Meshes | 87185201084021 | 129388325886092 |
| GarageLights | Meshes | 124692895162585 | 83123427499636 |
| GarageShell | Meshes | 114734875520385 | 121491509701515 |
| GarageSign | Meshes | 77309746815929 | 97116362523762 |
| GarageStructure | Meshes | 79270006556493 | 98702145130383 |
| GateChainLink | Meshes | 124272794650745 | 73207672300684 |
| GateChainRun | Meshes | 95430339517072 | 76766417787279 |
| GateChainWrap | Meshes | 110960492207804 | 130443776899054 |
| GateDowntownColumns | Meshes | 108532592863645 | 100622023476660 |
| GateDowntownCrest | Meshes | 125826091705271 | 136625187784489 |
| GateDowntownCrown | Meshes | 78065550426898 | 76948856455160 |
| GateDowntownInlayHigh | Meshes | 138236598259286 | 126374080453878 |
| GateDowntownInlayLow | Meshes | 73978543922047 | 121860079564829 |
| GateDowntownInlayMid | Meshes | 122317866532106 | 129558520019215 |
| GateDowntownPlinth | Meshes | 107278482923295 | 86735613167602 |
| GateDustyColumns | Meshes | 117297712279771 | 86245591782804 |
| GateDustyCrest | Meshes | 80580172831278 | 102095830213239 |
| GateDustyCrown | Meshes | 84029568732331 | 108965219161951 |
| GateDustyInlayHigh | Meshes | 81946948345013 | 92396752854278 |
| GateDustyInlayLow | Meshes | 87020772643400 | 88775367360936 |
| GateDustyInlayMid | Meshes | 121012710941260 | 83749599509288 |
| GateDustyPlinth | Meshes | 110839059652265 | 81607640523569 |
| GateLockedPlaque | Meshes | 91281029170193 | 85776840996865 |
| GatePadlockBody | Meshes | 140163082771569 | 114895657400713 |
| GatePadlockShackle | Meshes | 112064977038149 | 95042551202674 |
| GateRequirementPlaque | Meshes | 71624689678209 | 91408729218646 |
| GateSummitColumns | Meshes | 116585945901808 | 101537543480464 |
| GateSummitCrest | Meshes | 75609991349650 | 72855068822850 |
| GateSummitCrown | Meshes | 87745284432156 | 76667204899795 |
| GateSummitInlayHigh | Meshes | 121201737129889 | 135304094950228 |
| GateSummitInlayLow | Meshes | 132503600474169 | 107433432392469 |
| GateSummitInlayMid | Meshes | 122432717876953 | 115384570334359 |
| GateSummitPlinth | Meshes | 123915058031834 | 103260941940716 |
| HazardStrip | Meshes | 131308067592934 | 129733081613401 |
| LeaderboardCapRail | Meshes | 112756730022409 | 118478916447686 |
| LeaderboardFrame | Meshes | 113908519666761 | 91801326868428 |
| LeaderboardLampLens | Meshes | 74675984162564 | 135435933408871 |
| LeaderboardTextFace | Meshes | 94740208248666 | 127784702289834 |
| LightPost | Meshes | 136240285485160 | 122928044538401 |
| MarqueeBulb | Meshes | 107792494255734 | 125065021393580 |
| OilCanDisplay | Meshes | 70684156665297 | 102895488946455 |
| Parasol | Meshes | 96290961601445 | 129523374466942 |
| ParasolTeal | Meshes | 137648743329802 | 117941484620466 |
| ParkBin | Meshes | 105614179605967 | 136795891733710 |
| ParkingArrow | Meshes | 131426764702576 | 138960354307095 |
| PicnicTable | Meshes | 70679924563183 | 140641508048127 |
| Planter | Meshes | 74716533726124 | 110833334763085 |
| PlotGateAccent | Meshes | 116141689733548 | 108705556612994 |
| PlotGateBeam | Meshes | 93468975278723 | 106966488738990 |
| PlotGateChecker | Meshes | 136149495518732 | 77387230157770 |
| PlotGateFenceStub | Meshes | 124053386639427 | 78019452229411 |
| PlotGateFlagpoles | Meshes | 139021453048462 | 134605803320037 |
| PlotGateHedgeStub | Meshes | 81661540109869 | 131465059707764 |
| PlotGateLamps | Meshes | 101357819746042 | 71683574906675 |
| PlotGatePillars | Meshes | 89083749317837 | 105347357049574 |
| PlotGateStartLine | Meshes | 73549160337847 | 94199148538209 |
| RarityRing | Meshes | 75126108953276 | 107953177744195 |
| RollUpDoor | Meshes | 108434316528609 | 91711726836059 |
| RoofVent | Meshes | 73487211272948 | 110708731255555 |
| StuntApron | Meshes | 133474972767713 | 71107574763446 |
| StuntCone | Meshes | 128735165623877 | 118093047831211 |
| StuntEndBarrier | Meshes | 136763665082578 | 95306844036294 |
| StuntFlag | Meshes | 90426133652776 | 86517682558438 |
| StuntGantry | Meshes | 133362520173926 | 104817121227162 |
| StuntGridMarkings | Meshes | 133704870770169 | 93445278377528 |
| StuntLoop | Meshes | 73133440812210 | 75327562518478 |
| StuntPodium | Meshes | 135352583697109 | 81526632499772 |
| StuntSignFaceBoard | Meshes | 109317817309224 | 78604543460492 |
| StuntSignFaceComingSoon | Meshes | 77108293711707 | 73999005641583 |
| StuntSignFaceLettering | Meshes | 109878260834399 | 79167923727867 |
| StuntStartLightHousing | Meshes | 91530788392427 | 81815017911080 |
| StuntStartLightLens | Meshes | 98808475067412 | 118536850189116 |
| StuntTireRow | Meshes | 123628473301675 | 90528486626324 |
| TireRack | Meshes | 109408017259964 | 137956286102168 |
| TireStack | Meshes | 80992238482595 | 105539546634049 |
| ToolCart | Meshes | 102543773473842 | 116316038567016 |
| ToolWall | Meshes | 117340040095286 | 82901783754911 |
| TurntableDisc | Meshes | 135928862713310 | 138097925181855 |
| WallLight | Meshes | 102100752450863 | 124235524460081 |
| WrenchTireSculpture | Meshes | 107898777545853 | 129297331288501 |
| Palette | Palette | 128169045252325 | 134121745235322 |
| SwAnnouncerBooth | Speedway Meshes | 85280690019741 | 124453131187665 |
| SwBayBarrierArm | Speedway Meshes | 102661645918978 | 99420121739252 |
| SwBayBarrierPost | Speedway Meshes | 72382460044152 | 98664871775585 |
| SwBigScreen | Speedway Meshes | 128201415244874 | 136313621591068 |
| SwBleachers | Speedway Meshes | 107432199937261 | 87693115942075 |
| SwBlimp | Speedway Meshes | 96699312485170 | 80603776193517 |
| SwCatchFence | Speedway Meshes | 100543478185899 | 118467531984872 |
| SwColumn | Speedway Meshes | 115247428990660 | 117122389431761 |
| SwColumnCap | Speedway Meshes | 123422088082154 | 138360257717620 |
| SwConfettiCannon | Speedway Meshes | 82865014588770 | 86449102782819 |
| SwFanA | Speedway Meshes | 83121163075535 | 78659021360351 |
| SwFanArmA | Speedway Meshes | 75049768549378 | 78174090582827 |
| SwFanArmB | Speedway Meshes | 120825261111737 | 92288988788911 |
| SwFanArmC | Speedway Meshes | 126747982610886 | 128032313986312 |
| SwFanArmD | Speedway Meshes | 115678520260583 | 134667519052344 |
| SwFanB | Speedway Meshes | 91123601332587 | 135244994677708 |
| SwFanC | Speedway Meshes | 87393623373212 | 78827618381473 |
| SwFanD | Speedway Meshes | 117245066153917 | 78662527393225 |
| SwFireworkRack | Speedway Meshes | 129517648518270 | 125124780517169 |
| SwFlameDecal | Speedway Meshes | 127373852109905 | 93193112513464 |
| SwFloodTower | Speedway Meshes | 103538610674357 | 91154333937804 |
| SwFoldingChair | Speedway Meshes | 115166621593495 | 118657963872263 |
| SwGantry | Speedway Meshes | 91999865224306 | 74403998767331 |
| SwGantryGold | Speedway Meshes | 120131138578527 | 84586293883784 |
| SwGrandstandBay | Speedway Meshes | 103599785391659 | 95312713352772 |
| SwGuardRail | Speedway Meshes | 136867342464008 | 118243041147792 |
| SwHayRun | Speedway Meshes | 140031111271962 | 71403699224391 |
| SwKeeperArm | Speedway Meshes | 102504505914546 | 136090235910283 |
| SwKeeperBody | Speedway Meshes | 102350514652723 | 129469051229063 |
| SwLapBoard | Speedway Meshes | 136055088029366 | 82939533196986 |
| SwLemonadeStand | Speedway Meshes | 97741292989096 | 88358586428374 |
| SwLoopTrack | Speedway Meshes | 101864195807167 | 125969216625674 |
| SwMechanic | Speedway Meshes | 135045771420514 | 85414037662565 |
| SwOfficialArm | Speedway Meshes | 107245427682978 | 127574675253827 |
| SwOfficialBody | Speedway Meshes | 79915609641268 | 108302391421797 |
| SwOfficialPodium | Speedway Meshes | 140449945546404 | 99851458414418 |
| SwOrangeBarrier | Speedway Meshes | 127964033639594 | 116584146015210 |
| SwOwnerSign | Speedway Meshes | 124441916586855 | 114585653931779 |
| SwPaintedShed | Speedway Meshes | 91248138191970 | 100881923990640 |
| SwParkingSign | Speedway Meshes | 108613965243569 | 97551999119993 |
| SwPennantPole | Speedway Meshes | 78922292885261 | 133219469923618 |
| SwPitGarage | Speedway Meshes | 123837917076829 | 85056047877073 |
| SwPreviewCar | Speedway Meshes | 137630075868196 | 114289274081549 |
| SwRacewayShop | Speedway Meshes | 88675832942368 | 136327841605965 |
| SwRollDoor | Speedway Meshes | 73057985208386 | 137736104496512 |
| SwRoofSection | Speedway Meshes | 121872970793697 | 136803859882416 |
| SwRopeFence | Speedway Meshes | 138483697478646 | 130736182708379 |
| SwRustyShed | Speedway Meshes | 76838557009265 | 74007209717289 |
| SwSnackCart | Speedway Meshes | 95141887124611 | 124620820513366 |
| SwStartBoard | Speedway Meshes | 127792453703226 | 108638704239839 |
| SwStartLights | Speedway Meshes | 104205558358843 | 91248060101322 |
| SwStatueCar | Speedway Meshes | 128442367976976 | 107153665426811 |
| SwStatuePedestal | Speedway Meshes | 102560465524845 | 84105899812591 |
| SwToolChest | Speedway Meshes | 126048126880224 | 127404059896137 |
| SwTyreRun | Speedway Meshes | 132481136278127 | 129182236325606 |
| SwTyreStackTall | Speedway Meshes | 126825259786624 | 134733406920013 |
| SwTyreWall | Speedway Meshes | 86760996331774 | 75467866278108 |
| SwWaterBarrel | Speedway Meshes | 84553120810312 | 71014321583426 |
| SwWheelbarrow | Speedway Meshes | 109677414305240 | 92646788953541 |
| SwWonkyStick | Speedway Meshes | 101710054055028 | 107697770547663 |
| SwWrench | Speedway Meshes | 106420477941889 | 75450568807779 |
