# Island kit: the Stunt Circuit entrance and the leaderboard frame (Lane 3, Task 4, production pass
# after the concept review), in the kit's smooth faceted language: cream / light stone, navy / teal
# structure, chamfered edges, red / white curb accents.
#
# Stunt Circuit entrance: envelope 37 (x) x 40 (y), front faces -y (toward the fountain), ground z 0.
# Meshes modelled in ENVELOPE coordinates (origin = envelope centre on the ground):
#   StuntGantry        two pillars (shaft 3.5 x 3.5 above z 3, clear span 22) on widened cream
#                      bases (below z 3) carrying the sloped YOUR BEST / WEEKLY TOP consoles; beam
#                      4 deep, underside 10, top 18, gantry centre line y = -17.
#   StuntApron         the asphalt apron (22 wide) from the envelope front to the end pedestal.
#   StuntGridMarkings  separate thin paint: start-line checker and three grid boxes facing +y.
#   StuntEndBarrier    the closed end: a stone pedestal (top 4.4) carrying the loop, with the
#                      COMING SOON bezel on its front, and low curb rails to the tyre walls.
# Meshes with their own origin (placed by meta "layout" on StuntGantry):
#   StuntStartLightHousing / StuntStartLightLens   5 each; the lens is dark (inlay_off) when off.
#   StuntTireRow       four stacks of three tyres along local x (5 used along the apron sides).
#   StuntLoop          the loop-the-loop, origin at the pedestal top centre; loop in the local xz plane,
#                      placed on the closed-end pedestal on the axis, face-on to the gantry and plaza.
#   StuntPodium        the 1/2/3 podium with a trophy on the gold step.
#   StuntCone          a traffic cone (4 used at the apron mouth).
#   StuntFlag          a checkered flag on a pole, cloth toward +x (2 used, the left one turned 180).
#   StuntSignFace*     thin text faces (separate parts, review M19): Lettering (front and back),
#                      Board (YOUR BEST, WEEKLY TOP), ComingSoon. The text side is local -y.
# Leaderboard (envelope 18 x 4 x 15, front -y, ground z 0; sign spec revision 2):
#   LeaderboardFrame      sculpted base and legs to 3.5, the 18 x 11 board body (3.5..14.5), braces,
#                         blank back panel, a trophy between the legs, lamp arms and housing.
#   LeaderboardTextFace   the 18 x 11 thin text face (the SurfaceGui part).
#   LeaderboardCapRail    the 18 x 0.5 cap rail (14.5..15), neutral swatch for the accent colour.
#   LeaderboardLampLens   the lamp's lens strip (Neon from Luau), one SpotLight point in the meta.
# Meta points are in Blender mesh-local axes (x right, y back, z up, front faces -y), relative to
# the mesh origin. Roblox mesh-local is (x, z, -y): Blender -y is Roblox local +Z, so a text side
# modelled at -y is the part's BACK face (SurfaceGui Face = Back) unless the part is turned 180.
# A MeshPart is centred on its bounds; subtract the bounds centre from the manifest when placing.
# Placements: rot_z then rot_x in degrees (Blender, right-handed); in Roblox the same angles:
# CFrame.Angles(0, rad(rot_z), 0) * CFrame.Angles(rad(rot_x), 0, 0).

import math

from mathutils import Matrix, Vector

from kit_plot import pbox
from kit_portal import at_y, ball, cbox, cyl, layered, oface, rrect, sweep, tface
from kitlib import Builder

NAVY, TEAL, CREAM, STONE = "navy", "teal", "cream", "stone_light"
ASPHALT, RUBBER, LENS_OFF = "steel", "raccoon_dark", "inlay_off"
RED, WHITE, YELLOW, ORANGE = "cart_red", "cart_white", "awning_yellow", "fruit_orange"


def V(x, y, z):
    return Vector((x, y, z))


def r3(v):
    return [round(c, 3) for c in v]


def quad_y(b, x0, x1, z0, z1, y, sw, facing=-1):
    """A flat quad on the plane y, its normal along facing * y."""
    oface(b, [V(x0, y, z0), V(x1, y, z0), V(x1, y, z1), V(x0, y, z1)], sw, V((x0 + x1) / 2, y - facing, (z0 + z1) / 2))


def quad_x(b, y0, y1, z0, z1, x, sw, facing):
    oface(b, [V(x, y0, z0), V(x, y1, z0), V(x, y1, z1), V(x, y0, z1)], sw, V(x - facing, (y0 + y1) / 2, (z0 + z1) / 2))


def quad_z(b, x0, x1, y0, y1, z, sw):
    """A flat upward-facing quad at height z."""
    oface(b, [V(x0, y0, z), V(x1, y0, z), V(x1, y1, z), V(x0, y1, z)], sw, V((x0 + x1) / 2, (y0 + y1) / 2, z - 1))


def checker_y(b, x0, cols, sq, z0, rows, y, facing, sw_a="black", sw_b=WHITE):
    for row in range(rows):
        for k in range(cols):
            xa = x0 + k * sq
            quad_y(b, xa, xa + sq, z0 + row * sq, z0 + (row + 1) * sq, y, sw_a if (row + k) % 2 == 0 else sw_b, facing)


