---
title: Dusty Highway and Summit Pass build - requirement ledger
tags:
  - design
  - worlds
  - lane3
  - ledger
status: built and checked in Studio Edit previews (2026-10-29); uploads blocked until the Car Hop group exists
---

# Requirement ledger: Dusty Highway and Summit Pass build

Source of every row: Adam's brief [[worlds-dusty-summit-build]] (section 1 answers, 2026-10-28), the plans [[world-plan-dusty-highway]] and [[world-plan-summit-pass]], decision [[0026-world-plans-approved]]. Kit status (2026-10-28 23:22): both V2 kits are built from the Blender recipes (Dusty 94 meshes / 19,508 triangles and Summit 125 meshes / 35,792 triangles referenced by the data, within the 110 and about-130 ceilings), authored by two Sonnet workers (each reported claude-sonnet-5-5) and reviewed by the lead on gallery sheets; the planner code passes Selene, StyLua and the Rojo build. Studio ran both Worlds in the lead's own Studio on 2026-10-28 and 29 (Edit previews). Status words: **planned**, **code written** (Selene and StyLua pass, not yet run in Studio), **built and checked in Studio**, **blocked**, **not done**. "Evidence" names the check that will prove it; nothing is marked built until that evidence exists.

Modules: kit recipes `assets/downtown/kit/kit_dusty2.py`, `kit_summit2.py` (+ palette extensions `kit_world_palette_dh2.py`, `kit_world_palette_su2.py`); planner `src/lookdev/Downtown/City/WorldPlan.luau`, `WorldFeatures.luau`, `Assembler.luau`, `WorldLife.luau`; data `City/Worlds/DustyHighway.luau`, `SummitPass.luau`.

## Dusty Highway (answers D1 to D11)

