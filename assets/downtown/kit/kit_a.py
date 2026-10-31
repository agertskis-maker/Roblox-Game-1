# Downtown kit, direction A "Sunny Toy City": cheerful 2 to 4 storey facades in coral, mint,
# butter, sky and lilac with cream trims; softened (rounded) corners, striped scalloped awnings,
# arched and round windows, simple parapets with a playful crest, toy-like round corner turrets
# with cone caps. Depth 14 (research O9: A 12 to 16). Landmark: the DONUT DISTURB bakery with a
# sculptural upright rooftop donut turned 50 degrees toward oncoming traffic, so the circle reads
# before the text. Colourways are separate meshes (suffix _1 coral, _2 mint, _3 butter, _4 sky,
# _5 lilac, _q quiet cream for facades near hazards).

import math
import random

from kitlib import Builder, V, box, cyl, fp, opening, prism, rounded_rect2, sphere, wall_with_holes
from kit_facade import (
    BASE_H,
    STOREY,
    band,
    body,
    circle_uv,
    display,
    offset_outline,
    parapet_ring,
    plate,
    rrect_uv,
    roof_slab,
    shopfront,
    sign_face_record,
    upper,
    awning_striped,
)

D = 14.0
STYLE = {
    "D": D,
    "win_shape_base": "arch",
    "win_shape": "arch",
    "door_shape": "arch",
    "recess": 1.6,
    "door_recess": 1.6,
    "awning": "striped",
    "scallop": True,
    "display": "cakes",
    "win_w": 3.4,
    "win_v": (2.6, 9.4),
    "floor_band": "trim_1",
    "plinth": "wall_base",
    "pilaster_sw": "trim_1",
}

COLOURWAYS = {
    "1": {"wall": "wall_1", "awa": "aw2_a", "awb": "aw2_b", "acc": "accent_2", "shop": "frame", "reveal": "reveal"},
    "2": {"wall": "wall_2", "awa": "aw1_a", "awb": "aw1_b", "acc": "accent_1", "shop": "frame", "reveal": "reveal"},
    "3": {"wall": "wall_3", "awa": "aw3_a", "awb": "aw2_b", "acc": "accent_3", "shop": "frame", "reveal": "reveal"},
    "4": {"wall": "wall_4", "awa": "aw1_a", "awb": "aw1_b", "acc": "accent_2", "shop": "frame", "reveal": "reveal"},
    "5": {"wall": "wall_5", "awa": "aw2_a", "awb": "aw2_b", "acc": "accent_2", "shop": "frame", "reveal": "reveal"},
    "q": {"wall": "wall_6", "awa": "wall_base", "awb": "aw2_b", "acc": "trim_3", "shop": "frame", "reveal": "reveal"},
}


def seed_of(name):
    return sum(map(ord, name)) * 13 + len(name)


def base(name, w, cw):
    b = Builder(name, COLOURWAYS[cw])
    info = shopfront(b, w, STYLE)
    return b, {"module": "base", "width": w, "height": BASE_H, "depth": D, "colourway": cw, **info}


def mid(name, w, cw, round_windows=False):
    b = Builder(name, COLOURWAYS[cw])
    upper(b, w, STYLE, round_windows=round_windows)
    return b, {"module": "mid", "width": w, "height": STOREY, "depth": D, "colourway": cw}


