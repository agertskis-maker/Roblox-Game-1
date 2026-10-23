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
- WP8 Hop: done and Studio-verified (HopState, HopCue, chevron stream, LandingReticle, HopFigure icon, scenarios "Hop: ..." all PASS). WP9: code done and numerically Studio-verified (KeysLock tiers, SecuredReveal, CaptureRibbon stack/card, ClaimTray thumbnails, TradingCard, CardDetail, TradingSheet, Haptics; scenarios "Capture: ..." and "Cards: ..." PASS). **The Windows screen locked mid-session (lock screen is foreground): no further screenshots or videos could be taken; do NOT try to bypass it.** Captures still owed: tray thumbnails, trading sheet, card detail on phone, Keys tier 3, reveal comparison page.
- **Stage 4 done (WP10-WP12), commits c14628d, 904ac97, 9b55cca, e55e34a.** WP10: Worlds are data (`City/Worlds/*`) feeding the same Sequencer/Assembler. WP11: Downtown 4-6 storeys, taller middle distance, skyline, tree rhythm, hazard sightlines, theater blade 88, route 3,095; median NOT in the chase (Blender sample + dependency for Brian R, not sent). WP12: Dusty Highway (53 meshes) and Summit Pass (56 meshes) kits, per-World palette, WorldLife ambient layer; Edit traversals clean, Play merge mode 0 failures (timing discarded: unfocused). Kits output in `Car-Hop-Artdowntown-kit-worlds` (+ prepared OBJ/FBX batch packages, NOT uploaded). **The in-engine `screen_capture` still works while the Windows screen is locked** (viewport capture, stills only): evidence in `reviewhud-round2worldsstudio-edit`. No video is possible while locked. Next: Stage 5: WP13 music, WP14 integration (HUD backdrop with Worlds, perf, B2 upload needs GUI clicks), WP15 reviewer, review page, board/log, release lock.
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
9. Hop: one coordinated target (ring, arc, reticle, rim, one brief HOP word), best timing debounced (80 ms in, 180 ms out), one gold accent per window and id, whoosh throttled to 0.6 s.
10. Capture: the car shudder is DEFERRED; tier 3 decoration is one capped pulse (1.0 Hz), sparse sparks, transparent edges, outranked by warnings. Countdown only with trusted timing.
11. SECURED: tray count changes once at confirmation; wide screens get the full card only where it clears the protected rectangle; phones get a compact stack (riding chip steps aside); the old side ribbon is used only where it clears the tray.
12. Cards: fixture family Bus maps to Truck (flagged); Heat capacity comes from the outline family table (documented seconds, Tunable); Lap Pay and flavour are preview fixtures.

## Escalation triggers (focused Opus turn only for these)
(a) city generator for non-urban frontage (WP10), (b) SECURED reveal placement algorithm (WP9),
(c) tension-music approach if layers clash (WP13), (d) visual-only car shudder that cannot be separated (WP9).
