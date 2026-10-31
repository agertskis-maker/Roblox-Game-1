---
title: Island park signs
tags: [design, ui]
status: draft
---

# Island park signs

- Figma: "Car Hop UI", https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3, page **"Island signs"** (node `0:1`). Created on 2026-10-21 in Adam's Figma account (agertskis, Starter plan, "Adam Gertskis's team") with Adam's permission; no existing file link was recorded anywhere, so it could not be checked for an earlier copy. If an older "Car Hop UI" file turns up in Adam's drafts, keep one and delete the other.
- Frames (world-space signs, not screen UI): one frame per board face at 100 px per stud, plus phone readability frames (true size in points, camera FOV 70, vertical). Revision 2 (2026-10-22) node ids:

| Frame | Node id | Status |
|---|---|---|
| Heading "1. Signpost boards, revision 2" | `5:139` | context |
| Signpost board – PORTALS – arrow right / arrow left | `5:140` / `5:147` | draft, final review |
| Signpost board – GARAGE – arrow right / arrow left | `5:155` / `5:162` | draft, final review |
| Signpost board – STUNTS – arrow right / arrow left | `5:170` / `5:177` | draft, final review |
| Signpost board – PLOTS – arrow right / arrow left | `5:185` / `5:192` | draft, final review |
| Signpost board – LAKE – arrow right / arrow left | `5:200` / `5:207` | draft, final review |
| Signpost from 20 studs – phone landscape 749 x 381 | `5:215` | context (readability) |
| Signpost from 20 studs – phone portrait 401 x 777 | `5:240` | context (readability) |
| Icon library (the ten PNGs, identical to the game images) | `4:140` (images `4:141` to `4:159`) | draft, final review |
| Stand header – Hot dog / Popcorn / Ice cream / Lemonade (components) | `2:3` / `2:25` / `2:80` / `2:111` | decided (faces kept), unchanged |
| Stand front – Hot dog / Popcorn / Ice cream / Lemonade | `3:3` / `3:61` / `3:160` / `3:219` | checked and fixed 2026-10-22 |
| Note – Adam's decisions (2026-10-22) and final-review items | `3:279` | context |
| Export sheet (image export, positions below) | `9:410` | draft |
| Superseded 2026-10-22: old six World-name signpost boards (section) | `4:139` (holds `1:3` to `1:40`) | superseded, kept for history |

Related specs drawn on the same page: [[plot-track-signs]] (section 4) and [[portal-sign]] (section 5).

- Approval: Adam's decisions of 2026-10-22 (Task 3 brief), recorded here; the new frames are **draft, pending Adam's final review (Task 3)**. He reviews them at the final review, not mid-task.
  1. Board colour: plank brown `#B08456` (decided; replaces the lighter `sign_board` `#ECD6AA` on the kit mesh face).
  2. Food pictures: keep the small smiling faces (decided).
  3. Header board: the 3.0 × 1.6 stud header board on each stand (decided). Adam asked for the four never-checked stand front frames to be checked and fixed: done 2026-10-22, see "Food stand headers".
  4. Signpost boards: "short, kid-readable, icon first", five destinations: Portals, Garage, Stunt Circuit, Plots, Lake, replacing the old six World-name boards (decided). The look of the new boards is pending the final review.
  Until the final review, every board stays blank in the game ([[island-rework]] IRW-49, IRW-79).
- Hand edits in Figma since the spec was written: none.
- Figma reads used for this screen: 4 of the month's 6, all logged in [[figma-reads]]: `whoami` and one screenshot on 2026-10-21; two `get_screenshot` calls of the Export sheet on 2026-10-22 (the first served the export and the first visual check of the stand fronts and the new mocks; the second checked the fixes and is the final export). No reads remain in the Task 3 budget.

## Purpose
Help a player standing anywhere in the park see which way the portals, the Garage, the Stunt Circuit, the plots and the lake are, without reading a map. Signs are world props: nothing to press, no prompts, no prices. They never stand in a viewing corridor taller than 3 studs ([[island-rework]] IRW-15), which the build already enforces.

