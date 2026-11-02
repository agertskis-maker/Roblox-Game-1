---
title: Lane 3 big round, message for Brian L
date: 2026-11-01
tags:
  - lane3
  - lane2
  - message
---

# Lane 3 big round: message for Brian L (Lane 2)

From Adam, with Claude Code. Earlier unanswered messages stay in [[speedway-levels-for-brian-l]] and [[settings-sound-for-brian-l]]; they are not repeated here. **Nothing here is decided.** Every price, amount, reward and entitlement is a PREVIEW fixture. No real purchase, grant, save field or product exists in this round, and a finished-looking screen does not mean its system exists.

## What Lane 3 built

Shop, Portal card, Missions and Goals, Welcome back, loading screen, group pop-up, Stunt screens, customization. All display fixtures with a clear seam for your data.

## 1. Shop (M10)

**Seam:** `src/client/UI/Prototype/ShopPurchaseAdapter.luau` is the single purchase call. **Catalog fixture:** `src/shared/UI/ShopPreviewCatalog.luau`, shaped so `src/shared/Catalog` can replace it.

| Item | PREVIEW price (Robux) | Kind proposed |
|---|---|---|
| Double Lap Pay | 199 | Game pass |
| VIP | 299 | Game pass |
| Expanded Paddock | 149 | Game pass |
| All Passes Bundle | 549 | Unsolved, see below |
| Starter Pack | 79 | Unsolved, see below |
| Cash packs | none | Developer products, hidden behind a flag until amounts exist |

These are design proposals, set deliberately below some mature-game examples because Car Hop's value is unproven. The three passes sum to 647; 549 is 15.1% less **in this fixture only**. No public discount or BEST DEAL claim follows from that. They need your economy view, duplicate-ownership rules and real per-player prices.

| Proposal | Player benefit | Cost | Risk | Test |
|---|---|---|---|---|
| **L1.** Real purchase flow behind the adapter: ownership checks at open, `PromptGamePassPurchase`, idempotent `ProcessReceipt` for developer products | The Shop works | Server module plus receipts in ProfileStore | Receipt bugs cost players money; needs care | Mock receipts replayed twice grant once |
| **L2.** All Passes Bundle. A pass is a "one-time Robux fee"; a bundle cannot grant three passes natively | One-tap value | Needs a custom entitlement | Owning one pass already: what then? | Fixture "you already own part of this bundle" with a real server answer |
| **L3.** Starter Pack containing Cash. A developer product can be bought more than once, so a one-time pack needs your server gate | Clear first purchase | Saved flag | Repeat purchase | Second attempt is refused |
| **L4.** Per-player purchase rules through `PolicyService:GetPolicyInfoForPlayerAsync`. No universal CanBuyRobux flag exists; a policy error means unknown, not eligible | Compliance | Small | Getting it wrong on minors | Mock restricted and error states |

**Honesty rules kept:** BEST DEAL, SAVE and strikethrough are suppressed in normal preview presentation and only appear as a marked PREVIEW VALUE fixture until real comparable prices justify them. No countdowns, no fake counts, no paid randomness, no gift button (native pass gifting is unverified). VIP's offline cap is an economic benefit, so the card says "No boost to driving or racing" and states the cap, rather than "no gameplay advantage".

## 2. Save fields (each needs Adam's go-ahead first)

`TutorialStep`, `TutorialDone`, Shop "seen" state if wanted, group reward claimed, customization owned and equipped.

## 3. Tutorial analytics

`AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields)`, server only and in published games only. Proposed stable steps 1 to 12 mapped to tutorial 0 to 11. Skip is never logged as completing the rest. A Studio spy can check intent, not delivery.

## 4. Group reward (M16)

Join uses `GroupService:PromptJoinAsync` on a deliberate press; membership `Player:IsInGroupAsync`. **Yours:** server-side membership validation, once-only grant, the daily cap across sessions (this round is once per session; a client cannot enforce a daily cap), and the policy question: a blanket official permission or prohibition for a cosmetic join reward was not verified. **Unresolved for release.**

## 5. Missions and Goals (M13)

Fixtures in `src/client/UI/Prototype/SupportFixtures/`. Shape wanted: `{ id, templateId, text, target, progress, reward, state }` where state is `active | ready | claimed`, plus goals `{ id, text, done }` and a server refresh time. Authority: you. Open: whether a ready mission is replaced on claim or on refresh, and whether a claimable reward survives a daily refresh (Lane 3 assumes it does).

## 6. Welcome back (M14)

Wanted: `{ amount, secondsAway, secondsEarned, capSeconds, isVip }`. Cash is already in the balance when the card appears; COLLECT never grants. Data unavailable is never shown as $0.

## 7. Portal unlock (M12)

Wanted per World: `{ locked, requirements = { { kind, current, needed } }, roster = { { id, rarity, owned, name? } }, ownedStarters }`. The brief's example and the outline disagree on which World's cars count; the fixture is labelled and the rule is yours.

## 8. Stunt Circuit and customization (M17)

Wanted: medal thresholds (measured with real physics), time saving, weekly leaderboard, car Speed, Jump and Grip, owned paints, decals and wheels, equip state. All medal targets on screen are PREVIEW and do not set a threshold.

## Lane 3 meanwhile

Everything stays a labelled fixture. Nothing here reads or writes saved data.

## Replies

### Brian L
