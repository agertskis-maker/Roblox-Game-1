---
title: Team chat asks - message for Brian R and Adam
date: 2026-11-05
tags:
  - lane1
  - lane2
  - lane3
status: sent
---

# Team chat asks: message for Brian R (Lane 1) and Adam (Lane 3)

From Brian L (Lane 2), written by Claude Code on 2026-11-05, from the requests in the Legion Studios chat. Please answer in the Replies section.

## Done in Lane 2 (branch `feature/lane2-economy-preview`)

- **Every World has its own cars and two Legendaries:** `Catalog.CarWorld` now uses Adam's list (Downtown: Street Kid, Cruiser; Dusty Highway: Viper Strike, Apex; Summit Pass: Zip, Phantom). The starter car is Putter.
- **Later Worlds make more money:** World pay factor x1 / x40 / x1,600 on Lap Pay, claim bonus and Joyride Bonus, with Lap Pay $10 / $25 / $60 / $150 / $400 inside a World (`economy-v1.md` section 3). This is the candidate Lane 3 already uses in the beta's PREVIEW module.

## Asks for Brian R (your run code, nothing changed by Lane 2)

1. **Cars all the same size in a run.** The traffic size is random now (`sizeChance` in `RunSequence`), and big cars are harder to hop even though they should feel better. Could every spawn use one size, or the size depend only on rarity?
2. **Rare cars spawn more often.** Could the Rare, Epic and Legendary weights in `weightsAt` go up? Please tell Lane 2 the new odds so the pacing can be checked.
3. **Luck upgrade.** See `vault/design/specs/luck-station-proposal.md`: Cash-only Luck levels that multiply the non-Common weights, through `RunSequence.new(seed, luck)`. It needs your OK before anything is built.

## Ask for Adam and Brian R (whoever owns the look)

4. **Big effects when a rare car spawns.** A glow, trail or burst that grows with rarity, so a Legendary is obvious from far away. It is presentation only, with no economy change. Reduced Motion should tone it down.

## Replies

### Brian R

_(your answer here)_

### Adam

_(your answer here)_
