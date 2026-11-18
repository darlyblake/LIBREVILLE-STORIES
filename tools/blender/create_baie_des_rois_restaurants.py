"""Restaurant pavilion assets for LIBREVILLE-STORIES / Baie des Rois.

Run from the repository root:
  & "C:\\Program Files\\Blender Foundation\\Blender 5.3\\blender.exe" --background --python tools/blender/create_baie_des_rois_restaurants.py

Exports three GLB variants with the same architectural language. They are
assets only: placement is intentionally left to the existing OSM footprints
so no geographic position is guessed here. Blender 5.3 / Godot 4.3.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "models", "baie_des_rois")
os.makedirs(OUT_DIR, exist_ok=True)

# The standard pavilion is deliberately modular; Godot can scale it to the
# exact footprint of each existing mapped building after those footprints
# have been identified and excluded from the generic OSM building batch.
VARIANTS = [
    ("restaurant_pavillon_baie_des_rois_compact.glb", 6.8, 5.8),
    ("restaurant_pavillon_baie_des_rois.glb", 8.4, 6.8),
    ("restaurant_pavillon_baie_des_rois_large.glb", 10.0, 7.8),
]

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.meshes, bpy.data.curves):
        # Do not purge materials still used by another scene object.
        pass


def make_material(name, color, roughness=0.75, metallic=0.0, texture="none"):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
    if output is None:
        output = nodes.new("ShaderNodeOutputMaterial")
    if not output.inputs["Surface"].is_linked:
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic

    if texture == "wood":
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 5.5
        tex.inputs["Detail"].default_value = 3.0
        tex.inputs["Roughness"].default_value = 0.72
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.22
        ramp.color_ramp.elements[0].color = (color[0]*0.48, color[1]*0.42, color[2]*0.36, 1)
        ramp.color_ramp.elements[1].position = 0.78
        ramp.color_ramp.elements[1].color = (min(color[0]*1.32,1), min(color[1]*1.28,1), min(color[2]*1.2,1), 1)
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.16
        bump.inputs["Distance"].default_value = 0.045
        links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(tex.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    elif texture == "roof":
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 95.0
        noise.inputs["Detail"].default_value = 2.0
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.12
        bump.inputs["Distance"].default_value = 0.018
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def finish(obj, name, mat, bevel=0.0):
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    if bevel and obj.type == "MESH":
        mod = obj.modifiers.new("Petits_biseaux", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Normales_ponderees", "WEIGHTED_NORMAL")
    return obj


def cube(name, loc, dims, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)


def cylinder(name, loc, radius, depth, mat, vertices=16, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=loc, rotation=rotation or (0,0,0))
    return finish(bpy.context.object, name, mat, 0.012)


def beam(name, a, b, radius, mat, vertices=10):
    a, b = Vector(a), Vector(b)
    delta = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
        depth=delta.length, location=(a+b)*0.5)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return finish(obj, name, mat, 0.008)


def make_text(body, name, location, size, mat, rotation=(math.pi/2,0,0)):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = 0.0015
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    curve.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def create_pavilion(width, depth, output_name):
    clear_scene()
    W, D = width, depth
    eave_z, ridge_z = 3.25, 4.48
    half_run = D * 0.5 + 0.32
    angle = math.atan2(ridge_z-eave_z, half_run)
    slope_len = math.sqrt(half_run**2 + (ridge_z-eave_z)**2)

    wood = make_material("Bois_tropical_teck", (0.34,0.19,0.095), 0.72, texture="wood")
    wood_light = make_material("Bois_clair_menuiserie", (0.53,0.34,0.17), 0.74, texture="wood")
    wood_dark = make_material("Bois_structure_fonce", (0.19,0.105,0.052), 0.7, texture="wood")
    green = make_material("Toiture_vert_foret", (0.035,0.19,0.095), 0.43, 0.48, "roof")
    green_dark = make_material("Rives_vert_sombre", (0.018,0.075,0.045), 0.48, 0.42)
    concrete = make_material("Dalle_beton_sable", (0.55,0.53,0.47), 0.9)
    cream = make_material("Enduit_ivoire", (0.82,0.77,0.65), 0.86)
    glass = make_material("Verre_fume", (0.12,0.25,0.27), 0.2, 0.12)
    metal = make_material("Acier_anthracite", (0.055,0.07,0.065), 0.38, 0.68)
    linen = make_material("Toile_ecrue", (0.88,0.84,0.72), 0.94)
    leaf = make_material("Feuillage_tropical", (0.12,0.30,0.12), 0.88)
    warm_light = make_material("Diffuseur_lumiere_chaude", (1.0,0.72,0.38), 0.3)
    bsdf = next(n for n in warm_light.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (1.0,0.46,0.16,1)
        bsdf.inputs["Emission Strength"].default_value = 1.4

    # Raised concrete terrace and interior floor.
    cube("Socle_beton", (0,0,0.12), (W+0.38,D+0.38,0.24), concrete, 0.07)
    cube("Carrelage_interieur", (0,0,0.255), (W,D,0.035), cream, 0.012)
    # Subtle paving joints.
    for x in [(-W/2 + i*0.6) for i in range(1, int(W/0.6))]:
        cube("Joint_dallage", (x,0,0.277), (0.012,D-0.12,0.004), concrete, 0)

    # Timber columns and perimeter beams.
    post_x = [-W/2+0.18, W/2-0.18]
    post_y = [-D/2+0.18, D/2-0.18]
    for x in post_x:
        for y in post_y:
            cube("Poteau_porteur_lamelle", (x,y,(0.28+eave_z)/2),
                 (0.19,0.19,eave_z-0.28), wood_dark, 0.035)
            cube("Pied_poteau_acier", (x,y,0.42), (0.25,0.25,0.12), metal, 0.018)
    for y in post_y:
        cube("Poutre_longitudinale", (0,y,eave_z-0.12), (W+0.18,0.22,0.24), wood_dark, 0.035)
    for x in post_x:
        cube("Poutre_transversale", (x,0,eave_z-0.12), (0.22,D+0.18,0.24), wood_dark, 0.035)

    # Rear service wall, side screens and glazed serving frontage.
    cube("Mur_arriere_enduit", (0,D/2-0.12,1.72), (W-0.38,0.22,2.88), cream, 0.035)
    cube("Bandeau_bois_arriere", (0,D/2-0.245,2.85), (W-0.55,0.035,0.12), wood, 0.01)
    for side in (-1,1):
        x = side*(W/2-0.14)
        cube("Claustra_lateral_bas", (x,0.48,1.02), (0.12,D-1.05,1.48), wood, 0.025)
        for j in range(9):
            yy = -D/2+0.9+j*(D-1.8)/8
            cube("Lame_claustra", (x-side*0.075,yy,1.02), (0.035,0.055,1.45), wood_light, 0.008)

    # Front service counter and pass-through opening.
    front_y = -D/2+0.16
    cube("Facade_comptoir", (0,front_y,0.83), (W-0.62,0.14,0.94), wood, 0.025)
    for i in range( max(12, int(W*4)) ):
        x = -W/2+0.42+i*(W-0.84)/(max(12,int(W*4))-1)
        cube("Lattes_facade_comptoir", (x,front_y-0.078,0.83), (0.035,0.025,0.88), wood_light, 0.006)
    cube("Plan_comptoir", (0,front_y-0.13,1.34), (W-0.48,0.62,0.10), wood_light, 0.025)
    cube("Credence_comptoir", (0,-D/2+0.78,1.72), (W-0.72,0.055,0.72), glass, 0.012)
    # Kitchen work island and storage hints visible through the opening.
    cube("Plan_travail_cuisine", (0,D/2-0.82,1.10), (W-1.0,0.75,0.12), metal, 0.025)
    for x in (-W*0.27,0,W*0.27):
        cube("Facade_meuble_cuisine", (x,D/2-0.82,0.70), (0.68,0.62,0.66), wood_dark, 0.025)

    # Large two-slope green metal roof with standing seams.
    for side in (-1,1):
        panel = cube("Pan_toiture_vert_deux_pans",
            (0,side*half_run*0.5,(eave_z+ridge_z)*0.5),
            (W+0.82,slope_len+0.12,0.16), green, 0.025)
        panel.rotation_euler[0] = -side*angle
        # Raised standing seams follow the roof slope.
        for i in range(1, int(W/0.38)):
            x = -W/2 + i*0.38
            seam = cube("Nervure_toiture", (x,side*half_run*0.5,(eave_z+ridge_z)*0.5+0.09),
                        (0.028,slope_len,0.055), green_dark, 0.008)
            seam.rotation_euler[0] = -side*angle
    cube("Faitage_metallique", (0,0,ridge_z+0.05), (W+0.96,0.24,0.18), green_dark, 0.035)
    for side in (-1,1):
        cube("Bandeau_rive_longitudinale", (0,side*(half_run+0.03),eave_z),
             (W+0.98,0.16,0.24), green_dark, 0.025)
    # Timber soffit, visible under the broad overhang.
    cube("Sous_face_bois", (0,0,eave_z-0.17), (W+0.58,D+0.58,0.07), wood, 0.018)

    # Gutters and downpipes.
    for side in (-1,1):
        y = side*(half_run-0.02)
        cylinder("Gouttiere", (0,y,eave_z-0.13), 0.075, W+0.55, metal, 16, (0,math.pi/2,0))
        for x in (-W/2+0.32,W/2-0.32):
            beam("Descente_eaux_pluviales", (x,y,eave_z-0.12), (x,y,0.38), 0.035, metal)

    # Restaurant nameplate and discreet wayfinding.
    cube("Enseigne_fond", (0,-D/2-0.10,2.94), (min(W*0.58,4.6),0.075,0.42), green_dark, 0.035)
    make_text("RESTAURANT", "Enseigne_restaurant",
              (-min(W*0.25,1.85),-D/2-0.145,2.83), 0.24, linen)
    cube("Panneau_menu", (W/2-0.38,-D/2-0.10,1.95), (0.52,0.08,0.78), wood_dark, 0.025)
    for z in (1.72,1.88,2.04,2.20):
        cube("Ligne_menu", (W/2-0.38,-D/2-0.15,z), (0.30,0.012,0.022), linen, 0.004)

    # Dining area: four compact table sets, adjusted to the footprint.
    table_count = 2 if W < 7.5 else (4 if W < 9.5 else 6)
    positions = []
    cols = 2
    rows = math.ceil(table_count/cols)
    usable_x = min(W-2.0, 5.6)
    for idx in range(table_count):
        col, row = idx%cols, idx//cols
        x = (-usable_x/2 + col*usable_x/max(1,cols-1)) if cols > 1 else 0
        y = -0.15 + row*1.55 - (rows-1)*0.55
        positions.append((x,y))
    for idx,(tx,ty) in enumerate(positions):
        cube("Table_plateau_teck", (tx,ty,0.98), (1.05,0.72,0.10), wood_light, 0.045)
        for dx in (-0.40,0.40):
            for dy in (-0.24,0.24):
                cube("Pied_table", (tx+dx,ty+dy,0.61), (0.055,0.055,0.66), metal, 0.01)
        for sign in (-1,1):
            cx = tx + sign*0.83
            cube("Assise_chaise", (cx,ty,0.58), (0.48,0.48,0.09), wood, 0.025)
            cube("Dossier_chaise", (cx,ty+0.22,0.88), (0.48,0.075,0.62), wood, 0.025)
            for dx in (-0.19,0.19):
                for dy in (-0.18,0.18):
                    cube("Pied_chaise", (cx+dx,ty+dy,0.31), (0.045,0.045,0.54), metal, 0.008)

    # Pendant lamps below the roof.
    for x in (-W*0.25,0,W*0.25):
        beam("Suspension_cable", (x,0,eave_z-0.18), (x,0,2.78), 0.018, metal, 8)
        cylinder("Abat_jour", (x,0,2.72), 0.22, 0.11, green_dark, 16)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.085,
                                             location=(x,0,2.62))
        finish(bpy.context.object,"Ampoule_diffuseur",warm_light,0)

    # Low timber planters and tropical ornamental plants on both corners.
    for side in (-1,1):
        px, py = side*(W/2+0.20), -D/2+0.20
        cube("Jardiniere_bois", (px,py,0.43), (0.52,0.62,0.42), wood, 0.045)
        cylinder("Terreau", (px,py,0.66), 0.22, 0.045, concrete, 12)
        for j in range(5):
            a = 2*math.pi*j/5
            start = Vector((px,py,0.68))
            end = start + Vector((math.cos(a)*0.28,math.sin(a)*0.28,0.55+(j%2)*0.12))
            beam("Tige_plante", start, end, 0.018, leaf, 7)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.19,
                location=end)
            leaf_obj = bpy.context.object
            leaf_obj.scale = (1.0,0.42,0.28)
            leaf_obj.rotation_euler[2] = a
            finish(leaf_obj,"Feuille_ornementale",leaf,0)

    # Export selected mesh objects only. All text has been converted to mesh.
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    filepath = os.path.join(OUT_DIR, output_name)
    bpy.ops.export_scene.gltf(filepath=filepath, export_format="GLB",
        use_selection=True, export_apply=True, export_yup=True)
    print("RESTAURANT_GLB_EXPORTED:", filepath, "mesh_objects=", len(meshes))


if __name__ == "__main__":
    for filename, width, depth in VARIANTS:
        create_pavilion(width, depth, filename)
    print("BAIE DES ROIS | 3 pavillons de restauration exportés.")
