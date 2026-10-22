# Downtown kit library (Lane 3 look development): geometry helpers and the exporter for the
# headless Blender build (build_kit.py). Adapted from assets/island/kit/kitlib.py on the island
# branch, with three differences:
#   1. Geometry is written directly in ROBLOX axes (x right, y up, front = -Z, the LookVector).
#      The Builder stores Blender axes internally and export_json converts back, so the JSON is
#      the same format as the island kit (name, triangles, bounds, meta, grid, p, t).
#   2. Every face can take an orientation hint (a direction it must face); the winding is fixed
#      automatically, so faces always point out.
#   3. The palette lives in palette.py: one swatch layout shared by three colour variants.
# Low-poly, faceted, flat normals. Every face is coloured by pointing all its UVs at the centre
# of one palette swatch. Units: 1 unit = 1 stud.

import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

import palette

GRID = palette.GRID


def V(x, y=0.0, z=0.0):
    return Vector((x, y, z))


def _b(p):
    # Roblox (x, y, z) -> Blender (x, -z, y)
    return Vector((p[0], -p[2], p[1]))


def newell(pts):
    n = Vector((0.0, 0.0, 0.0))
    for i in range(len(pts)):
        a, c = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - c.y) * (a.z + c.z)
        n.y += (a.z - c.z) * (a.x + c.x)
        n.z += (a.x - c.x) * (a.y + c.y)
    return n


def dedupe(pts, eps=1e-5):
    out = []
    for p in pts:
        p = Vector(p)
        if not out or (p - out[-1]).length > eps:
            out.append(p)
    if len(out) > 1 and (out[0] - out[-1]).length <= eps:
        out.pop()
    return out


# ---------------------------------------------------------------- mesh building
class Builder:
    """Collects faceted geometry in Roblox axes; every face keeps its own swatch."""

    def __init__(self, name, remap=None):
        self.name = name
        self.remap = remap or {}
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def sw(self, swatch):
        return self.remap.get(swatch, swatch)

    def face(self, verts, swatch, hint=None):
        """A polygon; `hint` is a direction (Roblox axes) the face should point toward."""
        pts = dedupe(verts)
        if len(pts) < 3:
            return None
        n = newell(pts)
        if n.length < 1e-9:
            return None
        if hint is not None and n.dot(Vector(hint)) < 0:
            pts = list(reversed(pts))
        bv = [self.bm.verts.new(_b(v)) for v in pts]
        try:
            f = self.bm.faces.new(bv)
        except ValueError:
            return None
        u, v = palette.swatch_uv(self.sw(swatch))
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    def tri(self, a, b, c, swatch, hint=None):
        return self.face([a, b, c], swatch, hint)

    def quad(self, a, b, c, d, swatch, hint=None):
        return self.face([a, b, c, d], swatch, hint)

    def face2(self, verts, swatch):
        """A two-sided face (MeshPart.DoubleSided cannot be set from a script): front and back."""
        pts = dedupe(verts)
        if len(pts) < 3:
            return
        n = newell(pts)
        if n.length < 1e-9:
            return
        n = n.normalized()
        self.face(pts, swatch, n)
        self.face([p - n * 0.01 for p in pts], swatch, -n)

    def triangles(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def to_object(self, mirror_x=False):
        if mirror_x:
            for v in self.bm.verts:
                v.co.x = -v.co.x
            bmesh.ops.reverse_faces(self.bm, faces=list(self.bm.faces))
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        for p in me.polygons:
            p.use_smooth = False
        return obj


# ---------------------------------------------------------------- primitives (Roblox axes)
def box(b, centre, size, swatch, yaw=0.0):
    """An axis box rotated by `yaw` radians about +Y. `swatch` is a name, or a dict with any of
    top, bottom, front (-Z), back (+Z), left (-X), right (+X), side (default for the rest)."""
    c = Vector(centre)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    cs, sn = math.cos(yaw), math.sin(yaw)

    def P(x, y, z):
        return c + Vector((x * cs + z * sn, y, -x * sn + z * cs))

    def R(x, y, z):
        return Vector((x * cs + z * sn, y, -x * sn + z * cs))

    def pick(key):
        if isinstance(swatch, str):
            return swatch
        return swatch.get(key, swatch.get("side", swatch.get("top")))

    faces = [
        ("top", [P(-hx, hy, -hz), P(hx, hy, -hz), P(hx, hy, hz), P(-hx, hy, hz)], R(0, 1, 0)),
        ("bottom", [P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, -hy, hz), P(-hx, -hy, hz)], R(0, -1, 0)),
        ("front", [P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, hy, -hz), P(-hx, hy, -hz)], R(0, 0, -1)),
        ("back", [P(-hx, -hy, hz), P(hx, -hy, hz), P(hx, hy, hz), P(-hx, hy, hz)], R(0, 0, 1)),
        ("left", [P(-hx, -hy, -hz), P(-hx, -hy, hz), P(-hx, hy, hz), P(-hx, hy, -hz)], R(-1, 0, 0)),
        ("right", [P(hx, -hy, -hz), P(hx, -hy, hz), P(hx, hy, hz), P(hx, hy, -hz)], R(1, 0, 0)),
    ]
    for key, pts, n in faces:
        if not isinstance(swatch, str) and swatch.get("skip_" + key):
            continue
        b.face(pts, pick(key), n)


