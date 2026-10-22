---
title: Portal requirement sign
tags: [design, ui]
status: draft
---

# Portal requirement sign

- Figma: "Car Hop UI", https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3, page "Island signs", section 5 (heading `8:410`).
- Frames (a world-space sign, not screen UI, so there are no portrait / landscape / desktop layouts of the sign itself; the gameplay-scale frames show it on phones):

| Frame | Node id |
|---|---|
| Portal sign – LOCKED – DUSTY HIGHWAY (assembly, 100 px per stud) | `8:411` |
| Portal sign – READY – DUSTY HIGHWAY (assembly, 100 px per stud) | `8:448` |
| Plank 1 – World name – LOCKED / READY (560 × 120) | `8:415` / `8:452` |
| Plank 2 – Cash row – LOCKED / READY (560 × 120) | `8:424` / `8:461` |
| Plank 3 – Downtown cars row – LOCKED / READY (560 × 120) | `8:436` / `8:473` |
| Portal sign from 15 studs – phone landscape 749 × 381 | `8:486` |
| Portal sign from 40 studs – phone landscape 749 × 381 | `8:528` |
| Portal sign from 15 studs – phone portrait 401 × 777 | `8:570` |
| Portal sign from 40 studs – phone portrait 401 × 777 | `8:612` |
| Note (states, PREVIEW rule, Peek reservation) | `8:485` |

- Approval: pending. **Adam reviews this at the final review (Task 3), not mid-task.** New Lane 3 UI per [[0012-figma-ui-workflow]].
- Hand edits in Figma since the spec was written: none.
- Figma reads used for this screen: shared with [[island-signs]]; the two 2026-10-22 Export sheet screenshots included this sign in their review area (logged in [[figma-reads]]).

## Purpose
A wooden sign standing beside each World portal tells a player, before they walk in, whether the World is open to them and what is still missing. It is a world prop: nothing on it is pressable, it shows no prices, and it never offers a purchase. It is read from the walkway while the player keeps full control of their character and the camera.

Room is left for a future **Peek** interaction (look inside the World before it is open). It is not drawn: it would be a separate prompt in front of the sign or on screen, never a button on the planks. Nothing on the sign changes when Peek is added.

## Data and actions
| Control | Shows (source of the value) | Request it sends | Server owner (lane) |
|---|---|---|---|
| Plank 1: World name | the World's display name (static per portal) | none | Lane 3 (sign) |
| Plank 1: state badge and pill | LOCKED or READY! from the replicated unlock state for this player | none | unlock state: not decided here (shared contract, Lane 1 / Lane 2) |
| Plank 2: Cash row | the player's Cash toward the World's Cash requirement | none | economy: not decided here |
| Plank 3: Downtown cars row | cars owned from the previous World toward the car requirement | none | not decided here |

The sign only reads replicated values. The numbers, requirements and unlock rule are **not** decided by this spec; until they are, every number shown is a PREVIEW placeholder.

## PREVIEW rule
- Every number on this sign in a mockup, a Figma frame, a Studio preview or a screenshot is a placeholder and carries the PREVIEW tag right before it: "PREVIEW 1,200 / 5,000", "PREVIEW 2 / 3".
- The numbers in the frames (1,200 / 5,000 Cash; 2 / 3 Downtown cars) are made up and are **not** economy values. They must not be copied into code, data or another spec as real requirements.
- The tag disappears only when the values come from the server through an approved contract. A build that shows a hard-coded number keeps the tag.
- No prices, purchase prompts, "buy" wording or Robux anywhere on the sign.

## States
| State | What changes on screen | Text | Exit |
|---|---|---|---|
| LOCKED | badge shows `icon-lock.png`; dark pill; each bar filled to its fraction (Cash in coin gold, cars in sky blue); empty tick slots | "LOCKED" | any requirement met: that row's bar turns green and its tick appears; all met: READY |
| One requirement met | that row: full green bar, tick; the other row as LOCKED; pill stays LOCKED | "LOCKED" | the other requirement met |
| READY | badge shows `icon-portal.png`; green pill; both bars full and green; both ticks | "READY!" | stays READY (the portal itself handles entry) |
| Values not loaded yet | bars empty, numbers "– / –" (proposal), pill LOCKED | "LOCKED" | values arrive |
| Long World name | name TextScaled down, not wrapped | see layout | none |
| Large values | numbers shortened by the shared number formatter (for example 12.5K), not by this sign | | |

Drawn: LOCKED and READY. The other rows of this table are written only.

## Layout
Design pixels on each plank's SurfaceGui (PixelsPerStud 100, front face only, transparent background; the plank is the mesh). The three planks are each 5.6 × 1.2 studs = 560 × 120 px.

Sign structure (proposal for the kit): two posts 0.4 × 6.2 studs (`#7A5638`, 4 px `#3B2A1E` edge) at the plank ends, sign 6.2 studs wide overall; plank 1 spans 4.8–6.0 studs above the ground, plank 2 3.44–4.64, plank 3 2.08–3.28 (gaps 0.16). In the views it stands 2 studs beside the portal's 20 × 30 stud field (reversible).

**Plank 1 – World name**

