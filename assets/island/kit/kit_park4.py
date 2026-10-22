# Island kit: Task 4 park family "park4" (Lane 3): snack-corner furniture, raised flower beds and
# the river-loop bridges, in the kit's smooth faceted language (cream / light stone, navy / teal
# structure, chamfered edges, low side counts, no studs). Concept stage: sizes are proposals.
#
# Mesh-local axes (Blender): x right, y back, z up, front faces -y; Roblox mesh-local is (x, z, -y).
# Meta points are Blender mesh-local from the mesh origin; a MeshPart is centred on its bounds, so
# subtract the bounds centre (manifest) before placing anything on a MeshPart.
#
#   PicnicTable        origin at the table centre on the ground, long axis x. Top 2.7, seats 1.5.
#                      A 0.6 square hole at the top centre takes the Parasol pole.
#   Parasol            canopy + pole + ground socket as one mesh; origin at the pole bottom (z 0),
#                      standing in the PicnicTable centre hole (same origin as the table).
#   LightPost          string-light / bunting post, 9 tall; meta Hook = centre of the top ring
#                      (strings drawn by Luau between Hook points, any direction).
#   ParkBin            octagonal slatted bin, 2.1 across, 2.9 tall, open top with a dark liner.
#   BedJunctionRound   full round junction bed, 18 across.
#   BedCornerFillet    quarter-round bed for a grass corner where two paths meet: the path corner
#                      (where the two path edges would meet) at the origin, path edges along +x
#                      (path on y < 0) and +y (path on x < 0); follows the paving fillet of radius
#                      8 (half the 16 avenue width), set back 1 from the paving.
#   BedAvenueArc       5 x 18 curved strip bed on a 178 centreline radius (fits 157-200 within 0.03
#                      of sagitta), rounded ends; front (low planting) on the concave side, -y.
#   BedAvenueStraight  5 x 18 straight strip bed, rounded ends, front -y.
#   BedFountainArc     8 wide arc segment on a ring of centreline radius 49 (inner 45, outer 53),
#                      14 long on the centreline, square chamfered ends; front (concave) faces the
#                      fountain (-y) and has a 1.2 gravel strip inside the border.
#   BridgeRiverAvenue  river-loop bridge, deck 18 wide (avenue paths 16), 26 long.
#   BridgeRiverApproach river-loop bridge, deck 14 wide (approach paths 12), 26 long.
#                      Bridges: origin at deck centre, deck top z 0, long axis x (along the path).
#                      The walking surface is flat at z 0 from end to end (no arch on the deck):
#                      ends are square and flush, the deck sits in a notch (seat) on each
#                      abutment, and nothing in the mesh rises above z 0 at the ends. Shallow
#                      elliptical arches under the deck, two cutwater piers to the river bed,
#                      abutments with pilasters and flush-topped wing walls along the path sides.

import math

from mathutils import Vector

from kit_portal import cbox, cyl, newell, oface, sweep, tface, torus
from kitlib import Builder, box, tube


def r2(p):
    return [round(p[0], 2), round(p[1], 2)]


def r3(v):
    return [round(c, 3) for c in v]


def hface(b, pts, swatch, hint):
    """A planar face wound so its normal points along `hint`."""
    v = [Vector(p) for p in pts]
    if newell(v).dot(Vector(hint)) < 0:
        v.reverse()
    b.face(v, swatch)


# ================================================================ A. snack-corner furniture
TABLE_L, TOP_W, TOP_Z, TOP_T = 7.0, 3.2, 2.7, 0.24
SEAT_Z, SEAT_Y, SEAT_W, SEAT_T = 1.5, 2.55, 1.05, 0.2
FRAME_X, HOLE = 2.5, 0.6


