# Island kit: race plot front pieces (Lane 3, Task 3), in the kit's smooth faceted language.
#   PlotGate    replaces the greybox gate (Hub/Recipes/Plot.luau) with the same footprint: pillars
#               1.5 x 1.5 at x +/-7.75, 9 tall; lintel x -8.5..8.5, top 9.6, 1.2 tall, 1.5 deep;
#               nameplate 10 x 2.5 centred at height 11.45, 0.8 in front of the lintel centre line
#               (as the greybox). The opening x -7..7, z 0..8.4 stays empty. Ground line z 0.
#   KioskBooth  the upgrade kiosk placeholder inside the Kiosk reservation (HubData: x 19..29,
#               u 250.187..258.187) minus 1 stud a side: 8 (x) x 6 (y), at most 6 tall, origin at the
#               footprint centre on the ground; mesh x = plot x, mesh y = plot u, front faces -y
#               (toward the park). Decorative only: a blank sign panel, no prices or goods.
#   Flagpole    a slim 10-stud pole, flag side +x.
#   HeaderBoard a food-stand header board, origin at the board centre.
# Front faces -y. Meta points are Blender mesh-local (x right, y back, z up) from the mesh origin;
# Roblox mesh-local is (x, z, -y), and a MeshPart is centred on its bounds (see the manifest).

from mathutils import Vector

from kit_portal import ball, cbox, cyl, dome, oface, sweep, torus
from kitlib import Builder, box


def pbox(b, centre, size, swatch):
    """A plain box (12 triangles) for small trims where a chamfer would not show."""
    box(b, Vector(centre), Vector(size), swatch)


# ---------------------------------------------------------------- plot gate
GATE_POST_X, GATE_POST_W, GATE_POST_H = 7.75, 1.5, 9.0
LINTEL_X, LINTEL_TOP, LINTEL_H, LINTEL_D = 8.5, 9.6, 1.2, 1.5
PLATE_W, PLATE_H, PLATE_T, PLATE_Z, PLATE_Y = 10.0, 2.5, 0.4, 11.45, -0.8


def plot_gate(name):
    b = Builder(name)
    w = GATE_POST_W
    for s in (-1, 1):
        x = s * GATE_POST_X
        # cream foot, coral shaft, a yellow band and a cream collar under the lintel: one footprint
        cbox(b, Vector((x, 0, 0.4)), (w, w, 0.8), "cart_white", c=0.1)
        cbox(b, Vector((x, 0, 0.8 + 3.2)), (w, w, 6.4), "coral", c=0.1)
        cbox(b, Vector((x, 0, 7.45)), (w, w, 0.5), "awning_yellow", c=0.1)
        cbox(b, Vector((x, 0, 8.2)), (w, w, 1.0), "cart_white", c=0.1)
        # rounded caps on the lintel above the pillars
        cbox(b, Vector((x, 0, LINTEL_TOP + 0.1)), (1.4, 1.4, 0.2), "cart_white", c=0.06)
        dome(b, Vector((x, 0, LINTEL_TOP + 0.2)), 0.6, 0.55, 10, 3, "awning_yellow")
    lz = LINTEL_TOP - LINTEL_H / 2
    cbox(b, Vector((0, 0, lz)), (2 * LINTEL_X, LINTEL_D, LINTEL_H), "coral", c=0.14)
    # a checkered band on both faces of the lintel, edged with thin yellow lines
    sq, cols = 0.4, 32
    x0 = -sq * cols / 2
    for face_y in (-LINTEL_D / 2 - 0.012, LINTEL_D / 2 + 0.012):
        for row in range(2):
            z0 = lz - sq + row * sq
            for k in range(cols):
                xa = x0 + k * sq
                sw = "black" if (row + k) % 2 == 0 else "cart_white"
                pts = [Vector((xa, face_y, z0)), Vector((xa + sq, face_y, z0)), Vector((xa + sq, face_y, z0 + sq)), Vector((xa, face_y, z0 + sq))]
                oface(b, pts, sw, Vector((xa + sq / 2, 0, z0 + sq / 2)))
        for zl in (lz - sq - 0.06, lz + sq):
            pts = [Vector((x0, face_y, zl)), Vector((-x0, face_y, zl)), Vector((-x0, face_y, zl + 0.06)), Vector((x0, face_y, zl + 0.06))]
            oface(b, pts, "awning_yellow", Vector((0, 0, zl)))
    # nameplate: a cream board with a coral frame, on two short supports from the lintel
    plate_bottom = PLATE_Z - PLATE_H / 2
    for x in (-3.5, 3.5):
        cbox(b, Vector((x, PLATE_Y + 0.15, (LINTEL_TOP + plate_bottom) / 2 + 0.02)), (0.5, 0.4, plate_bottom - LINTEL_TOP + 0.14), "coral", c=0.06)
    cbox(b, Vector((0, PLATE_Y, PLATE_Z)), (PLATE_W, PLATE_T, PLATE_H), "cart_white", c=0.08, edge="coral", back="coral")
    front = PLATE_Y - PLATE_T / 2
    fw, fd = 0.2, 0.08
    fy = front - fd / 2 + 0.01
    cbox(b, Vector((0, fy, PLATE_Z + PLATE_H / 2 - fw / 2)), (PLATE_W, fd, fw), "coral", c=0.025)
    cbox(b, Vector((0, fy, PLATE_Z - PLATE_H / 2 + fw / 2)), (PLATE_W, fd, fw), "coral", c=0.025)
    for s in (-1, 1):
        cbox(b, Vector((s * (PLATE_W / 2 - fw / 2), fy, PLATE_Z)), (fw, fd, PLATE_H - 2 * fw + 0.02), "coral", c=0.025)
    # little yellow rounded ends on the nameplate's top corners
    for s in (-1, 1):
        ball(b, Vector((s * (PLATE_W / 2 - 0.1), PLATE_Y, PLATE_Z + PLATE_H / 2 + 0.05)), 0.22, 8, 4, "awning_yellow")
    height = PLATE_Z + PLATE_H / 2 + 0.27
    return b, {
        "height": round(height, 3), "opening": {"x": [-7.0, 7.0], "z": [0.0, 8.4]},
        "pillars_x": [-GATE_POST_X, GATE_POST_X], "pillar_size": [w, w, GATE_POST_H],
        "lintel": {"x": [-LINTEL_X, LINTEL_X], "top": LINTEL_TOP, "height": LINTEL_H, "depth": LINTEL_D},
        "nameplate": {"centre": [0.0, PLATE_Z], "size": [round(PLATE_W - 2 * fw, 3), round(PLATE_H - 2 * fw, 3)],
                      "plane_y": round(front, 3), "board": [PLATE_W, PLATE_H, PLATE_T], "board_centre_y": PLATE_Y},
        "note": "nameplate face: centre (x, z), size (w, h) inside the coral frame, on the plane y = plane_y (front -y)",
    }