## Where the text goes
| Sign | Count in the build | Faces with text | Board size (studs) | SurfaceGui canvas |
|---|---|---|---|---|
| Signpost arrow board (kit `Signpost`, 3 boards per post at heights 7.0, 5.65, 4.3) | 6 posts, 18 boards | both faces of each board | 4.2 × 0.95 | 420 × 95 px (PixelsPerStud 100) |
| Food stand header (picture, no text; approved new board) | 4 stands | front | 3.0 × 1.6 | 300 × 160 px (PixelsPerStud 100), or the exported image as a Decal |

Bunting and the gazebo carry no text.

## Content
Each post's three boards point to its three nearest destinations along the paths, chosen by the build from the post's position (reversible detail). Five destinations (Adam, 2026-10-22):

| Destination | Board text | Icon (PNG) | Badge colour |
|---|---|---|---|
| Portals (the portal row) | PORTALS | `icon-portal.png` (arched doorway with an energy swirl) | `#BA5CFF` portal violet (`WorldPalette.PortalDowntown`) |
| Garage | GARAGE | `icon-garage.png` (a car) | `#D9503F` warm red (proposal) |
| Stunt Circuit | STUNTS | `icon-stunt.png` (a car jumping off a ramp) | `#F7CE58` (`WorldPalette.Yellow`) |
| Plots | PLOTS | `icon-plots.png` (racetrack oval with a chequered start line) | `#FF963C` amber (the `WorldPalette.PortalDustyHighway` swatch; proposal for this use, and it matches the Dusty Highway portal sign badge, so Adam may prefer another colour) |
| Lake and falls | LAKE | `icon-lake.png` (three waves) | `#51D7D1` (`WorldPalette.ShallowWater`) |

"STUNT CIRCUIT" does not fit at 52 px next to the icon (it would need about 34 px), so the board says **STUNTS** (decision made for Adam, reversible; open at the final review). Longest board word: PORTALS (235 px at 52 px).

## Layout (per board face, 420 × 95 px)
The plank arrow is the kit mesh (square end at the post, tip 0.6 studs = 60 px long). The SurfaceGui draws only the badge, the icon and the label, on a transparent background. `x0` = 0 on a right-pointing face (tip at x 360–420) and 60 on a left-pointing face (tip at x 0–60).

| Element | Position and size (px) | Token / value |
|---|---|---|
| Board face | the mesh, plank `#B08456`, 4 px `#3B2A1E` edge (drawn in Figma for context only) | kit palette "plank" |
| Icon badge (Frame + UICorner 1,0 + UIStroke) | x0 + 12, y 7.5, 80 × 80 | badge colour per destination, 4 px stroke `#3B2A1E` |
| Icon (ImageLabel) | x0 + 20, y 15.5, 64 × 64, ScaleType Fit | the destination PNG |
| Label (TextLabel) | x0 + 104, y 16, 248 × 63, left aligned, centred vertically | Fredoka One 52, cream `#FFF6E0`, UIStroke 4 px `#3B2A1E` |
| Measured label widths at 52 px | PORTALS 235, GARAGE 220, STUNTS 209, PLOTS 168, LAKE 137 | all fit the 248 px zone |

- **Icon first, both faces (decision made for Adam, reversible):** the icon always sits at the left, where reading starts, and the label follows it. On a left-pointing face that puts the icon next to the tip; on a right-pointing face it sits at the post end. Text is never mirrored; the back face is the same layout with `x0` = 60.
- **Colour stripe dropped:** the destination colour moved from a stripe at the tip into the icon badge, where it reads with the icon at a distance. If Adam wants the stripe back, it is 60 px wide inside the tip only.
- **Text height:** "at least 50 px tall" is met as a 52 px font size (0.52 studs); the capital letters themselves are about 36 px tall. Capitals 50 px tall would need a 72 px font, which does not fit any word next to the icon.

Legibility (frames `5:215` and `5:240`; camera FOV 70 vertical, eye 6 studs above the ground, looking level, boards facing the camera):

