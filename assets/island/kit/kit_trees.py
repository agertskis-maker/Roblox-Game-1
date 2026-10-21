# Island kit: trees and shrubs (Lane 3). Smooth faceted low-poly forms: tapering bent trunks
# with root buttresses sunk below ground, main and secondary branches, and uneven foliage
# clumps at the branch ends with openings between them. Each tree exports as two meshes:
# <Name>_Trunk (trunk, roots, branches) and <Name>_Canopy (foliage, blossom, fruit), so the
# canopy can sway on its own and the trunk gets simple collision. Variants differ in branch
# arrangement and silhouette, not only size or colour.

import math
import random

from mathutils import Vector

from kitlib import Builder, bent_path, clump, cone, tube

LEAF = ["leaf_shadow", "leaf_dark", "leaf_mid", "leaf_light", "leaf_sun"]
LEAF_COOL = ["pine_dark", "leaf_dark", "leaf_mid", "leaf_light", "leaf_light"]
BIRCH_LEAF = ["leaf_dark", "leaf_mid", "leaf_light", "leaf_sun", "leaf_sun"]
BLOSSOM = ["blossom_deep", "blossom", "blossom", "blossom_pale", "blossom_white"]
WILLOW = ["leaf_dark", "willow_dark", "willow_dark", "willow_light", "willow_light"]
PINE = ["pine_dark", "pine_mid", "pine_light"]
BARK = ["bark_warm", "bark_dark", "bark_warm", "bark_streak"]
# depth of trunk below the y 0 ground line; placement may sink a tree by up to this much
SINK = 2.0
BIRCH_BARK = ["birch_white", "birch_white", "birch_mark", "birch_white", "birch_grey"]


def roots(b, rng, base_r, count, spread, bark):
    """Root buttresses from the trunk flare, sinking into the ground."""
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.35, 0.35)
        d = Vector((math.cos(a), math.sin(a), 0))
        start = d * base_r * 0.55 + Vector((0, 0, base_r * rng.uniform(0.9, 1.6)))
        mid = d * base_r * spread * 0.55 + Vector((0, 0, base_r * 0.35))
        # the root hugs the ground at y 0 for most of its run, then dives below it, so on a
        # slope the placement can sink the tree to its lowest root without roots in the air
        mid = d * base_r * spread * 0.55 + Vector((0, 0, base_r * 0.18))
        end = d * base_r * spread * rng.uniform(0.9, 1.25) + Vector((0, 0, -SINK * 0.7))
        tube(b, [start, mid, end], [base_r * 0.46, base_r * 0.28, base_r * 0.1], 4, bark, rng=rng, jitter=0.1)


def branch(b, rng, start, direction, length, radius, bark, segments=4, bend=(0, 0, 0.3)):
    path = bent_path(start, direction, length, segments, bend, rng, wobble=0.12)
    radii = [radius * (1 - 0.75 * i / segments) for i in range(segments + 1)]
    tube(b, path, radii, 5 if radius > 0.35 else 4, bark, rng=rng, jitter=0.08)
    return path


