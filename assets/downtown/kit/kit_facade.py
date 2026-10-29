# Downtown kit: the shared facade grammar for the modular buildings of directions A and B (C's
# glass podiums and towers have their own module in kit_c.py). Research O4/O9: a 12-stud bay,
# shop ground floor 16 tall, upper storeys 12, parapet or cornice cap 3 to 6; pivot at the
# bottom centre of the facade plane; the facade faces local -Z (the LookVector) and the body
# runs back to z = depth. Modules stack: base at y 0, mids at 16, 28, ..., the top on the last.
# A module is coloured through generic swatch names the colourway remaps:
#   wall, wall2 (secondary wall), awa / awb (awning stripes), acc (accent), shop (shopfront frame)
# Facade terms (kitlib.fp): u to the viewer's right, v up, d outward toward the street.

import math

from kitlib import (
    Builder,
    V,
    box,
    cyl,
    fface,
    fp,
    opening,
    prism,
    rounded_rect2,
    sphere,
    sweep,
    wall_with_holes,
)

BASE_H = 16.0
STOREY = 12.0


# ---------------------------------------------------------------- body
def body(b, w, v0, v1, D, side="wall", back="wall", outline=None, skip_front=True):
    """Side and back walls of a module between heights v0 and v1 (no roof, no floor)."""
    if outline:
        # a plan outline [(x, z)]: front edges (z == 0, inside the flat front) are skipped
        n = len(outline)
        for i in range(n):
            (ax, az), (cx, cz) = outline[i], outline[(i + 1) % n]
            if skip_front and abs(az) < 1e-6 and abs(cz) < 1e-6:
                continue
            ex, ez = cx - ax, cz - az
            mx, mz = (ax + cx) / 2, (az + cz) / 2
            out = V(ez, 0, -ex)
            # make sure it points away from the plan centre
            cxm = sum(p[0] for p in outline) / n
            czm = sum(p[1] for p in outline) / n
            if out.dot(V(mx - cxm, 0, mz - czm)) < 0:
                out = -out
            sw = side if abs(ez) > abs(ex) or az > 0.01 or cz > 0.01 else side
            if abs(az - D) < 1e-6 and abs(cz - D) < 1e-6:
                sw = back
            b.face([V(ax, v0, az), V(cx, v0, cz), V(cx, v1, cz), V(ax, v1, az)], sw, out)
        return
    hw = w / 2
    b.face([V(-hw, v0, 0), V(-hw, v0, D), V(-hw, v1, D), V(-hw, v1, 0)], side, V(-1, 0, 0))
    b.face([V(hw, v0, 0), V(hw, v0, D), V(hw, v1, D), V(hw, v1, 0)], side, V(1, 0, 0))
    b.face([V(-hw, v0, D), V(hw, v0, D), V(hw, v1, D), V(-hw, v1, D)], back, V(0, 0, 1))


def band(b, u0, u1, v0, v1, out, swatch, back=0.0):
    """A horizontal trim band protruding `out` from the facade (front, top, bottom, ends)."""
    box(b, fp((u0 + u1) / 2, (v0 + v1) / 2, (out - back) / 2), (u1 - u0, v1 - v0, out + back), swatch)


def pilaster(b, u, w, v0, v1, out, swatch):
    box(b, fp(u, (v0 + v1) / 2, out / 2 - 0.05), (w, v1 - v0, out + 0.1), swatch)


def sill(b, u0, u1, v, swatch, out=0.45, h=0.3):
    box(b, fp((u0 + u1) / 2, v - h / 2, out / 2), (u1 - u0 + 0.6, h, out), swatch)


