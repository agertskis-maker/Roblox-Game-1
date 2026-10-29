---
title: Speedway upgrade looks - ledger
tags:
  - design
  - speedway
  - island
status: review
---

# Speedway upgrade looks: ledger (SPW)

Source: Adam's brief of 2026-10-28 (`vault/design/specs/speedway-upgrade-looks.md`, the installed package `Car-Hop-briefs-2026-10-28`). Branch `feature/lane3-speedway-upgrades` from `feature/lane3-island-environment`. Decision [[0025-speedway-visible-levels]]. Owner: Adam (Lane 3). Looks only: no prices, Cash, save fields or remotes.

Answers from Adam in the question batch (2026-10-28): group ID **not yet** (keep going, guided import at the end); the two new UI pieces take a **task-scoped Studio-first exception** to the Figma rule; the overpass: **"do whatever is viable and your recommendation"**, as long as a car can visibly go round the track (an upside-down loop was flagged as possibly hard).

## Plan: module and kit
- **Shared (`src/shared/Island/Speedway/`, `ReplicatedStorage.Shared.Island.Speedway`):** `Ladder` (12 levels, names, signatures, the three 15-level extras), `Path` (lap path per level: oval, banked, spiral overpass, jump, loop; sampling by distance; plot frame), `Kit` / `KitIds` / `KitManifest` (speedway kit meshes: uploaded ids or session previews; part helpers), `Ctx` (plot-frame placement), `Track` (road, edges, banked walls, raised deck, loop platform, jump), `Props` (every placed prop, figures, signs, kiosk board), `Look` (the additive feature ladder, apply / setDetail / ghost / signature piece / clear).
- **Client (`src/client/Home/Island/`):** `SpeedwayLooks.client` (per plot level, detail, reveal, kiosk, ghost, sound, preview cars), `Speedway/Reveal`, `Speedway/Life`, `Speedway/Kiosk`, `Speedway/Sound`, `Speedway/PreviewPanel`, `Speedway/Calm`; `LappingPreview` extended (level paths, preview car mesh, crossing events, timing).
- **Build (`src/island/Hub/`):** the plot recipe keeps the front only; `HubBuild.previewSpeedway` / `clearSpeedway` for edit-mode views; `Preview/ImportCheck` (post-import checks).
- **Kit (`assets/island/kit/kit_speedway.py`):** new meshes, the existing palette only; reused: the island's banner art, pennants and flag cloths. Every ground road layer is parts (the approved Task 3 track).
- **Budgets (proposed, desktop, to be checked against the measured baseline):** see "Performance" below.

## Requirements

