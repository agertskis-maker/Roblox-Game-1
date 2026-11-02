---
title: Island walking speed - message for Brian R
tags:
  - design
  - island
  - movement
  - lane1
  - lane3
status: sent
---

# Island walking speed: message for Brian R (Lane 1)

From Adam (Lane 3), sent through the vault on 2026-10-29. Written by Claude Code from Adam's Raceway round 2 brief (`vault/design/specs/raceway-round2.md`, Part 6, on the branch `feature/lane3-speedway-upgrades`). Nothing in your code was changed. Please answer in the Replies section at the bottom (you or your AI).


> [!info] Beta note (2026-10-31)
> Adam published a one-place beta, **Car Hop Beta** (LEGION STUDI0S, private), from the branch `integration/beta-1` (draft PR #7, decision [[0030-car-hop-beta-1]]). It merges your PR #3 into that branch only (not into `main`), with one fix in `RunFx.luau` (`self` renamed `_self`, the Selene warning that fails your check). Walking into an island portal starts your `RunController` (profile "Circuit"); your Retry returns the player to the island. While the run is on, `MovementSpeedOwner = "CarHopBetaRun"` holds the island speed. Please replace `src/client/Beta/BetaRun.client.luau` with your real "entered a run" signal when you have it, and merge PR #3 when you are happy with it.

## What Adam decided
- On the **home island** every player walks at **WalkSpeed 32** (twice Roblox's 16), because the island is big.
- The avenue **boost lanes** stay and multiply that base: **32 x 1.5 = 48**, applied once (never stacking across lanes or re-entries).
- **In a run or through a portal, your run's own speed rules apply.** The island gives the speed back when the player leaves for a run and restores 32 when they come back.

## What Lane 3 checked in your code
On `origin/feature/lane1-run-prototype` (read only, `git grep`): nothing reads or writes `WalkSpeed`, `JumpPower` or `MovementSpeedOwner`; the run anchors the HumanoidRootPart while riding. So your run does **not** depend on WalkSpeed being 16, and nothing needs to change on your side for the faster island walk.

## The handover contract we need from you (proposal)
There is no agreed "this player is in a run" signal yet, so Lane 3 uses the existing takeover attribute from the walking boost (spec `vault/design/specs/walk-boost.md`, "Takeover path"):

1. **When your run (or anything else) takes over movement, set the LocalPlayer attribute `MovementSpeedOwner` to your system's name** (any non-empty string), **before** you write WalkSpeed. The island then clears its boost, writes back the WalkSpeed the player had before the island (normally 16) if it still holds its own 32, and stops writing entirely. It never writes over your value while the attribute is set.
2. **When the player is back on the island, remove the attribute.** The island applies 32 once again.
3. If you would rather own island walking too, the island base has its own switch (`WalkBoost.ISLAND_BASE_ENABLED`, or the LocalPlayer attribute `Lane3IslandBaseEnabled = false`); the boost lanes then multiply whatever base you set.

Until you send the real signal, the island preview demonstrates the handover with a **labelled Studio-only fixture** (`src/client/Home/Island/RunModeFixture.client.luau`): it sets `MovementSpeedOwner = "Lane3RunFixture"` while the player stands in a World portal's field and removes it when they step back out. It never runs in a live game.

## Questions for you
1. Is the LocalPlayer attribute `MovementSpeedOwner` acceptable as the run-entry signal, or do you want a different one (a Signal module, a server attribute)? Lane 3 will follow yours.
2. Does a run start on the island place (the player stays in this server) or in another place (a teleport)? If it is a teleport, the island only needs to restore 32 on arrival, which it already does.
3. Any concern with players arriving at a portal at 32, or at 48 if they come straight off a boost lane? Jump power and the camera are unchanged.
4. Do you want a server-side check on island walking speed? Lane 3 assumes not: it is the player's own walking, with no economy or saved state.

## Replies

### Brian R

_(your answer here)_
