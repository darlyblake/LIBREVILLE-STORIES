extends Node3D
## Ville 3D légère depuis les géométries OpenStreetMap.
## Les meshes sont découpés en lots pour limiter les pics mémoire et les draw calls.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const BUILDING_LIMIT := 60000
const BUILDINGS_PER_MESH := 1200
const ROADS_PER_MESH := 700
const MAX_ROAD_LABELS := 250
const MAX_POI_LABELS := 450
const DEM_META_PATH := "res://libreville_dem.json"
const DEM_BINARY_PATH := "res://libreville_dem_f32.bin"
const TERRAIN_CHUNK_CELLS := 32
const TERRAIN_VERTICAL_EXAGGERATION := 1.0

@export var show_roads := true
@export var show_buildings := true

var _road_count := 0
var _building_count := 0
var _poi_count := 0
var _environment_count := 0
var _neighbourhood_count := 0
var _locality_count := 0
var _grass_generator: GrassGenerator
var _environment_material: StandardMaterial3D
var _road_labels := 0
var _road_material: StandardMaterial3D
var _building_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _facade_detail_material: StandardMaterial3D
var _locality_points: Array[Dictionary] = []
var _location_hud: Label
var _location_refresh := 0.0
var _dem_heights := PackedFloat32Array()
var _dem_rows := 0
var _dem_columns := 0
var _dem_spacing := 30.0
var _dem_x_min := 0.0
var _dem_z_min := 0.0
var _dem_loaded := false

func _ready() -> void:
	_load_real_terrain()
	_disable_flat_ground()
	_apply_ground_surface()
	_add_ocean_plane()
	_road_material = _make_material(Color.WHITE)
	_road_material.vertex_color_use_as_albedo = true
	_road_material.albedo_texture = _make_asphalt_texture()
	_road_material.roughness = 0.88
	_road_material.uv1_scale = Vector3(1.0, 1.0, 1.0)
	_environment_material = _make_material(Color.WHITE)
	_environment_material.vertex_color_use_as_albedo = true
	_grass_generator = GrassGenerator.new()
	_grass_generator.name = "Procedural_Real_Grass"
	add_child(_grass_generator)
	_load_environment()
	_grass_generator.build()
	_load_neighbourhoods()
	_load_localities()
	_building_material = _make_material(Color(0.76, 0.68, 0.56))
	# Les couleurs attribuées aux bâtiments par type/OSM ID doivent être visibles.
	_building_material.vertex_color_use_as_albedo = true
	_roof_material = _make_material(Color.WHITE)
	_roof_material.vertex_color_use_as_albedo = true
	_roof_material.albedo_texture = _make_roof_tile_texture()
	_roof_material.roughness = 0.78
	_roof_material.metallic = 0.08
	_facade_detail_material = _make_material(Color.WHITE)
	_facade_detail_material.vertex_color_use_as_albedo = true
	_facade_detail_material.roughness = 0.85
	if show_roads:
		_load_roads()
	if show_buildings:
		_load_buildings()
	_load_pois()
	_position_player_on_terrain()
	_create_location_hud()
	print("LIBREVILLE STORIES | routes: %d | bâtiments: %d | lieux identifiables: %d | éléments environnementaux: %d" % [_road_count, _building_count, _poi_count, _environment_count])


func _process(delta: float) -> void:
	_location_refresh += delta
	if _location_refresh < 0.35:
		return
	_location_refresh = 0.0
	_update_location_hud()


func _create_location_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NavigationHUD"
	layer.layer = 5
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "PositionPanel"
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(310, 0)
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	_location_hud = Label.new()
	_location_hud.name = "CurrentLocation"
	_location_hud.text = "Localisation..."
	_location_hud.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_location_hud.add_theme_font_size_override("font_size", 15)
	margin.add_child(_location_hud)


