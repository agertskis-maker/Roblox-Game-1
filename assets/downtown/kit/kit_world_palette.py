# World kits palette (Lane 3, Round 2, R2-DH1 / R2-SP1): ONE 16 x 16 swatch layout shared by the two new Worlds,
# DH Dusty Highway and SU Summit Pass, in the same family as kit_b2_palette (a mesh points each triangle at the
# centre of one swatch; one mesh recolours per World by swapping the palette image or the swatches.json column).
#
# The shared road pieces (B2_Road_*) are NOT rebuilt: they keep their B2 swatch indices. This layout keeps those
# indices (asphalt, kerbs, sidewalks, verge, bridge steel, abutment stone) in the same cells and gives them
# per-World colours (a warm cream road for Dusty Highway, a cool slate road with frosted verges for Summit Pass).
# Every other cell is a World swatch. A swatch is either fixed (one colour for both Worlds) or a {DH, SU} pair; the
# generic names (w_wall_1, r_1, p_mid, ...) mean "the World's wall / rock / plant" so a recipe can serve both.
#
# Pure Python (no bpy), like kit_b2_palette, so the build and plain-Python checks can both import it.

import importlib
import os
import sys

import kit_b2_palette as P2

GRID = P2.GRID
CELL = P2.CELL
SIZE = P2.SIZE
WORLDS = ("DH", "SU")
WORLD_NAMES = {"DH": "Dusty Highway", "SU": "Summit Pass"}
FILE_TAG = {"DH": "DustyHighway", "SU": "SummitPass"}

# the B2 cells the shared road meshes use (by name, at their B2 index) and their colours per World
ROAD = {
    "asphalt": ((196, 176, 144), (90, 98, 114)),
    "asphalt_gutter": ((172, 154, 124), (76, 84, 100)),
    "asphalt_patch": ((188, 168, 138), (84, 92, 108)),
    "asphalt_side": ((180, 162, 132), (82, 90, 106)),
    "shoulder": ((214, 192, 158), (146, 154, 168)),
    "line_white": ((252, 248, 238), (250, 252, 255)),
    "line_yellow": ((244, 200, 70), (240, 196, 80)),
    "curb": ((232, 222, 204), (196, 206, 220)),
    "curb_top": ((244, 236, 220), (222, 232, 244)),
    "sidewalk_a": ((232, 214, 184), (226, 234, 244)),
    "sidewalk_b": ((222, 204, 174), (214, 224, 238)),
    "sidewalk_edge": ((210, 190, 160), (190, 202, 220)),
    "ground_lot": ((226, 188, 138), (236, 243, 250)),
    "grass": ((176, 160, 100), (196, 214, 204)),
    "grass_dark": ((146, 130, 82), (150, 176, 164)),
    "soil": ((176, 126, 92), (140, 130, 128)),
    "tree_grate": ((120, 104, 90), (92, 100, 114)),
    "deck_concrete": ((214, 196, 170), (176, 186, 202)),
    "deck_under": ((150, 130, 112), (108, 120, 140)),
    "parapet_stone": ((214, 170, 130), (168, 180, 198)),
    "parapet_cap": ((236, 196, 160), (214, 224, 238)),
    "path_gravel": ((200, 176, 140), (196, 204, 214)),
    "bridge_steel": ((156, 108, 86), (96, 116, 150)),
    "bridge_steel_dark": ((110, 74, 58), (66, 82, 112)),
    "quay_stone": ((190, 130, 100), (150, 166, 188)),
    "quay_top": ((220, 168, 134), (200, 214, 232)),
    "quay_dark": ((130, 86, 66), (96, 108, 128)),
}

