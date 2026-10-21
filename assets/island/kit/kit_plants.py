# Island kit: ground vegetation and aquatic plants (Lane 3). Small reusable clumps in the same
# faceted language as the trees. Flower clumps hold 8 to 12 flowers of ONE kind and colour so
# they plant as colour drifts, never confetti. Blades, petals and pads are two-sided. Every mesh
# has its ground (or water) line at y 0; anything below it is meant to be buried or submerged.

import math
import random

from mathutils import Vector

from kitlib import Builder, blade, bloom, clump, disc, rock, stem, tube

GRASS = ["blade", "leaf_mid", "leaf_light"]


def seed_of(name):
    return sum(map(ord, name)) * 7 + len(name)


def scatter(rng, n, radius, min_gap=0.0):
    pts = []
    tries = 0
    while len(pts) < n and tries < n * 40:
        tries += 1
        a = rng.uniform(0, 2 * math.pi)
        r = radius * math.sqrt(rng.uniform(0, 1))
        p = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        if all((p - q).length >= min_gap for q in pts):
            pts.append(p)
    return pts


def base_leaves(b, rng, at, count, length, swatch="stem"):
    for _ in range(count):
        a = rng.uniform(0, 2 * math.pi)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.35, 0.7)
        blade(b, at + Vector((0, 0, -0.1)), length * rng.uniform(0.7, 1.1), length * 0.28, lean, swatch, 2)


# ---------------------------------------------------------------- grasses and ground cover
def grass_tuft(name, blades, height, spread, tall=False):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, blades, spread):
        a = rng.uniform(0, 2 * math.pi)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.15, 0.5)
        h = height * rng.uniform(0.6, 1.15)
        sw = "straw" if tall and rng.random() < 0.3 else rng.choice(GRASS)
        blade(b, p + Vector((0, 0, -0.15)), h, rng.uniform(0.18, 0.3) * (1.4 if tall else 1), lean, sw, 3 if tall else 2)
    return b, {"height": height, "spread": spread}


def clover(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, 14, 1.6, 0.35):
        top = p + Vector((0, 0, rng.uniform(0.25, 0.45)))
        stem(b, p + Vector((0, 0, -0.1)), top, 0.03, "stem")
        for k in range(3):
            a = 2 * math.pi * k / 3 + rng.uniform(0, 1)
            d = Vector((math.cos(a), math.sin(a), 0))
            s = Vector((-d.y, d.x, 0))
            c = top + d * 0.2
            b.face2([top, c + s * 0.14, top + d * 0.32 + Vector((0, 0, 0.03)), c - s * 0.14], "clover")
    for p in scatter(rng, 3, 1.2):
        top = p + Vector((0, 0, 0.6))
        stem(b, p, top, 0.03, "stem")
        clump(b, top, Vector((0.12, 0.12, 0.12)), rng, ["daisy_white", "blossom_white"], subdiv=0)
    return b, {"height": 0.7, "spread": 1.6}


def fern(name, fronds, length):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + rng.uniform(-0.25, 0.25)
        d = Vector((math.cos(a), math.sin(a), 0))
        rise = rng.uniform(0.5, 0.9)
        n = 7
        prev = Vector((0, 0, -0.1))
        for i in range(1, n + 1):
            t = i / n
            # an arching rachis: up and out, drooping at the tip
            pt = d * length * t + Vector((0, 0, length * rise * (t - 0.85 * t * t)))
            stem(b, prev, pt, 0.04 * (1 - t) + 0.015, "fern", 3)
            w = length * 0.22 * math.sin(math.pi * min(1, t * 1.1))
            side = Vector((-d.y, d.x, 0))
            for sgn in (-1, 1):
                tip = pt + side * sgn * w + Vector((0, 0, -0.05))
                b.face2([prev, pt, tip], "fern" if i % 2 else "leaf_mid")
            prev = pt
    return b, {"height": length * 0.35, "spread": length}


def mushrooms(name, cap, count):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, count, 0.9, 0.3):
        h = rng.uniform(0.35, 0.8)
        r = h * rng.uniform(0.45, 0.7)
        tube(b, [p + Vector((0, 0, -0.2)), p + Vector((0, 0, h))], [r * 0.32, r * 0.24], 5, ["cap_white"])
        clump(b, p + Vector((0, 0, h)), Vector((r, r, r * 0.55)), rng, [cap, cap, cap], flatten=1.0, subdiv=1)
        if cap == "cap_red":
            for _ in range(4):
                a = rng.uniform(0, 2 * math.pi)
                q = p + Vector((math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, h + r * 0.4))
                clump(b, q, Vector((r * 0.13, r * 0.13, r * 0.07)), rng, ["cap_white"], subdiv=0)
    return b, {"height": 0.9, "spread": 0.9}


