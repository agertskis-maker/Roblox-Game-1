---
title: "0042: Lane 3 Round 7: home at your Raceway, the two-press Hop, luck, real cosmetics, richer Launch Pads"
date: 2026-11-05
tags:
  - decision
  - lane3
  - beta
status: decided
---

# 0042: Lane 3 Round 7

Date: 2026-11-05. Owner: Adam (Lane 3, repository owner, beta integration person).
Status: decided by Adam (brief section 0, 2026-11-05). The build choices are Claude Code's under the brief's SHOULD, MAY and "your call" items and are listed in [[lane3-round7-ledger]].
Brief: `vault/design/specs/lane3-round7.md` (copy of `Car-Hop-Art/review/round7/BRIEF-ROUND7.md`). Ledger: [[lane3-round7-ledger]]. Handoffs: [[lane3-round7-for-brian-r]], [[lane3-round7-for-brian-l]].

## What Adam decided (section 0)

1. **Every lane is open this round.** Brian R agreed. Run changes go on `feature/lane1-round7-from-adam` (from `feature/lane1-run-prototype`) as a pull request into his branch, never merged by this round. Brian L's car models may be edited to make paint work, each edit listed for him.
2. **Push everything and merge PR #15** once its check passes.
3. **Branches:** `feature/lane3-round7` from main, `integration/beta-5` from `integration/beta-4`.
4. **Home is your Raceway.** You spawn at your own plot's entrance, and every run ends back there.
5. **The Stunt Circuit is "Coming soon".** Its board becomes RICHEST RACERS (this server's players only).
6. **World unlocks:** 5 Downtown cars and $5M open Dusty Highway; 5 Dusty Highway cars and $1B open Summit Pass. The server checks both and spends the Cash.
7. **Coach Roxy's new look** (portrait from R7-IMG-01, uploaded once uploads are allowed).
8. **The two-press Hop:** press to leap, press again to dive.
9. **Stamina** as decision 0040 set it, and a bump costs 1 bolt.
10. **Luck:** 5 levels, x1.25 / x1.5 / x2 / x3 / x4, prices $100K / $1M / $10M / $100M / $1B (PREVIEW).
11. **Offline earnings:** 40% of Lap Pay for up to 24 hours (VIP 30 hours), and the money must really land in Cash.
12. **VIP:** a VIP trail, a gold name tag, VIP paints and 30 hours of offline earnings. No lounge.
13. **No free respawn.** Only the 19 Robux respawn remains (Coming soon while selling is off).
14. **One Style Shop** per Launch Pad with Paint, Decals, Wheels and Trails, shown on the car you drive.
15. **No editions ladder** in the Garage Index.
16. **Road cars are one size,** 1.25 times the old Normal.
17. **`RealPurchases` stays false.**
18. **Publish** to the private Car Hop Beta place 118605678346800 from the local beta file.
19. **Not this round:** the brief's section 15 list.

## Why the main build choices were made

- **Luck is a probability modifier bought with Cash, and Cash can be bought with Robux.** Roblox's paid random items policy therefore applies. The Lucky Clover panel shows the real odds, now and after, from the same `src/shared/Run/Luck` module the server uses. The server checks `PolicyService` and refuses luck to accounts that may not buy paid random items; their panel says "Not available for your account" (R7-S09).
- **Paint only on paint:** a game script may not set a SurfaceAppearance colour map, so paint is a 2% transparent copy of the body mesh with an EditableImage texture drawn from per-car masks. See the ledger's C-02 notes for the cars where this is imperfect.
- **The World under the road repeats in laps** (R-08). Lap k is the same World built again k route-lengths further on, made in the background and freed when passed. One very long route was rejected because planning the whole route up front would slow every join.
- **Beta glue stays on the integration branch.** Files that need the beta's server modules (Pit Stop and Lucky Clover panels, StyleState, Style Studio, Launch Pad init, Circuit and RICHEST RACERS scripts, SpeedwayLooks) stay on `integration/beta-5`, as in Round 6. `feature/lane3-round7` carries the Lane 3 files that stand on their own.
- **Missions:** 45 in five tabs, with no timers, streaks or daily resets. Counted missions start again on a rejoin until a `Missions` save field is agreed with Brian L.
