---
title: Dusty Highway and Summit Pass build - requirement ledger
tags:
  - design
  - worlds
  - lane3
  - ledger
status: in progress (started 2026-10-28; status column is updated as work lands)
---

# Requirement ledger: Dusty Highway and Summit Pass build

Source of every row: Adam's brief [[worlds-dusty-summit-build]] (section 1 answers, 2026-10-28), the plans [[world-plan-dusty-highway]] and [[world-plan-summit-pass]], decision [[0026-world-plans-approved]]. Kit status (2026-10-28 23:22): both V2 kits are built from the Blender recipes (Dusty 94 meshes / 19,508 triangles and Summit 125 meshes / 35,792 triangles referenced by the data, within the 110 and about-130 ceilings), authored by two Sonnet workers (each reported claude-sonnet-5-5) and reviewed by the lead on gallery sheets; the planner code passes Selene, StyLua and the Rojo build. Nothing has run in Studio yet (the Studio lock is held by the Speedway window). Status words: **planned**, **code written** (Selene and StyLua pass, not yet run in Studio), **built and checked in Studio**, **blocked**, **not done**. "Evidence" names the check that will prove it; nothing is marked built until that evidence exists.

Modules: kit recipes `assets/downtown/kit/kit_dusty2.py`, `kit_summit2.py` (+ palette extensions `kit_world_palette_dh2.py`, `kit_world_palette_su2.py`); planner `src/lookdev/Downtown/City/WorldPlan.luau`, `WorldFeatures.luau`, `Assembler.luau`, `WorldLife.luau`; data `City/Worlds/DustyHighway.luau`, `SummitPass.luau`.

## Dusty Highway (answers D1 to D11)

