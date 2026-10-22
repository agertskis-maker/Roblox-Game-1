# Downtown look development, direction C "Big Bright Metropolis": glass podiums at the
# frontage, towers set back 30+ behind them, a sky bridge set back between two midground towers,
# roof gardens, one screen, the elevated train crossing (s 320, underside 44) with the station on
# the left, and the distant arena dome closing the vista. Road, hazards and furniture come from
# layout.py (identical in A, B and C). Called by layout.py --dir C.

import fixture as F

RAIL_S = 320.0
RAIL_KEEP = (296.0, 344.0)


def compose(L, M, rng, kind, w, s_c, side, setback, quiet):
    pos, yaw = M.facade_pose(s_c, side, setback)
    two = rng.random() < 0.55
    if kind == "corner":
        cw = rng.choice(["1", "2"])
        L.add(f"C_PodiumCornerBase_{cw}", pos, yaw, band="frontage")
        y = 16
        if two:
            L.add(f"C_PodiumCornerUpper_{cw}", M.vadd(pos, [0, 16, 0]), yaw, band="frontage")
            y = 32
        L.add(f"C_PodiumCornerTop_{cw}", M.vadd(pos, [0, y, 0]), yaw, band="frontage")
        return pos, yaw, y
    cw = "q" if quiet else rng.choice(["1", "2", "3"])
    W = int(w)
    L.add(f"C_Podium{W}_{cw}", pos, yaw, band="frontage")
    y = 16
    if two:
        L.add(f"C_PodiumUpper{W}_{cw}", M.vadd(pos, [0, 16, 0]), yaw, band="frontage")
        y = 32
    L.add(f"C_PodiumTop{W}_{cw}", M.vadd(pos, [0, y, 0]), yaw, band="frontage")
    return pos, yaw, y


def tower(L, M, rng, s, off, side, height, slim=False, cw=None):
    cw = cw or rng.choice(["1", "2", "3"])
    p = F.point(s, off)
    yaw = F.yaw_facing_road(s, side) + rng.choice([0, 0, 90])
    w = 24.0 if slim else 36.0
    # the module's pivot is its front-face centre: shift so the tower is centred on p
    from math import cos, radians, sin

    a = radians(yaw)
    p = [p[0] - sin(a) * 0 - (w / 2) * sin(a), 0.0, p[2] - (w / 2) * cos(a)]
    n = max(2, int(round(height / 48)))
    mid = "C_TowerSlim48" if slim else "C_TowerMid48"
    crown = "C_TowerCrownSlim" if slim else "C_TowerCrown"
    for k in range(n):
        L.add(f"{mid}_{cw}", M.vadd(p, [0, 48 * k, 0]), yaw, band="tower")
    L.add(f"{crown}_{cw}", M.vadd(p, [0, 48 * n, 0]), yaw, band="tower")
    return p, yaw, 48 * n


