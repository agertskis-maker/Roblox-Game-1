---
title: Round 3 ENGINE HEAT coverage (measured in Studio Play)
tags: [design, spec, heat, lane3, measurement]
status: measured (Studio Play, virtual frames; not physical devices)
date: 2026-10-26
---
# ENGINE HEAT: centring, scale and coverage

Component: `src/client/UI/RunHud/HeatGauge.luau` (the approved original, **byte-identical to `main`**), mounted by `Prototype/Run/HeatPanel.luau`; placement and scale in the Heat region of `Prototype/Run/RunLayout.luau`. Only a uniform scale and a static anchor were changed. Scenario: `Heat: placement, scale and coverage (all frames)` (36 checks PASS in Studio Play), HEATROW lines below.

**Method and denominator.** Overlap = area(panel bounds *including the title tab, outline and shadow*, intersected with the protected road rectangle) / **area of the protected road rectangle**, device px, steady state (Calm). "Panel inside road" = the same intersection / area of the panel. Round 2 quoted the card alone as a share of the protected rectangle: its figures (Desktop 0%, Tablet 6%, PhoneLandscape 22%, notch 21-23%, PhoneSmall 30%) used a different panel box and a different placement, so they are history, not a baseline. The protected rectangle is a camera *proposal*, not a measurement of a real chase camera.

**Centring.** One static anchor (AnchorPoint 0.5, 1) on the full viewport centre; centre offset is 0.00 px on every frame, after 20 layouts, three mode round-trips and every alarm stage (the shake restores its resting position exactly). On the two notch frames the safe-area centre differs from the viewport centre by 13 px; the panel keeps the viewport centre and stays inside the safe area (pulled 0 px).

## Final table (Studio Play, 2026-10-26)
| Frame | Scale | Title text | Panel x, y, w, h (px) | Overlap with protected road | Panel inside road | Thumbstick zone overlap |
|---|---|---|---|---|---|---|
| Desktop | 0.667 | 16 px | 796.9, 959.9, 326.2, 112.1 | 0.0% | 0.0% | none |
| Tablet | 0.667 | 16 px | 426.9, 679.9, 326.2, 112.1 | 0.8% | 3.7% | 45.1 px (visual only) |
| PhoneLandscape | 0.813 | 13 px | 289.5, 273.2, 265.0, 91.1 | **22.3%** | 44.6% | 48.1 px |
| PhoneSmall | 0.813 | 13 px | 237.5, 244.2, 265.0, 91.1 | **30.8%** | 49.2% | 58.5 px |
| PhoneLandscapeLeft (notch) | 0.813 | 13 px | 289.5, 273.2, 265.0, 91.1 | 21.6% | 44.6% | 48.1 px |
| PhoneLandscapeRight (notch) | 0.813 | 13 px | 289.5, 273.2, 265.0, 91.1 | 21.6% | 44.6% | 48.1 px |

Stage growth (Warning 1.05, Critical 1.10, Meltdown 1.12) raises the phone figures during an alarm (see the HEATSTAGE lines in `results/regression-run-1-small-viewport.txt`: at the 16 px floor Meltdown reached 57-59% on phones).

## The tradeoff, with the measured alternatives (PhoneLandscape, title tab included)
| Phone scale | Title text | Overlap |
|---|---|---|
| 1.00 (the 16 px minimum) | 16 px | 41.1% (PhoneSmall 48.9%) |
| 0.92 (Round 2) | 14.7 px | 32.5% |
| 0.89 (Round 2) | 14.2 px | 29.5% |
| **0.813 (this round, provisional)** | **13 px** | **22.3%** (PhoneSmall 30.8%) |

Seen in the real city view: `Car-Hop-Art/review/hud-round3/stills/r3-heat-floor16-scale1.00-phonelandscape-city.jpg` (the panel covers the ridden car and the near lanes) against `r3-heat-floor12-scale0.75-phonelandscape-city.jpg` and the final `r3-final-phonesmall-combined-city-heat13-keys60-stamina4.jpg`.
**Decision needed from Adam:** the phone floor is 13 px (the title tab; the stage label 14.6 px). That is below the project's approved 16 px minimum for ordinary text, so it is provisional and one constant (`RunLayout.HeatTextFloor`; Desktop and Tablet keep 16 via `HeatTextFloorLarge`). Scale cannot reach zero overlap without an unreadable strip (PhoneLandscape still has 2.3% at scale 0.50, an 8 px title). Smallest further changes, none applied: accept; measure the real camera and move the protected rectangle's bottom edge; cut the 8 px bottom margin to 4 (about 3 points).
Heat vs HOP NOW!: HOP NOW! stays hidden at zero Stamina (Round 2 behaviour, scenario `Heat: reduced motion and HOP NOW!` 8/8 PASS).
