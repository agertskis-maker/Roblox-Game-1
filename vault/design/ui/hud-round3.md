---
title: Round 3 HUD, cards and audio — build spec
tags: [design, ui, spec, lane3]
status: awaiting final visual acceptance (Adam). Not an approved mock.
date: 2026-10-26
---
# Round 3 build spec (Lane 3 preview)

Ledger [[hud-round3]]; history [[hud-round2]] and `vault/design/ui/hud-round2.md`. **No Figma mock exists for these pieces** (Figma is signed in on a View seat and no "Car Hop UI" file link is on record;
see the ledger). They were specified here and drawn in Studio from code, and are recorded as *awaiting final visual acceptance*, not as historically approved mocks. Where the repo spec and a later
Adam decision disagree, Adam's decision wins. Values marked TOKEN CANDIDATE live as constants at the top of the named module until Adam approves them.

## 1. Distance pill (`Run/RouteLine.luau`, `Run/RouteMath.luau`)
One pill, 327 x 52 design px, top 12, identical on every frame (stable size, fixed boxes: distance right-aligned in a 120 px box, area name and a hint line left-aligned in a 160 px box, tabular digits).
Left: distance in gold ("821 m"). Right: area name and, under it, "Next in 73 m" (the area **ahead**) or "You are here" when nothing lies ahead (the last area of a plan that does not repeat). Metres to 99,999 m, then the approved km format.
Wording is two lines, not Adam's one-line example, because one line needs about 440 px (reversible: decision below). Name falls back to the district's short label, never to tiny text or an ellipsis. Removed: landmark thumbnail row, progress line, avatar marker, BEST badge, LAP tag, NEW BEST.
Domain functions in `RouteMath` are kept (Results and records may use them). The orange arrival popup (`DistrictBanner.luau`, event `DistrictEnter`) is kept and now starts 10 px below the pill. Other orange-ish candidates, all kept: the world-space "WELCOME TO" gateway span (navy board), `World/RareReveal.luau`, `Run/Milestones.luau`.

## 2. Landing label (`Run/RideChip.luau`)
The permanent RIDING chip is gone. On a confirmed landing the label shows the full rarity word and the car name for 1.5 s, fades over 0.25 s, replaces any earlier label, ignores repeats of the same identity, wraps long names at 16 px, clears on run end or loss of the ride, steady fade in reduced motion.
Shown only when the ridden car's nameplate is not (nameplate wins: while a capture is Holding or Pending, or the SECURED stack is up, the label is withheld). Size 200 x 68 (160 wide on PhoneSmall), under Settings, outside the protected road rectangle. The Settings button stays in this module.

## 3. Keys ring (`Run/KeysLock.luau`)
One continuous ring replaces the eight segments. Fill origin **12 o'clock, clockwise**. Slate track, yellow-gold fill; key-in-lock icon centred; HOLD ON / ALMOST! / SECURING above; percentage below. Built from `Frame` + `UICorner` + `UIStroke` + `UIGradient` (two clipped half rings, no uploaded art); a separate closed ring at exactly 100%.
The shown fill eases to the supplied progress in 0.07 s and never passes it; one bounded pulse (x1.07, 0.18 s) at the first close, then a steady brighter ring 2 px thicker; reduced motion skips the pulse. Full-but-unconfirmed holds a calm pending state (a quiet note, never SECURED). Capture time is **not** changed.

## 4. Stamina (`Run/StaminaMeter.luau`, `Run/StaminaBolt.luau`)
Sharp zigzag bolt hero icon with a thick dark edge, number kept, ten simple pips. Thresholds: 6-10 yellow, 4-5 orange, 1-3 red with a restrained pulse, 0 depleted (grey broken bolt, OUT OF STAMINA, Hop unavailable). No new forced run end; empty taps throttled; reduced motion steady strong glow.
(Details and measured clearance are filled in from the W3a report in [[hud-round3]].)

## 5. Cash and Hop icons (`CurrencyCounter/CashIcon.luau`, `Prototype/Icons2.luau`, `Run/HopButton.luau`, `Run/HopState.luau`)
Cash: one paper band that wraps the whole bundle (lit over the top note, a thin fold line, a darker front section, ends shaded where they turn behind and under); the Home line art (`CashStack`) has one ribbon over the fanned bills. Size unchanged.
Hop: original side-view car + one upward hop arc with an arrowhead (`HopCar` replaces `HopFigure`). States now differ by fill, overlay and word: Ready teal HOP; Best timing teal + gold ring; Cooldown dark sweep + WAIT; No target blue-grey, hatched, NO CAR; No Stamina rose, crossed bolt, NO / STAMINA.

## 6. ENGINE HEAT (`Run/HeatPanel.luau`, Heat region of `Run/RunLayout.luau`)
`HeatGauge` is the approved original, byte-identical to `main`; only uniform scale and anchoring change. One static anchor (AnchorPoint 0.5, 1; centred on the full viewport, pulled in only to stay inside the safe area; bottom margin 8). Scale rule and the measured coverage table: `vault/design/specs/hud-round3-heat-coverage.md`.

## 7. Garage (`Cards/*`, `Screens/CardDetail.luau`, `Screens/GarageMock.luau`)
Large cards only (the small duplicate row of the trading sheet is removed; the claimed-run tray is untouched). Names never ellipsised; the full rarity word at 16 px; a fixed shared header height per row. Sort: RAREST, LAP PAY, NEWEST on a copy, unknowns last, stable ties, state shown by word + check + underline. Detail: image, full name, full rarity word, WORLD, LAP PAY, three finish chips (OWNED / NOT OWNED / ?), nothing else.

## 8. Settings and audio
Settings has a Haptics row (default ON, "Buzz when you get a car" / "Buzz is off" / "Not available on this device"). Music fades finite (<= 0.4 s out, <= 0.3 s in), no polling; Keys chime is a ladder of at most four discrete notes (0.55 s each, >= 0.25 s apart, 5 semitones at most); the fanfare plays once per confirmed capture and ducks the music; one `MIX` table holds every level.

## 9. Overlays (`Home/ToastStack.luau`, `Screens/ResultsCard.luau`, `Run/Milestones.luau`)
Restyled onto `Arcade.surface` (one thick outline, gloss): bright plates, gold milestone band. In Run the toast stack sits in the Upper row under the pill and shows as many toasts as fit above the protected rectangle.

## Decisions I made (reversible)
Two-line pill wording; ring fills clockwise from 12 o'clock; Heat floor measured in real device pixels (one constant); toasts move to the Upper row in Run; haptics ON by default; sort has no default (collection order); synthetic acquisition numbers in the harness so NEWEST is visible.
