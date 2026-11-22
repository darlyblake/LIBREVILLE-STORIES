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
const DEM_META_EXTENDED_PATH := "res://libreville_dem_extended.json"
const DEM_BINARY_EXTENDED_PATH := "res://libreville_dem_extended_f32.bin"
const DEM_META_FALLBACK_PATH := "res://libreville_dem.json"
const DEM_BINARY_FALLBACK_PATH := "res://libreville_dem_f32.bin"
const TERRAIN_CHUNK_CELLS := 32
const TERRAIN_VERTICAL_EXAGGERATION := 1.0

@export var show_roads := true
@export var show_buildings := true
## Trottoirs : 0 = seulement ceux indiqués par OSM, 1 = + grands axes, 2 = + rues nommées, 3 = toutes les rues urbaines.
@export_enum("Tags OSM seulement", "Grands axes", "Grands axes + rues nommées", "Toutes les rues urbaines") var sidewalk_coverage := 3
## Collision des chaussées et trottoirs (le joueur marche dessus au lieu de passer dessous).
@export var road_collision := true
## Phase « tracé des routes » : les parcs/végétation OSM (polygones verts, arbres, herbe) sont masqués.
## Le sol reste vert ; remettre à true pour la phase décor.
@export var render_green_areas := false
## Charge aussi les packs 4K worn_asphalt (pistes en terre) et asphalt_floor (béton/pavés).
@export var load_extra_road_textures := true

