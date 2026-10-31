---
title: HUD reference study - Roblox UI
tags: [lane3, hud, research, references]
status: research
date: 2026-10-22
---

# HUD reference study: Roblox UI (2026-10-22)

Research only. It approves nothing. "Inference" marks my reading; every other claim comes from an image I viewed or a page I fetched. Stills cannot show animation.

## 1. Already approved (project files)
- `vault/design/visual-direction.md`:
  - HUD revision 4 approved by Adam on 2026-10-20: Cash top left, Distance top centre, Heat bottom centre, inside `CoreUISafeInsets`.
  - Cash floats with no card: Fredoka One, `#2EE65A` to `#A0F6B8` gradient, 3.5 px `#141B33` outline. The gain label sits below the number. `Format.cash` truncates.
  - Scale = short side / 390, from 1.0 up to 1.5. Text never shrinks.
  - Fredoka One 36/24/18/16, touch targets 48 px (primary 56 px) and `ReducedMotionEnabled`, approved 2026-10-19.
  - Notification badge: described, not built. A red `#E5484D` "!" used "for real new content only, never for pressure or countdowns".
  - Shop and Garage/Index buttons: deferred.
- `vault/decisions/0012-figma-ui-workflow.md`: Figma mock and `vault/design/ui/<screen>.md` spec before any build.
- `vault/design/car-hop-outline-v2.md` section 05: tutorial prompts never block, and no mission popups appear before the tutorial ends. Toast example: "Pip joined your Speedway!"

### Approved references viewed (`vault/design/references/`, no README; notes at `visual-direction.md` line 33)
- **ui-currency-counters-and-menu-buttons.png:**
  - Shop (rainbow) and Index (cyan) are thick black-outlined rectangles with a stud texture, a tilted icon hanging off the left edge, and a white outlined label.
  - A red "!" overlaps Index's top-right corner.
  - Small red Settings and Gear buttons sit above, about half the height of the big buttons.
  - Bottom left is a stack of three icon-plus-number currencies, each number with its own gradient and a heavy outline.
- **tutorial-01 to -05** (1440x852):
  - Yellow studded objective banner, top centre, about 41% of width and about 7.3% of height. Its top (y≈70) is level with Roblox's top-bar buttons.
  - A "TUTORIAL" tab overlaps the banner's top edge. Objective text is uppercase, outlined, with the counter inline in brackets: "GET 30 SKILLS (6/30)". Tutorial-04 shows an objective with no counter.
  - Tutorial-05 shows a green confirmation, "Scallop Shell purchased and equipped.", under the next objective.
  - A chevron trail on the ground points to the target.
  - **No progress strip** in any of these refs.

## 2. External sources (captured 2026-10-22)
Players online, from `games.roblox.com/v1/games` at 05:09 UTC:

| Game | Players |
|---|---|
| Adopt Me! | 118,414 |
| Blox Fruits | 107,306 |
| Pet Simulator 99 | 33,676 |
| Grow a Garden | 16,064 |
| Driving Empire | 16,035 |
| Jailbreak | 3,345 |
| Car Dealership Tycoon | 2,768 |

This is one snapshot, not a ranking.

Game-page thumbnails (PS99, Adopt Me, Blox Fruits, Driving Empire, Car Dealership Tycoon) were promotional art with no HUD; I viewed them and discarded them. The Driving Empire and Car Dealership Tycoon thumbnails also show real car-brand logos.

The HUD evidence comes from fan-wiki community uploads (Fandom, upload dates below) and Roblox docs. Files are in `C:\Users\agert\Documents\Car-Hop-Art\references\hud-downtown\roblox-ui\`:

| File | Source (uploaded) |
|---|---|
| wiki-drivingempire-stickers-gui-1920.webp | drivingempire.fandom.com/wiki/File:Stickers_GUI_Example.png (2026-04-09) |
| wiki-drivingempire-taxi-multiplier-bar.webp | drivingempire.fandom.com/wiki/File:TaxiEventMultiplierBar_UI.png (2023-03-28) |
| wiki-adoptme-hotbar.webp | adoptme.fandom.com/wiki/File:Hotbar.png (2024-06-17) |
| wiki-growagarden-buttons.webp | growagarden.fandom.com/wiki/File:Buttons.png (2025-04-17) |
| wiki-growagarden-goose-notification.webp | growagarden.fandom.com/wiki/File:Golden_Goose_Ability_Notification.png (2026-07-31) |
| wiki-growagarden-garden-guide-ui.webp | growagarden.fandom.com/wiki/File:Garden_Guide_UI.jpg (2025-08-14) |
| growagarden-01.png, -08.png | Roblox game-page thumbnails, universe 7436755782 |

Docs: create.roblox.com/docs/ui/position-and-size and /docs/input/mobile.

## 3. Observations

**O1. Number styling** (Grow a Garden thumbnails; approved ref).
- *Seen:* huge comma-grouped numbers with a vertical gradient (green, or rainbow in thumbnail 01) and a thick near-black outline, with no card.
- *Apply:* keep Cash as approved. Any secondary number reuses the 3.5 px outline at about 60% of the Cash numeral height (the 24 px token).
- *Limit:* marketing art, not the in-game HUD.

**O2. Earning line** (approved gain-below rule; "+1" floats in tutorial-02).
- *Apply:* place "+$12 / lap" under the Cash number, left-aligned to the "$" ink. Use 18 px mint `#A0F6B8` with a navy outline, at least 8 px from the gain label.
- *Inference:* the rate line competes with gain labels. Dim it to 50% while a gain plays.
- *Limit:* a still cannot show timing.

