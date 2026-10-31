# Summit Pass kit V2 (Lane 3, Kit V2, 2026-10-28, worker S): the backdrop-first redesign of plan world-plan-summit-pass.md.
# Authored mountain masses (far massifs, the summit horn, ridge curtains, spurs, terrace, knoll, treeline bands, piste glades,
# the glacier snout), road-edge pieces, chalet forms, lodge pieces, the opaque glacier gallery, the lake kit, landmarks, foliage,
# hazards, signs, props. Colour comes only from swatch names (kit_world_palette + kit_world_palette_su2). Everything is original.
#
# Terrain-like masses are built from ridge definitions: a crest polyline per ridge with a two-slope flank (steep upper face, gentler
# lower flank), the height at a point is the highest ridge tent there, a constrained Delaunay triangulation (crest lines are
# constraints) makes the facets, and every face is coloured by what it is: snow only within 35 degrees of horizontal (and in
# couloirs), forest on the low gentle skirts, rock otherwise, with lit/half/shade/deep planes and horizontal strata bands.

import math
import random

from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

import bmesh

import kit_world_lib as L
import kit_world_palette_su2 as P
from kit_b2lib import sock
from kitlib import V, beam, box, circle2, clip_poly, cyl, sphere, tube

WORLD = "SU"
ALL = ["PineVillage", "SkiLiftRidge", "FrozenLake", "GlacierTunnel", "SummitLodge"]
RECIPES = []  # (callable producing (builder, meta)) in build order
# Round 2 meshes this kit supersedes and no longer needs (the lead prunes them from the final kit)
DROP_OLD = [
    "SP_Sky_Ridge_1",  # two-to-four-tier stacked frusta: replaced by the SP_BG_Ridge_A..F curtains
    "SP_Sky_Ridge_2",  # same
]
# Round 2 names redrawn here under the SAME name (the Round 2 recipe is skipped in a V2 build)
REPLACES = [
    "SP_Haz_FrostCrack",  # footprint kept (14 x 10); pale oval with dark cracks, dark rim
    "SP_Haz_IcePatch",  # footprint kept (16 x 11); crisp dark rim, pale body at least 15 value points lighter than asphalt
    "SP_Haz_Snowbank",  # footprint kept; blue-grey base, plow stakes the only orange in Summit Pass
    "SP_LM_BellTower",  # becomes the 64-high clock tower on a fenced green (the Round 2 52-high tower had no clock face)
    "SP_LM_ChaletCluster",  # becomes Terrace Chalets: four different chalets climbing a bank (Round 2 was one flat row)
    "SP_LM_FrozenLake",  # becomes a rim-and-hut shore set with a pier (Round 2 was a 68 x 30 oval nobody could read)
    "SP_LM_SummitLodge",  # becomes the central great hall, 54 high with a glazed gable (Round 2 was a long chalet)
    "SP_LM_Observatory",  # redrawn on a 14-stud coursed stone plinth (Round 2 stood on the ground)
    "SP_LM_WarmingHut",  # redrawn: log walls, a mono-pitch roof, chimney, bench (Round 2 was a flat gable box)
    "SP_LM_FestivalStage",  # redrawn as the small 24 x 14 terrace stage Adam promoted (Round 2 was a 60-wide tier B stage)
]
LIGHT = Vector((-0.38, 0.80, 0.46)).normalized()  # direction toward the sun used to bake lit/half/shade planes (matches the review sun)


def rng_of(name):
    return random.Random(sum(map(ord, name)) * 31 + len(name))


def mirror_x(b):
    """Flip a finished builder in x (an authored left/right variant: never a negative scale)."""
    for v in b.bm.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(b.bm, faces=list(b.bm.faces))


def recipe(fn):
    RECIPES.append(fn)
    return fn


def finish(b, w, d, h, cls, districts, shop=False, family="Lot", module="scenery", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, family, module, w, d, h, cls, districts, sockets, shop, **kw)


def lm_finish(b, w, d, h, districts, placement="frontage", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, "LM", "landmark", w, d, h, "landmark", districts, sockets, False, placement=placement, **kw)


def unit(b, family, lod, band, **kw):
    """unit_meta plus the layout facts the planner reads: the long axis of the mesh (x or z) and the road-facing side (-Z)."""
    xs = [v.co.x for v in b.bm.verts]
    zs = [v.co.y for v in b.bm.verts]  # Blender y is Roblox -z
    kw.setdefault("long_axis", "x" if (max(xs) - min(xs)) >= (max(zs) - min(zs)) else "z")
    kw.setdefault("front", "-Z: the side that faces the road")
    return b, L.unit_meta(WORLD, family, lod, band, **kw)


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def lerp(a, b, t):
    return a + (b - a) * t


