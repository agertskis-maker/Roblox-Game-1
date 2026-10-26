---
title: Round 3 — original ENGINE HEAT: centring, scale rule, coverage of the protected road
tags: [design, spec, heat, lane3, round3]
status: PREDICTED offline (same formulas, re-implemented in Node); Studio numbers filled by the lead after the scenario run
date: 2026-10-26
---
# Original Heat, Round 3 (R3-H): centring, scale and honest coverage

**Read this first.** Every number below marked *predicted* was computed offline by a small Node re-implementation of the
`RunLayout` Heat region and the `Screen` frame definitions. It is **not Studio output.** The scenario
`Heat: placement, scale and coverage (all frames)` prints the same table from the live game as `HEATROW|...` lines; the lead
pastes those into the "Studio" column and replaces anything that differs. Until then nothing here is "verified in Studio".

Inventory facts (checked 2026-10-26, read-only):
- The mounted path is still `Prototype/Run/HeatPanel.luau` -> `RunHud/HeatGauge.luau` (unmodified). `HeatGauge.luau`,
  `RunHud/init.luau`, `AlarmClock.luau` and `Tokens.luau` are byte-identical to `main` (`git hash-object` equals
  `git rev-parse main:<path>` for all four).
- There is **no gameplay Heat code** anywhere: `src/client/Run` and `src/shared/Run` do not exist on this branch, `src/server`
  holds only `vendor/ProfileStore`, and `git grep` over `main`, `origin/main` and every `feature/*` ref finds Heat only in UI
  (Tokens, RunHud, the Prototype HUD) plus one presentation-only mention in `CarPreview` on `feature/lane3-first-car-downtown`.
  Lane 1 still owns Heat rules; the panel is driven by a fixture. [[hud-round2-heat-inventory]] is the Round 2 snapshot.

## What was changed (uniform scaling and anchoring only)
Silhouette, title tab, internal arrangement, typography, thresholds (0.6 / 0.85), labels and animation are the original's.
No timing or threshold changes. HOP NOW! stays hidden at zero Stamina and after a dismount, as in Round 2.

| Topic | Rule (code: `RunLayout` HEAT PANEL REGION, `HeatPanel.layout`) |
|---|---|
| Anchor | one static anchor in a container: `AnchorPoint (0.5, 1)`, `Position (0.5 + shift / width, 0, 1, -8)`; written only when the layout changes, never per frame; the original's root sits at the container's bottom centre and is scaled about that same point, so a shake, growth or alarm cannot move it |
| Centre | the **full viewport** centre (device frame centre), not the safe area's own centre. The two differ by `(right inset - left inset) / 2`: 0 px on four frames, **-13 px (Left) and +13 px (Right)** on the notch frames. The panel is pulled inward only if it plus its 10 px halo would leave the safe area (`pulled`, 0 px on every frame today). |
| Scale | the **smallest** scale at which the smallest Heat text (the ENGINE HEAT title tab, 16 design px) still reads at 16 **real** (device) px: `k = 16 / (16 x HudScale)`, at most 1 (the approved size) and at most what fits the safe width. HudScale is 1.5 on Desktop and Tablet, 1.0 on every phone frame |
| Bottom margin | 8 design px (unchanged since Round 2) |
| Stage growth | the original's 1.05 / 1.10 / 1.12 (about the bottom centre) is kept; the cap given to `gauge:setLayout` keeps the card and its outline 4 px clear of Hop and 24 px inside the safe edge. Only PhoneSmall is capped (1.025, Hop is 8 px from the panel) |
| Smoke | the original drift (1.0) on every frame |

Consequence of the rule: Desktop and Tablet get **0.667** (the panel is then 320 x 92 real px, the same physical size as on a
phone); **every phone frame gets 1.000**, because the title is exactly 16 px there and cannot go lower. Round 2 used
1.0 / 0.92 / 0.89 and, on phones, a title of 14.2 to 14.7 px.

## Method (same on every frame)
Device px, relative to the device frame's top-left. *Panel* = everything drawn at rest (Calm): card + 3 px outline + shadow
**and the title tab** that rises 16 px above the card (13 px half-height + 3 px outline). A stage adds its growth, the
alarm halo (10 px), the two sirens and, in Meltdown, the smoke plume at its worst-case reach (47 px above the card, faint at
the top). *Protected* = `RunLayout.protectedRect(profile)`.

