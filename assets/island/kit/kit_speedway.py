# Island kit: the Speedway family (Lane 3), in the kit's smooth faceted language: bright, chamfered,
# kid-friendly, no studs, no real brands. Path prefix "speedway/". Every colour is an existing
# swatch (no palette change). Front faces -y; Blender x right, y back, z up; Roblox mesh-local is
# (x, z, -y). Meta points are Blender mesh-local from the mesh origin. A MeshPart is centred on its
# bounds: subtract the manifest bounds centre before placing anything on a MeshPart. Text is added
# later on SurfaceGuis at the face rectangles recorded in meta ("face": centre [x, z], size [w, h],
# plane_y, normal). The character's RIGHT side is -x and its LEFT side +x (it faces -y).
#   Rustic early levels   SwHayRun SwTyreRun SwTyreWall SwRopeFence SwOwnerSign SwWonkyStick
#                         SwRustyShed SwPaintedShed SwLemonadeStand SwFoldingChair SwStartBoard
#                         SwPennantPole SwWaterBarrel SwWheelbarrow
#   Fans and figures      SwBleachers SwFanA..D SwFanArmA..D SwOfficialPodium SwOfficialBody
#                         SwOfficialArm SwMechanic SwWrench
#   Mid levels            SwSnackCart SwLapBoard SwStartLights SwPitGarage SwRollDoor SwToolChest
#                         SwTyreStackTall SwGrandstandBay SwAnnouncerBooth SwFloodTower SwGantry
#                         SwGantryGold SwBigScreen
#   Late levels           SwCatchFence SwColumn SwColumnCap SwGuardRail SwOrangeBarrier
#                         SwFlameDecal SwBlimp SwLoopTrack SwStatuePedestal SwStatueCar
#                         SwRoofSection SwConfettiCannon SwFireworkRack SwPreviewCar

import math
import random

from mathutils import Matrix, Vector

from kit_plot import awning
from kit_portal import ball, cbox, cyl, dome, layered, oface, sweep, tface, torus
from kit_stunt import V, checker_y, extrude, quad_x, quad_y, quad_z
from kitlib import Builder

V0 = Vector((0, 0, 0))


# ---------------------------------------------------------------- helpers
class Xf:
    """A transformed view of a Builder: every face is rotated (degrees about x, then y, then z),
    scaled and moved first, so any helper (cbox, cyl, sweep ...) can build in a turned frame."""

    def __init__(self, b, pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        self.b = b
        m = (Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y")
             @ Matrix.Rotation(math.radians(rot[0]), 3, "X"))
        self.m = m @ Matrix.Diagonal(Vector(scale))
        self.pos = Vector(pos)
        self.flip = self.m.determinant() < 0

    def _t(self, verts):
        v = [self.pos + self.m @ Vector(p) for p in verts]
        if self.flip:
            v.reverse()
        return v

    def face(self, verts, swatch):
        return self.b.face(self._t(verts), swatch)

    def face2(self, verts, swatch):
        return self.b.face2(self._t(verts), swatch)

    def tri(self, a, b_, c, swatch):
        return self.face([a, b_, c], swatch)

    def quad(self, a, b_, c, d, swatch):
        self.face([a, b_, c], swatch)
        self.face([a, c, d], swatch)


def bx(b, c, s, sw, **kw):
    """A plain box (12 triangles). Per-face swatches: xm xp ym yp zm zp; None leaves a face out."""
    c = Vector(c)
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2

    def P(x, y, z):
        return c + Vector((x * hx, y * hy, z * hz))

    sides = {
        "xm": [P(-1, -1, -1), P(-1, 1, -1), P(-1, 1, 1), P(-1, -1, 1)],
        "xp": [P(1, -1, -1), P(1, 1, -1), P(1, 1, 1), P(1, -1, 1)],
        "ym": [P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), P(-1, -1, 1)],
        "yp": [P(-1, 1, -1), P(1, 1, -1), P(1, 1, 1), P(-1, 1, 1)],
        "zm": [P(-1, -1, -1), P(1, -1, -1), P(1, 1, -1), P(-1, 1, -1)],
        "zp": [P(-1, -1, 1), P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1)],
    }
    for key, pts in sides.items():
        s_ = kw.get(key, sw)
        if s_ is not None:
            oface(b, pts, s_, c)


def hexa(b, p, sw, sws=None, skip=()):
    """A convex hexahedron from 8 points (ring A = 0..3, ring B = 4..7, same order)."""
    p = [Vector(q) for q in p]
    c = sum(p, V0) / 8
    for k, f in enumerate(((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))):
        if k not in skip:
            oface(b, [p[i] for i in f], sws[k] if sws else sw, c)


