# Downtown kit B2 build (Lane 3, direction B production start). Headless Blender, no add-ons
# beyond the bundled FBX exporter, no MCP:
#   set PYTHONDONTWRITEBYTECODE=1
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/kit_b2_build.py -- --out C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2 \
#       [--only road,lots,landmarks,street] [--no-fbx]
# Writes, under --out:
#   palette-B2-<District>.png   one 256 x 256 swatch layout, five district colourings
#   swatches.json               index, name, fixed flag, a colour per district (+ "B" = Main Street)
#   meshes/<Name>.json          compact mesh data (the Studio builder's format: name, triangles,
#                               bounds, meta, grid, p, t) with meta.sockets / bounds / lod / district
#                               / pivot_offset / swatches_used
#   manifest.json               every mesh: family, district, lod, triangles, bounds, pivot offset,
#                               sockets, sign faces, replaced overnight modules
#   catalogue.md                the module table for assets/downtown/kit-b/README.md
#   downtown-kit-b2.fbx         ONE batch import package: every mesh a separate, triangulated
#                               object named by its stable name, laid out on a grid, sharing one
#                               material that points at palette-B2-MainStreet.png (embedded)
#   downtown-kit-b2.obj         the same set as OBJ with one group per mesh (importer fallback)
# Art outputs stay outside Git (Car-Hop-Art); these scripts are the recipe.

import json
import os
import sys

import addon_utils
import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_b2_palette as P2  # noqa: E402
import kit_b2lib  # noqa: E402

GROUPS = ["road", "lots", "landmarks", "street"]
SPACING = 260.0
PER_ROW = 16


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out, only, fbx = None, None, True
    for i, a in enumerate(argv):
        if a == "--out":
            out = argv[i + 1]
        if a == "--only":
            only = argv[i + 1].split(",")
        if a == "--no-fbx":
            fbx = False
    if not out:
        raise SystemExit("--out is required")
    return out, only or GROUPS, fbx


def main():
    out, only, want_fbx = parse_args()
    meshes_dir = os.path.join(out, "meshes")
    os.makedirs(meshes_dir, exist_ok=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for d in P2.DISTRICTS:
        P2.write_palette_png(os.path.join(out, f"palette-B2-{P2.FILE_TAG[d]}.png"), d)
    with open(os.path.join(out, "swatches.json"), "w") as fh:
        json.dump({"grid": P2.GRID, "cell_px": P2.CELL, "size_px": P2.SIZE, "districts": {d: P2.DISTRICT_NAMES[d] for d in P2.DISTRICTS}, "swatches": P2.swatch_table()}, fh, indent=1)

    manifest = []
    seen = set()

    def emit(builder, meta):
        name = builder.name
        assert name not in seen, f"duplicate mesh name {name}"
        seen.add(name)
        obj = builder.to_object()
        data = kit_b2lib.export_json(obj, meshes_dir, meta)
        k = len(manifest)
        obj.location.x = (k % PER_ROW) * SPACING
        obj.location.y = -(k // PER_ROW) * SPACING
        m = data["meta"]
        lo, hi = data["bounds"]
        manifest.append(
            {
                "name": name,
                "family": m.get("family", "?"),
                "district": m.get("district", "any"),
                "lod": m.get("lod", "near"),
                "triangles": data["triangles"],
                "bounds": [lo, hi],
                "size": [round(hi[i] - lo[i], 2) for i in range(3)],
                "pivot": m.get("pivot", ""),
                "pivot_offset": m.get("pivot_offset"),
                "sockets": m.get("sockets", {}),
                "faces": [f.get("name") for f in m.get("faces", [])],
                "default_text": m.get("default_text"),
                "replaces": m.get("replaces"),
                "fbx_grid": [round(obj.location.x, 1), round(-obj.location.y, 1)],
            }
        )
        print(f"  {name}: {data['triangles']} triangles")

    if "road" in only:
        import kit_b2_road

        kit_b2_road.build_all(emit)
    if "lots" in only:
        import kit_b2_lots

        kit_b2_lots.build_all(emit)
    if "landmarks" in only:
        import kit_b2_landmarks

        kit_b2_landmarks.build_all(emit)
    if "street" in only:
        import kit_b2_street

        kit_b2_street.build_all(emit)

    # keep entries of groups not rebuilt this run
    path = os.path.join(out, "manifest.json")
    old = []
    if os.path.exists(path) and set(only) != set(GROUPS):
        with open(path) as fh:
            old = json.load(fh).get("meshes", [])
    names = {m["name"] for m in manifest}
    merged = [m for m in old if m["name"] not in names] + manifest
    merged.sort(key=lambda m: (m["family"], m["name"]))
    totals = {}
    for m in merged:
        t = totals.setdefault(m["family"], {"meshes": 0, "triangles": 0})
        t["meshes"] += 1
        t["triangles"] += m["triangles"]
    with open(path, "w") as fh:
        json.dump({"kit": "Downtown B2 (direction B, production start)", "palette_layout": "kit_b2_palette.py", "palettes": [f"palette-B2-{P2.FILE_TAG[d]}.png" for d in P2.DISTRICTS], "totals": totals, "meshes": merged}, fh, indent=1)
    write_catalogue(os.path.join(out, "catalogue.md"), merged)

    if manifest:
        export_packages(out, want_fbx)
    total = sum(m["triangles"] for m in manifest)
    print(f"built {len(manifest)} meshes, {total} triangles in total")
    for fam, t in sorted(totals.items()):
        print(f"  {fam}: {t['meshes']} meshes, {t['triangles']} triangles")


def write_catalogue(path, meshes):
    lines = ["| Name | Family | District | LOD | Tris | Size (x y z) | Sockets |", "|---|---|---|---|---|---|---|"]
    for m in meshes:
        sz = " x ".join(f"{v:g}" for v in m["size"])
        sk = ", ".join(sorted(m["sockets"].keys())) if isinstance(m["sockets"], dict) else ""
        lines.append(f"| `{m['name']}` | {m['family']} | {m['district']} | {m['lod']} | {m['triangles']} | {sz} | {sk} |")
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def export_packages(out, want_fbx):
    """One batch import package: every mesh a separate triangulated object on a grid, one shared
    material with the Main Street palette (the other districts swap TextureID in Studio)."""
    img = bpy.data.images.load(os.path.join(out, "palette-B2-MainStreet.png"))
    mat = bpy.data.materials.new("B2_Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
        o.data.materials.clear()
        o.data.materials.append(mat)
        o.select_set(True)
    if want_fbx:
        addon_utils.enable("io_scene_fbx", default_set=True)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(out, "downtown-kit-b2.fbx"),
            use_selection=True,
            object_types={"MESH"},
            axis_forward="-Z",
            axis_up="Y",
            global_scale=1.0,
            apply_unit_scale=True,
            mesh_smooth_type="FACE",
            use_mesh_modifiers=False,
            path_mode="COPY",
            embed_textures=True,
        )
    obj_path = os.path.join(out, "downtown-kit-b2.obj")
    bpy.ops.wm.obj_export(filepath=obj_path, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False, export_uv=True, export_normals=True, export_triangulated_mesh=True)
    # the 3D Importer splits an OBJ by group (g), not by object (o): name a group per object
    with open(obj_path) as fh:
        lines = fh.read().split("\n")
    with open(obj_path, "w") as fh:
        fh.write("\n".join(line + "\ng " + line[2:] if line.startswith("o ") else line for line in lines))


main()
