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

## Current files (this task)
- Docs: `vault/design/specs/hud-rebuild-downtown-b.md`, this file,
  `vault/decisions/0019-hud-arcade-rebuild-preview.md`, research notes in `vault/design/research/`
  (hud-ref-arcade-translation, capture-feedback, runner-progress-failure,
  modular-city-composition, sound-candidates).

## Lock log
- 09:20 island lock present (07:40). Repo work only.

## Next actions
1. Core contracts: PreviewTokens Arcade block, Arcade.luau, Store types, Priority.luau.
2. Launch workers HA HH HS HR HW DK DC with owned files.
3. Recheck the Studio lock about every 10 minutes.
