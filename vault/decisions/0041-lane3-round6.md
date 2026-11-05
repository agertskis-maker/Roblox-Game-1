---
title: "0041: Lane 3 Round 6: one run contract, World pay, lifetime Copies, a Robux pipeline with selling off, Missions on real events"
date: 2026-11-05
tags:
  - decision
  - lane3
  - beta
status: decided
---

# 0041: Lane 3 Round 6

Date: 2026-11-05. Owner: Adam (Lane 3, repository owner, beta integration person).
Status: decided by Adam (brief section 0, 2026-11-05). The build choices are Claude Code's under the brief's "your call" items and are listed in [[lane3-round6-ledger]].
Brief: `vault/design/specs/lane3-round6.md` (copy of `Car-Hop-Art/review/round6/BRIEF-ROUND6.md`). Ledger: [[lane3-round6-ledger]]. Handoffs: [[economy-preview-review-for-brian-l]], [[lane3-round6-for-brian-r]], [[robux-fields-for-brian-l]].

## Why this note is 0041, not 0040

The brief asks for "decision note 0040". `0040-beta-driving-update-stamina-shop.md` already used 0040 earlier the same day (the driving integration session). Decision numbers are never reused, so this round's note is 0041, reserved in `Car-Hop-Art/DECISION_NUMBERS.txt`.

## What Adam decided (brief section 0, summarised; the full text is in the brief copy)

1. Push every Lane 3 branch, merge PR #11 then PR #13 into `main` once each check passes, push the integration branches; integration branches and the Brians' branches are never merged into `main`.
2. Lane 3 code on `feature/lane3-round6` (from `main`); the beta on `integration/beta-4` (from `integration/beta-driving-update`).
3. One run contract: Brian L's remote names win (`StartRun`, `RunEvents`, `KeysComplete`, `RunGranted`). A beta-only shim keeps the old `Beta*` names for one round.
4. The beta adopts the candidate numbers as PREVIEW in `EconomyPreview` only: Lap Pay $10 / $25 / $60 / $150 / $400 by rarity, claim bonus 10x and Joyride Bonus 3x Lap Pay, World pay factor Downtown x1, Dusty Highway x40, Summit Pass x1,600.
5. `Copies` is the lifetime total; REMOVE in the Lineup leaves the spot empty.
6. The Robux pipeline is built with selling switched off in the published beta (`RealPurchases = false`). Two beta-only save fields: `Purchases` (receipt ids, newest 200) and `Owned`.
7. Creating the products under LEGION STUDI0S is approved.
8. Looks are the headline: Raceway, parking, and a "cooler everywhere" pass.
9. Missions count real events. No streaks, timers, limited-time offers, or loss for stopping.
10. Stunt Circuit screens against Brian R's Circuit or a fixture with the same event names. No cross-server leaderboard.
11. Release checklist and assets. No public publish, no audience, age rating or public-setting change.
12. Publish `integration/beta-4` to the private "Car Hop Beta" place 118605678346800 from a local file at the end.
13. Not this round: real sales, a public publish, the Brians' files, cross-server data, trading, a new currency, any other save field.

## Choices made under "your call" (details and reasons in the ledger)

- **Product kinds.** Respawn, the five Cash packs, the Starter Pack and the All Passes Bundle are Developer Products. Double Lap Pay, Expanded Paddock, VIP and the four Robux trails are Game Passes. The bundle is a Developer Product that writes the three pass ids into `Owned`, and ownership is "owns the Game Pass OR has it in `Owned`" (the brief's rule).
- **Products are created OFF SALE.** Something on sale can be bought from the experience's store page or Roblox's own in-game menus even while the beta's buttons say "Coming soon", so the products start off sale. Adam turns sales on later, together with `RealPurchases`.
- **A respawn that arrives after the run ended** pays Cash equal to that run's Results total, so a payment is never taken for nothing.
- **A second Starter Pack receipt** grants one Brawler copy and the $5,000 again rather than nothing (it should never be prompted twice; a receipt can still arrive).
- **The lifetime Copies conversion marker** lives in ProfileStore's `RobloxMetaData` (`CarHopBetaCopiesLifetime = true`), not in the save data, so no new save field is added.
- **Missions keep no save field.** Saved-fact missions read the save; "this visit" counts start at 0 on a rejoin; a finished, unclaimed mission is paid into the save when the player leaves. A `Missions` field is proposed to Brian L, not added.
- **The Stunt Circuit lap is server-timed** from the client's event names only; the board covers this server only and pays nothing.
- **Parking tiers break at 5, 9 and 13 spots,** plus the Expanded Paddock at 16 to 18. Tier 4's "turntable" is a raised STAR CAR podium, because a spinning car would fight the Lineup's lap animation.

## What this note does not decide

Real prices, real Lap Pay, the real `Missions` field and the real run remotes are Brian L's; the Circuit events are Brian R's. Each stand-in carries the three-line BETA-ONLY header and is deleted when the real module lands.
