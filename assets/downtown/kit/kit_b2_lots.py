# Downtown kit B2: frontage lots, midground masses and roof props for direction B "Bright Real
# City" (selected). Inherits B's grammar from kit_b.py (warm brick over a cream-stone shop base,
# recessed windows with stone sills and lintels, stepped cream cornices, plain canvas awnings,
# quoined corners, rooftop tanks) but each lot is ONE whole building to the kit contract: widths
# 24/36/48, depth <= 24, low (2 storeys) / mid (3) / tall (5-7, Midtown).
#
# Lot frame (kit_b2lib): facade at z = 0 facing -Z, footprint x 0..W, z 0..D; pivot = the front
# corner on the lot's own left (min x) at ground level on the frontage line. Recipes are written
# centred and Frame(W / 2) shifts them. Swatches are generic names remapped per colourway
# (wall, stone, aw, aw2, door, shop, acc) onto the district swatches of kit_b2_palette, so one
# mesh recolours per district by palette image.
#
# Awnings are plain canvas in teal, burgundy, navy or forest green with one cream valance band:
# never orange, never diagonal stripes (orange/white striping is reserved for construction
# hazards). Triangle discipline as in kit_b2lib: faces the chase camera cannot see are not built.

import math

from kit_b2lib import (
    B2Builder,
    Offset as Back,
    SideWall as Side,
    Frame,
    V,
    arch_window,
    body,
    box,
    cornice,
    face_rec,
    fbox,
    fdir,
    fp,
    fquad,
    parapet,
    pier,
    plate,
    sock,
    strip_band,
    wall_with_holes,
    window,
)
import kitlib
from kitlib import cyl, prism, sphere

STOREY = 12.0
WIN = {"reveal": "reveal", "glass": "glass", "glass_light": "glass_light", "sill": "trim_1", "lintel": "trim_1", "mullion": "frame"}

COLOURWAYS = {
    "a": {"wall": "wall_1", "stone": "stone_1", "aw": "aw_1", "aw2": "aw_2", "door": "door_1", "shop": "trim_2", "acc": "acc_1", "base": "stone_1"},
    "b": {"wall": "wall_2", "stone": "stone_2", "aw": "aw_2", "aw2": "aw_3", "door": "door_2", "shop": "stone_1", "acc": "acc_2", "base": "stone_2"},
    "c": {"wall": "wall_3", "stone": "stone_1", "aw": "aw_3", "aw2": "aw_1", "door": "door_1", "shop": "trim_2", "acc": "acc_1", "base": "stone_1"},
    # d: a painted shop base (the B "painted teal / mustard" colourways), stone trim
    "d": {"wall": "wall_1", "stone": "stone_2", "aw": "aw_1", "aw2": "aw_2", "door": "door_2", "shop": "trim_1", "acc": "acc_2", "base": "wall_4"},
}


def new(name, cw):
    return B2Builder(name, dict(COLOURWAYS[cw]))


def finish(b, W, mirror=False):
    fr = Frame(W / 2, mirror)
    fr.apply(b)
    return fr


def base_sockets(fr, W, D, roof_y, extra=None):
    s = {
        "front_left": sock((-W / 2, 0, 0), frame=fr),
        "front_right": sock((W / 2, 0, 0), frame=fr),
        "back_left": sock((-W / 2, 0, D), frame=fr),
        "roof_a": sock((-W * 0.22, roof_y, D * 0.62), frame=fr),
        "roof_b": sock((W * 0.24, roof_y, D * 0.5), frame=fr),
    }
    # front_left / front_right are named in the lot's own frame: front_left is the pivot
    s["front_left"], s["front_right"] = sock((0, 0, 0)), sock((W, 0, 0))
    s["back_left"] = sock((0, 0, D))
    if extra:
        s.update(extra)
    return s


def lot_meta(module, W, D, H, storeys, cls, district, fr, roof_y, sockets_extra=None, faces=None, orientation="front", **kw):
    m = {
        "family": "LM" if module == "landmark" else "Lot",
        "module": module,
        "width": W,
        "depth": D,
        "height": round(H, 2),
        "storeys": storeys,
        "height_class": cls,
        "orientation": orientation,
        "facing": "-Z",
        "district": district,
        "lod": "near",
        "pivot": "front corner on the lot's own left (min x), ground level, on the frontage line; facade faces -Z",
        "sockets": base_sockets(fr, W, D, roof_y, sockets_extra),
        "roof_y": round(roof_y, 2),
    }
    if faces:
        m["faces"] = faces
    m.update(kw)
    return m


# ---------------------------------------------------------------- shared pieces
def awning(b, u0, u1, v_top, drop, proj, sw="aw"):
    """A plain canvas awning: sloped top, underside, a valance with one cream band and two
    small side cheeks. No stripes."""
    v_out = v_top - drop
    top = [fp(u0, v_top, 0.05), fp(u1, v_top, 0.05), fp(u1, v_out, proj), fp(u0, v_out, proj)]
    b.face(top, sw, V(0, 1, 0) + fp(0, 0, 1))
    b.face([p + V(0, -0.12, 0) for p in top], "aw_under", V(0, -1, 0))
    val = 1.1
    fquad(b, u0, u1, v_out - val, v_out, proj, sw)
    fquad(b, u0, u1, v_out - val * 0.78, v_out - val * 0.52, proj + 0.03, "aw_edge")
    b.face([fp(u0, v_out, proj - 0.06), fp(u1, v_out, proj - 0.06), fp(u1, v_out - val, proj - 0.06), fp(u0, v_out - val, proj - 0.06)], "aw_under", V(0, 0, 1))
    for u in (u0, u1):
        b.face2([fp(u, v_top, 0.05), fp(u, v_out, proj), fp(u, v_out - val, proj)], sw)


def shop_window(b, u0, u1, v0=1.5, v1=9.6, k=0, frame_sw="shop"):
    """A recessed shop window with a thin frame and a flat display silhouette (shelf + three
    goods) standing in front of the glass."""
    rec = 1.3
    window(b, u0, u1, v0, v1, rec, WIN, bottom=True, sill=False, lintel=False, split=0.62)
    fquad(b, u0 - 0.35, u0, v0 - 0.35, v1, 0.12, frame_sw)
    fquad(b, u1, u1 + 0.35, v0 - 0.35, v1, 0.12, frame_sw)
    fquad(b, u0 - 0.35, u1 + 0.35, v1, v1 + 0.35, 0.12, frame_sw)
    fquad(b, u0, u1, v0 - 0.35, v0, 0.12, frame_sw)
    d = -rec + 0.3
    fquad(b, u0 + 0.2, u1 - 0.2, v0, v0 + 0.5, d, "shelf")
    w = u1 - u0
    goods = [(0.12, 0.34, 1.6, "display_1"), (0.40, 0.62, 2.4, "display_2"), (0.68, 0.88, 1.2, "display_3")]
    for a, c, h, sw in goods[k % 3 :] + goods[: k % 3]:
        fquad(b, u0 + w * a, u0 + w * c, v0 + 0.5, v0 + 0.5 + h, d + 0.05, sw)


def shop_door(b, u0, u1, h=8.6, wall_sw="base"):
    """A recessed door (2.0 deep): reveals, the door leaf with a glass panel, an architrave and a
    step."""
    window(b, u0, u1, 0.0, h, 2.0, {"reveal": "reveal", "glass": "door"}, sill=False, lintel=False, split=0)
    fquad(b, u0 + 0.45, u1 - 0.45, 4.0, h - 1.0, -1.94, "glass_light")
    fquad(b, u0 - 0.5, u0, 0, h + 0.5, 0.15, "trim_1")
    fquad(b, u1, u1 + 0.5, 0, h + 0.5, 0.15, "trim_1")
    fquad(b, u0 - 0.5, u1 + 0.5, h, h + 0.5, 0.15, "trim_1")
    strip_band(b, u0 - 0.5, u1 + 0.5, 0, 0.3, 0.8, "stone", bottom=False)


