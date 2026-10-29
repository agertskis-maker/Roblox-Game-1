# Downtown kit build (Lane 3 look development). Headless Blender, no add-ons, no MCP:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/build_kit.py -- --out C:\Users\agert\Documents\Car-Hop-Art\downtown-kit [--only road,street,hazard,skyline,A,B,C]
# Writes, under --out:
#   palette-A.png, palette-B.png, palette-C.png   one swatch layout, three colour variants
#   swatches.json            index, name, fixed flag and the three colours of every swatch
#   meshes/<Name>.json       compact mesh data (island kit format), Roblox axes, one per mesh
#   manifest.json            name, family, direction, triangles, bounds and metadata per mesh
#   downtown-kit.obj         every mesh of this run laid out on a grid (3D Importer fallback)
# Mesh names are shared by all directions; direction-only pieces start with A_, B_ or C_.
# Art outputs stay outside Git (Car-Hop-Art); these scripts are the recipe.

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kitlib  # noqa: E402,F401
import palette  # noqa: E402

FAMILIES = ["road", "street", "hazard", "skyline", "A", "B", "C"]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out, only, obj = None, None, True
    for i, a in enumerate(argv):
        if a == "--out":
            out = argv[i + 1]
        if a == "--only":
            only = argv[i + 1].split(",")
        if a == "--no-obj":
            obj = False
    if not out:
        raise SystemExit("--out is required")
    return out, only or FAMILIES, obj


def main():
    out, only, want_obj = parse_args()
    meshes_dir = os.path.join(out, "meshes")
    os.makedirs(meshes_dir, exist_ok=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for v in palette.VARIANTS:
        palette.write_palette_png(os.path.join(out, f"palette-{v}.png"), v)
    with open(os.path.join(out, "swatches.json"), "w") as fh:
        json.dump({"grid": palette.GRID, "cell_px": palette.CELL, "size_px": palette.SIZE, "swatches": palette.swatch_table()}, fh, indent=1)

    manifest = []
    cell = [0]

    def emit(builder, meta, family, direction, mirror=False):
        obj = builder.to_object(mirror_x=mirror)
        tris, lo, hi = kitlib.export_json(obj, meshes_dir, meta)
        obj.location.x = (cell[0] % 12) * 120.0
        obj.location.y = (cell[0] // 12) * 120.0
        cell[0] += 1
        manifest.append({"name": obj.name, "family": family, "direction": direction, "triangles": tris, "bounds": [lo, hi], "meta": meta})
        print(f"  {obj.name}: {tris} triangles")

    if "road" in only:
        import kit_road

        kit_road.build_all(emit)
    if "street" in only:
        import kit_street

        kit_street.build_all(emit)
    if "hazard" in only:
        import kit_hazards

        kit_hazards.build_all(emit)
    if "skyline" in only:
        import kit_skyline

        kit_skyline.build_all(emit)
    for d in ("A", "B", "C"):
        if d in only:
            mod = __import__("kit_" + d.lower())
            mod.build_all(emit)

    # previous manifest entries for families not rebuilt this run are kept
    path = os.path.join(out, "manifest.json")
    old = []
    if os.path.exists(path):
        with open(path) as fh:
            old = json.load(fh)
    rebuilt = {m["name"] for m in manifest}
    groups = set(only)
    merged = [m for m in old if m["name"] not in rebuilt and group_of(m) not in groups] + manifest
    merged.sort(key=lambda m: (m["direction"], m["family"], m["name"]))
    with open(path, "w") as fh:
        json.dump(merged, fh, indent=1)

    if want_obj and manifest:
        for o in bpy.context.scene.objects:
            o.select_set(True)
        tag = "-".join(only) if set(only) != set(FAMILIES) else "all"
        obj_path = os.path.join(out, f"downtown-kit-{tag}.obj")
        bpy.ops.wm.obj_export(
            filepath=obj_path,
            export_selected_objects=True,
            forward_axis="NEGATIVE_Z",
            up_axis="Y",
            export_materials=False,
            export_uv=True,
            export_normals=True,
            export_triangulated_mesh=True,
        )
        # the 3D Importer splits an OBJ by group (g), not by object (o): name a group per object
        with open(obj_path) as fh:
            lines = fh.read().split("\n")
        with open(obj_path, "w") as fh:
            fh.write("\n".join(line + "\ng " + line[2:] if line.startswith("o ") else line for line in lines))
    total = sum(m["triangles"] for m in manifest)
    print(f"built {len(manifest)} meshes, {total} triangles in total")


def group_of(m):
    # the --only group that builds a mesh: road, street, hazard, skyline, or A/B/C for the
    # direction modules (families "A/building", "B/landmark", ...)
    return m["family"].split("/")[0]


main()
