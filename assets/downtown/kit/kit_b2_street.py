# Downtown kit B2: the street layer for direction B production start: the fictional sign family,
# the WELCOME TO DOWNTOWN span and bunting (sparse, on believable posts, above vehicle clearance),
# district street furniture (formal lamps, hedges, flower beds), the harbor's waterfront kit
# (water, quay, piers, bollards, shed, dock crane, containers), the hazard set (B2 pothole and
# oil, the construction lot) and the skyline (the distant stadium and a spire).
#
# The overnight shared recipes (kit_street, kit_hazards, kit_skyline) are re-emitted unchanged in
# geometry under B2 names on the B2 palette (kit_b2lib.use_b2), so a B2 scene needs one palette
# image. Orange/white is used ONLY by the construction hazards; bunting, awnings and signs never
# pair those colours.
#
# Pivots: signs at the bottom centre of their back face (on the wall), front -Z; spans at the road
# centre line on the ground (y 0), spanning along X (place them with the road's start/end socket
# frame); furniture and props at the bottom centre; hazards at their centre on the road surface.

import math
import random

import kit_hazards
import kit_skyline
import kit_street
import kitlib
from kit_b2_road import CURB_H, WATER_Y, dims
from kit_b2lib import B2Builder, V, box, circle_uv, face_rec, fp, fquad, plate, side_plate, sock, use_b2
from kitlib import beam, cyl, prism, sphere, sweep, tube

use_b2(kit_street)
use_b2(kit_hazards)
use_b2(kit_skyline)


def seed_of(name):
    return sum(map(ord, name)) * 13 + len(name)


# ---------------------------------------------------------------- the sign family
def fascia(name, business, w, frame_sw, emblem):
    """A shop fascia for a lot's fascia socket: a framed board 3.6 tall on the sign band, a cream
    text face, and an original emblem standing proud at the left end (silhouette first)."""
    b = B2Builder(name)
    h = 3.6
    hw = w / 2
    plate(b, [(-hw, 0), (hw, 0), (hw, h), (-hw, h)], 0, 0.3, frame_sw)
    e = h * 1.15
    fu0 = -hw + e + 0.5
    fquad(b, fu0, hw - 0.35, 0.35, h - 0.35, 0.32, "sign_face")
    cu, cv = -hw + e / 2 + 0.2, h / 2
    emblem_shape(b, emblem, cu, cv, e * 0.5, 0.3)
    fw = hw - 0.35 - fu0
    return b, {
        "family": "Sign",
        "business": business,
        "kind": "fascia",
        "size": [w, h],
        "faces": [face_rec("main", fp(fu0 + fw / 2, h / 2, 0.34), fw - 0.4, h - 1.0)],
        "default_text": business,
        "lod": "near",
        "district": "MS,CH,HB,MT,SP",
        "pivot": "bottom centre of the back face (on the wall); front faces -Z",
        "sockets": {"mount": sock((0, 0, 0))},
        "mount": "a lot's fascia_<n> socket",
    }


def emblem_shape(b, kind, cu, cv, r, d):
    """Original emblems (no real logos): pizza-wheel, hex nut, open book, paw, coffee cup, note."""
    z0 = d
    if kind == "pizza":
        plate(b, circle_uv(cu, cv, r, 12), z0, z0 + 0.35, "emblem_crust")
        for k in range(12):
            if k % 2 == 0:
                a = 2 * math.pi * k / 12
                plate(b, [(cu + math.cos(a) * r * 0.9, cv + math.sin(a) * r * 0.9), (cu + math.cos(a + 0.26) * r * 1.1, cv + math.sin(a + 0.26) * r * 1.1), (cu + math.cos(a + 0.52) * r * 0.9, cv + math.sin(a + 0.52) * r * 0.9)], z0, z0 + 0.35, "emblem_crust", back=False)
        fq = [(cu + u, cv + v) for u, v in circle_uv(0, 0, r * 0.78, 12)]
        b.face([fp(u, v, z0 + 0.37) for u, v in fq], "emblem_cheese", V(0, 0, -1))
        for k in range(5):
            a = 2 * math.pi * k / 5 + 0.3
            b.face([fp(cu + math.cos(a) * r * 0.48 + u, cv + math.sin(a) * r * 0.48 + v, z0 + 0.39) for u, v in circle_uv(0, 0, r * 0.15, 6)], "emblem_red", V(0, 0, -1))
        b.face([fp(cu + u, cv + v, z0 + 0.39) for u, v in circle_uv(0, 0, r * 0.18, 6)], "emblem_crust", V(0, 0, -1))
    elif kind == "nut":
        plate(b, circle_uv(cu, cv, r, 6, math.pi / 6), z0, z0 + 0.45, "emblem_steel", "iron")
        b.face([fp(cu + u, cv + v, z0 + 0.47) for u, v in circle_uv(0, 0, r * 0.45, 8)], "iron", V(0, 0, -1))
    elif kind == "book":
        plate(b, [(cu - r, cv - r * 0.6), (cu - 0.08, cv - r * 0.75), (cu - 0.08, cv + r * 0.65), (cu - r, cv + r * 0.8)], z0, z0 + 0.3, "emblem_white", "emblem_blue")
        plate(b, [(cu + 0.08, cv - r * 0.75), (cu + r, cv - r * 0.6), (cu + r, cv + r * 0.8), (cu + 0.08, cv + r * 0.65)], z0, z0 + 0.3, "emblem_white", "emblem_blue")
        for k in range(3):
            v = cv + r * (0.4 - 0.3 * k)
            fquad(b, cu - r * 0.8, cu - r * 0.25, v - 0.06, v + 0.06, z0 + 0.32, "emblem_blue")
            fquad(b, cu + r * 0.25, cu + r * 0.8, v - 0.06, v + 0.06, z0 + 0.32, "emblem_blue")
    elif kind == "paw":
        plate(b, circle_uv(cu, cv - r * 0.25, r * 0.5, 8), z0, z0 + 0.3, "emblem_white", "sign_ink")
        for k in range(4):
            a = math.radians(50 + 27 * k)
            plate(b, circle_uv(cu + math.cos(a) * r * 0.8 - r * 0.0, cv - r * 0.25 + math.sin(a) * r * 0.85, r * 0.22, 6), z0, z0 + 0.3, "emblem_white", "sign_ink")


