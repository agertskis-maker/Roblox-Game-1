---
title: HUD reference study - mobile racing and runner games
tags: [research, hud, mobile, car-hop, lane-3]
status: research
---

# HUD reference study: mobile racing and runner games

Role 2 research for the Car Hop run HUD. Every source was captured on **2026-10-22**. The study images (not for use in the game) are in `C:\Users\agert\Documents\Car-Hop-Art\references\hud-downtown\racing\`. Fractions were measured on those downloads and are accurate to about ±2 %. This note approves nothing. Fonts and touch targets stay as recorded in `vault/design/visual-direction.md`.

## Sources

| ID | Source | Provenance | Files |
|---|---|---|---|
| S1 | [Subway Surfers, App Store](https://apps.apple.com/us/app/subway-surfers/id512939461) | Publisher screenshots, portrait, 460x1000 | `subway_appstore_02/03/04.jpg` |
| S2 | [Rodeo Stampede, App Store](https://apps.apple.com/us/app/rodeo-stampede-sky-zoo-safari/id1047961826) | Publisher screenshots, portrait, 462x1000 | `rodeo_appstore_1/4.jpg` |
| S3 | [Hill Climb Racing 2, App Store](https://apps.apple.com/us/app/hill-climb-racing-2/id1146465836) and [Fingersoft page](https://fingersoft.com/games/hill-climb-racing-2/) | Marketing composites, landscape, headline text added | `hcr2_appstore_physics.jpg` (1300x601), `hcr2_screen_01.png` |
| S4 | [Beach Buggy Racing 2, Vector Unit](https://www.vectorunit.com/beach-buggy-racing-2) | Official gallery, 1500x844 | `bbr2_shield.png`, `bbr2_egypt_01.png` |

The Fingersoft media page (https://fingersoft.com/media/) holds only logos and office photos. The BBR2 gallery images show **no HUD**. None of the sources shows a Results screen. **A still image cannot show animation**, so nothing here establishes how a sweep, arc, pulse or celebration moves, or how long it lasts.

## Observations

**O1. Gauges sit in the top band and the lower half stays clear. (S1)**
- Observed: the pause button (top-left) and the score and coin pills (top-right) all sit in the top ~10.5 % of the screen. The runner occupies the 50-90 % height band.
- Interpretation (inference): reading happens at the top and steering at the bottom, so the two never compete.
- Apply: in portrait 390x844, put distance, coins, Heat and the ride chip in the top 12 %, below the top-bar inset. In the bottom 40 %, put only the Hop and Foot Dash controls.
- Limits: Subway is played with swipes and has no on-screen buttons.

**O2. Main and secondary numbers differ clearly in size. (S1)**
- Observed: the score pill is ~39 % of the screen width and its digits are ~3 % of the height. The coin pill sits below it at ~17 % width with smaller digits. Both are right-aligned.
- Apply: distance at the 36 display size, top centre. Coins at the 24 value size, at least 8 px below the distance, and no wider than about half of it.
- Limits: the screenshots are staged.

**O3. Numbers sit on dark translucent pills. (S1)**
- Observed: white bold digits on rounded navy pills over busy scenes. The icons keep their own colours.
- Apply: put every HUD number on an 80-85 % opaque dark panel with a 2 px stroke. Aim for a contrast ratio of at least 4.5:1, and test it over the brightest Downtown sky and road.
- Limits: panel opacity was estimated from JPEGs.

**O4. The multiplier is a chip attached to the value it changes. (S1)**
- Observed: a yellow "x2/x6/x9" and a star sit at the left end of the score pill.
- Apply: show the Heat stage number as a chip at the end of the Heat bar, beside the flame icon. Give the current-ride chip (top-right) the same pill style.
- Limits: the multiplier is an economy mechanic, so only its layout is taken.

**O5. A minimal HUD: outlined distance and pause. (S2)**
- Observed: "30m" and "320m" appear top-left as white bold text with a dark outline and no panel, ~18 % of the width and ~4 % of the height. Pause is top-right. Nothing else is on screen.
- Interpretation (inference): during the run, the world itself is the interface.
- Apply: during a hop, show only distance, Heat and the controls. Coins pop up as "+N", then dim to 60 %. On a first run, show at most four HUD elements plus the controls.
- Limits: Rodeo uses a top-down camera, so the background is calmer than a city road.

**O6. A dashed ground ring marks the target. (S2)**
- Observed: a dashed yellow ellipse lies on the ground near the rider, ~52 % of the width, in the 62-77 % height band.
- Interpretation (inference): the ring marks where an action will land and is drawn in the world rather than on the HUD. Its exact game meaning is not confirmed.
- Apply: draw the Hop target ring in world space (a part or SurfaceGui), not on the HUD layer. Make it a dashed teal and white ring on the target car's roof, about the width of the roof. Give it a white outline of about 15 % of the ring width so it shows on both light and dark paint.
- Limits: whether the ring pulses or rotates cannot be seen in a still.

**O7. One accent colour means "act here". (S2)**
- Observed: only the lasso and the ring use saturated yellow.
- Apply: use teal only for hop cues (the ring and the Hop button's ready state). Use gold only for Keys (the ring, HOLD ON, YOU GOT THE KEYS!). Do not use either colour on Heat.

**O8. Gauges sit in the centre and controls in the corners. (S3)**
- Observed: the three dials span x 27-70 % in the bottom 31 % of the screen. The brake pedal covers x 4-17 % and the gas pedal x 77-97 %. Each pedal is at least 10 % of the width from the nearest dial. The distance "450m" sits inside a dial, in yellow.
- Interpretation (inference): thumbs never cover a gauge.
- Apply: put the Keys ring at x 40-60 %, at least 10 % of the width away from both thumb zones. Size it at no more than 14 % of the short side (about 55 px on both 844x390 and 390x844). Place it above the landing view: about 60-66 % of the height in portrait and about 70 % in landscape. Check it against the real camera so it never covers the landing roof.
- Limits: HCR2 is a side view, so the ground under its dials is not gameplay. In Car Hop it is. These images are composites.

**O9. A segmented scale with a red zone. (S3)**
- Observed: the fuel dial has a red segment at E and clear tick marks.
- Apply: build the Heat bar from 4-6 segments with marks at the stage boundaries, a flame icon and a stage numeral. Never show danger by red alone. Stage changes must not flash, and they need a reduced-motion version.
- Limits: dial motion is not visible.

**O10. Large edge-anchored pedals. (S3)**
- Observed: each pedal is ~13-20 % of the width and ~23-38 % of the height, flush with the bottom corners.
- Apply, landscape: a Hop button 96-112 px across, its centre ~120 px from the right edge and ~110 px from the bottom.
- Apply, portrait: a Hop button 88-104 px across, centred ~90 px from the right and ~150 px from the bottom.
- Apply, both: draw the cooldown sweep inside Hop's own circle. Put Foot Dash (64-72 px) above-left of Hop, at least 16 px away, with its draining arc around Foot Dash only.
- Limits: Roblox reserves the bottom-right corner for its jump button (see the implementation section).

**O11. The record callout sits in the world. (S3)**
- Observed: a tilted "NEW RECORD!" appears at mid-right, beside the road rather than over it.
- Interpretation (inference): a milestone anchored where it happened leaves the centre clear. It may be marketing art.
- Apply: show milestones and the best-distance marker as roadside signs. On screen, allow only a top-band toast of under 1.5 s, with no centre banner during play.
- Limits: the image is an edited composite.

**O12. State shown on the vehicle, not on the HUD. (S4)**
- Observed: a shield power-up appears as translucent shields around the car, and signposts in the world give direction.
- Apply, capture effect: sparkles and a key icon on the claimed car, with YOU GOT THE KEYS! in the top band.
- Apply, card reveal: a compact card in the upper-right quarter, at most 30 % of the width by 25 % of the height. The road ahead must stay visible.
- Limits: the BBR2 shields cover ~30 % of the frame, which is too much for Car Hop. These images show no HUD.

## Results card (gap)

No source shows a Results screen. This proposal is inferred from O2 and O3 only:
- Distance at the 36 display size, then coins and best at the 24 size.
- NEW BEST shown as a tag beside the best figure, not in place of it.
- Claimed cars shown as a row of small cards.
- RETRY as the 56 px primary button, bottom-right. GO HOME as a 48 px secondary button to its left, at least 24 px away.

This needs its own reference pass.

## New inspirations

- An in-world target ring as the main hop cue (O6).
- Roadside signs for milestones (O11).
- Gauges placed in the gaps between the thumbs (O8).

## Deliberate exclusions

- Nothing is copied: no logos, wordmarks, icons, pedal or dial art, characters, vehicles or fonts, and no near-identical layouts.
- No pressure tactics: no multiplier economy, no timers, no "hours left" badges, no streaks, and no offers on the Results screen.
- No strobe, no screen shake and no full-screen flashes. Every effect follows `GuiService.ReducedMotionEnabled`.
- The HCR2 bottom dial cluster is not taken as-is, because in Car Hop that area is the landing view.

## Roblox implementation implications

- **Safe area.** Use a ScreenGui with `ScreenInsets = CoreUISafeInsets`. It is the default, and the docs recommend it for interactive UI because it clears the top bar and the notch. In landscape the top bar sits top-left, so the Heat bar starts to its right or below it. ([Creator Docs](https://github.com/roblox/creator-docs/blob/main/content/en-us/includes/ui/screen-insets.md))
- **Reserved touch zones.** The docs reserve bottom-left for the thumbstick and bottom-right for jump, and say not to put key information there. ([Creator Docs](https://github.com/roblox/creator-docs/blob/main/content/en-us/ui/position-and-size.md))
- **Hop button placement.** Decide whether Hop replaces jump during a ride or sits beside it. Either way, read the position and size from `TouchGui.TouchControlFrame.JumpButton`, as the docs' blaster example does, rather than hard-coding pixels.
- **Touch-only controls.** Show Hop and Foot Dash only when the last input was touch.
- **Proposed thumb zones** (test in the device emulator):
  - Landscape 844x390: the stick in the left 35 % by the bottom 60 %; Hop and Dash in the right 35 % by the bottom 60 %.
  - Portrait 390x844: the bottom 30 %, split left and right.
- **Landscape fit check.** The 390 px height must hold the top band (~45 px), the Keys ring (~55 px) and Hop (~110 px) without overlap.
- **Approvals.** Every value here still needs a Figma spec and Lane 3 owner approval (decision 0012).