# the World swatches: (name, DH rgb, SU rgb); a name used by both Worlds means the same role in each
WORLD_SWATCHES = [
    # buildings
    ("w_wall_1", (214, 150, 108), (150, 98, 66)),
    ("w_wall_2", (246, 234, 204), (250, 242, 226)),
    ("w_wall_3", (120, 200, 190), (104, 68, 50)),
    ("w_wall_4", (236, 214, 176), (238, 244, 250)),
    ("w_trim_1", (150, 98, 72), (250, 242, 226)),
    ("w_trim_2", (250, 244, 228), (84, 66, 56)),
    ("w_roof_1", (176, 92, 64), (204, 72, 66)),
    ("w_roof_2", (130, 96, 74), (212, 224, 238)),
    ("w_roof_flat", (200, 170, 130), (232, 240, 248)),
    ("w_accent_1", (54, 176, 170), (242, 190, 78)),
    ("w_accent_2", (206, 84, 70), (204, 72, 66)),
    ("w_accent_3", (240, 196, 70), (52, 112, 84)),
    ("w_glass", (96, 150, 170), (150, 190, 220)),
    ("w_glass_light", (170, 214, 224), (214, 234, 248)),
    ("w_door", (54, 160, 156), (120, 70, 52)),
    # rock, in strata from dark to light, plus its top and shadow
    ("r_1", (150, 66, 46), (90, 102, 124)),
    ("r_2", (176, 82, 56), (110, 124, 146)),
    ("r_3", (198, 100, 64), (134, 148, 170)),
    ("r_4", (222, 134, 88), (160, 174, 194)),
    ("r_top", (232, 168, 112), (238, 244, 250)),
    ("r_shadow", (112, 50, 42), (70, 82, 104)),
    ("r_pale", (226, 190, 150), (206, 224, 240)),
    # ground
    ("g_hi", (240, 208, 156), (248, 251, 254)),
    ("g_sand", (226, 188, 138), (232, 240, 248)),
    ("g_lo", (200, 160, 112), (196, 210, 228)),
    ("g_track", (186, 146, 104), (170, 184, 204)),
    ("g_water", (70, 176, 190), (120, 176, 214)),
    ("g_water_deep", (40, 130, 150), (74, 130, 182)),
    # plants
    ("p_dark", (52, 112, 82), (36, 84, 64)),
    ("p_mid", (78, 148, 92), (52, 112, 84)),
    ("p_light", (126, 182, 106), (84, 150, 112)),
    ("p_flower", (232, 104, 128), (244, 248, 252)),
    ("p_trunk", (150, 108, 76), (104, 72, 52)),
    ("p_trunk_dark", (110, 78, 54), (76, 52, 40)),
    # materials
    ("m_wood_1", (156, 112, 78), (150, 104, 72)),
    ("m_wood_2", (116, 80, 56), (104, 70, 50)),
    ("m_metal", (150, 156, 164), (150, 158, 170)),
    ("m_metal_dark", (88, 94, 104), (84, 90, 102)),
    ("m_rust", (160, 92, 56), (140, 90, 64)),
    ("m_stone", (190, 170, 146), (170, 180, 196)),
    ("m_white", (250, 246, 236), (252, 253, 255)),
    ("m_black", (46, 44, 48), (44, 46, 54)),
    ("m_light", (255, 230, 150), (255, 236, 170)),
    ("m_sign", (250, 240, 214), (250, 244, 226)),
    ("m_sign_frame", (120, 76, 54), (84, 66, 56)),
    # hazards: the construction language (orange / white) is shared and reserved for hazards
    ("haz_orange", (240, 120, 30), (240, 120, 30)),
    ("haz_white", (248, 246, 240), (248, 246, 240)),
    ("haz_black", (44, 44, 48), (44, 44, 48)),
    ("hz_dark", (96, 52, 40), (30, 56, 92)),
    ("hz_rim", (214, 170, 120), (150, 190, 226)),
    ("hz_light", (240, 214, 168), (232, 244, 252)),
    ("hz_gloss", (255, 244, 220), (200, 232, 255)),
    # distant masses (pre-hazed, lighter and less saturated toward the sky)
    ("sk_1", (214, 160, 128), (176, 190, 210)),
    ("sk_2", (222, 176, 142), (190, 204, 222)),
    ("sk_3", (206, 150, 120), (166, 182, 204)),
    ("sk_4", (230, 196, 160), (204, 216, 232)),
    ("sk_trim", (240, 214, 184), (226, 236, 246)),
]

