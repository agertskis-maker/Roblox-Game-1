---
title: Lane 3 Round 4 ledger
date: 2026-11-03
tags:
  - lane3
  - ledger
---

# Lane 3 Round 4 ledger

Brief: [[lane3-round4]] (source `Car-Hop-Art/review/round4/BRIEF-ROUND4.md`). Decision: [[0036-lane3-round4]]. Answers for Brian L: [[economy-v1-answers-from-adam]] (on `main`, 267a97b). Message for Brian R: [[lane3-round4-for-brian-r]].

Branches: `feature/lane3-round4` (worktree `Roblox-Game-1-round4`, from `main` 77154fa) and `integration/beta-2` (worktree `Roblox-Game-1-beta2`). Place: `Car-Hop-Art/CarHop-Beta-2-local.rbxl` (backup `CarHop-Beta-2-local.2026-11-03-before-round4.rbxl`), saved 08:33 and 08:37 after Studio checks. Evidence: `Car-Hop-Art/review/round4/evidence/`.

Evidence types (F-00): **code** = source change and `check.ps1`; **self-test** = a module's `selfTest()` run in Studio; **solo Play** = one client in Studio Play in the beta place, mock save (ProfileStore "Roblox API services unavailable"); **frame** = the game's live UI drawn in a Studio-only device frame (`Lane3ScreenProfile`: Desktop 1920x1080, Tablet 1180x820, PhoneLandscape 844x390 with its insets) inside a 1434x573 Studio viewport on the laptop. No two-client test ran.