**O3. Colour-coded buttons** (Grow a Garden Buttons.png).
- *Seen:* flat saturated blue, brown and red rectangles with about a 4 px dark outline and white heavily outlined text. The centre button is about 1.25x taller.
- *Apply:* one hue per destination (Garage/Index cyan, Shop rainbow, Missions orange) with a 3-4 px navy `#1E2A4A` outline.
- *Inference:* the taller button marks the primary destination. If we use that cue, give it to Garage, not Shop.
- *Limit:* the image is a crop, so its screen position is unknown.

**O4. Icon overhang** (approved ref).
- *Seen:* tilted icons break the button's left edge by about 15% of the button width.
- *Apply:* original icons at about 1.1x the button height, tilted 8-10°. The hit area stays a rectangle of at least 56 px, clear of Roblox's top bar.

**O5. Labelled vertical stack** (Adopt Me Hotbar.png).
- *Seen:* right-edge square icon buttons, each with a coloured word under it (SHOP, DRESS UP, JOURNAL, FRIENDS). Top right there is a cash pill with a "$" icon.
- *Apply:* always pair an icon with a word, for young readers. On phone landscape, four buttons of 56 px with 8 px gaps make 248 px, about 64% of a 390 px height.
- *Limit:* the image is downscaled, so absolute sizes are unknown.

**O6. Thumb zones** (Roblox docs, quoted).
- *Quoted:*
  - "the default controls occupy a portion of the bottom-left and bottom-right corners"
  - "avoid placing important info or virtual buttons in these zones"
  - "A button placed 40% below the screen's top edge is reachable on a phone but almost unreachable on a tablet"
  - "The majority of Roblox sessions are played on mobile devices"
- *Apply:* the menu stack goes upper left, under Cash. Nothing goes in the two bottom-corner control zones. Design for phones first, and check tablet reach in the Device Simulator.

**O7. Banner proportions** (tutorial refs).
- *Apply:*
  - Desktop 1920x1080: about 38% of width (about 730 px) by 64 px.
  - Phone landscape 844x390: at most 46% of the safe width. Long objectives wrap to two lines and never shrink.
  - Phone portrait 390x844: full safe width minus 16 px gutters, below the Cash and Distance rows.
  - "TUTORIAL" is a 16 px tab overlapping the top edge by half its height.

**O8. Progress strip** (Driving Empire multiplier bar).
- *Seen:* a dark panel with a checkered top edge, a green fill bar with star milestone markers, a white end cap, and an "x1.5" label.
- *Apply:* an 8 px strip inside the banner's bottom edge, matching the counter. An original checker motif on the tab suits the motorsport style. Show milestones only for real steps.
- *Limit:* a 2023 upload; the live game may differ.

**O9. Confirmation** (tutorial-05).
- *Apply:* an 18 px confirmation line in success `#3DBE6C` with a navy outline, under the banner. It celebrates; it never sells. With reduced motion it appears without sliding in.

**O10. Toasts** (Grow a Garden notification).
- *Seen:* a single-line teal gradient bar with white outlined text, past tense, with an emoji at the end.
- *Apply:* one short sentence about something that already happened. Teal for info, green for success, never red. Place under the banner, at most two at a time, newest on top. Use original icons, not emoji (inference: emoji look different on each device).

**O11. Collection silhouettes** (Grow a Garden Garden Guide).
- *Seen:* black "?" silhouettes on coloured tiles, a tab column, a studded header and a red X close button.
- *Apply:* this informs the Index screen, not the HUD. The Index badge shows only when a new car is actually added.

**O12. Tool row and chrome** (Driving Empire stickers, 1920x1080).
- *Seen:* four bottom-centre square buttons of about 150 px (7.8% of width) with grey bevels and a lock overlay. A red Back button sits top right. Cash and Robux "Purchase" buttons are shown at equal weight.
- *Apply:* about 14% of screen height suits a desktop icon button. Translate the bevel into our single glossy highlight. Do not copy the equal-weight Robux layout.

## 4. Qualities preserved from the approved refs
- floating icon plus number
- heavy rounded numerals and strong dark outlines
- saturated colour per element
- chunky tilted overhanging icons and a stud texture
- yellow top-centre banner with a tab and an inline counter
- confirmation under the banner
- ground chevron trails

## 5. New inspirations (proposals; Adam approves)
- checker-motif progress strip (O8)
- word labels under icons (O5)
- category-coloured single-sentence toasts (O10)
- muted earning line (O2)

## 6. Deliberate exclusions
- The red "!" badge is never used for urgency, sales, timers or Shop. It keeps the approved "real new content" rule only, even though the ref shows it on Index.
- No equal-weight Robux prices, no paid boost buttons (the "+10K/+100K/+1M" row in the tutorial refs), no countdowns, restock timers, "limited" or streak messaging.
- No real logos, brands or car names. No copied icons, fonts (the Grow a Garden comic face), characters or distinctive layouts. Fredoka One only.
- No flashing HUD chrome; the 2.5 per second ceiling stays with Heat.

## 7. Implementation implications
- Menu stack, banner, toasts and earning line each need a Figma mock and a spec (decision 0012). New tokens (menu hues, banner yellow, toast teal, strip height) go in `src/shared/UI/Tokens.luau` after approval.
- Verify at 844x390, 390x844, a tablet and 1920x1080 with Device Simulator captures. None of this is tested yet.
- Menu buttons are real input targets. Check that they do not take touches meant for driving.
- Motion (toast, strip fill, confirmation) needs real-time video and a reduced-motion variant.
