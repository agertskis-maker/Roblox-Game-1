# Downtown kit B2: Blender review renders (NOT Roblox) for the direction B production start.
# Headless, no add-ons, no MCP:
#   set PYTHONDONTWRITEBYTECODE=1
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/kit_b2_render.py -- --kit C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2 \
#       --old C:\Users\agert\Documents\Car-Hop-Art\downtown-kit \
#       --out C:\Users\agert\Documents\Car-Hop-Art\review\hud-rebuild\downtown\blender \
#       [--only gallery,theater,hazards,districts,awnings,signs] [--samples 16]
# Builds ONE review street (a private preview arrangement, not a production layout: Lane 1 owns
# segments and DC owns the Studio city grammar): the five districts in fixture order on lane
# width 17, with every landmark, signs, spans, hazards, midground and skyline; plus the overnight
# B theater, pothole and oil (from --old, palette-B.png) at the same spots for before/after; plus
# two orthographic sheets (awnings per district palette, the sign family). Lighting, materials,
# haze, the mesh loader and the proxy car come from render.py (the overnight fixture's identical
# bright daytime). The chase camera is the fixture's: 12 behind, 6 above the car centre, looking
# 20 ahead at 1.5 up, vertical FOV 70, car in lane 2. Every image is stamped "Blender render".
# Sign text is drawn with Blender text objects in Arial Black as a stand-in for the Studio
# SurfaceGui (Fredoka One); it shows where the text faces are and how big the type can be.

import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_b2_palette as P2  # noqa: E402
import render as R1  # noqa: E402
from kit_b2_road import dims  # noqa: E402

W = 17
D = dims(W)
FO = D["frontage"]
LANE2 = -W / 2  # lane 2 centre (lanes 1-4 from the left)
LANE3 = W / 2
CAR_Y = 4.71 / 2
NORMALS = {"Front": (0, 0, -1), "Back": (0, 0, 1), "Left": (-1, 0, 0), "Right": (1, 0, 0), "Top": (0, 1, 0)}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    a = {"samples": 16, "only": None, "set": "new"}
    for i, k in enumerate(argv):
        if k in ("--kit", "--old", "--out", "--set"):
            a[k[2:]] = argv[i + 1]
        elif k == "--samples":
            a["samples"] = int(argv[i + 1])
        elif k == "--only":
            a["only"] = argv[i + 1].split(",")
    return a


def rot(yaw, x, z):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return x * c + z * s, -x * s + z * c


class Scene:
    def __init__(self, kit, old):
        self.kit, self.old = kit, old
        self.meshes, self.data = {}, {}
        self.mats = {}
        for d in P2.DISTRICTS:
            img = bpy.data.images.load(os.path.join(kit, f"palette-B2-{P2.FILE_TAG[d]}.png"))
            img.colorspace_settings.name = "sRGB"
            self.mats[d] = R1.material("B2_" + d, img)
            if d == "MS":
                self.oil = R1.material("B2_Oil", img, rough=0.06, spec=1.0, coat=1.0)
                self.neon = R1.material("B2_Neon", img, emit=1.6)
        img = bpy.data.images.load(os.path.join(old, "palette-B.png"))
        img.colorspace_settings.name = "sRGB"
        self.mat_old = R1.material("OldB", img)
        self.oil_old = R1.material("OldOil", img, rough=0.06, spec=1.0, coat=1.0)
        self.ink = R1.material("Ink", None, rough=0.6, rgba=R1.srgb_to_lin((36, 44, 70)))
        self.font = bpy.data.fonts.load(r"C:\Windows\Fonts\ariblk.ttf")
        self.groups = {}

    def mesh(self, name, old=False):
        key = (name, old)
        if key not in self.meshes:
            me, d = R1.load_mesh(os.path.join(self.old if old else self.kit, "meshes", name + ".json"))
            me.materials.append(self.mats["MS"])
            self.meshes[key], self.data[key] = me, d
        return self.meshes[key], self.data[key]

    def place(self, name, pos, yaw=0.0, district="MS", scale=None, old=False, group="street", text=None):
        me, d = self.mesh(name, old)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.location = R1.B(pos)
        o.rotation_euler = (0, 0, math.radians(yaw))
        if scale is not None:
            o.scale = (scale, scale, scale) if isinstance(scale, (int, float)) else (scale[0], scale[2], scale[1])
        slot = o.material_slots[0]
        slot.link = "OBJECT"
        if "Oil" in name:
            slot.material = self.oil_old if old else self.oil
        elif "LampLens" in name:
            slot.material = self.neon
        else:
            slot.material = self.mat_old if old else self.mats[district if district in self.mats else "MS"]
        self.groups.setdefault(group, []).append(o)
        if text is not None:
            self.texts(o, d, text, group)
        return o, d

    def texts(self, o, d, text, group):
        if text is True:
            text = d["meta"].get("default_text")
        if not text:
            return
        M = o.matrix_basis.copy()
        for f in d["meta"].get("faces", []):
            t = text if isinstance(text, str) else text.get(f.get("name"))
            if not t:
                continue
            n = f.get("normal", "Front")
            nv = NORMALS.get(n) if isinstance(n, str) else n
            if not nv:
                continue
            c = M @ R1.B(f["centre"])
            nb = (M.to_3x3() @ R1.B(nv)).normalized()
            w, h = f["size"]
            vertical = f.get("text") == "vertical"
            cu = bpy.data.curves.new("txt", "FONT")
            if vertical:
                letters = [ch for ch in t]
                cu.body = "\n".join(letters)
                cu.space_line = 0.82
                cu.size = min(w * 0.82, h / (len(letters) * 0.86))
            else:
                cu.body = t
                cu.size = min(h * 0.74, w / (len(t) * 0.74 + 0.5))
            cu.font = self.font
            cu.align_x = "CENTER"
            cu.align_y = "CENTER"
            cu.materials.append(self.ink)
            ob = bpy.data.objects.new("txt_" + o.name, cu)
            bpy.context.scene.collection.objects.link(ob)
            up = Vector((0, 0, 1))
            right = (-nb).cross(up).normalized()
            yv = nb.cross(right).normalized()
            R = Matrix((right, yv, nb)).transposed().to_4x4()
            ob.matrix_world = Matrix.Translation(c + nb * 0.05) @ R
            self.groups.setdefault(group, []).append(ob)

    def show(self, group, visible):
        for o in self.groups.get(group, []):
            o.hide_render = not visible


