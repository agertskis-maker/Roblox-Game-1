---
title: Island rework (Lane 3)
tags:
  - design
  - island
  - layout
status: draft
---

# Island rework: half-circle hub (draft, Task 1 layout proposal, pending Adam)

> [!warning] Proposal only
> Written by Claude Code for Adam (Lane 3 owner) on 2026-10-21. Nothing here is built. Task 1 produces an approved layout and then a walkable greybox. The greybox starts only after **"Approved: island layout — build the greybox."**, and detailed environment work only after **"Approved: island greybox."** This note is the requirement ledger for the whole rework; later sessions extend it rather than starting a new one.

> [!note] Approved 2026-10-21 (Adam)
> "Approved: island layout, build the greybox, with 6 plots, in my private place only." Garage and Stunt gate walking spread accepted (IRW-17); speed-boost target picked by Claude, Tunable (IRW-17). The four images downloaded at 10:36 to 10:37 are confirmed as the island references, and Adam pasted his original island brief; the rows it added are IRW-26 to IRW-29. The plot-count change still needs Brian L (board). The greybox is built from `src/island/Hub` (data generated from `island-layout.js` by `export-luau.js`); the Stage A build stays available as the switch-back.

Review page (computed diagrams and sketches, not Studio captures; private to Adam): https://claude.ai/artifact/KfFBw5PDnqN7atDDLVqHgR

## Sources
- Adam's message of 2026-10-21, "Car Hop Island Rework — Task 1: layout and spatial validation". Where it differs from earlier notes, it wins.
- The earlier island brief (2026-10-20 session), its ledger ISL-01 to ISL-16 in [[island-base]], decision [[0011-eight-plots-per-server]], the plot-marker draft [[plot-marker-contract]], [[GDD]] and [[car-hop-outline-v2]] sections 04 and 08 (Slots, Paddock, Income Tiers).
- **Missing evidence.** The message says an "original island brief" and four reference images are attached. Neither arrived in the session. The only island brief on record (2026-10-20) has none of the rework's numbers and says no island images were supplied. Four images were downloaded to `Downloads` at 10:36 to 10:37 on 2026-10-21, about 20 minutes before the message: a dark stone portal frame with a glowing purple field (two renderings), a steep grey rock valley with pine forest, a stylised low-poly snowy mountain with pines, and a green terrain mountain range with a waterfall and lakes. They match the portals, mountains, waterfall and lake in the brief, but are **not confirmed** as the references, so nothing below depends on them. Everything the message lists is carried here; numbers it does not give are labelled "my proposal".

## Baseline (verified 2026-10-21)
- Branch `feature/lane3-island-base`, in the worktree `Roblox-Game-1-island`: commits `27a0623` to `7b8e8f5` (Stage A recipes `35e7463`, Stage A results `7b8e8f5`). **Not merged and not pushed**: `main` (local `868842a`, remote `56e0976`) contains only the claim commit `cdfb12b` of this work.
- Decision 0011 (8 plots, 45 degree slices, under-8-second walks) and `vault/design/island-base.md` exist only on that branch.
- Stage A built 8 plots in `CarHop-Island-Test.rbxl`. The plot-gate-to-Downtown walk measured 8.08 s against 8 s; Adam had not answered before this rework.
- This rework continues on `feature/lane3-island-rework`, branched from `7b8e8f5`. Stage A work is kept unchanged.
- Studio lock: `Car-Hop-Art/STUDIO_LOCK.txt` (memory note `studio-lock-rule`). No Studio step was taken for Task 1's layout review.

## Structure (from Adam)
A stadium audience facing a stage. Six plots sit on the curved half-circle. The central park lies in front of them, and three portals stand across the straight side, facing the plots. Behind the portals are a lake, a waterfall and substantial mountains, and foothills and forest wrap the rest of the hub. Every plot is laid out the same way: **park → entrance and front facilities → oval at the outer rear → future expansion**. Downtown is the middle portal.

## Recommended layout (computed; `assets/island/rework/island-layout.js`)
Plan frame: fountain centre F at the origin, x east, y north toward the plots. Plot frame: u outward along the plot's centre line, v to the right. Units are studs.