| View from 20 studs | Points per stud | Board | Icon badge | Label capital height | Verdict |
|---|---|---|---|---|---|
| Phone landscape 749 × 381 pt | 13.6 | 57 × 13 pt | 11 pt | about 5 pt | icon shape and colour readable; the word is too small |
| Phone portrait 401 × 777 pt | 27.7 | 117 × 26 pt | 22 pt | about 10 pt | icon and word readable |

The 16 px text minimum is a screen-UI token; world text at 20 studs in landscape falls below it, which is why the icon comes first. From about 10 studs the landscape view doubles these sizes.

## Food stand headers (Adam's decisions, 2026-10-21 and 2026-10-22)
2026-10-21, Adam: "Remove words from their headers. Each should eventually have one large, cute, original painted picture: hot dog, popcorn, ice cream cone, lemonade glass. Use bold silhouettes, restrained detail, and clear color separation so each is recognizable from the walkway. Keep their illustration style consistent. No prices, purchase prompts, buttons, or other shop interactions." 2026-10-22: keep the small smiling faces; the 3.0 × 1.6 stud header board on each stand is approved.

Where the board goes (from `assets/island/kit/kit_props.py`): the kit has **no header board** yet, so this is a new flat board per stand. Carts (HotDogCart, PopcornCart) body 6.0 × 2.4 studs, awning front 6.8 wide rising from 6.6 to 7.6 studs with scallops down to 6.15; booths (IceCreamStand, LemonadeStand) body 6.0 × 3.8, roof front 7.0 wide rising from 4.9 to 6.4 with scallops down to 4.4, and an open gap of 1.1 studs between the body top (3.8) and the roof edge (4.9).

| Element | Value |
|---|---|
| Header board | 3.0 × 1.6 studs on all four stands, so the pictures share one scale; SurfaceGui 300 × 160 px, PixelsPerStud 100, front face only (or the exported PNG as a Decal). The in-progress kit `HeaderBoard` (`kit_plot.py`, another session) has a 0.1-stud bark frame, so its face is 2.8 × 1.4 studs with hang eyes at x ±1.0: either print the picture inside that face (280 × 140 px, the picture keeps its aspect and the sky panel fills the rest) or drop the frame (open question) |
| Carts (hot dog, popcorn) | **changed 2026-10-22:** hangs on two dark straps (0.1 studs wide) from the awning's front edge, just below the scallop tips, centred between the poles: bottom **4.45**, top **6.05** studs (was 5.0 to 6.6, which hid the middle scallops) |
| Booths (ice cream, lemonade) | **changed 2026-10-22:** mounted on the front of the roof fascia and resting on the body's top edge: bottom **3.8**, top **5.4** studs (was 3.75 to 5.35, 0.05 studs into the body). The 1.1-stud gap under the roof is smaller than the board, so it has to cover the middle scallops here |
| Board art | cream rim `#FFF6E0` with a 6 px dark brown outline `#3B2A1E`, pale sky panel `#DFF3FA`, corner radius 26 px; the corners outside the radius are plank `#B08456` in the exported image |
| Picture style | one item per board, filling the board height; 4–5 px dark brown outlines; flat colours with one shade step and one soft white highlight; small smiling face (eyes, smile, pink cheeks) on each item; no words, prices or prompts |
| Pictures | hot dog (red sausage, mustard zigzag, bun); popcorn (red and cream striped bucket, popcorn puffs, two flying kernels); ice cream (waffle cone, pink scoop, vanilla scoop, cherry); lemonade (glass, ice cubes, pink straw, lemon slice) |

Visual check of the four stand front frames (2026-10-22, first time they were seen): pictures, scale and centring were right. Fixed: the cart boards covered the middle awning scallops (now hung below them on straps); every rooftop sculpture floated 4–14 px (0.06–0.22 studs) above its roof (now resting on it); the hot dog sculpture's sausage was drawn behind the bun and showed only as two red ends (now drawn in front); the booth boards dipped 0.05 studs into the body (now resting on the body top). The frames' captions were updated to the new heights. These sculptures are 2D stand-ins for the kit's 3D sculptures; the kit models were not changed.

Seen from 12 studs at 1080p the header is about 192 × 102 px on screen (Stand front frames).

