"""Car Hop vehicle kit: builds shaped low-poly car meshes in Blender from a spec.

Run only inside Blender (bpy, bmesh, mathutils). Used by the study and car
recipes in assets/vehicles/. Headless use:

    blender -b --factory-startup --python assets/vehicles/<id>/build.py -- --out <dir>

Conventions (provisional, see assets/vehicles/README.md):
- 1 Blender unit = 1 Roblox stud.
- The car faces -Y, up is +Z, ground is z = 0. The car's left side is +X.
  With the FBX settings in export_fbx() the car faces Roblox -Z, up +Y,
  and its right side is Roblox +X.
- Every mesh object is named after its colour role, so Studio can recolour
  by name. Wheels are separate objects with their origin on the axle.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def lerp(a, b, t):
    return a + (b - a) * t


def interp(table, y):
    """Piecewise-linear lookup in a list of (y, value) pairs sorted by y."""
    if y <= table[0][0]:
        return table[0][1]
    for i in range(1, len(table)):
        y0, v0 = table[i - 1]
        y1, v1 = table[i]
        if y <= y1:
            t = (y - y0) / (y1 - y0) if y1 != y0 else 0.0
            return lerp(v0, v1, t)
    return table[-1][1]


def smooth_interp(table, y):
    """Like interp, but eased (smoothstep) between keys, for rounded profiles."""
    if y <= table[0][0]:
        return table[0][1]
    for i in range(1, len(table)):
        y0, v0 = table[i - 1]
        y1, v1 = table[i]
        if y <= y1:
            t = (y - y0) / (y1 - y0) if y1 != y0 else 0.0
            t = t * t * (3 - 2 * t)
            return lerp(v0, v1, t)
    return table[-1][1]


def bump(y, centre, half_width):
    """Smooth 0..1..0 bump used for fender volume over the wheels."""
    d = abs(y - centre) / half_width
    if d >= 1:
        return 0.0
    return 0.5 + 0.5 * math.cos(d * math.pi)


def hex_rgba(hexstr):
    h = hexstr.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255

    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b), 1.0)


# ---------------------------------------------------------------------------
# Materials (preview only: Roblox does not import Blender material colours)
# ---------------------------------------------------------------------------

ROLE_ORDER = ["BodyPrimary", "BodySecondary", "Trim", "Glass", "Headlamp", "Taillamp", "Plate", "Tire", "WheelMetal", "Hidden"]
# "Hidden" marks faces buried inside other geometry; they are never exported.


def role_material(role, hexstr):
    name = "Role_" + role
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    rgba = hex_rgba(hexstr)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = None
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            bsdf = node
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = rgba
        rough = {"BodyPrimary": 0.32, "BodySecondary": 0.35, "Glass": 0.15, "WheelMetal": 0.35}.get(role, 0.6)
        bsdf.inputs["Roughness"].default_value = rough
        if role == "WheelMetal":
            bsdf.inputs["Metallic"].default_value = 0.6
    return mat


def setup_materials(palette):
    mats = {}
    for role in ROLE_ORDER:
        mats[role] = role_material(role, palette.get(role, "#808080"))
    return mats


# ---------------------------------------------------------------------------
# Mesh building blocks
# ---------------------------------------------------------------------------


class Part:
    """A bmesh plus a role per face, kept until the final split by role."""

    def __init__(self):
        self.bm = bmesh.new()
        self.layer = self.bm.faces.layers.int.new("role")

    def face(self, verts, role):
        f = self.bm.faces.new(verts)
        f[self.layer] = ROLE_ORDER.index(role)
        return f

    def add_part(self, other, matrix=None):
        """Append another Part's geometry (optionally transformed)."""
        mapping = {}
        for v in other.bm.verts:
            co = v.co.copy()
            if matrix is not None:
                co = matrix @ co
            mapping[v] = self.bm.verts.new(co)
        for f in other.bm.faces:
            nf = self.bm.faces.new([mapping[v] for v in f.verts])
            nf[self.layer] = f[other.layer]
            nf.smooth = f.smooth


