extends Node3D
## Baie des Rois — kiosques GPS et mobilier 3D.
## Les modèles sont alignés sur le relief après la création des collisions DEM.

const ANCHOR := Vector3(-1790.0, 0.0, -570.0)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261117
	name = "BaieDesRois"
	_build_bay_water()
	_build_pavilions()
	_build_baie_street_props()
	# WorldMap construit le DEM de façon asynchrone. Ne pas placer les objets
	# avant que le relief proche existe, sinon ils restent au niveau zéro.
	await get_tree().process_frame
	var world_map := get_parent().get_node_or_null("WorldMap")
	if world_map != null and world_map.has_method("is_terrain_ready"):
		while not bool(world_map.call("is_terrain_ready")):
			await get_tree().process_frame
	_conform_baie_objects_to_terrain()
	print("LIBREVILLE STORIES | Baie des Rois : kiosques et mobilier 3D chargés et posés sur le terrain")


# ---------------------------------------------------------------------------
# Textures procédurales (style GTA : pas de couleur plate)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Textures procédurales (style GTA : pas de couleur plate)
# ---------------------------------------------------------------------------

func _tex_concrete() -> Texture2D:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(256):
		for x in range(256):
			var n := rng.randf()
			var base := 0.72 + n * 0.10
			var joint := ((x % 32) < 2) or ((y % 32) < 2)
			if joint:
				base *= 0.78
			base += ((x * 17 + y * 29) % 5) * 0.008
			img.set_pixel(x, y, Color(base * 0.98, base * 0.97, base * 0.92, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tex_grass() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in range(128):
		for x in range(128):
			var n := rng.randf()
			var g := 0.32 + n * 0.18
			var r := 0.18 + n * 0.08
			var b := 0.12 + n * 0.06
			if (x * 3 + y * 7) % 11 == 0:
				g *= 0.75
			img.set_pixel(x, y, Color(r, g, b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tex_wood() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var vein := sin(float(x) * 0.35 + float(y) * 0.02) * 0.06
			var base := 0.48 + vein + ((x + y * 3) % 7) * 0.01
			img.set_pixel(x, y, Color(base * 1.15, base * 0.78, base * 0.42, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tex_water() -> Texture2D:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for y in range(256):
		for x in range(256):
			var wave := sin(float(x) * 0.08) * cos(float(y) * 0.06) * 0.08
			var n := rng.randf() * 0.04
			var b := 0.52 + wave + n
			var g := 0.38 + wave * 0.6 + n
			var r := 0.08 + wave * 0.3
			img.set_pixel(x, y, Color(r, g, b, 0.88))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tex_sand() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for y in range(128):
		for x in range(128):
			var n := rng.randf()
			var base := 0.78 + n * 0.12
			img.set_pixel(x, y, Color(base, base * 0.90, base * 0.68, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tex_rock() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for y in range(64):
		for x in range(64):
			var n := rng.randf()
			var s := 0.30 + n * 0.18
			img.set_pixel(x, y, Color(s, s * 0.98, s * 0.94, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_mat(color: Color, roughness: float = 0.9, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(1, 1, 1)
	return m


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, nm: String = "Box") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Eau de la baie — forme courbe côté océan
# ---------------------------------------------------------------------------

func _build_bay_water() -> void:
	# La promenade est côté terre ; l'océan se trouve au-delà du bord aménagé.
	# Les surfaces sont placées légèrement au-dessus du sol mondial (y=0),
	# car l'ancien niveau négatif était entièrement masqué par le grand plan Ground.
	var root := Node3D.new()
	root.name = "BayWater"
	add_child(root)

	var water_shader := load("res://game/shaders/ocean_water.gdshader") as Shader
	if water_shader == null:
		push_error("Shader océan introuvable : res://game/shaders/ocean_water.gdshader")
		return
	var water_mat := ShaderMaterial.new()
	water_mat.shader = water_shader

	# Quatre nappes séparées évitent de couvrir toute la promenade.
	# Le bord côté terre est recouvert par l'enrochement collisionné.
	_add_water_surface(root, Vector2(270.0, 320.0), ANCHOR + Vector3(185.0, 0.055, 0.0), water_mat, "OceanMain")
	_add_water_surface(root, Vector2(46.0, 178.0), ANCHOR + Vector3(73.0, 0.058, -8.0), water_mat, "BayNorthArm")
	_add_water_surface(root, Vector2(58.0, 76.0), ANCHOR + Vector3(82.0, 0.060, -91.0), water_mat, "BaySouthArm")
	_add_water_surface(root, Vector2(58.0, 76.0), ANCHOR + Vector3(82.0, 0.060, 91.0), water_mat, "BayNorthInlet")


func _add_water_surface(parent: Node3D, dimensions: Vector2, world_position: Vector3, material: Material, node_name: String) -> void:
	var water := MeshInstance3D.new()
	water.name = node_name
	var plane := PlaneMesh.new()
	plane.size = dimensions
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	water.mesh = plane
	water.material_override = material
	water.position = world_position
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(water)


func _build_promenade() -> void:
	var mat := _make_mat(Color(0.88, 0.86, 0.80), 0.82, _tex_concrete())
	mat.uv1_scale = Vector3(0.08, 0.08, 1)
	var root := Node3D.new()
	root.name = "Promenade"
	add_child(root)
	_add_box(root, Vector3(48, 0.20, 200), ANCHOR + Vector3(0, 0.10, 0), mat, "Esplanade")
	_add_box(root, Vector3(14, 0.18, 100), ANCHOR + Vector3(22, 0.09, -15), mat, "AlleeEst")
	_add_box(root, Vector3(100, 0.18, 12), ANCHOR + Vector3(-8, 0.09, 45), mat, "AlleeNord")
	_add_box(root, Vector3(80, 0.18, 12), ANCHOR + Vector3(2, 0.09, -60), mat, "AlleeSud")
	_add_box(root, Vector3(36, 0.19, 36), ANCHOR + Vector3(-8, 0.10, 8), mat, "PlaceDome")


func _build_lawns() -> void:
	var grass := _make_mat(Color(0.55, 0.75, 0.40), 0.95, _tex_grass())
	grass.uv1_scale = Vector3(0.15, 0.15, 1)
	var root := Node3D.new()
	root.name = "Lawns"
	add_child(root)
	var patches: Array[Vector3] = [
		Vector3(20, 0.08, 24), Vector3(-14, 0, -28),
		Vector3(16, 0.08, 20), Vector3(18, 0, 32),
		Vector3(22, 0.08, 18), Vector3(-20, 0, 18),
		Vector3(14, 0.08, 30), Vector3(6, 0, -75),
		Vector3(18, 0.08, 16), Vector3(22, 0, -42),
		Vector3(12, 0.08, 22), Vector3(-24, 0, -55),
		Vector3(15, 0.08, 15), Vector3(-5, 0, 55),
	]
	for i in range(0, patches.size(), 2):
		var size: Vector3 = patches[i]
		var offset: Vector3 = patches[i + 1]
		_add_box(root, size, ANCHOR + offset + Vector3(0, 0.04, 0), grass, "Lawn_%d" % (i / 2))


func _conform_baie_objects_to_terrain() -> void:
	var world_map := get_parent().get_node_or_null("WorldMap")
	if world_map == null or not world_map.has_method("terrain_height_at_world"):
		push_warning("DEM non disponible pour ajuster les objets de la Baie des Rois.")
		return

	for container in get_children():
		if not (container is Node3D):
			continue
		for asset_root in container.get_children():
			if not (asset_root is Node3D):
				continue
			var root_3d := asset_root as Node3D
			var ground_y := float(world_map.call("terrain_height_at_world", root_3d.global_position.x, root_3d.global_position.z))
			var lowest_y := _lowest_visual_world_y(root_3d)
			if is_finite(lowest_y):
				root_3d.global_position.y += ground_y - lowest_y + 0.025
			else:
				root_3d.global_position.y = ground_y + 0.025
	print("LIBREVILLE STORIES | mobilier et kiosques alignés par leur base réelle sur le relief SRTM")


func _lowest_visual_world_y(root: Node3D) -> float:
	var lowest_y := INF
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is VisualInstance3D:
			var visual := current as VisualInstance3D
			var bounds := visual.get_aabb()
			if bounds.size.length_squared() > 0.000001:
				for corner_index in range(8):
					var corner := Vector3(
						bounds.position.x + (bounds.size.x if (corner_index & 1) != 0 else 0.0),
						bounds.position.y + (bounds.size.y if (corner_index & 2) != 0 else 0.0),
						bounds.position.z + (bounds.size.z if (corner_index & 4) != 0 else 0.0)
					)
					lowest_y = minf(lowest_y, visual.to_global(corner).y)
		for child in current.get_children():
			pending.append(child)
	return lowest_y


func _build_pavilions() -> void:
	const TYPE_A_PATH := "res://assets/models/baie_des_rois/kiosque_baie_des_rois.glb"
	const TYPE_B_PATH := "res://assets/models/baie_des_rois/kiosque_baie_des_rois_type_b.glb"
	if not ResourceLoader.exists(TYPE_A_PATH) or not ResourceLoader.exists(TYPE_B_PATH):
		push_error("Les deux modèles de kiosques sont requis. Générer les fichiers GLB A et B avec les scripts Blender.")
		return

	var type_a := load(TYPE_A_PATH) as PackedScene
	var type_b := load(TYPE_B_PATH) as PackedScene
	if type_a == null or type_b == null:
		push_error("Impossible de charger les deux modèles GLB de la Baie des Rois.")
		return

	# Implantation GPS : quatre kiosques par rangée sur l'axe mesuré de 101,07 m.
	# Les centres sont répartis régulièrement, en gardant une marge aux extrémités.
	# La rangée A est reculée de 6,5 m et la rangée B de 4,5 m.
	# Le calcul utilise le gabarit routier du jeu ; vérifier les limites réelles dans Godot.
	# Les deux ouvertures se font face sur le passage client central.
	const PROGRESS_VALUES: Array[float] = [0.08, 0.36, 0.64, 0.92]
	# Les façades commerciales sont orientées vers le passage central.
	# Les GLB présentent leur ouverture sur l'axe opposé à l'ancienne hypothèse :
	# on inverse les deux rotations pour que les deux comptoirs se regardent.
	const ROW_A_YAW := 0.0850
	const ROW_B_YAW := -3.0567

	var root := Node3D.new()
	root.name = "Kiosques3D_GPS"
	add_child(root)

	for i in range(PROGRESS_VALUES.size()):
		var progress: float = PROGRESS_VALUES[i]
		# Le premier kiosque déjà validé reste inchangé. Les sept autres reprennent
		# le volume bois à toiture plate/verte visible sur les photos de la promenade.
		var kiosk_a_scene: PackedScene = type_a if i == 0 else type_b
		var kiosk_a := kiosk_a_scene.instantiate() as Node3D
		if kiosk_a != null:
			kiosk_a.name = "Kiosque_%s_RangeeA_%02d" % ["TypeA" if i == 0 else "TypeB", i + 1]
			kiosk_a.position = BaieDesRoisSurvey.row_a_position(progress)
			kiosk_a.rotation.y = ROW_A_YAW
			kiosk_a.scale = Vector3.ONE
			root.add_child(kiosk_a)

		var kiosk_b := type_b.instantiate() as Node3D
		if kiosk_b != null:
			kiosk_b.name = "Kiosque_TypeB_RangeeB_%02d" % (i + 1)
			kiosk_b.position = BaieDesRoisSurvey.row_b_position(progress)
			kiosk_b.rotation.y = ROW_B_YAW
			kiosk_b.scale = Vector3.ONE
			root.add_child(kiosk_b)

	print("LIBREVILLE STORIES | %d kiosques GPS instanciés : recul A %.1f m / B %.1f m" % [root.get_child_count(), BaieDesRoisSurvey.ROW_A_OUTWARD_SETBACK_METERS, BaieDesRoisSurvey.ROW_B_OUTWARD_SETBACK_METERS])


func _build_baie_street_props() -> void:
	var props := BaieDesRoisPropsPlacement.new()
	add_child(props)

func _build_amphitheater() -> void:
	var root := Node3D.new()
	root.name = "Amphitheater"
	add_child(root)
	var center: Vector3 = ANCHOR + Vector3(-6, 0, 6)
	var base_mat := _make_mat(Color(0.85, 0.83, 0.78), 0.85, _tex_concrete())
	base_mat.uv1_scale = Vector3(0.1, 0.1, 1)
	_add_box(root, Vector3(24, 0.45, 24), center + Vector3(0, 0.22, 0), base_mat, "DomeBase")
	var shell := _make_mat(Color(0.16, 0.20, 0.26), 0.40)
	_add_box(root, Vector3(19, 4.0, 17), center + Vector3(0, 2.5, 0), shell, "DomeShell")
	var wood_inner := _make_mat(Color(0.85, 0.62, 0.35), 0.68, _tex_wood())
	wood_inner.uv1_scale = Vector3(0.3, 0.3, 1)
	_add_box(root, Vector3(15, 3.2, 13), center + Vector3(0, 2.0, 1.8), wood_inner, "DomeInner")
	var rim := _make_mat(Color(0.92, 0.90, 0.84), 0.75)
	_add_box(root, Vector3(13, 0.4, 1.4), center + Vector3(0, 0.55, 10), rim, "DomeRim")


func _build_palm_rows() -> void:
	var root := Node3D.new()
	root.name = "Palms"
	add_child(root)
	var trunk_mat := _make_mat(Color(0.55, 0.40, 0.22), 0.88, _tex_wood())
	trunk_mat.uv1_scale = Vector3(0.5, 0.2, 1)
	var leaf_mat := _make_mat(Color(0.25, 0.48, 0.20), 0.80, _tex_grass())
	leaf_mat.uv1_scale = Vector3(0.3, 0.3, 1)
	for row in range(3):
		var z0: float = -90.0 + float(row) * 60.0
		for i in range(12):
			var x: float = -24.0 + float(row) * 9.0 + float(i % 2) * 3.5
			var z: float = z0 + float(i) * 9.0 + _rng.randf_range(-1.8, 1.8)
			var p: Vector3 = ANCHOR + Vector3(x, 0, z)
			var h: float = _rng.randf_range(6.0, 9.5)
			_add_box(root, Vector3(0.40, h, 0.40), p + Vector3(0, h * 0.5, 0), trunk_mat, "PalmTrunk_%d_%d" % [row, i])
			_add_box(root, Vector3(3.6, 0.9, 3.6), p + Vector3(0, h + 0.35, 0), leaf_mat, "PalmCrown_%d_%d" % [row, i])
			_add_box(root, Vector3(4.5, 0.40, 1.3), p + Vector3(0, h + 0.55, 0), leaf_mat, "PalmFrond_%d_%d" % [row, i])


func _build_sand_zones() -> void:
	var sand := _make_mat(Color(0.92, 0.84, 0.62), 0.95, _tex_sand())
	sand.uv1_scale = Vector3(0.12, 0.12, 1)
	var root := Node3D.new()
	root.name = "Sand"
	add_child(root)
	_add_box(root, Vector3(32, 0.14, 40), ANCHOR + Vector3(28, 0.07, -22), sand, "Beach1")
	_add_box(root, Vector3(24, 0.14, 26), ANCHOR + Vector3(30, 0.07, 42), sand, "Beach2")
	_add_box(root, Vector3(20, 0.14, 18), ANCHOR + Vector3(26, 0.07, -70), sand, "Beach3")


func _build_coastal_edge() -> void:
	var rock := _make_mat(Color(0.55, 0.54, 0.50), 0.92, _tex_rock())
	rock.uv1_scale = Vector3(0.3, 0.3, 1)
	var root := Node3D.new()
	root.name = "CoastEdge"
	add_child(root)

	# Enrochements visibles et collisionnés : ils matérialisent la limite
	# praticable entre l'esplanade et la mer. Le sol mondial reste sous l'eau,
	# mais le joueur ne peut plus traverser librement cette bordure.
	var collision_root := StaticBody3D.new()
	collision_root.name = "CoastalCollision"
	collision_root.collision_layer = 1
	collision_root.collision_mask = 1
	root.add_child(collision_root)

	var segment_count: int = 24
	var coast_start_z: float = -115.0
	var coast_length: float = 230.0
	for i in range(segment_count):
		var t: float = float(i) / float(segment_count - 1)
		var z: float = coast_start_z + t * coast_length
		var x_curve: float = 38.0 + sin(t * PI) * 12.0
		var width: float = 6.8
		var segment_length: float = coast_length / float(segment_count - 1) + 0.35
		var x_offset: float = sin(float(i) * 12.9898) * 0.45
		var position := ANCHOR + Vector3(x_curve + x_offset, 0.52, z)
		_add_box(root, Vector3(width, 1.35, segment_length), position, rock, "Riprap_%d" % i)

		var collision := CollisionShape3D.new()
		collision.name = "RiprapCollision_%d" % i
		var shape := BoxShape3D.new()
		# Plus haut que la hauteur de saut du personnage : la barrière ne
		# peut pas être franchie simplement en sautant depuis la promenade.
		shape.size = Vector3(width, 2.65, segment_length)
		collision.shape = shape
		collision.position = position + Vector3(0.0, 0.65, 0.0)
		collision_root.add_child(collision)


func _build_street_furniture() -> void:
	var metal := _make_mat(Color(0.35, 0.36, 0.38), 0.45)
	var wood := _make_mat(Color(0.55, 0.40, 0.22), 0.8, _tex_wood())
	var light := _make_mat(Color(0.95, 0.92, 0.80), 0.3)
	var root := Node3D.new()
	root.name = "Furniture"
	add_child(root)
	for i in range(14):
		var z: float = -85.0 + float(i) * 13.0
		var p: Vector3 = ANCHOR + Vector3(-18.0, 0, z)
		_add_box(root, Vector3(0.18, 5.5, 0.18), p + Vector3(0, 2.75, 0), metal, "LampPole_%d" % i)
		_add_box(root, Vector3(0.9, 0.25, 0.5), p + Vector3(0.2, 5.5, 0), metal, "LampHead_%d" % i)
		_add_box(root, Vector3(0.6, 0.15, 0.35), p + Vector3(0.2, 5.35, 0), light, "LampGlow_%d" % i)
	for i in range(8):
		var z: float = -70.0 + float(i) * 20.0
		var p: Vector3 = ANCHOR + Vector3(-12.0, 0, z)
		_add_box(root, Vector3(1.8, 0.12, 0.55), p + Vector3(0, 0.45, 0), wood, "BenchSeat_%d" % i)
		_add_box(root, Vector3(1.8, 0.45, 0.12), p + Vector3(0, 0.70, -0.25), wood, "BenchBack_%d" % i)
		_add_box(root, Vector3(0.12, 0.42, 0.45), p + Vector3(-0.75, 0.21, 0), metal, "BenchLegL_%d" % i)
		_add_box(root, Vector3(0.12, 0.42, 0.45), p + Vector3(0.75, 0.21, 0), metal, "BenchLegR_%d" % i)
