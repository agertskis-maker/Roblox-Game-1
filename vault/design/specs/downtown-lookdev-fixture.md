---
title: Downtown look-development comparison fixture (preview)
tags: [design, spec, downtown, lane3]
status: preview
date: 2026-10-22
---
# Downtown look-development comparison fixture (preview values, for Brian R to confirm)

Lane 1 (Brian R) owns roads, segments, lane geometry and the run camera. This is NOT segment
generation: it is one fixed test road used identically for all three studies. Values marked
PREVIEW are reversible choices made overnight; the outline gives "4 lanes wide (Tunable), one
direction", about 18 visible traffic cars, and a chase camera about 12 studs behind and 6 above,
tilted about 12° down (car-hop-outline-v2). Scale: the Puglet reference car is 12.47 x 5.66 x
4.71 studs (provisional 1 stud = 0.28 m). Studs and game metres are kept separate.

## Road (frame: +X right, the car drives toward -Z, ground y = 0)
- Length 360 studs, from z = 0 to z = -360.
  - Straight A: s 0 to 140.
  - Gentle curve: s 140 to 240, constant radius 300 studs bending right (about 19°).
  - Intersection: centred at s 265, a two-lane cross street 30 studs wide, crossing at 90°.
  - Straight B: s 290 to 360.
- Carriageway: 4 lanes x 12.5 studs = 50 studs (PREVIEW), one direction. White edge lines
  0.6 wide; dashed lane lines 0.5 wide, 10 on / 10 off.
- A stylized marked crossing (zebra, 6 bars of 2.5 x 10) just before the intersection (s 245).
- Curbs 0.6 high, 0.8 wide. Sidewalks 12 studs wide each side (top 0.6).
- Frontage line: 12 studs from the curb (the sidewalk's outer edge).

## Scenery depth bands (measured from the road edge)
- Frontage: 0 to 25 studs back. 2 to 4 storeys (a storey is 12 studs; shop ground floor 16).
  Most detail; quieted locally behind the car, the Hop target and hazards (lower contrast,
  saturation under about 60% within 30 studs of those).
- Midground: 60 to 140 studs back. Taller, simpler masses, fewer openings.
- Skyline: 300 to 900 studs back. Simplified silhouettes, hazed (Atmosphere), 12 to 40 triangles
  each.

## Hazards (non-functional previews; positions identical in all three studies)
- Construction group: lane 4 (right), s 100 to 125: orange/white barriers, 8 cones, one sign;
  the crane stands on a lot behind the right sidewalk (never over the carriageway).
- Pothole: lane 2, s 172 (2.5 x 3.5, darker rim, lighter broken edge so it reads as a hole).
- Oil slick: lane 3, s 205 (6 x 4, dark glossy with a faint rainbow sheen; distinct from shadow).

## Car and camera
- Car: the Puglet-sized proxy in lane 2 (x = -6.25), front toward -Z.
- Chase camera: 12 behind, 6 above the car's centre, looking at a point 20 ahead at 1.5 up
  (about 12° down), FOV 70 (vertical), speed 50 studs/s along the lane centre (7.2 s pass).
- Comparison frames (chase): s = 30, 115 (construction), 200 (oil), 262 (intersection).
- Pedestrian frames: right sidewalk, eye 5 studs up, at s 60 looking forward-left, and at
  s 250 looking at the landmark.
- Lighting: identical bright daytime for all three (ClockTime 13.5, Brightness 2.2, the same
  Atmosphere/ColorCorrection); optional mood frames are labelled extras.

## Landmarks (one per direction, never on the carriageway)
- A Sunny Toy City: donut bakery with a rooftop donut, right side, s about 150.
- B Bright Real City: corner movie theater with deep canopy and tall vertical sign, at the
  intersection's near-right corner.
- C Big Bright Metropolis: elevated train crossing over the road at s about 320 (clearance at
  least 40 studs), station element on the left; a decorative train passes every ~12 s.
