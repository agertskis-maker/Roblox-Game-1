# World kits library (Lane 3, Round 2): the WorldBuilder (kitlib.Builder pointed at kit_world_palette), the exporter
# and the small scenery parts both World kits share (ground pads, rocks, cacti, pines, palms, plain buildings).
# Same geometry conventions as kit_b2lib: Roblox axes (x right, y up, front = -Z), a lot's facade in the plane z = 0
# facing -Z, footprint x 0..W, z 0..D, pivot = the front corner on the lot's own left at ground level on the
# frontage line. Recipes are written centred (x -W/2..W/2) and finished with shift(W/2).
#
# Triangle discipline as in B2: faces the chase camera cannot see are not built (no bottoms), and a silhouette is
# worth more than micro-detail at run speed. The budget for a scenery lot is about 700 triangles.

import json
import math
import os
import random

import bmesh
from mathutils import Vector

import kit_world_palette as W
import kitlib
from kit_b2lib import sock
from kitlib import V, box, cyl, prism, sphere, beam, circle2, dedupe, newell, wall_with_holes, fp

GRID = W.GRID


class WorldBuilder(kitlib.Builder):
    """kitlib.Builder with the world palette's swatch UVs, plus a shift for the lot frame."""

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
        u, v = W.swatch_uv(self.sw(swatch))
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        d = kitlib._b((dx, dy, dz))
        for v in self.bm.verts:
            v.co += d


def new(name):
    return WorldBuilder(name)


def export_json(obj, folder, meta):
    """kit_b2lib.export_json's format (name, triangles, bounds, meta, grid, p, t) with the world palette's names."""
    me = obj.data
    me.calc_loop_triangles()
    uv_layer = me.uv_layers.active.data
    positions = []
    for v in me.vertices:
        positions.extend(round(c, 3) for c in kitlib.to_roblox(v.co))
    tris, used = [], set()
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
    meta["swatches_used"] = sorted(W.NAMES[i] for i in used if i < len(W.NAMES) and W.NAMES[i])
    data = {"name": obj.name, "triangles": len(me.loop_triangles), "bounds": [lo, hi], "meta": meta, "grid": GRID, "p": positions, "t": tris}
    with open(os.path.join(folder, obj.name + ".json"), "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return data


# ---------------------------------------------------------------- meta
def lot_meta(world, family, module, w, d, h, cls, district, sockets=None, shop=False, **kw):
    """Meta for a lot or landmark. district is a list of district ids (Catalog.forWorld reads width, depth, facing,
    sockets and bounds from the mesh; the class, districts and the rest come from Worlds/<id>)."""
    s = {"front_left": sock((0, 0, 0)), "front_right": sock((w, 0, 0)), "back_left": sock((0, 0, d)), "roof_a": sock((w * 0.3, h, d * 0.6)), "roof_b": sock((w * 0.7, h, d * 0.5))}
    if sockets:
        s.update(sockets)
    m = {
        "family": family,
        "module": module,
        "world": world,
        "width": w,
        "depth": d,
        "height": round(h, 2),
        "height_class": cls,
        "orientation": "front",
        "facing": "-Z",
        "district": district,
        "shop": shop,
        "lod": "near",
        "pivot": "front corner on the lot's own left (min x), ground level, on the frontage line; facade faces -Z",
        "sockets": s,
    }
    m.update(kw)
    return m


def unit_meta(world, family, lod, band, **kw):
    m = {"family": family, "world": world, "unit": True, "lod": lod, "district": "any", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}, "band": band, "note": "scale [width, height, depth]"}
    m.update(kw)
    return m


# ---------------------------------------------------------------- scenery parts
def pad(b, w, d, sw="g_sand", h=0.4, x=0.0, z=0.0):
    """A low ground pad (x centred, z from z to z + d): a flat top and a thin skirt, so a lot reads as a place."""
    box(b, V(x, h / 2, z + d / 2), (w, h, d), {"side": "g_lo", "top": sw, "skip_bottom": True})


def rock(b, x, z, sx, sy, sz, rng, y=0.0, light=("r_2", "r_3", "r_4", "r_top"), subdiv=0, jitter=0.18):
    """A faceted boulder (an icosphere, flattened, lit from above-left)."""
    # sizes are full dimensions; sphere() takes radii, and the centre sits so the boulder rests on y
    sphere(b, V(x, y + sy * 0.45, z), (sx / 2, sy / 2, sz / 2), list(light), subdiv=subdiv, rng=rng, jitter=jitter, flatten=0.9)


def cactus(b, x, z, h, rng, arms=2, sw="p_mid", dark="p_dark"):
    """A saguaro: a 6-sided trunk with a rounded tip and up to two elbow arms."""
    r = max(0.8, h * 0.075)
    cyl(b, V(x, 0, z), h, r, 6, sw, r_top=r * 0.85, top_sw="p_light")
    cyl(b, V(x, h, z), r * 0.9, r * 0.85, 6, "p_light", r_top=r * 0.3, top=True)
    for k in range(arms):
        side = -1 if k == 0 else 1
        ay = h * (0.42 + 0.14 * rng.random())
        reach = r * 2.6
        box(b, V(x + side * reach / 2, ay, z), (reach, r * 0.95, r * 0.95), {"side": dark, "top": sw, "skip_bottom": True})
        up = h * (0.28 + 0.12 * rng.random())
        cyl(b, V(x + side * reach, ay - r * 0.4, z), up, r * 0.5, 6, dark, r_top=r * 0.42, top_sw="p_light")


