# World kits: Blender review renders (NOT Roblox) for Dusty Highway and Summit Pass. Headless, no add-ons, no MCP:
#   set PYTHONDONTWRITEBYTECODE=1
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/kit_world_render.py -- --world dusty|summit \
#       --kit C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-worlds --b2 C:\Users\agert\Documents\Car-Hop-Art\downtown-kit-b2 \
#       --out C:\Users\agert\Documents\Car-Hop-Art\review\hud-round2\worlds\dusty [--only districts,landmarks,gallery] [--samples 16]
# Builds ONE composition street per World (a private preview arrangement, NOT the planner's output: the Luau Sequencer
# plans the real routes): the five districts in order on the shared road template (the B2_Road pieces, recoloured by the
# World palette: the road cells keep their B2 indices), each with its lots, the tier A landmarks, props, hazards, the
# middle-distance masses and the skyline; then district chase shots, one chase shot per landmark and gallery sheets.
# Lighting, haze, the mesh loader and the proxy car come from render.py's identical bright daytime (tinted per World).
# Every image is stamped "Blender render". Traffic is not shown.

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit_world_palette as WP  # noqa: E402
import render as R1  # noqa: E402

W = 17
FO = 50.8  # frontage line from the carriageway centre (W17)
LANE2 = -W / 2
CAR_Y = 4.71 / 2

