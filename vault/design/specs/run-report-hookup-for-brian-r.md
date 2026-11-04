---
title: Run report hookup - message for Brian R
date: 2026-11-03
tags:
  - lane1
  - lane2
  - economy
status: sent
---

# Run report hookup: message for Brian R (Lane 1)

From Brian L (Lane 2), written by Claude Code on 2026-11-03. Please answer in the Replies section at the bottom.

## What is ready on the server

The server side of the run report in [[0021-run-report-proposal]] (Agreed by Brian L and Adam on 2026-10-28) is built as a labelled PREVIEW on the branch `feature/lane2-economy-preview` (`src/server/EconomyPreview/Runs.luau`, remote names in `src/shared/Net/EconomyPreviewNet.luau`). It runs only in a place with the Workspace attribute `Lane2EconomyPreview = true` (Brian L's private copy of Car Hop Beta) and saves with ProfileStore.Mock only. It is tested there with scripted runs; no real run has called it yet.

What the server does with your events:
- **StartRun** checks the World is unlocked, makes the seed and rebuilds the traffic with your `Shared.Run.RunSequence`.
- **Hop** (`t`, `d`, `target`) is accepted when the target spawn exists and `RunSequence:alongAt(spawn, t)` is within 90 studs of `d`. `target = 0` means the road.
- **KeysComplete** (`t`, `index`) pays when the player is riding that index and has been aboard at least `RunConfig.KEYS_TIME[rarity]` minus 0.25 s. An unowned car is a claim, an owned car a Joyride (Cash plus one edition copy). Each spawn pays once.
- **RunEnd** (`t`, `d`) pays distance Milestones (every `RunConfig.MILESTONE_METRES`), capped at a distance reachable from the last checked position.
- Anything that fails a check is dropped and logged; the run keeps going and nobody is kicked.
- Times may run up to 3 s ahead of the server clock; at most 12 run messages a second; at most 64 events a batch.

Your traffic cars are placeholders (`Family_Rarity`). The server turns each spawn into one of Brian L's showroom cars for that World (`Catalog.CarWorld`), from the spawn's own index and paint number, so the result is the same everywhere. A third of Common spawns become Uncommon cars, because the run has no Uncommon tier yet.

## What we need from you (about four lines in `src/client/Run`)

1. When a run starts, call `ReplicatedStorage.EconomyPreviewNet.StartRun:InvokeServer(worldId)` (`"Downtown"`, `"DustyHighway"` or `"SummitPass"`). It returns `{ runId, seed }`, or nil if the World is locked. Build `RunSequence.new(seed)` and `RunReport.new(seed)` from that seed.
2. `report.Batch:Connect(function(events) RunEvents:FireServer(runId, events) end)`
3. `report.Urgent:Connect(function(event) KeysComplete:FireServer(runId, event) end)`
4. Optional: `RunGranted.OnClientEvent` tells the client what was paid (`kind` = Claim, Joyride or Milestone, plus `car` and amounts) for the "You got the Keys!" card and Results.

Nothing else in your run changes. Variants rolled by `RunSequence.variantFor` are not used by the economy: special editions are crafted from Joyride copies instead (`vault/design/specs/economy-v1.md` section 4).

## Questions for you

1. Is the 90-stud Hop reach and the 0.25 s Keys tolerance fair for your run, or should they be different?
2. Will Uncommon become a run rarity, or should the server keep turning some Commons into Uncommons?
3. Your run has no road coins yet. Are they still planned (outline section 06)?

## Replies

### Brian R

_(your answer here)_
