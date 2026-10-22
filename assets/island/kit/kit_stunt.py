# Island kit: the Stunt Circuit entrance and the leaderboard frame (Lane 3, Task 4, CONCEPT stage),
# in the kit's smooth faceted language: cream / light stone, navy / teal structure, chamfered edges.
#
# Stunt Circuit entrance: envelope 37 (x) x 40 (y), front faces -y (toward the fountain), ground z 0.
# Meshes modelled in ENVELOPE coordinates (origin = envelope centre on the ground):
#   StuntGantry        two pillars 3.5 x 3.5 (clear span 22), beam 4 deep, underside 10, top 18,
#                      gantry centre line y = -17; blank lettering face and blank back face.
#   StuntApron         the asphalt apron (22 wide) from the envelope front to y 19, kerbs both sides.
#   StuntGridMarkings  a separate thin paint mesh: start-line checker and four staggered grid boxes.
#   StuntEndBarrier    the low COMING SOON / PREVIEW barrier with a blank sign face (max 6 tall).
# Meshes with their own origin (placed by meta "layout" on StuntGantry):
#   StuntStartLightHousing  one housing (5 used), origin at the housing centre, front -y.
#   StuntStartLightLens     the two lamp lenses of one housing (5 used), same origin as the housing,
#                           neutral swatch (accent_neutral) so Luau can colour or glow it.
#   StuntTireRow       four stacks of three tyres along local x (5 used along the apron sides).
#   StuntLoop          the loop-the-loop sculpture on its plinth; loop in the local xz plane.
#   StuntPodium        the 1/2/3 podium; origin at the footprint centre, front -y.
#   StuntPreviewBoard  a 6 x 4 board on two posts (2 used: YOUR BEST, WEEKLY TOP); blank faces.
# Leaderboard (envelope 18 x 4 x 15, front -y, ground z 0):
#   LeaderboardFrame            the board: plinth, posts, rails, cream rows face, teal header, crest.
#   LeaderboardEmblemCar        swappable crest emblem (toy car), origin at the crest mount point.
#   LeaderboardEmblemStopwatch  swappable crest emblem (stopwatch), same origin convention.
# Meta points are in Blender mesh-local axes (x right, y back, z up, front faces -y), relative to
# the mesh origin. Roblox mesh-local is (x, z, -y); a MeshPart is centred on its bounds, so subtract
# the bounds centre from the manifest before placing anything on a MeshPart. Placements use rot_z in
# degrees about +z (counter-clockwise seen from above); in Roblox that is CFrame.Angles(0, rad, 0).

import math

from mathutils import Vector

from kit_plot import pbox
from kit_portal import at_y, cbox, cyl, dome, layered, oface, rrect, sweep, tface
from kitlib import Builder

NAVY, TEAL, CREAM, STONE = "navy", "teal", "cream", "stone_light"
ASPHALT, RUBBER, LENS, CORAL = "steel", "raccoon_dark", "accent_neutral", "coral"


def V(x, y, z):
    return Vector((x, y, z))


def r3(v):
    return [round(c, 3) for c in v]


def rect_meta(cx, cz, w, h, plane_y):
    return {"centre": [round(cx, 3), round(cz, 3)], "size": [round(w, 3), round(h, 3)], "plane_y": round(plane_y, 3)}


def quad_y(b, x0, x1, z0, z1, y, sw, facing=-1):
    """A flat quad on the plane y, its normal along facing * y."""
    oface(b, [V(x0, y, z0), V(x1, y, z0), V(x1, y, z1), V(x0, y, z1)], sw, V((x0 + x1) / 2, y - facing, (z0 + z1) / 2))


def quad_z(b, x0, x1, y0, y1, z, sw):
    """A flat upward-facing quad at height z."""
    oface(b, [V(x0, y0, z), V(x1, y0, z), V(x1, y1, z), V(x0, y1, z)], sw, V((x0 + x1) / 2, (y0 + y1) / 2, z - 1))


def checker_y(b, x0, cols, sq, z0, rows, y, facing, sw_a="black", sw_b=CREAM, skip=None):
    for row in range(rows):
        for k in range(cols):
            xa = x0 + k * sq
            if skip and skip(xa + sq / 2):
                continue
            quad_y(b, xa, xa + sq, z0 + row * sq, z0 + (row + 1) * sq, y, sw_a if (row + k) % 2 == 0 else sw_b, facing)


# ---------------------------------------------------------------- envelope and gantry numbers
ENV_W, ENV_D, ENV_H = 37.0, 40.0, 18.0
FRONT_Y = -ENV_D / 2
GY = -17.0
SPAN, PIL, BEAM_D, BEAM_Z0, BEAM_Z1 = 22.0, 3.5, 4.0, 10.0, 18.0
PX0 = SPAN / 2
PX1 = PX0 + PIL
PCX = (PX0 + PX1) / 2
BEAM_FRONT = GY - BEAM_D / 2
BEAM_BACK = GY + BEAM_D / 2

