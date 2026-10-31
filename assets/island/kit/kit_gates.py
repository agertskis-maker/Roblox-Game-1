# Island kit: World portal gates, their lock set and the plot (speedway) gate (Lane 3, Task 4),
# in the kit's smooth faceted language: chamfered blocks, low side counts, no studs.
# PRODUCTION pass (after the concept review, concepts/concept-review.md, and the lead's decisions).
#
# Portal gates (family gates/Portal). One template, three surfaces. Gates stand 34 apart. Every gate
# mesh shares one origin: the field centre line on the ground (x 0 = field centre, y 0 = field plane,
# z 0 = ground under the pad), front faces -y. The field is 20 x 30, floating 2.5 above the ground
# (x -10..10, z 2.5..32.5). Columns are 4 x 4 on axes x +-13 (inner faces >= 10.6); plinths and
# capitals step out to |x| 15.4 and y +-2.5, so neighbours keep a 3.2 gap. The crest spans
# |x| <= 15.0 (0.4 in from the capital ends), z 33..44; the emblem medallion and the theme
# silhouette sit on it, top <= 50. Per theme (Downtown, Dusty, Summit):
#   Gate<T>Columns   both column shafts with their stepped capitals
#   Gate<T>Plinth    both stepped column bases
#   Gate<T>Crest     the crest band with the blank name face (29 x 9.8)
#   Gate<T>Crown     the emblem medallion (blank 6.4 disc) and the low theme silhouette
#   Gate<T>InlayLow / InlayMid / InlayHigh   inlay strips in three height bands (neutral swatch;
#                    Luau colours each world and lights them bottom to top)
# Downtown is always open (sign spec section 1), so it has no chain necks. Dusty and Summit have
# two recessed necks per column where the chain wraps sit.
# Lock set (family gates/Lock): GateChainLink, GateChainRun (5 pre-linked links), GateChainWrap,
#   GatePadlockBody, GatePadlockShackle, GateLockedPlaque, GateRequirementPlaque.
# Plot gate (family gates/Plot): PlotGatePillars, PlotGateBeam, PlotGateLamps, PlotGateAccent,
#   PlotGateChecker, PlotGateFlagpoles, PlotGateStartLine, PlotGateHedgeStub, PlotGateFenceStub.
#   Shared origin: the gate centre on the ground, front -y (toward the park).
# Text: every blank text face is listed in meta "sign_faces" as an exact rectangle (centre, size,
# normal, up) in mesh-local axes. Put a thin flat part (SignFace_*) there and parent the SurfaceGui
# to it: a SurfaceGui on the MeshPart itself sits on the bounding box and floats.
# Meta points are Blender mesh-local (x right, y back, z up) from the mesh origin. Roblox mesh-local
# is (x, z, -y), and a MeshPart is centred on its bounds (subtract the bounds centre).

import math
import random

from mathutils import Matrix, Vector

from kit_portal import at_y, ball, cbox, cyl, frames, layered, newell, oface, r3, rrect, sweep, torus
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