def blade_sign(name, business, height, width, frame_sw, emblem):
    """A projecting double-sided blade for a lot's blade_<n> socket: faces +X and -X (they look
    down the road both ways), a frame, cream text faces and an emblem crest on top."""
    b = B2Builder(name)
    t = 0.7
    z0, z1 = -0.9, -0.9 - width
    pts = [(z0, 0.0), (z1 + 0.6, 0.0), (z1, 0.6), (z1, height - 0.6), (z1 + 0.6, height), (z0, height)]
    side_plate(b, 0.0, pts, t, frame_sw, "sign_gold")
    fz0, fz1 = z0 - 0.45, z1 + 0.45
    for sx in (-1, 1):
        b.face([V(sx * (t / 2 + 0.03), y, z) for z, y in ((fz0, 0.55), (fz1, 0.55), (fz1, height - 0.55), (fz0, height - 0.55))], "sign_face", V(sx, 0, 0))
    for y in (0.8, height - 0.8):
        box(b, V(0, y, -0.45), (0.3, 0.3, 0.9), {"side": "iron"})
    cz = (z0 + z1) / 2
    if emblem == "cup":
        side_plate(b, 0.0, [(cz - 1.1, height + 0.2), (cz + 1.1, height + 0.2), (cz + 1.4, height + 2.4), (cz - 1.4, height + 2.4)], 0.6, "emblem_white", "sign_ink")
        side_plate(b, 0.0, [(cz - 1.4 - 0.9, height + 1.0), (cz - 1.3, height + 0.9), (cz - 1.3, height + 1.9), (cz - 1.4 - 0.9, height + 1.8)], 0.5, "emblem_white", "sign_ink")
        for k in range(3):
            side_plate(b, 0.0, [(cz - 0.7 + 0.7 * k, height + 2.6), (cz - 0.5 + 0.7 * k, height + 2.6), (cz - 0.3 + 0.7 * k, height + 3.6), (cz - 0.5 + 0.7 * k, height + 3.6)], 0.3, "emblem_white")
    elif emblem == "note":
        side_plate(b, 0.0, [(cz - 1.4 + 0.9 * math.cos(2 * math.pi * k / 8), height + 1.0 + 0.7 * math.sin(2 * math.pi * k / 8)) for k in range(8)], 0.6, "sign_ink")
        side_plate(b, 0.0, [(cz - 0.6, height + 1.0), (cz - 0.25, height + 1.0), (cz - 0.25, height + 4.2), (cz - 0.6, height + 4.2)], 0.6, "sign_ink")
        side_plate(b, 0.0, [(cz - 0.25, height + 4.2), (cz + 1.2, height + 3.4), (cz + 1.2, height + 2.8), (cz - 0.25, height + 3.5)], 0.6, "sign_ink")
    face_w = abs(fz1 - fz0)
    return b, {
        "family": "Sign",
        "business": business,
        "kind": "blade",
        "size": [t, height, width + 0.9],
        "faces": [
            {"name": "left", "centre": [-(t / 2 + 0.05), height / 2, round((fz0 + fz1) / 2, 3)], "size": [round(face_w, 3), round(height - 1.1, 3)], "normal": "Left", "text": "vertical"},
            {"name": "right", "centre": [t / 2 + 0.05, height / 2, round((fz0 + fz1) / 2, 3)], "size": [round(face_w, 3), round(height - 1.1, 3)], "normal": "Right", "text": "vertical"},
        ],
        "default_text": business,
        "lod": "near",
        "district": "MS,CH,HB,MT,SP",
        "pivot": "bottom of the back edge on the wall; projects toward -Z; faces +X/-X",
        "sockets": {"mount": sock((0, 0, 0))},
        "mount": "a lot's blade_<n> socket",
    }


def corner_blade(name):
    """A small hanging corner sign (3 x 2.2) on an iron bracket: Main Street's small corner signs
    (text per instance: OPEN, CAFE, BAKERY ...). Faces +X/-X; projects toward -Z."""
    b = B2Builder(name)
    beam(b, V(0, 2.9, 0.0), V(0, 2.9, -3.8), 0.12, 0.12, "iron")
    beam(b, V(0, 0.6, 0.0), V(0, 2.9, -2.6), 0.08, 0.08, "iron")
    side_plate(b, 0.0, [(-0.7, 0.4), (-3.7, 0.4), (-3.7, 2.6), (-0.7, 2.6)], 0.3, "sign_frame_3", "sign_gold")
    for sx in (-1, 1):
        b.face([V(sx * 0.17, y, z) for z, y in ((-0.95, 0.65), (-3.45, 0.65), (-3.45, 2.35), (-0.95, 2.35))], "sign_face", V(sx, 0, 0))
    return b, {
        "family": "Sign",
        "kind": "corner",
        "faces": [{"name": "left", "centre": [-0.2, 1.5, -2.2], "size": [2.4, 1.6], "normal": "Left"}, {"name": "right", "centre": [0.2, 1.5, -2.2], "size": [2.4, 1.6], "normal": "Right"}],
        "default_text": "OPEN",
        "lod": "near",
        "district": "MS",
        "pivot": "bracket root on the wall; projects toward -Z",
        "sockets": {"mount": sock((0, 0, 0))},
        "mount": "a corner lot's corner_sign socket, or a blade_<n> socket at y + 1",
    }