- **roadOverlapPct** = area(panel intersect protected) / **area(protected road)**. Headline figure.
- **panelInsideRoadPct** = the same intersection / **area(panel)**. This is the "47% of the panel" denominator of Round 2.
- Areas are exact unions of the pieces. The piece list is a model of what `HeatGauge` draws; the scenario checks the model
  against the live instances on every frame (card, outline, shadow, tab) and, in the alarm scenario, against the live halo,
  siren glows, tab and smoke puffs.
- Round 2 reported the first figure **for the card alone** at 1.0 / 0.92 / 0.89 in a placement that was shifted clear of the
  thumbstick zone: Desktop 0%, Tablet 6%, PhoneLandscape 22%, notch frames 21 to 23%, PhoneSmall 30%. That is a historical
  reference, not a baseline.

## Table (PREDICTED, offline; steady = Calm, panel including the title tab)
`HEATROW|frame|scale|x|y|w|h|centreOffsetPx|roadOverlapPct|panelInsideRoadPct|thumbOverlapPx` (x, y, w, h = panel box, device px)

| Frame (device px) | scale | x | y | w | h | centre offset | road overlap | panel inside road | thumb overlap |
|---|---|---|---|---|---|---|---|---|---|
| Desktop 1920 x 1080 | 0.667 | 796.9 | 959.9 | 326.2 | 112.1 | 0.00 | 0.0% | 0.0% | 0 (no zone) |
| Tablet 1180 x 820 | 0.667 | 426.9 | 679.9 | 326.2 | 112.1 | 0.00 | 0.8% | 3.7% | 45.1 |
| PhoneLandscape 844 x 390 | 1.000 | 259.0 | 253.0 | 326.0 | 112.0 | 0.00 | 41.1% | 54.2% | 78.6 |
| PhoneSmall 740 x 360 | 1.000 | 207.0 | 224.0 | 326.0 | 112.0 | 0.00 | 48.9% | 51.7% | 89.0 |
| PhoneLandscapeLeft (notch left) | 1.000 | 259.0 | 253.0 | 326.0 | 112.0 | 0.00 | 39.2% | 53.4% | 78.6 |
| PhoneLandscapeRight (notch right) | 1.000 | 259.0 | 253.0 | 326.0 | 112.0 | 0.00 | 39.2% | 53.4% | 78.6 |

Studio column: *filled by lead after the Studio run* (paste the `HEATROW|` lines).

Protected rectangle (device px, x, y, w, h; `HEATPROT|` lines): Desktop 576.0, 466.8, 768.0, 459.9. Tablet 354.0, 354.8,
472.0, 333.9. PhoneLandscape 257.0, 180.5, 330.0, 136.5. PhoneSmall 226.6, 166.0, 286.9, 126.0. Left 264.3, 180.5, 341.4,
136.5. Right 238.3, 180.5, 341.4, 136.5. (On the notch frames the rectangle is centred on the safe area and the panel on the
viewport, 13 px apart: the steady figures come out equal, the Meltdown figure differs by 2.3 points because the smoke plume
sits left of the panel.)

The `centre offset` column is the live card centre minus the viewport centre; predicted 0.00 on every frame (the scenario
accepts up to 1 px). Safe-area centre minus viewport centre, the unavoidable constraint if the safe centre were chosen
instead: 0, 0, 0, 0, **-13**, **+13** px; honouring the viewport costs nothing against the safe bounds on any frame.

## Alarm stages (PREDICTED; growth, halo, sirens, smoke included; `HEATSTAGE|` lines)
road overlap % (growth in brackets):

| Frame | Warning | Critical | Meltdown |
|---|---|---|---|
| Desktop | 0.0 (1.05) | 0.0 (1.10) | 0.2 (1.12) |
| Tablet | 1.4 | 4.1 | 6.1 |
| PhoneLandscape | 45.5 | 53.4 | 57.5 |
| PhoneSmall | 51.0 (1.025) | 55.0 (1.025) | 56.7 (1.025) |
| PhoneLandscapeLeft | 43.8 | 53.3 | 56.6 |
| PhoneLandscapeRight | 43.8 | 53.3 | 58.9 |