def frustum(b, z0, z1, c, lo, hi, swatch, top_sw=None):
    cx, cy = c

    def rect(w, d, z):
        return [Vector((cx + sx * w / 2, cy + sy * d / 2, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    layered(b, [rect(lo[0], lo[1], z0), rect(hi[0], hi[1], z1)], [swatch], Vector((cx, cy, (z0 + z1) / 2)), cap_last=top_sw or swatch)


def crystal(b, base, d, r, h, sides=6, sw=("ice", "ice_light")):
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
        oface(b, [r0[k], r0[k2], r1[k2], r1[k]], sw[k % 2], inside)
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


def sface(name, centre, size, normal=(0.0, -1.0, 0.0), up=(0.0, 0.0, 1.0), note=None):
    """A text-face record: put a thin flat part with this front rectangle there."""
    d = {"name": name, "centre": r3(Vector(centre)), "size": [round(size[0], 3), round(size[1], 3)],
         "normal": r3(Vector(normal)), "up": r3(Vector(up))}
    if note:
        d["note"] = note
    return d


SIGN_NOTE = ("sign_faces: exact text rectangles (centre, size, normal = the face's outward normal, up) "
             "in mesh-local axes; place a thin flat SignFace part there and parent the SurfaceGui to it")


# ---------------------------------------------------------------- portal gate template
FIELD_W, FIELD_H, FIELD_BOTTOM = 20.0, 30.0, 2.5
GATE_SPACING = 34.0
COL_X, COL_W, COL_D = 13.0, 4.0, 4.0
STEP_X, STEP_D = 4.8, 5.0             # widest plinth / capital step
OUTER_MAX = COL_X + STEP_X / 2        # 15.4
PLINTH_TOP, SHAFT_TOP, CAP_TOP = 2.6, 30.6, 33.0
CREST_HALF, CREST_D, CREST_Z0, CREST_Z1 = 15.0, 4.4, 33.0, 44.0
FACE_W, FACE_Z0, FACE_Z1 = 29.0, 33.7, 43.5
FACE_Y = -CREST_D / 2 - 0.2          # the raised name panel's front
EMBLEM_Z, EMBLEM_R, EMBLEM_RIM = 46.4, 3.2, 3.55
NECK_W = 3.0
NECKS = [(4.8, 9.2), (25.8, 30.2)]
WRAP_LOW, WRAP_HIGH = 7.0, 28.0
CHAIN_EYE_Y = -2.6
INLAY_BANDS = {"Low": (0.0, 12.6), "Mid": (12.6, 23.6), "High": (23.6, 60.0)}


def stepped(b, cx, z0, steps, sws, edge=None, up=True):
    """Stacked chamfered steps [(w, d, h)], from z0 upward."""
    z = z0
    for (w, d, h), sw in zip(steps, sws):
        cbox(b, Vector((cx, 0, z + h / 2)), (w, d, h), sw, c=min(0.14, h * 0.2), edge=edge)
        z += h
    return z


PLINTH_STEPS = [(4.8, 5.0, 0.9), (4.5, 4.6, 0.9), (4.2, 4.3, 0.8)]
CAP_STEPS = [(4.2, 4.3, 0.8), (4.5, 4.6, 0.8), (4.8, 5.0, 0.8)]


def template_meta(chained=True):
    m = {
        "origin": "field centre line on the ground: x 0 field centre, y 0 field plane, z 0 ground; front -y",
        "field": {"width": FIELD_W, "height": FIELD_H, "bottom": FIELD_BOTTOM, "top": FIELD_BOTTOM + FIELD_H, "plane_y": 0.0},
        "gate_spacing": GATE_SPACING, "columns_x": [-COL_X, COL_X], "column_section": [COL_W, COL_D],
        "column_inner_face_x": round(COL_X - COL_W / 2, 3), "outer_face_x": OUTER_MAX, "crest_half_width": CREST_HALF,
        "gap_to_neighbour": round(GATE_SPACING - 2 * OUTER_MAX, 3),
    }
    if chained:
        cross_z = (WRAP_LOW + WRAP_HIGH) / 2
        m.update({
            "neck_section": [NECK_W, NECK_W], "chain_wrap_zones_z": [list(n) for n in NECKS],
            "chain_wraps": {"left_low": [-COL_X, 0.0, WRAP_LOW], "left_high": [-COL_X, 0.0, WRAP_HIGH],
                            "right_low": [COL_X, 0.0, WRAP_LOW], "right_high": [COL_X, 0.0, WRAP_HIGH]},
            "chain_anchors": {"left_low": [-COL_X, CHAIN_EYE_Y, WRAP_LOW], "left_high": [-COL_X, CHAIN_EYE_Y, WRAP_HIGH],
                              "right_low": [COL_X, CHAIN_EYE_Y, WRAP_LOW], "right_high": [COL_X, CHAIN_EYE_Y, WRAP_HIGH]},
            "chain_cross": [0.0, CHAIN_EYE_Y, cross_z],
            "chain_diagonal_length": round(math.hypot(2 * COL_X, WRAP_HIGH - WRAP_LOW), 3),
            "chain_note": "two diagonals left_high->right_low and right_high->left_low, each three GateChainRun meshes; "
                          "set the second diagonal 0.7 toward -y so they pass at chain_cross",
            "requirement_plaque_suggested": {"position": [-14.0, -6.5, 0.0], "yaw_deg": 25.0,
                                             "mirror": {"position": [14.0, -6.5, 0.0], "yaw_deg": -25.0},
                                             "note": "beside the left column, outside the field's x range and the walk line; "
                                                     "face turned 25 degrees toward the approach"},
        })
    else:
        m["chained"] = "never: Downtown is always open (sign spec section 1); no necks, no wraps"
    return m


def crest_meta(panel, lettering):
    zc = (FACE_Z0 + FACE_Z1) / 2
    return {
        "underside": CREST_Z0, "top": CREST_Z1, "half_width": CREST_HALF, "panel": panel, "lettering_hint": lettering,
        "sign_faces": [sface("CrestName", (0.0, FACE_Y, zc), (FACE_W, FACE_Z1 - FACE_Z0),
                             note="two lines for DUSTY / HIGHWAY and SUMMIT / PASS; DOWNTOWN one line")],
        "sign_faces_note": SIGN_NOTE,
    }


def crown_meta(top, face_y):
    return {
        "top": round(top, 3), "medallion_centre": [0.0, EMBLEM_Z], "medallion_radius": EMBLEM_RIM,
        "sign_faces": [sface("Emblem", (0.0, face_y, EMBLEM_Z), (2 * EMBLEM_R, 2 * EMBLEM_R),
                             note="circular emblem decal of radius 3.2 inside this square")],
        "sign_faces_note": SIGN_NOTE,
        "note": "optional: without it the crest still reads; the emblem also sits on the padlock",
    }


def medallion(b, rim_sw, face_sw, y_front=-CREST_D / 2 - 0.25):
    """The emblem medallion in front of the crest top: its lower edge laps the crest top margin."""
    cyl(b, Vector((0, y_front + 0.7, EMBLEM_Z)), 0.7, EMBLEM_RIM, 20, rim_sw, axis=Vector((0, -1, 0)), top_sw=rim_sw)
    cyl(b, Vector((0, y_front, EMBLEM_Z)), 0.1, EMBLEM_R, 20, face_sw, axis=Vector((0, -1, 0)), top_sw=face_sw)
    return y_front - 0.1


# inlays -------------------------------------------------------------------
def strips_in_band(strips, band):
    lo, hi = INLAY_BANDS[band]
    out = []
    for x, z0, z1, w, fy in strips:
        a, c = max(z0, lo), min(z1, hi)
        if c - a > 0.4:
            out.append((x, a + (0.1 if a > z0 else 0), c - (0.1 if c < z1 else 0), w, fy))
    return out


def inlay_band(name, band, strips, crest_y, studs=False):
    b = Builder(name)
    rec = []
    for x, z0, z1, w, fy in strips_in_band(strips, band):
        box(b, Vector((x, fy - 0.04, (z0 + z1) / 2)), Vector((w, 0.12, z1 - z0)), "accent_neutral")
        rec.append({"x": round(x, 3), "z": [round(z0, 3), round(z1, 3)]})
    if band == "High":
        if studs:
            for k in range(19):
                box(b, Vector((-13.5 + 1.5 * k, crest_y - 0.08, 33.35)), Vector((0.45, 0.2, 0.45)), "accent_neutral")
            rec.append({"crest_row": "19 marquee studs at z 33.35"})
        else:
            box(b, Vector((0, crest_y - 0.05, 33.35)), Vector((26.0, 0.12, 0.3), ), "accent_neutral")
            rec.append({"crest_row": "one line at z 33.35"})
    lo, hi = INLAY_BANDS[band]
    return b, {"band": band, "z_range": [lo, min(hi, 45.0)], "strips": rec, "swatch": "accent_neutral (single swatch)",
               "recolour": "Luau: TextureID '' + Color; locked #3A3F5C, open = the World colour as Neon; "
                           "light InlayLow, then InlayMid, then InlayHigh (about 0.4 s apart); Reduce Motion: all at once"}


# ---------------------------------------------------------------- Downtown: gold art deco, stepped
DT_TIERS = [(PLINTH_TOP, 13.0, 4.4), (13.0, 23.0, 4.0), (23.0, SHAFT_TOP, 3.6)]


def downtown_columns(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        for i, (z0, z1, w) in enumerate(DT_TIERS):
            cbox(b, Vector((cx, 0, (z0 + z1) / 2)), (w, w, z1 - z0), "cream", c=0.14)
            # navy flute panel on the front of each tier, and a gold setback ledge on top
            box(b, Vector((cx, -w / 2, (z0 + z1) / 2)), Vector((w - 1.6, 0.2, z1 - z0 - 1.2)), "navy")
            if i < 2:
                cbox(b, Vector((cx, 0, z1 - 0.15)), (w + 0.1, w + 0.1, 0.3), "deco_gold", c=0.08)
            # gold beads on the two front corners
            for e in (-1, 1):
                box(b, Vector((cx + e * (w / 2 - 0.12), -w / 2 + 0.1, (z0 + z1) / 2)), Vector((0.3, 0.3, z1 - z0)), "deco_gold")
        stepped(b, cx, SHAFT_TOP, CAP_STEPS, ["deco_gold", "cream", "navy"], edge=None)
        # a small gold fan on the capital front
        for k in range(5):
            a0, a1 = math.pi * k / 5, math.pi * (k + 1) / 5
            r = 1.3 if k % 2 == 0 else 0.95
            pts = [(cx, 31.45), (cx + math.cos(a1) * r, 31.45 + math.sin(a1) * r), (cx + math.cos(a0) * r, 31.45 + math.sin(a0) * r)]
            extrude_xz(b, pts, -2.42, -2.28, "deco_gold" if k % 2 == 0 else "navy")
    return b, template_meta(chained=False)


def downtown_plinth(name):
    b = Builder(name)
    for s in (-1, 1):
        stepped(b, s * COL_X, 0.0, PLINTH_STEPS, ["navy", "cream", "deco_gold"])
    return b, {"top": PLINTH_TOP, "steps": [list(p) for p in PLINTH_STEPS], "outer_face_x": OUTER_MAX}


def downtown_crest(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, (CREST_Z0 + 43.4) / 2)), (2 * CREST_HALF, CREST_D, 43.4 - CREST_Z0), "cream", c=0.16)
    zc = (FACE_Z0 + FACE_Z1) / 2
    fh = FACE_Z1 - FACE_Z0
    # gold frame with stepped corners, navy name panel inside
    cbox(b, Vector((0, -CREST_D / 2 - 0.05, zc)), (FACE_W + 0.6, 0.2, fh + 0.4), "deco_gold", c=0.05)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cbox(b, Vector((sx * (FACE_W / 2 + 0.35), -CREST_D / 2 - 0.12, zc + sz * (fh / 2 + 0.3))), (1.0, 0.24, 1.0), "deco_gold", c=0.06)
    cbox(b, Vector((0, -CREST_D / 2 - 0.1, zc)), (FACE_W, 0.2, fh), "navy", c=0.04)
    # dark band for the marquee studs, gold top rail and a stepped (ziggurat) top
    cbox(b, Vector((0, -CREST_D / 2 + 0.05, 33.32)), (2 * CREST_HALF, 0.5, 0.64), "navy", c=0.08)
    cbox(b, Vector((0, 0, 43.55)), (2 * CREST_HALF, CREST_D + 0.2, 0.3), "deco_gold", c=0.08)
    cbox(b, Vector((0, 0, 43.85)), (26.0, CREST_D - 0.4, 0.3), "cream", c=0.08)
    m = crest_meta("navy, gold frame with stepped corners", "gold #F2C14E, one line")
    m["top"] = 44.0
    return b, m


def downtown_crown(name):
    b = Builder(name)
    # a stepped skyline: four set-back towers behind the medallion
    base = 44.0
    towers = [(-7.2, 2.2, 3.4), (-4.6, 2.6, 5.4), (4.6, 2.6, 5.0), (7.2, 2.2, 3.0)]
    for x, w, h in towers:
        extrude_xz(b, [(x - w / 2, base), (x + w / 2, base), (x + w / 2, base + h * 0.6), (x - w / 2, base + h * 0.6)], -0.3, 0.9, "deco_gold", "deco_gold")
        extrude_xz(b, [(x - w * 0.32, base + h * 0.6), (x + w * 0.32, base + h * 0.6), (x + w * 0.32, base + h * 0.88), (x - w * 0.32, base + h * 0.88)], -0.25, 0.85, "cream", "deco_gold")
        extrude_xz(b, [(x - w * 0.12, base + h * 0.88), (x + w * 0.12, base + h * 0.88), (x, base + h)], -0.2, 0.8, "deco_gold")
        # two navy window slots on the lower block
        for wx in (-w * 0.2, w * 0.2):
            box(b, Vector((x + wx, -0.32, base + h * 0.32)), Vector((0.32, 0.06, h * 0.36)), "navy")
    face_y = medallion(b, "deco_gold", "navy")
    return b, crown_meta(EMBLEM_Z + EMBLEM_RIM, face_y)


def downtown_strips():
    st = []
    for s in (-1, 1):
        for z0, z1, w in DT_TIERS:
            for e in (-0.6, 0.6):
                st.append((s * COL_X + e, z0 + 0.8, z1 - 0.8, 0.6, -w / 2 - 0.1))
    return st


# ---------------------------------------------------------------- Dusty Highway: red sandstone strata
DUSTY_CARVED = [(16.6, 18.2)]  # the mid carved band (the two necks are the other carved bands)


def shaft_runs(cuts):
    runs, z = [], PLINTH_TOP
    for a, c in sorted(cuts):
        runs.append((z, a))
        z = c
    runs.append((z, SHAFT_TOP))
    return [(a, c) for a, c in runs if c - a > 0.05]


def dusty_columns(name):
    b = Builder(name)
    tones = ["sand_red", "sand_red", "sand_orange", "sand_red", "sand_red", "sand_cream"]
    cuts = NECKS + DUSTY_CARVED
    for s in (-1, 1):
        cx = s * COL_X
        k = 0
        for z0, z1 in shaft_runs(cuts):
            n = max(1, round((z1 - z0) / 2.4))
            h = (z1 - z0) / n
            for i in range(n):
                cbox(b, Vector((cx, 0, z0 + h * (i + 0.5))), (COL_W, COL_D, h), tones[k % len(tones)], c=min(0.3, h * 0.2), edge="sand_dark")
                k += 1
        # broad carved bands: the recessed necks (chain seats) and one mid band
        for z0, z1 in cuts:
            cbox(b, Vector((cx, 0, (z0 + z1) / 2)), (NECK_W, NECK_W, z1 - z0 + 0.1), "sand_dark", c=0.12)
        # stepped, flared capital like a mesa ledge
        frustum(b, SHAFT_TOP, 31.4, (cx, 0), (4.0, 4.0), (4.4, 4.5), "sand_orange")
        cbox(b, Vector((cx, 0, 31.8)), (4.6, 4.8, 0.8), "sand_cream", c=0.25)
        cbox(b, Vector((cx, 0, 32.6)), (4.8, 5.0, 0.8), "sand_red", c=0.25, edge="sand_dark")
    m = template_meta()
    m["carved_bands_z"] = [list(c) for c in cuts]
    return b, m


def dusty_plinth(name):
    b = Builder(name)
    for s in (-1, 1):
        stepped(b, s * COL_X, 0.0, PLINTH_STEPS, ["sand_dark", "sand_red", "sand_orange"])
    return b, {"top": PLINTH_TOP, "steps": [list(p) for p in PLINTH_STEPS], "outer_face_x": OUTER_MAX}


def dusty_crest(name):
    b = Builder(name)
    zc = (FACE_Z0 + FACE_Z1) / 2
    fh = FACE_Z1 - FACE_Z0
    cbox(b, Vector((0, 0, (CREST_Z0 + 43.4) / 2)), (2 * CREST_HALF, CREST_D, 43.4 - CREST_Z0), "sand_orange", c=0.35, edge="sand_dark")
    cbox(b, Vector((0, -CREST_D / 2 - 0.05, zc)), (FACE_W + 0.6, 0.2, fh + 0.4), "sand_dark", c=0.15)
    cbox(b, Vector((0, -CREST_D / 2 - 0.1, zc)), (FACE_W, 0.2, fh), "sand_red", c=0.1)
    # strata courses: a dark bottom course and a mesa-profile cream top course
    cbox(b, Vector((0, 0, 33.3)), (2 * CREST_HALF, CREST_D + 0.3, 0.6), "sand_dark", c=0.22)
    extrude_xz(b, [(-CREST_HALF, 43.3), (CREST_HALF, 43.3), (CREST_HALF - 0.6, 43.7), (CREST_HALF - 1.6, 44.0), (-CREST_HALF + 1.6, 44.0), (-CREST_HALF + 0.6, 43.7)],
               -CREST_D / 2 - 0.2, CREST_D / 2 + 0.2, "sand_cream", "sand_cream")
    return b, crest_meta("sandstone red in a dark rim (strata texture)", "cream with a #7A2E1E side face, two lines")


def dusty_crown(name):
    b = Builder(name)
    # two flat-topped mesas either side of the medallion (the medallion is the setting sun)
    for sx, w0, w1, h in ((-1, 6.6, 4.4, 4.2), (1, 6.0, 3.8, 3.4)):
        x0 = sx * 6.6
        layers = [(44.0, 44.0 + h * 0.45, "sand_red"), (44.0 + h * 0.45, 44.0 + h * 0.8, "sand_orange"), (44.0 + h * 0.8, 44.0 + h, "sand_cream")]
        for i, (z0, z1, sw) in enumerate(layers):
            f0 = i / 3
            f1 = (i + 1) / 3
            a, c = w0 + (w1 - w0) * f0, w0 + (w1 - w0) * f1
            extrude_xz(b, [(x0 - a / 2, z0), (x0 + a / 2, z0), (x0 + c / 2, z1), (x0 - c / 2, z1)], -0.3, 0.9, sw, sw)
    face_y = medallion(b, "sand_dark", "sand_cream")
    return b, crown_meta(EMBLEM_Z + EMBLEM_RIM, face_y)


def dusty_strips():
    st = []
    cuts = NECKS + DUSTY_CARVED
    for s in (-1, 1):
        for z0, z1 in shaft_runs(cuts):
            if z1 - z0 > 1.0:
                st.append((s * COL_X, z0 + 0.35, z1 - 0.35, 0.8, -COL_D / 2))
    return st


# ---------------------------------------------------------------- Summit Pass: pale alpine stone, ice
SUMMIT_COLLARS = [(13.0, 13.8), (21.0, 21.8)]


def summit_columns(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        for z0, z1 in shaft_runs(NECKS):
            n = max(1, round((z1 - z0) / 2.8))
            h = (z1 - z0) / n
            for i in range(n):
                cbox(b, Vector((cx, 0, z0 + h * (i + 0.5))), (COL_W, COL_D, h), "alpine_stone", c=min(0.14, h * 0.2), edge="alpine_shadow")
        for z0, z1 in NECKS:
            cbox(b, Vector((cx, 0, (z0 + z1) / 2)), (NECK_W, NECK_W, z1 - z0 + 0.1), "alpine_shadow", c=0.12)
        # timber only on the two collars, bolted
        for z0, z1 in SUMMIT_COLLARS:
            cbox(b, Vector((cx, 0, (z0 + z1) / 2)), (4.3, 4.3, z1 - z0), "plank", c=0.1, edge="bark_warm")
        # stepped pale stone capital with a frost-blue course and short icicles under the first ledge
        stepped(b, cx, SHAFT_TOP, CAP_STEPS, ["alpine_stone", "frost_blue", "alpine_stone"], edge="alpine_shadow")
        for dx, ln in ((-1.3, 0.45), (-0.5, 0.6), (0.4, 0.4), (1.2, 0.55)):
            icicle(b, Vector((cx + dx, -2.24, 31.4)), ln, 0.12)
    m = template_meta()
    m["icicles_lowest_z"] = 30.8
    return b, m


def summit_plinth(name):
    b = Builder(name)
    for s in (-1, 1):
        cx = s * COL_X
        stepped(b, cx, 0.0, PLINTH_STEPS, ["alpine_shadow", "alpine_stone", "alpine_stone"], edge="alpine_shadow")
        # snow on the first step and a small ice cluster on the outer front corner, leaning forward
        ellipsoid(b, (cx - s * 0.8, -2.2, 0.95), (1.1, 0.5, 0.28), 8, 4, "snow")
        base = Vector((cx + s * 1.5, -2.05, 1.75))
        crystal(b, base, (0.0, -0.35, 1), 0.3, 2.0)
        crystal(b, base + Vector((-s * 0.45, 0.1, 0.0)), (-s * 0.25, -0.2, 1), 0.22, 1.4)
    return b, {"top": PLINTH_TOP, "steps": [list(p) for p in PLINTH_STEPS], "outer_face_x": OUTER_MAX, "ice_cluster_top": 3.8}


def summit_crest(name):
    b = Builder(name)
    zc = (FACE_Z0 + FACE_Z1) / 2
    fh = FACE_Z1 - FACE_Z0
    cbox(b, Vector((0, 0, (CREST_Z0 + 43.4) / 2)), (2 * CREST_HALF, CREST_D, 43.4 - CREST_Z0), "alpine_stone", c=0.2, edge="alpine_shadow")
    cbox(b, Vector((0, -CREST_D / 2 - 0.05, zc)), (FACE_W + 0.6, 0.2, fh + 0.4), "frost_blue", c=0.08)
    cbox(b, Vector((0, -CREST_D / 2 - 0.1, zc)), (FACE_W, 0.2, fh), "snow", c=0.05)
    # an ice rim along the bottom course and a snow cap with drip lobes
    cbox(b, Vector((0, 0, 33.3)), (2 * CREST_HALF, CREST_D + 0.3, 0.6), "frost_blue", c=0.15)
    cbox(b, Vector((0, 0, 43.7)), (2 * CREST_HALF - 0.2, CREST_D + 0.2, 0.6), "snow", c=0.22)
    for k in range(8):
        x = -12.6 + k * 3.6
        ellipsoid(b, (x, -CREST_D / 2 - 0.2, 43.5), (1.5 + 0.2 * (k % 2), 0.42, 0.4), 8, 4, "snow")
    return b, crest_meta("pale stone in a frost-blue frame", "alpine blue #24477A, ice side face #5FA9CF, two lines")


def summit_crown(name):
    b = Builder(name)
    # twin peaks behind the medallion, snow on the tips
    for x0, w, h in ((-5.0, 9.0, 5.3), (5.2, 8.0, 4.6)):
        z0 = 44.0
        tip = (x0, z0 + h)
        extrude_xz(b, [(x0 - w / 2, z0), (x0 + w / 2, z0), tip], -0.3, 0.9, "alpine_shadow", "alpine_shadow")
        sf = 0.42
        extrude_xz(b, [(x0 - w / 2 * sf, z0 + h * (1 - sf)), (x0 + w / 2 * sf, z0 + h * (1 - sf)), tip], -0.38, 0.95, "snow", "snow")
    crystal(b, Vector((-1.0, 0.2, 44.0)), (-0.3, 0.0, 1), 0.5, 2.2)
    crystal(b, Vector((1.2, 0.2, 44.0)), (0.35, 0.0, 1), 0.45, 1.8)
    face_y = medallion(b, "frost_blue", "alpine_stone")
    return b, crown_meta(EMBLEM_Z + EMBLEM_RIM, face_y)


def summit_strips():
    st = []
    for s in (-1, 1):
        for z0, z1 in shaft_runs(NECKS):
            cut = [(z0, z1)]
            for c0, c1 in SUMMIT_COLLARS:
                nxt = []
                for a, c in cut:
                    if c0 >= c or c1 <= a:
                        nxt.append((a, c))
                    else:
                        nxt += [(a, c0), (c1, c)]
                cut = nxt
            for a, c in cut:
                if c - a > 1.0:
                    st.append((s * COL_X, a + 0.3, c - 0.3, 0.6, -COL_D / 2))
    return st


# ---------------------------------------------------------------- lock set
RUN_LEN, RUN_W, RUN_WIRE = 3.2, 1.9, 0.5
RUN_PITCH = RUN_LEN - 2 * RUN_WIRE
RUN_LINKS = 5


def sweep_lit(b, path, radius, sides, sw, hi_sw, light=Vector((0.25, -0.45, 0.86)), phase=0.0):
    """A closed round tube along a polyline; faces turned to the light get the highlight swatch."""
    path = [Vector(p) for p in path]
    fr = frames(path, True)
    rings = []
    for p, (t, nor, bi) in zip(path, fr):
        rings.append([p + (nor * math.cos(phase + 2 * math.pi * k / sides) + bi * math.sin(phase + 2 * math.pi * k / sides)) * radius for k in range(sides)])
    light = light.normalized()
    n = len(path)
    for i in range(n):
        j = (i + 1) % n
        mid = (path[i] + path[j]) / 2
        for k in range(sides):
            k2 = (k + 1) % sides
            q = [rings[i][k], rings[i][k2], rings[j][k2], rings[j][k]]
            cen = sum(q, Vector((0, 0, 0))) / 4
            nn = (cen - mid).normalized()
            oface(b, q, hi_sw if nn.dot(light) > 0.55 else sw, mid)


def oval_link(b, c, t, w, length, width, wire, sides=4, pts=6, sw="iron", hi="iron_hi"):
    r = wire / 2
    hx, hy = length / 2 - r, width / 2 - r
    path = []
    for k in range(pts):
        a = 2 * math.pi * k / pts
        ca, sa = math.cos(a), math.sin(a)
        path.append(Vector(c) + t * (hx * math.copysign(abs(ca) ** 0.7, ca)) + w * (hy * math.copysign(abs(sa) ** 1.2, sa)))
    sweep_lit(b, path, r, sides, sw, hi, phase=math.pi / sides)


def gate_chain_link(name):
    b = Builder(name)
    oval_link(b, Vector((0, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), RUN_LEN, RUN_W, RUN_WIRE)
    return b, {"length": RUN_LEN, "width": RUN_W, "wire": RUN_WIRE, "pitch": RUN_PITCH, "origin": "link centre",
               "long_axis": "x", "plane": "xz (faces -y); use for end fitting only, the diagonals are GateChainRun"}


def gate_chain_run(name):
    b = Builder(name)
    for i in range(RUN_LINKS):
        c = Vector((i * RUN_PITCH, 0, 0))
        w = Vector((0, 0, 1)) if i % 2 == 0 else Vector((0, 1, 0))
        oval_link(b, c, Vector((1, 0, 0)), w, RUN_LEN, RUN_W, RUN_WIRE)
    return b, {"links": RUN_LINKS, "pitch": RUN_PITCH, "run_pitch": round(RUN_LINKS * RUN_PITCH, 3),
               "origin": "centre of the first link", "axis": "+x",
               "first_link_centre": [0.0, 0.0, 0.0], "last_link_centre": [round((RUN_LINKS - 1) * RUN_PITCH, 3), 0.0, 0.0],
               "note": "even links face -y (plane xz), odd links are edge-on; chain runs end to end at run_pitch "
                       "(the next run's first link sits one pitch past this run's last). Three runs make one diagonal"}


def rr_path(a, bb, r, n=360):
    """A dense closed polyline round a rounded rectangle (half sizes a, bb), CCW from the front centre."""
    cs = [(a - r, bb - r), (-(a - r), bb - r), (-(a - r), -(bb - r)), (a - r, -(bb - r))]
    seg = []
    for i, (cx, cy) in enumerate(cs):
        for k in range(13):
            ang = math.radians(90 * i + 90 * k / 12)
            seg.append(Vector((cx + math.cos(ang) * r, cy + math.sin(ang) * r, 0)))
    start = Vector((0, -bb, 0))
    idx = min(range(len(seg)), key=lambda i: (seg[i] - start).length if seg[i].y < 0 and seg[i].x >= 0 else 1e9)
    raw = [start] + seg[idx:] + seg[:idx] + [start]
    lens = [0.0]
    for i in range(1, len(raw)):
        lens.append(lens[-1] + (raw[i] - raw[i - 1]).length)
    total = lens[-1]
    pts = []
    j = 0
    for k in range(n):
        s = total * k / n
        while j < len(lens) - 2 and lens[j + 1] <= s:
            j += 1
        f = (s - lens[j]) / max(1e-9, lens[j + 1] - lens[j])
        pts.append(raw[j].lerp(raw[j + 1], f))
    return pts, total


def gate_chain_wrap(name):
    b = Builder(name)
    band_half = NECK_W / 2 + 0.15
    band_h = 1.5
    # a visible iron band round the neck, with light edges
    cbox(b, Vector((0, 0, 0)), (2 * band_half, 2 * band_half, band_h), "iron", c=0.12, edge="iron_hi")
    ln, wd, wire = 3.6, 2.0, 0.5
    per_turn = 6
    off = wire / 2 + 0.05
    dense, per = rr_path(band_half, band_half, 0.3)
    for i in range(per_turn):
        f = (i + 0.5) / per_turn
        idx = int(f * len(dense)) % len(dense)
        p = dense[idx]
        q = dense[(idx + 3) % len(dense)]
        t = (q - p).normalized()
        out = Vector((t.y, -t.x, 0))
        tilt = math.radians(18) * (1 if i % 2 else -1)
        w = (Vector((0, 0, 1)) * math.cos(tilt) + out * math.sin(tilt)).normalized()
        oval_link(b, p + out * off, t, w, ln, wd, wire)
    # a lug at the front centre where the X chain's end link hooks on
    cbox(b, Vector((0, -band_half - 0.35, 0)), (0.8, 0.7, 0.9), "iron", c=0.12, edge="iron_hi")
    reach = band_half + off + wire / 2 + (wd / 2) * math.sin(math.radians(18))
    return b, {
        "origin": "column axis at the wrap's mid height", "fits_neck": [NECK_W, NECK_W], "height": round(wd, 3),
        "links": per_turn, "turns": 1, "lug": [0.0, round(-band_half - 0.7, 3), 0.0],
        "reach_from_axis": round(max(reach, band_half + 0.7), 3),
        "symmetric": "use the same mesh at all four positions (rotate, never mirror)",
    }


PB_W, PB_H, PB_T = 7.0, 6.0, 2.4
PS_X, PS_R, PS_INSERT, PS_RISE = 2.3, 0.42, 0.6, 3.0


def gate_padlock_body(name):
    b = Builder(name)
    hy = PB_T / 2

    def prof(i):
        return rrect(PB_W - 2 * i, PB_H - 2 * i, max(0.2, 1.0 - i), max(0.3, 2.2 - i), seg=3)

    layers = [at_y(prof(0.3), hy), at_y(prof(0), hy - 0.3), at_y(prof(0), -hy + 0.4), at_y(prof(0.12), -hy + 0.14), at_y(prof(0.38), -hy)]
    layered(b, layers, ["steel", "steel", "brass", "steel"], Vector((0, 0, 0)), cap_first="steel", cap_last="steel")
    front = -hy
    ez = 0.5
    cyl(b, Vector((0, front + 0.05, ez)), 0.3, 2.4, 16, "brass", axis=Vector((0, -1, 0)), top_sw="brass")
    cyl(b, Vector((0, front - 0.25, ez)), 0.08, 2.05, 16, "cream", axis=Vector((0, -1, 0)), top_sw="cream")
    emblem_y = front - 0.33
    kz = -2.1
    cyl(b, Vector((0, front + 0.02, kz)), 0.14, 0.75, 10, "brass", axis=Vector((0, -1, 0)), top_sw="brass")
    cyl(b, Vector((0, front - 0.12, kz + 0.12)), 0.04, 0.3, 8, "black", axis=Vector((0, -1, 0)), top_sw="black")
    extrude_xz(b, [(-0.12, kz + 0.05), (0.12, kz + 0.05), (0.2, kz - 0.5), (-0.2, kz - 0.5)][::-1], front - 0.16, front - 0.1, "black")
    top = PB_H / 2
    for x in (-PS_X, PS_X):
        cyl(b, Vector((x, 0, top - 0.25)), 0.4, 0.62, 8, "steel", top_sw="black")
    eyes = []
    for x in (-2.4, 2.4):
        zc = -0.8 - math.sqrt(max(0.0, 2.2 ** 2 - (abs(x) - 1.3) ** 2)) - 0.22
        torus(b, Vector((x, 0, zc)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.36, 0.1, 6, 4, "steel")
        eyes.append([x, 0.0, round(zc, 3)])
    return b, {
        "width": PB_W, "height": PB_H, "thickness": PB_T, "origin": "body centre",
        "shackle_left": [-PS_X, top], "shackle_right": [PS_X, top], "shackle_seat": [-PS_X, round(top - PS_INSERT, 3)],
        "keyhole_centre": [0.0, kz], "plaque_eyes": eyes,
        "assembly": {"hang_from": "chain_cross", "body_centre_below_cross": round(PB_H / 2 + 1.5, 3),
                     "note": "the shackle arch hangs over the chain crossing: body top 1.5 below the crossing"},
        "sign_faces": [sface("PadlockEmblem", (0.0, emblem_y, ez), (4.1, 4.1), note="circular emblem of radius 2.05 inside this square")],
        "sign_faces_note": SIGN_NOTE,
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
    sweep(b, path, PS_R, 6, "steel", phase=math.pi / 6)
    return b, {
        "origin": "bottom of the left leg (hinge axis z)", "leg_gap": gap, "section": 2 * PS_R,
        "inner_width": round(gap - 2 * PS_R, 3), "height": round(top_outer, 3), "rise_above_body": PS_RISE,
        "inner_top_above_body": round(PS_RISE - 2 * PS_R, 3), "insert": PS_INSERT, "right_leg_bottom": right_bottom,
        "lift_to_open": round(PS_INSERT - right_bottom + 0.05, 3),
    }


LP_W, LP_H, LP_T = 15.4, 4.4, 0.5


def gate_locked_plaque(name):
    b = Builder(name)
    hy = LP_T / 2

    def prof(i):
        return rrect(LP_W - 2 * i, LP_H - 2 * i, max(0.15, 1.3 - i), max(0.15, 1.3 - i), seg=2)

    layers = [at_y(prof(0.1), hy), at_y(prof(0), hy - 0.1), at_y(prof(0), -hy + 0.12), at_y(prof(0.1), -hy)]
    layered(b, layers, ["bark_warm", "bark_warm", "bark_warm"], Vector((0, 0, 0)), cap_first="bark_warm", cap_last="bark_warm")
    fw, fh = LP_W - 1.0, LP_H - 1.0
    face = rrect(fw, fh, 0.9, 0.9, seg=2)
    face_y = -hy - 0.06
    layered(b, [at_y(face, -hy + 0.02), at_y(face, face_y)], ["cream"], Vector((0, 0, 0)), cap_last="cream")
    rings = []
    for x in (-2.4, 2.4):
        zc = LP_H / 2 + 0.22
        torus(b, Vector((x, 0, zc)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.36, 0.1, 6, 4, "steel")
        rings.append([x, 0.0, round(zc, 3)])
    return b, {
        "board": [LP_W, LP_H, LP_T], "origin": "board centre",
        "hang_rings": rings, "hang_note": "rings interlock with GatePadlockBody plaque_eyes: each ring centre 0.5 below its eye",
        "sign_faces": [sface("LockedText", (0.0, face_y, 0.0), (fw, fh), note="LOCKED at 2.5 capitals is 13.4 wide; corner radius 0.9")],
        "sign_faces_note": SIGN_NOTE,
    }


RQ_W, RQ_H, RQ_T, RQ_TILT = 7.4, 3.05, 0.35, 55.0
RQ_FACE = (7.0, 2.75)
RQ_TOP = 2.98  # viewing corridors: nothing taller than 3


def gate_requirement_plaque(name):
    b = Builder(name)
    theta = math.radians(90.0 - RQ_TILT)
    rot = Matrix.Rotation(-theta, 4, "X")
    normal = (rot.to_3x3() @ Vector((0, -1, 0))).normalized()
    up = (rot.to_3x3() @ Vector((0, 0, 1))).normalized()
    # board centre set so the highest corner is RQ_TOP
    zc = RQ_TOP - (RQ_H / 2) * math.sin(math.radians(RQ_TILT)) - (RQ_T / 2) * math.cos(math.radians(RQ_TILT))
    cbox(b, Vector((0, 0.1, 0.15)), (3.0, 2.4, 0.3), "stone_light", c=0.1, edge="rock")
    # a short post set back under the board
    cbox(b, Vector((0, 0.55, (0.3 + zc + 0.1) / 2)), (1.0, 0.8, zc + 0.1 - 0.3), "bark_warm", c=0.1, edge="plank_dark")
    n0 = mark(b)
    cbox(b, Vector((0, 0, 0)), (RQ_W, RQ_T, RQ_H), "bark_warm", c=0.1, edge="plank_dark")
    fw, fh = RQ_FACE
    box(b, Vector((0, -RQ_T / 2 - 0.03, 0)), Vector((fw, 0.06, fh)), "plank")
    m = Matrix.Translation(Vector((0, 0, zc))) @ rot
    xform_since(b, n0, m)
    face_c = m @ Vector((0, -RQ_T / 2 - 0.06, 0))
    lo_edge = m @ Vector((0, -RQ_T / 2, -RQ_H / 2))
    corners = [m @ Vector((0, sy * RQ_T / 2, sz * RQ_H / 2)) for sy in (-1, 1) for sz in (-1, 1)]
    top = max(c.z for c in corners)
    peek_v0 = -fh / 2
    peek_v1 = -fh / 2 + 0.225 * fh
    return b, {
        "origin": "ground centre, front -y",
        "tilt_from_horizontal_deg": RQ_TILT, "board": [RQ_W, RQ_H, RQ_T], "height": round(top, 3),
        "board_low_edge_z": round(lo_edge.z, 3), "corridor_limit": 3.0,
        "sign_faces": [sface("RequirementFace", face_c, (fw, fh), normal=normal, up=up,
                             note="spec 2b layout re-cut to this face: canvas 700 x 275 at PixelsPerStud 100 (was 800 x 400 on 8 x 4)")],
        "peek_reserved": {"face_local_u": [round(-fw / 2 + 0.1, 3), round(fw / 2 - 0.1, 3)],
                          "face_local_v": [round(peek_v0, 3), round(peek_v1, 3)],
                          "canvas_px": {"x": 10, "y": 213, "w": 680, "h": 62},
                          "note": "bottom 22.5 percent of the face (spec y 300..390 of 400, scaled); kept empty, never a button, not modelled"},
        "sign_faces_note": SIGN_NOTE,
        "placement": "see template meta requirement_plaque_suggested (beside the left column, not on the walk line)",
    }


# ---------------------------------------------------------------- plot (speedway) gate
PG_OPEN_HALF = 7.0
PG_BASE_X, PG_BASE_W, PG_BASE_H = 8.8, 3.6, 2.5
PG_PIL_X, PG_PIL_W = 8.25, 2.5
PG_BEAM_Z0, PG_BEAM_Z1, PG_BEAM_HALF, PG_BEAM_D = 10.5, 13.5, 12.0, 2.5
PG_DISC_X, PG_DISC_R = 10.4, 1.5
PG_NAME_W, PG_NAME_H = 17.4, 2.0
PG_FLAG_X, PG_FLAG_Y = 12.6, 2.0


def plotgate_pillars(name):
    b = Builder(name)
    for s in (-1, 1):
        bx = s * PG_BASE_X
        cbox(b, Vector((bx, 0, 0.3)), (PG_BASE_W, PG_BASE_W, 0.6), "rock", c=0.12, edge="rock_dark")
        cbox(b, Vector((bx - s * 0.75, 0, 1.025)), (1.8, 3.3, 0.85), "stone_light", c=0.1, edge="birch_grey")
        cbox(b, Vector((bx + s * 0.9, 0, 1.025)), (1.5, 3.3, 0.85), "birch_grey", c=0.1, edge="stone_light")
        cbox(b, Vector((bx, -0.8, 1.875)), (3.3, 1.7, 0.85), "birch_grey", c=0.1, edge="stone_light")
        cbox(b, Vector((bx, 0.85, 1.875)), (3.3, 1.6, 0.85), "stone_light", c=0.1, edge="birch_grey")
        cbox(b, Vector((bx, 0, 2.4)), (3.5, 3.5, 0.2), "stone_light", c=0.06)
        px = s * PG_PIL_X
        # teal plinth course, cream shaft, navy cap the beam sits on
        cbox(b, Vector((px, 0, 2.95)), (2.9, 2.9, 0.9), "teal", c=0.1)
        cbox(b, Vector((px, 0, (3.4 + 9.6) / 2)), (PG_PIL_W, PG_PIL_W, 9.6 - 3.4), "cream", c=0.14)
        cbox(b, Vector((px, 0, 10.05)), (2.9, 2.9, 0.9), "navy", c=0.1)
    return b, {
        "opening": {"x": [-PG_OPEN_HALF, PG_OPEN_HALF], "z": [0.0, PG_BEAM_Z0]},
        "stone_base": {"x": [round(PG_BASE_X - PG_BASE_W / 2, 3), round(PG_BASE_X + PG_BASE_W / 2, 3)], "size": [PG_BASE_W, PG_BASE_W, PG_BASE_H]},
        "pillar": {"x": PG_PIL_X, "size": [PG_PIL_W, PG_PIL_W]}, "hedge_joint_x": round(PG_BASE_X + PG_BASE_W / 2, 3),
        "colliders": "stone base 3.6 x 3.6 x 2.5 and pillar 2.9 x 2.9 to 10.5 each side; the opening stays clear",
    }


def plotgate_beam(name):
    b = Builder(name)
    zc = (PG_BEAM_Z0 + PG_BEAM_Z1) / 2
    hd = PG_BEAM_D / 2
    cbox(b, Vector((0, 0, zc)), (2 * PG_BEAM_HALF, PG_BEAM_D, PG_BEAM_Z1 - PG_BEAM_Z0), "navy", c=0.14)
    # a faint cream inner frame round the name zone, both faces
    fw, fh, t = PG_NAME_W + 0.3, PG_NAME_H + 0.3, 0.09
    for side in (-1, 1):
        y = side * (hd + 0.02)
        for dz in (-1, 1):
            box(b, Vector((0, y, zc + dz * fh / 2)), Vector((fw, 0.05, t)), "cream")
        for dx in (-1, 1):
            box(b, Vector((dx * fw / 2, y, zc)), Vector((t, 0.05, fh)), "cream")
    faces = []
    for side, tag in ((-1, "Front"), (1, "Back")):
        nrm = (0.0, float(side), 0.0)
        faces.append(sface("PlotName" + tag, (0.0, side * hd, zc), (PG_NAME_W, PG_NAME_H), normal=nrm,
                           note="owner name (upper case) with the YOUR SPEEDWAY / PREVIEW row; spec section 4 text rect"))
        for s in (-1, 1):
            faces.append(sface("PlotNumber" + tag + ("L" if s < 0 else "R"), (s * PG_DISC_X, side * (hd + 0.12), zc), (2.0, 2.0), normal=nrm,
                               note="plot number on the accent disc (capitals about 1.6)"))
    return b, {
        "beam": {"x": [-PG_BEAM_HALF, PG_BEAM_HALF], "z": [PG_BEAM_Z0, PG_BEAM_Z1], "depth": PG_BEAM_D, "colour": "navy"},
        "top": PG_BEAM_Z1, "sign_faces": faces, "sign_faces_note": SIGN_NOTE,
        "spec_note": "no label tab above the beam and no hanging PREVIEW plate (top <= 13.5, opening >= 10.5); both rows go in the name face",
    }


def plotgate_accent(name):
    b = Builder(name)
    zc = (PG_BEAM_Z0 + PG_BEAM_Z1) / 2
    hd = PG_BEAM_D / 2
    for side in (-1, 1):
        y = side * (hd + 0.02)
        for z in (PG_BEAM_Z0 + 0.2, PG_BEAM_Z1 - 0.2):
            box(b, Vector((0, y, z)), Vector((2 * PG_BEAM_HALF - 0.3, 0.06, 0.4)), "accent_neutral")
        for s in (-1, 1):
            cyl(b, Vector((s * PG_DISC_X, side * hd, zc)), 0.12, PG_DISC_R, 16, "accent_neutral", axis=Vector((0, side, 0)), top_sw="accent_neutral")
    for s in (-1, 1):
        box(b, Vector((s * PG_PIL_X, 0, 9.45)), Vector((2.62, 2.62, 0.3)), "accent_neutral")
    return b, {
        "swatch": "accent_neutral (single swatch)",
        "recolour": "TextureID '' + Color: 1 red #E5484D, 2 orange #FF8A1F, 3 yellow #F7C531, 4 green #3DBE6C, 5 blue #3F8FE0, 6 purple #8E5BE8",
        "parts": "beam bands 0.4 top and bottom (both faces), number discs r 1.5 at the beam ends (both faces), pillar collars under the caps",
    }


def plotgate_lamps(name):
    b = Builder(name)
    lights = []
    for s in (-1, 1):
        x = s * PG_PIL_X
        fy = -PG_PIL_W / 2
        cbox(b, Vector((x, fy - 0.05, 9.0)), (0.6, 0.12, 0.6), "metal", c=0.03)
        sweep(b, [Vector((x, fy - 0.08, 9.0)), Vector((x, fy - 0.6, 9.0)), Vector((x, fy - 0.75, 8.85))], 0.08, 5, "metal")
        ly = fy - 0.95
        cyl(b, Vector((x, ly, 8.6)), 0.2, 0.28, 8, "metal", r_top=0.2)
        ball(b, Vector((x, ly, 8.05)), 0.62, 8, 5, "lamp_glass")
        lights.append([x, round(ly, 3), 8.05])
    return b, {"light_points": lights, "globe_radius": 0.62, "note": "round globe lamps on short brackets at the pillar heads; PointLight at each light point"}


def plotgate_checker(name):
    b = Builder(name)
    sq, cols, rows = 1.0, 2, 4
    z0 = 3.5
    for s in (-1, 1):
        x0 = s * PG_PIL_X - sq * cols / 2
        fy = -PG_PIL_W / 2
        box(b, Vector((s * PG_PIL_X, fy - 0.03, z0 + sq * rows / 2)), Vector((sq * cols + 0.1, 0.07, sq * rows + 0.1)), "black")
        for r in range(rows):
            for k in range(cols):
                if (r + k) % 2:
                    continue
                xa, za = x0 + k * sq, z0 + r * sq
                oface(b, [Vector((xa, fy - 0.075, za)), Vector((xa + sq, fy - 0.075, za)), Vector((xa + sq, fy - 0.075, za + sq)), Vector((xa, fy - 0.075, za + sq))], "cart_white", Vector((xa, 0, za)))
    return b, {"strips": [[-PG_PIL_X, z0, z0 + sq * rows], [PG_PIL_X, z0, z0 + sq * rows]], "square": sq, "note": "1-stud squares (no shimmer), pillar fronts"}


def plotgate_flagpoles(name):
    b = Builder(name)
    flags = []
    for s in (-1, 1):
        x = s * PG_FLAG_X
        cbox(b, Vector((x, PG_FLAG_Y, 0.2)), (0.9, 0.9, 0.4), "stone_light", c=0.08)
        cyl(b, Vector((x, PG_FLAG_Y, 0.4)), 0.3, 0.24, 8, "metal", r_top=0.16)
        cyl(b, Vector((x, PG_FLAG_Y, 0.7)), 12.55, 0.12, 8, "cream", r_top=0.09)
        ball(b, Vector((x, PG_FLAG_Y, 13.33)), 0.16, 8, 4, "brass")
        flags.append({"top": [x, PG_FLAG_Y, 13.1], "bottom": [x, PG_FLAG_Y, 11.1], "side": "+x" if s > 0 else "-x"})
    return b, {"flags": flags, "height": 13.49, "note": "poles just past the beam ends, behind the hedge line; flags fly outward; cloth is a Luau Beam"}


def plotgate_start_line(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, 0.025)), (14.0, 2.1, 0.05), "cart_white", c=0.01)
    sq = 1.0
    for r in range(2):
        for k in range(14):
            if (r + k) % 2:
                continue
            xa, ya = -7.0 + k * sq, -sq + r * sq
            oface(b, [Vector((xa, ya, 0.055)), Vector((xa + sq, ya, 0.055)), Vector((xa + sq, ya + sq, 0.055)), Vector((xa, ya + sq, 0.055))], "black", Vector((xa, ya, 0)))
    return b, {"size": [14.0, 2.1], "top": 0.055, "note": "on the court between the pillars at y 0; raise 0.02 above the court surface"}


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
    ("Downtown", downtown_columns, downtown_plinth, downtown_crest, downtown_crown, downtown_strips, -CREST_D / 2 + 0.05 - 0.25, True),
    ("Dusty", dusty_columns, dusty_plinth, dusty_crest, dusty_crown, dusty_strips, -CREST_D / 2 - 0.15, False),
    ("Summit", summit_columns, summit_plinth, summit_crest, summit_crown, summit_strips, -CREST_D / 2 - 0.15, False),
]

LOCK = [
    ("GateChainLink", gate_chain_link), ("GateChainRun", gate_chain_run), ("GateChainWrap", gate_chain_wrap),
    ("GatePadlockBody", gate_padlock_body), ("GatePadlockShackle", gate_padlock_shackle),
    ("GateLockedPlaque", gate_locked_plaque), ("GateRequirementPlaque", gate_requirement_plaque),
]

PLOT = [
    ("PlotGatePillars", plotgate_pillars), ("PlotGateBeam", plotgate_beam), ("PlotGateLamps", plotgate_lamps),
    ("PlotGateAccent", plotgate_accent), ("PlotGateChecker", plotgate_checker), ("PlotGateFlagpoles", plotgate_flagpoles),
    ("PlotGateStartLine", plotgate_start_line), ("PlotGateHedgeStub", plotgate_hedge_stub), ("PlotGateFenceStub", plotgate_fence_stub),
]


def all_pieces():
    """(name, builder function, family) for every mesh, in build order."""
    out = []
    for theme, cols, plinth, crest, crown, strips, crest_y, studs in THEMES:
        out.append(("Gate" + theme + "Columns", cols, "gates/Portal"))
        out.append(("Gate" + theme + "Plinth", plinth, "gates/Portal"))
        out.append(("Gate" + theme + "Crest", crest, "gates/Portal"))
        out.append(("Gate" + theme + "Crown", crown, "gates/Portal"))
        for band in ("Low", "Mid", "High"):
            def fn(name, band=band, strips=strips, crest_y=crest_y, studs=studs):
                return inlay_band(name, band, strips(), crest_y, studs)
            out.append(("Gate" + theme + "Inlay" + band, fn, "gates/Portal"))
    out += [(n, fn, "gates/Lock") for n, fn in LOCK]
    out += [(n, fn, "gates/Plot") for n, fn in PLOT]
    return out


def build_all(emit):
    for name, fn, family in all_pieces():
        emit(*fn(name), family)


# referenced for lint-free imports
_ = (newell,)
