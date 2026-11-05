---
title: Lane 3 Round 5 ledger
tags:
  - lane3
  - ledger
---

# Lane 3 Round 5 ledger

Brief: [[lane3-round5]] (source `Car-Hop-Art/review/round5/BRIEF-ROUND5.md`). Decision: [[0039-lane3-round5-beta-loop]]. Report: `Car-Hop-Art/review/round5/RESULT.md`. Evidence: `Car-Hop-Art/review/round5/evidence/`.

Evidence types (R5-S09): **code**, **self-test**, **solo Play**, **frame**, **multi-client** (StudioTestService session, n clients), **published**. "Not done" is never written as a pass.

## The state on paper (L, also Brian L's handoff H-01)

One row per agreed field. Server = `src/server/Beta` (beta-only stand-ins). Attributes are written by the server only, read only on the client.

| Field (save) | Changed by (remote or event, server side) | Replicated as | Read by (client screen) |
|---|---|---|---|
| `Cash` | Lap Pay tick (`BetaLapPay`), run grants (`BetaRunEvents`, `BetaKeysComplete`), `BuyRacewayLevel`, `BuyParkingSpot`, `UnlockWorld`, Welcome back credit (on load), tutorial bonus (`TutorialDone`), Studio cheat `BetaGrantCash` | Player `BetaCash` | Home HUD Cash (HomeShell store), run HUD Cash (RunHud), Shop Cash readout (store), Raceway upgrade and parking panels (`ShopPanel.cashOf`), Lineup panel's next-spot price, Coach Roxy's locked portal card |
| `Cars` | claims and Joyrides (`BetaKeysComplete`) | Player `BetaCars` ("id:edition:copies,...") | Garage Index (cards, editions, copies, PARK), Lineup panel (pick list, Lap Pay), Results (car lines), Coach Roxy (cars owned from the World before) |
| `Lineup` | `SetLineupSlot` (Lineup panel), auto-park on a claim (`BetaKeysComplete`) | Player `BetaLineup` ("Putter,Minnow") | Raceway cars (RacewayLineup, every client), Lineup panel, Garage PARK state, tutorial Park step |
| `RacewayLevel` | `BuyRacewayLevel` | plot `SpeedwayLevel` | Raceway looks and upgrade panel, Lineup panel Lap Pay |
| `ParkingSpots` | `BuyParkingSpot` (and the Expanded Paddock pass, Studio switch only) | plot `ParkingSpots`, `ExpandedPaddock` | Raceway bays and parking panel, Lineup panel spots |
| `WorldsUnlocked` | `UnlockWorld` | Player `BetaWorldsUnlocked` ("Downtown,DustyHighway") | portals (PortalPreviewState), Coach Roxy, server refuses a run in a locked World |
| `LastSeen` | stamped on load (after the Welcome back credit) and on leave | Player `BetaWelcomeAmount`, `BetaWelcomeSeconds` (the credit already paid on this load) | Welcome back card |
| `TutorialDone` (beta-only, Round 2) | `TutorialDone` (finished or skipped) | Player `TutorialDone` | join flow (tutorial or Welcome back), auto-park hold |

Lap Pay clock: plot `BetaLapEpoch` (server time) and `BetaLapSeconds`; `src/shared/UI/LapClock` gives slot s its crossing moments. Payout event: `BetaLapPaid(plotIndex, slot, carId, amount, newCash?)` to every client, `newCash` only to the owner.

## Ledger

