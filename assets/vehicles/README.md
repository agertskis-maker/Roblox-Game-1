# Vehicle source recipes (Lane 3)

Text-only, reviewable recipes that rebuild every vehicle mesh in Blender.
Binary art (`.blend`, `.fbx`, `.rbxl`, `.rbxm`, renders) never goes in Git; it
lives in `C:\Users\agert\Documents\Car-Hop-Art\` (Adam, 2026-10-20). Rules for
names, logos and shapes: `AGENTS.md` "Vehicles" and decision 0010.

| Path | What |
|---|---|
| `lib/carkit.py` | Shared kit: lofted body and greenhouse sections, wheel arches, wheels, projected lamps and trim, split by colour role, FBX export |
| `lib/render_views_mcp.py` | Review stills for one car (bpy only; run in an interactive Blender or through the Blender MCP) |
| `downtown-starter/` | The Downtown Common starter (study B): spec, build script, import manifest |
| `studies/` | Rough comparison studies: starter architectures A, B, C and five rarity tiers |

## Tools (as used on 2026-10-20)

- Blender 5.2.2 LTS (free). No add-ons needed for the recipes.
- Blender MCP 1.8 add-on with `BLENDER_MCP_SAFE_MODE=1`, used only for review
  renders. Safe mode blocks file access, so the recipes run headless instead.
- Roblox Studio 3D Importer for the local import (Upload to Roblox off).

## Conventions (provisional, for Brian R's review)

- Units: 1 Blender unit = 1 stud. Provisional scale 1 stud = 0.28 m.
- Blender: car faces -Y, up +Z, ground z = 0, car's left side +X.
- FBX export (`carkit.export_fbx`): forward -Z, up Y, scale 1, normals only,
  no animation. In Roblox the car faces -Z, up +Y, right +X.
- One mesh object per colour role: `BodyPrimary`, `BodySecondary`, `Trim`,
  `Glass`, `Headlamp`, `Taillamp`, `Plate`. Wheels: `Wheel_<FL|FR|RL|RR>_Tire`
  and `Wheel_<..>_WheelMetal`, origin on the axle, one shared mesh per kind;
  right-side wheels are rotated 180 degrees about up (no negative scale).
  FL is front-left from the seated driver's point of view.
- Roblox ignores Blender material colours; Studio colours each MeshPart from
  its role (see `src/client/Home/CarPreview`).
- Faces buried inside other geometry are tagged `Hidden` and never exported.

## Rebuild

```
blender -b --factory-startup --python assets/vehicles/downtown-starter/build.py -- --out C:/Users/agert/Documents/Car-Hop-Art/vehicles/downtown-starter --no-render
blender -b --factory-startup --python assets/vehicles/studies/build_studies.py -- --out C:/Users/agert/Documents/Car-Hop-Art/vehicles/studies
```

Each run is deterministic and replaces its outputs. Then open Blender and run
`lib/render_views_mcp.py` (or `studies/render_studies_mcp.py`) for stills.
Headless Workbench renders came out much darker than interactive ones on this
machine, which is why stills are rendered interactively.
