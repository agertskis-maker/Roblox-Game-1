---
title: Round 2 HUD — layout, regions and states (UI spec)
tags: [design, ui, spec, lane3]
status: draft; updated per work package
date: 2026-10-23
---
# Round 2 HUD spec (Lane 3, preview)

Ledger [[hud-round2]]. Builds on [[hud-arcade-rebuild]]. Landscape only; Studio mocks without a Figma step (Adam's
task-scoped exception). Design px inside the virtual device frame; the frame is not the game's final scale.

## 1. Layout matrix (landscape only)
| Frame | Size | Insets (assumed, documented) | Notes |
|---|---|---|---|
| Desktop | 1920 × 1080 | top 58 | no touch zones |
| Tablet | 1180 × 820 | top 58, bottom 20 | touch zones: thumbstick lower-left 40% × 45%, Jump |
| PhoneLandscape | 844 × 390 | top 44, bottom 21, left/right 47 | both notch sides symmetric |
| PhoneSmall | ≈ 740 × 360 | as above | smallest practical viewport |
| PhoneLandscapeLeft / Right | 844 × 390 | notch on one side (asymmetric left/right insets) | assumptions, not measurements |
PhonePortrait is **removed** (S1). The window may be resized; nothing assumes one fixed size.

## 2. Placement (resolved together)
| Region | Home | Run |
|---|---|---|
| Top-left under core UI | — | compact **Cash** (no coin counter, no owned count) |
| Top-centre | tutorial / banner | **route line** (five stations, marker, callout, BEST badge) |
| Top-right | red labelled Settings | Settings + RIDING chip |
| Left menu | Shop / Garage (with `n / total CARS` pill) / Missions / Music | hidden |
| Left-middle above the movement zone | — | **Stamina** (when the demo is on) |
| Left, separate compact region | — | claimed tray |
| Bottom-left | big green **Cash** + earning line | — |
| Bottom-centre | — | **ENGINE HEAT** (the original panel) |
| Bottom-right | — | **Hop** (clear of Jump) |
| Beside the rider | — | **Keys** |
Safe regions to keep clear: the protected road-ahead rectangle, the touch zones, the ridden car, the next target, the
upcoming landing zone and near hazards. The capture ribbon never overlaps Cash. When space runs short, secondary
information compacts (an intentional collapsed tray) instead of shrinking core numbers.

## 3. Surfaces
One arcade family: strong readable outline, coloured surface, purposeful depth; one heavy outline per nesting chain.
Hit targets ≥ 48 design px (56 for primaries); text ≥ 16 design px (Heat's title tab on phones is the one documented exception).

## 4. States and precedence (filled in as built)
- Hop button: **OutOfStamina > Cooldown > NoTarget > BestTiming > Ready** (an unavailable state never advertises best timing).
- Run-time ordering: warning > pending capture > confirmed capture > run end > Results.
- Reduced motion (`GuiService.ReducedMotionEnabled` + the preview-only override): steady states, short fades, no shake, bounce, flight or spin.
