# Downtown kit B2: the landmark family (one thumbnail landmark per district plus the roadside
# set), silhouette first. Hierarchy of reusable complexity (triangle budget <= 2,500 each):
#   hero (one per district, read from about 300 studs by roofline): REEL WHEELS theater (Main
#   Street), city hall + clock tower (City Hall), harbor bridge arches (Harbor Bridge), distant
#   stadium (Midtown, skyline scale, in kit_b2_street), park fountain (Skyline Park);
#   roadside (any district, rhythm pieces): car wash, service canopy, donut bakery, delivery depot.
# The fire station of the base prompt is replaced by a fictional delivery depot (AGENTS.md
# vehicle rule 5: no emergency-service vehicles or liveries). All names and signs are original
# kid-friendly car puns; no real logos.
#
# Landmarks use FIXED swatches (lm_*, marquee*, civic_*, ...) so they look the same in every
# district palette; only window glass follows the district (within a few values everywhere).
# Lot-type landmarks use the lot frame (kit_b2lib): facade at z 0 facing -Z, footprint x 0..W,
# pivot at the front corner on the lot's own left. Moving parts (car-wash brushes) are separate
# meshes placed at named sockets.

import math

import kitlib
from kit_b2_lots import STOREY, WIN, finish, lot_meta, shop_door, shop_ground, uppers_pairs
from kit_b2_road import WATER_Y, dims
from kit_b2lib import (
    B2Builder,
    Offset,
    SideWall,
    V,
    arch_window,
    body,
    box,
    circle_uv,
    cornice,
    face_rec,
    fbox,
    fdir,
    fp,
    fquad,
    parapet,
    pier,
    plate,
    side_plate,
    sock,
    strip_band,
    wall_with_holes,
    window,
)
from kitlib import beam, cyl, prism, sphere, tube

LM = {"wall": "lm_wall", "base": "lm_wall_2", "stone": "lm_trim", "trim_1": "lm_trim", "reveal": "lm_wall_2", "door": "sign_frame_1", "shop": "sign_frame_3", "aw": "sign_frame_1", "aw2": "sign_frame_3", "course": "lm_wall_2"}


def lm(name, extra=None):
    r = dict(LM)
    if extra:
        r.update(extra)
    return B2Builder(name, r)


def poster(b, cu, cv, kind):
    """A framed poster case (5 x 7) with an original geometric graphic (no text, no real art)."""
    plate(b, [(cu - 2.5, cv - 3.5), (cu + 2.5, cv - 3.5), (cu + 2.5, cv + 3.5), (cu - 2.5, cv + 3.5)], 0, 0.25, "marquee_trim", back=False)
    fquad(b, cu - 2.1, cu + 2.1, cv - 3.1, cv + 3.1, 0.27, "poster_bg")
    z = 0.29
    if kind == 0:  # a rocket climbing past a moon
        b.face([fp(cu - 0.7, cv - 1.8, z), fp(cu + 0.7, cv - 1.8, z), fp(cu + 0.7, cv + 1.0, z), fp(cu, cv + 2.4, z), fp(cu - 0.7, cv + 1.0, z)], "poster_3", V(0, 0, -1))
        b.face([fp(cu + u, cv + v, z) for u, v in circle_uv(1.2, 2.2, 0.5, 6)], "emblem_white", V(0, 0, -1))
    elif kind == 1:  # sun over hills
        b.face([fp(cu + u, cv + v, z) for u, v in circle_uv(0, 0.9, 1.3, 8)], "poster_3", V(0, 0, -1))
        b.face([fp(cu - 2.1, cv - 3.1, z), fp(cu + 2.1, cv - 3.1, z), fp(cu + 2.1, cv - 1.0, z), fp(cu + 0.6, cv - 0.6, z), fp(cu - 2.1, cv - 1.2, z)], "poster_4", V(0, 0, -1))
    elif kind == 2:  # a round little car
        b.face([fp(cu - 1.6, cv - 0.6, z), fp(cu + 1.6, cv - 0.6, z), fp(cu + 1.6, cv + 0.6, z), fp(cu + 0.7, cv + 1.4, z), fp(cu - 0.9, cv + 1.4, z), fp(cu - 1.6, cv + 0.6, z)], "poster_1", V(0, 0, -1))
        for du in (-0.9, 0.9):
            b.face([fp(cu + du + u, cv - 0.7 + v, z + 0.01) for u, v in circle_uv(0, 0, 0.5, 6)], "reel_dark", V(0, 0, -1))
    else:  # a friendly round monster
        b.face([fp(cu + u, cv - 0.4 + v, z) for u, v in circle_uv(0, 0, 1.5, 8)], "poster_4", V(0, 0, -1))
        for du in (-0.5, 0.5):
            b.face([fp(cu + du + u, cv - 0.1 + v, z + 0.01) for u, v in circle_uv(0, 0, 0.3, 5)], "emblem_white", V(0, 0, -1))


def bulb_row(b, pts, size=0.42):
    """Marquee bulbs: small boxes with no back and no top (seen from below and the side)."""
    for p in pts:
        box(b, p, (size, size, size), {"side": "bulb", "skip_top": True})


def wheel_disc(b, cz, cy, R, x=0.0, t=1.0):
    """The REEL WHEELS crown: a film reel that is also a wheel, standing in the plane x = const
    (faces +X and -X, i.e. along the road): a silver disc with five dark reel holes, a hub and a
    dark tyre rim. Reads by silhouette before any text."""
    n = 14
    side_plate(b, x, [(cz + math.cos(2 * math.pi * k / n) * R, cy + math.sin(2 * math.pi * k / n) * R) for k in range(n)], t, "reel_steel", "reel_dark")
    for sx in (-1, 1):
        xf = x + sx * (t / 2 + 0.03)
        for k in range(5):
            a = 2 * math.pi * k / 5 + math.pi / 2
            hz, hy = cz + math.cos(a) * R * 0.52, cy + math.sin(a) * R * 0.52
            b.face([V(xf, hy + math.sin(2 * math.pi * j / 6) * R * 0.2, hz + math.cos(2 * math.pi * j / 6) * R * 0.2) for j in range(6)], "reel_dark", V(sx, 0, 0))
        b.face([V(xf, cy + math.sin(2 * math.pi * j / 6) * R * 0.12, cz + math.cos(2 * math.pi * j / 6) * R * 0.12) for j in range(6)], "marquee_trim", V(sx, 0, 0))
        # tyre: a dark ring band just inside the rim
        for k in range(n):
            a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
            p = [(R * 0.98, a0), (R * 0.98, a1), (R * 0.8, a1), (R * 0.8, a0)]
            b.face([V(xf, cy + math.sin(a) * r, cz + math.cos(a) * r) for r, a in p], "reel_dark", V(sx, 0, 0))