LIGHT_W, LIGHT_H, LIGHT_D, LIGHT_PITCH, LIGHT_Z, LIGHT_EMBED = 1.6, 2.4, 1.2, 2.6, 12.4, 0.5
LIGHT_Y = BEAM_FRONT + LIGHT_EMBED - LIGHT_D / 2
LIGHT_XS = [(i - 2) * LIGHT_PITCH for i in range(5)]
LAMP_DZ, LAMP_R = 0.55, 0.5
LENS_BACK_Y = -LIGHT_D / 2 - 0.06
LENS_APEX_Y = LENS_BACK_Y - 0.14

SIGN_Z0, SIGN_Z1, SIGN_HW, SIGN_T = 14.1, 17.5, 12.6, 0.3
BACK_Z0, BACK_Z1, BACK_HW = 13.6, 16.8, 10.0

APRON_Y1 = 19.0
APRON_TOP = 0.2
SLOTS = [(-5.0, -11.0), (5.0, -3.0), (-5.0, 5.0), (5.0, 13.0)]

TIRE_PITCH, TIRE_STACKS = 2.3, 4
TIRE_X = PX0 + 1.2
TIRE_ROWS = [(TIRE_X, -9.2), (TIRE_X, 0.0), (TIRE_X, 9.2), (-TIRE_X, -9.2), (-TIRE_X, 9.2)]

BAR_Y, BAR_D, BAR_H, BAR_HW = 17.6, 1.4, 1.2, 12.4

PB_W, PB_H, PB_Z0, PB_T = 6.0, 4.0, 2.4, 0.4
PB_X = PX0 + 0.75 + PB_W / 2
PB_Y = FRONT_Y + 0.4

LOOP_AT, LOOP_ROT = (15.95, 3.0), -90.0
PODIUM_AT, PODIUM_ROT = (-15.4, 0.0), 90.0


