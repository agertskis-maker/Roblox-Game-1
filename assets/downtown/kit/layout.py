# Downtown look development: the layout builder (pure Python; run it with any Python 3, for
# example Blender's bundled python.exe):
#   "C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe" assets/downtown/kit/layout.py \
#       --kit C:\Users\agert\Documents\Car-Hop-Art\downtown-kit --dir A
# Reads manifest.json (mesh bounds) from --kit, writes layout-<dir>.json and stats-<dir>.json.
#
# The layout JSON is the single placement source for the Studio builder:
#   instances[]: mesh, position [x, y, z] (studs, Roblox axes; the mesh's pivot), yaw (degrees,
#   CFrame.Angles(0, math.rad(yaw), 0)), scale (number or [x, y, z]), band, and for convenience
#   centre (world bounding-box centre) and size (scaled bounding-box size) so a MeshPart can be
#   set directly: MeshPart.Size = size, CFrame = CFrame.new(position) * Angles(0, yaw, 0) *
#   CFrame.new(local bbox centre * scale). Optional: sign_text, faces, anim, material, note.
# The road, hazards and street furniture are identical in A, B and C (common_* below); only the
# frontage, midground, skyline, signs and landmark change per direction.

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fixture as F  # noqa: E402

TITLES = {"A": "Sunny Toy City", "B": "Bright Real City", "C": "Big Bright Metropolis"}


def rot(yaw, v):
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c)


def vadd(a, b):
    return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]


class Layout:
    def __init__(self, d, manifest):
        self.d = d
        self.items = []
        self.man = {m["name"]: m for m in manifest}
        self.landmark_target = None

    def add(self, mesh, pos, yaw=0.0, scale=1.0, band="", **kw):
        if mesh not in self.man:
            raise KeyError(f"mesh {mesh} is not in the manifest")
        lo, hi = self.man[mesh]["bounds"]
        sc = (scale, scale, scale) if isinstance(scale, (int, float)) else tuple(scale)
        lc = [(lo[i] + hi[i]) / 2 * sc[i] for i in range(3)]
        size = [(hi[i] - lo[i]) * sc[i] for i in range(3)]
        centre = vadd(pos, rot(yaw, lc))
        it = {
            "mesh": mesh,
            "position": [round(v, 3) for v in pos],
            "yaw": round(((yaw + 180) % 360) - 180, 3),
            "scale": scale if isinstance(scale, (int, float)) else [round(v, 3) for v in scale],
            "band": band,
            "centre": [round(v, 3) for v in centre],
            "size": [round(v, 3) for v in size],
        }
        it.update(kw)
        if "sign_text" in kw:
            # the Studio builder reads `sign` (one string per sign instance); the faces to put it
            # on are the mesh's meta.faces in manifest.json (normal names like "Front")
            t = kw["sign_text"]
            it["sign"] = t if isinstance(t, str) else " / ".join(str(v) for v in t.values())
            it["faces"] = self.man[mesh]["meta"].get("faces", [])
        self.items.append(it)
        return it

    def add_local(self, mesh, base, yaw, local, extra_yaw=0.0, **kw):
        return self.add(mesh, vadd(base, rot(yaw, local)), yaw + extra_yaw, **kw)


# ---------------------------------------------------------------- frontage geometry helpers
def k_side(s, off):
    """Arc-length factor of a parallel line at lateral offset `off` (curve bends right)."""
    if F.STRAIGHT_A_END < s < F.CURVE_END:
        return (F.RADIUS - off) / F.RADIUS
    return 1.0


def advance(s, length, off):
    """The s reached after walking `length` studs along the line at lateral offset `off`."""
    done = 0.0
    step = 0.25
    while done < length:
        k = k_side(s, off)
        d = min(step * k, length - done)
        s += d / k
        done += d
    return s


def facade_pose(s_centre, side, setback=0.0):
    off = side * (F.FRONTAGE + setback)
    return F.point(s_centre, off), F.yaw_facing_road(s_centre, side)


