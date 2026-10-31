---
title: Plot race-track signs
tags: [design, ui]
status: draft
---

# Plot race-track signs

- Figma: "Car Hop UI", https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3, page "Island signs", section 4 (heading `7:139`).
- Frames (world-space signs at 100 px per stud):

| Frame | Node id |
|---|---|
| Track banner – Zoopa Fizz (soda, fictional) (component) | `7:140` |
| Track banner – Crunchkin Puffs (snack, fictional) (component) | `7:159` |
| Track banner – Stickytoe Tyres (tyres, fictional) (component) | `7:177` |
| Track banner – Wobblebot Toys (toys, fictional) (component) | `7:202` |
| Owner banner – background (export, no text) (component) | `7:237` |
| Owner banner – with live text placeholder | `7:351` |
| Plot nameplate – background (export, no text) (component) | `7:339` |
| Plot nameplate – with live text placeholder | `7:456` |
| Kiosk sign – background (export, no text) – 5.0 x 0.9 studs (component) | `7:348` |
| Kiosk sign – with live text placeholder | `7:468` |
| Track wall – one straight, banners at 40 px per stud (context) | `7:475` |
| Note (live text, brand check) | `7:474` |
| Export sheet (shared with [[island-signs]]) | `9:410` |

- Approval: pending. **Adam reviews these at the final review (Task 3), not mid-task.**
- Hand edits in Figma since the spec was written: none.
- Figma reads used for this screen: shared with [[island-signs]] (two Export sheet screenshots on 2026-10-22, logged in [[figma-reads]]).

## Purpose
Make each player's plot look like their own little speedway: fun fictional sponsor banners on the low track wall, an owner banner, a nameplate at the entrance and a label on the upgrade kiosk. All are world props: nothing to press, no prices, no purchase prompts. The kiosk sign only names the kiosk; what the kiosk does is out of scope.

