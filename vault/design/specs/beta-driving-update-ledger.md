---
title: Beta driving update, ledger
date: 2026-11-05
tags:
  - lane3
  - beta
---

# Beta driving update: ledger

Adam with Claude Code, 2026-11-05. Decision [[0040-beta-driving-update-stamina-shop]]. Branch `integration/beta-driving-update` = `integration/beta-2` + Brian R's `38e7995` + this work. Published to the private Car Hop Beta (place 118605678346800) on 2026-11-05 at 17:22 UTC.

## Choices Claude made (reversible)

| Choice | Why |
|---|---|
| Re-created the branch from `integration/beta-2` after first starting from beta-3 | the parent session's correction: beta-2 has Round 5 and the bridge |
| Gate off by session level 999 plus hidden labels | no edit to Brian R's files; his largest need is 208 |
| Stamina tiers: yellow 1, red 2, purple 3 hops per bolt, 5 slots | 15 hops fit in 5 slots (Adam's idea) |
| Prices 1K to 20M, about x3 a step | exponential and between the Downtown and Summit numbers ([[stamina-shop-for-brian-l]]) |
| STAMINA kiosk on each Launch Pad between PAINT and TRAILS, kiosks re-spaced 36 degrees, CARS mirrored to PAINT | Adam: in the hubs, not awkward |
| The lightning bolt follows the game icon's outline, built from 3D triangles | Adam: a real lightning bolt |
| Raceway cars: look along the path's travel, pivot on the track | a RealCar's front is -Z and its pivot is at the bottom |
| Portal return: raycast to the real floor | the field's bottom edge is about 3 studs under the plaza |
| Tutorial ground arrow hides within 14 studs of its target (the glow stays) | prompts open at 10 studs; the arrow sat over them |
| Locked-portal card: walking away also clears the live card's suppression | after one GOT IT, the UNLOCK card never came back that session |
| Road cars dressed as Brian L's cars inside Brian R's models | no edit to his files; the car shown is the car paid |
| Rojo on port 34873 from the worktree, `servePlaceIds` gains 0 | the old Rojo on 34872 served another branch; a local file has place ID 0 |

## Tests

| Test | Result | How |
|---|---|---|
| `scripts/check.ps1` (strict, Selene, StyLua, Rojo build) | PASS | local build |
| Brian R's commit vs the bridge (report fields, sequence) | no mismatch | code inspection |
| Downtown runs: steer, hop, claims, joyrides, milestones paid | PASS | Studio runtime |
| Run out of bolts (OUT OF BOLTS) and overheat (Meltdown) | PASS | Studio runtime |
| Keys capture circle fills and claims | PASS | Studio runtime |
| Dusty Highway: real unlock (5 cars, $5M), run, claim paid | PASS | Studio runtime |
| Summit Pass run | NOT RUN | needs 5 Dusty cars incl. an Epic or Legendary catch; the cheat only gives Cash |
| Stamina Shop: buy levels, NEED $X MORE, run board tiers | PASS | Studio runtime, visual |
| Tutorial: run, claim, HOME, Park step (arrow hides, Park Cars opens, parks), You're Ready | PASS | Studio runtime, visual |
| Raceway cars face forward and sit on the track | PASS | Studio runtime, visual |
| Portal return stands on the floor (root 3.23 over floor 0.08) | PASS | Studio runtime |
| HOME portal faces the pad centre | PASS | Studio runtime, visual |
| Road cars are Brian L's (24 of 24), names on tags and pop-ups | PASS | Studio runtime, visual |
| Rider Level and Needs labels hidden | PASS | Studio runtime |
| Self-tests (BetaShop stamina checks) | written; not re-run | MCP cannot call the self-test BindableFunction in this Studio |
| Multi-client "two" (2 players, one leaves mid-run) | 16/16 PASS | multi-client plugin |
| Multi-client "rejoin" (synthetic same-profile rejoin) | 10/10 PASS | multi-client plugin, 1 client |
| Phone landscape and PC size | Lane 3 UI fits; Results card fits when opened at phone size | Studio emulation (Brian R's overlay is not emulated) |
| Frame rate | 59 to 60 fps in Studio, 24 real cars | Studio runtime (not a phone) |
| Output | no errors; only the old `203785492` asset-type warning | Studio runtime |
| Live game after the first publish | **FAIL**: no World scenery beside the road; `BetaMultiTestClient` error on join | Adam played; Roblox player log |
| Live game after the fix and republish (18:53 UTC) | PASS: city beside the road (Adam), no scenery or helper errors, What's new beta-4.0 | Adam played; Roblox player log |

## Republish, 2026-11-05 18:53 UTC

The run's World scenery (`src/lookdev/Downtown/City`) asserted `RunService:IsStudio()`, so every live run had an empty road; Studio tests could never show it. The embedded preview city (`preview = true`, used by RunScenery) now builds in live games; the command-bar harness stays Studio-only. `BetaMultiTestClient` now asks for `StudioTestService` after its Studio check. What's new shows beta-4.0. Still seen in the live log: the two Shop pass images `rbxasset://carhop/art_pass_starter.png` and `art_pass_paddock.png` are local files, so they are blank in the live game until uploaded (a Round 5 open item).