# ---------------------------------------------------------------- common: road
def common_road(L):
    s = F.RUN_IN
    while s < F.RUN_OUT - 1e-6:
        if 240 <= s < 290:
            s = 290.0
            continue
        p, yaw = F.point(s), F.yaw_along(s)
        if F.STRAIGHT_A_END <= s < F.CURVE_END:
            L.add("RoadCurve20", p, yaw, band="road")
            L.add("MarksCurve20", p, yaw, band="road")
            L.add("SidewalkCurveInner20", p, yaw, band="road")
            L.add("SidewalkCurveOuter20", p, yaw, band="road")
        else:
            L.add("RoadStraight20", p, yaw, band="road")
            L.add("MarksStraight20", p, yaw, band="road")
            L.add("SidewalkStraight20", p, yaw, band="road")
            L.add("SidewalkStraight20", F.point(s + F.PIECE), yaw + 180, band="road")
        s += F.PIECE
    c, yaw = F.point(F.INTERSECTION_S), F.yaw_along(F.INTERSECTION_S)
    L.add("RoadIntersection", c, yaw, band="road")
    L.add("MarksIntersection", c, yaw, band="road")
    L.add("SidewalkCornerA", c, yaw, band="road", note="near-right corner")
    L.add("SidewalkCornerA", c, yaw + 180, band="road", note="far-left corner")
    L.add("SidewalkCornerB", c, yaw, band="road", note="near-left corner")
    L.add("SidewalkCornerB", c, yaw + 180, band="road", note="far-right corner")
    L.add("CrosswalkZebra", F.point(F.CROSSING_S), F.yaw_along(F.CROSSING_S), band="road")


# ---------------------------------------------------------------- common: hazards
def common_hazards(L):
    c = F.CONSTRUCTION
    lane = F.lane_offset(c["lane"])
    s0, s1 = c["s0"], c["s1"]
    for off in (lane - 3.05, lane + 3.05):
        L.add("Barrier", F.point(s0, off), F.yaw_along(s0) + 180, band="hazard", note="faces oncoming traffic")
    L.add("Barrier", F.point(s1, lane), F.yaw_along(s1) + 180, band="hazard")
    for k in range(8):
        s = s0 + 2.0 + (s1 - s0 - 3.0) * k / 7
        L.add("Cone", F.point(s, lane - 5.6), F.yaw_along(s), band="hazard")
    L.add("ConstructionSign", F.point(s0 + 5.0, lane + 1.0), F.yaw_along(s0) + 180, band="hazard")
    L.add("Crane", F.point(F.CRANE_S, F.CRANE_OFF), F.yaw_along(F.CRANE_S) + 180, band="hazard", note="on the lot behind the right sidewalk; jib parallel to the road, pointing back")
    # the crane's lot: hoarding along the frontage line and the lot's two ends
    lot0, lot1 = 92.0, 128.0
    for k in range(3):
        s = lot0 + 6 + 12 * k
        p, yaw = facade_pose(s, 1, 1.0)
        L.add("SiteFence", p, yaw, band="hazard")
    for s in (lot0, lot1):
        for k in range(3):
            off = F.FRONTAGE + 7.0 + 12 * k
            L.add("SiteFence", F.point(s, off), F.yaw_along(s) + 90, band="hazard")
    h = F.POTHOLE
    L.add("Pothole", F.point(h["s"], F.lane_offset(h["lane"])), F.yaw_along(h["s"]), band="hazard")
    o = F.OIL
    L.add("OilSlick", F.point(o["s"], F.lane_offset(o["lane"])), F.yaw_along(o["s"]), band="hazard", material="SmoothPlastic, Reflectance 0.25")


