---
title: Raceway level-up banner (RACEWAY LEVEL 5!)
tags: [design, ui, raceway]
status: "approved by Adam 2026-10-29"
---

# Raceway level-up banner

> [!success] Approved by Adam, 2026-10-29
> "approved for all ur reccomendations  and yes upload the meshes" (reply to the Raceway round 2 approval page, https://claude.ai/artifact/97zrdVD9wkB5nnFZQXmYgQ, and the Figma page node 25-747). Choices taken: (1) new token `Teal` #228A92 plus the light teal #51D7D1 for text on navy; (2) the banner keeps one line wherever it fits, two lines only as the fallback; (3) panel padding 20 on desktop and tablet, 16 on phones; (4) the shop roof stays at 8.5 studs. Every other default in this file is taken as written. Recorded in `vault/design/visual-direction.md`.

- Figma: Car Hop UI, page 'Raceway round 2 (pending Adam)' - https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3?node-id=25-747 (imported 2026-10-29 from `Car-Hop-Art/review/raceway-round2/mocks/raceway-ui-mocks.html` with html_to_figma: flat layers, text outlines may be dropped by the import; the spec values win)
- Mock: `Car-Hop-Art\review\raceway-round2\mocks\raceway-ui-mocks.html`, frames 4a (desktop 1920 x 1080, single line), 4b (phone landscape 844 x 390, the result of the width rule), 4c (the same phone with the two-line fallback), 4d (tablet landscape 1180 x 820).
- Brief: [[raceway-round2]] PART 3 and DESIGN 2 (Adam, 2026-10-29). Supersedes section 2 of [[speedway-upgrade-board]] (the old text "SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!"). Workflow: Figma-first ([[0012-figma-ui-workflow]]). Approval: pending Adam. Nothing here is approved. Hand edits in Figma: none. Figma reads used: none.
- It reuses the container already built in `src/client/Home/Island/Speedway/Reveal.luau` (`Reveal.banner`): same navy pill, coral border, cream outlined Fredoka text. Only the text, the timing, the size rule and the cancel rule change.

## What it says (exact text rules)
- The visible sentence is exactly `RACEWAY LEVEL N!`, N being the level just reached, 2 to 12 (level 1 is the start state and is never announced). Example: "RACEWAY LEVEL 5!". Upper case, one space between words, an exclamation mark, no full stop.
- Two lines when the single line does not fit (see the width test): `RACEWAY` over `LEVEL N!`. No extra words either way.
- Nothing else: no level title (no "THE FLAG OFFICIAL"), no old-to-new comparison, no sub-line, no rarity label, no second number badge, no Lap Pay value.
- The level names remain internal labels in `Ladder` and the docs. `Ladder.banner(level)` is changed to return this sentence (`string.format("RACEWAY LEVEL %d!", level)`), so no other code path can show a name.
- Only the plot owner's own level-up shows it (unchanged rule). Level-downs show nothing.
- Colour: the whole sentence is cream; the level number may be the yellow accent (the mock shows it yellow). Type size and contrast must still read the complete sentence.

## Container (unchanged from the built banner unless marked)
| Item | Value |
|---|---|
| ScreenGui | `Lane3SpeedwayBanner` (internal name may stay), `IgnoreGuiInset` true, `DisplayOrder` 20 |
| Position | pill anchored top centre: AnchorPoint (0.5, 0), Position (0.5, 0.14), that is 14% of the screen height down, centred horizontally |
| Fill | island navy #243A62, BackgroundTransparency 0.05 |
| Corner | 18 |
| Border | UIStroke coral #F47F70, thickness 4, Border mode (drawn outside the pill) |
| Padding | left and right 28, top 10, bottom 12 |
| Text | Fredoka One, `Tokens.TextSize.Display` 36, cream #FFF6E0, UIStroke 3 in #141B33 on each label |
| Level number | yellow #FACE46 (7.5:1 on the navy), same 3 px outline. Built as separate labels in a horizontal UIListLayout ("RACEWAY LEVEL ", "5", "!"), not rich text, because rich text draws a much thinner outline (found in an earlier HUD pass). Verify the space and the joins in Studio |
| Input | none. Active false, no button, no modal; never blocks the thumbstick, prompts or panels |
| Scale | NEW: one UIScale on the root, `Tokens.uiScaleFor(viewport)` (1.5 on 1920 x 1080 and 1180 x 820, 1.0 on 844 x 390). 36 design px is 54 screen px at 1.5. The built banner draws 36 px at every size and uses its UIScale only for the entrance bounce; the settle in this spec uses a second, inner UIScale. Reversible: keep the banner unscaled |

The pill height is 10 + 43 + 12 = 65 design px (one line, the 43 px line height is a 1.2 em estimate) plus the 8 px of border; two lines are 108 plus 8.

## Single line or two (the measured width test the build uses)
Measure, then decide, every time a banner is shown (the safe width can change with rotation or a resized window):
1. `safeWidth = (ViewportSize.X - left inset - right inset) / UIScale`, in design px, using the same CoreUISafeInsets as the HUD.
2. `limit = safeWidth - 2 x 28 (the pill padding) - 2 x 16 (a minimum screen margin, `Space.L`)`. The 16 margin is my addition so the pill never touches the safe edge (reversible: drop it).
3. Measure `TextService:GetTextBoundsAsync` for "RACEWAY LEVEL N!" at TextSize 36 in `Tokens.font()` (wrapped in `pcall`; on failure use the estimate below).
4. If that width is at most `limit`: one line at 36.
5. Otherwise two lines at 36 ("RACEWAY", "LEVEL N!"): measure the wider of the two; if it is at most `limit`, use two lines at 36.
6. Only if two lines at 36 still do not fit: two lines at 24 (`Tokens.TextSize.Value`). 24 is a fallback and is never the first choice.

Estimate (not measured, Fredoka One is not installed in my tools): average glyph width about 0.62 em, spaces included.
| Text | Glyphs | Width at 36 | Pill (width + 56 padding + 8 border) |
|---|---|---|---|
| RACEWAY LEVEL 5! | 16 | 16 x 0.62 x 36 = 357 | 421 design px |
| RACEWAY LEVEL 12! | 17 | 379 | 443 |
| RACEWAY | 7 | 156 | |
| LEVEL 5! | 8 | 179 | 243 |

Result at 844 x 390 (UIScale 1.0): assumed side insets about 47 each (a notched phone; assumed, not measured), safe width about 750, limit 750 - 56 - 32 = 662. The single line (about 357 by the estimate) fits with a wide margin, so a landscape phone uses one line at 36. The single line only stops fitting when the safe width falls below about 357 + 88 = 445 design px, which is narrower than any landscape phone (even a 568 px wide screen at 1.0 fits), and the estimate would need to be about 85% too small to change the 844 px result. The two-line layout and the 24 fallback are therefore protection for very narrow windows and unusual safe areas, not the common phone case.

The phone height also argues for one line: a two-line pill is about 116 px tall, 30% of a 390 px high screen, and reaches the avatar's head; one line is about 73 px. This is a point to confirm with Adam: his brief says "on small screens, use two lines"; the measured rule keeps one line on every landscape phone and keeps two lines as the fallback. If he wants two lines on every phone, the reversible alternative is to force two lines when the short side is under 500 px.

## Position and clearance
- Top centre, 14% down: desktop top edge about 151 px, tablet 115 px, phone 55 px. The pill is horizontally centred, so it is clear of the bottom-left Cash counter and the bottom-right touch controls (jump, thumbstick), which sit in the lower third. It sits above the gameplay focal area (the avatar and the track ahead are below about 40% of the height). ProximityPrompts appear near their object, in the middle of the view, below the pill. Frames 4a to 4d draw these keep-clear areas as dashed annotation boxes (schematic, not measured on a device).
- The run HUD places Cash top left (`vault/design/visual-direction.md`); the banner is an island HUD element and never runs during a run. If both can ever show together, the left Cash counter is outside the centred pill on every drawn size.
- The Roblox top bar sits at the top left; on 844 x 390 the pill starts at x = (844 - 421) / 2 = 211 design px, to the right of it (not measured on a device).

## Motion and timing
Total 1.50 s (the same as the reveal, `Reveal.Seconds` 1.5): **0.18 s in, 1.10 s hold, 0.22 s out.**
- In (0.18 s): the group fades 0 to 100% opacity while the pill settles from a 0.94 to 1.0 scale (Quad Out, no overshoot, no bounce). This replaces the old 0.45 s Back bounce, 2.7 s hold and 0.4 s fade.
- Hold (1.10 s): nothing moves.
- Out (0.22 s): the group fades to 0% opacity (Quad In), then the ScreenGui is destroyed or hidden.
- Reduced Motion (`GuiService.ReducedMotionEnabled`, or the preview-only override `Lane3ReducedMotionOverride`, never saved): opacity only, same times, scale stays 1.0, no bounce, no overshoot, no settle.

## Which level it announces (latest-only and cancel rule)
- At most one banner is active. There is one banner object per client; a new request never stacks a second.
- The banner is requested only when the track has reached the new level (the Look application for that level has completed), never from the click itself. It cannot announce a level the track did not reach. A new level updates the stats board, the panel and the track from one preview state, then the banner follows.
- Latest-only: each request carries a number. When a request arrives while a banner is in flight or while an earlier request is still waiting for the track, the stale tweens are cancelled (`Tween:Cancel()`), the pending hold delay is cancelled (`task.cancel`), and the banner restarts for the latest level only, with the text swapped in place and the same in-hold-out timing (a restart, not a second banner). Rapid presses 5, 6, 7 therefore show "RACEWAY LEVEL 7!" once, for the level the track settled on; a level the track skipped past is never shown.
- If the level goes down while a banner is visible, the banner fades out over 0.22 s and nothing replaces it.
- Opening, closing or reopening the panel, walking away and returning, or a visitor arriving never replays or starts a banner. The first level the client learns after joining is silent (no banner, no reveal).
- If the plot's owner changes while a banner is visible, it is cancelled the same way.

## Studio-only text (not player-facing)
The Studio preview panel title "SPEEDWAY PREVIEW" is renamed "RACEWAY PREVIEW" for consistency; it is never part of the game.

## Checks the build runs
- Text for each N from 2 to 12 is exactly `RACEWAY LEVEL N!` and contains no title word.
- Width test at 1920 x 1080, 1180 x 820, 844 x 390 and a narrow window (for example 480 px wide): the chosen layout, line count and size are logged; the single line at 844 is expected.
- A second request during the hold restarts with the new level; no second ScreenGui exists at any time.
- Reduced Motion: opacity only, no scale change.
- Banner never takes input; thumbstick and prompts work beneath it.

## Colours and tokens
`Tokens.TextSize.Display` 36 (and `Value` 24 for the last-resort fallback), `Tokens.font()`, `Tokens.uiScaleFor`. Island palette: navy #243A62, cream #FFF6E0, yellow #FACE46, coral #F47F70, outline #141B33 (as in [[speedway-upgrade-board]]). No new colours.
