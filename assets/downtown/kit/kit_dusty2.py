# Dusty Highway kit V2 (Lane 3, Worlds build, 2026-10-28, worker D): the density and polish pass for the desert World.
# Plan: vault/design/specs/world-plan-dusty-highway.md (grammar G1 to G10, inventory 8.1). Same builder, palette cells and
# conventions as kit_dusty.py (kit_world_lib). Every mesh is original and fictional; colour comes only from swatch names
# (kit_world_palette.py plus the extension kit_world_palette_dh2.py). Pure Blender-recipe Python, no Luau, no uploads.
#
# Authored masses are drawn at their REAL size (authored=True); the Assembler places them unstretched. Rock is built from
# lofts between plan outlines (rings), so every mass has a supported silhouette with sloped talus, strata of 8 studs or more,
# a lit top, a body plane and a deep-shade plane (baked by face direction, see _rock_sw). Faces the chase camera cannot see
# (bottoms) are not built; foundations go 1.5 below ground; backs, ends and undersides the route can reach are finished.

import math
import random

import kit_world_lib as L
from kit_b2lib import sock
from kitlib import V, beam, box, clip_poly, cyl, newell, prism, rounded_rect2, sphere, stripes, tube, circle2

NEAR = "near"
WORLD = "DH"
ALL = ["CactusFlats", "DinerStrip", "RedRockArches", "CanyonBridge", "MirageDunes"]
FOUND = -1.5  # foundations of rock and heavy masonry sit this far below ground

DROP_OLD = [
    "DH_LM_RockArch",  # the Round 2 arch reads as a ring on two stacks; DH_LM_RockArchThick / RockArchSmall replace it
    "DH_LM_CanyonBridge384",  # its trench cliffs are baked in; the true gorge uses DH_LM_BridgeTruss384 plus DH_Gorge_Wall_*
    "DH_Mid_Mesa_1",  # stacked-slab masses; DH_Mass_Butte_A..F (six silhouette classes) replace them
    "DH_Mid_Mesa_2",  # same
    "DH_Mid_Butte_1",  # same
    "DH_Mid_Butte_2",  # same
    "DH_Mid_Dune_1",  # a single mound; DH_BG_Dune_A..C (long S-curve ridges with crest and lee) replace it
    "DH_Prop_Cactus",  # thin 1.4 deep stick cactus; the Sentinel / Barrel / Paddle / Rosette families replace it (plan G4)
]
REPLACES = []  # filled by the P2 hazard redraw below
MEASURE = {}
_RECIPES = []


def rng_of(name):
    return random.Random(sum(map(ord, name)) * 31 + len(name))


def reg(name, fn, *args, **kw):
    _RECIPES.append((name, fn, args, kw))


def finish(b, w, d, h, cls, districts, shop=False, family="Lot", module="scenery", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, family, module, w, d, h, cls, districts, sockets, shop, **kw)


def lm_finish(b, w, d, h, districts, placement="frontage", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, "LM", "landmark", w, d, h, "landmark", districts, sockets, False, placement=placement, **kw)


def umeta(family, lod, band, **kw):
    return L.unit_meta(WORLD, family, lod, band, **kw)


# ================================================================ plan outlines (x, z) and rock lofts
def blob(cx, cz, hx, hz, n=14, e=0.6, rng=None, jit=0.0, rot=0.0):
    """A rounded-rectangle outline (superellipse), n vertices, ascending angle, optional jitter."""
    pts = []
    for k in range(n):
        a = rot + 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        x = hx * math.copysign(abs(c) ** e, c)
        z = hz * math.copysign(abs(s) ** e, s)
        if rng is not None and jit:
            j = 1 + rng.uniform(-jit, jit)
            x, z = x * j, z * j
        pts.append((cx + x, cz + z))
    return pts


def sc(poly, s, cx=0.0, cz=0.0):
    sx, sz = (s, s) if not isinstance(s, tuple) else s
    return [(cx + (x - cx) * sx, cz + (z - cz) * sz) for x, z in poly]


def sh(poly, dx=0.0, dz=0.0):
    return [(x + dx, z + dz) for x, z in poly]


def wob(poly, rng, a):
    return [(x + rng.uniform(-a, a), z + rng.uniform(-a, a)) for x, z in poly]


def area2(p):
    return 0.5 * sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))


SUN = (0.42, -0.91)  # horizontal direction toward the baked light (front, slightly +X)
LIT = ["r_1", "r_2", "r_3", "r_4"]
SHD = ["r_shadow", "d_sh_1", "d_sh_2", "d_sh_3"]


def _lit(n):
    hn = math.hypot(n.x, n.z)
    return 1.0 if hn < 1e-6 else (n.x * SUN[0] + n.z * SUN[1]) / hn


def rock_sw(spec, n):
    """Swatch for a rock face. spec: 1..4 = strata band (lit r_k, deep-shade twin on the dark side), ('sh', k) = in cast
    shadow, 'talus' = scree slope, or a swatch name."""
    if isinstance(spec, tuple):
        return SHD[spec[1] - 1] if n.y < 0.8 else "r_top"
    if spec == "talus":
        return "d_talus" if _lit(n) > -0.1 else "d_talus_sh"
    if not isinstance(spec, int):
        return spec
    if n.y > 0.8:
        return "r_top"
    if n.y < -0.35:
        return "r_shadow"
    k = spec
    lit = _lit(n)
    if n.y > 0.35:  # a sloped face catches more light
        return LIT[min(k, 3)] if lit > 0.0 else SHD[min(k, 3)]
    return LIT[k - 1] if lit > 0.12 else SHD[k - 1]


def loft(b, A, ya, B, yb, spec, up=True, fn=rock_sw):
    n = len(A)
    sg = 1 if area2(A) > 0 else -1
    for i in range(n):
        j = (i + 1) % n
        pts = [V(A[i][0], ya, A[i][1]), V(A[j][0], ya, A[j][1]), V(B[j][0], yb, B[j][1]), V(B[i][0], yb, B[i][1])]
        dx, dz = A[j][0] - A[i][0], A[j][1] - A[i][1]
        hint = V(sg * dz, 0, -sg * dx) if abs(yb - ya) > 1e-6 else V(0, 1 if up else -1, 0)
        nv = newell(pts)
        if nv.length < 1e-9:
            continue
        nv.normalize()
        if nv.dot(hint) < 0:
            nv = -nv
        b.face(pts, fn(spec, nv), hint)


def capface(b, poly, y, sw="r_top"):
    b.face([V(x, y, z) for x, z in poly], sw, V(0, 1, 0))