# ---------------------------------------------------------------- displays (shop window contents)
def display(b, kind, u, v, d, k):
    """A readable silhouette standing on the window floor at (u, v), depth d (inside the recess)."""
    sw = ["display_1", "display_2", "display_3", "display_4"]
    if kind == "cakes":
        # a tiered cake on a stand, or a pile of round loaves
        cyl(b, fp(u, v, d), 0.5, 0.25, 5, "shelf")
        cyl(b, fp(u, v + 0.5, d), 0.9, 1.0, 6, sw[k % 4], top_sw=sw[(k + 1) % 4])
        cyl(b, fp(u, v + 1.4, d), 0.7, 0.65, 6, sw[(k + 2) % 4], top_sw=sw[(k + 1) % 4])
        sphere(b, fp(u, v + 2.35, d), (0.28, 0.28, 0.28), ["accent_1", "accent_1"], subdiv=0)
    elif kind == "shelves":
        box(b, fp(u, v + 1.6, d), (2.6, 0.15, 0.7), "shelf")
        box(b, fp(u, v + 3.0, d), (2.6, 0.15, 0.7), "shelf")
        for j, x in enumerate((-0.8, 0.0, 0.8)):
            box(b, fp(u + x, v + 2.05, d), (0.5, 0.75, 0.5), sw[(k + j) % 4])
            box(b, fp(u + x * 0.9, v + 3.4, d), (0.55, 0.65, 0.45), sw[(k + j + 2) % 4])
        box(b, fp(u, v + 0.8, d), (2.4, 1.6, 0.6), "shelf")
    elif kind == "gadgets":
        box(b, fp(u, v + 0.6, d), (2.4, 1.2, 0.8), "shelf")
        box(b, fp(u, v + 2.2, d), (1.6, 2.0, 0.15), sw[k % 4])
        box(b, fp(u, v + 2.2, d + 0.06), (1.3, 1.6, 0.1), "glass_dark")
    elif kind == "flowers":
        cyl(b, fp(u, v, d), 0.9, 0.55, 6, "planter")
        sphere(b, fp(u, v + 1.6, d), (0.9, 0.8, 0.9), ["leaf_mid", "flower_1", "flower_2", "leaf_light"], subdiv=1)


# ---------------------------------------------------------------- awnings
def awning_striped(b, u0, u1, v_top, drop, proj, scallop=True, stripe=2.0):
    """A striped awning from the wall (v_top) out to `proj`, dropping `drop`, with a valance.
    Stripes show on top and underneath."""
    n = max(2, int(round((u1 - u0) / stripe)))
    sw = ["awa", "awb"]
    v_out = v_top - drop
    val = 0.9
    for i in range(n):
        a = u0 + (u1 - u0) * i / n
        c = u0 + (u1 - u0) * (i + 1) / n
        s = sw[i % 2]
        top = [fp(a, v_top, 0.05), fp(c, v_top, 0.05), fp(c, v_out, proj), fp(a, v_out, proj)]
        b.face(top, s, V(0, 1, 0) + fp(0, 0, 1))
        under = [p + V(0, -0.12, 0) for p in top]
        b.face(under, s, V(0, -1, 0))
        # valance with a rounded scallop
        m = (a + c) / 2
        if scallop:
            pts = [(a, v_out), (c, v_out), (c, v_out - val)]
            for k in range(1, 3):
                t = math.pi * k / 3
                pts.append((m + (c - m) * math.cos(t), v_out - val - (c - a) * 0.38 * math.sin(t)))
            pts.append((a, v_out - val))
        else:
            pts = [(a, v_out), (c, v_out), (c, v_out - val), (a, v_out - val)]
        b.face([fp(x, y, proj) for x, y in pts], s, fp(0, 0, 1))
        b.face([fp(x, y, proj - 0.06) for x, y in pts], s, fp(0, 0, -1))
    # side cheeks
    for u, nx in ((u0, -1), (u1, 1)):
        b.face2([fp(u, v_top, 0.05), fp(u, v_out, proj), fp(u, v_out - val, proj)], "awa")
    return v_out - val


