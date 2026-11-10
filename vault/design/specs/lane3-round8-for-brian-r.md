---
title: Lane 3 Round 8, run changes for Brian R
tags: [lane3, round8, lane1, handoff]
---

# Round 8 run changes for Brian R (N-01)

Adam's Round 8 session changed files in your run folders, with his Round 7 permission to edit every lane for the items in his
brief. They are copied onto `feature/lane1-round8-from-adam` (from `feature/lane1-round7-from-adam`) and offered to you as a pull
request into `feature/lane1-run-prototype`. Nothing is merged into your branch; you decide. Your structure and naming are kept.

| File | Change | Why |
|---|---|---|
| `src/client/Run/HopGuide.luau` (new) | Lock-on arrow over the car a Hop would land on, dive path chevrons and landing ring, the label of that car grows a little (`CarTags.setFocus`) | R-01, R-02: Adam's new lock-on and dive arrows |
| `src/client/Run/TrailMoments.luau` (new) | The trail reacts to speed, leap, dive, landing and hop chains | T-03 to T-05 |
| `src/client/Run/RunController.luau` | Wires HopGuide and TrailMoments; the run car wears the player's look from its first frame; **no floating "HOP NOW!" banner** at Meltdown (the Engine Heat panel already says it) | C-02, R-01, Adam's declutter ask |
| `src/client/Run/CarTags.luau` | **Declutter:** no car name line; the rarity word smaller; the tag sized in studs so far tags shrink instead of stacking; Common and Uncommon tags only within 35 and 50 studs (Rare 110, Epic 160, Legendary 220); `setFocus` for the lock-on | Adam: "declutter the actual gameplay by removing the names of the cars and making the rarities slightly smaller" |
| `src/client/Run/ChaseCamera.luau` | `intro(seconds)`: the launch hero moment, replayable in Studio | X-01 |
| `src/client/Run/RunFx.luau` | One line for the trail hand-off | C-02 |

`RunController.title` still builds the old "size, rarity, family" string for anything that calls it; only the floating tag lost
the name. The beta's own run client (`src/client/Beta`, not your folder) also hides the player's own VIP sign during a run.

Checks: `./scripts/check.ps1` passes on the branch. Studio: the merged beta build ran the end-to-end look test (40 of 40 PASS:
paint, decal, wheels and trail on the run car, the trail following a real hop) and every server self-test; the run screen was
reviewed by screenshot after the declutter. Phone layouts of the lock-on were not re-checked after the declutter.

## Replies