# ---------------------------------------------------------------- REEL WHEELS theater (Main Street)
def theater(name):
    """REEL WHEELS: a 36-wide front lot (B2 replaces B_Theater + B_TheaterBlade). The chase-camera
    read comes from three things the overnight version lacked: (1) a projecting TRAPEZOID marquee
    (10 out, 12-18 high) whose two angled faces face approaching and departing traffic at about
    35 degrees, so its text is readable from the lane; (2) a vertical BLADE sign 36 tall, 8.6 out,
    centred above the marquee, its two text faces looking straight down the road both ways and
    its top rising above the parapet into the sky; (3) a reel-wheel crown on the blade and a
    stepped tower crown, so the silhouette reads before text from about 300 studs. Below: a deep
    recessed entrance with four glass doors and a ticket booth, poster cases, a projecting
    central bay with tall windows and gold ribs, cream stone with marquee-red and gold accents."""
    b = lm(name)
    W, D = 36.0, 24.0
    hw = W / 2
    # ground floor: entrance recess and poster bays
    holes = [(-9.0, 9.0, 0.0, 10.0)]
    wall_with_holes(b, -hw, hw, 0, 16.0, holes, "base")
    window(b, -9.0, 9.0, 0.0, 10.0, 3.0, {"reveal": "lm_trim", "glass": "lm_wall_2"}, sill=False, lintel=False, split=0)
    for u in (-7.6, -4.1, 1.1, 4.6):
        fquad(b, u, u + 2.6, 0.0, 8.2, -2.94, "glass_light")
        fquad(b, u - 0.2, u + 2.8, 8.2, 8.6, -2.92, "marquee_trim")
    fbox(b, -1.3, 1.3, 0.0, 6.0, -2.95, -1.0, "marquee", skip=("back",))
    fquad(b, -1.0, 1.0, 3.0, 5.4, -0.98, "glass_light")
    poster(b, -13.5, 6.5, 0)
    poster(b, 13.5, 6.5, 2)
    strip_band(b, -hw, hw, 0, 1.0, 0.25, "marquee_trim", bottom=False)
    strip_band(b, -hw, hw, 16.0, 16.8, 0.45, "marquee_trim")
    # the trapezoid marquee: back edge u +-15 on the wall, front edge u +-8 at d 10
    mq = [(-15.0, 0.1), (15.0, 0.1), (8.0, 10.0), (-8.0, 10.0)]
    xz = [(-u, -d) for u, d in mq]
    prism(b, xz, 12.4, 17.6, "marquee", "roof_dark", "marquee_under", top=True, bottom=True)
    for y0, y1 in ((11.8, 12.4), (17.6, 18.2)):
        prism(b, kitlib_offset(xz, 0.3), y0, y1, "marquee_trim", "marquee_trim", "marquee_trim", top=True, bottom=True)
    # sign panels (inset cream boards) on the front and both angled faces
    faces = []
    fquad(b, -7.2, 7.2, 13.1, 16.9, 10.04, "sign_face")
    faces.append(face_rec("marquee_front", fp(0, 15.0, 10.06), 14.0, 3.4))
    for s in (-1, 1):
        (u0, d0), (u1, d1) = (s * 15.0, 0.1), (s * 8.0, 10.0)
        nu, nd = (d1 - d0), -(u1 - u0)
        if nu * s < 0:
            nu, nd = -nu, -nd
        ln = math.hypot(nu, nd)
        nu, nd = nu / ln * 0.05, nd / ln * 0.05
        a, c = 0.12, 0.88
        pa = (u0 + (u1 - u0) * a + nu, d0 + (d1 - d0) * a + nd)
        pc = (u0 + (u1 - u0) * c + nu, d0 + (d1 - d0) * c + nd)
        b.face([fp(pa[0], 13.1, pa[1]), fp(pc[0], 13.1, pc[1]), fp(pc[0], 16.9, pc[1]), fp(pa[0], 16.9, pa[1])], "sign_face", fdir(nu, 0, nd))
        mid = ((pa[0] + pc[0]) / 2, (pa[1] + pc[1]) / 2)
        n3 = fdir(nu * 20, 0, nd * 20)
        faces.append(face_rec("marquee_" + ("right" if s > 0 else "left"), fp(mid[0], 15.0, mid[1] + 0.01), math.hypot(pc[0] - pa[0], pc[1] - pa[1]) - 0.4, 3.4, normal=[round(n3.x, 3), 0, round(n3.z, 3)]))
    bulbs = []
    for k in range(9):
        u = -7.5 + 15.0 * k / 8
        bulbs.append(fp(u, 11.6, 9.6))
    for s in (-1, 1):
        for k in range(1, 4):
            t = k / 4
            bulbs.append(fp(s * (15.0 + (8.0 - 15.0) * t), 11.6, 0.1 + 9.9 * t - 0.4))
    bulb_row(b, bulbs)
    for s in (-1, 1):
        beam(b, fp(s * 7.6, 18.2, 9.4), fp(s * 5.0, 24.0, 1.3), 0.14, 0.14, "reel_dark")
    # upper facade: a projecting central bay (d 1.2) with four tall windows and gold ribs
    H = 40.0
    wall_with_holes(b, -hw, hw, 16.8, H, [(-15.0, -11.0, 20.0, 33.0), (11.0, 15.0, 20.0, 33.0)], "wall")
    for a, c in ((-15.0, -11.0), (11.0, 15.0)):
        arch_window(b, a, c, 20.0, 33.0, 1.0, "wall", {"reveal": "lm_wall_2", "glass": "glass", "lintel": "marquee_trim", "sill": "lm_trim"}, seg=4)
    bay = Offset(b, -1.2)
    bholes = [(u, u + 2.4, 20.0, 37.0) for u in (-7.0, -3.4, 1.0, 4.6)]
    wall_with_holes(bay, -8.0, 8.0, 16.8, H + 2.0, bholes, "wall")
    for a, c, h0, h1 in bholes:
        window(bay, a, c, h0, h1, 0.8, {"reveal": "lm_wall_2", "glass": "glass", "glass_light": "glass_light"}, sill=False, lintel=False, split=0.5)
    for u in (-8.0, -4.4, -0.2, 3.8, 7.4):
        pier(bay, u, u + 0.6, 17.0, H + 1.5, 0.35, "marquee_trim")
    for u in (-8.0, 8.0):
        b.face([fp(u, 16.8, 0), fp(u, H + 2.0, 0), fp(u, H + 2.0, 1.2), fp(u, 16.8, 1.2)], "wall", fdir(1 if u > 0 else -1))
    # cornice on the outer bays, a gold band, and the stepped tower crown over the bay
    for a, c in ((-hw, -8.0), (8.0, hw)):
        cornice(b, a - (0.3 if a < 0 else 0), c + (0.3 if c > 0 else 0), H - 3.0, 1.6, "lm_trim", 1.6)
        box(b, V(-(a + c) / 2, H - 0.6, 0.4), (c - a, 1.4, 0.8), {"side": "wall", "top": "lm_trim", "skip_bottom": True})
    strip_band(bay, -8.0, 8.0, H + 2.0, H + 2.8, 0.4, "marquee")
    y = H + 2.8
    for i, (pw, ph) in enumerate(((14.0, 3.4), (9.0, 3.0), (4.4, 2.6))):
        box(b, V(0, y + ph / 2, -0.6), (pw, ph, 1.6), {"side": "wall", "top": "marquee_trim", "skip_bottom": True})
        strip_band(Offset(b, -1.4), -pw / 2, pw / 2, y + ph - 0.5, y + ph, 0.2, "marquee_trim", top=False)
        y += ph
    crown_top = y
    # fly tower behind (silhouette mass above the roofline)
    box(b, V(0, 26.0, 17.0), (26.0, 52.0, 14.0), {"side": "lm_wall_2", "top": "roof_dark", "skip_bottom": True})
    box(b, V(0, 50.5, 17.0), (26.4, 1.2, 14.4), {"side": "marquee", "skip_bottom": True, "skip_top": True})
    roof_y = H - 1.0
    b.face([V(-hw, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
    body(b, W, 0, H, D)
    # the blade: Round 2 makes it 69 tall (y 19 to BLADE_TOP) so it still clears the roofline of the new
    # 4-6 storey neighbours (up to about 84), out to d 10, faces +X/-X (down the road both ways)
    BLADE_TOP = 88.0
    blade = [(-1.6, 19.0), (-8.6, 19.0), (-10.0, 20.4), (-10.0, BLADE_TOP - 1.4), (-8.6, BLADE_TOP), (-1.6, BLADE_TOP)]
    side_plate(b, 0.0, blade, 1.4, "marquee", "marquee_trim")
    face_top = BLADE_TOP - 1.6
    face_mid = (20.6 + face_top) / 2
    for sx in (-1, 1):
        xf = sx * 0.73
        b.face([V(xf, 20.6, -2.6), V(xf, 20.6, -9.0), V(xf, face_top, -9.0), V(xf, face_top, -2.6)], "sign_face", V(sx, 0, 0))
        faces.append({"name": "blade_" + ("right" if sx > 0 else "left"), "centre": [xf + sx * 0.02, face_mid, -5.8], "size": [6.2, round(face_top - 20.6 - 0.8, 2)], "normal": "Right" if sx > 0 else "Left", "text": "vertical"})
    bulb_row(b, [V(0, 21.0 + (BLADE_TOP - 22.0) * k / 21, -10.25) for k in range(22)], 0.5)
    for yb in (21.0, 43.0, 65.0, BLADE_TOP - 3.0):
        box(b, V(0, yb, -1.4), (0.5, 0.5, 1.0), {"side": "reel_dark"})
    box(b, V(0, BLADE_TOP + 1.0, -5.8), (0.6, 2.2, 0.6), {"side": "reel_dark"})
    wheel_disc(b, -5.8, BLADE_TOP + 6.6, 5.6)
    fr = finish(b, W)
    faces = [dict(f, centre=[round(f["centre"][0] + W / 2, 3), f["centre"][1], f["centre"][2]]) for f in faces]
    extra = {"roof_a": sock((-10.0, roof_y, 12.0), frame=fr), "roof_b": sock((10.0, roof_y, 9.0), frame=fr)}
    return b, lot_meta(
        "landmark",
        W,
        D,
        100.2,
        3,
        "landmark",
        "MS",
        fr,
        roof_y,
        extra,
        faces=faces,
        landmark="REEL WHEELS (movie theater)",
        default_text={"marquee_front": "NOW SHOWING", "marquee_left": "NOW SHOWING", "marquee_right": "NOW SHOWING", "blade_left": "REEL WHEELS", "blade_right": "REEL WHEELS"},
        replaces=["B_Theater", "B_TheaterBlade"],
        read={"silhouette": "blade + reel-wheel crown to y 100 (Round 2: above 6-storey neighbours), stepped crown to y %.1f, fly tower to 52" % crown_top, "approach_text": "blade faces +X/-X; marquee angled faces at about 35 degrees"},
    )


def kitlib_offset(xz, dist):
    """Offset a convex plan outline outward (mitred) - the marquee trims."""
    n = len(xz)
    cx = sum(p[0] for p in xz) / n
    cz = sum(p[1] for p in xz) / n
    out = []
    for i in range(n):
        p0, p1, p2 = xz[i - 1], xz[i], xz[(i + 1) % n]
        ns = []
        for a, c in ((p0, p1), (p1, p2)):
            dx, dz = c[0] - a[0], c[1] - a[1]
            ln = math.hypot(dx, dz) or 1
            nx, nz = dz / ln, -dx / ln
            mx, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
            if nx * (mx - cx) + nz * (mz - cz) < 0:
                nx, nz = -nx, -nz
            ns.append((nx, nz))
        nx, nz = ns[0][0] + ns[1][0], ns[0][1] + ns[1][1]
        ln = math.hypot(nx, nz) or 1
        nx, nz = nx / ln, nz / ln
        cosh = max(0.3, nx * ns[0][0] + nz * ns[0][1])
        out.append((p1[0] + nx * dist / cosh, p1[1] + nz * dist / cosh))
    return out


# ---------------------------------------------------------------- car wash (roadside)
def car_wash(name):
    """SUDSY WHEELS CAR WASH: a 48-wide lot. The wash tunnel runs parallel to the road inside the
    lot (never in the drivable lane): open arched ends face along the road, and three big open
    windows on the street face show the brush rigs inside. Brushes and the roller are separate
    meshes (B2_LM_CarWashBrush, B2_LM_CarWashRoller) at sockets, to turn calmly in Studio.
    Barrel roof in teal, white-tile walls, a cluster of soap bubbles over the name board."""
    b = lm(name, {"wall": "wash_tile", "base": "wash_tile"})
    W, D = 48.0, 24.0
    hw = W / 2
    H = 14.0
    th = 0.8  # wall thickness (the windows are open: reveals show it)
    holes = [(-19.0, -7.0, 3.0, 10.5), (-5.0, 5.0, 3.0, 10.5), (7.0, 19.0, 3.0, 10.5)]
    wall_with_holes(b, -hw, hw, 0, H, holes, "wall")
    for a, c, h0, h1 in holes:
        for u, dd in ((a, 1), (c, -1)):
            b.face([fp(u, h0, 0), fp(u, h1, 0), fp(u, h1, -th), fp(u, h0, -th)], "canopy_band", fdir(dd))
        b.face([fp(a, h1, 0), fp(c, h1, 0), fp(c, h1, -th), fp(a, h1, -th)], "canopy_band", V(0, -1, 0))
        b.face([fp(a, h0, 0), fp(c, h0, 0), fp(c, h0, -th), fp(a, h0, -th)], "canopy_band", V(0, 1, 0))
    strip_band(b, -hw, hw, 0, 1.2, 0.2, "canopy_band", bottom=False)
    # interior: floor, the far wall, the ceiling (seen through the windows and the open ends)
    b.face([V(-hw, 0.05, th), V(hw, 0.05, th), V(hw, 0.05, D - th), V(-hw, 0.05, D - th)], "concrete_block", V(0, 1, 0))
    b.face([V(-hw, 0, D - th), V(hw, 0, D - th), V(hw, H, D - th), V(-hw, H, D - th)], "wash_tile", V(0, 0, -1))
    b.face([V(-hw, H - 0.2, th), V(hw, H - 0.2, th), V(hw, H - 0.2, D - th), V(-hw, H - 0.2, D - th)], "canopy_under", V(0, -1, 0))
    b.face([V(-hw, 0, th), V(hw, 0, th), V(hw, H, th), V(-hw, H, th)], "wash_tile", V(0, 0, 1))
    # end walls with arched tunnel openings (both ends), back wall outside
    for side in (-1, 1):
        sw = SideWall(b, hw, D, side)
        wall_with_holes(sw, -D / 2, D / 2, 0, H, [(-6.0, 6.0, 0.0, 11.0)], "wall")
        for u, dd in ((-6.0, 1), (6.0, -1)):
            sw.face([fp(u, 0, 0), fp(u, 11.0, 0), fp(u, 11.0, -th), fp(u, 0, -th)], "canopy_band", fdir(dd))
        sw.face([fp(-6.0, 11.0, 0), fp(6.0, 11.0, 0), fp(6.0, 11.0, -th), fp(-6.0, 11.0, -th)], "canopy_band", V(0, -1, 0))
        fquad(sw, -6.8, 6.8, 11.0, 12.2, 0.15, "wash_roof")
    b.face([V(-hw, 0, D), V(hw, 0, D), V(hw, H, D), V(-hw, H, D)], "wall", V(0, 0, 1))
    # barrel roof (6 facets) along the tunnel, with gable ends
    prof = [(H, D + 0.6)]
    for k in range(7):
        a = math.pi * k / 6
        prof.append((H + math.sin(a) * 5.0, D / 2 + math.cos(a) * (D / 2 + 0.6)))
    prof = prof[1:]
    kitlib.sweep(b, prof, -hw - 0.6, hw + 0.6, "wash_roof", cap_sw="wash_tile")
    # name board standing on the roof front and the soap bubble cluster
    plate(b, [(-14.0, H + 0.4), (14.0, H + 0.4), (14.0, H + 4.4), (-14.0, H + 4.4)], -1.4, -1.0, "sign_face", "canopy_band")
    faces = [face_rec("name", fp(0, H + 2.4, -0.98), 27.0, 3.6)]
    for (u, v, r, sw) in ((-12.0, H + 6.4, 2.6, "bubble"), (-7.6, H + 7.6, 3.4, "bubble_hi"), (-2.6, H + 6.2, 2.2, "bubble"), (9.0, H + 6.8, 3.0, "bubble_hi"), (13.4, H + 5.8, 2.0, "bubble")):
        sphere(b, fp(u, v, -2.0), (r, r, r), [sw, "bubble", "bubble_hi"], subdiv=1)
    fr = finish(b, W)
    faces = [dict(f, centre=[round(f["centre"][0] + W / 2, 3), f["centre"][1], f["centre"][2]]) for f in faces]
    extra = {
        "brush_1": sock((hw - 13.0, 0.05, 6.5), frame=fr, mesh="B2_LM_CarWashBrush", spin="about +Y, about 0.5 turn/s (calm)"),
        "brush_2": sock((hw - 13.0, 0.05, D - 6.5), frame=fr, mesh="B2_LM_CarWashBrush", spin="about +Y, opposite"),
        "brush_3": sock((-hw + 13.0, 0.05, 6.5), frame=fr, mesh="B2_LM_CarWashBrush"),
        "brush_4": sock((-hw + 13.0, 0.05, D - 6.5), frame=fr, mesh="B2_LM_CarWashBrush"),
        "roller_1": sock((0.0, 9.0, D / 2), 90.0, frame=fr, mesh="B2_LM_CarWashRoller", spin="about its own X axis"),
    }
    return b, lot_meta("landmark", W, D, H + 10.0, 1, "landmark", "any", fr, H + 5.0, extra, faces=faces, landmark="SUDSY WHEELS CAR WASH", default_text={"name": "SUDSY WHEELS CAR WASH"}, moving_parts="separate meshes at brush_*/roller_* sockets; inside the lot, never in the drivable lane")


def wash_brush(name, horizontal=False):
    """A car-wash brush rig: a dark core and a star-section bristle drum in alternating blue and
    cyan facets (the rotation reads from the facets). Vertical by default (pivot at the base,
    turns about +Y); horizontal = the overhead roller (pivot at its centre, turns about +X)."""
    b = B2Builder(name)
    n = 12
    L = 10.0 if not horizontal else 11.0
    star = []
    for k in range(2 * n):
        a = math.pi * k / n
        r = 2.6 if k % 2 == 0 else 2.0
        star.append((math.cos(a) * r, math.sin(a) * r))

    def P(p, y):
        if horizontal:
            return V(y - L / 2, p[0], p[1])
        return V(p[0], y, p[1])

    y0, y1 = 0.7, L - 0.7
    for k in range(2 * n):
        a, c = star[k], star[(k + 1) % (2 * n)]
        sw = "brush_1" if (k // 2) % 2 == 0 else "brush_2"
        if horizontal:
            sw = "brush_3" if (k // 2) % 2 == 0 else "brush_1"
        mx, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
        b.face([P(a, y0), P(c, y0), P(c, y1), P(a, y1)], sw, P((mx, mz), 0) - P((0, 0), 0))
    for y, sgn in ((y0, -1), (y1, 1)):
        b.face([P(p, y) for p in star], "brush_core", (V(sgn, 0, 0) if horizontal else V(0, sgn, 0)))
    if horizontal:
        tube(b, [V(-L / 2 - 0.4, 0, 0), V(L / 2 + 0.4, 0, 0)], 0.35, 6, "brush_core")
    else:
        cyl(b, V(0, 0, 0), L + 0.8, 0.35, 6, "brush_core")
        box(b, V(0, L + 1.0, -1.4), (0.6, 0.6, 3.4), {"side": "brush_core"})
    return b, {
        "family": "LM",
        "part_of": "B2_LM_CarWash",
        "lod": "near",
        "district": "any",
        "pivot": "axis centre of the roller" if horizontal else "base of the brush axis",
        "spin_axis": "+X" if horizontal else "+Y",
        "sockets": {"axis": sock((0, 0, 0))},
        "motion": "calm: about 0.5 turn per second; stopped when Reduce Motion is on",
    }


# ---------------------------------------------------------------- service canopy (roadside)
def service_canopy(name):
    """PIT STOP SERVICE: a forecourt canopy 36 x 20 with a clear height of 18 (>= 16) on four
    sensible columns, two pump islands with fictional service pumps (air, water, wash: no fuel
    brand), and a small shop and a workshop bay behind. Lot 48 wide x 36 deep (a landmark lot:
    deeper than the 24 of frontage lots)."""
    b = lm(name, {"wall": "lm_wall", "base": "lm_wall"})
    W, D = 48.0, 36.0
    hw = W / 2
    b.face([V(-hw, 0.6, 0), V(hw, 0.6, 0), V(hw, 0.6, 26.0), V(-hw, 0.6, 26.0)], "deck_concrete", V(0, 1, 0))
    b.face([V(-hw, 0.0, 0), V(hw, 0.0, 0), V(hw, 0.6, 0), V(-hw, 0.6, 0)], "sidewalk_edge", V(0, 0, -1))
    CL = 18.0
    cz0, cz1 = 3.0, 23.0
    box(b, V(0, CL + 1.3, (cz0 + cz1) / 2), (36.0, 2.6, cz1 - cz0), {"side": "canopy_white", "bottom": "canopy_under", "top": "roof"})
    for z, nz in ((cz0 - 0.05, -1), (cz1 + 0.05, 1)):
        b.face([V(-18.0, CL + 0.1, z), V(18.0, CL + 0.1, z), V(18.0, CL + 0.6, z), V(-18.0, CL + 0.6, z)], "canopy_band", V(0, 0, nz))
    for x in (-18.05, 18.05):
        b.face([V(x, CL + 0.1, cz0), V(x, CL + 0.1, cz1), V(x, CL + 0.6, cz1), V(x, CL + 0.6, cz0)], "canopy_band", V(1 if x > 0 else -1, 0, 0))
    faces = [face_rec("canopy_front", V(0, CL + 1.6, cz0 - 0.08), 21.0, 1.4)]
    fquad(b, -11.0, 11.0, CL + 0.8, CL + 2.4, -cz0 + 0.07, "sign_face")
    for x in (-18.1, 18.1):
        sw = SideWall(b, 18.0, cz1 - cz0, 1 if x > 0 else -1, cz0)
        fquad(sw, -7.0, 7.0, CL + 0.8, CL + 2.4, 0.1, "sign_face")
        faces.append(face_rec("canopy_" + ("right" if x > 0 else "left"), V(x + (0.12 if x > 0 else -0.12), CL + 1.6, (cz0 + cz1) / 2), 13.0, 1.4, normal="Right" if x > 0 else "Left"))
    for x in (-12.0, 12.0):
        for z in (8.0, 18.0):
            box(b, V(x, 0.6 + (CL - 0.6) / 2, z), (1.6, CL - 0.6, 1.6), {"side": "canopy_white", "skip_bottom": True, "skip_top": True})
            box(b, V(x, 1.6, z), (2.2, 2.0, 2.2), {"side": "canopy_band", "top": "canopy_band", "skip_bottom": True})
    for k in range(6):
        x = -14.0 + 28.0 * (k % 3) / 2
        z = 8.0 if k < 3 else 18.0
        b.face([V(x - 1.5, CL - 0.02, z - 0.5), V(x + 1.5, CL - 0.02, z - 0.5), V(x + 1.5, CL - 0.02, z + 0.5), V(x - 1.5, CL - 0.02, z + 0.5)], "bulb", V(0, -1, 0))
    # two pump islands across the forecourt, two pumps each
    for x in (-5.0, 5.0):
        box(b, V(x, 0.9, 13.0), (3.0, 0.6, 12.0), {"side": "curb", "top": "curb_top", "skip_bottom": True})
        for z in (9.5, 16.5):
            box(b, V(x, 3.6, z), (1.8, 4.8, 1.4), {"side": "pump_body", "top": "pump_accent", "skip_bottom": True})
            box(b, V(x, 5.4, z), (1.9, 0.6, 1.5), {"side": "pump_accent", "skip_bottom": True, "skip_top": True})
            for sx in (-1, 1):
                b.face([V(x + sx * 0.92, 3.8, z - 0.4), V(x + sx * 0.92, 3.8, z + 0.4), V(x + sx * 0.92, 4.8, z + 0.4), V(x + sx * 0.92, 4.8, z - 0.4)], "glass_dark", V(sx, 0, 0))
            tube(b, [V(x + 0.9, 4.2, z), V(x + 1.5, 3.0, z), V(x + 1.3, 1.8, z + 0.3)], 0.12, 4, "reel_dark", cap=False)
    # shop (left) and workshop bay (right) at the back of the lot
    shop = Offset(b, 26.0)
    su0, su1, sH = 2.0, 22.0, 14.0  # facade u range (x -22..-2)
    holes = [(4.0, 10.0, 2.0, 9.0), (11.5, 15.1, 0.6, 9.0), (16.5, 20.5, 2.0, 9.0)]
    wall_with_holes(shop, su0, su1, 0.6, sH, holes, "wall")
    for a, c, h0, h1 in holes:
        window(shop, a, c, h0, h1, 0.8, WIN if h0 > 1 else {"reveal": "lm_wall_2", "glass": "sign_frame_1"}, sill=h0 > 1, lintel=False, split=0.55 if h0 > 1 else 0)
    strip_band(shop, su0, su1, sH - 2.8, sH - 0.6, 0.4, "canopy_band")
    strip_band(shop, su0, su1, sH - 0.6, sH, 0.3, "lm_trim")
    faces.append(face_rec("shop", V(-(su0 + su1) / 2, sH - 1.7, 26.0 - 0.45), 18.0, 1.6))
    box(b, V(-(su0 + su1) / 2, sH / 2, 31.0), (su1 - su0, sH, 10.0), {"side": "lm_wall", "top": "roof", "skip_bottom": True, "skip_front": True})
    ws = Offset(b, 24.0)
    wall_with_holes(ws, -22.0, -6.0, 0.6, 16.0, [(-19.0, -9.0, 0.6, 12.6)], "wall")
    window(ws, -19.0, -9.0, 0.6, 12.6, 0.8, {"reveal": "lm_wall_2", "glass": "depot_door"}, sill=False, lintel=False, split=0)
    for k in range(1, 5):
        fquad(ws, -18.8, -9.2, 0.6 + 12.0 * k / 5 - 0.15, 0.6 + 12.0 * k / 5 + 0.15, -0.75, "depot_door_dark")
    strip_band(ws, -22.0, -6.0, 15.0, 16.0, 0.3, "lm_trim")
    box(b, V(14.0, 8.0, 30.0), (16.0, 16.0, 12.0), {"side": "lm_wall", "top": "roof", "skip_bottom": True, "skip_front": True})
    fr = finish(b, W)
    faces = [dict(f, centre=[round(f["centre"][0] + W / 2, 3), f["centre"][1], f["centre"][2]]) for f in faces]
    return b, lot_meta("landmark", W, D, CL + 2.6, 1, "landmark", "any", fr, CL + 2.6, {}, faces=faces, landmark="PIT STOP SERVICE (service-station canopy)", clearance=CL, default_text={"canopy_front": "PIT STOP SERVICE", "canopy_left": "PIT STOP", "canopy_right": "PIT STOP", "shop": "SNACKS & MAPS"}, note="pumps are fictional air/water/wash service pumps; no fuel brand")


# ---------------------------------------------------------------- city hall and clock tower
def city_hall(name):
    """CITY HALL: a broad civic front 72 wide (a three-lot landmark) in cream stone. Wings of three
    storeys with arched ground-floor windows, giant pilasters and a balustraded parapet; a
    central hexastyle portico on a stepped podium under a pediment with a round civic emblem.
    The clock tower (B2_LM_ClockTower) stands on the roof behind the pediment at the clock_tower
    socket (its own visible base sits on the roof)."""
    b = lm(name, {"wall": "civic_stone", "base": "civic_shadow", "stone": "civic_column", "trim_1": "civic_column", "reveal": "civic_shadow", "door": "sign_frame_3"})
    W, D = 72.0, 24.0
    hw = W / 2
    GF, UP = 18.0, 14.0
    v = GF + 2 * UP  # 46
    for side in (-1, 1):
        a, c = (-hw, -15.0) if side < 0 else (15.0, hw)
        bays = [(a + 1.0 + 7.0 * i, a + 1.0 + 7.0 * i + 5.0) for i in range(3)]
        wall_with_holes(b, a, c, 0, GF, [(u0, u1, 2.0, 13.0) for u0, u1 in bays], "wall")
        for u0, u1 in bays:
            arch_window(b, u0, u1, 2.0, 13.0, 1.2, "wall", {"reveal": "civic_shadow", "glass": "glass", "lintel": "civic_column", "sill": "civic_column"}, seg=4)
        for k in range(1, 4):
            fquad(b, a, c, GF * k / 4 - 0.18, GF * k / 4, 0.1, "civic_shadow")
        holes = []
        for f in range(2):
            for u0, u1 in bays:
                holes.append((u0 + 0.8, u1 - 0.8, GF + f * UP + 2.6, GF + f * UP + 11.0))
        wall_with_holes(b, a, c, GF, v, holes, "wall")
        for h in holes:
            window(b, *h, 1.2, {"reveal": "civic_shadow", "glass": "glass", "glass_light": "glass_light", "sill": "civic_column", "mullion": "civic_column"}, lintel=False, mullion=True)
            fbox(b, h[0] - 0.7, h[1] + 0.7, h[3] + 0.2, h[3] + 0.9, 0, 0.6, "civic_column")
        for u in (a, a + 7.5, a + 14.5, c - 0.9):
            pier(b, u, u + 0.9, GF, v, 0.45, "civic_column")
        strip_band(b, a, c, GF - 1.0, GF, 0.6, "civic_column")
    # the centre: wall set back 8 behind the portico, three arched doors, upper windows
    cb = Offset(b, 8.0)
    doors = [(-9.0, -5.0), (-2.0, 2.0), (5.0, 9.0)]
    wall_with_holes(cb, -15.0, 15.0, 0, v, [(u0, u1, 6.0, 17.0) for u0, u1 in doors] + [(u0 + 0.4, u1 - 0.4, 24.0, 33.0) for u0, u1 in doors], "wall")
    for u0, u1 in doors:
        kitlib.opening(cb, u0, u1, 6.0, 17.0, "arch", 1.4, "wall", "civic_shadow", "sign_frame_3", arc_seg=4)
        window(cb, u0 + 0.4, u1 - 0.4, 24.0, 33.0, 1.0, {"reveal": "civic_shadow", "glass": "glass", "glass_light": "glass_light", "sill": "civic_column"}, lintel=False)
    for x in (-15.0, 15.0):
        b.face([V(x, 0, 0), V(x, 0, 8.0), V(x, v, 8.0), V(x, v, 0)], "civic_stone", V(1 if x < 0 else -1, 0, 0))
    # stepped podium (4 steps) and the portico
    for k in range(4):
        z0 = 1.5 * k
        box(b, V(0, 0.6 + 1.35 * (k + 0.5), (z0 + 8.0) / 2), (30.0 - 0.6 * k, 1.35, 8.0 - z0), {"side": "civic_column", "top": "civic_stone", "skip_bottom": True, "skip_back": True})
    ytop = 0.6 + 1.35 * 4
    cols = [-12.5 + 5.0 * i for i in range(6)]
    for x in cols:
        box(b, V(x, ytop + 0.5, 2.0), (3.0, 1.0, 3.0), {"side": "civic_column", "skip_bottom": True})
        cyl(b, V(x, ytop + 1.0, 2.0), 38.0 - ytop - 2.0, 1.25, 8, "civic_column", top=False, r_top=1.1)
        box(b, V(x, 38.0 - 0.5, 2.0), (3.0, 1.0, 3.0), {"side": "civic_column", "skip_top": True})
    box(b, V(0, 40.0, 3.6), (31.0, 4.0, 7.6), {"side": "civic_stone", "bottom": "civic_shadow", "top": "civic_roof", "skip_back": True})
    fquad(b, -15.5, 15.5, 41.2, 41.8, 0.25, "civic_shadow")
    # pediment: a triangular block with a gilt round emblem in the tympanum
    pd = [(-15.8, 42.0), (15.8, 42.0), (0.0, 51.0)]
    plate(b, pd, -7.4, 0.2, "civic_stone", "civic_column")
    b.face([fp(u, v_, 0.32) for u, v_ in circle_uv(0, 45.4, 2.0, 10)], "gilt", V(0, 0, -1))
    # wing cornice, balustraded parapet
    for a, c in ((-hw, -15.0), (15.0, hw)):
        strip_band(b, a, c, v, v + 1.4, 0.45, "civic_column", top=False)
        cornice(b, a - (0.4 if a < -20 else 0), c + (0.4 if c > 20 else 0), v + 1.4, 2.4, "civic_column", 2.2)
        box(b, V(-(a + c) / 2, v + 4.8, 0.4), (c - a, 2.4, 0.8), {"side": "civic_stone", "top": "civic_column", "skip_bottom": True})
        for k in range(3):
            u0 = a + (c - a) * (k + 0.12) / 3
            u1 = a + (c - a) * (k + 0.88) / 3
            fquad(b, u0, u1, v + 4.0, v + 5.6, -0.01, "civic_shadow")
    roof_y = v + 3.0
    b.face([V(-hw, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "civic_roof", V(0, 1, 0))
    body(b, W, 0, v + 3.6, D, side="civic_stone", back="civic_stone")
    fr = finish(b, W)
    extra = {
        "clock_tower": sock((0.0, roof_y, 15.0), frame=fr, mesh="B2_LM_ClockTower"),
        "flag_left": sock((-25.5, v + 6.0, 0.4), frame=fr),
        "flag_right": sock((25.5, v + 6.0, 0.4), frame=fr),
        "lamp_left": sock((-17.0, 0.6, 1.0), frame=fr, mesh="B2_Street_LampFormal"),
        "lamp_right": sock((17.0, 0.6, 1.0), frame=fr, mesh="B2_Street_LampFormal"),
    }
    faces = [face_rec("frieze", V(0 + W / 2, 40.0, -0.25), 22.0, 2.4)]
    return b, lot_meta("landmark", W, D, 51.0, 3, "landmark", "CH", fr, roof_y, extra, faces=faces, landmark="CITY HALL", default_text={"frieze": "CITY HALL"})


def clock_tower(name):
    """The clock tower: a rusticated base (visible, 16 square), a panelled shaft, a clock stage with
    four faces (gilt rims, hour marks, hands at ten past ten), an open belfry of four piers, and a
    purposeful roof: a copper ogee spire with a gilt finial. 88 tall. Pivot at the bottom centre;
    stands on City Hall's clock_tower socket or a plaza feature socket."""
    b = B2Builder(name)
    box(b, V(0, 3.0, 0), (16.0, 6.0, 16.0), {"side": "civic_stone", "top": "civic_column", "skip_bottom": True})
    for y in (1.5, 3.5):
        for k in range(4):
            yaw = math.pi / 2 * k
            n = V(math.sin(yaw), 0, math.cos(yaw))
            t = V(math.cos(yaw), 0, -math.sin(yaw))
            c = n * 8.03 + V(0, y, 0)
            b.face([c - t * 8.0 - V(0, 0.12, 0), c + t * 8.0 - V(0, 0.12, 0), c + t * 8.0 + V(0, 0.12, 0), c - t * 8.0 + V(0, 0.12, 0)], "civic_shadow", n)
    box(b, V(0, 6.4, 0), (17.0, 0.8, 17.0), {"side": "civic_column", "top": "civic_column", "skip_bottom": True})
    box(b, V(0, 23.4, 0), (12.0, 33.2, 12.0), {"side": "civic_stone", "skip_bottom": True, "skip_top": True})
    for k in range(4):
        yaw = math.pi / 2 * k
        n = V(math.sin(yaw), 0, math.cos(yaw))
        t = V(math.cos(yaw), 0, -math.sin(yaw))
        c = n * 6.03
        b.face([c + t * 3.2 + V(0, 10.0, 0), c - t * 3.2 + V(0, 10.0, 0), c - t * 3.2 + V(0, 36.0, 0), c + t * 3.2 + V(0, 36.0, 0)], "civic_shadow", n)
    # clock stage
    box(b, V(0, 40.0, 0), (14.6, 1.2, 14.6), {"side": "civic_column", "top": "civic_column"})
    box(b, V(0, 47.0, 0), (13.6, 13.0, 13.6), {"side": "civic_stone", "skip_bottom": True, "skip_top": True})
    box(b, V(0, 54.2, 0), (15.0, 1.4, 15.0), {"side": "civic_column", "top": "civic_column"})
    faces = []
    for k in range(4):
        yaw = math.pi / 2 * k
        n = V(math.sin(yaw), 0, math.cos(yaw))
        t = V(math.cos(yaw), 0, -math.sin(yaw))
        c = n * 6.85 + V(0, 47.0, 0)
        ring_o = [c + (t * math.cos(2 * math.pi * j / 12) + V(0, math.sin(2 * math.pi * j / 12), 0)) * 4.9 for j in range(12)]
        ring_i = [c + (t * math.cos(2 * math.pi * j / 12) + V(0, math.sin(2 * math.pi * j / 12), 0)) * 4.3 + n * 0.05 for j in range(12)]
        for j in range(12):
            j2 = (j + 1) % 12
            b.face([ring_o[j], ring_o[j2], ring_i[j2], ring_i[j]], "gilt", n)
        b.face(ring_i, "clock_face", n)
        for j in range(4):
            a = math.pi / 2 * j
            d = t * math.cos(a) + V(0, math.sin(a), 0)
            p = c + n * 0.1 + d * 3.6
            w = t * -math.sin(a) + V(0, math.cos(a), 0)
            b.face([p - w * 0.25, p + w * 0.25, p + w * 0.25 + d * 0.6, p - w * 0.25 + d * 0.6], "clock_hand", n)
        for ang, ln, wd in ((math.radians(30), 3.0, 0.35), (math.radians(150), 2.1, 0.45)):
            d = t * math.cos(ang) + V(0, math.sin(ang), 0)
            w = t * -math.sin(ang) + V(0, math.cos(ang), 0)
            p = c + n * 0.14
            b.face([p - w * wd / 2, p + w * wd / 2, p + d * ln + w * wd / 4, p + d * ln - w * wd / 4], "clock_hand", n)
        faces.append({"name": f"clock_{k}", "centre": [round(c.x, 3), round(c.y, 3), round(c.z, 3)], "size": [9.8, 9.8], "normal": [round(n.x, 3), 0, round(n.z, 3)], "kind": "clock (no text)"})
    # open belfry: four corner piers, a dark bell space, a cornice
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(b, V(sx * 5.4, 60.0, sz * 5.4), (2.8, 10.0, 2.8), {"side": "civic_stone", "skip_bottom": True, "skip_top": True})
    box(b, V(0, 60.0, 0), (7.0, 10.0, 7.0), {"side": "roof_dark", "skip_bottom": True, "skip_top": True})
    box(b, V(0, 65.6, 0), (15.4, 1.4, 15.4), {"side": "civic_column", "top": "copper_dark", "bottom": "civic_shadow"})
    # copper ogee roof: flare, neck, spire; gilt finial
    cyl(b, V(0, 66.3, 0), 3.0, 7.4, 8, "copper", top=False, r_top=5.6, phase=math.pi / 8)
    cyl(b, V(0, 69.3, 0), 2.2, 5.6, 8, "copper_dark", top=False, r_top=4.4, phase=math.pi / 8)
    cyl(b, V(0, 71.5, 0), 11.0, 4.4, 8, "copper", top=False, r_top=0.6, phase=math.pi / 8)
    sphere(b, V(0, 83.2, 0), (0.9, 0.9, 0.9), ["gilt", "gilt"], subdiv=0)
    cyl(b, V(0, 84.0, 0), 4.0, 0.25, 4, "gilt", r_top=0.02)
    return b, {
        "family": "LM",
        "landmark": "CLOCK TOWER",
        "height": 88.0,
        "footprint": 16.0,
        "lod": "near",
        "district": "CH",
        "pivot": "bottom centre of the base",
        "sockets": {"base": sock((0, 0, 0))},
        "faces": faces,
        "mount": "B2_LM_CityHall.clock_tower (roof, base visible above the roofline) or B2_Lot_Plaza48.feature",
    }


# ---------------------------------------------------------------- harbor bridge arches
def bridge_arches(name, W):
    """HARBOR BRIDGE: twin steel tied arches over a 192-stud span of B2_Road_BridgeDeck pieces,
    standing just outside the deck edge (never over the sidewalks or lanes), crown 44 above the
    deck, vertical hangers every 12, and lateral bracing between the arches only where they are
    at least 30 above the road (clearance >= 18 holds with margin). Pivot = the span start on
    the road centre line at deck level (the deck pieces' start socket)."""
    d = dims(W)
    b = B2Builder(name)
    L, Hc = 192.0, 44.0
    ax = d["frontage"] + 1.6
    n = 16

    def y_at(t):
        return Hc * (1 - (2 * t - 1) ** 2)

    for sx in (-1, 1):
        x = sx * ax
        path = [V(x, max(1.2, y_at(k / n)), -L * k / n) for k in range(n + 1)]
        tube(b, path, 1.25, 4, "bridge_steel", phase=math.pi / 4)
        box(b, V(x, 0.0, -L / 2), (2.2, 2.6, L), {"side": "bridge_steel_dark", "top": "bridge_steel"})
        for z in range(12, int(L), 12):
            t = z / L
            beam(b, V(x, 1.3, -z), V(x, y_at(t) - 0.8, -z), 0.3, 0.3, "bridge_light")
        for z in (0.0, -L):
            box(b, V(x, -2.4, z + (2.5 if z == 0.0 else -2.5)), (4.0, 4.4, 6.0), {"side": "quay_stone", "top": "quay_top"})
    braced = [k for k in range(n + 1) if y_at(k / n) >= 30.0]
    for k in braced:
        y = y_at(k / n)
        beam(b, V(-ax, y, -L * k / n), V(ax, y, -L * k / n), 0.9, 0.9, "bridge_steel")
    for i in range(len(braced) - 1):
        k0, k1 = braced[i], braced[i + 1]
        y0, y1 = y_at(k0 / n), y_at(k1 / n)
        beam(b, V(-ax, y0, -L * k0 / n), V(ax, y1, -L * k1 / n), 0.5, 0.5, "bridge_steel_dark")
        beam(b, V(ax, y0, -L * k0 / n), V(-ax, y1, -L * k1 / n), 0.5, 0.5, "bridge_steel_dark")
    low = min(y_at(k / n) for k in braced)
    return b, {
        "family": "LM",
        "landmark": "HARBOR BRIDGE (twin tied arches)",
        "length": L,
        "laneWidth": W,
        "arch_x": ax,
        "crown": Hc,
        "lowest_overhead_member": round(low, 2),
        "clearance_rule": ">= 18 over the road",
        "lod": "near",
        "district": "HB",
        "pivot": "span start on the road centre line at deck level (y 0)",
        "sockets": {"start": sock((0, 0, 0)), "end": sock((0, 0, -L))},
        "pairs_with": [f"B2_Road_BridgeDeck192_L4W{W}", f"B2_Road_Abutment96_L4W{W}", "B2_Harbor_Pier", "B2_Harbor_Water"],
    }


# ---------------------------------------------------------------- park fountain
def fountain(name):
    """The Skyline Park fountain: a 16-sided stone basin 24 across, a pedestal with two bowls,
    spill curtains and a small top jet; water surfaces are pale opaque water swatches (no
    Transparency). Pivot at the bottom centre (on the park lot's feature socket)."""
    b = B2Builder(name)
    n = 16
    R0, R1, top = 12.0, 11.0, 2.0
    out = kitlib.circle2(0, 0, R0, n)
    inn = kitlib.circle2(0, 0, R1, n)
    for k in range(n):
        k2 = (k + 1) % n
        (ax, az), (cx, cz) = out[k], out[k2]
        (ix, iz), (jx, jz) = inn[k], inn[k2]
        b.face([V(ax, 0, az), V(cx, 0, cz), V(cx, top, cz), V(ax, top, az)], "fountain_stone", V((ax + cx) / 2, 0, (az + cz) / 2))
        b.face([V(ax, top, az), V(cx, top, cz), V(jx, top, jz), V(ix, top, iz)], "fountain_dark" if k % 2 else "fountain_stone", V(0, 1, 0))
        b.face([V(ix, top, iz), V(jx, top, jz), V(jx, 1.3, jz), V(ix, 1.3, iz)], "fountain_dark", V(-(ix + jx) / 2, 0, -(iz + jz) / 2))
    b.face([V(x, 1.3, z) for x, z in inn], "fountain_water", V(0, 1, 0))
    cyl(b, V(0, 1.3, 0), 5.0, 1.4, 8, "fountain_stone", top=False)
    cyl(b, V(0, 6.3, 0), 1.0, 1.4, 8, "fountain_stone", top=False, r_top=5.0)
    cyl(b, V(0, 7.3, 0), 0.6, 5.0, 8, "fountain_dark", top=False)
    b.face([V(x, 7.7, z) for x, z in kitlib.circle2(0, 0, 4.7, 8)], "fountain_water", V(0, 1, 0))
    cyl(b, V(0, 1.4, 0), 6.0, 5.2, 8, "fountain_water_hi", top=False, r_top=5.1)
    cyl(b, V(0, 7.9, 0), 3.0, 0.8, 6, "fountain_stone", top=False)
    cyl(b, V(0, 10.9, 0), 0.7, 0.8, 6, "fountain_stone", top=False, r_top=2.8)
    b.face([V(x, 11.5, z) for x, z in kitlib.circle2(0, 0, 2.6, 6)], "fountain_water", V(0, 1, 0))
    cyl(b, V(0, 8.0, 0), 3.5, 2.9, 6, "fountain_water_hi", top=False, r_top=2.85)
    cyl(b, V(0, 11.6, 0), 2.6, 0.5, 5, "fountain_water_hi", r_top=0.05)
    return b, {"family": "LM", "landmark": "PARK FOUNTAIN", "height": 14.2, "diameter": 24.0, "lod": "near", "district": "SP", "pivot": "bottom centre", "sockets": {"base": sock((0, 0, 0))}, "water": "opaque pale water swatches (no Transparency); an optional particle spray is a Studio-side choice", "mount": "B2_Lot_Park48.feature"}


# ---------------------------------------------------------------- donut bakery (roadside)
def donut_ring(b, c, R, r, nmaj=16, nmin=8):
    """A standing donut whose ring lies in the plane x = c.x (it faces +X and -X: along the
    road), icing on both flat faces with a wavy edge, dough on the rims, flat sprinkles."""
    pts = []
    for i in range(nmaj):
        a = 2 * math.pi * i / nmaj
        row = []
        for j in range(nmin):
            t = 2 * math.pi * j / nmin
            rr = R + r * math.cos(t)
            row.append(c + V(r * math.sin(t), math.cos(a) * rr, math.sin(a) * rr))
        pts.append(row)
    for i in range(nmaj):
        i2 = (i + 1) % nmaj
        a = 2 * math.pi * (i + 0.5) / nmaj
        ring_c = c + V(0, math.cos(a) * R, math.sin(a) * R)
        for j in range(nmin):
            j2 = (j + 1) % nmin
            q = [pts[i][j], pts[i2][j], pts[i2][j2], pts[i][j2]]
            cen = sum(q, V(0)) / 4
            out = (cen - ring_c).normalized()
            wave = 0.28 + 0.12 * math.sin(i * 1.7)
            if abs(out.x) > wave + 0.25:
                sw = "donut_icing_hi" if out.y > 0.3 else "donut_icing"
            else:
                sw = "donut_dough" if out.y > -0.2 else "donut_dough_dark"
            b.face(q, sw, out)
    cols = ["sprinkle_1", "sprinkle_2", "sprinkle_3", "sprinkle_4"]
    for k in range(10):
        a = 2 * math.pi * (k + 0.3) / 10
        rr = R + (0.5 if k % 2 else -0.4) * r
        for sx in (-1, 1):
            p = c + V(sx * (r * 0.97 + 0.02), math.cos(a) * rr, math.sin(a) * rr)
            dvec = V(0, -math.sin(a + k), math.cos(a + k)) * 0.45
            w = V(0, math.cos(a + k), math.sin(a + k)) * 0.12
            b.face([p - dvec - w, p + dvec - w, p + dvec + w, p - dvec + w], cols[k % 4], V(sx, 0, 0))


def donut_bakery(name):
    """SPARE TIRE DONUTS: a two-storey brick bakery (36 wide) whose giant donut stands on the roof
    in a steel cradle bolted to the roof structure (two posts, a saddle beam and diagonal braces
    down to the roof): the donut is structurally attached, not floating. The ring faces along the
    road, so the chase camera sees its full circle on approach. A pink and teal shopfront."""
    b = lm(name, {"wall": "lm_brick", "base": "lm_wall", "aw": "donut_icing", "aw2": "sign_frame_1", "shop": "sign_frame_1"})
    W, D = 36.0, 22.0
    hw = W / 2
    GF = 16.0
    shop_ground(b, 36, GF)
    uppers_pairs(b, W, GF, 1)
    v = GF + STOREY
    strip_band(b, -hw, hw, v, v + 1.0, 0.3, "lm_trim", top=False)
    cornice(b, -hw - 0.3, hw + 0.3, v + 1.0, 1.8, "lm_trim", 1.8)
    parapet(b, W, v + 2.8, v + 4.2, D, "wall", "lm_trim")
    roof_y = v + 2.4
    b.face([V(-hw, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-hw, roof_y, D)], "roof", V(0, 1, 0))
    body(b, W, 0, v + 2.8, D)
    # name board on the sign band
    plate(b, [(-15.6, 11.9), (13.4, 11.9), (13.4, 14.7), (-15.6, 14.7)], 0.3, 0.6, "sign_face", "sign_frame_1", back=False)
    faces = [face_rec("name", fp(-1.1, 13.3, 0.62), 28.0, 2.4)]
    # the cradle: two posts on a roof beam, a saddle and four braces; the donut sits in the saddle
    cz = 9.0
    R, r = 6.4, 2.7
    cy = roof_y + 6.0 + R + r - 0.6
    box(b, V(0, roof_y + 0.4, cz), (2.0, 0.8, 14.0), {"side": "iron", "skip_bottom": True})
    for z in (cz - 4.0, cz + 4.0):
        box(b, V(0, roof_y + 3.4, z), (1.0, 6.0, 1.0), {"side": "iron", "skip_bottom": True})
        beam(b, V(0, roof_y + 0.8, z + (5.5 if z > cz else -5.5)), V(0, roof_y + 5.4, z), 0.25, 0.25, "iron_light")
    box(b, V(0, roof_y + 6.6, cz), (1.6, 1.2, 9.6), {"side": "iron"})
    for z in (cz - 3.0, cz + 3.0):
        box(b, V(0, roof_y + 7.8, z), (1.4, 1.6, 0.6), {"side": "iron"})
    donut_ring(b, V(0, cy, cz), R, r)
    fr = finish(b, W)
    faces = [dict(f, centre=[round(f["centre"][0] + W / 2, 3), f["centre"][1], f["centre"][2]]) for f in faces]
    return b, lot_meta("landmark", W, D, cy + R + r, 2, "landmark", "any", fr, roof_y, {}, faces=faces, landmark="SPARE TIRE DONUTS (donut bakery)", default_text={"name": "SPARE TIRE DONUTS"}, sign="the donut is mounted on a steel cradle bolted to a roof beam (structural)")


# ---------------------------------------------------------------- delivery depot (roadside)
def delivery_depot(name):
    """BOX HOP DELIVERY DEPOT (replaces the base prompt's fire station: AGENTS.md vehicle rule 5).
    A 48-wide brick depot hall with three roll-up loading doors, a two-storey stone office, a
    stepped parapet and a giant parcel (cardboard box with tape) perched at a jaunty angle on a
    roof cradle. Teal and navy accents; no red-and-white emergency livery anywhere."""
    b = lm(name, {"wall": "lm_brick", "base": "lm_brick"})
    W, D = 48.0, 24.0
    hw = W / 2
    HH = 22.0
    hall = (-hw, 10.0)
    doors = [(-22.0, -14.4), (-12.4, -4.8), (-2.8, 4.8)]
    wall_with_holes(b, hall[0], hall[1], 0, HH, [(a, c, 0.0, 12.6) for a, c in doors], "wall")
    for a, c in doors:
        window(b, a, c, 0.0, 12.6, 0.9, {"reveal": "lm_wall_2", "glass": "depot_door"}, sill=False, lintel=False, split=0)
        for k in range(1, 5):
            fquad(b, a + 0.15, c - 0.15, 12.6 * k / 5 - 0.15, 12.6 * k / 5 + 0.15, -0.85, "depot_door_dark")
        fquad(b, a - 0.5, c + 0.5, 12.6, 13.4, 0.2, "sign_frame_1")
    strip_band(b, hall[0], hall[1], 0, 1.0, 0.3, "lm_wall_2", bottom=False)
    plate(b, [(-21.0, 15.0), (7.0, 15.0), (7.0, 18.6), (-21.0, 18.6)], 0.0, 0.4, "sign_face", "sign_frame_3", back=False)
    faces = [face_rec("name", fp(-7.0, 16.8, 0.42), 27.0, 3.2)]
    strip_band(b, hall[0], hall[1], HH - 1.0, HH, 0.4, "lm_trim")
    y = HH
    for pw, ph in ((W * 0.5, 2.4), (W * 0.24, 2.0)):
        box(b, V(7.0, y + ph / 2, 0.4), (pw, ph, 0.8), {"side": "wall", "top": "lm_trim", "skip_bottom": True})
        y += ph
    # office: two storeys of stone with windows and a door
    off = (10.0, hw)
    holes = [(12.0, 16.4, 0.0, 8.6), (18.0, 22.4, 2.0, 9.4)] + [(u0, u1, 16.4, 22.6) for u0, u1 in ((11.8, 15.8), (18.0, 22.0))]
    wall_with_holes(b, off[0], off[1], 0, 26.0, holes, "lm_wall")
    shop_door(b, 12.0, 16.4)
    window(b, 18.0, 22.4, 2.0, 9.4, 1.0, WIN, mullion=True)
    for h in holes[2:]:
        window(b, *h, 1.0, WIN, mullion=True)
    strip_band(b, off[0], off[1], 12.6, 13.4, 0.3, "sign_frame_1")
    strip_band(b, off[0], off[1], 26.0, 27.2, 0.5, "lm_trim")
    pier(b, 9.6, 10.6, 0, 26.0, 0.4, "lm_trim")
    # giant parcel on a low cradle, tilted 12 degrees
    roof_y = HH - 0.6
    pc = V(7.0, roof_y + 1.0 + 4.0, 11.0)
    yaw = math.radians(12)
    box(b, V(7.0, roof_y + 0.5, 11.0), (8.0, 1.0, 6.0), {"side": "iron", "skip_bottom": True})
    box(b, pc, (11.0, 8.0, 8.0), {"side": "parcel", "top": "parcel", "front": "parcel_dark", "skip_bottom": True}, yaw=yaw)
    cs, sn = math.cos(yaw), math.sin(yaw)

    def R(x, y_, z):
        return pc + V(x * cs + z * sn, y_, -x * sn + z * cs)

    b.face([R(-1.0, 4.02, -4.0), R(1.0, 4.02, -4.0), R(1.0, 4.02, 4.0), R(-1.0, 4.02, 4.0)], "parcel_tape", V(0, 1, 0))
    b.face([R(-1.0, -4.0, -4.02), R(1.0, -4.0, -4.02), R(1.0, 4.0, -4.02), R(-1.0, 4.0, -4.02)], "parcel_tape", V(-sn, 0, -cs))
    b.face([R(-5.5, 1.2, -4.03), R(-2.2, 1.2, -4.03), R(-2.2, 3.0, -4.03), R(-5.5, 3.0, -4.03)], "emblem_white", V(-sn, 0, -cs))
    b.face([V(-10.0, roof_y, 0.8), V(hw, roof_y, 0.8), V(hw, roof_y, D), V(-10.0, roof_y, D)], "roof", V(0, 1, 0))
    b.face([V(-10.0, 25.4, 0.0), V(-hw, 25.4, 0.0), V(-hw, 25.4, D), V(-10.0, 25.4, D)], "roof", V(0, 1, 0))
    b.face([V(hw, 0, 0), V(hw, 0, D), V(hw, HH, D), V(hw, HH, 0)], "wall", V(1, 0, 0))
    b.face([V(-10.0, 0, D), V(hw, 0, D), V(hw, HH, D), V(-10.0, HH, D)], "wall", V(0, 0, 1))
    b.face([V(-hw, 0, 0), V(-hw, 0, D), V(-hw, 27.2, D), V(-hw, 27.2, 0)], "lm_wall", V(-1, 0, 0))
    b.face([V(-10.0, HH, 0), V(-10.0, HH, D), V(-10.0, 27.2, D), V(-10.0, 27.2, 0)], "lm_wall", V(1, 0, 0))
    b.face([V(-hw, 0, D), V(-10.0, 0, D), V(-10.0, 27.2, D), V(-hw, 27.2, D)], "lm_wall", V(0, 0, 1))
    fr = finish(b, W)
    faces = [dict(f, centre=[round(f["centre"][0] + W / 2, 3), f["centre"][1], f["centre"][2]]) for f in faces]
    extra = {"bollard_1": sock((13.4, 0.6, -1.0), frame=fr), "bollard_2": sock((3.8, 0.6, -1.0), frame=fr), "bollard_3": sock((-6.0, 0.6, -1.0), frame=fr)}
    return b, lot_meta("landmark", W, D, roof_y + 9.0, 2, "landmark", "any", fr, roof_y, extra, faces=faces, landmark="BOX HOP DELIVERY DEPOT (replaces the fire station)", default_text={"name": "BOX HOP DELIVERY"})


# ---------------------------------------------------------------- catalogue
def build_all(emit):
    emit(*theater("B2_LM_Theater"))
    emit(*car_wash("B2_LM_CarWash"))
    emit(*wash_brush("B2_LM_CarWashBrush"))
    emit(*wash_brush("B2_LM_CarWashRoller", horizontal=True))
    emit(*service_canopy("B2_LM_ServiceCanopy"))
    emit(*city_hall("B2_LM_CityHall"))
    emit(*clock_tower("B2_LM_ClockTower"))
    for W in (16, 17, 18):
        emit(*bridge_arches(f"B2_LM_BridgeArch192_L4W{W}", W))
    emit(*fountain("B2_LM_Fountain"))
    emit(*donut_bakery("B2_LM_DonutBakery"))
    emit(*delivery_depot("B2_LM_DeliveryDepot"))