def full_ring(half_pts, y):
    """Mirror a half section (from bottom centre to top centre, x >= 0) into a
    closed loop of 3D points at station y. Returns points in loop order."""
    left = [(x, y, z) for (x, z) in half_pts]
    right = [(-x, y, z) for (x, z) in reversed(half_pts[1:-1])]
    return left + right


def loft(part, rings, role_of, cap_start=True, cap_end=True, cap_role="BodyPrimary"):
    """Join consecutive rings (same point count) with quads.

    role_of(i, j) gives the role for the quad between ring i and i+1 that starts
    at point j. Returns the vertex grid."""
    bm = part.bm
    grid = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(n):
            a = grid[i][j]
            b = grid[i][(j + 1) % n]
            c = grid[i + 1][(j + 1) % n]
            d = grid[i + 1][j]
            part.face([a, b, c, d], role_of(i, j))
    if cap_start:
        part.face(list(reversed(grid[0])), cap_role)
    if cap_end:
        part.face(grid[-1], cap_role)
    return grid


def finish_part(part, name, mats, smooth_angle_deg=38.0):
    """Turn a Part into a Blender object with one material slot per role."""
    bm = part.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    for role in ROLE_ORDER:
        me.materials.append(mats[role])
    for f in bm.faces:
        f.material_index = f[part.layer]
        f.smooth = True
    bm.to_mesh(me)
    me.set_sharp_from_angle(angle=math.radians(smooth_angle_deg))
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def bake_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)


