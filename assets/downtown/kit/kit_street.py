# Downtown kit: street furniture, shared by directions A, B and C (the palette tints poles,
# planters and bins per direction). Pivot at the bottom centre, on the surface it stands on;
# "front" is local -Z (face it toward the road with fixture.yaw_facing_road). Sizes follow the
# research scale cues (0.28 m per stud): lamp 20, hydrant 2.8, bollard 3.5, bench seat 1.6.
# Glowing pieces (lamp lenses) are separate meshes so placement can give them Neon.

import math
import random

from kitlib import Builder, V, box, cyl, prism, rounded_rect2, sphere, tube


def seed_of(name):
    return sum(map(ord, name)) * 13 + len(name)


def lamp(name):
    """A 20-stud street lamp: plinth, tapered pole, a swan-neck arm reaching 4 toward the road
    (front, -Z) and a rounded hood. The lens is LampLens."""
    b = Builder(name)
    cyl(b, V(0, 0, 0), 1.2, 0.75, 8, "furn_metal_dark", r_top=0.6)
    cyl(b, V(0, 1.2, 0), 0.3, 0.6, 8, "furn_metal", r_top=0.42)
    cyl(b, V(0, 1.5, 0), 16.0, 0.3, 8, "furn_metal", r_top=0.22)
    # collar and swan neck
    cyl(b, V(0, 9.0, 0), 0.5, 0.36, 8, "furn_metal_dark")
    path = [V(0, 17.4, 0), V(0, 19.0, -0.6), V(0, 19.6, -2.0), V(0, 19.4, -3.4), V(0, 19.0, -4.0)]
    tube(b, path, [0.22, 0.2, 0.18, 0.18, 0.18], 6, "furn_metal")
    # hood: a shallow faceted dome over the lens
    hood = V(0, 18.9, -4.2)
    cyl(b, hood + V(0, -0.2, 0), 0.4, 1.15, 8, "furn_metal", top=False, r_top=1.2)
    cyl(b, hood + V(0, 0.2, 0), 0.5, 1.2, 8, "furn_metal", r_top=0.5)
    cyl(b, hood + V(0, 0.7, 0), 0.25, 0.5, 8, "furn_metal_dark", r_top=0.15)
    return b, {"height": 20.0, "reach": 4.2, "lens": [0, 18.5, -4.2], "material": "Metal"}


def lamp_lens(name):
    b = Builder(name)
    c = V(0, 18.7, -4.2)
    cyl(b, c + V(0, -0.5, 0), 0.5, 0.7, 8, "lamp_glass", bottom=True, r_top=1.1)
    return b, {"height": 19.2, "material": "Neon (dim) or SmoothPlastic", "note": "place with the same CFrame as Lamp"}