def mossy_rock(name, size):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    rock(b, Vector((0, 0, size.z * 0.45)), size, rng, ["moss", "rock", "rock_dark"], subdiv=2)
    return b, {"height": size.z * 1.45, "sink": size.z * 0.55}


def stump(name, radius, height):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    rings = tube(b, [Vector((0, 0, -1.2)), Vector((0, 0, height * 0.5)), Vector((0, 0, height))], [radius * 1.3, radius * 1.05, radius], 8, ["log_bark", "bark_dark"], rng=rng, jitter=0.08, cap=False)
    top = rings[-1]
    c = Vector((0, 0, height - 0.05))
    for k in range(len(top)):
        b.tri(top[k], top[(k + 1) % len(top)], c, "log_inner")
    for k in range(4):
        a = 2 * math.pi * k / 4 + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(b, [d * radius * 0.6 + Vector((0, 0, height * 0.35)), d * radius * 1.9 + Vector((0, 0, -0.6))], [radius * 0.45, radius * 0.12], 4, ["log_bark"], rng=rng, jitter=0.1)
    return b, {"height": height, "sink": 1.2}


def hollow_log(name, length, radius):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    n = 4
    path = [Vector((-length / 2 + length * i / n, rng.uniform(-0.15, 0.15), radius * 0.82)) for i in range(n + 1)]
    outer = tube(b, path, [radius * (1 - 0.05 * i) for i in range(n + 1)], 9, ["log_bark", "bark_dark", "log_bark"], rng=rng, jitter=0.06, cap=False)
    # the inside: a reversed inner tube, so the hollow reads from either end
    inner_r = [radius * 0.66 * (1 - 0.05 * i) for i in range(n + 1)]
    inner = []
    from kitlib import ring

    for i, p in enumerate(path):
        axis = path[min(i + 1, n)] - path[max(i - 1, 0)]
        inner.append(ring(p, axis, inner_r[i], 9, phase=0.37 * i))
    for i in range(n):
        a, c = inner[i], inner[i + 1]
        for k in range(9):
            k2 = (k + 1) % 9
            b.quad(a[k], c[k], c[k2], a[k2], "log_inner" if i in (0, n - 1) else "bark_dark")
    for end, ins in ((outer[0], inner[0]), (outer[-1], inner[-1])):
        for k in range(9):
            k2 = (k + 1) % 9
            b.quad(end[k], end[k2], ins[k2], ins[k], "log_inner")
    # a broken branch stub and moss on top
    tube(b, [path[1] + Vector((0, 0, radius * 0.7)), path[1] + Vector((0.4, 0.3, radius * 1.9))], [radius * 0.25, radius * 0.1], 4, ["log_bark"])
    clump(b, path[3] + Vector((0, 0, radius * 0.85)), Vector((radius * 0.7, radius * 0.5, radius * 0.18)), rng, ["moss"], subdiv=1)
    return b, {"height": radius * 1.9, "length": length, "sink": radius * 0.2}


def leaf_litter(name, count, spread):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, count, spread):
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        z = Vector((0, 0, 0.04 + rng.uniform(0, 0.05)))
        L = rng.uniform(0.3, 0.55)
        sw = rng.choice(["leaf_litter", "leaf_litter", "bark_streak", "fruit_orange", "straw"])
        b.face2([p + z - d * L * 0.5, p + z + s * L * 0.3, p + z + d * L * 0.5, p + z - s * L * 0.3], sw)
    return b, {"height": 0.1, "spread": spread}


