extends Node3D
## Repères patrimoniaux du front de mer : monument Georges-Damas-Aleka et tribune officielle.
## Coordonnées monument issues d'OpenStreetMap/Mapcarta. La tribune est positionnée
## en vis-à-vis à partir du plan de situation public ; son centroïde reste à affiner
## avec un relevé cadastral ou une orthophoto géoréférencée.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const MONUMENT_LAT := 0.3879
const MONUMENT_LON := 9.44288
# Position indicative de la tribune sur le côté opposé de l'esplanade.
# Elle est volontairement isolée ici pour pouvoir être corrigée sans toucher au modèle.
const TRIBUNE_LAT := 0.38831
const TRIBUNE_LON := 9.44356

var _stone: StandardMaterial3D
var _white: StandardMaterial3D
var _gold: StandardMaterial3D
var _roof: StandardMaterial3D
var _glass: StandardMaterial3D
var _dark: StandardMaterial3D
var _paving: StandardMaterial3D
var _yellow: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_build_monument()
	_build_official_tribune()
	print("LIBREVILLE STORIES | repères du front de mer : monument Georges-Damas-Aleka + tribune officielle")


func _make_materials() -> void:
	_stone = _mat(Color(0.82, 0.79, 0.70), 0.88)
	_white = _mat(Color(0.91, 0.90, 0.84), 0.82)
	_gold = _mat(Color(0.73, 0.57, 0.27), 0.48, 0.28)
	_roof = _mat(Color(0.78, 0.68, 0.43), 0.56, 0.18)
	_glass = _mat(Color(0.12, 0.25, 0.31), 0.22, 0.35)
	_dark = _mat(Color(0.16, 0.18, 0.18), 0.8)
	_paving = _mat(Color(0.66, 0.63, 0.56), 0.95)
	_yellow = _mat(Color(0.88, 0.62, 0.12), 0.62, 0.12)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _geo_to_world(latitude: float, longitude: float) -> Vector3:
	var x := (longitude - CENTER_LON) * METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT))
	var z := (CENTER_LAT - latitude) * METERS_PER_DEG_LAT
	var y := 0.0
	var world_map := get_parent().get_node_or_null("WorldMap")
	if world_map != null and world_map.has_method("terrain_height_at_world"):
		y = world_map.terrain_height_at_world(x, z)
	return Vector3(x, y, z)


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, radial_segments: int = 16) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_monument() -> void:
	var site := Node3D.new()
	site.name = "Monument_Georges_Damas_Aleka"
	site.position = _geo_to_world(MONUMENT_LAT, MONUMENT_LON)
	add_child(site)

	# Esplanade et socle du bâtiment principal.
	_box(site, "Esplanade_pierre", Vector3(92.0, 0.28, 58.0), Vector3(0, 0.12, 0), _paving)
	_add_platform_collision(site, Vector3(92.0, 0.35, 58.0), Vector3(0, 0.17, 0))
	_box(site, "Socle_arc", Vector3(34.0, 1.1, 19.0), Vector3(0, 0.68, 0), _white)

	# Arc monumental : deux piles épaisses, une traverse haute et un vide central.
	_box(site, "Pile_gauche", Vector3(5.0, 29.0, 7.0), Vector3(-11.0, 15.2, 0), _stone)
	_box(site, "Pile_droite", Vector3(5.0, 29.0, 7.0), Vector3(11.0, 15.2, 0), _stone)
	_box(site, "Linteau_superieur", Vector3(27.0, 5.0, 8.0), Vector3(0, 28.0, 0), _white)
	_box(site, "Corniche_frontale", Vector3(29.0, 0.7, 8.8), Vector3(0, 30.5, 0), _gold)
	_box(site, "Couronnement", Vector3(24.0, 1.0, 7.5), Vector3(0, 31.25, 0), _stone)
	_box(site, "Plaque_memorielle", Vector3(7.0, 2.2, 0.28), Vector3(0, 3.4, 3.72), _gold)
	_add_memorial_title(site)

	# Décrochements et nervures de façade qui donnent de la profondeur à l'arc.
	for side in [-1.0, 1.0]:
		for level in range(5):
			var y := 5.0 + float(level) * 5.2
			_box(site, "Nervure_%s_%02d" % [str(side), level], Vector3(0.38, 4.2, 7.35), Vector3(side * 8.4, y, 0), _white)
		_box(site, "Panneau_pilier_%s" % str(side), Vector3(2.8, 17.0, 0.22), Vector3(side * 11.0, 15.0, -3.62), _gold)

	# Ouverture centrale vitrée et bandeaux de niveaux du musée.
	_box(site, "Fond_vitre_musee", Vector3(11.5, 18.0, 0.32), Vector3(0, 14.0, 3.48), _glass)
	for level in range(1, 6):
		_box(site, "Bandeau_musee_%d" % level, Vector3(12.0, 0.24, 0.5), Vector3(0, 5.0 + float(level) * 3.0, 3.25), _gold)

	# Élément vertical supérieur : silhouette emblématique visible de loin.
	_box(site, "Tour_superieure", Vector3(5.2, 31.0, 5.2), Vector3(0, 46.0, 0), _stone)
	_box(site, "Noyau_tour_vitre", Vector3(3.3, 25.0, 3.5), Vector3(0, 46.0, 2.72), _glass)
	_box(site, "Aiguille_sommitale", Vector3(1.1, 5.0, 1.1), Vector3(0, 64.0, 0), _gold)
	_box(site, "Plateforme_tour", Vector3(8.0, 0.8, 8.0), Vector3(0, 62.0, 0), _white)

	# Neuf pavillons bas, répartis de part et d'autre de l'axe de promenade.
	var pavilion_positions: Array[Vector3] = [
		Vector3(-34, 0, -20), Vector3(-22, 0, -20), Vector3(-10, 0, -20),
		Vector3(10, 0, -20), Vector3(22, 0, -20), Vector3(34, 0, -20),
		Vector3(-24, 0, 20), Vector3(0, 0, 20), Vector3(24, 0, 20)
	]
	for i in range(pavilion_positions.size()):
		_build_pavilion(site, i + 1, pavilion_positions[i])

	# Mâts et drapeaux gabonais stylisés à l'entrée.
	for i in range(3):
		var x := float(i - 1) * 3.0
		_cylinder(site, "Mât_%d" % i, 0.09, 8.0, Vector3(x, 4.2, -27.0), _gold, 10)
		_box(site, "Drapeau_%d" % i, Vector3(1.5, 0.85, 0.06), Vector3(x + 0.8, 6.7, -27.0), [ _mat(Color(0.0,0.48,0.22),0.8), _mat(Color(0.96,0.78,0.12),0.8), _mat(Color(0.10,0.28,0.68),0.8) ][i])


