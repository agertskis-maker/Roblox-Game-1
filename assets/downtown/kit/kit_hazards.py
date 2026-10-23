# Downtown kit: non-functional hazard previews, shared and identically coloured in A, B and C
# (hazard swatches are fixed in every palette). Readability rules (research O10): cones 3 tall
# orange with a white band; barriers 4 tall with diagonal orange/white stripes; the pothole has
# a cracked rim lighter than the asphalt so it reads as a hole; the oil slick is a near-black
# glossy blob with a thin teal/violet/gold sheen ring, unlike soft grey-blue shadows. The crane
# stands on a lot and its jib stays parallel to the road, never over the carriageway.

import math
import random

from kitlib import Builder, V, beam, box, cyl, stripes, tube


def seed_of(name):
    return sum(map(ord, name)) * 13 + len(name)


def barrier(name):
    """A 6-wide, 4-tall board barrier on two A-frame legs, striped on both faces, with a small
    amber lamp. Front is local -Z (face it toward oncoming traffic)."""
    b = Builder(name)
    W = 6.0
    for x in (-W / 2 + 0.4, W / 2 - 0.4):
        for sz in (-1, 1):
            tube(b, [V(x, 0, sz * 0.9), V(x, 3.6, sz * 0.12)], [0.14, 0.12], 4, "haz_white")
        box(b, V(x, 0.1, 0), (0.6, 0.2, 2.2), "haz_black")
    for (y0, y1) in ((2.75, 3.75), (1.35, 2.25)):
        box(b, V(0, (y0 + y1) / 2, 0), (W, y1 - y0, 0.16), {"side": "haz_white"})
        for zf, n in ((-0.09, V(0, 0, -1)), (0.09, V(0, 0, 1))):
            stripes(b, -W / 2, y0, W / 2, y1, 0.75, ["haz_orange", "haz_white"], lambda u, v, zf=zf: V(u, v, zf), n, slant=1.0)
    cyl(b, V(W / 2 - 0.4, 3.75, 0), 0.15, 0.2, 6, "haz_black")
    cyl(b, V(W / 2 - 0.4, 3.9, 0), 0.45, 0.32, 8, "haz_amber", r_top=0.28)
    return b, {"height": 4.35, "length": W, "boards": 2}


def cone(name):
    b = Builder(name)
    box(b, V(0, 0.12, 0), (2.0, 0.24, 2.0), "haz_black")
    cyl(b, V(0, 0.24, 0), 1.15, 0.85, 10, "cone_orange", top=False, r_top=0.62)
    cyl(b, V(0, 1.39, 0), 0.55, 0.62, 10, "haz_white", top=False, r_top=0.5)
    cyl(b, V(0, 1.94, 0), 0.85, 0.5, 10, "cone_orange", r_top=0.16)
    cyl(b, V(0, 2.79, 0), 0.21, 0.16, 10, "cone_orange", r_top=0.06)
    return b, {"height": 3.0}


def construction_sign(name):
    """A folding A-frame stand with a diamond warning sign: orange face, black border and an
    exclamation pictogram (no text). Face toward oncoming traffic (front, -Z)."""
    b = Builder(name)
    for x in (-1.3, 1.3):
        tube(b, [V(x, 0, -0.9), V(x * 0.6, 5.0, -0.1)], [0.12, 0.1], 4, "haz_white")
        tube(b, [V(x, 0, 1.1), V(x * 0.6, 5.0, 0.1)], [0.12, 0.1], 4, "haz_white")
        box(b, V(x, 0.1, 0.1), (0.5, 0.2, 2.4), "haz_black")
    c = V(0, 4.6, -0.42)
    R = 2.4

    def diamond(r, z, sw):
        pts = [c + V(0, r, z), c + V(r, 0, z), c + V(0, -r, z), c + V(-r, 0, z)]
        b.face(pts, sw, V(0, 0, -1))
        return pts

    back = [c + V(0, R, 0.12), c + V(R, 0, 0.12), c + V(0, -R, 0.12), c + V(-R, 0, 0.12)]
    front = diamond(R, 0.0, "haz_black")
    b.face(back, "haz_orange", V(0, 0, 1))
    for i in range(4):
        q = [front[i], front[(i + 1) % 4], back[(i + 1) % 4], back[i]]
        mid = (front[i] + front[(i + 1) % 4]) / 2
        b.face(q, "haz_black", mid - c)
    diamond(R - 0.3, -0.02, "haz_orange")
    # exclamation mark: a tapered bar and a dot
    z = -0.04
    b.face([c + V(-0.22, 1.25, z), c + V(0.22, 1.25, z), c + V(0.14, -0.35, z), c + V(-0.14, -0.35, z)], "haz_black", V(0, 0, -1))
    dot = [c + V(math.cos(a) * 0.24, -0.85 + math.sin(a) * 0.24, z) for a in [2 * math.pi * k / 8 for k in range(8)]]
    b.face(dot, "haz_black", V(0, 0, -1))
    return b, {"height": 7.0, "faces": [], "pictogram": "exclamation"}