def awning_flat(b, u0, u1, v_top, drop, proj, edge=True):
    """A plain canvas awning (B) with a contrasting edge band on the valance."""
    v_out = v_top - drop
    top = [fp(u0, v_top, 0.05), fp(u1, v_top, 0.05), fp(u1, v_out, proj), fp(u0, v_out, proj)]
    b.face(top, "awa", V(0, 1, 0) + fp(0, 0, 1))
    b.face([p + V(0, -0.12, 0) for p in top], "awning_under", V(0, -1, 0))
    val = 1.1
    b.face([fp(u0, v_out, proj), fp(u1, v_out, proj), fp(u1, v_out - val, proj), fp(u0, v_out - val, proj)], "awa", fp(0, 0, 1))
    if edge:
        b.face([fp(u0, v_out - val * 0.55, proj + 0.02), fp(u1, v_out - val * 0.55, proj + 0.02), fp(u1, v_out - val * 0.8, proj + 0.02), fp(u0, v_out - val * 0.8, proj + 0.02)], "awb", fp(0, 0, 1))
    b.face([fp(u0, v_out, proj - 0.06), fp(u1, v_out, proj - 0.06), fp(u1, v_out - val, proj - 0.06), fp(u0, v_out - val, proj - 0.06)], "awning_under", fp(0, 0, -1))
    for u in (u0, u1):
        b.face2([fp(u, v_top, 0.05), fp(u, v_out, proj), fp(u, v_out - val, proj)], "awa")


# ---------------------------------------------------------------- ground floor
def shopfront(b, w, st):
    """Ground floor (16 tall): plinth, pilasters, display windows with silhouettes, a recessed
    door with a frame, an awning with an underside, a sign band and a top band."""
    H = BASE_H
    D = st["D"]
    hw = w / 2
    if w >= 24:
        wins = [(-hw + 1.6, -2.6), (2.6, hw - 1.6)]
        door = (-1.8, 1.8)
    else:
        wins = [(-hw + 1.4, 0.9)]
        door = (1.9, hw - 1.3)
    wv0, wv1 = 1.5, 9.6
    dv1 = 8.6 if st["door_shape"] == "rect" else 9.4
    holes = [(a, c, wv0, wv1) for a, c in wins] + [(door[0], door[1], 0.0, dv1)]
    wall_with_holes(b, -hw, hw, 0, H, holes, st.get("base_wall", "wall"))
    rec = st["recess"]
    for i, (a, c) in enumerate(wins):
        opening(b, a, c, wv0, wv1, st["win_shape_base"], rec, st.get("base_wall", "wall"), st.get("reveal", "shop"), ("glass", "glass_light") if st["win_shape_base"] == "rect" else "glass", glass_split=0.62 if st["win_shape_base"] == "rect" else None)
        # window floor (the stall riser) and displays
        box(b, fp((a + c) / 2, wv0 - 0.05, -rec / 2), (c - a, 0.1, rec), "shelf")
        n = 2 if c - a > 6 else 1
        for k in range(n):
            u = a + (c - a) * (k + 0.5) / n
            display(b, st["display"], u, wv0, -rec + 0.55, i * 2 + k)
        # a thin shopfront frame around the window
        for (u0, u1, v0, v1) in ((a - 0.35, a, wv0 - 0.35, wv1), (c, c + 0.35, wv0 - 0.35, wv1), (a - 0.35, c + 0.35, wv0 - 0.35, wv0)):
            box(b, fp((u0 + u1) / 2, (v0 + v1) / 2, 0.12), (u1 - u0, v1 - v0, 0.24), "shop")
        if st["win_shape_base"] == "rect":
            box(b, fp((a + c) / 2, wv1 + 0.17, 0.12), (c - a + 0.7, 0.35, 0.24), "shop")
    # door
    drec = st["door_recess"]
    opening(b, door[0], door[1], 0.0, dv1, st["door_shape"], drec, st.get("base_wall", "wall"), st.get("reveal", "shop"), "door")
    dw = door[1] - door[0]
    dc = (door[0] + door[1]) / 2
    # door glass panel and handle, on the door face
    box(b, fp(dc, 4.8, -drec + 0.06), (dw * 0.55, 3.6, 0.1), "glass_light")
    box(b, fp(door[1] - 0.6, 3.6, -drec + 0.15), (0.15, 0.8, 0.2), "trim_2")
    # door frame (architrave)
    if st["door_shape"] == "rect":
        for (u0, u1, v0, v1) in ((door[0] - 0.5, door[0], 0, dv1 + 0.5), (door[1], door[1] + 0.5, 0, dv1 + 0.5), (door[0] - 0.5, door[1] + 0.5, dv1, dv1 + 0.5)):
            box(b, fp((u0 + u1) / 2, (v0 + v1) / 2, 0.15), (u1 - u0, v1 - v0, 0.3), "trim_1")
    else:
        for u0, u1 in ((door[0] - 0.5, door[0]), (door[1], door[1] + 0.5)):
            box(b, fp((u0 + u1) / 2, (dv1 - dw / 2) / 2, 0.15), (u1 - u0, dv1 - dw / 2, 0.3), "trim_1")
    # door step
    box(b, fp(dc, 0.15, 0.4), (dw + 1.0, 0.3, 0.8), "trim_3")
    # plinth, end pilasters, sign band trim and top band
    band(b, -hw, hw, 0, 1.0, 0.18, st.get("plinth", "wall_base"))
    if st.get("pilasters", True):
        for u in (-hw + 0.5, hw - 0.5):
            pilaster(b, u, 1.0, 0, H - 0.6, 0.4, st.get("pilaster_sw", "trim_1"))
    if st.get("awning") == "striped":
        awning_striped(b, -hw + 1.0, hw - 1.0, 11.0, 1.6, 4.4, scallop=st.get("scallop", True))
    elif st.get("awning") == "flat":
        for a, c in wins:
            awning_flat(b, a - 0.4, c + 0.4, 11.0, 2.0, 3.8)
    # sign band frame (signs mount here, at v 11.8 to 14.6, d 0.3)
    band(b, -hw + 1.0, hw - 1.0, 11.4, 11.7, 0.3, "trim_1")
    band(b, -hw, hw, H - 0.7, H, st.get("top_band_out", 0.5), "trim_1")
    body(b, w, 0, H, D)
    return {"sign_band": [11.8, 14.8], "sign_depth": 0.3}


