# Dusty Highway kit (Lane 3, Round 2, R2-DH1): the desert World's lots, landmarks, props, hazards and distant masses,
# built with the same grammar as the Downtown B2 kit (kit_world_lib: B2-style builder, lot frame, swatch palette).
# An optimistic desert road trip at golden hour: broad red-rock forms, warm cream road, terracotta sand, selective
# turquoise accents. Everything is original and fictional. Names: DH_Lot_*, DH_LM_*, DH_Prop_*, DH_Haz_*, DH_Mid_*,
# DH_Sky_*, matching Worlds/DustyHighway.luau exactly.
#
# Hazards are SCENERY previews (sinkhole, sand drift, rockslide crew); canyon or collapsed-bridge gaps exist only in a
# marked hazard test area, never in the route. Orange/white is used only by hazards.

import math
import random

import kit_world_lib as L
from kit_b2lib import sock
from kitlib import V, beam, box, cyl, prism, tube, circle2

NEAR = "near"
WORLD = "DH"
ALL = ["CactusFlats", "DinerStrip", "RedRockArches", "CanyonBridge", "MirageDunes"]


def rng_of(name):
    return random.Random(sum(map(ord, name)) * 31 + len(name))


def finish(b, w, d, h, cls, districts, shop=False, family="Lot", module="scenery", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, family, module, w, d, h, cls, districts, sockets, shop, **kw)


# ---------------------------------------------------------------- strata and masses
def strata_block(b, cx, cz, w, d, y0, h, bands, tops=True, inset=0.0):
    """A rock block built from horizontal strata (dark at the bottom, light at the top) with a lit top."""
    n = len(bands)
    for i, sw in enumerate(bands):
        hh = h / n
        k = inset * (i / max(1, n - 1))
        box(b, V(cx, y0 + hh * i + hh / 2, cz), (w - 2 * k, hh, d - 2 * k), {"side": sw, "top": sw, "skip_bottom": True})
    if tops:
        box(b, V(cx, y0 + h + 0.25, cz), (w - 2 * inset, 0.5, d - 2 * inset), {"side": "r_top", "top": "r_top", "skip_bottom": True})


def mound(b, cx, cz, rx, rz, h, rng, swatches, rings=3, segs=12, y0=0.0):
    """A smooth dune or snow mound: concentric elliptical rings rising to an apex, each ring one swatch."""
    pts = []
    for r in range(rings + 1):
        t = r / rings
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            j = 1.0 + (rng.random() - 0.5) * 0.12 * (1 - t)
            ring.append(V(cx + math.cos(a) * rx * (1 - t * 0.95) * j, y0 + h * (1 - (1 - t) ** 2.2) if r else y0, cz + math.sin(a) * rz * (1 - t * 0.95) * j))
        pts.append(ring)
    for r in range(rings):
        sw = swatches[min(len(swatches) - 1, r)]
        for k in range(segs):
            k2 = (k + 1) % segs
            q = [pts[r][k], pts[r][k2], pts[r + 1][k2], pts[r + 1][k]]
            cen = sum(q, V(0)) / 4
            b.face(q, sw, V(cen.x - cx, 1.0, cen.z - cz))
    b.face(pts[rings], swatches[-1], V(0, 1, 0))


