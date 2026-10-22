---
title: Task 4 research - hub and formal-park dressing
tags: [research, island, lane3, task4, park, hub]
status: research
---

# Task 4 research: hub and formal-park dressing

Research only. Every number below is a proposal, not an approved value.

**Scale.** A 5-stud avatar stands for an adult of about 1.75 m, so 1 stud is about 0.35 m (about 1.15 ft). *Inference:* real-world minimums are floors, and a third-person camera with child players needs more room. The default jump height of 7.2 studs is assumed; confirm it in the place. Hub sizes come from [[island-rework]]: avenues 16 wide, garden ring 8, plaza ring 28.

**Sources** (each read on 2026-10-22, the date that applies to every observation below):
- S1 Gennawey, "An urban designer looks at Main Street", TouringPlans, 2008-11-13: https://touringplans.com/blog/an-urban-designer-looks-at-main-street/
- S2 "Garden à la française": https://en.wikipedia.org/wiki/Garden_%C3%A0_la_fran%C3%A7aise ; Versailles aerial photo, 2014, CC BY-SA 3.0: https://commons.wikimedia.org/wiki/File:Vue_a%C3%A9rienne_du_domaine_de_Versailles_le_20_ao%C3%BBt_2014_par_ToucanWings_-_Creative_Commons_By_Sa_3.0_-_22.jpg ; Vaux engraving (public domain): https://commons.wikimedia.org/wiki/File:VauxC17engraving.jpg
- S3 GDCI Global Street Design Guide, lighting guidance (undated): https://globaldesigningcities.org/publication/global-street-design-guide/utilities-and-infrastructure/lighting-and-technology/lighting-design-guidance/
- S4 Seattle Streets Illustrated 3.3 Clearances (updated 2017-06-09), Figure L: https://streetsillustrated.seattle.gov/design-standards/clearances/
- S5 Singapore LTA "Guide for Wayfinding Signage", chapter C9: https://www.lta.gov.sg/content/dam/ltagov/industry_innovations/industry_matters/development_construction_resources/walking_cycling_plan/pdf/Guide%20for%20Wayfinding%20Signage.pdf
- S6 Disneyland Plaza Inn photo, 2015, CC BY-SA 2.0: https://commons.wikimedia.org/wiki/File:Plaza_Inn,_Sleeping_Beauty_Castle_from_Main_Street,_U.S.A.,_Disneyland,_Anaheim,_California.jpg

I viewed four images. They are kept outside the repo as reference only in `Car-Hop-Art/references/island-task4/hub/` (Disneyland, Versailles, Vaux, Seattle Figure L). Nothing from them is copied into the game.

## Observations (2026-10-22)

### 1. One axis, mirrored dressing (S2, image viewed)
- **Observed:** The main axis runs at right angles to the house. Cross alleys meet it, and fountains or sculpture mark the crossings. At Versailles, twin basins, paired parterres and the Latona fountain sit on the axis, which runs straight to the canal.
- **Inference:** Strict symmetry near the centre reads as order. It can loosen at the edges.
- **Apply:** Use the portals, the fountain and the Garage at (0, 162) as the axis, x = 0. Mirror the lamps, benches and beds across x = 0 in the plaza and along the first 40 studs of each avenue. If the Garage and the Stunt entrance flank an axis, mirror their approaches too.
- **Limit:** Versailles was designed to be seen from above. Check the symmetry at eye level.

### 2. A landmark you can see from everywhere (S1)
- **Observed:** A "wienie" is a distant orienting feature. The castle is visible from nearly everywhere, and the hub-and-spoke plan keeps returning guests to one familiar point, which cuts walking.
- **Apply:** Use height bands: landmarks (portal envelope 36, the planned fountain jet), then destinations (Garage 22, Stunt gate), then homes (plot gates), then furniture (12 or less). Nothing taller than 4 studs stands between the plaza and the portals.
- **Limit:** This is design commentary, not Imagineering documentation.

### 3. Lamp cadence (S3; S4 image viewed)
- **Observed:** Sidewalk poles are 4.5 to 6 m tall, spaced 2.5 to 3 times their height for even light. S4 keeps lights 5 ft from fixed objects and keeps trees 20 ft from streetlights.
- **Inference:** A 10 to 12-stud stylized lamp spaced at about 3 times its height gives a pitch of 30 to 36 studs.
- **Apply:** On the 16-wide avenues, place mirrored lamp pairs every 36 studs. On the garden ring, place one-sided lamps every 30. Put any trees at the same 36 pitch, offset 18 from the lamps (about 17 studs from each lamp). Keep each lamp at least 4 studs from benches, bins and signs. **Junction exception:** restart the cadence at every junction, put one lamp on each outer cap corner, and drop any lamp that falls within 8 studs of the cap.
- **Limit:** Real spacing is set for light levels. Here it sets rhythm, so tune it in captures.

