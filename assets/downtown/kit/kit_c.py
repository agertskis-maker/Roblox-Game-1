# Downtown kit, direction C "Big Bright Metropolis": glass podiums (16 to 32 tall) with pale
# structural frames and selected saturated accent bands at the street, teal / sky / deep glass
# towers set back 30 or more behind them, a sky bridge set back between towers, roof gardens,
# a coherent screen billboard, and the landmark: an elevated train crossing over the road
# (underside 44) with a station on the left and a short two-car train. Matte glass (research O7:
# it never glitters behind traffic). Podium colourways: _1 coral accent / teal glass, _2 yellow /
# sky glass, _3 mint / deep glass, _q quiet. Tower glass: _1 teal, _2 sky, _3 deep.

import math
import random

from kitlib import Builder, V, beam, box, cyl, fp, opening, prism, rounded_rect2, sphere, wall_with_holes
from kit_facade import (
    BASE_H,
    band,
    body,
    circle_uv,
    display,
    offset_outline,
    parapet_ring,
    plate,
    rrect_uv,
    roof_slab,
    sign_face_record,
)

D = 28.0
PODIUM_CW = {
    "1": {"acc": "accent_1", "glass": "wall_4", "wall": "wall_1"},
    "2": {"acc": "accent_2", "glass": "wall_5", "wall": "wall_2"},
    "3": {"acc": "accent_3", "glass": "wall_6", "wall": "wall_1"},
    "q": {"acc": "trim_3", "glass": "wall_4", "wall": "wall_3"},
}
TOWER_CW = {"1": {"glass": "wall_4"}, "2": {"glass": "wall_5"}, "3": {"glass": "wall_6"}}


def seed_of(name):
    return sum(map(ord, name)) * 13 + len(name)


