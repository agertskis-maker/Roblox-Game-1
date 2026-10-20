# Review stills for a built vehicle. Paste into Blender's Python console or run
# through the Blender MCP (safe mode allows bpy, bmesh, mathutils, opening a
# .blend and rendering). Headless Workbench renders came out dark on this
# machine, so review stills are rendered in an interactive Blender session.
#
# Set BLEND and OUT below. Renders: <OUT>/<view>.png and <OUT>/<view>_grey.png.

import bmesh
import bpy
from mathutils import Vector

BLEND = r"C:\Users\agert\Documents\Car-Hop-Art\vehicles\downtown-starter\downtown-starter.blend"
OUT = r"C:\Users\agert\Documents\Car-Hop-Art\vehicles\downtown-starter\renders"
GREY_VIEWS = ("front34", "rear34", "side", "chase")

# name: (camera location, look-at target, ortho scale or None, lens mm)
VIEWS = {
    "front34": ((-11.0, -15.0, 6.0), (0.0, -0.5, 1.9), None, 50),
    "rear34": ((11.0, 15.0, 6.5), (0.0, 0.5, 1.9), None, 50),
    "side": ((40.0, 0.0, 2.4), (0.0, 0.0, 2.4), 14.5, 50),
    "front": ((0.0, -40.0, 2.5), (0.0, 0.0, 2.5), 7.8, 50),
    "rear": ((0.0, 40.0, 2.5), (0.0, 0.0, 2.5), 7.8, 50),
    "top": ((0.0, 0.0, 40.0), (0.0, 0.0, 0.0), 14.5, 50),
    "chase": ((0.0, 15.5, 7.6), (0.0, -8.0, 1.6), None, 32),
    "wheel": ((-6.0, -5.4, 1.6), (-2.4, -3.7, 1.1), None, 60),
    "lamps_rear": ((3.5, 9.5, 3.4), (1.2, 6.2, 2.4), None, 55),
    "lamps_front": ((-3.6, -9.6, 3.0), (-1.2, -6.2, 2.1), None, 55),
}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def setup(grey):
    s = bpy.context.scene
    s.render.engine = "BLENDER_WORKBENCH"
    s.render.resolution_x = 1600
    s.render.resolution_y = 1000
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
    sh.show_object_outline = False
    s.display.render_aa = "16"
    if s.world is None:
        s.world = bpy.data.worlds.new("World")
    s.world.color = (lin(0.91), lin(0.93), lin(0.95))


def ground():
    if bpy.data.objects.get("Ground"):
        return
    me = bpy.data.meshes.new("Ground")
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-100, -100, 0), (100, -100, 0), (100, 100, 0), (-100, 100, 0))]
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
    data.clip_end = 500
    obj = bpy.data.objects.get("ReviewCam")
    if obj is None:
        obj = bpy.data.objects.new("ReviewCam", data)
        bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    up = "Y"
    direction = Vector(tgt) - Vector(loc)
    if abs(direction.normalized().z) > 0.99:
        up = "X"
    obj.rotation_euler = direction.to_track_quat("-Z", up).to_euler()
    bpy.context.scene.camera = obj


bpy.ops.wm.open_mainfile(filepath=BLEND)
ground()
done = []
for grey in (False, True):
    setup(grey)
    for name, (loc, tgt, ortho, lens) in VIEWS.items():
        if grey and name not in GREY_VIEWS:
            continue
        cam(loc, tgt, ortho, lens)
        bpy.context.scene.render.filepath = OUT + "\\" + name + ("_grey" if grey else "") + ".png"
        bpy.ops.render.render(write_still=True)
        done.append(name + ("_grey" if grey else ""))
print("rendered", done)