func _build_pavilion(parent: Node3D, number: int, center: Vector3) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "Pavillon_province_%02d" % number
	pavilion.position = center
	parent.add_child(pavilion)
	_box(pavilion, "Volume_principal", Vector3(9.0, 4.8, 7.0), Vector3(0, 2.5, 0), _white)
	_box(pavilion, "Socle", Vector3(9.6, 0.45, 7.6), Vector3(0, 0.25, 0), _stone)
	_box(pavilion, "Toiture", Vector3(10.0, 0.55, 8.0), Vector3(0, 5.15, 0), _roof)
	_box(pavilion, "Vitrine", Vector3(5.5, 2.6, 0.12), Vector3(0, 2.8, -3.56), _glass)
	_box(pavilion, "Panneau_nom", Vector3(5.8, 0.65, 0.18), Vector3(0, 4.0, -3.68), _gold)


func _build_official_tribune() -> void:
	var site := Node3D.new()
	site.name = "Tribune_Officielle_Independance"
	site.position = _geo_to_world(TRIBUNE_LAT, TRIBUNE_LON)
	add_child(site)

	# Plateforme allongée et gradins en trois niveaux.
	_box(site, "Dalle_tribune", Vector3(72.0, 0.8, 25.0), Vector3(0, 0.4, 0), _dark)
	_add_platform_collision(site, Vector3(72.0, 0.9, 25.0), Vector3(0, 0.45, 0))
	for row in range(3):
		var depth := 6.0 + float(row) * 5.2
		var height := 1.2 + float(row) * 1.35
		_box(site, "Gradin_%d" % row, Vector3(62.0, height, 5.5), Vector3(0, 0.8 + height * 0.5, -8.0 + float(row) * 5.0), _stone)

	# Estrade centrale réservée aux autorités.
	_box(site, "Estrade_officielle", Vector3(25.0, 2.0, 5.0), Vector3(0, 3.1, 6.0), _white)
	_box(site, "Façade_estrade", Vector3(21.0, 1.2, 0.25), Vector3(0, 2.4, 8.55), _gold)
	for i in range(11):
		var x := -27.0 + float(i) * 5.4
		_cylinder(site, "Poteau_%02d" % i, 0.22, 9.0, Vector3(x, 5.0, 0), _white, 12)

	# Toiture couverte à profil ondulé/zigzag, caractéristique de la tribune.
	_box(site, "Toit_support", Vector3(76.0, 0.7, 29.0), Vector3(0, 10.0, 0), _dark)
	for segment in range(12):
		var x := -35.0 + float(segment) * 6.35
		var y := 10.7 + (1.15 if segment % 2 == 0 else 0.0)
		var panel := _box(site, "Toit_zigzag_%02d" % segment, Vector3(6.5, 0.32, 29.5), Vector3(x, y, 0), _dark)
		panel.rotation.z = deg_to_rad(4.5 if segment % 2 == 0 else -4.5)
		# Nervures métalliques du toit, visibles depuis le boulevard.
		_box(site, "Bord_toit_%02d" % segment, Vector3(0.16, 0.42, 29.2), Vector3(x + 3.1, y + 0.12, 0), _yellow)
	for i in range(8):
		var x := -28.0 + float(i) * 8.0
		_box(site, "Bandeau_façade_%d" % i, Vector3(0.18, 1.1, 0.35), Vector3(x, 8.9, 14.5), _gold)

	# Escaliers d'accès latéraux.
	for side in [-1.0, 1.0]:
		for step in range(5):
			_box(site, "Marche_%s_%d" % [str(side), step], Vector3(5.0, 0.28, 1.3), Vector3(side * 33.0, 0.5 + float(step) * 0.32, 10.0 - float(step) * 1.5), _white)


func _add_platform_collision(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision_plateforme"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = position
	body.add_child(shape_node)
	parent.add_child(body)


func _add_memorial_title(parent: Node3D) -> void:
	var title := Label3D.new()
	title.name = "Inscription_Georges_Damas_Aleka"
	title.text = "GEORGES DAMAS ALEKA\nLA CONCORDE"
	title.font_size = 48
	title.pixel_size = 0.012
	title.modulate = Color(0.96, 0.91, 0.76)
	title.position = Vector3(0, 3.35, 3.9)
	title.rotation_degrees = Vector3(0, 180, 0)
	title.outline_size = 8
	title.outline_modulate = Color(0.12, 0.12, 0.12)
	parent.add_child(title)