def box_mm(b, lo, hi, swatch):
    lo, hi = Vector(lo), Vector(hi)
    box(b, (lo + hi) / 2, hi - lo, swatch)


def prism(b, pts2, y0, y1, side_sw, top_sw=None, bottom_sw=None, top=True, bottom=False):
    """A vertical prism over a 2D outline [(x, z), ...] (any winding, may be concave)."""
    pts2 = [tuple(p) for p in pts2]
    n = len(pts2)
    cx = sum(p[0] for p in pts2) / n
    cz = sum(p[1] for p in pts2) / n
    sides = side_sw if isinstance(side_sw, (list, tuple)) else [side_sw]
    # orientation of the outline in the xz plane
    area = sum(pts2[i][0] * pts2[(i + 1) % n][1] - pts2[(i + 1) % n][0] * pts2[i][1] for i in range(n))
    for i in range(n):
        a, c = pts2[i], pts2[(i + 1) % n]
        ex, ez = c[0] - a[0], c[1] - a[1]
        # outward normal of the edge
        out = Vector((ez, 0, -ex)) if area > 0 else Vector((-ez, 0, ex))
        if out.length < 1e-9:
            continue
        b.face([V(a[0], y0, a[1]), V(c[0], y0, c[1]), V(c[0], y1, c[1]), V(a[0], y1, a[1])], sides[i % len(sides)], out)
    if top:
        b.face([V(p[0], y1, p[1]) for p in pts2], top_sw or sides[0], V(0, 1, 0))
    if bottom:
        b.face([V(p[0], y0, p[1]) for p in pts2], bottom_sw or sides[0], V(0, -1, 0))


def circle2(cx, cz, r, sides, phase=0.0, start=0.0, end=None):
    if end is None:
        return [(cx + math.cos(phase + 2 * math.pi * k / sides) * r, cz + math.sin(phase + 2 * math.pi * k / sides) * r) for k in range(sides)]
    return [(cx + math.cos(start + (end - start) * k / sides) * r, cz + math.sin(start + (end - start) * k / sides) * r) for k in range(sides + 1)]


def rounded_rect2(x0, z0, x1, z1, r, seg=3, corners=(True, True, True, True)):
    """Outline of a rectangle with rounded corners (corner order: x0z0, x1z0, x1z1, x0z1)."""
    out = []
    spec = [
        ((x0 + r, z0 + r), math.pi, 1.5 * math.pi, (x0, z0)),
        ((x1 - r, z0 + r), 1.5 * math.pi, 2 * math.pi, (x1, z0)),
        ((x1 - r, z1 - r), 0.0, 0.5 * math.pi, (x1, z1)),
        ((x0 + r, z1 - r), 0.5 * math.pi, math.pi, (x0, z1)),
    ]
    for (c, a0, a1, sharp), rnd in zip(spec, corners):
        if rnd and r > 0:
            for k in range(seg + 1):
                a = a0 + (a1 - a0) * k / seg
                out.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
        else:
            out.append(sharp)
    return out


