# Downtown kit B2: direction B "Bright Real City", production start

Direction B is selected (ledger `vault/design/specs/hud-rebuild-downtown-b.md`, D-01 to D-20).
This folder documents the **B2 kit**: reusable meshes built from headless-Blender recipes to the
"Downtown kit contract" in the ledger. It keeps B's look: warm brick over cream-stone shop bases,
recessed windows with stone sills and lintels, stepped cream cornices, plain canvas awnings,
restrained teal and navy accents, faceted low-poly forms and layered skylines. It drops the overnight
study's hazard-like orange awnings and its triangle-heavy modules.

Everything here is **preview art**. Nothing is uploaded or wired into gameplay. Segments,
streaming and the run camera belong to Lane 1 (Brian R). The Studio city grammar belongs to worker
DC. The import plan is in [MANIFEST.md](MANIFEST.md).

## Files

| What | Where |
|---|---|
| Recipes (in the repo) | `assets/downtown/kit/kit_b2_palette.py` (swatch layout, 5 district palettes), `kit_b2lib.py` (B2 builder, lot frame, cheap facade pieces, exporter), `kit_b2_road.py`, `kit_b2_lots.py`, `kit_b2_landmarks.py`, `kit_b2_street.py`, `kit_b2_build.py` (driver), `kit_b2_render.py` (review renders) |
| Build output (outside Git) | `C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2\`: `meshes/*.json`, `manifest.json`, `swatches.json`, `catalogue.md`, `palette-B2-<District>.png` x5, `downtown-kit-b2.fbx`, `downtown-kit-b2.obj` |
| Review renders (outside Git) | `C:\Users\agert\Documents\Car-Hop-Art\review\hud-rebuild\downtown\blender\` (see "Renders") |

These recipes reuse the overnight files unchanged: `kitlib.py` primitives, the
`kit_street`/`kit_hazards`/`kit_skyline` recipes (re-emitted on the B2 palette), and `render.py`
lighting. One additive change was made to `render.py`: a `__main__` guard so that it can be
imported. `kit_b.py` and `layout_b.py` are untouched.

### Rebuild

```
set PYTHONDONTWRITEBYTECODE=1
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python assets/downtown/kit/kit_b2_build.py -- --out C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python assets/downtown/kit/kit_b2_render.py -- --kit C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2 --old C:\Users\agert\Documents\Car-Hop-Art\downtown-kit --out C:\Users\agert\Documents\Car-Hop-Art\review\hud-rebuild\downtown\blender --samples 16
```

Before each launch, follow the Blender rules: only one `blender.exe` running, at least 5 GB of free
memory, and `Car-Hop-Art\BLENDER_LOCK.txt` present for the duration of the run. The build takes
about 10 s and the full render set about 2 min on this PC.

## Frames, pivots and sockets

- **Units** are studs. **Road frame**: +X right, travel toward −Z, ground y = 0.
- **Road pieces** (`B2_Road_*_L4W<w>`):
  - Pivot is the `start` socket: on the carriageway centre line at the piece start, asphalt top, facing −Z.
  - `end` socket: (0, 0, −L) on straights. On curves it is the arc end of R 360 / 16°: CurveR at (13.946, 0, −99.229) with yaw −16°, CurveL mirrored with yaw +16°.
  - Width is lanes 4 × `laneWidth` plus two 4-stud shoulders, then a 0.8 × 0.6 curb and a 12-stud sidewalk on each side. The frontage line therefore sits at half + 12.8 from the centre (W17: 50.8). Each piece is one mesh, from sidewalk edge to sidewalk edge.
  - **Seams**: every piece has the same cross-section at both ends. Lane dashes have a 16-stud period, scaled to a whole number per piece and centred in the period, so seams fall in gaps and markings run on across joins.
  - Variants: lane width 16, 17 (preview default) and 18 for every kind.
  - Extra sockets: `pier` on bridge decks; `cross_left`/`cross_right`, `signal_*` and `street_sign_*` on intersections.
- **Lots** (`B2_Lot_*` and the lot-type `B2_LM_*`):
  - The facade lies at z = 0 and faces −Z (`meta.facing = "-Z"`). The body runs to z = depth, and the footprint is x 0..W.
  - **Pivot** is the front corner on the lot's own left (min x), at ground level on the frontage line.
  - Placement: on the right of the road, yaw +90 with the pivot at the lot's start s (footprint s..s+W). On the left, yaw −90 with the pivot at s+W.
  - Mirroring is done only by mesh variant (`Corner24Mid_R`/`_L`), never by rotation.
  - Sockets: `front_left`, `front_right`, `back_left`, `roof_a`, `roof_b`, and where relevant `fascia_<n>` (with `max_width`), `blade_<n>`, `fire_escape`, `roof_tank`, `roof_vent`, `side_fascia`, `corner_sign`, `clock_tower`, `flag_*`, `lamp_*`, `brush_*`, `roller_*`, `bollard_*`, `tree_*`, `bench*` and `feature`.
  - Sockets are `{x, y, z, yaw}` in the mesh frame. Yaw is in degrees, using the `CFrame.Angles(0, rad(yaw), 0)` sign.
- **Townhouses** have their 8-stud front garden baked in (`meta.setback_baked`), so their pivot is still on the frontage line.
- **Signs**: pivot at the bottom centre of the back face, on the wall. Fascias face −Z. Blades project toward −Z with text faces on +X and −X, i.e. down the road both ways.
- **Spans** (bunting, welcome): pivot on the road centre line at ground level. They span along X.
- **Props and furniture**: pivot at the bottom centre. Hazards: pivot at their centre on the surface.
- Every mesh JSON carries `meta.sockets`, `meta.bounds`, `meta.lod` (`near` | `mid` | `far`), `meta.district`, `meta.pivot_offset` (bounds centre relative to the pivot), `meta.swatches_used`, and `meta.faces` where sign text goes. Face records use the overnight builder's format: `{name, centre, size, normal, text?}`, with `meta.default_text` alongside.

## District palettes

There is one swatch layout (`kit_b2_palette.py`, 222 swatches) and five images:
`palette-B2-MainStreet`, `-CityHall`, `-HarborBridge`, `-Midtown` and `-SkylinePark`.

- **Fixed swatches** look the same in every district: road, hazards, furniture, signs, landmarks and skyline. They are copied from the overnight B column.
- **District swatches** are a small set per district: walls ×4, stones ×2, trims, awnings ×3 plus an edge band and an underside, doors ×2, accents ×2, roof, paving, displays and midground walls.
- A lot mesh recolours per district by swapping its TextureID. Lots use colourways `a`–`d`, which remap generic names onto these swatches.

Character of each district:

- **Main Street**: warm red, ochre and brown brick, one painted teal, cream stone. Awnings teal, burgundy and navy.
- **City Hall**: cream stone, pale limestone, buff brick. Awnings navy, forest green and burgundy.
- **Harbor Bridge**: red-brown warehouse brick, weathered teal, grey stone. Awnings navy, teal and slate.
- **Midtown**: buff stone, pale terracotta, warm grey, blue-grey. Awnings navy, charcoal and teal.
- **Skyline Park**: cream, sand, soft brick, sage. Awnings forest green, teal and burgundy.

**No district awning is orange.** Orange/white appears only on construction hazards: the
barrier, cone, sign, site fence and construction lot.

## Catalogue summary

140 meshes, 37,591 triangles of unique geometry (generated table below):

| Family | Meshes | Triangles | Notes |
|---|---|---|---|
| Road | 33 | 10,566 | 11 kinds × lane widths 16/17/18: Straight96, Straight192, CurveL, CurveR, Intersection96, BridgeDeck96, BridgeDeck192, Abutment96 (Transition), TransitionVerge96, Park96, Park192 |
| Lot | 25 | 9,796 | Main Street 13 (Shop24Low a–d, Shop24Mid a–c, Shop36Mid a/b, Shop48Low a/c, Corner24Mid R/L), City Hall 3 (Civic36, Civic48, Plaza48), Harbor 2 (Warehouse48Low, Warehouse36Mid), Midtown 3 (Tall36Grid, Tall24Brick, Tall36Glass), Skyline Park 3 (Townhouse24 a/b, Park48), any 1 (Pocket24) |
| LM (landmarks) | 13 | 7,737 | Theater (MS), CityHall + ClockTower (CH), BridgeArch192 ×3 widths (HB), Fountain (SP), CarWash + Brush + Roller, ServiceCanopy, DonutBakery, DeliveryDepot (roadside, any district) |
| Mid | 8 | 674 | Block36 ×3, Tower40, Glass40, CivicDome (CH), Warehouse48 (HB), TreeClump (SP) |
| Sky | 11 | 546 | Slab/Stepped/Tower ×3 (unit-sized), Spire, Stadium (MT, real size) |
| Harbor | 9 | 566 | Water, Quay96, Pier ×3 widths, Bollard, Shed24, Crane (navy, not construction yellow), Containers |
| Street / Park / Prop | 20 | 2,662 | LampFormal (CH), the overnight furniture re-emitted, Hedge12, FlowerBed, FireEscape2/3, WaterTank, Vent, RoofAC |
| Sign | 7 | 594 | WHEEL GOOD PIZZA, LUG NUTS HARDWARE, HUBCAP BOOKS, PARK & BARK PETS (fascias); BRAKE-FAST DINER, HONK & ROLL MUSIC (blades); a corner blade |
| Span | 6 | 1,786 | WELCOME TO DOWNTOWN and bunting, ×3 widths (lowest point over the road 21.7 and 19.3; the rule is ≥ 18) |
| Haz | 8 | 2,664 | Pothole and Oil (new), ConstructionLot48 (new), Barrier, Cone, Sign, Crane, SiteFence (overnight geometry) |

### Triangle budgets, before → after (B modules changed)

| Overnight B module(s) | Before | B2 replacement | After |
|---|---|---|---|
| `B_Base24_*` + `B_Mid24_*` + `B_Top24_*` (a 2-storey 24 stack) | 766 + 236 + 210 = 1,212 | `B2_Lot_Shop24Low_*` (whole building) | 312–332 |
| the same stack with 2 mids (3 storeys) | 1,448 | `B2_Lot_Shop24Mid_*` | 402–450 |
| `B_CornerBase` + 2 × `B_CornerMid` + `B_CornerTop` (12-wide corner, 3 storeys) | 76 + 1,216 + 222 = 1,514 | `B2_Lot_Corner24Mid_R/L` (24 wide, two dressed faces, quoins) | 844 |
| `B_FireEscape2` / `B_FireEscape3` | 480 / 720 | `B2_Prop_FireEscape2` / `3` | 136 / 200 |
| `B_WaterTank` | 272 | `B2_Prop_WaterTank` | 126 |
| `B_Theater` + `B_TheaterBlade` | 1,286 + 228 = 1,514 | `B2_LM_Theater` (blade, marquee and crown in one mesh) | 993 |
| `Pothole` / `OilSlick` | 232 / 162 | `B2_Haz_Pothole` / `B2_Haz_Oil` | 168 / 168 |

Budget status against the 400-per-24-studs target:

- **Within budget**: Shop24Low, all Midtown talls (158–336), townhouses (276), Shop36Mid and Shop48Low (≤ 400 per 24 studs: 353–396 and 266–276).
- **Over budget**: Shop24Mid_c (450, from its arched top windows), Civic48 (510) and Corner24Mid (844 across two dressed faces, about 422 per 24 of facade). These are recorded as over budget; the quoin blocks are the first thing to trim.
- **Landmarks** are 222–1,231 each, all under the 2,500 cap.
- **Skyline**: blocks are 20–44 triangles. The stadium is 234, a deliberate far-landmark exception.
- **How the savings were made**: no back faces on trim, no sill undersides or lintel tops, no bottom reveals on upper windows, flat display silhouettes instead of boxed shelves, sweep cornices without brackets, and railings drawn as quads.

## Landmark notes (silhouette first)

- **REEL WHEELS theater (D-03)**: a 36-tall blade on the projecting central bay faces straight down the road both ways and rises above the parapet. A film-reel/wheel crown at y 66 makes the silhouette read before the text. A trapezoid marquee projects 10 studs; its angled faces meet approaching and departing traffic at about 35°. Above the bay are a stepped crown and a fly tower. Before/after renders are at 120 and 60 studs.
- **City Hall + clock tower**: a 72-wide stone front, a hexastyle portico on steps, and a pediment with a gilt emblem. The tower stands on the roof at the `clock_tower` socket. It has a visible rusticated base, a panelled shaft, four clock faces, an open belfry and a copper ogee spire to 88. Together they reach about 134 above the street.
- **Harbor Bridge**: twin tied steel arches outside the deck edge, with a crown 44 above the deck. Lateral bracing exists only where the arches are at least 30 high (lowest overhead member 33, above the 18 clearance). The deck pieces have open stone-post railings. Abutments drop to water at y −24, with a pier, quays, bollards, a navy dock crane, a shed and containers.
- **Car wash**: the tunnel runs parallel to the road inside its lot, with open arched ends and open windows. The brushes and roller are separate meshes at sockets (calm spin; stopped under Reduce Motion), outside the drivable lane.
- **Service canopy**: clear height 18 (≥ 16), four columns, fictional air/water/wash pumps with no fuel brand, a shop and a workshop bay. The lot is 48 × 36 (landmark depth).
- **Donut bakery**: a standing donut faces along the road, in a steel cradle bolted to a roof beam (posts, saddle, braces), so it is structurally attached.
- **Delivery depot** (replaces the fire station, AGENTS.md vehicle rule 5): three roll-up doors, a stone office, and a giant parcel on a roof cradle. Teal/navy accents, no emergency livery.
- **Fountain**: a 16-sided basin 24 across with two bowls, set on `B2_Lot_Park48.feature`. The water is opaque (no Transparency).
- **Stadium**: an oval 320 × 240 with light masts to 74. It belongs at 500–900 from the road.

## Renders (Blender EEVEE, 16 samples; stamped "not Roblox")

All under `Car-Hop-Art\review\hud-rebuild\downtown\blender\`:

- `gallery/sheet-<landmark>.png`: nine landmarks, each 2 × 2: approach (chase, 110 ahead), passing (30 ahead), rear (reverse chase), pedestrian or wide. The individual 800 × 450 frames are in `gallery/B2-<landmark>-<view>.png`.
- `sheet-theater-before-after.png`: overnight theater against B2, same street, same chase camera, at 120 and 60 ahead.
- `sheet-pothole-oil.png`: overnight against B2 pothole and oil, chase camera, 32 ahead.
- `sheet-awnings.png` and `B2-awnings-<D>.png`: per district, the three awning colourways plus a two-shop 48 lot, with swatch chips.
- `B2-sign-family.png`: the sign family. Text is Arial Black, a stand-in for the Studio SurfaceGui.
- `B2-district-<D>.png`: one 1280 × 720 chase frame per district.

The street in these renders is a private review arrangement in `kit_b2_render.py`. It is not a
production layout, segment generator or streaming plan.

## Known limitations and open points

- **Theater**: the after view is clearly better at 120 studs ahead (the blade and crown break the roofline), but at 60 the two read similarly. The marquee text is small, about 2.5-stud letters.
- **Oil**: the change at 32 studs is subtle. The edge band is calmer, but the pool size is similar.
- **Pothole**: it is darker and rimmed, but still small at 32 studs; motion was not tested.
- **Car wash**: the brushes are hard to see from the lane at chase height. Its silhouette is the weakest of the roadside set.
- **Midtown** still reads glass-blue in places. The review street keeps glass to one lot in six, but the grid lots' recessed glass and the midground towers add to it. DC should keep glass selective near the road.
- Lots are modelled from y = 0, and the 0.6 sidewalk covers their plinth bottom, as in the overnight kit.
- **Not done**:
  - no Studio check (DK never opens Studio);
  - no import into Roblox, no upload;
  - a chamfered corner variant of the theater (front placement only);
  - a construction cone redesign (the overnight cone is reused unchanged);
  - motion video.

## Module catalogue (generated by kit_b2_build.py: `catalogue.md`)

Size is the bounds extent in studs (x y z). LOD: near = frontage band, mid = midground (60-140), far = skyline (300-900).

| Name | Family | District | LOD | Tris | Size (x y z) | Sockets |
|---|---|---|---|---|---|---|
| `B2_Harbor_Bollard` | Harbor | HB | near | 54 | 2.2 x 2.5 x 2.2 | base |
| `B2_Harbor_Containers` | Harbor | HB | mid | 42 | 20 x 17.2 x 20 | base |
| `B2_Harbor_Crane` | Harbor | HB | mid | 226 | 10.89 x 35.51 x 33.03 | base |
| `B2_Harbor_Pier_L4W16` | Harbor | HB | near | 38 | 91.87 x 19 x 8 | top |
| `B2_Harbor_Pier_L4W17` | Harbor | HB | near | 38 | 95.3 x 19 x 8 | top |
| `B2_Harbor_Pier_L4W18` | Harbor | HB | near | 38 | 98.74 x 19 x 8 | top |
| `B2_Harbor_Quay96` | Harbor | HB | near | 16 | 96 x 24.75 x 12.4 | bollard_1, bollard_2, bollard_3, bollard_4, end, start |
| `B2_Harbor_Shed24` | Harbor | HB | mid | 18 | 25.2 x 15 x 17.2 | base |
| `B2_Harbor_Water` | Harbor | HB | mid | 96 | 960 x 0 x 192 | start |
| `B2_Haz_Barrier` | Haz | any | near | 210 | 6 x 4.38 x 2.2 | base |
| `B2_Haz_Cone` | Haz | any | near | 108 | 2 x 3 x 2 | base |
| `B2_Haz_ConstructionLot48` | Haz | any | near | 296 | 48 x 7.6 x 24 | cone_row, crane, gate |
| `B2_Haz_Crane` | Haz | any | near | 1460 | 10 x 55.04 x 46.04 | base |
| `B2_Haz_Oil` | Haz | any | near | 168 | 7.75 x 0 x 5.42 | centre |
| `B2_Haz_Pothole` | Haz | any | near | 168 | 5.51 x 0.25 x 7.29 | centre |
| `B2_Haz_Sign` | Haz | any | near | 94 | 4.8 x 7.02 x 2.4 | base |
| `B2_Haz_SiteFence` | Haz | any | near | 160 | 12.5 x 6.4 x 1.6 | base |
| `B2_LM_BridgeArch192_L4W16` | LM | HB | near | 996 | 104.8 x 49.48 x 203 | end, start |
| `B2_LM_BridgeArch192_L4W17` | LM | HB | near | 996 | 108.8 x 49.48 x 203 | end, start |
| `B2_LM_BridgeArch192_L4W18` | LM | HB | near | 996 | 112.8 x 49.48 x 203 | end, start |
| `B2_LM_CarWash` | LM | any | near | 222 | 49.2 x 25 x 25.49 | back_left, brush_1, brush_2, brush_3, brush_4, front_left, front_right, roller_1, roof_a, roof_b |
| `B2_LM_CarWashBrush` | LM | any | near | 120 | 5.2 x 11.3 x 5.7 | axis |
| `B2_LM_CarWashRoller` | LM | any | near | 112 | 11.8 x 5.2 x 5.2 | axis |
| `B2_LM_CityHall` | LM | CH | near | 1231 | 72.8 x 52 x 26.4 | back_left, clock_tower, flag_left, flag_right, front_left, front_right, lamp_left, lamp_right, roof_a, roof_b |
| `B2_LM_ClockTower` | LM | CH | near | 398 | 17 x 88 x 17 | base |
| `B2_LM_DeliveryDepot` | LM | any | near | 272 | 48 x 30.42 x 24.8 | back_left, bollard_1, bollard_2, bollard_3, front_left, front_right, roof_a, roof_b |
| `B2_LM_DonutBakery` | LM | any | near | 772 | 36.6 x 54 x 25.83 | back_left, front_left, front_right, roof_a, roof_b |
| `B2_LM_Fountain` | LM | SP | near | 233 | 24 x 14.2 x 24 | base |
| `B2_LM_ServiceCanopy` | LM | any | near | 396 | 48 x 20.6 x 36 | back_left, front_left, front_right, roof_a, roof_b |
| `B2_LM_Theater` | LM | MS | near | 993 | 36.6 x 66.08 x 34.7 | back_left, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Civic36Mid_a` | Lot | CH | near | 401 | 36.8 x 52.3 x 24.4 | back_left, flag, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Civic48Mid_b` | Lot | CH | near | 510 | 48.8 x 52.3 x 24.4 | back_left, flag, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Corner24Mid_L` | Lot | MS | near | 844 | 26.1 x 44.5 x 28.13 | back_left, corner_sign, fascia_1, front_left, front_right, roof_a, roof_b, side_fascia |
| `B2_Lot_Corner24Mid_R` | Lot | MS | near | 844 | 26.1 x 44.5 x 28.13 | back_left, corner_sign, fascia_1, front_left, front_right, roof_a, roof_b, side_fascia |
| `B2_Lot_Park48` | Lot | SP | near | 268 | 48 x 3.1 x 24 | back_left, bench_1, bench_2, feature, front_left, front_right, roof_a, roof_b, tree_1, tree_2 |
| `B2_Lot_Plaza48` | Lot | CH | near | 98 | 48 x 27.4 x 24 | back_left, feature, front_left, front_right, lamp_1, lamp_2, roof_a, roof_b, tree_1, tree_2 |
| `B2_Lot_Pocket24` | Lot | any | near | 58 | 24 x 12 x 24.05 | back_left, bench, front_left, front_right, roof_a, roof_b, tree_1, tree_2 |
| `B2_Lot_Shop24Low_a` | Lot | MS | near | 312 | 24.6 x 32.5 x 23.83 | back_left, blade_1, fascia_1, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop24Low_b` | Lot | MS | near | 312 | 24.6 x 32.5 x 23.83 | back_left, blade_1, fascia_1, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop24Low_c` | Lot | MS | near | 332 | 24.6 x 35.3 x 23.83 | back_left, blade_1, fascia_1, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop24Low_d` | Lot | MS | near | 332 | 24.6 x 35.3 x 23.83 | back_left, blade_1, fascia_1, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop24Mid_a` | Lot | MS | near | 402 | 24.6 x 44.5 x 23.83 | back_left, blade_1, fascia_1, fire_escape, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop24Mid_b` | Lot | MS | near | 410 | 24.6 x 47.7 x 23.83 | back_left, blade_1, fascia_1, fire_escape, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop24Mid_c` | Lot | MS | near | 450 | 24.6 x 44.5 x 23.83 | back_left, blade_1, fascia_1, fire_escape, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop36Mid_a` | Lot | MS | near | 530 | 36.6 x 47.7 x 23.83 | back_left, blade_1, fascia_1, fire_escape, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop36Mid_b` | Lot | MS | near | 594 | 36.6 x 44.5 x 23.83 | back_left, blade_1, fascia_1, fire_escape, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop48Low_a` | Lot | MS | near | 552 | 48.6 x 35.3 x 23.83 | back_left, blade_1, blade_2, fascia_1, fascia_2, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Shop48Low_c` | Lot | MS | near | 532 | 48.6 x 32.5 x 23.83 | back_left, blade_1, blade_2, fascia_1, fascia_2, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Tall24Brick_b` | Lot | MT | near | 158 | 24 x 67 x 28 | back_left, fascia_1, front_left, front_right, roof_a, roof_b, roof_tank, roof_vent |
| `B2_Lot_Tall36Glass_a` | Lot | MT | near | 336 | 36 x 91 x 28 | back_left, fascia_1, front_left, front_right, roof_a, roof_b, roof_tank, roof_vent |
| `B2_Lot_Tall36Grid_a` | Lot | MT | near | 198 | 36 x 79 x 28 | back_left, fascia_1, front_left, front_right, roof_a, roof_b, roof_tank, roof_vent |
| `B2_Lot_Townhouse24_a` | Lot | SP | near | 276 | 24.6 x 41.6 x 24 | back_left, front_left, front_right, garden_tree, roof_a, roof_b |
| `B2_Lot_Townhouse24_b` | Lot | SP | near | 276 | 24.6 x 41.6 x 24 | back_left, front_left, front_right, garden_tree, roof_a, roof_b |
| `B2_Lot_Warehouse36Mid_b` | Lot | HB | near | 417 | 36 x 54.2 x 24.8 | back_left, front_left, front_right, roof_a, roof_b |
| `B2_Lot_Warehouse48Low_a` | Lot | HB | near | 354 | 48 x 40.2 x 24.8 | back_left, front_left, front_right, roof_a, roof_b |
| `B2_Mid_Block36_1` | Mid | any | mid | 40 | 37 x 51 x 31 | base |
| `B2_Mid_Block36_2` | Mid | any | mid | 66 | 37 x 71.6 x 31 | base |
| `B2_Mid_Block36_3` | Mid | any | mid | 72 | 37 x 83.6 x 31 | base |
| `B2_Mid_CivicDome` | Mid | CH | mid | 130 | 44 x 53.6 x 36 | base |
| `B2_Mid_Glass40` | Mid | MT | mid | 104 | 40 x 137 x 40 | base |
| `B2_Mid_Tower40_4` | Mid | MT | mid | 90 | 41 x 127 x 35 | base |
| `B2_Mid_TreeClump` | Mid | SP | mid | 140 | 28.84 x 17.62 x 20.73 | base |
| `B2_Mid_Warehouse48` | Mid | HB | mid | 32 | 48 x 20 x 30 | base |
| `B2_Park_FlowerBed` | Park | SP,CH | near | 150 | 8 x 1.9 x 3 | base |
| `B2_Park_Hedge12` | Park | SP,CH | near | 20 | 12 x 3 x 2.6 | base |
| `B2_Prop_FireEscape2` | Prop | MS,MT | near | 136 | 10 x 21.4 x 3.01 | mount |
| `B2_Prop_FireEscape3` | Prop | MS,MT | near | 200 | 10 x 33.4 x 3.01 | mount |
| `B2_Prop_RoofAC` | Prop | MS,MT,HB | near | 144 | 4.6 x 4.89 x 3.4 | base |
| `B2_Prop_Vent` | Prop | MT,MS,HB | near | 42 | 3 x 6.2 x 3 | base |
| `B2_Prop_WaterTank` | Prop | MS,MT,HB | near | 126 | 7.2 x 15.2 x 7.2 | base |
| `B2_Road_Abutment96_L4W16` | Road | any | near | 338 | 97.7 x 28.6 x 96.45 | end, pier, start |
| `B2_Road_Abutment96_L4W17` | Road | any | near | 338 | 101.7 x 28.6 x 96.45 | end, pier, start |
| `B2_Road_Abutment96_L4W18` | Road | any | near | 338 | 105.7 x 28.6 x 96.45 | end, pier, start |
| `B2_Road_BridgeDeck192_L4W16` | Road | any | near | 802 | 97.7 x 11.6 x 192.9 | end, pier, start |
| `B2_Road_BridgeDeck192_L4W17` | Road | any | near | 802 | 101.7 x 11.6 x 192.9 | end, pier, start |
| `B2_Road_BridgeDeck192_L4W18` | Road | any | near | 802 | 105.7 x 11.6 x 192.9 | end, pier, start |
| `B2_Road_BridgeDeck96_L4W16` | Road | any | near | 478 | 97.7 x 11.6 x 96.9 | end, pier, start |
| `B2_Road_BridgeDeck96_L4W17` | Road | any | near | 478 | 101.7 x 11.6 x 96.9 | end, pier, start |
| `B2_Road_BridgeDeck96_L4W18` | Road | any | near | 478 | 105.7 x 11.6 x 96.9 | end, pier, start |
| `B2_Road_CurveL_L4W16` | Road | any | near | 428 | 109.66 x 1.6 x 112.68 | end, start |
| `B2_Road_CurveL_L4W17` | Road | any | near | 428 | 113.58 x 1.6 x 113.23 | end, start |
| `B2_Road_CurveL_L4W18` | Road | any | near | 428 | 117.5 x 1.6 x 113.78 | end, start |
| `B2_Road_CurveR_L4W16` | Road | any | near | 428 | 109.66 x 1.6 x 112.68 | end, start |
| `B2_Road_CurveR_L4W17` | Road | any | near | 428 | 113.58 x 1.6 x 113.23 | end, start |
| `B2_Road_CurveR_L4W18` | Road | any | near | 428 | 117.5 x 1.6 x 113.78 | end, start |
| `B2_Road_Intersection96_L4W16` | Road | any | near | 412 | 192 x 1.6 x 96 | cross_left, cross_right, end, signal_far_L, signal_far_R, signal_near_L, signal_near_R, start, street_sign_L, street_sign_R |
| `B2_Road_Intersection96_L4W17` | Road | any | near | 416 | 192 x 1.6 x 96 | cross_left, cross_right, end, signal_far_L, signal_far_R, signal_near_L, signal_near_R, start, street_sign_L, street_sign_R |
| `B2_Road_Intersection96_L4W18` | Road | any | near | 420 | 192 x 1.6 x 96 | cross_left, cross_right, end, signal_far_L, signal_far_R, signal_near_L, signal_near_R, start, street_sign_L, street_sign_R |
| `B2_Road_Park192_L4W16` | Road | any | near | 118 | 97.6 x 1.6 x 192 | end, start |
| `B2_Road_Park192_L4W17` | Road | any | near | 118 | 101.6 x 1.6 x 192 | end, start |
| `B2_Road_Park192_L4W18` | Road | any | near | 118 | 105.6 x 1.6 x 192 | end, start |
| `B2_Road_Park96_L4W16` | Road | any | near | 82 | 97.6 x 1.6 x 96 | end, start |
| `B2_Road_Park96_L4W17` | Road | any | near | 82 | 101.6 x 1.6 x 96 | end, start |
| `B2_Road_Park96_L4W18` | Road | any | near | 82 | 105.6 x 1.6 x 96 | end, start |
| `B2_Road_Straight192_L4W16` | Road | any | near | 206 | 97.6 x 1.6 x 192 | end, start |
| `B2_Road_Straight192_L4W17` | Road | any | near | 206 | 101.6 x 1.6 x 192 | end, start |
| `B2_Road_Straight192_L4W18` | Road | any | near | 206 | 105.6 x 1.6 x 192 | end, start |
| `B2_Road_Straight96_L4W16` | Road | any | near | 122 | 97.6 x 1.6 x 96 | end, start |
| `B2_Road_Straight96_L4W17` | Road | any | near | 122 | 101.6 x 1.6 x 96 | end, start |
| `B2_Road_Straight96_L4W18` | Road | any | near | 122 | 105.6 x 1.6 x 96 | end, start |
| `B2_Road_TransitionVerge96_L4W16` | Road | any | near | 104 | 97.6 x 1.6 x 96 | end, start |
| `B2_Road_TransitionVerge96_L4W17` | Road | any | near | 104 | 101.6 x 1.6 x 96 | end, start |
| `B2_Road_TransitionVerge96_L4W18` | Road | any | near | 104 | 105.6 x 1.6 x 96 | end, start |
| `B2_Sign_BrakeFastDiner` | Sign | MS,CH,HB,MT,SP | near | 108 | 0.76 x 13.6 x 5 | mount |
| `B2_Sign_CornerBlade` | Sign | MS | near | 40 | 0.34 x 2.56 x 3.83 | mount |
| `B2_Sign_HonkRollMusic` | Sign | MS,CH,HB,MT,SP | near | 100 | 0.76 x 14.2 x 5 | mount |
| `B2_Sign_HubcapBooks` | Sign | MS,CH,HB,MT,SP | near | 50 | 16 x 3.6 x 0.62 | mount |
| `B2_Sign_LugNutsHardware` | Sign | MS,CH,HB,MT,SP | near | 40 | 20 x 4.14 x 0.77 | mount |
| `B2_Sign_ParkBarkPets` | Sign | MS,CH,HB,MT,SP | near | 122 | 18 x 3.6 x 0.6 | mount |
| `B2_Sign_WheelGoodPizza` | Sign | MS,CH,HB,MT,SP | near | 134 | 18 x 4.4 x 0.69 | mount |
| `B2_Sky_Slab_1` | Sky | any | far | 20 | 1.04 x 1 x 1.04 | base |
| `B2_Sky_Slab_2` | Sky | any | far | 20 | 1.04 x 1 x 1.04 | base |
| `B2_Sky_Slab_3` | Sky | any | far | 20 | 1.04 x 1 x 1.04 | base |
| `B2_Sky_Spire` | Sky | MT,MS | far | 30 | 1 x 1 x 1 | base |
| `B2_Sky_Stadium` | Sky | MT | far | 234 | 332.8 x 73.5 x 249.6 | base |
| `B2_Sky_Stepped_1` | Sky | any | far | 30 | 1 x 1 x 1 | base |
| `B2_Sky_Stepped_2` | Sky | any | far | 30 | 1 x 1 x 1 | base |
| `B2_Sky_Stepped_3` | Sky | any | far | 30 | 1 x 1 x 1 | base |
| `B2_Sky_Tower_1` | Sky | any | far | 44 | 1 x 1 x 1 | base |
| `B2_Sky_Tower_2` | Sky | any | far | 44 | 1 x 1 x 1 | base |
| `B2_Sky_Tower_3` | Sky | any | far | 44 | 1 x 1 x 1 | base |
| `B2_Span_Bunting_L4W16` | Span | MS,SP | near | 234 | 77.2 x 26.85 x 1.2 | centre |
| `B2_Span_Bunting_L4W17` | Span | MS,SP | near | 236 | 81.2 x 26.85 x 1.2 | centre |
| `B2_Span_Bunting_L4W18` | Span | MS,SP | near | 236 | 85.2 x 26.85 x 1.2 | centre |
| `B2_Span_Welcome_L4W16` | Span | MS | near | 360 | 82.8 x 32.3 x 4 | centre |
| `B2_Span_Welcome_L4W17` | Span | MS | near | 360 | 86.8 x 32.3 x 4 | centre |
| `B2_Span_Welcome_L4W18` | Span | MS | near | 360 | 90.8 x 32.3 x 4 | centre |
| `B2_Street_Bench` | Street | any | near | 180 | 6 x 3.15 x 1.94 | base |
| `B2_Street_BikeRack` | Street | any | near | 216 | 7.2 x 3.02 x 2.7 | base |
| `B2_Street_Bin` | Street | any | near | 56 | 2.4 x 3.35 x 2.4 | base |
| `B2_Street_Bollard` | Street | any | near | 66 | 0.94 x 3.5 x 0.94 | base |
| `B2_Street_BusStop` | Street | any | near | 196 | 15.2 x 10.2 x 5.2 | base |
| `B2_Street_Hydrant` | Street | any | near | 164 | 1.7 x 2.8 x 1.6 | base |
| `B2_Street_Lamp` | Street | any | near | 204 | 2.4 x 19.85 x 6.15 | base |
| `B2_Street_LampFormal` | Street | CH | near | 188 | 7.9 x 17.35 x 2 | base |
| `B2_Street_LampLens` | Street | any | near | 28 | 2.2 x 0.5 x 2.2 | base |
| `B2_Street_Planter` | Street | any | near | 150 | 5.2 x 5.4 x 5.2 | base |
| `B2_Street_StreetSign` | Street | any | near | 56 | 5.6 x 12.05 x 5.6 | base |
| `B2_Street_TrafficLight` | Street | any | near | 220 | 5 x 15 x 2.35 | base |
| `B2_Street_Tree` | Street | any | near | 120 | 8.59 x 15.08 x 8.51 | base |
