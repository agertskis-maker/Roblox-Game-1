# Island kit: decorative wildlife (Lane 3), rigid pieces animated in code on the client (no rigs,
# no published animations). Friendly rounded faceted forms. Moving parts are separate meshes
# with their pivot at the joint: the mesh origin (0, 0, 0) is where the piece hinges, so the
# client rotates it about its own CFrame position after offsetting by the bounds centre.
#   Duck, Duckling: one piece each, water line at y 0 (they float).
#   Raccoon body + RaccoonHead (pivot at the neck).
#   ButterflyBody + ButterflyWingL/R (pivot on the body axis).
#   DragonflyBody + DragonflyWings (pivot on the body; flutters as one piece).
#   Frog, Fish: one piece each.

import math
import random

import bmesh
from mathutils import Vector

from kitlib import Builder, clump, tube


def seed_of(name):
    return sum(map(ord, name)) * 17 + len(name)


def duck(name, scale, adult=True):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    s = scale
    body_sw = ["duck_brown", "duck_brown", "duck_white"] if adult else ["duckling", "duckling", "fruit_yellow"]
    # body: a long rounded hull riding low, a raised tail
    clump(b, Vector((0, 0, 0.25 * s)), Vector((1.0 * s, 0.62 * s, 0.5 * s)), rng, body_sw, flatten=1.0, subdiv=2)
    clump(b, Vector((-0.85 * s, 0, 0.55 * s)), Vector((0.32 * s, 0.3 * s, 0.22 * s)), rng, body_sw[:2], subdiv=1)
    # head on a short neck, the bill pointing forward (+x)
    head_sw = ["duck_head", "duck_head"] if adult else ["duckling", "fruit_yellow"]
    tube(b, [Vector((0.6 * s, 0, 0.5 * s)), Vector((0.75 * s, 0, 0.95 * s))], [0.26 * s, 0.22 * s], 6, [head_sw[0] if not adult else "duck_white"])
    clump(b, Vector((0.8 * s, 0, 1.1 * s)), Vector((0.34 * s, 0.3 * s, 0.3 * s)), rng, head_sw, subdiv=2)
    tube(b, [Vector((1.05 * s, 0, 1.05 * s)), Vector((1.45 * s, 0, 1.0 * s))], [0.11 * s, 0.07 * s], 5, ["bill"])
    for y in (-0.2, 0.2):
        clump(b, Vector((0.98 * s, y * s, 1.2 * s)), Vector((0.06 * s, 0.06 * s, 0.07 * s)), rng, ["black"], subdiv=1)
    # folded wings
    for y in (-1, 1):
        clump(b, Vector((-0.1 * s, y * 0.5 * s, 0.45 * s)), Vector((0.65 * s, 0.14 * s, 0.26 * s)), rng, ["duck_brown" if adult else "fruit_yellow", "bark_streak" if adult else "duckling"], subdiv=1)
    return b, {"height": 1.4 * s, "length": 2.6 * s, "float": 0.0}


