# Island kit: the Garage (Lane 3, Task 4, Adam's brief section 9), a two-volume rebuild of the
# greybox block, in the kit's smooth faceted language (cream / light stone walls, navy / teal
# structure, chamfered edges, no studs). PRODUCTION pass after the independent concept review
# (concept-review.md: B3, M1, M2, M3, M19, L2 to L8) and the lead's decisions.
#
# Envelope (task4-layout.js): footprint 62 (x) by 40 (y), centred on the mesh origin, front faces
# -y (the fountain), ground line z 0, nothing above 34. The forecourt (14 deep, y -34 to -20) lies
# in front of the envelope and only holds small prop meshes (the lead reserves that zone).
#
# Massing: a LOWER workshop volume on the -x side (parapet 21.5) and a TALLER showroom volume
# (eaves 26) with upper windows, joined by one full-width canopy with the checkered band. An
# entrance pylon at the front-right corner (stepped crown to 30.6) frames the showroom entrance
# and carries the wrench-and-tyre crest (top 32.7). GARAGE sits on a 38 x 8.8 red-orange face as a
# parapet sign over the workshop volume.
#
# Building meshes share ONE origin (the footprint centre on the ground), so the Luau side places
# them with one CFrame; every point in GarageShell's meta is in that garage-local frame:
#   GarageShell       cream / stone walls, piers, pylon, pilasters, plinth, steps
#   GarageStructure   navy / teal canopy, copings, roof decks, frames, rails, windows, downpipes
#   GarageGlazing     showroom and entrance glass only (one glass swatch)
#   GarageInterior    floors, ceilings, stage, counter, interior trims
#   GarageLights      every light-emitting face (one swatch)
#   GarageSign        navy board with the blank red-orange face and back struts
#   CheckeredBand     two rows of 1.0 squares on the canopy fascia
#   ForecourtCurb     restrained red / white kerb blocks along the forecourt edge
# Placed pieces have their own origin (stated per mesh); GarageShell meta gives each placement.
# No car meshes: the Luau side seats Brian L's car models at the recorded seat points.
# Blank text faces: meta "text_faces" lists each one (centre on the face plane, size, normal and
# a thin-part CFrame suggestion), because a SurfaceGui on a MeshPart lands on its bounding box.
# Mesh-local axes: x right, y back, z up, front faces -y. Roblox mesh-local is (x, z, -y); a
# MeshPart is centred on its bounds, so subtract the bounds centre (manifest) before placing.

import math
import random

from mathutils import Vector

from kit_portal import ball, cbox, cyl, oface, sweep
from kitlib import Builder, clump

# ---------------------------------------------------------------- frame of the building
HW, HD = 31.0, 20.0
SX = 30.6  # side wall outer faces
BY = 19.4  # back wall outer face
FY = -17.0  # front wall face (wall y -17..-16)
GY = -16.0  # showroom glass plane
CANOPY_Y = -19.9
CANOPY_X1 = 19.4  # the canopy stops at the pylon
CANOPY_Z = (12.6, 15.0)
PX = (-6.6, -5.6)  # partition / showroom west wall
WS_TOP, WS_DECK, WS_CEIL = 21.5, 20.8, 15.5  # workshop parapet, roof deck, ceiling
EAVES, DECK, CEIL = 26.0, 25.0, 15.0  # showroom eaves, roof deck, ceiling
WS_FLOOR, SR_FLOOR = 0.2, 0.6
STAGE_Z, STAGE_Y = 2.6, 1.6

DOOR_W, DOOR_H = 10.0, 10.0
DOORS = {"A": -24.4, "B": -12.4}  # opening x c +/- 5, z 0.2..10.2
CURTAIN_W, CURTAIN_H, CURTAIN_T = 10.6, 10.2, 0.3
CURTAIN_Y = -15.8
HALF_OPEN = 5.0
LOAD_Y = 7.0  # loading door in the workshop LEFT wall (same curtain, closed, turned -90)

GLASS_X = (-5.2, CANOPY_X1)
TRANSOM = (10.5, 10.9)
GLASS_TOP = 12.4
SIDE_GLASS_Y = (-12.0, 14.0)

PYX = (19.4, 30.9)  # entrance pylon
PYF = -18.0  # pylon front face
PY_C = (PYX[0] + PYX[1]) / 2  # 25.15
ENTRANCE = (21.0, 29.0)
ENT_TOP = 11.4
PY_SHAFT, PY_STEP1, PY_TOP = 27.0, 28.8, 30.6
CREST_Z = 27.8  # tyre centre of the wall-mounted crest

TT_R = 8.0
TURNTABLES = [("Front", 11.5, -7.0, SR_FLOOR), ("BackLeft", 3.0, 10.2, STAGE_Z), ("BackRight", 21.0, 10.2, STAGE_Z)]
SIGN_BOARD = (-30.6, 8.6, 15.4, 25.2)  # x0, x1, z0, z1; board y -17.8..-17.0
SIGN_FACE = (-30.0, 8.0, 15.9, 24.7)
SIGN_FRONT_Y, SIGN_FACE_Y = -17.8, -17.95
LIFT = (-12.4, -3.0)
LIFT_PAD_TOP = 1.8  # half-raised pose: the car body shows through the half-open door


# ---------------------------------------------------------------- small helpers
def bx(b, x0, x1, y0, y1, z0, z1, sw):
    """A plain box from extents (12 triangles); sw may be a 6-list (bottom, top, -y, +y, -x, +x)."""
    from kitlib import box

    box(b, Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), Vector((x1 - x0, y1 - y0, z1 - z0)), sw)


def cbx(b, x0, x1, y0, y1, z0, z1, sw, c=0.12, **kw):
    cbox(b, Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), (x1 - x0, y1 - y0, z1 - z0), sw, c=c, **kw)


def fy(b, x0, x1, z0, z1, y, sw, out=-1):
    oface(b, [Vector((x0, y, z0)), Vector((x1, y, z0)), Vector((x1, y, z1)), Vector((x0, y, z1))], sw,
          Vector(((x0 + x1) / 2, y - out, (z0 + z1) / 2)))


def fx(b, y0, y1, z0, z1, x, sw, out=-1):
    oface(b, [Vector((x, y0, z0)), Vector((x, y1, z0)), Vector((x, y1, z1)), Vector((x, y0, z1))], sw,
          Vector((x - out, (y0 + y1) / 2, (z0 + z1) / 2)))


def fz(b, x0, x1, y0, y1, z, sw, out=1):
    oface(b, [Vector((x0, y0, z)), Vector((x1, y0, z)), Vector((x1, y1, z)), Vector((x0, y1, z))], sw,
          Vector(((x0 + x1) / 2, (y0 + y1) / 2, z - out)))


def onwall(b, axis, plane, out, u0, u1, z0, z1, d0, d1, sw, c=0.0):
    """A box on a wall face: u along the wall, d measured outward from the wall plane."""
    p0, p1 = sorted((plane + out * d0, plane + out * d1))
    ext = (p0, p1, u0, u1, z0, z1) if axis == "x" else (u0, u1, p0, p1, z0, z1)
    if c:
        cbx(b, *ext, sw, c=c)
    else:
        bx(b, *ext, sw)


def wall_face(b, axis, plane, out, u0, u1, z0, z1, d, sw):
    if axis == "x":
        fx(b, u0, u1, z0, z1, plane + out * d, sw, out)
    else:
        fy(b, u0, u1, z0, z1, plane + out * d, sw, out)


def window(b, axis, plane, out, uc, w, z0, z1, glass="glass_tint", frame="navy", mullion=True):
    """An applied window: tinted glass face, a navy frame, a centre mullion and a stone sill."""
    u0, u1 = uc - w / 2, uc + w / 2
    t = 0.3
    wall_face(b, axis, plane, out, u0, u1, z0, z1, 0.03, glass)
    onwall(b, axis, plane, out, u0 - t, u1 + t, z1, z1 + t, 0, 0.16, frame)
    onwall(b, axis, plane, out, u0 - t, u1 + t, z0 - t, z0, 0, 0.16, frame)
    onwall(b, axis, plane, out, u0 - t, u0, z0, z1, 0, 0.16, frame)
    onwall(b, axis, plane, out, u1, u1 + t, z0, z1, 0, 0.16, frame)
    if mullion:
        onwall(b, axis, plane, out, uc - 0.1, uc + 0.1, z0, z1, 0, 0.1, frame)
    onwall(b, axis, plane, out, u0 - 0.5, u1 + 0.5, z0 - t - 0.3, z0 - t, 0, 0.4, "stone_light")


def panel_door(b, axis, plane, out, uc, w, z0, h, sw="navy"):
    u0, u1 = uc - w / 2, uc + w / 2
    onwall(b, axis, plane, out, u0 - 0.35, u1 + 0.35, z0, z0 + h + 0.35, 0, 0.12, "stone_light")
    onwall(b, axis, plane, out, u0, u1, z0, z0 + h, 0, 0.2, sw)
    wall_face(b, axis, plane, out, uc - 0.6, uc + 0.6, z0 + h - 2.6, z0 + h - 1.0, 0.22, "glass_tint")
    hu = u1 - 0.6 if out < 0 else u0 + 0.6
    onwall(b, axis, plane, out, hu - 0.12, hu + 0.12, z0 + 3.6, z0 + 4.4, 0.2, 0.4, "steel")
    onwall(b, axis, plane, out, u0, u1, z0, z0 + 0.6, 0.2, 0.26, "steel")


def louvre(b, axis, plane, out, uc, w, z0, z1):
    onwall(b, axis, plane, out, uc - w / 2, uc + w / 2, z0, z1, 0, 0.08, "navy")
    z = z0 + 0.3
    while z < z1 - 0.2:
        onwall(b, axis, plane, out, uc - w / 2 + 0.15, uc + w / 2 - 0.15, z, z + 0.22, 0.08, 0.26, "steel")
        z += 0.55


def r3(v):
    return [round(float(c), 3) for c in v]


def prism(b, pts2, xform, y0, y1, sw, side_sw=None, caps=True):
    """Extrude a convex polygon given in (u, v) along y from y0 to y1; xform(u, v, y) -> Vector."""
    front = [xform(u, v, y0) for u, v in pts2]
    back = [xform(u, v, y1) for u, v in pts2]
    inside = sum(front + back, Vector((0, 0, 0))) / (2 * len(pts2))
    n = len(pts2)
    for k in range(n):
        k2 = (k + 1) % n
        oface(b, [front[k], front[k2], back[k2], back[k]], side_sw or sw, inside)
    if caps:
        oface(b, front, sw, inside)
        oface(b, back, sw, inside)