def xbox(b, centre, size, swatch, rot_x=0.0):
    """A plain box turned about x by rot_x degrees (for the sloped console parts)."""
    m = Matrix.Rotation(math.radians(rot_x), 3, "X")
    c = Vector(centre)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    P = {(sx, sy, sz): c + m @ V(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)}
    for axis in range(3):
        for s in (-1, 1):
            pts = []
            for t, u in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                k = [0, 0, 0]
                k[axis] = s
                k[(axis + 1) % 3] = t
                k[(axis + 2) % 3] = u
                pts.append(P[tuple(k)])
            oface(b, pts, swatch, c)


def prism_x(b, prof, x0, x1, sw, bevel=0.0, cap_sw=None):
    """A convex (y, z) outline extruded from x0 to x1, with optional bevelled ends."""
    cy = sum(p[0] for p in prof) / len(prof)
    cz = sum(p[1] for p in prof) / len(prof)

    def ring(x, inset):
        out = []
        for y, z in prof:
            d = Vector((y - cy, z - cz))
            k = max(0.0, 1 - inset / max(d.length, 1e-6))
            out.append(V(x, cy + d.x * k, cz + d.y * k))
        return out

    if bevel:
        layers = [ring(x0, bevel * 1.4), ring(x0 + bevel, 0), ring(x1 - bevel, 0), ring(x1, bevel * 1.4)]
        sws = [sw, sw, sw]
    else:
        layers = [ring(x0, 0), ring(x1, 0)]
        sws = [sw]
    layered(b, layers, sws, V((x0 + x1) / 2, cy, cz), cap_first=cap_sw or sw, cap_last=cap_sw or sw)


def extrude(b, pts2, y0, y1, sw, edge=None):
    """A prism from a convex xz outline, front face at y0 (the more negative)."""
    layered(b, [at_y(pts2, y1), at_y(pts2, y0)], [edge or sw], V(sum(p[0] for p in pts2) / len(pts2), (y0 + y1) / 2,
            sum(p[1] for p in pts2) / len(pts2)), cap_first=edge or sw, cap_last=sw)


def lathe(b, base, rings_rz, sides, sw, cap_top=True):
    base = Vector(base)
    layers = [[base + V(math.cos(2 * math.pi * k / sides) * r, math.sin(2 * math.pi * k / sides) * r, z) for k in range(sides)] for r, z in rings_rz]
    inside = base + V(0, 0, sum(z for _, z in rings_rz) / len(rings_rz))
    layered(b, layers, [sw] * (len(layers) - 1), inside, cap_last=sw if cap_top else None)


def trophy(b, base, k=1.0):
    """A small brass cup on a navy foot; height 1.35 * k."""
    base = Vector(base)
    cbox(b, base + V(0, 0, 0.125 * k), (0.9 * k, 0.9 * k, 0.25 * k), NAVY, c=0.04 * k)
    cyl(b, base + V(0, 0, 0.25 * k), 0.35 * k, 0.13 * k, 8, "brass")
    lathe(b, base, [(0.12 * k, 0.58 * k), (0.42 * k, 0.85 * k), (0.53 * k, 1.12 * k), (0.5 * k, 1.35 * k)], 10, "brass")
    for s in (-1, 1):
        sweep(b, [base + V(s * 0.47 * k, 0, 1.25 * k), base + V(s * 0.72 * k, 0, 1.18 * k), base + V(s * 0.76 * k, 0, 1.0 * k),
                  base + V(s * 0.55 * k, 0, 0.86 * k)], 0.055 * k, 5, "brass")
    return round(1.35 * k, 3)


def face_slab(name, w, h, sw, note):
    """A thin text face: its bounding front face (local -y) is exactly the w x h text rectangle."""
    b = Builder(name)
    pbox(b, V(0, 0, 0), (w, FACE_T, h), sw)
    return b, {"origin": "slab centre", "size": [w, FACE_T, h], "text_side": "-y (Roblox local +Z: SurfaceGui Face = Back)",
               "text_plane_local_y": -FACE_T / 2, "note": note}


# ---------------------------------------------------------------- envelope and gantry numbers
FACE_T = 0.06
FRONT_Y = -20.0
GY = -17.0
SPAN, PIL, BEAM_D, BEAM_Z0, BEAM_Z1 = 22.0, 3.5, 4.0, 10.0, 18.0
PX0 = SPAN / 2
PX1 = PX0 + PIL
PCX = (PX0 + PX1) / 2
BEAM_FRONT = GY - BEAM_D / 2
BEAM_BACK = GY + BEAM_D / 2

SHAFT_Z0 = 3.0
BAND_H = 0.8
BASE_X1 = 18.3
BASE_PROF = [(-19.95, -0.2), (-14.6, -0.2), (-14.6, SHAFT_Z0), (-18.85, SHAFT_Z0), (-19.95, 0.5)]
SLOPE_A, SLOPE_B = Vector((-19.95, 0.5)), Vector((-18.85, SHAFT_Z0))
SLOPE_U = (SLOPE_B - SLOPE_A).normalized()
SLOPE_N = Vector((-SLOPE_U.y, SLOPE_U.x))  # outward (toward -y, up)
SLOPE_MID = (SLOPE_A + SLOPE_B) / 2
SLOPE_ROT_X = -math.degrees(math.asin(SLOPE_U.x))  # local z -> slope direction
BOARD_FACE_W, BOARD_FACE_H, BEZEL_T = 6.0, 2.3, 0.08
BOARD_X = PX0 + 0.65 + BOARD_FACE_W / 2

