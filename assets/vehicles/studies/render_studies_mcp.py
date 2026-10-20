# Comparison renders for the studies. Run in an interactive Blender (Python
# console or the Blender MCP in safe mode). Same-scale lineups keep every car
# at its built size on one ground plane with one camera; "norm_" thumbnails
# scale each camera to the car's length so design language can be compared.

import bmesh
import bpy
from mathutils import Vector

BLEND = r"C:\Users\agert\Documents\Car-Hop-Art\vehicles\studies\studies.blend"
OUT = r"C:\Users\agert\Documents\Car-Hop-Art\vehicles\studies\renders"
STARTERS = ["A", "B", "C"]
TIERS = ["B", "T2", "T3", "T4", "T5"]
LENGTHS = {"A": 12.4, "B": 12.4, "C": 12.4, "T2": 15.8, "T3": 15.4, "T4": 16.0, "T5": 17.0}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def setup(grey, w=1600, h=1000):
    s = bpy.context.scene
    s.render.engine = "BLENDER_WORKBENCH"
    s.render.resolution_x = w
    s.render.resolution_y = h
    s.render.resolution_percentage = 100
    s.view_settings.view_transform = "Standard"
    sh = s.display.shading
    sh.light = "STUDIO"
    sh.color_type = "SINGLE" if grey else "MATERIAL"
    sh.single_color = (0.55, 0.57, 0.60)
    sh.show_shadows = True
    sh.shadow_intensity = 0.3
    sh.show_cavity = False
    sh.show_specular_highlight = True
    s.display.render_aa = "16"
    if s.world is None:
        s.world = bpy.data.worlds.new("World")
    s.world.color = (lin(0.91), lin(0.93), lin(0.95))


def ground():
    if bpy.data.objects.get("Ground"):
        return
    me = bpy.data.meshes.new("Ground")
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-300, -300, 0), (300, -300, 0), (300, 300, 0), (-300, 300, 0))]
    bm.faces.new(vs)
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new("GroundMat")
    mat.diffuse_color = (lin(0.80), lin(0.82), lin(0.85), 1.0)
    me.materials.append(mat)
    obj = bpy.data.objects.new("Ground", me)
    bpy.context.scene.collection.objects.link(obj)


def cam(loc, tgt, ortho, lens):
    data = bpy.data.cameras.get("ReviewCam") or bpy.data.cameras.new("ReviewCam")
    data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        data.ortho_scale = ortho
    data.lens = lens
    data.clip_end = 1000
    obj = bpy.data.objects.get("ReviewCam")
    if obj is None:
        obj = bpy.data.objects.new("ReviewCam", data)
        bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    direction = Vector(tgt) - Vector(loc)
    up = "X" if abs(direction.normalized().z) > 0.99 else "Y"
    obj.rotation_euler = direction.to_track_quat("-Z", up).to_euler()
    bpy.context.scene.camera = obj


def arrange(keys, offsets):
    for o in bpy.data.objects:
        key = o.get("study")
        if key is None:
            continue
        if key in keys:
            base = o["base"]
            off = offsets[keys.index(key)]
            o.location = (base[0] + off[0], base[1] + off[1], base[2])
            o.hide_render = False
        else:
            o.hide_render = True


def shot(name):
    bpy.context.scene.render.filepath = OUT + "\\" + name + ".png"
    bpy.ops.render.render(write_still=True)


bpy.ops.wm.open_mainfile(filepath=BLEND)
ground()
made = []

# 1. Starter studies: each alone, identical cameras.
for key in STARTERS:
    arrange([key], [(0, 0)])
    for grey in (False, True):
        setup(grey)
        tag = "_grey" if grey else ""
        cam((40, 0, 2.4), (0, 0, 2.4), 14.5, 50)
        shot("starter_" + key + "_side" + tag)
        cam((0, 18.0, 7.2), (0, -2.0, 1.4), None, 35)
        shot("starter_" + key + "_chase" + tag)
        cam((-11, -15, 6), (0, -0.5, 1.9), None, 50)
        shot("starter_" + key + "_front34" + tag)
        cam((11, 15, 6.5), (0, 0.5, 1.9), None, 50)
        shot("starter_" + key + "_rear34" + tag)
        made.append(key)

# 2. Tier ladder at world scale, nose to tail, one ortho camera.
ys = []
y = 0.0
for key in TIERS:
    ys.append((0.0, y))
    y += LENGTHS[key] + 3.0
centre = (y - 3.0) / 2 - LENGTHS[TIERS[0]] / 2
arrange(TIERS, [(o[0], o[1] - centre) for o in ys])
for grey in (False, True):
    setup(grey, 2400, 700)
    cam((90, 0, 3.0), (0, 0, 3.0), y + 2, 50)
    shot("tiers_scale_side" + ("_grey" if grey else ""))

# 3. Tier ladder at world scale, side by side, rear chase-style camera.
# Common on the left, Legendary on the right when seen from behind.
xs = [(26.0 - 13.0 * i, 0.0) for i in range(len(TIERS))]
arrange(TIERS, xs)
for grey in (False, True):
    setup(grey, 2400, 1000)
    cam((0, 62, 22), (0, -2, 1.0), None, 40)
    shot("tiers_scale_rear" + ("_grey" if grey else ""))

# 4. Normalized thumbnails: camera distance scaled by car length.
for key in TIERS:
    arrange([key], [(0, 0)])
    k = LENGTHS[key] / 12.4
    for grey in (False, True):
        setup(grey, 900, 600)
        tag = "_grey" if grey else ""
        cam((40, 0, 2.4 * k), (0, 0, 2.4 * k), 14.5 * k, 50)
        shot("norm_" + key + "_side" + tag)
        cam((11 * k, 15 * k, 6.5 * k), (0, 0.5 * k, 1.9 * k), None, 50)
        shot("norm_" + key + "_rear34" + tag)
print("done", made)