def broadleaf(name, seed, p):
    """General broadleaf tree. p: dict of shape parameters (see the species below)."""
    rng = random.Random(seed)
    trunk = Builder(name + "_Trunk")
    canopy = Builder(name + "_Canopy")
    bark = p.get("bark", BARK)
    leaves = p.get("leaves", LEAF)
    tips = []
    trunks = p.get("trunks", 1)
    for t in range(trunks):
        lean = Vector(p.get("lean", (0, 0, 0)))
        if trunks > 1:
            a = 2 * math.pi * t / trunks + rng.uniform(-0.3, 0.3)
            lean = lean + Vector((math.cos(a), math.sin(a), 0)) * 0.28
        up = (Vector((0, 0, 1)) + lean).normalized()
        h = p["height"] * (1 if t == 0 else rng.uniform(0.75, 0.92))
        r = p["radius"] * (1 if t == 0 else 0.72)
        base = Vector((0, 0, -0.6)) + (lean.normalized() * r * 1.1 if trunks > 1 else Vector((0, 0, 0)))
        stem_len = h * p.get("stem", 0.6)
        path = bent_path(base, up, stem_len, 5, p.get("bend", (0.3, 0.1, 0)), rng, wobble=0.1)
        radii = [r * (1.25 - 0.55 * i / 5) for i in range(6)]
        # a flared plug below ground level (SINK studs) keeps the trunk embedded on slopes
        tube(trunk, [path[0] - Vector((0, 0, SINK))] + path, [r * 1.4] + radii, 6, bark, rng=rng, jitter=0.07, cap=False)
        if t == 0 and p.get("roots", 4):
            roots(trunk, rng, r, p.get("roots", 4), p.get("root_spread", 2.6), bark)
        top = path[-1]
        # leader continuing up
        if p.get("leader", True):
            lead = branch(trunk, rng, top, up, h - stem_len, radii[-1] * 0.9, bark, 3, bend=(0, 0, 0.2))
            tips.append((lead[-1], 1.0))
        n = p["branches"]
        for k in range(n):
            f = p.get("branch_from", 0.45) + (p.get("branch_to", 0.95) - p.get("branch_from", 0.45)) * (k + rng.uniform(0, 0.6)) / n
            i = min(len(path) - 1, int(f * (len(path) - 1)))
            at = path[i].lerp(path[min(i + 1, len(path) - 1)], rng.uniform(0, 1))
            if f > 0.97:
                at = top
            a = 2 * math.pi * (k / n) + p.get("twist", 0.9) * t + rng.uniform(-0.45, 0.45)
            rise = math.radians(rng.uniform(*p.get("rise", (25, 45))))
            d = Vector((math.cos(a) * math.cos(rise), math.sin(a) * math.cos(rise), math.sin(rise)))
            blen = p["branch_len"] * rng.uniform(0.75, 1.15)
            bpath = branch(trunk, rng, at, d, blen, r * p.get("branch_r", 0.55), bark, 4, bend=p.get("branch_bend", (0, 0, 0.25)))
            tips.append((bpath[-1], 1.0))
            # fuller crowns: a smaller clump on the outer half of each main branch
            if p.get("mid_clumps", True):
                tips.append((bpath[len(bpath) // 2 + 1], 0.7))
            for s in range(rng.randint(*p.get("secondary", (1, 2)))):
                j = rng.randint(1, len(bpath) - 2)
                a2 = a + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1)
                d2 = Vector((math.cos(a2), math.sin(a2), math.tan(rise) * 0.8 + 0.4)).normalized()
                spath = branch(trunk, rng, bpath[j], d2, blen * rng.uniform(0.4, 0.6), r * 0.18, bark, 3)
                tips.append((spath[-1], 0.75))
    # foliage clumps at the tips, uneven, overlapping selectively
    size = p["clump"]
    flatten = p.get("flatten", 0.8)
    extra = p.get("extra")
    for tip, scale in tips:
        count = rng.randint(*p.get("per_tip", (1, 2)))
        for c in range(count):
            off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.4, 0.8))) * size * 0.55 * c
            sz = Vector((size, size, size)) * scale * rng.uniform(0.72, 1.18)
            sz.x *= rng.uniform(0.85, 1.2)
            sz.y *= rng.uniform(0.85, 1.2)
            # set slightly into the branch tip so the branch disappears into the foliage
            clump(canopy, tip + off - Vector((0, 0, size * 0.12)), sz, rng, leaves, flatten=flatten, droop=p.get("droop", 0), subdiv=2 if size * scale > 1.4 else 1)
            if extra == "fruit":
                for _ in range(rng.randint(2, 4)):
                    fpos = tip + off + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.9, 0.1))) * size * 0.8
                    clump(canopy, fpos, Vector((0.38, 0.38, 0.42)), rng, [p.get("fruit", "fruit_red")] * 2 + ["fruit_orange"], subdiv=0)
    if p.get("curtain"):
        # willow: hanging strands from the outer tips
        for tip, scale in tips:
            for _ in range(rng.randint(2, 3)):
                hang = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * size * 0.6
                length = p["curtain"] * rng.uniform(0.7, 1.1)
                centre = tip + hang + Vector((0, 0, -length * 0.45))
                clump(canopy, centre, Vector((size * 0.32, size * 0.32, length * 0.5)), rng, WILLOW, flatten=1.0)
    meta = {
        "height": max(t[0].z for t in tips) + size,
        "trunk_radius": p["radius"],
        "canopy_base": min(t[0].z for t in tips) - size,
        "sink": SINK,
        "root_reach": p["radius"] * p.get("root_spread", 2.6) * 1.1,
    }
    return trunk, canopy, meta