def annulus(b, xform, cu, cv, r_in, r_out, a0, a1, seg, y0, y1, sw, side_sw=None, closed=True):
    """A flat ring (or an arc of one) in (u, v), extruded along y; end caps when not closed."""
    pts = []
    for k in range(seg + (0 if closed else 1)):
        a = a0 + (a1 - a0) * k / seg
        pts.append(((cu + math.cos(a) * r_in, cv + math.sin(a) * r_in), (cu + math.cos(a) * r_out, cv + math.sin(a) * r_out)))
    ym = (y0 + y1) / 2
    for k in range(seg):
        k2 = (k + 1) % len(pts)
        (i1, o1), (i2, o2) = pts[k], pts[k2]
        am = a0 + (a1 - a0) * (k + 0.5) / seg
        mid_r = (r_in + r_out) / 2
        centre = xform(cu + math.cos(am) * mid_r, cv + math.sin(am) * mid_r, ym)
        for y in (y0, y1):
            oface(b, [xform(*i1, y), xform(*o1, y), xform(*o2, y), xform(*i2, y)], sw, centre + (xform(0, 0, ym) - xform(0, 0, y)))
        oface(b, [xform(*o1, y0), xform(*o2, y0), xform(*o2, y1), xform(*o1, y1)], side_sw or sw, centre)
        oface(b, [xform(*i1, y0), xform(*i2, y0), xform(*i2, y1), xform(*i1, y1)], side_sw or sw, centre)
    if not closed:
        for idx, nxt in ((0, 1), (len(pts) - 1, len(pts) - 2)):
            (i1, o1), (i2, o2) = pts[idx], pts[nxt]
            inside = xform((i1[0] + o1[0] + i2[0] + o2[0]) / 4, (i1[1] + o1[1] + i2[1] + o2[1]) / 4, ym)
            oface(b, [xform(*i1, y0), xform(*o1, y0), xform(*o1, y1), xform(*i1, y1)], side_sw or sw, inside)


def tface(b, pts, sw, toward):
    from kit_portal import tface as tf

    tf(b, pts, sw, toward)


