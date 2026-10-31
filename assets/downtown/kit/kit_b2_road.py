# Downtown kit B2: road segments built to the kit contract (vault/design/specs/
# hud-rebuild-downtown-b.md, "Downtown kit contract"). Every piece is ONE mesh from sidewalk edge
# to sidewalk edge: asphalt, shoulders, gutters, markings, curbs and sidewalks (or verges, or
# bridge railings), so a segment costs one MeshPart.
#
# Frame: the piece starts at the origin on the carriageway centre line (asphalt top, y 0) and runs
# toward local -Z (its LookVector); +X is right. startSocket = (0, 0, 0, yaw 0); endSocket =
# (0, 0, -L, 0) for straights, the arc end for curves (radius 360 on the centre line, 16 degrees).
# Width = laneWidth x 4 lanes + 2 x 4-stud shoulders; then a 0.8 x 0.6 curb and a 12-stud sidewalk
# on each side, so the frontage line is at half + 12.8 from the centre (W17: 50.8).
#
# Seams: every piece has the SAME cross-section at both ends (asphalt y 0, curb top 0.6, sidewalk
# top 0.6, sidewalk outer edge, skirt to -0.2), so any piece joins any other with no height step.
# Lane dashes use a 16-stud period scaled to a whole number of periods per piece (straights: 16
# exactly; the curve: 100.53 / 6 = 16.76) with the dash centred in its period, so seams always
# fall in a gap and the markings run continuously across joins. Paving slabs use the same idea.
# Lane width is a parameter (PREVIEW default 17; 16 and 18 variants for the width study).

import math

from kit_b2lib import B2Builder, V, box, road_frame, sock

LANES = 4
SHOULDER = 4.0
CURB_W = 0.8
CURB_H = 0.6
SIDEWALK = 12.0
MARK_Y = 0.02
DASH_PERIOD = 16.0
DASH_FRACTION = 0.45  # 7.2 on, 8.8 off on a straight
SLAB = 8.0
RADIUS = 360.0
CURVE_DEG = 16.0
CURVE_LEN = RADIUS * math.radians(CURVE_DEG)  # 100.53 on the centre line
WATER_Y = -24.0  # harbor water level (the bridge clears it by about 19 below the deck)
DECK_D = 4.5  # deck slab depth under the asphalt


def dims(W):
    half_lanes = LANES * W / 2
    half = half_lanes + SHOULDER
    return {"W": W, "half_lanes": half_lanes, "half": half, "curb_out": half + CURB_W, "frontage": half + CURB_W + SIDEWALK}


def periods(L, p):
    n = max(1, int(round(L / p)))
    return n, L / n


# ---------------------------------------------------------------- strips along the piece
def strip(b, P, off0, off1, sl0, sl1, steps, y, sw):
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        p = [P(a, off0), P(a, off1), P(c, off1), P(c, off0)]
        b.face([V(x, y, z) for x, z in p], sw, V(0, 1, 0))


def wall(b, P, off, sl0, sl1, steps, y0, y1, sw, facing):
    """A vertical band along an offset line; facing +1 faces +offset, -1 faces -offset."""
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        (x0, z0), (x1, z1) = P(a, off), P(c, off)
        hx, hz = P((a + c) / 2, off + facing)
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        b.face([V(x0, y0, z0), V(x1, y0, z1), V(x1, y1, z1), V(x0, y1, z0)], sw, V(hx - mx, 0, hz - mz))


def steps_for(kind, L):
    return 1 if kind == "straight" else max(4, int(round(L / 12.5)))


# ---------------------------------------------------------------- carriageway and markings
def carriageway(b, P, d, L, steps, dashes=True, dash_ranges=None, edge_ranges=None):
    h, hl = d["half"], d["half_lanes"]
    strip(b, P, -hl, hl, 0, L, steps, 0.0, "asphalt")
    for s in (-1, 1):
        o0, o1 = sorted((s * hl, s * (h - 1.2)))
        strip(b, P, o0, o1, 0, L, steps, 0.0, "shoulder")
        o0, o1 = sorted((s * (h - 1.2), s * h))
        strip(b, P, o0, o1, 0, L, steps, 0.0, "asphalt_gutter")
        # solid white edge line on the lane / shoulder boundary
        o0, o1 = sorted((s * (hl - 0.3), s * (hl + 0.3)))
        for e0, e1 in edge_ranges or [(0, L)]:
            strip(b, P, o0, o1, e0, e1, max(1, int(round(steps * (e1 - e0) / L))), MARK_Y, "line_white")
    if dashes:
        n, per = periods(L, DASH_PERIOD)
        dl = per * DASH_FRACTION
        for k in range(n):
            c = per * (k + 0.5)
            if dash_ranges is not None and not any(r0 <= c <= r1 for r0, r1 in dash_ranges):
                continue
            for x in [(-LANES / 2 + 1 + i) * d["W"] for i in range(LANES - 1)]:
                strip(b, P, x - 0.25, x + 0.25, c - dl / 2, c + dl / 2, 1 if steps == 1 else 2, MARK_Y, "line_white")
    # slab sides under the curbs (hidden; they close the seam if a curb is ever omitted)
    for s in (-1, 1):
        wall(b, P, s * h, 0, L, steps, -1.0, 0.0, "asphalt_side", s)