def pine(name, seed, p):
    rng = random.Random(seed)
    trunk = Builder(name + "_Trunk")
    canopy = Builder(name + "_Canopy")
    h = p["height"]
    r = p["radius"]
    lean = Vector(p.get("lean", (0, 0, 0)))
    up = (Vector((0, 0, 1)) + lean).normalized()
    path = bent_path(Vector((0, 0, -0.5)), up, h * 0.92, 6, p.get("bend", (0.1, 0, 0)), rng, wobble=0.05)
    radii = [r * (1.2 - 0.95 * i / 6) for i in range(7)]
    tube(trunk, [path[0] - Vector((0, 0, SINK))] + path, [r * 1.35] + radii, 6, BARK, rng=rng, jitter=0.06)
    if p.get("roots", 3):
        roots(trunk, rng, r, p.get("roots", 3), 2.2, BARK)
    tiers = p["tiers"]
    start = p.get("first", 0.22)
    for k in range(tiers):
        f = start + (0.92 - start) * k / tiers
        i = min(len(path) - 2, int(f * (len(path) - 1)))
        at = path[i].lerp(path[i + 1], f * (len(path) - 1) - i)
        width = p["width"] * (1 - 0.78 * k / tiers) * rng.uniform(0.9, 1.1)
        th = p.get("tier_height", 0.34) * h / tiers * rng.uniform(1.6, 2.0)
        tilt = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0)) * width * p.get("tilt", 0.2)
        cone(canopy, at, th, width, p.get("sides", 7), PINE, rng, droop=p.get("droop", 0.28), tip_offset=tilt)
    meta = {"height": h, "trunk_radius": r, "canopy_base": h * start, "sink": SINK, "root_reach": r * 2.4}
    return trunk, canopy, meta


def bush(name, seed, p):
    rng = random.Random(seed)
    b = Builder(name)
    n = p["clumps"]
    size = p["size"]
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.4, 0.4)
        d = rng.uniform(0.2, 0.75) * size if k else 0
        c = Vector((math.cos(a) * d, math.sin(a) * d, size * rng.uniform(0.45, 0.85)))
        s = Vector((size, size, size * 0.85)) * rng.uniform(0.6, 1.0)
        clump(b, c, s, rng, p.get("leaves", LEAF), flatten=0.85, subdiv=2)
    for _ in range(p.get("dots", 0)):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.3, 1.0) * size
        c = Vector((math.cos(a) * rr, math.sin(a) * rr, size * rng.uniform(0.6, 1.4)))
        clump(b, c, Vector((0.32, 0.32, 0.32)) * p.get("dot_size", 1), rng, [p["dot"]] * 3, subdiv=0)
    return b, {"height": size * 1.7, "sink": 0.4, "root_reach": size * 0.9}


