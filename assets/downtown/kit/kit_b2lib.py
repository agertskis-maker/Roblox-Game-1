# Downtown kit B2 library (Lane 3, direction B production start): the B2 builder, cheap facade
# helpers, the lot frame, sockets and the exporter. Geometry is still written in ROBLOX axes with
# kitlib's primitives (x right, y up, front = -Z); only the palette differs (kit_b2_palette), so
# kitlib's box/cyl/tube/sweep/wall_with_holes all work on a B2Builder unchanged.
#
# Triangle discipline (the B2 budgets: lots <= 400 per 24 studs of frontage, landmarks <= 2,500,
# skyline 12-40): faces the chase camera never sees are not built. Trim boxes drop their back
# face (it sits in the wall), sills drop their underside, lintels their top, upper-floor windows
# their bottom reveal, and shop displays are flat silhouettes behind the glass, not shelves of
# boxes. Silhouette first; micro-detail invisible at run speed is left out.
#
# Lot frame (the kit contract): a lot's facade lies in the plane z = 0 facing -Z (its LookVector,
# toward the road); the body runs back to z = depth; the footprint is x 0..W. The pivot (0, 0, 0)
# is the front corner on the lot's own left (its -RightVector side), at ground level on the
# frontage line. Recipes are written centred (x -W/2..W/2, facade terms u/v/d from kitlib.fp) and
# finalize() shifts them; a mirrored variant (corner-L from corner-R) is mirrored before the shift.

import json
import math
import os

import bmesh
from mathutils import Vector

import kit_b2_palette as P2
import kitlib
from kitlib import Builder, V, box, dedupe, fp, newell, sweep, wall_with_holes

GRID = P2.GRID
FRONT = V(0, 0, -1)


# ---------------------------------------------------------------- the B2 builder
class B2Builder(Builder):
    """kitlib.Builder pointed at the B2 swatch layout, plus shift and mirror for the lot frame."""

    def face(self, verts, swatch, hint=None):
        pts = dedupe(verts)
        if len(pts) < 3:
            return None
        n = newell(pts)
        if n.length < 1e-9:
            return None
        if hint is not None and n.dot(Vector(hint)) < 0:
            pts = list(reversed(pts))
        bv = [self.bm.verts.new(kitlib._b(v)) for v in pts]
        try:
            f = self.bm.faces.new(bv)
        except ValueError:
            return None
        u, v = P2.swatch_uv(self.sw(swatch))
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        d = kitlib._b((dx, dy, dz))
        for v in self.bm.verts:
            v.co += d

    def mirror(self):
        for v in self.bm.verts:
            v.co.x = -v.co.x
        bmesh.ops.reverse_faces(self.bm, faces=list(self.bm.faces))


def use_b2(module):
    """Point an overnight recipe module (kit_street, kit_hazards, kit_skyline) at the B2 palette:
    its recipes construct `Builder(name)` by module global, so swapping that global makes the
    same recipe write B2 swatch UVs. Every swatch those recipes use exists in kit_b2_palette."""
    module.Builder = B2Builder
    return module


# ---------------------------------------------------------------- frames, sockets, face records
class Frame:
    """Centred recipe coordinates -> final mesh coordinates (optional mirror, then shift)."""

    def __init__(self, dx=0.0, mirror=False):
        self.dx = dx
        self.mirror = mirror

    def p(self, v):
        v = Vector(v)
        x = -v.x if self.mirror else v.x
        return Vector((x + self.dx, v.y, v.z))

    def yaw(self, deg):
        return -deg if self.mirror else deg

    def normal(self, name):
        if self.mirror and name in ("Left", "Right"):
            return "Right" if name == "Left" else "Left"
        return name

    def apply(self, b):
        if self.mirror:
            b.mirror()
        if self.dx:
            b.shift(self.dx)


def sock(p, yaw=0.0, frame=None, **extra):
    """A named socket: {x, y, z, yaw} (yaw in degrees about +Y, Roblox CFrame.Angles sign)."""
    if frame is not None:
        p = frame.p(p)
        yaw = frame.yaw(yaw)
    d = {"x": round(p[0], 3), "y": round(p[1], 3), "z": round(p[2], 3), "yaw": round(yaw, 2)}
    d.update(extra)
    return d


def face_rec(name, centre, w, h, normal="Front", frame=None, both_sides=False, **extra):
    """Where text goes (the Studio builder's sign-face record): centre in the mesh frame."""
    c = frame.p(centre) if frame is not None else Vector(centre)
    n = frame.normal(normal) if frame is not None else normal
    d = {"name": name, "centre": [round(c.x, 3), round(c.y, 3), round(c.z, 3)], "size": [round(w, 3), round(h, 3)], "normal": n}
    if both_sides:
        d["both_sides"] = True
    d.update(extra)
    return d


