# Downtown kit palette (Lane 3 look development). ONE shared swatch layout, three colour
# variants: A Sunny Toy City, B Bright Real City, C Big Bright Metropolis. Every mesh points each
# triangle at the centre of one swatch, so the same mesh recolours by swapping the palette image
# (MeshPart.TextureID = palette-A.png / palette-B.png / palette-C.png).
#
# 16 x 16 swatches of 16 px in a 256 x 256 image, read left to right, top to bottom.
# Groups (research O12): road and hazard swatches are FIXED across the three variants, so the
# comparison is fair; furniture is lightly tinted per direction; facade, accent, sign, display,
# skyline and landmark swatches change per direction. Pure Python (no bpy), so the layout and
# stats scripts can import it too.
#
# Entry: (name, colour) for a fixed swatch, or (name, colour_A, colour_B, colour_C).

import struct
import zlib

GRID = 16
CELL = 16
SIZE = GRID * CELL

ENTRIES = [
    # ---------------------------------------------------------- road (fixed)
    ("asphalt", (116, 114, 118)),
    ("asphalt_gutter", (102, 100, 106)),
    ("asphalt_patch", (128, 126, 128)),
    ("asphalt_side", (92, 90, 96)),
    ("line_white", (242, 242, 236)),
    ("line_yellow", (250, 206, 72)),
    ("curb", (198, 194, 188)),
    ("curb_top", (216, 212, 206)),
    ("sidewalk_a", (208, 202, 192)),
    ("sidewalk_b", (196, 190, 180)),
    ("sidewalk_edge", (182, 176, 168)),
    ("ground_lot", (188, 184, 174)),
    ("grass", (128, 188, 98)),
    ("grass_dark", (100, 160, 84)),
    ("soil", (110, 82, 60)),
    ("tree_grate", (78, 80, 86)),
    # ---------------------------------------------------------- hazards (fixed)
    ("haz_orange", (252, 118, 28)),
    ("haz_white", (248, 246, 242)),
    ("haz_black", (40, 40, 46)),
    ("haz_amber", (252, 176, 40)),
    ("cone_orange", (255, 108, 20)),
    ("oil_black", (14, 16, 26)),
    ("oil_teal", (44, 176, 172)),
    ("oil_violet", (150, 96, 210)),
    ("oil_gold", (226, 196, 84)),
    ("oil_gloss", (96, 108, 134)),
    ("pot_floor", (48, 46, 52)),
    ("pot_wall", (72, 70, 76)),
    ("pot_rim", (176, 172, 168)),
    ("pot_chunk", (146, 144, 142)),
    ("crane_yellow", (250, 194, 36)),
    ("crane_dark", (62, 66, 74)),
    ("crane_cab", (238, 238, 232)),
    ("crane_glass", (120, 172, 204)),
    ("concrete_block", (170, 170, 168)),
    ("fence_mesh", (150, 158, 164)),
    # ---------------------------------------------------------- street furniture
    ("furn_metal", (92, 172, 160), (52, 58, 64), (196, 204, 210)),
    ("furn_metal_dark", (66, 132, 124), (36, 40, 46), (146, 156, 166)),
    ("lamp_glass", (255, 242, 196)),
    ("wood", (180, 128, 80)),
    ("wood_dark", (136, 94, 60)),
    ("planter", (240, 156, 134), (172, 100, 74), (212, 216, 220)),
    ("planter_rim", (250, 236, 220), (196, 132, 100), (236, 240, 242)),
    ("leaf_dark", (56, 128, 70), (50, 112, 62), (52, 122, 72)),
    ("leaf_mid", (84, 164, 78), (76, 146, 70), (78, 156, 80)),
    ("leaf_light", (128, 194, 88), (114, 176, 82), (120, 188, 92)),
    ("leaf_sun", (170, 214, 98), (150, 196, 92), (160, 208, 104)),
    ("trunk", (126, 88, 60)),
    ("hydrant", (244, 196, 52)),
    ("hydrant_cap", (224, 226, 226)),
    ("bin", (126, 194, 224), (46, 98, 82), (72, 84, 96)),
    ("bin_lid", (246, 238, 220), (32, 70, 60), (190, 198, 206)),
    ("shelter_glass", (176, 214, 228)),
    ("shelter_roof", (246, 236, 214), (60, 66, 72), (234, 238, 240)),
    ("sign_green", (40, 132, 92)),
    ("sign_white", (246, 246, 242)),
    ("signal_housing", (44, 48, 54)),
    ("signal_red", (236, 64, 52)),
    ("signal_amber", (252, 182, 40)),
    ("signal_green", (64, 206, 116)),
    ("signal_off", (74, 78, 86)),
    ("flower_1", (240, 112, 146), (226, 92, 80), (250, 120, 150)),
    ("flower_2", (252, 214, 80), (250, 196, 70), (252, 220, 90)),
    # ---------------------------------------------------------- facade walls (per direction)
    #  A: coral, mint, butter, sky, lilac, cream (75-85% value, softer than any car paint)
    #  B: warm brick, ochre brick, brown brick, cream stone, painted teal, painted mustard
    #  C: pale frame, warm pale, concrete, teal glass, sky glass, deep glass
    ("wall_1", (234, 156, 138), (172, 92, 72), (232, 236, 238)),
    ("wall_2", (156, 210, 188), (186, 126, 86), (236, 230, 218)),
    ("wall_3", (240, 214, 140), (150, 90, 74), (200, 204, 206)),
    ("wall_4", (150, 194, 228), (232, 218, 190), (96, 176, 182)),
    ("wall_5", (194, 176, 222), (98, 166, 160), (132, 190, 222)),
    ("wall_6", (244, 234, 214), (222, 176, 88), (72, 132, 162)),
    ("wall_base", (226, 206, 196), (214, 200, 174), (178, 186, 190)),
    ("trim_1", (250, 244, 228), (236, 224, 198), (244, 246, 246)),
    ("trim_2", (255, 252, 246), (54, 58, 62), (212, 216, 218)),
    ("trim_3", (226, 132, 116), (198, 184, 156), (180, 190, 196)),
    ("reveal", (222, 202, 192), (146, 114, 98), (172, 182, 188)),
    ("glass", (104, 164, 196), (72, 102, 122), (84, 158, 176)),
    ("glass_light", (168, 212, 230), (122, 152, 168), (150, 206, 220)),
    ("glass_dark", (74, 120, 150), (52, 72, 88), (58, 116, 140)),
    ("frame", (255, 255, 250), (238, 230, 208), (238, 242, 244)),
    ("door", (128, 96, 176), (40, 98, 92), (62, 72, 82)),
    ("door_2", (238, 120, 104), (120, 54, 44), (230, 120, 60)),
    ("roof", (206, 196, 192), (124, 122, 120), (184, 192, 194)),
    ("roof_dark", (170, 160, 160), (96, 94, 94), (150, 160, 164)),
    ("aw1_a", (238, 112, 98), (40, 140, 140), (40, 180, 190)),
    ("aw1_b", (255, 250, 240), (236, 226, 200), (244, 246, 246)),
    ("aw2_a", (82, 190, 160), (232, 122, 52), (255, 186, 40)),
    ("aw2_b", (255, 250, 240), (250, 238, 212), (244, 246, 246)),
    ("aw3_a", (96, 160, 232), (34, 98, 70), (246, 96, 96)),
    ("aw3_b", (250, 220, 110), (236, 226, 200), (244, 246, 246)),
    ("awning_under", (230, 210, 200), (176, 166, 146), (206, 212, 216)),
    ("accent_1", (255, 124, 146), (30, 150, 150), (255, 96, 96)),
    ("accent_2", (255, 202, 64), (240, 130, 40), (255, 192, 40)),
    ("accent_3", (100, 190, 240), (222, 182, 92), (60, 200, 160)),
    ("accent_4", (172, 124, 232), (64, 132, 92), (92, 132, 255)),
    ("sign_face", (255, 250, 238), (250, 242, 220), (250, 252, 252)),
    ("sign_frame_1", (236, 98, 92), (30, 110, 112), (40, 170, 186)),
    ("sign_frame_2", (60, 170, 150), (210, 104, 40), (250, 170, 30)),
    ("sign_frame_3", (100, 150, 230), (120, 50, 46), (240, 86, 96)),
    ("sign_frame_4", (160, 110, 220), (52, 56, 62), (80, 110, 230)),
    ("display_1", (252, 182, 200), (226, 186, 120), (250, 200, 120)),
    ("display_2", (250, 230, 160), (180, 120, 70), (120, 220, 200)),
    ("display_3", (150, 220, 250), (130, 170, 120), (250, 150, 160)),
    ("display_4", (210, 160, 110), (220, 220, 210), (200, 210, 250)),
    ("shelf", (246, 236, 220), (150, 104, 70), (220, 226, 230)),
    ("bulb", (255, 238, 176)),
    ("poster_1", (250, 110, 90), (232, 92, 70), (250, 110, 90)),
    ("poster_2", (70, 160, 230), (50, 120, 200), (70, 160, 230)),
    ("poster_3", (250, 210, 70), (246, 200, 70), (250, 210, 70)),
    ("poster_4", (110, 200, 140), (90, 180, 120), (110, 200, 140)),
    ("poster_bg", (40, 56, 90), (36, 44, 70), (40, 56, 90)),
    ("brick_course", (234, 168, 150), (152, 78, 60), (214, 220, 222)),
    ("iron", (70, 76, 84), (44, 48, 54), (120, 130, 140)),
    ("iron_light", (110, 118, 126), (78, 84, 92), (170, 178, 186)),
    # ---------------------------------------------------------- roof props
    ("vent", (250, 244, 232), (176, 180, 182), (220, 224, 226)),
    ("vent_dark", (200, 188, 180), (120, 124, 128), (170, 176, 180)),
    ("ac_body", (232, 228, 222), (196, 200, 202), (214, 220, 224)),
    ("ac_fan", (120, 124, 130), (96, 100, 106), (120, 128, 136)),
    ("tank_wood", (196, 146, 104), (148, 104, 70), (190, 160, 120)),
    ("tank_band", (90, 94, 100), (56, 58, 62), (110, 116, 122)),
    ("roof_deck", (214, 194, 160), (150, 136, 120), (196, 178, 150)),
    # ---------------------------------------------------------- skyline (pre-hazed toward the sky)
    ("sky_1", (226, 212, 228), (206, 192, 186), (150, 200, 214)),
    ("sky_2", (208, 226, 232), (188, 194, 206), (178, 214, 226)),
    ("sky_3", (238, 222, 214), (216, 206, 190), (204, 226, 234)),
    ("sky_4", (214, 230, 220), (180, 186, 200), (128, 184, 204)),
    ("sky_trim", (246, 240, 236), (226, 220, 212), (226, 238, 242)),
    ("mid_1", (230, 176, 160), (178, 116, 96), (112, 182, 192)),
    ("mid_2", (176, 214, 200), (196, 150, 112), (146, 196, 222)),
    ("mid_3", (232, 214, 160), (200, 190, 172), (92, 150, 176)),
    ("mid_4", (186, 176, 220), (150, 176, 184), (220, 226, 228)),
    ("mid_window", (150, 186, 210), (120, 134, 150), (196, 226, 236)),
    # ---------------------------------------------------------- landmarks
    ("donut_dough", (224, 164, 98)),
    ("donut_icing", (248, 140, 182)),
    ("donut_icing_hi", (252, 182, 210)),
    ("sprinkle_1", (255, 240, 120)),
    ("sprinkle_2", (110, 200, 250)),
    ("sprinkle_3", (255, 255, 255)),
    ("sprinkle_4", (120, 220, 150)),
    ("marquee", (238, 92, 80), (196, 56, 50), (238, 92, 80)),
    ("marquee_trim", (255, 214, 110), (240, 196, 96), (255, 214, 110)),
    ("train_body", (242, 246, 248)),
    ("train_stripe", (38, 172, 194)),
    ("train_accent", (255, 190, 40)),
    ("train_window", (58, 92, 114)),
    ("train_dark", (52, 56, 64)),
    ("rail_concrete", (216, 218, 216)),
    ("rail_side", (190, 194, 196)),
    ("rail_track", (118, 122, 130)),
    ("dome", (234, 238, 242)),
    ("dome_rib", (196, 206, 216)),
    ("dome_band", (110, 170, 200)),
    ("screen_frame", (60, 66, 76)),
    ("screen_face", (90, 170, 220)),
    ("garden_deck", (196, 166, 120)),
]

