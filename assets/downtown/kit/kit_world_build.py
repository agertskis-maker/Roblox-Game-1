# World kits build (Lane 3, Round 2): Dusty Highway (DH_*) and Summit Pass (SP_*). Headless Blender, no add-ons beyond the
# bundled FBX exporter, no MCP, safe mode (no network, no scripts from files other than this repo's):
#   set PYTHONDONTWRITEBYTECODE=1
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/kit_world_build.py -- --out C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-worlds \
#       [--only dusty,summit] [--no-fbx]
# Writes, under --out:
#   palette-DH.png, palette-SU.png   the two World palettes (one 16 x 16 swatch layout; the shared road cells keep
#                                    their B2 indices and take per-World colours)
#   swatches.json                    index, name, fixed flag and a colour per World (columns DH, SU)
#   meshes/<Name>.json               compact mesh data (the B2 format) for every DH_* and SP_* mesh
#   manifest.json, catalogue.md      every mesh: family, world, triangles, bounds, size, sockets
#   worlds-<World>.fbx / .obj        ONE batch import package per World (every mesh a separate triangulated object on a
#                                    grid, one material pointing at that World's palette). PREPARED, NOT UPLOADED: the
#                                    Dusty Highway and Summit Pass kits have no upload authority yet
# Art outputs stay outside Git (Car-Hop-Art); these scripts are the recipe.

import json
import os
import sys

import addon_utils
import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_world_lib as L  # noqa: E402
import kit_world_palette as W  # noqa: E402

GROUPS = ["dusty", "summit"]
PREFIX = {"dusty": "DH_", "summit": "SP_"}
WORLD_OF = {"dusty": "DH", "summit": "SU"}
SPACING = 140.0
PER_ROW = 14


# V2: --keep <file> (one mesh name per line) limits the manifest and the upload packages to the meshes the Worlds actually use
KEEP = {"file": None}


