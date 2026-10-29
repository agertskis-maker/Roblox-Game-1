# Summit Pass kit (Lane 3, Round 2, R2-SP1): the snowy mountain World's lots, landmarks, props, hazards and distant masses,
# on the same grammar as the Downtown B2 kit and the Dusty Highway kit (kit_world_lib). A crisp alpine road trip: white
# snow, ice blue, deep pine green, warm timber and red roofs. Everything is original and fictional. Names: SP_Lot_*,
# SP_LM_*, SP_Prop_*, SP_Haz_*, SP_Mid_*, SP_Sky_*, matching Worlds/SummitPass.luau exactly.
#
# Hazards are SCENERY previews (frost crack, ice patch, snowbank with plow stakes); a collapsed-ice GAP exists only in a
# marked hazard test area, never in the route. Ice is OPAQUE sculpted colour (no transparency). Orange/white is used only
# by hazards.

import math
import random

import kit_world_lib as L
from kit_b2lib import sock
from kit_dusty import mound, rng_of, strata_block
from kitlib import V, beam, box, circle2, cyl, sphere, tube

WORLD = "SU"
NEAR = "near"
ALL = ["PineVillage", "SkiLiftRidge", "FrozenLake", "GlacierTunnel", "SummitLodge"]
SNOW = ["g_lo", "g_sand", "g_hi"]


def finish(b, w, d, h, cls, districts, shop=False, family="Lot", module="scenery", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, family, module, w, d, h, cls, districts, sockets, shop, **kw)


def lm_finish(b, w, d, h, districts, placement="frontage", sockets=None, **kw):
    b.shift(w / 2)
    return b, L.lot_meta(WORLD, "LM", "landmark", w, d, h, "landmark", districts, sockets, False, placement=placement, **kw)


# ---------------------------------------------------------------- shared parts
def snow_pad(b, w, d, x=0.0, z=0.0):
    L.pad(b, w, d, "g_hi", 0.5, x=x, z=z)


def gable(b, x, z0, z1, w, y0, rise, roof="w_roof_1", snow=True, over=0.8):
    """A gable roof with its ridge along x: two sloped panels (front and back), two gable-end triangles and a snow cap."""
    hw = w / 2 + over
    zm = (z0 + z1) / 2
    zf, zb = z0 - over, z1 + over
    for s, zz in ((-1, zf), (1, zb)):
        b.face([V(x - hw, y0, zz), V(x + hw, y0, zz), V(x + hw, y0 + rise, zm), V(x - hw, y0 + rise, zm)], roof, V(0, 1, s))
        if snow:
            b.face([V(x - hw, y0 + rise * 0.55, zz + (zm - zz) * 0.45), V(x + hw, y0 + rise * 0.55, zz + (zm - zz) * 0.45), V(x + hw, y0 + rise + 0.25, zm), V(x - hw, y0 + rise + 0.25, zm)], "m_white", V(0, 1, s * 0.6))
    for sx in (-1, 1):
        b.face([V(x + sx * (w / 2), y0, z0), V(x + sx * (w / 2), y0, z1), V(x + sx * (w / 2), y0 + rise * 0.92, zm)], "w_wall_2", V(sx, 0, 0))


def chalet_body(b, x, w, d, h, wall, rise, roof="w_roof_1", windows=2):
    """A timber chalet centred on x: plain_building body, a steep snowy gable, a front porch and a chimney."""
    L.plain_building(b, w, d, h, wall, "w_trim_1", "w_roof_flat", "w_door", windows=windows, parapet=False, y0=0.5, x=x)
    gable(b, x, 0.0, d, w, h + 0.5, rise, roof)
    box(b, V(x + w * 0.28, h + 0.5 + rise * 0.85, d * 0.62), (2.2, rise * 0.7 + 2.0, 2.2), {"side": "m_stone", "top": "m_white", "skip_bottom": True})  # chimney
    for sx in (-1, 1):  # porch posts and a small roof over the door
        box(b, V(x + sx * 3.4, 4.0, -2.6), (0.5, 8.0, 0.5), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(x, 8.2, -1.4), (8.4, 0.5, 3.4), {"side": "w_roof_1", "top": "m_white", "skip_bottom": True})


# ---------------------------------------------------------------- lots
def chalet_lot(name, w, h, wall, rise, districts):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0 if w < 30 else 22.0
    snow_pad(b, w, d)
    chalet_body(b, 0.0, w - 5.0, d - 6.0, h, wall, rise, windows=2 if w < 30 else 3)
    L.pine(b, -w / 2 + 2.4, d - 4.0, 12.0, rng, snow=True, tiers=2)
    return finish(b, w, d, h + 0.5 + rise + 1.0, "low", districts)


