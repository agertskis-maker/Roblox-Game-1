# 0034: Real cars on the Lane 3 screens

Date: 2026-11-02. Owner: Adam (Lane 3).

**Decision.** `RealCar` shows Brian L's Normal cars on Customize, Trails, the launch card, the Launch Pad and the Car stall. `Supercar` stays as the fallback. Gold, Diamond and Rainbow are not pickable until real ownership exists.

**Why these methods.**
- The cars' textures are baked per car, so `Supercar`'s shells cannot map onto them. Paint is a see-through coloured copy of the body.
- Decals stay card-only on real cars. `decal_*` are `Supercar` texture sheets and `thumb_decal_*` are pictures of `Supercar`; both looked wrong on a real car. Flat decal art needs an owner-approved upload.
- `ViewportFrame` shows no Trail or particle objects, and a 2D drawing cannot follow a turning car, so the preview trail is parts on the car's tail.
- A Texture or Decal change inside a live `ViewportFrame` does not redraw until the part is reparented.

**Found in the built place.** A car model's pivot sits at its middle, not the bottom centre `assets/cars/README.md` says. Pizza Runner's pivot does not run along the car. Some models carry a saved scale. `RealCar` squares each display copy from its wheels and keeps the saved scale. `CarCard`, `RunKit.thumb` and the island seats still use the raw pivot.

**Risk.** Car meshes belong to Brian L's user account, not the group. They load for Adam in a local file; a published group place is untested.