# ---------------------------------------------------------------- flower clumps (8 to 12 flowers)
def flower_clump(name, kind, colour, count):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    spread = {"sunflower": 1.6, "lavender": 1.3}.get(kind, 1.2)
    pts = scatter(rng, count, spread, 0.28)
    for p in pts:
        if kind == "tulip":
            h = rng.uniform(1.0, 1.5)
            top = p + Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), h))
            stem(b, p + Vector((0, 0, -0.2)), top, 0.045, "stem")
            base_leaves(b, rng, p, 2, 0.8)
            # a closed cup of three upright petals
            for k in range(3):
                a = 2 * math.pi * k / 3 + rng.uniform(0, 0.4)
                d = Vector((math.cos(a), math.sin(a), 0))
                s = Vector((-d.y, d.x, 0))
                b.face2([top + s * 0.17 + d * 0.05, top + d * 0.2 + Vector((0, 0, 0.42)), top - s * 0.17 + d * 0.05, top + d * 0.06 - Vector((0, 0, 0.05))], colour)
        elif kind == "daisy":
            h = rng.uniform(0.6, 1.0)
            top = p + Vector((0, 0, h))
            stem(b, p + Vector((0, 0, -0.2)), top, 0.035, "stem")
            bloom(b, top, 0.3, 9, colour, "daisy_centre", cup=0.12, rng=rng)
            base_leaves(b, rng, p, 1, 0.5)
        elif kind == "poppy":
            h = rng.uniform(0.9, 1.4)
            top = p + Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), h))
            stem(b, p + Vector((0, 0, -0.2)), top, 0.03, "stem")
            bloom(b, top, 0.34, 5, colour, "poppy_centre", cup=0.45, rng=rng)
        elif kind == "lavender":
            h = rng.uniform(1.1, 1.7)
            for s in range(3):
                a = rng.uniform(0, 2 * math.pi)
                top = p + Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, h * rng.uniform(0.85, 1.05)))
                stem(b, p + Vector((0, 0, -0.2)), top, 0.025, "stem")
                # the flower spike: a knobbly faceted spindle on the top third of the stem
                spike = [p.lerp(top, f) for f in (0.66, 0.78, 0.9, 1.0)]
                tube(b, spike, [0.05, 0.11, 0.09, 0.03], 4, [colour, "lavender_light", colour], rng=rng, jitter=0.2)
            base_leaves(b, rng, p, 3, 0.6, "fern")
        elif kind == "wild":
            h = rng.uniform(0.45, 0.8)
            top = p + Vector((0, 0, h))
            stem(b, p + Vector((0, 0, -0.2)), top, 0.025, "stem")
            bloom(b, top, 0.17, 5, colour, "daisy_white", cup=0.3, rng=rng)
            base_leaves(b, rng, p, 1, 0.4)
        elif kind == "sunflower":
            h = rng.uniform(4.0, 5.6)
            top = p + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), h))
            stem(b, p + Vector((0, 0, -0.3)), top, 0.1, "stem", 4)
            for k in range(3):
                a = rng.uniform(0, 2 * math.pi)
                at = p.lerp(top, 0.3 + 0.2 * k)
                blade(b, at, 0.9, 0.7, Vector((math.cos(a), math.sin(a), 0)) * 1.4, "leaf_mid", 2)
            # head turned toward the sun side (+x) and tilted forward
            bloom(b, top + Vector((0.15, 0, 0)), 0.85, 14, colour, None, cup=0.05, rng=rng)
            clump(b, top + Vector((0.22, 0, 0.05)), Vector((0.42, 0.42, 0.16)), rng, ["sunflower_centre"] * 2, subdiv=1)
        elif kind == "rose":
            h = rng.uniform(0.9, 1.3)
            top = p + Vector((0, 0, h))
            stem(b, p + Vector((0, 0, -0.2)), top, 0.035, "stem")
            clump(b, p + Vector((0, 0, h * 0.45)), Vector((0.32, 0.32, 0.3)), rng, ["leaf_dark", "leaf_mid"], subdiv=1)
            # layered cupped petals
            bloom(b, top, 0.26, 5, colour, None, cup=0.7, rng=rng)
            bloom(b, top + Vector((0, 0, 0.06)), 0.17, 4, colour, None, cup=0.9, rng=rng)
            clump(b, top + Vector((0, 0, 0.1)), Vector((0.09, 0.09, 0.09)), rng, [colour], subdiv=0)
    height = {"sunflower": 5.6, "lavender": 1.7, "tulip": 1.9, "poppy": 1.6, "rose": 1.4}.get(kind, 1.0)
    return b, {"height": height, "spread": spread, "flowers": len(pts)}


