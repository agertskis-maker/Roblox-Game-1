---
title: "0027: Raceway round 2: no advertising, Raceway name, level-only banner, the Raceway shop, parking spots, island walking base 32"
date: 2026-10-29
tags:
  - decision
  - island
  - speedway
  - raceway
status: proposed
---

# 0027: Raceway round 2

> [!note] Pending Adam's review
> Written by Claude Code on 2026-10-29 for Adam's review of PR #4 (brief `vault/design/specs/raceway-round2.md`, ledger `vault/design/specs/raceway-round2-ledger.md`). Adam's decisions are marked **Decided (Adam)**; everything else is a reversible choice by Claude. Number reserved in `Car-Hop-Art/DECISION_NUMBERS.txt` after checking every local and remote branch (0016 to 0026 used or reserved). Builds on [[0025-speedway-visible-levels]] and [[0018-task4-island-redesign]] (walking boost).

## Decided (Adam, 2026-10-29)
- **No advertising** anywhere on the Raceway, at any level: no fictional sponsors, brands or ads (Pip's Pops, Comet Cola, Haul Buddy Tires, the four banked-wall banners, the blimp lettering, the big-screen rows). Each is replaced by plain painted race decoration (Design 1). This supersedes the brief §2.5 line "any banners use our own fictional names" for the Raceway.
- **"Raceway" is the player-facing name.** Internal code, files and attributes may keep "Speedway".
- **The level-up banner states the level only** ("RACEWAY LEVEL 5!"); level names stay internal labels.
- **The kiosk becomes the Raceway shop** with a shopkeeper, a stats board (Lap Pay multiplier, not a picture) and an upgrade panel; Studio-preview purchases only.
- **Lap Pay multiplier is the only earning stat per level**; lap time stays about 15 s. The curve (1.00, 1.10, 1.20, 1.35, 1.50, 1.70, 1.90, 2.15, 2.40, 2.70, 3.00, 3.50) is Adam's **proposal for Brian L**, read from one table.
- **Parking spots:** everyone starts with **2**, at most **15**, bought one at a time, each dearer than the last (proposed ×1.6, Brian L sets the first price); separate from Raceway levels with a separate save field (proposed `ParkingSpots`).
- **Island walking base 32** (twice Roblox's 16); the boost lanes multiply it (48). Home island only; runs follow Brian R's rules.
- **UI approved** (2026-10-29, "approved for all ur reccomendations and yes upload the meshes", on the approval page https://claude.ai/artifact/97zrdVD9wkB5nnFZQXmYgQ and the Figma page node 25-747): the upgrade panel, the parking panel, the banner, the stats board, the big screen, the shop fascia, the parking sign and plaque, the Raceway text. With his choices: a new UI token Teal #228A92 (plus light teal #51D7D1 for text on navy); the banner on one line wherever it fits; panel padding 20 desktop and tablet, 16 phone; the shop roof stays at 8.5 studs (it hides more of the near turn from a camera 12 up than the old 6-high kiosk, about the same from standing eye height). Recorded in `vault/design/visual-direction.md`.
- **Mesh upload approved:** the 9 new and repainted Raceway meshes go up under Adam's account (no Car Hop group yet).

## Reversible choices (Claude)
1. **The shop is 9 x 7 x 8.5**, 0.5 inside the measured Kiosk reservation (10 x 8, height 9). Adam's target envelope (12 x 8 x 10.5) does not fit it; enlarging the reservation would push into the entrance court or the Paddock, so it was not done. The keeper stands on a 0.6 step behind the 3.0 counter so the chest shows. Alternatives: a taller reservation (11.5) for the full 10.5 roof, or moving the stats board inside the booth.
2. **Shop and keeper are part of the client-assembled look** (feature `Shop`, every level), not the island build, because the keeper is animated on each client and greets only that client's plot owner. The island recipe no longer places the old `KioskBooth` mesh or its blank panel.
3. **Parking is drawn per client** from a plot attribute (proposed contract `ParkingSpots`, set by the server; Studio preview `Lane3ParkingPreviewSpots_PlotNN`), like the level. The island recipe keeps only the Paddock floor, aisle and pit lanes; Lane 2's bay markers (`Hub/Markers` Bay01..Bay15) are unchanged. Bays a plot does not own are plain floor (no painted tile, no collision).
4. **Bay order is Hub/Layout's** (row A from the centre out, then row B), so spots 1 and 2 are the two middle bays of the park-side row.
5. **Parking sign** in the Paddock's free left margin (plot x -33.8, u 264.2), mirroring the shop across the gate; no reservation existed for it.
6. **Grandstand end caps are parts** placed once at the stand's two outer ends (the bay mesh repeats, so caps in the mesh would double at every join). The optional checker strip on the stand was not added: the track's checker line already marks the finish.
7. **Repainted meshes load from preview data until the re-import**; their earlier uploads are kept as `KitIds.Superseded` (they hold no lettering: every sponsor and blimp word was a SurfaceGui). The four banner images stay uploaded but unreferenced.
8. **Run handover in the preview** uses the existing takeover attribute `MovementSpeedOwner`, set by a labelled Studio-only fixture while the player stands in a portal field (`Home/Island/RunModeFixture.client`). The real signal is Brian R's ([[walk-boost]]).
9. **Walking details** by the walking worker (spec [[walk-boost]]): the island base and the boost are separate switches; a boost never slows a base above 48; dust puffs replace the earlier wind trails, streaks and foot glow; low detail = saved graphics quality 1 to 3.
10. **Figma-first is followed** for every changed UI piece (banner, stats board, both panels, signs, big screen); the previous task's Studio-first exception was task-scoped and does not apply.

## Consequences
- The island's edit-mode build shows no shop or bays until `HubBuild.previewSpeedway()` (or Play).
- Lane 2 sends two integers per plot (`SpeedwayLevel`, `ParkingSpots`) and owns prices, Cash checks and saving; Lane 3's panels only request.
- Three repainted and six new meshes need one guided 3D Importer import.
