# Finished cars

Only Brian L edits this folder ([decision 0015](../../vault/decisions/0015-car-modeling-to-brian-l.md)). Ask him on the board before changing anything here.

- One `.rbxmx` file per finished car, in Roblox's text model format. `.gitignore` allows `.rbxmx` only in this folder.
- Each file references mesh asset IDs uploaded under Brian L's Roblox account (Open Use, Asset Privacy off).
- Rojo syncs this folder into `ReplicatedStorage.Cars` (`default.project.json`).
- `.blend` and `.fbx` sources never go here. They live in the team's shared Google Drive folder.
- Look rules, the rarity guide and the roster: `vault/design/cars/README.md`. Naming and logo guardrails: `AGENTS.md` "Vehicles".

## Showroom models (2026-11-02)

The 108 files here are Brian L's showroom cars: 27 cars, each in Normal, Gold, Diamond and Rainbow (roster: `vault/design/cars/showroom-roster.md` on branch `feature/lane2-ev-roster`). Polytruck and Sparkster are not built yet.

- Exported from Brian L's local `CarHop_Showroom.rbxl` with Lune; the file name is the model name (for example `Gold Workhorse.rbxmx`).
- Each model's pivot is its bottom centre with the front facing -Z, worked out from the wheel positions.
- Attributes: `CarName`, `Rarity` (COMMON, UNCOMMON, RARE, EPIC, LEGENDARY) and `Variant`. They are display labels only, not the Catalog.
- Display models: every part is anchored, with no seat or driving rig. The rig contract with Lane 1 is still open.
- Rainbow cars carry `RainbowFlowScript`, a `--!strict` client script that cycles the shimmer colours only while the car is in Workspace, and holds still with Roblox's Reduce Motion setting on.
- Meshes are AI-generated in Studio and referenced by asset ID (`MeshContent`). Not yet checked: which account owns them and whether they are Open Use.