def top(name, w, cw):
    """Parapet 3.2 tall with a rounded cream cap, lower side and back parapets, a flat roof and,
    on the 24 module, a semicircular crest with an accent medallion."""
    b = Builder(name, COLOURWAYS[cw])
    hw = w / 2
    roof_slab(b, [(-hw, 0), (hw, 0), (hw, D), (-hw, D)], 0.3)
    # front parapet (thick, the facade's top) and its rounded cap
    box(b, V(0, 1.6, 0.4), (w, 3.2, 0.8), "wall")
    from kitlib import sweep

    sweep(b, [(3.2, -0.25), (3.55, -0.2), (3.7, 0.4), (3.55, 1.0), (3.2, 1.05)], hw + 0.15, -hw - 0.15, "trim_1")
    # side and back parapets
    for x in (-hw + 0.3, hw - 0.3):
        box(b, V(x, 0.9, D / 2 + 0.4), (0.6, 1.8, D - 0.8), {"side": "wall", "top": "trim_1"})
    box(b, V(0, 0.9, D - 0.3), (w - 1.2, 1.8, 0.6), {"side": "wall", "top": "trim_1"})
    if w >= 24:
        r = 3.0
        crest = [(math.cos(math.pi * k / 8) * r, 3.4 + math.sin(math.pi * k / 8) * r) for k in range(9)]
        plate(b, crest, -0.5, 0.15, "wall", "trim_1", "wall")
        # medallion
        plate(b, circle_uv(0, 4.9, 1.2, 10), 0.15, 0.4, "acc", "trim_1")
        plate(b, circle_uv(0, 4.9, 0.55, 8), 0.4, 0.5, "trim_1")
    else:
        # a small rounded bump
        r = 1.6
        crest = [(math.cos(math.pi * k / 6) * r, 3.4 + math.sin(math.pi * k / 6) * r) for k in range(7)]
        plate(b, crest, -0.5, 0.15, "wall", "trim_1", "wall")
    return b, {"module": "top", "width": w, "height": 6.4 if w >= 24 else 5.0, "depth": D, "colourway": cw, "roof_y": 0.3}


CR = 3.5  # the corner turret's rounding radius


def corner_outline():
    return rounded_rect2(-6, 0, 6, D, CR, seg=4, corners=(True, True, False, False))


def corner(name, part, cw):
    """A 12-wide end bay with rounded front corners (symmetric, so it caps either end of a
    block). part: base (arched door), mid (round window, porthole medallions on the sides) or
    top (rounded parapet and a cone cap with a ball finial)."""
    b = Builder(name, COLOURWAYS[cw])
    ol = corner_outline()
    if part == "base":
        H = BASE_H
        flat = 6 - CR
        wall_with_holes(b, -flat, flat, 0, H, [(-1.9, 1.9, 0, 9.6)], "wall")
        opening(b, -1.9, 1.9, 0, 9.6, "arch", 1.6, "wall", "reveal", "door")
        box(b, fp(0, 4.8, -1.54), (2.0, 3.6, 0.1), "glass_light")
        body(b, 12, 0, H, D, outline=ol)
        prism(b, offset_outline(ol, 0.18), 0, 1.0, "wall_base", "wall_base")
        prism(b, offset_outline(ol, 0.4), H - 0.7, H, "trim_1", "trim_1", bottom=True)
        # small arched windows on the curved shoulders, faked as proud frames
        for sx in (-1, 1):
            c = V(sx * 5.2, 6.5, 1.4)
            box(b, c, (0.3, 4.0, 1.6), {"side": "glass", "top": "trim_1"}, yaw=sx * 0.7)
        h = H
    elif part == "mid":
        H = STOREY
        flat = 6 - CR
        wall_with_holes(b, -flat, flat, 0, H, [(-2.0, 2.0, 4.0, 8.0)], "wall")
        opening(b, -2.0, 2.0, 4.0, 8.0, "round", 0.9, "wall", "reveal", "glass")
        body(b, 12, 0, H, D, outline=ol)
        prism(b, offset_outline(ol, 0.22), 0, 0.45, "trim_1", "trim_1", bottom=True)
        for sx in (-1, 1):
            # porthole medallions on the two side walls
            for z in (6.0, 10.5):
                c = V(sx * 6.05, 6.0, z)
                ring_pts = [c + V(0, math.cos(2 * math.pi * k / 10) * 1.6, math.sin(2 * math.pi * k / 10) * 1.6) for k in range(10)]
                b.face(ring_pts, "trim_1", V(sx, 0, 0))
                inner = [c + V(sx * 0.05, math.cos(2 * math.pi * k / 10) * 1.15, math.sin(2 * math.pi * k / 10) * 1.15) for k in range(10)]
                b.face(inner, "glass", V(sx, 0, 0))
        h = H
    else:
        roof_slab(b, ol, 0.3)
        parapet_ring(b, ol, 0, 2.2, 0.6, "wall", "trim_1")
        cyl(b, V(0, 0.3, D / 2 - 1), 1.2, 4.2, 10, "trim_1", top=False)
        cyl(b, V(0, 1.5, D / 2 - 1), 7.0, 4.9, 10, "acc", r_top=0.0)
        sphere(b, V(0, 9.0, D / 2 - 1), (0.75, 0.75, 0.75), ["trim_1", "trim_1"], subdiv=1)
        h = 9.8
    return b, {"module": "corner_" + part, "width": 12, "height": h, "depth": D, "colourway": cw, "symmetric": True}