func _update_location_hud() -> void:
	if _location_hud == null:
		return
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		_location_hud.text = "LIBREVILLE  |  joueur introuvable"
		return
	var position := player.global_position
	var latitude := CENTER_LAT - position.z / METERS_PER_DEG_LAT
	var longitude := CENTER_LON + position.x / (METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT)))
	var nearest_name := "Localité non renseignée"
	var nearest_distance := INF
	for locality in _locality_points:
		var distance: float = Vector2(position.x, position.z).distance_to(locality.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_name = str(locality.name)
	var location_line := nearest_name
	if nearest_distance < 2500.0:
		location_line += "  ·  %.0f m" % nearest_distance
	else:
		location_line = "Hors des localités nommées OSM"
	_location_hud.text = "%s\n%.4f  ·  %.4f" % [location_line, latitude, longitude]

func _disable_flat_ground() -> void:
	# Le grand plan horizontal de main.tscn masquerait le relief réel et
	# conserverait une collision plane sous les zones en contrebas.
	var ground := get_parent().get_node_or_null("Ground") as StaticBody3D
	if ground != null:
		ground.visible = false
		var collision := ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.disabled = true


func _load_real_terrain() -> void:
	if not FileAccess.file_exists(DEM_META_PATH) or not FileAccess.file_exists(DEM_BINARY_PATH):
		push_warning("DEM Libreville absent : terrain plat de secours conservé.")
		return
	var meta_file := FileAccess.open(DEM_META_PATH, FileAccess.READ)
	if meta_file == null:
		push_warning("Impossible de lire les métadonnées du DEM.")
		return
	var parsed: Variant = JSON.parse_string(meta_file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Métadonnées DEM invalides.")
		return
	var meta: Dictionary = parsed
	_dem_rows = int(meta.get("rows", 0))
	_dem_columns = int(meta.get("columns", 0))
	_dem_spacing = float(meta.get("spacing_m", 30.0))
	_dem_x_min = float(meta.get("x_min", 0.0))
	_dem_z_min = float(meta.get("z_min", 0.0))
	if _dem_rows < 2 or _dem_columns < 2 or _dem_spacing <= 0.0:
		push_warning("Dimensions DEM invalides.")
		return
	var binary := FileAccess.open(DEM_BINARY_PATH, FileAccess.READ)
	if binary == null:
		push_warning("Impossible d'ouvrir la grille binaire DEM.")
		return
	var expected_bytes := _dem_rows * _dem_columns * 4
	if binary.get_length() != expected_bytes:
		push_warning("Taille DEM incorrecte : %d octets attendus, %d reçus." % [expected_bytes, binary.get_length()])
		return
	var bytes := binary.get_buffer(expected_bytes)
	_dem_heights.resize(_dem_rows * _dem_columns)
	for i in range(_dem_heights.size()):
		_dem_heights[i] = bytes.decode_float(i * 4) * TERRAIN_VERTICAL_EXAGGERATION
	_dem_loaded = true
	_build_terrain_chunks()
	print("LIBREVILLE STORIES | relief SRTM chargé : %d x %d cellules, pas %.0f m" % [_dem_columns, _dem_rows, _dem_spacing])


func terrain_height_at_world(x: float, z: float) -> float:
	return _terrain_height_at_world(x, z)


func _terrain_height_at_world(x: float, z: float) -> float:
	if not _dem_loaded:
		return 0.0
	var grid_x := clampf((x - _dem_x_min) / _dem_spacing, 0.0, float(_dem_columns - 1))
	var grid_z := clampf((z - _dem_z_min) / _dem_spacing, 0.0, float(_dem_rows - 1))
	var x0 := int(floor(grid_x))
	var z0 := int(floor(grid_z))
	var x1 := mini(x0 + 1, _dem_columns - 1)
	var z1 := mini(z0 + 1, _dem_rows - 1)
	var tx := grid_x - float(x0)
	var tz := grid_z - float(z0)
	var h00 := _dem_heights[z0 * _dem_columns + x0]
	var h10 := _dem_heights[z0 * _dem_columns + x1]
	var h01 := _dem_heights[z1 * _dem_columns + x0]
	var h11 := _dem_heights[z1 * _dem_columns + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build_terrain_chunks() -> void:
	var terrain_material := StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var chunk_index := 0
	for row_start in range(0, _dem_rows - 1, TERRAIN_CHUNK_CELLS):
		for col_start in range(0, _dem_columns - 1, TERRAIN_CHUNK_CELLS):
			var row_end := mini(row_start + TERRAIN_CHUNK_CELLS, _dem_rows - 1)
			var col_end := mini(col_start + TERRAIN_CHUNK_CELLS, _dem_columns - 1)
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(terrain_material)
			for row in range(row_start, row_end):
				for col in range(col_start, col_end):
					var x0 := _dem_x_min + float(col) * _dem_spacing
					var x1 := x0 + _dem_spacing
					var z0 := _dem_z_min + float(row) * _dem_spacing
					var z1 := z0 + _dem_spacing
					var h00 := _dem_heights[row * _dem_columns + col]
					var h10 := _dem_heights[row * _dem_columns + col + 1]
					var h01 := _dem_heights[(row + 1) * _dem_columns + col]
					var h11 := _dem_heights[(row + 1) * _dem_columns + col + 1]
					var c00 := _terrain_color(h00)
					var c10 := _terrain_color(h10)
					var c01 := _terrain_color(h01)
					var c11 := _terrain_color(h11)
					# Ordre des sommets orienté vers le haut (normale +Y).
					surface.set_color(c00)
					surface.add_vertex(Vector3(x0, h00, z0))
					surface.set_color(c01)
					surface.add_vertex(Vector3(x0, h01, z1))
					surface.set_color(c11)
					surface.add_vertex(Vector3(x1, h11, z1))
					surface.set_color(c00)
					surface.add_vertex(Vector3(x0, h00, z0))
					surface.set_color(c11)
					surface.add_vertex(Vector3(x1, h11, z1))
					surface.set_color(c10)
					surface.add_vertex(Vector3(x1, h10, z0))
			surface.generate_normals()
			var mesh := surface.commit()
			if mesh == null:
				continue
			var chunk := MeshInstance3D.new()
			chunk.name = "SRTM_Terrain_%03d" % chunk_index
			chunk.mesh = mesh
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(chunk)
			var body := StaticBody3D.new()
			body.name = "SRTM_Collision_%03d" % chunk_index
			body.collision_layer = 1
			body.collision_mask = 1
			var shape := CollisionShape3D.new()
			shape.shape = mesh.create_trimesh_shape()
			body.add_child(shape)
			add_child(body)
			chunk_index += 1
	print("LIBREVILLE STORIES | terrain et collisions SRTM générés : %d blocs" % chunk_index)


func _terrain_color(height: float) -> Color:
	if height < 1.0:
		return Color(0.66, 0.62, 0.48)
	if height < 15.0:
		return Color(0.34, 0.43, 0.30)
	if height < 45.0:
		return Color(0.29, 0.39, 0.27)
	return Color(0.35, 0.39, 0.29)


func _position_player_on_terrain() -> void:
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player != null and _dem_loaded:
		player.position.y = _terrain_height_at_world(player.position.x, player.position.z) + 2.0


func _apply_ground_surface() -> void:
	# Le grand plan de sol uni donne un aspect artificiel. Une texture légère
	# de variation végétale/terre apporte de la lecture sans ajouter de géométrie.
	var ground := get_parent().get_node_or_null("Ground/MeshInstance3D") as MeshInstance3D
	if ground == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = 20261117
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.48
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 20261118
	detail_noise.frequency = 0.12
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var base_grass := Color(0.25, 0.34, 0.27)
	var dry_soil := Color(0.37, 0.34, 0.27)
	var dense_grass := Color(0.18, 0.29, 0.21)
	for y in range(256):
		for x in range(256):
			var broad := noise.get_noise_2d(float(x), float(y))
			var detail := detail_noise.get_noise_2d(float(x), float(y))
			var color := base_grass.lerp(dry_soil, clampf((broad + 0.45) * 0.42, 0.0, 0.48))
			color = color.lerp(dense_grass, clampf((-broad - 0.2) * 0.24, 0.0, 0.22))
			color = color.lightened(detail * 0.035)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.material_override = material


func _add_ocean_plane() -> void:
	# Plan mer Atlantique / estuaire — plus visible, teinte GTA.
	var ocean := MeshInstance3D.new()
	ocean.name = "OceanSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16000.0, 11000.0)
	ocean.mesh = plane
	ocean.position = Vector3(-2600.0, -0.12, 100.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.36, 0.55, 0.94)
	mat.roughness = 0.15
	mat.metallic = 0.22
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Texture eau procédurale légère
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var wave := sin(float(x) * 0.12) * cos(float(y) * 0.09) * 0.06
			img.set_pixel(x, y, Color(0.10 + wave, 0.40 + wave * 0.5, 0.58 + wave, 0.94))
	img.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(40, 40, 1)
	ocean.material_override = mat
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Évite le z-fighting trop visible entre façades et détails décalés.
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return material

func _read_geojson(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _new_surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface

func _commit_surface(surface: SurfaceTool, instance_name: String) -> void:
	# Les normales sont calculées une seule fois par lot.
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var instance := MeshInstance3D.new()
	instance.name = instance_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _load_environment() -> void:
	var data := _read_geojson("res://data/osm/environment.geojson")
	if data.is_empty():
		push_warning("environment.geojson absent : littoral, eau et espaces verts non chargés.")
		return
	var surface := _new_surface(_environment_material)
	var relief_collision_surface := _new_surface(_environment_material)
	var tree_positions: Array[Vector3] = []
	var batch_count := 0
	var batch_index := 0
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		var kind := str(props.get("environment_kind", ""))
		var added := false
		if str(geometry.get("type", "")) == "Polygon":
			var rings: Array = geometry.get("coordinates", [])
			if rings.is_empty() or rings[0].size() < 4:
				continue
			var points := PackedVector2Array()
			for coordinate in rings[0]:
				var p := _geo_to_world(coordinate)
				points.append(Vector2(p.x, p.z))
			if points.size() > 1 and points[0].distance_squared_to(points[points.size() - 1]) < 0.0001:
				points.remove_at(points.size() - 1)
			if points.size() < 3:
				continue
			var indices := Geometry2D.triangulate_polygon(points)
			if indices.is_empty():
				continue
			var has_landscape_relief := kind in ["vegetation", "green_space"]
			var relief_center := Vector2.ZERO
			var relief_radius := 1.0
			if has_landscape_relief:
				# Calcul du centroïde après accumulation de tous les sommets.
				# La division dans la boucle déformait le centre vers le dernier point.
				for point in points:
					relief_center += point
				relief_center /= float(points.size())
				for point in points:
					relief_radius = maxf(relief_radius, point.distance_to(relief_center))
				_scatter_trees_in_polygon(points, int(props.get("osm_id", _environment_count)), tree_positions, kind)
				# Vraies touffes 3D uniquement sur les surfaces herbeuses cartographiées.
				var mapped_surface := str(props.get("surface", ""))
				var is_grass_area := str(props.get("landuse", "")) == "grass" or (kind == "green_space" and mapped_surface not in ["concrete", "paved", "asphalt"]) or str(props.get("leisure", "")) == "garden"
				if is_grass_area and _grass_generator != null:
					_grass_generator.add_patch(points, int(props.get("osm_id", _environment_count)), relief_center, relief_radius, kind, Callable(self, "_terrain_height_at_world"))
			surface.set_color(_environment_color(kind))
			if has_landscape_relief:
				relief_collision_surface.set_color(_environment_color(kind))
			for i in range(0, indices.size(), 3):
				var p0 := points[indices[i]]
				var p1 := points[indices[i + 1]]
				var p2 := points[indices[i + 2]]
				if has_landscape_relief:
					# Petites bosses de pelouse avec pente douce jusqu'au niveau du chemin.
					var center := (p0 + p1 + p2) / 3.0
					var h0 := _landscape_relief_height(p0, relief_center, relief_radius, kind)
					var h1 := _landscape_relief_height(p1, relief_center, relief_radius, kind)
					var h2 := _landscape_relief_height(p2, relief_center, relief_radius, kind)
					var hc := _landscape_relief_height(center, relief_center, relief_radius, kind)
					for target_surface in [surface, relief_collision_surface]:
						target_surface.add_vertex(Vector3(p0.x, h0, p0.y))
						target_surface.add_vertex(Vector3(p1.x, h1, p1.y))
						target_surface.add_vertex(Vector3(center.x, hc, center.y))
						target_surface.add_vertex(Vector3(p1.x, h1, p1.y))
						target_surface.add_vertex(Vector3(p2.x, h2, p2.y))
						target_surface.add_vertex(Vector3(center.x, hc, center.y))
						target_surface.add_vertex(Vector3(p2.x, h2, p2.y))
						target_surface.add_vertex(Vector3(p0.x, h0, p0.y))
						target_surface.add_vertex(Vector3(center.x, hc, center.y))
				else:
					surface.add_vertex(Vector3(p0.x, _terrain_height_at_world(p0.x, p0.y) + 0.025, p0.y))
					surface.add_vertex(Vector3(p1.x, _terrain_height_at_world(p1.x, p1.y) + 0.025, p1.y))
					surface.add_vertex(Vector3(p2.x, _terrain_height_at_world(p2.x, p2.y) + 0.025, p2.y))
			added = true
		elif str(geometry.get("type", "")) == "LineString":
			var coords: Array = geometry.get("coordinates", [])
			var width := 14.0 if kind == "coastline" else (5.5 if kind == "waterway" else (8.0 if kind == "water" else 1.6))
			surface.set_color(_environment_color(kind))
			for i in range(coords.size() - 1):
				var a := _geo_to_world(coords[i])
				var b := _geo_to_world(coords[i + 1])
				var direction := Vector2(b.x - a.x, b.z - a.z)
				if direction.length_squared() < 0.01:
					continue
				var side := Vector3(-direction.normalized().y, 0.0, direction.normalized().x) * width * 0.5
				_add_quad(surface, a + side + Vector3.UP * 0.014, a - side + Vector3.UP * 0.014, b - side + Vector3.UP * 0.014, b + side + Vector3.UP * 0.014)
				added = true
		if added:
			_environment_count += 1
			batch_count += 1
		if batch_count >= 900:
			_commit_surface(surface, "OSM_Environment_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(_environment_material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Environment_%03d" % batch_index)
	# Les pelouses en relief ont leur propre collision pour que le joueur
	# marche réellement sur les bosses au lieu de rester sous leur surface.
	var relief_mesh := relief_collision_surface.commit()
	if relief_mesh != null and relief_mesh.get_surface_count() > 0:
		var relief_body := StaticBody3D.new()
		relief_body.name = "OSM_Landscape_Relief_Collision"
		relief_body.collision_layer = 1
		relief_body.collision_mask = 1
		var relief_shape := CollisionShape3D.new()
		relief_shape.shape = relief_mesh.create_trimesh_shape()
		relief_body.add_child(relief_shape)
		add_child(relief_body)
	_commit_tree_instances(tree_positions)


func _landscape_relief_height(point: Vector2, center: Vector2, radius: float, kind: String) -> float:
	# Modelé paysager doux : les bordures rejoignent presque le sol, tandis que
	# le cœur des îlots monte progressivement. Les ondulations restent faibles
	# pour ne pas transformer les pelouses de la promenade en collines.
	var max_height := 0.65 if kind == "green_space" else 0.38
	var normalized_distance := clampf(point.distance_to(center) / maxf(radius, 1.0), 0.0, 1.0)
	var mound := pow(1.0 - normalized_distance, 1.45)
	var broad_undulation := sin(point.x * 0.075 + center.y * 0.031) * cos(point.y * 0.082 - center.x * 0.027)
	var fine_undulation := sin(point.x * 0.19 + point.y * 0.13) * 0.35
	var surface_variation := (broad_undulation * 0.045 + fine_undulation * 0.018) * mound
	return _terrain_height_at_world(point.x, point.y) + 0.035


func _scatter_trees_in_polygon(points: PackedVector2Array, osm_id: int, output: Array[Vector3], kind: String) -> void:
	if points.size() < 3 or output.size() >= 1200:
		return
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	var twice_area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		min_x = minf(min_x, a.x)
		max_x = maxf(max_x, a.x)
		min_y = minf(min_y, a.y)
		max_y = maxf(max_y, a.y)
		twice_area += a.x * b.y - b.x * a.y
	var area := absf(twice_area) * 0.5
	if area < 90.0:
		return
	var desired := mini(clampi(int(area / 260.0), 1, 12), 1200 - output.size())
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var radius := 1.0
	for point in points:
		radius = maxf(radius, point.distance_to(center))
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(osm_id) + 73421
	var added := 0
	var attempts := 0
	const MIN_TREE_SPACING := 5.5
	var min_spacing_squared := MIN_TREE_SPACING * MIN_TREE_SPACING
	# Évite les grappes de troncs presque superposés produites par le tirage
	# aléatoire indépendant, y compris entre deux espaces verts voisins.
	while added < desired and attempts < desired * 36:
		attempts += 1
		var candidate := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y))
		if not Geometry2D.is_point_in_polygon(candidate, points):
			continue
		var has_nearby_tree := false
		for existing_position in output:
			var existing := Vector2(existing_position.x, existing_position.z)
			if candidate.distance_squared_to(existing) < min_spacing_squared:
				has_nearby_tree = true
				break
		if has_nearby_tree:
			continue
		var tree_ground_y := _terrain_height_at_world(candidate.x, candidate.y)
		output.append(Vector3(candidate.x, tree_ground_y, candidate.y))
		added += 1


func _make_foliage_cluster(clumps: Array[Dictionary]) -> ArrayMesh:
	# Une couronne tropicale est composée de plusieurs masses de feuilles,
	# pas d'une sphère unique. Les petits volumes se chevauchent pour casser
	# la silhouette artificielle tout en restant dans un seul mesh instancié.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 9
	sphere.rings = 6
	for clump in clumps:
		var scale: Vector3 = clump.get("scale", Vector3.ONE)
		var offset: Vector3 = clump.get("offset", Vector3.ZERO)
		var mesh_transform := Transform3D(Basis().scaled(scale), offset)
		surface.append_from(sphere, 0, mesh_transform)
	surface.generate_normals()
	var generated := surface.commit()
	if generated == null:
		return ArrayMesh.new()
	return generated


func _commit_tree_instances(positions: Array[Vector3]) -> void:
	if positions.is_empty():
		return

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.075
	trunk_mesh.bottom_radius = 0.19
	trunk_mesh.height = 1.9
	trunk_mesh.radial_segments = 7

	# Trois silhouettes tropicales en volumes de feuillage irréguliers :
	# arbre large, arbre arrondi dense et arbre haut plus étroit.
	var canopy_meshes: Array[ArrayMesh] = [
		_make_foliage_cluster([
			{"offset": Vector3(0, 0, 0), "scale": Vector3(0.78, 0.66, 0.76)},
			{"offset": Vector3(-0.52, -0.10, 0.08), "scale": Vector3(0.58, 0.53, 0.60)},
			{"offset": Vector3(0.50, -0.06, -0.12), "scale": Vector3(0.62, 0.56, 0.58)},
			{"offset": Vector3(-0.18, 0.34, -0.30), "scale": Vector3(0.55, 0.52, 0.58)},
			{"offset": Vector3(0.22, 0.30, 0.34), "scale": Vector3(0.58, 0.50, 0.54)},
			{"offset": Vector3(0.05, -0.28, 0.40), "scale": Vector3(0.52, 0.43, 0.50)}
		]),
		_make_foliage_cluster([
			{"offset": Vector3(0, 0.08, 0), "scale": Vector3(0.70, 0.72, 0.68)},
			{"offset": Vector3(-0.40, -0.16, -0.22), "scale": Vector3(0.55, 0.52, 0.54)},
			{"offset": Vector3(0.42, -0.12, 0.18), "scale": Vector3(0.54, 0.58, 0.56)},
			{"offset": Vector3(-0.12, 0.42, 0.26), "scale": Vector3(0.50, 0.48, 0.50)},
			{"offset": Vector3(0.18, 0.34, -0.34), "scale": Vector3(0.48, 0.50, 0.48)}
		]),
		_make_foliage_cluster([
			{"offset": Vector3(0, 0.10, 0), "scale": Vector3(0.52, 0.92, 0.52)},
			{"offset": Vector3(-0.30, -0.22, 0.12), "scale": Vector3(0.43, 0.62, 0.43)},
			{"offset": Vector3(0.32, -0.18, -0.10), "scale": Vector3(0.42, 0.60, 0.44)},
			{"offset": Vector3(0.04, 0.48, 0.26), "scale": Vector3(0.42, 0.54, 0.42)}
		])
	]

	var trunk_material := _make_material(Color.WHITE)
	trunk_material.vertex_color_use_as_albedo = true
	var canopy_material := _make_material(Color.WHITE)
	canopy_material.vertex_color_use_as_albedo = true
	canopy_material.roughness = 0.96

	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.use_colors = true
	trunks.mesh = trunk_mesh
	trunks.instance_count = positions.size()

	var canopy_multimeshes: Array[MultiMesh] = []
	var canopy_counts: Array[int] = [0, 0, 0]
	for mesh in canopy_meshes:
		var canopy_batch := MultiMesh.new()
		canopy_batch.transform_format = MultiMesh.TRANSFORM_3D
		canopy_batch.use_colors = true
		canopy_batch.mesh = mesh
		canopy_batch.instance_count = positions.size()
		canopy_multimeshes.append(canopy_batch)

	var foliage_palette: Array[Color] = [
		Color(0.075, 0.23, 0.105),
		Color(0.11, 0.31, 0.14),
		Color(0.16, 0.37, 0.17),
		Color(0.22, 0.39, 0.16),
		Color(0.10, 0.32, 0.23),
		Color(0.27, 0.40, 0.19),
		Color(0.18, 0.29, 0.12)
	]

	for i in range(positions.size()):
		var position := positions[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(position.x * 13.0 + position.z * 29.0)) + i * 7919
		var height_scale := rng.randf_range(0.82, 1.34)
		var width_scale := rng.randf_range(0.82, 1.24)
		var yaw := rng.randf_range(0.0, TAU)
		var trunk_scale := Vector3(rng.randf_range(0.88, 1.12), height_scale, rng.randf_range(0.88, 1.12))
		var trunk_basis := Basis(Vector3.UP, yaw).scaled(trunk_scale)
		trunks.set_instance_transform(i, Transform3D(trunk_basis, position + Vector3.UP * (0.95 * height_scale)))
		trunks.set_instance_color(i, Color(0.43, 0.30, 0.18).lerp(Color(0.20, 0.15, 0.10), rng.randf()))

		var canopy_type := rng.randi_range(0, canopy_meshes.size() - 1)
		var canopy_index := canopy_counts[canopy_type]
		var canopy_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, width_scale))
		var canopy_height := 2.65 * height_scale
		if canopy_type == 1:
			canopy_height = 2.55 * height_scale
		elif canopy_type == 2:
			canopy_height = 2.95 * height_scale
		canopy_multimeshes[canopy_type].set_instance_transform(canopy_index, Transform3D(canopy_basis, position + Vector3.UP * canopy_height))
		canopy_multimeshes[canopy_type].set_instance_color(canopy_index, foliage_palette[rng.randi_range(0, foliage_palette.size() - 1)])
		canopy_counts[canopy_type] += 1

	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.name = "OSM_Tree_Trunks"
	trunk_instance.multimesh = trunks
	trunk_instance.material_override = trunk_material
	trunk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunk_instance)

	for canopy_type in range(canopy_multimeshes.size()):
		var canopy_batch := canopy_multimeshes[canopy_type]
		canopy_batch.visible_instance_count = canopy_counts[canopy_type]
		if canopy_counts[canopy_type] == 0:
			continue
		var canopy_instance := MultiMeshInstance3D.new()
		canopy_instance.name = "OSM_Tree_Canopies_%d" % canopy_type
		canopy_instance.multimesh = canopy_batch
		canopy_instance.material_override = canopy_material
		canopy_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(canopy_instance)
	print("LIBREVILLE STORIES | arbres tropicaux à couronnes groupées instanciés : %d" % positions.size())