def gantry(name):
    b = Builder(name)
    for s in (-1, 1):
        x = s * PCX
        # stone foot, navy shaft, teal collar under the beam: one 3.5 x 3.5 footprint
        cbox(b, V(x, GY, 0.6), (PIL, PIL, 1.6), STONE, c=0.2)
        cbox(b, V(x, GY, 5.4), (PIL, PIL, 8.0), NAVY, c=0.2)
        cbox(b, V(x, GY, 9.7), (PIL, PIL, 0.6), TEAL, c=0.12)
        # cream chevrons on the inner (track) face, pointing into the circuit (+y)
        xf = s * (PX0 - 0.04)
        for zc in (3.4, 5.4, 7.4):
            for arm in (1, -1):
                yz = [(GY - 0.75, zc + arm * 0.8), (GY - 0.15, zc + arm * 0.8), (GY + 0.85, zc), (GY + 0.25, zc)]
                oface(b, [V(xf, y, z) for y, z in yz], CREAM, V(x, GY, zc))
    # the beam sits on the pillars: x -14.5..14.5, y -19..-15, z 10..18
    cbox(b, V(0, GY, (BEAM_Z0 + BEAM_Z1) / 2), (2 * PX1, BEAM_D, BEAM_Z1 - BEAM_Z0), NAVY, c=0.3)
    # a cream soffit band along the lower edge, front and back
    for yy in (BEAM_FRONT, BEAM_BACK):
        cbox(b, V(0, yy, 10.45), (2 * PX1 - 0.4, 0.3, 0.5), CREAM, c=0.08)
    # front: teal light bar behind the five housings, checkered flanks, blank lettering face
    cbox(b, V(0, BEAM_FRONT, LIGHT_Z), (14.0, 0.3, 2.9), TEAL, c=0.08)
    for s in (-1, 1):
        x0 = 7.4 if s > 0 else -7.4 - 8 * 0.8
        checker_y(b, x0, 8, 0.8, 11.6, 2, BEAM_FRONT - 0.03, -1)
    cbox(b, V(0, BEAM_FRONT, (SIGN_Z0 + SIGN_Z1) / 2), (2 * SIGN_HW, SIGN_T, SIGN_Z1 - SIGN_Z0), CREAM, c=0.12, edge=TEAL)
    # back (apron side): checkered band and a blank face
    checker_y(b, -12.8, 32, 0.8, 11.0, 2, BEAM_BACK + 0.03, 1)
    cbox(b, V(0, BEAM_BACK, (BACK_Z0 + BACK_Z1) / 2), (2 * BACK_HW, SIGN_T, BACK_Z1 - BACK_Z0), CREAM, c=0.12, edge=TEAL)

    lights = []
    for i, x in enumerate(LIGHT_XS):
        lights.append({
            "index": i + 1, "housing_centre": r3((x, LIGHT_Y, LIGHT_Z)),
            "lens_centres": [r3((x, LIGHT_Y + LENS_APEX_Y, LIGHT_Z + LAMP_DZ)), r3((x, LIGHT_Y + LENS_APEX_Y, LIGHT_Z - LAMP_DZ))],
        })
    placements = [{"mesh": m, "at": [0.0, 0.0, 0.0], "rot_z": 0.0} for m in ("StuntGantry", "StuntApron", "StuntGridMarkings", "StuntEndBarrier")]
    for x in LIGHT_XS:
        for m in ("StuntStartLightHousing", "StuntStartLightLens"):
            placements.append({"mesh": m, "at": r3((x, LIGHT_Y, LIGHT_Z)), "rot_z": 0.0})
    for x, y in TIRE_ROWS:
        placements.append({"mesh": "StuntTireRow", "at": r3((x, y, 0.0)), "rot_z": 90.0})
    placements.append({"mesh": "StuntLoop", "at": r3((LOOP_AT[0], LOOP_AT[1], 0.0)), "rot_z": LOOP_ROT, "note": "loop faces the apron (-x)"})
    placements.append({"mesh": "StuntPodium", "at": r3((PODIUM_AT[0], PODIUM_AT[1], 0.0)), "rot_z": PODIUM_ROT, "note": "podium faces the apron (+x); gap in the left tyre wall"})
    placements.append({"mesh": "StuntPreviewBoard", "at": r3((-PB_X, PB_Y, 0.0)), "rot_z": 0.0, "board": "YOUR BEST"})
    placements.append({"mesh": "StuntPreviewBoard", "at": r3((PB_X, PB_Y, 0.0)), "rot_z": 0.0, "board": "WEEKLY TOP"})
    sc = SIGN_T / 2
    return b, {
        "origin": "envelope centre on the ground (envelope x -18.5..18.5, y -20..20, front -y)",
        "gantry": {"centre_y": GY, "clear_span": SPAN, "pillar_inner_x": PX0, "pillar_outer_x": PX1, "pillar_size": [PIL, PIL],
                   "pillar_y": [GY - PIL / 2, GY + PIL / 2], "beam_y": [BEAM_FRONT, BEAM_BACK], "beam_underside": BEAM_Z0, "top": BEAM_Z1},
        "lettering_face": dict(rect_meta(0.0, (SIGN_Z0 + SIGN_Z1) / 2, 2 * (SIGN_HW - 0.12), SIGN_Z1 - SIGN_Z0 - 0.24, BEAM_FRONT - sc), text="STUNT CIRCUIT", caps=2.5),
        "back_face": dict(rect_meta(0.0, (BACK_Z0 + BACK_Z1) / 2, 2 * (BACK_HW - 0.12), BACK_Z1 - BACK_Z0 - 0.24, BEAM_BACK + sc), facing="+y", text="optional (blank)"),
        "lights": lights, "lamp_diameter": 2 * LAMP_R,
        "layout": {"placements": placements,
                   "note": "positions in this mesh's local axes (envelope coords); a placement is the mesh origin, rot_z about +z"},
        "note": "face rects: centre (x, z), size (w, h) of the flat face, on the plane y = plane_y (front faces -y unless facing says otherwise)",
    }


# ---------------------------------------------------------------- start lights
def light_housing(name):
    b = Builder(name)
    hy = LIGHT_D / 2

    def prof(inset):
        return rrect(LIGHT_W - 2 * inset, LIGHT_H - 2 * inset, max(0.06, 0.34 - inset), max(0.06, 0.34 - inset), seg=2)

    layers = [at_y(prof(0.0), hy), at_y(prof(0.0), -hy + 0.09), at_y(prof(0.09), -hy)]
    layered(b, layers, ["black", "metal"], V(0, 0, 0), cap_first="black", cap_last="black")
    # a metal bezel round each lamp; the lens sits on its dark face
    for z in (LAMP_DZ, -LAMP_DZ):
        cyl(b, V(0, -hy + 0.01, z), 0.06, LAMP_R + 0.04, 10, "metal", axis=V(0, -1, 0), top_sw="black")
    return b, {"size": [LIGHT_W, LIGHT_D, LIGHT_H], "origin": "housing centre", "front_plane_y": round(-hy, 3),
               "lamp_z": [LAMP_DZ, -LAMP_DZ], "embed": LIGHT_EMBED,
               "note": "the back 0.5 sits inside the beam; place the matching StuntStartLightLens at the same CFrame"}


