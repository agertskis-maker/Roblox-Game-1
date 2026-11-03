---
title: Real cars on the Lane 3 screens and Launch Pads, for Brian L
date: 2026-11-02
tags:
  - design
  - lane2
---

# Real cars on the Lane 3 screens and Launch Pads, for Brian L

Your 27 Normal cars now show on Customize, Trails, the launch card, the Car stall and all three Launch Pads. They are read-only clones: `assets/cars` was not edited. Paint and wheels are PREVIEW looks on the copy. Gold, Diamond and Rainbow are not pickable until real ownership exists.

**Please look at these four things.**
1. **Pivots.** In a Rojo-built place, a car's pivot sits at its middle, not the bottom centre `assets/cars/README.md` says, and Pizza Runner's does not run along the car. Some models also carry a saved scale. `RealCar` works around this from the wheels. `CarCard`, `RunKit.thumb` and the island seats do not, so cars may sit wrongly there.
2. **Mesh ownership.** A sample of 55 ids all belong to your user account, not LEGION STUDI0S. They load for Adam in a local file; a published group place is untested. If they fail there, players see the stand-in car.
3. **Pizza Runner.** A reviewer said the white van with a red swoosh reads a little like an ambulance. `AGENTS.md` bans emergency liveries. Your call.
4. **Decals.** Your cars' textures are baked per car, so decals show only on their cards for now. Flat decal art would fix it.

Bolts changed too: 5 per run, 1 per hop. Anything in economy-v1 that counts on 10 needs a look.

**Owner avatars.** `src/client/Home/Island/PlotOwners.client.luau` reads each plot's `Owner` and `OwnerDisplayName` attributes. Please keep those names in the real plot service. No new data was added.
