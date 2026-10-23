---
title: HUD reference translation - arcade menu, stats and timers
tags: [research, ui, lane3]
date: 2026-10-22
---

# HUD reference translation: arcade menu, stats and timers (2026-10-22)

Research only. It approves nothing. Every token at the end is a **proposal from measurement** for the Lane 3 owner to accept or change.

Sources (both 2880x1704 PNG, viewed downscaled at 2000x1183, factor 1.44):
- **R3** `Car-Hop-Art/references/hud/hud-ref-03-shop-index-stats-halloween.png` (green Shop, cyan Index, italic stats)
- **R4** `Car-Hop-Art/references/hud/hud-ref-04-rainbow-shop-timers.png` (rainbow Shop, Settings/Gear, upright stats, timers)

## Method and uncertainty

- Windows title bar measured at **45 px** (rows 0-44 are flat 239,244,249; row 45 is sky) in both. Playable viewport = **2880 x 1659**. Roblox core UI (top-left) and the window chrome are excluded.
- Conversion: **1080p px = original px x 0.651** (1080 / 1659). "vh" = fraction of viewport height. The viewport is 1.736:1, so horizontal values at 1080p assume equal pixel scale (a 1920x1080 screen is slightly wider).
- Measured with PowerShell + System.Drawing (LockBits): dark/light run scans along rows and columns (dark = luminance < 60), bounding boxes of white or dark pixels, and colour sampling. Crops viewed at 1-2.5x in `%LOCALAPPDATA%\Temp\claude\hudref-crops\`.
- Edges are antialiased: **+-1 to 2 original px** (about +-1 px at 1080p) on every edge. Text "cap" = height of the white/colour glyph fill without the outline. Slant from stem-edge drift across 30-45 rows: **+-2 deg**.
- **D** = directly measured. **I** = inferred (reading of the image, not a pixel measurement).
- The two references use **different HUD scales**: R4's buttons are about 1.33x R3's. Both are reported.

## 1. Left menu buttons

| Item | R3 (orig px) | R4 (orig px) | vh | 1080p | Src |
|---|---|---|---|---|---|
| Wide button (Shop/Index) W x H | 305 x 122 | 362 x 162 | 0.074 / 0.098 | 199x79 / 236x105 | D |
| W/H ratio | 2.50 | 2.23 | | | D |
| Small button (Settings, Gear) W x H | n/a | 172 x 82 (ratio 2.1) | 0.049 | 112x53 | D |
| Toggle (Slow Mode) W x H | 194 x 80 | 256 x 110 | 0.048 / 0.066 | 126x52 / 167x72 | D |
| Outer corner radius | 9 (0.074 H) | 13 (0.080 H); small 4 (0.05 H) | | 6 / 8.5; small 2.6 | D (row-by-row edge drift) |
| Dark border | 6 | 6-7; small 6 | 0.004 | 3.9-4.6 | D |
| Border colour | darker shade of fill hue: green 11,72,0; indigo 26,0,72 | pure black 0,0,0; small 12,20,26 | | | D |
| Label cap (white fill) | 36 (0.30 H) | 57 (0.35 H); small G 21 (0.26 H) | 0.022 / 0.034 | 23 / 37; small 14 | D |
| Label outline | 5-6 (0.16 cap), 6,6,6 | 6 (0.11 cap), 0,0,0 | | 3.6-3.9 | D |
| Icon size | white glyph 60x50 (0.41 H) | 145x120 (0.74 H) | | 39x33 / 94x78 | D (R4 from 2x crop, +-4) |
| Icon overhang | none; sits inside, ~20 px from border | none past outer edge; touches inner border (0-3 px) | | 0 | D |
| Gaps (vertical) | Shop-Index 14, Index-toggle 18 | Settings-Shop 15, Shop-Index 11, Index-toggle 9 | | 9 / 12; 10 / 7 / 6 | D |
| Gap Settings-Gear (horizontal) | n/a | 4 | | 2.6 | D |
| Left margin | 27 | 24 | | 18 / 16 | D |
| Stack span (vh) | 0.394 - 0.608 (centre 0.50) | 0.328 - 0.659 (centre 0.49) | | | D |

Layout inside the wide button (D): icon left, label right of it; R4 label right padding ~17 px (0.10 H), label vertically centred.

Fill treatments:
- **R3 vertical gradient** (D): Shop R channel 107 -> 60 top to bottom (yellow-green to green); Index G 224 -> 195 (about 13% darker at the bottom). A 1-3 px light inner rim line just inside the border at top and bottom (190,255,180 on green). **No hard gloss band.**
- **R4 wide buttons** (D): flat fill (magenta column constant 255,0,242 top to bottom). No gloss band.
- **R4 small red buttons** (D): vertical gradient ~20% darker toward the bottom (249,63,93 -> 212,7,38), a white-to-fill inner bevel ~5 px on the top and left edges, a light inner line at the bottom, faint 2x2 checker cells (~24 px). Reads as the "gloss" (I).
- **Stud tile pattern** (D): R3 = very low contrast, about +-3-8% luminance (fill 67,255,1; highlight 84,255,23; shadow 60,230,0), pitch ~40 px both ways (0.33 H), about 3 rows x 7 columns. R4 = high contrast: stud edge 31,143,153 vs fill 51,238,255 (edge ~60% of fill luminance), pitch ~44 x 37 (0.25 H), 4 rows x 8 columns. **Our replacement tread/bolt motif should match R3's contrast (<= 8% luminance) at ~0.3 H pitch.**
- **Rainbow Shop** (D): order left to right red-orange 253,81,5 -> orange -> yellow 254,255,0 -> yellow-green -> green 89,255,0 -> teal -> cyan 4,184,255 -> blue -> violet -> magenta 255,0,242. Fully saturated stops. The same colour sits ~96 px further left on the bottom row than on the top row over 141 px of height, so iso-colour lines lean "/" about **34 deg** from vertical; gradient axis about 34 deg clockwise from horizontal (UIGradient Rotation ~ +34 is I; sign to confirm in Studio). Magenta is flat over the right ~30-45%.

## 2. Badges (red "!" and "6")

| Item | R3 | R4 | Src |
|---|---|---|---|
| Outer diameter (with outline) | 57 px = 0.47 H (37 at 1080p) | 70 px = 0.43 H (46 at 1080p) | D |
| Outline | 3 px dark maroon 56,0,14 | 4 px black | D |
| Fill / glyph | pure red 255,0,0; white glyph, thin dark outline | 254,0,4; white "!" | D |
| Centre vs button top-right corner | 11 px left, 18 px down (0.09 H, 0.15 H) | 7.5 left, 29.5 down (0.05 H, 0.18 H) | D |
| Overhang | 14 px past right edge, 7 px above top | 25 px past right edge, 4 px above top | D |

Rule of thumb (I): diameter ~0.45 H, centre on the right edge minus ~0.07 H, top edge plus ~0.16 H.

## 3. Bottom-left stats

| Item | R3 (italic) | R4 (upright) | 1080p | Src |
|---|---|---|---|---|
| Number cap (fill) | 54-55 (0.033 vh) | 66-70 (0.041 vh) | 35-36 / 43-46 | D |
| Number outline | 6-7 px black (0.12 cap) | 5-6 px black (0.085 cap) | 3.6-4.6 | D |
| Number colour | flat: magenta 255,30,240; green 20,255,0 | gradients: Cash green 0,255,60 -> mint 172,255,192 left to right; orange 255,162,47 -> 255,180,87 top to bottom and lighter right; cyan nearly flat 0,242,255 | | D |
| Icon size | 115-125 x 88-109 | 102-116 x 111-117 | ~72-76 | D (dark-outline bbox, +-5) |
| Icon / number cap | ~1.9 | ~1.6 | | D |
| Row pitch (outer top to outer top) | 107 | 114-126 | 70 / 74-82 | D |
| Icons vertical gap | n/a | ~5 px, icons nearly touch | 3 | D |
| Left margin (icon) | 19-25 | 21-28 | 13-18 | D |
| Number start x | 153 | 156-166 | 100-108 | D |
| Bottom margin | 42 below Friend Boost | 17 below cash icon, 35 below number | 27 / 11-23 | D |
| "+" mini badge | 66x67, yellow 240,193,1, 3 px dark brown 72,24,0, white "+" with ~15 px black outline | 65x61, light blue with studs, 5 px near-black, white "+" | 43 / 41 | D |
| "+" badge placement | overlaps icon bottom-right, ~0.5 of icon size, ~0.9 of number cap | same | | D |
| Friend Boost line | cap 46 (0.85 of number cap), 3 px black outline, white | n/a | 30, outline 2 | D |
| Slant | numbers ~11 deg; Friend Boost ~12 deg | upright | | D (stem drift) |
| K / M / T suffix | same size, colour and outline as digits; decimal kept (533.5M, 10.9T); "$" prefix same size | "$682K", same styling | | D |

## 4. Timer stack bottom-right

- R4 "Race in 3m 25s" / "Pumpkins in 0m 49s" (D): white fill, thin black outline 3-4 px (0.07 cap), cap 46-48 px (0.028 vh, **30 at 1080p**), italic slant **~9.5 deg** (R stem drifts 5 px over 30 rows). Icon (flag) 130x118 = ~2.5x cap (85x77 at 1080p), left of text. Row pitch 160 (104 at 1080p). Right margin 38 (25 at 1080p). Flag bottom 41 px above viewport bottom (27 at 1080p).
- R3 "in 1m 19s" (D): same style, cap ~46-49, right margin ~52, bottom 27 px; moon icon ~100x70 (I from view).
- Right-aligned text, icon on the left of each row (D).

## 5. World labels and ground circles

| Label | Fill | Outline (px / of cap) | Outline colour | Shadow / extrusion | Src |
|---|---|---|---|---|---|
| TRAILS SHOP (R4, near) | horizontal gradient yellow 234,189,0 -> orange 250,94,0 mid -> yellow 238,210,0; no vertical gradient | 7 / cap 93 = 0.075 | near-black navy 2,16,27 | none observed | D |
| SELL (R4, mid) | flat red 232,2,37 | 5-6 / cap ~70 = 0.08 | dark navy-violet 18,20,64 | none observed | D (blurred by distance) |
| HALLOWEEN EGG (R3, far) | flat yellow 209,192,9 | 2 / cap 26 = 0.08 | dark brown 69,21,0 | none observed | D |

World-label outline is thinner relative to cap (~0.075-0.08) than HUD numbers (0.09-0.12).

Ground circles (R4 yellow pad, D): centre fill saturated yellow 255,219-228,38-40 with faint tile texture; white ring ~34 px on a horizontal radius of ~360 px = **ring ~0.09 R**; ring is **dashed** (short gaps between ~10-12 segments, I from crop); soft pale inner transition ~25 px and soft outer glow ~18 px. Magenta pad: same build, thinner ring (I). R3 yellow pad has no white ring: bright yellow glowing rim with a translucent pale centre (I).

## 6. Outline summary

| Element | 1080p stroke | of cap | Colour |
|---|---|---|---|
| Button labels | 3.6-3.9 | 0.11-0.16 | black / 6,6,6 |
| Button border | 3.9-4.6 | 0.04 H | black (R4) or dark shade of fill (R3) |
| Stat numbers | 3.6-4.6 | 0.085-0.12 | black |
| Timers, Friend Boost | 2-2.6 | 0.065-0.07 | black |
| World labels | n/a (3D) | 0.075-0.08 | near-black navy or dark brown |

Our existing `Tokens.Color.Stroke` (30,42,74) and `CashOutline` (20,27,51) already sit in the near-black navy range (I).

## 7. Typography (we do not copy their fonts)

- R3 labels and numbers (I): very heavy rounded display face, round terminals, geometric bowls, open counters, short ascenders. R4 labels/numbers (I): heavy grotesque, less rounded, flat terminals, tall x-height, open "a"/"e". Timers (I): an italic of the R4 family.
- **Fredoka One** (approved): button labels, world labels, upright stat numbers (Cash, car count), badge glyphs. Closest to R3's rounded heavy look. It has no italic, and Roblox text cannot be skewed (I).
- **Nunito Black Italic** (verified in Roblox's families, not yet approved): candidate for timers, the earning/boost line and any italic number style. Its ~10-12 deg italic matches the measured 9.5-12 deg slant (I).
- Fredoka One cap height assumed ~0.7 x TextSize (I, unverified; check in Studio before locking sizes).

## 8. Composition

- Occupied (D): left column x 0-0.16 of width (menu stack centred at ~0.50 vh; stats from ~0.78 vh to the bottom); bottom-right timers (x 0.78-0.99, y 0.81-0.98 vh); bottom-centre hotbar; top-left core UI; top-centre transient toast; R3 also has two small square buttons on the right edge at 0.43-0.60 vh.
- Empty (D): centre ~60% of width from ~0.1 to ~0.8 vh. Avatar sits at ~0.45 width, 0.45-0.78 vh, framed by nothing.
- Asymmetry (I): heavy left (two clusters: menu mid-left, stats bottom-left), light right (timers only), no top HUD. The road/avatar lane is kept open by pushing everything to the left 16% and the bottom 20%.

## Proposed Car Hop arcade tokens (proposal from measurement)

Scale rule: design px x scale, scale = short side / 390 clamped 1.0-1.5; 1080p = 1.5x. All rows are **proposal from measurement**; values marked * are raised to meet the approved touch targets or sizes.

| Token | 1080p px | Design px (1.0) | Basis |
|---|---|---|---|
| Wide menu button W x H | 225 x 90 | 150 x 60 | between R3 79 and R4 105 high; ratio 2.5 (R3); 60 >= 56 primary |
| Small Settings button W x H | 108 x 72* | 72 x 48* | R4 is 112x53 (35 design px), below the 48 minimum |
| Corner radius (wide / small) | 7.5 / 4.5 | 5 / 3 | 0.075 H / 0.05 H |
| Outer dark border | 4.5 | 3 | 0.04 H |
| Label text size (Fredoka One) | 36 | 24 | approved "value" size; cap ~0.28 H (ref 0.30-0.35 H) |
| Label text outline | 4 | 2.5 | 0.11-0.16 cap |
| Menu icon size | 63 | 42 | 0.7 H (R4 0.74 H) |
| Badge diameter / outline | 39 / 3 | 26 / 2 | 0.45 H; centre at right edge -0.07 H, top +0.16 H |
| Stat number size, Cash (Fredoka One) | 54 | 36 | approved display size; cap ~25 design (between R3 and R4) |
| Car-count size | 54 | 36 | refs use equal rows; 24 if a hierarchy is wanted |
| Stat number outline | 4.5 | 3 | 0.085-0.12 cap |
| Stat icon size | 72 | 48 | ~1.6-1.9 x number cap |
| "+" mini badge | 36 | 24 | 0.5 of icon, overlapping its bottom-right |
| Earning / boost line (italic candidate) | 36 | 24 | 0.85 of number cap in R3; approved 24 |
| Timer text (italic candidate) / icon | 36 / 66 | 24 / 44 | cap 30 at 1080p; icon ~2x cap |
| Stat row pitch / gap | 78 / 6 | 52 / 4 | icons nearly touch in R4 |
| Menu stack gap | 9 | 6 | refs 6-12 at 1080p |
| Left / bottom / right margin | 18 / 18 / 24 | 12 / 12 / 16 | refs 16-18 / 11-27 / 25-34, plus safe-area inset |
| Menu stack position | centre 0.50 vh | | refs 0.49-0.50 |

## Do not copy

- Stud tile pattern on buttons (replace with an original low-contrast tire-tread/bolt motif).
- Their icons and art: cart, basket, book, shoe, candy corn, cash stack, car, flag, pumpkin, moon, egg, paw.
- Halloween or event labels and pads ("HALLOWEEN EGG", "TRAILS SHOP", "SELL", "FUSE MACHINE", "SPIN WHEEL") and their names.
- The hotbar (Roblox backpack) and right-edge egg/paw buttons.
- The exact composition and spacing as a whole screen; take proportions, not the layout one to one.
- Slow Mode toggle and Gear button features (we have not designed these).
- Their fonts.

## Qualities to preserve

- Wide, chunky buttons (~2.2-2.5:1) with a thick dark border and small corner radius (~0.075 H).
- Big icon on the left, heavy white label with a black outline on the right.
- Saturated flat or gently vertical-graded fills; texture contrast kept very low.
- Red notification badge (~0.45 H) straddling the top-right corner.
- Stats as icon + oversized outlined number, rows stacked tightly, suffixes styled like digits.
- Italic white timers with thin outlines and a large icon, right-aligned bottom-right.
- World labels: saturated fill, thin near-black navy outline (~0.08 cap), no extrusion.
- Ground pads: saturated centre, white ring ~0.09 R, soft edge.
- Left-heavy, centre-empty composition that keeps the car and road clear.