def light_lens(name):
    b = Builder(name)
    for z in (LAMP_DZ, -LAMP_DZ):
        sides = 12
        back = [V(math.cos(2 * math.pi * k / sides) * LAMP_R, LENS_BACK_Y, z + math.sin(2 * math.pi * k / sides) * LAMP_R) for k in range(sides)]
        mid = [V(p.x * 0.8, LENS_BACK_Y - 0.09, z + (p.z - z) * 0.8) for p in back]
        layered(b, [back, mid], [LENS], V(0, LENS_BACK_Y - 0.03, z), cap_first=LENS)
        apex = V(0, LENS_APEX_Y, z)
        for k in range(sides):
            oface(b, [mid[k], mid[(k + 1) % sides], apex], LENS, V(0, LENS_BACK_Y, z))
    return b, {"origin": "housing centre (same CFrame as StuntStartLightHousing)", "lamp_centres": [[0.0, round(LENS_APEX_Y, 3), LAMP_DZ], [0.0, round(LENS_APEX_Y, 3), -LAMP_DZ]],
               "diameter": 2 * LAMP_R, "swatch": LENS, "note": "both lamps of one housing light together; set Material Neon + Color from Luau"}


# ---------------------------------------------------------------- apron and paint
def apron(name):
    b = Builder(name)
    y0, y1 = FRONT_Y, APRON_Y1
    cbox(b, V(0, (y0 + y1) / 2, -0.05), (SPAN, y1 - y0, 0.5), ASPHALT, c=0.12)
    n = 20
    L = (y1 - y0) / n
    top = APRON_TOP + 0.06
    for s in (-1, 1):
        xa, xb = s * (PX0 - 1.0), s * (PX0 - 0.12)
        lo, hi = min(xa, xb), max(xa, xb)
        for k in range(n):
            ya, yb = y0 + k * L, y0 + (k + 1) * L
            sw = CORAL if k % 2 == 0 else CREAM
            quad_z(b, lo, hi, ya, yb, top, sw)
            for xx in (xa, xb):
                oface(b, [V(xx, ya, APRON_TOP), V(xx, yb, APRON_TOP), V(xx, yb, top), V(xx, ya, top)], sw,
                      V((xa + xb) / 2, (ya + yb) / 2, top / 2))
    return b, {"origin": "envelope centre on the ground", "x": [-PX0, PX0], "y": [y0, y1], "top": APRON_TOP, "sink": 0.3,
               "kerb": {"width": 0.88, "top": round(top, 3)}}


def grid_markings(name):
    b = Builder(name)
    z = APRON_TOP + 0.04
    # start line under the beam: 2 rows of 1-stud squares, x -10..10, y -18..-16
    for row in range(2):
        for k in range(20):
            quad_z(b, -10 + k, -9 + k, GY - 1 + row, GY + row, z, "black" if (row + k) % 2 == 0 else CREAM)
    boxes = []
    for cx, yf in SLOTS:
        # thin raised paint: a front bar and two short legs, open at the rear
        pbox(b, V(cx, yf + 0.2, z - 0.025), (7.0, 0.4, 0.05), CREAM)
        for sx in (-1, 1):
            pbox(b, V(cx + sx * 3.3, yf + 0.4 + 1.3, z - 0.025), (0.4, 2.6, 0.05), CREAM)
        boxes.append({"centre_x": cx, "front_y": yf, "width": 7.0, "legs": 2.6})
    return b, {"origin": "envelope centre on the ground", "paint_top": round(z, 3), "start_line": {"x": [-10, 10], "y": [GY - 1, GY + 1]},
               "grid_boxes": boxes, "note": "cars on the grid face -y (toward the gantry); the middle x -1.5..1.5 stays clear"}


def end_barrier(name):
    b = Builder(name)
    cbox(b, V(0, BAR_Y, (BAR_H - 0.2) / 2), (2 * BAR_HW, BAR_D, BAR_H + 0.2), STONE, c=0.15)
    fy = BAR_Y - BAR_D / 2 - 0.03
    for k in range(15):
        if k % 2 == 0:
            xa = -12.0 + k * 1.6
            quad_y(b, xa, xa + 1.6, 0.15, 1.0, fy, CORAL, -1)
    # the sign: navy board on two posts standing in the barrier, cream inset face
    board_y, board_z, bw, bh = BAR_Y - 0.6, 3.6, 12.4, 3.6
    for x in (-4.0, 4.0):
        cbox(b, V(x, board_y + 0.45, 3.0), (0.5, 0.5, 5.0), NAVY, c=0.08)
        dome(b, V(x, board_y + 0.45, 5.5), 0.3, 0.3, 8, 2, TEAL)
    cbox(b, V(0, board_y, board_z), (bw, 0.4, bh), NAVY, c=0.12)
    cbox(b, V(0, board_y - 0.22, board_z), (bw - 0.8, 0.12, bh - 0.8), CREAM, c=0.04)
    face_y = board_y - 0.28
    return b, {"origin": "envelope centre on the ground", "barrier": {"x": [-BAR_HW, BAR_HW], "y": [BAR_Y - BAR_D / 2, BAR_Y + BAR_D / 2], "top": BAR_H},
               "sign_face": dict(rect_meta(0.0, board_z, bw - 0.88, bh - 0.88, face_y), text="COMING SOON / PREVIEW"),
               "height": 5.8}


