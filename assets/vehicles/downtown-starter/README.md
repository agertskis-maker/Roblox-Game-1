# Downtown Common starter (study B)

Status: built in Blender 2026-10-20, pending Adam's review. Proposed name
"Puglet" (not approved). Rules: `AGENTS.md` "Vehicles", decision 0010, and
`vault/design/vehicles/rarity-style.md`.

## Files

| In Git | Purpose |
|---|---|
| `starter_spec.py` | Every dimension, section, decal and colour; the design sheet in code |
| `build.py` | Builds the car, writes stats, exports the FBX, saves the .blend |
| `../lib/carkit.py` | Shared construction kit |
| `../lib/render_views_mcp.py` | Review stills (interactive Blender) |

| Outside Git (`C:\Users\agert\Documents\Car-Hop-Art\vehicles\downtown-starter\`) | |
|---|---|
| `downtown-starter.blend` | Built scene |
| `downtown-starter.fbx` | Import file (14 mesh objects) |
| `stats.json` | Triangle counts and bounds written by `build.py` |
| `renders\*.png` | Review stills |

## Measured in Blender (stats.json, 2026-10-20)

- Overall: length 12.47, width 5.66 with mirrors (5.59 without), height 4.71 studs. At 1 stud = 0.28 m: 3.49 x 1.58 x 1.32 m.
- Wheelbase 7.94 (64% of length), tyre diameter 2.23 (18%), tyre width 0.69 (31% of diameter), roof about 4.1-4.3 wide (73-77% of body width), sill 0.66 (5%).
- Triangles 4,992 in total (3,546 unique, because the wheel meshes are shared); 14 mesh objects: BodyPrimary 1,601, Trim 1,049, Glass 208, Headlamp 108, Taillamp 84, Plate 14, and per wheel Tire 304 and WheelMetal 178.

## Import into the private test place (local only)

1. Run `build.py` (see `../README.md`).
2. Studio, private place `C:\Users\agert\Documents\Car-Hop-Art\CarHop-Lane3-Test.rbxl` (never the Team Create place).
3. Import 3D, choose `downtown-starter.fbx`, untick **Upload to Roblox**, Import.
4. Put the imported model at `ReplicatedStorage.Lane3_VehicleSamples.DowntownStarter`.
5. Playtest, then from the client: `require(game.Players.LocalPlayer.PlayerScripts.Client.Home.CarPreview).start()`.

Studio results are in the dated log; nothing is uploaded or published.
