# Downtown kit, direction B "Bright Real City": warm brick upper floors over cream-stone or
# painted shop bases, big recessed shop windows with transoms and shelves, recessed doors (2.0),
# plain canvas awnings in teal/orange/green, stone lintels and sills, stepped cornices on brackets,
# quoined corners, restrained fire escapes, rooftop water tanks and AC, and an occasional glass
# tower behind. Depth 20 (research O9: B 16 to 24). Landmark: the corner movie theater (REEL
# WHEELS CINEMA) with a deep canopy, a tall vertical blade sign, a stepped corner tower and
# original geometric poster panels. Colourways: _1 warm brick, _2 ochre brick, _3 brown brick,
# _4 painted teal, _5 painted mustard, _q quiet cream stone.

import math

from kitlib import Builder, V, beam, box, cyl, fface, fp, opening, prism, sweep, wall_with_holes
from kit_facade import (
    BASE_H,
    STOREY,
    band,
    body,
    circle_uv,
    plate,
    rrect_uv,
    roof_slab,
    shopfront,
    sign_face_record,
    upper,
)

D = 20.0
STYLE = {
    "D": D,
    "win_shape_base": "rect",
    "win_shape": "rect",
    "door_shape": "rect",
    "recess": 1.3,
    "door_recess": 2.0,
    "awning": "flat",
    "display": "shelves",
    "win_w": 3.2,
    "win_v": (2.4, 9.0),
    "course": "brick_course",
    "lintel": "trim_1",
    "sill_sw": "trim_1",
    "plinth": "trim_3",
    "pilaster_sw": "base_stone",
    "base_wall": "base_stone",
    "top_band_out": 0.7,
}

COLOURWAYS = {
    "1": {"wall": "wall_1", "base_stone": "wall_4", "shop": "accent_1", "awa": "aw2_a", "awb": "aw2_b", "reveal": "reveal"},
    "2": {"wall": "wall_2", "base_stone": "wall_4", "shop": "trim_2", "awa": "aw1_a", "awb": "aw1_b", "reveal": "reveal"},
    "3": {"wall": "wall_3", "base_stone": "wall_4", "shop": "accent_2", "awa": "aw3_a", "awb": "aw3_b", "reveal": "reveal"},
    "4": {"wall": "wall_5", "base_stone": "wall_5", "shop": "trim_1", "awa": "aw2_a", "awb": "aw2_b", "reveal": "reveal"},
    "5": {"wall": "wall_6", "base_stone": "wall_6", "shop": "accent_1", "awa": "aw1_a", "awb": "aw1_b", "reveal": "reveal"},
    "q": {"wall": "wall_4", "base_stone": "wall_base", "shop": "trim_3", "awa": "awning_under", "awb": "trim_1", "reveal": "reveal"},
}


def base(name, w, cw):
    b = Builder(name, COLOURWAYS[cw])
    info = shopfront(b, w, STYLE)
    return b, {"module": "base", "width": w, "height": BASE_H, "depth": D, "colourway": cw, **info}


def mid(name, w, cw):
    b = Builder(name, COLOURWAYS[cw])
    upper(b, w, STYLE)
    return b, {"module": "mid", "width": w, "height": STOREY, "depth": D, "colourway": cw}


CORNICE = [(1.0, 0.05), (1.0, -0.4), (1.6, -0.4), (1.6, -0.9), (2.2, -0.9), (2.2, -1.5), (2.8, -1.5), (2.8, 0.05)]