# ---------------------------------------------------------------- tyre walls
TIRE_PROFILE = [(1.04, 0.0), (1.1, 0.08), (1.1, 0.72), (0.92, 0.8), (1.1, 0.88), (1.1, 1.52), (0.92, 1.6),
                (1.1, 1.68), (1.1, 2.32), (1.0, 2.4)]


def tire_stack(b, c, accent):
    sides = 8
    ph = math.pi / sides

    def ring_at(r, z):
        return [c + V(math.cos(ph + 2 * math.pi * k / sides) * r, math.sin(ph + 2 * math.pi * k / sides) * r, z) for k in range(sides)]

    rings = [ring_at(r, z) for r, z in TIRE_PROFILE]
    sw = [RUBBER] * (len(rings) - 1)
    sw[4] = accent
    layered(b, rings, sw, c + V(0, 0, 1.2))
    hole = ring_at(0.5, 2.36)
    floor = ring_at(0.5, 1.9)
    top = rings[-1]
    for k in range(sides):
        k2 = (k + 1) % sides
        oface(b, [top[k], top[k2], hole[k2], hole[k]], RUBBER, c + V(0, 0, 1.2))
        tface(b, [hole[k], hole[k2], floor[k2], floor[k]], "black", c + V(0, 0, 2.1))
    oface(b, floor, "black", c + V(0, 0, 1.0))


def tire_row(name):
    b = Builder(name)
    x0 = -(TIRE_STACKS - 1) * TIRE_PITCH / 2
    for k in range(TIRE_STACKS):
        tire_stack(b, V(x0 + k * TIRE_PITCH, 0, 0), CORAL if k % 2 == 0 else CREAM)
    return b, {"origin": "row centre on the ground", "stacks": TIRE_STACKS, "pitch": TIRE_PITCH, "tyre": [2.2, 0.8],
               "height": 2.4, "length": round(TIRE_STACKS * TIRE_PITCH, 3), "note": "stacks along local x; symmetric, either way round"}


# ---------------------------------------------------------------- loop sculpture
LOOP_R, RIB_W, RIB_T, RAIL_H, RAIL_W, LANE = 5.6, 2.4, 0.35, 0.45, 0.2, 1.25
PLINTH_L, PLINTH_W, PLINTH_TOP = 16.0, 5.0, 1.0


def track_sweep(b, path):
    hw, t, rh, rw = RIB_W / 2, RIB_T, RAIL_H, RAIL_W
    prof = [(-hw, -t), (hw, -t), (hw, rh), (hw - rw, rh), (hw - rw, 0), (-hw + rw, 0), (-hw + rw, rh), (-hw, rh)]
    sws = [NAVY, NAVY, CREAM, CREAM, TEAL, CREAM, CREAM, NAVY]
    n = len(path)
    frames = []
    for i in range(n):
        if i == 0:
            T = path[1] - path[0]
        elif i == n - 1:
            T = path[-1] - path[-2]
        else:
            T = (path[i + 1] - path[i]).normalized() + (path[i] - path[i - 1]).normalized()
        T = T.normalized()
        Y = V(0, 1, 0) - T * T.y
        Y.normalize()
        N = T.cross(Y)
        frames.append((T, Y, N))
    rings = [[p + Y * u + N * v for u, v in prof] for p, (T, Y, N) in zip(path, frames)]
    for i in range(n - 1):
        Ya, Na = frames[i][1], frames[i][2]
        for k in range(len(prof)):
            k2 = (k + 1) % len(prof)
            du, dv = prof[k2][0] - prof[k][0], prof[k2][1] - prof[k][1]
            out = (Ya * dv - Na * du).normalized()
            pts = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            cen = sum(pts, V(0, 0, 0)) / 4
            oface(b, pts, sws[k], cen - out)
    # end caps: the slab and the two rails as convex pieces
    for i, sgn in ((0, 1), (n - 1, -1)):
        T, Y, N = frames[i]
        p = path[i]
        for poly in ([(-hw, -t), (hw, -t), (hw, 0), (-hw, 0)], [(hw - rw, 0), (hw, 0), (hw, rh), (hw - rw, rh)],
                     [(-hw, 0), (-hw + rw, 0), (-hw + rw, rh), (-hw, rh)]):
            pts = [p + Y * u + N * v for u, v in poly]
            cen = sum(pts, V(0, 0, 0)) / 4
            oface(b, pts, NAVY, cen + T * sgn)


