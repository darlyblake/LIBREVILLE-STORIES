"""Blender generator for Libreville landmark GLBs. Run from repo root:
blender --background --python tools/blender/generate_libreville_landmarks.py
Models are modular placeholders; replace named materials with licensed PBR maps later.
Leon Mba memorial and Independence Tribune remain texture-dependent and are not rebuilt.
"""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..",".."))
OUT=os.path.join(ROOT,"assets","models","landmarks")
os.makedirs(OUT,exist_ok=True)
def reset():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
def mat(n,c,r=.78,m=0):
    x=bpy.data.materials.new(n); x.diffuse_color=(*c,1); x.use_nodes=True
    s=next(z for z in x.node_tree.nodes if z.type=="BSDF_PRINCIPLED")
    s.inputs["Base Color"].default_value=(*c,1); s.inputs["Roughness"].default_value=r; s.inputs["Metallic"].default_value=m
    return x
def finish(o,n,m,b=0):
    o.name=n
    if m:o.data.materials.append(m)
    if b:
        q=o.modifiers.new("Bords_adoucis","BEVEL"); q.width=b; q.segments=2
        o.modifiers.new("Normales_ponderees","WEIGHTED_NORMAL")
    return o
def box(n,p,d,m,b=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p); o=bpy.context.object; o.dimensions=d
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,n,m,b)
def cyl(n,p,r,h,m,v=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=r,depth=h,location=p); return finish(bpy.context.object,n,m,.006)
def beam(n,a,b,r,m):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object; o.rotation_mode="QUATERNION"; o.rotation_quaternion=d.to_track_quat("Z","Y")
    return finish(o,n,m,.003)
def roof(n,cx,cy,w,d,eave,ridge,m):
    run=d*.5+.35; length=math.hypot(run,ridge-eave)
    for side in (-1,1):
        o=box(n,(cx,cy+side*run*.5,(ridge+eave)*.5),(w+.7,length,.22),m,.02)
        o.rotation_euler[0]=-side*math.atan2(ridge-eave,run)
def window(n,x,y,z,w,h,frame,glass):
    box(n+"_cadre",(x,y,z),(w+.12,.10,h+.12),frame,.008)
    box(n+"_vitrage",(x,y-.06,z),(w,.025,h),glass,.003)
    box(n+"_meneau",(x,y-.08,z),(w,.02,.035),frame,.002)
def export(name):
    bpy.ops.object.select_all(action="DESELECT"); objs=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    path=os.path.join(OUT,name)
    bpy.ops.export_scene.gltf(filepath=path,export_format="GLB",use_selection=True,export_apply=True,export_yup=True)
    print("EXPORTED",path,"meshes",len(objs))