def cornice_front(b, hw, swatch="trim_1"):
    sweep(b, CORNICE, -hw - 0.6, hw + 0.6, swatch)
    # brackets under the lowest step, every 3 studs
    n = int((2 * hw) // 3)
    for i in range(n + 1):
        u = -hw + 0.6 + (2 * hw - 1.2) * i / n
        box(b, fp(u, 0.6, 0.2), (0.45, 0.8, 0.4), swatch)


def top(name, w, cw):
    """A frieze, a three-step cornice on brackets, a brick parapet with stone coping, a flat
    roof and low side and back parapets."""
    b = Builder(name, COLOURWAYS[cw])
    hw = w / 2
    roof_slab(b, [(-hw, 0), (hw, 0), (hw, D), (-hw, D)], 0.3)
    box(b, fp(0, 0.5, -0.4), (w, 1.0, 0.8), "trim_3")
    cornice_front(b, hw)
    box(b, V(0, 3.4, 0.4), (w, 1.2, 0.8), "wall")
    box(b, V(0, 4.1, 0.4), (w + 0.3, 0.25, 1.1), "trim_1")
    for x in (-hw + 0.3, hw - 0.3):
        box(b, V(x, 1.0, D / 2 + 0.4), (0.6, 2.0, D - 0.8), {"side": "wall", "top": "trim_1"})
    box(b, V(0, 1.0, D - 0.3), (w - 1.2, 2.0, 0.6), {"side": "wall", "top": "trim_1"})
    # side returns of the cornice
    return b, {"module": "top", "width": w, "height": 4.25, "depth": D, "colourway": cw, "roof_y": 0.3}


def quoins(b, u, v0, v1, side_x, swatch="base_stone"):
    """Alternating stone blocks on a front corner (u on the facade) and its side wall."""
    v = v0
    k = 0
    while v + 1.4 <= v1 + 1e-6:
        w = 1.8 if k % 2 == 0 else 1.1
        sgn = 1 if u > 0 else -1
        box(b, fp(u - sgn * w / 2, v + 0.65, 0.12), (w, 1.3, 0.24), swatch)
        box(b, V(side_x + (0.12 if side_x > 0 else -0.12), v + 0.65, w / 2), (0.24, 1.3, w), swatch)
        v += 1.5
        k += 1


def corner(name, part, cw):
    """A 12-wide end bay with quoins on both front corners (symmetric, caps either end of a
    block). base: stone, recessed door; mid: two windows and blind side windows; top: cornice
    returns and a stepped pediment."""
    b = Builder(name, COLOURWAYS[cw])
    hw = 6.0
    if part == "base":
        H = BASE_H
        holes = [(-4.6, -0.8, 1.6, 9.6), (1.2, 4.6, 0, 8.8)]
        wall_with_holes(b, -hw, hw, 0, H, holes, "base_stone")
        opening(b, -4.6, -0.8, 1.6, 9.6, "rect", 1.3, "base_stone", "shop", ("glass", "glass_light"), glass_split=0.62)
        opening(b, 1.2, 4.6, 0, 8.8, "rect", 2.0, "base_stone", "shop", "door")
        box(b, fp(2.9, 4.8, -1.94), (2.0, 3.6, 0.1), "glass_light")
        band(b, -hw, hw, 0, 1.0, 0.18, "trim_3")
        band(b, -hw, hw, H - 0.7, H, 0.7, "trim_1")
        body(b, 12, 0, H, D, side="base_stone", back="base_stone")
        h = H
    elif part == "mid":
        H = STOREY
        upper(b, 12, STYLE)
        for u, sx in ((-hw, -hw), (hw, hw)):
            quoins(b, u, 0, H, -sx)
        # blind windows on the side walls (stone surrounds with dark panels)
        for sx in (-1, 1):
            for z in (6.0, 14.0):
                box(b, V(sx * (hw + 0.1), 5.7, z), (0.2, 6.6, 3.2), "trim_1")
                box(b, V(sx * (hw + 0.22), 5.7, z), (0.1, 5.8, 2.4), "glass_dark")
        h = H
    else:
        roof_slab(b, [(-hw, 0), (hw, 0), (hw, D), (-hw, D)], 0.3)
        box(b, fp(0, 0.5, -0.4), (12, 1.0, 0.8), "trim_3")
        cornice_front(b, hw)
        for sx in (-1, 1):
            # cornice returns along the sides
            box(b, V(sx * (hw + 0.4), 2.2, D / 2), (0.8, 1.2, D), "trim_1")
        box(b, V(0, 3.4, 0.4), (12, 1.2, 0.8), "wall")
        # stepped pediment
        for i, (pw, ph) in enumerate(((8.0, 1.2), (5.0, 1.0), (2.4, 0.9))):
            y0 = 4.0 + sum(h_ for _, h_ in ((8.0, 1.2), (5.0, 1.0), (2.4, 0.9))[:i])
            box(b, V(0, y0 + ph / 2, 0.4), (pw, ph, 0.8), "wall" if i < 2 else "trim_1")
        box(b, V(0, 4.1, 0.4), (12.3, 0.25, 1.1), "trim_1")
        for x in (-hw + 0.3, hw - 0.3):
            box(b, V(x, 1.0, D / 2 + 0.4), (0.6, 2.0, D - 0.8), {"side": "wall", "top": "trim_1"})
        box(b, V(0, 1.0, D - 0.3), (10.8, 2.0, 0.6), {"side": "wall", "top": "trim_1"})
        h = 7.1
    return b, {"module": "corner_" + part, "width": 12, "height": h, "depth": D, "colourway": cw, "symmetric": True}


# ---------------------------------------------------------------- facade extras and roof props
def fire_escape(name, levels):
    """A restrained fire escape for the right-hand bay of a 24 facade: a platform per storey
    (d 0 to 3) with railings, stairs between them and a raised drop ladder. Pivot = the
    building's pivot raised to the first upper floor (place it at y 16 with the building yaw)."""
    b = Builder(name)
    u0, u1 = 1.2, 11.2
    dep = 3.0
    for k in range(levels):
        y = 12 * k + 0.6
        box(b, fp((u0 + u1) / 2, y, dep / 2), (u1 - u0, 0.2, dep), "iron")
        top_y = y + 3.2
        box(b, fp((u0 + u1) / 2, top_y, dep), (u1 - u0, 0.14, 0.14), "iron")
        box(b, fp((u0 + u1) / 2, y + 1.6, dep), (u1 - u0, 0.1, 0.1), "iron")
        for u in (u0, u1):
            box(b, fp(u, top_y, dep / 2), (0.14, 0.14, dep), "iron")
            box(b, fp(u, y + 1.6, dep), (0.12, 3.2, 0.12), "iron")
        for i in range(3):
            u = u0 + (u1 - u0) * (i + 0.5) / 3
            box(b, fp(u, y + 1.6, dep), (0.08, 3.0, 0.08), "iron_light")
        # brackets back to the wall
        for u in (u0 + 0.5, u1 - 0.5):
            beam(b, fp(u, y - 0.1, dep - 0.2), fp(u, y - 2.0, 0.05), 0.12, 0.12, "iron")
        if k < levels - 1:
            a, c = (u0 + 1.0, u1 - 1.6) if k % 2 == 0 else (u1 - 1.6, u0 + 1.0)
            for dd in (0.6, 2.0):
                beam(b, fp(a, y + 0.1, dd), fp(c, y + 12.0, dd), 0.12, 0.12, "iron")
            for i in range(6):
                t = (i + 0.5) / 6
                u = a + (c - a) * t
                box(b, fp(u, y + 0.1 + 11.9 * t, 1.3), (0.5, 0.06, 1.4), "iron_light")
    # drop ladder (raised)
    for u in (u1 - 2.2, u1 - 1.2):
        box(b, fp(u, -2.6, dep - 0.3), (0.1, 6.0, 0.1), "iron")
    for i in range(6):
        box(b, fp(u1 - 1.7, -5.2 + i, dep - 0.3), (1.0, 0.08, 0.08), "iron")
    return b, {"levels": levels, "projection": dep, "pivot": "building pivot at y 16"}


def water_tank(name):
    """A rooftop water tank 9 tall on six 6-tall legs, wooden staves with iron bands and a
    shallow cone roof (research O5: on no more than one roof in three)."""
    b = Builder(name)
    for k in range(6):
        a = 2 * math.pi * k / 6
        x, z = math.cos(a) * 2.8, math.sin(a) * 2.8
        box(b, V(x, 3.0, z), (0.4, 6.0, 0.4), "tank_band")
    for k in range(3):
        a0, a1 = 2 * math.pi * k / 3, 2 * math.pi * k / 3 + math.pi
        beam(b, V(math.cos(a0) * 2.8, 0.5, math.sin(a0) * 2.8), V(math.cos(a1) * 2.8, 5.5, math.sin(a1) * 2.8), 0.12, 0.12, "tank_band")
    cyl(b, V(0, 6.0, 0), 0.3, 3.8, 10, "tank_band")
    cyl(b, V(0, 6.3, 0), 6.0, 3.5, 10, "tank_wood", top=False, r_top=3.3)
    for y in (7.3, 9.5, 11.6):
        cyl(b, V(0, y, 0), 0.25, 3.55 - (y - 6.3) * 0.033, 10, "tank_band", top=False)
    cyl(b, V(0, 12.3, 0), 2.4, 3.6, 10, "roof_dark", r_top=0.3)
    cyl(b, V(0, 14.7, 0), 0.4, 0.35, 6, "tank_band")
    beam(b, V(3.6, 6.3, 0), V(3.6, 12.3, 0), 0.1, 0.1, "tank_band")
    return b, {"height": 15.1, "footprint": 7.6}


# ---------------------------------------------------------------- midground
def mid_mass(name, height, sw, stepped=True):
    """A simpler brick or stone block 36 wide, 30 deep: window bands per storey, a stone base
    band and a stepped top."""
    b = Builder(name, {"wall": sw})
    w, d = 36.0, 30.0
    hw = w / 2
    floors = int((height - 10) // 12)
    holes = []
    for f in range(floors):
        v0 = 8 + f * 12
        for c in (-13.0, -4.4, 4.4, 13.0):
            holes.append((c - 2.6, c + 2.6, v0, v0 + 6.0))
    wall_with_holes(b, -hw, hw, 0, height, holes, "wall")
    for (a, c, v0, v1) in holes:
        opening(b, a, c, v0, v1, "rect", 0.5, "wall", "mid_window", "mid_window")
    body(b, w, 0, height, d)
    band(b, -hw, hw, 0, 6.0, 0.3, "sky_trim")
    if stepped:
        box(b, V(0, height + 0.6, d / 2), (w + 1.0, 1.2, d + 1.0), {"side": "sky_trim", "top": "roof"})
        box(b, V(0, height + 5.2, d / 2 + 2), (w - 12, 8.0, d - 10), {"side": "wall", "top": "roof"})
        box(b, V(0, height + 9.6, d / 2 + 2), (w - 11, 0.8, d - 9), "sky_trim")
    else:
        box(b, V(0, height + 0.6, d / 2), (w + 1.0, 1.2, d + 1.0), {"side": "sky_trim", "top": "roof"})
    return b, {"module": "midground", "width": w, "height": height + 10, "depth": d}


def glass_tower(name, height, glass):
    """An occasional glass tower behind the brick blocks: 40 x height x 40, pale spandrel bands
    every 12 and pale corner piers."""
    b = Builder(name, {"glass": glass})
    w = 40.0
    hw = w / 2
    box(b, V(0, height / 2, hw), (w - 2, height, w - 2), {"side": "glass", "top": "roof"})
    for y in range(12, int(height), 12):
        box(b, V(0, y, hw), (w - 1.6, 1.2, w - 1.6), "frame")
    for sx in (-1, 1):
        for sz in (0, 1):
            box(b, V(sx * (hw - 1.0), height / 2, 1.0 + sz * (w - 2.0)), (2.0, height, 2.0), "frame")
    box(b, V(0, height + 1.5, hw), (w, 3.0, w), {"side": "frame", "top": "roof"})
    box(b, V(0, height + 5, hw), (14, 4.0, 14), {"side": "frame", "top": "roof_dark"})
    return b, {"module": "midground", "width": w, "height": height + 7, "depth": w}


# ---------------------------------------------------------------- signs
def fascia(name, business, w, h, frame_sw, emblem):
    b = Builder(name)
    hw = w / 2
    plate(b, rrect_uv(-hw, 0, hw, h, 0.3, seg=1), 0, 0.3, frame_sw)
    e = h * 0.95
    face_u0 = -hw + e + 0.6
    plate(b, rrect_uv(face_u0, 0.4, hw - 0.4, h - 0.4, 0.15, seg=1), 0.3, 0.38, "sign_face")
    cu, cv = -hw + e / 2 + 0.35, h / 2
    if emblem == "nut":
        plate(b, circle_uv(cu, cv, e * 0.46, 6, math.pi / 6), 0.3, 0.7, "iron_light", "iron")
        plate(b, circle_uv(cu, cv, e * 0.2, 10), 0.7, 0.75, "iron")
    elif emblem == "slice":
        r = e * 0.48
        plate(b, [(cu - r, cv + r * 0.75), (cu + r, cv + r * 0.75), (cu, cv - r)], 0.3, 0.6, "sprinkle_1", "donut_dough")
        plate(b, [(cu - r, cv + r * 0.75), (cu + r, cv + r * 0.75), (cu + r * 0.9, cv + r * 0.45), (cu - r * 0.9, cv + r * 0.45)], 0.6, 0.66, "donut_dough")
        for du, dv in ((-0.3, 0.15), (0.3, 0.1), (0.0, -0.3)):
            plate(b, circle_uv(cu + du * r, cv + dv * r, r * 0.16, 6), 0.6, 0.66, "signal_red")
    fw = hw - 0.4 - face_u0
    return b, {"business": business, "faces": [sign_face_record("main", face_u0 + fw / 2, h / 2, 0.38, fw, h - 0.8)], "size": [w, h]}


def blade(name, business, height, width, frame_sw, bulbs=True, emblem=None):
    """A vertical blade sign projecting from the wall (toward local -Z), text faces on both
    sides (+X and -X), a few bulbs along the outer edge (restrained, not flashing)."""
    b = Builder(name)
    t = 0.6
    z0, z1 = -0.8, -0.8 - width
    pts = [(z0, 0.0), (z1 + 0.8, 0.0), (z1, 0.8), (z1, height - 0.8), (z1 + 0.8, height), (z0, height)]
    for sx in (-1, 1):
        b.face([V(sx * t / 2, y, z) for z, y in pts], frame_sw, V(sx, 0, 0))
    for i in range(len(pts)):
        (za, ya), (zc, yc) = pts[i], pts[(i + 1) % len(pts)]
        b.face([V(-t / 2, ya, za), V(t / 2, ya, za), V(t / 2, yc, zc), V(-t / 2, yc, zc)], frame_sw, V(0, (ya + yc) / 2 - height / 2, (za + zc) / 2 - (z0 + z1) / 2))
    fz0, fz1 = z0 - 0.5, z1 + 0.5
    for sx in (-1, 1):
        b.face([V(sx * (t / 2 + 0.05), y, z) for z, y in [(fz0, 0.7), (fz1, 0.7), (fz1, height - 0.7), (fz0, height - 0.7)]], "sign_face", V(sx, 0, 0))
    if bulbs:
        n = int(height // 2.2)
        for i in range(n):
            y = 1.1 + (height - 2.2) * i / max(1, n - 1)
            box(b, V(0, y, z1 - 0.15), (0.35, 0.35, 0.3), "bulb")
    for y in (1.0, height - 1.0):
        box(b, V(0, y, -0.4), (0.3, 0.3, 0.8), "iron")
    if emblem == "moon":
        for sx in (-1, 1):
            pts2 = [((z0 + z1) / 2 + math.cos(2 * math.pi * k / 10) * width * 0.38, height + width * 0.45 + math.sin(2 * math.pi * k / 10) * width * 0.38) for k in range(10)]
            b.face([V(sx * 0.3, y, z) for z, y in pts2], "sprinkle_1", V(sx, 0, 0))
        box(b, V(0, height + 0.2, (z0 + z1) / 2), (0.25, 0.5, 0.25), "iron")
    fw = abs(fz1 - fz0)
    cz = (fz0 + fz1) / 2
    return b, {
        "business": business,
        "faces": [
            {"name": "left", "centre": [-(t / 2 + 0.05), height / 2, round(cz, 3)], "size": [round(fw, 3), round(height - 1.4, 3)], "normal": "Left", "text": "vertical"},
            {"name": "right", "centre": [t / 2 + 0.05, height / 2, round(cz, 3)], "size": [round(fw, 3), round(height - 1.4, 3)], "normal": "Right", "text": "vertical"},
        ],
        "size": [t, height, width + 0.8],
        "mount": "blade: back edge on the facade, projecting toward the street",
    }


# ---------------------------------------------------------------- landmark: the corner movie theater
def poster(b, cu, cv, d, kind):
    """A framed poster case (4 x 6) with an original geometric graphic (no text, no real art)."""
    plate(b, rrect_uv(cu - 2.3, cv - 3.3, cu + 2.3, cv + 3.3, 0.2, seg=1), d, d + 0.25, "marquee_trim")
    plate(b, rrect_uv(cu - 2.0, cv - 3.0, cu + 2.0, cv + 3.0, 0.1, seg=1), d + 0.25, d + 0.3, "poster_bg")
    z0 = d + 0.3
    if kind == 0:  # a rocket climbing past stars
        plate(b, [(cu - 0.6, cv - 1.6), (cu + 0.6, cv - 1.6), (cu + 0.6, cv + 1.0), (cu, cv + 2.2), (cu - 0.6, cv + 1.0)], z0, z0 + 0.05, "poster_3")
        plate(b, circle_uv(cu, cv + 0.4, 0.35, 8), z0 + 0.05, z0 + 0.08, "poster_2")
        plate(b, [(cu - 0.6, cv - 1.6), (cu - 1.2, cv - 2.2), (cu - 0.6, cv - 0.6)], z0, z0 + 0.05, "poster_1")
        plate(b, [(cu + 0.6, cv - 1.6), (cu + 1.2, cv - 2.2), (cu + 0.6, cv - 0.6)], z0, z0 + 0.05, "poster_1")
        for du, dv in ((-1.4, 2.2), (1.3, 1.6), (-1.2, 0.3), (1.5, -0.6)):
            plate(b, circle_uv(cu + du, cv + dv, 0.14, 4), z0, z0 + 0.04, "sprinkle_3")
    elif kind == 1:  # a smiling sun over rolling hills
        plate(b, circle_uv(cu, cv + 0.8, 1.2, 12), z0, z0 + 0.05, "poster_3")
        plate(b, [(cu - 2.0, cv - 3.0), (cu + 2.0, cv - 3.0), (cu + 2.0, cv - 1.2), (cu + 0.8, cv - 0.7), (cu - 0.6, cv - 1.4), (cu - 2.0, cv - 0.9)], z0, z0 + 0.05, "poster_4")
        for du in (-0.4, 0.4):
            plate(b, circle_uv(cu + du, cv + 1.0, 0.14, 6), z0 + 0.05, z0 + 0.08, "poster_bg")
    elif kind == 2:  # a little round car with speed lines
        plate(b, rrect_uv(cu - 1.5, cv - 0.6, cu + 1.5, cv + 0.6, 0.5, seg=2), z0, z0 + 0.05, "poster_1")
        plate(b, rrect_uv(cu - 0.8, cv + 0.5, cu + 0.7, cv + 1.3, 0.35, seg=2), z0, z0 + 0.05, "poster_1")
        for du in (-0.9, 0.9):
            plate(b, circle_uv(cu + du, cv - 0.6, 0.45, 8), z0 + 0.05, z0 + 0.08, "poster_bg")
            plate(b, circle_uv(cu + du, cv - 0.6, 0.2, 6), z0 + 0.08, z0 + 0.1, "sprinkle_3")
        for dv in (-0.2, 0.3, 0.8):
            plate(b, [(cu - 1.9, cv + dv - 0.06), (cu - 1.7, cv + dv - 0.06), (cu - 1.7, cv + dv + 0.06), (cu - 1.9, cv + dv + 0.06)], z0, z0 + 0.05, "poster_2")
    else:  # a friendly round monster with spikes
        plate(b, circle_uv(cu, cv - 0.4, 1.4, 12), z0, z0 + 0.05, "poster_4")
        for k in range(4):
            a = math.pi * (0.2 + 0.2 * k)
            px, py = cu + math.cos(a) * 1.4, cv - 0.4 + math.sin(a) * 1.4
            plate(b, [(px - 0.3, py - 0.1), (px + 0.3, py - 0.1), (px + math.cos(a) * 0.7, py + math.sin(a) * 0.7)], z0, z0 + 0.05, "poster_3")
        for du in (-0.5, 0.5):
            plate(b, circle_uv(cu + du, cv - 0.1, 0.28, 8), z0 + 0.05, z0 + 0.08, "sprinkle_3")


def theater(name):
    """REEL WHEELS CINEMA on the intersection's near-right corner. 32 wide (u -16 to 16, the
    corner at u -16 = local +X, which faces the cross street), 30 deep. Cream stone with
    marquee-red and gold accents, vertical ribs, a stepped corner tower (to 52), a deep canopy
    projecting 9.5 at 12 to 15 (u -13 to 2), recessed glass doors with a ticket booth, poster
    cases on both street faces. The vertical blade sign is B_TheaterBlade (mounted at u -11)."""
    remap = {"wall": "wall_4", "acc": "marquee"}
    b = Builder(name, remap)
    w, Dd = 32.0, 30.0
    hw = w / 2
    H = 32.0
    # ground floor front: entrance recess (u -9 to 1), poster cases, a side door
    holes = [(-9.0, 1.0, 0, 9.0), (6.0, 13.0, 1.6, 9.6)]
    wall_with_holes(b, -hw, hw, 0, 16, holes, "wall")
    opening(b, -9.0, 1.0, 0, 9.0, "rect", 3.0, "wall", "marquee_trim", "glass")
    for u in (-7.6, -5.0, -2.4, 0.2):
        box(b, fp(u - 0.6, 4.2, -2.9), (1.1, 8.0, 0.12), "glass_light")
    box(b, fp(-4.0, 4.5, -2.2), (2.6, 0.1, 1.2), "marquee_trim")
    # ticket booth in the recess
    box(b, fp(-4.0, 3.5, -1.2), (2.6, 3.0, 1.6), {"side": "glass_light", "top": "marquee", "front": "glass_light"})
    box(b, fp(-4.0, 5.2, -1.2), (3.0, 0.4, 2.0), "marquee")
    opening(b, 6.0, 13.0, 1.6, 9.6, "rect", 1.2, "wall", "marquee_trim", ("glass", "glass_light"), glass_split=0.6)
    poster(b, 3.5, 6.0, 0.0, 0)
    poster(b, -12.5, 6.0, 0.0, 1)
    band(b, -hw, hw, 0, 1.0, 0.2, "trim_3")
    # upper front: vertical ribs and tall narrow windows
    holes = [(u - 0.9, u + 0.9, 18.0, 29.0) for u in (-3.0, 1.0, 5.0, 9.0, 13.0)]
    wall_with_holes(b, -hw, hw, 16, H, holes, "wall")
    for (a, c, v0, v1) in holes:
        opening(b, a, c, v0, v1, "rect", 0.8, "wall", "reveal", ("glass", "glass_light"), glass_split=0.5)
    for u in (-5.0, -1.0, 3.0, 7.0, 11.0, 15.2):
        box(b, fp(u, 24.0, 0.3), (0.8, 16.0, 0.6), "trim_1")
    band(b, -hw, hw, 16.0, 16.8, 0.4, "marquee_trim")
    band(b, -hw, hw, H - 1.4, H, 0.6, "acc")
    band(b, -hw, hw, H, H + 1.6, 0.3, "wall")
    body(b, w, 0, H + 1.6, Dd)
    # corner side (local +X): poster cases and an exit door, ribs above
    sx = hw
    for z, kind in ((5.0, 2), (11.0, 3)):
        c = V(sx + 0.05, 6.0, z)
        box(b, c, (0.25, 6.6, 4.6), "marquee_trim")
        box(b, c + V(0.15, 0, 0), (0.1, 6.0, 4.0), "poster_bg")
    for z in (5.0, 11.0):
        for (dy, dz, sw) in ((0.8, 0.0, "poster_3" if z < 8 else "poster_4"), (-1.2, 0.6, "poster_1"), (-1.0, -0.9, "poster_2")):
            box(b, V(sx + 0.25, 6.0 + dy, z + dz), (0.08, 1.6, 1.6), sw)
    box(b, V(sx + 0.05, 4.4, 21.0), (0.3, 8.8, 4.0), "door")
    box(b, V(sx + 0.15, 9.0, 21.0), (0.3, 0.5, 4.8), "trim_1")
    for z in (3.0, 9.0, 15.0, 21.0, 27.0):
        box(b, V(sx + 0.3, 24.0, z), (0.6, 16.0, 0.8), "trim_1")
    box(b, V(sx + 0.2, H - 0.7, Dd / 2), (0.6, 1.4, Dd), "acc")
    # stepped corner tower (u -16 to -6 -> x 6 to 16), rising in three setbacks
    steps = [(10.0, 30.0, H + 1.6, H + 8.0), (8.0, 24.0, H + 8.0, H + 14.0), (5.0, 16.0, H + 14.0, H + 19.0)]
    for i, (tw, td, y0, y1) in enumerate(steps):
        cx = 11.0 + (10.0 - tw) / 2
        box(b, V(cx, (y0 + y1) / 2, td / 2 + (30 - td) * 0.15), (tw, y1 - y0, td), {"side": "wall", "top": "roof"})
        box(b, V(cx, y1 - 0.4, td / 2 + (30 - td) * 0.15), (tw + 0.4, 0.8, td + 0.4), "acc" if i == 0 else "marquee_trim")
        for k in range(3):
            box(b, V(cx - tw / 2 + tw * (k + 0.5) / 3, (y0 + y1) / 2, -0.15 + (30 - td) * 0.15), (0.6, y1 - y0 - 1.6, 0.4), "trim_1")
    box(b, V(13.5, H + 20.0, 4.0), (1.4, 2.0, 1.4), "marquee_trim")
    # roof
    b.face([V(-hw, H + 1.6, 0), V(hw, H + 1.6, 0), V(hw, H + 1.6, Dd), V(-hw, H + 1.6, Dd)], "roof", V(0, 1, 0))
    # the deep canopy: u -13 to 2, 9.5 out, 12 to 15 high, bulbs on its underside edge
    cu0, cu1, proj = -13.0, 2.0, 9.5
    box(b, fp((cu0 + cu1) / 2, 13.5, proj / 2), (cu1 - cu0, 3.0, proj), {"side": "marquee", "bottom": "awning_under", "top": "roof_dark"})
    box(b, fp((cu0 + cu1) / 2, 15.2, proj - 0.2), (cu1 - cu0 + 0.4, 0.4, 0.6), "marquee_trim")
    box(b, fp((cu0 + cu1) / 2, 11.8, proj - 0.2), (cu1 - cu0 + 0.4, 0.4, 0.6), "marquee_trim")
    plate(b, [(cu0 + 0.8, 12.3), (cu1 - 0.8, 12.3), (cu1 - 0.8, 14.8), (cu0 + 0.8, 14.8)], proj, proj + 0.08, "sign_face")
    for i in range(12):
        u = cu0 + 0.7 + (cu1 - cu0 - 1.4) * i / 11
        box(b, fp(u, 11.75, proj - 0.9), (0.3, 0.3, 0.3), "bulb")
    for u in (cu0 + 1.0, cu1 - 1.0):
        beam(b, fp(u, 15.0, proj - 0.5), fp(u, 21.0, 0.05), 0.12, 0.12, "iron")
    return b, {
        "landmark": "REEL WHEELS CINEMA (corner movie theater)",
        "width": w,
        "depth": Dd,
        "height": H + 21.0,
        "canopy": {"u": [cu0, cu1], "projection": proj, "height": [12, 15]},
        "faces": [sign_face_record("marquee", (cu0 + cu1) / 2, 13.55, proj + 0.08, cu1 - cu0 - 1.6, 2.5)],
        "blade_mount": {"mesh": "B_TheaterBlade", "local": [11.0, 17.0, 0.0]},
        "corner_side": "+X",
    }


def build_all(emit):
    for cw in ("1", "2", "3", "4", "5", "q"):
        emit(*base(f"B_Base24_{cw}", 24, cw), "B/building", "B")
        emit(*base(f"B_Base12_{cw}", 12, cw), "B/building", "B")
        emit(*mid(f"B_Mid24_{cw}", 24, cw), "B/building", "B")
        emit(*mid(f"B_Mid12_{cw}", 12, cw), "B/building", "B")
        emit(*top(f"B_Top24_{cw}", 24, cw), "B/building", "B")
        emit(*top(f"B_Top12_{cw}", 12, cw), "B/building", "B")
    for cw in ("1", "2"):
        for part in ("base", "mid", "top"):
            emit(*corner(f"B_Corner{part.capitalize()}_{cw}", part, cw), "B/building", "B")
    emit(*fire_escape("B_FireEscape2", 2), "B/building", "B")
    emit(*fire_escape("B_FireEscape3", 3), "B/building", "B")
    emit(*water_tank("B_WaterTank"), "B/roof", "B")
    for i, sw in enumerate(("mid_1", "mid_2", "mid_3", "mid_4")):
        emit(*mid_mass(f"B_MidLow_{i + 1}", 50.0, sw), "B/midground", "B")
        emit(*mid_mass(f"B_MidTall_{i + 1}", 86.0, sw, stepped=True), "B/midground", "B")
    emit(*glass_tower("B_GlassTower_1", 150.0, "glass"), "B/midground", "B")
    emit(*glass_tower("B_GlassTower_2", 120.0, "glass_light"), "B/midground", "B")
    emit(*fascia("B_SignHardware", "LUG NUTS HARDWARE", 18.0, 3.0, "sign_frame_4", "nut"), "B/sign", "B")
    emit(*fascia("B_SignPizza", "WHEEL GOOD PIZZA", 16.0, 3.0, "sign_frame_3", "slice"), "B/sign", "B")
    emit(*blade("B_SignDiner", "BRAKE-FAST DINER", 9.0, 3.0, "sign_frame_2"), "B/sign", "B")
    emit(*blade("B_SignHotel", "TIRED? NAP HOTEL", 14.0, 2.6, "sign_frame_1", bulbs=False, emblem="moon"), "B/sign", "B")
    emit(*blade("B_TheaterBlade", "REEL WHEELS", 34.0, 6.5, "marquee"), "B/sign", "B")
    emit(*theater("B_Theater"), "B/landmark", "B")
