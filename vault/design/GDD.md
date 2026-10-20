---
title: Game Design Document
tags:
  - design
status: selected
concept: Car Hop
---

# Game Design Document

> [!info] Concept selected: Car Hop (working title)
> The team selected Car Hop at the 18 October 2026 meeting. Record: [[0007-concept-car-hop-and-lanes]]. Full detail is in [[car-hop-outline-v2]], the approved v2 outline; [[car-hopping-game-outline]] is the older v1, kept as history. This file is the live summary. If it disagrees with the outline, this file wins and the outline is refreshed.
>
> **Labels.** Every rule keeps the label it has in the outline:
> - **Decided**: stated by the owner at the 18 October meeting. Change it only with the owner.
> - **Proposed**: a reversible pick (the outline calls these "Delegated"). It is not a requirement until the owner or area owner approves it.
> - **Tunable**: a starting value for the first playtest. Not approved balance.
> - **Deferred**: not in the first release.
> - **Open**: needs an owner or team decision. Do not invent an answer.
>
> Choosing the concept does not approve any propose-first item in `AGENTS.md` (currency and economy fields, paid items, cross-server data). Each still needs its own approval first; see [[0007-concept-car-hop-and-lanes]].

## Pitch
You are a fearless kid who leaps from car to car on a never-ending highway. Hold on to a new car long enough and it is yours for good. Back on your island your cars drive laps on your own Speedway and pay you every lap; spend that Cash to grow the Speedway, unlock new Worlds with better cars, and chase Gold, Chrome and Rainbow versions. Take any car you own into the Stunt Circuit to race for the best time. Details: outline sections 01, 06 to 10.

## Target audience
- Mainly children (**Decided**): readable at a glance, no scary failure, no punishing loss, no text-heavy menus.
- Phone and PC both supported (**Decided**); phone layouts are checked in Studio's device emulator throughout. Console is **Deferred**.
- Tone: cartoony-cool, chunky and energetic (**Proposed**).
- No launch deadline (**Decided**). Quality over speed.

## Core loop
1. **Run.** Forward motion is automatic. Steer, and tap once to Hop to an auto-targeted car before the ridden car's Heat is full (**Decided**). Runs are endless until failure (**Decided**); retry is free (**Decided**).
2. **Claim.** Stay aboard an unowned car until its Keys meter fills and it is yours permanently, immediately, even if the run then fails (**Decided**). A few seconds, a little longer for rarer cars (**Decided**; the seconds are **Tunable**). Claiming a car you already own pays a Joyride Bonus (**Decided**).
3. **Go home.** Your Lineup cars drive laps on your Speedway and each lap pays a lump sum straight to your balance; rarer cars pay more (**Decided**). Spend Cash on the Speedway and on World unlocks, then run again.
4. **Race** (optional). Take one owned car into the Stunt Circuit obstacle course (**Decided**).

Run details (**Proposed** unless stated): private client-simulated runs checked by the server, four-lane one-direction traffic (same direction is **Decided**), Foot Dash on missing a car (landing on the road is **Decided**), Heat that resets on every Hop and rises on bumps (**Decided**), hazards: potholes, oil slicks, construction, gap jumps (**Decided**). Outline section 06.

**Heat stages** ([[0008-heat-critical-meltdown]]): `Calm` "Cool", `Warning` "Hot" from 60%, `Critical` "Too hot!" from 85%, `Meltdown` "Losing control!" at 100% (thresholds **Tunable**).
- Critical (**Decided**): localized red emphasis on the ridden car and the gauge, flashing at most 2.5 times per second, all visible peaks combined (0008 amendment 2), never full-screen; with reduced motion, steady red, a label or icon, and stripes instead.
- Meltdown (**Decided**): 100% Heat does not end the run. The car becomes hard to control for a brief escape window, Hop stays available, a claim that completes during it still counts, and the run ends only if the window expires with the player aboard. The HUD shows no escape timer: the bar stays full, "Losing control!" is joined by **HOP NOW!**, and smoke rises from the thermometer (0008 amendment).
- Heat display (**Decided**, 0008 amendment): continuous fill and colour (blue, pale cream about 35%, yellow at 60%, orange about 75%, red from 85%; no green); at Critical the Heat panel becomes a localized alarm driven by one clock shared with the car effect; reduced motion uses steady styling.
- Meltdown driving details (**Proposed**, **Tunable**, Lane 1): a 3-second window, sluggish steering, growing wobble and drift, falling speed, a final spinout, never inverted controls.
- This replaces the outline v2.0 "Blowout" and 1-second "Sputter" rule.

## Progression
- **Garage**: the permanent collection, with cards per World.
- **Worlds**: three at launch, variations rather than harder levels (**Decided**): Downtown, Dusty Highway, Summit Pass. Unlocking one needs Cash plus cars owned from the previous World (**Decided**); "5 of 8" is **Tunable**. Car names and rosters are **Proposed**, and **Open** for approval before any modeling.
- **Cars**: eight families, each with one run quirk (quirks per family **Decided**; the set of eight is **Proposed**), four rarities (**Proposed**), and Gold, Chrome and Rainbow Variants (**Decided**; spawn and multiplier rules **Proposed**).
- **Speedway growth**: Slots (start 3, max 12) and five Income Tiers that change how the plot looks (**Proposed**; counts and multipliers **Tunable**). Most spending improves the Speedway; income upgrades never affect racing (**Decided**).
- **Missions and Goals**: three rotating missions plus a one-time checklist (**Proposed**).
- **Stunt Circuit**: ghost time trial at launch, medals per car, cosmetic rewards (**Decided** that racing and cosmetic rewards exist; the format is **Proposed**). Live race lobbies are **Deferred**.