LIGHT_W, LIGHT_H, LIGHT_D, LIGHT_PITCH, LIGHT_Z, LIGHT_EMBED = 1.6, 2.4, 1.2, 2.6, 12.4, 0.5
LIGHT_Y = BEAM_FRONT + LIGHT_EMBED - LIGHT_D / 2
LIGHT_XS = [(i - 2) * LIGHT_PITCH for i in range(5)]
LAMP_DZ, LAMP_R = 0.55, 0.5
LENS_BACK_Y = -LIGHT_D / 2 - 0.06
LENS_APEX_Y = LENS_BACK_Y - 0.14

LET_W, LET_H, LET_Z = 27.0, 3.6, 15.8
LET_FRAME_T = 0.3

APRON_TOP = 0.2
PED_Y0, PED_Y1, PED_HW, PED_TOP = 14.2, 19.8, 8.0, 4.4
PED_YC = (PED_Y0 + PED_Y1) / 2
CS_W, CS_H, CS_Z = 10.0, 3.4, 2.3
SLOTS = [(-5.0, -5.0), (5.0, 3.0), (-5.0, 11.0)]

TIRE_PITCH, TIRE_STACKS = 2.3, 4
TIRE_X = PX0 + 1.2
TIRE_ROWS = [(TIRE_X, -9.6), (TIRE_X, -0.4), (TIRE_X, 8.8), (-TIRE_X, -9.6), (-TIRE_X, 8.8)]

PODIUM_AT, PODIUM_ROT = (-15.4, -0.4), 90.0
CONES = [(-9.4, -19.3), (9.4, -19.3), (-9.4, -13.4), (9.4, -13.4)]
FLAGS = [(9.6, 17.0, 0.0), (-9.6, 17.0, 180.0)]


def red_white_band(b, cx, cy, z0, half=PIL / 2, segs=4):
    """A curb band round a square shaft: flat quads on the four faces, alternating red / white."""
    z1 = z0 + BAND_H
    w = 2 * half / segs
    for k in range(segs):
        a, c = -half + k * w, -half + (k + 1) * w
        sw = RED if k % 2 == 0 else WHITE
        quad_y(b, cx + a, cx + c, z0, z1, cy - half, sw, -1)
        quad_y(b, cx - c, cx - a, z0, z1, cy + half, sw, 1)
        quad_x(b, cy - c, cy - a, z0, z1, cx + half, sw, 1)
        quad_x(b, cy + a, cy + c, z0, z1, cx - half, sw, -1)


def bolt(b, cx, cz, y_front, mirror=1):
    """A small lightning bolt in relief (two convex pieces), 1.0 x 2.2."""
    up = [(-0.5, -0.05), (0.15, -0.05), (0.5, 1.1), (-0.05, 1.1)]
    dn = [(-0.15, 0.25), (0.5, 0.25), (-0.4, -1.1)]
    for poly in (up, dn):
        pts = [(cx + mirror * x, cz + z) for x, z in poly]
        if mirror < 0:
            pts.reverse()
        extrude(b, pts, y_front, y_front + 0.16, YELLOW)


