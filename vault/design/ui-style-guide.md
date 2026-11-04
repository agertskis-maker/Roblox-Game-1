---
title: Car Hop UI style guide
status: working
date: 2026-11-02
tags:
  - design
  - ui
---

# Car Hop UI style guide

Every Lane 3 screen from Round 3 on follows this. Code lives in `src/client/UI/Prototype/CarKit.luau`, so a screen asks the kit instead of choosing its own numbers. Reference mockups: `Car-Hop-Art/review/round3/chatgpt-images/`.

## The idea
Car Hop's UI is a pit lane: dark navy bezels, chrome edges, checkered flags, number plates, speed lines. Bright things are products and buttons. One hero per screen, then a deliberate size drop.

## Fonts: two, each with a job
| Role | Font | Use | Stroke |
|---|---|---|---|
| Display | **Bangers** (chosen by test against Luckiest Guy, Sarpanch, Oswald, Titillium Italic) | Titles, prices, big numbers, stamps, buttons | Heavy: 1/9 of the text size, miter joins, ink navy |
| Readable | **Fredoka One** (the HUD font Adam approved) | Short descriptions, labels under 18 px | None on plates; light on art |

Bangers slants forward, so it reads as speed and looks like no other Roblox shop's default font. It runs narrow: set it about 1.2 times the size Fredoka would use. Nothing smaller than 14 px on a phone.

## Colour
- **Ink** `#0A0E22` for every outline. **Bezel** navy `#14213F` to `#0D1730`. **Chrome** edge `#DCE6F5` to `#6C7A96`.
- **Price button: always the same green**, `#3CE04A` to `#14A02C`. Nothing else on a screen is that green except Cash amounts.
- **Deals: always red and gold.** Red `#E0202C`, gold `#FFD23C`.
- **One signature colour per product family:**

| Family | Colour | Pattern |
|---|---|---|
| Starter | Orange `#FF8A14` | Speed lines |
| VIP | Gold `#FFC629` on black | Chevrons |
| Double Lap Pay | Royal blue `#1E72FF` | Lap lines |
| Extra Parking | Teal `#10B9A6` | Parking stripes |
| Bundle | Steel `#8BA3C7` | Checker |
| Cash | Money green `#2ACB4F`, deepening to red and gold on the biggest | Rays |
| Paint | Pink `#FF3F9C` | Halftone |
| Decals | Yellow `#FFC629` | Checker |
| Wheels | Violet `#7A4BFF` | Tread |
| Trails | Magenta `#E33FD0` | Speed lines |
| Free | Lime `#8BE02C` | Rays |

Rarity edges: Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold. Always with the word too.

## Cards
Radius 14 at desktop, 10 on a phone. Do not give every card the same size.

| Card | Share | Holds |
|---|---|---|
| Hero | 2/3 of the row (full width on a phone) | One big art in its own box, title, contents, price |
| Side | 1/3 of the row, stacked | Title, art, price |
| Banner | Full width, short | Title left, art centre, deal and price right |
| Pack | 1/5, growing to the right | Amount on top, art, label, price |
| Item | Grid, identical | Name, art in a fixed slot, price |

Art always fits a box inside its card and is still the biggest thing there (Adam, 2026-11-02). Every card: 3 px ink line, 2 px chrome inner edge, one family fill, one pattern at low opacity. Light comes from the top left; shadows fall down and right by 4 px.

## Icon and art slots
Icons never float. Sizes, including padding: 24, 32, 48, 64, 96. An icon image fills its slot; its padding is baked in by the art tool (10 percent), so optical size matches across a row. Rows share a baseline. Product art is authored at 1024 and shown at 512 or less; icons are authored at 512 and shown at 256 or less. Nothing upscales.

Images show a plain rounded placeholder until `IsLoaded`, then fade in over 0.12 s. Never a half-loaded picture.

## Buttons
- **Price:** green, ink line, darker lip under it, number in Display, "Robux" small beside it. Height 48 minimum, 56 for the hero. Hover lifts 2 px with an outline glow, press drops 3 px onto the lip.
- **Secondary:** navy plate, chrome edge, white Display.
- **Retry** orange, **Home** blue, always.
- **Tabs:** dark plates; the active one is yellow with ink text.

## Motifs
Generated, original and tinted per family: checker, speed lines, tread, rays, halftone, chevrons. One motif per card. Number plates for names. Pit boards (a rounded board with bolts) for panels. No sparkles unless something just happened.

## Motion
| What | Timing |
|---|---|
| Open | 0.2 s back-out, scale from 0.94 |
| Colour flow on hero and deals | One cycle in 12 s |
| Pattern drift | 40 px per 10 s |
| Shine sweep | 0.65 s, every 6 to 8 s, hero and deals only |
| Price breathing | 2.4 s, scale 1 to 1.03, primary only |
| Hover / press | 0.11 s / 0.07 s |
| Trail preview | Ribbon sway, pulses, at most 14 pieces |
| Count-up | 0.45 to 0.7 s |

All of it runs from one animator while the screen is open. Reduce Motion: no flow, no drift, no sweep, no breathing; hovers keep colour only.

## Words
Short, punchy, kid-readable. "Earn 2x Cash per lap!" not "Maximize your earnings potential." True statements only.

## AI-look check (score each screen 1 to 5 on "hand-designed and specific to Car Hop"; under 4 gets reworked)
- Same purple-to-pink gradient on everything
- Every card the same size, radius and glow
- Text centred everywhere, no hierarchy
- Sparkles and sheen on every element
- Icons of mixed weight, floating at random
- Small images stretched until blurry
- Too many tags and badges competing
- One default rounded font for every role
- Empty decorative space, marketing filler