def cyl(b, base, height, radius, sides, swatch, top=True, bottom=False, r_top=None, top_sw=None, phase=0.0):
    base = Vector(base)
    rt = radius if r_top is None else r_top
    lo = [base + V(math.cos(phase + 2 * math.pi * k / sides) * radius, 0, math.sin(phase + 2 * math.pi * k / sides) * radius) for k in range(sides)]
    hi = [base + V(math.cos(phase + 2 * math.pi * k / sides) * rt, height, math.sin(phase + 2 * math.pi * k / sides) * rt) for k in range(sides)]
    mid = base + V(0, height / 2, 0)
    for k in range(sides):
        k2 = (k + 1) % sides
        q = [lo[k], lo[k2], hi[k2], hi[k]]
        cen = sum(q, Vector()) / 4
        b.face(q, swatch, V(cen.x - mid.x, 0, cen.z - mid.z))
    if top and rt > 0:
        b.face(hi, top_sw or swatch, V(0, 1, 0))
    if bottom:
        b.face(lo, swatch, V(0, -1, 0))
    return lo, hi


def frame_axes(axis):
    axis = Vector(axis).normalized()
    ref = V(0, 1, 0) if abs(axis.y) < 0.9 else V(1, 0, 0)
    u = axis.cross(ref).normalized()
    w = axis.cross(u).normalized()
    return u, w


def ring(centre, axis, radius, sides, phase=0.0):
    u, w = frame_axes(axis)
    c = Vector(centre)
    return [c + (u * math.cos(phase + 2 * math.pi * k / sides) + w * math.sin(phase + 2 * math.pi * k / sides)) * radius for k in range(sides)]


def tube(b, path, radii, sides, swatch, cap=True, phase=0.0):
    """A faceted tube along a polyline (any direction), radius per point."""
    path = [Vector(p) for p in path]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(path)
    rings = []
    for i, p in enumerate(path):
        if i == 0:
            axis = path[1] - path[0]
        elif i == len(path) - 1:
            axis = path[-1] - path[-2]
        else:
            axis = (path[i + 1] - path[i]).normalized() + (path[i] - path[i - 1]).normalized()
        rings.append(ring(p, axis, radii[i], sides, phase))
    sws = swatch if isinstance(swatch, (list, tuple)) else [swatch]
    for i in range(len(rings) - 1):
        a, c = rings[i], rings[i + 1]
        mid = (path[i] + path[i + 1]) / 2
        for k in range(sides):
            k2 = (k + 1) % sides
            q = [a[k], a[k2], c[k2], c[k]]
            cen = sum(q, Vector()) / 4
            b.face(q, sws[i % len(sws)], cen - mid)
    if cap:
        b.face(rings[0], sws[0], path[0] - path[1])
        b.face(rings[-1], sws[-1], path[-1] - path[-2])
    return rings


def beam(b, a, c, w, h, swatch):
    """A square-section bar from a to c (a cheap 4-sided tube)."""
    tube(b, [a, c], max(w, h) * 0.7071, 4, swatch, phase=math.pi / 4)


