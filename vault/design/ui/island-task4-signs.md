---
title: Island Task 4 signs (one batch for Adam)
tags: [design, ui]
status: draft
---

# Island Task 4 signs

**Status: pending Adam's approval.** Nothing in this batch is approved, built or uploaded. Ledger [[island-rework]] IRW-134 (brief §3), with IRW-144, IRW-147 to IRW-152. New Lane 3 UI per [[0012-figma-ui-workflow]]. Adam's Task 4 brief does not grant the overnight task's separate Figma exception, so no Figma reads were used.

- **Figma:** "Car Hop UI", page **"Task 4 island signs (pending Adam)"** (`14:747`): https://www.figma.com/design/b6z7jCt39PfBVHRrWOC2V3?node-id=14-747. Drawn 2026-10-22. The frames were imported from the local review page with `html_to_figma`, so they are flat editable layers (vectors, text and texture images). They do not use Figma variables or components. **They have not been seen in Figma:** a screenshot is a read, so nobody has looked at the imported frames yet. Adam checks them by opening the link.

| Frame | Node id |
|---|---|
| PENDING — not approved (label) | `14:748` |
| 1. Portal gate crests | `15:2` |
| 2. Locked-gate plaques | `16:2` |
| 3. Leaderboard pair | `17:2` |
| 4. Plot gate nameplate beam | `18:2` |
| 5. Stunt entrance boards | `19:2` |
| 6. Garage sign, rings, prompt | `20:2` |
| 7. Snack stand header placement | `21:2` |

- **Local review page (the source of the Figma frames):** `C:\Users\agert\Documents\Car-Hop-Art\review\task4\signs\index.html` (a self-contained copy, `index-inline.html`, is what was imported). Section renders: `renders\s1.png` to `renders\s7.png`, plus `renders\00-full-page.png`.
- **Final-candidate textures:** `C:\Users\agert\Documents\Car-Hop-Art\review\task4\signs\textures\` (list under "Assets"). None is uploaded, in `vault/design/assets.md` or in `AssetIds.luau`. Generators: `art.js`, `textures.js` and `review.js` in the session scratchpad `task4signs\`, outside the repo.
- Figma calls this pass: `create_session`, `use_figma` (create the page and label; rename and arrange the frames), and `html_to_figma` (import). All are writes; the read count stays at 4 of 6 ([[figma-reads]]). `whoami` was **not** called, because [[0012-figma-ui-workflow]] counts it as a read.
- Hand edits in Figma since the spec was written: none.

## Rules for every sign in this batch
- **World props.** Nothing is pressable except the Garage ProximityPrompt (§6). No prices, no purchase wording, no Robux, no paid luck.
- **PREVIEW** marks every made-up value: a white tag with a dashed magenta stroke and magenta Fredoka One text (in Roblox a solid 2 px UIStroke, since UIStroke has no dashes). Same style as [[portal-sign]]. The tag disappears only when the value comes from the server through an approved contract. None of the numbers here are economy values. Do not copy them into code or data as real values.
- **Original art only.** No logos, brands, real names or usernames. Emblems are generic shapes (towers and a star, a sun over a mesa and a road, two peaks and a snowflake). Placeholder player names are invented and contain spaces, which Roblox usernames cannot. They were **not** checked against Roblox display names or trademarks.
- **Fonts.** Fredoka One for all game text (approved). The screen ramp (36 / 24 / 18 / 16) does not apply to world-space text. World text is specified by **capital height in studs**. Measured in Fredoka One: capital height = 0.75 × font size. For SurfaceGui text, TextSize in px = (capital height in studs / 0.75) × PixelsPerStud.
- **Read distance.** Two figures per sign, both from the Task 4 research (vertical FOV 70):
  - "Limit" uses 12 px capitals on a 720 px tall render: capital ≥ 0.0233 × D ([[task4-portal-gates]]).
  - "Comfortable" uses 12 pt on a 380 pt phone landscape: capital ≥ 0.044 × D ([[task4-garage-racing]]).
  - Neither has been checked in Studio. The review page shows each key sign at true pixel size for its target distance.
- **Textures.** 1024 px or less on the long side, because Roblox downsizes larger uploads. Power-of-two sizes. Texel density is given per sign. Text that changes (names, values, states) is **live** SurfaceGui text over the texture, never baked.

## Colours
Existing tokens (`src/shared/UI/Tokens.luau`): `Color.Text` `#1E2A4A` (navy), `Color.CashOutline` `#141B33` (ink outline), `Color.Coin` `#FFC83D`, `Color.Success` `#3DBE6C`, `Color.Primary` `#FF8A1F`, `Color.Danger` `#E5484D`, `Color.Calm` `#3FB6D8`, `Color.Chrome` `#D6DEE8`, `Color.BillBandShade` `#E07B12`. World swatches (`src/island/WorldPalette.luau`): `PortalDowntown` `#BA5CFF`, `PortalDustyHighway` `#FF963C`, `PortalSummitPass` `#6ED2FF`, `Yellow` `#F7CE58`. Decided: plank `#B08456`.