SHOP_LAYOUT = {
    # (kind, u0, u1) as seen from the street; one shop per 24 studs
    24: [("win", -10.4, -2.6), ("door", -1.8, 1.8), ("win", 2.6, 10.4)],
    36: [("win", -16.4, -8.2), ("door", -7.2, -3.6), ("win", -2.6, 7.6), ("door", 8.6, 12.2)],
    48: [("win", -22.4, -14.6), ("door", -13.8, -10.2), ("win", -9.4, -1.6), ("win", 1.6, 9.4), ("door", 10.2, 13.8), ("win", 14.6, 22.4)],
}
SHOP_UNITS = {24: [(-10.8, 10.8)], 36: [(-16.8, 12.6)], 48: [(-22.8, -1.2), (1.2, 22.8)]}


def shop_ground(b, W, GF=16.0, awnings=True):
    """Ground floor (16): stone or painted base, shop windows and doors, plinth, end pilasters,
    plain awnings per shop unit, a sign band frame and a top band. Returns the fascia mounts."""
    hw = W / 2
    lay = SHOP_LAYOUT[W]
    holes = [(u0, u1, 1.5, 9.6) if k == "win" else (u0, u1, 0.0, 8.6) for k, u0, u1 in lay]
    wall_with_holes(b, -hw, hw, 0, GF, holes, "base")
    wi = 0
    for k, u0, u1 in lay:
        if k == "win":
            shop_window(b, u0, u1, k=wi)
            wi += 1
        else:
            shop_door(b, u0, u1)
    strip_band(b, -hw, hw, 0, 0.9, 0.18, "stone", bottom=False)
    for u in (-hw, hw - 1.0):
        pier(b, u, u + 1.0, 0, GF - 0.7, 0.4, "stone")
    if W == 48:
        pier(b, -0.6, 0.6, 0, GF - 0.7, 0.4, "stone")
    mounts = []
    for i, (a, c) in enumerate(SHOP_UNITS[W]):
        if awnings:
            awning(b, a, c, 11.0, 2.0, 3.8, "aw" if i == 0 else "aw2")
        strip_band(b, a, c, 11.4, 11.7, 0.3, "trim_1", top=True, bottom=False)
        mounts.append(((a + c) / 2, c - a))
    strip_band(b, -hw, hw, GF - 0.7, GF, 0.55, "trim_1")
    return mounts


def uppers_pairs(b, W, v0, n_up, arched_top=False, wall="wall"):
    """Upper storeys of 12: two recessed windows per 12-stud bay (B's rhythm), stone sills and
    lintels, a thin brick course at each floor line. arched_top: the top storey's windows are
    arched (a roofline/window variant)."""
    hw = W / 2
    bays = int(round(W / 12))
    cols = []
    for i in range(bays):
        bc = -hw + 12 * i + 6
        cols += [bc - 3.0, bc + 3.0]
    holes = []
    for f in range(n_up):
        for c in cols:
            holes.append((c - 1.6, c + 1.6, v0 + f * STOREY + 2.4, v0 + f * STOREY + 9.0))
    wall_with_holes(b, -hw, hw, v0, v0 + n_up * STOREY, holes, wall)
    for (a, c, h0, h1) in holes:
        top_floor = h0 > v0 + (n_up - 1) * STOREY
        if arched_top and top_floor:
            # the arch is cut inside the rectangular hole: kitlib's opening fills the corners
            arch_window(b, a, c, h0, h1, 1.1, wall, WIN, seg=3)
        else:
            window(b, a, c, h0, h1, 1.1, WIN, mullion=True)
    for f in range(1, n_up):
        fquad(b, -hw, hw, v0 + f * STOREY - 0.25, v0 + f * STOREY, 0.08, "course")