# ---------------------------------------------------------------- water margins and the lake
def reeds(name, count, height, kind):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, count, 1.3):
        a = rng.uniform(0, 2 * math.pi)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.04, 0.16)
        h = height * rng.uniform(0.7, 1.15)
        base = p + Vector((0, 0, -0.8))
        if kind == "rush":
            stem(b, base, p + Vector((0, 0, h)) + lean * h, 0.05, rng.choice(["reed", "pine_mid"]), 3)
        else:
            blade(b, base, h + 0.8, rng.uniform(0.2, 0.32), lean, rng.choice(["reed", "reed", "straw"]), 3, twist=rng.uniform(0, 1))
        if kind == "cattail" and rng.random() < 0.55:
            top = p + Vector((0, 0, h * 1.05))
            stem(b, base, top, 0.04, "reed")
            tube(b, [top - Vector((0, 0, 0.7)), top], [0.13, 0.12], 6, ["cattail"])
            stem(b, top, top + Vector((0, 0, 0.35)), 0.02, "straw")
    return b, {"height": height * 1.2, "sink": 0.8}


def arrowhead(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, 7, 1.0, 0.3):
        h = rng.uniform(0.9, 1.6)
        top = p + Vector((0, 0, h))
        stem(b, p + Vector((0, 0, -0.8)), top, 0.04, "stem")
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0.35)).normalized()
        s = Vector((-d.y, d.x, 0)).normalized()
        tip = top + d * 0.75
        # arrow-shaped leaf with two back lobes
        b.face2([top, top + s * 0.32 - d * 0.35, tip], "leaf_mid")
        b.face2([top, tip, top - s * 0.32 - d * 0.35], "leaf_dark")
    return b, {"height": 2.0, "sink": 0.8}


def irises(name):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, 8, 0.9, 0.25):
        a = rng.uniform(0, 2 * math.pi)
        lean = Vector((math.cos(a), math.sin(a), 0)) * 0.08
        blade(b, p + Vector((0, 0, -0.6)), rng.uniform(1.8, 2.4), 0.24, lean, "leaf_mid", 3)
    for p in scatter(rng, 4, 0.7):
        top = p + Vector((0, 0, rng.uniform(1.7, 2.2)))
        stem(b, p + Vector((0, 0, -0.6)), top, 0.035, "stem")
        bloom(b, top, 0.28, 3, "iris", "tulip_yellow", cup=-0.35, rng=rng)
        bloom(b, top + Vector((0, 0, 0.12)), 0.2, 3, "iris", None, cup=1.4, rng=rng)
    return b, {"height": 2.4, "sink": 0.6}


def lily_pad(name, radius):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # a notched disc a hair above the water line, darker rim underneath
    disc(b, Vector((0, 0, 0.06)), radius, 12, "pad", thickness=0.06, rng=rng, notch=0.1)
    return b, {"height": 0.12, "radius": radius}


def lily_flower(name, colour):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    disc(b, Vector((0, 0, 0.05)), 0.9, 10, "pad_dark", thickness=0.05, rng=rng, notch=0.1)
    bloom(b, Vector((0.1, 0.1, 0.12)), 0.5, 8, colour, None, cup=0.7, rng=rng)
    bloom(b, Vector((0.1, 0.1, 0.2)), 0.32, 6, colour, "daisy_centre", cup=1.0, rng=rng)
    return b, {"height": 0.5, "radius": 0.9}


def duckweed(name, count, spread):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    for p in scatter(rng, count, spread):
        disc(b, p + Vector((0, 0, 0.04)), rng.uniform(0.08, 0.16), 5, "duckweed")
    return b, {"height": 0.05, "spread": spread}


def wet_rock(name, size):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    # set so the waterline (y 0) crosses it; the wet band is the strip just above the water
    rock(b, Vector((0, 0, size.z * 0.1)), size, rng, ["rock", "rock", "rock_dark"], subdiv=2, wet_band=0.35)
    return b, {"height": size.z * 1.1, "sink": size.z * 0.9}


def driftwood(name, length):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    path = [Vector((-length / 2 + length * i / 4, rng.uniform(-0.3, 0.3), 0.15 - 0.12 * i)) for i in range(5)]
    tube(b, path, [0.38, 0.36, 0.32, 0.26, 0.18], 6, ["birch_grey", "log_bark", "birch_grey"], rng=rng, jitter=0.1)
    for i in (1, 3):
        d = Vector((rng.uniform(-0.3, 0.6), rng.choice((-1, 1)) * 1.0, 0.5)).normalized()
        tube(b, [path[i], path[i] + d * rng.uniform(0.8, 1.4)], [0.14, 0.05], 4, ["birch_grey"])
    return b, {"height": 0.8, "length": length, "sink": 0.3}