def fdir(du=0.0, dv=0.0, dd=0.0):
    """A direction in facade terms (u right as seen from the street, v up, d out to the street)."""
    return V(-du, dv, -dd)


# ---------------------------------------------------------------- cheap facade pieces
def fbox(b, u0, u1, v0, v1, d0, d1, sw, skip=("back",)):
    """A facade-aligned box from depth d0 (wall side) to d1 (street side); `skip` lists faces
    not built (default: the back, which sits in the wall)."""
    spec = {"side": sw}
    for k in skip:
        spec["skip_" + k] = True
    box(b, fp((u0 + u1) / 2, (v0 + v1) / 2, (d0 + d1) / 2), (u1 - u0, v1 - v0, d1 - d0), spec)


def fquad(b, u0, u1, v0, v1, d, sw):
    """A flat facade-parallel quad at depth d, facing the street."""
    b.face([fp(u0, v0, d), fp(u1, v0, d), fp(u1, v1, d), fp(u0, v1, d)], sw, FRONT)


def strip_band(b, u0, u1, v0, v1, out, sw, top=True, bottom=True):
    """A protruding horizontal band: front, and optionally top and bottom (no ends, no back)."""
    fquad(b, u0, u1, v0, v1, out, sw)
    if top:
        b.face([fp(u0, v1, 0), fp(u1, v1, 0), fp(u1, v1, out), fp(u0, v1, out)], sw, V(0, 1, 0))
    if bottom:
        b.face([fp(u0, v0, 0), fp(u1, v0, 0), fp(u1, v0, out), fp(u0, v0, out)], sw, V(0, -1, 0))


def pier(b, u0, u1, v0, v1, out, sw, sides=True):
    """A pilaster or pier strip: front plus its two sides (no top, no back)."""
    fquad(b, u0, u1, v0, v1, out, sw)
    if sides:
        b.face([fp(u0, v0, 0), fp(u0, v1, 0), fp(u0, v1, out), fp(u0, v0, out)], sw, fdir(-1))
        b.face([fp(u1, v0, 0), fp(u1, v1, 0), fp(u1, v1, out), fp(u1, v0, out)], sw, fdir(1))


def window(b, u0, u1, v0, v1, rec, sw, bottom=False, sill=True, lintel=True, split=0.55, mullion=False):
    """A recessed window in a hole already cut by wall_with_holes: reveals (bottom only when
    asked: the chase camera looks up at upper floors), two-tone glass (sky reflection on top),
    a stone sill (front + top) and lintel (front + bottom). sw: dict with reveal, glass,
    glass_light, sill, lintel, and optionally mullion."""
    rv = sw.get("reveal", "reveal")
    b.face([fp(u0, v0, 0), fp(u0, v1, 0), fp(u0, v1, -rec), fp(u0, v0, -rec)], rv, fdir(1))
    b.face([fp(u1, v0, 0), fp(u1, v1, 0), fp(u1, v1, -rec), fp(u1, v0, -rec)], rv, fdir(-1))
    b.face([fp(u0, v1, 0), fp(u1, v1, 0), fp(u1, v1, -rec), fp(u0, v1, -rec)], rv, fdir(0, -1))
    if bottom:
        b.face([fp(u0, v0, 0), fp(u1, v0, 0), fp(u1, v0, -rec), fp(u0, v0, -rec)], sw.get("sill", rv), fdir(0, 1))
    if split:
        vs = v0 + (v1 - v0) * split
        fquad(b, u0, u1, v0, vs, -rec, sw.get("glass", "glass"))
        fquad(b, u0, u1, vs, v1, -rec, sw.get("glass_light", "glass_light"))
    else:
        fquad(b, u0, u1, v0, v1, -rec, sw.get("glass", "glass"))
    if mullion:
        uc = (u0 + u1) / 2
        fquad(b, uc - 0.12, uc + 0.12, v0, v1, -rec + 0.08, sw.get("mullion", "frame"))
    if sill:
        s0, s1 = u0 - 0.35, u1 + 0.35
        fquad(b, s0, s1, v0 - 0.32, v0, 0.4, sw.get("sill", "trim_1"))
        b.face([fp(s0, v0, 0), fp(s1, v0, 0), fp(s1, v0, 0.4), fp(s0, v0, 0.4)], sw.get("sill", "trim_1"), V(0, 1, 0))
    if lintel:
        s0, s1 = u0 - 0.4, u1 + 0.4
        fquad(b, s0, s1, v1, v1 + 0.7, 0.25, sw.get("lintel", "trim_1"))
        b.face([fp(s0, v1, 0), fp(s1, v1, 0), fp(s1, v1, 0.25), fp(s0, v1, 0.25)], sw.get("lintel", "trim_1"), V(0, -1, 0))


