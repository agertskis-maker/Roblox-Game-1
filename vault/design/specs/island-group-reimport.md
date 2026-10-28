---
title: Island Task 4 kit - group-owned re-import (prepared, waiting)
tags:
  - island
  - assets
  - group
status: waiting
---

# Island Task 4 kit: group-owned re-import

**Status: prepared, not run.** Waiting for the Car Hop Roblox group's ID (Adam, asked 2026-10-28: "Not yet, keep going"). Prepared by Claude Code in the Speedway upgrade looks session (brief section 5, step 6), the same way the HUD session prepares the B2 Downtown kit. Nothing has been uploaded for this. The group ownership note is the HUD session's (reserved number 0024).

## What moves
- **97 meshes**, the Task 4 families: garage 30, gates 37, park4 12, stunt 18. Today they are user-owned (peskaface, user 2393473976), uploaded 2026-10-22 in one 3D Importer batch, ids in `src/island/Hub/Environment/AssetIds.luau` (the block after "Task 4 (2026-10-22)") and in `assets/island/kit/manifest.md`.
- **Source package:** `C:\Users\agert\Documents\Car-Hop-Art\island-kit-task4\all\island-kit.obj` (97 objects, one group each, true size; checked 2026-10-28: 97 `o` names). Assets cannot move from a user to a group, so this is a new upload, not a transfer.
- **Not in this instruction, listed for Adam:** the island's 137 Task 2 meshes and its 15 effect images, the Task 3 sign art and the kit palette image (`AssetIds.Palette`) are also user-owned. Whether a group-owned experience may use user-owned images and meshes is the HUD session's documentation check; if the answer is no, these need the same treatment and are a separate decision.

## Steps (one guided moment with Adam, private island test place only)
1. Hold `STUDIO_LOCK.txt`; open the private island place (`open-island-test.ps1`, CarHop Island Test (private)); confirm it is not Team Create.
2. Adam: File > Import 3D (Ctrl+M), pick the OBJ above; in the importer: **Upload to Roblox on, Creator: the Car Hop group**, Import Only as a Model on, Scale Unit Stud, factor 1. Expect file dimensions about 418 x 35 x 409 and no size warning. The final Import click is Adam's.
3. Claude, in edit mode: `require(game.ServerStorage.Island:Clone().Hub.Preview.ImportCheck).run(<imported model>, "Task4", <group id>)`: expects 97 found, none missing, extra or duplicated, sizes within 0.01 of the manifest, and the group as creator on the sampled assets.
4. Replace the 97 lines in `AssetIds.luau` with the printed `idLines`; keep the old ids in `assets/island/kit/manifest.md` as "retired, user-owned".
5. Rebuild the island, Play-test: every Task 4 piece loads (no white boxes, no "failed to load" warnings from KitAssets), screenshots and console. Remove the imported model from the Workspace.
6. Record: manifest rows, the log, the board.

## Speedway kit (same moment)
The new Speedway kit (`Car-Hop-Art\island-kit-speedway\island-kit.obj`) is imported in the same guided moment, with the group as Creator, and checked with `ImportCheck.run(<model>, "Speedway", <group id>)`; its ids go in `src/shared/Island/Speedway/KitIds.luau` (`Meshes`). If the group is still unknown at the end of the session, both imports wait.
