---
title: Speedway upgrade looks - ledger
tags:
  - design
  - speedway
  - island
status: in-progress
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
| SPW-09 | One additive module, plot + level 1 to 12; clean upgrade, downgrade, repeat | §2.1, added | Look | to verify in Studio (cycle test) |
| SPW-10 | Same ~15 s lap at every level, crossing synced with the cue, no reward from crossings; measured per level | §2.2, added | Path, LappingPreview | to measure |
| SPW-11 | Fits the plot; never blocks gate, paths, Paddock, nameplate, plaza view; measured | §2.3, added | Preview/SpeedwayChecks | to measure |
| SPW-12 | Visitors safe on raised parts, loop, overpass; cars harmless | §2.4, added | Track | to test in Play |
| SPW-13 | Island style, symmetric prop placement, fictional names only | §2.5 | kit, Props | to review |
| SPW-14 | Readable from the plaza | §2.6 | captures | to capture |
| SPW-15 | Phones first: distance detail, budgets, measured cost of six top-level plots | §2.7, added | Look.setDetail, measurements | to measure |
| SPW-16 | Cheap life: rigid code-animated figures, official arm tween | §2.8 | Life | to test |
| SPW-17 | Reduce Motion calm versions | §2.9 | Calm, Reveal, Life | to test |
| SPW-18 | Layered quiet sound, ids listed, under the music | §2.10 | Sound | to choose ids and test |
| SPW-19 | Reveal (~1.5 s) with banner; calm version; no blocking; rapid clicks safe | §4, added | Reveal | to test |
| SPW-20 | Kiosk next-level board with picture and PREVIEW price; top-level state | §4 | Kiosk | to test |
| SPW-21 | Ghost outline of the next main piece, not cluttering | §4 | Look.ghost | to test |
| SPW-22 | Levels 1, 6 and 12 first, compared with both references and the island; fix before the rest | §5.3 | captures | to do |
| SPW-23 | Blender recipe, Roblox-safe export; upload with the group as Creator, or ask once and do it in the end guided moment | §5.5 | kit_speedway.py | recipe built; upload waiting for the group id |
| SPW-24 | Prepare the 97-mesh group re-import, list as waiting | §5.6 | island-group-reimport.md, ImportCheck | prepared |
| SPW-25 | Brian L message through the vault on main, board Up next row | §6 | main `4f2ce80` | done |
| SPW-26 | Review page with every listed section; STOP | §7 | `Car-Hop-Art/review/speedway-upgrades/` | to do |
| SPW-27 | Studio Play on desktop and landscape phone/tablet frames; tested vs read-only separated | §7 | review page | to do |
| SPW-28 | check.ps1, commit, push, draft PR (builds on the island branch), board, log | §7 | | to do |

## Performance
_(filled from Studio measurements)_

## Lap timing
_(filled from Studio measurements)_