def picnic_table(name):
    b = Builder(name)
    nb = 5
    bw = (TOP_W - (nb - 1) * 0.05) / nb
    zc = TOP_Z - TOP_T / 2
    for i in range(nb):
        y = -TOP_W / 2 + bw / 2 + i * (bw + 0.05)
        if i == nb // 2:
            # the centre board is split round the 0.6 pole hole
            half = (TABLE_L / 2 - HOLE / 2)
            for s in (-1, 1):
                cbox(b, Vector((s * (HOLE / 2 + half / 2), y, zc)), (half, bw, TOP_T), "bench_wood", c=0.06, edge="plank")
        else:
            cbox(b, Vector((0, y, zc)), (TABLE_L, bw, TOP_T), "bench_wood", c=0.06, edge="plank")
    # a cream grommet frame round the hole
    g = HOLE / 2 + 0.1
    for s in (-1, 1):
        box(b, Vector((0, s * g, TOP_Z + 0.03)), Vector((2 * g + 0.2, 0.2, 0.06)), "cream")
        box(b, Vector((s * g, 0, TOP_Z + 0.03)), Vector((0.2, 2 * g - 0.2, 0.06)), "cream")
    # two seats of two boards each
    sl = TABLE_L - 0.4
    for sy in (-1, 1):
        for k in (-1, 1):
            cbox(b, Vector((0, sy * SEAT_Y + k * 0.27, SEAT_Z - SEAT_T / 2)), (sl, 0.5, SEAT_T), "bench_wood", c=0.05, edge="plank")
    # two navy A-frames: top bearer, seat bearer, splayed legs, feet and a diagonal brace each
    for s in (-1, 1):
        x = s * FRAME_X
        cbox(b, Vector((x, 0, TOP_Z - TOP_T - 0.12)), (0.26, TOP_W - 0.2, 0.24), "navy", c=0.05)
        cbox(b, Vector((x, 0, SEAT_Z - SEAT_T - 0.12)), (0.26, 2 * SEAT_Y + SEAT_W - 0.1, 0.24), "navy", c=0.05)
        for sy in (-1, 1):
            sweep(b, [Vector((x, sy * 2.15, 0.1)), Vector((x, sy * 0.8, TOP_Z - TOP_T - 0.05))], 0.14, 4, "navy", phase=math.pi / 4)
            cbox(b, Vector((x, sy * 2.15, 0.07)), (0.42, 0.6, 0.14), "navy", c=0.04)
        sweep(b, [Vector((x, 0, SEAT_Z - SEAT_T - 0.12)), Vector((s * 0.9, 0, TOP_Z - TOP_T - 0.04))], 0.1, 4, "navy", phase=math.pi / 4)
    return b, {
        "height": round(TOP_Z + 0.06, 3), "TableTop": TOP_Z, "Seat": SEAT_Z, "length": TABLE_L,
        "width": round(2 * SEAT_Y + SEAT_W, 3), "PoleHole": [0, 0, TOP_Z], "hole": HOLE,
        "Seats": [[0, -SEAT_Y, SEAT_Z], [0, SEAT_Y, SEAT_Z]], "seat_length": sl, "seat_depth": SEAT_W,
        "note": "origin at the table centre on the ground; the Parasol shares the origin (its pole stands in PoleHole)",
    }


PAR_R, PAR_RIM, PAR_VAL, PAR_MID_R, PAR_MID, PAR_APEX, POLE_R = 3.75, 7.35, 7.05, 2.1, 7.75, 7.95, 0.13


def parasol(name):
    b = Builder(name)
    # ground socket: a weighted navy base with a cream collar (sits under the table, between frames)
    cyl(b, Vector((0, 0, -0.1)), 0.4, 0.55, 10, "navy", r_top=0.48)
    cyl(b, Vector((0, 0, 0.3)), 0.25, 0.24, 8, "cream", r_top=0.2)
    # pole (navy), a cream collar where it passes the table top, the runner and the top cap
    cyl(b, Vector((0, 0, 0.3)), PAR_APEX - 0.3, POLE_R, 8, "navy", top=False)
    cyl(b, Vector((0, 0, TOP_Z + 0.06)), 0.18, 0.2, 8, "cream")
    cyl(b, Vector((0, 0, 6.05)), 0.4, 0.22, 8, "cream", r_top=0.17)
    gores = 8
    rim = [Vector((math.cos(2 * math.pi * k / gores) * PAR_R, math.sin(2 * math.pi * k / gores) * PAR_R, PAR_RIM)) for k in range(gores)]
    mid = [Vector((math.cos(2 * math.pi * k / gores) * PAR_MID_R, math.sin(2 * math.pi * k / gores) * PAR_MID_R, PAR_MID)) for k in range(gores)]
    apex = Vector((0, 0, PAR_APEX))
    colours = ["coral", "cream"]
    for k in range(gores):
        k2 = (k + 1) % gores
        sw = colours[k % 2]
        b.face2([rim[k], rim[k2], mid[k2], mid[k]], sw)
        b.face2([mid[k], mid[k2], apex], sw)
        # a scalloped valance flap under each gore edge
        m = (rim[k] + rim[k2]) / 2
        b.face2([rim[k], rim[k2], m * 1.0 - Vector((0, 0, PAR_RIM - PAR_VAL))], "teal" if k % 2 else "coral")
    # ribs under the canopy from the runner to each rim point
    for k in range(gores):
        d = Vector((math.cos(2 * math.pi * k / gores), math.sin(2 * math.pi * k / gores), 0))
        tube(b, [Vector((0, 0, 6.35)) + d * 0.15, d * (PAR_R * 0.55) + Vector((0, 0, PAR_RIM + 0.18)), d * (PAR_R - 0.1) + Vector((0, 0, PAR_RIM - 0.04))], [0.045] * 3, 4, ["navy"], cap=False)
    # finial
    cyl(b, Vector((0, 0, PAR_APEX - 0.02)), 0.12, 0.16, 8, "navy")
    cyl(b, Vector((0, 0, PAR_APEX + 0.1)), 0.2, 0.12, 8, "cream", r_top=0.02)
    top = PAR_APEX + 0.3
    return b, {
        "height": round(top, 3), "PoleTop": [0, 0, round(top, 3)], "CanopyRim": {"radius": PAR_R, "z": PAR_RIM},
        "underside_min": PAR_VAL, "pole_radius": POLE_R, "apex": PAR_APEX, "socket_radius": 0.55,
        "note": "origin at the pole bottom on the ground; place at the PicnicTable origin (pole through PoleHole); lowest valance 7.05",
    }