# ---------------------------------------------------------------- roof props
def roof_vent(name):
    b = Builder(name)
    cyl(b, V(0, 0, 0), 2.2, 0.9, 8, "vent")
    sphere(b, V(0, 2.2, 0), (1.1, 0.8, 1.1), ["vent_dark", "vent", "vent"], subdiv=1)
    box(b, V(0, 0.15, 0), (2.4, 0.3, 2.4), "vent_dark")
    return b, {"height": 3.0}


# ---------------------------------------------------------------- midground
def mid_mass(name, height, sw):
    """A simpler, taller midground block: 36 x height x 24, window bands per storey (three
    recessed groups), a rounded top along its width."""
    b = Builder(name, {"wall": sw})
    w, d = 36.0, 24.0
    hw = w / 2
    floors = int((height - 8) // 12)
    holes = []
    for f in range(floors):
        v0 = 6 + f * 12
        for c in (-11.5, 0, 11.5):
            holes.append((c - 4.5, c + 4.5, v0, v0 + 5.5))
    wall_with_holes(b, -hw, hw, 0, height, holes, "wall")
    for (a, c, v0, v1) in holes:
        opening(b, a, c, v0, v1, "rect", 0.5, "wall", "mid_window", "mid_window")
    body(b, w, 0, height, d)
    # rounded roof along x
    n = 6
    pts = [(math.cos(math.pi * k / n) * d / 2, height + math.sin(math.pi * k / n) * 5.0) for k in range(n + 1)]
    for k in range(n):
        (z0, y0), (z1, y1) = pts[k], pts[k + 1]
        b.face([V(-hw, y0, d / 2 + z0), V(hw, y0, d / 2 + z0), V(hw, y1, d / 2 + z1), V(-hw, y1, d / 2 + z1)], "sky_trim", V(0, (y0 + y1) / 2 - height, (z0 + z1) / 2))
    for x in (-hw, hw):
        b.face([V(x, y, d / 2 + z) for z, y in pts], "wall", V(x, 0, 0))
    return b, {"module": "midground", "width": w, "height": height + 5, "depth": d}


# ---------------------------------------------------------------- signs (blank faces; text by SurfaceGui)
def sign_pizza(name):
    """WHEEL GOOD PIZZA: a coral rounded board with a pizza-wheel disc at its left end."""
    b = Builder(name)
    plate(b, rrect_uv(-7.5, 0, 7.5, 3.4, 1.2), 0, 0.35, "sign_frame_1")
    plate(b, rrect_uv(-4.4, 0.45, 6.9, 2.95, 0.6), 0.35, 0.45, "sign_face")
    cu = -5.6
    plate(b, circle_uv(cu, 1.7, 2.3, 16), 0.35, 0.75, "donut_dough")
    plate(b, circle_uv(cu, 1.7, 1.85, 16), 0.75, 0.85, "sprinkle_1")
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        plate(b, circle_uv(cu + math.cos(a) * 1.05, 1.7 + math.sin(a) * 1.05, 0.38, 8), 0.85, 0.92, "signal_red")
    # wheel spokes: thin crust-coloured lines from the hub
    for k in range(6):
        a = math.pi * k / 3
        plate(b, [(cu + math.cos(a) * 0.2 - math.sin(a) * 0.07, 1.7 + math.sin(a) * 0.2 + math.cos(a) * 0.07), (cu + math.cos(a) * 1.8, 1.7 + math.sin(a) * 1.8), (cu + math.cos(a) * 0.2 + math.sin(a) * 0.07, 1.7 + math.sin(a) * 0.2 - math.cos(a) * 0.07)], 0.85, 0.9, "donut_dough")
    return b, {"business": "WHEEL GOOD PIZZA", "faces": [sign_face_record("main", 1.25, 1.7, 0.45, 11.3, 2.5)], "size": [15.0, 3.4], "mount": "sign band, back on the facade"}


def sign_donut(name):
    """DONUT DISTURB: an arched pink-and-cream board for the bakery's sign band."""
    b = Builder(name)
    outline = [(-8, 0), (8, 0), (8, 2.6)]
    for k in range(1, 12):
        a = math.pi * k / 12
        outline.append((math.cos(a) * 8, 2.6 + math.sin(a) * 2.2))
    outline.append((-8, 2.6))
    plate(b, outline, 0, 0.35, "donut_icing", "sign_frame_1")
    plate(b, rrect_uv(-6.4, 0.5, 6.4, 3.2, 0.7), 0.35, 0.45, "sign_face")
    for k in range(9):
        a = math.pi * (k + 0.5) / 9
        plate(b, circle_uv(math.cos(a) * 7.0, 2.6 + math.sin(a) * 1.75, 0.22, 6), 0.35, 0.42, ["sprinkle_1", "sprinkle_2", "sprinkle_3", "sprinkle_4"][k % 4])
    return b, {"business": "DONUT DISTURB", "faces": [sign_face_record("main", 0, 1.85, 0.45, 12.8, 2.7)], "size": [16.0, 4.8]}


def sign_nap(name):
    """TIRED? NAP HOTEL: a tall blade sign projecting from the wall (local -Z), faces on both
    sides (+X and -X), a crescent moon on top."""
    b = Builder(name)
    t = 0.5
    # blade outline in (z, y): from the wall out to 4.2, 11 tall, rounded outer corners
    ol = rounded_rect2(-4.4, 0, -0.9, 11.0, 1.0, seg=3)
    for sx in (-1, 1):
        b.face([V(sx * t / 2, y, z) for z, y in ol], "sign_frame_3", V(sx, 0, 0))
    n = len(ol)
    for i in range(n):
        (z0, y0), (z1, y1) = ol[i], ol[(i + 1) % n]
        b.face([V(-t / 2, y0, z0), V(t / 2, y0, z0), V(t / 2, y1, z1), V(-t / 2, y1, z1)], "sign_frame_3", V(0, (y0 + y1) / 2 - 5.5, (z0 + z1) / 2 + 2.65))
    for sx in (-1, 1):
        inner = rounded_rect2(-3.9, 1.0, -1.4, 9.0, 0.5, seg=2)
        b.face([V(sx * (t / 2 + 0.06), y, z) for z, y in inner], "sign_face", V(sx, 0, 0))
    # mounting arms
    for y in (2.0, 9.0):
        box(b, V(0, y, -0.45), (0.25, 0.25, 0.9), "iron")
    # crescent moon: an outer circle minus an offset circle, as a polygon
    cz, cy, R = -2.65, 13.0, 2.0
    pts = []
    for k in range(13):
        a = math.radians(40 + 280 * k / 12)
        pts.append((cz + math.cos(a) * R, cy + math.sin(a) * R))
    for k in range(12, -1, -1):
        a = math.radians(40 + 280 * k / 12)
        pts.append((cz + 0.9 + math.cos(a) * R * 0.78, cy + math.sin(a) * R * 0.78))
    for sx in (-1, 1):
        b.face([V(sx * 0.35, y, z) for z, y in pts], "sprinkle_1", V(sx, 0, 0))
    m = len(pts)
    for i in range(m):
        (z0, y0), (z1, y1) = pts[i], pts[(i + 1) % m]
        b.face([V(-0.35, y0, z0), V(0.35, y0, z0), V(0.35, y1, z1), V(-0.35, y1, z1)], "sprinkle_1", V(0, y0 - cy, z0 - cz))
    box(b, V(0, 11.1, -2.65), (0.3, 0.6, 0.3), "iron")
    return b, {
        "business": "TIRED? NAP HOTEL",
        "faces": [
            {"name": "left", "centre": [-0.31, 5.0, -2.65], "size": [2.5, 8.0], "normal": "Left", "text": "vertical"},
            {"name": "right", "centre": [0.31, 5.0, -2.65], "size": [2.5, 8.0], "normal": "Right", "text": "vertical"},
        ],
        "size": [0.5, 15.0, 4.4],
        "mount": "blade: back edge on the facade, projecting toward the street",
    }


def sign_wash(name):
    """SUDS & SPOKES CAR WASH: a sky-blue board with bubble discs bursting off its top edge."""
    b = Builder(name)
    plate(b, rrect_uv(-8, 0, 8, 3.2, 1.4), 0, 0.35, "sign_frame_3")
    plate(b, rrect_uv(-7.2, 0.45, 7.2, 2.75, 0.8), 0.35, 0.45, "sign_face")
    for (cu, cv, r, sw) in ((-6.2, 3.4, 1.3, "sprinkle_3"), (-4.3, 3.9, 0.9, "sprinkle_2"), (5.6, 3.5, 1.5, "sprinkle_3"), (7.4, 4.4, 0.7, "sprinkle_2"), (3.7, 3.6, 0.6, "sprinkle_3")):
        plate(b, circle_uv(cu, cv, r, 12), 0.2, 0.55, sw, "sign_frame_3")
        plate(b, circle_uv(cu - r * 0.3, cv + r * 0.3, r * 0.25, 6), 0.55, 0.6, "sprinkle_3")
    return b, {"business": "SUDS & SPOKES CAR WASH", "faces": [sign_face_record("main", 0, 1.6, 0.45, 14.4, 2.3)], "size": [16.0, 5.1]}


def sign_diner(name):
    """BRAKE-FAST DINER: a mint board with a steaming cup on the right."""
    b = Builder(name)
    plate(b, rrect_uv(-7.5, 0, 7.5, 3.4, 1.0), 0, 0.35, "sign_frame_2")
    plate(b, rrect_uv(-6.9, 0.45, 3.6, 2.95, 0.6), 0.35, 0.45, "sign_face")
    cu = 5.4
    plate(b, [(cu - 1.3, 3.0), (cu + 1.3, 3.0), (cu + 0.9, 0.7), (cu - 0.9, 0.7)], 0.35, 0.8, "sprinkle_3", "sign_frame_2")
    # handle ring as a few segments
    for k in range(6):
        a0 = -math.pi / 2 + math.pi * k / 6
        a1 = -math.pi / 2 + math.pi * (k + 1) / 6
        r0, r1 = 0.45, 0.8
        c = (cu + 1.15, 1.95)
        plate(b, [(c[0] + math.cos(a0) * r0, c[1] + math.sin(a0) * r0), (c[0] + math.cos(a0) * r1, c[1] + math.sin(a0) * r1), (c[0] + math.cos(a1) * r1, c[1] + math.sin(a1) * r1), (c[0] + math.cos(a1) * r0, c[1] + math.sin(a1) * r0)], 0.35, 0.7, "sprinkle_3")
    for du in (-0.5, 0.4):
        plate(b, [(cu + du - 0.15, 3.3), (cu + du + 0.15, 3.3), (cu + du + 0.35, 4.3), (cu + du + 0.05, 4.3)], 0.35, 0.45, "sprinkle_3")
    return b, {"business": "BRAKE-FAST DINER", "faces": [sign_face_record("main", -1.65, 1.7, 0.45, 10.3, 2.5)], "size": [15.0, 4.3]}


# ---------------------------------------------------------------- landmark: DONUT DISTURB bakery
def donut(b, centre, R, r, yaw_deg, seg=20, minor=8, rng=None):
    """An upright donut (the hole faces local -Z before turning by yaw). Icing covers the front
    and the rim with uneven drips; sprinkles sit on the icing."""
    cs, sn = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    c = V(*centre)

    def P(a, t, rr=r):
        x = math.cos(a) * (R + rr * math.cos(t))
        y = math.sin(a) * (R + rr * math.cos(t))
        z = -rr * math.sin(t)
        # yaw about +Y: x' = x cos + z sin, z' = -x sin + z cos
        return c + V(x * cs + z * sn, y, -x * sn + z * cs)

    drip = [rng.uniform(-0.35, 0.25) for _ in range(seg)] if rng else [0] * seg
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        for j in range(minor):
            t0, t1 = 2 * math.pi * j / minor, 2 * math.pi * (j + 1) / minor
            tm = (t0 + t1) / 2
            q = [P(a0, t0), P(a1, t0), P(a1, t1), P(a0, t1)]
            am = (a0 + a1) / 2
            ring_c = c + V(math.cos(am) * R * cs, math.sin(am) * R, -math.cos(am) * R * sn)
            cen = sum(q, V(0)) / 4
            front = math.sin(tm)
            sw = "donut_icing" if front > -0.25 + drip[i] else "donut_dough"
            if sw == "donut_icing" and front > 0.85 and (i % 3 == 0):
                sw = "donut_icing_hi"
            b.face(q, sw, cen - ring_c)
    # sprinkles on the front of the icing
    if rng:
        cols = ["sprinkle_1", "sprinkle_2", "sprinkle_3", "sprinkle_4"]
        for k in range(34):
            a = rng.uniform(0, 2 * math.pi)
            t = rng.uniform(0.6, 2.5)
            p = P(a, t, r + 0.05)
            box(b, p, (0.9, 0.3, 0.3), cols[k % 4], yaw=rng.uniform(0, 3.1))


def donut_bakery(name):
    """36 wide, 18 deep: arched display windows with cake stands, a scalloped pink awning, an
    upper storey of round windows, a cream parapet, and on the roof a cream plinth holding the
    upright donut (19.6 across, centre 13 above the roof). Front faces local -Z."""
    rng = random.Random(seed_of(name))
    remap = {"wall": "wall_1", "awa": "aw1_a", "awb": "aw1_b", "shop": "frame", "reveal": "reveal", "acc": "accent_1"}
    b = Builder(name, remap)
    w, Dd = 36.0, 18.0
    hw = w / 2
    H0, H1 = 16.0, 12.0
    wins = [(-16.4, -8.4), (-6.0, -2.4), (2.4, 6.0), (8.4, 16.4)]
    door = (-1.9, 1.9)
    holes = [(-16.4, -8.4, 1.4, 10.4), (8.4, 16.4, 1.4, 10.4), (-6.2, -2.6, 2.0, 8.4), (2.6, 6.2, 2.0, 8.4), (door[0], door[1], 0, 9.6)]
    wall_with_holes(b, -hw, hw, 0, H0, holes, "wall")
    for k, (a, c, v0, v1) in enumerate(holes[:4]):
        opening(b, a, c, v0, v1, "arch", 1.8, "wall", "reveal", "glass")
        box(b, fp((a + c) / 2, v0 - 0.05, -0.9), (c - a, 0.1, 1.8), "shelf")
        n = 2 if c - a > 6 else 1
        for j in range(n):
            display(b, "cakes", a + (c - a) * (j + 0.5) / n, v0, -1.2, k * 2 + j)
    opening(b, door[0], door[1], 0, 9.6, "arch", 1.8, "wall", "reveal", "door")
    box(b, fp(0, 4.8, -1.74), (2.0, 3.6, 0.1), "glass_light")
    band(b, -hw, hw, 0, 1.0, 0.2, "trim_1")
    awning_striped(b, -hw + 1, hw - 1, 11.6, 1.6, 4.6, scallop=True)
    band(b, -hw + 1, hw - 1, 11.9, 12.2, 0.3, "trim_1")
    band(b, -hw, hw, H0 - 0.7, H0, 0.5, "trim_1")
    body(b, w, 0, H0 + H1, Dd)
    # upper storey: five round windows
    holes = [(c - 2.0, c + 2.0, H0 + 4.0, H0 + 8.0) for c in (-14, -7, 0, 7, 14)]
    wall_with_holes(b, -hw, hw, H0, H0 + H1, holes, "wall")
    for a, c, v0, v1 in holes:
        opening(b, a, c, v0, v1, "round", 0.9, "wall", "reveal", "glass")
    # parapet with a rounded cap, roof
    top = H0 + H1
    box(b, V(0, top + 1.6, 0.4), (w, 3.2, 0.8), "trim_1")
    from kitlib import sweep

    sweep(b, [(top + 3.2, -0.25), (top + 3.55, -0.2), (top + 3.7, 0.4), (top + 3.55, 1.0), (top + 3.2, 1.05)], hw + 0.15, -hw - 0.15, "wall")
    b.face([V(-hw, top + 0.3, 0), V(hw, top + 0.3, 0), V(hw, top + 0.3, Dd), V(-hw, top + 0.3, Dd)], "roof", V(0, 1, 0))
    for x in (-hw + 0.3, hw - 0.3):
        box(b, V(x, top + 0.9, Dd / 2 + 0.4), (0.6, 1.8, Dd - 0.8), {"side": "wall", "top": "trim_1"})
    box(b, V(0, top + 0.9, Dd - 0.3), (w - 1.2, 1.8, 0.6), {"side": "wall", "top": "trim_1"})
    # rooftop plinth and the donut
    box(b, V(0, top + 1.5, 7.5), (14.0, 2.4, 7.0), {"side": "trim_1", "top": "wall"})
    box(b, V(0, top + 3.0, 7.5), (12.5, 0.6, 6.0), "accent_2")
    for x in (-4.0, 4.0):
        box(b, V(x, top + 5.2, 7.5), (1.0, 4.0, 1.0), "trim_1")
    donut(b, (0, top + 13.4, 7.5), 7.0, 2.8, 50.0, seg=22, minor=8, rng=rng)
    return b, {
        "landmark": "DONUT DISTURB bakery",
        "width": w,
        "depth": Dd,
        "height": top + 23.3,
        "donut": {"centre": [0, top + 13.4, 7.5], "outer_diameter": 19.6, "turned_deg": 50, "note": "faces toward local -Z/-X: place on the road's right side so it greets oncoming traffic"},
        "sign_band": [12.3, 15.2],
    }


def build_all(emit):
    for cw in ("1", "2", "3", "4", "q"):
        emit(*base(f"A_Base24_{cw}", 24, cw), "A/building", "A")
        emit(*base(f"A_Base12_{cw}", 12, cw), "A/building", "A")
        emit(*mid(f"A_Mid24_{cw}", 24, cw), "A/building", "A")
        emit(*mid(f"A_Mid12_{cw}", 12, cw), "A/building", "A")
        emit(*top(f"A_Top24_{cw}", 24, cw), "A/building", "A")
        emit(*top(f"A_Top12_{cw}", 12, cw), "A/building", "A")
    for cw in ("2", "3"):
        emit(*mid(f"A_MidRound24_{cw}", 24, cw, round_windows=True), "A/building", "A")
    for cw in ("5", "4"):
        for part in ("base", "mid", "top"):
            emit(*corner(f"A_Corner{part.capitalize()}_{cw}", part, cw), "A/building", "A")
    emit(*roof_vent("A_RoofVent"), "A/roof", "A")
    for i, sw in enumerate(("mid_1", "mid_2", "mid_3", "mid_4")):
        emit(*mid_mass(f"A_MidLow_{i + 1}", 44.0, sw), "A/midground", "A")
        emit(*mid_mass(f"A_MidTall_{i + 1}", 68.0, sw), "A/midground", "A")
    emit(*sign_pizza("A_SignPizza"), "A/sign", "A")
    emit(*sign_donut("A_SignDonut"), "A/sign", "A")
    emit(*sign_nap("A_SignNap"), "A/sign", "A")
    emit(*sign_wash("A_SignWash"), "A/sign", "A")
    emit(*sign_diner("A_SignDiner"), "A/sign", "A")
    emit(*donut_bakery("A_DonutBakery"), "A/landmark", "A")
