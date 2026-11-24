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
const DEM_META_EXTENDED_PATH := "res://data/terrain/libreville_dem_extended.json"
const DEM_BINARY_EXTENDED_PATH := "res://data/terrain/libreville_dem_extended_f32.bin"
const DEM_META_FALLBACK_PATH := "res://data/terrain/libreville_dem.json"
const DEM_BINARY_FALLBACK_PATH := "res://data/terrain/libreville_dem_f32.bin"
const TERRAIN_CHUNK_CELLS := 32
const TERRAIN_VERTICAL_EXAGGERATION := 1.0
const TERRAIN_STREAM_RADIUS := 1
const TERRAIN_STREAM_UPDATE_SECONDS := 0.45
const TERRAIN_STREAM_MAX_BUILDS_PER_UPDATE := 2
# Rayon de données réellement converties en géométrie au démarrage (en mètres).
# Les fichiers GeoJSON restent des données compactes ; les meshes hors zone ne sont pas créés.
const WORLD_ENVIRONMENT_RADIUS := 1800.0
const WORLD_ROAD_RADIUS := 2400.0
const WORLD_BUILDING_RADIUS := 1400.0
const WORLD_POI_RADIUS := 1800.0
const WORLD_LOCALITY_RADIUS := 3500.0
const BAIE_DES_ROIS_WATER_LEVEL := -0.12
const BAIE_DES_ROIS_SITE_CENTER := Vector2(-1884.0, -400.0)
const BAIE_DES_ROIS_SITE_RADIUS := 190.0

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
var _neighbourhood_names: Dictionary = {}
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
var _terrain_stream_chunks: Dictionary = {}
var _terrain_stream_center := Vector2i(2147483647, 2147483647)
var _terrain_stream_timer := 0.0
var _terrain_stream_build_queue: Array[Vector2i] = []
var _terrain_stream_building := false
var _terrain_stream_material: StandardMaterial3D
var _ocean_water_material: ShaderMaterial
var _coastline_paths: Array[PackedVector2Array] = []
var _beach_polygons: Array[PackedVector2Array] = []

func _ready() -> void:
	# Le monde est construit progressivement : empêcher le joueur et le véhicule
	# de simuler leur gravité avant que le relief et ses collisions soient prêts.
	var player_during_setup := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player_during_setup != null:
		player_during_setup.set_physics_process(false)
	var vehicle_during_setup := get_parent().get_node_or_null("Vehicle") as CharacterBody3D
	if vehicle_during_setup != null:
		vehicle_during_setup.set_physics_process(false)

	# Lire le profil avant de construire le monde 3D.
	var graphics_config := ConfigFile.new()
	if graphics_config.load("user://graphics_settings.cfg") == OK:
		show_buildings = bool(graphics_config.get_value("graphics", "buildings", false))
		render_green_areas = bool(graphics_config.get_value("graphics", "vegetation", false))
		load_extra_road_textures = bool(graphics_config.get_value("graphics", "extra_textures", false))
		var sun := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if sun != null:
			sun.shadow_enabled = bool(graphics_config.get_value("graphics", "shadows", false))
	await get_tree().process_frame
	_load_real_terrain()
	if _dem_loaded:
		# Choisir la position terrestre AVANT de calculer les blocs initiaux :
		# sinon le terrain peut être construit autour de l'ancien point de spawn.
		_position_player_on_terrain()
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
	_load_coastline_paths()
	await get_tree().process_frame
	if _dem_loaded:
		await _build_terrain_chunks()
	# Le joueur reprend le contrôle dès que le sol et ses collisions proches
	# existent. Les décors non essentiels continuent ensuite leur préparation.
	var player_after_terrain := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player_after_terrain != null:
		player_after_terrain.set_physics_process(true)
	var vehicle_after_terrain := get_parent().get_node_or_null("Vehicle") as CharacterBody3D
	if vehicle_after_terrain != null:
		vehicle_after_terrain.set_physics_process(true)
	_grass_generator = GrassGenerator.new()
	_grass_generator.name = "Procedural_Real_Grass"
	add_child(_grass_generator)
	await _load_environment()
	await get_tree().process_frame
	_grass_generator.build()
	await get_tree().process_frame
	_load_neighbourhoods()
	await get_tree().process_frame
	_load_localities()
	await get_tree().process_frame
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
		await _load_roads()
		await get_tree().process_frame
	if show_buildings:
		await _load_buildings()
		await get_tree().process_frame
	_load_pois()
	# Recalculer les blocs autour du point de départ définitif et attendre leurs
	# collisions avant de rendre le contrôle au joueur.
	if _dem_loaded:
		_update_terrain_stream(true)
		while _terrain_stream_building or not _terrain_stream_build_queue.is_empty():
			await get_tree().process_frame
	var player_ready := get_parent().get_node_or_null("Player") as CharacterBody3D
	if player_ready != null:
		player_ready.set_physics_process(true)
	var vehicle_ready := get_parent().get_node_or_null("Vehicle") as CharacterBody3D
	if vehicle_ready != null:
		vehicle_ready.set_physics_process(true)
	_create_location_hud()
	print("LIBREVILLE STORIES | zone initiale : environnement %.0f m, routes %.0f m, bâtiments %.0f m | routes: %d | bâtiments: %d | POI: %d" % [WORLD_ENVIRONMENT_RADIUS, WORLD_ROAD_RADIUS, WORLD_BUILDING_RADIUS, _road_count, _building_count, _poi_count])


func _process(delta: float) -> void:
	_location_refresh += delta
	if _location_refresh >= 0.35:
		_location_refresh = 0.0
		_update_location_hud()
	if _dem_loaded:
		_terrain_stream_timer += delta
		if _terrain_stream_timer >= TERRAIN_STREAM_UPDATE_SECONDS:
			_terrain_stream_timer = 0.0
			_update_terrain_stream()


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
	# Ne jamais rabattre une coordonnée hors DEM sur son bord : cela donnait
	# une fausse altitude et pouvait faire apparaître le joueur dans l'océan.
	var x_max := _dem_x_min + float(_dem_columns - 1) * _dem_spacing
	var z_max := _dem_z_min + float(_dem_rows - 1) * _dem_spacing
	if x < _dem_x_min or x > x_max or z < _dem_z_min or z > z_max:
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
	# Le DEM complet reste en mémoire (grille compacte), mais seuls les blocs
	# proches du joueur deviennent des meshes/collisions Godot.
	_terrain_stream_material = StandardMaterial3D.new()
	_terrain_stream_material.vertex_color_use_as_albedo = true
	_terrain_stream_material.roughness = 1.0
	_terrain_stream_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_create_terrain_boundary_walls()
	_update_terrain_stream(true)
	# Sécuriser le sol sous le joueur avant de poursuivre le chargement des autres couches.
	while _terrain_stream_building or not _terrain_stream_build_queue.is_empty():
		await get_tree().process_frame
	print("LIBREVILLE STORIES | streaming terrain actif : rayon %d bloc(s), blocs créés à la demande." % TERRAIN_STREAM_RADIUS)


func _update_terrain_stream(force: bool = false) -> void:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null or _dem_rows < 2 or _dem_columns < 2:
		return
	var cell_world_size := float(TERRAIN_CHUNK_CELLS) * _dem_spacing
	var center := Vector2i(
		floori((player.global_position.x - _dem_x_min) / cell_world_size),
		floori((player.global_position.z - _dem_z_min) / cell_world_size)
	)
	if not force and center == _terrain_stream_center:
		return
	_terrain_stream_center = center
	var desired: Dictionary = {}
	for dz in range(-TERRAIN_STREAM_RADIUS, TERRAIN_STREAM_RADIUS + 1):
		for dx in range(-TERRAIN_STREAM_RADIUS, TERRAIN_STREAM_RADIUS + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			var max_chunk_x := ceili(float(_dem_columns - 1) / float(TERRAIN_CHUNK_CELLS)) - 1
			var max_chunk_z := ceili(float(_dem_rows - 1) / float(TERRAIN_CHUNK_CELLS)) - 1
			if key.x < 0 or key.y < 0 or key.x > max_chunk_x or key.y > max_chunk_z:
				continue
			desired[key] = true
			if not _terrain_stream_chunks.has(key) and not _terrain_stream_build_queue.has(key):
				_terrain_stream_build_queue.append(key)
	# Décharger les blocs qui sont sortis de la zone utile.
	for key in _terrain_stream_chunks.keys():
		if not desired.has(key):
			var chunk_nodes: Dictionary = _terrain_stream_chunks[key]
			for node in chunk_nodes.values():
				if is_instance_valid(node):
					node.queue_free()
			_terrain_stream_chunks.erase(key)
	# Priorité aux blocs les plus proches du joueur.
	_terrain_stream_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - center).length_squared() < Vector2(b - center).length_squared()
	)
	if not _terrain_stream_building:
		_build_terrain_stream_queue()


func _build_terrain_stream_queue() -> void:
	_terrain_stream_building = true
	var built_this_frame := 0
	while not _terrain_stream_build_queue.is_empty() and built_this_frame < TERRAIN_STREAM_MAX_BUILDS_PER_UPDATE:
		var key: Vector2i = _terrain_stream_build_queue.pop_front()
		if not _terrain_stream_chunks.has(key):
			_build_terrain_chunk(key)
			built_this_frame += 1
		await get_tree().process_frame
	_terrain_stream_building = false
	# Continuer le traitement progressivement sans monopoliser une frame.
	if not _terrain_stream_build_queue.is_empty():
		_build_terrain_stream_queue()


func _baie_coast_sea_normal(a: Vector2, b: Vector2) -> Vector2:
	var direction := (b - a).normalized()
	var sea_normal := Vector2(-direction.y, direction.x)
	if sea_normal.y < 0.0:
		sea_normal = -sea_normal
	return sea_normal