WORLDS = {
    "dusty": {
        "tag": "DH",
        "prefix": "DH_",
        "name": "Dusty Highway",
        "skycol": ((246, 226, 196), (104, 166, 214)),
        "districts": [("CactusFlats", 0, 656), ("DinerStrip", 656, 1240), ("RedRockArches", 1240, 1920), ("CanyonBridge", 1920, 2496), ("MirageDunes", 2496, 3160)],
        "lots": {
            "CactusFlats": ["Cactus24_a", "Adobe24_a", "Scrub36_b", "Corral36_a", "Cactus36_b", "Rocks36_a", "Scrub24_a", "Dune36_a", "Oasis24", "Cactus24_a"],
            "DinerStrip": ["Motel48_a", "Cactus24_a", "Stand24_a", "Garage36_a", "Adobe24_a", "Scrub36_b", "Hut24_a", "Cactus36_b", "Rest36_a"],
            "RedRockArches": ["Mesa36_a", "Scrub24_a", "Pillar24_a", "Rocks36_a", "Mesa48_b", "Hoodoo24_b", "Ridge24_a", "Scrub36_b", "Oasis36"],
            "CanyonBridge": ["Cliff48_a", "Ridge24_a", "Mesa36_a", "Cliff36_b", "Rocks36_a", "Scrub24_a", "Mesa48_b"],
            "MirageDunes": ["Dune48_b", "Cactus24_a", "Hut24_a", "Dune36_a", "Stand24_a", "Hoodoo24_b", "Scrub36_b", "Cactus36_b", "Adobe24_a", "Oasis36"],
        },
        "landmarks": [("DH_LM_WindmillTower", 250, 1), ("DH_LM_CactusGarden", 340, -1), ("DH_LM_Diner", 700, 1), ("DH_LM_PumpStation", 1090, -1), ("DH_LM_RockArch", 1420, 1), ("DH_LM_CactusSign", 2560, 1), ("DH_LM_GhostHuts", 2840, -1)],
        "bridge": ("DH_LM_CanyonBridge384", 2016.0),
        "props": {"lamp": "DH_Prop_Pole", "furn": ["DH_Prop_Cactus", "DH_Prop_Rock", "DH_Prop_Barrel", "DH_Prop_FencePost"], "busStop": "DH_Prop_BusShelter"},
        "mids": {"CactusFlats": ["DH_Mid_Mesa_1", "DH_Mid_Butte_1"], "DinerStrip": ["DH_Mid_Butte_1", "DH_Mid_Mesa_2"], "RedRockArches": ["DH_Mid_Mesa_1", "DH_Mid_Mesa_2", "DH_Mid_Butte_2"], "CanyonBridge": ["DH_Mid_Mesa_2", "DH_Mid_Butte_2"], "MirageDunes": ["DH_Mid_Dune_1", "DH_Mid_Butte_1"]},
        "sky": ["DH_Sky_Mesa_1", "DH_Sky_Mesa_2", "DH_Sky_Mesa_3", "DH_Sky_Ridge_1", "DH_Sky_Ridge_2", "DH_Sky_Spire"],
        "haz": [("DH_Haz_Sinkhole", 520.0, LANE2), ("DH_Haz_SandDrift", 980.0, W / 2), ("DH_Haz_Rockslide", 1700.0, LANE2)],
        "gallery_lots": ["Cactus24_a", "Cactus36_b", "Scrub24_a", "Scrub36_b", "Rocks36_a", "Adobe24_a", "Corral36_a", "Motel48_a", "Stand24_a", "Garage36_a", "Mesa36_a", "Mesa48_b", "Pillar24_a", "Hoodoo24_b", "Cliff48_a", "Cliff36_b", "Ridge24_a", "Dune36_a", "Dune48_b", "Hut24_a", "Oasis24", "Oasis36", "Rest36_a"],
        "gallery_lm": ["WindmillTower", "CactusGarden", "Diner", "PumpStation", "RockArch", "CactusSign", "GhostHuts", "GhostTown", "WaterTank"],
        "gallery_misc": ["DH_Prop_Pole", "DH_Prop_BusShelter", "DH_Prop_Cactus", "DH_Prop_Rock", "DH_Prop_Barrel", "DH_Prop_FencePost", "DH_Haz_Sinkhole", "DH_Haz_SandDrift", "DH_Haz_Rockslide"],
    },
    "summit": {
        "tag": "SU",
        "prefix": "SP_",
        "name": "Summit Pass",
        "skycol": ((214, 230, 246), (92, 156, 224)),
        "districts": [("PineVillage", 0, 648), ("SkiLiftRidge", 648, 1248), ("FrozenLake", 1248, 1920), ("GlacierTunnel", 1920, 2496), ("SummitLodge", 2496, 3176)],
        "lots": {
            "PineVillage": ["Chalet24_a", "Cabin24_a", "Cafe36_a", "Pines24_b", "Shop24_a", "Chalet36_b", "Bank36_a", "Lodge48_a", "Snowfield24", "Pines36_a", "Firepit36_a"],
            "SkiLiftRidge": ["Shed36_a", "Pines36_a", "Chalet24_a", "Rocks36_a", "Cafe36_a", "Peak36_a", "Bank24_b", "Chalet36_b", "Crag24_a", "Snowfield36"],
            "FrozenLake": ["Pier36_a", "Ice24_a", "Cabin24_a", "Pines24_b", "Ice36_b", "Peak36_a", "Serac36_a", "Bank36_a", "Snowfield24"],
            "GlacierTunnel": ["Serac48_b", "Ice24_a", "Rocks36_a", "Serac36_a", "Peak48_b", "Ice36_b", "Crag24_a", "Pines24_b"],
            "SummitLodge": ["Lodge48_a", "Chalet24_a", "Shop24_a", "Pines36_a", "Chalet36_b", "Peak36_a", "Bank24_b", "Cabin24_a", "Rocks36_a", "Firepit36_a", "Snowfield36"],
        },
        "landmarks": [("SP_LM_ChaletCluster", 230, 1), ("SP_LM_BellTower", 520, -1), ("SP_LM_SkiLift", 940, 1), ("SP_LM_WarmingHut", 1120, -1), ("SP_LM_FrozenLake", 1300, 1), ("SP_LM_SkateHut", 1600, -1), ("SP_LM_SummitLodge", 2560, 1), ("SP_LM_Observatory", 2760, -1), ("SP_LM_SnowmenRow", 2860, 1)],
        "bridge": ("SP_LM_GlacierTunnel384", 2016.0),
        "props": {"lamp": "SP_Prop_Pole", "furn": ["SP_Prop_Pine", "SP_Prop_Rock", "SP_Prop_Snowman", "SP_Prop_FencePost", "SP_Prop_Barrel"], "busStop": "SP_Prop_BusShelter"},
        "mids": {"PineVillage": ["SP_Mid_Slope_1", "SP_Mid_Slope_2"], "SkiLiftRidge": ["SP_Mid_Peak_1", "SP_Mid_Slope_2"], "FrozenLake": ["SP_Mid_Slope_1", "SP_Mid_Peak_2"], "GlacierTunnel": ["SP_Mid_Glacier_1", "SP_Mid_Peak_2"], "SummitLodge": ["SP_Mid_Peak_1", "SP_Mid_Peak_2", "SP_Mid_Slope_1"]},
        "sky": ["SP_Sky_Peak_1", "SP_Sky_Peak_2", "SP_Sky_Peak_3", "SP_Sky_Ridge_1", "SP_Sky_Ridge_2", "SP_Sky_Horn"],
        "haz": [("SP_Haz_FrostCrack", 520.0, LANE2), ("SP_Haz_IcePatch", 1000.0, W / 2), ("SP_Haz_Snowbank", 1700.0, LANE2)],
        "gallery_lots": ["Chalet24_a", "Chalet36_b", "Cabin24_a", "Cafe36_a", "Shop24_a", "Lodge48_a", "Pines36_a", "Pines24_b", "Bank36_a", "Bank24_b", "Rocks36_a", "Shed36_a", "Ice24_a", "Ice36_b", "Pier36_a", "Peak36_a", "Peak48_b", "Crag24_a", "Serac36_a", "Serac48_b", "Snowfield24", "Snowfield36", "Firepit36_a"],
        "gallery_lm": ["ChaletCluster", "BellTower", "SkiLift", "WarmingHut", "FrozenLake", "SkateHut", "SummitLodge", "Observatory", "SnowmenRow", "FestivalStage", "SledHill"],
        "gallery_misc": ["SP_Prop_Pole", "SP_Prop_BusShelter", "SP_Prop_Pine", "SP_Prop_Rock", "SP_Prop_Snowman", "SP_Prop_Barrel", "SP_Prop_FencePost", "SP_Haz_FrostCrack", "SP_Haz_IcePatch", "SP_Haz_Snowbank"],
    },
}


