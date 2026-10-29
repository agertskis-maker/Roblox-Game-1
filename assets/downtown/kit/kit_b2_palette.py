# Downtown kit B2 palette (Lane 3, direction B "Bright Real City", production start). ONE swatch
# layout shared by five district palettes: MS Main Street, CH City Hall, HB Harbor Bridge,
# MT Midtown, SP Skyline Park. A mesh points each triangle at the centre of one swatch, so a lot
# module recolours per district by swapping the palette image (MeshPart.TextureID =
# palette-B2-<district>.png); landmarks, road, hazards, furniture, signs and skyline use FIXED
# swatches and look identical in every district.
#
# Fixed swatches are copied from palette.py's B column, so the B2 kit keeps the selected B look
# (warm brick, cream stone, restrained teal/navy accents). District swatches are a small,
# coherent set: four walls, two stones, trims, three awnings (never orange: orange/white is
# reserved for construction hazards), doors, accents, roof and paving.
#
# 16 x 16 swatches of 16 px in a 256 x 256 image, read left to right, top to bottom. Pure Python
# (no bpy), so the build, the render and plain-Python checks can all import it.
#
# Entry: (name, (r, g, b)) for a fixed swatch, or (name, {"MS": rgb, "CH": rgb, ...}).

import struct
import zlib

import palette as P1

GRID = 16
CELL = 16
SIZE = GRID * CELL

DISTRICTS = ("MS", "CH", "HB", "MT", "SP")
DISTRICT_NAMES = {"MS": "Main Street", "CH": "City Hall", "HB": "Harbor Bridge", "MT": "Midtown", "SP": "Skyline Park"}
FILE_TAG = {"MS": "MainStreet", "CH": "CityHall", "HB": "HarborBridge", "MT": "Midtown", "SP": "SkylinePark"}


def _b(name):
    """The selected B colour of an overnight swatch."""
    return P1.colour(name, "B")


def _d(ms, ch, hb, mt, sp):
    return {"MS": ms, "CH": ch, "HB": hb, "MT": mt, "SP": sp}


