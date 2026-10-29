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

## Speedway sounds under test (2026-10-28; Creator Store audio, not uploaded)

| Use | Asset | Id | Source | In game |
|---|---|---|---|---|
| Breeze (levels 1-2) | Barstow Wind Light Blustery Low Howl 1 (SFX), 11.9 s | 9113286782 | ProSoundEffects | loop, volume 0.12, two nearest plots |
| Crowd murmur (level 3 on) | Theatre Crowd 3 (SFX), 36 s | 9119996106 | ProSoundEffects | loop, volume 0.05 to 0.2 by level |
| Cheer (Rare or rarer finish) | Wrestling Crowd 3 (SFX), 4.3 s | 9120974378 | ProSoundEffects | one-shot, volume 0.22, at most every 4 s |
| Horn (level 12, Legendary finish) | Vehicle Horn Short Long Honks 4 (SFX), 0.7 s | 9120385769 | ProSoundEffects | one-shot, volume 0.25, at most every 12 s |

All play in SoundGroup `Lane3Speedway`; licence text **not verified** (same status as the island sounds above). Heard in the recorded review clips (mean -44 dB, peak -26 dB over the level 1 to 12 clip); Adam's listening check pending.
