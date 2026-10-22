# The Downtown look-development comparison fixture as code (pure Python, no bpy). Values follow
# vault/design/specs/downtown-lookdev-fixture.md exactly; all are PREVIEW values for Brian R to
# confirm. Lane 1 owns real roads, segments, lane geometry and the run camera: this is one
# fixed test road used identically for directions A, B and C, not segment generation.
#
# Frame (Roblox studs): +X right, the car drives toward -Z, ground (asphalt top) y = 0.
# The road is parameterised by s, the distance along the carriageway centreline:
#   straight A s 0-140, curve s 140-240 (radius 300, bending right, about 19.1 degrees),
#   straight on the new heading s 240-360 with the intersection centred at s 265.
# Yaw convention for every placed instance: rotation about +Y by `yaw` degrees, Roblox
# CFrame.Angles(0, math.rad(yaw), 0); a piece's LookVector (local -Z) then points along
# (-sin yaw, 0, -cos yaw).

import math

# ---------------------------------------------------------------- road
LENGTH = 360.0
STRAIGHT_A_END = 140.0
CURVE_END = 240.0
RADIUS = 300.0
THETA_END = (CURVE_END - STRAIGHT_A_END) / RADIUS  # radians, about 19.1 degrees
INTERSECTION_S = 265.0
CROSS_WIDTH = 30.0  # the two-lane cross street
CROSSING_S = 245.0  # zebra centre
LANES = 4
LANE_W = 12.5
HALF = LANES * LANE_W / 2  # 25: carriageway half width
CURB_W = 0.8
CURB_H = 0.6
SIDEWALK_W = 12.0
FRONTAGE = HALF + CURB_W + SIDEWALK_W  # 37.8 from the centreline: the frontage line
PIECE = 20.0  # road piece length (one dash period: 10 on, 10 off)
RUN_IN = -60.0  # scenery-only extension before s 0 and after s 360 (not part of the fixture)
RUN_OUT = 480.0


def lane_offset(lane):
    """Lane 1 is the far left; lane 2 (the car's) is x = -6.25 on the straight."""
    return -HALF + LANE_W * (lane - 0.5)


def heading(s):
    if s <= STRAIGHT_A_END:
        return 0.0
    if s <= CURVE_END:
        return (s - STRAIGHT_A_END) / RADIUS
    return THETA_END


def centre(s):
    """(x, z) of the centreline at s; extends straight before 0 and after the curve."""
    if s <= STRAIGHT_A_END:
        return (0.0, -s)
    if s <= CURVE_END:
        t = (s - STRAIGHT_A_END) / RADIUS
        cx, cz = RADIUS, -STRAIGHT_A_END
        return (cx - RADIUS * math.cos(t), cz - RADIUS * math.sin(t))
    x0, z0 = centre(CURVE_END)
    d = s - CURVE_END
    return (x0 + math.sin(THETA_END) * d, z0 - math.cos(THETA_END) * d)


def forward(s):
    t = heading(s)
    return (math.sin(t), -math.cos(t))


def right(s):
    t = heading(s)
    return (math.cos(t), math.sin(t))


def point(s, off=0.0, y=0.0):
    """World point at road distance s, lateral offset `off` (+ right), height y."""
    cx, cz = centre(s)
    rx, rz = right(s)
    return [cx + rx * off, y, cz + rz * off]


def yaw_along(s):
    """Yaw (degrees) whose LookVector is the driving direction at s."""
    return -math.degrees(heading(s))


def yaw_facing_road(s, side):
    """Yaw for a facade (front = LookVector) on `side` (+1 right, -1 left) facing the road."""
    t = math.degrees(heading(s))
    return 90.0 - t if side > 0 else -90.0 - t


def nearest(x, z, step=2.0):
    """Approximate (s, lateral offset) of a world point, sampling the extended centreline."""
    best = None
    s = RUN_IN - 200
    while s <= RUN_OUT + 200:
        cx, cz = centre(s)
        d = (x - cx) ** 2 + (z - cz) ** 2
        if best is None or d < best[0]:
            best = (d, s)
        s += step
    s0 = best[1]
    # refine
    lo, hi = s0 - step, s0 + step
    for _ in range(30):
        m1, m2 = lo + (hi - lo) / 3, hi - (hi - lo) / 3
        c1, c2 = centre(m1), centre(m2)
        if (x - c1[0]) ** 2 + (z - c1[1]) ** 2 < (x - c2[0]) ** 2 + (z - c2[1]) ** 2:
            hi = m2
        else:
            lo = m1
    s = (lo + hi) / 2
    cx, cz = centre(s)
    rx, rz = right(s)
    return s, (x - cx) * rx + (z - cz) * rz


