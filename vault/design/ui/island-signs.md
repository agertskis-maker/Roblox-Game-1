---
title: Island park signs
tags: [design, ui]
status: draft
---

# Island park signs

- Figma: "Car Hop UI", https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3, page **"Island signs"** (node `0:1`). Created on 2026-10-21 in Adam's Figma account (agertskis, Starter plan, "Adam Gertskis's team") with Adam's permission; no existing file link was recorded anywhere, so it could not be checked for an earlier copy. If an older "Car Hop UI" file turns up in Adam's drafts, keep one and delete the other.
- Frames (world-space signs, not screen UI): one frame per board at 100 px per stud, plus eye-level frames at 64 px per stud (how big the sign looks on a 1080p screen from 12 studs, camera FOV 70). Node ids:

| Frame | Node id | Needs approval |
|---|---|---|
| Signpost board – DOWNTOWN | `1:4` | yes |
| Signpost board – DUSTY HIGHWAY | `1:10` | yes |
| Signpost board – SUMMIT PASS | `1:16` | yes |
| Signpost board – GARAGE | `1:22` | yes |
| Signpost board – STUNT CIRCUIT | `1:28` | yes |
| Signpost board – LAKE | `1:34` | yes |
| Signpost – eye level from 12 studs (1080p) | `1:40` | context only |
| Stand header – Hot dog (component) | `2:3` | yes |
| Stand header – Popcorn (component) | `2:25` | yes |
| Stand header – Ice cream (component) | `2:80` | yes |
| Stand header – Lemonade (component) | `2:111` | yes |
| Stand front – Hot dog | `3:3` | yes (header board size and place) |
| Stand front – Popcorn | `3:61` | yes (header board size and place) |
| Stand front – Ice cream | `3:160` | yes (header board size and place) |
| Stand front – Lemonade | `3:219` | yes (header board size and place) |
| Note – needs Adam's approval | `3:279` | lists the items below |

- Approval: pending (Adam). Until approved, every board stays blank in the game ([[island-rework]] IRW-49, IRW-79). Items to approve:
  1. The signpost board look (six board frames).
  2. The six destination stripe colours (new proposals, not yet tokens).
  3. Board face colour: plank `#B08456` as this spec says (drawn), or the lighter `sign_board` swatch `#ECD6AA` the kit mesh face uses now.
  4. The four wordless header pictures, including their small smiling faces (or without faces).
  5. The new 3.0 × 1.6 stud header board and where it hangs on each stand (four stand front frames).
- Hand edits in Figma since the spec was written: none.
- Figma reads used for this screen: 2 of the month's 6 (`whoami` for the plan key, one screenshot check of the header pictures), both logged in [[figma-reads]]. The stand front frames were drawn but not visually checked.

## Purpose
Help a player standing anywhere in the park see which way the three portals, the Garage, the Stunt Circuit and the lake are, without reading a map. Signs are world props: nothing to press, no prompts, no prices. They never stand in a viewing corridor taller than 3 studs ([[island-rework]] IRW-15), which the build already enforces.

## Where the text goes
| Sign | Count in the build | Faces with text | Board size (studs) | SurfaceGui canvas |
|---|---|---|---|---|
| Signpost arrow board (kit `Signpost`, 3 boards per post at heights 7.0, 5.65, 4.3) | 6 posts, 18 boards | both faces of each board | 4.2 × 0.95 | 420 × 95 px (PixelsPerStud 100) |
| Food stand header (picture, no text; proposed new board) | 4 stands | front | 3.0 × 1.6 | 300 × 160 px (PixelsPerStud 100) |

Bunting and the gazebo carry no text.

## Content
Each post's three boards point to its three nearest destinations along the paths, chosen by the build from the post's position (reversible detail). Names are the World names already used in the greybox:

| Destination | Board text | Arrow colour (proposal) |
|---|---|---|
| Downtown portal | DOWNTOWN | portal violet |
| Dusty Highway portal | DUSTY HIGHWAY | portal amber |
| Summit Pass portal | SUMMIT PASS | portal ice blue |
| Garage | GARAGE | warm red (matches the building) |
| Stunt Circuit gate | STUNT CIRCUIT | yellow |
| Lake and falls | LAKE | turquoise |

Longest text: "DUSTY HIGHWAY" (13 characters), which sets the text size.