Status: **done** (built and checked as named), **partial**, **not done**, **blocked**. Evidence names the type.

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| R5-S01 | Read the brief, decisions, ledgers, economy v1, Brian L's preview branch, Replies | MUST | done | code | Brian L's `feature/lane2-economy-preview` has server code (Economy, LapPay, Shop, Data, Plots): stand-in function names follow his (addCash, trySpend, lapPayFor, lineupPayPerLap, payOffline, Lap signal). No teammate replied in any Replies section. |
| R5-S02 | Merge Round 4 (PR #11) into main, branch `feature/lane3-round5` | MUST | partial | code | PR #11's check passed (2 runs SUCCESS at 8080fe8). Marking it ready and merging was **refused by the session's auto-mode permission check** ("Unrequested Commit in a Connected App"); not worked around. `feature/lane3-round5` was branched from the Round 4 tip (8080fe8) plus `main` (worktree `Roblox-Game-1-round5`), so nothing of Round 4 is lost; PR #11 waits for Adam. |
| R5-S03 | Board claim on main | MUST | done | code | `eaa73ee` on main |
| R5-S04 | Brief copy, this ledger, decision 0039 | MUST | done | code | 0039 reserved in `DECISION_NUMBERS.txt` |
| R5-S05 | Dated backup, the local beta is the main place | MUST | done | code | `CarHop-Beta-2-local.2026-11-03-before-round5.rbxl`. Multi-client suites ran in an identical copy `CarHop-Beta-2-multitest.rbxl` in a second Studio, because loading the new local plugin needs a Studio start and the first window could not be saved without sending keys while another window had focus. |
| R5-S06 | Rojo | MUST | done | code | `rojo serve beta.project.json` running from `Roblox-Game-1-beta2`. Code reached the places by the Round 4 route (local read-only tree server + Edit-mode pull); no Connect click was needed, so Adam was not asked for one. |
| R5-S07 | Lineup panel design route | MUST | done | code | Your call: built straight in Studio from R5-IMG-01 in the game's navy panel style (like the Car stall and the Garage), not in Figma. |
| R5-S08 | References | MUST | done | code | The images were read as layout direction. The game's existing navy panels and font win over the images' cream cards (brief R5-S08); recorded discrepancy, no restyle of other screens. |

### Module L: the loop (MUST)

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| L-01 | Cash, WorldsUnlocked, LastSeen in the beta save; BetaCash read only; FreePurchases default false | MUST | done | self-test (economy 24/24: old save gets Cash 0 and LastSeen 0, WorldsUnlocked=false repaired, empty table gains Downtown, NaN Cash repaired), solo Play (HUD, Shop, Raceway panels, Lineup panel, Coach Roxy read BetaCash; frame L-01) | Start Cash $0. Your call: a one-time PREVIEW tutorial bonus of $500, paid only on the TutorialDone false-to-true change (seen in Play), so the first spot ($500) is affordable when the tutorial ends. The run HUD now shows the server's Cash (Brian R's run sends 0). |
| L-02 | Lap Pay on the server, one scheduler, staggered, same clock as the cars | MUST | done | self-test (lappay 3/3, LapClock 0 failures: a 61 s stall pays once, a swap 0.1 s before the line keeps its crossing), solo Play (Cash rose $10 a lap; cars drive round the plot on LapClock, sampled moving about 27 studs a second; pop frame L-02), multi-client `two` (B sees A's 2 cars and 2 pops without newCash, B's Cash 0 -> 0; A gets 9 pops with newCash) | Your call: cars vanish with the plot when the owner leaves. Missing model: the stand-in car drives and the miss is logged once; the server pays from the save. Video `videos/L-02-lap-pay-raceway-SILENT.mp4` (20 s, no sound; see A-01). |
| L-03 | Run report, client-trusted inside caps; claim or Joyride decided by the server; Results from server totals | MUST | done | self-test (run 14/14), solo Play (autopilot runs: claims Pizza Runner, Minnow, Bolt; Joyrides; the 500 m milestone; Results "Parked at your Raceway" and "In your Garage. Raceway full."; frames L-03) | The server hands out the seed and rebuilds Brian R's sequence to look up each spawn, so `betaModel` is checked against the server's own answer. Caps in decision 0039. "Checking..." while a claim is unanswered (3 s). Brian R's run reports no coins, so there is no coin row. |
| L-04 | Lineup panel, Garage PARK, auto-park, tutorial Park step | MUST | done; Park step partly | solo Play (Park Cars prompt on F at the parking sign; Garage PARK opens the panel with the car picked out; refusal "Get more spots first."; Swap Pizza Runner -> Minnow and the Raceway rebuilt from BetaLineup; BUY a spot in the panel; frames L-04), multi-client `two`, self-test (lineup) | Built in Studio from R5-IMG-01 (R5-S07). Your call: the next spot is sold inside the panel ("BUY $500"); GET MORE SPOTS opens the Shop pass only past 15. The Park step completes on the Lineup attribute; only the path where the tutorial run caught Joyrides (nothing to park) was walked. The hand-park of a held claim was not walked in Play. |
| L-05 | Purchases charge Cash; UnlockWorld; can't-afford from the server | MUST | done | self-test (shop 11/11), solo Play (BUY $500 took Cash $550 -> $50; then "$1,450 more") | Coach Roxy shows cars, then Cash, then UNLOCK; pressing UNLOCK in Play was not reached (needs 5 Downtown cars). Portals follow BetaWorldsUnlocked; the "every portal open" beta switch is gone. |
| L-06 | Welcome back credit (SHOULD) | SHOULD | done (credit); card animation not re-checked | self-test (never stamped 0, 30 s 0, future 0, 1 h 721,200 at $6,010 a lap, 24 h capped, empty Lineup 0), multi-client `rejoin` (under 60 s pays 0, LastSeen stamped) | The card shows the server's paid amount; COLLECT only acknowledges. A same-server rejoin pays nothing (memory only). A real absence over 60 s was not played. |
| L-07 | The loop on every screen | MUST | partial | solo Play: tutorial, Downtown run, claims, Results, home, toasts, Lineup park/swap, Lap Pay, buy a spot, second run, auto-park (parked and Raceway full), Garage with copies ("Unlocked 3 / 27") | Not walked: buying a Raceway level, unlocking Dusty Highway with BetaGrantCash (coded, Studio-only, not exercised). |
| L-08 | Self-tests | MUST | done | `evidence/L-08-selftests-1.txt` | All PASS on Mock. Not proven: persistence across a fresh server process. |