def loop_sculpture(name):
    b = Builder(name)
    cbox(b, V(0, 0, (PLINTH_TOP - 0.2) / 2), (PLINTH_L, PLINTH_W, PLINTH_TOP + 0.2), STONE, c=0.15)
    z0 = PLINTH_TOP + RIB_T
    cz = z0 + LOOP_R
    seg = 28
    path = [V(-7.6, -LANE, z0)]
    for i in range(seg + 1):
        phi = 2 * math.pi * i / seg
        t = i / seg
        sm = t * t * (3 - 2 * t)
        path.append(V(LOOP_R * math.sin(phi), -LANE + 2 * LANE * sm, cz - LOOP_R * math.cos(phi)))
    path.append(V(7.6, LANE, z0))
    track_sweep(b, path)
    # two side posts with arms to the underside at mid height
    for s in (-1, 1):
        y = s * (-LANE + 2 * LANE * 0.15625)
        x = s * (LOOP_R + RIB_T + 0.35)
        cyl(b, V(x, y, PLINTH_TOP - 0.05), 0.35, 0.42, 8, CREAM)
        cyl(b, V(x, y, PLINTH_TOP + 0.3), cz - PLINTH_TOP - 0.05, 0.28, 8, NAVY)
        cbox(b, V(s * (LOOP_R + RIB_T + 0.15), y, cz), (0.5, 0.5, 0.6), NAVY, c=0.08)
    top = cz + LOOP_R + RIB_T
    return b, {"origin": "plinth footprint centre on the ground", "front": "-y (the loop is seen face-on from -y)",
               "plinth": [PLINTH_L, PLINTH_W, PLINTH_TOP], "loop_centre": [0.0, 0.0, round(cz, 3)], "loop_radius": LOOP_R,
               "ribbon": {"width": RIB_W, "thickness": RIB_T, "rails": RAIL_H, "lane_offset": 2 * LANE}, "height": round(top, 3)}


# ---------------------------------------------------------------- podium
def seg_digit(b, n, cx, zc, dh, y):
    dw, st = 0.56 * dh, 0.17 * dh
    hy = 0.06

    def seg(x, z, w, h):
        pbox(b, V(x, y - hy / 2, z), (w, hy, h), NAVY)

    if n == 1:
        seg(cx + 0.05 * dh, zc, st, dh)
        seg(cx - 0.12 * dh, zc + dh / 2 - st * 0.8, 0.22 * dh, st)
        seg(cx + 0.05 * dh, zc - dh / 2 + st / 2, 0.5 * dh, st)
        return
    a, d, g = (cx, zc + dh / 2 - st / 2), (cx, zc - dh / 2 + st / 2), (cx, zc)
    for x, z in (a, d, g):
        seg(x, z, dw, st)
    right_up, right_dn = (cx + dw / 2 - st / 2, zc + dh / 4), (cx + dw / 2 - st / 2, zc - dh / 4)
    left_dn = (cx - dw / 2 + st / 2, zc - dh / 4)
    verticals = [right_up, left_dn] if n == 2 else [right_up, right_dn]
    for x, z in verticals:
        seg(x, z, st, dh / 2)


def podium(name):
    b = Builder(name)
    cbox(b, V(0, 0, 0.1), (7.8, 3.6, 0.5), STONE, c=0.12)
    steps = [(-2.4, 2.4, 2, "fish_silver"), (0.0, 3.2, 1, "brass"), (2.4, 1.8, 3, "bark_streak")]
    plates = []
    for x, h, n, plate_sw in steps:
        cbox(b, V(x, 0, (0.35 + h - 0.2) / 2), (2.4, 3.0, h - 0.2 - 0.35), NAVY, c=0.12)
        cbox(b, V(x, 0, h - 0.1), (2.4, 3.1, 0.2), CREAM, c=0.06)
        ph = min(1.2, h - 0.2 - 0.35 - 0.2)
        pz = 0.35 + (h - 0.2 - 0.35) / 2
        cbox(b, V(x, -1.5 - 0.02, pz), (1.6, 0.12, ph), plate_sw, c=0.03)
        fy = -1.5 - 0.02 - 0.06
        seg_digit(b, n, x, pz, ph - 0.22, fy)
        plates.append({"place": n, "step_top": h, **rect_meta(x, pz, 1.6, ph, fy)})
    return b, {"origin": "footprint centre on the ground", "front": "-y", "footprint": [7.8, 3.6], "height": 3.2,
               "order_left_to_right": [2, 1, 3], "plates": plates,
               "note": "numerals are relief (navy on silver / gold / bronze plates); plate rects allow a decal instead"}