func _clip_baie_terrain_cell_to_shore(cell: PackedVector2Array) -> PackedVector2Array:
	if cell.size() < 3 or _coastline_paths.is_empty():
		return cell
	const SITE_CENTER := Vector2(-1884.0, -400.0)
	const CLIP_RADIUS := 270.0
	var center := Vector2.ZERO
	for point in cell:
		center += point
	center /= float(cell.size())
	if center.distance_to(SITE_CENTER) > CLIP_RADIUS:
		return cell
	var nearest_distance := INF
	var nearest_point := Vector2.ZERO
	var nearest_sea_normal := Vector2.ZERO
	for coast_path in _coastline_paths:
		for i in range(coast_path.size() - 1):
			var a: Vector2 = coast_path[i]
			var b: Vector2 = coast_path[i + 1]
			var segment := b - a
			if segment.length_squared() < 1.0:
				continue
			var t := clampf((center - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
			var candidate := a + segment * t
			var distance := center.distance_to(candidate)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_point = candidate
				nearest_sea_normal = _baie_coast_sea_normal(a, b)
	if nearest_distance > 75.0:
		return cell
	var clipped: Array[Vector2] = []
	for i in range(cell.size()):
		var current: Vector2 = cell[i]
		var next: Vector2 = cell[(i + 1) % cell.size()]
		var current_side := (current - nearest_point).dot(nearest_sea_normal)
		var next_side := (next - nearest_point).dot(nearest_sea_normal)
		var current_inside := current_side <= 0.0
		var next_inside := next_side <= 0.0
		if current_inside:
			clipped.append(current)
		if current_inside != next_inside:
			var denominator := current_side - next_side
			if absf(denominator) > 0.0001:
				clipped.append(current.lerp(next, current_side / denominator))
	if clipped.size() < 3:
		return PackedVector2Array()
	return PackedVector2Array(clipped)


func _coastline_land_normal(path: PackedVector2Array, segment_index: int) -> Vector2:
	var a: Vector2 = path[segment_index]
	var b: Vector2 = path[segment_index + 1]
	var direction := (b - a).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var midpoint := (a + b) * 0.5
	var left_height := _terrain_height_at_world(midpoint.x + perpendicular.x * 10.0, midpoint.y + perpendicular.y * 10.0)
	var right_height := _terrain_height_at_world(midpoint.x - perpendicular.x * 10.0, midpoint.y - perpendicular.y * 10.0)
	return perpendicular if left_height >= right_height else -perpendicular


func _coastline_miter_normal(path: PackedVector2Array, vertex_index: int, fallback: Vector2) -> Vector2:
	var previous_normal := fallback
	var next_normal := fallback
	if vertex_index > 0:
		previous_normal = _coastline_land_normal(path, vertex_index - 1)
	if vertex_index < path.size() - 1:
		next_normal = _coastline_land_normal(path, vertex_index)
	var summed := previous_normal + next_normal
	if summed.length_squared() < 0.0001:
		return fallback
	var miter := summed.normalized()
	var denominator := miter.dot(next_normal)
	if absf(denominator) < 0.25:
		return fallback
	return miter / denominator


func _build_terrain_chunk(key: Vector2i) -> void:
	var row_start := key.y * TERRAIN_CHUNK_CELLS
	var col_start := key.x * TERRAIN_CHUNK_CELLS
	var row_end := mini(row_start + TERRAIN_CHUNK_CELLS, _dem_rows - 1)
	var col_end := mini(col_start + TERRAIN_CHUNK_CELLS, _dem_columns - 1)
	if row_start >= row_end or col_start >= col_end:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain_stream_material)
	for row in range(row_start, row_end):
		for col in range(col_start, col_end):
			var x0 := _dem_x_min + float(col) * _dem_spacing
			var x1 := x0 + _dem_spacing
			var z0 := _dem_z_min + float(row) * _dem_spacing
			var z1 := z0 + _dem_spacing
			var cell := PackedVector2Array([
				Vector2(x0, z0), Vector2(x0, z1),
				Vector2(x1, z1), Vector2(x1, z0)
			])
			# Garder le relief collidable SOUS les chaussées. Le découpage du DEM
			# créait un vide physique dès qu'une collision routière manquait un triangle
			# (carrefours, bords de meshes ou surfaces OSM). La route reste visible
			# au-dessus du terrain grâce à ROAD_LIFT ; le sol garantit la marche.
			var terrain_pieces: Array[PackedVector2Array] = [_clip_baie_terrain_cell_to_shore(cell)]
			for piece in terrain_pieces:
				if piece.size() < 3:
					continue
				var indices := Geometry2D.triangulate_polygon(piece)
				if indices.is_empty():
					continue
				for i in range(0, indices.size(), 3):
					for vertex_index in range(3):
						var point: Vector2 = piece[indices[i + vertex_index]]
						var height: float = _terrain_height_at_world(point.x, point.y)
						surface.set_color(_terrain_color(height))
						surface.add_vertex(Vector3(point.x, height, point.y))
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		_terrain_stream_chunks[key] = {}
		return
	var chunk := MeshInstance3D.new()
	chunk.name = "SRTM_Terrain_%d_%d" % [key.x, key.y]
	chunk.mesh = mesh
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(chunk)
	var body := StaticBody3D.new()
	body.name = "SRTM_Collision_%d_%d" % [key.x, key.y]
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var terrain_collision := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	if terrain_collision == null:
		chunk.queue_free()
		body.queue_free()
		push_error("Collision SRTM impossible pour le bloc %s." % str(key))
		return
	terrain_collision.backface_collision = true
	shape.shape = terrain_collision
	body.add_child(shape)
	add_child(body)
	_terrain_stream_chunks[key] = {"mesh": chunk, "collision": body}


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
		var spawn_x := player.position.x
		var spawn_z := player.position.z
		var spawn_height := _terrain_height_at_world(spawn_x, spawn_z)
		# L'ancre historique de la Baie des Rois peut tomber côté mer selon
		# la résolution du DEM. Chercher un point terrestre proche plutôt que
		# laisser le joueur apparaître sous la surface océanique.
		if spawn_height < 1.0:
			var best_distance := INF
			var best_position := Vector2(spawn_x, spawn_z)
			var search_radius := 1200.0
			for radius_step in range(1, 41):
				var radius := float(radius_step) * 30.0
				for angle_step in range(32):
					var angle := TAU * float(angle_step) / 32.0
					var candidate_x := spawn_x + cos(angle) * radius
					var candidate_z := spawn_z + sin(angle) * radius
					var candidate_height := _terrain_height_at_world(candidate_x, candidate_z)
					var candidate_distance := Vector2(candidate_x - spawn_x, candidate_z - spawn_z).length_squared()
					if candidate_height >= 1.0 and candidate_distance < best_distance:
						best_distance = candidate_distance
						best_position = Vector2(candidate_x, candidate_z)
			if best_distance < INF:
					spawn_x = best_position.x
					spawn_z = best_position.y
					spawn_height = _terrain_height_at_world(spawn_x, spawn_z)
					print("LIBREVILLE STORIES | point de départ déplacé sur la terre ferme (%.0f m)." % sqrt(best_distance))
			else:
				push_warning("Aucun point terrestre proche du point de départ : vérifier l'emprise du DEM.")
		player.position = Vector3(spawn_x, spawn_height + 2.0, spawn_z)
	var vehicle := get_parent().get_node_or_null("Vehicle") as Node3D
	if vehicle != null and player != null:
		# La voiture suit le point de départ sécurisé au lieu de rester en mer.
		var vehicle_x := player.position.x + 6.0
		var vehicle_z := player.position.z + 3.0
		var vehicle_ground := _terrain_height_at_world(vehicle_x, vehicle_z)
		if vehicle_ground < 1.0:
			vehicle_x = player.position.x
			vehicle_z = player.position.z
			vehicle_ground = _terrain_height_at_world(vehicle_x, vehicle_z)
		# L'origine du véhicule correspond au bas des pneus (rayon 0,42 m).
		# Le placer à +0,65 m le faisait flotter au-dessus de la chaussée.
		vehicle.position = Vector3(vehicle_x, vehicle_ground + ROAD_LIFT + 0.01, vehicle_z)


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

uniform sampler2D ocean_base_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ocean_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ocean_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D ocean_ao : filter_linear_mipmap, repeat_enable;

varying vec3 water_normal;
varying vec3 water_world_pos;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	vec2 p = world_pos.xz;
	// Trois houles longues et douces : pas de sinusoïdes serrées qui dessinent
	// des bandes parallèles visibles sur toute la surface.
	float a1 = dot(p, normalize(vec2(0.82, 0.57))) * 0.014 + t * 0.34;
	float a2 = dot(p, normalize(vec2(-0.34, 0.94))) * 0.027 - t * 0.25;
	float a3 = dot(p, normalize(vec2(0.98, -0.18))) * 0.043 + t * 0.19;
	float h1 = sin(a1) * 0.038;
	float h2 = sin(a2) * 0.014;
	float h3 = sin(a3) * 0.004;
	float height = h1 + h2 + h3;
	float dx = cos(a1) * 0.038 * 0.014 * 0.82
		+ cos(a2) * 0.014 * 0.027 * -0.34
		+ cos(a3) * 0.004 * 0.043 * 0.98;
	float dz = cos(a1) * 0.038 * 0.014 * 0.57
		+ cos(a2) * 0.014 * 0.027 * 0.94
		+ cos(a3) * 0.004 * 0.043 * -0.18;
	VERTEX.y += height;
	water_normal = normalize(vec3(-dx, 1.0, -dz));
	water_world_pos = world_pos;
}

