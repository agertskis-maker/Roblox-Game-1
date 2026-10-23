---
title: HUD rebuild + Downtown B — checkpoint
tags: [design, spec, checkpoint, lane3]
status: live
date: 2026-10-22
---
# Checkpoint (read this first after a context change)

Ledger and plan: [[hud-rebuild-downtown-b]]. Branch `feature/lane3-hud-downtown-lookdev`, worktree
`Roblox-Game-1-hud`. Draft PR #2. Board claim on main `ca25d44`.

## Tool ownership
- Studio: island session holds `Car-Hop-Art/STUDIO_LOCK.txt` (taken 07:40). This task does no
  Studio step until the file is gone; then it writes its own lock ("car session (HUD rebuild)").
  Never seize, never close the island place, never repoint its Rojo server.
- Blender: one operator only = worker DK (headless `blender --background`, safe mode, no MCP
  edits); it writes `Car-Hop-Art/BLENDER_LOCK.txt` while running and checks for another
  `blender.exe` first.
- Memory floor 4 GB free (6.0 GB at 09:20 with island Studio open).

## Approved vs proposed (short)
- Approved and reused: rev-4 CurrencyCounter/CashIcon + its gain behaviour, Format.cash,
  Fredoka One sizes, touch 48/56, scale rule, Reduce Motion rule; GDD Decided: permanent claim,
  Joyride Bonus exists.
- Adam's task decisions: B selected; Cash/cars bottom left; Heat bottom centre; Keys beside
  rider (full redesign); Settings red labelled; big-gain preserved; interfaces held; Figma
  skipped for this task only; sound candidates for listening; free steering is Brian R's.
- Everything else is a preview value (PreviewTokens `Arcade` block, timings, segment counts,
  road width, district lengths, +$50 Joyride, "+$120 / lap").

## Decisions made so far (reversible)
1. Italic numbers/timers candidate: Nunito Black Italic (verified installed: Roblox font
   families list Black Italic 900). Fredoka One stays for labels.
2. Decision note number 0019 (0016–0018 used on the island branch / this branch).
3. Board claim on main via the clean tooling worktree (board-only commit).
4. Keys ring: 8 segments (brief range 8–12; capture research suggested 4; low end of the brief kept for phone clarity).
5. Arcade tokens retuned to the measured references: wide 150×60, corner 5, boundary 3, label 28, icons 0.74×h inside the edge, gap 8; Settings 84×40 visual with a 48 hit box (measured 35 is below the approved touch size).
6. References: HUD screenshots copied as 1920-wide JPGs (originals 5 MB PNGs stay in Car-Hop-Art); 11 dino frames + analysis copied verbatim to vault/design/references/dino-study/; provenance README.
7. Sound candidates (16 verified ids) loaded through Sounds.luau routes, two per category, A/B switchable; CashBig deliberately left without an asset (none was ever approved).
8. Downtown kit contract set by the lead (pivot front-left of footprint, 96/192 straights, R 360 curves, 4 × 17 lanes default); the research note proposed bottom-centre pivots and 192-only segments — kept as a later option.

## Current files (this task)
- Docs: `vault/design/specs/hud-rebuild-downtown-b.md`, this file,
  `vault/decisions/0019-hud-arcade-rebuild-preview.md`, research notes in `vault/design/research/`
  (hud-ref-arcade-translation, capture-feedback, runner-progress-failure,
  modular-city-composition, sound-candidates).

## Lock log
- 09:20 island lock present (07:40). Repo work only.
- 09:39 still present; passes 2 h at 09:40 — per the lock rule, told Adam instead of touching it.
- 10:06 still present. Workers hit the API session limit about 10:05; resumed 14:40.
- 14:50 still present (7 h old; island Studio window open, its session probably stopped at the same limit). Asked Adam to release it or say "take the Studio lock"; not touched.

## Workers (launched 09:30–09:45)
HA icons+specimen, HH home, HS screens/Results, HR run+Keys, HW world+fixtures, DK Blender kit (only Blender operator), DC city grammar (asked to run client-side in Play too). Lead-owned files committed in 2d1b401.

## State at 14:50
All seven workers finished. Commits (local, not pushed): 2d1b401 (lead core + docs), bc229f8 (HUD rebuild + city grammar), 5328426 (B2 kit recipes + manifest; HUD playground city backdrop). check.ps1 passes; both playground places build. Kit output: Car-Hop-Art/downtown-kit-b2 (140 meshes, 37,591 tris, FBX batch package, 5 palettes); renders in Car-Hop-Art/review/hud-rebuild/downtown/blender/.

## Next actions (all need Studio)
1. Lock: write own lock; `rojo build playground/hud.project.json -o Car-Hop-Art/CarHop-HUD-Playground.rbxl` and the downtown equivalent; open in a separate Studio window (never the island place).
2. HUD place, Play: specimen sheet (`:Invoke("play","Specimen: composed")`) over the city backdrop (`useCity(true)`), compare with both references, fix kit tokens; check Arcade.STROKE_FOLLOWS_UISCALE.
3. Record the §18 fixtures (worker scenario names), four profiles, reserved zones, perf with HUD + city + traffic.
4. Downtown place, edit mode: `City.run({seed=2207})`, 2,000-stud chase video, width study, stats, reset pass.
5. Batched click for Adam: 3D Importer of downtown-kit-b2.fbx (only if Play-mode meshes are needed beyond EditableMesh previews).
6. Reviewers (HUD/reference, run, city, integration) on captures; fixes; review page; log; board (free-steering note for Brian R); push; PR #2.