# ---------------------------------------------------------------- species and variants
TREES = {
    # broad oak-like: thick trunk, wide spreading crown
    "Oak": [
        dict(height=20, radius=1.25, branches=5, branch_len=8.5, rise=(22, 38), clump=4.6, per_tip=(1, 2), flatten=0.78, roots=5, secondary=(1, 2), lean=(0.05, 0, 0)),
        dict(height=17, radius=1.1, branches=4, branch_len=9.5, rise=(15, 30), clump=4.2, per_tip=(1, 2), flatten=0.7, roots=4, secondary=(2, 3), stem=0.5, lean=(0, 0.12, 0), bend=(0.5, 0, 0)),
        dict(height=22, radius=1.4, branches=3, branch_len=7.5, rise=(35, 55), clump=5.2, per_tip=(2, 3), flatten=0.85, roots=5, secondary=(1, 2), stem=0.65, leaves=LEAF_COOL),
    ],
    # tall tree with separate canopy tiers on side branches (ref5 structure)
    "Tiered": [
        dict(height=28, radius=0.95, branches=5, branch_len=6, rise=(5, 18), clump=4.4, per_tip=(1, 1), flatten=0.38, roots=4, secondary=(0, 1), stem=0.85, branch_from=0.35, branch_to=0.95, twist=2.4, mid_clumps=False),
        dict(height=32, radius=1.05, branches=6, branch_len=5.2, rise=(8, 20), clump=3.8, per_tip=(1, 1), flatten=0.34, roots=3, secondary=(0, 0), stem=0.9, branch_from=0.3, branch_to=0.97, twist=2.0, lean=(0.08, 0.04, 0), mid_clumps=False),
        dict(height=25, radius=0.9, branches=4, branch_len=7, rise=(2, 14), clump=5.0, per_tip=(1, 2), flatten=0.4, roots=4, secondary=(0, 1), stem=0.8, branch_from=0.45, branch_to=0.95, twist=1.6, bend=(0.6, 0, 0), mid_clumps=False),
    ],
    # wide flat-topped umbrella crown
    "Umbrella": [
        dict(height=16, radius=0.85, branches=5, branch_len=9, rise=(28, 40), clump=4.2, per_tip=(2, 2), flatten=0.34, roots=4, secondary=(1, 2), stem=0.82, branch_from=0.9, branch_to=1.0, leader=False, branch_bend=(0, 0, -0.15), branch_r=0.7),
        dict(height=14, radius=0.95, branches=4, branch_len=10.5, rise=(18, 30), clump=4.6, per_tip=(2, 3), flatten=0.3, roots=5, secondary=(1, 1), stem=0.75, branch_from=0.88, branch_to=1.0, leader=False, lean=(0.18, 0, 0), bend=(0.8, 0, 0), branch_r=0.72),
        dict(height=18, radius=0.8, branches=6, branch_len=8, rise=(32, 46), clump=3.8, per_tip=(1, 2), flatten=0.32, roots=3, secondary=(1, 2), stem=0.86, branch_from=0.92, branch_to=1.0, leader=False, branch_r=0.68),
    ],
    # pale-bark birch, airy, incl. multi-trunk forms
    "Birch": [
        dict(height=19, radius=0.45, branches=5, branch_len=4, rise=(45, 65), clump=2.4, per_tip=(1, 2), flatten=0.95, roots=3, secondary=(1, 1), stem=0.7, bark=BIRCH_BARK, leaves=BIRCH_LEAF, branch_r=0.5),
        dict(height=17, radius=0.38, trunks=3, branches=3, branch_len=3.4, rise=(50, 70), clump=2.2, per_tip=(1, 2), flatten=0.95, roots=0, secondary=(0, 1), stem=0.75, bark=BIRCH_BARK, leaves=BIRCH_LEAF, branch_r=0.5),
        dict(height=21, radius=0.42, trunks=2, branches=4, branch_len=3.8, rise=(42, 62), clump=2.6, per_tip=(1, 1), flatten=1.0, roots=2, secondary=(1, 1), stem=0.72, bark=BIRCH_BARK, leaves=BIRCH_LEAF, branch_r=0.5, lean=(0.06, 0, 0)),
    ],
    # blossom tree
    "Blossom": [
        dict(height=12, radius=0.7, branches=4, branch_len=5.5, rise=(30, 48), clump=3.2, per_tip=(1, 2), flatten=0.78, roots=4, secondary=(1, 2), stem=0.5, leaves=BLOSSOM, bend=(0.4, 0.2, 0)),
        dict(height=10, radius=0.62, branches=5, branch_len=6.2, rise=(18, 34), clump=2.9, per_tip=(1, 2), flatten=0.7, roots=3, secondary=(1, 2), stem=0.45, leaves=BLOSSOM, lean=(0.15, 0, 0), bend=(0.7, 0, 0)),
        dict(height=13, radius=0.75, branches=3, branch_len=4.8, rise=(42, 60), clump=3.6, per_tip=(2, 2), flatten=0.85, roots=4, secondary=(1, 1), stem=0.55, leaves=BLOSSOM),
    ],
    # weeping willow: arching branches with hanging curtains
    "Willow": [
        dict(height=14, radius=1.05, branches=5, branch_len=7, rise=(35, 55), clump=3.6, per_tip=(1, 1), flatten=0.7, roots=5, secondary=(1, 1), stem=0.55, leaves=WILLOW, curtain=8, branch_bend=(0, 0, -0.5)),
        dict(height=12, radius=0.95, branches=4, branch_len=8, rise=(25, 40), clump=3.4, per_tip=(1, 1), flatten=0.65, roots=4, secondary=(1, 2), stem=0.5, leaves=WILLOW, curtain=7, lean=(0.14, 0, 0), branch_bend=(0, 0, -0.6)),
        dict(height=15, radius=1.1, branches=6, branch_len=6, rise=(45, 60), clump=3.2, per_tip=(1, 1), flatten=0.75, roots=5, secondary=(0, 1), stem=0.6, leaves=WILLOW, curtain=9.5, branch_bend=(0, 0, -0.45)),
    ],
    # small fruit tree
    "Fruit": [
        dict(height=8, radius=0.5, branches=4, branch_len=3.6, rise=(30, 48), clump=2.5, per_tip=(1, 2), flatten=0.85, roots=3, secondary=(1, 1), stem=0.5, extra="fruit", fruit="fruit_red"),
        dict(height=7, radius=0.45, branches=3, branch_len=3.2, rise=(38, 55), clump=2.7, per_tip=(2, 2), flatten=0.9, roots=3, secondary=(0, 1), stem=0.55, extra="fruit", fruit="fruit_orange", lean=(0.1, 0, 0)),
        dict(height=9, radius=0.52, branches=5, branch_len=3.4, rise=(25, 40), clump=2.3, per_tip=(1, 1), flatten=0.8, roots=4, secondary=(1, 2), stem=0.45, extra="fruit", fruit="fruit_yellow", bend=(0.5, 0, 0)),
    ],
}
PINES = {
    "Pine": [
        dict(height=24, radius=0.7, tiers=6, width=6.5, droop=0.3, sides=7, first=0.24),
        dict(height=30, radius=0.85, tiers=7, width=7.2, droop=0.36, sides=8, first=0.3, lean=(0.06, 0, 0), tilt=0.3),
        dict(height=19, radius=0.6, tiers=5, width=6.0, droop=0.24, sides=6, first=0.18, bend=(0.3, 0, 0)),
    ],
    "PineSapling": [dict(height=5.5, radius=0.2, tiers=3, width=2.0, droop=0.2, sides=6, first=0.2, roots=0)],
}
BUSHES = {
    "BushSmall": dict(clumps=3, size=1.4),
    "BushMedium": dict(clumps=5, size=2.0),
    "BushLarge": dict(clumps=7, size=2.8, leaves=LEAF_COOL),
    "BerryBush": dict(clumps=5, size=1.9, dots=14, dot="berry"),
    "FloweringShrub": dict(clumps=5, size=2.1, dots=18, dot="shrub_flower", dot_size=1.3),
}


def build_all(emit):
    """Calls emit(builder, meta, family) for every tree, pine, sapling and bush."""
    for family, variants in TREES.items():
        for i, p in enumerate(variants):
            name = f"{family}{chr(65 + i)}"
            trunk, canopy, meta = broadleaf(name, sum(map(ord, name)) * 13 + i, p)
            meta["family"] = family
            emit(trunk, dict(meta, part="trunk"), family)
            emit(canopy, dict(meta, part="canopy"), family)
    for family, variants in PINES.items():
        for i, p in enumerate(variants):
            name = f"{family}{chr(65 + i)}" if len(variants) > 1 else family
            trunk, canopy, meta = pine(name, sum(map(ord, name)) * 7, p)
            meta["family"] = family
            emit(trunk, dict(meta, part="trunk"), family)
            emit(canopy, dict(meta, part="canopy"), family)
    for name, p in BUSHES.items():
        b, meta = bush(name, sum(map(ord, name)) * 11, p)
        meta["family"] = "Bush"
        emit(b, meta, "Bush")