| ID | What | Status | Evidence | Notes |
|---|---|---|---|---|
| R4-S01 | Read first | Done | this ledger, 0036 | No teammate has answered any `## Replies` section. Codex's uncommitted 0037 and 0012 read in Adam's checkouts |
| R4-S02 | Branch | Done (changed) | `feature/lane3-round4` from `main` | New worktree `Roblox-Game-1-round4`: `biground` and the main checkout hold Codex's uncommitted edits, so neither was switched |
| R4-S03 | Board claim on `main` | Done | 77154fa | Board change only |
| R4-S04 | Records | Done | brief copy, this ledger, 0036 reserved in `DECISION_NUMBERS.txt` | |
| R4-S05 | Places, backups, saves | Done | backup above; LastWriteTime 08:33:07, 08:37:03 | Saved with Ctrl+S only after confirming Studio was the foreground window in the same script |
| R4-S06 | Rojo | Changed | | `rojo serve` was not used: the Rojo plugin needs a click inside Studio. A local read-only tree server (`Car-Hop-Art/tools/treeserve.js`, port 35011) plus an Edit-mode pull updated only changed scripts; HttpEnabled was switched on only for the fetch and back off. Never the Team Create place |
| R4-S07 | Figma | Not done | | Designed straight in Studio (edition ladder, full parking state, loading count): no Figma session was opened in this round |
| R4-S08 | References | Partly | | Worked from the existing Garage and Shop look; R4-IMG files not opened |
| R4-NAME | Catch A Car! | Done for code | E05-dusty-pad-arrival, C09 frame | Loading wordmark and Launch Pad floor band now read CATCH A CAR!; no other player-facing title string or baked logo in Lane 3. Loading screen not captured |
| E-01 | Decision 0036 | Done | `vault/decisions/0036-lane3-round4.md` | |
| E-02 | Answers for Brian L on `main` | Done | 267a97b | Includes 4 questions on what the agreed fields mean |
| E-03 | Roster by World | Done | `RosterFixtures.selfTest(ReplicatedStorage.Cars)` PASS in Studio | Putter stays Downtown (E-03a). Look check: Rustbucket (cream, round, rusty) reads more like a classic tiny Italian city car than Putter (mint bubble); reported to Brian L, not swapped |
| E-04 | One roster fixture | Done | `src/shared/UI/RosterFixtures.luau` | Every Lane 3 car list reads it: Garage, cards, detail, Car stall, turntable, portal fixtures, tutorial, Missions, Welcome back, Results |
| E-05 | Real cars on every screen | Partly | E05 frames | Seen: Garage (desktop, tablet, phone), card detail, Car stall and pad (Dusty, phone). Code only: portal sign and Coach Roxy numbers, launch card, Results claimed cards, Missions, tutorial target, run nameplates (they show Brian R's run names). Not seen: portal signs, Peek, Results |
| E-06 | Edition ladder | Done | E06 frames | Normal 0, one short (Pizza Runner 24/25), just merged (Minnow), Gold to Diamond (Executive 12/25), Galaxy top. Phone shows names, next edition and copies without scrolling |
| E-07 | Big numbers | Done | `FormatTests.selfTest` PASS | Qa added; ShopMock, card Lap Pay and Style prices moved to `Format.cash`. CashLine's tip keeps exact dollars on purpose |
| E-08 | Economy v1 numbers | Done in code, partly seen | parking frames ($500, $1,500, $265M) | Raceway board and upgrade panel prices not captured |
| E-09 | Rider Level gate | Done | search: no Rider Level readout in Lane 3 | Deferred line on the board (`main`) |
| E-10 | Robux items consistent | Done | E10 frame | Respawn decided, "Keep your run going" line; Expanded Paddock one name; paid trails and paints no longer share a word with an edition. Not seen: the Results respawn line |
| E-11 | Done-when | Partly | | Format tests pass, answers on `main`, 0036 written. Stills at all three sizes exist only for the Garage and the Shop |
| C-01 | Flicker scan | Not done | | Not run this round |
| C-02 | Real claim with a driver | Not done | | No driver built. Recording a claim in the beta save would mean trusting a client claim (the run is client-only); left for Brian R and Brian L |
| C-03 | Get more spots, full state | Done (solo Play, phone frame for the Shop) | C03 frames | Expanded Paddock (asked by Adam on 2026-11-03): the pass gives 3 bays on top of the bought ones, up to 18, at the two ends of row A on a floor extension (no overlap, flush with the Paddock floor); the sign moves out; the card updates live (5 / 18 after the pass at 2) and tops out at RACEWAY FULL 18 / 18 with no offer. Pass ownership in the beta is a Studio-only switch (`CarHopBeta` attribute `PreviewExpandedPaddock`); the real Robux sale and ownership check are Brian L's. BUY pressed for real 2 -> 15 through the beta remote; 15 shows RACEWAY FULL 15 / 15, 15 bays (owned, not occupancy) and GET MORE SPOTS, which opened the Shop on Passes. The parking card itself has its own ScreenGui, so it draws at window size, not in the device frame. "Can't afford" needs a Cash source (`ShopPanel.cashOf`), which the beta has none of: built, not seen |
| C-04 | Settings | Done at phone frame | C04 frames | Replay tutorial now centred on the band; mutes, Reduce motion On/Off/Roblox, Haptics (disabled, "not available") pressed with no error. Desktop and tablet not captured |
| C-05 | Shop 4/5 | Round 1 of 3, target not met | C05 frames | Two fresh Sonnet reviewers. A: desktop 4/4/3, tablet 3/3/3, phone 3/3/3. B: desktop 4/4/3, tablet 3/3/3, phone 3/3/2. Both: Starter Pack, VIP and Expanded Paddock art suggest a car is included; tablet side-card prices cover their art; phone Passes prices cut off on the first view; small text under 14 px on phone. Fixed after review: FREE tab lit wrongly, duplicate PREVIEW line. Rounds 2 and 3 not run |
| C-06 | Preload | Done (warm cache) | Output lines | 134 known ids (images, kit meshes, 2 sounds), 8 s budget, count on screen, cars warmed afterwards. Ready in 4.48, 4.54, 4.11, 5.03 s with 134/134. The first run (before `car_detail` was typed as an image) gave 9.14 s ReadyBackground at 36/134. Before-times with the old 2-item manifest were not measured; the bad-id and delayed-callback tests were not run |
| C-07 | Pad performance | Not done | | |
| C-08 | Videos and loudness | Not done | | |
| C-09 | Launch Pad loose ends | Partly | C09 frame, Car stall frames | TRAILS opens the Garage's Customize at Trails (one screen); Dusty kiosks Cars and Trails opened; Car stall shows that World's 9 with the Loaner first. Not done: RETRY in Downtown and Dusty, orbit at zoom limit, F4 tuner, tree tops, 5x loop |
| C-10 | Park step through SetLineupSlot | Partly | `BetaLineup.selfTest` PASS; live remote test | Beta-only stand-in on `integration/beta-2` with the agreed name, arguments and checks; beta save gains only the agreed `Cars` and `Lineup`. No Lineup picker panel exists, so the tutorial's Park step stays skipped |
| C-11 | Reduce Motion | Not done | | The Settings switch works (C-04); the five screens were not filmed |
| C-12 | Not Lane 3's | Written | [[lane3-round4-for-brian-r]], answers file | |
| M-01 | Two clients | Blocked | | The Studio MCP `start_stop_play` has no client count; the Server & Clients mode needs a click in Studio. Exact clicks in RESULT |
| M-02 | Two-client checks | Blocked | | Needs M-01 |
| M-03 | Six clients | Blocked | | Needs M-01 |
| M-04 | Fix and report | Not reached | | |
| F-01 | check.ps1 | Done | exit 0 on both branches | |
| F-02 | Commits, PR | Done | see RESULT | Draft PR to `main`; `integration/beta-2` updated |
| F-03 | Merge into main | Not done | | Modules are not all done or honestly complete enough to merge; left for Adam |
| F-04 | Records | Done | board, log, this ledger, 0036 | |
| F-05 | RESULT.md | Done | `review/round4/RESULT.md` | |
