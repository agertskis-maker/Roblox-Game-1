# Downtown look development, direction B "Bright Real City": frontage, landmark, signs,
# midground and skyline. The road, hazards and furniture come from layout.py (identical in A, B
# and C). Called by layout.py --dir B.

import fixture as F


def compose(L, M, rng, kind, w, s_c, side, setback, quiet):
    pos, yaw = M.facade_pose(s_c, side, setback)
    if kind == "corner":
        cw = rng.choice(["1", "2"])
        n = rng.choice([2, 3, 3])
        L.add(f"B_CornerBase_{cw}", pos, yaw, band="frontage")
        for k in range(n):
            L.add(f"B_CornerMid_{cw}", M.vadd(pos, [0, 16 + 12 * k, 0]), yaw, band="frontage")
        L.add(f"B_CornerTop_{cw}", M.vadd(pos, [0, 16 + 12 * n, 0]), yaw, band="frontage")
        return pos, yaw, 16 + 12 * n, n
    cw = "q" if quiet else rng.choice(["1", "1", "2", "3", "4", "5"])
    n = rng.choice([2, 2, 3, 3, 4])
    W = int(w)
    L.add(f"B_Base{W}_{cw}", pos, yaw, band="frontage")
    for k in range(n):
        L.add(f"B_Mid{W}_{cw}", M.vadd(pos, [0, 16 + 12 * k, 0]), yaw, band="frontage")
    top_y = 16 + 12 * n
    L.add(f"B_Top{W}_{cw}", M.vadd(pos, [0, top_y, 0]), yaw, band="frontage")
    if W == 24 and n >= 3 and rng.random() < 0.3:
        L.add("B_FireEscape3", M.vadd(pos, [0, 16, 0]), yaw, band="frontage")
    elif W == 24 and n == 2 and rng.random() < 0.2:
        L.add("B_FireEscape2", M.vadd(pos, [0, 16, 0]), yaw, band="frontage")
    return pos, yaw, top_y, n


def build(L, rng, M):
    M.common_road(L)
    M.common_hazards(L)
    M.common_furniture(L, "TreeRound")
    placed = []
    blocks = {1: [(-62, 90), (130, 197)], -1: [(-62, 236.0), (295.0, 482)]}
    blocks[1].append((295.0, 482))
    tanks = 0
    for side, segs in blocks.items():
        for s0, s1 in segs:
            for kind, w, s_c, sb in M.fill_block(s0, s1, side, rng, [24, 24, 12], alley_every=(3, 5), setback_p=0.12):
                q = M.near_hazard(s_c, side) and kind != "corner"
                pos, yaw, top_y, n = compose(L, M, rng, kind, w, s_c, side, sb, q)
                placed.append((kind, w, s_c, side, pos, yaw, top_y))
                # roof props: a water tank on no more than one roof in three, AC units
                if kind == "mid" and w == 24:
                    if rng.random() < 0.33 and tanks % 1 == 0:
                        L.add_local("B_WaterTank", pos, yaw, (rng.choice([-6, 6]), top_y + 0.3, 12.0), band="frontage")
                        tanks += 1
                    elif rng.random() < 0.6:
                        L.add_local("RoofAC", pos, yaw, (rng.uniform(-6, 6), top_y + 0.3, 13.0), band="frontage")
                elif kind == "mid" and rng.random() < 0.4:
                    L.add_local("RoofAC", pos, yaw, (0, top_y + 0.3, 12.0), band="frontage")
    # landmark: the corner theater on the intersection's near-right corner
    s_c = 215.5
    pos = F.point(s_c, F.FRONTAGE)
    yaw = F.yaw_facing_road(239.9, 1)
    L.add("B_Theater", pos, yaw, band="landmark", sign_text={"marquee": "NOW SHOWING"})
    L.add_local("B_TheaterBlade", pos, yaw, (11.0, 17.0, 0.0), band="sign", sign_text="REEL WHEELS")
    L.add_local("RoofAC", pos, yaw, (-8.0, 33.6, 18.0), band="landmark")
    L.add_local("B_WaterTank", pos, yaw, (-6.0, 33.6, 22.0), band="landmark")
    L.landmark_target = M.vadd(pos, M.rot(yaw, (6.0, 17.0, -3.0)))
    # signs on chosen frontage buildings
    want = [("B_SignHardware", "LUG NUTS HARDWARE", -1, 70.0), ("B_SignPizza", "WHEEL GOOD PIZZA", 1, 330.0), ("B_SignPizza", "WHEEL GOOD PIZZA", -1, 185.0)]
    used = set()
    for mesh, text, side, s_t in want:
        cands = [p for p in placed if p[3] == side and p[0] == "mid" and p[1] == 24 and id(p) not in used]
        best = min(cands, key=lambda p: abs(p[2] - s_t))
        used.add(id(best))
        L.add_local(mesh, best[4], best[5], (0, 11.8, -0.3), band="sign", sign_text=text)
    cands = [p for p in placed if p[3] == 1 and p[0] == "mid" and p[2] < 90]
    best = min(cands, key=lambda p: abs(p[2] - 40))
    L.add_local("B_SignDiner", best[4], best[5], (best[1] / 2 - 1.5, 16.5, 0.0), band="sign", sign_text="BRAKE-FAST DINER")
    cands = [p for p in placed if p[3] == -1 and p[0] == "mid" and 290 < p[2] < 400]
    best = max(cands, key=lambda p: (p[6], -abs(p[2] - 330)))
    L.add_local("B_SignHotel", best[4], best[5], (-best[1] / 2 + 2.0, 18.0, 0.0), band="sign", sign_text="TIRED? NAP HOTEL")
    tall = [f"B_MidTall_{i}" for i in range(1, 5)] + ["B_GlassTower_1", "B_GlassTower_2"]
    M.midground(L, rng, {"low": [f"B_MidLow_{i}" for i in range(1, 5)], "tall": tall}, rows=((65.0, 0.45), (120.0, 0.85)))
    M.vista(L, rng, [f"B_MidTall_{i}" for i in range(1, 5)] + ["B_GlassTower_2"])
    M.skyline(L, rng, ["SkyStepped_1", "SkyStepped_2", "SkyStepped_3", "SkySlab_2", "SkySlab_1", "SkyTower_2"], (40, 90), (70, 170), (40, 80))