NAMES = [e[0] for e in ENTRIES]
SW = {name: i for i, name in enumerate(NAMES)}
assert len(NAMES) == len(set(NAMES)), "duplicate swatch name"
assert len(NAMES) <= GRID * GRID, "palette is full"

VARIANTS = ("A", "B", "C")
FIXED = {e[0] for e in ENTRIES if len(e) == 2}


def colour(name, variant):
    e = ENTRIES[SW[name]]
    if len(e) == 2:
        return e[1]
    return e[1 + VARIANTS.index(variant)]


def swatch_uv(name):
    i = SW[name]
    gx, gy = i % GRID, i // GRID
    # image rows run top to bottom; Roblox and Blender UV v runs bottom to top
    return ((gx + 0.5) / GRID, 1 - (gy + 0.5) / GRID)


def _png(path, width, height, rows):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        fh.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        fh.write(chunk(b"IEND", b""))


def write_palette_png(path, variant):
    """The variant's 256 x 256 swatch image; unused cells are a neutral mid grey."""
    rows = []
    for py in range(SIZE):
        gy = py // CELL
        row = bytearray()
        for gx in range(GRID):
            i = gy * GRID + gx
            r, g, b = colour(NAMES[i], variant) if i < len(NAMES) else (128, 128, 128)
            row += bytes((r, g, b, 255)) * CELL
        rows.append(bytes(row))
    _png(path, SIZE, SIZE, rows)


def swatch_table():
    """For the manifest: index, name, fixed flag and the three colours."""
    return [
        {"index": i, "name": n, "fixed": n in FIXED, "A": colour(n, "A"), "B": colour(n, "B"), "C": colour(n, "C")}
        for i, n in enumerate(NAMES)
    ]