func _environment_color(kind: String) -> Color:
	match kind:
		"water", "waterway":
			return Color(0.12, 0.42, 0.62)   # mer / rivières plus visibles
		"coastline":
			return Color(0.86, 0.76, 0.52)   # bande sable littoral
		"vegetation":
			return Color(0.16, 0.38, 0.22)
		"green_space":
			return Color(0.24, 0.46, 0.24)
		"natural_surface":
			return Color(0.70, 0.62, 0.45)
		_:
			return Color(0.34, 0.42, 0.30)


func _load_neighbourhoods() -> void:
	var data := _read_geojson("res://data/osm/neighbourhoods.geojson")
	if data.is_empty():
		return
	var material := _make_material(Color(0.96, 0.72, 0.30))
	var surface := _new_surface(material)
	var batch_count := 0
	var batch_index := 0
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		if str(geometry.get("type", "")) != "Polygon":
			continue
		var rings: Array = geometry.get("coordinates", [])
		if rings.is_empty():
			continue
		var added := false
		# Tracer aussi les anneaux intérieurs des multipolygones (îlots/exclusions).
		for coords in rings:
			if coords.size() < 4:
				continue
			for index in range(coords.size() - 1):
				var a := _geo_to_world(coords[index])
				var b := _geo_to_world(coords[index + 1])
				var direction := Vector2(b.x - a.x, b.z - a.z)
				if direction.length_squared() < 0.01:
					continue
				var side := Vector3(-direction.normalized().y, 0.0, direction.normalized().x) * 1.8
				_add_quad(surface, a + side + Vector3.UP * 0.045, a - side + Vector3.UP * 0.045, b - side + Vector3.UP * 0.045, b + side + Vector3.UP * 0.045)
				added = true
		if added:
			_neighbourhood_count += 1
			batch_count += 1
		if batch_count >= 500:
			_commit_surface(surface, "OSM_Neighbourhood_Boundaries_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Neighbourhood_Boundaries_%03d" % batch_index)
	print("LIBREVILLE STORIES | limites locales OSM : %d" % _neighbourhood_count)


