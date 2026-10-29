---
title: Dusty Highway redesign plan
tags: [design, world-plan, lane3]
status: approved by Adam on 2026-10-28 (answers under "Approval requested"); build in progress on feature/lane3-worlds-dusty-summit
date: 2026-10-26
---

# Dusty Highway redesign plan

**Planning only.** Nothing here is built, uploaded, imported or changed in Studio, Blender, Git or source. The existing Dusty Highway preview stays exactly as it is until Adam approves. No picture in this plan is a screenshot of a built redesign (none exists). The two diagrams are hand-written SVG sketches, captioned as concept diagrams:

- `vault/design/specs/world-plans-assets/dusty-layer-bands.svg` (the road-edge, near, mid and far bands)
- `vault/design/specs/world-plans-assets/dusty-cycle-strip.svg` (one cycle of five districts, illustrative landmarks, proposed density curve)

**How to read the labels.** MEASURED means a number read from a file or sampled from a still (source named). OBSERVED means I looked at a still or render. CONTRACT INPUT means a value that already exists in code or in the review documents. HYPOTHESIS means my design proposal, to be tested. UNKNOWN means nobody has supplied it (usually Brian R's run contract).

**Direction kept (Adam, binding).** The warm desert road-trip identity and the five districts stay: Cactus Flats, Diner Strip, Red Rock Arches, Canyon Bridge, Mirage Dunes. No name is changed anywhere in this plan; name refinements appear only under "Approval requested" as proposals.

## 1. Why Downtown succeeds (shared section)

Compared: `studio-edit/downtown-1-main-street-theater-pothole-s215.jpg` and `downtown-2-midtown-intersection-s2060.jpg`, the renders `downtown-blvd/B2-district-MS.png`, `B2-theater-before-120ahead.png` and `B2-theater-after-60ahead.png` (Blender, not Roblox pixels), plus `Sequencer.luau`, `Catalog.luau`, `City/README.md` and `vault/design/downtown-plan.md`.

1. **Three layers with different jobs.** Facades stand on a frontage line 50 studs from the centre line (half road 38 + 12 sidewalk). Taller middle blocks sit 60 to 140 studs beyond the road edge. Pale skyline blocks sit 300 to 900 out. In s215 you can name all three: awning shopfronts, stepped brick blocks, pale towers at the vanishing point.
2. **Facade scale.** Lots are 24, 36 or 48 wide and four to six storeys (ground 16 + 12 per storey), so the street is a room about as tall as the road is wide. Window and cornice rhythm is readable as large shapes at 250 studs.
3. **A beat of solid and breath.** No module repeats immediately on a side, no module faces itself across the road, and a courtyard or pocket park interrupts every 5 to 8 lots.
4. **Clear road.** Nothing stands inside the kerb except lamps every 48 studs and trees on a deliberate rhythm (every 2nd or 3rd slot). No tree or bus shelter sits within 40 studs before a hazard.
5. **The road reads by value.** MEASURED from pixel samples of s215: road luminance 0.37, sidewalk 0.80, a contrast ratio of 2.0:1, plus white lane lines.
6. **Landmarks you see twice.** One every 500 to 700 studs, beside the road, never at a hazard. The theater blade (raised to 88) is a silhouette first at 120 ahead, then a marquee at 60 ahead.
7. **Signs you can read.** Dark navy letters on pale boards at awning height ("DASHBOARD DAISIES" in s215); no name repeats inside 400 studs.
8. **A palette hierarchy.** Warm brick and ochre walls, cool grey road, small teal and maroon awning accents, blue sky. The road is the quietest large shape.
9. **Purposeful props.** Lamps, trees, one bus shelter per district, a cart, pigeons: each belongs to a kerb or a shopfront.
10. **Bounded motion.** Pigeons, flags on poles, cart steam, birds and a blimp, all pooled, off the carriageway and reduced-motion aware.
11. **Soft district joins.** 96-stud Transition segments plus a blend of 84 studs either side, so a join is two or three mixed lots, not a cut.
12. **A destination.** The avenue ends on a distant arch or tower (the B2 theater renders), so the eye has somewhere to go.

**What carries over to a desert (principles, not parts).** Keep the three layer jobs, but make them rock, plant and dune layers. Replace facade scale with sandstone mass scale and silhouette clarity. Replace the lot rhythm with authored mass-and-gap phrases. Replace the dark-road/light-sidewalk value split with a cream road between darker clay verges. Replace storefront signs and awnings with roadside signs, shade and forecourts. Replace pigeons and flags with hawks, tumbleweeds and restrained pennants. Replace blended lots with ground-colour and mass gradients at the joins. Do not just swap buildings for rocks.

## 2. Diagnosis of the existing Dusty preview

Compared (not stud-matched, see the note below): Dusty `studio-edit/dusty-1-cactus-flats-windmill-s150.jpg`, `dusty-4-diner-strip-s612.jpg`, `dusty-2-red-rock-arches-s1320.jpg`, `dusty-3-canyon-bridge-approach-s2250.jpg`, `dusty-5-canyon-bridge-exit-cactus-sign-s2440.jpg`, the Blender renders in `worlds/dusty/`, and the HUD-over-Dusty frame `stills/r2-keys-tier3-desert-full.jpg`. These are Studio Edit stills with the FIXTURE chase camera; the Blender renders are not Roblox pixels. The stills are 1920 x 767, about 2.5:1, wider than most real screens (UNKNOWN how a 16:9 or phone crop changes the composition).

| Candidate problem | Verdict | Evidence |
|---|---|---|
| Repeated single-height silhouettes | **Supported** (mid and far layers); partly (frontage) | `DustyHighway.luau`: each district lists only 2 to 3 mid meshes (Cactus Flats: `DH_Mid_Mesa_1`, `DH_Mid_Butte_1`) chosen by a station rotation (`massIndex`); `Sequencer.luau` places about one mid mass per 96 studs per side; the far layer is six unit meshes of 26 to 52 triangles (`catalogue.md`). s150 and s612 show the same stepped-stack profile on both sides and repeated pale pointed cones right of centre. Frontage heights are `low = 8, mid = 0` in Cactus Flats and Diner Strip: nothing but the windmill rises above about 17 studs. |
| Too much undifferentiated empty ground | **Supported** (for the ground itself) | Ground is 2,048-stud tiles of ONE colour (`Assembler.luau` `updateGround`, `ground = rgb(226,188,138)`). The right half of s150 is a flat plane to the horizon. Openness is wanted; the flatness is the issue. |
| Arbitrary prop scatter | **Supported, but it is metronomic, not random** | `Sequencer.luau` puts a pole every 48 studs per side and a furniture piece 24 studs after each (cactus, fence post, barrel, rock from a 4 to 5 entry bag). The left side of s150 shows evenly spaced poles and cacti and one lone barrel at the kerb. The pole is a lamp-headed pole on a city 48-stud beat. |
| Missing near-road frame | **Partly** | s150: the first ~100 studs either side is sidewalk only. s612 has bushes at left foreground. s1320 has strong near masses. It depends on the lot draw. |
| Weak landmarks | **Mixed** | Strong: the big cactus sign (s2440, a large silhouette against sky) and the bridge portals. Weaker: the windmill at s150 is a small lattice. In s612 I cannot tell which building is the diner. The arch in s1320 reads as a tilted ring on a stack, not clearly as an arch. |
| Abrupt district joins | **Cannot tell** in general; **supported** at the bridge ends | s612 sits inside a planned blend (572 to 740) and looks mixed. At s2440 the cliff wall ends in a square end block at the deck end; at s2250 the cliffs start as straight walls. |
| Insufficient far backdrop | **Partly** | s150 has pale far shapes at right, but the road-axis horizon is empty flat ground and haze. Far shapes are six coarse meshes. |
| Road edge too weak (extra finding) | **Supported, MEASURED** | Pixel samples: road (230,212,176), sidewalk (244,230,203), open ground (245,221,173), the last taken in s150 and s612. Road vs sidewalk 1.18:1; road vs open ground 1.09:1 (the ground is slightly LIGHTER than the road). Downtown is 2.0:1 (section 1). Single-point samples from JPEGs. The edge is carried almost only by the white line. |
| Sky not dusty and not distinct (extra) | **Supported, MEASURED** | Sky at the top of frame: Dusty (77,170,201), Downtown (87,184,217), Summit (86,179,223): the same saturated cyan-blue in all three Worlds. |
| Canyon reads as a trench, not a gorge (extra) | **Supported** | s2250 and the renders show cliff walls beside the deck and a thin sky slot. `Assembler.luau` says the floor under a bridge landmark is "still a flat strip, not a depth" (y -0.25). |
| Hazard orange sits near terrain orange (extra) | **Supported (palette)** | Hazard orange (240,120,30) has hue 26 and saturation 0.88. Rock tops `r_top` (232,168,112) and `r_4` (222,134,88) are hue 28 and 21, saturation 0.52 and 0.60. Hazard orange vs rock: 1.4:1 luminance. The sinkhole and sand drift are not orange at all (`hz_dark`, `hz_rim`, `hz_light`): the drift's pale mound vs the cream road is 1.5:1 in the palette, and the Blender Diner Strip render shows it as a faint tan patch. |
| Sightline rule does not protect Dusty (extra) | **Supported from code** | The "no tree or bus shelter near a hazard" rule only blocks the kinds `tree` and `busStop`; Dusty's furniture is cactus, rock, barrel and fence post, so it is not blocked. |
| HUD covers the top-centre sky (extra) | **Observed** | In `r2-keys-tier3-desert-full.jpg` the route line sits over the sky in the upper middle; a tall silhouette in the centre can be hidden. |

**Matched-view note.** The comparison above used Downtown s215 and s2060 against Dusty s150, s612, s1320, s2250 and s2440: same chase camera, same lane template, different stud positions. No stud-matched Downtown-vs-Dusty pair exists. The lead may capture one in Studio: Downtown and Dusty at s150, s600, s1300 and s2250, FIXTURE camera (12 behind, 6 up, look 20, FOV 70), lane 2, the same proxy car, once at 16:9 and once at a phone-landscape aspect.

## 3. Contract inputs, unknowns and matched assumptions

| Item | Value | Status and source |
|---|---|---|
| Lanes, width, shoulder | 4 lanes x 17 studs + 2 x 4 stud shoulders = 76 studs; half road 38 | CONTRACT INPUT (preview value, reversible), `Sequencer.luau`, `City/README.md` |
| Kerb, verge, frontage line | kerb 0.8, verge 12 studs, frontage line 50 from the centre | CONTRACT INPUT, same |
| Bands | frontage 0 to 25 from the road edge; mid masses near face 98 to 138 from the centre (size 36 to 72 x 28 to 40); skyline near face 338 to 818 (size 60 to 140 wide) | CONTRACT INPUT, `Sequencer.luau` mass loop, `downtown-plan.md` section 5 |
| Segments | Straight 96 / 192, curves radius 360 over 16 degrees, Transition 96, BridgeDeck 192 | CONTRACT INPUT, README |
| Route and districts | about 3,195 studs; fixture targets 656 / 584 / 680 / 576 / 664 (sum 3,160); realised table is `City.boundaries()` | CONTRACT INPUT; realised table not read |
| Landmark spacing | 300 to 440 studs (Dusty); 8 tier A landmarks | CONTRACT INPUT, `DustyHighway.luau` |
| Sign gap | no sign name twice within 400 studs | CONTRACT INPUT, `SIGN_GAP`, `Worlds.check` |
| Welcome span | "WELCOME TO DUSTY HIGHWAY" at each Cactus Flats start, clearance 26 | CONTRACT INPUT (preview) |
| Chase cameras | FIXTURE 12 behind, 6 up, look 20, FOV 70; HIGH 18, 10, 24, FOV 75 | CONTRACT INPUT, README |
| Speed | 70 studs/s in the chase rig; the real speed contract | fixture value; the real value is **UNKNOWN, Brian R's contract** |
| Car size | Puglet reference 12.47 x 5.66 x 4.71 studs | CONTRACT INPUT, `Cars.luau` |
| Studs to metres | 0.28, PROVISIONAL, never an identity | CONTRACT INPUT |
| Hop height and length, hazard clearance, scenery collision, kerb wall, streaming owner, ground ownership | none supplied | **UNKNOWN, Brian R (Lane 1)** |
| World and district ids in a shared catalogue | not defined yet | **UNKNOWN, Brian L (Lane 2)**; district names also appear in `WorldRoutes.luau`, `Icons2.luau`, `Store.luau` |

Matched scale assumptions used in every district below: chase camera behind and above the ridden car (FIXTURE), 70 studs/s as a labelled fixture (so 250 studs is about 3.6 s of approach and a landmark 50 studs off the road is abeam for about 1.5 s), Roblox FOV treated as the vertical field of view (HYPOTHESIS; the horizontal angle then depends on the screen), and lane 2.

## 4. World-wide visual grammar

**G1 The cream ribbon (road readability rule).** The road is meant to be the lightest large flat shape at ground level, framed by darker verges (today the open ground is as light as the road). Within 12 studs outside the edge line, ground must reach at least **1.8:1** luminance contrast against the road in a still (PROVISIONAL TARGET: 90% of Downtown's measured 2.0:1; today about 1.1 to 1.2). Method, a palette swap only: recolour the shared road piece's verge cells (`sidewalk_a`, `sidewalk_b`, `sidewalk_edge`) in `palette-DH.png` from pale cream to a packed-clay tone. A starting swatch near (168,120,86) should light up near (197,140,101), about 2.0:1 against today's rendered road. The cream kerb top stays as a crisp bright edge; the B2 road meshes do not change. In Mirage Dunes no pale sand lies within 12 studs of the edge (the "dune apron").

**G2 Palette roles** (existing values from `kit_world_palette.py`).

| Role | Existing | Proposed treatment |
|---|---|---|
| Road cream | asphalt (196,176,144), renders about (230,212,176) | keep |
| Terracotta terrain | `r_1` (150,66,46) to `r_top` (232,168,112) | keep; **scenery terracotta never above saturation 0.60**, so hazard orange (0.88) stays separate |
| Dusty-blue sky | default sky, measured (77,170,201) | target hue 200 to 208, saturation 0.30 to 0.45, start near (126,164,190), reached by Atmosphere colour, decay, offset and the colour grade, **not** an uploaded skybox; cannot verify without a Studio test |
| Aerial ramp | far swatches `sk_1..sk_4` pinkish (214,160,128) to (230,196,160) | shift toward dusty mauve-blue with distance: depth is baked colour, not fog |
| Selective turquoise | `w_accent_1` (54,176,170), water (70,176,190) | made things and water only, at most about 5% of a frame, one big turquoise disc in the whole World (the cactus sign); never on plants, rock or vehicles |
| Plant green | rendered cactus (60,171,94), a vivid UI green | toward sage and olive (saturation at most 0.45) |
| Coral, gold | (206,84,70), (240,196,70) | small accents; no yellow-and-black pairs near the road (the Keys lock ring is yellow and black) |
| Hazard | orange (240,120,30), white, black | reserved, see G8 |

**G3 Bold sandstone.** Rock reads as three big planes at 250 studs: lit top, body, deep shade. Silhouette classes: table mesa, stepped butte, fin, cap rock, saddle, ridge, arch wall. HYPOTHESIS rules (to test, chosen to fix the pale pointed cones in s150 and s612 and the "ring on a stack" in s1320): each mass at least 12 studs thick; a mid-range form's footprint at least half its height; apex width at least 15% of base width; a cap rock's neck at least 40% of the cap's width (balanced, not floating); no two consecutive masses on one side share a class; any 600-stud window shows at least four classes.

**G4 Plants in families.** *Sentinel* (tall columnar cactus with arms, two sizes), *Barrel* (low round), *Paddle* (flat pads), *Rosette* (spiky ground rosette), plus existing scrub. A cluster is one Sentinel hero, two or three satellites from other families, two to four rocks and a ground patch; a hero is not repeated within 150 studs. This replaces the thin `DH_Prop_Cactus` (4.96 x 9.72 x 1.39) as roadside furniture.

**G5 Lighting (economical golden hour).** One sun, warm key, cooler fill, no per-object lights, masses keep `CastShadow = false` so rock never stripes the cream road. Form comes from face angle and strata swatches. Existing (CONTRACT INPUT): ClockTime 14.2, Brightness 2.1, exposure -0.25, Atmosphere density 0.2, offset 0.22, haze 1.8. HYPOTHESIS: 14.2 is mid-afternoon, not golden hour; compare 14.2, 15.5 and 16.5 in matched stills and pick by eye (cannot verify without Studio).

**G6 Haze rule.** Atmosphere colour stays pale (saturation at most 0.25; today (238,214,178) is exactly 0.25, not orange). Haze softens far shapes only. **Haze-off test:** every near, mid and far form must still read with Atmosphere density at 0; a form that only works in haze is weak geometry and gets fixed, not fogged. Consider lowering haze from 1.8 toward 1.2 once the aerial ramp lands.

**G7 Repetition rules.** No prop family at constant spacing for more than three in a row. Desert utility poles are sparse: 120 to 220 studs, one side per stretch (Diner Strip 48 to 72; bridge lamps unchanged). Barrels, fence posts and rocks appear only inside groups. The existing no-immediate-repeat lot rule stays.

**G8 Hazard distinction.** Orange-and-white striping, cones, barriers, wind-socks and warning boards are hazard-only. Hazards sit on the carriageway; scenery never stands on it. Extend the existing 40-stud "no tree or shelter" clear zone to every scenery kind in Dusty, and keep scenery boulders at least 10 studs off the road edge with no scenery rock group within 60 studs before a rockslide hazard (scenery talus must never look like rubble on the road). No decorative "worksite" uses orange, white stripes or cones.

**G9 Keep Hop and Keys distinct.** The Hop reticle, dashed ring and chevrons and the Keys capture ring (pale cyan, with a yellow-and-black lock) are overlays on the road. Scenery avoids ring, arc, chevron and arrow shapes near the road (one reason the arch must not read as a ring), keeps turquoise greener than the capture cyan (I did not sample the exact cue colour, UNKNOWN), and has no glowing scenery at car height beside the corridor.

**G10 Designed groups.** Details come in named groups, never isolated props every few studs. A group is baked into one lot module (24, 36 or 48 wide) so the existing planner's bags, repeat rules, treatments and sign spacing still apply.

**Corridor protection.** Decorative motion never crosses the playable corridor (the 76-stud road plus a 4-stud margin) without gameplay approval. Existing life respects this: tumbleweeds at 44.8 studs, hawks at 100 studs lateral at the closest, the dust devil at 350 or more.

## 5. Density curve and variation across the cycle

`dusty-cycle-strip.svg` shows the shape. One cycle is about 3,160 studs; the route runs about one cycle, and the HUD loop repeats it. The existing planner uses one mid mass per about 96 studs per side everywhere (about 2.1 per 100 studs, both sides), a pole every 48 studs and a landmark every 300 to 440: a uniform density. The proposal makes density a curve (HYPOTHESIS targets, to be checked by counting in stills):

| District | Role in the cycle | Frontage occupied (share of length with a group) | Near groups per 100 studs (both sides) | Mid masses per 100 studs (both sides) | Far layers | Signs | Pole spacing |
|---|---|---|---|---|---|---|---|
| Cactus Flats | breathe in | 25 to 35% | 0.6 to 0.9 | 0.9 to 1.3 | 2 | none (welcome span, plaque, one wayfinding board) | 120 to 220, one side |
| Diner Strip | human peak | 60 to 75% inside a ~300-stud core, ~30% on the entry and exit | 1.6 to 2.2 in the core | 0.5 | 1 to 2 | 5 to 7 | 48 to 72 |
| Red Rock Arches | mass peak | 55 to 70% (rock) | 1.0 to 1.4 | 1.6 to 2.0 | 3 | 1 to 2 | 120 to 220 |
| Canyon Bridge | squeeze, then release | 70 to 80% on the approach (cliffs), 15% on the span | 0.8 | 1.0 | 3 | 2 to 3 | bridge lamps |
| Mirage Dunes | airy | 15 to 25% | 0.4 to 0.7 | 0.8 to 1.0 | 3, soft | 2 to 3 | none or sparse |

**Variation without incoherence.**
- Per-district sub-seeds: `hash(seed, cycle, district)` instead of one stream, so cycle 2 of Cactus Flats is not a replay of cycle 1. Same seed and cycle still give the same plan. This changes the Dusty plan digest only (Downtown untouched); existing seeds 2207, 11, 77, 101, 314 stay the test set. Seed 42 repeats a landmark in Dusty (R2-W1) and stays excluded.
- Palettes: each district has three (CF-sand, CF-adobe, CF-pale and so on); a cycle never repeats the previous cycle's palette in the same district.
- Landmark variation: the windmill alternates with the existing tier B `WaterTank` as the focal piece on cycle 2; the arch has two variants; ghost huts alternate with the tier B `GhostTown` block.
- Sign spacing: the 400-stud rule plus the proposed "each shop name once per cycle".
- District weighting: mass density comes from the table above, not one global rule.
- Module joins: natural forms rotate in 90-degree steps; faced modules (facades, signs, the arch opening) are never rotated, only mirrored by picking the L or R variant (the existing corner-lot rule).

| Shared element | Rule |
|---|---|
| Shared meshes | rock silhouette pack (used by all rock districts), plant families, marker set, ground patches, sign boards, fence runs |
| Safe orientation | natural forms: 0/90/180/270 yaw; faced items: mirror only |
| Palette swaps | three per district via swatch cells; no new textures |
| Landmark spacing | keep 300 to 440; the arch-to-bridge gap may exceed it because the bridge is 384 long (planner behaviour to confirm) |
| Joins | 96-stud Transition segments and an 84-stud blend either side; see each district's transition |

## 6. District plans

Every district uses the same fields. Layers are measured from the centre line: road-edge 38 to 50, near 50 to about 100, mid about 100 to 300, far 300 to 900.

### 6.1 Cactus Flats (fixture target 656 studs)

**First impression.** Wide, warm and open: the road runs across a sun-baked plain toward a far mesa wall, with one tall windmill as the first landmark. Sketch in words: the cream ribbon fills the lower half, clay verges frame it, three cactus clusters sit apart on the right, a windmill stands against open sky on the left, a long pale mesa lies on the horizon.

**Why the emptiness will not feel unfinished.** (1) The openness has edges: a near rock pair frames the entrance and a far mesa wall closes the view. (2) The ground has texture at three scales: tonal patches of 100 to 200 studs, wash lines and tracks of 30 to 60 studs, and scatter of 2 to 6 studs; every 100 x 100 stud square within 300 studs of the road holds at least one cue. (3) Scale anchors: small near plants against a tall far windmill. (4) Leading lines: the one-sided pole line, a pipe run on posts and a wheel track all point at the horizon. (5) Rhythm: clusters spaced irregularly with open stretches of 60 to 120 studs, about one part cluster to three parts open. This replaces the "flat plane" seen in s150, and the pole-and-cactus metronome.

**Entrance.** The welcome span (existing, static, 26 clearance) at about 60 studs in. Just ahead, two near rock outcrops at 70 to 110 studs lateral (a framing gate pair, 10 to 20 studs tall) so the plain opens after you pass them.

**Layers.**
- Road-edge: clay verge; a pole line on ONE side only (120 to 220 studs, irregular); reflector posts; a "dry wash" culvert marker group twice in the district.
- Near: four to six groups: cactus clusters (24 and 36 wide), scrub carpet, ranch rail fence, adobe shed, all kept 60 or more studs apart. Heights stay under 17 studs except heroes.
- Mid: two or three buttes per side, overlapping in depth; the windmill yard set back 40 to 60 studs behind the frontage line, isolated in open ground, with a water tank, stock trough and a pump house.
- Far: a long tabletop mesa wall on one horizon and a lower ridge on the other; an optional second windmill silhouette 400 to 500 studs out.

**Landmarks.** *Windmill* (WINDY ACRES WINDMILL, 26 x 67 x 31): approach silhouette from 300 studs, a lattice tower with a wheel against clear sky; place a gap in the far mesa wall behind it (sky-gap rule: a landmark is seen against sky or a lighter far layer, never against a same-value mass). Passing: tank and trough low at 40 studs abeam. Exit: it leaves the frame at the side within about 1.5 s. *Saguaro Garden* (49.7 x 31 x 24), about two thirds through: a tall hero with satellites, readable at 250 studs.

**Families.** The four plant families; adobe, corral, ranch gate and windmill-yard buildings; poles, rail fence runs, reflector posts and a plaque, with barrels only inside the yard group.

**Signage.** No shop signs (`signs = false`). The welcome span (existing); a sandstone district plaque ("CACTUS FLATS") at the start; one wayfinding board "SHADE AND SODA AHEAD" about 120 studs before the join. One plaque and one board per cycle; none within 80 studs of a hazard.

**Palette and lighting.** CF-sand, CF-adobe, CF-pale; turquoise only on the windmill vane and the ranch door; the far wall carries the aerial ramp.

**Ambient motion.** Tumbleweeds (4, shoulder only), hawks (3), the far dust devil. Optional: windmill wheel at 0.1 turns per second.

**Hazard visibility.** The most open district: hazard orange sits against clean cream. Keep near groups 60 studs clear of a hazard.

**Transition to Diner Strip.** Poles thicken from 120 to 220 down toward 48 to 72; the first ramada appears as a flat-topped silhouette at 250 studs; ground shifts from sand to forecourt clay; clusters thin. Shared lot types (cactus, scrub, adobe) already exist in both districts, so lots blend naturally.

**Reusable kit (DH_ prefix).** LM WindmillTower and CactusGarden; Lot Cactus24/36, Scrub24/36, Rocks36, Adobe24, Corral36, Dune36, Oasis24; Mid Mesa_1 and Butte_1; Sky_*; Prop Pole, FencePost, Rock.

**Optional upgrades.** Wheel rotation; a second far windmill; a pipe run to the horizon; wheel-track decals.

### 6.2 Diner Strip (584 studs)

**First impression.** A friendly pit stop: the open plain suddenly has a compact, lively roadside cluster, with shade, colour and a sign you can read from far away, then it opens again. Sketch in words: cream facades with turquoise and coral trim at three set-backs, a ramada, a tall sunburst pole sign against the sky, a dark mesa behind so light signs pop.

**Entrance.** 120 studs of teaser: a wayfinding board, a pole sign far ahead, poles tightening, forecourt-clay ground, the first ramada's flat silhouette.

**Layers.**
- Road-edge: clay verge, poles every 48 to 72 studs, a bus-shelter style shade stop (existing), markers.
- Near: six to eight low structures per side at three set-backs: flush (small stands), 8 (cafe, trading post with porch), 16 (diner, motel with forecourt), matching the planner's courtyard set-backs of 8, 12 and 16. Forecourts have a paved apron from the verge to the door. Heights of 10, 14, 18, 24 and 28 using parapets and false fronts. No continuous facade: any two adjacent structures leave a gap of 12 studs or more; frontage fill at most 75%.
- Mid: mesas behind the strip, kept lower and paler (at most 44 high, the existing `midHeight`); the tallest 140 or more studs back. Light sign faces sit against blue sky or a darker terracotta mass, never against cream ground.
- Far: a pale far ridge with a butte pair; the bigger rock arrives in the last 120 studs.

**Landmarks.** *Pit Stop Diner* (48 x 24 x 28): a long low body, a strong daytime pole sign (new, about 12 wide x 40 to 48 tall: a cream sunburst or diamond face with rust lettering and a turquoise ring), readable as colour and shape at 300 studs. Passing: the forecourt (ramada, three tables, planter barrels). *Old Pump Garage* (48 x 24 x 18, required): a flat canopy line with two pump totems, tyre and crate stacks. Approach reads as a horizontal canopy against the mesa.

**Groups.** Diner courtyard; pump island and garage; motel row (the existing 48-wide motel); fruit and soda stand; shade lot (ramada plus bus shelter); billboard back.

**Parked decorative silhouettes.** Not in v1. A car-shaped scenery piece could be mistaken for a capturable car, and vehicle looks belong to Brian L (decision 0015) under the original-vehicle rules (0010). Use a flatbed trailer, hay bales and tyre stacks instead; a car-shaped prop only with Brian L's approval.

**Signage.** The existing 12 names, once each per cycle, plus six proposed (section 7). Limits: at most three readable text signs in a 250-stud forward window; dark rust or deep turquoise lettering on cream; no board wider than 18 studs except the diner sign; none within 80 studs of a hazard; no safety-orange or striped awnings.

**Palette and lighting.** DS-cream, DS-turquoise, DS-sand; turquoise on at most one facade in three; shade undersides in warm `r_shadow`, not black.

**Ambient motion.** Pennants: at most two strings of eight, inside the forecourt, parallel to the road and at least 60 studs from the centre line, never over the road. Tumbleweeds continue.

**Hazard visibility.** The strip is the busiest near field: no structure within 60 studs of a hazard station, no pennant near it, no orange.

**Transition to Red Rock Arches.** The strip tapers over about 150 studs to a stand and a hut; ground clay turns terracotta; near rock outcrops appear; a fin pair stands at the boundary.

**Reusable kit (DH_ prefix).** LM Diner and PumpStation; Lot Motel48, Stand24, Garage36, Hut24, Rest36, Adobe24; Prop BusShelter, Pole, Barrel.

**Optional upgrades.** A trading-post porch group; a second pole sign in cycle 2.

### 6.3 Red Rock Arches (680 studs)

**First impression.** The road enters a gallery of giant layered sandstone, with one arch you cannot miss.

**Entrance.** A fin pair 40 to 60 studs inside the boundary; rock masses climb from 6 to 12 studs at the verge toward 60.

**Layers.**
- Road-edge: clay verge, deeper rust where rock meets it; talus wedges (a slope foot toward the road); marker cairns.
- Near: rock lots (existing mesa, pillar, hoodoo and ridge lots) with three or four strata bands, each 4 to 6 studs or thicker, never stacks of thin plates.
- Mid: tall masses (40 to 90) staggered so three layers overlap from the car.
- Far: a tabletop wall and a ridge, hazed by the aerial ramp.

**Landmark: the safe-clearance arch.** Today's `DH_LM_RockArch` (72 x 54 x 36, 330 triangles) reads as a ring. Proposed primary: a thick natural bridge, 90 to 110 wide, 56 to 70 tall, opening about 36 to 44 wide and 30 to 36 high, lintel at least 12 studs thick, legs at least 24 wide, on a stepped plinth, with a **flat squared lintel** so it reads as an arch at oblique angles. Placed on the right, 90 to 130 studs from the centre line, so no part comes within 50 studs of the road edge. Its opening plane is turned 25 to 35 degrees toward oncoming cars so the opening is face-on near 200 studs ahead (HYPOTHESIS; the planner needs a yaw option for landmarks, Lane 3 code). It sits against sky or a pale far layer. A flat clay viewpoint apron at the verge with a "LOOKOUT" board makes it purposeful. Approach: from 300 studs a heavy gate-like mass with a bright hole. Passing: the opening is seen at an angle from the right-front. Exit: it slips out at the right edge. Option B (OPTIONAL, needs Brian R): a drive-through gate arch with legs outside the verge and clearance of at least 60 studs (HYPOTHESIS: well above the 26-stud banner clearance; the hop apex and camera line are UNKNOWN). Not proposed until that contract exists.

**Rhythm (proposed phrases, district-relative, plus or minus 20%).**

| Studs in | Left | Right |
|---|---|---|
| 0 to 170 | hoodoo trio near | open, far butte visible |
| 170 to 340 | open, far wall visible | tall mesa pair with talus near |
| 340 to 510 | low rock lots, open | arch group (landmark) at 110 lateral |
| 510 to 680 | mid masses stagger | mid masses stagger, funnel toward the bridge |

**Families.** Rock silhouettes (seven classes), talus, marker cairns, sparse cactus clusters, one oasis (existing).

**Signage.** One "LOOKOUT" board and one "CANYON BRIDGE AHEAD" board near the end. No shop signs.

**Palette and lighting.** RA-rock, RA-deep, RA-pale; turquoise only at the oasis water; side-light brings out the strata.

**Ambient motion.** Hawks; tumbleweeds; no pennants.

**Hazard visibility.** The rockslide hazard is rocks plus an orange barrier. Scenery boulders stay at least 10 studs off the road edge, and no scenery rock group within 60 studs before the hazard (G8).

**Transition to Canyon Bridge.** Masses close in over 200 studs; cliffs rise from 6 to 40 studs; a rim fence and portal pair appear.

**Reusable kit (DH_ prefix).** LM RockArch; Lot Mesa36/48, Pillar24, Hoodoo24, Ridge24, Rocks36, Oasis36; Mid Mesa_1/2, Butte_2.

**Optional upgrades.** A second small arch so the plural in the district name is earned; the drive-through option.

### 6.4 Canyon Bridge (576 studs)

**First impression.** The land cracks open. You feel the drop and the sky, cross a proud truss bridge, and the far side reveals the next place.

**Entrance (rim approach, about 190 studs).** Terraced cliffs converge at the verge; a rim rail; a "CANYON BRIDGE AHEAD" board at 300 or more studs; the road visibly continues across.

**The gorge problem.** Today the floor under the deck is a flat strip at the ground level (the bridge sits in a trench with walls beside it). Option A (true gorge, recommended): a ground exception in the Assembler, so no ground tile lies under or beside the span, a deep floor 45 to 90 studs below (HYPOTHESIS, fixed by a Studio test), terraced walls dropping from the rim, and the road deck at ground height. Needs a ground exception (Lane 3 look-dev code) and Brian R's answer on the kerb and any boundary. Option B (cheaper fallback): keep the trench but add depth cues: wider sky slot, overhanging terraces, a far wall seen through the truss.

```
side view, Option A (not to scale)
rim ======\                                  /====== rim
   cliff   \  terraced wall      wall terraced/  cliff
 =======deck=============truss==============deck=======
            \____ 45 to 90 studs down ____/
              dry wash floor, far walls beyond
```

**Layers.**
- Road-edge: existing bridge parapet and bridge lamps (every 48 studs); on the rim, a verge and keeper's yard.
- Near: on the approach, rim rocks and a "bridge-keeper's yard" worksite (timber stack, trestle shelter, hut in neutral browns; no cones or orange).
- Mid: terraced gorge walls 100 to 250 studs off axis, three layers deep with a haze gradient.
- Far: a distant mesa wall and a sliver of sky: the horizon reveal.

**Landmark: the bridge** (`DH_LM_CanyonBridge384`, 162.8 x 46.5 x 384.9, 1,396 triangles). Approach (from 450 studs): a thin dark span line between rim abutments. Passing: truss portals at a steady rhythm. Exit: the last portal frames the Big Cactus Sign (a deliberate view corridor: nothing tall right of the road for 200 studs after the far abutment). "Believable supported crossing": stepped-stone abutments at both ends, pylon stacks visible past the rail, truss undersides. From the chase camera the supports are mostly hidden by the deck, so the HIGH camera and the far approach carry that read (the lead should check with HIGH).

**Safe scenery bridge versus a future gap hazard.** The scenery bridge is always an unbroken deck with continuous parapets and intact portals, no hazard colours, no ramps, no warning boards, named "CANYON BRIDGE". A gameplay gap (`car-hop-outline-v2.md`: "washed-out canyon bridge with ramp") would be a different object: broken truss, ramp lanes, orange-and-white warning boards, always in a marked test area and never in this route. Never within 120 studs of each other. No new collision or physics is proposed.

**Families and signage.** Cliff terraces, rim rocks, keeper's yard parts. Two boards at most ("CANYON BRIDGE AHEAD", a rim notice); no shop signs.

**Palette and lighting.** CB-cliff, CB-shadow, CB-sand; deep shade in the gorge uses `r_shadow` (112,50,42), never black; no turquoise except possibly water at the floor.

**Ambient motion.** Hawks circle over the gorge (they already fly at 110 high, 100 studs lateral). **Tumbleweeds skip bridge-deck segments** (current `WorldLife.step` has no bridge check, so with a real gorge they would roll on air beside the deck).

**Hazard visibility.** The existing planner keeps landmarks 60 studs from a hazard; I propose also no hazard on the deck and no decoration on it.

**Transition to Mirage Dunes.** The exit portal reveals the cactus sign; cliffs fall away in three steps over 150 studs; ground lightens from terracotta to pale sand.

**Reusable kit (DH_ prefix).** LM CanyonBridge384; Lot Cliff48/36, Ridge24, Mesa36; Mid Mesa_2, Butte_2; Prop Pole (bridge lamps); the shared B2 bridge deck and abutment.

**Optional upgrades.** A lookout shelf across the gorge.

### 6.5 Mirage Dunes (664 studs)

**First impression.** Soft, bright and airy: gold dunes, a giant cactus sign, the ghost of a roadside town, and the road a clear cream ribbon through a shimmering distance.

**Entrance.** The Big Cactus Sign 120 to 160 studs past the bridge end, right, in a clearing; ground lightens to dune gold; low dunes begin 60 or more studs from the road.

**Layers.**
- Road-edge: clay verge continues (this is what keeps the edge legible in bright sand); the dune apron rule: no pale sand within 12 studs of the edge; a low clay-sand fringe pieces only outside the shoulder.
- Near: dune lots set back 60 or more studs, the ghost-hut row, a fenced "dead well" group.
- Mid: soft dune ridges 20 to 50 high with long S-curve profiles; a hoodoo or butte accent.
- Far: pale wide ridges with the lightest aerial ramp: airy distance.

**Landmarks.** *Big Cactus Sign* (36 x 22 x 42): the district's memorable silhouette: a trunk, two arms at different heights and a round board, with a dark rust outline so it reads against pale sky; its disc is the one big turquoise piece in the World. Approach from 300 studs as a bold green shape. *Ghost Huts* (48 x 24 x 18, required): three or four leaning huts, empty window frames, sand banked on the back walls, a bent fence, a sign frame with no sign; dark brown against pale dune (a deliberate dark accent in pale land). Group: service remnants, a half-buried pump island, a collapsed canopy, the tier B `WaterTank` on legs (a story callback to the diner).

**Signage.** The cactus sign itself, one "LAST FILL" style board (PROPOSED name "LAST FILL, THEN SAND", which uses no distance or unit), and a nameless sign frame. Each name once per cycle.

**Palette and lighting.** MD-dune, MD-gold, MD-rose; the lightest sand in the World, so the clay verge is non-negotiable.

**Ambient motion.** Tumbleweeds, hawks, the dust devil drifting far right. Optional shimmer: one flat far-ground strip, at least 250 studs from the road, a pale blue-sand gradient with small alpha drift at no more than 0.4 Hz, within 900 studs only, off in reduced motion. No refraction shader.

**Hazard visibility.** The worst district: the sand drift's pale mound is the same colour as dunes and nearly the same as the cream road (1.5:1 in the palette). Proposed "hazard readability kit" (scenery previews; real hazards are Brian R's): a dark windward rim band on the drift, a hazard wind-sock marker (orange and white, hazard-only) and a warning board 120 or more studs ahead.

**Transition to Cactus Flats (the wrap).** Dunes flatten; the far mesa wall returns; the windmill silhouette appears about 300 studs before the boundary; the welcome span follows.

**Reusable kit (DH_ prefix).** LM CactusSign, GhostHuts, GhostTown and WaterTank (tier B); Lot Dune36/48, Hut24, Hoodoo24, Rocks36, Stand24; Mid Dune_1, Butte_1.

**Optional upgrades.** The shimmer strip; a mirage pool decal (static); a tattered flag on the sign frame.

## 7. Signs and ambient motion

**Original fictional signs.** Existing (CONTRACT INPUT, `DustyHighway.luau`): PIT STOP FUEL, SUNBURN SODA, DUSTY BUCKLE MOTEL, GAS AND GRIN, TUMBLEWEED TACOS, LIZARD LUNCH, COOL CACTUS ICE, HOWDY HUBCAPS, DESERT DONUT DEPOT, ROUTE SIX FRUIT, SAND-WICHES, BOOT SCOOT BURGERS. Landmark labels: WINDY ACRES WINDMILL, SAGUARO GARDEN, PIT STOP DINER, OLD PUMP GARAGE, SANDSTONE ARCH, CANYON BRIDGE, BIG CACTUS SIGN, GHOST HUTS, GHOST TOWN BLOCK, WATER TANK. PROPOSED additions (working names, not checked for existing marks; I did no search): SPUR AND SPARK GARAGE, COYOTE COFFEE CART, DUNE BUGGY BAKERY, PADDLE PEAR PIES, SUNDOWN SUNDAES, WAGON WHEEL WASH, LAST FILL THEN SAND, LOOKOUT, SHADE AND SODA AHEAD, CANYON BRIDGE AHEAD. Wayfinding uses no distance numbers (studs are not metres). The road marker is an original rounded sandstone plaque with a cactus glyph, not a highway shield.

**Repetition limits.** Each shop name once per cycle; never twice within 400 studs (existing check); at most three readable text signs in a 250-stud forward window; at most one sign per lot; none within 80 studs of a hazard station. Readability: shape and colour must read at 250 studs; text is legible by about 80 studs on a phone (assumption: a 390-pixel-high viewport, UNKNOWN; at FOV 70 that is about 3.5 pixels per stud at 80 studs, so a 3.5-stud cap height is about 12 pixels). Signs need a darker or sky backdrop.

| Motion | Count and place | Behaviour | Cleanup and culling |
|---|---|---|---|
| Tumbleweeds (existing) | 4, at 44.8 studs lateral, shoulder only | roll at about 8 to 12 studs per second, hop up to 1.4 | pooled; re-home 50 behind or 480 ahead; skip bridge segments (proposed); Trove |
| Hawks (existing) | 3, 100 studs lateral at the closest, 110 high | glide, flap 3 Hz | updated at 10 Hz; hidden beyond 900 |
| Dust devil (existing) | 1, 350 to 490 studs lateral | one emitter, rate 10 | on within 900 only; off in reduced motion |
| Pennants (proposed) | at most 2 strings of 8, Diner forecourt | sway about 6 degrees at 0.4 Hz | on within 350 studs only (like smoke); pooled |
| Windmill wheel (proposed, optional) | 1 visible | 0.1 turns per second | on within 600 studs |
| Shimmer (proposed, optional) | 1 strip, 250 or more studs out | alpha drift at most 0.4 Hz | within 900; off in reduced motion |

No decorative motion crosses the road; all reduce to rest with reduced motion (existing WorldLife behaviour). If any motion is judged by video (CLAUDE.md), a real-time video is required.

## 8. Buildable budget and approval boundary

### 8.1 Inventory

Existing kit: 53 meshes, 8,973 triangles (Haz 3 = 450, Sky 6 = 221, Lot 23 = 3,879, Prop 6 = 291, Mid 5 = 382, LM 10 = 3,750; `catalogue.md`), one 256 x 256 palette image, about 84 of 256 swatch cells used (my count). Complexity tiers are relative to those: **S** about like an existing prop or mass (20 to 90 triangles), **M** like a lot (100 to 500), **L** like a landmark (500 to 1,400). No triangle counts are invented for unbuilt pieces. Priority: P1 core, P2 should, P3 optional.

| ID | Item (working name) | Purpose | Visible size (studs) | Reuse per cycle | Tier | Material | Depends on | Pri |
|---|---|---|---|---|---|---|---|---|
| T1 | Far mesa walls x4 (new) | bold far silhouettes | 250-450 long, 50-110 tall | about 10 | S | `sk_*` ramp | palette | P1 |
| T2 | `DH_Sky_*` x6 (reuse) | far filler | 60-140 x 90-190 | about 16 | S | existing | none | P1 |
| T3 | Mid butte family x6 (new) | silhouette classes | 30-70 wide, 40-90 tall | 6-8 each | M | rock strata | palette | P1 |
| T4 | `DH_Mid_*` x5 (reuse) | mid fill | 24-42 x 26-85 | 6-8 | S | existing | none | P1 |
| T5 | Dune ridges x3 (new) | soft rhythm | 80-160 long, 10-26 tall | 6 | S/M | sand | none | P1 |
| T6 | Gorge wall terraces x3 (new) | Canyon depth | 96-192 long, 45-90 tall | 8 | M | rock | bridge decision | P1 |
| T7 | Ground patches x5 (new) | ground texture | 60-200 x 30-80, flat | 15-25 | S | `g_*` swatches | none | P1 |
| E1 | Verge clay palette (swap) | road edge | n/a | all | none | palette only | none | P1 |
| E2 | Marker set x5 (new) | plaque, reflector, cairn, culvert, wall | 2-10 | 3-5 per district | S | wood, stone | none | P1 |
| E3 | Rail fence run (new) | near framing | 24 long | 4 | S | wood | none | P2 |
| E4 | Sand fringe x3 | verge softening | 24-48 long | 6 | S | sand | G1b | P3 |
| A1 | Diner facades x3 (new) | cafe, trading post, tyre shed | 24-48 wide, 14-28 tall | 1-2 | M | cream + accent | palette | P1 |
| A2 | Shade structures x2 (new) | ramada, umbrella cluster | 12-24 wide | 4-6 | S | wood, canvas | none | P1 |
| A3 | Forecourt pieces x4 (new) | pump totem, pump canopy, table, planters | 3-24 | 6-10 | S | metal, wood | none | P1 |
| A4 | Ghost remnants x4 (new) | false front, shed, well, fence | 12-30 | 3-4 | M | weathered wood | none | P2 |
| A5 | Windmill yard x3 (new) | tank, pump house, pipe run | 8-96 | 2 | S | metal | none | P2 |
| A6 | Keeper's yard x2 (new) | worksite, no hazard language | 12-24 | 2 | S | timber | none | P2 |
| A7 | Existing lots, about 14 (reuse) | filler | 24-48 wide | per planner | M | existing | none | P1 |
| L1 | Arch B (new) | thick flat-lintel arch | 90-110 x 56-70 x 40-60 | 1 | L | rock | none | P1 |
| L2 | Bridge supports x3 (new) | pylon, abutment, undersides | 20 x 45-90 x 30 | 1 | L | stone, steel | gorge decision | P1 |
| L3 | Diner pole sign (new) | strong daytime sign | 12 x 40-48 | 1 | S | cream, rust | none | P1 |
| L4 | 8 tier A landmarks (reuse) | base | see section 3 | 1 each | M/L | existing | none | P1 |
| L5 | Tier B x2 (reuse) | cycle variants | 72 x 30, 24 x 48 | 1 | M/S | existing | catalogue change | P2 |
| F1 | Plant families x8 (new) | Sentinel, Barrel, Paddle, Rosette, two sizes | 4-30 tall | many | S | sage swatches | none | P1 |
| F2 | Cluster lots x4 (new) | baked groups | 24 and 36 wide | 6-10 | M | baked | F1 | P1 |
| S1 | Sign boards x5 (new) | pole, blade, plaque, wayfinding, hazard board | 3-18 | per sign rule | S | board swatches | sign text path | P1 |
| M1 | Windmill wheel (new) | rotation | 24 wide | 1 | S | metal | none | P3 |
| M2 | Pennant strings x2 (new) | restrained motion | 24-36 long | 2 | S | coral, turquoise | none | P3 |
| M3 | Shimmer strip (new) | optional | 200 x 40 flat | 1 | S | pale | none | P3 |

Counts: about 55 new meshes (P1 about 40), taking the total to about 108. For scale, the Downtown B2 kit has 180 objects and 56,751 triangles (R2-E2). Source art: recipes continue as text in `assets/downtown/kit/`; generated `.obj`, `.fbx` and `.blend` stay outside Git (the audit proposes a shared folder; I have not read it and claim nothing is stored there).

### 8.2 Phone budgets

| Metric | Baseline | PROVISIONAL TARGET (a hypothesis, not a measurement) |
|---|---|---|
| Visible scenery triangles | no per-frame measurement exists. Paper estimate from catalogue values: about 17,000 across the active window, excluding road meshes (my arithmetic, not a measurement) | at most 35,000, well under Downtown's proposed 60,000 (`downtown-plan.md` section 6) |
| Unique meshes | 53 | at most 110 |
| Textures and materials | 1 palette image, opaque | stay at 1, no new textures |
| Live parts, Studio Edit, 3,195-stud traversal | MEASURED 298 parts, 163 live items (20 proxy), p95 18.0 to 18.1 ms, 0 frames over 33 ms (R2-E3, a laptop) | at most 400 |
| Live parts, Play merge | MEASURED 259 parts, 23 proxy, p95 18.0 ms | at most 340; merged meshes per client stay at 8 |
| Transparent surfaces | kit opaque (palette alpha 255); one emitter | at most 2 emitters, rate at most 20 per second |
| Animated parts | 9 parts plus one emitter | at most 30 |
| Loading footprint | MEASURED: 8 frames over 33 ms, worst 160 ms across four World builds | no worse |
| Active window | 1 behind + 6 ahead; skyline 2 + 14 | unchanged |
| Headroom | outline expects about 18 visible traffic cars at 20 to 40 parts each (about 360 to 720 parts) | scenery parts must leave that room, so keep scenery near today's counts |

These are Studio-on-a-laptop numbers. They are NOT phone numbers and certify no 30 FPS floor.

### 8.3 Test plan for the future build

1. Comparable chase views: the five existing stud positions (s150, s612, s1320, s2250, s2440) plus Downtown pairs, FIXTURE and HIGH, 16:9 and a phone aspect.
2. A full cycle twice (about 6,400 studs) to see the wrap, with one World rebuild in the middle.
3. Hazard readability: each of the three hazards at five stations per district, camera 12 behind, 6 up; pass if the hazard keeps a 1.5:1 or better pixel contrast against both road and background (PROVISIONAL), and a warning board is visible 120 or more studs ahead.
4. Seams: `Worlds.check` (join error under 0.01, sign gap, landmark coverage), a corridor-clearance scan (nothing within 41.8 studs), the haze-off test, the G1 verge contrast (at least 1.8:1) and the G3 silhouette rules by counting.
5. Memory trend over three cycles (flat within about 20 MB, as measured before); frame samples with the window in front.
6. Reduced motion: every item at rest.
7. A physical-device follow-up on an actual phone. This plan certifies nothing about phones.

### 8.4 Phases after approval

P0 decisions (below). P1 "no-new-mesh pass": verge palette, aerial ramp, sky and light tests, ground colour, pole rhythm, density weights; nothing uploaded; compare stills. P2 natural kit (T family). P3 groups district by district: Cactus Flats, Diner Strip, Red Rock Arches, Mirage Dunes. P4 Canyon Bridge gorge (needs Brian R's answers). P5 ambient motion (real-time video required). P6 full-cycle test and review page. Each phase ends with Adam reviewing stills.

**Uploads.** Adam's standing approval covers uploading his own approved Blender meshes for these two Worlds under his account only after he approves these plans. The existing 53 Dusty meshes are not uploaded, and the previous Downtown import stopped at the importer clicks (R2-E2). Import the OBJ at 1 unit per stud, not the FBX (centimetres). Who clicks the importer is an open item.

**Unresolved Lane 1 and Lane 2 contracts.** Real speed; hop height and length; scenery collision and kerb wall; ground and terrain ownership (needed for the gorge); streaming ownership; hazard visuals and warning-sign contract; traffic density; district and World ids and display names in the shared catalogue (Lane 2, Brian L); scenery vehicles (Brian L).

## 9. Risks, tradeoffs and what is not proposed

**Risks.** The sandstone, gorge and arch changes are the largest geometry. A lower-contrast cream road is a deliberate trade for identity, which only the clay verge keeps readable. Orange terrain makes hazard distinction fragile; the rules above cost visual freedom. Phone legibility is not verified. A Canyon Bridge gorge cut touches ground tiles and an unknown kerb rule. Per-district sub-seeds change the Dusty plan digest.

**Not proposed.** No collision, physics, gap hazard, transport or ramp is implemented. No new hazard behaviour (hazard readability pieces are scenery previews). No upload now. No change to Downtown, Summit Pass, the HUD, the road meshes, audio or Lane 1 contracts. No parked car meshes. No skybox image. No name applied. No phone performance claim.

## Approval requested

1. **Direction.** Approve the grammar G1 to G10 and the five-district template as the Dusty look target, or amend.
2. **Names (PROPOSED only, none applied).** (a) Keep all five district names. (b) Optional: rename the landmark label SANDSTONE ARCH to GATEKEEPER ARCH if the arch becomes the gateway composition (no uniqueness search done). (c) Optional: add a small second arch so "Arches" is earned. A rename would touch `WorldRoutes.luau`, `Icons2.luau`, `Store.luau`, `DustyHighway.luau` and Lane 2's future catalogue.
3. **Canyon Bridge.** Option A (true gorge, needs a ground exception and Brian R) or Option B (trench with depth cues).
4. **Arch.** Approve the flanking thick arch; and say whether a drive-through option may be explored with Brian R.
5. **Verge palette swap** (clay verge, road meshes unchanged) and the **sky and light tests** in a private Studio test place.
6. **Planner changes** (Lane 3 look-dev code only): group lots, district density weights, irregular pole rhythm, per-district sub-seeds, landmark yaw, tumbleweeds skipping bridges.
7. **Scenery vehicles.** Confirm none in v1, or ask Brian L.
8. **Budgets.** Accept the provisional targets in 8.2 or set others.
9. **Motion.** Approve at most two pennant strings, an optional windmill wheel and an optional shimmer strip under the stated limits.
10. **Scope.** Which of the P1, P2 and P3 inventory rows to cut.
11. **Uploads.** Confirm the guided OBJ batches after approval and who drives the importer.

### Adam's answers, 2026-10-28 (recorded for the build; decision [[0026-world-plans-approved]])

Adam approved this plan on 2026-10-28 with the answers below (source: `vault/design/specs/worlds-dusty-summit-build.md`, section 1).

1. **Direction:** the visual grammar G1 to G10 and the five-district template are approved as written.
2. **Names:** keep all five district names. Do NOT rename Sandstone Arch. DO add the small second arch so "Red Rock Arches" earns its plural.
3. **Canyon Bridge:** Option A, the true gorge. Build it in the Lane 3 look-dev preview. Anything that changes gameplay (falling, collision, hop height or the road and ground contract) is Brian R's: a message goes to him through the vault and his code is not changed.
4. **Arch:** approve the thick arch beside the road. The drive-through version is written as a proposal for Brian R and is not built now.
5. **Verge palette swap** (clay verge, road meshes unchanged) and the **sky and light tests** in a private place: approved.
6. **Planner changes** (Lane 3 look-dev code only): all approved: grouped lots, district density weights, irregular pole rhythm, per-district sub-seeds, landmark yaw, tumbleweeds skipping bridges.
7. **Scenery vehicles:** none in v1. A later item that will use Brian L's finished cars.
8. **Budgets:** the provisional targets in 8.2 are accepted as ceilings to test against.
9. **Motion:** all three approved: at most two pennant strings, the windmill wheel and the shimmer strip, within the stated limits.
10. **Scope:** build P1 and P2. Build P3 only if the measured performance stays inside the 8.2 ceilings; list any P3 item that is skipped and why.
11. **Uploads:** guided OBJ batches, Adam clicks the importer. Creator is the Car Hop Roblox group ([[0024-roblox-group-ownership]]).

## Evidence list

All under `C:\Users\agert\Documents\Car-Hop-Art\review\hud-round2\` unless marked repo (`C:\Users\agert\Documents\Roblox-Game-1-hud\`).

**Viewed images.**
- `worlds\studio-edit\downtown-1-main-street-theater-pothole-s215.jpg`, `downtown-2-midtown-intersection-s2060.jpg`
- `worlds\studio-edit\dusty-1-cactus-flats-windmill-s150.jpg`, `dusty-2-red-rock-arches-s1320.jpg`, `dusty-3-canyon-bridge-approach-s2250.jpg`, `dusty-4-diner-strip-s612.jpg`, `dusty-5-canyon-bridge-exit-cactus-sign-s2440.jpg`
- `worlds\dusty\W-bridge-approach.png`, `W-bridge-on.png`, `W-district-CanyonBridge.png`, `W-district-CactusFlats.png`, `W-district-DinerStrip.png`, `W-district-RedRockArches.png`, `W-district-MirageDunes.png`, `W-gallery-landmarks.png`, `W-gallery-lots.png`, `W-gallery-props.png`
- `worlds\downtown-blvd\B2-district-MS.png`, `B2-theater-before-120ahead.png`, `B2-theater-after-60ahead.png`
- `stills\r2-keys-tier3-desert-full.jpg`, `r2-keys-tier3-desert-ring.jpg`, `r2-chase-dusty-edit-3195studs-contact.jpg`

**Read (repo).** `src\lookdev\Downtown\City\Worlds\DustyHighway.luau`, `Worlds\init.luau`, `Worlds\Make.luau`, `City\WorldLife.luau`, `City\README.md`; parts of `City\Sequencer.luau` (constants, spans, props, masses), `City\Assembler.luau` (lighting, ground, masses, bridge floor) and `City\Catalog.luau`; `assets\downtown\kit\kit_dusty.py` and `kit_world_palette.py` (headers, hazards, palette); `vault\design\downtown-plan.md` (headings and sections 3 to 8); `vault\design\specs\hud-round2.md` rows R2-D1, W1, W2, DH1, SP1, E2, E3; `vault\design\car-hop-outline-v2.md` (hazard table, World 2).
**Read (other).** `C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-worlds\catalogue.md`; `perf\PERF-ROUND2.md`.

**Could NOT verify.** No Roblox pixels of any redesign exist. No stud-matched Downtown-versus-Dusty pair exists. Pixel contrast values are single-point samples from JPEGs (s150, s612 and the Downtown stills); the open-ground sample is distant and may be hazed, so near ground could differ. I did not play the videos, run the planner or Luau, open Blender, or read `City.boundaries()`, so landmark stations are illustrative. I did not read `hud-rebuild-downtown-b.md`, `REVIEW-ROUND2.md` (searched only), or the audit that proposes the shared art folder. Real speed, hop height, phone aspect, the exact Hop and Keys cue colours, the kerb wall, and the importer behaviour are UNKNOWN. The kit's text-on-sign path is unread. Sign names are not checked against existing marks.