## Economy
One currency, **Cash** (**Proposed**: no second currency at launch). Server-authoritative.

| Sources | Sinks |
|---|---|
| Lap Pay (main), offline earnings | Slots, Income Tiers |
| Claims and Joyride Bonuses | World unlock (Cash part) |
| Road coins, Milestones, Missions, Goals | Paint, decals, wheels |
| Stunt Circuit finishes and medals | |

- Lap Pay = rarity base x Variant multiplier x Income Tier multiplier, credited by a server timer (**Proposed**; every number **Tunable**).
- Restricted offline earnings exist (**Decided**); the 50% rate and 8-hour cap are **Proposed** and **Tunable**.
- Pacing targets (hours to unlock Worlds, and so on) are for the first playtest only. No price in the outline is final.

> [!warning] Server authority
> All currency and inventory logic is server-side. The client only requests actions. See `AGENTS.md`.

> [!warning] Propose-first
> Cash, Lap Pay, offline earnings, and any currency or economy field in saved data are propose-first in `AGENTS.md`. Present benefit, cost, risk and a test, and record the owner's approval as a decision note, before building them.

## Systems
- [ ] Player data / saving (ProfileStore); save layout owned by Lane 2
- [ ] Catalog module: every car, World, price and mission template as data (**Proposed**); owned by Lane 2
- [ ] Island hub: 12-player servers and a plot per player (**Proposed**, **Tunable**), Garage, Portals
- [ ] Run: traffic, chase camera, Hop and target ring, Foot Dash, Heat, hazards
- [ ] Claiming: Keys meter, server check against a run seed, Joyride Bonus, Results panel
- [ ] Speedway: Lineup, Lap Pay timers, Slots, Income Tiers, offline earnings, plot visiting
- [ ] Worlds and Variants
- [ ] Stunt Circuit: course, race stats, ghosts, medals, customization, weekly board
- [ ] Missions and Goals
- [ ] Tutorial (arrows and short prompts, no cutscene: **Decided**)
- [ ] Game passes

## Monetization
Game passes from the start (**Decided**). Pass set (**Proposed**, prices **Open**): Double Lap Pay, Expanded Paddock, VIP. Passes never change Heat, Keys or race performance. No paid randomness and no Developer Products at launch. Nothing is built until the team approves a design and current Roblox policy and this account's publishing eligibility are checked (`CLAUDE.md`). Outline section 12.

## Art and audio direction
- Chunky block cartoon: rounded blocks, big wheels, flat saturated colors, thick dark UI outlines, one palette per World, bright daytime lighting (**Proposed**).
- UI: one panel style, icon-first labels, large numbers; the outline proposes touch targets of at least 44 px. Fonts, the final touch-target size, and the reduced-motion mechanism are **Open**, to be proposed with the visual direction for the owner's approval (`AGENTS.md`).
- Audio: one music loop per World plus the island and Stunt Circuit, short key sounds, and no sound that carries information alone (**Proposed**).
- Reference: Rodeo Stampede informs the mechanics only. No assets, names, characters or presentation are copied; every car is fictional. Outline section 13.

## Milestones
Stages, not dates: there is no deadline (**Decided**). Each stage ends with the checks listed in outline section 15.

| Milestone | Goal | Target date |
|-----------|------|-------------|
| M0 Foundation | Catalog skeleton, save schema v1 with Mock tests, island greybox with 12 plots; a player joins, gets a plot, saves and loads an empty profile | none |
| M1 Run prototype | Downtown road, traffic, camera, Hop, Foot Dash, Heat, three placeholder cars | none |
| M2 Claiming and keeping | Keys, server validation, Joyride Bonus, Results, coins, Milestones | none |
| M3 Speedway and economy | Lineup, Lap Pay, Slots, Income Tiers, Garage UI, offline earnings, visiting | none |
| M4 Worlds and Variants | Three full Worlds, Portals, Start In picker, Variants, Missions and Goals | none |
| M5 Stunt Circuit | Course, ghosts, medals, rewards, customization, weekly board | none |
| M6 Release | Tutorial, passes, audio, lighting, UI review at all sizes, policy checks, phone performance | none |

## Open questions
Full list: outline section 17. Still open:
- Final title (Car Hop is a working title) and whether it is available on Roblox.
- The one integration person ([[0007-concept-car-hop-and-lanes]]). Lane owners are named: Brian R (Lane 1), Brian L (Lane 2), Adam (Lane 3).
- Approval of the proposed car names and silhouettes before modeling.
- Game pass prices; whether Developer Products or a daily bonus are ever added.
- Publishing eligibility and current policy for this account.
- Server size (12 proposed) after the first multiplayer test.
- Approvals still owed under `AGENTS.md` before building: the Cash economy and its save fields, game passes, and any cross-server data (the weekly leaderboards and shared ghosts use OrderedDataStore and a DataStore).
- Daily mechanics (mission refresh, the daily taper on race rewards, the optional daily bonus) need a check against the rule that the audience is mainly children and no streak pressure is used.
