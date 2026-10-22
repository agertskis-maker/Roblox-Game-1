---
title: "0017: Garage and Stunt gate not relocated"
date: 2026-10-22
tags:
  - decision
  - island
  - layout
status: proposed
---

# 0017: Garage and Stunt gate not relocated

> [!note] Decision for Adam
> Written by Claude Code on 2026-10-22, during island rework Task 3, while Adam was asleep (silent mode). Claude Code left the buildings where they are, which can be undone. Adam picks one of the options below. Ledger IRW-100 in [[island-rework]]; log [[2026-10-22]].

## What was asked
Task 3 brief item 2: move the Garage and the Stunt gate to about (-56, 30) and (56, 30), mirrored, and keep every check passing. Targets: worst walk at most 12 s with the boost, and at most 4 s best to worst.

## What was found
- **Both target spots sit inside viewing corridors 2 and 5.** A building there would hide the portals from those entrances (IRW-15, the corridor rule).
- **No spot outside the corridors reaches a 4 s spread.** The layout optimizer found none. The spread is geometric: an equal walk from all six entrances needs the destination close to the fountain axis, and that is where the corridors run.
- **Walks with the buildings where they are** (server walk tests, Play, seconds over plots 1 to 6, boost lanes as a preview):

| Destination | Boost off: worst / best / spread | Boost on: worst / best / spread |
|---|---|---|
| Garage | 18.40 / 9.57 / 8.83 | 15.57 / 7.38 / 8.19 |
| Stunt gate | 22.40 / 12.32 / 10.08 | 18.30 / 10.18 / 8.12 |

Both targets are **not met**. Every destination was reached from every plot.

## Options for Adam
1. **Keep the current spots and extend the boost lanes** (garden ring and the two approaches). The revision-pass simulation (2026-10-22, before Task 3) gave Garage 12.78 s worst and 5.88 s spread, Stunt gate 16.92 s and 7.07 s. Still short of the targets, and the real boost waits for Brian R's movement contract.
2. **Move only part of the way** toward the target spots, stopping at the corridor edge. Shorter walks, but the spread stays above 4 s.
3. **Accept the spread.** Adam already relaxed the Garage and Stunt gate on 2026-10-21 (IRW-17: the Garage opens from a button anywhere and players do not compete on the island). The 4 s spread and 12 s worst would become Tunable goals.
4. **Change the corridor rule** so a building may stand in part of corridor 2 and 5. The requested spots could then be used, but the portals would be partly hidden from those two entrances. The walks at those spots have not been measured.

## Why the buildings stayed
The viewing corridors are an approved rule, and the portals are the hub's main feature. Breaking the rule needs Adam's choice, and the walk targets cannot be met without breaking it. Nothing else depends on the current positions, so any option above can be built later.
