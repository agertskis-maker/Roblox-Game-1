# Island kit: the portal lock and requirement sign (Lane 3, Task 3), in the kit's smooth faceted
# language: chamfered boards, rounded rims, low side counts, no studs.
#   ChainLink        one oval link, origin at the link centre, long axis +x, lying in the xy plane.
#   PadlockBody      origin at the body centre; front (keyhole) faces -y.
#   PadlockShackle   origin at the bottom of the LEFT leg (the hinge), so it can lift and swing
#                    open about z; the right leg is shorter and leaves its socket after a small lift.
#   ChainAnchorPost  a slim support post, ground line z 0, two eyelets on its +x (inner) side.
#   PortalSign       three stacked planks on two posts, front faces -y, ground line z 0.
# Meta points are in Blender mesh-local axes (x right, y back, z up, front faces -y), relative to
# the mesh origin. Roblox mesh-local is (x, z, -y); a MeshPart is centred on its bounds, so subtract
# the bounds centre from the manifest before placing anything on a MeshPart.

import math

from mathutils import Vector

from kitlib import Builder


# ---------------------------------------------------------------- shared helpers (also kit_plot)
def newell(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        a, c = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - c.y) * (a.z + c.z)
        n.y += (a.z - c.z) * (a.x + c.x)
        n.z += (a.x - c.x) * (a.y + c.y)
    return n


def oface(b, pts, swatch, inside):
    """A planar face wound so its normal points away from the point `inside`."""
    v = [Vector(p) for p in pts]
    centroid = sum(v, Vector((0, 0, 0))) / len(v)
    if newell(v).dot(centroid - Vector(inside)) < 0:
        v.reverse()
    b.face(v, swatch)


def tface(b, pts, swatch, toward):
    """A planar face wound so its normal points toward the point `toward` (hole walls)."""
    v = [Vector(p) for p in pts]
    centroid = sum(v, Vector((0, 0, 0))) / len(v)
    if newell(v).dot(Vector(toward) - centroid) < 0:
        v.reverse()
    b.face(v, swatch)


def cbox(b, centre, size, swatch, c=0.06, front=None, edge=None, back=None, top=None):
    """A box with chamfered edges and corners (44 triangles). front / back / top override the
    swatch of the -y / +y / +z faces, edge the swatch of the chamfers."""
    centre = Vector(centre)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    c = min(c, hx * 0.45, hy * 0.45, hz * 0.45)
    e = edge or swatch

    def P(x, y, z):
        return centre + Vector((x, y, z))

    sides = {
        (1, 0, 0): swatch, (-1, 0, 0): swatch, (0, 1, 0): back or swatch,
        (0, -1, 0): front or swatch, (0, 0, 1): top or swatch, (0, 0, -1): swatch,
    }
    for (nx, ny, nz), sw in sides.items():
        pts = []
        for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            if nx:
                pts.append(P(nx * hx, s * (hy - c), t * (hz - c)))
            elif ny:
                pts.append(P(s * (hx - c), ny * hy, t * (hz - c)))
            else:
                pts.append(P(s * (hx - c), t * (hy - c), nz * hz))
        oface(b, pts, sw, centre)
    for s in (-1, 1):
        for t in (-1, 1):
            # edges along x, y and z
            oface(b, [P(-(hx - c), s * hy, t * (hz - c)), P(hx - c, s * hy, t * (hz - c)),
                      P(hx - c, s * (hy - c), t * hz), P(-(hx - c), s * (hy - c), t * hz)], e, centre)
            oface(b, [P(s * hx, -(hy - c), t * (hz - c)), P(s * hx, hy - c, t * (hz - c)),
                      P(s * (hx - c), hy - c, t * hz), P(s * (hx - c), -(hy - c), t * hz)], e, centre)
            oface(b, [P(s * hx, t * (hy - c), -(hz - c)), P(s * hx, t * (hy - c), hz - c),
                      P(s * (hx - c), t * hy, hz - c), P(s * (hx - c), t * hy, -(hz - c))], e, centre)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                oface(b, [P(sx * hx, sy * (hy - c), sz * (hz - c)), P(sx * (hx - c), sy * hy, sz * (hz - c)),
                          P(sx * (hx - c), sy * (hy - c), sz * hz)], e, centre)