# ---------------------------------------------------------------- upper floors
def upper(b, w, st, round_windows=False):
    H = STOREY
    D = st["D"]
    hw = w / 2
    bays = int(round(w / 12))
    centres = []
    for i in range(bays):
        bc = -hw + 12 * i + 6
        centres += [bc - 3.0, bc + 3.0]
    ww = st["win_w"]
    holes = []
    for c in centres:
        if round_windows:
            holes.append((c - 2.0, c + 2.0, 4.0, 8.0))
        else:
            holes.append((c - ww / 2, c + ww / 2, st["win_v"][0], st["win_v"][1]))
    wall_with_holes(b, -hw, hw, 0, H, holes, "wall")
    for (a, c, v0, v1) in holes:
        shape = "round" if round_windows else st["win_shape"]
        opening(b, a, c, v0, v1, shape, st["recess"], "wall", "reveal", ("glass", "glass_light") if shape == "rect" else "glass", glass_split=0.55 if shape == "rect" else None, mullion=("frame", 0.22) if shape == "rect" else None)
        if not round_windows:
            sill(b, a, c, v0, st.get("sill_sw", "trim_1"))
            if st.get("lintel"):
                box(b, fp((a + c) / 2, v1 + 0.35, 0.15), (c - a + 0.8, 0.7, 0.3), st["lintel"])
        else:
            # a ring frame round the porthole
            n = 12
            for k in range(n):
                a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
                cu, cv = (a + c) / 2, (v0 + v1) / 2
                r0, r1 = 2.0, 2.45
                pts = [fp(cu + math.cos(a0) * r0, cv + math.sin(a0) * r0, 0.25), fp(cu + math.cos(a1) * r0, cv + math.sin(a1) * r0, 0.25), fp(cu + math.cos(a1) * r1, cv + math.sin(a1) * r1, 0.25), fp(cu + math.cos(a0) * r1, cv + math.sin(a0) * r1, 0.25)]
                b.face(pts, "trim_1", V(0, 0, -1))
    if st.get("floor_band"):
        band(b, -hw, hw, 0, 0.45, 0.22, st["floor_band"])
    if st.get("course"):
        band(b, -hw, hw, H - 0.3, H, 0.08, st["course"])
    body(b, w, 0, H, D)