def arch_window(b, u0, u1, v0, v1, rec, wall_sw, sw, seg=4, sill=True):
    """An arched recessed window (kitlib.opening's arch, with few segments) and a keystone."""
    kitlib.opening(b, u0, u1, v0, v1, "arch", rec, wall_sw, sw.get("reveal", "reveal"), sw.get("glass", "glass"), arc_seg=seg)
    uc = (u0 + u1) / 2
    fbox(b, uc - 0.45, uc + 0.45, v1 - 0.3, v1 + 0.6, 0, 0.3, sw.get("lintel", "trim_1"), skip=("back", "top"))
    if sill:
        s0, s1 = u0 - 0.35, u1 + 0.35
        fquad(b, s0, s1, v0 - 0.32, v0, 0.4, sw.get("sill", "trim_1"))
        b.face([fp(s0, v0, 0), fp(s1, v0, 0), fp(s1, v0, 0.4), fp(s0, v0, 0.4)], sw.get("sill", "trim_1"), V(0, 1, 0))


def cornice(b, u0, u1, v, out=1.9, sw="trim_1", h=2.0):
    """A three-step cornice: a stepped profile swept along the facade (no brackets: they are
    invisible at run speed; the step shadows carry the read)."""
    a, c = out * 0.2, out * 0.55
    prof = [(v, 0.05), (v, -a), (v + h * 0.3, -a), (v + h * 0.3, -c), (v + h * 0.62, -c), (v + h * 0.62, -out), (v + h, -out), (v + h, 0.05)]
    sweep(b, prof, -u1, -u0, sw)


def body(b, w, v0, v1, D, side="wall", back="wall", roof=None, x0=None, x1=None):
    """Side and back walls (and optionally a roof slab at v1) of a centred block."""
    x0 = -w / 2 if x0 is None else x0
    x1 = w / 2 if x1 is None else x1
    b.face([V(x0, v0, 0), V(x0, v0, D), V(x0, v1, D), V(x0, v1, 0)], side, V(-1, 0, 0))
    b.face([V(x1, v0, 0), V(x1, v0, D), V(x1, v1, D), V(x1, v1, 0)], side, V(1, 0, 0))
    b.face([V(x0, v0, D), V(x1, v0, D), V(x1, v1, D), V(x0, v1, D)], back, V(0, 0, 1))
    if roof:
        b.face([V(x0, v1, 0), V(x1, v1, 0), V(x1, v1, D), V(x0, v1, D)], roof, V(0, 1, 0))


def parapet(b, w, v0, v1, D, sw="wall", cap="trim_1", inset=0.0):
    """A front parapet wall over the full width (front, back, top, ends) with a coping strip."""
    box(b, V(0, (v0 + v1) / 2, 0.4 + inset), (w, v1 - v0, 0.8), {"side": sw, "top": cap, "skip_bottom": True})
    fbox(b, -w / 2 - 0.15, w / 2 + 0.15, v1, v1 + 0.3, -0.15 - inset, 0.95 - inset, cap, skip=("bottom",))


def plate(b, outline, d0, d1, front_sw, edge_sw=None, back=True):
    """A flat board in facade (u, v) terms extruded from d0 (wall) to d1 (street)."""
    edge_sw = edge_sw or front_sw
    b.face([fp(u, v, d1) for u, v in outline], front_sw, FRONT)
    if back:
        b.face([fp(u, v, d0) for u, v in outline], edge_sw, V(0, 0, 1))
    n = len(outline)
    cu = sum(p[0] for p in outline) / n
    cv = sum(p[1] for p in outline) / n
    for i in range(n):
        (au, av), (cu2, cv2) = outline[i], outline[(i + 1) % n]
        b.face([fp(au, av, d0), fp(cu2, cv2, d0), fp(cu2, cv2, d1), fp(au, av, d1)], edge_sw, fdir((au + cu2) / 2 - cu, (av + cv2) / 2 - cv))


def circle_uv(cu, cv, r, n=12, phase=0.0):
    return [(cu + math.cos(phase + 2 * math.pi * k / n) * r, cv + math.sin(phase + 2 * math.pi * k / n) * r) for k in range(n)]


def side_plate(b, x, outline_zy, t, front_sw, edge_sw=None):
    """A board standing in a plane x = const (a blade sign, a flag): outline in (z, y), thickness
    t centred on x, both big faces built (they face +X and -X)."""
    edge_sw = edge_sw or front_sw
    for sx in (-1, 1):
        b.face([V(x + sx * t / 2, y, z) for z, y in outline_zy], front_sw, V(sx, 0, 0))
    n = len(outline_zy)
    cz = sum(p[0] for p in outline_zy) / n
    cy = sum(p[1] for p in outline_zy) / n
    for i in range(n):
        (za, ya), (zc, yc) = outline_zy[i], outline_zy[(i + 1) % n]
        b.face([V(x - t / 2, ya, za), V(x + t / 2, ya, za), V(x + t / 2, yc, zc), V(x - t / 2, yc, zc)], edge_sw, V(0, (ya + yc) / 2 - cy, (za + zc) / 2 - cz))