class WScene:
    def __init__(self, cfg, kit, b2):
        self.cfg, self.kit, self.b2 = cfg, kit, b2
        img = bpy.data.images.load(os.path.join(kit, f"palette-{cfg['tag']}.png"))
        img.colorspace_settings.name = "sRGB"
        self.mat = R1.material("World_" + cfg["tag"], img)
        self.meshes = {}
        self.data = {}
        self.objs = []

    def mesh(self, name):
        if name not in self.meshes:
            folder = os.path.join(self.b2 if name.startswith("B2_") else self.kit, "meshes")
            me, d = R1.load_mesh(os.path.join(folder, name + ".json"))
            me.materials.append(self.mat)
            self.meshes[name], self.data[name] = me, d
        return self.meshes[name], self.data[name]

    def place(self, name, pos, yaw=0.0, scale=None):
        me, d = self.mesh(name)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        o.location = R1.B(pos)
        o.rotation_euler = (0, 0, math.radians(yaw))
        if scale is not None:
            o.scale = (scale, scale, scale) if isinstance(scale, (int, float)) else (scale[0], scale[2], scale[1])
        slot = o.material_slots[0]
        slot.link = "OBJECT"
        slot.material = self.mat
        self.objs.append(o)
        return o, d

    def lot(self, name, s, side):
        """Right side: pivot at s (footprint s..s+W, yaw 90). Left side: pivot at s + W (yaw -90)."""
        _, d = self.mesh(name)
        wl = d["meta"]["width"]
        if side > 0:
            self.place(name, (FO, 0.0, -s), 90.0)
        else:
            self.place(name, (-FO, 0.0, -(s + wl)), -90.0)
        return wl


