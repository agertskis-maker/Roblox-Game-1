---
title: Raceway parking panel, parking sign and ADD SPOT plaque
tags: [design, ui, raceway, parking]
status: "pending Adam's approval"
---

# Raceway parking panel, parking sign and ADD SPOT plaque

- Figma: Car Hop UI, page 'Raceway round 2 (pending Adam)' - https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3?node-id=25-747 (imported 2026-10-29 from `Car-Hop-Art/review/raceway-round2/mocks/raceway-ui-mocks.html` with html_to_figma: flat layers, text outlines may be dropped by the import; the spec values win)
- Mock: `Car-Hop-Art\review\raceway-round2\mocks\raceway-ui-mocks.html`, frames 3a (desktop 1920 x 1080), 3b (phone landscape 844 x 390), 3c (tablet landscape 1180 x 820), 3d (15 of 15 state), 5b (ADD SPOT plaque), 5c (parking sign), 6 (prompt text), 7 (BUY states).
- Brief: [[raceway-round2]] PART 5 and DESIGN 5 (Adam, 2026-10-29). Workflow: Figma-first ([[0012-figma-ui-workflow]]). Approval: pending Adam. Nothing here is approved. Hand edits in Figma: none. Figma reads used: none.
- Same card style, tokens, fonts, sizes, button states and safety rules as [[raceway-upgrade-panel]]; this file lists only what differs. Where it is silent, that file applies.
- Adam's decision (recorded for the ledger): everyone starts with 2 parking spots. Parking spots and Raceway levels are two separate upgrades with separate state; the save field names (`ParkingSpots`, start 2, max 15) are a proposal for Brian L, not built here.

## Purpose, entry and exit
- A small panel that shows how many of the 15 Paddock bays the owner has, which bay is next, and a BUY button. Bays are bought one at a time. The panel never calculates or shows a price: "PRICE: SET BY ECONOMY" is a fixed label.
- Opens only for the plot owner, from the ProximityPrompt "Buy Parking Spot" (ObjectText "Parking") on the parking sign beside the Paddock. Roblox's default prompt style, unchanged (frame 6). Visitors get no prompt and see the sign read-only.
- Exits, ownership safety and "opening or closing never replays the reveal": identical to [[raceway-upgrade-panel]].

## Panel layout (design px, UIScale = `Tokens.uiScaleFor`, 1.5 on desktop and tablet, 1.0 on phone)
Card 520 x 300 (780 x 450 screen px at 1.5), fill `Color.Card`, UIStroke `Stroke.Thick` 4 navy outside, `Radius.Panel` 20, same shadow, padding 20 (16 on phone). Inner height 260 on desktop, 268 on phone, no scrolling needed (the phone safe height is 358). Same scrim.

| # | Row | Height | Gap above | Content |
|---|---|---|---|---|
| 1 | Header | 48 | 0 | title "PARKING SPOTS" (24 navy), close button 48 x 48 |
| 2 | Tiles | 72 | 12 | OWNED tile, arrow, NEXT SPOT tile |
| 3 | Price strip | 32 | 8 | "PRICE: SET BY ECONOMY" |
| 4 | BUY row | 56 | 8 | BUY + "STUDIO PREVIEW" marker |
| 5 | Preview line | 20 | 4 | "No Cash spent. Progress is not saved." |

Tiles (two lines each: a label, then a 36 value):
- OWNED tile: 196 x 72, `CardInset` fill, UIStroke 2 navy, `Radius.Card` 14. Label "OWNED" 18 navy; value "2 / 15" 36 navy. Reads "OWNED 2 / 15".
- Arrow: 28 x 20 navy, same shape as the Raceway panel.
- NEXT SPOT tile (stronger): 240 x 72, `Teal` #228A92 fill, UIStroke 4 navy, `Radius.Card` 14. Label "NEXT SPOT" 18 and value "3" 36, both `Color.Card` cream with a navy outline (1 px for the label, 2 px for the value). Reads "NEXT SPOT 3".
- Text uses `TextScaled` with `MinTextSize` 16, so "2 / 15" and "14 / 15" never clip.

Everything else (price strip, BUY button, preview marker, preview line, close button, text roles, colours, contrast) is exactly as in [[raceway-upgrade-panel]].

## States
| Owned | Tiles | Price strip | BUY row | Preview line |
|---|---|---|---|---|
| 2 to 14 (preview) | OWNED k / 15, arrow, NEXT SPOT k + 1 | "PRICE: SET BY ECONOMY" | BUY + STUDIO PREVIEW | shown |
| 15 | "ALL SPOTS OWNED" (36 cream on `Teal` tile, 440 x 84, 4 px stroke, 3 px outline) over a `CardInset` tile 440 x 56 with "OWNED 15 / 15" (24 navy) | removed | removed | removed |
| Outside the preview fixture | as 2 to 14 but BUY Disabled, no marker, no preview line; the prompt is disabled so the panel normally cannot open | | | |

Card height stays 300 in the 15 state (reversible: shrink). The close button stays. No state ever shows a price number.