| Item | Value |
|---|---|
| Plots | 6, centre lines at bearings -75, -45, -15, 15, 45, 75 (Plot01 west end to Plot06 east end) |
| Sector | 30 degrees each; plot envelopes keep **8 from each sector ray** (16 between neighbours). Usable half width: 58.0 at the entrance, 96.0 where the straights start (about 27.7 to 28.1 degrees of each 30) |
| Entrance radius r0 | **247.2** (gate on the promenade's outer edge, facing F) |
| Front zone | u 247.2 to 337.2 (**90 deep**, inside the brief's 80 to 100) |
| Oval | stadium oval, **long axis radial**. Centreline turns **R 35**, straights **103.6**, path **427.1** (same lap as the approved Speedway), track 16 wide, 11 from the centreline to each clearance edge. Clearance footprint 92 x 195.6; infield 48 wide |
| Oval position | near tip 343.2 (6-stud walkway after the front zone); straights 389.2 to 492.8; far tip 538.8 |
| Plot outer radius | **561.1** (outer sign band); plot depth 313.9 |
| What sets the size | the near floodlight pads at the outer corners of the 50-stud bands are the binding points, at exactly 8 from the sector rays |
| Hub | promenade r 227.2 to 247.2 (20 wide), six radial avenues 16 wide from the promenade to the plaza, fountain basin r 12 inside a paved plaza r 40 (a 28-wide walking ring), garden ring path r 135 (8 wide) |
| Portal row | Summit Pass (x -28), Downtown (x 0), Dusty Highway (x 28); fronts on y -56, facing north. Frames 22 wide, 16 opening, 36 tall (my proposal), 6 deep: a tight triptych with 6-stud gaps. A 14-wide approach from the plaza to each portal and a stage walk along their fronts |
| Lake, waterfall, mountains | lake outline: ellipse centred (0, -172), 600 x 200, its shore 10 behind the portal backs; waterfall at x -120 on the far shore, 120 tall, off the portal axis so the portals never hide it; seven placeholder peaks 140 to 300 tall from y -250 to -650 |
| Foothills and forest | band r 569 to 671 round the arc, wrapping down both ends to the mountains |
| Whole hub | about 1,340 across and 1,320 north to south including the mountains. Stage A's island was about 511 to 569 across |

### Every plot, front to back (oval radial; same in all six)
Reservations are stored in `island-layout.js` with name, bounds, intended use, allowed occupants and height allowance. Base items exist from the start; the rest are reserved space only, and none is built. Heights and pad sizes not given in the brief are **my proposal**.

| Reservation | Bounds (plot frame, v x u) | Use / allowed occupants | Height |
|---|---|---|---|
| Entrance court, gate, nameplate | v ±16, u r0 to r0+14 | gate arch, nameplate, planters under 3 | 10 |
| Kiosk | v 19 to 29, u r0+3 to r0+11 | Paddock kiosk only | 9 |
| Paddock (base) | v ±36, u r0+16 to r0+58 (72 x 42) | 15 bays of 9 x 16: row A 7, aisle 10, row B 8; 3 visible at start. Capacity reservation only; does not change Slot limits, passes or saves | 1 |
| Pit garage pads | v ±40 to ±62, u r0+20 to r0+56 | pit garage every third Slot, up to 5 (outline 08) | 18 |
| Front building strips | v ±5 to ±22, u r0+62 to r0+90 | income-tier front buildings | 18 |
| Plot walkway | v ±3, r0+58 to the oval tip | players walk to the track end | 0 |
| Pit exit / pit entry lanes (base) | 10 wide, from the Paddock's rear corners alongside the near curve to where the straights start | Lineup cars | 0 |
| Pit building | v 58 to 82, u 355.2 to 385.2 | tier 4 pit building | 18 |
| Big screen pad | v -82 to -58, u 375.2 to 385.2 | tier 4 big screen | 30 |
| Oval (base) | stadium, clearance footprint 92 x 195.6 | lap path, barrier, curb, margins | 2 |
| Elevated track envelope | the oval footprint, airspace 8 to 40 | raised deck (10 clear), ramp 72 at 1 in 6 on the right straight, supports in the 2-stud margins. **Never over the gantry segment** | 40 |
| Start / finish gantry | left straight, u 412.1 to 418.1, spanning the track | tier 3 gantry; cars cross it heading toward the park | 22 (16 clear) |
| Right band | v 47 to 85, the straights' length | tier 2 bleachers and crowds | 12 |
| Left band | v -85 to -47, the straights' length | tier 2 bleachers, **replaced by** the tier 3 covered grandstand and tier 5 roof section in the same footprint | 40 |
| Band outer walks | v ±86 to ±96, between the pads | crowd circulation | 0 |
| Floodlight pads (4) | 10 x 10 at the outer corners of both bands | one tier 3 tower each | 60 |
| Statue pad | infield, v ±6, u 379.2 to 391.2 | tier 5 champion statue | 20 |
| Loop envelope | infield, 34 x 38, centred on the straights' midpoint | vertical loop, radius 16, and its supports | 40 |
| Fireworks points (2) | infield far end, 6 x 6, open sky | tier 5 launchers | 3 |
| Outer sign and banner band | v ±96, u 540.8 to 552.8 | signs and banners; the tier 2 flag line starts here and is replaced by signs | 20 |

**Conflict check (computed):** 0 conflicts. Every footprint is inside its wedge (8 or more from both rays), and neighbouring plots never touch. Four pairs share space by rule: the oval inside its own elevated envelope; the gantry spanning the oval; the gantry inside the elevated envelope, on condition the raised deck never passes over it; and the tier 2 left bleachers replaced by the grandstand (documented replacement). No base flags, walls or banners sit in upgrade space: the flag line lives in the sign band, and the rope fence on the barrier line. Permanent trees, paths and park structures stay inside r 227.2, off every plot.

**Start / finish:** with the long axis radial, the end nearest the entrance is the near curve. The start / finish line goes on the **left straight, a quarter of the way from the near end**, so cars cross it heading toward the park and it is visible from the entrance court. The oval is not rotated and its dimensions are unchanged.

### Park
| Item | Value |
|---|---|
| Fountain | basin r 12, rim and stone under 3 so it never blocks a corridor (a water jet is a later visual); the plaza ring is 28 wide; the six avenues and three approaches end at the plaza edge, so nothing is blocked |
| Garage | 44 x 36, height 22, centred (0, 162), door facing the fountain, in the pocket between the middle plots' avenues; its approach path runs to the plaza |
| Stunt Circuit gate | 30 x 10, height 16, centred (-100, -36), west of the stage, facing the fountain |
| Leaderboards | two boards 12 x 4, 16 tall, at x ±57 on the stage line, outside the portal span |
| Gazebo | 16 x 16, 12 tall, (-138, 80), on the garden ring; food stands (decorative) 32 x 12, 8 tall, (138, 78) |
| Stream | an S from a spring in the north-west garden, round the north of the plaza and the south of the Garage, into the lake east of the portal row; 10 wide, at least 71 from F |
| Bridges | **9**, one at every path crossing: avenues 2 to 6, the garden ring (twice), the east lakeside walk and the Garage approach. Each is 16 long and 2 wider than its path |
| Viewing corridors | a triangle from each entrance to the ends of the portal row. Nothing taller than 3 may stand in one: no trees, signs or buildings. Computed: Garage, Stunt gate, gazebo, food stands and boards are **outside all six**. Kiosks and future grandstands sit inside the plots, behind the viewer |

Buildings were placed by a grid search that keeps them out of every corridor, path and the stream, choosing the place with the smallest best-to-worst walking difference.

## Walking routes (computed path network, WalkSpeed 16, no boosts)
Shortest route along the promenade, avenues, plaza (round the basin), garden ring, approaches and stage walk. Times are distance / 16; Stage A showed walked times run 0.5 to 1.2 s over such estimates when a walker stops at waypoints.

| Destination | Plot01 | Plot02 | Plot03 | Plot04 | Plot05 | Plot06 | Best to worst |
|---|---|---|---|---|---|---|---|
| Fountain (rim) | 14.6 | 14.6 | 14.6 | 14.6 | 14.6 | 14.6 | **0.0** |
| Summit Pass | 17.3 | 18.2 | 18.9 | 19.3 | 19.2 | 18.8 | **1.97** |
| Downtown | 17.7 | 18.4 | 18.8 | 18.8 | 18.4 | 17.7 | **1.09** |
| Dusty Highway | 18.8 | 19.2 | 19.3 | 18.9 | 18.2 | 17.3 | **1.97** |
| Garage | 18.5 | 14.1 | 9.7 | 9.7 | 14.1 | 18.5 | **8.8** |
| Stunt Circuit gate | 12.1 | 16.5 | 20.3 | 21.1 | 21.6 | 21.9 | **9.8** |

Studs: fountain 234.2 for every plot; Downtown 283.7 to 301.0; Garage 154.5 to 295.9; Stunt gate 193.4 to 349.6.

**Targets (from the brief; the boosted target values did not arrive):**
- Entrance to fountain at most 20 s: **met**, 14.6 s for every plot.
- At most 2 s between the best and worst plot: **met** for the fountain and all three portals (side portals 1.97 s, a thin margin to re-measure in the greybox), **not met** for the Garage (8.8 s) or the Stunt gate (9.8 s).
- The Stunt gate's worst route (21.9 s) and the stage-wing alternatives (22.2 s) are over 20 s.

**Geometric limit (why no placement fixes it):** for plots on a half circle round F, a destination at lateral offset x and depth y from F gives a best-to-worst difference of about (1.93 |x| + 0.71 |y|) / 16 seconds. Staying within 2 s needs the destination within about 16 studs sideways and 45 along the axis of F. That zone holds the fountain and the portal triptych and nothing else; a Garage or Stunt gate there would stand in every corridor. Five plots do not change this (the factor becomes 1.90 x + 0.69 y); they shorten every walk instead.

## Alternatives (numbers computed by the same script)
| Variant | Entrance r | Plot outer r | Fountain | Portals best-worst | Garage best-worst | Stunt best-worst |
|---|---|---|---|---|---|---|
| **6 plots, radial oval R 35 (recommended)** | 247.2 | 561.1 | 14.6 s | 1.09 / 1.97 | 9.7 to 18.5 (8.8) | 12.1 to 21.9 (9.8) |
| 5 plots, radial oval R 35 | 179.3 | 494.4 | 10.4 s | 1.22 / 1.93 | 7.5 to 17.7 (10.2) | 8.1 to 15.5 (7.3) |
| 6 plots, radial oval R 30 | 233.5 | 552.4 | 13.8 s | 1.09 / 1.97 | 8.8 to 17.6 (8.8) | 11.4 to 20.8 (9.4) |
| 6 plots, tangential oval R 35 | 299.9 | 587.9 | 17.9 s | not drawn | not drawn | not drawn |
| 5 plots, tangential oval R 35 | 230.9 | 518.9 | 13.6 s | not drawn | not drawn | not drawn |
| 6 plots, Garage and Stunt as stage wings | 247.2 | 561.1 | 14.6 s | 1.09 / 1.97 | 12.3 to 22.2 (9.9) | 12.3 to 22.2 (9.9) |

- **Radial beats tangential** by 52.7 in entrance radius: the near curve tucks into the narrow part of the wedge.
- **R 30** saves 13.7 in radius but leaves a 38-wide infield for the 34-wide loop envelope (2 each side).
- **Portal spacing:** 28 centre to centre meets 2 s (1.97); 38 gives 2.3 s.

## Cross-lane dependencies
- **Lane 2 (Brian L):**
  - `PlotCount` 6 instead of 8, and Max Players at most 6 (supersedes 0011).
  - Plot positions and facing change; marker names can stay. `LayoutVersion` bumps.
  - The 15-bay Paddock capacity matches outline 08 (12 Slots plus 3 from a pass) and changes nothing in Slots, passes or saves.
- **Lanes 1 and 2:**
  - The lap is still 427.1, so a 15 s lap still means 28.5 studs/s.
  - Lineup cars at most 6 x 15 = 90 (was 120).
  - Any walking boost or WalkSpeed change is theirs to coordinate; chevrons stay a visual proposal.
- **All lanes:**
  - The hub is about 2.4 times wider than Stage A's island, so the streaming proposal in [[island-base]] matters more. Place-wide settings are proposed only.
  - The shared `ServerStorage` root proposal on the board still stands. The stopgap project file stays until the team decides.

## Proposed decision amendment
Draft: [[draft-0013-six-plot-half-circle-island]]. It supersedes 0011's plot count, 45 degree slices, under-8-second walk target and island footprint. It becomes a numbered decision only after Adam approves the layout.

## Files and Studio objects to change (greybox, after approval only)
- `src/island/Layout.luau`, revision 3: half-circle geometry, the reservations table (names, bounds, use, occupants, heights), routes and corridors, ported from `island-layout.js`.
- `src/island/Recipes/Plot.luau`: the front-zone-first plot with the radial oval.
- `src/island/Recipes/Plaza.luau` becomes `Park.luau`: plaza, promenade arc, avenues, ring, stream and bridges, Garage, Stunt gate, boards, gazebo and food stands, and the portal row with placeholder fields.
- New `Recipes/Backdrop.luau`: lake outline, waterfall, mountain and foothill masses as labelled placeholder Parts.
- New `Preview/ReservationOverlay.luau`: the optional debug overlay.
- `Preview/LayoutChecks.luau`: wedge containment, overlaps and corridors.
- `Preview/WalkTests.luau`: all 6 plots to every destination.
- `IslandBuild.luau`, `Markers.luau` and `assets/island/README.md`: build order, marker positions (names unchanged) and rebuild notes.
- **Studio:** only `Workspace.Lane3_IslandPreview` in `CarHop-Island-Test.rbxl`, rebuilt from the recipes.
  - The Stage A terrain coast is removed by the existing scoped cleanup inside its measured box.
  - The greybox uses Parts for the lake and backdrop, so no new terrain area is needed.
  - Lighting keeps the existing capture-and-restore.
- **Not touched:** `default.project.json`, `src/server`, `src/shared`, Lane 1 and Lane 2 code, the car checkout and the car test place.

## Requirement ledger
| ID | Requirement | Req/Opt | Source | Acceptance evidence | Status |
|---|---|---|---|---|---|
| IRW-01 | Half circle: 6 plots on the curved side, park in front, 3 portals across the straight side facing the plots; not a ring, not portals in the middle, not a row | Required | Adam 2026-10-21 "The structure I want" | top-down diagram; greybox capture | calculated |
| IRW-02 | Six equal 30 degree sectors; buffers inside the sectors | Required | "Compute a layout" | containment table | calculated: 8 from each ray, all pass |
| IRW-03 | Same orientation on every plot: park → front → oval at the outer rear → expansion; never reversed | Required | "Every plot must have the same internal orientation" | rotated copies of one template; LayoutChecks | calculated |
| IRW-04 | Front zone 80 to 100 deep holding Paddock, parking bays, kiosk, nameplate and future front buildings; up to 15 bays as capacity | Required (planning input) | "proposed front-zone depth"; outline 08 | plot detail; bay count | calculated: 90 deep, 15 bays |
| IRW-05 | Oval at least the approved dimensions (path 427.1, width 16, tightest turn 30 or more) | Required | "Preserve at least the existing approved oval dimensions"; [[island-base]] revision 2 | track table | calculated: R 35, 103.6 straights, 427.1 |
| IRW-06 | Start / finish on a visible straight without rotating or resizing the oval | Required | "Show the proposed start/finish position" | plot detail; greybox capture | proposed: left straight, a quarter from the near end |
| IRW-07 | Entrances face a common focal region near the portal-side park; paths make it evident at eye level | Required | "Plot entrances should face" | arrows on the diagram; eye-level sketches, then captures | calculated, sketched |
| IRW-08 | Downtown in the middle, Dusty Highway and Summit Pass flanking | Required | "Downtown is the middle portal" | diagram | calculated (Summit west, Dusty east: my choice) |
| IRW-09 | Lake, waterfall and substantial mountains behind the portals | Required | structure | backdrop masses in the greybox | placeholder footprints calculated |
| IRW-10 | Foothills and forest round the remaining edges | Required | structure | diagram; greybox | placeholder band calculated |
| IRW-11 | Every expansion reservation stored as data (name, bounds, use, allowed occupants), with an optional debug overlay: 50-stud side bands, grandstand height, 4 floodlight pads, gantry clearance, pit building and screen pad, outer sign band, elevated track and supports, statue and fireworks | Required | "Preserve future expansion space" | reservation table; overlay capture | calculated in JS; Luau data and overlay in the greybox |
| IRW-12 | Conflict rules: oval inside its own elevated envelope; shared envelopes only when compatible; base items out of upgrade space unless replacement is documented; no intrusion by trees, paths, park or neighbours; no incompatible double reservations | Required | "Resolve conflicts explicitly" | overlap matrix | calculated: 0 conflicts, 4 allowed pairs with reasons |
| IRW-13 | Park footprints: promenade about 20, avenues about 16, fountain plaza with circulation, Garage, Stunt gate, leaderboards, 3 portal approaches, garden loops, S stream with bridges at every crossing, food stands and gazebo, lake boundary, soft perimeter | Required | "Park and circulation" | diagram; greybox | calculated (one garden ring; more loops in the environment task) |
| IRW-14 | Fountain never blocks the avenues; usable plaza round it | Required | same | plaza ring 28 wide | calculated |
| IRW-15 | Clear viewing corridors from every entrance to the portal row, considering trees, kiosks, signs, grandstands and the Garage | Required | same | corridor check; eye-level captures | calculated: no tall object in any corridor |
| IRW-16 | Routes measured at the default WalkSpeed on the real paths and bridges, for all 6 plots to fountain, each portal, Garage and Stunt gate | Required | "Walking fairness" | route table now; walked times in the greybox | walked 2026-10-21 in the greybox, all 36 routes reached ([[2026-10-21]]) |
| IRW-17 | Proposed targets: fountain at most 20 s; at most 2 s best to worst per destination; shorter boosted targets | Proposal (owner to confirm) | original brief per the message | route table | fountain and portals met. **Garage and Stunt gate: relaxed target, Tunable** (Adam 2026-10-21: the Garage opens from a button anywhere and players do not compete on the island): no best-to-worst limit, worst unboosted route at most 25 s. **Boosted target, Tunable** (Claude's pick; Adam had none): with any future walking boost, entrance to fountain at most 10 s and to every portal at most 13 s; a 1.5 times boost (WalkSpeed 24) would meet it. No boost is planned or built (IRW-18) |
| IRW-18 | No speed boosts or WalkSpeed changes; chevrons only as a visual proposal | Constraint | "Do not implement speed boosts" | file list | constraint |
| IRW-19 | Five-plot versus six-plot alternatives with numbers and a diagram if six cannot meet the important targets; keep the half circle and the oval size | Required | same | alternatives table and diagram | calculated |
| IRW-20 | First review: annotated top-down diagram (dimensions, orientation arrows, reservations, routes, bridges, portal row, lake, boundaries, mountain footprint), eye-level sketches from a middle and an end plot, recommended layout, conflicts, alternatives, cross-lane dependencies, decision amendment, files to change | Required | "First review" | review page | done (computed, not Studio) |
| IRW-21 | After approval: greybox with the existing construction approach; reproducible; cleanup scoped to owned objects; placeholder portal fields, lake outline, backdrop masses, park buildings, labelled as placeholders | Required, gated | "After that approval" | rebuild count, cleanup diff, captures | built 2026-10-21 from `src/island/Hub`, rebuilds give the same part count; Stage A removed by its own cleanup |
| IRW-22 | Greybox evidence: walked routes, reservation tests, annotated top-down, eye level from every entrance, middle and end views toward the portals, real-time walk from an end plot to Downtown, reservation overlay | Required, gated | same | review page with video | top-down, plaza and entrance captures and walked routes done; the real-time walk video and the overlay close-ups are not done |
| IRW-23 | Process: board claim, one ledger, log, the existing Studio lock, available memory above 4 GB, only the island test place, never the car session, no merge or publish | Constraint | message; AGENTS.md | log | constraint |
| IRW-24 | Front-zone depth and 15-bay capacity do not authorise changes to Slot limits, passes, server assignment or saved data | Constraint | "They do not authorize" | file list | constraint |
| IRW-25 | Record the change from 8 plots as a decision amendment | Required | "The proposed decision amendment" | [[draft-0013-six-plot-half-circle-island]] | drafted; Adam approved the layout, plot count pending Brian L |
| IRW-26 | Bright, kid-friendly, vibrant park: detailed nature (large and small trees, bushes, flowers) and structures, with real-looking detailed mountains in the distance | Required (environment task, after "Approved: island greybox.") | Adam's island brief, pasted 2026-10-21; references `rock-valley-pines`, `stylised-snowy-mountain`, `green-mountains-waterfall-lakes` (inspiration only) | environment sample captures | greybox has placeholder masses only |
| IRW-27 | Base track is a plain oval with yellow lines, flags, a checkered start / finish line and banners; bleachers, loops and signs come later as upgrades | Required | Adam's island brief | greybox capture of one oval | greybox: yellow edge lines, checkered line, barrier banners, flag line in the sign band (placeholders) |
| IRW-28 | Portals have **no frame**: a swirling glowing centre only, its own colours per World, mysterious but inviting, animated effects that grow stronger as you approach; locked portals dimmed, with a realistic 3D chain and a detailed sign. Supersedes the 22 x 36 frame proposal under "Choices I made" and the outline's "archways"; the 22 x 6 footprint and 36 height stay reserved | Required | Adam's island brief; reference `portal-glowing-field` (only the glowing field, not its frame or its source's look) | greybox capture; portal sample in the environment task | greybox: frameless discs in placeholder World colours (Downtown violet, Dusty Highway amber, Summit Pass ice blue, Claude's proposal), the two locked ones dimmed behind a chain placeholder with a low sign; no animation yet |
| IRW-29 | The centre area sits off to the side, partly wrapped by the plots (not a full ring), so no plot faces away from the portals; every entrance faces the centre; the centre is easy to reach | Required | Adam's island brief | as IRW-01, IRW-07 and IRW-16 | already covered by IRW-01, IRW-07 and IRW-16 (recorded so the brief is traceable) |

Carried forward from [[island-base]] to the detailed environment task, re-sited by this layout: the Garage with three empty turntables (ISL-04), the portal family and locked states (ISL-05), the Stunt gate, leaderboards with honest empty states, and signposts (ISL-06), the landscape kit (ISL-07), and presentation-only interactions with reduced motion (ISL-08). ISL-12's under-8-second target is superseded by IRW-17 once Adam approves.

## Choices I made (reversible)
- Summit Pass west and Dusty Highway east; Plot01 at the west end, numbered clockwise.
- 16-stud buffer between plot envelopes; 6-stud walkway between the front zone and the oval tip.
- Portal frames 22 wide and 36 tall so they read from about 300 studs (6.8 degrees tall from a middle entrance). *Superseded 2026-10-21 by Adam's brief (IRW-28): no frame; the footprint and height stay reserved.*
- Pit lanes alongside the near curve; pit building on the right, big screen on the left; grandstand on the start / finish side.
- Heights and pad sizes in the reservation table where the brief gives none.
- The waterfall off the portal axis (x -120).
- The stream's course; one garden ring path.

## Not yet (kept visible)
Detailed landscaping, park props, portal effects, finished scenery and lighting, the Garage interior and turntables, real cars, plot assignment and saving, upgrade tiers themselves, any audio, phone tests, streaming settings.

## Greybox results (2026-10-21)
Built and walked in the private island place; details in [[2026-10-21]].
- Walked best-to-worst: fountain 0.00, Downtown 1.15, Summit Pass **2.08**, Dusty Highway **2.09**, Garage 8.85, Stunt gate 10.08 s. The side portals are just over IRW-17's 2 s (planned 2.0); options for Adam: accept about 2.1 s as Tunable, or tighten the portal spacing from 28 to 26 (4-stud gaps between the frameless discs).
- Changes from the computed layout: `corridorMargin` 10 (Stunt gate to (-106, -36), food stands to (140, 76)); nameplate on the lintel at 11.45; no rails where two bridges overlap at the Avenue 6 and ring junction (the environment task should make that one junction bridge); routes to a door go round to its front.
- From the end plots the frameless 22-stud portal discs look small at about 250 studs; the portal sample (IRW-28) should test size and glow from Plot01.

## Task 2: environment and base-level dressing (intake 2026-10-21, not started)
Source: Adam's message "Car Hop Island Rework — Task 2: environment and base-level dressing" (2026-10-21, sent after "layout approved:"). Intake only; nothing below is built. Stops: **"Approved: island environment — continue dressing."**, a representative-plot review, then **"Approved: island park and base tracks."**

| ID | Requirement | Req/Opt | Source | Acceptance evidence | Status |
|---|---|---|---|---|---|
| IRW-30 | Start only once "Approved: island greybox" is recorded | Precondition | "First verify that Approved: island greybox is recorded" | quoted approval in the log | met: "Approved: island greybox." (Adam, 2026-10-21) |
| IRW-31 | Keep the approved layout dimensions, plot orientations, routes and upgrade reservations | Constraint | "Preserve approved layout dimensions" | LayoutChecks and WalkTests re-run after each stage | constraint |
| IRW-32 | From a plot entrance: detailed park, clear portal approaches, turquoise lake, waterfall, layered ridges and distinctive peaks; stadium-facing-stage kept; the park is never a maze and never hides destinations | Required | "The image I want players to see" | postcard and entrance captures; sightline check | built; postcard and both end plots captured, sightline check passes; for review |
| IRW-33 | Three depth zones: near (grassy rises, clustered pines, shrubs, rocks, soft edges), middle (foothills, connected ridges, forest, valleys), far (3 to 5 distinctive peaks with secondary ridges, lighter, lower contrast, haze) | Required | "Create three visual depth zones" | captures at three distances | built (near rises with clusters, foothills and forest, main range of five summits plus back range); for review |
| IRW-34 | Avoid identical peaks, uniform hills, pyramids on flat ground, uniform noise, a continuous cliff wall, straight snow caps, evenly scattered trees | Required | "Avoid" list | review against the list | built; known weak spots listed on the review page (regular waterfall buttress, banded rock texture) |
| IRW-35 | Peaks with asymmetric shoulders and connecting terrain; gullies follow downhill drainage; the tallest peak supports the lake and waterfall composition without spoiling other views | Required | "Give major peaks asymmetric shoulders" | close and distant captures | built (asymmetric shoulders, gullies by steepest descent, landmark behind the falls); for review |
| IRW-36 | References 1 and 3 for terrain forms, ridges, rock and grass by slope, irregular snow, turquoise water and layered distance; reference 2 for layered pine silhouettes, clustered trees, friendly foreground, bright sky and soft clouds; one coherent environment, not photographic detail | Required | "Interpret the references deliberately" | side-by-side comparison with the references | comparison on the review page; for review |
| IRW-37 | Reproducible terrain: island source structure, saved seed, deterministic, generator version, parameters and bounds recorded; bounded chunks with progress and memory checks; never clear all terrain; unrelated terrain kept; any global colour, water, atmosphere or lighting change recorded and scoped | Required | "Reproducible terrain and water" | rebuild diff, memory log, settings capture | built: seed 20261021, version island-env-1, recorded box, chunked writes, memory logged, ownership check, saved and restorable look ([[0014-island-environment-generation]]) |
| IRW-38 | Verify Studio APIs before use; choose the method by the visual result | Constraint | "implementation candidates, not proof" | API checks noted in the log | APIs checked in the docs and in Studio (log 2026-10-21); no noise recipes exist (Adam) |
| IRW-39 | Calm turquoise lake behind the portals; visible waterfall feeding it as a deliberate visual (falling sheets, foam, restrained mist); shallow park stream; stone and reed banks; bridges at every crossing; plausible flow, grading within the circulation plan | Required | "Create" list | captures, waterfall video | built (lake, falls with sheets, foam and mist, creek, pool, stream re-routed for right-angle crossings, outlet gorge, stone and reed banks, 8 bridges); for review |
| IRW-40 | Environment stop evidence: middle-plot postcard, both end plots, close and distant mountain comparisons with the references, two restrained atmosphere treatments, real-time greybox walk with the backdrop, waterfall motion, memory before, after and minimum, layout and reservation checks | Required | "First stop" | review page with videos | approved by Adam 2026-10-21 with changes (IRW-56 onward); Atmosphere A |
| IRW-41 | Park features: winding secondary paths, avenues and promenade, fences, shaped hedges, tiered fountain, lamp posts, benches, small knolls, wooden bridges and stream banks, food stands, signposts, gazebo, flowers, varied trees, bunting, a car-shaped topiary | Required (after IRW-40 approval) | "Then build the park" | stills per category | not started |
| IRW-42 | Four park-tree families (broad oak, blossom, airy birch, fruit or flowering) plus layered perimeter pines | Required | same | stills | not started |
| IRW-43 | Flower beds in five silhouettes (tulips, daisies, sunflowers, lavender, roses), in colour drifts and height layers, with room round paths and landmarks | Required | same | stills; path checks | not started |
| IRW-44 | Decorative food stands (hot dog cart, ice-cream stand, lemonade stand, popcorn cart) with no shop affordance | Required | same | stills; no prompts, prices or interactions | not started |
| IRW-45 | Construction details with a purpose (bridge rails and curved decks, fountain tiers, bench slats, lantern housings, bed borders, shaped signboards, awnings); a small reusable kit, not many tiny parts | Required | same | part counts by category | not started |
| IRW-46 | Propose meshes where they clearly help; uploads need Adam's approval; say honestly when a motif needs an asset that is not available | Constraint | same | proposal list | constraint |
| IRW-47 | One representative plot first, base tier only: plain oval at approved size, dark asphalt, yellow inner markings, dashed lane markings, thin white outer line, checkered line on the approved straight, striped grass infield, low outer wall, flags, pennant bunting, friendly fictional banners; clean markings through curves, no z-fighting | Required | "Finish only the base racetrack tier" | close captures; representative-plot stop | not started |
| IRW-48 | No bleachers, crowds, floodlights, gantries, pit buildings, screens, loops, elevated track, large signs, statues or fireworks; reservation volumes kept; small base decorations follow the removal and compatibility plan | Constraint | same | reservation checks | constraint |
| IRW-49 | Approved type and tokens (Fredoka One, `AGENTS.md`); any designed sign, banner or SurfaceGui content gets a Figma mock, spec and approval first ([[0012-figma-ui-workflow]]); physical sign structures may go ahead | Constraint | "Use the actual approved typography" | Figma spec approval | no Figma link in the vault; banners and signs blank until Adam sends it |
| IRW-50 | Replicate the approved plot design on all plots; incidental landscaping differs between neighbours | Required | "Replicate the approved design" | overview capture | not started |
| IRW-51 | Client presentation: flags, bunting, fountain, waterfall, limited particles; time-based, bounded, cleaned up, distance-based; reduced motion as approved (`GuiService.ReducedMotionEnabled` plus a preview-only override) | Required | "Animation, lighting, and performance" | videos; reduced-motion toggle test | not started |
| IRW-52 | Compare lighting options this Studio supports; bright readable daylight, restrained bloom and haze; the portals stay the brightest focus later | Required | same | two or more captures | not started |
| IRW-53 | Measure parts and instances by park, plot and effects; terrain time and memory; desktop frame time in named views; effects with all plots visible; the lapping stress test if it still runs. The phone 30 FPS target stays unverified without suitable hardware | Required | same | measurement table | not started |
| IRW-54 | Final review: real-time videos (park walk, waterfall and fountain, flags, track), stills of the full hub and each asset category, re-run reservation, path and sightline checks, views with the debug envelopes visible; ledger, log, manifest and design notes updated; missing assets and checks recorded | Required | "Final review for this task" | review page | not started |
| IRW-55 | No portal work, merge, publish or upload | Constraint | same | log | constraint |

## Task 2, step 2: environment and park revision (from Adam's approval of 2026-10-21, evening)
Source: Adam's message "Approved: island environment with the changes below. Approved: continue dressing." (Atmosphere A, Clear Alpine). Rows trace every requirement in that message; status is updated as work lands. One stop at the end; no plot track, portals, gameplay, economy, saving or other lanes' interfaces.

| ID | Requirement | Req/Opt | Source | Acceptance evidence | Status |
|---|---|---|---|---|---|
| IRW-56 | Atmosphere A (Clear Alpine) is the chosen look; decision 0014 accepted and recorded on the existing note | Required | "Use Atmosphere A ... accepts decision 0014" | 0014 status and approval quote | done: Atmosphere A in use; 0014 accepted, revision section added |
| IRW-57 | Original Blender meshes and authored images may be uploaded under peskaface without per-asset approval; verify the upload identity; no other account or group; no Toolbox, no generate_* tools; Blender MCP safe mode on; binary sources in Car-Hop-Art, recipes and manifests in the repo; stop Blender when idle; no animation publishing; audio proposal only | Constraint | section 1 | asset manifest with ids, owner and load checks | done: Studio user 2393473976 (peskaface) verified before upload; Creator "Me" in the importer; GetProductInfo reports peskaface for the meshes |
| IRW-58 | Record every uploaded mesh and image (revisions, failed and pending states); verify each final asset loads; no duplicate uploads of unchanged assets | Required | section 1 | manifest; load check per asset | done: assets/island/kit/manifest.md (15 images, 137 meshes, 1 model, the FBX attempts that uploaded nothing); every final asset loads (PreloadAsync, 137 of 137); one import, no duplicates |
| IRW-59 | Recoverable baseline before replacing: ledger, 0014, logs, branch, test place, lock; baseline cameras, counts, performance, memory; a recoverable copy; owned objects and terrain bounds identified | Required | section 2 | baseline record | done: 10 saved cameras and before captures, SceneStats counts, memory, terrain copy Lane3_EnvBaseline_Terrain in ServerStorage plus commit 3c252ba and seed |
| IRW-60 | Free system memory stays above 4 GB; bounded batches; stop heavy work safely if it crosses | Constraint | section 2 | memory log (minimum) | **breached once**: below 4 GB from 17:56 to 18:01 (minimum 3.23 GB, during a playtest); at or above 4.6 GB since 18:02; no crash or lost work |
| IRW-61 | Superseded trees and waterfall objects replaced in their owned containers, never doubled | Constraint | section 2 | SceneStats before and after | done: old pines, shrubs, rocks and reeds replaced in Flora; 0 unions left; old waterfall replaced in its Waterfall model |
| IRW-62 | ref5 gives structure only (roots, bent branching trunks, canopy tiers, umbrella crowns, slim trees, layered pines, fallen logs, rocks, bright flower groups), no studs or slabs; ref6 gives strand falls with gaps, layered foam and mist, dark faceted wet cliffs, clumpy faceted foliage, curved trunks, branches, shoreline plants, moving grass; the scene stays bright daytime with rich blue and white water and turquoise shallows | Required | section 3 | review page comparison | done: references inspected and used for structure only |
| IRW-63 | One connected water system: snowfield creek and side-gully stream, upper falls, shared ledge basin, segmented lower falls, lake plunge pool, lake current, park-stream outflow; descending channels with rock beds, wet edges and rapids; basins at impacts; visibly directional discharge; inside the approved footprint | Required | section 4 | channel elevation readback; captures | done (Stage 1): one connected system, channels descend, water above its bed; checked in Studio |
| IRW-64 | Upper plunge with a pronounced lip, short outward arc, dark wet cliff visible behind strands, breakup increasing toward impact, natural variation | Required | section 4 | close and plot captures; video | built; for review (close-up quality is a listed weak spot) |
| IRW-65 | Side horsetail hugging the rock into the same ledge basin | Required | section 4 | captures | built; for review |
| IRW-66 | Ledge basin churning and spilling into a lower fall split by rock into 2 to 4 unequal streams converging at the plunge pool; total cascade taller than before | Required | section 4 | captures; measured heights | built: three streams in front of the rock with open gaps (fixed 2026-10-21 evening); cascade 169.5 studs |
| IRW-67 | Stepped faceted cliff replacing the cone buttress: planes, unequal ledges, crevices, drainage channels, overhangs, a shallow grotto, dark wet rock near spray, lighter dry rock away, moss and ferns; no repeated banding near the falls | Required | section 4 | captures | partly: stepped cliff, ledges, grotto volume and wet rock built; the rock texture still reads uniform close up (weak spot) |
| IRW-68 | Layered beam water traced along each segment's real path (body, fast and slow strands, highlights, spray ribbons as fits the segment), authored seamless streak textures, varied phase, speed, width and repeat, one blue-to-white progression per full drop, 2 or 3 stray ribbons, depth readable from Plot01 and Plot06 | Required | section 5 | captures from Plot01, Plot03, Plot06, plaza; video | done: layered beams with 14 original textures; layers now stay on each fall's line |
| IRW-69 | Impact effects at the ledge basin and plunge pool (splash and droplets, turbulent centre, whitewater, irregular foam ring shaped to the landing, ripple rings, lacy foam breaking away, low drifting mist, rising cliff mist); foam carried along a fading current to the outflow; grotto drips; a faint viewpoint-aware mist rainbow | Required | section 6 | video; captures | built; motion checked in Play (rates by distance and reduced motion) |
| IRW-70 | Original soft-edged textures (streaks, foam, ripples, droplets, mist, rainbow, sparkle); time-based client presentation with Trove cleanup and distance scaling; reduced motion calms spray, drift and decoration but keeps flowing water | Required | section 6 | texture list; reduced-motion comparison video | done: tested in Play (reduced-motion override calms spray and decoration, beams keep flowing) |
| IRW-71 | Two or three Roblox-uploaded sounds proposed with links and ids, not inserted | Proposal | section 6 | review page | done: three Creator Store sounds proposed on the review page, not inserted |
| IRW-72 | Smooth faceted Blender trees: bent tapering trunk, 3 to 5 sunk root buttresses, 2 to 5 main branches, thinning secondaries, 6 to 15 uneven foliage clumps with openings; warm and cool variation through a verified colour workflow | Required | section 7 | catalogue; colour method note | done: kit_trees.py recipes; roots sunk and embedded |
| IRW-73 | Three distinct variants each of oak, tiered tree, umbrella tree, birch (with multi-trunk), blossom, willow, small fruit tree, layered blue-green pine; plus a young pine, three bush sizes, a berry bush and a flowering shrub | Required | section 7 | catalogue | done: 8 families x 3 variants plus sapling, three bushes, berry bush, flowering shrub |
| IRW-74 | Replace the verified old pine population (975 found: 346 slim, 314 medium, 315 broad) through the placement system, keeping spacing and corridors; habitat placement; dirt and litter patches and understory; roots embedded; reuse uploads; simple trunk collision and non-colliding foliage; subtle nearby sway off under reduced motion; unique and scene triangle counts reported | Required | section 7 | SceneStats; corridor checks; floating check | done: 975 old pines plus 236 other old parts replaced by 764 mesh trees, 134 bushes, 137 boulders, 48 reeds; 121 steep spots skipped |
| IRW-75 | Irregular lake inside the approved footprint: coves, a peninsula, varied banks, shelves, deep middle, sand and pebble shallows, dark deep bed, beach near the plaza, rocky falls shore, marsh cove, damp band; turquoise shallows and blue centre; calm water with flow only near the falls, foam route and outflow; park stream checked after water settings | Required | section 8 | captures; footprint check | done (Stage 1): irregular lake with shelves, beach, rocky shore and marsh |
| IRW-76 | Aquatic details by habitat: reeds, cattails, rushes, arrowhead, irises; notched lily pads in 3 sizes with white and pink flowers; duckweed in still corners; no pads in turbulence or the deep centre; wet-banded rocks, driftwood, decorative stepping stones off routes, drifting leaves and petals; a small dock and tied rowboat only outside protected space | Required | section 8 | captures; positions | done: 45 margin stands, 14 lily colonies, duckweed, wet rocks, driftwood, stepping stones, floating debris; dock and rowboat at plan (-124.6, -86.8) |
| IRW-77 | Ground vegetation: grass near selected path edges and the lake, six flower types in 8 to 12 flower clumps planted in colour drifts by height and light, ferns, clover, tall grass, mushrooms, mossy rocks, stumps, a hollow log, dirt under trees and worn path margins; verify the current terrain grass-decoration controls | Required | section 9 | catalogue; captures | done: 34 flower drifts, shore grass, ferns, clover, tall grass, mushrooms, mossy rocks, stumps, 3 hollow logs; no Terrain.Decoration in this Studio build |
| IRW-78 | Client-side decorative wildlife on a shared budget: ducks, a raccoon by a log, butterflies, dragonflies, frogs, fish, pollen and seed fluff, fireflies in shade only; bounded paths, distance culling, reduced motion, full cleanup; maximum active counts reported | Required | section 10 | video; counts | done: Wildlife.client.luau; budget 36 creatures and 8 emitters; worst spot asks 10 and 4; reduced motion and cleanup tested in Play |
| IRW-79 | Park dressing in the same visual language: food stands (decorative), benches, lamp posts, bridges, hedges, tiered fountain, car-shaped topiary and the other approved items; framing the falls and portals, never obstructing; sign content follows the Figma-first rule (physical objects built, mock and spec prepared for the final review) | Required | section 11 | captures; corridor checks | done: park dressing from the kit; 0 corridor obstacles; sign text waits for the Figma mock ([[island-signs]]) |
| IRW-80 | Final review page: matched before and after views from the saved cameras, the five videos, a species and asset catalogue, the upload table, the not-inserted sounds, measurements (parts, MeshParts, triangles, emitters and particles, creatures, memory, free memory minimum, frame time with conditions), full layout and walking checks, tunables, known weaknesses | Required | section 13 | review page | done: review page (see [[2026-10-21]]) |
| IRW-81 | Commits in coherent increments after checks; board, log, design record, ledger and manifest updated; approvals recorded, dressing pending final review; no merge or publish; lock released and idle tools stopped | Required | section 14 | git log; records | done: pushed in increments on feature/lane3-island-environment; board, log, ledger, manifest and 0014 updated; no merge or publish |

## Task 2, step 3: revision pass (from Adam, 2026-10-21 late evening)

> "Approved: the current island environment direction, subject to the revisions below. Approved: carry out this revision pass before starting the representative racetrack plot or building the portals." It does not approve the finished revisions, sign artwork, building relocation or visible quality reductions.

| ID | Requirement | Type | Source | Evidence | Status |
|---|---|---|---|---|---|
| IRW-82 | Studio lock, private place, local save before editing (not to Roblox, not committed); 4 GB memory floor; no publish or merge | Constraint | section 1 | log | done: saved to `Car-Hop-Art/CarHop-Island-Test-revision-baseline.rbxl` (Studio was opened from the cloud place, so a new file by Adam's choice); memory below 4 GB for 18 s at 22:08 while Adam's Roblox player was open, then above 5 GB |
| IRW-83 | Phone viewport baseline before building: emulator, portrait and landscape, overview, plaza, a plot entrance; same frame-time method; host-rendered, not real phone | Required | section 2 | measurements | done: iPhone 17 Pro, 749 × 381 and 401 × 777; 60 fps steady, 0 to 1 frames over 33.3 ms; phone performance unverified |
| IRW-84 | Avenue boost lanes: paired white chevrons, flush, controlled glow; brief bounded boost that does not stack, cleans up and uses the movement system; reduced motion stops the pulse | Required (visual); **boost blocked on a movement contract** | section 3 | captures; walks | visuals built; boost is a WalkTests preview only (1.5 × while on a strip and 0.5 s after); no movement system exists yet, contract proposed for Brian R |
| IRW-85 | Walks from all six entrances to fountain, portals, Garage, Stunt gate, boost on and off; Garage and Stunt gate worst 12 s and spread 2 s, or a relocation proposal | Required | section 3 | table | measured; targets **not met** by the lanes; relocation proposed, waits for Adam |
| IRW-86 | Waterfall blue-green and see-through mid-drop, white at the lip, edges, streaks, turbulence and impact | Required | section 4 | captures, video | done |
| IRW-87 | Rainbow discoverable from the plaza and lakeshore against darker rock, soft | Required | section 4 | captures | done (beside the lower falls, west side); small from the lakeshore |
| IRW-88 | Wet dark rock and selective moss by the falls and lakeside cliffs, broad tonal variation | Required | section 4 | captures | done (terrain deep layers) |
| IRW-89 | Plot06 falls view reopened; all six entrances checked | Required | section 5 | ray test | done: falls 100 % from Plots 1, 2, 5, 6; 97 % Plot04 (leaderboard), 81 % Plot03 (Stunt gate pillar, a greybox building) |
| IRW-90 | Raccoon readable: mask, ringed tail, round ears, hunched, silhouette; re-upload | Required | section 5 | sheet, capture | done |
| IRW-91 | Recover skipped steep trees within a bounded radius, keeping the grounding rule | Required | section 5 | counts | done: 169 skipped spots in this build (121 before), 48 recovered, 99 still too steep, 22 crowded |
| IRW-92 | FlowerMeadow camera on a real drift | Required | section 5 | capture | done |
| IRW-93 | Yellow ground lines: find the source; off by default, Edit-only, never in Play | Required | section 6 | captures; Play check | done: they were the planning overlay's viewing-corridor strips |
| IRW-94 | Fix branches through canopies in the recipes; re-export and re-upload only changed meshes | Required | section 7 | contact sheets | done (8 meshes) |
| IRW-95 | Stand headers: wordless pictures; Figma mocks; signs blank until approved | Required | section 8 | Figma | mocks drawn; approval pending |
| IRW-96 | Test the three sounds; manifest; listening | Required | section 9 | manifest | falls and birdsong in test; quack off (63 s asset); not listened to |
| IRW-97 | Keep assets Restricted; document grants | Required | section 10 | manifest | documented; **privacy state unverified** (Roblox default is Open Use) |
| IRW-98 | Asset 203785492 checked narrowly | Required | section 11 | log | external (Pop Close Sound by another user; no reference in the place or repo) |
| IRW-99 | Grand fountain inside a measured sightline envelope, layered water display, calm choreography, reduced motion, costs | Required | section 12 | envelope, captures, video, ray test | built; portals 100 % visible from all six entrances (solid geometry, ray test) |

### Proposed shared movement-modifier contract (for Brian R, Lane 1; not built, needs approval)
- One owner module, client side, `src/shared/Movement/SpeedModifiers` (or wherever Lane 1 places movement): `set(source: string, multiplier: number, seconds: number?)` and `clear(source: string)`. WalkSpeed = the character's base speed × the **largest** active multiplier (sources never stack), clamped to at most 1.5. Each source has one slot, so overlapping triggers refresh it instead of adding.
- It clears every source on respawn, on character removal and when a mode that owns movement (a collection run, an obstacle race, driving) takes over; those modes can also block island sources.
- The island lanes would call `set("IslandBoostLane", 1.5, 0.5)` each frame the player stands on a strip, and nothing else. No saved data, no economy, no server state (a walking speed boost on the hub needs no server authority beyond Roblox's own movement checks; to be confirmed by Lane 1).
- Until this exists, the island does not change any player's WalkSpeed.

### Garage and Stunt gate (measured, 2026-10-22)
Boost lanes on the six avenues (1.5 × while on a strip, 0.5 s linger; preview walkers): Garage worst 15.57 s, spread 8.17 s; Stunt gate worst 18.28 s, spread 8.13 s. Simulated lanes on the garden ring and both approaches too: Garage 12.78 s and 5.88 s; Stunt gate 16.92 s and 7.07 s. The targets (worst 12 s, spread 2 s) are **not met**; the spread is geometric (Task 1 analysis: within 2 s needs the destination within about 16 studs sideways and 45 along the axis of the fountain). **Relocation proposal waits for Adam** (see the review page).