func _make_asphalt_texture() -> Texture2D:
	# Asphalte procédural type GTA : grain sombre + micro-variation.
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	for y in range(128):
		for x in range(128):
			var n := rng.randf()
			var base := 0.22 + n * 0.08
			# Légères stries longitudinales (usure / bitume).
			var streak := 0.03 if (x + y * 3) % 17 == 0 else 0.0
			var shade := clampf(base + streak + ((x * 7 + y * 11) % 5) * 0.008, 0.14, 0.38)
			image.set_pixel(x, y, Color(shade, shade * 1.01, shade * 0.98, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _make_sidewalk_texture() -> Texture2D:
	# Trottoir béton / dalles — joints discrets style urbain africain / GTA.
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var tile := 16
			var is_joint := (x % tile == 0) or (y % tile == 0)
			var grain := 0.78 + float((x * 13 + y * 19) % 7) * 0.012
			if is_joint:
				grain *= 0.82
			image.set_pixel(x, y, Color(0.62 * grain, 0.61 * grain, 0.57 * grain, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _load_roads() -> void:
	var data := _read_geojson("res://data/osm/roads.geojson")
	if data.is_empty():
		push_warning("roads.geojson absent : carte routière non chargée.")
		return
	var surface := _new_surface(_road_material)
	var sidewalk_material := _make_material(Color.WHITE)
	sidewalk_material.vertex_color_use_as_albedo = true
	sidewalk_material.albedo_texture = _make_sidewalk_texture()
	sidewalk_material.roughness = 0.95
	var sidewalk_surface := _new_surface(sidewalk_material)
	var curb_material := _make_material(Color(0.48, 0.47, 0.44))
	curb_material.vertex_color_use_as_albedo = true
	curb_material.roughness = 0.9
	var curb_surface := _new_surface(curb_material)
	var marking_material := _make_material(Color(0.95, 0.95, 0.90))
	marking_material.vertex_color_use_as_albedo = true
	marking_material.roughness = 0.7
	var marking_surface := _new_surface(marking_material)
	var crosswalk_material := _make_material(Color(0.96, 0.96, 0.92))
	crosswalk_material.vertex_color_use_as_albedo = true
	var crosswalk_surface := _new_surface(crosswalk_material)
	var junction_counts: Dictionary = {}
	for feature in data.get("features", []):
		var junction_geometry: Dictionary = feature.get("geometry", {})
		var junction_lines: Array = []
		match str(junction_geometry.get("type", "")):
			"LineString":
				junction_lines.append(junction_geometry.get("coordinates", []))
			"MultiLineString":
				junction_lines = junction_geometry.get("coordinates", [])
		for junction_line in junction_lines:
			if junction_line.size() < 2:
				continue
			for endpoint in [junction_line[0], junction_line[junction_line.size() - 1]]:
				var key := _road_junction_key(endpoint)
				junction_counts[key] = int(junction_counts.get(key, 0)) + 1
	# Petits raccords circulaires aux nœuds OSM partagés : évite les trous
	# visibles entre plusieurs rubans de chaussée aux carrefours.
	surface.set_color(Color(0.27, 0.29, 0.29))
	var patched_junctions: Dictionary = {}
	for feature in data.get("features", []):
		var junction_geometry: Dictionary = feature.get("geometry", {})
		var junction_lines: Array = []
		match str(junction_geometry.get("type", "")):
			"LineString":
				junction_lines.append(junction_geometry.get("coordinates", []))
			"MultiLineString":
				junction_lines = junction_geometry.get("coordinates", [])
		for junction_line in junction_lines:
			if junction_line.size() < 2:
				continue
			for endpoint in [junction_line[0], junction_line[junction_line.size() - 1]]:
				var key := _road_junction_key(endpoint)
				if int(junction_counts.get(key, 0)) < 3 or patched_junctions.has(key):
					continue
				var props: Dictionary = feature.get("properties", {})
				var width := _road_width(str(props.get("highway", "residential")), props)
				var center := _geo_to_world(endpoint)
				_add_junction_patch(surface, center, maxf(3.0, width * 0.72))
				patched_junctions[key] = true
	var batch_count := 0
	var batch_index := 0
	var road_features: Array = data.get("features", []).duplicate()
	road_features.sort_custom(Callable(self, "_compare_road_features"))
	for feature in road_features:
		var geometry: Dictionary = feature.get("geometry", {})
		var lines: Array = []
		match str(geometry.get("type", "")):
			"LineString":
				lines.append(geometry.get("coordinates", []))
			"MultiLineString":
				lines = geometry.get("coordinates", [])
			_:
				continue
		var props: Dictionary = feature.get("properties", {})
		if _road_labels < MAX_ROAD_LABELS and str(props.get("name", "")).strip_edges() != "":
			var label_coords: Array = []
			for candidate_line in lines:
				if candidate_line.size() >= 2:
					label_coords = candidate_line
					break
			if not label_coords.is_empty():
				var midpoint: Array = label_coords[int(label_coords.size() / 2)]
				_add_map_label(str(props.get("name")), _geo_to_world(midpoint) + Vector3.UP * 0.55, Color(0.92, 0.95, 1.0), 280.0)
				_road_labels += 1
		var road_kind := str(props.get("highway", "residential"))
		var width := _road_width(road_kind, props)
		var sidewalk_mode := _road_sidewalk_mode(props, road_kind)
		var has_center_marking := _road_has_center_marking(props, road_kind)
		surface.set_color(_road_color(road_kind, props))
		marking_surface.set_color(Color(0.96, 0.96, 0.90))
		sidewalk_surface.set_color(Color(0.78, 0.76, 0.70))
		curb_surface.set_color(Color(0.42, 0.41, 0.38))
		var added := false
		for coords in lines:
			if coords.size() < 2:
				continue
			var supports_crosswalk := road_kind in ["primary", "secondary", "tertiary", "trunk"]
			if supports_crosswalk and coords.size() >= 2:
				var first_direction := _geo_to_world(coords[1]) - _geo_to_world(coords[0])
				var last_direction := _geo_to_world(coords[coords.size() - 2]) - _geo_to_world(coords[coords.size() - 1])
				if int(junction_counts.get(_road_junction_key(coords[0]), 0)) >= 3 and first_direction.length() > 0.1:
					_add_crosswalk(crosswalk_surface, _geo_to_world(coords[0]), Vector2(first_direction.x, first_direction.z).normalized(), width)
				if int(junction_counts.get(_road_junction_key(coords[coords.size() - 1]), 0)) >= 3 and last_direction.length() > 0.1:
					_add_crosswalk(crosswalk_surface, _geo_to_world(coords[coords.size() - 1]), Vector2(last_direction.x, last_direction.z).normalized(), width)
			for i in range(coords.size() - 1):
				var a := _geo_to_world(coords[i])
				var b := _geo_to_world(coords[i + 1])
				var direction := Vector2(b.x - a.x, b.z - a.z)
				var seg_len := direction.length()
				if seg_len < 0.08:
					continue
				var dir_n := direction / seg_len
				# Vecteur perpendiculaire unitaire (pas pré-multiplié).
				var perp := Vector3(-dir_n.y, 0.0, dir_n.x)
				var half := width * 0.5
				var y_road := 0.022
				# Chaussée avec UV pour la texture d'asphalte.
				_add_road_quad(surface,
					a + perp * half + Vector3.UP * y_road,
					a - perp * half + Vector3.UP * y_road,
					b - perp * half + Vector3.UP * y_road,
					b + perp * half + Vector3.UP * y_road,
					seg_len, width)
				if has_center_marking:
					_add_road_center_dashes(marking_surface, a, b)
					# Bandes de rive blanches discrètes sur les grands axes.
					if road_kind in ["trunk", "primary", "motorway"]:
						_add_road_edge_line(marking_surface, a, b, perp, half - 0.18)
				if sidewalk_mode != "none":
					var sw := 1.55  # largeur trottoir (m)
					var curb_w := 0.22
					var y_sw := 0.055
					var y_curb := 0.048
					if sidewalk_mode in ["both", "left"]:
						# Bordure / caniveau
						_add_quad(curb_surface,
							a + perp * half + Vector3.UP * y_curb,
							a + perp * (half + curb_w) + Vector3.UP * y_curb,
							b + perp * (half + curb_w) + Vector3.UP * y_curb,
							b + perp * half + Vector3.UP * y_curb)
						# Trottoir
						_add_sidewalk_quad(sidewalk_surface,
							a + perp * (half + curb_w) + Vector3.UP * y_sw,
							a + perp * (half + curb_w + sw) + Vector3.UP * y_sw,
							b + perp * (half + curb_w + sw) + Vector3.UP * y_sw,
							b + perp * (half + curb_w) + Vector3.UP * y_sw,
							seg_len, sw)
					if sidewalk_mode in ["both", "right"]:
						_add_quad(curb_surface,
							a - perp * half + Vector3.UP * y_curb,
							a - perp * (half + curb_w) + Vector3.UP * y_curb,
							b - perp * (half + curb_w) + Vector3.UP * y_curb,
							b - perp * half + Vector3.UP * y_curb)
						_add_sidewalk_quad(sidewalk_surface,
							a - perp * (half + curb_w) + Vector3.UP * y_sw,
							a - perp * (half + curb_w + sw) + Vector3.UP * y_sw,
							b - perp * (half + curb_w + sw) + Vector3.UP * y_sw,
							b - perp * (half + curb_w) + Vector3.UP * y_sw,
							seg_len, sw)
				added = true
		if added:
			_road_count += 1
			batch_count += 1
		if batch_count >= ROADS_PER_MESH:
			_commit_surface(surface, "OSM_Roads_%03d" % batch_index)
			_commit_surface(sidewalk_surface, "OSM_Sidewalks_%03d" % batch_index)
			_commit_surface(curb_surface, "OSM_Curbs_%03d" % batch_index)
			_commit_surface(marking_surface, "OSM_Road_Markings_%03d" % batch_index)
			_commit_surface(crosswalk_surface, "OSM_Crosswalks_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(_road_material)
			sidewalk_surface = _new_surface(sidewalk_material)
			curb_surface = _new_surface(curb_material)
			marking_surface = _new_surface(marking_material)
			crosswalk_surface = _new_surface(crosswalk_material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Roads_%03d" % batch_index)
		_commit_surface(sidewalk_surface, "OSM_Sidewalks_%03d" % batch_index)
		_commit_surface(curb_surface, "OSM_Curbs_%03d" % batch_index)
		_commit_surface(marking_surface, "OSM_Road_Markings_%03d" % batch_index)
		_commit_surface(crosswalk_surface, "OSM_Crosswalks_%03d" % batch_index)


func _road_junction_key(coordinate: Array) -> String:
	# Arrondi d'environ 2 m pour regrouper les nœuds OSM partagés malgré de légères différences.
	return "%.5f:%.5f" % [float(coordinate[0]), float(coordinate[1])]


func _add_junction_patch(surface: SurfaceTool, center: Vector3, radius: float) -> void:
	var segments := 12
	var y := center.y + 0.028
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		var b := TAU * float(i + 1) / float(segments)
		surface.add_vertex(Vector3(center.x, y, center.z))
		# Inverser l'ordre pour orienter les faces vers le haut (normale +Y).
		surface.add_vertex(Vector3(center.x + cos(b) * radius, y, center.z + sin(b) * radius))
		surface.add_vertex(Vector3(center.x + cos(a) * radius, y, center.z + sin(a) * radius))


func _add_crosswalk(surface: SurfaceTool, junction: Vector3, inward_direction: Vector2, road_width: float) -> void:
	if road_width < 5.5:
		return
	var direction := Vector3(inward_direction.x, 0.0, inward_direction.y).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x) * (road_width * 0.42)
	var center := junction + direction * 3.5 + Vector3.UP * 0.062
	# Bandes piétonnes plus nettes (style GTA).
	for stripe_index in range(6):
		var offset := (float(stripe_index) - 2.5) * 0.72
		var stripe_center := center + direction * offset
		var along := direction * 0.22
		_add_quad(surface,
			stripe_center - along + side,
			stripe_center - along - side,
			stripe_center + along - side,
			stripe_center + along + side)


func _road_has_center_marking(props: Dictionary, road_kind: String) -> bool:
	# Marquage de représentation : uniquement sur les axes structurants ou voies
	# explicitement à plusieurs voies. Ce n'est pas un relevé des lignes peintes.
	var lanes := str(props.get("lanes", "")).to_int()
	if lanes >= 2:
		return true
	return road_kind in ["trunk", "primary", "secondary"]


func _add_road_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, length: float, width: float) -> void:
	# UV proportionnels à la longueur / largeur pour un asphalte stable.
	var u_scale := length / 4.0
	var v_scale := width / 4.0
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(0.0, v_scale))
	surface.add_vertex(b)
	surface.set_uv(Vector2(u_scale, v_scale))
	surface.add_vertex(c)
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(u_scale, v_scale))
	surface.add_vertex(c)
	surface.set_uv(Vector2(u_scale, 0.0))
	surface.add_vertex(d)


func _add_sidewalk_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, length: float, width: float) -> void:
	var u_scale := length / 2.5
	var v_scale := width / 2.5
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(0.0, v_scale))
	surface.add_vertex(b)
	surface.set_uv(Vector2(u_scale, v_scale))
	surface.add_vertex(c)
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(u_scale, v_scale))
	surface.add_vertex(c)
	surface.set_uv(Vector2(u_scale, 0.0))
	surface.add_vertex(d)


