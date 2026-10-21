---
title: First-car record (copied from the Lane 3 branch)
tags:
  - design
  - vehicles
---

# First-car record (copied from the Lane 3 branch)

Copied word for word on 2026-10-21 from `feature/lane3-first-car-downtown` (`f309ea2`) for the car handover to Brian L ([[README|car handover pack]]). Nothing below was rewritten; headings are one level lower. The branch keeps the originals.

## From `vault/design/visual-direction.md`

### Vehicles (2026-10-20)
- **Approved direction** ([[0010-vehicle-direction]]): original fictional or parody vehicles inspired by real categories, eras and proportions, as polished, shaped low-poly cars; the five vehicle guardrails are in `AGENTS.md` "Vehicles". Every car, including the cheapest Common, must look intentionally shaped and desirable.
- **Proposed, pending Adam's review:** the five-tier rarity guide [[rarity-style]] (with the reference observations) and the 24-car [[roster]]. The Uncommon tier and its numbers are proposals for Brian L.
- **First car (Downtown Common starter, study B):** built in Blender from the recipe in `assets/vehicles/downtown-starter/`; pending Adam's review. Not approved, and its proposed name (Puglet) is not approved.
- **Superseded:** the Pip sections below (toy hatchback, cream roof, wheels about 1.3 times realistic, parts-only). They stay as history; Pip's 2026-10-19 approval does not approve the new car or its name.

Provisional rig from the superseded Pip sketch (the same file, section "Pip, approved sketch"):

