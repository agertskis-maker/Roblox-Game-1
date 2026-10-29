---
title: Downtown environment references (city lookdev A/B/C)
tags: [research, downtown, world-1, environment, lookdev, lane-3]
status: research
date: 2026-10-22
---

# Downtown environment references

Research only. Nothing here is approved, and it picks none of directions A, B or C. All sources were captured on 2026-10-22. I opened and looked at each study image before writing about it. The images are kept outside the repo in `C:\Users\agert\Documents\Car-Hop-Art\references\hud-downtown\city\`.

## Sources

| # | Source | Provenance | Local file |
|---|---|---|---|
| S1 | [MK8D New York Minute start line](https://www.mariowiki.com/File:MK8D_New_York_Minute_Start_Line.jpg) | Nintendo screenshot (wiki: "Nintendo UK Twitter"), used on the wiki under fair use | `mk8d-new-york-minute-start-line.jpg` |
| S2 | [Kenney City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial) | Official Kenney page, CC0, v2.1 | `kenney-city-kit-commercial-sample.png`, `-preview.png` |
| S3 | [Synty POLYGON City Pack](https://syntystore.com/products/polygon-city-pack) | Official store page; "331 unique assets with x4 alternative texture colors" | `synty-polygon-city-screenshot-01.png`, `synty-polygon-city-layout-01.png` |
| S4 | [Burgess and Purkeypile, "Skyrim's Modular Approach to Level Design", GDC 2013](https://www.gamedeveloper.com/design/skyrim-s-modular-approach-to-level-design) | Talk text, Game Developer, 2013-05-01 | text only |
| S5 | [Mitchell, Francke and Eng, "Illustrative Rendering in Team Fortress 2", NPAR 2007](https://www.cs.princeton.edu/courses/archive/fall07/cos597B/papers/mitchell-team-fortress.pdf) | Valve paper (Princeton course copy) | text only |

## Project facts that constrain the city

Quotes are from `car-hop-outline-v2.md` unless another file is named.

- **Road:** "Roads are 4 lanes wide (**Tunable**), one direction." "all traffic goes the same direction as the player."
- **Segments:** "straight and gently curved prefab segments, streamed in ahead and recycled behind."
- **Scenery:** "Side scenery per World is low-detail and decorative … Nothing beside the road is interactive."
- **Traffic and performance:** "about 18 visible traffic cars, 20 to 40 parts per car, 30 fps target on a mid-range phone with StreamingEnabled".
- **Camera:** "about 12 studs behind and 6 above the ridden car, tilted roughly 12 degrees down". "Field of view is fixed. The camera must never clip into traffic."
- **Downtown look:** "a sunny cartoon city. Teal sky, warm grey asphalt, coral and mint block buildings, yellow crosswalk stripes, billboards with fictional ads. Lots of 90-degree shapes." **Tension:** this pulls against direction A's "softened facades"; the owner decides.
- **Hazards:** "cones and a crane arm, drawbridge gaps", "signposted ahead with an icon sign and a road marking".
- **Lighting:** "bright daytime … no expensive shadows on traffic". Music: "upbeat brass and bouncy bass" (suggests a bouncy, rhythmic facade cadence; inference).
- **Scale** (`cars/README.md`): "provisionally 1 stud = 0.28 m". The Puglet reference car is "12.47 x 5.66 x 4.71 studs with 4,992 triangles".

**Derived (inference):**
- **Real-world sizes in studs:** a 3.5 m lane is 12.5 studs, so 4 lanes are about 50 studs. One storey is about 12 studs. A shop ground floor is about 16 studs.
- **Camera frame:** I assumed Roblox's default 70° vertical field of view, so the top of the frame sits about 23° above horizontal. The highest point of a roadside facade still in frame is about 6 + 0.42 × (distance ahead) studs. That is 57 studs at 120 studs ahead and 90 studs at 200.
- **What that means:** the rooflines of 2–4 storey blocks first appear about 80–130 studs ahead.
- **Ownership:** lane width and segment length belong to Lane 1.

## Observations (inference unless quoted)

**O1. Three depth bands and a closed vista** (S1, S5)
- *Observed:* S1 has a foreground wall of shop glazing, midground towers covered in billboards, and a lit block closing the far end. S5 models its distant skybox "with less detail … prevents the skybox from generating high-frequency noise".
- *Apply:*
  - Bands: foreground 0–15 studs behind the kerb, midground 40–120, skyline 250 and beyond.
  - **A:** foreground 28–52 studs tall, midground 60–90.
  - **B:** foreground 40–64, midground 80–140.
  - **C:** podiums 16–32 studs, towers set back 30 or more studs and 150–300 tall, with the arena dome as the closing shape.
- *Limits:* an endless road cannot stay closed. Use the curved segments or a landmark every few segments instead.

**O2. Sign scale** (S1, S3)
- *Observed:* S1's billboards span about 2–3 storeys, start about one storey up, and wrap building corners. S3 mounts oversized 3D props (a bowling pin, a guitar) on its facades.
- *Apply:*
  - All directions: panels 16–24 studs wide, bottom edge at 16 studs or higher, at most one per 60 studs of frontage per side. Use pictograms rather than words, which also avoids localisation.
  - **A:** a roof donut 14–18 studs across.
  - **B:** a vertical theatre sign 30–40 × 6–8 studs, with a canopy that projects 10–12 studs.
  - **C:** banners on the podiums only.
- *Limits:* S1's signs are lit at night. In daylight, signs must carry through value and colour instead of glow.

**O3. Overhead framing** (S1, S3)
- *Observed:* a start gantry in S1. Traffic signals on mast arms and overhead wires in S3.
- *Apply:*
  - Only at Milestones and gaps, with at least 40 studs of clearance. That figure is an estimate; check it against Lane 1's hop apex plus the camera offset.
  - **C:** the train crossing at 45–55 studs, about once per 500 m.
  - **A:** bunting at 36 studs or higher.
  - **B:** fire escapes stay outside the kerb line.
- *Limits:* the rule that the camera must never clip rules out low overhangs.

**O4. Base, middle and top modules** (S2, S3)
- *Observed:* S2 buildings have a dark ground band, a pale body with inset windows, and a thick dark parapet. The only saturated parts are small green or orange awnings. S3 has red-and-white striped awnings.
- *Apply:*
  - Kit: base 16 studs, middle 12 studs per floor, cap 3–4 studs, plus corner pieces and storefronts on a 12-stud bay.
  - **A:** pastel bases, striped awnings, cream bodies.
  - **B:** cream stone base, brick middle, cornice cap, doors recessed 1.5–2 studs.
  - **C:** pale mullions over teal glass, with colour only on the podium.
- *Limits:* S2 is isometric. From the chase camera, the base band fills far more of the frame.

**O5. Roof props make the silhouette** (S2, S3)
- *Observed:* S2 has vents, stair huts and planters. The S3 prop sheet includes a wooden water tank, AC units and pipes.
- *Apply:*
  - **A:** rounded vents.
  - **B:** water tanks 8–10 studs tall on 6-stud legs, on no more than 1 roof in 3.
  - **C:** roof gardens with tree crowns 6–10 studs.
- *Limits:* borrow S3's silhouettes, not its detail.
**O6. A cheap skyline set** (S2, S5)
- *Observed:* the S2 preview shows separate white, windowless tower blocks.
- *Apply:*
  - 12–40 triangles per block, 15–25% lighter and 30–40% less saturated toward the sky colour, in at least two layers for parallax.
  - **A:** rounded tops.
  - **B:** stepped setbacks.
  - **C:** a dense teal cluster with a dome 120 or more studs across.
- *Limits:* one layer alone reads as a backdrop.
**O7. Quiet facades, saturation reserved for gameplay** (S5, S1)
- *Observed:* S5 keeps "muted colors dominating and small areas of saturation" and avoids geometry that adds "visual noise". S1 keeps the road low-contrast.
- *Apply:*
  - Only cars, the Hop ring, coins and hazards go above 60% HSV saturation.
  - Facades 0–15 studs from the kerb stay at 25–45% saturation, and accents cover no more than about 15% of a facade.
  - Asphalt sits at 40–50% value, with cars at least 20 value points away from it.
  - **A** is at the most risk because pastels sit close to car paint. Keep A's facades at 75–85% value and lower in saturation than any car.
  - **B:** brick at 35–45% saturation.
  - **C:** matte glass, so it never glitters behind traffic.
- *Limits:* S5 is about characters in a shooter, so applying it to cars is my analogy.

**O8. Rhythm, interruption and art fatigue** (S4, S3)
- *Observed:* S4 found players "reacted more strongly to repeated detail elements than to repeated architecture". S3 breaks its frontage with fire escapes and alleys.
- *Apply:*
  - Break the frontage every 3–5 bays (36–60 studs) with an 8–12-stud alley, a height change of 8 studs or more, or a 2–4-stud setback.
  - Place a landmark every 4–6 segments, and never repeat a hero piece within 1,000 m. Landmarks: **A** the bakery, **B** the theatre, **C** the dome or the train.
- *Limits:* S4 is a dungeon kit; analogy only.
**O9. Grid and pivot discipline** (S4)
- *Observed:* S4 calls kits "first and foremost … systems". It says footprints should be "multiples of each other", warns "avoid … a kit which tiles on all axes", and keeps pivots at ground centre because "changing pivots later can be a huge problem".
- *Apply:*
  - A 12-stud bay with a 4-stud sub-grid, and the pivot at the bottom centre of the kerb face.
  - Building depth: **A** 12–16 studs, **B** 16–24, **C** 24 or more.
  - Segments in multiples of 48 studs.
- *Limits:* segment length belongs to Lane 1.

**O10. Hazard readability against shadows** (S1, S3)
- *Observed:* coloured pools of light on S1's asphalt could be mistaken for an oil slick. The S3 props include orange cones and striped barriers.
- *Apply:*
  - **Oil slick:** a glossy near-black blob 8–10 studs across with a rainbow or teal sheen rim.
  - **Shadows:** cool grey-blue and soft, never with a rim.
  - **Pothole:** 4–6 studs across, with a cracked rim at least 15 value points lighter.
  - **Cones:** 3 studs tall, orange with a white band.
  - **Barriers:** 4 studs tall, with diagonal orange and white stripes.
  - No lane decals other than crosswalks and hazard markings.
  - **C** has the most tower shadow, so test it in Studio first.
- *Limits:* none of the sources covers hazard art; this is synthesis.

**O11. Scale cues** (S3, project facts)
- *Observed:* S3 places bollards, hydrants, mailboxes and bus stops next to its cars.
- *Apply (at 0.28 m per stud):* door 7.5–8 studs, hydrant 2.8, bollard 3.5, lamp 18–22, mailbox 4.5, pavement 10–14 wide. Keep furniture at least 2 studs outside the outer lane.
- *Limits:* an R15 avatar (about 5.5 studs) is child-sized at this scale. The team must decide whether doors are scaled to the avatar or to the car.

**O12. Palette swaps over shared UVs** (S2, S3, island kit)
- *Observed:* S3 sells "x4 alternative texture colors" of the same meshes. S2 uses flat colour. The island kit already uses one "256 x 256 swatch image (MeshPart.TextureID)" made of 16 × 16 swatches.
- *Apply:*
  - One Downtown swatch layout with three palette PNGs, one each for A, B and C.
  - Street furniture, hazards and skyline blocks are shared across directions.
  - Swatch groups: facade, accent, road, hazard (fixed across directions) and skyline haze.
- *Limits:* a palette swap cannot change form. B's cornices and C's mullions still need their own meshes.

## Exclusions

- **From S1:** no night setting, neon-led lighting, characters, logos, track layout, marquee shape or billboard art.
- **From S3:** no police, ambulance, emergency or military vehicles or signs, and no copies of its billboards or food props.
- **General:** no real brands, businesses or landmarks; no boardwalk or seaside; no reference images in the repo.

## What it means for building

- **Recipes:** follow the island kit's approach: headless Blender (`--background --factory-startup`, no add-ons, no MCP) running Python recipes kept in `assets/`, with outputs going to `Car-Hop-Art`. If Blender MCP is used, it runs with `BLENDER_MCP_SAFE_MODE=1`, and work stops if safe mode blocks a step. The Blender MCP server did not connect in this session.
- **Budgets (proposed; need performance testing):**
  - Traffic alone is about 18 × 4,992 ≈ 90k triangles. Keep visible scenery in the same range.
  - Facade module ≤ 400 triangles, landmark ≤ 3,000, skyline block ≤ 40, furniture item ≤ 150.
  - No more than 40 scenery MeshParts per segment side, all sharing one palette texture.
  - Shadows from the foreground band only.
- **Approvals:** uploads, `generate_*` tools and `insert_asset` need the owner's approval.
- **Fair comparison:** the same grid, segment, camera and hazard swatches for A, B and C. Only the facades, the landmark and the palette change between them.