func _add_road_edge_line(surface: SurfaceTool, a: Vector3, b: Vector3, perp: Vector3, offset: float) -> void:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := delta.length()
	if length < 2.0:
		return
	var half_w: float = 0.06
	var y: float = 0.058
	# Ligne continue de chaque côté.
	var signs: Array[float] = [-1.0, 1.0]
	for sign in signs:
		var signed_offset: float = offset * sign
		var center_a: Vector3 = a + perp * signed_offset + Vector3.UP * y
		var center_b: Vector3 = b + perp * signed_offset + Vector3.UP * y
		var side: Vector3 = perp * half_w
		_add_quad(surface, center_a + side, center_a - side, center_b - side, center_b + side)


func _add_road_center_dashes(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := delta.length()
	if length < 4.0:
		return
	var direction := delta / length
	var side := Vector3(-direction.z, 0.0, direction.x) * 0.09
	var dash_length := 2.8
	var gap_length := 4.2
	var distance := 0.8
	while distance + dash_length < length:
		var start_point := a + direction * distance + Vector3.UP * 0.058
		var end_point := a + direction * (distance + dash_length) + Vector3.UP * 0.058
		_add_quad(surface, start_point + side, start_point - side, end_point - side, end_point + side)
		distance += dash_length + gap_length


func _road_sidewalk_mode(props: Dictionary, road_kind: String) -> String:
	var general := str(props.get("sidewalk", "")).to_lower()
	var left := str(props.get("sidewalk:left", "")).to_lower()
	var right := str(props.get("sidewalk:right", "")).to_lower()
	if general in ["no", "none", "separate"]:
		return "none"
	if left == "no":
		return "right" if right in ["yes", "both"] else "none"
	if right == "no":
		return "left" if left in ["yes", "both"] else "none"
	if left in ["yes", "both"] and right in ["yes", "both"]:
		return "both"
	if left in ["yes", "both"]:
		return "left"
	if right in ["yes", "both"]:
		return "right"
	if general in ["yes", "both"]:
		return "both"
	# Axes structurants + rues résidentielles : trottoirs de représentation (style GTA / Libreville).
	if road_kind in ["trunk", "primary", "secondary", "tertiary", "residential"]:
		return "both"
	return "none"


func _compare_road_features(a: Dictionary, b: Dictionary) -> bool:
	var props_a: Dictionary = a.get("properties", {})
	var props_b: Dictionary = b.get("properties", {})
	var priority_a := _road_label_priority(props_a)
	var priority_b := _road_label_priority(props_b)
	if priority_a == priority_b:
		return str(props_a.get("name", "")) < str(props_b.get("name", ""))
	return priority_a < priority_b


func _road_label_priority(props: Dictionary) -> int:
	if str(props.get("name", "")).strip_edges().is_empty():
		return 99
	match str(props.get("highway", "")):
		"motorway", "trunk":
			return 0
		"primary":
			return 1
		"secondary":
			return 2
		"tertiary":
			return 3
		"residential", "unclassified":
			return 4
		_:
			return 5


func _load_buildings() -> void:
	var data := _read_geojson("res://data/osm/buildings.geojson")
	if data.is_empty():
		push_warning("buildings.geojson absent : bâtiments non chargés.")
		return
	var features: Array = data.get("features", [])
	var limit := mini(features.size(), BUILDING_LIMIT)
	var surface := _new_surface(_building_material)
	var roof_surface := _new_surface(_roof_material)
	var detail_surface := _new_surface(_facade_detail_material)
	var batch_count := 0
	var batch_index := 0
	for index in range(limit):
		var feature: Dictionary = features[index]
		var geometry: Dictionary = feature.get("geometry", {})
		var polygons: Array = []
		match str(geometry.get("type", "")):
			"Polygon":
				polygons.append(geometry.get("coordinates", []))
			"MultiPolygon":
				polygons = geometry.get("coordinates", [])
			_:
				continue
		var props: Dictionary = feature.get("properties", {})
		var building_kind := str(props.get("building", "yes"))
		var osm_id := int(props.get("osm_id", index))
		var height := _building_height(building_kind, osm_id, props)
		var added := false
		for polygon in polygons:
			if polygon.is_empty() or polygon[0].size() < 4:
				continue
			var points := PackedVector2Array()
			for coordinate in polygon[0]:
				var p := _geo_to_world(coordinate)
				points.append(Vector2(p.x, p.z))
			if points.size() > 1 and points[0].distance_squared_to(points[points.size() - 1]) < 0.0001:
				points.remove_at(points.size() - 1)
			if points.size() < 3:
				continue
			var indices := Geometry2D.triangulate_polygon(points)
			if indices.is_empty():
				continue
			var facade_col := _building_color(building_kind, osm_id, props)
			var building_center := Vector2.ZERO
			for footprint_point in points:
				building_center += footprint_point
			building_center /= float(points.size())
			var building_base_y := _terrain_height_at_world(building_center.x, building_center.y)
			surface.set_color(facade_col)
			_add_building(surface, roof_surface, detail_surface, points, indices, height, _roof_color(building_kind, osm_id, props), building_kind, osm_id, props, facade_col, building_base_y)
			added = true
		if added:
			_building_count += 1
			batch_count += 1
		if batch_count >= BUILDINGS_PER_MESH:
			_commit_surface(surface, "OSM_Buildings_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			_commit_surface(roof_surface, "OSM_Roofs_%03d" % batch_index)
			batch_index += 1
			_commit_surface(detail_surface, "OSM_Facade_Details_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(_building_material)
			roof_surface = _new_surface(_roof_material)
			detail_surface = _new_surface(_facade_detail_material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Buildings_%03d" % batch_index)
		_commit_surface(roof_surface, "OSM_Roofs_%03d" % batch_index)
		_commit_surface(detail_surface, "OSM_Facade_Details_%03d" % batch_index)



func _load_localities() -> void:
	var data := _read_geojson("res://data/osm/localities.geojson")
	if data.is_empty():
		push_warning("localities.geojson absent : les noms de quartiers/localités ne seront pas affichés.")
		return
	var features: Array = data.get("features", []).duplicate()
	features.sort_custom(Callable(self, "_compare_locality_features"))
	for feature in features:
		var geometry: Dictionary = feature.get("geometry", {})
		if str(geometry.get("type", "")) != "Point":
			continue
		var props: Dictionary = feature.get("properties", {})
		var label_text := str(props.get("name", "")).strip_edges()
		var coordinates: Array = geometry.get("coordinates", [])
		if label_text.is_empty() or coordinates.size() < 2:
			continue
		var world_position := _geo_to_world(coordinates)
		_locality_points.append({"name": label_text, "position": Vector2(world_position.x, world_position.z)})
		_add_map_label(label_text, world_position + Vector3.UP * 0.65, Color(1.0, 0.84, 0.48), 600.0)
		_locality_count += 1
	print("LIBREVILLE STORIES | noms de quartiers/localités OSM : %d" % _locality_count)


func _compare_locality_features(a: Dictionary, b: Dictionary) -> bool:
	var props_a: Dictionary = a.get("properties", {})
	var props_b: Dictionary = b.get("properties", {})
	var priority_a := _locality_priority(str(props_a.get("place", "")))
	var priority_b := _locality_priority(str(props_b.get("place", "")))
	if priority_a == priority_b:
		return str(props_a.get("name", "")) < str(props_b.get("name", ""))
	return priority_a < priority_b


func _locality_priority(kind: String) -> int:
	match kind:
		"city", "town":
			return 0
		"suburb", "district":
			return 1
		"neighbourhood", "quarter":
			return 2
		"village", "hamlet", "locality":
			return 3
		_:
			return 4

func _load_pois() -> void:
	var data := _read_geojson("res://data/osm/pois.geojson")
	if data.is_empty():
		push_warning("pois.geojson absent : les lieux nommés ne seront pas affichés.")
		return
	var poi_features: Array = data.get("features", []).duplicate()
	poi_features.sort_custom(Callable(self, "_compare_poi_features"))
	for feature in poi_features:
		if _poi_count >= MAX_POI_LABELS:
			break
		var geometry: Dictionary = feature.get("geometry", {})
		if str(geometry.get("type", "")) != "Point":
			continue
		var props: Dictionary = feature.get("properties", {})
		var place_name := str(props.get("name", "")).strip_edges()
		if str(props.get("place", "")) in ["city", "town", "suburb", "neighbourhood", "quarter", "district", "village", "hamlet", "locality"]:
			continue # Les localités sont affichées depuis localities.geojson.
		if place_name.is_empty():
			continue
		var coordinates: Array = geometry.get("coordinates", [])
		if coordinates.size() < 2:
			continue
		var kind := str(props.get("place", ""))
		if kind.is_empty():
			kind = str(props.get("amenity", props.get("shop", props.get("tourism", props.get("healthcare", props.get("building", "place"))))))
		_add_map_label(place_name, _geo_to_world(coordinates) + Vector3.UP * 0.55, _poi_color(kind), 500.0)
		_poi_count += 1


func _compare_poi_features(a: Dictionary, b: Dictionary) -> bool:
	var props_a: Dictionary = a.get("properties", {})
	var props_b: Dictionary = b.get("properties", {})
	var priority_a := _poi_priority(props_a)
	var priority_b := _poi_priority(props_b)
	if priority_a == priority_b:
		return str(props_a.get("name", "")) < str(props_b.get("name", ""))
	return priority_a < priority_b


func _poi_priority(props: Dictionary) -> int:
	var place_kind := str(props.get("place", ""))
	if place_kind in ["city", "town", "suburb", "neighbourhood", "quarter", "district", "village", "hamlet"]:
		return 0
	var kind := str(props.get("amenity", props.get("healthcare", props.get("shop", props.get("tourism", place_kind)))))
	match kind:
		"hospital", "clinic", "police", "fire_station", "townhall", "government", "marketplace":
			return 0
		"school", "college", "university", "kindergarten", "bus_station", "ferry_terminal":
			return 1
		"supermarket", "mall", "department_store", "bank", "pharmacy":
			return 2
		"museum", "attraction", "monument", "viewpoint", "hotel":
			return 3
		_:
			return 4


func _add_map_label(label_text: String, world_position: Vector3, label_color: Color, max_distance: float) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.position = world_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.pixel_size = 0.007
	label.modulate = label_color
	label.outline_size = 4
	label.outline_modulate = Color(0.08, 0.10, 0.12, 0.95)
	label.visibility_range_end = max_distance
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(label)


func _poi_color(kind: String) -> Color:
	match kind:
		"city", "town", "suburb", "neighbourhood", "quarter", "district", "village", "hamlet":
			return Color(1.0, 0.88, 0.58)
		"hospital", "clinic", "doctors", "pharmacy", "healthcare":
			return Color(1.0, 0.48, 0.43)
		"school", "college", "university", "kindergarten", "school_building":
			return Color(0.48, 0.72, 1.0)
		"police", "fire_station", "government", "townhall", "civic", "administrative":
			return Color(0.72, 0.78, 1.0)
		"marketplace", "supermarket", "mall", "convenience":
			return Color(1.0, 0.82, 0.42)
		"hotel", "museum", "attraction", "viewpoint":
			return Color(0.60, 0.90, 0.72)
		_:
			return Color(0.96, 0.96, 0.90)

func _geo_to_world(coordinate: Array) -> Vector3:
	var lon := float(coordinate[0])
	var lat := float(coordinate[1])
	var x := (lon - CENTER_LON) * METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT))
	var z := -(lat - CENTER_LAT) * METERS_PER_DEG_LAT
	return Vector3(x, _terrain_height_at_world(x, z), z)

func _road_color(kind: String, props: Dictionary = {}) -> Color:
	# Palette asphalte plus propre / GTA, teintée par la texture procédurale.
	var surface_tag := str(props.get("surface", "")).to_lower()
	match surface_tag:
		"asphalt", "paved":
			return Color(0.55, 0.56, 0.55)
		"concrete":
			return Color(0.72, 0.72, 0.70)
		"paving_stones", "sett":
			return Color(0.68, 0.66, 0.60)
		"gravel", "fine_gravel":
			return Color(0.62, 0.58, 0.50)
		"ground", "dirt", "earth", "unpaved":
			return Color(0.58, 0.50, 0.40)
	match kind:
		"motorway", "trunk":
			return Color(0.48, 0.50, 0.50)   # axes principaux plus sombres
		"primary":
			return Color(0.52, 0.53, 0.53)
		"secondary":
			return Color(0.56, 0.57, 0.56)
		"tertiary":
			return Color(0.58, 0.59, 0.57)
		"residential", "unclassified":
			return Color(0.60, 0.60, 0.58)
		"service":
			return Color(0.58, 0.58, 0.56)
		"footway", "path", "steps", "cycleway":
			return Color(0.70, 0.66, 0.58)
		_:
			return Color(0.58, 0.58, 0.56)

func _road_width(kind: String, props: Dictionary = {}) -> float:
	# Utilise la largeur réelle ou le nombre de voies OSM quand ils existent.
	# Largeurs inspirées de Libreville : Boulevard Triomphal / Bord de mer ≈ 4 voies.
	# Le parseur commun gère aussi les largeurs exprimées en pieds (ft / ')
	# et les décimales avec virgule, au lieu de les interpréter comme des mètres.
	var tagged_width := _parse_osm_height(str(props.get("width", "")))
	if tagged_width >= 1.5 and tagged_width <= 40.0:
		return tagged_width
	var lanes := str(props.get("lanes", "")).to_int()
	if lanes >= 1 and lanes <= 8:
		return clampf(float(lanes) * 3.4 + 1.2, 3.5, 28.0)
	match kind:
		"motorway", "trunk":
			return 16.0   # type autoroute / voie rapide
		"primary":
			return 12.5  # Boulevard Triomphal, Bd de l'Indépendance
		"secondary":
			return 9.0
		"tertiary":
			return 7.0
		"residential", "unclassified":
			return 5.5
		"service":
			return 3.6
		"footway", "path", "steps", "cycleway":
			return 1.8
		_:
			return 5.0

func _parse_osm_height(raw_value: String) -> float:
	# OSM accepte des hauteurs en mètres, centimètres ou pieds.
	# Sans unité explicite, la convention OSM est le mètre.
	var value := raw_value.strip_edges().to_lower().replace(",", ".")
	if value.is_empty():
		return -1.0
	var multiplier := 1.0
	if value.ends_with("ft") or value.ends_with("feet"):
		multiplier = 0.3048
		value = value.replace("feet", "").replace("ft", "").strip_edges()
	elif value.ends_with("cm"):
		multiplier = 0.01
		value = value.replace("cm", "").strip_edges()
	elif value.ends_with("m"):
		value = value.substr(0, value.length() - 1).strip_edges()
	elif value.ends_with("'"):
		multiplier = 0.3048
		value = value.substr(0, value.length() - 1).strip_edges()
	var parsed := value.to_float()
	if parsed <= 0.0:
		return -1.0
	return parsed * multiplier


func _building_height(kind: String, osm_id: int, props: Dictionary) -> float:
	var tagged_height := _parse_osm_height(str(props.get("height", "")))
	if tagged_height >= 2.5 and tagged_height <= 150.0:
		return tagged_height
	var levels := str(props.get("building:levels", "")).to_int()
	if levels > 0 and levels <= 40:
		return clampf(float(levels) * 3.15, 3.0, 120.0)
	# Hauteurs différenciées inspirées de Libreville :
	# cathédrale, bâtiments admin (Bd Triomphal), immeubles, maisons populaires.
	match kind:
		"cathedral", "church", "mosque", "temple":
			return 14.0 + float(abs(osm_id) % 60) / 10.0
		"government", "public", "civic":
			return 16.0 + float(abs(osm_id) % 80) / 8.0
		"university", "hospital", "school", "college":
			return 11.0 + float(abs(osm_id) % 70) / 10.0
		"commercial", "office", "retail":
			return 12.0 + float(abs(osm_id) % 90) / 8.0
		"apartments", "hotel", "dormitory":
			return 10.0 + float(abs(osm_id) % 80) / 8.0
		"house", "detached", "residential", "semidetached_house", "bungalow":
			return 4.2 + float(abs(osm_id) % 28) / 10.0
		"warehouse", "industrial", "supermarket", "hangar":
			return 6.0 + float(abs(osm_id) % 40) / 10.0
		_:
			return 4.0 + float(abs(osm_id) % 40) / 10.0

func _building_color(kind: String, osm_id: int, props: Dictionary = {}) -> Color:
	# Priorité aux couleurs réellement renseignées dans OSM.
	var tagged := str(props.get("building:colour", props.get("building:color", ""))).strip_edges()
	if not tagged.is_empty():
		return Color.from_string(tagged, Color(0.76, 0.70, 0.62))
	# Palette inspirée de Libreville (enduits clairs, parpaings, planches, ocre) :
	# tons sable, crème, gris ciment, blanc cassé, quelques pastels chauds.
	var palette: Array[Color] = [
		Color(0.82, 0.76, 0.66),  # sable clair
		Color(0.74, 0.70, 0.62),  # beige ciment
		Color(0.88, 0.84, 0.76),  # blanc cassé
		Color(0.66, 0.66, 0.61),  # gris clair
		Color(0.80, 0.70, 0.58),  # ocre doux
		Color(0.90, 0.86, 0.78),  # crème
		Color(0.70, 0.73, 0.68),  # vert-gris très pâle
		Color(0.78, 0.64, 0.52),  # terre cuite claire
		Color(0.72, 0.68, 0.60),  # taupe
		Color(0.84, 0.80, 0.72)   # ivoire
	]
	var selected := palette[abs(osm_id) % palette.size()]
	if kind in ["industrial", "warehouse"]:
		selected = Color(0.58, 0.61, 0.59) if abs(osm_id) % 3 == 0 else Color(0.67, 0.67, 0.62)
	elif kind in ["commercial", "retail", "supermarket", "office"]:
		selected = Color(0.76, 0.76, 0.71) if abs(osm_id) % 2 == 0 else Color(0.82, 0.78, 0.70)
	elif kind in ["apartments", "hotel"]:
		selected = Color(0.80, 0.76, 0.68) if abs(osm_id) % 2 == 0 else Color(0.72, 0.70, 0.64)
	# building:material module la teinte quand aucune couleur explicite n'est fournie.
	var material_tag := str(props.get("building:material", "")).strip_edges().to_lower()
	var material_tint := Color.WHITE
	match material_tag:
		"brick", "bricks":
			material_tint = Color(1.06, 0.90, 0.80)
		"wood", "timber":
			material_tint = Color(1.06, 0.93, 0.80)
		"concrete", "cement_block", "concrete_block":
			material_tint = Color(0.93, 0.95, 0.96)
		"metal", "steel", "aluminium":
			material_tint = Color(0.88, 0.93, 0.97)
		"stone", "limestone":
			material_tint = Color(1.03, 1.00, 0.92)
		"glass":
			material_tint = Color(0.84, 0.94, 1.06)
		"plaster", "render", "stucco":
			material_tint = Color(1.03, 1.02, 0.98)
	return Color(
		clampf(selected.r * material_tint.r, 0.0, 1.0),
		clampf(selected.g * material_tint.g, 0.0, 1.0),
		clampf(selected.b * material_tint.b, 0.0, 1.0),
		selected.a
	)

func _should_use_pitched_roof(kind: String, props: Dictionary, point_count: int) -> bool:
	if point_count != 4:
		return false
	# roof:shape explicite prime sur la règle heuristique par type de bâtiment.
	var shape := str(props.get("roof:shape", "")).strip_edges().to_lower()
	if shape in ["flat", "none"]:
		return false
	if shape == "gabled":
		return true
	# Ces formes nécessitent une géométrie dédiée ; ne pas les dessiner à tort en deux pans.
	if shape in ["hipped", "pyramidal", "skillion", "shed", "round", "dome", "onion"]:
		return false
	return kind in ["house", "residential", "detached", "semidetached_house", "bungalow"]


func _roof_style(kind: String, osm_id: int, props: Dictionary = {}) -> int:
	# Les tags de matériau OSM priment sur la règle visuelle de secours.
	var material_tag := str(props.get("roof:material", "")).to_lower()
	if material_tag in ["metal", "tin", "corrugated_metal", "sheet", "steel", "aluminium"]:
		return 1
	if material_tag in ["concrete", "concrete_plates", "asphalt"]:
		return 2
	if material_tag in ["tile", "tiles", "roof_tiles", "terracotta", "slate"]:
		return 0
	# 0 = tuiles, 1 = tôle nervurée (très répandue à Libreville), 2 = dalle béton.
	# Répartition inspirée des quartiers populaires et résidentiels de la capitale :
	# tôle ondulée dominante, béton sur le tertiaire, tuiles plus rares.
	match kind:
		"industrial", "warehouse", "carport", "shed", "garage", "hangar":
			return 1
		"commercial", "retail", "office", "supermarket", "government", "hospital", "university":
			return 2 if abs(osm_id) % 4 != 0 else 1
		"apartments", "hotel", "dormitory":
			return 1 if abs(osm_id) % 3 != 0 else 2
		"house", "detached", "residential", "semidetached_house", "bungalow":
			# Majorité de tôles, quelques toits en tuiles ou béton.
			var roll: int = abs(osm_id) % 10
			if roll < 7:
				return 1
			if roll < 9:
				return 0
			return 2
		_:
			return 1 if abs(osm_id) % 5 < 3 else (0 if abs(osm_id) % 2 == 0 else 2)


func _roof_color(kind: String, osm_id: int, props: Dictionary = {}) -> Color:
	var tagged := str(props.get("roof:colour", props.get("roof:color", ""))).strip_edges()
	if not tagged.is_empty():
		return Color.from_string(tagged, Color(0.62, 0.34, 0.25))
	# Teintes inspirées de Libreville : tôle grise/rouille, béton clair, tuiles orangées.
	var variation := float(abs(osm_id) % 9) * 0.015
	match _roof_style(kind, osm_id, props):
		1:
			# Tôle ondulée : grise neuve ou légèrement oxydée (très courant).
			if abs(osm_id) % 5 == 0:
				return Color(0.62 + variation, 0.48 + variation * 0.6, 0.38 + variation * 0.4)  # rouille douce
			return Color(0.72 + variation * 0.4, 0.74 + variation * 0.3, 0.73 + variation * 0.3)
		2:
			return Color(0.78 + variation * 0.25, 0.79 + variation * 0.25, 0.75 + variation * 0.25)
		_:
			# Tuiles / terre cuite claire, style tropical.
			return Color(0.78 + variation * 0.15, 0.42 + variation * 0.2, 0.28 + variation * 0.15)


func _make_roof_tile_texture() -> Texture2D:
	# Atlas procédural compact : tuiles, tôle nervurée et dalle béton.
	# Chaque bande est répétée séparément par _add_roof_uv_triangle.
	var image := Image.create(128, 192, false, Image.FORMAT_RGBA8)
	for y in range(192):
		var style := int(y / 64)
		var local_y := y % 64
		for x in range(128):
			var local_x := x % 32
			var pixel := Color(0.58, 0.30, 0.21, 1.0)
			if style == 0:
				# Tuiles terre cuite — joints plus marqués, légère variation.
				var row := int(local_y / 14)
				var tile_x := (x + (15 if row % 2 == 1 else 0)) % 32
				var is_joint := local_y % 14 == 0 or local_y % 14 == 13 or tile_x == 0 or tile_x == 31
				var shade := 0.72 if is_joint else (0.88 + float((x * 11 + local_y * 7) % 5) * 0.025)
				pixel = Color(0.72 * shade, 0.38 * shade, 0.24 * shade, 1.0)
			elif style == 1:
				# Tôle ondulée réaliste (nervures verticales + légère oxydation).
				var rib_pos := local_x % 8
				var rib := 0.70 if rib_pos <= 1 else (0.92 if rib_pos >= 6 else 1.0)
				var wave := 0.93 if local_y % 10 == 0 else 1.0
				var rust := 1.0 - float((x * 13 + y * 17) % 11) * 0.012
				pixel = Color(0.55 * rib * wave * rust, 0.57 * rib * wave * rust, 0.56 * rib * wave * rust, 1.0)
			else:
				# Dalle béton / bitume : joints discrets + grain.
				var seam := 0.88 if local_x == 0 or local_y % 28 == 0 else 1.0
				var grain := 0.97 + float((x * 19 + local_y * 11) % 9) * 0.005
				pixel = Color(0.62 * seam * grain, 0.63 * seam * grain, 0.60 * seam * grain, 1.0)
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _add_roof_uv_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, style: int) -> void:
	var band := 1.0 / 3.0
	var v_offset := float(style) * band
	var uv_a := Vector2(fposmod(a.x / 3.0, 1.0), v_offset + fposmod(a.z / 3.0, 1.0) * band)
	var uv_b := Vector2(fposmod(b.x / 3.0, 1.0), v_offset + fposmod(b.z / 3.0, 1.0) * band)
	var uv_c := Vector2(fposmod(c.x / 3.0, 1.0), v_offset + fposmod(c.z / 3.0, 1.0) * band)
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)


