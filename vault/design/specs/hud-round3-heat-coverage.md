---
title: Round 3 ENGINE HEAT coverage (measured in Studio Play)
tags: [design, spec, heat, lane3, measurement]
status: measured (Studio Play, virtual frames; not physical devices)
date: 2026-10-26
---
# ENGINE HEAT: centring, scale and coverage

Component: `src/client/UI/RunHud/HeatGauge.luau` (the approved original, **byte-identical to `main`**), mounted by `Prototype/Run/HeatPanel.luau`; placement and scale in the Heat region of `Prototype/Run/RunLayout.luau`. Only a uniform scale and a static anchor were changed. Scenario `Heat: placement, scale and coverage (all frames)` (36 checks PASS in the final run); the full log with every HEATROW, HEATPROT and HEATSTAGE line is `Car-Hop-Art/review/hud-round3/results/regression-final.txt`.

**Method and denominator.** Overlap = area(panel bounds *including the title tab, outline and shadow*, intersected with the protected road rectangle) / **area of the protected road rectangle**, device px, steady state (Calm) unless a stage is named. "Panel inside road" = the same intersection / area of the panel. Round 2 quoted the card alone as a share of the protected rectangle: its figures (Desktop 0%, Tablet 6%, PhoneLandscape 22%, notch 21-23%, PhoneSmall 30%) used a different panel box and a different placement, so they are history, not a baseline. The protected rectangle is a camera *proposal*, not a measurement of a real chase camera.

**Centring.** One static anchor (AnchorPoint 0.5, 1) on the full viewport centre; centre offset is 0.00 px on every frame, after 20 layouts, three mode round-trips and every alarm stage (the shake restores its resting position exactly). On the two notch frames the safe-area centre differs from the viewport centre by 13 px; the panel keeps the viewport centre and stays inside the safe area (pulled 0 px). At every scale the panel still partly hides the ridden car's roof, because it is centred at the bottom as asked.

## Final table (shipped: Studio Play, final build, 2026-10-26)
Adam asked for the panel "slightly bigger" after the first measured version (13 px phones, 16 px Desktop/Tablet); this is the result of that step (14 px phones, 17 px Desktop and Tablet).

| Frame | Scale | Title text | Panel x, y, w, h (px) | Overlap, steady | Warning / Critical / Meltdown | Panel inside road | Thumbstick zone |
|---|---|---|---|---|---|---|---|
| Desktop | 0.708 | 17 px | 786.6, 953.1, 346.7, 119.1 | 0.0% | 0.0 / 0.0 / 0.4% | 0.0% | none |
| Tablet | 0.708 | 17 px | 416.6, 673.1, 346.7, 119.1 | 1.7% | 3.1 / 6.2 / 8.6% | 7.1% | 55.4 px (visual only) |
| PhoneLandscape | 0.875 | 14 px | 279.4, 266.5, 285.2, 98.0 | **28.0%** | 32.3 / 42.0 / 47.3% | 48.2% | 58.2 px |
| PhoneSmall | 0.875 | 14 px | 227.4, 237.5, 285.2, 98.0 | **38.1%** | 42.0 / 49.5 / 53.2% | 52.6% | 68.6 px |
| PhoneLandscapeLeft (notch) | 0.875 | 14 px | 279.4, 266.5, 285.2, 98.0 | 27.1% | 31.3 / 39.9 / 44.4% | 48.2% | 58.2 px |
| PhoneLandscapeRight (notch) | 0.875 | 14 px | 279.4, 266.5, 285.2, 98.0 | 27.1% | 31.3 / 39.9 / 45.5% | 48.2% | 58.2 px |

## The tradeoff, with the measured alternatives (PhoneLandscape, steady, title tab included)
| Phone scale | Title text | Overlap | Notes |
|---|---|---|---|
| 1.00 (the project's 16 px minimum) | 16 px | 41.1% (PhoneSmall 48.9%) | the panel covers the ridden car and the near lanes |
| 0.92 (Round 2) | 14.7 px | 32.5% | |
| 0.89 (Round 2) | 14.2 px | 29.5% | |
| **0.875 (shipped, slightly bigger)** | **14 px** | **28.0%** (PhoneSmall 38.1%) | |
| 0.813 (the first version this round) | 13 px | 22.3% (PhoneSmall 30.8%) | measured earlier; Meltdown 57% was at scale 1.0 |

Matched frames (same spot on the route, PhoneLandscape): `Car-Hop-Art/review/hud-round3/stills/r3-heat-matched-phonelandscape-s700-title16px-scale1.00.jpg`, `...title14px-scale0.89.jpg`, `...title13px-scale0.81...jpg`, `...title14px-scale0.875-SHIPPED.jpg`.

**Confirmed final by Adam on 2026-10-28** (round 3 close-out brief; recorded in `vault/design/visual-direction.md`): the phone floor (14 px) is an approved exception to the 16 px minimum for ordinary text; it is one constant (`RunLayout.HeatTextFloor`; Desktop and Tablet use `HeatTextFloorLarge`, 17). Scale cannot reach zero overlap without an unreadable strip (PhoneLandscape still has 2.3% at scale 0.50, an 8 px title). Smallest further changes, none applied: accept; measure the real camera and move the protected rectangle's bottom edge; cut the 8 px bottom margin to 4 (about 3 points). HOP NOW! stays hidden at zero Stamina (Round 2 behaviour; scenario `Heat: reduced motion and HOP NOW!` 8/8 PASS).
