extends Node3D
## Repères patrimoniaux du front de mer : monument Georges-Damas-Aleka et tribune officielle.
## Coordonnées monument issues d'OpenStreetMap/Mapcarta. La tribune est positionnée
## Les deux centroïdes sont lus dans les objets cartographiques OpenStreetMap.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const MONUMENT_LAT := 0.3879
const MONUMENT_LON := 9.44288
# Centroïde du toit de la tribune officielle (OSM way 1495944465).
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

	# Parvis principal : dalle claire, joints de dilatation et cheminement axial.
	_box(site, "Parvis_pierre_naturelle", Vector3(112.0, 0.32, 74.0), Vector3(0, 0.16, 0), _paving)
	_add_platform_collision(site, Vector3(112.0, 0.4, 74.0), Vector3(0, 0.2, 0))
	for x in range(-50, 51, 10):
		_box(site, "Joint_parvis_%d" % x, Vector3(0.045, 0.012, 72.0), Vector3(float(x), 0.33, 0), _dark)
	_box(site, "Socle_batiment", Vector3(39.0, 0.9, 22.0), Vector3(0, 0.62, 0), _stone)

	# Bâtiment photographié : deux grands jambages habillés de panneaux,
	# un large vide traversant et un couronnement rectangulaire vitré.
	_box(site, "Jambage_gauche_principal", Vector3(8.0, 27.5, 17.0), Vector3(-14.2, 14.5, 0), _white)
	_box(site, "Jambage_droit_principal", Vector3(8.0, 27.5, 17.0), Vector3(14.2, 14.5, 0), _white)
	_box(site, "Couronnement_superieur", Vector3(36.0, 8.0, 18.0), Vector3(0, 25.0, 0), _white)
	_box(site, "Bandeau_fenetre_haut", Vector3(25.5, 3.8, 0.34), Vector3(0, 27.0, 9.18), _glass)
	_box(site, "Bandeau_fenetre_milieu", Vector3(25.5, 3.8, 0.34), Vector3(0, 20.5, 9.18), _glass)
	_box(site, "Bandeau_sous_fenetre", Vector3(26.0, 0.35, 0.5), Vector3(0, 18.25, 9.0), _stone)
	_box(site, "Bandeau_superieur_fenetre", Vector3(26.0, 0.35, 0.5), Vector3(0, 29.15, 9.0), _stone)

	# Menuiseries en aluminium : trames verticales et traverses des vitrages.
	for row in range(2):
		var window_y := 20.5 + float(row) * 6.5
		for mullion in range(13):
			var mx := -12.0 + float(mullion) * 2.0
			_box(site, "Meneau_vitre_%d_%02d" % [row, mullion], Vector3(0.10, 3.7, 0.18), Vector3(mx, window_y, 9.42), _dark)
		_box(site, "Traverse_vitre_%d" % row, Vector3(25.5, 0.10, 0.18), Vector3(0, window_y, 9.42), _dark)

	# Façades latérales : joints de panneaux, fenêtres verticales et bandeaux.
	for side in [-1.0, 1.0]:
		for floor_index in range(1, 6):
			var fy := 3.0 + float(floor_index) * 4.0
			_box(site, "Joint_facade_%s_%d" % [str(side), floor_index], Vector3(0.035, 0.035, 16.8), Vector3(side * 18.24, fy, 0), _stone)
		for window_index in range(3):
			var wy := 8.0 + float(window_index) * 7.0
			_box(site, "Fenetre_laterale_%s_%d" % [str(side), window_index], Vector3(0.20, 3.8, 5.0), Vector3(side * 18.28, wy, -2.0), _glass)
			for frame_z in [-4.5, 0.5]:
				_box(site, "Cadre_lateral_%s_%d_%s" % [str(side), window_index, str(frame_z)], Vector3(0.24, 4.0, 0.12), Vector3(side * 18.42, wy, frame_z), _dark)

	# Grande ouverture traversante au rez-de-chaussée et piliers intérieurs.
	_box(site, "Plafond_passage", Vector3(20.0, 0.55, 16.0), Vector3(0, 8.2, 0), _stone)
	for side in [-1.0, 1.0]:
		_box(site, "Colonne_interieure_%s" % str(side), Vector3(1.2, 15.0, 1.2), Vector3(side * 8.6, 7.8, -4.0), _white)
		_box(site, "Socle_colonne_%s" % str(side), Vector3(1.8, 0.7, 1.8), Vector3(side * 8.6, 0.7, -4.0), _stone)
	# Vitrage du hall en retrait, pour garder la transparence du passage.
	_box(site, "Hall_musee_vitre_arriere", Vector3(15.5, 7.0, 0.22), Vector3(0, 4.3, 7.7), _glass)
	for mullion in range(8):
		var gx := -7.0 + float(mullion) * 2.0
		_box(site, "Meneau_hall_%02d" % mullion, Vector3(0.10, 6.8, 0.16), Vector3(gx, 4.3, 7.9), _dark)

	# Inscription institutionnelle dorée, armoiries stylisées et plaque mémorielle.
	_add_3d_text(site, "REPUBLIQUE GABONAISE", Vector3(0, 30.0, 9.55), 30, _gold)
	_add_3d_text(site, "UNION - TRAVAIL - JUSTICE", Vector3(0, 28.8, 9.55), 21, _gold)
	_add_3d_text(site, "LA CONCORDE", Vector3(0, 23.0, 9.58), 42, _gold)
	for side in [-1.0, 1.0]:
		_build_gabon_emblem(site, Vector3(side * 15.2, 29.0, 9.35))
		_build_province_shield(site, Vector3(side * 14.2, 13.0, 8.62), int(side))
	_box(site, "Stele_memorielle", Vector3(3.2, 5.2, 0.38), Vector3(0, 3.2, 8.65), _stone)
	_add_3d_text(site, "GEORGES DAMAS ALEKA", Vector3(0, 4.0, 8.9), 15, _gold)

	# Structure verticale secondaire au-dessus du couronnement, sans déformer
	# la silhouette du portail observée sur les photographies.
	_box(site, "Couronne_technique", Vector3(18.0, 1.0, 12.0), Vector3(0, 29.7, 0), _stone)
	for side in [-1.0, 1.0]:
		_box(site, "Aileron_superieur_%s" % str(side), Vector3(1.0, 5.5, 12.0), Vector3(side * 8.2, 32.7, 0), _white)
	_box(site, "Linteau_superieur_fin", Vector3(17.0, 1.0, 12.0), Vector3(0, 35.2, 0), _white)

	# Huit pavillons d'exposition périphériques (le bâtiment central représente l'Estuaire).
	var pavilion_positions: Array[Vector3] = [
		Vector3(-43, 0, -25), Vector3(-29, 0, -25), Vector3(-15, 0, -25), Vector3(15, 0, -25),
		Vector3(29, 0, -25), Vector3(43, 0, -25), Vector3(-22, 0, 25), Vector3(22, 0, 25)
	]
	for i in range(pavilion_positions.size()):
		_build_pavilion(site, i + 1, pavilion_positions[i])

	# Allée cérémonielle, bassins peu profonds et éclairage de mise en valeur.
	_box(site, "Axe_promenade", Vector3(8.0, 0.08, 62.0), Vector3(0, 0.36, -1.0), _white)
	for side in [-1.0, 1.0]:
		_box(site, "Bassin_reflet_%s" % str(side), Vector3(7.0, 0.16, 22.0), Vector3(side * 49.0, 0.40, 0), _glass)
		for lamp_index in range(5):
			var lz := -27.0 + float(lamp_index) * 13.5
			_cylinder(site, "Mât_eclairage_%s_%d" % [str(side), lamp_index], 0.10, 5.0, Vector3(side * 53.0, 2.8, lz), _dark, 12)
			_box(site, "Luminaire_%s_%d" % [str(side), lamp_index], Vector3(0.8, 0.22, 0.35), Vector3(side * 53.0, 5.4, lz), _gold)

	# Drapeaux gabonais devant le monument.
	for i in range(3):
		var flag_x := float(i - 1) * 4.0
		_cylinder(site, "Mât_drapeau_%d" % i, 0.07, 9.0, Vector3(flag_x, 4.8, -35.0), _dark, 12)
		_box(site, "Drapeau_%d" % i, Vector3(2.2, 1.25, 0.06), Vector3(flag_x + 1.1, 7.2, -35.0), _yellow)


