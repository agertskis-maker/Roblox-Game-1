---
title: Speedway upgrade board, level-up banner and preview panel
tags: [design, ui, speedway]
status: "approved by Adam 2026-10-29"
---

# Speedway upgrade board, level-up banner and preview panel

> [!success] Approved by Adam, 2026-10-29
> "approved for all ur reccomendations  and yes upload the meshes" (reply to the Raceway round 2 approval page, https://claude.ai/artifact/97zrdVD9wkB5nnFZQXmYgQ, and the Figma page node 25-747). Choices taken: (1) new token `Teal` #228A92 plus the light teal #51D7D1 for text on navy; (2) the banner keeps one line wherever it fits, two lines only as the fallback; (3) panel padding 20 on desktop and tablet, 16 on phones; (4) the shop roof stays at 8.5 studs. Every other default in this file is taken as written. Recorded in `vault/design/visual-direction.md`.

## Round 2 (2026-10-29, pending Adam's approval)

- Figma: Car Hop UI, page 'Raceway round 2 (pending Adam)' - https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3?node-id=25-747 (imported 2026-10-29 from `Car-Hop-Art/review/raceway-round2/mocks/raceway-ui-mocks.html` with html_to_figma: flat layers, text outlines may be dropped by the import; the spec values win)
- Mock: `Car-Hop-Art\review\raceway-round2\mocks\raceway-ui-mocks.html`: frame 5a (stats board, owner, visitor, MAX), 5b (shop fascia sign), 5d (big screen near and far), 5e (owner sign and gate beam text), 4a to 4d (banner).
- Brief: [[raceway-round2]] PART 1 (big screen), PART 2 (rename), PART 3 (banner), PART 4 and DESIGN 3 (shop, stats board). Workflow: the 2026-10-28 Studio-first exception was for that task only; Round 2 follows the Figma-first rule ([[0012-figma-ui-workflow]]). Approval: pending Adam. Nothing in Round 2 is approved. Hand edits in Figma: none. Figma reads used: none.
- **Supersedes:** section 1 below (the kiosk board: a stats board instead of a picture, renamed) and section 2 (the banner, now [[raceway-level-banner]]). Section 3 (ghost preview) is unchanged. Section 4 (preview panel) is unchanged except its title word. The old text is kept below, marked superseded, for history.
- **Rename:** every player-facing "Speedway" becomes "Raceway". Code, module and file names may keep "Speedway" (decision to be recorded in the ledger). Strings: "SPEEDWAY LEVEL n" to "RACEWAY LEVEL n"; "PLAYER'S SPEEDWAY" to "PLAYER'S RACEWAY"; "YOUR SPEEDWAY" to "YOUR RACEWAY"; ownerText "Adam's Speedway" to "Adam's Raceway"; the Studio-only panel title "SPEEDWAY PREVIEW" to "RACEWAY PREVIEW". `plot-track-signs.md` and `island-task4-signs.md` still show the old word in their text rows; this note overrides those strings.
- Fonts, touch targets and tokens: unchanged and approved (`src/shared/UI/Tokens.luau`: Fredoka One, 36 / 24 / 18 / 16). World faces are not HUD, so their sizes are in px at the face's `PixelsPerStud`. Colours: island navy #243A62, cream #FFF6E0, yellow #FACE46, mint #80D8BD, coral #F47F70, outline #141B33; teal #228A92 (the island kit's existing swatch "teal", `assets/island/kit/kitlib.py`; no teal exists in `WorldPalette.luau` or `visual-direction.md`), and light teal #51D7D1 (`WorldPalette.ShallowWater`) where teal text sits on navy (6.5:1; #228A92 is only 2.8:1 on #243A62, so it is used for shapes and never for small text there).
- Lap Pay and the "New:" lines come from the two tables in [[raceway-upgrade-panel]] (one table each; Lap Pay is a PROPOSAL for Brian L). The board, the panel and the track all read the same preview level, so they never disagree.

### R1. Kiosk stats board (world sign, every plot; replaces section 1)
- Where: a standing board beside the Raceway shop's counter opening (the former Paddock kiosk booth), facing the owner's approach and never covering the shopkeeper's face. The final spot is measured by the build inside the Kiosk reservation (the old spot, plot frame x 31.6, u 252.4, is only a starting point). The stand is unchanged: 4.6 x 5 studs on two cream posts with the red-orange cap, built by `Props.kioskBoard`.
- Face: the existing face, 4.3 x 4.7 studs = **215 x 235 px** at SurfaceGui `PixelsPerStud` 50 (frame 5a draws it at 2x, 430 x 470, for readability). Fill island navy #243A62. All text Fredoka One, centred, outlined #141B33 with thickness `max(1, floor(size / 14))`; `TextScaled` with the sizes below as the maximum and 12 as the minimum.
- The picture is gone: no ViewportFrame, no next-level picture, no level name, no "NEXT: NAME", no "PRICE: PREVIEW". With no ViewportFrame the old PlayerGui-parented SurfaceGui workaround (found 2026-10-28) is no longer needed for the picture; the build may use an ordinary SurfaceGui on the face.
- Owner view, rows at 1x px (y from the top of the face, h = row height):

