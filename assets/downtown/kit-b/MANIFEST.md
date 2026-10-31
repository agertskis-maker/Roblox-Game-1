# Downtown kit B2: import manifest (X-05)

This is the plan for bringing the B2 kit into Roblox as uploaded MeshParts. **Nothing has been
imported or uploaded yet.** Uploads need Adam's click in the 3D Importer, under the existing
permission (uploads only under peskaface, logged), in the task's local test place, never the
Team Create place. Every Studio-side statement below comes from the Roblox Creator Docs
(3D Importer, Mesh specifications) and is **unverified on this kit** until the first import.

## Source of truth

- **Recipes**: `assets/downtown/kit/kit_b2*.py` (in Git).
- **Generated data**: `C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2\` (outside Git, rebuilt by `kit_b2_build.py`):
  - `manifest.json`: per mesh, the stable `name`, `family`, `district`, `lod`, `triangles`, `bounds`, `size`, `pivot` (text), `pivot_offset`, `sockets`, sign `faces`, `default_text`, `replaces`, `fbx_grid`. It also holds family totals.
  - `meshes/<Name>.json`: geometry plus the full `meta`. This is the same compact format the Studio preview builder reads (`src/lookdev/Downtown/KitMesh.luau`).
  - `swatches.json`: per swatch index, the name, a fixed flag, and the RGB for `MS`, `CH`, `HB`, `MT`, `SP`. A `B` column repeats Main Street for the overnight builder.
  - `palette-B2-MainStreet.png`, `-CityHall`, `-HarborBridge`, `-Midtown`, `-SkylinePark`: 256 × 256, 16 × 16 swatches of 16 px.

## Stable names

`B2_<Family>_<Variant>`, the same in the JSON file name, the FBX object name, the OBJ group, and the
MeshPart name after import. Families: `Road`, `Lot`, `LM`, `Mid`, `Sky`, `Harbor`, `Street`,
`Park`, `Prop`, `Sign`, `Span`, `Haz`. Lane-width variants end in `_L4W16`, `_L4W17` or
`_L4W18`. A name never changes once uploaded. A changed mesh gets a new upload under the same name,
and its id goes into the asset-id table (below).

## Pivots

Each mesh is authored around its contract pivot (see README "Frames, pivots and sockets"). An
imported MeshPart is centred on its bounds, which the preview builder's `KitMesh.luau` also
assumes. To place by the contract pivot:

- `MeshPart.PivotOffset = CFrame.new(-pivot_offset)`, where `pivot_offset` is `meta.pivot_offset` (bounds centre relative to the pivot, Roblox axes).
- Then `part:PivotTo(slotCFrame)`, with `slotCFrame` from a segment socket or a lot frontage slot.
- Socket CFrames are `pivotCFrame * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)`.
- Lots face local −Z (`meta.facing = "-Z"`). Mirror only by the `_L`/`_R` variant, never by a negative scale.

## Materials and palette assignment

- Every mesh carries a single material. All of its colour comes from UVs that point at swatch centres (flat colour per face).
- In Studio, set `Material = SmoothPlastic` and `TextureID` = the uploaded palette image for the district:
  - Lots, midground and district awnings use their district's palette (see `meta.district`; `any` means use the current district's).
  - Fixed swatches (road, hazards, furniture, signs, landmarks, skyline) are identical in all five images, so those meshes can use any palette. Use Main Street so they batch.
- The research note suggests one shared TextureID per district so identical meshes instance into one draw call. Five palettes therefore mean at most five texture variants per lot mesh.
- Material hints in meta:
  - `B2_Street_LampLens` may be Neon (dim).
  - `B2_Haz_Oil`: SmoothPlastic, Reflectance about 0.25. The sheen needs `EnvironmentSpecularScale > 0`.
  - Water: Reflectance about 0.15.
  - No Transparency on any scenery.
- Set `CastShadow` off for midground, skyline and furniture under about 4 studs. Scenery is Anchored, with CanCollide, CanTouch and CanQuery off and CollisionFidelity Box (lead and DC decide; Lane 1 owns kerb collision).

## The batch import package

**`downtown-kit-b2.fbx`** (1.16 MB) is ONE file containing all 140 meshes:

- Each mesh is a separate object named by its stable name.
- Every mesh is triangulated.
- Flat normals (smoothing by face).
- Axes are converted to Roblox (forward −Z, up Y).
- Objects are laid out on a 260-stud grid, 16 per row. `manifest.json` gives each object's `fbx_grid` cell, so nothing overlaps in the importer preview.
- All objects share one material (`B2_Palette`) whose image is `palette-B2-MainStreet.png`, embedded in the file.

**`downtown-kit-b2.obj`** holds the same set, with one `g` group per mesh, as a fallback. The
importer splits OBJ files by group, not by object, so a group is written per object, as in the
overnight kit. This file has no material.

Proposed importer settings (setting names from the Roblox Creator Docs, importer page):

| Setting | Value | Why |
|---|---|---|
| Import Only As Model | **off** | Each child mesh becomes its own asset, giving one MeshId per stable name. Default is on, which makes one asset only. |
| Merge Meshes | off (default) | Keep 140 separate MeshParts. |
| Upload to Roblox | on only with Adam's approval | Otherwise it is a local test import. |
| Add to Workspace | on, in the local test place only | This also grants that place permission to use the assets. |
| Set Pivot to Scene Origin | default (on) | Affects only the Model's pivot; each part's pivot comes from `PivotOffset` above. |
| Scale Unit | Studs | The meshes are authored in studs. Blender wrote 1 unit = 1 stud with unit scale applied. **Verify** one size against `manifest.json` (e.g. `B2_Lot_Shop24Low_a` should be about 24.6 × 32.5 × 23.8) before uploading the rest. If it arrives 100× off, change Scale Unit and re-import. |
| Anchored | on | Static scenery. |

After the import:

1. Record each MeshId in an asset-id table keyed by stable name. This is lead-owned: the review plan says `AssetIds`. It is not written here, because no ids exist yet.
2. Upload the five palette PNGs as images and record their ids.
3. Set the per-district TextureID as described above.
4. **Check access**: each MeshId and image id loads in the test place (the docs say asset use needs owner or share permission).

## Format limits and known risks

- **20,000 triangles per mesh** (Mesh specifications). The largest B2 mesh is the City Hall at 1,231 triangles, so the kit is well under.
- **Watertight, no back faces, volume** (Mesh specifications guidance). B2 deliberately leaves out faces the chase camera cannot see: wall backs behind trim, sill undersides, open railings, single-sided signs' backs where a wall covers them. Markings, water, oil and the pothole are flat or near-flat. The overnight OBJ import of similar geometry is the precedent, but Studio import behaviour for this kit is **unverified**. If the importer rejects a mesh or shows holes, the first step is to rebuild that family with back faces enabled. Doing so means removing the `skip` lists in `kit_b2lib.fbox` calls.
- **No n-gons**: the FBX and OBJ are triangulated on export. The JSON is triangles by definition.
- **One texture per MeshPart**: district recolour is by TextureID swap, not per-face materials.
- **Pivot loss on import** is handled by `PivotOffset` from `meta.pivot_offset`, which was computed from the same vertex data as the export.
- **EditableMesh preview** (the existing Studio builder) is session-only: capped at 20k triangles and 60k vertices per mesh and subject to device memory budgets. Production should use the uploaded MeshParts (research note, finding 12).

## Ownership

| Item | Owner |
|---|---|
| Recipes and generated data | DK, on this task |
| The import click and uploads | Adam (only after approval) |
| The asset-id table and Studio wiring | Lead and DC |
| Segment sockets, streaming, collision | Brian R (Lane 1); proposals only here |