def sm(t):
    t = clamp(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ================================================================ terrain: ridges, triangulation, colour
class Noise:
    """Deterministic smooth noise in [-1, 1] from a few sine products (scale = the feature size in studs)."""

    def __init__(self, rng, scale):
        self.t = [(1.0 / (scale * rng.uniform(0.35, 0.7)) * (1 + k), 1.0 / (scale * rng.uniform(0.35, 0.7)) * (1 + k * 0.7), rng.uniform(0, 6.28), rng.uniform(0, 6.28), 1.0 / (1 + k)) for k in range(3)]
        self.n = sum(a for *_, a in self.t)

    def __call__(self, x, z):
        return sum(a * math.sin(fx * x + px) * math.sin(fz * z + pz) for fx, fz, px, pz, a in self.t) / self.n


def seg_dist(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    l2 = dx * dx + dz * dz
    t = 0.0 if l2 == 0 else clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0.0, 1.0)
    return math.hypot(px - (ax + dx * t), pz - (az + dz * t)), t


def ridge(pts, s1=1.0, s2=0.45, d1=55.0, sides=(1.0, 1.0)):
    """A crest polyline [(x, z, height), ...]; the flank falls at slope s1 up to d1 studs from the crest, then at s2. sides = slope
    multipliers for the two flanks: (cross < 0, cross > 0), where cross = (crest direction) x (point - crest point) in the x, z plane
    (for a crest running along +x, the first is the -z side, the road side)."""
    return {"pts": pts, "s1": s1, "s2": s2, "d1": d1, "sides": sides}


def plateau(cx, cz, hx, hz, h, s1=0.6, s2=0.6, d1=10.0):
    """A flat top (a rectangle at height h) with a flank on every side; its corners are crest nodes."""
    pts = [(cx - hx, cz - hz, h), (cx + hx, cz - hz, h), (cx + hx, cz + hz, h), (cx - hx, cz + hz, h), (cx - hx, cz - hz, h)]
    r = ridge(pts, s1, s2, d1)
    r["rect"] = (cx, cz, hx, hz, h)
    return r


def crest_height(ridges, x, z):
    best = -1e9
    for r in ridges:
        if "rect" in r:
            cx, cz, hx, hz, h = r["rect"]
            d = math.hypot(max(abs(x - cx) - hx, 0.0), max(abs(z - cz) - hz, 0.0))
            v = h - r["s1"] * min(d, r["d1"]) - r["s2"] * max(0.0, d - r["d1"])
            best = max(best, v)
            continue
        p = r["pts"]
        kn, kp = r["sides"]
        for i in range(len(p) - 1):
            a, c = p[i], p[i + 1]
            d, t = seg_dist(x, z, a[0], a[1], c[0], c[1])
            k = kn if (c[0] - a[0]) * (z - a[1]) - (c[1] - a[1]) * (x - a[0]) < 0 else kp
            v = a[2] + (c[2] - a[2]) * t - k * (r["s1"] * min(d, r["d1"]) + r["s2"] * max(0.0, d - r["d1"]))
            if v > best:
                best = v
    return best


def mirrored(ridges, couloirs=None):
    out = []
    for r in ridges:
        m = dict(r)
        m["sides"] = (r["sides"][1], r["sides"][0])
        m["pts"] = [(-x, z, h) for x, z, h in r["pts"]]
        if "rect" in r:
            cx, cz, hx, hz, h = r["rect"]
            m["rect"] = (-cx, cz, hx, hz, h)
        out.append(m)
    return out


BASE_Y = -1.0


def terrain(ridges, W, D, spacing, rng, H, p=3.0, taper=0.3, noise_amp=0.045, noise_scale=None, couloirs=(), couloir_depth=0.0, jit=0.3, keep_sq=0.6, node_step=1.5, flank=(0.0, 0.55)):
    """Triangles [(Vector, Vector, Vector)] in Roblox axes over a footprint W x D (centred) plus the height function."""
    nz = Noise(rng, noise_scale or max(W, D) * 0.25)
    hw, hd = W / 2, D / 2

    def hfun(x, z):
        v = crest_height(ridges, x, z)
        e = (abs(x) / hw) ** p + (abs(z) / hd) ** p
        t = 1.0 if e < 1 - taper else max(0.0, (1 - e) / taper)
        v *= sm(t) ** 0.8
        v += noise_amp * H * nz(x, z) * clamp(v / H, 0.0, 1.0)
        for (ax, az, bx, bz, wd) in couloirs:
            d, _ = seg_dist(x, z, ax, az, bx, bz)
            if d < wd:
                v -= couloir_depth * H * sm(1 - d / wd) * clamp(v / (0.4 * H), 0.0, 1.0)
        return v

    pts, hz, idx = [], [], {}
    edge_set = set()

    def add(x, z, h=None):
        k = (round(x, 2), round(z, 2))
        if k in idx:
            j = idx[k]
            if h is not None and hz[j] is None:
                hz[j] = h
            return j
        idx[k] = len(pts)
        pts.append(Vector((x, z)))
        hz.append(h)
        return idx[k]

    crest_segs = []
    flank_nodes = []
    for r in ridges:
        pp = r["pts"]
        prev = add(pp[0][0], pp[0][1], pp[0][2])
        for i in range(1, len(pp)):
            c, a = pp[i - 1], pp[i]
            ln = math.hypot(a[0] - c[0], a[1] - c[1])
            if ln < 1e-6:
                continue
            n = max(1, int(ln / (spacing * node_step) + 0.5))
            crest_segs.append((c, a))
            dv = ((a[0] - c[0]) / ln, (a[1] - c[1]) / ln)
            if i == 1:
                flank_nodes.append((r, pp[0], dv))
            for k in range(1, n + 1):
                t = k / n
                q = (lerp(c[0], a[0], t), lerp(c[1], a[1], t), lerp(c[2], a[2], t))
                j = add(q[0], q[1], q[2])
                if j != prev:
                    edge_set.add((min(prev, j), max(prev, j)))
                prev = j
                flank_nodes.append((r, q, dv))
    for (r, q, dv) in flank_nodes:
        d1 = r["d1"]
        for sg in (-1, 1):
            k = r["sides"][0] if sg < 0 else r["sides"][1]
            d1k = d1
            d0 = d1k + max(0.0, q[2] - k * r["s1"] * d1k) / max(k * r["s2"], 0.05)
            for dist in (d1k, d1k + (d0 - d1k) * flank[1]):
                if dist < spacing * 0.6:
                    continue
                x, z = q[0] - sg * dv[1] * dist, q[1] + sg * dv[0] * dist
                if abs(x) <= hw and abs(z) <= hd:
                    add(x, z)
    for (ax, az, bx, bz, wd) in couloirs:  # couloir lines get vertices so the gully can dent the terrain
        n = max(2, int(math.hypot(bx - ax, bz - az) / spacing))
        for k in range(n + 1):
            add(lerp(ax, bx, k / n), lerp(az, bz, k / n))
    # jittered grid fill, kept clear of the crest lines
    nx, nzc = int(W / spacing) + 1, int(D / spacing) + 1
    for i in range(nx):
        for j in range(nzc):
            x = -hw + (i + 0.5 + rng.uniform(-jit, jit)) * W / nx
            z = -hd + (j + 0.5 + rng.uniform(-jit, jit)) * D / nzc
            if any(seg_dist(x, z, c[0], c[1], a[0], a[1])[0] < spacing * keep_sq for c, a in crest_segs):
                continue
            if any((q.x - x) ** 2 + (q.y - z) ** 2 < (spacing * 0.5) ** 2 for q in pts):
                continue
            add(x, z)
    res = delaunay_2d_cdt(pts, sorted(edge_set), [], 0, 1e-4)
    vs, faces, orig = res[0], res[2], res[3]
    ys = []
    for i, v in enumerate(vs):
        o = orig[i]
        h = hz[o[0]] if o and hz[o[0]] is not None else hfun(v.x, v.y)
        ys.append(h if h > 0.35 else BASE_Y)
    tris = []
    for f in faces:
        q = [Vector((vs[k].x, ys[k], vs[k].y)) for k in f]
        if max(v.y for v in q) <= BASE_Y + 0.05:
            continue
        tris.append(tuple(q))
    return tris, hfun


# ---- colour: snow, forest, rock by slope, height and facing
STYLE_FAR = {"rock": ("rk_farthest", "rk_far_lit", "rk_far", "rk_far_shade", "rk_far_deep"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_far", "pn_far", "pn_mid", "pn_mid"), "snow_line": 0.34, "forest_line": 0.10, "forest_slope": 62.0, "bands": 6}
STYLE_HORN = {"rock": ("rk_far_lit", "rk_far", "rk_far_shade", "rk_far_deep", "rk_far_deep"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_far", "pn_far", "pn_mid", "pn_mid"), "snow_line": 0.3, "forest_line": 0.07, "forest_slope": 62.0, "bands": 6}
STYLE_MID = {"rock": ("rk_mid_lit", "rk_mid", "r_2", "r_1", "r_shadow"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_mid", "pn_mid", "pn_deep", "pn_deep"), "snow_line": 0.12, "forest_line": 0.0, "bands": 5}
STYLE_FOOT = {"rock": ("rk_mid_lit", "rk_mid", "r_2", "r_1", "r_shadow"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_mid", "pn_mid", "pn_deep", "pn_deep"), "snow_line": 0.5, "forest_line": 0.5, "forest_slope": 40.0, "bands": 5}
STYLE_ICE = {"rock": ("ice_lit", "ice_pale", "ice_deep", "ice_shade", "ice_shade"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("ice_pale", "ice_pale", "ice_deep", "ice_deep"), "snow_line": 0.12, "forest_line": 0.0, "bands": 6}
STYLE_NEAR = {"rock": ("rk_near_lit", "rk_near", "rk_near_shade", "rk_dark", "rk_dark"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_mid", "pn_mid", "pn_deep", "pn_deep"), "snow_line": 0.1, "forest_line": 0.0, "bands": 5}
STYLE_GLACIER = {"rock": ("rk_near_lit", "rk_near", "rk_near_shade", "rk_dark", "rk_dark"), "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_mid", "pn_mid", "pn_deep", "pn_deep"), "snow_line": 0.5, "forest_line": 0.0, "bands": 5}


def tri_swatch(q, st, H, couloirs=(), snow_slope=35.0, forest_slope=42.0, y_off=0.0):
    n = (q[1] - q[0]).cross(q[2] - q[0])
    if n.length < 1e-9:
        return None
    n = n.normalized()
    if n.y < 0:
        n = -n
    slope = math.degrees(math.acos(clamp(n.y, -1, 1)))
    ch = (q[0].y + q[1].y + q[2].y) / 3 - y_off
    cx, cz = (q[0].x + q[1].x + q[2].x) / 3, (q[0].z + q[1].z + q[2].z) / 3
    lit = n.dot(LIGHT)
    tone = 0 if lit > 0.62 else 1 if lit > 0.3 else 2 if lit > -0.05 else 3
    f = ch / H
    gully = any(seg_dist(cx, cz, ax, az, bx, bz)[0] < wd * 0.5 for (ax, az, bx, bz, wd) in couloirs)
    if gully and slope <= 58.0:
        return st["snow"][1 if (tone < 2 and slope > snow_slope) else tone]
    if f < st["forest_line"] and slope <= st.get("forest_slope", forest_slope):
        return st["forest"][tone]
    if slope <= snow_slope and f >= st["snow_line"]:
        return st["snow"][tone]
    band = int(clamp(f, 0, 0.999) * st["bands"])
    return st["rock"][min(4, tone + (band & 1))]


def paint(b, tris, st, H, couloirs=(), **kw):
    for q in tris:
        sw = tri_swatch(q, st, H, couloirs, **kw)
        if sw:
            b.face(list(q), sw, V(0, 1, 0))


def mini_pine(b, x, y, z, h, r, dark="pn_mid", light="pn_far", sides=5, tiers=2, snow=None):
    """A tiny distant conifer: one or two stacked pyramids (a dark body, a lighter or snowy upper tier). Sinks 1 stud into the ground."""
    y -= 1.0
    h += 1.0
    if tiers == 1:
        cyl(b, V(x, y, z), h, r, sides, dark, r_top=0.0)
        return
    cyl(b, V(x, y, z), h * 0.5, r, sides, dark, r_top=r * 0.5, top=False)
    cyl(b, V(x, y + h * 0.42, z), h * 0.58, r * 0.72, sides, snow or light, r_top=0.0)


def scatter_pines(b, hfun, sites, rng, hmin, hmax, dark="pn_mid", light="pn_far", sides=4, tiers=1, snow_top=None):
    for (x, z) in sites:
        y = hfun(x, z)
        if y < 1.0:
            continue
        h = rng.uniform(hmin, hmax)
        mini_pine(b, x, y, z, h, h * rng.uniform(0.2, 0.28), dark if rng.random() < 0.6 else light, light, sides, tiers, snow_top)


def sites_in(rng, W, D, n, ok, gap, tries=900, cz0=None):
    out = []
    t = 0
    while len(out) < n and t < tries:
        t += 1
        x = rng.uniform(-W / 2, W / 2)
        z = rng.uniform(-D / 2, D / 2) if cz0 is None else rng.uniform(*cz0)
        if not ok(x, z):
            continue
        if any((x - a) ** 2 + (z - c) ** 2 < gap * gap for a, c in out):
            continue
        out.append((x, z))
    return out


# ================================================================ S1: far massifs and the summit horn
def massif(name, W, D, H, ridges, spacing, style=STYLE_FAR, couloirs=(), note="", cdepth=0.05, forest_tris=None, **tk):
    rng = rng_of(name)
    b = L.new(name)
    tris, _ = terrain(ridges, W, D, spacing, rng, H, couloirs=couloirs, couloir_depth=cdepth, **tk)
    paint(b, tris, style, H, couloirs)
    return unit(b, "Backdrop", "far", "far 700-1200 from the road", authored=True, kind="massif", role=note, district="any", height=H, width=W, depth=D)


def skirt(W, D, h):
    """A low forested foothill platform under a massif: gentle edges (forest-coloured), so the mountain rises out of trees."""
    return plateau(0, 0, W * 0.40, D * 0.30, h, 0.42, 1.4, 34)


@recipe
def massif_a():
    S1, S2, D1 = 1.7, 1.15, 70
    r = [
        skirt(440, 380, 30),
        ridge([(-205, 12, 34), (-165, 4, 112), (-120, 0, 178), (-84, -8, 150), (-40, -4, 208), (18, -2, 252), (72, -5, 284), (112, 8, 234), (142, 2, 240), (176, 12, 150), (212, 10, 40)], S1, S2, D1),
        ridge([(72, -5, 284), (58, 58, 212), (96, 98, 132), (84, 126, 44)], S1 - 0.1, S2, D1 - 10),
        ridge([(-120, 0, 178), (-132, -52, 112), (-150, -86, 46)], S1 - 0.1, S2, D1 - 20),
        ridge([(-6, -62, 118), (44, -70, 126)], 0.3, 1.3, 26),
        ridge([(142, 2, 240), (150, -48, 150), (170, -84, 56)], S1, S2, D1 - 20),
    ]
    cl = [(40, -22, 62, -90, 22), (-70, -20, -92, -78, 16), (120, -10, 140, -70, 18)]
    return massif("SP_BG_Massif_A", 440, 380, 284, r, 30, couloirs=cl, note="far massif, summit right of centre, two shoulders, a notch and a snow bench")


@recipe
def massif_b():
    S1, S2, D1 = 1.7, 1.15, 60
    r = [
        skirt(360, 330, 24),
        ridge([(-172, 5, 30), (-124, -4, 92), (-78, 0, 150), (-58, -6, 192), (-18, 2, 148), (16, -4, 104), (56, 6, 158), (100, 0, 178), (140, 8, 98), (172, 4, 30)], S1, S2, D1),
        ridge([(100, 0, 178), (92, 54, 122), (114, 92, 58)], S1 - 0.1, S2, D1 - 10),
        ridge([(-58, -6, 192), (-76, -56, 112), (-92, -92, 46)], S1 - 0.1, S2, D1 - 10),
        ridge([(14, -62, 92), (66, -56, 98)], 0.3, 1.3, 22),
        ridge([(-130, 40, 70), (-90, 80, 70)], 0.3, 1.3, 20),
    ]
    cl = [(-30, -16, -44, -74, 18), (88, -10, 70, -60, 16)]
    return massif("SP_BG_Massif_B", 360, 330, 192, r, 28, couloirs=cl, note="far massif, summit left of centre, a second peak, a hanging bench")


@recipe
def massif_c():
    S1, S2, D1 = 1.8, 1.2, 70
    r = [
        skirt(500, 440, 34),
        ridge([(-246, 6, 38), (-206, -6, 104), (-170, 2, 182), (-132, 8, 168), (-96, -4, 252), (-62, -6, 348), (-20, 2, 286), (24, 8, 232), (62, 0, 268), (110, 6, 168), (160, 4, 120), (200, 6, 90), (240, 4, 40)], S1, S2, D1),
        ridge([(-62, -6, 348), (-50, 62, 262), (-20, 104, 170), (-30, 140, 56)], S1 - 0.1, S2, D1 - 10),
        ridge([(-96, -4, 252), (-130, -60, 170), (-150, -100, 90), (-160, -126, 40)], S1 - 0.1, S2, D1 - 10),
        ridge([(62, 0, 268), (84, -50, 190), (104, -90, 90)], S1 - 0.1, S2, D1 - 20),
        ridge([(20, -72, 130), (80, -76, 122)], 0.3, 1.3, 26),
        ridge([(150, -30, 96), (206, -50, 90)], 0.3, 1.3, 22),
    ]
    cl = [(-60, -20, -70, -96, 24), (80, -4, 100, -70, 18), (-190, -4, -204, -80, 18)]
    return massif("SP_BG_Massif_C", 500, 440, 348, r, 37, couloirs=cl, note="far massif, tallest, summit left of centre, a long stepped right-hand shoulder and a cliffed flank")


@recipe
def massif_d():
    S1, S2, D1 = 1.5, 1.1, 50
    r = [
        skirt(520, 300, 26),
        plateau(40, 0, 78, 22, 176, 1.9, 1.2, 40),
        ridge([(-248, 8, 36), (-196, 0, 74), (-150, -4, 112), (-100, 2, 142), (-30, 0, 176)], S1 - 0.2, S2, D1 - 12),
        ridge([(118, 0, 176), (160, -6, 98), (214, 4, 54), (256, 6, 30)], 2.0, 1.2, 50),
        ridge([(-100, 2, 142), (-110, 56, 90), (-90, 96, 40)], S1 - 0.2, S2, D1 - 12),
        ridge([(60, 22, 176), (70, 80, 110), (50, 112, 46)], S1 - 0.2, S2, D1 - 12),
        ridge([(-70, -58, 84), (-10, -62, 90)], 0.3, 1.3, 22),
    ]
    cl = [(100, -20, 110, -80, 20), (-140, -4, -150, -70, 18)]
    return massif("SP_BG_Massif_D", 520, 300, 178, r, 30, couloirs=cl, note="far massif, flat-topped table summit with a sheer right-hand cliff and a long stepped left ridge")


@recipe
def massif_horn():
    S1, S2, D1 = 2.4, 1.6, 40
    r = [
        plateau(0, 0, 96, 66, 46, 0.45, 1.2, 30),  # a forested and snowy apron the tooth rises out of
        ridge([(0, 0, 392), (15, -3, 353), (45, 0, 274), (75, 4, 196), (105, 6, 118), (135, 8, 60), (152, 8, 28)], S1, S2, D1),
        ridge([(0, 0, 392), (-12, 0, 353), (-40, -3, 274), (-66, 0, 214), (-82, 4, 190), (-112, 4, 182), (-124, 5, 140), (-136, 6, 96), (-146, 8, 60), (-154, 8, 30)], S1 - 0.2, S2, D1),
        ridge([(0, 0, 392), (-14, 40, 300), (-30, 80, 196), (-38, 112, 90), (-40, 128, 40)], S1 - 0.2, S2, D1),
        ridge([(0, 0, 392), (14, -40, 300), (30, -80, 196), (40, -110, 90), (42, -126, 40)], S1 - 0.2, S2, D1),
        ridge([(-120, -26, 150), (-84, -30, 156)], 0.2, 1.6, 24),
    ]
    cl = [(12, -20, 24, -86, 16), (-30, 20, -38, 80, 14), (60, 0, 76, 40, 14)]
    k_ = 0.93
    r = [dict(rr, pts=[(x * k_, z, h) for x, z, h in rr["pts"]]) for rr in r]
    for rr in r:
        if "rect" in rr:
            cx0, cz0, hx0, hz0, h0 = rr["rect"]
            rr["rect"] = (cx0 * k_, cz0, hx0 * k_, hz0, h0)
    cl = [(ax * k_, az, bx * k_, bz, wd) for (ax, az, bx, bz, wd) in cl]
    return massif("SP_BG_Massif_Horn", 320, 290, 392, r, 24, style=STYLE_HORN, couloirs=cl, cdepth=0.04, note="the recurring summit horn: a sharp tooth, a stepped snow shoulder on its left, rising out of a wide apron")


# ================================================================ S1: ridge curtains
RIDGE_LADDERS = [
    ("rk_far_lit", "rk_far", "rk_far_shade", "rk_far_deep", "rk_far_deep"),  # front band: the darkest
    ("rk_farthest", "rk_far_lit", "rk_far", "rk_far_shade", "rk_far_deep"),
    ("rk_farthest", "rk_farthest", "rk_far_lit", "rk_far", "rk_far_shade"),  # back band: the lightest
]


def ridge_curtain(name, length, H, bands, note):
    """A curtain of two or three jagged bands, front to back, each lighter than the one in front. bands = [(z, height factor, profile)]
    where profile is a list of crest-height fractions (8 to 14 uneven vertices). Strip construction, so the count is exact."""
    rng = rng_of(name)
    b = L.new(name)
    nb = len(bands)
    for k, (zc, hf, prof) in enumerate(bands):
        st = {"rock": RIDGE_LADDERS[min(k + (3 - nb), 2)], "snow": ("s_lit", "s_half", "s_shade", "s_gully"), "forest": ("pn_far", "pn_far", "pn_mid", "pn_mid"), "snow_line": 0.3, "forest_line": 0.0, "bands": 4}
        n = len(prof)
        steps = [rng.uniform(0.6, 1.4) for _ in range(n - 1)]
        tot = sum(steps)
        xs, acc = [], 0.0
        for sp in [0.0] + steps:
            acc += sp
            xs.append(-length / 2 + length * acc / tot)
        hk = H * hf
        a = hk * 0.9 + 14
        st_prof = [(-a, BASE_Y), (-a * 0.55, 0.24), (-a * 0.2, 0.64), (0.0, 1.0), (a * 0.2, 0.64), (a * 0.55, 0.24), (a, BASE_Y)]
        cols = []
        for i in range(n):
            hh = hk * prof[i] * (1.0 if 0 < i < n - 1 else 0.35)
            zj = zc + rng.uniform(-5, 5)
            col = []
            for (dz, fr) in st_prof:
                if fr == BASE_Y:
                    col.append(Vector((xs[i], BASE_Y, zj + dz)))
                else:
                    col.append(Vector((xs[i], hh * fr, zj + dz * (1.0 - 0.15 * (1 - prof[i])))))
            cols.append(col)
        for i in range(n - 1):
            for j in range(len(st_prof) - 1):
                p00, p10, p11, p01 = cols[i][j], cols[i + 1][j], cols[i + 1][j + 1], cols[i][j + 1]
                for tri in ((p00, p10, p11), (p00, p11, p01)) if (i + j) % 2 else ((p00, p10, p01), (p10, p11, p01)):
                    sw = tri_swatch(list(tri), st, hk)
                    if sw:
                        b.face(list(tri), sw, V(0, 1, 0))
    return unit(b, "Backdrop", "far", "ridge curtain 300-700 from the road", authored=True, kind="ridge", role=note, district="any", height=H, width=length)


@recipe
def ridge_a():
    return ridge_curtain("SP_BG_Ridge_A", 380, 120, [(-40, 0.62, [0.4, 0.95, 0.5, 0.85, 1.0, 0.45, 0.9, 0.4]), (0, 0.82, [0.35, 0.8, 0.45, 1.0, 0.5, 0.9, 0.4, 0.75]), (40, 1.0, [0.45, 0.9, 0.4, 1.0, 0.55, 0.95, 0.35, 0.8])], "ridge curtain, three bands, saw-tooth")


@recipe
def ridge_b():
    return ridge_curtain("SP_BG_Ridge_B", 300, 100, [(-30, 0.7, [0.5, 0.95, 0.55, 1.0, 0.4, 0.85, 0.45, 0.8, 0.35, 0.7, 0.45, 0.3]), (30, 1.0, [0.4, 0.8, 0.45, 0.95, 1.0, 0.4, 0.9, 0.5, 0.85, 0.4, 0.7, 0.35])], "ridge curtain, two bands, twin high points")


@recipe
def ridge_c():
    return ridge_curtain("SP_BG_Ridge_C", 420, 140, [(-42, 0.6, [0.35, 0.8, 0.45, 0.95, 0.5, 1.0, 0.4, 0.85]), (0, 0.8, [0.4, 0.9, 1.0, 0.45, 0.85, 0.6, 0.9, 0.35]), (42, 1.0, [0.3, 0.55, 0.85, 0.5, 1.0, 0.95, 0.55, 0.4])], "ridge curtain, tall, a long right-hand rise")


@recipe
def ridge_d():
    return ridge_curtain("SP_BG_Ridge_D", 240, 70, [(-24, 0.75, [0.45, 0.9, 0.5, 1.0, 0.55, 0.85, 0.4, 0.7, 0.45, 0.6]), (24, 1.0, [0.4, 0.75, 0.5, 0.95, 0.45, 1.0, 0.5, 0.85, 0.4, 0.55])], "ridge curtain, low and jagged")


@recipe
def ridge_e():
    return ridge_curtain("SP_BG_Ridge_E", 340, 110, [(-36, 0.65, [0.4, 0.6, 0.95, 0.5, 1.0, 0.4, 0.8, 0.4]), (0, 0.85, [0.35, 0.95, 0.45, 1.0, 0.7, 0.4, 0.8, 0.45]), (36, 1.0, [0.5, 0.7, 0.4, 0.95, 1.0, 0.5, 0.9, 0.4])], "ridge curtain, a left-hand peak")


@recipe
def ridge_f():
    return ridge_curtain("SP_BG_Ridge_F", 280, 90, [(-28, 0.7, [0.55, 0.95, 0.4, 0.85, 0.5, 1.0, 0.45, 0.8, 0.4, 0.9, 0.45, 0.7, 0.4, 0.3]), (28, 1.0, [0.4, 0.7, 0.95, 0.45, 1.0, 0.55, 0.4, 0.85, 0.95, 0.5, 0.8, 0.45])], "ridge curtain, fourteen small points")


# ================================================================ S1: spurs, terrace, knoll, treeline, glade, snout
def glade_mask(pts, width):
    """A predicate for points within width/2 of a polyline [(x, z), ...]."""

    def inside(x, z):
        return any(seg_dist(x, z, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])[0] < width / 2 for i in range(len(pts) - 1))

    return inside


def face_normal(q):
    n = (q[1] - q[0]).cross(q[2] - q[0])
    if n.length < 1e-9:
        return Vector((0, 1, 0))
    n = n.normalized()
    return n if n.y >= 0 else -n


def foothill(name, W, D, H, ridges, spacing, glade=None, trees=24, mirror=False, couloirs=(), note="", tree_h=(15, 24), tree_band_=(0.06, 0.5), seed_name=None, **tk):
    rng = rng_of(seed_name or name)
    b = L.new(name)
    tris, hfun = terrain(ridges, W, D, spacing, rng, H, couloirs=couloirs, couloir_depth=0.05, **tk)
    gl = glade_mask(*glade) if glade else (lambda x, z: False)
    style = STYLE_FOOT
    for q in tris:
        cx, cz = (q[0].x + q[1].x + q[2].x) / 3, (q[0].z + q[1].z + q[2].z) / 3
        if gl(cx, cz):
            n = face_normal(q)
            if math.degrees(math.acos(clamp(n.y, -1, 1))) < 48:
                b.face(list(q), "s_lit" if n.dot(LIGHT) > 0.35 else "s_half", V(0, 1, 0))
                continue
        sw = tri_swatch(list(q), style, H, couloirs)
        if sw:
            b.face(list(q), sw, V(0, 1, 0))

    def ok(x, z):
        y = hfun(x, z)
        if y < tree_band_[0] * H or y > tree_band_[1] * H or gl(x, z):
            return False
        e = 3.0
        gx, gz = (hfun(x + e, z) - hfun(x - e, z)) / (2 * e), (hfun(x, z + e) - hfun(x, z - e)) / (2 * e)
        return math.hypot(gx, gz) < 0.62

    sites = sites_in(rng, W, D, trees, ok, 9.0)
    scatter_pines(b, hfun, sites, rng, tree_h[0], tree_h[1], dark="pn_deep", light="pn_far", sides=4, tiers=1)
    if mirror:
        mirror_x(b)
    return unit(b, "Backdrop", "mid", "foothill spur 100-220 from the road", authored=True, kind="spur", role=note, district="any", height=H, width=W, depth=D, long_axis="x")


def spur_ridges(L_, H, S1=0.95, S2=0.62, D1=34):
    hl = L_ / 2
    return [
        ridge([(-hl + 6, 6, H * 0.3), (-hl * 0.6, 0, H * 0.72), (-hl * 0.25, -4, H * 0.62), (hl * 0.1, 2, H), (hl * 0.5, 6, H * 0.74), (hl * 0.62, -2, H * 0.84), (hl - 6, 8, H * 0.3)], S1, S2, D1),
        ridge([(hl * 0.1, 2, H), (hl * 0.04, 46, H * 0.62), (hl * 0.2, 80, H * 0.28)], S1 - 0.1, S2, D1 - 6),
        ridge([(-hl * 0.25, -4, H * 0.62), (-hl * 0.3, -40, H * 0.4), (-hl * 0.28, -70, H * 0.16)], S1 - 0.1, S2, D1 - 8),
        ridge([(hl * 0.35, -30, H * 0.36), (hl * 0.7, -34, H * 0.34)], 0.35, 1.2, 14),
    ]


SPUR_A_COUL = [(10, -4, 14, -60, 14), (-50, -2, -58, -50, 12)]
SPUR_A_GLADE = ([(-30, -60), (-12, -20), (6, 4)], 22)


@recipe
def spur_a():
    H = 96
    return foothill("SP_BG_Spur_A", 190, 230, H, spur_ridges(190, H), 20, glade=SPUR_A_GLADE, trees=40, couloirs=SPUR_A_COUL, note="foothill spur: strata, snow-filled gullies, a pine band and a narrow piste glade")


@recipe
def spur_a_m():
    H = 96
    b, meta = foothill("SP_BG_Spur_A_M", 190, 230, H, spur_ridges(190, H), 20, glade=SPUR_A_GLADE, trees=40, mirror=True, couloirs=SPUR_A_COUL, note="the authored mirror of SP_BG_Spur_A", seed_name="SP_BG_Spur_A")
    meta["mirror_of"] = "SP_BG_Spur_A"
    return b, meta


@recipe
def spur_b():
    H = 66
    hl = 75
    r = [
        ridge([(-hl, 4, H * 0.3), (-hl * 0.5, -2, H * 0.78), (-hl * 0.1, 3, H * 0.9), (hl * 0.3, -3, H), (hl * 0.7, 4, H * 0.55), (hl, 2, H * 0.22)], 0.9, 0.62, 26),
        ridge([(hl * 0.3, -3, H), (hl * 0.35, 40, H * 0.5), (hl * 0.5, 70, H * 0.2)], 0.85, 0.62, 22),
        ridge([(-hl * 0.5, -2, H * 0.78), (-hl * 0.6, -36, H * 0.36), (-hl * 0.6, -66, H * 0.12)], 0.85, 0.62, 22),
    ]
    return foothill("SP_BG_Spur_B", 160, 190, H, r, 18, trees=30, couloirs=[(0, 0, -6, -46, 12), (50, 0, 62, -40, 12)], tree_h=(14, 22), note="a lower foothill spur with a pine band and two gullies")


@recipe
def spur_c():
    H = 120
    hl = 105
    r = [
        ridge([(-hl, 6, H * 0.28), (-hl * 0.62, 0, H * 0.7), (-hl * 0.3, -4, H * 0.5), (-hl * 0.05, 4, H * 0.86), (hl * 0.28, -2, H), (hl * 0.6, 6, H * 0.64), (hl, 4, H * 0.24)], 1.0, 0.65, 38),
        ridge([(hl * 0.28, -2, H), (hl * 0.2, 50, H * 0.6), (hl * 0.3, 90, H * 0.24)], 0.95, 0.65, 34),
        ridge([(-hl * 0.05, 4, H * 0.86), (-hl * 0.2, -44, H * 0.5), (-hl * 0.18, -80, H * 0.18)], 0.95, 0.65, 34),
        ridge([(-hl * 0.7, -30, H * 0.3), (-hl * 0.4, -34, H * 0.28)], 0.35, 1.3, 16),
    ]
    return foothill("SP_BG_Spur_C", 230, 260, H, r, 22, glade=([(40, -90), (28, -50), (30, -10), (22, 20)], 24), trees=44, couloirs=[(-30, -6, -34, -70, 16), (80, 0, 90, -60, 14)], tree_h=(16, 26), note="the tallest foothill spur: a stepped crest, gullies and a diagonal piste glade")


def mini_chalet(b, x, y0, z, w, d, h, rise, roof, wall, ridge_x=True):
    """A simplified chalet for distant ranks: a box, a gabled roof with a snow cap, a chimney, one honey window. Centre (x, z), sits on y0."""
    hw, hd = w / 2, d / 2
    box(b, V(x, y0 + h / 2 - 0.5, z), (w, h + 1.0, d), {"side": wall, "skip_top": True, "skip_bottom": True})
    yb = y0 + h
    if ridge_x:
        for sz in (-1, 1):
            zz = z + sz * (hd + 0.8)
            b.face([V(x - hw - 0.8, yb, zz), V(x + hw + 0.8, yb, zz), V(x + hw + 0.8, yb + rise, z), V(x - hw - 0.8, yb + rise, z)], roof, V(0, 1, sz))
            zs = z + sz * (hd + 0.8) * 0.5 + sz * 0.1
            b.face([V(x - hw * 0.9, yb + rise * 0.45 + 0.25, zs), V(x + hw * 0.9, yb + rise * 0.45 + 0.25, zs), V(x + hw * 0.9, yb + rise + 0.3, z), V(x - hw * 0.9, yb + rise + 0.3, z)], "s_lit", V(0, 1, sz))
        for sx in (-1, 1):
            b.face([V(x + sx * hw, yb, z - hd), V(x + sx * hw, yb, z + hd), V(x + sx * hw, yb + rise * 0.92, z)], "w_wall_2", V(sx, 0, 0))
        b.face([V(x - 2.0, y0 + 0.2, z - hd - 0.3), V(x + 2.0, y0 + 0.2, z - hd - 0.3), V(x + 2.0, y0 + h * 0.65, z - hd - 0.3), V(x - 2.0, y0 + h * 0.65, z - hd - 0.3)], "honey_glow", V(0, 0, -1))
    else:
        for sx in (-1, 1):
            xx = x + sx * (hw + 0.8)
            b.face([V(xx, yb, z - hd - 0.8), V(xx, yb, z + hd + 0.8), V(x, yb + rise, z + hd + 0.8), V(x, yb + rise, z - hd - 0.8)], roof, V(sx, 1, 0))
            xs_ = x + sx * (hw + 0.8) * 0.5 + sx * 0.1
            b.face([V(xs_, yb + rise * 0.45 + 0.25, z - hd * 0.9), V(xs_, yb + rise * 0.45 + 0.25, z + hd * 0.9), V(x, yb + rise + 0.3, z + hd * 0.9), V(x, yb + rise + 0.3, z - hd * 0.9)], "s_lit", V(sx, 1, 0))
        for sz in (-1, 1):
            b.face([V(x - hw, yb, z + sz * hd), V(x + hw, yb, z + sz * hd), V(x, yb + rise * 0.92, z + sz * hd)], "w_wall_2", V(0, 0, sz))
        b.face([V(x - 2.0, y0 + 0.2, z - hd - 0.3), V(x + 2.0, y0 + 0.2, z - hd - 0.3), V(x + 2.0, y0 + h * 0.6, z - hd - 0.3), V(x - 2.0, y0 + h * 0.6, z - hd - 0.3)], "honey_glow", V(0, 0, -1))
    box(b, V(x + hw * 0.45, yb + rise * 0.9, z + hd * 0.2), (1.8, rise * 0.5 + 1.0, 1.8), {"side": "s_stone", "top": "s_lit", "skip_bottom": True})


@recipe
def terrace_a():
    rng = rng_of("SP_BG_Terrace_A")
    b = L.new("SP_BG_Terrace_A")
    W, D, H = 170, 150, 70
    cl = [(40, 40, 36, 10, 12)]
    r = [
        plateau(0, -6, 66, 14, 17, 0.5, 1.1, 8),
        ridge([(-84, 52, 40), (-50, 50, 66), (-10, 54, 78), (30, 50, 70), (62, 54, 60), (84, 52, 34)], 1.0, 0.7, 22),
        ridge([(-30, 52, 72), (-46, 18, 40), (-52, -20, 14)], 0.8, 0.7, 12),
    ]
    tris, hfun = terrain(r, W, D, 22, rng, H, couloirs=cl, couloir_depth=0.04)
    for q in tris:
        cy = (q[0].y + q[1].y + q[2].y) / 3
        cx, cz = (q[0].x + q[1].x + q[2].x) / 3, (q[0].z + q[1].z + q[2].z) / 3
        n = face_normal(q)
        if n.y > 0.97 and 15 < cy < 19 and abs(cx) <= 70 and -22 <= cz <= 8:
            b.face(list(q), "s_half" if n.dot(LIGHT) > 0.9 else "s_lit", V(0, 1, 0))
            continue
        sw = tri_swatch(list(q), STYLE_FOOT, H, cl)
        if sw:
            b.face(list(q), sw, V(0, 1, 0))
    # a second rank of small chalets on the bench: the bench sits 17 high, eaves 10 to 14 above it
    roofs = ["rf_slate", "w_roof_1", "rf_forest", "rf_shingle"]
    walls = ["m_wood_1", "s_board", "s_ochre", "m_wood_2"]
    for i, (x, w, hw_, rise) in enumerate(((-50, 18, 10, 6), (-17, 14, 12, 5), (17, 20, 9, 7), (50, 15, 11, 5))):
        mini_chalet(b, x, 17, -6 + rng.uniform(-2, 2), w, 12, hw_, rise, roofs[i], walls[i], ridge_x=(i % 2 == 0))
    for x, z in ((-72, -10), (-34, 6), (0, 12), (34, 2), (70, -8), (-10, -14)):
        mini_pine(b, x, 17 if abs(x) < 66 else max(1.0, hfun(x, z)), z, rng.uniform(16, 22), 4.4, "pn_mid", "pn_far", 5, 2, "s_half")
    sites = sites_in(rng, W, D, 14, lambda x, z: z > 18 and 28 < hfun(x, z) < 60, 11.0)
    scatter_pines(b, hfun, sites, rng, 16, 22, dark="pn_mid", light="pn_deep", sides=4, tiers=1)
    return unit(b, "Backdrop", "mid", "foothill terrace 100-200 from the road", authored=True, kind="terrace", role="a foothill terrace with a flat bench that carries a second rank of four small chalets, a pine band behind", district=["PineVillage"], height=H, width=W, depth=D)


@recipe
def knoll():
    rng = rng_of("SP_BG_Knoll")
    b = L.new("SP_BG_Knoll")
    W, D, H = 110, 96, 42
    r = [
        plateau(0, -2, 22, 18, 40, 1.4, 0.9, 14),
        ridge([(-44, 8, 20), (-26, 14, 36), (8, 18, 34), (40, 10, 24)], 1.0, 0.8, 14),
        ridge([(-14, -10, 38), (-26, -30, 24), (-28, -44, 8)], 1.0, 0.8, 10),
        ridge([(22, -10, 38), (36, -30, 22), (38, -44, 8)], 1.0, 0.8, 10),
    ]
    tris, hfun = terrain(r, W, D, 14, rng, H, noise_amp=0.05, taper=0.3, jit=0.25)
    for q in tris:
        sw = tri_swatch(list(q), STYLE_NEAR, H)
        if sw:
            b.face(list(q), sw, V(0, 1, 0))
    for x, z in ((-40, -14), (-34, 20), (44, -18), (40, 26), (-6, 34)):
        mini_pine(b, x, max(1.0, hfun(x, z)), z, rng.uniform(16, 24), 4.4, "pn_mid", "pn_far", 5, 2, "s_half")
    return unit(b, "Backdrop", "mid", "rock knoll behind the lodge", authored=True, kind="knoll", role="a rock knoll with a flat 44 x 36 snow top at 40 studs that carries the observatory plinth", district=["SummitLodge"], height=H, width=W, depth=D, platform={"centre": [0, 40, -2], "size": [44, 36]})


def tree_band(name, length, hmin, hmax, rows, note):
    rng = rng_of(name)
    b = L.new(name)
    d = 14.0 * rows
    box(b, V(0, 0.6, 0), (length, 2.2, d), {"side": "s_half", "top": "s_half", "skip_bottom": True})  # a low snowy strip the trees stand on
    n_per = int(length / 12.0)
    for r_ in range(rows):
        z = -d / 2 + 6 + r_ * 14.0
        for i in range(n_per):
            x = -length / 2 + (i + rng.uniform(0.1, 0.9)) * length / n_per
            h = rng.uniform(hmin, hmax) * (1.0 - 0.1 * r_)
            rr = h * rng.uniform(0.16, 0.22)
            mini_pine(b, x, 1.5, z + rng.uniform(-3, 3), h, rr, "pn_deep" if rng.random() < 0.45 else "pn_mid", "pn_mid", 4, 2, "s_half" if rng.random() < 0.4 else None)
    return unit(b, "Backdrop", "mid", "far-shore treeline 330-380 from the road", authored=True, kind="treeline", role=note, district=["FrozenLake"], height=hmax, width=length, depth=d)


@recipe
def treeline_a():
    return tree_band("SP_BG_TreelineBand_A", 220, 30, 40, 2, "a dark far-shore pine band: two staggered rows of uneven firs on a low snow strip")


@recipe
def treeline_b():
    return tree_band("SP_BG_TreelineBand_B", 150, 28, 38, 2, "a shorter dark pine band with taller firs at one end")


def piste_glade(name, W, D, H, glade_pts, note):
    rng = rng_of(name)
    b = L.new(name)
    hd = D / 2
    r = [ridge([(-W / 2 + 8, hd - 14, H * 0.8), (-W * 0.25, hd - 20, H), (0, hd - 16, H * 0.88), (W * 0.26, hd - 22, H * 0.98), (W / 2 - 8, hd - 14, H * 0.74)], 0.8, 0.6, 40)]
    tris, hfun = terrain(r, W, D, 24, rng, H, noise_amp=0.04, taper=0.25, p=4.0, keep_sq=0.5)
    gl = glade_mask(glade_pts, 40)
    gl_trees = glade_mask(glade_pts, 54)
    for q in tris:
        cx, cz = (q[0].x + q[1].x + q[2].x) / 3, (q[0].z + q[1].z + q[2].z) / 3
        n = face_normal(q)
        if gl(cx, cz):
            b.face(list(q), "s_lit" if n.dot(LIGHT) > 0.5 else "s_half", V(0, 1, 0))
        elif (q[0].y + q[1].y + q[2].y) / 3 > H * 0.93:
            b.face(list(q), "rk_near_lit" if n.dot(LIGHT) > 0.5 else "rk_near", V(0, 1, 0))
        else:
            b.face(list(q), "pn_mid" if n.dot(LIGHT) > 0.3 else "pn_deep", V(0, 1, 0))
    sites = []
    for i in range(len(glade_pts) - 1):  # tree lines hug both edges of the glade, then a loose forest beyond
        (x0, z0), (x1, z1) = glade_pts[i], glade_pts[i + 1]
        ln = math.hypot(x1 - x0, z1 - z0)
        nx, nz = -(z1 - z0) / ln, (x1 - x0) / ln
        k = max(2, int(ln / 11))
        for j in range(k + 1):
            t = j / k
            for sg in (-1, 1):
                off = 25.0 + rng.uniform(0, 4)
                sites.append((lerp(x0, x1, t) + sg * nx * off + rng.uniform(-2, 2), lerp(z0, z1, t) + sg * nz * off + rng.uniform(-2, 2)))
    sites = [(x, z) for (x, z) in sites if abs(x) < W / 2 - 6 and abs(z) < hd - 6 and hfun(x, z) > 3.0]
    extra = sites_in(rng, W, D, 10, lambda x, z: hfun(x, z) > 6.0 and not gl_trees(x, z) and abs(x) < W / 2 - 8 and abs(z) < hd - 10, 12.0)
    scatter_pines(b, hfun, sites + extra, rng, 22, 34, dark="pn_deep", light="pn_mid", sides=4, tiers=1)
    g0, g1 = glade_pts[0], glade_pts[-1]
    path = [[round(x, 2), round(max(0.0, hfun(x, z)), 2), round(z, 2)] for (x, z) in glade_pts]
    surface = [[round(g0[0], 2), round(max(0.0, hfun(*g0)), 2)], [round(g1[0], 2), round(max(0.0, hfun(*g1)), 2)]]
    return unit(b, "Backdrop", "mid", "forested hillside 120-260 from the road", authored=True, kind="glade", role=note, district=["SkiLiftRidge"], height=H, width=W, depth=D, surface=surface, surface_path=path)


@recipe
def glade_a():
    return piste_glade("SP_BG_PisteGlade_A", 200, 130, 80, [(-50, -50), (-30, -10), (-8, 26), (14, 52)], "a forested slope with a diagonal 40-wide piste glade and tree lines on both sides")


@recipe
def glade_b():
    return piste_glade("SP_BG_PisteGlade_B", 240, 130, 88, [(60, -50), (40, -22), (22, 4), (28, 30), (46, 52)], "a forested slope with an S-bent 40-wide piste glade")


@recipe
def glacier_snout():
    rng = rng_of("SP_BG_GlacierSnout")
    b = L.new("SP_BG_GlacierSnout")
    W, D = 300, 170
    n = 9
    xs = [-80 + 160 * i / (n - 1) + (rng.uniform(-4, 4) if 0 < i < n - 1 else 0.0) for i in range(n)]
    notch = {2, 5}  # crevasse columns: the cliff face steps back and is dark
    # cross-section, front to back: (dz from the cliff foot, height fraction, colour of the segment that follows)
    prof = [(0.0, None, "ice_pale"), (0.5, 0.26, "ice_lit"), (1.0, 0.52, "s_half"), (12.0, 0.54, "ice_pale"), (12.6, 0.74, "ice_lit"), (13.0, 0.92, "s_lit"), (36.0, 0.96, "s_lit"), (74.0, 1.1, "s_half"), (112.0, 1.26, "ice_deep"), (112.5, None, None)]
    cols = []
    for i, x in enumerate(xs):
        h = 118 * (rng.uniform(0.8, 1.0) if 0 < i < n - 1 else 0.72)
        zf = -36 + rng.uniform(-3, 3) + (7 if i in notch else 0.0)
        col = []
        for k, (dz, fr, _) in enumerate(prof):
            col.append(Vector((x, BASE_Y if fr is None else fr * h, zf + dz)))
        cols.append(col)
    for i in range(n - 1):
        for k in range(len(prof) - 1):
            a, c = prof[k], prof[k + 1]
            p00, p10, p11, p01 = cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1]
            sw = a[2]
            if k in (0, 1, 3, 4):  # cliff faces: the crevasse columns are dark, the others alternate ice tones
                if i in notch or i + 1 in notch:
                    sw = "ice_shade"
                elif i % 2:
                    sw = {"ice_deep": "ice_shade", "ice_pale": "ice_deep", "ice_lit": "ice_pale"}[sw]
            for tri in ((p00, p10, p11), (p00, p11, p01)):
                b.face(list(tri), sw, V(0, 1, 0) if k in (2, 5, 6, 7) else Vector((tri[0].x * 0, 0.0, -1.0 if k < 8 else 1.0)))
    for si, x in ((0, xs[0]), (n - 1, xs[-1])):  # the two end walls close the mass
        b.face(list(cols[si]), "ice_deep", V(-1 if si == 0 else 1, 0, 0))
    # dark rock flanks, two different masses (the left is taller and broader)
    flanks = (
        (-1, 104, [ridge([(14, -50, 70), (8, -10, 130), (-2, 24, 178), (-10, 54, 150)], 1.5, 1.1, 36), ridge([(-2, 24, 178), (-26, 14, 112), (-38, 0, 46)], 1.4, 1.1, 34), ridge([(8, -10, 130), (-6, -44, 78), (-10, -66, 34)], 1.4, 1.1, 30)], 110),
        (1, 100, [ridge([(-12, -46, 64), (-6, -12, 118), (8, 20, 150), (14, 50, 128)], 1.5, 1.1, 34), ridge([(8, 20, 150), (30, 10, 100), (40, -2, 42)], 1.4, 1.1, 32), ridge([(-6, -12, 118), (6, -40, 70)], 1.4, 1.1, 28)], 100),
    )
    for sg, off, rr, fw in flanks:
        tr, _ = terrain(rr, fw, 160, 20, rng, 178, noise_amp=0.05, taper=0.3)
        for q in tr:
            qq = [Vector((v.x + sg * off, v.y, v.z + 20)) for v in q]
            sw = tri_swatch(qq, STYLE_GLACIER, 178)
            if sw:
                b.face(qq, sw, V(0, 1, 0))
    return unit(b, "Backdrop", "mid", "glacier body above the tunnel", authored=True, kind="glacier", role="a big blue-white stepped ice cliff front with dark rock flanks, the glacier body above the tunnel", district=["GlacierTunnel"], height=178, width=W, depth=D)


# ================================================================ shared parts: profile strips, frustums, snow rings, collars
def strips(b, xs, profs, swf, caps=True):
    """Sweep a per-station profile [(z, y), ...] (front to back, base to base) along x. swf(i, k) names the swatch of the quad between
    stations i, i+1 on profile segment k. The end caps close the mass."""
    n, m = len(xs), len(profs[0])
    for i in range(n - 1):
        for k in range(m - 1):
            a0, a1 = profs[i][k], profs[i][k + 1]
            c0, c1 = profs[i + 1][k], profs[i + 1][k + 1]
            p00, p10, p11, p01 = V(xs[i], a0[1], a0[0]), V(xs[i + 1], c0[1], c0[0]), V(xs[i + 1], c1[1], c1[0]), V(xs[i], a1[1], a1[0])
            dz, dy = a1[0] - a0[0], a1[1] - a0[1]
            hint = V(0, dz, -dy) if (abs(dz) + abs(dy)) > 1e-6 else V(0, 1, 0)
            sw = swf(i, k)
            b.face([p00, p10, p11], sw, hint)
            b.face([p00, p11, p01], sw, hint)
    if caps:
        for i, sgn in ((0, -1), (n - 1, 1)):
            b.face([V(xs[i], y, z) for z, y in profs[i]], swf(i if i < n - 1 else i - 1, 0), V(sgn, 0, 0))


def frustum(b, cx, y, cz, h, r0, r1, sides, phase, sw, bottom=None, top=None):
    """A faceted frustum (r1 = 0 gives a pyramid). sw is a swatch name or fn(k, nx, nz) -> swatch for side k."""
    lo = [V(cx + math.cos(phase + 2 * math.pi * k / sides) * r0, y, cz + math.sin(phase + 2 * math.pi * k / sides) * r0) for k in range(sides)]
    hi = [V(cx + math.cos(phase + 2 * math.pi * k / sides) * r1, y + h, cz + math.sin(phase + 2 * math.pi * k / sides) * r1) for k in range(sides)]
    for k in range(sides):
        k2 = (k + 1) % sides
        am = phase + 2 * math.pi * (k + 0.5) / sides
        nx, nz = math.cos(am), math.sin(am)
        s_ = sw(k, nx, nz) if callable(sw) else sw
        b.face([lo[k], lo[k2], hi[k2], hi[k]], s_, V(nx, (r0 - r1) / max(h, 0.01), nz))
    if bottom:
        b.face(lo, bottom, V(0, -1, 0))
    if top and r1 > 0:
        b.face(hi, top, V(0, 1, 0))


def snow_ring(b, x, z, r_out, r_in, h=0.9, sides=6, sw="s_half", top="s_lit", y=-0.3):
    """A low ring of snow around a trunk or post (a 'collar'): a frustum from r_out at the ground to r_in at h."""
    frustum(b, x, y, z, h + 0.3, r_out, r_in, sides, 0.3, sw, top=top)


def snow_mound(b, cx, cz, rx, rz, h, rng, sws, rings=3, segs=10, y0=0.0):
    """A lumpy snow mound of concentric elliptical rings (sws = swatch per ring, outside to inside)."""
    pts = []
    for r in range(rings + 1):
        t = r / rings
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            j = 1.0 + (rng.random() - 0.5) * 0.16 * (1 - t)
            ring.append(V(cx + math.cos(a) * rx * (1 - t * 0.9) * j, (y0 + h * (1 - (1 - t) ** 2.0)) if r else y0 - 0.3, cz + math.sin(a) * rz * (1 - t * 0.9) * j))
        pts.append(ring)
    for r in range(rings):
        for k in range(segs):
            k2 = (k + 1) % segs
            q = [pts[r][k], pts[r][k2], pts[r + 1][k2], pts[r + 1][k]]
            cen = sum(q, V(0, 0, 0)) / 4
            b.face(q, sws[min(len(sws) - 1, r)], V(cen.x - cx, 1.0, cen.z - cz))
    b.face(pts[rings], sws[-1], V(0, 1, 0))


# ================================================================ S1: road edge
def edge_meta(kind, Ln, h, note):
    return {"kind": kind, "length": Ln, "height": h, "role": note, "district": "any"}


def berm(name, Ln, hmax, note):
    rng = rng_of(name)
    b = L.new(name)
    n = max(4, int(Ln / 7.0)) + 1
    xs = [-Ln / 2 + Ln * i / (n - 1) for i in range(n)]
    profs = []
    for i in range(n):
        h = hmax * (rng.uniform(0.62, 1.0) if 0 < i < n - 1 else 0.38)
        zj = rng.uniform(-0.6, 0.6)
        profs.append([(-4.8 + zj, BASE_Y), (-3.2 + zj, 0.3 * h), (-1.1 + zj, 0.86 * h), (0.8, h), (2.8, 0.72 * h), (4.6, 0.16 * h), (5.6, BASE_Y)])
    cols = ["s_gully", "s_shade", "s_half", "s_lit", "s_half", "s_shade"]
    strips(b, xs, profs, lambda i, k: cols[k] if not (k in (2, 3) and i % 2) else ("s_lit" if k == 2 else "s_half"))
    return unit(b, "Edge", "near", "road edge 38-50", authored=True, **edge_meta("berm", Ln, hmax, note))


@recipe
def berm_a():
    return berm("SP_Edge_Berm_A", 24, 2.4, "an uneven plowed berm, blue-grey at the base, 24 long")


@recipe
def berm_b():
    return berm("SP_Edge_Berm_B", 36, 3.2, "an uneven plowed berm, 36 long")


@recipe
def berm_c():
    return berm("SP_Edge_Berm_C", 48, 4.0, "an uneven plowed berm, 48 long")


def drift(name, Ln, h, note):
    rng = rng_of(name)
    b = L.new(name)
    n = max(3, int(Ln / 6.0)) + 1
    xs = [-Ln / 2 + Ln * i / (n - 1) for i in range(n)]
    profs = []
    for i in range(n):
        hh = h * (rng.uniform(0.7, 1.0) if 0 < i < n - 1 else 0.4)
        profs.append([(-5.2, BASE_Y), (-3.4, 0.2 * hh), (-0.8, 0.55 * hh), (1.8, 0.9 * hh), (3.6, hh), (4.6, hh), (4.6, BASE_Y)])
    cols = ["s_shade", "s_half", "s_lit", "s_lit", "s_half", "s_shade"]
    strips(b, xs, profs, lambda i, k: cols[k])
    return unit(b, "Edge", "near", "building base", authored=True, **edge_meta("drift", Ln, h, note))


@recipe
def drift_a():
    return drift("SP_Edge_Drift_A", 12, 3.0, "a drift wedge against a wall, 12 long")


@recipe
def drift_b():
    return drift("SP_Edge_Drift_B", 18, 4.0, "a drift wedge against a wall, 18 long")


@recipe
def drift_c():
    return drift("SP_Edge_Drift_C", 24, 5.0, "a drift wedge against a wall, 24 long")


@recipe
def snowpole():
    b = L.new("SP_Edge_Snowpole")
    snow_ring(b, 0, 0, 2.4, 0.9, 0.9)
    cyl(b, V(0, 0.4, 0), 7.2, 0.38, 5, "m_wood_2", r_top=0.32, top_sw="m_wood_2")
    cyl(b, V(0, 5.0, 0), 2.6, 0.42, 5, "bunt_cream", r_top=0.36, top_sw="bunt_cream")  # a pale reflective top section
    box(b, V(0, 7.9, 0), (0.9, 0.5, 0.9), {"side": "m_wood_1", "top": "s_lit", "skip_bottom": True})
    return unit(b, "Edge", "near", "road edge 38-50", authored=True, long_axis="x", **edge_meta("snowpole", 0.9, 8.4, "a snow pole 8 tall: a timber pole with a pale top section and a snow cap, in a snow collar"))


def split_rail(name, Ln, spacing, h, rails, note):
    rng = rng_of(name)
    b = L.new(name)
    xs = [-Ln / 2 + spacing * i for i in range(int(round(Ln / spacing)) + 1)]
    for x in xs:
        frustum(b, x, -0.3, 0, 1.0, 1.8, 0.9, 4, 0.78, "s_half", top="s_lit")  # a 2-stud snow collar
        box(b, V(x, h / 2 + 0.2, 0), (0.7, h + 0.4, 0.7), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    for i in range(len(xs) - 1):
        for r in range(rails):
            y = h * (0.45 + 0.42 * r / max(1, rails - 1)) if rails > 1 else h * 0.6
            tilt = rng.uniform(-0.12, 0.12)
            box(b, V((xs[i] + xs[i + 1]) / 2, y + tilt, -0.55 if r % 2 else 0.55), (spacing + 0.6, 0.42, 0.42), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    return unit(b, "Edge", "near", "road edge 38-50", authored=True, **edge_meta("rail", Ln, h, note))


@recipe
def rail_a():
    return split_rail("SP_Edge_Rail_A", 24, 8.0, 3.2, 2, "a split-rail fence run, 24 long, two rails on 8-stud bays")


@recipe
def rail_b():
    return split_rail("SP_Edge_Rail_B", 24, 12.0, 2.8, 3, "a lower split-rail fence run, 24 long, 12-stud bays with three rails")


def rock_cut(name, Ln, h, note, ledges=2):
    rng = rng_of(name)
    b = L.new(name)
    n = max(5, int(Ln / 5.0)) + 1
    xs = [-Ln / 2 + Ln * i / (n - 1) for i in range(n)]
    profs = []
    for i in range(n):
        hh = h * (rng.uniform(0.74, 1.0) if 0 < i < n - 1 else 0.55)
        zj = rng.uniform(-0.8, 0.8)
        pr = [(zj, BASE_Y), (zj + 0.5, 0.34 * hh), (zj + 3.2, 0.36 * hh), (zj + 3.6, 0.7 * hh), (zj + 6.0, 0.72 * hh), (zj + 6.4, hh), (zj + 9.0, hh * 1.03), (zj + 14.0, 0.45 * hh), (zj + 16.0, BASE_Y)]
        profs.append(pr)
    cols = ["rk_near", "rk_warm", "s_half", "rk_near_lit", "s_half", "rk_near", "s_lit", "rk_near_shade"]
    alt = ["rk_dark", "rk_near", "s_shade", "rk_warm", "s_half", "rk_near_shade", "s_half", "rk_dark"]
    strips(b, xs, profs, lambda i, k: cols[k] if (i + k) % 3 else alt[k])
    return unit(b, "Edge", "near", "road edge 38-50", authored=True, pivot="bottom centre: x centred on the cut, z = 0 at the foot of the cut face (the road side); the mass runs back toward +Z", **edge_meta("rockcut", Ln, h, note))


@recipe
def rockcut_a():
    return rock_cut("SP_Edge_RockCut_A", 24, 8, "a rock cut 24 long, 8 high: strata and snow on the ledges")


@recipe
def rockcut_b():
    return rock_cut("SP_Edge_RockCut_B", 36, 12, "a rock cut 36 long, 12 high")


@recipe
def rockcut_c():
    return rock_cut("SP_Edge_RockCut_C", 48, 16, "a rock cut 48 long, 16 high")


def moraine(name, Ln, note):
    rng = rng_of(name)
    b = L.new(name)
    snow_mound(b, 0, 0, Ln * 0.5, 6.0, 1.6, rng, ["moraine_dirty", "moraine_dirty", "s_shade"], rings=2, segs=10)
    nb = int(Ln / 9)
    for i in range(nb):
        x = -Ln / 2 + (i + 0.5) * Ln / nb + rng.uniform(-1.5, 1.5)
        sz = rng.uniform(2.6, 4.2)
        sphere(b, V(x, 0.9 + sz * 0.2, rng.uniform(-3, 3)), (sz, sz * 0.6, sz * 0.8), ["rk_dark", "moraine", "moraine", "moraine_dirty"], subdiv=0, rng=rng, jitter=0.2)
    return unit(b, "Edge", "near", "tunnel approach", authored=True, **edge_meta("moraine", Ln, 4.0, note))


@recipe
def moraine_a():
    return moraine("SP_Edge_Moraine_A", 24, "rubble and dirty snow at the glacier approach, 24 long")


@recipe
def moraine_b():
    return moraine("SP_Edge_Moraine_B", 48, "rubble and dirty snow at the glacier approach, 48 long")


# ================================================================ S1: foliage
def conifer(b, x, z, h, rng, tiers=5, sides=6, base_r=None, greens=("p_dark", "p_mid"), snow=0.55, ring=True, trunk_h=None):
    """A snow-laden conifer: a flared trunk in a snow ring, drooping tiers whose faces toward the light carry snow, a spike."""
    base_r = base_r or h * 0.17
    y0 = trunk_h if trunk_h is not None else h * 0.16
    if ring:
        snow_ring(b, x, z, base_r * 0.9 + 1.4, 1.9, 0.9, sides=6)
        frustum(b, x, -0.2, z, 1.7, 1.9, 0.95, 5, 0.2, "p_trunk_dark")
        cyl(b, V(x, 1.4, z), y0, 0.95, 5, "p_trunk", r_top=0.8)
    else:
        cyl(b, V(x, -0.2, z), y0 + 0.4, 1.1, 4, "p_trunk", r_top=0.8)
    span = h - y0
    for i in range(tiers):
        t = i / tiers
        r = base_r * (1 - t * 0.8) * rng.uniform(0.92, 1.08)
        ty = y0 + span * t * 0.86
        th = span / tiers * 1.55
        dx, dz = rng.uniform(-0.12, 0.12) * r, rng.uniform(-0.12, 0.12) * r
        gi = greens[i % 2]

        def side_sw(k, nx, nz, gi=gi, t=t):
            lit = nx * LIGHT.x + nz * LIGHT.z
            if lit > -0.1 and rng.random() < snow + t * 0.3:
                return "s_lit" if (lit > 0.35 and t > 0.4) else "s_half"
            return gi

        frustum(b, x + dx, ty, z + dz, th, r, r * 0.3, sides, 0.35 * i, side_sw, bottom="pn_deep")
    frustum(b, x, y0 + span * 0.86 + 0.6, z, span * 0.2 + 1.2, base_r * 0.2, 0.0, sides, 0.0, "pn_mid")


def foliage_meta(kind, h, note):
    return {"kind": kind, "height": h, "role": note, "district": "any"}


@recipe
def spruce():
    b = L.new("SP_Fol_Spruce")
    conifer(b, 0, 0, 38.0, rng_of("SP_Fol_Spruce"), tiers=5, sides=6, base_r=8.6)
    return unit(b, "Fol", "near", "near layer 50-90", authored=True, **foliage_meta("spruce", 38.0, "a snow-laden spruce 38 tall (scale 0.7 to 1.15 gives 26 to 44): the trunk flares into a snow ring"))


@recipe
def fir():
    b = L.new("SP_Fol_Fir")
    conifer(b, 0, 0, 21.0, rng_of("SP_Fol_Fir"), tiers=4, sides=5, base_r=5.0, greens=("pn_young", "p_mid"), snow=0.25)
    return unit(b, "Fol", "near", "near layer 50-90", authored=True, **foliage_meta("fir", 21.0, "a young fir 16 to 26 tall, lighter green, little snow"))


@recipe
def bent_pine():
    rng = rng_of("SP_Fol_BentPine")
    b = L.new("SP_Fol_BentPine")
    snow_ring(b, 0, 0, 3.6, 1.8, 0.9)
    path = [V(0, -0.2, 0), V(0.6, 7.0, 0.2), V(2.2, 15.0, -0.2), V(4.6, 23.0, 0.3), V(7.4, 28.0, 0.0)]
    tube(b, path, [1.7, 1.2, 0.95, 0.75, 0.5], 5, ["p_trunk_dark", "p_trunk"], cap=True)
    for (cx, cy, rr) in ((6.8, 27.0, 6.4), (11.4, 24.6, 5.4), (3.8, 21.6, 5.0), (9.0, 30.0, 3.6)):
        sphere(b, V(cx, cy, rng.uniform(-0.6, 0.6)), (rr, rr * 0.42, rr * 0.8), ["pn_bent", "pn_bent", "pn_mid", "s_half"], subdiv=0, rng=rng, jitter=0.18, light_dir=(0.1, 1.0, 0.0))
    return unit(b, "Fol", "near", "near layer 50-90", authored=True, **foliage_meta("bentpine", 32.0, "a wind-bent pine 24 to 34 tall: the crown streams to one side (+x)"))


def grove(name, spec, note):
    rng = rng_of(name)
    b = L.new(name)
    box(b, V(0, 0.2, 0), (21.0, 0.9, 15.0), {"side": "s_half", "top": "s_lit", "skip_bottom": True})
    top = 0.0
    for (x, z, h, k) in spec:
        conifer(b, x, z, h, rng, tiers=3 if len(spec) < 4 else 2, sides=4, base_r=h * 0.17, greens=("p_dark", "p_mid") if k else ("p_mid", "p_dark"), snow=0.5, ring=False, trunk_h=h * 0.14)
        top = max(top, h)
    return unit(b, "Fol", "near", "near layer 50-90", authored=True, **foliage_meta("grove", top, note))


@recipe
def grove_a():
    return grove("SP_Fol_Grove_A", [(-5.5, -1.0, 42.0, 0), (1.5, 2.5, 33.0, 1), (6.0, -2.0, 38.0, 0), (-1.0, -4.0, 27.0, 1)], "a grove of four spruces at mixed heights 27 to 42 on one snow base")


@recipe
def grove_b():
    return grove("SP_Fol_Grove_B", [(-6.0, 1.0, 34.0, 1), (0.0, -2.0, 44.0, 0), (6.5, 1.5, 28.0, 0)], "a grove of three spruces 28 to 44")


@recipe
def grove_c():
    return grove("SP_Fol_Grove_C", [(-6.5, -2.0, 30.0, 0), (-1.5, 3.0, 40.0, 1), (4.0, -3.0, 36.0, 0), (7.5, 2.0, 26.0, 1)], "a grove of four spruces 26 to 40, the tallest set back")


@recipe
def reeds():
    rng = rng_of("SP_Fol_Reeds")
    b = L.new("SP_Fol_Reeds")
    snow_mound(b, 0, 0, 7.0, 4.0, 1.0, rng, ["s_shade", "s_half"], rings=2, segs=8)
    for i in range(14):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0.5, 5.0)
        x, z = math.cos(a) * r, math.sin(a) * r * 0.55
        hh = rng.uniform(4.5, 9.0)
        lean = rng.uniform(-0.9, 0.9)
        base = [V(x - 0.35, 0.5, z), V(x + 0.35, 0.5, z - 0.2), V(x, 0.5, z + 0.35)]
        tip = V(x + lean, 0.5 + hh, z + rng.uniform(-0.4, 0.4))
        for kk in range(3):
            b.face([base[kk], base[(kk + 1) % 3], tip], "s_reed" if i % 3 else "s_half", V(base[kk].x - x, 0.3, base[kk].z - z) + V(0, 0, 0))
    return unit(b, "Fol", "near", "lake shore", authored=True, **foliage_meta("reeds", 9.5, "a frozen reed clump: pale straw blades with frosted tips"))


# ================================================================ S1: hazards (scenery previews; footprints identical to Round 2)
def haz_meta(kind, note):
    return {"family": "Haz", "world": WORLD, "lod": "near", "district": "any", "kind": kind, "pivot": "centre on the surface it stands on", "sockets": {"base": sock((0, 0, 0))}, "rule": note}


def oval(rx, rz, n=14):
    return circle2(0, 0, 1.0, n)


@recipe
def haz_ice_patch():
    b = L.new("SP_Haz_IcePatch")
    ring = circle2(0, 0, 1.0, 16)
    b.face([V(x * 8.0, 0.05, z * 5.5) for x, z in ring], "rim_haz", V(0, 1, 0))  # a crisp dark rim
    b.face([V(x * 7.0, 0.08, z * 4.7) for x, z in ring], "hz_light", V(0, 1, 0))  # a pale body, far lighter than the asphalt
    b.face([V(x * 3.6 - 1.2, 0.1, z * 2.0) for x, z in ring], "s_lit", V(0, 1, 0))
    return b, haz_meta("oil", "ice patch: a crisp oval with a dark rim, pale body and a brighter heart; at least 15 value points lighter than asphalt; scenery preview only")


@recipe
def haz_frost_crack():
    rng = rng_of("SP_Haz_FrostCrack")
    b = L.new("SP_Haz_FrostCrack")
    ring = circle2(0, 0, 1.0, 14)
    b.face([V(x * 7.0, 0.05, z * 5.0) for x, z in ring], "rim_dark", V(0, 1, 0))
    b.face([V(x * 6.4, 0.07, z * 4.4) for x, z in ring], "hz_light", V(0, 1, 0))
    for kk in range(4):  # dark jagged crack strips across the pale patch
        a = (kk - 1.5) * 0.45
        pts = [V(-5.6 + 2.8 * j, 0.09, (rng.random() - 0.5) * 2.8 + a * (-5.6 + 2.8 * j) * 0.4) for j in range(5)]
        for j in range(4):
            p, q = pts[j], pts[j + 1]
            b.face([V(p.x, 0.1, p.z - 0.3), V(q.x, 0.1, q.z - 0.3), V(q.x, 0.1, q.z + 0.3), V(p.x, 0.1, p.z + 0.3)], "rim_haz", V(0, 1, 0))
    return b, haz_meta("pothole", "frost crack: dark cracks across a pale oval patch (dark on pale), scenery preview only")


@recipe
def haz_snowbank():
    rng = rng_of("SP_Haz_Snowbank")
    b = L.new("SP_Haz_Snowbank")
    snow_mound(b, 0, 0, 10.0, 4.6, 2.2, rng, ["s_shade", "s_half", "s_lit"], rings=3, segs=12)
    for s_ in (-1, 1):  # plow stakes and cones: orange-and-white lives only here
        for z in (-3.6, 3.6):
            box(b, V(s_ * 11.6, 2.4, z), (0.4, 4.8, 0.4), {"side": "haz_orange", "top": "haz_white", "skip_bottom": True})
        cyl(b, V(s_ * 12.8, 0, 0.0), 2.0, 0.7, 6, "haz_orange", r_top=0.2, top_sw="haz_white")
    return b, haz_meta("construction", "snowbank with plow stakes (orange and white appear only here)")


# ================================================================ S1: signs
def sign_meta(w, h, fx, fy, fz):
    return {"role": "a blank cream sign face toward the road; the text is drawn at runtime", "district": "any", "sign_face": {"centre": [round(fx, 2), round(fy, 2), round(fz, 2)], "size": [round(w, 2), round(h, 2)]}}


def board_face(b, cx, cy, w, h, frame_t=0.9, depth=0.9, face_sw="m_sign"):
    """A timber frame with a blank cream face at z = -(depth/2 + 0.05); returns the face centre z."""
    box(b, V(cx, cy, 0), (w, h, depth), {"side": "m_sign_frame", "top": "s_half", "skip_bottom": True})
    zf = -depth / 2 - 0.05
    b.face([V(cx - w / 2 + frame_t, cy - h / 2 + frame_t, zf), V(cx + w / 2 - frame_t, cy - h / 2 + frame_t, zf), V(cx + w / 2 - frame_t, cy + h / 2 - frame_t, zf), V(cx - w / 2 + frame_t, cy + h / 2 - frame_t, zf)], face_sw, V(0, 0, -1))
    return zf


@recipe
def sign_a():
    b = L.new("SP_Sign_Board_A")
    w, h = 20.0, 7.6
    for x in (-w / 2 + 1.6, w / 2 - 1.6):
        snow_ring(b, x, 0, 1.8, 0.8, 0.6)
        box(b, V(x, 5.6, 0), (0.9, 11.2, 0.9), {"side": "m_wood_2", "skip_bottom": True})
    zf = board_face(b, 0, 9.4, w, h)
    return unit(b, "Sign", "near", "frontage", authored=True, **sign_meta(w - 1.8, h - 1.8, 0, 9.4, zf))


@recipe
def sign_b():
    b = L.new("SP_Sign_Board_B")
    w, h = 14.0, 6.6
    snow_ring(b, -9.0, 0, 2.0, 0.9, 0.7)
    box(b, V(-9.0, 7.5, 0), (1.0, 15.0, 1.0), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(-1.0, 14.2, 0), (17.0, 0.8, 0.8), {"side": "m_wood_2", "top": "s_half", "skip_bottom": True})  # a bracket arm
    for x in (-5.4, 4.8):
        box(b, V(x, 13.2, 0), (0.3, 1.2, 0.3), {"side": "m_metal_dark", "skip_bottom": True})  # two hangers
    zf = board_face(b, -0.3, 9.7, w, h, depth=0.8)
    return unit(b, "Sign", "near", "frontage", authored=True, **sign_meta(w - 1.8, h - 1.8, -0.3, 9.7, zf))


@recipe
def sign_c():
    b = L.new("SP_Sign_Board_C")
    w, h = 26.0, 8.0
    for x in (-w / 2 + 2.0, w / 2 - 2.0):
        snow_ring(b, x, 0, 2.0, 0.9, 0.7)
        box(b, V(x, 6.0, 0), (1.1, 12.0, 1.1), {"side": "m_wood_2", "skip_bottom": True})
    zf = board_face(b, 0, 10.0, w, h, depth=1.0)
    b.face([V(-w / 2 - 0.8, 14.2, -1.2), V(w / 2 + 0.8, 14.2, -1.2), V(w / 2 + 0.8, 15.4, 0.6), V(-w / 2 - 0.8, 15.4, 0.6)], "rf_shingle", V(0, 1, -1))  # a small timber cap with a snow lid
    b.face([V(-w / 2 - 0.4, 14.5, -0.9), V(w / 2 + 0.4, 14.5, -0.9), V(w / 2 + 0.4, 15.7, 0.5), V(-w / 2 - 0.4, 15.7, 0.5)], "s_half", V(0, 1, -1))
    return unit(b, "Sign", "near", "frontage", authored=True, **sign_meta(w - 1.8, h - 1.8, 0, 10.0, zf))


# ================================================================ architecture helpers
# A building is written centred (x -W/2..W/2), facade in the plane z = 0 facing -Z, body behind it (z > 0); finish() shifts it.
class WallFrame:
    """A wall plane: kind 'z' (a wall across the x axis at z = c) or 'x' (a wall along z at x = c); sign = the outward direction."""

    def __init__(self, kind, c, sign):
        self.kind, self.c, self.sign = kind, c, sign
        self.n = V(0, 0, sign) if kind == "z" else V(sign, 0, 0)

    def P(self, u, y, d=0.0):
        return V(u, y, self.c + self.sign * d) if self.kind == "z" else V(self.c + self.sign * d, y, u)

    def skip(self):
        """box() skip flags for a box standing on this wall (its face against the wall is not built)."""
        if self.kind == "z":
            return {"skip_back": True} if self.sign < 0 else {"skip_front": True}
        return {"skip_right": True} if self.sign < 0 else {"skip_left": True}

    def box(self, b, u, y, w, h, d0, d1, sw):
        """A box on the wall: centre u, y, width w along the wall, height h, from d0 to d1 outward; sw = swatch or dict."""
        dm = (d0 + d1) / 2
        c = self.P(u, y, dm)
        sz = (w, h, d1 - d0) if self.kind == "z" else (d1 - d0, h, w)
        sd = dict(sw) if isinstance(sw, dict) else {"side": sw}
        sd["skip_bottom"] = sd.get("skip_bottom", True)
        sd.update(self.skip())
        box(b, c, sz, sd)


PL = 1.6  # plinth height: the stone footing runs 1.5 below ground and 1.6 above


def pad(b, W, D, x=0.0, z0=-1.0):
    """The lot's snow pad: a low slab with a blue-grey edge, so a lot reads as a place (the road side has the berm in front of it)."""
    box(b, V(x, 0.2, (z0 + D) / 2), (W, 0.9, D - z0), {"side": "s_shade", "top": "s_half", "skip_bottom": True})


def snow_skirt(b, x0, x1, z0, z1, y, out=2.4, y_out=0.7):
    """A sloped drift around a plinth: four trapezoids from the ground ring up to the wall foot."""
    c = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    o = [(x0 - out, z0 - out), (x1 + out, z0 - out), (x1 + out, z1 + out), (x0 - out, z1 + out)]
    for i in range(4):
        j = (i + 1) % 4
        mx, mz = (c[i][0] + c[j][0]) / 2 - (x0 + x1) / 2, (c[i][1] + c[j][1]) / 2 - (z0 + z1) / 2
        b.face([V(c[i][0], y, c[i][1]), V(c[j][0], y, c[j][1]), V(o[j][0], y_out, o[j][1]), V(o[i][0], y_out, o[i][1])], "s_lit" if i == 0 else "s_half", V(mx, 1.2, mz))


def wall_panel(b, wf, u0, u1, y0, y1, style, tones):
    """A wall face in one of the building styles: plain, log (horizontal courses), board (boards and battens), storeys (plaster with beams)."""
    n = wf.n
    if style == "plain":
        b.face([wf.P(u0, y0), wf.P(u1, y0), wf.P(u1, y1), wf.P(u0, y1)], tones[0], n)
    elif style == "log":
        k = max(2, int(round((y1 - y0) / 2.1)))
        ch = (y1 - y0) / k
        for i in range(k):
            b.face([wf.P(u0, y0 + i * ch), wf.P(u1, y0 + i * ch), wf.P(u1, y0 + (i + 1) * ch), wf.P(u0, y0 + (i + 1) * ch)], tones[i % 2], n)
    elif style == "board":
        u, i = u0, 0
        while u < u1 - 1e-6:
            wd = min(3.4 if i % 2 == 0 else 0.9, u1 - u)
            b.face([wf.P(u, y0), wf.P(u + wd, y0), wf.P(u + wd, y1), wf.P(u, y1)], tones[i % 2], n)
            u += wd
            i += 1
    elif style == "storeys":  # tones = (plaster, beam, storeys)
        k = int(tones[2])
        sh = (y1 - y0) / k
        for i in range(k):
            ya, yb = y0 + i * sh, y0 + (i + 1) * sh
            b.face([wf.P(u0, ya), wf.P(u1, ya), wf.P(u1, yb - 0.5), wf.P(u0, yb - 0.5)], tones[0], n)
            b.face([wf.P(u0, yb - 0.5), wf.P(u1, yb - 0.5), wf.P(u1, yb), wf.P(u0, yb)], tones[1], n)


def window(b, wf, u, y, w=3.6, h=4.6, glow=False, frame="w_trim_1", shutter=None, sill=True, cross=False):
    """A raised window: a frame box, a pane (honey glow or glass), a snowy sill, optional shutters. y is the pane centre."""
    wf.box(b, u, y, w + 1.2, h + 1.2, 0.0, 0.45, {"side": frame, "top": frame})
    pane = "honey_glow" if glow else "w_glass"
    b.face([wf.P(u - w / 2, y - h / 2, 0.5), wf.P(u + w / 2, y - h / 2, 0.5), wf.P(u + w / 2, y + h / 2, 0.5), wf.P(u - w / 2, y + h / 2, 0.5)], pane, wf.n)
    if cross:  # one mullion bar
        wf.box(b, u, y, 0.35, h, 0.5, 0.6, {"side": frame})
    if sill:
        wf.box(b, u, y - h / 2 - 0.75, w + 2.0, 0.5, 0.0, 1.1, {"side": frame, "top": "s_lit"})
    if shutter:
        for sg in (-1, 1):
            wf.box(b, u + sg * (w / 2 + 1.5), y, 1.3, h + 0.6, 0.0, 0.4, {"side": shutter})


def door(b, wf, u, w=4.2, h=7.4, y0=PL, frame="m_wood_2", panel="w_door"):
    wf.box(b, u, y0 + h / 2 + 0.2, w + 1.2, h + 0.8, 0.0, 0.45, {"side": frame, "top": frame})
    b.face([wf.P(u - w / 2, y0, 0.5), wf.P(u + w / 2, y0, 0.5), wf.P(u + w / 2, y0 + h, 0.5), wf.P(u - w / 2, y0 + h, 0.5)], panel, wf.n)


def steps(b, wf, u, w=6.0, n=2, y_top=PL):
    """Steps from the door sill down to the ground (the lowest, farthest step is 1/n of the sill height)."""
    for k in range(n):
        top = y_top * (n - k) / n
        wf.box(b, u, (top - 0.3) / 2, w - k * 0.4, top + 0.3, 0.0, 1.2 * (k + 1), {"side": "s_stone_dk", "top": "s_half", "skip_bottom": True})


def porch(b, wf, u, w, depth, y_roof, roof_sw, rise=1.4, post="m_wood_2", deck=True):
    """A porch roof (a mono-pitch slab with a snow lid) on two posts that reach the ground, plus a deck."""
    for sg in (-1, 1):
        wf.box(b, u + sg * (w / 2 - 0.3), (y_roof - 0.3) / 2, 0.7, y_roof + 0.3, depth - 0.8, depth - 0.1, {"side": post, "top": post})
    wf.box(b, u, y_roof + rise / 2, w + 1.4, rise, 0.0, depth + 0.6, {"side": roof_sw, "top": roof_sw})
    wf.box(b, u, y_roof + rise + 0.25, w + 0.6, 0.5, 0.2, depth + 0.2, {"side": "s_half", "top": "s_lit"})
    if deck:
        wf.box(b, u, 0.5, w + 1.0, 1.4, 0.0, depth + 0.8, {"side": "s_stone_dk", "top": "m_wood_1"})


def chimney(b, x, z, y0, y1, w=2.2):
    y1 = y0 + (y1 - y0) * 0.8
    box(b, V(x, (y0 + y1) / 2, z), (w, y1 - y0, w), {"side": "s_stone", "top": "s_stone", "skip_bottom": True})
    box(b, V(x, y1 + 0.3, z), (w + 0.7, 0.6, w + 0.7), {"side": "s_stone_lt", "top": "s_lit", "skip_bottom": True})
    return (x, y1 + 0.6, z)


def mp(axis, l, a, y):
    """(along, across, y) -> point; axis 'x' = the ridge runs along x."""
    return V(l, y, a) if axis == "x" else V(a, y, l)


def gable_roof(b, axis, l0, l1, a0, a1, ye, rise, roof, edge="m_wood_2", gable_wall="w_wall_2", over_e=1.8, over_g=0.9, t=0.55, snow=1.0, gable_ends=(True, True), ridge_cap="m_wood_2"):
    """A gable roof over the wall rectangle (along l0..l1, across a0..a1) with eaves at ye and the ridge `rise` above: thick panels with a
    fascia, soffits, barge boards, a ridge cap and (when the pitch is under 45 degrees) snow slabs from the ridge down. Returns the ridge top."""
    ac = (a0 + a1) / 2
    half = (a1 - a0) / 2
    slope = rise / half
    yr = ye + rise
    L0, L1 = l0 - over_g, l1 + over_g
    tt = t * math.sqrt(1 + slope * slope)
    for s in (-1, 1):
        aw = ac + s * half
        ae = aw + s * over_e
        ye_e = ye - slope * over_e
        b.face([mp(axis, L0, ae, ye_e), mp(axis, L1, ae, ye_e), mp(axis, L1, ac, yr), mp(axis, L0, ac, yr)], roof, mp(axis, 0, s * slope, 1))
        b.face([mp(axis, L0, ae, ye_e), mp(axis, L1, ae, ye_e), mp(axis, L1, ae, ye_e - tt), mp(axis, L0, ae, ye_e - tt)], edge, mp(axis, 0, s, 0))
        b.face([mp(axis, L0, ae, ye_e - tt), mp(axis, L1, ae, ye_e - tt), mp(axis, L1, aw, ye - tt), mp(axis, L0, aw, ye - tt)], edge, mp(axis, 0, 0, -1))
        for lw, Lb, sl in ((l0, L0, -1), (l1, L1, 1)):
            b.face([mp(axis, Lb, ae, ye_e), mp(axis, Lb, ac, yr), mp(axis, Lb, ac, yr - tt), mp(axis, Lb, ae, ye_e - tt)], edge, mp(axis, sl, 0, 0))
            b.face([mp(axis, Lb, ae, ye_e - tt), mp(axis, Lb, ac, yr - tt), mp(axis, lw, ac, yr - tt), mp(axis, lw, ae, ye_e - tt), mp(axis, lw, aw, ye - tt)], edge, mp(axis, 0, 0, -1))
        if snow > 0 and slope <= 1.0:
            sn = 0.5
            af = ac + s * half * snow if snow < 0.99 else ac + s * (half + over_e - 0.9)
            yf = yr - slope * abs(af - ac)
            Ls0, Ls1 = L0 + 0.5, L1 - 0.5
            b.face([mp(axis, Ls0, af, yf + sn), mp(axis, Ls1, af, yf + sn), mp(axis, Ls1, ac, yr + sn), mp(axis, Ls0, ac, yr + sn)], "s_lit", mp(axis, 0, s * slope, 1))
            b.face([mp(axis, Ls0, af, yf), mp(axis, Ls1, af, yf), mp(axis, Ls1, af, yf + sn), mp(axis, Ls0, af, yf + sn)], "s_half", mp(axis, 0, s, 0))
            for Ls, sl in ((Ls0, -1), (Ls1, 1)):
                b.face([mp(axis, Ls, af, yf), mp(axis, Ls, ac, yr), mp(axis, Ls, ac, yr + sn), mp(axis, Ls, af, yf + sn)], "s_half", mp(axis, sl, 0, 0))
    for (lw, sl, on) in ((l0, -1, gable_ends[0]), (l1, 1, gable_ends[1])):
        if on and gable_wall:
            b.face([mp(axis, lw, a0, ye), mp(axis, lw, a1, ye), mp(axis, lw, ac, yr)], gable_wall, mp(axis, sl, 0, 0))
    if ridge_cap:
        sz = (L1 - L0 + 0.2, 0.7, 1.3) if axis == "x" else (1.3, 0.7, L1 - L0 + 0.2)
        cc = mp(axis, (L0 + L1) / 2, ac, yr + 0.15)
        box(b, cc, sz, {"side": ridge_cap, "top": "s_half" if snow > 0 and slope <= 1.0 else ridge_cap, "skip_bottom": True})
    return yr


def hip_roof(b, x0, x1, z0, z1, ye, rise, roof, edge="m_wood_2", over=1.8, t=0.55, snow=1.0):
    """A hip roof (ridge along x) with thick panels, a fascia and soffits all round and snow on the long panels."""
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    half = (z1 - z0) / 2
    rl = max(0.5, (x1 - x0) / 2 - half)
    yr = ye + rise
    slope = rise / half
    tt = t * math.sqrt(1 + slope * slope)
    xa, xb, za, zb = x0 - over, x1 + over, z0 - over, z1 + over
    ye_e = ye - slope * over
    R0, R1 = V(cx - rl, yr, cz), V(cx + rl, yr, cz)
    corners = [V(xa, ye_e, za), V(xb, ye_e, za), V(xb, ye_e, zb), V(xa, ye_e, zb)]
    b.face([corners[0], corners[1], R1, R0], roof, V(0, slope, -1))
    b.face([corners[2], corners[3], R0, R1], roof, V(0, slope, 1))
    b.face([corners[1], corners[2], R1], roof, V(1, slope, 0))
    b.face([corners[3], corners[0], R0], roof, V(-1, slope, 0))
    for i in range(4):
        c0, c1 = corners[i], corners[(i + 1) % 4]
        nrm = V(c1.z - c0.z, 0, -(c1.x - c0.x))
        b.face([c0, c1, c1 - V(0, tt, 0), c0 - V(0, tt, 0)], edge, nrm)
    wl = [V(x0, ye - tt, z0), V(x1, ye - tt, z0), V(x1, ye - tt, z1), V(x0, ye - tt, z1)]
    for i in range(4):
        j = (i + 1) % 4
        b.face([corners[i] - V(0, tt, 0), corners[j] - V(0, tt, 0), wl[j], wl[i]], edge, V(0, -1, 0))
    if snow > 0 and slope <= 1.0:
        sn = 0.5
        for s, zz in ((-1, za), (1, zb)):
            dz = half * 0.35
            zf = cz + s * dz
            hx = rl + (half - dz) * 0.9
            b.face([V(cx - hx, yr - slope * dz + sn, zf), V(cx + hx, yr - slope * dz + sn, zf), V(cx + rl, yr + sn, cz), V(cx - rl, yr + sn, cz)], "s_lit", V(0, slope, s))
    return yr


def dormer(b, x, w, y_base, hh, zf, depth, roof, wall="w_wall_2", glow=True):
    """A small dormer on a front roof slope: a box with a gabled roof and a glazed front. zf = its front wall z, y_base = the roof surface there."""
    y_base -= 0.3
    box(b, V(x, y_base + hh / 2, zf + depth / 2), (w, hh, depth), {"side": wall, "skip_top": True, "skip_bottom": True, "skip_front": True})
    b.face([V(x - w / 2, y_base, zf), V(x + w / 2, y_base, zf), V(x + w / 2, y_base + hh, zf), V(x - w / 2, y_base + hh, zf)], wall, V(0, 0, -1))
    b.face([V(x - w / 2 + 0.7, y_base + 0.9, zf - 0.1), V(x + w / 2 - 0.7, y_base + 0.9, zf - 0.1), V(x + w / 2 - 0.7, y_base + hh - 0.6, zf - 0.1), V(x - w / 2 + 0.7, y_base + hh - 0.6, zf - 0.1)], "honey_glow" if glow else "w_glass", V(0, 0, -1))
    rr = w * 0.34
    for s_ in (-1, 1):
        b.face([V(x + s_ * (w / 2 + 0.5), y_base + hh, zf - 0.6), V(x + s_ * (w / 2 + 0.5), y_base + hh, zf + depth + 0.3), V(x, y_base + hh + rr, zf + depth + 0.3), V(x, y_base + hh + rr, zf - 0.6)], roof, V(s_, 1, 0))
    b.face([V(x - w / 2 - 0.4, y_base + hh, zf - 0.05), V(x + w / 2 + 0.4, y_base + hh, zf - 0.05), V(x, y_base + hh + rr, zf - 0.05)], wall, V(0, 0, -1))


def wood_pile(b, x, z, w=5.0, h=2.6, d=2.0):
    """A woodpile: a stack of logs read as three tiers, under a plank cap with snow."""
    box(b, V(x, h / 2, z), (w, h, d), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    for k in range(3):
        box(b, V(x, 0.45 + k * 0.85, z - d / 2 - 0.05), (w - 0.2, 0.42, 0.1), {"side": "m_wood_2"})
    box(b, V(x, h + 0.3, z), (w + 0.8, 0.5, d + 0.8), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})


def lot_sockets(W, smokes):
    """roof_a / roof_b smoke sockets from chimney tops (recipe frame x, y, z), shifted into the lot frame."""
    out = {}
    for name, p in zip(("roof_a", "roof_b"), smokes):
        out[name] = sock((p[0] + W / 2, p[1], p[2]))
    return out


def lot(b, W, D, h, cls, districts, smokes=(), shop=False, **kw):
    return finish(b, W, D, h, cls, districts, shop=shop, module="scenery", sockets=lot_sockets(W, smokes) if smokes else None, authored=True, **kw)


# ================================================================ S1: chalet forms
def house_base(b, x0, x1, z0, z1, style, tones, y1, plinth_sw="s_stone", gable=None):
    """Plinth with a snow skirt and the four walls up to y1 (the roof function adds gable triangles)."""
    y0 = PL
    box(b, V((x0 + x1) / 2, (y0 - 1.5) / 2, (z0 + z1) / 2), (x1 - x0 + 0.6, y0 + 1.5, z1 - z0 + 0.6), {"side": plinth_sw, "top": "s_stone_lt", "skip_bottom": True})
    snow_skirt(b, x0 - 0.3, x1 + 0.3, z0 - 0.3, z1 + 0.3, y0)
    fr = WallFrame("z", z0, -1)
    bk = WallFrame("z", z1, 1)
    lf = WallFrame("x", x0, -1)
    rt = WallFrame("x", x1, 1)
    wall_panel(b, fr, x0, x1, y0, y1, style, tones)
    wall_panel(b, bk, x0, x1, y0, y1, style if style != "board" else "plain", tones if style != "board" else (tones[0],))
    wall_panel(b, lf, z0, z1, y0, y1, style, tones)
    wall_panel(b, rt, z0, z1, y0, y1, style, tones)
    return fr, bk, lf, rt


@recipe
def chalet_log24():
    b = L.new("SP_Lot_ChaletLog24")
    W, D = 24.0, 18.0
    pad(b, W, D)
    x0, x1, z0, z1 = -9.5, 9.5, 1.0, 15.0
    wy = 8.0
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("m_wood_1", "m_wood_2"), wy)
    door(b, fr, -2.5, h=6.4)
    steps(b, fr, -2.5, 6.0)
    porch(b, fr, -2.5, 8.0, 3.4, 7.8, "rf_forest")
    window(b, fr, 5.5, 5.6, h=3.8, glow=True, shutter="rf_forest")
    window(b, lf, 8.0, 5.6, h=3.8, glow=True, shutter="rf_forest")
    window(b, rt, 8.0, 5.6, h=3.8, shutter="rf_forest")
    window(b, bk, 0.0, 5.6, h=3.8)
    yr = gable_roof(b, "x", x0, x1, z0, z1, wy + PL, 5.0, "rf_forest", gable_wall="s_board", over_e=2.0, snow=0.85)
    smoke = chimney(b, 4.5, 11.5, wy + PL, wy + PL + 6.6)
    wood_pile(b, -8.0, 17.0, 5.0)
    return lot(b, W, D, 16.0, "low", ["PineVillage", "SkiLiftRidge", "SummitLodge"], [smoke], role="a low log chalet: 30 degree forest-green roof, ridge along the road, porch and woodpile", ridge="parallel", roof_colour="rf_forest")


@recipe
def chalet_board36():
    b = L.new("SP_Lot_ChaletBoard36")
    W, D = 36.0, 22.0
    pad(b, W, D)
    x0, x1, z0, z1 = -14.0, 14.0, 1.0, 19.0
    wy = 7.4
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "board", ("s_board", "s_weather"), wy)
    door(b, fr, 5.0)
    steps(b, fr, 5.0, 6.0)
    porch(b, fr, 5.0, 8.0, 3.2, 8.6, "m_wood_2")
    for u in (-9.0, -2.0):
        window(b, fr, u, 6.2, w=3.8, h=4.8, glow=(u > -5), shutter="s_sage")
    window(b, lf, 8.0, 6.2, glow=True)
    window(b, lf, 14.0, 6.2)
    window(b, rt, 8.0, 6.2)
    # ridge across the road: the gable end faces the road; the glazed gable window
    yr = gable_roof(b, "z", z0, z1, x0, x1, wy + PL, 11.6, "w_roof_1", gable_wall="s_board", over_e=1.9, snow=0.6)
    b.face([V(-3.0, wy + PL + 2.0, z0 - 0.4), V(3.0, wy + PL + 2.0, z0 - 0.4), V(3.0, wy + PL + 7.4, z0 - 0.4), V(-3.0, wy + PL + 7.4, z0 - 0.4)], "honey_glow", V(0, 0, -1))
    box(b, V(0, wy + PL + 4.7, z0 - 0.15), (7.0, 6.4, 0.3), {"side": "m_wood_2", "skip_bottom": True, "skip_back": True})
    smoke = chimney(b, -6.0, 12.0, wy + PL + 3.0, wy + PL + 12.6)
    return lot(b, W, D, 21.5, "low", ["PineVillage", "SkiLiftRidge"], [smoke], role="a board-and-batten chalet: 40 degree berry roof, gable end to the road, glazed gable window", ridge="across", roof_colour="w_roof_1")


@recipe
def chalet_aframe24():
    b = L.new("SP_Lot_ChaletAFrame24")
    W, D = 24.0, 20.0
    pad(b, W, D)
    hw = 9.4
    z0, z1 = 1.5, 17.5
    base = 6.0
    ymax = PL + base + 19.2
    # a 58 degree A-frame: two roof panels from a low timber base to a ridge across the road; shed snow, show timber
    for s_ in (-1, 1):
        for k in range(7):
            t0, t1 = k / 7, (k + 1) / 7
            xa, xb = s_ * (hw + 0.6) * (1 - t0), s_ * (hw + 0.6) * (1 - t1)
            ya, yb = PL + (ymax - PL) * t0, PL + (ymax - PL) * t1
            b.face([V(xa, ya, z0 - 0.5), V(xa, ya, z1 + 0.5), V(xb, yb, z1 + 0.5), V(xb, yb, z0 - 0.5)], "m_wood_2" if k % 2 else "rf_shingle", V(s_, 1, 0))
    # the front and back triangles: timber frame, glazed
    for (zf, sg) in ((z0 - 0.5, -1), (z1 + 0.5, 1)):
        tri = [V(-hw - 0.6, PL, zf), V(hw + 0.6, PL, zf), V(0, ymax, zf)]
        b.face(tri, "m_wood_1", V(0, 0, sg))
        if sg < 0:
            gl = [V(-hw + 1.6, PL + 1.2, zf - 0.25), V(hw - 1.6, PL + 1.2, zf - 0.25), V(1.6, ymax - 6.0, zf - 0.25), V(-1.6, ymax - 6.0, zf - 0.25)]
            b.face(gl, "honey_glow", V(0, 0, -1))
            for (a, c) in ((V(-hw - 0.2, PL, zf - 0.3), V(-0.5, ymax - 0.5, zf - 0.3)), (V(hw + 0.2, PL, zf - 0.3), V(0.5, ymax - 0.5, zf - 0.3))):
                tube(b, [a, c], 0.45, 4, "m_wood_2", phase=0.78)
            box(b, V(0, PL + 6.4, zf - 0.3), (hw * 1.2, 0.5, 0.5), {"side": "m_wood_2"})
            box(b, V(0, PL + 11.4, zf - 0.3), (hw * 0.62, 0.5, 0.5), {"side": "m_wood_2"})
        else:
            b.face([V(-hw + 1.6, PL + 1.2, zf + 0.1), V(hw - 1.6, PL + 1.2, zf + 0.1), V(1.4, ymax - 6.0, zf + 0.1), V(-1.4, ymax - 6.0, zf + 0.1)], "w_glass", V(0, 0, 1))
    # side base boards close the ends under the panels; a deck with steps in front
    box(b, V(0, PL / 2 - 0.5, (z0 + z1) / 2), (2 * hw + 1.2, PL + 1.0, z1 - z0 + 1.0), {"side": "s_stone", "top": "s_stone", "skip_bottom": True})
    snow_skirt(b, -hw - 0.6, hw + 0.6, z0 - 0.5, z1 + 0.5, PL, out=1.4)
    box(b, V(0, 1.3, z0 - 2.6), (14.0, 0.6, 4.4), {"side": "m_wood_2", "top": "m_wood_1"})
    for sx in (-6.4, 6.4):
        box(b, V(sx, 0.6, z0 - 4.6), (0.7, 2.6, 0.7), {"side": "m_wood_2"})
    box(b, V(0, 2.6, z0 - 4.7), (13.4, 0.4, 0.4), {"side": "m_wood_2", "top": "s_half"})
    snow_ring(b, -hw - 0.6, 4.0, 2.0, 1.0, 1.0)  # drifts under the eaves where the roof sheds
    snow_ring(b, hw + 0.6, 12.0, 2.0, 1.0, 1.0)
    smoke = chimney(b, 0.0, 14.0, ymax - 9.0, ymax + 1.0, w=2.2)
    return lot(b, W, D, ymax + 1.5, "mid", ["PineVillage", "SkiLiftRidge"], [smoke], role="a steep A-frame: 58 degree shingle panels shed snow and show timber, a glazed gable to the road", ridge="across", roof_colour="rf_shingle")


@recipe
def chalet_hip36():
    b = L.new("SP_Lot_ChaletHip36")
    W, D = 36.0, 21.0
    pad(b, W, D)
    x0, x1, z0, z1 = -14.0, 14.0, 1.0, 19.0
    wy = 12.0
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "plain", ("s_ochre",), wy)
    fr.box(b, 0.0, PL + wy * 0.5 + 0.3, x1 - x0, 0.7, 0.0, 0.3, {"side": "m_wood_2", "top": "s_half"})  # a belt course between the storeys
    for u in (-10.0, 0.0, 10.0):
        window(b, fr, u, PL + 3.6, w=3.6, h=4.4, glow=(u == 0.0), frame="w_wall_2", shutter="rf_slate")
    for u in (-10.0, 10.0):
        window(b, fr, u, PL + 8.6, w=3.6, h=4.0, frame="w_wall_2", shutter="rf_slate")
    door(b, fr, 0.0, w=4.4, h=7.0, frame="w_wall_2")
    steps(b, fr, 0.0, 6.0)
    porch(b, fr, 0.0, 8.0, 3.2, 8.4, "rf_slate")
    for u in (6.0, 12.0):
        window(b, lf, u, PL + 6.0, w=3.6, h=4.4, frame="w_wall_2")
        window(b, rt, u, PL + 6.0, w=3.6, h=4.4, frame="w_wall_2", glow=True)
    yr = hip_roof(b, x0, x1, z0, z1, wy + PL, 6.8, "rf_slate", over=1.9)
    for x in (-8.0, 8.0):
        dormer(b, x, 4.6, wy + PL + (6.8 / 9.0) * 2.4, 3.8, z0 + 2.4, 3.6, "rf_slate")
    smoke = chimney(b, 5.0, 12.0, wy + PL + 2.0, wy + PL + 8.8)
    return lot(b, W, D, wy + PL + 8.8, "mid", ["PineVillage", "SummitLodge"], [smoke], role="a plastered hip-roof house with two dormers: slate-blue roof, ochre walls", ridge="parallel", roof_colour="rf_slate")


@recipe
def bakery36():
    b = L.new("SP_Lot_Bakery36")
    W, D = 36.0, 21.0
    pad(b, W, D)
    x0, x1, z0, z1 = -15.0, 15.0, 1.0, 19.0
    base_h, wy = 5.0, 7.0
    # a stone ground storey with big arched shop windows, a plastered upper storey
    box(b, V(0, (base_h - 1.5) / 2, (z0 + z1) / 2), (x1 - x0 + 0.6, base_h + 1.5, z1 - z0 + 0.6), {"side": "s_stone", "top": "s_stone_lt", "skip_bottom": True})
    snow_skirt(b, x0 - 0.3, x1 + 0.3, z0 - 0.3, z1 + 0.3, base_h)
    fr, bk, lf, rt = WallFrame("z", z0, -1), WallFrame("z", z1, 1), WallFrame("x", x0, -1), WallFrame("x", x1, 1)
    for wf, (u0, u1) in ((fr, (x0, x1)), (bk, (x0, x1)), (lf, (z0, z1)), (rt, (z0, z1))):
        wall_panel(b, wf, u0, u1, base_h, base_h + wy, "storeys", ("w_wall_2", "m_wood_2", 1))
    for u in (-9.0, 0.0, 9.0):
        window(b, fr, u, base_h + 3.8, w=3.6, h=3.8, glow=(u != 0.0), frame="m_wood_2", shutter="s_paleblue")
    # shop windows in the stone: wide honey panes with a canvas awning in forest green
    for u in (-9.0, 8.0):
        wf = fr
        wf.box(b, u, 2.9, 9.4, 4.4, 0.0, 0.5, {"side": "m_wood_2", "top": "m_wood_2"})
        b.face([wf.P(u - 4.0, 1.4, 0.55), wf.P(u + 4.0, 1.4, 0.55), wf.P(u + 4.0, 4.4, 0.55), wf.P(u - 4.0, 4.4, 0.55)], "honey_glow", wf.n)
        wf.box(b, u, 2.9, 0.4, 3.2, 0.5, 0.65, {"side": "m_wood_2"})
    door(b, fr, 0.0, w=4.4, h=6.0, y0=PL, frame="m_wood_2")
    steps(b, fr, 0.0, 6.0)
    # awning: a sloped canvas with a snow lid, on two posts to the ground
    b.face([V(-13.0, 7.6, z0 - 0.2), V(13.0, 7.6, z0 - 0.2), V(13.0, 5.8, z0 - 4.2), V(-13.0, 5.8, z0 - 4.2)], "rf_forest", V(0, 1, -1.5))
    b.face([V(-13.0, 7.9, z0 - 0.2), V(13.0, 7.9, z0 - 0.2), V(13.0, 6.1, z0 - 3.6), V(-13.0, 6.1, z0 - 3.6)], "s_half", V(0, 1, -1.5))
    b.face([V(-13.0, 5.8, z0 - 4.2), V(13.0, 5.8, z0 - 4.2), V(13.0, 5.1, z0 - 4.2), V(-13.0, 5.1, z0 - 4.2)], "rf_forest", V(0, 0, -1))
    for x in (-13.0, 13.0):
        box(b, V(x, 2.7, z0 - 4.0), (0.7, 6.0, 0.7), {"side": "m_wood_2", "skip_bottom": True})
        snow_ring(b, x, z0 - 4.0, 1.8, 0.8, 0.7)
    yr = gable_roof(b, "x", x0, x1, z0, z1, base_h + wy, 5.2, "rf_slate", over_e=2.0, snow=0.9, gable_wall="w_wall_2")
    s1 = chimney(b, -9.0, 14.0, base_h + wy, base_h + wy + 8.0)
    s2 = chimney(b, 9.0, 14.0, base_h + wy + 0.5, base_h + wy + 7.6)
    return lot(b, W, D, base_h + wy + 7.4, "low", ["PineVillage", "SummitLodge"], [s1, s2], shop=True, role="a stone-based bakery: two arched-looking shop windows, forest awning, slate roof and two chimneys", ridge="parallel", roof_colour="rf_slate")


@recipe
def shed_mono24():
    b = L.new("SP_Lot_ShedMono24")
    W, D = 24.0, 18.0
    pad(b, W, D)
    x0, x1, z0, z1 = -10.0, 10.0, 1.5, 15.5
    h_lo, h_hi = 5.8, 9.8
    box(b, V(0, (PL - 1.5) / 2, (z0 + z1) / 2), (x1 - x0 + 0.6, PL + 1.5, z1 - z0 + 0.6), {"side": "s_stone", "top": "s_stone_lt", "skip_bottom": True})
    snow_skirt(b, x0 - 0.3, x1 + 0.3, z0 - 0.3, z1 + 0.3, PL)
    # a mono-pitch shed: low front wall, tall back wall, a single sloped roof falling toward the road
    fr, bk, lf, rt = WallFrame("z", z0, -1), WallFrame("z", z1, 1), WallFrame("x", x0, -1), WallFrame("x", x1, 1)
    wall_panel(b, fr, x0, x1, PL, PL + h_lo, "board", ("m_wood_2", "s_weather"))
    wall_panel(b, bk, x0, x1, PL, PL + h_hi, "plain", ("m_wood_2",))
    for wf, sgn in ((lf, -1), (rt, 1)):
        xx = x0 if sgn < 0 else x1
        pts = [V(xx, PL, z0), V(xx, PL, z1), V(xx, PL + h_hi, z1), V(xx, PL + h_lo, z0)]
        b.face(pts, "m_wood_2", V(sgn, 0, 0))
    ye0, ye1 = PL + h_lo, PL + h_hi
    oe = 1.8
    slope = (ye1 - ye0) / (z1 - z0)
    za, zb = z0 - oe, z1 + 1.0
    ya, yb = ye0 - slope * oe, ye1 + slope * 1.0
    tt = 0.7
    b.face([V(x0 - 1.0, ya, za), V(x1 + 1.0, ya, za), V(x1 + 1.0, yb, zb), V(x0 - 1.0, yb, zb)], "rf_cream", V(0, 1, -slope))
    b.face([V(x0 - 1.0, ya, za), V(x1 + 1.0, ya, za), V(x1 + 1.0, ya - tt, za), V(x0 - 1.0, ya - tt, za)], "m_wood_2", V(0, 0, -1))
    b.face([V(x0 - 1.0, yb, zb), V(x1 + 1.0, yb, zb), V(x1 + 1.0, yb - tt, zb), V(x0 - 1.0, yb - tt, zb)], "m_wood_2", V(0, 0, 1))
    for s_ in (-1, 1):
        b.face([V(s_ * (x1 + 1.0), ya, za), V(s_ * (x1 + 1.0), yb, zb), V(s_ * (x1 + 1.0), yb - tt, zb), V(s_ * (x1 + 1.0), ya - tt, za)], "m_wood_2", V(s_, 0, 0))
    b.face([V(x0 - 1.0, ya - tt, za), V(x1 + 1.0, ya - tt, za), V(x1 + 1.0, ye0 - tt, z0), V(x0 - 1.0, ye0 - tt, z0)], "m_wood_2", V(0, -1, 0))
    sn = 0.55
    b.face([V(x0 - 0.4, ya + 0.0 + sn + slope * 1.2, za + 1.2), V(x1 + 0.4, ya + sn + slope * 1.2, za + 1.2), V(x1 + 0.4, yb + sn - 0.2, zb - 0.6), V(x0 - 0.4, yb + sn - 0.2, zb - 0.6)], "s_lit", V(0, 1, -slope))
    b.face([V(x0 - 0.4, ya + slope * 1.2, za + 1.2), V(x1 + 0.4, ya + slope * 1.2, za + 1.2), V(x1 + 0.4, ya + sn + slope * 1.2, za + 1.2), V(x0 - 0.4, ya + sn + slope * 1.2, za + 1.2)], "s_half", V(0, 0, -1))
    # wide barn-style double door and a small window
    door(b, fr, -2.5, w=8.0, h=4.8, frame="m_wood_1", panel="m_wood_1")
    box(b, V(-2.5, PL + 2.4, z0 - 0.7), (0.4, 4.8, 0.3), {"side": "m_wood_2"})
    window(b, fr, 6.8, PL + 3.4, w=2.4, h=2.2, glow=True)
    window(b, lf, 8.0, PL + 3.6, w=2.4, h=2.2)
    smoke = chimney(b, 6.5, 12.0, PL + h_hi - 1.0, PL + h_hi + 3.6, w=2.0)
    return lot(b, W, D, PL + h_hi + 3.6, "low", ["PineVillage", "SkiLiftRidge", "FrozenLake"], [smoke], role="a mono-pitch shed: a low front under a single sloped cream roof, barn doors", ridge="mono", roof_colour="rf_cream")


@recipe
def duplex36():
    b = L.new("SP_Lot_Duplex36")
    W, D = 36.0, 21.0
    pad(b, W, D)
    z0, z1 = 1.0, 19.0
    halves = ((-16.0, -0.5, 9.4, "w_roof_1", "m_wood_1", 6.6), (0.5, 16.0, 11.6, "rf_forest", "s_ochre", 7.0))  # two bodies with different eaves, roofs, walls
    smokes = []
    for k, (x0, x1, wy, roof, wall, rise) in enumerate(halves):
        style = "log" if k == 0 else "plain"
        tones = ("m_wood_1", "m_wood_2") if k == 0 else (wall,)
        fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, style, tones, wy)
        xc = (x0 + x1) / 2
        door(b, fr, xc - 3.4 if k == 0 else xc + 3.4)
        steps(b, fr, xc - 3.4 if k == 0 else xc + 3.4, 6.0)
        porch(b, fr, xc - 3.4 if k == 0 else xc + 3.4, 7.0, 3.0, 8.0 if k == 0 else 8.2, roof)
        window(b, fr, xc + 3.4 if k == 0 else xc - 3.4, PL + 4.4, h=4.2, glow=(k == 1), shutter="m_wood_2" if k == 1 else "rf_forest")
        if k == 1:
            window(b, fr, xc - 3.4, PL + 8.8, w=3.4, h=3.2, frame="w_wall_2")
            window(b, fr, xc + 3.4, PL + 8.8, w=3.4, h=3.2, frame="w_wall_2", glow=True)
        window(b, lf if k == 0 else rt, 8.0, PL + 5.0)
        gable_roof(b, "z", z0, z1, x0, x1, wy + PL, rise, roof, gable_wall="s_board" if k == 0 else "w_wall_2", over_e=1.6, snow=0.6)
        smokes.append(chimney(b, x0 + 3.0 if k == 0 else x1 - 3.0, 12.5, wy + PL + 2.0, wy + PL + rise + 2.8))
    return lot(b, W, D, 21.0, "mid", ["PineVillage", "SummitLodge"], smokes, role="a duplex: two bodies under their own gables, berry and forest roofs, eaves 2 studs apart", ridge="across", roof_colour="w_roof_1+rf_forest")


@recipe
def inn48():
    b = L.new("SP_Lot_Inn48")
    W, D = 48.0, 22.0
    pad(b, W, D)
    x0, x1, z0, z1 = -20.0, 20.0, 1.0, 20.0
    wy = 22.5
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "storeys", ("w_wall_2", "m_wood_2", 3), wy, plinth_sw="s_stone")
    # half-timber upper storeys with a stone ground floor read through plinth + a darker lower band
    for u in (-14.0, -4.0, 6.0, 15.0):
        window(b, fr, u, PL + 4.4, w=3.8, h=4.4, glow=(u in (-4.0, 15.0)), frame="m_wood_2", sill=False)
        window(b, fr, u, PL + 12.0, w=3.8, h=4.2, glow=(u in (-14.0, 6.0)), frame="m_wood_2", shutter="w_roof_1")
        window(b, fr, u, PL + 19.4, w=3.6, h=4.0, glow=(u in (-4.0, 15.0)), frame="m_wood_2", sill=False)
    door(b, fr, -9.0, w=4.8, h=7.2)
    steps(b, fr, -9.0, 7.0)
    porch(b, fr, -9.0, 9.0, 3.6, 8.8, "rf_slate")
    # a balcony on the first floor over the entrance bay: deck, rails, posts to the ground
    wf = fr
    wf.box(b, 10.0, PL + 8.0, 12.0, 0.6, 0.0, 3.4, {"side": "m_wood_2", "top": "m_wood_1"})
    for u in (4.2, 15.8):
        wf.box(b, u, 4.2, 0.7, 9.0, 3.0, 3.5, {"side": "m_wood_2"})
    wf.box(b, 10.0, PL + 9.2, 12.0, 0.45, 3.0, 3.4, {"side": "m_wood_2", "top": "s_half"})
    for u in (4.2, 10.0, 15.8):
        wf.box(b, u, PL + 8.6, 0.45, 1.5, 3.0, 3.4, {"side": "m_wood_2"})
    for wf2, uu in ((lf, 8.0), (lf, 15.0), (rt, 8.0), (rt, 15.0)):
        window(b, wf2, uu, PL + 12.0, w=3.6, h=4.2, glow=(uu == 8.0), frame="m_wood_2", sill=False)
        window(b, wf2, uu, PL + 19.4, w=3.6, h=4.0, frame="m_wood_2", sill=False)
    yr = gable_roof(b, "x", x0, x1, z0, z1, wy + PL, 6.8, "rf_slate", over_e=2.2, snow=0.8, gable_wall="w_wall_2")
    for x in (-12.0, 12.0):
        dormer(b, x, 5.0, wy + PL + 0.6, 4.2, z0 + 1.8, 3.8, "w_roof_1")
    s1 = chimney(b, -15.0, 14.0, wy + PL + 1.0, wy + PL + 8.8)
    s2 = chimney(b, 14.0, 14.0, wy + PL + 1.0, wy + PL + 8.4)
    return lot(b, W, D, wy + PL + 9.2, "tall", ["PineVillage"], [s1, s2], role="the three-storey inn (30-34 high): half-timber storeys, a balcony, slate roof with berry dormers, two chimneys", ridge="parallel", roof_colour="rf_slate")


@recipe
def hall48():
    b = L.new("SP_Lot_Hall48")
    W, D = 48.0, 24.0
    pad(b, W, D)
    x0, x1, z0, z1 = -20.0, 20.0, 1.0, 22.0
    wy = 16.0
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("m_wood_1", "m_wood_2"), wy, plinth_sw="s_stone_dk")
    # a high hall: tall glazed bays, a stone entrance and a broad ridge across the road over the centre
    for u in (-15.0, -7.0, 7.0, 15.0):
        window(b, fr, u, PL + 8.4, w=3.8, h=8.6, glow=(u in (-7.0, 15.0)), frame="m_wood_2")
    door(b, fr, 0.0, w=5.4, h=8.4, frame="s_stone_lt")
    steps(b, fr, 0.0, 8.0, n=3)
    porch(b, fr, 0.0, 10.0, 3.8, 10.0, "rf_shingle")
    for u in (8.0, 16.0):
        window(b, lf, u, PL + 8.0, w=3.6, h=7.0, glow=True, frame="m_wood_2")
        window(b, rt, u, PL + 8.0, w=3.6, h=7.0, frame="m_wood_2")
    yr = gable_roof(b, "x", x0, x1, z0, z1, wy + PL, 7.6, "rf_shingle", over_e=2.2, snow=0.85, gable_wall="s_board")
    s1 = chimney(b, -13.0, 16.0, wy + PL + 1.0, wy + PL + 9.6)
    s2 = chimney(b, 13.0, 16.0, wy + PL + 1.0, wy + PL + 9.6)
    return lot(b, W, D, wy + PL + 10.8, "mid", ["PineVillage", "SummitLodge"], [s1, s2], role="a log hall: tall glazed bays, a stone entrance, a long shingle roof, two chimneys", ridge="parallel", roof_colour="rf_shingle")


def yard(name, W, with_cabin):
    rng = rng_of(name)
    b = L.new(name)
    D = 18.0
    pad(b, W, D, z0=0.0)
    hw = W / 2
    # a fenced yard: front fence with a gate gap, side fences, collars on every post
    gate = -3.0 if W < 30 else 5.0
    xs_front = [-hw + 1.0 + i * (W - 2.0) / (3 if W < 30 else 4) for i in range(4 if W < 30 else 5)]
    posts = [(x, 0.8) for x in xs_front] + [(sx, z) for sx in (-hw + 1.0, hw - 1.0) for z in (8.8, 16.8)]
    for (x, z) in posts:
        frustum(b, x, -0.3, z, 0.9, 1.7, 0.85, 4, 0.78, "s_half", top="s_lit")
        box(b, V(x, 1.9, z), (0.6, 3.6, 0.6), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    for i in range(len(xs_front) - 1):
        if abs((xs_front[i] + xs_front[i + 1]) / 2 - gate) < 5.5 and i == (1 if W < 30 else 2):
            continue
        for y in (1.6, 2.7):
            box(b, V((xs_front[i] + xs_front[i + 1]) / 2, y, 0.8), ((xs_front[i + 1] - xs_front[i]) + 0.2, 0.4, 0.4), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    for sx in (-hw + 1.0, hw - 1.0):
        for z0_ in (0.8, 8.8):
            for y in (1.6, 2.7):
                box(b, V(sx, y, z0_ + 4.0), (0.4, 0.4, 8.2), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    # woodpile, sled, a lantern post and a small shed if there is room
    wood_pile(b, -hw + 5.0, 14.0, 5.0)
    box(b, V(hw - 6.0, 0.8, 7.0), (1.4, 0.4, 5.4), {"side": "w_roof_1", "top": "w_roof_1", "skip_bottom": True})  # a sled: two runners, a bed
    box(b, V(hw - 6.0 - 0.9, 0.35, 7.0), (0.3, 0.5, 5.8), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(hw - 6.0 + 0.9, 0.35, 7.0), (0.3, 0.5, 5.8), {"side": "m_wood_2", "skip_bottom": True})
    lx, lz = gate + 3.0 if W < 30 else -4.0, 2.2
    frustum(b, lx, -0.3, lz, 0.9, 1.8, 0.9, 4, 0.78, "s_half", top="s_lit")
    cyl(b, V(lx, 0.4, lz), 11.0, 0.4, 5, "m_wood_2", r_top=0.34)
    box(b, V(lx, 11.9, lz), (1.8, 1.6, 1.8), {"side": "honey_glow", "top": "m_wood_2", "skip_bottom": True})
    box(b, V(lx, 12.9, lz), (2.4, 0.5, 2.4), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    smokes = []
    if with_cabin:
        x0, x1, z0, z1 = 3.0, W / 2 - 3.0, 9.0, 17.0
        fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("m_wood_1", "m_wood_2"), 7.0)
        door(b, fr, (x0 + x1) / 2 - 1.5, w=3.4, h=6.0)
        window(b, fr, (x0 + x1) / 2 + 3.4, PL + 4.0, w=2.6, h=2.8, glow=True)
        gable_roof(b, "x", x0, x1, z0, z1, 7.0 + PL, 3.6, "rf_slate", over_e=1.4, snow=0.9, gable_wall="s_board")
        smokes.append(chimney(b, x1 - 2.0, z1 - 2.5, 7.0 + PL, 7.0 + PL + 6.0, w=1.8))
    return lot(b, W, D, 15.0, "low", ["PineVillage", "SkiLiftRidge", "SummitLodge"], smokes, role="a set-back courtyard lot: a fenced yard with a woodpile, a sled and a lantern" + (" and a small cabin" if with_cabin else ""), setback="8 to 16 studs behind the frontage", family="Lot")


@recipe
def yard24():
    return yard("SP_Lot_Yard24", 24.0, False)


@recipe
def yard36():
    return yard("SP_Lot_Yard36", 36.0, True)


# ================================================================ placement helper (build a part in its own frame, then move it)
class placed:
    """with placed(b, dx, dy, dz, yaw, mirror): build in a local frame; on exit the new geometry is mirrored in x (an authored variant),
    yawed about +Y (radians) and moved. Everything the builder gained inside the block is transformed."""

    def __init__(self, b, dx=0.0, dy=0.0, dz=0.0, yaw=0.0, mirror=False):
        self.b, self.dx, self.dy, self.dz, self.yaw, self.mirror = b, dx, dy, dz, yaw, mirror

    def __enter__(self):
        self.n0, self.f0 = len(self.b.bm.verts), len(self.b.bm.faces)
        return self.b

    def __exit__(self, *a):
        bm = self.b.bm
        bm.verts.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        cs, sn = math.cos(self.yaw), math.sin(self.yaw)
        for i in range(self.n0, len(bm.verts)):
            v = bm.verts[i]
            x, y, z = v.co.x, v.co.z, -v.co.y
            if self.mirror:
                x = -x
            x, z = x * cs + z * sn, -x * sn + z * cs
            v.co = Vector((x + self.dx, -(z + self.dz), y + self.dy))
        if self.mirror:
            bmesh.ops.reverse_faces(bm, faces=[bm.faces[i] for i in range(self.f0, len(bm.faces))])
        return False


def fence_run(b, x0, x1, z, step=6.0, gate=None, rails=2, h=3.4):
    """A rail fence along x at depth z from x0 to x1 with a snow collar on every post; gate = (xa, xb) leaves a gap."""
    n = max(1, int(round((x1 - x0) / step)))
    xs = [x0 + (x1 - x0) * i / n for i in range(n + 1)]
    for x in xs:
        frustum(b, x, -0.3, z, 0.9, 1.7, 0.85, 4, 0.78, "s_half", top="s_lit")
        box(b, V(x, h / 2 + 0.2, z), (0.6, h + 0.4, 0.6), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    for i in range(n):
        xm = (xs[i] + xs[i + 1]) / 2
        if gate and gate[0] <= xm <= gate[1]:
            continue
        for r in range(rails):
            box(b, V(xm, h * (0.5 + 0.38 * r), z), (xs[i + 1] - xs[i] + 0.2, 0.4, 0.4), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})


def fence_run_z(b, x, z0, z1, step=6.0, rails=2, h=3.4):
    n = max(1, int(round((z1 - z0) / step)))
    zs = [z0 + (z1 - z0) * i / n for i in range(n + 1)]
    for z in zs:
        frustum(b, x, -0.3, z, 0.9, 1.7, 0.85, 4, 0.78, "s_half", top="s_lit")
        box(b, V(x, h / 2 + 0.2, z), (0.6, h + 0.4, 0.6), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    for i in range(n):
        for r in range(rails):
            box(b, V(x, h * (0.5 + 0.38 * r), (zs[i] + zs[i + 1]) / 2), (0.4, 0.4, zs[i + 1] - zs[i] + 0.2), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})


# ================================================================ S1: lodge pieces
def lodge_wing(name, flip, roof, note):
    """A lodge wing: a stone ground storey, two log storeys with a long balcony, a gable roof along the road and a cross-gable entrance bay at
    one end (flip = +1 puts it at +x, -1 at -x), so the A and B variants are authored left and right versions."""
    b = L.new(name)
    W, D = 44.0, 22.0
    pad(b, W, D)
    x0, x1, z0, z1 = -20.0, 20.0, 1.0, 20.0
    base_h, wy = 7.0, 20.5
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("s_stone", "s_stone_lt"), base_h, plinth_sw="s_stone_dk")
    for wf, (u0, u1) in ((fr, (x0, x1)), (bk, (x0, x1)), (lf, (z0, z1)), (rt, (z0, z1))):
        wall_panel(b, wf, u0, u1, base_h, wy, "log", ("m_wood_1", "m_wood_2"))
    fr.box(b, 0.0, base_h + 0.2, x1 - x0, 0.6, 0.0, 0.5, {"side": "s_stone_lt", "top": "s_half"})  # a stone ledge under the timber storeys
    ex = flip * 14.0  # the entrance bay
    for u in (-16.0, -7.0, 2.0, 11.0):
        if abs(u - ex) < 8.0:
            continue
        window(b, fr, u, 3.6, w=3.6, h=4.0, frame="s_stone_lt", sill=False)
    for u in (-17.0, -9.0, -1.0, 7.0, 15.0):
        if abs(u - ex) < 8.0:
            continue
        window(b, fr, u, base_h + 4.0, w=3.6, h=4.2, glow=(u in (-9.0, 7.0)), frame="m_wood_2")
        window(b, fr, u, base_h + 10.6, w=3.6, h=4.2, glow=(u in (-17.0, -1.0, 15.0)), frame="m_wood_2", shutter="rf_forest" if u in (-9.0, 7.0) else None, sill=False)
    # the balcony along the front at the first timber storey: deck on posts that reach the ground, a rail
    by = base_h + 7.2
    bx0, bx1 = (-19.0, 3.0) if flip > 0 else (-3.0, 19.0)
    bxc = (bx0 + bx1) / 2
    fr.box(b, bxc, by, bx1 - bx0, 0.6, 0.0, 3.6, {"side": "m_wood_2", "top": "m_wood_1"})
    for u in (bx0 + 0.6, bxc, bx1 - 0.6):
        fr.box(b, u, (by - 0.3) / 2, 0.8, by + 0.3, 2.8, 3.5, {"side": "m_wood_2"})
    fr.box(b, bxc, by + 2.2, bx1 - bx0, 0.5, 3.0, 3.5, {"side": "m_wood_2", "top": "s_half"})
    for u in (bx0 + 0.6, bxc, bx1 - 0.6):
        fr.box(b, u, by + 1.2, 0.5, 2.0, 3.0, 3.5, {"side": "m_wood_2"})
    gable_roof(b, "x", x0, x1, z0, z1, wy + PL, 7.0, roof, over_e=2.2, snow=0.8, gable_wall="s_board")
    # entrance bay: a cross-gable block with a glazed gable end, a stone door surround and steps
    ew = 12.0
    eb = WallFrame("z", z0 - 3.8, -1)
    box(b, V(ex, (wy + 3.0) / 2 + 0.2, (z0 - 3.8 + z0 + 6.0) / 2), (ew, wy + 3.0 + 0.4, 9.8 + 0.0), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True, "skip_top": True})
    wall_panel(b, eb, ex - ew / 2, ex + ew / 2, PL, wy + 3.0, "log", ("m_wood_1", "m_wood_2"))
    door(b, eb, ex, w=5.0, h=8.0, frame="s_stone_lt")
    steps(b, eb, ex, 8.0, n=2)
    window(b, eb, ex - 3.6, base_h + 9.0, w=2.4, h=4.4, glow=True, frame="m_wood_2", sill=False)
    window(b, eb, ex + 3.6, base_h + 9.0, w=2.4, h=4.4, frame="m_wood_2", sill=False)
    gable_roof(b, "z", z0 - 3.8, z0 + 6.0, ex - ew / 2, ex + ew / 2, wy + 3.0 + PL, 6.8, roof, over_e=1.6, over_g=1.0, snow=0.7, gable_wall="s_board", gable_ends=(True, False))
    b.face([V(ex - 2.6, wy + 3.0 + PL + 1.6, z0 - 4.9), V(ex + 2.6, wy + 3.0 + PL + 1.6, z0 - 4.9), V(ex + 0.0 + 0.2, wy + 3.0 + PL + 5.4, z0 - 4.9), V(ex - 0.2, wy + 3.0 + PL + 5.4, z0 - 4.9)], "honey_glow", V(0, 0, -1))
    s1 = chimney(b, -flip * 12.0, 15.0, wy + PL + 1.5, wy + PL + 8.6)
    s2 = chimney(b, -flip * 2.0, 15.0, wy + PL + 3.0, wy + PL + 9.0)
    return lot(b, W, D, wy + PL + 9.8, "tall", ["SummitLodge"], [s1, s2], role=note, variant=name[-1], ridge="parallel (entrance bay across)", roof_colour=roof)


@recipe
def lodge_wing_a():
    return lodge_wing("SP_Lot_LodgeWing_A", 1, "w_roof_1", "the left lodge wing: stone ground storey, two log storeys, a long balcony and a cross-gable entrance bay at its +x end; berry roof")


@recipe
def lodge_wing_b():
    return lodge_wing("SP_Lot_LodgeWing_B", -1, "rf_forest", "the right lodge wing, authored as its own left/right variant: entrance bay at its -x end; forest-green roof")


@recipe
def annex36():
    b = L.new("SP_Lot_Annex36")
    W, D = 36.0, 20.0
    pad(b, W, D)
    x0, x1, z0, z1 = -15.0, 15.0, 1.0, 18.0
    wy = 11.0
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("s_stone", "s_stone_lt"), wy, plinth_sw="s_stone_dk")
    for u in (-9.0, 0.0, 9.0):
        window(b, fr, u, PL + 5.6, w=3.6, h=4.6, glow=(u != 0.0), frame="s_stone_lt")
    door(b, fr, -3.0 + 0.0, w=4.6, h=7.2, frame="s_stone_lt")
    steps(b, fr, -3.0, 6.6, n=2)
    window(b, lf, 9.0, PL + 5.6, w=3.4, h=4.4, frame="s_stone_lt")
    window(b, rt, 9.0, PL + 5.6, w=3.4, h=4.4, glow=True, frame="s_stone_lt")
    gable_roof(b, "x", x0, x1, z0, z1, wy + PL, 5.6, "rf_forest", over_e=2.0, snow=0.9, gable_wall="s_stone_lt")
    # a lantern bracket beside the door, honey glass
    box(b, V(1.8, PL + 7.0, z0 - 1.0), (0.4, 0.4, 1.6), {"side": "m_wood_2"})
    box(b, V(1.8, PL + 6.2, z0 - 1.7), (1.0, 1.4, 1.0), {"side": "honey_glow", "top": "m_wood_2", "skip_bottom": True})
    s1 = chimney(b, 10.0, 12.0, wy + PL, wy + PL + 8.0)
    return lot(b, W, D, wy + PL + 8.6, "mid", ["SummitLodge"], [s1], role="the stone annex beside the lodge hall: coursed stone walls, forest-green roof, a lantern at the door", ridge="parallel", roof_colour="rf_forest")


# ================================================================ S1: landmarks
def clock_face(b, wf, u, y, r=4.2):
    """A round clock: a cream disc, a dark rim, four ticks and two hands (10 past 10), flat on a wall (read from outside)."""
    ring = [(math.cos(2 * math.pi * k / 12) * r, math.sin(2 * math.pi * k / 12) * r) for k in range(12)]
    ring_o = [(math.cos(2 * math.pi * k / 12) * (r + 0.7), math.sin(2 * math.pi * k / 12) * (r + 0.7)) for k in range(12)]
    b.face([wf.P(u + x, y + z, 0.4) for x, z in ring], "m_sign", wf.n)
    for k in range(12):
        k2 = (k + 1) % 12
        b.face([wf.P(u + ring[k][0], y + ring[k][1], 0.4), wf.P(u + ring[k2][0], y + ring[k2][1], 0.4), wf.P(u + ring_o[k2][0], y + ring_o[k2][1], 0.3), wf.P(u + ring_o[k][0], y + ring_o[k][1], 0.3)], "m_wood_2", wf.n)
    for (tx, ty) in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        c = (u + tx * (r - 0.8), y + ty * (r - 0.8))
        b.face([wf.P(c[0] - 0.3, c[1] - 0.3, 0.5), wf.P(c[0] + 0.3, c[1] - 0.3, 0.5), wf.P(c[0] + 0.3, c[1] + 0.3, 0.5), wf.P(c[0] - 0.3, c[1] + 0.3, 0.5)], "m_wood_2", wf.n)
    for (ang, ln, wd) in ((math.radians(60), r * 0.55, 0.32), (math.radians(30), r * 0.8, 0.22)):  # hour hand toward 10, minute toward 2
        dx, dy = math.cos(ang) * ln, math.sin(ang) * ln
        px, py = -math.sin(ang) * wd, math.cos(ang) * wd
        b.face([wf.P(u - px, y - py, 0.55), wf.P(u + dx - px, y + dy - py, 0.55), wf.P(u + dx + px, y + dy + py, 0.55), wf.P(u + px, y + py, 0.55)], "m_black", wf.n)


@recipe
def clock_tower():
    b = L.new("SP_LM_BellTower")
    W, D = 36.0, 30.0
    rng = rng_of("SP_LM_BellTower")
    pad(b, W, D)
    fence_run(b, -16.0, 16.0, 1.2, step=6.4, gate=(-3.5, 3.5))
    fence_run_z(b, -16.0, 1.2, 28.0, step=6.0)
    fence_run_z(b, 16.0, 1.2, 28.0, step=6.0)
    for (x, z, h) in ((-12.5, 24.0, 22.0), (12.5, 24.0, 20.0)):
        conifer(b, x, z, h, rng, tiers=4, sides=5, base_r=h * 0.2)
    cx, cz = 0.0, 15.0
    x0, x1, z0, z1 = -7.5, 7.5, 7.5, 22.5
    top1 = 26.0
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "board", ("s_board", "s_weather"), top1, plinth_sw="s_stone_dk")
    door(b, fr, 0.0, w=4.4, h=7.6)
    steps(b, fr, 0.0, 6.4, n=2)
    for u in (-4.6, 4.6):
        window(b, fr, u, 15.0, w=2.2, h=6.0, glow=(u > 0), frame="m_wood_2", sill=False)
    window(b, fr, 0.0, 21.0, w=2.2, h=4.4, frame="m_wood_2", sill=False)
    for wf in (lf, rt):
        window(b, wf, 15.0, 16.0, w=2.2, h=6.0, frame="m_wood_2", sill=False)
    frustum(b, cx, top1 - 0.6, cz, 3.6, 12.4, 8.5, 4, math.pi / 4, "rf_slate", bottom="m_wood_2")  # a pent skirt roof round the timber stage
    c0, c1 = 3.0 + top1, 3.0 + top1 + 15.0
    sx0, sx1, sz0, sz1 = -5.9, 5.9, cz - 5.9, cz + 5.9
    sfr, sbk, slf, srt = WallFrame("z", sz0, -1), WallFrame("z", sz1, 1), WallFrame("x", sx0, -1), WallFrame("x", sx1, 1)
    for wf, (u0, u1) in ((sfr, (sx0, sx1)), (sbk, (sx0, sx1)), (slf, (sz0, sz1)), (srt, (sz0, sz1))):
        wall_panel(b, wf, u0, u1, c0, c1, "plain", ("w_wall_2",))
        clock_face(b, wf, cz if wf.kind == "x" else 0.0, c0 + 7.4)
    for (qx, qz) in ((sx0, sz0), (sx1, sz0), (sx0, sz1), (sx1, sz1)):
        box(b, V(qx, (c0 + c1) / 2, qz), (1.0, c1 - c0 + 0.4, 1.0), {"side": "m_wood_2", "top": "m_wood_2", "skip_bottom": True})
    box(b, V(cx, c0 - 0.2, cz), (13.4, 0.8, 13.4), {"side": "m_wood_2", "top": "s_half", "skip_bottom": True})
    frustum(b, cx, c1, cz, 15.0, 10.2, 0.0, 8, math.pi / 8, lambda k, nx, nz: "s_paleblue" if (nx * LIGHT.x + nz * LIGHT.z) > 0.15 else "rf_slate", bottom="m_wood_2")
    box(b, V(cx, c1 + 0.4, cz), (13.0, 0.8, 13.0), {"side": "m_wood_2", "top": "m_wood_2", "skip_bottom": True})
    sphere(b, V(cx, c1 + 15.7, cz), (1.3, 1.3, 1.3), ["w_accent_1", "w_accent_1", "bunt_honey"], subdiv=1)
    cyl(b, V(cx, c1 + 16.5, cz), 2.6, 0.3, 4, "w_accent_1", r_top=0.05)
    return lm_finish(b, W, D, c1 + 19.2, ["PineVillage"], read="the clock tower: timber base, cream clock stage with a face toward the road, slate-blue spire, gold finial, on a fenced green with two firs", variant="clock tower, 64 high")


def small_chalet(b, w, d, wall_h, rise, roof, style, tones, ridge_x, door_u, glow=0):
    """A small chalet in a local frame (x -w/2..w/2, z 1..d): used by the terrace chalets."""
    x0, x1, z0, z1 = -w / 2, w / 2, 1.0, d
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, style, tones, wall_h)
    door(b, fr, door_u, w=3.6, h=6.6)
    steps(b, fr, door_u, 5.0, n=2)
    porch(b, fr, door_u, 6.0, 2.6, 8.4, roof, rise=1.0)
    for u in (-w / 2 + 3.6, w / 2 - 3.6):
        if abs(u - door_u) > 4.5:
            window(b, fr, u, PL + 5.0, w=3.2, h=4.0, glow=bool(glow), frame="m_wood_2", sill=True)
    window(b, lf, (z0 + z1) / 2, PL + 5.0, w=3.0, h=4.0, frame="m_wood_2", sill=False)
    window(b, rt, (z0 + z1) / 2, PL + 5.0, w=3.0, h=4.0, glow=True, frame="m_wood_2", sill=False)
    if ridge_x:
        gable_roof(b, "x", x0, x1, z0, z1, wall_h + PL, rise, roof, over_e=1.7, snow=0.9, gable_wall="s_board")
    else:
        gable_roof(b, "z", z0, z1, x0, x1, wall_h + PL, rise, roof, over_e=1.5, snow=0.9, gable_wall="s_board")
    return chimney(b, w / 2 - 3.0, z1 - 2.5, wall_h + PL, wall_h + PL + 7.0, w=1.9)


@recipe
def terrace_chalets():
    b = L.new("SP_LM_ChaletCluster")
    W, D = 48.0, 32.0
    rng = rng_of("SP_LM_ChaletCluster")
    pad(b, W, D)
    # four chalets climbing a bank: eaves 14, 18, 20 and 26, on stepped terraces with stone retaining walls
    spec = (
        (-13.0, 4.0, 0.0, 16.0, 11.0, "rf_forest", "log", ("m_wood_1", "m_wood_2"), True, -4.0),
        (14.0, 5.0, 4.0, 15.0, 12.0, "w_roof_1", "board", ("s_board", "s_weather"), False, 3.0),
        (-12.0, 15.0, 6.0, 15.0, 11.0, "rf_slate", "plain", ("s_ochre",), True, 3.0),
        (4.0, 22.0, 12.0, 17.0, 9.0, "rf_shingle", "log", ("m_wood_2", "m_wood_1"), False, -3.0),
    )
    smokes = []
    for (cx, cz, y0, w, d, roof, style, tones, rx, du) in spec:
        if y0 > 0:  # the terrace under it: a stone retaining block with a snow top
            box(b, V(cx, (y0 - 0.5) / 2, cz + d / 2 - 0.2), (w + 3.0, y0 + 0.5, d + 3.0), {"side": "s_stone", "top": "s_half", "skip_bottom": True})
        with placed(b, cx, y0 + (0.25 if y0 > 0 else 0.0), cz):
            smokes.append(small_chalet(b, w, d, 12.4, 5.6 if rx else 6.4, roof, style, tones, rx, du, glow=1))
    # a stair of snow-capped stone steps climbing the bank between the terraces
    for k in range(6):
        box(b, V(0.5 + k * 0.2, 0.5 + k * 1.1, 6.0 + k * 2.6), (5.0, 1.1 + k * 1.1, 2.6), {"side": "s_stone_dk", "top": "s_half", "skip_bottom": True})
    fence_run(b, -22.0, 22.0, 0.6, step=7.3, gate=(-3.0, 3.0))
    for (x, z, h) in ((-21.0, 8.0, 24.0), (21.0, 12.0, 20.0)):
        conifer(b, x, z, h, rng, tiers=4, sides=5, base_r=h * 0.2)
    lm = lm_finish(b, W, D, 40.0, ["PineVillage"], sockets=lot_sockets(W, smokes[:2]), read="Terrace Chalets: four chalets climbing a bank, eaves 14, 18, 20 and 26, one shared fenced yard", variant="terrace chalets")
    return lm


# ---- the ski lift
def lift_wheel(b, x, y, z, r=2.2, w=1.0, sides=8):
    """A sheave: a wheel with its axis along z (the cable runs along x)."""
    tube(b, [V(x, y, z - w / 2), V(x, y, z + w / 2)], r, sides, "m_metal_dark", phase=math.pi / sides)
    tube(b, [V(x, y, z - w / 2 - 0.15), V(x, y, z + w / 2 + 0.15)], r * 0.4, sides, "m_metal")


def concrete_footing(b, x, z, w=9.0, h=3.2, sunk=2.0, skirt=True):
    box(b, V(x, (h - sunk) / 2, z), (w, h + sunk, w), {"side": "s_stone_lt", "top": "s_stone", "skip_bottom": True})
    if skirt:
        snow_skirt(b, x - w / 2, x + w / 2, z - w / 2, z + w / 2, h, out=3.2, y_out=0.4)


def lift_tower(name, kind):
    rng = rng_of(name)
    b = L.new(name)
    if kind == "A":  # a tall lattice tower on a rock outcrop
        H, bw = 72.0, 9.0
        for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            beam(b, V(sx * bw / 2, 3.2, sz * bw / 2), V(sx * 1.1, H, sz * 1.1), 1.0, 1.0, "m_metal_dark")
        for (y, f) in ((16.0, 0.74), (34.0, 0.52), (52.0, 0.3)):
            hw = bw / 2 * f + 0.4
            for (a, c) in (((-hw, y, -hw), (hw, y, -hw)), ((hw, y, -hw), (hw, y, hw)), ((hw, y, hw), (-hw, y, hw)), ((-hw, y, hw), (-hw, y, -hw))):
                beam(b, V(*a), V(*c), 0.5, 0.5, "m_metal")
        for (y0, y1, f0, f1) in ((3.2, 16.0, 1.0, 0.74), (16.0, 34.0, 0.74, 0.52)):  # X braces on the two faces across the cable
            for sz in (-1, 1):
                a = V(-bw / 2 * f0 - 0.0, y0, sz * bw / 2 * f0)
                c = V(bw / 2 * f1, y1, sz * bw / 2 * f1)
                beam(b, a, c, 0.4, 0.4, "m_metal")
        box(b, V(0, H + 0.6, 0), (3.0, 1.2, 15.0), {"side": "m_metal_dark", "top": "m_metal", "skip_bottom": True})  # the crossarm
        for sz in (-5.4, 5.4):
            lift_wheel(b, 0, H + 3.0, sz)
            box(b, V(0, H + 1.9, sz), (0.8, 1.6, 1.0), {"side": "m_metal_dark", "skip_bottom": True})
        concrete_footing(b, 0, 0, 12.0, 3.2)
        for (x, z, s_) in ((-6.0, 3.0, 5.0), (5.5, -4.0, 4.4), (-3.0, -6.5, 3.8), (6.5, 5.0, 3.6)):
            sphere(b, V(x, 1.0 + s_ * 0.2, z), (s_, s_ * 0.6, s_ * 0.85), ["rk_near_shade", "rk_near", "rk_near", "rk_near_lit"], subdiv=0, rng=rng, jitter=0.2)
        top = H + 5.2
    elif kind == "B":  # a tapered tubular mast
        H = 56.0
        tube(b, [V(0, -2.0, 0), V(0, 4.0, 0), V(0, H, 0)], [3.2, 2.7, 1.1], 6, ["m_metal", "m_metal_dark"], phase=0.3)
        for y, rr in ((12.0, 3.1), (30.0, 2.2)):
            tube(b, [V(0, y, 0), V(0, y + 0.8, 0)], rr + 0.5, 6, "m_metal_dark", phase=0.3)
        box(b, V(0, H + 0.5, 0), (2.6, 1.0, 13.0), {"side": "m_metal_dark", "top": "m_metal", "skip_bottom": True})
        for sz in (-4.6, 4.6):
            lift_wheel(b, 0, H + 2.8, sz)
            box(b, V(0, H + 1.7, sz), (0.8, 1.4, 1.0), {"side": "m_metal_dark", "skip_bottom": True})
        concrete_footing(b, 0, 0, 9.0, 3.0)
        top = H + 5.0
    else:  # C: a short H-frame on a slope: one footing stepped higher than the other
        H = 40.0
        for (sz, up) in ((-1, 0.0), (1, 3.4)):
            beam(b, V(0, 3.0 + up, sz * 7.0), V(0, H, sz * 4.2), 1.6, 1.6, "m_metal_dark")
            beam(b, V(-3.0, 3.0 + up, sz * 7.0), V(0, H - 6.0, sz * 4.4), 0.5, 0.5, "m_metal")
            beam(b, V(3.0, 3.0 + up, sz * 7.0), V(0, H - 6.0, sz * 4.4), 0.5, 0.5, "m_metal")
            concrete_footing(b, 0, sz * 7.0, 6.0, 3.0 + up, sunk=2.0 + up)
        box(b, V(0, H + 0.6, 0), (2.6, 1.2, 12.4), {"side": "m_metal_dark", "top": "m_metal", "skip_bottom": True})
        box(b, V(0, H - 11.0, 0), (1.0, 0.8, 9.6), {"side": "m_metal", "skip_bottom": True})
        for sz in (-3.4, 3.4):
            lift_wheel(b, 0, H + 3.0, sz)
        for (x, z, s_) in ((-5.0, 8.0, 4.4), (5.0, -8.0, 4.0), (4.5, 10.0, 3.2)):
            sphere(b, V(x, 1.0 + s_ * 0.2, z), (s_, s_ * 0.6, s_ * 0.85), ["rk_near_shade", "rk_near", "rk_near", "rk_near_lit"], subdiv=0, rng=rng, jitter=0.2)
        top = H + 5.2
    return unit(b, "LM", "near", "lift line 60+ from the road edge", authored=True, kind="lifttower", role=f"lift tower type {kind}: the cable runs along x, the crossarm along z; the cable rides over the sheaves at y = {top:.1f}", district=["SkiLiftRidge"], height=top, cable_height=round(top, 1), cable_axis="x", footing="concrete with a snow skirt, grounded in the slope")


@recipe
def lift_tower_a():
    return lift_tower("SP_LM_LiftTower_A", "A")


@recipe
def lift_tower_b():
    return lift_tower("SP_LM_LiftTower_B", "B")


@recipe
def lift_tower_c():
    return lift_tower("SP_LM_LiftTower_C", "C")


@recipe
def lift_base():
    b = L.new("SP_LM_LiftBase")
    W, D = 48.0, 28.0
    rng = rng_of("SP_LM_LiftBase")
    pad(b, W, D)
    # the base shed: coursed metal, a deep eave, a big dark opening where the chairs load, a bullwheel on a frame
    x0, x1, z0, z1 = -20.0, 2.0, 9.0, 24.0
    house_base(b, x0, x1, z0, z1, "board", ("m_metal", "s_stone_lt"), 12.0, plinth_sw="s_stone_dk")
    fr = WallFrame("z", z0, -1)
    b.face([fr.P(-14.0, PL, 0.5), fr.P(-4.0, PL, 0.5), fr.P(-4.0, PL + 8.4, 0.5), fr.P(-14.0, PL + 8.4, 0.5)], "m_metal_dark", fr.n)
    fr.box(b, -9.0, PL + 4.4, 11.6, 9.6, 0.0, 0.45, {"side": "rk_dark", "top": "rk_dark"})
    b.face([fr.P(-14.0, PL, 0.55), fr.P(-4.0, PL, 0.55), fr.P(-4.0, PL + 8.4, 0.55), fr.P(-14.0, PL + 8.4, 0.55)], "ice_void", fr.n)
    gable_roof(b, "x", x0, x1, z0, z1, 12.0 + PL, 4.0, "rf_slate", over_e=2.4, snow=0.9, gable_wall="s_stone_lt")
    # the bullwheel: a big wheel on two A-legs at the loading end, with the cable running off along +x
    wx, wy_, wz = 9.0, 14.0, 17.0
    for sz in (-1, 1):
        for sx in (-1, 1):
            beam(b, V(wx + sx * 4.4, 0.0, wz + sz * 2.4), V(wx + sx * 0.8, wy_, wz + sz * 1.2), 1.0, 1.0, "m_metal_dark")
    tube(b, [V(wx, wy_, wz - 1.8), V(wx, wy_, wz + 1.8)], 6.0, 12, "m_metal_dark", phase=0.2)
    tube(b, [V(wx, wy_, wz - 2.0), V(wx, wy_, wz + 2.0)], 2.2, 8, "m_metal")
    concrete_footing(b, wx, wz, 11.0, 1.6)
    # ticket kiosk: a small log hut with a front window and a cream sign face (text drawn at runtime)
    kx, kz = 17.0, 4.0
    with placed(b, kx, 0, kz):
        fr2, bk2, lf2, rt2 = house_base(b, -3.5, 3.5, 1.0, 7.0, "log", ("m_wood_1", "m_wood_2"), 8.0)
        window(b, fr2, 0.0, PL + 4.4, w=4.4, h=3.0, glow=True, frame="m_wood_2")
        gable_roof(b, "x", -3.5, 3.5, 1.0, 7.0, 8.0 + PL, 3.4, "w_roof_1", over_e=1.4, snow=0.9, gable_wall="s_board")
        box(b, V(0, PL + 8.8 + 3.4, -0.6), (6.0, 1.8, 0.4), {"side": "m_sign_frame"})
        b.face([V(-2.7, PL + 11.4, -0.85), V(2.7, PL + 11.4, -0.85), V(2.7, PL + 12.9, -0.85), V(-2.7, PL + 12.9, -0.85)], "m_sign", V(0, 0, -1))
    # a queue fence in switchbacks, a ski rack and parked chairs
    fence_run(b, -22.0, -2.0, 2.0, step=5.0, rails=2, h=3.0)
    fence_run_z(b, -2.0, 2.0, 8.0, step=3.0, h=3.0)
    for i, col in enumerate(("w_roof_1", "bunt_teal", "w_roof_1")):
        x = 8.0 + i * 5.0
        box(b, V(x, 1.0, 6.5), (3.2, 0.5, 2.4), {"side": col, "top": col, "skip_bottom": True})
        box(b, V(x, 2.6, 7.6), (3.2, 2.6, 0.35), {"side": col, "skip_bottom": True})
    conifer(b, 21.0, 22.0, 24.0, rng, tiers=4, sides=5, base_r=4.8)
    return lm_finish(b, W, D, 32.0, ["SkiLiftRidge"], read="lift base: a metal shed with a loading opening, a bullwheel on A-legs, a ticket kiosk with a blank sign face, queue fences, parked chairs", sign_face={"centre": [17.0 + W / 2, 13.75, 3.15], "size": [5.4, 1.5]})


@recipe
def lift_top():
    b = L.new("SP_LM_LiftTop")
    W, D = 36.0, 30.0
    rng = rng_of("SP_LM_LiftTop")
    pad(b, W, D)
    # a rock outcrop under the top station, snow on its ledges
    for (x, z, sx, sy, sz) in ((-8.0, 14.0, 13.0, 8.0, 9.0), (7.0, 10.0, 12.0, 7.0, 8.0), (-1.0, 22.0, 14.0, 9.0, 8.0), (12.0, 20.0, 7.0, 5.0, 6.0), (-13.0, 6.0, 6.0, 4.0, 5.0)):
        sphere(b, V(x, sy * 0.45, z), (sx / 2, sy / 2, sz / 2), ["rk_near_shade", "rk_near", "rk_near", "rk_near_lit", "s_half"], subdiv=1, rng=rng, jitter=0.18, flatten=0.9)
    sx0, sx1, sz0, sz1 = -9.0, 9.0, 8.0, 20.0
    base = 6.0
    box(b, V(0, base / 2 + 1.0, (sz0 + sz1) / 2), (sx1 - sx0 + 0.6, base + 2.0, sz1 - sz0 + 0.6), {"side": "s_stone_dk", "top": "s_stone", "skip_bottom": True})
    fr, bk, lf, rt = WallFrame("z", sz0, -1), WallFrame("z", sz1, 1), WallFrame("x", sx0, -1), WallFrame("x", sx1, 1)
    for wf, (u0, u1) in ((fr, (sx0, sx1)), (bk, (sx0, sx1)), (lf, (sz0, sz1)), (rt, (sz0, sz1))):
        wall_panel(b, wf, u0, u1, base, base + 9.0, "board", ("m_metal", "s_stone_lt"))
    b.face([fr.P(-4.0, base, 0.4), fr.P(4.0, base, 0.4), fr.P(4.0, base + 6.4, 0.4), fr.P(-4.0, base + 6.4, 0.4)], "ice_void", fr.n)
    fr.box(b, 0.0, base + 3.4, 9.6, 7.0, 0.0, 0.35, {"side": "rk_dark"})
    b.face([fr.P(-4.0, base, 0.45), fr.P(4.0, base, 0.45), fr.P(4.0, base + 6.4, 0.45), fr.P(-4.0, base + 6.4, 0.45)], "ice_void", fr.n)
    for u in (-6.4, 6.4):
        window(b, fr, u, base + 5.4, w=2.2, h=3.0, glow=True, frame="m_wood_2", sill=False)
    gable_roof(b, "x", sx0, sx1, sz0, sz1, base + 9.0, 3.4, "rf_slate", over_e=2.2, snow=0.9, gable_wall="s_stone_lt")
    # the bullwheel gantry on the +z end: the cable comes up from the lift line and carries on out of sight behind the ridge
    wx, wy_, wz = 0.0, base + 15.0, 24.0
    for sx in (-1, 1):
        beam(b, V(sx * 4.0, base + 1.0, wz - 1.0), V(sx * 1.0, wy_, wz), 1.0, 1.0, "m_metal_dark")
        beam(b, V(sx * 4.0, base + 1.0, wz + 3.0), V(sx * 1.0, wy_, wz + 1.0), 1.0, 1.0, "m_metal_dark")
    tube(b, [V(wx - 1.8, wy_, wz), V(wx + 1.8, wy_, wz)], 5.4, 12, "m_metal_dark", phase=0.2)
    tube(b, [V(wx - 2.0, wy_, wz), V(wx + 2.0, wy_, wz)], 1.8, 8, "m_metal")
    tube(b, [V(wx, wy_ + 5.4, wz - 0.0), V(wx, wy_ + 5.4, wz + 6.0)], 0.5, 4, "m_black", phase=0.78)  # the cable leaving over the wheel...
    tube(b, [V(wx, wy_ + 5.4, wz + 6.0), V(wx, wy_ + 9.4, wz + 22.0)], 0.5, 4, "m_black", phase=0.78)  # ...climbing away out of sight
    box(b, V(0, base + 6.0, wz - 1.0), (9.0, 0.8, 0.8), {"side": "m_metal", "skip_bottom": True})
    conifer(b, -14.0, 24.0, 22.0, rng, tiers=4, sides=5, base_r=4.4)
    return lm_finish(b, W, D, wy_ + 12.0, ["SkiLiftRidge"], read="lift top station on the ridge: a metal-clad house on a rock outcrop, a bullwheel gantry, the cable leaving out of sight")


@recipe
def lift_cable24():
    b = L.new("SP_LM_LiftCable24")
    tube(b, [V(-12.0, 0, 0), V(0, -0.5, 0), V(12.0, 0, 0)], 0.5, 4, "m_black", phase=math.pi / 4)  # a 24-long cable, 1 stud thick, with a slight sag
    for x in (-8.0, 0.0, 8.0):
        box(b, V(x, 0.2, 0), (1.2, 1.0, 1.0), {"side": "m_metal_dark", "top": "m_metal"})  # a clamp
        box(b, V(x, -2.2, 0), (0.35, 3.4, 0.35), {"side": "m_metal_dark", "skip_bottom": False})  # a hanger
    b.shift(0.0, 4.2, 0.0)  # the hanger bottoms sit at y = 0.3; the cable centre line is at y = 4.2
    return unit(b, "LM", "near", "lift line", authored=True, kind="liftcable", role="a straight 24-long lift cable segment along x (1 stud thick) with three hangers; the planner chains and angles it", district=["SkiLiftRidge"], height=5.0, length=24.0, cable_height=4.2, pivot="bottom centre, at the segment middle; the cable centre line is 4.2 above the pivot and the hangers hang below it", long_axis="x")


def chair(name, col):
    b = L.new(name)
    box(b, V(0, -1.9, 0), (0.45, 3.8, 0.45), {"side": "m_metal_dark"})  # the hanger from the cable grip at y = 0
    box(b, V(0, 0.1, 0), (1.4, 0.9, 1.2), {"side": "m_metal_dark", "top": "m_metal"})
    box(b, V(0, -4.3, 0.0), (3.2, 0.6, 2.4), {"side": col, "top": col})  # the seat
    box(b, V(0, -2.9, 1.05), (3.2, 2.6, 0.4), {"side": col, "top": col})  # the backrest
    for sx in (-1.5, 1.5):
        box(b, V(sx, -3.5, -0.2), (0.3, 1.8, 2.0), {"side": "m_metal_dark"})  # armrests
    box(b, V(0, -5.6, -1.2), (3.2, 0.3, 0.3), {"side": "m_metal_dark"})  # a footrest bar
    b.shift(0.0, 5.85, 0.0)  # the footrest bottom sits at y = 0; the cable grip is at y = 6.0
    return unit(b, "Anim", "near", "off-road", authored=True, kind="chair", role="a ski-lift chair 3 wide x 6 tall; the cable grip is at y = 6.0 above the pivot", district=["SkiLiftRidge"], height=6.0, grip_height=6.0, pivot="bottom centre (the footrest); the cable grip is 6.0 above it, the chair hangs below the grip")


@recipe
def anim_chair():
    return chair("SP_Anim_Chair", "w_roof_1")


@recipe
def anim_chair_teal():
    return chair("SP_Anim_ChairTeal", "bunt_teal")


@recipe
def frozen_lake_set():
    b = L.new("SP_LM_FrozenLake")
    W, D = 60.0, 38.0
    rng = rng_of("SP_LM_FrozenLake")
    pad(b, W, D)
    # the skate hut at the shore (left), a pier running onto the lake (+z), dark rim rocks along the shore, benches and a skate rack
    with placed(b, -14.0, 0.0, 2.0):
        x0, x1, z0, z1 = -8.0, 8.0, 1.0, 13.0
        fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("m_wood_1", "m_wood_2"), 8.6)
        door(b, fr, -2.0, w=3.8, h=6.8)
        steps(b, fr, -2.0, 5.2, n=2)
        porch(b, fr, -2.0, 7.0, 2.8, 8.2, "rf_forest", rise=1.0)
        window(b, fr, 4.0, PL + 4.6, w=3.4, h=3.6, glow=True, frame="m_wood_2")
        window(b, lf, 7.0, PL + 4.6, w=3.0, h=3.4, frame="m_wood_2")
        window(b, rt, 7.0, PL + 4.6, w=3.0, h=3.4, glow=True, frame="m_wood_2")
        gable_roof(b, "x", x0, x1, z0, z1, 8.6 + PL, 4.4, "rf_forest", over_e=1.8, snow=0.9, gable_wall="s_board")
        sm = chimney(b, 4.5, 9.0, 8.6 + PL, 8.6 + PL + 7.4, w=1.9)
    sm_world = (-14.0 + sm[0], sm[1], 2.0 + sm[2])
    # the pier: planks on posts, with a rail down one side
    px, pz0, pz1 = 12.0, 12.0, 36.0
    box(b, V(px, 1.7, (pz0 + pz1) / 2), (5.0, 0.5, pz1 - pz0), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    for k in range(5):
        z = pz0 + 2.0 + k * 5.4
        for sx in (-2.0, 2.0):
            box(b, V(px + sx, 0.7, z), (0.7, 2.4, 0.7), {"side": "m_wood_2", "skip_bottom": False})
    for k in range(5):
        z = pz0 + 2.0 + k * 5.4
        box(b, V(px - 2.3, 3.0, z), (0.4, 2.2, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(px - 2.3, 4.0, (pz0 + pz1) / 2), (0.4, 0.4, pz1 - pz0 - 1.0), {"side": "m_wood_2", "top": "s_half", "skip_bottom": True})
    # rim rocks: dark, in groups, with snow caps, and a frozen reed clump or two
    for (x, z, s_) in ((-26.0, 30.0, 5.0), (-20.0, 34.0, 4.0), (-10.0, 33.0, 5.4), (0.0, 35.0, 4.2), (24.0, 32.0, 5.0), (28.0, 36.0, 3.8), (-28.0, 22.0, 4.0)):
        sphere(b, V(x, s_ * 0.3 + 0.3, z), (s_, s_ * 0.55, s_ * 0.85), ["rim_dark", "rim_dark", "rk_dark", "s_shade"], subdiv=0, rng=rng, jitter=0.2)
    for (x, z) in ((-16.0, 31.0), (14.0, 6.0)):
        for i in range(5):
            a = rng.uniform(0, 6.28)
            hh = rng.uniform(4.0, 7.0)
            base_ = [V(x + math.cos(a) * 0.5 + 0.3 * k, 0.4, z + math.sin(a) * 0.5 + 0.2 * (k % 2)) for k in range(3)]
            tip = V(x + math.cos(a) * 0.5 + rng.uniform(-0.6, 0.6), 0.4 + hh, z + math.sin(a) * 0.5)
            for kk in range(3):
                b.face([base_[kk], base_[(kk + 1) % 3], tip], "s_reed", V(base_[kk].x - x, 0.3, base_[kk].z - z))
    for bx in (6.0, -3.0):  # benches facing the lake
        box(b, V(bx, 1.4, 22.0), (5.0, 0.5, 1.6), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
        for sx in (-2.0, 2.0):
            box(b, V(bx + sx, 0.6, 22.0), (0.5, 1.4, 1.4), {"side": "m_wood_2", "skip_bottom": True})
    fence_run(b, -28.0, 28.0, 1.0, step=7.0, gate=(-6.0, 2.0), rails=2, h=3.2)
    return lm_finish(b, W, D, 16.0, ["FrozenLake"], sockets=lot_sockets(W, [sm_world]), read="the lake shore set (no oval): a skate hut with a porch, a pier onto the lake, dark rim rocks, benches, reeds and a rail fence", variant="shore set")


# ---- the summit lodge great hall
@recipe
def summit_lodge_hall():
    b = L.new("SP_LM_SummitLodge")
    W, D = 48.0, 30.0
    rng = rng_of("SP_LM_SummitLodge")
    pad(b, W, D)
    x0, x1, z0, z1 = -21.0, 21.0, 2.0, 27.0
    base_h, wy = 9.0, 14.0
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("s_stone", "s_stone_lt"), base_h, plinth_sw="s_stone_dk")
    for wf, (u0, u1) in ((fr, (x0, x1)), (bk, (x0, x1)), (lf, (z0, z1)), (rt, (z0, z1))):
        wall_panel(b, wf, u0, u1, base_h, wy, "log", ("m_wood_1", "m_wood_2"))
    fr.box(b, 0.0, base_h + 0.2, x1 - x0, 0.7, 0.0, 0.6, {"side": "s_stone_lt", "top": "s_half"})
    door(b, fr, 0.0, w=6.4, h=8.6, frame="s_stone_lt")
    steps(b, fr, 0.0, 9.6, n=3)
    for u in (-15.0, -9.0, 9.0, 15.0):
        window(b, fr, u, 5.0, w=3.8, h=4.6, glow=(u in (-9.0, 15.0)), frame="s_stone_lt")
    for u in (-17.0, -11.0, 11.0, 17.0):
        window(b, fr, u, base_h + 2.6, w=3.4, h=4.0, glow=(u in (-17.0, 11.0)), frame="m_wood_2", sill=False)
    for sidew, uu in ((lf, 9.0), (lf, 17.0), (lf, 24.0), (rt, 9.0), (rt, 17.0), (rt, 24.0)):
        window(b, sidew, uu, 5.0, w=3.6, h=4.4, glow=(uu == 17.0), frame="s_stone_lt")
    # the great gable: a tall 60 degree roof with the gable end to the road, a big glazed front with timber mullions
    half = (x1 - x0) / 2
    rise = half * math.tan(math.radians(60.0))
    ye = wy + PL
    gable_roof(b, "z", z0, z1, x0, x1, ye, rise, "rf_slate", over_e=2.0, over_g=1.2, snow=0.0, gable_wall="s_board", ridge_cap="m_wood_2")
    ymid = ye + rise
    b.face([V(-12.4, ye + 1.0, z0 - 0.3), V(12.4, ye + 1.0, z0 - 0.3), V(2.4, ye + rise - 7.8, z0 - 0.3), V(-2.4, ye + rise - 7.8, z0 - 0.3)], "m_wood_2", V(0, 0, -1))
    b.face([V(-11.6, ye + 2.0, z0 - 0.45), V(11.6, ye + 2.0, z0 - 0.45), V(1.9, ye + rise - 8.5, z0 - 0.45), V(-1.9, ye + rise - 8.5, z0 - 0.45)], "honey_glow", V(0, 0, -1))
    for x in (-8.0, -4.0, 0.0, 4.0, 8.0):  # mullions
        top = ye + 2.0 + (ye + rise - 8.5 - (ye + 2.0)) * (1 - (abs(x) - 1.9) / 9.7) if abs(x) > 1.9 else ye + rise - 8.5
        box(b, V(x, (ye + 2.0 + top) / 2, z0 - 0.62), (0.45, top - ye - 2.0, 0.3), {"side": "m_wood_2"})
    # a cupola on the ridge with a teal pennant, and three chimneys at the back
    cy = ymid - 1.0
    cx_, cz_ = 0.0, (z0 + z1) / 2
    box(b, V(cx_, cy + 2.0, cz_), (4.4, 4.0, 4.4), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})
    for s_ in (-1, 1):
        b.face([V(cx_ + s_ * 1.6, cy + 1.2, cz_ - 2.25), V(cx_ + s_ * 0.2, cy + 1.2, cz_ - 2.25), V(cx_ + s_ * 0.2, cy + 3.2, cz_ - 2.25), V(cx_ + s_ * 1.6, cy + 3.2, cz_ - 2.25)], "honey_glow", V(0, 0, -1))
    frustum(b, cx_, cy + 4.0, cz_, 2.8, 3.4, 0.0, 4, math.pi / 4, "rf_slate")
    cyl(b, V(cx_, cy + 6.6, cz_), 5.2, 0.22, 4, "m_metal", r_top=0.15)
    b.face([V(cx_ + 0.1, cy + 11.0, cz_ - 0.05), V(cx_ + 5.0, cy + 10.4, cz_ - 0.05), V(cx_ + 0.1, cy + 9.4, cz_ - 0.05)], "bunt_teal", V(0, 0, -1))
    b.face([V(cx_ + 0.1, cy + 11.0, cz_ + 0.05), V(cx_ + 5.0, cy + 10.4, cz_ + 0.05), V(cx_ + 0.1, cy + 9.4, cz_ + 0.05)], "bunt_teal", V(0, 0, 1))
    smokes = []
    for (x, z) in ((-14.0, 24.0), (14.0, 24.0), (0.0, 25.0)):
        yb = ye + (rise * (1 - (abs(x) - 0.0) / half) if abs(x) < half else 0.0) - 0.5
        smokes.append(chimney(b, x, z, yb - 1.0, yb + 8.0, w=2.6))
    # steep roofs shed snow: drifts bank against the base, a lantern pair at the door
    for sx in (-1, 1):
        cyl(b, V(sx * 6.4, 0.0, z0 - 1.6), 9.0, 0.35, 5, "m_wood_2", r_top=0.3)
        box(b, V(sx * 6.4, 9.6, z0 - 1.6), (1.6, 1.5, 1.6), {"side": "honey_glow", "top": "m_wood_2", "skip_bottom": True})
        box(b, V(sx * 6.4, 10.7, z0 - 1.6), (2.2, 0.5, 2.2), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    for (x, z, h) in ((-22.0, 24.0, 26.0), (22.0, 22.0, 24.0)):
        conifer(b, x, z, h, rng, tiers=4, sides=5, base_r=h * 0.2)
    return lm_finish(b, W, D, ymid + 15.0, ["SummitLodge"], sockets=lot_sockets(W, smokes[:2]), read="the great hall: a 60 degree slate gable 54 high to the road, a glazed gable end, stone base, three chimneys, a cupola with a teal pennant", variant="great hall")


# ================================================================ S1: the glacier gallery (opaque, thick rock-and-ice horseshoe)
# Route frame: the road runs toward -Z along x = 0; the road surface is y = 0. Every piece's FRONT is its +Z face (the face the driver
# approaches); its body extends toward -Z. Bays are exactly 32 long with identical end profiles; pivot = the bottom centre of the bay's START
# face (z = 0, x = 0, y = 0 on the deck), the bay occupies z 0 .. -32. Profile: vertical inner walls at x = +/-58 up to y = 28, then an
# ellipse (semi-axes 58 x 18) to a crown at y = 46. The shell is 14 studs thick (portals 18).
TUN_CY = 28.0
TUN_A, TUN_B = 58.0, 18.0
TUN_Y_WALL = [-6.0, 6.0, 14.0, 20.0, 28.0]  # wall vertices: the strata thresholds sit on vertices
TUN_PHIS = [math.asin((y - TUN_CY) / TUN_B) for y in (32.0, 36.0, 40.0, 43.2, 45.2)] + [math.acos(8.0 / TUN_A), math.pi / 2]
TUN_EXT = ["rk_near_shade", "ice_deep", "rk_near", "ice_pale", "ice_lit", "ice_pale", "ice_lit", "s_half"]  # strata bottom to top: rock, ice, rock, ice, ice (then ice again, snow)
TUN_INT = ["rk_dark", "ice_shade", "rk_near_shade", "ice_deep", "ice_pale", "ice_deep", "ice_pale", "ice_pale"]  # the same order, one step darker inside
TUN_BANDS = [6.0, 14.0, 20.0, 32.0, 38.0, 46.0, 54.0]


def tun_band(y):
    return sum(1 for t in TUN_BANDS if y >= t)


def tun_ring(da=0.0, db=0.0):
    """The full profile left base -> crown -> right base as [(x, y, kind)], scaled by da, db (inner = 0)."""
    right = [(TUN_A + da, y, "w") for y in TUN_Y_WALL] + [((TUN_A + da) * math.cos(p), TUN_CY + (TUN_B + db) * math.sin(p), "a") for p in TUN_PHIS]
    left = [(-x, y, k) for (x, y, k) in right[:-1]]  # base .. just before the crown
    return left + [(0.0, right[-1][1], "a")] + right[:-1][::-1]


def ring_at(da, db):
    return tun_ring(da, db)


def ring_strip(b, pts, z0, z1, swf, toward_axis, skip=None):
    for i in range(len(pts) - 1):
        if skip and skip(i, pts):
            continue
        (xa, ya, _), (xb, yb, _) = pts[i], pts[i + 1]
        mx, my = (xa + xb) / 2, (ya + yb) / 2
        hx, hy = -mx, TUN_CY - my
        if not toward_axis:
            hx, hy = -hx, -hy
        b.face([V(xa, ya, z0), V(xb, yb, z0), V(xb, yb, z1), V(xa, ya, z1)], swf(my), V(hx, hy, 0))


def ring_plate(b, inner, outer, z, nz, swf, skip=None):
    for i in range(len(inner) - 1):
        if skip and skip(i, inner):
            continue
        q = [inner[i], inner[i + 1], outer[i + 1], outer[i]]
        b.face([V(p[0], p[1], z) for p in q], swf((outer[i][1] + outer[i + 1][1]) / 2), V(0, 0, nz))


def ext_sw(y):
    return TUN_EXT[tun_band(y)]


def int_sw(y):
    return TUN_INT[tun_band(y)]


def ring_lumps(seed, n, lo=0.0, hi=0.08):
    r = random.Random(seed)
    return [1.0 + r.uniform(lo, hi) for _ in range(n)]


def tun_clearance():
    """The lowest inner-roof height over the 76-wide carriageway (x = +/-38), read from the polyline the mesh is built from."""
    inner = ring_at(0, 0)
    best = 1e9
    for i in range(len(inner) - 1):
        (xa, ya, _), (xb, yb, _) = inner[i], inner[i + 1]
        for xe in (-38.0, 38.0):
            if (xa - xe) * (xb - xe) <= 0 and xa != xb:
                best = min(best, ya + (yb - ya) * (xe - xa) / (xb - xa))
    return best


def tun_meta(kind, role, **kw):
    d = dict(kind=kind, role=role, district=["GlacierTunnel"], clear_width=2 * TUN_A, crown=TUN_CY + TUN_B, min_clearance_over_carriageway=round(tun_clearance(), 2), wall_height=TUN_CY, front="+Z (the approach face)", pivot_note="bottom centre of the START face (x = 0, y = 0 = deck, z = 0); the body extends toward -Z")
    d.update(kw)
    return d


def tun_icicles(b, xs, y_of_x, z, rng, lmax=8.0):
    for x in xs:
        ln = rng.uniform(4.5, lmax)
        y0 = y_of_x(x) - 0.4
        r = rng.uniform(0.7, 1.1)
        for sides in (3,):
            tip = V(x + rng.uniform(-0.3, 0.3), y0 - ln, z + rng.uniform(-0.3, 0.3))
            base = [V(x + math.cos(a) * r, y0, z + math.sin(a) * r) for a in (0.3, 0.3 + 2.094, 0.3 + 4.188)]
            for kk in range(3):
                b.face([base[kk], base[(kk + 1) % 3], tip], "ice_lit", V(base[kk].x - x, -0.4, base[kk].z - z))


def crown_y(x):
    return TUN_CY + TUN_B * math.sqrt(max(0.0, 1 - (x / TUN_A) ** 2))


def tun_lanterns(b, zc):
    for sg in (-1, 1):
        box(b, V(sg * (TUN_A - 1.0), 16.0, zc), (1.6, 2.6, 1.2), {"side": "honey_glow", "top": "m_wood_2", "skip_bottom": True})  # static honey lantern on the wall
        box(b, V(sg * (TUN_A - 0.2), 16.0, zc), (0.6, 3.2, 1.8), {"side": "m_wood_2"})


def bay_build(name, seed, hole=False, gallery=False, lanterns=True, note=""):
    rng = rng_of(name)
    b = L.new(name)
    inner = ring_at(0, 0)
    n = len(inner)
    T = 14.0
    e_mid = ring_lumps(seed, n, 0.0, 0.07)

    def grow(i, x, y, k, f):
        return (x * (1 + T * f / TUN_A), (TUN_CY + (y - TUN_CY) * (1 + T * f / TUN_B)) if y > TUN_CY else y, k)

    outer_end = [grow(i, x, y, k, 1.0) for i, (x, y, k) in enumerate(inner)]
    outer_mid = [grow(i, x, y, k, e_mid[i]) for i, (x, y, k) in enumerate(inner)]
    rib = [(x * (1 - 2.0 / TUN_A), (TUN_CY + (y - TUN_CY) * (1 - 2.0 / TUN_B)) if y > TUN_CY else y, k) for (x, y, k) in inner]

    def is_hole(i, pts):
        return hole and pts[i][2] == "a" and pts[i + 1][2] == "a" and abs(pts[i][0]) <= 8.2 and abs(pts[i + 1][0]) <= 8.2

    def is_leftwall(i, pts):
        return gallery and pts[i][0] < -TUN_A + 0.01 and pts[i + 1][0] < -TUN_A + 0.01 and pts[i + 1][1] <= TUN_CY + 0.01

    gaps = [(-3.0, -8.0), (-13.0, -18.0), (-23.0, -28.0)]  # the three openings (gallery bay)
    piers = [(0.0, -3.0), (-8.0, -13.0), (-18.0, -23.0), (-28.0, -32.0)]  # the closed ends and the piers between them

    # which z ranges each segment covers
    def ranges(i, pts):
        if is_leftwall(i, pts):
            return piers
        if is_hole(i, pts):
            return [(0.0, -8.0), (-24.0, -32.0)]
        return [(0.0, -32.0)]

    for i in range(n - 1):
        for (za, zb) in ranges(i, inner):
            seg_in = [inner[i], inner[i + 1]]
            ring_strip(b, seg_in, za, zb, int_sw, True)
            # outer: two strips so the middle can bulge (lumps); the bulge exists only where the span covers the middle
            zm = (za + zb) / 2
            for (z0_, z1_, oa, ob) in ((za, zm, outer_end, outer_mid), (zm, zb, outer_mid, outer_end)):
                A, B_, C, D_ = oa[i], oa[i + 1], ob[i + 1], ob[i]
                mx, my = (A[0] + B_[0]) / 2, (A[1] + B_[1]) / 2
                hint = V(mx, my - TUN_CY, 0)
                sw = ext_sw(my)
                b.face([V(A[0], A[1], z0_), V(B_[0], B_[1], z0_), V(C[0], C[1], z1_), V(D_[0], D_[1], z1_)], sw, hint)
    # pier end faces (gallery): the solid ends between the shell surfaces
    if gallery:
        for (za, zb) in piers:
            for z_, nz in ((za, 1), (zb, -1)):
                if z_ in (0.0, -32.0):
                    continue
                for i in range(n - 1):
                    if is_leftwall(i, inner):
                        q = [inner[i], inner[i + 1], outer_end[i + 1], outer_end[i]]
                        b.face([V(p[0], p[1], z_) for p in q], ext_sw((q[0][1] + q[1][1]) / 2), V(0, 0, nz))
        for (za, zb) in gaps:  # the soffit above each opening: the springline underside
            ia = next(i for i in range(n - 1) if is_leftwall(i, inner) and inner[i + 1][1] >= TUN_CY - 0.01)
            p_in, p_out = inner[ia + 1], outer_end[ia + 1]
            b.face([V(p_out[0], p_out[1], za), V(p_in[0], p_in[1], za), V(p_in[0], p_in[1], zb), V(p_out[0], p_out[1], zb)], "ice_deep", V(0, -1, 0))
    # sky window: reveals around the opening and a few icicles from its edges
    if hole:
        ia = next(i for i in range(n - 1) if is_hole(i, inner))
        ib = max(i for i in range(n - 1) if is_hole(i, inner))
        pin_l, pin_r = inner[ia], inner[ib + 1]
        pout_l, pout_r = outer_end[ia], outer_end[ib + 1]
        mid_i = (ia + ib) // 2
        for (z_, nz) in ((-8.0, -1), (-24.0, 1)):  # reveals at the near and far edges: along the crown, between the inner and outer surfaces
            for i in range(ia, ib + 1):
                q = [inner[i], inner[i + 1], outer_end[i + 1], outer_end[i]]
                b.face([V(p[0], p[1], z_) for p in q], "ice_pale", V(0, 0, nz))
        for (pin, pout, nx) in ((pin_l, pout_l, 1), (pin_r, pout_r, -1)):  # reveals at the two sides
            b.face([V(pin[0], pin[1], -8.0), V(pin[0], pin[1], -24.0), V(pout[0], pout[1], -24.0), V(pout[0], pout[1], -8.0)], "ice_lit", V(nx, 0, 0))
        tun_icicles(b, [-6.5, -3.0, 0.0, 3.0, 6.5], crown_y, -8.6, rng)
        tun_icicles(b, [-5.0, 5.5], crown_y, -23.4, rng)
    # the ring rib at the bay start: 3 long, 2 studs proud, one step lighter (the exterior strata set) than the shell
    for i in range(n - 1):
        ring_strip(b, [rib[i], rib[i + 1]], 0.0, -3.0, ext_sw, True)
        q = [inner[i], inner[i + 1], rib[i + 1], rib[i]]
        mid_y = (inner[i][1] + inner[i + 1][1]) / 2
        b.face([V(p[0], p[1], 0.0) for p in q], ext_sw(mid_y), V(0, 0, 1))
        b.face([V(p[0], p[1], -3.0) for p in q], ext_sw(mid_y), V(0, 0, -1))
    if lanterns and not gallery:
        tun_lanterns(b, -16.0)
    return unit(b, "Tunnel", "near", "the route", authored=True, **tun_meta("bay", note, length=32.0, sky_window=hole, open_side="-x, behind three piers" if gallery else None))


@recipe
def gt_bay_a():
    return bay_build("SP_GT_Bay_A", 21, note="a closed bay: thick rock-and-ice shell, strata in a fixed order, a ring rib at the start, two static honey lanterns")


@recipe
def gt_bay_b():
    return bay_build("SP_GT_Bay_B", 33, note="a closed bay with a different exterior bulge")


@recipe
def gt_bay_c():
    return bay_build("SP_GT_Bay_C", 47, lanterns=False, note="a closed bay with a third exterior bulge and no lanterns")


@recipe
def gt_bay_sky():
    return bay_build("SP_GT_BaySky", 58, hole=True, lanterns=False, note="a bay with a 16 x 16 roof opening (the sky window), icicles at its edges, none lower than 36 above the deck")


@recipe
def gt_bay_gallery():
    return bay_build("SP_GT_BayGallery", 69, gallery=True, lanterns=False, note="a bay open on its -x side behind three rock-and-ice piers")


def portal(name, out):
    """PortalIn (out False): front plate at z = 0 facing +Z, passage to z = -28. PortalOut (out True): starts at z = 0, front (exit) plate at z = -28."""
    rng = rng_of(name)
    b = L.new(name)
    inner = ring_at(0, 0)
    n = len(inner)
    T = 18.0
    outer = [(x * (1 + T / TUN_A), (TUN_CY + (y - TUN_CY) * (1 + T / TUN_B)) if y > TUN_CY else y, k) for (x, y, k) in inner]
    DEPTH = 28.0
    # the passage: interior strata, progressively darker toward the middle of the portal-in (a dark-blue, never black, opening); brighter at the exit
    if not out:
        segs = [(0.0, -10.0, int_sw), (-10.0, -20.0, lambda y: TUN_INT[max(0, tun_band(y) - 1)] if tun_band(y) > 0 else "rk_dark"), (-20.0, -28.0, lambda y: "ice_void" if tun_band(y) % 2 else "rk_dark")]
    else:
        segs = [(0.0, -8.0, int_sw), (-8.0, -20.0, lambda y: TUN_EXT[tun_band(y)]), (-20.0, -28.0, lambda y: "ice_lit" if tun_band(y) >= 3 else TUN_EXT[tun_band(y)])]
    for (za, zb, swf) in segs:
        ring_strip(b, inner, za, zb, swf, True)
    # the shell outside: a thick lip with strata continuing from the walls, a mid ring that bulges
    r = random.Random(7)
    bulge = [1.0 + r.uniform(0, 0.08) for _ in range(n)]
    mid = [(x * (1 + T * bulge[i] / TUN_A), (TUN_CY + (y - TUN_CY) * (1 + T * bulge[i] / TUN_B)) if y > TUN_CY else y, k) for i, (x, y, k) in enumerate(inner)]
    for i in range(n - 1):
        for (z0_, z1_, oa, ob) in ((0.0, -14.0, outer, mid), (-14.0, -28.0, mid, outer)):
            A, B_, C, D_ = oa[i], oa[i + 1], ob[i + 1], ob[i]
            my = (A[1] + B_[1]) / 2
            b.face([V(A[0], A[1], z0_), V(B_[0], B_[1], z0_), V(C[0], C[1], z1_), V(D_[0], D_[1], z1_)], ext_sw(my), V((A[0] + B_[0]) / 2, my - TUN_CY, 0))
    if not out:
        ring_plate(b, inner, outer, 0.0, 1, ext_sw)  # the front plate: the thick lip, strata across the face
        # snow cornice over the crown: a convex lump of snow along the top of the front plate, overhanging by 2
        top = [i for i in range(n) if outer[i][1] >= 40.0]
        for i in range(top[0], top[-1]):
            a0, a1 = outer[i], outer[i + 1]
            def lift(p, d):
                dx, dy = p[0], p[1] - TUN_CY
                ln = math.hypot(dx / (TUN_A + T), dy / (TUN_B + T)) or 1.0
                return (p[0] + dx / ln / (TUN_A + T) * d * 0.9, p[1] + dy / ln / (TUN_B + T) * d * 0.9)
            c0, c1 = lift(a0, 3.2), lift(a1, 3.2)
            b.face([V(a0[0], a0[1], 0.0), V(a1[0], a1[1], 0.0), V(c1[0], c1[1], 0.6), V(c0[0], c0[1], 0.6)], "s_half", V(0, 0, 1))
            b.face([V(c0[0], c0[1], 0.6), V(c1[0], c1[1], 0.6), V(c1[0], c1[1], -12.0), V(c0[0], c0[1], -12.0)], "s_lit", V((c0[0] + c1[0]) / 2, (c0[1] + c1[1]) / 2 - TUN_CY, 0))
            b.face([V(c0[0], c0[1], -12.0), V(c1[0], c1[1], -12.0), V(a1[0], a1[1], -12.0), V(a0[0], a0[1], -12.0)], "s_half", V(0, 0, -1))
        tun_icicles(b, [-22.0, -14.0, -6.0, 5.0, 13.0, 21.0], crown_y, -2.0, rng)
    else:
        rim = [(x * (1 + 7.0 / TUN_A), (TUN_CY + (y - TUN_CY) * (1 + 7.0 / TUN_B)) if y > TUN_CY else y, k) for (x, y, k) in inner]
        # the exit face: a dark thick rim (7 wide, standing 3 proud) inside the lip plate
        ring_plate(b, rim, outer, -DEPTH, -1, ext_sw)
        ring_plate(b, inner, rim, -DEPTH - 3.0, -1, lambda y: "rk_dark")
        ring_strip(b, rim, -DEPTH, -DEPTH - 3.0, lambda y: "rim_dark", False)
        ring_strip(b, inner, -DEPTH, -DEPTH - 3.0, lambda y: "rim_dark", True)
        # a snow lid over the crown
        top = [i for i in range(n) if outer[i][1] >= 40.0]
        for i in range(top[0], top[-1]):
            a0, a1 = outer[i], outer[i + 1]
            b.face([V(a0[0], a0[1] + 0.2, 0.0), V(a1[0], a1[1] + 0.2, 0.0), V(a1[0] * 0.98, a1[1] + 3.0, -14.0), V(a0[0] * 0.98, a0[1] + 3.0, -14.0)], "s_lit", V(0, 1, 0))
            b.face([V(a0[0] * 0.98, a0[1] + 3.0, -14.0), V(a1[0] * 0.98, a1[1] + 3.0, -14.0), V(a1[0], a1[1], -DEPTH), V(a0[0], a0[1], -DEPTH)], "s_half", V(0, 1, 0))
    # the inner start of the portal-out meets the last bay; the portal-in's far end meets bay 1
    # (ring ribs belong to the bays)
    return unit(b, "Tunnel", "near", "the route", authored=True, **tun_meta("portal_out" if out else "portal_in", "portal " + ("out: a dark thick rim round the exit" if out else "in: a thick rock-and-ice lip 28 deep, a snow cornice, a dark-blue opening"), depth=DEPTH, threshold="the opening starts at z = 0 (the outer face)" if not out else "the exit threshold is at z = -28; the rim stands 3 proud to z = -31", front="+Z (approach face, portal in); -Z (exit face, portal out)"))


@recipe
def gt_portal_in():
    return portal("SP_GT_PortalIn", False)


@recipe
def gt_portal_out():
    return portal("SP_GT_PortalOut", True)


def flank_wall(name, inner_at_plus, seed, note):
    """A flank wall 64 long (x) and 28 deep (z 0 .. -28): the front plate at z = 0 faces +Z with strata continuing across it; the tall end meets
    the portal (inner_at_plus: the tall end is at +x), the low end steps down to 28."""
    rng = random.Random(seed)
    b = L.new(name)
    n = 9
    xs = [-32.0 + 64.0 * i / (n - 1) for i in range(n)]
    hs = []
    for i in range(n):
        t = i / (n - 1)
        t = t if inner_at_plus else 1 - t
        hs.append((64.0 - 36.0 * t ** 0.85) * rng.uniform(0.93, 1.03) if 0 < i < n - 1 else (64.0 - 36.0 * t ** 0.85) * 0.99)
    # front plate: strata bands clipped under the stepped top line
    for i in range(n - 1):
        xa, xb, ha, hb = xs[i], xs[i + 1], hs[i], hs[i + 1]
        poly = [(xa, -6.0), (xb, -6.0), (xb, hb), (xa, ha)]
        for bi in range(len(TUN_EXT)):
            y0, y1 = (-6.0 if bi == 0 else TUN_BANDS[bi - 1]), (TUN_BANDS[bi] if bi < len(TUN_BANDS) else 200.0)
            clipped = clip_poly(poly, xa, y0, xb, y1)
            if len(clipped) >= 3:
                b.face([V(p[0], p[1], 0.0) for p in clipped], TUN_EXT[bi], V(0, 0, 1))
    # top: a stepped snowy top that slopes back and down, the back face and the two end faces
    for i in range(n - 1):
        xa, xb, ha, hb = xs[i], xs[i + 1], hs[i], hs[i + 1]
        b.face([V(xa, ha, 0.0), V(xb, hb, 0.0), V(xb, hb * 0.97, -12.0), V(xa, ha * 0.97, -12.0)], "s_lit", V(0, 1, 0.1))
        b.face([V(xa, ha * 0.97, -12.0), V(xb, hb * 0.97, -12.0), V(xb, hb * 0.55, -28.0), V(xa, ha * 0.55, -28.0)], "s_half" if i % 2 else "s_lit", V(0, 1, -0.5))
        b.face([V(xa, ha * 0.55, -28.0), V(xb, hb * 0.55, -28.0), V(xb, BASE_Y, -28.0), V(xa, BASE_Y, -28.0)], TUN_EXT[1 + i % 2], V(0, 0, -1))
    for sx, idx in ((-1, 0), (1, n - 1)):
        h = hs[idx]
        b.face([V(sx * 32.0, -6.0, 0.0), V(sx * 32.0, h, 0.0), V(sx * 32.0, h * 0.97, -12.0), V(sx * 32.0, h * 0.55, -28.0), V(sx * 32.0, -6.0, -28.0)], "rk_near" if sx == (1 if inner_at_plus else -1) else "ice_deep", V(sx, 0, 0))
    # rock lumps on the front plate (thick, convex): a few boulders stand proud of the face
    for k in range(4):
        i = rng.randrange(1, n - 1)
        x, y = xs[i] + rng.uniform(-2, 2), rng.uniform(6.0, min(hs[i] - 8.0, 30.0))
        sphere(b, V(x, y, 2.0), (rng.uniform(3.5, 5.5), rng.uniform(3.0, 4.5), 3.0), ["rk_near_shade", "rk_near", "rk_near", "rk_near_lit"], subdiv=0, rng=rng, jitter=0.2)
    return unit(b, "Tunnel", "near", "the route", authored=True, kind="flank_wall", role=note, district=["GlacierTunnel"], length=64.0, depth=28.0, tall_end="+x" if inner_at_plus else "-x", front="+Z (the front plate at z = 0)", pivot_note="bottom centre of the front plate (z = 0), x centred on the wall; body toward -Z; the tall end (64 high) joins the portal's outer edge at x = +/-76")


@recipe
def gt_wall_a():
    return flank_wall("SP_GT_Wall_A", True, 5, "the left flank wall (tall end at +x, against the portal): strata continue across the front plate, snow on the stepped top")


@recipe
def gt_wall_b():
    return flank_wall("SP_GT_Wall_B", False, 9, "the right flank wall (tall end at -x, against the portal), a different stepped top")


@recipe
def gt_icefall():
    rng = rng_of("SP_GT_IceFall")
    b = L.new("SP_GT_IceFall")
    H = 54.0
    # a frozen waterfall column: stacked tapering facets, three ice tones, a bulb at the foot; back against the portal plate (z = 0), standing 6 proud
    prof = [(0.0, 5.6, 6.0), (5.0, 4.4, 5.0), (13.0, 3.2, 4.2), (24.0, 3.6, 4.6), (36.0, 2.8, 4.0), (46.0, 3.8, 5.0), (H, 4.6, 5.4)]
    rings = []
    for (y, hw, dz) in prof:
        r = []
        for k in range(6):
            a = math.pi * k / 5  # a half-hexagon bulging toward +z
            r.append(V(math.cos(a) * hw * rng.uniform(0.92, 1.08), y, math.sin(a) * dz))
        rings.append(r)
    cols = ["ice_deep", "ice_pale", "ice_lit", "ice_pale", "ice_lit"]
    for i in range(len(rings) - 1):
        for k in range(5):
            q = [rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]]
            cen = sum(q, V(0, 0, 0)) / 4
            b.face(q, cols[(i + k) % 5] if i % 2 else cols[(i + k + 2) % 5], V(cen.x, 0, cen.z))
    b.face(rings[-1], "s_lit", V(0, 1, 0))
    b.face(rings[0], "ice_deep", V(0, -1, 0))
    b.face([V(rings[0][0].x, 0.0, 0.0), V(rings[0][5].x, 0.0, 0.0), V(rings[-1][5].x, H, 0.0), V(rings[-1][0].x, H, 0.0)], "ice_pale", V(0, 0, -1))
    return unit(b, "Tunnel", "near", "portal face", authored=True, kind="icefall", role="an ice-fall column for the portal front plate: back flat against z = 0, standing 6 proud toward +Z", district=["GlacierTunnel"], height=H, front="+Z", pivot_note="bottom centre of the flat back, which sits on the portal plate")


# ================================================================ S1: the lake kit
def ice_tile(name, W, D, centre, radii, cracks_x, cracks_z, note):
    """A seamless ice tile at y = 0.8 above the snow: pale cyan at the edges, a deeper blue irregular heart (ice_heart), faceted so it is matte
    and textured, pale crack lines on the blue (the reverse of the hazard), a 0.8 skirt in rim_dark. The edges are flat and all ice_pale, and the
    cracks cross the edges at the same offsets on every tile, so tiles join edge to edge."""
    rng = rng_of(name)
    b = L.new(name)
    nx, nz = int(W / 12), int(D / 12)
    Y0 = 0.8
    hx, hz = W / 2, D / 2
    pts = {}
    for i in range(nx + 1):
        for j in range(nz + 1):
            x, z = -hx + W * i / nx, -hz + D * j / nz
            edge = i in (0, nx) or j in (0, nz)
            pts[(i, j)] = V(x, Y0 + (0.0 if edge else rng.uniform(-0.14, 0.14)), z + 0.0)
    cx, cz = centre
    a0, b0 = radii

    def heart(x, z):
        ang = math.atan2((z - cz) / b0, (x - cx) / a0)
        wob = 1.0 + 0.1 * math.sin(3 * ang + 0.7) + 0.05 * math.sin(5 * ang + 2.0)
        return math.hypot((x - cx) / a0, (z - cz) / b0) / wob

    def cell(i, j):
        for tri in (((i, j), (i + 1, j), (i + 1, j + 1)), ((i, j), (i + 1, j + 1), (i, j + 1))):
            q = [pts[k] for k in tri]
            cen = sum(q, V(0, 0, 0)) / 3
            d = heart(cen.x, cen.z)
            sw = "ice_heart" if d < 0.5 else "ice_deep" if d < 0.8 else "ice_pale"
            b.face(q, sw, V(0, 1, 0))

    for i in range(nx):
        for j in range(nz):
            cell(i, j)
    # fine pale cracks on the surface: polylines that cross the tile edges at fixed offsets
    def crack(pts2, wd=0.6):
        for k in range(len(pts2) - 1):
            (xa, za), (xb, zb) = pts2[k], pts2[k + 1]
            ln = math.hypot(xb - xa, zb - za)
            nxv, nzv = -(zb - za) / ln * wd / 2, (xb - xa) / ln * wd / 2
            b.face([V(xa - nxv, Y0 + 0.07, za - nzv), V(xb - nxv, Y0 + 0.07, zb - nzv), V(xb + nxv, Y0 + 0.07, zb + nzv), V(xa + nxv, Y0 + 0.07, za + nzv)], "ice_crack", V(0, 1, 0))

    crack([(-hx, cracks_z), (-hx * 0.55, cracks_z - 4), (-hx * 0.2, cracks_z + 4), (hx * 0.3, cracks_z - 3), (hx, cracks_z)])
    crack([(cracks_x, -hz), (cracks_x - 5, -hz * 0.5), (cracks_x + 4, -hz * 0.1), (cracks_x - 3, hz * 0.45), (cracks_x, hz)])
    crack([(hx * 0.3, cracks_z - 3), (hx * 0.5, cracks_z - 14), (hx * 0.62, cracks_z - 22)], 0.45)
    # the 0.8 skirt in rim_dark (hidden where tiles join)
    for (xa, za, xb, zb, nrm) in ((-hx, -hz, hx, -hz, (0, 0, -1)), (hx, hz, -hx, hz, (0, 0, 1)), (-hx, hz, -hx, -hz, (-1, 0, 0)), (hx, -hz, hx, hz, (1, 0, 0))):
        b.face([V(xa, Y0, za), V(xb, Y0, zb), V(xb, -0.4, zb), V(xa, -0.4, za)], "rim_dark", V(*nrm))
    return unit(b, "Lake", "mid", "lake plane, 90+ from the road", authored=True, kind="icetile", role=note, district=["FrozenLake"], tile=[W, D], surface_y=Y0, tileable=True, front="-Z (the tile is symmetric; any side can face the road)", long_axis="x")


@recipe
def fl_plane_a():
    return ice_tile("SP_FL_Plane_A", 96.0, 96.0, (6.0, -4.0), (34.0, 30.0), 10.0, 12.0, "a 96 x 96 matte ice tile: pale cyan edge, an irregular deep-blue heart, fine pale cracks that cross the tile edges at fixed offsets")


@recipe
def fl_plane_b():
    return ice_tile("SP_FL_Plane_B", 192.0, 96.0, (-8.0, 2.0), (66.0, 27.0), 10.0, 12.0, "a 192 x 96 matte ice tile with a long deep-blue heart; the same crack offsets as Plane_A")


def shore_rim(name, Ln, note, reeds):
    rng = rng_of(name)
    b = L.new(name)
    n = max(4, int(Ln / 6)) + 1
    xs = [-Ln / 2 + Ln * i / (n - 1) for i in range(n)]
    profs = []
    for i in range(n):
        h = rng.uniform(0.9, 1.7) if 0 < i < n - 1 else 0.5
        profs.append([(-2.4, BASE_Y), (-1.6, 0.45 * h), (-0.4, h), (1.2, h * 0.9), (2.6, 0.2 * h), (3.2, BASE_Y)])
    strips(b, xs, profs, lambda i, k: ["rim_dark", "rim_dark", "rk_dark", "rim_dark", "rim_dark"][k])
    for i in range(int(Ln / 8)):
        x = -Ln / 2 + (i + 0.5) * Ln / int(Ln / 8) + rng.uniform(-1.5, 1.5)
        sz = rng.uniform(2.4, 3.8)
        sphere(b, V(x, 0.6 + sz * 0.25, rng.uniform(-0.8, 1.2)), (sz, sz * 0.6, sz * 0.85), ["rim_dark", "rk_dark", "rim_dark", "s_shade"], subdiv=0, rng=rng, jitter=0.2)
    for k in range(reeds):
        x = rng.uniform(-Ln / 2 + 3, Ln / 2 - 3)
        z = rng.uniform(1.5, 3.5)
        for kk in range(4):
            hh = rng.uniform(4.0, 7.0)
            base_ = [V(x + 0.3 * m + 0.4 * kk, 0.3, z + 0.25 * (m % 2)) for m in range(3)]
            tip = V(x + 0.4 * kk + rng.uniform(-0.6, 0.6), 0.3 + hh, z + rng.uniform(-0.3, 0.3))
            for m in range(3):
                b.face([base_[m], base_[(m + 1) % 3], tip], "s_reed", V(base_[m].x - x, 0.3, base_[m].z - z))
    return unit(b, "Lake", "near", "shore", authored=True, kind="rim", role=note, district=["FrozenLake"], length=Ln, front="-Z (toward the road; the rim sits on the lake side of the buffer)")


@recipe
def fl_rim_a():
    return shore_rim("SP_FL_Rim_A", 24, "a dark shore rim 24 long: a low rim_dark berm with rocks and a reed clump", 1)


@recipe
def fl_rim_b():
    return shore_rim("SP_FL_Rim_B", 36, "a dark shore rim 36 long with two reed clumps", 2)


@recipe
def fl_rim_c():
    return shore_rim("SP_FL_Rim_C", 48, "a dark shore rim 48 long with three reed clumps", 3)


def fish_hut(name, gable, note):
    b = L.new(name)
    rng = rng_of(name)
    x0, x1, z0, z1 = -4.5, 4.5, -3.5, 3.5
    box(b, V(0, 0.4, 0), (11.0, 0.8, 9.0), {"side": "s_shade", "top": "s_half", "skip_bottom": True})  # the hut sits in a trodden snow pad on the ice
    fr, bk, lf, rt = WallFrame("z", z0, -1), WallFrame("z", z1, 1), WallFrame("x", x0, -1), WallFrame("x", x1, 1)
    h = 5.4 if gable else 4.6
    for wf, (u0, u1) in ((fr, (x0, x1)), (bk, (x0, x1)), (lf, (z0, z1)), (rt, (z0, z1))):
        wall_panel(b, wf, u0, u1, 0.8, 0.8 + h, "board", ("m_wood_2", "s_weather"))
    door(b, fr, -1.2, w=2.4, h=4.2, y0=0.8)
    window(b, fr, 2.4, 4.4, w=1.6, h=1.6, glow=True, frame="m_wood_1", sill=False)
    window(b, lf, 0.0, 4.4, w=1.6, h=1.6, frame="m_wood_1", sill=False)
    if gable == "across":
        gable_roof(b, "z", z0, z1, x0, x1, 0.8 + h, 3.2, "rf_slate", over_e=1.0, over_g=0.6, snow=0.9, gable_wall="m_wood_1", t=0.4)
        c = chimney(b, -2.8, 1.6, 0.8 + h + 1.0, 0.8 + h + 5.6, w=1.2)
        top = 0.8 + h + 3.4
    elif gable:
        gable_roof(b, "x", x0, x1, z0, z1, 0.8 + h, 2.6, "bunt_teal", over_e=1.0, over_g=0.6, snow=0.9, gable_wall="m_wood_1", t=0.4)
        c = chimney(b, 2.6, 1.6, 0.8 + h + 1.0, 0.8 + h + 5.6, w=1.2)
        top = 0.8 + h + 3.0
    else:
        yl, yh = 0.8 + h, 0.8 + h + 1.8
        b.face([V(x0 - 0.8, yl, z0 - 1.0), V(x1 + 0.8, yl, z0 - 1.0), V(x1 + 0.8, yh, z1 + 0.8), V(x0 - 0.8, yh, z1 + 0.8)], "rf_forest", V(0, 1, -0.3))
        b.face([V(x0 - 0.8, yl + 0.45, z0 - 0.4), V(x1 + 0.8, yl + 0.45, z0 - 0.4), V(x1 + 0.8, yh + 0.45, z1 + 0.8), V(x0 - 0.8, yh + 0.45, z1 + 0.8)], "s_lit", V(0, 1, -0.3))
        for sx in (-1, 1):
            b.face([V(sx * 4.5, 0.8, z0), V(sx * 4.5, 0.8, z1), V(sx * 4.5, yh, z1), V(sx * 4.5, yl, z0)], "m_wood_2", V(sx, 0, 0))
        c = chimney(b, 2.4, 1.8, yh - 0.4, yh + 3.4, w=1.2)
        top = yh + 3.8
    return unit(b, "Lake", "near", "on the lake", authored=True, kind="fishhut", role=note, district=["FrozenLake"], height=top, smoke_socket=[round(c[0], 2), round(c[1], 2), round(c[2], 2)])


@recipe
def fl_fish_hut_a():
    return fish_hut("SP_FL_FishHut_A", True, "an ice-fishing hut 9 high: board walls, a teal gable roof with snow, a chimney")


@recipe
def fl_fish_hut_b():
    return fish_hut("SP_FL_FishHut_B", "across", "an ice-fishing hut 9 high: a slate gable across the road, a chimney")


# ================================================================ S2: props, animated parts, redraws
def prop_meta(kind, h, note, **kw):
    d = {"kind": kind, "height": h, "role": note, "district": "any"}
    d.update(kw)
    return d


@recipe
def prop_woodpile():
    b = L.new("SP_Prop_Woodpile")
    wood_pile(b, 0, 0, 5.4, 2.8, 2.2)
    for k in range(5):  # a few split logs lying in front, ends toward the road
        box(b, V(-2.0 + k * 1.0, 0.5, -2.0 - (k % 2) * 0.5), (0.7, 0.8, 1.4), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})
    return unit(b, "Prop", "near", "near layer", authored=True, **prop_meta("woodpile", 3.6, "a stack of split logs under a plank cap with snow"))


@recipe
def prop_sled():
    b = L.new("SP_Prop_Sled")
    for sx in (-1.1, 1.1):  # runners with an upturned nose
        box(b, V(sx, 0.55, 0.3), (0.35, 0.5, 5.4), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
        b.face([V(sx - 0.17, 0.3, -2.4), V(sx + 0.17, 0.3, -2.4), V(sx + 0.17, 1.5, -3.2), V(sx - 0.17, 1.5, -3.2)], "m_wood_2", V(0, 0, -1))
        b.face([V(sx - 0.17, 0.8, -2.4), V(sx - 0.17, 1.5, -3.2), V(sx - 0.17, 1.2, -2.2)], "m_wood_2", V(-1, 0, 0))
        b.face([V(sx + 0.17, 0.8, -2.4), V(sx + 0.17, 1.5, -3.2), V(sx + 0.17, 1.2, -2.2)], "m_wood_2", V(1, 0, 0))
    for k in range(4):  # slats
        box(b, V(0, 1.1, -1.8 + k * 1.5), (3.0, 0.4, 1.0), {"side": "w_roof_1", "top": "w_roof_1", "skip_bottom": True})
    box(b, V(0, 1.45, -2.6), (2.4, 0.18, 0.18), {"side": "bunt_cream"})  # a pull rope
    return unit(b, "Prop", "near", "near layer", authored=True, **prop_meta("sled", 1.8, "a wooden sled with berry slats and a rope"))


@recipe
def prop_skirack():
    b = L.new("SP_Prop_SkiRack")
    for sx in (-4.0, 4.0):
        snow_ring(b, sx, 0, 1.8, 0.8, 0.6)
        box(b, V(sx, 2.2, 0), (0.7, 4.4, 0.7), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    box(b, V(0, 4.2, 0), (9.0, 0.6, 0.7), {"side": "m_wood_2", "top": "s_half", "skip_bottom": True})
    box(b, V(0, 1.4, -0.5), (8.4, 0.5, 0.6), {"side": "m_wood_2", "top": "s_half", "skip_bottom": True})
    cols = ["bunt_teal", "w_roof_1", "bunt_honey", "bunt_green", "bunt_cream", "bunt_teal"]
    for k, c in enumerate(cols):  # six skis leaning on the top bar
        x = -3.4 + k * 1.36
        beam(b, V(x, 0.8, -1.9), V(x + 0.15, 7.2, -0.2), 0.45, 0.2, c)
    return unit(b, "Prop", "near", "near layer", authored=True, **prop_meta("skirack", 7.4, "a timber ski rack with six pairs of skis in the bunting colours"))


@recipe
def prop_lantern():
    b = L.new("SP_Prop_Lantern")
    snow_ring(b, 0, 0, 2.4, 1.2, 0.9)
    box(b, V(0, 1.3, 0), (1.6, 2.6, 1.6), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})  # a 2-stud collar
    cyl(b, V(0, 2.4, 0), 10.6, 0.45, 5, "m_wood_2", r_top=0.38)
    box(b, V(0.9, 12.4, 0), (2.2, 0.45, 0.45), {"side": "m_wood_2"})  # arm
    box(b, V(1.9, 11.9, 0), (0.25, 1.0, 0.25), {"side": "m_metal_dark"})
    box(b, V(2.0, 10.6, 0), (2.1, 2.2, 2.1), {"side": "honey_glow", "top": "honey_glow", "skip_bottom": False})  # honey glass, painted, never emissive
    for (x, z, sx, sz) in ((2.0, 0.0, 2.4, 0.3), (2.0, 0.0, 0.3, 2.4)):
        box(b, V(x, 10.6, z), (sx, 2.4, sz), {"side": "m_wood_2"})  # timber mullions
    frustum(b, 2.0, 11.7, 0.0, 1.5, 1.8, 0.0, 4, math.pi / 4, "m_wood_2", bottom="m_wood_2")
    box(b, V(2.0, 12.3, 0), (1.5, 0.3, 1.5), {"side": "s_lit", "top": "s_lit", "skip_bottom": True})
    return unit(b, "Prop", "near", "road edge", authored=True, **prop_meta("lantern", 15.0, "a timber lantern lamp post 15 tall with a 2-stud collar and a honey glass lantern on an arm; the lantern hangs toward +x (yaw it to face the road)", glow_socket=[2.0, 10.6, 0.0]))


@recipe
def prop_bench():
    b = L.new("SP_Prop_Bench")
    for sx in (-2.6, 2.6):
        box(b, V(sx, 1.0, 0), (0.6, 2.0, 2.2), {"side": "m_wood_2", "skip_bottom": True})
        box(b, V(sx, 2.6, 0.9), (0.6, 2.4, 0.5), {"side": "m_wood_2"})
    for z in (-0.7, 0.3):
        box(b, V(0, 2.1, z), (6.2, 0.35, 0.8), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    for y in (3.0, 3.8):
        box(b, V(0, y, 1.05), (6.2, 0.6, 0.3), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    return unit(b, "Prop", "near", "near layer", authored=True, **prop_meta("bench", 4.2, "a slatted timber bench with a backrest and a little snow"))


@recipe
def prop_bin():
    b = L.new("SP_Prop_Bin")
    box(b, V(0, 1.6, 0), (2.6, 3.2, 2.6), {"side": "rf_forest", "top": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 3.4, 0), (3.0, 0.5, 3.0), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    for z in (-1.32, 1.32):
        box(b, V(0, 1.6, z), (0.3, 2.6, 0.12), {"side": "m_wood_2"})
    frustum(b, 0, -0.3, 0, 0.8, 2.6, 1.9, 4, math.pi / 4, "s_half", top=None)
    return unit(b, "Prop", "near", "near layer", authored=True, **prop_meta("bin", 3.8, "a forest-green timber bin with a snow-capped lid"))


@recipe
def prop_trailmarker():
    b = L.new("SP_Prop_TrailMarker")
    snow_ring(b, 0, 0, 2.2, 1.0, 0.8)
    box(b, V(0, 3.8, 0), (0.7, 7.6, 0.7), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 8.2, 0.0), (5.0, 5.0, 0.6), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})  # the board
    zf = -0.35
    body = [(0, -2.0), (1.5, -1.7), (1.9, -0.4), (1.5, 1.0), (0.8, 1.7), (-0.8, 1.7), (-1.5, 1.0), (-1.9, -0.4), (-1.5, -1.7)]  # an owl: body, two ear tufts, two eyes, a beak
    b.face([V(x, 8.2 + y, zf) for x, y in body], "s_weather", V(0, 0, -1))
    b.face([V(-1.5, 8.2 + 1.0, zf - 0.05), V(-0.8, 8.2 + 1.7, zf - 0.05), V(-1.3, 8.2 + 2.4, zf - 0.05)], "s_weather", V(0, 0, -1))
    b.face([V(1.5, 8.2 + 1.0, zf - 0.05), V(0.8, 8.2 + 1.7, zf - 0.05), V(1.3, 8.2 + 2.4, zf - 0.05)], "s_weather", V(0, 0, -1))
    for ex in (-0.85, 0.85):
        eye = circle2(ex, 8.2 + 0.7, 0.62, 8)
        b.face([V(x, y, zf - 0.08) for x, y in [(p[0], p[1]) for p in eye]], "bunt_cream", V(0, 0, -1))
        eye2 = circle2(ex, 8.2 + 0.7, 0.28, 6)
        b.face([V(x, y, zf - 0.12) for x, y in [(p[0], p[1]) for p in eye2]], "m_black", V(0, 0, -1))
    b.face([V(-0.3, 8.2 + 0.1, zf - 0.1), V(0.3, 8.2 + 0.1, zf - 0.1), V(0.0, 8.2 - 0.6, zf - 0.1)], "bunt_honey", V(0, 0, -1))
    b.face([V(-1.3, 8.2 - 1.0, zf - 0.07), V(1.3, 8.2 - 1.0, zf - 0.07), V(0.9, 8.2 - 1.7, zf - 0.07), V(-0.9, 8.2 - 1.7, zf - 0.07)], "s_board", V(0, 0, -1))
    return unit(b, "Prop", "near", "trail", authored=True, **prop_meta("trailmarker", 10.8, "a trail marker: an original owl icon painted on a timber board on a post"))


def pennant_pole(b, x, z, h, col="bunt_teal"):
    snow_ring(b, x, z, 2.4, 1.2, 0.9)
    box(b, V(x, 1.3, z), (1.6, 2.6, 1.6), {"side": "m_wood_1", "top": "m_wood_2", "skip_bottom": True})  # 2-stud collar
    cyl(b, V(x, 2.4, z), h - 2.4, 0.4, 5, "m_metal", r_top=0.28)
    sphere(b, V(x, h + 0.4, z), (0.7, 0.7, 0.7), ["w_accent_1", "w_accent_1", "bunt_honey"], subdiv=0)
    ya, yb = h - 1.2, h - 5.2
    for s_, dz in ((1, 0.12), (-1, -0.12)):  # a two-sided swallow-tail pennant, 7 long
        b.face([V(x + 0.3, ya, z + dz), V(x + 7.2, (ya + yb) / 2 + 0.4, z + dz), V(x + 0.3, yb, z + dz)], col, V(0, 0, s_))


@recipe
def prop_pennantpole():
    b = L.new("SP_Prop_PennantPole")
    pennant_pole(b, 0, 0, 22.0)
    return unit(b, "Prop", "near", "road edge", authored=True, **prop_meta("pennantpole", 22.0, "a flag pole with a 2-stud collar and a two-sided teal pennant (no orange), the pennant streams toward +x"))


@recipe
def prop_garland24():
    rng = rng_of("SP_Prop_Garland24")
    b = L.new("SP_Prop_Garland24")
    for sx in (-12.0, 12.0):
        snow_ring(b, sx, 0, 2.2, 1.0, 0.8)
        cyl(b, V(sx, 0.4, 0), 15.6, 0.45, 5, "m_wood_2", r_top=0.36)
        box(b, V(sx, 16.2, 0), (1.0, 0.5, 1.0), {"side": "m_wood_1", "top": "s_lit", "skip_bottom": True})
    n = 8
    path = [V(-12.0 + 24.0 * k / n, 15.4 - 3.4 * math.sin(math.pi * k / n), 0) for k in range(n + 1)]  # a drooping string
    tube(b, path, 0.2, 3, "m_wood_1", phase=math.pi / 4)
    cols = ["bunt_teal", "bunt_green", "bunt_cream", "bunt_honey", "bunt_berry"]  # no orange
    for k in range(1, n):
        p = path[k]
        for s_, dz in ((1, 0.06), (-1, -0.06)):
            b.face([V(p.x - 1.0, p.y, p.z + dz), V(p.x + 1.0, p.y, p.z + dz), V(p.x, p.y - 2.6, p.z + dz)], cols[(k - 1) % 5], V(0, 0, s_))
    return unit(b, "Prop", "near", "road edge, parallel to the road", authored=True, **prop_meta("garland", 16.4, "static roadside bunting: two poles 24 apart, a drooping string of triangular flags in teal, green, cream, honey and berry; runs along x, never over the road", length=24.0))


# ---- animated parts
@recipe
def anim_skier():
    b = L.new("SP_Anim_Skier")
    for sx in (-0.6, 0.6):
        box(b, V(sx, 0.2, 0.2), (0.4, 0.3, 5.6), {"side": "bunt_cream", "top": "bunt_teal", "skip_bottom": True})  # skis
        beam(b, V(sx * 0.9, 0.4, 0.0), V(sx * 0.7, 2.8, 0.5), 0.5, 0.5, "m_wood_2")  # legs
    box(b, V(0, 3.9, 0.4), (1.8, 2.0, 1.1), {"side": "bunt_teal", "top": "bunt_teal", "skip_bottom": True})  # a jacket
    box(b, V(0, 2.9, 0.4), (1.8, 0.9, 1.1), {"side": "bunt_green", "top": "bunt_green", "skip_bottom": True})
    sphere(b, V(0, 5.3, 0.45), (0.7, 0.7, 0.7), ["w_wall_2", "w_wall_2", "bunt_cream"], subdiv=0)
    box(b, V(0, 5.8, 0.4), (1.5, 0.7, 1.5), {"side": "bunt_berry", "top": "bunt_berry", "skip_bottom": True})  # a hat
    for sx in (-1.4, 1.4):
        beam(b, V(sx * 0.8, 3.6, 0.8), V(sx, 0.2, -1.0), 0.28, 0.28, "m_metal_dark")  # poles
    return unit(b, "Anim", "near", "far slopes", authored=True, **prop_meta("skier", 6.0, "a skier 6 tall in the bunting colours (a berry hat, a teal jacket): one mesh, travels -z"))


@recipe
def anim_skater():
    b = L.new("SP_Anim_Skater")
    for sx in (-0.45, 0.45):
        box(b, V(sx, 0.25, 0.0), (0.35, 0.5, 1.8), {"side": "m_metal", "top": "m_metal_dark", "skip_bottom": True})  # skates
        beam(b, V(sx, 0.5, 0.0), V(sx, 2.4, 0.1), 0.5, 0.5, "bunt_green")
    box(b, V(0, 3.4, 0.1), (1.7, 1.9, 1.0), {"side": "bunt_honey", "top": "bunt_honey", "skip_bottom": True})  # a honey jacket
    sphere(b, V(0, 4.7, 0.1), (0.65, 0.65, 0.65), ["w_wall_2", "w_wall_2", "bunt_cream"], subdiv=0)
    box(b, V(0, 5.2, 0.1), (1.4, 0.6, 1.4), {"side": "bunt_teal", "top": "bunt_teal", "skip_bottom": True})
    for sx in (-1, 1):  # arms out for balance
        beam(b, V(sx * 0.9, 3.9, 0.1), V(sx * 2.6, 3.1, 0.2), 0.4, 0.4, "bunt_honey")
    return unit(b, "Anim", "near", "lake", authored=True, **prop_meta("skater", 5.4, "a skater 5 tall, arms out, in honey and teal"))


# ---- redraws
@recipe
def observatory():
    b = L.new("SP_LM_Observatory")
    W, D = 36.0, 30.0
    pad(b, W, D)
    cx, cz = 0.0, 16.0
    # a 14-stud stone plinth of four coursed bands (12 sides), then a cool white drum and dome
    for k in range(4):
        r0 = 13.4 - k * 0.3
        frustum(b, cx, k * 3.5 - 0.3, cz, 3.8 if k else 3.8, r0, r0 - 0.3, 12, 0.26, "s_stone" if k % 2 == 0 else "s_stone_lt", bottom=None, top="s_stone_lt" if k == 3 else None)
    snow_skirt(b, cx - 11.0, cx + 11.0, cz - 11.0, cz + 11.0, 2.5, out=3.2, y_out=0.5)
    frustum(b, cx, 13.5, cz, 1.0, 13.6, 13.6, 12, 0.26, "s_stone_lt", top="s_half")  # the cornice
    # steps and a door on the road side, a balustrade rail on the plinth top
    for k in range(3):
        h = 1.6 * (3 - k)
        box(b, V(cx, (h - 0.3) / 2, cz - 12.8 - k * 1.2), (6.4 - k * 0.5, h + 0.3, 1.2), {"side": "s_stone_dk", "top": "s_half", "skip_bottom": True})
    b.face([V(cx - 2.2, 4.8, cz - 13.2), V(cx + 2.2, 4.8, cz - 13.2), V(cx + 2.2, 11.4, cz - 13.2), V(cx - 2.2, 11.4, cz - 13.2)], "ice_void", V(0, 0, -1))
    box(b, V(cx, 8.1, cz - 13.5), (5.6, 7.0, 0.45), {"side": "m_wood_2", "skip_bottom": True, "skip_back": True})
    b.face([V(cx - 2.2, 4.8, cz - 13.8), V(cx + 2.2, 4.8, cz - 13.8), V(cx + 2.2, 11.4, cz - 13.8), V(cx - 2.2, 11.4, cz - 13.8)], "w_door", V(0, 0, -1))
    frustum(b, cx, 14.5, cz, 7.6, 11.4, 11.4, 12, 0.26, lambda k, nx, nz: "m_white" if (nx * LIGHT.x + nz * LIGHT.z) > 0.0 else "s_half", bottom=None, top=None)  # the drum
    ring_r = 11.4
    for k in range(6):  # dome rings
        a0, a1 = math.pi / 2 * k / 6, math.pi / 2 * (k + 1) / 6
        r0, r1 = ring_r * math.cos(a0), ring_r * math.cos(a1)
        frustum(b, cx, 22.1 + ring_r * math.sin(a0), cz, ring_r * (math.sin(a1) - math.sin(a0)) + 0.05, r0, max(0.0, r1), 12, 0.26, lambda kk, nx, nz, k=k: "m_white" if (nx * LIGHT.x + nz * LIGHT.z) > 0.0 else ("s_half" if k % 2 else "s_shade"))
    b.face([V(cx - 1.2, 23.6, cz - ring_r * 0.97), V(cx + 1.2, 23.6, cz - ring_r * 0.97), V(cx + 0.9, 31.6, cz - ring_r * 0.48), V(cx - 0.9, 31.6, cz - ring_r * 0.48)], "ice_void", V(0, 0.4, -1))  # the telescope slit
    cyl(b, V(cx, 33.4, cz), 3.4, 0.35, 4, "m_metal", r_top=0.1)
    sphere(b, V(cx, 36.9, cz), (0.9, 0.9, 0.9), ["w_accent_1", "w_accent_1", "bunt_honey"], subdiv=0)
    fence_run(b, -14.0, 14.0, 1.0, step=7.0, gate=(-4.0, 4.0), rails=2, h=3.0)
    return lm_finish(b, W, D, 38.0, ["SummitLodge"], read="the observatory: a cool white dome on a 14-stud coursed stone plinth, steps and a door on the road side")


@recipe
def warming_hut():
    b = L.new("SP_LM_WarmingHut")
    W, D = 36.0, 24.0
    pad(b, W, D)
    x0, x1, z0, z1 = -10.0, 10.0, 2.0, 16.0
    h_lo, h_hi = 10.0, 14.6
    fr, bk, lf, rt = house_base(b, x0, x1, z0, z1, "log", ("m_wood_1", "m_wood_2"), h_lo)
    # the mono-pitch hut: the log walls rise to the back, one roof slopes toward the road
    wall_panel(b, bk, x0, x1, PL + h_lo, PL + h_hi, "log", ("m_wood_1", "m_wood_2"))
    for wf, sgn, xx in ((lf, -1, x0), (rt, 1, x1)):
        b.face([V(xx, PL + h_lo, z0), V(xx, PL + h_lo, z1), V(xx, PL + h_hi, z1)], "m_wood_2", V(sgn, 0, 0))
    door(b, fr, -3.0, w=4.2, h=7.4)
    steps(b, fr, -3.0, 6.0)
    window(b, fr, 4.5, PL + 5.0, w=4.0, h=3.8, glow=True, frame="m_wood_2", shutter="rf_forest")
    window(b, lf, 8.0, PL + 5.0, w=3.2, h=3.6, frame="m_wood_2", sill=False)
    window(b, rt, 8.0, PL + 5.0, w=3.2, h=3.6, glow=True, frame="m_wood_2", sill=False)
    ye0, ye1 = PL + h_lo, PL + h_hi
    slope = (ye1 - ye0) / (z1 - z0)
    oe, tt = 2.2, 0.7
    za, zb = z0 - oe, z1 + 1.0
    ya, yb = ye0 - slope * oe, ye1 + slope * 1.0
    b.face([V(x0 - 1.0, ya, za), V(x1 + 1.0, ya, za), V(x1 + 1.0, yb, zb), V(x0 - 1.0, yb, zb)], "rf_forest", V(0, 1, -slope))
    b.face([V(x0 - 1.0, ya, za), V(x1 + 1.0, ya, za), V(x1 + 1.0, ya - tt, za), V(x0 - 1.0, ya - tt, za)], "m_wood_2", V(0, 0, -1))
    b.face([V(x0 - 1.0, yb, zb), V(x1 + 1.0, yb, zb), V(x1 + 1.0, yb - tt, zb), V(x0 - 1.0, yb - tt, zb)], "m_wood_2", V(0, 0, 1))
    for s_ in (-1, 1):
        b.face([V(s_ * (x1 + 1.0), ya, za), V(s_ * (x1 + 1.0), yb, zb), V(s_ * (x1 + 1.0), yb - tt, zb), V(s_ * (x1 + 1.0), ya - tt, za)], "m_wood_2", V(s_, 0, 0))
    b.face([V(x0 - 1.0, ya - tt, za), V(x1 + 1.0, ya - tt, za), V(x1 + 1.0, ye0 - tt, z0), V(x0 - 1.0, ye0 - tt, z0)], "m_wood_2", V(0, -1, 0))
    sn = 0.55
    b.face([V(x0 - 0.4, ya + slope * 1.2 + sn, za + 1.2), V(x1 + 0.4, ya + slope * 1.2 + sn, za + 1.2), V(x1 + 0.4, yb + sn - 0.2, zb - 0.6), V(x0 - 0.4, yb + sn - 0.2, zb - 0.6)], "s_lit", V(0, 1, -slope))
    b.face([V(x0 - 0.4, ya + slope * 1.2, za + 1.2), V(x1 + 0.4, ya + slope * 1.2, za + 1.2), V(x1 + 0.4, ya + slope * 1.2 + sn, za + 1.2), V(x0 - 0.4, ya + slope * 1.2 + sn, za + 1.2)], "s_half", V(0, 0, -1))
    sm = chimney(b, 6.5, 12.5, PL + h_hi - 1.0, PL + h_hi + 5.2, w=2.2)
    # a bench by the door and a woodpile at the end
    box(b, V(5.0, 1.5, z0 - 2.2), (6.0, 0.4, 1.6), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    for sx in (2.6, 7.4):
        box(b, V(sx, 0.7, z0 - 2.2), (0.5, 1.6, 1.4), {"side": "m_wood_2", "skip_bottom": True})
    wood_pile(b, 13.0, 8.0, 4.0, 2.6, 2.0)
    return lm_finish(b, W, D, PL + h_hi + 6.0, ["SkiLiftRidge"], sockets=lot_sockets(W, [sm]), read="the warming hut: log walls, a mono-pitch forest roof falling to the road, a chimney, a bench by the door")


@recipe
def festival_stage():
    b = L.new("SP_LM_FestivalStage")
    W, D = 32.0, 22.0
    pad(b, W, D)
    # a timber stage 24 x 14, 3.4 high on stone footings, steps on the road side, a back wall and two flats, two pennant poles
    sx0, sx1, sz0, sz1 = -12.0, 12.0, 6.0, 20.0
    sh = 3.4
    for x in (-11.0, 0.0, 11.0):
        for z in (7.0, 19.0):
            box(b, V(x, (sh - 0.3) / 2, z), (1.8, sh + 0.3, 1.8), {"side": "s_stone", "top": "s_stone_lt", "skip_bottom": True})
    box(b, V(0, sh - 0.4, (sz0 + sz1) / 2), (sx1 - sx0, 0.8, sz1 - sz0), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    fr = WallFrame("z", sz0, -1)
    b.face([fr.P(sx0, 0.4, 0.0), fr.P(sx1, 0.4, 0.0), fr.P(sx1, sh - 0.8, 0.0), fr.P(sx0, sh - 0.8, 0.0)], "m_wood_2", fr.n)
    for k in range(3):  # steps
        box(b, V(0, (1.1 * (3 - k) - 0.3) / 2, sz0 - 1.0 - k * 1.1), (6.0, 1.1 * (3 - k) + 0.3, 1.1), {"side": "s_stone_dk", "top": "s_half", "skip_bottom": True})
    # the back wall: boards in two tones, a cream banner panel (blank), side flats
    bk = WallFrame("z", sz1 - 0.4, 1)
    box(b, V(0, sh + 5.4, sz1 - 0.6), (sx1 - sx0, 10.8, 0.8), {"side": "m_wood_1", "top": "s_half", "skip_bottom": True})
    for i in range(6):
        b.face([V(sx0 + 4.0 * i, sh + 0.0 + 0.2, sz1 - 1.05), V(sx0 + 4.0 * (i + 1), sh + 0.2, sz1 - 1.05), V(sx0 + 4.0 * (i + 1), sh + 10.4, sz1 - 1.05), V(sx0 + 4.0 * i, sh + 10.4, sz1 - 1.05)], "s_board" if i % 2 else "m_wood_1", V(0, 0, -1))
    b.face([V(-7.0, sh + 3.0, sz1 - 1.15), V(7.0, sh + 3.0, sz1 - 1.15), V(7.0, sh + 8.4, sz1 - 1.15), V(-7.0, sh + 8.4, sz1 - 1.15)], "m_sign", V(0, 0, -1))
    for sg in (-1, 1):
        box(b, V(sg * 11.4, sh + 4.0, sz0 + 6.0), (0.8, 8.0, 12.0), {"side": "m_wood_2", "top": "s_half", "skip_bottom": True})  # side flats
    box(b, V(0, sh + 11.2, sz1 - 0.6), (sx1 - sx0 + 1.2, 0.8, 1.6), {"side": "m_wood_2", "top": "s_lit", "skip_bottom": True})
    pennant_pole(b, -14.0, 7.0, 20.0)
    pennant_pole(b, 14.0, 7.0, 20.0)
    return lm_finish(b, W, D, 24.0, ["SummitLodge"], read="the festival terrace stage: a 24 x 14 timber stage 3.4 high with steps, a back wall with a blank banner, side flats, two pennant poles", sign_face={"centre": [W / 2, 3.4 + 5.7, 18.85], "size": [14.0, 5.4]})


# ================================================================ build
def build_all(emit):
    P.report()
    for fn in RECIPES:
        b, meta = fn()
        emit(b, meta)
