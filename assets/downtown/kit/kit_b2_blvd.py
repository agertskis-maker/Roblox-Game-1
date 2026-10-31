# Downtown kit B2, Round 2 boulevard refinement (Lane 3, R2-D1). Added to the existing recipes, not a new
# pipeline: the same B2Builder, palette, Frame and helpers as kit_b2_lots.py, built as the "blvd" group by
# kit_b2_build.py (--only blvd), so regenerating it never touches the other 140 meshes.
#
# Why: the selected wide-lane direction (4 lanes x 17 + shoulders) made the 2-3 storey Main Street shops read
# small. This group adds FOUR-TO-SIX storey shop-fronted frontage (ground floor 16 + upper storeys of 12, the
# same window rhythm, cornices and shop-level detail: more storeys, never a vertically stretched lot), a few
# set-back variants for varied rooflines, taller layered middle-distance blocks (with roof tanks and plant rooms)
# and a richer skyline (wedding-cake setbacks, crowns, water tanks, needles). The existing 2-3 storey lots stay
# as the "occasional" low buildings; the Catalog now derives a shop-fronted lot's height class from its storeys
# (<=3 low, 4 mid, >=5 tall) so district bags can ask for the mix.
#
# Awnings stay plain canvas (teal, burgundy, navy, green): orange/white striping is reserved for hazards.

import math

import kit_b2_lots as L
from kit_b2lib import B2Builder, Offset as Back, V, box, sock, strip_band, body, cornice, fquad, fp, fdir
from kitlib import cyl

STOREY = L.STOREY
LOT_DISTRICTS = ["MS", "CH", "MT", "SP"]  # not the harbour (warehouses there)


def height_class(n):
    return "low" if n <= 3 else ("mid" if n == 4 else "tall")


def flush_lot(name, W, n, cw, top):
    """A flush shop-fronted lot of n storeys (the shop_lot recipe with more upper floors)."""
    b, meta = L.shop_lot(name, W, n, cw, top=top, arched=(cw == "c" and n == 4), district=LOT_DISTRICTS)
    meta["height_class"] = height_class(n)
    meta["round2"] = "boulevard scale: %d storeys" % n
    return b, meta