# ---------------------------------------------------------------- spans over the road
def bunting(name, W):
    """Sparse bunting across the road: two painted poles on the sidewalks 1.2 in from the curb, a
    rope sagging to 21.5 and pennants in teal, cream, burgundy, gold and navy (never orange and
    white). Lowest pennant tip >= 18 over the road."""
    d = dims(W)
    b = B2Builder(name)
    px = d["curb_out"] + 1.2
    top = 26.0
    for sx in (-1, 1):
        cyl(b, V(sx * px, CURB_H, 0), 1.0, 0.6, 8, "furn_metal_dark", r_top=0.45)
        cyl(b, V(sx * px, CURB_H + 1.0, 0), top - CURB_H - 0.2, 0.32, 8, "furn_metal", top=False, r_top=0.26)
        sphere(b, V(sx * px, top + 0.9, 0), (0.55, 0.55, 0.55), ["sign_gold", "sign_gold"], subdiv=0)
    sag = 4.5
    n = 14
    rope = [V(-px + 2 * px * k / n, top - sag * (1 - (2 * k / n - 1) ** 2), 0) for k in range(n + 1)]
    tube(b, rope, 0.09, 3, "iron", cap=False)
    cols = ["pennant_1", "pennant_2", "pennant_3", "pennant_4", "pennant_5"]
    m = int(2 * px // 4.2)
    low = 99.0
    for k in range(1, m):
        x = -px + 2 * px * k / m
        y = top - sag * (1 - (x / px) ** 2)
        tip = y - 2.2
        low = min(low, tip)
        b.face2([V(x - 0.9, y, 0), V(x + 0.9, y, 0), V(x, tip, 0)], cols[k % len(cols)])
    return b, {
        "family": "Span",
        "laneWidth": W,
        "span": round(2 * px, 2),
        "lowest_point_over_road": round(low, 2),
        "clearance_rule": ">= 18",
        "lod": "near",
        "district": "MS,SP",
        "pivot": "road centre line at ground level; spans along X; place with a segment socket frame",
        "sockets": {"centre": sock((0, 0, 0))},
        "rule": "sparse: at most one bunting span per 192-stud segment, never at a hazard",
    }


def welcome_span(name, W):
    """WELCOME TO DOWNTOWN: a gateway across the road on two brick piers (3 x 3, stone caps and
    lanterns) on the sidewalks, a slightly arched steel truss and a sign board whose underside is
    22.4 over the road (>= 18). Text on both faces (+Z faces approaching traffic)."""
    d = dims(W)
    b = B2Builder(name)
    px = d["curb_out"] + 2.6
    H = 30.0
    for sx in (-1, 1):
        box(b, V(sx * px, CURB_H + 1.0, 0), (4.0, 2.0, 4.0), {"side": "lm_trim", "top": "lm_trim", "skip_bottom": True})
        box(b, V(sx * px, CURB_H + 2.0 + (H - 4.0) / 2, 0), (3.0, H - 4.0, 3.0), {"side": "lm_brick", "skip_bottom": True, "skip_top": True})
        box(b, V(sx * px, H, 0), (3.8, 1.0, 3.8), {"side": "lm_trim", "top": "lm_trim"})
        cyl(b, V(sx * px, H + 0.5, 0), 1.6, 0.8, 6, "lamp_glass", top=False)
        cyl(b, V(sx * px, H + 2.1, 0), 0.8, 1.1, 6, "furn_metal_dark", r_top=0.1)
    yb, yt = 22.4, 26.6
    n = 10
    chord_top = [V(-px + 2 * px * k / n, yt + 1.6 + 2.4 * (1 - (2 * k / n - 1) ** 2), 0) for k in range(n + 1)]
    tube(b, chord_top, 0.35, 4, "bridge_steel", phase=math.pi / 4)
    beam(b, V(-px, yb - 0.4, 0), V(px, yb - 0.4, 0), 0.6, 0.6, "bridge_steel")
    for k in range(1, n):
        a = chord_top[k]
        beam(b, V(a.x, yt, 0), a, 0.22, 0.22, "bridge_steel_dark")
    bw = 2 * d["half_lanes"] - 6.0
    plate(b, [(-bw / 2, yb), (bw / 2, yb), (bw / 2, yt), (-bw / 2, yt)], -0.3, 0.3, "sign_frame_1")
    fquad(b, -bw / 2 + 0.4, bw / 2 - 0.4, yb + 0.4, yt - 0.4, 0.31, "sign_face")
    b.face([V(-bw / 2 + 0.4, yb + 0.4, 0.31), V(bw / 2 - 0.4, yb + 0.4, 0.31), V(bw / 2 - 0.4, yt - 0.4, 0.31), V(-bw / 2 + 0.4, yt - 0.4, 0.31)], "sign_face", V(0, 0, 1))
    for sx in (-1, 1):
        beam(b, V(sx * bw / 2, yt, 0), V(sx * px, yt + 1.6, 0), 0.25, 0.25, "bridge_steel")
    return b, {
        "family": "Span",
        "laneWidth": W,
        "span": round(2 * px, 2),
        "lowest_point_over_road": round(yb - 0.7, 2),
        "clearance_rule": ">= 18",
        "faces": [
            {"name": "approach", "centre": [0, round((yb + yt) / 2, 3), 0.32], "size": [round(bw - 1.0, 2), round(yt - yb - 0.8, 2)], "normal": "Back"},
            {"name": "depart", "centre": [0, round((yb + yt) / 2, 3), -0.32], "size": [round(bw - 1.0, 2), round(yt - yb - 0.8, 2)], "normal": "Front"},
        ],
        "default_text": {"approach": "WELCOME TO DOWNTOWN", "depart": "COME BACK SOON!"},
        "lod": "near",
        "district": "MS",
        "pivot": "road centre line at ground level; spans along X",
        "sockets": {"centre": sock((0, 0, 0))},
        "rule": "one at the Downtown entry (first Main Street segment); not repeated per cycle",
    }


# ---------------------------------------------------------------- district furniture
def formal_lamp(name):
    """City Hall's formal lamp: a fluted cast base, a tapered post, a crossarm with two lanterns
    (6-sided glass under domed caps) and a finial. 17 tall, pivot at the bottom centre."""
    b = B2Builder(name)
    cyl(b, V(0, 0, 0), 1.6, 1.0, 8, "furn_metal_dark", top=False, r_top=0.8)
    cyl(b, V(0, 1.6, 0), 0.6, 0.8, 8, "furn_metal", top=False, r_top=0.5)
    cyl(b, V(0, 2.2, 0), 12.0, 0.36, 8, "furn_metal_dark", top=False, r_top=0.26)
    box(b, V(0, 14.4, 0), (6.4, 0.35, 0.35), {"side": "furn_metal_dark"})
    for sx in (-1, 1):
        x = sx * 3.0
        beam(b, V(sx * 0.3, 13.0, 0), V(x * 0.8, 14.3, 0), 0.12, 0.12, "furn_metal_dark")
        cyl(b, V(x, 14.6, 0), 0.25, 0.5, 6, "furn_metal_dark")
        cyl(b, V(x, 14.85, 0), 1.8, 0.55, 6, "lamp_glass", top=False, r_top=0.75)
        cyl(b, V(x, 16.65, 0), 0.7, 0.95, 6, "furn_metal_dark", r_top=0.15)
    cyl(b, V(0, 14.6, 0), 2.2, 0.22, 6, "furn_metal_dark", r_top=0.05)
    return b, {"family": "Street", "height": 17.4, "reach": 3.0, "lod": "near", "district": "CH", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}, "material": "Metal; lantern glass could be Neon (dim) in Studio"}