## Layout (per board face, 420 × 95 px)
| Element | Position and size | Token / value |
|---|---|---|
| Board | the mesh itself (warm plank, faceted edge) | kit palette "plank" |
| Colour stripe at the arrow tip | 70 × 95 px at the pointed end | per destination (table above) |
| Text | left 24 px to the stripe, centred vertically, height 58 px | Fredoka One, cream `#FFF6E0`, 3 px dark brown outline `#3B2A1E` |
| Text size (as drawn in Figma) | 36 px font size, 2 % letter spacing, same on every board | the largest size at which "DUSTY HIGHWAY" fits the 24–340 px text area (307 px wide) |
| Small icon (optional) | 56 × 56 px before the text | none drawn; none in the game until approved |

Back face: the same board mirrored (tip on the left, stripe on the left), text not mirrored and right-aligned 24 px from the square end.

Legibility target: the text box is 58 px (0.58 studs) tall, but the Figma check shows the width limit sets the font at 36 px (about 0.36 studs), so the letters are smaller than first estimated. The eye-level frame shows the result at 1080p from 12 studs; the 25-stud and phone checks are still to do.

## Food stand headers (Adam's decision, 2026-10-21)
Adam: "Remove words from their headers. Each should eventually have one large, cute, original painted picture: hot dog, popcorn, ice cream cone, lemonade glass. Use bold silhouettes, restrained detail, and clear color separation so each is recognizable from the walkway. Keep their illustration style consistent. No prices, purchase prompts, buttons, or other shop interactions." So the headers are pictures with no text.

Where the board goes (from `assets/island/kit/kit_props.py`): the kit has **no header board**. The front of each stand has striped awnings and a product sculpture on top, but no flat board for a picture. The flat fronts are: carts (HotDogCart, PopcornCart) body 6.0 × 2.4 studs, awning front 6.8 wide rising from 6.6 to 7.6 studs with scallops down to 6.15; booths (IceCreamStand, LemonadeStand) body 6.0 × 3.8, roof front 7.0 wide rising from 4.9 to 6.4 with scallops down to 4.4, and an open gap of 1.1 studs between the body top (3.8) and the roof edge (4.9). A striped, sloped awning cannot carry a picture cleanly, so this spec proposes one new flat header board per stand (a physical sign structure, allowed by IRW-49 once Adam approves its size):

| Element | Value |
|---|---|
| Header board | 3.0 × 1.6 studs, same on all four stands so the pictures share one scale; SurfaceGui 300 × 160 px, PixelsPerStud 100, front face only |
| Carts (hot dog, popcorn) | hung under the front edge of the awning, centred between the poles, bottom 5.0, top 6.6 studs |
| Booths (ice cream, lemonade) | hung on the front of the roof edge above the closed hatch, bottom 3.75, top 5.35 studs |
| Board art | cream rim `#FFF6E0` with a 6 px dark brown outline `#3B2A1E`, pale sky panel `#DFF3FA`, corner radius 26 px |
| Picture style | one item per board, filling the board height; 4–5 px dark brown outlines; flat colours with one shade step and one soft white highlight; small smiling face (eyes, smile, pink cheeks) on each item; no words, prices or prompts |
| Pictures | hot dog (red sausage, mustard zigzag, bun); popcorn (red and cream striped bucket, popcorn puffs, two flying kernels); ice cream (waffle cone, pink scoop, vanilla scoop, cherry); lemonade (glass, ice cubes, pink straw, lemon slice) |

Seen from 12 studs at 1080p the header is about 192 × 102 px on screen (Stand front frames). The pictures reach the game only as exported images, listed in `vault/design/assets.md` and uploaded with Adam's approval ([[0012-figma-ui-workflow]] step 7).

## Tokens used
Font: Fredoka One (approved; Figma has "Fredoka One Regular", no substitute needed). The cream, outline brown, sky panel and destination colours are **new proposals**, not yet in `src/shared/UI/Tokens.luau`; they go into the module only once this spec is approved. Destination stripe colours as drawn: Downtown `#BA5CFF`, Dusty Highway `#FF963C`, Summit Pass `#6ED2FF` (the three `WorldPalette` portal swatches), Garage `#D9503F` (proposal), Stunt Circuit `#F7CE58` (`WorldPalette.Yellow`), Lake `#51D7D1` (`WorldPalette.ShallowWater`). Figma colours are plain values, not variables, until the tokens exist.

## Motion
None. Signs are still, and reduced motion changes nothing here.

## Questions for Adam (batched with the final review)
1. ~~The "Car Hop UI" Figma link, or permission to create that file.~~ Answered 2026-10-21: permission given; file created (link above).
2. ~~Food stand headers: plain names or no text?~~ Answered 2026-10-21: no text, one picture each (section above).
3. Icons next to names on the signpost boards: yes or no.
4. Approve or change the five items listed under Approval at the top.