def curb(b, P, d, s, sl0, sl1, steps):
    h = d["half"]
    top = CURB_H
    wall(b, P, s * h, sl0, sl1, steps, 0.0, top - 0.15, "curb", -s)
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        pa0, pc0 = P(a, s * h), P(c, s * h)
        pa1, pc1 = P(a, s * (h + 0.15)), P(c, s * (h + 0.15))
        rx = P((a + c) / 2, -s)[0] - P((a + c) / 2, 0)[0]
        rz = P((a + c) / 2, -s)[1] - P((a + c) / 2, 0)[1]
        b.face([V(pa0[0], top - 0.15, pa0[1]), V(pc0[0], top - 0.15, pc0[1]), V(pc1[0], top, pc1[1]), V(pa1[0], top, pa1[1])], "curb", V(rx, 1.0, rz))
    o0, o1 = sorted((s * (h + 0.15), s * d["curb_out"]))
    strip(b, P, o0, o1, sl0, sl1, steps, top, "curb_top")


def paving(b, P, d, s, sl0, sl1, steps, inner=None, outer=None):
    """Sidewalk slabs alternating two close greys, a darker back edge and a skirt."""
    top = CURB_H
    inner = d["curb_out"] if inner is None else inner
    outer = d["frontage"] if outer is None else outer
    n, per = periods(sl1 - sl0, SLAB)
    o0, o1 = sorted((s * inner, s * (outer - 0.6)))
    for k in range(n):
        a, c = sl0 + per * k, sl0 + per * (k + 1)
        strip(b, P, o0, o1, a, c, max(1, steps // n) if steps > 1 else 1, top, "sidewalk_a" if k % 2 == 0 else "sidewalk_b")
    o0, o1 = sorted((s * (outer - 0.6), s * outer))
    strip(b, P, o0, o1, sl0, sl1, steps, top, "sidewalk_edge")


def skirt(b, P, d, s, sl0, sl1, steps, y0=-0.2):
    wall(b, P, s * d["frontage"], sl0, sl1, steps, y0, CURB_H, "sidewalk_edge", s)


def verge(b, P, d, s, sl0, sl1, steps, w0, w1):
    """A planted verge between the curb and the path, width w0 at sl0 to w1 at sl1 (a taper when
    they differ), grass a hair below the curb top; the path continues outside it."""
    top = CURB_H - 0.05
    co = d["curb_out"]
    n = max(steps, 4 if w0 != w1 else 1)
    for i in range(n):
        a = sl0 + (sl1 - sl0) * i / n
        c = sl0 + (sl1 - sl0) * (i + 1) / n
        wa = w0 + (w1 - w0) * i / n
        wc = w0 + (w1 - w0) * (i + 1) / n
        pts = [P(a, s * co), P(c, s * co), P(c, s * (co + wc)), P(a, s * (co + wa))]
        b.face([V(x, top, z) for x, z in pts], "grass" if i % 2 == 0 else "grass_dark", V(0, 1, 0))
        # path between the verge and the edge strip, kept as one strip per step
        pts = [P(a, s * (co + wa)), P(c, s * (co + wc)), P(c, s * (d["frontage"] - 0.6)), P(a, s * (d["frontage"] - 0.6))]
        b.face([V(x, CURB_H, z) for x, z in pts], "sidewalk_a", V(0, 1, 0))
    o0, o1 = sorted((s * (d["frontage"] - 0.6), s * d["frontage"]))
    strip(b, P, o0, o1, sl0, sl1, steps, CURB_H, "sidewalk_edge")


def railing(b, P, d, s, sl0, sl1):
    """An open bridge railing on the outer 0.8 of the sidewalk: a stone plinth, stone posts every
    8 studs and a steel top and mid rail (see-through between posts: continuous and open)."""
    fo = d["frontage"]
    x0, x1 = fo - 0.8, fo
    n, per = periods(sl1 - sl0, 8.0)
    for k in range(n + 1):
        sl = sl0 + per * k
        x, z = P(sl, s * (fo - 0.4))
        box(b, V(x, CURB_H + 2.0, z), (0.9, 4.0, 0.9), {"side": "parapet_stone", "top": "parapet_cap", "skip_bottom": True})
    for y0, y1, sw in ((CURB_H, CURB_H + 0.8, "parapet_stone"), (CURB_H + 3.5, CURB_H + 3.9, "bridge_steel"), (CURB_H + 2.0, CURB_H + 2.25, "bridge_steel")):
        xa, za = P(sl0, s * (fo - 0.4))
        xc, zc = P(sl1, s * (fo - 0.4))
        cx, cz = (xa + xc) / 2, (za + zc) / 2
        ln = math.hypot(xc - xa, zc - za)
        yaw = math.atan2(-(xc - xa), -(zc - za))
        box(b, V(cx, (y0 + y1) / 2, cz), (0.5 if sw != "parapet_stone" else 0.8, y1 - y0, ln), {"side": sw, "skip_bottom": sw != "parapet_stone"}, yaw=yaw)
    return x0, x1


def deck_edge(b, P, d, s, sl0, sl1, steps):
    """The deck slab seen from outside: a steel fascia band, the slab underside and a girder."""
    fo = d["frontage"]
    wall(b, P, s * fo, sl0, sl1, steps, -1.2, CURB_H, "parapet_cap", s)
    wall(b, P, s * fo, sl0, sl1, steps, -DECK_D, -1.2, "bridge_steel", s)
    o0, o1 = sorted((s * 0.0, s * fo))
    for i in range(steps):
        a = sl0 + (sl1 - sl0) * i / steps
        c = sl0 + (sl1 - sl0) * (i + 1) / steps
        p = [P(a, o0), P(a, o1), P(c, o1), P(c, o0)]
        b.face([V(x, -DECK_D, z) for x, z in p], "deck_under", V(0, -1, 0))
    # a box girder under each lane pair
    for gx in (s * d["half_lanes"] * 0.5, s * (d["half"] + 4.0)):
        wall(b, P, gx - 1.5, sl0, sl1, steps, -DECK_D - 2.5, -DECK_D, "bridge_steel_dark", -1)
        wall(b, P, gx + 1.5, sl0, sl1, steps, -DECK_D - 2.5, -DECK_D, "bridge_steel_dark", 1)
        strip(b, P, gx - 1.5, gx + 1.5, sl0, sl1, steps, -DECK_D - 2.5, "bridge_steel_dark")


# ---------------------------------------------------------------- pieces
def piece(name, W, kind, L, style="plain"):
    """style: plain (urban sidewalks), park (planted 4-stud verge), verge_in (verge tapers in
    from 0 to 4 over the piece), bridge (deck: railings, fascia, underside), abutment (first half
    plain on land, second half railing over a stone abutment wall down to the water)."""
    d = dims(W)
    b = B2Builder(name)
    P = road_frame(kind, RADIUS)
    st = steps_for(kind, L)
    carriageway(b, P, d, L, st)
    for s in (-1, 1):
        curb(b, P, d, s, 0, L, st)
        if style == "plain":
            paving(b, P, d, s, 0, L, st)
            skirt(b, P, d, s, 0, L, st)
        elif style == "park":
            verge(b, P, d, s, 0, L, st, 4.0, 4.0)
            skirt(b, P, d, s, 0, L, st)
        elif style == "verge_in":
            verge(b, P, d, s, 0, L, st, 0.0, 4.0)
            skirt(b, P, d, s, 0, L, st)
        elif style == "bridge":
            paving(b, P, d, s, 0, L, st, outer=d["frontage"])
            railing(b, P, d, s, 0, L)
            deck_edge(b, P, d, s, 0, L, st)
        elif style == "abutment":
            paving(b, P, d, s, 0, L, st)
            skirt(b, P, d, s, 0, L / 2, st)
            railing(b, P, d, s, L / 2, L)
            # the embankment wall: stone from the sidewalk edge down to the water, second half
            wall(b, P, s * d["frontage"], L / 2, L, st, WATER_Y, CURB_H, "quay_stone", s)
            wall(b, P, s * d["frontage"], L / 2, L, st, WATER_Y, WATER_Y + 2.0, "quay_dark", s)
    if style == "abutment":
        # the abutment face under the bridge's first span (faces the water ahead, -Z)
        fo = d["frontage"]
        b.face([V(-fo, WATER_Y, -L), V(fo, WATER_Y, -L), V(fo, -0.2, -L), V(-fo, -0.2, -L)], "quay_stone", V(0, 0, -1))
        b.face([V(-fo, -1.6, -L - 0.4), V(fo, -1.6, -L - 0.4), V(fo, -0.2, -L - 0.4), V(-fo, -0.2, -L - 0.4)], "quay_top", V(0, 0, -1))
    if kind == "straight":
        end = sock((0, 0, -L), 0.0)
    else:
        sgn = 1.0 if kind == "curveR" else -1.0
        t = math.radians(CURVE_DEG)
        end = sock((sgn * RADIUS * (1 - math.cos(t)), 0, -RADIUS * math.sin(t)), -sgn * CURVE_DEG)
    kinds = {"straight": "Straight", "curveR": "CurveR", "curveL": "CurveL"}
    k = {"bridge": "BridgeDeck", "abutment": "Transition", "verge_in": "Transition"}.get(style, kinds[kind])
    n, per = periods(L, DASH_PERIOD)
    meta = {
        "family": "Road",
        "kind": k,
        "style": style,
        "length": round(L, 3),
        "laneWidth": W,
        "lanes": LANES,
        "shoulder": SHOULDER,
        "half_width": d["half"],
        "curb": [CURB_W, CURB_H],
        "sidewalk": SIDEWALK,
        "frontage_offset": d["frontage"],
        "dash": {"period": round(per, 3), "on": round(per * DASH_FRACTION, 3), "centred": True},
        "pivot": "startSocket: carriageway centre line at the piece start, asphalt top (y 0), facing -Z",
        "sockets": {"start": sock((0, 0, 0)), "end": end},
        "lod": "near",
        "district": "any",
        "material": "SmoothPlastic (asphalt-look via palette)",
    }
    if kind != "straight":
        meta["radius"] = RADIUS
        meta["angle_deg"] = CURVE_DEG
    if style in ("bridge", "abutment"):
        meta["water_y"] = WATER_Y
        meta["deck_depth"] = DECK_D
        meta["sockets"]["pier"] = sock((0, -DECK_D - 2.5, -L / 2 if style == "bridge" else -L))
        meta["railing"] = "open: stone posts every 8, steel top rail at 4.5 above the sidewalk"
    if style in ("park", "verge_in"):
        meta["verge"] = "4-stud planted verge inside the 12-stud sidewalk band" if style == "park" else "verge tapers 0 -> 4 along the piece"
    return b, meta


def intersection(name, W, cross=30.0):
    """A 96-long piece with a two-lane cross street (30 wide) centred at sl 48, crossing at 90
    degrees; corner sidewalks with 6-stud fillets; yellow zebra crossings (the outline's yellow
    crosswalk stripes) before and after the junction box; stop bars; the cross street's yellow
    centre dashes and white edge lines out to the arm ends."""
    d = dims(W)
    b = B2Builder(name)
    L = 96.0
    P = road_frame("straight")
    h, hl, fo = d["half"], d["half_lanes"], d["frontage"]
    zc = -L / 2
    ch = cross / 2
    F = 6.0  # curb fillet radius
    ARM = math.ceil((fo + 40.0) / 8.0) * 8.0
    m0, m1 = L / 2 - ch, L / 2 + ch  # the mouth on the main road (sl)
    carriageway(b, P, d, L, 1, dash_ranges=[(0, m0 - 14), (m1 + 14, L)], edge_ranges=[(0, m0 - F), (m1 + F, L)])
    up = V(0, 1, 0)
    for sx in (-1, 1):
        # cross-street arm asphalt and its slab end
        x0, x1 = sorted((sx * h, sx * ARM))
        b.face([V(x0, 0, zc + ch), V(x1, 0, zc + ch), V(x1, 0, zc - ch), V(x0, 0, zc - ch)], "asphalt", up)
        b.face([V(sx * ARM, -1, zc - ch), V(sx * ARM, -1, zc + ch), V(sx * ARM, 0, zc + ch), V(sx * ARM, 0, zc - ch)], "asphalt_side", V(sx, 0, 0))
        # yellow centre dashes (6 on, 6 off) and white edge lines on the arm
        x = h + 10.0
        while x + 6 <= ARM:
            a, c = sorted((sx * x, sx * (x + 6)))
            b.face([V(a, MARK_Y, zc - 0.3), V(c, MARK_Y, zc - 0.3), V(c, MARK_Y, zc + 0.3), V(a, MARK_Y, zc + 0.3)], "line_yellow", up)
            x += 12.0
        for sz in (-1, 1):
            a, c = sorted((sx * (h + F + 1.0), sx * ARM))
            z0, z1 = sorted((zc + sz * (ch - 1.1), zc + sz * (ch - 0.5)))
            b.face([V(a, MARK_Y, z0), V(c, MARK_Y, z0), V(c, MARK_Y, z1), V(a, MARK_Y, z1)], "line_white", up)
        # a zebra across each arm, just outside the junction box
        for k in range(5):
            z = zc - ch + 1.5 + (cross - 3.0) * (k + 0.5) / 5
            a, c = sorted((sx * (h + 3.0), sx * (h + 11.0)))
            b.face([V(a, MARK_Y, z - 1.25), V(c, MARK_Y, z - 1.25), V(c, MARK_Y, z + 1.25), V(a, MARK_Y, z + 1.25)], "line_yellow", up)
        # corner sidewalks (near and far) with a filleted curb
        for sz in (-1, 1):
            corner(b, d, sx, sz, zc, ch, F, ARM, L)
    # zebras across the main road before and after the box, with stop bars
    nb = max(8, int(round(2 * hl / 5.6)))
    pitch = 2 * hl / nb
    for z0, z1, stop in ((-(m0 - 12), -(m0 - 4), -(m0 - 13.5)), (-(m1 + 4), -(m1 + 12), None)):
        for i in range(nb):
            x = -hl + pitch * (i + 0.5)
            b.face([V(x - 1.25, MARK_Y, z0), V(x + 1.25, MARK_Y, z0), V(x + 1.25, MARK_Y, z1), V(x - 1.25, MARK_Y, z1)], "line_yellow", up)
        if stop is not None:
            b.face([V(-hl, MARK_Y, stop + 0.5), V(hl, MARK_Y, stop + 0.5), V(hl, MARK_Y, stop - 0.5), V(-hl, MARK_Y, stop - 0.5)], "line_white", up)
    sockets = {
        "start": sock((0, 0, 0)),
        "end": sock((0, 0, -L)),
        "cross_left": sock((-ARM, 0, zc), 90.0),
        "cross_right": sock((ARM, 0, zc), -90.0),
    }
    for sx, tag in ((1, "R"), (-1, "L")):
        sockets[f"signal_near_{tag}"] = sock((sx * (h + 2.5), CURB_H, -(m0 - 3.0)), 180.0)
        sockets[f"signal_far_{tag}"] = sock((sx * (h + 2.5), CURB_H, -(m1 + 3.0)), 0.0)
        sockets[f"street_sign_{tag}"] = sock((sx * (fo - 3.0), CURB_H, -(m0 - 5.0)))
    meta = {
        "family": "Road",
        "kind": "Intersection",
        "length": L,
        "laneWidth": W,
        "lanes": LANES,
        "shoulder": SHOULDER,
        "half_width": h,
        "frontage_offset": fo,
        "cross_width": cross,
        "cross_centre_sl": L / 2,
        "arm_reach": ARM,
        "fillet": F,
        "pivot": "startSocket: carriageway centre line at the piece start, asphalt top, facing -Z",
        "sockets": sockets,
        "lod": "near",
        "district": "any",
        "note": "lots stop at the corner sidewalks (sl < 33 - 12.8 and sl > 63 + 12.8 on the main road); corner-L/R lot variants sit on them",
    }
    return b, meta


def corner(b, d, sx, sz, zc, ch, F, ARM, L):
    """One corner sidewalk: the main-road curb runs from the piece end to the fillet, turns along
    the cross-street curb out to the arm end; paving fills to the frontage lines."""
    h, co, fo = d["half"], d["curb_out"], d["frontage"]
    top = CURB_H
    ez = zc + sz * ch  # the cross street's curb line on this side of the box
    end_z = 0.0 if sz > 0 else -L  # piece end on this side
    # curb line (road side) as a polyline, from the piece end along the main road, round the
    # fillet, then along the cross street to the arm end
    cxf, czf = sx * (h + F), ez + sz * F
    line = [(sx * h, end_z), (sx * h, czf)]
    for k in range(1, 6):
        a = (math.pi / 2) * k / 6
        line.append((cxf - sx * F * math.cos(a), czf - sz * F * math.sin(a)))
    line += [(cxf, ez), (sx * ARM, ez)]

    def offset(pts, dist):
        out = []
        for i, (x, z) in enumerate(pts):
            if i == 0:
                out.append((x + sx * dist, z))
            elif i == len(pts) - 1:
                out.append((x, z + sz * dist))
            else:
                # radial from the fillet centre (or the straight normal at the fillet start/end)
                vx, vz = x - cxf, z - czf
                ln = math.hypot(vx, vz) or 1.0
                out.append((x - vx / ln * dist, z - vz / ln * dist))
        return out

    # asphalt in the fillet wedge between the square corner and the curved curb
    arc = line[1:-1]
    for k in range(len(arc) - 1):
        b.face([V(sx * h, 0, ez), V(arc[k][0], 0, arc[k][1]), V(arc[k + 1][0], 0, arc[k + 1][1])], "asphalt", V(0, 1, 0))
    inner = offset(line, CURB_W)
    chamf = offset(line, 0.15)
    for i in range(len(line) - 1):
        (ax, az), (qx, qz) = line[i], line[i + 1]
        road = V(-(sx), 0, 0) if i == 0 else (V(0, 0, -sz) if i == len(line) - 2 else V((ax + qx) / 2 - cxf, 0, (az + qz) / 2 - czf))
        b.face([V(ax, 0, az), V(qx, 0, qz), V(qx, top - 0.15, qz), V(ax, top - 0.15, az)], "curb", road)
        (ex, ez2), (fx, fz) = chamf[i], chamf[i + 1]
        b.face([V(ax, top - 0.15, az), V(qx, top - 0.15, qz), V(fx, top, fz), V(ex, top, ez2)], "curb", road + V(0, 1, 0))
        (gx, gz), (hx, hz) = inner[i], inner[i + 1]
        b.face([V(ex, top, ez2), V(fx, top, fz), V(hx, top, hz), V(gx, top, gz)], "curb_top", V(0, 1, 0))
    # paving: the inner curb line, then the outer boundary (cross-street frontage, the corner of
    # the two frontage lines, the main-road frontage back to the piece end)
    outer = [(sx * ARM, ez + sz * (CURB_W + SIDEWALK)), (sx * fo, ez + sz * (CURB_W + SIDEWALK)), (sx * fo, end_z)]
    b.face([V(x, top, z) for x, z in inner + outer], "sidewalk_a", V(0, 1, 0))
    ring = [(sx * ARM, ez)] + outer
    for i in range(len(ring) - 1):
        (ax, az), (qx, qz) = ring[i], ring[i + 1]
        out = V(sx, 0, 0) if i != 1 else V(0, 0, sz)
        b.face([V(ax, -0.2, az), V(qx, -0.2, qz), V(qx, top, qz), V(ax, top, az)], "sidewalk_edge", out)


def build_all(emit, widths=(16, 17, 18)):
    for W in widths:
        tag = f"L4W{W}"
        emit(*piece(f"B2_Road_Straight96_{tag}", W, "straight", 96.0))
        emit(*piece(f"B2_Road_Straight192_{tag}", W, "straight", 192.0))
        emit(*piece(f"B2_Road_CurveR_{tag}", W, "curveR", CURVE_LEN))
        emit(*piece(f"B2_Road_CurveL_{tag}", W, "curveL", CURVE_LEN))
        emit(*intersection(f"B2_Road_Intersection96_{tag}", W))
        emit(*piece(f"B2_Road_BridgeDeck96_{tag}", W, "straight", 96.0, "bridge"))
        emit(*piece(f"B2_Road_BridgeDeck192_{tag}", W, "straight", 192.0, "bridge"))
        emit(*piece(f"B2_Road_Abutment96_{tag}", W, "straight", 96.0, "abutment"))
        emit(*piece(f"B2_Road_TransitionVerge96_{tag}", W, "straight", 96.0, "verge_in"))
        emit(*piece(f"B2_Road_Park96_{tag}", W, "straight", 96.0, "park"))
        emit(*piece(f"B2_Road_Park192_{tag}", W, "straight", 192.0, "park"))
