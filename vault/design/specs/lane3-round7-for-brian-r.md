---
title: "Round 7: message for Brian R (Lane 1)"
tags:
  - lane1
  - lane3
  - handoff
---

# Round 7: message for Brian R (Lane 1)

Hi Brian R. Adam opened every lane for Round 7 and you agreed, so his beta changed some of your run files. All of it is on `feature/lane1-round7-from-adam`, as pull request #17 into your `feature/lane1-run-prototype`. **Nothing was merged into your branch.** Merge it, change it or close it. Decision: [[0042-lane3-round7]]. Ledger: [[lane3-round7-ledger]].

## Files changed in your folders

| File | What changed | Why (Adam's playtest) |
|---|---|---|
| `src/client/Run/RunController.luau` | R-01 two-press Hop: the first press leaps (1 bolt) and you float at 0.6x speed; the second press dives onto the car in the ring. A dive that misses is a bonk on the road (1 bolt) with a short recovery. R-02 Heat now builds over the Keys time + 3 s, with a warning on the car. R-04 driving into a car costs 1 bolt, then 1.5 s free. R-05 the rider is always hidden inside the car. A `Boarded` signal fires when you board a car (the beta dresses that car in your Style Shop look). | R-01 (the two-press Hop from the reference video), R-02 (Heat "far too slow"), R-05 ("at times you'll spawn on top of the car"). |
| `src/client/Run/CarTags.luau` | R-10 three lines: the rarity word large and in its colour, the car's name, a red "new!". A tag is seen from further away the rarer the car (Common 70 studs, Uncommon 90, Rare 150, Epic 210, Legendary 280). | R-10 (the label was too small to make Adam chase the car); far Common tags piled up on the horizon in Studio. |
| `src/client/Run/CarVisual.luau` | The Legendary light beacon reaches height + 260 (was + 40) and is wider. | Rare cars should shout from far down the road. |
| `src/client/Run/RunReport.luau` | New event kinds: Leap, Bump, Bonk, Thrown (1 bolt each). Hop is now the dive. | The server counts bolts too. |
| `src/shared/Run/Luck.luau` (new) | The one luck rule (L-02): luck L multiplies Legendary and Epic weights by L and Rare by 1 + (L - 1) / 2; Commons never below 35%. Has a 20,000-spawn self-test. | Section 0 item 10. |
| `src/shared/Run/RunSequence.luau` | Spawn odds go through Luck (on top of Brian L's commit 9c06811 on this branch: one car size, doubled rare odds, a luck parameter, rare-car effects). | |
| `src/shared/Run/RunConfig.luau` | R-03 `ROAD_CAR_SCALE = 1.25` (one size for every road car), with hop reach, float reach and camera raised to match; the Heat, Hop and bump values above. | Section 0 item 16. |

## What was checked

- `./scripts/check.ps1` passes on `feature/lane1-round7-from-adam`.
- `RunPlayground.client.luau` still finds every RunController call it makes.
- Played in Adam's local beta (`integration/beta-5`) in Studio: runs, the two-press Hop, bumps costing bolts, WRECKED, Results, End Run.
- **Not checked:** your RunPlayground itself in Studio.

## Questions for you

1. Do you want the two-press Hop as the only Hop, or a setting?
2. Is 0.6x the speed you want while floating?
3. Can the run get a "scenery off" option? Today the beta trims your roadside from outside (`src/client/UI/WorldsUnderRoad/RunScenery.luau`).

## Replies