# ---------------------------------------------------------------- lots
def cactus_lot(name, w, n, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0
    L.pad(b, w, d, "g_sand", 0.4)
    for i in range(n):
        x = -w / 2 + (i + 0.5) * w / n + (rng.random() - 0.5) * 3
        L.cactus(b, x, 5 + rng.random() * (d - 10), h * (0.65 + 0.35 * rng.random()), rng, arms=rng.choice([0, 1, 2, 2]))
    for _ in range(3):
        L.rock(b, -w / 2 + rng.random() * w, 3 + rng.random() * (d - 6), 2.4, 1.8, 2.2, rng, y=0.3)
    return finish(b, w, d, h + 0.5, "low", ["CactusFlats", "DinerStrip", "MirageDunes"])


def scrub_lot(name, w, h, districts):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0 if w < 30 else 22.0
    L.pad(b, w, d, "g_sand", 0.4)
    for i in range(int(w // 6)):
        x = -w / 2 + 3 + i * 6 + rng.random() * 2
        z = 3 + rng.random() * (d - 6)
        r = 2.0 + rng.random() * 1.6
        from kitlib import sphere

        sphere(b, V(x, 0.4 + r * 0.7, z), (r, r * 0.7, r), ["p_dark", "p_mid", "p_light", "p_light"], subdiv=0, rng=rng, jitter=0.2)
    for _ in range(2):
        L.rock(b, -w / 2 + rng.random() * w, 3 + rng.random() * (d - 6), 3.0, 2.2, 2.8, rng, y=0.3)
    return finish(b, w, d, h, "low", districts)


def rocks_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_lo", 0.4)
    for i in range(6):
        sx = 5 + rng.random() * 6
        L.rock(b, -w / 2 + 4 + (w - 8) * i / 5 + rng.random() * 2, 4 + rng.random() * (d - 8), sx, h * (0.6 + 0.4 * rng.random()), sx * 0.9, rng, y=0.3, subdiv=1)
    return finish(b, w, d, h, "low", ["CactusFlats", "RedRockArches", "CanyonBridge", "MirageDunes"])


def adobe_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 18.0
    L.pad(b, w, d, "g_sand", 0.4)
    L.plain_building(b, w - 4, 14.0, h, "w_wall_1", "w_wall_2", "w_roof_flat", "w_door", windows=2, y0=0.4)
    for i in range(5):  # vigas: round beam ends under the roofline
        cyl(b, V(-8 + i * 4, h - 1.6, -0.2), 0.9, 0.45, 5, "m_wood_2", top=True)
    box(b, V(w * 0.2, h + 2.2, 8), (3.0, 4.4, 3.0), {"side": "w_wall_1", "top": "w_trim_1", "skip_bottom": True})
    L.cactus(b, -w / 2 + 2.6, 2.0, 6.0, rng, arms=1)
    return finish(b, w, d, h + 1.0, "low", ["CactusFlats", "DinerStrip", "MirageDunes"])


def corral_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_track", 0.4)
    for i in range(int(w // 4) + 1):
        x = -w / 2 + 1.5 + i * (w - 3) / int(w // 4)
        box(b, V(x, 2.2, 1.5), (0.6, 4.4, 0.6), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    for y in (1.6, 3.2):
        box(b, V(0, y, 1.5), (w - 2.4, 0.5, 0.4), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    for z in (d - 1.5,):
        for y in (1.6, 3.2):
            box(b, V(0, y, z), (w - 2.4, 0.5, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(-w * 0.25, 1.2, d * 0.5), (7.0, 1.6, 2.2), {"side": "m_wood_2", "top": "g_water", "skip_bottom": True})  # trough
    for k in range(5):
        box(b, V(w * 0.22 + (k % 3) * 3.3, 1.0 + (k // 3) * 2.0, d * 0.55), (3.0, 2.0, 2.2), {"side": "w_accent_3", "top": "g_hi", "skip_bottom": True})  # hay
    box(b, V(w * 0.3, 4.0, d - 4), (10.0, 8.0, 6.0), {"side": "w_wall_1", "top": "w_roof_2", "skip_bottom": True})
    return finish(b, w, d, 8.5, "low", ["CactusFlats"])


def motel_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0
    L.pad(b, w, d, "g_sand", 0.4)
    box(b, V(0, h / 2, 11), (w - 2, h, 14), {"side": "w_wall_2", "top": "w_roof_flat", "skip_bottom": True})
    box(b, V(0, h + 0.5, 11), (w - 1.2, 1.0, 14.6), {"side": "w_trim_1", "top": "w_roof_flat", "skip_bottom": True})
    for i in range(6):  # doors and windows in a row on the front wall
        x = -w / 2 + 5 + i * (w - 10) / 5
        b.face([V(x - 1.6, 0.4, 3.99), V(x + 1.6, 0.4, 3.99), V(x + 1.6, 8.4, 3.99), V(x - 1.6, 8.4, 3.99)], "w_door", V(0, 0, -1))
        b.face([V(x + 2.6, 4.0, 3.99), V(x + 5.0, 4.0, 3.99), V(x + 5.0, 8.0, 3.99), V(x + 2.6, 8.0, 3.99)], "w_glass", V(0, 0, -1)) if i < 5 else None
    box(b, V(0, 10.5, 3.0), (w - 1.0, 0.6, 3.0), {"side": "w_accent_1", "top": "w_accent_1", "skip_bottom": True})  # a turquoise walkway roof
    for x in (-w / 2 + 2, w / 2 - 2):
        box(b, V(x, 5.2, 1.8), (0.6, 10.4, 0.6), {"side": "w_trim_1", "skip_bottom": True})
    # roadside sign pole at the left end, board facing the road both ways
    cyl(b, V(-w / 2 + 3, 0.4, -1.0), 20.0, 0.5, 5, "m_metal_dark", r_top=0.45)
    box(b, V(-w / 2 + 3, 20.5, -1.0), (0.8, 6.0, 8.0), {"side": "m_sign", "top": "m_sign_frame", "skip_bottom": True})
    box(b, V(-w / 2 + 3, 24.2, -1.0), (1.0, 1.4, 8.4), {"side": "w_accent_2", "top": "w_accent_2", "skip_bottom": True})
    return finish(b, w, d, 25.0, "low", ["DinerStrip"], shop=True, module="shop")


def stand_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 16.0
    L.pad(b, w, d, "g_sand", 0.4)
    for x in (-w / 2 + 2.0, w / 2 - 2.0):
        box(b, V(x, 4.2, 4.0), (0.6, 8.4, 0.6), {"side": "m_wood_2", "skip_bottom": True})
        box(b, V(x, 5.0, 11.0), (0.6, 10.0, 0.6), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 9.4, 7.5), (w - 1.0, 0.7, 11.0), {"side": "w_accent_1", "top": "w_accent_1", "skip_bottom": True})  # plain turquoise canvas roof
    box(b, V(0, 8.9, 3.6), (w - 1.0, 1.0, 1.0), {"side": "w_wall_2", "top": "w_wall_2", "skip_bottom": True})  # cream valance
    box(b, V(0, 2.0, 4.4), (w - 4.0, 3.6, 2.0), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})  # counter
    box(b, V(0, 1.0, 13.0), (w - 3.0, 2.0, 2.2), {"side": "m_wood_2", "skip_bottom": True})  # back shelf
    for i in range(4):
        box(b, V(-w / 2 + 4 + i * (w - 8) / 3, 4.1, 4.4), (2.2, 1.0, 1.8), {"side": "p_flower" if i % 2 else "w_accent_3", "top": "p_light", "skip_bottom": True})  # crates of fruit
    return finish(b, w, d, 10.0, "low", ["DinerStrip", "MirageDunes"], shop=True, module="shop")


def garage_lot(name, w, h):
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_track", 0.4)
    box(b, V(0, 6.0, 13), (w - 4, 12.0, 16), {"side": "w_wall_4", "top": "w_roof_flat", "skip_bottom": True})
    # gable roof along x
    hw = (w - 3) / 2
    for s in (-1, 1):
        b.face([V(-hw, 12, 13 + s * 9), V(hw, 12, 13 + s * 9), V(hw, 16, 13), V(-hw, 16, 13)], "w_roof_1", V(0, 1, s))
    for sx in (-1, 1):  # the two gable ends
        b.face([V(sx * hw, 12.0, 4.0), V(sx * hw, 12.0, 22.0), V(sx * hw, 16.0, 13.0)], "w_wall_4", V(sx, 0, 0))
    for i in range(2):  # two dark bay doors on the front
        x = -w * 0.2 + i * w * 0.4
        b.face([V(x - 4.2, 0.4, 4.99), V(x + 4.2, 0.4, 4.99), V(x + 4.2, 9.0, 4.99), V(x - 4.2, 9.0, 4.99)], "m_metal_dark", V(0, 0, -1))
        box(b, V(x, 9.4, 4.7), (9.4, 0.8, 0.8), {"side": "w_trim_1", "skip_back": True})
    for x in (-w * 0.3, w * 0.3):  # two old pumps on a kerbed island
        box(b, V(x, 0.8, 1.2), (3.6, 0.8, 2.4), {"side": "m_stone", "top": "g_hi", "skip_bottom": True})
        box(b, V(x, 3.2, 1.2), (1.4, 4.0, 1.2), {"side": "w_accent_2", "top": "m_white", "skip_bottom": True})
    return finish(b, w, d, 16.0, "low", ["DinerStrip"], shop=True, module="shop")


def mesa_lot(name, w, h, d=24.0):
    rng = rng_of(name)
    b = L.new(name)
    L.pad(b, w, d, "g_lo", 0.4)
    tiers = 4
    y = 0.4
    cw, cd = w * 0.98, d * 0.96
    for i in range(tiers):
        th = (h - 0.4) * (0.34 if i == 0 else 0.22 if i < 3 else 0.22)
        strata_block(b, (rng.random() - 0.5) * 2 * (1 - i * 0.2), d / 2, cw, cd, y, th, ["r_1", "r_2"] if i == 0 else ["r_2", "r_3"] if i == 1 else ["r_3", "r_4"], tops=(i == tiers - 1), inset=0.0)
        y += th
        cw *= 0.82 - rng.random() * 0.06
        cd *= 0.84
    return finish(b, w, d, h, "mid", ["RedRockArches", "CanyonBridge"])


def pillar_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_lo", 0.4)
    y = 0.4
    r = w * 0.4
    for i in range(5):
        seg = (h - 0.4) / 5
        cyl(b, V(0, y, d / 2), seg, r, 6, ["r_1", "r_2", "r_3", "r_4", "r_3"][i], r_top=r * (0.82 if i < 4 else 0.9), top_sw="r_top", phase=0.2 * i)
        y += seg
        r *= 0.86 if i < 3 else 1.05
    return finish(b, w, d, h, "mid", ["RedRockArches"])


def hoodoo_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_lo", 0.4)
    cyl(b, V(0, 0.4, d / 2), h * 0.62, w * 0.34, 6, "r_2", r_top=w * 0.2, top_sw="r_3")
    cyl(b, V(0, 0.4 + h * 0.62, d / 2), h * 0.1, w * 0.2, 6, "r_1", r_top=w * 0.3, top_sw="r_3")
    cyl(b, V(0, 0.4 + h * 0.72, d / 2), h * 0.26, w * 0.46, 6, "r_3", r_top=w * 0.38, top_sw="r_top", phase=0.4)
    return finish(b, w, d, h, "mid", ["RedRockArches", "MirageDunes"])


def cliff_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    L.pad(b, w, d, "g_lo", 0.4)
    strata_block(b, 0, d - 8, w, 14.0, 0.4, h * 0.55, ["r_1", "r_2", "r_1", "r_2"], tops=False)
    strata_block(b, 0, d - 6, w * 0.88, 11.0, 0.4 + h * 0.55, h * 0.45, ["r_3", "r_4", "r_3"], tops=True)
    # a talus slope at the foot (a wedge toward the road)
    b.face([V(-w / 2, 0.4, d - 15), V(w / 2, 0.4, d - 15), V(w / 2, h * 0.3, d - 15), V(-w / 2, h * 0.3, d - 15)], "r_shadow", V(0, 0, -1))
    b.face([V(-w / 2, 0.4, d - 15), V(w / 2, 0.4, d - 15), V(w / 2, 0.4, 5), V(-w / 2, 0.4, 5)], "g_lo", V(0, 1, 0))
    b.face([V(-w / 2, 0.4, 5), V(w / 2, 0.4, 5), V(w / 2, h * 0.3, d - 15), V(-w / 2, h * 0.3, d - 15)], "r_2", V(0, 1, -0.6))
    return finish(b, w, d, h, "mid", ["CanyonBridge"])


def ridge_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_lo", 0.4)
    for z0, z1, hh, sw in ((d, 8.0, h, "r_2"), (8.0, 0.0, h * 0.25, "r_3")):
        b.face([V(-w / 2, 0.4, z0), V(w / 2, 0.4, z0), V(w / 2, hh, z0 - 3), V(-w / 2, hh, z0 - 3)], "r_1", V(0, 0, 1))
        b.face([V(-w / 2, hh, z0 - 3), V(w / 2, hh, z0 - 3), V(w / 2, 0.4, z1), V(-w / 2, 0.4, z1)], sw, V(0, 1, -1))
    for s in (-1, 1):
        b.face([V(s * w / 2, 0.4, d), V(s * w / 2, h, d - 3), V(s * w / 2, 0.4, 0.0)], "r_shadow", V(s, 0, 0))
    return finish(b, w, d, h, "low", ["CanyonBridge", "RedRockArches"])


def dune_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    mound(b, 0, d / 2, w * 0.5, d * 0.5, h, rng, ["g_lo", "g_sand", "g_hi"], y0=0.0)
    mound(b, w * 0.18, d * 0.6, w * 0.3, d * 0.36, h * 0.7, rng, ["g_sand", "g_hi", "g_hi"], y0=0.0)
    L.rock(b, -w * 0.3, d * 0.3, 2.4, 1.6, 2.2, rng, y=0.0)
    return finish(b, w, d, h, "low", ["MirageDunes", "CactusFlats"])


def hut_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_sand", 0.4)
    L.plain_building(b, w - 6, 13.0, h - 2.5, "m_wood_2", "m_wood_1", "w_roof_2", "m_metal_dark", windows=2, parapet=False, y0=0.4, x=-1.0)
    # a lopsided gable roof
    hw = (w - 6) / 2
    b.face([V(-hw - 1.0, h - 2.1, -0.6), V(hw - 1.0 + 1.0, h - 2.1, -0.6), V(hw + 1.0, h + 1.2, 6.5), V(-hw - 1.0, h + 0.4, 6.5)], "w_roof_2", V(0, 1, -1))
    b.face([V(-hw - 1.0, h + 0.4, 6.5), V(hw + 1.0, h + 1.2, 6.5), V(hw + 1.0, h - 2.1, 14.0), V(-hw - 1.0, h - 2.1, 14.0)], "m_wood_1", V(0, 1, 1))
    for i in range(3):
        box(b, V(w / 2 - 2.0, 1.4, 3.0 + i * 3.4), (0.4, 2.8, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    from kitlib import sphere

    sphere(b, V(-w / 2 + 3.0, 1.7, 1.5), (1.6, 1.3, 1.6), ["m_wood_2", "m_wood_1", "g_hi"], subdiv=0, rng=rng, jitter=0.3)  # a tumbleweed
    return finish(b, w, d, h, "low", ["MirageDunes", "DinerStrip"])


def oasis_lot(name, w):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    L.pad(b, w, d, "p_light", 0.4)
    ring = circle2(w * 0.1, d * 0.5, min(8.0, w * 0.26), 10)
    b.face([V(x, 0.45, z) for x, z in ring], "g_water", V(0, 1, 0))
    for x, z in circle2(w * 0.1, d * 0.5, min(8.0, w * 0.26) + 0.9, 10, phase=0.3):
        L.rock(b, x, z, 1.4, 0.9, 1.3, rng, y=0.3)
    for i in range(3 if w > 30 else 2):
        L.palm(b, -w / 2 + 4 + i * (w - 8) / (2 if w > 30 else 1), 5 + rng.random() * 14, 12.0 + rng.random() * 3, rng)
    box(b, V(w * 0.3, 0.9, 4.0), (5.0, 0.8, 1.6), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})  # a bench
    return finish(b, w, d, 15.5, "low", ALL, module="park")


def rest_lot(name, w):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    L.pad(b, w, d, "g_hi", 0.4)
    for x in (-w * 0.3, w * 0.3):
        for z in (6.0, 18.0):
            box(b, V(x, 5.2, z), (0.7, 10.0, 0.7), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 10.4, 12.0), (w * 0.7, 0.8, 16.0), {"side": "m_wood_1", "top": "w_roof_flat", "skip_bottom": True})
    for k in range(5):
        box(b, V(0, 10.9, 5.0 + k * 3.5), (w * 0.7, 0.3, 0.5), {"side": "m_wood_2", "skip_bottom": True})  # slats on the shade roof
    for x in (-w * 0.15, w * 0.15):
        box(b, V(x, 1.8, 12.0), (7.0, 0.6, 2.4), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
        box(b, V(x, 1.0, 12.0), (5.0, 1.2, 1.6), {"side": "m_wood_2", "skip_bottom": True})
    L.cactus(b, w * 0.42, 3.0, 6.0, rng, arms=1)
    return finish(b, w, d, 11.0, "mid", ["CactusFlats", "DinerStrip", "MirageDunes"], module="plaza")


# ---------------------------------------------------------------- landmarks
def lm_finish(b, w, d, h, districts, placement="frontage", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, "LM", "landmark", w, d, h, "landmark", districts, sockets, False, placement=placement, **kw)


def windmill(name):
    b = L.new(name)
    w, d, h = 32.0, 32.0, 66.0
    L.pad(b, 26.0, 26.0, "g_lo", 0.4, z=2.0)
    legs = [(-5, 5), (5, 5), (5, 15), (-5, 15)]
    top = [(-2, 8), (2, 8), (2, 12), (-2, 12)]
    for (x0, z0), (x1, z1) in zip(legs, top):
        beam(b, V(x0, 0.4, z0 + 4), V(x1, 48.0, z1 + 4), 0.9, 0.9, "m_wood_2")
    def leg(i, t):
        (x0, z0), (x1, z1) = legs[i], top[i]
        return V(x0 + (x1 - x0) * t, 0.4 + 47.6 * t, z0 + 4 + (z1 - z0) * t)

    levels = (0.0, 0.25, 0.5, 0.75, 1.0)
    for j, t in enumerate(levels):
        if 0 < j < len(levels):
            for i in range(4):
                beam(b, leg(i, t), leg((i + 1) % 4, t), 0.5, 0.5, "m_wood_1")
        if j < len(levels) - 1:
            t2 = levels[j + 1]
            for i in range(4):
                beam(b, leg(i, t), leg((i + 1) % 4, t2), 0.4, 0.4, "m_wood_2")
    box(b, V(0, 49.2, 10.0), (6.0, 2.4, 6.0), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 54.0, 10.0), (4.4, 6.0, 4.4), {"side": "w_wall_2", "top": "w_roof_1", "skip_bottom": True})  # the gear housing
    # the wheel: twelve blades in the plane x = 0.. (disc normal along the road), hub at (x 2.6, y 54, z 10)
    hubx, hubz = 3.2, 10.0
    for k in range(12):
        a = 2 * math.pi * k / 12
        c, s = math.cos(a), math.sin(a)
        r0, r1 = 2.0, 13.0
        for sx in (-0.1, 0.1):
            pass
        b.face([V(hubx, 54.0 + s * r0, hubz + c * r0), V(hubx, 54.0 + s * r1 + c * 1.6, hubz + c * r1 - s * 1.6), V(hubx, 54.0 + s * r1 - c * 1.6, hubz + c * r1 + s * 1.6)], "m_metal" if k % 2 else "w_wall_2", V(1, 0, 0))
        b.face([V(hubx, 54.0 + s * r0, hubz + c * r0), V(hubx, 54.0 + s * r1 - c * 1.6, hubz + c * r1 + s * 1.6), V(hubx, 54.0 + s * r1 + c * 1.6, hubz + c * r1 - s * 1.6)], "m_metal" if k % 2 else "w_wall_2", V(-1, 0, 0))
    cyl(b, V(hubx, 54.0, hubz), 1.0, 1.2, 8, "w_accent_2", top=True)
    box(b, V(0, 55.0, 17.0), (0.4, 4.0, 8.0), {"side": "w_accent_1", "skip_bottom": True})  # tail vane
    beam(b, V(0, 54.0, 12.0), V(0, 55.0, 17.0), 0.5, 0.5, "m_wood_2")
    return lm_finish(b, w, d, h, ["CactusFlats"], read="windmill wheel faces the road both ways")


def cactus_garden(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 48.0, 24.0, 30.0
    L.pad(b, w, d, "g_lo", 0.4)
    box(b, V(0, 0.9, 0.8), (w - 1.0, 1.0, 1.4), {"side": "m_stone", "top": "m_stone", "skip_bottom": True})  # low stone border
    for i in range(5):
        L.cactus(b, -w / 2 + 6 + i * (w - 12) / 4, 8 + rng.random() * 10, 16.0 + 14.0 * (1 - abs(i - 2) / 2.5) * rng.random() + (4 if i == 2 else 0), rng, arms=2)
    from kitlib import sphere

    for i in range(6):
        r = 1.2 + rng.random() * 0.9
        sphere(b, V(-w / 2 + 5 + i * 8.6, 0.4 + r * 0.9, 4.0 + rng.random() * 3), (r, r * 0.9, r), ["p_dark", "p_mid", "p_light", "p_flower"], subdiv=0, rng=rng, jitter=0.1)
    return lm_finish(b, w, d, h, ["CactusFlats"])


def diner(name):
    b = L.new(name)
    w, d, h = 48.0, 24.0, 28.0
    L.pad(b, w, d, "g_track", 0.4)
    box(b, V(-2, 7.0, 13), (38.0, 14.0, 16), {"side": "w_wall_2", "top": "w_roof_flat", "skip_bottom": True})
    box(b, V(-2, 14.6, 13), (39.6, 1.2, 17.6), {"side": "w_accent_2", "top": "w_roof_flat", "skip_bottom": True})  # a coral roof band
    box(b, V(-2, 3.2, 4.9), (36.0, 1.4, 0.4), {"side": "w_accent_1", "skip_bottom": True})  # turquoise stripe
    b.face([V(-19, 4.6, 4.96), V(15, 4.6, 4.96), V(15, 10.6, 4.96), V(-19, 10.6, 4.96)], "w_glass", V(0, 0, -1))  # the long window band
    for i in range(7):
        box(b, V(-19 + i * 5.6, 7.6, 4.8), (0.5, 6.4, 0.4), {"side": "m_metal", "skip_bottom": True})
    box(b, V(-2, 9.8, 0.4), (40.0, 0.5, 8.0), {"side": "w_accent_1", "top": "w_accent_1", "skip_bottom": True})  # entrance canopy
    # the big roadside sign: a pole and a diamond board facing the road both ways
    cyl(b, V(18.0, 0.4, 1.5), 22.0, 0.6, 5, "m_metal_dark", r_top=0.5)
    pts = [(-3.0, 22.0), (0.0, 18.0), (3.0, 22.0), (0.0, 29.0)]
    for sx in (-1, 1):
        b.face([V(18.0 + sx * 0.5, y, 1.5 + z) for z, y in pts], "m_sign" if sx > 0 else "m_sign", V(sx, 0, 0))
    for sx in (-1, 1):
        b.face([V(18.0 + sx * 0.52, y, 1.5 + z * 0.62) for z, y in [(-3.0, 23.0), (0.0, 20.5), (3.0, 23.0), (0.0, 27.0)]], "w_accent_2", V(sx, 0, 0))
    return lm_finish(b, w, d, h, ["DinerStrip"], read="coral and turquoise diner with a diamond sign")


def pump_station(name):
    b = L.new(name)
    w, d, h = 48.0, 24.0, 18.0
    L.pad(b, w, d, "g_track", 0.4)
    for x in (-w * 0.38, w * 0.38):
        for z in (4.0, 12.0):
            box(b, V(x, 8.0, z), (0.9, 16.0, 0.9), {"side": "m_metal", "skip_bottom": True})
    box(b, V(0, 16.6, 8.0), (w * 0.82, 1.6, 12.0), {"side": "w_accent_1", "top": "m_white", "skip_bottom": True})
    box(b, V(0, 15.6, 2.2), (w * 0.82, 0.5, 0.4), {"side": "w_accent_2", "skip_bottom": True})
    for x in (-8.0, 8.0):
        box(b, V(x, 0.8, 8.0), (3.0, 0.8, 7.0), {"side": "m_stone", "top": "g_hi", "skip_bottom": True})
        box(b, V(x, 3.6, 8.0), (1.6, 4.8, 1.4), {"side": "w_accent_2", "top": "m_white", "skip_bottom": True})
        box(b, V(x, 5.6, 7.3), (1.2, 1.0, 0.2), {"side": "w_glass_light", "skip_bottom": True})
    box(b, V(w * 0.3, 5.0, 18.0), (12.0, 10.0, 6.0), {"side": "w_wall_4", "top": "w_roof_flat", "skip_bottom": True})
    box(b, V(w * 0.3, 10.5, 18.0), (12.8, 1.0, 6.8), {"side": "w_trim_1", "top": "w_roof_1", "skip_bottom": True})
    return lm_finish(b, w, d, h, ["DinerStrip"])


def rock_arch(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 72.0, 36.0, 56.0
    L.pad(b, w, d, "g_lo", 0.4)
    # twin base masses in strata and a thick arch swept over them (a 4-sided tube along a half circle)
    for s in (-1, 1):
        strata_block(b, s * 24.0, d / 2, 20.0 + 3 * rng.random(), 24.0, 0.4, 22.0, ["r_1", "r_2", "r_3"], tops=False)
    path = []
    n = 12
    for k in range(n + 1):
        a = math.pi * k / n
        path.append(V(math.cos(a) * 24.0, 22.0 + math.sin(a) * 26.0, d / 2))
    tube(b, path, 8.4, 4, ["r_3", "r_4"], phase=math.pi / 4)
    for k in range(1, n, 2):
        p = path[k]
        box(b, V(p.x, p.y + 4.4, p.z), (6.0, 2.0, 12.0), {"side": "r_top", "top": "r_top", "skip_bottom": True})
    box(b, V(-24.0, 23.0, d / 2), (14.0, 1.0, 20.0), {"side": "r_top", "top": "r_top", "skip_bottom": True})
    box(b, V(24.0, 23.0, d / 2), (14.0, 1.0, 20.0), {"side": "r_top", "top": "r_top", "skip_bottom": True})
    for _ in range(4):
        L.rock(b, -w / 2 + 6 + rng.random() * (w - 12), 3.0 + rng.random() * 6, 3.5, 2.5, 3.0, rng, y=0.3)
    return lm_finish(b, w, d, h, ["RedRockArches"], read="a sandstone arch seen through the opening")


def canyon_bridge(name):
    """CANYON BRIDGE (bridge landmark, 384 along the route, centred on the deck centre; the pivot is the deck centre
    at deck level). A rustic through-truss over the deck (clearance 26 > 18) and a cliff on each side of the span, so
    the road crosses a canyon. The deck, parapets and abutments are the shared B2_Road pieces."""
    b = L.new(name)
    ax = 50.8 + 1.6  # the truss stands just outside the deck edge (frontage 50.8 for W17), like the Harbor arches
    Lh = 192
    for s in (-1, 1):
        x = s * ax
        beam(b, V(x, 26.0, -Lh), V(x, 26.0, Lh), 1.8, 1.8, "bridge_steel")
        beam(b, V(x, 1.0, -Lh), V(x, 1.0, Lh), 1.4, 1.4, "bridge_steel_dark")
        for z in range(-Lh + 0, Lh + 1, 24):
            beam(b, V(x, 1.0, z), V(x, 26.0, z), 0.9, 0.9, "bridge_steel_dark")
        for z in range(-Lh, Lh, 48):
            beam(b, V(x, 1.0, z), V(x, 26.0, z + 24), 0.6, 0.6, "bridge_steel")
            beam(b, V(x, 26.0, z + 24), V(x, 1.0, z + 48), 0.6, 0.6, "bridge_steel")
    for z in range(-Lh + 24, Lh, 48):
        beam(b, V(-ax, 26.0, z), V(ax, 26.0, z), 1.2, 1.2, "bridge_steel")
    # the canyon: strata cliffs outside the sidewalks, stepping down toward the ends
    for s in (-1, 1):
        for k, (z0, z1, hh) in enumerate(((-192, -96, 24.0), (-96, 96, 46.0), (96, 192, 24.0))):
            strata_block(b, s * (ax + 16.0), (z0 + z1) / 2, 26.0, z1 - z0 - 2, 0.0, hh, ["r_1", "r_2", "r_3", "r_4"], tops=True)
    # rock pylons at the two ends of the truss
    for s in (-1, 1):
        for z in (-Lh + 6.0, Lh - 6.0):
            strata_block(b, s * ax, z, 5.0, 6.0, 0.0, 30.0, ["r_1", "r_2", "r_3"], tops=True)
    return b, L.lot_meta(WORLD, "LM", "landmark", 384.0, 0.0, 46.0, "landmark", ["CanyonBridge"], {"start": sock((0, 0, 192)), "end": sock((0, 0, -192))}, False, placement="bridge", pairs_with=["B2_Road_BridgeDeck192_L4W17", "B2_Road_Abutment96_L4W17"])


def cactus_sign(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 36.0, 22.0, 42.0
    L.pad(b, 14.0, 10.0, "g_lo", 0.4, z=8.0, x=0.0)
    cyl(b, V(0, 0.4, 13.0), 12.0, 1.0, 5, "m_metal_dark", r_top=0.9)
    # the board: a cactus silhouette standing in the plane x = 0 (faces +X and -X, along the road)
    outline = [(-2.0, 12.0), (2.0, 12.0), (2.0, 24.0), (6.0, 24.0), (6.0, 33.0), (9.0, 33.0), (9.0, 22.0), (12.0, 22.0), (12.0, 36.0), (9.0, 38.0), (5.0, 36.0), (5.0, 41.0), (0.0, 43.0), (-5.0, 41.0), (-5.0, 36.0), (-9.0, 38.0), (-12.0, 36.0), (-12.0, 22.0), (-9.0, 22.0), (-9.0, 30.0), (-6.0, 30.0), (-6.0, 24.0), (-2.0, 24.0)]
    for sx, sw in ((-1, "p_mid"), (1, "p_mid")):
        pts = [V(sx * 0.7, y, 13.0 + z) for z, y in outline]
        b.face(pts, sw, V(sx, 0, 0))
    for i in range(0, len(outline)):
        (z0, y0), (z1, y1) = outline[i], outline[(i + 1) % len(outline)]
        b.face([V(-0.7, y0, 13 + z0), V(0.7, y0, 13 + z0), V(0.7, y1, 13 + z1), V(-0.7, y1, 13 + z1)], "p_dark", V(0, (y0 + y1) / 2 - 27, (z0 + z1) / 2))
    for sx in (-1, 1):
        b.face([V(sx * 0.75, 26.0, 13.0 + 3.0), V(sx * 0.75, 26.0, 13.0 - 3.0), V(sx * 0.75, 32.0, 13.0 - 3.0), V(sx * 0.75, 32.0, 13.0 + 3.0)], "m_sign", V(sx, 0, 0))  # a text plate
    return lm_finish(b, w, d, h, ["MirageDunes"])


def ghost_huts(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 48.0, 24.0, 18.0
    L.pad(b, w, d, "g_sand", 0.4)
    for i, (hx, hw_, hh) in enumerate(((-15.0, 13.0, 12.0), (3.0, 11.0, 10.0), (18.0, 12.0, 14.0))):
        L.plain_building(b, hw_, 11.0, hh - 2.0, "m_wood_2", "m_wood_1", "w_roof_2", "m_metal_dark", windows=1, parapet=False, y0=0.4, x=hx)
        lean = (rng.random() - 0.5) * 2.4
        b.face([V(hx - hw_ / 2 - 0.8, hh - 1.6, -0.5), V(hx + hw_ / 2 + 0.8, hh - 1.6, -0.5), V(hx + hw_ / 2 + 0.8 + lean, hh + 1.6, 5.5), V(hx - hw_ / 2 - 0.8 + lean, hh + 1.6, 5.5)], "w_roof_2", V(0, 1, -1))
        b.face([V(hx - hw_ / 2 - 0.8 + lean, hh + 1.6, 5.5), V(hx + hw_ / 2 + 0.8 + lean, hh + 1.6, 5.5), V(hx + hw_ / 2 + 0.8, hh - 1.6, 11.5), V(hx - hw_ / 2 - 0.8, hh - 1.6, 11.5)], "m_wood_1", V(0, 1, 1))
    from kitlib import sphere

    for i in range(3):
        sphere(b, V(-w / 2 + 6 + i * 17, 1.7, 2.0 + rng.random() * 3), (1.6, 1.3, 1.6), ["m_wood_2", "m_wood_1", "g_hi"], subdiv=0, rng=rng, jitter=0.3)
    return lm_finish(b, w, d, h, ["MirageDunes"])


def ghost_town(name):
    b = L.new(name)
    w, d, h = 72.0, 30.0, 24.0
    L.pad(b, w, d, "g_sand", 0.4)
    for i, (hx, hw_, hh) in enumerate(((-24.0, 18.0, 20.0), (-3.0, 14.0, 16.0), (16.0, 16.0, 22.0), (31.0, 8.0, 14.0))):
        L.plain_building(b, hw_, 14.0, hh, "m_wood_2" if i % 2 else "w_wall_1", "m_wood_1", "w_roof_flat", "m_metal_dark", windows=2, parapet=True, y0=0.4, x=hx)
    return lm_finish(b, w, d, h, [], read="tier B kit gallery: ghost town block")


def water_tank(name):
    b = L.new(name)
    w, d, h = 24.0, 24.0, 48.0
    L.pad(b, w, d, "g_lo", 0.4)
    for x, z in ((-6, 6), (6, 6), (6, 18), (-6, 18)):
        beam(b, V(x * 0.9, 0.4, z), V(x * 0.7, 30.0, 12 + (z - 12) * 0.78), 1.0, 1.0, "m_wood_2")
    cyl(b, V(0, 30.0, 12.0), 14.0, 9.0, 10, "m_wood_1", r_top=9.0, top_sw="m_wood_2")
    cyl(b, V(0, 44.0, 12.0), 4.0, 9.4, 10, "w_roof_2", r_top=0.4, top=True)
    return lm_finish(b, w, d, h, [], read="tier B kit gallery: water tank")


# ---------------------------------------------------------------- props (bottom centre; -Z faces the road)
def prop_meta(kind, h):
    return {"family": "Prop", "world": WORLD, "lod": NEAR, "district": "any", "kind": kind, "pivot": "bottom centre, on the sidewalk; -Z toward the road", "sockets": {"base": sock((0, 0, 0))}, "height": h}


def pole(name):
    b = L.new(name)
    cyl(b, V(0, 0, 0), 16.0, 0.45, 5, "m_wood_2", r_top=0.38)
    box(b, V(0, 15.2, -1.2), (0.4, 0.4, 3.6), {"side": "m_wood_1", "skip_bottom": True})
    box(b, V(0, 14.4, -2.4), (1.0, 1.4, 1.0), {"side": "m_light", "top": "m_metal_dark", "skip_bottom": True})
    return b, prop_meta("lamp", 16.0)


def bus_shelter(name):
    b = L.new(name)
    box(b, V(0, 8.0, 0.4), (9.0, 0.5, 4.4), {"side": "m_wood_1", "top": "w_roof_1", "skip_bottom": True})
    box(b, V(0, 4.2, 2.4), (9.0, 7.0, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    for x in (-4.2, 4.2):
        box(b, V(x, 4.0, -1.4), (0.4, 8.0, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 1.6, 1.3), (6.4, 0.5, 1.4), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    return b, prop_meta("busStop", 8.5)


def prop_cactus(name):
    b = L.new(name)
    L.cactus(b, 0, 0, 9.0, rng_of(name), arms=2)
    return b, prop_meta("cactus", 9.0)


def prop_rock(name):
    rng = rng_of(name)
    b = L.new(name)
    L.rock(b, 0, 0, 2.6, 2.0, 2.2, rng, light=("r_2", "r_3", "r_4", "r_top"))
    L.rock(b, 2.0, 1.0, 1.5, 1.2, 1.4, rng, light=("r_3", "r_4", "r_top", "r_top"))
    return b, prop_meta("rock", 2.5)


def prop_barrel(name):
    b = L.new(name)
    cyl(b, V(0, 0, 0), 3.0, 1.2, 8, "m_wood_1", r_top=1.2, top_sw="m_wood_2")
    cyl(b, V(0, 0.7, 0), 0.4, 1.28, 8, "m_metal_dark", top=False)
    cyl(b, V(0, 2.0, 0), 0.4, 1.28, 8, "m_metal_dark", top=False)
    return b, prop_meta("barrel", 3.0)


def fence_post(name):
    b = L.new(name)
    box(b, V(0, 1.6, 0), (0.5, 3.2, 0.5), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    box(b, V(3.0, 2.5, 0), (6.0, 0.3, 0.25), {"side": "m_wood_1", "skip_bottom": True})
    box(b, V(3.0, 1.5, 0), (6.0, 0.3, 0.25), {"side": "m_wood_1", "skip_bottom": True})
    return b, prop_meta("fencePost", 3.2)


# ---------------------------------------------------------------- hazards (scenery previews; centre on the road surface)
def haz_meta(kind, note):
    return {"family": "Haz", "world": WORLD, "lod": NEAR, "district": "any", "kind": kind, "pivot": "centre on the surface it stands on", "sockets": {"base": sock((0, 0, 0))}, "rule": note}


def sinkhole(name):
    rng = rng_of(name)
    b = L.new(name)
    n = 12
    outer, inner = circle2(0, 0, 6.4, n), circle2(0, 0, 4.4, n)
    for k in range(n):
        k2 = (k + 1) % n
        b.face([V(outer[k][0], 0.05, outer[k][1]), V(outer[k2][0], 0.05, outer[k2][1]), V(outer[k2][0], 0.55, outer[k2][1]), V(outer[k][0], 0.55, outer[k][1])], "hz_rim", V(outer[k][0], 0, outer[k][1]))
        b.face([V(outer[k][0], 0.55, outer[k][1]), V(outer[k2][0], 0.55, outer[k2][1]), V(inner[k2][0], 0.5, inner[k2][1]), V(inner[k][0], 0.5, inner[k][1])], "hz_light" if k % 2 else "hz_rim", V(0, 1, 0))
        b.face([V(inner[k][0], 0.5, inner[k][1]), V(inner[k2][0], 0.5, inner[k2][1]), V(inner[k2][0] * 0.55, 0.12, inner[k2][1] * 0.55), V(inner[k][0] * 0.55, 0.12, inner[k][1] * 0.55)], "hz_dark", V(-inner[k][0], 1, -inner[k][1]))
    b.face([V(x * 0.55, 0.12, z * 0.55) for x, z in inner], "m_black", V(0, 1, 0))
    return b, haz_meta("pothole", "sinkhole: a rimmed dark pit, scenery preview only")


def sand_drift(name):
    rng = rng_of(name)
    b = L.new(name)
    mound(b, 0, 0, 11.0, 5.2, 1.6, rng, ["hz_rim", "hz_light", "hz_light"], rings=3, segs=14, y0=0.0)
    mound(b, 4.0, 1.4, 6.0, 3.0, 1.0, rng, ["hz_light", "hz_light"], rings=2, segs=10, y0=0.0)
    return b, haz_meta("oil", "sand drift: a low pale mound across the lane, scenery preview only")


def rockslide(name):
    rng = rng_of(name)
    b = L.new(name)
    for i in range(7):
        s = 1.6 + rng.random() * 2.6
        L.rock(b, -5.0 + i * 1.8 + rng.random(), (rng.random() - 0.5) * 6.0, s, s * 0.8, s, rng, light=("r_2", "r_3", "r_4", "r_top"))
    for s in (-1, 1):  # the crew's barrier and cones: the only orange and white in the kit
        box(b, V(s * 9.0, 1.4, -3.5), (4.0, 0.7, 0.5), {"side": "haz_orange", "top": "haz_white", "skip_bottom": True})
        for z in (-0.5, 1.6):
            cyl(b, V(s * 9.0 + (z * 0.2), 0, z + 2.0), 2.0, 0.7, 6, "haz_orange", r_top=0.2, top_sw="haz_white")
    return b, haz_meta("construction", "rockslide crew: rocks, a barrier and cones (construction language is hazard-only)")


# ---------------------------------------------------------------- distant masses
def mass_meta(kind, h, w=36.0, d=30.0):
    return {"family": "Mid", "world": WORLD, "lod": "mid", "district": "any", "kind": kind, "width": w, "depth": d, "height": h, "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}, "band": "midground 60-140 from the road edge"}


def mesa_mass(name, w, d, h, tiers, sw):
    rng = rng_of(name)
    b = L.new(name)
    y, cw, cd = 0.0, w, d
    for i in range(tiers):
        th = h * (0.46 if i == 0 else 0.54 / max(1, tiers - 1))
        strata_block(b, 0, d / 2, cw, cd, y, th, sw[min(i, len(sw) - 1)], tops=(i == tiers - 1))
        y += th
        cw *= 0.8
        cd *= 0.82
    return b, mass_meta("mesa", y, w, d)


def sky_unit(name, kind, tiers):
    b = L.new(name)
    for i, (r, h0, h1) in enumerate(tiers):
        cyl(b, V(0, h0, 0), h1 - h0, r, 5, "sk_1" if i % 2 == 0 else "sk_3", r_top=r * 0.78 if i < len(tiers) - 1 else r * 0.2, top_sw="sk_trim", phase=0.3 * i)
    return b, L.unit_meta(WORLD, "Sky", "far", "skyline 300-800 from the road edge", kind=kind)


def build_all(emit):
    # lots
    for nm, w_, n, h in (("DH_Lot_Cactus24_a", 24, 4, 14.0), ("DH_Lot_Cactus36_b", 36, 6, 16.0)):
        emit(*cactus_lot(nm, w_, n, h))
    emit(*scrub_lot("DH_Lot_Scrub24_a", 24, 6.0, ALL))
    emit(*scrub_lot("DH_Lot_Scrub36_b", 36, 7.0, ALL))
    emit(*rocks_lot("DH_Lot_Rocks36_a", 36, 12.0))
    emit(*adobe_lot("DH_Lot_Adobe24_a", 24, 12.0))
    emit(*corral_lot("DH_Lot_Corral36_a", 36, 8.0))
    emit(*motel_lot("DH_Lot_Motel48_a", 48, 14.0))
    emit(*stand_lot("DH_Lot_Stand24_a", 24, 10.0))
    emit(*garage_lot("DH_Lot_Garage36_a", 36, 14.0))
    emit(*mesa_lot("DH_Lot_Mesa36_a", 36, 34.0))
    emit(*mesa_lot("DH_Lot_Mesa48_b", 48, 42.0))
    emit(*pillar_lot("DH_Lot_Pillar24_a", 24, 36.0))
    emit(*hoodoo_lot("DH_Lot_Hoodoo24_b", 24, 28.0))
    emit(*cliff_lot("DH_Lot_Cliff48_a", 48, 40.0))
    emit(*cliff_lot("DH_Lot_Cliff36_b", 36, 34.0))
    emit(*ridge_lot("DH_Lot_Ridge24_a", 24, 20.0))
    emit(*dune_lot("DH_Lot_Dune36_a", 36, 10.0))
    emit(*dune_lot("DH_Lot_Dune48_b", 48, 12.0))
    emit(*hut_lot("DH_Lot_Hut24_a", 24, 12.0))
    emit(*oasis_lot("DH_Lot_Oasis24", 24))
    emit(*oasis_lot("DH_Lot_Oasis36", 36))
    emit(*rest_lot("DH_Lot_Rest36_a", 36))
    # landmarks
    emit(*windmill("DH_LM_WindmillTower"))
    emit(*cactus_garden("DH_LM_CactusGarden"))
    emit(*diner("DH_LM_Diner"))
    emit(*pump_station("DH_LM_PumpStation"))
    emit(*rock_arch("DH_LM_RockArch"))
    emit(*canyon_bridge("DH_LM_CanyonBridge384"))
    emit(*cactus_sign("DH_LM_CactusSign"))
    emit(*ghost_huts("DH_LM_GhostHuts"))
    emit(*ghost_town("DH_LM_GhostTown"))
    emit(*water_tank("DH_LM_WaterTank"))
    # props
    emit(*pole("DH_Prop_Pole"))
    emit(*bus_shelter("DH_Prop_BusShelter"))
    emit(*prop_cactus("DH_Prop_Cactus"))
    emit(*prop_rock("DH_Prop_Rock"))
    emit(*prop_barrel("DH_Prop_Barrel"))
    emit(*fence_post("DH_Prop_FencePost"))
    # hazards
    emit(*sinkhole("DH_Haz_Sinkhole"))
    emit(*sand_drift("DH_Haz_SandDrift"))
    emit(*rockslide("DH_Haz_Rockslide"))
    # middle distance (authored heights chosen to match the districts' midHeight ranges)
    emit(*mesa_mass("DH_Mid_Mesa_1", 36, 30, 60.0, 4, [["r_1", "r_2"], ["r_2", "r_3"], ["r_3", "r_4"], ["r_4", "r_3"]]))
    emit(*mesa_mass("DH_Mid_Mesa_2", 40, 30, 84.0, 4, [["r_1", "r_2"], ["r_2", "r_3"], ["r_3", "r_4"], ["r_4", "r_3"]]))
    emit(*mesa_mass("DH_Mid_Butte_1", 28, 24, 34.0, 2, [["r_2", "r_3"], ["r_3", "r_4"]]))
    emit(*mesa_mass("DH_Mid_Butte_2", 24, 24, 48.0, 3, [["r_1", "r_2"], ["r_2", "r_3"], ["r_3", "r_4"]]))
    b = L.new("DH_Mid_Dune_1")
    mound(b, 0, 14.0, 22.0, 15.0, 26.0, rng_of("dune"), ["g_lo", "g_sand", "g_hi"], rings=3, segs=12)
    emit(b, mass_meta("dune", 26.0, 44.0, 30.0))
    # skyline (unit meshes, scaled per instance)
    emit(*sky_unit("DH_Sky_Mesa_1", "mesa", [(0.5, 0.0, 0.5), (0.4, 0.5, 0.82), (0.3, 0.82, 1.0)]))
    emit(*sky_unit("DH_Sky_Mesa_2", "mesa", [(0.5, 0.0, 0.62), (0.34, 0.62, 1.0)]))
    emit(*sky_unit("DH_Sky_Mesa_3", "mesa", [(0.5, 0.0, 0.4), (0.44, 0.4, 0.7), (0.36, 0.7, 0.9), (0.26, 0.9, 1.0)]))
    emit(*sky_unit("DH_Sky_Ridge_1", "ridge", [(0.5, 0.0, 0.5), (0.3, 0.5, 0.78)]))
    emit(*sky_unit("DH_Sky_Ridge_2", "ridge", [(0.5, 0.0, 0.34), (0.36, 0.34, 0.6), (0.2, 0.6, 0.72)]))
    emit(*sky_unit("DH_Sky_Spire", "spire", [(0.42, 0.0, 0.4), (0.3, 0.4, 0.75), (0.18, 0.75, 1.0)]))