def painted(b, centre, size, rng, paint, subdiv=2, jitter=0.1, deform=None):
    """A faceted ellipsoid whose faces are coloured by region: paint(u, n) gets the face's
    direction on the unit sphere (u) and its normal (n) and returns a swatch. Used where a
    marking must sit on the form itself (the raccoon's mask, belly and ear linings)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    unit = {}
    for v in bm.verts:
        n = v.co.normalized()
        unit[v.index] = n
        s = 1 + rng.uniform(-jitter, jitter)
        v.co = Vector((n.x * size.x * s, n.y * size.y * s, n.z * size.z * s))
        if deform:
            v.co = deform(v.co)
    bm.normal_update()
    for f in bm.faces:
        u = sum((unit[v.index] for v in f.verts), Vector()).normalized()
        b.face([centre + v.co for v in f.verts], paint(u, f.normal))
    bm.free()


def raccoon(name):
    # Read at a distance by its silhouette and markings: a low, hunched body with the rump
    # higher than the shoulders, short dark legs, and a thick tail in bold dark and pale rings
    # held out behind and a little to one side, so the rings show from the side and the rear.
    rng = random.Random(seed_of(name))
    b = Builder(name)

    def fur(u, n):
        if n.z < -0.45:
            return "birch_grey"  # paler belly
        return "rock" if rng.random() < 0.3 else "raccoon"

    # torso: rump raised, back arched, shoulders dropping toward the neck
    def hunch(v):
        return Vector((v.x, v.y, v.z - 0.3 * v.x + (0.14 * max(0.0, 1 - ((v.x + 0.35) / 0.9) ** 2) if v.z > 0 else 0)))

    painted(b, Vector((-0.1, 0, 0.84)), Vector((1.0, 0.62, 0.5)), rng, fur, subdiv=2, deform=hunch)
    # shoulders and neck, rising to the head joint at the neck point (0.95, 0, 1.25)
    tube(b, [Vector((0.4, 0, 0.86)), Vector((0.72, 0, 1.02)), Vector((0.98, 0, 1.2))], [0.44, 0.4, 0.3], 8, ["raccoon", "rock", "raccoon"])
    # haunches, so the rump reads round from behind
    for y in (-1, 1):
        painted(b, Vector((-0.58, y * 0.32, 0.72)), Vector((0.38, 0.22, 0.34)), rng, fur, subdiv=1)
    # short dark legs with paws
    for x, top in ((0.6, 0.62), (-0.6, 0.6)):
        for y in (-0.3, 0.3):
            tube(b, [Vector((x, y, top)), Vector((x + 0.03, y, 0.06))], [0.19, 0.15], 5, ["raccoon_dark"])
            clump(b, Vector((x + 0.08, y, 0.06)), Vector((0.15, 0.12, 0.07)), rng, ["raccoon_dark"], subdiv=1)
    # the ringed tail: six bands, grey at the root, then dark / pale, ending in a dark tip
    pts = [Vector((-0.85, 0, 1.12)), Vector((-1.15, 0.04, 1.08)), Vector((-1.45, 0.13, 1.1)), Vector((-1.72, 0.25, 1.2)), Vector((-1.94, 0.38, 1.36)), Vector((-2.1, 0.5, 1.56)), Vector((-2.2, 0.58, 1.76))]
    bands = ["raccoon", "raccoon_dark", "birch_white", "raccoon_dark", "birch_white", "raccoon_dark"]
    tube(b, pts, [0.24, 0.31, 0.34, 0.34, 0.31, 0.25, 0.15], 7, bands)
    return b, {"height": 1.6, "length": 3.6, "neck": [0.95, 0, 1.25]}


def raccoon_head(name):
    # Pivot at the neck (origin); the head sits forward of it and slightly low (the hunch).
    # Broad round skull, a short pointed pale muzzle with a black nose, round ears with dark
    # linings, and the mask: a dark band across the eyes wrapping round the sides of the face,
    # with pale brows above it and pale cheeks below it.
    rng = random.Random(seed_of(name))
    b = Builder(name)

    def face(u, n):
        if u.x > 0.05:
            if -0.12 < u.z < 0.42 and abs(u.y) < 0.95:
                return "raccoon_dark"  # the mask
            if u.z >= 0.42 and u.x > 0.45 and abs(u.y) < 0.75:
                return "birch_white"  # brows
            if u.z <= -0.12:
                return "birch_white"  # cheeks and chin
        return "raccoon"

    painted(b, Vector((0.36, 0, 0.02)), Vector((0.42, 0.5, 0.38)), rng, face, subdiv=2, jitter=0.06)

    def muzzle(u, n):
        if u.x > 0.86:
            return "black"  # nose
        return "birch_white"

    painted(b, Vector((0.74, 0, -0.06)), Vector((0.3, 0.19, 0.15)), rng, muzzle, subdiv=2, jitter=0.05)
    for y in (-1, 1):
        # eyes: a pale glint in the mask
        clump(b, Vector((0.7, y * 0.2, 0.09)), Vector((0.055, 0.055, 0.055)), rng, ["cart_white"], subdiv=0)

        # round ears, dark inside, pale rim
        def ear(u, n, y=y):
            return "raccoon_dark" if n.x > 0.35 else "birch_white"

        painted(b, Vector((0.2, y * 0.31, 0.37)), Vector((0.08, 0.16, 0.15)), rng, ear, subdiv=2, jitter=0.03)
    return b, {"height": 0.55}


def butterfly_body(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    tube(b, [Vector((-0.35, 0, 0)), Vector((0, 0, 0.02)), Vector((0.3, 0, 0.03))], [0.05, 0.07, 0.06], 5, ["black"])
    for y in (-1, 1):
        tube(b, [Vector((0.3, 0, 0.05)), Vector((0.55, y * 0.12, 0.25))], [0.012, 0.012], 3, ["black"])
    return b, {"height": 0.3}


def butterfly_wing(name, side, swatch):
    b = Builder(name)
    # a forewing and a rounder hindwing, hinged on the body axis (origin), lying flat (wings open)
    y = side
    fore = [Vector((0.15, 0, 0)), Vector((0.5, y * 0.55, 0)), Vector((0.2, y * 0.75, 0)), Vector((-0.1, y * 0.5, 0))]
    hind = [Vector((-0.05, 0, 0)), Vector((-0.1, y * 0.45, 0)), Vector((-0.45, y * 0.5, 0)), Vector((-0.4, y * 0.15, 0))]
    b.face2(fore, swatch)
    b.face2(hind, swatch)
    b.face2([Vector((0.3, y * 0.5, 0.005)), Vector((0.22, y * 0.66, 0.005)), Vector((0.12, y * 0.5, 0.005))], "black")
    return b, {"span": 0.75}


def dragonfly_body(name):
    b = Builder(name)
    tube(b, [Vector((-1.1, 0, 0)), Vector((-0.4, 0, 0)), Vector((0.2, 0, 0.02)), Vector((0.45, 0, 0.03))], [0.025, 0.045, 0.08, 0.1], 5, ["dragonfly", "wing_blue", "dragonfly"])
    rng = random.Random(seed_of(name))
    for y in (-1, 1):
        clump(b, Vector((0.48, y * 0.08, 0.06)), Vector((0.07, 0.07, 0.07)), rng, ["fish_silver"], subdiv=1)
    return b, {"length": 1.6}


def dragonfly_wings(name):
    b = Builder(name)
    for x in (0.12, -0.12):
        for y in (-1, 1):
            b.face2([Vector((x, 0, 0)), Vector((x + 0.12, y * 0.85, 0.02)), Vector((x - 0.08, y * 0.9, 0.02)), Vector((x - 0.1, y * 0.15, 0))], "fish_silver")
    return b, {"span": 1.8}


def frog(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    clump(b, Vector((0, 0, 0.32)), Vector((0.55, 0.48, 0.32)), rng, ["frog", "frog", "frog_belly"], flatten=1.0, subdiv=2)
    for y in (-1, 1):
        clump(b, Vector((0.3, y * 0.22, 0.62)), Vector((0.14, 0.14, 0.14)), rng, ["frog"], subdiv=1)
        clump(b, Vector((0.38, y * 0.24, 0.66)), Vector((0.07, 0.07, 0.07)), rng, ["black"], subdiv=1)
        # folded back legs and front feet
        clump(b, Vector((-0.3, y * 0.45, 0.2)), Vector((0.35, 0.17, 0.18)), rng, ["frog", "leaf_mid"], subdiv=1)
        clump(b, Vector((0.35, y * 0.3, 0.06)), Vector((0.14, 0.1, 0.05)), rng, ["frog_belly"], subdiv=1)
    return b, {"height": 0.8, "length": 1.2}


def fish(name, swatch):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    clump(b, Vector((0, 0, 0)), Vector((0.75, 0.2, 0.32)), rng, [swatch, swatch, "fish_silver"], flatten=1.0, subdiv=2)
    # tail fin and a dorsal fin
    b.face2([Vector((-0.65, 0, 0)), Vector((-1.15, 0, 0.35)), Vector((-1.05, 0, 0)), Vector((-1.15, 0, -0.35))], swatch)
    b.face2([Vector((-0.1, 0, 0.28)), Vector((0.2, 0, 0.3)), Vector((-0.3, 0, 0.5))], swatch)
    return b, {"length": 1.9}


def build_all(emit):
    A = "animals/"
    emit(*duck("Duck", 1.0, True), A + "Duck")
    emit(*duck("Duckling", 0.45, False), A + "Duck")
    emit(*raccoon("Raccoon"), A + "Raccoon")
    emit(*raccoon_head("RaccoonHead"), A + "Raccoon")
    emit(*butterfly_body("ButterflyBody"), A + "Butterfly")
    emit(*butterfly_wing("ButterflyWingL", 1, "wing_orange"), A + "Butterfly")
    emit(*butterfly_wing("ButterflyWingR", -1, "wing_orange"), A + "Butterfly")
    emit(*butterfly_wing("ButterflyBlueWingL", 1, "wing_blue"), A + "Butterfly")
    emit(*butterfly_wing("ButterflyBlueWingR", -1, "wing_blue"), A + "Butterfly")
    emit(*dragonfly_body("DragonflyBody"), A + "Dragonfly")
    emit(*dragonfly_wings("DragonflyWings"), A + "Dragonfly")
    emit(*frog("Frog"), A + "Frog")
    emit(*fish("FishOrange", "fish_orange"), A + "Fish")
    emit(*fish("FishSilver", "fish_silver"), A + "Fish")