def setback_lot(name, W, n, cw, D=22.0, setback=4.0):
    """n storeys with the top one set back 4 studs behind a terrace coping (a varied roofline): the lower
    block is the shop_lot grammar (shop ground, window pairs, quoins), the top storey a glazed grid in the
    wall colour, like the Midtown towers' top. The setback is on the street side only."""
    b = L.new(name, cw)
    hw = W / 2
    GF = 16.0
    mounts = L.shop_ground(b, W, GF)
    n_low = n - 2  # storeys between the ground floor and the set-back one
    L.uppers_pairs(b, W, GF, n_low)
    v1 = GF + n_low * STOREY
    L.quoin_strips(b, W, GF, v1)
    strip_band(b, -hw, hw, v1, v1 + 0.8, 0.5, "trim_1")
    b.face([V(-hw, v1 + 0.8, 0), V(hw, v1 + 0.8, 0), V(hw, v1 + 0.8, setback), V(-hw, v1 + 0.8, setback)], "roof", V(0, 1, 0))
    v = v1 + 0.8 + STOREY - 1.4
    tb = Back(b, setback)
    L.grid_face(tb, -hw + 2, hw - 2, v1 + 0.8, v, max(2, int((W - 4) // 6)), 1, "wall", "trim_1", "glass", depth=0.6, pier_w=1.0)
    for x in (-hw + 2, hw - 2):
        b.face([V(x, v1 + 0.8, setback), V(x, v1 + 0.8, D), V(x, v, D), V(x, v, setback)], "wall", V(1 if x > 0 else -1, 0, 0))
    strip_band(tb, -hw + 2, hw - 2, v, v + 1.0, 0.4, "trim_1")
    roof_y = v + 0.6
    b.face([V(-hw + 2, roof_y, setback), V(hw - 2, roof_y, setback), V(hw - 2, roof_y, D), V(-hw + 2, roof_y, D)], "roof", V(0, 1, 0))
    body(b, W, 0, v1 + 0.8, D, side="wall", back="wall")
    b.face([V(-hw + 2, v1 + 0.8, D), V(hw - 2, v1 + 0.8, D), V(hw - 2, v, D), V(-hw + 2, v, D)], "wall", V(0, 0, 1))
    fr = L.finish(b, W)
    extra = {}
    for i, (u, w) in enumerate(mounts):
        extra["fascia_%d" % (i + 1)] = sock((-u, 11.8, -0.3), frame=fr, max_width=round(w - 1.0, 2))
        extra["blade_%d" % (i + 1)] = sock((-(u + w / 2 - 0.6), GF + 0.6, 0.0), frame=fr)
    extra["roof_tank"] = sock((W * 0.2, roof_y, D * 0.62), frame=fr)
    meta = L.lot_meta("shop", W, D, v + 1.0, n, height_class(n), LOT_DISTRICTS, fr, roof_y, extra, colourway=cw, top="setback", setback_top=setback)
    meta["round2"] = "boulevard scale: %d storeys, top storey set back %g" % (n, setback)
    return b, meta


# ---------------------------------------------------------------- middle distance (60-140 studs back)
def mid_block2(name, w, d, h, sw, top):
    """mid_block's closed mass (window bands on the three visible faces) with richer tops:
    wedding: two setbacks; tank: a plant room and a roof water tank on stilts; slab: a long roof mass."""
    b, meta = L.mid_block(name, w, d, h, sw, "flat", "any")
    hw = w / 2
    H = h + 1.0
    if top == "wedding":
        box(b, V(0, h + 5.0, d / 2 + 1), (w * 0.72, 8.0, d * 0.74), {"side": "wall", "top": "roof", "skip_bottom": True})
        box(b, V(0, h + 11.0, d / 2 + 2), (w * 0.46, 8.0, d * 0.5), {"side": "wall", "top": "roof", "skip_bottom": True})
        box(b, V(0, h + 15.6, d / 2 + 2), (w * 0.46 + 0.8, 0.8, d * 0.5 + 0.8), {"side": "mid_trim", "top": "roof", "skip_bottom": True})
        H = h + 16.0
    elif top == "tank":
        box(b, V(-hw * 0.35, h + 3.0, d * 0.55), (w * 0.34, 4.5, d * 0.34), {"side": "mid_trim", "top": "roof_dark", "skip_bottom": True})
        for sx in (-1, 1):
            for sz in (-1, 1):
                box(b, V(hw * 0.4 + sx * 2.0, h + 4.0, d * 0.5 + sz * 2.0), (0.5, 6.0, 0.5), {"side": "roof_dark", "skip_bottom": True})
        cyl(b, V(hw * 0.4, h + 7.0, d * 0.5), 6.0, 3.6, 8, "mid_trim", r_top=3.4, phase=math.pi / 8)
        cyl(b, V(hw * 0.4, h + 13.0, d * 0.5), 2.0, 3.4, 8, "roof_dark", r_top=0.4, phase=math.pi / 8)
        H = h + 15.0
    elif top == "slab":
        box(b, V(0, h + 3.0, d * 0.6), (w * 0.8, 4.0, d * 0.5), {"side": "mid_trim", "top": "roof_dark", "skip_bottom": True})
        H = h + 5.5
    meta["height"] = H
    meta["round2"] = "middle-distance block with a %s top" % top
    return b, meta


# ---------------------------------------------------------------- skyline (unit meshes, scaled per instance)
def sky_wedding(name, body_sw, cap):
    """Three setbacks and a mast: the classic stepped-tower silhouette."""
    b = B2Builder(name)
    box(b, V(0, 0.28, 0), (1.0, 0.56, 1.0), {"side": body_sw, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.64, 0), (0.78, 0.16, 0.78), {"side": body_sw, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.82, 0), (0.54, 0.2, 0.54), {"side": cap, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.94, 0), (0.3, 0.08, 0.3), {"side": body_sw, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.99, 0), (0.04, 0.12, 0.04), {"side": cap, "skip_bottom": True})
    return b, {"unit": True, "note": "scale [width, height, depth]"}


def sky_crown(name, body_sw, cap):
    """A slab with a crown: a chamfered pyramid cap and a plant-room box."""
    b = B2Builder(name)
    box(b, V(0, 0.44, 0), (1.0, 0.88, 1.0), {"side": body_sw, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.92, 0), (0.84, 0.08, 0.84), {"side": cap, "top": cap, "skip_bottom": True})
    cyl(b, V(0, 0.9, 0), 0.1, 0.34, 4, cap, r_top=0.14, phase=math.pi / 4)
    return b, {"unit": True, "note": "scale [width, height, depth]"}


def sky_tank(name, body_sw, cap):
    """A slab with roof masses: a plant block and a water tank on stilts (stretched by the unit scale, so it
    is kept small and chunky: a silhouette at 300+ studs, not a detail)."""
    b = B2Builder(name)
    box(b, V(0, 0.46, 0), (1.0, 0.92, 1.0), {"side": body_sw, "top": cap, "skip_bottom": True})
    box(b, V(-0.22, 0.96, 0.1), (0.3, 0.08, 0.3), {"side": cap, "top": cap, "skip_bottom": True})
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(b, V(0.24 + sx * 0.05, 0.96, -0.12 + sz * 0.05), (0.025, 0.08, 0.025), {"side": cap, "skip_bottom": True})
    cyl(b, V(0.24, 0.98, -0.12), 0.1, 0.1, 8, cap, r_top=0.09, phase=math.pi / 8)
    return b, {"unit": True, "note": "scale [width, height, depth]"}


def sky_needle(name, body_sw, cap):
    """A slim tower with a tapering needle (a broadcast mast)."""
    b = B2Builder(name)
    box(b, V(0, 0.38, 0), (1.0, 0.76, 1.0), {"side": body_sw, "top": cap, "skip_bottom": True})
    box(b, V(0, 0.8, 0), (0.62, 0.08, 0.62), {"side": cap, "top": cap, "skip_bottom": True})
    cyl(b, V(0, 0.84, 0), 0.16, 0.12, 4, cap, r_top=0.01, phase=math.pi / 4)
    return b, {"unit": True, "note": "scale [width, height, depth]"}


def sky_meta(meta):
    meta.update({"family": "Sky", "lod": "far", "district": "any", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}})
    return meta


def build_all(emit):
    # 4-6 storey shop-fronted frontage (flush): 23 meshes across widths 24 / 36 / 48 and colourways a-d
    flush = [
        # (width, storeys, colourway, top)
        (24, 4, "a", "cornice"), (24, 4, "b", "pediment"), (24, 4, "c", "stepped"), (24, 4, "d", "cornice"),
        (24, 5, "a", "stepped"), (24, 5, "b", "cornice"), (24, 6, "c", "pediment"),
        (36, 4, "a", "pediment"), (36, 4, "b", "cornice"), (36, 4, "c", "stepped"),
        (36, 5, "b", "pediment"), (36, 5, "d", "cornice"), (36, 6, "a", "stepped"),
        (48, 4, "a", "stepped"), (48, 4, "c", "cornice"), (48, 5, "b", "cornice"), (48, 6, "d", "pediment"),
    ]
    for W, n, cw, top in flush:
        emit(*flush_lot("B2_Lot_Shop%dBlvd%d_%s" % (W, n, cw), W, n, cw, top))
    for W, n, cw in ((24, 5, "b"), (24, 6, "a"), (36, 5, "c"), (36, 6, "b"), (36, 6, "d"), (48, 5, "a"), (48, 6, "c")):
        emit(*setback_lot("B2_Lot_Shop%dStep%d_%s" % (W, n, cw), W, n, cw))
    # middle distance: taller, with tops
    emit(*mid_block2("B2_Mid_Block36_4", 36, 30, 92, "mid_1", "wedding"))
    emit(*mid_block2("B2_Mid_Block36_5", 36, 30, 84, "mid_2", "tank"))
    emit(*mid_block2("B2_Mid_Block48_1", 48, 30, 100, "mid_3", "slab"))
    emit(*mid_block2("B2_Mid_Block40_6", 40, 32, 118, "mid_4", "wedding"))
    # skyline
    for shape, fn in (("Wedding", sky_wedding), ("Crown", sky_crown), ("Tank", sky_tank), ("Needle", sky_needle)):
        for i, (body_sw, cap) in enumerate((("sky_1", "sky_trim"), ("sky_2", "sky_3"), ("sky_4", "sky_trim"))):
            b, meta = fn("B2_Sky_%s_%d" % (shape, i + 1), body_sw, cap)
            emit(b, sky_meta(meta))