func _build_pavilion(parent: Node3D, number: int, center: Vector3) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "Pavillon_province_%02d" % number
	pavilion.position = center
	parent.add_child(pavilion)
	_box(pavilion, "Socle_granit", Vector3(10.5, 0.55, 8.5), Vector3(0, 0.28, 0), _stone)
	_box(pavilion, "Volume_blanc", Vector3(9.8, 4.8, 7.8), Vector3(0, 2.85, 0), _white)
	_box(pavilion, "Toiture_debordante", Vector3(10.8, 0.42, 8.8), Vector3(0, 5.45, 0), _dark)
	_box(pavilion, "Bandeau_verre", Vector3(8.6, 2.0, 0.16), Vector3(0, 3.3, 3.98), _glass)
	for mullion in range(7):
		var px := -3.6 + float(mullion) * 1.2
		_box(pavilion, "Meneau_pavillon_%02d" % mullion, Vector3(0.08, 1.9, 0.12), Vector3(px, 3.3, 4.08), _dark)
	_box(pavilion, "Plaque_province", Vector3(5.6, 0.55, 0.18), Vector3(0, 4.65, 4.08), _gold)
	_add_3d_text(pavilion, "PAVILLON %02d" % number, Vector3(0, 4.55, 4.22), 12, _white)
	for side in [-1.0, 1.0]:
		_box(pavilion, "Pilastre_%s" % str(side), Vector3(0.22, 4.2, 0.28), Vector3(side * 4.65, 2.8, 4.0), _stone)


