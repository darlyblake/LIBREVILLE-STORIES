extends Node3D
## Premiers repères bâtis du centre de Libreville.
## Les positions proviennent des références OSM/Wikidata documentées dans le dépôt
## et les modèles GLB locaux sont des reconstructions originales Blender.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0

const CATHEDRAL_SCENE := "res://assets/models/landmarks/cathedrale_sainte_marie_libreville.glb"
const SAINT_MICHEL_SCENE := "res://assets/models/landmarks/eglise_saint_michel_nkembo.glb"

const CATHEDRAL_LAT := 0.40283
const CATHEDRAL_LON := 9.43630
const SAINT_MICHEL_LAT := 0.40907
const SAINT_MICHEL_LON := 9.45757
const MONT_BOUET_LAT := 0.40125
const MONT_BOUET_LON := 9.45192

var _world_map: Node
var _materials: Dictionary = {}


func _ready() -> void:
	_world_map = get_parent().get_node_or_null("WorldMap")
	_add_landmark("Cathedrale_Sainte_Marie", CATHEDRAL_SCENE, CATHEDRAL_LAT, CATHEDRAL_LON, 0.0)
	_add_landmark("Eglise_Saint_Michel_Nkembo", SAINT_MICHEL_SCENE, SAINT_MICHEL_LAT, SAINT_MICHEL_LON, 0.0)
	_build_mont_bouet_market()
	print("LIBREVILLE STORIES | cathédrale, Saint-Michel et premier marché Mont-Bouët instanciés")


func _geo_to_world(latitude: float, longitude: float) -> Vector3:
	var x := (longitude - CENTER_LON) * METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT))
	var z := (CENTER_LAT - latitude) * METERS_PER_DEG_LAT
	var y := 0.0
	if _world_map != null and _world_map.has_method("terrain_height_at_world"):
		y = _world_map.terrain_height_at_world(x, z)
	return Vector3(x, y, z)


func _add_landmark(node_name: String, scene_path: String, latitude: float, longitude: float, yaw: float) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("Modèle de repère absent : " + scene_path)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("Impossible de charger le modèle : " + scene_path)
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("Le modèle n'a pas de racine Node3D : " + scene_path)
		return
	instance.name = node_name
	instance.position = _geo_to_world(latitude, longitude)
	instance.rotation.y = yaw
	add_child(instance)