# ---------------------------------------------------------------- builder proxies
class Offset:
    """Draws onto `inner` with every point moved by (dx, dy, dz): facade-space geometry for a
    set-back storey (dz > 0) or a projecting bay (dz < 0)."""

    def __init__(self, inner, dz, dx=0.0, dy=0.0):
        self.inner = inner
        self.d = V(dx, dy, dz)

    def face(self, verts, swatch, hint=None):
        return self.inner.face([Vector(v) + self.d for v in verts], swatch, hint)

    def face2(self, verts, swatch):
        self.inner.face2([Vector(v) + self.d for v in verts], swatch)


class SideWall:
    """Draws facade-space geometry onto a side wall: the facade plane is turned to x = hw facing
    +X (side=+1) or x = -hw facing -X (side=-1); facade u runs along the depth so that u
    -D/2..D/2 covers z D..0 (+X side) or 0..D (-X side), always reading left-to-right for a
    viewer standing outside that wall."""

    def __init__(self, inner, hw, D, side=1, z0=0.0):
        self.inner = inner
        self.hw = hw
        self.D = D
        self.side = side
        self.z0 = z0

    def _p(self, v):
        if self.side > 0:  # yaw -90: (x, z) -> (-z, x)
            return V(-v.z + self.hw, v.y, v.x + self.D / 2 + self.z0)
        return V(v.z - self.hw, v.y, -v.x + self.D / 2 + self.z0)  # yaw +90: (x, z) -> (z, -x)

    def _d(self, v):
        return V(-v.z, v.y, v.x) if self.side > 0 else V(v.z, v.y, -v.x)

    def face(self, verts, swatch, hint=None):
        return self.inner.face([self._p(Vector(v)) for v in verts], swatch, None if hint is None else self._d(Vector(hint)))

    def face2(self, verts, swatch):
        pts = [self._p(Vector(v)) for v in verts]
        n = newell(pts)
        if n.length < 1e-9:
            return
        n = n.normalized()
        self.inner.face(pts, swatch, n)
        self.inner.face([p - n * 0.01 for p in pts], swatch, -n)


# ---------------------------------------------------------------- road frames (parameterised)
def road_frame(kind, radius=360.0):
    """Local (x, z) of road distance sl and lateral offset off (+ right) for a piece starting at
    the origin heading -Z. CurveR bends toward +X, CurveL toward -X."""
    if kind == "straight":
        return lambda sl, off: (off, -sl)
    sgn = 1.0 if kind == "curveR" else -1.0
    R = radius

    def P(sl, off):
        t = sl / R
        r = R - sgn * off
        return (sgn * (R - r * math.cos(t)), -r * math.sin(t))

    return P


# ---------------------------------------------------------------- export
def export_json(obj, folder, meta):
    """kitlib.export_json's compact format (name, triangles, bounds, meta, grid, p, t), plus the
    contract fields inside meta: bounds and the pivot offset (bounds centre relative to the
    pivot: an imported MeshPart is centred on its bounds, so PivotOffset = CFrame.new(-centre))."""
    me = obj.data
    me.calc_loop_triangles()
    uv_layer = me.uv_layers.active.data
    positions = []
    for v in me.vertices:
        positions.extend(round(c, 3) for c in kitlib.to_roblox(v.co))
    tris = []
    used = set()
    for lt in me.loop_triangles:
        u, v = uv_layer[lt.loops[0]].uv
        gx = min(GRID - 1, int(u * GRID))
        gy = min(GRID - 1, int((1 - v) * GRID))
        idx = gy * GRID + gx
        used.add(idx)
        tris.extend((lt.vertices[0], lt.vertices[1], lt.vertices[2], idx))
    lo = [min(positions[i::3]) for i in range(3)]
    hi = [max(positions[i::3]) for i in range(3)]
    meta = dict(meta)
    meta["bounds"] = [lo, hi]
    meta["pivot_offset"] = [round((lo[i] + hi[i]) / 2, 3) for i in range(3)]
    meta["swatches_used"] = sorted(P2.NAMES[i] for i in used if i < len(P2.NAMES))
    data = {
        "name": obj.name,
        "triangles": len(me.loop_triangles),
        "bounds": [lo, hi],
        "meta": meta,
        "grid": GRID,
        "p": positions,
        "t": tris,
    }
    with open(os.path.join(folder, obj.name + ".json"), "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return data
