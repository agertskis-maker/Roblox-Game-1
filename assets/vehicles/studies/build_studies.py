"""Rough comparison studies (not finished cars): three starter architectures
(A, B, C) and five rarity-tier studies, all at the same provisional scale
(1 stud = 0.28 m). Run headless:

    blender -b --factory-startup --python assets/vehicles/studies/build_studies.py -- --out C:/Users/agert/Documents/Car-Hop-Art/vehicles/studies

Saves <out>/studies.blend and <out>/studies.json. Every object carries a
"base" custom property (its built location) and a "study" property, so the
review render script can arrange the cars side by side or nose to tail.
"""

import copy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "downtown-starter"))

import bpy  # noqa: E402

import carkit  # noqa: E402
from starter_spec import PALETTE as STARTER_PALETTE  # noqa: E402
from starter_spec import SPEC as STARTER  # noqa: E402


def seam(y, z, h):
    return {"side": "sides", "at": (y, z), "size": (0.022, h), "n": 8.0, "role": "Trim", "offset": 0.02, "segs": 12}


def lamps(front_x, front_z, front_a, front_b, rear_x, rear_z, rear_a, rear_b, n=3.4):
    return [
        {"side": "front", "at": (front_x, front_z), "size": (front_a + 0.05, front_b + 0.045), "n": n, "skew": 0.1, "taper": 0.15, "role": "Trim", "offset": 0.015, "mirror": True, "rings": 2},
        {"side": "front", "at": (front_x, front_z), "size": (front_a, front_b), "n": n, "skew": 0.09, "taper": 0.15, "role": "Headlamp", "offset": 0.03, "mirror": True, "rings": 2},
        {"side": "rear", "at": (rear_x, rear_z), "size": (rear_a + 0.05, rear_b + 0.05), "n": 4.0, "role": "Trim", "offset": 0.015, "mirror": True, "rings": 2},
        {"side": "rear", "at": (rear_x, rear_z), "size": (rear_a, rear_b), "n": 4.0, "role": "Taillamp", "offset": 0.03, "mirror": True, "rings": 2},
    ]


def study_a():
    """A: tall-roof five-door, cabin forward, upright hatch."""
    s = copy.deepcopy(STARTER)
    s["name"] = "study-a"
    s["body_top"] = [(-6.2, 1.95), (-6.1, 2.2), (-5.9, 2.5), (-5.5, 2.72), (-4.6, 2.9), (-3.6, 3.04), (0.0, 3.1), (4.5, 3.2), (5.75, 3.2), (6.0, 3.0), (6.2, 2.6)]
    s["cabin_y"] = [-3.55, -3.2, -1.7, -1.2, 0.55, 0.95, 3.25, 3.55, 4.6, 5.0, 5.75, 5.85]
    s["roof_z"] = [(-3.55, 3.08), (-3.2, 3.42), (-1.7, 4.80), (-1.2, 4.86), (3.0, 4.86), (4.7, 4.80), (5.0, 4.70), (5.75, 3.32), (5.85, 3.26)]
    s["roof_hw"] = [(-3.55, 2.32), (-1.7, 2.14), (1.0, 2.16), (4.6, 2.14), (5.75, 2.24), (5.85, 2.28)]
    s["side_glass"] = [(-3.1, 0.55), (0.95, 3.25), (3.55, 4.55)]
    s["top_glass"] = [(-3.5, -1.75), (4.95, 5.72)]
    s["fender_bumps"] = [(STARTER["axles"][0], 0.06, 1.9), (STARTER["axles"][1], 0.07, 2.0)]
    s["decals"] = [d for d in STARTER["decals"] if d["side"] != "sides"] + [
        seam(-3.0, 2.2, 0.75), seam(0.75, 2.0, 0.92), seam(3.35, 2.1, 0.85)]
    s["boxes"] = [((2.63, -3.0, 3.18), (0.40, 0.24, 0.26), "BodyPrimary", 0.06, True)]
    return s, dict(STARTER_PALETTE)