| ID | Requirement (Adam, 2026-10-28) | Plan section | Carried by | Evidence | Status |
|---|---|---|---|---|---|
| D1 | Grammar G1 to G10 and the five-district template as written | 4, 5, 6 | kit, WorldPlan, data | district stills vs plan | planned |
| D1-G1 | Cream ribbon: clay verge, road meshes unchanged, verge contrast at least 1.8:1 | 4 G1 | palette override `sidewalk_a/b/edge` (DH) | measured pixel contrast in a Studio still | planned |
| D1-G2 | Palette roles: scenery terracotta saturation at most 0.60, sage plants, aerial ramp, one big turquoise disc | 4 G2 | `kit_world_palette_dh2.py` | HSV table in build log | planned |
| D1-G3 | Bold sandstone: three planes, thick masses, class variety (four classes per 600 studs) | 4 G3 | `DH_Mass_Butte_A..F`, `DH_BG_MesaWall_A..D` | gallery sheets, count by stills | planned |
| D1-G4 | Plant families Sentinel, Barrel, Paddle, Rosette; hero not repeated within 150 | 4 G4 | `DH_Fol_*`, `DH_Lot_Cluster*` | stills | planned |
| D1-G5/G6 | One sun, haze only on far shapes; haze-off test | 4 G5, G6 | Lighting test in Studio | haze-off still | planned |
| D1-G7 | No constant-spacing prop family; poles 120 to 220 one side (Diner 48 to 72) | 4 G7 | WorldPlan `poles` | plan stats (spacing list) | code written |
| D1-G8 | Hazard distinction: no scenery within 60 before a hazard, boulders 10+ off the edge | 4 G8 | WorldPlan `hazardClear`, rules | plan check counts | code written |
| D1-G9 | Scenery never ring, arc or arrow near the road; keep Hop and Keys distinct | 4 G9 | kit review | gallery review | planned |
| D1-G10 | Designed groups baked in lot modules | 4 G10 | `DH_Lot_Cluster*`, data lots | stills | planned |
| D2 | Keep all five district names; Sandstone Arch NOT renamed; add the small second arch | 6.3 | data (`RockArch`, `RockArchSmall` "LITTLE ARCH") | plan check: both planned | code written |
| D3 | Canyon Bridge Option A, the true gorge, look-dev only; gameplay parts are Brian R's | 6.4 | WorldPlan gorge, Assembler ground cut, `DH_Gorge_*`, `DH_LM_BridgeTruss384` | Studio stills from road, rim, HIGH camera | code written |
| D3-msg | Message to Brian R through the vault (gorge needs) | 8.4 | `worlds-dusty-summit-for-brian-r.md` on main | pushed to main (9e993b1) | **done** |
| D4 | Thick arch beside the road; drive-through version proposal only | 6.3 | `DH_LM_RockArchThick`, WorldPlan set-back and yaw | still at 300, 120, 60 studs | code written |
| D5 | Clay verge palette swap; sky and light tests in a private place | 4 G1, G5 | palette; Lighting test | stills at ClockTime 14.2, 15.5, 16.5 | planned |
| D6 | Planner changes (look-dev code only): grouped lots, density weights, pole rhythm, sub-seeds, landmark yaw, tumbleweeds skip bridges | 5, 8.4 | Sequencer sub-seeds, WorldPlan, WorldLife | plan digest differs per cycle; Studio | code written |
| D7 | Scenery vehicles: none in v1 (later item, Brian L's cars) | 6.2 | n/a | none built | **done (nothing built)** |
| D8 | Budgets in 8.2 are ceilings | 8.2 | measurement | performance table | planned |
| D9 | Motion: at most two pennant strings, windmill wheel, shimmer strip, within limits | 7 | WorldLife (P3) | real-time video with sound | planned (P3) |
| D10 | Build P1 and P2; P3 only inside the ceilings; list skipped P3 and why | 8.1 | scope | skipped list on review page | planned |
| D11 | Guided OBJ uploads, Creator the Car Hop group | 8.4 | `downtown-kit-worlds-v2` OBJ package | asset ids in `vault/design/assets.md` | **blocked: the group is not created yet (Adam, 2026-10-28 23:2x); previews only until it exists** |

## Summit Pass (answers S1 to S15)

| ID | Requirement (Adam, 2026-10-28) | Plan section | Carried by | Evidence | Status |
|---|---|---|---|---|---|
| S1 | Keep five names and the alpine morning; backdrop first | 1, 5.5 | data, kit order | stills | planned |
| S2 | Retire stacked cones from the foreground; far massifs, ridge curtains, spurs, one recurring horn | 5.5 | `SP_BG_*`, WorldPlan rules and pin, cone lots removed | stills; plan stats | code written |
| S3 | Exaggerated scale (pines 26 to 44, tower 64, lodge hall up to 58) | 5.8 | `SP_Fol_*`, `SP_LM_BellTower`, `SP_LM_SummitLodge`, data | measured sizes in the manifest | planned |
| S4 | Frozen Lake: plane at least 240 x 360, rim, 40-stud buffer, fence, companion addition, no shortcut | 7.3 | WorldFeatures.lake, `SP_FL_*` | plan stats `lake` (across, along, near edge) and a still | code written |
| S5 | Glacier Tunnel: opaque horseshoe gallery, sky windows, gallery bays, zero transparency, exit-exposure rule | 7.4 | WorldFeatures.tunnel, `SP_GT_*` | stills inside and at the exit; transparency count 0 | code written |
| S6 | Ski lift Default: static crossing at least 64 studs; chairs move only off the road; Option M is a proposal | 7.2 | WorldFeatures.lift, WorldLife chairs | plan stats `liftCrossing`; video | code written |
| S7 | Stepped 120-stud lodge; promote the small festival terrace stage | 7.5 | landmark width 120, companions, `SP_LM_FestivalStage` | still at 240, 120, 60 | code written |
| S8 | Landmark order observatory, snowmen, lodge; spacing 300 to 440; majors 500+ apart | 6, 7.5 | Sequencer `landmarkOrder`, data | `Sequencer.check` spacing numbers | code written |
| S9 | WELCOME on the first lap only; later laps "KEEP CLIMBING!" | 6 | WorldPlan `welcomeLater` | plan with length 6400 | code written |
| S10 | Static roadside bunting garlands, no orange, none within 120 before a hazard | 5.1, 5.4 | WorldFeatures.chains `garlands`, `SP_Prop_Garland24` | plan check: nearest hazard distance | code written |
| S11 | Name refinements: clock tower label, "Terrace Chalets", new sign names | 11 | data labels and `signs` | stills | code written (the clock tower label wording is a reversible choice) |
| S12 | Lighting test: warm sun tint, road-contrast retune in a private place | 5.2, 5.3 | Lighting test; palette | stills; measured contrast | planned |
| S13 | Budgets in 8.2 are ceilings | 8.2 | measurement | performance table | planned |
| S14 | Uploads under the standing approval, Creator the Car Hop group, OBJ, Adam clicks the importer | 8.4 | OBJ package | asset ids | **blocked: the group is not created yet (Adam, 2026-10-28 23:2x); previews only until it exists** |
| S15 | Send Brian R the open contracts | 8.4 | vault message | pushed to main | **done** |

## Brief requirements (sections 2 to 5 and added details)

| ID | Requirement | Evidence | Status |
|---|---|---|---|
| B1 | Dusty first, then Summit; compare each first district to Downtown at the same camera before going on | side-by-side stills | planned |
| B2 | Seamless repetition: full repeat boundary, deterministic seeds, active-window cleanup | stills at the wrap, two cycles | planned |
| B3 | Road readable, hazards distinct; scenery never like the Hop ring, chevrons or Keys ring | stills; desaturated hazard test | planned |
| B4 | Performance against each plan's 8.2 ceilings, labelled desktop | performance table | planned |
| B5 | Review page `Car-Hop-Art\review\worlds-dusty-summit\index.html`: stills of every district, before and after, beside Downtown, real-time video with sound per whole World, performance tables, asset ids, skipped P3, decisions for Adam, what Adam and Brian R must do | the page | planned |
| B6 | Studio Play on desktop and the landscape phone and tablet frames; separate Studio-tested from code-read | the page | planned |
| B7 | `./scripts/check.ps1`, commit, push, draft PR that builds on `feature/lane3-hud-downtown-lookdev`, board and log; no merge | PR link | planned |
| B8 | Lane boundaries: nothing in `src/client/Run`, `src/shared/Run`, `src/server`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars` | `git diff --stat` against the base | planned |
