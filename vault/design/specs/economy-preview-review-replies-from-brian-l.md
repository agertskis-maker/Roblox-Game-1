---
title: Economy preview review - replies from Brian L
date: 2026-11-05
tags:
  - lane2
  - lane3
  - economy
  - review
status: partial
---

# Economy preview review: replies from Brian L

Answers to Adam's `economy-preview-review-for-brian-l.md` (branch `feature/lane3-round6`), written by Claude Code for Brian L on 2026-11-05. They are kept here on `feature/lane2-economy-preview` because that file is on Adam's branch. Only the items Brian L has answered are filled in.

1. **F1 to F4 fixed: done 2026-11-05** (Brian L: "Approved, go ahead"). In `src/server/EconomyPreview/Runs.luau` and `Economy.luau`:
   - F1 and F2: every event's `d` is checked before it is used: not more than 5 studs backwards, and at most `RunSequence:travelledAt(t)` + 1,500 studs, the same as `BetaRun.Caps`. Milestones count at most `travelledAt(t)`. A Hop is checked before `ensure` runs, so a far `d` can no longer freeze the server.
   - F3: at most 5 claims plus Joyrides a run (the bolt count). Paid respawns and the Stamina upgrade do not raise it yet.
   - F4: Cash is capped at `Catalog.MaxCash` = $1Qa (10^15), below 2^53.
   - Also: `StartRun` has a 0.75 s cooldown.
2. A1 `Copies` is the lifetime total: _not answered yet_
3. A2 which car list: _not answered yet_
4. A3 Lineup removal rule: _not answered yet_
5. A4 your remote names win: _not answered yet_
6. A5 Expanded Paddock to 18: _not answered yet_
7. A6 section 11 and the two Robux fields: _not answered yet_
8. Section 3, candidate numbers: _not answered yet_
9. **Cash cap: $1Qa (10^15).**

Checked: `./scripts/check.ps1` exit 0; Lune Catalog tests pass; the new distance rule was computed against Lane 1's `RunSequence` in the Car Hop Beta place (calculation only, nothing changed): 94 of 94 real nearby Hops accepted, `d = 10,000,000` refused at t = 1 s and at t = 3,600 s, a 100-stud step backwards refused. Not tested: a full run through `Runs.report` in Play, because the economy preview is not synced into any place open right now.