def gantry(name):
    b = Builder(name)
    boards = []
    for s in (-1, 1):
        x = s * PCX
        # widened cream base below z 3 (x 11..18.3): a navy kick, the stone body with a sloped console
        xa, xb = (PX0, BASE_X1) if s > 0 else (-BASE_X1, -PX0)
        # the kick stands 0.03 back from the inner face (no coplanar caps, nothing in the span)
        prism_x(b, [(-20.0, -0.2), (-14.55, -0.2), (-14.55, 0.35), (-20.0, 0.35)], xa + 0.03 * s, xb + 0.03 * s, NAVY)
        prism_x(b, BASE_PROF, xa, xb, STONE, bevel=0.12)
        bx = s * BOARD_X
        bez_c = SLOPE_MID + SLOPE_N * (BEZEL_T / 2)
        xbox(b, V(bx, bez_c.x, bez_c.y), (BOARD_FACE_W + 0.6, BEZEL_T, (SLOPE_B - SLOPE_A).length - 0.15), NAVY, SLOPE_ROT_X)
        fc = SLOPE_MID + SLOPE_N * (BEZEL_T + FACE_T / 2)
        boards.append((bx, fc))
        # shaft above 3 stays exactly 3.5 x 3.5: curb band, navy shaft, curb collar under the beam
        red_white_band(b, x, GY, SHAFT_Z0)
        cbox(b, V(x, GY, (SHAFT_Z0 + BAND_H + 9.2) / 2), (PIL, PIL, 9.2 - SHAFT_Z0 - BAND_H), NAVY, c=0.2)
        red_white_band(b, x, GY, 9.2)
        # yellow chevrons on the inner (track) face, pointing into the circuit (+y)
        xf = s * (PX0 - 0.02)
        for zc in (4.9, 6.5, 8.1):
            for arm in (1, -1):
                yz = [(GY - 0.75, zc + arm * 0.65), (GY - 0.15, zc + arm * 0.65), (GY + 0.85, zc), (GY + 0.25, zc)]
                oface(b, [V(xf, y, z) for y, z in yz], YELLOW, V(x, GY, zc))
    # the beam sits on the pillars: x -14.5..14.5, y -19..-15, z 10..18
    # the body stops at 17.8 under the cream coping (17.7..18), so no face is coplanar with the top
    cbox(b, V(0, GY, (BEAM_Z0 + 17.8) / 2), (2 * PX1, BEAM_D, 17.8 - BEAM_Z0), NAVY, c=0.3)
    cbox(b, V(0, GY, 17.85), (2 * PX1 + 0.1, BEAM_D + 0.1, 0.3), CREAM, c=0.08)
    for yy in (BEAM_FRONT, BEAM_BACK):
        cbox(b, V(0, yy, 10.45), (2 * PX1 - 0.4, 0.3, 0.5), CREAM, c=0.08)
        # yellow rule frame round each lettering face
        cbox(b, V(0, yy + (-0.05 if yy < GY else 0.05), LET_Z), (LET_W + 0.4, LET_FRAME_T, LET_H + 0.4), YELLOW, c=0.06)
    # front: teal light bar, a lightning bolt either side, 1-stud checker flanks
    cbox(b, V(0, BEAM_FRONT, 12.375), (14.0, 0.3, 2.75), TEAL, c=0.08)
    for s in (-1, 1):
        bolt(b, s * 7.8, 12.4, BEAM_FRONT - 0.14, s)
        checker_y(b, 8.6 if s > 0 else -13.6, 5, 1.0, 11.4, 2, BEAM_FRONT - 0.03, -1)
    checker_y(b, -13.0, 26, 1.0, 10.9, 2, BEAM_BACK + 0.03, 1)

    let_front = BEAM_FRONT - 0.05 - LET_FRAME_T / 2
    let_back = BEAM_BACK + 0.05 + LET_FRAME_T / 2
    lights = []
    for i, x in enumerate(LIGHT_XS):
        lights.append({"index": i + 1, "housing_centre": r3((x, LIGHT_Y, LIGHT_Z)),
                       "lens_centres": [r3((x, LIGHT_Y + LENS_APEX_Y, LIGHT_Z + LAMP_DZ)), r3((x, LIGHT_Y + LENS_APEX_Y, LIGHT_Z - LAMP_DZ))]})
    P = []

    def put(mesh, at, rot_z=0.0, rot_x=0.0, **kw):
        d = {"mesh": mesh, "at": r3(at), "rot_z": rot_z}
        if rot_x:
            d["rot_x"] = round(rot_x, 3)
        d.update(kw)
        P.append(d)

    for m in ("StuntGantry", "StuntApron", "StuntGridMarkings", "StuntEndBarrier"):
        put(m, (0, 0, 0))
    for x in LIGHT_XS:
        put("StuntStartLightHousing", (x, LIGHT_Y, LIGHT_Z))
        put("StuntStartLightLens", (x, LIGHT_Y, LIGHT_Z))
    for x, y in TIRE_ROWS:
        put("StuntTireRow", (x, y, 0), 90.0)
    put("StuntLoop", (LOOP_AT[0], LOOP_AT[1], LOOP_Z), LOOP_ROT, note="on the closed-end pedestal, on the axis, face-on to the gantry and the plaza")
    put("StuntPodium", (PODIUM_AT[0], PODIUM_AT[1], 0), PODIUM_ROT, note="faces the apron (+x); gap in the left tyre wall")
    for x, y in CONES:
        put("StuntCone", (x, y, APRON_TOP), 0.0)
    for x, y, rz in FLAGS:
        put("StuntFlag", (x, y, 0), rz)
    faces = {}
    put("StuntSignFaceLettering", (0, let_front - FACE_T / 2, LET_Z), 0.0, text="STUNT CIRCUIT (front)")
    put("StuntSignFaceLettering", (0, let_back + FACE_T / 2, LET_Z), 180.0, text="STUNT CIRCUIT (back)")
    faces["lettering_front"] = {"centre": r3((0, let_front - FACE_T, LET_Z)), "size": [LET_W, LET_H], "normal": [0, -1, 0]}
    faces["lettering_back"] = {"centre": r3((0, let_back + FACE_T, LET_Z)), "size": [LET_W, LET_H], "normal": [0, 1, 0]}
    for (bx, fc), label in zip(boards, ("YOUR BEST", "WEEKLY TOP")):
        put("StuntSignFaceBoard", (bx, fc.x, fc.y), 0.0, SLOPE_ROT_X, text=label)
        front = fc + SLOPE_N * (FACE_T / 2)
        faces[label] = {"centre": r3((bx, front.x, front.y)), "size": [BOARD_FACE_W, BOARD_FACE_H],
                        "normal": r3((0, SLOPE_N.x, SLOPE_N.y)), "tilt_from_vertical_deg": round(-SLOPE_ROT_X, 2)}
    cs_y = PED_Y0 - 0.12 - FACE_T / 2
    put("StuntSignFaceComingSoon", (0, cs_y, CS_Z), 0.0, text="COMING SOON / PREVIEW")
    faces["COMING SOON"] = {"centre": r3((0, cs_y - FACE_T / 2, CS_Z)), "size": [CS_W, CS_H], "normal": [0, -1, 0]}
    return b, {
        "origin": "envelope centre on the ground (envelope x -18.5..18.5, y -20..20, front -y)",
        "gantry": {"centre_y": GY, "clear_span": SPAN, "pillar_inner_x": PX0, "pillar_outer_x": PX1,
                   "shaft": {"size": [PIL, PIL], "y": [GY - PIL / 2, GY + PIL / 2], "z": [SHAFT_Z0, BEAM_Z0]},
                   "base": {"x": [PX0, BASE_X1], "y": [-20.0, -14.55], "top": SHAFT_Z0, "note": "widened below z 3 only, both sides mirrored"},
                   "beam": {"x": [-PX1, PX1], "y": [BEAM_FRONT, BEAM_BACK], "underside": BEAM_Z0, "top": BEAM_Z1},
                   "proud_of_faces": "lettering frames 0.35, soffit bands and light bar 0.15, chevrons 0.02 (inner faces), bolts 0.14, lights to y -19.9"},
        "text_faces": faces, "lights": lights, "lamp_diameter": 2 * LAMP_R,
        "lightning": "relief bolts on the beam at x +/-7.8 (between the light bar and the checker); none in the lettering texture",
        "layout": {"placements": P, "note": "positions in this mesh's local axes (envelope coords); a placement is the mesh origin"},
        "note": "text_faces: centre = the centre of the text plane (the SignFace part's outer face), normal = the side the text reads from",
    }


