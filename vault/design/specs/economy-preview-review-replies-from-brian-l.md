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
On 2026-11-05 Brian L said to answer with what he decided before ("just add what i told you too initially"). Items 2, 3, 8 and 9 come from those earlier decisions. Items 4 to 7 had no earlier decision; Brian L accepted Claude's recommendations for them the same day ("Yes, accept them").

2. **A1 `Copies`: Agree, the lifetime total.** Brian L chose the lifetime ladder on 2026-11-02: Gold 25, Diamond 250, Rainbow 2,500, Galaxy 25,000 copies ("a little easier but still extremely rare, like getting an heirloom in apex but even rarer").
3. **A2 car list: Adam's list** (9 per World, two Legendaries each, Putter as the starter car). Brian L first answered "his list" from his 2026-11-03 approval, then on 2026-11-05 chose Adam's list after the team chat asked for every World to have its own Legendaries ("approved option 1"). Now in `Catalog.CarWorld`.
4. **A3 Lineup removal rule: Agree.** `carId = nil` removes the car; the Lineup has no gaps; a spot the player emptied stays empty; auto-fill only places a new claim. Built in the preview on 2026-11-05 (Brian L: "Approved, go ahead"): `SetLineupSlot(slot, nil)` removes, and buying a parking spot no longer fills it.
5. **A4 remote names: Agree, the `EconomyPreviewNet` names win** (`StartRun`, `RunEvents`, `KeysComplete`, `RunGranted`).
6. **A5 Expanded Paddock: Agree.** Saved `ParkingSpots` stays 2 to 15; the plot attribute `ParkingSpots` is bought + 3 with the pass (up to 18), and `ExpandedPaddock = true`.
7. **A6 Robux: Agree.** `economy-v1.md` section 11 now says the Robux purchases are in. OK for Lane 3 to propose the receipt-history and owned-passes-and-trails fields; their exact names still need "Agreed". Conditions: no paid luck, editions and cars never sold for Robux, and no pushy sale tactics (no crossed-out "was" prices, "Best deal" or "Save %" badges, timers or limited stock). The current Shop preview shows a crossed-out 647, "SAVE 15%" and "BEST DEAL"; please remove them.
8. **Section 3 numbers: the candidate** (Brian L, 2026-11-05, "approved option 1", after the team chat asked for later Worlds to make more money): Lap Pay $10 / $25 / $60 / $150 / $400, claim bonus 10x and Joyride 3x the Lap Pay, World pay factor x1 / x40 / x1,600 (field `payFactor` on `Catalog.Worlds`). Raceway, parking and World prices are unchanged, including $2T for level 12. This replaces the first answer (economy v1 numbers).
9. **Cash cap: $1Qa (10^15).**

Checked: `./scripts/check.ps1` exit 0; Lune Catalog tests pass; the new distance rule was computed against Lane 1's `RunSequence` in the Car Hop Beta place (calculation only, nothing changed): 94 of 94 real nearby Hops accepted, `d = 10,000,000` refused at t = 1 s and at t = 3,600 s, a 100-stud step backwards refused. Not tested: a full run through `Runs.report` in Play, because the economy preview is not synced into any place open right now.
