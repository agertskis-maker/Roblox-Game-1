---
title: Lane 3 Round 2, for Brian R
tags:
  - spec
  - teammate
---

# Lane 3 Round 2: for Brian R

From Adam (Lane 3), sent through the vault on 2026-11-02. Written by Claude Code. Nothing in your code was changed. Please answer in the Replies section at the bottom (you or your AI).

## The Stunt Circuit is yours now (Adam, 2026-11-01)

You build the course and its gameplay. Lane 3 keeps only the screens (pre-race, results, leaderboard, customization) and the gate and leaderboard sign on the island.

An optional starting kit is in `src/lookdev/Stunt` (course parts, `StuntData` with its centre line, checkpoints and obstacles). Use it, change it or throw it away. Lane 3 will not touch it again.

The screens need these from your race. None of them exists yet, so all of them run on labelled PREVIEW fixtures today.

| Event | What it means | Payload wanted | Who reads it | Until then |
|---|---|---|---|---|
| Race start | The countdown ended | course id, car id | `StuntPreRace` | Fixture |
| Checkpoint | A gate was passed | index, split time | `StuntMock` | Fixture |
| Finish | The race ended | valid or not, time in seconds | `StuntResults` | Fixture; an invalid run shows NOT FINISHED and no medal |
| Ghost gap | Compared with the best | seconds, or nil | `StuntResults` | "No ghost comparison" |
| Medal | Which was earned | none, bronze, silver, gold | `StuntResults`, medal-locked paints | Fixture |

This does not declare a remote contract on your behalf. Tell us what you would rather send.

## Asked before, still open

1. **The `"None"` scenery option.** Your test scenery has no off switch, so the World stands far beside the road, mostly behind your stands. See `lane3-big-round-for-brian-r.md`. It unlocks the most.
2. **Tutorial run events.** The tutorial reads your run through `TutorialRunAdapter` (`getDebugState` and `Ended` only). Steer, hop, claim and heat need observable events. Exact gaps:

| Step | Needs | Observed now |
|---|---|---|
| Steer | Left and right input seen | Read from the run's debug state, not an event |
| Hop | A hop that landed | Read from the run's debug state, not an event |
| Keys | A car fully claimed | Read from the run's debug state, not an event |
| Heat | Heat rising | Read from the run's debug state, not an event |
| Home | A way home from Results | Your Results has Revive and Retry, no HOME: the step's words say HOME |

3. **First-run assists.** Runs in the beta end at about 40 to 55 m when nothing steers, which is also what a new player will do.

## Controls wording

The tutorial says "Press A and D" and "Press Space" on keyboard, "Use the thumbstick" and "Tap Hop" on touch, "Use the left stick" and "Press A" on gamepad. These are defaults from the old legend. Please confirm them, or give `controlText` to the tutorial.

## Replies

### Brian R

_(your answer here)_
