# Island kit: World portal gates, their lock set and the plot (speedway) gate (Lane 3, Task 4),
# in the kit's smooth faceted language: chamfered blocks, low side counts, no studs.
# CONCEPT STAGE: proportions and parts for review, not production.
#
# Portal gates (family gates/Portal). One template, three surfaces. Every gate mesh shares one
# origin: the field centre line on the ground (x 0 = field centre, y 0 = field plane, z 0 = ground
# under the pad), front faces -y (toward the fountain). The field is 20 x 30, floating 2.5 above the
# ground, so it spans x -10..10, z 2.5..32.5. Columns sit outside it (inner faces >= 10.5, outer
# faces <= 13.3, so two gates 28 apart keep a 1.4 gap); the crest band spans x -13.3..13.3,
# z 33.0..42.0. Per theme (Downtown, Dusty, Summit):
#   Gate<T>Columns  both column shafts with their capitals
#   Gate<T>Plinth   both column bases
#   Gate<T>Crest    the crest band, with a blank name face rectangle in meta
#   Gate<T>Crown    the optional emblem crown above the crest (an 8-stud emblem disc slot)
#   Gate<T>Inlay    thin inlay strips, one swatch (inlay_off); Luau relights them when open
# Lock set (family gates/Lock): GateChainLink, GateChainWrap, GatePadlockBody, GatePadlockShackle,
#   GateLockedPlaque, GateRequirementPlaque.
# Plot gate (family gates/Plot): PlotGatePillars, PlotGateBeam, PlotGateLamps, PlotGateAccent,
#   PlotGateChecker, PlotGateFlagpoles, PlotGateStartLine, PlotGateHedgeStub, PlotGateFenceStub.
#   Shared origin: the gate centre on the ground, front -y (toward the park).
# Meta points are Blender mesh-local (x right, y back, z up) from the mesh origin. Roblox mesh-local
# is (x, z, -y), and a MeshPart is centred on its bounds (subtract the bounds centre).

import math
import random

from mathutils import Matrix, Vector

from kit_plot import pbox
from kit_portal import at_y, ball, cbox, cyl, layered, oface, r3, rrect, sweep, torus
from kitlib import Builder, box, clump


# ---------------------------------------------------------------- helpers
def mark(b):
    return len(b.bm.verts)


def xform_since(b, n0, m):
    """Apply matrix m to every vertex added since mark n0 (each face owns its verts until export)."""
    b.bm.verts.ensure_lookup_table()
    for i in range(n0, len(b.bm.verts)):
        v = b.bm.verts[i]
        v.co = m @ v.co


def extrude_xz(b, pts2, y0, y1, front_sw, side_sw=None, back_sw=None):
    """A convex (x, z) outline extruded from y0 (front) to y1 (back)."""
    side_sw = side_sw or front_sw
    cx = sum(p[0] for p in pts2) / len(pts2)
    cz = sum(p[1] for p in pts2) / len(pts2)
    f = [Vector((x, y0, z)) for x, z in pts2]
    k = [Vector((x, y1, z)) for x, z in pts2]
    layered(b, [f, k], [side_sw], Vector((cx, (y0 + y1) / 2, cz)), cap_first=front_sw, cap_last=back_sw or side_sw)


def ellipsoid(b, c, size, sides, rings, sw):
    n0 = mark(b)
    ball(b, Vector((0, 0, 0)), 1.0, sides, rings, sw)
    xform_since(b, n0, Matrix.Translation(Vector(c)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))