| ID | Requirement | Source | Files | Status / evidence |
|---|---|---|---|---|
| SPW-01 | Install/reuse the briefs package without moving files the other session reads; verify five names | session prompt | briefs folder | done: reused (installed 17:13, archive `old-2026-10-28` holds two older briefs); the zip is no longer in Downloads, so no byte comparison was possible |
| SPW-02 | Board claim on main, vault-only commit | prompt | BOARD.md (main) | done: `cbc8f99` |
| SPW-03 | Branch from the island branch; brief copied into the vault | §0 | `vault/design/specs/speedway-upgrade-looks.md` | done: `33c4a66` |
| SPW-04 | Find the existing Speedway, build on it, no parallel track system | §0 | Plot recipe, Markers, TrackMotion, LappingPreview | done: base track moved into the look (levels 4 on); markers unchanged; TrackMotion waves the new flags; LappingPreview extended |
| SPW-05 | 10 to 15 levels decided, 12 recommended and built as PREVIEW looks | §1, §3 | Ladder, Look | built, see the level table |
| SPW-06 | Supersede the 2026-10-21 base-track rule in ledger and decision | §1 | 0025, island-rework pointer | done (0025) |
| SPW-07 | Looks only: no prices, Cash, save fields, remotes; preview price placeholder | §1 | Kiosk, Props | done by construction (no remotes, no amounts) |
| SPW-08 | Slots stay a separate ladder (assumption recorded) | §1 | Brian L message | done |
| SPW-09 | One additive module, plot + level 1 to 12; clean upgrade, downgrade, repeat | §2.1, added | Look | **Studio-tested** (Play): up 1 to 12 and down 12 to 1 give identical part counts and feature folders per level; rapid 7, 8, 9, 10 equals a direct 1 to 10; re-applying a level changes nothing |
| SPW-10 | Same ~15 s lap at every level, crossing synced with the cue, no reward from crossings; measured per level | §2.2, added | Path, LappingPreview | **Studio-tested**: 14.998 to 15.000 s laps at every level, cue 2 to 18 ms after the crossing (Lap timing table) |
| SPW-11 | Fits the plot; never blocks gate, paths, Paddock, nameplate, plaza view; measured | §2.3, added | Preview/SpeedwayChecks | **Studio-measured**: no part outside the sector or over gate, walk, Paddock, kiosk or pit lanes at any level; plaza view in the Performance table (levels 9 to 12 partly hidden from a standing eye) |
| SPW-12 | Visitors safe on raised parts, loop, overpass; cars harmless | §2.4, added | Track | **Studio-tested** (Play, scripted walker): the whole level-12 lap incl. hump, loop pad, raised far turn, deck and descent walked without getting stuck; walked under the descent (6.6 headroom over the root) and under the far turn; parapets 1.65 high on every raised edge; gantry collides at its legs only; loop mesh does not collide |
| SPW-13 | Island style, symmetric prop placement, fictional names only | §2.5 | kit, Props | island palette only; fictional names (PIP'S POPS, COMET COLA, HAUL BUDDY TIRES, the existing banner brands); stills reviewed |
| SPW-14 | Readable from the plaza | §2.6 | captures | captured from the plaza at every level (review page) |
| SPW-15 | Phones first: distance detail, budgets, measured cost of six top-level plots | §2.7, added | Look.setDetail, measurements | **Studio-measured**: six plots at level 12 cost +2,293 parts, +0.40 ms render CPU, +1.3 MB graphics; far plots drop to silhouette at 260 studs; no real phone measured |
| SPW-16 | Cheap life: rigid code-animated figures, official arm tween | §2.8 | Life | **Studio-tested**: figures, the official's flag, start lights, gantry and blimp in Play (clip crowd-and-official); 34 figures, 100 animated parts on the near plot |
| SPW-17 | Reduce Motion calm versions | §2.9 | Calm, Reveal, Life | **Studio-tested**: Reduce Motion override: reveal pieces travel 0.00 studs (normal 7.85 with the bounce), banner fades in place, idle motion calmer |
| SPW-18 | Layered quiet sound, ids listed, under the music | §2.10 | Sound | four Pro Sound Effects ids chosen and heard in the recorded clips (quiet: mean -44 dB); Adam's listening check pending; licence text not verified |
| SPW-19 | Reveal (~1.5 s) with banner; calm version; no blocking; rapid clicks safe | §4, added | Reveal | **Studio-tested**: reveal 1.5 s, banner "SPEEDWAY LEVEL 6: PIT ROW!" shown then cleared; rapid clicks end in the right look |
| SPW-20 | Kiosk next-level board with picture and PREVIEW price; top-level state | §4 | Kiosk | **Studio-tested** after a fix: the board draws from PlayerGui (a ViewportFrame on a world SurfaceGui did not draw); text scales to fit; the top level shows TOP LEVEL! |
| SPW-21 | Ghost outline of the next main piece, not cluttering | §4 | Look.ghost | built (the next level's main piece outlined on the home plot); not separately checked |
| SPW-22 | Levels 1, 6 and 12 first, compared with both references and the island; fix before the rest | §5.3 | captures | done: levels 1, 6 and 12 first, fixes before the rest (near-turn wall lowered, deck lightened, gantry colliders, podium moved) |
| SPW-23 | Blender recipe, Roblox-safe export; upload with the group as Creator, or ask once and do it in the end guided moment | §5.5 | kit_speedway.py | **uploaded** 2026-10-28 under Adam's user account on his choice (the account is in no group): 55 meshes, ImportCheck clean; group re-import later |
| SPW-24 | Prepare the 97-mesh group re-import, list as waiting | §5.6 | island-group-reimport.md, ImportCheck | prepared; waiting for the group and for Adam's account to join it |
| SPW-25 | Brian L message through the vault on main, board Up next row | §6 | main `4f2ce80` | done |
| SPW-26 | Review page with every listed section; STOP | §7 | `Car-Hop-Art/review/speedway-upgrades/` | review page built (Car-Hop-Art/review/speedway-upgrades/index.html) |
| SPW-27 | Studio Play on desktop and landscape phone/tablet frames; tested vs read-only separated | §7 | review page | **Studio-tested**: desktop, landscape phone (749 x 381, touch) and landscape tablet (1178 x 818, touch) frames in Play |
| SPW-28 | check.ps1, commit, push, draft PR (builds on the island branch), board, log | §7 | | to do |
| SPW-29 | Simpler ramps: no spiral, no track over track; the jump becomes a low hump (Adam 2026-10-28, "Both") | Adam mid-task | Path, Track, Look, Ladder, kit_speedway.py | **Studio-tested**: built and walked; laps 15 s |
| SPW-30 | Bleachers and grandstand in the painted island style: navy / coral / cream rows, navy sponsor panel (fictional), hand rails, fans seated properly (Adam 2026-10-28) | Adam mid-task | kit_speedway.py, Props | **built and seen in Studio**: worker restyle (bleachers 370, grandstand bay 932 triangles), sponsor text on the panels, fans skip the aisle |
| SPW-31 | Play previews of kit meshes need the experience's "Allow Mesh / Image APIs" (Adam switched it on in his private place, 2026-10-28); the Studio client's EditableMesh memory budget is shared with edit-mode previews, so Play is tested from a fresh Studio | found in Studio | KitIds (uploads remove the need) | noted |

## Performance
Measured in Studio on Adam's laptop, private island place, 2026-10-28, with the uploaded kit (WIP 6).

**Per plot, per level** (edit mode, `Hub/Preview/SpeedwayChecks.run({ plot = 3 })`; parts and mesh parts counted from the placed look; triangles from the kit manifests, 12 per box part; plaza view = share of 40 lap points visible from five points on the plaza edge, Speedway parts as the only blockers):

| Level | Parts | Mesh parts | Triangles | Highest point | Plaza view, eye 5 | Plaza view, camera 12 | Outside sector / protected |
|---|---|---|---|---|---|---|---|
| 1 | 313 | 89 | 24,684 | 6.9 | 94.5% | 97.5% | 0 / 0 |
| 2 | 321 | 95 | 25,916 | 8.1 | 94.5% | 97.5% | 0 / 0 |
| 3 | 353 | 125 | 28,844 | 8.1 | 94.5% | 97.5% | 0 / 0 |
| 4 | 444 | 80 | 28,404 | 8.1 | 99.0% | 99.0% | 0 / 0 |
| 5 | 493 | 83 | 29,796 | 10.4 | 98.0% | 99.0% | 0 / 0 |
| 6 | 518 | 91 | 31,706 | 10.4 | 98.0% | 99.0% | 0 / 0 |
| 7 | 587 | 159 | 39,180 | 13.0 | 98.0% | 99.0% | 0 / 0 |
| 8 | 601 | 164 | 43,246 | 40.1 | 96.5% | 97.5% | 0 / 0 |
| 9 | 868 | 153 | 38,652 | 40.1 | 23.0% | 59.0% | 0 / 0 |
| 10 | 901 | 157 | 33,822 | 40.1 | 38.5% | 59.5% | 0 / 0 |
| 11 | 945 | 159 | 34,994 | 65.0 | 38.5% | 62.0% | 0 / 0 |
| 12 | 958 | 168 | 38,380 | 65.0 | 42.5% | 67.0% | 0 / 0 |

Highest point includes the blimp's orbit envelope (11 on) and the firework bloom (12). Levels 9 to 12: the banked near-turn wall and the raised far turn hide the far side of the lap from a standing eye on the plaza; the tall pieces (gantry, grandstand roof, loop, blimp) read from there. The level 1 to 3 triangle counts include the meshes of the hay, tyre and rope runs (the most mesh parts).

**Six plots** (Play, client, Studio window in front, camera on the plaza looking at plot 3; the laptop was on battery and Studio held a flat 15.0 fps at both levels, so frame rate does not separate them; the render and memory numbers do):

| All six plots at | Speedway parts | Render CPU per frame (mean / max) | Heartbeat | Client memory | Instances | Graphics parts | Lapping loop |
|---|---|---|---|---|---|---|---|
| Level 1 | 1,865 | 5.75 / 9.03 ms | 0.59 ms | 2,917 MB | 128.8 MB | 10.1 MB | 0.37 ms |
| Level 12 | 4,158 | 6.15 / 8.96 ms | 0.44 ms | 2,930 MB | 129.7 MB | 11.4 MB | 0.44 ms |
| Cost of six top-level plots | +2,293 parts | +0.40 ms mean | no change | +13 MB (noise level) | +0.9 MB | +1.3 MB | +0.07 ms |

Not measured: a real phone (the device emulator shares the PC's GPU) and the GPU time (Studio reported 0 on this machine). Far plots switch to their silhouette (Minor and Life folders out) beyond 260 studs.

## Lap timing
Play, client, `LappingPreview.timing(32)` via the Studio test hook (`Lane3SpeedwayControl`), 6 cars per plot, os.clock between successive finish crossings of each car; the offset is the car's distance past the line in the frame the cue fired.

| Levels | Path | Length | Visual speed | Measured lap (mean, min to max) | Cue after the crossing |
|---|---|---|---|---|---|
| 1 to 6 | oval | 427.1 | 28.5 | 14.999 s (14.998 to 15.001) | 9.0 to 11.1 ms |
| 7 and 8 | oval | 427.1 | 28.5 | 14.999 s (14.994 to 15.005) | 2.7 to 14.5 ms |
| 9 | banked oval | 427.1 | 28.5 | 14.998 s (14.987 to 15.011) | 1.8 to 16.1 ms |
| 10 and 11 | raised far turn (11: hump) | 427.1 | 28.5 | 14.998 s (14.987 to 15.011) | 1.9 to 17.2 ms |
| 12 | raised far turn + loop | 494.6 | 33.0 | 14.998 s (14.987 to 15.010) | 3.2 to 17.8 ms |

The cue fires in the same frame the car's phase wraps (one clock), so the offset is under one frame (at most 66.7 ms at the battery-capped 15 fps; measured under 18 ms). Rewards never come from crossings (cars are client-only and not replicated).
