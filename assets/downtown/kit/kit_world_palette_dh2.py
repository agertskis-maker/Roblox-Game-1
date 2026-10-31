# Dusty Highway palette extension (Lane 3, Kit V2, 2026-10-28, worker D). Read by kit_world_palette.py only in a V2 build.
#   NEW_SWATCHES  appended after the Round 2 swatches (DH colour, SU colour; the SU column is unused, copied from DH)
#   OVERRIDES     recolour an existing swatch in the DH column only
# Colours are written as HSV (hue degrees, saturation, value) and converted here, so the plan's rules can be checked by
# running this file: `python kit_world_palette_dh2.py` prints the saturation of every DH swatch it touches.
#   G1  verge: packed clay (road meshes unchanged), the cream kerb top stays bright
#   G2  scenery terracotta never above saturation 0.60 (hazard orange 240,120,30 is 0.88, hue 26); aerial ramp sk_*
#   G4  plants toward sage and olive (saturation <= 0.45)
# New names start with d_, gp_, sage_, olive, bloom, sk_ or sign_ (the Summit kit uses other prefixes).

import colorsys


def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb((h % 360) / 360.0, s, v)
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))


def _both(name, rgb):
    return (name, rgb, rgb)


NEW_SWATCHES = [
    # deep-shade ladder for rock (the shaded twin of r_1..r_4): r_1 -> r_shadow, r_2 -> d_sh_1, r_3 -> d_sh_2, r_4 -> d_sh_3
    _both("d_sh_1", hsv(12, 0.50, 0.50)),
    _both("d_sh_2", hsv(14, 0.49, 0.58)),
    _both("d_sh_3", hsv(16, 0.48, 0.66)),
    # scree and talus at the foot of rock (lit, shaded)
    _both("d_talus", hsv(26, 0.40, 0.82)),
    _both("d_talus_sh", hsv(20, 0.44, 0.60)),
    # dunes: gold body, rose accent, lee shade, crest highlight
    _both("d_gold", hsv(38, 0.42, 0.92)),
    _both("d_rose", hsv(15, 0.34, 0.88)),
    _both("d_shade", hsv(20, 0.42, 0.66)),
    _both("d_crest", hsv(42, 0.26, 0.97)),
    # weathered wood (ghost remnants)
    _both("d_weather_1", hsv(28, 0.33, 0.54)),
    _both("d_weather_2", hsv(24, 0.38, 0.38)),
    _both("d_weather_3", hsv(32, 0.24, 0.66)),
    # aerial ramp, near to far: dusty mauve toward a pale blue (saturation <= 0.25, lighter and bluer with distance)
    _both("sk_5", hsv(4, 0.20, 0.77)),
    _both("sk_6", hsv(330, 0.14, 0.80)),
    _both("sk_7", hsv(285, 0.10, 0.83)),
    _both("sk_8", hsv(235, 0.10, 0.87)),
    # ground patches (tonal washes on the 226,188,138 ground)
    _both("gp_wash", hsv(33, 0.30, 0.86)),
    _both("gp_dark", hsv(27, 0.44, 0.78)),
    _both("gp_pale", hsv(36, 0.28, 0.94)),
    _both("gp_clay", hsv(24, 0.48, 0.75)),
    _both("gp_scrub", hsv(42, 0.38, 0.70)),
    _both("gp_pave", hsv(30, 0.22, 0.76)),
    # the far shimmer strip: a pale blue-sand gradient (sand to blue)
    _both("gp_haze_1", hsv(34, 0.12, 0.92)),
    _both("gp_haze_2", hsv(28, 0.05, 0.90)),
    _both("gp_haze_3", hsv(220, 0.07, 0.89)),
    _both("gp_haze_4", hsv(214, 0.12, 0.88)),
    # plants: sage and olive, saturation <= 0.45
    _both("sage_dark", hsv(135, 0.30, 0.38)),
    _both("sage_mid", hsv(115, 0.26, 0.54)),
    _both("sage_light", hsv(95, 0.27, 0.68)),
    _both("olive", hsv(62, 0.43, 0.50)),
    _both("bloom", hsv(348, 0.45, 0.88)),
    # signs: blank cream face, rust lettering area, gold sun, sandstone plaque
    _both("sign_face", hsv(42, 0.14, 0.99)),
    _both("sign_rust", hsv(18, 0.57, 0.58)),
    _both("sign_gold", hsv(40, 0.56, 0.93)),
    _both("sign_stone", hsv(28, 0.38, 0.84)),
]

OVERRIDES = {
    # G1 packed-clay verge (the cream kerb top curb_top and curb stay bright)
    "sidewalk_a": {"DH": (168, 120, 86)},
    "sidewalk_b": {"DH": (158, 112, 80)},
    "sidewalk_edge": {"DH": (142, 98, 70)},
    "grass": {"DH": (176, 128, 92)},
    "grass_dark": {"DH": (150, 108, 78)},
    # G2 terracotta, hue 19 to 25, saturation <= 0.58, dark to light order kept (hazard orange stays the only vivid one)
    "r_1": {"DH": hsv(19, 0.55, 0.55)},
    "r_2": {"DH": hsv(21, 0.56, 0.67)},
    "r_3": {"DH": hsv(23, 0.57, 0.78)},
    "r_4": {"DH": hsv(25, 0.55, 0.86)},
    "r_shadow": {"DH": hsv(10, 0.50, 0.43)},
    "w_roof_1": {"DH": hsv(18, 0.55, 0.66)},
    "m_rust": {"DH": hsv(20, 0.56, 0.60)},
    # G4 plants toward sage and olive, relative lightness order kept
    "p_dark": {"DH": hsv(135, 0.30, 0.38)},
    "p_mid": {"DH": hsv(115, 0.26, 0.54)},
    "p_light": {"DH": hsv(95, 0.27, 0.68)},
    # aerial ramp (sk_5..sk_8 are new): the Round 2 pinkish tones move toward mauve and lose saturation
    "sk_3": {"DH": hsv(8, 0.23, 0.68)},
    "sk_1": {"DH": hsv(8, 0.21, 0.72)},
    "sk_2": {"DH": hsv(10, 0.18, 0.84)},
    "sk_4": {"DH": hsv(12, 0.13, 0.91)},
    "sk_trim": {"DH": hsv(20, 0.10, 0.95)},
}

if __name__ == "__main__":
    def sat(c):
        mx, mn = max(c), min(c)
        return 0.0 if mx == 0 else (mx - mn) / mx

    def hue(c):
        return colorsys.rgb_to_hsv(*(x / 255.0 for x in c))[0] * 360

    rows = [(n, c["DH"]) for n, c in OVERRIDES.items()] + [(n, a) for n, a, _ in NEW_SWATCHES]
    for n, c in rows:
        print(f"{n:14s} {str(c):18s} sat {sat(c):.2f} hue {hue(c):5.1f} v {max(c) / 255:.2f}")