# ---------------------------------------------------------------- kiosk
KIOSK_W, KIOSK_D, KIOSK_MAX_H = 8.0, 6.0, 6.0


def awning(b, x0, x1, y_wall, y_edge, z_wall, z_edge, stripes, sw_a, sw_b, drop=0.28):
    for i in range(stripes):
        xa = x0 + (x1 - x0) * i / stripes
        xb = x0 + (x1 - x0) * (i + 1) / stripes
        sw = sw_a if i % 2 == 0 else sw_b
        b.face2([Vector((xa, y_edge, z_edge)), Vector((xb, y_edge, z_edge)), Vector((xb, y_wall, z_wall)), Vector((xa, y_wall, z_wall))], sw)
        b.face2([Vector((xa, y_edge, z_edge)), Vector(((xa + xb) / 2, y_edge, z_edge - drop)), Vector((xb, y_edge, z_edge))], sw)


def kiosk_booth(name):
    b = Builder(name)
    yf, yb = -2.4, 2.8
    # skirt, body and corner posts
    cbox(b, Vector((0, 0.2, 0.25)), (7.8, 5.6, 0.5), "cart_white", c=0.08)
    body_top = 4.4
    cbox(b, Vector((0, (yf + 0.4 + yb) / 2, (0.5 + body_top) / 2)), (7.6, yb - yf - 0.4, body_top - 0.5), "mint", c=0.06)
    wy = yf + 0.2
    wx, wz0, wz1 = 2.2, 1.7, 3.6
    # the front wall round the counter window (plain blocks; corner posts hide the outer edges)
    for x0, x1, z0, z1 in ((-3.8, -wx, 0.5, body_top), (wx, 3.8, 0.5, body_top), (-wx, wx, 0.5, wz0), (-wx, wx, wz1, body_top)):
        pbox(b, Vector(((x0 + x1) / 2, wy, (z0 + z1) / 2)), (x1 - x0, 0.4, z1 - z0), "mint")
    # the window: a warm interior, a cream frame and a wooden counter on two brackets
    oface(b, [Vector((-wx, wy + 0.19, wz0)), Vector((wx, wy + 0.19, wz0)), Vector((wx, wy + 0.19, wz1)), Vector((-wx, wy + 0.19, wz1))], "plank_dark", Vector((0, 2, 2.6)))
    fy = yf - 0.03
    for c, s in (((0, fy, wz1 + 0.06), (2 * wx + 0.24, 0.08, 0.12)), ((0, fy, wz0 - 0.06), (2 * wx + 0.24, 0.08, 0.12)),
                 ((-wx - 0.06, fy, (wz0 + wz1) / 2), (0.12, 0.08, wz1 - wz0)), ((wx + 0.06, fy, (wz0 + wz1) / 2), (0.12, 0.08, wz1 - wz0))):
        pbox(b, Vector(c), s, "cart_white")
    cbox(b, Vector((0, -2.5, 1.72)), (5.0, 0.8, 0.16), "bench_wood", c=0.04)
    for x in (-1.8, 1.8):
        pbox(b, Vector((x, -2.55, 1.35)), (0.14, 0.3, 0.6), "metal")
    for x in (-3.8, 3.8):
        for y in (yf, yb):
            cbox(b, Vector((x, y, (0.5 + body_top) / 2)), (0.4, 0.4, body_top - 0.5), "cart_white", c=0.06)
    # striped awning over the window
    awning(b, -2.6, 2.6, yf - 0.02, -2.95, 4.25, 3.85, 6, "coral", "cart_white")
    # roof: a coral slab with a cream top
    cbox(b, Vector((0, 0, body_top + 0.1)), (KIOSK_W, KIOSK_D, 0.2), "coral", c=0.06)
    cbox(b, Vector((0, 0, body_top + 0.275)), (KIOSK_W - 0.2, KIOSK_D - 0.2, 0.15), "cart_white", c=0.05)
    roof_top = body_top + 0.35
    # blank sign panel on the roof front: coral backing, cream face, two brackets behind
    pz, pw, ph = 5.35, 5.0, 0.9
    for x in (-2.0, 2.0):
        pbox(b, Vector((x, -2.3, roof_top + 0.25)), (0.2, 0.4, 0.5), "metal")
    cbox(b, Vector((0, -2.6, pz)), (5.4, 0.2, 1.2), "coral", c=0.05)
    face_y = -2.7 - 0.06
    pbox(b, Vector((0, -2.73, pz)), (pw, 0.06, ph), "cart_white")
    height = pz + 0.6
    return b, {
        "height": round(height, 3), "footprint": [KIOSK_W, KIOSK_D], "max_height": KIOSK_MAX_H,
        "panel": {"centre": [0.0, pz], "size": [pw, ph], "plane_y": round(face_y, 3)},
        "window": {"x": [-wx, wx], "z": [wz0, wz1]}, "counter_top": 1.8,
        "note": "origin at the footprint centre on the ground; mesh x = plot x, mesh y = plot u; front -y",
    }