def hedge(name, L=12.0):
    """A clipped box hedge 12 long, 3 tall, with a chamfered top (sides dark, top light)."""
    b = B2Builder(name)
    prof = [(0.0, -1.3), (2.3, -1.3), (3.0, -0.7), (3.0, 0.7), (2.3, 1.3), (0.0, 1.3)]
    sweep(b, prof, -L / 2, L / 2, ["hedge_dark", "hedge_light", "hedge_light", "hedge_light", "hedge_dark", "soil"], cap_sw="hedge_dark")
    return b, {"family": "Park", "length": L, "height": 3.0, "lod": "near", "district": "SP,CH", "pivot": "bottom centre; runs along X", "sockets": {"base": sock((0, 0, 0))}}


def flower_bed(name):
    """A low stone-rimmed flower bed 8 x 3 with clustered flowers in three colours."""
    rng = random.Random(seed_of(name))
    b = B2Builder(name)
    prism(b, [(-4, -1.5), (4, -1.5), (4, 1.5), (-4, 1.5)], 0, 0.9, "fountain_stone", "soil")
    for k in range(7):
        x = -3.2 + 6.4 * k / 6
        z = rng.uniform(-0.6, 0.6)
        sphere(b, V(x, 1.3, z), (0.7, 0.6, 0.7), ["leaf_mid", "flower_1", "flower_2", "flower_3"][k % 2 :: 2] + ["leaf_dark"], subdiv=0, rng=rng)
    return b, {"family": "Park", "size": [8, 1.9, 3], "lod": "near", "district": "SP,CH", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}}


# ---------------------------------------------------------------- harbor waterfront
def water(name):
    """The river: a 960 x 192 water plane at the water level (y -24 below the road), faceted in
    three close blues so it reads as water at speed without noise. Pivot = the bridge span start
    on the road centre line at deck level (the plane sits at WATER_Y below it); the river runs
    along X under the 192-stud span."""
    rng = random.Random(seed_of(name))
    b = B2Builder(name)
    nx, nz = 12, 4
    X, L = 480.0, 192.0
    for i in range(nx):
        for j in range(nz):
            x0, x1 = -X + 2 * X * i / nx, -X + 2 * X * (i + 1) / nx
            z0, z1 = -L * j / nz, -L * (j + 1) / nz
            a, c = rng.choice(["water", "water", "water_light"]), rng.choice(["water", "water_dark"])
            b.face([V(x0, WATER_Y, z0), V(x1, WATER_Y, z0), V(x1, WATER_Y, z1)], a, V(0, 1, 0))
            b.face([V(x0, WATER_Y, z0), V(x1, WATER_Y, z1), V(x0, WATER_Y, z1)], c, V(0, 1, 0))
    return b, {"family": "Harbor", "size": [2 * X, 0, L], "water_y": WATER_Y, "lod": "mid", "district": "HB", "pivot": "bridge span start on the road centre line at deck level; the plane is at water_y", "sockets": {"start": sock((0, 0, 0))}, "material": "SmoothPlastic, Reflectance about 0.15 (no Transparency)"}


def quay(name):
    """A 96-long quay edge for the river banks: a stone wall from the promenade (y 0.6) down to the
    water, a coping band, a dark waterline and a 12-deep promenade. Runs along local X (x 0..96);
    the water side faces -Z. Bollards attach at bollard_* sockets."""
    b = B2Builder(name)
    L, P = 96.0, 12.0
    b.face([V(0, CURB_H, 0), V(L, CURB_H, 0), V(L, CURB_H, P), V(0, CURB_H, P)], "quay_top", V(0, 1, 0))
    b.face([V(0, WATER_Y, 0), V(L, WATER_Y, 0), V(L, CURB_H - 0.6, 0), V(0, CURB_H - 0.6, 0)], "quay_stone", V(0, 0, -1))
    box(b, V(L / 2, CURB_H - 0.3, 0.2), (L, 0.9, 1.2), {"side": "quay_top", "top": "quay_top", "skip_bottom": True, "skip_back": True})
    b.face([V(0, WATER_Y, -0.05), V(L, WATER_Y, -0.05), V(L, WATER_Y + 2.2, -0.05), V(0, WATER_Y + 2.2, -0.05)], "quay_dark", V(0, 0, -1))
    b.face([V(0, WATER_Y, P), V(L, WATER_Y, P), V(L, CURB_H, P), V(0, CURB_H, P)], "quay_stone", V(0, 0, 1))
    sk = {f"bollard_{i + 1}": sock((12.0 + 24.0 * i, CURB_H, 1.6)) for i in range(4)}
    sk["start"] = sock((0, 0, 0))
    sk["end"] = sock((L, 0, 0))
    return b, {"family": "Harbor", "length": L, "promenade": P, "lod": "near", "district": "HB", "pivot": "quay edge start at road level (y 0); runs along +X, water at -Z", "sockets": sk}