## Where the signs go
| Sign | Kit part (from `src/island/Hub/Recipes/Plot.luau`) | Size (studs) | Canvas |
|---|---|---|---|
| Track banners | `Banner`, 0.1 × 1.6 × 10 on the barrier's outer face, 4 per straight, 8 per plot (now plain Coral / Mint / Yellow) | 10 × 1.6 | 1000 × 160 px |
| Owner banner | one of the 8 `Banner` parts per straight (proposal: the one nearest the Paddock) | 10 × 1.6 | 1000 × 160 px |
| Plot nameplate | `Nameplate`, 10 × 2.5 × 0.4 on the gate arch (now blank cream) | 10 × 2.5 | 1000 × 250 px |
| Kiosk sign panel | the blank cream panel on the roof front of `KioskBooth` in `assets/island/kit/kit_plot.py` (5.0 × 0.9 face on a 5.4 × 1.2 coral backing, centre 5.35 studs up). That file appeared during this pass (another session's uncommitted work), so the mock was first drawn at the brief's 3.0 × 1.0 default and then resized | 5.0 × 0.9 | 500 × 90 px |

Each image goes on as a Decal (or a SurfaceGui ImageLabel, PixelsPerStud 100) on the outward face. Live text is a SurfaceGui TextLabel above the image on the same face.

## Content
Brands are invented for this game (kid-friendly, no real brands, logos or characters). They were **not trademark-searched**; check each name before any upload.

| Banner | Background | Left art | Right art | Brand text |
|---|---|---|---|---|
| Zoopa Fizz (soda) | `#3FB6D8` with white bubbles | red bottle, gold cap, cream label with a star | gold star burst | "ZOOPA FIZZ!" Fredoka One 84, cream, 6 px `#3B2A1E` outline |
| Crunchkin Puffs (snack) | `#7B4BD6` with gold stars | orange snack bag with a smiling puff | three puffs | "CRUNCHKIN PUFFS" Fredoka One 66, `#FFC83D`, 6 px `#3B2A1E` outline |
| Stickytoe Tyres (tyres) | `#2E3440` charcoal | tyre with treads and hub | three yellow hazard stripes | "STICKYTOE TYRES" Fredoka One 66, white, 6 px `#141B33` outline |
| Wobblebot Toys (toys) | `#FF8A1F` with cream dots | smiling blue robot head with an antenna | three toy blocks | "WOBBLEBOT TOYS" Fredoka One 68, cream, 6 px `#3B2A1E` outline |

The brand text is part of the banner image (static art). Every brand banner has an 8 px dark rim and a 3 px pinstripe 14 px in (cream, or gold on the tyre banner). "TYRES" follows the brief's spelling; "TIRES" is the US alternative (reversible).

## States
None of these signs has states. Live text only changes when the plot's owner changes.

| Case | Owner banner and nameplate | Kiosk |
|---|---|---|
| Owner present | owner's display name | "UPGRADES" |
| Plot unclaimed | text hidden; plain background (proposal) | "UPGRADES" hidden or shown (open question) |
| Long name (20 characters) | TextScaled down to the minimum size below; then TextTruncate AtEnd | n/a |

## Layout and live text
Live text rects, in design px on each canvas (origin top left). The exported backgrounds contain no text.

| Sign | Text (placeholder) | Rect x, y, w × h | Font and size | Colours | Alignment |
|---|---|---|---|---|---|
| Owner banner (1000 × 160) | "<PLAYER>'S SPEEDWAY" (uppercase display name + "'S SPEEDWAY") | 180, 24, 640 × 112 | Fredoka One 54 (TextScaled, max 54, min 28); placeholder measures 626 × 65 | cream `#FFF6E0`, UIStroke 5 px `#141B33` | centred both ways |
| Plot nameplate (1000 × 250) | "<PLAYER>'S PLOT" | 70, 44, 860 × 162 | Fredoka One 88 (TextScaled, max 88, min 40); placeholder measures 771 × 106 | dark brown `#3B2A1E`, no outline, on the cream panel | centred both ways |
| Kiosk sign (500 × 90) | "UPGRADES" | 92, 13, 316 × 64 | Fredoka One 40 (TextScaled, max 40, min 24); measures 216 × 48 | cream `#FFF6E0`, UIStroke 3 px `#3B2A1E` | centred both ways |

A 20-character name needs about 34 px on the owner banner and about 54 px on the nameplate, both above the minimums. Names are the player's Roblox display name, run through Roblox text filtering as the build requires (Lane 3 build detail).

Background art:

| Image | Layout |
|---|---|
| Owner banner background | navy `#1E2A4A`; chequered blocks 120 × 160 at each end (20 px squares, white and `#141B33`); gold `#FFC83D` bars 8 px wide at x 120 and x 872; gold stars (32 px) at x 140 and x 828; 8 px `#141B33` rim |
| Nameplate background | plank `#B08456` (decided colour), 8 px `#3B2A1E` rim, two grain lines `#9A7048`, cream `#FFF6E0` name panel at 36, 30, 928 × 190 (radius 22, 5 px `#3B2A1E` stroke), four bolts `#7A5638` (16 px) in the corners |
| Kiosk background | `#3FB6D8` (`Tokens.Color.Calm`), 5 px `#3B2A1E` rim, `icon-wrench.png` 70 × 70 at 10, 10 and at 420, 10 |

Track wall order (frame `7:475`, a proposal): owner banner on each straight nearest the Paddock, the four brands filling the other slots.

## Tokens used
From `src/shared/UI/Tokens.luau`: `Color.Calm` `#3FB6D8`, `Color.Primary` `#FF8A1F`, `Color.Coin` `#FFC83D`, `Color.Danger` `#E5484D` (bottle, block; decorative use on a world banner), `Color.Success` `#3DBE6C` (block), `Color.Text` `#1E2A4A` (owner banner navy), `Color.CashOutline` `#141B33`, `Color.Chrome` `#D6DEE8`, `Color.ChromeShade` `#8C98AA`, `FontFamily` Fredoka One. Proposals, not yet tokens: cream `#FFF6E0`, outline brown `#3B2A1E`, plank `#B08456`, grain `#9A7048`, purple `#7B4BD6`, charcoal `#2E3440`, and the world-sign text sizes 88 / 84 / 68 / 66 / 54 / 34.

## Buttons
None.

## Motion
None (the banners do not wave; the base flag line elsewhere is unchanged).

## Assets
Exported from the Export sheet `9:410` at 100 px per stud; files in the Task 3 scratchpad `task3fig\export\`. None is uploaded or listed in `vault/design/assets.md` yet; upload only with Adam's approval. Asset IDs are never invented.

| Image | Drawn in Figma (node) | Exported file | Size | Sheet x, y | Upload approved | Asset ID |
|---|---|---|---|---|---|---|
| Zoopa Fizz banner | `7:140` | `banner-zoopa-fizz.png` | 1000 × 160 | 20, 200 | no | none |
| Crunchkin Puffs banner | `7:159` | `banner-crunchkin-puffs.png` | 1000 × 160 | 20, 380 | no | none |
| Stickytoe Tyres banner | `7:177` | `banner-stickytoe-tyres.png` | 1000 × 160 | 20, 560 | no | none |
| Wobblebot Toys banner | `7:202` | `banner-wobblebot-toys.png` (see note) | 1000 × 160 | 20, 740 | no | none |
| Owner banner background | `7:237` | `owner-banner-bg.png` | 1000 × 160 | 20, 920 | no | none |
| Nameplate background | `7:339` | `nameplate-bg.png` | 1000 × 250 | 20, 1100 | no | none |
| Kiosk background | `7:348` | `kiosk-bg.png` (see note) | 500 × 90 | 20, 1370 | no | none |

Note on the Wobblebot PNG: the final Export sheet read caught the banner with its rim and pinstripe 10 px too low (a slip in the fix script, corrected in Figma afterwards). With no reads left, the PNG was rebuilt locally from the two reads: the frame rows come from the first read and the robot and text rows from the second, and the top of the antenna ball is mirrored from its lower half. It matches the corrected Figma layers to within one antialiased pixel row on the ball. Re-export it from Figma when a read is available before uploading.

Note on the kiosk PNG: it was resized to the kit panel after the last read, so `kiosk-bg.png` was drawn locally by `task3figkiosk.js` from the Figma layer values (fill, rim, the same wrench PNG area-averaged to 70 × 70). Re-export it from Figma before uploading too.

Nameplate and kit: `kit_plot.py` (in progress) gives the nameplate board 10 × 2.5 with a 0.2-stud coral frame, so its printable face is 9.6 × 2.1 studs. This spec keeps the brief's full 10 × 2.5 face (1000 × 250 px, with its own plank rim). If the kit frame stays, use the cream panel only: canvas 960 × 210, live text rect 40, 25, 880 × 160, same font and colours, and no background image (the kit face is already cream).

## Open questions
1. Approve the four brand banners and their invented names (to be trademark-checked before upload).
2. Owner banner placement and count, and what an unclaimed plot shows.
3. Kiosk sign panel 5.0 × 0.9 studs (from the kit) and whether "UPGRADES" is the right word for the kiosk (its function is outside this spec).
4. "TYRES" or "TIRES".