def stepping_stone(name, radius):
    rng = random.Random(seed_of(name))
    b = Builder(name)
    rock(b, Vector((0, 0, -0.15)), Vector((radius, radius * rng.uniform(0.8, 0.95), 0.55)), rng, ["stone_light", "rock", "rock"], subdiv=2, wet_band=0.05)
    return b, {"height": 0.4, "radius": radius, "sink": 0.7}


def floating_leaf(name, swatch, size):
    b = Builder(name)
    z = Vector((0, 0, 0.04))
    b.face2([z + Vector((-size, 0, 0)), z + Vector((0, size * 0.45, 0)), z + Vector((size, 0, 0)), z + Vector((0, -size * 0.45, 0))], swatch)
    return b, {"height": 0.05}


def build_all(emit):
    F = "plants/"
    emit(*grass_tuft("GrassTuft", 14, 1.2, 0.8), F + "Grass")
    emit(*grass_tuft("GrassTuftWide", 26, 1.0, 1.6), F + "Grass")
    emit(*grass_tuft("TallGrass", 22, 2.6, 1.2, tall=True), F + "Grass")
    emit(*clover("Clover"), F + "Grass")
    emit(*fern("FernA", 7, 2.2), F + "Fern")
    emit(*fern("FernB", 9, 1.6), F + "Fern")
    emit(*mushrooms("MushroomsRed", "cap_red", 5), F + "Mushroom")
    emit(*mushrooms("MushroomsBrown", "cap_brown", 6), F + "Mushroom")
    emit(*mossy_rock("MossyRockA", Vector((2.2, 1.8, 1.3))), F + "Rock")
    emit(*mossy_rock("MossyRockB", Vector((3.4, 2.6, 1.9))), F + "Rock")
    emit(*stump("Stump", 1.0, 1.4), F + "Log")
    emit(*hollow_log("HollowLog", 9, 1.1), F + "Log")
    emit(*leaf_litter("LeafLitter", 60, 3.2), F + "Litter")
    flowers = [
        ("TulipsRed", "tulip", "tulip_red", 11),
        ("TulipsYellow", "tulip", "tulip_yellow", 10),
        ("Daisies", "daisy", "daisy_white", 12),
        ("Poppies", "poppy", "poppy_red", 9),
        ("Lavender", "lavender", "lavender", 8),
        ("BlueWildflowers", "wild", "wild_blue", 12),
        ("Sunflowers", "sunflower", "sunflower", 8),
        ("RosesRed", "rose", "tulip_red", 9),
        ("RosesPink", "rose", "blossom_deep", 9),
    ]
    for name, kind, colour, count in flowers:
        emit(*flower_clump(name, kind, colour, count), F + "Flower")
    emit(*reeds("Reeds", 18, 2.6, "reed"), F + "Aquatic")
    emit(*reeds("Cattails", 14, 3.0, "cattail"), F + "Aquatic")
    emit(*reeds("Rushes", 26, 2.0, "rush"), F + "Aquatic")
    emit(*arrowhead("Arrowhead"), F + "Aquatic")
    emit(*irises("Irises"), F + "Aquatic")
    emit(*lily_pad("LilyPadS", 0.7), F + "Aquatic")
    emit(*lily_pad("LilyPadM", 1.2), F + "Aquatic")
    emit(*lily_pad("LilyPadL", 1.8), F + "Aquatic")
    emit(*lily_flower("LilyFlowerWhite", "lily_white"), F + "Aquatic")
    emit(*lily_flower("LilyFlowerPink", "lily_pink"), F + "Aquatic")
    emit(*duckweed("Duckweed", 70, 3.0), F + "Aquatic")
    emit(*wet_rock("WetRockA", Vector((2.6, 2.0, 1.6))), F + "Aquatic")
    emit(*wet_rock("WetRockB", Vector((4.0, 3.0, 2.2))), F + "Aquatic")
    emit(*driftwood("Driftwood", 8), F + "Aquatic")
    emit(*stepping_stone("SteppingStone", 1.6), F + "Aquatic")
    emit(*floating_leaf("FloatingLeaf", "leaf_litter", 0.45), F + "Aquatic")
    emit(*floating_leaf("FloatingPetal", "blossom", 0.25), F + "Aquatic")
