---
title: Raceway levels - message for Brian L
tags:
  - design
  - speedway
  - lane2
  - lane3
status: sent
---

# Raceway levels: message for Brian L (Lane 2)

From Adam (Lane 3), sent through the vault on 2026-10-28. Written by Claude Code from Adam's brief (`vault/design/specs/speedway-upgrade-looks.md`, on the branch `feature/lane3-speedway-upgrades`). Please answer in the Replies section at the bottom (you or your AI).



> [!info] Beta note (2026-10-31)
> Adam published a one-place beta, **Car Hop Beta** (LEGION STUDI0S, private), from the branch `integration/beta-1` (draft PR #7, decision [[0030-car-hop-beta-1]]). Until your real save layout, economy and plot service exist, it uses clearly labelled stand-ins in `src/server/Beta`: a beta-only ProfileStore store `CarHopBeta1` with `RacewayLevel` and `ParkingSpots`, plot ownership, and **free** purchases through two argument-less remotes. Replace them with yours whenever you are ready; the Raceway client only reads the plot attributes `SpeedwayLevel`, `ParkingSpots` and `OwnerDisplayName`.

## Round 2 update (2026-10-29): Raceway, Lap Pay, parking spots and the purchase flow

From Adam, after his review of PR #4. Written by Claude Code from Adam's brief (`vault/design/specs/raceway-round2.md` on `feature/lane3-speedway-upgrades`). Everything below the line "Round 1 message" is the original message, kept as it was apart from the name.

### 1. "Speedway" is now "Raceway"
- Players read **Raceway** everywhere ("Adam's Raceway", "RACEWAY LEVEL 5!", the shop, the panels, the prompts). Lane 3's code, files and attributes keep the word "Speedway" to avoid churn (for example the plot attribute `SpeedwayLevel` and the module `Shared.Island.Speedway.Look`).
- **Proposed save field name: `RacewayLevel`** (an integer, 1 to the final count), instead of the `SpeedwayLevel` proposed in round 1. The plot attribute Lane 3 reads stays `SpeedwayLevel` unless you prefer to rename both; say which.
- The level-up banner now states the level only: "RACEWAY LEVEL 5!". Level names are internal labels and are never shown.

### 2. Lap Pay multiplier per level (Adam's PROPOSAL for you to replace)
Adam's stat for each level is a **Lap Pay multiplier**. Lap time stays about 15 s at every level and car speed does not change, so the multiplier is the only earning stat. Lane 3 shows it on the shop's stats board and in the upgrade panel as "LAP PAY x1.35 → x1.50", read from one table (`Ladder.LapPay` in `src/shared/Island/Speedway/Ladder.luau`) so your economy can replace it in one place:

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Lap Pay | x1.00 | x1.10 | x1.20 | x1.35 | x1.50 | x1.70 | x1.90 | x2.15 | x2.40 | x2.70 | x3.00 | x3.50 |

Nothing pays from this table; it is display only until you decide the real values.

### 3. Parking spots (Adam's decision, with a price PROPOSAL)
- **Decided by Adam:** every player starts with **2** parking spots; the Paddock has room for **15**; more are bought **one at a time**; the number of spots is how many cars can sit on the plot's Raceway lineup.
- **Separate upgrade:** parking spots and Raceway levels are two separate upgrades with separate save fields. Changing one never changes the other (tested in Studio both ways).
- **Proposed save field: `ParkingSpots`** (integer, starts at 2, maximum 15). Lane 3 reads a plot attribute of the same name, `ParkingSpots`, set by your server.
- **Proposed price rule (yours to set):** each new spot costs about **1.6 times** the previous one, starting from a first price you choose: `price(k) = firstPrice * 1.6^(k - 3)` for buying spot k, k = 3 to 15. The first price and the rounding are yours. No price is hard-coded anywhere in Lane 3's code.
- What players see: owned bays have clean cream lines; the next bay has a short navy-and-cream barrier with an "ADD SPOT" plaque; bays beyond stay plain floor. The parking sign shows "PARKING 2 / 15" live. Buying unlocks the next bay with a short reveal (the barrier lifts, the lines paint in, a little confetti). At 15 the barrier is gone and the panel says "ALL SPOTS OWNED".

### 4. The purchase flow Lane 3 built (so your code only supplies prices, checks Cash and sends the result)
| Step | Lane 3 (built) | You (Lane 2, to build) |
|---|---|---|
| The owner walks up | The shopkeeper waves; prompt "Upgrade Raceway" on the shop counter, and "Buy Parking Spot" on the parking sign. Owner only; visitors see the board and sign read-only | Tell the client which plot the player owns (today a Studio preview attribute stands in) |
| The panel opens | "RACEWAY UPGRADES" (current and next level, Lap Pay change, the "New:" pieces) or "PARKING SPOTS" (owned k / 15, next spot), "PRICE: SET BY ECONOMY", a big BUY button | Supply the price for the next level and the next spot (Lane 3 will show it in place of "SET BY ECONOMY") |
| BUY | Locks the button (one request per transition, rapid clicks cannot buy twice) and sends a request | **Check Cash on the server**, charge it, and **set the plot attribute** `SpeedwayLevel` (or `ParkingSpots`) to the new value; save `RacewayLevel` / `ParkingSpots` |
| Result | When the attribute changes: the track or the Paddock rebuilds with its reveal, the banner "RACEWAY LEVEL n!" (levels only), the board and the panel update together, the button unlocks | On failure send nothing; the button unlocks after its timeout. Proposed states for later (not connected): pending, success, error, "NEED MORE CASH" (`vault/design/ui/raceway-upgrade-panel.md`, FUTURE states) |

Today, in the Studio preview only, BUY changes a local preview value; there is no Cash, no saving and no remote. Outside Studio there is no prompt yet, because no price exists. The client never sends an amount or a price.

### What Lane 3 needs from you now
1. The real Lap Pay effect per level (or keep Adam's proposal), and the price per level.
2. The first parking-spot price and your rounding, or a different growth rule.
3. The save field names: `RacewayLevel` and `ParkingSpots`, or yours.
4. The remote(s) for "buy next level" and "buy next spot" (names and arguments; the client sends no amount).

---

## Round 1 message (2026-10-28)

### What Adam decided

- The Raceway gets **10 to 15 upgrade levels** instead of the outline's 5 Income Tiers. It starts as a plain dirt track and gets a little better at every level, ending at a spectacular raised track with a loop.
- **Every level must be visible**: someone walking past a plot can tell roughly what level it is. That is the "the island shows progress" pillar.
- Crowds, bleachers, a referee-style flag official and other life arrive as the track grows.
- This replaces the 2026-10-21 rule that the base track already has yellow lines, flags, a checkered line and banners: those now arrive at later levels.

**Recommended (Claude, Adam can overrule): 12 levels.** Enough for a new visible change every level, inside Adam's range, without the art and phone cost of 15. Lane 3 is building the 12 as a look **preview** only:

1. Backyard Dirt Track
2. Raked and Roped
3. First Fans
4. Paved
5. The Flag Official
6. Pit Row
7. The Grandstand
8. Lights and Big Screen
9. Banked Turns
10. The Overpass
11. Jump and Blimp
12. Loop of Legends

If the team picks 15, three more looks fit in: a Night Lights Show (after 8), a Second Grandstand (after 9) and a Sky Tram (after 11).

**Assumption (please confirm or correct):** Slots, the parking bays in the Paddock, stay a separate ladder and are not part of these levels.

### What Lane 3 needs from you

These are yours to decide; Lane 3 builds looks only (no prices, no multipliers, no Cash, no save fields, no remotes):

1. **The final number of levels** (10 to 15).
2. **The price of each level and how much each level raises Lap Pay**, from your economy model.
3. **The save field for the level.** Proposal: one integer `SpeedwayLevel`, starting at 1.
4. **Whether this ladder replaces the outline's Income Tier** (in the save data and in the Lap Pay formula), or sits beside it.

### What Lane 3 will expose (proposal)

Your code only has to send the level number:

- **Server:** set the integer attribute `SpeedwayLevel` on the player's plot Model (`Workspace...Plots.PlotNN`) whenever it changes (join, purchase, reset). Optionally also `OwnerDisplayName` (a string) for the owner's sign.
- **Every client** reads that attribute and assembles the Raceway with Lane 3's look module (`ReplicatedStorage.Shared.Island.Speedway.Look`, function `Look.apply(plot, level)`), so visitors see the right level too. When the number goes up, the client plays the level-up reveal (about 1.5 seconds: dust, pieces bouncing into place, confetti, a banner such as "SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!"). Nothing blocks the player.
- **Lap timing stays yours.** Lineup cars lap in about 15 seconds at every level; Lap Pay stays a server timer. The visual car speeds up on the longer tracks so the car still crosses the finish line when the Lap Pay pops. Lane 3 needs the lap timer's events (car, rarity, time) on the client to sync the flag official, the crowd and the Lap Pay pop; the preview uses a labelled fixture until then.
- **The kiosk's upgrade board** shows the current level, the next level's name and picture, and a price placeholder. It needs the next price from your catalog when you have it.

Nothing is wired to your code yet; the contract above is a proposal until you agree.


## Replies

### Brian L

_(your answer here)_
