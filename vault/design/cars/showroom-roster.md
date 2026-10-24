---
title: Showroom roster, five tiers
date: 2026-10-24
tags:
  - design
  - vehicles
status: approved-by-car-owner
---

# Showroom roster, five tiers

> [!note] Approved by Brian L (car looks owner) on 2026-10-24: "Approved: the five-tier showroom roster as written."
> This is Brian L's car-modeling list for his own private showroom place, so it needs no sign-off from the other lanes (Brian L, 2026-10-24). Putting the five tiers into the game's GDD or Catalog is a separate, later step. The Lap Pay values and the flagged names are still open.
>
> Brian L's revision, 2026-10-24, of the 24-car showroom seen in Studio screenshots (four tiers: Common, Rare, Epic, Legendary, six cars each). The showroom place (`CarHop_Showroom.rbxl`, Brian L's local file) is not in Git. On 2026-10-24 it was rearranged to match this list: a green UNCOMMON zone, Common moved one zone along, cars moved between tiers with their `Rarity` attribute updated, name-sign placeholders "(to build)" for the six new cars, Solar Flare parked in `ServerStorage.ParkedCars`, and a full copy of the old layout in `ServerStorage.CarShowroom_Backup_2026-10-24`. Nothing is built, uploaded, or in the Catalog. This is a different list from [[roster]] (24 cars by World and family); which one the game uses is open. Names follow `AGENTS.md` "Vehicles"; risk notes are judgement, not legal advice.

Lap Pay per tier (proposals from [[rarity-style]] section 12, not approved): Common $5, Uncommon $8, Rare $12, Epic $30, Legendary $80.

The rule used to place every car: **roughly what the real car it parodies costs, and how special it looks.** Cheap everyday cars are Common; nicer everyday cars with one fun idea are Uncommon; sporty or tough cars are Rare; expensive luxury, off-road and electric cars are Epic; supercars and hypercars are Legendary.

## What changed

1. **New Uncommon tier (green)** between Common and Rare, with six cars: two moved down from Rare and four new ones.
2. **Zip and Street Kid** move from Rare to **Legendary**. They look like Italian supercars, which cost hundreds of thousands in real life.
3. **Solar Flare is dropped** from Legendary and from launch. It is a round bubble concept car with no real car behind it, so it has no fair place on a "real car value" ladder. Keep the model parked for a later fun or event slot.
4. **Two electric cars added:** Polytruck (Cybertruck-style pickup, Rare) and Sparkster (Tesla Roadster-style sports car, Epic). Same names as in [[roster]].
5. Re-check of the rest: the two muscle cars (Thunder, Brawler) move from Epic down to Rare, and Velvet moves from Legendary down to Epic. Real muscle cars cost far less than luxury and exotic cars, and Velvet reads as a fancy sports coupe, not a supercar.

## Roster

