"""
build_breakables.py — Blender (3.6 / 4.x) script for Kung Fu Chop! breakable meshes.

Builds clean low-poly versions of the breakable objects, pre-fractures each one into chunky
segments, gives every face stud-scaled UVs (1 Blender unit = 1 Roblox stud = 1 stud tile)
with the square-stud texture, and exports one FBX per object ready for Roblox's 3D Importer.

Run from a terminal:
    blender --background --python blender/build_breakables.py
or open it in Blender's Scripting tab and press Run Script.

Then in Roblox Studio (see docs/BLENDER_PIPELINE.md):
    3D Importer → blender/export/IronAnvil.fbx → Scale Unit: Stud → Import
    rename the imported Model to "IronAnvil" and move it into ServerStorage/BreakableModels
The server swaps the voxel segments for your mesh pieces (palette + studs applied), and each
piece shatters on its own when the object breaks.
"""

import math
import os
import random

import bpy  # noqa: I001 — must be imported before bmesh/mathutils when run as the `bpy` module
import bmesh
from mathutils import Matrix, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
EXPORT_DIR = os.path.join(HERE, "export")
STUD_TEXTURE = os.path.join(ROOT, "assets", "textures", "stud_tile.png")

# id: (builder, size (x, y_up, z), cuts per axis (x, y, z), colour)
# Blender is Z-up; sizes below are given Roblox-style (Y up) and converted.
OBJECTS = {
    "WoodenBoard": ("box", (7, 0.8, 3), (4, 1, 2), (0.84, 0.6, 0.36)),
    "BrickStack": ("bricks", (5, 3.6, 2.4), (2, 3, 1), (0.77, 0.28, 0.22)),
    "IronAnvil": ("anvil", (6.4, 4.2, 3.2), (3, 2, 2), (0.35, 0.36, 0.41)),
    "StonePillar": ("pillar", (4, 7, 4), (2, 4, 2), (0.67, 0.65, 0.59)),
    "SteelBeam": ("ibeam", (11, 3, 2.4), (5, 1, 1), (0.43, 0.47, 0.53)),
    "DiamondBlock": ("box", (4.5, 4.5, 4.5), (2, 2, 2), (0.47, 0.9, 1.0)),
    "ServerRack": ("box", (4, 7.2, 3), (2, 4, 1), (0.16, 0.17, 0.22)),
    "NeonCrystal": ("crystal", (5, 9, 5), (2, 4, 2), (1.0, 0.24, 0.78)),
    "MechCore": ("sphere", (7, 7, 7), (2, 3, 2), (0.27, 0.3, 0.35)),
    "Meteorite": ("rock", (7, 7, 7), (3, 3, 3), (0.24, 0.2, 0.2)),
    "Moon": ("sphere", (9, 9, 9), (3, 3, 3), (0.78, 0.78, 0.77)),
    "Planet": ("planet", (16, 8, 16), (3, 3, 3), (0.24, 0.51, 1.0)),
}


# ------------------------------------------------------------------------------------------
# Base shapes (bmesh, Z-up, centred on the origin)
# ------------------------------------------------------------------------------------------


def add_box(bm, sx, sy, sz, offset=(0, 0, 0)):
    result = bmesh.ops.create_cube(bm, size=1.0)
    for v in result["verts"]:
        v.co = Vector((v.co.x * sx + offset[0], v.co.y * sy + offset[1], v.co.z * sz + offset[2]))


def shape_box(bm, x, y, z):
    add_box(bm, x, y, z)


def shape_bricks(bm, x, y, z):
    rows = 3
    h = z / rows
    for r in range(rows):
        shift = 0.25 * x / 2 if r % 2 else 0
        add_box(bm, x * 0.98, y * 0.98, h * 0.94, (shift * 0.2, 0, -z / 2 + h * (r + 0.5)))


def shape_anvil(bm, x, y, z):
    add_box(bm, x * 0.75, y * 0.9, z * 0.2, (0, 0, -z * 0.4))  # foot
    add_box(bm, x * 0.38, y * 0.55, z * 0.4, (0, 0, -z * 0.1))  # waist
    add_box(bm, x * 0.72, y, z * 0.32, (-x * 0.1, 0, z * 0.34))  # face
    horn = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=z * 0.16, radius2=0.05, depth=x * 0.3)
    for v in horn["verts"]:
        v.co = Vector((v.co.z + x * 0.38, v.co.y, v.co.x + z * 0.38))