def ground(sc, s0, s1, x0=-2500, x1=2500):
    gsw = P2.SW["ground_lot"]
    g = P2.GRID
    me = bpy.data.meshes.new("Ground")
    pts = [R1.B((x0, -0.05, -s0)), R1.B((x1, -0.05, -s0)), R1.B((x1, -0.05, -s1)), R1.B((x0, -0.05, -s1))]
    me.from_pydata([tuple(p) for p in pts], [], [(0, 1, 2, 3)])
    uvl = me.uv_layers.new(name="UVMap")
    for li in range(4):
        uvl.data[li].uv = ((gsw % g + 0.5) / g, 1 - (gsw // g + 0.5) / g)
    me.materials.append(sc.mats["MS"])
    o = bpy.data.objects.new("Ground", me)
    bpy.context.scene.collection.objects.link(o)


# ---------------------------------------------------------------- the review street
DISTRICT_RANGES = [("MS", -192, 768), ("CH", 768, 1344), ("HB", 1344, 1920), ("MT", 1920, 2496), ("SP", 2496, 3168)]
LOTS_OLD = {
    "MS": ["B2_Lot_Shop24Low_a", "B2_Lot_Shop24Mid_b", "B2_Lot_Shop24Low_c", "B2_Lot_Shop36Mid_a", "B2_Lot_Shop24Mid_a", "B2_Lot_Shop24Low_b", "B2_Lot_Shop48Low_a", "B2_Lot_Shop24Mid_c", "B2_Lot_Shop24Low_d", "B2_Lot_Shop36Mid_b", "B2_Lot_Pocket24", "B2_Lot_Shop48Low_c"],
    "CH": ["B2_Lot_Civic36Mid_a", "B2_Lot_Shop24Mid_b", "B2_Lot_Civic48Mid_b", "B2_Lot_Shop24Low_a"],
    "HB": ["B2_Lot_Warehouse48Low_a", "B2_Lot_Warehouse36Mid_b", "B2_Lot_Shop24Low_c"],
    # selective glass: one glass volume per six Midtown lots, so the near-road read stays quiet
    "MT": ["B2_Lot_Tall36Grid_a", "B2_Lot_Tall24Brick_b", "B2_Lot_Shop24Mid_a", "B2_Lot_Tall24Brick_b", "B2_Lot_Tall36Glass_a", "B2_Lot_Shop24Low_b"],
    "SP": ["B2_Lot_Townhouse24_a", "B2_Lot_Townhouse24_b", "B2_Lot_Pocket24", "B2_Lot_Townhouse24_a"],
}
MIDS_OLD = {
    "MS": ["B2_Mid_Block36_1", "B2_Mid_Block36_2", "B2_Mid_Block36_3"],
    "CH": ["B2_Mid_CivicDome", "B2_Mid_Block36_1", "B2_Mid_Block36_2"],
    "HB": ["B2_Mid_Warehouse48", "B2_Harbor_Shed24", "B2_Mid_Block36_1"],
    "MT": ["B2_Mid_Glass40", "B2_Mid_Tower40_4", "B2_Mid_Block36_3"],
    "SP": ["B2_Mid_TreeClump", "B2_Mid_TreeClump", "B2_Mid_Block36_1"],
}
SKY_OLD = ["B2_Sky_Stepped_1", "B2_Sky_Stepped_2", "B2_Sky_Slab_1", "B2_Sky_Slab_2", "B2_Sky_Tower_2", "B2_Sky_Spire", "B2_Sky_Stepped_3"]
# Round 2 boulevard set (kit_b2_blvd.py): four-to-six storey frontage with the occasional two-to-three storey lot,
# a taller layered middle distance and a richer skyline. "--set old" reproduces the Round 1 arrangement.
LOTS_NEW = {
    "MS": ["B2_Lot_Shop24Blvd4_a", "B2_Lot_Shop36Blvd5_b", "B2_Lot_Shop24Low_a", "B2_Lot_Shop48Blvd4_a", "B2_Lot_Shop24Step6_a", "B2_Lot_Shop36Blvd4_b", "B2_Lot_Shop24Mid_b", "B2_Lot_Shop36Step5_c", "B2_Lot_Shop24Blvd5_a", "B2_Lot_Pocket24", "B2_Lot_Shop48Blvd5_b", "B2_Lot_Shop24Blvd4_c", "B2_Lot_Shop36Blvd6_a", "B2_Lot_Shop24Blvd4_b", "B2_Lot_Shop48Step6_c"],
    "CH": ["B2_Lot_Civic36Mid_a", "B2_Lot_Shop24Blvd4_b", "B2_Lot_Civic48Mid_b", "B2_Lot_Shop36Blvd5_d", "B2_Lot_Shop24Blvd5_b"],
    "HB": ["B2_Lot_Warehouse48Low_a", "B2_Lot_Warehouse36Mid_b", "B2_Lot_Shop24Low_c"],
    "MT": ["B2_Lot_Tall36Grid_a", "B2_Lot_Shop24Blvd5_a", "B2_Lot_Tall24Brick_b", "B2_Lot_Shop36Step6_b", "B2_Lot_Tall36Glass_a", "B2_Lot_Shop48Blvd6_d", "B2_Lot_Shop24Blvd4_d"],
    "SP": ["B2_Lot_Townhouse24_a", "B2_Lot_Shop24Blvd4_a", "B2_Lot_Townhouse24_b", "B2_Lot_Pocket24", "B2_Lot_Shop36Blvd4_c", "B2_Lot_Townhouse24_a"],
}
MIDS_NEW = {
    "MS": ["B2_Mid_Block36_1", "B2_Mid_Block36_4", "B2_Mid_Block36_2", "B2_Mid_Block48_1", "B2_Mid_Block36_5", "B2_Mid_Block36_3"],
    "CH": ["B2_Mid_CivicDome", "B2_Mid_Block36_4", "B2_Mid_Block48_1", "B2_Mid_Block36_2"],
    "HB": ["B2_Mid_Warehouse48", "B2_Harbor_Shed24", "B2_Mid_Block36_1"],
    "MT": ["B2_Mid_Glass40", "B2_Mid_Tower40_4", "B2_Mid_Block40_6", "B2_Mid_Block36_5", "B2_Mid_Block48_1"],
    "SP": ["B2_Mid_TreeClump", "B2_Mid_Block36_1", "B2_Mid_Block36_4", "B2_Mid_TreeClump"],
}
SKY_NEW = SKY_OLD + ["B2_Sky_Wedding_1", "B2_Sky_Wedding_2", "B2_Sky_Wedding_3", "B2_Sky_Crown_1", "B2_Sky_Crown_2", "B2_Sky_Tank_1", "B2_Sky_Tank_2", "B2_Sky_Needle_1", "B2_Sky_Needle_3"]
LOTS, MIDS, SKY, SKY_H = LOTS_NEW, MIDS_NEW, SKY_NEW, (120.0, 300.0)

SIGNS = [("B2_Sign_WheelGoodPizza", "fascia_1"), ("B2_Sign_BrakeFastDiner", "blade_1"), ("B2_Sign_LugNutsHardware", "fascia_1"), ("B2_Sign_HubcapBooks", "fascia_1"), ("B2_Sign_HonkRollMusic", "blade_1"), ("B2_Sign_ParkBarkPets", "fascia_1")]


def district_at(s):
    for d, a, b in DISTRICT_RANGES:
        if a <= s < b:
            return d
    return "SP"


def place_lot(sc, name, s, side, district, text=True):
    """Right side: pivot at s (footprint s..s+W, yaw 90). Left side: pivot at s + W (yaw -90)."""
    _, d = sc.mesh(name)
    Wl = d["meta"]["width"]
    if side > 0:
        pos, yaw = (FO, 0.0, -s), 90.0
    else:
        pos, yaw = (-FO, 0.0, -(s + Wl)), -90.0
    o, d = sc.place(name, pos, yaw, district, text=text)
    return pos, yaw, d, Wl


def at_socket(pos, yaw, sk):
    x, z = rot(yaw, sk["x"], sk["z"])
    return (pos[0] + x, pos[1] + sk["y"], pos[2] + z), yaw + sk.get("yaw", 0.0)


def build_street(sc):
    rng = random.Random(20261022)
    # road pieces in order (name, length); the second abutment is placed reversed
    pieces = [("Straight192", 192)] * 5 + [("Straight192", 192), ("Intersection96", 96), ("Straight96", 96), ("Straight192", 192)]
    pieces += [("Abutment96", 96), ("BridgeDeck192", 192), ("Abutment96R", 96), ("Straight192", 192)]
    pieces += [("Straight192", 192), ("Intersection96", 96), ("Straight96", 96), ("Straight192", 192)]
    pieces += [("TransitionVerge96", 96), ("Park192", 192), ("Park192", 192), ("Park192", 192)]
    s = -192.0
    for nm, L in pieces:
        if nm.endswith("R"):
            sc.place(f"B2_Road_{nm[:-1]}_L4W{W}", (0, 0, -(s + L)), 180.0)
        else:
            sc.place(f"B2_Road_{nm}_L4W{W}", (0, 0, -s), 0.0, text=None)
        s += L
    ground(sc, -700, 1392)
    ground(sc, 1680, 3800)
    # reserved frontage (landmarks, intersections, the river)
    reserved = {1: [(200, 248), (560, 596), (980.2, 1035.8), (1060, 1132), (1344, 1728), (1740, 1788), (2132.2, 2187.8), (2200, 2248), (2800, 2848)], -1: [(300, 336), (980.2, 1035.8), (1060, 1108), (1344, 1728), (2132.2, 2187.8), (2260, 2308)]}
    sign_i = 0
    for side in (1, -1):
        for dist, a, b in DISTRICT_RANGES:
            bag = list(LOTS[dist])
            k = rng.randrange(len(bag)) if side < 0 else 0
            s = a + (6 if side < 0 else 0)
            last = None
            while s < b:
                name = bag[k % len(bag)]
                k += 1
                if name == last:
                    name = bag[k % len(bag)]
                    k += 1
                Wl = sc.mesh(name)[1]["meta"]["width"]
                hit = next(((r0, r1) for r0, r1 in reserved[side] if s < r1 and s + Wl > r0), None)
                if hit:
                    s = hit[1]
                    continue
                if s + Wl > b + 12:
                    break
                pos, yaw, d, _ = place_lot(sc, name, s, side, dist)
                last = name
                sk = d["meta"]["sockets"]
                # signs on Main Street shops, a water tank on some roofs
                if dist == "MS" and "Shop24" in name and sign_i < len(SIGNS) and rng.random() < 0.8:
                    mesh, socket = SIGNS[sign_i]
                    if socket in sk:
                        p2, y2 = at_socket(pos, yaw, sk[socket])
                        sc.place(mesh, p2, y2, dist, text=True)
                        sign_i += 1
                if name.startswith("B2_Lot_Shop") and "roof_a" in sk and rng.random() < 0.3:
                    p2, y2 = at_socket(pos, yaw, sk["roof_a"])
                    sc.place("B2_Prop_WaterTank", p2, y2, dist)
                elif ("Tall" in name or "Mid" in name) and "roof_b" in sk and rng.random() < 0.5:
                    p2, y2 = at_socket(pos, yaw, sk.get("roof_tank", sk["roof_b"]))
                    sc.place("B2_Prop_WaterTank" if "Tall" in name else "B2_Prop_RoofAC", p2, y2, dist)
                if "fire_escape" in sk and rng.random() < 0.35:
                    p2, y2 = at_socket(pos, yaw, sk["fire_escape"])
                    sc.place("B2_Prop_FireEscape2" if d["meta"]["storeys"] == 3 else "B2_Prop_FireEscape3", p2, y2, dist)
                s += Wl
    # landmarks
    lm = {}
    lm["theater"] = place_lot(sc, "B2_LM_Theater", 560, 1, "MS")
    lm["bakery"] = place_lot(sc, "B2_LM_DonutBakery", 300, -1, "MS")
    lm["construction"] = place_lot(sc, "B2_Haz_ConstructionLot48", 200, 1, "MS", text=None)
    p, y, d, _ = lm["construction"]
    p2, y2 = at_socket(p, y, d["meta"]["sockets"]["crane"])
    sc.place("B2_Haz_Crane", p2, y2)
    lm["cityhall"] = place_lot(sc, "B2_LM_CityHall", 1060, 1, "CH")
    p, y, d, _ = lm["cityhall"]
    p2, y2 = at_socket(p, y, d["meta"]["sockets"]["clock_tower"])
    sc.place("B2_LM_ClockTower", p2, y2)
    for nm in ("lamp_left", "lamp_right"):
        p2, y2 = at_socket(p, y, d["meta"]["sockets"][nm])
        sc.place("B2_Street_LampFormal", p2, y2)
    lm["plaza"] = place_lot(sc, "B2_Lot_Plaza48", 1060, -1, "CH", text=None)
    lm["depot"] = place_lot(sc, "B2_LM_DeliveryDepot", 1740, 1, "HB")
    p, y, d, _ = lm["depot"]
    for nm in ("bollard_1", "bollard_2", "bollard_3"):
        p2, y2 = at_socket(p, y, d["meta"]["sockets"][nm])
        sc.place("B2_Street_Bollard", p2, y2)
    lm["carwash"] = place_lot(sc, "B2_LM_CarWash", 2200, 1, "MT")
    p, y, d, _ = lm["carwash"]
    for nm, sk in d["meta"]["sockets"].items():
        if nm.startswith("brush"):
            p2, y2 = at_socket(p, y, sk)
            sc.place("B2_LM_CarWashBrush", p2, y2 + 20.0 * (int(nm[-1]) % 3))
        elif nm.startswith("roller"):
            p2, y2 = at_socket(p, y, sk)
            sc.place("B2_LM_CarWashRoller", p2, y2 - 90.0)
    lm["canopy"] = place_lot(sc, "B2_LM_ServiceCanopy", 2260, -1, "MT")
    lm["park"] = place_lot(sc, "B2_Lot_Park48", 2800, 1, "SP", text=None)
    p, y, d, _ = lm["park"]
    p2, y2 = at_socket(p, y, d["meta"]["sockets"]["feature"])
    sc.place("B2_LM_Fountain", p2, y2)
    for nm in ("tree_1", "tree_2"):
        p2, y2 = at_socket(p, y, d["meta"]["sockets"][nm])
        sc.place("B2_Street_Tree", p2, y2, scale=1.3)
    sc.place("B2_Sky_Stadium", (480.0, 0, -2700.0), 90.0)
    # harbor: arches, pier, water, quays, waterfront props
    sc.place(f"B2_LM_BridgeArch192_L4W{W}", (0, 0, -1440.0), 0.0)
    sc.place(f"B2_Harbor_Pier_L4W{W}", (0, -7.0, -1536.0), 0.0)
    sc.place("B2_Harbor_Water", (0, 0, -1392.0), 0.0, scale=[1.0, 1.0, 1.5])
    for k in range(4):
        sc.place("B2_Harbor_Quay96", (FO + 96 * k, 0, -1392.0), 0.0)
        sc.place("B2_Harbor_Quay96", (-FO - 96 * (k + 1), 0, -1392.0), 0.0)
        sc.place("B2_Harbor_Quay96", (FO + 96 * (k + 1), 0, -1680.0), 180.0)
        sc.place("B2_Harbor_Quay96", (-FO - 96 * k, 0, -1680.0), 180.0)
        for j in range(4):
            sc.place("B2_Harbor_Bollard", (FO + 96 * k + 12 + 24 * j, 0.6, -1393.6))
    sc.place("B2_Harbor_Crane", (FO + 70.0, 0, -1702.0), 180.0)
    sc.place("B2_Harbor_Crane", (-FO - 150.0, 0, -1372.0), 0.0)
    sc.place("B2_Harbor_Containers", (FO + 120.0, 0, -1715.0), 90.0)
    sc.place("B2_Harbor_Shed24", (-(FO + 50.0), 0, -1376.0), 0.0)
    sc.place("B2_Harbor_Shed24", (FO + 170.0, 0, -1376.0), 0.0)
    # spans
    sc.place(f"B2_Span_Welcome_L4W{W}", (0, 0, -30.0), 0.0, text=True)
    sc.place(f"B2_Span_Bunting_L4W{W}", (0, 0, -150.0), 0.0)
    sc.place(f"B2_Span_Bunting_L4W{W}", (0, 0, -2650.0), 0.0)
    # hazards (Main Street): lane closure in lane 4, pothole lane 2, oil lane 3
    for s in (186.0, 192.0, 198.0, 204.0, 210.0, 216.0):
        sc.place("B2_Haz_Barrier", (25.5 + (s - 186.0) * 0.0, 0, -s - 20.0), 90.0)
    for k in range(6):
        sc.place("B2_Haz_Cone", (25.5 - 6.0 + k * 1.0, 0, -(176.0 + k * 4.0)))
    sc.place("B2_Haz_Sign", (31.0, 0, -160.0), 180.0)
    hz = {}
    hz["pothole"] = sc.place("B2_Haz_Pothole", (LANE2, 0, -430.0), group="haz_new")
    hz["oil"] = sc.place("B2_Haz_Oil", (LANE3, 0, -470.0), group="haz_new")
    sc.place("Pothole", (LANE2, 0, -430.0), old=True, group="haz_old")
    sc.place("OilSlick", (LANE3, 0, -470.0), old=True, group="haz_old")
    sc.show("haz_old", False)
    # the overnight theater at the same spot (before/after); old pivot = facade bottom centre
    p_old = (FO, 0.0, -(560.0 + 16.0))
    sc.place("B_Theater", p_old, 90.0, old=True, group="theater_old", text={"marquee": "NOW SHOWING"})
    bx, bz = rot(90.0, 11.0, 0.0)
    sc.place("B_TheaterBlade", (p_old[0] + bx, 17.0, p_old[2] + bz), 90.0, old=True, group="theater_old", text="REEL WHEELS")
    sc.show("theater_old", False)
    # furniture: lamps every 48 (formal in City Hall), trees between, skipping mouths and the river
    for side in (1, -1):
        for k in range(-3, 66):
            s = 48.0 * k + 12.0
            dist = district_at(s)
            if 1344 <= s <= 1728 or any(r0 - 4 < s < r1 + 4 for r0, r1 in ((980.2, 1035.8), (2132.2, 2187.8))) or 160 <= s <= 230:
                continue
            x = side * (D["curb_out"] + 1.4)
            if dist == "CH":
                sc.place("B2_Street_LampFormal", (x, 0.6, -s), 0.0)
            else:
                sc.place("B2_Street_Lamp", (x, 0.6, -s), 90.0 * side)
                sc.place("B2_Street_LampLens", (x, 0.6, -s), 90.0 * side)
            if dist in ("MS", "CH", "SP", "MT"):
                tx = side * (D["curb_out"] + (2.4 if dist == "SP" else 3.2))
                sc.place("B2_Street_Tree", (tx, 0.6, -(s + 24.0)), rng.uniform(0, 360))
    # midground and skyline
    for side in (1, -1):
        s = -150.0
        while s < 3300:
            dist = district_at(s)
            if not (1392 < s < 1680):
                nm = rng.choice(MIDS[dist])
                off = FO + 70.0 + rng.uniform(0, 60)
                sc.place(nm, (side * off, 0, -s), 90.0 * side, dist)
            s += rng.uniform(46, 66)
        s = -300.0
        while s < 3600:
            nm = rng.choice(SKY)
            off = FO + rng.uniform(320, 820)
            sc.place(nm, (side * off, 0, -s), 0.0, scale=[rng.uniform(40, 90), rng.uniform(*SKY_H), rng.uniform(40, 80)])
            s += rng.uniform(55, 90)
    return lm, hz


# ---------------------------------------------------------------- cameras and shots
def chase(s, lane=LANE2):
    return (lane, CAR_Y + 6.0, -(s - 12.0)), (lane, 1.5, -(s + 20.0))


def reverse(s, lane=LANE2):
    return (lane, CAR_Y + 6.0, -(s + 12.0)), (lane, 1.5, -(s - 20.0))


def shoot(cam, car, path, eye, tgt, note, res, samples, car_s=None, ortho=None, car_x=LANE2):
    cd = cam.data
    if ortho:
        cd.type = "ORTHO"
        cd.sensor_fit = "HORIZONTAL"
        cd.ortho_scale = ortho
    else:
        cd.type = "PERSP"
        cd.sensor_fit = "VERTICAL"
        cd.angle_y = math.radians(70.0)
    for o in car:
        o.hide_render = car_s is None
    if car_s is not None:
        car[0].location = R1.B((car_x, CAR_Y, -car_s))
    R1.setup_render("eevee", samples, res, note)
    R1.aim(cam, eye, tgt)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


def main():
    a = parse_args()
    global LOTS, MIDS, SKY, SKY_H
    if a["set"] == "old":
        LOTS, MIDS, SKY, SKY_H = LOTS_OLD, MIDS_OLD, SKY_OLD, (70.0, 190.0)
    suffix = "" if a["set"] == "new" and not a.get("tag") else "-" + (a.get("tag") or a["set"])
    only = a["only"] or ["gallery", "theater", "hazards", "districts", "awnings", "signs"]
    out = a["out"]
    os.makedirs(out, exist_ok=True)
    R1.clear()
    sc = Scene(a["kit"], a["old"])
    R1.world_setup()
    R1.sun_setup()
    lm, hz = build_street(sc)
    root = R1.proxy_car()
    car = [root] + list(root.children)
    cd = bpy.data.cameras.new("Cam")
    cd.clip_start = 0.3
    cd.clip_end = 5000
    cam = bpy.data.objects.new("Cam", cd)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    S = a["samples"]
    tag = "Blender render (EEVEE) - not Roblox | Downtown B2"
    G = (800, 450)

    def ped(s_m, side, h=14.0):
        # from the opposite sidewalk, eye 5.6 up, toward the landmark's facade middle
        eye = (-side * (FO - 6.0), 5.6, -s_m)
        tgt = (side * (FO + 10.0), h, -s_m)
        return eye, tgt

    if "gallery" in only:
        gal = os.path.join(out, "gallery")
        os.makedirs(gal, exist_ok=True)
        shots = [
            ("theater", "B2_LM_Theater REEL WHEELS", 578.0, 1, 30.0),
            ("bakery", "B2_LM_DonutBakery SPARE TIRE DONUTS", 318.0, -1, 22.0),
            ("cityhall", "B2_LM_CityHall + B2_LM_ClockTower", 1096.0, 1, 40.0),
            ("bridge", "B2_LM_BridgeArch192 HARBOR BRIDGE", 1536.0, 0, 20.0),
            ("depot", "B2_LM_DeliveryDepot BOX HOP", 1764.0, 1, 16.0),
            ("carwash", "B2_LM_CarWash SUDSY WHEELS", 2224.0, 1, 10.0),
            ("canopy", "B2_LM_ServiceCanopy PIT STOP", 2284.0, -1, 12.0),
            ("fountain", "B2_LM_Fountain (Park48 lot)", 2824.0, 1, 6.0),
            ("stadium", "B2_Sky_Stadium (distant)", 2300.0, 1, 30.0),
        ]
        for key, label, s_m, side, h in shots:
            views = [("1-approach", chase(s_m - 110.0), s_m - 110.0), ("2-passing", chase(s_m - 30.0), s_m - 30.0), ("3-rear", reverse(s_m + 70.0), None)]
            if key == "bridge":
                views = [("1-approach", chase(1330.0), 1330.0), ("2-passing", chase(1500.0), 1500.0), ("3-rear", reverse(1760.0), None)]
                ped_view = ((FO + 60.0, 5.6, -1384.0), (0.0, 18.0, -1540.0))
            elif key == "stadium":
                views = [("1-approach", chase(2060.0), 2060.0), ("2-passing", chase(2380.0), 2380.0), ("3-rear", ((-40.0, 40.0, -2050.0), (480.0, 30.0, -2700.0)), None)]
                ped_view = ((FO - 4.0, 5.6, -2420.0), (480.0, 40.0, -2700.0))
            else:
                ped_view = ped(s_m, side, h)
            views.append(("4-pedestrian", ped_view, None))
            for vk, (eye, tgt), car_s in views:
                nm = f"B2-{key}-{vk}"
                shoot(cam, car, os.path.join(gal, nm + ".png"), eye, tgt, f"{tag} | {label} | {vk} ({'chase 12 behind / 6 up, FOV 70' if car_s else ('reverse chase' if 'rear' in vk else 'pedestrian / wide')})", G, S, car_s)
    if "theater" in only:
        for state in ("before", "after"):
            sc.show("theater_old", state == "before")
            for o in [o for o in sc.groups["street"] if o.name.startswith("B2_LM_Theater") or o.name.startswith("txt_B2_LM_Theater")]:
                o.hide_render = state == "before"
            for d in (120.0, 60.0):
                s = 578.0 - d
                nm = f"B2-theater-{state}-{int(d)}ahead{suffix}"
                desc = "overnight B_Theater + B_TheaterBlade" if state == "before" else "B2_LM_Theater"
                shoot(cam, car, os.path.join(out, nm + ".png"), *chase(s), f"{tag} | theater {state}: {desc} | chase, landmark {int(d)} ahead", G, S, s)
        sc.show("theater_old", False)
        for o in sc.groups["street"]:
            if o.name.startswith("B2_LM_Theater") or o.name.startswith("txt_B2_LM_Theater"):
                o.hide_render = False
    if "hazards" in only:
        for state in ("before", "after"):
            sc.show("haz_old", state == "before")
            sc.show("haz_new", state == "after")
            for key, s_h in (("pothole", 430.0), ("oil", 470.0)):
                s = s_h - 32.0
                nm = f"B2-{key}-{state}"
                desc = ("overnight " + ("Pothole" if key == "pothole" else "OilSlick")) if state == "before" else ("B2_Haz_Pothole" if key == "pothole" else "B2_Haz_Oil")
                shoot(cam, car, os.path.join(out, nm + ".png"), *chase(s), f"{tag} | {desc} | chase, 32 ahead", G, S, s)
        sc.show("haz_old", False)
        sc.show("haz_new", True)
    if "districts" in only:
        for d, s, label in (("MS", 470.0, "Main Street"), ("CH", 950.0, "City Hall"), ("HB", 1340.0, "Harbor Bridge"), ("MT", 2080.0, "Midtown"), ("SP", 2690.0, "Skyline Park")):
            shoot(cam, car, os.path.join(out, f"B2-district-{d}{suffix}.png"), *chase(s), f"{tag} | district sample: {label} (palette-B2-{P2.FILE_TAG[d]}) | chase s {int(s)}", (1280, 720), S + 8, s)
    if "median" in only:
        median_sample(sc, cam, car, out, S, tag)
    if "awnings" in only:
        awning_sheet(sc, cam, car, out, S, tag)
    if "signs" in only:
        sign_sheet(sc, cam, car, out, S, tag)


def slab(sc, name, x0, x1, s0, s1, swatch, y=0.0):
    """A flat quad in the review scene (x lateral, s along the route) coloured by one palette swatch."""
    g = P2.GRID
    sw = P2.SW[swatch]
    me = bpy.data.meshes.new(name)
    pts = [R1.B((x0, y, -s0)), R1.B((x1, y, -s0)), R1.B((x1, y, -s1)), R1.B((x0, y, -s1))]
    me.from_pydata([tuple(p) for p in pts], [], [(0, 1, 2, 3)])
    uvl = me.uv_layers.new(name="UVMap")
    for li in range(4):
        uvl.data[li].uv = ((sw % g + 0.5) / g, 1 - (sw // g + 0.5) / g)
    me.materials.append(sc.mats["MS"])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def median_sample(sc, cam, car, out, S, tag):
    """ALTERNATE BOULEVARD SAMPLE (a visual layout PROPOSAL, not part of any chase): two carriageways of two
    17-wide lanes with a 14-wide planted median between them. It exists only because the brief asked for a planted
    median between directions; the live road contract has four lanes in ONE direction, so the main chase keeps its
    unobstructed corridor and gains urban scale from tree-lined verges instead. Built far from the review street."""
    X0 = 6000.0
    S0, S1 = 0.0, 480.0
    half_med, lane, sidewalk = 7.0, 17.0, 10.0
    x_in, x_out = half_med + 1.0, half_med + 1.0 + 2 * lane
    # carriageways, shoulders to the kerbs, the planted median and its kerbs, the sidewalks
    for side in (-1, 1):
        a, b = sorted((X0 + side * x_in, X0 + side * x_out))
        slab(sc, "Carriageway", a, b, S0, S1, "asphalt", 0.0)
        c = X0 + side * (x_in + lane)
        slab(sc, "LaneLine", c - 0.25, c + 0.25, S0, S1, "line_white", 0.02)
        e0, e1 = sorted((X0 + side * x_out, X0 + side * (x_out + sidewalk)))
        slab(sc, "Sidewalk", e0, e1, S0, S1, "sidewalk_a", 0.35)
        k0, k1 = sorted((X0 + side * half_med, X0 + side * (half_med + 0.8)))
        slab(sc, "MedianKerb", k0, k1, S0, S1, "curb_top", 0.4)
    slab(sc, "MedianPlanting", X0 - half_med, X0 + half_med, S0, S1, "grass", 0.38)
    slab(sc, "GroundLeft", X0 - 600, X0 - (x_out + sidewalk), S0 - 80, S1 + 80, "ground_lot", -0.05)
    slab(sc, "GroundRight", X0 + x_out + sidewalk, X0 + 600, S0 - 80, S1 + 80, "ground_lot", -0.05)
    # trees on the median every 24, a lamp every 48; lamps and trees on the sidewalks
    for k in range(0, int(S1 // 24)):
        s = 12.0 + 24.0 * k
        sc.place("B2_Street_Tree", (X0 + (2.5 if k % 2 else -2.5), 0.38, -s), rng_deg(k), scale=1.5)
        if k % 2 == 0:
            sc.place("B2_Street_LampFormal", (X0, 0.38, -(s + 12.0)), 0.0)
        for side in (-1, 1):
            if (k + (side > 0)) % 3 == 0:
                sc.place("B2_Street_Tree", (X0 + side * (x_out + 3.4), 0.35, -(s + 6.0)), rng_deg(k + 7))
    # frontage on both sides: the same four-to-six storey lots as the main boulevard
    names = ["B2_Lot_Shop24Blvd4_a", "B2_Lot_Shop36Blvd5_b", "B2_Lot_Shop48Blvd4_a", "B2_Lot_Shop24Step6_a", "B2_Lot_Shop36Blvd4_b", "B2_Lot_Shop24Blvd5_a", "B2_Lot_Shop36Step5_c", "B2_Lot_Shop24Blvd4_c"]
    fx = x_out + sidewalk
    for side in (1, -1):
        s, k = 0.0, (0 if side > 0 else 3)
        while s < S1 - 30:
            name = names[k % len(names)]
            k += 1
            wl = sc.mesh(name)[1]["meta"]["width"]
            if side > 0:
                sc.place(name, (X0 + fx, 0.0, -s), 90.0, "MS", text=None)
            else:
                sc.place(name, (X0 - fx, 0.0, -(s + wl)), -90.0, "MS", text=None)
            s += wl
    note = tag + " | PROPOSAL, NOT IN ANY CHASE: planted-median boulevard sample, needs a Lane 1 road contract"
    car_x = X0 + x_in + lane * 1.5
    shoot(cam, car, os.path.join(out, "B2-median-sample-chase.png"), (car_x, CAR_Y + 6.0, -(60.0 - 12.0)), (car_x, 1.5, -(60.0 + 20.0)), note + " | chase on the right carriageway", (1280, 720), S + 8, 60.0, car_x=car_x)
    shoot(cam, car, os.path.join(out, "B2-median-sample-high.png"), (X0 + 6.0, 62.0, 30.0), (X0, 4.0, -230.0), note + " | high view down the median", (1280, 720), S + 8, None)
    shoot(cam, car, os.path.join(out, "B2-median-sample-median.png"), (X0 + 3.0, 5.6, -45.0), (X0 - 1.0, 7.0, -190.0), note + " | standing in the median", (1280, 720), S + 8, None)


def rng_deg(k):
    return (k * 137.5) % 360.0


def chip(sc, name, rgb, x0, y0, x1, y1, z):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(R1.B(p)) for p in ((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))], [], [(0, 1, 2, 3)])
    me.materials.append(R1.material(name, None, rough=0.9, haze=False, rgba=R1.srgb_to_lin(rgb)))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def label(sc, text, pos, size, group):
    cu = bpy.data.curves.new("lbl", "FONT")
    cu.body = text
    cu.font = sc.font
    cu.size = size
    cu.align_x = "CENTER"
    cu.materials.append(sc.ink)
    ob = bpy.data.objects.new("lbl", cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = R1.B(pos)
    ob.rotation_euler = (math.radians(90), 0, 0)  # faces Roblox +Z (the sheets are lit from +Z)
    sc.groups.setdefault(group, []).append(ob)
    return ob


def awning_sheet(sc, cam, car, out, S, tag):
    """Per district: the three shop awning colourways and a two-shop 48 lot, front-on
    (orthographic), with chips of the district's awning, wall, stone and trim swatches."""
    names = ["B2_Lot_Shop24Low_a", "B2_Lot_Shop24Low_b", "B2_Lot_Shop24Low_c", "B2_Lot_Shop48Low_a"]
    chips = ["aw_1", "aw_2", "aw_3", "aw_edge", "wall_1", "wall_2", "wall_3", "wall_4", "stone_1", "stone_2", "trim_1", "door_1", "acc_1"]
    # the sheets face +Z (yaw 180) so the facades take the fixture sun (behind-left of the road)
    for i, d in enumerate(P2.DISTRICTS):
        X0, Z0 = 6000.0 + 400.0 * i, 0.0
        grp = "aw_" + d
        x = X0 + 66.0
        for nm in names:
            o, data = sc.place(nm, (x, 0, Z0), 180.0, d, group=grp)
            x -= data["meta"]["width"] + 4.0
        cx = X0 - 66.0
        for c in chips:
            o = chip(sc, f"chip_{d}_{c}", P2.colour(c, d), cx, 41.0, cx + 8.0, 47.0, Z0 + 6.0)
            sc.groups[grp].append(o)
            label(sc, c, (cx + 4.0, 38.6, Z0 + 6.05), 1.5, grp)
            cx += 10.2
    for i, d in enumerate(P2.DISTRICTS):
        for dd in P2.DISTRICTS:
            sc.show("aw_" + dd, dd == d)
        X0 = 6000.0 + 400.0 * i
        shoot(cam, car, os.path.join(out, f"B2-awnings-{d}.png"), (X0, 24.0, 200.0), (X0, 24.0, 0.0), f"{tag} | awnings + swatches: {P2.DISTRICT_NAMES[d]} | front ortho", (800, 300), S, None, ortho=142.0)


def sign_sheet(sc, cam, car, out, S, tag):
    """The fictional sign family on a cream wall, front-on, with text faces filled."""
    X0, Z0 = 9000.0, 0.0
    wall = chip(sc, "signwall", (232, 218, 190), X0 - 80, -2, X0 + 80, 70, Z0 - 0.05)
    sc.groups.setdefault("signs", []).append(wall)
    rows = [
        [("B2_Sign_WheelGoodPizza", 0.0), ("B2_Sign_LugNutsHardware", 0.0), ("B2_Sign_HubcapBooks", 0.0)],
        [("B2_Sign_ParkBarkPets", 0.0), ("B2_Sign_BrakeFastDiner", 1.0), ("B2_Sign_HonkRollMusic", 1.0), ("B2_Sign_CornerBlade", 1.0)],
    ]
    y = 44.0
    for row in rows:
        x = X0 - 66.0
        for nm, yaw in row:  # yaw flag: 1 = blade
            _, data = sc.mesh(nm)
            wdt = data["meta"].get("size", [6.0])[0] if data["meta"].get("kind") == "fascia" else 8.0
            px = x + wdt / 2
            # fascias turned to face +Z (yaw 180); blades turned so a text face looks at +Z (yaw -90)
            o, _ = sc.place(nm, (px - (2.7 if yaw else 0.0), y, Z0), -90.0 if yaw else 180.0, group="signs", text=True)
            label(sc, nm, (px, y - 5.0, Z0 + 0.5), 1.3, "signs")
            x += wdt + 10.0
        y -= 26.0
    for k in list(sc.groups):
        if k.startswith("aw_"):
            sc.show(k, False)
    shoot(cam, car, os.path.join(out, "B2-sign-family.png"), (X0, 34.0, 200.0), (X0, 34.0, 0.0), f"{tag} | sign family (text: Arial Black stand-in for the Studio SurfaceGui)", (1600, 900), S, None, ortho=150.0)


main()