POST_H, HOOK_Z = 9.0, 8.85


def light_post(name):
    b = Builder(name)
    # a cream stone footing, partly sunk, with a navy collar
    cbox(b, Vector((0, 0, 0.1)), (1.3, 1.3, 0.8), "stone_light", c=0.1, top="cream")
    cbox(b, Vector((0, 0, 0.6)), (0.72, 0.72, 0.2), "navy", c=0.05)
    # the navy post with two cream bands
    cbox(b, Vector((0, 0, 0.7 + 3.75)), (0.42, 0.42, 7.5), "navy", c=0.07)
    for z in (2.6, 7.6):
        cbox(b, Vector((0, 0, z)), (0.54, 0.54, 0.24), "cream", c=0.05)
    # cap plate, pyramid and the hook ring on a short stalk
    cbox(b, Vector((0, 0, 8.28)), (0.62, 0.62, 0.16), "cream", c=0.04)
    base = 8.36
    sq = [Vector((sx * 0.26, sy * 0.26, base)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    tip = Vector((0, 0, 8.66))
    for k in range(4):
        oface(b, [sq[k], sq[(k + 1) % 4], tip], "navy", Vector((0, 0, base + 0.05)))
    cyl(b, Vector((0, 0, 8.55)), 0.3, 0.05, 6, "navy")
    torus(b, Vector((0, 0, HOOK_Z)), Vector((1, 0, 0)), Vector((0, 1, 0)), 0.24, 0.05, 10, 4, "navy")
    return b, {
        "height": POST_H, "Hook": [0, 0, HOOK_Z], "hook_ring_radius": 0.24, "footing": 1.3, "sink": 0.3,
        "note": "Hook is the centre of a horizontal ring on top: strings may leave in any direction",
    }


def park_bin(name):
    b = Builder(name)
    S = 8
    ph = math.pi / S

    def oct_ring(z, r):
        return [Vector((math.cos(ph + 2 * math.pi * k / S) * r, math.sin(ph + 2 * math.pi * k / S) * r, z)) for k in range(S)]

    def bandr(lo, hi, sw, inward=False, inside_z=None):
        for k in range(S):
            k2 = (k + 1) % S
            pts = [lo[k], lo[k2], hi[k2], hi[k]]
            mid = sum(pts, Vector((0, 0, 0))) / 4
            c = Vector((0, 0, mid.z if inside_z is None else inside_z))
            if inward:
                tface(b, pts, sw, c)
            else:
                oface(b, pts, sw, c)

    # navy plinth, a navy lower band, wooden slats, a navy upper band, a cream rolled rim
    bandr(oct_ring(-0.2, 1.02), oct_ring(0.2, 1.02), "navy")
    bandr(oct_ring(0.2, 1.02), oct_ring(0.28, 0.94), "navy")
    bandr(oct_ring(0.28, 0.9), oct_ring(2.3, 0.9), "navy")
    apo = 0.9 * math.cos(ph)
    for k in range(S):
        a = 2 * math.pi * (k + 1) / S
        d = Vector((math.cos(a), math.sin(a), 0))
        box(b, d * (apo + 0.05) + Vector((0, 0, 1.4)), Vector((0.46, 0.12, 1.75)), "bench_wood", rot_z=a + math.pi / 2)
    cbox_r = oct_ring(2.3, 0.97)
    bandr(oct_ring(0.4, 0.97), oct_ring(0.6, 0.97), "navy")
    bandr(oct_ring(2.1, 0.97), cbox_r, "navy")
    rim_lo = oct_ring(2.3, 1.07)
    rim_hi = oct_ring(2.62, 1.07)
    rim_top = oct_ring(2.72, 0.98)
    inner_top = oct_ring(2.72, 0.82)
    inner_lo = oct_ring(2.35, 0.8)
    bandr(cbox_r, rim_lo, "cream", inside_z=2.6)
    bandr(rim_lo, rim_hi, "cream")
    bandr(rim_hi, rim_top, "cream")
    for k in range(S):
        k2 = (k + 1) % S
        oface(b, [rim_top[k], rim_top[k2], inner_top[k2], inner_top[k]], "cream", Vector((0, 0, 0)))
    bandr(inner_lo, inner_top, "black", inward=True)
    oface(b, inner_lo, "black", Vector((0, 0, 0)))
    return b, {"height": 2.72, "radius": 1.07, "opening_radius": 0.8, "opening_z": 2.72,
               "note": "no bin existed in the kit (checked kit_props, kit_plants, manifest); new piece"}


# ================================================================ B. raised flower beds
BED_TOP, BED_SOIL, BED_FOOT, BED_CH = 0.9, 0.6, -0.3, 0.15
HEIGHTS = {"back": [4.0, 5.0], "middle": [2.0, 3.0], "front": [0.8, 1.5]}


def bed_shell(b, outline, bw, soil_regions=None):
    """Loft a kerb border from outline(t) (t = inset from the outer edge; CCW from above, the same
    point count for every t) and fill the soil. soil_regions: optional [(polygon, swatch)] that
    replace the single soil face (the fountain bed's gravel strip)."""
    layers = [(-0.05, BED_FOOT), (0.0, 0.15), (0.0, BED_TOP - BED_CH), (BED_CH, BED_TOP),
              (bw - BED_CH, BED_TOP), (bw, BED_TOP - 0.12), (bw, BED_SOIL)]
    sw = ["rock", "sign_board", "stone_light", None, "stone_light", "rock_dark"]
    rings = [[Vector((x, y, z)) for x, y in outline(t)] for t, z in layers]
    n = len(rings[0])
    # kerb-stone rhythm on the top: alternate two creams about every 1.6 studs of length
    mid = outline(bw / 2)
    run, tops = 0.0, []
    for k in range(n):
        p, q = Vector(mid[k]), Vector(mid[(k + 1) % n])
        seg = (q - p).length
        tops.append("cream" if int((run + seg / 2) / 1.6) % 2 == 0 else "stone_light")
        run += seg
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        for k in range(n):
            k2 = (k + 1) % n
            b.face([A[k], A[k2], B[k2], B[k]], sw[i] or tops[k])
    if soil_regions is None:
        b.face(rings[-1], "dirt")
    else:
        for poly, swatch in soil_regions:
            b.face([Vector((x, y, BED_SOIL)) for x, y in poly], swatch)


def circle(r, n, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def bed_meta(planting, bw, extra):
    m = {"height": BED_TOP, "soil": BED_SOIL, "border_top": BED_TOP, "border_width": bw, "sink": -BED_FOOT,
         "planting": [r2(p) for p in planting], "heights": HEIGHTS}
    m.update(extra)
    return m


# ---------------------------------------------------------------- BedJunctionRound
JR_R, JR_BW = 9.0, 1.25


def bed_junction_round(name):
    b = Builder(name)
    bed_shell(b, lambda t: circle(JR_R - t, 44), JR_BW)
    rp = JR_R - JR_BW
    edges = [0.0, rp * 1 / 3, rp * 2 / 3, rp]
    return b, bed_meta(circle(rp, 24), JR_BW, {
        "radius": JR_R, "planting_radius": rp,
        "bands": {"type": "radial", "centre": [0, 0],
                  "back": [0, round(edges[1], 2)], "middle": [round(edges[1], 2), round(edges[2], 2)], "front": [round(edges[2], 2), round(rp, 2)]},
        "note": "bands are radius ranges from the centre: tallest in the middle, lowest at the kerb",
    })


# ---------------------------------------------------------------- BedCornerFillet
CF_FILLET, CF_SET, CF_RB, CF_BW = 8.0, 1.0, 15.0, 1.25
CF_FRONT, CF_MIDDLE = 2.0, 4.2   # band edges, measured from the planting's front (path-side) edge


def corner_outline(tf, tb, nl=4, nb=16, nf=8):
    """Grass-corner bed: front edges y = s + tf (along +x) and x = s + tf (along +y) joined by the
    paving fillet offset (centre (8, 8), radius 8 - s - tf); back arc about the path corner (the
    origin) of radius Rb - tb. CCW from above."""
    f = CF_FILLET
    e = CF_SET + tf
    rb = CF_RB - tb
    rf = f - e
    a0 = math.asin(e / rb)
    a1 = math.pi / 2 - a0
    xe = rb * math.cos(a0)
    pts = []
    for i in range(nl):
        pts.append((f + (xe - f) * i / nl, e))
    for j in range(nb + 1):
        a = a0 + (a1 - a0) * j / nb
        pts.append((rb * math.cos(a), rb * math.sin(a)))
    ye = rb * math.sin(a1)
    for i in range(1, nl + 1):
        pts.append((e, ye + (f - ye) * i / nl))
    for j in range(1, nf):
        a = math.pi + (math.pi / 2) * j / nf
        pts.append((f + rf * math.cos(a), f + rf * math.sin(a)))
    return pts


def bed_corner_fillet(name):
    b = Builder(name)
    bed_shell(b, lambda t: corner_outline(t, t), CF_BW)
    planting = corner_outline(CF_BW, CF_BW)
    middle = corner_outline(CF_BW + CF_FRONT, CF_BW)
    back = corner_outline(CF_BW + CF_MIDDLE, CF_BW)
    return b, bed_meta(planting, CF_BW, {
        "path_corner": [0, 0], "path_edges": {"x_path": "y = 0 (path on y < 0)", "y_path": "x = 0 (path on x < 0)"},
        "fillet_radius": CF_FILLET, "fillet_centre": [CF_FILLET, CF_FILLET], "setback": CF_SET, "back_radius": CF_RB,
        "bands": {"type": "nested", "rule": "a point is back if inside back_outline, else middle if inside middle_outline, else front",
                  "front_depth": CF_FRONT, "middle_depth": round(CF_MIDDLE - CF_FRONT, 2),
                  "middle_outline": [r2(p) for p in middle], "back_outline": [r2(p) for p in back]},
        "sightline_note": "research task4-hub-park 9 asks for nothing over 3 studs within about 17 of a corner; the whole bed lies within 15, so the 4-5 back band conflicts (question for the lead)",
        "note": "place with the origin on the junction's path-edge corner; rotate in 90 degree steps for the other three corners",
    })


# ---------------------------------------------------------------- BedAvenueArc / BedAvenueStraight
AV_L, AV_W, AV_BW, AV_R = 18.0, 5.0, 1.0, 178.0


def stadium_outline(L, Wd, ns=8, nc=8):
    def f(t):
        r = Wd / 2 - t
        xc = L / 2 - Wd / 2
        pts = []
        for i in range(ns):
            pts.append((-xc + 2 * xc * i / ns, -r))
        for j in range(nc):
            a = -math.pi / 2 + math.pi * j / nc
            pts.append((xc + r * math.cos(a), r * math.sin(a)))
        for i in range(ns):
            pts.append((xc - 2 * xc * i / ns, r))
        for j in range(nc):
            a = math.pi / 2 + math.pi * j / nc
            pts.append((-xc + r * math.cos(a), r * math.sin(a)))
        return pts
    return f


def arc_capped_outline(R, L, Wd, ns=10, nc=8):
    """A curved strip on a centreline of radius R through the origin, centre of curvature (0, -R)
    (concave side -y), rounded caps; L is the overall length along the centreline."""
    th = (L / 2 - Wd / 2) / R

    def P(rad, a):
        return Vector((rad * math.sin(a), -R + rad * math.cos(a)))

    def f(t):
        r = Wd / 2 - t
        pts = []
        for i in range(ns):
            pts.append(P(R - r, -th + 2 * th * i / ns))
        er, ur, tr = P(R, th), Vector((math.sin(th), math.cos(th))), Vector((math.cos(th), -math.sin(th)))
        for j in range(nc):
            c = math.pi * j / nc
            pts.append(er + r * (-ur * math.cos(c) + tr * math.sin(c)))
        for i in range(ns):
            pts.append(P(R + r, th - 2 * th * i / ns))
        el, ul, tl = P(R, -th), Vector((-math.sin(th), math.cos(th))), Vector((-math.cos(th), -math.sin(th)))
        for j in range(nc):
            c = math.pi * j / nc
            pts.append(el + r * (ul * math.cos(c) + tl * math.sin(c)))
        return [(p.x, p.y) for p in pts]
    return f, th


def strip_bands(half):
    """Three equal strips across a planting of half-width `half`, front on -y."""
    w = 2 * half / 3
    return [-half, -half + w, -half + 2 * w, half]


def bed_avenue_straight(name):
    b = Builder(name)
    f = stadium_outline(AV_L, AV_W)
    bed_shell(b, f, AV_BW)
    half = AV_W / 2 - AV_BW
    e = strip_bands(half)
    return b, bed_meta(f(AV_BW), AV_BW, {
        "length": AV_L, "width": AV_W,
        "bands": {"type": "strip_y", "front": [round(e[0], 2), round(e[1], 2)], "middle": [round(e[1], 2), round(e[2], 2)], "back": [round(e[2], 2), round(e[3], 2)]},
        "note": "bands are y ranges (front on -y, toward the path); rounded ends of radius 2.5",
    })


def bed_avenue_arc(name):
    b = Builder(name)
    f, th = arc_capped_outline(AV_R, AV_L, AV_W)
    bed_shell(b, f, AV_BW)
    half = AV_W / 2 - AV_BW
    e = strip_bands(half)
    return b, bed_meta(f(AV_BW), AV_BW, {
        "length": AV_L, "width": AV_W, "arc_radius": AV_R, "centre": [0, -AV_R],
        "sweep_deg": round(math.degrees(2 * (AV_L / 2) / AV_R), 3), "cap_centre_sweep_deg": round(math.degrees(2 * th), 3),
        "inner_radius": AV_R - AV_W / 2, "outer_radius": AV_R + AV_W / 2,
        "bands": {"type": "arc_radial", "centre": [0, -AV_R], "front": [round(AV_R + e[0], 2), round(AV_R + e[1], 2)],
                  "middle": [round(AV_R + e[1], 2), round(AV_R + e[2], 2)], "back": [round(AV_R + e[2], 2), round(AV_R + e[3], 2)]},
        "fits_radius": [157, 200],
        "note": "front (low) on the concave side; sagitta 0.23 over 18, so one radius fits 157-200 within 0.03",
    })


# ---------------------------------------------------------------- BedFountainArc
FA_RM, FA_RI, FA_RO, FA_LEN, FA_BW, FA_GRAVEL, FA_CH = 49.0, 45.0, 53.0, 14.0, 1.25, 1.2, 0.6


def fountain_outline(ns=10):
    th = (FA_LEN / 2) / FA_RM

    def P(rad, a):
        return (rad * math.sin(a), -FA_RM + rad * math.cos(a))

    def f(t):
        ri, ro = FA_RI + t, FA_RO - t
        c = max(0.05, FA_CH - 0.414 * t)

        def ang(r):
            return th - math.asin(t / r)

        pts = []
        ai = ang(ri) - c / ri
        for i in range(ns + 1):
            pts.append(P(ri, -ai + 2 * ai * i / ns))
        pts.append(P(ri + c, ang(ri + c)))
        pts.append(P(ro - c, ang(ro - c)))
        ao = ang(ro) - c / ro
        for i in range(ns + 1):
            pts.append(P(ro, ao - 2 * ao * i / ns))
        pts.append(P(ro - c, -ang(ro - c)))
        pts.append(P(ri + c, -ang(ri + c)))
        return pts
    return f, th


def arc_region(r_in, r_out, t_end, th, ns=10):
    def P(rad, a):
        return (rad * math.sin(a), -FA_RM + rad * math.cos(a))

    def ang(r):
        return th - math.asin(t_end / r)

    pts = [P(r_in, -ang(r_in) + 2 * ang(r_in) * i / ns) for i in range(ns + 1)]
    pts += [P(r_out, ang(r_out) - 2 * ang(r_out) * i / ns) for i in range(ns + 1)]
    return pts


def bed_fountain_arc(name):
    b = Builder(name)
    f, th = fountain_outline()
    g0, g1 = FA_RI + FA_BW, FA_RI + FA_BW + FA_GRAVEL
    p1 = FA_RO - FA_BW
    gravel = arc_region(g0, g1, FA_BW, th)
    soil = arc_region(g1, p1, FA_BW, th)
    bed_shell(b, f, FA_BW, soil_regions=[(gravel, "rock"), (soil, "dirt")])
    w = (p1 - g1) / 3
    return b, bed_meta(soil, FA_BW, {
        "ring_radius": FA_RM, "inner_radius": FA_RI, "outer_radius": FA_RO, "centre": [0, -FA_RM],
        "sweep_deg": round(math.degrees(2 * th), 3), "length_on_centreline": FA_LEN,
        "gravel": {"inner": g0, "outer": g1},
        "bands": {"type": "arc_radial", "centre": [0, -FA_RM], "front": [round(g1, 2), round(g1 + w, 2)],
                  "middle": [round(g1 + w, 2), round(g1 + 2 * w, 2)], "back": [round(g1 + 2 * w, 2), round(p1, 2)]},
        "note": "front (concave, toward the fountain) has a 1.2 gravel strip inside the kerb; place with the centre on the fountain and yaw by multiples of the sweep plus gaps",
    })


# ================================================================ C. river-loop bridges
BR_HL, BR_EB, BR_END = 13.0, 0.8, 0.8      # half length, edge-beam width, end-beam length
BR_ZS, BR_BED, BR_WATER = -2.2, -4.6, -2.5  # arch springing, river bed, water surface
BR_PIER_X, BR_PIER_HW, BR_ABF = 4.6, 0.8, 11.5
BR_RING, BR_PROUD, BR_WING = 0.45, 0.1, 16.6
BR_POSTS = 8                                  # bays per side


def ellipse_pts(xa, xb, zs, zc, n=12):
    """Intrados samples (x, z, outward normal) from xa to xb, vertical at the springings."""
    xm, a, h = (xa + xb) / 2, (xb - xa) / 2, zc - zs
    out = []
    for i in range(n + 1):
        phi = math.pi - math.pi * i / n
        x, z = xm + a * math.cos(phi), zs + h * math.sin(phi)
        nx, nz = math.cos(phi) / a, math.sin(phi) / h
        ln = math.hypot(nx, nz)
        out.append((x, z, nx / ln, nz / ln))
    return out


def bridge_river(name, W):
    b = Builder(name)
    hw = W / 2
    HL = BR_HL
    yb = hw - BR_EB
    # ---- the walking surface: flat at z 0 from end to end
    xe = HL - BR_END
    nb = 24
    for i in range(nb):
        x0, x1 = -xe + 2 * xe * i / nb, -xe + 2 * xe * (i + 1) / nb
        hface(b, [(x0, -yb, 0), (x1, -yb, 0), (x1, yb, 0), (x0, yb, 0)], "plank" if i % 2 == 0 else "bench_wood", (0, 0, 1))
    for s in (-1, 1):
        hface(b, [(-HL, s * yb, 0), (HL, s * yb, 0), (HL, s * hw, 0), (-HL, s * hw, 0)], "stone_light", (0, 0, 1))
        hface(b, [(s * xe, -yb, 0), (s * HL, -yb, 0), (s * HL, yb, 0), (s * xe, yb, 0)], "cream", (0, 0, 1))
        # the end faces of the deck and abutment (buried in the path fill)
        hface(b, [(s * HL, -hw, 0), (s * HL, hw, 0), (s * HL, hw, -3.4), (s * HL, -hw, -3.4)], "rock", (s, 0, 0))
    # ---- arches: side spans from the abutment face to the pier, a wider middle span
    pf = BR_PIER_X - BR_PIER_HW
    spans = [(-BR_ABF, -(BR_PIER_X + BR_PIER_HW), -1.15), (-pf, pf, -0.95), (BR_PIER_X + BR_PIER_HW, BR_ABF, -1.15)]
    yo = hw + BR_PROUD
    for xa, xb, zc in spans:
        pts = ellipse_pts(xa, xb, BR_ZS, zc)
        ring = [(x + nx * BR_RING, z + nz * BR_RING) for x, z, nx, nz in pts]
        xm = (xa + xb) / 2
        for i in range(len(pts) - 1):
            (x0, z0, _, _), (x1, z1, _, _) = pts[i], pts[i + 1]
            (rx0, rz0), (rx1, rz1) = ring[i], ring[i + 1]
            # soffit (barrel underside) across the full width
            tface(b, [(x0, -yo, z0), (x1, -yo, z1), (x1, yo, z1), (x0, yo, z0)], "rock_dark", (xm, 0, BR_ZS - 1.0))
            for s in (-1, 1):
                # the proud arch ring (voussoir band) and its upper edge
                hface(b, [(x0, s * yo, z0), (x1, s * yo, z1), (rx1, s * yo, rz1), (rx0, s * yo, rz0)], "stone_light", (0, s, 0))
                nrm = Vector(((pts[i][2] + pts[i + 1][2]) / 2, 0, (pts[i][3] + pts[i + 1][3]) / 2))
                hface(b, [(rx0, s * hw, rz0), (rx1, s * hw, rz1), (rx1, s * yo, rz1), (rx0, s * yo, rz0)], "stone_light", nrm)
                # spandrel wall above the ring, up to the deck
                hface(b, [(rx0, s * hw, rz0), (rx1, s * hw, rz1), (rx1, s * hw, 0), (rx0, s * hw, 0)], "sign_board", (0, s, 0))
    # spandrel over each pier, between the neighbouring rings
    for sx in (-1, 1):
        # from the middle span's ring end to the side span's ring end (no overlap with the strips)
        x0, x1 = sx * (BR_PIER_X - BR_PIER_HW + BR_RING), sx * (BR_PIER_X + BR_PIER_HW - BR_RING)
        for s in (-1, 1):
            hface(b, [(x0, s * hw, BR_ZS), (x1, s * hw, BR_ZS), (x1, s * hw, 0), (x0, s * hw, 0)], "sign_board", (0, s, 0))
    # a proud cornice band under the deck edge (top below z 0, so no lip)
    for s in (-1, 1):
        cbox(b, Vector((0, s * (hw + 0.06), -0.22)), (2 * BR_ABF, 0.24, 0.3), "stone_light", c=0.05)
    # ---- piers with pointed cutwaters, from the river bed
    for sx in (-1, 1):
        px = sx * BR_PIER_X
        hex_ = [(px - BR_PIER_HW, -(hw + 0.1)), (px, -(hw + 1.3)), (px + BR_PIER_HW, -(hw + 0.1)),
                (px + BR_PIER_HW, hw + 0.1), (px, hw + 1.3), (px - BR_PIER_HW, hw + 0.1)]
        for (z0, z1, sw) in ((BR_BED, BR_WATER - 0.1, "rock"), (BR_WATER - 0.1, BR_ZS, "stone_light")):
            for k in range(6):
                (ax, ay), (bx, by) = hex_[k], hex_[(k + 1) % 6]
                oface(b, [(ax, ay, z0), (bx, by, z0), (bx, by, z1), (ax, ay, z1)], sw, (px, 0, (z0 + z1) / 2))
        # sloped caps (starlings) on the two noses, leaning on the spandrel
        for s in (-1, 1):
            A = Vector((px - BR_PIER_HW, s * (hw + 0.1), BR_ZS))
            T = Vector((px, s * (hw + 1.3), BR_ZS))
            B = Vector((px + BR_PIER_HW, s * (hw + 0.1), BR_ZS))
            P = Vector((px, s * (hw + 0.1), BR_ZS + 0.9))
            inside = Vector((px, s * (hw + 0.4), BR_ZS + 0.2))
            oface(b, [A, T, P], "stone_light", inside)
            oface(b, [T, B, P], "stone_light", inside)
    # ---- abutments: river face under the springing, corner pilasters, flush wing walls
    for sx in (-1, 1):
        hface(b, [(sx * BR_ABF, -yo, -3.4), (sx * BR_ABF, yo, -3.4), (sx * BR_ABF, yo, BR_ZS), (sx * BR_ABF, -yo, BR_ZS)], "rock", (-sx, 0, 0))
        for s in (-1, 1):
            cbox(b, Vector((sx * (BR_ABF + HL - 0.1) / 2, s * (hw + 0.2), -1.7)), (HL - 0.1 - BR_ABF, 0.4, 3.4), "sign_board", c=0.08, top="cream", edge="stone_light")
            cbox(b, Vector((sx * (HL + BR_WING) / 2, s * (hw - 0.175), -1.4)), (BR_WING - HL, 1.25, 2.8), "sign_board", c=0.08, top="cream", edge="stone_light")
    # ---- railings: cream posts and newels, navy top rail, teal mid and kick rails
    yr = hw - 0.4
    xn = HL - 0.4
    for s in (-1, 1):
        for i in range(BR_POSTS + 1):
            x = -xn + 2 * xn * i / BR_POSTS
            if i in (0, BR_POSTS):
                cbox(b, Vector((x, s * yr, 1.7)), (0.8, 0.8, 3.4), "cream", c=0.08, edge="stone_light")
                cbox(b, Vector((x, s * yr, 3.48)), (0.96, 0.96, 0.16), "navy", c=0.04)
                base, half, top = 3.56, 0.34, 4.0
            else:
                cbox(b, Vector((x, s * yr, 1.5)), (0.42, 0.42, 3.0), "cream", c=0.06, edge="stone_light")
                base, half, top = 3.0, 0.24, 3.28
            sq = [Vector((x + qx * half, s * yr + qy * half, base)) for qx, qy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            tip = Vector((x, s * yr, top))
            for k in range(4):
                oface(b, [sq[k], sq[(k + 1) % 4], tip], "navy", Vector((x, s * yr, base + 0.02)))
        L = 2 * xn - 0.8
        cbox(b, Vector((0, s * yr, 2.72)), (L, 0.3, 0.32), "navy", c=0.07)
        cbox(b, Vector((0, s * yr, 1.65)), (L, 0.2, 0.22), "teal", c=0.05)
        cbox(b, Vector((0, s * yr, 0.6)), (L, 0.2, 0.2), "teal", c=0.05)
    corners = [[sx * HL, sy * hw, 0] for sx in (-1, 1) for sy in (-1, 1)]
    return b, {
        "height": 4.0, "deck_top": 0, "deck_length": 2 * HL, "deck_width": W, "walk_width": round(2 * (yr - 0.21), 2),
        "DeckEnds": [[-HL, 0, 0], [HL, 0, 0]], "DeckCorners": corners,
        "RailEnds": [[sx * xn, sy * yr, 0] for sx in (-1, 1) for sy in (-1, 1)], "rail_line_y": yr, "rail_top": 2.88,
        "FencePost": [[sx * (HL + 0.45), sy * yr, 0] for sx in (-1, 1) for sy in (-1, 1)],
        "water_surface": BR_WATER, "river_bed": BR_BED, "river_width": 16, "bank_slope": "1:3.5 (water edge x +/-8 to path level at x +/-16.75)",
        "abutment_face_x": BR_ABF, "piers_x": [-BR_PIER_X, BR_PIER_X], "pier_width": 2 * BR_PIER_HW, "wing_wall_end_x": BR_WING,
        "wing_wall_y": [round(hw - 0.8, 2), round(hw + 0.45, 2)],
        "ends": "flush and square: the deck top is flat z 0 end to end; the deck sits in a notch on each abutment, and the path meets the vertical end face at x +/-13 at z 0; no taper, nothing above z 0 at the ends",
        "collision": {"deck": [[-HL, -hw, -0.6], [HL, hw, 0]], "rails": "one box per side: x +/-12.6, y rail_line_y +/-0.4, z 0..3.0"},
        "note": "FencePost points stand on the wing-wall tops (z 0) on the rail line, just outside the deck ends; wing walls run x 13..16.6 beside the path (path edge at |y| = path width / 2)",
    }


def build_all(emit):
    P = "park4/"
    emit(*picnic_table("PicnicTable"), P + "Snack")
    emit(*parasol("Parasol"), P + "Snack")
    emit(*light_post("LightPost"), P + "Snack")
    emit(*park_bin("ParkBin"), P + "Snack")
    emit(*bed_junction_round("BedJunctionRound"), P + "Bed")
    emit(*bed_corner_fillet("BedCornerFillet"), P + "Bed")
    emit(*bed_avenue_arc("BedAvenueArc"), P + "Bed")
    emit(*bed_avenue_straight("BedAvenueStraight"), P + "Bed")
    emit(*bed_fountain_arc("BedFountainArc"), P + "Bed")
    emit(*bridge_river("BridgeRiverAvenue", 18.0), P + "Bridge")
    emit(*bridge_river("BridgeRiverApproach", 14.0), P + "Bridge")
