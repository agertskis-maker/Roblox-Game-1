---
title: Car Hop economy v1
date: 2026-11-02
tags:
  - design
  - economy
  - lane2
status: proposed
owner: Brian L (Lane 2)
---

# Car Hop economy v1

> [!warning] Status: proposed
> Written by Claude Code for Brian L (Lane 2, economy owner) on 2026-11-02. Brian L chose the direction in chat: huge numbers that climb into the trillions, a quick start that gets grindy late, and special editions crafted from duplicates the way Be Fish does it, very rare even for low cars.
>
> Cash and every saved economy field are propose-first in `AGENTS.md`. The catalog, the save layout and the remotes are shared contracts, so they change only after all three lane owners write "Agreed" on the board. **Nothing here is built.** Every number is **Tunable** for the first playtest and lives in one Catalog table once built.

## 1. The game's money in one minute

- There is one currency: **Cash**.
- Your cars drive laps on your **Raceway**. Every lap (about 15 seconds) each car pays **Lap Pay**. That is the main income, and it keeps paying while you are in a run.
- You spend Cash on three things: **Raceway levels** (multiply all Lap Pay), **parking spots** (more cars on the Raceway) and **World unlocks** (new cars to catch).
- You never buy cars. You **claim** them in runs by riding until the Keys fill ([[GDD]], **Decided**).
- Riding a car you already own pays a **Joyride Bonus** and gives you a **copy** of that car. Copies merge into **special editions** (Gold, Diamond, Rainbow, Galaxy) that pay far more.
- The numbers start small and grow very fast. A new player counts in hundreds; a late player counts in billions and trillions.

## 2. Who decides what

| Part | Owner |
|---|---|
| All numbers, save fields, remotes, server checks | Brian L (Lane 2) |
| Run events that pay (claims, Joyrides, coins, Milestones) | Brian R (Lane 1) reports them; Lane 2 checks and pays ([[0021-run-report-proposal]]) |
| How Cash, prices, editions and the Raceway look on screen | Adam (Lane 3) |

## 3. Car rarity numbers

| | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Keys time to claim | 3 s | 3.5 s | 4 s | 5 s | 6 s |
| Lap Pay per lap (Normal edition) | $10 | $50 | $250 | $2,000 | $25,000 |
| New-claim bonus (first time you get the car) | $100 | $500 | $2,500 | $20,000 | $250,000 |
| Joyride Bonus (already owned) | $30 | $150 | $750 | $6,000 | $75,000 |

- Keys times for Common, Rare, Epic and Legendary are the outline's **Decided** "a little longer for rarer cars" values; Uncommon's 3.5 s is from [[rarity-style]].
- Each tier pays about 5 to 12 times the tier below, so every new rarity feels like a big jump.
- The Joyride Bonus is multiplied by the car's edition (section 4).

## 4. Special editions (crafted, like Be Fish)