def crane(name):
    """A compact tower crane for a building lot: concrete pad and ballast, a lattice mast 46
    tall, slewing cab, a 34-long jib along local -Z with a trolley and hook, and a counter-jib
    with weights along +Z. Place it so the jib runs parallel to the road, away from it."""
    b = Builder(name)
    box(b, V(0, 0.5, 0), (10, 1.0, 10), "concrete_block")
    for x in (-2.6, 2.6):
        box(b, V(x, 1.7, 0), (2.0, 1.4, 6.0), "concrete_block")
    M = 2.0  # half mast width
    top = 46.0
    corners = [V(-M, 1.0, -M), V(M, 1.0, -M), V(M, 1.0, M), V(-M, 1.0, M)]
    for c in corners:
        beam(b, c, c + V(0, top - 1.0, 0), 0.35, 0.35, "crane_yellow")
    lv = 1.0
    step = 4.5
    k = 0
    while lv + step <= top + 0.1:
        for i in range(4):
            a, c = corners[i], corners[(i + 1) % 4]
            pa, pc = a + V(0, lv - 1.0, 0), c + V(0, lv - 1.0, 0)
            beam(b, pa + V(0, step, 0), pc + V(0, step, 0), 0.18, 0.18, "crane_yellow")
            if (i + k) % 2 == 0:
                beam(b, pa, pc + V(0, step, 0), 0.14, 0.14, "crane_yellow")
            else:
                beam(b, pc, pa + V(0, step, 0), 0.14, 0.14, "crane_yellow")
        lv += step
        k += 1
    # slewing ring, cab and tower head
    box(b, V(0, top + 0.6, 0), (5.0, 1.2, 5.0), "crane_dark")
    box(b, V(2.6, top + 2.3, -1.6), (2.6, 2.6, 2.8), {"side": "crane_cab", "front": "crane_glass", "top": "crane_yellow"})
    apex = V(0, top + 9.0, 0)
    for c in (V(-1.2, top + 1.2, -1.2), V(1.2, top + 1.2, -1.2), V(1.2, top + 1.2, 1.2), V(-1.2, top + 1.2, 1.2)):
        beam(b, c, apex, 0.25, 0.25, "crane_yellow")
    # jib: a triangular truss toward -Z, 34 long
    J = 34.0
    y0 = top + 1.4
    lo_l, lo_r, hi = V(-1.0, y0, 0), V(1.0, y0, 0), V(0, y0 + 2.2, 0)
    end = V(0, 0, -J)
    for p in (lo_l, lo_r, hi):
        beam(b, p, p + end + (V(0, -0.0, 0)), 0.25, 0.25, "crane_yellow")
    n = 8
    for i in range(n):
        za = -J * i / n
        zb = -J * (i + 1) / n
        beam(b, lo_l + V(0, 0, za), hi + V(0, 0, zb), 0.12, 0.12, "crane_yellow")
        beam(b, lo_r + V(0, 0, za), hi + V(0, 0, zb), 0.12, 0.12, "crane_yellow")
    # pendant ties from the apex to the jib and counter-jib
    beam(b, apex, hi + V(0, 0, -J * 0.62), 0.08, 0.08, "crane_dark")
    # counter-jib with ballast weights toward +Z
    CJ = 12.0
    box(b, V(0, y0 + 0.3, CJ / 2), (2.2, 0.7, CJ), "crane_yellow")
    for z in (CJ - 3.0, CJ - 1.2):
        box(b, V(0, y0 - 1.4, z), (2.6, 2.6, 1.6), "concrete_block")
    beam(b, apex, V(0, y0 + 0.6, CJ - 1.0), 0.08, 0.08, "crane_dark")
    # trolley, cable and hook block over the lot
    tz = -J * 0.7
    box(b, V(0, y0 - 0.4, tz), (2.4, 0.8, 1.6), "crane_dark")
    beam(b, V(0, y0 - 0.8, tz), V(0, 18.0, tz), 0.06, 0.06, "crane_dark")
    box(b, V(0, 17.0, tz), (1.2, 2.0, 0.8), "haz_orange")
    tube(b, [V(0, 16.0, tz), V(0, 15.0, tz + 0.5), V(0, 15.0, tz - 0.4)], [0.15, 0.15, 0.15], 4, "crane_dark")
    return b, {"height": top + 9.0, "jib": J, "counter_jib": CJ, "note": "jib along local -Z; keep it parallel to the road"}