def cabin_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 18.0
    snow_pad(b, w, d)
    bw, bd = w - 6.0, 13.0
    for i in range(int((h - 0.5) // 1.6)):  # log courses: alternating tones
        box(b, V(0, 0.5 + i * 1.6 + 0.8, bd / 2 + 1.0), (bw + (0.5 if i % 2 else 0), 1.6, bd), {"side": "m_wood_1" if i % 2 else "m_wood_2", "top": "m_wood_2", "skip_bottom": True})
    
    b.face([V(-1.6, 0.5, 0.45), V(1.6, 0.5, 0.45), V(1.6, 7.6, 0.45), V(-1.6, 7.6, 0.45)], "w_door", V(0, 0, -1))
    gable(b, 0.0, 1.0, 1.0 + bd, bw, h + 0.5, 4.6, "m_wood_2")
    box(b, V(-bw * 0.28, h + 3.4, 8.0), (1.8, 5.0, 1.8), {"side": "m_stone", "top": "m_white", "skip_bottom": True})
    L.pine(b, w / 2 - 2.4, d - 3.0, 11.0, rng, snow=True, tiers=2)
    return finish(b, w, d, h + 0.5 + 6.0, "low", ["PineVillage", "FrozenLake", "SummitLodge"])


def cafe_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    snow_pad(b, w, d)
    chalet_body(b, 0.0, w - 4.0, d - 6.0, h, "w_wall_4", 5.5, "w_roof_1", windows=3)
    box(b, V(0, 9.6, -2.8), (w - 6.0, 0.6, 5.0), {"side": "w_accent_2", "top": "m_white", "skip_bottom": True})  # plain red canvas awning
    box(b, V(0, 8.9, -5.1), (w - 6.0, 1.0, 0.4), {"side": "w_wall_2", "skip_bottom": True})
    cyl(b, V(-w / 2 + 2.6, 0.5, -1.0), 17.0, 0.45, 5, "m_metal_dark", r_top=0.4)
    box(b, V(-w / 2 + 2.6, 15.6, -1.0), (0.7, 4.4, 6.4), {"side": "m_sign", "top": "m_sign_frame", "skip_bottom": True})
    return finish(b, w, d, h + 0.5 + 6.0, "low", ["PineVillage", "SkiLiftRidge"], shop=True, module="shop")


def shop_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0
    snow_pad(b, w, d)
    L.plain_building(b, w - 3.0, 14.0, h, "w_wall_3", "w_trim_1", "w_roof_flat", "w_door", windows=2, parapet=True, y0=0.5)
    box(b, V(0, h + 1.8, 7.0), (w - 2.0, 1.2, 15.4), {"side": "m_white", "top": "m_white", "skip_bottom": True})  # a deep snow roof
    box(b, V(0, 8.8, -2.4), (w - 5.0, 0.5, 4.6), {"side": "w_accent_1", "top": "m_white", "skip_bottom": True})  # a plain golden awning
    box(b, V(w / 2 - 1.2, 11.0, -1.2), (0.6, 4.0, 4.0), {"side": "m_sign", "top": "m_sign_frame", "skip_bottom": True})
    return finish(b, w, d, h + 3.0, "low", ["PineVillage", "SummitLodge"], shop=True, module="shop")


def lodge_lot(name, w, h):
    b = L.new(name)
    d = 24.0
    snow_pad(b, w, d)
    box(b, V(0, 3.2, 13.0), (w - 2.0, 6.4, 18.0), {"side": "m_stone", "top": "m_stone", "skip_bottom": True})  # stone base
    L.plain_building(b, w - 6.0, 15.0, h - 6.0, "w_wall_1", "w_trim_1", "w_roof_flat", "w_door", windows=4, parapet=False, y0=6.4, x=0.0)
    gable(b, -w * 0.2, 0.0, 18.0, w * 0.46, h + 0.4, 7.0, "w_roof_1")
    gable(b, w * 0.2, 0.0, 18.0, w * 0.46, h + 0.4, 7.0, "w_roof_1")
    box(b, V(0, 14.0, -1.4), (w * 0.6, 0.6, 4.6), {"side": "w_roof_1", "top": "m_white", "skip_bottom": True})
    cyl(b, V(w / 2 - 3.0, 0.5, -1.0), 19.0, 0.5, 5, "m_metal_dark", r_top=0.45)
    box(b, V(w / 2 - 3.0, 17.8, -1.0), (0.8, 5.0, 7.6), {"side": "m_sign", "top": "m_sign_frame", "skip_bottom": True})
    return finish(b, w, d, h + 7.5, "low", ["PineVillage", "SummitLodge"], shop=True, module="shop")


def pines_lot(name, w, n, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0 if w < 30 else 22.0
    L.pad(b, w, d, "g_hi", 0.5)
    for i in range(n):
        L.pine(b, -w / 2 + (i + 0.5) * w / n + (rng.random() - 0.5) * 2.5, 4 + rng.random() * (d - 8), h * (0.7 + 0.3 * rng.random()), rng, snow=True, tiers=3)
    return finish(b, w, d, h, "low", ALL)


def bank_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0
    mound(b, 0, d / 2, w * 0.5, d * 0.46, h, rng, SNOW, y0=0.0)
    mound(b, -w * 0.2, d * 0.35, w * 0.26, d * 0.28, h * 0.7, rng, ["g_sand", "g_hi", "g_hi"], y0=0.0)
    L.pine(b, w * 0.26, d * 0.6, 9.0, rng, snow=True, tiers=2)
    return finish(b, w, d, h + 6.0, "low", ALL)


def rocks_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "g_hi", 0.5)
    for i in range(5):
        sx = 5 + rng.random() * 6
        L.rock(b, -w / 2 + 4 + (w - 8) * i / 4 + rng.random() * 2, 4 + rng.random() * (d - 8), sx, h * (0.6 + 0.4 * rng.random()), sx * 0.9, rng, y=0.5, light=("r_1", "r_2", "r_3", "m_white"), subdiv=1)
    return finish(b, w, d, h, "low", ["SkiLiftRidge", "GlacierTunnel", "SummitLodge"])


def liftshed_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    snow_pad(b, w, d)
    box(b, V(0, h / 2 + 0.5, 12.0), (w - 6.0, h, 14.0), {"side": "m_metal", "top": "m_white", "skip_bottom": True})
    box(b, V(0, h + 1.4, 12.0), (w - 5.0, 1.0, 15.0), {"side": "w_roof_1", "top": "m_white", "skip_bottom": True})
    b.face([V(-4.0, 0.5, 4.95), V(4.0, 0.5, 4.95), V(4.0, 8.5, 4.95), V(-4.0, 8.5, 4.95)], "m_metal_dark", V(0, 0, -1))
    cyl(b, V(w * 0.3, 0.5, 4.0), 16.0, 0.6, 5, "m_metal_dark", r_top=0.5)
    cyl(b, V(w * 0.3 - 2.4, 15.0, 4.0), 0.6, 2.8, 12, "m_metal", r_top=2.8, top_sw="m_metal_dark")  # a bullwheel on the post
    return finish(b, w, d, h + 2.5, "low", ["SkiLiftRidge"])


def ice_lot(name, w, h, districts):
    rng = rng_of(name)
    b = L.new(name)
    d = 20.0 if w < 30 else 22.0
    L.pad(b, w, d, "w_glass_light", 0.5)
    for i in range(int(w // 8) + 1):
        x = -w / 2 + 3 + i * (w - 6) / max(1, int(w // 8))
        hh = h * (0.5 + 0.5 * rng.random())
        cyl(b, V(x, 0.5, 4 + rng.random() * (d - 8)), hh, 2.6 + rng.random() * 1.4, 5, "w_glass", r_top=0.5, top_sw="w_glass_light", phase=rng.random())
    return finish(b, w, d, h + 1.0, "low", districts)


def pier_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 22.0
    L.pad(b, w, d, "w_glass_light", 0.5)
    box(b, V(0, 1.2, 8.0), (w - 6.0, 0.7, 7.0), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})  # the boardwalk
    for x in (-w / 2 + 4, w / 2 - 4):
        for z in (4.8, 11.2):
            box(b, V(x, 0.9, z), (0.6, 1.6, 0.6), {"side": "m_wood_2", "skip_bottom": True})
    for x in (-w * 0.2, w * 0.2):
        box(b, V(x, 2.4, 5.0), (4.0, 0.5, 1.4), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
        box(b, V(x, 3.4, 4.4), (4.0, 1.4, 0.3), {"side": "m_wood_1", "skip_bottom": True})
    L.pine(b, w / 2 - 3.0, d - 4.0, 9.0, rng, snow=True, tiers=2)
    return finish(b, w, d, h, "low", ["FrozenLake"])


def peak_lot(name, w, h, d=24.0):
    rng = rng_of(name)
    b = L.new(name)
    L.pad(b, w, d, "g_hi", 0.5)
    y = 0.5
    r = w * 0.52
    parts = (("r_1", 0.30), ("r_2", 0.26), ("r_3", 0.22), ("m_white", 0.22))
    for i, (sw, f) in enumerate(parts):
        seg = (h - 0.5) * f
        cyl(b, V(rng.random() - 0.5, y, d / 2), seg, r, 5 + (i % 2), sw, r_top=r * (0.72 if i < 3 else 0.12), top_sw="m_white", phase=0.25 * i)
        y += seg
        r *= 0.72
    return finish(b, w, d, h, "mid", ["SkiLiftRidge", "FrozenLake", "GlacierTunnel", "SummitLodge"])


def serac_lot(name, w, h):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    L.pad(b, w, d, "w_glass_light", 0.5)
    n = 3 if w < 40 else 4
    for i in range(n):
        x = -w / 2 + (i + 0.5) * w / n
        hh = h * (0.55 + 0.45 * rng.random())
        strata_block(b, x, 6.0 + rng.random() * 10, w / n * (0.8 + 0.2 * rng.random()), 9.0 + rng.random() * 5, 0.5, hh, ["w_glass", "w_glass_light", "w_glass", "r_pale"], tops=True)
    return finish(b, w, d, h, "mid", ["GlacierTunnel", "FrozenLake"])


def snowfield_lot(name, w):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    mound(b, 0, d / 2, w * 0.5, d * 0.46, 5.0, rng, SNOW)
    L.pine(b, -w * 0.3, d * 0.6, 14.0, rng, snow=True)
    if w > 30:
        L.pine(b, w * 0.3, d * 0.35, 16.0, rng, snow=True)
    snowman_parts(b, w * 0.05, d * 0.3, 1.0, rng)
    return finish(b, w, d, 17.0, "low", ALL, module="park")


def firepit_lot(name, w):
    rng = rng_of(name)
    b = L.new(name)
    d = 24.0
    L.pad(b, w, d, "g_sand", 0.5)
    ring = circle2(0, d * 0.5, 4.2, 10)
    for x, z in ring:
        L.rock(b, x, z, 1.6, 1.0, 1.5, rng, y=0.5, light=("r_2", "r_3", "r_4", "r_pale"))
    cyl(b, V(0, 0.5, d * 0.5), 2.2, 1.4, 6, "w_accent_1", r_top=0.2, top_sw="w_accent_3")
    for k in range(4):
        a = math.pi / 2 * k + 0.4
        box(b, V(math.cos(a) * 7.4, 1.2, d * 0.5 + math.sin(a) * 7.4), (4.6, 1.6, 1.4), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True}, yaw=-a + math.pi / 2)
    L.pine(b, -w / 2 + 3.5, 4.0, 14.0, rng, snow=True)
    L.pine(b, w / 2 - 3.5, d - 4.0, 12.0, rng, snow=True)
    return finish(b, w, d, 15.0, "mid", ["PineVillage", "SkiLiftRidge", "SummitLodge"], module="plaza")


# ---------------------------------------------------------------- snowmen
def snowman_parts(b, x, z, s, rng, scarf="w_accent_2", hat="m_black"):
    sphere(b, V(x, 0.5 + 1.8 * s, z), (1.8 * s, 1.7 * s, 1.8 * s), ["m_white", "m_white", "g_hi"], subdiv=1, rng=None)
    sphere(b, V(x, 0.5 + 4.4 * s, z), (1.3 * s, 1.25 * s, 1.3 * s), ["m_white", "m_white", "g_hi"], subdiv=1, rng=None)
    sphere(b, V(x, 0.5 + 6.2 * s, z), (0.95 * s, 0.9 * s, 0.95 * s), ["m_white", "m_white", "g_hi"], subdiv=1, rng=None)
    box(b, V(x, 0.5 + 5.4 * s, z), (2.4 * s, 0.5 * s, 2.4 * s), {"side": scarf, "top": scarf, "skip_bottom": True})
    cyl(b, V(x, 0.5 + 6.9 * s, z), 1.1 * s, 0.9 * s, 6, hat, r_top=0.8 * s, top_sw=hat)
    box(b, V(x, 0.5 + 6.2 * s, z - 1.1 * s), (0.3 * s, 0.3 * s, 0.9 * s), {"side": "w_accent_3", "skip_bottom": True})  # a carrot nose


# ---------------------------------------------------------------- landmarks
def chalet_cluster(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 60.0, 26.0, 28.0
    snow_pad(b, w, d)
    for x, cw, hh, wall in ((-20.0, 18.0, 14.0, "w_wall_1"), (1.0, 20.0, 18.0, "w_wall_3"), (21.0, 16.0, 12.0, "w_wall_1")):
        chalet_body(b, x, cw, 14.0, hh, wall, 7.0 + (hh - 12) * 0.4, windows=2)
    for x in (-27.0, 11.0, 28.0):
        L.pine(b, x, d - 3.0, 15.0 + rng.random() * 3, rng, snow=True)
    return lm_finish(b, w, d, h, ["PineVillage"])


def bell_tower(name):
    b = L.new(name)
    w, d, h = 28.0, 28.0, 52.0
    snow_pad(b, w, d)
    box(b, V(0, 17.0, 14.0), (13.0, 34.0, 13.0), {"side": "m_stone", "top": "m_stone", "skip_bottom": True})
    for y in (8.0, 20.0):
        b.face([V(-1.6, y, 7.45), V(1.6, y, 7.45), V(1.6, y + 5.0, 7.45), V(-1.6, y + 5.0, 7.45)], "m_metal_dark", V(0, 0, -1))
    box(b, V(0, 38.0, 14.0), (13.6, 8.0, 13.6), {"side": "w_wall_2", "top": "w_wall_2", "skip_bottom": True})
    for s in (-1, 1):
        b.face([V(-3.0, 35.0, 14.0 + s * 6.9), V(3.0, 35.0, 14.0 + s * 6.9), V(3.0, 41.0, 14.0 + s * 6.9), V(-3.0, 41.0, 14.0 + s * 6.9)], "m_metal_dark", V(0, 0, s))
        b.face([V(s * 6.9, 35.0, 11.0), V(s * 6.9, 35.0, 17.0), V(s * 6.9, 41.0, 17.0), V(s * 6.9, 41.0, 11.0)], "m_metal_dark", V(s, 0, 0))
    cyl(b, V(0, 42.0, 14.0), 9.0, 8.6, 4, "w_roof_1", r_top=0.4, top_sw="m_white", phase=math.pi / 4)
    cyl(b, V(0, 50.0, 14.0), 2.0, 0.3, 4, "m_metal", r_top=0.05)
    disc = circle2(0, 0, 3.0, 12)
    for sx in (-1, 1):
        b.face([V(sx * 6.75, 26.0 + z, 14.0 + x) for x, z in disc], "m_white", V(sx, 0, 0))
    return lm_finish(b, w, d, h, ["PineVillage"])


def ski_lift(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 60.0, 24.0, 44.0
    snow_pad(b, w, d)
    for x in (-22.0, 22.0):  # two lattice towers, an A-frame across the road, a crossarm and a sheave
        for z in (8.0, 16.0):
            beam(b, V(x, 0.5, z), V(x, 34.0, 12.0), 1.0, 1.0, "m_metal_dark")
        beam(b, V(x, 14.0, 8.0), V(x, 14.0, 16.0), 0.5, 0.5, "m_metal")
        beam(b, V(x, 24.0, 10.0), V(x, 24.0, 14.0), 0.5, 0.5, "m_metal")
        box(b, V(x, 35.0, 12.0), (1.6, 1.2, 9.0), {"side": "m_metal_dark", "top": "m_metal", "skip_bottom": True})
    for z in (9.0, 15.0):  # two cable runs along the road axis with sag
        pts = [V(-30.0 + 60.0 * k / 12, 35.0 - 3.6 * math.sin(math.pi * k / 12) * (1 if (k > 0) else 0) - (0.0), z) for k in range(13)]
        tube(b, pts, 0.25, 4, "m_black", phase=math.pi / 4)
    for k, x in enumerate((-14.0, -2.0, 10.0)):  # chairs hanging from the cable
        for z in (9.0, 15.0):
            beam(b, V(x, 33.0, z), V(x, 27.0, z), 0.2, 0.2, "m_metal_dark")
            box(b, V(x, 26.4, z), (3.6, 0.5, 1.6), {"side": "w_accent_2", "top": "w_accent_2", "skip_bottom": True})
            box(b, V(x, 28.2, z + (0.7 if z > 12 else -0.7)), (3.6, 3.2, 0.3), {"side": "w_accent_2", "skip_bottom": True})
    box(b, V(-w / 2 + 6.0, 5.0, 18.0), (10.0, 10.0, 7.0), {"side": "m_metal", "top": "m_white", "skip_bottom": True})  # the bottom station shed
    return lm_finish(b, w, d, h, ["SkiLiftRidge"], read="lift towers, cable and chairs along the road")


def warming_hut(name):
    b = L.new(name)
    w, d, h = 36.0, 24.0, 18.0
    snow_pad(b, w, d)
    L.plain_building(b, 22.0, 14.0, 11.0, "w_wall_1", "w_trim_1", "w_roof_flat", "w_door", windows=2, parapet=False, y0=0.5, x=-2.0)
    gable(b, -2.0, 0.0, 14.0, 22.0, 11.5, 5.0, "w_roof_1")
    box(b, V(7.0, 11.0, 9.0), (2.2, 9.0, 2.2), {"side": "m_stone", "top": "m_white", "skip_bottom": True})
    box(b, V(-12.0, 12.0, -2.0), (0.6, 5.0, 6.0), {"side": "m_sign", "top": "m_sign_frame", "skip_bottom": True})
    return lm_finish(b, w, d, h, ["SkiLiftRidge"])


def frozen_lake(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 72.0, 40.0, 10.0
    ring = circle2(0, 0, 1.0, 16)
    b.face([V(x * 34.0, 0.45, 20.0 + z * 15.0) for x, z in ring], "w_glass_light", V(0, 1, 0))
    b.face([V(x * 30.0, 0.5, 20.0 + z * 12.0) for x, z in ring], "g_water", V(0, 1, 0))
    for k in range(16):
        a = 2 * math.pi * k / 16
        L.rock(b, math.cos(a) * 35.0, 20.0 + math.sin(a) * 16.0, 4.0 + rng.random() * 2, 2.4, 3.6, rng, y=0.4, light=("r_1", "r_2", "r_3", "m_white"))
    for i, col in enumerate(("w_accent_2", "w_accent_3", "w_accent_1", "w_accent_2", "w_accent_3")):  # skaters
        sx, sz = -18.0 + i * 9.0, 14.0 + (i % 3) * 5.0
        cyl(b, V(sx, 0.5, sz), 3.0, 0.7, 6, col, r_top=0.5)
        sphere(b, V(sx, 4.0, sz), (0.55, 0.55, 0.55), ["w_wall_2", "w_wall_2", "w_wall_2"], subdiv=0)
    for x in (-34.0, 34.0):
        L.pine(b, x, 4.0, 15.0, rng, snow=True)
    return lm_finish(b, w, d, h, ["FrozenLake"], read="a frozen lake with decorative skaters")


def skate_hut(name):
    b = L.new(name)
    w, d, h = 36.0, 22.0, 16.0
    snow_pad(b, w, d)
    L.plain_building(b, 24.0, 12.0, 9.0, "w_wall_3", "w_trim_1", "w_roof_flat", "w_door", windows=2, parapet=False, y0=0.5)
    gable(b, 0.0, 0.0, 12.0, 24.0, 9.5, 4.6, "w_roof_1")
    box(b, V(0, 8.0, -3.0), (22.0, 0.5, 5.0), {"side": "w_accent_1", "top": "m_white", "skip_bottom": True})
    for i in range(4):
        box(b, V(-8.0 + i * 5.4, 1.4, -2.4), (1.6, 1.8, 2.6), {"side": "m_metal", "top": "w_accent_2", "skip_bottom": True})
    return lm_finish(b, w, d, h, ["FrozenLake"])


def glacier_tunnel(name):
    """GLACIER TUNNEL (bridge landmark, 384 along the route, centred on the deck centre): twelve opaque ice ribs arching
    over the deck (rx 56, crown 40: clear of the 50.8 frontage and well over the 18 clearance), ice roof slabs on every
    other bay so the approach stays readable, ice walls and hanging icicles. The deck is the shared B2_Road pieces."""
    rng = rng_of(name)
    b = L.new(name)
    Lh = 192
    rx, ry = 56.0, 40.0
    ribs = list(range(-176, 177, 32))
    for zi, z in enumerate(ribs):
        path = [V(math.cos(math.pi * k / 10) * rx, math.sin(math.pi * k / 10) * ry, z) for k in range(11)]
        tube(b, path, 4.0, 4, ["w_glass", "w_glass_light"], phase=math.pi / 4)
        for k in range(1, 10, 2):  # icicles under the crown
            p = path[k]
            cyl(b, V(p.x * 0.97, p.y - 4.0 - 6.0 * rng.random(), z), 5.0 + 5.0 * rng.random(), 0.15, 4, "w_glass_light", r_top=1.0)
    for i in range(len(ribs) - 1):
        if i % 2 == 0:
            z0, z1 = ribs[i] + 3.0, ribs[i + 1] - 3.0
            for k in range(10):
                a0, a1 = math.pi * k / 10, math.pi * (k + 1) / 10
                p0 = (math.cos(a0) * (rx + 0.6), math.sin(a0) * (ry + 0.6))
                p1 = (math.cos(a1) * (rx + 0.6), math.sin(a1) * (ry + 0.6))
                b.face([V(p0[0], p0[1], z0), V(p1[0], p1[1], z0), V(p1[0], p1[1], z1), V(p0[0], p0[1], z1)], "w_glass" if (k + i) % 3 else "r_pale", V(-math.cos((a0 + a1) / 2), -1, 0))
    for s in (-1, 1):  # ice walls and pylons at the two ends
        for zi in range(-Lh, Lh, 64):
            strata_block(b, s * (rx + 6.0), zi + 32.0, 10.0, 62.0, 0.0, 16.0 + 6.0 * rng.random(), ["w_glass", "w_glass_light", "r_pale"], tops=True)
        for z in (-Lh + 4.0, Lh - 4.0):
            strata_block(b, s * (rx - 2.0), z, 8.0, 8.0, 0.0, 30.0, ["w_glass", "r_pale", "w_glass_light"], tops=True)
    return b, L.lot_meta(WORLD, "LM", "landmark", 384.0, 0.0, 44.0, "landmark", ["GlacierTunnel"], {"start": sock((0, 0, 192)), "end": sock((0, 0, -192))}, False, placement="bridge", pairs_with=["B2_Road_BridgeDeck192_L4W17", "B2_Road_Abutment96_L4W17"])


def summit_lodge(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 72.0, 30.0, 40.0
    snow_pad(b, w, d)
    box(b, V(0, 5.0, 17.0), (w - 6.0, 10.0, 22.0), {"side": "m_stone", "top": "m_stone", "skip_bottom": True})
    L.plain_building(b, w - 10.0, 20.0, 18.0, "w_wall_1", "w_trim_1", "w_roof_flat", "w_door", windows=6, parapet=False, y0=10.0)
    box(b, V(0, 13.0, -2.8), (w - 12.0, 0.7, 4.4), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})  # the balcony
    for i in range(9):
        box(b, V(-w / 2 + 8 + i * (w - 16) / 8, 14.4, -4.8), (0.4, 2.2, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    gable(b, -w * 0.18, 0.0, 22.0, w * 0.5, 28.0, 10.0, "w_roof_1")
    gable(b, w * 0.24, 0.0, 22.0, w * 0.34, 28.0, 8.0, "w_roof_1")
    for x in (-w * 0.3, w * 0.3):
        box(b, V(x, 32.0, 14.0), (2.8, 12.0, 2.8), {"side": "m_stone", "top": "m_white", "skip_bottom": True})
    cyl(b, V(0, 38.0, 2.0), 10.0, 0.3, 4, "m_metal", r_top=0.2)
    box(b, V(1.8, 45.0, 2.0), (3.4, 2.2, 0.2), {"side": "w_accent_2", "skip_bottom": True})
    for x in (-w * 0.42, w * 0.42):
        L.pine(b, x, d - 4.0, 18.0, rng, snow=True)
    return lm_finish(b, w, d, 47.0, ["SummitLodge"])


def observatory(name):
    b = L.new(name)
    w, d, h = 36.0, 30.0, 46.0
    snow_pad(b, w, d)
    cyl(b, V(0, 0.5, 16.0), 26.0, 12.0, 12, "w_wall_2", r_top=11.0, top_sw="m_white", phase=0.2)
    cyl(b, V(0, 18.0, 16.0), 1.4, 12.6, 12, "m_stone", r_top=12.6, phase=0.2)
    for k in range(5):  # dome rings
        a0, a1 = math.pi / 2 * k / 5, math.pi / 2 * (k + 1) / 5
        cyl(b, V(0, 26.5 + 11.0 * math.sin(a0), 16.0), 11.0 * (math.sin(a1) - math.sin(a0)) + 0.1, 11.0 * math.cos(a0), 12, "w_accent_1" if k % 2 else "w_wall_4", r_top=11.0 * math.cos(a1), top_sw="m_white", phase=0.2)
    box(b, V(0, 34.0, 16.0 - 8.0), (3.0, 11.0, 4.0), {"side": "m_black", "skip_bottom": True})  # the telescope slit
    beam(b, V(0, 33.0, 4.0), V(0, 40.0, -1.0), 1.4, 1.4, "m_metal")
    for k in range(3):
        b.face([V(-1.4 + k * 1.4, 8.0, 4.0), V(-0.4 + k * 1.4, 8.0, 4.0), V(-0.4 + k * 1.4, 14.0, 4.0), V(-1.4 + k * 1.4, 14.0, 4.0)], "w_glass_light", V(0, 0, -1))
    return lm_finish(b, w, d, h, ["SummitLodge"])


def snowmen_row(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 48.0, 20.0, 14.0
    snow_pad(b, w, d)
    cols = ("w_accent_2", "w_accent_3", "w_accent_1", "w_accent_2", "w_accent_3")
    for i in range(5):
        snowman_parts(b, -w / 2 + 5 + i * (w - 10) / 4, 6.0 + (i % 2) * 5.0, 1.5 - 0.15 * abs(i - 2), rng, scarf=cols[i], hat="m_black" if i % 2 == 0 else "w_roof_1")
    return lm_finish(b, w, d, h, ["SummitLodge"])


def festival_stage(name):
    b = L.new(name)
    w, d, h = 60.0, 28.0, 22.0
    snow_pad(b, w, d)
    box(b, V(0, 2.0, 16.0), (40.0, 3.0, 16.0), {"side": "m_wood_2", "top": "m_wood_1", "skip_bottom": True})
    for x in (-18.0, 18.0):
        box(b, V(x, 11.0, 9.0), (0.8, 18.0, 0.8), {"side": "m_metal_dark", "skip_bottom": True})
    box(b, V(0, 20.0, 14.0), (42.0, 1.2, 14.0), {"side": "w_accent_2", "top": "m_white", "skip_bottom": True})
    for i in range(7):
        b.face([V(-18.0 + i * 6.0, 19.6, 6.6), V(-15.0 + i * 6.0, 19.6, 6.6), V(-16.5 + i * 6.0, 16.0, 6.6)], "w_accent_3" if i % 2 else "w_accent_1", V(0, 0, -1))
    return lm_finish(b, w, d, h, [], read="tier B kit gallery: winter festival stage")


def sled_hill(name):
    rng = rng_of(name)
    b = L.new(name)
    w, d, h = 60.0, 36.0, 20.0
    mound(b, 0, d * 0.55, w * 0.5, d * 0.5, h, rng, SNOW)
    for x in (-8.0, 4.0, 14.0):
        box(b, V(x, 0.7, 6.0), (1.2, 0.5, 3.4), {"side": "w_accent_2", "top": "w_accent_2", "skip_bottom": True})
    L.pine(b, -w * 0.4, d * 0.7, 16.0, rng, snow=True)
    return lm_finish(b, w, d, h, [], read="tier B kit gallery: sled hill")


# ---------------------------------------------------------------- props
def prop_meta(kind, h):
    return {"family": "Prop", "world": WORLD, "lod": NEAR, "district": "any", "kind": kind, "pivot": "bottom centre, on the sidewalk; -Z toward the road", "sockets": {"base": sock((0, 0, 0))}, "height": h}


def pole(name):
    b = L.new(name)
    cyl(b, V(0, 0, 0), 15.0, 0.4, 5, "m_metal_dark", r_top=0.34)
    box(b, V(0, 14.8, -1.2), (0.4, 0.4, 3.0), {"side": "m_metal_dark", "skip_bottom": True})
    box(b, V(0, 14.0, -2.4), (1.2, 1.6, 1.2), {"side": "m_light", "top": "m_white", "skip_bottom": True})
    box(b, V(0, 15.4, -2.4), (1.6, 0.5, 1.6), {"side": "m_white", "top": "m_white", "skip_bottom": True})
    return b, prop_meta("lamp", 16.0)


def bus_shelter(name):
    b = L.new(name)
    box(b, V(0, 8.0, 0.4), (9.0, 0.5, 4.4), {"side": "m_wood_1", "top": "m_white", "skip_bottom": True})
    box(b, V(0, 4.2, 2.4), (9.0, 7.0, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    for x in (-4.2, 4.2):
        box(b, V(x, 4.0, -1.4), (0.4, 8.0, 0.4), {"side": "m_wood_2", "skip_bottom": True})
    box(b, V(0, 1.6, 1.3), (6.4, 0.5, 1.4), {"side": "m_wood_1", "top": "m_wood_1", "skip_bottom": True})
    return b, prop_meta("busStop", 8.5)


def prop_pine(name):
    b = L.new(name)
    L.pine(b, 0, 0, 14.0, rng_of(name), snow=True, tiers=3)
    return b, prop_meta("pine", 14.0)


def prop_rock(name):
    rng = rng_of(name)
    b = L.new(name)
    L.rock(b, 0, 0, 2.8, 2.0, 2.4, rng, light=("r_1", "r_2", "r_3", "m_white"))
    L.rock(b, 2.0, 1.0, 1.6, 1.2, 1.5, rng, light=("r_2", "r_3", "m_white", "m_white"))
    return b, prop_meta("rock", 2.6)


def prop_snowman(name):
    b = L.new(name)
    snowman_parts(b, 0, 0, 0.9, rng_of(name))
    return b, prop_meta("snowman", 7.4)


def prop_barrel(name):
    b = L.new(name)
    cyl(b, V(0, 0, 0), 3.0, 1.2, 8, "m_wood_1", r_top=1.2, top_sw="m_white")
    cyl(b, V(0, 0.7, 0), 0.4, 1.28, 8, "m_metal_dark", top=False)
    cyl(b, V(0, 2.0, 0), 0.4, 1.28, 8, "m_metal_dark", top=False)
    return b, prop_meta("barrel", 3.0)


def fence_post(name):
    b = L.new(name)
    box(b, V(0, 1.6, 0), (0.5, 3.2, 0.5), {"side": "m_wood_2", "top": "m_white", "skip_bottom": True})
    box(b, V(3.0, 2.5, 0), (6.0, 0.3, 0.25), {"side": "m_wood_1", "top": "m_white", "skip_bottom": True})
    box(b, V(3.0, 1.5, 0), (6.0, 0.3, 0.25), {"side": "m_wood_1", "top": "m_white", "skip_bottom": True})
    return b, prop_meta("fencePost", 3.2)


# ---------------------------------------------------------------- hazards (scenery previews)
def haz_meta(kind, note):
    return {"family": "Haz", "world": WORLD, "lod": NEAR, "district": "any", "kind": kind, "pivot": "centre on the surface it stands on", "sockets": {"base": sock((0, 0, 0))}, "rule": note}


def frost_crack(name):
    rng = rng_of(name)
    b = L.new(name)
    ring = circle2(0, 0, 1.0, 12)
    b.face([V(x * 7.0, 0.05, z * 5.0) for x, z in ring], "hz_light", V(0, 1, 0))
    for k in range(4):  # dark jagged crack strips across the patch
        a = (k - 1.5) * 0.45
        pts = [V(-6.0 + 3.0 * j, 0.08, (rng.random() - 0.5) * 3.0 + a * (-6.0 + 3.0 * j) * 0.4) for j in range(5)]
        for j in range(4):
            p, q = pts[j], pts[j + 1]
            b.face([V(p.x, 0.09, p.z - 0.25), V(q.x, 0.09, q.z - 0.25), V(q.x, 0.09, q.z + 0.25), V(p.x, 0.09, p.z + 0.25)], "hz_dark", V(0, 1, 0))
    return b, haz_meta("pothole", "frost crack: dark cracks across a pale ice patch, scenery preview only")


def ice_patch(name):
    b = L.new(name)
    ring = circle2(0, 0, 1.0, 14)
    b.face([V(x * 8.0, 0.05, z * 5.5) for x, z in ring], "hz_rim", V(0, 1, 0))
    b.face([V(x * 6.4, 0.07, z * 4.2) for x, z in ring], "hz_light", V(0, 1, 0))
    b.face([V(x * 3.6 - 1.4, 0.09, z * 2.2) for x, z in ring], "hz_gloss", V(0, 1, 0))
    return b, haz_meta("oil", "ice patch: a glossy pale patch, scenery preview only")


def snowbank_haz(name):
    rng = rng_of(name)
    b = L.new(name)
    mound(b, 0, 0, 10.0, 4.6, 2.2, rng, ["g_lo", "g_sand", "g_hi"], rings=3, segs=12)
    for s in (-1, 1):  # plow stakes and cones (construction language is hazard-only)
        for z in (-3.6, 3.6):
            box(b, V(s * 11.6, 2.4, z), (0.4, 4.8, 0.4), {"side": "haz_orange", "top": "haz_white", "skip_bottom": True})
        cyl(b, V(s * 12.8, 0, 0.0), 2.0, 0.7, 6, "haz_orange", r_top=0.2, top_sw="haz_white")
    return b, haz_meta("construction", "snowbank with plow stakes and cones (construction language is hazard-only)")


# ---------------------------------------------------------------- distant masses
def mass_meta(kind, h, w, d):
    return {"family": "Mid", "world": WORLD, "lod": "mid", "district": "any", "kind": kind, "width": w, "depth": d, "height": h, "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}, "band": "midground 60-140 from the road edge"}


def peak_mass(name, w, d, h, tiers):
    b = L.new(name)
    y, r = 0.0, w * 0.5
    sws = ["r_1", "r_2", "r_3", "m_white"]
    for i in range(tiers):
        seg = h / tiers
        cyl(b, V(0, y, d / 2), seg, r, 6, sws[min(i, 3)] if i < tiers - 1 else "m_white", r_top=r * (0.7 if i < tiers - 1 else 0.1), top_sw="m_white", phase=0.3 * i)
        y += seg
        r *= 0.7
    return b, mass_meta("peak", h, w, d)


def slope_mass(name, w, d, h):
    rng = rng_of(name)
    b = L.new(name)
    mound(b, 0, d / 2, w * 0.5, d * 0.5, h, rng, ["g_lo", "g_sand", "g_hi"], rings=3, segs=12)
    L.pine(b, -w * 0.22, d * 0.4, h * 0.5, rng, snow=True, tiers=3)
    L.pine(b, w * 0.2, d * 0.52, h * 0.42, rng, snow=True, tiers=3)
    return b, mass_meta("slope", h, w, d)


def glacier_mass(name, w, d, h):
    rng = rng_of(name)
    b = L.new(name)
    for i in range(4):
        hh = h * (0.5 + 0.5 * rng.random()) if i != 1 else h
        strata_block(b, -w * 0.36 + i * w * 0.24, d / 2 + (rng.random() - 0.5) * 6, w * 0.26, d * (0.6 + 0.3 * rng.random()), 0.0, hh, ["w_glass", "w_glass_light", "w_glass", "r_pale"], tops=True)
    return b, mass_meta("glacier", h, w, d)


def sky_unit(name, kind, tiers):
    b = L.new(name)
    for i, (r, h0, h1) in enumerate(tiers):
        cyl(b, V(0, h0, 0), h1 - h0, r, 5, "sk_1" if i % 2 == 0 else "sk_3", r_top=r * 0.74 if i < len(tiers) - 1 else r * 0.06, top_sw="sk_trim", phase=0.3 * i)
    return b, L.unit_meta(WORLD, "Sky", "far", "skyline 300-800 from the road edge", kind=kind)


def build_all(emit):
    D = ALL
    # lots
    emit(*chalet_lot("SP_Lot_Chalet24_a", 24, 16.0, "w_wall_1", 7.0, ["PineVillage", "SkiLiftRidge", "SummitLodge"]))
    emit(*chalet_lot("SP_Lot_Chalet36_b", 36, 18.0, "w_wall_3", 8.0, ["PineVillage", "SkiLiftRidge", "SummitLodge"]))
    emit(*cabin_lot("SP_Lot_Cabin24_a", 24, 12.0))
    emit(*cafe_lot("SP_Lot_Cafe36_a", 36, 16.0))
    emit(*shop_lot("SP_Lot_Shop24_a", 24, 14.0))
    emit(*lodge_lot("SP_Lot_Lodge48_a", 48, 20.0))
    emit(*pines_lot("SP_Lot_Pines36_a", 36, 6, 24.0))
    emit(*pines_lot("SP_Lot_Pines24_b", 24, 4, 20.0))
    emit(*bank_lot("SP_Lot_Bank36_a", 36, 8.0))
    emit(*bank_lot("SP_Lot_Bank24_b", 24, 7.0))
    emit(*rocks_lot("SP_Lot_Rocks36_a", 36, 14.0))
    emit(*liftshed_lot("SP_Lot_Shed36_a", 36, 14.0))
    emit(*ice_lot("SP_Lot_Ice24_a", 24, 8.0, ["FrozenLake", "GlacierTunnel"]))
    emit(*ice_lot("SP_Lot_Ice36_b", 36, 10.0, ["FrozenLake", "GlacierTunnel"]))
    emit(*pier_lot("SP_Lot_Pier36_a", 36, 10.0))
    emit(*peak_lot("SP_Lot_Peak36_a", 36, 40.0))
    emit(*peak_lot("SP_Lot_Peak48_b", 48, 48.0))
    emit(*peak_lot("SP_Lot_Crag24_a", 24, 34.0, 22.0))
    emit(*serac_lot("SP_Lot_Serac36_a", 36, 36.0))
    emit(*serac_lot("SP_Lot_Serac48_b", 48, 44.0))
    emit(*snowfield_lot("SP_Lot_Snowfield24", 24))
    emit(*snowfield_lot("SP_Lot_Snowfield36", 36))
    emit(*firepit_lot("SP_Lot_Firepit36_a", 36))
    # landmarks
    emit(*chalet_cluster("SP_LM_ChaletCluster"))
    emit(*bell_tower("SP_LM_BellTower"))
    emit(*ski_lift("SP_LM_SkiLift"))
    emit(*warming_hut("SP_LM_WarmingHut"))
    emit(*frozen_lake("SP_LM_FrozenLake"))
    emit(*skate_hut("SP_LM_SkateHut"))
    emit(*glacier_tunnel("SP_LM_GlacierTunnel384"))
    emit(*summit_lodge("SP_LM_SummitLodge"))
    emit(*observatory("SP_LM_Observatory"))
    emit(*snowmen_row("SP_LM_SnowmenRow"))
    emit(*festival_stage("SP_LM_FestivalStage"))
    emit(*sled_hill("SP_LM_SledHill"))
    # props
    emit(*pole("SP_Prop_Pole"))
    emit(*bus_shelter("SP_Prop_BusShelter"))
    emit(*prop_pine("SP_Prop_Pine"))
    emit(*prop_rock("SP_Prop_Rock"))
    emit(*prop_snowman("SP_Prop_Snowman"))
    emit(*prop_barrel("SP_Prop_Barrel"))
    emit(*fence_post("SP_Prop_FencePost"))
    # hazards
    emit(*frost_crack("SP_Haz_FrostCrack"))
    emit(*ice_patch("SP_Haz_IcePatch"))
    emit(*snowbank_haz("SP_Haz_Snowbank"))
    # middle distance (authored heights chosen to match the districts' midHeight ranges)
    emit(*slope_mass("SP_Mid_Slope_1", 44, 30, 30.0))
    emit(*slope_mass("SP_Mid_Slope_2", 48, 30, 52.0))
    emit(*peak_mass("SP_Mid_Peak_2", 40, 30, 66.0, 3))
    emit(*peak_mass("SP_Mid_Peak_1", 44, 30, 90.0, 4))
    emit(*glacier_mass("SP_Mid_Glacier_1", 52, 30, 108.0))
    # skyline (unit meshes, scaled per instance)
    emit(*sky_unit("SP_Sky_Peak_1", "peak", [(0.5, 0.0, 0.5), (0.36, 0.5, 0.82), (0.24, 0.82, 1.0)]))
    emit(*sky_unit("SP_Sky_Peak_2", "peak", [(0.5, 0.0, 0.62), (0.34, 0.62, 1.0)]))
    emit(*sky_unit("SP_Sky_Peak_3", "peak", [(0.5, 0.0, 0.4), (0.42, 0.4, 0.72), (0.3, 0.72, 0.9), (0.2, 0.9, 1.0)]))
    emit(*sky_unit("SP_Sky_Ridge_1", "ridge", [(0.5, 0.0, 0.5), (0.3, 0.5, 0.78)]))
    emit(*sky_unit("SP_Sky_Ridge_2", "ridge", [(0.5, 0.0, 0.34), (0.36, 0.34, 0.6), (0.2, 0.6, 0.72)]))
    emit(*sky_unit("SP_Sky_Horn", "horn", [(0.46, 0.0, 0.4), (0.3, 0.4, 0.74), (0.16, 0.74, 1.0)]))