func _material(key: String, color: Color, roughness: float = 0.86, metallic: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	var pbr_asset := ""
	if key == "market_concrete":
		pbr_asset = "concrete_floor_01"
	elif key == "market_tole":
		pbr_asset = "corrugated_iron_03"
	elif key == "market_structure":
		pbr_asset = "rusty_metal_02"
	elif key == "market_structure_alt":
		pbr_asset = "rusty_metal_05"
	elif key in ["market_wood", "market_crate"]:
		pbr_asset = "rough_wood"
	if not pbr_asset.is_empty():
		_apply_market_pbr(material, pbr_asset)
	_materials[key] = material
	return material


func _apply_market_pbr(material: StandardMaterial3D, asset_id: String) -> void:
	var folder := "res://assets/textures/pbr/%s/" % asset_id
	var absolute_folder := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(absolute_folder):
		return
	for filename in DirAccess.get_files_at(absolute_folder):
		var base_name := filename.get_basename()
		var texture := load(folder + filename) as Texture2D
		if texture == null:
			continue
		if base_name.ends_with("_diff"):
			material.albedo_texture = texture
		elif base_name.ends_with("_nor_gl"):
			material.normal_enabled = true
			material.normal_texture = texture
			material.normal_scale = 0.72
		elif base_name.ends_with("_rough"):
			material.roughness_texture = texture
		elif base_name.ends_with("_ao"):
			material.ao_enabled = true
			material.ao_texture = texture
		elif base_name.ends_with("_metal"):
			material.metallic = 1.0
			material.metallic_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(1.4, 1.4, 1.0)


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _build_mont_bouet_market() -> void:
	var market := Node3D.new()
	market.name = "Marche_Mont_Bouet"
	market.position = _geo_to_world(MONT_BOUET_LAT, MONT_BOUET_LON)
	add_child(market)

	var concrete := _material("market_concrete", Color(0.48, 0.46, 0.40))
	var metal := _material("market_tole", Color(0.28, 0.31, 0.29), 0.72, 0.18)
	var dark_metal := _material("market_structure", Color(0.12, 0.14, 0.13), 0.68, 0.28)
	var weathered_metal := _material("market_structure_alt", Color(0.20, 0.17, 0.13), 0.76, 0.24)
	var wood := _material("market_wood", Color(0.36, 0.22, 0.12))
	var crate_material := _material("market_crate", Color(0.48, 0.31, 0.16))
	var fruit_red := _material("market_fruit_red", Color(0.72, 0.12, 0.07), 0.48)
	var fruit_green := _material("market_fruit_green", Color(0.25, 0.48, 0.12), 0.52)
	var fruit_yellow := _material("market_fruit_yellow", Color(0.92, 0.62, 0.12), 0.5)
	var awning_colors: Array[Color] = [
		Color(0.72, 0.17, 0.12), Color(0.12, 0.31, 0.22),
		Color(0.86, 0.66, 0.25), Color(0.16, 0.29, 0.48),
		Color(0.73, 0.70, 0.60), Color(0.42, 0.19, 0.13)
	]
	var awnings: Array[StandardMaterial3D] = []
	for index in range(awning_colors.size()):
		awnings.append(_material("market_awning_%d" % index, awning_colors[index], 0.82))

	# Un parvis irrégulier en latérite compactée, sans dalle continue qui masquerait les routes.
	_box(market, "Plateforme_entree_marche", Vector3(74.0, 0.12, 4.0), Vector3(0, 0.04, 43.0), concrete)
	_box(market, "Panneau_entree", Vector3(16.0, 0.42, 0.34), Vector3(0, 4.8, 45.5), dark_metal)
	var sign := Label3D.new()
	sign.name = "Enseigne_Marche_Mont_Bouet"
	sign.text = "MARCHÉ MONT-BOUËT"
	sign.font_size = 64
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 5.0, 45.28)
	sign.modulate = Color(1.0, 0.86, 0.58)
	sign.outline_size = 8
	sign.outline_modulate = Color(0.08, 0.09, 0.08)
	market.add_child(sign)

	# Trois halles ouvertes, avec allées traversantes et petites boutiques répétées.
	# Les bâches colorées, poteaux métalliques et comptoirs donnent une première lecture
	# de marché populaire gabonais ; les enseignes et marchandises seront détaillées ensuite.
	var stall_index := 0
	for row in range(3):
		var row_z := -22.0 + float(row) * 23.0
		for column in range(7):
			var x := -24.0 + float(column) * 8.0
			_build_market_stall(market, stall_index, Vector3(x, 0.0, row_z),
				awnings[stall_index % awnings.size()], metal, dark_metal, weathered_metal, wood,
				crate_material, fruit_red, fruit_green, fruit_yellow)
			stall_index += 1

	# Auvent longitudinal côté livraison : garde un espace dégagé pour les porteurs.
	_box(market, "Auvent_livraison", Vector3(62.0, 0.22, 5.0), Vector3(0, 4.0, -47.0), metal)
	for x in range(-30, 31, 10):
		_box(market, "Poteau_livraison_%d" % x, Vector3(0.16, 4.0, 0.16), Vector3(float(x), 2.0, -47.0), dark_metal)


