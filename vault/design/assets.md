---
title: Uploaded Roblox assets (manifest)
tags: [design, assets, manifest, lane3]
status: live (group-owned since 2026-10-31)
date: 2026-10-26
---
# Uploaded Roblox assets

Promised by [[0012-figma-ui-workflow]] (asset manifest) and created in Round 3 ([[hud-round3]]). **Asset ids are not secrets.** The runtime reads the ids from src/lookdev/Downtown/KitIds.luau (generated from this import); source files stay outside Git.

## CURRENT (2026-10-31): everything re-imported under the group LEGION STUDI0S
Adam created the Roblox group **LEGION STUDI0S** (group id **74306252**, owner peskaface) and asked for every Lane 3 import to go under it. He clicked the Studio 3D Importer with Creator = LEGION STUDI0S, Scale Unit Stud, Scale Factor 1. **Every id in use was checked on 2026-10-31 against the Roblox economy API: Creator type Group, id 74306252 (406 of 406).** Full id tables: `src/lookdev/Downtown/KitIds.luau` (B2) and `src/lookdev/Downtown/WorldsKitIds.luau` (Dusty Highway, Summit Pass); raw export outside Git: `Car-Hop-Art/upload-legion-2026-10-31/uploaded-ids-raw.json`.

| Package | Meshes | Palette image (group-owned) | Studio Play check (2026-10-31, HUD playground, seed 2207, uploaded meshes on) |
|---|---|---|---|
| `downtown-kit-b2.obj` (re-import; replaces the 2026-10-26 user-owned copy below) | 180 | MainStreet `rbxassetid://115645565589526`, CityHall `rbxassetid://120361816797873`, HarborBridge `rbxassetid://123078658571358`, Midtown `rbxassetid://117967728274920`, SkylinePark `rbxassetid://120446738978080` | Downtown built: 134 group meshes live in the window, 0 failed to load, colours from MainStreet |
| `worlds-DustyHighway.obj` | 94 | DH `rbxassetid://92626338032695` | Dusty Highway built: 46 group meshes live at the start, 0 failed (the canyon stretch was not walked in Play) |
| `worlds-SummitPass.obj` | 125 | SU `rbxassetid://132433565064493` | Summit Pass built: 34 group meshes live at the start, 0 failed |

