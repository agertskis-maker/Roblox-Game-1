---
title: "0030: Car Hop Beta 1: one place that joins the island, the Raceway, the HUD and Brian R's run"
date: 2026-10-31
tags:
  - decision
  - beta
  - integration
status: accepted
---

# 0030: Car Hop Beta 1

> [!note] Approved by Adam (repository owner), 2026-10-31
> "merge whatever u need and continue with all of ur reccomendations, hold it in one place, it can save it deosnt need to be a real fully working version yet it can have some aspects missing, ill connect the code, yes create and publish it when its ready." Written by Claude Code. Number reserved in `Car-Hop-Art/DECISION_NUMBERS.txt`.

## Decided (Adam)
- **Lane 3's work is merged into `main`**: PRs #2 (HUD and Downtown), #5 (Dusty Highway and Summit Pass) and #4 (island and Raceway) through PR #6, after the GitHub check passed.
- **One place**: the island hub and the runs live in a single place. No teleports between places.
- **The beta may save**, and may have parts missing.
- **Adam is the integration person**: he connects the code to the beta place.
- **The beta experience is created and published** under the group LEGION STUDI0S when ready.

## What Beta 1 is
- **Branch** `integration/beta-1`: `main`, plus Brian R's PR #3 (merged into this branch only; PR #3 stays his to merge into `main`), plus the beta glue below.
- **Project file** `beta.project.json`: the normal game tree, plus the switch `ReplicatedStorage.CarHopBeta` and the island builder in `ServerStorage.Island`. `default.project.json` is unchanged, so every beta script is off in the team's normal game.
- **Place**: built from `beta.project.json`, then the island is built once in edit mode (`EnvironmentBuild.build({ preset = "ClearAlpine", seed = 20261021 })`) and saved into the place.

## Beta glue (Claude, reversible; stand-ins for Lane 2 and Lane 1 contracts)
1. **Saving**: `src/server/Beta/BetaData` is the only profile owner: ProfileStore store `CarHopBeta1`, template `{ RacewayLevel = 1, ParkingSpots = 2 }`, the AGENTS.md lifecycle. It is a beta-only store, so the real game's saves start clean. Brian L's real save layout replaces it.
2. **Plots**: `BetaPlots` gives each player the lowest free plot. It sets the plot attributes the Raceway looks already read (`Owner`, `OwnerDisplayName`, `SpeedwayLevel`, `ParkingSpots`) and the player attribute `HomePlot`.
3. **Purchases are free**: two RemoteEvents in `ReplicatedStorage.CarHopBetaNet` (`BuyRacewayLevel`, `BuyParkingSpot`). They take no arguments. The server checks for a loaded save and a plot, the limits (level 12, 15 spots) and a 0.75 s cooldown, then raises the saved number by one. There is no Cash, because the economy is Brian L's and propose-first. The panels still say "PRICE: SET BY ECONOMY".
4. **Portals start runs**: `src/client/Beta/BetaRun` starts Brian R's `RunController` (profile "Circuit", the one he plays) when the player walks into an open portal field. His controller drives Lane 3's RunHud. The results screen's **Retry** returns the player to the island in front of that portal. The run takes walking speed through `MovementSpeedOwner = "CarHopBetaRun"`.
5. **All three portals are open** in the beta (`PortalPreviewState`). Normally only Downtown starts open.
6. **Studio-only tools are off in the beta**: the Raceway preview panel and the run fixture.
7. **One edit in Brian R's file, on this branch only**: `RunFx.sound` parameter `self` renamed `_self` (a Selene unused-variable warning that fails his PR #3 check).

## Missing on purpose (Beta 1)
- The road is Brian R's test canyon in every World. The Downtown B, Dusty Highway and Summit Pass scenery is not under the road yet: it needs the lane and road contract with Brian R.
- Nothing from a run is saved: no Cash, no cars caught, no Rider Level.
- The cars are Brian R's placeholder families. No finished car models exist yet in `assets/cars` (Brian L).
- The results screen says "Retry", but it returns the player to the island.
- The real unlock rules, prices and Lap Pay are not used.

## Consequences
- Brian L replaces `BetaData`, `BetaShop` and the save fields with his contracts. Brian R replaces `BetaRun` with his real "a player entered a run" signal.
- To rebuild the place: `rojo build beta.project.json -o CarHop-Beta-1.rbxl`, then run the island build in edit mode. A Rojo connection (`rojo serve beta.project.json`) keeps the code current.
