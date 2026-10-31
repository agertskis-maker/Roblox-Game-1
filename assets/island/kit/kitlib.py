# Island kit library (Lane 3): geometry helpers, the shared palette and the exporters for the
# headless Blender build (build_kit.py). Low-poly, faceted, seeded. Every face is coloured by
# pointing all its UVs at the centre of one palette swatch, so colour survives any import route
# (MeshPart.TextureID = the uploaded palette image). Units: 1 Blender unit = 1 stud.

import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- palette
# 16 x 16 swatches of 16 px in a 256 x 256 image. Index -> (name, sRGB 0-255).
PALETTE = [
    ("leaf_shadow", (40, 92, 54)), ("leaf_dark", (56, 118, 62)), ("leaf_mid", (78, 148, 70)),
    ("leaf_light", (112, 176, 82)), ("leaf_sun", (156, 200, 92)),
    ("pine_dark", (34, 84, 74)), ("pine_mid", (48, 108, 92)), ("pine_light", (74, 136, 112)),
    ("bark_dark", (84, 58, 42)), ("bark_warm", (122, 84, 56)), ("bark_streak", (150, 108, 74)),
    ("birch_white", (232, 228, 214)), ("birch_grey", (196, 192, 180)), ("birch_mark", (52, 48, 44)),
    ("blossom_deep", (222, 112, 150)), ("blossom", (242, 160, 186)), ("blossom_pale", (250, 206, 220)),
    ("blossom_white", (252, 240, 242)),
    ("fruit_red", (206, 52, 44)), ("fruit_orange", (238, 140, 44)), ("fruit_yellow", (232, 206, 72)),
    ("willow_dark", (96, 140, 60)), ("willow_light", (150, 186, 84)),
    ("tulip_red", (220, 48, 60)), ("tulip_yellow", (246, 204, 60)), ("daisy_white", (248, 246, 238)),
    ("daisy_centre", (244, 190, 40)), ("poppy_red", (232, 60, 40)), ("poppy_centre", (40, 34, 30)),
    ("lavender", (150, 112, 196)), ("lavender_light", (186, 156, 220)), ("wild_blue", (88, 128, 222)),
    ("sunflower", (250, 196, 30)), ("sunflower_centre", (98, 62, 30)), ("stem", (78, 136, 58)),
    ("fern", (70, 140, 66)), ("clover", (86, 152, 74)), ("straw", (196, 182, 112)), ("blade", (98, 168, 70)),
    ("cap_red", (210, 46, 40)), ("cap_white", (244, 240, 230)), ("cap_brown", (150, 102, 62)),
    ("rock", (138, 142, 146)), ("rock_dark", (98, 102, 108)), ("moss", (92, 150, 70)), ("wet_band", (64, 70, 76)),
    ("log_bark", (104, 72, 48)), ("log_inner", (206, 168, 116)), ("plank", (176, 132, 86)), ("plank_dark", (128, 92, 60)),
    ("reed", (110, 150, 70)), ("cattail", (110, 72, 44)), ("pad", (70, 142, 74)), ("pad_dark", (50, 112, 62)),
    ("lily_white", (250, 248, 244)), ("lily_pink", (240, 160, 190)), ("iris", (122, 92, 200)), ("duckweed", (120, 182, 70)),
    ("duck_brown", (140, 102, 70)), ("duck_white", (240, 238, 232)), ("duck_head", (36, 110, 76)),
    ("bill", (240, 150, 40)), ("duckling", (246, 214, 88)), ("raccoon", (130, 130, 134)), ("raccoon_dark", (48, 48, 52)),
    ("wing_orange", (240, 140, 40)), ("wing_blue", (80, 140, 230)), ("dragonfly", (40, 170, 170)),
    ("frog", (96, 170, 70)), ("frog_belly", (214, 222, 150)), ("fish_orange", (240, 130, 50)), ("fish_silver", (196, 206, 214)),
    ("black", (24, 24, 28)),
    ("cart_red", (214, 66, 58)), ("cart_white", (246, 242, 236)), ("awning_yellow", (248, 206, 70)),
    ("icecream_pink", (246, 168, 196)), ("lemon", (250, 222, 80)), ("popcorn_red", (218, 52, 52)),
    ("metal", (64, 72, 82)), ("lamp_glass", (255, 236, 170)), ("bench_wood", (172, 118, 70)),
    ("hedge", (62, 130, 62)), ("hedge_dark", (44, 100, 52)), ("stone_light", (224, 216, 200)),
    ("fountain_water", (110, 186, 220)), ("berry", (180, 34, 70)), ("shrub_flower", (214, 78, 170)),
    ("sapling", (120, 180, 92)), ("bunting_red", (230, 70, 70)), ("bunting_blue", (80, 140, 230)),
    ("bunting_yellow", (250, 206, 70)), ("bunting_green", (90, 180, 110)), ("sign_board", (236, 214, 170)),
    ("rope", (200, 176, 130)), ("leaf_litter", (150, 112, 62)), ("dirt", (122, 92, 64)),
    # appended for the portal lock, sign and plot front (Task 3); existing cells are unchanged
    ("steel", (96, 102, 110)), ("brass", (200, 158, 66)), ("coral", (244, 127, 112)), ("mint", (128, 216, 189)),
    # appended for the Task 4 park4 family (navy / teal structure, cream trims); existing cells are unchanged
    ("navy", (36, 58, 98)), ("teal", (34, 138, 146)), ("cream", (244, 236, 214)),
    # appended for the Task 4 gates family (portal gate themes, lock, plot gate); existing cells are unchanged
    ("deco_gold", (236, 184, 58)), ("sand_red", (190, 82, 56)), ("sand_orange", (226, 134, 74)),
    ("sand_cream", (238, 200, 150)), ("sand_dark", (146, 64, 46)), ("alpine_stone", (218, 224, 230)),
    ("alpine_shadow", (176, 188, 200)), ("snow", (250, 252, 255)), ("ice", (96, 206, 238)),
    ("ice_light", (184, 238, 252)), ("chain_iron", (82, 76, 72)), ("inlay_off", (60, 64, 76)),
    ("accent_neutral", (226, 226, 226)),
    # appended for the Task 4 garage family (sign face, glass, floors, lights); existing cells are unchanged
    ("red_orange", (234, 88, 50)), ("teal_dark", (26, 104, 112)), ("glass", (176, 218, 232)),
    ("glass_tint", (74, 112, 140)), ("concrete", (172, 174, 170)), ("light_panel", (255, 248, 226)),
    ("tile_grey", (210, 212, 214)),
    # appended for the Task 4 gates production pass (Summit frame, lighter chain iron); existing cells are unchanged
    ("frost_blue", (95, 169, 207)), ("iron", (132, 128, 124)), ("iron_hi", (186, 182, 176)),
]
SW = {name: i for i, (name, _) in enumerate(PALETTE)}
GRID = 16
CELL = 16
SIZE = GRID * CELL