def frustum(b, z0, z1, c, lo, hi, swatch, top_sw=None, bottom=False):
    """A rectangular frustum from (lo w, d) at z0 to (hi w, d) at z1, centred on c (x, y)."""
    cx, cy = c

    def rect(w, d, z):
        return [Vector((cx + sx * w / 2, cy + sy * d / 2, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    layered(b, [rect(lo[0], lo[1], z0), rect(hi[0], hi[1], z1)], [swatch], Vector((cx, cy, (z0 + z1) / 2)),
            cap_first=swatch if bottom else None, cap_last=top_sw or swatch)


def crystal(b, base, d, r, h, sides=6, sw=("ice", "ice_light")):
    """A faceted ice prism with a pointed tip, alternating facet tones."""
    base = Vector(base)
    d = Vector(d).normalized()
    ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    r0 = [base + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * r * 0.8 for k in range(sides)]
    r1 = [base + d * h * 0.7 + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * r for k in range(sides)]
    tip = base + d * h
    inside = base + d * h * 0.4
    for k in range(sides):
        k2 = (k + 1) % sides
        s = sw[k % 2]
        oface(b, [r0[k], r0[k2], r1[k2], r1[k]], s, inside)
        oface(b, [r1[k], r1[k2], tip], sw[(k + 1) % 2], inside)
    oface(b, r0, sw[0], inside)


def icicle(b, top, length, r, sides=4):
    top = Vector(top)
    ringp = [top + Vector((math.cos(2 * math.pi * k / sides + 0.4) * r, math.sin(2 * math.pi * k / sides + 0.4) * r, 0)) for k in range(sides)]
    tip = top - Vector((0, 0, length))
    inside = top - Vector((0, 0, length * 0.3))
    for k in range(sides):
        oface(b, [ringp[k], ringp[(k + 1) % sides], tip], "ice_light" if k % 2 else "ice", inside)
    oface(b, ringp, "ice_light", tip)


def thin_strip(b, x, z0, z1, w, front_y, sw, t=0.12):
    """A thin vertical strip proud of the plane y = front_y by t - 0.02."""
    cbox(b, Vector((x, front_y - t / 2 + 0.02, (z0 + z1) / 2)), (w, t, z1 - z0), sw, c=0.03)


# ---------------------------------------------------------------- portal gate template
FIELD_W, FIELD_H, FIELD_BOTTOM = 20.0, 30.0, 2.5
COL_X = 11.9                      # column axis
COL_W, COL_D = 2.4, 3.0           # shaft section (also the section at the chain wrap zones)
OUTER_MAX = 13.3                  # nothing goes past |x| 13.3 (neighbour gates are 28 apart)
PLINTH_TOP, SHAFT_TOP, CREST_Z0, CREST_TOP = 2.2, 30.6, 33.0, 42.0
FACE_W, FACE_Z0, FACE_Z1 = 26.0, 33.8, 41.0
CREST_W, CREST_D = 2 * OUTER_MAX, 3.2
EMBLEM_Z, EMBLEM_R = 45.6, 4.0
WRAP_LOW, WRAP_HIGH, WRAP_HALF = 7.0, 28.0, 2.15
CHAIN_EYE_Y = -2.55
GATE_SPACING = 28.0


def template_meta():
    cross_z = (WRAP_LOW + WRAP_HIGH) / 2
    return {
        "origin": "field centre line on the ground: x 0 field centre, y 0 field plane, z 0 ground; front -y",
        "field": {"width": FIELD_W, "height": FIELD_H, "bottom": FIELD_BOTTOM, "top": FIELD_BOTTOM + FIELD_H, "plane_y": 0.0},
        "columns_x": [-COL_X, COL_X], "column_section": [COL_W, COL_D],
        "shaft_inner_face_x": round(COL_X - COL_W / 2, 3), "plinth_inner_face_x": 10.5, "outer_face_x": OUTER_MAX,
        "gap_to_neighbour_at_28": round(GATE_SPACING - 2 * OUTER_MAX, 3),
        "chain_wrap_zones_z": [[WRAP_LOW - WRAP_HALF, WRAP_LOW + WRAP_HALF], [WRAP_HIGH - WRAP_HALF, WRAP_HIGH + WRAP_HALF]],
        "chain_wraps": {"left_low": [-COL_X, 0.0, WRAP_LOW], "left_high": [-COL_X, 0.0, WRAP_HIGH],
                        "right_low": [COL_X, 0.0, WRAP_LOW], "right_high": [COL_X, 0.0, WRAP_HIGH]},
        "chain_anchors": {"left_low": [-COL_X, CHAIN_EYE_Y, WRAP_LOW], "left_high": [-COL_X, CHAIN_EYE_Y, WRAP_HIGH],
                          "right_low": [COL_X, CHAIN_EYE_Y, WRAP_LOW], "right_high": [COL_X, CHAIN_EYE_Y, WRAP_HIGH]},
        "chain_cross": [0.0, CHAIN_EYE_Y, cross_z],
        "chain_note": "diagonals left_high->right_low and right_high->left_low cross at chain_cross (field centre); "
                      "offset one diagonal 0.35 toward -y so they pass; GateChainWrap origins at chain_wraps",
    }


def crest_meta(face_y, extra=None):
    m = {
        "name_face": {"centre": [0.0, round((FACE_Z0 + FACE_Z1) / 2, 3)], "size": [FACE_W, round(FACE_Z1 - FACE_Z0, 3)], "plane_y": round(face_y, 3)},
        "underside": CREST_Z0, "top": CREST_TOP, "width": CREST_W,
        "note": "name face: centre (x, z), size (w, h) on the plane y = plane_y, front -y; blank for SurfaceGui text",
    }
    if extra:
        m.update(extra)
    return m


def crown_meta(face_y, top, extra=None):
    m = {
        "emblem_slot": {"centre": [0.0, EMBLEM_Z], "radius": EMBLEM_R, "plane_y": round(face_y, 3), "shape": "disc"},
        "top": round(top, 3), "base": 41.0,
        "note": "optional: rises above the 42 crest line; drop it and the gate still reads (see README)",
    }
    if extra:
        m.update(extra)
    return m


def inlay_meta(strips):
    return {
        "swatch": "inlay_off (single swatch)",
        "recolour": "dark when locked as built; lit: TextureID '' + Color + Material Neon (Luau)",
        "strips": [{"x": r3([s[0]])[0], "z": [round(s[1], 3), round(s[2], 3)]} for s in strips],
        "note": "strips are listed bottom to top; split the mesh if a per-strip light sweep is wanted",
    }


def emblem_disc(b, y_front, rim_sw, face_sw, rim_r=EMBLEM_R + 0.45, depth=0.5):
    """A rimmed disc facing -y at EMBLEM_Z; returns the face plane y."""
    cyl(b, Vector((0, y_front + depth, EMBLEM_Z)), depth, rim_r, 24, rim_sw, axis=Vector((0, -1, 0)), top_sw=rim_sw)
    cyl(b, Vector((0, y_front, EMBLEM_Z)), 0.1, EMBLEM_R, 24, face_sw, axis=Vector((0, -1, 0)), top_sw=face_sw)
    return y_front - 0.1


# ---------------------------------------------------------------- Downtown: gold art deco
def downtown_columns(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        cbox(b, Vector((cx, 0, (PLINTH_TOP + SHAFT_TOP) / 2)), (COL_W, COL_D, SHAFT_TOP - PLINTH_TOP), "cream", c=0.12)
        # navy flute panels on the front, split by a gold belt course
        for z0, z1 in ((3.0, 15.6), (16.4, 29.8)):
            cbox(b, Vector((cx, -COL_D / 2, (z0 + z1) / 2)), (1.8, 0.2, z1 - z0), "navy", c=0.04)
        cbox(b, Vector((cx, 0, 16.0)), (2.6, 3.2, 0.8), "deco_gold", c=0.1)
        # gold corner beads up the front edges
        for e in (-1, 1):
            cbox(b, Vector((cx + e * (COL_W / 2 - 0.1), -COL_D / 2 + 0.08, (PLINTH_TOP + SHAFT_TOP) / 2)), (0.28, 0.28, SHAFT_TOP - PLINTH_TOP), "deco_gold", c=0.06)
        # ziggurat capital stepping out to the crest
        cbox(b, Vector((cx, 0, 30.9)), (2.6, 3.2, 0.6), "deco_gold", c=0.1)
        cbox(b, Vector((cx, 0, 31.7)), (2.8, 3.4, 1.0), "cream", c=0.12)
        cbox(b, Vector((cx, 0, 32.6)), (2.8, 3.6, 0.8), "navy", c=0.1, edge="deco_gold")
        # a small gold fan on the capital front
        for k in range(5):
            a0 = math.pi * k / 5
            a1 = math.pi * (k + 1) / 5
            r = 0.95 if k % 2 == 0 else 0.7
            pts = [(cx, 31.2), (cx + math.cos(a0) * r, 31.2 + math.sin(a0) * r), (cx + math.cos(a1) * r, 31.2 + math.sin(a1) * r)]
            extrude_xz(b, [(x, z) for x, z in reversed(pts)], -1.78, -1.68, "deco_gold" if k % 2 == 0 else "navy")
    return b, template_meta()


def downtown_plinth(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        cbox(b, Vector((cx, 0, 0.4)), (2.8, 3.8, 0.8), "navy", c=0.12, edge="deco_gold")
        cbox(b, Vector((cx, 0, 1.2)), (2.6, 3.5, 0.8), "cream", c=0.1)
        cbox(b, Vector((cx, 0, 1.9)), (2.5, 3.2, 0.6), "deco_gold", c=0.1)
    return b, {"top": PLINTH_TOP, "steps": [[2.8, 3.8, 0.8], [2.6, 3.5, 0.8], [2.5, 3.2, 0.6]], "outer_face_x": round(COL_X + 1.4, 3)}


def downtown_crest(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, (CREST_Z0 + 41.4) / 2)), (CREST_W, CREST_D, 41.4 - CREST_Z0), "cream", c=0.15)
    # navy name panel (gold lettering later)
    cbox(b, Vector((0, -CREST_D / 2, (FACE_Z0 + FACE_Z1) / 2)), (FACE_W + 0.2, 0.2, FACE_Z1 - FACE_Z0 + 0.2), "navy", c=0.05)
    face_y = -CREST_D / 2 - 0.1
    # the dark studded band under the name, edged in gold
    cbox(b, Vector((0, -CREST_D / 2 + 0.05, 33.32)), (CREST_W, 0.5, 0.64), "navy", c=0.08)
    cbox(b, Vector((0, -CREST_D / 2 - 0.05, 33.67)), (FACE_W + 0.2, 0.2, 0.1), "deco_gold", c=0.03)
    for k in range(17):
        x = -12.0 + 1.5 * k
        cbox(b, Vector((x, -CREST_D / 2 - 0.25, 33.32)), (0.42, 0.2, 0.42), "deco_gold", c=0.06)
    # gold top rail and a stepped (ziggurat) top edge
    cbox(b, Vector((0, 0, 41.25)), (CREST_W, CREST_D + 0.2, 0.3), "deco_gold", c=0.08)
    cbox(b, Vector((0, 0, 41.55)), (24.0, 3.0, 0.3), "cream", c=0.08)
    cbox(b, Vector((0, 0, 41.85)), (18.0, 2.8, 0.3), "deco_gold", c=0.08)
    return b, crest_meta(face_y, {"panel": "navy", "lettering_hint": "gold"})


def downtown_crown(name):
    b = Builder(name)
    # a sunburst fan of alternating long and short rays behind the emblem
    n = 13
    zc = 41.4
    for k in range(n):
        a0 = math.pi * k / n
        a1 = math.pi * (k + 1) / n
        r = 8.4 if k % 2 == 0 else 6.9
        pts = [(0.0, zc), (math.cos(a1) * r, zc + math.sin(a1) * r), (math.cos(a0) * r, zc + math.sin(a0) * r)]
        pts = list(reversed(pts))
        extrude_xz(b, pts, -0.3, 0.6, "deco_gold" if k % 2 == 0 else "cream", "deco_gold")
    # a stepped navy base the fan springs from
    cbox(b, Vector((0, 0.15, 41.7)), (9.0, 1.4, 0.6), "navy", c=0.1, edge="deco_gold")
    face_y = emblem_disc(b, -0.8, "deco_gold", "navy")
    return b, crown_meta(face_y, zc + 8.4)


# ---------------------------------------------------------------- Dusty Highway: red sandstone
DUSTY_BANDS = [  # (z0, z1, swatch, width) strata courses proud of the core, outside the wrap zones
    (2.2, 3.5, "sand_cream", 2.7), (10.0, 12.2, "sand_orange", 2.8), (13.2, 14.2, "sand_cream", 2.6),
    (16.0, 19.0, "sand_orange", 2.8), (20.2, 21.4, "sand_cream", 2.7), (22.6, 25.0, "sand_orange", 2.75),
]


def dusty_columns(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        cbox(b, Vector((cx, 0, (PLINTH_TOP + SHAFT_TOP) / 2)), (COL_W, COL_D, SHAFT_TOP - PLINTH_TOP), "sand_red", c=0.22, edge="sand_dark")
        for i, (z0, z1, sw, w) in enumerate(DUSTY_BANDS):
            jitter = 0.04 * (1 if (i + (s > 0)) % 2 else -1)
            cbox(b, Vector((cx + jitter, 0, (z0 + z1) / 2)), (w, COL_D + (w - COL_W), z1 - z0), sw, c=0.3)
        # mesa-like capital: a flared corbel, a cream overhang slab and a red cap
        frustum(b, SHAFT_TOP, 31.8, (cx, 0), (2.45, 3.05), (2.8, 3.7), "sand_orange")
        cbox(b, Vector((cx, 0, 32.1)), (2.8, 3.7, 0.6), "sand_cream", c=0.25)
        cbox(b, Vector((cx, 0, 32.7)), (2.7, 3.5, 0.6), "sand_red", c=0.22)
    return b, template_meta()


def dusty_plinth(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        cbox(b, Vector((cx, 0, 0.7)), (2.8, 3.8, 1.4), "sand_dark", c=0.4)
        cbox(b, Vector((cx, 0, 1.8)), (2.6, 3.4, 0.8), "sand_red", c=0.28)
        # a couple of fallen sandstone chunks at the outer-front corner
        cbox(b, Vector((cx + s * 1.0, -2.25, 0.3)), (0.8, 0.7, 0.6), "sand_orange", c=0.2)
    return b, {"top": PLINTH_TOP, "outer_face_x": round(COL_X + 1.4, 3)}


def dusty_crest(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, (CREST_Z0 + 41.4) / 2)), (CREST_W, CREST_D, 41.4 - CREST_Z0), "sand_red", c=0.35, edge="sand_dark")
    cbox(b, Vector((0, -CREST_D / 2, (FACE_Z0 + FACE_Z1) / 2)), (FACE_W + 0.1, 0.2, FACE_Z1 - FACE_Z0 + 0.1), "sand_cream", c=0.06)
    face_y = -CREST_D / 2 - 0.1
    # strata rails: an orange bottom course and a mesa-profile orange top course
    cbox(b, Vector((0, 0, 33.35)), (CREST_W, CREST_D + 0.3, 0.7), "sand_orange", c=0.28)
    extrude_xz(b, [(-OUTER_MAX, 41.0), (OUTER_MAX, 41.0), (OUTER_MAX - 0.5, 41.5), (OUTER_MAX - 1.4, 42.0), (-OUTER_MAX + 1.4, 42.0), (-OUTER_MAX + 0.5, 41.5)][::-1],
               -CREST_D / 2 - 0.2, CREST_D / 2 + 0.2, "sand_orange", "sand_orange")
    # a cream seam line between the bottom course and the band
    cbox(b, Vector((0, -CREST_D / 2 - 0.02, 33.78)), (CREST_W - 0.4, 0.2, 0.14), "sand_dark", c=0.04)
    return b, crest_meta(face_y, {"panel": "sand_cream", "lettering_hint": "sand_red or navy, two lines for DUSTY / HIGHWAY"})


def dusty_crown(name):
    b = Builder(name)
    # a layered mesa (butte) behind the emblem: three strata, flat top
    layers = [(41.2, 44.2, 8.2, 7.4, "sand_red"), (44.2, 47.2, 7.2, 6.4, "sand_orange"), (47.2, 49.6, 6.2, 5.0, "sand_cream"), (49.6, 50.6, 4.8, 4.2, "sand_red")]
    for z0, z1, h0, h1, sw in layers:
        extrude_xz(b, [(-h0, z0), (h0, z0), (h1, z1), (-h1, z1)][::-1], -0.3, 0.9, sw, sw)
    face_y = emblem_disc(b, -0.8, "sand_dark", "sand_cream")
    return b, crown_meta(face_y, 50.6)


# ---------------------------------------------------------------- Summit Pass: pale alpine
SUMMIT_COLLARS = [(12.4, 13.2), (21.4, 22.2)]


def summit_columns(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        # ashlar courses: stacked chamfered blocks give the joint lines
        z = PLINTH_TOP
        course = (SHAFT_TOP - PLINTH_TOP) / 14
        for i in range(14):
            cbox(b, Vector((cx, 0, z + course / 2)), (COL_W, COL_D, course), "alpine_stone", c=0.12, edge="alpine_shadow")
            z += course
        # timber collars, bolted
        for z0, z1 in SUMMIT_COLLARS:
            cbox(b, Vector((cx, 0, (z0 + z1) / 2)), (2.7, 3.3, z1 - z0), "plank", c=0.1, edge="bark_warm")
            for e in (-0.8, 0.8):
                cyl(b, Vector((cx + e, -1.65, (z0 + z1) / 2)), 0.08, 0.12, 6, "metal", axis=Vector((0, -1, 0)))
        # timber corbel and a stone cap under the crest
        cbox(b, Vector((cx, 0, 31.1)), (2.8, 3.6, 1.0), "plank", c=0.1, edge="bark_warm")
        cbox(b, Vector((cx, 0, 32.3)), (2.7, 3.4, 1.4), "alpine_stone", c=0.15, edge="alpine_shadow")
        # icicles under the corbel's outer half (clear of the upper chain wrap)
        for k, (dx, ln) in enumerate(((0.4, 0.5), (0.8, 0.8), (1.15, 0.45))):
            icicle(b, Vector((cx + s * dx, -1.65, 30.6)), ln, 0.13)
    return b, template_meta()


def summit_plinth(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        cbox(b, Vector((cx, 0, 0.7)), (2.8, 3.8, 1.4), "alpine_shadow", c=0.35)
        cbox(b, Vector((cx, 0, 1.8)), (2.6, 3.4, 0.8), "alpine_stone", c=0.2, edge="alpine_shadow")
        # snow drifts on the plinth step and a small ice cluster at the outer-front corner
        ellipsoid(b, (cx - s * 0.5, -1.55, 2.2), (0.9, 0.5, 0.28), 8, 4, "snow")
        ellipsoid(b, (cx + s * 1.0, -1.7, 1.45), (0.7, 0.45, 0.25), 8, 4, "snow")
        base = Vector((cx + s * 1.0, -1.45, 2.15))
        crystal(b, base, (s * 0.25, -0.2, 1), 0.32, 2.5)
        crystal(b, base + Vector((s * 0.35, 0.2, -0.1)), (s * 0.7, 0.1, 1), 0.24, 1.6)
        crystal(b, base + Vector((-s * 0.3, -0.25, -0.1)), (-s * 0.2, -0.6, 1), 0.2, 1.3)
    return b, {"top": PLINTH_TOP, "outer_face_x": round(COL_X + 1.4, 3), "ice_cluster_top": 4.65}


def summit_crest(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, (CREST_Z0 + 41.4) / 2)), (CREST_W, CREST_D, 41.4 - CREST_Z0), "alpine_stone", c=0.2, edge="alpine_shadow")
    cbox(b, Vector((0, -CREST_D / 2, (FACE_Z0 + FACE_Z1) / 2)), (FACE_W + 0.1, 0.2, FACE_Z1 - FACE_Z0 + 0.1), "birch_white", c=0.05)
    face_y = -CREST_D / 2 - 0.1
    # timber rails top and bottom
    cbox(b, Vector((0, 0, 33.35)), (CREST_W, CREST_D + 0.3, 0.7), "plank", c=0.12, edge="bark_warm")
    cbox(b, Vector((0, 0, 41.2)), (CREST_W, CREST_D + 0.3, 0.4), "plank", c=0.1, edge="bark_warm")
    # snow cap with drip lobes over the front edge
    cbox(b, Vector((0, 0, 41.65)), (CREST_W - 0.2, CREST_D + 0.2, 0.5), "snow", c=0.2)
    for k in range(7):
        x = -11.4 + k * 3.8
        ellipsoid(b, (x, -CREST_D / 2 - 0.15, 41.45), (1.5 + 0.2 * (k % 2), 0.42, 0.42), 8, 4, "snow")
    # icicle groups under the bottom rail, in front of the field's top edge
    rng = random.Random(41)
    for g in range(8):
        x0 = -10.5 + g * 3.0
        for dx, ln in ((-0.4, 0.8), (0.0, 1.4), (0.4, 1.0)):
            icicle(b, Vector((x0 + dx, -CREST_D / 2 - 0.1, 33.0)), ln * rng.uniform(0.85, 1.15), 0.14)
    return b, crest_meta(face_y, {"panel": "birch_white", "lettering_hint": "navy or timber brown", "icicles_lowest_z": 31.4})


def summit_crown(name):
    b = Builder(name)
    ellipsoid(b, (0, 0.2, 41.5), (6.0, 1.4, 1.1), 10, 4, "snow")
    # an ice crystal cluster fanning out behind the emblem
    for dx, lean, r, h in ((0.0, 0.0, 1.2, 10.0), (-3.2, -0.35, 1.0, 8.0), (3.2, 0.35, 1.0, 8.2), (-5.4, -0.75, 0.8, 5.6), (5.4, 0.75, 0.8, 5.4), (-1.6, -0.12, 0.7, 6.4), (1.8, 0.15, 0.7, 6.0)):
        crystal(b, Vector((dx * 0.6, 0.35, 41.6)), (lean, 0.05, 1), r, h)
    face_y = emblem_disc(b, -0.8, "plank", "alpine_stone")
    return b, crown_meta(face_y, 51.6)


# ---------------------------------------------------------------- inlays
def inlay_mesh(name, strips_by_front, crest_front_y, studs=False):
    """strips_by_front: list of (x, z0, z1, width, front_y). Plus a crest line (or a row of
    marquee studs for Downtown) along the crest's bottom course, under the name face."""
    b = Builder(name)
    strips = []
    for x, z0, z1, w, fy in strips_by_front:
        thin_strip(b, x, z0, z1, w, fy, "inlay_off")
        strips.append((x, z0, z1))
    if studs:
        for k in range(17):
            cbox(b, Vector((-12.0 + 1.5 * k, crest_front_y - 0.08, 33.32)), (0.42, 0.2, 0.42), "inlay_off", c=0.06)
    else:
        cbox(b, Vector((0, crest_front_y - 0.04, 33.35)), (22.0, 0.12, 0.3), "inlay_off", c=0.03)
    strips.append((0.0, 33.2, 33.5))
    strips.sort(key=lambda s: s[1])
    m = inlay_meta(strips)
    m["crest_row"] = "17 marquee studs" if studs else "one line"
    return b, m


def downtown_inlay(name):
    st = []
    for s in (-1, 1):
        for e in (-0.45, 0.45):
            for z0, z1 in ((3.3, 15.3), (16.7, 29.5)):
                st.append((s * COL_X + e, z0, z1, 0.6, -COL_D / 2 - 0.1))
    return inlay_mesh(name, st, -1.8, studs=True)


def dusty_inlay(name):
    st = []
    for s in (-1, 1):
        z = 3.5
        for z0, z1, sw, w in DUSTY_BANDS[1:] + [(SHAFT_TOP - 0.3, SHAFT_TOP, None, COL_W)]:
            # core run below this band, then the band itself (its front sits further forward)
            if z0 > z + 0.05:
                st.append((s * COL_X, z + 0.15, z0 - 0.15, 0.8, -COL_D / 2))
            if sw:
                st.append((s * COL_X, z0 + 0.25, z1 - 0.25, 0.8, -(COL_D + (w - COL_W)) / 2))
            z = z1
    return inlay_mesh(name, st, -1.75)


def summit_inlay(name):
    st = []
    for s in (-1, 1):
        for z0, z1 in ((2.7, 12.2), (13.4, 21.2), (22.4, 30.2)):
            st.append((s * COL_X, z0, z1, 0.6, -COL_D / 2))
        for z0, z1 in SUMMIT_COLLARS:
            st.append((s * COL_X, z0 + 0.2, z1 - 0.2, 0.6, -1.65))
    return inlay_mesh(name, st, -1.75)


# ---------------------------------------------------------------- lock set
GL_LEN, GL_W, GL_WIRE = 2.2, 1.3, 0.32


def oval_link(b, c, t, w, length, width, wire, sides, swatch, pts=8):
    r = wire / 2
    hx, hy = length / 2 - r, width / 2 - r
    ang = [2 * math.pi * k / pts for k in range(pts)]
    path = []
    for a in ang:
        # a stadium-like oval: flatten the long sides a little
        ca, sa = math.cos(a), math.sin(a)
        path.append(Vector(c) + t * (hx * math.copysign(abs(ca) ** 0.8, ca)) + w * (hy * math.copysign(abs(sa) ** 1.2, sa)))
    sweep(b, path, r, sides, swatch, closed=True, phase=math.pi / sides)


def gate_chain_link(name):
    b = Builder(name)
    oval_link(b, Vector((0, 0, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), GL_LEN, GL_W, GL_WIRE, 6, "chain_iron")
    pitch = GL_LEN - 2 * GL_WIRE
    return b, {"length": GL_LEN, "width": GL_W, "wire": GL_WIRE, "pitch": round(pitch, 3), "origin": "link centre",
               "long_axis": "x", "plane": "xy (alternate links turn 90 degrees about x)", "swatch": "chain_iron (warm dark grey)"}


def rr_path(a, bb, r, n=480):
    """A dense closed polyline round a rounded rectangle (half sizes a, bb), CCW from the front centre."""
    pts = []
    # corner centres
    cs = [(a - r, bb - r), (-(a - r), bb - r), (-(a - r), -(bb - r)), (a - r, -(bb - r))]
    seg = []
    for i, (cx, cy) in enumerate(cs):
        for k in range(13):
            ang = math.radians(90 * i + 90 * k / 12)
            seg.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    # resample by arc length, starting at the front centre (0, -bb) heading +x
    raw = [Vector((x, y, 0)) for x, y in seg]
    start = Vector((0, -bb, 0))
    # rotate the list so it begins after the front centre
    idx = min(range(len(raw)), key=lambda i: (raw[i] - start).length if raw[i].y < 0 and raw[i].x >= 0 else 1e9)
    raw = [start] + raw[idx:] + raw[:idx] + [start]
    lens = [0.0]
    for i in range(1, len(raw)):
        lens.append(lens[-1] + (raw[i] - raw[i - 1]).length)
    total = lens[-1]
    for k in range(n):
        s = total * k / n
        j = max(i for i in range(len(lens)) if lens[i] <= s)
        j = min(j, len(raw) - 2)
        f = (s - lens[j]) / max(1e-9, lens[j + 1] - lens[j])
        pts.append(raw[j].lerp(raw[j + 1], f))
    return pts, total


def gate_chain_wrap(name):
    b = Builder(name)
    hx, hy = COL_W / 2, COL_D / 2
    dense, per = rr_path(hx, hy, 0.2)
    turns, per_turn = 2, 10
    n = turns * per_turn
    rise = 1.55
    for i in range(n):
        f = (i + 0.5) / per_turn
        idx = int((f % 1.0) * len(dense)) % len(dense)
        p = dense[idx]
        q = dense[(idx + 4) % len(dense)]
        t2 = (q - p).normalized()
        out = Vector((t2.y, -t2.x, 0))  # CCW path: outward normal
        z = -rise * turns / 2 + rise * f
        t = (t2 * per / per_turn + Vector((0, 0, rise / per_turn))).normalized()
        flat = i % 2 == 0
        off = 0.27 if flat else GL_W / 2 + 0.02
        c = p + out * off + Vector((0, 0, z))
        w = t.cross(out).normalized() if flat else out
        oval_link(b, c, t, w, GL_LEN * 0.95, GL_W * 0.95, GL_WIRE, 4, "chain_iron", pts=8)
    # the joining ring at the front centre, where the X chain hooks on
    eye = Vector((0, CHAIN_EYE_Y, 0))
    cbox(b, Vector((0, -hy - 0.4, 0)), (0.7, 0.6, 0.9), "chain_iron", c=0.12)
    torus(b, eye, Vector((0, 1, 0)), Vector((0, 0, 1)), 0.55, 0.17, 10, 5, "chain_iron")
    return b, {
        "origin": "column axis at the wrap's mid height", "fits_section": [COL_W, COL_D],
        "turns": turns, "links": n, "height": round(rise * turns + GL_W, 3),
        "eye": [0.0, CHAIN_EYE_Y, 0.0], "eye_note": "front-centre joining ring; the X chain's end link hooks here",
        "symmetric": "use the same mesh on both columns (rotate, never mirror)",
    }


PB_W, PB_H, PB_T = 7.0, 6.0, 2.4
PS_X, PS_R, PS_INSERT, PS_RISE = 2.3, 0.42, 0.6, 3.0


def gate_padlock_body(name):
    b = Builder(name)
    hy = PB_T / 2

    def prof(i):
        return rrect(PB_W - 2 * i, PB_H - 2 * i, max(0.2, 1.0 - i), max(0.3, 2.2 - i), seg=4)

    layers = [at_y(prof(0.3), hy), at_y(prof(0), hy - 0.3), at_y(prof(0), -hy + 0.4), at_y(prof(0.12), -hy + 0.14), at_y(prof(0.38), -hy)]
    layered(b, layers, ["steel", "steel", "brass", "steel"], Vector((0, 0, 0)), cap_first="steel", cap_last="steel")
    front = -hy
    ez = 0.5
    # emblem plate: a brass rim round a blank cream face (the World emblem goes here)
    cyl(b, Vector((0, front + 0.05, ez)), 0.3, 2.4, 24, "brass", axis=Vector((0, -1, 0)), top_sw="brass")
    cyl(b, Vector((0, front - 0.25, ez)), 0.08, 2.05, 24, "cream", axis=Vector((0, -1, 0)), top_sw="cream")
    emblem_y = front - 0.33
    # keyhole: a brass escutcheon with a dark keyhole, the strongest dark spot
    kz = -2.1
    cyl(b, Vector((0, front + 0.02, kz)), 0.14, 0.75, 12, "brass", axis=Vector((0, -1, 0)), top_sw="brass")
    cyl(b, Vector((0, front - 0.12, kz + 0.12)), 0.04, 0.3, 10, "black", axis=Vector((0, -1, 0)), top_sw="black")
    extrude_xz(b, [(-0.12, kz + 0.05), (0.12, kz + 0.05), (0.2, kz - 0.5), (-0.2, kz - 0.5)][::-1], front - 0.16, front - 0.1, "black")
    # socket collars on the top
    top = PB_H / 2
    for x in (-PS_X, PS_X):
        cyl(b, Vector((x, 0, top - 0.25)), 0.4, 0.62, 10, "steel", top_sw="black")
    # two eyelets under the body for the LOCKED plaque
    eyes = []
    for x in (-2.0, 2.0):
        zc = -0.8 - math.sqrt(2.2 ** 2 - (abs(x) - 1.3) ** 2) - 0.22
        torus(b, Vector((x, 0, zc)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.36, 0.1, 10, 5, "steel")
        eyes.append([x, 0.0, round(zc, 3)])
    return b, {
        "width": PB_W, "height": PB_H, "thickness": PB_T, "origin": "body centre",
        "shackle_left": [-PS_X, top], "shackle_right": [PS_X, top], "shackle_seat": [-PS_X, round(top - PS_INSERT, 3)],
        "emblem_face": {"centre": [0.0, ez], "radius": 2.05, "plane_y": round(emblem_y, 3)},
        "keyhole_centre": [0.0, kz], "plaque_eyes": eyes,
        "assembly": {"hang_from": "chain_cross", "body_centre_below_cross": round(PS_INSERT - PS_INSERT + PB_H / 2 + 1.5, 3),
                     "note": "put the shackle arch over the chain crossing: body top 1.5 below the crossing, so the body centre is 4.5 below it"},
        "note": "points are (x, z) at y 0 unless (x, y, z); put the GatePadlockShackle origin at shackle_seat",
    }


def gate_padlock_shackle(name):
    b = Builder(name)
    gap = 2 * PS_X
    top_outer = PS_INSERT + PS_RISE
    rc = gap / 2
    zc = top_outer - PS_R - rc
    path = [Vector((0, 0, 0))]
    for k in range(11):
        a = math.pi - math.pi * k / 10
        path.append(Vector((rc + math.cos(a) * rc, 0, zc + math.sin(a) * rc)))
    right_bottom = 0.3
    path.append(Vector((gap, 0, right_bottom)))
    sweep(b, path, PS_R, 8, "steel", phase=math.pi / 8)
    return b, {
        "origin": "bottom of the left leg (hinge axis z)", "leg_gap": gap, "section": 2 * PS_R,
        "inner_width": round(gap - 2 * PS_R, 3), "height": round(top_outer, 3), "rise_above_body": PS_RISE,
        "inner_top_above_body": round(PS_RISE - 2 * PS_R, 3), "insert": PS_INSERT, "right_leg_bottom": right_bottom,
        "lift_to_open": round(PS_INSERT - right_bottom + 0.05, 3),
    }


LP_W, LP_H, LP_T = 9.0, 4.0, 0.5


def gate_locked_plaque(name):
    b = Builder(name)
    hy = LP_T / 2

    def prof(i):
        return rrect(LP_W - 2 * i, LP_H - 2 * i, max(0.15, 1.3 - i), max(0.15, 1.3 - i), seg=3)

    layers = [at_y(prof(0.1), hy), at_y(prof(0), hy - 0.1), at_y(prof(0), -hy + 0.12), at_y(prof(0.1), -hy)]
    layered(b, layers, ["navy", "navy", "navy"], Vector((0, 0, 0)), cap_first="navy", cap_last="navy")
    fw, fh = LP_W - 0.8, LP_H - 0.8
    face = rrect(fw, fh, 0.95, 0.95, seg=3)
    layered(b, [at_y(face, -hy + 0.02), at_y(face, -hy - 0.06)], ["cream"], Vector((0, 0, 0)), cap_last="cream")
    rings = []
    for x in (-2.0, 2.0):
        zc = LP_H / 2 + 0.22
        torus(b, Vector((x, 0, zc)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.36, 0.1, 10, 5, "steel")
        rings.append([x, 0.0, round(zc, 3)])
    return b, {
        "board": [LP_W, LP_H, LP_T], "origin": "board centre",
        "face": {"centre": [0.0, 0.0], "size": [round(fw, 3), round(fh, 3)], "corner_radius": 0.95, "plane_y": round(-hy - 0.06, 3)},
        "hang_rings": rings, "hang_note": "rings interlock with GatePadlockBody plaque_eyes: put each ring centre 0.5 below its eye",
        "cap_height_hint": "LOCKED at 2.5 cap fits the face",
    }


RQ_W, RQ_H, RQ_T, RQ_TILT = 8.6, 5.6, 0.4, 35.0


def gate_requirement_plaque(name):
    b = Builder(name)
    cbox(b, Vector((0, 0.2, 0.2)), (3.8, 3.2, 0.4), "stone_light", c=0.12, edge="rock")
    cbox(b, Vector((0, 0.3, 1.45)), (1.7, 1.3, 2.1), "cream", c=0.15, edge="stone_light")
    cbox(b, Vector((0, 0.3, 0.55)), (2.1, 1.7, 0.3), "navy", c=0.08)
    # the angled board, built upright then tilted back
    zc = 2.6
    theta = math.radians(90.0 - RQ_TILT)
    n0 = mark(b)
    cbox(b, Vector((0, 0, 0)), (RQ_W, RQ_T, RQ_H), "navy", c=0.12)
    fw, fh = RQ_W - 0.6, RQ_H - 0.6
    cbox(b, Vector((0, -RQ_T / 2 - 0.03, 0)), (fw, 0.08, fh), "sign_board", c=0.03)
    m = Matrix.Translation(Vector((0, 0, zc))) @ Matrix.Rotation(-theta, 4, "X")
    xform_since(b, n0, m)
    normal = (Matrix.Rotation(-theta, 3, "X") @ Vector((0, -1, 0))).normalized()
    up = (Matrix.Rotation(-theta, 3, "X") @ Vector((0, 0, 1))).normalized()
    face_c = m @ Vector((0, -RQ_T / 2 - 0.07, 0))
    lo_edge = m @ Vector((0, 0, -RQ_H / 2))
    hi_edge = m @ Vector((0, 0, RQ_H / 2))
    return b, {
        "origin": "ground centre, front -y",
        "face": {"centre": r3(face_c), "size": [round(fw, 3), round(fh, 3)], "normal": r3(normal), "up": r3(up),
                 "tilt_from_horizontal_deg": RQ_TILT},
        "peek_reserved": {"centre_uv": [2.5, -1.55], "size": [2.4, 1.3],
                          "note": "face-local (u along +x, v along 'up' from the face centre); keep clear for the Peek button (UI, not modelled)"},
        "board_low_edge_z": round(lo_edge.z, 3), "board_high_edge_z": round(hi_edge.z, 3),
        "height": round(hi_edge.z + RQ_T / 2, 2),
        "note": "PREVIEW values go on the face; the board is angled so a 5-stud avatar reads it from 6-12 studs",
    }


# ---------------------------------------------------------------- plot (speedway) gate
PG_OPEN_HALF, PG_BEAM_Z0, PG_BEAM_Z1 = 7.0, 10.2, 12.9
PG_BASE_X, PG_BASE_H = 8.8, 2.5
PG_PIL_X, PG_PIL_W = 8.3, 2.2
PG_CAP_X = 7.9
PG_FLAG_X, PG_FLAG_Y = 9.95, 0.95


def plotgate_pillars(name):
    b = Builder(name)
    for s in (-1, 1):
        bx = s * PG_BASE_X
        cbox(b, Vector((bx, 0, 0.3)), (3.6, 3.6, 0.6), "rock", c=0.12, edge="rock_dark")
        # two courses of offset stone blocks
        cbox(b, Vector((bx - s * 0.75, 0, 1.025)), (1.8, 3.3, 0.85), "stone_light", c=0.1, edge="birch_grey")
        cbox(b, Vector((bx + s * 0.9, 0, 1.025)), (1.5, 3.3, 0.85), "birch_grey", c=0.1, edge="stone_light")
        cbox(b, Vector((bx, -0.8, 1.875)), (3.3, 1.7, 0.85), "birch_grey", c=0.1, edge="stone_light")
        cbox(b, Vector((bx, 0.85, 1.875)), (3.3, 1.6, 0.85), "stone_light", c=0.1, edge="birch_grey")
        cbox(b, Vector((bx, 0, 2.4)), (3.5, 3.5, 0.2), "stone_light", c=0.06)
        # the slim upper pillar
        cbox(b, Vector((s * PG_PIL_X, 0, (PG_BASE_H + PG_BEAM_Z0) / 2)), (PG_PIL_W, PG_PIL_W, PG_BEAM_Z0 - PG_BASE_H), "cart_white", c=0.14)
    return b, {
        "opening": {"x": [-PG_OPEN_HALF, PG_OPEN_HALF], "z": [0.0, PG_BEAM_Z0 - 0.1], "above_base_x": [-(PG_PIL_X - PG_PIL_W / 2), PG_PIL_X - PG_PIL_W / 2]},
        "stone_base": {"x": [7.0, 10.6], "size": [3.6, 3.6, PG_BASE_H]}, "pillar": {"x": PG_PIL_X, "size": [PG_PIL_W, PG_PIL_W]},
        "hedge_joint_x": 10.6, "colliders": "two boxes: stone base 3.6 x 3.6 x 2.5, pillar 2.2 x 2.2 to 10.2",
    }


def plotgate_beam(name):
    b = Builder(name)
    zc = (PG_BEAM_Z0 + PG_BEAM_Z1) / 2
    cbox(b, Vector((0, 0, zc)), (12.4, 1.2, PG_BEAM_Z1 - PG_BEAM_Z0), "cart_white", c=0.1)
    badges = []
    for s in (-1, 1):
        cyl(b, Vector((s * PG_CAP_X, -0.7 + 0.02, zc)), 0.1, 0.95, 16, "cart_white", axis=Vector((0, -1, 0)), top_sw="cart_white")
        badges.append({"centre": [s * PG_CAP_X, round(zc, 3)], "radius": 0.95, "plane_y": -0.78})
        cyl(b, Vector((s * PG_CAP_X, 0.7 - 0.02, zc)), 0.1, 0.95, 16, "cart_white", axis=Vector((0, 1, 0)), top_sw="cart_white")
    return b, {
        "beam": {"x": [-6.2, 6.2], "z": [PG_BEAM_Z0, PG_BEAM_Z1], "depth": 1.2},
        "name_face": {"centre": [0.0, round(zc, 3)], "size": [12.0, 2.5], "plane_y": -0.6,
                      "rows": "owner name / YOUR SPEEDWAY / car count + Income Tier PREVIEW"},
        "name_face_back": {"centre": [0.0, round(zc, 3)], "size": [12.0, 2.5], "plane_y": 0.6},
        "number_badges": badges, "number_badges_back_plane_y": 0.78, "top": PG_BEAM_Z1 + 0.1,
    }


def plotgate_accent(name):
    b = Builder(name)
    zc = (PG_BEAM_Z0 + PG_BEAM_Z1) / 2
    for s in (-1, 1):
        cbox(b, Vector((s * PG_CAP_X, 0, zc)), (3.4, 1.4, 2.9), "accent_neutral", c=0.14)
        cbox(b, Vector((s * PG_PIL_X, 0, 2.8)), (2.5, 2.5, 0.6), "accent_neutral", c=0.1)
        cbox(b, Vector((s * PG_PIL_X, 0, 9.75)), (2.5, 2.5, 0.7), "accent_neutral", c=0.1)
    return b, {
        "swatch": "accent_neutral (single swatch)",
        "recolour": "TextureID '' + Color = the plot accent (red, orange, yellow, green, blue, purple)",
        "parts": "beam end caps (carry the number badges), pillar collars at 2.5-3.1 and 9.4-10.1",
    }


def plotgate_lamps(name):
    b = Builder(name)
    lights = []
    for s in (-1, 1):
        x = s * PG_PIL_X
        fy = -PG_PIL_W / 2
        cbox(b, Vector((x, fy - 0.05, 8.75)), (0.6, 0.12, 0.9), "metal", c=0.03)
        sweep(b, [Vector((x, fy - 0.08, 9.0)), Vector((x, fy - 0.75, 9.0)), Vector((x, fy - 0.85, 8.85))], 0.07, 5, "metal")
        ly = fy - 0.85
        cyl(b, Vector((x, ly, 8.6)), 0.25, 0.1, 6, "metal")
        cyl(b, Vector((x, ly, 8.45)), 0.18, 0.55, 6, "metal", r_top=0.1)
        cyl(b, Vector((x, ly, 7.55)), 0.9, 0.42, 6, "lamp_glass", top=False)
        cyl(b, Vector((x, ly, 7.4)), 0.15, 0.48, 6, "metal", bottom=True)
        lights.append([x, round(ly, 3), 8.0])
    return b, {"light_points": lights, "note": "lantern sconces on the pillar fronts; PointLight at each light point"}


def plotgate_checker(name):
    b = Builder(name)
    sq, cols, rows = 0.4, 2, 8
    z0 = 3.4
    for s in (-1, 1):
        x0 = s * PG_PIL_X - sq * cols / 2
        fy = -PG_PIL_W / 2
        cbox(b, Vector((s * PG_PIL_X, fy - 0.03, z0 + sq * rows / 2)), (sq * cols + 0.1, 0.07, sq * rows + 0.1), "black", c=0.02)
        for r in range(rows):
            for k in range(cols):
                if (r + k) % 2:
                    continue
                xa, za = x0 + k * sq, z0 + r * sq
                oface(b, [Vector((xa, fy - 0.075, za)), Vector((xa + sq, fy - 0.075, za)), Vector((xa + sq, fy - 0.075, za + sq)), Vector((xa, fy - 0.075, za + sq))], "cart_white", Vector((xa, 0, za)))
    return b, {"strips": [[-PG_PIL_X, z0, z0 + sq * rows], [PG_PIL_X, z0, z0 + sq * rows]], "square": sq, "note": "vertical checker on each pillar front, under the lantern"}


def plotgate_flagpoles(name):
    b = Builder(name)
    flags = []
    for s in (-1, 1):
        x = s * PG_FLAG_X
        cyl(b, Vector((x, PG_FLAG_Y, PG_BASE_H)), 0.3, 0.26, 8, "metal", r_top=0.17)
        cyl(b, Vector((x, PG_FLAG_Y, PG_BASE_H + 0.3)), 12.6 - PG_BASE_H - 0.3, 0.12, 8, "cart_white", r_top=0.09)
        ball(b, Vector((x, PG_FLAG_Y, 12.76)), 0.17, 8, 4, "brass")
        flags.append({"top": [x, PG_FLAG_Y, 12.4], "bottom": [x, PG_FLAG_Y, 10.6], "side": "+x" if s > 0 else "-x"})
    return b, {"flags": flags, "height": 12.93, "note": "flags fly outward, away from the opening; cloth is a Luau Beam"}


def plotgate_start_line(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, 0.025)), (14.0, 1.9, 0.05), "cart_white", c=0.01)
    sq_w, sq_d = 1.0, 0.75
    for r in range(2):
        for k in range(14):
            if (r + k) % 2:
                continue
            xa, ya = -7.0 + k * sq_w, -sq_d + r * sq_d
            oface(b, [Vector((xa, ya, 0.055)), Vector((xa + sq_w, ya, 0.055)), Vector((xa + sq_w, ya + sq_d, 0.055)), Vector((xa, ya + sq_d, 0.055))], "black", Vector((xa, ya, 0)))
    return b, {"size": [14.0, 1.9], "top": 0.055, "note": "lies on the court between the pillars at y 0; raise 0.02 above the court surface"}


def plotgate_hedge_stub(name):
    rng = random.Random(4417)
    b = Builder(name)
    length, height, depth = 3.0, 2.6, 1.8
    for i in range(2):
        x = length * (i + 0.5) / 2
        clump(b, Vector((x, 0, height * 0.55)), Vector((length / 2 * 0.85, depth * 0.62, height * 0.6)), rng, ["hedge_dark", "hedge", "hedge", "leaf_mid"], flatten=1.0, subdiv=2)
    box(b, Vector((length / 2, 0, height * 0.35)), Vector((length * 0.96, depth * 0.85, height * 0.7)), ["hedge_dark", "hedge"])
    return b, {"length": length, "height": height, "origin": "inner end (against the stone base), extends +x", "matches": "HedgeStraight (2.6 tall)"}


def plotgate_fence_stub(name):
    b = Builder(name)
    length = 3.0
    cyl(b, Vector((length - 0.2, 0, -0.8)), 3.3, 0.2, 6, "cart_white")
    ball(b, Vector((length - 0.2, 0, 2.6)), 0.22, 6, 3, "cart_white")
    for z in (0.9, 1.95):
        box(b, Vector((length / 2, 0, z)), Vector((length, 0.14, 0.3)), "cart_white")
    for i in range(3):
        box(b, Vector((0.5 + i * 0.9, 0.1, 1.1)), Vector((0.32, 0.1, 2.0)), "cart_white")
    return b, {"length": length, "height": 2.8, "origin": "inner end (rails tuck into the stone base), extends +x", "matches": "FenceSegment"}


# ---------------------------------------------------------------- build
THEMES = [
    ("Downtown", downtown_columns, downtown_plinth, downtown_crest, downtown_crown, downtown_inlay),
    ("Dusty", dusty_columns, dusty_plinth, dusty_crest, dusty_crown, dusty_inlay),
    ("Summit", summit_columns, summit_plinth, summit_crest, summit_crown, summit_inlay),
]

LOCK = [
    ("GateChainLink", gate_chain_link), ("GateChainWrap", gate_chain_wrap), ("GatePadlockBody", gate_padlock_body),
    ("GatePadlockShackle", gate_padlock_shackle), ("GateLockedPlaque", gate_locked_plaque), ("GateRequirementPlaque", gate_requirement_plaque),
]

PLOT = [
    ("PlotGatePillars", plotgate_pillars), ("PlotGateBeam", plotgate_beam), ("PlotGateLamps", plotgate_lamps),
    ("PlotGateAccent", plotgate_accent), ("PlotGateChecker", plotgate_checker), ("PlotGateFlagpoles", plotgate_flagpoles),
    ("PlotGateStartLine", plotgate_start_line), ("PlotGateHedgeStub", plotgate_hedge_stub), ("PlotGateFenceStub", plotgate_fence_stub),
]


def all_pieces():
    """(name, builder function, family) for every mesh, in build order."""
    out = []
    for theme, *fns in THEMES:
        for part, fn in zip(("Columns", "Plinth", "Crest", "Crown", "Inlay"), fns):
            out.append(("Gate" + theme + part, fn, "gates/Portal"))
    out += [(n, fn, "gates/Lock") for n, fn in LOCK]
    out += [(n, fn, "gates/Plot") for n, fn in PLOT]
    return out


def build_all(emit):
    for name, fn, family in all_pieces():
        emit(*fn(name), family)
