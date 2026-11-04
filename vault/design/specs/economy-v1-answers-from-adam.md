---
title: Economy v1, Adam's answers
date: 2026-11-03
tags:
  - design
  - economy
  - lane2
  - lane3
status: answers
owner: Adam (Lane 3, repository owner), for Brian L (Lane 2)
---

# Economy v1: Adam's answers

For Brian L. These answer `vault/design/specs/economy-v1.md` (on `feature/lane2-economy-design`), sections 11, 12 and 13, in the same order. Adam decided on 2026-11-02; items in section 12 marked "delegated" were chosen by Claude under Adam's delegation. Full record: decision 0036 (`vault/decisions/0036-lane3-round4.md`, on `feature/lane3-round4`).

Lane 3 now shows every economy v1 number as PREVIEW from one module, `src/shared/UI/EconomyPreview.luau`, and the car list from `src/shared/UI/RosterFixtures.luau`. When your Catalog and server exist, each one is replaced in one place, and your values win.

## Section 11: Fair for kids

1. **No daily streaks, no limited-time offers, no countdown pressure, no paid random rolls.** Agreed. Lane 3 has none.
2. **Editions and cars are never sold for Robux.** Agreed, with one exception Adam decided on 2026-11-03 (decision 0038, on `feature/lane3-round4`): the Starter Pack includes one Rare car, **Brawler**, one per player, so its car art is true. Editions are still never sold and no other car is sold. This changes your rule, so please answer under Replies whether you agree.
   **Game passes (Double Lap Pay, Expanded Paddock, VIP).** In the launch scope (Adam, item 4 below). Lane 3 shows PREVIEW prices; the real prices and a current Roblox policy check are still needed before anything is sold.
3. **Nothing is ever lost.** Agreed.
4. **The 19 Robux respawn.** Decided by Adam: "we definitely are going to have the 19 Robux respawn, and we're going to have all the Robux purchases. That's non-negotiable." The respawn and every planned Robux purchase are in the launch scope. This replaces the recommendation in this section, the outline's "No Developer Products (Cash packs) at launch", and, for the respawn, "Paid passes never change Heat, Keys or race performance".

## Section 12: Open items

1. **Car list and Worlds.** Your showroom's 27 built cars, five rarities, 9 per World, the same rarity shape in each World. The first car is the World's Loaner (starting car).

   | World | Common | Uncommon | Rare | Epic | Legendary |
   |---|---|---|---|---|---|
   | Downtown | **Putter** (Loaner), Pizza Runner | Minnow, Surf Wagon | Bolt, Brawler | Executive | Street Kid, Cruiser |
   | Dusty Highway | **Rustbucket** (Loaner), Old Faithful | Beach Bug, Workhorse | Thunder | Desert King, Night Rider | Viper Strike, Apex |
   | Summit Pass | **Commuter** (Loaner), Family Hauler | Trailblazer, Sunny Camper | Rally Dog | Monarch, Velvet | Zip, Phantom |

   When built: Sparkster to Downtown, Polytruck to Dusty Highway (10, 10 and 9). You can move any car; your Catalog wins. Lane 3 uses the model names in `ReplicatedStorage.Cars` as the car ids.
2. **Rider Level gate.** Not at launch (delegated). World unlocks, longer Keys times for rarer cars and the 5-bolt Stamina limit already pace a player. It is on the board's Deferred list; revisit if playtests show skilled players claiming every car of a World in one run even with 5 bolts.
3. **Big-number display.** Agreed, with the abbreviations (delegated). See "The Qa display rule" below.
4. **Galaxy look.** Still yours to approve. Lane 3 shows a placeholder badge (deep purple with small stars) marked PREVIEW.
5. **The open questions in `speedway-levels-for-brian-l.md`.** Lane 3 now shows sections 5 and 6 (the 12 Raceway prices and multipliers, parking prices for spots 3 to 15) as PREVIEW on the Raceway board, the upgrade panel and the parking panel.

## Section 13: Proposed contracts

- **Save fields:** Agreed by all three lanes (Adam relayed on 2026-11-02): `Cash`, `Cars { [carId]: { Edition, Copies } }`, `Lineup`, `RacewayLevel`, `ParkingSpots`, `WorldsUnlocked`, `LastSeen`, exactly as in section 13.
- **Remotes:** `BuyRacewayLevel`, `BuyParkingSpot`, `SetLineupSlot`, `UnlockWorld` are part of that contract.
- **Plot attributes** Lane 3 reads: `SpeedwayLevel` and `ParkingSpots`, unchanged.

Questions Lane 3 needs answered (no new fields; only what the agreed ones mean):

1. **`Edition`:** Lane 3 reads it as 1 to 5 in the order Normal, Gold, Diamond, Rainbow, Galaxy. Is that right, or is it 0-based or a name?
2. **`Copies`:** Lane 3 reads it as the copies held at the current edition (0 to 24; a merge takes 25 and resets it). If it is the lifetime total instead, the ladder must work out the remainder; say which.
3. **`Lineup`:** can it have gaps (slot 3 filled, slot 2 empty)? Lane 3's beta stand-in for `SetLineupSlot` allows a gap and treats `carId = nil` as "take the car out".
4. **Largest Cash value:** what is the cap? Lane 3's display handles up to 999 Qa exactly and then shows whole Qa, but Luau numbers stop being exact at about 9 Qa.

## Robux products for Lane 2 to build

Every price is the PREVIEW default Lane 3 shows today. In Lane 3 every price press ends in "Coming soon"; nothing is charged or granted.