def build(L, rng, M):
    M.common_road(L)
    M.common_hazards(L)
    M.common_furniture(L, "TreeRound")
    placed = []
    blocks = {1: [(-62, 90), (130, 236.5), (RAIL_KEEP[1] - 10, 482)], -1: [(-62, 236.5), (RAIL_KEEP[1] - 10, 482)]}
    for side, segs in blocks.items():
        for s0, s1 in segs:
            for kind, w, s_c, sb in M.fill_block(s0, s1, side, rng, [24, 24, 12], alley_every=(2, 3), alley_w=(10, 14), setback_p=0.0):
                q = M.near_hazard(s_c, side) and kind != "corner"
                pos, yaw, top_y = compose(L, M, rng, kind, w, s_c, side, sb, q)
                placed.append((kind, w, s_c, side, pos, yaw, top_y))
                if kind == "mid" and w == 24 and rng.random() < 0.35:
                    L.add_local("C_RoofGarden", pos, yaw, (0, top_y + 0.3, 13.0), band="frontage")
                elif kind == "mid" and rng.random() < 0.4:
                    L.add_local("RoofAC", pos, yaw, (rng.uniform(-4, 4), top_y + 0.3, 16.0), band="frontage")
    # towers set back 30+ behind the frontage line, framing sky gaps (not a continuous wall)
    for side in (1, -1):
        s = -40.0 + (0 if side > 0 else 35.0)
        while s < 470:
            ok = not (205 < s < 325) and not (side > 0 and 80 < s < 140)
            if ok:
                off = side * (F.FRONTAGE + 30 + rng.uniform(18, 26))
                tower(L, M, rng, s, off, side, rng.choice([150, 190, 240, 290]), slim=rng.random() < 0.4)
            s = M.advance(s, rng.uniform(75, 105), side * (F.FRONTAGE + 50))
    # midground: taller towers, and one sky bridge set back between a pair of them
    for side in (1, -1):
        s = -120.0 + rng.uniform(0, 30)
        while s < 640:
            bad = 205 < s < 330 or (side > 0 and 80 < s < 140)
            if not bad:
                tower(L, M, rng, s, side * (F.FRONTAGE + rng.uniform(110, 140)), side, rng.choice([200, 250, 300]), slim=rng.random() < 0.3)
            s = M.advance(s, rng.uniform(70, 95), side * (F.FRONTAGE + 120))
    # the sky bridge: two slim towers on the left, about 130 back, at s 380 and 412
    pa, ya, _ = tower(L, M, rng, 380.0, -(F.FRONTAGE + 128), -1, 240, slim=True, cw="2")
    pb, yb, _ = tower(L, M, rng, 414.0, -(F.FRONTAGE + 128), -1, 240, slim=True, cw="1")
    mid = [(pa[0] + pb[0]) / 2, 96.0, (pa[2] + pb[2]) / 2]
    # the towers' pivots are their front faces; the bridge spans between their centres
    cx = F.point(397.0, -(F.FRONTAGE + 128))
    L.add("C_SkyBridge", [cx[0], 96.0, cx[2]], F.yaw_along(397.0) + 90, band="tower", note="set back 128 from the frontage line, between two slim towers")
    # the landmark: elevated train crossing at s 320 with the station on the left
    c = F.point(RAIL_S)
    yaw = F.yaw_along(RAIL_S)
    L.add("C_RailSpan", c, yaw, band="landmark", overhead=True)
    for x in (-48.0, 48.0):
        L.add_local("C_RailPier", c, yaw, (x, 0, 0), band="landmark")
    for k in range(5):
        L.add_local("C_RailViaduct40", c, yaw, (50.0 + 40 * k, 0, 0), band="landmark")
        L.add_local("C_RailViaduct40", c, yaw, (-50.0 - 40 * k, 0, 0), extra_yaw=180, band="landmark")
        L.add_local("C_RailPier", c, yaw, (88.0 + 40 * k, 0, 0), band="landmark")
        L.add_local("C_RailPier", c, yaw, (-88.0 - 40 * k, 0, 0), band="landmark")
    L.add_local("C_Station", c, yaw, (0, 0, 0), band="landmark")
    L.add_local("C_SignStation", c, yaw, (-78.0, 47.0 + 12.6, -10.6), band="sign", sign_text="SKYLINE LOOP STATION")
    # the decorative train: on the span in the stills, sliding across every 12 s in the chase pass
    t_still = M.vadd(c, M.rot(yaw, (-8.0, 47.0, -1.6)))
    p0 = M.vadd(c, M.rot(yaw, (-260.0, 47.0, -1.6)))
    p1 = M.vadd(c, M.rot(yaw, (260.0, 47.0, -1.6)))
    L.add("C_Train", t_still, yaw, band="landmark", overhead=True, anim={"type": "slide", "from": p0, "to": p1, "period": 12.0, "pass_time": 5.0, "offset": 2.2})
    # the plaza under the crossing on the right: trees and benches
    for s, off in ((302, 46), (338, 46), (306, 62), (334, 64)):
        L.add("TreeRound", F.point(s, off), 0.0, band="park")
    for s in (312.0, 328.0):
        L.add("Bench", F.point(s, 42.0), F.yaw_facing_road(s, 1), band="park")
    L.landmark_target = M.vadd(c, [0, 50.0, 0])
    # signs: TURBO TOWERS banner, GEAR UP GYM vertical banner, PIT STOP NOODLES blade, one screen
    def pick(side, s_t, w=None, kind="mid"):
        cands = [p for p in placed if p[3] == side and p[0] == kind and (w is None or p[1] == w)]
        return min(cands, key=lambda p: abs(p[2] - s_t))

    p = pick(-1, 70.0, 24)
    L.add_local("C_SignTurbo", p[4], p[5], (0, 12.6, -0.36), band="sign", sign_text="TURBO TOWERS")
    p = pick(1, 40.0, 24)
    L.add_local("C_SignGym", p[4], p[5], (8.0, 17.0, -0.3), band="sign", sign_text="GEAR UP GYM")
    p = pick(1, 360.0)
    L.add_local("C_SignNoodle", p[4], p[5], (p[1] / 2 - 1.5, 17.0, 0.0), band="sign", sign_text="PIT STOP NOODLES")
    p = pick(-1, 185.0, 24)
    L.add_local("C_SignScreen", p[4], p[5], (0, p[6] + 3.5, 1.0), band="sign", sign_text="(screen loop)", anim={"type": "screen", "note": "one restrained ImageLabel loop; pause under reduced motion"})
    p = pick(-1, 360.0, 24)
    L.add_local("C_SignTurbo", p[4], p[5], (0, 12.6, -0.36), band="sign", sign_text="TURBO TOWERS")

    def extra(L2, rng2):
        d = F.point(1000.0, -120.0)
        L2.add("C_ArenaDome", d, F.yaw_along(1000.0), band="skyline", note="distant arena dome closing the vista")

    # close the vista with a cluster of towers beyond the run-out
    for off in (-110.0, -45.0, 25.0, 95.0):
        tower(L, M, rng, 600.0 + rng.uniform(-10, 25), off, -1, rng.choice([150, 200, 250]), slim=rng.random() < 0.5)
    M.skyline(L, rng, ["SkyTower_1", "SkyTower_2", "SkyTower_3", "SkySlab_1", "SkySlab_3"], (40, 80), (150, 330), (40, 70), extra=extra)