def tyre(b, centre, axis, r_out, r_in, width, sides, tread="black", wall="wet_band", hole="black", crown=True):
    """A tyre: tread band (optionally crowned), two sidewall rings and the inner bead band."""
    axis = Vector(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    v = axis.cross(u).normalized()
    c = Vector(centre)
    h = width / 2
    bulge = width * 0.12 if crown else 0.0

    def P(r, a, t):
        return c + (u * math.cos(a) + v * math.sin(a)) * r + axis * t

    for k in range(sides):
        a, a2 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
        am = (a + a2) / 2
        if crown:
            oface(b, [P(r_out - bulge, a, -h), P(r_out - bulge, a2, -h), P(r_out, a2, 0), P(r_out, a, 0)], tread, c)
            oface(b, [P(r_out, a, 0), P(r_out, a2, 0), P(r_out - bulge, a2, h), P(r_out - bulge, a, h)], tread, c)
        else:
            oface(b, [P(r_out, a, -h), P(r_out, a2, -h), P(r_out, a2, h), P(r_out, a, h)], tread, c)
        for t in (-h, h):
            oface(b, [P(r_in, a, t), P(r_in, a2, t), P(r_out - bulge, a2, t), P(r_out - bulge, a, t)], wall, P((r_in + r_out) / 2, am, 0))
        tface(b, [P(r_in, a, -h), P(r_in, a2, -h), P(r_in, a2, h), P(r_in, a, h)], hole, c)


def clip_z(poly, z0, z1):
    """Sutherland-Hodgman clip of a convex polygon in (u, z) to z0 <= z <= z1."""
    def clip(pts, keep, inter):
        out = []
        for i in range(len(pts)):
            a, c = pts[i], pts[(i + 1) % len(pts)]
            if keep(a):
                out.append(a)
                if not keep(c):
                    out.append(inter(a, c))
            elif keep(c):
                out.append(inter(a, c))
        return out

    def at(zc):
        return lambda a, c: (a[0] + (c[0] - a[0]) * (zc - a[1]) / (c[1] - a[1]), zc)

    p = clip(poly, lambda q: q[1] >= z0, at(z0))
    return clip(p, lambda q: q[1] <= z1, at(z1)) if p else p


# ---------------------------------------------------------------- GarageShell (cream / stone)
def shell(name):
    b = Builder(name)
    W, S = "cream", "stone_light"
    # workshop front: corner pier, centre pier and the junction pier, on stone feet
    for x0, x1 in ((-30.9, -29.4), (-19.4, -17.4), (-7.4, -5.6)):
        cbx(b, x0, x1, -17.3, -16.0, 0.0, CANOPY_Z[0], W, c=0.15)
        cbx(b, max(-31.0, x0 - 0.1), x1 + 0.1, -17.45, -15.9, 0.0, 0.9, S, c=0.1)
    for c in DOORS.values():
        bx(b, c - DOOR_W / 2, c + DOOR_W / 2, FY, FY + 1, WS_FLOOR + DOOR_H, CANOPY_Z[0], W)
    # front upper walls: workshop (behind the sign) and showroom (with windows)
    bx(b, -SX, PX[1], FY, FY + 1, CANOPY_Z[0], WS_TOP - 0.2, W)
    bx(b, PX[1], PYX[0], FY, FY + 1, CANOPY_Z[0], EAVES - 0.2, W)
    # side, back and partition / west walls
    ly0, ly1 = LOAD_Y - DOOR_W / 2, LOAD_Y + DOOR_W / 2
    bx(b, -SX, -SX + 1, FY, ly0, 0, WS_TOP - 0.2, W)
    bx(b, -SX, -SX + 1, ly1, BY, 0, WS_TOP - 0.2, W)
    bx(b, -SX, -SX + 1, ly0, ly1, WS_FLOOR + DOOR_H, WS_TOP - 0.2, W)
    bx(b, PX[0], PX[1], FY, BY, 0, EAVES - 0.2, W)
    y0, y1 = SIDE_GLASS_Y
    bx(b, SX - 1, SX, FY, y0, 0, EAVES - 0.2, W)
    bx(b, SX - 1, SX, y1, BY, 0, EAVES - 0.2, W)
    bx(b, SX - 1, SX, y0, y1, GLASS_TOP, EAVES - 0.2, W)
    bx(b, SX - 1.2, SX + 0.2, y0, y1, 0, SR_FLOOR, S)
    bx(b, -SX, PX[0], BY - 1, BY, 0, WS_TOP - 0.2, W)
    bx(b, PX[0], SX, BY - 1, BY, 0, EAVES - 0.2, W)
    # showroom sill under the glass and the bulkhead behind the glass head
    bx(b, PX[1], GLASS_X[1], -16.6, -15.75, 0, SR_FLOOR, S)
    bx(b, PX[1], SX - 1, GY, -15.4, GLASS_TOP, CEIL, W)
    # entrance pylon: two piers, the shaft over the opening, a two-step crown, a doorstep
    cbx(b, PYX[0], ENTRANCE[0], PYF, -16.0, 0, ENT_TOP + 0.4, W, c=0.15)
    cbx(b, ENTRANCE[1], PYX[1], PYF, -16.0, 0, ENT_TOP + 0.4, W, c=0.15)
    for x0, x1 in ((PYX[0], ENTRANCE[0]), (ENTRANCE[1], PYX[1])):
        cbx(b, x0 - 0.1, min(31.0, x1 + 0.1), PYF - 0.15, -15.9, 0, 0.9, S, c=0.1)
    cbx(b, PYX[0], PYX[1], PYF, -15.0, ENT_TOP, PY_SHAFT, W, c=0.15)
    cbx(b, PYX[0], PYX[1], -15.0, -12.6, DECK - 0.4, PY_SHAFT, W, c=0.12)
    cbx(b, PYX[0] + 0.8, PYX[1] - 0.8, PYF + 0.2, -13.0, PY_SHAFT, PY_STEP1, S, c=0.12)
    cbx(b, PYX[0] + 1.8, PYX[1] - 1.8, PYF + 0.4, -13.4, PY_STEP1, PY_TOP, S, c=0.12)
    cbx(b, ENTRANCE[0], ENTRANCE[1], -19.4, PYF + 0.01, 0, SR_FLOOR, S, c=0.06)
    bx(b, ENTRANCE[0], ENTRANCE[1], PYF, GY, 0, SR_FLOOR, S)
    # stone plinth course round the sides and back (gap at the loading door)
    bx(b, -SX - 0.2, -SX, FY, ly0, 0, 0.7, S)
    bx(b, -SX - 0.2, -SX, ly1, BY + 0.2, 0, 0.7, S)
    bx(b, SX, SX + 0.2, -16.0, y0, 0, 0.7, S)
    bx(b, SX, SX + 0.2, y1, BY + 0.2, 0, 0.7, S)
    bx(b, -SX - 0.2, SX + 0.2, BY, BY + 0.2, 0, 0.7, S)
    # pilasters: workshop (to 21.3) and showroom (to 25.8)
    wt, st = WS_TOP - 0.2, EAVES - 0.2
    cbx(b, -30.95, -29.6, BY - 1.0, BY + 0.35, 0, wt, S, c=0.12)
    cbx(b, 29.6, 30.95, BY - 1.0, BY + 0.35, 0, st, S, c=0.12)
    for y in (-10.0, -1.0, 15.2):
        cbx(b, -SX - 0.35, -SX + 0.2, y - 0.6, y + 0.6, 0, wt, S, c=0.12)
    for y in (y0 - 0.6, y1 + 0.6):
        cbx(b, SX - 0.2, SX + 0.35, y - 0.6, y + 0.6, 0, st, S, c=0.12)
    for x, top in ((-27.4, wt), (-14.6, wt), (-6.1, st), (6.0, st), (18.0, st)):
        cbx(b, x - 0.6, x + 0.6, BY - 0.2, BY + 0.35, 0, top, S, c=0.12)
    return b


# ---------------------------------------------------------------- GarageStructure (navy / teal)
def structure(name):
    b = Builder(name)
    N, T = "navy", "teal"
    # canopy along the workshop and showroom glass: navy slab, teal fascia (checkered band on it)
    cbx(b, -30.9, CANOPY_X1, CANOPY_Y, -16.0, CANOPY_Z[0], CANOPY_Z[1], N, c=0.15, front=T)
    for x in (-30.15, -18.4, -6.5):
        y_w, y_e, zt, zb = -17.3, -19.0, CANOPY_Z[0], CANOPY_Z[0] - 1.8
        pts = [(y_w, zt), (y_e, zt), (y_w, zb)]
        front = [Vector((x - 0.2, y, z)) for y, z in pts]
        back = [Vector((x + 0.2, y, z)) for y, z in pts]
        ins = Vector((x, (y_w * 2 + y_e) / 3, (zt * 2 + zb) / 3))
        oface(b, front, N, ins)
        oface(b, back, N, ins)
        for k in range(3):
            k2 = (k + 1) % 3
            oface(b, [front[k], front[k2], back[k2], back[k]], N, ins)
    # door heads (teal), steel guide rails inside the jambs, a navy head box at the ceiling
    for c in DOORS.values():
        x0, x1, zt = c - DOOR_W / 2, c + DOOR_W / 2, WS_FLOOR + DOOR_H
        bx(b, x0 - 0.35, x1 + 0.35, -17.42, -17.28, zt, zt + 0.5, T)
        for xr in (x0 - 0.3, x1 - 0.2):
            bx(b, xr, xr + 0.5, -16.0, -15.5, WS_FLOOR, WS_CEIL, "steel")
        bx(b, x0 - 0.3, x1 + 0.3, -16.0, -15.2, WS_CEIL - 0.4, WS_CEIL, N)
    # showroom glazing frame
    gy0, gy1 = GY - 0.25, GY + 0.25
    bx(b, PX[1], GLASS_X[0], gy0, gy1, SR_FLOOR, GLASS_TOP, N)
    bx(b, PX[1], GLASS_X[1], gy0 - 0.1, gy1, GLASS_TOP, CANOPY_Z[0], N)
    bx(b, GLASS_X[0], GLASS_X[1], gy0, gy1, SR_FLOOR, SR_FLOOR + 0.2, N)
    bx(b, GLASS_X[0], GLASS_X[1], gy0, gy1, TRANSOM[0], TRANSOM[1], N)
    bx(b, 6.9, 7.3, gy0, gy1, TRANSOM[1], GLASS_TOP, N)
    # entrance: navy surround with a chrome lip on the pylon front, transom bar, patch fittings,
    # pull bars, three chrome speed lines, and a stepped-up navy hood with a teal front
    e0, e1 = ENTRANCE
    for a in ((e0 - 0.5, e0, SR_FLOOR, ENT_TOP + 0.5), (e1, e1 + 0.5, SR_FLOOR, ENT_TOP + 0.5), (e0 - 0.5, e1 + 0.5, ENT_TOP, ENT_TOP + 0.5)):
        bx(b, a[0], a[1], PYF - 0.15, PYF, a[2], a[3], N)
    for a in ((e0 - 0.05, e0 + 0.12, SR_FLOOR, ENT_TOP + 0.12), (e1 - 0.12, e1 + 0.05, SR_FLOOR, ENT_TOP + 0.12), (e0, e1, ENT_TOP - 0.12, ENT_TOP + 0.05)):
        bx(b, a[0], a[1], PYF - 0.22, PYF + 0.05, a[2], a[3], "steel")
    dy = -17.35
    bx(b, e0, e1, dy - 0.15, dy + 0.15, 10.0, 10.4, N)
    for xa, xb in ((21.05, 21.65), (24.35, 24.95), (25.05, 25.65), (28.35, 28.95)):
        for za, zb in ((SR_FLOOR + 0.1, SR_FLOOR + 0.5), (9.6, 10.0)):
            bx(b, xa, xb, dy - 0.12, dy + 0.12, za, zb, "steel")
    for x in (24.6, 25.4):
        bx(b, x - 0.07, x + 0.07, dy - 0.5, dy - 0.36, 3.6, 7.6, "steel")
        for z in (3.9, 7.3):
            bx(b, x - 0.05, x + 0.05, dy - 0.38, dy - 0.05, z - 0.05, z + 0.05, "steel")
    for z in (12.6, 13.3, 14.0):
        bx(b, PYX[0] + 0.6, PYX[1] - 0.6, PYF - 0.12, PYF, z, z + 0.2, "steel")
    cbx(b, PYX[0] + 0.6, PYX[1] - 0.4, CANOPY_Y, PYF + 0.01, 15.0, 16.4, N, c=0.12, front=T)
    # pylon glass-block slot: navy fins and glazing bars (the glow is in GarageLights)
    for x in (PY_C - 1.6, PY_C + 1.2):
        bx(b, x, x + 0.4, PYF - 0.2, PYF, 16.8, 23.2, N)
    for z in (18.4, 20.0, 21.6):
        bx(b, PY_C - 1.1, PY_C + 1.1, PYF - 0.15, PYF - 0.05, z - 0.06, z + 0.06, N)
    # side glazing frame (right wall)
    sx = SX - 0.5
    y0, y1 = SIDE_GLASS_Y
    bx(b, sx - 0.25, sx + 0.25, y0, y0 + 0.4, SR_FLOOR, GLASS_TOP, N)
    bx(b, sx - 0.25, sx + 0.25, y1 - 0.4, y1, SR_FLOOR, GLASS_TOP, N)
    bx(b, sx - 0.25, sx + 0.25, y0, y1, GLASS_TOP - 0.4, GLASS_TOP, N)
    bx(b, sx - 0.25, sx + 0.25, y0, y1, SR_FLOOR, SR_FLOOR + 0.2, N)
    bx(b, sx - 0.25, sx + 0.25, y0, y1, TRANSOM[0], TRANSOM[1], N)
    bx(b, sx - 0.25, sx + 0.25, 0.8, 1.2, TRANSOM[1], GLASS_TOP - 0.4, N)
    # roof decks in quiet grey roofing (teal only on the copings), a hatch on the workshop roof
    bx(b, -SX + 1, PX[0], FY + 1, BY - 1, WS_DECK - 0.4, WS_DECK, [N, "concrete", N, N, N, N])
    bx(b, PX[1], SX - 1, FY + 1, BY - 1, DECK - 0.4, DECK, [N, "concrete", N, N, N, N])
    cbx(b, -26.0, -23.4, 10.5, 13.1, WS_DECK, WS_DECK + 0.7, N, c=0.1, top="steel")
    # teal copings: workshop (21.5) and showroom (26)
    for a in ((-30.9, PX[1], -17.25, -15.8, WS_TOP), (-30.9, -29.4, -15.8, 19.65, WS_TOP), (-29.4, PX[0], 18.2, 19.65, WS_TOP),
              (-6.9, PYX[0], -17.25, -15.8, EAVES), (-6.9, -5.4, -15.8, 19.65, EAVES), (29.4, 30.9, -12.6, 19.65, EAVES), (-5.4, 29.4, 18.2, 19.65, EAVES)):
        cbx(b, a[0], a[1], a[2], a[3], a[4] - 0.2, a[4], T, c=0.06)
    # navy string course at the upper floor line round the sides and back
    bx(b, -SX - 0.15, -SX, FY, BY, CANOPY_Z[1], CANOPY_Z[1] + 0.7, N)
    bx(b, SX, SX + 0.15, -16.0, BY, CANOPY_Z[1], CANOPY_Z[1] + 0.7, N)
    bx(b, -SX, SX, BY, BY + 0.15, CANOPY_Z[1], CANOPY_Z[1] + 0.7, N)
    # windows: workshop upper (17.3..20.1), showroom upper (17.6..22.6), west clerestory
    for y, w in ((-13.8, 3.0), (-5.5, 4.0), (LOAD_Y, 5.0)):
        window(b, "x", -SX, -1, y, w, 17.3, 20.1)
    for y in (-9.0, 1.0, 11.0):
        window(b, "x", PX[0], -1, y, 3.2, 22.4, 24.8, mullion=False)
    for y in (-7.6, 1.0, 9.6):
        window(b, "x", SX, 1, y, 4.5, 17.6, 22.6)
    for x, w in ((-21.0, 5.0), (-9.9, 2.8)):
        window(b, "y", BY, 1, x, w, 17.3, 20.1)
    window(b, "y", BY, 1, -21.0, 5.0, 9.8, 12.6)
    for x in (0.0, 12.0, 24.1):
        window(b, "y", BY, 1, x, 5.0, 17.6, 22.6)
    for x in (11.9, 16.7):
        window(b, "y", FY, -1, x, 3.4, 17.6, 22.6)
    # ground storey: a workshop high window and louvre (left), the back service door
    window(b, "x", -SX, -1, -5.5, 4.0, 9.8, 12.6)
    louvre(b, "x", -SX, -1, -5.5, 3.4, 3.0, 6.0)
    panel_door(b, "y", BY, 1, -9.9, 3.6, 0.7, 8.6)
    louvre(b, "y", BY, 1, 12.0, 4.0, 8.8, 11.6)
    # loading area on the workshop's left side: a navy hood over the loading door
    onwall(b, "x", -SX, -1, LOAD_Y - 5.6, LOAD_Y + 5.6, 10.7, 11.3, 0, 0.4, N, c=0.06)
    # downpipes with hopper heads under the copings, a foot shoe and a drain gully at each
    for x, top in ((-29.0, WS_DECK), (-4.9, DECK), (29.0, DECK)):
        yc = BY + 0.32
        cyl(b, Vector((x, yc, 0.5)), top - 0.6 - 0.5, 0.2, 6, N)
        cbx(b, x - 0.4, x + 0.4, BY, BY + 0.6, top - 0.6, top + 0.3, N, c=0.06)
        cbx(b, x - 0.3, x + 0.3, BY + 0.2, BY + 0.55, 0.06, 0.5, N, c=0.05)
        bx(b, x - 0.45, x + 0.45, BY + 0.02, BY + 0.6, 0, 0.06, "black")
    return b


# ---------------------------------------------------------------- GarageGlazing (glass only)
def glazing(name):
    b = Builder(name)
    G = "glass"
    x0, x1 = GLASS_X
    bx(b, x0, x1, GY - 0.05, GY + 0.05, SR_FLOOR + 0.2, TRANSOM[0], G)
    bx(b, x0, x1, GY - 0.05, GY + 0.05, TRANSOM[1], GLASS_TOP, G)
    sx = SX - 0.5
    y0, y1 = SIDE_GLASS_Y
    bx(b, sx - 0.05, sx + 0.05, y0 + 0.4, y1 - 0.4, SR_FLOOR + 0.2, TRANSOM[0], G)
    bx(b, sx - 0.05, sx + 0.05, y0 + 0.4, y1 - 0.4, TRANSOM[1], GLASS_TOP - 0.4, G)
    dy = -17.35
    bx(b, ENTRANCE[0], ENTRANCE[1], dy - 0.05, dy + 0.05, SR_FLOOR + 0.1, 10.0, G)
    bx(b, ENTRANCE[0], ENTRANCE[1], dy - 0.05, dy + 0.05, 10.4, ENT_TOP, G)
    return b


# ---------------------------------------------------------------- GarageInterior
def interior(name):
    b = Builder(name)
    wx0, wx1 = -SX + 1, PX[0]
    bx(b, wx0, wx1, GY, BY - 1, 0, WS_FLOOR, "concrete")
    for c in DOORS.values():
        bx(b, c - DOOR_W / 2, c + DOOR_W / 2, -17.3, GY, 0, WS_FLOOR, "concrete")
    bx(b, -SX, -SX + 1, LOAD_Y - DOOR_W / 2, LOAD_Y + DOOR_W / 2, 0, WS_FLOOR, "concrete")
    lx, ly = LIFT
    for xa, xb, ya, yb in ((lx - 5.0, lx + 5.0, ly - 8.0, ly - 7.75), (lx - 5.0, lx + 5.0, ly + 7.75, ly + 8.0),
                           (lx - 5.0, lx - 4.75, ly - 8.0, ly + 8.0), (lx + 4.75, lx + 5.0, ly - 8.0, ly + 8.0)):
        bx(b, xa, xb, ya, yb, WS_FLOOR, WS_FLOOR + 0.02, "awning_yellow")
    fz(b, wx0, wx1, GY, BY - 1, WS_CEIL, "cream", out=-1)
    for z0, z1, sw in ((WS_FLOOR, 1.2, "navy"), (6.0, 6.5, "teal")):
        bx(b, wx0, wx1, BY - 1.2, BY - 1, z0, z1, sw)
        bx(b, wx0, wx0 + 0.2, GY, LOAD_Y - DOOR_W / 2, z0, z1, sw)
        bx(b, wx0, wx0 + 0.2, LOAD_Y + DOOR_W / 2, BY - 1.2, z0, z1, sw)
        bx(b, wx1 - 0.2, wx1, GY, BY - 1.2, z0, z1, sw)
    # showroom: tile floor (into the pylon reveal), stage, step, mats, ceiling, walls, counter
    sx0, sx1 = PX[1], SX - 1
    bx(b, sx0, sx1, -15.75, BY - 1, 0, SR_FLOOR, ["tile_grey", "tile_grey", "stone_light", "stone_light", "stone_light", "stone_light"])
    bx(b, GLASS_X[1], sx1, GY, -15.75, 0, SR_FLOOR, "tile_grey")
    cbx(b, sx0, sx1, STAGE_Y, BY - 1, SR_FLOOR - 0.01, STAGE_Z, "stone_light", c=0.1, front="teal", top="stone_light")
    cbx(b, 22.5, 28.5, STAGE_Y - 1.4, STAGE_Y, SR_FLOOR - 0.01, SR_FLOOR + 1.0, "stone_light", c=0.08, front="teal")
    bx(b, sx0, sx1, STAGE_Y - 0.6, STAGE_Y, SR_FLOOR, SR_FLOOR + 0.02, "navy")
    bx(b, ENTRANCE[0] + 0.5, ENTRANCE[1] - 0.5, -15.5, -12.0, SR_FLOOR, SR_FLOOR + 0.03, "navy")
    bx(b, ENTRANCE[0] + 0.5, ENTRANCE[1] - 0.5, -19.3, -18.1, SR_FLOOR, SR_FLOOR + 0.03, "navy")
    fz(b, sx0, sx1, -15.4, BY - 1, CEIL, "cream", out=-1)
    bx(b, sx0, sx1, BY - 1.2, BY - 1, STAGE_Z, CEIL, "teal")
    bx(b, sx0, sx1, BY - 1.25, BY - 1.2, 5.6, 6.0, "cream")
    cbx(b, 6.0, 18.0, BY - 1.45, BY - 1.2, 9.0, 13.4, "navy", c=0.06)
    for x0, x1, y0, y1 in ((sx0, sx0 + 0.2, -15.4, BY - 1.2), (sx1 - 0.2, sx1, -15.4, SIDE_GLASS_Y[0]), (sx1 - 0.2, sx1, SIDE_GLASS_Y[1], BY - 1.2)):
        bx(b, x0, x1, y0, y1, SR_FLOOR, SR_FLOOR + 0.8, "navy")
    cbx(b, -4.5, 0.5, -6.0, -3.6, SR_FLOOR, 3.5, "cream", c=0.1)
    cbx(b, -4.7, 0.7, -6.2, -3.4, 3.5, 3.8, "teal", c=0.06)
    bx(b, -4.3, 0.3, -6.05, -3.8, SR_FLOOR, SR_FLOOR + 0.4, "navy")
    return b


# ---------------------------------------------------------------- WallLight (sconce)
def wall_light(name):
    b = Builder(name)
    cbx(b, -0.3, 0.3, -0.1, 0, -0.5, 0.5, "navy", c=0.03)
    cbx(b, -0.22, 0.22, -0.38, -0.1, -0.32, 0.3, "lamp_glass", c=0.03)
    for x in (-0.24, 0.2):
        bx(b, x, x + 0.04, -0.4, -0.1, -0.34, 0.32, "navy")
    cbx(b, -0.28, 0.28, -0.4, -0.08, 0.3, 0.42, "navy", c=0.03)
    cbx(b, -0.26, 0.26, -0.4, -0.08, -0.42, -0.32, "navy", c=0.03)
    return b, {"origin": "wall mount at the lamp centre height; the lantern points -y; depth 0.4", "lamp_centre": [0.0, -0.24, 0.0],
               "note": "lamp_glass faces; a PointLight at each placement's light point"}


# ---------------------------------------------------------------- GarageLights (one light swatch)
def light_points():
    pts = {
        "workshop_front": [-24.4, -6.0, 14.9], "workshop_lift": [-12.4, -3.0, 14.9], "workshop_back": [-18.0, 12.0, 14.9],
        "showroom_entrance": [PY_C, -8.0, 14.4], "canopy_workshop": [-18.4, -18.2, 12.3], "canopy_showroom": [6.0, -18.2, 12.3],
        "entrance_hood": [PY_C, -19.0, 14.6], "pylon_slot": [PY_C, -18.8, 20.0],
    }
    for tid, x, y, _z in TURNTABLES:
        pts["showroom_" + tid] = [x, y, 14.4]
    for i, wl in enumerate(wall_light_placements()):
        x, y, z = wl["position"]
        yaw = math.radians(wl["yaw"])
        dx, dy = -math.sin(yaw) * -0.24, math.cos(yaw) * -0.24
        pts["wall_light_%d" % (i + 1)] = r3((x + dx, y + dy, z))
    return pts


def wall_light_placements():
    return [
        {"position": [20.0, PYF, 7.6], "yaw": 0, "where": "entrance, left pier"},
        {"position": [30.2, PYF, 7.6], "yaw": 0, "where": "entrance, right pier"},
        {"position": [-SX, LOAD_Y - 2.6, 12.4], "yaw": -90, "where": "loading door, front side"},
        {"position": [-SX, LOAD_Y + 2.6, 12.4], "yaw": -90, "where": "loading door, back side"},
        {"position": [-9.9, BY, 10.2], "yaw": 180, "where": "back service door"},
    ]


def lights(name):
    b = Builder(name)
    L = "light_panel"
    for x in (-24.4, -12.4):
        bx(b, x - 0.5, x + 0.5, -12.0, 14.0, WS_CEIL - 0.2, WS_CEIL, L)
    for _, x, y, _z in TURNTABLES:
        cyl(b, Vector((x, y, CEIL - 0.2)), 0.2, 3.0, 8, L, bottom=True)
    cyl(b, Vector((PY_C, -8.0, CEIL - 0.2)), 0.2, 1.6, 8, L, bottom=True)
    for x in (-24.4, -12.4, 0.0, 12.0):
        bx(b, x - 0.5, x + 0.5, -18.7, -17.7, CANOPY_Z[0] - 0.1, CANOPY_Z[0], L)
    bx(b, PX[1], SX - 1, STAGE_Y - 0.08, STAGE_Y, STAGE_Z - 0.5, STAGE_Z - 0.3, L)
    bx(b, PY_C - 1.2, PY_C + 1.2, PYF - 0.08, PYF, 16.8, 23.2, L)
    bx(b, PY_C - 0.8, PY_C + 0.8, -19.4, -18.6, 14.9, 15.0, L)
    return b


# ---------------------------------------------------------------- GarageSign (board + blank face)
def sign(name):
    b = Builder(name)
    x0, x1, z0, z1 = SIGN_BOARD
    cbx(b, x0, x1, SIGN_FRONT_Y, -17.0, z0, z1, "navy", c=0.15)
    fx0, fx1, fz0, fz1 = SIGN_FACE
    bx(b, fx0, fx1, SIGN_FACE_Y, SIGN_FRONT_Y + 0.01, fz0, fz1, "red_orange")
    t = SIGN_FRONT_Y
    for a in ((fx0 - 0.25, fx1 + 0.25, fz1 + 0.1, fz1 + 0.22), (fx0 - 0.25, fx1 + 0.25, fz0 - 0.22, fz0 - 0.1),
              (fx0 - 0.22, fx0 - 0.1, fz0 - 0.1, fz1 + 0.1), (fx1 + 0.1, fx1 + 0.22, fz0 - 0.1, fz1 + 0.1)):
        bx(b, a[0], a[1], t - 0.05, t + 0.01, a[2], a[3], "cream")
    # steel struts behind the part above the workshop roof
    for x in (-27.0, -18.0, -9.0):
        sweep(b, [Vector((x, -16.95, z1 - 0.8)), Vector((x, -12.8, WS_DECK + 0.05))], 0.16, 6, "steel")
        cbx(b, x - 0.4, x + 0.4, -13.2, -12.4, WS_DECK, WS_DECK + 0.15, "steel", c=0.04)
    return b


def bulb_positions():
    fx0, fx1, fz0, fz1 = SIGN_FACE
    xs = [-28.6 + k * (6.6 + 28.6) / 5 for k in range(6)]
    top, bot = (fz1 + SIGN_BOARD[3]) / 2, (fz0 + SIGN_BOARD[2]) / 2
    pts = [[round(x, 3), SIGN_FRONT_Y, round(top, 3)] for x in xs] + [[round(x, 3), SIGN_FRONT_Y, round(bot, 3)] for x in xs]
    mid = round((fz0 + fz1) / 2, 3)
    pts += [[round((SIGN_BOARD[0] + fx0) / 2, 3), SIGN_FRONT_Y, mid], [round((SIGN_BOARD[1] + fx1) / 2, 3), SIGN_FRONT_Y, mid]]
    return pts


# ---------------------------------------------------------------- CheckeredBand (on the fascia)
def checkered_band(name):
    b = Builder(name)
    sq, rows = 1.0, 2
    x0, x1 = -30.6, CANOPY_X1
    cols = int(round((x1 - x0) / sq))
    yf, yb = -19.98, CANOPY_Y + 0.005
    z0 = CANOPY_Z[0] + 0.2
    for r in range(rows):
        for k in range(cols):
            xa = x0 + k * sq
            fy(b, xa, xa + sq, z0 + r * sq, z0 + (r + 1) * sq, yf, "black" if (r + k) % 2 == 0 else "cream")
    zt = z0 + rows * sq
    fz(b, x0, x1, yf, yb, zt, "navy", out=1)
    fz(b, x0, x1, yf, yb, z0, "navy", out=-1)
    fx(b, yf, yb, z0, zt, x0, "navy", out=-1)
    fx(b, yf, yb, z0, zt, x1, "navy", out=1)
    return b, {"squares": sq, "rows": rows, "columns": cols, "x": [x0, x1], "z": [round(z0, 3), round(zt, 3)], "front_y": yf,
               "note": "garage-local; 1.0 squares to avoid shimmer at distance (check in Play)"}


# ---------------------------------------------------------------- ForecourtCurb (garage-local)
CURB_FRONT_Y = -27.7  # forecourt edge, 8 in front of the envelope front (the forecourt walk starts at -29)
# kerb only where no door or entrance approach crosses: the showroom glass front and the two corners
CURB_RUNS = [("x", -7.4, ENTRANCE[0], CURB_FRONT_Y), ("x", -31.0, -29.6, CURB_FRONT_Y), ("x", 29.2, 31.0, CURB_FRONT_Y),
             ("y", -27.4, -20.4, -30.7), ("y", -27.4, -20.4, 30.7)]


def forecourt_curb(name):
    b = Builder(name)
    h, d = 0.35, 0.6
    for axis, a0, a1, c in CURB_RUNS:
        n = max(1, int(round((a1 - a0) / 2.0)))
        step = (a1 - a0) / n
        for k in range(n):
            u0, u1 = a0 + k * step, a0 + (k + 1) * step
            sw = "bunting_red" if k % 2 == 0 else "cart_white"
            if axis == "x":
                bx(b, u0 + 0.02, u1 - 0.02, c - d / 2, c + d / 2, 0, h, sw)
            else:
                bx(b, c - d / 2, c + d / 2, u0 + 0.02, u1 - 0.02, 0, h, sw)
    return b, {"origin": "garage-local", "height": h, "front_line_y": CURB_FRONT_Y,
               "runs": [{"axis": a, "from": a0, "to": a1, "at": c} for a, a0, a1, c in CURB_RUNS],
               "note": "red / white blocks along the forecourt edge only; none across the door A / B or entrance approach lines"}


# ---------------------------------------------------------------- RollUpDoor (used three times)
def rollup_door(name):
    b = Builder(name)
    w, h, t = CURTAIN_W, CURTAIN_H, CURTAIN_T
    hx, hy = w / 2, t / 2
    bar = 0.3
    n = 15
    sh = (h - bar) / n
    for i in range(n):
        za = bar + i * sh
        zb = za + sh
        g = 0.12
        fy(b, -hx, hx, za + g, zb, -hy, "teal")
        oface(b, [Vector((-hx, -hy + 0.07, za)), Vector((hx, -hy + 0.07, za)), Vector((hx, -hy, za + g)), Vector((-hx, -hy, za + g))],
              "teal_dark", Vector((0, 1, za)))
    za = bar + 9 * sh
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        fy(b, x - 0.65, x + 0.65, za + 0.2, za + sh - 0.08, -hy - 0.02, "lamp_glass")
    fy(b, -hx, hx, bar, h, hy, "teal", out=1)
    fx(b, -hy, hy, bar, h, -hx, "teal_dark", out=-1)
    fx(b, -hy, hy, bar, h, hx, "teal_dark", out=1)
    fz(b, -hx, hx, -hy, hy, h, "teal_dark", out=1)
    cbx(b, -hx, hx, -hy - 0.05, hy + 0.05, 0, bar, "steel", c=0.05)
    bx(b, -0.7, 0.7, -hy - 0.3, -hy - 0.16, 0.95, 1.15, "steel")
    for x in (-0.6, 0.6):
        bx(b, x - 0.06, x + 0.06, -hy - 0.18, -hy, 0.99, 1.11, "steel")
    return b, {
        "origin": "bottom centre of the curtain (mid-plane)", "size": [w, h, t], "slats": n,
        "travel_axis": "z (straight up, behind the head wall)", "closed_bottom_z": WS_FLOOR,
        "half_open_travel": HALF_OPEN, "max_travel": round(WS_CEIL - (WS_FLOOR + h) - 0.05, 3),
    }


# ---------------------------------------------------------------- HazardStrip (door jambs)
HZ_W, HZ_H, HZ_T = 0.6, 9.3, 0.06


def hazard_strip(name):
    b = Builder(name)
    p = 0.6  # stripe pitch along z, 45 degree stripes
    y = -HZ_T
    k = -2
    while k * p < HZ_H + p:
        c0, c1 = k * p, (k + 1) * p
        poly = [(-HZ_W / 2, c0), (HZ_W / 2, c0 + HZ_W), (HZ_W / 2, c1 + HZ_W), (-HZ_W / 2, c1)]
        poly = clip_z(poly, 0.0, HZ_H)
        if len(poly) >= 3:
            oface(b, [Vector((u, y, z)) for u, z in poly], "awning_yellow" if k % 2 == 0 else "black", Vector((0, 1, HZ_H / 2)))
        k += 1
    fx(b, y, 0, 0, HZ_H, -HZ_W / 2, "black", out=-1)
    fx(b, y, 0, 0, HZ_H, HZ_W / 2, "black", out=1)
    fz(b, -HZ_W / 2, HZ_W / 2, y, 0, HZ_H, "black", out=1)
    return b, {"origin": "bottom centre on the wall plane; front -y", "size": [HZ_W, HZ_H, HZ_T], "stripes": "45 degrees, 0.6 pitch, yellow / black"}


def hazard_placements():
    out = []
    for c in DOORS.values():
        for x in (c - DOOR_W / 2 - HZ_W / 2, c + DOOR_W / 2 + HZ_W / 2):
            out.append({"position": [round(x, 3), -17.3, 0.9], "yaw": 0})
    for y in (LOAD_Y - DOOR_W / 2 - HZ_W / 2, LOAD_Y + DOOR_W / 2 + HZ_W / 2):
        out.append({"position": [-SX, round(y, 3), 0.9], "yaw": -90})
    return out


# ---------------------------------------------------------------- CarLift (two-post)
LIFT_POST_X = 4.2


def car_lift(name):
    b = Builder(name)
    for s in (-1, 1):
        x = s * LIFT_POST_X
        cbx(b, x - 0.9, x + 0.9, -0.9, 0.9, 0, 0.15, "steel", c=0.04)
        cbx(b, x - 0.45, x + 0.45, -0.45, 0.45, 0.15, 12.0, "navy", c=0.08)
        cbx(b, x - 0.47, x + 0.47, -0.47, 0.47, 0.15, 0.8, "awning_yellow", c=0.08)
        cbx(b, x - 0.65, x + 0.65, -0.65, 0.65, 0.9, 2.3, "red_orange", c=0.1)
        for yy in (-3.0, 3.0):
            px = s * 2.1
            sweep(b, [Vector((x - s * 0.6, yy * 0.12, 1.5)), Vector((px, yy, 1.5))], 0.16, 6, "steel")
            cyl(b, Vector((px, yy, 1.35)), 0.25, 0.36, 8, "steel", top_sw="black")
            cyl(b, Vector((px, yy, 1.6)), LIFT_PAD_TOP - 1.6, 0.32, 8, "black")
    cbx(b, -LIFT_POST_X - 0.5, LIFT_POST_X + 0.5, -0.5, 0.5, 12.0, 12.6, "navy", c=0.08)
    sweep(b, [Vector((-LIFT_POST_X + 0.45, -0.3, 11.5)), Vector((LIFT_POST_X - 0.45, -0.3, 11.5))], 0.08, 6, "awning_yellow")
    cbx(b, -LIFT_POST_X - 1.25, -LIFT_POST_X - 0.45, -0.55, 0.55, 5.0, 6.6, "red_orange", c=0.08)
    cyl(b, Vector((-LIFT_POST_X - 1.27, -0.2, 6.0)), 0.08, 0.14, 8, "cart_white", axis=Vector((-1, 0, 0)))
    cyl(b, Vector((-LIFT_POST_X - 0.85, 0, 6.6)), 0.8, 0.22, 8, "steel")
    return b, {
        "origin": "lift centre on the floor (between the posts)", "posts_x": [-LIFT_POST_X, LIFT_POST_X],
        "car_rest": [0.0, 0.0, LIFT_PAD_TOP], "car_axis": "y (nose toward -y, the door)",
        "pads": [[s * 2.1, yy, LIFT_PAD_TOP] for s in (-1, 1) for yy in (-3.0, 3.0)], "height": 12.6,
        "note": "half-raised pose: car_rest is where the car body's underside (sills) sits",
    }


# ---------------------------------------------------------------- ToolWall (large silhouettes)
def tool_wall(name):
    b = Builder(name)
    hw = 4.0
    bx(b, -hw, hw, -2.0, 0, 0, 3.1, "cart_red")
    bx(b, -hw - 0.1, hw + 0.1, -2.2, 0, 3.1, 3.4, "bench_wood")
    for x in (-2.0, 2.0):
        bx(b, x - 1.0, x + 1.0, -2.1, -2.0, 2.0, 2.2, "steel")
    bx(b, -0.03, 0.03, -2.04, -2.0, 0.2, 3.0, "plank_dark")
    # light grey pegboard with a navy frame and a lamp strip on top
    bx(b, -hw, hw, -0.15, 0, 4.0, 8.8, "alpine_shadow")
    for a in ((-hw - 0.2, hw + 0.2, 8.8, 9.0), (-hw - 0.2, hw + 0.2, 3.8, 4.0), (-hw - 0.2, -hw, 4.0, 8.8), (hw, hw + 0.2, 4.0, 8.8)):
        bx(b, a[0], a[1], -0.25, 0, a[2], a[3], "navy")
    bx(b, -hw, hw, -0.7, -0.15, 9.0, 9.25, "navy")
    bx(b, -hw + 0.2, hw - 0.2, -0.65, -0.5, 8.92, 9.0, "lamp_glass")
    y0, y1 = -0.3, -0.15
    # spanner (2.2), claw hammer (2.0), saw (2.5), drill, screwdriver, adjustable wrench
    bx(b, -3.4, -3.1, y0, y1, 5.0, 7.0, "steel")
    bx(b, -3.65, -2.85, y0, y1, 7.0, 7.4, "steel")
    bx(b, -3.55, -2.95, y0, y1, 4.6, 5.0, "steel")
    bx(b, -2.25, -1.95, y0, y1, 4.8, 6.6, "bench_wood")
    bx(b, -2.7, -1.3, y0, y1, 6.6, 7.1, "steel")
    prism(b, [(-0.9, 5.1), (0.9, 5.1), (0.9, 7.3), (-0.9, 6.0)], lambda u, v, y: Vector((u, y, v)), y0, y1, "steel")
    bx(b, -0.6, 0.6, y0, y1, 7.3, 7.8, "cart_red")
    cbx(b, 1.3, 2.7, -0.55, -0.15, 6.4, 7.2, "wild_blue", c=0.05)
    bx(b, 1.5, 1.9, -0.5, -0.2, 5.4, 6.4, "black")
    bx(b, 2.7, 3.1, -0.4, -0.25, 6.65, 6.95, "steel")
    bx(b, 3.3, 3.5, y0, y1, 5.6, 6.6, "steel")
    bx(b, 3.2, 3.6, y0, y1, 6.6, 7.6, "awning_yellow")
    return b, {"origin": "floor, on the wall plane (y 0), centred; extends to -y", "width": 2 * hw, "height": 9.25,
               "bench_top": 3.4, "light_point": [0.0, -1.2, 8.6], "tools": "spanner, hammer, saw, drill, screwdriver (1.5 to 2.5 long)"}


# ---------------------------------------------------------------- ToolCart
def tool_cart(name):
    b = Builder(name)
    for x in (-1.2, 1.2):
        for y in (-0.55, 0.55):
            bx(b, x - 0.12, x + 0.12, y - 0.12, y + 0.12, 0.45, 0.65, "steel")
            cyl(b, Vector((x - 0.1, y, 0.28)), 0.2, 0.28, 8, "black", axis=Vector((1, 0, 0)), bottom=True)
    cbx(b, -1.5, 1.5, -0.8, 0.8, 0.65, 3.0, "cart_red", c=0.1)
    for z in (1.05, 1.65, 2.15, 2.6):
        bx(b, -1.4, 1.4, -0.84, -0.8, z - 0.03, z + 0.03, "plank_dark")
        bx(b, -0.5, 0.5, -0.92, -0.8, z + 0.12, z + 0.22, "steel")
    cbx(b, -1.6, 1.6, -0.85, 0.85, 3.0, 3.15, "steel", c=0.04)
    for a in ((-1.6, 1.6, -0.85, -0.75), (-1.6, 1.6, 0.75, 0.85), (-1.6, -1.5, -0.75, 0.75), (1.5, 1.6, -0.75, 0.75)):
        bx(b, a[0], a[1], a[2], a[3], 3.15, 3.4, "steel")
    sweep(b, [Vector((1.5, -0.55, 2.7)), Vector((1.95, -0.55, 2.7)), Vector((1.95, 0.55, 2.7)), Vector((1.5, 0.55, 2.7))], 0.07, 6, "steel")
    bx(b, -1.1, 0.2, -0.3, -0.1, 3.15, 3.25, "steel")
    cbx(b, 0.4, 1.2, -0.1, 0.5, 3.15, 3.55, "wild_blue", c=0.05)
    return b, {"origin": "floor centre; front (drawers) -y; push handle +x", "size": [3.9, 1.7, 3.55]}


# ---------------------------------------------------------------- TireRack (lean)
def tire_rack(name):
    b = Builder(name)
    hx, hy, H = 2.8, 0.75, 4.7
    for x in (-hx, hx):
        for y in (-hy, hy):
            bx(b, x - 0.1, x + 0.1, y - 0.1, y + 0.1, 0, H, "steel")
    for z in (0.45, 2.6):
        for y in (-0.45, 0.45):
            bx(b, -hx, hx, y - 0.08, y + 0.08, z - 0.15, z, "navy")
    bx(b, -hx - 0.1, hx + 0.1, -hy - 0.1, hy + 0.1, H, H + 0.12, "navy")
    r = 0.95
    for z in (0.45, 2.6):
        for k in range(4):
            x = -1.95 + k * 1.3
            tyre(b, Vector((x, 0, z + r - 0.1)), Vector((1, 0, 0)), r, 0.5, 0.85, 8, crown=False)
    return b, {"origin": "floor centre; front -y", "size": [5.8, 1.7, H + 0.12], "tyres": 8}


# ---------------------------------------------------------------- TurntableDisc + RarityRing
def turntable_disc(name):
    b = Builder(name)
    n = 32
    H = 0.5
    rim = [Vector((math.cos(2 * math.pi * k / n) * TT_R, math.sin(2 * math.pi * k / n) * TT_R, H)) for k in range(n)]
    hub = [Vector((math.cos(2 * math.pi * k / 16) * 1.1, math.sin(2 * math.pi * k / 16) * 1.1, H)) for k in range(16)]
    for k in range(16):
        sw = "stone_light" if k % 2 == 0 else "tile_grey"
        oface(b, [hub[k], rim[2 * k], rim[2 * k + 1], rim[(2 * k + 2) % n], hub[(k + 1) % 16]], sw, Vector((0, 0, 0)))
    oface(b, hub, "steel", Vector((0, 0, 0)))
    low = [Vector((p.x, p.y, 0)) for p in rim]
    for k in range(n):
        k2 = (k + 1) % n
        oface(b, [low[k], low[k2], rim[k2], rim[k]], "navy", Vector((0, 0, H / 2)))
    cyl(b, Vector((0, 0, H)), 0.06, 0.7, 8, "brass")
    return b, {"origin": "disc centre on its base (floor)", "radius": TT_R, "top": H, "car_seat": [0.0, 0.0, H],
               "rotation_axis": "z through the origin"}


def rarity_ring(name):
    b = Builder(name)
    n = 32
    ri, ro2, H = 7.4, 8.08, 0.62

    def P(r, k, z):
        a = 2 * math.pi * k / n
        return Vector((math.cos(a) * r, math.sin(a) * r, z))

    for k in range(n):
        k2 = (k + 1) % n
        oface(b, [P(ri, k, H), P(ro2, k, H), P(ro2, k2, H), P(ri, k2, H)], "cart_white", Vector((0, 0, 0)))
        tface(b, [P(ri, k, 0.5), P(ri, k2, 0.5), P(ri, k2, H), P(ri, k, H)], "cart_white", Vector((0, 0, H)))
        oface(b, [P(ro2, k, 0.0), P(ro2, k2, 0.0), P(ro2, k2, H), P(ro2, k, H)], "cart_white", Vector((0, 0, H / 2)))
    return b, {"origin": "same as TurntableDisc", "inner_radius": ri, "outer_radius": ro2, "top": H,
               "recolour": "clear TextureID, set Color; Material SmoothPlastic or Neon",
               "rarity_colours_proposal": {"common": [214, 220, 226], "rare": [80, 140, 230], "epic": [160, 110, 220], "legendary": [246, 196, 60]}}


# ---------------------------------------------------------------- MarqueeBulb
def marquee_bulb(name):
    b = Builder(name)
    cyl(b, Vector((0, 0, 0)), 0.16, 0.22, 8, "brass", axis=Vector((0, -1, 0)), top_sw="brass")
    ball(b, Vector((0, -0.42, 0)), 0.27, 8, 5, "lamp_glass")
    return b, {"origin": "mount point on the sign board front; the bulb points -y", "diameter": 0.54, "depth": 0.69}


# ---------------------------------------------------------------- RoofVent
def roof_vent(name):
    b = Builder(name)
    cbx(b, -1.1, 1.1, -1.1, 1.1, 0, 0.3, "navy", c=0.06)
    cbx(b, -0.85, 0.85, -0.85, 0.85, 0.3, 1.6, "steel", c=0.06)
    for z in (0.6, 0.95, 1.3):
        for axis, plane, out in (("y", -0.85, -1), ("y", 0.85, 1), ("x", -0.85, -1), ("x", 0.85, 1)):
            onwall(b, axis, plane, out, -0.7, 0.7, z, z + 0.14, 0, 0.1, "navy")
    for x in (-0.7, 0.7):
        for y in (-0.7, 0.7):
            bx(b, x - 0.08, x + 0.08, y - 0.08, y + 0.08, 1.6, 1.85, "steel")
    cbx(b, -1.15, 1.15, -1.15, 1.15, 1.85, 2.05, "navy", c=0.06)
    sq = [Vector((sx * 0.95, sy * 0.95, 2.05)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    tip = Vector((0, 0, 2.4))
    for k in range(4):
        oface(b, [sq[k], sq[(k + 1) % 4], tip], "navy", Vector((0, 0, 2.1)))
    return b, {"origin": "base centre on the roof deck", "size": [2.3, 2.3, 2.4]}


# ---------------------------------------------------------------- GarageFlagpole (sign-top clamp)
FLAG_H = 6.4


def garage_flagpole(name):
    b = Builder(name)
    H = FLAG_H
    # a navy clamp that straddles the 0.8-deep sign board top (origin on the board top)
    cbx(b, -0.45, 0.45, -0.6, 0.6, -0.45, 0.25, "navy", c=0.05)
    cyl(b, Vector((0, 0, 0.25)), 0.3, 0.18, 8, "metal", r_top=0.14)
    cyl(b, Vector((0, 0, 0.55)), H - 0.55 - 0.4, 0.11, 8, "cart_white", r_top=0.085)
    cyl(b, Vector((0, 0, H - 0.4)), 0.1, 0.12, 8, "metal")
    ball(b, Vector((0, 0, H - 0.16)), 0.14, 8, 4, "brass")
    sweep(b, [Vector((0, 0.08, 1.0)), Vector((0, 0.22, 1.0))], 0.03, 5, "metal")
    return b, {"origin": "on the sign board top at the pole axis (the clamp reaches 0.45 below)", "height": round(H - 0.02, 3),
               "flag_top": round(H - 0.45, 3), "flag_bottom": round(H - 2.45, 3), "flag_side": "+x",
               "cloth": "checkered (black / cream), animated by the Luau side"}


# ---------------------------------------------------------------- WrenchTireSculpture (pylon crest)
def sculpture(name):
    b = Builder(name)
    # origin: the mount point on the pylon face, at the tyre centre height; the crest projects -y
    R, rr, ra = 2.6, 0.9, 0.45  # tyre centreline radius, radial and axial half-thickness
    yt = -0.8
    cbx(b, -0.8, 0.8, -0.35, 0.2, -0.8, 0.8, "steel", c=0.06)
    seg, sides = 20, 8
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        radial = Vector((math.cos(a), 0, math.sin(a)))
        ring_pts = []
        for j in range(sides):
            ph = 2 * math.pi * j / sides
            ring_pts.append(radial * (R + math.cos(ph) * rr) + Vector((0, yt + math.sin(ph) * ra, 0)))
        rings.append((radial, ring_pts))
    for i in range(seg):
        rad1, p1 = rings[i]
        rad2, p2 = rings[(i + 1) % seg]
        core = ((rad1 + rad2) / 2).normalized() * R + Vector((0, yt, 0))
        for j in range(sides):
            j2 = (j + 1) % sides
            ph = 2 * math.pi * (j + 0.5) / sides
            cph, sph = math.cos(ph), math.sin(ph)
            sw = "black" if cph > 0.35 else ("cart_white" if (sph < -0.6 and cph > -0.5) else "wet_band")
            oface(b, [p1[j], p2[j], p2[j2], p1[j2]], sw, core)
    hub_r = R - rr + 0.12
    cyl(b, Vector((0, yt + 0.35, 0)), 0.7, hub_r, 12, "steel", axis=Vector((0, -1, 0)), bottom=True)
    cyl(b, Vector((0, yt - 0.35, 0)), 0.1, 0.7, 10, "teal", axis=Vector((0, -1, 0)))
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        cyl(b, Vector((math.cos(a) * 1.05, yt - 0.35, math.sin(a) * 1.05)), 0.08, 0.12, 6, "brass", axis=Vector((0, -1, 0)))
    th = math.radians(50)
    U = Vector((math.cos(th), 0, math.sin(th)))
    V = Vector((-math.sin(th), 0, math.cos(th)))
    yc = -1.58
    E, Wr = 4.0, 1.8

    def X(u, v, y):
        return U * u + V * v + Vector((0, y, 0))

    prism(b, [(-2.9, -0.65), (2.7, -0.65), (2.7, 0.65), (-2.9, 0.65)], X, yc - 0.1, yc + 0.1, "accent_neutral", side_sw="steel")
    annulus(b, X, -E, 0.0, 0.62, 1.4, 0.0, 2 * math.pi, 12, yc - 0.22, yc + 0.22, "accent_neutral", side_sw="steel")
    gap = math.radians(40)
    annulus(b, X, E, 0.0, 0.75, Wr, gap, 2 * math.pi - gap, 10, yc - 0.22, yc + 0.22, "accent_neutral", side_sw="steel", closed=False)
    cyl(b, Vector((0, yt - 0.45, 0)), 0.35, 0.3, 8, "brass", axis=Vector((0, -1, 0)))
    top = E * math.sin(th) + Wr
    return b, {"origin": "mount point on the pylon face (y 0) at the tyre centre; projects -y to 1.8",
               "tyre_outer_radius": R + rr, "top_above_origin": round(top, 3), "bottom_below_origin": round(E * math.sin(th) + 1.4, 3),
               "half_width": round(E * math.cos(th) + Wr, 3), "depth": 1.8}


# ---------------------------------------------------------------- forecourt props
def tire_stack(name):
    b = Builder(name)
    rng = random.Random(41)
    for (x, y), count in (((0.0, 0.0), 4), ((2.45, 0.6), 2)):
        for i in range(count):
            jx, jy = rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08)
            tyre(b, Vector((x + jx, y + jy, 0.4 + i * 0.8)), Vector((0, 0, 1)), 1.1, 0.55, 0.8, 10, crown=False)
    cyl(b, Vector((0, 0, 3.2)), 0.08, 0.7, 10, "teal", bottom=True)
    return b, {"origin": "floor, centre of the taller stack", "size": [4.7, 2.3, 3.3], "tyres": 6}


def oil_can_display(name):
    b = Builder(name)
    for x in (-0.95, 0.95):
        cbx(b, x - 0.08, x + 0.08, -0.45, 0.45, 0, 2.6, "navy", c=0.03)
    for z in (0.35, 1.2, 2.05):
        cbx(b, -0.95, 0.95, -0.42, 0.42, z - 0.08, z, "steel", c=0.02)
    bx(b, -0.95, 0.95, 0.38, 0.45, 0.3, 2.6, "navy")
    cols = ("bunting_red", "awning_yellow", "wild_blue", "mint")
    for zi, z in enumerate((0.35, 1.2, 2.05)):
        for k in range(4):
            cyl(b, Vector((-0.6 + k * 0.4, -0.05, z)), 0.55, 0.17, 8, cols[(k + zi) % 4], top_sw="steel")
    cbx(b, -1.05, 1.05, -0.52, -0.36, 2.6, 3.2, "red_orange", c=0.04)
    return b, {"origin": "floor centre; front -y", "size": [2.1, 0.95, 3.2],
               "header_face": {"centre": [0.0, 2.9], "size": [2.0, 0.5], "plane_y": -0.52}}


def drum(name, sw):
    b = Builder(name)
    r, H = 0.95, 2.8
    cyl(b, Vector((0, 0, 0)), H, r, 12, sw, top_sw="steel", bottom=False)
    for z in (0.9, 1.9):
        cyl(b, Vector((0, 0, z - 0.08)), 0.16, r + 0.06, 12, "steel", top=True)
    cyl(b, Vector((0, 0, H)), 0.04, r - 0.08, 12, sw)
    cyl(b, Vector((0.45, 0.2, H)), 0.12, 0.14, 6, "steel")
    return b, {"origin": "floor centre", "diameter": 2 * r, "height": H + 0.16}


def air_pump(name):
    b = Builder(name)
    cbx(b, -0.55, 0.55, -0.45, 0.45, 0, 0.2, "steel", c=0.04)
    cbx(b, -0.25, 0.25, -0.25, 0.25, 0.2, 3.0, "red_orange", c=0.05)
    cbx(b, -0.6, 0.6, -0.4, 0.35, 3.0, 4.3, "cream", c=0.08)
    cbx(b, -0.65, 0.65, -0.45, 0.4, 4.3, 4.5, "navy", c=0.05)
    cyl(b, Vector((0, -0.4, 3.7)), 0.06, 0.38, 12, "navy", axis=Vector((0, -1, 0)))
    cyl(b, Vector((0, -0.46, 3.7)), 0.03, 0.31, 12, "cart_white", axis=Vector((0, -1, 0)))
    bx(b, -0.03, 0.03, -0.51, -0.47, 3.7, 3.98, "bunting_red")
    bx(b, 0.62, 0.82, -0.1, 0.1, 3.2, 3.4, "steel")
    path = [Vector((0.62, 0, 3.2))]
    for k in range(9):
        a = math.pi * 2 * k / 8
        path.append(Vector((0.85 + 0.05 * k, 0.45 * math.sin(a), 2.4 + 0.75 * math.cos(a))))
    sweep(b, path, 0.06, 5, "black")
    return b, {"origin": "floor centre; gauge faces -y", "size": [1.6, 1.0, 4.5]}


def garage_bench(name):
    b = Builder(name)
    L = 5.0
    for x in (-2.0, 2.0):
        cbx(b, x - 0.15, x + 0.15, -0.7, 0.5, 0, 0.35, "navy", c=0.04)
        cbx(b, x - 0.12, x + 0.12, -0.55, -0.3, 0.35, 1.5, "navy", c=0.03)
        cbx(b, x - 0.12, x + 0.12, 0.2, 0.45, 0.35, 2.9, "navy", c=0.03)
    for y in (-0.6, -0.2, 0.2):
        cbx(b, -L / 2, L / 2, y - 0.17, y + 0.17, 1.5, 1.7, "bench_wood", c=0.04)
    for z in (2.1, 2.6):
        cbx(b, -L / 2, L / 2, 0.45, 0.6, z - 0.18, z + 0.18, "bench_wood", c=0.04)
    return b, {"origin": "floor centre; seat faces -y (turn 180 to face the showroom)", "size": [L, 1.3, 2.8], "seat_height": 1.7}


def planter(name):
    b = Builder(name)
    rng = random.Random(7)
    cbx(b, -2.2, 2.2, -0.8, 0.8, 0, 0.9, "stone_light", c=0.1)
    cbx(b, -2.3, 2.3, -0.9, 0.9, 0.9, 1.05, "navy", c=0.05)
    bx(b, -2.05, 2.05, -0.65, 0.65, 1.0, 1.08, "dirt")
    for x in (-1.35, 0.0, 1.35):
        clump(b, Vector((x, 0, 1.45)), Vector((0.85, 0.6, 0.5)), rng, ["hedge_dark", "hedge", "leaf_mid", "leaf_light"], subdiv=1)
    for x, sw in ((-0.7, "tulip_red"), (0.65, "daisy_white"), (1.9, "tulip_yellow"), (-1.9, "tulip_yellow")):
        ball(b, Vector((x, -0.35, 1.85)), 0.2, 6, 3, sw)
    return b, {"origin": "floor centre; long axis x", "size": [4.6, 1.8, 2.05]}


def parking_arrow(name):
    b = Builder(name)
    z = 0.03
    pts = [(-0.3, -1.6), (0.3, -1.6), (0.3, 0.2), (0.9, 0.2), (0.0, 1.6), (-0.9, 0.2), (-0.3, 0.2)]
    oface(b, [Vector((-0.3, -1.6, z)), Vector((0.3, -1.6, z)), Vector((0.3, 0.2, z)), Vector((-0.3, 0.2, z))], "cart_white", Vector((0, 0, -1)))
    oface(b, [Vector((0.9, 0.2, z)), Vector((0.0, 1.6, z)), Vector((-0.9, 0.2, z))], "cart_white", Vector((0, 0, -1)))
    n = len(pts)
    for k in range(n):
        a, c = pts[k], pts[(k + 1) % n]
        oface(b, [Vector((a[0], a[1], 0)), Vector((c[0], c[1], 0)), Vector((c[0], c[1], z)), Vector((a[0], a[1], z))], "cart_white", Vector((0, 0.2, z / 2)))
    return b, {"origin": "arrow centre on the ground; points +y", "size": [1.8, 3.2, 0.03]}


def bollard(name):
    b = Builder(name)
    cyl(b, Vector((0, 0, 0)), 1.2, 0.22, 8, "awning_yellow", top=False)
    for z in (0.35, 0.8):
        cyl(b, Vector((0, 0, z)), 0.15, 0.225, 8, "black", top=False)
    from kit_portal import dome

    dome(b, Vector((0, 0, 1.2)), 0.22, 0.12, 8, 2, "black")
    return b, {"origin": "floor centre", "radius": 0.22, "height": 1.32}


# ---------------------------------------------------------------- placements (garage-local)
# Forecourt props stand in y -28..-20 (within 8 of the envelope front) and outside the approach
# lines of door A (x -29.4..-19.4), door B (x -17.4..-7.4) and the entrance (x 21..29).
FORECOURT = {
    "TireStack": {"position": [-5.6, -22.0, 0.0], "yaw": 0},
    "OilCanDisplay": {"position": [-3.0, -25.8, 0.0], "yaw": 0},
    "DrumRed": {"position": [-0.6, -21.4, 0.0], "yaw": 0},
    "DrumTeal": {"position": [-0.4, -23.8, 0.0], "yaw": 0},
    "AirPump": {"position": [-5.8, -25.6, 0.0], "yaw": 0},
    "GarageBench": {"position": [10.5, -23.0, 0.0], "yaw": 180},
    "Planter": [{"position": [4.6, -23.0, 0.0], "yaw": 0}, {"position": [16.4, -23.0, 0.0], "yaw": 0}],
    "ParkingArrow": [{"position": [-12.4, -24.0, 0.0], "yaw": 0, "note": "painted, flat: bay B, toward the lift door"},
                     {"position": [PY_C, -24.0, 0.0], "yaw": 0, "note": "painted, flat: toward the showroom entrance"}],
    "Bollard": [{"position": [-30.75, LOAD_Y - 4.5, 0.0], "yaw": 0}, {"position": [-30.75, LOAD_Y + 4.5, 0.0], "yaw": 0}],
}


def text_faces():
    """Every blank face that will carry text or a picture, with its exact plane (garage-local)."""
    out = []

    def add(fid, cx, plane_y, cz, w, h, normal_y, mesh):
        t = 0.05
        out.append({"id": fid, "mesh": mesh, "centre": [round(cx, 3), round(plane_y, 3), round(cz, 3)], "size": [round(w, 3), round(h, 3)],
                    "normal": [0, normal_y, 0],
                    "thin_part": {"size": [round(w, 3), round(h, 3), t], "centre": [round(cx, 3), round(plane_y + normal_y * t / 2, 3), round(cz, 3)],
                                  "note": "a flat part whose back face lies on the plane; put the SurfaceGui on its front (normal) face"}})

    fx0, fx1, fz0, fz1 = SIGN_FACE
    add("SignFace_Garage", (fx0 + fx1) / 2, SIGN_FACE_Y, (fz0 + fz1) / 2, fx1 - fx0, fz1 - fz0, -1, "GarageSign")
    add("SignFace_ShowroomPanel", 12.0, BY - 1.45, 11.2, 11.8, 4.2, -1, "GarageInterior")
    p = FORECOURT["OilCanDisplay"]["position"]
    add("SignFace_OilCanHeader", p[0], p[1] - 0.52, 2.9, 2.0, 0.5, -1, "OilCanDisplay")
    return out


def garage_meta():
    tt = []
    for tid, x, y, z in TURNTABLES:
        tt.append({"id": tid, "centre": [x, y, z], "radius": TT_R, "car_seat": [x, y, round(z + 0.5, 3)],
                   "ring": "RarityRing at the same centre", "label_point": [x, y, round(z + 0.5 + 6.2, 3)], "light": "showroom_" + tid})
    return {
        "origin": "footprint centre on the ground line; front faces -y (the fountain)",
        "yaw_convention": "degrees about z in Blender mesh-local axes, counter-clockwise seen from above; a placed mesh's front (-y) turns with it",
        "envelope": {"x": [-HW, HW], "y": [-HD, HD], "top": 34.0},
        "volumes": {"workshop": {"x": [-SX, PX[1]], "parapet": WS_TOP, "roof_deck": WS_DECK, "ceiling": WS_CEIL},
                    "showroom": {"x": [PX[0], SX], "eaves": EAVES, "roof_deck": DECK, "ceiling": CEIL},
                    "pylon": {"x": list(PYX), "front_y": PYF, "shaft_top": PY_SHAFT, "crown_top": PY_TOP}},
        "levels": {"workshop_floor": WS_FLOOR, "showroom_floor": SR_FLOOR, "showroom_stage": STAGE_Z},
        "workshop": {"x": [-SX + 1, PX[0]], "y": [GY, BY - 1]},
        "showroom": {"x": [PX[1], SX - 1], "y": [GY, BY - 1], "glass_plane_y": GY, "glass_x": list(GLASS_X),
                     "glass_z": [SR_FLOOR, GLASS_TOP], "transom_z": list(TRANSOM), "upper_mullions_x": [7.1],
                     "side_glass": {"x": SX - 0.5, "y": list(SIDE_GLASS_Y)},
                     "entrance": {"x": list(ENTRANCE), "z": [SR_FLOOR, ENT_TOP], "door_plane_y": -17.35, "walk_in": False,
                                  "note": "closed and collidable for this task; frameless glass doors in the pylon"}},
        "doors": {
            "A": {"opening": {"x": [DOORS["A"] - 5, DOORS["A"] + 5], "z": [WS_FLOOR, WS_FLOOR + DOOR_H], "wall_face_y": FY},
                  "mesh": "RollUpDoor", "position": [DOORS["A"], CURTAIN_Y, WS_FLOOR], "yaw": 0, "state": "closed"},
            "B": {"opening": {"x": [DOORS["B"] - 5, DOORS["B"] + 5], "z": [WS_FLOOR, WS_FLOOR + DOOR_H], "wall_face_y": FY},
                  "mesh": "RollUpDoor", "position": [DOORS["B"], CURTAIN_Y, WS_FLOOR + HALF_OPEN], "yaw": 0, "state": "half open (+5.0)",
                  "closed_position": [DOORS["B"], CURTAIN_Y, WS_FLOOR]},
            "Loading": {"opening": {"y": [LOAD_Y - 5, LOAD_Y + 5], "z": [WS_FLOOR, WS_FLOOR + DOOR_H], "wall_face_x": -SX},
                        "mesh": "RollUpDoor", "position": [-SX + 1.2, LOAD_Y, WS_FLOOR], "yaw": -90, "state": "closed (left-side loading area)"},
            "travel": {"axis": "z", "half_open": HALF_OPEN, "max": round(WS_CEIL - (WS_FLOOR + CURTAIN_H) - 0.05, 3)},
            "size_note": "10 wide x 10 tall (worker rule 8 x 10 met)",
        },
        "placements": dict({
            "CarLift": {"position": [LIFT[0], LIFT[1], WS_FLOOR], "yaw": 0},
            "ToolWall": {"position": [-19.6, BY - 1.2, WS_FLOOR], "yaw": 0, "note": "back wall, left of the lift car as seen through door B"},
            "TireRack": {"position": [-26.7, BY - 2.2, WS_FLOOR], "yaw": 0, "note": "back wall, far left, seen through door B past the lift post"},
            "ToolCart": {"position": [-9.4, -11.6, WS_FLOOR], "yaw": 0},
            "TurntableDisc": [t["centre"] for t in tt], "RarityRing": [t["centre"] for t in tt],
            "MarqueeBulb": bulb_positions(),
            "RoofVent": [[2.0, 9.0, DECK], [9.0, 9.0, DECK], [16.0, 9.0, DECK]],
            "GarageFlagpole": [{"position": [-30.15, -17.4, SIGN_BOARD[3]], "yaw": 0, "flag_side": "+x"},
                               {"position": [8.15, -17.4, SIGN_BOARD[3]], "yaw": 180, "flag_side": "-x after the turn"}],
            "WrenchTireSculpture": {"position": [PY_C, PYF, CREST_Z], "yaw": 0, "note": "crest on the entrance pylon"},
            "HazardStrip": hazard_placements(),
            "WallLight": wall_light_placements(),
        }, **FORECOURT),
        "turntables": tt,
        "turntable_motion": {"axis": "z", "deg_per_s": 6, "reduced_motion": "stop at a three-quarter pose (45, 135, 225 degrees)",
                             "data_hooks": "per slot: id, centre, car_seat, label_point, ring; the car model's pivot at its bottom centre goes on car_seat"},
        "lift_car_point": [LIFT[0], LIFT[1], round(WS_FLOOR + LIFT_PAD_TOP, 3)],
        "lift_car_note": "the car body's underside sits here, long axis y, nose -y; no car mesh in the kit",
        "light_points": light_points(),
        "text_faces": text_faces(),
        "sign": {"face": {"centre": [round((SIGN_FACE[0] + SIGN_FACE[1]) / 2, 3), round((SIGN_FACE[2] + SIGN_FACE[3]) / 2, 3)],
                          "size": [round(SIGN_FACE[1] - SIGN_FACE[0], 3), round(SIGN_FACE[3] - SIGN_FACE[2], 3)], "plane_y": SIGN_FACE_Y,
                          "capitals": 6.5},
                 "board": {"x": [SIGN_BOARD[0], SIGN_BOARD[1]], "z": [SIGN_BOARD[2], SIGN_BOARD[3]], "y": [SIGN_FRONT_Y, -17.0]}},
        "flag_tops": [[-30.15, -17.4, round(SIGN_BOARD[3] + FLAG_H - 0.45, 3)], [8.15, -17.4, round(SIGN_BOARD[3] + FLAG_H - 0.45, 3)]],
        "sculpture_anchor": [PY_C, PYF, CREST_Z],
        "PromptPoint": {"position": [PY_C, -21.0, 2.6], "action": "Open Garage", "note": "in front of the pylon entrance, outside; preview reports 'not connected'"},
        "forecourt": {"y": [-28.0, -20.0], "x": [-HW, HW], "note": "props within 8 of the envelope front; the 10-wide forecourt walk runs at y -29..-39 (lead layout); the Luau side paints bay lines",
                      "approach_lines": {"door_A": [DOORS["A"] - 5, DOORS["A"] + 5], "door_B": [DOORS["B"] - 5, DOORS["B"] + 5], "entrance": list(ENTRANCE), "note": "x ranges kept clear of standing props from the facade to the walk"},
                      "bays": [{"id": "B", "x": [DOORS["B"] - 4.5, DOORS["B"] + 4.5], "y": [-28.0, -20.0], "size": [9, 8], "note": "8 deep now; a 13-long car overhangs into the walk"}],
                      "service_cluster": {"x": [-6.7, 0.7], "y": [-26.3, -20.4], "items": "tyre stack, oil cans, two drums, air pump (beside the workshop, in front of the showroom's left glass)"},
                      "seating_cluster": {"x": [2.3, 18.7], "y": [-23.9, -22.1], "items": "GarageBench facing the showroom, two planters"}},
        "loading_area": {"door_y": [LOAD_Y - 5, LOAD_Y + 5], "wall_face_x": -SX,
                         "note": "workshop left side, on the wall only: roll-up door, hood, hazard strips, two wall lights, two bollards at the wall line (outer x -30.97); no outside zone"},
    }


def build_all(emit):
    P = "garage/"
    emit(shell("GarageShell"), garage_meta(), P + "Building")
    emit(structure("GarageStructure"), {"origin": "garage-local (same as GarageShell)"}, P + "Building")
    emit(glazing("GarageGlazing"), {"origin": "garage-local", "swatch": "glass (one swatch); Transparency about 0.55, Material Glass"}, P + "Building")
    emit(interior("GarageInterior"), {"origin": "garage-local"}, P + "Building")
    emit(lights("GarageLights"), {"origin": "garage-local", "swatch": "light_panel (one swatch); Neon, PointLights at GarageShell light_points"}, P + "Building")
    emit(sign("GarageSign"), {"origin": "garage-local", "face": garage_meta()["sign"]["face"], "text_face": "SignFace_Garage in GarageShell text_faces"}, P + "Sign")
    emit(*checkered_band("CheckeredBand"), P + "Sign")
    emit(*marquee_bulb("MarqueeBulb"), P + "Sign")
    emit(*forecourt_curb("ForecourtCurb"), P + "Forecourt")
    emit(*rollup_door("RollUpDoor"), P + "Workshop")
    emit(*hazard_strip("HazardStrip"), P + "Workshop")
    emit(*car_lift("CarLift"), P + "Workshop")
    emit(*tool_wall("ToolWall"), P + "Workshop")
    emit(*tool_cart("ToolCart"), P + "Workshop")
    emit(*tire_rack("TireRack"), P + "Workshop")
    emit(*wall_light("WallLight"), P + "Building")
    emit(*turntable_disc("TurntableDisc"), P + "Showroom")
    emit(*rarity_ring("RarityRing"), P + "Showroom")
    emit(*roof_vent("RoofVent"), P + "Roof")
    emit(*garage_flagpole("GarageFlagpole"), P + "Roof")
    emit(*sculpture("WrenchTireSculpture"), P + "Pylon")
    emit(*tire_stack("TireStack"), P + "Forecourt")
    emit(*oil_can_display("OilCanDisplay"), P + "Forecourt")
    emit(*drum("DrumRed", "red_orange"), P + "Forecourt")
    emit(*drum("DrumTeal", "teal"), P + "Forecourt")
    emit(*air_pump("AirPump"), P + "Forecourt")
    emit(*garage_bench("GarageBench"), P + "Forecourt")
    emit(*planter("Planter"), P + "Forecourt")
    emit(*parking_arrow("ParkingArrow"), P + "Forecourt")
    emit(*bollard("Bollard"), P + "Forecourt")
