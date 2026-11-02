---
title: Lane 3 Round 3, for Brian R
date: 2026-11-02
tags:
  - design
  - lane1
---

# Lane 3 Round 3, for Brian R

None of your files were edited. Everything below runs from the beta glue and can move into your code when you want it. Frames: `Car-Hop-Art/review/round3/evidence/`.

## 1. Run camera (please try this first)
Adam: the view from behind the car is too low and things block it. I built a tuner that re-aims your camera one render step after yours (`src/client/UI/LaunchPad/RunCamera.luau`), so your smoothing, jolts and field-of-view punches all stay. In the beta, press **F4** during a run for sliders and presets.

Recommended, "Higher":

| Your value | Now | Recommended |
|---|---|---|
| `CAMERA_BACK` | 15 | 18 |
| `CAMERA_UP` | 8.5 | 14 |
| `CAMERA_LOOK_AHEAD` | 34 | 30 |
| Aim height (the `+ 2` in `ChaseCamera.step`) | 2 | 0 |
| `CAMERA_FOV` | 70 | 70 |

Please set these in `RunConfig` when you agree, and we delete the beta module.

## 2. Launch Pads and the START hook
A portal now goes to a Launch Pad (`src/client/UI/LaunchPad`). The ramp opens a card, and START calls `startRun(world)` in `BetaRun`: `RunController.new`, `run:start()`, as before. RETRY goes straight into another run; HOME goes back to the island.

Ask: `Options.startCar` on `RunController.new`, so the car a player picks at the stall is the car they start in. Today every run starts in your Loaner, and the stall says so.

## 3. Stamina (bolts)
Adam asked for this so runs can't go on forever. The rule is the proposal from HUD Round 2: 10 bolts a run, one spent on each hop that really happens, a refused press spends nothing, and at zero you can't hop. A free or paid respawn gives 3 back.

It works from outside by putting a `requestHop` field on your run object, in front of your method (`LaunchPad/RunStamina.luau`). It's a stopgap. Please move the rule into `RunController.requestHop`.

## 4. Respawn
Your `run:revive()` and free revives are reused. After the free ones, the results card offers a cheap Robux respawn (PREVIEW, ends in Coming soon).

Ask: a `Revive` event carrying its source (free or paid), for the run report.

## 5. Trail on the player's car
`attachTrail` in `LaunchPad/init.luau` puts two attachments and a `Trail` on the HumanoidRootPart. It's cosmetic only.

Ask: a `run.CarChanged(model)` signal, or a public `getRiddenModel()`, so the trail can sit on the car's tail instead of the rider.

## 6. Results data
The new card reads `getDebugState()`: `mode`, `metres`, `hops`, `claimed`, `revives`. It hides your temporary `Lane1RunOverlay.Results`, and it calls nothing but `revive`.

Ask: results that say the rarity of each claimed car, and a `ResultsShown` moment. Rarity is guessed from the title today.

## 7. Still open, from earlier messages
- A `"None"` scenery option, so Lane 3 can stop trimming your road segments.
- Tutorial events: first hop landed, claim confirmed, run ended with a reason. The tutorial infers them at 15 Hz.
- The "Cut lanes... Hop: Space" hint and "Lane 1 run prototype" label: the beta hides the hint from outside, because phones play too.
- The Stunt Circuit handover in `lane3-round2-for-brian-r.md`.

## Replies

### Brian R

_(your answer here)_