def bridge_pier(name, W):
    """A stone bridge pier with pointed cutwaters (the river runs along X), from below the water
    to the deck girders, with a cap. Pivot at its top centre (the deck pieces' pier socket)."""
    d = dims(W)
    b = B2Builder(name)
    hl = d["frontage"] * 0.85
    top = 0.0
    bot = WATER_Y - 2.0 - (-7.0)
    out = [(-hl - 4.0, 0), (-hl, -3.5), (hl, -3.5), (hl + 4.0, 0), (hl, 3.5), (-hl, 3.5)]
    prism(b, out, bot, top - 1.2, "quay_stone", "quay_top")
    box(b, V(0, top - 0.6, 0), (2 * hl + 2.0, 1.2, 8.0), {"side": "quay_top", "top": "quay_top", "skip_bottom": True})
    prism(b, [(x * 1.01, z * 1.04) for x, z in out], bot, bot + 2.6, "quay_dark", top=False)
    return b, {"family": "Harbor", "laneWidth": W, "height": round(top - bot, 2), "lod": "near", "district": "HB", "pivot": "top centre (sits under the deck girders at the deck piece's pier socket)", "sockets": {"top": sock((0, 0, 0))}}


def bollard(name):
    b = B2Builder(name)
    cyl(b, V(0, 0, 0), 0.4, 1.1, 8, "iron", top=False)
    cyl(b, V(0, 0.4, 0), 1.6, 0.75, 8, "iron", top=False, r_top=0.65)
    cyl(b, V(0, 2.0, 0), 0.5, 1.05, 8, "iron_light", r_top=0.9)
    return b, {"family": "Harbor", "height": 2.5, "lod": "near", "district": "HB", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}}


def shed(name):
    """A small waterfront shed 24 x 16 x 10 with a gable roof and a big sliding door."""
    b = B2Builder(name)
    w, dd, h = 24.0, 16.0, 10.0
    box(b, V(0, h / 2, dd / 2), (w, h, dd), {"side": "shed_wall", "skip_bottom": True, "skip_top": True})
    for z in (0.0, dd):
        b.face([V(-w / 2, h, z), V(w / 2, h, z), V(0, h + 5.0, z)], "shed_wall", V(0, 0, -1 if z == 0 else 1))
    for sx in (-1, 1):
        b.face([V(sx * (w / 2 + 0.6), h - 0.3, -0.6), V(0, h + 5.0, -0.6), V(0, h + 5.0, dd + 0.6), V(sx * (w / 2 + 0.6), h - 0.3, dd + 0.6)], "shed_roof", V(sx * 0.6, 1, 0))
    fquad(b, -5.0, 5.0, 0.0, 8.0, 0.05, "container_1")
    fquad(b, -5.4, 5.4, 8.0, 8.5, 0.06, "shed_roof")
    return b, {"family": "Harbor", "size": [w, h + 5, dd], "lod": "mid", "district": "HB", "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}}


def dock_crane(name):
    """A small dock crane (navy-teal, not construction yellow): a portal gantry on four legs, a
    slewing house and a luffing jib raised 35 degrees, an A-frame and a hook block. 42 tall."""
    b = B2Builder(name)
    for sx in (-1, 1):
        for sz in (-1, 1):
            beam(b, V(sx * 5.0, 0, sz * 5.0), V(sx * 3.4, 14.0, sz * 3.4), 0.9, 0.9, "bridge_steel")
        beam(b, V(sx * 5.0, 1.0, -5.0), V(sx * 5.0, 1.0, 5.0), 0.6, 0.6, "bridge_steel_dark")
    box(b, V(0, 14.6, 0), (8.0, 1.2, 8.0), {"side": "bridge_steel_dark"})
    box(b, V(0, 17.8, 1.0), (6.0, 5.2, 8.0), {"side": "container_1", "top": "shed_roof", "front": "crane_glass", "skip_bottom": True})
    for sx in (-1, 1):
        beam(b, V(sx * 1.6, 20.4, 3.5), V(0, 27.0, 2.5), 0.35, 0.35, "bridge_steel")
    a = math.radians(35)
    jl = 30.0
    root = V(0, 18.0, -2.5)
    tip = root + V(0, math.sin(a) * jl, -math.cos(a) * jl)
    for sx in (-1, 1):
        beam(b, root + V(sx * 1.0, 0, 0), tip + V(sx * 0.3, 0, 0), 0.5, 0.5, "bridge_steel")
    for k in range(1, 5):
        p = root.lerp(tip, k / 5)
        beam(b, p + V(-0.9, 0, 0), p + V(0.9, 0, 0), 0.25, 0.25, "bridge_steel_dark")
    beam(b, V(0, 27.0, 2.5), tip, 0.12, 0.12, "iron")
    beam(b, tip, tip + V(0, -14.0, 0), 0.08, 0.08, "iron")
    box(b, tip + V(0, -15.0, 0), (1.2, 1.8, 1.0), {"side": "iron_light"})
    return b, {"family": "Harbor", "height": round(tip.y + 0.5, 1), "lod": "mid", "district": "HB", "pivot": "bottom centre of the gantry", "sockets": {"base": sock((0, 0, 0))}, "note": "waterfront only, beyond the frontage band; jib points to local -Z (toward the water)"}


def containers(name):
    """A stack of three shipping containers (20 x 8.6 x 8): two below, one across on top."""
    b = B2Builder(name)
    for (c, size, sw) in ((V(-5.0, 4.3, 0), (8.0, 8.6, 20.0), "container_1"), (V(4.0, 4.3, 0), (8.0, 8.6, 20.0), "container_2"), (V(0, 12.9, 0), (20.0, 8.6, 8.0), "container_3")):
        box(b, c, size, {"side": sw, "skip_bottom": True})
    for z in (-6.0, 0.0, 6.0):
        for x in (-9.05, 8.05):
            b.face([V(x, 0.6, z - 0.4), V(x, 0.6, z + 0.4), V(x, 8.0, z + 0.4), V(x, 8.0, z - 0.4)], "shed_roof", V(-1 if x < 0 else 1, 0, 0))
    return b, {"family": "Harbor", "size": [18, 17.2, 20], "lod": "mid", "district": "HB", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}}