| Row | y | h | Text | Size | Colour |
|---|---|---|---|---|---|
| Level | 10 | 26 | RACEWAY LEVEL 4 | 22 | yellow #FACE46 |
| Label | 42 | 18 | LAP PAY | 16 | cream #FFF6E0 |
| Values | 58 | 30 | x1.35, a right arrow 20 x 14, an up-arrow cue 14 x 17, x1.50 (centred row, gaps 5) | 24 | x1.35 and the arrow cream; the cue and x1.50 light teal #51D7D1 (the cue has a #141B33 outline) |
| Next | 100 | 22 | NEXT: LEVEL 5 | 18 | cream |
| New | 126 | 40 | New: flag official, start lights (up to two lines, 19 px line height, inset 14 each side) | 16 | cream |
| Price | 172 | 24 | PRICE: SET BY ECONOMY in a strip inset 12 each side: 2 px dashed mint border, radius 8 | 14 | mint #80D8BD |
| Marker | 202 | 18 | PREVIEW in a 59 px pill, 2 px mint outline, radius 9, centred | 12 | mint |

  The price strip and PREVIEW marker stay until Brian L's prices exist; no currency amount is ever shown here. Whole-face margins: 10 at the top, about 15 at the bottom.
- Visitor view: the same face with no change. Read-only: no prompt, no BUY, nothing to press. The upgrade prompt is a separate ProximityPrompt on the shopkeeper's counter and appears for the plot owner only.
- MAX view (level 12): "RACEWAY LEVEL 12" (22 yellow, y 10); "MAX LEVEL" (34 cream, 2 px outline, y 52, h 44); a teal #228A92 bar 99 x 6, radius 3, centred at y 100; "LAP PAY" (16 cream, y 126, h 20); "x3.50" (30 cream, y 146, h 36). No next level, no price strip, no PREVIEW marker, no promise of another level.
- Text changes instantly when the plot's preview level changes (no animation, so nothing differs under Reduced Motion).

### R2. Level-up banner (replaces section 2)
See [[raceway-level-banner]]: "RACEWAY LEVEL N!" only, one line where it fits, 0.18 s in, 1.10 s hold, 0.22 s out, latest-only.

