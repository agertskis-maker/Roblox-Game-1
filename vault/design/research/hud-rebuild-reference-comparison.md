---
title: HUD rebuild — reference comparison (visible, inferred, preserved, changed)
tags: [research, ui, lane3, references]
date: 2026-10-22
---
# Reference comparison for the HUD rebuild

Sources: `vault/design/references/hud-ref-03-shop-index-stats-halloween.jpg`,
`hud-ref-04-rainbow-shop-timers.jpg` (Adam's screenshots), the 11 selected dino-study frames and
Adam's analysis (`vault/design/references/dino-study/`), and the older approved references in the
same folder. Measurements: [[hud-ref-arcade-translation]]. Provenance: `vault/design/references/README.md`.
The source games are not identified. Stills prove layout and styling only — not motion, timing,
exact metrics, mobile usability or server behaviour.

## 1. Directly visible (stills)
- **HUD images (both desktop windows with Roblox core UI at top left; analysed as the playable
  viewport below the title bar).** A compact left menu: wide rectangular buttons (Shop, a book
  "Index") about 2.2–2.5:1, corners rounded only slightly (≈ 0.075 × height), a thick dark
  boundary (≈ 4 px at 1080p), a strong colour fill (green, cyan, a rainbow on ref-04) with a stud
  tile texture, an illustrated icon on the left and a large white label with a black outline on
  the right. Small red rectangular "Settings" and "Gear" buttons with outlined labels (ref-04). A
  red circular badge ("!", "6") straddling each button's top-right corner. A switch row "Slow
  Mode" with a green knob. Bottom-left stats with **no backing panels**: illustrated icon + big
  bright number with a thick dark outline (magenta and green on ref-03; orange, cyan and green on
  ref-04), compact suffixes ($10.9T, 533.5M, $682K), a "+" mini badge on a collection icon, and an
  italic white line ("Friend Boost: +10%"). Bottom-right italic white timers with illustrated
  icons. A bottom-centre hotbar. World destination words (big yellow/white letters with a dark
  outline) over shops; flat coloured ground circles with white rings at interaction spots.
- **Dino frames.** A top-centre strip of ten illustrated zone tiles with an avatar head and the
  distance beneath ("99 m" → "2,142 m"), a "BEST" marker inside a tile; a slim full-width zone
  banner ("Forest"); world nameplates over every animal (size tag, NEW, rarity word in colour,
  name, requirement) that pile up unreadably in the distance; a dashed ring around a target; a
  lasso over the rider; two small pie meters beside the rider; an "IT'S YOURS!" side banner with
  the animal's name and "Keep going!"; "0 SECURED" → "1 SECURED" with an icon card at left
  middle; a red "!" + "Not enough stamina" warning near the rider; a large slanted "STOMPED!"
  banner with a reason line ("Stamina 20 / 60 needed"); "GREAT RUN!" back at the base; bunting
  across the valley; dark translucent stat cards bottom left; a round jump button with "Space".

## 2. Inferred (not provable from stills)
- The menu labels and numbers probably use one heavy rounded display face; the timers and the
  boost line an italic or obliqued face (≈ 9.5–12° slant measured).
- The two HUD screenshots use different UI scales (ref-04's buttons ≈ 1.33× ref-03's).
- The dino "0 SECURED" → "1 SECURED" change about a second after "IT'S YOURS!" is a
  **presentation observation**; it does not show how that game confirms captures.
- Tile widths in the dino strip look equal while zone distances probably differ.

## 3. What we preserve (qualities, not assets)
- Wide compact rectangles, limited rounding, thick near-black boundaries, strong fills with a
  controlled gradient and a narrow gloss; big white outlined labels; illustrated icons with a
  little depth and a tilt; red labelled Settings; red earned badges pinned outside the corner.
- Big bright numbers floating on the world, bottom left, no cards; an italic subordinate line.
- Open space around the avatar and road; purposeful asymmetry (left-heavy menu and stats).
- World words that read as destinations; ground circles with a crisp white ring.
- From the dino study (adopted lessons only): readable target information, an open running
  corridor, a non-blocking side capture banner, an understandable failure reason, progress
  landmarks (district strip + zone banner), a claimed-this-run tray.

## 4. What we deliberately change
| Reference trait | Our version | Why |
|---|---|---|
| Stud tile texture on buttons | faint original bolt/tread motif on large buttons only | our art rules forbid studs; never copied tiles |
| Index (book) button | Garage (car-book) and Missions | our real features |
| Gear, Slow Mode, hotbar, right-side squares | none; one real toggle (Music) | no features that do not exist (§5) |
| Timers | off-by-default PREVIEW proposal | no scheduled events or fake urgency for children |
| Magenta/orange stat numbers | cyan car count, green Cash, white italic earning line | Car Hop's colour roles |
| "+" badge as a purchase button | inert, part of the collection symbol | no misleading buy affordance |
| Dino stat cards (dark translucent) | no panels | Adam's new references |
| Dino strip with an end tile | rolling repeating district window | an endless run must not imply an end |
| Distant nameplate piles | priority, cap, overlap suppression, fade at min size | readability |
| Paw/egg buttons, auras, "x4.5 Stamina" paid boost, selling | none | permanent cars; no pay-to-win |
| "Cash stays top left" (study text) | bottom left | Adam's decision 2026-10-22 |
| Halloween labels and the source games' names, art, fonts | none | copying rules |

## 5. Older references kept where compatible
The approved rev-4 CurrencyCounter (heavy rounded green numerals, dark outline, cash-stack art,
gain behaviour) already matches the new grammar and is reused unchanged, only moved; the yellow
tutorial banner with a tab and chevron trails stays, restyled. Where the older references
conflict (Cash top left, gear-only Settings), the new references win.