def tower(b, base, rng, steps, cap="r_top", w=0.5):
    """steps: (y, scale, spec[, extra]) from the foot up; spec is the band of the wall BELOW this ring (None for the first).
    extra: dict with dx, dz, poly (an alternative outline), nf (pull the front vertices 11..13 inward)."""
    rings = []
    for st in steps:
        y, s, spec = st[0], st[1], st[2]
        ex = st[3] if len(st) > 3 else {}
        p = sc(ex.get("poly", base), s)
        if ex.get("nf"):
            p = [(x * (1 - ex["nf"]), z * (1 - ex["nf"])) if k in (len(p) * 3 // 4 - 1, len(p) * 3 // 4, len(p) * 3 // 4 + 1) else (x, z) for k, (x, z) in enumerate(p)]
        p = wob(sh(p, ex.get("dx", 0.0), ex.get("dz", 0.0)), rng, ex.get("w", w))
        rings.append((p, y, spec))
    for i in range(1, len(rings)):
        spec = rings[i][2]
        up = True
        if isinstance(spec, list):
            spec, up = spec
        loft(b, rings[i - 1][0], rings[i - 1][1], rings[i][0], rings[i][1], spec, up)
    if cap:
        capface(b, rings[-1][0], rings[-1][1], cap)
    b.meas = getattr(b, "meas", [])
    for p, y, _ in rings:
        xs, zs = [q[0] for q in p], [q[1] for q in p]
        b.meas.append((y, max(xs) - min(xs), max(zs) - min(zs)))
    return rings


def measure(name, b, h, base_h=None):
    m = getattr(b, "meas", [])
    if not m:
        return
    body = [r for r in m if r[0] > 0]
    thick = min(min(r[1], r[2]) for r in body)
    base = [r for r in m if r[0] <= 0]
    bw = max(max(r[1], r[2]) for r in base) if base else 0
    top = m[-1]
    MEASURE[name] = {"h": round(h, 1), "thick_min": round(thick, 1), "foot_max": round(bw, 1), "foot_over_h": round(bw / h, 2), "apex_w": round(max(top[1], top[2]), 1)}


def bbox_size(b):
    """Real bounding size (x, y, z) in Roblox axes of the geometry built so far."""
    xs = [v.co.x for v in b.bm.verts]
    ys = [v.co.z for v in b.bm.verts]
    zs = [-v.co.y for v in b.bm.verts]
    return round(max(xs) - min(xs), 1), round(max(ys) - min(ys), 1), round(max(zs) - min(zs), 1)


def mass_meta(name, b, w, h, d, kind, **kw):
    w, h, d = bbox_size(b)  # the true size wins over the nominal numbers passed by the recipe
    return b, umeta("Mass", "mid", "mid-range 98-250 from the road edge", kind=kind, width=w, depth=d, height=h, authored=True, long_axis="x", **kw)


# ================================================================ far mesa walls (T1)
def far_wall(name, sky, depth, H_, seed_off=0):
    """A far mesa wall along X from a skyline [(x, h), ...]: a fluted front (small jogs in depth), strata bands and a lit rim in
    the aerial ramp, a sloped scree foot, finished ends, back and top."""
    rng = rng_of(name)
    b = L.new(name)
    tone = sky
    xs = [p[0] for p in H_]
    x_mid = (min(xs) + max(xs)) / 2
    pts = [(x - x_mid, h) for x, h in H_]
    zf0 = -depth / 2
    zb = depth / 2
    n = len(pts) - 1
    jog = [0.0] + [rng.choice([-4.0, -2.0, 0.0, 2.5, 4.5]) for _ in range(n)]
    zfs = [zf0 + jog[i + 1] for i in range(n)]  # front plane of strip i
    HM = max(p[1] for p in pts)
    lv = [FOUND, HM * 0.30, HM * 0.58]
    rimw = max(7.0, HM * 0.12)

    def bands(x0, h0, x1, h1, fn_face):
        """The front-face polygons of a strip: horizontal strata under a rim band that follows the skyline."""
        lo = [(x0, FOUND), (x1, FOUND), (x1, h1 - rimw), (x0, h0 - rimw)]
        for k in range(3):
            ya = lv[k]
            yb = lv[k + 1] if k < 2 else 1e9
            poly = clip_poly(lo, min(x0, x1) - 1, ya, max(x0, x1) + 1, yb)
            if len(poly) >= 3:
                fn_face(poly, tone[k if k < 3 else 2])
        fn_face([(x0, h0 - rimw), (x1, h1 - rimw), (x1, h1), (x0, h0)], tone[3])

    for i in range(n):
        (x0, h0), (x1, h1) = pts[i], pts[i + 1]
        zf = zfs[i]

        def front(poly, sw, zf=zf):
            b.face([V(px, py, zf) for px, py in poly], sw, V(0, 0, -1))

        bands(x0, h0, x1, h1, front)
        # sloped scree foot in front of the wall
        b.face([V(x0, FOUND, zf - 7), V(x1, FOUND, zf - 7), V(x1, 7.0, zf), V(x0, 7.0, zf)], tone[1], V(0, 0.5, -1))
        # top (the lit plane) and back
        b.face([V(x0, h0, zf), V(x1, h1, zf), V(x1, h1, zb), V(x0, h0, zb)], tone[3], V(0, 1, 0))
        b.face([V(x0, FOUND, zb), V(x1, FOUND, zb), V(x1, h1, zb), V(x0, h0, zb)], tone[0], V(0, 0, 1))
        # the jog between this strip and the next (a side face turned to the shade)
        if i < n - 1:
            za, zc = zf, zfs[i + 1]
            if abs(za - zc) > 0.01:
                hh = h1
                for k in range(3):
                    ya, yb = lv[k], (lv[k + 1] if k < 2 else hh)
                    yb = min(yb, hh)
                    if yb > ya:
                        sw = tone[max(0, k - 1)]
                        b.face([V(x1, ya, za), V(x1, ya, zc), V(x1, yb, zc), V(x1, yb, za)], sw, V(1 if za > zc else -1, 0, 0))
    # ends
    for xe, he, zfe, sg in ((pts[0][0], pts[0][1], zfs[0], -1), (pts[-1][0], pts[-1][1], zfs[-1], 1)):
        b.face([V(xe, FOUND, zfe - 7), V(xe, FOUND, zb), V(xe, he, zb), V(xe, he, zfe), V(xe, 7.0, zfe)], tone[0], V(sg, 0, 0))
    ext = (max(p[0] for p in pts) - min(p[0] for p in pts), HM, depth)
    return b, umeta("Backdrop", "far", "far backdrop 300-900 from the road edge", kind="mesa wall", width=round(ext[0], 1), depth=depth + 7, height=HM, authored=True, role="far mesa wall, aerial-ramp colour (depth is baked, not fog)", district="any")


def mesa_pts(kind):
    if kind == "A":  # a long tabletop with chipped ends and small steps
        return [(0, 36), (14, 58), (40, 66), (90, 68), (150, 70), (215, 69), (262, 66), (320, 68), (372, 62), (404, 52), (430, 30)]
    if kind == "B":  # a tabletop with a deep notch and a lower shoulder
        return [(0, 44), (20, 74), (60, 82), (118, 84), (150, 84), (164, 58), (176, 36), (196, 34), (210, 60), (222, 84), (270, 82), (318, 78), (344, 58), (372, 52), (398, 30)]
    if kind == "C":  # a stepped wall with one butte
        return [(0, 30), (16, 52), (70, 54), (96, 74), (160, 76), (190, 90), (200, 102), (226, 104), (240, 92), (252, 78), (292, 76), (322, 62), (370, 60), (396, 34)]
    pts = []  # D: a low ridge with a saddle (two soft humps)
    for i in range(0, 17):
        x = i * 22.0
        t = i / 16.0
        h = 30 + 30 * math.sin(math.pi * min(1, t * 1.9)) ** 1.2 if t < 0.52 else 26 + 28 * math.sin(math.pi * (t - 0.44) / 0.56) ** 1.1
        pts.append((x, max(26.0, h)))
    pts[8] = (176.0, 32.0)
    pts[0] = (0.0, 24.0)
    pts[-1] = (352.0, 22.0)
    return pts


def _mesa_wall(nm, k, tones, depth):
    return far_wall(nm, list(tones), depth, mesa_pts(k))


# each wall sits at its own distance in the aerial ramp: shade, body, upper body, sunlit rim (nearer = warmer and darker)
reg("DH_BG_MesaWall_A", lambda nm: _mesa_wall(nm, "A", ("sk_3", "sk_1", "sk_5", "sk_2"), 70))
reg("DH_BG_MesaWall_B", lambda nm: _mesa_wall(nm, "B", ("sk_1", "sk_5", "sk_6", "sk_4"), 64))
reg("DH_BG_MesaWall_C", lambda nm: _mesa_wall(nm, "C", ("sk_5", "sk_6", "sk_7", "sk_4"), 76))
reg("DH_BG_MesaWall_D", lambda nm: _mesa_wall(nm, "D", ("sk_6", "sk_7", "sk_8", "sk_trim"), 58))


# ================================================================ mid-butte family (T3): six silhouette classes
def butte_table(name):
    """A: table mesa, 62 x 46 x 54: a long flat top, four strata bands, a front notch that deepens upward."""
    rng = rng_of(name)
    b = L.new(name)
    base = blob(0, 0, 31, 23, 16, 0.55, rng, 0.05, rot=0.2)
    tower(
        b, base, rng,
        [
            (FOUND, 1.0, None),
            (12.0, 0.86, "talus", {"nf": 0.0}),
            (24.0, 0.835, 2, {"nf": 0.12, "w": 0.8}),
            (24.0, 0.80, "d_talus", {"nf": 0.2, "w": 0.8}),
            (38.0, 0.79, 3, {"nf": 0.34, "w": 0.9}),
            (50.0, 0.785, 4, {"nf": 0.46, "w": 0.9}),
            (54.0, 0.76, 4, {"nf": 0.5, "w": 0.6}),
        ],
    )
    measure(name, b, 54.0)
    return mass_meta(name, b, 62, 54, 46, "table mesa", silhouette="table mesa", mirror_safe=True)


def butte_stepped(name):
    """B: stepped butte, 48 x 40 x 62: talus foot, a lower cliff, a wide sand-covered step, a narrower offset tower, a cap lip."""
    rng = rng_of(name)
    b = L.new(name)
    lower = blob(0, 0, 24, 19, 16, 0.5, rng, 0.05, rot=0.1)
    upper = blob(5.5, -2, 12, 13, 16, 0.6, rng, 0.06, rot=0.5)
    spur = blob(-12.5, 4.0, 6.5, 8.0, 12, 0.6, rng, 0.06, rot=0.3)
    tower(
        b, lower, rng,
        [
            (FOUND, 1.0, None),
            (14.0, 0.80, "talus"),
            (31.0, 0.77, 2, {"w": 0.8}),
            (31.0, 1.0, "d_talus", {"poly": upper}),
            (46.0, 0.95, 3, {"poly": upper, "w": 0.7}),
            (57.0, 0.88, 4, {"poly": upper, "w": 0.7}),
            (62.0, 0.76, 4, {"poly": upper}),
        ],
    )
    tower(b, spur, rng, [(31.0, 1.0, None), (40.0, 0.92, 3), (45.0, 0.78, 4)])  # a lower pinnacle on the step
    b.meas = [m for m in b.meas if m[1] > 12.5 and m[2] > 12.5]  # the pinnacle is an accent on the step, not a mass
    measure(name, b, 62.0)
    return mass_meta(name, b, 48, 62, 40, "stepped butte", silhouette="stepped butte")


def butte_fin(name):
    """C: fin, 68 x 30 x 82: a serrated wall of three towers on a shared scree shoulder, each at least 14 thick."""
    rng = rng_of(name)
    b = L.new(name)
    sho = blob(0, 0, 34, 14.5, 16, 0.5, rng, 0.04)
    tower(b, sho, rng, [(FOUND, 1.0, None), (18.0, 0.82, "talus"), (24.0, 0.74, 2)], cap="d_talus")
    for cx, hx, hz, top, dz in ((-13.5, 10.5, 8.2, 82.0, 0.0), (8.0, 10.5, 7.8, 62.0, 0.8), (23.0, 8.5, 7.5, 44.0, -0.6)):
        base = blob(cx, dz, hx, hz, 12, 0.55, rng, 0.04)
        tower(b, base, rng, [(24.0, 1.0, None), (24.0 + (top - 24.0) * 0.5, 0.95, 3), (top - 8, 0.91, 4), (top, 0.86, 4)])
    measure(name, b, 82.0)
    return mass_meta(name, b, 68, 82, 30, "fin", silhouette="fin")


def butte_cap(name):
    """D: cap rock, 44 x 32 x 58: a scree mound, a waisted neck (at least 45 percent of the cap width) and a dark overhanging cap."""
    rng = rng_of(name)
    b = L.new(name)
    mound_p = blob(0, 0, 19, 15, 14, 0.7, rng, 0.05)
    neck = blob(0, 0, 10.5, 9.0, 14, 0.8, rng, 0.05, rot=0.2)
    cap = blob(0, 0, 22, 16, 14, 0.62, rng, 0.05, rot=0.2)
    rings = tower(
        b, mound_p, rng,
        [
            (FOUND, 1.0, None),
            (9.0, 0.78, "talus"),
            (9.0, 1.0, "d_talus", {"poly": neck, "w": 0.3}),
            (22.0, 0.97, 3, {"poly": neck}),
            (34.0, 0.88, 4, {"poly": neck}),
            (39.0, 0.95, 3, {"poly": neck}),
        ],
        cap=None,
    )
    # the underside of the cap (deep shade between the neck and the cap rim), then the cap walls and the lit top
    rim_lo = wob(sc(cap, 0.96), rng, 0.4)
    loft(b, rings[-1][0], 39.0, rim_lo, 39.0, "r_shadow", up=False, fn=lambda sp, n: sp)
    cr = [(rim_lo, 39.0), (wob(sc(cap, 1.0), rng, 0.4), 41.5), (wob(sc(cap, 0.98), rng, 0.4), 52.0), (wob(sc(cap, 0.86), rng, 0.4), 57.0)]
    for i in range(3):
        loft(b, cr[i][0], cr[i][1], cr[i + 1][0], cr[i + 1][1], 2 if i < 2 else 4)
    capface(b, cr[-1][0], 57.0, "r_top")
    b.meas = getattr(b, "meas", []) + [(39.0, 44.0, 32.0), (57.0, 38.0, 28.0)]
    measure(name, b, 57.0)
    MEASURE[name]["neck_over_cap"] = round(2 * 10.5 * 0.88 / (2 * 22.0), 2)
    return mass_meta(name, b, 44, 57, 32, "cap rock", silhouette="cap rock")


def butte_saddle(name):
    """E: saddle, 74 x 36 x 76: a broad shoulder carrying a tall and a lower summit with a saddle between them."""
    rng = rng_of(name)
    b = L.new(name)
    sho = blob(0, 0, 34, 17.5, 18, 0.5, rng, 0.04, rot=0.12)
    tower(b, sho, rng, [(FOUND, 1.0, None), (14.0, 0.86, "talus"), (26.0, 0.84, 2), (38.0, 0.80, 3)], cap="d_talus")
    sad = blob(1.2, 0.0, 11.0, 12.5, 14, 0.55, rng, 0.05, rot=0.2)  # the saddle itself: a lower block joining the two summits
    tower(b, sad, rng, [(38.0, 1.0, None), (43.0, 0.95, 3), (47.0, 0.88, 4)])
    for cx, hx, hz, top, dz in ((-16.0, 11.5, 12.0, 76.0, 0.5), (19.5, 10.5, 11.5, 60.0, -0.5)):
        base = blob(cx, dz, hx, hz, 14, 0.55, rng, 0.05, rot=0.3)
        tower(b, base, rng, [(38.0, 1.0, None), (38.0 + (top - 38.0) * 0.45, 0.88, 3), (top - 9, 0.76, 4), (top, 0.62, 4)])
    measure(name, b, 76.0)
    return mass_meta(name, b, 74, 76, 36, "saddle", silhouette="saddle")


def butte_archwall(name):
    """F: ridge / arch wall, 74 x 34 x 58: a leaning rock wall with a squared opening (flat lintel) set off centre."""
    rng = rng_of(name)
    b = L.new(name)
    foot = blob(0, 0, 34.5, 17, 18, 0.5, rng, 0.04)
    tower(b, foot, rng, [(FOUND, 1.0, None), (9.0, 0.9, "talus")], cap="d_talus")
    pl = blob(-17.0, 0.0, 14.0, 13.0, 14, 0.55, rng, 0.05, rot=0.2)
    pr = blob(20.5, 0.5, 10.5, 12.5, 14, 0.55, rng, 0.05, rot=0.4)
    tower(b, pl, rng, [(9.0, 1.0, None), (20.0, 0.95, 2), (29.0, 0.92, 3)], cap=None)
    tower(b, pr, rng, [(9.0, 1.0, None), (20.0, 0.95, 2), (29.0, 0.92, 3)], cap=None)
    lint = blob(0, 0.2, 33.0, 14.2, 16, 0.5, rng, 0.03)
    # one continuous upper mass over the window whose crest leans and rises toward the left (a ridge, not a slab on legs)
    rings = tower(b, lint, rng, [(29.0, 1.0, None), (40.0, 0.98, 3, {"dx": -1.0}), (52.0, 0.92, 4, {"dx": -3.5}), (63.0, 0.82, 4, {"dx": -7.0, "nf": 0.2}), (72.0, 0.70, 4, {"dx": -9.5, "nf": 0.3})], w=0.4)
    b.face([V(x, 29.0, z) for x, z in rings[0][0]], "r_shadow", V(0, -1, 0))  # the underside seen through the opening
    measure(name, b, 72.0)
    return mass_meta(name, b, 74, 72, 34, "ridge arch wall", silhouette="ridge/arch wall", opening="about x -3..11, y 9..29, flat lintel")


for _n, _f in (("A", butte_table), ("B", butte_stepped), ("C", butte_fin), ("D", butte_cap), ("E", butte_saddle), ("F", butte_archwall)):
    reg(f"DH_Mass_Butte_{_n}", _f)
# ================================================================ dune ridges (T5)
def dune(name, length, width, H, kind):
    """A dune ridge along X: a long S-curve crest, a gentle windward (-Z) slope, a steeper shaded lee (+Z) face, a crest highlight and
    a darker clay-sand skirt (never pale at the foot). A grid of 15 stations by 8 rows."""
    rng = rng_of(name)
    b = L.new(name)
    nx = 15
    us = [0.0, 0.17, 0.36, 0.52, 0.60, 0.70, 0.86, 1.0]
    cu = 0.60
    ph = rng.uniform(0, 3)

    def env(s):
        return math.sin(math.pi * s) ** 0.75

    def amp(s):
        if kind == "A":  # one long sinuous crest, rising to the right
            return H * (0.72 + 0.28 * math.sin(2.6 * math.pi * s + ph)) * env(s) * (0.85 + 0.3 * s)
        if kind == "B":  # a double hump
            g = math.exp(-(((s - 0.28) / 0.17) ** 2)) + 0.8 * math.exp(-(((s - 0.72) / 0.15) ** 2))
            return H * (0.2 + 0.8 * min(1.0, g)) * env(s) ** 0.5
        return H * (0.80 + 0.2 * math.sin(3.4 * math.pi * s + ph)) * env(s) ** 0.9  # C: low, long, soft

    def prof(u):
        if u <= cu:
            return (u / cu) ** 1.3
        return ((1 - u) / (1 - cu)) ** 1.05

    grid = []
    for i in range(nx):
        s = i / (nx - 1)
        x = (s - 0.5) * length
        a = amp(s)
        zs = (width * 0.16) * math.sin(2 * math.pi * 1.25 * s + ph)  # the crest meanders in plan (the S-curve)
        col = []
        for u in us:
            h = a * prof(u)
            col.append((x, -0.3 + h, -width / 2 + u * width + zs * (0.35 + 0.65 * math.sin(math.pi * u)) + (rng.uniform(-0.6, 0.6) if 0 < u < 1 else 0.0)))
        grid.append(col)
    for i in range(nx - 1):
        for j in range(len(us) - 1):
            q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
            ys = [p[1] for p in q]
            if max(ys) < -0.2:
                continue
            avg = sum(ys) / 4 + 0.3
            r = avg / H
            um = (us[j] + us[j + 1]) / 2
            if r < 0.13:
                sw = "gp_clay"
            elif r < 0.26 and um < cu:
                sw = "gp_dark"
            elif abs(um - cu) < 0.07:
                sw = "d_crest"
            elif um > cu:
                sw = "d_rose" if (r < 0.2 or (i + 2 * j) % 13 == 0) else "d_shade"
            else:
                sw = "d_rose" if (i * 7 + j) % 9 == 0 else "d_gold"
            b.face([V(*p) for p in q], sw, V(0, 1, (-1 if um < cu else 1) * 0.6))
    return b, umeta("Backdrop", "mid", "dune ridge 60-300 from the road edge", kind="dune", width=length, depth=width, height=H, authored=True, role="soft S-curve dune ridge: crest highlight, shaded lee, clay-sand skirt", district=["MirageDunes", "CactusFlats"])


reg("DH_BG_Dune_A", dune, 150.0, 52.0, 24.0, "A")
reg("DH_BG_Dune_B", dune, 112.0, 46.0, 18.0, "B")
reg("DH_BG_Dune_C", dune, 160.0, 58.0, 12.0, "C")


# ================================================================ ground patches (T7): flat, top at y = +0.12, no bottom
GY = 0.12
GD = 0.20  # detail laid on a patch


def flat(b, poly, y, sw):
    b.face([V(x, y, z) for x, z in poly], sw, V(0, 1, 0))


def ribbon(b, path, w, y, sw):
    """A flat ribbon of width w along a polyline in xz."""
    pts = []
    for i, (x, z) in enumerate(path):
        a = path[max(0, i - 1)]
        c = path[min(len(path) - 1, i + 1)]
        dx, dz = c[0] - a[0], c[1] - a[1]
        ln = math.hypot(dx, dz) or 1.0
        nx_, nz_ = -dz / ln, dx / ln
        pts.append(((x + nx_ * w / 2, z + nz_ * w / 2), (x - nx_ * w / 2, z - nz_ * w / 2)))
    for i in range(len(pts) - 1):
        (a0, a1), (b0, b1) = pts[i], pts[i + 1]
        b.face([V(a0[0], y, a0[1]), V(b0[0], y, b0[1]), V(b1[0], y, b1[1]), V(a1[0], y, a1[1])], sw, V(0, 1, 0))


def ground_patch(name, kind, w, d):
    rng = rng_of(name)
    b = L.new(name)
    n = {"A": 11, "B": 12, "C": 10, "D": 13, "E": 9}[kind]
    out = blob(0, 0, w / 2, d / 2, n, 0.8, rng, 0.14, rot=rng.uniform(0, 1))
    if kind == "A":  # a tonal patch: dark clay with a pale heart and two scrub islands
        flat(b, out, GY, "gp_dark")
        flat(b, blob(-w * 0.08, d * 0.04, w * 0.27, d * 0.26, 8, 0.8, rng, 0.14), GD, "gp_pale")
        for cx, cz in ((w * 0.3, -d * 0.12), (-w * 0.33, d * 0.18)):
            flat(b, blob(cx, cz, w * 0.07, d * 0.1, 6, 0.9, rng, 0.2), GD, "gp_scrub")
    elif kind == "B":  # wash lines: a pale wash with three dry-channel meanders
        flat(b, out, GY, "gp_wash")
        for k, zc in enumerate((-d * 0.22, 0.0, d * 0.2)):
            path = [(-w * 0.4 + i * w * 0.8 / 6, zc + math.sin(i * 0.9 + k * 2.1) * d * 0.09) for i in range(7)]
            ribbon(b, path, 3.0 - k * 0.5, GD, "gp_dark")
    elif kind == "C":  # wheel tracks: two parallel ruts curving across a pale patch
        flat(b, out, GY, "gp_pale")
        for off in (-3.2, 3.2):
            path = [(-w * 0.42 + i * w * 0.84 / 6, off + math.sin(i * 0.55) * d * 0.14) for i in range(7)]
            ribbon(b, path, 2.2, GD, "g_track")
    elif kind == "D":  # scrub scatter: a dull olive tone with small dark and olive islands
        flat(b, out, GY, "gp_scrub")
        for i in range(6):
            flat(b, blob(rng.uniform(-w * 0.34, w * 0.34), rng.uniform(-d * 0.3, d * 0.3), rng.uniform(3, 6), rng.uniform(2.5, 4.5), 6, 0.9, rng, 0.2), GD, "olive" if i % 2 else "gp_dark")
    else:  # E: clay hardpan with cracks (pale wash lines)
        flat(b, out, GY, "gp_clay")
        flat(b, blob(w * 0.05, 0, w * 0.32, d * 0.3, 8, 0.8, rng, 0.12), GD, "gp_dark")
        for k in range(2):
            path = [(-w * 0.3 + i * w * 0.6 / 4, (k - 0.5) * d * 0.4 + math.sin(i * 1.3 + k) * d * 0.1) for i in range(5)]
            ribbon(b, path, 0.9, GD + 0.01, "gp_wash")
    return b, umeta("Ground", "near", "ground 30-300 from the road", kind="ground patch", width=w, depth=d, height=GY, authored=True, flat=True, role="tonal ground texture, no bottom", district="any")


for _n, (_k, _w, _d) in {"A": ("A", 150.0, 64.0), "B": ("B", 196.0, 52.0), "C": ("C", 124.0, 40.0), "D": ("D", 96.0, 62.0), "E": ("E", 70.0, 34.0)}.items():
    reg(f"DH_Ground_{_n}", ground_patch, _k, _w, _d)


# ================================================================ gorge walls (T6): terraced walls swept along a toe line
def _norm(dx, dz):
    ln = math.hypot(dx, dz) or 1.0
    return dx / ln, dz / ln


def gorge(name, legs, H, mirror=False, spacing=11.0, cut=7.0, kind="straight"):
    """A terraced gorge wall swept along a toe line (legs = polyline of (x, z)); the void is on the left of the travel direction
    (heading +X: toward -Z). Profile from the toe: scree, three cliff tiers (shaded foot, lit face), two sand ledges, a lit rim
    ledge, and the back wall. Corners are chamfered. The piece is centred on x and z, bottom at the gorge floor."""
    rng = rng_of(name)
    b = L.new(name)
    legs = list(legs)
    if mirror:
        legs = [(-x, z) for x, z in reversed(legs)]
    # subdivide each leg; chamfer the corners
    pts = [legs[0]]
    for k in range(1, len(legs)):
        a, c = legs[k - 1], legs[k]
        dx, dz = _norm(c[0] - a[0], c[1] - a[1])
        ln = math.hypot(c[0] - a[0], c[1] - a[1])
        start = pts[-1]
        end = c
        if k < len(legs) - 1:
            end = (c[0] - dx * cut, c[1] - dz * cut)
        seg = math.hypot(end[0] - start[0], end[1] - start[1])
        m = max(1, int(round(seg / spacing)))
        for i in range(1, m + 1):
            pts.append((start[0] + (end[0] - start[0]) * i / m, start[1] + (end[1] - start[1]) * i / m))
        if k < len(legs) - 1:
            nx2, nz2 = _norm(legs[k + 1][0] - c[0], legs[k + 1][1] - c[1])
            pts.append((c[0] + nx2 * cut, c[1] + nz2 * cut))
    n = len(pts)
    # interior normals (mitred)
    en = []
    for i in range(n - 1):
        dx, dz = _norm(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
        en.append((dz, -dx))
    nm = []
    for i in range(n):
        if i == 0:
            nm.append(en[0])
        elif i == n - 1:
            nm.append(en[-1])
        else:
            sx, sz = en[i - 1][0] + en[i][0], en[i - 1][1] + en[i][1]
            dot = en[i - 1][0] * en[i][0] + en[i - 1][1] * en[i][1]
            nm.append((sx / (1 + dot), sz / (1 + dot)))
    # the profile: (offset away from the void, y, band spec of the link from the previous vertex)
    yt, y1, y2 = 0.15 * H, 0.40 * H, 0.68 * H
    prof = [
        (-8.0, FOUND, None, 0),
        (0.0, yt, "talus", 0),
        (0.0, yt + (y1 - yt) * 0.45, ("sh", 2), 1),
        (0.0, y1, 3, 1),
        (8.5, y1, "d_talus", 1),
        (8.5, y1 + (y2 - y1) * 0.45, ("sh", 3), 2),
        (8.5, y2, 3, 2),
        (18.5, y2, "d_talus", 2),
        (18.5, y2 + (H - y2) * 0.45, ("sh", 4), 3),
        (18.5, H, 4, 3),
        (30.0, H, "r_top", 3),
    ]
    noise = []
    for t in range(4):
        raw = [rng.uniform(-1, 1) for _ in range(n)]
        noise.append([(raw[max(0, i - 1)] + raw[i] * 3 + raw[min(n - 1, i + 1)]) / 5 for i in range(n)])
    amp = [0.0, 3.2, 4.2, 5.2]

    def P(i, j):
        off, y, _, t = prof[j]
        o = off + amp[t] * noise[t][i] * (1 if j > 0 else 0)
        return (pts[i][0] - nm[i][0] * o, y, pts[i][1] - nm[i][1] * o)

    for i in range(n - 1):
        for j in range(len(prof) - 1):
            q = [P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)]
            spec = prof[j + 1][2]
            mx, mz = (nm[i][0] + nm[i + 1][0]) / 2, (nm[i][1] + nm[i + 1][1]) / 2
            if abs(prof[j + 1][1] - prof[j][1]) < 1e-6:
                hint = V(0, 1, 0)
            elif spec == "talus":
                hint = V(mx, 0.6, mz)
            else:
                hint = V(mx, 0, mz)
            vq = [V(*p) for p in q]
            nv = newell(vq)
            if nv.length < 1e-9:
                continue
            nv.normalize()
            if nv.dot(hint) < 0:
                nv = -nv
            b.face(vq, rock_sw(spec, nv), hint)
        # the back wall (buried by the rim land) so the piece is closed
        ta, tc = P(i, len(prof) - 1), P(i + 1, len(prof) - 1)
        b.face([V(*ta), V(*tc), V(tc[0], FOUND, tc[2]), V(ta[0], FOUND, ta[2])], "d_sh_1", V(-(nm[i][0] + nm[i + 1][0]), 0, -(nm[i][1] + nm[i + 1][1])))
    # end caps
    for i, sg in ((0, -1), (n - 1, 1)):
        tx, tz = (pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]) if i == 0 else (pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1])
        poly = [V(*P(i, j)) for j in range(len(prof))]
        top = P(i, len(prof) - 1)
        poly.append(V(top[0], FOUND, top[2]))
        b.face(poly, "d_sh_1", V(sg * tx, 0, sg * tz))
    # centre on x and z
    xs = [v.co.x for v in b.bm.verts]
    zs = [-v.co.y for v in b.bm.verts]  # Blender y = -roblox z
    b.shift(-(max(xs) + min(xs)) / 2, 0.0, -(max(zs) + min(zs)) / 2)
    ex = (max(xs) - min(xs), H, max(zs) - min(zs))
    meta = umeta("Gorge", "mid", "gorge wall 100-250 from the axis", kind="gorge wall", width=round(ex[0], 1), depth=round(ex[2], 1), height=H, authored=True, district=["CanyonBridge"], role="terraced gorge wall: scree, three cliff tiers with shaded feet, sand ledges, lit rim; void toward -Z" + ("; end piece: the wall turns toward the void at +X so the gorge closes" if kind == "end" else ""))
    if mirror:
        meta["mirror_of"] = name[: -len("_mirror")] if name.endswith("_mirror") else name
    return b, meta


