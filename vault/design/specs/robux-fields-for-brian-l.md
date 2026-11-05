---
title: Robux and Missions save fields - proposal for Brian L
date: 2026-11-05
tags:
  - lane2
  - lane3
  - economy
  - save
status: proposed
---

# Robux and Missions save fields: proposal for all three lanes

From Adam (Lane 3), written with Claude Code in Round 6 (brief section 0 items 6 and 9, R-06, G-02). Brian L owns the save layout; this is a proposal, not a change to the agreed fields. Please answer in Replies.

## 1. What the beta does today

The beta (`integration/beta-4`, beta-only stand-ins in `src/server/Beta`) adds exactly two fields to its own beta store (`CarHopBeta1`), allowed by Adam for the beta only. No other field was added. Selling is switched off in the published beta (`BetaConfig.RealPurchases = false`); in Studio, purchases are free test purchases.

### `Purchases`: processed receipt ids

```lua
Purchases = { "8f3c...e1", "a71b...09" } -- PurchaseId strings from ProcessReceipt, newest last, at most 200
```

- **Why:** Roblox can call `ProcessReceipt` again for the same purchase (after a server shutdown, a rejoin, a second server). The only safe rule is "record the receipt id in the player's session-locked save, save, and only then answer `PurchaseGranted`". A retried receipt finds its id and answers `PurchaseGranted` without granting again (Roblox docs, `MarketplaceService.ProcessReceipt`, read 2026-11-05; `robux-api-notes.md`).
- **Why 200:** a player would have to buy 200 Developer Products before the oldest id falls off, and Roblox only retries receipts that were never acknowledged, which are always among the newest.
- **Where:** `BetaPurchases.processReceipt` and `BetaData.saveReceipt` (waits for a finished ProfileStore save that contains the id; if none comes within 15 s it answers `NotProcessedYet`, and the retry grants nothing twice).

### `Owned`: things bought that Roblox does not keep for us

```lua
Owned = { ["starter-pack"] = true, rookie_flame = true, starter_stripe = true, vip = true, ["double-lap-pay"] = true }
```

- **Why:** the All Passes Bundle is one Developer Product that must grant three passes, and the Starter Pack is once per player. Roblox keeps Game Pass ownership itself, but not "this player bought the bundle" or "this player already had the Starter Pack". Ownership is "owns the Game Pass OR has the id in `Owned`".
- **Values:** `true` only. Keys are the product ids in `src/shared/Beta/BetaProducts.luau` and cosmetic ids from `src/shared/UI/CosmeticPreviewCatalog.luau`.

## 2. A Missions field (proposal only; not added anywhere)

Missions (Round 6, G-01 and G-02; list in `src/shared/UI/MissionsPreview.luau`) are counted from real server events. Without a field:
- a mission that reads saved facts (cars, Lineup, Raceway level, spots, Worlds, editions) and was already done when the player joins shows as done with nothing to claim, so nobody can claim a reward twice by rejoining;
- the "this visit" missions (Lap Pay earned, Joyrides, runs, the longest run) start again at 0 on a rejoin;
- a finished mission that was not claimed is paid into the save when the player leaves, so nothing is lost for stopping.

Proposed field, if you want missions to remember across visits:

```lua
Missions = {
	Claimed = { ["first-catch"] = true }, -- mission ids claimed (never paid twice)
	Counts = { lapCash = 1250, joyrides = 3, runs = 4, bestMetres = 1650 }, -- the counted facts, kept
}
```

No timers, no daily reset, no streaks (Adam's rule for a children's game). Rewards stay PREVIEW until you set them.

## 3. Questions

1. Do you take `Purchases` and `Owned` as they are, or with other names or shapes?
2. Do you want the `Missions` field, or keep missions per visit?
3. The beta grants a Robux respawn that arrives after the run ended as Cash equal to that run's Results total. Is that your rule too?
4. A second Starter Pack receipt (it should never be prompted, but a receipt could still arrive) grants a Brawler copy and $5,000 again rather than nothing. Agree?

## Replies

### Brian L

_(your answer here)_

### Brian R

_(only if missions should count something your run reports)_