# ---------------------------------------------------------------- preview boards
def preview_board(name):
    b = Builder(name)
    zc = PB_Z0 + PB_H / 2
    for x in (-2.6, 2.6):
        cbox(b, V(x, 0.45, -0.05), (0.8, 0.8, 0.5), STONE, c=0.08)
        cbox(b, V(x, 0.45, 2.95), (0.45, 0.45, 5.9), NAVY, c=0.07)
    cbox(b, V(0, 0, zc), (PB_W, PB_T, PB_H), NAVY, c=0.12)
    hdr_h = 1.0
    hz = PB_Z0 + PB_H - 0.25 - hdr_h / 2
    body_h = PB_H - 0.5 - hdr_h - 0.1
    bz = PB_Z0 + 0.25 + body_h / 2
    cbox(b, V(0, -PB_T / 2, hz), (PB_W - 0.5, 0.1, hdr_h), TEAL, c=0.03)
    cbox(b, V(0, -PB_T / 2, bz), (PB_W - 0.5, 0.1, body_h), CREAM, c=0.03)
    fy = -PB_T / 2 - 0.05
    return b, {"origin": "board centre plane, on the ground", "board": [PB_W, PB_T, PB_H], "bottom": PB_Z0, "height": PB_Z0 + PB_H,
               "header_face": rect_meta(0.0, hz, PB_W - 0.56, hdr_h - 0.06, fy),
               "body_face": rect_meta(0.0, bz, PB_W - 0.56, body_h - 0.06, fy),
               "posts_x": [-2.6, 2.6], "posts_y": 0.45}


# ---------------------------------------------------------------- leaderboard
LB_HW, LB_FACE_HW, LB_FACE_Z0, LB_FACE_Z1, LB_HDR_Z0 = 9.0, 8.0, 1.4, 13.4, 10.35
LB_FACE_Y = -0.5
CREST_Z0, CREST_Z1, CREST_W, CREST_FRONT = 13.4, 15.0, 4.4, -0.65
EMBLEM_Z = 14.2


def leaderboard(name):
    b = Builder(name)
    cbox(b, V(0, 0.2, 0.2), (2 * LB_HW, 3.6, 0.8), STONE, c=0.15)
    for s in (-1, 1):
        cbox(b, V(s * 8.4, 0, (0.6 + 14.1) / 2), (0.8, 1.3, 14.1 - 0.6), NAVY, c=0.12)
    cbox(b, V(0, 0, 1.0), (17.6, 1.0, 0.8), NAVY, c=0.1)
    cbox(b, V(0, 0, 13.75), (17.6, 1.1, 0.7), NAVY, c=0.1)
    cbox(b, V(0, 0.1, (1.3 + 13.5) / 2), (16.2, 0.4, 12.2), NAVY, c=0.06)
    rows_h = LB_HDR_Z0 - 0.2 - LB_FACE_Z0
    cbox(b, V(0, LB_FACE_Y + 0.1, LB_FACE_Z0 + rows_h / 2), (2 * LB_FACE_HW, 0.2, rows_h), CREAM, c=0.03)
    cbox(b, V(0, LB_FACE_Y + 0.11, LB_HDR_Z0 - 0.1), (2 * LB_FACE_HW, 0.22, 0.2), NAVY, c=0.03)
    hdr_h = LB_FACE_Z1 - LB_HDR_Z0
    cbox(b, V(0, LB_FACE_Y + 0.1, LB_HDR_Z0 + hdr_h / 2), (2 * LB_FACE_HW, 0.2, hdr_h), TEAL, c=0.03)
    # a checkered band on the top rail, broken by the crest
    checker_y(b, -8.0, 32, 0.5, 13.5, 1, -0.55 - 0.03, -1, skip=lambda xc: abs(xc) < CREST_W / 2 + 0.1)
    # the crest: a rounded navy tab rising to 15 that carries the swappable emblem
    prof = rrect(CREST_W, CREST_Z1 - CREST_Z0, 0.7, 0.05, seg=3, cz=(CREST_Z0 + CREST_Z1) / 2)
    prof_in = rrect(CREST_W - 0.16, CREST_Z1 - CREST_Z0 - 0.16, 0.62, 0.05, seg=3, cz=(CREST_Z0 + CREST_Z1) / 2)
    layered(b, [at_y(prof, 0.35), at_y(prof, CREST_FRONT + 0.08), at_y(prof_in, CREST_FRONT)], [NAVY, TEAL],
            V(0, -0.1, (CREST_Z0 + CREST_Z1) / 2), cap_first=NAVY, cap_last=NAVY)
    # two back braces down to the plinth
    for x in (-6.0, 6.0):
        sweep(b, [V(x, 0.3, 11.0), V(x, 1.7, 0.55)], 0.22, 6, NAVY)
    rows_top = LB_HDR_Z0 - 0.2
    return b, {
        "origin": "footprint centre on the ground", "front": "-y", "envelope": [18.0, 4.0, 15.0], "height": CREST_Z1,
        "display_face": rect_meta(0.0, (LB_FACE_Z0 + LB_FACE_Z1) / 2, 2 * LB_FACE_HW - 0.06, LB_FACE_Z1 - LB_FACE_Z0, LB_FACE_Y),
        "header_face": dict(rect_meta(0.0, LB_HDR_Z0 + hdr_h / 2, 2 * LB_FACE_HW - 0.06, hdr_h - 0.06, LB_FACE_Y), caps=2.6),
        "rows_face": dict(rect_meta(0.0, LB_FACE_Z0 + (rows_top - LB_FACE_Z0) / 2, 2 * LB_FACE_HW - 0.06, rows_top - LB_FACE_Z0 - 0.06, LB_FACE_Y),
                          rows=10, row_pitch=round((rows_top - LB_FACE_Z0) / 10, 3), caps=0.7),
        "emblem_mount": [0.0, CREST_FRONT, EMBLEM_Z], "emblem_max": [3.0, 1.4],
        "note": "face rects: centre (x, z), size (w, h), on the plane y = plane_y; put an emblem's origin at emblem_mount",
    }


