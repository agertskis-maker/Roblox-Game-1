# Summit Pass palette extension (Lane 3, Kit V2, 2026-10-28, worker S). Read by kit_world_palette.py only in a V2 build.
#   NEW_SWATCHES  appended after the Round 2 swatches (DH colour, SU colour; the DH column is unused, copied from SU)
#   OVERRIDES     recolour an existing swatch in the SU column only
# Plan 5.1 ladders: snow s_*, rock rk_* (near, mid, far, farthest), pine pn_*, roofs rf_*, honey, ice ice_*/rim_*/moraine*,
# bunting bunt_*. New names start with s_, rk_, pn_, rf_, ice_, rim_, moraine, bunt_ or honey_ (the Dusty kit uses others).
#
# The report (printed by kit_summit2.build_all at the start of a build) lists HSV and luminance for every swatch this file adds or
# overrides, and the value gaps the plan names: far rock against the horizon haze (206,222,244), the ice-patch hazard against asphalt.

import colorsys


def _both(name, rgb):
    return (name, rgb, rgb)


NEW_SWATCHES = [
    # snow ladder (plan 5.1): lit, half-lit, shade, gully. No large area reaches 245.
    _both("s_lit", (240, 246, 252)),
    _both("s_half", (222, 232, 244)),
    _both("s_shade", (176, 194, 220)),
    _both("s_gully", (150, 172, 204)),
    # rock, far ladder (always >= 10 value points darker than the haze): farthest, lit, body, shade, deep
    _both("rk_farthest", (192, 208, 228)),
    _both("rk_far_lit", (182, 198, 220)),
    _both("rk_far", (168, 186, 210)),
    _both("rk_far_shade", (150, 168, 194)),
    _both("rk_far_deep", (134, 152, 180)),
    # rock, mid ladder (the rest of the mid ladder is the existing r_2 and r_1)
    _both("rk_mid", (134, 148, 170)),
    _both("rk_mid_lit", (156, 170, 192)),
    # rock, near ladder
    _both("rk_near", (112, 118, 130)),
    _both("rk_near_lit", (146, 154, 168)),
    _both("rk_near_shade", (90, 96, 110)),
    _both("rk_warm", (126, 120, 122)),
    _both("rk_dark", (74, 82, 98)),
    # pine: mid, far, young, wind-bent, and the deep underside of near boughs
    _both("pn_mid", (58, 104, 98)),
    _both("pn_far", (96, 132, 140)),
    _both("pn_young", (70, 128, 92)),
    _both("pn_bent", (60, 96, 76)),
    _both("pn_deep", (26, 62, 52)),
    # roofs (berry stays w_roof_1)
    _both("rf_forest", (46, 92, 76)),
    _both("rf_slate", (63, 91, 115)),
    _both("rf_shingle", (118, 86, 66)),
    _both("rf_cream", (234, 226, 206)),
    # honey: static window glow and lantern glass, never emissive
    _both("honey_glow", (255, 214, 120)),
    # ice (glacier and lake, matte) and the dark shore rim
    _both("ice_pale", (176, 214, 238)),
    _both("ice_deep", (118, 168, 208)),
    _both("ice_heart", (86, 142, 196)),
    _both("ice_crack", (214, 236, 250)),
    _both("ice_lit", (206, 230, 246)),
    _both("ice_shade", (96, 146, 190)),
    _both("ice_void", (38, 62, 104)),
    _both("rim_dark", (62, 70, 86)),
    _both("rim_haz", (36, 44, 62)),
    _both("moraine", (128, 124, 126)),
    _both("moraine_dirty", (170, 168, 172)),
    # bunting (no orange)
    _both("bunt_teal", (70, 170, 170)),
    _both("bunt_green", (52, 112, 84)),
    _both("bunt_cream", (250, 242, 226)),
    _both("bunt_honey", (242, 190, 78)),
    _both("bunt_berry", (204, 72, 66)),
    # walls and stone for the chalet forms
    _both("s_board", (186, 150, 112)),
    _both("s_weather", (132, 112, 100)),
    _both("s_ochre", (224, 192, 130)),
    _both("s_stone_lt", (176, 182, 194)),
    _both("s_stone", (146, 152, 164)),
    _both("s_stone_dk", (104, 110, 124)),
    _both("s_sage", (150, 178, 150)),
    _both("s_paleblue", (132, 160, 190)),
    _both("s_reed", (200, 184, 140)),
]

