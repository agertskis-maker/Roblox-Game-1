---
title: Raceway upgrade panel (RACEWAY UPGRADES)
tags: [design, ui, raceway]
status: "approved by Adam 2026-10-29"
---

# Raceway upgrade panel

> [!success] Approved by Adam, 2026-10-29
> "approved for all ur reccomendations  and yes upload the meshes" (reply to the Raceway round 2 approval page, https://claude.ai/artifact/97zrdVD9wkB5nnFZQXmYgQ, and the Figma page node 25-747). Choices taken: (1) new token `Teal` #228A92 plus the light teal #51D7D1 for text on navy; (2) the banner keeps one line wherever it fits, two lines only as the fallback; (3) panel padding 20 on desktop and tablet, 16 on phones; (4) the shop roof stays at 8.5 studs. Every other default in this file is taken as written. Recorded in `vault/design/visual-direction.md`.

- Figma: Car Hop UI, page 'Raceway round 2 (pending Adam)' - https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3?node-id=25-747 (imported 2026-10-29 from `Car-Hop-Art/review/raceway-round2/mocks/raceway-ui-mocks.html` with html_to_figma: flat layers, text outlines may be dropped by the import; the spec values win)
- Mock (HTML source for the Figma import): `Car-Hop-Art\review\raceway-round2\mocks\raceway-ui-mocks.html`, frames 1a (desktop 1920 x 1080), 1b (phone landscape 844 x 390), 1c (tablet landscape 1180 x 820), 2 (MAX state, desktop), 7 (BUY button states).
- Brief: [[raceway-round2]] DESIGN 4 (Adam, 2026-10-29). Workflow: Figma-first ([[0012-figma-ui-workflow]]); this is a new Lane 3 panel, so it is mocked first and built by hand in Luau from this file. The task-scoped Studio-first exception of 2026-10-28 does not cover it.
- Approval: pending Adam. Nothing here is approved. Hand edits in Figma: none. Figma reads used for this screen: none.
- Related: [[raceway-parking-panel]] (same card style), [[raceway-level-banner]], [[speedway-upgrade-board]] (kiosk stats board).
- Frames are landscape only (the island HUD is landscape-only); phone portrait is not drawn. Reversible: add a portrait frame if the game ever supports it.

## Purpose, entry and exit
- Shows a plot owner what the next Raceway level gives (Lap Pay change and the new physical pieces), the price, and a BUY button. It is a picture of the upgrade, not a shop economy: prices belong to Brian L (Lane 2).
- Opens only for the plot owner, from the ProximityPrompt "Upgrade Raceway" on the shopkeeper's counter (frame 6 of the mock: Roblox's default prompt style, unchanged; ActionText "Upgrade Raceway", ObjectText "Raceway shop"). Visitors get no prompt and no panel; they read the stats board (read-only).
- Closes by: the close button; Escape (keyboard) or B (gamepad); the owner walking out of 1.5 x the prompt's MaxActivationDistance (proposal, reversible); ownership of the plot changing (see Safety). Closing never changes the level.
- Opening or closing never replays the reveal or the banner. The panel only reads the current level; the reveal is driven by level changes seen after the first state (see Transitions).

## Layout (design px; scaled once by a UIScale on the panel root)
`UIScale = Tokens.uiScaleFor(viewport)` = short side / 390 clamped to 1.0 .. 1.5. Desktop 1920 x 1080 and tablet 1180 x 820 both give 1.5; phone landscape 844 x 390 gives 1.0. Components do not multiply sizes themselves. The panel sits in a ScreenGui with `ScreenInsets = CoreUISafeInsets`, DisplayOrder 18 (below the banner at 20), centred in the safe area.

### Card
| Item | Value |
|---|---|
| Card size | 520 x 360 design px (780 x 540 screen px at 1.5). On a short screen the height is `min(360, safeHeight / UIScale - 32)`: phone 844 x 390 gives 358 |
| Fill, stroke | `Color.Card` #FFF4DC; UIStroke `Stroke.Thick` 4, `Color.Stroke` #1E2A4A, Border mode (drawn outside the 520 x 360) |
| Corner | `Radius.Panel` 20 |
| Shadow | `Shadow.OffsetY` 4, `Color.Shadow` at `Shadow.Transparency` 0.8 (a navy copy of the card, 4 px lower) |
| Padding | 20 on desktop and tablet, 16 on phone (short side under 500 px). 20 is the brief's proposal and is not a `Space` token (the nearest are 16 and 24); built as a local constant, Adam may prefer a token |
| Scrim | full-screen navy `Color.Stroke` at 55% transparency (45% opaque), visual only: Active false, so it never swallows a touch meant for the thumbstick or the world. Tap outside does not close (reversible) |

