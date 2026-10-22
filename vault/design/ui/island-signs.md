---
title: Island park signs
tags: [design, ui]
status: draft
---

# Island park signs

- Figma: **not yet drawn.** The "Car Hop UI" file link is not recorded in the vault or in [[0012-figma-ui-workflow]]; the mock is drawn as soon as Adam sends the link (or says to create the file). Writes are exempt from the read limit; this spec needs no read.
- Frames (world-space signs, not screen UI): one frame per board shape at 100 px per stud, plus one eye-level frame of a signpost from 12 studs.
- Approval: pending (Adam). Until approved, every board stays blank in the game ([[island-rework]] IRW-49, IRW-79).
- Hand edits in Figma since the spec was written: none.
- Figma reads used for this screen: 0 ([[figma-reads]]).

## Purpose
Help a player standing anywhere in the park see which way the three portals, the Garage, the Stunt Circuit and the lake are, without reading a map. Signs are world props: nothing to press, no prompts, no prices. They never stand in a viewing corridor taller than 3 studs ([[island-rework]] IRW-15), which the build already enforces.

## Where the text goes
| Sign | Count in the build | Faces with text | Board size (studs) | SurfaceGui canvas |
|---|---|---|---|---|
| Signpost arrow board (kit `Signpost`, 3 boards per post at heights 7.0, 5.65, 4.3) | 6 posts, 18 boards | both faces of each board | 4.2 × 0.95 | 420 × 95 px (PixelsPerStud 100) |
| Food stand header (optional, see questions) | 4 stands | front | about 3.0 × 0.6 | 300 × 60 px |

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
| Small icon (optional) | 56 × 56 px before the text | to be drawn in Figma; none in the game until approved |

Legibility target: the text is about 0.58 studs tall, readable at eye level from about 25 studs on desktop. That was measured from the greybox board heights; the phone check is still to do.

## Tokens used
Font: Fredoka One (approved). The cream, outline brown and destination colours are **new proposals**, not yet in `src/shared/UI/Tokens.luau`; they go into the module only once this spec is approved.

## Motion
None. Signs are still, and reduced motion changes nothing here.

## Questions for Adam (batched with the final review)
1. The "Car Hop UI" Figma link, or permission to create that file.
2. Food stand headers: plain names only ("HOT DOGS", "POPCORN", "ICE CREAM", "LEMONADE"), or no text so nothing looks like a shop? This spec's default is no text.
3. Icons next to names: yes or no.
