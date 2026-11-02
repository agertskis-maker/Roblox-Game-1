---
title: "0031: Lane 3 big round, the choices made"
date: 2026-11-01
tags:
  - decision
  - lane3
status: accepted for the preview; Adam can overrule any item
---

# 0031: Lane 3 big round

Brief: [[lane3-big-round]]. Ledger: [[lane3-big-round-ledger]]. Adam gave Claude Code judgment for this round; each choice below is reversible.

## World and Raceway
1. **Height layers replace overlaps.** Path 0.08, pad border 0.14, promenade 0.16, pad 0.20, plaza 0.24. Each kind of surface has its own height, so where two meet the higher one wins and nothing can flicker. Paint sits 0.12 above the road.
2. **Paving went from cream to a warmer stone** (WorldPalette) because the old cream bloomed to plain white in daylight, which is what hid the path edges.
3. **Beds:** one 2-stud clearance. Fountain beds moved out to one shared radius (68). Flowers are tested by the corners of their whole footprint against the bed's true outline (`BedShapes`), and a clump only goes in if it fits on both mirrored beds.
4. **No loose lawn flowers.** Every park flower is in a bed. Chosen over deliberate wildflower borders for the tidier read.
5. **Benches:** 24 only, in pairs facing across the avenues at two radii. Lamps: matched pairs. Lamps left the corridor rule and are judged by the portal ray test instead, because the corridor rule removed nearly all of them. Portal visibility stays at about 96 to 98% from the plot gates; the small loss is lamp posts.
6. **Fruit trees removed.** Their floating apples are inside the mesh, 52 to 59 loose pieces per canopy. A re-export can bring them back.
7. **Fountain:** a gold car statue on a tall pedestal, built from Parts and the group-owned `SwStatueCar`, so no upload. Nose raised 13 degrees toward the portals. The sunken car turned out to be `FountainGrand` itself.
8. **Raceway one line system:** white edge lines, red and white curbs on corner insides only, no centre line. Racing line and yellow lines removed.
9. **The loop** is now built along the cars' own lap path from track pieces, on a road widened by 6.8 studs with smooth triangle edges, so no car can clip it and there is no pad. `SwLoopTrack` is no longer used. The flame decal is gone.
10. **Clutter:** shed, lemonade stand, chair, barrels and wheelbarrow removed from every level. The snack cart stays, in the fan zone.
11. **PIT ROW** is Part-built, not a mesh, so it needed no upload.
12. **Pit lanes** meet the track at a shallow angle and share its asphalt colour.

## Worlds
13. **Dusty:** 41 part-built structures (`DustyStructures`) in the plan's five districts, no new upload. Live parts peak at about 460, **over the plan's 400 Edit ceiling** by about 15%. Triangles and unique meshes stay inside. Accepted for Adam's review; merging structure Parts into meshes is the fix.
14. **Gorge:** half width doubled to 124 plus five striped cliffs on the rims. The floor still cannot be seen from the run camera (decision 0029). Reported, not faked.
15. **Tumbleweeds:** 4 to 2, and lighter coloured, because the dark ones read as rolling black balls.
16. **Shop boards off** in Dusty and Summit. Each building carries its own sign. Only a few wayfinding signs remain.
17. **Summit:** a named exception `longGapBeside = GlacierTunnel` up to 780. **The bell tower is a pin, not a planned landmark**, at 108 studs on the same spot every seed. It no longer takes part in the spacing rule.
18. **Seed 314 fails `landmark-majors`:** ChaletCluster to SkiLift to FrozenLake are 378 and 366 apart against the 500 rule. Four of five seeds pass. Not hidden, not weakened.

## Worlds under the road
19. **Adapter:** `src/client/UI/WorldsUnderRoad/RunScenery.luau`, switched by the attribute `WorldScenery` on `ReplicatedStorage.CarHopBeta`. `sceneryOnly` lays the route straight, from Brian R's origin, and pushes everything out 96 studs.
20. **Generated `KitBounds.luau`** lets uploaded meshes stand correctly without the mesh JSON, so the beta file needs no kit folders.

## UI
21. **Shop:** BEST DEAL, SAVE and strikethrough stay off in normal preview presentation, on as a marked fixture only. No separate full-width bundle banner: the leading bundle card plays that role.
22. **Loading screen:** `ReplicatedFirst` is mapped in `beta.project.json` only; `default.project.json` is untouched. The boot script lives in `src/replicatedfirst`, outside `src/client`, so the normal game never runs it.
23. **Group pop-up:** session cap only. A client cannot enforce a daily cap.
24. **Honesty notes** are named `HonestyNote` so the playground's caption toggle cannot hide them.
25. **Figma:** not used. The brief allowed building straight in Studio, and the project's Figma read limit made a round trip poor value.
26. **Robux symbol:** the word "Robux" is used until an official source is confirmed.

## Tooling
27. `OverlapScan` compares only faces pointing the same way, so a shared interior wall is not flicker. MeshParts are counted as manual, never cleared.