def study_c():
    """C: rounded two-box city car, one-arc roof."""
    s = copy.deepcopy(STARTER)
    s["name"] = "study-c"
    s.update({"top_edge": 0.32, "hood_crown": 0.16, "roof_crown": 0.16, "shoulder_in": 0.12, "belly_frac": 0.46})
    s["body_top"] = [(-6.2, 1.8), (-6.1, 2.05), (-5.9, 2.32), (-5.5, 2.55), (-4.5, 2.75), (-3.3, 2.9), (0.0, 2.98), (4.6, 3.05), (5.6, 3.0), (5.95, 2.8), (6.2, 2.4)]
    s["body_hw"] = [(-6.2, 1.9), (-6.1, 2.2), (-5.9, 2.42), (-5.5, 2.56), (-4.8, 2.64), (-3.7, 2.67), (0.0, 2.67), (4.24, 2.68), (5.3, 2.62), (5.8, 2.48), (6.05, 2.3), (6.2, 2.05)]
    s["cabin_y"] = [-3.3, -3.0, -1.5, -0.5, 0.5, 1.5, 1.9, 3.0, 4.2, 5.2, 5.55]
    s["roof_z"] = [(-3.3, 2.98), (-3.0, 3.25), (-1.5, 4.25), (-0.5, 4.6), (0.5, 4.68), (1.5, 4.62), (3.0, 4.36), (4.2, 3.96), (5.2, 3.42), (5.55, 3.15)]
    s["roof_hw"] = [(-3.3, 2.2), (-1.5, 1.98), (0.5, 1.95), (3.0, 1.95), (4.2, 1.98), (5.55, 2.15)]
    s["side_glass"] = [(-2.9, 1.5), (1.9, 3.9)]
    s["top_glass"] = [(-3.25, -0.9), (4.1, 5.5)]
    s["decals"] = [d for d in STARTER["decals"] if d["side"] != "sides"] + [seam(-2.75, 2.15, 0.72), seam(1.7, 2.0, 0.9)]
    s["boxes"] = [((2.6, -2.75, 3.1), (0.40, 0.24, 0.26), "BodyPrimary", 0.07, True)]
    return s, dict(STARTER_PALETTE)


def tier_uncommon():
    """Uncommon: modern compact pickup with one coordinated stripe."""
    s = copy.deepcopy(STARTER)
    s.update({
        "name": "tier-uncommon", "length": 15.8, "width": 6.4, "axles": [-4.6, 4.5], "tire_r": 1.33, "tire_w": 0.86,
        "track_x": 2.68, "arch_r": 1.52, "arch_z": 1.42, "spokes": 6, "top_edge": 0.16, "hood_crown": 0.07, "shoulder_in": 0.05,
        "body_y": [-7.9, -7.8, -7.55, -7.0, -4.6, -2.6, 0.0, 2.0, 4.5, 7.4, 7.8, 7.9],
        "body_top": [(-7.9, 2.6), (-7.75, 3.05), (-7.4, 3.3), (-6.5, 3.42), (-2.6, 3.62), (2.0, 3.7), (7.6, 3.72), (7.9, 3.6)],
        "body_bottom": [(-7.9, 1.25), (-7.4, 1.05), (7.4, 1.05), (7.9, 1.25)],
        "body_hw": [(-7.9, 2.6), (-7.75, 2.92), (-7.4, 3.05), (-6.5, 3.08), (7.4, 3.08), (7.75, 3.0), (7.9, 2.85)],
        "fender_bumps": [(-4.6, 0.12, 2.1), (4.5, 0.12, 2.1)],
        "cabin_y": [-2.6, -2.25, -0.9, -0.5, 1.9, 2.0],
        "roof_z": [(-2.6, 3.62), (-2.25, 3.95), (-0.9, 5.95), (-0.5, 6.0), (1.9, 5.98), (2.0, 3.66)],
        "roof_hw": [(-2.6, 2.7), (-0.9, 2.5), (1.9, 2.5), (2.0, 2.6)],
        "side_glass": [(-2.2, -0.1), (0.25, 1.75)], "top_glass": [(-2.55, -0.95)],
        "cut_boxes": [((0.0, 4.95, 4.45), (5.6, 5.5, 1.7))],
    })
    s["decals"] = lamps(2.05, 2.95, 0.68, 0.22, 2.35, 2.95, 0.30, 0.42) + [
        {"side": "sides", "at": (0.0, 2.55), "size": (6.6, 0.11), "n": 8.0, "role": "BodySecondary", "offset": 0.02, "segs": 16},
        {"side": "front", "at": (0.0, 2.35), "size": (1.25, 0.45), "n": 5.0, "role": "Trim", "offset": 0.02, "rings": 2},
    ]
    s["boxes"] = [((3.0, -2.2, 3.95), (0.45, 0.26, 0.32), "BodyPrimary", 0.06, True)]
    pal = dict(STARTER_PALETTE)
    pal.update({"BodyPrimary": "#E8B33A", "BodySecondary": "#242A32", "WheelMetal": "#59616D"})
    return s, pal


