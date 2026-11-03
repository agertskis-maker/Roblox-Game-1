---
title: 0032 Lane 3 Round 2
status: accepted
date: 2026-11-02
tags:
  - decision
  - lane3
---

# 0032: Lane 3 Round 2

Brief [[lane3-round2]], ledger [[lane3-round2-ledger]]. Builds on [[0031-lane3-big-round]]. Reversible choices made without asking, as the brief told me to, with why.

## Ownership
- **Brian R builds the Stunt Circuit** course and gameplay (Adam, 2026-11-01). Lane 3 keeps the screens and the island gate and sign. `src/lookdev/Stunt` stays as an optional kit.
- **Cosmetics cost Cash** (Adam's direction). Prices stay Brian L's; the screen shows named PREVIEW prices and a separate PREVIEW balance.
- **BEST DEAL is back on** when it is true inside the PREVIEW catalog. SAVE 15% is computed from 647 and 549.

## Raceway
- **Root cause of the crossing lines:** lanes, their paint and the barrier gaps were three separate hand-kept geometries. Now `Speedway/RoadNet` is the one source; junctions are single polygons that replace the track between two cross-sections.
- **The near turn is flat at every level** (it banked 3 degrees). A flush junction is impossible on a banked edge, and 3 degrees barely showed.
- **Pit lanes moved into the per-client Look** so a junction can replace the track at each level. On levels 1 to 3 they are dirt with no paint.
- **Lanes are 10 wide**, the aisle's own width, and leave the aisle's end, so they no longer run through the outer row B bays.
- **Paved plot surfaces all top at 0.2**, the road's height. Parked cars sit 0.16 lower into the floor as a result.
- **The hump is level 11 only.** The loop takes that straight.

## Loop
- A teardrop from a curvature schedule: 38.9 high, radius 14.1 at the top and 30.2 low. Not called a clothoid.
- **Ribbon 16 at the road, 14 up in the loop.** The brief's starting value is 16 throughout, which needs a 54-stud taper; two of those plus the loop's 38 of forward run do not fit the 103.6 straight. The hard rule (two track widths, tapers of 3 x the extra width) holds: 32 wide, 48-stud tapers.
- **Every car takes the loop.** With entry and exit side by side there is no room for a third lane beside it, so nothing passes it.
- The entry stays on the road's line and the exit bends back over 48 studs.
- Slim legs at the ring's widest points. A full steel portal hid the loop like a cage.

## Island
- **Both white fences removed:** they were the only two on the island.
- **Boards turned about 18 degrees** toward the avenue, 32 studs on the plaza side. They already faced the fountain itself; that read wrong from the path. The Garage board is mirrored with it.
- **The low tilted plaque by locked gates is removed.** The locked portal's dialogue card says the same thing.
- **Crowns stay 1 stud apart everywhere**, measured from the trunk at the widest way. 658 plants became 580, mostly far forest.
- **Signposts keep the approved arrow boards.** The arrow is the point of a signpost, and SignKit has no arrow form.
- **Snack stop:** a pad with two stalls and a bench, at the end of the stands.

## UI
- **Icons:** cut from the ChatGPT sheet. Seven are composed (home, steer, hop, retry, moon, plus, check). `GameIcons` is the one source and `Icons2.draw` asks it first, so every screen changed at once. Until the upload, Adam's local files show them through EditableImage from modules kept outside Git.
- **Ground arrows** update every frame from the character and flow to the target (Adam, 2026-11-02: "they need to move with the character with every step"). Before, they were redrawn three times a second.
- **Phone Cash** sits bottom centre beside the thumbstick zone. Phone tiles are 48 rows, not 56: only about 166 px sit above the thumbstick.
- **Coach Roxy** is a local proposal for a name, not approved lore.
- **`Screen` has a Live mode** so the UI fills a real screen; the device frame stays for the playground.

## Beta
- **`joinMode` is an explicit test switch** (`HomeJoinMode` on `CarHopBeta`), default new. Nothing saved says whether a player is new, and this round adds no save field.
- **The join queue** is `Home/ModalQueue`: one blocking panel, four pending, two info cards, one promotion after 30 quiet seconds.
- Results "Earn faster" is a goal pill after coming home, because the beta's results card is Brian R's.

## Left alone on purpose
- **Summit's majors rule still fails.** Its rule has one narrow solution, and fixed stations collide with each seed's road layout, which made the look worse. It needs a design choice: see the ledger.
- **No audio in videos.** Windows Application Control blocks the capture tool. I did not rebuild it to get round the block.

## Adam's changes during the round (2026-11-02)
- **The Worlds replace Brian R's test scenery in the beta** ("override his rule ... keep his gameplay and game mechanics"). His files are not edited. Lane 3 removes every part of a road segment that is wider than the road or stands above it, once the World is standing, and leaves his road, kerbs, markings, cars, rules and camera. `ReplaceRoadside` on `CarHopBeta` is the switch. The three Worlds are built in the background after join.
- **The tutorial is for first-time players only.** This needs one saved flag, so `TutorialDone` was added to the **beta-only** save template (`BetaConfig.Template`) and one no-argument remote. Adam asked for it directly. It does not touch the real game's save, and Brian L's real layout still needs its own field.
- **The real screen has its own UI scale.** The phone rule grew the UI to 1.5 on any window taller than 585 px. Off phones it is now the window height over 800, from 0.7 to 1.15.
- **No keys are named in the tutorial,** and the run's own keyboard hint is hidden in the beta, because phones play too.
- **Players spawn on the plaza, in front of the fountain.** There was no SpawnLocation, so Roblox used the world's centre.
- **A thin paved collar runs just outside the plaza's edge.** It closes the grass slivers at the path joins.