- **Rig (provisional, for Brian R's review):** `Root` invisible part at ground under the car centre, model PrimaryPart, facing -Z, +Y up; every part Anchored (kinematic, moved with PivotTo; no Seat, no Humanoid, no welds needed). `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR` models with pivots at axle centres, spin about local X. Attachments: `SeatAnchor` (rider position, faces forward; placement only), `HeadlightL`, `HeadlightR`, `HeatSteam` (hood), `HopRing` (ground centre), `KeysMeter` (above roof), `TrailL`, `TrailR` (rear corners). Every visible part carries a `ColorRole` attribute (Body, Roof, Trim, Glass, LampFront, LampRear, Tire, Hub); finishes are role-to-colour maps. Model attribute `RigVersion = "0-provisional"`.

## From `assets/vehicles/README.md` (the Blender recipe kit, still on the branch)

## Vehicle source recipes (Lane 3)

Text-only, reviewable recipes that rebuild every vehicle mesh in Blender.
Binary art (`.blend`, `.fbx`, `.rbxl`, `.rbxm`, renders) never goes in Git; it
lives in `C:\Users\agert\Documents\Car-Hop-Art\` (Adam, 2026-10-20). Rules for
names, logos and shapes: `AGENTS.md` "Vehicles" and decision 0010.

| Path | What |
|---|---|
| `lib/carkit.py` | Shared kit: lofted body and greenhouse sections, wheel arches, wheels, projected lamps and trim, split by colour role, FBX export |
| `lib/render_views_mcp.py` | Review stills for one car (bpy only; run in an interactive Blender or through the Blender MCP) |
| `downtown-starter/` | The Downtown Common starter (study B): spec, build script, import manifest |
| `studies/` | Rough comparison studies: starter architectures A, B, C and five rarity tiers |

### Tools (as used on 2026-10-20)

- Blender 5.2.2 LTS (free). No add-ons needed for the recipes.
- Blender MCP 1.8 add-on with `BLENDER_MCP_SAFE_MODE=1`, used only for review
  renders. Safe mode blocks file access, so the recipes run headless instead.
- Roblox Studio 3D Importer for the local import (Upload to Roblox off).

### Conventions (provisional, for Brian R's review)

- Units: 1 Blender unit = 1 stud. Provisional scale 1 stud = 0.28 m.
- Blender: car faces -Y, up +Z, ground z = 0, car's left side +X.
- FBX export (`carkit.export_fbx`): forward -Z, up Y, scale 1, normals only,
  no animation. In Roblox the car faces -Z, up +Y, right +X.
- One mesh object per colour role: `BodyPrimary`, `BodySecondary`, `Trim`,
  `Glass`, `Headlamp`, `Taillamp`, `Plate`. Wheels: `Wheel_<FL|FR|RL|RR>_Tire`
  and `Wheel_<..>_WheelMetal`, origin on the axle, one shared mesh per kind;
  right-side wheels are rotated 180 degrees about up (no negative scale).
  FL is front-left from the seated driver's point of view.
- Roblox ignores Blender material colours; Studio colours each MeshPart from
  its role (see `src/client/Home/CarPreview`).
- Faces buried inside other geometry are tagged `Hidden` and never exported.

### Rebuild

```
blender -b --factory-startup --python assets/vehicles/downtown-starter/build.py -- --out C:/Users/agert/Documents/Car-Hop-Art/vehicles/downtown-starter --no-render
blender -b --factory-startup --python assets/vehicles/studies/build_studies.py -- --out C:/Users/agert/Documents/Car-Hop-Art/vehicles/studies
```

Each run is deterministic and replaces its outputs. Then open Blender and run
`lib/render_views_mcp.py` (or `studies/render_studies_mcp.py`) for stills.
Headless Workbench renders came out much darker than interactive ones on this
machine, which is why stills are rendered interactively.

## From `assets/vehicles/downtown-starter/README.md`

## Downtown Common starter (study B)

Status: built in Blender 2026-10-20, pending Adam's review. Proposed name
"Puglet" (not approved). Rules: `AGENTS.md` "Vehicles", decision 0010, and
`vault/design/vehicles/rarity-style.md`.

### Files

| In Git | Purpose |
|---|---|
| `starter_spec.py` | Every dimension, section, decal and colour; the design sheet in code |
| `build.py` | Builds the car, writes stats, exports the FBX, saves the .blend |
| `../lib/carkit.py` | Shared construction kit |
| `../lib/render_views_mcp.py` | Review stills (interactive Blender) |

| Outside Git (`C:\Users\agert\Documents\Car-Hop-Art\vehicles\downtown-starter\`) | |
|---|---|
| `downtown-starter.blend` | Built scene |
| `downtown-starter.fbx` | Import file (14 mesh objects) |
| `stats.json` | Triangle counts and bounds written by `build.py` |
| `renders\*.png` | Review stills |

### Measured in Blender (stats.json, 2026-10-20)

- Overall: length 12.47, width 5.66 with mirrors (5.59 without), height 4.71 studs. At 1 stud = 0.28 m: 3.49 x 1.58 x 1.32 m.
- Wheelbase 7.94 (64% of length), tyre diameter 2.23 (18%), tyre width 0.69 (31% of diameter), roof about 4.1-4.3 wide (73-77% of body width), sill 0.66 (5%).
- Triangles 4,992 in total (3,546 unique, because the wheel meshes are shared); 14 mesh objects: BodyPrimary 1,601, Trim 1,049, Glass 208, Headlamp 108, Taillamp 84, Plate 14, and per wheel Tire 304 and WheelMetal 178.

### Import into the private test place (local only)

1. Run `build.py` (see `../README.md`).
2. Studio, private place `C:\Users\agert\Documents\Car-Hop-Art\CarHop-Lane3-Test.rbxl` (never the Team Create place).
3. Import 3D, choose `downtown-starter.fbx`, untick **Upload to Roblox**, Import.
4. Put the imported model at `ReplicatedStorage.Lane3_VehicleSamples.DowntownStarter`.
5. Playtest, then from the client: `require(game.Players.LocalPlayer.PlayerScripts.Client.Home.CarPreview).start()`.

Studio results are in the dated log; nothing is uploaded or published.

## From `vault/log/2026-10-20.md`

### First car: Studio import uploaded the meshes (Claude Code with Adam, Lane 3)

- Place file moved (Adam's answer): the private test place is now `C:\Users\agert\Documents\Car-Hop-Art\CarHop-Lane3-Test.rbxl` (moved out of the repository root; hashes matched).
- Studio coordination (Adam, 11:00): sessions take `C:\Users\agert\Documents\Car-Hop-Art\STUDIO_LOCK.txt` before any Studio step and delete it after. The car session held it 11:00 to 11:14.
- Opening the place: Studio first opened its own auto-recovery copy from 2026-10-19 22:16 instead of the file. That window was closed without saving, and the recovery file was moved unchanged to `%LOCALAPPDATA%\Roblox\RobloxStudio\AutoSaves\Archived\CarHop-Lane3-Test_AutoRecovery_0_20261019_221654.rbxl`. The real file then opened (window title shows its path; PlaceId 0). Rojo `serve --port 34872` connected; `Client.Home.CarPreview` and `Client.UI` synced.
- Import: this Studio build's Import button opens a new "Import Queue" (Creator "Me", preset "Studio Default", Start Import) rather than the older importer with an "Upload to Roblox" tick box. The instructions given did not cover the queue's upload behaviour. Importing `downtown-starter.fbx` there **uploaded all 14 meshes to Roblox** under Adam's user account. verified: every MeshPart has a numeric `rbxassetid://` MeshId, and `GetProductInfo(89128981297411)` returns Name "BodyPrimary", AssetTypeId 4 (Mesh), CreatorType User, Created 2026-10-20T15:12:07Z, IsPublicDomain false. This breaks Adam's "Do not upload anything" answer. Work stopped and Adam was told.
- The imported model also arrived at 100 times scale (BodyPrimary 566 x 405 x 1240 studs), so the FBX unit setting needs fixing before any re-import.
- The place was not saved. Nothing was moved, played or recorded.

#### Upload follow-up (Adam's decisions, 2026-10-20 afternoon)

- Adam decided: keep the 14 meshes; uploads are allowed for testing (option A), meshes only, only for this task's cars and studies, and only to the same owner. Every upload is listed below. These are test uploads: final meshes will be re-uploaded under whoever owns the published game, and the recipes regenerate every mesh.
- **Owner** (verified with `MarketplaceService:GetProductInfo` on each asset): Roblox **user** account `peskaface` (user ID 2393473976), the account signed in to Studio (`StudioService:GetUserId()` returns the same ID). Not a group.
- **How it happened** (Roblox docs, [3D Importer](https://create.roblox.com/docs/art/modeling/3d-importer)): "Upload to Roblox" is a File General setting in the import preview, and its default is **enabled**. The Import Queue imports each row with its preset ("Studio Default", the default behaviour); the preview with the Upload toggle only opens when the asset's name is clicked in the queue. The toggle was never turned off for this import. The queue's "Creator" column was "Me", which is why the owner is the user account.
- **Why the car was 100 times too big:** the importer's "Scale Unit" default is Studs, and the Blender export used `apply_unit_scale=True`, which gave every object a 100x transform. `carkit.export_fbx` now uses `apply_unit_scale=False` (raw Blender units = studs). Geometry is unchanged: rebuilt 13:04, 4,992 triangles, same per-part counts.
- Wheels are uploaded as separate meshes per wheel (the FBX shares one tyre and one rim mesh across four objects, but the importer uploaded each object's mesh).

##### Uploaded test assets (all Mesh, owner user `peskaface` 2393473976)

| Name | Asset ID | Uploaded (UTC) | Car | Note |
|---|---|---|---|---|
| BodyPrimary | 89128981297411 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Glass | 118639989161261 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Headlamp | 133982943493866 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Plate | 136652844802526 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Taillamp | 118467779170247 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Trim | 105088965358409 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_FL_Tire | 76937559988816 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_FL_WheelMetal | 92227666974347 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_FR_Tire | 101433569205168 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_FR_WheelMetal | 124123929756526 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_RL_Tire | 74251823363991 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_RL_WheelMetal | 98509285454099 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_RR_Tire | 78540627048721 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |
| Wheel_RR_WheelMetal | 77154767515942 | 2026-10-20 15:12 | downtown-starter | import 1, 100x scale |

### First car: re-import and Studio checks (Claude Code with Adam, Lane 3, evening)

- Adam's change of plan: future cars will be made in Claude Design and imported, not modelled from scratch in Blender. For this car only the re-import and the checks that apply to every car (size, wheels and seat, cost of one car); no videos and no review page. No pipeline decision is recorded yet; that waits for the first Claude Design car.
- Memory: Adam asked to close the empty Studio start-page window (closed normally) and Blender (the file `Car-Hop-Art\vehicles\downtown-starter\downtown-starter.blend` was saved to its own place first, 21:39:27, 156,977 bytes), and to stop this session's Blender MCP server (the Codex and other Claude copies were left alone). Free memory went from 2.8 GB to 8.6 GB.
- Studio lock held by the car session 21:39 to 22:02, then deleted so the island session could start.
- Re-imports: the fixed FBX (13:04 build) was imported twice through the Import Queue: once with "Upload to Roblox" on, once with it meant to be off. verified: both times every MeshPart got the **same asset IDs as import 1** and the same 100x mesh size (`MeshSize` 566 x 405 x 1240 for BodyPrimary). So Studio reused the meshes it had already uploaded instead of reading the new scale, and **no new assets were uploaded** (the list above is unchanged). Wheel_FL_WheelMetal now points at 98509285454099 (the identical rear-left rim). The FBX scale fix is therefore still untested in Studio; the FBX header reads UnitScaleFactor 1 and object scale 1.
- Size fix used instead: `Model:ScaleTo(0.01)` in Studio. verified: 12.465 long x 4.71 tall x 5.66 wide studs (exact match with Blender), wheels touching the ground (tyre radius 1.115), wheelbase 7.94, track 4.84. Stored at `ReplicatedStorage.Lane3_VehicleSamples.DowntownStarter`; the two old copies were deleted.
- Wheels (playtest, CarPreview driving on the preview rail): verified: all four wheels keep their centres on their axles, rims stay locked to the tyres, and the spin matches the ground speed (about 141 degrees per 0.2 s at about 49 studs per second, radius 1.115). No seats, nothing collides.
- Seat (playtest, temporary Seat at the provisional SeatAnchor, removed when play stopped): verified: a default R15 avatar (5.71 studs tall) sits, but its **head top is at 5.70 studs and the roof at 4.71**, so the head and hat stick out about 1 stud through the roof, and the closed body has no inside. The car or the seat needs a decision (see the report to Adam). Numbers only; no screenshot of it (the play camera could not be moved).
- Cost of one car (desktop playtest only, frame rate capped at 60): 14 MeshParts, 15 instances per copy, 4,992 triangles (3,546 unique). 1, 10, 50 and 100 anchored copies all stayed at 60 fps (worst frame 19 ms with or without cars), and mesh memory stayed at 3.67 MB because copies share the same mesh data. Not measured: phones, the GPU frame time (Studio reported 0), physics on a moving car.
- The place was **not saved** (Ctrl+S did not reach Studio; the file is still dated 2026-10-19). The car stays in the open Studio window; re-importing is three clicks if it closes.