def blob(rng, rx, rz, n, lobes, amp, phase=None):
    phase = rng.uniform(0, 6.28) if phase is None else phase
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 1 + sum(amp[i] * math.sin(lobes[i] * a + phase * (i + 1)) for i in range(len(lobes)))
        pts.append((math.cos(a) * rx * r, math.sin(a) * rz * r))
    return pts


def ring_band(b, outer, inner, y, swatches, hint=V(0, 1, 0)):
    n = len(outer)
    for k in range(n):
        k2 = (k + 1) % n
        sw = swatches[k % len(swatches)] if isinstance(swatches, list) else swatches
        b.face([V(outer[k][0], y, outer[k][1]), V(outer[k2][0], y, outer[k2][1]), V(inner[k2][0], y, inner[k2][1]), V(inner[k][0], y, inner[k][1])], sw, hint)


def pothole(name):
    """2.5 (across) x 3.5 (along the road): a lighter broken edge, a darker wall band and the
    darkest floor, all a hair above the asphalt (the road slab is not cut)."""
    rng = random.Random(seed_of(name))
    b = Builder(name)
    n = 14
    rim = blob(rng, 1.25 * 1.18, 1.75 * 1.18, n, [3, 5], [0.08, 0.05])
    edge = [(x * 0.84, z * 0.84) for x, z in blob(rng, 1.25, 1.75, n, [3, 5], [0.1, 0.06])]
    wall = [(x * 0.82, z * 0.82) for x, z in edge]
    floor_ = [(x * 0.8, z * 0.8) for x, z in wall]
    ring_band(b, rim, edge, 0.012, "pot_rim")
    ring_band(b, edge, wall, 0.014, "pot_wall")
    ring_band(b, wall, floor_, 0.016, "pot_floor")
    b.face([V(x, 0.016, z) for x, z in floor_], "pot_floor", V(0, 1, 0))
    # broken chunks on the rim and crumbs inside
    for k in range(7):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(1.0, 1.2)
        c = V(math.cos(a) * 1.25 * r, 0.0, math.sin(a) * 1.75 * r)
        s = rng.uniform(0.18, 0.32)
        box(b, c + V(0, s * 0.25, 0), (s, s * 0.5, s * 1.3), {"top": "pot_chunk", "side": "pot_rim"}, yaw=rng.uniform(0, 3))
    for k in range(4):
        c = V(rng.uniform(-0.5, 0.5), 0.0, rng.uniform(-0.8, 0.8))
        s = rng.uniform(0.14, 0.24)
        box(b, c + V(0, 0.03, 0), (s, 0.06, s), "pot_chunk", yaw=rng.uniform(0, 3))
    # hairline cracks out into the asphalt
    for a in (0.6, 2.3, 4.0, 5.3):
        p0 = V(math.cos(a) * 1.4, 0.013, math.sin(a) * 1.9)
        p1 = V(math.cos(a + 0.2) * 2.3, 0.013, math.sin(a + 0.2) * 2.9)
        side = V(-(p1.z - p0.z), 0, p1.x - p0.x).normalized() * 0.05
        b.face([p0 - side, p0 + side, p1], "pot_wall", V(0, 1, 0))
    return b, {"height": 0.15, "size": [2.5, 3.5], "material": "Plastic"}


