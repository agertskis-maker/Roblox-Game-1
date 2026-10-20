"""Downtown Common starter (study B, recommended): three-door supermini hatch.

Provisional scale: 1 stud = 0.28 m. All values in studs. The car faces -Y.
Front bumper at y = -6.2, rear bumper at y = +6.2, ground at z = 0.
"""

L = 12.4
FRONT_AXLE = -3.70
REAR_AXLE = 4.24  # wheelbase 7.94 (64% of length)
TIRE_R = 1.115  # diameter 2.23 (18% of length)
TIRE_W = 0.69  # 31% of diameter

PALETTE = {
    # Provisional swatches from Adam's brief, chosen again under Studio lighting.
    "BodyPrimary": "#2878E8",
    "BodySecondary": "#F2F4F7",
    "Trim": "#242A32",
    "Glass": "#1B293E",
    "Headlamp": "#FFF0CD",
    "Taillamp": "#E83D45",
    "Plate": "#E9E4D6",
    "Tire": "#171B21",
    "WheelMetal": "#AAB4C0",
}

SPEC = {
    "name": "downtown-starter",
    "length": L,
    "width": 5.64,
    "axles": [FRONT_AXLE, REAR_AXLE],
    "tire_r": TIRE_R,
    "tire_w": TIRE_W,
    "track_x": 2.42,  # wheel centre; tyre face sits 0.06 inside the fender
    "arch_r": TIRE_R + 0.16,
    "arch_z": TIRE_R + 0.07,
    "spokes": 5,
    "tire_segments": 18,
    # Lower body: stations, top line, bottom line, plan half-width.
    "body_y": [-6.2, -6.12, -5.95, -5.6, -5.0, -3.7, -2.9, -1.0, 1.0, 3.0, 4.24, 5.2, 5.75, 6.02, 6.2],
    "body_step": 0.6,
    "body_top": [
        (-6.2, 1.86), (-6.12, 2.06), (-5.95, 2.30), (-5.6, 2.50), (-5.0, 2.64), (-3.7, 2.82),
        (-2.9, 2.93), (0.0, 3.00), (3.0, 3.08), (4.6, 3.14), (5.55, 3.16), (5.85, 3.02), (6.05, 2.78), (6.2, 2.45),
    ],
    "body_bottom": [(-6.2, 0.98), (-5.95, 0.80), (-5.4, 0.66), (5.2, 0.66), (5.9, 0.78), (6.2, 0.98)],
    "body_hw": [
        (-6.2, 2.05), (-6.12, 2.30), (-5.95, 2.48), (-5.6, 2.60), (-5.0, 2.66), (-3.7, 2.68),
        (0.0, 2.68), (4.24, 2.69), (5.2, 2.67), (5.75, 2.60), (6.02, 2.48), (6.2, 2.24),
    ],
    "fender_bumps": [(FRONT_AXLE, 0.10, 1.9), (REAR_AXLE, 0.13, 2.05)],
    "hood_crown": 0.10,
    "top_edge": 0.20,
    "sill_tuck": 0.17,
    "shoulder_in": 0.07,
    "belly_frac": 0.40,
    "bevel_width": 0.045,
    "bevel_angle": 55.0,
    # Cabin (greenhouse).
    "cabin_y": [-2.9, -2.55, -1.05, -0.4, 1.75, 2.1, 3.05, 3.45, 4.6, 5.5, 5.62],
    "cabin_step": 0.42,
    "cabin_inset": 0.08,
    "roof_z": [
        (-2.9, 3.00), (-2.55, 3.30), (-1.05, 4.56), (-0.4, 4.61), (1.5, 4.62), (3.0, 4.57),
        (3.45, 4.50), (4.6, 3.86), (5.5, 3.24), (5.62, 3.18),
    ],
    "roof_hw": [(-2.9, 2.30), (-1.05, 2.06), (0.5, 2.08), (3.0, 2.06), (3.45, 2.02), (5.5, 2.20), (5.62, 2.26)],
    "roof_crown": 0.09,
    "roof_edge_out": 0.07,
    "side_glass": [(-2.5, 1.75), (2.1, 3.05)],
    "top_glass": [(-2.85, -1.10), (3.50, 5.48)],
    "glass_frame": 0.065,
    "glass_recess": 0.04,
    "decals": [
        # Headlamps: swept housing, lens, one dark divider bar (two-segment
        # lamp, no round "pupils").
        {"side": "front", "at": (1.58, 2.18), "size": (0.60, 0.21), "n": 3.4, "skew": 0.12, "taper": 0.16, "role": "Trim", "offset": 0.015, "mirror": True, "rings": 2},
        {"side": "front", "at": (1.58, 2.18), "size": (0.55, 0.165), "n": 3.4, "skew": 0.11, "taper": 0.16, "role": "Headlamp", "offset": 0.03, "mirror": True, "rings": 2},
        {"side": "front", "at": (1.52, 2.15), "size": (0.34, 0.022), "n": 8.0, "role": "Trim", "offset": 0.045, "mirror": True, "segs": 12, "rings": 1},
        # Slim upper grille between the lamps and a wide lower intake.
        {"side": "front", "at": (0.0, 2.05), "size": (0.86, 0.075), "n": 5.0, "role": "Trim", "offset": 0.02},
        {"side": "front", "at": (0.0, 1.30), "size": (1.30, 0.21), "n": 4.0, "taper": -0.08, "role": "Trim", "offset": 0.02, "rings": 2},
        # Tail lamps: wide housing reaching the corner, red lens, slim clear
        # reverse bar on the inner end.
        {"side": "rear", "at": (1.66, 2.60), "size": (0.58, 0.25), "n": 4.0, "skew": -0.05, "taper": 0.10, "role": "Trim", "offset": 0.015, "mirror": True, "rings": 2},
        {"side": "rear", "at": (1.68, 2.61), "size": (0.53, 0.195), "n": 4.0, "skew": -0.04, "taper": 0.10, "role": "Taillamp", "offset": 0.03, "mirror": True, "rings": 2},
        {"side": "rear", "at": (1.30, 2.57), "size": (0.16, 0.045), "n": 6.0, "role": "Headlamp", "offset": 0.045, "mirror": True, "segs": 12},
        # Rear signature: a dark bar joining the two lamps into one wide line.
        {"side": "rear", "at": (0.0, 2.63), "size": (1.12, 0.055), "n": 8.0, "role": "Trim", "offset": 0.02, "segs": 16},
        # Rear: plate recess and blank plate, bumper line, lower diffuser band.
        {"side": "rear", "at": (0.0, 1.62), "size": (0.70, 0.23), "n": 5.0, "role": "Trim", "offset": 0.015},
        {"side": "rear", "at": (0.0, 1.62), "size": (0.62, 0.17), "n": 5.0, "role": "Plate", "offset": 0.03},
        {"side": "rear", "at": (0.0, 2.02), "size": (1.75, 0.022), "n": 8.0, "role": "Trim", "offset": 0.02, "rings": 1, "segs": 16},
        {"side": "rear", "at": (0.0, 1.10), "size": (1.70, 0.13), "n": 5.0, "role": "Trim", "offset": 0.02},
        # Side: door shut lines and a small handle.
        {"side": "sides", "at": (1.92, 2.02), "size": (0.022, 0.92), "n": 8.0, "role": "Trim", "offset": 0.02, "rings": 1, "segs": 16},
        {"side": "sides", "at": (-2.52, 2.18), "size": (0.022, 0.76), "n": 8.0, "role": "Trim", "offset": 0.02, "rings": 1, "segs": 16},
        {"side": "sides", "at": (1.42, 2.68), "size": (0.18, 0.045), "n": 4.0, "role": "Trim", "offset": 0.025, "rings": 1, "segs": 12},
    ],
    "boxes": [
        # Mirrors: (centre, size, role, bevel, mirror_x)
        ((2.63, -2.42, 3.12), (0.40, 0.24, 0.26), "BodyPrimary", 0.06, True),
    ],
    "smooth_angle": 36.0,
}