# ---------------------------------------------------------------- car and camera
CAR_SIZE = (5.66, 4.71, 12.47)  # Puglet: width, height, length (studs)
CAR_LANE = 2
CAR_CENTRE_Y = CAR_SIZE[1] / 2
CAM_BEHIND = 12.0
CAM_ABOVE = 6.0  # above the car's centre
LOOK_AHEAD = 20.0
LOOK_Y = 1.5
FOV_V = 70.0
SPEED = 50.0  # studs per second along the lane centre (the fixture pass is 7.2 s)
CHASE_FRAMES = [30.0, 115.0, 200.0, 262.0]
CHASE_LABELS = {30.0: "start", 115.0: "construction", 200.0: "oil", 262.0: "intersection"}


def car_pose(s):
    off = lane_offset(CAR_LANE)
    p = point(s, off, CAR_CENTRE_Y)
    return p, yaw_along(s)


def chase_camera(s):
    off = lane_offset(CAR_LANE)
    eye = point(s - CAM_BEHIND, off, CAR_CENTRE_Y + CAM_ABOVE)
    target = point(s + LOOK_AHEAD, off, LOOK_Y)
    return eye, target


PED_EYE = 5.0
PED_X = HALF + CURB_W + 6.0  # middle of the right sidewalk


def pedestrian_cameras(landmark_target):
    """Two pedestrian frames: s 60 looking forward-left, s 250 looking at the landmark."""
    eye1 = point(60.0, PED_X, CURB_H + PED_EYE)
    # forward-left: 40 degrees left of the driving direction, slightly up
    fx, fz = forward(60.0)
    rx, rz = right(60.0)
    a = math.radians(40)
    dx = fx * math.cos(a) - rx * math.sin(a)
    dz = fz * math.cos(a) - rz * math.sin(a)
    t1 = [eye1[0] + dx * 60, eye1[1] + 6.0, eye1[2] + dz * 60]
    eye2 = point(250.0, PED_X, CURB_H + PED_EYE)
    return [("ped-s60", eye1, t1), ("ped-s250", eye2, landmark_target)]


# ---------------------------------------------------------------- hazards (identical in A, B, C)
CONSTRUCTION = {"lane": 4, "s0": 100.0, "s1": 125.0}
POTHOLE = {"lane": 2, "s": 172.0, "size": (2.5, 3.5)}
OIL = {"lane": 3, "s": 205.0, "size": (6.0, 4.0)}
CRANE_S = 112.0
CRANE_OFF = FRONTAGE + 22.0  # on a lot behind the right sidewalk

# ---------------------------------------------------------------- landmarks
LANDMARK = {
    "A": {"s": 150.0, "side": 1},
    "B": {"s": 228.0, "side": 1},  # the intersection's near-right corner (s 205 to 250)
    "C": {"s": 320.0, "side": -1},  # train crossing over the road; station on the left
}
TRAIN_CLEARANCE = 44.0  # underside of the crossing span (at least 40)

# ---------------------------------------------------------------- scenery bands (from the frontage line)
BAND_FRONTAGE = (0.0, 25.0)
BAND_MID = (60.0, 140.0)
BAND_SKY = (300.0, 900.0)
QUIET_RADIUS = 30.0  # facades this close to hazards are kept lower-contrast


def hazard_points():
    """World (x, z) centres of the gameplay-critical road items, for facade quieting."""
    pts = []
    c = CONSTRUCTION
    for s in (c["s0"], (c["s0"] + c["s1"]) / 2, c["s1"]):
        p = point(s, lane_offset(c["lane"]))
        pts.append((p[0], p[2]))
    for h in (POTHOLE, OIL):
        p = point(h["s"], lane_offset(h["lane"]))
        pts.append((p[0], p[2]))
    return pts