def saint_michel():
    reset()
    wall=mat("SM_Enduit_ocre",(0.66,.47,.31)); stone=mat("SM_Pierre",(0.27,.25,.21))
    wood=mat("SM_Douka_sculpte",(0.28,.12,.055)); roofmat=mat("SM_Tole",(0.14,.18,.17),.62,.2)
    dark=mat("SM_Menuiserie",(.07,.065,.055)); glass=mat("SM_Vitraux",(.09,.22,.23),.2)
    colors=[mat("SM_Mosaique_"+str(i),c) for i,c in enumerate([(.7,.16,.08),(.9,.61,.12),(.12,.34,.27),(.12,.28,.58),(.8,.76,.61)])]
    box("Parvis",(0,-15,.08),(52,18,.16),stone); box("Soubassement",(0,0,.55),(39,25,1.1),stone)
    box("Nef",(0,0,5),(37,23,8.8),wall); roof("Toiture_deux_pans",0,0,37,23,9.4,14.2,roofmat)
    # The church is documented with 31 carved hardwood pillars.
    coords=[(-17+i*2.25,y) for i in range(16) for y in (-11.4,11.4)]
    coords=coords[:31]
    for i,(x,y) in enumerate(coords):
        cyl("Pilier_Douka_sculpte_%02d"%i,(x,y,4.9),.24,8.7,wood)
        for z in (1.3,2.1,3,4,5,6,7,8): cyl("Relief_colonne",(x,y,z),.275,.06,wood)
    box("Fronton",(0,-11.8,9.25),(18,.3,2.2),wall)
    box("Bandeau_mosaique",(0,-11.98,9.55),(14,.12,1.25),dark)
    for i in range(28):
        box("Carreau_mosaique_%02d"%i,(-6.7+i*.5,-12.06,9.55),(.43,.045,.96),colors[(i+i//4)%5],.004)
    box("Porte",(0,-12,3),(4,.18,5.4),dark)
    for side in (-1,1):
        for x in (-12,-6,0,6,12): window("Baie_laterale",x,side*11.62,5.1,1.5,3,dark,glass)
    # Bell frame beside the main church: the original 1949 bell structure is retained.
    for x in (19,21):
        for y in (-9,-7): box("Clocher_poteau",(x,y,2.8),(.18,.18,5.3),wood)
    beam("Clocher_traverse",(19,-8,5.3),(21,-8,5.3),.10,wood)
    roof("Toit_clocher",20,-8,2.4,2.4,5.8,6.7,roofmat)
    cyl("Cloche",(20,-8,4.8),.28,.55,stone)
    export("eglise_saint_michel_nkembo.glb")
def cathedral():
    reset()
    yellow=mat("SMAR_Enduit_jaune",(.78,.57,.2)); wood=mat("SMAR_Charpente_bois",(.24,.12,.055))
    roofmat=mat("SMAR_Toiture",(.18,.21,.19),.65,.15); glass=mat("SMAR_Vitraux",(.13,.27,.38),.2)
    frame=mat("SMAR_Menuiserie",(.1,.08,.06)); stone=mat("SMAR_Pierre",(.48,.45,.38))
    box("Parvis",(0,-14,.08),(48,18,.16),stone); box("Nef",(0,0,6),(34,22,11.5),yellow)
    roof("Toiture_nef",0,0,34,22,11.8,17,roofmat)
    box("Facade_frontale",(0,-11.2,6.2),(34,.35,11.8),yellow)
    box("Portail_principal",(0,-11.43,3.4),(5,.18,6.5),frame)
    for x in (-10,-5,5,10): window("Vitrail_facade",x,-11.43,7.5,1.7,3.2,frame,glass)
    for side in (-1,1):
        for x in (-12,-6,0,6,12):
            window("Vitrail_lateral",x,side*11.15,6.6,1.8,3.4,frame,glass)
            box("Contrefort",(x,side*11.5,4.5),(.7,.8,8.5),yellow)
    # Timber roof trusses visible through the restored nave openings.
    for x in range(-15,16,5):
        beam("Entrait",(x,-9.5,10.5),(x,9.5,10.5),.13,wood)
        beam("Arbaletrier_gauche",(x,-9.5,10.5),(x,0,16.6),.13,wood)
        beam("Arbaletrier_droit",(x,9.5,10.5),(x,0,16.6),.13,wood)
    box("Tour_clocher",(0,-11.8,14),(5,4.8,7),yellow)
    for x in (-1.6,1.6): box("Ouverture_clocher",(x,-14.25,14.6),(.7,.08,2),frame)
    roof("Toit_clocher",0,-11.8,5.4,5,17.5,19.4,roofmat)
    beam("Croix_verticale",(0,-11.8,19.5),(0,-11.8,21),.09,wood)
    beam("Croix_horizontale",(-.7,-11.8,20.2),(.7,-11.8,20.2),.08,wood)
    export("cathedrale_sainte_marie_libreville.glb")
def baraka():
    reset()
    plaster=mat("Baraka_Enduit_chaux",(.78,.75,.65)); wood=mat("Baraka_Bois_ancien",(.28,.16,.085))
    tin=mat("Baraka_Tole_rouille",(.34,.16,.085),.78,.1); stone=mat("Baraka_Pierre",(.3,.29,.25))
    glass=mat("Baraka_Vitre",(.12,.17,.16),.3)
    # Two historic school blocks with verandas, based on archival site photographs.
    for i,x in enumerate((-8,8)):
        box("Ecole_bloc_%d"%i,(x,0,2.4),(13,8,4.6),plaster)
        roof("Toit_ecole",x,0,13,8,4.8,6.8,tin)
        for side in (-1,1):
            for j in range(4): window("Fenetre_ecole",x-4.5+j*3,side*4.08,2.9,1.4,1.8,wood,glass)
        for j in range(5):
            xx=x-5+j*2.5; beam("Poteau_galerie",(xx,-4.8,.2),(xx,-4.8,3.9),.13,wood)
    # Historic Protestant church with stone base and steep metal roof.
    box("Socle_eglise",(0,12,.55),(18,13,1.1),stone)
    box("Eglise_mission",(0,12,4.2),(17,12,7.2),plaster)
    roof("Toiture_eglise",0,12,17,12,7.8,12,tin)
    box("Clocher_tour",(0,5.85,8.1),(3.6,1,8.5),plaster)
    roof("Toit_clocher",0,5.85,3.8,2,12.3,13.5,tin)
    for x in (-5.5,-2.8,2.8,5.5): window("Fenetre_eglise",x,5.85,4.5,1.2,2.3,wood,glass)
    box("Porte_eglise",(0,5.78,2.2),(2.8,.16,4),wood)
    for x in range(-15,16,3): beam("Cloture_piquet",(x,-8,.1),(x,-8,1.1),.045,stone)
    for z in (.45,.9): beam("Cloture_traverse",(-15,-8,z),(15,-8,z),.035,stone)
    box("Cheminement_cour",(0,-5,.08),(5,18,.16),stone)
    export("mission_protestante_baraka_site.glb")
if __name__=="__main__":
    saint_michel(); cathedral(); baraka()
    print("3 monuments exportes dans assets/models/landmarks")
