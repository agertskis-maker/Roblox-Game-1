---
title: Car handover pack for Brian L
date: 2026-10-21
tags:
  - design
  - vehicles
  - handover
---

# Car handover pack for Brian L

Brian L, car modeling is yours from 2026-10-21, on top of Lane 2 (Data & Economy). Do the save-data module first, then cars. You approve car looks. Adam (Lane 3) keeps the world, the UI, the HUD and the Downtown scene. The decisions are in [[0015-car-modeling-to-brian-l]].

## What is in this folder

| File | What it is | Status |
|---|---|---|
| this README | Decisions, Adam's look rules, the first car, open items | Decisions settled 2026-10-21 |
| [[0010-vehicle-direction]] (in `vault/decisions/`) | The vehicle direction and the five naming and logo guardrails | Accepted 2026-10-20 |
| [[rarity-style]] | Rarity style guide: quality floor, tier ladder, palette, triangle budgets, evidence for "finished" | Proposed |
| [[roster]] | 24-car launch roster across the three Worlds, plus two electric Downtown extras (Polytruck, Sparkster, added 2026-10-24), with parody names and risk notes | Proposed |
| [[showroom-roster]] | Brian L's five-tier revision of the 24-car Studio showroom: green Uncommon added, Zip and Street Kid to Legendary, Solar Flare dropped, two electric cars added, name flags | Proposed 2026-10-24 |
| [[first-car-record]] | Word-for-word copies of the first-car notes: conventions, measurements, upload history, Studio checks | History |

These are copies from Adam's branch `feature/lane3-first-car-downtown` (`f309ea2`). The Blender recipe kit (`assets/vehicles/`, Python) and the Studio preview script (`src/client/Home/CarPreview`) stay on that branch; read them with `git show feature/lane3-first-car-downtown:<path>` if useful.

## Decided

- **Owner.** Brian L owns car modeling and approves car looks (Adam, 2026-10-21).
- **Where finished cars live.** `assets/cars/`, which only Brian L edits. One `.rbxmx` file per car, in text format. Rojo syncs the folder into `ReplicatedStorage.Cars`. `.gitignore` allows `.rbxmx` only in that folder; all other `.rbxm`/`.rbxmx` files are still build outputs.
- **Meshes.** Each `.rbxmx` references uploaded mesh asset IDs. Upload them under Brian L's own Roblox account, as Open Use, with Asset Privacy off.
- **Source art.** `.blend` and `.fbx` files stay out of the repo, in the shared Google Drive folder.
- **Vehicle direction** ([[0010-vehicle-direction]]): original fictional or parody vehicles inspired by real categories, eras and proportions, as polished, shaped low-poly cars. The five guardrails are in `AGENTS.md` "Vehicles": no real logos or badges, every name with a visible parody twist, shapes inspired by but not copied from the real car, nothing mean or unsuitable for children, no police, military or emergency vehicles.
- **First car.** A Fiat 500 parody as the Downtown Compact starter, a Common (Adam, 2026-10-21). Its name is not chosen yet and needs a visible parody twist.

## Adam's car look rules

1. Parody real cars with altered names. No real logos or badges anywhere.
2. Never blocky. Even Commons are nicely shaped and stylish.
3. Clearly cooler as rarity rises: sportier shapes, extravagant paint, flames, shine.
4. Vans are Common or Uncommon only.
5. No taxi signs unless the car is a taxi.
6. The Uncommon tier was added, so there are five tiers: Common, Uncommon, Rare, Epic, Legendary.
7. No Roblox studs.
8. The world is bright and stylized; cars should fit it.

[[rarity-style]] turns rules 2 to 5 into measurable detail. That detail is a proposal for you to approve or change.

## Proposed, not decided

- The tier ladder detail, quality floor, palette roles and per-car triangle budgets (3,000 to 12,000 by tier) in [[rarity-style]].
- The 24-car [[roster]] and every car name in it. The roster's Downtown Compact is "Puglet", a late-1980s/90s three-door supermini. Adam's new first car (the Fiat 500 parody) replaces it in that slot.
- The two electric extras (Polytruck, Rare pickup; Sparkster, Epic sports car), requested by Brian L on 2026-10-24. As extras they give Downtown 10 cars and break the "8 per World, one per family" shape, which Adam and Brian R need to agree to.
- Uncommon economy values (Keys claim 3.5 s, Lap Pay $8, Joyride Bonus $5). These are yours as Lane 2 and are not in code, the Catalog or saves.
- Every rig and running-gear convention below.

## What already exists for the first car

- No Fiat 500 parody has been planned or modelled yet. There are no dimensions, sketches or files for it.
- The only built car is Adam's study B starter (the three-door "Puglet"), made in Blender from code. It is 12.47 x 5.66 x 4.71 studs with 4,992 triangles in 14 mesh pieces. It is the reference for scale and cost, not the look to copy. Study C on the branch ("rounded two-box city car, one-arc roof") is the closest shape to a 500. Details are in [[first-car-record]].
- Its 14 meshes were uploaded as tests under Adam's account (peskaface). They are not the meshes for the finished game.
- Desktop only: 100 copies of that car held 60 fps. Nothing has been measured on a phone.

## Open items

1. **Car rig contract with Brian R (Lane 1), before the first car.** Agree on scale (provisionally 1 stud = 0.28 m), facing (-Z forward, +Y up), part and wheel names, and the seat. Also agree the attachments for Heat steam, the Hop ring, the Keys meter and Variant trails, and how cars with 2, 6 or giant wheels work. Starting point: the provisional rig and the conventions in [[first-car-record]]. Known problem: a default R15 avatar's head sticks about 1 stud through the roof of the study B car.
2. **Triangle budget for about 18 cars on screen on a phone.** The per-car budgets in [[rarity-style]] give roughly 54,000 triangles for 18 Commons and up to about 216,000 for 18 Legendaries. Set one total budget and measure it on a real phone.
3. **Rojo and mesh IDs (to test with the first car).** Rojo's documentation lists `MeshPart.MeshId` as a property its live sync cannot set. A car `.rbxmx` may build correctly with `rojo build` but not appear correctly when Rojo live-syncs into Studio. Check this in your private test place before relying on live sync.
4. **Open Use meshes in Adam's game (to test with the first car).** Check that meshes uploaded under your account load in a place owned by Adam's account.

## Your files on Adam's PC (for the shared Drive folder)

Adam will move the first-car Blender and FBX files into the shared Drive folder. They are listed in [[2026-10-21]].