# ---------------------------------------------------------------- start lights
def light_housing(name):
    b = Builder(name)
    hy = LIGHT_D / 2

    def prof(inset):
        return rrect(LIGHT_W - 2 * inset, LIGHT_H - 2 * inset, max(0.06, 0.34 - inset), max(0.06, 0.34 - inset), seg=2)

    layers = [at_y(prof(0.0), hy), at_y(prof(0.0), -hy + 0.09), at_y(prof(0.09), -hy)]
    layered(b, layers, ["black", "metal"], V(0, 0, 0), cap_first="black", cap_last="black")
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
        layered(b, [back, mid], [LENS_OFF], V(0, LENS_BACK_Y - 0.03, z), cap_first=LENS_OFF)
        apex = V(0, LENS_APEX_Y, z)
        for k in range(sides):
            oface(b, [mid[k], mid[(k + 1) % sides], apex], LENS_OFF, V(0, LENS_BACK_Y, z))
    return b, {"origin": "housing centre (same CFrame as StuntStartLightHousing)", "lamp_centres": [[0.0, round(LENS_APEX_Y, 3), LAMP_DZ], [0.0, round(LENS_APEX_Y, 3), -LAMP_DZ]],
               "diameter": 2 * LAMP_R, "swatch_off": LENS_OFF, "lit": "clear TextureID, Material Neon, Color red",
               "note": "both lamps of one housing light together; lights fill one by one, hold, all off, long pause; steady and unlit under Reduce Motion"}


# ---------------------------------------------------------------- apron and paint
def apron(name):
    b = Builder(name)
    y0, y1 = FRONT_Y, PED_Y0
    cbox(b, V(0, (y0 + y1) / 2, -0.05), (SPAN, y1 - y0, 0.5), ASPHALT, c=0.12)
    n = 17
    L = (y1 - y0) / n
    top = APRON_TOP + 0.06
    for s in (-1, 1):
        xa, xb = s * (PX0 - 1.0), s * (PX0 - 0.12)
        lo, hi = min(xa, xb), max(xa, xb)
        for k in range(n):
            ya, yb = y0 + k * L, y0 + (k + 1) * L
            sw = RED if k % 2 == 0 else WHITE
            quad_z(b, lo, hi, ya, yb, top, sw)
            for xx in (xa, xb):
                oface(b, [V(xx, ya, APRON_TOP), V(xx, yb, APRON_TOP), V(xx, yb, top), V(xx, ya, top)], sw,
                      V((xa + xb) / 2, (ya + yb) / 2, top / 2))
    return b, {"origin": "envelope centre on the ground", "x": [-PX0, PX0], "y": [y0, y1], "top": APRON_TOP, "sink": 0.3,
               "kerb": {"width": 0.88, "top": round(top, 3)}}


def grid_markings(name):
    b = Builder(name)
    z = APRON_TOP + 0.04
    for row in range(2):
        for k in range(20):
            quad_z(b, -10 + k, -9 + k, GY - 1 + row, GY + row, z, "black" if (row + k) % 2 == 0 else WHITE)
    boxes = []
    for cx, yf in SLOTS:
        # front bar at the +y end, two short legs back toward the plaza: cars face into the circuit
        pbox(b, V(cx, yf - 0.2, z - 0.025), (7.0, 0.4, 0.05), WHITE)
        for sx in (-1, 1):
            pbox(b, V(cx + sx * 3.3, yf - 0.4 - 1.3, z - 0.025), (0.4, 2.6, 0.05), WHITE)
        boxes.append({"centre_x": cx, "front_y": yf, "width": 7.0, "legs": 2.6})
    return b, {"origin": "envelope centre on the ground", "paint_top": round(z, 3), "start_line": {"x": [-10, 10], "y": [GY - 1, GY + 1]},
               "grid_boxes": boxes, "car_facing": "+y (into the circuit), matching the pillar chevrons; the middle x -1.5..1.5 stays clear"}