**Proposals (not tokens yet; added to Tokens only after approval):**

| Colour | Use |
|---|---|
| cream `#FFF6E0` | sign text and light faces |
| outline brown `#3B2A1E` | outlines |
| PREVIEW magenta `#C2187A` | PREVIEW tags |
| bar track `#5A4030`, grain `#9A7048`, post `#7A5638` | plaque details (from [[portal-sign]]) |
| deco gold `#F2C14E` / `#8A5F12` / `#FFE9A8` | Downtown |
| sandstone `#C8643F` / `#E39A6B` / `#9A4530`, side face `#7A2E1E` | Dusty Highway |
| pale stone `#E6EEF3` / joints `#C3D2DE`, alpine blue `#24477A`, ice side `#5FA9CF` | Summit Pass |
| garage red-orange `#E8562A`, side face `#8C2A14` | Garage sign |
| row stripe `#24335A` | leaderboard rows |
| bronze `#D98A4A` | third-place medal |
| plot accents `#F7C531` (yellow), `#3F8FE0` (blue), `#8E5BE8` (purple) | plot gates |
| Garage badge red `#D9503F` | from [[island-signs]] |

## 1. Portal gate crests (IRW-147)
**Purpose:** name each World on its gate so a player can tell the three portals apart from the plaza and the plot entrances. The emblem carries the identity farther than the letters.

**Gate template assumed for the mock (proposal, not from the layout data):** two columns 6 wide and 33 tall either side of the 20 × 30 field, which floats 2.8 above the pad. The gate is 32 wide overall. The kit modeller sets the real gate size; the crest scales with it.

| Part | Size (studs) | Where | Texture | Texel density |
|---|---|---|---|---|
| Crest name panel | 32 × 16, from 33 to 49 above the pad | front face of the crest mesh (Decal, or SurfaceGui ImageLabel); the back face gets the same texture if the gate is seen from behind | `crest-name-<world>.png` 1024 × 512 | 32 px per stud |
| Emblem medallion | 9 across, centred 2.5 above the panel top (its lower 2 studs overlap the panel) | separate disc part in front of the panel | `crest-emblem-<world>.png` 512 × 512, transparent outside the circle | 57 px per stud |

| World | Panel | Letters | Capital height | Limit / comfortable |
|---|---|---|---|---|
| Downtown (gold art deco) | navy `#1E2A4A` with a faint sunburst, gold frame and stepped corners, a gold rule with a chevron under the name | DOWNTOWN, one line, gold `#F2C14E`, side face `#8A5F12`, 8 px ink outline | **3.3** (8 letters must fit 29.5 studs) | 142 / 75 |
| Dusty Highway (red sandstone) | three sandstone strata with cream joint lines, soft weathering pits, rounded 12 px brown edge | DUSTY / HIGHWAY, two lines, cream, side face `#7A2E1E`, 10 px brown outline | **4.6** | 197 / 105 |
| Summit Pass (pale alpine, ice) | pale stone blocks, ice rim along the bottom, small ice spikes in the corners. Snow caps and icicles are mesh, not texture | SUMMIT / PASS, two lines, alpine blue `#24477A`, ice side face `#5FA9CF`, ink outline | **4.6** | 197 / 105 |

