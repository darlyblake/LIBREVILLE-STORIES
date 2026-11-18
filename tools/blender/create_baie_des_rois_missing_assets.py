"""Missing standalone assets for the first Baie des Rois area.

Run from repository root:
  & "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools/blender/create_baie_des_rois_missing_assets.py

Exports reusable GLB assets only. No world positions are assigned here:
placement must follow the existing mapped green-space polygons and verified
reference locations. Blender 5.3 / Godot 4.3 / low-end GPU friendly.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "baie_des_rois")
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, rough=0.8, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def finish(obj, name, material, bevel=0.0):
    obj.name = name
    if material:
        obj.data.materials.append(material)
    if bevel and obj.type == "MESH":
        b = obj.modifiers.new("Bords_adoucis", "BEVEL")
        b.width = bevel
        b.segments = 2
        obj.modifiers.new("Normales_ponderees", "WEIGHTED_NORMAL")
    return obj


def box(name, loc, size, material, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, material, bevel)


def cyl(name, loc, radius, depth, material, vertices=16, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
        depth=depth, location=loc, rotation=rotation or (0, 0, 0))
    return finish(bpy.context.object, name, material, 0.008)


def beam(name, a, b, radius, material, vertices=10):
    a, b = Vector(a), Vector(b)
    d = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
        depth=d.length, location=(a+b)*0.5)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.to_track_quat("Z", "Y")
    return finish(o, name, material, 0.006)


def export(filename):
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
    if meshes:
        bpy.context.view_layer.objects.active = meshes[0]
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
        use_selection=True, export_apply=True, export_yup=True)
    print("BAIE_MISSING_ASSET_EXPORTED:", path, "meshes:", len(meshes))


def create_thatch_pavilion():
    reset()
    wood = mat("Bois_brun_orange", (0.39, 0.20, 0.09))
    wood_dark = mat("Bois_structure", (0.20, 0.105, 0.05))
    thatch = mat("Chaume_fibres_naturelles", (0.57, 0.39, 0.19))
    thatch_light = mat("Fibres_claires", (0.72, 0.54, 0.29))
    stone = mat("Dalle_pierre_sable", (0.62, 0.59, 0.51))
    W, D = 7.2, 6.2
    box("Dalle_pavillon", (0, 0, 0.12), (W+0.3, D+0.3, 0.24), stone, 0.05)
    # Four timber posts and a simple open-sided shelter.
    for x in (-W/2+0.18, W/2-0.18):
        for y in (-D/2+0.18, D/2-0.18):
            box("Poteau_bois", (x, y, 1.75), (0.22, 0.22, 3.0), wood_dark, 0.025)
    for y in (-D/2+0.18, D/2-0.18):
        box("Poutre_longue", (0, y, 3.15), (W+0.2, 0.25, 0.25), wood, 0.025)
    for x in (-W/2+0.18, W/2-0.18):
        box("Poutre_transversale", (x, 0, 3.15), (0.25, D+0.2, 0.25), wood, 0.025)
    # A warm service counter at the rear, with open customer frontage.
    box("Comptoir", (0, D/2-0.35, 0.88), (W-0.8, 0.65, 1.0), wood, 0.035)
    box("Plan_comptoir", (0, D/2-0.35, 1.42), (W-0.65, 0.78, 0.12), thatch_light, 0.025)
    for x in (-2.0, 0, 2.0):
        box("Etagere_arriere", (x, D/2-0.68, 1.95), (1.2, 0.08, 0.08), wood_dark, 0.01)
    # Four sloping roof panels, represented by a faceted thick thatch shell.
    ridge = 4.55
    eave = 3.35
    half = D/2 + 0.45
    angle = math.atan2(ridge-eave, half)
    length = math.sqrt(half*half + (ridge-eave)**2)
    for side in (-1, 1):
        p = box("Toit_chaume_pan", (0, side*half/2, (ridge+eave)/2),
                (W+0.85, length, 0.30), thatch, 0.04)
        p.rotation_euler[0] = -side*angle
        # Short raised fibre strips create a visible thatch texture without
        # excessive polygons; they follow the slope.
        for i in range(0, 30):
            x = -W/2 + i*(W/29)
            strip = box("Nervure_fibres_chaume",
                (x, side*half/2, (ridge+eave)/2+0.16),
                (0.035, length*0.98, 0.045), thatch_light, 0.008)
            strip.rotation_euler[0] = -side*angle
    box("Faitage_chaume", (0, 0, ridge+0.04), (W+0.95, 0.42, 0.34), thatch_light, 0.08)
    # Low woven side screens, leaving the front open.
    for side in (-1, 1):
        x = side*(W/2-0.13)
        for i in range(11):
            z = 0.65 + i*0.13
            box("Claustra_lateral", (x, 0.55, z), (0.10, D-1.1, 0.055), wood, 0.008)
    export("pavillon_chaume_baie_des_rois.glb")


def create_playground():
    reset()
    red = mat("Rouge_jeux", (0.78, 0.055, 0.035), 0.55)
    yellow = mat("Jaune_jeux", (0.98, 0.62, 0.035), 0.55)
    blue = mat("Bleu_jeux", (0.035, 0.25, 0.58), 0.55)
    green = mat("Vert_jeux", (0.10, 0.40, 0.19), 0.65)
    metal = mat("Acier_peint", (0.18, 0.20, 0.20), 0.42, 0.45)
    rubber = mat("Sol_caoutchouc", (0.27, 0.31, 0.30), 0.95)
    # Compact rubber safety pad is an asset base, not a site placement.
    box("Dalle_souple_aire_jeux", (0, 0, 0.06), (10.0, 8.0, 0.12), rubber, 0.12)
    # Double swing frame with A-legs, top beam, chains and two seats.
    # Deux portiques en A se rejoignent sur une barre longitudinale.
    for top_x in (-3.7, 0.95):
        for side in (-1, 1):
            foot = (top_x + side*0.72, side*1.35, 0.18)
            head = (top_x, 0.0, 3.45)
            beam("Jambe_portique_A", foot, head, 0.085, red)
    beam("Barre_haute_balançoire", (-3.7, 0.0, 3.45),
         (0.95, 0.0, 3.45), 0.095, yellow)
    for sx in (-2.65, -0.15):
        for side in (-1, 1):
            beam("Chaine_balançoire", (sx, side*0.20, 3.30),
                 (sx, side*0.20, 1.45), 0.025, metal, 8)
        box("Siege_balançoire", (sx, 0, 1.38), (0.62, 0.42, 0.12), blue, 0.04)
    # Small slide: ladder, platform, side guards and sloped chute.
    for x in (1.55, 2.45):
        beam("Pied_toboggan", (x, -1.65, 0.15), (x, -1.65, 1.65), 0.055, metal)
    box("Plateforme_toboggan", (2.0, -1.65, 1.62), (1.15, 1.1, 0.16), yellow, 0.04)
    for x in (1.62, 2.38):
        beam("Garde_corps_toboggan", (x, -1.65, 1.65), (x, -1.65, 2.35), 0.055, red)
    chute = box("Glissiere_toboggan", (2.0, -0.15, 0.92), (1.0, 3.0, 0.13), blue, 0.06)
    chute.rotation_euler[0] = math.radians(-20)
    # Climbing ladder and low seesaw.
    for y in (-0.65, 0.65):
        beam("Montant_echelle", (3.55, y, 0.15), (3.55, y, 2.0), 0.045, metal)
    for z in (0.45, 0.82, 1.19, 1.56):
        beam("Barreau_echelle", (3.55, -0.65, z), (3.55, 0.65, z), 0.04, yellow)
    cyl("Pivot_bascule", (0.0, 2.15, 0.55), 0.30, 0.45, red, 12)
    beam("Planche_bascule", (-2.1, 2.15, 0.80), (2.1, 2.15, 0.80), 0.09, yellow, 8)
    for x in (-2.1, 2.1):
        box("Poignee_bascule", (x, 2.15, 1.05), (0.12, 0.16, 0.48), blue, 0.04)
    export("aire_jeux_baie_des_rois.glb")


def create_picnic_table():
    reset()
    wood = mat("Bois_table_pique_nique", (0.43, 0.24, 0.11), 0.78)
    metal = mat("Pieds_metalliques", (0.12, 0.14, 0.14), 0.48, 0.55)
    # Standard 6-person picnic table, 2.1 x 1.8 m footprint.
    box("Plateau_table", (0, 0, 0.88), (2.0, 0.82, 0.12), wood, 0.035)
    for x in (-0.72, 0.72):
        beam("Pied_table_diagonal", (x, -0.25, 0.10), (x, 0, 0.84), 0.055, metal)
        beam("Pied_table_diagonal", (x, 0.25, 0.10), (x, 0, 0.84), 0.055, metal)
    for y in (-0.68, 0.68):
        box("Banc_assise", (0, y, 0.52), (2.0, 0.22, 0.09), wood, 0.025)
        for x in (-0.72, 0.72):
            beam("Pied_banc", (x, y, 0.10), (x, y, 0.50), 0.045, metal)
    export("table_pique_nique_baie_des_rois.glb")


def create_fountain():
    reset()
    stone = mat("Pierre_claire_fontaine", (0.68, 0.66, 0.59), 0.72)
    dark = mat("Pierre_sombre", (0.28, 0.32, 0.32), 0.55)
    water = mat("Eau_bleu_turquoise", (0.035, 0.32, 0.42), 0.18, 0.12)
    # Low circular basin and central nozzle. Water is a static blue insert;
    # a lightweight Godot shader can animate it later if desired.
    cyl("Socle_fontaine", (0, 0, 0.16), 2.0, 0.32, stone, 48)
    cyl("Bassin_fontaine", (0, 0, 0.43), 1.82, 0.26, stone, 48)
    cyl("Eau_bassin", (0, 0, 0.57), 1.58, 0.035, water, 48)
    cyl("Colonne_centrale", (0, 0, 0.92), 0.24, 0.72, dark, 20)
    cyl("Couronne_superieure", (0, 0, 1.32), 0.58, 0.12, stone, 32)
    cyl("Buse_jet", (0, 0, 1.47), 0.10, 0.18, dark, 16)
    for i in range(8):
        a = 2*math.pi*i/8
        x, y = math.cos(a)*1.72, math.sin(a)*1.72
        cyl("Borne_bord_bassin", (x, y, 0.78), 0.11, 0.34, stone, 12)
    export("fontaine_baie_des_rois.glb")


def create_tropical_planting():
    reset()
    soil = mat("Terre_massif", (0.22, 0.15, 0.08), 0.95)
    planter = mat("Bordure_jardiniere_pierre", (0.52, 0.51, 0.44), 0.9)
    leaf_dark = mat("Feuilles_vert_fonce", (0.055, 0.22, 0.095), 0.88)
    leaf_mid = mat("Feuilles_vert_moyen", (0.16, 0.39, 0.16), 0.88)
    leaf_light = mat("Feuilles_vert_clair", (0.34, 0.52, 0.19), 0.88)
    flower = mat("Fleurs_tropicales", (0.82, 0.20, 0.12), 0.72)
    # Rectangular low planter containing a mixed tropical foliage cluster.
    box("Massif_terre", (0, 0, 0.18), (4.8, 2.2, 0.28), soil, 0.06)
    for x in (-2.35, 2.35):
        box("Bordure_massif", (x, 0, 0.30), (0.12, 2.3, 0.42), planter, 0.025)
    for y in (-1.08, 1.08):
        box("Bordure_massif", (0, y, 0.30), (4.8, 0.12, 0.42), planter, 0.025)
    # Broad-leaf tropical plants from low-poly ellipsoids and tapered stems.
    positions = [(-1.75,-0.55),(-1.0,0.45),(-0.2,-0.48),(0.65,0.42),(1.55,-0.42),
                 (-1.45,0.48),(0.15,0.50),(1.35,0.48)]
    for idx, (x,y) in enumerate(positions):
        h = 0.85 + (idx % 3)*0.18
        beam("Tige_massif", (x,y,0.34), (x,y,h), 0.035, leaf_dark, 7)
        for j in range(6):
            a = 2*math.pi*j/6 + idx*0.37
            length = 0.52 + (j%2)*0.12
            start = Vector((x,y,0.48 + (j%3)*0.12))
            end = start + Vector((math.cos(a)*length, math.sin(a)*length, 0.22+(j%2)*0.12))
            beam("Nervure_feuille", start, end, 0.018, leaf_dark, 6)
            center = (start+end)*0.5
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=1, location=center)
            o = bpy.context.object
            o.scale = (length*0.62, 0.13, 0.045)
            o.rotation_euler[2] = a
            finish(o, "Feuille_tropicale", [leaf_dark, leaf_mid, leaf_light][j%3], 0)
    # Small flowering accents, not a continuous carpet.
    for x,y in [(-1.8,0.15),(-0.55,-0.72),(0.9,-0.7),(1.85,0.12)]:
        beam("Tige_fleur", (x,y,0.35), (x,y,0.78), 0.018, leaf_dark, 6)
        for j in range(5):
            a = 2*math.pi*j/5
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5,
                radius=0.11, location=(x+math.cos(a)*0.11,y+math.sin(a)*0.11,0.80))
            finish(bpy.context.object, "Petale_fleur", flower, 0)
    export("massif_tropical_baie_des_rois.glb")


if __name__ == "__main__":
    create_thatch_pavilion()
    create_playground()
    create_picnic_table()
    create_fountain()
    create_tropical_planting()
    print("BAIE DES ROIS | 5 familles d'assets manquants générées.")