def end_barrier(name):
    b = Builder(name)
    d = PED_Y1 - PED_Y0
    cbox(b, V(0, PED_YC, 0.1), (2 * PED_HW + 0.1, d + 0.1, 0.6), NAVY, c=0.1)
    cbox(b, V(0, PED_YC, (0.4 + PED_TOP - 0.25) / 2), (2 * PED_HW, d, PED_TOP - 0.25 - 0.4), STONE, c=0.18)
    cbox(b, V(0, PED_YC, PED_TOP - 0.125), (2 * PED_HW + 0.1, d + 0.1, 0.25), CREAM, c=0.06)
    # navy bezel for the COMING SOON face
    cbox(b, V(0, PED_Y0 - 0.06, CS_Z), (CS_W + 0.6, 0.12, CS_H + 0.4), NAVY, c=0.04)
    # low curb rails from the pedestal to the tyre walls
    for s in (-1, 1):
        x0, x1 = PED_HW, PX0 + 0.2
        cx = s * (x0 + x1) / 2
        cbox(b, V(cx, PED_Y0 + 0.7, 0.5), (x1 - x0, 1.4, 1.4), STONE, c=0.12)
        w = (x1 - x0) / 4
        for k in range(4):
            xa = s * (x0 + k * w)
            xb = s * (x0 + (k + 1) * w)
            quad_y(b, min(xa, xb), max(xa, xb), 0.2, 1.0, PED_Y0 - 0.02, RED if k % 2 == 0 else WHITE, -1)
    return b, {"origin": "envelope centre on the ground",
               "pedestal": {"x": [-PED_HW, PED_HW], "y": [PED_Y0, PED_Y1], "top": PED_TOP, "loop_seat": [0.0, PED_YC, PED_TOP]},
               "rails": {"x": [PED_HW, PX0 + 0.2], "y": [PED_Y0, PED_Y0 + 1.4], "top": 1.2}, "height": PED_TOP,
               "note": "the COMING SOON text face is StuntSignFaceComingSoon (see StuntGantry text_faces)"}


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
        tire_stack(b, V(x0 + k * TIRE_PITCH, 0, 0), RED if k % 2 == 0 else WHITE)
    return b, {"origin": "row centre on the ground", "stacks": TIRE_STACKS, "pitch": TIRE_PITCH, "tyre": [2.2, 0.8],
               "height": 2.4, "length": round(TIRE_STACKS * TIRE_PITCH, 3), "note": "stacks along local x; symmetric, either way round"}


# ---------------------------------------------------------------- loop sculpture
LOOP_R, RIB_W, RIB_T, RAIL_H, RAIL_W, LANE = 3.9, 2.4, 0.35, 0.45, 0.2, 1.25
LOOP_HALF = 7.6
# on the closed-end pedestal, on the axis, face-on to the gantry and the plaza (sightline-clear)
LOOP_AT, LOOP_Z, LOOP_ROT = (0.0, PED_YC), PED_TOP, 0.0