Idea taken from Be Fish (Goofy Vegetables, Roblox): every 50 copies of a fish merge into one copy of the next tier, and tiers are never random or bought ([fan wiki](https://befish.cc/)). Car Hop copies the structure only, not Be Fish's names, art or numbers.

**How it works**
1. Filling the Keys on a car you already own gives you 1 **copy** of that car (and the Joyride Bonus).
2. Copies count for life and merge automatically: **25** make Gold, then each further edition needs **10 times** the total (Brian L, 2026-11-02: Rainbow and Galaxy a little easier than a flat 25 per step, but still rarer than an Apex Legends heirloom). You keep the car and every edition you reach, for good.
3. A Raceway car shows and pays as its best edition. The Lineup still holds one of each model (**Decided**).

| Edition | Lap Pay and Joyride multiplier | Total Joyrides on that one car | Look |
|---|---|---|---|
| Normal | x1 | the first claim | the model |
| **Gold** | x3 | 25 | gold metal with a sparkle (model built) |
| **Diamond** | x10 | 250 | glassy blue with glints (model built) |
| **Rainbow** | x50 | 2,500 | cycling rainbow shimmer (model built) |
| **Galaxy** | x250 | 25,000 | deep purple with twinkling stars (new; applied in code on top of the model, look to be approved by Brian L) |

**Why this makes editions very rare, even for Commons**
- A Joyride only counts for the one car you rode. A run gives a handful of Joyrides spread across all your owned cars, so one particular Common might get 1 or 2 copies a run.
- Rough estimate, if one particular Common gets about 2 copies an hour of play (an assumption until the run's spawn rates are set): Gold about 12 hours, Diamond about 125 hours, Rainbow about 1,250 hours (the Apex-heirloom range) and Galaxy about 12,500 hours, a true lifetime goal. Legendaries appear far less often in traffic, so their editions take far longer again.
- Considered and rejected (2026-11-02): ChatGPT's review kept 25 per step (Galaxy at 390,625, about 170,000 hours for a Common) and lowered every payout; Brian L kept the numbers in this document instead.
- Nothing speeds it up: no luck, no boosts, no Robux. Every edition is earned the same way by every player.

**Changes to earlier rules**
- Replaces the outline's **Proposed** rule that Gold, Chrome and Rainbow Variants spawn at random in traffic. Variants still exist, as the GDD **Decided**.
- **Diamond** replaces Chrome (Brian L, 2026-11-02). **Galaxy** is a new fifth edition.
- Editions still never change a car's quirk or race stats, and do not count toward World unlocks.

## 5. Raceway levels (12, Adam's looks)

Each level multiplies every car's Lap Pay. Adam built the 12 looks ([[0025-speedway-visible-levels]]); these replace the outline's 5 Income Tiers.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Lap Pay x | 1 | 1.9 | 3.5 | 6.5 | 12 | 23 | 43 | 80 | 150 | 285 | 535 | 1,000 |
| Price | (start) | $1K | $5K | $25K | $150K | $1M | $7M | $50M | $400M | $3B | $25B | $2T |

## 6. Parking spots (start 2, max 15)

Adam decided the start (2) and the maximum (15). Spot k costs **$500 x 3^(k - 3)**, rounded to a friendly number:

| Spot | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Price | $500 | $1.5K | $4.5K | $13.5K | $40K | $120K | $365K | $1.1M | $3.3M | $10M | $30M | $90M | $265M |

## 7. World unlocks

| World | Cash | Cars needed | Rough time (estimate) |
|---|---|---|---|
| 1 | free | none | start |
| 2 | $5M | 5 cars from World 1 | 1.5 to 2 hours |
| 3 | $1B | 5 cars from World 2 | a further 2 to 3 hours |

Which car belongs to which World (approved by Brian L on 2026-11-03, for his showroom list):
- **World 1, Downtown:** Rustbucket, Putter, Old Faithful, Commuter, Family Hauler, Pizza Runner, Minnow, Workhorse, Trailblazer, Sunny Camper, Bolt.
- **World 2, Dusty Highway:** Beach Bug, Surf Wagon, Rally Dog, Thunder, Brawler, Desert King, Executive, Night Rider, Velvet.
- **World 3, Summit Pass:** Monarch, Zip, Street Kid, Viper Strike, Phantom, Apex, Cruiser.
- Polytruck and Sparkster are not built yet. Whether the GDD's 24-car World roster or this showroom list is the game's list is still a team decision (section 12, item 1).

## 8. Smaller Cash sources (all from runs)

| Source | World 1 | World 2 | World 3 |
|---|---|---|---|
| Road coin (capped at 100 a run) | $5 | $500 | $50K |
| Distance Milestone, every 500 m | $100 | $10K | $1M |

Run Cash is added the moment the server accepts the event, so a disconnect loses nothing already earned (outline section 06).

## 9. Offline earnings

While you are away, your Raceway earns **50%** of its normal rate for up to **8 hours** (outline, **Proposed**; restricted offline earnings are **Decided**). It is paid once when you rejoin and shown on a Welcome back card. The saved last-seen time stops the same hours being paid twice.

## 10. How a player's numbers grow (estimates, not yet simulated)

| When | Typical Raceway | Income |
|---|---|---|
| First 5 minutes | 2 to 3 Commons, level 1 | about $100 a minute |
| 30 to 45 minutes | 5 to 6 cars (Commons, Uncommons, a Rare), level 3 to 4 | about $5K to $10K a minute |
| 2 hours (World 2) | 7 to 8 cars with an Epic, level 6 | about $250K a minute |
| 5 hours (World 3) | 10 cars with a Legendary, level 8 | about $10M a minute |
| Weeks | 15 cars, mostly Legendary and Epic, level 12 | about $650M a minute, and billions a minute with Gold and Diamond editions |

Worked example for the last row: 6 Legendaries ($150K a lap), 6 Epics ($12K) and 3 Rares ($750) make about $163K a lap, times 4 laps a minute, times 1,000 at level 12. Level 12 itself ($2T) takes days of play at level 11 income.

A spreadsheet model (early, typical and extreme players) comes before tuning. These rows are targets, not results.

## 11. Fair for kids (`CLAUDE.md`)

- No daily streaks, no "limited time" offers, no countdown pressure, no paid random rolls.
- Editions and cars are never sold for Robux, and luck is never sold. Robux purchases are **in** (Adam's decision of 2026-11-02, decision 0038; Brian L accepted on 2026-11-05): the 19 Robux respawn, the Starter Pack (with Brawler), VIP, Double Lap Pay and Expanded Paddock (3 bays on top of what was bought, up to 18). Prices and the exact save fields still need the team's design and a current Roblox policy check (`PolicyService`) before selling is switched on.
- No pushy sale tactics: no crossed-out "was" prices, "Best deal" or "Save %" badges, timers or limited stock.
- Nothing is ever lost: no Cash penalty for a failed run, no car or edition can be taken away.
- The 19 Robux respawn (decision 0033) is in, by Adam's decision. It conflicts with two GDD lines ("Passes never change Heat, Keys or race performance", "no Developer Products at launch"), so the GDD needs updating too.

## 12. Open items (need an answer before building)

1. **Car list and Worlds.** The GDD plans 24 cars, 8 per World, 4 rarities. Brian L's showroom has 29 cars in 5 rarities and no Worlds ([[showroom-roster]] on branch `feature/lane2-ev-roster`). Which list counts, and which cars go in which World?
2. **Rider Level gate** (Brian R's [[0022-circuit-run-profile-proposal]]): not used here. Brian L and Adam decide together.
3. **Big-number display** for Lane 3: 1.2K, 3.4M, 5.6B, 7.8T, then Qa (quadrillion). Roblox numbers stay exact up to about 9 quadrillion, so the economy is capped well below that.
4. **Galaxy look**: Brian L approves the colours and effect.
5. Adam's open questions in `speedway-levels-for-brian-l.md` are answered by sections 5 and 6 and section 13.

## 13. Proposed contracts (need "Agreed" from all three lanes)

**Save fields** (ProfileStore template; `Reconcile` backfills them):

| Field | Type | Start |
|---|---|---|
| `Cash` | number | 0 |
| `Cars` | `{ [carId]: { Edition: number, Copies: number } }` | the World 1 Loaner, Normal, 0 copies |
| `Lineup` | `{ carId }`, length at most `ParkingSpots` | the Loaner |
| `RacewayLevel` | integer 1 to 12 | 1 |
| `ParkingSpots` | integer 2 to 15 | 2 |
| `WorldsUnlocked` | `{ [worldId]: true }` | World 1 |
| `LastSeen` | number (Unix time) | join time |

**Remotes** (`src/shared/Net`; the client never sends an amount or a price):

| Remote | Arguments | Server checks |
|---|---|---|
| `BuyRacewayLevel` | none | profile loaded, below 12, enough Cash, cooldown |
| `BuyParkingSpot` | none | profile loaded, below 15, enough Cash, cooldown |
| `SetLineupSlot` | slot (integer), carId (string or nil) | slot within `ParkingSpots`, car owned, not already in the Lineup |
| `UnlockWorld` | worldId (string) | known World, not unlocked, enough Cash, enough cars from the World before |

Run payouts use the run report in [[0021-run-report-proposal]] (Agreed by Brian L and Adam on 2026-10-28).

**Plot attributes** Lane 3 already reads: `SpeedwayLevel` (set from `RacewayLevel`) and `ParkingSpots`.

## 14. How to test it (once approved)

- Mock-only save tests (`ProfileStore.Mock`) for every purchase: enough Cash, not enough Cash, at the maximum, rapid repeated clicks.
- A Studio playtest in Brian L's private copy `CarHop-Lane2-Economy.rbxl`: earn Lap Pay, buy a level and a spot, be refused without Cash, rejoin and see the same balance.
- A pacing check against section 10 with the spreadsheet model, then a real playtest with a timer.