| Element | Position and size (px) | Token / value |
|---|---|---|
| State badge (Frame, UICorner 1,0, UIStroke) | x 12, y 12, 96 × 96 | the World's portal colour (Dusty Highway `#FF963C` = `WorldPalette.PortalDustyHighway`), 4 px `#3B2A1E` stroke |
| State icon (ImageLabel, Fit) | x 22, y 22, 76 × 76 | `icon-lock.png` (LOCKED) / `icon-portal.png` (READY) |
| World name (TextLabel, live) | x 124, y 12, 420 × 56, left aligned | Fredoka One 44 (TextScaled, max 44, min 28), cream `#FFF6E0`, UIStroke 4 px `#3B2A1E`; "DUSTY HIGHWAY" measures 364 × 53 |
| State pill (auto width, padding 14, UICorner 18) | x 124, y 74, h 36; width hugs the text (LOCKED 123, READY! 122) | LOCKED: fill `#3B2A1E`, text Fredoka One 22 cream. READY!: fill `#3DBE6C` (`Tokens.Color.Success`), 3 px `#3B2A1E` stroke, text Fredoka One 24 cream with 3 px `#3B2A1E` outline |

**Planks 2 and 3 – requirement rows** (same layout; plank 2 Cash, plank 3 Downtown cars)

| Element | Position and size (px) | Token / value |
|---|---|---|
| Row icon (ImageLabel, Fit) | x 14, y 20, 80 × 80 | `icon-coin.png` (Cash) / `icon-garage.png` (cars) |
| Row label | x 108, y 12, auto width, h 32, left aligned | Fredoka One 26, cream `#FFF6E0`, UIStroke 3 px `#3B2A1E`; "CASH" ends at x 178, "DOWNTOWN CARS" at x 349 |
| Progress numbers (live) | right edge at x 544, y 12, h 32, right aligned | Fredoka One 26, cream, UIStroke 3 px `#3B2A1E`; "1,200 / 5,000" 159 wide, "2 / 3" 59 wide |
| PREVIEW tag | right edge 8 px left of the numbers, y 16, h 28, auto width (94), padding 8, UICorner 6 | white fill, 2 px dashed `#C2187A` stroke (Roblox: solid 2 px UIStroke), text "PREVIEW" Fredoka One 16 `#C2187A`; sits at x 283 (Cash) and x 383 (cars), clear of the labels |
| Bar track | x 108, y 62, 372 × 40, UICorner 20 | fill `#5A4030`, UIStroke 3 px `#3B2A1E` |
| Bar fill | x 112, y 66, width 364 × fraction (clamped 0–1), h 32, UICorner 16 | not met: Cash `#FFC83D` (`Tokens.Color.Coin`), cars `#6ED2FF` (`WorldPalette.PortalSummitPass` swatch, proposal); met: `#3DBE6C` (Success) |
| Tick slot, not met | x 490, y 60, 44 × 44 circle | fill `#5A4030`, UIStroke 4 px cream at 50 % |
| Tick, met | x 488, y 58, 48 × 48 | `icon-tick.png` |

Legibility (frames `8:486` to `8:612`; camera FOV 70 vertical, eye 6 studs above the ground, looking level):

| View | Points per stud | Sign width | World name capital height | Row numbers capital height |
|---|---|---|---|---|
| 15 studs, phone landscape | 18.1 | 112 pt | about 5.6 pt | about 3.3 pt |
| 40 studs, phone landscape | 6.8 | 42 pt | about 2.1 pt | about 1.2 pt |
| 15 studs, phone portrait | 37.0 | 229 pt | about 11.4 pt | about 6.7 pt |
| 40 studs, phone portrait | 13.9 | 86 pt | about 4.3 pt | about 2.5 pt |

What reads at a distance is the state: badge icon, pill colour, bar fill and the ticks. The numbers only read up close (portrait at 15 studs, or nearer). That is a reason for the future Peek or an on-screen panel to show the numbers large; it is not solved on the sign.

Safe area, top-bar inset and touch targets do not apply (world prop, nothing pressable).

## Tokens used
From `src/shared/UI/Tokens.luau`: `Color.Coin` `#FFC83D`, `Color.Success` `#3DBE6C`, `FontFamily` Fredoka One, `TextSize.Minimum` 16 (the PREVIEW tag). Proposals, not yet tokens: cream `#FFF6E0`, outline brown `#3B2A1E`, plank `#B08456` (decided colour for boards), post `#7A5638`, bar track `#5A4030`, PREVIEW magenta `#C2187A`, cars bar `#6ED2FF`, and world-sign text sizes 44 / 26 / 22 / 24 (larger or smaller than the screen ramp because they are world-space).

## Buttons
None. Peek is reserved for later and is not drawn.

## Motion
| Event | Property | From → to | Duration | Easing | Reduced motion |
|---|---|---|---|---|---|
| Value changes | bar fill width | old → new | 0.35 s (proposal; matches `Motion.CashGainSeconds`) | Quad Out | snap |
| Row met | bar colour, tick | row colour → green, tick scale 0.6 → 1 | 0.2 s | Back Out | snap, no scale |
| READY | pill swap LOCKED → READY! | swap | 0.2 s | Quad Out | snap |

Reduced motion follows `GuiService.ReducedMotionEnabled` plus the preview-only override (approved 2026-10-19).

## Assets
| Image | Drawn in Figma (node) | Exported file (Task 3 scratchpad `task3fig\icons\`) | Manifest row | Upload approved | Asset ID |
|---|---|---|---|---|---|
| Lock, portal, coin, car, tick icons (256 × 256) | Icon library `4:157`, `4:141`, `4:153`, `4:143`, `4:155` | `icon-lock.png`, `icon-portal.png`, `icon-coin.png`, `icon-garage.png`, `icon-tick.png` | not yet | no | none |

The planks and all text are built live; no sign image is exported.

## Open questions
1. Approve the layout, the two states and the PREVIEW tag style.
2. The unlock rule and the real requirement values are a shared contract (economy and replicated unlock state): who owns them, and when they are decided. Until then the numbers stay PREVIEW.
3. Sign position beside each portal (2 studs to the right in the mock), and whether every portal gets one.
4. The cars-row bar colour (sky blue proposal) and the "– / –" loading text.