def tier_rare():
    """Rare: 1990s-style rally sport sedan (our own shapes, wing and scoop)."""
    s = copy.deepcopy(STARTER)
    s.update({
        "name": "tier-rare", "length": 15.4, "width": 6.2, "axles": [-4.3, 4.7], "tire_r": 1.16, "tire_w": 0.84,
        "track_x": 2.55, "arch_r": 1.33, "arch_z": 1.22, "spokes": 6, "top_edge": 0.16,
        "body_y": [-7.7, -7.6, -7.4, -6.9, -4.3, -2.7, 0.0, 3.4, 4.7, 6.8, 7.4, 7.6, 7.7],
        "body_top": [(-7.7, 1.75), (-7.55, 2.05), (-7.2, 2.35), (-6.4, 2.55), (-4.3, 2.75), (-2.7, 2.9), (0.0, 2.98), (3.6, 3.12), (6.9, 3.22), (7.45, 3.05), (7.7, 2.6)],
        "body_bottom": [(-7.7, 0.82), (-7.3, 0.58), (7.2, 0.58), (7.7, 0.85)],
        "body_hw": [(-7.7, 2.3), (-7.55, 2.62), (-7.2, 2.8), (-6.4, 2.88), (7.0, 2.88), (7.45, 2.78), (7.7, 2.5)],
        "fender_bumps": [(-4.3, 0.22, 2.0), (4.7, 0.25, 2.1)],
        "cabin_y": [-2.75, -2.4, -0.8, -0.3, 1.0, 1.3, 2.5, 2.9, 4.2, 4.4],
        "roof_z": [(-2.75, 2.95), (-2.4, 3.3), (-0.8, 4.5), (-0.3, 4.55), (2.5, 4.5), (2.9, 4.42), (4.2, 3.32), (4.4, 3.16)],
        "roof_hw": [(-2.75, 2.45), (-0.8, 2.12), (2.5, 2.1), (4.2, 2.35), (4.4, 2.4)],
        "side_glass": [(-2.35, 1.0), (1.3, 2.75)], "top_glass": [(-2.7, -0.85), (2.95, 4.15)],
    })
    s["decals"] = lamps(1.9, 2.18, 0.66, 0.2, 1.95, 2.72, 0.62, 0.2) + [
        {"side": "front", "at": (0.0, 1.35), "size": (1.6, 0.3), "n": 4.0, "role": "Trim", "offset": 0.02, "rings": 2},
        {"side": "sides", "at": (0.6, 1.45), "size": (4.6, 0.16), "n": 8.0, "role": "BodySecondary", "offset": 0.02, "segs": 16},
        {"side": "sides", "at": (0.6, 1.75), "size": (4.6, 0.05), "n": 8.0, "role": "BodySecondary", "offset": 0.02, "segs": 16},
    ]
    s["boxes"] = [
        ((0.0, -4.3, 3.0), (1.5, 1.4, 0.22), "BodyPrimary", 0.08, False),  # hood scoop
        ((0.0, -4.95, 3.02), (1.2, 0.08, 0.14), "Trim", 0.0, False),  # scoop mouth
        ((2.1, 6.95, 3.6), (0.12, 0.45, 0.75), "BodyPrimary", 0.03, True),  # wing stalks
        ((0.0, 7.05, 4.0), (5.3, 0.85, 0.12), "BodyPrimary", 0.04, False),  # wing blade
        ((2.62, -2.4, 3.12), (0.40, 0.24, 0.26), "BodyPrimary", 0.06, True),
    ]
    pal = dict(STARTER_PALETTE)
    pal.update({"BodyPrimary": "#1E56C8", "BodySecondary": "#F4F6F8", "WheelMetal": "#E8ECEF"})
    return s, pal


