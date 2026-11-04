---
status: draft
owner: Adam (integration), for Brian L
date: 2026-11-03
---

# Car Hop Beta 3: everyone's work with your economy on

Adam asked for one combined beta that you can open, see working, and keep editing the economy on.

## What's in it
- **Lane 3 up to Round 4:**
  - Garage with 27 real cars and the edition ladder
  - RACEWAY FULL
  - 18 bays with the Expanded Paddock pass
  - Starter Pack with Brawler
  - Launch Pads and the Shop
- **Brian R:** his Stage 1 run (PR #3).
- **You:**
  - the 108 showroom cars
  - all of `feature/lane2-economy-preview`: the economy design, the preview, World unlocks, the Lineup picker, server-checked run payouts and the day cycle
- **Not in it:** Lane 3 Round 5, which is still being built.

Branch `integration/beta-3`, draft PR #12. It's never merged into `main`.

Place file on Adam's PC: `Car-Hop-Art\CarHop-Beta-3.rbxl`. It's a local copy with place ID 0, not the group's place. Your economy and the day cycle are already switched on in it.

## The switches
Two Workspace attributes turn your work on, as in your own copy:
- `Lane2EconomyPreview = true` turns on your economy.
- `Lane2DayCyclePreview = true` turns on your day cycle.

You no longer switch `Server.Beta.BetaServer` off by hand. It sees `Lane2EconomyPreview` and steps aside, so your preview is the only owner of saves, plots and purchases. Your `BetaCompat` still prints "the beta's own server is still on", because it checks `Disabled`. You can drop that warning: the beta server makes nothing in this mode.

A small bridge, `src/server/Beta/BetaEconomyBridge.luau`, answers the two beta remotes your preview doesn't:
- **`TutorialDone`:** kept for the session only. Your saves are Mock, so every Studio server is a first join.
- **`SetLineupSlot` (slot, carId):** passed to your `Economy.setLineupSlot`. Your Lineup is copied twice a second into the player attribute `BetaLineup`, which Lane 3's screens read. A nil carId (take a car out) is refused, because the preview has no remove yet.

With your economy on, the Cash counter on the HUD shows your server's `Cash` attribute and loses its PREVIEW tag (`src/client/Beta/BetaHome.client.luau`).

None of your files were changed. Without `Lane2EconomyPreview`, Beta 3 plays like Beta 2.

## Checked in Studio Play (2026-11-03, one player, Mock saves)
- **Economy on:**
  - Your preview started, gave plot 1 and paid Lap Pay.
  - `CarHopBetaNet` had all four remotes.
  - BuyParkingSpot through the beta's remote was refused at $60. After a Dev top-up it cost $500, and spots went from 2 to 3.
  - SetLineupSlot(1, "Putter") swapped the Lineup to "Putter,Rustbucket". Junk arguments changed nothing.
  - The HUD Cash showed $123K, matching your `Cash`. The day cycle reported "Day".
  - 134 of 134 art items loaded, and there were no script errors.
- **Economy off:** the beta server owned the plot, spawn and Lineup, and your preview stayed silent.

## Not checked
- Pressing the Raceway shop and parking sign by hand. The remotes were fired from a test script instead.
- A real run, two players, phones.
- The day cycle's night look in this place.
- The Raceway's bay visuals after the purchase.

## How to work on it
1. Run `git fetch`, then branch from `origin/integration/beta-3`, or merge it into your economy branch.
2. Run `rojo serve beta.project.json` and connect it to your private copy. `servePlaceIds` now allows unpublished local copies (place ID 0) as well as the group's place. Never sync into the group's Team Create place without Adam.
3. Keep your economy edits on your own branch. Adam merges them into the next beta.

## Open questions
- **Lane 3's Garage, Shop prices, Missions pay and Results** still show their own PREVIEW fixtures, not your save. Only Cash, plots, Raceway level, parking and the Lineup come from your server. What should Lane 3 read for owned cars, editions and prices: attributes, or a remote?
- **Expanded Paddock:** Lane 3 builds up to 18 bays, but your preview caps spots at 15.