const ROAD_LIFT := 0.035
const MARKING_LIFT := 0.085
const ROAD_MAX_STEP := 15.0
const ROAD_HIT_CELL := 32.0
const MEDIAN_MAX_GAP := 18.0
const LAMP_PATH := "res://assets/models/baie_des_rois/lampadaire_baie_des_rois.glb"
const LAMP_VISIBILITY := 260.0
const CURB_WIDTH := 0.18
const CURB_HEIGHT := 0.14
const SIDEWALK_WIDTH := 2.0
const ROAD_UV_METERS := 6.0
const SIDEWALK_UV_METERS := 2.0
const ROAD_TILE_SIZE := 800.0
const ROAD_DETAIL_VISIBILITY := 450.0
const JUNCTION_CLEARANCE := 0.8
const MIN_SIDEWALK_RUN := 2.0
const ROAD_TEXTURED_KEYS := ["asphalt", "dirt", "paving", "sidewalk"]
const ROAD_SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_a : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D albedo_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 0.5;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	float n_big = texture(noise_tex, w / 160.0).r;
	float n_mid = texture(noise_tex, w / 41.0 + vec2(0.31, 0.57)).r;
	float n_fine = texture(noise_tex, w / 7.0 + vec2(0.70, 0.20)).r;
	float wear = clamp(COLOR.a, 0.0, 1.5);
	float lane = UV2.x;
	float across = abs(UV2.y);

	// Deux lectures de la même texture à échelle/rotation différentes :
	// les fissures ne se répètent plus au même rythme sur toute la route.
	vec2 uv_b = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * UV * 0.43 + vec2(0.37, 0.71);
	vec3 a1 = texture(albedo_a, UV).rgb;
	vec3 a2 = texture(albedo_a, uv_b).rgb;
	vec3 asphalt = mix(a1, a2, 0.45);

	// Zones de bitume plus clair, délavé ou poussiéreux.
	float faded = smoothstep(0.50, 0.78, n_big) * (0.35 + 0.35 * wear);
	vec3 dusty = texture(albedo_c, UV * 0.7).rgb * 1.35;
	asphalt = mix(asphalt, asphalt * 1.22, faded);
	asphalt = mix(asphalt, dusty, faded * 0.22);

	// Rapiéçages : plaques de bitume plus sombre et plus lisse.
	float patch_mask = smoothstep(0.62, 0.70, n_mid) * (1.0 - smoothstep(0.82, 0.90, n_big)) * clamp(wear, 0.0, 1.0);
	vec3 patch_col = texture(albedo_b, UV * 1.3).rgb * vec3(0.74, 0.76, 0.80);
	asphalt = mix(asphalt, patch_col, patch_mask * 0.65);

	// Traces de pneus dans les voies, rives poussiéreuses.
	float track = max(exp(-pow((across - 0.30) / 0.09, 2.0)), exp(-pow((across - 0.72) / 0.09, 2.0)));
	asphalt *= 1.0 - 0.20 * track * lane * (0.6 + 0.4 * n_fine);
	float dust = smoothstep(0.78, 1.0, across) * lane;
	asphalt = mix(asphalt, vec3(0.40, 0.34, 0.27) * (0.8 + 0.4 * n_fine), dust * (0.30 + 0.20 * wear));

	ALBEDO = asphalt * COLOR.rgb;
	ROUGHNESS = clamp(texture(rough_a, UV).r * mix(1.0, 0.82, patch_mask) + 0.05 * track, 0.0, 1.0);
	SPECULAR = 0.35;
	NORMAL_MAP = texture(normal_a, UV).xyz;
	NORMAL_MAP_DEPTH = normal_strength;
}
"""

var _road_count := 0
var _building_count := 0
var _poi_count := 0
var _environment_count := 0
var _neighbourhood_count := 0
var _locality_count := 0
var _grass_generator: GrassGenerator
var _environment_material: Material
var _road_labels := 0
var _road_material: Material
var _road_hit_grid: Dictionary = {}
var _lamp_batch: Array[Transform3D] = []
var _lamp_parts: Array[Dictionary] = []
var _lamp_count := 0
var _road_materials: Dictionary = {}
var _uv_origin := Vector2.ZERO
var _building_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _facade_detail_material: StandardMaterial3D
var _locality_points: Array[Dictionary] = []
var _neighbourhood_polygons: Dictionary = {}
var _neighbourhood_arrondissements: Dictionary = {}
var _road_clearance_segments: Array[Dictionary] = []
var _road_clearance_grid: Dictionary = {}
var _location_hud: Label
var _location_refresh := 0.0
var _dem_heights := PackedFloat32Array()
var _dem_rows := 0
var _dem_columns := 0
var _dem_spacing := 30.0
var _dem_x_min := 0.0
var _dem_z_min := 0.0
var _dem_loaded := false
var _coastline_paths: Array[PackedVector2Array] = []
var _beach_polygons: Array[PackedVector2Array] = []

func _ready() -> void:
	_load_real_terrain()
	if _dem_loaded:
		_disable_flat_ground()
	else:
		push_warning("DEM indisponible : le sol plat et sa collision restent actifs pour éviter la chute du joueur.")
	_apply_ground_surface()
	_add_ocean_plane()
	_build_road_materials()
	_environment_material = _make_environment_material()
	# Le réseau routier doit être connu AVANT la génération du relief :
	# le terrain SRTM est alors réellement évidé sous chaussées et trottoirs.
	_load_road_clearance_data()
	if _dem_loaded:
		_build_terrain_chunks()
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
	# Le DEM régional étendu est prioritaire. L'ancien relief reste disponible
	# comme secours tant que les nouveaux fichiers ne sont pas présents ensemble.
	var use_extended_dem := FileAccess.file_exists(DEM_META_EXTENDED_PATH) and FileAccess.file_exists(DEM_BINARY_EXTENDED_PATH)
	var meta_path := DEM_META_EXTENDED_PATH if use_extended_dem else DEM_META_FALLBACK_PATH
	var binary_path := DEM_BINARY_EXTENDED_PATH if use_extended_dem else DEM_BINARY_FALLBACK_PATH
	if not FileAccess.file_exists(meta_path) or not FileAccess.file_exists(binary_path):
		push_warning("DEM Libreville absent : terrain plat de secours conservé.")
		return
	var meta_file := FileAccess.open(meta_path, FileAccess.READ)
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
	var binary := FileAccess.open(binary_path, FileAccess.READ)
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
	print("LIBREVILLE STORIES | relief SRTM chargé (%s) : %d x %d cellules, pas %.0f m" % ["étendu" if use_extended_dem else "secours", _dem_columns, _dem_rows, _dem_spacing])


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
					# On découpe chaque cellule SRTM contre les corridors OSM.
					# Cela retire le terrain lui-même sous la chaussée ET le trottoir ;
					# masquer seulement les polygones OSM ne suffisait pas.
					var cell := PackedVector2Array([
						Vector2(x0, z0), Vector2(x0, z1),
						Vector2(x1, z1), Vector2(x1, z0)
					])
					var terrain_pieces := _clip_polygon_away_from_roads(cell, 0.85)
					for piece in terrain_pieces:
						if piece.size() < 3:
							continue
						var indices := Geometry2D.triangulate_polygon(piece)
						if indices.is_empty():
							continue
						for i in range(0, indices.size(), 3):
							for vertex_index in range(3):
								var point: Vector2 = piece[indices[i + vertex_index]]
								var height := _terrain_height_at_world(point.x, point.y)
								surface.set_color(_terrain_color(height))
								surface.add_vertex(Vector3(point.x, height, point.y))
			surface.generate_normals()
			var mesh := surface.commit()
			if mesh == null or mesh.get_surface_count() == 0:
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
			var terrain_collision := mesh.create_trimesh_shape() as ConcavePolygonShape3D
			if terrain_collision == null:
				push_error("Collision SRTM impossible pour le bloc %d." % chunk_index)
				continue
			terrain_collision.backface_collision = true
			shape.shape = terrain_collision
			body.add_child(shape)
			add_child(body)
			chunk_index += 1
	_create_terrain_boundary_walls()
	print("LIBREVILLE STORIES | terrain SRTM évidé sous routes et trottoirs : %d blocs" % chunk_index)

func _create_terrain_boundary_walls() -> void:
	# Le DEM couvre une zone finie : des murs invisibles empêchent le joueur
	# de quitter la surface collidable et de tomber dans le vide.
	var x_max := _dem_x_min + float(_dem_columns - 1) * _dem_spacing
	var z_max := _dem_z_min + float(_dem_rows - 1) * _dem_spacing
	var width := x_max - _dem_x_min
	var depth := z_max - _dem_z_min
	var center_x := (_dem_x_min + x_max) * 0.5
	var center_z := (_dem_z_min + z_max) * 0.5
	var wall_height := 220.0
	var wall_center_y := 70.0
	var wall_thickness := 4.0
	var walls: Array[Dictionary] = [
		{"name": "TerrainBoundary_West", "size": Vector3(wall_thickness, wall_height, depth + wall_thickness * 2.0), "position": Vector3(_dem_x_min - wall_thickness * 0.5, wall_center_y, center_z)},
		{"name": "TerrainBoundary_East", "size": Vector3(wall_thickness, wall_height, depth + wall_thickness * 2.0), "position": Vector3(x_max + wall_thickness * 0.5, wall_center_y, center_z)},
		{"name": "TerrainBoundary_North", "size": Vector3(width, wall_height, wall_thickness), "position": Vector3(center_x, wall_center_y, _dem_z_min - wall_thickness * 0.5)},
		{"name": "TerrainBoundary_South", "size": Vector3(width, wall_height, wall_thickness), "position": Vector3(center_x, wall_center_y, z_max + wall_thickness * 0.5)}
	]
	for wall_data in walls:
		var body := StaticBody3D.new()
		body.name = str(wall_data.name)
		body.collision_layer = 1
		body.collision_mask = 1
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall_data.size
		shape_node.shape = box
		body.add_child(shape_node)
		body.position = wall_data.position
		add_child(body)


func _terrain_color(height: float) -> Color:
	# Palette minérale temporaire pour distinguer nettement les chaussées.
	# Les couleurs végétales seront réintroduites pendant la décoration.
	if height < 1.0:
		return Color(0.62, 0.57, 0.46)
	if height < 15.0:
		return Color(0.43, 0.42, 0.39)
	if height < 45.0:
		return Color(0.39, 0.40, 0.39)
	return Color(0.45, 0.44, 0.41)


func _position_player_on_terrain() -> void:
	if not _dem_loaded:
		return
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player != null:
		player.position.y = _terrain_height_at_world(player.position.x, player.position.z) + 2.0
	var vehicle := get_parent().get_node_or_null("Vehicle") as Node3D
	if vehicle != null:
		vehicle.position.y = _terrain_height_at_world(vehicle.position.x, vehicle.position.z) + 0.25


func _apply_ground_surface() -> void:
	# Mode contrôle des routes : sol neutre minéral, sans texture végétale.
	# Les espaces verts OSM restent masqués jusqu'à la phase décoration.
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
	var base_grass := Color(0.27, 0.28, 0.28)
	var dry_soil := Color(0.36, 0.35, 0.33)
	var dense_grass := Color(0.23, 0.25, 0.25)
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
	# Océan Atlantique procédural : vagues géométriques animées et reflets Fresnel.
	# Aucun fichier de texture externe n'est requis ; shader volontairement léger
	# pour rester compatible avec les GPU intégrés.
	var ocean := MeshInstance3D.new()
	ocean.name = "OceanSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16000.0, 11000.0)
	plane.subdivide_width = 180
	plane.subdivide_depth = 140
	ocean.mesh = plane
	ocean.position = Vector3(-2600.0, -0.12, 100.0)

	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec3 water_normal;
varying vec3 water_world_pos;
varying float wave_height;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	vec2 p = world_pos.xz;

	float a1 = dot(p, normalize(vec2(0.82, 0.57))) * 0.030 + t * 0.72;
	float a2 = dot(p, normalize(vec2(-0.34, 0.94))) * 0.052 - t * 0.91;
	float a3 = dot(p, normalize(vec2(0.98, -0.18))) * 0.091 + t * 1.18;

	float h1 = sin(a1) * 0.34;
	float h2 = sin(a2) * 0.13;
	float h3 = sin(a3) * 0.045;
	float height = h1 + h2 + h3;

	float dx = cos(a1) * 0.34 * 0.030 * 0.82
		+ cos(a2) * 0.13 * 0.052 * -0.34
		+ cos(a3) * 0.045 * 0.091 * 0.98;
	float dz = cos(a1) * 0.34 * 0.030 * 0.57
		+ cos(a2) * 0.13 * 0.052 * 0.94
		+ cos(a3) * 0.045 * 0.091 * -0.18;

	VERTEX.y += height;
	wave_height = height;
	water_normal = normalize(vec3(-dx, 1.0, -dz));
	water_world_pos = world_pos;
}

void fragment() {
	float broad = sin(water_world_pos.x * 0.006 + TIME * 0.18)
		* cos(water_world_pos.z * 0.008 - TIME * 0.15);
	float fine = sin(water_world_pos.x * 0.041 + water_world_pos.z * 0.027 + TIME * 0.8);
	float ripple_a = water_world_pos.x * 0.19 + water_world_pos.z * 0.11 + TIME * 1.55;
	float ripple_b = water_world_pos.x * -0.13 + water_world_pos.z * 0.23 - TIME * 1.12;
	float ripple_c = water_world_pos.x * 0.31 + water_world_pos.z * -0.08 + TIME * 2.05;
	float ripple_dx = cos(ripple_a) * 0.19 * 0.075 + cos(ripple_b) * -0.13 * 0.045 + cos(ripple_c) * 0.31 * 0.018;
	float ripple_dz = cos(ripple_a) * 0.11 * 0.075 + cos(ripple_b) * 0.23 * 0.045 + cos(ripple_c) * -0.08 * 0.018;
	float crest = smoothstep(0.28, 0.48, wave_height + fine * 0.035);

	vec3 deep_water = vec3(0.012, 0.105, 0.175);
	vec3 mid_water = vec3(0.018, 0.235, 0.315);
	vec3 sunlit_water = vec3(0.075, 0.36, 0.42);
	vec3 water_color = mix(deep_water, mid_water, 0.45 + broad * 0.18);
	water_color = mix(water_color, sunlit_water, crest * 0.12);
	water_color *= 0.96 + 0.045 * sin(water_world_pos.x * 0.013 + water_world_pos.z * 0.009 + TIME * 0.22);

	vec3 detailed_normal = normalize(water_normal + vec3(-ripple_dx, 0.0, -ripple_dz));
	vec3 n = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(detailed_normal, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 4.0);
	vec3 sun_direction = normalize(vec3(-0.35, 0.82, 0.44));
	float glint = pow(max(dot(reflect(-sun_direction, n), VIEW), 0.0), 48.0);
	ALBEDO = mix(water_color, vec3(0.34, 0.52, 0.54), fresnel * 0.48);
	ALBEDO += vec3(0.22, 0.27, 0.25) * glint * 0.22;
	METALLIC = 0.12;
	ROUGHNESS = mix(0.24, 0.38, clamp(abs(fine) * 0.5, 0.0, 1.0));
	SPECULAR = 0.72;
	NORMAL = n;
}
"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	ocean.material_override = water_material
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(ocean)


func _make_environment_material() -> ShaderMaterial:
	# Matériau commun aux surfaces OSM : les plages reçoivent un grain fin,
	# des rides de sable et des zones minérales irrégulières sans multiplier
	# les matériaux ni les draw calls.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;
varying vec4 surface_tint;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += vec2(dot(p, p + vec2(45.32)));
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_tint = COLOR;
}

void fragment() {
	vec3 base = surface_tint.rgb;
	float sand_mask = smoothstep(0.62, 0.78, base.r)
		* smoothstep(0.52, 0.72, base.g)
		* (1.0 - smoothstep(0.55, 0.72, base.b));
	vec2 p = world_position.xz;
	float broad = noise21(p * 0.075);
	float medium = noise21(p * 0.62);
	float grain = hash21(floor(p * 8.0));
	float ripple = sin(p.x * 0.42 + sin(p.y * 0.17) * 1.8) * 0.5 + 0.5;
	float sand_variation = 0.84 + broad * 0.18 + medium * 0.08;
	sand_variation += (ripple - 0.5) * 0.045 + (grain - 0.5) * 0.055;
	vec3 sand_color = base * sand_variation;
	sand_color = mix(sand_color, sand_color * vec3(0.82, 0.78, 0.69), smoothstep(0.68, 0.92, broad) * 0.12);
	// Humidité diffuse du sable près des zones basses : taches foncées,
	// légèrement plus lisses, sans créer une bande artificielle uniforme.
	float damp_noise = broad * 0.62 + medium * 0.38;
	float damp_mask = smoothstep(0.58, 0.78, damp_noise) * sand_mask;
	sand_color = mix(sand_color, sand_color * vec3(0.76, 0.79, 0.78), damp_mask * 0.34);
	vec3 other_color = base * (0.97 + broad * 0.06);
	ALBEDO = mix(other_color, sand_color, sand_mask);
	float sand_roughness = mix(0.94, 0.88, damp_mask);
	ROUGHNESS = mix(0.94, sand_roughness, sand_mask);
	SPECULAR = mix(0.18, 0.28, damp_mask);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Évite le z-fighting trop visible entre façades et détails décalés.
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return material

func _read_geojson(path: String) -> Dictionary:
	# Pour les couches de détail, préférer la nouvelle extraction régionale
	# lorsqu'elle existe ; conserver les quartiers historiques en secours.
	var filename := path.get_file()
	var extended_path := "res://data/osm/extended/" + filename
	var use_extended_layer := filename != "neighbourhoods.geojson" and FileAccess.file_exists(extended_path)
	var selected_path := extended_path if use_extended_layer else path
	if not FileAccess.file_exists(selected_path):
		return {}
	var file := FileAccess.open(selected_path, FileAccess.READ)
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
			var original_points := PackedVector2Array()
			for coordinate in rings[0]:
				var p := _geo_to_world(coordinate)
				original_points.append(Vector2(p.x, p.z))
			if original_points.size() > 1 and original_points[0].distance_squared_to(original_points[original_points.size() - 1]) < 0.0001:
				original_points.remove_at(original_points.size() - 1)
			if original_points.size() < 3:
				continue
			if kind == "natural_surface" and (str(props.get("natural", "")).to_lower() in ["beach", "sand"] or str(props.get("surface", "")).to_lower() == "sand"):
				_beach_polygons.append(original_points)
			var has_landscape_relief := kind in ["vegetation", "green_space"]
			if has_landscape_relief and not render_green_areas:
				continue
			var render_polygons: Array[PackedVector2Array] = [original_points]
			# Toute surface terrestre OSM doit respecter le corridor route + bordure + trottoir.
			# Les plans d'eau sont conservés : ils ne doivent pas être découpés comme du terrain.
			if not _is_water_environment_polygon(kind, props):
				render_polygons = _clip_polygon_away_from_roads(original_points, 1.0 if has_landscape_relief else 0.65)
			var polygon_added := false
			for points in render_polygons:
				if points.size() < 3:
					continue
				var indices := Geometry2D.triangulate_polygon(points)
				if indices.is_empty():
					continue
				var relief_center := Vector2.ZERO
				var relief_radius := 1.0
				if has_landscape_relief:
					for point in points:
						relief_center += point
					relief_center /= float(points.size())
					for point in points:
						relief_radius = maxf(relief_radius, point.distance_to(relief_center))
					_scatter_trees_in_polygon(points, int(props.get("osm_id", _environment_count)), tree_positions, kind)
					var mapped_surface := str(props.get("surface", ""))
					var is_grass_area := str(props.get("landuse", "")) == "grass" or (kind == "green_space" and mapped_surface not in ["concrete", "paved", "asphalt"]) or str(props.get("leisure", "")) == "garden"
					if is_grass_area and _grass_generator != null:
						_grass_generator.add_patch(points, int(props.get("osm_id", _environment_count)), relief_center, relief_radius, kind, Callable(self, "_terrain_height_at_world"), Callable(self, "_is_near_road"))
				surface.set_color(_environment_color(kind))
				if has_landscape_relief:
					relief_collision_surface.set_color(_environment_color(kind))
				for i in range(0, indices.size(), 3):
					var p0 := points[indices[i]]
					var p1 := points[indices[i + 1]]
					var p2 := points[indices[i + 2]]
					if has_landscape_relief:
						# Un grand triangle plat flottait au-dessus des routes : on le
						# découpe en petits triangles posés sur le maillage du relief.
						var pieces: Array = []
						_subdivide_ground_triangle(p0, p1, p2, 14.0, pieces)
						for piece in pieces:
							for target_surface in [surface, relief_collision_surface]:
								for q in piece:
									var qv: Vector2 = q
									target_surface.add_vertex(Vector3(qv.x, _terrain_mesh_height(qv.x, qv.y) + 0.008, qv.y))
					else:
						var flat_pieces: Array = []
						_subdivide_ground_triangle(p0, p1, p2, 14.0, flat_pieces)
						for piece in flat_pieces:
							for q in piece:
								var qv: Vector2 = q
								surface.add_vertex(Vector3(qv.x, _terrain_mesh_height(qv.x, qv.y) + 0.02, qv.y))
				polygon_added = true
			added = polygon_added
		elif str(geometry.get("type", "")) == "LineString":
			var coords: Array = geometry.get("coordinates", [])
			if kind == "coastline":
				var coast_path := PackedVector2Array()
				for coordinate in coords:
					var coast_point := _geo_to_world(coordinate)
					coast_path.append(Vector2(coast_point.x, coast_point.z))
				if coast_path.size() >= 2:
					_coastline_paths.append(coast_path)
					added = true
			else:
				var width := 5.5 if kind == "waterway" else (8.0 if kind == "water" else 1.6)
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
	_build_coastal_details()
	_commit_tree_instances(tree_positions)


func _is_inside_beach(point: Vector2) -> bool:
	for beach in _beach_polygons:
		if Geometry2D.is_point_in_polygon(point, beach):
			return true
	return false


func _build_coastal_details() -> void:
	if _coastline_paths.is_empty():
		return

	# L'écume suit exactement les trois vagues principales de l'océan.
	# Le bruit animé casse le ruban uniforme en nappes et langues irrégulières.
	var foam_shader := Shader.new()
	foam_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

varying vec3 shore_world_pos;
varying vec4 shore_tint;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float a1 = dot(p.xz, normalize(vec2(0.82, 0.57))) * 0.030 + t * 0.72;
	float a2 = dot(p.xz, normalize(vec2(-0.34, 0.94))) * 0.052 - t * 0.91;
	float a3 = dot(p.xz, normalize(vec2(0.98, -0.18))) * 0.091 + t * 1.18;
	float wave = sin(a1) * 0.34 + sin(a2) * 0.13 + sin(a3) * 0.045;
	VERTEX.y = -0.12 + wave + 0.035;
	shore_world_pos = p;
	shore_tint = COLOR;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += vec2(dot(p, p + vec2(45.32)));
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = shore_world_pos.xz;
	float broad = noise21(p * 0.12 + vec2(TIME * 0.035, -TIME * 0.021));
	float middle = noise21(p * 0.48 + vec2(-TIME * 0.075, TIME * 0.052));
	float fine = noise21(p * 2.4 + vec2(TIME * 0.13, TIME * 0.09));
	float wave_a = sin(p.x * 0.72 + p.y * 0.31 + TIME * 0.8);
	float wave_b = sin(p.x * 1.37 - p.y * 0.83 - TIME * 0.55);
	float wave_pattern = wave_a * 0.34 + wave_b * 0.22 + (middle - 0.5) * 0.72;
	float breakup = smoothstep(-0.24, 0.48, wave_pattern + (broad - 0.5) * 0.5);
	float lace = smoothstep(0.24, 0.76, fine * 0.72 + middle * 0.28);
	float foam_mask = breakup * mix(0.68, 1.0, lace);
	float pulse = 0.82 + 0.18 * sin(TIME * 1.7 + p.x * 0.11);
	ALBEDO = mix(vec3(0.52, 0.68, 0.69), vec3(0.96, 0.99, 0.97), lace);
	ALPHA = shore_tint.a * foam_mask * pulse;
}
"""
	var foam_material := ShaderMaterial.new()
	foam_material.shader = foam_shader
	var foam_surface := _new_surface(foam_material)
	var foam_count := 0
	var rock_transforms: Array[Transform3D] = []
	var rock_colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122

	for coast_path in _coastline_paths:
		for i in range(coast_path.size() - 1):
			var a := coast_path[i]
			var b := coast_path[i + 1]
			var segment := b - a
			var length := segment.length()
			if length < 1.5:
				continue
			var direction := segment / length
			var perpendicular := Vector2(-direction.y, direction.x)
			var midpoint := (a + b) * 0.5
			var sample_left := midpoint + perpendicular * 10.0
			var sample_right := midpoint - perpendicular * 10.0
			var left_height := _terrain_height_at_world(sample_left.x, sample_left.y)
			var right_height := _terrain_height_at_world(sample_right.x, sample_right.y)
			var land_normal := perpendicular if left_height >= right_height else -perpendicular
			var sea_normal := -land_normal
			var sandy := _is_inside_beach(midpoint + land_normal * 5.0) or _is_inside_beach(midpoint + land_normal * 12.0)

			var foam_a_inner := a + sea_normal * 0.35
			var foam_a_outer := a + sea_normal * 3.2
			var foam_b_inner := b + sea_normal * 0.35
			var foam_b_outer := b + sea_normal * 3.2
			var foam_alpha := rng.randf_range(0.28, 0.68)
			foam_surface.set_color(Color(0.88, 0.95, 0.94, foam_alpha))
			foam_surface.add_vertex(Vector3(foam_a_inner.x, 0.055, foam_a_inner.y))
			foam_surface.add_vertex(Vector3(foam_b_inner.x, 0.055, foam_b_inner.y))
			foam_surface.add_vertex(Vector3(foam_b_outer.x, 0.055, foam_b_outer.y))
			foam_surface.add_vertex(Vector3(foam_a_inner.x, 0.055, foam_a_inner.y))
			foam_surface.add_vertex(Vector3(foam_b_outer.x, 0.055, foam_b_outer.y))
			foam_surface.add_vertex(Vector3(foam_a_outer.x, 0.055, foam_a_outer.y))
			foam_count += 1

			if sandy:
				continue
			var rock_steps := maxi(1, int(ceil(length / 9.0)))
			for rock_index in range(rock_steps):
				var t := (float(rock_index) + rng.randf_range(0.2, 0.8)) / float(rock_steps)
				var shoreline := a.lerp(b, t)
				var rock_xz := shoreline + land_normal * rng.randf_range(0.5, 2.8)
				var rock_height := rng.randf_range(0.45, 1.35)
				var rock_scale_x := rng.randf_range(0.65, 2.0)
				var rock_scale_z := rng.randf_range(0.55, 1.65)
				# Le bas du mesh est à y=0 : l'origine doit être légèrement
				# sous le terrain pour éviter l'effet de rochers flottants.
				var rock_y := _terrain_height_at_world(rock_xz.x, rock_xz.y) - 0.08
				var rock_basis := Basis(Vector3(rock_scale_x, 0.0, 0.0), Vector3(0.0, rock_height, 0.0), Vector3(0.0, 0.0, rock_scale_z)).rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				rock_transforms.append(Transform3D(rock_basis, Vector3(rock_xz.x, rock_y, rock_xz.y)))
				var shade := rng.randf_range(0.70, 1.0)
				rock_colors.append(Color(shade * 0.58, shade * 0.60, shade * 0.59, 1.0))

				# Petits galets mêlés aux blocs : ils densifient la ligne de
				# contact avec l'eau sans créer une bordure rocheuse continue.
				if rng.randf() < 0.72:
					var pebble_xz := shoreline + land_normal * rng.randf_range(0.15, 1.15)
					var pebble_height := rng.randf_range(0.16, 0.38)
					var pebble_scale := rng.randf_range(0.22, 0.62)
					var pebble_y := _terrain_height_at_world(pebble_xz.x, pebble_xz.y) - 0.035
					var pebble_basis := Basis(
						Vector3(pebble_scale * rng.randf_range(0.9, 1.5), 0.0, 0.0),
						Vector3(0.0, pebble_height, 0.0),
						Vector3(0.0, 0.0, pebble_scale * rng.randf_range(0.8, 1.4))
					).rotated(Vector3.UP, rng.randf_range(0.0, TAU))
					rock_transforms.append(Transform3D(pebble_basis, Vector3(pebble_xz.x, pebble_y, pebble_xz.y)))
					var pebble_shade := rng.randf_range(0.58, 0.82)
					rock_colors.append(Color(pebble_shade * 0.58, pebble_shade * 0.60, pebble_shade * 0.59, 1.0))

	if foam_count > 0:
		var foam_mesh := foam_surface.commit()
		if foam_mesh != null and foam_mesh.get_surface_count() > 0:
			var foam_instance := MeshInstance3D.new()
			foam_instance.name = "Coastal_Wave_Foam"
			foam_instance.mesh = foam_mesh
			foam_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			foam_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(foam_instance)

	if not rock_transforms.is_empty():
		# Shader minéral procédural : grain, strates irrégulières et humidité
		# à la base. Il complète les futures textures PBR sans les remplacer.
		var rock_shader := Shader.new()
		rock_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 rock_local;