| ID | Requirement (Adam, 2026-10-28) | Plan section | Carried by | Evidence | Status |
|---|---|---|---|---|---|
| D1 | Grammar G1 to G10 and the five-district template as written | 4, 5, 6 | kit, WorldPlan, data | district stills vs plan | **built; checked in Studio Edit preview** (before/after stills of every district, review page) |
| D1-G1 | Cream ribbon: clay verge, road meshes unchanged, verge contrast at least 1.8:1 | 4 G1 | palette override `sidewalk_a/b/edge` (DH) | measured pixel contrast in a Studio still | **built; measured** road:verge 2.14:1 at ClockTime 14.2 and 2.56:1 at 16.5 (target 1.8:1); chosen 15.5 sits between, not measured on its own |
| D1-G2 | Palette roles: scenery terracotta saturation at most 0.60, sage plants, aerial ramp, one big turquoise disc | 4 G2 | `kit_world_palette_dh2.py` | HSV table in build log | built (kit palette, worker HSV report); not re-audited by the lead in Studio |
| D1-G3 | Bold sandstone: three planes, thick masses, class variety (four classes per 600 studs) | 4 G3 | `DH_Mass_Butte_A..F`, `DH_BG_MesaWall_A..D` | gallery sheets, count by stills | built and seen in stills; the four-classes-per-600-studs count was not measured |
| D1-G4 | Plant families Sentinel, Barrel, Paddle, Rosette; hero not repeated within 150 | 4 G4 | `DH_Fol_*`, `DH_Lot_Cluster*` | stills | built and seen in stills; hero spacing 150 not measured |
| D1-G5/G6 | One sun, haze only on far shapes; haze-off test | 4 G5, G6 | Lighting test in Studio | haze-off still | **partly done**: light tests made (ClockTime, Atmosphere, grade); the sky stays the engine default (no uploaded skybox, no Sky object); haze-off still not captured |
| D1-G7 | No constant-spacing prop family; poles 120 to 220 one side (Diner 48 to 72) | 4 G7 | WorldPlan `poles` | plan stats (spacing list) | **built; planner check passes in Studio** |
| D1-G8 | Hazard distinction: no scenery within 60 before a hazard, boulders 10+ off the edge | 4 G8 | WorldPlan `hazardClear`, rules | plan check counts | **built; planner check passes in Studio** (hazard-clear zones from data) |
| D1-G9 | Scenery never ring, arc or arrow near the road; keep Hop and Keys distinct | 4 G9 | kit review | gallery review | built; judged on stills by the lead and the final reviewer |
| D1-G10 | Designed groups baked in lot modules | 4 G10 | `DH_Lot_Cluster*`, data lots | stills | built (lot modules); seen in stills |
| D2 | Keep all five district names; Sandstone Arch NOT renamed; add the small second arch | 6.3 | data (`RockArch`, `RockArchSmall` "LITTLE ARCH") | plan check: both planned | **built; planner check passes** (both arches planned; 58.0 and 55.1 studs from the road edge) |
| D3 | Canyon Bridge Option A, the true gorge, look-dev only; gameplay parts are Brian R's | 6.4 | WorldPlan gorge, Assembler ground cut, `DH_Gorge_*`, `DH_LM_BridgeTruss384` | Studio stills from road, rim, HIGH camera | **built; checked in Studio** (road, rim and HIGH camera stills). Limit: the gorge is a 124-stud-wide pit under the bridge (the approved half-width 62), not a canyon cutting the whole landscape |
| D3-msg | Message to Brian R through the vault (gorge needs) | 8.4 | `worlds-dusty-summit-for-brian-r.md` on main | pushed to main (9e993b1) | **done** (main 9e993b1) |
| D4 | Thick arch beside the road; drive-through version proposal only | 6.3 | `DH_LM_RockArchThick`, WorldPlan set-back and yaw | still at 300, 120, 60 studs | built; approach stills at 300, 120 and 60 studs; drive-through stays a proposal |
| D5 | Clay verge palette swap; sky and light tests in a private place | 4 G1, G5 | palette; Lighting test | stills at ClockTime 14.2, 15.5, 16.5 | **tested**: ClockTime 14.2, 15.5, 16.5 stills; 15.5 chosen (reversible) |
| D6 | Planner changes (look-dev code only): grouped lots, density weights, pole rhythm, sub-seeds, landmark yaw, tumbleweeds skip bridges | 5, 8.4 | Sequencer sub-seeds, WorldPlan, WorldLife | plan digest differs per cycle; Studio | built; planner checks pass; the per-cycle plan digest comparison was not run |
| D7 | Scenery vehicles: none in v1 (later item, Brian L's cars) | 6.2 | n/a | none built | **done (nothing built)** |
| D8 | Budgets in 8.2 are ceilings | 8.2 | measurement | performance table | **measured** (Edit preview, desktop): all ceilings met, see the review page |
| D9 | Motion: at most two pennant strings, windmill wheel, shimmer strip, within limits | 7 | WorldLife (P3) | real-time video with sound | **built within the ceilings** (30 animated parts at most); real-time video with music |
| D10 | Build P1 and P2; P3 only inside the ceilings; list skipped P3 and why | 8.1 | scope | skipped list on review page | P1 and P2 built; P3 listed on the review page |
| D11 | Guided OBJ uploads, Creator the Car Hop group | 8.4 | `downtown-kit-worlds-v2` OBJ package | asset ids in `vault/design/assets.md` | **blocked: the group is not created yet** (Adam, 2026-10-28). Used-only OBJ packages (94 and 125 meshes) are ready in `Car-Hop-Art\downtown-kit-worlds-v2-upload`; previews only until the group exists |

## Summit Pass (answers S1 to S15)

| ID | Requirement (Adam, 2026-10-28) | Plan section | Carried by | Evidence | Status |
|---|---|---|---|---|---|
| S1 | Keep five names and the alpine morning; backdrop first | 1, 5.5 | data, kit order | stills | **built; checked in Studio Edit preview** (stills of every district) |
| S2 | Retire stacked cones from the foreground; far massifs, ridge curtains, spurs, one recurring horn | 5.5 | `SP_BG_*`, WorldPlan rules and pin, cone lots removed | stills; plan stats | **built; planner checks pass** (cone lots removed; far massifs and horn in stills) |
| S3 | Exaggerated scale (pines 26 to 44, tower 64, lodge hall up to 58) | 5.8 | `SP_Fol_*`, `SP_LM_BellTower`, `SP_LM_SummitLodge`, data | measured sizes in the manifest | built; sizes read from the manifest (tower 64.6, lodge 64.3 tall) |
| S4 | Frozen Lake: plane at least 240 x 360, rim, 40-stud buffer, fence, companion addition, no shortcut | 7.3 | WorldFeatures.lake, `SP_FL_*` | plan stats `lake` (across, along, near edge) and a still | **built; planner check passes** (lake 288 x 384, starts 92 from the centre); seen in stills and from the road |
| S5 | Glacier Tunnel: opaque horseshoe gallery, sky windows, gallery bays, zero transparency, exit-exposure rule | 7.4 | WorldFeatures.tunnel, `SP_GT_*` | stills inside and at the exit; transparency count 0 | **built; checked** (opaque gallery, stills outside and inside; 0 visible transparent surfaces) |
| S6 | Ski lift Default: static crossing at least 64 studs; chairs move only off the road; Option M is a proposal | 7.2 | WorldFeatures.lift, WorldLife chairs | plan stats `liftCrossing`; video | **built; planner check passes** (crossing 69.5 over the deck); chairs move only off the road; Option M stays a proposal |
| S7 | Stepped 120-stud lodge; promote the small festival terrace stage | 7.5 | landmark width 120, companions, `SP_LM_FestivalStage` | still at 240, 120, 60 | built (hall mesh 55 wide plus wing lots and the festival stage as companions); the full 120-stud width is carried by companions, judged on stills only |
| S8 | Landmark order observatory, snowmen, lodge; spacing 300 to 440; majors 500+ apart | 6, 7.5 | Sequencer `landmarkOrder`, data | `Sequencer.check` spacing numbers | **built; planner check passes** (observatory 2499, snowmen 2569, lodge 2925) |
| S9 | WELCOME on the first lap only; later laps "KEEP CLIMBING!" | 6 | WorldPlan `welcomeLater` | plan with length 6400 | built; planner check passes (welcome only on lap one); a 6,400-stud two-lap run was not captured |
| S10 | Static roadside bunting garlands, no orange, none within 120 before a hazard | 5.1, 5.4 | WorldFeatures.chains `garlands`, `SP_Prop_Garland24` | plan check: nearest hazard distance | **built; planner check passes** (nearest garland 154 studs before a hazard) |
| S11 | Name refinements: clock tower label, "Terrace Chalets", new sign names | 11 | data labels and `signs` | stills | built; the clock tower label wording is a reversible choice |
| S12 | Lighting test: warm sun tint, road-contrast retune in a private place | 5.2, 5.3 | Lighting test; palette | stills; measured contrast | **tested**: warm sun tint not applied (the colours read well); road swatch retuned from (90,98,114) to (72,80,98), measured 4.3 to 4.5:1 (was 2.67 to 2.95:1) |
| S13 | Budgets in 8.2 are ceilings | 8.2 | measurement | performance table | **measured** (Edit preview, desktop): all ceilings met, see the review page |
| S14 | Uploads under the standing approval, Creator the Car Hop group, OBJ, Adam clicks the importer | 8.4 | OBJ package | asset ids | **blocked: the group is not created yet**; packages ready as for D11 |
| S15 | Send Brian R the open contracts | 8.4 | vault message | pushed to main | **done** (main 9e993b1) |

## Brief requirements (sections 2 to 5 and added details)

| ID | Requirement | Evidence | Status |
|---|---|---|---|
| B1 | Dusty first, then Summit; compare each first district to Downtown at the same camera before going on | side-by-side stills | **done** (Downtown s215 beside each World first district) |
| B2 | Seamless repetition: full repeat boundary, deterministic seeds, active-window cleanup | stills at the wrap, two cycles | **not verified**: the active window stayed correct over each full route in the sweep and the chase; the two-cycle wrap at 6,400 studs was not captured |
| B3 | Road readable, hazards distinct; scenery never like the Hop ring, chevrons or Keys ring | stills; desaturated hazard test | partly done: stills read well; the desaturated hazard test was not run |
| B4 | Performance against each plan's 8.2 ceilings, labelled desktop | performance table | **done** (measured; desktop labelled) |
| B5 | Review page `Car-Hop-Art\review\worlds-dusty-summit\index.html`: stills of every district, before and after, beside Downtown, real-time video with sound per whole World, performance tables, asset ids, skipped P3, decisions for Adam, what Adam and Brian R must do | the page | **done** (`Car-Hop-Art\review\worlds-dusty-summit\index.html`) |
| B6 | Studio Play on desktop and the landscape phone and tablet frames; separate Studio-tested from code-read | the page | **not tested in Play**: Play cannot hold the EditableMesh previews, so Studio Play and the phone and tablet frames wait for the uploaded meshes; every picture is Studio Edit |
| B7 | `./scripts/check.ps1`, commit, push, draft PR that builds on `feature/lane3-hud-downtown-lookdev`, board and log; no merge | PR link | checks pass (`./scripts/check.ps1` exit 0); draft PR opened (see the log); never merged |
| B8 | Lane boundaries: nothing in `src/client/Run`, `src/shared/Run`, `src/server`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars` | `git diff --stat` against the base | **checked** (`git diff --stat` shows no change outside Lane 3 folders and vault) |