void fragment() {
	vec3 deep_water = vec3(0.012, 0.105, 0.175);
	vec3 mid_water = vec3(0.018, 0.235, 0.315);
	float broad = sin(water_world_pos.x * 0.004 + TIME * 0.11)
		* cos(water_world_pos.z * 0.005 - TIME * 0.09);
	vec3 water_color = mix(deep_water, mid_water, 0.48 + broad * 0.10);
	vec3 n = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(water_normal, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 4.0);
	vec3 sun_direction = normalize(vec3(-0.35, 0.82, 0.44));
	float glint = pow(max(dot(reflect(-sun_direction, n), VIEW), 0.0), 64.0);
	// Le normal map océan défile à deux échelles et vitesses différentes :
	// le détail bouge en continu sans former des traits ou des rubans réguliers.
	vec2 ocean_uv = UV * vec2(430.0, 300.0);
	vec2 drift_a = ocean_uv + vec2(TIME * 0.006, -TIME * 0.004);
	vec2 drift_b = ocean_uv * 1.63 + vec2(-TIME * 0.003, TIME * 0.005);
	vec3 normal_a = texture(ocean_normal, drift_a).rgb;
	vec3 normal_b = texture(ocean_normal, drift_b).rgb;
	vec3 blended_normal = normalize(mix(normal_a, normal_b, 0.32));
	vec3 ocean_albedo = texture(ocean_base_color, drift_a).rgb;
	ALBEDO = mix(water_color, ocean_albedo * vec3(0.48, 0.76, 0.86), 0.42);
	ALBEDO = mix(ALBEDO, vec3(0.34, 0.52, 0.54), fresnel * 0.36);
	ALBEDO += vec3(0.18, 0.23, 0.22) * glint * 0.12;
	METALLIC = 0.015;
	ROUGHNESS = clamp(texture(ocean_roughness, drift_a).r * 0.58 + 0.18, 0.18, 0.62);
	AO = texture(ocean_ao, drift_a).r;
	SPECULAR = 0.58;
	NORMAL_MAP = blended_normal;
	NORMAL_MAP_DEPTH = 0.24;
}
"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	var ocean_texture_root := "res://assets/textures/water/ocean_1k/"
	var ocean_base := load(ocean_texture_root + "baseColor.png") as Texture2D
	var ocean_normal_map := load(ocean_texture_root + "normal.png") as Texture2D
	var ocean_rough := load(ocean_texture_root + "roughness.png") as Texture2D
	var ocean_ao := load(ocean_texture_root + "ambientOcclusion.png") as Texture2D
	if ocean_base != null and ocean_normal_map != null and ocean_rough != null and ocean_ao != null:
		water_material.set_shader_parameter("ocean_base_color", ocean_base)
		water_material.set_shader_parameter("ocean_normal", ocean_normal_map)
		water_material.set_shader_parameter("ocean_roughness", ocean_rough)
		water_material.set_shader_parameter("ocean_ao", ocean_ao)
		print("LIBREVILLE STORIES | pack PBR océan 1K chargé.")
	else:
		push_warning("Pack PBR océan incomplet : eau procédurale conservée en secours.")
	_ocean_water_material = water_material
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

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dry_sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_sand_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D dry_sand_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_sand_ao : filter_linear_mipmap, repeat_enable;
uniform sampler2D dry_sand_ao : filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap, repeat_enable;

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
	// Humidité diffuse du sable : transition entre sable sec et humide.
	float damp_noise = broad * 0.62 + medium * 0.38;
	float damp_mask = smoothstep(0.58, 0.78, damp_noise) * sand_mask;
	vec2 ground_uv = p * 0.065;
	vec3 dry_sand = texture(dry_sand_albedo, ground_uv).rgb;
	vec3 wet_sand = texture(wet_sand_albedo, ground_uv * 0.82).rgb;
	vec3 sand_texture = mix(dry_sand, wet_sand, damp_mask * 0.78);
	vec3 sand_color = sand_texture * (0.91 + sand_variation * 0.10);
	sand_color = mix(sand_color, sand_color * vec3(0.76, 0.79, 0.78), damp_mask * 0.18);

	float grass_mask = smoothstep(0.06, 0.18, base.g - base.r)
		* smoothstep(0.035, 0.15, base.g - base.b);
	vec3 grass_texture = texture(grass_albedo, ground_uv * 0.72).rgb;
	vec3 grass_color = grass_texture * vec3(0.78, 0.86, 0.74);

	float neutral_mask = 1.0 - smoothstep(0.035, 0.15,
		abs(base.r - base.g) + abs(base.g - base.b));
	vec3 soil_color = texture(soil_albedo, ground_uv * 0.84).rgb * vec3(0.92, 0.90, 0.84);
	vec3 gravel_color = texture(gravel_albedo, ground_uv * 0.95).rgb;
	vec3 other_color = mix(soil_color, gravel_color, neutral_mask * 0.72);
	float water_mask = smoothstep(0.08, 0.24, base.b - base.g);
	ALBEDO = mix(other_color, sand_color, sand_mask);
	ALBEDO = mix(ALBEDO, grass_color, grass_mask);
	ALBEDO = mix(ALBEDO, base, water_mask);
	float dry_roughness = texture(dry_sand_roughness, ground_uv).r;
	float wet_roughness = texture(wet_sand_roughness, ground_uv * 0.82).r;
	float sand_roughness = mix(dry_roughness, wet_roughness, damp_mask);
	ROUGHNESS = mix(0.94, sand_roughness, sand_mask);
	ROUGHNESS = mix(ROUGHNESS, 0.96, grass_mask);
	float dry_ao = texture(dry_sand_ao, ground_uv).r;
	float wet_ao = texture(wet_sand_ao, ground_uv * 0.82).r;
	AO = mix(1.0, mix(dry_ao, wet_ao, damp_mask), sand_mask);
	SPECULAR = mix(0.16, 0.24, damp_mask);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var texture_paths := {
		"grass_albedo": "res://assets/textures/vegetation/Grass001_4K-JPG/Grass001_4K-JPG_Color.jpg",
		"wet_sand_albedo": "res://assets/textures/ground/Ground061_4K-JPG/Ground061_4K-JPG_Color.jpg",
		"dry_sand_albedo": "res://assets/textures/ground/Ground093C_4K-JPG/Ground093C_4K-JPG_Color.jpg",
		"wet_sand_roughness": "res://assets/textures/ground/Ground061_4K-JPG/Ground061_4K-JPG_Roughness.jpg",
		"dry_sand_roughness": "res://assets/textures/ground/Ground093C_4K-JPG/Ground093C_4K-JPG_Roughness.jpg",
		"wet_sand_ao": "res://assets/textures/ground/Ground061_4K-JPG/Ground061_4K-JPG_AmbientOcclusion.jpg",
		"dry_sand_ao": "res://assets/textures/ground/Ground093C_4K-JPG/Ground093C_4K-JPG_AmbientOcclusion.jpg",
		"soil_albedo": "res://assets/textures/ground/Ground103_4K-JPG/Ground103_4K-JPG_Color.jpg",
		"gravel_albedo": "res://assets/textures/ground/Ground014_4K-JPG/Ground014_4K-JPG_Color.jpg"
	}
	for parameter in texture_paths:
		var texture_path: String = texture_paths[parameter]
		var texture := load(texture_path) as Texture2D
		if texture != null:
			material.set_shader_parameter(parameter, texture)
		else:
			push_warning("Texture environnementale absente : %s" % texture_path)
	print("LIBREVILLE STORIES | textures PBR de sable, herbe, terre et gravier connectées.")
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

func _load_coastline_paths() -> void:
	var data := _read_geojson("res://data/osm/environment.geojson")
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		if str(props.get("environment_kind", "")) != "coastline" or str(geometry.get("type", "")) != "LineString":
			continue
		var coast_path := PackedVector2Array()
		for coordinate in geometry.get("coordinates", []):
			var coast_point := _geo_to_world(coordinate)
			coast_path.append(Vector2(coast_point.x, coast_point.z))
		if coast_path.size() >= 2:
			_coastline_paths.append(coast_path)
	print("LIBREVILLE STORIES | lignes de côte chargées avant le relief : %d" % _coastline_paths.size())


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
	var environment_index := 0
	var environment_features: Array = _filter_features_to_player_zone(data.get("features", []).duplicate(), WORLD_ENVIRONMENT_RADIUS)
	var player_for_environment := get_parent().get_node_or_null("Player") as Node3D
	var environment_origin := Vector2.ZERO
	if player_for_environment != null:
		environment_origin = Vector2(player_for_environment.global_position.x, player_for_environment.global_position.z)
	environment_features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _feature_world_center(a).distance_squared_to(environment_origin) < _feature_world_center(b).distance_squared_to(environment_origin)
	)
	for feature in environment_features:
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
				surface.set_color(WorldMapColorUtils.environment_color(kind))
				if has_landscape_relief:
					relief_collision_surface.set_color(WorldMapColorUtils.environment_color(kind))
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
					if _coastline_paths.is_empty():
						_coastline_paths.append(coast_path)
					added = true
			else:
				var width := 5.5 if kind == "waterway" else (8.0 if kind == "water" else 1.6)
				surface.set_color(WorldMapColorUtils.environment_color(kind))
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
		environment_index += 1
		if environment_index % 40 == 0:
			await get_tree().process_frame
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
	# L'océan global texturé est l'unique surface d'eau ; ne pas superposer une seconde nappe locale.
	_build_coastal_details()
	_build_baie_des_rois_seawall()
	_commit_tree_instances(tree_positions)


func is_terrain_ready() -> bool:
	# Le mode secours utilise un sol plat ; avec le DEM, attendre au moins
	# le premier bloc de terrain et ses collisions.
	return not _dem_loaded or not _terrain_stream_chunks.is_empty()


