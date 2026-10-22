# Downtown look development: Blender review renders of one direction's layout (NOT Roblox).
# Headless, no add-ons, no MCP:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       --python assets/downtown/kit/render.py -- --kit C:\Users\agert\Documents\Car-Hop-Art\downtown-kit \
#       --dir A --out C:\Users\agert\Documents\Car-Hop-Art\review\hud-downtown\downtown\blender \
#       [--mode stills|chase|both] [--samples 24] [--chase-frames 96] [--only chase-s030,ped-s60]
# Reads layout-<dir>.json, meshes/<Name>.json and palette-<dir>.png from --kit. Builds the scene
# with linked duplicates (one mesh datablock per kit mesh), the fixture's identical bright
# daytime light (sun + sky colour, distance haze for the skyline), the fixture camera (vertical
# FOV 70) and a Puglet-sized proxy car (pop blue) in lane 2. Every image is stamped
# "Blender render" so it is never mistaken for a Roblox capture.
# Stills: chase-s030/115/200/262 and ped-s60/ped-s250 at 1280 x 720 (EEVEE; Workbench fallback).
# Chase pass: N frames along s 0..336 at 960 x 540 into chase-<dir>/frame_####.png (assemble
# with ffmpeg at 24 fps).

import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fixture as F  # noqa: E402
import palette  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    a = {"mode": "both", "samples": 24, "chase_frames": 96, "only": None, "engine": "eevee", "chase_samples": 16}
    for i, k in enumerate(argv):
        if k == "--kit":
            a["kit"] = argv[i + 1]
        elif k == "--dir":
            a["dir"] = argv[i + 1]
        elif k == "--out":
            a["out"] = argv[i + 1]
        elif k == "--mode":
            a["mode"] = argv[i + 1]
        elif k == "--samples":
            a["samples"] = int(argv[i + 1])
        elif k == "--chase-samples":
            a["chase_samples"] = int(argv[i + 1])
        elif k == "--chase-frames":
            a["chase_frames"] = int(argv[i + 1])
        elif k == "--only":
            a["only"] = argv[i + 1].split(",")
        elif k == "--engine":
            a["engine"] = argv[i + 1]
    return a