def ground(sc, s0, s1, swatch="g_sand", x0=-2500, x1=2500):
    g = WP.GRID
    sw = WP.SW[swatch]
    me = bpy.data.meshes.new("Ground")
    pts = [R1.B((x0, -0.05, -s0)), R1.B((x1, -0.05, -s0)), R1.B((x1, -0.05, -s1)), R1.B((x0, -0.05, -s1))]
    me.from_pydata([tuple(p) for p in pts], [], [(0, 1, 2, 3)])
    uvl = me.uv_layers.new(name="UVMap")
    for li in range(4):
        uvl.data[li].uv = ((sw % g + 0.5) / g, 1 - (sw // g + 0.5) / g)
    me.materials.append(sc.mat)
    o = bpy.data.objects.new("Ground", me)
    bpy.context.scene.collection.objects.link(o)


def build_street(sc, cfg):
    rng = random.Random(20261023 + len(cfg["name"]))
    pre = cfg["prefix"]
    # road: straights, the bridge run (abutment, two decks, abutment reversed) in the bridge district
    bridge_name, bridge_s = cfg["bridge"]
    s = -192.0
    while s < 3300:
        if abs(s - (bridge_s - 96.0)) < 1.0:
            sc.place(f"B2_Road_Abutment96_L4W{W}", (0, 0, -s))
            s += 96.0
            for _ in range(2):
                sc.place(f"B2_Road_BridgeDeck192_L4W{W}", (0, 0, -s))
                s += 192.0
            sc.place(f"B2_Road_Abutment96_L4W{W}", (0, 0, -(s + 96.0)), 180.0)
            s += 96.0
            continue
        step = 96.0 if abs(s + 96.0 - (bridge_s - 96.0)) < 1.0 or abs(s + 96.0 - bridge_s) < 1.0 else 192.0
        sc.place(f"B2_Road_Straight{int(step)}_L4W{W}", (0, 0, -s))
        s += step
    ground(sc, -700, 3800)
    # the bridge landmark centres on the deck centre
    sc.place(bridge_name, (0, 0, -bridge_s))
    # lots on both sides, district by district; the landmark frontage and the bridge are reserved
    reserved = {1: [], -1: []}
    for name, st, side in cfg["landmarks"]:
        _, d = sc.mesh(name)
        wl = d["meta"]["width"]
        reserved[side].append((st - 6, st + wl + 6))
        if side > 0:
            sc.place(name, (FO, 0.0, -st), 90.0)
        else:
            sc.place(name, (-FO, 0.0, -(st + wl)), -90.0)
    for side in (1, -1):
        reserved[side].append((bridge_s - 200, bridge_s + 200))
    for dist, a, b in cfg["districts"]:
        bag = [pre + "Lot_" + n for n in cfg["lots"][dist]]
        for side in (1, -1):
            s = a + (6 if side < 0 else 0)
            k = 0 if side > 0 else 3
            last = None
            while s < b:
                name = bag[k % len(bag)]
                k += 1
                if name == last:
                    name = bag[k % len(bag)]
                    k += 1
                wl = sc.mesh(name)[1]["meta"]["width"]
                hit = next(((r0, r1) for r0, r1 in reserved[side] if s < r1 and s + wl > r0), None)
                if hit:
                    s = hit[1]
                    continue
                if s + wl > b + 12:
                    break
                sc.lot(name, s, side)
                last = name
                s += wl
    # props: poles every 48 (alternating sides), furniture between
    pr = cfg["props"]
    for side in (1, -1):
        for k in range(-3, 70):
            s = 48.0 * k + (12.0 if side < 0 else 36.0)
            if bridge_s - 100 <= s <= bridge_s + 484:
                continue
            x = side * (50.8 - 12.8 + 1.4 + 4.0)
            sc.place(pr["lamp"], (x, 0.6, -s), 90.0 * side + 0.0)
            fs = s + 24.0
            if fs < 3200 and not (bridge_s - 100 <= fs <= bridge_s + 484):
                kind = pr["furn"][(k + (side > 0)) % len(pr["furn"])]
                sc.place(kind, (side * (50.8 - 12.8 + 1.4 + 6.0), 0.6, -fs), rng.uniform(0, 360))
    # hazards on the road surface
    for name, s_h, lane_x in cfg["haz"]:
        sc.place(name, (lane_x, 0.02, -s_h))
    # middle distance and skyline
    for side in (1, -1):
        s = -150.0
        while s < 3300:
            dist = next((d for d, a, b in cfg["districts"] if a <= s < b), cfg["districts"][-1][0])
            if not (bridge_s - 100 <= s <= bridge_s + 484):
                nm = rng.choice(cfg["mids"][dist])
                off = FO + 70.0 + rng.uniform(0, 60)
                sc.place(nm, (side * off, 0, -s), 90.0 * side)
            s += rng.uniform(46, 66)
        s = -300.0
        while s < 3600:
            nm = rng.choice(cfg["sky"])
            off = FO + rng.uniform(320, 820)
            sc.place(nm, (side * off, 0, -s), 0.0, scale=[rng.uniform(60, 140), rng.uniform(70, 190), rng.uniform(60, 110)])
            s += rng.uniform(70, 120)


def chase(s, lane=LANE2):
    return (lane, CAR_Y + 6.0, -(s - 12.0)), (lane, 1.5, -(s + 20.0))


def shoot(cam, car, path, eye, tgt, note, res, samples, car_s=None):
    cd = cam.data
    cd.type = "PERSP"
    cd.sensor_fit = "VERTICAL"
    cd.angle_y = math.radians(70.0)
    for o in car:
        o.hide_render = car_s is None
    if car_s is not None:
        car[0].location = R1.B((LANE2, CAR_Y, -car_s))
    R1.setup_render("eevee", samples, res, note)
    R1.aim(cam, eye, tgt)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


def gallery(sc, cfg, names, cols, spacing, origin_x, origin_s):
    """Meshes on a grid off the street (x +origin_x), each at its authored size, facade toward the camera at -Z."""
    for i, nm in enumerate(names):
        r, c = divmod(i, cols)
        sc.place(nm, (origin_x + c * spacing, 0, -(origin_s + r * spacing)), 0.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    a = {"samples": 16, "only": None}
    for i, k in enumerate(argv):
        if k in ("--world", "--kit", "--b2", "--out"):
            a[k[2:]] = argv[i + 1]
        elif k == "--samples":
            a["samples"] = int(argv[i + 1])
        elif k == "--only":
            a["only"] = argv[i + 1].split(",")
    cfg = WORLDS[a["world"]]
    only = a["only"] or ["districts", "landmarks", "gallery"]
    out = a["out"]
    os.makedirs(out, exist_ok=True)
    R1.clear()
    R1.SKY_HORIZON, R1.SKY_ZENITH = cfg["skycol"]
    sc = WScene(cfg, a["kit"], a["b2"])
    R1.world_setup()
    R1.sun_setup()
    build_street(sc, cfg)
    pre = cfg["prefix"]
    # a gallery area to the side (x 9000): lots, landmarks, props and hazards
    GX = 9000.0
    lots = [pre + "Lot_" + n for n in cfg["gallery_lots"]]
    lms = [pre + "LM_" + n for n in cfg["gallery_lm"]]
    gallery(sc, cfg, lots, 8, 56.0, GX, 0.0)
    gallery(sc, cfg, lms, 5, 90.0, GX, 240.0)
    gallery(sc, cfg, cfg["gallery_misc"], 9, 30.0, GX, 480.0)
    ground_g = bpy.data.meshes.new("GalleryGround")
    root = R1.proxy_car()
    car = [root] + list(root.children)
    cd = bpy.data.cameras.new("Cam")
    cd.clip_start = 0.3
    cd.clip_end = 6000
    cam = bpy.data.objects.new("Cam", cd)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    S = a["samples"]
    tag = f"Blender render (EEVEE) - not Roblox | {cfg['name']} kit"
    if "districts" in only:
        for dist, st, en in cfg["districts"]:
            mid = (st + en) / 2 if dist not in ("CanyonBridge", "GlacierTunnel") else st + 40
            shoot(cam, car, os.path.join(out, f"W-district-{dist}.png"), *chase(mid), f"{tag} | district sample: {dist} | chase s {int(mid)}", (1280, 720), S + 8, mid)
        bridge_name, bridge_s = cfg["bridge"]
        shoot(cam, car, os.path.join(out, "W-bridge-approach.png"), *chase(bridge_s - 150.0), f"{tag} | {bridge_name} | approach, 150 ahead", (1280, 720), S + 8, bridge_s - 150.0)
        shoot(cam, car, os.path.join(out, "W-bridge-on.png"), *chase(bridge_s - 60.0), f"{tag} | {bridge_name} | on the span", (1280, 720), S + 8, bridge_s - 60.0)
    if "landmarks" in only:
        for name, st, side in cfg["landmarks"]:
            key = name.split("LM_")[1]
            shoot(cam, car, os.path.join(out, f"W-landmark-{key}.png"), *chase(st - 90.0), f"{tag} | {name} | chase, landmark 90 ahead", (1280, 720), S + 8, st - 90.0)
    if "gallery" in only:
        # lots grid, landmarks, props and hazards seen from a raised three-quarter view
        rows = (len(lots) + 7) // 8
        shoot(cam, car, os.path.join(out, "W-gallery-lots.png"), (GX + 3.5 * 56.0, 150.0, 130.0), (GX + 3.5 * 56.0, 10.0, -(rows * 28.0)), f"{tag} | gallery: {len(lots)} lots (facade toward the camera)", (1600, 900), S, None)
        shoot(cam, car, os.path.join(out, "W-gallery-landmarks.png"), (GX + 2.0 * 90.0, 160.0, 240.0 + 110.0), (GX + 2.0 * 90.0, 20.0, -(240.0 + 40.0)), f"{tag} | gallery: landmarks", (1600, 900), S, None)
        shoot(cam, car, os.path.join(out, "W-gallery-props.png"), (GX + 4.0 * 30.0, 30.0, 480.0 + 40.0), (GX + 4.0 * 30.0, 3.0, -(480.0 + 4.0)), f"{tag} | gallery: props and hazards", (1600, 700), S, None)


main()