func _add_uv_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_c)
	surface.add_vertex(c)
	surface.set_uv(uv_d)
	surface.add_vertex(d)


func _add_building(walls: SurfaceTool, roofs: SurfaceTool, details: SurfaceTool,
		points: PackedVector2Array, indices: PackedInt32Array, height: float,
		roof_tint: Color, building_kind: String, osm_id: int, props: Dictionary = {},
		facade_color: Color = Color(0.76, 0.68, 0.56), base_y: float = 0.0) -> void:
	var longest_edge_index := 0
	var longest_edge_length := 0.0
	var signed_area := 0.0
	for area_index in range(points.size()):
		var area_a := points[area_index]
		var area_b := points[(area_index + 1) % points.size()]
		signed_area += area_a.x * area_b.y - area_b.x * area_a.y
	# Petite plinthe (0 → 0.12 m) pour ancrer proprement le bâtiment au sol
	# et éviter l'aspect "flottant" à la base.
	var plinth_h := 0.12
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var edge_length := a.distance_to(b)
		if edge_length > longest_edge_length:
			longest_edge_length = edge_length
			longest_edge_index = i
		var uv_length := edge_length / 3.0
		var uv_height := height / 3.0
		# Mur principal (du haut de la plinthe jusqu'au toit).
		walls.set_color(facade_color)
		_add_uv_quad(walls,
			Vector3(a.x, base_y + plinth_h, a.y), Vector3(b.x, base_y + plinth_h, b.y),
			Vector3(b.x, base_y + height, b.y), Vector3(a.x, base_y + height, a.y),
			Vector2(0.0, 0.0), Vector2(uv_length, 0.0),
			Vector2(uv_length, uv_height), Vector2(0.0, uv_height))
		# Plinthe légèrement plus sombre.
		walls.set_color(Color(0.52, 0.49, 0.44))
		_add_uv_quad(walls,
			Vector3(a.x, base_y, a.y), Vector3(b.x, base_y, b.y),
			Vector3(b.x, base_y + plinth_h, b.y), Vector3(a.x, base_y + plinth_h, a.y),
			Vector2(0.0, 0.0), Vector2(uv_length * 0.2, 0.0),
			Vector2(uv_length * 0.2, 0.15), Vector2(0.0, 0.15))
		var edge_direction := Vector3((b.x - a.x) / maxf(edge_length, 0.001), 0.0, (b.y - a.y) / maxf(edge_length, 0.001))
		var outward_normal := Vector3(edge_direction.z, 0.0, -edge_direction.x) * (1.0 if signed_area > 0.0 else -1.0)
		_add_facade_windows(details, a, b, height, building_kind, osm_id, outward_normal, base_y)
	if longest_edge_length >= 2.8 and building_kind not in ["garage", "shed", "roof", "carport"]:
		var door_a := points[longest_edge_index]
		var door_b := points[(longest_edge_index + 1) % points.size()]
		var door_direction := Vector3((door_b.x - door_a.x) / longest_edge_length, 0.0, (door_b.y - door_a.y) / longest_edge_length)
		var door_normal := Vector3(door_direction.z, 0.0, -door_direction.x) * (1.0 if signed_area > 0.0 else -1.0)
		_add_facade_door(details, door_a, door_b, door_normal, base_y)
	roofs.set_color(roof_tint)
	var roof_style := _roof_style(building_kind, osm_id, props)
	var pitched_roof := false
	if _should_use_pitched_roof(building_kind, props, points.size()):
		pitched_roof = _add_pitched_roof(roofs, points, height, roof_style, base_y)
	if not pitched_roof:
		for i in range(0, indices.size(), 3):
			var p0 := points[indices[i]]
			var p1 := points[indices[i + 1]]
			var p2 := points[indices[i + 2]]
			_add_roof_uv_triangle(roofs, Vector3(p0.x, base_y + height + 0.04, p0.y),
				Vector3(p1.x, base_y + height + 0.04, p1.y), Vector3(p2.x, base_y + height + 0.04, p2.y), roof_style)