reg("DH_Gorge_Wall_A", gorge, [(-63.0, 0.0), (63.0, 0.0)], 54.0)
reg("DH_Gorge_Wall_B", gorge, [(-90.0, 0.0), (90.0, 0.0)], 78.0)
reg("DH_Gorge_Wall_C", gorge, [(-62.0, 0.0), (30.0, 0.0), (30.0, -66.0)], 88.0, kind="end")
reg("DH_Gorge_Wall_C_mirror", gorge, [(-62.0, 0.0), (30.0, 0.0), (30.0, -66.0)], 88.0, mirror=True, kind="end")
# ================================================================ small-part primitives
def ribbed(b, x, y, z, h, r0, r1, sides, sa, sb, top=None, phase=0.0, dx=0.0, dz=0.0):
    """A frustum whose faces alternate two swatches (cactus ribs). dx, dz lean the top."""
    lo = [(x + math.cos(phase + 2 * math.pi * k / sides) * r0, z + math.sin(phase + 2 * math.pi * k / sides) * r0) for k in range(sides)]
    hi = [(x + dx + math.cos(phase + 2 * math.pi * k / sides) * r1, z + dz + math.sin(phase + 2 * math.pi * k / sides) * r1) for k in range(sides)]
    for k in range(sides):
        k2 = (k + 1) % sides
        am = phase + 2 * math.pi * (k + 0.5) / sides
        b.face([V(lo[k][0], y, lo[k][1]), V(lo[k2][0], y, lo[k2][1]), V(hi[k2][0], y + h, hi[k2][1]), V(hi[k][0], y + h, hi[k][1])], sa if k % 2 == 0 else sb, V(math.cos(am), 0, math.sin(am)))
    if top and r1 > 0:
        b.face([V(px, y + h, pz) for px, pz in hi], top, V(0, 1, 0))
    return hi


def pyr(b, x, y, z, r, h, sw):
    """A small 4-sided pyramid (a bloom or a spine cluster)."""
    base = [(x - r, z - r), (x + r, z - r), (x + r, z + r), (x - r, z + r)]
    ap = V(x, y + h, z)
    for k in range(4):
        a, c = base[k], base[(k + 1) % 4]
        b.face([V(a[0], y, a[1]), V(c[0], y, c[1]), ap], sw, V((a[0] + c[0]) / 2 - x, 0.5, (a[1] + c[1]) / 2 - z))


def extrude_xy(b, pts, z0, z1, side, front, back=None):
    """A polygon in the (x, y) plane extruded between z0 (the -Z face) and z1 (the +Z face)."""
    n = len(pts)
    ar = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sg = 1 if ar > 0 else -1
    b.face([V(x, y, z0) for x, y in pts], front, V(0, 0, -1))
    b.face([V(x, y, z1) for x, y in pts], back or side, V(0, 0, 1))
    for i in range(n):
        a, c = pts[i], pts[(i + 1) % n]
        b.face([V(a[0], a[1], z0), V(c[0], c[1], z0), V(c[0], c[1], z1), V(a[0], a[1], z1)], side, V(sg * (c[1] - a[1]), -sg * (c[0] - a[0]), 0))


def glyph_cactus(b, cx, y0, z, s, sw):
    """A flat saguaro glyph (a sign decoration) standing on y0, scale s, in the plane z facing -Z."""
    p = [(-0.16, 0), (0.16, 0), (0.16, 0.42), (0.48, 0.42), (0.48, 0.86), (0.32, 0.86), (0.32, 0.58), (0.16, 0.58), (0.16, 1.0), (-0.16, 1.0), (-0.16, 0.46), (-0.32, 0.46), (-0.32, 0.74), (-0.48, 0.74), (-0.48, 0.30), (-0.16, 0.30)]
    b.face([V(cx + x * s, y0 + y * s, z) for x, y in p], sw, V(0, 0, -1))


def board(b, cx, cy, cz, w, h, t, frame, face, border=0.45, back=None):
    """A sign board centred on (cx, cy, cz), face toward -Z: a frame box with an inset blank face. Returns the sign_face dict."""
    box(b, V(cx, cy, cz), (w, h, t), {"side": frame, "top": frame, "bottom": frame, "front": frame, "back": back or frame})
    zf = cz - t / 2 - 0.1
    b.face([V(cx - w / 2 + border, cy - h / 2 + border, zf), V(cx + w / 2 - border, cy - h / 2 + border, zf), V(cx + w / 2 - border, cy + h / 2 - border, zf), V(cx - w / 2 + border, cy + h / 2 - border, zf)], face, V(0, 0, -1))
    return {"centre": [round(cx, 2), round(cy, 2), round(zf, 2)], "size": [round(w - 2 * border, 2), round(h - 2 * border, 2)]}


def post(b, x, z, h, w=0.7, sw="m_wood_2", top="m_wood_1"):
    box(b, V(x, h / 2, z), (w, h, w), {"side": sw, "top": top, "skip_bottom": True})


# ================================================================ plant families (F1): Sentinel, Barrel, Paddle, Rosette
def sentinel(b, x, z, h, rng, arms=3, y0=0.0, yaw=0.0):
    """A tall columnar cactus: an 8-rib trunk with a rounded crown, elbow arms (horizontal then up) and a bloom on top."""
    r = max(1.5, h * 0.072)
    ribbed(b, x, y0, z, h * 0.84, r, r * 0.9, 8, "sage_mid", "sage_dark", None, phase=0.2)
    ribbed(b, x, y0 + h * 0.84, z, h * 0.16, r * 0.9, r * 0.34, 8, "sage_mid", "sage_light", "sage_light", phase=0.2)
    sides = [yaw + 0.15, yaw + math.pi - 0.1, yaw + math.pi * 0.5 + 0.3][:arms]
    for k, a in enumerate(sides):
        ay = y0 + h * (0.34 + 0.16 * k * (1 if k < 2 else 0.4) + 0.05 * rng.random())
        reach = r * (2.5 + 0.5 * rng.random())
        ar = r * 0.6
        ex, ez = x + math.cos(a) * reach, z + math.sin(a) * reach
        tube(b, [V(x, ay, z), V(ex, ay, ez)], [ar, ar], 5, "sage_dark", cap=False)
        up = h * (0.24 + 0.08 * rng.random())
        ribbed(b, ex, ay - ar, ez, up + ar + ar * 1.2, ar, ar * 0.45, 5, "sage_mid", "sage_dark", "sage_light", phase=0.3)
    pyr(b, x, y0 + h, z, r * 0.22, r * 0.5, "bloom")


def barrel(b, x, z, R, hh, y0=0.0, sides=10, blooms=3, phase=0.0):
    """A low ribbed barrel cactus with a flat crown and a ring of blooms."""
    ribbed(b, x, y0 - 0.2, z, hh * 0.55 + 0.2, R * 0.82, R, sides, "sage_mid", "sage_dark", None, phase=phase)
    ribbed(b, x, y0 + hh * 0.55, z, hh * 0.45, R, R * 0.6, sides, "sage_mid", "sage_dark", "sage_light", phase=phase)
    for i in range(blooms):
        a = phase + 2 * math.pi * i / blooms
        pyr(b, x + math.cos(a) * R * 0.28, y0 + hh, z + math.sin(a) * R * 0.28, R * 0.12, R * 0.26, "bloom")


def plate(b, c, v, nn, rx, ry, thick, n, sw_face, sw_back, sw_rim):
    """A flat oval plate (a cactus pad): centre c, long axis v, normal nn."""
    v = V(*v).normalized()
    nn = V(*nn).normalized()
    u = v.cross(nn).normalized()
    c = V(*c)
    ring = [c + u * (rx * math.cos(2 * math.pi * k / n)) + v * (ry * math.sin(2 * math.pi * k / n)) for k in range(n)]
    f = [p + nn * (thick / 2) for p in ring]
    bk = [p - nn * (thick / 2) for p in ring]
    b.face(f, sw_face, nn)
    b.face(bk, sw_back, -nn)
    for k in range(n):
        k2 = (k + 1) % n
        mid = (ring[k] + ring[k2]) / 2 - c
        b.face([f[k], f[k2], bk[k2], bk[k]], sw_rim, mid)


def paddle(b, x, z, s, rng, y0=0.0, yaw=0.0, chain=5, wide=1.0):
    """A paddle (prickly-pear) cactus: flat oval pads chained and tilted, small fruit on the rim. wide > 1 spreads it low and broad."""
    ca, sa = math.cos(yaw), math.sin(yaw)

    def P(px, py, pz):
        return (x + px * ca - pz * sa, y0 + py, z + px * sa + pz * ca)

    def D(dx, dy, dz):
        return (dx * ca - dz * sa, dy, dx * sa + dz * ca)

    wd = wide
    pads = [((0, 0.9 * s, 0), (0.1, 1, 0.0), (0, 0, -1), 0.8 * s, 1.15 * s),
            ((-0.7 * s * wd, 2.6 * s, 0.1), (-0.45 * wd, 1, 0.05), (0.15, 0, -1), 0.7 * s, 1.0 * s),
            ((0.8 * s * wd, 2.5 * s, -0.1), (0.5 * wd, 1, 0.0), (-0.2, 0, -1), 0.7 * s, 1.0 * s),
            ((-1.5 * s * wd, 4.1 * s, 0.1), (-0.5 * wd, 1, 0.1), (0.2, 0, -1), 0.55 * s, 0.8 * s),
            ((1.8 * s * wd, 3.9 * s, 0.0), (0.7 * wd, 1, 0.1), (-0.25, 0, -1), 0.55 * s, 0.8 * s)][:chain]
    for c, v, nn, rx, ry in pads:
        plate(b, P(*c), D(*v), D(*nn), rx, ry, 0.5, 6, "sage_mid", "sage_dark", "sage_dark")
    for c, v, nn, rx, ry in pads[-2:]:
        p = P(c[0] + v[0] * ry * 0.7, c[1] + ry * 0.75, c[2])
        pyr(b, p[0], p[1], p[2], 0.28 * s, 0.5 * s, "bloom")