ENTRIES = [
    # ---------------------------------------------------------- road (fixed, B)
    ("asphalt", _b("asphalt")),
    ("asphalt_gutter", _b("asphalt_gutter")),
    ("asphalt_patch", _b("asphalt_patch")),
    ("asphalt_side", _b("asphalt_side")),
    ("shoulder", (124, 122, 126)),
    ("line_white", _b("line_white")),
    ("line_yellow", _b("line_yellow")),
    ("curb", _b("curb")),
    ("curb_top", _b("curb_top")),
    ("sidewalk_a", _b("sidewalk_a")),
    ("sidewalk_b", _b("sidewalk_b")),
    ("sidewalk_edge", _b("sidewalk_edge")),
    ("ground_lot", _b("ground_lot")),
    ("grass", _b("grass")),
    ("grass_dark", _b("grass_dark")),
    ("soil", _b("soil")),
    ("tree_grate", _b("tree_grate")),
    ("deck_concrete", (196, 194, 188)),
    ("deck_under", (150, 150, 148)),
    ("parapet_stone", (220, 214, 200)),
    ("parapet_cap", (234, 230, 220)),
    ("path_gravel", (214, 200, 170)),
    # ---------------------------------------------------------- hazards (fixed)
    ("haz_orange", _b("haz_orange")),
    ("haz_white", _b("haz_white")),
    ("haz_black", _b("haz_black")),
    ("haz_amber", _b("haz_amber")),
    ("cone_orange", _b("cone_orange")),
    ("oil_black", _b("oil_black")),
    ("oil_teal", _b("oil_teal")),
    ("oil_violet", _b("oil_violet")),
    ("oil_gold", _b("oil_gold")),
    ("oil_gloss", _b("oil_gloss")),
    # B2 oil: a controlled edge (muted, darker than the overnight ring, never neon)
    ("oil2_teal", (54, 116, 120)),
    ("oil2_violet", (96, 80, 132)),
    ("oil2_gold", (140, 124, 80)),
    ("oil2_gloss", (88, 98, 120)),
    ("pot_floor", _b("pot_floor")),
    ("pot_wall", _b("pot_wall")),
    ("pot_rim", _b("pot_rim")),
    ("pot_chunk", _b("pot_chunk")),
    # B2 pothole: the far wall faces the camera and catches light, the near side is in shadow
    ("pot_wall_lit", (98, 96, 100)),
    ("pot_shadow", (30, 30, 36)),
    ("crane_yellow", _b("crane_yellow")),
    ("crane_dark", _b("crane_dark")),
    ("crane_cab", _b("crane_cab")),
    ("crane_glass", _b("crane_glass")),
    ("concrete_block", _b("concrete_block")),
    ("fence_mesh", _b("fence_mesh")),
    ("site_dirt", (160, 132, 100)),
    # ---------------------------------------------------------- street furniture (fixed, B)
    ("furn_metal", _b("furn_metal")),
    ("furn_metal_dark", _b("furn_metal_dark")),
    ("lamp_glass", _b("lamp_glass")),
    ("wood", _b("wood")),
    ("wood_dark", _b("wood_dark")),
    ("planter", _b("planter")),
    ("planter_rim", _b("planter_rim")),
    ("leaf_dark", _b("leaf_dark")),
    ("leaf_mid", _b("leaf_mid")),
    ("leaf_light", _b("leaf_light")),
    ("leaf_sun", _b("leaf_sun")),
    ("trunk", _b("trunk")),
    ("hydrant", _b("hydrant")),
    ("hydrant_cap", _b("hydrant_cap")),
    ("bin", _b("bin")),
    ("bin_lid", _b("bin_lid")),
    ("shelter_glass", _b("shelter_glass")),
    ("shelter_roof", _b("shelter_roof")),
    ("sign_green", _b("sign_green")),
    ("sign_white", _b("sign_white")),
    ("signal_housing", _b("signal_housing")),
    ("signal_red", _b("signal_red")),
    ("signal_amber", _b("signal_amber")),
    ("signal_green", _b("signal_green")),
    ("signal_off", _b("signal_off")),
    ("flower_1", _b("flower_1")),
    ("flower_2", _b("flower_2")),
    ("flower_3", (176, 120, 196)),
    ("hedge_dark", (58, 112, 64)),
    ("hedge_light", (92, 150, 82)),
    ("iron", _b("iron")),
    ("iron_light", _b("iron_light")),
    ("ac_body", _b("ac_body")),
    ("ac_fan", _b("ac_fan")),
    ("vent", _b("vent")),
    ("vent_dark", _b("vent_dark")),
    ("tank_wood", _b("tank_wood")),
    ("tank_band", _b("tank_band")),
    ("roof_deck", _b("roof_deck")),
    # bunting pennants (never orange/white: that pairing is the hazard code)
    ("pennant_1", (30, 140, 146)),
    ("pennant_2", (244, 232, 204)),
    ("pennant_3", (150, 52, 60)),
    ("pennant_4", (228, 184, 84)),
    ("pennant_5", (48, 74, 120)),
    # ---------------------------------------------------------- district swatches (per palette)
    #            Main Street      City Hall        Harbor Bridge    Midtown          Skyline Park
    ("wall_1", _d((172, 92, 72), (232, 218, 190), (146, 80, 64), (214, 196, 160), (236, 226, 204))),
    ("wall_2", _d((186, 126, 86), (220, 210, 192), (120, 72, 62), (204, 142, 110), (218, 196, 158))),
    ("wall_3", _d((150, 90, 74), (204, 166, 122), (108, 140, 140), (176, 170, 162), (186, 114, 90))),
    ("wall_4", _d((92, 150, 146), (196, 192, 184), (172, 168, 160), (156, 168, 180), (150, 172, 142))),
    ("stone_1", _d((232, 218, 190), (242, 234, 214), (204, 198, 184), (228, 216, 192), (242, 234, 216))),
    ("stone_2", _d((214, 200, 174), (226, 214, 190), (184, 178, 166), (200, 190, 172), (222, 212, 192))),
    ("trim_1", _d((236, 224, 198), (248, 242, 228), (222, 214, 196), (236, 228, 212), (248, 242, 230))),
    ("trim_2", _d((54, 58, 62), (52, 62, 84), (48, 56, 64), (50, 54, 60), (48, 70, 62))),
    ("course", _d((152, 78, 60), (206, 194, 168), (110, 62, 52), (186, 170, 140), (206, 190, 160))),
    ("reveal", _d((146, 114, 98), (196, 184, 160), (120, 100, 90), (170, 160, 144), (190, 176, 150))),
    ("glass", _d((72, 102, 122), (70, 98, 120), (66, 96, 116), (84, 120, 146), (74, 106, 124))),
    ("glass_light", _d((122, 152, 168), (126, 156, 172), (116, 146, 160), (140, 176, 196), (128, 160, 172))),
    ("glass_dark", _d((52, 72, 88), (50, 70, 88), (48, 66, 80), (58, 86, 108), (52, 74, 88))),
    ("frame", _d((238, 230, 208), (246, 240, 226), (226, 220, 206), (236, 232, 222), (246, 242, 230))),
    ("roof", _d((124, 122, 120), (134, 132, 128), (118, 116, 114), (128, 128, 128), (130, 128, 124))),
    ("roof_dark", _d((96, 94, 94), (104, 102, 100), (90, 88, 88), (98, 98, 100), (100, 98, 96))),
    ("aw_1", _d((40, 140, 140), (40, 62, 98), (40, 62, 98), (40, 62, 98), (42, 104, 76))),
    ("aw_2", _d((128, 44, 52), (42, 96, 72), (40, 124, 126), (58, 62, 70), (40, 140, 140))),
    ("aw_3", _d((40, 62, 98), (128, 44, 52), (70, 82, 96), (30, 130, 136), (128, 44, 52))),
    ("aw_edge", _d((236, 226, 200), (240, 234, 216), (226, 220, 204), (232, 228, 218), (240, 234, 216))),
    ("aw_under", _d((176, 166, 146), (186, 178, 160), (164, 158, 146), (172, 168, 160), (182, 174, 156))),
    ("door_1", _d((40, 98, 92), (36, 52, 84), (40, 84, 70), (50, 54, 60), (42, 96, 72))),
    ("door_2", _d((120, 54, 44), (96, 64, 44), (70, 96, 120), (36, 52, 84), (40, 110, 112))),
    ("acc_1", _d((30, 150, 150), (44, 70, 110), (52, 92, 130), (30, 140, 146), (70, 130, 90))),
    ("acc_2", _d((222, 182, 92), (214, 176, 92), (210, 170, 80), (52, 62, 84), (222, 182, 92))),
    ("ground", _d((188, 184, 174), (214, 206, 190), (176, 174, 168), (186, 184, 180), (196, 190, 176))),
    ("plaza", _d((208, 198, 182), (226, 216, 196), (190, 184, 174), (204, 200, 194), (214, 204, 186))),
    ("display_1", _d((226, 186, 120), (214, 190, 150), (196, 170, 130), (200, 210, 220), (226, 196, 140))),
    ("display_2", _d((180, 120, 70), (150, 120, 90), (140, 110, 90), (130, 150, 170), (170, 130, 90))),
    ("display_3", _d((130, 170, 120), (120, 150, 130), (120, 150, 150), (110, 170, 180), (140, 180, 120))),
    ("shelf", _d((150, 104, 70), (140, 104, 76), (130, 96, 70), (120, 120, 124), (150, 110, 76))),
    # midground (simpler, lighter than the frontage: a value step back)
    ("mid_1", _d((178, 116, 96), (222, 212, 192), (160, 110, 96), (206, 192, 166), (222, 210, 186))),
    ("mid_2", _d((196, 150, 112), (206, 196, 176), (150, 160, 158), (190, 160, 140), (204, 186, 156))),
    ("mid_3", _d((200, 190, 172), (196, 178, 150), (186, 182, 174), (176, 196, 210), (178, 190, 166))),
    ("mid_4", _d((150, 176, 184), (186, 186, 180), (140, 158, 170), (150, 170, 192), (196, 160, 136))),
    ("mid_window", _d((120, 134, 150), (126, 140, 154), (116, 132, 146), (120, 150, 172), (124, 140, 152))),
    ("mid_trim", _d((226, 220, 212), (238, 232, 220), (214, 210, 202), (230, 228, 222), (238, 234, 224))),
    # ---------------------------------------------------------- signs (fixed)
    ("sign_face", (250, 242, 220)),
    ("sign_ink", (36, 44, 70)),
    ("sign_frame_1", (30, 110, 112)),
    ("sign_frame_2", (120, 50, 46)),
    ("sign_frame_3", (40, 60, 100)),
    ("sign_frame_4", (52, 56, 62)),
    ("sign_frame_5", (40, 96, 70)),
    ("sign_gold", (222, 182, 92)),
    ("emblem_red", (196, 64, 56)),
    ("emblem_cheese", (246, 204, 96)),
    ("emblem_crust", (206, 150, 92)),
    ("emblem_steel", (156, 164, 174)),
    ("emblem_white", (248, 246, 240)),
    ("emblem_blue", (60, 110, 170)),
    ("bulb", _b("bulb")),
    # ---------------------------------------------------------- landmarks (fixed)
    ("lm_wall", (232, 218, 190)),
    ("lm_wall_2", (214, 200, 174)),
    ("lm_brick", (172, 92, 72)),
    ("lm_trim", (240, 232, 212)),
    ("marquee", _b("marquee")),
    ("marquee_trim", _b("marquee_trim")),
    ("marquee_under", (176, 166, 146)),
    ("poster_1", _b("poster_1")),
    ("poster_2", _b("poster_2")),
    ("poster_3", _b("poster_3")),
    ("poster_4", _b("poster_4")),
    ("poster_bg", _b("poster_bg")),
    ("reel_steel", (198, 202, 208)),
    ("reel_dark", (60, 66, 76)),
    ("donut_dough", (224, 164, 98)),
    ("donut_dough_dark", (190, 128, 72)),
    ("donut_icing", (248, 140, 182)),
    ("donut_icing_hi", (252, 182, 210)),
    ("sprinkle_1", (255, 240, 120)),
    ("sprinkle_2", (110, 200, 250)),
    ("sprinkle_3", (255, 255, 255)),
    ("sprinkle_4", (120, 220, 150)),
    ("civic_stone", (236, 228, 206)),
    ("civic_column", (246, 240, 224)),
    ("civic_shadow", (204, 194, 170)),
    ("civic_roof", (120, 126, 132)),
    ("copper", (112, 172, 152)),
    ("copper_dark", (82, 138, 120)),
    ("gilt", (226, 190, 96)),
    ("clock_face", (250, 246, 232)),
    ("clock_hand", (36, 40, 50)),
    ("bridge_steel", (64, 98, 126)),
    ("bridge_steel_dark", (44, 66, 86)),
    ("bridge_light", (120, 150, 172)),
    ("water", (82, 150, 170)),
    ("water_light", (126, 186, 198)),
    ("water_dark", (62, 120, 142)),
    ("quay_stone", (178, 168, 150)),
    ("quay_top", (204, 196, 180)),
    ("quay_dark", (122, 116, 106)),
    ("shed_wall", (154, 170, 176)),
    ("shed_roof", (98, 110, 118)),
    ("container_1", (40, 108, 130)),
    ("container_2", (150, 60, 58)),
    ("container_3", (210, 176, 84)),
    ("canopy_white", (242, 242, 238)),
    ("canopy_band", (40, 124, 126)),
    ("canopy_under", (214, 214, 210)),
    ("pump_body", (232, 232, 228)),
    ("pump_accent", (40, 62, 98)),
    ("wash_tile", (206, 228, 232)),
    ("wash_roof", (40, 140, 150)),
    ("brush_1", (64, 140, 220)),
    ("brush_2", (96, 204, 226)),
    ("brush_3", (250, 212, 80)),
    ("brush_core", (70, 76, 84)),
    ("bubble", (214, 238, 248)),
    ("bubble_hi", (246, 252, 255)),
    ("depot_door", (178, 186, 192)),
    ("depot_door_dark", (136, 146, 154)),
    ("parcel", (204, 152, 98)),
    ("parcel_dark", (170, 120, 74)),
    ("parcel_tape", (236, 214, 150)),
    ("fountain_stone", (224, 216, 198)),
    ("fountain_dark", (190, 180, 160)),
    ("fountain_water", (150, 206, 224)),
    ("fountain_water_hi", (214, 238, 246)),
    ("flag_1", (30, 120, 150)),
    ("flag_2", (240, 232, 210)),
    ("stadium_1", (206, 204, 208)),
    ("stadium_2", (188, 190, 200)),
    ("stadium_light", (232, 230, 222)),
    # ---------------------------------------------------------- skyline (fixed, B, pre-hazed)
    ("sky_1", _b("sky_1")),
    ("sky_2", _b("sky_2")),
    ("sky_3", _b("sky_3")),
    ("sky_4", _b("sky_4")),
    ("sky_trim", _b("sky_trim")),
]