def B(p):
    """Roblox (x, y, z) -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def srgb_to_lin(c):
    def f(x):
        x = x / 255.0
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4

    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


# identical lighting for A, B and C (fixture: ClockTime 13.5, Brightness 2.2 in Studio)
SKY_HORIZON = (216, 236, 246)
SKY_ZENITH = (104, 178, 230)
AMBIENT = (150, 176, 206)
AMBIENT_STRENGTH = 1.25
SUN_STRENGTH = 2.6
SUN_ELEVATION = 56.0
SUN_AZIMUTH = 215.0  # degrees, measured from the driving direction (-Z) toward +X: behind-left
HAZE_START, HAZE_END, HAZE_MAX = 260.0, 1500.0, 0.6


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def material(name, img, rough=0.7, spec=0.35, emit=0.0, coat=0.0, haze=True, rgba=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    if coat and "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.05
    if rgba is not None:
        bsdf.inputs["Base Color"].default_value = rgba
        col_socket = None
    else:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        col_socket = tex.outputs["Color"]
    if emit:
        if col_socket is not None:
            nt.links.new(col_socket, bsdf.inputs["Emission Color"])
        else:
            bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emit
    shader = bsdf.outputs["BSDF"]
    if haze:
        cam = nt.nodes.new("ShaderNodeCameraData")
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = HAZE_START
        mr.inputs["From Max"].default_value = HAZE_END
        mr.inputs["To Min"].default_value = 0.0
        mr.inputs["To Max"].default_value = HAZE_MAX
        mr.clamp = True
        nt.links.new(cam.outputs["View Distance"], mr.inputs["Value"])
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = srgb_to_lin(SKY_HORIZON)
        em.inputs["Strength"].default_value = 1.0
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(mr.outputs["Result"], mix.inputs["Fac"])
        nt.links.new(shader, mix.inputs[1])
        nt.links.new(em.outputs["Emission"], mix.inputs[2])
        shader = mix.outputs["Shader"]
    nt.links.new(shader, out.inputs["Surface"])
    return mat


def world_setup():
    w = bpy.data.worlds.new("Daylight")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 0.55
    mr.clamp = True
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    mixc = nt.nodes.new("ShaderNodeMix")
    mixc.data_type = "RGBA"
    nt.links.new(mr.outputs["Result"], mixc.inputs[0])
    mixc.inputs[6].default_value = srgb_to_lin(SKY_HORIZON)
    mixc.inputs[7].default_value = srgb_to_lin(SKY_ZENITH)
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(mixc.outputs[2], bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = 1.0
    bg_light = nt.nodes.new("ShaderNodeBackground")
    bg_light.inputs["Color"].default_value = srgb_to_lin(AMBIENT)
    bg_light.inputs["Strength"].default_value = AMBIENT_STRENGTH
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg_light.outputs["Background"], mix.inputs[1])
    nt.links.new(bg_cam.outputs["Background"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def sun_setup():
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy = SUN_STRENGTH
    ld.angle = math.radians(2.0)
    ld.color = (1.0, 0.97, 0.92)
    o = bpy.data.objects.new("Sun", ld)
    bpy.context.scene.collection.objects.link(o)
    # direction toward the sun in Roblox axes: azimuth from -Z toward +X, then elevation
    az, el = math.radians(SUN_AZIMUTH), math.radians(SUN_ELEVATION)
    to_sun = (math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el))
    d = B(to_sun)
    o.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    return o


def load_mesh(path):
    with open(path) as fh:
        d = json.load(fh)
    p = d["p"]
    verts = [B((p[i], p[i + 1], p[i + 2])) for i in range(0, len(p), 3)]
    t = d["t"]
    faces = [(t[i], t[i + 1], t[i + 2]) for i in range(0, len(t), 4)]
    sw = [t[i + 3] for i in range(0, len(t), 4)]
    me = bpy.data.meshes.new(d["name"])
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    g = d["grid"]
    for poly, s in zip(me.polygons, sw):
        gx, gy = s % g, s // g
        uv = ((gx + 0.5) / g, 1 - (gy + 0.5) / g)
        for li in poly.loop_indices:
            uvl.data[li].uv = uv
    me.validate()
    return me, d


def box_mesh(name, size, centre=(0, 0, 0)):
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] + centre[0], v.co.y * size[1] + centre[1], v.co.z * size[2] + centre[2]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def cyl_mesh(name, r, w):
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=r, radius2=r, depth=w)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def proxy_car():
    """Puglet-sized proxy: 5.66 wide, 4.71 tall, 12.47 long (Blender: x width, y length, z up),
    pivot at the car centre. Pop blue body, dark cabin glass, black wheels."""
    W, Ht, L = F.CAR_SIZE
    root = bpy.data.objects.new("ProxyCar", None)
    bpy.context.scene.collection.objects.link(root)
    blue = material("CarBlue", None, rough=0.35, spec=0.6, coat=0.6, haze=False, rgba=srgb_to_lin((28, 112, 255)))
    glass = material("CarGlass", None, rough=0.15, spec=0.6, haze=False, rgba=srgb_to_lin((34, 48, 70)))
    tyre = material("CarTyre", None, rough=0.8, haze=False, rgba=srgb_to_lin((28, 28, 32)))
    white = material("CarLight", None, rough=0.3, haze=False, rgba=srgb_to_lin((250, 246, 230)), emit=0.5)
    red = material("CarTail", None, rough=0.3, haze=False, rgba=srgb_to_lin((230, 40, 40)), emit=0.6)
    zc = -Ht / 2  # bottom of the car relative to its centre
    parts = [
        (box_mesh("CarBody", (W, L, 2.2), (0, 0, zc + 0.75 + 1.1)), blue),
        (box_mesh("CarCabin", (W * 0.86, L * 0.5, 1.7), (0, -0.6, zc + 2.95 + 0.85)), glass),
        (box_mesh("CarRoof", (W * 0.8, L * 0.44, 0.2), (0, -0.6, zc + 4.61)), blue),
        (box_mesh("CarLampL", (1.1, 0.2, 0.5), (-1.9, L / 2 + 0.05, zc + 2.3)), white),
        (box_mesh("CarLampR", (1.1, 0.2, 0.5), (1.9, L / 2 + 0.05, zc + 2.3)), white),
        (box_mesh("CarTailL", (1.1, 0.2, 0.5), (-1.9, -L / 2 - 0.05, zc + 2.3)), red),
        (box_mesh("CarTailR", (1.1, 0.2, 0.5), (1.9, -L / 2 - 0.05, zc + 2.3)), red),
    ]
    for me, mat in parts:
        me.materials.append(mat)
        o = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(o)
        o.parent = root
    for x in (-W / 2 + 0.5, W / 2 - 0.5):
        for y in (-L / 2 + 2.3, L / 2 - 2.3):
            me = cyl_mesh("Wheel", 1.15, 1.0)
            me.materials.append(tyre)
            o = bpy.data.objects.new("Wheel", me)
            bpy.context.scene.collection.objects.link(o)
            o.parent = root
            o.location = (x, y, zc + 1.15)
            o.rotation_euler = (0, math.radians(90), 0)
    return root


def place_car(root, s):
    p, yaw = F.car_pose(s)
    root.location = B(p)
    root.rotation_euler = (0, 0, math.radians(yaw))


def aim(cam, eye, target):
    cam.location = B(eye)
    d = B(target) - B(eye)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def setup_render(engine, samples, res, note):
    sc = bpy.context.scene
    ok = True
    if engine == "eevee":
        try:
            sc.render.engine = "BLENDER_EEVEE"
            sc.eevee.taa_render_samples = samples
            sc.eevee.use_shadows = True
            try:
                sc.eevee.use_raytracing = False
            except Exception:
                pass
        except Exception as e:
            print("EEVEE unavailable:", e)
            ok = False
    if engine != "eevee" or not ok:
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.light = "STUDIO"
        sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
    except Exception as e:
        print("view transform:", e)
    sc.view_settings.exposure = 0.0
    sc.render.use_stamp = True
    for k in ("date", "time", "render_time", "frame", "frame_range", "memory", "hostname", "camera", "lens", "scene", "marker", "filename", "sequencer_strip"):
        try:
            setattr(sc.render, "use_stamp_" + k, False)
        except Exception:
            pass
    sc.render.use_stamp_note = True
    sc.render.stamp_note_text = note
    sc.render.stamp_font_size = 18 if res[0] >= 1280 else 14
    sc.render.stamp_background = (0, 0, 0, 0.55)


def main():
    a = parse_args()
    kit, d = a["kit"], a["dir"]
    os.makedirs(a["out"], exist_ok=True)
    with open(os.path.join(kit, f"layout-{d}.json")) as fh:
        layout = json.load(fh)
    clear()
    img = bpy.data.images.load(os.path.join(kit, f"palette-{d}.png"))
    img.colorspace_settings.name = "sRGB"
    mats = {
        "default": material("Kit", img),
        "neon": material("KitNeon", img, emit=1.6, haze=True),
        "oil": material("KitOil", img, rough=0.06, spec=1.0, coat=1.0),
        "glass": material("KitGlass", img, rough=0.25, spec=0.6),
    }
    world_setup()
    sun_setup()
    # ground: one big lot plane at y -0.05 (the Studio builder uses a Part)
    gsw = palette.SW["ground_lot"]
    g = palette.GRID
    me = bpy.data.meshes.new("Ground")
    R = 4000
    me.from_pydata([(-R, -R, -0.05), (R, -R, -0.05), (R, R, -0.05), (-R, R, -0.05)], [], [(0, 1, 2, 3)])
    uvl = me.uv_layers.new(name="UVMap")
    for li in range(4):
        uvl.data[li].uv = ((gsw % g + 0.5) / g, 1 - (gsw // g + 0.5) / g)
    me.materials.append(mats["default"])
    go = bpy.data.objects.new("Ground", me)
    bpy.context.scene.collection.objects.link(go)

    meshes = {}
    anims = []
    for inst in layout["instances"]:
        name = inst["mesh"]
        if name not in meshes:
            me, data = load_mesh(os.path.join(kit, "meshes", name + ".json"))
            hint = str(data.get("meta", {}).get("material", "")).lower()
            if name == "OilSlick":
                me.materials.append(mats["oil"])
            elif name in ("LampLens",) or "neon" in hint:
                me.materials.append(mats["neon"])
            else:
                me.materials.append(mats["default"])
            meshes[name] = me
        o = bpy.data.objects.new(name, meshes[name])
        bpy.context.scene.collection.objects.link(o)
        o.location = B(inst["position"])
        o.rotation_euler = (0, 0, math.radians(inst.get("yaw", 0.0)))
        s = inst.get("scale", 1.0)
        if isinstance(s, (int, float)):
            o.scale = (s, s, s)
        else:
            o.scale = (s[0], s[2], s[1])
        if inst.get("anim"):
            anims.append((o, inst))
    print(f"placed {len(layout['instances'])} instances of {len(meshes)} meshes")

    car = proxy_car()
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = math.radians(F.FOV_V)
    cam_data.clip_start = 0.3
    cam_data.clip_end = 4000
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    def set_anims(t):
        for o, inst in anims:
            an = inst["anim"]
            if an.get("type") == "slide":
                p0, p1 = Vector(an["from"]), Vector(an["to"])
                period = an.get("period", 12.0)
                pass_time = an.get("pass_time", 4.0)
                ph = ((t + an.get("offset", 0.0)) % period) / pass_time
                if ph > 1.0:
                    ph = -1.0
                if ph < 0:
                    o.location = B((0, -500, 0))
                else:
                    o.location = B(tuple(p0.lerp(p1, ph)))

    label = f"Blender render (EEVEE) - not Roblox | Downtown {d}: {layout.get('title', '')}"
    if a["mode"] in ("stills", "both"):
        setup_render(a["engine"], a["samples"], (1280, 720), label)
        shots = []
        for s in F.CHASE_FRAMES:
            eye, tgt = F.chase_camera(s)
            shots.append((f"chase-s{int(s):03d}", s, eye, tgt))
        lm = layout.get("landmark_target")
        for nm, eye, tgt in F.pedestrian_cameras(lm):
            shots.append((nm, 30.0, eye, tgt))
        for nm, s, eye, tgt in shots:
            if a["only"] and nm not in a["only"]:
                continue
            place_car(car, s)
            set_anims(layout.get("still_anim_time", 0.0))
            aim(cam, eye, tgt)
            bpy.context.scene.render.stamp_note_text = f"{label} | {nm}"
            path = os.path.join(a["out"], f"{d}-{nm}.png")
            bpy.context.scene.render.filepath = path
            try:
                bpy.ops.render.render(write_still=True)
            except Exception as e:
                print("render failed, falling back to Workbench:", e)
                setup_render("workbench", a["samples"], (1280, 720), label)
                bpy.ops.render.render(write_still=True)
            print("wrote", path)
    if a["mode"] in ("chase", "both"):
        setup_render(a["engine"], a["chase_samples"], (960, 540), label)
        folder = os.path.join(a["out"], f"chase-{d}")
        os.makedirs(folder, exist_ok=True)
        n = a["chase_frames"]
        for i in range(n):
            s = 336.0 * i / n
            t = i / 24.0
            place_car(car, s)
            set_anims(t)
            eye, tgt = F.chase_camera(s)
            aim(cam, eye, tgt)
            bpy.context.scene.render.stamp_note_text = f"{label} | chase pass s {s:.0f}"
            bpy.context.scene.render.filepath = os.path.join(folder, f"frame_{i + 1:04d}.png")
            bpy.ops.render.render(write_still=True)
        print("chase frames written to", folder)


main()
