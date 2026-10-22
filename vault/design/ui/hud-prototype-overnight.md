---
title: HUD prototype (overnight preview) — screens and values
tags: [design, ui, lane3, preview]
status: preview — Figma transfer and owner approval pending
date: 2026-10-22
---
# HUD prototype, overnight preview (2026-10-22)

**Figma transfer and owner approval pending.** Built Studio-first under Adam's one-night UI
preview exception ([[hud-downtown-overnight]]). Not production-approved; the Figma-first rule
([[0012-figma-ui-workflow]]) still applies before anything ships. The Figma file was not touched
overnight: the month's read budget is recorded as used up on the island branch
(`figma-reads.md` there: 4 + 2 of 6 by the sign mocks), and the rule says to report the count to
Adam before any read, which a silent run cannot do. Candidate frames are the Studio captures in
`Car-Hop-Art/review/hud-downtown/hud/shots/`.

Code: `src/client/UI/Prototype/` (modules), `playground/hud/` (bootstrap, fixtures driver, debug
panel). Architecture and component contract: [[hud-prototype-architecture]].

## What is approved and reused unchanged
Run HUD revision 4 (2026-10-20): the CurrencyCounter + CashIcon (Cash look, Format.cash), Distance
option B (flag + outlined number), the ENGINE HEAT panel bottom centre, the scale rule (short side
/ 390, 1.0–1.5), Fredoka One 36/24/18/16, touch 48/56, Reduce Motion = GuiService plus the
preview-only override.

## Preview values (all reversible, all in PreviewTokens.luau or the component headers)
| Item | Value |
|---|---|
| Colour roles | Ink #16243F, Panel #FFF6E3, Cash button light/deep #8BFF6E/#18B23A, Primary #FFA41F→#FF5E00, Keys #FFD24A→#F2A900, Hop teal #78FFE6/#00A8A0 (Hop only), Settings navy |
| Rarity | Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold; label + 1–5 pips always shown |
| Variants | Gold, Chrome, Rainbow as a finish ring + ribbon word, never a rarity |
| Outline / shadow | 3 px navy, 4 px shadow down, top-left highlight on major controls only |
| Menu buttons | 64 design px body (96 px at 1080p), Settings 48 px gear without label; desktop column, tablet/phone row |
| Cash | approved counter; earning line "+$120 / lap" (FIXTURE; Brian L owns the rate); exact value tooltip 2 s on tap/hover/focus |
| Big-gain celebration | gain ≥ max(10% of the previous shown balance, $500), 8 s cooldown; bounded 6 sparks; none in reduced motion |
| Tutorial banner | yellow, TUTORIAL tab, objective + (n/goal), 8 px progress strip, hint line, green Done state with ≤16 confetti |
| Toasts | max 2 visible, 2.5 s, queue 6, duplicates merge "×2"; Success green, Info cream/navy, Unlock gold |
| Lap Pay | BillboardGui +$N, ~3 studs up, 1.2 s, ≤120 studs, ≤4 visible, combined when overlapping |
| Prompts | custom ProximityPrompt card; key cap E / gamepad X / TAP; hold ring for HoldDuration |
| Car card | 200 × 280; ViewportFrame proxy turning ~20°/s on one shared ticker, ≤6 spinning; static 35° view in reduced motion; owned / unowned silhouette / loading / unavailable / selected / variants |
| Run | approved layout default; PROPOSAL variant: 5-segment Heat bar top left (approved Heat words in capitals) |
| Keys | gold ring outside the landing view (middle 40% width × 45% height kept clear); HOLD ON → CONFIRMING… → only an explicit Confirmed event celebrates |
| Capture | YOU GOT THE KEYS!, rarity burst ≤12, card with 6° tilt; compact ribbon when the card would cover the landing view (phones, tablet); card deferred to Results |
| Hop | 96 px touch button beside (not over) the reserved Jump zone, cooldown sweep; desktop "SPACE: HOP" hint; preview intent only |
| Foot Dash | sneaker + draining arc + DASH |
| Results | RUN COMPLETE ribbon, Distance / Coins / Best rows, NEW BEST stamp, claimed cards, earnings count-up, RETRY (primary) / GO HOME; skippable; one transition per press |
| Motion | press 0.10 s, release 0.14, panel 0.22 in / 0.16 out, count-up 0.4–0.8 s, pop 1.10 |
| Sounds | typed hooks, silent (no asset inserted), preview SoundGroups Lane3PreviewUI / Lane3PreviewMusic |

## Open questions for Adam
1. Heat during a run: keep the approved bottom-centre panel or try the top-left bar (proposal)?
2. Settings gear without a label on the Home menu?
3. The approved counter shows its own "+$N" under Cash and the prototype adds a merging chip: keep one.
4. Shop pass concepts are from the outline's delegated list, labelled "not approved", price pending.
