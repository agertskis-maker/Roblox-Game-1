---
title: Lane 3 Round 2, for Brian L
tags:
  - spec
  - teammate
---

# Lane 3 Round 2: for Brian L

From Adam (Lane 3), sent through the vault on 2026-11-02. Written by Claude Code. Nothing in your code was changed, and nothing here is a final price. Please answer in the Replies section at the bottom (you or your AI).

## Cosmetics: paint, decals, wheels

Adam's direction: cosmetics are bought with in-game Cash, in tiers that get fancier and pricier. Prices are yours (economy is propose-first). The screen shows named PREVIEW prices, in `src/shared/UI/CosmeticPreviewCatalog.luau`: 33 paints, 15 decals and 10 wheels. The full table is in `lane3-round2.md`, N12-03b.

- These amounts are arbitrary starting points for testing the screens, not balanced prices.
- Preview balances are isolated: the screen spends its own "PREVIEW Cash" (5,000 at the start of a session). It never touches real Cash, nothing is charged, and nothing is saved.
- A cosmetic changes the look only: no speed, grip, jump or income.
- No new currency.

**Calibration to do:** compare price with verified net Cash per minute early, mid and late, and with Raceway upgrade costs at those points. The aim is affordable self-expression first and long-term showpieces later.

Medal-locked paints need a medal result from Brian R and your say on entitlement.

## What the HUD needs (read-only)

| Value | Where it shows | Today |
|---|---|---|
| Cash balance | Bottom left | PREVIEW fixture in the beta: the beta has no Cash yet |
| Cash per second | Green +X/s beside it | Hidden until a real rate is supplied: never invented |
| Cars owned and catalog size | "12 / 24" | PREVIEW fixture |
| Variants owned per car | Garage detail | "Not available yet" |
| Medals | Customize locks | Fixture only |

## Welcome back

The card treats the amount it is given as already credited. CLAIM only acknowledges, exactly once; it never credits again, and the coin flight is a look only. It needs: the credited amount, the credited time (with any cap, not the time away), and a verified zero, which skips the card. There is no offline payout yet, so the beta shows a PREVIEW amount.

## Later, not built

- **Index completion rewards.** The Garage shows a PREVIEW reward per World, and CLAIM only works for the session. Real ones need a claim remote and saved state.
- **Update Log.** It needs no data. "Shown once per version" is per session only, because that needs a saved field to last. Your call whether it is worth one.
- **Tutorial finished flag.** The beta cannot tell a new player from a returning one, so the join flow uses a test switch (`HomeJoinMode`). One saved flag would fix it.

## Still open from before

`lane3-big-round-for-brian-l.md`: real purchases, save fields, group reward, missions, welcome-back and portal data. `speedway-levels-for-brian-l.md` and `settings-sound-for-brian-l.md` have no replies yet either.

## Replies

### Brian L

_(your answer here)_