def planter(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    outline = rounded_rect2(-2.4, -2.4, 2.4, 2.4, 0.8, seg=2)
    prism(b, outline, 0, 2.0, "planter", top=False)
    prism(b, rounded_rect2(-2.6, -2.6, 2.6, 2.6, 0.9, seg=2), 2.0, 2.4, "planter_rim", "planter_rim")
    # soil just below the rim, a rounded shrub and two flower dots
    box(b, V(0, 2.3, 0), (4.2, 0.1, 4.2), "soil")
    sphere(b, V(0, 3.6, 0), (2.0, 1.5, 2.0), ["leaf_dark", "leaf_mid", "leaf_light", "leaf_sun"], subdiv=1, rng=rng, jitter=0.12)
    for p in (V(1.2, 4.6, -1.0), V(-1.1, 4.4, -1.2), V(0.3, 5.0, 1.0)):
        sphere(b, p, (0.45, 0.4, 0.45), ["flower_1", "flower_2"], subdiv=0, rng=rng)
    return b, {"height": 5.2, "footprint": [5.2, 5.2]}


def tree(name, toy=False):
    """A street tree with a rounded crown in a square grate. toy=True: one perfectly round crown
    on a straight trunk (direction A's lollipop tree)."""
    rng = random.Random(seed_of(name))
    b = Builder(name)
    box(b, V(0, 0.03, 0), (5.0, 0.06, 5.0), "tree_grate")
    leaves = ["leaf_dark", "leaf_mid", "leaf_light", "leaf_sun"]
    if toy:
        cyl(b, V(0, 0, 0), 8.0, 0.55, 6, "trunk", r_top=0.45)
        sphere(b, V(0, 12.5, 0), (5.2, 5.0, 5.2), leaves, subdiv=2, rng=rng, jitter=0.0)
        return b, {"height": 17.5, "crown_radius": 5.2, "trunk_clear": 7.5}
    tube(b, [V(0, 0, 0), V(0.1, 4.0, 0), V(-0.1, 7.5, 0.1)], [0.6, 0.45, 0.35], 6, "trunk")
    tube(b, [V(0, 6.5, 0), V(1.6, 8.6, 0.4)], [0.28, 0.18], 5, "trunk")
    sphere(b, V(0, 11.0, 0), (4.6, 3.8, 4.6), leaves, subdiv=1, rng=rng, jitter=0.1)
    sphere(b, V(1.8, 9.6, 1.2), (3.0, 2.6, 3.0), leaves, subdiv=1, rng=rng, jitter=0.12)
    sphere(b, V(-1.6, 12.6, -0.8), (2.8, 2.4, 2.8), leaves, subdiv=1, rng=rng, jitter=0.12)
    return b, {"height": 15.5, "crown_radius": 5.0, "trunk_clear": 7.0}


def hydrant(name):
    b = Builder(name)
    cyl(b, V(0, 0, 0), 0.3, 0.75, 8, "hydrant")
    cyl(b, V(0, 0.3, 0), 1.7, 0.55, 8, "hydrant", r_top=0.5)
    cyl(b, V(0, 2.0, 0), 0.2, 0.62, 8, "hydrant_cap")
    cyl(b, V(0, 2.2, 0), 0.45, 0.5, 8, "hydrant", r_top=0.2)
    cyl(b, V(0, 2.65, 0), 0.15, 0.15, 6, "hydrant_cap")
    for d in (V(1, 0, 0), V(-1, 0, 0), V(0, 0, -1)):
        tube(b, [V(0, 1.45, 0) + d * 0.4, V(0, 1.45, 0) + d * 0.85], [0.26, 0.26], 6, "hydrant_cap" if d.z else "hydrant")
    return b, {"height": 2.8}


def bench(name):
    b = Builder(name)
    L = 6.0
    for z in (-0.5, 0.0, 0.5):
        box(b, V(0, 1.6, z), (L, 0.18, 0.42), "wood")
    for y in (2.3, 2.85):
        box(b, V(0, y, 0.95 + (y - 2.3) * 0.15), (L, 0.4, 0.14), "wood")
    for x in (-L / 2 + 0.5, L / 2 - 0.5):
        box(b, V(x, 0.75, -0.55), (0.22, 1.5, 0.22), "furn_metal_dark")
        box(b, V(x, 0.75, 0.6), (0.22, 1.5, 0.22), "furn_metal_dark")
        box(b, V(x, 1.45, 0.0), (0.24, 0.16, 1.5), "furn_metal_dark")
        box(b, V(x, 2.3, 1.05), (0.2, 1.7, 0.18), "furn_metal_dark")
        box(b, V(x, 2.05, -0.2), (0.24, 0.14, 1.2), "furn_metal")
    return b, {"height": 3.2, "length": L, "seat": 1.7}


def bus_stop(name):
    """A shelter 12 long, open to the road (front, -Z): framed back and end glass, a roof with an
    overhang, a bench and a blank route sign on a post."""
    b = Builder(name)
    L, D, Ht = 12.0, 4.0, 8.4
    for x in (-L / 2, L / 2):
        for z in (-D / 2 + 0.2, D / 2):
            box(b, V(x, Ht / 2, z), (0.3, Ht, 0.3), "furn_metal")
    box(b, V(0, Ht + 0.3, 0), (L + 1.0, 0.5, D + 1.2), {"top": "shelter_roof", "side": "furn_metal", "bottom": "shelter_roof"})
    # back glass with a base rail and an advertising frame left blank
    box(b, V(0, 4.4, D / 2), (L - 0.3, 6.6, 0.12), "shelter_glass")
    box(b, V(0, 0.6, D / 2), (L, 0.4, 0.3), "furn_metal")
    box(b, V(0, 7.9, D / 2), (L, 0.3, 0.3), "furn_metal")
    for x in (-L / 2, L / 2):
        box(b, V(x, 4.4, 0.2), (0.12, 6.6, D - 0.6), "shelter_glass")
    box(b, V(0, 1.7, 1.2), (L - 3, 0.25, 1.2), "wood")
    for x in (-3.5, 3.5):
        box(b, V(x, 0.85, 1.2), (0.25, 1.7, 0.9), "furn_metal_dark")
    # sign post at the kerb end
    cyl(b, V(L / 2 + 1.5, 0, -1.2), 10.0, 0.16, 6, "furn_metal")
    box(b, V(L / 2 + 1.5, 9.0, -1.2), (2.2, 2.2, 0.15), {"front": "sign_white", "back": "sign_white", "side": "furn_metal"})
    box(b, V(L / 2 + 1.5, 9.0, -1.2), (2.4, 2.4, 0.1), "sign_green")
    return b, {
        "height": Ht + 0.6,
        "length": L + 3,
        "faces": [{"name": "route", "centre": [L / 2 + 1.5, 9.0, -1.28], "size": [2.2, 2.2], "normal": "Front", "both_sides": True}],
    }


def bin_(name):
    b = Builder(name)
    cyl(b, V(0, 0, 0), 3.0, 1.0, 8, "bin", r_top=1.1)
    cyl(b, V(0, 3.0, 0), 0.35, 1.2, 8, "bin_lid", r_top=0.9)
    box(b, V(0, 2.6, -1.05), (1.0, 0.35, 0.1), "furn_metal_dark")
    return b, {"height": 3.4}


def bike_rack(name):
    b = Builder(name)
    box(b, V(0, 0.1, 0), (7.2, 0.2, 0.4), "furn_metal_dark")
    for x in (-2.4, 0.0, 2.4):
        path = [V(x, 0.1, -1.2), V(x, 2.4, -1.2), V(x, 2.9, -0.6), V(x, 2.9, 0.6), V(x, 2.4, 1.2), V(x, 0.1, 1.2)]
        tube(b, path, [0.15] * len(path), 6, "furn_metal")
    return b, {"height": 3.0, "length": 7.2}


def traffic_light(name):
    """A signal pole for the kerb, lenses facing local -Z (turn it to face oncoming traffic: yaw
    = yaw_along + 180). One head on the pole, a second on a short arm that stays over the
    sidewalk (it reaches 3.5 toward local +X; mount it so the arm points away from the road)."""
    b = Builder(name)
    cyl(b, V(0, 0, 0), 0.8, 0.6, 8, "signal_housing", r_top=0.45)
    cyl(b, V(0, 0.8, 0), 14.2, 0.28, 8, "furn_metal", r_top=0.24)
    tube(b, [V(0, 13.4, 0), V(3.5, 13.8, 0)], [0.18, 0.15], 6, "furn_metal")

    def head(c):
        box(b, c, (1.3, 3.8, 1.0), "signal_housing")
        box(b, c + V(0, 0, 0.55), (1.8, 4.4, 0.12), "signal_housing")
        for i, sw in enumerate(("signal_off", "signal_off", "signal_green")):
            y = c.y + 1.2 - 1.2 * i
            ln = []
            for k in range(8):
                a = 2 * math.pi * k / 8
                ln.append(V(c.x + math.cos(a) * 0.42, y + math.sin(a) * 0.42, c.z - 0.52))
            b.face(ln, sw, V(0, 0, -1))
            # visor
            box(b, V(c.x, y + 0.5, c.z - 0.85), (1.0, 0.08, 0.7), "signal_housing")

    head(V(0, 9.6, -0.55))
    head(V(3.2, 11.6, -0.55))
    return b, {"height": 15.0, "arm": 3.5, "lit": "green"}


def street_sign(name):
    """A corner name sign: two crossed blank blades on a post (text by SurfaceGui)."""
    b = Builder(name)
    cyl(b, V(0, 0, 0), 11.0, 0.16, 6, "furn_metal")
    box(b, V(0, 10.2, 0), (5.6, 1.0, 0.14), {"front": "sign_green", "back": "sign_green", "side": "sign_white"})
    box(b, V(0, 11.3, 0), (0.14, 1.0, 5.6), {"left": "sign_green", "right": "sign_green", "side": "sign_white"})
    cyl(b, V(0, 11.8, 0), 0.25, 0.22, 6, "furn_metal_dark")
    return b, {
        "height": 12.0,
        "faces": [
            {"name": "blade_x", "centre": [0, 10.2, -0.08], "size": [5.2, 0.8], "normal": "Front", "both_sides": True},
            {"name": "blade_z", "centre": [-0.08, 11.3, 0], "size": [5.2, 0.8], "normal": "Left", "both_sides": True},
        ],
    }


def bollard(name):
    b = Builder(name)
    cyl(b, V(0, 0, 0), 3.0, 0.45, 8, "furn_metal", r_top=0.4)
    cyl(b, V(0, 3.0, 0), 0.5, 0.4, 8, "furn_metal_dark", r_top=0.15)
    cyl(b, V(0, 2.2, 0), 0.25, 0.47, 8, "sign_white")
    return b, {"height": 3.5}


def roof_ac(name):
    """A rooftop air-conditioning unit (shared roof prop): a box with a fan grille and a duct."""
    b = Builder(name)
    box(b, V(0, 0.15, 0), (4.6, 0.3, 3.4), "ac_fan")
    box(b, V(0, 1.6, 0), (4.2, 2.6, 3.0), "ac_body")
    cyl(b, V(-0.8, 2.9, 0), 0.12, 1.1, 10, "ac_fan")
    for k in range(4):
        a = math.pi / 2 * k + 0.4
        box(b, V(-0.8 + math.cos(a) * 0.5, 3.04, math.sin(a) * 0.5), (0.9, 0.06, 0.25), "ac_body", yaw=-a)
    box(b, V(1.3, 3.3, 0.4), (1.0, 1.4, 1.0), "ac_body")
    tube(b, [V(1.3, 3.9, 0.4), V(1.3, 4.4, 0.4), V(1.9, 4.6, 0.4)], [0.35, 0.35, 0.35], 6, "ac_fan")
    return b, {"height": 4.8}


def build_all(emit):
    P = "street"
    emit(*lamp("Lamp"), P, "common")
    emit(*lamp_lens("LampLens"), P, "common")
    emit(*planter("Planter"), P, "common")
    emit(*tree("TreeRound"), P, "common")
    emit(*tree("A_TreeToy", toy=True), P, "A")
    emit(*hydrant("Hydrant"), P, "common")
    emit(*bench("Bench"), P, "common")
    emit(*bus_stop("BusStop"), P, "common")
    emit(*bin_("Bin"), P, "common")
    emit(*bike_rack("BikeRack"), P, "common")
    emit(*traffic_light("TrafficLight"), P, "common")
    emit(*street_sign("StreetSign"), P, "common")
    emit(*bollard("Bollard"), P, "common")
    emit(*roof_ac("RoofAC"), P, "common")
