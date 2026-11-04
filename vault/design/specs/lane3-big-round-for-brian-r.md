---
title: Lane 3 big round, message for Brian R
date: 2026-11-01
tags:
  - lane3
  - lane1
  - message
---

# Lane 3 big round: message for Brian R (Lane 1)

From Adam, with Claude Code. Earlier open items stay in [[worlds-dusty-summit-for-brian-r]] (D1 to D7, S1 to S8) and [[island-walking-for-brian-r]]; they are not repeated here. Nothing below edits your files. Every item is a proposal.

## What Lane 3 built that touches you

- **Worlds beside your road.** `src/client/UI/WorldsUnderRoad/RunScenery.luau` streams the World's roadside scenery beside your road on `integration/beta-2` only. One switch: the attribute `WorldScenery` on `ReplicatedStorage.CarHopBeta`. Normal game: never required.
- **Tutorial run steps 2 to 5** listen through a Lane 3 adapter (see section 2).
- **Stunt Circuit course and screens**: `src/lookdev/Stunt/`, data proposal `StuntData.luau`. Looks only: no collision, no gameplay.

## 1. Scenery contract (M8)

**What was read from your code, without editing it:**

| Fact | Source | Note |
|---|---|---|
| Road start | `RunConfig.ORIGIN` = `CFrame.new(0, 400, 0)` | y up, travel toward -Z, centre line x = 0 |
| Width | `RunConfig.ROAD_HALF_WIDTH` = 38 | 4 lanes x 17 + 4-stud shoulders each side; same as the look-dev road |
| Distance | `run:getDebugState().along` | studs. A temporary read, not a contract |
| End of run | `run.Ended` | Signal. Used for cleanup |
| Scenery | `RunRoad.new(zone, seed, profile.scenery)` | only `"Canyon"` or `"Circuit"` |

**The blocker.** Your test scenery cannot be turned off through the API, so Lane 3 stands outside it: the Circuit's grandstands reach about 140 studs from the centre line, and every Lane 3 piece is moved out 96 studs. The World therefore reads as a backdrop behind your stands, not as a street beside the road.

| Proposal | Player benefit | Cost | Risk | Test |
|---|---|---|---|---|
| **R1.** Add `"None"` to `RunConfig.Scenery`: `RunRoad` builds the road surface, shoulders and paint only | The Worlds finally look like Worlds in a run: buildings close to the road | About 10 lines in `RunRoad` | Low. Off unless a profile asks for it | Run with `"None"`, set `PUSH = 0` in `RunScenery`, drive one loop |
| **R2.** A public `run:getAlong(): number` and `run.road` geometry fields (`origin`, `halfWidth`) | The adapter stops depending on a debug call | Small | None | Adapter reads it; delete the debug use |
| **R3.** District and hazard alignment: who decides where a hazard stands relative to a World district | Hazards can have warning signs and a clear approach | Needs a decision | Sequencing with the seed system | Two runs on one seed show the same order |
| **R4.** Curves. The Worlds are planned with bends; your road is straight, so `sceneryOnly` lays every curve straight | Worlds keep their shape if your road gets bends | Larger | Touches steering and camera | Later |

**Clash list if R1 is not taken:** Circuit grass and gravel to 90 studs, tyre wall and fence at 89 to 93, grandstands 100 to 136, roof to 140, advertising boards reading CAR HOP, start gantries every 1,000 studs.

**Ownership proposal:** Lane 1 owns road, lanes, collision, camera, hazards as gameplay. Lane 3 owns everything further than the shoulder. The look-dev road pieces are not used in a run.

## 2. Tutorial events (M11)

| Event wanted | Read today | Missing |
|---|---|---|
| Steered left and right | Lane 3 samples lateral from `getDebugState` | a clean `Steered(direction)` is nicer, not needed |
| First hop landed | not observable as an event | `HopLanded` signal |
| Claim confirmed | not observable | `ClaimConfirmed(carId)` signal. The tutorial may only say "It's yours!" on this |
| Heat stage changed | `getDebugState` Heat value | `HeatStageChanged(stage)` |
| Run ended and why | `Ended` results | a stable `reason` field |

**Module:** Lane 3 adapter `TutorialRunAdapter`. **Authority:** Lane 1. **Preview substitute:** stand-in events in the HUD playground. **Test to replace it:** full tutorial in the beta with real events.

### First-run assists (yours to build)
Sparse traffic, no hazards in the first 300 m, half-speed Heat until the first claim, and a slow wide first target. Player benefit: a five-year-old lands a first hop. Cost: a `firstRun` flag on the profile. Risk: the first run teaches a slightly easier game. Test: three new players, first hop within 30 seconds.

## 3. Canyon (M6-04)

The gorge is now twice as wide (124 from the centre line) and striped cliffs stand on both rims. From your run camera the deck still fills the view: a ray over the balustrade reaches 1 to 2 studs below the rim (decision 0029). The floor and river cannot be seen from the road. **Needed for a deep read:** lower or open balustrades, or a higher camera over the bridge. Both are yours. Lane 3 does not fake it.

## 4. Stunt Circuit (M17)

Data proposal: `src/lookdev/Stunt/StuntData.luau` (units, origin, axes, centreline, widths, section ids, warning positions, visual bounds, checkpoint transforms, restart zones). Art bounds are separate from proposed hitboxes. Moving obstacles are visual-only. Needed from you: driving, collision, checkpoint logic, ghosts, timing, and whether the 75-second target suits your fastest and slowest cars.

## Lane 3 meanwhile

Keeps the adapter behind its switch on `integration/beta-2`. Nothing merges to `main` that needs your code.

## Replies

### Brian R