# ---------------------------------------------------------------- common: street furniture
def common_furniture(L, tree):
    R, Lf = 1, -1

    def at(mesh, s, off, yaw=None, **kw):
        side = 1 if off > 0 else -1
        y = F.CURB_H
        L.add(mesh, F.point(s, off, y), F.yaw_facing_road(s, side) if yaw is None else yaw, band="street", **kw)

    lamp_r = [10, 50, 90, 130, 170, 210, 300, 340, 380, 420, 460]
    lamp_l = [-10, 30, 70, 110, 150, 190, 230, 310, 350, 390, 430, 470]
    for s in lamp_r:
        at("Lamp", s, R * 31.0)
        at("LampLens", s, R * 31.0, material="Neon (dim)")
    for s in lamp_l:
        at("Lamp", s, Lf * 31.0)
        at("LampLens", s, Lf * 31.0, material="Neon (dim)")
    for s in [30, 80, 320, 360, 400, 440]:
        at(tree, s, R * 31.4)
    for s in [10, 50, 90, 170, 210, 330, 370, 410, 450]:
        at(tree, s, Lf * 31.4)
    at("BusStop", 128.0, Lf * 32.2)
    at("Bin", 120.0, Lf * 34.5)
    at("Hydrant", 76.0, R * 26.9)
    at("Hydrant", 300.0, Lf * 26.9)
    at("Bench", 64.0, R * 35.0)
    at("Bin", 68.5, R * 35.0)
    at("Bench", 160.0, Lf * 35.0)
    at("Bench", 330.0, R * 35.0)
    at("Bin", 334.5, R * 35.0)
    at("BikeRack", 345.0, Lf * 34.8, yaw=F.yaw_along(345.0))
    at("BikeRack", 24.0, R * 34.8, yaw=F.yaw_along(24.0))
    for s in (20, 80, 200, 340):
        at("Planter", s, Lf * 35.2)
    for s in (40, 350, 430):
        at("Planter", s, R * 35.2)
    # signals at the four corners, lenses toward oncoming traffic
    for s in (236.0, 294.0):
        y = F.yaw_along(s) + 180
        L.add("TrafficLight", F.point(s, 30.2, F.CURB_H), y, band="street", note="arm reaches toward the road but stays over the sidewalk")
        L.add("TrafficLight", F.point(s, -27.2, F.CURB_H), y, band="street")
    at("StreetSign", 238.5, Lf * 35.0, yaw=F.yaw_along(238.5))
    at("StreetSign", 291.5, R * 35.0, yaw=F.yaw_along(291.5))
    for s in (240.0, 290.0):
        for off in (-36.5, 36.5):
            at("Bollard", s, off)


# ---------------------------------------------------------------- frontage filling
def fill_block(s0, s1, side, rng, widths, alley_every=(2, 4), alley_w=(9, 12), corner_w=12.0, setback_p=0.2):
    """Plan buildings along [s0, s1] on one side. Returns a list of (kind, width, s_centre,
    setback) with kind 'corner' at block and alley ends and 'mid' between."""
    off = side * F.FRONTAGE
    out = []
    s = s0
    run = 0
    target = rng.randint(*alley_every)

    def room(w):
        return advance(s, w, off) <= s1

    if corner_w and room(corner_w):
        e = advance(s, corner_w, off)
        out.append(("corner", corner_w, (s + e) / 2, 0.0))
        s = e
    while True:
        w = rng.choice(widths)
        if not room(w + (corner_w or 0)):
            w = min(widths)
            if not room(w + (corner_w or 0)):
                break
        e = advance(s, w, off)
        sb = 2.5 if rng.random() < setback_p else 0.0
        out.append(("mid", w, (s + e) / 2, sb))
        s = e
        run += 1
        if run >= target and room(alley_w[1] + 2 * (corner_w or 0) + max(widths)):
            if corner_w:
                e = advance(s, corner_w, off)
                out.append(("corner", corner_w, (s + e) / 2, 0.0))
                s = e
            s = advance(s, rng.uniform(*alley_w), off)
            if corner_w:
                e = advance(s, corner_w, off)
                out.append(("corner", corner_w, (s + e) / 2, 0.0))
                s = e
            run = 0
            target = rng.randint(*alley_every)
    if corner_w and room(corner_w):
        e = advance(s, corner_w, off)
        out.append(("corner", corner_w, (s + e) / 2, 0.0))
    return out


def near_hazard(s, side):
    """Frontage beside the hazards is quieted (research O7): lower-contrast colourways."""
    if side > 0 and 80 <= s <= 140:
        return True
    if 160 <= s <= 220:
        return True
    return False


# ---------------------------------------------------------------- midground and skyline
CROSS_KEEP = (215.0, 315.0)