- **Palettes:** uploaded as the textures of small carrier models (`palette-carriers.obj` for SU, `palette-carriers-2.obj` for the other six); the importer uploaded each PNG as a group-owned Image. The 1 + 6 carrier quad meshes are also group assets; they are not used.
- **Mistake kept on record:** the first Summit Pass import went up with Creator "Me" (125 meshes owned by the user peskaface). Adam re-imported it under the group; only the group ids are used. The unused user-owned ids are in `Car-Hop-Art/upload-legion-2026-10-31/summit-user-owned-UNUSED.json`.
- **Superseded:** the 2026-10-26 user-owned B2 kit (sections below) stays on Roblox but is no longer referenced.
- **Not in this upload:** the Speedway / Raceway kit (island branch, the island session's work) and the car models (Brian L).
- **Not verified:** loading in a published group-owned experience (nothing is published); every mesh of every route in Play (only the start windows above).

## Ownership and access
- **Creator:** the Roblox user peskaface (userId 2393473976, Adam), the importer's Creator was "Me". Uploaded 2026-10-26 with Upload to Roblox on, Import as Package off, Merge Meshes off, Anchored off. No Robux cost was shown.
- **Group:** Adam is creating a Roblox group in which he and Brian R and Brian L will be owners. Assets do not transfer from a user to a group: if the team wants these meshes and images under the group they must be **re-imported with the group as Creator** and KitIds.luau regenerated. At import time the group was not yet in the importer's Creator list.
- **Privacy:** private to the creator (Roblox default for uploads; not set to Open Use). They load for the owner in Studio; an experience owned by another account or a group needs permission granted per asset. Not verified in a published experience (nothing is published).
- **Source files (outside Git):** Car-Hop-Art/downtown-kit-b2/downtown-kit-b2.obj (meshes), palette-B2-*.png (images), manifest.json, swatches.json; the Blender recipe is ssets/downtown/kit/kit_b2_build.py family. Proposed home: the shared Car Hop source art Drive folder ([[hud-round3-art-dependency-audit]]).

## Images (5 palettes, 256 x 256, 16 x 16 cells, original flat swatches)
| File | Asset id | SHA-256 of the source PNG | Used for |
|---|---|---|---|
| palette-B2-MainStreet.png | `rbxassetid://106035734715405` | `3C2CF811EDE1D188…` | TextureID of the Downtown kit meshes (MainStreet is the default for the whole city now; per-district assignment is a follow-up) |
| palette-B2-CityHall.png | `rbxassetid://140152441733520` | `60719886765FED72…` | TextureID of the Downtown kit meshes (CityHall is the default for the whole city now; per-district assignment is a follow-up) |
| palette-B2-HarborBridge.png | `rbxassetid://87337911136648` | `96FE7ED56CFDE8DF…` | TextureID of the Downtown kit meshes (HarborBridge is the default for the whole city now; per-district assignment is a follow-up) |
| palette-B2-Midtown.png | `rbxassetid://101473795151029` | `4FC37717C9280EC8…` | TextureID of the Downtown kit meshes (Midtown is the default for the whole city now; per-district assignment is a follow-up) |
| palette-B2-SkylinePark.png | `rbxassetid://100343892082907` | `D28BD81EB519BBB1…` | TextureID of the Downtown kit meshes (SkylinePark is the default for the whole city now; per-district assignment is a follow-up) |

## Meshes (180, OBJ package)
Import settings verified on screen before uploading: Scale Unit Stud, Scale Factor 1, File Dimensions 4476.00 x 161.00 x 3052.95 studs, Polygon Count 56,751 (matches the OBJ read on disk: 180 objects, 56,751 triangles). The FBX of the same kit is 100x too large (centimetres) and was **not** used. Every uploaded size was compared with manifest.json: maximum difference 0.0054 studs, 0 mismatches over 0.25 stud. The OBJ carries palette-cell UVs and normals but **no material or texture reference**: colour comes from the palette image set as TextureID.

| Mesh name | Asset id | Uploaded size (studs) | Manifest size | Triangles | Status (2026-10-26) |
|---|---|---|---|---|---|
| B2_Harbor_Bollard | `rbxassetid://137573272804165` | 2.2 x 2.5 x 2.2 | 2.2 x 2.5 x 2.2 | 54 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Containers | `rbxassetid://90872208318128` | 20 x 17.2 x 20 | 20 x 17.2 x 20 | 42 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Crane | `rbxassetid://99544909958214` | 10.894 x 35.514 x 33.027 | 10.89 x 35.51 x 33.03 | 226 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Pier_L4W16 | `rbxassetid://128083802518394` | 91.87 x 19 x 8 | 91.87 x 19 x 8 | 38 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Pier_L4W17 | `rbxassetid://109788110006583` | 95.304 x 19 x 8 | 95.3 x 19 x 8 | 38 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Pier_L4W18 | `rbxassetid://76959424452900` | 98.738 x 19 x 8 | 98.74 x 19 x 8 | 38 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Quay96 | `rbxassetid://80799381275894` | 96 x 24.75 x 12.4 | 96 x 24.75 x 12.4 | 16 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Shed24 | `rbxassetid://77856663788815` | 25.2 x 15 x 17.2 | 25.2 x 15 x 17.2 | 18 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Harbor_Water | `rbxassetid://111223061996253` | 960 x 0.001 x 192 | 960 x 0 x 192 | 96 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Haz_Barrier | `rbxassetid://131894017095272` | 6 x 4.38 x 2.2 | 6 x 4.38 x 2.2 | 210 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Haz_Cone | `rbxassetid://132380534087744` | 2 x 3 x 2 | 2 x 3 x 2 | 108 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Haz_ConstructionLot48 | `rbxassetid://127471318434784` | 48 x 7.6 x 24 | 48 x 7.6 x 24 | 296 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Haz_Crane | `rbxassetid://110080842084355` | 10 x 55.039 x 46.04 | 10 x 55.04 x 46.04 | 1460 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Haz_Oil | `rbxassetid://128134599240259` | 7.753 x 0.003 x 5.415 | 7.75 x 0 x 5.42 | 168 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Haz_Pothole | `rbxassetid://98269342528510` | 5.513 x 0.249 x 7.286 | 5.51 x 0.25 x 7.29 | 168 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Haz_Sign | `rbxassetid://101294311268582` | 4.8 x 7.024 x 2.4 | 4.8 x 7.02 x 2.4 | 94 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Haz_SiteFence | `rbxassetid://86609137999377` | 12.5 x 6.4 x 1.6 | 12.5 x 6.4 x 1.6 | 160 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_BridgeArch192_L4W16 | `rbxassetid://104852847019885` | 104.8 x 49.484 x 203 | 104.8 x 49.48 x 203 | 996 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_BridgeArch192_L4W17 | `rbxassetid://83778475508473` | 108.8 x 49.484 x 203 | 108.8 x 49.48 x 203 | 996 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_LM_BridgeArch192_L4W18 | `rbxassetid://114432530290037` | 112.8 x 49.484 x 203 | 112.8 x 49.48 x 203 | 996 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_CarWash | `rbxassetid://119548908938906` | 49.2 x 25 x 25.492 | 49.2 x 25 x 25.49 | 222 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_CarWashBrush | `rbxassetid://133493342965802` | 5.2 x 11.3 x 5.7 | 5.2 x 11.3 x 5.7 | 120 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_CarWashRoller | `rbxassetid://99598887285339` | 11.8 x 5.2 x 5.2 | 11.8 x 5.2 x 5.2 | 112 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_CityHall | `rbxassetid://72108376129835` | 72.8 x 52 x 26.4 | 72.8 x 52 x 26.4 | 1231 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_LM_ClockTower | `rbxassetid://85217875290212` | 17 x 88 x 17 | 17 x 88 x 17 | 398 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_DeliveryDepot | `rbxassetid://113236636532342` | 48 x 30.42 x 24.8 | 48 x 30.42 x 24.8 | 272 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_LM_DonutBakery | `rbxassetid://93051356203837` | 36.6 x 54 x 25.83 | 36.6 x 54 x 25.83 | 772 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_Fountain | `rbxassetid://79977497788390` | 24 x 14.2 x 24 | 24 x 14.2 x 24 | 233 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_LM_ServiceCanopy | `rbxassetid://117822429318432` | 48 x 20.6 x 36 | 48 x 20.6 x 36 | 396 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_LM_Theater | `rbxassetid://103590051982357` | 36.6 x 100.06 x 35.6 | 36.6 x 100.06 x 35.6 | 1105 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Civic36Mid_a | `rbxassetid://139466882101320` | 36.8 x 52.3 x 24.4 | 36.8 x 52.3 x 24.4 | 401 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Civic48Mid_b | `rbxassetid://119941326430601` | 48.8 x 52.3 x 24.4 | 48.8 x 52.3 x 24.4 | 510 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Corner24Mid_L | `rbxassetid://92580044919846` | 26.1 x 44.5 x 28.13 | 26.1 x 44.5 x 28.13 | 844 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Corner24Mid_R | `rbxassetid://127377637281357` | 26.1 x 44.5 x 28.13 | 26.1 x 44.5 x 28.13 | 844 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Park48 | `rbxassetid://90840173862642` | 48 x 3.1 x 24 | 48 x 3.1 x 24 | 268 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Plaza48 | `rbxassetid://94829488335873` | 48 x 27.4 x 24 | 48 x 27.4 x 24 | 98 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Pocket24 | `rbxassetid://130193159934363` | 24 x 12 x 24.05 | 24 x 12 x 24.05 | 58 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd4_a | `rbxassetid://130352911457924` | 24.6 x 56.5 x 23.83 | 24.6 x 56.5 x 23.83 | 492 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd4_b | `rbxassetid://117395933291924` | 24.6 x 59.7 x 23.83 | 24.6 x 59.7 x 23.83 | 500 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd4_c | `rbxassetid://137237694591742` | 24.6 x 59.3 x 23.83 | 24.6 x 59.3 x 23.83 | 560 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd4_d | `rbxassetid://82048073735988` | 24.6 x 56.5 x 23.83 | 24.6 x 56.5 x 23.83 | 492 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd5_a | `rbxassetid://135172977240624` | 24.6 x 71.3 x 23.83 | 24.6 x 71.3 x 23.83 | 602 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd5_b | `rbxassetid://96864842301862` | 24.6 x 68.5 x 23.83 | 24.6 x 68.5 x 23.83 | 582 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Blvd6_c | `rbxassetid://85711790667519` | 24.6 x 83.7 x 23.83 | 24.6 x 83.7 x 23.83 | 680 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Low_a | `rbxassetid://81277901404785` | 24.6 x 32.5 x 23.83 | 24.6 x 32.5 x 23.83 | 312 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop24Low_b | `rbxassetid://115405994178540` | 24.6 x 32.5 x 23.83 | 24.6 x 32.5 x 23.83 | 312 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Low_c | `rbxassetid://95222283560523` | 24.6 x 35.3 x 23.83 | 24.6 x 35.3 x 23.83 | 332 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop24Low_d | `rbxassetid://122539710096525` | 24.6 x 35.3 x 23.83 | 24.6 x 35.3 x 23.83 | 332 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Mid_a | `rbxassetid://104422114371303` | 24.6 x 44.5 x 23.83 | 24.6 x 44.5 x 23.83 | 402 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop24Mid_b | `rbxassetid://97252267484408` | 24.6 x 47.7 x 23.83 | 24.6 x 47.7 x 23.83 | 410 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop24Mid_c | `rbxassetid://104176750533677` | 24.6 x 44.5 x 23.83 | 24.6 x 44.5 x 23.83 | 450 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop24Step5_b | `rbxassetid://100255056775254` | 24 x 64.4 x 25.83 | 24 x 64.4 x 25.83 | 490 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop24Step6_a | `rbxassetid://113815338126809` | 24 x 76.4 x 25.83 | 24 x 76.4 x 25.83 | 580 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Blvd4_a | `rbxassetid://110497664274242` | 36.6 x 59.7 x 23.83 | 36.6 x 59.7 x 23.83 | 664 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Blvd4_b | `rbxassetid://102522156182572` | 36.6 x 56.5 x 23.83 | 36.6 x 56.5 x 23.83 | 656 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Blvd4_c | `rbxassetid://102192863522170` | 36.6 x 59.3 x 23.83 | 36.6 x 59.3 x 23.83 | 748 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Blvd5_b | `rbxassetid://97502247546843` | 36.6 x 71.7 x 23.83 | 36.6 x 71.7 x 23.83 | 798 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Blvd5_d | `rbxassetid://129243678102635` | 36.6 x 68.5 x 23.83 | 36.6 x 68.5 x 23.83 | 790 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Blvd6_a | `rbxassetid://126911970329528` | 36.6 x 83.3 x 23.83 | 36.6 x 83.3 x 23.83 | 944 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Mid_a | `rbxassetid://88653804243880` | 36.6 x 47.7 x 23.83 | 36.6 x 47.7 x 23.83 | 530 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Mid_b | `rbxassetid://84305993192324` | 36.6 x 44.5 x 23.83 | 36.6 x 44.5 x 23.83 | 594 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Step5_c | `rbxassetid://84090374921065` | 36 x 64.4 x 25.83 | 36 x 64.4 x 25.83 | 666 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Step6_b | `rbxassetid://71944640183380` | 36 x 76.4 x 25.83 | 36 x 76.4 x 25.83 | 800 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop36Step6_d | `rbxassetid://76764829657170` | 36 x 76.4 x 25.83 | 36 x 76.4 x 25.83 | 800 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop48Blvd4_a | `rbxassetid://76008553906126` | 48.6 x 59.3 x 23.83 | 48.6 x 59.3 x 23.83 | 908 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop48Blvd4_c | `rbxassetid://110232578542645` | 48.6 x 56.5 x 23.83 | 48.6 x 56.5 x 23.83 | 984 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop48Blvd5_b | `rbxassetid://75318579994701` | 48.6 x 68.5 x 23.83 | 48.6 x 68.5 x 23.83 | 1066 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop48Blvd6_d | `rbxassetid://86322512843744` | 48.6 x 83.7 x 23.83 | 48.6 x 83.7 x 23.83 | 1252 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop48Low_a | `rbxassetid://122485300683925` | 48.6 x 35.3 x 23.83 | 48.6 x 35.3 x 23.83 | 552 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop48Low_c | `rbxassetid://107316191766269` | 48.6 x 32.5 x 23.83 | 48.6 x 32.5 x 23.83 | 532 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Shop48Step5_a | `rbxassetid://113156803023149` | 48 x 64.4 x 25.83 | 48 x 64.4 x 25.83 | 910 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Shop48Step6_c | `rbxassetid://95652616942086` | 48 x 76.4 x 25.83 | 48 x 76.4 x 25.83 | 1088 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Tall24Brick_b | `rbxassetid://138960917637211` | 24 x 67 x 28 | 24 x 67 x 28 | 158 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Tall36Glass_a | `rbxassetid://81699659550800` | 36 x 91 x 28 | 36 x 91 x 28 | 336 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Tall36Grid_a | `rbxassetid://72403642503682` | 36 x 79 x 28 | 36 x 79 x 28 | 198 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Lot_Townhouse24_a | `rbxassetid://110874681784475` | 24.6 x 41.6 x 24 | 24.6 x 41.6 x 24 | 276 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Townhouse24_b | `rbxassetid://96983391864968` | 24.6 x 41.6 x 24 | 24.6 x 41.6 x 24 | 276 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Warehouse36Mid_b | `rbxassetid://125596432938817` | 36 x 54.2 x 24.8 | 36 x 54.2 x 24.8 | 417 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Lot_Warehouse48Low_a | `rbxassetid://82940206913074` | 48 x 40.2 x 24.8 | 48 x 40.2 x 24.8 | 354 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block36_1 | `rbxassetid://100949864852723` | 37 x 51 x 31 | 37 x 51 x 31 | 40 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block36_2 | `rbxassetid://72998678214186` | 37 x 71.6 x 31 | 37 x 71.6 x 31 | 66 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block36_3 | `rbxassetid://125217504565082` | 37 x 83.6 x 31 | 37 x 83.6 x 31 | 72 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block36_4 | `rbxassetid://117157970935166` | 37 x 108 x 31 | 37 x 108 x 31 | 88 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block36_5 | `rbxassetid://87579005844103` | 37 x 99 x 31 | 37 x 99 x 31 | 152 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block40_6 | `rbxassetid://112448272244599` | 41 x 134 x 33 | 41 x 134 x 33 | 106 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Block48_1 | `rbxassetid://74640582408111` | 49 x 105 x 31 | 49 x 105 x 31 | 74 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_CivicDome | `rbxassetid://124577483587967` | 44 x 53.6 x 36 | 44 x 53.6 x 36 | 130 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Mid_Glass40 | `rbxassetid://113492747399256` | 40 x 137 x 40 | 40 x 137 x 40 | 104 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Mid_Tower40_4 | `rbxassetid://107334124446531` | 41 x 127 x 35 | 41 x 127 x 35 | 90 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Mid_TreeClump | `rbxassetid://139091262498288` | 28.837 x 17.625 x 20.731 | 28.84 x 17.62 x 20.73 | 140 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Mid_Warehouse48 | `rbxassetid://99799199224390` | 48 x 20 x 30 | 48 x 20 x 30 | 32 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Park_FlowerBed | `rbxassetid://106606382067439` | 8 x 1.9 x 3 | 8 x 1.9 x 3 | 150 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Park_Hedge12 | `rbxassetid://110657426775188` | 12 x 3 x 2.6 | 12 x 3 x 2.6 | 20 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Prop_FireEscape2 | `rbxassetid://133974443686467` | 10 x 21.4 x 3.01 | 10 x 21.4 x 3.01 | 136 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Prop_FireEscape3 | `rbxassetid://84331588939320` | 10 x 33.4 x 3.01 | 10 x 33.4 x 3.01 | 200 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Prop_RoofAC | `rbxassetid://140031322514842` | 4.6 x 4.888 x 3.4 | 4.6 x 4.89 x 3.4 | 144 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Prop_Vent | `rbxassetid://89059049431496` | 3 x 6.2 x 3 | 3 x 6.2 x 3 | 42 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Prop_WaterTank | `rbxassetid://87934834773032` | 7.2 x 15.2 x 7.2 | 7.2 x 15.2 x 7.2 | 126 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Abutment96_L4W16 | `rbxassetid://96702401939967` | 97.7 x 28.6 x 96.45 | 97.7 x 28.6 x 96.45 | 338 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Abutment96_L4W17 | `rbxassetid://96489813025227` | 101.7 x 28.6 x 96.45 | 101.7 x 28.6 x 96.45 | 338 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Abutment96_L4W18 | `rbxassetid://108374938261575` | 105.7 x 28.6 x 96.45 | 105.7 x 28.6 x 96.45 | 338 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_BridgeDeck192_L4W16 | `rbxassetid://100886809416404` | 97.7 x 11.6 x 192.9 | 97.7 x 11.6 x 192.9 | 802 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_BridgeDeck192_L4W17 | `rbxassetid://113386857866002` | 101.7 x 11.6 x 192.9 | 101.7 x 11.6 x 192.9 | 802 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_BridgeDeck192_L4W18 | `rbxassetid://129000077073423` | 105.7 x 11.6 x 192.9 | 105.7 x 11.6 x 192.9 | 802 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_BridgeDeck96_L4W16 | `rbxassetid://72952871925127` | 97.7 x 11.6 x 96.9 | 97.7 x 11.6 x 96.9 | 478 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_BridgeDeck96_L4W17 | `rbxassetid://110518141585504` | 101.7 x 11.6 x 96.9 | 101.7 x 11.6 x 96.9 | 478 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_BridgeDeck96_L4W18 | `rbxassetid://73857319081716` | 105.7 x 11.6 x 96.9 | 105.7 x 11.6 x 96.9 | 478 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_CurveL_L4W16 | `rbxassetid://108052962428720` | 109.655 x 1.6 x 112.681 | 109.66 x 1.6 x 112.68 | 428 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_CurveL_L4W17 | `rbxassetid://91479616612128` | 113.578 x 1.6 x 113.232 | 113.58 x 1.6 x 113.23 | 428 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_CurveL_L4W18 | `rbxassetid://86994352966890` | 117.5 x 1.6 x 113.783 | 117.5 x 1.6 x 113.78 | 428 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_CurveR_L4W16 | `rbxassetid://74450815671589` | 109.655 x 1.6 x 112.681 | 109.66 x 1.6 x 112.68 | 428 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_CurveR_L4W17 | `rbxassetid://103340335697173` | 113.578 x 1.6 x 113.232 | 113.58 x 1.6 x 113.23 | 428 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_CurveR_L4W18 | `rbxassetid://127557291598773` | 117.5 x 1.6 x 113.783 | 117.5 x 1.6 x 113.78 | 428 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Intersection96_L4W16 | `rbxassetid://101931553949623` | 192 x 1.6 x 96 | 192 x 1.6 x 96 | 412 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Intersection96_L4W17 | `rbxassetid://121837947251938` | 192 x 1.6 x 96 | 192 x 1.6 x 96 | 416 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_Intersection96_L4W18 | `rbxassetid://85019626218098` | 192 x 1.6 x 96 | 192 x 1.6 x 96 | 420 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Park192_L4W16 | `rbxassetid://92173452083293` | 97.6 x 1.6 x 192 | 97.6 x 1.6 x 192 | 118 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Park192_L4W17 | `rbxassetid://80583296731637` | 101.6 x 1.6 x 192 | 101.6 x 1.6 x 192 | 118 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Park192_L4W18 | `rbxassetid://90931531583181` | 105.6 x 1.6 x 192 | 105.6 x 1.6 x 192 | 118 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Park96_L4W16 | `rbxassetid://109701621684988` | 97.6 x 1.6 x 96 | 97.6 x 1.6 x 96 | 82 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Park96_L4W17 | `rbxassetid://128371544629541` | 101.6 x 1.6 x 96 | 101.6 x 1.6 x 96 | 82 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Park96_L4W18 | `rbxassetid://125947843194026` | 105.6 x 1.6 x 96 | 105.6 x 1.6 x 96 | 82 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Straight192_L4W16 | `rbxassetid://99158550373072` | 97.6 x 1.6 x 192 | 97.6 x 1.6 x 192 | 206 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Straight192_L4W17 | `rbxassetid://96902621963894` | 101.6 x 1.6 x 192 | 101.6 x 1.6 x 192 | 206 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_Straight192_L4W18 | `rbxassetid://104951868386901` | 105.6 x 1.6 x 192 | 105.6 x 1.6 x 192 | 206 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Straight96_L4W16 | `rbxassetid://86343908011202` | 97.6 x 1.6 x 96 | 97.6 x 1.6 x 96 | 122 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_Straight96_L4W17 | `rbxassetid://85648190625334` | 101.6 x 1.6 x 96 | 101.6 x 1.6 x 96 | 122 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_Straight96_L4W18 | `rbxassetid://71841799567092` | 105.6 x 1.6 x 96 | 105.6 x 1.6 x 96 | 122 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_TransitionVerge96_L4W16 | `rbxassetid://98807426684671` | 97.6 x 1.6 x 96 | 97.6 x 1.6 x 96 | 104 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Road_TransitionVerge96_L4W17 | `rbxassetid://90982737367739` | 101.6 x 1.6 x 96 | 101.6 x 1.6 x 96 | 104 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Road_TransitionVerge96_L4W18 | `rbxassetid://94269175854287` | 105.6 x 1.6 x 96 | 105.6 x 1.6 x 96 | 104 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_BrakeFastDiner | `rbxassetid://90590927331607` | 0.76 x 13.6 x 5 | 0.76 x 13.6 x 5 | 108 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_CornerBlade | `rbxassetid://107257676032531` | 0.34 x 2.56 x 3.827 | 0.34 x 2.56 x 3.83 | 40 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_HonkRollMusic | `rbxassetid://133245374973218` | 0.76 x 14.2 x 5 | 0.76 x 14.2 x 5 | 100 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_HubcapBooks | `rbxassetid://92005070162043` | 16 x 3.6 x 0.62 | 16 x 3.6 x 0.62 | 50 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_LugNutsHardware | `rbxassetid://96213301198170` | 20 x 4.14 x 0.77 | 20 x 4.14 x 0.77 | 40 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_ParkBarkPets | `rbxassetid://85373418442319` | 18 x 3.6 x 0.6 | 18 x 3.6 x 0.6 | 122 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sign_WheelGoodPizza | `rbxassetid://116920830231013` | 18 x 4.397 x 0.69 | 18 x 4.4 x 0.69 | 134 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sky_Crown_1 | `rbxassetid://120460427816278` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Crown_2 | `rbxassetid://79524407402810` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Crown_3 | `rbxassetid://119514079515742` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Needle_1 | `rbxassetid://88746431266815` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sky_Needle_2 | `rbxassetid://113407046158514` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Needle_3 | `rbxassetid://97156094364973` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sky_Slab_1 | `rbxassetid://76632572793269` | 1.04 x 1 x 1.04 | 1.04 x 1 x 1.04 | 20 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Slab_2 | `rbxassetid://132590487349689` | 1.04 x 1 x 1.04 | 1.04 x 1 x 1.04 | 20 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Slab_3 | `rbxassetid://79688143797572` | 1.04 x 1 x 1.04 | 1.04 x 1 x 1.04 | 20 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Spire | `rbxassetid://111373882667029` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sky_Stadium | `rbxassetid://97194239925191` | 332.8 x 73.5 x 249.6 | 332.8 x 73.5 x 249.6 | 234 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Stepped_1 | `rbxassetid://71375061852511` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Stepped_2 | `rbxassetid://120633281931107` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Stepped_3 | `rbxassetid://83007537717923` | 1 x 1 x 1 | 1 x 1 x 1 | 30 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Tank_1 | `rbxassetid://79073969268984` | 1 x 1.08 x 1 | 1 x 1.08 x 1 | 82 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Tank_2 | `rbxassetid://74120685894266` | 1 x 1.08 x 1 | 1 x 1.08 x 1 | 82 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Tank_3 | `rbxassetid://123080328098474` | 1 x 1.08 x 1 | 1 x 1.08 x 1 | 82 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Tower_1 | `rbxassetid://109188398050233` | 1 x 1 x 1 | 1 x 1 x 1 | 44 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Tower_2 | `rbxassetid://127663427669717` | 1 x 1 x 1 | 1 x 1 x 1 | 44 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Tower_3 | `rbxassetid://79899881160953` | 1 x 1 x 1 | 1 x 1 x 1 | 44 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Wedding_1 | `rbxassetid://135170789241059` | 1 x 1.05 x 1 | 1 x 1.05 x 1 | 50 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Sky_Wedding_2 | `rbxassetid://72094321184491` | 1 x 1.05 x 1 | 1 x 1.05 x 1 | 50 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Sky_Wedding_3 | `rbxassetid://135061780133101` | 1 x 1.05 x 1 | 1 x 1.05 x 1 | 50 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Span_Bunting_L4W16 | `rbxassetid://117116443317004` | 77.2 x 26.85 x 1.2 | 77.2 x 26.85 x 1.2 | 234 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Span_Bunting_L4W17 | `rbxassetid://136037204689374` | 81.2 x 26.85 x 1.2 | 81.2 x 26.85 x 1.2 | 236 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Span_Bunting_L4W18 | `rbxassetid://95725285315300` | 85.2 x 26.85 x 1.2 | 85.2 x 26.85 x 1.2 | 236 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Span_Welcome_L4W16 | `rbxassetid://105312961377411` | 82.8 x 32.3 x 4 | 82.8 x 32.3 x 4 | 360 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Span_Welcome_L4W17 | `rbxassetid://116723414769670` | 86.8 x 32.3 x 4 | 86.8 x 32.3 x 4 | 360 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Span_Welcome_L4W18 | `rbxassetid://116339613855590` | 90.8 x 32.3 x 4 | 90.8 x 32.3 x 4 | 360 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Street_Bench | `rbxassetid://114254754006450` | 6 x 3.15 x 1.94 | 6 x 3.15 x 1.94 | 180 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_BikeRack | `rbxassetid://121779647820089` | 7.2 x 3.022 x 2.7 | 7.2 x 3.02 x 2.7 | 216 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_Bin | `rbxassetid://131348970467412` | 2.4 x 3.35 x 2.4 | 2.4 x 3.35 x 2.4 | 56 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_Bollard | `rbxassetid://106937582664693` | 0.94 x 3.5 x 0.94 | 0.94 x 3.5 x 0.94 | 66 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Street_BusStop | `rbxassetid://96900259604141` | 15.2 x 10.2 x 5.2 | 15.2 x 10.2 x 5.2 | 196 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_Hydrant | `rbxassetid://111351509352396` | 1.7 x 2.8 x 1.6 | 1.7 x 2.8 x 1.6 | 164 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_Lamp | `rbxassetid://96011767468107` | 2.4 x 19.85 x 6.15 | 2.4 x 19.85 x 6.15 | 204 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_LampFormal | `rbxassetid://105808140275704` | 7.9 x 17.35 x 2 | 7.9 x 17.35 x 2 | 188 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_LampLens | `rbxassetid://78507962571965` | 2.2 x 0.5 x 2.2 | 2.2 x 0.5 x 2.2 | 28 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Street_Planter | `rbxassetid://95940161726798` | 5.2 x 5.4 x 5.2 | 5.2 x 5.4 x 5.2 | 150 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |
| B2_Street_StreetSign | `rbxassetid://79885070800022` | 5.6 x 12.05 x 5.6 | 5.6 x 12.05 x 5.6 | 56 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Street_TrafficLight | `rbxassetid://128462205235981` | 5 x 15 x 2.35 | 5 x 15 x 2.35 | 220 | uploaded; size matches; not placed by this route, **not loaded in Play** |
| B2_Street_Tree | `rbxassetid://114417657834605` | 8.593 x 15.082 x 8.509 | 8.59 x 15.08 x 8.51 | 120 | uploaded; size matches; **loaded in Play** (Downtown seed 2207, whole route walked) |

Play check: the Downtown city (seed 2207, 3,094 studs, one road width L4W17) was walked end to end in a Studio Play client: **88 of 180 meshes loaded** with the palette texture and no proxy boxes; the other **92** are uploaded and size-checked but this route does not place them (other lane widths L4W16/L4W18, harbor pieces, unused lots and signs), so their loading is **untested**. Colour: the old session-only preview and the uploaded meshes both use the Main Street palette; there is no side-by-side capture of the two.

## Not uploaded
Dusty Highway and Summit Pass kit art (53 and 56 meshes) and the car models: not uploaded. The World redesign plans propose their kits ([[world-plan-dusty-highway]], [[world-plan-summit-pass]]); uploading them waits for Adam's approval of those plans.