def shape_pillar(bm, x, y, z):
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=x * 0.42, radius2=x * 0.42, depth=z * 0.72)
    add_box(bm, x, y, z * 0.14, (0, 0, -z * 0.43))
    add_box(bm, x, y, z * 0.14, (0, 0, z * 0.43))


def shape_ibeam(bm, x, y, z):
    add_box(bm, x, y, z * 0.2, (0, 0, z * 0.4))
    add_box(bm, x, y, z * 0.2, (0, 0, -z * 0.4))
    add_box(bm, x, y * 0.3, z * 0.62)


def shape_crystal(bm, x, y, z):
    """Hexagonal bipyramid with a short prism band in the middle."""
    ring_lo, ring_hi = [], []
    for i in range(6):
        a = math.tau * i / 6
        ring_lo.append(bm.verts.new((math.cos(a) * x / 2, math.sin(a) * y / 2, -z * 0.15)))
        ring_hi.append(bm.verts.new((math.cos(a) * x / 2, math.sin(a) * y / 2, z * 0.15)))
    tip_top, tip_bottom = bm.verts.new((0, 0, z / 2)), bm.verts.new((0, 0, -z / 2))
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
        bm.faces.new((ring_hi[i], ring_hi[j], tip_top))
        bm.faces.new((ring_lo[j], ring_lo[i], tip_bottom))


def shape_sphere(bm, x, y, z):
    result = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    for v in result["verts"]:
        v.co = Vector((v.co.x * x, v.co.y * y, v.co.z * z))


def shape_rock(bm, x, y, z):
    result = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.5)
    for v in result["verts"]:
        bump = 1 + 0.25 * noise.noise(v.co * 3.1)
        v.co = Vector((v.co.x * x * bump, v.co.y * y * bump, v.co.z * z * bump))


def shape_planet(bm, x, y, z):
    """Globe (radius = half height) plus a flat ring reaching the full width."""
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=z / 2)
    segments, inner, outer, half = 24, x * 0.31, x / 2, z * 0.06
    rings = {key: [] for key in ("it", "ot", "ib", "ob")}
    for i in range(segments):
        a = math.tau * i / segments
        c, s_ = math.cos(a), math.sin(a)
        rings["it"].append(bm.verts.new((c * inner, s_ * inner * y / x, half)))
        rings["ot"].append(bm.verts.new((c * outer, s_ * outer * y / x, half)))
        rings["ib"].append(bm.verts.new((c * inner, s_ * inner * y / x, -half)))
        rings["ob"].append(bm.verts.new((c * outer, s_ * outer * y / x, -half)))
    for i in range(segments):
        j = (i + 1) % segments
        it, ot, ib, ob = rings["it"], rings["ot"], rings["ib"], rings["ob"]
        bm.faces.new((it[i], ot[i], ot[j], it[j]))  # top
        bm.faces.new((ib[j], ob[j], ob[i], ib[i]))  # bottom
        bm.faces.new((ot[i], ob[i], ob[j], ot[j]))  # outer wall
        bm.faces.new((it[j], ib[j], ib[i], it[i]))  # inner wall


SHAPES = {
    "box": shape_box,
    "bricks": shape_bricks,
    "anvil": shape_anvil,
    "pillar": shape_pillar,
    "ibeam": shape_ibeam,
    "crystal": shape_crystal,
    "sphere": shape_sphere,
    "rock": shape_rock,
    "planet": shape_planet,
}

# ------------------------------------------------------------------------------------------
# Fracture: slice the base mesh with jittered (slightly tilted) planes into closed chunks
# ------------------------------------------------------------------------------------------


def cut_positions(extent, cuts, rng):
    if cuts <= 1:
        return []
    step = extent / cuts
    return [-extent / 2 + step * i + rng.uniform(-0.18, 0.18) * step for i in range(1, cuts)]