def cylinder_cutter(name, centre, radius, x0, x1, mats, segments=18):
    """Solid cylinder along X from x0 to x1, used to cut wheel openings."""
    bm = bmesh.new()
    ring0 = []
    ring1 = []
    for k in range(segments):
        a = 2 * math.pi * k / segments
        y = centre[1] + radius * math.cos(a)
        z = centre[2] + radius * math.sin(a)
        ring0.append(bm.verts.new((x0, y, z)))
        ring1.append(bm.verts.new((x1, y, z)))
    for k in range(segments):
        k2 = (k + 1) % segments
        bm.faces.new([ring0[k], ring0[k2], ring1[k2], ring1[k]])
    bm.faces.new(list(reversed(ring0)))
    bm.faces.new(ring1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    me.materials.append(mats["Trim"])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.hide_render = True
    return obj


def boolean(obj, cutter, op="DIFFERENCE"):
    mod = obj.modifiers.new("Bool_" + cutter.name, "BOOLEAN")
    mod.operation = op
    mod.object = cutter
    mod.solver = "EXACT"
    if hasattr(mod, "material_mode"):
        mod.material_mode = "TRANSFER"
    bake_modifiers(obj)
    bpy.data.objects.remove(cutter)


# ---------------------------------------------------------------------------
# Body and cabin
# ---------------------------------------------------------------------------


def body_half_section(spec, y):
    zt = smooth_interp(spec["body_top"], y)
    zb = smooth_interp(spec["body_bottom"], y)
    hw = smooth_interp(spec["body_hw"], y)
    for (axle_y, amount, half) in spec.get("fender_bumps", []):
        hw += amount * bump(y, axle_y, half)
    crown = spec.get("hood_crown", 0.08) * max(0.0, min(1.0, (zt - zb) / 1.2))
    h = max(0.05, zt - zb)
    tuck = spec.get("sill_tuck", 0.16)
    edge = spec.get("top_edge", 0.30)
    shoulder_in = spec.get("shoulder_in", 0.06)
    belly = spec.get("belly_frac", 0.42)
    return [
        (0.0, zb),
        (hw - tuck * 1.9, zb),
        (hw - tuck, zb + min(0.22, h * 0.18)),
        (hw, zb + h * belly),
        (hw - shoulder_in * 0.4, zb + h * 0.74),
        (hw - shoulder_in, zt - min(0.14, h * 0.12)),
        (hw - edge, zt),
        (hw * 0.55, zt + crown * 0.75),
        (0.0, zt + crown),
    ]


def body_role(spec, y, seg, half_len):
    """Role of a body quad from its station y and segment index."""
    # segments on the left half: 0 bottom, 1 tuck, 2 lower side, 3 upper side,
    # 4 shoulder, 5 top edge, 6/7 top surface; mirrored on the right.
    s = seg if seg < half_len else (2 * half_len - 1 - seg)
    if s == 0:
        return "Trim"
    lower_trim = spec.get("lower_trim_ends", [])
    for (y0, y1) in lower_trim:
        if y0 <= y <= y1 and s == 1:
            return "Trim"
    return "BodyPrimary"


def build_body(spec, mats):
    part = Part()
    ys = stations(spec["body_y"], spec.get("body_step", 0.42))
    rings = [full_ring(body_half_section(spec, y), y) for y in ys]
    half_len = len(body_half_section(spec, ys[0])) - 1

    def role_of(i, j):
        return body_role(spec, (ys[i] + ys[i + 1]) / 2, j, half_len)

    loft(part, rings, role_of)
    return part


def cabin_half_section(spec, y):
    zb = smooth_interp(spec["body_top"], y) - 0.04
    zr = smooth_interp(spec["roof_z"], y)
    hb = smooth_interp(spec["body_hw"], y) - spec.get("top_edge", 0.30) - spec.get("cabin_inset", 0.10)
    for (axle_y, amount, half) in spec.get("fender_bumps", []):
        hb += 0.35 * amount * bump(y, axle_y, half)
    hr = smooth_interp(spec["roof_hw"], y)
    h = max(0.02, zr - zb)
    crown = spec.get("roof_crown", 0.10) * min(1.0, h / 1.0)
    edge = min(0.22, h * 0.25)
    out = spec.get("roof_edge_out", 0.06)
    lean_mid = lerp(hb, hr + out, 0.45) + spec.get("glass_bow", 0.03)
    return [
        (0.0, zb),
        (hb, zb),
        (lean_mid, zb + h * 0.45),
        (hr + out, zr - edge),
        (hr - 0.06, zr - edge * 0.25),
        (hr * 0.5, zr + crown * 0.7),
        (0.0, zr + crown),
    ]


def build_cabin(spec, mats):
    """Greenhouse with inset, recessed glass. Returns a Part."""
    part = Part()
    ys = stations(spec["cabin_y"], spec.get("cabin_step", 0.40))
    rings = [full_ring(cabin_half_section(spec, y), y) for y in ys]
    half_len = 6
    glass_faces = []

    def in_ranges(y, ranges):
        for (y0, y1) in ranges:
            if y0 <= y <= y1:
                return True
        return False

    def role_of(i, j):
        y = (ys[i] + ys[i + 1]) / 2
        s = j if j < half_len else (2 * half_len - 1 - j)
        if s == 0:
            return "Hidden"  # base strip, buried in the body
        if s in (1, 2):
            return "Glass" if in_ranges(y, spec["side_glass"]) else "BodyPrimary"
        if s == 3:
            return "BodyPrimary"  # pillar / roof rail strip
        if in_ranges(y, spec["top_glass"]):
            return "Glass"
        return spec.get("roof_role", "BodyPrimary")

    loft(part, rings, role_of, cap_role="BodyPrimary")
    # Recess every glass region: inset a frame and push the glass in.
    for f in part.bm.faces:
        if f[part.layer] == ROLE_ORDER.index("Glass"):
            glass_faces.append(f)
    if glass_faces:
        res = bmesh.ops.inset_region(part.bm, faces=glass_faces, thickness=spec.get("glass_frame", 0.07),
                                     depth=-spec.get("glass_recess", 0.035), use_even_offset=True)
        for f in res["faces"]:
            f[part.layer] = ROLE_ORDER.index(spec.get("frame_role", "BodyPrimary"))
    return part


def stations(keys, step):
    """Station list covering keys, with roughly `step` spacing, keys included."""
    out = []
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        n = max(1, int(math.ceil((b - a) / step)))
        for k in range(n):
            out.append(a + (b - a) * k / n)
    out.append(keys[-1])
    return out


# ---------------------------------------------------------------------------
# Wheels
# ---------------------------------------------------------------------------


def build_wheel(spec, mats):
    """Tyre (with dark barrel) and rim, built at the origin, outer face +X.
    Returns (tyre Part, rim Part)."""
    R = spec["tire_r"]
    w = spec["tire_w"]
    seg = spec.get("tire_segments", 20)
    tyre = Part()
    rim = Part()
    hw = w / 2
    # Tyre cross-section (radius, x) from the inner bead around to the outer bead.
    prof = [
        (R * 0.70, -hw + 0.02),
        (R * 0.90, -hw),
        (R * 0.985, -hw + 0.10),
        (R, -hw * 0.35),
        (R, hw * 0.35),
        (R * 0.985, hw - 0.10),
        (R * 0.90, hw),
        (R * 0.74, hw - 0.02),
    ]
    rings = []
    for k in range(seg):
        a = 2 * math.pi * k / seg - math.pi / 2  # a vertex sits on the ground contact point
        rings.append([tyre.bm.verts.new((x, r * math.cos(a), r * math.sin(a))) for (r, x) in prof])
    for k in range(seg):
        k2 = (k + 1) % seg
        for p in range(len(prof) - 1):
            tyre.face([rings[k][p], rings[k][p + 1], rings[k2][p + 1], rings[k2][p]], "Tire")
    # Dark barrel back disc, visible through the spoke openings.
    xb = hw - 0.30
    back = [tyre.bm.verts.new((xb, R * 0.74 * math.cos(2 * math.pi * k / seg), R * 0.74 * math.sin(2 * math.pi * k / seg))) for k in range(seg)]
    tyre.face(back, "Tire")
    # Barrel wall joining the outer bead to the back disc (inside of the rim).
    for k in range(seg):
        k2 = (k + 1) % seg
        tyre.face([rings[k][-1], back[k], back[k2], rings[k2][-1]], "Tire")

    # Rim: lip ring flush with the tyre, recessed spoke face, hub.
    lip_out, lip_in = R * 0.76, R * 0.68
    x_lip = hw - 0.015
    x_face = hw - 0.13
    rs = seg
    lo = [rim.bm.verts.new((x_lip, lip_out * math.cos(2 * math.pi * k / rs), lip_out * math.sin(2 * math.pi * k / rs))) for k in range(rs)]
    li = [rim.bm.verts.new((x_lip, lip_in * math.cos(2 * math.pi * k / rs), lip_in * math.sin(2 * math.pi * k / rs))) for k in range(rs)]
    lw = [rim.bm.verts.new((x_face - 0.04, lip_in * math.cos(2 * math.pi * k / rs), lip_in * math.sin(2 * math.pi * k / rs))) for k in range(rs)]
    for k in range(rs):
        k2 = (k + 1) % rs
        rim.face([lo[k], lo[k2], li[k2], li[k]], "WheelMetal")
        rim.face([li[k], li[k2], lw[k2], lw[k]], "WheelMetal")
    # Spokes: tapered blades from hub to lip, slightly proud, with side walls.
    n_spokes = spec.get("spokes", 5)
    hub_r = R * 0.20
    for s in range(n_spokes):
        a0 = 2 * math.pi * s / n_spokes + math.pi / 2
        # Spoke widths are absolute (studs), so spokes stay solid at the hub.
        w_hub = spec.get("spoke_hub_width", R * 0.17)
        w_lip = spec.get("spoke_lip_width", R * 0.12)
        r0 = hub_r * 0.8
        pts = [
            (r0, a0 - w_hub / 2 / r0),
            (lip_in, a0 - w_lip / 2 / lip_in),
            (lip_in, a0 + w_lip / 2 / lip_in),
            (r0, a0 + w_hub / 2 / r0),
        ]
        front = [rim.bm.verts.new((x_face, r * math.cos(a), r * math.sin(a))) for (r, a) in pts]
        backv = [rim.bm.verts.new((x_face - 0.10, r * math.cos(a), r * math.sin(a))) for (r, a) in pts]
        rim.face(front, "WheelMetal")
        for k in range(4):
            k2 = (k + 1) % 4
            rim.face([front[k2], front[k], backv[k], backv[k2]], "WheelMetal")
    # Hub disc and centre cap.
    hs = 12
    hub = [rim.bm.verts.new((x_face + 0.01, hub_r * math.cos(2 * math.pi * k / hs), hub_r * math.sin(2 * math.pi * k / hs))) for k in range(hs)]
    hubb = [rim.bm.verts.new((x_face - 0.10, hub_r * math.cos(2 * math.pi * k / hs), hub_r * math.sin(2 * math.pi * k / hs))) for k in range(hs)]
    rim.face(hub, "WheelMetal")
    for k in range(hs):
        k2 = (k + 1) % hs
        rim.face([hub[k2], hub[k], hubb[k], hubb[k2]], "WheelMetal")
    cap_r = R * 0.08
    cap = [rim.bm.verts.new((x_face + 0.05, cap_r * math.cos(2 * math.pi * k / 8), cap_r * math.sin(2 * math.pi * k / 8))) for k in range(8)]
    capb = [rim.bm.verts.new((x_face + 0.01, cap_r * 1.15 * math.cos(2 * math.pi * k / 8), cap_r * 1.15 * math.sin(2 * math.pi * k / 8))) for k in range(8)]
    rim.face(cap, "WheelMetal")
    for k in range(8):
        k2 = (k + 1) % 8
        rim.face([cap[k2], cap[k], capb[k], capb[k2]], "WheelMetal")
    return tyre, rim


# ---------------------------------------------------------------------------
# Projected details: lamps, plates, intakes, seams
# ---------------------------------------------------------------------------


def superellipse_patch(cx, cz, a, b, n=3.0, rings=4, segs=24, skew=0.0, taper=0.0):
    """Flat patch (x, z) shaped like a rounded rectangle; returns verts, faces.
    skew shifts the top edge sideways, taper narrows the top."""
    verts = [(cx, cz)]
    faces = []
    for r in range(1, rings + 1):
        s = r / rings
        for k in range(segs):
            t = 2 * math.pi * k / segs
            c, sn = math.cos(t), math.sin(t)
            x = a * s * math.copysign(abs(c) ** (2 / n), c)
            z = b * s * math.copysign(abs(sn) ** (2 / n), sn)
            up = (z / b + 1) / 2 if b else 0.5
            x = x * (1 - taper * up) + skew * (z / b if b else 0)
            verts.append((cx + x, cz + z))
    for k in range(segs):
        k2 = (k + 1) % segs
        faces.append([0, 1 + k, 1 + k2])
    for r in range(1, rings):
        o0 = 1 + (r - 1) * segs
        o1 = 1 + r * segs
        for k in range(segs):
            k2 = (k + 1) % segs
            faces.append([o0 + k, o1 + k, o1 + k2, o0 + k2])
    return verts, faces


def projected_decal(name, shape, plane, target, offset, role, mats):
    """Project a flat patch onto `target` along an axis.

    shape: (verts2d, faces). plane: ("front"|"rear"|"left"|"right", position)."""
    verts2d, faces = shape
    side, pos = plane
    bm = bmesh.new()
    vs = []
    for (u, v) in verts2d:
        if side in ("front", "rear"):
            vs.append(bm.verts.new((u, pos, v)))
        else:
            vs.append(bm.verts.new((pos, u, v)))
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    me = bpy.data.meshes.new(name)
    me.materials.append(mats[role])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("Wrap", "SHRINKWRAP")
    mod.target = target
    mod.wrap_method = "PROJECT"
    mod.offset = offset
    if side in ("front", "rear"):
        mod.use_project_y = True
    else:
        mod.use_project_x = True
    mod.use_negative_direction = side in ("rear", "left")
    mod.use_positive_direction = side in ("front", "right")
    bake_modifiers(obj)
    # Faces must point away from the body.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    want = {"front": Vector((0, -1, 0)), "rear": Vector((0, 1, 0)), "left": Vector((1, 0, 0)), "right": Vector((-1, 0, 0))}[side]
    for f in bm.faces:
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
        f.smooth = True
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def decal_to_part(obj, part, role):
    """Copy a baked decal object into a Part with the given role, then delete it."""
    mapping = {}
    me = obj.data
    for v in me.vertices:
        mapping[v.index] = part.bm.verts.new(obj.matrix_world @ v.co)
    for p in me.polygons:
        f = part.face([mapping[i] for i in p.vertices], role)
        f.smooth = True
    bpy.data.objects.remove(obj)


def mirror_x(verts2d):
    return [(-u, v) for (u, v) in verts2d]


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


def split_roles(part, prefix, mats, smooth_angle_deg=38.0):
    """Make one object per role present in the Part. Returns {role: object}."""
    out = {}
    for ri, role in enumerate(ROLE_ORDER):
        if role == "Hidden":
            continue
        bm = part.bm.copy()
        layer = bm.faces.layers.int.get("role")
        dead = [f for f in bm.faces if f[layer] != ri]
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        if len(bm.faces) == 0:
            bm.free()
            continue
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        me = bpy.data.meshes.new(prefix + role)
        me.materials.append(mats[role])
        for f in bm.faces:
            f.material_index = 0
            f.smooth = True
        bm.to_mesh(me)
        bm.free()
        me.set_sharp_from_angle(angle=math.radians(smooth_angle_deg))
        obj = bpy.data.objects.new(prefix + role, me)
        bpy.context.scene.collection.objects.link(obj)
        out[role] = obj
    return out


def part_to_object(part, name, mats, smooth_angle_deg=38.0):
    """Single object keeping per-face role materials (used before booleans)."""
    return finish_part(part, name, mats, smooth_angle_deg)


def object_to_part(obj):
    """Read an object (materials named Role_*) back into a Part."""
    part = Part()
    me = obj.data
    mapping = {}
    for v in me.vertices:
        mapping[v.index] = part.bm.verts.new(obj.matrix_world @ v.co)
    for p in me.polygons:
        mat = me.materials[p.material_index] if me.materials else None
        role = mat.name[5:].split(".")[0] if mat is not None and mat.name.startswith("Role_") else "BodyPrimary"
        if role not in ROLE_ORDER:
            role = "Trim"
        try:
            part.face([mapping[i] for i in p.vertices], role)
        except ValueError:
            pass
    return part


def tri_count(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = obj.evaluated_get(dg).to_mesh()
    n = sum(len(p.vertices) - 2 for p in me.polygons)
    obj.evaluated_get(dg).to_mesh_clear()
    return n


def box_part(part, centre, size, role, bevel=0.0):
    bm = bmesh.new()
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(centre)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5)
    mapping = {}
    for v in bm.verts:
        mapping[v] = part.bm.verts.new(v.co)
    for f in bm.faces:
        nf = part.face([mapping[v] for v in f.verts], role)
        nf.smooth = True
    bm.free()


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def export_fbx(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        # Raw Blender units: Studio's importer reads them as studs (Scale Unit
        # "Studs"). apply_unit_scale=True gave every object a 100x transform.
        apply_unit_scale=False,
        apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="OFF",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
    )


def apply_rotation_z(obj, angle):
    obj.rotation_euler = (0, 0, angle)
    obj.data.transform(Matrix.Rotation(angle, 4, "Z"))
    obj.rotation_euler = (0, 0, 0)


# ---------------------------------------------------------------------------
# Whole car
# ---------------------------------------------------------------------------

WHEEL_NAMES = {(-1, 1): "FL", (-1, -1): "FR", (1, 1): "RL", (1, -1): "RR"}


def build_car(spec, mats, prefix=""):
    """Build a complete car from a spec. Returns a dict:
    {"parts": {role: obj}, "wheels": {"FL": (tyre_obj, rim_obj), ...}, "stats": {...}}"""
    L = spec["length"]
    body = build_body(spec, mats)
    body_obj = finish_part(body, prefix + "BodyShell", mats)

    # Wheel openings: one cutter per wheel, only as deep as the wheel well.
    R = spec["tire_r"]
    for axle_y in spec["axles"]:
        for s in (1, -1):
            x_in = s * (spec["track_x"] - spec["tire_w"] / 2 - spec.get("well_depth", 0.30))
            x_out = s * (spec["track_x"] + 2.0)
            cutter = cylinder_cutter("Arch", (0, axle_y, spec.get("arch_z", R + 0.05)), spec.get("arch_r", R + 0.17),
                                     min(x_in, x_out), max(x_in, x_out), mats)
            boolean(body_obj, cutter)

    for extra in spec.get("cut_boxes", []):
        # (centre, size): e.g. a pickup bed
        bm = bmesh.new()
        res = bmesh.ops.create_cube(bm, size=1.0)
        for v in res["verts"]:
            v.co = Vector((v.co.x * extra[1][0], v.co.y * extra[1][1], v.co.z * extra[1][2])) + Vector(extra[0])
        me = bpy.data.meshes.new("Cut")
        me.materials.append(mats["Trim"])
        bm.to_mesh(me)
        bm.free()
        cut = bpy.data.objects.new("Cut", me)
        bpy.context.scene.collection.objects.link(cut)
        boolean(body_obj, cut)

    if spec.get("bevel_width", 0) > 0:
        # Soft chamfer on sharp edges only (arch lips, end caps), one segment.
        bev = body_obj.modifiers.new("Bevel", "BEVEL")
        bev.width = spec["bevel_width"]
        bev.segments = 1
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(spec.get("bevel_angle", 55.0))
        bake_modifiers(body_obj)

    final = object_to_part(body_obj)
    if spec.get("cabin_y"):
        final.add_part(build_cabin(spec, mats))

    # Projected details (lamps, grilles, plates, seams).
    half_w = spec["width"] / 2 + 1.0
    plane_pos = {"front": -L / 2 - 1.0, "rear": L / 2 + 1.0, "left": half_w, "right": -half_w}
    for d in spec.get("decals", []):
        sides = [d["side"]]
        if d["side"] == "sides":
            sides = ["left", "right"]
        for side in sides:
            centres = [d["at"][0]]
            if d.get("mirror") and side in ("front", "rear"):
                centres.append(-d["at"][0])
            for cx in centres:
                skew = d.get("skew", 0.0) * (1 if cx >= 0 else -1)
                shape = superellipse_patch(cx, d["at"][1], d["size"][0], d["size"][1], d.get("n", 3.0),
                                           d.get("rings", 1), d.get("segs", 14), skew, d.get("taper", 0.0))
                obj = projected_decal("Decal", shape, (side, plane_pos[side]), body_obj, d.get("offset", 0.02),
                                      d["role"], mats)
                decal_to_part(obj, final, d["role"])

    for m in spec.get("boxes", []):
        # (centre, size, role, bevel, mirror_x)
        box_part(final, m[0], m[1], m[2], m[3])
        if m[4]:
            box_part(final, (-m[0][0], m[0][1], m[0][2]), m[1], m[2], m[3])

    bpy.data.objects.remove(body_obj)
    parts = split_roles(final, prefix, mats, spec.get("smooth_angle", 38.0))
    final.bm.free()

    # Wheels: one shared tyre mesh and rim mesh, four objects, origin on the axle.
    tyre, rim = build_wheel(spec, mats)
    tyre_obj = finish_part(tyre, prefix + "TyreMesh", mats, 50.0)
    rim_obj = finish_part(rim, prefix + "RimMesh", mats, 30.0)
    for src, role in ((tyre_obj, "Tire"), (rim_obj, "WheelMetal")):
        src.data.materials.clear()
        src.data.materials.append(mats[role])
        for p in src.data.polygons:
            p.material_index = 0
    wheels = {}
    for i, axle_y in enumerate(spec["axles"]):
        for s in (1, -1):
            key = WHEEL_NAMES[(-1 if i == 0 else 1, s)]
            objs = []
            for src, kind in ((tyre_obj, "Tire"), (rim_obj, "WheelMetal")):
                o = bpy.data.objects.new(prefix + "Wheel_" + key + "_" + kind, src.data)
                bpy.context.scene.collection.objects.link(o)
                o.location = (s * spec["track_x"], axle_y, R)
                if s < 0:
                    o.rotation_euler = (0, 0, math.pi)
                objs.append(o)
            wheels[key] = tuple(objs)
    bpy.data.objects.remove(tyre_obj)
    bpy.data.objects.remove(rim_obj)

    stats = {"triangles": 0, "unique_triangles": 0, "objects": 0}
    seen = set()
    for o in list(parts.values()) + [w for pair in wheels.values() for w in pair]:
        t = tri_count(o)
        stats["triangles"] += t
        stats["objects"] += 1
        if o.data.name not in seen:
            seen.add(o.data.name)
            stats["unique_triangles"] += t
    return {"parts": parts, "wheels": wheels, "stats": stats}


# ---------------------------------------------------------------------------
# Review renders (Workbench: neutral, fast, no baked lighting)
# ---------------------------------------------------------------------------


def setup_render(res_x, res_y, grey=False, background="#E9EDF1"):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_WORKBENCH" if "BLENDER_WORKBENCH" in engines else engines[0]
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "SINGLE" if grey else "MATERIAL"
    shading.single_color = (0.62, 0.64, 0.67)
    shading.show_shadows = True
    shading.shadow_intensity = 0.35
    shading.show_cavity = False
    shading.show_specular_highlight = True
    shading.show_object_outline = False
    shading.background_type = "VIEWPORT"
    shading.background_color = hex_rgba(background)[:3]
    # Final Workbench renders take the background from the World colour.
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = hex_rgba(background)[:3]
    scene.display.render_aa = "16"
    scene.view_settings.view_transform = "Standard"


def camera(name, location, target, ortho_scale=None, lens=50.0):
    cam_data = bpy.data.cameras.get(name) or bpy.data.cameras.new(name)
    if ortho_scale:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho_scale
    else:
        cam_data.type = "PERSP"
        cam_data.lens = lens
    cam_data.clip_end = 500
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, cam_data)
        bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    direction = Vector(target) - Vector(location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = obj
    return obj


def ground_plane(size=200.0, colour="#CDD3DA"):
    me = bpy.data.meshes.get("Ground") or bpy.data.meshes.new("Ground")
    bm = bmesh.new()
    s = size / 2
    vs = [bm.verts.new(p) for p in ((-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0))]
    bm.faces.new(vs)
    bm.to_mesh(me)
    bm.free()
    mat = role_material("Ground", colour)
    me.materials.clear()
    me.materials.append(mat)
    obj = bpy.data.objects.get("Ground") or bpy.data.objects.new("Ground", me)
    if obj.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(obj)
    return obj


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