# ---------------------------------------------------------------- hazards (B2 pothole and oil)
def blob(rng, rx, rz, n, lobes, amp, jitter=0.0):
    ph = rng.uniform(0, 6.28)
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 1 + sum(amp[i] * math.sin(lobes[i] * a + ph * (i + 1)) for i in range(len(lobes))) + (rng.uniform(-jitter, jitter) if jitter else 0)
        pts.append((math.cos(a) * rx * r, math.sin(a) * rz * r))
    return pts


def pothole(name):
    """A pothole that reads as a HOLE at the chase angle (research section 6): 4.4 across and
    5.8 along the road (stretched 1.3x), an irregular broken rim raised 0.22 and lighter than the
    asphalt, inner walls sloping down to a dark floor: the far wall (facing the camera) is a mid
    band, the walls to the sides are lit, and a shadow crescent lies on the floor under the near
    rim. Broken chunks on the rim, hairline cracks. The road slab is not cut."""
    rng = random.Random(seed_of(name))
    b = B2Builder(name)
    n = 14
    base = blob(rng, 2.2, 2.9, n, [3, 5], [0.08, 0.05], jitter=0.05)
    outer = [(x * 1.18, z * 1.18) for x, z in base]
    rim_i = [(x * 0.9, z * 0.9) for x, z in base]
    floor_ = [(x * 0.66, z * 0.66) for x, z in base]
    yr, yf = 0.22, 0.04
    for k in range(n):
        k2 = (k + 1) % n
        # outer skirt from the asphalt up to the rim top
        (ax, az), (cx, cz) = outer[k], outer[k2]
        (bx, bz), (dx, dz) = base[k], base[k2]
        b.face([V(ax, 0.0, az), V(cx, 0.0, cz), V(dx, yr, dz), V(bx, yr, bz)], "pot_chunk" if k % 3 == 0 else "pot_rim", V((ax + cx) / 2, 0.6, (az + cz) / 2))
        # rim top
        (ex, ez), (fx, fz) = rim_i[k], rim_i[k2]
        b.face([V(bx, yr, bz), V(dx, yr, dz), V(fx, yr, fz), V(ex, yr, ez)], "pot_rim" if k % 4 else "pot_chunk", V(0, 1, 0))
        # inner wall, coloured by which way it faces (+Z faces the chase camera behind)
        (gx, gz), (hx, hz) = floor_[k], floor_[k2]
        nrm = V(-(ex + fx) / 2, 0.0, -(ez + fz) / 2).normalized()
        sw = "pot_wall_lit" if nrm.z > 0.35 else ("pot_shadow" if nrm.z < -0.35 else "pot_wall")
        b.face([V(ex, yr, ez), V(fx, yr, fz), V(hx, yf, hz), V(gx, yf, gz)], sw, nrm + V(0, 0.8, 0))
    b.face([V(x, yf, z) for x, z in floor_], "pot_floor", V(0, 1, 0))
    # shadow crescent on the floor under the near (+Z) rim
    near = sorted(range(n), key=lambda k: -floor_[k][1])[:5]
    near.sort(key=lambda k: math.atan2(floor_[k][1], floor_[k][0]))
    pts = [floor_[k] for k in near]
    inner = [(x * 0.55, z * 0.55 - 0.15) for x, z in reversed(pts)]
    b.face([V(x, yf + 0.006, z) for x, z in pts + inner], "pot_shadow", V(0, 1, 0))
    for k in range(6):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(1.0, 1.15)
        c = V(math.cos(a) * 2.2 * r, 0.0, math.sin(a) * 2.9 * r)
        s = rng.uniform(0.25, 0.45)
        box(b, c + V(0, s * 0.3, 0), (s, s * 0.6, s * 1.3), {"top": "pot_chunk", "side": "pot_rim", "skip_bottom": True}, yaw=rng.uniform(0, 3))
    for a in (0.5, 2.2, 3.9, 5.2):
        p0 = V(math.cos(a) * 2.5, 0.012, math.sin(a) * 3.3)
        p1 = V(math.cos(a + 0.2) * 3.6, 0.012, math.sin(a + 0.2) * 4.4)
        side = V(-(p1.z - p0.z), 0, p1.x - p0.x).normalized() * 0.07
        b.face([p0 - side, p0 + side, p1], "pot_wall", V(0, 1, 0))
    return b, {"family": "Haz", "size": [4.4, 0.22, 5.8], "lod": "near", "district": "any", "pivot": "centre on the road surface", "sockets": {"centre": sock((0, 0, 0))}, "replaces": "Pothole", "read": "raised light rim, sloped inner walls, dark floor, shadow crescent; no flat circle", "clear_zone": "4-6 studs of quiet road around it, no lane decals"}