func _build_baie_des_rois_water() -> void:
	if _coastline_paths.is_empty():
		push_warning("Baie des Rois : aucune ligne de côte OSM disponible pour positionner l'eau.")
		return

	# Les relevés GPS des kiosques placent la côte de ce secteur à environ
	# 29–38 m côté +Z. On sélectionne la ligne OSM la plus proche de ce secteur,
	# puis on prolonge la mer depuis le rivage vers le large, pas depuis le centre-ville.
	const SITE_CENTER := Vector2(-1884.0, -400.0)
	const SITE_RADIUS := 190.0
	const SEA_WIDTH := 480.0
	var water_surface := SurfaceTool.new()
	water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 0

	for coast_path in _coastline_paths:
		for i in range(coast_path.size() - 1):
			var a: Vector2 = coast_path[i]
			var b: Vector2 = coast_path[i + 1]
			var segment := b - a
			var length := segment.length()
			if length < 1.5:
				continue

			var nearest_t := clampf((SITE_CENTER - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
			var nearest := a + segment * nearest_t
			if nearest.distance_to(SITE_CENTER) > SITE_RADIUS:
				continue

			# Limiter chaque tronçon à la portion utile autour des kiosques.
			var half_span := minf(length * 0.5, SITE_RADIUS)
			var t0 := maxf(0.0, nearest_t - half_span / length)
			var t1 := minf(1.0, nearest_t + half_span / length)
			var coast_a := a.lerp(b, t0)
			var coast_b := a.lerp(b, t1)
			var local_segment := coast_b - coast_a
			if local_segment.length_squared() < 1.0:
				continue

			var direction := local_segment.normalized()
			var perpendicular := Vector2(-direction.y, direction.x)
			var midpoint := (coast_a + coast_b) * 0.5
			var left_height := _terrain_height_at_world(midpoint.x + perpendicular.x * 10.0, midpoint.y + perpendicular.y * 10.0)
			var right_height := _terrain_height_at_world(midpoint.x - perpendicular.x * 10.0, midpoint.y - perpendicular.y * 10.0)
			var land_normal := perpendicular if left_height >= right_height else -perpendicular
			var sea_normal := -land_normal
			# Les coordonnées GPS et le relevé du littoral indiquent le large
			# du côté +Z pour cette portion nord de la Baie des Rois.
			if sea_normal.y < 0.0:
				sea_normal = -sea_normal

			var inner_a := coast_a + sea_normal * 0.8
			var inner_b := coast_b + sea_normal * 0.8
			var outer_a := coast_a + sea_normal * SEA_WIDTH
			var outer_b := coast_b + sea_normal * SEA_WIDTH
			var y_inner_a := BAIE_DES_ROIS_WATER_LEVEL + 0.018
			var y_inner_b := BAIE_DES_ROIS_WATER_LEVEL + 0.018
			var y_outer_a := BAIE_DES_ROIS_WATER_LEVEL + 0.018
			var y_outer_b := BAIE_DES_ROIS_WATER_LEVEL + 0.018

			var vertices := [
				Vector3(inner_a.x, y_inner_a, inner_a.y),
				Vector3(inner_b.x, y_inner_b, inner_b.y),
				Vector3(outer_b.x, y_outer_b, outer_b.y),
				Vector3(outer_a.x, y_outer_a, outer_a.y)
			]
			for index in [0, 1, 2, 0, 2, 3]:
				var vertex: Vector3 = vertices[index]
				water_surface.set_uv(Vector2(vertex.x, vertex.z) * 0.018)
				water_surface.add_vertex(vertex)
			segment_count += 1

	if segment_count == 0:
		push_warning("Baie des Rois : la ligne de côte OSM n'a pas de tronçon dans le périmètre GPS attendu.")
		return

	water_surface.generate_normals()
	var water_mesh := water_surface.commit()
	if water_mesh == null or water_mesh.get_surface_count() == 0:
		return
	var water_instance := MeshInstance3D.new()
	water_instance.name = "BaieDesRois_SeaSurface"
	water_instance.mesh = water_mesh
	water_instance.material_override = _ocean_water_material
	water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(water_instance)
	print("LIBREVILLE STORIES | eau locale Baie des Rois : %d tronçons OSM, départ au bord du rivage" % segment_count)


func _build_baie_des_rois_seawall() -> void:
	# Mur de rive en béton, construit uniquement sur le tronçon côtier
	# correspondant au relevé GPS de la Baie des Rois.
	if _coastline_paths.is_empty():
		return
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.70, 0.70, 0.66)
	concrete.roughness = 0.92
	concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wall_surface := _new_surface(concrete)
	var wall_segments := 0
	var rail_root := Node3D.new()
	rail_root.name = "BaieDesRois_Seafront_Guardrail"
	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = Color(0.34, 0.38, 0.39)
	rail_material.metallic = 0.62
	rail_material.roughness = 0.42
	var rock_root := Node3D.new()
	rock_root.name = "BaieDesRois_Coastal_Rock_Assets"
	var rock_scene_a := load("res://assets/models/environment/coastal_rocks/rock_face_01_4k.gltf/rock_face_01_4k.gltf") as PackedScene
	var rock_scene_b := load("res://assets/models/environment/coastal_rocks/rock_face_02_4k.gltf/rock_face_02_4k.gltf") as PackedScene
	var rock_count := 0
	var rock_index := 0

	for coast_path in _coastline_paths:
		for i in range(coast_path.size() - 1):
			var a: Vector2 = coast_path[i]
			var b: Vector2 = coast_path[i + 1]
			var segment := b - a
			var length := segment.length()
			if length < 1.5:
				continue
			var midpoint := (a + b) * 0.5
			if midpoint.distance_to(BAIE_DES_ROIS_SITE_CENTER) > BAIE_DES_ROIS_SITE_RADIUS:
				continue
			var direction := segment / length
			var perpendicular := Vector2(-direction.y, direction.x)
			var left_sample := midpoint + perpendicular * 10.0
			var right_sample := midpoint - perpendicular * 10.0
			var left_height := _terrain_height_at_world(left_sample.x, left_sample.y)
			var right_height := _terrain_height_at_world(right_sample.x, right_sample.y)
			var land_normal := perpendicular if left_height >= right_height else -perpendicular
			var start_normal := _coastline_miter_normal(coast_path, i, land_normal)
			var end_normal := _coastline_miter_normal(coast_path, i + 1, land_normal)
			var wall_a := a + start_normal * 1.0
			var wall_b := b + end_normal * 1.0
			var sea_a := wall_a - start_normal * 0.16
			var sea_b := wall_b - end_normal * 0.16
			var land_a := wall_a + start_normal * 0.16
			var land_b := wall_b + end_normal * 0.16
			var bottom_y := BAIE_DES_ROIS_WATER_LEVEL - 0.30
			var top_a := maxf(_terrain_height_at_world(wall_a.x, wall_a.y) + 0.72, BAIE_DES_ROIS_WATER_LEVEL + 0.95)
			var top_b := maxf(_terrain_height_at_world(wall_b.x, wall_b.y) + 0.72, BAIE_DES_ROIS_WATER_LEVEL + 0.95)

			# Face tournée vers l'eau, face tournée vers la promenade et couronnement.
			_add_quad(wall_surface,
				Vector3(sea_a.x, bottom_y, sea_a.y), Vector3(sea_b.x, bottom_y, sea_b.y),
				Vector3(sea_b.x, top_b, sea_b.y), Vector3(sea_a.x, top_a, sea_a.y))
			_add_quad(wall_surface,
				Vector3(land_b.x, bottom_y, land_b.y), Vector3(land_a.x, bottom_y, land_a.y),
				Vector3(land_a.x, top_a, land_a.y), Vector3(land_b.x, top_b, land_b.y))
			_add_quad(wall_surface,
				Vector3(sea_a.x, top_a, sea_a.y), Vector3(sea_b.x, top_b, sea_b.y),
				Vector3(land_b.x, top_b, land_b.y), Vector3(land_a.x, top_a, land_a.y))
			wall_segments += 1

			# Garde-corps métallique bas au-dessus du muret béton : deux lisses
			# et des montants espacés, orientés suivant chaque segment OSM.
			var rail_mid := (wall_a + wall_b) * 0.5
			var rail_delta := wall_b - wall_a
			var rail_length := rail_delta.length() + 0.16
			var rail_base_y := (top_a + top_b) * 0.5
			var rail_yaw := atan2(rail_delta.x, rail_delta.y)
			for rail_height in [0.12, 0.50, 0.91]:
				var rail_bar := MeshInstance3D.new()
				var rail_box := BoxMesh.new()
				rail_box.size = Vector3(0.042, 0.042, rail_length)
				rail_bar.mesh = rail_box
				rail_bar.material_override = rail_material
				rail_bar.position = Vector3(rail_mid.x, rail_base_y + rail_height, rail_mid.y)
				rail_bar.rotation.y = rail_yaw
				rail_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				rail_root.add_child(rail_bar)
			# Montants fins rapprochés : le garde-corps ne ressemble plus à une
			# succession de longues barres flottantes avec un poteau tous les 15 m.
			var post_count := maxi(1, int(ceil(rail_length / 2.4)))
			for post_index in range(post_count + 1):
				var post_t := float(post_index) / float(post_count)
				var post_point := wall_a.lerp(wall_b, post_t)
				var post := MeshInstance3D.new()
				var post_box := BoxMesh.new()
				post_box.size = Vector3(0.052, 0.96, 0.052)
				post.mesh = post_box
				post.material_override = rail_material
				post.position = Vector3(post_point.x, rail_base_y + 0.48, post_point.y)
				post.rotation.y = rail_yaw
				post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				rail_root.add_child(post)

			# Les sections sableuses restent dégagées. Sur les portions rocheuses,
			# alterner les deux modèles PBR téléchargés, à faible densité.
			var sandy := _is_inside_beach(midpoint + land_normal * 5.0) or _is_inside_beach(midpoint + land_normal * 12.0)
			if not sandy and i % 2 == 0 and rock_count < 40 and (rock_scene_a != null or rock_scene_b != null):
				var rock_scene: PackedScene = rock_scene_a if (rock_index % 2 == 0 and rock_scene_a != null) or rock_scene_b == null else rock_scene_b
				var rock_instance := rock_scene.instantiate() as Node3D
				if rock_instance != null:
					rock_instance.name = "CoastalRock_%02d" % rock_count
					var rock_position := midpoint - land_normal * 0.62
					var rock_ground := _terrain_height_at_world(rock_position.x, rock_position.y)
					rock_instance.position = Vector3(rock_position.x, maxf(rock_ground - 0.10, BAIE_DES_ROIS_WATER_LEVEL - 0.42), rock_position.y)
					rock_instance.rotation.y = atan2(-direction.y, direction.x)
					var rock_scale := 0.42 if rock_index % 2 == 0 else 0.50
					rock_instance.scale = Vector3.ONE * rock_scale
					rock_root.add_child(rock_instance)
					rock_count += 1
					rock_index += 1

	if wall_segments > 0:
		wall_surface.generate_normals()
		var wall_mesh := wall_surface.commit()
		if wall_mesh != null and wall_mesh.get_surface_count() > 0:
			var wall_instance := MeshInstance3D.new()
			wall_instance.name = "BaieDesRois_Concrete_Seawall"
			wall_instance.mesh = wall_mesh
			wall_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wall_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(wall_instance)
			var wall_body := StaticBody3D.new()
			wall_body.name = "BaieDesRois_Concrete_Seawall_Collision"
			wall_body.collision_layer = 1
			wall_body.collision_mask = 1
			var wall_collision := CollisionShape3D.new()
			wall_collision.shape = wall_mesh.create_trimesh_shape()
			wall_body.add_child(wall_collision)
			add_child(wall_body)
	if rail_root.get_child_count() > 0:
		add_child(rail_root)
	if rock_count > 0:
		add_child(rock_root)
	print("LIBREVILLE STORIES | rive Baie des Rois : %d segments béton, garde-corps %d pièces, %d rochers PBR" % [wall_segments, rail_root.get_child_count(), rock_count])


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
	float wave = sin(a1) * 0.055 + sin(a2) * 0.022 + sin(a3) * 0.008;
	VERTEX.y = BAIE_DES_ROIS_WATER_LEVEL + wave + 0.005;
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
			var foam_a_outer := a + sea_normal * rng.randf_range(1.25, 2.0)
			var foam_b_inner := b + sea_normal * 0.35
			var foam_b_outer := b + sea_normal * rng.randf_range(1.25, 2.0)
			var foam_alpha := rng.randf_range(0.10, 0.30)
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
				var rock_xz := shoreline - land_normal * rng.randf_range(0.35, 2.1)
				# Les blocs sont côté mer, hors chaussée, et partiellement immergés.
				if _is_near_road(rock_xz):
					continue
				var rock_height := rng.randf_range(0.45, 1.35)
				var rock_scale_x := rng.randf_range(0.65, 2.0)
				var rock_scale_z := rng.randf_range(0.55, 1.65)
				# Le bas du mesh est à y=0 : l'origine doit être légèrement
				# sous le terrain pour éviter l'effet de rochers flottants.
				var rock_y := maxf(_terrain_height_at_world(rock_xz.x, rock_xz.y) - 0.08, BAIE_DES_ROIS_WATER_LEVEL - 0.55)
				var rock_basis := Basis(Vector3(rock_scale_x, 0.0, 0.0), Vector3(0.0, rock_height, 0.0), Vector3(0.0, 0.0, rock_scale_z)).rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				rock_transforms.append(Transform3D(rock_basis, Vector3(rock_xz.x, rock_y, rock_xz.y)))
				var shade := rng.randf_range(0.70, 1.0)
				rock_colors.append(Color(shade * 0.58, shade * 0.60, shade * 0.59, 1.0))

				# Petits galets mêlés aux blocs : ils densifient la ligne de
				# contact avec l'eau sans créer une bordure rocheuse continue.
				if rng.randf() < 0.72:
					var pebble_xz := shoreline - land_normal * rng.randf_range(0.12, 0.85)
					if _is_near_road(pebble_xz):
						continue
					var pebble_height := rng.randf_range(0.16, 0.38)
					var pebble_scale := rng.randf_range(0.22, 0.62)
					var pebble_y := maxf(_terrain_height_at_world(pebble_xz.x, pebble_xz.y) - 0.035, BAIE_DES_ROIS_WATER_LEVEL - 0.18)
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
		# ArrayMesh n'expose pas de propriété `material` : le matériau se définit par surface.
		if rock_mesh.get_surface_count() > 0:
			rock_mesh.surface_set_material(0, rock_material)
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
			var radius: float = float(ring_radii[ring_index]) * irregularity
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
	var radius: float = 1.0
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
	var foliage_palette: Array[Color] = [
		Color(0.075, 0.23, 0.105), Color(0.11, 0.31, 0.14),
		Color(0.16, 0.37, 0.17), Color(0.22, 0.39, 0.16),
		Color(0.10, 0.32, 0.23), Color(0.27, 0.40, 0.19),
		Color(0.18, 0.29, 0.12)
	]

	# Un lot MultiMesh par carré de 800 m : les arbres lointains ne forcent
	# plus un unique grand volume visible depuis toute la ville.
	var spatial_tiles: Dictionary = {}
	for position in positions:
		var key := Vector2i(floori(position.x / ROAD_TILE_SIZE), floori(position.z / ROAD_TILE_SIZE))
		if not spatial_tiles.has(key):
			spatial_tiles[key] = []
		spatial_tiles[key].append(position)
	var tile_keys: Array = spatial_tiles.keys()
	var player := get_parent().get_node_or_null("Player") as Node3D
	var player_xz := Vector2.ZERO
	if player != null:
		player_xz = Vector2(player.global_position.x, player.global_position.z)
	tile_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ca := Vector2((float(a.x) + 0.5) * ROAD_TILE_SIZE, (float(a.y) + 0.5) * ROAD_TILE_SIZE)
		var cb := Vector2((float(b.x) + 0.5) * ROAD_TILE_SIZE, (float(b.y) + 0.5) * ROAD_TILE_SIZE)
		return ca.distance_squared_to(player_xz) < cb.distance_squared_to(player_xz)
	)
	for tile_key in tile_keys:
		_build_tree_tile_instances(tile_key, spatial_tiles[tile_key], trunk_mesh, canopy_meshes, trunk_material, canopy_material, foliage_palette)
	print("LIBREVILLE STORIES | arbres tropicaux regroupés par secteurs : %d arbres, %d secteurs" % [positions.size(), tile_keys.size()])


