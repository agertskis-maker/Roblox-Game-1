---
title: Lane 3 Round 3, for Brian L
date: 2026-11-02
tags:
  - design
  - lane2
---

# Lane 3 Round 3, for Brian L

Every price and amount below is a PREVIEW proposal. Nothing is sold, nothing is granted, and no product or pass ids exist. Your files were not edited. These need your decision, and propose-first items need Adam's.

## 1. Scaling Cash packs (Adam's decision)
A pack gives "N minutes of your Raceway earnings", with a floor from the Cash you hold, so a pack stays worth having however far you've come. One display module holds the maths, ready to move: `src/shared/UI/CashPackPreview.luau`.

`amount = rounded down to 3 digits of max(earningsPerSecond x 60 x minutes, currentCash x floor, minutes x 50)`

| Pack | Minutes | Floor (x Cash held) | PREVIEW Robux |
|---|---|---|---|
| Small stack | 10 | 0.4 | 49 |
| Bundle | 30 | 1 | 99 |
| Briefcase | 60 | 1.9 | 179 |
| Safe | 180 | 5 | 449 |
| Vault | 480 | 12 | 899 |

**The rule that must hold:** the real grant is computed **by the server, at purchase time, from server data**, inside `ProcessReceipt`, once per receipt, with the amount saved against the receipt id so a retry can't pay twice. The client's number is only a display and is never trusted. The card can change between looking and paying, so show the final amount after the purchase.

Please check the floors against your economy. A 12x floor is generous for someone holding a lot of Cash; that's the point of Adam's "$1 million buys $5 million" idea, but it needs your curve.

## 2. Trails (new cosmetic)
Cosmetic only: they never change Heat, Keys, Stamina or a race. In `src/shared/UI/CosmeticPreviewCatalog.luau`.

| Trail | PREVIEW price |
|---|---|
| Smoke Ring | $800 |
| Spark Dust | $1,500 |
| Bubble Pop | $2,200 |
| Neon Line | $3,000 |
| Star Drift | $4,500 |
| Flame Rush | 99 Robux |
| Confetti Party | 129 Robux |
| Rainbow Road | 199 Robux |
| Galaxy Tail | 249 Robux |

## 3. Cosmetic tiers
Decals are now 14 real designs ($500 to $9,000), wheels 10 ($0 to $6,000), paints 33 as before ($0 to $12,000). Prices rise with tier. Ids changed for decals, so nothing should depend on the Round 2 ids.

## 4. Launch Pad purchases
The Trail stall and Paint corner use the same catalog. Cash items are a PREVIEW buy that takes fixture Cash for the session. Robux items end in Coming soon. The Car stall lists cars; it needs your real owned-car list.

## 5. Respawn for Robux (new, Adam asked for it)
**Decided 2026-11-02:** Adam keeps it at 19 Robux, knowing it helps a run.

After a crash, once free revives are used, the card offers a respawn for a PREVIEW 19 Robux. It gives the same thing as a free revive: back on a car, 3 bolts. Needs a Developer Product and a server-checked grant. This touches run outcomes, so please agree it with Adam and Brian R, and decide how it fits "no paid gameplay advantage". It's built so it can be removed with one line.

## 6. Other renames and data
- **Expanded Paddock is now "Extra Parking"** on screen (Adam: simpler for kids). The offer id `expanded-paddock` is unchanged.
- The packs need your Raceway earnings per second: the card uses a PREVIEW $30/s.
- Run results show PREVIEW Cash (distance, hops, cars). The real payout is yours.

## 7. Still open, from earlier messages
- `lane3-round2-for-brian-l.md` (cosmetic prices, HUD data, Welcome Back rules, a saved tutorial flag)
- `lane3-big-round-for-brian-l.md` (Shop catalog and purchases, save fields, group reward, missions, portal data)
- `speedway-levels-for-brian-l.md`, `settings-sound-for-brian-l.md`

## Replies

### Brian L

_(your answer here)_

## Added 2026-11-02: Missions and Goals ladder

Adam asked for many more quests and goals, paying more the harder they are. All of it is a display fixture in `src/client/UI/Prototype/SupportFixtures/MissionFixtures.luau`; nothing is granted, saved or tracked.

- The seam changed: `missions[]` can hold up to 15 active rows (it was 3), and `goals[]` rows gain an optional `reward`.
- Proposal to accept or change: 27 mission templates in five tiers (Easy $150 to $300, Medium $750 to $1,500, Hard $3,000 to $6,000, Expert $10,000 to $20,000, Legend $40,000 to $75,000) and 24 goals from $500 to $500,000.
- Decisions for you: whether these amounts fit the economy, whether goals pay out at all, how progress is tracked, and whether Silver and Gold medals exist. Six goals are the approved names; 18 are new.