def track_sweep(b, path):
    hw, t, rh, rw = RIB_W / 2, RIB_T, RAIL_H, RAIL_W
    prof = [(-hw, -t), (hw, -t), (hw, rh), (hw - rw, rh), (hw - rw, 0), (-hw + rw, 0), (-hw + rw, rh), (-hw, rh)]
    sws = [NAVY, NAVY, "coral", "coral", TEAL, "coral", "coral", NAVY]
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
        frames.append((T, Y, T.cross(Y)))
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
    pz = 0.0
    z0 = pz + RIB_T
    cz = z0 + LOOP_R
    seg = 26
    path = [V(-LOOP_HALF, -LANE, z0)]
    for i in range(seg + 1):
        phi = 2 * math.pi * i / seg
        t = i / seg
        sm = t * t * (3 - 2 * t)
        path.append(V(LOOP_R * math.sin(phi), -LANE + 2 * LANE * sm, cz - LOOP_R * math.cos(phi)))
    path.append(V(LOOP_HALF, LANE, z0))
    track_sweep(b, path)
    for s in (-1, 1):
        y = s * (-LANE + 2 * LANE * 0.15625)
        x = s * (LOOP_R + RIB_T + 0.35)
        cyl(b, V(x, y, pz - 0.05), 0.35, 0.42, 8, CREAM)
        cyl(b, V(x, y, pz + 0.3), cz - pz - 0.05, 0.28, 8, NAVY)
        cbox(b, V(s * (LOOP_R + RIB_T + 0.15), y, cz), (0.5, 0.5, 0.6), NAVY, c=0.08)
    top = cz + LOOP_R + RIB_T
    # a fixed scale car upside down at the top of the loop (meta only, no car mesh)
    seat = (0.0, 0.0, round(cz + LOOP_R, 3))
    return b, {"origin": "pedestal top centre (the track underside rests on z 0)", "front": "-y (face-on to the gantry and the plaza)",
               "loop_centre": [0.0, 0.0, round(cz, 3)], "loop_radius": LOOP_R, "height": round(top, 3),
               "ribbon": {"width": RIB_W, "thickness": RIB_T, "rails": RAIL_H, "inner_width": round(RIB_W - 2 * RAIL_W, 3), "lane_offset": 2 * LANE},
               "car_seat": {"position": list(seat), "up": [0, 0, -1], "forward": [-1, 0, 0], "scale": 0.3,
                            "envelope_position": [LOOP_AT[0], LOOP_AT[1], round(LOOP_Z + seat[2], 3)], "envelope_forward": [-1, 0, 0],
                            "note": "local axes; envelope_* are after the placement (on the pedestal, rot_z 0). A 13 x 6 x 4.5 car at scale 0.3 (3.9 x 1.8 x 1.35) fits the 2.0 between the rails, wheels on the driving surface at the top; any angle phi: position = (R sin phi, y, cz - R cos phi), up = toward the loop centre"}}


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
    for x, z in ([right_up, left_dn] if n == 2 else [right_up, right_dn]):
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
        plates.append({"place": n, "step_top": h, "centre": [x, round(pz, 3)], "size": [1.6, round(ph, 3)], "plane_y": round(fy, 3)})
    th = trophy(b, V(0, 0.75, 3.2))
    return b, {"origin": "footprint centre on the ground", "front": "-y", "footprint": [7.8, 3.6], "height": round(3.2 + th, 3),
               "order_left_to_right": [2, 1, 3], "plates": plates, "trophy": {"base": [0.0, 0.75, 3.2], "height": th},
               "stand_point_first": [0.0, -0.5, 3.2],
               "note": "numerals are relief (navy on silver / gold / bronze plates); the trophy stands at the back of the gold step"}


# ---------------------------------------------------------------- cones and flags
def cone(name):
    b = Builder(name)
    cbox(b, V(0, 0, 0.075), (1.3, 1.3, 0.15), ORANGE, c=0.05)
    lathe(b, V(0, 0, 0), [(0.58, 0.15), (0.45, 0.75)], 8, ORANGE, cap_top=False)
    lathe(b, V(0, 0, 0), [(0.45, 0.75), (0.34, 1.2)], 8, WHITE, cap_top=False)
    lathe(b, V(0, 0, 0), [(0.34, 1.2), (0.14, 1.85), (0.1, 1.9)], 8, ORANGE)
    return b, {"origin": "base centre on the apron top", "height": 1.9}


def flag(name):
    b = Builder(name)
    cbox(b, V(0, 0, 0.1), (0.9, 0.9, 0.6), STONE, c=0.08)
    cyl(b, V(0, 0, 0.4), 9.4, 0.12, 8, WHITE, r_top=0.09)
    ball(b, V(0, 0, 9.92), 0.16, 8, 4, "brass")
    sq, cols, rows, z0 = 0.75, 4, 3, 7.4
    for r in range(rows):
        for k in range(cols):
            xa, za = 0.15 + k * sq, z0 + r * sq
            b.face2([V(xa, 0, za), V(xa + sq, 0, za), V(xa + sq, 0, za + sq), V(xa, 0, za + sq)], "black" if (r + k) % 2 == 0 else WHITE)
    return b, {"origin": "pole foot on the ground", "height": 10.08, "cloth": {"x": [0.15, 0.15 + cols * sq], "z": [z0, z0 + rows * sq]},
               "note": "checkered cloth toward +x (two-sided); turn 180 for the left flag"}


# ---------------------------------------------------------------- leaderboard (sign spec revision 2)
LB_FACE_Z0, LB_FACE_Z1 = 3.5, 14.5
LB_BODY_D = 0.8
LB_FACE_CY = -LB_BODY_D / 2 - FACE_T / 2
LB_LIGHT = (0.0, -1.45, 14.5)


