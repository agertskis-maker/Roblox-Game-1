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
- **Cost:** the walking goals (worst at most 12 s boosted, spread at most 4 s) are not met, and not only for the wings. Measured in Studio with the preview walkers (default rigs on the planned routes, the boost state machine applied to their WalkSpeed; table on the review page): Garage worst 23.42 s and spread 10.35 s, Stunt worst 22.65 s and spread 9.58 s (a mirrored pair, so the 0.8 s difference is walker noise; unboosted 26.7 s, spread 13.6 s); Downtown worst 14.83 s, spread 1.05 s; Summit Pass and Dusty Highway worst 16.6 s, spread 2.88 s; the fountain 10.77 s. A real character walking Plot 1 to Downtown on the client boost took 13.70 s (the walkers: 13.78 s). Corrected 2026-10-23: the first version of this note said "a Studio playtest with the boost"; those numbers came from the walkers, not a player.
- **Why 12 s is out of reach here** (movement review): a plot entrance is 207 studs from the plaza edge (8.8 s boosted) and the fountain alone measures 10.7 s, so no destination past the plaza can be reached in 12 s at 1.5x on this island radius; a mirrored east / west pair cannot get much below 14 s worst. The goal is a geometry limit, not only a sightline trade.
- **Proposal for Adam (not built):** boost strips on the two wing approaches would bring the Garage / Stunt worst to about 19.6 s and the spread to about 6.1 s (model), with no sightline cost. It extends the brief's "middle third of each avenue", so it waits for Adam. At the Task 3 positions the worst boosted walk was 15.6 s (Garage) and 18.3 s (Stunt gate), with a waterfall obstruction.
- **Alternative for Adam:** a narrower Garage (about 46 wide) on the north axis between corridors 3 and 4 walks like Task 3, but cannot be mirrored with the Stunt entrance.

## 2b. Portal row, gate setback and the waterfall (revised the same day)
The first checker sampled each sight ray at 40 points (about 12 studs apart) and stepped over thin
objects; Studio's PortalSight then showed the new gate columns hiding up to half of Plot 5's
waterfall and 7–15 % of the field edges from Plots 1 and 6. With an exact ray test
(`task4-layout.js`, Cyrus-Beck clipping) and a sweep over spacing, row position, gate setback and
the falls position:
- **Portal spacing 58** (was 28 in Task 3), row front at y -56.
- **Gate setback 2.6**: each gate frame stands behind its field plane, so the field is drawn in
  front of its own columns and is never clipped from an oblique entrance.
- **The waterfall moves 18 studs east** (falls line x -120 to -102) so every entrance's view of the
  falls passes between two gates; the side falls (tarn, side stream, horsetail) are switched off
  (`Cascade.SideFalls = false`), leaving the one main curtain the brief asks for.
- **The Most Cars Owned board** stands beside the Garage approach path (0.57 of the way from the
  plaza, 17.5 studs off on the lake side; the Fastest Stunt Circuit board mirrors it): beside the
  Garage itself it hid half of Plot 6's falls, and at 14 off it stood 1.2 studs inside the
  12-wide approach (movement review M3). `board-sweep.js` finds the clear window k 0.54 to 0.59,
  off -16.25 to -19.
- **Results.** Model (`task4-layout.js`): 0 % of any portal field and 0 % of the lower or upper
  falls hidden from any entrance. Studio (PortalSight, 2026-10-23, the built island): the falls
  100 % visible from all six entrances; the portal fields 100 % except **Plot 2 to Dusty Highway and
  Plot 5 to Summit Pass at 97.81 %**: at spacing 58 each side field lies on the line from the far
  plot through the fountain centre, and the approved grand fountain hides the field's low edge
  (scaling the fountain to 0.9 gives 99.33 %; left for Adam). The model's tall list leaves out the
  fountain, so its 0 % is not the in-game figure.
- **Locked portals** (measured 2026-10-23): with the lock built, 48 to 62 % of the Dusty Highway and
  Summit Pass fields stay visible (65 to 72 % without the chains); the falls stay 100 %. The lock is
  meant to be seen in front of the field, but it conflicts with "full portal-field visibility" in
  the locked state, which is what players see by default. Decision for Adam (a smaller or lower
  padlock and plaque, or accept).

