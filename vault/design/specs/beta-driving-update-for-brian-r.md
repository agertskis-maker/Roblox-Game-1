---
title: Beta driving update, for Brian R
date: 2026-11-05
tags:
  - lane1
  - lane3
---

# Beta driving update: notes for Brian R

From Adam (Lane 3), written with Claude Code on 2026-11-05. Decision [[0040-beta-driving-update-stamina-shop]]. Your commit `38e7995` ("easier Circuit and a much better Hop") is merged into `integration/beta-driving-update` and published to the private Car Hop Beta. **Your files were not edited** (`src/client/Run`, `src/shared/Run`); the merge kept your `RunFx.luau` where it conflicted. Everything below lives in `src/client/Beta/BetaRun.client.luau`.

## 1. The run is paid through the Round 5 bridge

Same bridge as [[lane3-round5-for-brian-r]] section 1: the server seed goes into `RunController.new`, `run._report.Batch` and `.Urgent` go to `BetaRunEvents` and `BetaKeysComplete`, Retry or Home sends `BetaRunEnd`. Your commit did not change `RunReport` or the event fields, so nothing broke. The server rebuilds your traffic with the same shared `RunSequence` and `RunConfig`, so your warm-up stretch and the new spacing are the same on both sides. Tested: claims and joyrides paid in Downtown and Dusty Highway.

**Ask:** a public `run.Report` (and the sequence) would let the bridge stop reading `run._report` and `run._sequence`.

## 2. The Rider Level gate is off in the beta (Adam: not at launch)

The beta passes `session.level = 999` (above your largest need, 80 x 2.6 = 208) and hides your "Needs N" tag lines and the "Rider Level" corner label. **Blocker for you:** the gate is still in your code. When you remove it, delete `GATE_OFF_LEVEL` and the two hide hooks.

## 3. Your road cars show Brian L's cars (Adam asked for it)

- Each `Proxy_` model in `Lane1_RunZone.Traffic` keeps moving exactly as you move it; the beta hides its parts (Transparency, not `LocalTransparencyModifier`, because your in-car view and fade reset that) and puts the showroom car `BetaRunMap` names for it inside the model. Your rarity underglow stays. The car you start on shows the car picked on the launch card. Motorcycles show a car too (no real bike exists, and a catch is always a car).
- Your tag titles, the "You got the Keys!" and "Joyride Bonus!" banners and the NEW / JOYRIDE tray name the real car, keeping your size and variant words.
- Your `session.owned` is seeded before each run from the save, so NEW, JOYRIDE and "owned" agree with what the server pays. Your `start()` marks the loaner family (`Compact_Common`) owned; in the beta that family is a car to catch, so only that one mark during `start()` is ignored.
- Known limits: the Heat tint and the Gold and Chrome looks colour your hidden parts, so they do not show on the real car (the Heat bar still shows Heat); the in-car view hides your cabin parts, not the real car's roof.

**Ask:** when your run spawns real cars (or reads Brian L's Catalog), all three adapters are deleted.

## 4. What the tests saw

- Feel: the warm-up stretch and the gentler Circuit made first claims easy in solo play; the landing marker and the red outline on the car you are about to hit read well. Overheat ends a run as "Meltdown".
- One hop costs one bolt (checked with separate key down and key up). The Studio test tool's single "key press" registers as two hops; that is the tool, not your input.
- A missed hop with nothing in reach ends the run at once ("Crashed into ..."), even with bolts left. Intended?
- 59 to 60 frames per second in Studio with 24 real cars on the road.
- Your Heat panel stays on screen behind the Results card after a run ends.

## 5. Two lines Adam may want changed

- "Lane 1 run prototype · stand-in cars and labels · nothing is saved" is still shown at the bottom of the run. In the beta the cars are real and the run is saved. Could it go, or be switchable?
- Your first-claim Heat assist is per play session, not per save, so a returning player gets it again each session.