func _add_pitched_roof(surface: SurfaceTool, points: PackedVector2Array, wall_height: float, style: int, base_y: float = 0.0) -> bool:
	# Première géométrie à deux pans, réservée aux empreintes quadrilatérales
	# convexes et allongées. Les formes complexes gardent un toit plat.
	var longest_index := 0
	var longest_length := 0.0
	var shortest_side := INF
	var cross_sign := 0.0
	for i in range(4):
		var edge := points[(i + 1) % 4] - points[i]
		var next_edge := points[(i + 2) % 4] - points[(i + 1) % 4]
		var edge_length := edge.length()
		longest_length = maxf(longest_length, edge_length)
		if edge_length > longest_length - 0.001:
			longest_index = i
		var cross_value := edge.cross(next_edge)
		if absf(cross_value) < 0.01:
			return false
		if cross_sign == 0.0:
			cross_sign = signf(cross_value)
		elif signf(cross_value) != cross_sign:
			return false
	for i in [((longest_index + 1) % 4), ((longest_index + 3) % 4)]:
		shortest_side = minf(shortest_side, points[i].distance_to(points[(i + 1) % 4]))
	if shortest_side <= 0.1 or longest_length / shortest_side < 1.18:
		return false

	var p0 := points[longest_index]
	var p1 := points[(longest_index + 1) % 4]
	var p2 := points[(longest_index + 2) % 4]
	var p3 := points[(longest_index + 3) % 4]
	var roof_y := base_y + wall_height + 0.035
	var ridge_y := roof_y + clampf(shortest_side * 0.30, 0.75, 1.9)
	var a := Vector3(p0.x, roof_y, p0.y)
	var b := Vector3(p1.x, roof_y, p1.y)
	var c := Vector3(p2.x, roof_y, p2.y)
	var d := Vector3(p3.x, roof_y, p3.y)
	var ridge_start_2d := (p0 + p3) * 0.5
	var ridge_end_2d := (p1 + p2) * 0.5
	var ridge_start := Vector3(ridge_start_2d.x, ridge_y, ridge_start_2d.y)
	var ridge_end := Vector3(ridge_end_2d.x, ridge_y, ridge_end_2d.y)

	# Deux pans inclinés et deux triangles de pignon.
	_add_roof_uv_triangle(surface, a, b, ridge_end, style)
	_add_roof_uv_triangle(surface, a, ridge_end, ridge_start, style)
	_add_roof_uv_triangle(surface, ridge_start, ridge_end, c, style)
	_add_roof_uv_triangle(surface, ridge_start, c, d, style)
	_add_roof_uv_triangle(surface, a, ridge_start, d, style)
	_add_roof_uv_triangle(surface, b, c, ridge_end, style)
	return true