| Tier | Car | Looks like (from the screenshots) | Real-world class and rough price | Why this tier | Change |
|---|---|---|---|---|---|
| Common | Rustbucket | Small classic white city car | Old tiny city car, very cheap | The cheapest kind of car | Same |
| Common | Putter | Mint bubble city car with a black roof | Tiny classic city car | Cheap and cute | Same |
| Common | Old Faithful | Blue 1980s hatch | Old everyday car | Cheap and plain | Same |
| Common | Commuter | Silver small sedan | Everyday sedan, about $20k | Ordinary car | Same |
| Common | Family Hauler | Beige minivan | Family minivan, about $35k | Vans stay Common or Uncommon | Same |
| Common | Pizza Runner | White delivery van with a pizza on the roof | Small delivery van | Work van, kept low | Same |
| Uncommon | Workhorse | Blue older pickup | Basic pickup, about $30k | Everyday truck, one step up from a family car | Down from Rare |
| Uncommon | Trailblazer | Orange small boxy 4x4 | Small 4x4, about $25-30k | Fun but not sporty | Down from Rare |
| Uncommon | Minnow | New: modern three-door hatch with a contrasting roof | Premium small hatch, about $30k | Nicer than a Common, one trim idea (the roof) | New |
| Uncommon | Beach Bug | New: open beach buggy with a roll bar | Kit-car dune buggy | Fun character car, not fast | New |
| Uncommon | Sunny Camper | New: 1960s-style split-window camper van with a pop-up roof | Classic camper van | Charming van; vans top out at Uncommon | New |
| Uncommon | Surf Wagon | New: 1950s wood-panel station wagon with a surfboard on the roof | Classic wagon | Character car with one decoration idea | New |
| Rare | Rally Dog | White raised rally 4x4 | Rally-prepared car | Clear sporty identity | Same |
| Rare | Bolt | White small sports coupe | Small sports car | Sporty | Same |
| Rare | Thunder | Red muscle car | Muscle car, about $40-70k | Sporty and loud, but far below exotics | Down from Epic |
| Rare | Brawler | Teal muscle car | Muscle car, about $40-70k | Same as Thunder | Down from Epic |
| Rare | Polytruck | New: angular faceted electric pickup | Electric pickup, about $80-100k | Futuristic, but still a truck | New |
| Epic | Desert King | Lifted desert pickup | High-performance off-road truck, about $90k | Expensive specialist truck | Same |
| Epic | Executive | Dark luxury car | Luxury sedan, $100k+ | Expensive, special looking | Same |
| Epic | Monarch | White boxy luxury 4x4 | Luxury off-roader, $100k+ | Expensive, special looking | Same |
| Epic | Night Rider | Black performance car | Luxury performance car, $100k+ | Expensive, special looking | Same |
| Epic | Velvet | Purple sports coupe | Premium sports coupe, $100-150k | Fancy, but not a supercar | Down from Legendary |
| Epic | Sparkster | New: low electric two-seater with a removable roof | Electric sports car, about $100-200k | Supercar-quick, below the true exotics | New |
| Legendary | Zip | Yellow wedge supercar | Italian supercar, $250k+ | A dream car | Up from Rare |
| Legendary | Street Kid | Purple wedge supercar | Italian supercar, $300k+ | A dream car | Up from Rare |
| Legendary | Viper Strike | Green supercar | Supercar | A dream car | Same |
| Legendary | Phantom | Dark grey hypercar | Hypercar, $1M+ | The rarest kind of car | Same |
| Legendary | Apex | Low hypercar | Hypercar, $1M+ | The rarest kind of car | Same |
| Legendary | Cruiser | Blue open-top supercar | Collector supercar, $1M+ | A dream car | Same |
| (dropped) | Solar Flare | Round bubble concept car with orange wheels | No real car | Odd one out; park for a later fun slot | Removed |

Count: 6 Common, 6 Uncommon, 5 Rare, 6 Epic, 6 Legendary, 29 cars (6 of them still to build). Three Legendaries (Zip, Street Kid, Viper Strike) are wedge supercars; if that feels samey, Zip can sit in Epic instead.

## Name checks against `AGENTS.md` "Vehicles" (flags, not decisions)

These existing names may break rule 2 (no real model or brand name used unchanged). Each needs a visible parody twist or a new name:

| Name | Problem | Suggested replacement |
|---|---|---|
| Trailblazer | A real SUV model name, unchanged | Trail Pup |
| Bolt | A real electric car model name, unchanged | Jolt |
| Phantom | A real luxury car model name, unchanged | Spectra |
| Workhorse | A real electric truck company name | Haul Horse |
| Viper Strike | Contains a real sports car model name | Fang Strike |

## Other mismatches to settle

- The showroom's Variants are Gold, Diamond and Rainbow. The GDD has Gold, Chrome and Rainbow as **Decided**. Using Diamond in the game instead of Chrome would be a GDD change for later.
- [[roster]] lists 24 different cars by World and family. The team needs to choose which list is the real one, or merge them.
- The showroom models were not checked for logos, badges or copied shapes. Zip, Street Kid, Viper Strike and Cruiser look closest to specific real cars and should be checked first.
