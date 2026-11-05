---
title: Luck Station - proposal
date: 2026-11-05
tags:
  - lane2
  - lane1
  - lane3
  - economy
status: proposed
---

# Luck Station: proposal (propose first, nothing built)

From Brian L (Lane 2), written by Claude Code on 2026-11-05. The team chat asked for rare cars to show up more often "so people have something to work for", and suggested an upgrade that raises your luck. This note proposes one, as `AGENTS.md` asks for anything touching the economy or luck. Nothing is built until Brian L, Adam and Brian R agree.

## The idea

A **Luck Station** in the hub, next to the CARS stand. Brian L chose the spot in Studio Play on 2026-11-05: about (5982, 1203, 4.5) in the Car Hop Beta hub, the open floor between the HOME portal and the CARS stand.

- The player buys **Luck levels with Cash only**. Never Robux, no pass, no paid boost, no timed offer (paid luck is not allowed; most players are children).
- Each level makes Rare, Epic and Legendary traffic a little more common in that player's runs. Commons become a little less common, so the road still looks the same.
- 10 levels. The station shows the current level, the next level's price and the new odds in plain numbers (now and after, per rarity), worked out from Brian R's real weights.

## Proposed numbers (PREVIEW, tune in a playtest)

| Luck level | Rare, Epic and Legendary weight | Price |
|---|---|---|
| 1 (start) | x1.00 | free |
| 2 | x1.10 | $5K |
| 3 | x1.20 | $40K |
| 4 | x1.30 | $300K |
| 5 | x1.45 | $2.5M |
| 6 | x1.60 | $20M |
| 7 | x1.75 | $150M |
| 8 | x1.90 | $1.2B |
| 9 | x2.05 | $10B |
| 10 | x2.25 | $80B |

Prices sit between the Raceway levels, so Luck competes with Raceway and parking for Cash instead of replacing them. At most about 2.25 times the odds, so a Legendary stays a big moment.

## What each lane would do

- **Lane 1 (Brian R):** `RunSequence.new(seed, luck)`. The luck level multiplies the non-Common rarity weights in `weightsAt`. It has to live inside the sequence, because the server rebuilds the same traffic from the seed to check every Hop and Keys (decision 0021).
- **Lane 2 (Brian L):** save field `LuckLevel` (1 to 10, default 1), remote `BuyLuckLevel` (no arguments; the server picks the price), and `StartRun` returns `{ runId, seed, luck }` so the client builds the same sequence. The shared contracts need "Agreed" from all three lanes.
- **Lane 3 (Adam):** the station model and its panel in the hub, and the beta stand-in until Lane 2's server replaces it.

## For the team to weigh

- **Benefit:** a clear goal between Worlds; rare cars feel reachable; it answers "rare cars should spawn more often" without making them common for everyone.
- **Cost:** one save field, one remote, one parameter in Brian R's sequence, one station and one panel.
- **Risk:** too strong and Legendaries stop feeling special; another upgrade on top of Raceway and parking. Both are tunable from one table.
- **Test:** count rarities over 200 seeded runs at levels 1, 5 and 10 (a Lune test on `RunSequence`), then a playtest in a private copy.

## Replies

### Adam

_(your answer here)_

### Brian R

_(your answer here)_