def leaderboard(name):
    b = Builder(name)
    # sculpted base: navy kick, stone plinth, a top step (0..1)
    cbox(b, V(0, 0.1, 0.05), (17.8, 3.6, 0.5), NAVY, c=0.1)
    cbox(b, V(0, 0.1, 0.525), (17.4, 3.3, 0.45), STONE, c=0.12)
    cbox(b, V(0, 0.1, 0.875), (15.6, 2.7, 0.25), STONE, c=0.08)
    # two tapered legs 1..3.5 with cream collars
    for s in (-1, 1):
        x = s * 6.0
        lo = [V(x + a * 0.8, b_ * 0.7, 1.0) for a, b_ in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        hi = [V(x + a * 0.6, b_ * 0.4, LB_FACE_Z0 + 0.05) for a, b_ in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        layered(b, [lo, hi], [NAVY], V(x, 0, 2.2))
        cbox(b, V(x, 0, 1.15), (1.9, 1.7, 0.3), CREAM, c=0.06)
    # a small trophy on a navy block between the legs
    cbox(b, V(0, 0, 1.3), (2.4, 1.6, 0.6), NAVY, c=0.08)
    th = trophy(b, V(0, 0, 1.6), 1.2)
    # the board body 18 x 11 (3.5..14.5), blank cream back panel, two back braces
    cbox(b, V(0, 0, (LB_FACE_Z0 + LB_FACE_Z1) / 2), (18.0, LB_BODY_D, LB_FACE_Z1 - LB_FACE_Z0), NAVY, c=0.12)
    cbox(b, V(0, LB_BODY_D / 2 + 0.02, 9.0), (16.0, 0.1, 9.0), CREAM, c=0.03)
    for x in (-6.0, 6.0):
        sweep(b, [V(x, LB_BODY_D / 2 + 0.1, 11.0), V(x, 1.5, 1.0)], 0.34, 6, NAVY)
    # lamp: two short arms from the cap rail front and a slim housing over the top edge
    for x in (-3.5, 3.5):
        cbox(b, V(x, -0.85, 14.75), (0.3, 0.8, 0.3), NAVY, c=0.05)
    cbox(b, V(0, -1.45, 14.78), (9.0, 0.5, 0.4), NAVY, c=0.08)
    face_front = LB_FACE_CY - FACE_T / 2
    top = LB_FACE_Z1
    canvas = {"ppstud": 50, "px": [900, 550], "header": [0.0, 2.25], "label_row": [2.25, 2.8], "rows_from": 2.84, "row_pitch": 0.8, "rows": 10}
    aim = Vector((0, face_front, (LB_FACE_Z0 + LB_FACE_Z1) / 2)) - Vector(LB_LIGHT)
    return b, {
        "origin": "footprint centre on the ground", "front": "-y", "envelope": [18.0, 4.0, 15.0], "height": 15.0,
        "layout": [{"mesh": "LeaderboardFrame", "at": [0, 0, 0]},
                   {"mesh": "LeaderboardTextFace", "at": r3((0, LB_FACE_CY, (LB_FACE_Z0 + LB_FACE_Z1) / 2))},
                   {"mesh": "LeaderboardCapRail", "at": [0.0, 0.0, 14.75]},
                   {"mesh": "LeaderboardLampLens", "at": [0, 0, 0]}],
        "text_face": {"centre": r3((0, face_front, (LB_FACE_Z0 + LB_FACE_Z1) / 2)), "size": [18.0, 11.0], "normal": [0, -1, 0],
                      "z": [LB_FACE_Z0, LB_FACE_Z1], "canvas": canvas,
                      "note": "studs measured down from the face top z 14.5: header 0..2.25, label row 2.25..2.8, rows from 2.84 at 0.8"},
        "cap_rail": {"z": [14.5, 15.0], "accent": {"cars": "#D9503F", "stunt": "#F7CE58"}},
        "light": {"position": list(LB_LIGHT), "direction": r3(aim.normalized()), "type": "SpotLight", "note": "subtle; face brightness only"},
        "trophy": {"base": [0.0, 0.0, 1.6], "height": th},
        "back_panel": {"centre": [0.0, round(LB_BODY_D / 2 + 0.07, 3), 9.0], "size": [16.0, 9.0], "note": "decorative, no text"},
    }


def lb_cap_rail(name):
    b = Builder(name)
    cbox(b, V(0, 0, 0), (18.0, 1.0, 0.5), "accent_neutral", c=0.1)
    return b, {"origin": "rail centre", "z": [14.5, 15.0], "note": "clear TextureID and set Color: #D9503F (cars), #F7CE58 (stunt)"}


def lb_lamp_lens(name):
    b = Builder(name)
    prism_x(b, [(-1.66, 14.58), (-1.24, 14.58), (-1.3, 14.5), (-1.62, 14.52)], -4.3, 4.3, "lamp_glass")
    return b, {"origin": "frame origin (place at the frame CFrame)", "light": list(LB_LIGHT), "note": "Neon from Luau; angled down toward the face"}


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
    emit(*cone("StuntCone"), P + "Decor")
    emit(*flag("StuntFlag"), P + "Decor")
    emit(*face_slab("StuntSignFaceLettering", LET_W, LET_H, NAVY, "STUNT CIRCUIT, yellow on navy texture; front and back placements"), P + "SignFaces")
    emit(*face_slab("StuntSignFaceBoard", BOARD_FACE_W, BOARD_FACE_H, NAVY, "YOUR BEST / WEEKLY TOP, tilted with the console (rot_x)"), P + "SignFaces")
    emit(*face_slab("StuntSignFaceComingSoon", CS_W, CS_H, CREAM, "COMING SOON / PREVIEW on the pedestal front"), P + "SignFaces")
    emit(*leaderboard("LeaderboardFrame"), P + "Leaderboard")
    emit(*face_slab("LeaderboardTextFace", 18.0, 11.0, NAVY, "the leaderboard SurfaceGui part, PixelsPerStud 50, canvas 900 x 550"), P + "Leaderboard")
    emit(*lb_cap_rail("LeaderboardCapRail"), P + "Leaderboard")
    emit(*lb_lamp_lens("LeaderboardLampLens"), P + "Leaderboard")