# ---------------------------------------------------------------- podium modules
def podium_base(name, w, cw):
    """Ground floor (16): full-height glass bays between pale frame columns every 6, a glass
    canopy on thin hangers, displays, an accent band above and a pale plinth."""
    b = Builder(name, PODIUM_CW[cw])
    hw = w / 2
    H = BASE_H
    bays = int(w // 6)
    holes = []
    for i in range(bays):
        u0 = -hw + 6 * i + 0.5
        holes.append((u0, u0 + 5.0, 0.8 if i != bays // 2 else 0.0, 11.0))
    wall_with_holes(b, -hw, hw, 0, H, holes, "wall")
    for i, (a, c, v0, v1) in enumerate(holes):
        door = i == bays // 2
        opening(b, a, c, v0, v1, "rect", 0.9, "wall", "frame", ("glass_dark", "glass") if door else ("glass", "glass_light"), glass_split=0.72)
        box(b, fp((a + c) / 2, 8.4, -0.75), (c - a, 0.25, 0.2), "frame")
        if door:
            box(b, fp((a + c) / 2, 4.0, -0.8), (0.2, 8.0, 0.15), "frame")
        else:
            box(b, fp((a + c) / 2, v0 - 0.05, -0.45), (c - a, 0.1, 0.9), "shelf")
            display(b, "gadgets", (a + c) / 2, v0, -0.6, i)
    for i in range(bays + 1):
        u = -hw + 6 * i
        box(b, fp(min(max(u, -hw + 0.25), hw - 0.25), H / 2, 0.25), (0.5, H, 0.5), "frame")
    # glass canopy
    box(b, fp(0, 11.6, 1.6), (w - 1.0, 0.25, 3.2), {"side": "frame", "top": "glass_light", "bottom": "glass_light"})
    for u in (-hw + 2, 0, hw - 2):
        beam(b, fp(u, 11.7, 3.0), fp(u, 14.0, 0.05), 0.1, 0.1, "iron_light")
    band(b, -hw, hw, 12.6, 15.0, 0.35, "acc")
    band(b, -hw, hw, 15.0, 16.0, 0.4, "frame")
    band(b, -hw, hw, 0, 0.8, 0.15, "wall_base")
    body(b, w, 0, H, D, side="wall", back="wall")
    return b, {"module": "podium_base", "width": w, "height": H, "depth": D, "colourway": cw, "sign_band": [12.6, 15.0]}


def podium_upper(name, w, cw):
    """Second podium level (16): a ribbon window between pale horizontal fins and solid pale
    panels, an accent fin at the top."""
    b = Builder(name, PODIUM_CW[cw])
    hw = w / 2
    H = 16.0
    wall_with_holes(b, -hw, hw, 0, H, [(-hw + 0.8, hw - 0.8, 4.0, 11.5)], "wall")
    opening(b, -hw + 0.8, hw - 0.8, 4.0, 11.5, "rect", 0.8, "wall", "frame", ("glass", "glass_light"), glass_split=0.6)
    for u in [(-hw + 0.8) + (w - 1.6) * k / (w // 4) for k in range(1, int(w // 4))]:
        box(b, fp(u, 7.75, -0.6), (0.3, 7.5, 0.3), "frame")
    for v in (3.6, 11.9):
        band(b, -hw, hw, v - 0.2, v + 0.2, 1.0, "frame")
    band(b, -hw, hw, 14.6, 15.2, 0.6, "acc")
    body(b, w, 0, H, D, side="wall", back="wall")
    return b, {"module": "podium_upper", "width": w, "height": H, "depth": D, "colourway": cw}


def podium_top(name, w, cw):
    b = Builder(name, PODIUM_CW[cw])
    hw = w / 2
    roof_slab(b, [(-hw, 0), (hw, 0), (hw, D), (-hw, D)], 0.3, "roof")
    box(b, V(0, 1.0, 0.4), (w, 2.0, 0.8), "frame")
    box(b, V(0, 2.1, 0.3), (w + 0.4, 0.2, 1.2), "frame")
    for x in (-hw + 0.3, hw - 0.3):
        box(b, V(x, 0.8, D / 2 + 0.4), (0.6, 1.6, D - 0.8), "frame")
    box(b, V(0, 0.8, D - 0.3), (w - 1.2, 1.6, 0.6), "frame")
    return b, {"module": "podium_top", "width": w, "height": 2.2, "depth": D, "colourway": cw, "roof_y": 0.3}


def podium_corner(name, part, cw):
    """A 12-wide end bay with rounded glass front corners (radius 4) and pale bands."""
    b = Builder(name, PODIUM_CW[cw])
    ol = rounded_rect2(-6, 0, 6, D, 4.0, seg=4, corners=(True, True, False, False))
    if part == "top":
        roof_slab(b, ol, 0.3)
        parapet_ring(b, ol, 0, 2.0, 0.5, "frame", "frame")
        return b, {"module": "podium_corner_top", "width": 12, "height": 2.0, "depth": D, "colourway": cw, "symmetric": True}
    H = 16.0
    # glass all round the rounded front, pale floor plates
    prism(b, offset_outline(ol, -0.6), 0.8, H - 1.2, "glass", top=False)
    for v0, v1 in ((0, 0.8), (H - 1.2, H)):
        prism(b, ol, v0, v1, "frame", "frame", bottom=(v0 == 0))
    if part == "base":
        prism(b, offset_outline(ol, 0.15), 12.6, 14.8, "acc", "acc")
        box(b, fp(0, 4.2, -0.1), (3.6, 8.4, 0.2), "glass_dark")
    else:
        prism(b, offset_outline(ol, 0.2), 7.6, 8.2, "frame", "frame", bottom=True)
    # mullions on the curve
    for k in range(1, 5):
        a = math.pi + (math.pi / 2) * k / 5
        for sx in (-1, 1):
            x = sx * (2.0 + 4.0 * -math.cos(a)) * 1.0
            z = 4.0 + 4.0 * math.sin(a)
            box(b, V(x, H / 2, z), (0.3, H, 0.3), "frame")
    return b, {"module": "podium_corner_" + part, "width": 12, "height": H, "depth": D, "colourway": cw, "symmetric": True}


# ---------------------------------------------------------------- towers
def tower_mid(name, w, cw, h=48.0):
    """Four storeys of curtain wall on all four sides: matte glass core, pale corner piers,
    vertical mullion fins every 6 and a pale spandrel ring per floor. Pivot: bottom centre of
    the front face (front = local -Z), body back to z = w."""
    b = Builder(name, TOWER_CW[cw])
    hw = w / 2
    box(b, V(0, h / 2, hw), (w - 1.0, h, w - 1.0), {"side": "glass", "skip_top": True, "skip_bottom": True})
    for y in range(0, int(h), 12):
        box(b, V(0, y + 0.5, hw), (w - 0.4, 1.0, w - 0.4), {"side": "frame", "skip_top": y > 0, "skip_bottom": y > 0, "top": "frame"})
    for sx in (-1, 1):
        for sz in (0, 1):
            box(b, V(sx * (hw - 0.8), h / 2, 0.8 + sz * (w - 1.6)), (1.6, h, 1.6), "frame")
    n = int(w // 6)
    for i in range(1, n):
        t = -hw + 6 * i
        box(b, V(t, h / 2, -0.1), (0.45, h, 0.6), "frame")
        box(b, V(t, h / 2, w + 0.1), (0.45, h, 0.6), "frame")
        box(b, V(-hw - 0.1, h / 2, hw + t), (0.6, h, 0.45), "frame")
        box(b, V(hw + 0.1, h / 2, hw + t), (0.6, h, 0.45), "frame")
    return b, {"module": "tower_mid", "width": w, "height": h, "depth": w, "colourway": cw, "storeys": int(h // 12)}


def tower_crown(name, w, cw, rng_seed=0):
    """A setback crown: a roof terrace with a garden, a smaller glass top storey and pale fins
    rising 8 above the roof to make an open crown."""
    rng = random.Random(seed_of(name))
    b = Builder(name, TOWER_CW[cw])
    hw = w / 2
    box(b, V(0, 0.5, hw), (w - 0.4, 1.0, w - 0.4), {"side": "frame", "top": "garden_deck"})
    iw = w * 0.62
    box(b, V(0, 7.0, hw + 1.0), (iw, 12.0, iw), {"side": "glass", "top": "roof"})
    box(b, V(0, 13.2, hw + 1.0), (iw + 0.6, 0.6, iw + 0.6), "frame")
    for k in range(int(iw // 4) + 1):
        x = -iw / 2 + iw * k / max(1, int(iw // 4))
        box(b, V(x, 10.0, hw + 1.0 - iw / 2 - 0.3), (0.45, 18.0, 0.5), "frame")
        box(b, V(x, 10.0, hw + 1.0 + iw / 2 + 0.3), (0.45, 18.0, 0.5), "frame")
    # garden round the setback: planters with round crowns
    for (x, z) in ((-hw + 3, 3), (hw - 3, 3), (-hw + 3, w - 3), (hw - 3, w - 3), (0, 2.6)):
        box(b, V(x, 1.6, z), (3.6, 1.2, 3.6), "planter")
        sphere(b, V(x, 4.0, z), (2.2, 2.0, 2.2), ["leaf_dark", "leaf_mid", "leaf_light", "leaf_sun"], subdiv=1, rng=rng, jitter=0.1)
    box(b, V(0, 1.4, 0.4), (w, 0.8, 0.4), "frame")
    return b, {"module": "tower_crown", "width": w, "height": 19.0, "depth": w, "colourway": cw}


def sky_bridge(name, L=30.0):
    """A glass sky bridge spanning local X (L long), 6 x 6, pale ribs; set it back from the
    road between two towers (never over the carriageway)."""
    b = Builder(name)
    box(b, V(0, 3.0, 0), (L, 6.0, 6.0), {"side": "glass_light", "top": "frame", "bottom": "frame"})
    for k in range(int(L // 3) + 1):
        x = -L / 2 + L * k / int(L // 3)
        box(b, V(x, 3.0, 0), (0.4, 6.4, 6.4), "frame")
    box(b, V(0, 0.2, 0), (L + 0.6, 0.6, 6.8), "frame")
    return b, {"length": L, "height": 6.6}


def roof_garden(name):
    """A podium roof garden: deck, raised planters with round trees, a pergola and benches."""
    rng = random.Random(seed_of(name))
    b = Builder(name)
    box(b, V(0, 0.15, 0), (20.0, 0.3, 12.0), "garden_deck")
    for x, z in ((-7, -3), (6, 3), (-2, 3.5)):
        box(b, V(x, 1.0, z), (4.0, 1.4, 4.0), {"side": "planter", "top": "soil"})
        cyl(b, V(x, 1.7, z), 2.5, 0.3, 5, "trunk")
        sphere(b, V(x, 5.4, z), (2.6, 2.4, 2.6), ["leaf_dark", "leaf_mid", "leaf_light", "leaf_sun"], subdiv=1, rng=rng, jitter=0.1)
    for x in (2.0, 8.0):
        for z in (-4.5, -1.5):
            box(b, V(x, 2.0, z), (0.3, 4.0, 0.3), "frame")
    for k in range(5):
        box(b, V(5.0, 4.1, -5.0 + 1.0 * k + 0.5), (7.0, 0.25, 0.25), "frame")
    box(b, V(5.0, 0.8, -3.0), (4.0, 0.3, 1.0), "wood")
    for x, z in ((-8.5, 4.0), (8.5, -1.0)):
        sphere(b, V(x, 0.9, z), (0.9, 0.8, 0.9), ["leaf_mid", "flower_1", "flower_2"], subdiv=0, rng=rng)
    return b, {"footprint": [20, 12], "height": 8.0}


# ---------------------------------------------------------------- signs and screens
def sign_screen(name):
    """A podium billboard screen 20 x 11 in a dark frame on two posts; the screen face is where a
    restrained animation can play (one coherent loop, no video)."""
    b = Builder(name)
    plate(b, rrect_uv(-10.6, 0, 10.6, 12.0, 0.5, seg=1), 0.0, 0.8, "screen_frame")
    plate(b, [(-10.0, 0.5), (10.0, 0.5), (10.0, 11.5), (-10.0, 11.5)], 0.8, 0.85, "screen_face")
    for u in (-6.0, 6.0):
        box(b, fp(u, -1.5, 0.4), (0.6, 3.0, 0.6), "screen_frame")
    return b, {"business": "screen", "faces": [sign_face_record("screen", 0, 6.0, 0.85, 20.0, 11.0)], "size": [21.2, 12.0], "material": "SmoothPlastic; animate the face with one ImageLabel loop"}


def sign_banner(name, business, w, h, frame_sw, vertical=False):
    b = Builder(name)
    plate(b, rrect_uv(-w / 2, 0, w / 2, h, 0.2, seg=1), 0, 0.3, frame_sw)
    plate(b, rrect_uv(-w / 2 + 0.4, 0.4, w / 2 - 0.4, h - 0.4, 0.1, seg=1), 0.3, 0.36, "sign_face")
    # a saturated accent stripe across the bottom (or down the side)
    if vertical:
        plate(b, [(-w / 2 + 0.4, 0.4), (-w / 2 + 1.0, 0.4), (-w / 2 + 1.0, h - 0.4), (-w / 2 + 0.4, h - 0.4)], 0.36, 0.4, "accent_2")
    else:
        plate(b, [(-w / 2 + 0.4, 0.4), (w / 2 - 0.4, 0.4), (w / 2 - 0.4, 0.9), (-w / 2 + 0.4, 0.9)], 0.36, 0.4, "accent_2")
    fw, fh = (w - 2.0, h - 0.8) if vertical else (w - 0.8, h - 1.4)
    cu = 0.3 if vertical else 0
    cv = h / 2 if vertical else h / 2 + 0.25
    return b, {"business": business, "faces": [sign_face_record("main", cu, cv, 0.36, fw, fh)], "size": [w, h], "text": "vertical" if vertical else "horizontal"}


def sign_noodle(name):
    """PIT STOP NOODLES: a round blade sign projecting from the wall, a bowl emblem on top."""
    b = Builder(name)
    t = 0.6
    cz, cy, R = -3.4, 3.2, 3.0
    pts = [(cz + math.cos(2 * math.pi * k / 16) * R, cy + math.sin(2 * math.pi * k / 16) * R) for k in range(16)]
    for sx in (-1, 1):
        b.face([V(sx * t / 2, y, z) for z, y in pts], "sign_frame_3", V(sx, 0, 0))
        b.face([V(sx * (t / 2 + 0.05), cy + math.sin(2 * math.pi * k / 16) * (R - 0.5), cz + math.cos(2 * math.pi * k / 16) * (R - 0.5)) for k in range(16)], "sign_face", V(sx, 0, 0))
    for i in range(16):
        (za, ya), (zc, yc) = pts[i], pts[(i + 1) % 16]
        b.face([V(-t / 2, ya, za), V(t / 2, ya, za), V(t / 2, yc, zc), V(-t / 2, yc, zc)], "sign_frame_3", V(0, (ya + yc) / 2 - cy, (za + zc) / 2 - cz))
    box(b, V(0, cy, -0.25), (0.3, 0.3, 0.5), "iron")
    # bowl with chopsticks
    bowl = [(cz - 1.4, 6.4), (cz + 1.4, 6.4), (cz + 0.9, 5.6), (cz - 0.9, 5.6)]
    for sx in (-1, 1):
        b.face([V(sx * 0.35, y, z) for z, y in bowl], "sprinkle_3", V(sx, 0, 0))
    for i in range(4):
        (za, ya), (zc, yc) = bowl[i], bowl[(i + 1) % 4]
        b.face([V(-0.35, ya, za), V(0.35, ya, za), V(0.35, yc, zc), V(-0.35, yc, zc)], "sprinkle_3", V(0, (ya + yc) / 2 - 6.0, (za + zc) / 2 - cz))
    beam(b, V(0, 6.2, cz + 0.2), V(0, 8.0, cz + 1.2), 0.1, 0.1, "wood_dark")
    beam(b, V(0, 6.2, cz + 0.6), V(0, 7.9, cz + 1.7), 0.1, 0.1, "wood_dark")
    return b, {
        "business": "PIT STOP NOODLES",
        "faces": [
            {"name": "left", "centre": [-(t / 2 + 0.05), cy, cz], "size": [4.6, 4.6], "normal": "Left"},
            {"name": "right", "centre": [t / 2 + 0.05, cy, cz], "size": [4.6, 4.6], "normal": "Right"},
        ],
        "size": [t, 8.0, 6.4],
    }


# ---------------------------------------------------------------- landmark: elevated train crossing
DECK_Y = 44.0  # underside of the deck
DECK_T = 3.0
DECK_W = 10.0


def deck(b, x0, x1, girder=False):
    """The guideway deck along local X: slab, edge parapets, two rails; optional deep side
    girders with diagonal web panels for the crossing span."""
    y0, y1 = DECK_Y, DECK_Y + DECK_T
    box(b, V((x0 + x1) / 2, (y0 + y1) / 2, 0), (x1 - x0, DECK_T, DECK_W), {"side": "rail_side", "top": "rail_concrete", "bottom": "rail_side"})
    for sz in (-1, 1):
        box(b, V((x0 + x1) / 2, y1 + 0.6, sz * (DECK_W / 2 - 0.3)), (x1 - x0, 1.2, 0.6), "rail_concrete")
        box(b, V((x0 + x1) / 2, y1 + 0.15, sz * 1.6), (x1 - x0, 0.3, 0.4), "rail_track")
    box(b, V((x0 + x1) / 2, y0 + 0.6, 0), (x1 - x0, 0.3, DECK_W + 0.2), "train_stripe")
    if girder:
        gh = 3.6
        n = int((x1 - x0) // 6)
        for sz in (-1, 1):
            z = sz * (DECK_W / 2 + 0.4)
            box(b, V((x0 + x1) / 2, y1 + gh - 0.4, z), (x1 - x0, 0.8, 0.8), "frame")
            box(b, V((x0 + x1) / 2, y1 + 0.4, z), (x1 - x0, 0.8, 0.8), "frame")
            for i in range(n + 1):
                x = x0 + (x1 - x0) * i / n
                box(b, V(x, y1 + gh / 2, z), (0.6, gh, 0.6), "frame")
                if i < n:
                    xa, xb = x, x0 + (x1 - x0) * (i + 1) / n
                    if i % 2 == 0:
                        beam(b, V(xa, y1 + 0.6, z), V(xb, y1 + gh - 0.6, z), 0.35, 0.35, "frame")
                    else:
                        beam(b, V(xa, y1 + gh - 0.6, z), V(xb, y1 + 0.6, z), 0.35, 0.35, "frame")


def rail_span(name):
    """The crossing span: 100 long across the road (local X), underside 44, with lattice side
    girders so it reads as a bridge. Pivot: road centre at ground; place with the road's yaw so
    local X runs across the carriageway. Piers stand at x +-48 (C_RailPier), outside the
    sidewalks."""
    b = Builder(name)
    deck(b, -50.0, 50.0, girder=True)
    return b, {"length": 100, "clearance": DECK_Y, "overhead": True}


def rail_viaduct(name):
    b = Builder(name)
    deck(b, 0.0, 40.0)
    return b, {"length": 40, "clearance": DECK_Y, "pivot": "start of the 40 piece, deck centreline at ground"}


def rail_pier(name):
    b = Builder(name)
    box(b, V(0, 1.0, 0), (5.0, 2.0, 6.0), "rail_side")
    box(b, V(0, DECK_Y / 2, 0), (3.0, DECK_Y - 2, 4.0), "rail_concrete")
    box(b, V(0, DECK_Y - 1.5, 0), (4.0, 3.0, DECK_W + 1.0), {"side": "rail_concrete", "top": "rail_side"})
    box(b, V(0, 14.0, 0), (3.2, 1.2, 4.2), "train_stripe")
    return b, {"height": DECK_Y}


def station(name):
    """The station on the left of the crossing (local -X side, along the viaduct): a platform
    canopy on the deck from x -58 to -98 with a curved pale-frame roof over teal glass, a glass
    stair and lift tower down to a street pavilion at the frontage line, and the station sign
    (C_SignStation) on the canopy."""
    b = Builder(name)
    x0, x1 = -98.0, -58.0
    y1 = DECK_Y + DECK_T
    # side platforms
    for sz in (-1, 1):
        box(b, V((x0 + x1) / 2, y1 + 0.5, sz * 7.5), (x1 - x0, 1.0, 5.0), {"side": "rail_side", "top": "sidewalk_a"})
        box(b, V((x0 + x1) / 2, y1 - 1.5, sz * 7.5), (x1 - x0, 3.0, 5.0), "rail_side")
    # canopy: posts and a curved roof (half-barrel, 6 facets)
    for x in [x0 + 2 + k * 9 for k in range(5)]:
        for sz in (-1, 1):
            box(b, V(x, y1 + 5.0, sz * 9.2), (0.5, 8.0, 0.5), "frame")
    n = 6
    R = 10.4
    prev = None
    for k in range(n + 1):
        a = math.pi * k / n
        z, y = math.cos(a) * R, y1 + 9.0 + math.sin(a) * 3.2
        if prev:
            pz, py = prev
            b.face([V(x0 - 1, py, pz), V(x1 + 1, py, pz), V(x1 + 1, y, z), V(x0 - 1, y, z)], "glass" if k in (3, 4) else "frame", V(0, (py + y) / 2 - (y1 + 9.0), (pz + z) / 2))
            b.face([V(x0 - 1, py - 0.3, pz), V(x1 + 1, py - 0.3, pz), V(x1 + 1, y - 0.3, z), V(x0 - 1, y - 0.3, z)], "awning_under", V(0, -1, 0))
        prev = (z, y)
    for x in (x0 - 1, x1 + 1):
        pts = [V(x, y1 + 9.0 + math.sin(math.pi * k / n) * 3.2, math.cos(math.pi * k / n) * R) for k in range(n + 1)]
        b.face(pts, "frame", V(1 if x > x0 else -1, 0, 0))
    # stair and lift tower to the street, at the frontage side near the road (x -46 to -54)
    tx = -50.0
    box(b, V(tx, DECK_Y / 2 + 2, 10.0), (8.0, DECK_Y + 4, 8.0), {"side": "glass", "top": "frame"})
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(b, V(tx + sx * 4.0, DECK_Y / 2 + 2, 10.0 + sz * 4.0), (0.7, DECK_Y + 4, 0.7), "frame")
    for y in range(8, int(DECK_Y), 8):
        box(b, V(tx, y, 10.0), (8.4, 0.6, 8.4), "frame")
    box(b, V(tx - 6, y1 + 0.5, 10.0), (8.0, 1.0, 4.0), {"side": "rail_side", "top": "sidewalk_a"})
    # street pavilion
    box(b, V(tx, 5.0, 10.0), (12.0, 10.0, 10.0), {"side": "glass_light", "top": "frame"})
    box(b, V(tx, 10.3, 10.0), (13.0, 0.6, 11.0), "train_stripe")
    return b, {"landmark": "SKYLINE LOOP station", "platform_y": y1 + 1.0, "sign_mount": {"mesh": "C_SignStation", "local": [-78.0, y1 + 12.6, -10.0]}}


def train(name):
    """A short two-car decorative train (each car 24 long, 6.4 wide, 7.4 tall), rounded noses,
    a window band and a teal stripe, running along local X. Pivot at the train centre on the
    rails (place on the deck top, y 47)."""
    b = Builder(name)
    for car in (-1, 1):
        cx = car * 12.6
        x0, x1 = cx - 12.0, cx + 12.0
        box(b, V(cx, 0.9, 0), (21.0, 1.2, 4.6), "train_dark")
        body_pts = []
        prof = [(1.5, -3.2), (6.2, -3.2), (7.4, -2.4), (7.6, 0.0), (7.4, 2.4), (6.2, 3.2), (1.5, 3.2)]
        nose = car  # nose at the outer end
        xa, xb = (x0, x1)
        # body: an extruded rounded profile (y, z) along x
        for i in range(len(prof) - 1):
            (ya, za), (yb, zb) = prof[i], prof[i + 1]
            sw = "train_window" if 3.6 < (ya + yb) / 2 < 6.0 and abs(za) > 2.5 else ("train_stripe" if (ya + yb) / 2 < 3.0 else "train_body")
            b.face([V(xa, ya, za), V(xb, ya, za), V(xb, yb, zb), V(xa, yb, zb)], sw, V(0, (ya + yb) / 2 - 4.0, (za + zb) / 2))
        b.face([V(xa, 1.5, -3.2), V(xb, 1.5, -3.2), V(xb, 1.5, 3.2), V(xa, 1.5, 3.2)], "train_dark", V(0, -1, 0))
        # window band and stripe as raised strips on the sides
        for sz in (-1, 1):
            box(b, V(cx, 4.6, sz * 3.22), (20.0, 1.8, 0.1), "train_window")
            box(b, V(cx, 2.6, sz * 3.22), (24.0, 0.6, 0.1), "train_stripe")
        # ends: the outer end is a rounded nose, the inner end a flat gangway
        outer = x1 if car > 0 else x0
        inner = x0 if car > 0 else x1
        b.face([V(inner, y, z) for y, z in prof], "train_body", V(-car, 0, 0))
        tip = outer + car * 2.6
        cen = V(tip, 3.6, 0)
        for i in range(len(prof) - 1):
            (ya, za), (yb, zb) = prof[i], prof[i + 1]
            pa, pb = V(outer, ya, za), V(outer, yb, zb)
            ma, mb = V(outer + car * 1.8, 1.5 + (ya - 1.5) * 0.85, za * 0.8), V(outer + car * 1.8, 1.5 + (yb - 1.5) * 0.85, zb * 0.8)
            sw = "train_window" if 4.0 < (ya + yb) / 2 < 6.6 else "train_body"
            b.face([pa, pb, mb, ma], sw, V(car, (ya + yb) / 2 - 4.0, (za + zb) / 2))
            b.face([ma, mb, cen], "train_accent" if (ya + yb) / 2 < 3.0 else sw, V(car, (ya + yb) / 2 - 4.0, (za + zb) / 2))
        b.face([V(outer, 1.5, -3.2), V(outer, 1.5, 3.2), V(outer + car * 1.8, 1.5, 2.56), V(outer + car * 1.8, 1.5, -2.56)], "train_dark", V(0, -1, 0))
        box(b, V(cx, 8.0, 0), (6.0, 0.6, 2.0), "train_dark")
    return b, {"length": 52.0, "height": 8.3, "anim": "slides along local X across the crossing every ~12 s"}


def build_all(emit):
    for cw in ("1", "2", "3", "q"):
        emit(*podium_base(f"C_Podium24_{cw}", 24, cw), "C/building", "C")
        emit(*podium_base(f"C_Podium12_{cw}", 12, cw), "C/building", "C")
        emit(*podium_upper(f"C_PodiumUpper24_{cw}", 24, cw), "C/building", "C")
        emit(*podium_upper(f"C_PodiumUpper12_{cw}", 12, cw), "C/building", "C")
        emit(*podium_top(f"C_PodiumTop24_{cw}", 24, cw), "C/building", "C")
        emit(*podium_top(f"C_PodiumTop12_{cw}", 12, cw), "C/building", "C")
    for cw in ("1", "2"):
        for part in ("base", "upper", "top"):
            emit(*podium_corner(f"C_PodiumCorner{part.capitalize()}_{cw}", part, cw), "C/building", "C")
    for cw in ("1", "2", "3"):
        emit(*tower_mid(f"C_TowerMid48_{cw}", 36.0, cw), "C/tower", "C")
        emit(*tower_mid(f"C_TowerSlim48_{cw}", 24.0, cw), "C/tower", "C")
        emit(*tower_crown(f"C_TowerCrown_{cw}", 36.0, cw), "C/tower", "C")
        emit(*tower_crown(f"C_TowerCrownSlim_{cw}", 24.0, cw), "C/tower", "C")
    emit(*sky_bridge("C_SkyBridge"), "C/tower", "C")
    emit(*roof_garden("C_RoofGarden"), "C/roof", "C")
    emit(*sign_screen("C_SignScreen"), "C/sign", "C")
    emit(*sign_banner("C_SignTurbo", "TURBO TOWERS", 16.0, 3.4, "sign_frame_1"), "C/sign", "C")
    emit(*sign_banner("C_SignGym", "GEAR UP GYM", 4.0, 12.0, "sign_frame_2", vertical=True), "C/sign", "C")
    emit(*sign_banner("C_SignStation", "SKYLINE LOOP STATION", 24.0, 3.0, "sign_frame_1"), "C/sign", "C")
    emit(*sign_noodle("C_SignNoodle"), "C/sign", "C")
    emit(*rail_span("C_RailSpan"), "C/landmark", "C")
    emit(*rail_viaduct("C_RailViaduct40"), "C/landmark", "C")
    emit(*rail_pier("C_RailPier"), "C/landmark", "C")
    emit(*station("C_Station"), "C/landmark", "C")
    emit(*train("C_Train"), "C/landmark", "C")