## 3. River loop
One continuous loop, lake to lake: a circle of radius 157 about the fountain from bearing -78 to 78, with legs down to the lake on both sides, 16 wide, mirrored. Eight bridges: the six avenues and the two wing approaches. The lakeside walks now join the wing approaches before their bridges, so no other path crosses the river.

## 4. Formal park
All non-tree dressing is placed in mirrored pairs (either both sides pass every rule, or neither is placed). Snack corners at bearing ±34, radius 192: bearing 60 hid 47 % of Plot 2's lower waterfall, and 30 hid 1 % of Plot 3's. The gazebo is on the axis at (0, 196). The leaderboards stand beside the wing approaches (§2b). Review fixes (2026-10-23): the snack corners stand on bordered paved pads (their 30 x 28 boxes) with 8-wide spurs from the front edge to the nearest avenue, and the gazebo on a round pad with a spur to the promenade on the axis (movement review M4); the 24 straight avenue beds are removed and every remaining bed has a green bedding carpet (complaint review J1).

## 5. Shore rule
Every dry-land piece must have its whole footprint (corners and centre) at least 3 studs from the lake waterline and 4 from the river edge. The car topiary (the "turtle on a brown pad") stood in the lake because the old rule never tested the shore; it is removed. Until 2026-10-23 the validator tested 0 margin and the dressing only (complaint review J10, movement review M6); `Task4Checks.shore` now tests the stated margins on the dressing, the destinations, the portal gates and the bridges, plus a beach band (no piece on bare sand: the terrain under the hub buildings, leaderboards and portal gates is lawn), with 0 failures.

## 6. Walking boost
`src/shared/Island/WalkBoostLogic.luau` (numbers and state machine), `src/shared/Movement/SpeedModifiers.luau` (the largest multiplier wins, nothing stacks, the exact base speed is restored), and the client controller `src/client/Home/Island/WalkBoost.luau`. One switch, `WalkBoost.ENABLED`, plus the run-time attribute `Lane3WalkBoostEnabled`. Takeover: the LocalPlayer attribute `MovementSpeedOwner` makes the boost stand aside completely. State guard (movement review M1): no boost while seated, swimming, climbing, ragdolled or dead; a 1 s grace in the air so a hop keeps it. WalkBoostTests 206 / 206 in Play (2026-10-23). The boost holds 0.5 s after leaving a strip and then eases for 0.5 s (base speed back 1.0 s after leaving; the brief says "roughly 0.5 s"; reversible with `Linger = 0`). Spec: [[walk-boost]].

## 7. Review fixes and the choices made for Adam (2026-10-23)
After the three fresh reviews (architecture, complaint ledger, movement / layout), reversible, each pending Adam's review:
- **Garage showroom:** with no finished car yet, the turntables and the lift carry a car under a red-orange dust cover, tyres showing; no car look is designed (car looks are Brian L's, [[0015-car-modeling-to-brian-l]]). The back-wall panel reads SHOWROOM with a PREVIEW tag.
- **Plot gates:** the beam reads YOUR SPEEDWAY until Lane 2's plot ownership supplies a name ("PLAYER NAME" read as a broken template); the checker strip is half height under the collars; the flags taper to pennants.
- **Waterfall:** the ledge basin sits inside the ledge (radius 7.5; at 9.5 its front hung out of the cliff as a floating bowl); the curtain is 18 wide (from 14); the rainbow spans 92 studs across the curtain foot at transparency 0.62 or more, its feet faded.
- **Bridges:** each deck is long enough for its corners to land 4.5 studs clear of the river on the real (curving) river; Bridges 01 and 06 are 31 long, the kit mesh stretched along the path.
- **Fountain ring:** round fillets tangent to the path edge and the plaza circle, and the path strips keep their run-on at every end that is not a bridge cut (that lost run-on, not the fillet shape, left the grass crescents).
