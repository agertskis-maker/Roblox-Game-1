---
title: "Draft 0013: six plots on a half-circle island (proposed amendment to 0011)"
date: 2026-10-21
tags:
  - decision
  - island
  - design
status: proposed
---

# Draft 0013: six plots on a half-circle island

> [!warning] Proposed, not accepted
> Drafted by Claude Code for Adam (Lane 3 owner) on 2026-10-21. It becomes `0013-six-plot-half-circle-island.md` with `status: accepted` only after Adam approves the layout ("Approved: island layout — build the greybox."). Until then [[0011-eight-plots-per-server]] stands. The plot count and server size also need Brian L (Lane 2) to agree, since they change a shared contract ([[plot-marker-contract]]).

## Proposed decision
- The island hub is a **half circle**: six plots on the curved side face a central park, and the three portals stand across the straight side facing the plots (Downtown in the middle). A lake, a waterfall and mountains lie behind the portals; foothills and forest wrap the rest.
- **6 plots, at most 6 players per server.** Each plot is a 30 degree sector with an 8-stud buffer inside it on each side. The plot count stays one config value (`PlotCount`).
- Every plot is laid out the same way, front to back: park, entrance and front facilities (Paddock with 15 bays of capacity, kiosk, nameplate, front buildings), the oval at the outer rear, then future expansion.
- The oval keeps the approved lap: path 427.1, track 16 wide, turns R 35, long axis pointing outward.
- Walking targets, all unboosted at the default WalkSpeed: entrance to fountain at most 20 s, and at most 2 s best to worst for the fountain and each portal. The Garage and Stunt Circuit gate follow Adam's choice in the layout review; with them outside the viewing corridors, the measured layout gives 8.8 and 9.8 s best to worst.

## Supersedes (from [[0011-eight-plots-per-server]])
- 8 plots in 45 degree slices, and 8 players per server.
- "Any plot gate to any shared plaza destination in under 8 seconds" (ISL-12 in [[island-base]]), measured at 8.08 s in Stage A.
- The island footprint of about 515 to 600 studs across. The hub becomes about 1,340 across including the foothills.

0011's "one config value" rule and its note that Lane 2 never hard-codes the count still apply.

## Why
- Adam's rework brief (2026-10-21): a stadium audience facing a stage, with every plot the same and room for the whole upgrade path (50-stud side bands, grandstand, floodlights, gantry, pit building and screen, sign band, elevated track and loop, statue and fireworks).
- Measured in `assets/island/rework/island-layout.js`: with those reservations, six 30 degree plots need an entrance radius of 247.2 and reach 561.1. All reservations fit with no conflicts.
- Five plots would shorten every walk by about 4 s but would not fix the Garage and Stunt gate fairness, which is geometric.

## Consequences
- **Lane 2:**
  - `PlotCount` 6 and Max Players at most 6.
  - Plot positions and facing change; marker names can stay. `LayoutVersion` bumps.
  - Slots, passes and saved data are unchanged.
- **Lanes 1 and 2:**
  - The lap length is unchanged.
  - Lineup cars at most 90 (was 120).
  - Any walking boost is theirs to coordinate; none is planned.
- **All lanes:** the larger hub makes the streaming proposal more important.
- **Lane 3:**
  - The Stage A 8-plot build stays on `feature/lane3-island-base` as history.
  - The greybox is rebuilt from revised recipes on `feature/lane3-island-rework`.

## Reverting
Set `PlotCount` back to 8, restore Layout revision 2 from `feature/lane3-island-base`, and re-run the layout checks.
