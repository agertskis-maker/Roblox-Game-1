---
title: "0018: Task 4 island redesign: lakeside destination wings, river loop, gate families, formal park, walking boost"
date: 2026-10-22
tags:
  - decision
  - island
  - layout
status: proposed
---

# 0018: Task 4 island redesign

> [!note] Pending Adam's review
> Written by Claude Code on 2026-10-22 during island rework Task 4. Adam's Task 4 brief authorizes these revisions; it is **not** final approval of the island, which stays pending "Approved: island rework". Each choice below is reversible. Ledger IRW-127 onward in [[island-rework]].

This note supersedes, for the island preview only:
- [[0016-frameless-portal-rendering]], on the frame: the portal **fields** stay frameless energy (no ring, disc or card), but each now stands inside a themed **gate**: two columns and a crest (brief §8). The fields' own rendering rules in 0016 still apply.
- [[0017-garage-stunt-not-relocated]]: the Garage and the Stunt Circuit entrance **are** relocated, to the positions below.
- The Task 2 S-stream ("partial river"): replaced by one mirrored river loop.
- The loose, seeded park dressing: replaced by mirrored formal dressing.
- The visual-only boost lanes (IRW-102): a real 1.5x walking boost is now built, with a takeover path for Brian R (brief §13; explicitly authorized).

## 1. One centre axis
`island-layout.js` `P.task4.axisX = 0` is the only axis. Mirrored pairs are (x, y) and (-x, y); the checker (`assets/island/rework/task4-layout.js`) fails any pair that differs by more than 0.01 stud.

## 2. Garage and Stunt Circuit entrance: lakeside wings
- **Chosen:** the Garage at plan (187.9, -52.1) and the Stunt entrance at (-187.9, -52.1) (bearing ±105.5, radius 195), both facing the fountain, where the promenade ends meet the lake. Envelopes: Garage 62 x 40, top 34; Stunt 37 x 40, gantry top 18.
- **Why:** a search over every mirrored position (widths 54, 62 and 70) with ray tests from 27 eye points at each of the six entrances found that every closer position fails a sightline:
  - inside about r 130, every spot hides part of a portal field from at least one entrance;
  - the flanks beside the portal row hide all of Plot 6's waterfall view (and the mirror spot cuts Plot 2's);
  - the gaps between avenues near the ring fit at most a 47-stud front, too narrow for a two-level Garage with a workshop and a three-turntable showroom.
- **Cost:** the walking goals (worst at most 12 s boosted, spread at most 4 s) are not met: planned boosted worst 22.6 s, spread 12.0 s. The brief makes these goals, "not permission to break sightlines". At the Task 3 positions the worst boosted walk was 15.6 s (Garage) and 18.3 s (Stunt gate), with a waterfall obstruction.
- **Alternative for Adam:** a narrower Garage (about 46 wide) on the north axis between corridors 3 and 4 walks like Task 3, but cannot be mirrored with the Stunt entrance.

## 3. River loop
One continuous loop, lake to lake: a circle of radius 157 about the fountain from bearing -78 to 78, with legs down to the lake on both sides, 16 wide, mirrored. Eight bridges: the six avenues and the two wing approaches. The lakeside walks now join the wing approaches before their bridges, so no other path crosses the river.

## 4. Formal park
All non-tree dressing is placed in mirrored pairs (either both sides pass every rule, or neither is placed). Snack corners at bearing ±34, radius 192: bearing 60 hid 47 % of Plot 2's lower waterfall, and 30 hid 1 % of Plot 3's. The gazebo is on the axis at (0, 196). The leaderboards stand at the north end of each wing forecourt (18 x 15).

## 5. Shore rule
Every dry-land piece must have its whole footprint (corners and centre) at least 3 studs from the lake waterline and 4 from the river edge. The car topiary (the "turtle on a brown pad") stood in the lake because the old rule never tested the shore; it is removed.

## 6. Walking boost
`src/shared/Island/WalkBoostLogic.luau` (numbers and state machine), `src/shared/Movement/SpeedModifiers.luau` (the largest multiplier wins, nothing stacks, the exact base speed is restored), and the client controller `src/client/Home/Island/WalkBoost.luau`. One switch, `WalkBoost.ENABLED`, plus the run-time attribute `Lane3WalkBoostEnabled`. Takeover: the LocalPlayer attribute `MovementSpeedOwner` makes the boost stand aside completely. Spec: [[walk-boost]].