def slice_cell(source_bm, bounds, tilt):
    bm = source_bm.copy()
    for axis, (lo, hi) in enumerate(bounds):
        for value, keep_below in ((hi, True), (lo, False)):
            if value is None:
                continue
            normal = Vector((0, 0, 0))
            normal[axis] = 1
            normal[(axis + 1) % 3] = tilt[axis]
            normal.normalize()
            co = Vector((0, 0, 0))
            co[axis] = value
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            result = bmesh.ops.bisect_plane(
                bm, geom=geom, dist=1e-5, plane_co=co, plane_no=normal, clear_outer=keep_below, clear_inner=not keep_below
            )
            cut_edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
            if cut_edges:
                bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    return bm


def stud_uvs(bm):
    """Box-project UVs in stud units so the stud texture tiles once per stud."""
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        u_axis, v_axis = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in face.loops:
            loop[uv_layer].uv = (loop.vert.co[u_axis], loop.vert.co[v_axis])


# ------------------------------------------------------------------------------------------
# Scene helpers
# ------------------------------------------------------------------------------------------


def stud_material(name, color):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*color, 1)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.45
    if os.path.exists(STUD_TEXTURE):
        image = nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(STUD_TEXTURE, check_existing=True)
        try:  # tint the grey studs with the object colour
            mix = nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs["Fac"].default_value = 1.0
            mix.inputs["Color1"].default_value = (*color, 1)
            links.new(image.outputs["Color"], mix.inputs["Color2"])
            links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
        except RuntimeError:
            links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def build(object_id, spec, seed):
    shape, (sx, sy_up, sz), (cx, cy_up, cz), color = spec
    rng = random.Random(seed)
    # Roblox (x, y_up, z) → Blender (x, -z, y_up)
    bx, by, bz = sx, sz, sy_up
    cuts = (cx, cz, cy_up)

    base = bmesh.new()
    SHAPES[shape](base, bx, by, bz)
    bmesh.ops.remove_doubles(base, verts=base.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(base, faces=base.faces)

    collection = bpy.data.collections.new(object_id)
    bpy.context.scene.collection.children.link(collection)
    material = stud_material(f"{object_id}_Studs", color)

    positions = [cut_positions(extent, n, rng) for extent, n in zip((bx, by, bz), cuts)]
    tilt = [rng.uniform(-0.12, 0.12) for _ in range(3)]
    index = 0
    for i in range(len(positions[0]) + 1):
        for j in range(len(positions[1]) + 1):
            for k in range(len(positions[2]) + 1):
                bounds = []
                for axis, idx in enumerate((i, j, k)):
                    cuts_axis = positions[axis]
                    lo = cuts_axis[idx - 1] if idx > 0 else None
                    hi = cuts_axis[idx] if idx < len(cuts_axis) else None
                    bounds.append((lo, hi))
                chunk = slice_cell(base, bounds, tilt)
                if len(chunk.faces) < 4:
                    chunk.free()
                    continue
                index += 1
                stud_uvs(chunk)
                mesh = bpy.data.meshes.new(f"Segment_{index}")
                chunk.to_mesh(mesh)
                chunk.free()
                mesh.materials.append(material)
                obj = bpy.data.objects.new(f"Segment_{index}", mesh)
                collection.objects.link(obj)
                # Origin at the chunk's centre so it spins nicely as debris.
                centre = sum((v.co for v in mesh.vertices), Vector()) / max(1, len(mesh.vertices))
                mesh.transform(Matrix.Translation(-centre))
                obj.location = centre
    base.free()
    return collection, index


def export(collection, object_id):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(EXPORT_DIR, f"{object_id}.fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        path_mode="COPY",
        embed_textures=True,
    )


def main():
    clear_scene()
    for seed, (object_id, spec) in enumerate(OBJECTS.items()):
        collection, segments = build(object_id, spec, seed + 1)
        export(collection, object_id)
        print(f"[Kung Fu Chop!] {object_id}: {segments} segments -> export/{object_id}.fbx")
        # Leave the last build in the scene; hide the others for a tidy file.
        collection.hide_viewport = True
    print("Done. Import the FBX files with Roblox Studio's 3D Importer (Scale Unit: Stud).")


if __name__ == "__main__":
    main()