The alarm halo is decoration and reaches up to 3.2 px below the safe area on the phone frames (8 px bottom margin against a
10 px halo, as in Round 2); every other part of the panel stays inside the safe bounds in every stage.

## Legibility versus clearance: the measured tradeoff
Legibility was chosen (title and labels at least 16 real px, Adam's number). On phones that means no shrinking at all, and the
panel then covers **39 to 49%** of the proposed protected road rectangle. Scale alone cannot fix it; predicted road overlap
on PhoneLandscape for a **centred** panel:

| scale | 1.00 | 0.92 | 0.89 | 0.80 | 0.70 | 0.60 | 0.50 |
|---|---|---|---|---|---|---|---|
| title px (real) | 16.0 | 14.7 | 14.2 | 12.8 | 11.2 | 9.6 | 8.0 |
| road overlap | 41.1% | 32.5% | 29.5% | 21.2% | 13.5% | 7.2% | 2.3% |

PhoneSmall: 48.9, 42.1, 39.5, 29.3, 19.3, 11.1, 4.7. Tablet (HudScale 1.5): 15.6, 11.4, 9.7, 5.4, 1.4, 0.0 (at 0.60, title
14.4 px). Even at 0.50 (an 8 px title) 2.3% remain, so zero overlap on a phone is not reachable by scaling without an unreadable strip,
which Adam ruled out.
Comparison with Round 2's method (card only) at the Round 2 scales, **centred**: PhoneLandscape 34.1 / 26.6 / 23.9% for
1.0 / 0.92 / 0.89, PhoneSmall 41.3 / 35.4 / 33.0%, Tablet 11.6 / 7.8 / 6.4%, Desktop 0%. So Round 2's 22 / 30 / 6% were
about 0.4 to 4.6 points lower than a centred card because the panel was shifted off-centre; today's gap beyond that is the
title tab and outline (4 to 8 points) and the larger phone scale (1.0 instead of 0.89 to 0.92). The headline difference is therefore the honest accounting plus the
16 px floor, not a regression of the layout.

**Smallest further changes (a proposal for Adam; none applied):**
1. **Accept and document** the phone figures, because the protected rectangle is itself a reversible proposal from the
   preview chase camera (L-05), not a camera measurement.
2. **Measure with the real camera** and move the rectangle's bottom edge. A phone-size panel at scale 1.0 clears it only if
   the bottom fraction is **0.64 (PhoneLandscape) / 0.61 (PhoneSmall)** instead of 0.84; Tablet 0.77 instead of 0.85 at scale 1.0.
3. **Bottom margin 8 -> 4 design px** gains 4 px: PhoneLandscape 41.1 -> 38.2%, PhoneSmall 48.9 -> 45.7% (small; changes the
   Round 2 margin, so not applied).
4. Hiding only the title tab on phones was offered in Round 2 and is **not** authorised here.

## Thumbstick zone (assumed, conservative; the panel takes no input so the overlap is visual only)
Horizontal depth of the panel box into the Thumbstick zone (device px, predicted): Tablet 45.1, PhoneLandscape 78.6,
PhoneSmall 89.0, Left 78.6, Right 78.6, Desktop none. Round 2 had a soft overlap of at most 60 design px (Tablet, PhoneSmall)
and 0 on the 844 phones by shifting the panel off-centre; strict centring is what now puts the panel over the zone on every
touch frame. Hop clearance (predicted, at the largest growth, device px): the 844 phones about 40 px (grown card edge 558, Hop at 598),
PhoneSmall about 4 px (growth capped at 1.025), Tablet about 71 px, Desktop far away.

## What was and was not verified
Verified: Selene and StyLua on the three source files and the scenario; the four approved originals are byte-identical to
`main`; predicted numbers from an independent re-implementation of the formulas. **Not verified (needs the Studio run):**
every live instance measurement (centre offset, live scale, live text px, model-vs-live bounds), the alarm sampling, the
reduced-motion and HOP NOW! states, the build-and-destroy counts, the diagnostic overlay look. See the scenarios in
`playground/hud/scripts/scenarios/Heat.luau`.