def keep_names():
    if not KEEP["file"]:
        return None
    with open(KEEP["file"]) as fh:
        return {line.strip() for line in fh if line.strip()}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out, only, fbx = None, None, True
    for i, a in enumerate(argv):
        if a == "--keep":
            KEEP["file"] = argv[i + 1]
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
    for w in W.WORLDS:
        W.write_palette_png(os.path.join(out, f"palette-{w}.png"), w)
    with open(os.path.join(out, "swatches.json"), "w") as fh:
        json.dump({"grid": W.GRID, "cell_px": W.CELL, "size_px": W.SIZE, "worlds": W.WORLD_NAMES, "swatches": W.swatch_table()}, fh, indent=1)

    manifest = []
    seen = set()
    row = {"dusty": 0, "summit": 0}
    group = {"g": None, "v2": False}
    # V2 build (--v2 / KIT_WORLD_V2=1): the v2 recipe modules add meshes, and may retire Round 2 meshes they supersede
    # (DROP_OLD) or redraw under the same name (REPLACES); the Round 2 recipe is then skipped for those names.
    v2mods = {}
    skip = set()
    if W.V2:
        import importlib

        for g, modname in (("dusty", "kit_dusty2"), ("summit", "kit_summit2")):
            if g in only:
                try:
                    v2mods[g] = importlib.import_module(modname)
                except ImportError:
                    continue
                skip |= set(getattr(v2mods[g], "DROP_OLD", ())) | set(getattr(v2mods[g], "REPLACES", ()))

    def emit(builder, meta):
        name = builder.name
        if name in skip and not group["v2"]:
            return
        assert name not in seen, f"duplicate mesh name {name}"
        assert name.startswith(PREFIX[group["g"]]), f"{name} does not start with {PREFIX[group['g']]}"
        seen.add(name)
        obj = builder.to_object()
        data = L.export_json(obj, meshes_dir, meta)
        k = row[group["g"]]
        row[group["g"]] += 1
        obj.location.x = (k % PER_ROW) * SPACING
        obj.location.y = -(k // PER_ROW) * SPACING
        m = data["meta"]
        lo, hi = data["bounds"]
        manifest.append(
            {
                "name": name,
                "world": WORLD_OF[group["g"]],
                "family": m.get("family", "?"),
                "district": m.get("district", "any"),
                "lod": m.get("lod", "near"),
                "triangles": data["triangles"],
                "bounds": [lo, hi],
                "size": [round(hi[i] - lo[i], 2) for i in range(3)],
                "pivot_offset": m.get("pivot_offset"),
                "sockets": m.get("sockets", {}),
                "swatches_used": m.get("swatches_used", []),
            }
        )
        print(f"  {name}: {data['triangles']} triangles")

    if "dusty" in only:
        group["g"] = "dusty"
        import kit_dusty

        kit_dusty.build_all(emit)
        if "dusty" in v2mods:
            group["v2"] = True
            v2mods["dusty"].build_all(emit)
            group["v2"] = False
    if "summit" in only:
        group["g"] = "summit"
        import kit_summit

        kit_summit.build_all(emit)
        if "summit" in v2mods:
            group["v2"] = True
            v2mods["summit"].build_all(emit)
            group["v2"] = False

    # keep entries of groups not rebuilt this run
    path = os.path.join(out, "manifest.json")
    old = []
    if os.path.exists(path) and set(only) != set(GROUPS):
        with open(path) as fh:
            old = json.load(fh).get("meshes", [])
    names = {m["name"] for m in manifest}
    merged = [m for m in old if m["name"] not in names] + manifest
    keep = keep_names()
    if keep is not None:
        merged = [m for m in merged if m["name"] in keep]
        for o in list(bpy.data.objects):
            if o.type == "MESH" and o.name not in keep:
                bpy.data.objects.remove(o, do_unlink=True)
    merged.sort(key=lambda m: (m["world"], m["family"], m["name"]))
    totals = {}
    for m in merged:
        t = totals.setdefault(f"{m['world']}/{m['family']}", {"meshes": 0, "triangles": 0})
        t["meshes"] += 1
        t["triangles"] += m["triangles"]
    with open(path, "w") as fh:
        json.dump({"kit": "World kits: Dusty Highway (DH), Summit Pass (SP)", "palette_layout": "kit_world_palette.py", "totals": totals, "meshes": merged}, fh, indent=1)
    write_catalogue(os.path.join(out, "catalogue.md"), merged)

    for g in only:
        export_package(out, g, want_fbx)
    print(f"built {len(manifest)} meshes, {sum(m['triangles'] for m in manifest)} triangles in total")
    for key, t in sorted(totals.items()):
        print(f"  {key}: {t['meshes']} meshes, {t['triangles']} triangles")


def write_catalogue(path, meshes):
    lines = ["| Name | World | Family | LOD | Tris | Size (x y z) | Sockets |", "|---|---|---|---|---|---|---|"]
    for m in meshes:
        sz = " x ".join(f"{v:g}" for v in m["size"])
        sk = ", ".join(sorted(m["sockets"].keys())) if isinstance(m["sockets"], dict) else ""
        lines.append(f"| `{m['name']}` | {m['world']} | {m['family']} | {m['lod']} | {m['triangles']} | {sz} | {sk} |")
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def export_package(out, g, want_fbx):
    """One batch import package for a World: its meshes only, triangulated, one material with its palette."""
    world, prefix = WORLD_OF[g], PREFIX[g]
    img = bpy.data.images.load(os.path.join(out, f"palette-{world}.png"))
    mat = bpy.data.materials.new(f"{prefix}Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or not o.name.startswith(prefix):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
        o.data.materials.clear()
        o.data.materials.append(mat)
        o.select_set(True)
    tag = W.FILE_TAG[world]
    if want_fbx:
        addon_utils.enable("io_scene_fbx", default_set=True)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(out, f"worlds-{tag}.fbx"),
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
    obj_path = os.path.join(out, f"worlds-{tag}.obj")
    bpy.ops.wm.obj_export(filepath=obj_path, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False, export_uv=True, export_normals=True, export_triangulated_mesh=True)
    with open(obj_path) as fh:
        lines = fh.read().split("\n")
    with open(obj_path, "w") as fh:
        fh.write("\n".join(line + "\ng " + line[2:] if line.startswith("o ") else line for line in lines))


main()
