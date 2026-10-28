---
title: Speedway levels - message for Brian L
tags:
  - design
  - speedway
  - lane2
  - lane3
status: sent
---

# Speedway levels: message for Brian L (Lane 2)

From Adam (Lane 3), sent through the vault on 2026-10-28. Written by Claude Code from Adam's brief (`vault/design/specs/speedway-upgrade-looks.md`, on the branch `feature/lane3-speedway-upgrades`). Please answer in the Replies section at the bottom (you or your AI).

## What Adam decided

- The Speedway gets **10 to 15 upgrade levels** instead of the outline's 5 Income Tiers. It starts as a plain dirt track and gets a little better at every level, ending at a spectacular raised track with a loop.
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

## What Lane 3 needs from you

These are yours to decide; Lane 3 builds looks only (no prices, no multipliers, no Cash, no save fields, no remotes):

1. **The final number of levels** (10 to 15).
2. **The price of each level and how much each level raises Lap Pay**, from your economy model.
3. **The save field for the level.** Proposal: one integer `SpeedwayLevel`, starting at 1.
4. **Whether this ladder replaces the outline's Income Tier** (in the save data and in the Lap Pay formula), or sits beside it.

## What Lane 3 will expose (proposal)

Your code only has to send the level number:

- **Server:** set the integer attribute `SpeedwayLevel` on the player's plot Model (`Workspace...Plots.PlotNN`) whenever it changes (join, purchase, reset). Optionally also `OwnerDisplayName` (a string) for the owner's sign.
- **Every client** reads that attribute and assembles the Speedway with Lane 3's look module (`ReplicatedStorage.Shared.Island.Speedway.Look`, function `Look.apply(plot, level)`), so visitors see the right level too. When the number goes up, the client plays the level-up reveal (about 1.5 seconds: dust, pieces bouncing into place, confetti, a banner such as "SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!"). Nothing blocks the player.
- **Lap timing stays yours.** Lineup cars lap in about 15 seconds at every level; Lap Pay stays a server timer. The visual car speeds up on the longer tracks so the car still crosses the finish line when the Lap Pay pops. Lane 3 needs the lap timer's events (car, rarity, time) on the client to sync the flag official, the crowd and the Lap Pay pop; the preview uses a labelled fixture until then.
- **The kiosk's upgrade board** shows the current level, the next level's name and picture, and a price placeholder. It needs the next price from your catalog when you have it.

Nothing is wired to your code yet; the contract above is a proposal until you agree.

## Replies

### Brian L

_(your answer here)_