def midground(L, rng, meshes, rows=((65.0, 0.5), (118.0, 0.85)), spacing=(42, 58), s_range=(-140, 620), scale_fn=None):
    for side in (1, -1):
        for depth, tall_p in rows:
            off = side * (F.FRONTAGE + depth)
            s = s_range[0] + rng.uniform(0, 30)
            while s < s_range[1] - (60 if abs(off) < 100 else 0):
                if not (CROSS_KEEP[0] < s < CROSS_KEEP[1]):
                    mesh = rng.choice(meshes["tall"] if rng.random() < tall_p else meshes["low"])
                    p = F.point(s, off)
                    L.add(mesh, p, F.yaw_facing_road(s, side) + rng.uniform(-4, 4), band="midground")
                    if footprint_problem(L.items[-1]):
                        L.items.pop()
                s = advance(s, rng.uniform(*spacing), off)


def skyline(L, rng, shapes, w_rng, h_rng, d_rng, extra=None):
    """Two parallax layers each side, a closing vista ahead and a layer behind."""
    def put(s, off, near):
        mesh = rng.choice(shapes)
        w, h, d = rng.uniform(*w_rng), rng.uniform(*h_rng) * (0.75 if near else 1.0), rng.uniform(*d_rng)
        p = F.point(s, off)
        L.add(mesh, p, F.yaw_along(s) + rng.choice([0, 90]) + rng.uniform(-8, 8), scale=[w, h, d], band="skyline")

    for side in (1, -1):
        for (d0, d1, step, near) in ((300, 460, 70, True), (560, 860, 95, False)):
            s = -500 + rng.uniform(0, step)
            while s < 1000:
                put(s, side * (F.FRONTAGE + rng.uniform(d0, d1)), near)
                s += step * rng.uniform(0.8, 1.25)
    # the vista beyond the run-out (ahead) and behind the start
    for s0, s1 in ((780, 1100), (-760, -460)):
        s = s0
        while s < s1:
            off = -260
            while off < 260:
                put(s + rng.uniform(-30, 30), off + rng.uniform(-20, 20), s0 < 0)
                off += rng.uniform(70, 110)
            s += rng.uniform(140, 200)
    if extra:
        extra(L, rng)


def vista(L, rng, meshes, s_at=560.0, offs=(-84, -42, 0, 42, 84)):
    """Close the far end of the run-out (research O1: a closing block at the end of the view)."""
    for off in offs:
        s = s_at + rng.uniform(-6, 18)
        L.add(rng.choice(meshes), F.point(s, off), F.yaw_along(s) + 180 + rng.uniform(-3, 3), band="midground", note="vista closer beyond the run-out")


# ---------------------------------------------------------------- direction A
def compose_a(L, rng, kind, w, s_c, side, setback, quiet, storeys=None, cw=None, signs=None):
    pos, yaw = facade_pose(s_c, side, setback)
    if kind == "corner":
        cw = cw or rng.choice(["5", "4"])
        n = storeys if storeys is not None else rng.choice([1, 2, 2, 3])
        L.add(f"A_CornerBase_{cw}", pos, yaw, band="frontage")
        for k in range(n):
            L.add(f"A_CornerMid_{cw}", vadd(pos, [0, 16 + 12 * k, 0]), yaw, band="frontage")
        L.add(f"A_CornerTop_{cw}", vadd(pos, [0, 16 + 12 * n, 0]), yaw, band="frontage")
        return pos, yaw, 16 + 12 * n
    cw = "q" if quiet else (cw or rng.choice(["1", "2", "3", "4"]))
    n = storeys if storeys is not None else rng.choice([1, 1, 2, 2, 3])
    W = int(w)
    L.add(f"A_Base{W}_{cw}", pos, yaw, band="frontage")
    for k in range(n):
        mesh = f"A_Mid{W}_{cw}"
        if W == 24 and cw in ("2", "3") and rng.random() < 0.5:
            mesh = f"A_MidRound24_{cw}"
        L.add(mesh, vadd(pos, [0, 16 + 12 * k, 0]), yaw, band="frontage")
    top_y = 16 + 12 * n
    L.add(f"A_Top{W}_{cw}", vadd(pos, [0, top_y, 0]), yaw, band="frontage")
    if W == 24 and rng.random() < 0.6:
        L.add_local("A_RoofVent", pos, yaw, (rng.choice([-7, 7]), top_y + 0.3, 8.0), band="frontage")
    if rng.random() < 0.35:
        L.add_local("RoofAC", pos, yaw, (rng.uniform(-3, 3), top_y + 0.3, 10.0), band="frontage")
    return pos, yaw, top_y


