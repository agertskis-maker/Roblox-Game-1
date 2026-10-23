---
title: Round 2 — checkpoint (read this first after a context change)
tags: [design, spec, checkpoint, lane3]
status: live
date: 2026-10-23
---
# Checkpoint

Ledger [[hud-round2]]; Heat evidence [[hud-round2-heat-inventory]]; decision [[0020-hud-round2-presentation]].
Plan (outside the repo): `C:\Users\agert\.claude\plans\cosmic-prancing-jellyfish.md`. Branch
`feature/lane3-hud-downtown-lookdev`, worktree `Roblox-Game-1-hud`. One lead, at most one reviewer.

## Ownership and environment
- Studio lock: `Car-Hop-Art\STUDIO_LOCK.txt` taken 2026-10-23 14:20 ("car session (HUD round 2)"); delete it only at the end.
- Memory floor 4 GB; log: `Car-Hop-Art\review\hud-round2\memory-log.txt` (helper `memlog.ps1`, stops when the lock is gone).
- Island Studio window is open and untouched. Blender idle (no lock).
- Helpers (session scratchpad): `reopen.ps1 hud|downtown`, `grab.ps1`, `seq.ps1`, `rec.ps1` (now write to `review\hud-round2`),
  `keepfront.ps1 -ProcId -Seconds`, `memlog.ps1`.
- Baselines (outside Git): `Car-Hop-Art\baselines\round2-start\`.

## Stage status
- Stage 1: done (GitHub = local at 14:20; ledger, decision 0020, Heat inventory, baselines).
- Stage 2: done and Studio-verified: WP3 landscape-only (property read in Edit and Play; six frames), WP4 Cash/Home (no car count, Garage pill cases, Shop seamless rainbow, pickups, Results source row, ribbon/chip/panel restyle; cards and banner restyle ride with WP9/WP7), WP5 original Heat (equivalence table, fit per frame, reduced-motion Meltdown). Commits: c5890c9 + later.
- Stage 3 in progress. WP6 Stamina: done and Studio-verified (incl. reduced motion). WP7 route line: done and Studio-verified (RouteLine + RouteMath, ten new original district tiles in Icons2, WorldRoutes fixtures, scenarios in `scenarios/Route.luau`: all PASS for the three Worlds; videos r2-route-cycle-desktop.mp4 and r2-route-cycle-summit-phoneL.mp4). Next: WP8 Hop, WP9 capture/reveal/tray/cards. Stage 4: WP10-12 Worlds. Stage 5: WP13-15.
- Harness additions (playground only): `setWorld(id)`, `setRecord(recordM, verified)`, `setSpeed(mps)` (0 holds the distance), component key `routeLine` (was `strip`), scenarios "Route: …".

## Decisions made so far (reversible)
1. Orientation set in the two playground projects only (Adam, 2026-10-23); `default.project.json` line recorded for the team.
2. Heat adapter keeps `HeatGauge` unmodified; segmented bar kept unmounted as a debug variant.
3. Heat baseline hosted the original panel standalone (as RunHud does), not via RunHudPreview.
4. Heat scale steps 1.0/0.92/0.89 (label >= 16 px); tablet and PhoneSmall use the soft thumbstick overlap (<= 60 px), flagged ThumbstickSoft.
5. Garage button is taller by Arcade.PillExtra (26) so icon and label keep full size; pill drops "CARS" then the total when it would not fit.
6. Overlay restyle through Arcade.surface (gradient fill, one thick outline, gloss): gold ribbon, red warning chip, blue RIDING chip, blue tray review; Style panels brightened to cobalt.
7. Route line: schematic equal visual stretches per district (marker pace from the explicit unequal lengths); monotonic total distance per run; NEW BEST needs a verified record (nil counts as verified) and fires once per run; wider block than the old strip (600 x 161 desktop, 430 x 109 phones).
8. District tiles for Dusty Highway and Summit Pass are original scenes in Icons2 (triangle helper clips a rotated square at the base line).

## Escalation triggers (focused Opus turn only for these)
(a) city generator for non-urban frontage (WP10), (b) SECURED reveal placement algorithm (WP9),
(c) tension-music approach if layers clash (WP13), (d) visual-only car shudder that cannot be separated (WP9).