def frames(path, closed):
    """Parallel-transport frames (tangent, normal, binormal) along a polyline."""
    n = len(path)
    tans = []
    for i in range(n):
        if closed:
            t = path[(i + 1) % n] - path[i - 1]
        elif i == 0:
            t = path[1] - path[0]
        elif i == n - 1:
            t = path[-1] - path[-2]
        else:
            t = path[i + 1] - path[i - 1]
        tans.append(t.normalized())
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    nor = tans[0].cross(ref).normalized()
    out = []
    for t in tans:
        nor = (nor - t * nor.dot(t)).normalized()
        out.append((t, nor, t.cross(nor).normalized()))
    return out


def sweep(b, path, radius, sides, swatch, closed=False, caps=True, phase=0.0):
    """A round-section tube along a polyline without twisting; flat caps on open ends."""
    path = [Vector(p) for p in path]
    fr = frames(path, closed)
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(path)
    rings = []
    for p, (t, nor, bi), r in zip(path, fr, radii):
        rings.append([p + (nor * math.cos(phase + 2 * math.pi * k / sides) + bi * math.sin(phase + 2 * math.pi * k / sides)) * r for k in range(sides)])
    count = len(path) if closed else len(path) - 1
    for i in range(count):
        j = (i + 1) % len(path)
        mid = (path[i] + path[j]) / 2
        for k in range(sides):
            k2 = (k + 1) % sides
            oface(b, [rings[i][k], rings[i][k2], rings[j][k2], rings[j][k]], swatch, mid)
    if caps and not closed:
        oface(b, rings[0], swatch, path[1])
        oface(b, rings[-1], swatch, path[-2])
    return rings


def torus(b, centre, axis_u, axis_v, radius, wire, segments, sides, swatch, rx=None, ry=None):
    """A closed ring in the plane of axis_u / axis_v (optionally oval: rx, ry centreline radii)."""
    rx = radius if rx is None else rx
    ry = radius if ry is None else ry
    path = [Vector(centre) + Vector(axis_u) * math.cos(2 * math.pi * k / segments) * rx
            + Vector(axis_v) * math.sin(2 * math.pi * k / segments) * ry for k in range(segments)]
    sweep(b, path, wire, sides, swatch, closed=True)


def layered(b, layers, swatches, inside, cap_first=None, cap_last=None):
    """Bands between profile rings of equal length (a lofted convex solid)."""
    for i in range(len(layers) - 1):
        a, c = layers[i], layers[i + 1]
        n = len(a)
        for k in range(n):
            k2 = (k + 1) % n
            oface(b, [a[k], a[k2], c[k2], c[k]], swatches[i], inside)
    if cap_first:
        oface(b, layers[0], cap_first, inside)
    if cap_last:
        oface(b, layers[-1], cap_last, inside)


def rrect(w, h, r_top, r_bot, seg=3, cx=0.0, cz=0.0):
    """A rounded rectangle in the xz plane, counter-clockwise, (seg + 1) points per corner."""
    pts = []
    corners = ((w / 2 - r_top, h / 2 - r_top, r_top, 0.0), (-w / 2 + r_top, h / 2 - r_top, r_top, 90.0),
               (-w / 2 + r_bot, -h / 2 + r_bot, r_bot, 180.0), (w / 2 - r_bot, -h / 2 + r_bot, r_bot, 270.0))
    for x, z, r, a0 in corners:
        for k in range(seg + 1):
            a = math.radians(a0 + 90.0 * k / seg)
            pts.append((cx + x + math.cos(a) * r, cz + z + math.sin(a) * r))
    return pts


