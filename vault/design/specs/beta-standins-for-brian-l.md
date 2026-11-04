---
title: Beta stand-ins, the replacement map for Brian L
tags:
  - lane2
  - lane3
  - beta
  - handoff
---

# Beta stand-ins: what your server replaces, one for one

From Adam (Lane 3, beta integration person), written with Claude Code, 2026-11-03. Decision [[0039-lane3-round5-beta-loop]]; the state on paper is the first table of [[lane3-round5-ledger]].

In Round 5 the private beta (`beta.project.json`, branch `integration/beta-2`) got stand-in server code for the rest of the agreed contract, so the three of us can play the whole loop: portal, run, claim, Garage, park, Lap Pay, buy a level or a spot, unlock a World. Every stand-in lives in `src/server/Beta` or `src/shared/Beta`, which only the beta loads. **Nothing here touches your files** (`src/server` outside `Beta`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars`). The function names follow your `feature/lane2-economy-preview` branch (addCash, trySpend, lapPayFor, lineupPayPerLap, payOffline, the Lap signal) so your modules drop in.

## The replacement map

Direction: C->S is a client request, S->C a server message. Every argument is checked as hostile; the player is always the sender, never an argument. Attributes are written by the server only.

| Stand-in file | Agreed contract it implements | Fields and attributes it touches | Client code that calls or reads it | What your module must keep identical | Delete |
|---|---|---|---|---|---|
| `src/server/Beta/BetaData.luau` | the ProfileStore lifecycle (AGENTS.md) with the agreed fields `Cash`, `Cars`, `Lineup`, `RacewayLevel`, `ParkingSpots`, `WorldsUnlocked`, `LastSeen` (+ the beta's own `TutorialDone`) | store `CarHopBeta1`; repairs wrong-typed values after Reconcile; stamps `LastSeen` on leave | none directly | the field names and types; `LastSeen` in Unix seconds, 0 = never | all of it once your Data module runs the beta |
| `src/server/Beta/BetaEconomy.luau` | Cash and car grants | `Cash`, `Cars`; Player attributes `BetaCash` (number), `BetaCars` ("id:edition:copies,..."), `BetaWorldsUnlocked` ("Downtown,DustyHighway"), `BetaWelcomeAmount`, `BetaWelcomeSeconds` | `src/shared/UI/LiveData.luau` reads every attribute; HomeShell (Cash, Garage, Welcome back), RunHud, ShopPanel, LineupPanel, LaunchPad (Results, Coach Roxy) | the attribute names and formats, or change them in `LiveData.Attributes` in one place | `BetaGrantCash` (Studio cheat) and `FreePurchases` (test switch) |
| `src/server/Beta/BetaLapPay.luau` | Lap Pay on a server timer, paid while the owner is in the server | `Cash`; plot `BetaLapEpoch` (server time), `BetaLapSeconds`; S->C `BetaLapPaid(plotIndex: number, slot: number, carId: string, amount: number, newCash: number?)` to every client, `newCash` only to the owner | `RacewayLineup.client.luau` (cars drive on `LapClock`, the "+$" pop), `SpeedwayLooks` (crowd, flag, sound), the tutorial's Park step | the schedule rule in `src/shared/UI/LapClock.luau` (slot s crosses at epoch + offset(s) + k * lap), so the car on screen crosses when you pay; one payout per slot per lap; nothing paid for a swap | the stand-in; keep `LapClock` or replace it in both places |
| `src/server/Beta/BetaRun.luau` | note 0021 run report (Agreed 2026-10-28) | `Cash`, `Cars`, `Lineup` (auto-park); C->S `BetaRunStart(worldId: string, startCarId: string?) -> { runId: string, seed: number }?` (RemoteFunction), `BetaRunEvents(runId: string, events: { { kind, t, d, x?, target?, index?, cause? } })`, `BetaKeysComplete(runId: string, spawnIndex: number, betaModel: string?)`, `BetaRunEnd(runId: string, cause: string)`; S->C `BetaRunGranted(runId, { kind = "claim" or "joyride" or "milestone", carId?, amount, newCash, parked?, edition?, copies?, rose?, index? })`, `BetaRunResults(runId, totals)` | `src/client/Beta/BetaRun.client.luau` (the bridge on Brian R's RunReport signals), LaunchPad's Results card (`runTally`) | the 0021 field names (`t`, `d`, `x`, `target`, `index`, `cause`); claim vs Joyride decided on the server; a repeated spawn grants nothing; a late `BetaRunEnd` gets the same totals | **`betaModel`** (beta-only; your server has `RunSequence`), the client-trusted caps, `src/shared/Beta/BetaRunMap.luau` (placeholder families -> showroom cars) |
| `src/server/Beta/BetaShop.luau` | `BuyRacewayLevel()`, `BuyParkingSpot()`, `UnlockWorld(worldId: string)`, plus the beta's `TutorialDone()` | `Cash`, `RacewayLevel`, `ParkingSpots`, `WorldsUnlocked`; S->C `BetaResult(what: string, ok: boolean, reason: string?, missing: number?)` after every purchase or Lineup request | Raceway panels (`SpeedwayLooks` buy), LineupPanel (BUY a spot), LaunchPad (Coach Roxy's UNLOCK, refusal toasts) | no arguments for the two buys; the server prices; a refusal names the missing Cash; a retry of an owned unlock is not charged | the stand-in; `BetaResult` can become your own reply event (change `LiveData.Remotes.Result`) |
| `src/server/Beta/BetaLineup.luau` | `SetLineupSlot(slot: number, carId: string?)` | `Lineup`; Player `BetaLineup` ("Putter,Minnow") | LineupPanel, Garage PARK, the tutorial Park step | the Lineup stays dense (no holes); nil removes and the cars behind move up; a refusal changes nothing | the stand-in; auto-park on a claim moves into your claim code |
| `src/server/Beta/BetaPlots.luau` (Round 1) | plot assignment | plot `Owner`, `OwnerDisplayName`, `SpeedwayLevel`, `ParkingSpots`, `ExpandedPaddock`; Player `HomePlot`, `BetaNoPlot` | every Raceway look, RacewayLineup, LineupPanel | the plot attribute names | the stand-in |
| `src/server/Beta/BetaMultiTest.server.luau`, `src/client/Beta/BetaMultiTestClient.client.luau` | nothing (a Studio test harness) | test-only `BetaTestAck`, `BetaTestCmd`; Mock store; `BetaData.setNextJoinKey` | the local plugin `Car-Hop-Art/tools/multitest-plugin.lua` | nothing | all of it, with the beta |

Nil and removal: `SetLineupSlot(slot, nil)` removes; a missing attribute means "not loaded yet" on the client (screens keep their PREVIEW fixture). Timing: attributes replicate within a frame or two of the change; `BetaLapPaid` fires at the payout boundary. Idempotency: run grants are keyed by spawn index per run; the tutorial bonus by the `TutorialDone` false -> true change; the Welcome back credit is paid once per load with `LastSeen` stamped in the same step. Failure messages are short sentences for children ("Not enough Cash.", "Get more spots first.").

## Removable scaffolding, in one list

- `betaModel` on `BetaKeysComplete` and `src/shared/Beta/BetaRunMap.luau`.
- The client-trusted run report and its caps (decision 0039 lists the values).
- The test harness (`BetaMultiTest*`, the plugin) and the Studio-only `BetaGrantCash`, `FreePurchases`, `CarHopBetaSelfTest`.
- Every number: they come from `src/shared/UI/EconomyPreview.luau` (PREVIEW), which your Catalog replaces in one place.

## Still unanswered from the Round 4 answers file (economy-v1-answers-from-adam.md)

The four questions on what the agreed fields mean are copied here so they are in one place; please answer in either file.

1. **`Edition`:** Lane 3 reads it as 1 to 5 in the order Normal, Gold, Diamond, Rainbow, Galaxy. Is that right, or is it 0-based or a name?
2. **`Copies`:** the copies held at the current edition (starting again at 0 after each step), or the lifetime total? Round 5 note: your preview branch (a433e5c) now has the ladder 25 / 250 / 2,500 / 25,000 as lifetime totals; the beta uses those numbers as the step AT each edition with Copies starting again at 0, as the Round 5 brief says. Say which reading wins and Lane 3 changes `EconomyPreview.addCopy` and the Garage's progress line in one place.
3. **`Lineup`:** can it have gaps (slot 3 filled, slot 2 empty)? Correction to the Round 4 file: the beta's `SetLineupSlot` does **not** allow a gap (a saved array with holes does not survive the DataStore); `carId = nil` takes the car out and the cars behind move up.
4. **Largest Cash value:** what is the cap? Lane 3's display handles up to 999 Qa exactly and then shows whole Qa, but Luau numbers stop being exact at about 9 Qa.

Also still open from that file: Brawler in the Starter Pack (decision 0038) changes your "cars are never sold" rule; do you agree?

The beta modules are scaffolding so the team can play; your server replaces them one for one. Nothing in them is a design decision you have to keep except the agreed contract.

## Replies

### Brian L

_(your answer here)_
