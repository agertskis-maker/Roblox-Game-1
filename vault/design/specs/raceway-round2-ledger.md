---
title: Raceway round 2 - ledger
tags:
  - design
  - speedway
  - raceway
  - island
status: in progress
---

# Raceway round 2: ledger (RW2)

Source: Adam's review of PR #4, 2026-10-29 (`vault/design/specs/raceway-round2.md`). Branch `feature/lane3-speedway-upgrades` (draft PR #4). Decision [[0027-raceway-round2]]. Builds on [[speedway-upgrade-looks-ledger]] and [[0025-speedway-visible-levels]]. Owner: Adam (Lane 3). Studio preview purchases only: no Cash, prices, save fields or remotes.

Status words: **built** (code or mesh written, lint clean), **Studio-tested** (run in Adam's private island place, mode named), **waiting** (on a person), **not done**.

## Requirements

| ID | Requirement | Source | Files | Status / evidence |
|---|---|---|---|---|
| RW2-01 | Board claim on main, board-only commit | prompt | BOARD.md (main) | done: `7eb5535` |
| RW2-02 | Brief copied into the vault; plan with folders and lane check posted | prompt | `raceway-round2.md` | done |
| RW2-03 | Remove every sponsor, brand or ad at every level; list what was removed | Part 1 | Props, Track, KitIds, kit_speedway.py | built: see "Removed" below |
| RW2-04 | Bleachers: cream fascia, navy lower stripe 15 %, mirrored short teal end stripes, plain middle | Design 1 | kit_speedway.py `bleachers` | built (mesh re-exported; Blender sheet `island-kit-speedway/sheets/sheet_rw201.png`) |
| RW2-05 | Grandstand: navy fascia, cream inset, two mirrored coral end caps; owner name only on its own sign | Design 1 | kit_speedway.py `grandstand_bay`, Props.grandstand | built; the optional start/finish checker strip on the stand was not added (the track already has the checker line) |
| RW2-06 | Banked walls: barrier shape kept, cream upper edge, broad teal band, coral end marker each side; no billboards | Design 1 | Track.bankWalls | built |
| RW2-07 | Blimp: cream body, navy underside, teal fins, one coral stripe each side, no lettering; movement unchanged | Design 1 | kit_speedway.py `blimp`, Props.blimp | built (orbit code unchanged) |
| RW2-08 | Big screen: one calm "RACEWAY LEVEL N" on navy, cream text, small teal underline; far: plain panel | Design 1 | Props.bigScreen | waiting: Figma approval (UI) |
| RW2-09 | Baked letters: identify affected meshes and uploads; keep old ids until replacements are verified | Design 1 | KitIds.Superseded, manifest | done: no uploaded mesh carries lettering (all text was SurfaceGuis); the 4 banner images carry baked brand names and are no longer referenced; 3 repainted meshes wait for the re-import |
| RW2-10 | Before/after stills, same camera, level and lighting | Design 1 | review page | not done |
| RW2-11 | "Speedway" becomes "Raceway" wherever a player reads it; internal names keep "Speedway" | Part 2 | Props, Signs, Kiosk, Reveal, PreviewPanel | waiting: Figma approval (sign and HUD text) |
| RW2-12 | Banner states the level only ("RACEWAY LEVEL 5!"), one line or "RACEWAY" / "LEVEL 5!"; 0.18 / 1.10 / 0.22 s; latest only | Part 3, Design 2 | Ladder.banner, Reveal.banner | waiting: Figma approval |
| RW2-13 | Level names kept as internal labels only | Part 3 | Ladder | to do with RW2-12 |
| RW2-14 | Kiosk becomes the Raceway shop inside the Kiosk reservation; measured | Part 4, Design 3 | kit_speedway.py `raceway_shop`, Props.shop, Hub/Recipes/Plot | built: 9 x 7 x 8.5 (0.5 inside the 10 x 8 x 9 reservation); Adam's 12 x 8 x 10.5 target does not fit; SpeedwayChecks checks it |
| RW2-15 | Shopkeeper: rigid parts, idle bob <= 0.05 over 3.2 s, greeting 55 deg / two 12 deg waves / return, once per approach, >= 8 s apart, no greeting through walls, Reduce Motion still pose, never collides | Part 4, Design 3 | kit_speedway.py `keeper_*`, Props.shop, Life, SpeedwayLooks | built |
| RW2-16 | Stats board instead of the picture: current and next level, LAP PAY x1.35 -> x1.50, "New: ...", price placeholder; MAX at 12; visitors read only | Part 4 | Kiosk.luau, Ladder | waiting: Figma approval |
| RW2-17 | Lap Pay multiplier table (PROPOSAL for Brian L), read from one table | Part 4 | Ladder | to do with RW2-16 |
| RW2-18 | "Upgrade Raceway" prompt for the owner only; upgrade panel; Studio-preview BUY raises the level with the reveal; no Cash, saves or remotes | Part 4, Design 4 | new panel module | waiting: Figma approval |
| RW2-19 | Parking: owned bays usable, next bay barrier with ADD SPOT, others plain floor; start 2, max 15 | Part 5, Design 5 | Parking, ParkingLook, Hub/Recipes/Plot | built (geometry, reveal); plaque and sign text wait for Figma approval |
| RW2-20 | Parking sign with "Buy Parking Spot" prompt and panel; preview BUY unlocks with the 0.9 s reveal; ALL SPOTS OWNED at 15 | Part 5, Design 5 | ParkingLook, new panel module | reveal built; panel waiting: Figma approval |
| RW2-21 | Parking and level independent in both directions | Design 5 | separate attributes | built by construction (separate attributes and builders); Studio test to do |
| RW2-22 | Island walking base 32, boost 48 exactly, no stacking, run takeover releases and restores | Part 6, Design 6 | WalkBoost, WalkBoostLogic, SpeedModifiers, tests, walk-boost.md | built by the walking worker (Sonnet); tests written, not yet run in Studio |
| RW2-23 | Dust puffs only while moving on a boost lane, <= 4/s, 0.25 s, 0.15 to 0.35; off for Reduce Motion and low detail | Design 6 | WalkBoost | built; not yet seen in Studio |
| RW2-24 | Walk animation, camera, edges, fences and jumps at 32 and 48 | Part 6, Design 6 | (Studio test) | not done |
| RW2-25 | Brian R's run does not depend on WalkSpeed 16 | Part 6 | (read only) | done: `git grep` on `origin/feature/lane1-run-prototype` finds no WalkSpeed, JumpPower or MovementSpeedOwner; the run anchors the root while riding |
| RW2-26 | Messages for Brian L (rename, RacewayLevel, Lap Pay table, parking, purchase flow) on main; keep Replies | Part 7 | speedway-levels-for-brian-l.md (main) | not done |
| RW2-27 | Studio Play: owner and visitor, levels 1 to 12, buying 12 levels and 2 to 15 spots, MAX states, walking, portal; desktop, phone and tablet frames | Part 8 | review page | not done |
| RW2-28 | Review page `Car-Hop-Art/review/raceway-round2/` | Part 8 | | not done |
| RW2-29 | check.ps1, commit, push, PR #4 update, board, log | Part 8 | | not done |
| RW2-30 | Figma mocks and specs for every changed UI piece, batched for Adam's approval | prompt, 0012 | `vault/design/ui/raceway-*.md`, Figma "Car Hop UI" | in progress |

## Removed (Part 1)

| Name | Where | Replaced by | Still in runtime geometry or a pending upload? |
|---|---|---|---|
| PIP'S POPS, COMET COLA, HAUL BUDDY TIRES | SurfaceGui text on the bleachers' and the grandstand bays' navy sponsor plates (`Props.sponsorPanel`, removed) | bleachers: a plain cream fascia with a navy lower stripe and two teal end stripes; grandstand: a plain cream inset on the navy fascia, coral end caps | No. The text was never in a mesh. The old bleachers and grandstand uploads (ids in `KitIds.Superseded`) still have the old blank navy plate, no letters |
| ZOOPA FIZZ, CRUNCHKIN PUFFS, STICKYTOE TYRES, WOBBLEBOT TOYS | three Decal banners on the far banked wall, level 9 (`Track.bankWalls`) | the wall itself: teal band, cream upper edge, coral end markers | The four images stay uploaded (island AssetIds, `KitIds.Textures` entries removed); nothing in the Raceway references them. Other island uses: none (`git grep` finds the four ids only in the `AssetIds.SignArt` table; `Signs.banner`, which could show them, has no caller since the track moved into the look) |
| CAR HOP | SurfaceGui text on both blimp plaques (`Props.blimp`) | plain envelope with a coral side stripe; the plaques are gone from the mesh | No (text was a SurfaceGui; the old blimp upload has two blank plaques) |
| LINEUP / PREVIEW car rows | the big screen (`Props.bigScreen`) | "RACEWAY LEVEL N" display (waiting for Figma approval) | No |
| "sponsor" meta faces | `SwBleachers` and `SwGrandstandBay` recipe meta | `fascia` meta, no text | No |

Searched: `assets/island/kit/kit_speedway.py`, `assets/island/kit/manifest.md`, every file in `src` for the three sponsor names, the four banner names, "sponsor", "BannerA" to "BannerD" and "CAR HOP".

## Choices recorded here
- Internal code, file, attribute and folder names keep "Speedway" (`SpeedwayLook`, `SpeedwayLevel`, `Lane3SpeedwayPreviewLevel...`) to avoid churn (Adam allowed it). Only player-readable text changes.
- The 2-spot start is Adam's decision (2026-10-29).
- The parking sign stands in the Paddock reservation's free left margin (plot frame x -33.8, u 264.2), away from the gate (x -16..16). No other reservation exists for it.
- The bays a plot does not own are plain Paddock floor: the old 15 painted tiles, yellow starter outlines and floor numbers are no longer built by the island recipe (the Lane 2 bay markers are unchanged).

## Studio evidence so far (2026-10-29, before the UI approval)
Adam's private island place, one Studio, Rojo port 34873. Edit = edit-mode preview; Play = Studio Play, one client (no multi-client test, no physical device).

| Rows | Mode | What was checked | Result |
|---|---|---|---|
| RW2-03 to RW2-07, RW2-10 | Edit | before / after stills from the same five cameras on plot 3 (before = the five look modules of `5192669` checked out for the capture, then restored) | grandstand, bleachers, far banked wall, blimp, kiosk and Paddock captured before and after (`Car-Hop-Art/review/raceway-round2/stills`); the big screen "after" waits for its UI approval; the first blimp "after" showed the coral stripe too wide (both equator bands), fixed to one band and confirmed in the mesh data (coral triangles 88 to 44); an edit-mode capture of the fixed blimp is not possible (edit mode keeps the old mesh data module cached) and Play ran out of EditableMesh budget before the blimp |
| RW2-14 | Edit | `SpeedwayChecks.run` (every level) and a plaza view with and without the shop | fits: 0 sector or protected hits at every level, the shop inside the Kiosk reservation less 0.5 and under 9; plaza view at standing eye height: the new shop costs about the same as the old kiosk (level 1: 77.0 vs 78.5 %; level 9: 56.0 vs 57.5 %); from a camera 12 up it costs 6 to 12 points more (level 1: 80.0 vs 91.5 %), from its 8.5 roof. For Adam: keep, or a lower roof (about 7) |
| RW2-15 | Play | keeper greeting measured per frame | one greeting per approach: 1.03 s (target 1.05), peak 67 deg (55 + 12), none while standing at the counter, none on a return inside 8 s; idle bob range 0.020 stud (limit 0.05); Reduce Motion override: bob 0, arm 0 over 3.3 s. First run found two bugs (front from the mesh's LookVector, ray blocked by the booth's own collider), fixed and re-tested |
| RW2-19, RW2-21 | Play | parking reveal 2 to 3 per frame; independence | barrier lift done by 0.21 to 0.25 s, bay 3 lines 0.25 to 0.55 s, confetti gone by 0.72 s, lifted arm removed at 0.9 s, barrier moved to bay 4; level 6 kept 2 spots, 4 spots kept level 6, level 2 kept 4 spots; five quick changes 5 to 9 ended at 9; 15 = no barrier; 99 clamps to 15; reset back to 2 |
| RW2-19 | Edit | `SpeedwayChecks.parking` for 2 to 15 | client bay list = Hub/Layout's; 0 parts outside the Paddock after moving the prompt anchor 0.5 in, 0 on routes, 0 colliding decoration |
| RW2-22 | Play | `WalkBoostTests.run({ respawn = true })` | **322 passed, 0 failed, 0 skipped** |
| RW2-22, RW2-24 | Play | the same 65-stud avenue 3 stretch walked three times (MoveTo, real character) | island base off: 15.7 studs/s (peak 16); base 32, lanes off: 31.3 (peak 32); base 32 on the boost lane: 44.3 average, peak 48 (the first 7 studs are before the strip) |
| RW2-22 | Play | run handover fixture (character placed in and out of the Summit Pass field) | outside 32; inside 16 with `MovementSpeedOwner = Lane3RunFixture`; back out 32 and the attribute cleared (teleported, not walked) |
| RW2-27 | Play | real-time video | **blocked**: Windows does not let this session bring Studio to the front, and the window capture is black behind other windows; needs Adam to click the Studio window once (guided moment) |

## Walking boundaries (Studio Play, 2026-10-29 evening)
Plot 3 frame, a real character driven by MoveTo and a scripted jump at the bank edge (Roblox's default jump: the root peaked at y 9.5 every time), Studio Play, one client.

| WalkSpeed | Speed at the jump | Came down at | River at that spot (x 25) |
|---|---|---|---|
| 16 | 15.4 | u 155.0 (in the river) | water u 147 to 164 (18 wide) |
| 32 (island base) | 30.7 | u 163.0 (the far edge of the water) | |
| 48 (boost lane only) | 46.5 | u 170.5 (clear across) | |

- A boosted running jump clears the 18-wide river; at 32 it reaches the far edge. Every avenue already has a bridge where its boost lane runs, so it saves a few seconds and crosses no fence or gate. For Adam: accept (reversible: a low reed edge or a wider river).
- The plots have no fences (visitors may walk onto any Raceway by design), so there is no plot fence to jump.
- Lake: from the fountain toward +Z the first water is 78 studs out behind a sand beach sloping to -0.7; a 32-speed run in ends up swimming in the shallows and walking back out is on land in 1.0 s (no drop, no trap). Swimming speed stays the island base 32 (the boost itself drops in water, as designed). Roblox's own state flicker (Swimming, GettingUp, Running) shows at the shallow edge.
- Not tested: the waterfall approach, diagonal and turning runs, the walk animation look at 32 and 48 on video (needs the Studio window in front).