def at_y(pts2, y):
    return [Vector((x, y, z)) for x, z in pts2]


def cyl(b, base, height, radius, sides, swatch, r_top=None, top=True, bottom=False, axis=Vector((0, 0, 1)), top_sw=None):
    axis = Vector(axis).normalized()
    base = Vector(base)
    rt = radius if r_top is None else r_top
    ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))
    u = axis.cross(ref).normalized()
    v = axis.cross(u).normalized()
    lo = [base + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * radius for k in range(sides)]
    hi = [base + axis * height + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * rt for k in range(sides)]
    inside = base + axis * height / 2
    layered(b, [lo, hi], [swatch], inside, cap_first=swatch if bottom else None, cap_last=(top_sw or swatch) if top else None)


def dome(b, base, radius, height, sides, rings_n, swatch, axis_z=True):
    """A rounded cap: a faceted half-ellipsoid standing on z = base.z."""
    base = Vector(base)
    layers = []
    for i in range(rings_n):
        a = (math.pi / 2) * i / rings_n
        r = radius * math.cos(a)
        z = height * math.sin(a)
        layers.append([base + Vector((math.cos(2 * math.pi * k / sides) * r, math.sin(2 * math.pi * k / sides) * r, z)) for k in range(sides)])
    inside = base + Vector((0, 0, height * 0.3))
    layered(b, layers, [swatch] * len(layers), inside, cap_first=swatch)
    top = base + Vector((0, 0, height))
    last = layers[-1]
    for k in range(sides):
        oface(b, [last[k], last[(k + 1) % sides], top], swatch, inside)


def ball(b, centre, radius, sides, rings_n, swatch):
    centre = Vector(centre)
    layers = []
    for i in range(1, rings_n):
        a = -math.pi / 2 + math.pi * i / rings_n
        r = radius * math.cos(a)
        z = radius * math.sin(a)
        layers.append([centre + Vector((math.cos(2 * math.pi * k / sides) * r, math.sin(2 * math.pi * k / sides) * r, z)) for k in range(sides)])
    layered(b, layers, [swatch] * len(layers), centre)
    for pole, ring_pts in ((centre - Vector((0, 0, radius)), layers[0]), (centre + Vector((0, 0, radius)), layers[-1])):
        for k in range(sides):
            oface(b, [ring_pts[k], ring_pts[(k + 1) % sides], pole], swatch, centre)


def r3(v):
    return [round(c, 3) for c in v]


# ---------------------------------------------------------------- chain
LINK_LEN, LINK_W, LINK_WIRE = 1.0, 0.62, 0.15


def chain_link(name):
    b = Builder(name)
    r = LINK_WIRE / 2
    hx, hy = LINK_LEN / 2 - r, LINK_W / 2 - r
    # eight centreline points round a stadium-like oval in the xy plane
    path = [Vector((hx, 0, 0)), Vector((hx * 0.71, hy * 0.85, 0)), Vector((0, hy, 0)), Vector((-hx * 0.71, hy * 0.85, 0)),
            Vector((-hx, 0, 0)), Vector((-hx * 0.71, -hy * 0.85, 0)), Vector((0, -hy, 0)), Vector((hx * 0.71, -hy * 0.85, 0))]
    sweep(b, path, r, 6, "metal", closed=True)
    # interlocked links pull tight end to end: pitch = the inside length
    pitch = LINK_LEN - 2 * LINK_WIRE
    return b, {"length": LINK_LEN, "width": LINK_W, "wire": LINK_WIRE, "pitch": round(pitch, 3),
               "origin": "link centre", "long_axis": "x", "plane": "xy (alternate links turn 90 degrees about x)"}


# ---------------------------------------------------------------- padlock
BODY_W, BODY_H, BODY_T = 1.7, 1.5, 0.75
SOCKET_X = 0.5
SHACKLE_R = 0.09
SHACKLE_INSERT = 0.15


