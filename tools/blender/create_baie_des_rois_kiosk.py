"""Create and export a first Baie des Rois kiosk asset for LIBREVILLE-STORIES.

Run from the repository root:
  blender --background --python tools/blender/create_baie_des_rois_kiosk.py

The script builds a modular low/mid-poly kiosk and exports GLB.
It does not modify the Godot scene automatically.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTPUT_DIR = os.path.join(ROOT, "assets", "models", "baie_des_rois")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "kiosque_baie_des_rois.glb")
W, D = 4.8, 3.6
WALL_H, ROOF_H = 2.65, 3.35

# Start with an empty scene.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness=0.72, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True

    # Blender 5.x may create a node tree without the default Principled node.
    # Create the shader and output explicitly instead of assuming they exist.
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.location = (0, 0)

    output = next((node for node in nodes if node.type == "OUTPUT_MATERIAL"), None)
    if output is None:
        output = nodes.new("ShaderNodeOutputMaterial")
        output.location = (300, 0)

    if not output.inputs["Surface"].is_linked:
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat

ivory = material("Enduit ivoire chaud", (0.78, 0.72, 0.59))
white = material("Blanc casse", (0.91, 0.88, 0.79))
blue = material("Bleu profond Baie des Rois", (0.035, 0.13, 0.22), 0.48)
wood = material("Bois tropical", (0.30, 0.16, 0.075), 0.66)
glass = material("Vitrage teinte", (0.10, 0.23, 0.27), 0.22, 0.12)
concrete = material("Beton", (0.43, 0.43, 0.39))
metal = material("Metal peint", (0.12, 0.14, 0.15), 0.38, 0.55)
created = []

def finish(obj, name, mat, bevel=0.0):
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Aretes adoucies", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Normales propres", "WEIGHTED_NORMAL")
    created.append(obj)
    return obj

def cube(name, loc, scale, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)

def beam_between(name, a, b, radius, mat, vertices=12):
    a, b = Vector(a), Vector(b)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
        depth=direction.length, location=(a+b)/2)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return finish(obj, name, mat, 0.008)

# Concrete base and floor.
cube("Dalle beton", (0, 0, 0.10), (W+0.24, D+0.24, 0.20), concrete, 0.06)
cube("Sol interieur", (0, 0, 0.215), (W, D, 0.035), ivory, 0.01)

# Rear wall and two side returns; front remains open for service.
cube("Mur arriere", (0, D/2-0.10, 0.215+WALL_H/2), (W-0.18, 0.20, WALL_H), ivory, 0.035)
for side in (-1, 1):
    cube("Retour lateral", (side*(W/2-0.10), 0.02, 0.215+WALL_H/2),
         (0.20, D-0.20, WALL_H), ivory, 0.035)

# Front service counter and timber details.
cube("Comptoir facade", (0, -D/2+0.20, 1.12), (W-0.45, 0.42, 0.16), wood, 0.035)
cube("Facade comptoir", (0, -D/2+0.39, 0.70), (W-0.48, 0.12, 0.78), blue, 0.025)
cube("Plan de travail", (0, -D/2+0.18, 1.23), (W-0.34, 0.58, 0.09), wood, 0.025)
for i in range(17):
    x = -W/2 + 0.55 + i*0.23
    cube("Lame bois decorative", (x, D/2-0.205, 1.35), (0.045, 0.035, 1.85), wood, 0.008)

# Side glazing and metal frames.
for side in (-1, 1):
    x = side*(W/2-0.205)
    cube("Vitrage lateral", (x, 0.15, 2.0), (0.035, 1.35, 0.95), glass, 0.012)
    for yy in (-0.54, 0.84):
        cube("Montant vitrage", (x-side*0.025, yy, 2.0), (0.09, 0.055, 1.08), metal, 0.008)
    for zz in (1.47, 2.53):
        cube("Traverse vitrage", (x-side*0.025, 0.15, zz), (0.09, 1.48, 0.055), metal, 0.008)

# Four structural posts and broad canopy.
for x in (-W/2+0.16, W/2-0.16):
    for y in (-D/2+0.16, D/2-0.16):
        cube("Poteau structure", (x, y, 1.72), (0.13, 0.13, 3.0), blue, 0.025)
cube("Auvent toiture", (0, 0, ROOF_H), (W+0.65, D+0.55, 0.22), blue, 0.07)
cube("Bandeau facade", (0, -D/2-0.23, 3.12), (W+0.30, 0.12, 0.34), ivory, 0.035)
cube("Sous face auvent", (0, 0, 3.215), (W+0.46, D+0.34, 0.035), white, 0.015)

# Rainwater details.
cube("Gouttiere avant", (0, -D/2-0.29, 3.20), (W+0.55, 0.10, 0.10), metal, 0.025)
for x in (-W/2+0.22, W/2-0.22):
    beam_between("Descente eau pluviale", (x, -D/2-0.27, 3.16),
                 (x, -D/2-0.27, 0.34), 0.035, metal)

# Sign panel and text converted to mesh for reliable GLB export.
cube("Enseigne fond", (0, -D/2-0.30, 3.12), (2.65, 0.055, 0.25), blue, 0.02)
font = bpy.data.curves.new("Texte enseigne", type="FONT")
font.body = "BAIE DES ROIS"
font.size = 0.19
font.extrude = 0.001
text_obj = bpy.data.objects.new("Enseigne BAIE DES ROIS", font)
bpy.context.collection.objects.link(text_obj)
text_obj.location = (-1.10, -D/2-0.337, 3.055)
text_obj.rotation_euler[0] = math.radians(90)
font.materials.append(white)
bpy.ops.object.select_all(action="DESELECT")
text_obj.select_set(True)
bpy.context.view_layer.objects.active = text_obj
bpy.ops.object.convert(target="MESH")
text_obj = bpy.context.object
created.append(text_obj)

# Exterior menu panel.
cube("Panneau menu", (1.72, -D/2-0.12, 1.88), (0.48, 0.06, 0.72), blue, 0.025)
for z in (1.66, 1.84, 2.02):
    cube("Ligne menu", (1.72, -D/2-0.155, z), (0.30, 0.012, 0.025), white, 0.004)

# Collect all generated meshes under one asset collection.
collection = bpy.data.collections.new("LIBREVILLE_STORIES_BAIE_DES_ROIS_KIOSK")
bpy.context.scene.collection.children.link(collection)
for obj in created:
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)

# Keep the base resting at Z=0 and export only the kiosk.
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(iter(collection.objects))
os.makedirs(OUTPUT_DIR, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUTPUT_FILE,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
print("KIOSK_GLB_EXPORTED:", OUTPUT_FILE)