### R3. Big screen display (levels 8 to 12; replaces the Lineup rows)
- Face: the existing big-screen face, 20 x 11 studs = **500 x 275 px** at `PixelsPerStud` 25 (frame 5d, drawn 1x). Fill stays #141B33 (the face's current colour, kept so it still reads as a screen).
- Near: one label "RACEWAY LEVEL N" (N is the plot's level, 8 to 12), Fredoka One 48, `TextScaled` max 48 min 28, cream #FFF6E0, no outline, centred in a 500 x 60 box at (0, 78); one small teal #228A92 underline 160 x 8, radius 4, at (170, 150). Nothing else: no cycling, no flashing border, no payout numbers, no ticker, no brand. The old "LINEUP" and "PREVIEW" labels and the four rows (CAR 1 COMMON ...) are removed.
- Far (proposal, tune in Studio): beyond about 80 studs from the camera (10 stud hysteresis) the letters are dropped and the face shows only broad shapes: a cream bar 310 x 40, radius 10, at (95, 92) and the same teal underline. Reversible: a plain navy panel with no shapes. 80 studs comes from legibility: the 48 px letters are about 1.9 studs tall, which is about 28 px tall on a 1080p screen at 60 studs and about 14 px at 120; on a phone they are roughly a third of that.
- Reduced Motion: nothing animates, so nothing changes. Text swaps when the level changes.

### R4. Shop fascia sign (replaces the old "UPGRADES" kiosk sign)
- One sign, 9 x 1.6 studs = **450 x 80 px** at `PixelsPerStud` 50 (frame 5b draws it 2x, 900 x 160), under the shop roof on the front, facing the plot entrance. One header only: no second sign competing with it.
- Cream #FFF6E0 fill, corners 6, a 2 px inner line in #243A62 inset 5; text "RACEWAY UPGRADES" in #243A62, Fredoka One 38, `TextScaled` max 38 min 24, centred, no outline (estimated 377 px wide by the 0.62 em average, in a 440 px field). Static text, no states.
- Replaces the 5.0 x 0.9 stud "UPGRADES" panel on the old booth ([[plot-track-signs]], "Kiosk sign").

### R5. Owner sign and plot gate beam (text only)
- Owner sign text: "ADAM'S RACEWAY" (before "ADAM'S SPEEDWAY"); with no owner name: "YOUR RACEWAY". `Signs.banner` placeholder "PLAYER'S SPEEDWAY" becomes "PLAYER'S RACEWAY". The text is one letter shorter, so the existing `TextScaled` limits still fit.
- Plot gate beam name row: "YOUR RACEWAY" (before "YOUR SPEEDWAY"). Size, position, TextScaled limits (max 58, min 24), outline and every other row on the beam are unchanged. Frame 5e shows the before and after strings; the plate art is not redrawn.

### R6. Parking sign, ADD SPOT plaque, prompts
See [[raceway-parking-panel]] (the sign face and plaque) and [[raceway-upgrade-panel]] (the shop). Both prompts use Roblox's default ProximityPrompt style, unchanged: ActionText "Upgrade Raceway" with ObjectText "Raceway shop" on the shopkeeper's counter; ActionText "Buy Parking Spot" with ObjectText "Parking" on the parking sign. Owner only.

## Round 1 (2026-10-28), kept for history; sections 1 and 2 are SUPERSEDED by Round 2 above

- **Workflow:** task-scoped Studio-first exception to the Figma-first rule (`AGENTS.md`, [[0012-figma-ui-workflow]]), approved by Adam on 2026-10-28 for this task only ("Studio-first exception"): specified here, built in the preview marked PREVIEW, reviewed by Adam at the final review. A Figma mock can follow if Adam wants one. Not a workflow change.
- Approval: pending (Adam, final review of the Speedway upgrade looks task).
- Fonts and touch targets from the approved tokens (`src/shared/UI/Tokens.luau`): Fredoka One, 36 display / 24 value / 18 label / 16 minimum; touch targets 48 px minimum. No other font or size is introduced.
- Colours from the island and HUD palette: navy `#243A62` panels, cream `#FFF6E0` text, yellow `#FACE46` headings, mint `#80D8BD` PREVIEW tags, coral `#F47F70` accents, near-black navy `#141B33` outlines.

## 1. Kiosk upgrade board (world sign, every plot) - SUPERSEDED by Round 2 R1 (2026-10-29)
- Where: a standing board beside the Paddock kiosk, plot frame x 31.6, u 252.4, facing the park; 4.6 x 5 studs on two cream posts, navy face with a red-orange cap. Built by `Props.kioskBoard`, filled by `Home/Island/Speedway/Kiosk`.
- Content, top to bottom: "SPEEDWAY LEVEL n" (yellow), the current level's name (cream), "NEXT: NAME" (cream), a picture of what the next level adds (the next level's main piece in a ViewportFrame, seen from the plaza side), one line of what it adds, and "PRICE: PREVIEW" (mint). No currency amount: prices are Lane 2's.
- Top level: "TOP LEVEL!" and "Every look is built." with the PREVIEW tag, never an invalid next level.
- Nothing to press; it is a sign. Purchases and prompts belong to Lane 2.

## 2. Level-up banner (HUD, on a level-up of your own plot) - SUPERSEDED by [[raceway-level-banner]] (2026-10-29)
- Text: `SPEEDWAY LEVEL 5: THE FLAG OFFICIAL!` (Ladder.banner), Fredoka One 36, cream with a near-black navy outline, on a navy pill with a coral border, top centre (14 % down), above the gameplay HUD.
- Motion: scales in with a small bounce (0.45 s), holds about 2.7 s, fades (0.4 s). Reduce Motion: fades in and out in place.
- Never blocks input (no button, no modal).

## 3. Ghost preview (world, your plot only)
- The next level's main piece as a faint light-blue outline (82 % transparent, no text, no figures, no lights, no collision), so kids see what they are working toward. Your plot only, so other plots stay clean. Off for clean captures (preview panel "Ghost").

## 4. Preview panel (Studio playtests only)
- Bottom left, navy panel: "SPEEDWAY PREVIEW · Plot n · Level n", then buttons "-" and "+" (56 x 48), "Plot" (cycles the plot it drives) and "All" (every plot at this level), then "Ghost", "Calm" (the preview-only Reduce Motion override) and "Hide". All buttons at least 48 px tall, Fredoka 18.
- Only in Studio (`RunService:IsStudio()`); it sets LocalPlayer attributes only. Never part of the game.
