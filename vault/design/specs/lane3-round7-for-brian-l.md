---
title: "Round 7: message for Brian L (economy, saves, car models)"
tags:
  - lane2
  - lane3
  - handoff
---

# Round 7: message for Brian L

Hi Brian L. Here is what Round 7 added that touches your work. Decision: [[0042-lane3-round7]]. Ledger: [[lane3-round7-ledger]]. Everything below is in Adam's beta (`integration/beta-5`) as beta-only stand-ins, ready for your real modules to replace.

## Car models and paint (C-02)

- **No car model file was edited.** Paint works without touching your models: each car gets a 2% transparent copy of its body mesh with a drawn texture. Where the paint goes comes from a mask per car, generated outside the repo from each car's own texture: `src/client/UI/Prototype/Style/PaintMasks.luau` (base64 run lengths, 256 x 256, 7 shades).
- **Cars that need your help:**
  - **Apex:** its texture is mostly grey, so the mask had to be forced. Paint shows weakly on it.
  - **Viper Strike:** keeps some of its green where the mask misses body panels.
  - **Rainbow editions** have their own mesh with no mask, so they are not painted. Gold and Diamond share the base mesh and take paint.
- **A livery to check (AGENTS.md vehicle rule 5):** a reviewer said one SUV in the paint contact sheet (`Car-Hop-Art/review/round7/frames/C02-contact-sheet-white.jpg`, third row, left) looks like it has a police livery. Please check it and change the texture if you agree.
- **An upload problem to fix:** `AssetService:CreateEditableImageAsync` cannot read your car textures. Asset 91449126189134 is owned by a user account (10608836728), not by LEGION STUDI0S. If the car textures were re-uploaded under the group, paint could be drawn straight from them instead of from the stored masks.

## New beta save fields (in `src/server/Beta/BetaData.luau`, all repaired by `sanitize`)

| Field | What it holds |
|---|---|
| `LuckLevel` | Lucky Clover levels bought, 0 to 5 (P-04) |
| `Equipped` | The worn Style Shop item per tab: Paint, Decals, Wheels, Trails (C-08) |
| `Owned` | Now also holds Style Shop items bought for Cash, by catalog id (ids are unique across all four tabs; a self-test checks this) |
| `StaminaLevel` | From decision 0040, unchanged |

## Proposed for you

1. **A `Missions` save field.** 45 missions now run in five tabs (U-05). Saved facts (cars, rarities, Raceway level, spots, Worlds, Style Shop items, Stamina level) survive a rejoin. Counted facts (Lap Pay earned, Joyrides, runs, longest run, hops, longest hop chain, longest bump-free run) start again at 0 on a rejoin. A field that keeps the counters and the claimed ids would fix that.
2. **Luck and Roblox policy:** luck is bought with Cash, and Cash can be bought with Robux, so the beta checks `PolicyService` and refuses luck to accounts that may not buy paid random items. Your real economy should keep that check.
3. **Prices** for luck ($100K to $1B), Style Shop items ($500 to $2B) and mission rewards are PREVIEW values in `src/shared/UI/EconomyPreview.luau`, `CosmeticPreviewCatalog.luau` and `MissionsPreview.luau`. Replace them with yours.

## Replies

