# Downtown kit: distant skyline silhouettes (band 300 to 900 studs from the frontage line).
# Unit-sized meshes (1 x 1 x 1, pivot at the bottom centre) that the layout scales per instance,
# 12 to 40 triangles each, coloured with the pre-hazed sky_* swatches (lighter and less
# saturated toward the sky, research O6). Each shape comes in two colourways (_1, _2).
# Shapes: SkySlab (plain block, cap band), SkyStepped (setbacks, B), SkyRound (rounded top, A),
# SkyTower (chamfered tower, C). C_ArenaDome is the metropolis's distant closing shape.

import math

from kitlib import Builder, V, box, cyl, prism


def slab(name, body, cap):
    b = Builder(name)
    box(b, V(0, 0.48, 0), (1.0, 0.96, 1.0), {"side": body, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.98, 0), (1.04, 0.04, 1.04), {"side": cap, "top": cap, "skip_bottom": True})
    return b, {"unit": True, "note": "scale [width, height, depth]"}


def stepped(name, body, cap):
    b = Builder(name)
    box(b, V(0, 0.3, 0), (1.0, 0.6, 1.0), {"side": body, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.75, 0.04), (0.78, 0.3, 0.8), {"side": body, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.95, 0.08), (0.5, 0.1, 0.55), {"side": cap, "top": cap, "skip_bottom": True})
    return b, {"unit": True}


def rounded(name, body, cap):
    b = Builder(name)
    box(b, V(0, 0.4, 0), (1.0, 0.8, 1.0), {"side": body, "top": body, "skip_bottom": True, "skip_top": True})
    # half-cylinder roof along x, 6 facets
    n = 6
    pts = [(math.cos(math.pi * k / n) * 0.5, 0.8 + math.sin(math.pi * k / n) * 0.2) for k in range(n + 1)]
    for k in range(n):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        b.face([V(x0, y0, -0.5), V(x1, y1, -0.5), V(x1, y1, 0.5), V(x0, y0, 0.5)], cap, V((x0 + x1) / 2, (y0 + y1) / 2 - 0.8, 0))
    for z, n_ in ((-0.5, V(0, 0, -1)), (0.5, V(0, 0, 1))):
        b.face([V(x, y, z) for x, y in pts], body, n_)
    return b, {"unit": True}


def tower(name, body, cap):
    b = Builder(name)
    c = 0.18
    outline = [(-0.5 + c, -0.5), (0.5 - c, -0.5), (0.5, -0.5 + c), (0.5, 0.5 - c), (0.5 - c, 0.5), (-0.5 + c, 0.5), (-0.5, 0.5 - c), (-0.5, -0.5 + c)]
    prism(b, outline, 0, 0.94, body, cap)
    prism(b, [(x * 0.7, z * 0.7) for x, z in outline], 0.94, 1.0, cap, cap)
    return b, {"unit": True}


def arena_dome(name):
    """A distant arena: a drum 150 across and 22 tall with a band, under a ribbed shallow dome
    (top 52). Real size, pivot at the bottom centre."""
    b = Builder(name)
    R = 75.0
    n = 20
    cyl(b, V(0, 0, 0), 16.0, R, n, "dome_rib", top=False)
    cyl(b, V(0, 16.0, 0), 6.0, R + 1.0, n, "dome_band", top=False)
    rings = 4
    prev = None
    for i in range(rings + 1):
        a = (math.pi / 2) * i / rings * 0.92
        r = (R + 1.0) * math.cos(a)
        y = 22.0 + 30.0 * math.sin(a)
        cur = [V(math.cos(2 * math.pi * k / n) * r, y, math.sin(2 * math.pi * k / n) * r) for k in range(n)]
        if prev:
            for k in range(n):
                k2 = (k + 1) % n
                q = [prev[k], prev[k2], cur[k2], cur[k]]
                cen = sum(q, V(0)) / 4
                b.face(q, "dome_rib" if k % 4 == 0 else "dome", cen - V(0, 0, 0))
        prev = cur
    b.face(prev, "dome", V(0, 1, 0))
    return b, {"height": 52.0, "diameter": 2 * R + 2}


def build_all(emit):
    P = "skyline"
    for shape, fn in (("SkySlab", slab), ("SkyStepped", stepped), ("SkyRound", rounded), ("SkyTower", tower)):
        emit(*fn(shape + "_1", "sky_1", "sky_trim"), P, "common")
        emit(*fn(shape + "_2", "sky_2", "sky_3"), P, "common")
        emit(*fn(shape + "_3", "sky_4", "sky_trim"), P, "common")
    emit(*arena_dome("C_ArenaDome"), P, "C")