def tier_epic():
    """Epic: mid-engine supercar wedge with a forward canopy."""
    s = copy.deepcopy(STARTER)
    s.update({
        "name": "tier-epic", "length": 16.0, "width": 7.0, "axles": [-4.75, 4.55], "tire_r": 1.24, "tire_w": 1.0,
        "track_x": 2.86, "arch_r": 1.38, "arch_z": 1.28, "spokes": 5, "top_edge": 0.14, "hood_crown": 0.05,
        "spoke_hub_width": 0.15, "spoke_lip_width": 0.11,
        "body_y": [-8.0, -7.9, -7.6, -6.8, -4.75, -2.5, 0.0, 2.5, 4.55, 7.0, 7.7, 7.9, 8.0],
        "body_top": [(-8.0, 1.25), (-7.85, 1.45), (-7.4, 1.62), (-6.0, 1.85), (-4.75, 2.05), (-2.5, 2.45), (0.0, 2.55), (2.5, 2.62), (4.55, 2.75), (7.0, 2.85), (7.7, 2.8), (8.0, 2.55)],
        "body_bottom": [(-8.0, 0.6), (-7.5, 0.42), (7.5, 0.42), (8.0, 0.75)],
        "body_hw": [(-8.0, 2.5), (-7.85, 2.85), (-7.4, 3.05), (-6.0, 3.15), (0.0, 3.05), (4.55, 3.2), (7.6, 3.2), (7.9, 3.05), (8.0, 2.8)],
        "fender_bumps": [(-4.75, 0.2, 2.0), (4.55, 0.32, 2.3)],
        "cabin_y": [-2.55, -2.2, -0.4, 0.2, 1.2, 1.6, 3.6, 4.8],
        "roof_z": [(-2.55, 2.42), (-2.2, 2.75), (-0.4, 3.85), (0.2, 3.95), (1.2, 3.92), (1.6, 3.85), (3.6, 3.1), (4.8, 2.72)],
        "roof_hw": [(-2.55, 2.5), (-0.4, 1.95), (1.2, 1.9), (3.6, 2.1), (4.8, 2.4)],
        "side_glass": [(-2.1, 1.25)], "top_glass": [(-2.5, -0.45), (1.65, 3.5)],
    })
    s["decals"] = lamps(2.3, 1.62, 0.6, 0.12, 2.3, 2.45, 0.6, 0.12, n=5.0) + [
        {"side": "sides", "at": (2.6, 1.75), "size": (0.9, 0.42), "n": 3.0, "taper": 0.4, "role": "Trim", "offset": 0.02, "rings": 2},
        {"side": "front", "at": (0.0, 0.95), "size": (2.4, 0.22), "n": 5.0, "role": "Trim", "offset": 0.02, "rings": 2},
        {"side": "rear", "at": (0.0, 1.15), "size": (2.6, 0.35), "n": 5.0, "role": "Trim", "offset": 0.02, "rings": 2},
    ]
    s["boxes"] = [((2.85, -1.9, 2.75), (0.38, 0.22, 0.22), "BodyPrimary", 0.05, True)]
    pal = dict(STARTER_PALETTE)
    pal.update({"BodyPrimary": "#8BCB2C", "WheelMetal": "#2E343C"})
    return s, pal


