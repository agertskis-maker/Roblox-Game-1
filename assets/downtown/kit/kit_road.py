# Downtown kit: road pieces, shared by directions A, B and C (fixture values from fixture.py).
# Road pieces pivot at the START of the piece on the carriageway centreline (asphalt top, y 0)
# and run toward local -Z (their LookVector), so a layout chains them by s: piece k starts at
# s = 20k with yaw = fixture.yaw_along(s). Curves bend right (centre of curvature at local +X).
# Markings are top-only quads 0.02 above the asphalt. Sidewalk pieces include the curb; the
# right-side straight piece is reused on the left with yaw + 180 placed at the piece's end.

import math

import fixture as F
from kitlib import Builder, V, box, prism

H = F.HALF
SL = F.PIECE
MARK_Y = 0.02
EDGE_IN, EDGE_OUT = H - 1.1, H - 0.5  # white edge lines, 0.6 wide, 0.5 in from the curb
DASH_X = [-F.LANE_W, 0.0, F.LANE_W]
DASH_W = 0.5


def frame(kind):
    """Local (x, z) of road distance sl (0..20) and lateral offset off (+ right)."""
    if kind == "straight":
        return lambda sl, off: (off, -sl)
    R = F.RADIUS

    def P(sl, off):
        t = sl / R
        return (R - (R - off) * math.cos(t), -(R - off) * math.sin(t))

    return P