func _build_tree_tile_instances(tile_key: Vector2i, positions: Array, trunk_mesh: CylinderMesh,
		canopy_meshes: Array[ArrayMesh], trunk_material: StandardMaterial3D,
		canopy_material: StandardMaterial3D, foliage_palette: Array[Color]) -> void:
	var tile_origin := Vector3((float(tile_key.x) + 0.5) * ROAD_TILE_SIZE, 0.0, (float(tile_key.y) + 0.5) * ROAD_TILE_SIZE)
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.use_colors = true
	trunks.mesh = trunk_mesh
	trunks.instance_count = positions.size()
	var canopy_multimeshes: Array[MultiMesh] = []
	var canopy_counts: Array[int] = [0, 0, 0]
	for mesh in canopy_meshes:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = mesh
		batch.instance_count = positions.size()
		canopy_multimeshes.append(batch)
	for i in range(positions.size()):
		var position: Vector3 = positions[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(position.x * 13.0 + position.z * 29.0)) + i * 7919
		var height_scale := rng.randf_range(0.82, 1.34)
		var width_scale := rng.randf_range(0.82, 1.24)
		var yaw := rng.randf_range(0.0, TAU)
		var trunk_scale := Vector3(rng.randf_range(0.88, 1.12), height_scale, rng.randf_range(0.88, 1.12))
		var trunk_basis := Basis(Vector3.UP, yaw).scaled(trunk_scale)
		var trunk_position := position + Vector3.UP * (0.95 * height_scale) - tile_origin
		trunks.set_instance_transform(i, Transform3D(trunk_basis, trunk_position))
		trunks.set_instance_color(i, Color(0.43, 0.30, 0.18).lerp(Color(0.20, 0.15, 0.10), rng.randf()))
		var canopy_type := rng.randi_range(0, canopy_meshes.size() - 1)
		var canopy_index := canopy_counts[canopy_type]
		var canopy_height := (2.65 if canopy_type != 1 else 2.55) * height_scale
		if canopy_type == 2:
			canopy_height = 2.95 * height_scale
		var canopy_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, width_scale))
		var canopy_position := position + Vector3.UP * canopy_height - tile_origin
		canopy_multimeshes[canopy_type].set_instance_transform(canopy_index, Transform3D(canopy_basis, canopy_position))
		canopy_multimeshes[canopy_type].set_instance_color(canopy_index, foliage_palette[rng.randi_range(0, foliage_palette.size() - 1)])
		canopy_counts[canopy_type] += 1
	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.name = "OSM_Tree_Trunks_%d_%d" % [tile_key.x, tile_key.y]
	trunk_instance.multimesh = trunks
	trunk_instance.material_override = trunk_material
	trunk_instance.position = tile_origin
	trunk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunk_instance)
	for canopy_type in range(canopy_multimeshes.size()):
		var batch := canopy_multimeshes[canopy_type]
		batch.visible_instance_count = canopy_counts[canopy_type]
		if canopy_counts[canopy_type] == 0:
			continue
		var canopy_instance := MultiMeshInstance3D.new()
		canopy_instance.name = "OSM_Tree_Canopies_%d_%d_%d" % [tile_key.x, tile_key.y, canopy_type]
		canopy_instance.multimesh = batch
		canopy_instance.material_override = canopy_material
		canopy_instance.position = tile_origin
		canopy_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(canopy_instance)


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
			_neighbourhood_names[osm_id] = str(props.get("name", "Quartier"))
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


func _find_road_texture(folder_name: String, file_stem: String) -> Texture2D:
	# Les packs restent dans leur dossier d'origine (xxx_4k.gltf/textures). On teste les
	# chemins directement : fonctionne dans l'éditeur comme dans un export.
	if folder_name == "":
		return null
	var base := "res://assets/textures/roads/%s/textures/%s" % [folder_name, file_stem]
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
	for key in ["curb", "skirt", "marking", "crosswalk", "median", "island"]:
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
		var radius: float = float(segment.radius) + extra_margin
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
	var features: Array = _filter_features_to_player_zone(data.get("features", []).duplicate(), WORLD_ROAD_RADIUS)
	var player_for_roads := get_parent().get_node_or_null("Player") as Node3D
	var road_origin := Vector2.ZERO
	if player_for_roads != null:
		road_origin = Vector2(player_for_roads.global_position.x, player_for_roads.global_position.z)
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _feature_world_center(a).distance_squared_to(road_origin) < _feature_world_center(b).distance_squared_to(road_origin)
	)
	_load_lamp_parts()
	_add_road_name_labels(features)
	# 1. Découpe en tronçons + registre des nœuds (carrefours, T, croisements).
	var parts: Array[Dictionary] = []
	var node_registry: Dictionary = {}
	var road_feature_index := 0
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
		var width := WorldMapRoadUtils.road_width(kind, props)
		var surface_key := WorldMapColorUtils.road_surface_key(kind, props)
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
				"tint": WorldMapColorUtils.road_tint(kind, props, surface_key),
				"class_lift": _road_class_lift(kind),
				"oneway_sign": _road_oneway_sign(props),
			})
		road_feature_index += 1
		if road_feature_index % 60 == 0:
			await get_tree().process_frame
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
	tile_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var center_a := Vector2((float(a.x) + 0.5) * ROAD_TILE_SIZE, (float(a.y) + 0.5) * ROAD_TILE_SIZE)
		var center_b := Vector2((float(b.x) + 0.5) * ROAD_TILE_SIZE, (float(b.y) + 0.5) * ROAD_TILE_SIZE)
		return center_a.distance_squared_to(road_origin) < center_b.distance_squared_to(road_origin)
	)
	var patched: Dictionary = {}
	var tile_counter := 0
	for tile_key in tile_keys:
		var surfaces := _new_road_surfaces()
		var collision := SurfaceTool.new()
		collision.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part_index in tiles[tile_key]:
			_build_road_part(parts[part_index], part_index, surfaces, collision, node_registry, patched, parts)
			_road_count += 1
		_commit_road_surfaces(surfaces, collision, "%03d" % tile_counter)
		_commit_lamps("%03d" % tile_counter)
		tile_counter += 1
		await get_tree().process_frame
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
		"island": Color(0.31, 0.39, 0.25),
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
		# Collision de secours construite directement depuis la chaussée visible.
		# Elle garantit que les triangles physiques utilisent exactement les mêmes
		# sommets que le rendu, même si le maillage de collision dédié est incomplet.
		if road_collision and key in ["asphalt", "dirt", "paving"]:
			var road_shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
			if road_shape != null:
				road_shape.backface_collision = true
				var road_body := StaticBody3D.new()
				road_body.name = "OSM_Road_Surface_Collision_%s_%s" % [str(key), tile_name]
				road_body.collision_layer = 1
				road_body.collision_mask = 1
				var road_collision_shape := CollisionShape3D.new()
				road_collision_shape.shape = road_shape
				road_body.add_child(road_collision_shape)
				add_child(road_body)
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


func _build_road_part(part: Dictionary, part_index: int, surfaces: Dictionary, collision: SurfaceTool, node_registry: Dictionary, patched: Dictionary, all_parts: Array[Dictionary]) -> void:
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
	# Les voies OSM fermées taguées roundabout reçoivent un véritable îlot central.
	if keys.size() >= 8 and keys[0] == keys[keys.size() - 1] and (str(props.get("junction", "")) == "roundabout" or str(props.get("roundabout", "")) == "yes"):
		_add_roundabout_island(surfaces["island"], orig_points, half)
	var lift: float = ROAD_LIFT + float(part.class_lift)
	var last := points.size() - 1
	_set_uv_origin(points[0])
	road_surface.set_color(part.tint)
	# Raccords aux carrefours : les nœuds OSM peuvent être aux extrémités
	# ou au milieu d'une LineString. On traite donc tous les nœuds d'origine.
	for node_index in range(keys.size()):
		var node_key: String = keys[node_index]
		var entries: PackedFloat32Array = node_registry.get(node_key, PackedFloat32Array())
		var entry_count := int(entries.size() / 3)
		if _junction_arm_count(node_key, node_registry, all_parts) >= 3 and not patched.has(node_key):
			patched[node_key] = true
			var patch_radius := 2.2
			for e in range(entry_count):
				patch_radius = maxf(patch_radius, entries[e * 3 + 1])
			_add_intersection_patch(road_surface, orig_points[node_index], node_key, node_registry, all_parts)
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
	var lane_count := WorldMapRoadUtils.road_lane_count(props)
	var is_oneway := WorldMapRoadUtils.road_is_oneway(props)
	var has_lane_marking := (lane_count >= 2 or kind in ["trunk", "primary", "secondary"]) and surface_key == "asphalt"
	var crosswalk_start := -1.0
	var crosswalk_end := -1.0
	if kind in ["primary", "secondary", "tertiary", "trunk"]:
		crosswalk_start = _junction_clearance(node_registry.get(keys[0], PackedFloat32Array()), part_index, true)
		crosswalk_end = _junction_clearance(node_registry.get(keys[keys.size() - 1], PackedFloat32Array()), part_index, true)
	var marking_surface: SurfaceTool = surfaces["marking"]
	# Distance cumulée sur la géométrie d'origine : les marquages sont coupés
	# avant les zones de conflit, au lieu de traverser le centre des carrefours.
	var junction_cuts := _road_part_cuts(part_index, keys, orig_points, node_registry)
	var distance_along := PackedFloat32Array()
	distance_along.resize(points.size())
	distance_along[0] = 0.0
	for distance_index in range(1, points.size()):
		distance_along[distance_index] = distance_along[distance_index - 1] + Vector2(
			points[distance_index].x - points[distance_index - 1].x,
			points[distance_index].z - points[distance_index - 1].z
		).length()
	for i in range(last):
		var a := points[i]
		var b := points[i + 1]
		var seg_len := Vector2(b.x - a.x, b.z - a.z).length()
		if seg_len < 0.08:
			continue
		var mark_from := 0.0
		var mark_to := seg_len
		var segment_start := distance_along[i]
		var segment_end := segment_start + seg_len
		var internal_junction_overlap := false
		for junction_cut in junction_cuts:
			# Les extrémités sont coupées précisément ci-dessous ; pour un carrefour
			# situé au milieu d'une géométrie, on supprime le segment qui le traverse.
			if junction_cut.x > 0.05 and junction_cut.x < float(part.length) - 0.05:
				if segment_start <= junction_cut.x + junction_cut.y and segment_end >= junction_cut.x - junction_cut.y:
					internal_junction_overlap = true
					break
		if internal_junction_overlap:
			mark_to = 0.0
		if crosswalk_start >= 0.0 and segment_start < crosswalk_start:
			mark_from = maxf(mark_from, crosswalk_start - segment_start)
		if crosswalk_end >= 0.0:
			var distance_to_end := float(part.length) - segment_start
			if distance_to_end - seg_len < crosswalk_end:
				mark_to = minf(mark_to, distance_to_end - crosswalk_end)
		var marking_a := a.lerp(b, clampf(mark_from / seg_len, 0.0, 1.0))
		var marking_b := a.lerp(b, clampf(mark_to / seg_len, 0.0, 1.0))
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
		if has_lane_marking and mark_to > mark_from + 0.25:
			_add_road_lane_markings(marking_surface, marking_a, marking_b, width, lane_count, is_oneway, props)
			if kind in ["trunk", "primary", "motorway"]:
				var direction := Vector2(marking_b.x - marking_a.x, marking_b.z - marking_a.z).normalized()
				var perp := Vector3(-direction.y, 0.0, direction.x)
				_add_marking_quad(marking_surface, marking_a + perp * (half - 0.18), marking_b + perp * (half - 0.18), 0.06)
				_add_marking_quad(marking_surface, marking_a - perp * (half - 0.18), marking_b - perp * (half - 0.18), 0.06)
		if i == 0 and crosswalk_start >= 0.0 and float(part.length) > crosswalk_start + 6.0:
			var approach_direction := Vector2(b.x - a.x, b.z - a.z).normalized()
			_add_crosswalk(surfaces["crosswalk"], a, approach_direction, width, crosswalk_start + 1.9)
			_add_stop_line(marking_surface, a, approach_direction, width, crosswalk_start + 4.8)
		if i == last - 1 and crosswalk_end >= 0.0 and float(part.length) > crosswalk_end + 6.0:
			var approach_direction := Vector2(a.x - b.x, a.z - b.z).normalized()
			_add_crosswalk(surfaces["crosswalk"], b, approach_direction, width, crosswalk_end + 1.9)
			_add_stop_line(marking_surface, b, approach_direction, width, crosswalk_end + 4.8)
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
	var self_half := 0.0
	var other_half := 0.0
	for e in range(count):
		var entry_part := int(entries[e * 3])
		if entry_part == part_index:
			self_half = maxf(self_half, entries[e * 3 + 1])
			continue
		others += 1
		other_half = maxf(other_half, entries[e * 3 + 1])
		if entries[e * 3 + 2] > 0.5:
			other_ends += 1
	if others == 0:
		return -1.0
	if others == 1 and self_is_end and other_ends == 1:
		return -1.0
	# Le dégagement doit couvrir la chaussée la plus large des deux voies :
	# sinon un trottoir de grand axe peut commencer sous la chaussée secondaire.
	return maxf(self_half, other_half) + JUNCTION_CLEARANCE


