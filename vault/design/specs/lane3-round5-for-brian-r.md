---
title: Lane 3 Round 5, for Brian R
date: 2026-11-03
tags:
  - lane1
  - lane3
---

# Lane 3 Round 5: notes for Brian R

From Adam (Lane 3, beta integration person), written with Claude Code on 2026-11-03. **Nothing here changes your files** (`src/client/Run`, `src/shared/Run` were read only). Each item is for you to accept, change or ignore. Decision [[0039-lane3-round5-beta-loop]].

## 1. The beta run bridge (your run now pays in the beta)

`src/client/Beta/BetaRun.client.luau` (beta-only) connects to the two signals your `RunReport` already has "for whoever wires them". It never changes the run.

- **Start.** Before `RunController.new`, the beta asks the server `BetaRunStart(worldId, startCarId?)` and gets `{ runId, seed }`. The seed goes into `RunController.new({ session, profile = "Circuit", seed = seed })`, so the server can rebuild your traffic with `RunSequence.new(seed, RunConfig.profile("Circuit"))` and look up a spawn by index (as note 0021 says). With no answer the run still plays, unpaid.
- **During.** `run._report.Batch` -> `BetaRunEvents(runId, batch)` (your events exactly: `kind`, `t`, `d`, `x`, `target`, `index`, `cause`, rounded as `RunReport.push` rounds them). `run._report.Urgent` (KeysComplete) -> `BetaKeysComplete(runId, index, betaModel)` at once.
- **End.** When the player presses Retry or Home: `BetaRunEnd(runId, cause)` with your `cause` text.
- **Reading private fields.** The bridge reads `run._report` and `run._sequence` (for the beta-only `betaModel`). If you would rather expose them, a public `run.Report` (the RunReport) would let the bridge stop reaching into the table; nothing else is needed.

Your real run can send the same payloads through Brian L's remotes and the beta bridge goes away.

## 2. `betaModel` (disappears once the server owns the sequence)

Your spawns are placeholder families (`Family_Rarity`); the save holds Brian L's 27 showroom cars. The beta maps a spawn to a car of the run's World in `src/shared/Beta/BetaRunMap.luau` (by rarity and a hash of the family, the same on both sides; Common spawns split between Common and Uncommon cars; a World's Loaner is never a catch). The client adds that name as `betaModel`; the server computes the same name from its own copy of the sequence and drops the claim if they differ. When your run spawns real cars (or Brian L's Catalog names them), `betaModel` and `BetaRunMap` are deleted.

## 3. What the tests saw of the run

- The beta's caps (decision 0039) never dropped an honest event in the autopilot runs or the multi-client suites: `d` stayed under your profile's speed curve plus 1,500 studs, and no batch had more than 30 events.
- `KeysComplete` can come for the car the run starts in (the first ridden spawn), so the first Joyride of a run is often the start car. That is fine for the beta; say if it is not meant to report.
- A crash cause can be a long sentence ("Crashed into a BIG Common Pickup"); the beta keeps up to 60 characters in its log.
- A Studio-only test driver now exists in the beta glue (`PlayerGui.CarHopBetaControl:Invoke("autopilot", true)`), written from the rule in your `RunPlayground` driver; your file is unchanged.

## 4. Still open from Round 4 (not changed this round)

1. The floating car labels piling up at the horizon.
2. The "Lane 1 run prototype - stand-in cars and labels - nothing is saved" line on screen. In the beta the run now IS saved (claims, Cash), so that line reads wrong to a tester; could it hide when `ReplicatedStorage.CarHopBeta` exists?
3. The crash at about 50 m when nobody steers (seen again: 46 m and 64 m runs on 2026-11-03 in the beta log).

## Replies

### Brian R

_(your answer here)_