func _build_market_stall(parent: Node3D, index: int, center: Vector3, awning: Material,
		roof_material: Material, frame_material: Material, alternate_frame_material: Material,
		wood: Material, crate_material: Material,
		fruit_red: Material, fruit_green: Material, fruit_yellow: Material) -> void:
	var stall := Node3D.new()
	stall.name = "Etal_%02d" % index
	stall.position = center
	parent.add_child(stall)

	# Comptoir ouvert vers l'allée, quatre poteaux et une toiture en tôle.
	# Quelques supports reçoivent une patine plus marquée, sans uniformiser la halle.
	var selected_frame_material := alternate_frame_material if index % 4 == 2 else frame_material
	_box(stall, "Comptoir", Vector3(5.2, 0.95, 1.0), Vector3(0, 0.48, 1.45), wood)
	_box(stall, "Facade_comptoir", Vector3(5.25, 0.18, 0.08), Vector3(0, 0.52, 0.91), crate_material)
	for side_x in [-2.45, 2.45]:
		for side_z in [-1.8, 1.8]:
			_box(stall, "Poteau", Vector3(0.13, 3.6, 0.13), Vector3(side_x, 1.8, side_z), selected_frame_material)
	_box(stall, "Tole_ondulee", Vector3(6.1, 0.18, 5.1), Vector3(0, 3.72, 0), roof_material)
	_box(stall, "Bache_facade", Vector3(5.8, 1.05, 0.12), Vector3(0, 2.92, -2.47), awning)
	_box(stall, "Bache_laterale", Vector3(0.12, 1.0, 4.7), Vector3(-3.02, 2.9, 0), awning)

	# Caisses empilées et paniers de produits simplifiés.
	for crate_index in range(2):
		var crate_x := -1.7 + float(crate_index) * 3.0
		_box(stall, "Caisse_%d" % crate_index, Vector3(1.0, 0.72, 0.86), Vector3(crate_x, 0.42, -1.25), crate_material)
	var fruit_materials: Array[Material] = [fruit_red, fruit_green, fruit_yellow]
	for fruit_index in range(3):
		var fruit := MeshInstance3D.new()
		fruit.name = "Produit_%d" % fruit_index
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		fruit.mesh = sphere
		fruit.material_override = fruit_materials[(index + fruit_index) % fruit_materials.size()]
		fruit.position = Vector3(-1.8 + float(fruit_index) * 0.55, 1.08, 1.1)
		stall.add_child(fruit)
	if index % 3 == 0:
		_add_market_vendor(stall, index)


func _add_market_vendor(parent: Node3D, index: int) -> void:
	var vendor := Node3D.new()
	vendor.name = "Vendeur_%02d" % index
	vendor.position = Vector3(0.0, 0.0, -0.65)
	vendor.set_script(preload("res://game/scripts/market_vendor.gd"))
	vendor.set("vendor_index", index)
	var interaction_body := StaticBody3D.new()
	interaction_body.name = "ZoneInteraction"
	var interaction_shape := CollisionShape3D.new()
	var interaction_capsule := CapsuleShape3D.new()
	interaction_capsule.radius = 0.42
	interaction_capsule.height = 1.9
	interaction_shape.shape = interaction_capsule
	interaction_shape.position = Vector3(0.0, 1.0, 0.0)
	interaction_body.add_child(interaction_shape)
	vendor.add_child(interaction_body)
	var skin_colors: Array[Color] = [Color(0.28, 0.16, 0.10), Color(0.42, 0.25, 0.16), Color(0.55, 0.34, 0.22)]
	var shirt_colors: Array[Color] = [Color(0.12, 0.30, 0.52), Color(0.66, 0.18, 0.12), Color(0.14, 0.38, 0.24), Color(0.78, 0.62, 0.20)]
	var skin := _material("vendor_skin_%d" % (index % skin_colors.size()), skin_colors[index % skin_colors.size()])
	var shirt := _material("vendor_shirt_%d" % (index % shirt_colors.size()), shirt_colors[index % shirt_colors.size()])
	var dark := _material("vendor_trousers", Color(0.12, 0.13, 0.15))
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.25
	torso_mesh.height = 0.92
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 1.22, 0)
	torso.material_override = shirt
	vendor.add_child(torso)
	var head := MeshInstance3D.new()
	head.name = "Tete"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.position = Vector3(0, 1.86, 0)
	head.material_override = skin
	vendor.add_child(head)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.105
		leg_mesh.height = 0.78
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.12, 0.42, 0)
		leg.material_override = dark
		vendor.add_child(leg)
		var arm := MeshInstance3D.new()
		arm.name = "BrasGauche" if side < 0.0 else "BrasDroit"
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.075
		arm_mesh.height = 0.68
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.31, 1.20, 0.16)
		arm.rotation.x = -0.45
		arm.material_override = skin
		vendor.add_child(arm)
	parent.add_child(vendor)