func _road_part_cuts(part_index: int, keys: Array[String], points: Array[Vector3], node_registry: Dictionary) -> Array[Vector2]:
	var cuts: Array[Vector2] = []
	var distance := 0.0
	var last := keys.size() - 1
	for i in range(keys.size()):
		if i > 0:
			distance += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
		var radius: float = float(_junction_clearance(node_registry.get(keys[i], PackedFloat32Array()), part_index, i == 0 or i == last))
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
		var built_segments := PackedByteArray()
		built_segments.resize(count - 1)
		# Première passe : repérer chaque portion réellement construite.
		# Une route secondaire peut interrompre le trottoir plusieurs fois ;
		# chaque portion doit donc avoir ses propres rampes et ses propres bouchons.
		for scan_index in range(count - 1):
			var scan_is_median := gaps[scan_index] > 0.0 and gaps[scan_index + 1] > 0.0
			if scan_is_median and (gaps[scan_index] < 2.0 * CURB_WIDTH + 0.5 or gaps[scan_index + 1] < 2.0 * CURB_WIDTH + 0.5):
				continue
			var scan_curb := (curb[scan_index] + curb[scan_index + 1]) * 0.5
			var scan_outer := (outer[scan_index] + outer[scan_index + 1]) * 0.5
			if _point_on_other_road(scan_curb.x, scan_curb.z, part_index) or _point_on_other_road(scan_outer.x, scan_outer.z, part_index):
				continue
			built_segments[scan_index] = 1
		# Chaque suite continue de segments reçoit une rampe à ses deux bouts.
		var segment_cursor := 0
		while segment_cursor < built_segments.size():
			if built_segments[segment_cursor] == 0:
				segment_cursor += 1
				continue
			var run_start := segment_cursor
			while segment_cursor + 1 < built_segments.size() and built_segments[segment_cursor + 1] == 1:
				segment_cursor += 1
			var run_end := segment_cursor + 1
			var travelled_from_start := 0.0
			var distance_to_end := PackedFloat32Array()
			distance_to_end.resize(run_end - run_start + 1)
			distance_to_end[run_end - run_start] = 0.0
			for ramp_index in range(run_end - 1, run_start - 1, -1):
				distance_to_end[ramp_index - run_start] = distance_to_end[ramp_index + 1 - run_start] + edge[ramp_index].distance_to(edge[ramp_index + 1])
			for ramp_index in range(run_start, run_end + 1):
				var from_start := travelled_from_start
				var from_end := distance_to_end[ramp_index - run_start]
				var ramp_factor := minf(minf(from_start / 1.5, from_end / 1.5), 1.0)
				top_y[ramp_index] = edge_y[ramp_index] + (top_y[ramp_index] - edge_y[ramp_index]) * ramp_factor
				if ramp_index < run_end:
					travelled_from_start += edge[ramp_index].distance_to(edge[ramp_index + 1])
			segment_cursor += 1
		for i in range(count - 1):
			var is_median := gaps[i] > 0.0 and gaps[i + 1] > 0.0
			if is_median and (gaps[i] < 2.0 * CURB_WIDTH + 0.5 or gaps[i + 1] < 2.0 * CURB_WIDTH + 0.5):
				continue
			var mid_curb := (curb[i] + curb[i + 1]) * 0.5
			var mid_outer := (outer[i] + outer[i + 1]) * 0.5
			if _point_on_other_road(mid_curb.x, mid_curb.z, part_index) or _point_on_other_road(mid_outer.x, mid_outer.z, part_index):
				continue
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
		# Fermer chaque extrémité de dalle, y compris après une interruption
		# causée par une entrée ou une chaussée transversale.
		var cap_cursor := 0
		while cap_cursor < built_segments.size():
			if built_segments[cap_cursor] == 0:
				cap_cursor += 1
				continue
			var cap_start := cap_cursor
			while cap_cursor + 1 < built_segments.size() and built_segments[cap_cursor + 1] == 1:
				cap_cursor += 1
			var cap_end := cap_cursor + 1
			for end_index in [cap_start, cap_end]:
				var top_edge := Vector3(edge[end_index].x, top_y[end_index], edge[end_index].z)
				var top_outer := Vector3(outer[end_index].x, top_y[end_index], outer[end_index].z)
				var base_outer := Vector3(outer[end_index].x, ground_y[end_index], outer[end_index].z)
				var base_edge := Vector3(edge[end_index].x, edge_y[end_index], edge[end_index].z)
				_add_plain_quad(curb_surface, top_edge, top_outer, base_outer, base_edge)
			cap_cursor += 1
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
	var batch_center := Vector3.ZERO
	for transform in _lamp_batch:
		batch_center += transform.origin
	batch_center /= float(_lamp_batch.size())
	for part_number in range(_lamp_parts.size()):
		var info: Dictionary = _lamp_parts[part_number]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = info.mesh
		multimesh.instance_count = _lamp_batch.size()
		var part_transform: Transform3D = info.xform
		for i in range(_lamp_batch.size()):
			var local_transform: Transform3D = _lamp_batch[i] * part_transform
			local_transform.origin -= batch_center
			multimesh.set_instance_transform(i, local_transform)
		var instance := MultiMeshInstance3D.new()
		instance.name = "OSM_Lampadaires_%s_%d" % [tile_name, part_number]
		instance.multimesh = multimesh
		instance.position = batch_center
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


