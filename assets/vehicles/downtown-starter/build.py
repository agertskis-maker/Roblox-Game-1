"""Build the Downtown Common starter, save the .blend, export the FBX and render
review stills. Run headless (not through the MCP):

    blender -b --factory-startup --python assets/vehicles/downtown-starter/build.py -- --out C:/Users/agert/Documents/Car-Hop-Art/vehicles/downtown-starter

Outputs (outside Git): <out>/downtown-starter.blend, <out>/downtown-starter.fbx,
<out>/renders/*.png and <out>/stats.json.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import carkit  # noqa: E402
from starter_spec import PALETTE, SPEC  # noqa: E402


def parse_out():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.join(HERE, "_out")
    if "--out" in argv:
        out = argv[argv.index("--out") + 1]
    renders = "--no-render" not in argv
    return out, renders


def main():
    out, renders = parse_out()
    os.makedirs(os.path.join(out, "renders"), exist_ok=True)
    carkit.clear_scene()
    mats = carkit.setup_materials(PALETTE)
    car = carkit.build_car(SPEC, mats)
    objects = list(car["parts"].values()) + [o for pair in car["wheels"].values() for o in pair]
    stats = dict(car["stats"])
    stats["parts"] = {o.name: carkit.tri_count(o) for o in objects}
    xs = [(o.matrix_world @ v.co) for o in objects for v in o.data.vertices]
    stats["bounds"] = {
        "length": round(max(p.y for p in xs) - min(p.y for p in xs), 3),
        "width": round(max(p.x for p in xs) - min(p.x for p in xs), 3),
        "height": round(max(p.z for p in xs) - min(p.z for p in xs), 3),
        "min_z": round(min(p.z for p in xs), 3),
    }
    body = car["parts"]["BodyPrimary"]
    bxs = [(body.matrix_world @ v.co) for v in body.data.vertices]
    stats["body_width_no_mirrors"] = round(2 * max(abs(p.x) for p in bxs if p.y > -2.0 or p.z < 2.9), 3)
    with open(os.path.join(out, "stats.json"), "w") as fh:
        json.dump(stats, fh, indent=2)
    print("STATS", json.dumps(stats))

    carkit.export_fbx(os.path.join(out, SPEC["name"] + ".fbx"), objects)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, SPEC["name"] + ".blend"))

    if not renders:
        return
    carkit.ground_plane()
    rd = os.path.join(out, "renders")
    views = {
        "front34": ((-11.0, -15.0, 6.0), (0, -0.5, 1.9), None, 50),
        "rear34": ((11.0, 15.0, 6.5), (0, 0.5, 1.9), None, 50),
        "side": ((40.0, 0.0, 2.4), (0, 0, 2.4), 14.5, None),
        "front": ((0.0, -40.0, 2.4), (0, 0, 2.4), 7.6, None),
        "rear": ((0.0, 40.0, 2.4), (0, 0, 2.4), 7.6, None),
        "top": ((0.0, 0.0, 40.0), (0, 0.001, 0), 14.5, None),
        "chase": ((0.0, 15.5, 7.6), (0, -8.0, 1.6), None, 32),
        "wheel": ((-6.0, -5.4, 1.6), (-2.4, -3.7, 1.1), None, 60),
        "lamps_rear": ((3.5, 9.5, 3.4), (1.2, 6.2, 2.4), None, 55),
    }
    for grey in (False, True):
        carkit.setup_render(1600, 1000, grey=grey)
        for key, (loc, tgt, ortho, lens) in views.items():
            if grey and key not in ("front34", "rear34", "side", "chase"):
                continue
            carkit.camera("Cam", loc, tgt, ortho, lens or 50)
            carkit.render_to(os.path.join(rd, key + ("_grey" if grey else "") + ".png"))


main()