varying vec4 rock_tint;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += vec2(dot(p, p + vec2(45.32)));
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	rock_local = VERTEX;
	rock_tint = COLOR;
}

void fragment() {
	vec2 p = rock_local.xz * 3.2 + vec2(rock_local.y * 1.7, rock_local.y * 0.8);
	float broad = noise21(p * 0.7);
	float grain = noise21(p * 5.4);
	float strata_noise = noise21(p * 1.8);
	float strata = smoothstep(0.42, 0.58,
		0.5 + sin(rock_local.y * 34.0 + strata_noise * 3.8) * 0.5);
	float mineral = 0.78 + broad * 0.22 + (grain - 0.5) * 0.12;
	vec3 stone = rock_tint.rgb * mineral;
	stone *= mix(0.88, 1.08, strata);
	float wet_base = 1.0 - smoothstep(0.08, 0.38, rock_local.y);
	stone = mix(stone, stone * vec3(0.56, 0.63, 0.66), wet_base * 0.48);
	ALBEDO = stone;
	ROUGHNESS = mix(0.96, 0.72, wet_base * 0.65);
	SPECULAR = 0.28;
}
"""
		var rock_material := ShaderMaterial.new()
		rock_material.shader = rock_shader
		var rock_mesh := _make_coastal_rock_mesh()
		rock_mesh.material = rock_material
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = rock_mesh
		multi.instance_count = rock_transforms.size()
		for index in range(rock_transforms.size()):
			multi.set_instance_transform(index, rock_transforms[index])
			multi.set_instance_color(index, rock_colors[index])
		var rocks := MultiMeshInstance3D.new()
		rocks.name = "Coastal_Rock_Formations"
		rocks.multimesh = multi
		rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rocks.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(rocks)
	print("LIBREVILLE STORIES | littoral : %d segments, %d rubans d'écume, %d rochers" % [_coastline_paths.size(), foam_count, rock_transforms.size()])


func _make_coastal_rock_mesh() -> ArrayMesh:
	# Une forme rocheuse facettée et asymétrique, partagée par toutes les
	# instances MultiMesh : davantage de relief sans multiplier les draw calls.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	const SIDES := 9
	var ring_heights := [0.0, 0.18, 0.48, 0.78, 1.0]
	var ring_radii := [0.48, 0.78, 0.70, 0.46, 0.12]
	var rings: Array[PackedVector3Array] = []
	var ring_colors: Array[PackedColorArray] = []
	var phase := rng.randf_range(0.0, TAU)
	for ring_index in range(ring_heights.size()):
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		for side in range(SIDES):
			var angle := TAU * float(side) / float(SIDES) + phase
			var irregularity := rng.randf_range(0.78, 1.22)
			var radius := ring_radii[ring_index] * irregularity
			var y_jitter := rng.randf_range(-0.055, 0.055) if ring_index > 0 and ring_index < 4 else 0.0
			vertices.append(Vector3(cos(angle) * radius, ring_heights[ring_index] + y_jitter, sin(angle) * radius))
			var shade := rng.randf_range(0.72, 1.0) * (1.0 - float(ring_index) * 0.045)
			colors.append(Color(0.58 * shade, 0.61 * shade, 0.60 * shade, 1.0))
		rings.append(vertices)
		ring_colors.append(colors)
	for ring_index in range(rings.size() - 1):
		for side in range(SIDES):
			var next_side := (side + 1) % SIDES
			var a := rings[ring_index][side]
			var b := rings[ring_index][next_side]
			var c := rings[ring_index + 1][next_side]
			var d := rings[ring_index + 1][side]
			var ca := ring_colors[ring_index][side]
			var cb := ring_colors[ring_index][next_side]
			var cc := ring_colors[ring_index + 1][next_side]
			var cd := ring_colors[ring_index + 1][side]
			surface.set_color(ca)
			surface.add_vertex(a)
			surface.set_color(cb)
			surface.add_vertex(b)
			surface.set_color(cc)
			surface.add_vertex(c)
			surface.set_color(ca)
			surface.add_vertex(a)
			surface.set_color(cc)
			surface.add_vertex(c)
			surface.set_color(cd)
			surface.add_vertex(d)
	surface.generate_normals()
	return surface.commit()


func _subdivide_ground_triangle(a: Vector2, b: Vector2, c: Vector2, max_edge: float, out: Array, depth: int = 0) -> void:
	var ab := a.distance_to(b)
	var bc := b.distance_to(c)
	var ca := c.distance_to(a)
	var longest := maxf(ab, maxf(bc, ca))
	if longest <= max_edge or depth >= 9:
		out.append([a, b, c])
		return
	if ab >= bc and ab >= ca:
		var m := (a + b) * 0.5
		_subdivide_ground_triangle(a, m, c, max_edge, out, depth + 1)
		_subdivide_ground_triangle(m, b, c, max_edge, out, depth + 1)
	elif bc >= ca:
		var m2 := (b + c) * 0.5
		_subdivide_ground_triangle(a, b, m2, max_edge, out, depth + 1)
		_subdivide_ground_triangle(a, m2, c, max_edge, out, depth + 1)
	else:
		var m3 := (c + a) * 0.5
		_subdivide_ground_triangle(a, b, m3, max_edge, out, depth + 1)
		_subdivide_ground_triangle(m3, b, c, max_edge, out, depth + 1)


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
	return _terrain_height_at_world(point.x, point.y) + 0.006


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
		# Aucun arbre ne doit apparaître sur une chaussée ou un trottoir.
		if _is_near_road(candidate, 2.0):
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
			return Color(0.76, 0.68, 0.49)  # sable chaud des plages de Libreville
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
		var props: Dictionary = feature.get("properties", {})
		var osm_id := int(props.get("osm_id", 0))
		# Conserve le contour en coordonnées locales WorldMap pour contrôler les destinations de téléportation.
		if osm_id > 0 and rings[0].size() >= 4:
			var polygon := PackedVector2Array()
			for coordinate in rings[0]:
				var world_point := _geo_to_world(coordinate)
				polygon.append(Vector2(world_point.x, world_point.z))
			_neighbourhood_polygons[osm_id] = polygon
			_neighbourhood_arrondissements[osm_id] = str(props.get("arrondissement", ""))
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


func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 4:
		return false
	var inside := false
	var previous := polygon.size() - 1
	for current in range(polygon.size()):
		var a := polygon[current]
		var b := polygon[previous]
		if (a.y > point.y) != (b.y > point.y):
			var crossing_x := (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
			if point.x < crossing_x:
				inside = not inside
		previous = current
	return inside


func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var twice_area := 0.0
	var centroid_x := 0.0
	var centroid_y := 0.0
	for index in range(polygon.size() - 1):
		var a := polygon[index]
		var b := polygon[index + 1]
		var cross := a.x * b.y - b.x * a.y
		twice_area += cross
		centroid_x += (a.x + b.x) * cross
		centroid_y += (a.y + b.y) * cross
	if absf(twice_area) < 0.001:
		var average := Vector2.ZERO
		for point in polygon:
			average += point
		return average / maxf(1.0, float(polygon.size()))
	return Vector2(centroid_x / (3.0 * twice_area), centroid_y / (3.0 * twice_area))


func _find_road_texture(folder_name: String, file_stem: String) -> Texture2D:
	# Les packs restent dans leur dossier d'origine (xxx_4k.gltf/textures). On teste les
	# chemins directement : fonctionne dans l'éditeur comme dans un export.
	if folder_name == "":
		return null
	var base := "res://%s/textures/%s" % [folder_name, file_stem]
	for extension in ["jpg", "jpeg", "png", "webp", "tga", "bmp"]:
		var path := "%s.%s" % [base, extension]
		if ResourceLoader.exists(path):
			var loaded := load(path) as Texture2D
			if loaded != null:
				return loaded
			push_warning("Impossible de charger la texture de route : " + path)
	return null


func _find_asphalt_map(file_stem: String) -> Texture2D:
	return _find_road_texture("asphalt_02_4k.gltf", file_stem)


func _make_road_material(folder_name: String, stem: String, fallback: String, normal_scale: float) -> StandardMaterial3D:
	var material := _make_material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	var albedo := _find_road_texture(folder_name, stem + "_diff_4k")
	var normal := _find_road_texture(folder_name, stem + "_nor_gl_4k")
	var rough := _find_road_texture(folder_name, stem + "_rough_4k")
	var arm := _find_road_texture(folder_name, stem + "_arm_4k")
	if albedo != null:
		print("LIBREVILLE STORIES | textures 4K chargées : " + folder_name)
	else:
		if fallback == "asphalt":
			albedo = _make_asphalt_texture()
		elif fallback == "dirt":
			albedo = _make_ground_texture(Color(0.46, 0.31, 0.21), 20261123)
		else:
			albedo = _make_ground_texture(Color(0.62, 0.60, 0.56), 20261124)
	material.albedo_texture = albedo
	if normal == null and fallback == "asphalt":
		normal = _make_asphalt_normal_texture()
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = normal_scale
	material.roughness = 0.94
	material.metallic = 0.0
	if rough != null:
		material.roughness_texture = rough
	elif arm != null:
		# Carte ARM : R = occlusion, G = rugosité, B = métal.
		material.roughness_texture = arm
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.ao_enabled = true
		material.ao_texture = arm
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.ao_light_affect = 0.35
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _make_asphalt_shader_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ROAD_SHADER_CODE
	material.shader = shader
	var albedo_a := _find_road_texture("asphalt_02_4k.gltf", "asphalt_02_diff_4k")
	var normal_a := _find_road_texture("asphalt_02_4k.gltf", "asphalt_02_nor_gl_4k")
	var rough_a := _find_road_texture("asphalt_02_4k.gltf", "asphalt_02_rough_4k")
	if albedo_a != null:
		print("LIBREVILLE STORIES | textures 4K chargées : asphalt_02_4k.gltf")
	else:
		albedo_a = _make_asphalt_texture()
	if normal_a == null:
		normal_a = _make_asphalt_normal_texture()
	var albedo_b: Texture2D = null
	var albedo_c: Texture2D = null
	if load_extra_road_textures:
		albedo_b = _find_road_texture("asphalt_floor_4k.gltf", "asphalt_floor_diff_4k")
		albedo_c = _find_road_texture("worn_asphalt_4k.gltf", "worn_asphalt_diff_4k")
	if albedo_b == null:
		albedo_b = _make_ground_texture(Color(0.55, 0.55, 0.55), 20261125)
	if albedo_c == null:
		albedo_c = _make_ground_texture(Color(0.46, 0.31, 0.21), 20261126)
	var noise := FastNoiseLite.new()
	noise.seed = 20261127
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var noise_texture := ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	material.set_shader_parameter("albedo_a", albedo_a)
	material.set_shader_parameter("normal_a", normal_a)
	if rough_a != null:
		material.set_shader_parameter("rough_a", rough_a)
	material.set_shader_parameter("albedo_b", albedo_b)
	material.set_shader_parameter("albedo_c", albedo_c)
	material.set_shader_parameter("noise_tex", noise_texture)
	material.set_shader_parameter("normal_strength", 0.5)
	return material


func _build_road_materials() -> void:
	_road_materials["asphalt"] = _make_asphalt_shader_material()
	if load_extra_road_textures:
		_road_materials["dirt"] = _make_road_material("worn_asphalt_4k.gltf", "worn_asphalt", "dirt", 0.6)
		_road_materials["paving"] = _make_road_material("asphalt_floor_4k.gltf", "asphalt_floor", "paving", 0.5)
	else:
		_road_materials["dirt"] = _make_road_material("", "", "dirt", 0.6)
		_road_materials["paving"] = _make_road_material("", "", "paving", 0.5)
	_road_material = _road_materials["asphalt"]
	var sidewalk := _make_material(Color.WHITE)
	sidewalk.vertex_color_use_as_albedo = true
	sidewalk.albedo_texture = _make_sidewalk_texture()
	sidewalk.roughness = 0.95
	sidewalk.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_road_materials["sidewalk"] = sidewalk
	for key in ["curb", "skirt", "marking", "crosswalk", "median"]:
		var plain := _make_material(Color.WHITE)
		plain.vertex_color_use_as_albedo = true
		plain.roughness = 0.9 if (key == "curb" or key == "skirt" or key == "median") else 0.7
		_road_materials[key] = plain


func _make_ground_texture(base: Color, noise_seed: int) -> Texture2D:
	const SIZE := 256
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var grain := FastNoiseLite.new()
	grain.seed = noise_seed + 1
	grain.frequency = 0.35
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var v := 1.0 + noise.get_noise_2d(float(x), float(y)) * 0.18 + grain.get_noise_2d(float(x), float(y)) * 0.10
			image.set_pixel(x, y, Color(clampf(base.r * v, 0.0, 1.0), clampf(base.g * v, 0.0, 1.0), clampf(base.b * v, 0.0, 1.0), 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _make_asphalt_texture() -> Texture2D:
	# Bitume haute définition procédural : variations larges, grain fin et granulats.
	# La texture est répétée tous les 4 m par _add_road_quad pour garder une échelle crédible.
	const SIZE := 512
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 20261117
	broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	broad_noise.frequency = 0.018
	broad_noise.fractal_octaves = 3
	broad_noise.fractal_gain = 0.48
	var grain_noise := FastNoiseLite.new()
	grain_noise.seed = 20261118
	grain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grain_noise.frequency = 0.19
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	for y in range(SIZE):
		for x in range(SIZE):
			var broad := broad_noise.get_noise_2d(float(x), float(y))
			var grain := grain_noise.get_noise_2d(float(x), float(y))
			var aggregate := rng.randf_range(-0.045, 0.045)
			# Petites traces irrégulières, sans motif de grille visible.
			var fleck := 0.035 if rng.randf() > 0.992 else 0.0
			var shade := clampf(0.205 + broad * 0.045 + grain * 0.025 + aggregate + fleck, 0.105, 0.34)
			image.set_pixel(x, y, Color(shade * 1.015, shade * 1.01, shade * 0.99, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _make_asphalt_normal_texture() -> Texture2D:
	# Relief microscopique du granulat pour casser l'aspect d'un simple aplat.
	const SIZE := 512
	var noise := FastNoiseLite.new()
	noise.seed = 20261120
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.24
	noise.fractal_octaves = 2
	var heightmap := Image.create(SIZE, SIZE, false, Image.FORMAT_RF)
	for y in range(SIZE):
		for x in range(SIZE):
			var h := 0.5 + noise.get_noise_2d(float(x), float(y)) * 0.22
			heightmap.set_pixel(x, y, Color(h, h, h, 1.0))
	heightmap.bump_map_to_normal_map(3.0)
	heightmap.generate_mipmaps()
	return ImageTexture.create_from_image(heightmap)


func _make_sidewalk_texture() -> Texture2D:
	# Dalles de béton de 0,5 m (la texture couvre 2 m) : joints nets, teinte variable par dalle.
	const SIZE := 256
	const SLAB := 64
	var grain := FastNoiseLite.new()
	grain.seed = 20261122
	grain.frequency = 0.5
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var slab_x := int(x / SLAB)
			var slab_y := int(y / SLAB)
			var slab_shade := 0.92 + float((slab_x * 7 + slab_y * 13) % 5) * 0.025
			var shade := slab_shade + grain.get_noise_2d(float(x), float(y)) * 0.05
			if x % SLAB < 2 or y % SLAB < 2:
				shade *= 0.62
			shade = clampf(shade, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade * 0.80, shade * 0.79, shade * 0.76, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _polygon_area_abs(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var twice_area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		twice_area += a.x * b.y - b.x * a.y
	return absf(twice_area) * 0.5


func _is_water_environment_polygon(kind: String, props: Dictionary) -> bool:
	var normalized_kind := kind.to_lower()
	var natural := str(props.get("natural", "")).to_lower()
	var water := str(props.get("water", "")).to_lower()
	var landuse := str(props.get("landuse", "")).to_lower()
	var is_water_kind := normalized_kind in ["water", "water_area", "lake", "river", "sea", "ocean", "lagoon", "reservoir", "coastline"]
	var is_water_tagged := natural == "water" or water in ["lake", "river", "reservoir", "pond", "basin"] or landuse in ["reservoir", "basin"]
	return is_water_kind or is_water_tagged


func _clip_polygon_away_from_roads(subject: PackedVector2Array, extra_margin: float = 0.0) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [subject]
	if subject.size() < 3 or _road_clearance_grid.is_empty():
		return pieces
	const cell_size := 128.0
	var min_x := subject[0].x
	var max_x := subject[0].x
	var min_z := subject[0].y
	var max_z := subject[0].y
	for point in subject:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.y)
		max_z = maxf(max_z, point.y)
	var candidates: Array = []
	var seen: Dictionary = {}
	for cx in range(int(floor(min_x / cell_size)) - 1, int(floor(max_x / cell_size)) + 2):
		for cz in range(int(floor(min_z / cell_size)) - 1, int(floor(max_z / cell_size)) + 2):
			for segment in _road_clearance_grid.get(Vector2i(cx, cz), []):
				var key := str(segment.a) + "|" + str(segment.b)
				if seen.has(key):
					continue
				seen[key] = true
				var a: Vector2 = segment.a
				var b: Vector2 = segment.b
				if maxf(a.x, b.x) < min_x - 32.0 or minf(a.x, b.x) > max_x + 32.0 or maxf(a.y, b.y) < min_z - 32.0 or minf(a.y, b.y) > max_z + 32.0:
					continue
				candidates.append(segment)
	# OSM segments are clipped one by one; only the local 128 m grid is searched.
	for segment in candidates:
		if pieces.is_empty():
			break
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var direction := (b - a).normalized()
		if direction.length_squared() < 0.0001:
			continue
		var normal := Vector2(-direction.y, direction.x)
		var radius := float(segment.radius) + extra_margin
		var cap := 0.35
		var corridor := PackedVector2Array([
			a - direction * cap + normal * radius,
			b + direction * cap + normal * radius,
			b + direction * cap - normal * radius,
			a - direction * cap - normal * radius
		])
		var next_pieces: Array[PackedVector2Array] = []
		for piece in pieces:
			var clipped := Geometry2D.clip_polygons(piece, corridor)
			for result_piece in clipped:
				if result_piece.size() >= 3:
					next_pieces.append(result_piece)
		pieces = next_pieces
	return pieces


func _load_roads() -> void:
	var data := _read_geojson("res://data/osm/roads.geojson")
	if data.is_empty():
		push_warning("roads.geojson absent : carte routière non chargée.")
		return
	var started_ms := Time.get_ticks_msec()
	var features: Array = data.get("features", [])
	_load_lamp_parts()
	_add_road_name_labels(features)
	# 1. Découpe en tronçons + registre des nœuds (carrefours, T, croisements).
	var parts: Array[Dictionary] = []
	var node_registry: Dictionary = {}
	for feature in features:
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
		var kind := str(props.get("highway", "residential"))
		var width := _road_width(kind, props)
		var surface_key := _road_surface_key(kind, props)
		var sidewalk_mode := _road_sidewalk_mode(props, kind)
		if surface_key == "dirt":
			sidewalk_mode = "none"
		for line in lines:
			if line.size() < 2:
				continue
			var points: Array[Vector3] = []
			var keys: Array[String] = []
			for coordinate in line:
				var point := _geo_to_road_point(coordinate)
				if points.is_empty() or Vector2(points[points.size() - 1].x - point.x, points[points.size() - 1].z - point.z).length() > 0.05:
					points.append(point)
					keys.append(_road_junction_key(coordinate))
			if points.size() < 2:
				continue
			var part_index := parts.size()
			var length := 0.0
			for i in range(points.size() - 1):
				length += Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).length()
			var part_sidewalk := sidewalk_mode
			if part_sidewalk != "none" and keys[0] == keys[keys.size() - 1] and length < 300.0 and points.size() >= 4:
				# Rond-point : trottoir seulement sur le côté extérieur (pas sur l'îlot central).
				var centroid := Vector2.ZERO
				for p in points:
					centroid += Vector2(p.x, p.z)
				centroid /= float(points.size())
				var mid := int(points.size() / 2)
				var travel := Vector2(points[mid + 1].x - points[mid].x, points[mid + 1].z - points[mid].z) if mid + 1 < points.size() else Vector2.RIGHT
				var left_normal := Vector2(-travel.y, travel.x)
				var to_center := centroid - Vector2(points[mid].x, points[mid].z)
				part_sidewalk = "right" if left_normal.dot(to_center) > 0.0 else "left"
			for i in range(keys.size()):
				var entries: PackedFloat32Array = node_registry.get(keys[i], PackedFloat32Array())
				entries.append(float(part_index))
				entries.append(width * 0.5)
				entries.append(1.0 if (i == 0 or i == keys.size() - 1) else 0.0)
				node_registry[keys[i]] = entries
			parts.append({
				"props": props,
				"kind": kind,
				"width": width,
				"surface": surface_key,
				"sidewalk": part_sidewalk,
				"points": _densify_polyline(points, ROAD_MAX_STEP),
				"orig_points": points,
				"keys": keys,
				"length": length,
				"tint": _road_tint(kind, props, surface_key),
				"class_lift": _road_class_lift(kind),
				"oneway_sign": _road_oneway_sign(props),
			})
	_build_road_hit_grid(parts)
	# 2. Regroupement spatial : chaque lot de meshes couvre une zone compacte,
	#    ce qui permet au moteur d'éliminer les zones hors champ.
	var tiles: Dictionary = {}
	for part_index in range(parts.size()):
		var first_point: Vector3 = parts[part_index].points[0]
		var tile := Vector2i(floori(first_point.x / ROAD_TILE_SIZE), floori(first_point.z / ROAD_TILE_SIZE))
		if not tiles.has(tile):
			tiles[tile] = []
		tiles[tile].append(part_index)
	var tile_keys: Array = tiles.keys()
	tile_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var patched: Dictionary = {}
	var tile_counter := 0
	for tile_key in tile_keys:
		var surfaces := _new_road_surfaces()
		var collision := SurfaceTool.new()
		collision.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part_index in tiles[tile_key]:
			_build_road_part(parts[part_index], part_index, surfaces, collision, node_registry, patched)
			_road_count += 1
		_commit_road_surfaces(surfaces, collision, "%03d" % tile_counter)
		_commit_lamps("%03d" % tile_counter)
		tile_counter += 1
	_road_hit_grid.clear()
	print("LIBREVILLE STORIES | VERSION v7 · décor vert OSM %s | réseau routier : %d tronçons, %d zones, %d lampadaires, %d ms" % ["ACTIVÉ" if render_green_areas else "MASQUÉ", parts.size(), tile_counter, _lamp_count, Time.get_ticks_msec() - started_ms])


func _add_road_name_labels(features: Array) -> void:
	var sorted_features: Array = features.duplicate()
	sorted_features.sort_custom(Callable(self, "_compare_road_features"))
	for feature in sorted_features:
		if _road_labels >= MAX_ROAD_LABELS:
			return
		var props: Dictionary = feature.get("properties", {})
		var label_text := str(props.get("name", "")).strip_edges()
		if label_text == "":
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var lines: Array = []
		match str(geometry.get("type", "")):
			"LineString":
				lines.append(geometry.get("coordinates", []))
			"MultiLineString":
				lines = geometry.get("coordinates", [])
			_:
				continue
		for candidate_line in lines:
			if candidate_line.size() >= 2:
				var midpoint: Array = candidate_line[int(candidate_line.size() / 2)]
				_add_map_label(label_text, _geo_to_road_point(midpoint) + Vector3.UP * 0.55, Color(0.92, 0.95, 1.0), 280.0)
				_road_labels += 1
				break


func _new_road_surfaces() -> Dictionary:
	var surfaces: Dictionary = {}
	for key in ROAD_TEXTURED_KEYS:
		var textured := _new_surface(_road_materials[key])
		if key == "sidewalk":
			textured.set_smooth_group(-1)
		textured.set_color(Color.WHITE)
		textured.set_uv(Vector2.ZERO)
		textured.set_uv2(Vector2.ZERO)
		surfaces[key] = textured
	var plain_colors := {
		"median": Color(0.52, 0.51, 0.49),
		"curb": Color(0.70, 0.69, 0.66),
		"skirt": Color(0.42, 0.40, 0.36),
		"marking": Color(0.96, 0.96, 0.90),
		"crosswalk": Color(0.96, 0.96, 0.92),
	}
	for key in plain_colors.keys():
		var plain := _new_surface(_road_materials[key])
		plain.set_smooth_group(-1)
		plain.set_color(plain_colors[key])
		surfaces[key] = plain
	return surfaces


func _commit_road_surfaces(surfaces: Dictionary, collision: SurfaceTool, tile_name: String) -> void:
	for key in surfaces.keys():
		var surface: SurfaceTool = surfaces[key]
		var textured: bool = key in ROAD_TEXTURED_KEYS
		if textured and not bool(surface.get_meta("used", false)):
			continue
		surface.generate_normals()
		if textured:
			surface.generate_tangents()
		var mesh := surface.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var instance := MeshInstance3D.new()
		instance.name = ("OSM_Roads_%s" % tile_name) if key == "asphalt" else ("OSM_Roads_%s_%s" % [str(key).capitalize(), tile_name])
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if key != "asphalt" and key != "dirt" and key != "paving":
			# Bordures, trottoirs, marquages : inutiles au loin.
			instance.visibility_range_end = ROAD_DETAIL_VISIBILITY
		add_child(instance)
	if not road_collision:
		return
	var collision_mesh := collision.commit()
	if collision_mesh == null or collision_mesh.get_surface_count() == 0:
		return
	var shape := collision_mesh.create_trimesh_shape() as ConcavePolygonShape3D
	if shape == null:
		push_warning("Collision routière impossible pour la zone " + tile_name)
		return
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = "OSM_Roads_Collision_" + tile_name
	body.collision_layer = 1
	body.collision_mask = 1
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	body.add_child(collision_shape)
	add_child(body)


func _build_road_part(part: Dictionary, part_index: int, surfaces: Dictionary, collision: SurfaceTool, node_registry: Dictionary, patched: Dictionary) -> void:
	var points: Array[Vector3] = part.points
	var orig_points: Array[Vector3] = part.orig_points
	var keys: Array[String] = part.keys
	var props: Dictionary = part.props
	var kind: String = part.kind
	var width: float = part.width
	var surface_key: String = part.surface
	var sidewalk_mode: String = part.sidewalk
	var road_surface: SurfaceTool = surfaces[surface_key]
	var half := width * 0.5
	var lift: float = ROAD_LIFT + float(part.class_lift)
	var last := points.size() - 1
	_set_uv_origin(points[0])
	road_surface.set_color(part.tint)
	# Raccords aux carrefours (une seule fois par nœud).
	for end_slot in range(2):
		var end_index := 0 if end_slot == 0 else last
		var node_key: String = keys[0] if end_slot == 0 else keys[keys.size() - 1]
		var entries: PackedFloat32Array = node_registry.get(node_key, PackedFloat32Array())
		var entry_count := int(entries.size() / 3)
		if entry_count >= 3 and not patched.has(node_key):
			patched[node_key] = true
			var patch_radius := 2.2
			for e in range(entry_count):
				patch_radius = maxf(patch_radius, entries[e * 3 + 1])
			_add_junction_patch(road_surface, points[end_index], minf(patch_radius, 9.0))
	# Chaussée : bandes longitudinales ~7 m, chaque sommet posé sur le relief exact.
	var strips := maxi(2, ceili(width / 7.0))
	var draped: Array = []
	for k in range(strips + 1):
		var offset := half - width * float(k) / float(strips)
		var line := _offset_road_polyline(points, offset)
		var line_draped: Array[Vector3] = []
		for p in line:
			line_draped.append(_rp(p, lift))
		draped.append(line_draped)
	for join_index in range(1, last):
		var incoming := Vector2(points[join_index].x - points[join_index - 1].x, points[join_index].z - points[join_index - 1].z).normalized()
		var outgoing := Vector2(points[join_index + 1].x - points[join_index].x, points[join_index + 1].z - points[join_index].z).normalized()
		if incoming.dot(outgoing) < 0.97:
			_add_road_round_join(road_surface, points[join_index], half)
	var lane_count := _road_lane_count(props)
	var is_oneway := _road_is_oneway(props)
	var has_lane_marking := (lane_count >= 2 or kind in ["trunk", "primary", "secondary"]) and surface_key == "asphalt"
	var crosswalk_start := -1.0
	var crosswalk_end := -1.0
	if kind in ["primary", "secondary", "tertiary", "trunk"]:
		crosswalk_start = _junction_clearance(node_registry.get(keys[0], PackedFloat32Array()), part_index, true)
		crosswalk_end = _junction_clearance(node_registry.get(keys[keys.size() - 1], PackedFloat32Array()), part_index, true)
	var marking_surface: SurfaceTool = surfaces["marking"]
	for i in range(last):
		var a := points[i]
		var b := points[i + 1]
		var seg_len := Vector2(b.x - a.x, b.z - a.z).length()
		if seg_len < 0.08:
			continue
		for k in range(strips):
			var l0: Array[Vector3] = draped[k]
			var l1: Array[Vector3] = draped[k + 1]
			var across0 := 1.0 - 2.0 * float(k) / float(strips)
			var across1 := 1.0 - 2.0 * float(k + 1) / float(strips)
			_add_road_quad_uv2(road_surface, l0[i], l1[i], l1[i + 1], l0[i + 1], across0, across1)
		if road_collision:
			# Une seule bande de collision par tronçon (bords seulement) : suffisant et léger.
			var edge_left: Array[Vector3] = draped[0]
			var edge_right: Array[Vector3] = draped[strips]
			_add_plain_quad(collision, edge_left[i], edge_right[i], edge_right[i + 1], edge_left[i + 1])
		if has_lane_marking:
			_add_road_lane_markings(marking_surface, a, b, width, lane_count, is_oneway)
			if kind in ["trunk", "primary", "motorway"]:
				var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
				var perp := Vector3(-direction.y, 0.0, direction.x)
				_add_marking_quad(marking_surface, a + perp * (half - 0.18), b + perp * (half - 0.18), 0.06)
				_add_marking_quad(marking_surface, a - perp * (half - 0.18), b - perp * (half - 0.18), 0.06)
		if i == 0 and crosswalk_start >= 0.0:
			_add_crosswalk(surfaces["crosswalk"], a, Vector2(b.x - a.x, b.z - a.z).normalized(), width, crosswalk_start + 1.9)
		if i == last - 1 and crosswalk_end >= 0.0:
			_add_crosswalk(surfaces["crosswalk"], b, Vector2(a.x - b.x, a.z - b.z).normalized(), width, crosswalk_end + 1.9)
	# Trottoirs : découpés aux carrefours, T, entrées de service et voies voisines.
	if sidewalk_mode != "none":
		var cuts := _road_part_cuts(part_index, keys, orig_points, node_registry)
		for run in _sidewalk_runs(float(part.length), cuts):
			var slice := _slice_polyline(points, run.x, run.y)
			if slice.size() >= 2:
				_add_sidewalk_strip(surfaces, collision, slice, width, sidewalk_mode, part_index, lift, part)


func _junction_clearance(entries: PackedFloat32Array, part_index: int, self_is_end: bool) -> float:
	# Retourne le rayon à dégager autour d'un nœud partagé, ou -1 s'il n'y a pas de carrefour
	# (impasse, ou simple prolongement d'une voie par une autre).
	var count := int(entries.size() / 3)
	if count < 2:
		return -1.0
	var others := 0
	var other_ends := 0
	var other_half := 0.0
	for e in range(count):
		if int(entries[e * 3]) == part_index:
			continue
		others += 1
		other_half = maxf(other_half, entries[e * 3 + 1])
		if entries[e * 3 + 2] > 0.5:
			other_ends += 1
	if others == 0:
		return -1.0
	if others == 1 and self_is_end and other_ends == 1:
		return -1.0
	return other_half + JUNCTION_CLEARANCE


func _road_part_cuts(part_index: int, keys: Array[String], points: Array[Vector3], node_registry: Dictionary) -> Array[Vector2]:
	var cuts: Array[Vector2] = []
	var distance := 0.0
	var last := keys.size() - 1
	for i in range(keys.size()):
		if i > 0:
			distance += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
		var radius := _junction_clearance(node_registry.get(keys[i], PackedFloat32Array()), part_index, i == 0 or i == last)
		if radius >= 0.0:
			cuts.append(Vector2(distance, radius))
	return cuts


func _sidewalk_runs(total_length: float, cuts: Array[Vector2]) -> Array[Vector2]:
	var runs: Array[Vector2] = []
	var cursor := 0.0
	for cut in cuts:
		var gap_start := cut.x - cut.y
		var gap_end := cut.x + cut.y
		if gap_start > cursor + MIN_SIDEWALK_RUN:
			runs.append(Vector2(cursor, gap_start))
		cursor = maxf(cursor, gap_end)
	if total_length > cursor + MIN_SIDEWALK_RUN:
		runs.append(Vector2(cursor, total_length))
	return runs


func _slice_polyline(points: Array[Vector3], from_distance: float, to_distance: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var travelled := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		if seg < 0.0001:
			continue
		var seg_start := travelled
		travelled += seg
		if travelled <= from_distance or seg_start >= to_distance:
			continue
		var t0 := clampf((from_distance - seg_start) / seg, 0.0, 1.0)
		var t1 := clampf((to_distance - seg_start) / seg, 0.0, 1.0)
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		if result.is_empty():
			result.append(p0)
		if Vector2(result[result.size() - 1].x - p1.x, result[result.size() - 1].z - p1.z).length() > 0.05:
			result.append(p1)
	return result


func _add_sidewalk_strip(surfaces: Dictionary, collision: SurfaceTool, run: Array[Vector3], width: float, mode: String, part_index: int, lift: float, part: Dictionary) -> void:
	var half := width * 0.5
	var kind: String = part.kind
	var oneway_sign := int(part.oneway_sign)
	var can_median := oneway_sign != 0 and kind in ["trunk", "primary", "secondary", "tertiary"]
	var spacing := _lamp_spacing(kind)
	if kind in ["residential", "unclassified"] and str(part.props.get("name", "")).strip_edges() == "":
		spacing = 0.0
	var lamp_scale := 1.25 if kind in ["trunk", "primary"] else 1.0
	var sides: Array[float] = []
	if mode in ["both", "left"]:
		sides.append(1.0)
	if mode in ["both", "right"]:
		sides.append(-1.0)
	var curb_surface: SurfaceTool = surfaces["curb"]
	var walk_surface: SurfaceTool = surfaces["sidewalk"]
	var median_surface: SurfaceTool = surfaces["median"]
	_set_uv_origin(run[0])
	walk_surface.set_color(Color(0.74, 0.74, 0.73))
	var count := run.size()
	for side_sign in sides:
		var edge := _offset_road_polyline(run, half * side_sign)
		var curb := _offset_road_polyline(run, (half + CURB_WIDTH) * side_sign)
		var outer_full := _offset_road_polyline(run, (half + CURB_WIDTH + SIDEWALK_WIDTH) * side_sign)
		var outer: Array[Vector3] = []
		var gaps := PackedFloat32Array()
		for i in range(count):
			var gap := -1.0
			if can_median:
				var j := mini(i, count - 2)
				var geometry_dir := Vector2(run[j + 1].x - run[j].x, run[j + 1].z - run[j].z).normalized()
				var outward_2d := Vector2(-geometry_dir.y, geometry_dir.x) * side_sign
				gap = _median_gap(edge[i], outward_2d, geometry_dir * float(oneway_sign), part_index)
			gaps.append(gap)
			if gap > 0.0:
				# Terre-plein : chaque chaussée construit sa moitié, elles se rejoignent au milieu.
				var median_width := clampf((gap - 2.0 * CURB_WIDTH) * 0.5, 0.0, 9.0)
				outer.append(curb[i] + (outer_full[i] - curb[i]) * (median_width / SIDEWALK_WIDTH))
			else:
				outer.append(outer_full[i])
		# Altitudes par sommet : bord de chaussée, dessus du trottoir, sol sous le bord extérieur.
		var edge_y := PackedFloat32Array()
		var top_y := PackedFloat32Array()
		var ground_y := PackedFloat32Array()
		for i in range(count):
			var ey := _terrain_mesh_height(edge[i].x, edge[i].z) + lift
			var cy := _terrain_mesh_height(curb[i].x, curb[i].z)
			var oy := _terrain_mesh_height(outer[i].x, outer[i].z)
			edge_y.append(ey)
			top_y.append(maxf(ey + CURB_HEIGHT, maxf(cy, oy) + 0.07))
			ground_y.append(oy)
		var first_built := -1
		var last_built := -1
		for i in range(count - 1):
			var is_median := gaps[i] > 0.0 and gaps[i + 1] > 0.0
			if is_median and (gaps[i] < 2.0 * CURB_WIDTH + 0.5 or gaps[i + 1] < 2.0 * CURB_WIDTH + 0.5):
				continue
			var mid_curb := (curb[i] + curb[i + 1]) * 0.5
			var mid_outer := (outer[i] + outer[i + 1]) * 0.5
			if _point_on_other_road(mid_curb.x, mid_curb.z, part_index) or _point_on_other_road(mid_outer.x, mid_outer.z, part_index):
				continue
			if first_built < 0:
				first_built = i
			last_built = i + 1
			var e0 := Vector3(edge[i].x, edge_y[i], edge[i].z)
			var e1 := Vector3(edge[i + 1].x, edge_y[i + 1], edge[i + 1].z)
			var ct0 := Vector3(curb[i].x, top_y[i], curb[i].z)
			var ct1 := Vector3(curb[i + 1].x, top_y[i + 1], curb[i + 1].z)
			var ot0 := Vector3(outer[i].x, top_y[i], outer[i].z)
			var ot1 := Vector3(outer[i + 1].x, top_y[i + 1], outer[i + 1].z)
			# Bordure biseautée (une seule face), puis dalle de trottoir ou terre-plein planté.
			_add_plain_quad(curb_surface, e0, e1, ct1, ct0)
			if is_median:
				_add_plain_quad(median_surface, ct0, ot0, ot1, ct1)
			else:
				_add_textured_quad(walk_surface, ct0, ot0, ot1, ct1, SIDEWALK_UV_METERS)
			if road_collision:
				# Collision en rampe douce : le joueur monte sur le trottoir sans buter.
				_add_plain_quad(collision, e0, ct0, ct1, e1)
				_add_plain_quad(collision, ct0, ot0, ot1, ct1)
			if not is_median:
				var dir := Vector2(run[i + 1].x - run[i].x, run[i + 1].z - run[i].z).normalized()
				var outward := Vector3(-dir.y, 0.0, dir.x) * side_sign
				_add_sidewalk_skirt(surfaces, collision, ot0, ot1, ground_y[i], ground_y[i + 1], outward)
		# Bouts du trottoir fermés (pas de dalle creuse vue de côté).
		for end_index in [first_built, last_built]:
			if end_index < 0:
				continue
			var top_edge := Vector3(edge[end_index].x, top_y[end_index], edge[end_index].z)
			var top_outer := Vector3(outer[end_index].x, top_y[end_index], outer[end_index].z)
			var base_outer := Vector3(outer[end_index].x, ground_y[end_index], outer[end_index].z)
			var base_edge := Vector3(edge[end_index].x, edge_y[end_index], edge[end_index].z)
			_add_plain_quad(curb_surface, top_edge, top_outer, base_outer, base_edge)
		# Lampadaires : décalés d'une demi-période entre les deux côtés ; une seule rive
		# pour les petites rues ; un côté sur deux dans un terre-plein (pas de doublon).
		if spacing > 0.0 and not (kind in ["residential", "unclassified"] and side_sign > 0.0):
			var lamp_line := _offset_road_polyline(run, (half + CURB_WIDTH + 0.6) * side_sign)
			_place_lamps_along(run, lamp_line, top_y, gaps, side_sign, spacing, 0.0 if side_sign > 0.0 else spacing * 0.5, lamp_scale, part_index)


func _road_oneway_sign(props: Dictionary) -> int:
	var value := str(props.get("oneway", "")).to_lower()
	if value in ["yes", "true", "1"]:
		return 1
	if value == "-1":
		return -1
	return 0


func _median_gap(edge_point: Vector3, outward: Vector2, travel: Vector2, part_index: int) -> float:
	# Largeur libre entre ce bord de chaussée et la chaussée voisine roulant en sens
	# inverse, située de ce côté-ci : c'est l'emplacement du terre-plein central.
	var cell := Vector2i(floori(edge_point.x / ROAD_HIT_CELL), floori(edge_point.z / ROAD_HIT_CELL))
	var point := Vector2(edge_point.x, edge_point.z)
	var best := -1.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(cell.x + dx, cell.y + dz)
			if not _road_hit_grid.has(key):
				continue
			for segment in _road_hit_grid[key]:
				if int(segment[5]) == part_index or segment[6] < 0.5 or segment[7] < 0.5:
					continue
				if Vector2(segment[8], segment[9]).dot(travel) > -0.6:
					continue
				var nearest := Geometry2D.get_closest_point_to_segment(point, Vector2(segment[0], segment[1]), Vector2(segment[2], segment[3]))
				if (nearest - point).dot(outward) <= 0.0:
					continue
				var gap := point.distance_to(nearest) - float(segment[4])
				if gap > 0.4 and gap < MEDIAN_MAX_GAP and (best < 0.0 or gap < best):
					best = gap
	return best


func _lamp_spacing(kind: String) -> float:
	match kind:
		"trunk", "primary":
			return 36.0
		"secondary":
			return 40.0
		"tertiary":
			return 52.0
		"residential", "unclassified":
			return 70.0
	return 0.0


func _load_lamp_parts() -> void:
	_lamp_parts.clear()
	_lamp_batch.clear()
	_lamp_count = 0
	if not ResourceLoader.exists(LAMP_PATH):
		push_warning("Modèle de lampadaire absent : " + LAMP_PATH)
		return
	var packed := load(LAMP_PATH) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate() as Node3D
	if root == null:
		return
	_collect_lamp_parts(root, Transform3D.IDENTITY)
	root.free()
	_merge_lamp_parts()


func _merge_lamp_parts() -> void:
	# Fusionne les 6 pièces du lampadaire en un seul mesh à 2 matériaux (métal, diffuseur
	# lumineux) : 3 fois moins d'appels de rendu par zone.
	if _lamp_parts.is_empty():
		return
	var groups: Dictionary = {}
	for info in _lamp_parts:
		var mesh: Mesh = info.mesh
		var material := mesh.surface_get_material(0)
		var key := "default"
		if material is BaseMaterial3D:
			key = "%s|%s" % [str((material as BaseMaterial3D).albedo_color), str((material as BaseMaterial3D).emission_enabled)]
		if not groups.has(key):
			var group := SurfaceTool.new()
			group.begin(Mesh.PRIMITIVE_TRIANGLES)
			group.set_material(material)
			groups[key] = group
		var target: SurfaceTool = groups[key]
		target.append_from(mesh, 0, info.xform)
	var merged := ArrayMesh.new()
	for key in groups.keys():
		var group_tool: SurfaceTool = groups[key]
		group_tool.commit(merged)
	_lamp_parts = [{"mesh": merged, "xform": Transform3D.IDENTITY}]


func _collect_lamp_parts(node: Node, parent_transform: Transform3D) -> void:
	var local := parent_transform
	if node is Node3D:
		local = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		_lamp_parts.append({"mesh": (node as MeshInstance3D).mesh, "xform": local})
	for child in node.get_children():
		_collect_lamp_parts(child, local)


func _place_lamps_along(run: Array[Vector3], lamp_line: Array[Vector3], top_y: PackedFloat32Array, gaps: PackedFloat32Array, side_sign: float, spacing: float, phase: float, lamp_scale: float, part_index: int) -> void:
	if _lamp_parts.is_empty():
		return
	var total := 0.0
	for i in range(lamp_line.size() - 1):
		total += Vector2(lamp_line[i + 1].x - lamp_line[i].x, lamp_line[i + 1].z - lamp_line[i].z).length()
	var travelled := 0.0
	var next_at := 4.0 + phase
	for i in range(lamp_line.size() - 1):
		var seg := Vector2(lamp_line[i + 1].x - lamp_line[i].x, lamp_line[i + 1].z - lamp_line[i].z).length()
		if seg < 0.001:
			continue
		while next_at <= travelled + seg:
			var t := (next_at - travelled) / seg
			var position := lamp_line[i].lerp(lamp_line[i + 1], t)
			position.y = lerpf(top_y[i], top_y[i + 1], t)
			var in_median := gaps[i] > 0.0 and gaps[i + 1] > 0.0
			var allowed := (next_at <= total - 4.0) and (not in_median or part_index % 2 == 0)
			if allowed and not _point_on_other_road(position.x, position.z, part_index):
				var dir := Vector2(run[i + 1].x - run[i].x, run[i + 1].z - run[i].z).normalized()
				var toward_road := -Vector3(-dir.y, 0.0, dir.x) * side_sign
				var yaw := atan2(-toward_road.z, toward_road.x)
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * lamp_scale)
				_lamp_batch.append(Transform3D(basis, position))
			next_at += spacing
		travelled += seg


func _commit_lamps(tile_name: String) -> void:
	if _lamp_batch.is_empty() or _lamp_parts.is_empty():
		_lamp_batch.clear()
		return
	for part_number in range(_lamp_parts.size()):
		var info: Dictionary = _lamp_parts[part_number]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = info.mesh
		multimesh.instance_count = _lamp_batch.size()
		var part_transform: Transform3D = info.xform
		for i in range(_lamp_batch.size()):
			multimesh.set_instance_transform(i, _lamp_batch[i] * part_transform)
		var instance := MultiMeshInstance3D.new()
		instance.name = "OSM_Lampadaires_%s_%d" % [tile_name, part_number]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = LAMP_VISIBILITY
		add_child(instance)
	_lamp_count += _lamp_batch.size()
	_lamp_batch.clear()


func _add_sidewalk_skirt(surfaces: Dictionary, collision: SurfaceTool, top_a: Vector3, top_b: Vector3, ground_a: float, ground_b: float, outward: Vector3) -> void:
	# Flanc extérieur du trottoir jusqu'au terrain, et pente praticable pour redescendre.
	var drop_a := top_a.y - ground_a
	var drop_b := top_b.y - ground_b
	if drop_a < 0.22 and drop_b < 0.22:
		return
	var bottom_a := Vector3(top_a.x, ground_a - 0.05, top_a.z)
	var bottom_b := Vector3(top_b.x, ground_b - 0.05, top_b.z)
	_add_plain_quad(surfaces["skirt"], top_a, top_b, bottom_b, bottom_a)
	if road_collision:
		var reach := clampf(maxf(drop_a, drop_b) * 1.5, 0.3, 4.0)
		_add_plain_quad(collision, top_a, top_b, bottom_b + outward * reach, bottom_a + outward * reach)


func _add_plain_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _add_textured_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, meters: float) -> void:
	_add_textured_tri(surface, a, b, c, meters)
	_add_textured_tri(surface, a, c, d, meters)


func _add_textured_tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, meters: float) -> void:
	_add_road_tri(surface, a, b, c, meters, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


func _add_road_tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, meters: float, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	# UV2 = (voie ?, position en travers -1..1) : utilisé par le shader pour les traces de pneus.
	surface.set_meta("used", true)
	surface.set_uv(_world_uv(a, meters))
	surface.set_uv2(ua)
	surface.add_vertex(a)
	surface.set_uv(_world_uv(b, meters))
	surface.set_uv2(ub)
	surface.add_vertex(b)
	surface.set_uv(_world_uv(c, meters))
	surface.set_uv2(uc)
	surface.add_vertex(c)


func _add_road_quad_uv2(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, across_ad: float, across_bc: float) -> void:
	var ua := Vector2(1.0, across_ad)
	var ub := Vector2(1.0, across_bc)
	_add_road_tri(surface, a, b, c, ROAD_UV_METERS, ua, ub, ub)
	_add_road_tri(surface, a, c, d, ROAD_UV_METERS, ua, ub, ua)


func _set_uv_origin(point: Vector3) -> void:
	# Origine alignée sur la période de texture : le motif reste continu d'un tronçon à l'autre.
	_uv_origin = Vector2(roundf(point.x / ROAD_UV_METERS) * ROAD_UV_METERS, roundf(point.z / ROAD_UV_METERS) * ROAD_UV_METERS)


func _world_uv(point: Vector3, meters: float) -> Vector2:
	return Vector2((point.x - _uv_origin.x) / meters, (point.z - _uv_origin.y) / meters)


func _geo_to_road_point(coordinate: Array) -> Vector3:
	var point := _geo_to_world(coordinate)
	return Vector3(point.x, _terrain_mesh_height(point.x, point.z), point.z)


func _terrain_mesh_height(x: float, z: float) -> float:
	# Hauteur du maillage de terrain tel qu'il est réellement dessiné (deux triangles
	# par cellule, diagonale (x0,z0)-(x1,z1)), et non l'interpolation bilinéaire :
	# la route se pose ainsi exactement sur le sol visible, sans plaque verte qui dépasse.
	if not _dem_loaded:
		return 0.0
	var gx := clampf((x - _dem_x_min) / _dem_spacing, 0.0, float(_dem_columns - 1) - 0.0001)
	var gz := clampf((z - _dem_z_min) / _dem_spacing, 0.0, float(_dem_rows - 1) - 0.0001)
	var c := int(floor(gx))
	var r := int(floor(gz))
	var fx := gx - float(c)
	var fz := gz - float(r)
	var h00 := _dem_heights[r * _dem_columns + c]
	var h10 := _dem_heights[r * _dem_columns + c + 1]
	var h01 := _dem_heights[(r + 1) * _dem_columns + c]
	var h11 := _dem_heights[(r + 1) * _dem_columns + c + 1]
	if fz >= fx:
		return h00 + (h01 - h00) * fz + (h11 - h01) * fx
	return h00 + (h10 - h00) * fx + (h11 - h10) * fz


func _rp(point: Vector3, lift: float) -> Vector3:
	return Vector3(point.x, _terrain_mesh_height(point.x, point.z) + lift, point.z)


func _road_class_lift(kind: String) -> float:
	# Les routes importantes passent légèrement au-dessus des petites quand elles se
	# superposent : plus de scintillement (z-fighting) entre deux bitumes.
	match kind:
		"motorway", "trunk":
			return 0.012
		"primary":
			return 0.010
		"secondary":
			return 0.008
		"tertiary":
			return 0.006
		"residential", "unclassified":
			return 0.004
		"service":
			return 0.002
	return 0.0


func _densify_polyline(points: Array[Vector3], max_step: float) -> Array[Vector3]:
	var result: Array[Vector3] = [points[0]]
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var distance := Vector2(b.x - a.x, b.z - a.z).length()
		var steps := maxi(1, ceili(distance / max_step))
		for step in range(1, steps + 1):
			if step == steps:
				result.append(b)
			else:
				var p := a.lerp(b, float(step) / float(steps))
				result.append(Vector3(p.x, _terrain_mesh_height(p.x, p.z), p.z))
	return result


func _build_road_hit_grid(parts: Array[Dictionary]) -> void:
	_road_hit_grid.clear()
	for part_index in range(parts.size()):
		var part: Dictionary = parts[part_index]
		if str(part.kind) in ["footway", "path", "steps", "cycleway", "pedestrian", "track"]:
			continue
		var pts: Array[Vector3] = part.points
		var half: float = float(part.width) * 0.5
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var travel := Vector2(b.x - a.x, b.z - a.z)
			travel = travel.normalized() * float(part.oneway_sign) if travel.length() > 0.001 else Vector2.ZERO
			var is_major := 1.0 if str(part.kind) in ["trunk", "primary", "secondary", "tertiary"] else 0.0
			var is_oneway := 1.0 if int(part.oneway_sign) != 0 else 0.0
			var segment := PackedFloat32Array([a.x, a.z, b.x, b.z, half, float(part_index), is_oneway, is_major, travel.x, travel.y])
			var min_x := floori((minf(a.x, b.x) - half) / ROAD_HIT_CELL)
			var max_x := floori((maxf(a.x, b.x) + half) / ROAD_HIT_CELL)
			var min_z := floori((minf(a.z, b.z) - half) / ROAD_HIT_CELL)
			var max_z := floori((maxf(a.z, b.z) + half) / ROAD_HIT_CELL)
			for cx in range(min_x, max_x + 1):
				for cz in range(min_z, max_z + 1):
					var cell := Vector2i(cx, cz)
					if not _road_hit_grid.has(cell):
						_road_hit_grid[cell] = []
					_road_hit_grid[cell].append(segment)


func _point_on_other_road(x: float, z: float, part_index: int) -> bool:
	var cell := Vector2i(floori(x / ROAD_HIT_CELL), floori(z / ROAD_HIT_CELL))
	if not _road_hit_grid.has(cell):
		return false
	var point := Vector2(x, z)
	for segment in _road_hit_grid[cell]:
		if int(segment[5]) == part_index:
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(point, Vector2(segment[0], segment[1]), Vector2(segment[2], segment[3]))
		if point.distance_to(nearest) < float(segment[4]) - 0.2:
			return true
	return false


func _road_surface_key(kind: String, props: Dictionary) -> String:
	var surface_tag := str(props.get("surface", "")).to_lower()
	if surface_tag in ["unpaved", "ground", "dirt", "earth", "compacted", "gravel", "fine_gravel", "sand", "mud", "grass"]:
		return "dirt"
	if kind in ["track", "construction"]:
		return "dirt"
	if surface_tag in ["concrete", "paving_stones", "sett", "cobblestone", "concrete:plates", "concrete:lanes", "paved_stones"]:
		return "paving"
	if kind in ["footway", "pedestrian", "steps", "cycleway"]:
		return "paving"
	if kind == "path" and surface_tag == "":
		return "dirt"
	return "asphalt"


func _road_tint(kind: String, props: Dictionary, surface_key: String) -> Color:
	var shade := 0.95
	var wear := 1.0
	if surface_key == "asphalt":
		match kind:
			"motorway", "trunk", "motorway_link", "trunk_link":
				shade = 0.84
				wear = 0.35
			"primary", "primary_link":
				shade = 0.88
				wear = 0.45
			"secondary", "secondary_link":
				shade = 0.91
				wear = 0.6
			"tertiary", "tertiary_link":
				shade = 0.94
				wear = 0.8
			"service":
				shade = 1.0
				wear = 1.3
			_:
				shade = 0.97
				wear = 1.0
	elif surface_key == "dirt":
		shade = 1.0
	var smoothness := str(props.get("smoothness", "")).to_lower()
	if smoothness in ["bad", "very_bad", "horrible", "very_horrible", "impassable"]:
		shade *= 0.86
		wear += 0.4
	elif smoothness == "intermediate":
		shade *= 0.94
		wear += 0.2
	# Légère variation déterministe par route : casse l'uniformité sans aléatoire.
	var id_value := str(props.get("osm_id", "0")).to_int()
	shade = clampf(shade + (float(id_value % 17) / 16.0 - 0.5) * 0.08, 0.6, 1.0)
	wear = clampf(wear + (float(id_value % 11) / 10.0 - 0.5) * 0.3, 0.1, 1.5)
	if surface_key == "dirt":
		return Color(shade, shade * 0.95, shade * 0.90)
	if surface_key == "paving":
		# La texture asphalt_floor est beige : on la refroidit pour obtenir un béton gris.
		return Color(shade * 0.80, shade * 0.85, shade * 0.92)
	# L'alpha porte le niveau d'usure lu par le shader d'asphalte.
	return Color(shade, shade, shade, wear)


func _offset_road_polyline(points: Array[Vector3], offset: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if points.size() < 2:
		return result
	for i in range(points.size()):
		var previous_direction: Vector2
		var next_direction: Vector2
		if i == 0:
			next_direction = Vector2(points[1].x - points[0].x, points[1].z - points[0].z).normalized()
			previous_direction = next_direction
		elif i == points.size() - 1:
			previous_direction = Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).normalized()
			next_direction = previous_direction
		else:
			previous_direction = Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).normalized()
			next_direction = Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).normalized()
		var previous_normal := Vector2(-previous_direction.y, previous_direction.x)
		var next_normal := Vector2(-next_direction.y, next_direction.x)
		var miter := (previous_normal + next_normal).normalized()
		if miter.length_squared() < 0.001:
			miter = next_normal
		var denominator := maxf(absf(miter.dot(next_normal)), 0.35)
		var miter_length := clampf(offset / denominator, -absf(offset) * 2.2, absf(offset) * 2.2)
		var displaced := Vector2(points[i].x, points[i].z) + miter * miter_length
		result.append(Vector3(displaced.x, points[i].y, displaced.y))
	return result


func _load_road_clearance_data() -> void:
	_road_clearance_segments.clear()
	_road_clearance_grid.clear()
	var data := _read_geojson("res://data/osm/roads.geojson")
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		var kind := str(props.get("highway", "residential"))
		var width := _road_width(kind, props)
		var sidewalk_extra := (CURB_WIDTH + SIDEWALK_WIDTH) if _road_sidewalk_mode(props, kind) != "none" else 0.0
		var lines: Array = []
		match str(geometry.get("type", "")):
			"LineString":
				lines.append(geometry.get("coordinates", []))
			"MultiLineString":
				lines = geometry.get("coordinates", [])
			_:
				continue
		for line in lines:
			for i in range(line.size() - 1):
				var a := _geo_to_world(line[i])
				var b := _geo_to_world(line[i + 1])
				var segment := {
					"a": Vector2(a.x, a.z),
					"b": Vector2(b.x, b.z),
					"radius": width * 0.5 + sidewalk_extra
				}
				_road_clearance_segments.append(segment)
				# Index spatial de 128 m : les vérifications d'herbe ne parcourent
				# que les routes proches au lieu de rescanner tout le réseau OSM.
				const cell_size := 128.0
				var min_cell_x := int(floor(minf(a.x, b.x) / cell_size))
				var max_cell_x := int(floor(maxf(a.x, b.x) / cell_size))
				var min_cell_z := int(floor(minf(a.z, b.z) / cell_size))
				var max_cell_z := int(floor(maxf(a.z, b.z) / cell_size))
				for cell_x in range(min_cell_x, max_cell_x + 1):
					for cell_z in range(min_cell_z, max_cell_z + 1):
						var cell_key := Vector2i(cell_x, cell_z)
						if not _road_clearance_grid.has(cell_key):
							_road_clearance_grid[cell_key] = []
						_road_clearance_grid[cell_key].append(segment)


func _is_near_road(point: Vector2, extra_margin: float = 0.0) -> bool:
	const cell_size := 128.0
	var cell_x := int(floor(point.x / cell_size))
	var cell_z := int(floor(point.y / cell_size))
	for offset_x in range(-1, 2):
		for offset_z in range(-1, 2):
			var nearby_segments: Array = _road_clearance_grid.get(Vector2i(cell_x + offset_x, cell_z + offset_z), [])
			for segment in nearby_segments:
				var a: Vector2 = segment.a
				var b: Vector2 = segment.b
				var nearest := Geometry2D.get_closest_point_to_segment(point, a, b)
				if point.distance_squared_to(nearest) <= pow(float(segment.radius) + extra_margin, 2.0):
					return true
	return false


func _road_junction_key(coordinate: Array) -> String:
	# Arrondi d'environ 2 m pour regrouper les nœuds OSM partagés malgré de légères différences.
	return "%.5f:%.5f" % [float(coordinate[0]), float(coordinate[1])]


func _add_junction_patch(surface: SurfaceTool, center: Vector3, radius: float) -> void:
	const SEGMENTS := 14
	const PATCH_LIFT := 0.06
	var c := _rp(center, PATCH_LIFT)
	for i in range(SEGMENTS):
		var a0 := TAU * float(i) / float(SEGMENTS)
		var a1 := TAU * float(i + 1) / float(SEGMENTS)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var i0 := _rp(center + d0 * radius * 0.5, PATCH_LIFT)
		var i1 := _rp(center + d1 * radius * 0.5, PATCH_LIFT)
		var o0 := _rp(center + d0 * radius, PATCH_LIFT)
		var o1 := _rp(center + d1 * radius, PATCH_LIFT)
		_add_textured_tri(surface, c, i0, i1, ROAD_UV_METERS)
		_add_textured_quad(surface, i0, o0, o1, i1, ROAD_UV_METERS)


func _add_road_round_join(surface: SurfaceTool, center: Vector3, radius: float) -> void:
	const SEGMENTS := 7
	var c := _rp(center, ROAD_LIFT + 0.01)
	for i in range(SEGMENTS):
		var a0 := TAU * float(i) / float(SEGMENTS)
		var a1 := TAU * float(i + 1) / float(SEGMENTS)
		_add_textured_tri(surface, c,
			_rp(center + Vector3(cos(a0), 0.0, sin(a0)) * radius, ROAD_LIFT + 0.01),
			_rp(center + Vector3(cos(a1), 0.0, sin(a1)) * radius, ROAD_LIFT + 0.01),
			ROAD_UV_METERS)


func _add_crosswalk(surface: SurfaceTool, junction: Vector3, inward_direction: Vector2, road_width: float, distance: float = 3.5) -> void:
	if road_width < 5.5:
		return
	var direction := Vector3(inward_direction.x, 0.0, inward_direction.y).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x) * (road_width * 0.42)
	var center := junction + direction * distance
	for stripe_index in range(6):
		var offset := (float(stripe_index) - 2.5) * 0.72
		var stripe_center := center + direction * offset
		var along := direction * 0.22
		_add_quad(surface,
			_rp(stripe_center - along + side, MARKING_LIFT + 0.005),
			_rp(stripe_center - along - side, MARKING_LIFT + 0.005),
			_rp(stripe_center + along - side, MARKING_LIFT + 0.005),
			_rp(stripe_center + along + side, MARKING_LIFT + 0.005))


func _road_has_center_marking(props: Dictionary, road_kind: String) -> bool:
	return _road_lane_count(props) >= 2 or road_kind in ["trunk", "primary", "secondary"]


func _add_road_lane_markings(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, lanes: int, oneway: bool) -> void:
	var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
	if direction.length_squared() < 0.001:
		return
	var perpendicular := Vector3(-direction.y, 0.0, direction.x)
	var half := width * 0.5
	var count := maxi(2, lanes)
	if oneway:
		# Une chaussée à sens unique ne reçoit pas de ligne centrale séparant les sens.
		for lane_index in range(1, count):
			var offset := -half + width * float(lane_index) / float(count)
			_add_road_dashes_offset(surface, a, b, perpendicular, offset)
	elif count <= 2:
		_add_road_center_dashes(surface, a, b)
	else:
		# Ligne médiane continue et séparations pointillées des voies supplémentaires.
		_add_marking_quad(surface, a + perpendicular * -0.07, b + perpendicular * -0.07, 0.045)
		_add_marking_quad(surface, a + perpendicular * 0.07, b + perpendicular * 0.07, 0.045)
		var lanes_each_side := int(floor(float(count) * 0.5))
		for lane_index in range(1, lanes_each_side):
			var offset := width * float(lane_index) / float(count)
			_add_road_dashes_offset(surface, a, b, perpendicular, offset)
			_add_road_dashes_offset(surface, a, b, perpendicular, -offset)


func _add_road_dashes_offset(surface: SurfaceTool, a: Vector3, b: Vector3, perpendicular: Vector3, offset: float) -> void:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := delta.length()
	if length < 4.0:
		return
	var direction := delta / length
	var distance := 0.8
	while distance + 2.8 < length:
		_add_marking_quad(surface,
			a + perpendicular * offset + direction * distance,
			a + perpendicular * offset + direction * (distance + 2.8), 0.055)
		distance += 7.0


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


func _add_road_center_dashes(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := delta.length()
	if length < 4.0:
		return
	var direction := delta / length
	var dash_length := 2.8
	var gap_length := 4.2
	var distance := 0.8
	while distance + dash_length < length:
		_add_marking_quad(surface, a + direction * distance, a + direction * (distance + dash_length), 0.09)
		distance += dash_length + gap_length


func _add_marking_quad(surface: SurfaceTool, p0: Vector3, p1: Vector3, half_width: float) -> void:
	# Marquage posé sur le relief : chaque coin est ajusté à la hauteur du sol.
	var delta := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)
	if delta.length() < 0.01:
		return
	var side := Vector3(-delta.z, 0.0, delta.x).normalized() * half_width
	_add_quad(surface,
		_rp(p0 + side, MARKING_LIFT),
		_rp(p0 - side, MARKING_LIFT),
		_rp(p1 - side, MARKING_LIFT),
		_rp(p1 + side, MARKING_LIFT))


func _road_sidewalk_mode(props: Dictionary, road_kind: String) -> String:
	var general := str(props.get("sidewalk", "")).to_lower()
	var left := str(props.get("sidewalk:left", "")).to_lower()
	var right := str(props.get("sidewalk:right", "")).to_lower()
	if general in ["no", "none"] or (general == "separate" and sidewalk_coverage < 2):
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
	# Sans tag OSM, aménagement représentatif selon `sidewalk_coverage`
	# (les bretelles, pistes, services et chemins n'en reçoivent jamais).
	if sidewalk_coverage <= 0:
		return "none"
	if road_kind in ["trunk", "primary", "secondary", "tertiary"]:
		return "both"
	if road_kind in ["residential", "unclassified", "living_street"]:
		if sidewalk_coverage >= 3:
			return "both"
		if sidewalk_coverage >= 2 and str(props.get("name", "")).strip_edges() != "":
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
			# L'empreinte est découpée avec la même zone de sécurité que les surfaces
			# terrestres : chaussée + bordure + trottoir + marge anti-chevauchement.
			var footprint_parts := _clip_polygon_away_from_roads(points, 0.65)
			var facade_col := _building_color(building_kind, osm_id, props)
			for footprint in footprint_parts:
				if footprint.size() < 3:
					continue
				# Évite les fragments résiduels sans supprimer les petits bâtiments intacts.
				if footprint_parts.size() > 1 and _polygon_area_abs(footprint) < 2.0:
					continue
				var indices := Geometry2D.triangulate_polygon(footprint)
				if indices.is_empty():
					continue
				var building_center := Vector2.ZERO
				for footprint_point in footprint:
					building_center += footprint_point
				building_center /= float(footprint.size())
				var building_base_y := _terrain_height_at_world(building_center.x, building_center.y)
				surface.set_color(facade_col)
				_add_building(surface, roof_surface, detail_surface, footprint, indices, height, _roof_color(building_kind, osm_id, props), building_kind, osm_id, props, facade_col, building_base_y)
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
		var place_kind := str(props.get("place", ""))
		# Le repère de ville « Libreville » n'est pas une destination de quartier.
		if place_kind != "city":
			var osm_id := int(props.get("osm_id", 0))
			_locality_points.append({
				"name": label_text,
				"osm_id": osm_id,
				"place": place_kind,
				"arrondissement": str(_neighbourhood_arrondissements.get(osm_id, "")),
				"position": Vector2(world_position.x, world_position.z)
			})
		_add_map_label(label_text, world_position + Vector3.UP * 0.65, Color(1.0, 0.84, 0.48), 600.0)
		_locality_count += 1
	print("LIBREVILLE STORIES | noms de quartiers/localités OSM : %d" % _locality_count)


func get_locality_destinations() -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	for locality in _locality_points:
		var point: Vector2 = locality.position
		var osm_id := int(locality.get("osm_id", 0))
		var polygon: PackedVector2Array = _neighbourhood_polygons.get(osm_id, PackedVector2Array())
		# Le point OSM doit rester dans son propre secteur ; sinon, utiliser son centroïde.
		if not polygon.is_empty() and not _point_in_polygon(point, polygon):
			point = _polygon_centroid(polygon)
		# Avec le DEM étendu, les limites du relief remplacent l'ancienne
		# boîte fixe de 12 km qui excluait les quartiers périphériques.
		if _dem_loaded:
			if point.x < _dem_x_min or point.x > _dem_x_min + float(_dem_columns - 1) * _dem_spacing:
				continue
			if point.y < _dem_z_min or point.y > _dem_z_min + float(_dem_rows - 1) * _dem_spacing:
				continue
		else:
			if absf(point.x) > 5900.0 or absf(point.y) > 5900.0:
				continue
		var ground_y := _terrain_height_at_world(point.x, point.y)
		destinations.append({
			"name": str(locality.name),
			"arrondissement": str(locality.get("arrondissement", "")),
			"osm_id": osm_id,
			"position": Vector3(point.x, ground_y + 2.2, point.y)
		})
	return destinations


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

func _road_lane_count(props: Dictionary) -> int:
	# Les voies directionnelles sont plus fiables que lanes quand elles existent.
	var forward := str(props.get("lanes:forward", "")).to_int()
	var backward := str(props.get("lanes:backward", "")).to_int()
	if forward > 0 or backward > 0:
		return clampi(forward + backward, 1, 8)
	var both_ways := str(props.get("lanes:both_ways", "")).to_int()
	var total := str(props.get("lanes", "")).to_int()
	if total <= 0:
		total = both_ways
	return clampi(total, 0, 8)


func _road_is_oneway(props: Dictionary) -> bool:
	var value := str(props.get("oneway", "")).to_lower()
	return value in ["yes", "true", "1", "-1"]


func _road_width(kind: String, props: Dictionary = {}) -> float:
	# Les voies OSM priment sur les largeurs manifestement incohérentes.
	# Ex. Libreville : width=5 avec lanes=2 ne peut pas contenir deux voies.
	var lanes := _road_lane_count(props)
	var tagged_width := _parse_osm_height(str(props.get("width", "")))
	if tagged_width >= 1.5 and tagged_width <= 40.0:
		if lanes == 0 or tagged_width >= float(lanes) * 2.65:
			return tagged_width
	if lanes >= 1:
		return clampf(float(lanes) * 3.4 + 1.2, 3.5, 28.0)
	match kind:
		"motorway", "trunk":
			return 8.0 if _road_is_oneway(props) else 16.0
		"primary":
			return 7.2 if _road_is_oneway(props) else 13.6 # 2x2 par défaut en double sens
		"secondary":
			return 4.8 if _road_is_oneway(props) else 9.2
		"tertiary":
			return 7.0
		"residential", "unclassified":
			return 5.5
		"service":
			return 3.6
		"motorway_link", "trunk_link", "primary_link":
			return 7.0
		"secondary_link":
			return 6.0
		"tertiary_link":
			return 5.5
		"construction":
			return 6.0
		"track":
			return 3.5
		"pedestrian":
			return 4.0
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