def oil_slick(name):
    """6 (across) x 4 (along): a lobed near-black blob, a faint sheen ring just inside the edge
    (teal, violet, gold in turn), a glossy highlight streak and a few satellite drops."""
    rng = random.Random(seed_of(name))
    b = Builder(name)
    n = 28
    outer = blob(rng, 3.0, 2.0, n, [3, 4, 7], [0.07, 0.05, 0.025])
    sheen_o = [(x * 0.93, z * 0.93) for x, z in outer]
    sheen_i = [(x * 0.84, z * 0.84) for x, z in outer]
    y = 0.022
    ring_band(b, outer, sheen_o, y, "oil_black")
    cols = ["oil_teal", "oil_teal", "oil_violet", "oil_violet", "oil_gold", "oil_black", "oil_teal", "oil_violet", "oil_black", "oil_gold"]
    ring_band(b, sheen_o, sheen_i, y + 0.001, [cols[(k * 7 // 4) % len(cols)] for k in range(n)])
    b.face([V(x, y, z) for x, z in sheen_i], "oil_black", V(0, 1, 0))
    # glossy streak (where the sky reflects)
    hl = [(-1.4, -0.5), (-0.2, -0.85), (1.1, -0.7), (1.3, -0.45), (-0.1, -0.5), (-1.2, -0.25)]
    b.face([V(x, y + 0.003, z) for x, z in hl], "oil_gloss", V(0, 1, 0))
    for k in range(4):
        a = rng.uniform(0, 6.28)
        c = (math.cos(a) * 3.6, math.sin(a) * 2.5)
        r = rng.uniform(0.18, 0.35)
        drop = [(c[0] + math.cos(t) * r, c[1] + math.sin(t) * r * 0.8) for t in [2 * math.pi * j / 7 for j in range(7)]]
        b.face([V(x, y, z) for x, z in drop], "oil_black", V(0, 1, 0))
    return b, {"height": 0.03, "size": [6.0, 4.0], "material": "SmoothPlastic, Reflectance about 0.25"}


def site_fence(name):
    """A 12-long construction hoarding panel for the crane's lot: posts on concrete feet, a
    striped kick board and a grey mesh screen (both sides). Runs along local X; front -Z."""
    b = Builder(name)
    L = 12.0
    for x in (-L / 2 + 0.2, 0.0, L / 2 - 0.2):
        box(b, V(x, 0.3, 0), (0.9, 0.6, 1.6), "concrete_block")
        box(b, V(x, 3.2, 0), (0.2, 6.4, 0.2), "haz_white")
    for zf, n in ((-0.12, V(0, 0, -1)), (0.12, V(0, 0, 1))):
        stripes(b, -L / 2, 0.7, L / 2, 1.9, 0.9, ["haz_orange", "haz_white"], lambda u, v, zf=zf: V(u, v, zf), n, slant=1.0)
    box(b, V(0, 1.3, 0), (L, 1.2, 0.2), {"side": "haz_white"})
    b.face2([V(-L / 2, 2.0, 0), V(L / 2, 2.0, 0), V(L / 2, 6.0, 0), V(-L / 2, 6.0, 0)], "fence_mesh")
    box(b, V(0, 6.1, 0), (L, 0.2, 0.25), "haz_white")
    return b, {"height": 6.4, "length": L}


def build_all(emit):
    P = "hazard"
    emit(*barrier("Barrier"), P, "common")
    emit(*cone("Cone"), P, "common")
    emit(*construction_sign("ConstructionSign"), P, "common")
    emit(*crane("Crane"), P, "common")
    emit(*pothole("Pothole"), P, "common")
    emit(*oil_slick("OilSlick"), P, "common")
    emit(*site_fence("SiteFence"), P, "common")