- **Emblems:** Downtown: three stepped gold towers under a cream star, on navy with a violet ring. Dusty Highway: a cream sun setting over red mesas, with a road and a yellow centre line. Summit Pass: two snowy peaks and a white snowflake on pale sky. At 270 studs a 9-stud emblem is about 17 px tall on a 720 px render.
- **States:** the crest texture is the same locked and open. The state lives on the gate: inlay strips (0.6 wide, two per column, mesh parts) dark `#3A3F5C` but visible when locked, lit in the World colour when open; the field dimmed when locked and brightest when open; chains and padlock (§2). Downtown is always open.
- **Font check (research open check 1):** measured in this pass. HIGHWAY at 4.6 capitals is 28.7 studs wide, inside the 29.5-stud text zone; SUMMIT is 24.8. DOWNTOWN cannot reach 4.6 on one line inside a 32-stud crest (it would be 39 studs wide).

## 2. Locked-gate plaques (IRW-148)
### 2a. LOCKED plaque
| Item | Value |
|---|---|
| Purpose | a friendly, readable "this gate is closed for now" under the padlock |
| Size | 16 × 4 studs, inside the field below the padlock, centre about 10 above the pad (in the mock) |
| Texture | `plaque-locked.png` 1024 × 256 (64 px per stud), front face |
| Art | rounded cream plaque (radius 56 px), 16 px brown edge, plank inner line, two plank rivets. LOCKED in navy `#1E2A4A`, **capitals 2.5** (research minimum), 13.4 studs wide |
| Read distance | limit 107, comfortable 57 |
| States | shown only while locked; removed with the chains on unlock (the unlock animation is IRW-148, not this spec). Not used on Downtown |

Friendliness comes from shape and colour (cream, rounded, no red, no warning stripes). The first draft had a second line ("Not yet! See the plaque below"), but it does not fit at 2.5 capitals on a 4-stud plaque, so it was dropped (reversible).

### 2b. Requirement plaque on a short pedestal
| Item | Value |
|---|---|
| Purpose | say what is still needed to open the World, read up close |
| Placement | on a 3-stud post about 4 studs in front of the gate and to one side of the walk line (in the mock: left). The face is 8 × 4 studs, tilted 30° back toward the walkway, top edge about 5 above the ground. Avatar eye 4.5 |
| Background texture | `plaque-requirement-bg-dusty-highway.png` / `-summit-pass.png` 1024 × 512 (128 px per stud): plank, brown rim, grain, and a World-colour title strip (Dusty `#FF963C`, Summit `#6ED2FF`) with the baked title "TO OPEN DUSTY HIGHWAY" / "TO OPEN SUMMIT PASS" (Fredoka One, cream, brown outline) |
| Live layer | SurfaceGui, front face, PixelsPerStud 100, canvas 800 × 400, transparent |

Live layout, in design px:

| Element | Position and size | Value |
|---|---|---|
| State pill | x 652, y 20, 128 × 40, radius 20 | LOCKED: fill brown, text Fredoka One 24 cream. READY!: fill `Color.Success`, 3 px brown stroke, text 26 cream with a 3 px brown outline |
| Row 1 (Cash) / Row 2 (previous-World cars) | rows start at y 92 / y 196 | |
| Row icon | x 14, row y + 10, 72 × 72 | `icon-coin.png` / `icon-garage.png` (existing) |
| Row label | x 100, baseline row y + 30 | Fredoka One 28, cream, 3 px brown UIStroke. "CASH"; "DOWNTOWN CARS" (Dusty) or "DUSTY HIGHWAY CARS" (Summit) |
| Numbers | right edge x 700, same baseline | Fredoka One 28, cream, brown stroke. Shown as "PREVIEW 1,200 / 5,000" and "PREVIEW 2 / 3" |
| PREVIEW tag | right edge 8 px left of the numbers, y row + 4, h 24 | tag style above, text 16 |
| Bar track | x 100, y row + 44, 590 × 38, radius 19 | `#5A4030`, 3 px brown stroke |
| Bar fill | x 104, y row + 48, 582 × fraction, h 30 | not met: Cash `Color.Coin`, cars `#6ED2FF`; met: `Color.Success` |
| Tick slot / tick | centre x 740, y row + 62, r 24 / `icon-tick.png` 56 × 56 | as [[portal-sign]] |
| **Peek reservation** | x 10, y 300, 780 × 90 | **left empty** in the build. Reserved for a future Peek prompt, which is not built and is never a button on the plaque. The dashed outline in the mock is an annotation only |

- **Values:** the PREVIEW values from [[portal-sign]] (1,200 / 5,000 Cash; 2 / 3 cars). **Summit Pass shows the same numbers.** No Summit values exist and none are invented.
- **States drawn:** LOCKED and READY!. Written only: one requirement met (that row green with a tick, pill still LOCKED); values not loaded ("– / –", bars empty).
- **Read distance:** title capitals 0.3 studs, row text 0.21. Readable from about 5 to 7 studs on a phone (comfortable rule), so the pedestal sits right beside the walk line. At range, the pill colour, bar fill and ticks carry the state.

## 3. Leaderboard pair (IRW-152)
**Purpose:** show who has the most cars, and the week's fastest Stunt Circuit times, beside the Garage and the Stunt entrance. Nothing is connected, so every row is PREVIEW sample data or the honest empty state.

| Part | Size (studs) | Where | Art |
|---|---|---|---|
| Legs | two posts 1.2 wide, 2 tall | | navy |
| Screen | **18 × 14** inside a 1-stud navy frame (board 20 × 16), bottom at 2 | SurfaceGui, front face, PixelsPerStud 50, canvas 900 × 700 | live (below) |
| Topper | 20 × 5 on top of the frame (18 to 23) | front face | `leaderboard-topper-most-cars.png` / `-fastest-stunt.png` 1024 × 256 (51 px per stud) |
| Trophy | about 4 tall, on the topper | mesh (gold `#FFC83D`, base `#E07B12`) | |

**Topper headers (baked):**
- MOST CARS / OWNED: two lines, **capitals 1.5** (font 102 px in the texture), gold `Color.Coin` with an `#E07B12` side face and an ink outline. Car icon badges in Garage red `#D9503F`. Limit 64, comfortable 34.
- FASTEST / STUNT CIRCUIT: capitals **1.35** (STUNT CIRCUIT is the longest line), with stunt icon badges in `#F7CE58`. Limit 58, comfortable 31.
- The research asked for 2.6-stud header capitals. **That does not fit:** "MOST CARS OWNED" at 2.6 capitals is 34 studs wide, and "FASTEST STUNT CIRCUIT" 43 studs, against an 18 to 20 stud board. At 60 studs from the plaza, the topper's colour, icons and trophy carry the board; the words read from about 34 studs.

**Screen, live (design px, 900 × 700):**