## Tokens used
Font: Fredoka One (approved; Figma has "Fredoka One Regular"). Plank `#B08456` is decided (2026-10-22). Cream `#FFF6E0`, outline brown `#3B2A1E`, sky panel `#DFF3FA`, the badge colours and the grain `#9A7048` are **proposals** for `src/shared/UI/Tokens.luau`, added there only after the final review. Badge colours reuse `WorldPalette` swatches where one exists (table above). Figma colours are plain values, not variables, until the tokens exist.

## Assets
Sources: icons are drawn by `icons.js` (dependency-free Node script, signed-distance shapes, 4× supersampled, 256 × 256 RGBA with transparency, cream glyph `#FFF6E0` with a 12 px `#3B2A1E` outline). Header images come from the Export sheet (`9:410`, read on 2026-10-22). None is uploaded or in `vault/design/assets.md` yet; upload only with Adam's approval ([[0012-figma-ui-workflow]] step 7). Asset IDs are never invented.

| Image | Drawn in Figma (node) | Exported file (Task 3 scratchpad `task3fig\`) | Size | Upload approved | Asset ID |
|---|---|---|---|---|---|
| Portal, Garage, Stunt Circuit, Plots, Lake icons | Icon library `4:141`, `4:143`, `4:145`, `4:147`, `4:149` | `icons\icon-portal.png`, `icon-garage.png`, `icon-stunt.png`, `icon-plots.png`, `icon-lake.png` | 256 × 256 | no | none |
| Arrow, coin, tick, lock, wrench-and-star icons | `4:151`, `4:153`, `4:155`, `4:157`, `4:159` | `icons\icon-arrow.png`, `icon-coin.png`, `icon-tick.png`, `icon-lock.png`, `icon-wrench.png` | 256 × 256 | no | none |
| Stand headers | `2:3`, `2:25`, `2:80`, `2:111` | `export\header-hotdog.png`, `header-popcorn.png`, `header-icecream.png`, `header-lemonade.png` | 300 × 160 | no | none |

Export sheet positions (frame `9:410`, 1380 × 1480 px, magenta `#FF00FF` background so a bad crop shows; each asset at scale 1 = 100 px per stud):

| Asset | x, y | w × h |
|---|---|---|
| header-hotdog | 20, 20 | 300 × 160 |
| header-popcorn | 340, 20 | 300 × 160 |
| header-icecream | 660, 20 | 300 × 160 |
| header-lemonade | 980, 20 | 300 × 160 |
| banner-zoopa-fizz | 20, 200 | 1000 × 160 |
| banner-crunchkin-puffs | 20, 380 | 1000 × 160 |
| banner-stickytoe-tyres | 20, 560 | 1000 × 160 |
| banner-wobblebot-toys | 20, 740 | 1000 × 160 |
| owner-banner-bg | 20, 920 | 1000 × 160 |
| nameplate-bg | 20, 1100 | 1000 × 250 |
| kiosk-bg (resized after the last read; PNG drawn locally, see [[plot-track-signs]]) | 20, 1370 | 500 × 90 |

## Motion
None. Signs are still, and reduced motion changes nothing here.

## Decisions made in this pass (reversible)
- Board word STUNTS for Stunt Circuit (fit at 52 px).
- Icon at the reading start on both faces; destination colour in the icon badge instead of a tip stripe.
- Badge colours for Garage (`#D9503F`) and Plots (`#FF963C`).
- Cart and booth header heights changed as above to stop hiding scallops and to sit on the body.

## Questions for Adam (batched with the final review)
1. ~~The "Car Hop UI" Figma link, or permission to create that file.~~ Answered 2026-10-21.
2. ~~Food stand headers: plain names or no text?~~ Answered 2026-10-21: no text, one picture each.
3. ~~Icons next to names on the signpost boards.~~ Answered 2026-10-22: icon first.
4. ~~Board colour, faces on the pictures, header board size.~~ Answered 2026-10-22.
5. Approve or change: the five board faces and icons, STUNTS, the badge colours, and the new cart and booth header heights.
6. Header picture on the kit board's 2.8 × 1.4 face, or a board without the bark frame.