def swatch_uv(name):
    i = SW[name]
    gx, gy = i % GRID, i // GRID
    # image rows run top to bottom; Roblox and Blender UV v runs bottom to top
    return ((gx + 0.5) / GRID, 1 - (gy + 0.5) / GRID)


def write_palette_png(path):
    img = bpy.data.images.new("palette", SIZE, SIZE, alpha=True)
    px = [0.0] * (SIZE * SIZE * 4)
    for i, (_, (r, g, b)) in enumerate(PALETTE):
        gx, gy = i % GRID, i // GRID
        for y in range(CELL):
            for x in range(CELL):
                # Blender image rows start at the bottom
                row = SIZE - 1 - (gy * CELL + y)
                k = (row * SIZE + gx * CELL + x) * 4
                px[k : k + 4] = [r / 255, g / 255, b / 255, 1.0]
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# ---------------------------------------------------------------- mesh building
class Builder:
    """Collects faceted geometry: every face keeps its own swatch."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.faces = []

    def face(self, verts, swatch):
        bv = [self.bm.verts.new(v) for v in verts]
        f = self.bm.faces.new(bv)
        u, v = swatch_uv(swatch)
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    def tri(self, a, b, c, swatch):
        return self.face([a, b, c], swatch)

    def quad(self, a, b, c, d, swatch):
        self.face([a, b, c], swatch)
        self.face([a, c, d], swatch)

    def face2(self, verts, swatch):
        """A two-sided face (MeshPart.DoubleSided cannot be set from a script): front and back."""
        self.face(verts, swatch)
        # the back sits a hair behind the front so the vertex merge in to_object keeps both
        v = [Vector(p) for p in verts]
        n = (v[1] - v[0]).cross(v[2] - v[0])
        n = n.normalized() * 0.01 if n.length > 1e-9 else Vector((0, 0, 0))
        self.face([p - n for p in reversed(v)], swatch)

    def triangles(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def to_object(self):
        # shared positions (UVs live on the face corners, so merging changes nothing visible)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        for p in me.polygons:
            p.use_smooth = False
        return obj


def ring(centre, axis, radius, sides, phase=0.0, jitter=0.0, rng=None):
    axis = axis.normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    v = axis.cross(u).normalized()
    pts = []
    for k in range(sides):
        a = phase + 2 * math.pi * k / sides
        r = radius * (1 + (rng.uniform(-jitter, jitter) if rng and jitter else 0))
        pts.append(centre + (u * math.cos(a) + v * math.sin(a)) * r)
    return pts


def tube(b, path, radii, sides, swatches, rng=None, jitter=0.0, cap=True):
    """A faceted tube along a polyline, radius per point; swatches cycles per ring band."""
    rings = []
    for i, p in enumerate(path):
        if i == 0:
            axis = path[1] - path[0]
        elif i == len(path) - 1:
            axis = path[-1] - path[-2]
        else:
            axis = (path[i + 1] - path[i - 1])
        rings.append(ring(p, axis, radii[i], sides, phase=0.37 * i, jitter=jitter, rng=rng))
    for i in range(len(rings) - 1):
        sw = swatches[i % len(swatches)]
        a, c = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            b.quad(a[k], a[k2], c[k2], c[k], sw)
    if cap:
        top = rings[-1]
        tip = path[-1] + (path[-1] - path[-2]).normalized() * radii[-1] * 0.6
        for k in range(sides):
            b.tri(top[k], top[(k + 1) % sides], tip, swatches[-1])
    return rings


def bent_path(base, direction, length, segments, bend, rng, wobble=0.15):
    """A curving polyline: direction drifts by `bend` (a vector added per unit length)."""
    pts = [Vector(base)]
    d = Vector(direction).normalized()
    step = length / segments
    for _ in range(segments):
        d = (d + Vector(bend) * step / length * 2 + Vector((rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble), rng.uniform(-wobble * 0.5, wobble * 0.5))) * 0.4).normalized()
        pts.append(pts[-1] + d * step)
    return pts


def clump(b, centre, size, rng, swatches_by_height, flatten=1.0, subdiv=1, droop=0.0):
    """An uneven faceted foliage clump: a jittered icosphere, coloured by face height/normal."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        s = 1 + rng.uniform(-0.22, 0.22)
        v.co = Vector((n.x * size.x * s, n.y * size.y * s, n.z * size.z * s * flatten))
        if droop and v.co.z < 0:
            v.co.z *= 1 + droop
    for f in bm.faces:
        pts = [centre + v.co for v in f.verts]
        nz = f.normal.z
        cz = sum(v.co.z for v in f.verts) / len(f.verts) / max(size.z, 1e-6)
        # lighter on top and sun side, darker underneath and inside
        light = 0.55 * nz + 0.35 * cz + 0.1 * f.normal.x + rng.uniform(-0.15, 0.15)
        idx = min(len(swatches_by_height) - 1, max(0, int((light + 1) / 2 * len(swatches_by_height))))
        b.face(pts, swatches_by_height[idx])
    bm.free()