def bar(b, p0, p1, w, sw, w2=None, up=(0, 0, 1), skip=()):
    """A box from point p0 to point p1 (12 triangles), section w x w2."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    ref = Vector(up)
    if abs(d.dot(ref)) > 0.98:
        ref = Vector((1, 0, 0))
    s = d.cross(ref).normalized() * (w / 2)
    u = s.cross(d).normalized() * ((w2 or w) / 2)
    hexa(b, [p0 - s - u, p0 + s - u, p0 + s + u, p0 - s + u, p1 - s - u, p1 + s - u, p1 + s + u, p1 - s + u], sw, skip=skip)


def strut(b, p0, p1, r, sw, n=3, r1=None):
    """An open n-sided bar from p0 to p1 (no caps: 2n triangles) for lattices and cables."""
    p0, p1 = Vector(p0), Vector(p1)
    cyl(b, p0, (p1 - p0).length, r, n, sw, r_top=r1, top=False, bottom=False, axis=p1 - p0)


def gem(b, c, rx, ry, rz, sw, n=6, phase=0.0):
    """A faceted bipyramid (2n triangles): lemons, popcorn, flower heads, small knobs."""
    c = Vector(c)
    ring = [c + V(math.cos(phase + 2 * math.pi * k / n) * rx, math.sin(phase + 2 * math.pi * k / n) * ry, 0) for k in range(n)]
    for k in range(n):
        oface(b, [ring[k], ring[(k + 1) % n], c + V(0, 0, rz)], sw, c)
        oface(b, [ring[k], ring[(k + 1) % n], c - V(0, 0, rz)], sw, c)


def lat(b, base, prof, sides, sws, phase=0.0, cap_top=None, cap_bot=None, alt=None, inward=()):
    """A surface of revolution about z: prof = [(r, z), ...]; one swatch per band (or one for all);
    alt = (a, b) alternates per side (staves); bands in `inward` face the axis (hole walls)."""
    base = Vector(base)
    rings = [[base + V(math.cos(phase + 2 * math.pi * k / sides) * r, math.sin(phase + 2 * math.pi * k / sides) * r, z)
              for k in range(sides)] for r, z in prof]
    for i in range(len(rings) - 1):
        sw = sws[i] if isinstance(sws, (list, tuple)) else sws
        z0, z1 = prof[i][1], prof[i + 1][1]
        flat = abs(z0 - z1) < 1e-9
        for k in range(sides):
            k2 = (k + 1) % sides
            pts = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            s = alt[k % 2] if alt else sw
            if flat:
                oface(b, pts, s, sum(pts, V0) / 4 - V(0, 0, 1))
            else:
                mid = base + V(0, 0, (z0 + z1) / 2)
                (tface if i in inward else oface)(b, pts, s, mid)
    if cap_top:
        oface(b, rings[-1], cap_top, sum(rings[-1], V0) / sides - V(0, 0, 1))
    if cap_bot:
        oface(b, rings[0], cap_bot, sum(rings[0], V0) / sides + V(0, 0, 1))


def tyre(b, c, axis, u, R, w, r_in, steps, sws, a0=0.0, a1=360.0, shoulder=0.22):
    """A tyre: axle along `axis`, angle measured from `u` toward axis x u; hexagonal section."""
    c = Vector(c)
    a = Vector(axis).normalized()
    u = Vector(u).normalized()
    v = a.cross(u)
    sh = shoulder * w
    prof = [(R, -0.36 * w), (R, 0.36 * w), (R - sh, 0.5 * w), (r_in, 0.5 * w), (r_in, -0.5 * w), (R - sh, -0.5 * w)]
    closed = abs(a1 - a0 - 360.0) < 1e-6
    rings = []
    for i in range(steps if closed else steps + 1):
        t = math.radians(a0 + (a1 - a0) * i / steps)
        d = u * math.cos(t) + v * math.sin(t)
        rings.append([c + d * r + a * x for r, x in prof])
    for i in range(steps):
        j = (i + 1) % len(rings)
        tm = math.radians(a0 + (a1 - a0) * (i + 0.5) / steps)
        inside = c + (u * math.cos(tm) + v * math.sin(tm)) * (R + r_in) / 2
        for k in range(6):
            oface(b, [rings[i][k], rings[i][(k + 1) % 6], rings[j][(k + 1) % 6], rings[j][k]], sws[k], inside)


def loft(b, rings, sws, cap_a=None, cap_b=None):
    """Bands between rings of equal length (a ring of one point is a tip); sws is a swatch, a list
    per sector, or f(band, sector)."""
    for i in range(len(rings) - 1):
        a, c = rings[i], rings[i + 1]
        inside = (sum(a, V0) / len(a) + sum(c, V0) / len(c)) / 2
        n = max(len(a), len(c))
        for k in range(n):
            k2 = (k + 1) % n
            sw = sws(i, k) if callable(sws) else (sws[k] if isinstance(sws, (list, tuple)) else sws)
            if len(a) == 1:
                oface(b, [a[0], c[k], c[k2]], sw, inside)
            elif len(c) == 1:
                oface(b, [a[k], a[k2], c[0]], sw, inside)
            else:
                oface(b, [a[k], a[k2], c[k2], c[k]], sw, inside)
    if cap_a and len(rings[0]) > 1:
        oface(b, rings[0], cap_a, sum(rings[1], V0) / len(rings[1]))
    if cap_b and len(rings[-1]) > 1:
        oface(b, rings[-1], cap_b, sum(rings[-2], V0) / len(rings[-2]))


def planks_y(b, x0, x1, z0, z1, y, n, sw_a, sw_b, facing=-1, lean=0.0):
    """n vertical plank quads side by side on the plane y (alternating swatches)."""
    w = (x1 - x0) / n
    for i in range(n):
        quad_y(b, x0 + i * w, x0 + (i + 1) * w, z0, z1, y, sw_a if i % 2 == 0 else sw_b, facing)


def planks_x(b, y0, y1, z0, z1, x, n, sw_a, sw_b, facing):
    w = (y1 - y0) / n
    for i in range(n):
        quad_x(b, y0 + i * w, y0 + (i + 1) * w, z0, z1, x, sw_a if i % 2 == 0 else sw_b, facing)


def r3(v):
    return [round(float(c), 3) for c in v]


def lerp_path(path, z):
    """The point on a polyline at height z (the polyline rises monotonically in z)."""
    for p, q in zip(path, path[1:]):
        if p.z <= z <= q.z:
            t = (z - p.z) / (q.z - p.z)
            return p + (q - p) * t
    return path[-1]


# ---------------------------------------------------------------- rustic: hay, tyres, fence
def hay_run(name):
    b = Builder(name)
    rng = random.Random(11)
    xs = (-3.15, 0.0, 3.15)
    for x in xs:
        sz = (3.0 + rng.uniform(-0.05, 0.05), 1.6 + rng.uniform(-0.05, 0.05), 1.4 + rng.uniform(-0.04, 0.04))
        xf = Xf(b, pos=(x + rng.uniform(-0.03, 0.03), rng.uniform(-0.05, 0.05), sz[2] / 2 + 0.03),
                rot=(rng.uniform(-1.5, 1.5), 0, rng.uniform(-2.5, 2.5)))
        cbox(xf, V0, sz, "straw", c=0.14, top="fruit_yellow", edge="straw")
        for bx_ in (-0.8, 0.8):
            bx(xf, V(bx_, 0, 0), (0.1, sz[1] + 0.05, sz[2] + 0.05), "rope")
    return b, {"length": 9.3, "bales": 3, "origin": "footprint centre on the ground", "front": "-y"}


def tyre_run(name):
    b = Builder(name)
    xs = (-2.95, -0.98, 0.98, 2.95)
    yaw = (8, -6, 5, -9)
    lean = (3, -4, 2, 4)
    for x, ya, ln in zip(xs, yaw, lean):
        xf = Xf(b, pos=(x, 0, 0.02), rot=(ln, 0, ya))
        tyre(xf, V0, (0, -1, 0), (1, 0, 0), 0.9, 0.6, 0.42, 5,
             ["raccoon_dark", "raccoon_dark", "black", "black", "black", "raccoon_dark"], a0=-12, a1=192)
        # a low mound of earth round the foot of each tyre
        hexa(xf, [V(-0.92, -0.62, -0.18), V(0.92, -0.62, -0.18), V(0.92, 0.62, -0.18), V(-0.92, 0.62, -0.18),
                  V(-0.74, -0.4, 0.14), V(0.74, -0.4, 0.14), V(0.74, 0.4, 0.14), V(-0.74, 0.4, 0.14)], "dirt", skip=(0,))
    return b, {"length": 8.0, "tyres": 4, "radius": 0.9, "width": 0.6, "origin": "footprint centre; tyre centres on the ground line (half buried)",
               "front": "-y", "note": "tyre axles along y; the buried half is left open below the ground"}


def tyre_wall(name):
    b = Builder(name)
    R, H, cols = 0.866, 2.0 / 3.0, 5
    ph = math.pi / 8
    for i in range(cols):
        x = (i - 2) * 1.85
        for j in range(3):
            sw = "cart_red" if (i + j) % 2 == 0 else "cart_white"
            z0 = j * H
            if j == 2:
                lat(b, V(x, 0, z0), [(R, 0), (R, H - 0.1), (R - 0.1, H), (0.42, H)], 8,
                    [sw, sw, sw], phase=ph, cap_top="black")
            else:
                lat(b, V(x, 0, z0), [(R, 0), (R, H)], 8, sw, phase=ph)
    # a black strap round the wall at mid height, with two bright buckles
    bx(b, V(0, -0.84, 1.0), (9.0, 0.06, 0.2), "metal", yp=None, zm=None)
    bx(b, V(0, 0.84, 1.0), (9.0, 0.06, 0.2), "metal", ym=None, zm=None)
    for x in (-2.8, 2.8):
        bx(b, V(x, -0.86, 1.0), (0.34, 0.06, 0.3), "iron_hi")
    return b, {"length": 9.0, "depth": 1.6, "height": 2.0, "columns": cols, "origin": "footprint centre on the ground", "front": "-y"}


def rope_fence(name):
    b = Builder(name)
    xs = (-4.4, -1.47, 1.47, 4.4)
    rng = random.Random(5)
    for x in xs:
        xf = Xf(b, pos=(x, 0, 0), rot=(rng.uniform(-2, 2), 0, rng.uniform(-3, 3)))
        lat(xf, V0, [(0.12, 0), (0.12, 1.45), (0.06, 1.62)], 6, "bark_warm", cap_top="log_inner")
    for z in (1.28, 0.82):
        path = []
        for i in range(len(xs)):
            path.append(V(xs[i], -0.15, z))
            if i + 1 < len(xs):
                path.append(V((xs[i] + xs[i + 1]) / 2, -0.15, z - 0.2))
        sweep(b, path, 0.045, 4, "rope")
    return b, {"length": 9.0, "posts": 4, "post_height": 1.62, "origin": "footprint centre on the ground", "front": "-y"}


def owner_sign(name):
    b = Builder(name)
    tilt = 2.5
    for x in (-2.7, 2.7):
        lat(b, V(x, 0.05, 0), [(0.14, 0), (0.14, 3.95), (0.07, 4.2)], 6, "bark_warm", cap_top="log_inner")
    xf = Xf(b, pos=(0, -0.28, 2.3), rot=(0, tilt, 0))
    cbox(xf, V0, (7.0, 0.22, 2.2), "plank", c=0.05, edge="plank_dark")
    fy = -0.11 - 0.04
    for z in (1.1 - 0.13, -(1.1 - 0.13)):
        bx(xf, V(0, fy, z), (7.0, 0.08, 0.26), "plank_dark")
    for x in (-3.5 + 0.13, 3.5 - 0.13):
        bx(xf, V(x, fy, 0), (0.26, 0.08, 1.68), "plank_dark")
    bx(xf, V(0, -0.125, 0), (6.48, 0.03, 1.68), "sign_board")
    for z in (-0.55, 0.55):
        bx(xf, V(0, 0.07, z), (7.2, 0.2, 0.2), "plank_dark")
    return b, {
        "origin": "footprint centre on the ground", "front": "-y", "tilt_deg": tilt,
        "face": {"centre": [0.0, 2.3], "size": [6.4, 1.6], "plane_y": round(-0.28 - 0.125, 3), "normal": [0, -1, 0],
                 "roll_deg": tilt, "note": "the board is turned about y by roll_deg (tilt), so the text is rolled by the same angle"},
        "board": [7.0, 2.2], "board_bottom": 1.2,
    }


STICK_PATH = [V(0, 0, 0), V(0.08, 0, 1.2), V(-0.05, 0.02, 2.5), V(0.12, 0, 3.8), V(0.02, -0.02, 5.0), V(0.15, 0, 6.0)]


def wonky_stick(name):
    b = Builder(name)
    sweep(b, STICK_PATH, [0.14, 0.12, 0.1, 0.09, 0.08, 0.065], 5, "bark_warm")
    gem(b, V(0.15, 0, 6.08), 0.1, 0.1, 0.12, "log_inner", n=5)
    top, bot = lerp_path(STICK_PATH, 5.6), lerp_path(STICK_PATH, 3.9)
    return b, {"height": 6.1, "flag_top": r3(top), "flag_bottom": r3(bot), "flag_side": "+x", "origin": "foot on the ground"}


# ---------------------------------------------------------------- sheds
SHED_W, SHED_D, SHED_ZW = 5.4, 4.4, 3.7
ROOF_X, EAVE_Y, ZE, ZR = 3.0, 2.55, 3.52, 5.0
DOOR_X, WIN_X = 1.4, -1.3


def roof_z(x, u):
    """Roof height at x and fall fraction u (0 eave, 1 ridge); the ridge runs a hair crooked."""
    ze = ZE + 0.04 * x / ROOF_X
    zr = ZR + 0.10 * x / ROOF_X
    return ze + (zr - ze) * u


def corrugated(b, side, sws, amp=0.07, segs=24):
    """One roof slope (side -1 front, +1 back): zig-zag strips down the fall, a flat underside, closed ends."""
    xs = [-ROOF_X + 2 * ROOF_X * j / segs for j in range(segs + 1)]
    off = [amp if j % 2 else 0.0 for j in range(segs + 1)]
    ye = side * EAVE_Y
    for j in range(segs):
        pts = [V(xs[j], ye, roof_z(xs[j], 0) + off[j]), V(xs[j + 1], ye, roof_z(xs[j + 1], 0) + off[j + 1]),
               V(xs[j + 1], 0, roof_z(xs[j + 1], 1) + off[j + 1]), V(xs[j], 0, roof_z(xs[j], 1) + off[j])]
        oface(b, pts, sws[j], V((xs[j] + xs[j + 1]) / 2, ye / 2, roof_z(0, 0.5) - 1))
    t = 0.07
    under = [V(-ROOF_X, ye, roof_z(-ROOF_X, 0) - t), V(ROOF_X, ye, roof_z(ROOF_X, 0) - t),
             V(ROOF_X, 0, roof_z(ROOF_X, 1) - t), V(-ROOF_X, 0, roof_z(-ROOF_X, 1) - t)]
    oface(b, under, "plank_dark", V(0, ye / 2, roof_z(0, 0.5) + 1))
    for x in (-ROOF_X, ROOF_X):
        oface(b, [V(x, ye, roof_z(x, 0)), V(x, 0, roof_z(x, 1)), V(x, 0, roof_z(x, 1) - t), V(x, ye, roof_z(x, 0) - t)],
              sws[0] if x < 0 else sws[-1], V(0, ye / 2, roof_z(0, 0.5)))


def shed(name, painted):
    b = Builder(name)
    rng = random.Random(23 if not painted else 24)
    hw, hd = SHED_W / 2, SHED_D / 2
    trim = "cart_white" if painted else "bark_dark"
    # plinth, walls and the two gable triangles
    bx(b, V(0, 0, 0.125), (5.6, 4.6, 0.25), "stone_light" if painted else "concrete", zm=None)
    bx(b, V(0, 0, (0.25 + SHED_ZW) / 2), (SHED_W, SHED_D, SHED_ZW - 0.25), "stone_light" if painted else "plank_dark", zm=None, zp=None)
    for sx in (-1, 1):
        oface(b, [V(sx * hw, -hd, SHED_ZW), V(sx * hw, hd, SHED_ZW), V(sx * hw, 0, 4.9)], "cream" if painted else "plank_dark", V(0, 0, 3.8))
    # siding: alternating boards (weathered and random when rusty)
    pal = ["cream", "stone_light"] if painted else ["plank", "plank_dark", "bark_warm", "plank_dark"]

    def pick(i):
        return pal[i % 2] if painted else pal[rng.randrange(len(pal))]

    nf = 8 if painted else 12
    ns = 6 if painted else 10
    for i in range(nf):
        w = SHED_W / nf
        quad_y(b, -hw + i * w, -hw + (i + 1) * w, 0.25, SHED_ZW, -hd - 0.02, pick(i), -1)
        quad_y(b, -hw + i * w, -hw + (i + 1) * w, 0.25, SHED_ZW, hd + 0.02, pick(i + 1), 1)
    for i in range(ns):
        w = SHED_D / ns
        quad_x(b, -hd + i * w, -hd + (i + 1) * w, 0.25, SHED_ZW, -hw - 0.02, pick(i), -1)
        quad_x(b, -hd + i * w, -hd + (i + 1) * w, 0.25, SHED_ZW, hw + 0.02, pick(i + 1), 1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(b, V(sx * (hw + 0.01), sy * (hd + 0.01), (0.25 + 3.5) / 2), (0.22, 0.22, 3.5 - 0.25), trim, zm=None)
    # roof: corrugated sheets, ridge cap, eave boards
    if painted:
        sws = ["teal" if j % 2 == 0 else "teal_dark" for j in range(24)]
        sws_b = sws
    else:
        base = ["sand_red", "sand_dark"]
        sws = [base[j % 2] for j in range(24)]
        for j in (7, 8, 9):
            sws[j] = "iron"
        sws[15] = "sand_orange"
        sws_b = [base[j % 2] for j in range(24)]
        for j in (16, 17):
            sws_b[j] = "iron"
        sws_b[4] = "sand_orange"
    corrugated(b, -1, sws)
    corrugated(b, 1, sws_b)
    tilt_r = -math.degrees(math.atan2(0.20, 2 * ROOF_X))
    cbox(Xf(b, pos=(0, 0, roof_z(0, 1) + 0.09), rot=(0, tilt_r, 0)), V0, (6.0, 0.6, 0.2), "cream" if painted else "iron", c=0.07)
    tilt_e = -math.degrees(math.atan2(0.08, 2 * ROOF_X))
    for sy in (-1, 1):
        bx(Xf(b, pos=(0, sy * (EAVE_Y + 0.02), roof_z(0, 0) - 0.08), rot=(0, tilt_e, 0)), V0, (6.0, 0.1, 0.24), trim)
    # door
    dz0, dz1 = 0.25, 2.9
    dy = -hd - 0.02
    for sx in (-1, 1):
        bx(b, V(DOOR_X + sx * 0.82, dy - 0.06, (dz0 + dz1) / 2), (0.14, 0.14, dz1 - dz0 + 0.1), trim, zm=None)
    bx(b, V(DOOR_X, dy - 0.06, dz1 + 0.05), (1.78, 0.14, 0.14), trim)
    bx(b, V(DOOR_X, dy - 0.03, (dz0 + dz1) / 2 - 0.02), (1.5, 0.1, dz1 - dz0 - 0.1), "teal_dark" if painted else "plank_dark", zm=None)
    if painted:
        for z in (0.95, 2.05):
            bx(b, V(DOOR_X, dy - 0.1, z), (1.06, 0.04, 0.8 if z < 1.5 else 0.7), "teal", zm=None)
        bx(b, V(DOOR_X + 0.55, dy - 0.12, 1.5), (0.1, 0.1, 0.1), "brass")
    else:
        bar(b, V(DOOR_X - 0.6, dy - 0.1, 0.55), V(DOOR_X + 0.6, dy - 0.1, 2.6), 0.05, "plank", w2=0.2)
        for z in (0.6, 2.55):
            bx(b, V(DOOR_X, dy - 0.1, z), (1.4, 0.05, 0.2), "plank")
        for z in (0.9, 2.3):
            bx(b, V(DOOR_X - 0.62, dy - 0.11, z), (0.3, 0.05, 0.1), "iron")
        bx(b, V(DOOR_X + 0.55, dy - 0.1, 1.5), (0.1, 0.1, 0.1), "iron_hi")
    # window
    wz = 2.0
    if painted:
        for sx in (-1, 1):
            bx(b, V(WIN_X + sx * 0.7, dy - 0.05, wz), (0.14, 0.12, 1.2), trim)
        for sz in (-1, 1):
            bx(b, V(WIN_X, dy - 0.05, wz + sz * 0.55), (1.54, 0.12, 0.12), trim)
        bx(b, V(WIN_X, dy - 0.04, wz), (1.26, 0.04, 0.98), "glass_tint")
        bx(b, V(WIN_X, dy - 0.08, wz), (0.07, 0.05, 0.98), trim)
        # window box with flowers
        bx(b, V(WIN_X, dy - 0.3, 1.3), (1.6, 0.36, 0.3), "teal", zp=None)
        bx(b, V(WIN_X, dy - 0.3, 1.46), (1.5, 0.3, 0.06), "dirt")
        for k, sw in enumerate(("tulip_red", "awning_yellow", "daisy_white", "coral", "lavender")):
            gem(b, V(WIN_X - 0.6 + 0.3 * k, dy - 0.3, 1.62 + 0.04 * (k % 2)), 0.1, 0.1, 0.12, sw, n=4)
        bx(b, V(WIN_X, dy - 0.3, 1.52), (1.44, 0.22, 0.1), "leaf_mid", zm=None)
        bx(b, V(0.0, dy - 0.45, 0.325), (1.9, 0.7, 0.15), "stone_light", zm=None)
    else:
        bx(b, V(WIN_X, dy - 0.03, wz), (1.3, 0.04, 1.1), "black")
        for sx in (-1, 1):
            bx(b, V(WIN_X + sx * 0.7, dy - 0.06, wz), (0.12, 0.1, 1.2), trim)
        for sz in (-1, 1):
            bx(b, V(WIN_X, dy - 0.06, wz + sz * 0.56), (1.5, 0.1, 0.12), trim)
        for k, z in enumerate((wz - 0.25, wz + 0.05, wz + 0.33)):
            bx(Xf(b, pos=(WIN_X, dy - 0.1, z), rot=(0, (-4, 3, -2)[k], 0)), V0, (1.45, 0.05, 0.22), "plank")
        # a leaning spare plank, two patches and a stovepipe
        bar(b, V(2.35, dy - 0.2, 0.25), V(2.25, dy - 0.12, 2.1), 0.07, "plank", w2=0.35)
        bx(b, V(-0.1, dy - 0.0, 1.0), (0.8, 0.02, 0.5), "plank", ym="plank")
        bx(b, V(hw + 0.02, 1.0, 2.4), (0.02, 0.8, 0.6), "plank_dark")
        lat(b, V(-1.6, 1.3, roof_z(-1.6, 0.49) - 0.1), [(0.17, 0), (0.17, 0.8)], 6, "iron", cap_top="black")
        lat(b, V(-1.6, 1.3, roof_z(-1.6, 0.49) + 0.7), [(0.17, 0), (0.28, 0.06), (0.28, 0.12)], 6, "iron", cap_top="iron_hi")
    meta = {
        "origin": "footprint centre on the ground", "front": "-y", "footprint": [6.0, 5.0], "height": round(roof_z(ROOF_X, 1) + 0.2, 3),
        "walls": [SHED_W, SHED_D], "door": {"x": DOOR_X, "width": 1.5, "z": [dz0, dz1]},
        "window": {"x": WIN_X, "z": wz, "size": [1.3, 1.1]}, "ridge": {"z": ZR, "crooked_rise_over_length": 0.2},
        "note": "SwRustyShed and SwPaintedShed share footprint and silhouette",
    }
    return b, meta


# ---------------------------------------------------------------- lemonade stand
def lemonade_stand(name):
    b = Builder(name)
    bx(b, V(0, 0.15, 0.55), (3.3, 1.5, 1.1), "plank_dark", zm=None)
    planks_y(b, -1.65, 1.65, 0.0, 1.1, -0.62, 8, "plank", "bark_warm", -1)
    cbox(b, V(0, 0.05, 1.18), (3.5, 1.7, 0.16), "plank", c=0.05, top="log_inner", edge="plank_dark")
    for x in (-1.6, 1.6):
        bx(b, V(x, -0.85, 1.14), (0.16, 0.16, 2.28 - 0.0), "bark_warm", zm=None)
        bx(b, V(x, 0.85, 1.33), (0.16, 0.16, 2.66), "bark_warm", zm=None)
    bx(b, V(0, 0.9, 1.96), (3.2, 0.1, 1.4), "plank", ym="plank_dark", zm=None, zp=None)
    awning(b, -1.75, 1.75, 0.95, -1.0, 2.65, 2.3, 8, "awning_yellow", "cart_white", drop=0.25)
    # header board on two short uprights above the back of the awning
    for x in (-1.4, 1.4):
        bx(b, V(x, 0.98, 2.88), (0.14, 0.12, 0.5), "bark_warm", zm=None)
    cbox(b, V(0, 0.92, 2.9), (3.3, 0.14, 0.6), "plank_dark", c=0.04, edge="plank")
    bx(b, V(0, 0.92 - 0.085, 2.9), (2.9, 0.03, 0.4), "sign_board")
    # pitcher with a handle, lemons and two cups on the counter
    pz = 1.26
    lat(b, V(-0.9, -0.1, pz), [(0.2, 0), (0.28, 0.12), (0.3, 0.5), (0.25, 0.62)], 8, ["lemon", "lemon", "glass"], cap_top="lemon")
    sweep(b, [V(-0.62, -0.1, pz + 0.55), V(-0.42, -0.1, pz + 0.5), V(-0.4, -0.1, pz + 0.25), V(-0.62, -0.1, pz + 0.12)], 0.04, 4, "glass")
    for x, y, z, sw in ((0.55, -0.05, 0.14, "lemon"), (0.95, -0.2, 0.14, "fruit_yellow"), (1.05, 0.25, 0.14, "lemon"), (0.78, 0.2, 0.38, "fruit_yellow")):
        gem(b, V(x, y, pz + z), 0.2, 0.17, 0.14, sw, n=6)
    for x, y in ((-0.2, 0.3), (0.05, 0.36)):
        lat(b, V(x, y, pz), [(0.1, 0), (0.13, 0.24)], 6, "cart_white", cap_top="lemon")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "footprint": [3.5, 2.0], "height": 3.2,
               "face": {"centre": [0.0, 2.9], "size": [2.9, 0.4], "plane_y": round(0.92 - 0.085 - 0.015, 3), "normal": [0, -1, 0]},
               "counter_top": 1.26}


# ---------------------------------------------------------------- folding chair
def folding_chair(name):
    b = Builder(name)
    for x in (-0.4, 0.4):
        strut(b, V(x, -0.38, 0.0), V(x, 0.34, 0.93), 0.04, "iron_hi", n=4)
        strut(b, V(x, 0.38, 0.0), V(x, -0.34, 0.93), 0.04, "iron_hi", n=4)
        strut(b, V(x, 0.34, 0.93), V(x, 0.5, 1.78), 0.04, "iron_hi", n=4)
    bx(b, V(0, 0, 0.99), (0.86, 0.8, 0.06), "teal", zm="teal_dark")
    bx(Xf(b, pos=(0, 0.46, 1.42), rot=(-8, 0, 0)), V0, (0.84, 0.05, 0.6), "teal", yp="teal_dark")
    bx(b, V(0, 0.51, 1.76), (0.92, 0.07, 0.07), "iron_hi")
    bx(b, V(0, -0.36, 0.91), (0.92, 0.07, 0.07), "iron_hi")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "height": 1.8, "seat_height": 1.02}


# ---------------------------------------------------------------- start board
def start_board(name):
    b = Builder(name)
    for x in (-3.2, 3.2):
        cbox(b, V(x, 0.42, 1.98), (0.4, 0.36, 3.96), "plank_dark", c=0.05)
    cbox(b, V(0, 0, 3.7), (8.0, 0.3, 1.6), "cart_red", c=0.06, edge="cart_white")
    for facing, sgn in ((-1, -1), (1, 1)):
        checker_y(b, -3.8, 20, 0.38, 4.08, 1, sgn * (0.15 + 0.012), facing)
        bx(b, V(0, sgn * (0.15 + 0.015), 3.49), (7.6, 0.03, 1.02), "cart_white")
    for x in (-3.2, 3.2):
        bar(b, V(x, 0.45, 2.2), V(x * 1.0, 1.9, 0.0), 0.2, "plank_dark")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "board": [8.0, 0.3, 1.6], "top": 4.5,
               "face": {"centre": [0.0, 3.49], "size": [7.4, 0.9], "plane_y": -0.18, "normal": [0, -1, 0]},
               "face_back": {"centre": [0.0, 3.49], "size": [7.4, 0.9], "plane_y": 0.18, "normal": [0, 1, 0]},
               "checker_band": {"z": [4.08, 4.46], "squares": 20}}


# ---------------------------------------------------------------- pennant pole
def pennant_pole(name):
    b = Builder(name)
    bx(b, V(0, 0, 0.1), (0.55, 0.55, 0.2), "plank_dark", zm=None)
    zs = [0.2 + 1.51 * k for k in range(6)]
    lat(b, V0, [(0.15 - 0.012 * k, z) for k, z in enumerate(zs)], 5, ["cart_red", "cart_white", "cart_red", "cart_white", "cart_red"], cap_top="cart_white")
    eye = V(0, 0, 7.95)
    torus(b, eye, V(1, 0, 0), V(0, 0, 1), 0.14, 0.035, 4, 3, "iron_hi")
    return b, {"origin": "foot on the ground", "height": 8.07, "eye": r3(eye), "eye_radius": 0.14, "note": "the eye ring lies in the xz plane"}


# ---------------------------------------------------------------- water barrel
def water_barrel(name):
    b = Builder(name)
    prof = [(0.735, 0), (0.81, 0.4), (0.865, 1.0), (0.81, 1.6), (0.735, 2.0)]
    lat(b, V0, prof + [(0.63, 2.0), (0.6, 1.85)], 8, ["plank", "plank", "plank", "plank", "plank_dark", "plank_dark"],
        phase=math.pi / 8, alt=None, inward=(5,), cap_top="fountain_water")

    def r_at(z):
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 <= z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return prof[-1][0]

    for z in (0.3, 1.0, 1.7):
        lat(b, V0, [(r_at(z - 0.07) + 0.03, z - 0.07), (r_at(z + 0.07) + 0.03, z + 0.07)], 8, "iron", phase=math.pi / 8)
    return b, {"origin": "foot centre on the ground", "diameter": 1.6, "height": 2.0, "water_z": 1.85}


# ---------------------------------------------------------------- wheelbarrow
def open_tray(b, c, bot, top, h, t, sw_out, sw_in, sw_rim):
    c = Vector(c)
    bx_, by_ = bot[0] / 2, bot[1] / 2
    tx, ty = top[0] / 2, top[1] / 2
    ob = [c + V(sx * bx_, sy * by_, 0) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    ot = [c + V(sx * tx, sy * ty, h) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    it = [c + V(sx * (tx - t), sy * (ty - t), h) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    ib = [c + V(sx * (bx_ - t), sy * (by_ - t), t) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    mid = c + V(0, 0, h / 2)
    for k in range(4):
        k2 = (k + 1) % 4
        oface(b, [ob[k], ob[k2], ot[k2], ot[k]], sw_out, mid)
        oface(b, [ot[k], ot[k2], it[k2], it[k]], sw_rim, mid + V(0, 0, -5))
        tface(b, [it[k], it[k2], ib[k2], ib[k]], sw_in, mid)
    oface(b, ob, sw_out, mid)
    oface(b, ib, sw_in, mid + V(0, 0, -5))


def wheelbarrow(name):
    b = Builder(name)
    open_tray(b, V(0, 0, 0.6), (1.0, 0.7), (1.8, 1.2), 0.6, 0.07, "cart_red", "popcorn_red", "cart_white")
    wc = V(1.1, 0, 0.45)
    xf = Xf(b, pos=wc, rot=(90, 0, 0))
    lat(xf, V0, [(0.45, -0.09), (0.45, 0.09), (0.2, 0.09)], 8, ["raccoon_dark", "black"], cap_top="black", cap_bot="black")
    gem(b, wc + V(0, -0.1, 0), 0.1, 0.08, 0.1, "steel", n=6, phase=0)
    for sy in (-1, 1):
        bar(b, V(0.6, sy * 0.33, 0.62), V(1.1, sy * 0.3, 0.45), 0.07, "plank_dark")
        bar(b, V(-0.5, sy * 0.45, 0.66), V(-1.3, sy * 0.58, 0.95), 0.1, "plank")
        bx(b, V(-1.3, sy * 0.6, 0.97), (0.4, 0.14, 0.14), "plank_dark")
        bar(b, V(-0.5, sy * 0.45, 0.62), V(-0.62, sy * 0.52, 0.0), 0.09, "plank_dark")
    bar(b, V(-0.5, -0.45, 0.4), V(-0.5, 0.45, 0.4), 0.07, "plank_dark")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "length": 3.0, "wheel_at": "+x", "height": 1.2}


# ---------------------------------------------------------------- stepped terraces
def terrace(b, x0, x1, prof, tops, risers, ends, back, front=None):
    """A solid stepped block under a (y, z) profile that climbs from the front (-y) to the back: each
    segment of `prof` is a tread (same z) or a riser (same y, higher z); the front and back faces drop
    to the ground and the two ends (x0 / x1) are stepped panels. tops / risers: a swatch, or a list
    with one swatch per tread / riser in order."""

    def pick(sw, k):
        return sw[k] if isinstance(sw, (list, tuple)) else sw

    nt = nr = 0
    quad_y(b, x0, x1, 0.0, prof[0][1], prof[0][0], front or pick(risers, 0), -1)
    for (ya, za), (yb, zb) in zip(prof, prof[1:]):
        if abs(za - zb) < 1e-9:
            quad_z(b, x0, x1, ya, yb, za, pick(tops, nt))
            nt += 1
            quad_x(b, ya, yb, 0.0, za, x0, ends, -1)
            quad_x(b, ya, yb, 0.0, za, x1, ends, 1)
        else:
            quad_y(b, x0, x1, za, zb, ya, pick(risers, nr), -1)
            nr += 1
    quad_y(b, x0, x1, 0.0, prof[-1][1], prof[-1][0], back, 1)


# ---------------------------------------------------------------- bleachers
# Painted island-style stand: three benches (front navy, middle coral, back cream) on stepped decks, a
# navy sponsor hoarding along the whole front and light-metal hand rails. Fan fit (SwFanA..D, origin =
# seat contact point): the thighs run 1.0 forward over the bench, the shins hang just in front of its
# front edge (0.69), the shoes reach 1.3 forward and sit 0.88 below the origin. So each bench is
# 0.68 in front of and 0.34 behind its row's y, and the feet land on the deck of the step below
# (a rise of 0.68 + the 0.2 bench = 0.88), the front row's on the apron.
BL_PITCH, BL_RISE, BL_BENCH_T, BL_APRON = 1.68, 0.68, 0.2, 0.12
BL_YC = [-1.15 + BL_PITCH * i for i in range(3)]  # seat centre y of each row
BL_DECK = [BL_APRON + BL_RISE * (i + 1) for i in range(3)]  # deck tops
BL_ROWS = [(round(y, 3), round(t + BL_BENCH_T, 3)) for y, t in zip(BL_YC, BL_DECK)]  # (seat y, seat top z)
BL_X0, BL_X1 = -7.8, 6.5  # bench ends; the deck beyond (to +8) is the stair strip at the +x end
BL_COLOURS = ["navy", "coral", "cream"]


def bleachers(name):
    b = Builder(name)
    XL, XR, YF, YB = -8.0, 8.0, -2.5, 2.7
    rail = "iron_hi"
    prof = [(YF, BL_APRON)]
    for yc, t in zip(BL_YC, BL_DECK):
        prof += [(yc - 0.68, prof[-1][1]), (yc - 0.68, t)]
    prof.append((YB, BL_DECK[-1]))
    terrace(b, XL, XR, prof, "teal_dark", "teal", "teal", "teal")
    for (yc, sz), col in zip(BL_ROWS, BL_COLOURS):
        cbox(b, V((BL_X0 + BL_X1) / 2, yc - 0.17, sz - BL_BENCH_T / 2), (BL_X1 - BL_X0, 1.02, BL_BENCH_T), col, c=0.04)
    # yellow nosing lines on the stair strip
    for yc, t in zip(BL_YC, BL_DECK):
        quad_z(b, BL_X1 + 0.15, XR - 0.2, yc - 0.68, yc - 0.5, t + 0.004, "awning_yellow")
    # sponsor hoarding along the front: navy board, cream cap and end posts, plain navy plate for the text
    HX0, HX1, HY, HH = XL, BL_X1 + 0.1, -2.66, 0.95
    bx(b, V((HX0 + HX1) / 2, HY + 0.08, HH / 2), (HX1 - HX0, 0.16, HH), "navy", zm=None, yp=None)
    bx(b, V((HX0 + HX1) / 2, HY + 0.02, HH + 0.04), (HX1 - HX0, 0.3, 0.08), "cream", zm=None)
    plate_x0, plate_x1, plate_z0, plate_z1 = -7.6, 6.2, 0.14, 0.84
    bx(b, V((plate_x0 + plate_x1) / 2, HY - 0.02, (plate_z0 + plate_z1) / 2), (plate_x1 - plate_x0, 0.04, plate_z1 - plate_z0), "navy", yp=None)
    for px in (XL + 0.17, HX1 - 0.17):
        bx(b, V(px, HY + 0.05, 0.62), (0.3, 0.26, 1.24), "cream", zm=None)
    # back rail (two bars on five posts) and the two end rails (a sloped bar on four posts each)
    BY = 2.62
    for x in (-7.9, -3.95, 0.0, 3.95, 7.9):
        bx(b, V(x, BY, (BL_DECK[-1] + 3.56) / 2), (0.12, 0.12, 3.56 - BL_DECK[-1]), rail, zm=None)
    for z in (3.5, 2.9):
        bx(b, V(0, BY, z), (15.8, 0.1, 0.1), rail, xm=None, xp=None)

    def z_line(y):
        return BL_DECK[0] + (BL_DECK[1] - BL_DECK[0]) / BL_PITCH * (y - (BL_YC[0] - 0.68))

    for sx in (-1, 1):
        x = sx * 7.9
        bar(b, V(x, -2.2, z_line(-2.2) + 0.95), V(x, BY, z_line(BY) + 0.95), 0.1, rail, w2=0.1, up=(1, 0, 0))
        for y, base in ((-2.2, BL_APRON), (-1.0, BL_DECK[0]), (0.7, BL_DECK[1])):
            top = z_line(y) + 0.95
            bx(b, V(x, y, (base + top) / 2), (0.1, 0.1, top - base), rail, zm=None)
    return b, {
        "origin": "footprint centre on the ground", "front": "-y", "length": 16.0, "depth": 5.4, "height": 3.6,
        "rows": [{"seat_z": sz, "y": yc, "x0": BL_X0, "x1": BL_X1} for yc, sz in BL_ROWS],
        "steps": {"x": [BL_X1 + 0.1, XR - 0.2], "end": "+x"}, "back_rail_z": [2.9, 3.56],
        "sponsor": {"centre": [round((plate_x0 + plate_x1) / 2, 3), round((plate_z0 + plate_z1) / 2, 3)],
                    "size": [round(plate_x1 - plate_x0, 3), round(plate_z1 - plate_z0, 3)], "plane_y": round(HY - 0.04, 3),
                    "normal": [0, -1, 0], "note": "plain navy board, text goes on it"},
        "note": "seat_z is the top of the bench; y the bench seat centre (bench from y - 0.68 to y + 0.34); a fan origin sits at (x, y, seat_z), its feet land on the deck of the step below",
    }


# ---------------------------------------------------------------- people
def head(b, c, r, skin, mouth="red_orange"):
    """A faceted round head (48 triangles) turned so a flat facet faces front (-y), with eyes and a smile."""
    c = Vector(c)
    ball(Xf(b, pos=c, rot=(0, 0, 22.5)), V0, r, 8, 4, skin)
    for s in (-1, 1):
        bx(b, c + V(s * 0.32 * r, -0.9 * r, 0.02 * r), (0.17 * r, 0.09 * r, 0.27 * r), "black")
    oface(b, [c + V(-0.17 * r, -0.85 * r, -0.27 * r), c + V(0.17 * r, -0.85 * r, -0.27 * r), c + V(0.17 * r, -0.85 * r, -0.34 * r),
              c + V(-0.17 * r, -0.85 * r, -0.34 * r)], mouth, c)


def arm_down(b, o, sleeve, skin):
    """An arm hanging down from the shoulder pivot o: sleeve, forearm and a mitt hand; 1.5 long."""
    o = Vector(o)
    cyl(b, o + V(0, 0, -0.65), 0.85, 0.22, 6, sleeve, r_top=0.27, top=True, bottom=True)
    cyl(b, o + V(0, 0, -1.15), 0.5, 0.15, 6, skin, r_top=0.2, top=False, bottom=False)
    ball(b, o + V(0, 0, -1.29), 0.21, 6, 3, skin)


def fan_arm(name, sleeve, skin):
    b = Builder(name)
    arm_down(b, V0, sleeve, skin)
    return b, {"origin": "shoulder pivot", "length": 1.5, "rest": "hangs along -z",
               "hand": r3((0, 0, -1.3)), "note": "attach at the matching SwFan shoulder_l (+x) or shoulder_r (-x)"}


def fan(name, shirt, skin, trousers, style, hair, accent):
    b = Builder(name)
    for sx in (-1, 1):
        x = sx * 0.27
        bx(b, V(x, -0.52, 0.2), (0.4, 0.95, 0.4), trousers, zm=None, yp=None)
        bx(b, V(x, -0.88, -0.35), (0.38, 0.38, 0.9), trousers, zm=None)
        bx(b, V(x, -1.0, -0.78), (0.42, 0.6, 0.2), "raccoon_dark")
    hexa(b, [V(-0.46, -0.3, 0.02), V(0.46, -0.3, 0.02), V(0.46, 0.3, 0.02), V(-0.46, 0.3, 0.02),
             V(-0.58, -0.32, 1.25), V(0.58, -0.32, 1.25), V(0.58, 0.32, 1.25), V(-0.58, 0.32, 1.25)], shirt, skip=(0,))
    lat(b, V(0, 0, 1.2), [(0.16, 0), (0.15, 0.3)], 6, skin)
    c = V(0, 0, 2.02)
    head(b, c, 0.5, skin)
    if style != "puff":
        bx(b, c + V(0, 0.28, 0.02), (0.6, 0.28, 0.45), hair or "bark_dark", zm=None, ym=None)
    if style == "short":
        dome(b, c + V(0, 0, 0.2), 0.5, 0.46, 8, 2, hair)
    elif style == "cap":
        dome(b, c + V(0, 0, 0.2), 0.53, 0.46, 8, 2, accent)
        bx(b, c + V(0, -0.62, 0.23), (0.7, 0.4, 0.06), accent)
        gem(b, c + V(0, 0, 0.68), 0.07, 0.07, 0.07, "cart_white", n=5)
    elif style == "pony":
        dome(b, c + V(0, 0, 0.2), 0.5, 0.46, 8, 2, hair)
        sweep(b, [c + V(0, 0.42, 0.3), c + V(0, 0.68, 0.16), c + V(0, 0.76, -0.32)], [0.13, 0.12, 0.07], 4, hair)
        gem(b, c + V(0, 0.47, 0.28), 0.1, 0.1, 0.1, accent, n=4)
    elif style == "puff":
        ball(Xf(b, pos=c + V(0, 0.16, 0.34), rot=(0, 0, 22.5)), V0, 0.58, 8, 4, hair)
    return b, {"origin": "seat contact point (bottom of the hips)", "front": "-y", "seated_height": 2.7,
               "shoulder_l": [0.62, 0.0, 1.1], "shoulder_r": [-0.62, 0.0, 1.1], "head_centre": r3(c),
               "note": "no arms; the matching SwFanArm is placed at the shoulder points (character left is +x)"}


# ---------------------------------------------------------------- official, podium, mechanic
def official_podium(name):
    b = Builder(name)
    R, W = "cart_red", "cart_white"
    top, za, zb = 2.1, 1.4, 0.7
    cbox(b, V(0, 0, 0.1), (3.0, 3.0, 0.2), "navy", c=0.05)
    planks_y(b, -1.45, 1.45, 0.2, top - 0.2, -1.45, 6, R, W, -1)
    planks_y(b, -1.45, 1.45, 0.2, zb - 0.1, 1.45, 6, R, W, 1)
    planks_y(b, -1.45, 1.45, zb - 0.1, za - 0.2, 1.0, 6, R, W, 1)
    planks_y(b, -1.45, 1.45, za - 0.2, top - 0.2, 0.5, 6, R, W, 1)
    for sx in (-1, 1):
        for k, (y0, y1, h) in enumerate(((-1.5, -1.0, top - 0.2), (-1.0, -0.5, top - 0.2), (-0.5, 0.0, top - 0.2), (0.0, 0.5, top - 0.2),
                                         (0.5, 1.0, za - 0.2), (1.0, 1.5, zb - 0.1))):
            quad_x(b, y0, y1, 0.2, h, sx * 1.45, R if k % 2 == 0 else W, sx)
    cbox(b, V(0, -0.5, top - 0.1), (3.0, 2.0, 0.2), W, c=0.05, top="navy", edge="navy")
    bx(b, V(0, 0.75, za - 0.1), (3.0, 0.5, 0.2), W, zp="navy")
    bx(b, V(0, 1.25, zb - 0.0), (3.0, 0.5, 0.2), W, zp="navy")
    # a little rail round three sides of the deck
    for x in (-1.42, 1.42):
        for y in (-1.42, 0.42):
            bx(b, V(x, y, top + 0.15), (0.1, 0.1, 0.3), "iron_hi", zm=None)
    bx(b, V(0, -1.42, top + 0.28), (2.9, 0.08, 0.08), "iron_hi")
    for x in (-1.42, 1.42):
        bx(b, V(x, -0.5, top + 0.28), (0.08, 1.9, 0.08), "iron_hi")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "footprint": [3.0, 3.0], "height": 2.4, "deck_top": top,
               "stand": [0.0, -0.4, top], "steps_at": "back (+y)", "step_tops": [za, zb]}


def official_body(name):
    b = Builder(name)
    skin = "log_inner"
    for sx in (-1, 1):
        x = sx * 0.28
        hexa(b, [V(x - 0.23, -0.25, 0.28), V(x + 0.23, -0.25, 0.28), V(x + 0.23, 0.25, 0.28), V(x - 0.23, 0.25, 0.28),
                 V(x - 0.25, -0.28, 1.85), V(x + 0.25, -0.28, 1.85), V(x + 0.25, 0.28, 1.85), V(x - 0.25, 0.28, 1.85)], "black", skip=(0,))
        bx(b, V(x, -0.1, 0.14), (0.48, 0.8, 0.28), "raccoon_dark", zm=None)
    bx(b, V(0, 0, 1.92), (1.14, 0.64, 0.14), "raccoon_dark")
    bx(b, V(0, -0.33, 1.92), (0.22, 0.04, 0.12), "iron_hi")
    for k in range(4):
        w = 1.12 + 0.045 * k
        bx(b, V(0, 0, 2.06 + 0.345 * (k + 0.5)), (w, 0.62 + 0.02 * k, 0.345), "cart_white" if k % 2 == 0 else "black",
           zm=None if k else None, zp=None if k < 3 else "black")
    bx(b, V(0, -0.03, 3.4), (0.6, 0.46, 0.1), "cart_white")
    lat(b, V(0, 0, 3.4), [(0.16, 0), (0.15, 0.25)], 6, skin)
    hc = V(0, 0, 3.85)
    head(b, hc, 0.5, skin)
    bx(b, hc + V(0, 0.28, 0.02), (0.6, 0.28, 0.45), "black", zm=None, ym=None)
    dome(b, hc + V(0, 0, 0.2), 0.56, 0.52, 8, 2, "black")
    bx(b, hc + V(0, -0.64, 0.23), (0.8, 0.4, 0.07), "black")
    gem(b, hc + V(0, 0, 0.74), 0.07, 0.07, 0.07, "cart_white", n=5)
    # whistle on a red cord
    gem(b, V(0.0, -0.42, 2.95), 0.11, 0.09, 0.11, "iron_hi", n=6)
    for sx in (-1, 1):
        bar(b, V(sx * 0.2, -0.36, 3.34), V(0, -0.42, 3.05), 0.04, "cart_red", w2=0.04)
    arm_down(b, V(0.74, 0, 3.12), "black", skin)
    gem(b, V(-0.72, 0, 3.1), 0.3, 0.3, 0.27, "black", n=6)
    return b, {"origin": "feet on the ground", "front": "-y", "height": 4.6, "shoulder_r": [-0.74, 0.0, 3.12],
               "shoulder_l_arm": "baked in (hanging, +x)", "note": "SwOfficialArm attaches at shoulder_r (character right is -x)"}


def official_arm(name):
    b = Builder(name)
    arm_down(b, V0, "black", "log_inner")
    cyl(b, V(0, 0, -3.6), 2.4, 0.05, 5, "plank_dark", top=True, bottom=True)
    gem(b, V(0, 0, -3.66), 0.08, 0.08, 0.1, "deco_gold", n=4)
    cols, rows, cw, ch, ztop = 4, 3, 0.4, 1.1 / 3, -2.4
    for r in range(rows):
        for k in range(cols):
            x0 = -0.06 - k * cw
            z0 = ztop - (r + 1) * ch
            b.face2([V(x0, 0, z0), V(x0 - cw, 0, z0), V(x0 - cw, 0, z0 + ch), V(x0, 0, z0 + ch)], "black" if (r + k) % 2 == 0 else "cart_white")
    return b, {"origin": "shoulder pivot", "rest": "arm and flag stick hang along -z", "stick": {"from": [0, 0, -1.2], "to": [0, 0, -3.6], "length": 2.4},
               "cloth": {"x": [-0.06, -1.66], "z": [-3.5, -2.4], "side": "-x (outward from the right shoulder)", "plane": "xz, two-sided", "squares": [4, 3]}}


def mechanic(name):
    b = Builder(name)
    skin, teal, tdark = "bark_streak", "teal", "teal_dark"
    for sx in (-1, 1):
        x = sx * 0.28
        hexa(b, [V(x - 0.23, -0.25, 0.28), V(x + 0.23, -0.25, 0.28), V(x + 0.23, 0.25, 0.28), V(x - 0.23, 0.25, 0.28),
                 V(x - 0.25, -0.28, 1.8), V(x + 0.25, -0.28, 1.8), V(x + 0.25, 0.28, 1.8), V(x - 0.25, 0.28, 1.8)], teal, skip=(0,))
        bx(b, V(x, -0.1, 0.14), (0.48, 0.8, 0.28), "raccoon_dark", zm=None)
    bx(b, V(0, 0, 1.95), (1.16, 0.66, 0.4), teal, zm=None)
    bx(b, V(0, 0, 2.7), (1.26, 0.68, 1.1), "cream", zm=None, zp=None)
    bx(b, V(0, -0.38, 2.5), (0.92, 0.08, 1.2), teal)
    bx(b, V(0, -0.44, 2.45), (0.46, 0.05, 0.34), tdark)
    for sx in (-1, 1):
        bx(b, V(sx * 0.4, -0.36, 3.15), (0.16, 0.08, 0.4), teal)
    bx(b, V(-0.3, 0.36, 1.95), (0.26, 0.05, 0.36), "cart_red")
    lat(b, V(0, 0, 3.25), [(0.16, 0), (0.15, 0.3)], 6, skin)
    hc = V(0, 0, 3.85)
    head(b, hc, 0.5, skin)
    bx(b, hc + V(0, 0.28, 0.02), (0.6, 0.28, 0.45), "bark_dark", zm=None, ym=None)
    dome(b, hc + V(0, 0, 0.2), 0.55, 0.55, 8, 2, tdark)
    bx(b, hc + V(0, -0.62, 0.23), (0.76, 0.4, 0.06), tdark)
    arm_down(b, V(0.74, 0, 3.12), "cream", skin)
    # right arm: sleeve down to the elbow, then the forearm held forward at waist height
    o = V(-0.74, 0, 3.12)
    cyl(b, o + V(0, 0, -0.65), 0.85, 0.22, 6, "cream", r_top=0.27, top=True, bottom=True)
    cyl(Xf(b, pos=o + V(0, 0, -0.62), rot=(-90, 0, 0)), V0, 0.8, 0.17, 6, skin, r_top=0.2, top=False, bottom=False)
    hand = o + V(0, -0.94, -0.62)
    ball(b, hand, 0.2, 6, 3, skin)
    return b, {"origin": "feet on the ground", "front": "-y", "height": 4.6, "hand_r": r3(hand + V(0, -0.1, 0)),
               "shoulder_r": r3(o), "note": "right hand (character right is -x) held forward at waist height; the wrench origin goes at hand_r"}


def prism_xz(b, pts, y0, y1, sw):
    """A prism from a counter-clockwise (x, z) outline (may be concave), from y0 to y1 (y0 < y1)."""
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cz = sum(p[1] for p in pts) / n
    for k in range(n):
        (xa, za), (xb, zb) = pts[k], pts[(k + 1) % n]
        out = V(zb - za, 0, -(xb - xa)).normalized()
        quad = [V(xa, y0, za), V(xb, y0, zb), V(xb, y1, zb), V(xa, y1, za)]
        oface(b, quad, sw, sum(quad, V0) / 4 - out)
    oface(b, [V(x, y0, z) for x, z in pts], sw, V(cx, y0 + 1, cz))
    oface(b, [V(x, y1, z) for x, z in pts], sw, V(cx, y1 - 1, cz))


def wrench(name):
    b = Builder(name)
    bx(b, V(0.075, 0, 0), (0.75, 0.1, 0.15), "iron_hi", xm=None, xp=None)
    # open-end head, turned 15 degrees as on a real spanner
    prism_xz(Xf(b, pos=(0.6, 0, 0), rot=(0, -15, 0)), [(-0.2, -0.27), (0.2, -0.27), (0.2, -0.11), (0.0, -0.11), (0.0, 0.11), (0.2, 0.11), (0.2, 0.27), (-0.2, 0.27)],
             -0.06, 0.06, "steel")
    prism_xz(b, [(-0.5 + 0.3 * math.cos(2 * math.pi * k / 6), 0.3 * math.sin(2 * math.pi * k / 6)) for k in range(6)], -0.06, 0.06, "steel")
    oface(b, [V(-0.5 + 0.14 * math.cos(2 * math.pi * k / 6), -0.063, 0.14 * math.sin(2 * math.pi * k / 6)) for k in range(6)], "black", V(-0.5, 5, 0))
    return b, {"origin": "middle of the grip", "length": 1.6, "plane": "xz, open jaw toward +x", "spin_axis": "y"}


# ---------------------------------------------------------------- snack cart
def snack_cart(name):
    b = Builder(name)
    for sy in (-1, 1):
        xf = Xf(b, pos=(0.1, sy * 0.95, 0.62), rot=(90 * sy, 0, 0))
        lat(xf, V0, [(0.62, -0.1), (0.62, 0.1), (0.42, 0.1)], 8, ["raccoon_dark", "cart_red"], cap_top="iron_hi", cap_bot="black")
        gem(b, V(0.1, sy * 1.08, 0.62), 0.12, 0.08, 0.12, "iron_hi", n=6)
    cbox(b, V(0, 0, 1.05), (2.4, 1.4, 1.0), "cart_red", c=0.06, edge="cart_white")
    planks_y(b, -1.2, 1.2, 0.6, 1.5, -0.72, 8, "cart_white", "cart_red", -1)
    planks_y(b, -1.2, 1.2, 0.6, 1.5, 0.72, 8, "cart_white", "cart_red", 1)
    bx(b, V(0, 0, 1.6), (2.6, 1.6, 0.1), "cart_white", zp="navy")
    open_tray(b, V(-0.2, -0.35, 1.65), (1.3, 0.8), (1.8, 1.0), 0.7, 0.07, "cart_white", "lemon", "cart_red")
    for k, (x, y, z) in enumerate(((-0.8, -0.5, 2.3), (-0.4, -0.2, 2.35), (0.0, -0.5, 2.3), (0.3, -0.25, 2.34), (-0.6, -0.2, 2.5),
                                   (-0.1, -0.35, 2.5), (-0.95, -0.25, 2.34), (0.15, -0.55, 2.46), (-0.5, -0.5, 2.55))):
        gem(b, V(x, y, z), 0.15, 0.14, 0.13, "cream" if k % 3 else "lemon", n=5)
    lat(b, V(0, 0.25, 1.65), [(0.07, 0), (0.07, 1.9)], 6, "iron_hi", cap_top="iron_hi")
    rim = [V(math.cos(2 * math.pi * k / 8) * 1.25, 0.15 + math.sin(2 * math.pi * k / 8) * 1.25, 2.95) for k in range(8)]
    apex = V(0, 0.15, 3.52)
    for k in range(8):
        sw = "coral" if k % 2 == 0 else "cart_white"
        k2 = (k + 1) % 8
        b.face2([apex, rim[k], rim[k2]], sw)
        mid = (rim[k] + rim[k2]) / 2
        mid = V(mid.x, mid.y, 2.75)
        b.face2([rim[k], mid, rim[k2]], sw)
    gem(b, apex + V(0, 0, 0.04), 0.1, 0.1, 0.14, "deco_gold", n=6)
    for sy in (-1, 1):
        bar(b, V(-1.15, sy * 0.5, 1.2), V(-1.8, sy * 0.55, 1.05), 0.08, "plank_dark")
    bx(b, V(-1.8, 0, 1.05), (0.1, 1.15, 0.1), "plank")
    bar(b, V(1.2, 0, 0.7), V(1.75, 0, 0.0), 0.08, "iron_hi")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "footprint": [3.6, 2.5], "height": 3.6, "handle_at": "-x",
               "umbrella": {"centre": [0.0, 0.15, 2.95], "radius": 1.25, "apex_z": 3.52}}


# ---------------------------------------------------------------- lap board
def lap_board(name):
    b = Builder(name)
    cz = 2.9
    cbox(b, V(0, 0, cz), (3.0, 0.2, 2.4), "navy", c=0.06)
    bx(b, V(0, -0.12, cz + 0.85), (2.7, 0.04, 0.45), "teal")
    slots = []
    for x in (-0.72, 0.72):
        bx(b, V(x, -0.125, cz - 0.3), (1.15, 0.05, 1.5), "black")
        bx(b, V(x, -0.14, cz - 0.3), (1.0, 0.05, 1.35), "cream")
        bx(b, V(x, -0.16, cz + 0.4), (1.2, 0.08, 0.06), "iron_hi")
        slots.append({"centre": [x, cz - 0.3], "size": [1.0, 1.35], "plane_y": -0.165})
    for sx in (-1, 1):
        bar(b, V(sx * 1.75, -0.1, 4.0), V(sx * 1.95, -1.05, 0.0), 0.12, "plank_dark")
        for z in (3.5, 2.0):
            bx(b, V(sx * 1.63, -0.1, z), (0.3, 0.14, 0.14), "plank_dark")
    bar(b, V(0, 0.12, 4.0), V(0, 1.7, 0.0), 0.12, "plank_dark")
    bx(b, V(0, -0.45, 1.55), (3.7, 0.7, 0.1), "plank")
    bx(b, V(0, 0.5, 1.2), (2.4, 0.1, 0.12), "plank_dark")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "board": [3.0, 2.4], "height": 4.1,
               "face": {"centre": [0.0, cz + 0.85], "size": [2.7, 0.4], "plane_y": -0.14, "normal": [0, -1, 0], "note": "header strip"},
               "slots": slots, "note": "two blank flip-card slots (cream cards); slot centre (x, z)"}


# ---------------------------------------------------------------- start lights
def start_lights(name):
    b = Builder(name)
    bx(b, V(0, 0, 0.1), (1.1, 1.1, 0.2), "concrete", zm=None)
    lat(b, V(0, 0, 0.2), [(0.24, 0), (0.2, 1.6)], 6, "metal")
    cbox(b, V(0, 0, 3.8), (2.4, 0.7, 4.4), "navy", c=0.1)
    bx(b, V(0, 0, 6.05), (2.5, 0.8, 0.1), "teal", zm=None)
    lamps = []
    for k in range(5):
        z = 2.25 + 0.82 * k
        for sx in (-1, 1):
            cyl(b, V(sx * 0.55, -0.35, z), 0.12, 0.34, 6, "inlay_off", axis=(0, -1, 0))
        bx(b, V(0, -0.5, z + 0.47), (2.0, 0.3, 0.08), "black", zm=None)
        lamps.append([0.0, -0.47, round(z, 3)])
    return b, {"origin": "foot centre on the ground", "front": "-y", "height": 6.1, "lamps": lamps, "lens_x": [-0.55, 0.55],
               "lens_radius": 0.34, "note": "lamps: the centre of each lamp row on the housing front; lenses are dark (inlay_off) when off"}


# ---------------------------------------------------------------- pit garage
def pit_garage(name):
    b = Builder(name)
    CREAM, NAVY, TD = "cream", "navy", "teal_dark"
    bx(b, V(0, 0, 0.1), (18, 10, 0.2), "concrete", zm=None)
    for x in (-7.4, -1.6, 1.6, 7.4):
        quad_z(b, x - 0.1, x + 0.1, -4.0, 4.6, 0.205, "awning_yellow")
    yf = -4.8
    for x0, x1 in ((-9.0, -7.5), (-1.5, 1.5), (7.5, 9.0)):
        bx(b, V((x0 + x1) / 2, yf, 2.6), (x1 - x0, 0.4, 4.8), CREAM, yp=TD, zm=None, zp=None)
    bx(b, V(0, yf, 6.2), (18, 0.4, 2.4), NAVY, yp=TD, zm=TD, zp=None)
    for sx in (-1, 1):
        bx(b, V(sx * 8.8, 0, 3.8), (0.4, 10, 7.2), CREAM, xm=TD if sx > 0 else CREAM, xp=TD if sx < 0 else CREAM, zm=None, zp=None)
        for y in (-2.2, 2.2):
            bx(b, V(sx * 9.03, y, 5.3), (0.06, 2.0, 1.8), "cart_white")
            bx(b, V(sx * 9.06, y, 5.3), (0.04, 1.8, 1.6), "glass_tint")
    bx(b, V(0, 4.8, 3.8), (18, 0.4, 7.2), CREAM, ym=NAVY, zm=None, zp=None)
    bx(b, V(0, 0, 7.2), (17.6, 9.6, 0.4), "concrete", zm="cream")
    cbox(b, V(0, -4.85, 7.7), (18.0, 0.5, 0.6), NAVY, c=0.06, edge=NAVY)
    bx(b, V(0, 4.95, 7.7), (18.0, 0.4, 0.6), CREAM, zm=None)
    for sx in (-1, 1):
        bx(b, V(sx * 8.8, 0, 7.7), (0.4, 9.4, 0.6), CREAM, zm=None, yp=None, ym=None)
    # red-orange accent stripes along the front and the roof edge
    bx(b, V(0, yf - 0.23, 5.18), (18.0, 0.06, 0.2), "red_orange")
    bx(b, V(0, yf - 0.23, 0.45), (18.0, 0.06, 0.25), "red_orange", zm=None)
    # door frames and roll-door housings
    for cx in (-4.5, 4.5):
        for sx in (-1, 1):
            bx(b, V(cx + sx * 2.9, yf - 0.2, 2.6), (0.3, 0.3, 4.8), NAVY, zm=None)
        bx(b, V(cx, yf - 0.2, 4.95), (6.0, 0.3, 0.3), "red_orange")
        bx(b, V(cx, yf + 0.35, 4.6), (5.8, 0.4, 0.4), "stone_light")
    # sign band
    fy = yf - 0.2 - 0.04
    for z, h in ((6.2 + 0.85, 0.14), (6.2 - 0.85, 0.14)):
        bx(b, V(0, fy - 0.0, z), (14.3, 0.08, h), CREAM)
    for x in (-7.08, 7.08):
        bx(b, V(x, fy, 6.2), (0.14, 0.08, 1.56), CREAM)
    bx(b, V(0, fy + 0.02, 6.2), (14.0, 0.04, 1.5), CREAM)
    # interior: darker back wall with a tool wall, a workbench and ceiling lights
    bx(b, V(-4.7, 4.57, 3.6), (5.0, 0.06, 2.8), "stone_light")
    bx(b, V(-4.7, 4.3, 2.1), (5.0, 0.5, 0.1), "plank")
    for k, (x, z, w, h, sw) in enumerate(((-6.6, 4.1, 0.5, 1.2, "red_orange"), (-5.6, 4.2, 0.14, 1.0, "iron_hi"), (-4.7, 4.0, 0.6, 0.9, "awning_yellow"),
                                          (-3.7, 4.2, 0.14, 1.1, "iron_hi"), (-2.9, 3.9, 0.5, 0.7, "cart_red"), (-6.0, 3.0, 0.9, 0.2, "steel"))):
        bx(b, V(x, 4.5, z), (w, 0.08, h), sw)
    bx(b, V(4.5, 4.0, 1.3), (3.4, 1.0, 0.14), "plank", zm=None)
    for x in (2.9, 6.1):
        bx(b, V(x, 4.0, 0.65), (0.2, 0.8, 1.1), "plank_dark", zm=None)
    for x in (-4.5, 4.5):
        for y in (-1.5, 1.5):
            bx(b, V(x, y, 6.97), (1.6, 0.8, 0.06), "light_panel", zp=None)
    # the back: an accent stripe and a service door
    bx(b, V(0, 5.03, 0.45), (18.0, 0.06, 0.25), "red_orange", zm=None)
    bx(b, V(-6.0, 5.04, 1.75), (1.8, 0.08, 3.1), NAVY, zm=None)
    bx(b, V(-6.0, 5.07, 1.7), (1.5, 0.06, 2.9), "teal", zm=None)
    bx(b, V(-5.55, 5.1, 1.7), (0.1, 0.06, 0.1), "brass")
    # roof equipment
    bx(b, V(5.5, 1.5, 7.65), (2.0, 1.4, 0.5), "stone_light", zm=None)
    lat(b, V(5.5, 1.5, 7.9), [(0.55, 0), (0.55, 0.08)], 6, "metal", cap_top="black")
    lat(b, V(-6.0, 2.0, 7.4), [(0.25, 0), (0.25, 0.55)], 6, "iron", cap_top="black")
    return b, {
        "origin": "footprint centre on the ground", "front": "-y", "footprint": [18.0, 10.0], "height": 8.0,
        "openings": [{"x": [-7.5, -1.5], "z": [0.2, 5.0]}, {"x": [1.5, 7.5], "z": [0.2, 5.0]}],
        "face": {"centre": [0.0, 6.2], "size": [14.0, 1.5], "plane_y": round(fy + 0.02 - 0.02, 3), "normal": [0, -1, 0], "note": "sign band"},
        "interior_back_wall_y": 4.6, "roll_door_housing_z": 4.6, "floor_top": 0.2,
    }


def roll_door(name):
    b = Builder(name)
    bx(b, V(0, 0, 2.5), (5.9, 0.12, 4.9), "cream", zm=None)
    for k in range(7):
        bx(b, V(0, -0.08, 0.75 + 0.6 * k), (5.9, 0.06, 0.12), "stone_light", yp=None)
    bx(b, V(0, -0.02, 0.1), (6.0, 0.2, 0.2), "iron_hi", zm=None)
    return b, {"origin": "bottom centre", "size": [6.0, 5.0], "thickness": 0.2, "front": "-y", "note": "fits a 6 x 5 opening; slide along z to roll up"}


def tool_chest(name):
    b = Builder(name)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(b, V(sx * 0.8, sy * 0.4, 0.17), (0.22, 0.3, 0.34), "raccoon_dark", zm=None)
    cbox(b, V(0, 0, 1.4), (2.0, 1.2, 2.0), "cart_red", c=0.06, edge="red_orange")
    bx(b, V(0, 0, 2.5), (2.1, 1.3, 0.2), "iron_hi", zm=None)
    for k in range(5):
        z0 = 0.55 + 0.36 * k
        quad_y(b, -0.9, 0.9, z0, z0 + 0.33, -0.612, "raccoon_dark", -1)
        quad_y(b, -0.86, 0.86, z0 + 0.02, z0 + 0.31, -0.62, "coral" if k % 2 else "red_orange", -1)
        bx(b, V(0, -0.65, z0 + 0.165), (0.9, 0.07, 0.06), "iron_hi")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "size": [2.1, 1.3, 2.6], "drawers": 5}


def tyre_stack_tall(name):
    b = Builder(name)
    R, H = 0.866, 0.6
    ph = math.pi / 8
    for j in range(4):
        z0 = j * H
        sws = ["raccoon_dark", "cart_white" if j % 2 else "raccoon_dark", "cart_white"]
        if j == 3:
            lat(b, V0, [(R - 0.07, z0), (R, z0 + 0.3), (R - 0.07, z0 + H), (0.42, z0 + H)], 8, ["raccoon_dark", "raccoon_dark", "raccoon_dark"], phase=ph, cap_top="black")
        else:
            lat(b, V0, [(R - 0.07, z0), (R, z0 + 0.3), (R - 0.07, z0 + H)], 8, ["raccoon_dark", "cart_white" if j % 2 else "raccoon_dark"], phase=ph)
    bx(b, V(0, -0.83, 1.2), (0.15, 0.05, 2.4), "metal", zm=None, zp=None)
    return b, {"origin": "footprint centre on the ground", "diameter": 1.6, "height": 2.4, "tyres": 4}


# ---------------------------------------------------------------- grandstand bay
# The bleachers' painted look, bigger and roofed: five tiers of seat runs (navy, coral, cream, navy,
# coral from the front) with a teal stepped terrace, a navy sponsor hoarding along the front, the
# central aisle with its rails, the back wall, columns and the cantilevered canopy. Each tier climbs
# in two equal 0.46 steps: a foot tread, then the seat deck (0.42 seat + 0.46 step = the fan's 0.88 hip-to-sole). Fan fit (see bleachers): the seat run is
# 0.68 in front of and 0.32 behind the tier's y; its foot tread (0.7 wide) lies in front of the riser
# below the seat deck and the shoes (0.88 under the origin, 0.62 forward of the seat front) rest on it.
GS_P, GS_STEP, GS_SEAT = 1.85, 0.46, 0.42  # tier pitch along y; half step (a tier rises 2 x GS_STEP); seat top above its deck
GS_YC = [-3.8 + GS_P * i for i in range(5)]  # seat centre y of each tier
GS_T = [1.6 + 2 * GS_STEP * i for i in range(5)]  # seat deck top z
GS_COLOURS = ["navy", "coral", "cream", "navy", "coral"]


def grandstand_bay(name):
    b = Builder(name)
    NAVY, CREAM, CORAL = "navy", "cream", "coral"
    yB = [yc - 0.68 for yc in GS_YC]  # riser under each seat deck (front of the seat run)
    pts = [(-5.3, GS_T[0] - GS_STEP)]
    for i in range(5):
        pts += [(yB[i], GS_T[i] - GS_STEP), (yB[i], GS_T[i])]
        if i < 4:  # the seat deck runs 0.47 behind the tier's y (past the backrests), then the next foot tread
            pts += [(GS_YC[i] + 0.47, GS_T[i]), (GS_YC[i] + 0.47, GS_T[i + 1] - GS_STEP)]
    pts.append((4.95, GS_T[4]))
    terrace(b, -7.0, 7.0, pts, "teal_dark", "teal", CREAM, CREAM, front=NAVY)
    # a seat run each side of the central aisle: metal bracket block, painted seat pan and backrest panels
    for i, (yc, t, col) in enumerate(zip(GS_YC, GS_T, GS_COLOURS)):
        for sx in (-1, 1):
            xc = sx * 3.85
            bx(b, V(xc, yc - 0.18, t + 0.12), (6.3, 0.8, 0.24), "iron", zm=None, yp=None)
            bx(b, V(xc, yc - 0.18, t + 0.33), (6.3, 1.0, 0.18), col, zm=None)
            for k in range(4):
                x = sx * (0.7 + 1.575 * (k + 0.5))
                bx(b, V(x, yc + 0.38, t + 0.62), (1.475, 0.12, 0.7), col, zm=None)
    # aisle hand rails: a sloped bar on three posts each side of the aisle steps
    slope = 2 * GS_STEP / GS_P

    def z_line(y):
        return GS_T[0] + slope * (y - yB[0])

    for sx in (-1, 1):
        bar(b, V(sx * 0.65, -4.9, z_line(-4.9) + 0.95), V(sx * 0.65, 4.7, z_line(4.7) + 0.95), 0.07, "iron_hi", up=(1, 0, 0))
        for i in (0, 2, 4):
            y = yB[i] + 0.15
            top = z_line(y) + 0.95
            bx(b, V(sx * 0.65, y, (GS_T[i] + top) / 2), (0.08, 0.08, top - GS_T[i]), "iron_hi", zm=None)
    # back wall with bands, two back columns, the cantilevered canopy and its beams
    bx(b, V(0, 5.2, 4.75), (14.0, 0.5, 9.5), CREAM, ym=CREAM, zm=None, zp=NAVY)
    for z0, z1, sw in ((6.4, 6.9, NAVY), (8.7, 9.2, "teal")):
        quad_y(b, -7.0, 7.0, z0, z1, 4.945, sw, -1)
        quad_y(b, -7.0, 7.0, z0, z1, 5.455, sw, 1)
    for x in (-3.5, 3.5):
        cbox(b, V(x, 5.2, 6.2), (0.9, 0.6, 12.4), "teal", c=0.06, edge=CREAM)
    ztop = lambda y: 12.1 + (y + 5.3) * (0.9 / 10.8)
    pts = [V(-7, -5.3, ztop(-5.3)), V(7, -5.3, ztop(-5.3)), V(7, 5.5, ztop(5.5)), V(-7, 5.5, ztop(5.5))]
    hexa(b, pts + [p - V(0, 0, 0.4) for p in pts], "teal", sws=["cream", "teal", "navy", CREAM, "teal", CREAM], skip=())
    for k in range(8):
        xa, xb = -7 + 1.75 * k, -7 + 1.75 * (k + 1)
        oface(b, [V(xa, -5.3, ztop(-5.3) + 0.012), V(xb, -5.3, ztop(-5.3) + 0.012), V(xb, 5.5, ztop(5.5) + 0.012), V(xa, 5.5, ztop(5.5) + 0.012)],
              "teal" if k % 2 == 0 else CREAM, V((xa + xb) / 2, 0, 0))
    for x in (-3.5, 3.5):
        bar(b, V(x, 5.2, ztop(5.2) - 0.65), V(x, -5.0, ztop(-5.0) - 0.65), 0.35, NAVY, w2=0.5, up=(1, 0, 0))
    # sponsor hoarding along the whole front (joins flush with the next bay): navy board, cream cap,
    # a plain navy plate (0.04 proud) for the text
    HY, HH = -5.5, 1.4
    bx(b, V(0, HY + 0.1, HH / 2), (14.0, 0.2, HH), NAVY, zm=None, yp=None)
    bx(b, V(0, HY + 0.04, HH + 0.04), (14.0, 0.32, 0.08), CREAM, zm=None)
    plate = {"x": 13.4, "z0": 0.2, "z1": 1.2}
    bx(b, V(0, HY - 0.02, (plate["z0"] + plate["z1"]) / 2), (plate["x"], 0.04, plate["z1"] - plate["z0"]), NAVY, yp=None)
    rows = [{"seat_z": round(t + GS_SEAT, 3), "y": round(yc, 3), "x0": -6.85, "x1": 6.85, "aisle": [-0.7, 0.7]} for yc, t in zip(GS_YC, GS_T)]
    return b, {"origin": "footprint centre on the ground", "front": "-y", "module": [14.0, 11.0], "height": 13.0, "join": "flush at x = +/-7, repeat every 14 along x",
               "rows": rows, "canopy_underside_front": round(ztop(-5.3) - 0.4, 3), "columns_x": [-3.5, 3.5], "note": "back columns repeat every 7 studs across modules; seat_z is the top of the seat pan, y the seat centre (seat from y - 0.68 to y + 0.32), a fan origin sits at (x, y, seat_z) and its feet land on the foot tread in front of the seat deck; keep fans out of the aisle (x within +/-1.3)",
               "sponsor": {"centre": [0.0, round((plate["z0"] + plate["z1"]) / 2, 3)], "size": [plate["x"], round(plate["z1"] - plate["z0"], 3)],
                           "plane_y": round(HY - 0.04, 3), "normal": [0, -1, 0], "note": "plain navy board along the front, text goes on it"}}


# ---------------------------------------------------------------- announcer booth
def announcer_booth(name):
    b = Builder(name)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 2.2, sy * 1.7
            lat(b, V(x, y, 0.2), [(0.3, 0), (0.2, 6.5)], 6, "navy", cap_top="navy")
            bx(b, V(x, y, 0.1), (0.9, 0.9, 0.2), "concrete", zm=None)
    for y in (-1.7, 1.7):
        strut(b, V(-2.2, y, 1.2), V(2.2, y, 5.8), 0.07, "steel", n=4)
        strut(b, V(2.2, y, 1.2), V(-2.2, y, 5.8), 0.07, "steel", n=4)
    for x in (-2.2, 2.2):
        strut(b, V(x, -1.7, 1.2), V(x, 1.7, 5.8), 0.07, "steel", n=4)
        strut(b, V(x, 1.7, 1.2), V(x, -1.7, 5.8), 0.07, "steel", n=4)
    cbox(b, V(0, 0, 6.85), (5.6, 4.6, 0.3), "navy", c=0.06, edge="teal")
    # ladder at the back
    for sx in (-1, 1):
        bar(b, V(1.5 + sx * 0.4, 2.65, 0.0), V(1.5 + sx * 0.4, 2.35, 6.8), 0.08, "iron_hi", up=(1, 0, 0))
    for k in range(6):
        bx(b, V(1.5, 2.6 - 0.04 * k, 0.6 + 1.1 * k), (0.8, 0.08, 0.08), "iron_hi")
    # cabin
    bx(b, V(0, 2.0, 8.5), (5.0, 0.2, 3.0), "cream", ym="teal_dark", zm=None, zp=None)
    for sx in (-1, 1):
        bx(b, V(sx * 2.4, 0, 8.5), (0.2, 4.0, 3.0), "cream", xm="cream" if sx < 0 else "teal_dark", xp="cream" if sx > 0 else "teal_dark", zm=None, zp=None)
        bx(b, V(sx * 2.53, 0, 8.7), (0.06, 1.8, 1.4), "cart_white")
        bx(b, V(sx * 2.56, 0, 8.7), (0.04, 1.6, 1.2), "glass")
    bx(b, V(0, -2.0, 7.5), (5.0, 0.2, 1.0), "cream", zm=None, zp=None, yp=None)
    bx(b, V(0, -2.0, 9.7), (5.0, 0.2, 0.6), "teal", zm=None, zp=None, yp=None)
    for sx in (-1, 1):
        bx(b, V(sx * 2.35, -2.0, 8.6), (0.3, 0.2, 1.4), "cream", zm=None, zp=None, yp=None)
    bx(b, V(0, -2.0, 8.6), (4.4, 0.06, 1.2), "glass")
    for x in (-1.0, 1.0):
        bx(b, V(x, -2.07, 8.6), (0.1, 0.1, 1.3), "cart_white")
    bx(b, V(-1.0, 2.11, 8.1), (1.2, 0.05, 2.2), "cart_white")
    bx(b, V(-1.0, 2.14, 8.05), (1.0, 0.05, 2.0), "teal_dark")
    bx(b, V(-0.65, 2.18, 8.0), (0.08, 0.05, 0.08), "brass")
    awning(b, -2.6, 2.6, -2.1, -2.65, 9.4, 9.05, 6, "teal", "cart_white", drop=0.2)
    cbox(b, V(0, 0, 10.15), (5.6, 4.6, 0.3), "teal", c=0.06, edge="cream")
    lat(b, V(0, 0, 10.3), [(0.1, 0), (0.1, 1.05)], 6, "iron_hi")
    bx(b, V(0, 0, 11.3), (2.8, 0.12, 0.12), "iron_hi")
    for sx in (-1, 1):
        xf = Xf(b, pos=(sx * 1.2, -0.1, 11.3), rot=(90, 0, 0))
        lat(xf, V0, [(0.1, 0), (0.18, 0.25), (0.42, 0.7)], 8, ["iron_hi", "cart_white"], cap_top="black")
    return b, {"origin": "footprint centre on the ground", "front": "-y", "cabin": [5.0, 4.0], "cabin_floor_z": 7.0, "height": 11.9,
               "ladder_at": "back (+y)", "note": "four stilt legs; glass windows on the front and sides"}


# ---------------------------------------------------------------- flood tower
def flood_tower(name):
    b = Builder(name)
    z0, z1 = 1.2, 35.5
    h0, h1 = 1.2, 0.7
    cbox(b, V(0, 0, 0.6), (3.0, 3.0, 1.2), "concrete", c=0.1)

    def P(sx, sy, z):
        h = h0 + (h1 - h0) * (z - z0) / (z1 - z0)
        return V(sx * h, sy * h, z)

    corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    for sx, sy in corners:
        bar(b, P(sx, sy, z0), P(sx, sy, z1), 0.26, "navy")
    n = 6
    zs = [z0 + (z1 - z0) * k / n for k in range(n + 1)]
    for k, z in enumerate(zs):
        for i in range(4):
            a, c = corners[i], corners[(i + 1) % 4]
            strut(b, P(a[0], a[1], z), P(c[0], c[1], z), 0.07, "navy", n=3)
    for k in range(n):
        for i in range(4):
            a, c = corners[i], corners[(i + 1) % 4]
            if (k + i) % 2 == 0:
                strut(b, P(a[0], a[1], zs[k]), P(c[0], c[1], zs[k + 1]), 0.06, "teal_dark", n=3)
            else:
                strut(b, P(c[0], c[1], zs[k]), P(a[0], a[1], zs[k + 1]), 0.06, "teal_dark", n=3)
    bx(b, V(0, 0, z1 + 0.1), (2.6, 2.6, 0.2), "steel", zm=None)
    for sy in (-1, 1):
        bx(b, V(0, sy * 1.25, z1 + 0.75), (2.5, 0.07, 0.07), "iron_hi")
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(b, V(sx * 1.25, sy * 1.25, z1 + 0.5), (0.08, 0.08, 0.8), "iron_hi", zm=None)
    bx(b, V(0, 0, z1 + 0.5), (0.8, 0.8, 0.5), "steel", zm=None)
    tilt = 12.0
    hc = V(0, -0.2, 38.0)
    xf = Xf(b, pos=hc, rot=(tilt, 0, 0))
    cbox(xf, V0, (6.0, 0.8, 4.0), "navy", c=0.1)
    for r, z in ((0, 0.95), (0, -0.95)):
        for x in (-2.1, -0.7, 0.7, 2.1):
            cyl(xf, V(x, -0.4, z), 0.14, 0.5, 8, "lamp_glass", axis=(0, -1, 0))
    for z in (1.6, -0.2):
        bx(xf, V(0, -0.5, z + 0.3), (5.8, 0.3, 0.1), "steel", zm=None)
    gem(b, V(0, -0.1, 39.9), 0.18, 0.18, 0.2, "red_orange", n=5)
    m = Matrix.Rotation(math.radians(tilt), 3, "X")
    lamp_centre = hc + m @ V(0, -0.54, 0)
    aim = m @ V(0, -1, 0)
    return b, {"origin": "footprint centre on the ground", "front": "-y", "height": 40.4, "foot": [3.0, 3.0],
               "lamp_centre": r3(lamp_centre), "aim": r3(aim), "head": [6.0, 4.0], "lenses": 8, "tilt_down_deg": tilt}


# ---------------------------------------------------------------- gantry
GX, GBZ0, GBZ1 = 10.5, 16.0, 19.0


def gantry(name):
    b = Builder(name)
    NAVY, CREAM = "navy", "cream"
    for sx in (-1, 1):
        x = sx * GX
        cbox(b, V(x, 0, 0.3), (2.8, 3.0, 0.6), "concrete", c=0.08)
        cbox(b, V(x, 0, 8.3), (1.6, 1.8, 15.4), NAVY, c=0.1)
        cbox(b, V(x, 0, 0.9), (2.0, 2.2, 0.4), CREAM, c=0.06)
        for z in (4.0, 12.5):
            bx(b, V(x, 0, z), (1.64, 1.84, 0.35), "red_orange", zm=None, zp=None)
    cbox(b, V(0, 0, 17.5), (24.0, 2.0, 3.0), NAVY, c=0.15)
    cbox(b, V(0, 0, 19.15), (24.4, 2.3, 0.3), CREAM, c=0.06)
    for sy in (-1, 1):
        bx(b, V(0, sy * 1.0, 16.25), (23.8, 0.1, 0.2), CREAM)
        yb = sy * (1.0 + 0.012)
        checker_y(b, -11.7, 39, 0.6, 18.3, 1, yb, sy)
        fy = sy * 1.04
        for z in (16.55 - 0.05, 18.15 + 0.05):
            bx(b, V(0, fy + sy * 0.0, z), (18.4, 0.08, 0.14), CREAM)
        for x in (-9.13, 9.13):
            bx(b, V(x, fy, 17.35), (0.14, 0.08, 1.74), CREAM)
        bx(b, V(0, sy * 1.02, 17.35), (18.0, 0.04, 1.5), CREAM)
    bx(b, V(0, -0.55, 15.94), (17.6, 0.8, 0.12), CREAM, zp=None)
    for k in range(9):
        cyl(b, V(-8 + 2 * k, -0.55, 15.88), 0.06, 0.34, 6, "inlay_off", axis=(0, 0, -1))
    face = lambda sy: {"centre": [0.0, 17.35], "size": [18.0, 1.5], "plane_y": round(sy * 1.04, 3), "normal": [0, sy, 0]}
    return b, {"origin": "footprint centre on the ground", "front": "-y", "legs_x": [-GX, GX], "clear_height": 16.0, "beam": {"x": [-12, 12], "z": [GBZ0, GBZ1], "depth": 2.0},
               "face": face(-1), "face_back": face(1), "checker_band": {"z": [18.3, 18.9]}, "lights": {"count": 9, "z": 15.82, "y": -0.55},
               "height": 19.3, "note": "SwGantryGold trims share this origin"}


def gantry_gold(name):
    b = Builder(name)
    G = "deco_gold"
    for sx in (-1, 1):
        for z in (1.55, 15.45):
            cbox(b, V(sx * GX, 0, z), (1.74, 1.94, 0.3), G, c=0.05)
    for sy in (-1, 1):
        bx(b, V(0, sy * 1.0, 16.02), (24.0, 0.1, 0.1), G)
        bx(b, V(0, sy * 1.17, 19.32), (24.4, 0.1, 0.1), G)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(b, V(sx * 11.93, sy * 1.0, 17.5), (0.1, 0.1, 3.0), G)
    cbox(b, V(0, 0, 19.5), (3.2, 1.2, 0.4), G, c=0.08)
    gem(b, V(0, 0, 20.5), 0.6, 0.4, 1.0, G, n=6)
    for sx in (-1, 1):
        gem(b, V(sx * 1.35, 0, 20.1), 0.4, 0.3, 0.7, G, n=6)
    for k in range(5):
        gem(b, V(-1.2 + 0.6 * k, -0.62, 19.78), 0.12, 0.12, 0.16, "brass", n=4)
    return b, {"origin": "same as SwGantry (footprint centre on the ground)", "front": "-y", "parts": ["leg collars", "beam edge trims", "crown"],
               "note": "place at the SwGantry CFrame; the gold swatch is deco_gold"}


# ---------------------------------------------------------------- big screen
def big_screen(name):
    b = Builder(name)
    cbox(b, V(0, 0, 13.5), (21.4, 1.2, 12.4), "navy", c=0.15)
    fy = -0.6 - 0.02
    bx(b, V(0, fy, 13.5), (20.0, 0.06, 11.0), "inlay_off")
    for z in (13.5 + 5.6, 13.5 - 5.6):
        bx(b, V(0, fy - 0.02, z), (20.3, 0.1, 0.16), "cream")
    for x in (-10.08, 10.08):
        bx(b, V(x, fy - 0.02, 13.5), (0.16, 0.1, 11.0), "cream")
    for sx in (-1, 1):
        x = sx * 5.5
        hexa(b, [V(x - 0.7, -0.6, 0.3), V(x + 0.7, -0.6, 0.3), V(x + 0.7, 0.6, 0.3), V(x - 0.7, 0.6, 0.3),
                 V(x - 0.5, -0.5, 7.8), V(x + 0.5, -0.5, 7.8), V(x + 0.5, 0.5, 7.8), V(x - 0.5, 0.5, 7.8)], "navy", skip=(0,))
        bx(b, V(x, 0, 0.15), (2.4, 2.0, 0.3), "concrete", zm=None)
        bx(b, V(x, 0, 7.6), (1.2, 1.1, 0.4), "cream")
        bar(b, V(x, 0.45, 6.4), V(x, 3.0, 0.0), 0.3, "navy", w2=0.4, up=(1, 0, 0))
    # the back: ribs on the body
    for z in (9.0, 18.0):
        bx(b, V(0, 0.66, z), (20.0, 0.12, 0.3), "metal")
    for x in (-7.5, -2.5, 2.5, 7.5):
        bx(b, V(x, 0.66, 13.5), (0.3, 0.12, 8.7), "metal")
    for sx in (-1, 1):
        x = sx * 8.0
        cbox(b, V(x, 0, 21.0), (1.4, 1.0, 1.8), "navy", c=0.08, edge="teal")
        cyl(b, V(x, -0.5, 21.2), 0.1, 0.45, 8, "black", axis=(0, -1, 0))
        cyl(b, V(x, -0.5, 20.45), 0.1, 0.2, 6, "black", axis=(0, -1, 0))
    return b, {"origin": "footprint centre on the ground", "front": "-y", "height": 21.9,
               "face": {"centre": [0.0, 13.5], "size": [20.0, 11.0], "plane_y": round(fy - 0.03, 3), "normal": [0, -1, 0], "bottom_z": 8.0},
               "legs_x": [-5.5, 5.5], "note": "the face is the inlay_off slab; replace its texture with a SurfaceGui/Neon from Luau"}


# ---------------------------------------------------------------- catch fence, column, rails, barrier
def catch_fence(name):
    b = Builder(name)
    xs = (-4.4, -1.47, 1.47, 4.4)
    for x in xs:
        bx(b, V(x, 0, 2.45), (0.26, 0.26, 4.9), "iron", zm=None)
        bx(b, V(x, 0, 0.1), (0.7, 0.7, 0.2), "concrete", zm=None)
        gem(b, V(x, 0, 5.0), 0.16, 0.16, 0.14, "iron_hi", n=4)
    bx(b, V(0, 0, 4.9), (9.0, 0.2, 0.18), "steel")
    bx(b, V(0, 0, 0.3), (9.0, 0.2, 0.18), "steel")
    for k in range(18):
        x = -4.4 + 8.8 * k / 17
        b.face2([V(x - 0.03, 0, 0.35), V(x + 0.03, 0, 0.35), V(x + 0.03, 0, 4.85), V(x - 0.03, 0, 4.85)], "metal")
    for k in range(8):
        z = 0.75 + 0.58 * k
        b.face2([V(-4.45, 0, z - 0.03), V(4.45, 0, z - 0.03), V(4.45, 0, z + 0.03), V(-4.45, 0, z + 0.03)], "steel")
    return b, {"length": 9.0, "height": 5.2, "posts": 4, "origin": "footprint centre on the ground", "front": "-y", "mesh": "thin two-sided bars"}


def column(name):
    b = Builder(name)
    r = 1.2 / math.cos(math.pi / 8)
    lat(b, V0, [(r, 0), (r, 1.0)], 8, "concrete", phase=math.pi / 8, cap_top="concrete", cap_bot="concrete")
    return b, {"unit_height": 1.0, "across_flats": 2.4, "origin": "base centre on the ground", "note": "stretch in height (Size.Y) to any height; octagonal, flats to +/-x and +/-y"}


def column_cap(name):
    b = Builder(name)
    bx(b, V(0, 0, -0.25), (6.0, 2.0, 0.5), "concrete")
    bx(b, V(0, 0, -0.28), (6.04, 2.04, 0.2), "navy", zm=None, zp=None)
    hexa(b, [V(-1.2, -0.9, -1.2), V(1.2, -0.9, -1.2), V(1.2, 0.9, -1.2), V(-1.2, 0.9, -1.2),
             V(-2.4, -1.0, -0.5), V(2.4, -1.0, -0.5), V(2.4, 1.0, -0.5), V(-2.4, 1.0, -0.5)], "concrete", skip=(1,))
    return b, {"size": [6.0, 2.0, 1.2], "origin": "top centre (it sits under a deck)", "stem": [2.4, 1.8], "note": "bottom face 2.4 x 1.8 meets a SwColumn top"}


def guard_rail(name):
    b = Builder(name)
    prof = [(0.0, 0.7), (0.0, 0.78), (-0.07, 0.85), (0.0, 0.94), (-0.07, 1.03), (0.0, 1.1), (0.0, 1.18)]
    for i in range(len(prof) - 1):
        (y0, z0), (y1, z1) = prof[i], prof[i + 1]
        b.face2([V(-4.5, y0, z0), V(4.5, y0, z0), V(4.5, y1, z1), V(-4.5, y1, z1)], "steel" if i % 2 == 0 else "iron_hi")
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        bx(b, V(x, 0.18, 0.7), (0.2, 0.12, 1.4), "iron", zm=None)
        bx(b, V(x, 0.09, 0.95), (0.14, 0.2, 0.4), "iron_hi")
        bx(b, V(x, -0.1, 1.12), (0.14, 0.03, 0.1), "awning_yellow")
    return b, {"length": 9.0, "height": 1.4, "origin": "footprint centre on the ground", "front": "-y", "posts": 5, "note": "rail face toward -y"}


def orange_barrier(name):
    b = Builder(name)

    def ring(hx, hy, z):
        return [V(-hx, -hy, z), V(hx, -hy, z), V(hx, hy, z), V(-hx, hy, z)]

    rings = [ring(2.0, 0.4, 0.0), ring(1.97, 0.34, 0.5), ring(1.97, 0.3, 1.0), ring(1.94, 0.22, 1.45), ring(1.9, 0.18, 1.6)]
    sws = ["fruit_orange", "cart_white", "fruit_orange", "cart_white"]
    loft(b, rings, lambda i, k: sws[i], cap_b="fruit_orange")
    for x in (-1.0, 1.0):
        lat(b, V(x, 0, 1.6), [(0.15, 0), (0.12, 0.06)], 6, "cart_white", cap_top="black")
    return b, {"length": 4.0, "depth": 0.8, "height": 1.7, "origin": "footprint centre on the ground", "front": "-y", "note": "fruit_orange / cart_white bands"}


# ---------------------------------------------------------------- flame decal
FLAME = [(0, -3.0), (1.05, -2.55), (1.5, -1.3), (1.5, -0.2), (1.25, 2.0), (0.75, 1.15), (0.15, 3.0), (-0.6, 1.1), (-1.15, 1.9),
         (-1.5, -0.3), (-1.45, -1.4), (-0.95, -2.55)]


def flame_decal(name):
    b = Builder(name)
    S = V(0, -2.4, 0)

    def layer(scale, z, sw, rev=False):
        pts = [S + (V(x, y, 0) - S) * scale + V(0, 0, z) for x, y in FLAME]
        o = S + (V(0, -0.5, 0) - S) * scale + V(0, 0, z)
        for k in range(len(pts)):
            tri = [o, pts[k], pts[(k + 1) % len(pts)]]
            oface(b, tri, sw, o + V(0, 0, -1 if not rev else 1))

    layer(1.0, 0.03, "red_orange")
    layer(0.66, 0.04, "fruit_orange")
    layer(0.34, 0.05, "awning_yellow")
    layer(1.0, 0.0, "red_orange", rev=True)
    return b, {"size": [3.0, 6.0, 0.05], "origin": "centre on the surface", "tips": "+y", "note": "lies flat, faceted flame pointing +y, three layers"}


# ---------------------------------------------------------------- blimp
BL_R = 3.4
BL_HALF = 12.0


def blimp_r(t):
    return BL_R * (1 - abs(t) ** 2.4) ** 0.46


def blimp(name):
    b = Builder(name)
    ts = [-1, -0.93, -0.8, -0.62, -0.4, -0.2, 0, 0.2, 0.4, 0.62, 0.8, 0.93, 1]
    n = 16
    rings = []
    for t in ts:
        y = BL_HALF * t
        if abs(t) >= 1:
            rings.append([V(0, y, 0)])
        else:
            r = blimp_r(t)
            rings.append([V(r * math.sin(2 * math.pi * k / n), y, r * math.cos(2 * math.pi * k / n)) for k in range(n)])

    def sw(i, k):
        thm = (k + 0.5) * 360.0 / n
        if thm > 180:
            thm = 360 - thm
        e = 90 - thm
        up = e >= 0
        lvl = int(round((abs(e) - 11.25) / 22.5))
        if i in (0, len(ts) - 2):
            return "coral" if up else "teal"
        return {3: "teal" if up else "coral", 2: "cream", 1: "coral" if up else "teal", 0: "cart_white"}[lvl]

    loft(b, rings, sw)
    for sx in (-1, 1):
        cbox(b, V(sx * (BL_R + 0.04 - 0.25), 0, 0), (0.5, 10.0, 2.6), "cart_white", c=0.06, edge="teal")
    for k in range(4):
        xf = Xf(b, rot=(0, 90 * k, 0))
        hexa(xf, [V(-0.09, 7.4, 1.4), V(0.09, 7.4, 1.4), V(0.09, 11.0, 1.0), V(-0.09, 11.0, 1.0),
                  V(-0.09, 9.5, 5.3), V(0.09, 9.5, 5.3), V(0.09, 11.0, 5.0), V(-0.09, 11.0, 5.0)], "teal" if k % 2 == 0 else "coral")
    cbox(b, V(0, -1.5, -3.9), (1.8, 4.2, 1.4), "cart_white", c=0.12, edge="teal")
    for sx in (-1, 1):
        bx(b, V(sx * 0.92, -1.5, -3.75), (0.04, 3.0, 0.5), "glass_tint")
    bx(b, V(0, -3.62, -3.75), (1.3, 0.04, 0.5), "glass_tint")
    for z in (0.0, 90.0):
        bx(Xf(b, pos=(0, 0.75, -3.9), rot=(0, z, 0)), V0, (0.14, 0.06, 1.5), "iron_hi")
    gem(b, V(0, 0.68, -3.9), 0.14, 0.1, 0.14, "deco_gold", n=6)
    gem(b, V(0, -12.0, 0), 0.4, 0.4, 0.5, "deco_gold", n=8)
    face = lambda sx: {"centre": [0.0, 0.0], "size": [9.6, 2.4], "plane_x": round(sx * (BL_R + 0.04), 3), "normal": [sx, 0, 0], "note": "(y, z) centre on the plaque"}
    return b, {"origin": "envelope centre (not the ground)", "nose": "-y", "length": 24.0, "radius": BL_R, "height": 9.0, "face_left": face(-1), "face_right": face(1),
               "fins": 4, "gondola_z": -3.9, "note": "text plaques on both sides, flat vertical faces normal +/-x"}


# ---------------------------------------------------------------- loop track
LOOP_R, LOOP_OFF, LOOP_W, LOOP_RUN = 10.0, 12.0, 10.0, 6.0


def loop_track(name):
    b = Builder(name)
    hw, t, rh, rw = LOOP_W / 2, 0.8, 0.8, 0.5
    prof = [(-hw, -t), (hw, -t), (hw, rh), (hw - rw, rh), (hw - rw, 0), (-hw + rw, 0), (-hw + rw, rh), (-hw, rh)]
    base = ["navy", "navy", "fruit_orange", "fruit_orange", "inlay_off", "fruit_orange", "fruit_orange", "navy"]
    path = [(V(0, -LOOP_RUN, 0), V(0, 0, 1))]
    N = 48
    for i in range(N + 1):
        th = 2 * math.pi * i / N
        path.append((V(LOOP_OFF * th / (2 * math.pi), LOOP_R * math.sin(th), LOOP_R * (1 - math.cos(th))), V(0, -math.sin(th), math.cos(th))))
    path.append((V(LOOP_OFF, LOOP_RUN, 0), V(0, 0, 1)))
    W = V(1, 0, 0)
    rings = [[p + W * u + U * v for u, v in prof] for p, U in path]
    for i in range(len(path) - 1):
        (pa, Ua), (pb, Ub) = path[i], path[i + 1]
        for k in range(len(prof)):
            k2 = (k + 1) % len(prof)
            du, dv = prof[k2][0] - prof[k][0], prof[k2][1] - prof[k][1]
            out = (W * dv - ((Ua + Ub) / 2) * du).normalized()
            pts = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            cen = sum(pts, V0) / 4
            sw = base[k]
            if k in (2, 3, 5, 6):
                sw = "fruit_orange" if i % 2 == 0 else "cart_white"
            oface(b, pts, sw, cen - out)
        if 1 <= i < len(path) - 2 and i % 2 == 1:
            for (pp, UU) in ((pa, Ua),):
                quad = [pa + W * -0.15 + Ua * 0.012, pa + W * 0.15 + Ua * 0.012, pb + W * 0.15 + Ub * 0.012, pb + W * -0.15 + Ub * 0.012]
                oface(b, quad, "cart_white", pa - Ua)
    for i, sgn in ((0, 1), (len(path) - 1, -1)):
        p, U = path[i]
        T = (path[1][0] - path[0][0]).normalized() if i == 0 else (path[-1][0] - path[-2][0]).normalized()
        for poly in ([(-hw, -t), (hw, -t), (hw, 0), (-hw, 0)], [(hw - rw, 0), (hw, 0), (hw, rh), (hw - rw, rh)], [(-hw, 0), (-hw + rw, 0), (-hw + rw, rh), (-hw, rh)]):
            pts = [p + W * u + U * v for u, v in poly]
            cen = sum(pts, V0) / 4
            oface(b, pts, "navy", cen + T * sgn)
    return b, {"radius": LOOP_R, "offset": LOOP_OFF, "width": LOOP_W, "runout": LOOP_RUN, "thickness": t, "rail_height": rh,
               "origin": "entry point of the loop on the road surface (0, 0, 0)", "entry": [0, -LOOP_RUN, 0], "exit": [LOOP_OFF, LOOP_RUN, 0],
               "loop_centre_at_x": [0.0, 0.0, LOOP_R], "top": [LOOP_OFF / 2, 0.0, 2 * LOOP_R],
               "centreline": "x = 12 th / 2pi, y = 10 sin th, z = 10 (1 - cos th); cars drive on the INSIDE (road normal toward the loop axis)",
               "note": "road surface normal at th is (0, -sin th, cos th); the deck structure lies outside the road; rails rise inward"}


# ---------------------------------------------------------------- statue
def statue_pedestal(name):
    b = Builder(name)
    G = "deco_gold"
    cbox(b, V(0, 0, 0.3), (6.0, 6.0, 0.6), "stone_light", c=0.1)
    bx(b, V(0, 0, 0.85), (5.2, 5.2, 0.5), "cream")
    cbox(b, V(0, 0, 2.05), (4.2, 4.2, 1.9), "stone_light", c=0.08)
    bx(b, V(0, 0, 3.2), (4.8, 4.8, 0.4), "cream")
    cbox(b, V(0, 0, 3.7), (5.2, 5.2, 0.6), "stone_light", c=0.08)
    for z, w in ((0.6, 5.3), (3.0, 4.3), (3.4, 5.0)):
        bx(b, V(0, 0, z), (w, w, 0.12), G)
    for sx in (-1, 1):
        for sy in (-1, 1):
            gem(b, V(sx * 2.45, sy * 2.45, 4.02), 0.18, 0.18, 0.12, G, n=4)
    py = -2.1
    bx(b, V(0, py - 0.02, 2.0), (2.4, 0.04, 0.9), "navy")
    for z in (2.0 + 0.5, 2.0 - 0.5):
        bx(b, V(0, py - 0.04, z), (2.6, 0.08, 0.12), G)
    for x in (-1.25, 1.25):
        bx(b, V(x, py - 0.04, 2.0), (0.12, 0.08, 0.9), G)
    return b, {"origin": "footprint centre on the ground", "front": "-y", "footprint": [6.0, 6.0], "height": 4.0, "top_z": 4.0,
               "face": {"centre": [0.0, 2.0], "size": [2.4, 0.9], "plane_y": round(py - 0.04, 3), "normal": [0, -1, 0]}}


def car_ring(y, hw, z0, z1):
    h = z1 - z0
    return [V(-0.75 * hw, y, z0), V(0.75 * hw, y, z0), V(hw, y, z0 + 0.3 * h), V(hw, y, z0 + 0.7 * h), V(0.55 * hw, y, z1), V(-0.55 * hw, y, z1),
            V(-hw, y, z0 + 0.7 * h), V(-hw, y, z0 + 0.3 * h)]


def statue_car(name):
    b = Builder(name)
    G, BR = "deco_gold", "brass"
    secs = [(-6.5, 1.8, 0.0, 0.5), (-5.5, 3.0, 0.0, 0.55), (-3.0, 3.4, 0.0, 0.55), (3.0, 3.4, 0.0, 0.55), (5.5, 3.0, 0.0, 0.55), (6.5, 1.8, 0.0, 0.5)]
    base_r = [[V(-hw, y, 0), V(hw, y, 0), V(hw, y, zt), V(-hw, y, zt)] for y, hw, _, zt in secs]
    loft(b, base_r, ["concrete", "cream", "navy", "cream"], cap_a="cream", cap_b="cream")
    c = Xf(b, pos=(0, 0, 0.55))
    body = [(-5.0, 0.5, 1.4, 1.9), (-4.2, 1.1, 1.0, 2.3), (-2.8, 1.7, 0.8, 2.7), (-1.0, 1.9, 0.8, 3.0), (1.0, 1.9, 0.8, 3.0), (3.0, 1.6, 0.9, 2.8),
            (4.5, 1.1, 1.1, 2.4), (5.0, 0.6, 1.3, 2.0)]
    loft(c, [car_ring(*s) for s in body], [BR, BR, G, G, G, G, G, BR], cap_a=BR, cap_b=BR)
    dome(Xf(c, pos=(0, 0.3, 2.9), scale=(0.9, 1.5, 1.0)), V0, 1.0, 0.9, 8, 3, BR)
    sweep(c, [V(-0.8, 2.4, 2.8), V(0, 2.4, 4.0), V(0.8, 2.4, 2.8)], 0.12, 5, BR)
    for sx in (-1, 1):
        for y in (-3.0, 3.3):
            xf = Xf(c, pos=(sx * 2.15, y, 1.05), rot=(0, 90 * sx, 0))
            lat(xf, V0, [(1.05, -0.4), (1.05, 0.4), (0.5, 0.4)], 10, [BR, G], cap_top=BR, cap_bot=BR)
            gem(c, V(sx * 2.6, y, 1.05), 0.16, 0.34, 0.34, "deco_gold", n=6, phase=0)
        bx(c, V(sx * 1.7, 4.6, 3.2), (0.1, 1.2, 1.4), BR)
        bx(c, V(sx * 0.8, 4.6, 2.55), (0.15, 0.15, 0.9), BR, zm=None)
    bx(c, V(0, 4.6, 3.35), (3.6, 0.9, 0.12), G)
    bx(c, V(0, -4.5, 0.95), (2.6, 0.8, 0.1), BR)
    return b, {"origin": "base centre on the ground", "nose": "-y", "length_car": 10.0, "base": [7.0, 13.0, 0.55], "height": 4.6,
               "note": "generic stylized toy racer, no real car shapes; deco_gold and brass"}


# ---------------------------------------------------------------- roof section
def roof_section(name):
    b = Builder(name)
    zu = lambda y: 15.0 + 3.5 * ((y + 8.0) / 16.0) ** 1.6
    ys = [-8.0 + 16.0 * k / 5 for k in range(6)]
    T = 0.5
    for j in range(6):
        xa, xb = -21 + 7 * j, -14 + 7 * j
        sw = "teal" if j % 2 == 0 else "cream"
        for i in range(5):
            oface(b, [V(xa, ys[i], zu(ys[i]) + T), V(xb, ys[i], zu(ys[i]) + T), V(xb, ys[i + 1], zu(ys[i + 1]) + T), V(xa, ys[i + 1], zu(ys[i + 1]) + T)], sw, V(0, 0, 0))
    for i in range(5):
        oface(b, [V(-21, ys[i], zu(ys[i])), V(21, ys[i], zu(ys[i])), V(21, ys[i + 1], zu(ys[i + 1])), V(-21, ys[i + 1], zu(ys[i + 1]))], "cream", V(0, 0, 40))
        for sx in (-1, 1):
            oface(b, [V(sx * 21, ys[i], zu(ys[i])), V(sx * 21, ys[i + 1], zu(ys[i + 1])), V(sx * 21, ys[i + 1], zu(ys[i + 1]) + T), V(sx * 21, ys[i], zu(ys[i]) + T)],
                  "navy", V(0, 0, 20))
    oface(b, [V(-21, -8, zu(-8)), V(21, -8, zu(-8)), V(21, -8, zu(-8) + T), V(-21, -8, zu(-8) + T)], "navy", V(0, 0, 20))
    oface(b, [V(-21, 8, zu(8)), V(21, 8, zu(8)), V(21, 8, zu(8) + T), V(-21, 8, zu(8) + T)], "navy", V(0, 0, 20))
    for x in (-17.5, -10.5, -3.5, 3.5, 10.5, 17.5):
        sweep(b, [V(x, y, zu(y) - 0.3) for y in ys[:5]], 0.22, 4, "navy")
    masts = (-14.0, 0.0, 14.0)
    for xm in masts:
        cbox(b, V(xm, 6.8, 0.3), (2.4, 2.4, 0.6), "concrete", c=0.08)
        lat(b, V(xm, 6.8, 0.6), [(0.9, 0), (0.55, 15.4), (0.35, 35.9)], 8, ["cream", "teal"], cap_top="cream")
        gem(b, V(xm, 6.8, 36.7), 0.3, 0.3, 0.4, "red_orange", n=6)
        bx(b, V(xm, 6.8, 35.2), (1.4, 0.3, 0.3), "iron_hi")
        top = V(xm, 6.8, 36.0)
        for ax, ay in ((xm, -7.6), (xm - 7, -7.6), (xm + 7, -7.6), (xm - 3.5, 0.0), (xm + 3.5, 0.0)):
            strut(b, top, V(ax, ay, zu(ay) + T + 0.1), 0.07, "iron_hi", n=3)
    return b, {"origin": "footprint centre on the ground", "front": "-y", "length": 42.0, "depth": 16.0, "underside_front": 15.0, "top_z": 37.1,
               "masts_x": [-14.0, 0.0, 14.0], "mast_y": 6.8, "bays": "sits above three SwGrandstandBay modules (centres x -14, 0, 14)"}


# ---------------------------------------------------------------- cannon, rack, preview car
def confetti_cannon(name):
    b = Builder(name)
    pv = V(0, 0.3, 0.8)
    bx(b, V(0, 0, 0.15), (1.6, 1.6, 0.3), "navy", zm=None)
    for sx in (-1, 1):
        bx(b, V(sx * 0.58, pv.y, 0.55), (0.16, 0.5, 0.5), "deco_gold", zm=None)
    cyl(b, V(-0.7, pv.y, pv.z), 1.4, 0.1, 6, "iron_hi", axis=(1, 0, 0))
    xf = Xf(b, pos=pv, rot=(45, 0, 0))
    lat(xf, V0, [(0.26, -0.4), (0.3, 0.75), (0.34, 1.05), (0.48, 1.35)], 8, ["coral", "deco_gold", "coral"], cap_top="black", cap_bot="coral")
    m = Matrix.Rotation(math.radians(45), 3, "X")
    d = m @ V(0, 0, 1)
    muzzle = pv + d * 1.35
    return b, {"origin": "footprint centre on the ground", "muzzle": r3(muzzle), "direction": r3(d), "elevation_deg": 45, "front": "-y", "muzzle_radius": 0.48}


def firework_rack(name):
    b = Builder(name)
    bx(b, V(0, 0, 0.15), (2.0, 2.0, 0.3), "navy", zm=None)
    mouths = []
    for k, (x, y) in enumerate(((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5))):
        sw = "navy" if k % 2 == 0 else "coral"
        lat(b, V(x, y, 0.3), [(0.34, 0), (0.34, 2.2)], 6, sw, cap_top="black")
        lat(b, V(x, y, 0.3), [(0.365, 1.55), (0.365, 1.85)], 6, "cart_white" if k % 2 == 0 else "awning_yellow")
        mouths.append([x, y, 2.5])
    for y in (-0.66, 0.66):
        bx(b, V(0, y, 0.9), (1.9, 0.08, 0.12), "metal")
    return b, {"origin": "footprint centre on the ground", "height": 2.5, "footprint": [2.0, 2.0], "tube_mouths": mouths, "tube_radius": 0.34}


def preview_car(name):
    b = Builder(name)
    A, GL, RB = "accent_neutral", "glass_tint", "raccoon_dark"
    body = [(-6.25, 1.3, 1.1, 2.1), (-5.6, 2.0, 0.85, 2.5), (-4.5, 2.4, 0.7, 2.85), (-2.0, 2.5, 0.7, 3.0), (0.0, 2.55, 0.7, 3.0), (3.0, 2.55, 0.7, 3.0),
            (5.0, 2.4, 0.75, 2.9), (6.0, 1.9, 0.9, 2.6), (6.25, 1.3, 1.1, 2.3)]
    loft(b, [car_ring(*s) for s in body], lambda i, k: RB if k == 0 else A, cap_a=A, cap_b=A)
    cab = [(-2.4, 2.2, 2.1, 3.05), (-1.1, 2.1, 1.65, 4.3), (-0.2, 2.0, 1.55, 4.7), (3.0, 2.0, 1.55, 4.7), (4.3, 2.05, 1.7, 4.15), (5.4, 2.15, 2.0, 3.05)]
    rings = []
    for y, hwb, hwt, zt in cab:
        zm = 2.9 + 0.55 * (zt - 2.9)
        rings.append([V(-hwb, y, 2.9), V(hwb, y, 2.9), V(hwb * 0.95, y, zm), V(hwt, y, zt), V(-hwt, y, zt), V(-hwb * 0.95, y, zm)])

    def csw(i, k):
        if k == 0:
            return A
        if i in (0, 4):
            return GL
        return GL if k in (1, 2, 4, 5) else A

    loft(b, rings, csw, cap_a=GL, cap_b=GL)
    for sx in (-1, 1):
        for y in (-3.9, 3.9):
            xf = Xf(b, pos=(sx * 2.4, y, 1.3), rot=(0, 90 * sx, 0))
            lat(xf, V0, [(1.3, -0.35), (1.3, 0.35), (1.0, 0.35)], 10, [RB, "black"], cap_top=RB)
            cyl(b, V(sx * 2.73, y, 1.3), 0.1, 0.5, 6, "iron_hi", axis=(sx, 0, 0))
        bx(b, V(sx * 1.2, -5.7, 1.75), (0.9, 0.3, 0.5), "lamp_glass")
        bx(b, V(sx * 1.3, 5.75, 2.0), (0.9, 0.3, 0.4), "red_orange")
        bx(b, V(sx * 2.45, -1.2, 3.4), (0.5, 0.3, 0.3), RB)
    return b, {"origin": "ground centre", "size": [5.7, 4.7, 12.5], "nose": "-y", "note": "generic preview fixture, NOT a car design; body is accent_neutral (set MeshPart.Color and clear nothing else), windows glass_tint, wheels raccoon_dark with iron_hi hubs",
               "wheel_centres": [[-2.5, -3.9, 1.3], [2.5, -3.9, 1.3], [-2.5, 3.9, 1.3], [2.5, 3.9, 1.3]], "wheel_radius": 1.3}


# ---------------------------------------------------------------- build
CAPS = {
    "SwHayRun": 220, "SwTyreRun": 320, "SwTyreWall": 520, "SwRopeFence": 220, "SwOwnerSign": 220, "SwWonkyStick": 80,
    "SwRustyShed": 650, "SwPaintedShed": 750, "SwLemonadeStand": 520, "SwFoldingChair": 120, "SwStartBoard": 320,
    "SwPennantPole": 100, "SwWaterBarrel": 160, "SwWheelbarrow": 220,
    "SwBleachers": 900, "SwFanA": 260, "SwFanB": 260, "SwFanC": 260, "SwFanD": 260, "SwFanArmA": 60, "SwFanArmB": 60, "SwFanArmC": 60,
    "SwFanArmD": 60, "SwOfficialPodium": 320, "SwOfficialBody": 420, "SwOfficialArm": 220, "SwMechanic": 420, "SwWrench": 60,
    "SwSnackCart": 620, "SwLapBoard": 260, "SwStartLights": 320, "SwPitGarage": 1200, "SwRollDoor": 120, "SwToolChest": 200,
    "SwTyreStackTall": 220, "SwGrandstandBay": 1600, "SwAnnouncerBooth": 820, "SwFloodTower": 950, "SwGantry": 1200, "SwGantryGold": 420,
    "SwBigScreen": 520, "SwCatchFence": 320, "SwColumn": 40, "SwColumnCap": 80, "SwGuardRail": 220, "SwOrangeBarrier": 120,
    "SwFlameDecal": 60, "SwBlimp": 950, "SwLoopTrack": 1600, "SwStatuePedestal": 320,
    "SwStatueCar": 800, "SwRoofSection": 1000, "SwConfettiCannon": 200, "SwFireworkRack": 160, "SwPreviewCar": 600,
}


def build_all(emit):
    P = "speedway/"

    def go(result, family):
        b, meta = result
        tris = b.triangles()
        cap = CAPS.get(b.name)
        if cap and tris > cap:
            print(f"  OVER CAP {b.name}: {tris} > {cap}")
        emit(b, meta, P + family)

    go(hay_run("SwHayRun"), "Rustic")
    go(tyre_run("SwTyreRun"), "Rustic")
    go(tyre_wall("SwTyreWall"), "Rustic")
    go(rope_fence("SwRopeFence"), "Rustic")
    go(owner_sign("SwOwnerSign"), "Rustic")
    go(wonky_stick("SwWonkyStick"), "Rustic")
    go(shed("SwRustyShed", False), "Rustic")
    go(shed("SwPaintedShed", True), "Rustic")
    go(lemonade_stand("SwLemonadeStand"), "Rustic")
    go(folding_chair("SwFoldingChair"), "Rustic")
    go(start_board("SwStartBoard"), "Rustic")
    go(pennant_pole("SwPennantPole"), "Rustic")
    go(water_barrel("SwWaterBarrel"), "Rustic")
    go(wheelbarrow("SwWheelbarrow"), "Rustic")
    go(bleachers("SwBleachers"), "Fans")
    go(fan("SwFanA", "coral", "sand_cream", "navy", "short", "bark_dark", None), "Fans")
    go(fan("SwFanB", "teal", "log_inner", "metal", "cap", None, "cart_red"), "Fans")
    go(fan("SwFanC", "awning_yellow", "bark_streak", "wild_blue", "pony", "black", "coral"), "Fans")
    go(fan("SwFanD", "lavender", "bark_warm", "stone_light", "puff", "black", None), "Fans")
    go(fan_arm("SwFanArmA", "coral", "sand_cream"), "Fans")
    go(fan_arm("SwFanArmB", "teal", "log_inner"), "Fans")
    go(fan_arm("SwFanArmC", "awning_yellow", "bark_streak"), "Fans")
    go(fan_arm("SwFanArmD", "lavender", "bark_warm"), "Fans")
    go(official_podium("SwOfficialPodium"), "Fans")
    go(official_body("SwOfficialBody"), "Fans")
    go(official_arm("SwOfficialArm"), "Fans")
    go(mechanic("SwMechanic"), "Fans")
    go(wrench("SwWrench"), "Fans")
    go(snack_cart("SwSnackCart"), "Mid")
    go(lap_board("SwLapBoard"), "Mid")
    go(start_lights("SwStartLights"), "Mid")
    go(pit_garage("SwPitGarage"), "Mid")
    go(roll_door("SwRollDoor"), "Mid")
    go(tool_chest("SwToolChest"), "Mid")
    go(tyre_stack_tall("SwTyreStackTall"), "Mid")
    go(grandstand_bay("SwGrandstandBay"), "Mid")
    go(announcer_booth("SwAnnouncerBooth"), "Mid")
    go(flood_tower("SwFloodTower"), "Mid")
    go(gantry("SwGantry"), "Mid")
    go(gantry_gold("SwGantryGold"), "Mid")
    go(big_screen("SwBigScreen"), "Mid")
    go(catch_fence("SwCatchFence"), "Late")
    go(column("SwColumn"), "Late")
    go(column_cap("SwColumnCap"), "Late")
    go(guard_rail("SwGuardRail"), "Late")
    go(orange_barrier("SwOrangeBarrier"), "Late")
    go(flame_decal("SwFlameDecal"), "Late")
    go(blimp("SwBlimp"), "Late")
    go(loop_track("SwLoopTrack"), "Late")
    go(statue_pedestal("SwStatuePedestal"), "Late")
    go(statue_car("SwStatueCar"), "Late")
    go(roof_section("SwRoofSection"), "Late")
    go(confetti_cannon("SwConfettiCannon"), "Late")
    go(firework_rack("SwFireworkRack"), "Late")
    go(preview_car("SwPreviewCar"), "Late")