def sphere(b, centre, size, swatches, subdiv=1, rng=None, jitter=0.0, flatten=1.0, light_dir=(0.3, 1.0, -0.2)):
    """A faceted ellipsoid (icosphere), each face coloured by how much it faces the light."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        s = 1 + (rng.uniform(-jitter, jitter) if rng and jitter else 0)
        v.co = Vector((n.x * size[0] * s, n.z * size[1] * s * flatten, n.y * size[2] * s))
    L = Vector(light_dir).normalized()
    c = Vector(centre)
    for f in bm.faces:
        pts = [c + v.co for v in f.verts]
        cen = sum(pts, Vector()) / len(pts)
        nrm = (cen - c).normalized()
        light = nrm.dot(L) + (rng.uniform(-0.15, 0.15) if rng else 0)
        idx = min(len(swatches) - 1, max(0, int((light + 1) / 2 * len(swatches))))
        b.face(pts, swatches[idx], cen - c)
    bm.free()


def torus(b, centre, R, r, seg_major, seg_minor, swatch_fn, axis_up=True):
    """A torus lying flat (hole along +Y) or standing (hole along +Z, facing the front).
    swatch_fn(i_major, j_minor, outward_y) -> swatch name."""
    c = Vector(centre)
    pts = []
    for i in range(seg_major):
        a = 2 * math.pi * i / seg_major
        row = []
        for j in range(seg_minor):
            t = 2 * math.pi * j / seg_minor
            rr = R + r * math.cos(t)
            if axis_up:
                p = V(math.cos(a) * rr, r * math.sin(t), math.sin(a) * rr)
            else:
                p = V(math.cos(a) * rr, math.sin(a) * rr, -r * math.sin(t))
            row.append(c + p)
        pts.append(row)
    for i in range(seg_major):
        i2 = (i + 1) % seg_major
        a = 2 * math.pi * (i + 0.5) / seg_major
        ring_c = c + (V(math.cos(a) * R, 0, math.sin(a) * R) if axis_up else V(math.cos(a) * R, math.sin(a) * R, 0))
        for j in range(seg_minor):
            j2 = (j + 1) % seg_minor
            q = [pts[i][j], pts[i2][j], pts[i2][j2], pts[i][j2]]
            cen = sum(q, Vector()) / 4
            out = cen - ring_c
            b.face(q, swatch_fn(i, j, out.normalized()), out)


def disc(b, centre, radius, sides, swatch, normal=(0, 1, 0), phase=0.0):
    rim = ring(centre, normal, radius, sides, phase)
    b.face(rim, swatch, normal)
    return rim


def sweep(b, profile, x0, x1, swatch, caps=True, cap_sw=None):
    """Sweep a 2D profile [(y, z), ...] (a closed outline in the yz plane) along x from x0 to
    x1: cornices, sills, rails. Faces point away from the profile's centre."""
    n = len(profile)
    cy = sum(p[0] for p in profile) / n
    cz = sum(p[1] for p in profile) / n
    sws = swatch if isinstance(swatch, (list, tuple)) else [swatch]
    for i in range(n):
        a, c = profile[i], profile[(i + 1) % n]
        q = [V(x0, a[0], a[1]), V(x1, a[0], a[1]), V(x1, c[0], c[1]), V(x0, c[0], c[1])]
        my, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
        b.face(q, sws[i % len(sws)], V(0, my - cy, mz - cz))
    if caps:
        b.face([V(x0, p[0], p[1]) for p in profile], cap_sw or sws[0], V(-1, 0, 0))
        b.face([V(x1, p[0], p[1]) for p in profile], cap_sw or sws[0], V(1, 0, 0))


def clip_poly(poly, x0, y0, x1, y1):
    """Sutherland-Hodgman clip of a 2D polygon to an axis rectangle."""

    def clip(pts, inside, inter):
        out = []
        for i in range(len(pts)):
            a, c = pts[i - 1], pts[i]
            ia, ic = inside(a), inside(c)
            if ic:
                if not ia:
                    out.append(inter(a, c))
                out.append(c)
            elif ia:
                out.append(inter(a, c))
        return out

    def ix(xv):
        return lambda a, c: (xv, a[1] + (c[1] - a[1]) * (xv - a[0]) / (c[0] - a[0]))

    def iy(yv):
        return lambda a, c: (a[0] + (c[0] - a[0]) * (yv - a[1]) / (c[1] - a[1]), yv)

    pts = list(poly)
    for inside, inter in (
        (lambda p: p[0] >= x0, ix(x0)),
        (lambda p: p[0] <= x1, ix(x1)),
        (lambda p: p[1] >= y0, iy(y0)),
        (lambda p: p[1] <= y1, iy(y1)),
    ):
        if not pts:
            break
        pts = clip(pts, inside, inter)
    return pts


