import bpy
import math
import os
from mathutils import Vector

# LIBREVILLE STORIES — props tropicaux légers pour la Baie des Rois
# Blender 5.x / export GLB compatible Godot 4.3.
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "baie_des_rois")
os.makedirs(OUT, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name, color, roughness=0.82, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True

    # Blender 5.x peut créer un node tree sans nœud Principled préexistant
    # dans certains contextes background. On reconstruit explicitement le shader.
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        nodes.clear()
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.location = (0, 0)
    output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
    if output is None:
        output = nodes.new("ShaderNodeOutputMaterial")
        output.location = (320, 0)
    if not output.inputs["Surface"].is_linked:
        mat.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def set_material_input(mat, socket_name, value):
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        raise RuntimeError("Shader Principled introuvable dans le matériau " + mat.name)
    socket = bsdf.inputs.get(socket_name)
    if socket is None:
        raise RuntimeError("Entrée shader absente : " + socket_name)
    socket.default_value = value


def assign(obj, mat):
    obj.data.materials.append(mat)
    return obj


def join_named_meshes(prefix, final_name):
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(prefix)]
    if len(objects) < 2:
        if objects:
            objects[0].name = final_name
        return
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = final_name


def export_selected(filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    bpy.context.view_layer.objects.active = next(
        (o for o in bpy.context.scene.objects if o.type == "MESH"), None
    )
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, filename),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def make_palm():
    clear_scene()
    bark = material("Palm_Bark_Warm", (0.30, 0.19, 0.105))
    ring_mat = material("Palm_Trunk_Rings", (0.48, 0.32, 0.18))
    leaf_dark = material("Palm_Leaf_Dark", (0.055, 0.22, 0.095))
    leaf_light = material("Palm_Leaf_Light", (0.13, 0.34, 0.13))

    # Tronc légèrement fuselé et incliné, avec une vraie silhouette cylindrique.
    rings = 18
    sides = 10
    verts, faces = [], []
    for j in range(rings + 1):
        t = j / rings
        z = t * 6.4
        cx = 0.10 * math.sin(t * 1.8)
        radius = 0.28 * (1.0 - 0.34 * t)
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            verts.append((cx + math.cos(a) * radius, math.sin(a) * radius, z))
    for j in range(rings):
        for i in range(sides):
            a = j * sides + i
            b = j * sides + (i + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(range(sides - 1, -1, -1)),
                  tuple(rings * sides + i for i in range(sides))])
    mesh = bpy.data.meshes.new("PalmTrunkMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(bark)
    mesh.materials.append(ring_mat)
    trunk = bpy.data.objects.new("Palm_Trunk", mesh)
    bpy.context.collection.objects.link(trunk)
    for poly in mesh.polygons:
        poly.use_smooth = True

    # Anneaux de croissance discrets, intégrés au tronc.
    for k in range(1, 25):
        z = k * 0.25
        t = z / 6.4
        cx = 0.10 * math.sin(t * 1.8)
        radius = 0.282 * (1.0 - 0.34 * t)
        bpy.ops.mesh.primitive_torus_add(
            major_radius=radius, minor_radius=0.018,
            major_segments=12, minor_segments=4,
            location=(cx, 0, z)
        )
        ring = bpy.context.object
        ring.name = "Trunk_Growth_Ring"
        assign(ring, ring_mat)

    # Couronne : 9 palmes arquées, rachis + folioles effilées.
    for frond in range(9):
        angle = 2.0 * math.pi * frond / 9.0 + 0.18
        radial = Vector((math.cos(angle), math.sin(angle), 0))
        lateral = Vector((-math.sin(angle), math.cos(angle), 0))
        base = Vector((0.10 * math.sin(1.8), 0, 6.25))
        tip = base + radial * (2.9 + (frond % 3) * 0.18) + Vector((0, 0, -1.05))
        # Rachis segmenté.
        curve = bpy.data.curves.new("Palm_Rachis", "CURVE")
        curve.dimensions = "3D"
        curve.resolution_u = 2
        curve.bevel_depth = 0.035
        curve.bevel_resolution = 2
        spline = curve.splines.new("POLY")
        spline.points.add(7)
        for j, point in enumerate(spline.points):
            t = j / 7.0
            p = base.lerp(tip, t) + Vector((0, 0, -0.45 * math.sin(t * math.pi)))
            point.co = (*p, 1)
        rachis = bpy.data.objects.new("Palm_Rachis", curve)
        bpy.context.collection.objects.link(rachis)
        assign(rachis, leaf_light)
        bpy.ops.object.select_all(action="DESELECT")
        rachis.select_set(True)
        bpy.context.view_layer.objects.active = rachis
        bpy.ops.object.convert(target="MESH")

        for side_sign in (-1, 1):
            for j in range(2, 19):
                t = j / 20.0
                origin = base.lerp(tip, t) + Vector((0, 0, -0.45 * math.sin(t * math.pi)))
                length = (0.55 + 0.72 * math.sin(t * math.pi)) * (1.0 - 0.24 * t)
                direction = (lateral * side_sign * 0.88 + radial * 0.34).normalized()
                end = origin + direction * length + radial * 0.20
                mid = origin.lerp(end, 0.52) + Vector((0, 0, -0.10))
                width = 0.075 * math.sin(t * math.pi) + 0.025
                leaf_verts = [
                    tuple(origin),
                    tuple(mid + lateral * side_sign * width),
                    tuple(end),
                    tuple(mid - lateral * side_sign * width),
                ]
                leaf_mesh = bpy.data.meshes.new("Palm_LeafletMesh")
                leaf_mesh.from_pydata(leaf_verts, [], [(0, 1, 2), (0, 2, 3)])
                leaf_mesh.materials.append(leaf_dark if (j + frond) % 3 else leaf_light)
                leaf_obj = bpy.data.objects.new("Palm_Leaflet", leaf_mesh)
                bpy.context.collection.objects.link(leaf_obj)

    # Fusionner les centaines de folioles en un seul mesh pour limiter les draw calls.
    join_named_meshes("Palm_Leaflet", "Palm_Leaves_Merged")
    join_named_meshes("Trunk_Growth_Ring", "Palm_Rings_Merged")
    join_named_meshes("Palm_Rachis", "Palm_Rachis_Merged")

    # Petit cœur de couronne.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.34, location=(0, 0, 6.35))
    crown = bpy.context.object
    crown.name = "Palm_Crown"
    crown.scale = (1.0, 1.0, 0.72)
    assign(crown, leaf_light)
    export_selected("palmier_baie_des_rois.glb")


def make_bench():
    clear_scene()
    wood = material("Bench_Teak", (0.34, 0.19, 0.085))
    wood_alt = material("Bench_Teak_Light", (0.52, 0.32, 0.15))
    metal = material("Bench_Dark_Metal", (0.075, 0.09, 0.10), 0.42, 0.72)

    def cube(name, loc, scale, mat, bevel=0.035):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        assign(obj, mat)
        if bevel:
            mod = obj.modifiers.new("Soft_Edges", "BEVEL")
            mod.width = bevel
            mod.segments = 2
            obj.modifiers.new("Weighted_Normals", "WEIGHTED_NORMAL")
        return obj

    # Banc de 1,85 m, assise à 45 cm, dossier incliné.
    for i in range(5):
        cube("Seat_Wood_Slat", (0, 0.43, -0.34 + i * 0.16),
             (1.85, 0.075, 0.13), wood if i % 2 else wood_alt)
    for i in range(3):
        cube("Back_Wood_Slat", (0, 0.78 + i * 0.14, 0.43),
             (1.85, 0.10, 0.11), wood if i % 2 else wood_alt)
    for x in (-0.70, 0.70):
        cube("Bench_Side_Frame", (x, 0.43, 0.02), (0.10, 0.72, 0.78), metal, 0.045)
        cube("Bench_Foot", (x, 0.08, 0.02), (0.12, 0.12, 0.92), metal, 0.035)
    export_selected("banc_baie_des_rois.glb")


def make_streetlight():
    clear_scene()
    metal = material("Streetlight_Charcoal", (0.055, 0.07, 0.075), 0.38, 0.78)
    diffuser = material("LED_Diffuser", (0.80, 0.86, 0.78), 0.28)
    set_material_input(diffuser, "Emission Color", (0.75, 0.82, 0.68, 1))
    set_material_input(diffuser, "Emission Strength", 0.35)

    def cylinder(name, radius, depth, loc, mat, vertices=12):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
        obj = bpy.context.object
        obj.name = name
        assign(obj, mat)
        bevel = obj.modifiers.new("Edge_Bevel", "BEVEL")
        bevel.width = 0.025
        bevel.segments = 2
        obj.modifiers.new("Weighted_Normals", "WEIGHTED_NORMAL")
        return obj

    cylinder("Pole_Base", 0.19, 0.22, (0, 0, 0.11), metal)
    cylinder("Pole", 0.075, 5.6, (0, 0, 2.92), metal)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.11, location=(0, 0, 5.72))
    assign(bpy.context.object, metal)
    # Bras horizontal et tête LED orientée vers le sol.
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.045, depth=1.15, location=(0.48, 0, 5.68), rotation=(0, math.pi / 2, 0))
    assign(bpy.context.object, metal)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(1.02, 0, 5.58))
    head = bpy.context.object
    head.name = "LED_Luminaire"
    head.dimensions = (0.48, 0.28, 0.14)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(head, metal)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(1.02, 0, 5.49))
    panel = bpy.context.object
    panel.name = "LED_Diffuser"
    panel.dimensions = (0.38, 0.20, 0.025)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(panel, diffuser)
    export_selected("lampadaire_baie_des_rois.glb")


if __name__ == "__main__":
    make_palm()
    make_bench()
    make_streetlight()
    print("BAIE DES ROIS | 3 assets exportés : palmier, banc, lampadaire")