### Module T: multi-client (MUST)

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| T-01 | Local plugin and beta harness, hands-free | MUST | done | multi-client (plugin printed its startup line; four suites launched by a Workspace attribute set through the Studio MCP; EndTest results returned) | Plugin `%LOCALAPPDATA%\Roblox\Plugins\CatchACar-MultiTest.lua`, source `Car-Hop-Art\tools\multitest-plugin.lua`. A plugin cannot write a file at a chosen path: results go to a Workspace attribute and Output and the host saved them as `evidence/multitest-*.json`. A new local plugin loads only on Studio start, so the suites ran in a second Studio on a copy of the beta file. |
| T-02 | Two clients, suite `two` | MUST | done | multi-client, 2 clients + AddPlayers(1): 16/16 PASS, 0 server errors, `multitest-two-2-c62ba0bf.json` | Plots 1 and 2 with owner names; park; visitor sees cars and pops with own Cash unchanged; forged extra and malformed arguments leave A alone; two runs at once (Downtown, Dusty Highway) each with its own Cash; no claim crosses saves; B leaves, plot freed in 0.6 s, A's Lap Pay continues; C gets plot 2. Players spawn on the plaza (Adam's decision), not at gates. |
| T-03 | Rejoin, suite `rejoin` | MUST | done (synthetic) | multi-client, 1 client + AddPlayers(1): 10/10 PASS, `multitest-rejoin-1-6b7d7ed5.json` (two earlier tries failed: the run was asked for during the loading screen; fixed) | Synthetic same-profile rejoin: UserId -1 left, UserId -2 joined on mock key -1. Proven: graceful leave + EndSession on Mock keeps Cash 120, cars, Lineup, LastSeen; no Welcome back pay under 60 s. Not proven: a real account, a crash, a live DataStore. |
| T-04 | Six clients (SHOULD) | SHOULD | partial | multi-client, `multitest-six-6-1e66f90b.json` | Only 5 of 6 clients were ready inside 120 s on this laptop (7 Studio windows), so the added client became the 6th and no 7th existed. Server 18.0 ms mean frame; Lap Pay pass 0.30 ms mean. |
| T-05 | Report | MUST | done | four JSON files; one client frame taken from inside a test through the Studio MCP | 0 server errors in every suite. |