## BUY behaviour
Identical single-flight rule to [[raceway-upgrade-panel]]: accepted once per transition, rapid clicks cannot double-buy, state `Idle -> Locked -> Idle`, unlocked only when the sign count, the panel, and the Paddock all show the new count and the unlock reveal (about 0.9 s) has finished. In the preview fixture it raises the owned count by one (never above 15). No Cash, no saving, no remotes.

Independence (to be verified in Studio, both directions): changing the Raceway level never changes the owned spot count, and unlocking a spot never changes the Lap Pay multiplier or the Raceway level. The two panels have separate state values, separate transition guards and separate Locked states; reopening either panel, switching owner and visitor, and rapid clicks must leave the other value untouched.

## Parking sign (world face)
Flat face, drawn 2x in frame 5c (320 x 380 px at 2x). Real size: **3.2 studs wide x 3.8 studs total height** on a navy post, kept inside its existing reservation and away from the gate (the build measures the reservation and reports; this file sets no position).
- Board: 3.2 x 2.2 studs (160 x 110 px at SurfaceGui `PixelsPerStud` 50), cream #FFF6E0, beveled (a 2 px white top edge and a 3 px #DCD2B6 bottom edge at 1x, corners 8). The 2.2 stud board height is my decision (reversible); the brief fixes the 3.2 width and the 3.8 total.
- Teal inset: 146 x 96 px at (7, 7), `Teal` #228A92, corners 6, a 3 px `TealDark` #1A6870 lower edge.
- Contents inside the inset (1x px, origin top left of the inset): "P" 36 px at (10, 4) in a 34 x 40 box, cream #FFF6E0 with a 1.5 px #141B33 outline; a small plus 12 x 12 px at (40, 8), cream, 2.6 px strokes with round caps (the "add" cue next to the P); "PARKING" 17 px at (56, 8) in an 86 x 32 box, cream, 1.5 px outline, centred; the live count "k / 15" (k = owned) 34 px at (0, 46) in a 146 x 44 box, cream, 1.5 px outline, centred. All Fredoka One. The text is live SurfaceGui text, never baked into a mesh.
- Post: navy #243A62, 0.5 stud wide x 1.6 stud tall (25 x 80 px at 50 px per stud), with a #141B33 cap 0.8 wide x 0.12 high under the board.
- At 15 / 15 the sign stays and reads "15 / 15". Visitors see the same live count.
- "P" is a simple original letter shape, not a copy of any road-sign or brand mark.

## ADD SPOT plaque (world face)
Flat face, frame 5b. 1.8 x 0.6 studs = 180 x 60 px at `PixelsPerStud` 100 (drawn 2x). Navy #243A62, 6 px corners, a 2 px cream line at 45% opacity inset 4 px, text "ADD SPOT" 22 px cream #FFF6E0, Fredoka One, no outline, centred. Understated: no price, no arrow, no "FOR SALE", no icon. Mounted on the post of the barrier at the next bay's mouth, facing the walkway; removed at 15.

## Barrier and unlock reveal (world, summary; the barrier is a part, not UI)
- The next unowned bay shows one short navy-and-cream barrier arm at its mouth, about 2.0 studs high, plus the ADD SPOT plaque. Owned bays have clean cream ground lines and their existing car positioning. Bays beyond the next one are hidden as functional stalls; the Paddock keeps a plain surface so there are no holes. Hidden bays keep no invisible collision. No chains across routes, no red locks, no price balloons, no cone forest.
- The decorative arm is visual only: `CanCollide` false, `CanTouch` false, `CanQuery` false while closed, while moving and when open, so it can never trap or fling an avatar.
- Unlock timing, total about 0.9 s, started by an accepted BUY:
  1. t = 0: immediate acknowledgement (BUY press 0.1 s, then Locked; the sign count and the OWNED tile update at once).
  2. 0 to 0.25 s: the barrier pivots up about 80 degrees (Quad In-Out).
  3. 0.25 to 0.55 s (0.30 s): the bay's ground lines paint in from the mouth to the back (their length grows, Quad Out).
  4. from 0.25 s: 8 to 12 small confetti pieces in cream #FFF6E0, teal #228A92 and coral #F47F70, burst once, 0.2 to 0.35 stud, lifetime 0.45 to 0.6 s, so all are gone by about 0.9 s. No beam, no explosion, no camera shake.
  5. at 0.9 s: the next marker (barrier and plaque) appears at the next bay (0.15 s fade). At 15 no new marker is made and the old one is removed.
- Reduced Motion (`GuiService.ReducedMotionEnabled` or the preview-only override): the barrier is hidden at once (no pivot), the lines and the count switch immediately with a short 0.15 s fade, no confetti; the next marker fades in the same 0.15 s.
- One reveal at a time; a second accepted unlock cannot start while Locked.

## Sound
None added by this spec.

## Open questions for Adam
1. Parking board height 2.2 studs (default) within the fixed 3.8 total.
2. Visitors see the barrier and plaque (default: the world state is the same for everyone) or only the owner does.
3. Barrier arm shape and exact mounting need a short check against the Paddock mouth geometry (the build measures it; no mock exists for the 3D barrier).
4. Card height in the 15 state: keep 300 (default) or shrink.