def oil_slick(name):
    """Oil that reads as oil, not neon: a lobed near-black pool 6.5 x 4.5, a glossy sky streak and
    a CONTROLLED iridescent edge: a thin, broken band (about 60% of the rim) whose muted teal,
    violet and gold fade into each other, plus a few drops. Render/Studio material: glossy
    (low roughness / Reflectance about 0.25)."""
    rng = random.Random(seed_of(name))
    b = B2Builder(name)
    n = 30
    outer = blob(rng, 3.25, 2.25, n, [3, 4, 7], [0.07, 0.05, 0.025])
    y = 0.025
    edge_o = [(x * 0.96, z * 0.96) for x, z in outer]
    edge_i = [(x * 0.9, z * 0.9) for x, z in outer]
    from kit_hazards import ring_band

    ring_band(b, outer, edge_o, y, "oil_black")
    cols = []
    seq = ["oil2_teal", "oil2_teal", "oil2_violet", "oil2_violet", "oil2_gold", "oil2_gold", "oil_black", "oil_black", "oil_black", "oil2_teal", "oil2_violet", "oil_black"]
    for k in range(n):
        cols.append(seq[(k * len(seq)) // n])
    ring_band(b, edge_o, edge_i, y + 0.001, cols)
    b.face([V(x, y, z) for x, z in edge_i], "oil_black", V(0, 1, 0))
    hl = [(-1.6, -0.6), (-0.3, -0.95), (1.2, -0.8), (1.4, -0.55), (-0.2, -0.6), (-1.3, -0.35)]
    b.face([V(x, y + 0.003, z) for x, z in hl], "oil2_gloss", V(0, 1, 0))
    for k in range(4):
        a = rng.uniform(0, 6.28)
        c = (math.cos(a) * 3.9, math.sin(a) * 2.8)
        r = rng.uniform(0.18, 0.32)
        b.face([V(c[0] + math.cos(t) * r, y, c[1] + math.sin(t) * r * 0.8) for t in [2 * math.pi * j / 6 for j in range(6)]], "oil_black", V(0, 1, 0))
    return b, {"family": "Haz", "size": [6.5, 0.03, 4.5], "lod": "near", "district": "any", "pivot": "centre on the road surface", "sockets": {"centre": sock((0, 0, 0))}, "replaces": "OilSlick", "material": "SmoothPlastic, Reflectance about 0.25 (needs EnvironmentSpecularScale > 0 for sheen); no Transparency"}


def construction_lot(name):
    """The construction grouping as a 48 x 24 lot (never on the carriageway): site dirt, a striped
    hoarding along the front (orange/white: construction is the ONLY place that pairing appears),
    a site office, a material stack, and the crane's socket at the back with its jib parallel to
    the road (yaw 90 in the lot frame: the jib runs along the frontage, away from the road)."""
    b = B2Builder(name)
    W, D = 48.0, 24.0
    hw = W / 2
    b.face([V(-hw, 0.4, 0), V(hw, 0.4, 0), V(hw, 0.4, D), V(-hw, 0.4, D)], "site_dirt", V(0, 1, 0))
    for i in range(4):
        x0 = -hw + 12.0 * i
        if i == 2:
            continue  # the site gate
        for x in (x0 + 0.3, x0 + 11.7):
            box(b, V(x, 3.2, 0.6), (0.25, 6.4, 0.25), {"side": "haz_white", "skip_bottom": True})
        for zf, nz in ((0.45, V(0, 0, -1)), (0.75, V(0, 0, 1))):
            kitlib.stripes(b, x0, 0.7, x0 + 12.0, 1.9, 0.9, ["haz_orange", "haz_white"], lambda u, v, zf=zf: V(u, v, zf), nz, slant=1.0)
        b.face2([V(x0, 2.0, 0.6), V(x0 + 12.0, 2.0, 0.6), V(x0 + 12.0, 6.0, 0.6), V(x0, 6.0, 0.6)], "fence_mesh")
    box(b, V(-14.0, 4.0, 18.0), (14.0, 7.2, 7.0), {"side": "crane_cab", "top": "concrete_block", "front": "crane_cab", "skip_bottom": True})
    fquad_world = [V(-10.0, 3.0, 14.48), V(-16.0, 3.0, 14.48), V(-16.0, 6.0, 14.48), V(-10.0, 6.0, 14.48)]
    b.face(fquad_world, "crane_glass", V(0, 0, -1))
    for k in range(3):
        box(b, V(12.0, 0.9 + 1.0 * k, 14.0 + 0.4 * k), (8.0 - k, 1.0, 4.0), {"side": "wood", "top": "wood_dark", "skip_bottom": True})
    sk = {"crane": sock((hw + 0.0, 0.4, 16.0), 90.0, mesh="B2_Haz_Crane", note="jib along the lot's +X (parallel to the road), never over the carriageway"), "cone_row": sock((hw, 0.6, -6.0), note="cones on the sidewalk side only when a lane closure is shown"), "gate": sock((hw + 6.0, 0.4, 0.6))}
    b.shift(hw)
    return b, {"family": "Haz", "module": "construction_lot", "facing": "-Z", "width": W, "depth": D, "lod": "near", "district": "any", "pivot": "front corner on the lot's own left (min x), ground level (lot frame)", "sockets": sk, "rule": "construction language (orange/white) reserved for hazards; crane outside clearance"}


# ---------------------------------------------------------------- skyline
def stadium(name):
    """The distant stadium (Midtown's skyline thumbnail), real size: an oval 320 x 240, a 34-tall
    outer wall in two pale tones, a flared rim band, an inward roof ring and four light masts to
    74. Pre-hazed pale swatches; about 200 triangles (a far landmark: above the 12-40 skyline
    block budget on purpose). Place it 500-900 studs from the road."""
    b = B2Builder(name)
    n = 20
    rx, rz = 160.0, 120.0

    def ring(s, y):
        return [V(math.cos(2 * math.pi * k / n) * rx * s, y, math.sin(2 * math.pi * k / n) * rz * s) for k in range(n)]

    rings = [ring(1.0, 0.0), ring(1.0, 34.0), ring(1.04, 40.0), ring(0.82, 44.0)]
    sws = ["stadium_2", "stadium_1", "stadium_1"]
    for i in range(3):
        a, c = rings[i], rings[i + 1]
        for k in range(n):
            k2 = (k + 1) % n
            q = [a[k], a[k2], c[k2], c[k]]
            cen = sum(q, V(0)) / 4
            b.face(q, sws[i] if (k % 2 or i != 0) else "stadium_1", V(cen.x, 0.4 if i == 2 else 0.0, cen.z) if i != 2 else V(0, 1, 0))
    b.face(ring(0.82, 43.9), "stadium_2", V(0, 1, 0))
    for k in range(4):
        a = math.pi / 4 + math.pi / 2 * k
        p = V(math.cos(a) * rx * 0.95, 40.0, math.sin(a) * rz * 0.95)
        beam(b, p, p + V(0, 30.0, 0), 1.6, 1.6, "stadium_2")
        box(b, p + V(0, 31.5, 0), (8.0, 4.0, 2.0), {"side": "stadium_light"}, yaw=-a + math.pi / 2)
    return b, {"family": "Sky", "landmark": "DISTANT STADIUM", "size": [2 * rx, 74.0, 2 * rz], "lod": "far", "district": "MT", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}, "band": "skyline 500-900 from the road edge"}


def spire(name):
    """A unit-sized skyline spire tower (scale [w, h, d] per instance): a body, one setback and a
    needle. 1 x 1 x 1, pivot at the bottom centre, pre-hazed sky swatches."""
    b = B2Builder(name)
    box(b, V(0, 0.33, 0), (1.0, 0.66, 1.0), {"side": "sky_2", "top": "sky_trim", "skip_bottom": True})
    box(b, V(0, 0.76, 0), (0.7, 0.2, 0.7), {"side": "sky_4", "top": "sky_trim", "skip_bottom": True})
    cyl(b, V(0, 0.86, 0), 0.14, 0.18, 4, "sky_trim", r_top=0.01, phase=math.pi / 4)
    return b, {"family": "Sky", "unit": True, "lod": "far", "district": "MT,MS", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}, "note": "scale [width, height, depth]"}