### 4. Benches set back from the walking line (S4 image viewed)
- **Observed:** The clear walking zone is at least 6 ft. Benches sit at least 2 ft from that zone and at least 3 ft from the curb, in a furniture band.
- **Apply:** Use benches of about 6 x 2 studs, with the front 2 studs back from the path edge and 3 studs clear behind before any hedge or bed. Pair them, either facing across the avenue or side by side, and aim them at a view (fountain, river, portals).
- **Limit:** Check that no avatar can get wedged between a bench and a hedge.

### 5. Bins at thresholds (S6 image viewed; S4)
- **Observed:** One bin stands at the edge of the seating, beside the entry and the menu post, out of the walking line.
- **Apply:** Give each bench pair and each snack corner one bin, on the approach side, 1 to 2 studs outside the path edge and at least 3 studs from the bench. Keep bins off the plaza ring and out of junction caps.
- **Limit:** This is based on a single photo.

### 6. Signposts only at decision points (S5)
- **Observed:** Signs go at junctions where people pause, in consistent places, with a clear zone around them against clutter. Neighbouring decision points should look distinct. Repeat signs appear every 20 to 30 m only on long routes.
- **Apply:** Put one signpost at each junction, always on the approach-right corner, just before the cap. Show three destinations or fewer, with icons, and keep 4 studs clear around it. Skip repeaters on avenues shorter than about 80 studs (S5's 20 to 30 m is about 57 to 86 studs). Give each junction its own bed colour.
- **Limit:** S5 is a transit standard for adults. Children rely more on icons and landmarks.

### 7. Flower beds at nodes, simpler with distance (S2, image viewed)
- **Observed:** The richest parterres sit nearest the house and the axis nodes. They simplify into grass, then into groves, farther out.
- **Apply:** Put beds at the plaza edge, at junction corners, at avenue ends, and in mirrored strips along the first stretch of each avenue. Use plain grass or low hedge in between.
- **Limit:** Broderie is too fine for faceted low-poly. Use a few bold colour blocks instead.

### 8. Snack-corner composition (S6 image viewed; S4)
- **Observed:** Umbrella tables sit beside the entry, under an arched sign with globe lamps on posts. Hedges frame the court, and the approach is open. S4 requires at least 8 ft of clear height overhead.
- **Apply:**
  - Two stands about 90 degrees apart, with 3 to 4 picnic tables under umbrellas (canopy underside at least 7 studs).
  - String lights strung between 4 corner posts, with the lowest sag at 13 studs or more (5-stud avatar plus 7.2-stud jump) and CanCollide off.
  - A clear approach 10 studs wide, a hedge across the back, and the bin on the exit side.
- **Limit:** The photo shows a restaurant court, which is larger than a snack corner.

### 9. Junction paving as one footprint (S2, S4 images viewed)
- **Observed:** Each Versailles node is one continuous surface with the beds cut into it, and its edges follow the routes. S4 keeps 5 ft clear at corners and keeps tall obstructions 20 ft from crossings.
- **Apply:** Make each junction one paving piece: a round cap, or fillets with a radius of half the wider path's width (8 on an avenue). Run the border band continuously along the route instead of stopping it at each path end. Keep 5 studs clear beyond the fillet tangents, and nothing over 3 studs within about 17 studs of a corner.
- **Limit:** S4's rules are about traffic visibility. Here they serve sight lines.

### 10. Subtraction (S5, S2, S4)
- **Observed:** Signs are rationed to important points (S5). No trees are planted close to the house (S2). Clearances keep space empty on purpose (S4).
- **Apply:** Keep the plaza ring clear except at its outer edge, keep the axis clear, and leave the bridges undressed. Every prop should name its job (light, rest, sign, waste, frame); delete any that cannot.
- **Limit:** Too much emptiness can look unfinished. Judge it in eye-level captures.

## Not covered
These topics were not covered:
- How popular any hub or game currently is (no dated source was checked).
- Light levels.
- Where the Stunt entrance goes.
