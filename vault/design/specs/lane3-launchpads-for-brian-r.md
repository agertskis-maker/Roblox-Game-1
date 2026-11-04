---
title: Launch Pads and bolts, for Brian R
date: 2026-11-02
tags:
  - design
  - lane1
---

# Launch Pads and bolts, for Brian R

None of your files were edited.

**Bolts.** A run now has 5 bolts, 1 per hop (it was 10). A respawn gives 2 back (it was 3). The tutorial run has 8. All three are Tunable and live in `src/client/UI/LaunchPad/RunStamina.luau`, wrapping `run.requestHop` from outside your code as before. Please move the rule into `RunController` when you agree the numbers.

**START.** START now runs a countdown of about 1.4 seconds on the gantry, then calls `startRun(world)` as before, so your run still starts at green. The pad leaves the Workspace first.

**Worth checking.** With 5 bolts, please say whether runs feel too short, and whether the Heat rules still make sense.