def strip(b, P, off0, off1, sl0, sl1, steps, y, swatch, alt=None, alt_len=None):
    """A flat band between two offsets over sl0..sl1, facing up."""
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        sw = swatch
        if alt and alt_len:
            sw = alt[int(((a + c) / 2) // alt_len) % len(alt)]
        p = [P(a, off0), P(a, off1), P(c, off1), P(c, off0)]
        b.face([V(x, y, z) for x, z in p], sw, V(0, 1, 0))


def wall(b, P, off, sl0, sl1, steps, y0, y1, swatch, facing):
    """A vertical band along an offset line; facing = +1 faces +offset, -1 faces -offset."""
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        (x0, z0), (x1, z1) = P(a, off), P(c, off)
        (hx, hz) = P((a + c) / 2, off + facing)
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        b.face([V(x0, y0, z0), V(x1, y0, z1), V(x1, y1, z1), V(x0, y1, z0)], swatch, V(hx - mx, 0, hz - mz))


def asphalt(name, kind):
    b = Builder(name)
    P = frame(kind)
    st = 1 if kind == "straight" else 4
    strip(b, P, -H, -H + 1.4, 0, SL, st, 0.0, "asphalt_gutter")
    strip(b, P, -H + 1.4, H - 1.4, 0, SL, st, 0.0, "asphalt")
    strip(b, P, H - 1.4, H, 0, SL, st, 0.0, "asphalt_gutter")
    # slab sides under the curbs, so no gap shows at a curb seam
    wall(b, P, -H, 0, SL, st, -1.0, 0.0, "asphalt_side", -1)
    wall(b, P, H, 0, SL, st, -1.0, 0.0, "asphalt_side", 1)
    return b, {"pivot": "start of piece, carriageway centre, asphalt top", "length": SL, "width": 2 * H, "kind": kind, "material": "Asphalt-look Plastic"}


def marks(name, kind):
    b = Builder(name)
    P = frame(kind)
    st = 1 if kind == "straight" else 4
    for sgn in (-1, 1):
        o0, o1 = sorted((sgn * EDGE_IN, sgn * EDGE_OUT))
        strip(b, P, o0, o1, 0, SL, st, MARK_Y, "line_white")
    # 10 on, 10 off, the dash centred in the piece so joins never split a dash
    for x in DASH_X:
        strip(b, P, x - DASH_W / 2, x + DASH_W / 2, 5.0, 15.0, 1 if kind == "straight" else 2, MARK_Y, "line_white")
    return b, {"pivot": "start of piece, carriageway centre", "length": SL, "height_above_asphalt": MARK_Y, "kind": kind}


def sidewalk_band(b, P, side, sl0, sl1, steps, slab=5.0):
    """Curb (chamfered) and sidewalk on one side between sl0 and sl1."""
    s = side
    c0, c1 = H, H + F.CURB_W
    w1 = F.FRONTAGE
    top = F.CURB_H
    # curb face, chamfer and top
    wall(b, P, s * c0, sl0, sl1, steps, 0.0, top - 0.15, "curb", -s)
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        pa0, pc0 = P(a, s * c0), P(c, s * c0)
        pa1, pc1 = P(a, s * (c0 + 0.15)), P(c, s * (c0 + 0.15))
        q =[V(pa0[0], top - 0.15, pa0[1]), V(pc0[0], top - 0.15, pc0[1]), V(pc1[0], top, pc1[1]), V(pa1[0], top, pa1[1])]
        # chamfer faces up and toward the road
        rx, rz = P((a + c) / 2, -s)[0] - P((a + c) / 2, 0)[0], P((a + c) / 2, -s)[1] - P((a + c) / 2, 0)[1]
        b.face(q, "curb", V(rx, 1.0, rz))
    o0, o1 = sorted((s * (c0 + 0.15), s * c1))
    strip(b, P, o0, o1, sl0, sl1, steps, top, "curb_top")
    # sidewalk slabs, alternating two close greys every 5 studs, with a darker back edge
    o0, o1 = sorted((s * c1, s * (w1 - 0.6)))
    for i in range(int(round((sl1 - sl0) / slab))):
        a = sl0 + i * slab
        c = min(sl1, a + slab)
        sub = max(1, steps * int(slab) // int(sl1 - sl0)) if steps > 1 else 1
        strip(b, P, o0, o1, a, c, sub, top, "sidewalk_a" if i % 2 == 0 else "sidewalk_b")
    o0, o1 = sorted((s * (w1 - 0.6), s * w1))
    strip(b, P, o0, o1, sl0, sl1, steps, top, "sidewalk_edge")
    # outer skirt down to the lot ground
    wall(b, P, s * w1, sl0, sl1, steps, -0.2, top, "sidewalk_edge", s)


def sidewalk(name, kind, side):
    b = Builder(name)
    P = frame(kind)
    sidewalk_band(b, P, side, 0, SL, 1 if kind == "straight" else 4)
    return b, {
        "pivot": "start of piece, carriageway centre",
        "length": SL,
        "side": "right" if side > 0 else "left",
        "curb": [F.CURB_W, F.CURB_H],
        "sidewalk_width": F.SIDEWALK_W,
        "note": "SidewalkStraight20 is the right side; for the left side place it with yaw + 180 at the piece end" if kind == "straight" else "built in place for its side of the curve",
    }


def curb_only(name):
    b = Builder(name)
    # 20 long, pivot at the road-side bottom edge's start; the curb occupies x 0..0.8
    box(b, V(0.4, F.CURB_H / 2, -SL / 2), (F.CURB_W, F.CURB_H, SL), {"top": "curb_top", "side": "curb"})
    return b, {"pivot": "road-side bottom edge, start", "length": SL, "size": [F.CURB_W, F.CURB_H, SL]}


# ---------------------------------------------------------------- intersection
CROSS_HALF = F.CROSS_WIDTH / 2  # 15
ARM = 140.0  # the cross street is modelled out to x = +-140
FILLET = 5.0


def intersection(name):
    """Asphalt for the junction box and both cross-street arms. Pivot: junction centre (s 265),
    main road along local -Z (s 240 at z +25, s 290 at z -25)."""
    b = Builder(name)
    up = V(0, 1, 0)
    b.face([V(-H, 0, 25), V(H, 0, 25), V(H, 0, -25), V(-H, 0, -25)], "asphalt", up)
    for sx in (-1, 1):
        x0, x1 = sx * H, sx * ARM
        b.face([V(x0, 0, CROSS_HALF), V(x1, 0, CROSS_HALF), V(x1, 0, -CROSS_HALF), V(x0, 0, -CROSS_HALF)], "asphalt", up)
        # gutters along the cross street's curbs
        for sz in (-1, 1):
            z0, z1 = sz * (CROSS_HALF - 1.2), sz * CROSS_HALF
            b.face([V(x0 + sx * FILLET, 0.001, z0), V(x1, 0.001, z0), V(x1, 0.001, z1), V(x0 + sx * FILLET, 0.001, z1)], "asphalt_gutter", up)
            # the fillet between the square corner and the rounded curb
            cx, cz = sx * (H + FILLET), sz * (CROSS_HALF + FILLET)
            corner = V(sx * H, 0, sz * CROSS_HALF)
            arc = []
            for k in range(5):
                a = k / 4 * (math.pi / 2)
                arc.append(V(cx - sx * FILLET * math.cos(a), 0, cz - sz * FILLET * math.sin(a)))
            for k in range(4):
                b.face([corner, arc[k], arc[k + 1]], "asphalt", up)
        # arm end face
        b.face([V(x1, -1, -CROSS_HALF), V(x1, -1, CROSS_HALF), V(x1, 0, CROSS_HALF), V(x1, 0, -CROSS_HALF)], "asphalt_side", V(sx, 0, 0))
    return b, {"pivot": "junction centre on the carriageway centreline, asphalt top", "main_length": 50, "cross_width": F.CROSS_WIDTH, "arm_reach": ARM}


def intersection_marks(name):
    b = Builder(name)
    up = V(0, 1, 0)
    y = MARK_Y
    # main road edge lines either side of the mouth
    for sx in (-1, 1):
        u0, u1 = sorted((sx * EDGE_IN, sx * EDGE_OUT))
        for z0, z1 in ((CROSS_HALF, 25.0), (-25.0, -CROSS_HALF)):
            b.face([V(u0, y, z0), V(u1, y, z0), V(u1, y, z1), V(u0, y, z1)], "line_white", up)
    # no lane dashes inside the junction (s 240 to 290); the zebra fills s 240 to 250
    # cross street: yellow centre dashes (6 on, 6 off), white edge lines, stop bars
    for sx in (-1, 1):
        x = H + 8.0
        while x + 6 <= ARM:
            x0, x1 = sorted((sx * x, sx * (x + 6)))
            b.face([V(x0, y, -0.3), V(x1, y, -0.3), V(x1, y, 0.3), V(x0, y, 0.3)], "line_yellow", up)
            x += 12
        for sz in (-1, 1):
            z0, z1 = sorted((sz * (CROSS_HALF - 1.1), sz * (CROSS_HALF - 0.5)))
            x0, x1 = sorted((sx * (H + FILLET + 1), sx * ARM))
            b.face([V(x0, y, z0), V(x1, y, z0), V(x1, y, z1), V(x0, y, z1)], "line_white", up)
        # stop bar across the inbound half of each arm (the half nearer the start of the road)
        x0, x1 = sorted((sx * (H + 3.0), sx * (H + 4.0)))
        zs = (0.5, CROSS_HALF - 1.2) if sx > 0 else (-(CROSS_HALF - 1.2), -0.5)
        b.face([V(x0, y, zs[0]), V(x1, y, zs[0]), V(x1, y, zs[1]), V(x0, y, zs[1])], "line_white", up)
    return b, {"pivot": "junction centre", "height_above_asphalt": y}


def offset_polyline(pts, dist, side):
    """Offset a 2D polyline by dist to its left (side +1) or right (side -1), mitred."""
    out = []
    n = len(pts)
    for i in range(n):
        normals = []
        for j in (i - 1, i):
            if 0 <= j < n - 1:
                (ax, az), (cx, cz) = pts[j], pts[j + 1]
                dx, dz = cx - ax, cz - az
                L = math.hypot(dx, dz)
                normals.append((-dz / L * side, dx / L * side))
        nx = sum(p[0] for p in normals)
        nz = sum(p[1] for p in normals)
        L = math.hypot(nx, nz)
        nx, nz = nx / L, nz / L
        cosh = nx * normals[0][0] + nz * normals[0][1]
        k = dist / max(cosh, 0.3)
        out.append((pts[i][0] + nx * k, pts[i][1] + nz * k))
    return out


def corner(name, mirror=False):
    """The near-right corner sidewalk of the junction (mirror for the near-left one). Placed
    with the junction's pivot and yaw; rotate 180 degrees for the far corners."""
    b = Builder(name)
    top = F.CURB_H
    cx, cz = H + FILLET, CROSS_HALF + FILLET
    B = [(H, 25.0), (H, cz)]
    for k in range(1, 8):
        a = math.pi + k / 8 * (math.pi / 2)
        B.append((cx + FILLET * math.cos(a), cz + FILLET * math.sin(a)))
    B += [(cx, CROSS_HALF), (ARM, CROSS_HALF)]
    Bc = offset_polyline(B, 0.15, 1)
    Bi = offset_polyline(B, F.CURB_W, 1)
    # curb face (toward the road), chamfer and curb top
    for i in range(len(B) - 1):
        (ax, az), (qx, qz) = B[i], B[i + 1]
        dx, dz = qx - ax, qz - az
        road = V(dz, 0, -dx)  # right of travel = the road side
        b.face([V(ax, 0, az), V(qx, 0, qz), V(qx, top - 0.15, qz), V(ax, top - 0.15, az)], "curb", road)
        (ex, ez), (fx, fz) = Bc[i], Bc[i + 1]
        b.face([V(ax, top - 0.15, az), V(qx, top - 0.15, qz), V(fx, top, fz), V(ex, top, ez)], "curb", road + V(0, 1, 0))
        (gx, gz), (hx, hz) = Bi[i], Bi[i + 1]
        b.face([V(ex, top, ez), V(fx, top, fz), V(hx, top, hz), V(gx, top, gz)], "curb_top", V(0, 1, 0))
    outer = [(ARM, CROSS_HALF + F.CURB_W + F.SIDEWALK_W), (F.FRONTAGE, CROSS_HALF + F.CURB_W + F.SIDEWALK_W), (F.FRONTAGE, 25.0)]
    b.face([V(x, top, z) for x, z in Bi + outer], "sidewalk_a", V(0, 1, 0))
    # skirts: arm end, back edge, lot edge
    ring = [(ARM, CROSS_HALF)] + outer
    for i in range(len(ring) - 1):
        (ax, az), (qx, qz) = ring[i], ring[i + 1]
        mx, mz = (ax + qx) / 2, (az + qz) / 2
        out = V(1, 0, 0) if i == 0 else (V(0, 0, 1) if i == 1 else V(1, 0, 0))
        b.face([V(ax, -0.2, az), V(qx, -0.2, qz), V(qx, top, qz), V(ax, top, az)], "sidewalk_edge", out)
    return b, {"pivot": "junction centre", "corner": "near-left" if mirror else "near-right", "fillet": FILLET, "mirror_of": "SidewalkCornerA" if mirror else None}


def zebra(name):
    """Six bars of 2.5 x 10 across the carriageway (yellow, per the outline's yellow crosswalk
    stripes), evenly spread over the 50-stud width. Pivot: crossing centre."""
    b = Builder(name)
    up = V(0, 1, 0)
    pitch = 2 * H / 6
    for i in range(6):
        x = -H + pitch * (i + 0.5)
        b.face([V(x - 1.25, MARK_Y, -5), V(x + 1.25, MARK_Y, -5), V(x + 1.25, MARK_Y, 5), V(x - 1.25, MARK_Y, 5)], "line_yellow", up)
    # thin white edge bars framing the crossing
    for z in (-5.6, 5.6):
        b.face([V(-H + 1, MARK_Y, z - 0.25), V(H - 1, MARK_Y, z - 0.25), V(H - 1, MARK_Y, z + 0.25), V(-H + 1, MARK_Y, z + 0.25)], "line_white", up)
    return b, {"pivot": "crossing centre", "bars": 6, "bar_size": [2.5, 10]}


def build_all(emit):
    P = "road"
    emit(*asphalt("RoadStraight20", "straight"), P, "common")
    emit(*asphalt("RoadCurve20", "curve"), P, "common")
    emit(*marks("MarksStraight20", "straight"), P, "common")
    emit(*marks("MarksCurve20", "curve"), P, "common")
    emit(*sidewalk("SidewalkStraight20", "straight", 1), P, "common")
    emit(*sidewalk("SidewalkCurveInner20", "curve", 1), P, "common")
    emit(*sidewalk("SidewalkCurveOuter20", "curve", -1), P, "common")
    emit(*curb_only("Curb20"), P, "common")
    emit(*intersection("RoadIntersection"), P, "common")
    emit(*intersection_marks("MarksIntersection"), P, "common")
    emit(*corner("SidewalkCornerA"), P, "common")
    emit(*corner("SidewalkCornerB", mirror=True), P, "common", True)
    emit(*zebra("CrosswalkZebra"), P, "common")