def roof_slab(b, outline, v, swatch="roof"):
    b.face([V(x, v, z) for x, z in outline], swatch, V(0, 1, 0))


def parapet_ring(b, outline, v0, v1, t, swatch, cap):
    """A thin parapet wall following a plan outline (inner face, top cap)."""
    prism(b, outline, v0, v1, swatch, top=False)
    n = len(outline)
    cx = sum(p[0] for p in outline) / n
    cz = sum(p[1] for p in outline) / n
    inner = []
    for x, z in outline:
        dx, dz = cx - x, cz - z
        L = math.hypot(dx, dz) or 1
        inner.append((x + dx / L * t * 1.41, z + dz / L * t * 1.41))
    for i in range(n):
        (ax, az), (qx, qz) = inner[i], inner[(i + 1) % n]
        b.face([V(ax, v0, az), V(qx, v0, qz), V(qx, v1, qz), V(ax, v1, az)], swatch, V(cx - (ax + qx) / 2, 0, cz - (az + qz) / 2))
        (ox, oz), (px, pz) = outline[i], outline[(i + 1) % n]
        b.face([V(ox, v1, oz), V(px, v1, pz), V(qx, v1, qz), V(ax, v1, az)], cap, V(0, 1, 0))


# ---------------------------------------------------------------- sign boards
def plate(b, outline, d0, d1, front_sw, edge_sw=None, back_sw=None):
    """A flat board in the facade plane: a 2D outline [(u, v)] extruded from depth d0 (back,
    against the wall) to d1 (front). Front faces the street."""
    edge_sw = edge_sw or front_sw
    back_sw = back_sw or edge_sw
    b.face([fp(u, v, d1) for u, v in outline], front_sw, V(0, 0, -1))
    b.face([fp(u, v, d0) for u, v in outline], back_sw, V(0, 0, 1))
    n = len(outline)
    cu = sum(p[0] for p in outline) / n
    cv = sum(p[1] for p in outline) / n
    for i in range(n):
        (au, av), (cu2, cv2) = outline[i], outline[(i + 1) % n]
        q = [fp(au, av, d0), fp(cu2, cv2, d0), fp(cu2, cv2, d1), fp(au, av, d1)]
        b.face(q, edge_sw, fp((au + cu2) / 2 - cu, (av + cv2) / 2 - cv, 0))


def rrect_uv(u0, v0, u1, v1, r, seg=3):
    """A rounded rectangle outline in facade (u, v) terms."""
    return rounded_rect2(u0, v0, u1, v1, r, seg)


def circle_uv(cu, cv, r, n=12, phase=0.0):
    return [(cu + math.cos(phase + 2 * math.pi * k / n) * r, cv + math.sin(phase + 2 * math.pi * k / n) * r) for k in range(n)]


def sign_face_record(name, cu, cv, d, w, h, normal="Front"):
    """Where text goes: centre in the mesh's local frame (pivot-relative), size and face."""
    c = fp(cu, cv, d)
    return {"name": name, "centre": [round(c.x, 3), round(c.y, 3), round(c.z, 3)], "size": [round(w, 3), round(h, 3)], "normal": normal}


def offset_outline(pts, dist):
    """Offset a convex plan outline outward by dist (mitred)."""
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sgn = 1 if area > 0 else -1
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        ns = []
        for a, c in ((p0, p1), (p1, p2)):
            dx, dz = c[0] - a[0], c[1] - a[1]
            L = math.hypot(dx, dz) or 1
            ns.append((dz / L * sgn, -dx / L * sgn))
        nx, nz = ns[0][0] + ns[1][0], ns[0][1] + ns[1][1]
        L = math.hypot(nx, nz) or 1
        nx, nz = nx / L, nz / L
        cosh = max(0.3, nx * ns[0][0] + nz * ns[0][1])
        out.append((p1[0] + nx * dist / cosh, p1[1] + nz * dist / cosh))
    return out