def pine(b, x, z, h, rng, snow=False, tiers=3):
    """A stacked pine: a trunk and tiers of 6-sided frustums, optionally snow-capped."""
    r0 = h * 0.28
    cyl(b, V(x, 0, z), h * 0.22, h * 0.05, 5, "p_trunk", r_top=h * 0.045)
    ty = h * 0.18
    th = (h - ty) / tiers * 1.25
    for i in range(tiers):
        r = r0 * (1.0 - i * 0.27)
        sw = "p_dark" if i % 2 == 0 else "p_mid"
        cyl(b, V(x, ty + i * th * 0.78, z), th, r, 6, sw, r_top=r * 0.18, top_sw="m_white" if snow else "p_light", phase=0.3 * i)
        if snow and i < tiers - 1:
            cyl(b, V(x, ty + i * th * 0.78 + th * 0.62, z), th * 0.38, r * 0.5, 6, "m_white", r_top=r * 0.18, phase=0.3 * i)


def palm(b, x, z, h, rng):
    """A date palm: a leaning trunk of three segments and a crown of eight fronds (flat wedges)."""
    lean = (rng.random() - 0.5) * 2.2
    px, py = x, 0.0
    for i in range(3):
        nx = px + lean / 3
        cyl(b, V(px, py, z), h / 3, h * 0.045, 5, "p_trunk" if i % 2 == 0 else "p_trunk_dark", r_top=h * 0.04)
        px, py = nx, py + h / 3
    for k in range(8):
        a = 2 * math.pi * k / 8
        tip = V(px + math.cos(a) * h * 0.34, py - h * 0.1, z + math.sin(a) * h * 0.34)
        mid = V(px + math.cos(a) * h * 0.17, py + h * 0.07, z + math.sin(a) * h * 0.17)
        w = h * 0.06
        n = V(-math.sin(a), 0, math.cos(a)) * w
        b.face([V(px, py, z), mid + n, tip, mid - n], "p_mid" if k % 2 else "p_dark", V(0, 1, 0))
        b.face([V(px, py, z), mid - n, tip, mid + n], "p_mid" if k % 2 else "p_dark", V(0, -1, 0))


def plain_building(b, w, d, h, wall, trim, roof, door="w_door", windows=2, parapet=True, y0=0.0, x=0.0):
    """A flat-roofed block with a recessed door and `windows` windows on the front, a trim course and a parapet.
    Built centred on x; facade at z = 0 facing -Z."""
    hw = w / 2
    dw = min(5.0, w * 0.2)
    holes = [(x - dw / 2, x + dw / 2, y0, y0 + 8.0)]
    wins = []
    for i in range(windows):
        cx = x - hw + (i + 0.5) * w / windows
        if abs(cx - x) < dw * 0.9:
            cx += dw * 1.4 * (1 if cx >= x else -1)
        wins.append((cx - 2.0, cx + 2.0, y0 + 4.0, y0 + 8.8))
    holes += [h_ for h_ in wins if x - hw + 1 < h_[0] and h_[1] < x + hw - 1]
    # the facade is built in kitlib facade terms (u right as seen from the street = -x)
    wall_with_holes(b, -(x + hw), -(x - hw), y0, y0 + h, [(-hh[1], -hh[0], hh[2], hh[3]) for hh in holes], wall)
    # recessed door and window panes
    for hh in holes:
        pane = door if hh[3] - hh[2] > 7.9 and hh[2] == y0 else "w_glass"
        b.face([V(hh[0], hh[2], 0.6), V(hh[1], hh[2], 0.6), V(hh[1], hh[3], 0.6), V(hh[0], hh[3], 0.6)], pane, V(0, 0, -1))
        for s in (hh[0], hh[1]):
            b.face([V(s, hh[2], 0), V(s, hh[3], 0), V(s, hh[3], 0.6), V(s, hh[2], 0.6)], trim, V(1 if s == hh[0] else -1, 0, 0))
        b.face([V(hh[0], hh[3], 0), V(hh[1], hh[3], 0), V(hh[1], hh[3], 0.6), V(hh[0], hh[3], 0.6)], trim, V(0, -1, 0))
    box(b, V(x, y0 + h / 2, d / 2), (w, h, d), {"side": wall, "top": roof, "skip_front": True, "skip_bottom": True})
    box(b, V(x, y0 + h - 0.5, -0.15), (w + 0.4, 1.0, 0.7), {"side": trim, "top": trim, "skip_bottom": True, "skip_back": True})
    if parapet:
        box(b, V(x, y0 + h + 0.5, d / 2), (w + 0.6, 1.0, d + 0.6), {"side": trim, "top": roof, "skip_bottom": True})