func _build_official_tribune() -> void:
	var site := Node3D.new()
	site.name = "Tribune_Officielle_Independance"
	site.position = _geo_to_world(TRIBUNE_LAT, TRIBUNE_LON)
	add_child(site)

	# Tribune monumentale jaune : gradins, allées rouges et assises vertes.
	_box(site, "Plateforme_beton", Vector3(82.0, 0.9, 34.0), Vector3(0, 0.45, 0), _stone)
	_add_platform_collision(site, Vector3(82.0, 1.0, 34.0), Vector3(0, 0.5, 0))
	for row in range(10):
		var rz := -13.0 + float(row) * 2.7
		var ry := 1.0 + float(row) * 0.42
		_box(site, "Marche_gradin_%02d" % row, Vector3(74.0, 0.42, 2.7), Vector3(0, ry, rz), _stone)
		_box(site, "Assise_gradin_%02d" % row, Vector3(71.0, 0.32, 1.9), Vector3(0, ry + 0.36, rz - 0.18), _dark)
	_box(site, "Alee_centrale_rouge", Vector3(4.2, 0.16, 28.0), Vector3(0, 1.2, 0), _gold)
	_box(site, "Estrade_officielle", Vector3(32.0, 1.0, 7.0), Vector3(0, 5.3, 10.0), _white)
	_box(site, "Face_estrade", Vector3(30.0, 1.2, 0.35), Vector3(0, 5.0, 13.55), _yellow)
	_box(site, "Moquette_protocolaire", Vector3(25.0, 0.08, 8.0), Vector3(0, 5.85, 10.0), _gold)

	# Façade arrière jaune avec panneaux verticaux et baies sombres.
	_box(site, "Facade_arriere_jaune", Vector3(80.0, 12.0, 1.2), Vector3(0, 8.0, -16.0), _yellow)
	for fin in range(41):
		var fx := -39.0 + float(fin) * 1.95
		_box(site, "Lame_facade_%02d" % fin, Vector3(0.22, 11.5, 0.34), Vector3(fx, 8.0, -15.25), _gold)
	for window_index in range(8):
		var wx := -32.0 + float(window_index) * 9.0
		_box(site, "Baie_facade_%02d" % window_index, Vector3(5.8, 2.6, 0.16), Vector3(wx, 5.0, -15.25), _glass)

	# Poteaux, poutres et charpente métallique apparente sous la couverture.
	for i in range(17):
		var px := -39.0 + float(i) * 4.875
		_cylinder(site, "Poteau_acier_%02d" % i, 0.24, 12.0, Vector3(px, 6.6, -1.0), _dark, 16)
		_box(site, "Console_poteau_%02d" % i, Vector3(0.7, 0.7, 1.0), Vector3(px, 11.5, -1.0), _yellow)
	for beam in range(9):
		var bz := -14.0 + float(beam) * 3.5
		_box(site, "Poutre_transversale_%02d" % beam, Vector3(80.0, 0.34, 0.38), Vector3(0, 12.3, bz), _dark)
	for brace in range(16):
		var bx := -38.0 + float(brace) * 5.0
		var beam := _box(site, "Contreventement_%02d" % brace, Vector3(0.22, 5.0, 0.22), Vector3(bx, 10.4, -1.0), _dark)
		beam.rotation.z = deg_to_rad(24.0 if brace % 2 == 0 else -24.0)

	# Couverture à dents de scie : alternance de panneaux et bandeaux de rive.
	_box(site, "Sous_face_toiture", Vector3(86.0, 0.55, 38.0), Vector3(0, 13.0, 0), _dark)
	for segment in range(16):
		var sx := -40.0 + float(segment) * 5.35
		var sy := 13.65 + (0.95 if segment % 2 == 0 else 0.0)
		var roof_panel := _box(site, "Panneau_toiture_%02d" % segment, Vector3(5.6, 0.38, 38.5), Vector3(sx, sy, 0), _yellow)
		roof_panel.rotation.z = deg_to_rad(3.0 if segment % 2 == 0 else -3.0)
		_box(site, "Nervure_toiture_%02d" % segment, Vector3(0.14, 0.5, 38.0), Vector3(sx + 2.7, sy + 0.18, 0), _dark)
	# Bande tricolore discrète sous l'avant de la couverture.
	for color_index in range(3):
		var stripe_color: Color = [Color(0.0, 0.42, 0.20), Color(0.96, 0.76, 0.10), Color(0.10, 0.26, 0.62)][color_index]
		var stripe_material := _mat(stripe_color, 0.72)
		_box(site, "Bandeau_national_%d" % color_index, Vector3(86.0, 0.16, 0.38), Vector3(0, 12.65, 18.8 + float(color_index) * 0.42), stripe_material)

	# Escaliers d'accès et rampes latérales.
	for side in [-1.0, 1.0]:
		for step in range(8):
			_box(site, "Marche_acces_%s_%d" % [str(side), step], Vector3(5.0, 0.24, 1.1), Vector3(side * 38.0, 1.0 + float(step) * 0.34, 13.0 - float(step) * 1.2), _stone)
		_cylinder(site, "Main_courante_%s" % str(side), 0.07, 12.0, Vector3(side * 40.5, 3.2, 8.0), _dark, 10)


