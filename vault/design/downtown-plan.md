---
title: Downtown production plan (proposal)
tags: [design, downtown, plan, lane3]
status: proposal
date: 2026-10-22
---
# Downtown (World 1) production plan — proposal, not a selected direction

Written after the overnight look-development studies ([[hud-downtown-overnight]], fixture
[[downtown-lookdev-fixture]], research [[downtown-ref-environment]]). **Adam chooses the
direction**; this plan recommends one and keeps all three reviewable. Lane boundaries: Brian R
(Lane 1) owns roads, segments, lane geometry, hazards as gameplay, the run camera and streaming;
Brian L (Lane 2) owns cars and car data; Lane 3 owns the look. Numbers are proposals with their
assumptions stated. Evidence: `Car-Hop-Art/review/hud-downtown/` (Studio captures in
`downtown/studio/`, Blender renders in `downtown/blender/`, costs in `downtown/costs.md`).

## 1. Recommendation

**Recommended: B, Bright Real City, with A's warmth borrowed for signs and street furniture** (the independent Downtown reviewer reached the same ranking at moderate confidence, about 60% after the recheck, with A a close second).
Not selected — Adam decides.

| | A Sunny Toy City | B Bright Real City | C Big Bright Metropolis |
|---|---|---|---|
| Fit with the island (bright cartoon, rounded) | strongest match in palette and softness | good: warm brick and cream read friendly | weakest: cool glass, larger scale |
| Fit with sleek stylized parody cars | toy facades can make real-proportioned cars look oversized | best: real proportions match real-feeling cars | good scale, but the cars get lost against busy glass |
| Road readability at speed | good; pastels stay calm | good; strong cornices frame the road, warm walls contrast with grey road | busiest; glass grids add high-frequency detail near the road |
| Distinctness from later Worlds | could blur into the island | clearly "city" | clearly "big city", but Summit/Dusty contrast fine |
| Outline wording ("coral and mint block buildings… lots of 90-degree shapes") | colours match, shapes softer than stated | shapes match, colours warmer | shapes match, colours cooler |
| Build cost (unique meshes / unique triangles) | 87 / 20.5k | 94 / 22.4k | 86 / 15.6k |
| Placed triangles in the study | 84k | 119k (highest; trimmable) | 107k |
| Edit-mode chase pass, this PC (not a phone; see note) | 17.0 ms mean, 93 ms max | 16.9 ms mean, 88 ms max | 16.7 ms mean, 19 ms max |

Note on the frame times: all three sit at the 60 fps cap (about 16.7 ms), so they cannot rank the directions; A and B were sampled before their sign text was wired and without ambient motion, C with both, and the isolated maxima are single spikes. Treat them as "no obvious problem on this desktop", nothing more.

Why B: it reads as a believable street at chase-camera speed, its forms are rectilinear like
the outline asks, the warm palette sits well next to the island, and it scales honestly against
real-proportioned cars. Its triangle count is the highest of the three and must be trimmed
(fire escapes and 24-stud bases are over the 400-triangle module budget). A is the safest fit
with the island but risks a dollhouse scale against the cars; C is the most spectacular in
stills and the hardest to keep readable. Performance numbers are desktop Studio edit-mode
only; phone performance is unverified for all three.

## 2. Modular kit inventory and reuse

From `assets/downtown/kit/` (headless Blender recipes; JSON mesh data in the island format):
- Shared (all directions): road straight / curve / intersection, curb, sidewalk, lane markings,
  zebra crossing, lamp, planter, tree, hydrant, bench, bus stop, bin, bike rack, traffic light,
  street sign, barrier, cone, construction sign, crane, pothole, oil slick, skyline blocks
  (45 meshes).
- Per direction: base (shopfront), middle floors, tops / cornices / parapets, corners, roof
  props, signs and one landmark (A 54, B 61, C 55 meshes).
- Reuse: one 16 × 16 swatch layout with three palette PNGs, so one kit can be recoloured;
  road and hazard swatches identical in every palette.
- Effort (rough, one Lane 3 person with Claude, assuming the chosen direction and an agreed
  segment contract): trim and finish the chosen kit 2–3 days; upload + Studio integration on
  real segments 2 days; landmark polish and signs 1–2 days; streaming and performance pass on
  a mid-range phone 2–3 days. Dependencies: segment contract (Brian R), car bounds (Brian L),
  mesh uploads (Adam's click in the 3D Importer).

## 3. Segment needs (proposals for Brian R)

Straight, gentle curve (radius about 300 studs), intersection (cross street 30 wide), bridge,
construction (lane closure with barriers; crane on a lot, never over the carriageway), underpass
and overpass (C's elevated rail has at least 40 studs clearance). A drawbridge or a gap is a
gameplay mechanic: a proposal for Brian R only, not part of this plan.

## 4. Landmark pacing

One landmark per roughly 600–900 studs of road (proposal: about 8–12 s at a 70–110 stud/s run
speed), always beside the road, readable by silhouette before text, and never at a hazard. Studs
are the build unit; game metres are Lane 1's unit (provisional 1 stud = 0.28 m in the cars
README, not an identity).

## 5. Skyline, distance detail, streaming and collision

Three bands: frontage 0–25 studs from the road edge (full detail), midground 60–140 (simpler,
taller), skyline 300–900 (12–40 triangle blocks, hazed by Atmosphere). Scenery has no collision
except a continuous invisible kerb wall owned by the segment (Brian R decides). Streaming:
scenery grouped per segment so it streams with the segment (owner: Brian R). Rebuild workflow:
recipe → JSON → Studio builder (preview) → 3D Importer upload → ids in an AssetIds module.

## 6. Traffic budget

The outline gives about 18 visible traffic cars, 20 to 40 parts per car, a 30 fps phone target
with StreamingEnabled. The studies had **no traffic** (one proxy car only), so their numbers do
not include it. Reserve headroom: scenery in view should stay under about 60k triangles on
phones (proposal; B's busiest frame estimate is 90k and must come down).

## 7. City ambience, horns and music (proposals; no audio added)

Soft city bed (distant traffic hum, birds, a far tram bell), rare short friendly horn toots
(never alarm-like), food-cart sizzle near carts. Music direction from the outline: upbeat brass
and bouncy bass. Nothing was inserted or listened to overnight.

## 8. Contract questions

For Brian R: lane count and width (preview 4 × 12.5 studs), segment length and joins, scenery
bounds (preview: 12-stud sidewalks, frontage from 37.8 studs off the centre line), hazard
clearances (barrier set-back, crane position), run camera (preview 12 behind, 6 up, 12° down,
FOV 70), world scaling (studs to metres), and who owns streaming of scenery blocks.
For Brian L: canonical car bounds and data (id, name, rarity, variant, family, quirk, model
reference, bounding size) for the cards and a consistent scale against the Puglet reference.