def tier_legendary():
    """Legendary: hypercar with a teardrop canopy and one dorsal spine."""
    s = copy.deepcopy(STARTER)
    s.update({
        "name": "tier-legendary", "length": 17.0, "width": 7.4, "axles": [-5.0, 4.9], "tire_r": 1.32, "tire_w": 1.08,
        "track_x": 3.02, "arch_r": 1.46, "arch_z": 1.36, "spokes": 10, "top_edge": 0.12, "hood_crown": 0.04,
        "spoke_hub_width": 0.07, "spoke_lip_width": 0.08,
        "body_y": [-8.5, -8.4, -8.1, -7.2, -5.0, -2.6, 0.0, 2.6, 4.9, 7.4, 8.2, 8.4, 8.5],
        "body_top": [(-8.5, 1.05), (-8.35, 1.3), (-7.9, 1.5), (-6.4, 1.7), (-5.0, 1.95), (-2.6, 2.2), (0.0, 2.3), (2.6, 2.45), (4.9, 2.65), (7.4, 2.75), (8.2, 2.6), (8.5, 2.3)],
        "body_bottom": [(-8.5, 0.45), (-8.0, 0.32), (8.0, 0.32), (8.5, 0.6)],
        "body_hw": [(-8.5, 2.6), (-8.35, 3.0), (-7.9, 3.25), (-6.4, 3.3), (0.0, 3.05), (4.9, 3.35), (8.0, 3.4), (8.4, 3.2), (8.5, 2.95)],
        "fender_bumps": [(-5.0, 0.32, 2.2), (4.9, 0.36, 2.5)],
        "cabin_y": [-2.7, -2.3, -0.4, 0.6, 1.6, 3.2, 4.6],
        "roof_z": [(-2.7, 2.18), (-2.3, 2.55), (-0.4, 3.68), (0.6, 3.82), (1.6, 3.72), (3.2, 3.15), (4.6, 2.6)],
        "roof_hw": [(-2.7, 2.3), (-0.4, 1.55), (0.6, 1.45), (1.6, 1.45), (3.2, 1.6), (4.6, 1.9)],
        "side_glass": [(-2.2, 2.9)], "top_glass": [(-2.65, 3.05)],
        "roof_role": "Glass",
    })
    s["decals"] = lamps(2.55, 1.4, 0.55, 0.07, 0.0, 2.35, 2.9, 0.06, n=6.0) + [
        {"side": "sides", "at": (2.2, 1.45), "size": (1.5, 0.5), "n": 3.0, "taper": 0.5, "role": "Trim", "offset": 0.02, "rings": 2},
        {"side": "rear", "at": (0.0, 1.0), "size": (3.0, 0.42), "n": 5.0, "role": "Trim", "offset": 0.02, "rings": 2},
        {"side": "front", "at": (0.0, 0.75), "size": (2.8, 0.16), "n": 5.0, "role": "Trim", "offset": 0.02, "rings": 2},
    ]
    s["boxes"] = [
        ((0.0, 5.6, 3.15), (0.14, 5.0, 0.9), "BodyPrimary", 0.04, False),  # dorsal spine, the one big idea
        ((2.9, -2.0, 2.5), (0.36, 0.22, 0.2), "BodyPrimary", 0.05, True),
    ]
    pal = dict(STARTER_PALETTE)
    pal.update({"BodyPrimary": "#EEF1F5", "Glass": "#161D29", "WheelMetal": "#BFC6CF", "Trim": "#1C2128"})
    return s, pal


STUDIES = [
    ("A", study_a), ("B", lambda: (copy.deepcopy(STARTER), dict(STARTER_PALETTE))), ("C", study_c),
    ("T2", tier_uncommon), ("T3", tier_rare), ("T4", tier_epic), ("T5", tier_legendary),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(HERE, "_out")
    os.makedirs(out, exist_ok=True)
    carkit.clear_scene()
    report = {}
    for key, make in STUDIES:
        spec, palette = make()
        mats = {}
        for role in carkit.ROLE_ORDER:
            mat = bpy.data.materials.new(key + "_Role_" + role)
            mat.diffuse_color = carkit.hex_rgba(palette.get(role, "#808080"))
            mats[role] = mat
        # Material names must start with Role_ for the kit; use per-study copies.
        for role, mat in mats.items():
            mat.name = "Role_" + role + "." + key
        car = carkit.build_car(spec, mats, prefix=key + "_")
        objs = list(car["parts"].values()) + [o for pair in car["wheels"].values() for o in pair]
        for o in objs:
            o["study"] = key
            o["base"] = list(o.location)
        report[key] = {"name": spec["name"], "triangles": car["stats"]["triangles"], "objects": car["stats"]["objects"],
                       "length": spec["length"], "width": spec["width"]}
        print("STATS", key, json.dumps(report[key]))
    with open(os.path.join(out, "studies.json"), "w") as fh:
        json.dump(report, fh, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "studies.blend"))


main()