func _add_facade_windows(surface: SurfaceTool, a: Vector2, b: Vector2,
		height: float, building_kind: String, osm_id: int, normal: Vector3, base_y: float = 0.0) -> void:
	if building_kind in ["garage", "shed", "roof", "carport", "warehouse", "industrial"]:
		return
	var edge := b - a
	var edge_length := edge.length()
	if edge_length < 4.0 or height < 2.6:
		return
	var tangent := Vector3(edge.x / edge_length, 0.0, edge.y / edge_length)
	var floors := clampi(int(ceil(height / 3.05)), 1, 8)
	var window_count := clampi(int(floor(edge_length / 4.8)), 1, 6)
	var spacing := edge_length / float(window_count)
	var window_width := clampf(spacing * 0.36, 0.60, 1.20)
	var window_height := 0.92 if floors == 1 else 1.10
	var glass := Color(0.14, 0.22, 0.28) if abs(osm_id) % 3 == 0 else Color(0.20, 0.28, 0.33)
	for floor_index in range(floors):
		var center_y := 1.10 + float(floor_index) * 3.00
		if center_y + window_height * 0.5 > height - 0.30:
			continue
		for window_index in range(window_count):
			var center_distance := (float(window_index) + 0.5) * spacing
			var center := Vector3(a.x, base_y, a.y) + tangent * center_distance + Vector3.UP * center_y
			var half_width := window_width * 0.5
			var half_height := window_height * 0.5
			# Offset très léger pour coller la fenêtre à la façade (évite le flottement).
			var offset := normal * 0.028
			surface.set_color(glass)
			_add_quad(surface,
				center - tangent * half_width - Vector3.UP * half_height + offset,
				center + tangent * half_width - Vector3.UP * half_height + offset,
				center + tangent * half_width + Vector3.UP * half_height + offset,
				center - tangent * half_width + Vector3.UP * half_height + offset)
			if floors >= 2 and building_kind in ["apartments", "residential", "house", "commercial", "office"] and (window_index + abs(osm_id)) % 4 == 0 and floor_index > 0:
				_add_facade_balcony(surface, center, tangent, normal, half_width, base_y + center_y - half_height - 0.06)
			# Appui de fenêtre discret, collé à la façade.
			surface.set_color(Color(0.70, 0.68, 0.62))
			var sill_center := center - Vector3.UP * (half_height + 0.05)
			var sill_offset := normal * 0.038
			_add_quad(surface,
				sill_center - tangent * (half_width + 0.03) + sill_offset,
				sill_center + tangent * (half_width + 0.03) + sill_offset,
				sill_center + tangent * (half_width + 0.03) + Vector3.UP * 0.07 + sill_offset,
				sill_center - tangent * (half_width + 0.03) + Vector3.UP * 0.07 + sill_offset)


func _add_facade_balcony(surface: SurfaceTool, center: Vector3, tangent: Vector3,
		normal: Vector3, half_width: float, floor_y: float) -> void:
	# Balcon stylisé à faible profondeur : dalle, garde-corps et montants.
	# floor_y est une hauteur mondiale absolue (sous le bas de la fenêtre).
	# On ignore volontairement center.y pour éviter le double-ajout qui faisait
	# flotter les balcons au-dessus des toits.
	var depth := 0.68
	var width := half_width + 0.18
	var base := Vector3(center.x, floor_y, center.z)
	var front := base + normal * depth
	var back_left := base - tangent * width + normal * 0.04
	var back_right := base + tangent * width + normal * 0.04
	var front_left := front - tangent * width
	var front_right := front + tangent * width
	# Dalle du balcon (légèrement en dessous du seuil de fenêtre).
	surface.set_color(Color(0.68, 0.66, 0.60))
	_add_quad(surface, back_left, back_right, front_right, front_left)
	# Garde-corps avant + côtés.
	var rail_bottom := floor_y + 0.06
	var rail_top := floor_y + 0.88
	surface.set_color(Color(0.32, 0.34, 0.33))
	_add_quad(surface,
		Vector3(front_left.x, rail_bottom, front_left.z),
		Vector3(front_right.x, rail_bottom, front_right.z),
		Vector3(front_right.x, rail_top, front_right.z),
		Vector3(front_left.x, rail_top, front_left.z))
	_add_quad(surface,
		Vector3(back_left.x, rail_bottom, back_left.z),
		Vector3(back_left.x, rail_top, back_left.z),
		Vector3(front_left.x, rail_top, front_left.z),
		Vector3(front_left.x, rail_bottom, front_left.z))
	_add_quad(surface,
		Vector3(back_right.x, rail_bottom, back_right.z),
		Vector3(front_right.x, rail_bottom, front_right.z),
		Vector3(front_right.x, rail_top, front_right.z),
		Vector3(back_right.x, rail_top, back_right.z))

func _add_facade_door(surface: SurfaceTool, a: Vector2, b: Vector2, normal: Vector3, base_y: float = 0.0) -> void:
	var edge := b - a
	var edge_length := edge.length()
	if edge_length < 2.8:
		return
	var tangent := Vector3(edge.x / edge_length, 0.0, edge.y / edge_length)
	# Porte ancrée au sol (y ≈ 1.05 = centre d'une porte de 2,1 m).
	var center := Vector3(a.x, base_y + 1.05, a.y) + tangent * (edge_length * 0.5)
	var half_width := 0.44
	var half_height := 1.05
	surface.set_color(Color(0.30, 0.22, 0.16))
	var offset := normal * 0.032
	_add_quad(surface,
		center - tangent * half_width - Vector3.UP * half_height + offset,
		center + tangent * half_width - Vector3.UP * half_height + offset,
		center + tangent * half_width + Vector3.UP * half_height + offset,
		center - tangent * half_width + Vector3.UP * half_height + offset)


func _add_uv_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Coordonnées mondiales : le motif reste à une échelle constante sur chaque toit.
	surface.set_uv(Vector2(a.x / 2.0, a.z / 2.0))
	surface.add_vertex(a)
	surface.set_uv(Vector2(b.x / 2.0, b.z / 2.0))
	surface.add_vertex(b)
	surface.set_uv(Vector2(c.x / 2.0, c.z / 2.0))
	surface.add_vertex(c)

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)