| Element | Position | Value |
|---|---|---|
| Column row | y 0 to 54, navy | "#", "PLAYER" and "CARS" / "BEST TIME" in Fredoka One 30, Chrome `#D6DEE8`. PREVIEW tag (text 20) right edge at x 640. Stunt board: a WEEKLY pill at x 248, 150 × 36, `#F7CE58` with ink text 26 |
| Rows 1 to 10 | from y 58, pitch 63.5, height 61, alternating `#24335A` / navy | rank at x 44 (Fredoka One 40; ranks 1 to 3 in a medal circle r 25: gold `#FFC83D`, silver `#D6DEE8`, bronze `#D98A4A`); name at x 100, left aligned, Fredoka One 47 cream (**capitals 0.7 studs**, as researched); value right edge x 870, Fredoka One 47, gold for the top 3, cream otherwise |
| Long names | | TextScaled inside 560 px, minimum 32, then TextTruncate AtEnd |
| Empty state | | rows hidden; "No scores yet" Fredoka One 56 cream, and "(the board fills in when it is connected)" 28 Chrome |

- **Row read distance:** limit 30, comfortable 16 (research: run the path within 15).
- **Row pitch:** 1.27 studs (the research's 1.4 does not leave room for the column row).
- **PREVIEW sample data.** Most cars: Zippy Zebra 42, Captain Vroom 37, Pickle Pop 33, Sunny Sprocket 29, Maple Muffin 26, Professor Beep 22, Wobbly Wheels 19, Lemon Drop 15, Pixel Pup 12, Biscuit Boost 9. Stunt weekly: the same ten names reordered, times 0:38.4 to 0:53.5.
- **Envelope conflict (for the lead):** `assets/island/rework/task4-layout.js` reserves `board: { w: 12, d: 4, h: 14 }`. This board is about **20 wide and 27 tall** (2 + 16 + 5 + 4). Either the envelope grows and the sightline and falls checks are re-run, or the board shrinks: smaller header text, the trophy dropped, or the topper merged into the frame.
- **Data owner:** not decided. Car counts and stunt times are other lanes' data. Weekly resets and any cross-server board (OrderedDataStore) are out of scope until approved (AGENTS.md).

## 4. Plot gate nameplate beam (IRW-151)
**Purpose:** mark each plot's entrance with its number and its owner, and tell the owner "this one is yours".

| Part | Size (studs) | Where | Texture / layer |
|---|---|---|---|
| Beam | 24 × 3 across the two pillars (opening 14 × 11, pillars 3 × 3, overhang 2 each side), underside 11 | front face (and back face, the same) | `plotgate-beam-<n>-<colour>.png` 1024 × 128 (43 px per stud), one per plot |
| Owner name | live, on the beam | SurfaceGui, PixelsPerStud 50, canvas 1200 × 150; text rect x 160, y 20, 880 × 110 | Fredoka One max 88 (capitals 1.32), TextScaled, min 40, cream, 6 px ink UIStroke, centred; the display name in upper case |
| Label tab | 12 × 1.6 on top of the beam (14 to 15.6) | front face, SurfaceGui PixelsPerStud 50 | cream face, 4 px accent stroke, navy Fredoka One 60 (capitals 0.9) |
| PREVIEW row plate | 12.6 × 1.4, hung 0.4 below the beam on two short rods (bottom 9.2, so 9.2 clear for avatar and car) | front face, SurfaceGui PixelsPerStud 50 | navy, 3 px accent stroke. Left to right: PREVIEW tag, car icon, "7 CARS" cream, "INCOME TIER 2" gold; Fredoka One 35 (capitals 0.53) |

- **Beam art (baked):** navy face, accent bands 0.4 top and bottom with an ink line, a faint cream inner frame round the name zone, and the plot number in an accent disc at each end. Disc 2.3 across; number cream with a brown outline, **capitals 1.4**. Number limit 60, comfortable 32; name 57 / 30.
- **Accent family (one family):** 1 red `#E5484D` (`Color.Danger` value), 2 orange `#FF8A1F` (`Color.Primary` value), 3 yellow `#F7C531`, 4 green `#3DBE6C` (`Color.Success`), 5 blue `#3F8FE0`, 6 purple `#8E5BE8`. Danger and Primary are screen-UI roles; reusing their values decoratively on world signs follows [[plot-track-signs]].
- **Label (proposal):** the owner's own client shows **YOUR SPEEDWAY**; every other player sees **SPEEDWAY**. The text is set locally, nothing is saved.
- **States:**
  - Owner present: name shown.
  - Unclaimed plot: name hidden, tab "SPEEDWAY", plate hidden (proposal).
  - Long name: TextScaled, then TextTruncate AtEnd. A 20-character name at average letter width fits at about 70 px; 20 W's drop to the 40 minimum and truncate.
  - Names go through Roblox text filtering (build detail).
  - Car count and Income Tier stay PREVIEW until a contract exists. **"Income Tier" is an economy concept**: its existence, name and values are propose-first and not decided here.
- **Owner name source:** Lane 2 (Brian L), already on the board.

## 5. Stunt entrance boards (IRW-150)
| Board | Size (studs) | Where | Texture / layer | Text | Read distance |
|---|---|---|---|---|---|
| STUNT CIRCUIT letter board | 32 × 4 on top of the 29-wide gantry beam (beam 10 to 14, board 14 to 18, the 18-stud gantry height in the layout) | front face (back face the same) | `stunt-beam-lettering.png` 1024 × 128 (32 px per stud): navy, chequered ends 3 studs wide (0.5-stud squares), yellow edge rules | STUNT CIRCUIT `#F7CE58`, side face `#E07B12`, ink outline, **capitals 2.4**, 24.5 studs wide | limit 103, comfortable 55 |
| COMING SOON end sign | 10 × 5 on a post, bottom at 2.5, at the far end of the apron | front face | `stunt-coming-soon.png` 1024 × 512 (102 px per stud): navy and yellow hazard border 0.5 wide, cream panel | COMING / SOON navy, capitals 1.15; a PREVIEW tag baked in (the whole sign marks a preview) | 49 / 26 |
| YOUR BEST | 8 × 4 board by the apron | front face; bg `stunt-board-your-best-bg.png` 1024 × 512 (128 px per stud), header strip `Color.Calm` with the baked YOUR BEST (capitals 0.6) and stunt icons | live SurfaceGui 800 × 400 at 100 px per stud: PREVIEW tag (text 22) centred at y 118; time "0:42.7" Fredoka One 140 `Color.Coin`, ink stroke, centred at baseline 300; caption "best stunt lap time" 26 Chrome | header 26 / 14; time 45 / 24 |
| WEEKLY TOP | 8 × 4 | bg `stunt-board-weekly-top-bg.png`, header strip `#F7CE58` | live: PREVIEW tag right edge x 770, y 112; three rows from y 172, pitch 72: medal r 26, name Fredoka One 46 cream at x 100, time 46 gold, right edge 770 | rows 15 / 8 |

- **States:**
  - YOUR BEST: PREVIEW time, or "No run yet" (Fredoka One 64 cream) while not connected.
  - WEEKLY TOP: PREVIEW sample rows (Pickle Pop 0:38.4, Biscuit Boost 0:39.9, Zippy Zebra 0:41.2), or the empty state (proposal: "No scores yet", as §3).
- The five start lights and their slow countdown are IRW-150 motion, not this spec. They sit on the beam face under the letter board and are drawn unlit in the mock.

## 6. Garage (IRW-149)
**GARAGE sign**

| Item | Value |
|---|---|
| Size and place | 56 × 14 studs on the 70-wide Garage front, bottom at 11, top at 25 (eaves 26) |
| Texture | `garage-sign.png` 1024 × 256 (18 px per stud), front face |
| Art | red-orange face `#E8562A` (proposal); navy trim 0.75 top and bottom with a cream pinstripe |
| Letters | GARAGE in cream `#FFF6E0`, side face `#8C2A14`, ink outline, **capitals 9** (50.7 studs wide) |
| Read distance | limit 386, comfortable 205 (the research recommendation) |

Marquee bulbs are **separate parts, not texture**: about 14 warm `#FFE9A8` Neon spheres, 1 across, on a 4-stud pitch along the top edge. They glow steadily with no chase animation, so reduced motion changes nothing. The 2-stud checkered band under the sign is mesh or a repeating Texture, not part of this image.

**Showroom turntable rarity rings:** recommended **no text** on the rings. Ring colour only (0.6 wide on the rim), because rarity tiers and their names are undecided (Lane 2 data). While the cars are previews, each turntable gets a small floor plaque, 3 × 0.8 studs, navy, with a PREVIEW tag. It is live SurfaceGui, so there is no texture.

**"Open Garage" ProximityPrompt:** prompt text, not art; Roblox default prompt style.

| Property | Value |
|---|---|
| ActionText | "Open Garage" |
| ObjectText | "Garage (preview)" |
| HoldDuration | 0 |
| MaxActivationDistance | 10 (proposal) |
| KeyboardKeyCode | default E |

When the player presses it: only that player sees ObjectText change to **"Not connected yet"** for 3 s, then it changes back. No screen panel opens, nothing is sent to the server, nothing is saved. Any panel the prompt opens later is new screen UI and goes through [[0012-figma-ui-workflow]] on its own.

## 7. Snack stand picture headers (IRW-144)
**No new art.** The four header pictures already exist, are decided ([[island-signs]]: one smiling food picture each, no words) and are uploaded: `AssetIds.luau` HeaderHotDog, HeaderPopcorn, HeaderIceCream, HeaderLemonade (300 × 160). They sit on the kit `HeaderBoard` (3.0 × 1.6, printable face 2.8 × 1.4). This spec only fixes how the boards sit, so the pictures read in front of the awnings at the two Task 4 snack corners (two stands each).

| Stand | Mount | Height (bottom to top) | Depth |
|---|---|---|---|
| Carts (hot dog, popcorn) | unchanged: hung on two dark straps from the awning's front edge, below the scallop tips (6.15) | 4.45 to 6.05 | eave 2.1 out, board front at 2.15 |
| Booths (ice cream, lemonade) | **change (proposal):** two small bracket blocks on the fascia hold the board's face at **3.35** from the stand centre (it is 3.0 today), so the whole board is in front of every scallop (eave 2.9). It covers the middle scallops on purpose: the 1.1-stud gap under the roof is smaller than the board | 3.8 to 5.4, resting on the body top | face 3.35 |

- Seen from 12 studs at 1080p, the header is about 192 × 102 px ([[island-signs]]).
- Whole-result review F8 found the booth boards partly behind the scallops; the 0.35 offset is meant to fix that. It must be checked in a Studio capture from the walkway: front, and 30° either side.
- The "above the awning" option was rejected, because the rooftop sculptures sit there.
- This is a `ParkDressing.luau` change (`front = 3.0` → 3.35 for the two booths), for the build after approval. Not done here.

## Assets
All in `C:\Users\agert\Documents\Car-Hop-Art\review\task4\signs\textures\`. Upload status for every file: **upload approved: no; asset ID: none.** Upload only after Adam approves ([[0012-figma-ui-workflow]] step 7); never invent IDs. The Figma frames contain the same images.

| File | Size | Sign |
|---|---|---|
| `crest-name-downtown.png`, `crest-name-dusty-highway.png`, `crest-name-summit-pass.png` | 1024 × 512 | §1 crest panels |
| `crest-emblem-downtown.png`, `crest-emblem-dusty-highway.png`, `crest-emblem-summit-pass.png` | 512 × 512 (transparent) | §1 medallions and the §2 padlock emblem |
| `plaque-locked.png` | 1024 × 256 | §2a |
| `plaque-requirement-bg-dusty-highway.png`, `plaque-requirement-bg-summit-pass.png` | 1024 × 512 | §2b |
| `leaderboard-topper-most-cars.png`, `leaderboard-topper-fastest-stunt.png` | 1024 × 256 | §3 |
| `plotgate-beam-1-red.png` … `plotgate-beam-6-purple.png` | 1024 × 128 | §4 |
| `stunt-beam-lettering.png` | 1024 × 128 | §5 |
| `stunt-coming-soon.png` | 1024 × 512 | §5 |
| `stunt-board-your-best-bg.png`, `stunt-board-weekly-top-bg.png` | 1024 × 512 | §5 |
| `garage-sign.png` | 1024 × 256 | §6 |

The icons on the boards are the existing Task 3 icon PNGs (`island-kit\textures\signs\icon-*.png`), unchanged.

## Motion
None in these signs; reduced motion changes nothing. The gate unlock, the start-light countdown and the turntable rotation are motion owned by IRW-148, IRW-150 and IRW-149, specified with their builds.

## Decisions made in this pass (reversible)
- Crest panel 32 × 16 with a separate 9-stud emblem disc. DOWNTOWN on one line at 3.3; the two-word names on two lines at 4.6.
- Gate template (columns 6 × 33) assumed for the mock only.
- LOCKED plaque 16 × 4 without a second line.
- Requirement plaque 8 × 4 on a 3-stud pedestal, tilted 30°, with the Peek strip at the bottom.
- Leaderboard: header on a topper (two lines, 1.5 / 1.35 capitals); row pitch 1.27; PREVIEW tag in the column row; WEEKLY pill.
- Placeholder names (listed in §3).
- Plot beam 24 × 3 with the number baked twice and the name live; tab text YOUR SPEEDWAY / SPEEDWAY by viewer; the PREVIEW plate hung under the beam.
- Plot accent hexes for yellow, blue and purple.
- STUNT CIRCUIT on a letter board above the beam; COMING SOON 10 × 5.
- Garage red-orange `#E8562A`; no text on the rarity rings.
- Booth headers pushed out to 3.35.

## Decisions for Adam (one batch)
1. **Approve or change the whole batch:** crests and emblems, LOCKED plaque, requirement plaque, leaderboards, plot beam, stunt boards, GARAGE sign. Record it in `vault/design/visual-direction.md`.
2. **DOWNTOWN size:** one line at 3.3 capitals (readable to about 140 studs, not 200), or a wider Downtown crest, which breaks the one-outline family.
3. **Leaderboard size:** the boards need about 20 × 27 studs against the 12 × 14 layout envelope. Either grow the envelope (and re-run the sightline and falls checks) or accept smaller headers or no trophy. Also confirm the header capitals (1.5 / 1.35, not the researched 2.6).
4. **Placeholder names** (Zippy Zebra, Captain Vroom, …) are fine for a PREVIEW board, or give others.
5. **Plot gate label:** "YOUR SPEEDWAY" for the owner and "SPEEDWAY" for everyone else? What does an unclaimed plot show?
6. **"Income Tier" on the PREVIEW plate:** keep the words as a placeholder, or drop them until the economy is designed (an economy field is propose-first).
7. **Plot accent family:** red, orange, `#F7C531` yellow, green, `#3F8FE0` blue, `#8E5BE8` purple, including reusing the Danger and Primary values decoratively.
8. **Requirement plaque:** remove it on unlock or keep it showing READY!? Is Summit Pass's car row "DUSTY HIGHWAY CARS"? Is the Peek strip at the bottom where you want it?
9. **Garage:** the red-orange (`#E8562A`), and no text on the rarity rings until the tiers exist.
10. **Prompt wording:** "Open Garage" / "Garage (preview)" / "Not connected yet" (3 s, local only).
11. **Booth headers moved out to 3.35** so they sit in front of the scallops.
12. **Upload:** after approval, permission to upload the 22 textures (under which account, Restricted or Open Use) and to list them in `vault/design/assets.md`.

## Not verified
- Nothing was built or seen in Studio; every read distance is calculated, not measured.
- The Figma frames were written but never viewed (no reads).
- Names were not searched against Roblox display names or trademarks.
- The gate template, Garage front and gantry drawn in the mocks are context, not the kit models.