| Item | PREVIEW price | What it does (as the player reads it) | Where it is sold |
|---|---|---|---|
| Respawn | 19 Robux | Keep your run going. | Run results, after the free respawns are used |
| Cash pack, 10 minutes | 49 Robux | Cash worth 10 minutes of your Raceway (at least 0.4x the Cash you hold) | Shop, Cash |
| Cash pack, 30 minutes | 99 Robux | 30 minutes of Raceway Cash (at least 1x your Cash) | Shop, Cash |
| Cash pack, 1 hour | 179 Robux | 1 hour of Raceway Cash (at least 1.9x your Cash) | Shop, Cash |
| Cash pack, 3 hours | 449 Robux | 3 hours of Raceway Cash (at least 5x your Cash) | Shop, Cash |
| Cash pack, 8 hours | 899 Robux | 8 hours of Raceway Cash (at least 12x your Cash) | Shop, Cash |
| Double Lap Pay (pass) | 199 Robux | Your cars earn twice as much on your Raceway. | Shop (Featured, Passes); Results "Earn faster" |
| Expanded Paddock (pass) | 149 Robux | Park 3 more cars: up to 18! | Shop (Passes); the full parking card's GET MORE SPOTS |
| VIP (pass) | 299 Robux | VIP paints, a name tag and your own lounge; offline earnings build for up to 12 hours | Shop (Featured, Passes); HUD VIP button |
| All Passes Bundle | 549 Robux | Double Lap Pay, Expanded Paddock and VIP (647 Robux bought one by one) | Shop (Passes) |
| Starter Pack | 79 Robux | Brawler (a Rare car), $5,000 Cash, Rookie Flame paint and Starter Stripe decal; one per player (decision 0038) | Shop (Featured) |
| Flame Rush trail | 99 Robux | A flashy trail behind your car (looks only) | Garage, Customize, Trails |
| Confetti Party trail | 129 Robux | A flashy trail (looks only) | Garage, Customize, Trails |
| Prism Ribbon trail | 199 Robux | A flashy trail (looks only) | Garage, Customize, Trails |
| Comet Tail trail | 249 Robux | A flashy trail (looks only) | Garage, Customize, Trails |

Cheaper trails stay Cash. No item involves paid randomness, and no item sells a car or an edition.

Recommendation for how to build them. Lane 3 has not tested any of this against Roblox; please check each point against the current official Roblox documentation before building:

- **The Starter Pack's car** is granted like a claimed car: Brawler into `Cars` at Normal with 0 copies, once per player, inside the same receipt grant as the pack's Cash. A player who already owns Brawler: decide what they get instead (for example a copy toward Gold), so the pack never gives nothing.
- **Consumables (the respawn, Cash packs, the Starter Pack's Cash) as Developer Products**, granted on the server in `MarketplaceService.ProcessReceipt`, never from a client callback. Make the grant safe to repeat: record the purchase id so a retried receipt never grants twice, and return "granted" only after the grant is saved.
- **Permanent items (passes, Robux trails) as Game Passes**, or Developer Products with saved ownership. Check ownership on the server when the player joins and after a purchase.
- **Per-player purchase restrictions:** check `PolicyService` before showing a purchase prompt, and show a clear "not available" state when they apply. Only the returned fields that apply to the item matter; none of them is a general "can buy" answer.
- **A paid respawn that arrives late** (the run already ended, the player left): decide what the player gets before selling it, so a payment is never taken without the promised value.
- **Receipt and trail ownership records** may need fields beyond the agreed list; that is a contract question for all three lanes, not something Lane 3 adds.
- **Regional pricing:** if Roblox shows a player-specific price, the price on Lane 3's buttons must come from the product, not from these PREVIEW numbers.

## Expanded Paddock and the 15-spot maximum

Economy v1 says the maximum is 15 parking spots. The outline's Expanded Paddock adds 3 spots, which would be above the maximum. **Recommendation: the pass gives 3 more bays on top of the ones bought, so a pass holder can reach 18**, because a pass that adds nothing at the maximum would be a broken purchase. Lane 3 built it that way on 2026-11-03 (Adam asked): with the pass the front row becomes 10 evenly spaced bays (mirrored about the centre line, on the same 9-stud grid as the back row) on small floor strips at both ends, and the parking sign moves out. Note for car placement: with the pass, front-row bays 1 to 7 sit half a bay (4.5 studs) from where the 15-bay layout puts them; `Parking.bay(i, true)` in `src/shared/Island/Speedway/Parking.luau` gives every bay's position, so Lineup cars should be placed from it rather than from the fixed Bay01 to Bay15 markers. The saved `ParkingSpots` stays 2 to 15; your server would set the plot attribute `ExpandedPaddock = true` and publish `ParkingSpots` as bought + 3. In the beta, ownership is a Studio-only test switch; the real sale and ownership check are yours. If you choose otherwise, `Parking.ExpandedSpots` and the pass text change in one place.

## The Qa display rule

- Below $10,000: exact dollars with commas ("$9,999").
- From $10,000: at most three significant digits with K, M, B, T or Qa (quadrillion), truncated and never rounded up: "$10K", "$999K" for 999,999, "$1M", "$999B", "$1T", "$2T", "$999T" for 999.99T, "$1Qa", "$1.23Qa".
- From 1,000 Qa: whole Qa with commas ("$1,000Qa").
- Negative, NaN or infinite values show "$0".
- It is display only: screens always compare the real numbers, never the text. Tests: `src/shared/UI/FormatTests.luau`.

## Replies

### Brian L

_(your answer here)_
