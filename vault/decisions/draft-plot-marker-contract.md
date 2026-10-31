---
title: "Draft: plot-marker contract between Lane 3 and Lane 2"
date: 2026-10-20
tags:
  - decision
  - contract
  - island
status: proposed
---

# Draft: plot-marker contract between Lane 3 and Lane 2 (PROPOSED, not approved)

> [!warning] Unnumbered on purpose
> `main` has decisions 0001 to 0009, `feature/lane3-first-car-downtown` adds 0010, and this branch adds 0011 (eight plots). Another session may take the next number, so this draft has no number yet. It gets the next free number when it is accepted and merged.

## Proposed decision
Plots are found by stable names: `Workspace.Island.Plots.Plot01` to `PlotNN`, where `NN` runs to the `PlotCount` attribute on `Island` (8, per [[0011-eight-plots-per-server]]); Lane 2 never hard-codes the count. Each plot holds an invisible `Markers` part whose Attachments give the gate spawn, nameplate anchor, Speedway path (a summary plus ordered samples about 5 studs apart, counter-clockwise), 15 ordered bays (three marked initial) and pit-lane points. Cosmetic geometry lives under `Visual` and may change freely. Full spec: [[plot-marker-contract]].

## Why
- Lane 2's assignment code and Lane 3's island are built by different people at different times (open item in [[0007-concept-car-hop-and-lanes]]).
- Attachments under one anchor part are cheap and give exact world transforms. Names are stable where display text and colours are not.
- One `PlotCount` value means the count can change by decision without touching Lane 2 code.
- The Speedway is no longer an oval, so the samples carry the shape and the summary carries the totals.

## Needs
- Brian L (Lane 2): agree or change the names, the spawn method and runtime attributes.
- Brian R (Lane 1): confirm that the path direction and the start line suit Lineup visuals.
- Adam (Lane 3): go-ahead for the revision 2 layout in [[island-base]] (plot count already decided).

## Reverting
Delete this draft and the contract note; nothing depends on them yet.
