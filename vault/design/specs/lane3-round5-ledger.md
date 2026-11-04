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

(Module rows follow.)
