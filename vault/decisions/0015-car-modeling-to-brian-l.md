---
title: "0015: car modeling moves from Lane 3 to Brian L"
date: 2026-10-21
tags:
  - decision
  - vehicles
  - lanes
status: accepted
---

# 0015: car modeling moves from Lane 3 to Brian L

## Decision (Adam, repository owner, 2026-10-21)
1. **Owner.** Brian L (Brian Levenson, GitHub `jdhwjd`) owns car modeling, in addition to Lane 2 Data & Economy. He does the save-data module first, then cars.
2. **Approvals.** Brian L approves car looks. Lane 3 (Adam) keeps the world, the UI, the HUD and the Downtown scene.
3. **Finished cars** live in `assets/cars/`, which only Brian L edits. There is one `.rbxmx` file per car, in text format. The `.rbxm` binary format is blocked as a build output, and `.gitignore` allows `.rbxmx` only in this folder. The files reference uploaded mesh asset IDs. Rojo syncs the folder into `ReplicatedStorage.Cars` (`default.project.json`).
4. **Source art.** Car `.blend` and `.fbx` files stay out of the repo, in a shared Google Drive folder. This settles the backlog item "Decide where source `.blend` and exported `.fbx` art lives" for cars only. Animation source art and animation ownership stay open ([[0005-animation-pipeline]]).
5. **Mesh uploads.** Car meshes are uploaded under Brian L's Roblox account, as Open Use, with Asset Privacy off.
6. **First car.** A Fiat 500 parody, the Downtown Compact starter (a Common).

## Builds on
- [[0007-concept-car-hop-and-lanes]] listed "who builds the cars" and "the shared car rig" as open. This note settles who builds and approves the cars. The rig is still open: Brian L agrees it with Brian R (Lane 1).
- [[0010-vehicle-direction]] (accepted 2026-10-20) still applies in full, including the `AGENTS.md` "Vehicles" guardrails. Its owner references now read as Brian L for car looks. Two of its statements are replaced:
  - "Source recipes live in `assets/vehicles/<car-id>/`" is replaced for finished cars by `assets/cars/`.
  - Binary art "in `C:\Users\agert\Documents\Car-Hop-Art\`" is replaced by the shared Drive folder.
- The handover pack is [[design/cars/README|vault/design/cars/README]]. The rarity guide and roster stay proposals until Brian L approves them.

## Why
This is Adam's call as repository owner; the note records no further reason from him. What the setup gives: one person owns car looks, files and uploads, so the roster stays consistent. Text `.rbxmx` keeps cars reviewable in Git without committing binary build outputs. Keeping source art in Drive keeps the repository small.

## Not established yet
- Live sync and mesh IDs: Rojo's documentation lists `MeshPart.MeshId` as a property its live sync cannot set (https://rojo.space/docs/v7/sync-details). Whether a car `.rbxmx` live-syncs correctly, or needs `rojo build`, is untested.
- Whether Open Use meshes owned by Brian L's account load in a place owned by Adam's account is untested.
- The shared Drive folder's link and who has access are not recorded yet.
- The 14 test meshes uploaded on 2026-10-20 under Adam's account (listed in [[first-car-record]]) are test uploads only. They are not the game's meshes.