def build_a(L, rng):
    common_road(L)
    common_hazards(L)
    common_furniture(L, "A_TreeToy")
    placed = []
    blocks = {1: [(-62, 90), (293.5, 482)], -1: [(-62, 236.5), (293.5, 482)]}
    for side, segs in blocks.items():
        for s0, s1 in segs:
            for kind, w, s_c, sb in fill_block(s0, s1, side, rng, [24, 24, 12]):
                q = near_hazard(s_c, side) and kind != "corner"
                pos, yaw, top_y = compose_a(L, rng, kind, w, s_c, side, sb, q)
                placed.append((kind, w, s_c, side, pos, yaw, top_y))
    # landmark: the DONUT DISTURB bakery on the right at s 150
    lm = F.LANDMARK["A"]
    pos, yaw = facade_pose(lm["s"], 1, 0.0)
    L.add("A_DonutBakery", pos, yaw, band="landmark")
    L.add_local("A_SignDonut", pos, yaw, (0, 12.4, -0.3), band="sign", sign_text="DONUT DISTURB")
    L.landmark_target = vadd(pos, rot(yaw, (0, 28 + 13.4, 7.5)))
    # breathing room after the bakery: a small pocket park (s 172 to 234, right)
    for s, off in ((182, 46), (198, 58), (214, 46), (228, 60), (190, 72), (222, 76)):
        L.add("A_TreeToy", F.point(s, off), 0.0, band="park")
    for s, off in ((186, 40.5), (206, 40.5), (226, 40.5)):
        L.add("Planter", F.point(s, off), F.yaw_facing_road(s, 1), band="park")
    for s in (196.0, 216.0):
        L.add("Bench", F.point(s, 52.0), F.yaw_facing_road(s, 1), band="park")
    # signs on chosen frontage buildings (blank faces; the text goes on SurfaceGuis)
    want = [("A_SignPizza", "WHEEL GOOD PIZZA", -1, 70.0), ("A_SignDiner", "BRAKE-FAST DINER", 1, 40.0), ("A_SignWash", "SUDS & SPOKES CAR WASH", -1, 185.0), ("A_SignPizza", "WHEEL GOOD PIZZA", 1, 330.0)]
    used = set()
    for mesh, text, side, s_t in want:
        cands = [p for p in placed if p[3] == side and p[0] == "mid" and p[1] == 24 and id(p) not in used]
        if not cands:
            continue
        best = min(cands, key=lambda p: abs(p[2] - s_t))
        used.add(id(best))
        L.add_local(mesh, best[4], best[5], (0, 11.8, -0.3), band="sign", sign_text=text)
    # the NAP HOTEL blade on the tallest building near s 320 on the left
    cands = [p for p in placed if p[3] == -1 and p[0] == "mid" and 290 < p[2] < 400]
    if cands:
        best = max(cands, key=lambda p: (p[6], -abs(p[2] - 330)))
        L.add_local("A_SignNap", best[4], best[5], (-best[1] / 2 + 2.0, 16.5, 0.0), band="sign", sign_text="TIRED? NAP HOTEL")
    midground(L, rng, {"low": [f"A_MidLow_{i}" for i in range(1, 5)], "tall": [f"A_MidTall_{i}" for i in range(1, 5)]})
    vista(L, rng, [f"A_MidTall_{i}" for i in range(1, 5)] + [f"A_MidLow_{i}" for i in range(1, 5)])
    skyline(L, rng, ["SkyRound_1", "SkyRound_2", "SkyRound_3", "SkySlab_1", "SkySlab_3"], (40, 90), (50, 120), (40, 80))