func _add_3d_text(parent: Node3D, value: String, position: Vector3, font_size: int, material: Material) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = Color.WHITE
	label.outline_size = 4
	label.outline_modulate = Color(0.12, 0.12, 0.12)
	label.material_override = material
	parent.add_child(label)


func _build_gabon_emblem(parent: Node3D, position: Vector3) -> void:
	_box(parent, "Support_armoiries", Vector3(1.5, 1.8, 0.22), position, _gold)
	_box(parent, "Bande_armoiries_verte", Vector3(1.15, 0.42, 0.10), position + Vector3(0, 0.42, 0.16), _mat(Color(0.0, 0.42, 0.20), 0.72))
	_box(parent, "Bande_armoiries_jaune", Vector3(1.15, 0.42, 0.10), position + Vector3(0, 0, 0.16), _mat(Color(0.96, 0.76, 0.10), 0.72))
	_box(parent, "Bande_armoiries_bleue", Vector3(1.15, 0.42, 0.10), position + Vector3(0, -0.42, 0.16), _mat(Color(0.10, 0.26, 0.62), 0.72))


func _build_province_shield(parent: Node3D, position: Vector3, side: int) -> void:
	_box(parent, "Blason_province_%d" % side, Vector3(1.35, 1.65, 0.16), position, _gold)
	_box(parent, "Couleur_blason_%d" % side, Vector3(0.95, 1.1, 0.10), position + Vector3(0, 0, 0.12), _mat(Color(0.10, 0.36, 0.25), 0.7))


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