def top_cap(b, W, v, D, kind="cornice"):
    """The cap over the last storey. cornice: frieze, stepped cornice, brick parapet with stone
    coping. stepped: the same with a raised centre panel. pediment: a shallow centre gable.
    flat: a simple coping (Midtown). Returns (roof_y, top_y)."""
    hw = W / 2
    if kind == "flat":
        strip_band(b, -hw, hw, v, v + 1.2, 0.35, "stone", bottom=True)
        roof_y = v + 0.6
        b.face([V(-hw, roof_y, 0.4), V(hw, roof_y, 0.4), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
        return roof_y, v + 1.2
    strip_band(b, -hw, hw, v, v + 1.0, 0.3, "stone", top=False)
    cornice(b, -hw - 0.3, hw + 0.3, v + 1.0, 1.8, "trim_1", 1.8)
    parapet(b, W, v + 2.8, v + 4.2, D, "wall", "trim_1")
    top_y = v + 4.5
    if kind == "stepped":
        for i, (pw, ph) in enumerate(((W * 0.42, 1.6), (W * 0.22, 1.2))):
            y0 = v + 4.5 + (1.6 if i else 0.0)
            box(b, V(0, y0 + ph / 2, 0.4), (pw, ph, 0.8), {"side": "wall", "top": "trim_1", "skip_bottom": True})
        top_y = v + 7.3
    elif kind == "pediment":
        pw, ph = W * 0.36, 3.2
        plate(b, [(-pw / 2, v + 4.5), (pw / 2, v + 4.5), (0, v + 4.5 + ph)], -0.8, 0.1, "wall", "trim_1")
        top_y = v + 4.5 + ph
    roof_y = v + 2.4
    b.face([V(-hw, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
    return roof_y, top_y


def quoin_strips(b, W, v0, v1):
    """Cheap quoins: a stone strip on each front corner (alternating blocks are only on corner
    lots, where the corner is the read)."""
    hw = W / 2
    pier(b, -hw, -hw + 1.4, v0, v1, 0.2, "stone")
    pier(b, hw - 1.4, hw, v0, v1, 0.2, "stone")


# ---------------------------------------------------------------- Main Street shops
def shop_lot(name, W, n, cw, top="cornice", arched=False, quoins=True, district="MS", D=20.0):
    b = new(name, cw)
    GF = 16.0
    mounts = shop_ground(b, W, GF)
    n_up = n - 1
    uppers_pairs(b, W, GF, n_up, arched_top=arched)
    v = GF + n_up * STOREY
    if quoins:
        quoin_strips(b, W, GF, v)
    roof_y, top_y = top_cap(b, W, v, D, top)
    body(b, W, 0, v + 2.8, D)
    fr = finish(b, W)
    extra = {}
    for i, (u, w) in enumerate(mounts):
        extra[f"fascia_{i + 1}"] = sock((-u, 11.8, -0.3), frame=fr, max_width=round(w - 1.0, 2))
        extra[f"blade_{i + 1}"] = sock((-(u + w / 2 - 0.6), GF + 0.6, 0.0), frame=fr)
    if n >= 3 and W in (24, 36):
        extra["fire_escape"] = sock((-(W / 2 - 1.0), GF, 0.0), 0.0, frame=fr, note=f"B2_Prop_FireEscape{n - 1}: spans x +10 from this socket over the first bay, projects 3 toward the street")
    cls = "low" if n == 2 else "mid"
    return b, lot_meta("shop", W, D, top_y, n, cls, district, fr, roof_y, extra, colourway=cw, top=top, arched_top=arched)


def corner_lot(name, W, n, cw, mirror=False, district="MS", D=24.0):
    """corner-R (mirror=False): a shop lot whose right-hand side (local +X) is a dressed street
    facade with a side door and windows and alternating stone quoins on the corner. corner-L is
    the mirrored mesh (never a rotation)."""
    b = new(name, cw)
    GF = 16.0
    hw = W / 2
    mounts = shop_ground(b, W, GF)
    n_up = n - 1
    uppers_pairs(b, W, GF, n_up)
    v = GF + n_up * STOREY
    pier(b, hw - 1.4, hw, GF, v, 0.2, "stone")
    roof_y, top_y = top_cap(b, W, v, D, "cornice")
    # side facade at x = +hw (facing +X), drawn through a rotated proxy of the builder
    side = Side(b, hw, D)
    holes = [(-D / 2 + 3.0, -D / 2 + 9.0, 1.5, 9.6), (D / 2 - 7.0, D / 2 - 3.4, 0.0, 8.6)]
    for f in range(n_up):
        for c in (-D / 2 + 6.0, 0.0, D / 2 - 6.0):
            holes.append((c - 1.6, c + 1.6, GF + f * STOREY + 2.4, GF + f * STOREY + 9.0))
    wall_with_holes(side, -D / 2, D / 2, 0, GF, [h for h in holes if h[3] <= GF], "base")
    wall_with_holes(side, -D / 2, D / 2, GF, v, [h for h in holes if h[2] >= GF], "wall")
    shop_window(side, *holes[0][:2], k=1)
    shop_door(side, *holes[1][:2])
    for (a, c, h0, h1) in holes[2:]:
        window(side, a, c, h0, h1, 1.1, WIN, mullion=True)
    strip_band(side, -D / 2, D / 2, 0, 0.9, 0.18, "stone", bottom=False)
    strip_band(side, -D / 2, D / 2, GF - 0.7, GF, 0.55, "trim_1")
    strip_band(side, -D / 2, D / 2, v, v + 1.0, 0.3, "stone", top=False)
    cornice(side, -D / 2 - 0.3, D / 2 + 0.3, v + 1.0, 1.8, "trim_1", 1.8)
    box(b, V(hw - 0.4, v + 3.5, D / 2), (0.8, 1.4, D), {"side": "wall", "top": "trim_1", "skip_bottom": True})
    # alternating quoin blocks on the corner (front face and side face)
    y, k = GF, 0
    while y + 1.3 <= v + 1e-6:
        w = 1.8 if k % 2 == 0 else 1.1
        fbox(b, -hw, -hw + w, y, y + 1.3, 0, 0.22, "stone", skip=("back", "right", "bottom"))
        fbox(side, D / 2 - w, D / 2, y, y + 1.3, 0, 0.22, "stone", skip=("back", "left", "bottom"))
        y += 1.5
        k += 1
    # left side and back walls (the right side is the dressed facade)
    b.face([V(-hw, 0, 0), V(-hw, 0, D), V(-hw, v + 2.8, D), V(-hw, v + 2.8, 0)], "wall", V(-1, 0, 0))
    b.face([V(-hw, 0, D), V(hw, 0, D), V(hw, v + 2.8, D), V(-hw, v + 2.8, D)], "wall", V(0, 0, 1))
    fr = finish(b, W, mirror)
    extra = {}
    for i, (u, w) in enumerate(mounts):
        extra[f"fascia_{i + 1}"] = sock((-u, 11.8, -0.3), frame=fr, max_width=round(w - 1.0, 2))
    extra["side_fascia"] = sock((hw + 0.3, 11.8, D / 2), -90.0, frame=fr)
    extra["corner_sign"] = sock((hw + 0.2, GF + 1.0, 0.6), -45.0, frame=fr, note="small corner blade at 45 degrees")
    orient = "corner-L" if mirror else "corner-R"
    return b, lot_meta("corner", W, D, top_y, n, "mid" if n >= 3 else "low", district, fr, roof_y, extra, orientation=orient, colourway=cw)


# ---------------------------------------------------------------- City Hall district: civic
def civic_lot(name, W, n, cw, district="CH", D=22.0):
    """Broader civic facade in stone: a rusticated 18-stud ground floor with one wide arched
    window per bay, giant pilasters through the upper storeys, one tall window per bay with a
    hood, a deep cornice and a panelled balustrade parapet."""
    b = new(name, cw)
    b.remap.update({"base": "stone_2", "stone": "trim_1"})
    hw = W / 2
    GF = 18.0
    bays = int(round(W / 12))
    holes = []
    for i in range(bays):
        c = -hw + 12 * i + 6
        if i == bays // 2:
            holes.append((c - 2.4, c + 2.4, 0.0, 11.0))
        else:
            holes.append((c - 3.0, c + 3.0, 2.0, 13.0))
    wall_with_holes(b, -hw, hw, 0, GF, holes, "base")
    for (a, c, h0, h1) in holes:
        if h0 == 0.0:
            kitlib.opening(b, a, c, h0, h1, "arch", 2.0, "base", "reveal", "door", arc_seg=4)
            fquad(b, a + 0.5, c - 0.5, 4.0, 8.0, -1.94, "glass_light")
            strip_band(b, a - 1.0, c + 1.0, 0, 0.6, 1.6, "stone", bottom=False)
        else:
            arch_window(b, a, c, h0, h1, 1.3, "base", WIN, seg=4)
    for k in range(1, 4):
        fquad(b, -hw, hw, GF * k / 4 - 0.18, GF * k / 4, 0.1, "civic_shadow")
    strip_band(b, -hw, hw, GF - 1.0, GF, 0.6, "trim_1")
    n_up = n - 1
    v = GF + n_up * 14.0
    holes = []
    for f in range(n_up):
        for i in range(bays):
            c = -hw + 12 * i + 6
            holes.append((c - 1.9, c + 1.9, GF + f * 14.0 + 2.6, GF + f * 14.0 + 11.0))
    wall_with_holes(b, -hw, hw, GF, v, holes, "wall")
    for (a, c, h0, h1) in holes:
        window(b, a, c, h0, h1, 1.2, WIN, mullion=True, lintel=False)
        fbox(b, a - 0.7, c + 0.7, h1 + 0.2, h1 + 0.9, 0, 0.6, "trim_1", skip=("back",))
    for i in range(bays + 1):
        u = -hw + 12 * i
        pier(b, max(-hw, u - 0.8), min(hw, u + 0.8), GF, v, 0.45, "trim_1")
    strip_band(b, -hw, hw, v, v + 1.4, 0.45, "trim_1", top=False)
    cornice(b, -hw - 0.4, hw + 0.4, v + 1.4, 2.4, "trim_1", 2.2)
    parapet(b, W, v + 3.6, v + 6.0, D, "wall", "trim_1")
    for i in range(bays):
        c = -hw + 12 * i + 6
        fquad(b, c - 3.6, c + 3.6, v + 4.0, v + 5.6, -0.01, "civic_shadow")
    roof_y = v + 3.0
    b.face([V(-hw, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
    body(b, W, 0, v + 3.6, D)
    fr = finish(b, W)
    extra = {"flag": sock((0.0, v + 6.3, 0.4), frame=fr, note="flagpole mount on the parapet centre")}
    return b, lot_meta("civic", W, D, v + 6.3, n, "mid", district, fr, roof_y, extra, colourway=cw)


# ---------------------------------------------------------------- Harbor: warehouses
def warehouse_lot(name, W, n, cw, district="HB", D=24.0):
    """A brick harbour warehouse: tall segmental-arched loading doors, a pedestrian door, a row of
    arched windows per storey, brick piers, and a stepped gable parapet with a painted name band
    (text face). Two tall storeys (18 + 14) or more."""
    b = new(name, cw)
    b.remap.update({"wall": COLOURWAYS[cw]["wall"], "base": COLOURWAYS[cw]["wall"]})
    hw = W / 2
    GF = 18.0
    if W >= 48:
        doors = [(-19.0, -9.0), (9.0, 19.0)]
        ped = (-2.0, 2.0)
    else:
        doors = [(-14.0, -4.0)]
        ped = (6.0, 9.6)
    holes = [(a, c, 0.0, 13.0) for a, c in doors] + [(ped[0], ped[1], 0.0, 8.6)]
    wall_with_holes(b, -hw, hw, 0, GF, holes, "base")
    for a, c in doors:
        kitlib.opening(b, a, c, 0.0, 13.0, "arch", 1.4, "base", "reveal", "door", arc_seg=4)
        for k in range(1, 4):
            fquad(b, a + 0.2, c - 0.2, 13.0 * k / 5 - 0.15, 13.0 * k / 5 + 0.15, -1.3, "door_1")
        fquad(b, a - 0.6, c + 0.6, 13.0 + 0.0, 13.8, 0.3, "stone")
    shop_door(b, ped[0], ped[1])
    strip_band(b, -hw, hw, 0, 1.2, 0.25, "stone", bottom=False)
    n_up = n - 1
    v = GF + n_up * 14.0
    holes = []
    nc = int((W - 4) // 8)
    cols = [-(nc - 1) * 4.0 + 8.0 * i for i in range(nc)]
    for f in range(n_up):
        for c in cols:
            holes.append((c - 2.0, c + 2.0, GF + f * 14.0 + 3.0, GF + f * 14.0 + 10.4))
    wall_with_holes(b, -hw, hw, GF, v, holes, "wall")
    for (a, c, h0, h1) in holes:
        arch_window(b, a, c, h0, h1, 1.0, "wall", WIN, seg=3)
    strip_band(b, -hw, hw, GF - 0.6, GF, 0.3, "stone")
    for u in (-hw, hw - 1.2):
        pier(b, u, u + 1.2, 0, v, 0.4, "wall")
    # stepped gable parapet with a painted name band
    strip_band(b, -hw, hw, v, v + 0.8, 0.35, "stone", top=False)
    steps = [(W, 3.0), (W * 0.62, 2.4), (W * 0.3, 2.0)]
    y = v + 0.8
    for i, (pw, ph) in enumerate(steps):
        box(b, V(0, y + ph / 2, 0.4), (pw, ph, 0.8), {"side": "wall", "top": "stone", "skip_bottom": True})
        y += ph
    band_w = W * 0.56
    fquad(b, -band_w / 2, band_w / 2, v + 1.2, v + 3.4, -0.02, "stone")
    roof_y = v + 1.6
    b.face([V(-hw, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
    body(b, W, 0, v + 3.8, D)
    fr = finish(b, W)
    faces = [face_rec("name_band", fp(0, v + 2.3, 0.04), band_w - 1.0, 2.0, frame=fr)]
    return b, lot_meta("warehouse", W, D, y, n, "low" if n == 2 else "mid", district, fr, roof_y, {}, faces=faces, colourway=cw, default_text="HARBOR SUPPLY CO.")


# ---------------------------------------------------------------- Midtown: structural grids
def grid_face(b, u0, u1, v0, v1, cols, rows, pier_sw, spandrel_sw, glass_sw, depth=1.0, pier_w=1.0):
    """A repeated structural grid: one recessed glass plane, a spandrel strip at each floor line
    and piers on every column line (front and sides). Cheap, and reads as a grid at any speed."""
    fquad(b, u0, u1, v0, v1, -depth, glass_sw)
    for r in range(rows + 1):
        y = v0 + (v1 - v0) * r / rows
        y0, y1 = max(v0, y - 0.7), min(v1, y + 0.7)
        fquad(b, u0, u1, y0, y1, -0.3, spandrel_sw)
        b.face([fp(u0, y0, -depth), fp(u1, y0, -depth), fp(u1, y0, -0.3), fp(u0, y0, -0.3)], spandrel_sw, V(0, -1, 0))
    for c in range(cols + 1):
        u = u0 + (u1 - u0) * c / cols
        a, e = max(u0, u - pier_w / 2), min(u1, u + pier_w / 2)
        fquad(b, a, e, v0, v1, 0.2, pier_sw)
        if c > 0:
            b.face([fp(a, v0, -depth), fp(a, v1, -depth), fp(a, v1, 0.2), fp(a, v0, 0.2)], pier_sw, fdir(-1))
        if c < cols:
            b.face([fp(e, v0, -depth), fp(e, v1, -depth), fp(e, v1, 0.2), fp(e, v0, 0.2)], pier_sw, fdir(1))


def tall_lot(name, W, n, cw, style="grid", district="MT", D=24.0):
    """Midtown tall lot (5-7 storeys): an 18-stud stone lobby with a glazed storefront and a
    canopy, then a structural grid (style grid: stone piers; brick: brick piers and dark
    spandrels; glass: a curtain wall with thin mullions over a two-storey stone podium), and a
    set-back top storey for a varied roofline."""
    b = new(name, cw)
    hw = W / 2
    GF = 18.0
    # lobby: stone piers every 6, glazing between, an entrance canopy
    grid_face(b, -hw, hw, 0.8, GF - 1.4, int(W // 6), 1, "stone", "stone", "glass", depth=0.9, pier_w=1.2)
    strip_band(b, -hw, hw, 0, 0.8, 0.3, "stone", bottom=False)
    strip_band(b, -hw, hw, GF - 1.4, GF, 0.5, "trim_1")
    fbox(b, -4.5, 4.5, 11.0, 11.8, 0, 4.0, "trim_2", skip=("back",))
    n_up = n - 1
    v = GF + n_up * STOREY
    setback = 4.0
    if style == "glass":
        podium = GF + STOREY
        wall_with_holes(b, -hw, hw, GF, podium, [(-hw + 3 + 6 * i, -hw + 6 + 6 * i, GF + 2.4, GF + 9.0) for i in range(int((W - 3) // 6))], "stone")
        for i in range(int((W - 3) // 6)):
            window(b, -hw + 3 + 6 * i, -hw + 6 + 6 * i, GF + 2.4, GF + 9.0, 0.8, WIN, lintel=False)
        strip_band(b, -hw, hw, podium - 0.6, podium, 0.4, "trim_1")
        grid_face(b, -hw + 1.2, hw - 1.2, podium, v - STOREY, int(W // 4), n_up - 2, "frame", "glass_dark", "glass_light", depth=0.4, pier_w=0.3)
        pier(b, -hw, -hw + 1.2, podium, v - STOREY, 0.5, "stone")
        pier(b, hw - 1.2, hw, podium, v - STOREY, 0.5, "stone")
    else:
        pier_sw = "stone" if style == "grid" else "wall"
        span_sw = "stone" if style == "grid" else "course"
        grid_face(b, -hw, hw, GF, v - STOREY, int(W // 6), n_up - 1, pier_sw, span_sw, "glass", depth=1.0, pier_w=1.2)
    # the set-back top storey (a varied roofline: its own coping)
    v1 = v - STOREY
    strip_band(b, -hw, hw, v1, v1 + 0.8, 0.5, "trim_1")
    b.face([V(-hw, v1 + 0.8, 0), V(hw, v1 + 0.8, 0), V(hw, v1 + 0.8, setback), V(-hw, v1 + 0.8, setback)], "roof", V(0, 1, 0))
    tb = Back(b, setback)
    grid_face(tb, -hw + 2, hw - 2, v1 + 0.8, v, int((W - 4) // 6), 1, "stone" if style != "brick" else "wall", "trim_1", "glass", depth=0.6, pier_w=1.0)
    for x in (-hw + 2, hw - 2):
        b.face([V(x, v1 + 0.8, setback), V(x, v1 + 0.8, D), V(x, v, D), V(x, v, setback)], "stone" if style != "brick" else "wall", V(1 if x > 0 else -1, 0, 0))
    strip_band(tb, -hw + 2, hw - 2, v, v + 1.0, 0.4, "trim_1")
    roof_y = v + 0.6
    b.face([V(-hw + 2, roof_y, setback), V(hw - 2, roof_y, setback), V(hw - 2, roof_y, D), V(-hw + 2, roof_y, D)], "roof", V(0, 1, 0))
    body(b, W, 0, v1 + 0.8, D, side="stone" if style != "brick" else "wall", back="stone" if style != "brick" else "wall")
    b.face([V(-hw + 2, v1 + 0.8, D), V(hw - 2, v1 + 0.8, D), V(hw - 2, v, D), V(-hw + 2, v, D)], "stone" if style != "brick" else "wall", V(0, 0, 1))
    fr = finish(b, W)
    extra = {"roof_tank": sock((W * 0.2, roof_y, D * 0.62), frame=fr), "roof_vent": sock((-W * 0.25, roof_y, D * 0.5), frame=fr)}
    extra["fascia_1"] = sock((0.0, 12.2, -4.0), frame=fr, max_width=8.0, note="on the canopy front")
    return b, lot_meta("tall", W, D, v + 1.0, n, "tall", district, fr, roof_y, extra, style=style, colourway=cw, setback_top=setback)


# ---------------------------------------------------------------- Skyline Park: townhouses
def townhouse_lot(name, W, n, cw, district="SP", D=24.0):
    """A set-back townhouse: an 8-stud front garden (lawn, low hedge with a gate gap, a path to a
    stoop) baked into the lot, the house facade at z 8, a two-storey bay window, sash windows and
    a cornice. The lot's pivot is still at the garden's front line (the frontage line)."""
    b = new(name, cw)
    hw = W / 2
    SB = 8.0
    GF = 14.0
    # garden
    b.face([V(-hw, 0.6, 0), V(hw, 0.6, 0), V(hw, 0.6, SB), V(-hw, 0.6, SB)], "grass", V(0, 1, 0))
    b.face([V(-hw, 0.0, 0), V(hw, 0.0, 0), V(hw, 0.6, 0), V(-hw, 0.6, 0)], "stone", V(0, 0, -1))
    b.face([V(2.0, 0.62, 0), V(5.6, 0.62, 0), V(5.6, 0.62, SB), V(2.0, 0.62, SB)], "path_gravel", V(0, 1, 0))
    for x0, x1 in ((-hw + 0.4, 1.6), (6.0, hw - 0.4)):
        box(b, V((x0 + x1) / 2, 1.8, 0.9), (x1 - x0, 2.4, 1.4), {"side": "hedge_dark", "top": "hedge_light", "skip_bottom": True})
    for x in (1.6, 6.0):
        box(b, V(x, 1.9, 0.9), (0.9, 2.6, 0.9), {"side": "stone", "top": "trim_1", "skip_bottom": True})
    # house facade, drawn pushed back by SB
    h = Back(b, SB)
    n_up = n - 1
    holes = [(-hw + 3.0, -hw + 7.0, 2.0, 9.6), (2.4, 5.2, 1.0, 9.0)]
    wall_with_holes(h, -hw, hw, 0.6, GF, holes, "wall")
    window(h, -hw + 3.0, -hw + 7.0, 2.0, 9.6, 1.0, WIN, mullion=True)
    window(h, 2.4, 5.2, 1.0, 9.0, 1.4, {"reveal": "reveal", "glass": "door"}, sill=False, lintel=False, split=0)
    fbox(h, 1.6, 6.0, 0.6, 1.4, 0, 2.2, "stone", skip=("back", "bottom"))
    fbox(h, 1.9, 5.7, 9.4, 9.9, 0, 1.6, "trim_1", skip=("back",))
    v = GF + n_up * STOREY
    holes = []
    for f in range(n_up):
        for c in (3.8, hw - 3.6):
            holes.append((c - 1.5, c + 1.5, GF + f * STOREY + 2.2, GF + f * STOREY + 9.2))
    wall_with_holes(h, -hw, hw, GF, v, holes, "wall")
    for (a, c, h0, h1) in holes:
        window(h, a, c, h0, h1, 1.0, WIN, mullion=True)
    # two-storey bay window on the left bay (a three-sided oriel from v 1.2 to GF + 12)
    bu0, bu1, bd = -hw + 2.0, -hw + 8.0, 2.2
    y0, y1 = GF + 0.8, GF + STOREY - 0.6
    pts = [(bu0, 0), (bu0 + 1.2, bd), (bu1 - 1.2, bd), (bu1, 0)]
    for i in range(3):
        (ua, da), (uc, dc) = pts[i], pts[i + 1]
        h.face([fp(ua, y0, da), fp(uc, y0, dc), fp(uc, y1, dc), fp(ua, y1, da)], "wall", fdir((ua + uc) / 2 - (bu0 + bu1) / 2, 0, (da + dc) / 2 + 1))
        h.face([fp(ua + (uc - ua) * 0.15, y0 + 2.0, da + (dc - da) * 0.15 + 0.02), fp(uc - (uc - ua) * 0.15, y0 + 2.0, dc - (dc - da) * 0.15 + 0.02), fp(uc - (uc - ua) * 0.15, y1 - 1.6, dc - (dc - da) * 0.15 + 0.02), fp(ua + (uc - ua) * 0.15, y1 - 1.6, da + (dc - da) * 0.15 + 0.02)], "glass_light", fdir((ua + uc) / 2 - (bu0 + bu1) / 2, 0, (da + dc) / 2 + 1))
    h.face([fp(u, y1, d) for u, d in pts], "trim_1", V(0, 1, 0))
    h.face([fp(u, y0, d) for u, d in pts], "trim_1", V(0, -1, 0))
    strip_band(h, -hw, hw, GF - 0.4, GF, 0.2, "course")
    strip_band(h, -hw, hw, v, v + 0.9, 0.3, "stone", top=False)
    cornice(h, -hw - 0.3, hw + 0.3, v + 0.9, 1.5, "trim_1", 1.5)
    box(b, V(0, v + 2.4 + 0.6, SB + 0.4), (W, 1.2, 0.8), {"side": "wall", "top": "trim_1", "skip_bottom": True})
    roof_y = v + 1.9
    b.face([V(-hw, roof_y, SB + 0.8), V(hw, roof_y, SB + 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
    b.face([V(-hw, 0, SB), V(-hw, 0, D), V(-hw, v + 2.4, D), V(-hw, v + 2.4, SB)], "wall", V(-1, 0, 0))
    b.face([V(hw, 0, SB), V(hw, 0, D), V(hw, v + 2.4, D), V(hw, v + 2.4, SB)], "wall", V(1, 0, 0))
    b.face([V(-hw, 0, D), V(hw, 0, D), V(hw, v + 2.4, D), V(-hw, v + 2.4, D)], "wall", V(0, 0, 1))
    fr = finish(b, W)
    extra = {"garden_tree": sock((-hw * 0.5, 0.6, SB * 0.5), frame=fr)}
    return b, lot_meta("townhouse", W, D, v + 3.6, n, "mid" if n >= 3 else "low", district, fr, roof_y, extra, setback_baked=SB, colourway=cw)


# ---------------------------------------------------------------- open lots (glue kit)
def open_lot(name, W, kind, district, D=24.0):
    """Courtyard / pocket park / plaza / park lots: they break a block's rhythm (research O8) and
    carry district identity. Furniture, trees and features attach at sockets."""
    b = B2Builder(name, {"wall": "wall_1"})
    hw = W / 2
    extra = {}
    if kind == "pocket":
        b.face([V(-hw, 0.6, 0), V(hw, 0.6, 0), V(hw, 0.6, D), V(-hw, 0.6, D)], "plaza", V(0, 1, 0))
        b.face([V(-hw, 0.0, 0), V(hw, 0.0, 0), V(hw, 0.6, 0), V(-hw, 0.6, 0)], "sidewalk_edge", V(0, 0, -1))
        for x0, x1 in ((-hw, -3.0), (3.0, hw)):
            box(b, V((x0 + x1) / 2, 1.9, 0.6), (x1 - x0, 2.6, 1.2), {"side": "wall", "top": "stone_1", "skip_bottom": True})
        for x in (-3.0, 3.0):
            box(b, V(x, 2.6, 0.6), (1.3, 4.0, 1.3), {"side": "stone_1", "top": "trim_1", "skip_bottom": True})
        box(b, V(0, 6.0, D - 0.5), (W, 12.0, 1.0), {"side": "wall", "top": "trim_1", "skip_bottom": True})
        for x in (-hw + 5.0, hw - 5.0):
            b.face([V(x - 2.0, 0.62, D * 0.55 - 2.0), V(x + 2.0, 0.62, D * 0.55 - 2.0), V(x + 2.0, 0.62, D * 0.55 + 2.0), V(x - 2.0, 0.62, D * 0.55 + 2.0)], "tree_grate", V(0, 1, 0))
        extra = {"tree_1": sock((-hw + 5.0, 0.6, D * 0.55)), "tree_2": sock((hw - 5.0, 0.6, D * 0.55)), "bench": sock((0, 0.6, D - 3.0), 180.0)}
        h = 12.0
    elif kind == "plaza":
        b.face([V(-hw, 0.6, 0), V(hw, 0.6, 0), V(hw, 0.6, D), V(-hw, 0.6, D)], "plaza", V(0, 1, 0))
        b.face([V(-hw, 0.0, 0), V(hw, 0.0, 0), V(hw, 0.6, 0), V(-hw, 0.6, 0)], "sidewalk_edge", V(0, 0, -1))
        # a raised octagonal planter bed with a lawn and a low stone rim, and paving bands
        prism(b, kitlib.circle2(0, D * 0.55, 7.0, 8, math.pi / 8), 0.6, 1.8, "civic_stone", "grass")
        for z in (3.0, D - 3.0):
            b.face([V(-hw, 0.63, z - 0.6), V(hw, 0.63, z - 0.6), V(hw, 0.63, z + 0.6), V(-hw, 0.63, z + 0.6)], "civic_shadow", V(0, 1, 0))
        for x in (-hw + 4.0, hw - 4.0):
            cyl(b, V(x, 0.6, 3.0), 0.8, 0.9, 6, "civic_stone")
            cyl(b, V(x, 1.4, 3.0), 26.0, 0.18, 6, "furn_metal")
            b.face2([V(x, 26.0, 3.0), V(x, 21.5, 3.0), V(x + (6.5 if x < 0 else -6.5), 23.75, 3.0)], "flag_1")
        extra = {"tree_1": sock((-hw + 9.0, 0.6, D - 5.0)), "tree_2": sock((hw - 9.0, 0.6, D - 5.0)), "lamp_1": sock((-hw + 1.5, 0.6, 1.5)), "lamp_2": sock((hw - 1.5, 0.6, 1.5)), "feature": sock((0, 1.8, D * 0.55), note="clock tower or statue base")}
        h = 26.4
    elif kind == "park":
        b.face([V(-hw, 0.55, 0), V(hw, 0.55, 0), V(hw, 0.55, D), V(-hw, 0.55, D)], "grass", V(0, 1, 0))
        b.face([V(-hw, 0.0, 0), V(hw, 0.0, 0), V(hw, 0.55, 0), V(-hw, 0.55, 0)], "sidewalk_edge", V(0, 0, -1))
        b.face([V(-3.0, 0.58, 0), V(3.0, 0.58, 0), V(3.0, 0.58, D * 0.55 - 7.5), V(-3.0, 0.58, D * 0.55 - 7.5)], "path_gravel", V(0, 1, 0))
        b.face([V(x, 0.58, z) for x, z in kitlib.circle2(0, D * 0.55, 9.0, 12)], "path_gravel", V(0, 1, 0))
        for x0, x1 in ((-hw + 0.5, -3.6), (3.6, hw - 0.5)):
            box(b, V((x0 + x1) / 2, 1.8, 1.2), (x1 - x0, 2.6, 1.8), {"side": "hedge_dark", "top": "hedge_light", "skip_bottom": True})
        for x in (-hw + 6.0, hw - 6.0):
            prism(b, kitlib.circle2(x, D - 6.0, 3.0, 6), 0.55, 1.2, "fountain_dark", "soil")
            for k in range(5):
                a = 2 * math.pi * k / 5
                sphere(b, V(x + math.cos(a) * 1.6, 1.6, D - 6.0 + math.sin(a) * 1.6), (0.6, 0.5, 0.6), ["flower_1", "flower_2", "flower_3"], subdiv=0)
        extra = {"feature": sock((0, 0.58, D * 0.55), note="B2_LM_Fountain, or a tree group"), "tree_1": sock((-hw + 5.0, 0.55, 8.0)), "tree_2": sock((hw - 5.0, 0.55, 8.0)), "bench_1": sock((-6.0, 0.58, D * 0.55 - 9.5)), "bench_2": sock((6.0, 0.58, D * 0.55 - 9.5))}
        h = 3.1
    else:
        raise ValueError(kind)
    fr = finish(b, W)
    sk = {k: sock((v["x"] + W / 2, v["y"], v["z"]), v["yaw"], **{kk: vv for kk, vv in v.items() if kk not in ("x", "y", "z", "yaw")}) for k, v in extra.items()}
    return b, lot_meta(kind, W, D, h, 0, "open", district, fr, 0.6, sk)


# ---------------------------------------------------------------- roof props
def fire_escape(name, levels):
    """A trimmed fire escape (before: B_FireEscape2 480 / B_FireEscape3 720 triangles): per level
    a platform, a railing as a front rail and three bar quads, one slanted stair plank with
    stringers; a raised drop ladder. Pivot: on the wall plane at the left end of the first
    platform, floor height of the first upper storey; it spans x 0..10 and projects to z -3."""
    b = B2Builder(name)
    W, dep = 10.0, 3.0
    for k in range(levels):
        y = 12.0 * k + 0.6
        box(b, V(W / 2, y, -dep / 2), (W, 0.25, dep), {"side": "iron", "skip_back": True})
        # railing: top rail (front and top), mid rail (front), end posts and three bars
        b.face([V(0, y + 3.2, -dep), V(W, y + 3.2, -dep), V(W, y + 3.4, -dep), V(0, y + 3.4, -dep)], "iron", V(0, 0, -1))
        b.face([V(0, y + 3.4, -dep), V(W, y + 3.4, -dep), V(W, y + 3.4, -dep + 0.2), V(0, y + 3.4, -dep + 0.2)], "iron", V(0, 1, 0))
        b.face([V(0, y + 1.6, -dep), V(W, y + 1.6, -dep), V(W, y + 1.75, -dep), V(0, y + 1.75, -dep)], "iron", V(0, 0, -1))
        for x in (0.1, W * 0.25, W * 0.5, W * 0.75, W - 0.1):
            b.face2([V(x - 0.08, y, -dep), V(x + 0.08, y, -dep), V(x + 0.08, y + 3.3, -dep), V(x - 0.08, y + 3.3, -dep)], "iron_light" if 0.1 < x < W - 0.1 else "iron")
        for x in (0.1, W - 0.1):
            b.face2([V(x, y + 3.3, -dep), V(x, y + 3.3, 0), V(x, y + 3.1, 0), V(x, y + 3.1, -dep)], "iron")
        # one diagonal bracket per end
        for x in (0.6, W - 0.6):
            b.face2([V(x, y - 0.1, -dep + 0.3), V(x, y - 0.1, -dep + 0.6), V(x, y - 2.2, 0), V(x, y - 2.5, 0)], "iron")
        if k < levels - 1:
            a, c = (1.0, W - 1.6) if k % 2 == 0 else (W - 1.6, 1.0)
            # the stair as one slanted tread plank between two stringers
            b.face2([V(a, y + 0.15, -0.6), V(c, y + 12.15, -0.6), V(c, y + 12.15, -2.0), V(a, y + 0.15, -2.0)], "iron_light")
            for z in (-0.5, -2.1):
                b.face2([V(a, y + 0.1, z), V(c, y + 12.1, z), V(c, y + 12.6, z), V(a, y + 0.6, z)], "iron")
    # raised drop ladder: two rails and a rung panel
    for x in (W - 2.2, W - 1.2):
        b.face2([V(x - 0.06, -5.4, -dep + 0.3), V(x + 0.06, -5.4, -dep + 0.3), V(x + 0.06, 0.4, -dep + 0.3), V(x - 0.06, 0.4, -dep + 0.3)], "iron")
    for i in range(3):
        b.face2([V(W - 2.2, -5.0 + 1.8 * i, -dep + 0.3), V(W - 1.2, -5.0 + 1.8 * i, -dep + 0.3), V(W - 1.2, -4.85 + 1.8 * i, -dep + 0.3), V(W - 2.2, -4.85 + 1.8 * i, -dep + 0.3)], "iron")
    return b, {
        "family": "Prop",
        "levels": levels,
        "projection": dep,
        "lod": "near",
        "district": "MS,MT",
        "pivot": "wall plane, left end of the first platform, first upper floor level; spans x 0..10, projects to z -3",
        "sockets": {"mount": sock((0, 0, 0))},
        "replaces": f"B_FireEscape{levels}",
    }


def water_tank(name):
    """A trimmed rooftop water tank (before: B_WaterTank 272): four legs, an 8-sided staved tank
    with two bands and a cone roof with a finial. Pivot at the bottom centre."""
    b = B2Builder(name)
    for k in range(4):
        a = math.pi / 4 + math.pi / 2 * k
        box(b, V(math.cos(a) * 2.6, 3.0, math.sin(a) * 2.6), (0.45, 6.0, 0.45), {"side": "tank_band", "skip_bottom": True, "skip_top": True})
    for k in range(2):
        a0 = math.pi / 4 + math.pi * k
        b.face2([V(math.cos(a0) * 2.6, 0.6, math.sin(a0) * 2.6), V(math.cos(a0 + math.pi) * 2.6, 5.4, math.sin(a0 + math.pi) * 2.6), V(math.cos(a0 + math.pi) * 2.6, 5.7, math.sin(a0 + math.pi) * 2.6), V(math.cos(a0) * 2.6, 0.9, math.sin(a0) * 2.6)], "tank_band")
    cyl(b, V(0, 6.0, 0), 6.3, 3.5, 8, "tank_wood", top=False, bottom=True, r_top=3.3)
    for y in (7.6, 10.6):
        cyl(b, V(0, y, 0), 0.35, 3.55 - (y - 6.0) * 0.032, 8, "tank_band", top=False)
    cyl(b, V(0, 12.3, 0), 2.4, 3.6, 8, "roof_dark", r_top=0.3)
    cyl(b, V(0, 14.7, 0), 0.5, 0.3, 4, "tank_band", r_top=0.1)
    return b, {"family": "Prop", "height": 15.2, "footprint": 7.2, "lod": "near", "district": "MS,MT,HB", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}, "replaces": "B_WaterTank", "rule": "on no more than one roof in three"}


def vent_stack(name):
    b = B2Builder(name)
    box(b, V(0, 1.2, 0), (3.0, 2.4, 3.0), {"side": "vent", "top": "vent_dark", "skip_bottom": True})
    cyl(b, V(0.4, 2.4, 0.3), 3.2, 0.6, 6, "vent_dark", top=True)
    cyl(b, V(0.4, 5.6, 0.3), 0.6, 1.0, 6, "vent", r_top=0.4)
    return b, {"family": "Prop", "height": 6.2, "lod": "near", "district": "MT,MS,HB", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}}


# ---------------------------------------------------------------- midground masses
def mid_block(name, w, d, h, sw, top="flat", district="any", bands=True):
    """A simple closed mass for the midground band (60-140 studs back): no openings, painted
    window bands on the three faces a road can see, a cap band; 'stepped' adds a setback block.
    Pivot at the bottom centre of its front face (it is placed by the midground layout, not on
    the frontage line)."""
    b = B2Builder(name, {"wall": sw})
    hw = w / 2
    box(b, V(0, h / 2, d / 2), (w, h, d), {"side": "wall", "top": "roof", "skip_bottom": True})
    if bands:
        floors = int((h - 10) // 12)
        for f in range(floors):
            y0 = 8 + 12 * f
            b.face([V(-hw + 2, y0, -0.15), V(hw - 2, y0, -0.15), V(hw - 2, y0 + 5.5, -0.15), V(-hw + 2, y0 + 5.5, -0.15)], "mid_window", V(0, 0, -1))
            for sx in (-1, 1):
                b.face([V(sx * (hw + 0.15), y0, 2), V(sx * (hw + 0.15), y0, d - 2), V(sx * (hw + 0.15), y0 + 5.5, d - 2), V(sx * (hw + 0.15), y0 + 5.5, 2)], "mid_window", V(sx, 0, 0))
    box(b, V(0, h + 0.5, d / 2), (w + 1.0, 1.0, d + 1.0), {"side": "mid_trim", "top": "roof"})
    H = h + 1.0
    if top == "stepped":
        box(b, V(0, h + 5.0, d / 2 + 2), (w * 0.62, 8.0, d * 0.62), {"side": "wall", "top": "roof", "skip_bottom": True})
        box(b, V(0, h + 9.3, d / 2 + 2), (w * 0.62 + 0.8, 0.6, d * 0.62 + 0.8), {"side": "mid_trim", "top": "roof", "skip_bottom": True})
        H = h + 9.6
    elif top == "crown":
        box(b, V(0, h + 4.0, d / 2), (w * 0.45, 6.0, d * 0.45), {"side": "mid_trim", "top": "roof", "skip_bottom": True})
        cyl(b, V(0, h + 7.0, d / 2), 10.0, w * 0.12, 4, "mid_trim", r_top=0.2, phase=math.pi / 4)
        H = h + 17.0
    return b, {"family": "Mid", "width": w, "depth": d, "height": H, "lod": "mid", "district": district, "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}, "band": "midground 60-140 from the road edge"}


def mid_glass(name, w, h, district="MT"):
    """A selective glass tower for Midtown's midground: glass body, pale spandrel bands every
    two floors, pale corner piers, a plant-room crown."""
    b = B2Builder(name)
    hw = w / 2
    box(b, V(0, h / 2, hw), (w - 2, h, w - 2), {"side": "glass", "top": "roof", "skip_bottom": True})
    for y in range(24, int(h), 24):
        box(b, V(0, y, hw), (w - 1.6, 1.4, w - 1.6), {"side": "mid_trim", "skip_top": True, "skip_bottom": True})
    for sx in (-1, 1):
        for sz in (0, 1):
            box(b, V(sx * (hw - 1.0), h / 2, 1.0 + sz * (w - 2.0)), (2.0, h, 2.0), {"side": "mid_trim", "skip_bottom": True, "skip_top": True})
    box(b, V(0, h + 1.5, hw), (w, 3.0, w), {"side": "mid_trim", "top": "roof"})
    box(b, V(0, h + 5.0, hw + 3), (w * 0.4, 4.0, w * 0.4), {"side": "mid_trim", "top": "roof_dark", "skip_bottom": True})
    return b, {"family": "Mid", "width": w, "depth": w, "height": h + 7.0, "lod": "mid", "district": district, "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}}


def mid_civic_dome(name):
    """City Hall district midground: a stone drum and a shallow ribbed copper dome with a lantern,
    over a plain block (reads at the skyline's edge as 'civic')."""
    b = B2Builder(name)
    box(b, V(0, 15.0, 18.0), (44.0, 30.0, 36.0), {"side": "civic_stone", "top": "civic_roof", "skip_bottom": True})
    cyl(b, V(0, 30.0, 18.0), 8.0, 11.0, 10, "civic_column", top=False)
    prev = None
    for i in range(4):
        a = (math.pi / 2) * i / 4
        r = 11.5 * math.cos(a)
        y = 38.0 + 10.0 * math.sin(a)
        cur = [V(math.cos(2 * math.pi * k / 10) * r, y, 18.0 + math.sin(2 * math.pi * k / 10) * r) for k in range(10)]
        if prev:
            for k in range(10):
                k2 = (k + 1) % 10
                q = [prev[k], prev[k2], cur[k2], cur[k]]
                cen = sum(q, V(0)) / 4
                b.face(q, "copper" if k % 2 else "copper_dark", cen - V(0, 30.0, 18.0))
        prev = cur
    b.face(prev, "copper", V(0, 1, 0))
    cyl(b, V(0, 46.6, 18.0), 4.0, 1.6, 6, "civic_column", r_top=1.4)
    cyl(b, V(0, 50.6, 18.0), 3.0, 1.6, 6, "copper", r_top=0.1)
    return b, {"family": "Mid", "width": 44, "depth": 36, "height": 53.6, "lod": "mid", "district": "CH", "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}}


def mid_warehouse(name):
    """Harbor midground: a long shed with a saw-tooth roof (four teeth)."""
    b = B2Builder(name)
    w, d, h = 48.0, 30.0, 14.0
    box(b, V(0, h / 2, d / 2), (w, h, d), {"side": "shed_wall", "top": "shed_roof", "skip_bottom": True, "skip_top": True})
    n = 4
    for i in range(n):
        x0 = -w / 2 + w * i / n
        x1 = x0 + w / n
        b.face([V(x0, h, 0), V(x1, h + 6.0, 0), V(x1, h + 6.0, d), V(x0, h, d)], "shed_roof", V(-0.6, 1, 0))
        b.face([V(x1, h, 0), V(x1, h + 6.0, 0), V(x1, h + 6.0, d), V(x1, h, d)], "glass_light", V(1, 0, 0))
        for z in (0, d):
            b.face([V(x0, h, z), V(x1, h, z), V(x1, h + 6.0, z)], "shed_wall", V(0, 0, -1 if z == 0 else 1))
    return b, {"family": "Mid", "width": w, "depth": d, "height": h + 6.0, "lod": "mid", "district": "HB", "pivot": "bottom centre of the front face", "sockets": {"base": sock((0, 0, 0))}}


def mid_trees(name):
    """Skyline Park midground: a clump of five low-poly crowns on short trunks (one mesh)."""
    b = B2Builder(name)
    pts = [(-9, 4, 1.0), (-2, 9, 1.25), (6, 3, 1.1), (11, 10, 0.9), (1, -2, 0.95)]
    for i, (x, z, s) in enumerate(pts):
        cyl(b, V(x, 0, z), 6.0 * s, 0.6 * s, 4, "trunk", top=False)
        sphere(b, V(x, 9.5 * s, z), (5.2 * s, 4.6 * s, 5.2 * s), ["leaf_dark", "leaf_mid", "leaf_light", "leaf_sun"], subdiv=1)
    return b, {"family": "Mid", "width": 30, "depth": 20, "height": 15, "lod": "mid", "district": "SP", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}}


# ---------------------------------------------------------------- catalogue
def build_all(emit):
    # Main Street: low/mid-rise shops, warm brick, cream cornices, teal/burgundy/navy awnings
    for cw in ("a", "b", "c"):
        emit(*shop_lot(f"B2_Lot_Shop24Low_{cw}", 24, 2, cw, top="cornice" if cw != "c" else "stepped"))
        emit(*shop_lot(f"B2_Lot_Shop24Mid_{cw}", 24, 3, cw, top="cornice" if cw != "b" else "pediment", arched=cw == "c"))
    emit(*shop_lot("B2_Lot_Shop24Low_d", 24, 2, "d", top="stepped"))
    emit(*shop_lot("B2_Lot_Shop36Mid_a", 36, 3, "a", top="pediment"))
    emit(*shop_lot("B2_Lot_Shop36Mid_b", 36, 3, "b", top="cornice", arched=True))
    emit(*shop_lot("B2_Lot_Shop48Low_a", 48, 2, "a", top="stepped"))
    emit(*shop_lot("B2_Lot_Shop48Low_c", 48, 2, "c", top="cornice"))
    emit(*corner_lot("B2_Lot_Corner24Mid_R", 24, 3, "a"))
    emit(*corner_lot("B2_Lot_Corner24Mid_L", 24, 3, "a", mirror=True))
    # City Hall: broad civic facades in stone
    emit(*civic_lot("B2_Lot_Civic36Mid_a", 36, 3, "a"))
    emit(*civic_lot("B2_Lot_Civic48Mid_b", 48, 3, "b"))
    # Harbor Bridge: brick warehouses
    emit(*warehouse_lot("B2_Lot_Warehouse48Low_a", 48, 2, "a"))
    emit(*warehouse_lot("B2_Lot_Warehouse36Mid_b", 36, 3, "b"))
    # Midtown: tall grids with set-back tops
    emit(*tall_lot("B2_Lot_Tall36Grid_a", 36, 6, "a", "grid"))
    emit(*tall_lot("B2_Lot_Tall24Brick_b", 24, 5, "b", "brick"))
    emit(*tall_lot("B2_Lot_Tall36Glass_a", 36, 7, "a", "glass"))
    # Skyline Park: set-back townhouses
    emit(*townhouse_lot("B2_Lot_Townhouse24_a", 24, 3, "a"))
    emit(*townhouse_lot("B2_Lot_Townhouse24_b", 24, 3, "b"))
    # glue: open lots
    emit(*open_lot("B2_Lot_Pocket24", 24, "pocket", "any"))
    emit(*open_lot("B2_Lot_Plaza48", 48, "plaza", "CH"))
    emit(*open_lot("B2_Lot_Park48", 48, "park", "SP"))
    # roof props
    emit(*fire_escape("B2_Prop_FireEscape2", 2))
    emit(*fire_escape("B2_Prop_FireEscape3", 3))
    emit(*water_tank("B2_Prop_WaterTank"))
    emit(*vent_stack("B2_Prop_Vent"))
    # midground
    emit(*mid_block("B2_Mid_Block36_1", 36, 30, 50, "mid_1", "flat", "any"))
    emit(*mid_block("B2_Mid_Block36_2", 36, 30, 62, "mid_2", "stepped", "any"))
    emit(*mid_block("B2_Mid_Block36_3", 36, 30, 74, "mid_3", "stepped", "any"))
    emit(*mid_block("B2_Mid_Tower40_4", 40, 34, 110, "mid_4", "crown", "MT"))
    emit(*mid_glass("B2_Mid_Glass40", 40, 130))
    emit(*mid_civic_dome("B2_Mid_CivicDome"))
    emit(*mid_warehouse("B2_Mid_Warehouse48"))
    emit(*mid_trees("B2_Mid_TreeClump"))