### Rows, top to bottom (inner width 480 on desktop, 488 at padding 16)
| # | Row | Height | Gap above | Content |
|---|---|---|---|---|
| 1 | Header | 48 | 0 | title "RACEWAY UPGRADES" at the left, close button at the right |
| 2 | Level tiles | 48 | 12 (`Space.M`) | CURRENT tile, arrow, NEXT tile in one row |
| 3 | Hero stat | 48 | 8 (`Space.S`) | "LAP PAY x1.35 → x1.50" |
| 4 | New line | 24 | 4 (`Space.XS`) | "New: flag official, start lights" |
| 5 | Price strip | 32 | 8 | "PRICE: SET BY ECONOMY" |
| 6 | BUY row | 56 | 8 | BUY button + "STUDIO PREVIEW" marker |
| 7 | Preview line | 20 | 4 | "No Cash spent. Progress is not saved." |

Sum: 276 px of rows + 44 px of gaps = 320 px, exactly the inner height of a 360 card at padding 20 (326 inside a 358 card at padding 16, so 6 px spare). No bars, no progress bar: levels are discrete and a bar would imply fractions.

Scrolling: rows 1 and 6 to 7 are fixed (header at the top, BUY row and preview line at the bottom, always reachable). Rows 2 to 5 live in a ScrollingFrame (Y only, `ElasticBehavior` Never, scroll bar shown only when the content overflows). At 844 x 390 nothing overflows, so it does not scroll in practice; the scroller is the safety net for tall text or a very short window.