func _offset_road_polyline(points: Array[Vector3], offset: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if points.size() < 2:
		return result
	# Nettoyer les doublons horizontaux sans changer le nombre ni l'ordre des sommets
	# renvoyés : les consommateurs associent les décalages aux altitudes par index.
	var clean_points: Array[Vector3] = []
	var point_map := PackedInt32Array()
	for point in points:
		if clean_points.is_empty():
			clean_points.append(point)
			point_map.append(0)
			continue
		var previous_point := clean_points[clean_points.size() - 1]
		var horizontal_distance := Vector2(point.x - previous_point.x, point.z - previous_point.z).length()
		if horizontal_distance > 0.05:
			clean_points.append(point)
			point_map.append(clean_points.size() - 1)
		else:
			point_map.append(clean_points.size() - 1)
			if point.y > previous_point.y:
				clean_points[clean_points.size() - 1] = Vector3(previous_point.x, point.y, previous_point.z)
	if clean_points.size() < 2:
		for point in points:
			result.append(Vector3(point.x, point.y, point.z))
		return result
	var clean_offsets: Array[Vector3] = []
	for i in range(clean_points.size()):
		var previous_direction: Vector2
		var next_direction: Vector2
		if i == 0:
			next_direction = Vector2(clean_points[1].x - clean_points[0].x, clean_points[1].z - clean_points[0].z).normalized()
			previous_direction = next_direction
		elif i == clean_points.size() - 1:
			previous_direction = Vector2(clean_points[i].x - clean_points[i - 1].x, clean_points[i].z - clean_points[i - 1].z).normalized()
			next_direction = previous_direction
		else:
			previous_direction = Vector2(clean_points[i].x - clean_points[i - 1].x, clean_points[i].z - clean_points[i - 1].z).normalized()
			next_direction = Vector2(clean_points[i + 1].x - clean_points[i].x, clean_points[i + 1].z - clean_points[i].z).normalized()
		var previous_normal := Vector2(-previous_direction.y, previous_direction.x)
		var next_normal := Vector2(-next_direction.y, next_direction.x)
		var miter := (previous_normal + next_normal).normalized()
		if miter.length_squared() < 0.001:
			miter = next_normal
		var denominator := maxf(absf(miter.dot(next_normal)), 0.35)
		var miter_length := clampf(offset / denominator, -absf(offset) * 2.2, absf(offset) * 2.2)
		var displaced := Vector2(clean_points[i].x, clean_points[i].z) + miter * miter_length
		clean_offsets.append(Vector3(displaced.x, clean_points[i].y, displaced.y))
	for point_index in range(points.size()):
		var offset_point := clean_offsets[point_map[point_index]]
		result.append(Vector3(offset_point.x, points[point_index].y, offset_point.z))
	return result

func _load_road_clearance_data() -> void:
	_road_clearance_segments.clear()
	_road_clearance_grid.clear()
	var data := _read_geojson("res://data/osm/roads.geojson")
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		var kind := str(props.get("highway", "residential"))
		var width := WorldMapRoadUtils.road_width(kind, props)
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


func _junction_arm_count(node_key: String, node_registry: Dictionary, all_parts: Array[Dictionary]) -> int:
	# Une route traversant le nœud au milieu de sa LineString apporte deux bras,
	# même si elle ne compte que comme une seule entrée dans le registre.
	var entries: PackedFloat32Array = node_registry.get(node_key, PackedFloat32Array())
	var arm_count := 0
	for entry_index in range(0, entries.size(), 3):
		var part_index := int(entries[entry_index])
		if part_index < 0 or part_index >= all_parts.size():
			continue
		var part: Dictionary = all_parts[part_index]
		var keys: Array[String] = part.keys
		for point_index in range(keys.size()):
			if keys[point_index] != node_key:
				continue
			if point_index > 0:
				arm_count += 1
			if point_index + 1 < keys.size():
				arm_count += 1
	return arm_count


func _round_convex_road_outline(outline: PackedVector2Array, radius: float = 0.45) -> PackedVector2Array:
	# Adoucit légèrement les angles du patch d'asphalte sans changer son emprise générale.
	# Les segments intermédiaires évitent les pointes triangulaires aux raccordements.
	var rounded := PackedVector2Array()
	if outline.size() < 3:
		return outline
	for i in range(outline.size()):
		var previous := outline[(i - 1 + outline.size()) % outline.size()]
		var current := outline[i]
		var next := outline[(i + 1) % outline.size()]
		var incoming := previous - current
		var outgoing := next - current
		var trim := minf(radius, minf(incoming.length(), outgoing.length()) * 0.22)
		if trim < 0.04:
			rounded.append(current)
			continue
		var start := current + incoming.normalized() * trim
		var finish := current + outgoing.normalized() * trim
		for step in range(4):
			var t := float(step) / 3.0
			var one_minus_t := 1.0 - t
			var point := start * (one_minus_t * one_minus_t) + current * (2.0 * one_minus_t * t) + finish * (t * t)
			if rounded.is_empty() or rounded[rounded.size() - 1].distance_to(point) > 0.01:
				rounded.append(point)
	return rounded


func _add_intersection_patch(surface: SurfaceTool, center: Vector3, node_key: String,
		node_registry: Dictionary, all_parts: Array[Dictionary]) -> void:
	# Empreinte calculée depuis les branches réellement connectées :
	# un T produit une forme à trois bras, un croisement une forme à quatre bras.
	# Cela évite le disque uniforme qui déborde sur les trottoirs aux carrefours étroits.
	var entries: PackedFloat32Array = node_registry.get(node_key, PackedFloat32Array())
	var outline_points := PackedVector2Array()
	var center_2d := Vector2(center.x, center.z)
	# Le dégagement des trottoirs est calculé avec la route la plus large du
	# carrefour. Le patch doit atteindre ce même rayon sur chaque branche,
	# sinon les coupes des trottoirs laissent des trous autour de l'asphalte.
	var junction_reach := 0.0
	for entry_index in range(0, entries.size(), 3):
		var connected_part_index := int(entries[entry_index])
		if connected_part_index < 0 or connected_part_index >= all_parts.size():
			continue
		var connected_part: Dictionary = all_parts[connected_part_index]
		junction_reach = maxf(junction_reach, float(connected_part.width) * 0.5 + JUNCTION_CLEARANCE)
	for entry_index in range(0, entries.size(), 3):
		var connected_part_index := int(entries[entry_index])
		if connected_part_index < 0 or connected_part_index >= all_parts.size():
			continue
		var connected_part: Dictionary = all_parts[connected_part_index]
		var connected_points: Array[Vector3] = connected_part.orig_points
		var connected_keys: Array[String] = connected_part.keys
		var half_width := float(connected_part.width) * 0.5
		for point_index in range(connected_keys.size()):
			if connected_keys[point_index] != node_key:
				continue
			var neighbours: Array[int] = []
			if point_index > 0:
				neighbours.append(point_index - 1)
			if point_index + 1 < connected_points.size():
				neighbours.append(point_index + 1)
			for neighbour_index in neighbours:
				var neighbour := connected_points[neighbour_index]
				var direction := Vector2(neighbour.x - center.x, neighbour.z - center.z).normalized()
				if direction.length_squared() < 0.001:
					continue
				var side := Vector2(-direction.y, direction.x) * half_width
				var reach := maxf(junction_reach, half_width + JUNCTION_CLEARANCE)
				var arm_end := center_2d + direction * reach
				outline_points.append(arm_end + side)
				outline_points.append(arm_end - side)
	if outline_points.size() < 6:
		_add_junction_patch(surface, center, 3.0)
		return
	var hull := Geometry2D.convex_hull(outline_points)
	if hull.size() < 3:
		_add_junction_patch(surface, center, 3.0)
		return
	var rounded_hull := _round_convex_road_outline(hull)
	var indices := Geometry2D.triangulate_polygon(rounded_hull)
	if indices.is_empty():
		_add_junction_patch(surface, center, 3.0)
		return
	for triangle_index in range(0, indices.size(), 3):
		var a: Vector2 = rounded_hull[indices[triangle_index]]
		var b: Vector2 = rounded_hull[indices[triangle_index + 1]]
		var c: Vector2 = rounded_hull[indices[triangle_index + 2]]
		_add_textured_tri(surface,
			_rp(Vector3(a.x, center.y, a.y), ROAD_LIFT + 0.06),
			_rp(Vector3(b.x, center.y, b.y), ROAD_LIFT + 0.06),
			_rp(Vector3(c.x, center.y, c.y), ROAD_LIFT + 0.06),
			ROAD_UV_METERS)


func _add_roundabout_island(surface: SurfaceTool, road_points: Array[Vector3], road_half_width: float) -> void:
	# La ligne OSM suit l'axe de l'anneau : on décale son contour vers l'intérieur
	# d'une demi-largeur de chaussée pour remplir uniquement l'îlot central.
	var outline := PackedVector2Array()
	for i in range(road_points.size() - 1):
		outline.append(Vector2(road_points[i].x, road_points[i].z))
	if outline.size() < 7:
		return
	var islands := Geometry2D.offset_polygon(outline, -maxf(road_half_width, 2.0))
	if islands.is_empty():
		return
	surface.set_color(Color(0.30, 0.38, 0.23))
	for island in islands:
		if island.size() < 3:
			continue
		var indices := Geometry2D.triangulate_polygon(island)
		if indices.is_empty():
			continue
		for i in range(0, indices.size(), 3):
			for vertex_index in range(3):
				var point: Vector2 = island[indices[i + vertex_index]]
				surface.add_vertex(_rp(Vector3(point.x, 0.0, point.y), ROAD_LIFT + 0.045))


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


func _add_stop_line(surface: SurfaceTool, junction: Vector3, inward_direction: Vector2, road_width: float, distance: float) -> void:
	if road_width < 5.5:
		return
	var direction := Vector3(inward_direction.x, 0.0, inward_direction.y).normalized()
	if direction.length_squared() < 0.001:
		return
	# Ligne transversale continue, placée juste après le passage béton
	# dans le sens d'approche du carrefour.
	var side := Vector3(-direction.z, 0.0, direction.x) * (road_width * 0.45)
	var center := junction + direction * distance
	var along := direction * 0.065
	surface.set_color(Color(0.91, 0.91, 0.88, 1.0))
	_add_quad(surface,
		_rp(center - along + side, MARKING_LIFT + 0.012),
		_rp(center - along - side, MARKING_LIFT + 0.012),
		_rp(center + along - side, MARKING_LIFT + 0.012),
		_rp(center + along + side, MARKING_LIFT + 0.012))


func _add_crosswalk(surface: SurfaceTool, junction: Vector3, inward_direction: Vector2, road_width: float, distance: float = 3.5) -> void:
	if road_width < 5.5:
		return
	var direction := Vector3(inward_direction.x, 0.0, inward_direction.y).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x) * (road_width * 0.46)
	var center := junction + direction * distance
	# À Libreville, représenter le passage comme des éléments de béton,
	# et non comme de simples bandes de peinture blanche.
	# Les dalles sont légèrement surélevées, avec joints sombres et nuances minérales.
	for slab_index in range(6):
		var offset := (float(slab_index) - 2.5) * 0.78
		var slab_center := center + direction * offset
		var along := direction * 0.29
		var lift := MARKING_LIFT + 0.035
		var shade := 0.72 + float((slab_index * 3) % 4) * 0.025
		var concrete := Color(shade * 0.99, shade, shade * 0.98, 1.0)
		var a := _rp(slab_center - along + side, lift)
		var b := _rp(slab_center - along - side, lift)
		var c := _rp(slab_center + along - side, lift)
		var d := _rp(slab_center + along + side, lift)
		surface.set_color(concrete)
		_add_quad(surface, a, b, c, d)


func _road_has_center_marking(props: Dictionary, road_kind: String) -> bool:
	return WorldMapRoadUtils.road_lane_count(props) >= 2 or road_kind in ["trunk", "primary", "secondary"]


func _add_road_lane_markings(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, lanes: int, oneway: bool, props: Dictionary) -> void:
	var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
	if direction.length_squared() < 0.001:
		return
	var perpendicular := Vector3(-direction.y, 0.0, direction.x)
	var half := width * 0.5
	var forward := str(props.get("lanes:forward", "")).to_int()
	var backward := str(props.get("lanes:backward", "")).to_int()
	if forward > 0 and backward > 0 and not oneway:
		# Répartition exacte des voies de chaque sens selon les tags directionnels OSM.
		var total := forward + backward
		var divider := -half + width * float(forward) / float(total)
		_add_marking_quad(surface, a + perpendicular * (divider - 0.045), b + perpendicular * (divider - 0.045), 0.035)
		_add_marking_quad(surface, a + perpendicular * (divider + 0.045), b + perpendicular * (divider + 0.045), 0.035)
		for lane_index in range(1, forward):
			var offset := -half + width * float(lane_index) / float(total)
			_add_road_dashes_offset(surface, a, b, perpendicular, offset)
		for lane_index in range(1, backward):
			var offset := divider + width * float(lane_index) / float(total)
			_add_road_dashes_offset(surface, a, b, perpendicular, offset)
		return
	var count := maxi(2, lanes)
	if oneway:
		# Une chaussée à sens unique : séparations internes, sans fausse ligne centrale.
		for lane_index in range(1, count):
			var offset := -half + width * float(lane_index) / float(count)
			_add_road_dashes_offset(surface, a, b, perpendicular, offset)
	elif count <= 2 or count % 2 != 0:
		# Pour un nombre impair sans détail directionnel, ne pas inventer la répartition.
		_add_road_center_dashes(surface, a, b)
	else:
		# Double ligne centrale et séparations des voies supplémentaires de chaque côté.
		_add_marking_quad(surface, a + perpendicular * -0.07, b + perpendicular * -0.07, 0.035)
		_add_marking_quad(surface, a + perpendicular * 0.07, b + perpendicular * 0.07, 0.035)
		var lanes_each_side := int(count / 2)
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
	var features: Array = _filter_features_to_player_zone(data.get("features", []).duplicate(), WORLD_BUILDING_RADIUS)
	var player_for_buildings := get_parent().get_node_or_null("Player") as Node3D
	var building_origin := Vector2.ZERO
	if player_for_buildings != null:
		building_origin = Vector2(player_for_buildings.global_position.x, player_for_buildings.global_position.z)
	# Les empreintes proches du joueur sont traitées en premier : les premiers
	# lots de meshes contiennent donc le quartier de départ, pas l'autre bout de Libreville.
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _feature_world_center(a).distance_squared_to(building_origin) < _feature_world_center(b).distance_squared_to(building_origin)
	)
	var restaurant_scenes: Array[PackedScene] = []
	for restaurant_path in [
		"res://assets/models/baie_des_rois/restaurant_pavillon_baie_des_rois_compact.glb",
		"res://assets/models/baie_des_rois/restaurant_pavillon_baie_des_rois.glb",
		"res://assets/models/baie_des_rois/restaurant_pavillon_baie_des_rois_large.glb"
	]:
		var restaurant_scene := load(restaurant_path) as PackedScene
		if restaurant_scene != null:
			restaurant_scenes.append(restaurant_scene)
	var baie_restaurant_count := 0
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
		var feature_center := _feature_world_center(feature)
		if not restaurant_scenes.is_empty() and _is_baie_des_rois_restaurant_candidate(props, feature_center):
			if _place_baie_des_rois_restaurant(feature, restaurant_scenes, baie_restaurant_count):
				baie_restaurant_count += 1
				continue
		var building_kind := str(props.get("building", "yes"))
		var osm_id := int(props.get("osm_id", index))
		var height := WorldMapBuildingStyleUtils.building_height(building_kind, osm_id, props)
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
			var facade_col := WorldMapBuildingStyleUtils.building_color(building_kind, osm_id, props)
			for footprint in footprint_parts:
				if footprint.size() < 3:
					continue
				# Évite les fragments résiduels sans supprimer les petits bâtiments intacts.
				if footprint_parts.size() > 1 and WorldMapGeometryUtils.polygon_area_abs(footprint) < 2.0:
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
				_add_building(surface, roof_surface, detail_surface, footprint, indices, height, WorldMapBuildingStyleUtils.roof_color(building_kind, osm_id, props), building_kind, osm_id, props, facade_col, building_base_y)
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
		if index % 40 == 0:
			await get_tree().process_frame
	if batch_count > 0:
		_commit_surface(surface, "OSM_Buildings_%03d" % batch_index)
		_commit_surface(roof_surface, "OSM_Roofs_%03d" % batch_index)
		_commit_surface(detail_surface, "OSM_Facade_Details_%03d" % batch_index)