def keyhole_inside(x, z):
    if x * x + (z - 0.08) ** 2 <= 0.1 ** 2:
        return True
    if -0.22 <= z <= 0.02:
        half = 0.03 + (0.02 - z) / 0.24 * 0.035
        return abs(x) <= half
    return False


def plate_inside(x, z):
    return (x / 0.27) ** 2 + ((z + 0.04) / 0.36) ** 2 <= 1.0


def march(inside_fn, angle, limit=0.6, step=0.0015):
    d = Vector((math.sin(angle), math.cos(angle)))
    t = 0.0
    while t < limit and inside_fn(d.x * (t + step), d.y * (t + step)):
        t += step
    return (d.x * t, d.y * t)


def padlock_body(name):
    b = Builder(name)
    o = Vector((0, 0, 0))
    hy = BODY_T / 2

    def prof(inset):
        return rrect(BODY_W - 2 * inset, BODY_H - 2 * inset, max(0.05, 0.22 - inset), max(0.08, 0.5 - inset), seg=4)

    layers = [
        at_y(prof(0.1), hy),
        at_y(prof(0.0), hy - 0.075),
        at_y(prof(0.0), -hy + 0.115),
        at_y(prof(0.045), -hy + 0.075),
        at_y(prof(0.085), -hy + 0.045),
        at_y(prof(0.16), -hy + 0.005),
        at_y(prof(0.32), -hy - 0.025),
    ]
    # back cap, sides, a thin bright rim round the front edge, then the gently domed front
    layered(b, layers, ["metal", "metal", "steel", "steel", "metal", "metal"], o, cap_first="metal", cap_last="metal")
    front_y = -hy - 0.025
    # brass keyhole plate with a recessed dark keyhole: rays from (0, 0) to the plate outline and
    # to the keyhole outline give matching rings for the plate face and the recess walls
    n = 24
    plate_face, plate_back, key_face, key_floor = [], [], [], []
    for k in range(n):
        a = 2 * math.pi * k / n
        px, pz = march(plate_inside, a)
        kx, kz = march(keyhole_inside, a)
        plate_face.append(Vector((px, front_y - 0.07, pz)))
        plate_back.append(Vector((px, front_y, pz)))
        key_face.append(Vector((kx, front_y - 0.07, kz)))
        key_floor.append(Vector((kx, front_y - 0.01, kz)))
    pc = Vector((0, front_y - 0.035, -0.04))
    layered(b, [plate_back, plate_face], ["brass"], pc)
    for k in range(n):
        k2 = (k + 1) % n
        oface(b, [plate_face[k], plate_face[k2], key_face[k2], key_face[k]], "brass", pc + Vector((0, 1, 0)))
        tface(b, [key_face[k], key_face[k2], key_floor[k2], key_floor[k]], "black", Vector((0, front_y - 0.04, 0)))
    floor_c = Vector((0, front_y - 0.01, 0))
    for k in range(n):
        oface(b, [key_floor[k], key_floor[(k + 1) % n], floor_c], "black", floor_c + Vector((0, 1, 0)))
    # socket collars on the top
    top = BODY_H / 2
    for x in (-SOCKET_X, SOCKET_X):
        cyl(b, Vector((x, 0, top - 0.02)), 0.07, 0.15, 8, "steel", top_sw="black")
    return b, {
        "width": BODY_W, "height": BODY_H, "thickness": BODY_T, "origin": "body centre",
        "shackle_left": [-SOCKET_X, top], "shackle_right": [SOCKET_X, top],
        "shackle_seat": [-SOCKET_X, round(top - SHACKLE_INSERT, 3)],
        "keyhole_centre": [0.0, 0.0], "front_plane_y": round(front_y - 0.07, 3),
        "note": "points are (x, z) at y 0; put the PadlockShackle origin at shackle_seat",
    }


