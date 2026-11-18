"""Generate the second, visually distinct Baie des Rois kiosk and export GLB.

Run from repository root with Blender 5.3:
  blender --background --python tools/blender/create_baie_des_rois_kiosk_type_b.py
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "baie_des_rois", "kiosque_baie_des_rois_type_b.glb")
W, D = 4.8, 3.6

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def mat(name, color, rough=0.72, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    shader = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if shader is None:
        shader = nodes.new("ShaderNodeBsdfPrincipled")
    output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
    if output is None:
        output = nodes.new("ShaderNodeOutputMaterial")
    if not output.inputs["Surface"].is_linked:
        links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metallic
    return m

ivory = mat("Type B | enduit clair", (0.82, 0.80, 0.72))
white = mat("Type B | blanc", (0.94, 0.92, 0.85))
green = mat("Type B | vert baie", (0.035, 0.22, 0.15), 0.46, 0.12)
dark = mat("Type B | metal anthracite", (0.09, 0.12, 0.12), 0.42, 0.55)
wood = mat("Type B | bois miel", (0.48, 0.27, 0.12), 0.7)
glass = mat("Type B | vitrage", (0.08, 0.22, 0.25), 0.2, 0.15)
concrete = mat("Type B | beton", (0.43, 0.44, 0.42))
created = []

def cube(name, loc, size, material, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        b = o.modifiers.new("Aretes adoucies", "BEVEL")
        b.width, b.segments = bevel, 2
        o.modifiers.new("Normales propres", "WEIGHTED_NORMAL")
    created.append(o)
    return o

def beam(name, a, b, radius, material):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=d.length, location=(a+b)/2)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.to_track_quat("Z", "Y")
    o.data.materials.append(material)
    created.append(o)
    return o

# Raised concrete platform and a more open, modern service pavilion.
cube("Socle beton", (0, 0, 0.10), (W+0.22, D+0.22, 0.20), concrete, 0.055)
cube("Plancher", (0, 0, 0.215), (W, D, 0.035), ivory, 0.01)

# Rear service wall with a timber band; two side screens remain mostly glazed.
cube("Mur fond", (0, 1.68, 1.52), (W-0.18, 0.20, 2.55), ivory, 0.03)
for side in (-1, 1):
    x = side * 2.22
    cube("Vitrage lateral", (x, 0.0, 1.72), (0.055, 2.95, 2.18), glass, 0.012)
    for y in (-1.38, 0.0, 1.38):
        cube("Montant lateral", (x-side*0.035, y, 1.72), (0.09, 0.065, 2.28), dark, 0.008)

# Broad open counter on the front; vertical timber fins give it a distinct identity.
cube("Comptoir facade", (0, -1.55, 0.72), (4.15, 0.16, 0.78), green, 0.025)
cube("Plan de service", (0, -1.57, 1.15), (4.35, 0.58, 0.10), wood, 0.025)
for i in range(21):
    x = -2.0 + i*0.20
    cube("Claustra bois facade", (x, -1.40, 1.72), (0.055, 0.08, 1.10), wood, 0.008)

# Four slim columns support a flat, slightly tilted cantilever roof.
for x in (-2.20, 2.20):
    for y in (-1.52, 1.52):
        cube("Poteau metal", (x, y, 1.85), (0.12, 0.12, 3.25), dark, 0.018)
roof = cube("Auvent plat debordant", (0, 0, 3.62), (W+0.78, D+0.78, 0.20), green, 0.045)
roof.rotation_euler[0] = math.radians(-2.0)
cube("Sous face bois", (0, 0, 3.49), (W+0.40, D+0.40, 0.045), wood, 0.012)
cube("Bandeau facade", (0, -2.02, 3.28), (W+0.35, 0.12, 0.34), white, 0.025)
cube("Gouttiere", (0, -1.98, 3.48), (W+0.65, 0.12, 0.12), dark, 0.02)
for x in (-2.12, 2.12):
    beam("Descente pluviale", (x, -1.98, 3.45), (x, -1.98, 0.32), 0.035, dark)

# A horizontal green sign band distinguishes type B from the pitched-roof kiosk.
cube("Enseigne", (0, -2.095, 3.28), (2.75, 0.035, 0.22), green, 0.012)
font = bpy.data.curves.new("Texte enseigne type B", type="FONT")
font.body = "BAIE DES ROIS"
font.size = 0.18
font.extrude = 0.001
txt = bpy.data.objects.new("Texte BAIE DES ROIS type B", font)
bpy.context.collection.objects.link(txt)
txt.location = (-1.08, -2.12, 3.22)
txt.rotation_euler[0] = math.radians(90)
font.materials.append(white)
bpy.ops.object.select_all(action="DESELECT")
txt.select_set(True)
bpy.context.view_layer.objects.active = txt
bpy.ops.object.convert(target="MESH")
created.append(bpy.context.object)

# Menu panel and a small side service shutter.
cube("Panneau menu", (1.76, -1.92, 1.92), (0.42, 0.07, 0.72), dark, 0.018)
for z in (1.70, 1.88, 2.06):
    cube("Ligne menu", (1.76, -1.965, z), (0.26, 0.012, 0.022), white, 0.003)
cube("Volet service lateral", (-2.27, 0.15, 2.30), (0.06, 1.05, 0.68), green, 0.012)

collection = bpy.data.collections.new("LIBREVILLE_STORIES_KIOSK_TYPE_B")
bpy.context.scene.collection.children.link(collection)
for obj in created:
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)

bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(iter(collection.objects))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True)
print("KIOSK_TYPE_B_EXPORTED:", OUT)