NAMES = [e[0] for e in ENTRIES]
SW = {name: i for i, name in enumerate(NAMES)}
assert len(NAMES) == len(set(NAMES)), "duplicate swatch name"
assert len(NAMES) <= GRID * GRID, "palette is full"
FIXED = {e[0] for e in ENTRIES if not isinstance(e[1], dict)}
DISTRICT_SWATCHES = [e[0] for e in ENTRIES if isinstance(e[1], dict)]


def colour(name, district):
    e = ENTRIES[SW[name]]
    if isinstance(e[1], dict):
        return e[1][district]
    return e[1]


def swatch_uv(name):
    i = SW[name]
    gx, gy = i % GRID, i // GRID
    # image rows run top to bottom; Roblox and Blender UV v runs bottom to top
    return ((gx + 0.5) / GRID, 1 - (gy + 0.5) / GRID)


def write_palette_png(path, district):
    """The district's 256 x 256 swatch image; unused cells are a neutral mid grey."""
    rows = []
    for py in range(SIZE):
        gy = py // CELL
        row = bytearray()
        for gx in range(GRID):
            i = gy * GRID + gx
            r, g, b = colour(NAMES[i], district) if i < len(NAMES) else (128, 128, 128)
            row += bytes((r, g, b, 255)) * CELL
        rows.append(bytes(row))
    P1._png(path, SIZE, SIZE, rows)


def swatch_table():
    """For swatches.json: index, name, fixed flag and one colour per district. The "B" column
    repeats Main Street so the overnight Studio builder (paletteId "B") can read it unchanged."""
    out = []
    for i, n in enumerate(NAMES):
        row = {"index": i, "name": n, "fixed": n in FIXED}
        for d in DISTRICTS:
            row[d] = list(colour(n, d))
        row["B"] = list(colour(n, "MS"))
        out.append(row)
    return out


def png_bytes(width, height, rows):
    """Encode RGBA rows as PNG bytes (for the swatch chip sheet in the review renders)."""

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