### Components
| Component | Size and position | Look |
|---|---|---|
| Title | left, vertically centred in row 1, TextSize 24 (`Value`) | Fredoka One, `Color.Text` #1E2A4A, no outline, left aligned, 16 characters (about 240 px by the 0.62 em estimate) |
| Close button | 48 x 48 (`Touch.Minimum`), right end of row 1 | `Color.CardInset` #F6E6BF fill, UIStroke `Stroke.Regular` 3 navy, `Radius.Card` 14, an X of two navy strokes 4.5 px thick in a 20 x 20 icon area, round caps |
| CURRENT tile | 196 x 40, vertically centred in the row | `CardInset` fill, UIStroke `Stroke.Thin` 2 navy, `Radius.Card` 14; text "CURRENT LEVEL 4", 18 (`Label`), navy |
| Arrow | 28 x 20 between the tiles, gaps 8 | navy, 4.5 px stroke, round caps and joins, shape of a right arrow (shape, not colour, says "next") |
| NEXT tile (stronger) | 240 x 48 | `Teal` #228A92 fill (new token, see Colours), UIStroke `Stroke.Thick` 4 navy, `Radius.Card` 14; text "NEXT LEVEL 5", 24 (`Value`), `Color.Card` cream with a 2 px navy outline |
| Hero stat | full width x 48 | white (`Color.Track` #FFFFFF) fill, UIStroke 3 navy, `Radius.Card` 14; one centred row: "LAP PAY" 18 navy, then "x1.35" 36 (`Display`) navy, a right arrow 28 x 20 navy, an up-arrow cue 22 x 26 (solid teal with a 2 px navy outline), then "x1.50" 36 teal. Gaps 12 / 10 / 10 / 4. Next value is teal plus the up-arrow shape: never colour alone |
| New line | full width x 24, centred | 18 navy, no outline. "New:" and the pieces on one line, at most two short physical additions |
| Price strip | full width x 32 | transparent, UIStroke `Stroke.Thin` 2 dashed navy (a dashed outline marks a placeholder), `Radius.Small` 8; text "PRICE: SET BY ECONOMY" 18 navy |
| BUY button | flexible width (about 300 to 450) x 56 (`Touch.Primary`) | see BUY states |
| STUDIO PREVIEW marker | 172 x 40, right of BUY with an 8 px gap, vertically centred in the 56 row | `Color.Stroke` navy pill (radius 20), UIStroke 2 mint #80D8BD, text "STUDIO PREVIEW" 16 (`Minimum`) mint #80D8BD. Persistent while the preview fixture is running; never shown at runtime outside the fixture |
| Preview line | full width x 20, centred | "No Cash spent. Progress is not saved." 16 (`Minimum`), `Color.TextSecondary` #4A5578 |

Level-text rules: tile text is `TextScaled` with `MaxTextSize` 18 (current) and 24 (next) and `MinTextSize` 16, so "CURRENT LEVEL 11" (about 179 px by the estimate in a 196 px tile) never clips. Lap Pay always shows two decimals with an "x" ("x1.00", "x3.50").

### BUY button (the primary button)
- Size: at least 56 high; wide, fills the row left of the marker. Label "BUY", 36 (`Display`), navy `Color.Text` (navy on orange is 6.0:1; cream on orange fails at 2.2:1, so cream is not used).
- Normal: `Color.Primary` #FF8A1F fill, UIStroke 4 navy, `Radius.Card` 14, a 5 px lower lip in `Color.PrimaryPressed` #D96A00, and one quiet gloss: a white strip at 38% opacity, 10 px high, inset 12 px from the sides and 4 px from the top, `Radius.Small`. Static: no sweeping or moving shine.
- Pressed (0.1 s, `Motion.Press`): fill `PrimaryPressed`, no gloss, label down 3 px. Reduced Motion: the colour change only, no label shift.
- Locked (from an accepted click until the transition has finished): same look at 55% opacity, not clickable.
- Disabled (no price, outside the preview): flat #D8D2C4 fill, navy outline, label in `TextSecondary`.
- Orange means go or buy, so it is used for BUY only.

## States
| State | What shows |
|---|---|
| Level 1 to 11 (Studio preview) | the layout above. Texts from the two tables below |
| Level 12 (MAX) | header and close, then "MAX LEVEL" and "RACEWAY LEVEL 12" only. No comparison, no price strip, no BUY, no preview marker, no promise of another level. Same 520 x 360 card so nothing jumps when the last purchase lands (reversible: shrink to fit) |
| Opening | one frame of the current level; no entrance replay of the Raceway reveal |
| Runtime outside the Studio preview fixture | the price is unknown, so there is no enabled purchase action: BUY is drawn Disabled (decision, reversible: hide it), the STUDIO PREVIEW marker and the preview line are hidden, the price strip stays. The shopkeeper prompt is also disabled until a price exists, so the panel normally cannot open; this is only the safety net |
| Visitor | no prompt, no panel. If the panel is somehow open when the plot changes hands it closes (see Safety) |

MAX card: the first tile is `Teal` fill with a 4 px navy stroke, 440 x 84, "MAX LEVEL" 36 cream with a 3 px navy outline; below it a `CardInset` tile 440 x 56 with a 2 px stroke and "RACEWAY LEVEL 12" 24 navy; both centred in the body with a 12 px gap.

### The two tables (one table each, read by the board, the panel and the banner)
Lap Pay is a PROPOSAL for Brian L, kept in one table so his economy can replace it. It is the only earning stat: lap time stays about 15 s and car speed does not change.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Lap Pay | x1.00 | x1.10 | x1.20 | x1.35 | x1.50 | x1.70 | x1.90 | x2.15 | x2.40 | x2.70 | x3.00 | x3.50 |

The "New:" line shows what the NEXT level adds (the same strings the board uses):

| Next level | Line |
|---|---|
| 2 | New: rope fence, pennants |
| 3 | New: bleachers, snack cart |
| 4 | New: asphalt, tyre wall |
| 5 | New: flag official, start lights |
| 6 | New: pit garage |
| 7 | New: grandstand, announcer booth |
| 8 | New: floodlights, big screen |
| 9 | New: banked turns |
| 10 | New: raised far turn |
| 11 | New: hump, blimp |
| 12 | New: loop, champion statue |

Level names ("Pit Row", "The Flag Official" ...) stay as internal labels in code and docs and are never shown.

## Behaviour
- Close: sets the panel closed. Gamepad: BUY is the default selected object; Down and Up move between BUY and Close; B closes.
- BUY (Studio preview fixture only): accepted at most once per transition. The panel holds a single-flight state `Idle -> Locked -> Idle`: a click is accepted only when the state is Idle and the level the panel shows equals the plot's preview level; accepting sets Locked at once (so a second click in the same frame or in the next frames is ignored, never queued), raises the preview level by one, and starts the track reveal. The state returns to Idle when the board, panel and track all show the new level and the reveal has finished (`Reveal.Seconds`, 1.5 s). Rapid clicks cannot buy twice or skip a level.
- One preview state drives everything: the new level updates the stats board, this panel and the track together, and the banner is shown only when the track has reached that level ([[raceway-level-banner]]). The banner cannot announce a level the track did not reach.
- No Cash, no saving, no remotes, no player currency, no save field. "No Cash spent. Progress is not saved." says so.
- Press feedback: `Motion.Press` 0.1 s. Panel open and close: fade the card (a CanvasGroup) over `Motion.Panel` 0.2 s with a 0.96 to 1.0 scale, no overshoot. Value changes after a purchase cross-fade over `Motion.LabelFade` 0.15 s.
- Reduced Motion (`GuiService.ReducedMotionEnabled`, plus the preview-only override `Lane3ReducedMotionOverride`, which is never saved): panel opacity only (0.1 s, no scale), press changes colour only, values snap, no gloss change.

## Safety
- Ownership changing while the panel is open (the owner leaves, the plot is released or claimed by someone else, the preview owner changes) closes the panel in the same frame without animation, drops any Locked state, and ignores any late result. A visitor can never see an enabled BUY.
- The client only requests; it never sends an amount, a price or a result. In the preview fixture the "purchase" is a local level change. In production the server computes and validates everything (AGENTS.md, Never trust the client with currency).
- Prices are not stored, formatted or computed here. "PRICE: SET BY ECONOMY" is a fixed label.

## FUTURE states for Brian L (not connected, not built)
These describe the UI only, so his economy can be dropped in. Nothing here is wired and no remote, amount or save field is introduced by Lane 3. Every word is a proposal.

| State | Trigger (his server decides) | BUY | Price strip | Panel |
|---|---|---|---|---|
| Normal, affordable | server reports a price and enough Cash | enabled, "BUY" | "PRICE: $ amount" in the strip (his formatting, `Format.cash`) | as above, no STUDIO PREVIEW marker |
| Pending | request sent, no answer yet | Locked look, label "BUYING..." (24) | "WORKING..." | nothing else changes; close stays enabled; timeout is his |
| Success | server confirms the new level | returns to Normal for the next level | "DONE! LEVEL 5" for 1.5 s, then the next price | tiles, hero and New line update together; the track reveal and banner run once from the level change |
| Error | server refuses or the request fails | enabled again | "OOPS! TRY AGAIN" | no level change, no banner |
| Unaffordable | server says Cash is too low | Disabled look | "NEED MORE CASH" | no level change; no pressure, no countdown, no discount wording |

To connect it he supplies: a price for each level, a server-side Cash check, the new level on success. Lane 3 supplies the prompt, panel, board, track reveal and banner. Frame 7 of the mock shows all of these.

## Colours and tokens
From `src/shared/UI/Tokens.luau`: `Color.Card`, `CardInset`, `Text`/`Stroke` (navy #1E2A4A), `TextSecondary` #4A5578, `Track` #FFFFFF, `Primary` #FF8A1F, `PrimaryPressed` #D96A00, `Shadow`; `TextSize` 36 / 24 / 18 / 16; `Space` XS 4, S 8, M 12; `Radius` Small 8, Card 14, Panel 20; `Stroke` Thin 2, Regular 3, Thick 4; `Touch` 48 / 56; `Motion.Press`, `Panel`, `LabelFade`; Fredoka One.

New, proposed (add to `Tokens.Color` when approved): **Teal #228A92**, the island kit's existing swatch "teal" = (34, 138, 146) in `assets/island/kit/kitlib.py` (the same colour the Raceway pieces are painted with). The island palette file `src/island/WorldPalette.luau` and `vault/design/visual-direction.md` hold no teal for the island (the only teal there is a Downtown atmosphere tint), so the kit swatch is used rather than inventing #2FA9A0. `Tokens.Color.Calm` #3FB6D8 is a sky blue, not this teal. Mint #80D8BD (preview marker) is from the island palette.

Contrast (computed from the hex values, WCAG relative luminance): navy on Card 12.9:1; navy on orange 6.0:1; TextSecondary on Card 6.7:1; teal on white 4.1:1 (hero next value, 36 px, large text needs 3:1); cream on teal 3.76:1 (large text, also navy-outlined); mint on navy 8.4:1. Teal on `CardInset` would be 3.3:1, so the hero sits on white. Reversible alternative for more contrast: `TealDark` #1A6870 (kit "teal_dark"): 5.9:1 on Card.

## Assets
None uploaded or needed: the panel is built from frames, corners, strokes and the two small icon shapes (arrow, up-arrow) as UI vectors or ImageLabels drawn in code. No image upload without Adam's approval.

## Open questions for Adam
1. Padding 20 (brief) or a token (16 or 24).
2. Add `Teal` #228A92 to `Tokens.Color` (taken from the kit), or use another value.
3. Outside the preview, hide BUY (my default is Disabled) and the prompt?
4. Tap outside the card to close, at the cost of a scrim that can sink touches (my default: no).
5. MAX card keeps the 360 height (default) or shrinks.
