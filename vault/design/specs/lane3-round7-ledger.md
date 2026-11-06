---
title: Lane 3 Round 7 ledger
tags:
  - lane3
  - ledger
---

# Lane 3 Round 7 ledger

Brief: [[lane3-round7]] (source `Car-Hop-Art/review/round7/BRIEF-ROUND7.md`). Decision: [[0042-lane3-round7]]. Report: `Car-Hop-Art/review/round7/RESULT.md`. Frames: `Car-Hop-Art/review/round7/frames/`.

Evidence types: **code**, **self-test** (the beta's Studio self-tests, auto-run in Play on a test save), **solo Play** (Studio Play in `Car-Hop-Art\CarHop-Beta-5-local.rbxl`, driven through the Studio MCP and the Studio-only drivers `CarHopBetaCmd` / `CarHopHomeCmd`), **frame**, **review** (Sonnet reviewer), **published**. "Not done" is never written as a pass.

Branches: the beta is `integration/beta-5`. Lane 3 files that stand on their own are copied to `feature/lane3-round7`. Beta glue (files needing `Shared.Beta` or the beta panels) stays on `integration/beta-5`. Run files go to `feature/lane1-round7-from-adam` (PR #17 into Brian R's branch).

Status: **done**, **partial**, **not done**, **blocked**.

## Setup and process

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| R7-S01 Read first | MUST | done | code | AGENTS.md, BOARD, decisions 0040/0041, Round 6 RESULT and ledger, reference notes, 22 images and GENERATION-NOTES, VERIFICATION.md. |
| R7-S02 Branches, board | MUST | partial | code | Board claim `21ba106` on main. Worktrees `-round7` (integration/beta-5), `-round7-lane3`, `-round7-lane1`. Push sweep done. **PR #15 is not merged:** `gh pr ready 15 && gh pr merge 15` was refused by the session's permission check ("Merge Without Review"). Its check passed and it is mergeable; Adam can press Merge. `feature/lane3-round7` already contains it (merge `bb6976c`). |
| R7-S03 Studio file, rojo | MUST | done | solo Play | `CarHop-Beta-5-local.rbxl`; `rojo serve beta.project.json --port 34890`; Rojo connected by Claude (Adam's standing OK). |
| R7-S04 Permissions batch | MUST | blocked | | Asked in the first message (image uploads; creating Robux products). No "done" from Adam yet. The Open Cloud check also reported scope `developer-product:read` not granted. Blocks M-01 to M-04 and the Roxy portrait upload. |
| R7-S05 Ledger, decision | MUST | done | code | This file, [[0042-lane3-round7]], brief copy. |
| R7-S06 Order, drops | MUST | done | | Order followed. Nothing on the drop list was dropped for time except as marked below. |
| R7-S07 Images | MUST | done | | Used as direction only; names and text from the brief. |
| R7-S08 Evidence rules | MUST | done | review | One lead; two Sonnet reviewers, 11 frames each (T-05). |
| R7-S09 Luck policy, image slips | MUST | done | self-test | Real odds shown before buying (LuckPanel, from `src/shared/Run/Luck`); PolicyService check; restricted accounts see "Not available for your account" and the server refuses (shop self-test). "PIXEL BLAST" spelled from the brief. |

## Module A

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| A-01 Spawn at your Raceway | MUST | done | solo Play | `HomeSpot`; join and every return go to your own plot's entrance. |
| A-02 Badge over every plot | MUST | done | solo Play | Always-on-top badges with the owner's headshot. |
| A-03 Circuit Coming soon | MUST | done | self-test | Closed gate; the server refuses Circuit events. |
| A-04 RICHEST RACERS | MUST | done | solo Play | This server's players only. |
| A-05 Portals and Coach Roxy | MUST | partial | code, solo Play | Two bars (cars, Cash), one next-step line, GOT IT / UNLOCK; the portal-open moment (chains fall) is the existing Portals moment. **Roxy's new portrait is not uploaded** (R7-S04). |
| A-06 Launch Pads detail | MUST | partial | frame | Faceted bushes with flowers, trees (pines on Summit), lamps, benches, bunting, hydrants / crates / tyre stacks, a ROAD CLOSED set with an invisible wall, symmetric layout, HOME arch. Checked north and south from Downtown; **the full 360-degree turn at three heights in all three Worlds was not done**. |
| A-07 Launch card | MUST | done | frame | No hops line, car centred about its own middle, red X (48 px), walking off closes it, START orange. |
| A-08 Island cooler | SHOULD | not done | | Time went to MUSTs. |

## Module R

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| R-01 Two-press Hop | MUST | done | self-test, solo Play | Leap (1 bolt), float 0.6x, dive; bonk and recovery. |
| R-02 Heat faster | MUST | partial | code | Heat over Keys time + 3 s. **The 20-ride measurement was not run.** |
| R-03 One size x1.25 | MUST | done | code, solo Play | `RunConfig.ROAD_CAR_SCALE = 1.25`. |
| R-04 Bump costs a bolt | MUST | done | self-test | 1.5 s grace; server counts too. |
| R-05 Inside the car | MUST | done | solo Play | Rider hidden on every boarding path. |
| R-06 WRECKED | MUST | done | frame | The WRECKED card now leaves as Results opens (it stayed behind Results before). |
| R-07 End Run | MUST | done | solo Play | |
| R-08 World never runs out | MUST | partial | solo Play (pretend run) | Cause: the World was one ~9,000-stud route at fixed positions. Now laps of the World follow the car. Checked with a pretend run at 2,000 to 19,500 studs (parts ahead at every point). **The 10-minute autopilot run in each World with parts, memory and frames at 0/5/10 min was not done.** |
| R-09 No white world | MUST | partial | frame | Haze was near white (205, 224, 238, density 0.3); now sky blue / sand / mountain blue. Each World is preloaded before START ("Warming up..."). **Cold join of the published game not checked.** |
| R-10 Rare cars shout | MUST | done | solo Play | Three-line tags, distance by rarity, taller Legendary beacon. |
| R-11 Run feedback | MUST | done | solo Play | IT'S YOURS / SECURED from server grants. |
| R-12 Luck in the run | MUST | done | self-test | Run keeps the save's luck snapshot; LUCK xN badge. |

## Modules P and L

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| P-01 Offline earnings land | MUST | partial | self-test | 40%, 24 h, VIP 30 h; credited on COLLECT or on leaving, once. **A real rejoin was not possible in this local file** (DataStore unavailable). |
| P-02 Portal rules on server | MUST | done | self-test | |
| P-03 Stamina BUY works | MUST | done | solo Play, frame | A real click on BUY took level 0 to 1. Panel now titled PIT STOP. |
| P-04 Luck prices and save | MUST | done | self-test | |
| L-01 Lucky Clover kiosk | MUST | done | frame | |
| L-02 Odds rule | MUST | done | self-test | Table below. |
| L-03 Feel | SHOULD | done | code | Clover badge and LUCKY! when a Rare or better joins while luck is on; no faked per-car luck. |
| L-04 Proof | MUST | done | self-test | 20,000 spawns, observed within 1 point of the rule. See the note under the table. |

**L-02 table** (start of a run, before the distance ramp): luck x1: Rare 30%, Epic 6%, Legendary 1.2% (37.2% Rare or better). Luck x2: Rare 45%, Epic 12%, Legendary 2.4%. Luck x4 and above hit the cap: 65% Rare or better, because Commons never fall below 35%.
**Honest note:** averaged over a whole 2 km run, x4 raises Rare or better only from 64.75% to 65.02% (seed 70707), because the distance ramp already reaches the cap. Luck matters mostly early in a run. Raising the Commons floor or the cap is a design choice for Adam and Brian L.

## Module C

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| C-01 Preview on your car | MUST | done | frame | Your selected car on the Style Shop turntable. |
| C-02 Paint only on paint | MUST | partial | frame | Masked body-only paint on 27 cars. **Apex** takes weak paint (its texture is mostly grey; mask forced). **Viper Strike** keeps some green. **Rainbow editions** (own mesh, no mask) are not painted; Gold and Diamond use the base mask. |
| C-03 Paints | MUST | done | code | 34 paints plus Factory Paint in seven tiers ($500 to $2B; three Robux; two VIP). |
| C-04 Decals | MUST | done | code | 20 decals, drawn in code (EditableImage). |
| C-05 Wheels | MUST | done | code | 14 wheels. |
| C-06 Trails | MUST | done | frame | 13 trails from the exhausts. "Rainbow Road" in the brief is named **Rainbow Runway**, so no existing game's name is used. |
| C-07 One Style Shop | MUST | done | frame | |
| C-08 Equipped is visible | MUST | done | frame, self-test | Run car, Raceway lineup car, Garage and launch card. |
| C-09 Pick-me moments | SHOULD | not done | | |

## Module U

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| U-01 Upgrade screens | MUST | partial | frame | Racetrack frame (kerbs, chequered corners, lapping car) and paddock frame (bay lines, P sign) round the existing rows, price and BUY. **No preview image of the next level's look, and phone and tablet sizes not captured.** |
| U-02 Pick a car | MUST | done | code | RIDE THIS CAR with "Ready to ride" and a glow. **Not captured in a frame.** |
| U-03 No editions ladder | MUST | done | code | Ladder hidden; edition badge in the corner. **Not captured in a frame.** |
| U-04 Results | MUST | done | frame | GREAT RUN!, distance, cars with pictures, Cash, 19 Robux respawn, RETRY, HOME; no free respawn. |
| U-05 Missions | MUST | done | self-test, frame | 45 missions, five tabs plus GOALS, green claim count per tab, red count on the Missions button. |
| U-06 Shop fixes | MUST | done | code | |
| U-07 Stamina and Luck panels | MUST | done | frame | Bolt sparks and flash; clover leaf burst. |
| U-08 Round 6 leftovers | SHOULD | not done | | |

## Modules K and H

| ID | Level | Status | Evidence | Notes |
|---|---|---|---|---|
| K-01 Rare cars glow | MUST | done | frame | Strip and light by rarity, sparkles for Epic and Legendary, gold pillar and finish-line fireworks for Legendary, edition effects. Fireworks not seen in a frame. |
| K-02 Money you can see | SHOULD | partial | | "+$" pops at the line exist; no $/lap tags. |
| K-03 EQUIP BEST | SHOULD | not done | | |
| K-04 Bays and badges | MAY | not done | | |
| H-01 Goal line | MUST | done | frame | From the live mission feed; hidden in runs and during the tutorial. |
| H-02 Roxy's next goal | SHOULD | not done | | |
| H-03 Kiosk signs | MUST | done | frame | Pit Stop, Lucky Clover, Raceway shop, parking. |
| H-04 Fast loop | MUST | done | solo Play | Path from each plot to the Downtown portal 367 to 418 studs; at walk speed 32 that is 11.5 to 13.1 s, plus about 2.4 s from the pad's arrival to the ramp: 14 to 15.5 s, under 20 s. |
| H-05 Failure teaches | MUST | done | frame | Each wreck names its fix. |
| H-06 Sound | SHOULD | not done | | |
| H-07 First five minutes | SHOULD | not done | | |
| H-08 Pacing check | SHOULD | not done | | |

## Modules M, N, T, F

| ID | Level | Status | Notes |
|---|---|---|---|
| M-01 Products | MUST if S04 | blocked | No "done" from Adam on R7-S04. |
| M-02 Test purchases | MUST if M-01 | blocked | |
| M-03 Uploads | MUST if S04 | blocked | Art ready in `Car-Hop-Art/upload-round7/`. |
| M-04 Product art | SHOULD | partial | Art cropped (`art_r7_*.png`), not uploaded. |
| N-01 Brian R note | MUST | done | [[lane3-round7-for-brian-r]] |
| N-02 Brian L note | MUST | done | [[lane3-round7-for-brian-l]] |
| N-03 Board, decision, log | MUST | done | |
| T-01 check.ps1 | MUST | done | Passed on every pushed branch. |
| T-02 Self-tests | MUST | done | 11 suites, 0 not PASS. |
| T-03 Two-client and rejoin suites | MUST | done | Multi-client plugin in Studio: "two" 16/16, "rejoin" 12/12. A first "two" run failed 14/16 because the automatic self-tests changed Player1's save during the test; they now stand aside in multi-client tests (`f060852`). |
| T-04 10-minute runs, cold join | MUST | not done | See R-08 and R-09. Next action: in Studio Play run `CarHopBetaCmd` "start" plus the autopilot for 10 minutes in each World and record parts, memory and frames at 0/5/10 min; after the publish, Adam's first join is the cold-join check. |
| T-05 Frames and reviewers | MUST | partial | Desktop frames only; two Sonnet reviewers (results in RESULT.md). |
| T-06 Six clients | SHOULD | not done | First on the drop list. |
| F-01 Push, PRs | MUST | done | Every branch pushed and matching GitHub. PR #17 (run files, into Brian R's branch), draft PR #18 (`feature/lane3-round7` into `main`), draft PR #19 (`integration/beta-5` into `main`). |
| F-02 Merge lane3-round7 | MUST | not done | Not every MUST passed. |
| F-03 Publish | MUST | blocked | The Studio MCP has no publish action: `StudioPublishService` is not reachable from its scripts, its keyboard tool reaches only the game view, and Open Cloud here sends only JSON or asset files (not a place file). This round allows Studio MCP input only, so the window-message clicks used in Round 6 were not used. Next action: Adam presses File > Publish to Roblox As in `CarHop-Beta-5-local.rbxl`, guided one click at a time; then check `Updated` on economy.roblox.com/v2/assets/118605678346800/details. |
| F-04 RESULT.md | MUST | done | `Car-Hop-Art/review/round7/RESULT.md`. |

## T-05 reviewer findings

Two Sonnet reviewers, 11 frames each, 2026-11-05.

| Finding | Action |
|---|---|
| Kiosk signs too small; Pit Stop and Lucky Clover signs overlap | Fixed: signs 12 x 4.8 studs, Lucky Clover sign raised (`c0fb701`). |
| Goal line sits over the upgrade cards | Fixed: hidden while an upgrade card is open. |
| "Catch your first car" mission read oddly | Fixed: "Have 2 cars: catch your first!". |
| ROAD CLOSED sign and cones small | Fixed: 16 x 6 sign, bigger cones. |
| One SUV in the paint contact sheet looks like a police livery | Open: listed for Brian L ([[lane3-round7-for-brian-l]]), AGENTS.md vehicle rule 5. |
| Lightning trail weak (thin white loops) | Open: needs a thicker beam and colour. |
| Galaxy paint ragged; Putter's cream top unpainted | Open: mask work (C-02). |
| Clover mascot looks like spheres on a block | Open: needs a modelled clover. |
| Pit Stop bolt icons do not match the hop counts | Open: tie icons to `RunStamina` tiers. |
| Results has no scrim; HUD shows around it | Open. |
| "CARS CAUGHT" label partly hidden | Open. |
| "BETA" pill confusing | Open. |
| Unaffordable button orange on the Raceway card, grey elsewhere | Open: pick one rule. |
| Luck odds text dense; "Legendary 3%→3%" at the cap | Open: hide unchanged lines. |
| Mixed fonts | Open: fonts are undecided (AGENTS.md). |
| Hydrant plain | Open. |

## Studio test drivers added this round (Studio only)

`CarHopBetaCmd`: `start`, `scenery:World/studs` and `scenery:off` (a pretend run for R-08), `aura:Car/edition,...` (K-01 test cars). `CarHopHomeCmd`: `open:<panel>`, `tab:<Missions tab>`, `skip:tutorial`, `close:update`, `kiosk:upgrade` / `kiosk:parking`. The attribute bridge turns the words on/off into true/false, so commands accept both.