# ---------------------------------------------------------------- stats and checks
def camera_frustum_count(L, man, eye, target, fov_v=F.FOV_V, aspect=16 / 9, far=3000.0):
    fx, fy, fz = target[0] - eye[0], target[1] - eye[1], target[2] - eye[2]
    n = math.sqrt(fx * fx + fy * fy + fz * fz)
    f = (fx / n, fy / n, fz / n)
    up = (0, 1, 0)
    r = (f[1] * up[2] - f[2] * up[1], f[2] * up[0] - f[0] * up[2], f[0] * up[1] - f[1] * up[0])
    rn = math.sqrt(sum(c * c for c in r))
    r = tuple(c / rn for c in r)
    u = (r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0])
    tv = math.tan(math.radians(fov_v / 2))
    th = tv * aspect
    tris, count = 0, 0
    for it in L.items:
        c = it["centre"]
        rad = 0.5 * math.sqrt(sum(v * v for v in it["size"]))
        d = (c[0] - eye[0], c[1] - eye[1], c[2] - eye[2])
        z = sum(d[i] * f[i] for i in range(3))
        if z < -rad or z > far:
            continue
        x = sum(d[i] * r[i] for i in range(3))
        y = sum(d[i] * u[i] for i in range(3))
        zz = max(z, 0.1)
        if abs(x) - rad / math.cos(math.atan(th)) > zz * th or abs(y) - rad / math.cos(math.atan(tv)) > zz * tv:
            continue
        tris += man[it["mesh"]]["triangles"]
        count += 1
    return tris, count


def footprint_problem(it):
    """True when an instance's footprint touches the carriageway or the cross street."""
    c, sz, yaw = it["centre"], it["size"], it["yaw"]
    for sx in (-0.5, 0.0, 0.5):
        for sz_ in (-0.5, 0.0, 0.5):
            d = rot(yaw, (sx * sz[0], 0, sz_ * sz[2]))
            s, off = F.nearest(c[0] + d[0], c[2] + d[2])
            if F.RUN_IN - 5 <= s <= F.RUN_OUT + 5 and abs(off) < F.HALF:
                return True
            if 235.0 < s < 295.0 and abs(off) > F.HALF:
                return True
    return False


def checks(L):
    """Nothing but road and hazards on the carriageway; overhead pieces at least 40 up; no
    buildings in the cross street."""
    problems = []
    for it in L.items:
        if it["band"] in ("road", "hazard"):
            continue
        c, sz, yaw = it["centre"], it["size"], it["yaw"]
        pts = []
        for sx in (-0.5, 0.5):
            for sz_ in (-0.5, 0.5):
                d = rot(yaw, (sx * sz[0], 0, sz_ * sz[2]))
                pts.append((c[0] + d[0], c[2] + d[2]))
        pts.append((c[0], c[2]))
        bottom = c[1] - sz[1] / 2
        for x, z in pts:
            s, off = F.nearest(x, z)
            if F.RUN_IN - 5 <= s <= F.RUN_OUT + 5 and abs(off) < F.HALF - 0.01:
                if it.get("overhead") and bottom >= 40.0:
                    continue
                problems.append(f"{it['mesh']} at s {s:.0f} off {off:.1f} is over the carriageway")
                break
            if it["band"] in ("frontage", "landmark", "midground") and 237.2 < s < 292.8 and abs(off) > F.HALF and not it.get("overhead"):
                problems.append(f"{it['mesh']} at s {s:.0f} off {off:.1f} is in the cross street")
                break
    return problems


