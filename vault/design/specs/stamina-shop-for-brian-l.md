---
title: Stamina Shop, for Brian L
date: 2026-11-05
tags:
  - lane2
  - lane3
---

# Stamina Shop: notes for Brian L

From Adam (Lane 3), written with Claude Code on 2026-11-05. Decision [[0040-beta-driving-update-stamina-shop]]. **None of your files were changed** (`src/server` outside `src/server/Beta`, `src/shared/Catalog`, `src/shared/Net`, `assets/cars`). Each item is yours to accept, change or replace.

## 1. A new save field (beta-only until you decide)

- `StaminaLevel: number`, default 0, in the beta template (`src/shared/Beta/BetaConfig.luau`). Adam approved it for the beta on 2026-11-05. It is **not** an Agreed field; please say whether it joins your real template, under this name or another.
- The beta repairs a bad value on load (not a number, NaN or infinity becomes 0; otherwise whole number, clamped 0 to 10) in `BetaData.sanitize`.
- The level is replicated read only as the player attribute `BetaStaminaLevel`.

## 2. The numbers (PREVIEW, in `src/shared/UI/EconomyPreview.luau`)

- Stamina = 5 + level (`StaminaStart` 5, `StaminaPerLevel` 1), so 5 to 15 hops per run.
- Price of the next level, in Cash: 1K, 3K, 9K, 27K, 80K, 250K, 750K, 2.25M, 6.75M, 20M (about x3 a step). Total 30.1M.
- Why these: the first level costs about one or two good Downtown runs; the first six levels together (370K) cost less than the Dusty Highway unlock (5M); the last two (6.75M and 20M) are Dusty Highway money; the whole ladder (30.1M) is far below the Summit Pass unlock (1B). Cash only: no Robux, no paid randomness, no timers.
- `EconomyPreview.staminaFor(level)` and `EconomyPreview.staminaPrice(level)`; both are NaN-safe and clamp.

## 3. The remote (stand-in, same style as BuyRacewayLevel)

- `BuyStaminaLevel()` takes **no arguments**. The server checks the save is loaded, the level is below 10, prices it from EconomyPreview, spends Cash with `trySpend`, adds 1, publishes the attribute and answers through the usual `BetaResult`.
- Self-test (`BetaShop.selfTest`): refused at $999 for a $1,000 level (missing $1); bought at $1,000; refused again at $0; top level refused with no charge; the level survives a save and reload.

## 4. The run cap follows Stamina

- The beta run cap on claims plus joyrides per run is now `max(5, staminaFor(StaminaLevel))` (`BetaRun.keysComplete`). The tutorial run is 5 too (it was 8).

## 5. What it looks like

- A STAMINA kiosk on each World's Launch Pad (between PAINT and TRAILS) with a battery tower and a lightning bolt. Standing in its ring opens the STAMINA SHOP card: NOW and NEXT bolt rows, 10 level pills, BUY $X (or NEED $X MORE, or MAX LEVEL), PREVIEW tag.
- On the run board, bolts change colour so 15 hops still fit in 5 slots: yellow = 1 hop, red = 2 hops (a hop empties half a bolt), purple = 3 hops.

## Questions for you

1. Does `StaminaLevel` (or your name for it) join the real save template?
2. Keep, change or replace the 10 prices? They are only in `EconomyPreview`.
3. Should the server's claim cap read Stamina from your Catalog once it exists?