# ---------------------------------------------------------------- flagpole
def flagpole(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, 0.125)), (0.9, 0.9, 0.25), "metal", c=0.05)
    cyl(b, Vector((0, 0, 0.25)), 0.4, 0.2, 8, "metal", r_top=0.15)
    cyl(b, Vector((0, 0, 0.6)), 9.06, 0.12, 8, "cart_white", r_top=0.085)
    cyl(b, Vector((0, 0, 9.62)), 0.1, 0.12, 8, "metal")
    ball(b, Vector((0, 0, 9.86)), 0.14, 8, 4, "brass")
    # a cleat on the back (+y): a stem and a horned bar
    sweep(b, [Vector((0, 0.08, 1.3)), Vector((0, 0.22, 1.3))], 0.03, 5, "metal")
    sweep(b, [Vector((0, 0.24, 1.08)), Vector((0, 0.25, 1.3)), Vector((0, 0.24, 1.52))], 0.035, 5, "metal")
    return b, {
        "height": 10.0, "flag_top": 9.6, "flag_bottom": 7.6, "flag_side": "+x",
        "pole_radius_at_flag_bottom": round(0.12 - (0.035 * (7.6 - 0.6) / 9.06), 3), "pole_radius_at_flag_top": round(0.12 - (0.035 * (9.6 - 0.6) / 9.06), 3),
        "cleat": [0.0, 0.24, 1.3],
    }


# ---------------------------------------------------------------- header board
HB_W, HB_H, HB_T = 3.0, 1.6, 0.18


def header_board(name):
    b = Builder(name)
    cbox(b, Vector((0, 0, 0)), (HB_W, HB_T, HB_H), "plank", c=0.03, edge="plank_dark")
    tw, td = 0.1, 0.04
    ty = -HB_T / 2 - td / 2 + 0.005
    pbox(b, Vector((0, ty, HB_H / 2 - tw / 2)), (HB_W, td, tw), "bark_warm")
    pbox(b, Vector((0, ty, -HB_H / 2 + tw / 2)), (HB_W, td, tw), "bark_warm")
    for s in (-1, 1):
        pbox(b, Vector((s * (HB_W / 2 - tw / 2), ty, 0)), (tw, td, HB_H - 2 * tw + 0.01), "bark_warm")
    hangs = []
    for x in (-1.0, 1.0):
        # a strap over the top edge and a ring eye above it
        pbox(b, Vector((x, 0, HB_H / 2 + 0.01)), (0.18, HB_T + 0.06, 0.2), "metal")
        torus(b, Vector((x, 0, HB_H / 2 + 0.15)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.1, 0.03, 6, 4, "metal")
        hangs.append([x, round(HB_H / 2 + 0.15, 3)])
    return b, {
        "board": [HB_W, HB_H, HB_T], "origin": "board centre",
        "face": {"centre": [0.0, 0.0], "size": [round(HB_W - 2 * tw, 3), round(HB_H - 2 * tw, 3)], "plane_y": round(-HB_T / 2, 3)},
        "hang_eyes": hangs, "height_above_centre": round(HB_H / 2 + 0.26, 2),
    }



def build_all(emit):
    P = "plot/"
    emit(*plot_gate("PlotGate"), P + "Gate")
    emit(*kiosk_booth("KioskBooth"), P + "Kiosk")
    emit(*flagpole("Flagpole"), P + "Flag")
    emit(*header_board("HeaderBoard"), P + "Food")
