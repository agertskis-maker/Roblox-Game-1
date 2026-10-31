# World kits V2: Blender review sheets (NOT Roblox pixels) for the mesh JSON a kit build wrote. Headless, no add-ons, no MCP:
#   set PYTHONDONTWRITEBYTECODE=1
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/kit_world2_gallery.py -- --kit <kit folder with meshes/ and palette-DH.png|palette-SU.png> \
#       --world dusty|summit --prefix DH_Mid_ [--names DH_A,DH_B] --out <folder> [--samples 8] [--per 6]
# For each selected mesh it renders two tiles (a front-left three-quarter view and a back-right one, so the backs and the
# undersides a chase camera can reach are checked too) with a Puglet-sized proxy car beside it for scale (omitted above 150
# studs) on a flat ground, and writes contact sheets gallery-<tag>-NN.png (up to --per meshes each, 4 tiles across).
# The picture is a Blender render with the World's palette: it shows form, colour and finish, not Roblox lighting.

import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import render as R  # noqa: E402

TILE = (480, 360)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    a = {"samples": 8, "per": 6, "prefix": "", "names": None}
    for i, k in enumerate(argv):
        if k in ("--kit", "--world", "--prefix", "--out"):
            a[k[2:]] = argv[i + 1]
        elif k == "--names":
            a["names"] = argv[i + 1].split(",")
        elif k in ("--samples", "--per"):
            a[k[2:]] = int(argv[i + 1])
    for need in ("kit", "world", "out"):
        if need not in a:
            raise SystemExit(f"--{need} is required")
    return a


def render_tile(sc, cam, eye, target, note, path):
    R.aim(cam, eye, target)
    sc.render.stamp_note_text = note
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    arr = np.empty(TILE[0] * TILE[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return arr.reshape(TILE[1], TILE[0], 4)


def main():
    a = parse_args()
    tag = "DH" if a["world"] == "dusty" else "SU"
    kit, out = a["kit"], a["out"]
    os.makedirs(out, exist_ok=True)
    mesh_dir = os.path.join(kit, "meshes")
    names = a["names"] or sorted(f[:-5] for f in os.listdir(mesh_dir) if f.endswith(".json") and f.startswith(a["prefix"]))
    if not names:
        raise SystemExit("no meshes selected")
    R.clear()
    R.world_setup()
    R.sun_setup()
    img = bpy.data.images.load(os.path.join(kit, f"palette-{tag}.png"))
    img.colorspace_settings.name = "sRGB"
    pal = R.material("WorldPalette", img, rough=0.75, spec=0.2, haze=False)
    ground_rgb = (226, 188, 138) if tag == "DH" else (236, 243, 250)
    gmat = R.material("Ground", None, rough=0.9, haze=False, rgba=R.srgb_to_lin(ground_rgb))
    R.setup_render("eevee", a["samples"], TILE, "")
    sc = bpy.context.scene
    camd = bpy.data.cameras.new("Cam")
    camd.lens = 32
    cam = bpy.data.objects.new("Cam", camd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    car = R.proxy_car()
    sheets = []
    batch = []
    page = 0
    tmp = os.path.join(out, "_tile.png")
    for name in names:
        me, d = R.load_mesh(os.path.join(mesh_dir, name + ".json"))
        me.materials.append(pal)
        obj = bpy.data.objects.new(name, me)
        sc.collection.objects.link(obj)
        lo, hi = d["bounds"]
        c = [(lo[i] + hi[i]) / 2 for i in range(3)]
        ext = [hi[i] - lo[i] for i in range(3)]
        radius = max(max(ext) * 0.62, 6.0)
        gsize = max(ext[0], ext[2], 40.0) * 3.0
        gme = R.box_mesh("G_" + name, (gsize, gsize, 1.0), (c[0], -c[2], -0.5))
        gme.materials.append(gmat)
        gobj = bpy.data.objects.new("G_" + name, gme)
        sc.collection.objects.link(gobj)
        show_car = max(ext) <= 150.0
        car.hide_render = not show_car
        if show_car:
            car.location = R.B((lo[0] - 9.0, 2.36, c[2]))
            car.rotation_euler = (0, 0, math.radians(90))
        dist = radius * 2.6
        tiles = []
        for sgn, label in ((-1, "front-left"), (1, "back-right")):
            eye = (c[0] - sgn * dist * 0.62, c[1] + radius * 0.55, c[2] - sgn * dist * 0.78)
            note = f"{name}  {d['triangles']} tris  {ext[0]:.0f} x {ext[1]:.0f} x {ext[2]:.0f}  ({label})"
            tiles.append(render_tile(sc, cam, eye, (c[0], c[1] - radius * 0.1, c[2]), note, tmp))
        batch.append(np.concatenate(tiles, axis=1))  # one cell: the two views of one mesh, 960 x 360
        for o in (obj, gobj):
            bpy.data.objects.remove(o, do_unlink=True)
        if len(batch) == a["per"]:
            sheets.append(batch)
            batch = []
    if batch:
        sheets.append(batch)
    for i, cells in enumerate(sheets):
        cells = cells + [np.zeros_like(cells[0])] * (a["per"] - len(cells))
        cols = 2
        rows = [np.concatenate(cells[k : k + cols] + [np.zeros_like(cells[0])] * (cols - len(cells[k : k + cols])), axis=1) for k in range(0, len(cells), cols)]
        page = np.concatenate(rows[::-1], axis=0)  # Blender images start at the bottom row
        im = bpy.data.images.new(f"sheet{i}", page.shape[1], page.shape[0], alpha=True)
        im.pixels.foreach_set(page.reshape(-1))
        path = os.path.join(out, f"gallery-{tag}-{i + 1:02d}.png")
        im.filepath_raw = path
        im.file_format = "PNG"
        im.save()
        print("wrote", path)
    if os.path.exists(tmp):
        os.remove(tmp)


main()