def stripes(b, u0, v0, u1, v1, width, swatches, to3d, hint, slant=1.0):
    """Diagonal stripes clipped to a rectangle in a 2D frame; to3d(u, v) -> point."""
    span = (u1 - u0) + (v1 - v0) * abs(slant)
    k = 0
    s = u0 - (v1 - v0) * abs(slant) - width
    while s < u1 + width:
        band = [(s, v0), (s + width, v0), (s + width + (v1 - v0) * slant, v1), (s + (v1 - v0) * slant, v1)]
        poly = clip_poly(band, u0, v0, u1, v1)
        if len(poly) >= 3:
            b.face([to3d(p[0], p[1]) for p in poly], swatches[k % len(swatches)], hint)
        s += width
        k += 1
    return span


# ---------------------------------------------------------------- facade frame
# A facade lies in the local plane z = 0 and faces -Z (the LookVector, Roblox Front face). The
# building body is behind it (z > 0). In facade terms: u runs to the right as seen by someone
# standing in front of it (that is local -X), v is up, d is outward toward the viewer (local -Z).
def fp(u, v, d=0.0):
    return V(-u, v, -d)


FRONT = V(0, 0, -1)


def fface(b, uv_pts, d, swatch):
    """A facade-parallel polygon at depth d, facing the viewer."""
    b.face([fp(u, v, d) for (u, v) in uv_pts], swatch, FRONT)


def wall_with_holes(b, u0, u1, v0, v1, holes, swatch, d=0.0):
    """A flat facade wall with rectangular holes [(hu0, hu1, hv0, hv1), ...] (non-overlapping)."""
    us = sorted({u0, u1} | {h[0] for h in holes if u0 < h[0] < u1} | {h[1] for h in holes if u0 < h[1] < u1})
    for i in range(len(us) - 1):
        a, c = us[i], us[i + 1]
        mid = (a + c) / 2
        cover = sorted((h[2], h[3]) for h in holes if h[0] <= mid <= h[1])
        y = v0
        for hv0, hv1 in cover:
            if hv0 > y + 1e-6:
                fface(b, [(a, y), (c, y), (c, hv0), (a, hv0)], d, swatch)
            y = max(y, hv1)
        if v1 > y + 1e-6:
            fface(b, [(a, y), (c, y), (c, v1), (a, v1)], d, swatch)