def padlock_shackle(name):
    b = Builder(name)
    gap = 2 * SOCKET_X
    rise = 1.1
    top_outer = SHACKLE_INSERT + rise
    rc = gap / 2
    zc = top_outer - SHACKLE_R - rc
    path = [Vector((0, 0, 0))]
    for k in range(9):
        a = math.pi - math.pi * k / 8
        path.append(Vector((rc + math.cos(a) * rc, 0, zc + math.sin(a) * rc)))
    right_bottom = 0.05
    path.append(Vector((gap, 0, right_bottom)))
    sweep(b, path, SHACKLE_R, 6, "steel", phase=math.pi / 6)
    return b, {
        "origin": "bottom of the left leg (hinge axis z)", "leg_gap": gap, "section": 2 * SHACKLE_R,
        "inner_width": round(gap - 2 * SHACKLE_R, 3), "height": round(top_outer, 3),
        "rise_above_body": rise, "insert": SHACKLE_INSERT, "right_leg_bottom": right_bottom,
        "lift_to_open": round(SHACKLE_INSERT - right_bottom + 0.02, 3),
    }


# ---------------------------------------------------------------- anchor post
POST_W, POST_H = 0.55, 13.0
EYE_R, EYE_WIRE = 0.18, 0.045


def chain_anchor_post(name):
    b = Builder(name)
    cap_z = POST_H - 0.32
    cbox(b, Vector((0, 0, cap_z / 2)), (POST_W, POST_W, cap_z), "plank_dark", c=0.07, edge="bark_warm")
    # base plate and a foot collar
    cbox(b, Vector((0, 0, 0.06)), (1.1, 1.1, 0.12), "metal", c=0.04)
    cbox(b, Vector((0, 0, 0.27)), (0.67, 0.67, 0.3), "metal", c=0.05)
    # cap: a collar band and a low pyramid top
    cbox(b, Vector((0, 0, cap_z + 0.06)), (0.69, 0.69, 0.16), "metal", c=0.04)
    base = cap_z + 0.14
    sq = [Vector((sx * 0.3, sy * 0.3, base)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    tip = Vector((0, 0, POST_H))
    for k in range(4):
        oface(b, [sq[k], sq[(k + 1) % 4], tip], "metal", Vector((0, 0, base + 0.05)))
    oface(b, sq, "metal", tip)
    eyes = {}
    for key, z in (("eye_high", 12.2), ("eye_low", 2.8)):
        cbox(b, Vector((POST_W / 2 + 0.03, 0, z)), (0.1, 0.22, 0.22), "metal", c=0.025)
        cyl(b, Vector((POST_W / 2 + 0.07, 0, z)), 0.06, 0.05, 6, "metal", axis=Vector((1, 0, 0)))
        cx = POST_W / 2 + 0.07 + 0.04 + EYE_R
        torus(b, Vector((cx, 0, z)), Vector((1, 0, 0)), Vector((0, 0, 1)), EYE_R, EYE_WIRE, 8, 5, "metal")
        eyes[key] = [round(cx, 3), 0.0, z]
    return b, dict(eyes, height=POST_H, width=POST_W, eye_inner_radius=round(EYE_R - EYE_WIRE, 3),
                   note="eyelets on the +x side, hole axis y; eye points are the ring centres (x, y, z)")


# ---------------------------------------------------------------- requirement sign
PLANK_W, PLANK_H, PLANK_T, PLANK_GAP, SIGN_BASE = 5.6, 1.2, 0.22, 0.12, 1.3
POST_X = 2.45


def oct_profile(w, h, cut):
    hw, hh = w / 2, h / 2
    return [(hw, -hh + cut), (hw, hh - cut), (hw - cut, hh), (-hw + cut, hh), (-hw, hh - cut), (-hw, -hh + cut), (-hw + cut, -hh), (hw - cut, -hh)]


def plank(b, cx, cz, w, h, t, face_sw, edge_sw, cut=0.16, bevel=0.05):
    def prof(inset):
        p = oct_profile(w - 2 * inset, h - 2 * inset, max(0.01, cut - 0.586 * inset))
        return [(x + cx, z + cz) for x, z in p]

    hy = t / 2
    layers = [at_y(prof(bevel), hy), at_y(prof(0), hy - bevel), at_y(prof(0), -hy + bevel), at_y(prof(bevel), -hy)]
    layered(b, layers, [edge_sw, edge_sw, edge_sw], Vector((cx, 0, cz)), cap_first=edge_sw, cap_last=face_sw)
    return {"centre": [round(cx, 3), round(cz, 3)], "size": [round(w - 2 * bevel, 3), round(h - 2 * bevel, 3)],
            "plane_y": round(-hy, 3)}


def portal_sign(name):
    b = Builder(name)
    tones = [("plank", "plank_dark"), ("bench_wood", "bark_warm"), ("plank", "plank_dark")]
    rows = ["bottom", "middle", "top"]
    meta_planks = []
    tops = []
    for i in range(3):
        z0 = SIGN_BASE + i * (PLANK_H + PLANK_GAP)
        cz = z0 + PLANK_H / 2
        face_sw, edge_sw = tones[i]
        m = plank(b, 0.0, cz, PLANK_W, PLANK_H, PLANK_T, face_sw, edge_sw)
        m["row"] = rows[i]
        meta_planks.append(m)
        tops.append(z0 + PLANK_H)
        # a bolt head over each post
        for x in (-POST_X, POST_X):
            cyl(b, Vector((x, -PLANK_T / 2 + 0.005, cz)), 0.035, 0.075, 6, "metal", axis=Vector((0, -1, 0)), top_sw="steel")
    plank_top = tops[-1]
    # trim rail along the top plank
    cbox(b, Vector((0, 0.02, plank_top + 0.07)), (PLANK_W + 0.24, PLANK_T + 0.12, 0.14), "bark_warm", c=0.04)
    # two posts behind, set 0.6 into the ground, with small capped tops
    post_top = plank_top + 0.55
    for x in (-POST_X, POST_X):
        cbox(b, Vector((x, PLANK_T / 2 + 0.2, (post_top - 0.6) / 2)), (0.4, 0.4, post_top + 0.6), "bark_warm", c=0.05, edge="plank_dark")
        cbox(b, Vector((x, PLANK_T / 2 + 0.2, post_top + 0.05)), (0.5, 0.5, 0.1), "plank_dark", c=0.03)
        base = post_top + 0.1
        sq = [Vector((x + sx * 0.22, PLANK_T / 2 + 0.2 + sy * 0.22, base)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        tip = Vector((x, PLANK_T / 2 + 0.2, base + 0.18))
        for k in range(4):
            oface(b, [sq[k], sq[(k + 1) % 4], tip], "plank_dark", Vector((x, PLANK_T / 2 + 0.2, base + 0.02)))
    height = post_top + 0.28
    return b, {
        "planks": list(reversed(meta_planks)), "plank_gap": PLANK_GAP, "bottom": SIGN_BASE,
        "text_safe_width": round(2 * POST_X - 0.3, 3), "bolts_x": [-POST_X, POST_X],
        "height": round(height, 3), "sink": 0.6,
        "note": "plank face rects: centre (x, z), size (w, h) of the flat front face, on the plane y = plane_y (front faces -y)",
    }


def build_all(emit):
    P = "portal/"
    emit(*chain_link("ChainLink"), P + "Lock")
    emit(*padlock_body("PadlockBody"), P + "Lock")
    emit(*padlock_shackle("PadlockShackle"), P + "Lock")
    emit(*chain_anchor_post("ChainAnchorPost"), P + "Lock")
    emit(*portal_sign("PortalSign"), P + "Sign")