# ---------------------------------------------------------------- re-emitted shared recipes
def reuse(fn, name, family, district="any", lod="near", **kw):
    b, meta = fn(name, **kw) if kw else fn(name)
    m = {"family": family, "lod": lod, "district": district, "pivot": "bottom centre" if family != "Haz" else "centre on the surface it stands on", "sockets": {"base": sock((0, 0, 0))}, "recipe": f"{fn.__module__}.{fn.__name__} (overnight geometry, B2 palette)"}
    m.update(meta)
    return b, m


def build_all(emit):
    # sign family
    emit(*fascia("B2_Sign_WheelGoodPizza", "WHEEL GOOD PIZZA", 18.0, "sign_frame_2", "pizza"))
    emit(*fascia("B2_Sign_LugNutsHardware", "LUG NUTS HARDWARE", 20.0, "sign_frame_4", "nut"))
    emit(*fascia("B2_Sign_HubcapBooks", "HUBCAP BOOKS", 16.0, "sign_frame_3", "book"))
    emit(*fascia("B2_Sign_ParkBarkPets", "PARK & BARK PETS", 18.0, "sign_frame_5", "paw"))
    emit(*blade_sign("B2_Sign_BrakeFastDiner", "BRAKE-FAST DINER", 10.0, 3.6, "sign_frame_1", "cup"))
    emit(*blade_sign("B2_Sign_HonkRollMusic", "HONK & ROLL MUSIC", 10.0, 3.6, "sign_frame_3", "note"))
    emit(*corner_blade("B2_Sign_CornerBlade"))
    # spans
    for W in (16, 17, 18):
        emit(*bunting(f"B2_Span_Bunting_L4W{W}", W))
        emit(*welcome_span(f"B2_Span_Welcome_L4W{W}", W))
    # district furniture and park pieces
    emit(*formal_lamp("B2_Street_LampFormal"))
    emit(*hedge("B2_Park_Hedge12"))
    emit(*flower_bed("B2_Park_FlowerBed"))
    # shared street furniture, re-emitted on the B2 palette
    for fn, nm in ((kit_street.lamp, "B2_Street_Lamp"), (kit_street.lamp_lens, "B2_Street_LampLens"), (kit_street.planter, "B2_Street_Planter"), (kit_street.hydrant, "B2_Street_Hydrant"), (kit_street.bench, "B2_Street_Bench"), (kit_street.bus_stop, "B2_Street_BusStop"), (kit_street.bin_, "B2_Street_Bin"), (kit_street.bike_rack, "B2_Street_BikeRack"), (kit_street.traffic_light, "B2_Street_TrafficLight"), (kit_street.street_sign, "B2_Street_StreetSign"), (kit_street.bollard, "B2_Street_Bollard")):
        emit(*reuse(fn, nm, "Street"))
    emit(*reuse(kit_street.tree, "B2_Street_Tree", "Street"))
    emit(*reuse(kit_street.roof_ac, "B2_Prop_RoofAC", "Prop", "MS,MT,HB"))
    # harbor waterfront
    emit(*water("B2_Harbor_Water"))
    emit(*quay("B2_Harbor_Quay96"))
    for W in (16, 17, 18):
        emit(*bridge_pier(f"B2_Harbor_Pier_L4W{W}", W))
    emit(*bollard("B2_Harbor_Bollard"))
    emit(*shed("B2_Harbor_Shed24"))
    emit(*dock_crane("B2_Harbor_Crane"))
    emit(*containers("B2_Harbor_Containers"))
    # hazards: B2 pothole and oil, the construction lot, and the shared set re-emitted
    emit(*pothole("B2_Haz_Pothole"))
    emit(*oil_slick("B2_Haz_Oil"))
    emit(*construction_lot("B2_Haz_ConstructionLot48"))
    for fn, nm in ((kit_hazards.barrier, "B2_Haz_Barrier"), (kit_hazards.cone, "B2_Haz_Cone"), (kit_hazards.construction_sign, "B2_Haz_Sign"), (kit_hazards.crane, "B2_Haz_Crane"), (kit_hazards.site_fence, "B2_Haz_SiteFence")):
        emit(*reuse(fn, nm, "Haz"))
    # skyline
    emit(*stadium("B2_Sky_Stadium"))
    emit(*spire("B2_Sky_Spire"))
    for shape, fn in (("Slab", kit_skyline.slab), ("Stepped", kit_skyline.stepped), ("Tower", kit_skyline.tower)):
        for i, (body_sw, cap) in enumerate((("sky_1", "sky_trim"), ("sky_2", "sky_3"), ("sky_4", "sky_trim"))):
            b, meta = fn(f"B2_Sky_{shape}_{i + 1}", body_sw, cap)
            meta.update({"family": "Sky", "lod": "far", "district": "any", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}})
            emit(b, meta)