# V2 (Dusty Highway / Summit Pass build, 2026-10-28, decision 0026): a build with KIT_WORLD_V2=1 in the environment (or
# --v2 on the command line) also merges two extension modules, each owned by one World's kit author:
#   kit_world_palette_dh2.py   NEW_SWATCHES = [(name, (DH r, g, b), (SU r, g, b)), ...]  and  OVERRIDES = {name: {"DH": rgb}}
#   kit_world_palette_su2.py   the same, for the Summit Pass column
# New swatches are appended after the Round 2 list, so every Round 2 index is unchanged; OVERRIDES recolour an existing
# swatch (a ROAD cell or a World swatch) in that World's column only. Without V2 nothing here changes, so the Round 2
# kit (Car-Hop-Art\downtown-kit-worlds) can still be rebuilt exactly.
V2 = os.environ.get("KIT_WORLD_V2") == "1" or "--v2" in sys.argv
OVERRIDES = {}
if V2:
    for _modname in ("kit_world_palette_dh2", "kit_world_palette_su2"):
        try:
            _ext = importlib.import_module(_modname)
        except ImportError:
            continue
        WORLD_SWATCHES.extend(_ext.NEW_SWATCHES)
        for _n, _c in getattr(_ext, "OVERRIDES", {}).items():
            OVERRIDES.setdefault(_n, {}).update(_c)

# cells: the shared road names stay at their B2 index; World swatches fill the other cells in order
_road_cells = {P2.SW[n]: n for n in ROAD}
NAMES = [None] * (GRID * GRID)
for _i, _n in _road_cells.items():
    NAMES[_i] = _n
_free = [i for i in range(len(NAMES)) if NAMES[i] is None]
assert len(WORLD_SWATCHES) <= len(_free), "world palette is full"
for _k, _w in enumerate(WORLD_SWATCHES):
    NAMES[_free[_k]] = _w[0]
_used = [n for n in NAMES if n]
assert len(_used) == len(set(_used)), "duplicate world swatch name"
SW = {n: i for i, n in enumerate(NAMES) if n}


def colour(name, world):
    k = 0 if world == "DH" else 1
    if name in OVERRIDES and world in OVERRIDES[name]:
        return tuple(OVERRIDES[name][world])
    if name in ROAD:
        return ROAD[name][k]
    for w in WORLD_SWATCHES:
        if w[0] == name:
            return w[1 + k]
    raise KeyError(name)


def swatch_uv(name):
    i = SW[name]
    gx, gy = i % GRID, i // GRID
    return ((gx + 0.5) / GRID, 1 - (gy + 0.5) / GRID)


def write_palette_png(path, world):
    """The World's 256 x 256 swatch image; unused cells are a neutral mid grey."""
    rows = []
    for py in range(SIZE):
        gy = py // CELL
        row = bytearray()
        for gx in range(GRID):
            i = gy * GRID + gx
            r, g, b = colour(NAMES[i], world) if NAMES[i] else (128, 128, 128)
            row += bytes((r, g, b, 255)) * CELL
        rows.append(bytes(row))
    P2.P1._png(path, SIZE, SIZE, rows)


def swatch_table():
    """For swatches.json: index, name and one colour per World (columns DH and SU). Cells that no mesh uses are
    left out, so the Studio loader never invents colours."""
    out = []
    for i, n in enumerate(NAMES):
        if not n:
            continue
        row = {"index": i, "name": n, "fixed": n in ROAD or n.startswith("haz_")}
        for w in WORLDS:
            row[w] = list(colour(n, w))
        out.append(row)
    return out