OVERRIDES = {
    # plan 5.1: no large area reaches 245
    "g_hi": {"SU": (240, 246, 252)},
    "m_white": {"SU": (243, 247, 252)},
    # plan 5.3 / S12 road-contrast retune: the Round 2 slate (90,98,114) measured 2.67 to 2.95 to 1 against the snow verge in
    # Studio stills (plan asks 3 to 1); each road swatch is about 20 percent darker, the same blue-grey hue
    "asphalt": {"SU": (72, 80, 98)},
    "asphalt_gutter": {"SU": (60, 68, 84)},
    "asphalt_patch": {"SU": (68, 76, 92)},
    "asphalt_side": {"SU": (66, 74, 90)},
}

HAZE = (206, 222, 244)
ASPHALT = (72, 80, 98)  # the Summit road swatch after the retune (OVERRIDES above; kit_world_palette.ROAD["asphalt"] SU column was (90, 98, 114))


def _hsv(c):
    h, s, v = colorsys.rgb_to_hsv(*(x / 255.0 for x in c))
    return h * 360.0, s, v


def _lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def report():
    """Print the HSV and luminance of every swatch this file adds or overrides, and the checked value gaps."""
    rows = [(n, c["SU"]) for n, c in OVERRIDES.items()] + [(n, a) for n, a, _ in NEW_SWATCHES]
    print("Summit palette extension (SU column): swatch, rgb, hue deg, sat, value (HSV V x 255), luminance")
    for n, c in rows:
        h, s, v = _hsv(c)
        tag = " (override)" if n in OVERRIDES else ""
        print(f"  {n:15s} {str(tuple(c)):16s} h {h:5.1f}  s {s:4.2f}  v {v * 255:5.1f}  lum {_lum(c):5.1f}{tag}")
    print(f"value gaps (haze {HAZE}, V {max(HAZE)}, lum {_lum(HAZE):.1f}; asphalt {ASPHALT}, V {max(ASPHALT)}, lum {_lum(ASPHALT):.1f}):")
    for n in ("rk_farthest", "rk_far_lit", "rk_far", "rk_far_shade", "rk_far_deep"):
        c = next(a for m, a, _ in NEW_SWATCHES if m == n)
        print(f"  far rock {n:13s} V gap to haze {max(HAZE) - max(c):3d}, luminance gap {_lum(HAZE) - _lum(c):5.1f}")
    patch = (232, 244, 252)  # hz_light, the ice-patch hazard body
    print(f"  ice patch hz_light vs asphalt: V gap {max(patch) - max(ASPHALT)}, luminance gap {_lum(patch) - _lum(ASPHALT):.1f}; patch rim rim_haz lum {_lum((36, 44, 62)):.1f} (darker than asphalt by {_lum(ASPHALT) - _lum((36, 44, 62)):.1f})")
    # plan 5.1: "no large area at 245 or above". The brief fixed g_hi / m_white / s_lit at (240,246,252) / (243,247,252): their luminance is
    # 245 to 246, so the brightest snow sits AT the limit (the lead's values, kept). The large snow areas this kit paints use s_half
    # (luminance 230.7) and the shared ground (ground_lot, luminance 242.1); s_lit is the sunlit accent step.
    for n in ("s_lit", "g_hi", "m_white", "s_half"):
        c = OVERRIDES[n]["SU"] if n in OVERRIDES else next(a for m, a, _ in NEW_SWATCHES if m == n)
        print(f"  {n}: rgb {tuple(c)}, luminance {_lum(c):.1f}, mean {sum(c) / 3:.1f}, max channel {max(c)}")
    print(f"  swatches added: {len(NEW_SWATCHES)}, overridden: {len(OVERRIDES)}")