def opening(b, u0, u1, v0, v1, shape, recess, wall_sw, reveal_sw, glass_sw, d=0.0, arc_seg=8, mullion=None, glass_split=None):
    """Fill a rectangular hole (already cut by wall_with_holes) with a recessed window.
    shape: 'rect', 'arch' (semicircular top within the rectangle) or 'round' (circle in a square)."""
    uc = (u0 + u1) / 2
    w = u1 - u0
    if shape == "rect":
        prof = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    elif shape == "arch":
        r = w / 2
        vc = v1 - r
        prof = [(u0, v0), (u1, v0)]
        for k in range(arc_seg + 1):
            a = math.pi * k / arc_seg
            prof.append((uc + math.cos(a) * r, vc + math.sin(a) * r))
        prof.append((u0, v0))
        prof = prof[:-1]
        # wall infill between the arch and the rectangle's top corners
        for k in range(arc_seg):
            a0, a1 = math.pi * k / arc_seg, math.pi * (k + 1) / arc_seg
            p0 = (uc + math.cos(a0) * r, vc + math.sin(a0) * r)
            p1 = (uc + math.cos(a1) * r, vc + math.sin(a1) * r)
            o0 = _proj_sq(uc, vc, r, a0, top_only=True)
            o1 = _proj_sq(uc, vc, r, a1, top_only=True)
            pts = [o0, o1, p1, p0]
            if a0 < math.pi / 4 < a1 or a0 < 3 * math.pi / 4 < a1:
                pass
            fface(b, pts, d, wall_sw)
    elif shape == "round":
        r = w / 2
        vc = (v0 + v1) / 2
        n = arc_seg * 2
        prof = [(uc + math.cos(2 * math.pi * k / n) * r, vc + math.sin(2 * math.pi * k / n) * r) for k in range(n)]
        for k in range(n):
            a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
            fface(b, [_proj_sq(uc, vc, r, a0), _proj_sq(uc, vc, r, a1), prof[(k + 1) % n], prof[k]], d, wall_sw)
    else:
        raise ValueError(shape)
    # reveals: from the wall plane back into the building
    n = len(prof)
    cu = sum(p[0] for p in prof) / n
    cv = sum(p[1] for p in prof) / n
    for i in range(n):
        a, c = prof[i], prof[(i + 1) % n]
        mu, mv = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
        q = [fp(a[0], a[1], d), fp(c[0], c[1], d), fp(c[0], c[1], d - recess), fp(a[0], a[1], d - recess)]
        inward = fp(cu - mu, cv - mv, 0)
        b.face(q, reveal_sw, inward)
    # the glass at the back
    if glass_split:
        # horizontal two-tone glass (sky reflection on the upper part) for rect openings
        vs = v0 + (v1 - v0) * glass_split
        fface(b, [(u0, v0), (u1, v0), (u1, vs), (u0, vs)], d - recess, glass_sw[0])
        fface(b, [(u0, vs), (u1, vs), (u1, v1), (u0, v1)], d - recess, glass_sw[1])
    else:
        fface(b, prof, d - recess, glass_sw if isinstance(glass_sw, str) else glass_sw[0])
    if mullion:
        sw, t = mullion
        if shape == "rect":
            box(b, fp(uc, (v0 + v1) / 2, d - recess + 0.1), (t, v1 - v0, 0.2), sw)
        elif shape == "arch":
            box(b, fp(uc, (v0 + v1) / 2 - w / 4, d - recess + 0.1), (t, v1 - v0 - w / 2, 0.2), sw)
    return prof


def _proj_sq(uc, vc, r, a, top_only=False):
    ca, sa = math.cos(a), math.sin(a)
    t = []
    if abs(ca) > 1e-9:
        t.append(r / abs(ca))
    if abs(sa) > 1e-9:
        t.append(r / abs(sa))
    k = min(t)
    return (uc + ca * k, vc + sa * k)


# ---------------------------------------------------------------- export
def to_roblox(v):
    # Blender Z-up, -Y forward -> Roblox Y-up, -Z forward
    return (v.x, v.z, -v.y)


def export_json(obj, folder, meta):
    """Compact mesh data for the Studio builder, the island kit's format: shared positions
    (Roblox axes) and, per triangle, three vertex indices and the palette swatch index. Normals
    are flat per face."""
    me = obj.data
    me.calc_loop_triangles()
    uv_layer = me.uv_layers.active.data
    positions = []
    for v in me.vertices:
        positions.extend(round(c, 3) for c in to_roblox(v.co))
    tris = []
    for lt in me.loop_triangles:
        u, v = uv_layer[lt.loops[0]].uv
        gx = min(GRID - 1, int(u * GRID))
        gy = min(GRID - 1, int((1 - v) * GRID))
        tris.extend((lt.vertices[0], lt.vertices[1], lt.vertices[2], gy * GRID + gx))
    lo = [min(positions[i::3]) for i in range(3)]
    hi = [max(positions[i::3]) for i in range(3)]
    data = {
        "name": obj.name,
        "triangles": len(me.loop_triangles),
        "bounds": [lo, hi],
        "meta": meta,
        "grid": GRID,
        "p": positions,
        "t": tris,
    }
    path = os.path.join(folder, obj.name + ".json")
    with open(path, "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return data["triangles"], lo, hi