def extrude(b, pts2, y0, y1, sw, edge=None):
    """A prism from a convex xz outline, front face at y0 (the more negative)."""
    layered(b, [at_y(pts2, y1), at_y(pts2, y0)], [edge or sw], V(sum(p[0] for p in pts2) / len(pts2), (y0 + y1) / 2,
            sum(p[1] for p in pts2) / len(pts2)), cap_first=edge or sw, cap_last=sw)


def circle2(cx, cz, r, n):
    return [(cx + math.cos(2 * math.pi * k / n) * r, cz + math.sin(2 * math.pi * k / n) * r) for k in range(n)]


def emblem_car(name):
    b = Builder(name)
    extrude(b, rrect(2.6, 0.62, 0.26, 0.18, seg=2, cz=-0.1), -0.22, 0.02, "brass")
    extrude(b, rrect(1.4, 0.5, 0.22, 0.02, seg=2, cx=-0.12, cz=0.37), -0.22, 0.02, "brass")
    extrude(b, rrect(1.0, 0.28, 0.12, 0.02, seg=2, cx=-0.12, cz=0.37), -0.26, -0.2, CREAM)
    for x in (-0.78, 0.78):
        extrude(b, circle2(x, -0.32, 0.3, 10), -0.28, 0.02, "black")
        extrude(b, circle2(x, -0.32, 0.12, 8), -0.32, -0.26, CREAM)
    return b, {"origin": "crest mount point (back plane centre)", "size": [2.6, 0.32, 1.24], "front_plane_y": -0.32,
               "note": "a generic toy car, no real model"}


def emblem_stopwatch(name):
    b = Builder(name)
    cz = -0.12
    extrude(b, circle2(0, cz, 0.55, 14), -0.22, 0.02, "brass")
    extrude(b, circle2(0, cz, 0.43, 14), -0.26, -0.2, CREAM)
    extrude(b, [(-0.09, 0.42), (0.09, 0.42), (0.09, 0.58), (-0.09, 0.58)], -0.2, 0.0, "brass")
    extrude(b, [(-0.2, 0.58), (0.2, 0.58), (0.2, 0.72), (-0.2, 0.72)], -0.22, 0.02, "brass")
    # one hand at about two o'clock and a centre cap
    a = math.radians(55)
    ux, uz = math.cos(a), math.sin(a)
    px, pz = -uz * 0.045, ux * 0.045
    extrude(b, [(px, cz + pz), (ux * 0.34 + px, cz + uz * 0.34 + pz), (ux * 0.34 - px, cz + uz * 0.34 - pz), (-px, cz - pz)], -0.3, -0.25, NAVY)
    extrude(b, circle2(0, cz, 0.07, 8), -0.32, -0.25, NAVY)
    return b, {"origin": "crest mount point (back plane centre)", "size": [1.1, 0.32, 1.39], "front_plane_y": -0.32}


def build_all(emit):
    P = "stunt/"
    emit(*gantry("StuntGantry"), P + "Gantry")
    emit(*light_housing("StuntStartLightHousing"), P + "Lights")
    emit(*light_lens("StuntStartLightLens"), P + "Lights")
    emit(*apron("StuntApron"), P + "Apron")
    emit(*grid_markings("StuntGridMarkings"), P + "Apron")
    emit(*end_barrier("StuntEndBarrier"), P + "Apron")
    emit(*tire_row("StuntTireRow"), P + "Apron")
    emit(*loop_sculpture("StuntLoop"), P + "Decor")
    emit(*podium("StuntPodium"), P + "Decor")
    emit(*preview_board("StuntPreviewBoard"), P + "Boards")
    emit(*leaderboard("LeaderboardFrame"), P + "Leaderboard")
    emit(*emblem_car("LeaderboardEmblemCar"), P + "Leaderboard")
    emit(*emblem_stopwatch("LeaderboardEmblemStopwatch"), P + "Leaderboard")
