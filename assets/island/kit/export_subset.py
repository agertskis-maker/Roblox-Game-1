# Island kit (Lane 3): writes an OBJ holding only the named meshes, for re-uploading changed or
# new meshes through the 3D Importer without duplicating unchanged ones. Run after build_kit.py:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup \
#       <kit dir>\kit.blend --python assets/island/kit/export_subset.py -- --out <file.obj> Name1 Name2 ...
# Same OBJ settings as build_kit.py (1 unit = 1 stud, -Z forward, Y up, one group per mesh).

import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    out = argv[argv.index("--out") + 1]
    names = [a for i, a in enumerate(argv) if a != "--out" and (i == 0 or argv[i - 1] != "--out")]
    missing = [n for n in names if n not in bpy.data.objects]
    if missing:
        raise SystemExit("not in the kit: " + ", ".join(missing))
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.name in names)
    bpy.ops.wm.obj_export(
        filepath=out,
        export_selected_objects=True,
        forward_axis="NEGATIVE_Z",
        up_axis="Y",
        export_materials=False,
        export_uv=True,
        export_normals=True,
        export_triangulated_mesh=True,
    )
    with open(out) as fh:
        lines = fh.read().split("\n")
    with open(out, "w") as fh:
        fh.write("\n".join(line + "\ng " + line[2:] if line.startswith("o ") else line for line in lines))
    print("wrote", len(names), "meshes to", out)


main()