def cone(b, base, height, radius, sides, swatches, rng, droop=0.25, jitter=0.12, tip_offset=None):
    """A faceted cone tier, rim drooping below the base ring, for pines."""
    rim = []
    for k in range(sides):
        a = 2 * math.pi * k / sides + rng.uniform(-0.12, 0.12)
        r = radius * (1 + rng.uniform(-jitter, jitter))
        rim.append(base + Vector((math.cos(a) * r, math.sin(a) * r, -droop * radius * rng.uniform(0.7, 1.2))))
    tip = base + Vector((0, 0, height)) + (tip_offset or Vector((0, 0, 0)))
    inner = [base + (p - base) * 0.35 + Vector((0, 0, height * 0.08)) for p in rim]
    for k in range(sides):
        k2 = (k + 1) % sides
        top_face_sw = swatches[min(len(swatches) - 1, 1 + (k % 2))]
        b.tri(rim[k], rim[k2], tip, top_face_sw)
        b.quad(rim[k2], rim[k], inner[k], inner[k2], swatches[0])


def box(b, centre, size, swatch, rot_z=0.0):
    hx, hy, hz = size.x / 2, size.y / 2, size.z / 2
    m = Matrix.Rotation(rot_z, 3, "Z")
    c = [centre + m @ Vector((sx * hx, sy * hy, sz * hz)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    # wound counter-clockwise seen from outside, so every face points out
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    for f in faces:
        b.face([c[i] for i in f], swatch if isinstance(swatch, str) else swatch[faces.index(f) % len(swatch)])


def disc(b, centre, radius, sides, swatch, normal=Vector((0, 0, 1)), thickness=0.0, rng=None, notch=0.0):
    rim = ring(centre, normal, radius, sides, jitter=0.06 if rng else 0, rng=rng)
    if notch:
        rim = rim[: int(sides * (1 - notch)) + 1]
    c = centre
    for k in range(len(rim) - 1 if notch else len(rim)):
        b.tri(c, rim[k], rim[(k + 1) % len(rim)], swatch)
    if thickness:
        under = [p - normal.normalized() * thickness for p in rim]
        for k in range(len(rim) - 1 if notch else len(rim)):
            k2 = (k + 1) % len(rim)
            b.quad(rim[k2], rim[k], under[k], under[k2], swatch)


def rock(b, centre, size, rng, swatches, subdiv=1, wet_band=None):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    # flat-cut planes give broad facets
    for v in bm.verts:
        n = v.co.normalized()
        v.co = Vector((n.x * size.x, n.y * size.y, n.z * size.z)) * (1 + rng.uniform(-0.18, 0.18))
    for f in bm.faces:
        pts = [centre + v.co for v in f.verts]
        z = sum(p.z for p in pts) / len(pts)
        if wet_band is not None and z < wet_band:
            sw = "wet_band"
        else:
            sw = swatches[0] if f.normal.z > 0.55 else swatches[1 if rng.random() > 0.4 else min(2, len(swatches) - 1)]
        b.face(pts, sw)
    bm.free()


def blade(b, base, height, width, lean, swatch, segments=2, twist=0.0):
    """A tapered two-sided blade or leaf strip leaning by `lean` (a horizontal vector per unit height)."""
    side = Vector((-lean.y, lean.x, 0)).normalized() if lean.length > 1e-6 else Vector((1, 0, 0))
    side = Matrix.Rotation(twist, 3, "Z") @ side
    pts = []
    for i in range(segments + 1):
        t = i / segments
        c = base + Vector((0, 0, height * t)) + lean * height * t * t
        w = width * (1 - t) * 0.5
        pts.append((c - side * w, c + side * w))
    for i in range(segments):
        a0, a1 = pts[i]
        b0, b1 = pts[i + 1]
        if i == segments - 1:
            b.face2([a0, a1, (b0 + b1) / 2], swatch)
        else:
            b.face2([a0, a1, b1, b0], swatch)


def stem(b, base, top, radius, swatch, sides=3):
    tube(b, [base, top], [radius, radius * 0.7], sides, [swatch])


def bloom(b, centre, radius, petals, petal_sw, centre_sw, cup=0.25, rng=None):
    """A simple flower head: a ring of two-sided petals round a small centre."""
    for k in range(petals):
        a = 2 * math.pi * k / petals + (rng.uniform(-0.15, 0.15) if rng else 0)
        a2 = a + math.pi / petals
        a0 = a - math.pi / petals
        tip = centre + Vector((math.cos(a) * radius, math.sin(a) * radius, radius * cup))
        l = centre + Vector((math.cos(a0) * radius * 0.45, math.sin(a0) * radius * 0.45, 0))
        r = centre + Vector((math.cos(a2) * radius * 0.45, math.sin(a2) * radius * 0.45, 0))
        b.face2([centre, r, tip, l], petal_sw)
    if centre_sw:
        clump(b, centre + Vector((0, 0, radius * 0.08)), Vector((radius * 0.3, radius * 0.3, radius * 0.22)), rng or random.Random(1), [centre_sw] * 2, subdiv=0)


# ---------------------------------------------------------------- export
def to_roblox(v):
    # Blender Z-up, -Y forward -> Roblox Y-up, -Z forward
    return (v.x, v.z, -v.y)


def export_json(obj, folder, meta):
    """Compact mesh data for the Studio uploader: shared positions (Roblox axes) and, per
    triangle, three vertex indices and the palette swatch index. Normals are flat per face."""
    me = obj.data
    me.calc_loop_triangles()
    uv_layer = me.uv_layers.active.data
    positions = []
    for v in me.vertices:
        positions.extend(round(c, 3) for c in to_roblox(v.co))
    tris = []
    for lt in me.loop_triangles:
        u, v = uv_layer[lt.loops[0]].uv
        gx = min(GRID - 1, int(u * GRID))
        gy = min(GRID - 1, int((1 - v) * GRID))
        # Blender winding is counter-clockwise seen from outside; the Y-up swap keeps it
        tris.extend((lt.vertices[0], lt.vertices[1], lt.vertices[2], gy * GRID + gx))
    lo = [min(positions[i::3]) for i in range(3)]
    hi = [max(positions[i::3]) for i in range(3)]
    data = {
        "name": obj.name,
        "triangles": len(me.loop_triangles),
        "bounds": [lo, hi],
        "meta": meta,
        "grid": GRID,
        "p": positions,
        "t": tris,
    }
    path = os.path.join(folder, obj.name + ".json")
    with open(path, "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return data["triangles"], lo, hi