def write(L, kit):
    d = L.d
    man = L.man
    eye_frames = {}
    for s in F.CHASE_FRAMES:
        eye, tgt = F.chase_camera(s)
        eye_frames[f"chase-s{int(s):03d}"] = camera_frustum_count(L, man, eye, tgt)
    meshes = sorted({it["mesh"] for it in L.items})
    bands = {}
    for it in L.items:
        b = bands.setdefault(it["band"], {"instances": 0, "triangles": 0})
        b["instances"] += 1
        b["triangles"] += man[it["mesh"]]["triangles"]
    probs = checks(L)
    layout = {
        "direction": d,
        "title": TITLES[d],
        "units": "studs",
        "frame": "Roblox axes: +X right, car drives toward -Z, asphalt top y = 0; yaw = CFrame.Angles(0, rad(yaw), 0)",
        "palette": f"palette-{d}.png",
        "mesh_folder": "meshes",
        "environment": {
            "ground": {"y": -0.05, "swatch": "ground_lot", "note": "one large Part or terrain under everything"},
            "lighting": {"ClockTime": 13.5, "Brightness": 2.2, "note": "identical for A, B and C; same Atmosphere and ColorCorrection"},
            "atmosphere": {"note": "haze the skyline band (300 to 900 studs out)"},
        },
        "fixture": {
            "road_length": F.LENGTH,
            "lanes": F.LANES,
            "lane_width": F.LANE_W,
            "curve": {"s": [F.STRAIGHT_A_END, F.CURVE_END], "radius": F.RADIUS, "bends": "right"},
            "intersection_s": F.INTERSECTION_S,
            "crossing_s": F.CROSSING_S,
            "car": {"lane": F.CAR_LANE, "size": F.CAR_SIZE},
            "camera": {"behind": F.CAM_BEHIND, "above_car_centre": F.CAM_ABOVE, "look_ahead": F.LOOK_AHEAD, "look_y": F.LOOK_Y, "fov_vertical": F.FOV_V, "speed": F.SPEED},
            "chase_frames": F.CHASE_FRAMES,
            "run_in_out": [F.RUN_IN, F.RUN_OUT],
            "note": "PREVIEW values for Brian R to confirm (vault/design/specs/downtown-lookdev-fixture.md)",
        },
        "landmark_target": [round(v, 3) for v in L.landmark_target] if L.landmark_target else None,
        "instances": L.items,
    }
    path = os.path.join(kit, f"layout-{d}.json")
    with open(path, "w") as fh:
        head = {k: v for k, v in layout.items() if k != "instances"}
        txt = json.dumps(head, indent=1)[:-2]
        fh.write(txt + ',\n "instances": [\n')
        fh.write(",\n".join("  " + json.dumps(it, separators=(",", ":")) for it in L.items))
        fh.write("\n ]\n}\n")
    total = sum(man[it["mesh"]]["triangles"] for it in L.items)
    stats = {
        "direction": d,
        "title": TITLES[d],
        "unique_meshes": len(meshes),
        "unique_mesh_triangles": sum(man[m]["triangles"] for m in meshes),
        "instances": len(L.items),
        "triangles_all_instances": total,
        "triangles_in_view_estimate": {k: {"triangles": v[0], "instances": v[1]} for k, v in eye_frames.items()},
        "triangles_in_view_note": "frustum test of each instance's bounding sphere against the fixture chase camera (FOV 70 vertical, 16:9), no occlusion: an upper bound; the proxy car and traffic are not included",
        "bands": bands,
        "textures": [{"file": f"palette-{d}.png", "size": [256, 256], "shared_by": "every kit mesh"}],
        "transparent_effects": 0,
        "animated_objects": sum(1 for it in L.items if it.get("anim")),
        "signs": [
            {
                "mesh": it["mesh"],
                "text": it.get("sign_text"),
                "business": man[it["mesh"]]["meta"].get("business"),
                "faces": man[it["mesh"]]["meta"].get("faces", []),
                "position": it["position"],
                "yaw": it["yaw"],
            }
            for it in L.items
            if it.get("sign_text") is not None
        ],
        "checks": {"problems": probs, "rules": "nothing but road and hazard pieces on the carriageway; overhead pieces at least 40 studs up; no buildings in the cross street"},
        "meshes": meshes,
    }
    with open(os.path.join(kit, f"stats-{d}.json"), "w") as fh:
        json.dump(stats, fh, indent=1)
    print(f"{d}: {len(L.items)} instances, {len(meshes)} unique meshes, {total} triangles; in view {[(k, v[0]) for k, v in eye_frames.items()]}")
    for p in probs:
        print("  CHECK:", p)


def main():
    argv = sys.argv[1:]
    kit = argv[argv.index("--kit") + 1]
    d = argv[argv.index("--dir") + 1]
    with open(os.path.join(kit, "manifest.json")) as fh:
        manifest = json.load(fh)
    L = Layout(d, manifest)
    rng = random.Random({"A": 101, "B": 202, "C": 303}[d])
    if d == "A":
        build_a(L, rng)
    elif d == "B":
        import layout_b

        layout_b.build(L, rng, sys.modules[__name__])
    elif d == "C":
        import layout_c

        layout_c.build(L, rng, sys.modules[__name__])
    write(L, kit)


if __name__ == "__main__":
    main()
