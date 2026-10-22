# Island kit build (Lane 3). Headless Blender, no add-ons, no MCP:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/island/kit/build_kit.py -- --out C:\Users\agert\Documents\Car-Hop-Art\island-kit
# Writes, under --out:
#   palette.png             the shared 256 x 256 swatch image (MeshPart.TextureID)
#   meshes/<Name>.json      compact mesh data for the Studio uploader (one per mesh)
#   island-kit.fbx, .obj    every mesh in one file, for the 3D Importer fallback
#   kit.blend               the generated scene, for inspection
#   manifest.json           name, family, part, triangles, bounds and metadata per mesh
# Art outputs stay outside Git (Car-Hop-Art); these scripts are the recipe.

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kitlib  # noqa: E402

FAMILIES = ["trees", "plants", "props", "animals"]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = None
    only = None
    for i, a in enumerate(argv):
        if a == "--out":
            out = argv[i + 1]
        if a == "--only":
            only = argv[i + 1].split(",")
    if not out:
        raise SystemExit("--out is required")
    return out, only or FAMILIES


def main():
    out, only = parse_args()
    meshes_dir = os.path.join(out, "meshes")
    os.makedirs(meshes_dir, exist_ok=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    kitlib.write_palette_png(os.path.join(out, "palette.png"))

    manifest = []
    cell = [0]

    def emit(builder, meta, family):
        obj = builder.to_object()
        tris, lo, hi = kitlib.export_json(obj, meshes_dir, meta)
        # lay the objects out on a 12-wide grid of 36-stud cells (the largest piece is about 31):
        # the mesh data is local, but the 3D Importer refuses a file whose overall extent is too
        # large, which a single row (about 1,700 studs) was
        obj.location.x = (cell[0] % 12) * 36.0
        obj.location.y = (cell[0] // 12) * 36.0
        cell[0] += 1
        manifest.append({"name": obj.name, "family": family, "triangles": tris, "bounds": [lo, hi], "meta": meta})
        print(f"  {obj.name}: {tris} triangles")

    if "trees" in only:
        import kit_trees

        kit_trees.build_all(emit)
    if "plants" in only:
        import kit_plants

        kit_plants.build_all(emit)
    if "props" in only:
        import kit_props

        kit_props.build_all(emit)
    if "animals" in only:
        import kit_animals

        kit_animals.build_all(emit)

    # previous manifest entries for families not rebuilt this run are kept
    path = os.path.join(out, "manifest.json")
    old = []
    if os.path.exists(path):
        with open(path) as fh:
            old = json.load(fh)
    rebuilt = {m["name"] for m in manifest}
    merged = [m for m in old if m["name"] not in rebuilt and m.get("family_group") not in only] + [
        dict(m, family_group=group_of(m["family"])) for m in manifest
    ]
    with open(path, "w") as fh:
        json.dump(merged, fh, indent=1)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "kit.blend"))
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out, "island-kit.fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=False,
        apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=False,
        mesh_smooth_type="FACE",
    )
    # the same meshes as OBJ, which carries no unit (1 unit = 1 stud in the 3D Importer)
    bpy.ops.wm.obj_export(
        filepath=os.path.join(out, "island-kit.obj"),
        export_selected_objects=True,
        forward_axis="NEGATIVE_Z",
        up_axis="Y",
        export_materials=False,
        export_uv=True,
        export_normals=True,
        export_triangulated_mesh=True,
    )
    # the 3D Importer splits an OBJ by group (g), not by object (o): name a group per object
    obj_path = os.path.join(out, "island-kit.obj")
    with open(obj_path) as fh:
        lines = fh.read().split("\n")
    with open(obj_path, "w") as fh:
        fh.write("\n".join(line + "\ng " + line[2:] if line.startswith("o ") else line for line in lines))
    total = sum(m["triangles"] for m in manifest)
    print(f"built {len(manifest)} meshes, {total} triangles in total")


def group_of(family):
    trees = {"Oak", "Tiered", "Umbrella", "Birch", "Blossom", "Willow", "Fruit", "Pine", "PineSapling", "Bush"}
    if family in trees:
        return "trees"
    return family.split("/")[0]


main()