def rosette(b, x, z, R, hh, y0=0.0, blades=12, phase=0.0, sw=("sage_light", "sage_mid"), tip="olive"):
    """A spiky ground rosette: blades radiating and arching up from a core, a ring of upright inner blades."""
    for k in range(blades):
        a = phase + 2 * math.pi * k / blades
        ca, sa = math.cos(a), math.sin(a)
        px, pz = -sa, ca
        w = R * 0.12
        pts = [V(x + ca * R * 0.1, y0 + hh * 0.3, z + sa * R * 0.1), V(x + ca * R * 0.55 + px * w, y0 + hh * 0.85, z + sa * R * 0.55 + pz * w), V(x + ca * R, y0 + hh * 0.55, z + sa * R), V(x + ca * R * 0.55 - px * w, y0 + hh * 0.85, z + sa * R * 0.55 - pz * w)]
        b.face2(pts, sw[k % 2])
    for k in range(blades // 2):
        a = phase + 0.26 + 2 * math.pi * k / (blades // 2)
        ca, sa = math.cos(a), math.sin(a)
        px, pz = -sa, ca
        w = R * 0.08
        pts = [V(x + ca * R * 0.08, y0 + hh * 0.3, z + sa * R * 0.08), V(x + ca * R * 0.26 + px * w, y0 + hh * 0.7, z + sa * R * 0.26 + pz * w), V(x + ca * R * 0.42, y0 + hh * 1.0, z + sa * R * 0.42), V(x + ca * R * 0.26 - px * w, y0 + hh * 0.7, z + sa * R * 0.26 - pz * w)]
        b.face2(pts, tip if k % 2 else sw[0])


def fol_meta(kind, h, **kw):
    return umeta("Fol", NEAR, "near foliage", kind=kind, height=h, role="plant family " + kind, district=["CactusFlats", "DinerStrip", "MirageDunes"], **kw)


def fol_sentinel(name, h, arms):
    rng = rng_of(name)
    b = L.new(name)
    sentinel(b, 0, 0, h, rng, arms)
    return b, fol_meta("Sentinel", h)


def fol_barrel(name, kind):
    rng = rng_of(name)
    b = L.new(name)
    if kind == "A":
        barrel(b, 0, 0, 3.2, 6.0)
    else:  # B: a big barrel with two young ones
        barrel(b, 0, 0, 2.7, 5.0, sides=8, phase=0.3)
        barrel(b, 3.6, 1.0, 1.5, 2.8, sides=6, blooms=2)
        barrel(b, -2.4, 2.8, 1.2, 2.2, sides=6, blooms=1)
    return b, fol_meta("Barrel", 6.0 if kind == "A" else 5.0)


def fol_paddle(name, kind):
    rng = rng_of(name)
    b = L.new(name)
    if kind == "A":
        paddle(b, 0, 0, 1.45, rng, chain=5)
    else:
        paddle(b, 0, 0, 1.15, rng, yaw=0.0, chain=4, wide=-1.0)
    return b, fol_meta("Paddle", 8.5 if kind == "A" else 6.0)


def fol_rosette(name, kind):
    b = L.new(name)
    if kind == "A":
        rosette(b, 0, 0, 5.0, 4.0, blades=12)
    else:
        rosette(b, 0, 0, 4.6, 4.8, blades=10, phase=0.4, sw=("sage_mid", "olive"), tip="sage_light")
    return b, fol_meta("Rosette", 4.0 if kind == "A" else 4.8)


reg("DH_Fol_Sentinel_A", fol_sentinel, 28.0, 3)
reg("DH_Fol_Sentinel_B", fol_sentinel, 14.0, 2)
reg("DH_Fol_Barrel_A", fol_barrel, "A")
reg("DH_Fol_Barrel_B", fol_barrel, "B")
reg("DH_Fol_Paddle_A", fol_paddle, "A")
reg("DH_Fol_Paddle_B", fol_paddle, "B")
reg("DH_Fol_Rosette_A", fol_rosette, "A")
reg("DH_Fol_Rosette_B", fol_rosette, "B")


# ================================================================ cluster lots (F2): designed groups on a clay-sand pad
def cluster_lot(name, w, plan):
    """plan: dict(hero=(x, z, h, arms), sats=[(kind, x, z, size)...], rocks=[(x, z, sx, sy)...], patch=(cx, cz, rx, rz, swatch))"""
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    padp = blob(0, d / 2, w / 2 - 0.5, d / 2 - 0.6, 12, 0.75, rng, 0.07, rot=plan.get("rot", 0.0))
    prism(b, padp, 0.0, 0.35, "g_lo", "gp_clay", top=True)
    pcx, pcz, prx, prz, psw = plan["patch"]
    flat(b, blob(pcx, pcz, prx, prz, 8, 0.8, rng, 0.14), 0.46, psw)
    y0 = 0.25
    hx, hz, hh, arms = plan["hero"]
    sentinel(b, hx, hz, hh, rng, arms, y0=y0, yaw=plan.get("yaw", 0.0))
    for kind, x, z, s in plan["sats"]:
        if kind == "barrel":
            barrel(b, x, z, s, s * 1.8, y0=y0, phase=rng.random())
        elif kind == "paddle":
            paddle(b, x, z, s, rng, y0=y0, yaw=rng.uniform(0, 6.28), chain=4)
        else:
            rosette(b, x, z, s, s * 0.85, y0=y0, blades=10, phase=rng.random())
    for x, z, sx, sy in plan["rocks"]:
        L.rock(b, x, z, sx, sy, sx * 0.85, rng, y=y0 - 0.1, light=("r_2", "r_3", "r_4", "r_top"), subdiv=0, jitter=0.2)
    return finish(b, w, d, hh + 1.0, "low", ["CactusFlats", "MirageDunes", "DinerStrip"], module="cluster", group="cluster", hero="Sentinel", role="designed plant group: one Sentinel hero, satellites, rocks and a ground patch (G4, G10)")


reg("DH_Lot_Cluster24_a", cluster_lot, 24, {"hero": (-4.5, 11.0, 26.0, 3), "sats": [("barrel", 4.5, 6.0, 2.4), ("barrel", 7.5, 12.5, 1.6), ("rosette", -8.5, 4.5, 3.6)], "rocks": [(8.0, 16.5, 4.2, 2.6), (-9.0, 16.0, 3.0, 2.0), (1.5, 18.0, 2.4, 1.6)], "patch": (0, 11, 9.5, 6.5, "gp_wash"), "rot": 0.1})
reg("DH_Lot_Cluster24_b", cluster_lot, 24, {"hero": (6.0, 13.5, 15.0, 2), "sats": [("paddle", -5.5, 7.5, 1.5), ("rosette", 0.5, 5.0, 3.2), ("barrel", -8.5, 15.0, 2.0)], "rocks": [(-1.0, 17.0, 5.2, 3.2), (-9.5, 5.0, 2.6, 1.8)], "patch": (-2, 11, 8.0, 7.5, "gp_dark"), "rot": 0.5, "yaw": 1.8})
reg("DH_Lot_Cluster36_a", cluster_lot, 36, {"hero": (-11.0, 12.0, 29.0, 3), "sats": [("paddle", 2.0, 7.0, 1.6), ("barrel", 8.5, 12.0, 2.5), ("rosette", 14.0, 6.0, 3.8)], "rocks": [(-1.0, 17.5, 5.5, 3.6), (-15.0, 5.0, 3.0, 2.0), (6.0, 18.0, 3.4, 2.2), (13.5, 16.0, 2.4, 1.6)], "patch": (3, 11, 13.0, 6.0, "gp_wash"), "rot": 0.3, "yaw": 0.4})
reg("DH_Lot_Cluster36_b", cluster_lot, 36, {"hero": (9.0, 9.5, 19.0, 2), "sats": [("rosette", -5.0, 8.0, 3.4), ("barrel", -12.0, 14.0, 2.2), ("paddle", 15.0, 15.5, 1.3)], "rocks": [(-10.0, 5.0, 4.4, 2.8), (-2.0, 16.5, 3.0, 2.0), (1.5, 4.5, 2.0, 1.4)], "patch": (-4, 12, 11.0, 6.8, "gp_scrub"), "rot": 0.9, "yaw": 2.6})
# ================================================================ edge pieces (E2, E3): roadside markers, bottom centre, -Z toward the road
def edge_meta(kind, h, **kw):
    return umeta("Edge", NEAR, "road edge 38-60 from the centre", kind=kind, height=h, district="any", **kw)


def edge_plaque(name):
    """An original rounded sandstone plaque with a saguaro glyph on two timber posts, about 6 x 7. The lower panel is the sign face."""
    b = L.new(name)
    for x in (-2.0, 2.0):
        post(b, x, 0.0, 6.0, 0.8)
    outline = rounded_rect2(-3.0, 2.2, 3.0, 7.0, 1.3, seg=3, corners=(False, False, True, True))
    extrude_xy(b, outline, -0.45, 0.45, "sign_stone", "sign_stone", "sign_stone")
    zf = -0.56
    b.face([V(-2.4, 2.7, zf), V(2.4, 2.7, zf), V(2.4, 4.9, zf), V(-2.4, 4.9, zf)], "sign_face", V(0, 0, -1))
    glyph_cactus(b, 0.0, 5.15, zf, 1.5, "sage_mid")
    return b, edge_meta("plaque", 7.0, sign_face={"centre": [0.0, 3.8, zf], "size": [4.8, 2.2]}, role="district marker plaque")


def edge_reflector(name):
    b = L.new(name)
    post(b, 0, 0, 4.0, 0.5)
    for sg in (-1, 1):  # a pale reflector button each way along the road, on both faces
        box(b, V(0, 3.2, sg * 0.28), (0.7, 0.7, 0.1), {"side": "m_white", "top": "m_white", "skip_bottom": True})
    box(b, V(0, 3.9, 0), (0.64, 0.2, 0.64), {"side": "m_metal", "top": "m_metal", "skip_bottom": True})
    return b, edge_meta("reflector", 4.0, role="road edge reflector post")


def edge_cairn(name):
    rng = rng_of(name)
    b = L.new(name)
    for i, (x, z, sx, sy) in enumerate(((0.0, 0.0, 3.3, 1.3), (0.15, 0.1, 2.7, 1.1), (-0.1, 0.0, 2.1, 0.95), (0.1, -0.05, 1.6, 0.85), (0.0, 0.0, 1.0, 0.7))):
        y = (0.0, 1.05, 1.95, 2.7, 3.3)[i]
        L.rock(b, x, z, sx, sy * 1.55, sx * 0.9, rng, y=y, light=("r_pale", "d_talus", "m_stone", "r_top"), subdiv=0, jitter=0.12)
    return b, edge_meta("cairn", 4.0, role="stacked-stone marker")


def edge_culvert(name):
    """A dry-wash culvert marker group, 10 long: a stone headwall with a dark opening and a short timber railing along its top."""
    b = L.new(name)
    wall_with_holes_front(b, -5.0, 5.0, 0.0, 2.6, 0.0, [(-2.2, 2.2, 0.0, 1.7)], "m_stone")
    box(b, V(0, 1.3, 0.8), (10.0, 2.6, 1.6), {"side": "m_stone", "top": "gp_pale", "skip_front": True, "skip_bottom": True})
    # the opening: reveals and a dark back
    for x, sg in ((-2.2, 1), (2.2, -1)):
        b.face([V(x, 0, 0), V(x, 1.7, 0), V(x, 1.7, 1.4), V(x, 0, 1.4)], "d_weather_2", V(sg, 0, 0))
    b.face([V(-2.2, 1.7, 0), V(2.2, 1.7, 0), V(2.2, 1.7, 1.4), V(-2.2, 1.7, 1.4)], "d_weather_2", V(0, -1, 0))
    b.face([V(-2.2, 0, 1.4), V(2.2, 0, 1.4), V(2.2, 1.7, 1.4), V(-2.2, 1.7, 1.4)], "r_shadow", V(0, 0, -1))
    for s in (-1, 1):  # flared wing walls
        box(b, V(s * 6.4, 0.9, -0.6), (3.0, 1.8, 0.8), {"side": "m_stone", "top": "gp_pale", "skip_bottom": True}, yaw=-s * 0.5)
    for x in (-4.4, 0.0, 4.4):
        post(b, x, 0.8, 4.4, 0.5, "m_wood_2", "m_wood_1")
    for y in (3.5, 4.3):
        box(b, V(0, y, 0.8), (10.0, 0.3, 0.3), {"side": "m_wood_1", "skip_bottom": True})
    return b, edge_meta("culvert", 4.6, role="dry-wash culvert marker: headwall, opening, short railing")


def wall_with_holes_front(b, x0, x1, y0, y1, zf, holes, sw):
    """A wall in the plane z = zf facing -Z with rectangular holes [(x0, x1, y0, y1)] (x increases to the right)."""
    from kitlib import wall_with_holes as wwh

    wwh(b, -x1, -x0, y0, y1, [(-h[1], -h[0], h[2], h[3]) for h in holes], sw, d=-zf)


def edge_wallstub(name):
    """A low stone wall stub, 12 long, 2.6 tall: coursed stones on the face, a capping slab."""
    rng = rng_of(name)
    b = L.new(name)
    box(b, V(0, 1.15, 0.7), (12.0, 2.3, 1.4), {"side": "m_stone", "top": "m_stone", "skip_front": True, "skip_bottom": True})
    sws = ["m_stone", "d_talus", "r_pale", "m_stone"]
    for row in range(3):
        x = -6.0
        k = 0
        while x < 5.9:
            wdt = min(6.0 - x, rng.choice([2.4, 3.0, 3.6]) if row != 1 else rng.choice([2.0, 2.7, 3.3]))
            if row == 1 and x == -6.0:
                wdt = 1.3
            b.face([V(x + 0.05, row * 0.77, 0), V(x + wdt - 0.05, row * 0.77, 0), V(x + wdt - 0.05, (row + 1) * 0.77 - 0.05, 0), V(x + 0.05, (row + 1) * 0.77 - 0.05, 0)], sws[(k + row) % 4], V(0, 0, -1))
            x += wdt
            k += 1
    box(b, V(0, 2.5, 0.7), (12.4, 0.4, 1.8), {"side": "sign_stone", "top": "d_talus", "skip_bottom": False})
    return b, edge_meta("wall", 2.7, role="low stone wall stub")


def edge_rail24(name):
    """E3: a 24-long timber post-and-rail fence run for near framing."""
    b = L.new(name)
    for i in range(5):
        post(b, -12.0 + i * 6.0, 0.0, 3.6 if i % 2 == 0 else 3.4, 0.55)
    for y in (2.9, 1.7):
        box(b, V(0, y, 0.0), (24.5, 0.32, 0.28), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": False})
    return b, edge_meta("rail", 3.6, role="timber rail fence run")


reg("DH_Edge_Plaque", edge_plaque)
reg("DH_Edge_Reflector", edge_reflector)
reg("DH_Edge_Cairn", edge_cairn)
reg("DH_Edge_Culvert", edge_culvert)
reg("DH_Edge_WallStub", edge_wallstub)
reg("DH_Edge_Rail24", edge_rail24)


# ================================================================ sign boards (S1): blank cream face, text drawn at runtime
def sign_meta(kind, h, face, **kw):
    return umeta("Sign", NEAR, "roadside sign", kind=kind, height=h, sign_face=face, district="any", **kw)


def sign_pole(name):
    """A roadside pole sign: a board 8 x 4 on a post, braced, with a rust frame and a blank cream face."""
    b = L.new(name)
    cyl(b, V(0, 0, 0.6), 8.4, 0.45, 6, "m_wood_2", r_top=0.4, top_sw="m_wood_1")
    face = board(b, 0.0, 6.6, 0.0, 8.0, 4.0, 0.7, "sign_rust", "sign_face", 0.5, back="m_sign_frame")
    for s in (-1, 1):
        beam(b, V(0, 3.4, 0.6), V(s * 3.2, 4.8, 0.45), 0.35, 0.35, "m_wood_2")
    box(b, V(0, 9.0, 0.0), (8.6, 0.4, 1.0), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    return b, sign_meta("pole", 9.2, face, role="roadside pole sign 8 x 4")


def sign_blade(name):
    """A blade sign facing the approach: a tall narrow board with chamfered corners on a post, finial on top."""
    b = L.new(name)
    cyl(b, V(0, 0, 0.8), 15.0, 0.5, 6, "m_wood_2", r_top=0.42, top_sw="m_wood_1")
    pts = [(-1.9, 4.3), (1.9, 4.3), (2.5, 4.9), (2.5, 13.1), (1.9, 13.7), (-1.9, 13.7), (-2.5, 13.1), (-2.5, 4.9)]
    extrude_xy(b, pts, -0.5, 0.45, "sign_rust", "sign_rust", "m_sign_frame")
    zf = -0.6
    b.face([V(-1.7, 4.9, zf), V(1.7, 4.9, zf), V(1.7, 13.1, zf), V(-1.7, 13.1, zf)], "sign_face", V(0, 0, -1))
    box(b, V(0, 14.0, 0.8), (1.0, 0.9, 1.0), {"side": "w_accent_2", "top": "w_accent_2", "skip_bottom": True})
    return b, sign_meta("blade", 15.0, {"centre": [0.0, 9.0, zf], "size": [3.4, 8.2]}, role="blade sign facing the approach")


def sign_plaque(name):
    """The sandstone district plaque, wide: a rounded slab on two stone piers with a saguaro glyph above a blank panel."""
    b = L.new(name)
    for x in (-5.0, 5.0):
        box(b, V(x, 1.4, 0.0), (2.6, 2.8, 2.2), {"side": "m_stone", "top": "d_talus", "skip_bottom": True})
    outline = rounded_rect2(-7.0, 2.8, 7.0, 9.6, 1.6, seg=3, corners=(False, False, True, True))
    extrude_xy(b, outline, -0.8, 0.8, "sign_stone", "sign_stone", "sign_stone")
    zf = -0.9
    b.face([V(-6.0, 3.4, zf), V(6.0, 3.4, zf), V(6.0, 6.8, zf), V(-6.0, 6.8, zf)], "sign_face", V(0, 0, -1))
    glyph_cactus(b, 0.0, 7.0, zf, 2.2, "sage_mid")
    for s in (-1, 1):
        glyph_cactus(b, s * 4.6, 7.2, zf, 1.3, "sage_dark")
    return b, sign_meta("plaque", 9.6, {"centre": [0.0, 5.1, zf], "size": [12.0, 3.4]}, role="district plaque, wide")


def sign_wayfinding(name):
    """A low wayfinding board on two posts."""
    b = L.new(name)
    for x in (-4.0, 4.0):
        post(b, x, 0.0, 6.4, 0.7)
    face = board(b, 0.0, 5.0, 0.0, 10.4, 3.2, 0.6, "sign_rust", "sign_face", 0.4, back="m_sign_frame")
    box(b, V(0, 6.85, 0.0), (11.0, 0.35, 0.9), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    return b, sign_meta("wayfinding", 7.0, face, role="low wayfinding board on two posts")


def sign_warning(name):
    """A HAZARD warning board (hazard-only orange and white stripes, a blank cream face), 120+ studs ahead of a hazard."""
    b = L.new(name)
    for x in (-3.6, 3.6):
        post(b, x, 0.0, 5.6, 0.8, "m_metal_dark", "m_metal")
    cx, cy, w, h, t = 0.0, 7.2, 10.0, 6.0, 0.6
    box(b, V(cx, cy, 0.0), (w, h, t), {"side": "haz_black", "top": "haz_black", "bottom": "haz_black", "back": "haz_black", "front": "haz_black"})
    zf = -t / 2 - 0.1
    stripes(b, cx - w / 2 + 0.3, cy - h / 2 + 0.3, cx + w / 2 - 0.3, cy + h / 2 - 0.3, 1.6, ["haz_orange", "haz_white"], lambda u, v: V(u, v, zf), V(0, 0, -1), slant=1.0)
    zi = zf - 0.12
    b.face([V(-3.6, 5.6, zi), V(3.6, 5.6, zi), V(3.6, 8.8, zi), V(-3.6, 8.8, zi)], "sign_face", V(0, 0, -1))
    return b, sign_meta("warning", 10.2, {"centre": [0.0, 7.2, zi], "size": [7.2, 3.2]}, role="hazard warning board (hazard-only orange/white)", hazard=True)


reg("DH_Sign_Pole", sign_pole)
reg("DH_Sign_Blade", sign_blade)
reg("DH_Sign_Plaque", sign_plaque)
reg("DH_Sign_Wayfinding", sign_wayfinding)
reg("DH_Sign_Warning", sign_warning)
# ================================================================ Diner Strip: facade lots (A1), shade (A2), forecourt (A3)
def window(b, x0, x1, y0, y1, zf, trim, rec=0.7, glass="w_glass"):
    """A recessed window in a front wall at z = zf: reveals in `trim`, glass at the back, a sill and a lintel."""
    b.face([V(x0, y0, zf + rec), V(x1, y0, zf + rec), V(x1, y1, zf + rec), V(x0, y1, zf + rec)], glass, V(0, 0, -1))
    for x, sg in ((x0, 1), (x1, -1)):
        b.face([V(x, y0, zf), V(x, y1, zf), V(x, y1, zf + rec), V(x, y0, zf + rec)], trim, V(sg, 0, 0))
    b.face([V(x0, y1, zf), V(x1, y1, zf), V(x1, y1, zf + rec), V(x0, y1, zf + rec)], "r_shadow", V(0, -1, 0))
    b.face([V(x0, y0, zf), V(x1, y0, zf), V(x1, y0, zf + rec), V(x0, y0, zf + rec)], trim, V(0, 1, 0))
    box(b, V((x0 + x1) / 2, y0 - 0.2, zf - 0.25), (x1 - x0 + 0.8, 0.4, 0.5), {"side": trim, "top": trim, "skip_bottom": True})  # sill


def awning(b, x0, x1, y_hi, y_lo, zf, reach, top_sw, under_sw="r_shadow"):
    """A sloped canopy over a window run: top plane, underside in shade and two end triangles."""
    z1 = zf - reach
    b.face([V(x0, y_hi, zf), V(x1, y_hi, zf), V(x1, y_lo, z1), V(x0, y_lo, z1)], top_sw, V(0, 1, -0.6))
    b.face([V(x0, y_hi - 0.15, zf), V(x1, y_hi - 0.15, zf), V(x1, y_lo - 0.15, z1), V(x0, y_lo - 0.15, z1)], under_sw, V(0, -1, 0.6))
    for x, sg in ((x0, -1), (x1, 1)):
        b.face([V(x, y_hi, zf), V(x, y_lo, z1), V(x, y_lo - 0.15, z1), V(x, y_hi - 0.15, zf)], top_sw, V(sg, 0, 0))
    b.face([V(x0, y_lo, z1), V(x1, y_lo, z1), V(x1, y_lo - 0.15, z1), V(x0, y_lo - 0.15, z1)], top_sw, V(0, 0, -1))


def parapet(b, x0, x1, y0, zf, steps, side_sw, front_sw, t=1.0):
    """A stepped false-front parapet standing on y0: steps = [(x_from, x_to, height)] from left to right; extruded t deep."""
    pts = [(x0, y0), (x1, y0)]
    for xa, xb, hh in reversed(steps):
        pts += [(xb, y0 + hh), (xa, y0 + hh)]
    # the outline above goes right-to-left along the top; collapse duplicate verticals
    out = []
    for p in pts:
        if not out or abs(p[0] - out[-1][0]) > 1e-6 or abs(p[1] - out[-1][1]) > 1e-6:
            out.append(p)
    extrude_xy(b, out, zf - 0.4, zf - 0.4 + t, side_sw, front_sw, front_sw)


def facade_pad(b, w, d, apron_w, zf, deck=None):
    """A clay forecourt pad with a paved apron from the verge edge (z 0) to the door (z = zf)."""
    box(b, V(0, 0.2, d / 2), (w, 0.4, d), {"side": "g_lo", "top": "gp_clay", "skip_bottom": True})
    box(b, V(0, 0.28, zf / 2), (apron_w, 0.56, zf), {"side": "gp_dark", "top": "gp_pave", "skip_bottom": True, "skip_back": True})


def lot_cafe(name):
    """A: the cafe, 36 x 24 x 17: cream walls, turquoise trim and door, a stepped false front with a blank sign panel, coral awnings,
    vigas under the roofline, shade in warm r_shadow, a paved apron from the verge to the door."""
    rng = rng_of(name)
    b = L.new(name)
    w, d, zf, bw, bd, h = 36.0, 24.0, 8.0, 29.0, 13.0, 11.5
    facade_pad(b, w, d, 24.0, zf)
    X0, X1 = -bw / 2, bw / 2
    holes = [(-2.4, 2.4, 0.56, 8.6), (-11.5, -5.5, 3.2, 8.2), (5.5, 11.5, 3.2, 8.2)]
    wall_with_holes_front(b, X0, X1, 0.56, h, zf, holes, "w_wall_2")
    box(b, V(0, h / 2, zf + bd / 2), (bw, h - 0.0, bd), {"side": "w_wall_2", "top": "w_roof_flat", "skip_front": True, "skip_bottom": True})
    # door (turquoise) and two windows
    b.face([V(-2.4, 0.56, zf + 0.7), V(2.4, 0.56, zf + 0.7), V(2.4, 8.6, zf + 0.7), V(-2.4, 8.6, zf + 0.7)], "w_door", V(0, 0, -1))
    for x, sg in ((-2.4, 1), (2.4, -1)):
        b.face([V(x, 0.56, zf), V(x, 8.6, zf), V(x, 8.6, zf + 0.7), V(x, 0.56, zf + 0.7)], "w_accent_1", V(sg, 0, 0))
    b.face([V(-2.4, 8.6, zf), V(2.4, 8.6, zf), V(2.4, 8.6, zf + 0.7), V(-2.4, 8.6, zf + 0.7)], "r_shadow", V(0, -1, 0))
    for x0, x1 in ((-11.5, -5.5), (5.5, 11.5)):
        window(b, x0, x1, 3.2, 8.2, zf, "w_accent_1")
    awning(b, -12.4, -4.6, 9.6, 7.4, zf, 3.4, "w_accent_2")
    awning(b, 4.6, 12.4, 9.6, 7.4, zf, 3.4, "w_accent_2")
    # a turquoise band under the parapet and vigas (round beam ends) along the roofline
    box(b, V(0, 10.2, zf - 0.15), (bw + 0.4, 0.7, 0.4), {"side": "w_accent_1", "top": "w_accent_1", "skip_bottom": True, "skip_back": True})
    for i in range(7):
        box(b, V(-12.0 + i * 4.0, 9.35, zf - 0.55), (0.7, 0.7, 0.9), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True, "skip_back": True})
    # the false front: stepped, turquoise-capped, with a blank sign panel
    parapet(b, X0 - 0.2, X1 + 0.2, h, zf, [(X0 - 0.2, -8.0, 2.4), (-8.0, 8.0, 5.4), (8.0, X1 + 0.2, 2.4)], "w_accent_1", "w_wall_2", 1.0)
    zp = zf - 0.55
    b.face([V(-6.2, h + 1.6, zp), V(6.2, h + 1.6, zp), V(6.2, h + 4.4, zp), V(-6.2, h + 4.4, zp)], "sign_face", V(0, 0, -1))
    # side windows, a back door, roof gadgets
    for sx in (-1, 1):
        for zz in (zf + 3.5, zf + 8.5):
            b.face([V(sx * (bw / 2 + 0.05), 3.4, zz - 1.3), V(sx * (bw / 2 + 0.05), 3.4, zz + 1.3), V(sx * (bw / 2 + 0.05), 7.6, zz + 1.3), V(sx * (bw / 2 + 0.05), 7.6, zz - 1.3)], "w_glass", V(sx, 0, 0))
    b.face([V(-1.6, 0.56, zf + bd + 0.05), V(1.6, 0.56, zf + bd + 0.05), V(1.6, 7.6, zf + bd + 0.05), V(-1.6, 7.6, zf + bd + 0.05)], "m_wood_2", V(0, 0, 1))
    box(b, V(8.0, h + 1.2, zf + 8.0), (3.2, 2.4, 3.2), {"side": "w_wall_4", "top": "w_trim_1", "skip_bottom": True})
    box(b, V(-8.5, h + 0.6, zf + 7.0), (4.0, 1.2, 3.0), {"side": "m_metal", "top": "m_metal", "skip_bottom": True})
    # planter barrels flanking the door, small tables on the apron
    for x in (-4.2, 4.2):
        cyl(b, V(x, 0.56, zf - 1.2), 1.7, 0.9, 6, "m_wood_1", r_top=0.95, top_sw="sage_mid")
    for x in (-8.5, 8.5):
        box(b, V(x, 1.5, zf - 5.0), (2.4, 0.2, 2.4), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
        box(b, V(x, 0.8, zf - 5.0), (0.4, 1.4, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    return finish(b, w, d, h + 5.4, "low", ["DinerStrip"], shop=True, module="shop", sign_face={"centre": [w / 2, h + 3.0, zp], "size": [12.4, 2.8]}, role="cafe facade lot (turquoise trim), apron to the door")


def lot_post(name):
    """B: the trading post, 48 x 24 x 20: a long cream-and-adobe body with a deep timber porch (posts, shed roof, shade underside in
    r_shadow), a stepped false front with coral trim and a blank sign panel, hanging rugs, crates and pots."""
    rng = rng_of(name)
    b = L.new(name)
    w, d, zf, bw, bd, h = 48.0, 24.0, 10.0, 43.0, 13.0, 12.0
    facade_pad(b, w, d, 30.0, 2.4)
    box(b, V(0, 0.55, 6.2), (43.0, 0.9, 8.0), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})  # porch deck z 2.2..10.2
    X0, X1 = -bw / 2, bw / 2
    holes = [(-3.0, 3.0, 0.9, 8.8), (-17.0, -10.0, 3.6, 8.4), (10.0, 17.0, 3.6, 8.4), (-20.5, -19.0, 0.9, 7.0)]
    holes = holes[:3]
    wall_with_holes_front(b, X0, X1, 0.9, h, zf, holes, "w_wall_4")
    box(b, V(0, h / 2, zf + bd / 2), (bw, h, bd), {"side": "w_wall_4", "top": "w_roof_flat", "skip_front": True, "skip_bottom": True})
    # double door (brown, coral frame) and two windows
    b.face([V(-3.0, 0.9, zf + 0.7), V(3.0, 0.9, zf + 0.7), V(3.0, 8.8, zf + 0.7), V(-3.0, 8.8, zf + 0.7)], "m_wood_2", V(0, 0, -1))
    for x, sg in ((-3.0, 1), (3.0, -1)):
        b.face([V(x, 0.9, zf), V(x, 8.8, zf), V(x, 8.8, zf + 0.7), V(x, 0.9, zf + 0.7)], "w_accent_2", V(sg, 0, 0))
    b.face([V(-3.0, 8.8, zf), V(3.0, 8.8, zf), V(3.0, 8.8, zf + 0.7), V(-3.0, 8.8, zf + 0.7)], "r_shadow", V(0, -1, 0))
    for x0, x1 in ((-17.0, -10.0), (10.0, 17.0)):
        window(b, x0, x1, 3.6, 8.4, zf, "w_accent_2")
    # the porch: posts, a beam, a shed roof sloping up toward the building, shade underside
    for i in range(6):
        post(b, -20.0 + i * 8.0, 3.2, 9.0, 0.9)
    box(b, V(0, 9.4, 3.2), (43.4, 0.8, 1.1), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": False})
    yl, yh = 9.8, 11.4
    b.face([V(X0 - 0.4, yl, 1.8), V(X1 + 0.4, yl, 1.8), V(X1 + 0.4, yh, zf), V(X0 - 0.4, yh, zf)], "w_roof_1", V(0, 1, -0.4))
    b.face([V(X0 - 0.4, yl - 0.3, 1.8), V(X1 + 0.4, yl - 0.3, 1.8), V(X1 + 0.4, yh - 0.3, zf), V(X0 - 0.4, yh - 0.3, zf)], "r_shadow", V(0, -1, 0.4))
    for x, sg in ((X0 - 0.4, -1), (X1 + 0.4, 1)):
        b.face([V(x, yl, 1.8), V(x, yh, zf), V(x, yh - 0.3, zf), V(x, yl - 0.3, 1.8)], "w_roof_1", V(sg, 0, 0))
    b.face([V(X0 - 0.4, yl, 1.8), V(X1 + 0.4, yl, 1.8), V(X1 + 0.4, yl - 0.3, 1.8), V(X0 - 0.4, yl - 0.3, 1.8)], "m_wood_1", V(0, 0, -1))
    # a stepped false front with coral trim and a blank sign panel
    parapet(b, X0 - 0.2, X1 + 0.2, h, zf, [(X0 - 0.2, -14.0, 2.6), (-14.0, -6.0, 4.6), (-6.0, 6.0, 7.6), (6.0, 14.0, 4.6), (14.0, X1 + 0.2, 2.6)], "w_accent_2", "w_wall_2", 1.0)
    zp = zf - 0.55
    b.face([V(-9.0, h + 3.2, zp), V(9.0, h + 3.2, zp), V(9.0, h + 6.4, zp), V(-9.0, h + 6.4, zp)], "sign_face", V(0, 0, -1))
    # hanging rugs under the porch beam, crates, pots and a rack
    for x, sw in ((-14.0, "w_accent_2"), (-11.0, "w_accent_3"), (13.0, "sign_rust"), (16.0, "w_accent_2")):
        b.face2([V(x - 1.1, 5.0, 3.55), V(x + 1.1, 5.0, 3.55), V(x + 1.1, 8.8, 3.55), V(x - 1.1, 8.8, 3.55)], sw)
        b.face([V(x - 1.1, 5.0, 3.52), V(x + 1.1, 5.0, 3.52), V(x + 1.1, 5.5, 3.52), V(x - 1.1, 5.5, 3.52)], "m_wood_2", V(0, 0, -1))
    for k, (x, y, z, s) in enumerate(((7.0, 1.7, 6.0, 2.4), (9.6, 1.4, 6.2, 1.8), (8.0, 3.7, 6.0, 1.8), (-7.0, 1.5, 6.0, 2.0))):
        box(b, V(x, y, z), (s, s * 0.9, s), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})
    for k, x in enumerate((-5.0, -3.2, 3.2, 5.2)):
        cyl(b, V(x, 1.0, 6.0), 1.1 + 0.3 * (k % 2), 0.7, 6, "w_accent_1" if k == 1 else "sign_rust", r_top=0.5, top_sw="r_shadow")
    # side and back finish
    for sx in (-1, 1):
        for zz in (zf + 4.0, zf + 9.0):
            b.face([V(sx * (bw / 2 + 0.05), 3.8, zz - 1.3), V(sx * (bw / 2 + 0.05), 3.8, zz + 1.3), V(sx * (bw / 2 + 0.05), 7.8, zz + 1.3), V(sx * (bw / 2 + 0.05), 7.8, zz - 1.3)], "w_glass", V(sx, 0, 0))
    for x in (-10.0, 10.0):
        b.face([V(x - 1.6, 0.9, zf + bd + 0.05), V(x + 1.6, 0.9, zf + bd + 0.05), V(x + 1.6, 7.6, zf + bd + 0.05), V(x - 1.6, 7.6, zf + bd + 0.05)], "m_wood_2", V(0, 0, 1))
    box(b, V(-14.0, h + 1.0, zf + 7.0), (5.0, 2.0, 3.6), {"side": "w_wall_2", "top": "w_trim_1", "skip_bottom": True})
    return finish(b, w, d, h + 7.0, "low", ["DinerStrip"], shop=True, module="shop", sign_face={"centre": [w / 2, h + 4.8, zp], "size": [18.0, 3.2]}, role="trading post with a deep porch, coral trim")


def lot_tyre(name):
    """C: the tyre shed, 24 x 24 x 17: a cream shed with an open service bay (deep shade inside), an office door, a tall rectangular
    false front with a blank sign panel and coral trim, a sloped brown roof behind it, tyre stacks and crates."""
    rng = rng_of(name)
    b = L.new(name)
    w, d, zf, bw, bd, h = 24.0, 24.0, 5.0, 21.0, 16.0, 10.5
    facade_pad(b, w, d, 21.0, zf)
    X0, X1 = -bw / 2, bw / 2
    holes = [(-9.2, 0.2, 0.56, 8.2), (4.0, 7.6, 0.56, 7.6), (8.2, 10.0, 3.8, 6.6)]
    wall_with_holes_front(b, X0, X1, 0.56, h, zf, holes, "w_wall_2")
    box(b, V(0, h / 2, zf + bd / 2), (bw, h, bd), {"side": "w_wall_2", "top": "w_roof_2", "skip_front": True, "skip_bottom": True})
    # the open bay: deep shade inside, a wooden lintel; the office door in coral
    x0, x1 = -9.2, 0.2
    b.face([V(x0, 0.56, zf + 5.0), V(x1, 0.56, zf + 5.0), V(x1, 8.2, zf + 5.0), V(x0, 8.2, zf + 5.0)], "r_shadow", V(0, 0, -1))
    for x, sg in ((x0, 1), (x1, -1)):
        b.face([V(x, 0.56, zf), V(x, 8.2, zf), V(x, 8.2, zf + 5.0), V(x, 0.56, zf + 5.0)], "d_sh_1", V(sg, 0, 0))
    b.face([V(x0, 8.2, zf), V(x1, 8.2, zf), V(x1, 8.2, zf + 5.0), V(x0, 8.2, zf + 5.0)], "r_shadow", V(0, -1, 0))
    box(b, V((x0 + x1) / 2, 8.6, zf - 0.2), (x1 - x0 + 1.2, 0.8, 0.6), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True, "skip_back": True})
    b.face([V(4.0, 0.56, zf + 0.7), V(7.6, 0.56, zf + 0.7), V(7.6, 7.6, zf + 0.7), V(4.0, 7.6, zf + 0.7)], "w_accent_2", V(0, 0, -1))
    for x, sg in ((4.0, 1), (7.6, -1)):
        b.face([V(x, 0.56, zf), V(x, 7.6, zf), V(x, 7.6, zf + 0.7), V(x, 0.56, zf + 0.7)], "w_wall_4", V(sg, 0, 0))
    b.face([V(4.0, 7.6, zf), V(7.6, 7.6, zf), V(7.6, 7.6, zf + 0.7), V(4.0, 7.6, zf + 0.7)], "r_shadow", V(0, -1, 0))
    window(b, 8.2, 10.0, 3.8, 6.6, zf, "w_wall_4", rec=0.5)
    # a tall false front with coral trim and a blank sign panel; the roof slopes down behind it
    parapet(b, X0 - 0.2, X1 + 0.2, h, zf, [(X0 - 0.2, X1 + 0.2, 4.8)], "w_accent_2", "w_wall_2", 1.0)
    zp = zf - 0.55
    b.face([V(-8.0, h + 0.9, zp), V(8.0, h + 0.9, zp), V(8.0, h + 3.9, zp), V(-8.0, h + 3.9, zp)], "sign_face", V(0, 0, -1))
    b.face([V(X0 + 0.1, h - 0.05, zp - 0.02), V(X1 - 0.1, h - 0.05, zp - 0.02), V(X1 - 0.1, h + 0.5, zp - 0.02), V(X0 + 0.1, h - 0.05 + 0.5, zp - 0.02)], "sign_rust", V(0, 0, -1))
    # tyre stacks (rubber rings) left of the bay, an upright tyre, crates
    for x, z, n in ((-10.6, zf - 2.2, 4), (-8.6, zf - 2.0, 5), (6.2, zf - 2.4, 3)):
        for k in range(n):
            cyl(b, V(x, 0.56 + k * 0.78, z), 0.78, 1.5, 6, "m_black" if k % 2 == 0 else "m_metal_dark", top=(k == n - 1), top_sw="m_metal_dark", phase=0.4 * k)
    cyl(b, V(10.0, 0.56, zf - 1.0), 0.8, 1.5, 6, "m_black")
    for k, (x, z, s) in enumerate(((9.3, zf - 2.8, 1.8), (10.2, zf - 1.8, 1.5))):
        box(b, V(x, 0.56 + s / 2, z), (s, s, s), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})
    # side and back finish
    for sx in (-1, 1):
        b.face([V(sx * (bw / 2 + 0.05), 3.8, zf + 5.0), V(sx * (bw / 2 + 0.05), 3.8, zf + 8.0), V(sx * (bw / 2 + 0.05), 7.0, zf + 8.0), V(sx * (bw / 2 + 0.05), 7.0, zf + 5.0)], "w_glass", V(sx, 0, 0))
    b.face([V(-3.0, 0.56, zf + bd + 0.05), V(3.0, 0.56, zf + bd + 0.05), V(3.0, 8.4, zf + bd + 0.05), V(-3.0, 8.4, zf + bd + 0.05)], "d_weather_2", V(0, 0, 1))
    box(b, V(5.0, h + 0.9, zf + 10.0), (4.0, 1.8, 3.0), {"side": "m_metal", "top": "m_metal", "skip_bottom": True})
    return finish(b, w, d, h + 4.8, "low", ["DinerStrip", "CactusFlats"], shop=True, module="shop", sign_face={"centre": [w / 2, h + 2.4, zp], "size": [16.0, 3.0]}, role="tyre shed with an open service bay, coral trim")


reg("DH_Lot_Cafe36_a", lot_cafe)
reg("DH_Lot_Post48_a", lot_post)
reg("DH_Lot_Tyre24_a", lot_tyre)


def shade_ramada(name):
    """A flat-topped timber ramada, 24 x 14 x 11: six posts, two beams, a slatted roof slab with its underside in r_shadow, a bench."""
    b = L.new(name)
    for x in (-10.5, 0.0, 10.5):
        for z in (-5.0, 5.0):
            post(b, x, z, 10.0, 0.9)
    for z in (-5.0, 5.0):
        box(b, V(0, 10.5, z), (24.0, 0.9, 1.0), {"side": "m_wood_2", "top": "m_wood_1", "bottom": "r_shadow"})
    box(b, V(0, 11.1, 0.0), (24.2, 0.4, 13.0), {"side": "m_wood_1", "top": "m_wood_1", "bottom": "r_shadow"})
    for k in range(5):
        b.face([V(-11.9, 11.32, -5.4 + k * 2.7), V(11.9, 11.32, -5.4 + k * 2.7), V(11.9, 11.32, -4.2 + k * 2.7), V(-12.2, 11.32, -4.2 + k * 2.7)], "m_wood_2", V(0, 1, 0))
    box(b, V(0, 1.6, 4.2), (6.0, 0.3, 1.2), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    for x in (-2.4, 2.4):
        post(b, x, 4.2, 1.5, 0.4)
    return b, umeta("Prop", NEAR, "forecourt", kind="shade", width=24.0, height=11.5, role="ramada (shade structure)", district=["DinerStrip", "CactusFlats"])


def shade_umbrellas(name):
    """A cluster of three umbrellas with small tables, 12 wide."""
    b = L.new(name)
    for x, z, sw, hh in ((-3.6, 0.0, "w_accent_2", 7.0), (0.4, 2.8, "w_accent_1", 6.4), (3.8, -1.2, "w_wall_2", 6.8)):
        cyl(b, V(x, 0, z), hh, 0.2, 4, "m_metal_dark")
        cyl(b, V(x, hh - 0.2, z), 1.3, 2.8, 6, sw, top=True, bottom=True, r_top=0.3, top_sw=sw)
        box(b, V(x, 2.5, z), (2.2, 0.25, 2.2), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    return b, umeta("Prop", NEAR, "forecourt", kind="shade", width=12.0, height=7.5, role="umbrella cluster with tables", district=["DinerStrip"])


def pump_totem_parts(b, x, z):
    box(b, V(x, 0.4, z), (2.6, 0.8, 2.2), {"side": "m_stone", "top": "gp_pave", "skip_bottom": True})
    box(b, V(x, 3.0, z), (1.6, 4.4, 1.2), {"side": "w_wall_2", "top": "w_wall_2", "skip_bottom": True})
    box(b, V(x, 5.5, z), (1.9, 0.6, 1.5), {"side": "w_accent_2", "top": "w_accent_2", "skip_bottom": True})
    b.face([V(x - 0.55, 3.2, z - 0.65), V(x + 0.55, 3.2, z - 0.65), V(x + 0.55, 4.6, z - 0.65), V(x - 0.55, 4.6, z - 0.65)], "w_glass", V(0, 0, -1))
    b.face([V(x - 0.55, 3.2, z + 0.65), V(x + 0.55, 3.2, z + 0.65), V(x + 0.55, 4.6, z + 0.65), V(x - 0.55, 4.6, z + 0.65)], "w_glass", V(0, 0, 1))


def fore_pump_totem(name):
    b = L.new(name)
    pump_totem_parts(b, 0.0, 0.0)
    return b, umeta("Prop", NEAR, "forecourt", kind="pump", height=5.8, role="pump totem (original fictional pump)", district=["DinerStrip"])


def fore_pump_canopy(name):
    """A flat canopy line, 24 wide, 12.5 tall, with two pump totems under it; the underside is in shade."""
    b = L.new(name)
    for x in (-10.0, 10.0):
        for z in (-3.8, 3.8):
            post(b, x, z, 11.6, 0.9, "m_metal", "m_metal")
    box(b, V(0, 12.2, 0.0), (24.0, 1.4, 10.0), {"side": "w_accent_1", "top": "w_roof_flat", "bottom": "r_shadow"})
    box(b, V(0, 12.9, -4.9), (24.2, 0.5, 0.35), {"side": "w_wall_2", "top": "w_wall_2", "skip_bottom": True})
    box(b, V(0, 0.2, 0.0), (22.0, 0.4, 8.6), {"side": "gp_dark", "top": "gp_pave", "skip_bottom": True})
    for x in (-5.0, 5.0):
        pump_totem_parts(b, x, 0.0)
    return b, umeta("Prop", NEAR, "forecourt", kind="pump canopy", width=24.0, height=13.2, role="flat pump canopy with two totems", district=["DinerStrip"])


def fore_table(name):
    """A picnic table, 6 long, with no umbrella."""
    b = L.new(name)
    box(b, V(0, 2.3, 0.0), (6.0, 0.3, 2.5), {"side": "m_wood_1", "top": "m_wood_1", "bottom": "m_wood_2"})
    for z in (-2.0, 2.0):
        box(b, V(0, 1.35, z), (6.0, 0.3, 0.9), {"side": "m_wood_1", "top": "m_wood_1", "bottom": "m_wood_2"})
    for x in (-2.2, 2.2):
        for z in (-1.4, 1.4):
            post(b, x, z, 2.3, 0.35)
    return b, umeta("Prop", NEAR, "forecourt", kind="table", width=6.0, height=2.5, role="picnic table", district=["DinerStrip", "CactusFlats"])


def fore_planters(name):
    """Planter barrels, 6 wide: three half barrels with sage plants."""
    rng = rng_of(name)
    b = L.new(name)
    for x, z, r, hh in ((-2.0, 0.0, 1.2, 2.2), (1.6, 0.6, 1.0, 1.8), (0.0, -1.6, 0.9, 1.5)):
        cyl(b, V(x, 0, z), hh, r, 6, "m_wood_1", r_top=r * 0.95, top_sw="d_weather_2")
        cyl(b, V(x, hh * 0.45, z), 0.3, r * 1.06, 6, "m_metal_dark", top=False)
        L.rock(b, x, z, r * 1.4, r * 1.3, r * 1.4, rng, y=hh - 0.2, light=("sage_dark", "sage_mid", "sage_light", "sage_light"), subdiv=0, jitter=0.15)
    return b, umeta("Prop", NEAR, "forecourt", kind="planter", width=6.0, height=3.4, role="planter barrels", district=["DinerStrip"])


reg("DH_Shade_Ramada", shade_ramada)
reg("DH_Shade_Umbrellas", shade_umbrellas)
reg("DH_Fore_PumpTotem", fore_pump_totem)
reg("DH_Fore_PumpCanopy", fore_pump_canopy)
reg("DH_Fore_Table", fore_table)
reg("DH_Fore_Planters", fore_planters)
# ================================================================ landmarks: the arches (L1)
def rect(cx, cz, hx, hz):
    return [(cx - hx, cz - hz), (cx + hx, cz - hz), (cx + hx, cz + hz), (cx - hx, cz + hz)]


def rock_arch_thick(name):
    """L1: the thick natural bridge, 104 x 61 x 48 (frontage landmark, facade plane z = 0, the opening faces -Z). Two broad legs on a
    two-step plinth carry a FLAT SQUARED lintel 18 thick over a 42 wide, 32 high opening; the strata bands run on from the legs into
    the lintel; every side is finished and the lintel overhangs the legs. Not a ring: a gate mass."""
    rng = rng_of(name)
    b = L.new(name)
    W, D = 104.0, 48.0
    zc = D / 2
    plinth = blob(0, zc, 52.0, 24.0, 22, 0.45, rng, 0.02)
    rings = tower(
        b, plinth, rng,
        [
            (FOUND, 1.0, None),
            (5.0, 0.985, 2),
            (5.0, 0.92, "d_talus"),
            (9.0, 0.915, 3),
        ],
        cap="d_talus", w=0.3,
    )
    # the legs: strata bands 2 / 3 / 4 (y 9 .. 41), continuing into the lintel
    legs = []
    for sx, hx, ph in ((-1, 12.8, 0.1), (1, 12.0, 0.6)):
        cx = sx * 33.2
        base = blob(cx, zc, hx, 19.0, 16, 0.5, rng, 0.04, rot=ph)
        tower(b, base, rng, [(9.0, 1.0, None), (20.0, 0.97, 2), (32.0, 0.94, 3), (41.0, 0.92, 4)], cap=None, w=0.45)
    lint = blob(0, zc, 51.0, 20.5, 22, 0.45, rng, 0.02)
    lr = tower(b, lint, rng, [(41.0, 1.0, None), (50.0, 0.965, 3), (58.5, 0.92, 4, {"dx": 0.8}), (61.0, 0.90, 4, {"dx": 1.0})], w=0.35)
    b.face([V(x, 41.0, z) for x, z in lr[0][0]], "r_shadow", V(0, -1, 0))  # the underside seen through the opening
    # fallen blocks and boulders at the feet and a talus wedge beside each leg
    for sx, x, z, sxz, sy in ((-1, -46.0, 5.0, 6.5, 4.5), (1, 45.0, 7.0, 7.0, 5.0), (-1, -22.0, 3.5, 4.5, 3.0), (1, 21.0, 4.0, 5.0, 3.4), (-1, -43.0, 43.0, 6.0, 4.5), (1, 42.0, 42.0, 6.5, 5.0)):
        L.rock(b, x, z, sxz, sy, sxz * 0.9, rng, y=7.6, light=("r_2", "r_3", "r_4", "r_top"), subdiv=0, jitter=0.2)
    for x, z, s in ((-46.0, -1.0, 6.0), (46.0, 1.0, 5.6), (-32.0, -2.0, 4.2), (30.0, -1.5, 4.6)):
        L.rock(b, x, z + 6.0, s, s * 0.62, s * 0.9, rng, y=-0.4, light=("d_talus_sh", "d_talus", "r_pale", "r_top"), subdiv=0, jitter=0.2)
    measure(name, b, 61.0)
    MEASURE[name].update({"opening": "42 x 32", "lintel_thick": 17.5, "leg_w": 24.8})
    return lm_finish(b, W, D, 61.0, ["RedRockArches"], placement="beside", authored=True, family_note="thick arch", role="the thick natural bridge; flat squared lintel; opening faces -Z (the planner yaws it toward oncoming cars)", opening=[-21.0 + W / 2, 9.0, 21.0 + W / 2, 41.0])


def rock_arch_small(name):
    """Adam's second arch, 48 x 28 x 28: a smaller sibling, not a scaled copy: asymmetric legs (wide left, slender right), a lighter
    banding (bands 3 / 4), a notched stepped lintel over a 15 wide, 15 high opening, one plinth step, one fallen block."""
    rng = rng_of(name)
    b = L.new(name)
    W, D = 48.0, 28.0
    zc = D / 2
    plinth = blob(0, zc, 24.0, 14.0, 18, 0.45, rng, 0.02)
    tower(b, plinth, rng, [(FOUND, 1.0, None), (5.0, 0.94, 3)], cap="d_talus", w=0.3)
    pl = blob(-14.0, zc, 7.6, 11.0, 12, 0.5, rng, 0.04, rot=0.2)
    pr = blob(15.0, zc + 0.5, 6.0, 9.6, 12, 0.5, rng, 0.04, rot=0.5)
    tower(b, pl, rng, [(5.0, 1.0, None), (12.5, 0.96, 3), (20.0, 0.93, 4)], cap=None, w=0.35)
    tower(b, pr, rng, [(5.0, 1.0, None), (12.5, 0.95, 3), (20.0, 0.92, 4)], cap=None, w=0.3)
    lint = blob(-1.5, zc, 23.0, 12.0, 18, 0.5, rng, 0.03)
    lr = tower(b, lint, rng, [(20.0, 1.0, None), (25.0, 0.96, 4, {"dx": 0.5}), (28.0, 0.80, 4, {"dx": 3.0, "dz": 1.0})], w=0.3)
    b.face([V(x, 20.0, z) for x, z in lr[0][0]], "r_shadow", V(0, -1, 0))
    L.rock(b, 20.0, 3.0, 4.0, 3.0, 3.6, rng, y=4.2, light=("r_3", "r_4", "r_top", "r_top"), subdiv=0, jitter=0.2)
    L.rock(b, -22.0, 4.0, 3.0, 2.2, 2.7, rng, y=-0.3, light=("d_talus_sh", "d_talus", "r_pale", "r_top"), subdiv=0, jitter=0.2)
    measure(name, b, 28.0)
    return lm_finish(b, W, D, 28.0, ["RedRockArches"], placement="beside", authored=True, role="the small second arch: a smaller asymmetric sibling of RockArchThick", opening=[-6.5 + W / 2, 5.0, 8.5 + W / 2, 20.0])


reg("DH_LM_RockArchThick", rock_arch_thick)
reg("DH_LM_RockArchSmall", rock_arch_small)


# ================================================================ landmarks: the bridge parts (L2)
def msn_sw(spec, n):
    if n.y > 0.8:
        return "quay_top"
    if n.y < -0.3:
        return "bridge_steel_dark"
    return spec[0] if _lit(n) > 0.12 else spec[1]


COURSE_A = ("quay_stone", "quay_dark")
COURSE_B = ("parapet_stone", "d_talus_sh")


def masonry(b, rings, specs):
    """rings: [(polygon, y)]; specs: course (lit, shade) pair per link; stone faces by direction."""
    for i in range(len(rings) - 1):
        loft(b, rings[i][0], rings[i][1], rings[i + 1][0], rings[i + 1][1], specs[i], fn=msn_sw)


def bridge_pylon(name):
    """L2: a bridge pylon, 22 x 64 x 32 (the shaft) standing on a gorge floor: a stone footing, a battered masonry shaft in courses with
    string courses, a stone bearing seat and a steel crosshead (92 wide) that meets the deck girders at the top. Pivot bottom centre."""
    rng = rng_of(name)
    b = L.new(name)
    ys = [FOUND, 6.0, 18.0, 30.0, 42.0, 54.0]
    hx = [13.5, 11.0, 10.0, 9.2, 8.4, 7.6]
    hz = [18.5, 16.0, 15.2, 14.4, 13.6, 12.8]
    rings = [(rect(0, 0, hx[i], hz[i]), ys[i]) for i in range(len(ys))]
    masonry(b, rings, [COURSE_B, COURSE_A, COURSE_B, COURSE_A, COURSE_B])
    capface(b, rings[-1][0], 54.0, "quay_top")
    for y in (18.0, 30.0, 42.0):  # string courses
        i = ys.index(y)
        box(b, V(0, y, 0), (hx[i] * 2 + 1.4, 0.9, hz[i] * 2 + 1.4), {"side": "quay_top", "top": "quay_top", "bottom": "quay_dark"})
    box(b, V(0, 55.2, 0), (17.0, 1.6, 27.0), {"side": "quay_stone", "top": "quay_top", "bottom": "quay_dark"})  # the bearing seat
    # the steel crosshead under the deck girders (x -17, +17, +-42, bottom at y 63 - 7)
    box(b, V(0, 59.2, 0), (92.0, 4.4, 13.0), {"side": "bridge_steel", "top": "bridge_steel", "bottom": "bridge_steel_dark"})
    for x in (-34.0, -8.0, 8.0, 34.0):
        box(b, V(x, 59.2, 0), (0.9, 4.0, 13.8), {"side": "bridge_steel_dark", "top": "bridge_steel_dark", "skip_bottom": True})
    for x in (-42.0, -17.0, 17.0, 42.0):
        box(b, V(x, 62.2, 0), (3.6, 1.6, 9.0), {"side": "bridge_steel_dark", "top": "bridge_steel", "skip_bottom": True})
    # a ladder-brace of steel on each long face of the shaft (reads as a steel-and-stone stack from the HIGH camera)
    def hz_at(y):
        for i in range(len(ys) - 1):
            if ys[i] <= y <= ys[i + 1]:
                return hz[i] + (hz[i + 1] - hz[i]) * (y - ys[i]) / (ys[i + 1] - ys[i])
        return hz[-1]

    for sz in (-1, 1):
        for xa, xb in ((-6.0, 6.0), (6.0, -6.0)):
            beam(b, V(xa, 22.0, sz * (hz_at(22.0) + 0.45)), V(xb, 50.0, sz * (hz_at(50.0) + 0.45)), 0.7, 0.7, "bridge_steel")
    meta = umeta("LM", "mid", "under the deck, inside the gorge", kind="bridge pylon", width=92.0, depth=37.0, height=63.0, authored=True, deck_clearance=63.0, deck_underside_clearance=65.5,
                 role="pylon: base on the gorge floor; top meets the underside of the deck girders (deck level minus 7); for a floor 70 below the deck place the base at y = -70", placement="gorge")
    return b, meta


def bridge_abutment(name):
    """L2: a stepped-stone abutment for either end of the span, 112 x 34 x 30: three stepped masonry courses, four pilasters and a bearing
    shelf; the stepped face looks toward -Z (the gorge), the back and ends are finished. Pivot bottom centre."""
    b = L.new(name)
    courses = [(FOUND, 11.0, 56.0, -15.0, 15.0, COURSE_A), (11.0, 22.0, 54.0, -9.0, 15.0, COURSE_B), (22.0, 32.0, 52.5, -3.0, 15.0, COURSE_A)]
    for y0, y1, hx, z0, z1, sp in courses:
        r = rect(0, (z0 + z1) / 2, hx, (z1 - z0) / 2)
        loft(b, r, y0, r, y1, sp, fn=msn_sw)
        capface(b, r, y1, "quay_top" if y1 < 32 else "quay_top")
    box(b, V(0, 33.0, 6.0), (103.0, 2.0, 18.0), {"side": "quay_top", "top": "quay_stone", "bottom": "quay_dark"})  # the bearing shelf
    for x in (-41.0, -14.0, 14.0, 41.0):  # pilasters on the lowest course
        box(b, V(x, 6.0, -15.9), (6.0, 12.0, 1.8), {"side": "quay_dark", "top": "quay_top", "skip_bottom": True})
    for x in (-34.0, 0.0, 34.0):  # pilasters on the middle course
        box(b, V(x, 16.5, -9.9), (5.0, 10.0, 1.6), {"side": "quay_dark", "top": "quay_top", "skip_bottom": True})
    meta = umeta("LM", "mid", "under the deck, inside the gorge", kind="bridge abutment", width=112.0, depth=34.0, height=34.0, authored=True, bearing_height=34.0, role="stepped-stone abutment for either end; the stepped face is -Z, the planner yaws it 180 degrees for the far end", placement="gorge")
    return b, meta


def bridge_under(name):
    """L2: the underside of one 192-long deck span as seen from below and from the HIGH camera: cross frames with X bracing every 32
    studs between the four deck girders, lower lateral bracing and two lower chords. Pivot bottom centre; the top (girder underside)
    is at y = 8.5."""
    b = L.new(name)
    Lh = 96.0
    gx = (-42.0, -17.0, 17.0, 42.0)
    top, bot = 8.5, 0.6
    for st in range(-3, 4):
        z = st * 32.0
        beam(b, V(gx[0], bot, z), V(gx[3], bot, z), 1.1, 1.1, "bridge_steel_dark")  # lower chord of the cross frame
        beam(b, V(gx[0], top, z), V(gx[3], top, z), 0.9, 0.9, "bridge_steel")  # the top strut under the deck
        for i in range(3):
            xa, xb = gx[i], gx[i + 1]
            beam(b, V(xa, top, z), V(xb, bot, z), 0.55, 0.55, "bridge_steel")
            beam(b, V(xb, top, z), V(xa, bot, z), 0.55, 0.55, "bridge_steel")
        for x in gx:  # a hanger from each girder
            beam(b, V(x, top, z), V(x, bot, z), 0.7, 0.7, "bridge_steel_dark")
    for x in (-30.0, 30.0):  # two lower chords along the span and a lateral K-bracing between the cross frames
        beam(b, V(x, bot, -Lh), V(x, bot, Lh), 1.3, 1.3, "bridge_steel_dark")
    for st in range(-3, 3):
        z0, z1 = st * 32.0, st * 32.0 + 32.0
        for xa, xb in ((-30.0, 30.0),):
            beam(b, V(xa, bot, z0), V(xb, bot, z1), 0.5, 0.5, "bridge_steel")
            beam(b, V(xb, bot, z0), V(xa, bot, z1), 0.5, 0.5, "bridge_steel")
    meta = umeta("LM", "mid", "under the deck", kind="bridge underside", width=84.0, depth=192.0, height=9.1, authored=True, deck_clearance=8.5, role="cross frames, X bracing and lower chords under one 192 deck; long on Z", placement="deck-under")
    return b, meta


def bridge_truss384(name):
    """L2 (replaces the cliff-bearing Round 2 bridge): the same through-truss over the deck (same ax, 26 clearance, 384 along the route,
    pivot = deck centre at deck level, same sockets), WITHOUT the baked cliffs; each end carries a slim stone-and-steel tower standing on
    the rim (a 9 x 10 footing sunk 1.5 below ground) so the truss reads as supported on the gorge walls."""
    rng = rng_of(name)
    b = L.new(name)
    ax = 50.8 + 1.6
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
    # end towers on the rim
    for s in (-1, 1):
        for sz in (-1, 1):
            cx, cz = s * ax, sz * (Lh + 2.5)
            ys = [FOUND, 2.5, 12.0, 22.0, 29.0]
            hx = [5.0, 4.0, 3.5, 3.1, 2.9]
            hz = [5.4, 4.4, 3.9, 3.5, 3.3]
            ring = [(rect(cx, cz, hx[i], hz[i]), ys[i]) for i in range(len(ys))]
            masonry(b, ring, [("quay_dark", "quay_dark"), COURSE_A, COURSE_B, COURSE_A])
            box(b, V(cx, 29.9, cz), (7.6, 1.2, 8.0), {"side": "bridge_steel_dark", "top": "bridge_steel", "bottom": "bridge_steel_dark"})
            box(b, V(cx, 1.9, cz), (10.0, 0.8, 11.0), {"side": "quay_dark", "top": "quay_top", "skip_bottom": True})  # the footing course, proud of the shaft
            beam(b, V(cx, 29.5, cz - sz * 3.0), V(cx, 26.4, cz - sz * 9.0), 0.8, 0.8, "bridge_steel")  # a strut from the tower head to the top chord
    return b, L.lot_meta(WORLD, "LM", "landmark", 384.0, 0.0, 46.0, "landmark", ["CanyonBridge"], {"start": sock((0, 0, 192)), "end": sock((0, 0, -192))}, False, placement="bridge", pairs_with=["B2_Road_BridgeDeck192_L4W17", "B2_Road_Abutment96_L4W17"], authored=True, role="through-truss over the deck without cliffs; end towers on the rim")


reg("DH_LM_BridgePylon", bridge_pylon)
reg("DH_LM_BridgeAbutment", bridge_abutment)
reg("DH_LM_BridgeUnder", bridge_under)
reg("DH_LM_BridgeTruss384", bridge_truss384)


# ================================================================ landmark: the diner pole sign (L3)
def extrude_zy(b, pts, x0, x1, side, face_lo, face_hi):
    """A polygon in the (z, y) plane extruded along x between x0 (the -X face) and x1 (the +X face)."""
    n = len(pts)
    ar = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sg = 1 if ar > 0 else -1
    b.face([V(x0, y, z) for z, y in pts], face_lo, V(-1, 0, 0))
    b.face([V(x1, y, z) for z, y in pts], face_hi, V(1, 0, 0))
    for i in range(n):
        a, c = pts[i], pts[(i + 1) % n]
        b.face([V(x0, a[1], a[0]), V(x0, c[1], c[0]), V(x1, c[1], c[0]), V(x1, a[1], a[0])], side, V(0, sg * (c[0] - a[0]), -sg * (c[1] - a[1])))


def diner_sign(name):
    """L3: the diner's pole sign, 12 wide x 46 tall: a stout pole, a cream sunburst board (rust lettering area, a turquoise ring, gold rays)
    facing along the road on BOTH sides (it reads as colour and shape at 300 studs). Frontage landmark frame: 12 along the road (x), 16 deep."""
    b = L.new(name)
    W, D = 12.0, 16.0
    zc, yc = 8.0, 36.0
    # the pole and its footing, braces to the board
    cyl(b, V(0, 0.4, zc), 27.0, 0.9, 6, "m_metal", r_top=0.75, top_sw="m_metal_dark")
    box(b, V(0, 0.6, zc), (5.0, 1.2, 5.0), {"side": "m_stone", "top": "gp_pave", "skip_bottom": True})
    for sz in (-1, 1):
        beam(b, V(0, 18.0, zc + sz * 0.8), V(0, 27.5, zc + sz * 4.2), 0.5, 0.5, "m_metal_dark")

    def ell(sx, sy, n=14, off=0.0):
        return [(zc + math.cos(2 * math.pi * k / n + off) * sx, yc + math.sin(2 * math.pi * k / n + off) * sy) for k in range(n)]

    outer = ell(5.9, 8.6, 14, 0.0)
    extrude_zy(b, outer, -0.7, 0.7, "sign_rust", "sign_rust", "sign_rust")
    for sgn in (-1, 1):
        xf = sgn * 0.8
        ring_o, ring_i = ell(5.35, 7.8, 14), ell(4.55, 6.9, 14)
        for k in range(14):
            k2 = (k + 1) % 14
            b.face([V(xf, ring_o[k][1], ring_o[k][0]), V(xf, ring_o[k2][1], ring_o[k2][0]), V(xf, ring_i[k2][1], ring_i[k2][0]), V(xf, ring_i[k][1], ring_i[k][0])], "w_accent_1", V(sgn, 0, 0))
        xi = sgn * 0.86
        face = ell(4.4, 6.75, 14)
        b.face([V(xi, y, z) for z, y in face], "sign_face", V(sgn, 0, 0))
        xr = sgn * 0.92
        for k in range(14):  # gold sunburst rays between the face rim and the lettering area (every other sector)
            if k % 2:
                continue
            k2 = (k + 1) % 14
            a0, a1 = ell(4.4, 6.75, 14)[k], ell(4.4, 6.75, 14)[k2]
            i0, i1 = ell(2.7, 4.2, 14)[k], ell(2.7, 4.2, 14)[k2]
            b.face([V(xr, a0[1], a0[0]), V(xr, a1[1], a1[0]), V(xr, i1[1], i1[0]), V(xr, i0[1], i0[0])], "sign_gold", V(sgn, 0, 0))
        # a rust frame around the blank lettering area
        zl, zr, yl, yh = zc - 2.9, zc + 2.9, yc - 1.7, yc + 1.7
        for (z0, y0, z1, y1) in ((zl, yh - 0.35, zr, yh), (zl, yl, zr, yl + 0.35), (zl, yl, zl + 0.35, yh), (zr - 0.35, yl, zr, yh)):
            b.face([V(sgn * 0.98, y0, z0), V(sgn * 0.98, y0, z1), V(sgn * 0.98, y1, z1), V(sgn * 0.98, y1, z0)], "sign_rust", V(sgn, 0, 0))
        b.face([V(sgn * 0.98, yl + 0.35, zl + 0.35), V(sgn * 0.98, yl + 0.35, zr - 0.35), V(sgn * 0.98, yh - 0.35, zr - 0.35), V(sgn * 0.98, yh - 0.35, zl + 0.35)], "sign_face", V(sgn, 0, 0))
    pyr(b, 0.0, yc + 8.5, zc, 0.9, 1.8, "w_accent_2")
    face = {"centre": [W / 2 - 0.9, yc, zc], "size": [5.2, 3.0], "normal": "-X and +X (both faces)"}
    return lm_finish(b, W, D, 46.0, ["DinerStrip"], placement="frontage", authored=True, sign_face=face, role="strong daytime pole sign, board faces along the road both ways", read="cream sunburst, turquoise ring, rust lettering area")


reg("DH_LM_DinerSign", diner_sign)
# ================================================================ P2: ghost remnants (A4), windmill yard (A5), keeper's yard (A6), hazard readability
import kit_dusty as K1  # noqa: E402  (the Round 2 recipes: mound, haz_meta and the windmill tower)


def lean(b, kx=0.0, kz=0.0):
    """Shear the finished mesh so it leans: x += kx * y, z += kz * y (planar faces stay planar)."""
    for v in b.bm.verts:
        yr = v.co.z
        v.co.x += kx * yr
        v.co.y -= kz * yr


def prop_u(kind, w, h, role, fam="Prop", **kw):
    return umeta(fam, NEAR, "near / mid frontage", kind=kind, width=w, height=h, role=role, district=kw.pop("district", ["MirageDunes"]), **kw)


def sand_bank(b, cx, cz, rx, rz, h, rng):
    K1.mound(b, cx, cz, rx, rz, h, rng, ["gp_clay", "d_gold", "d_gold"], rings=3, segs=10, y0=-0.2)


def ghost_falsefront(name):
    """A4: a false-front remnant, 30 wide x 19 tall: a weathered facade with a chipped stepped top, empty window frames and a door, braced
    from behind, leaning, sand banked on the back."""
    rng = rng_of(name)
    b = L.new(name)
    wall_with_holes_front(b, -15.0, 15.0, 0.0, 13.0, 0.0, [(-12.5, -7.5, 4.8, 10.4), (7.5, 12.5, 4.8, 10.4), (-2.6, 2.6, 0.0, 9.0)], "d_weather_1")
    box(b, V(0, 6.5, 0.45), (30.0, 13.0, 0.9), {"side": "d_weather_2", "top": "d_weather_3", "skip_front": True, "skip_bottom": True})
    for x0, x1 in ((-12.5, -7.5), (7.5, 12.5)):
        window(b, x0, x1, 4.8, 10.4, 0.0, "d_weather_3", rec=0.8, glass="r_shadow")
    b.face([V(-2.6, 0, 0.8), V(2.6, 0, 0.8), V(2.6, 9.0, 0.8), V(-2.6, 9.0, 0.8)], "r_shadow", V(0, 0, -1))
    for x, sg in ((-2.6, 1), (2.6, -1)):
        b.face([V(x, 0, 0), V(x, 9.0, 0), V(x, 9.0, 0.8), V(x, 0, 0.8)], "d_weather_3", V(sg, 0, 0))
    # the chipped, stepped top
    pts = [(-15.0, 13.0), (15.0, 13.0), (15.0, 15.6), (9.0, 15.6), (9.0, 18.4), (3.0, 18.4), (3.0, 16.2), (-1.0, 17.0), (-1.0, 19.0), (-8.0, 19.0), (-8.0, 15.0), (-15.0, 15.0)]
    extrude_xy(b, pts, -0.1, 0.8, "d_weather_2", "d_weather_1", "d_weather_2")
    for x in (-9.0, 0.0, 9.0):  # braces behind
        beam(b, V(x, 0.0, 8.0), V(x, 12.0, 0.9), 0.55, 0.55, "d_weather_2")
    for x in (-14.4, 14.4):
        post(b, x, 1.6, 3.4, 0.6, "d_weather_2", "d_weather_3")
    sand_bank(b, 4.0, 7.0, 13.0, 6.0, 4.6, rng)
    lean(b, 0.025, 0.05)
    return b, prop_u("ghost false front", 30.0, 19.0, "ghost remnant: false front, leaning, empty windows, sand banked at the back", "Prop", kind2="ghost")


def ghost_shed(name):
    """A4: a leaning shed remnant, 14 x 11 x 10: board walls with missing boards, an empty door, a sagging broken roof, sand on the back wall."""
    rng = rng_of(name)
    b = L.new(name)
    wall_with_holes_front(b, -6.0, 6.0, 0.0, 7.4, -3.5, [(-1.4, 1.6, 0.0, 5.6), (3.2, 5.0, 3.4, 6.0)], "d_weather_1")
    box(b, V(0, 3.7, 1.0), (12.0, 7.4, 9.0), {"side": "d_weather_2", "skip_front": True, "skip_bottom": True, "top": "d_weather_3"})
    b.face([V(-1.4, 0, -2.6), V(1.6, 0, -2.6), V(1.6, 5.6, -2.6), V(-1.4, 5.6, -2.6)], "r_shadow", V(0, 0, -1))
    window(b, 3.2, 5.0, 3.4, 6.0, -3.5, "d_weather_3", rec=0.7, glass="r_shadow")
    for x, sg in ((-1.4, 1), (1.6, -1)):
        b.face([V(x, 0, -3.5), V(x, 5.6, -3.5), V(x, 5.6, -2.6), V(x, 0, -2.6)], "d_weather_3", V(sg, 0, 0))
    # board lines on the front wall (vertical boards as thin relief strips) and a broken roof: one plane sags, one is gone
    for k in range(6):
        box(b, V(-5.0 + k * 2.0, 3.7, -3.62), (0.16, 7.4, 0.14), {"side": "d_weather_2", "skip_bottom": True})
    b.face([V(-6.8, 7.4, -4.0), V(0.4, 7.4, -4.0), V(0.4, 6.4, 5.6), V(-6.8, 7.8, 5.6)], "d_weather_2", V(0, 1, 0))
    b.face([V(-6.8, 7.0, -4.0), V(0.4, 6.6, -4.0), V(0.4, 6.0, 5.6), V(-6.8, 7.4, 5.6)], "r_shadow", V(0, -1, 0))
    for x in (2.4, 5.4):  # bare rafters where the roof is gone
        beam(b, V(x, 7.3, -3.8), V(x, 8.3, 5.6), 0.5, 0.5, "d_weather_2")
    sand_bank(b, 0.0, 6.6, 7.0, 4.0, 5.2, rng)
    lean(b, 0.04, 0.03)
    return b, prop_u("ghost shed", 14.0, 10.0, "ghost remnant: leaning shed with a broken roof", "Prop")


def ghost_well(name):
    """A4: a dead well, 7 wide x 9 tall: a stone ring, two leaning posts and a bare crossbeam with a broken windlass, a bucket on the rim."""
    rng = rng_of(name)
    b = L.new(name)
    cyl(b, V(0, -0.3, 0), 2.9, 2.6, 8, "m_stone", r_top=2.5, top_sw="d_weather_2")
    cyl(b, V(0, 2.4, 0), 0.5, 2.7, 8, "d_talus", r_top=2.7, top_sw="d_talus", top=True)
    for sx, k in ((-1, 0.18), (1, -0.1)):
        beam(b, V(sx * 2.4, 2.6, 0.0), V(sx * 2.4 + k * 3.0, 8.4, 0.0), 0.55, 0.55, "d_weather_2")
    beam(b, V(-2.2, 8.2, 0.0), V(2.4, 8.5, 0.0), 0.5, 0.5, "d_weather_1")
    beam(b, V(-0.6, 6.2, 0.4), V(0.9, 8.0, 0.0), 0.3, 0.3, "m_metal_dark")
    cyl(b, V(1.2, 2.9, 1.4), 1.0, 0.55, 6, "m_wood_2", r_top=0.5, top_sw="r_shadow")
    sand_bank(b, 0.0, 1.8, 4.2, 2.2, 1.4, rng)
    return b, prop_u("ghost well", 7.0, 9.0, "ghost remnant: dead well", "Prop")


def ghost_fence(name):
    """A4: a leaning fence run, 30 long: seven weathered posts at different tilts, rails with gaps, sand along the foot."""
    rng = rng_of(name)
    b = L.new(name)
    tilt = [0.0, 0.18, -0.12, 0.3, -0.2, 0.08, 0.25]
    for i, tl in enumerate(tilt):
        x = -15.0 + i * 5.0
        beam(b, V(x, 0.0, 0.0), V(x + tl * 3.4, 3.7 - abs(tl) * 0.8, rng.uniform(-0.2, 0.2)), 0.5, 0.5, "d_weather_2")
    for y, gaps in ((3.0, (2,)), (1.7, (4,))):
        for i in range(6):
            if i in gaps:
                continue
            x0 = -15.0 + i * 5.0
            box(b, V(x0 + 2.5, y + (i % 2) * 0.12, 0.0), (4.7, 0.3, 0.26), {"side": "d_weather_1", "top": "d_weather_3", "skip_bottom": False}, yaw=0.03 * (i - 3))
    for k in range(3):
        K1.mound(b, -10.0 + k * 10.0, 0.3, 4.6, 1.8, 0.9, rng, ["gp_clay", "d_gold", "d_gold"], rings=2, segs=8, y0=-0.2)
    return b, prop_u("ghost fence", 30.0, 4.0, "ghost remnant: leaning fence run", "Prop")


reg("DH_Ghost_FalseFront", ghost_falsefront)
reg("DH_Ghost_Shed", ghost_shed)
reg("DH_Ghost_Well", ghost_well)
reg("DH_Ghost_Fence", ghost_fence)


def yard_tank(name):
    """A5: a round stock tank, 11 wide x 4: a steel wall, a rolled rim, water inside, a small trough beside it."""
    b = L.new(name)
    cyl(b, V(0, 0, 0), 3.4, 5.0, 12, "m_metal", top=False)
    cyl(b, V(0, 3.2, 0), 0.7, 5.3, 12, "m_metal_dark", top=True, top_sw="m_metal_dark")
    # water level and the inside wall
    ring = circle2(0, 0, 4.7, 12)
    for k in range(12):
        a, c = ring[k], ring[(k + 1) % 12]
        b.face([V(a[0], 2.4, a[1]), V(c[0], 2.4, c[1]), V(c[0], 3.9, c[1]), V(a[0], 3.9, a[1])], "m_metal_dark", V(-(a[0] + c[0]), 0, -(a[1] + c[1])))
    b.face([V(x, 2.4, z) for x, z in ring], "g_water", V(0, 1, 0))
    box(b, V(7.6, 0.9, 0.0), (5.0, 1.8, 2.0), {"side": "m_wood_2", "top": "g_water", "skip_bottom": True})
    beam(b, V(5.0, 2.6, 0.0), V(3.0, 3.8, 0.0), 0.5, 0.5, "m_metal_dark")
    return b, prop_u("yard tank", 14.0, 4.1, "windmill yard: stock tank", "Prop", district=["CactusFlats"])


def yard_pumphouse(name):
    """A5: a pump house, 9 x 8 x 8: a small metal-clad shed with a pitched roof, a door and a vent, adobe plinth."""
    b = L.new(name)
    box(b, V(0, 0.5, 0.0), (9.6, 1.0, 8.6), {"side": "w_wall_1", "top": "w_wall_1", "skip_bottom": True})
    box(b, V(0, 3.8, 0.0), (8.6, 5.6, 7.6), {"side": "w_wall_4", "top": "w_wall_4", "skip_bottom": True})
    hw = 4.8
    for s in (-1, 1):
        b.face([V(-hw, 6.6, s * 4.4), V(hw, 6.6, s * 4.4), V(hw, 8.4, 0.0), V(-hw, 8.4, 0.0)], "w_roof_2", V(0, 1, s))
    for sx in (-1, 1):
        b.face([V(sx * hw, 6.6, -4.4), V(sx * hw, 6.6, 4.4), V(sx * hw, 8.4, 0.0)], "w_wall_4", V(sx, 0, 0))
    window_front = V(0, 0, -1)
    b.face([V(-1.3, 1.0, -3.85), V(1.3, 1.0, -3.85), V(1.3, 5.2, -3.85), V(-1.3, 5.2, -3.85)], "m_wood_2", window_front)
    b.face([V(2.2, 3.2, -3.85), V(3.4, 3.2, -3.85), V(3.4, 4.4, -3.85), V(2.2, 4.4, -3.85)], "w_glass", window_front)
    box(b, V(-2.6, 6.9, 0.0), (1.2, 1.4, 1.2), {"side": "m_metal", "top": "m_metal_dark", "skip_bottom": True})
    for sx in (-1, 1):
        b.face([V(sx * 4.32, 2.4, -1.0), V(sx * 4.32, 2.4, 1.0), V(sx * 4.32, 4.4, 1.0), V(sx * 4.32, 4.4, -1.0)], "w_glass", V(sx, 0, 0))
    return b, prop_u("yard pump house", 10.0, 8.4, "windmill yard: pump house", "Prop", district=["CactusFlats"])


def yard_piperun(name):
    """A5: a pipe run on posts, 96 long: a 6-sided pipe pointing at the horizon, couplings every 12 studs and T-head posts."""
    b = L.new(name)
    tube(b, [V(-48.0, 3.4, 0.0), V(48.0, 3.4, 0.0)], [0.75, 0.75], 6, "m_metal", cap=True)
    for i in range(9):
        x = -48.0 + i * 12.0
        box(b, V(x, 1.6, 0.0), (0.6, 3.2, 0.6), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
        box(b, V(x, 2.5, 0.0), (0.7, 0.35, 1.6), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
        if i < 8:
            tube(b, [V(x + 5.7, 3.4, 0.0), V(x + 6.3, 3.4, 0.0)], [1.0, 1.0], 4, "m_metal_dark", cap=False)
    return b, prop_u("pipe run", 96.0, 4.0, "windmill yard: a pipe on posts pointing at the horizon; long on X", "Prop", district=["CactusFlats"], long_axis="x")


reg("DH_Yard_Tank", yard_tank)
reg("DH_Yard_PumpHouse", yard_pumphouse)
reg("DH_Yard_PipeRun", yard_piperun)


def keeper_worksite(name):
    """A6: the bridge-keeper's worksite, 24 x 14 x 9, neutral browns only (no orange, white stripes or cones): a timber stack, a trestle
    shelter on four posts and two sawhorses."""
    b = L.new(name)
    for x in (-4.0, 4.0):
        for z in (-2.5, 2.5):
            post(b, x + 8.0, z, 7.0, 0.7)
    b.face([V(2.6, 7.0, -3.3), V(13.4, 7.0, -3.3), V(13.4, 8.6, 0.0), V(2.6, 8.6, 0.0)], "w_roof_2", V(0, 1, -1))
    b.face([V(2.6, 8.6, 0.0), V(13.4, 8.6, 0.0), V(13.4, 7.0, 3.3), V(2.6, 7.0, 3.3)], "w_roof_2", V(0, 1, 1))
    b.face([V(2.6, 6.8, -3.3), V(13.4, 6.8, -3.3), V(13.4, 8.4, 0.0), V(2.6, 8.4, 0.0)], "r_shadow", V(0, -1, -0.4))
    for sx in (2.6, 13.4):
        b.face([V(sx, 7.0, -3.3), V(sx, 7.0, 3.3), V(sx, 8.6, 0.0)], "w_roof_2", V(1 if sx > 8 else -1, 0, 0))
    box(b, V(8.0, 3.2, 0.0), (7.0, 0.5, 3.0), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": False})  # a work table under the shelter
    # the timber stack: four layers of planks laid across
    for k in range(4):
        box(b, V(-8.0, 0.55 + k * 1.1, 0.0), (9.0 - (k % 2) * 0.8, 1.0, 3.6 - (k % 2) * 0.4), {"side": "m_wood_1" if k % 2 == 0 else "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    for x in (-9.5, -6.5):
        box(b, V(x, 5.0, 0.0), (0.4, 0.5, 3.0), {"side": "m_wood_2", "top": "m_wood_2", "skip_bottom": True})
    for x in (-1.0, 3.5):  # sawhorses
        box(b, V(x, 1.8, 5.2), (3.0, 0.4, 0.5), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
        for dx in (-1.1, 1.1):
            beam(b, V(x + dx, 0.0, 5.0), V(x + dx * 0.6, 1.7, 5.2), 0.4, 0.4, "m_wood_2")
    return b, prop_u("keeper worksite", 24.0, 9.0, "bridge-keeper's worksite: timber stack, trestle shelter, neutral browns, no hazard language", "Prop", district=["CanyonBridge"])


def keeper_hut(name):
    """A6: the keeper's hut, 13 x 11 x 9: a small plank hut with a gabled roof, a door, a window, a chimney."""
    b = L.new(name)
    box(b, V(0, 3.5, 0.0), (11.0, 7.0, 9.0), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    hw = 6.2
    for s in (-1, 1):
        b.face([V(-hw, 6.8, s * 5.2), V(hw, 6.8, s * 5.2), V(hw, 9.0, 0.0), V(-hw, 9.0, 0.0)], "w_roof_2", V(0, 1, s))
        b.face([V(-hw, 6.5, s * 5.2), V(hw, 6.5, s * 5.2), V(hw, 8.7, 0.0), V(-hw, 8.7, 0.0)], "r_shadow", V(0, -1, -s))
    for sx in (-1, 1):
        b.face([V(sx * 5.5, 7.0, -4.5), V(sx * 5.5, 7.0, 4.5), V(sx * 5.5, 8.7, 0.0)], "m_wood_2", V(sx, 0, 0))
    b.face([V(-1.4, 0.0, -4.55), V(1.4, 0.0, -4.55), V(1.4, 5.2, -4.55), V(-1.4, 5.2, -4.55)], "m_wood_2", V(0, 0, -1))
    window(b, 2.4, 4.4, 3.0, 5.2, -4.5, "m_wood_2", rec=0.4)
    box(b, V(-3.0, 9.0, 1.6), (1.6, 3.2, 1.6), {"side": "m_stone", "top": "m_metal_dark", "skip_bottom": True})
    for sx in (-1, 1):
        b.face([V(sx * 5.55, 2.8, -1.2), V(sx * 5.55, 2.8, 1.2), V(sx * 5.55, 5.0, 1.2), V(sx * 5.55, 5.0, -1.2)], "w_glass", V(sx, 0, 0))
    return b, prop_u("keeper hut", 13.0, 12.0, "bridge-keeper's hut, neutral browns", "Prop", district=["CanyonBridge"])


reg("DH_Keeper_Worksite", keeper_worksite)
reg("DH_Keeper_Hut", keeper_hut)


def haz_sanddrift(name):
    """P2 hazard readability, a REPLACE of the Round 2 sand drift with the same footprint (about 22 x 10.4): the lowest ring of the pale
    mound is now a dark windward rim (hz_dark), a darker crust crescent runs along the -Z (windward) side and dark wind-scour streaks cross
    the lee, so the drift separates from the cream road."""
    rng = rng_of(name)
    b = L.new(name)
    K1.mound(b, 0, 0, 11.0, 5.2, 1.6, rng, ["hz_dark", "hz_light", "hz_light"], rings=3, segs=14, y0=0.0)
    K1.mound(b, 4.0, 1.4, 6.0, 3.0, 1.0, rng, ["hz_dark", "hz_light"], rings=2, segs=10, y0=0.0)
    # the windward crust: a crescent of dark sand hugging the -Z edge of the mound
    outer = [(math.cos(a) * 11.2, math.sin(a) * 5.4) for a in [math.pi + 0.25 + k * (math.pi - 0.5) / 8 for k in range(9)]]
    inner = [(math.cos(a) * 9.9, math.sin(a) * 4.6) for a in [math.pi + 0.25 + k * (math.pi - 0.5) / 8 for k in range(9)]]
    for k in range(8):
        b.face([V(outer[k][0], 0.06, outer[k][1]), V(outer[k + 1][0], 0.06, outer[k + 1][1]), V(inner[k + 1][0], 0.2, inner[k + 1][1]), V(inner[k][0], 0.2, inner[k][1])], "hz_dark", V(0, 1, -1))
    for sx, sz in ((-5.0, 1.2), (1.0, 2.4), (6.5, 0.8)):  # wind-scour streaks across the lee
        b.face([V(sx - 2.4, 1.2, sz - 0.25), V(sx + 2.4, 1.1, sz - 0.25), V(sx + 2.4, 1.1, sz + 0.25), V(sx - 2.4, 1.2, sz + 0.25)], "hz_rim", V(0, 1, 0))
    return b, K1.haz_meta("oil", "sand drift with a dark windward rim band (hazard readability, scenery preview only)")


def haz_windsock(name):
    """P2 hazard readability: a wind-sock marker on a pole, 12 tall, orange and white bands (hazard-only language)."""
    b = L.new(name)
    box(b, V(0, 0.3, 0.0), (2.4, 0.6, 2.4), {"side": "m_stone", "top": "gp_pave", "skip_bottom": True})
    cyl(b, V(0, 0.4, 0.0), 11.4, 0.4, 6, "m_metal", r_top=0.32, top_sw="m_metal_dark")
    beam(b, V(0, 11.6, 0.0), V(1.6, 11.6, 0.0), 0.35, 0.35, "m_metal_dark")
    tube(b, [V(1.8, 11.6, 0.0), V(3.6, 11.55, 0.0), V(5.4, 11.4, 0.0), V(7.2, 11.2, 0.0), V(9.0, 10.9, 0.0)], [1.45, 1.25, 1.0, 0.8, 0.6], 6, ["haz_orange", "haz_white", "haz_orange", "haz_white"], cap=False)
    b.face([V(1.8 + 0.0, 11.6 + math.cos(a) * 1.5, math.sin(a) * 1.5) for a in [k * math.pi / 3 for k in range(6)]], "m_metal_dark", V(-1, 0, 0))
    meta = L.unit_meta(WORLD, "Haz", NEAR, "roadside, beside a hazard", kind="windsock", height=12.4, pivot="bottom centre", role="hazard wind-sock marker (orange and white, hazard-only)", hazard=True)
    return b, meta


reg("DH_Haz_SandDrift", haz_sanddrift)
REPLACES.append("DH_Haz_SandDrift")  # the Round 2 sand drift is a pale mound that merges with the cream road
reg("DH_Haz_WindSock", haz_windsock)


# ================================================================ P3: sand fringe (E4), windmill wheel (M1), pennants (M2), shimmer (M3), windmill tower without the wheel
def fringe(name, length, width, H):
    rng = rng_of(name)
    b = L.new(name)
    nx, rows = 9, [0.0, 0.3, 0.62, 0.82, 1.0]
    for i in range(nx - 1):
        for j in range(len(rows) - 1):
            def P(ii, jj):
                s = ii / (nx - 1)
                env = math.sin(math.pi * s) ** 0.7
                h = H * env * (0.6 + 0.4 * math.sin(3.1 * math.pi * s + length)) * (rows[jj] / 0.62 if rows[jj] <= 0.62 else (1 - rows[jj]) / 0.38) ** 1.2
                return V((s - 0.5) * length, -0.2 + h, -width / 2 + rows[jj] * width + 0.5 * math.sin(2 * math.pi * s * 1.4) * (1 if 0 < jj < 4 else 0))

            q = [P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)]
            ys = [p.y for p in q]
            if max(ys) < -0.1:
                continue
            avg = sum(ys) / 4 + 0.2
            sw = "gp_clay" if avg < 0.35 else ("d_gold" if rows[j] < 0.62 else "gp_dark")
            b.face(q, sw, V(0, 1, 0.5 if rows[j] > 0.62 else -0.5))
    return b, umeta("Edge", NEAR, "verge fringe, outside the shoulder", kind="sand fringe", width=length, depth=width, height=H, long_axis="x", role="verge-softening sand fringe with a clay-sand skirt (never pale at the foot)", district=["MirageDunes", "CactusFlats"], authored=True)


reg("DH_Fringe_Sand_A", fringe, 24.0, 10.0, 1.5)
reg("DH_Fringe_Sand_B", fringe, 36.0, 12.0, 1.9)
reg("DH_Fringe_Sand_C", fringe, 48.0, 14.0, 2.3)


def anim_wheel(name):
    """M1: a windmill wheel, 24 wide, to be spun about its axle: the pivot is the hub; the disc is in the plane x = 0 (normal along X, the
    road, as in Round 2): a metal rim, twelve sail blades, a hub. Symmetric about the axle."""
    b = L.new(name)
    R0, R1, n = 11.9, 11.1, 10
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        for x, sg in ((0.35, 1), (-0.35, -1)):
            b.face([V(x, math.sin(a0) * R1, math.cos(a0) * R1), V(x, math.sin(a1) * R1, math.cos(a1) * R1), V(x, math.sin(a1) * R0, math.cos(a1) * R0), V(x, math.sin(a0) * R0, math.cos(a0) * R0)], "m_metal", V(sg, 0, 0))
        am = (a0 + a1) / 2
        b.face([V(-0.35, math.sin(a0) * R0, math.cos(a0) * R0), V(0.35, math.sin(a0) * R0, math.cos(a0) * R0), V(0.35, math.sin(a1) * R0, math.cos(a1) * R0), V(-0.35, math.sin(a1) * R0, math.cos(a1) * R0)], "m_metal_dark", V(0, math.sin(am), math.cos(am)))
        b.face([V(-0.35, math.sin(a0) * R1, math.cos(a0) * R1), V(-0.35, math.sin(a1) * R1, math.cos(a1) * R1), V(0.35, math.sin(a1) * R1, math.cos(a1) * R1), V(0.35, math.sin(a0) * R1, math.cos(a0) * R1)], "m_metal_dark", V(0, -math.sin(am), -math.cos(am)))
    for k in range(10):  # the sail blades: flat paddles between the hub and the rim, two-sided
        a = 2 * math.pi * k / 10
        c, s = math.cos(a), math.sin(a)
        r0, r1 = 1.8, 11.1
        w0, w1 = 0.5, 1.5
        pts = [V(0.0, s * r0 - c * w0, c * r0 + s * w0), V(0.0, s * r1 - c * w1, c * r1 + s * w1), V(0.0, s * r1 + c * w1, c * r1 - s * w1), V(0.0, s * r0 + c * w0, c * r0 - s * w0)]
        b.face2(pts, "w_wall_2" if k % 2 == 0 else "m_metal")
    # the hub: a short octagonal drum along the X axle (kitlib cyl is vertical, so it is laid out by hand)
    hr = [(math.sin(2 * math.pi * k / 8) * 1.5, math.cos(2 * math.pi * k / 8) * 1.5) for k in range(8)]
    for k in range(8):
        y0, z0 = hr[k]
        y1, z1 = hr[(k + 1) % 8]
        b.face([V(-0.9, y0, z0), V(0.9, y0, z0), V(0.9, y1, z1), V(-0.9, y1, z1)], "w_accent_2", V(0, y0 + y1, z0 + z1))
    b.face([V(0.9, y, z) for y, z in hr], "m_metal_dark", V(1, 0, 0))
    b.face([V(-0.9, y, z) for y, z in hr], "m_metal_dark", V(-1, 0, 0))
    return b, umeta("Anim", NEAR, "windmill head", kind="windmill wheel", width=24.0, height=24.0, depth=1.0, hub=[0.0, 0.0, 0.0], axle="X", rotate="about the X axis through the pivot (the hub)", role="windmill wheel that turns at 0.1 turns per second (plan M1)", district=["CactusFlats"], pivot="hub (the axle centre)")


def windmill_tower(name):
    """M1 (replaces Round 2's DH_LM_WindmillTower): the same lattice tower, gear housing and tail vane at the same size and pivot, with the
    wheel removed so DH_Anim_WindmillWheel can spin about the hub. meta.hub is the hub in the lot frame."""
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
    box(b, V(0, 55.0, 17.0), (0.4, 4.0, 8.0), {"side": "w_accent_1", "skip_bottom": True})  # tail vane
    beam(b, V(0, 54.0, 12.0), V(0, 55.0, 17.0), 0.5, 0.5, "m_wood_2")
    box(b, V(2.3, 54.0, 10.0), (1.4, 1.6, 1.6), {"side": "m_metal_dark", "top": "m_metal_dark", "skip_bottom": True})  # the axle stub the wheel mounts on
    return lm_finish(b, w, d, h, ["CactusFlats"], read="windmill tower; the wheel is DH_Anim_WindmillWheel at meta.hub", hub=[3.2 + w / 2, 54.0, 10.0], authored=False)


reg("DH_Anim_WindmillWheel", anim_wheel)
reg("DH_LM_WindmillTower", windmill_tower)
REPLACES.append("DH_LM_WindmillTower")  # the wheel is its own mesh now


def anim_pennants(name):
    """M2: one string of eight pennants, 30 long, hung between two 10-tall poles parallel to the road (the x axis): coral and turquoise."""
    b = L.new(name)
    for x in (-15.0, 15.0):
        cyl(b, V(x, 0, 0), 10.0, 0.35, 5, "m_wood_2", r_top=0.28, top_sw="m_wood_1")
    pts = [V(-15.0, 9.6, 0.0), V(-5.0, 9.0, 0.0), V(5.0, 9.0, 0.0), V(15.0, 9.6, 0.0)]
    tube(b, pts, [0.12] * 4, 4, "m_wood_1", cap=False)
    for i in range(8):
        x = -12.0 + i * 3.4
        sag = 9.6 - 0.6 * (1 - (x / 15.0) ** 2)  # the string sags toward the middle
        b.face2([V(x - 1.0, sag, 0.0), V(x + 1.0, sag, 0.0), V(x, sag - 3.0, 0.0)], "w_accent_2" if i % 2 == 0 else "w_accent_1")
    return b, umeta("Anim", NEAR, "forecourt", kind="pennant string", width=30.0, height=10.0, long_axis="x", role="one string of eight pennants between two poles, parallel to the road (plan M2)", district=["DinerStrip"])


def anim_shimmer(name):
    """M3: one flat far-ground strip, 200 x 40 (long on X), a pale blue-sand gradient in eight bands across the depth."""
    b = L.new(name)
    sw = ["gp_pale", "gp_haze_1", "gp_haze_1", "gp_haze_2", "gp_haze_2", "gp_haze_3", "gp_haze_3", "gp_haze_4"]
    for k in range(8):
        z0, z1 = -20.0 + k * 5.0, -20.0 + (k + 1) * 5.0
        b.face([V(-100.0, 0.1, z0), V(100.0, 0.1, z0), V(100.0, 0.1, z1), V(-100.0, 0.1, z1)], sw[k], V(0, 1, 0))
    return b, umeta("Anim", "far", "far ground, 250+ from the road", kind="shimmer strip", width=200.0, depth=40.0, height=0.1, flat=True, long_axis="x", authored=True, role="mirage shimmer strip, a pale blue-sand gradient (plan M3)", district=["MirageDunes"])


reg("DH_Anim_PennantString", anim_pennants)
reg("DH_Anim_Shimmer", anim_shimmer)
# <<<MORE>>>


def build_all(emit):
    for name, fn, args, kw in _RECIPES:
        b, meta = fn(name, *args, **kw)
        emit(b, meta)
    for nm, m in MEASURE.items():
        print(f"  MEASURE {nm}: {m}")
