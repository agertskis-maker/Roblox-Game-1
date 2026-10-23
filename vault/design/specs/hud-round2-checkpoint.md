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
- Stage 1: R2-G1 done (GitHub = local at 14:20). Ledger, decision 0020, Heat inventory written. Heat baseline captured
  (original + round-1 segmented). `Run: Heat sequence (HEAT_SEQ)` scenario added. **Next: commit Stage 1, then WP3.**
- Stage 2 → 5: open.

## Decisions made so far (reversible)
1. Orientation set in the two playground projects only (Adam, 2026-10-23); `default.project.json` line recorded for the team.
2. Heat adapter keeps `HeatGauge` unmodified; segmented bar kept unmounted as a debug variant.
3. Heat baseline hosted the original panel standalone (as `RunHud` does), not via `RunHudPreview`.

## Escalation triggers (focused Opus turn only for these)
(a) city generator for non-urban frontage (WP10), (b) SECURED reveal placement algorithm (WP9),
(c) tension-music approach if layers clash (WP13), (d) visual-only car shudder that cannot be separated (WP9).