func _is_baie_des_rois_restaurant_candidate(props: Dictionary, center: Vector2) -> bool:
	if center.distance_to(BAIE_DES_ROIS_SITE_CENTER) > BAIE_DES_ROIS_SITE_RADIUS:
		return false
	var amenity := str(props.get("amenity", "")).to_lower()
	var building := str(props.get("building", "")).to_lower()
	var shop := str(props.get("shop", "")).to_lower()
	var name := str(props.get("name", "")).to_lower()
	var osm_id := int(props.get("osm_id", 0))
	# Ces cinq empreintes OSM sont les petits commerces/kiosques identifiés sur
	# la promenade nord ; ne pas transformer les immeubles voisins en restaurants.
	if osm_id in [1070652037, 1070652038, 1070652039, 1070652040, 1070652041]:
		return true
	var food_tags := ["restaurant", "cafe", "fast_food", "food_court", "bar"]
	if amenity in food_tags or building in ["restaurant", "catering"]:
		return true
	if building in ["commercial", "retail"] and (shop in ["food", "bakery", "convenience", "restaurant"] or not name.is_empty()):
		return true
	for keyword in ["restaurant", "resto", "cafe", "café", "snack", "pavillon"]:
		if name.contains(keyword):
			return true
	return false


func _place_baie_des_rois_restaurant(feature: Dictionary, scenes: Array[PackedScene], index: int) -> bool:
	var geometry: Dictionary = feature.get("geometry", {})
	var coordinates: Array = []
	match str(geometry.get("type", "")):
		"Polygon":
			var rings: Array = geometry.get("coordinates", [])
			if not rings.is_empty():
				coordinates = rings[0]
		"MultiPolygon":
			var polygons: Array = geometry.get("coordinates", [])
			if not polygons.is_empty() and not polygons[0].is_empty():
				coordinates = polygons[0][0]
	if coordinates.size() < 4 or scenes.is_empty():
		return false

	var points := PackedVector2Array()
	var center := Vector2.ZERO
	for coordinate in coordinates:
		var point3 := _geo_to_world(coordinate)
		var point := Vector2(point3.x, point3.z)
		points.append(point)
		center += point
	center /= float(points.size())

	# Axe principal et largeur réelle mesurés dans le polygone OSM.
	var longest_edge := Vector2.RIGHT
	var longest_length := 0.0
	for point_index in range(points.size()):
		var edge := points[(point_index + 1) % points.size()] - points[point_index]
		if edge.length_squared() > longest_length:
			longest_length = edge.length_squared()
			longest_edge = edge
	if longest_length < 16.0:
		return false
	var axis := longest_edge.normalized()
	var side_axis := Vector2(-axis.y, axis.x)
	var min_along := INF
	var max_along := -INF
	var min_side := INF
	var max_side := -INF
	for point in points:
		var along := point.dot(axis)
		var across := point.dot(side_axis)
		min_along = minf(min_along, along)
		max_along = maxf(max_along, along)
		min_side = minf(min_side, across)
		max_side = maxf(max_side, across)
	var target_width := max_along - min_along
	var target_depth := max_side - min_side
	if target_width < 4.0 or target_depth < 4.0:
		return false

	# Dimensions X/Z des trois modèles Blender : compact, standard, grand.
	var model_dimensions: Array[Vector2] = [
		Vector2(6.8, 5.8),
		Vector2(8.4, 6.8),
		Vector2(10.0, 7.8)
	]
	var best_scene: PackedScene
	var best_scale := 0.0
	var best_score := INF
	for scene_index in range(mini(scenes.size(), model_dimensions.size())):
		var dimensions := model_dimensions[scene_index]
		var fit_scale := minf(target_width / dimensions.x, target_depth / dimensions.y) * 0.94
		var coverage := (dimensions.x * dimensions.y * fit_scale * fit_scale) / (target_width * target_depth)
		# Choisir la variante dont l'échelle reste la plus proche de 1.0 :
		# cela évite d'agrandir un petit kiosque de 60 % alors qu'un modèle large
		# existe déjà pour l'empreinte OSM.
		var score := absf(log(maxf(fit_scale, 0.001))) + (1.0 - coverage) * 0.25
		if fit_scale > 0.0 and score < best_score:
			best_score = score
			best_scale = fit_scale
			best_scene = scenes[scene_index]
	if best_scene == null:
		return false

	var instance := best_scene.instantiate() as Node3D
	if instance == null:
		return false
	var props: Dictionary = feature.get("properties", {})
	var osm_id := int(props.get("osm_id", index))
	var label := str(props.get("name", "Kiosque commercial"))
	instance.name = "Kiosque_BaieDesRois_OSM_%d_%s" % [osm_id, label.replace(" ", "_")]
	instance.position = Vector3(center.x, _terrain_height_at_world(center.x, center.y) + 0.025, center.y)
	instance.rotation.y = atan2(-axis.y, axis.x)
	instance.scale = Vector3.ONE * best_scale
	add_child(instance)
	return true


func _load_localities() -> void:
	var data := _read_geojson("res://data/osm/localities.geojson")
	if data.is_empty():
		push_warning("localities.geojson absent : les noms de quartiers/localités ne seront pas affichés.")
		return
	# Le panneau de téléportation doit couvrir les six arrondissements, pas seulement
	# le rayon de streaming autour du point de départ. Cette couche ne contient qu'une
	# centaine de points : charger toute la liste reste très léger.
	var features: Array = data.get("features", []).duplicate()
	var player_for_localities := get_parent().get_node_or_null("Player") as Node3D
	var locality_origin := Vector2.ZERO
	if player_for_localities != null:
		locality_origin = Vector2(player_for_localities.global_position.x, player_for_localities.global_position.z)
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var props_a: Dictionary = a.get("properties", {})
		var props_b: Dictionary = b.get("properties", {})
		var priority_a := _locality_priority(str(props_a.get("place", "")))
		var priority_b := _locality_priority(str(props_b.get("place", "")))
		if priority_a != priority_b:
			return priority_a < priority_b
		return _feature_world_center(a).distance_squared_to(locality_origin) < _feature_world_center(b).distance_squared_to(locality_origin)
	)
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
	# Les polygones OSM sont la source de vérité pour les quartiers géolocalisés.
	# On ne dépend plus des points localities filtrés autour du joueur : cela évite
	# le message « aucun quartier dans cette zone » lorsque le joueur démarre en bord de mer.
	for key in _neighbourhood_polygons.keys():
		var osm_id := int(key)
		var polygon: PackedVector2Array = _neighbourhood_polygons[osm_id]
		if polygon.size() < 4:
			continue
		var point := WorldMapGeometryUtils.polygon_centroid(polygon)
		if not WorldMapGeometryUtils.point_in_polygon(point, polygon):
			# Pour un quartier concave, rapprocher le centroïde des milieux de côtés
			# jusqu'à trouver un point réellement à l'intérieur du contour.
			var found_inside := false
			for vertex_index in range(polygon.size() - 1):
				var candidate := polygon[vertex_index].lerp(point, 0.5)
				if WorldMapGeometryUtils.point_in_polygon(candidate, polygon):
					point = candidate
					found_inside = true
					break
			if not found_inside:
				point = polygon[0].lerp(point, 0.02)
		var ground_y := _terrain_height_at_world(point.x, point.y)
		destinations.append({
			"name": str(_neighbourhood_names.get(osm_id, "Quartier")),
			"arrondissement": str(_neighbourhood_arrondissements.get(osm_id, "")),
			"osm_id": osm_id,
			"position": Vector3(point.x, ground_y + 1.8, point.y)
		})
	destinations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("arrondissement", "")) == str(b.get("arrondissement", "")):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return str(a.get("arrondissement", "")) < str(b.get("arrondissement", ""))
	)
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
	var poi_features: Array = _filter_features_to_player_zone(data.get("features", []).duplicate(), WORLD_POI_RADIUS)
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
		_add_map_label(place_name, _geo_to_world(coordinates) + Vector3.UP * 0.55, WorldMapColorUtils.poi_color(kind), 500.0)
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


func _collect_geo_points(value: Variant, points: Array[Vector2]) -> void:
	if not value is Array:
		return
	var values: Array = value
	if values.size() >= 2 and typeof(values[0]) in [TYPE_FLOAT, TYPE_INT] and typeof(values[1]) in [TYPE_FLOAT, TYPE_INT]:
		var world_point := _geo_to_world([float(values[0]), float(values[1])])
		points.append(Vector2(world_point.x, world_point.z))
		return
	for child in values:
		_collect_geo_points(child, points)



func _filter_features_to_player_zone(features: Array, radius_m: float) -> Array:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return features
	var center := Vector2(player.global_position.x, player.global_position.z)
	var radius_squared := radius_m * radius_m
	var selected: Array = []
	for feature in features:
		if not feature is Dictionary:
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var points: Array[Vector2] = []
		_collect_geo_points(geometry.get("coordinates", []), points)
		if points.is_empty():
			continue
		# La distance au centre géométrique permet de ne créer que les objets
		# appartenant à la zone active et à sa couronne de préparation.
		var feature_center := Vector2.ZERO
		for point in points:
			feature_center += point
		feature_center /= float(points.size())
		if feature_center.distance_squared_to(center) <= radius_squared:
			selected.append(feature)
	return selected

func _feature_world_center(feature: Dictionary) -> Vector2:
	var geometry: Dictionary = feature.get("geometry", {})
	var points: Array[Vector2] = []
	_collect_geo_points(geometry.get("coordinates", []), points)
	if points.is_empty():
		var player := get_parent().get_node_or_null("Player") as Node3D
		return Vector2(player.global_position.x, player.global_position.z) if player != null else Vector2.ZERO
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / float(points.size())


func _geo_to_world(coordinate: Array) -> Vector3:
	var lon := float(coordinate[0])
	var lat := float(coordinate[1])
	var x := (lon - CENTER_LON) * METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT))
	var z := -(lat - CENTER_LAT) * METERS_PER_DEG_LAT
	return Vector3(x, _terrain_height_at_world(x, z), z)

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
	var roof_style := WorldMapBuildingStyleUtils.roof_style(building_kind, osm_id, props)
	var pitched_roof := false
	if WorldMapBuildingStyleUtils.should_use_pitched_roof(building_kind, props, points.size()):
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