### Module S: Shop

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| S-01 | Pass art without cars | MUST | partial | frames (`evidence/shop/round2`), both reviewers R1 PASS | Starter Pack and Expanded Paddock art cut from R5-IMG-03; VIP uses the game's uploaded crown icon (your call). **Not uploaded**: the two PNGs (`Car-Hop-Art/review/round5/art/`) show only where `Lane3_LocalArt` exists; elsewhere the uploaded gift and parking icons stand in, never a car. No asset id exists yet, so none is recorded. |
| S-02 | Round 4 findings fixed, two reviewers to 4/5 | MUST | done | frames (`evidence/shop/`, `shop/round2/`), measured text sizes | Round 1: A 4/3/3, B 4/3/3 (desktop/tablet/phone). Fixed: tab highlight after a resize, INCLUDES art inside its tile, side-card art left of the price, phone pass cards in the first view, text floor 14 rendered px (measured 13.6 and 11.6 before), VIP line. **Round 2: A 4/4/4, B 4/4/4.** Kept dissent: the struck "647" and "PREVIEW VALUE" are the weakest text; carousel dots are tiny; Brawler's thumb is dim on navy. |
| S-03 | Accessibility hooks | SHOULD | not done | none | Dropped for time (listed first to drop). |

### Module P

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| P-01 | Flicker zero, part counts, Downtown pad under the limit | MUST | done (draw calls not read) | solo Play scans with `OverlapScan` | Before: Worlds under the road 69 / 44 / 61 flicker pairs (cornices, corner pilasters, park path, court wall, GAP ground), pads 0 (Downtown). After: island 0, three pads 0, three Worlds 0 with the moving WorldLife figures left out (they overlap their own pieces while animating). Downtown pad 634 -> 595 parts. Draw calls and triangles not read (Render Stats did not open through the Studio MCP). The World scan covered the World folder present during a run, not exactly 2,000 studs. |
| P-02 | Budget note | SHOULD | done | `performance-budget.md` | |

### Module A

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| A-01 | Four videos with game audio + loudness | MUST | **blocked** | `videos/L-02-lap-pay-raceway-SILENT.mp4` (labelled silent) | Windows Application Control blocks `ProcessAudioCapture.exe`; ffmpeg sees only the microphone and AirPods, no loopback. No loudness measured. Next: Adam allows that exe or turns on Stereo Mix; then `Start-StudioClip.ps1` works. |
| A-02 | Reduce Motion stills | MUST | partial | `evidence/reduce-motion/` (Shop, Results, Lineup panel at phone frame) | With the override on, the three screens hold still with their information. Found and fixed: the phone Results card put Cash and RESPAWN under RETRY/HOME (`results-phone-BEFORE-fix.jpg`). Not captured: HUD at Heat Critical, the Keys capture. Transitions not recorded. |

### Modules H and F

| ID | What | Level | Status | Evidence | Notes |
|---|---|---|---|---|---|
| H-01 | Replacement map for Brian L | MUST | done | `beta-standins-for-brian-l.md` | |
| H-02 | Notes for Brian R | MUST | done | `lane3-round5-for-brian-r.md` | |
| H-03 | Decision 0039 | MUST | done | `vault/decisions/0039-lane3-round5-beta-loop.md` | |
| F-01 | check.ps1 exit 0 on both branches | MUST | done | code | Both exit 0. |
| F-02 | Commits, push, PR, beta-2 merged | MUST | done | code | See RESULT for the PR link. |
| F-03 | Merge to main only if every MUST passed | MUST | not merged | | A-01 blocked, A-02 and L-07 partial, S-01 art not uploaded. |
| F-04 | Publish to the private beta place | MUST | **not done** | | The session that started this round was told "No publishing, no Team Create edits (place 118605678346800)", and that is the Team Create place, which brief section 1 also forbids editing. A publish waits for Adam's direct go-ahead. |
| F-05 | Board and log | MUST | done | | |
| F-06 | RESULT.md | MUST | done | | |
