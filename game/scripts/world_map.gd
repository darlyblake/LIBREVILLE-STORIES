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

@export var show_roads := true
@export var show_buildings := true

var _road_count := 0
var _building_count := 0
var _poi_count := 0
var _environment_count := 0
var _neighbourhood_count := 0
var _locality_count := 0
var _environment_material: StandardMaterial3D
var _road_labels := 0
var _road_material: StandardMaterial3D
var _building_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _facade_detail_material: StandardMaterial3D
var _locality_points: Array[Dictionary] = []
var _location_hud: Label
var _location_refresh := 0.0

func _ready() -> void:
	_road_material = _make_material(Color.WHITE)
	_road_material.vertex_color_use_as_albedo = true
	_environment_material = _make_material(Color.WHITE)
	_environment_material.vertex_color_use_as_albedo = true
	_load_environment()
	_load_neighbourhoods()
	_load_localities()
	_building_material = _make_material(Color(0.76, 0.68, 0.56))
	# Les couleurs attribuées aux bâtiments par type/OSM ID doivent être visibles.
	_building_material.vertex_color_use_as_albedo = true
	_roof_material = _make_material(Color.WHITE)
	_roof_material.vertex_color_use_as_albedo = true
	_roof_material.albedo_texture = _make_roof_tile_texture()
	_facade_detail_material = _make_material(Color.WHITE)
	_facade_detail_material.vertex_color_use_as_albedo = true
	if show_roads:
		_load_roads()
	if show_buildings:
		_load_buildings()
	_load_pois()
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
	_location_hud.text = "LIBREVILLE  |  localisation en cours..."
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
	_location_hud.text = "LIBREVILLE  |  POSITION DU JOUEUR\n%s\nGPS  %.5f, %.5f" % [location_line, latitude, longitude]

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
			if kind in ["vegetation", "green_space"]:
				_scatter_trees_in_polygon(points, int(props.get("osm_id", _environment_count)), tree_positions)
			surface.set_color(_environment_color(kind))
			for i in range(0, indices.size(), 3):
				var p0 := points[indices[i]]
				var p1 := points[indices[i + 1]]
				var p2 := points[indices[i + 2]]
				surface.add_vertex(Vector3(p0.x, 0.012, p0.y))
				surface.add_vertex(Vector3(p1.x, 0.012, p1.y))
				surface.add_vertex(Vector3(p2.x, 0.012, p2.y))
			added = true
		elif str(geometry.get("type", "")) == "LineString":
			var coords: Array = geometry.get("coordinates", [])
			var width := 5.0 if kind == "coastline" else (2.0 if kind == "waterway" else 1.2)
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
	_commit_tree_instances(tree_positions)


func _scatter_trees_in_polygon(points: PackedVector2Array, osm_id: int, output: Array[Vector3]) -> void:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(osm_id) + 73421
	var added := 0
	var attempts := 0
	while added < desired and attempts < desired * 18:
		attempts += 1
		var candidate := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y))
		if Geometry2D.is_point_in_polygon(candidate, points):
			output.append(Vector3(candidate.x, 0.0, candidate.y))
			added += 1


func _commit_tree_instances(positions: Array[Vector3]) -> void:
	if positions.is_empty():
		return
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.16
	trunk_mesh.height = 1.4
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.85
	canopy_mesh.height = 2.0
	var trunk_material := _make_material(Color(0.30, 0.20, 0.12))
	var canopy_material := _make_material(Color(0.16, 0.34, 0.18))
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = positions.size()
	var canopies := MultiMesh.new()
	canopies.transform_format = MultiMesh.TRANSFORM_3D
	canopies.mesh = canopy_mesh
	canopies.instance_count = positions.size()
	for i in range(positions.size()):
		var position := positions[i]
		trunks.set_instance_transform(i, Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.7))
		var canopy_basis := Basis.IDENTITY.scaled(Vector3(1.0, 1.25, 1.0))
		canopies.set_instance_transform(i, Transform3D(canopy_basis, position + Vector3.UP * 2.25))
	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.name = "OSM_Tree_Trunks"
	trunk_instance.multimesh = trunks
	trunk_instance.material_override = trunk_material
	trunk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunk_instance)
	var canopy_instance := MultiMeshInstance3D.new()
	canopy_instance.name = "OSM_Tree_Canopies"
	canopy_instance.multimesh = canopies
	canopy_instance.material_override = canopy_material
	canopy_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canopy_instance)
	print("LIBREVILLE STORIES | arbres 3D instanciés : %d" % positions.size())


func _environment_color(kind: String) -> Color:
	match kind:
		"water", "waterway":
			return Color(0.20, 0.48, 0.66)
		"coastline":
			return Color(0.78, 0.69, 0.49)
		"vegetation":
			return Color(0.20, 0.39, 0.25)
		"green_space":
			return Color(0.29, 0.48, 0.27)
		"natural_surface":
			return Color(0.72, 0.65, 0.48)
		_:
			return Color(0.36, 0.43, 0.32)


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


func _load_roads() -> void:
	var data := _read_geojson("res://data/osm/roads.geojson")
	if data.is_empty():
		push_warning("roads.geojson absent : carte routière non chargée.")
		return
	var surface := _new_surface(_road_material)
	var sidewalk_material := _make_material(Color(0.62, 0.61, 0.56))
	sidewalk_material.vertex_color_use_as_albedo = true
	var sidewalk_surface := _new_surface(sidewalk_material)
	var marking_material := _make_material(Color(0.92, 0.92, 0.86))
	marking_material.vertex_color_use_as_albedo = true
	var marking_surface := _new_surface(marking_material)
	var crosswalk_material := _make_material(Color(0.94, 0.95, 0.90))
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
				_add_map_label(str(props.get("name")), _geo_to_world(midpoint) + Vector3.UP * 1.25, Color(0.92, 0.95, 1.0), 280.0)
				_road_labels += 1
		var road_kind := str(props.get("highway", "residential"))
		var width := _road_width(road_kind, props)
		var sidewalk_mode := _road_sidewalk_mode(props, road_kind)
		var has_center_marking := _road_has_center_marking(props, road_kind)
		surface.set_color(_road_color(road_kind, props))
		marking_surface.set_color(Color(0.94, 0.94, 0.88))
		sidewalk_surface.set_color(Color(0.66, 0.65, 0.60))
		var added := false
		for coords in lines:
			if coords.size() < 2:
				continue
			var supports_crosswalk := road_kind in ["primary", "secondary", "tertiary"]
			if supports_crosswalk:
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
				if direction.length_squared() < 0.01:
					continue
				var side := Vector3(-direction.normalized().y, 0.0, direction.normalized().x) * width * 0.5
				_add_quad(surface, a + side + Vector3.UP * 0.025, a - side + Vector3.UP * 0.025, b - side + Vector3.UP * 0.025, b + side + Vector3.UP * 0.025)
				if has_center_marking:
					_add_road_center_dashes(marking_surface, a, b)
				if sidewalk_mode != "none":
					var side_width := 1.25
					var outer_offset := width * 0.5 + side_width
					var inner_offset := width * 0.5
					if sidewalk_mode in ["both", "left"]:
						_add_quad(sidewalk_surface,
							a + side * inner_offset + Vector3.UP * 0.04,
						a + side * outer_offset + Vector3.UP * 0.04,
						b + side * outer_offset + Vector3.UP * 0.04,
						b + side * inner_offset + Vector3.UP * 0.04)
					if sidewalk_mode in ["both", "right"]:
						_add_quad(sidewalk_surface,
							a - side * inner_offset + Vector3.UP * 0.04,
						a - side * outer_offset + Vector3.UP * 0.04,
						b - side * outer_offset + Vector3.UP * 0.04,
						b - side * inner_offset + Vector3.UP * 0.04)
				added = true
		if added:
			_road_count += 1
			batch_count += 1
		if batch_count >= ROADS_PER_MESH:
			_commit_surface(surface, "OSM_Roads_%03d" % batch_index)
			_commit_surface(sidewalk_surface, "OSM_Sidewalks_%03d" % batch_index)
			_commit_surface(marking_surface, "OSM_Road_Markings_%03d" % batch_index)
			_commit_surface(crosswalk_surface, "OSM_Crosswalks_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(_road_material)
			sidewalk_surface = _new_surface(sidewalk_material)
			marking_surface = _new_surface(marking_material)
			crosswalk_surface = _new_surface(crosswalk_material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Roads_%03d" % batch_index)
		_commit_surface(sidewalk_surface, "OSM_Sidewalks_%03d" % batch_index)
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
		surface.add_vertex(Vector3(center.x + cos(a) * radius, y, center.z + sin(a) * radius))
		surface.add_vertex(Vector3(center.x + cos(b) * radius, y, center.z + sin(b) * radius))


func _add_crosswalk(surface: SurfaceTool, junction: Vector3, inward_direction: Vector2, road_width: float) -> void:
	if road_width < 5.0:
		return
	var direction := Vector3(inward_direction.x, 0.0, inward_direction.y)
	var side := Vector3(-direction.z, 0.0, direction.x) * road_width * 0.40
	var center := junction + direction * 3.2 + Vector3.UP * 0.075
	# Marquage schématique aux carrefours OSM à trois branches ou plus.
	for stripe_index in range(5):
		var offset := (float(stripe_index) - 2.0) * 0.78
		var stripe_center := center + direction * offset
		var along := direction * 0.18
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


func _add_road_center_dashes(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := delta.length()
	if length < 5.0:
		return
	var direction := delta / length
	var side := Vector3(-direction.z, 0.0, direction.x) * 0.07
	var dash_length := 3.0
	var gap_length := 5.0
	var distance := 1.0
	while distance + dash_length < length:
		var start_point := a + direction * distance + Vector3.UP * 0.065
		var end_point := a + direction * (distance + dash_length) + Vector3.UP * 0.065
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
	# Sur les axes structurants, trottoirs de représentation visuelle faute de tag explicite.
	if road_kind in ["trunk", "primary", "secondary"]:
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
			surface.set_color(_building_color(building_kind, osm_id, props))
			_add_building(surface, roof_surface, detail_surface, points, indices, height, _roof_color(building_kind, osm_id, props), building_kind, osm_id, props)
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
		_add_map_label(label_text, world_position + Vector3.UP * 2.8, Color(1.0, 0.84, 0.48), 900.0)
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
		_add_map_label(place_name, _geo_to_world(coordinates) + Vector3.UP * 1.15, _poi_color(kind), 500.0)
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
	label.font_size = 24
	label.pixel_size = 0.008
	label.modulate = label_color
	label.outline_size = 5
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
	return Vector3(x, 0.0, z)

func _road_color(kind: String, props: Dictionary = {}) -> Color:
	# Les surfaces OSM priment sur la palette de secours par catégorie.
	var surface_tag := str(props.get("surface", "")).to_lower()
	match surface_tag:
		"asphalt", "paved":
			return Color(0.25, 0.27, 0.27)
		"concrete":
			return Color(0.43, 0.44, 0.42)
		"paving_stones", "sett":
			return Color(0.48, 0.46, 0.41)
		"gravel", "fine_gravel":
			return Color(0.48, 0.44, 0.36)
		"ground", "dirt", "earth", "unpaved":
			return Color(0.43, 0.37, 0.29)
	# Hiérarchie de secours lorsque le revêtement n'est pas renseigné.
	match kind:
		"motorway", "trunk":
			return Color(0.22, 0.25, 0.26)
		"primary":
			return Color(0.25, 0.28, 0.29)
		"secondary":
			return Color(0.28, 0.30, 0.30)
		"tertiary":
			return Color(0.30, 0.32, 0.31)
		"residential", "unclassified":
			return Color(0.33, 0.34, 0.32)
		"service":
			return Color(0.30, 0.31, 0.30)
		"footway", "path", "steps", "cycleway":
			return Color(0.48, 0.45, 0.39)
		_:
			return Color(0.31, 0.33, 0.32)

func _road_width(kind: String, props: Dictionary = {}) -> float:
	# Utilise la largeur réelle ou le nombre de voies OSM quand ils existent.
	var tagged_width := str(props.get("width", "")).replace("m", "").strip_edges().to_float()
	if tagged_width >= 1.5 and tagged_width <= 40.0:
		return tagged_width
	var lanes := str(props.get("lanes", "")).to_int()
	if lanes >= 1 and lanes <= 8:
		return clampf(float(lanes) * 3.1 + 0.6, 3.0, 25.0)
	match kind:
		"motorway", "trunk": return 11.0
		"primary": return 8.5
		"secondary": return 7.0
		"tertiary": return 5.8
		"residential", "unclassified": return 4.8
		"service": return 3.0
		"footway", "path", "steps": return 1.5
		_: return 4.0

func _building_height(kind: String, osm_id: int, props: Dictionary) -> float:
	var tagged_height := str(props.get("height", "")).to_float()
	if tagged_height >= 2.5 and tagged_height <= 150.0:
		return tagged_height
	var levels := str(props.get("building:levels", "")).to_int()
	if levels > 0 and levels <= 40:
		return clampf(float(levels) * 3.1, 3.0, 120.0)
	match kind:
		"cathedral", "university", "hospital", "government", "commercial", "office":
			return 10.0 + float(abs(osm_id) % 90) / 10.0
		"apartments", "hotel", "dormitory":
			return 9.0 + float(abs(osm_id) % 70) / 10.0
		"house", "detached", "residential", "semidetached_house":
			return 4.0 + float(abs(osm_id) % 25) / 10.0
		"warehouse", "industrial", "supermarket":
			return 5.0 + float(abs(osm_id) % 35) / 10.0
		_:
			return 3.5 + float(abs(osm_id) % 35) / 10.0

func _building_color(kind: String, osm_id: int, props: Dictionary = {}) -> Color:
	# Priorité aux couleurs réellement renseignées dans OSM.
	var tagged := str(props.get("building:colour", props.get("building:color", ""))).strip_edges()
	if not tagged.is_empty():
		return Color.from_string(tagged, Color(0.76, 0.70, 0.62))
	# Palette sobre et variée inspirée des façades observées à Libreville :
	# enduit clair, sable, gris ciment, blanc cassé et quelques tons chauds.
	var palette: Array[Color] = [
		Color(0.78, 0.72, 0.63),
		Color(0.70, 0.66, 0.58),
		Color(0.83, 0.80, 0.72),
		Color(0.62, 0.62, 0.57),
		Color(0.76, 0.67, 0.57),
		Color(0.86, 0.82, 0.73),
		Color(0.67, 0.70, 0.67),
		Color(0.73, 0.61, 0.51)
	]
	var selected := palette[abs(osm_id) % palette.size()]
	if kind in ["industrial", "warehouse"]:
		selected = Color(0.58, 0.61, 0.59) if abs(osm_id) % 3 == 0 else Color(0.67, 0.67, 0.62)
	elif kind in ["commercial", "retail", "supermarket", "office"]:
		selected = Color(0.72, 0.72, 0.67) if abs(osm_id) % 2 == 0 else Color(0.78, 0.75, 0.67)
	return selected

func _roof_style(kind: String, osm_id: int, props: Dictionary = {}) -> int:
	# Les tags de matériau OSM priment sur la règle visuelle de secours.
	var material_tag := str(props.get("roof:material", "")).to_lower()
	if material_tag in ["metal", "tin", "corrugated_metal", "sheet", "steel"]:
		return 1
	if material_tag in ["concrete", "concrete_plates", "asphalt"]:
		return 2
	if material_tag in ["tile", "tiles", "roof_tiles", "terracotta"]:
		return 0
	# 0 = tuiles, 1 = tôle nervurée, 2 = dalle béton. Sans tag, estimation.
	match kind:
		"industrial", "warehouse", "carport", "shed":
			return 1
		"commercial", "retail", "office", "supermarket", "government":
			return 2
		_:
			return 0 if abs(osm_id) % 5 != 0 else 2


func _roof_color(kind: String, osm_id: int, props: Dictionary = {}) -> Color:
	var tagged := str(props.get("roof:colour", props.get("roof:color", ""))).strip_edges()
	if not tagged.is_empty():
		return Color.from_string(tagged, Color(0.62, 0.34, 0.25))
	# La teinte varie légèrement, le motif vient de la bande de texture choisie.
	var variation := float(abs(osm_id) % 7) * 0.018
	match _roof_style(kind, osm_id, props):
		1:
			return Color(0.91 + variation * 0.3, 0.94 + variation * 0.2, 0.94 + variation * 0.2)
		2:
			return Color(0.83 + variation * 0.3, 0.84 + variation * 0.3, 0.80 + variation * 0.3)
		_:
			return Color(0.96 + variation * 0.2, 0.92 + variation * 0.2, 0.88 + variation * 0.2)


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
				var row := int(local_y / 16)
				var tile_x := (x + (16 if row % 2 == 1 else 0)) % 32
				var shade := 0.78 if local_y % 16 == 15 else (0.91 if local_y % 16 == 0 or tile_x == 0 else 1.0)
				pixel = Color(0.60 * shade, 0.31 * shade, 0.22 * shade, 1.0)
			elif style == 1:
				var rib := 0.76 if local_x == 0 or local_x == 1 else (1.0 if local_x < 27 else 0.88)
				var wave := 0.94 if local_y % 8 == 0 else 1.0
				pixel = Color(0.48 * rib * wave, 0.53 * rib * wave, 0.55 * rib * wave, 1.0)
			else:
				var seam := 0.91 if local_x == 0 or local_y % 32 == 0 else 1.0
				var grain := 0.985 + float((x * 17 + local_y * 13) % 7) * 0.004
				pixel = Color(0.58 * seam * grain, 0.59 * seam * grain, 0.56 * seam * grain, 1.0)
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
		roof_tint: Color, building_kind: String, osm_id: int, props: Dictionary = {}) -> void:
	var longest_edge_index := 0
	var longest_edge_length := 0.0
	var signed_area := 0.0
	for area_index in range(points.size()):
		var area_a := points[area_index]
		var area_b := points[(area_index + 1) % points.size()]
		signed_area += area_a.x * area_b.y - area_b.x * area_a.y
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var edge_length := a.distance_to(b)
		if edge_length > longest_edge_length:
			longest_edge_length = edge_length
			longest_edge_index = i
		var uv_length := edge_length / 3.0
		var uv_height := height / 3.0
		_add_uv_quad(walls,
			Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y),
			Vector3(b.x, height, b.y), Vector3(a.x, height, a.y),
			Vector2(0.0, 0.0), Vector2(uv_length, 0.0),
			Vector2(uv_length, uv_height), Vector2(0.0, uv_height))
		var edge_direction := Vector3((b.x - a.x) / maxf(edge_length, 0.001), 0.0, (b.y - a.y) / maxf(edge_length, 0.001))
		var outward_normal := Vector3(edge_direction.z, 0.0, -edge_direction.x) * (1.0 if signed_area > 0.0 else -1.0)
		_add_facade_windows(details, a, b, height, building_kind, osm_id, outward_normal)
	if longest_edge_length >= 2.8 and building_kind not in ["garage", "shed", "roof", "carport"]:
		var door_a := points[longest_edge_index]
		var door_b := points[(longest_edge_index + 1) % points.size()]
		var door_direction := Vector3((door_b.x - door_a.x) / longest_edge_length, 0.0, (door_b.y - door_a.y) / longest_edge_length)
		var door_normal := Vector3(door_direction.z, 0.0, -door_direction.x) * (1.0 if signed_area > 0.0 else -1.0)
		_add_facade_door(details, door_a, door_b, door_normal)
	roofs.set_color(roof_tint)
	var roof_style := _roof_style(building_kind, osm_id, props)
	var pitched_roof := false
	if points.size() == 4 and building_kind in ["house", "residential", "detached", "semidetached_house", "bungalow"]:
		pitched_roof = _add_pitched_roof(roofs, points, height, roof_style)
	if not pitched_roof:
		for i in range(0, indices.size(), 3):
			var p0 := points[indices[i]]
			var p1 := points[indices[i + 1]]
			var p2 := points[indices[i + 2]]
			_add_roof_uv_triangle(roofs, Vector3(p0.x, height + 0.035, p0.y),
				Vector3(p1.x, height + 0.035, p1.y), Vector3(p2.x, height + 0.035, p2.y), roof_style)


func _add_pitched_roof(surface: SurfaceTool, points: PackedVector2Array, wall_height: float, style: int) -> bool:
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
	var roof_y := wall_height + 0.035
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
		height: float, building_kind: String, osm_id: int, normal: Vector3) -> void:
	if building_kind in ["garage", "shed", "roof", "carport", "warehouse", "industrial"]:
		return
	var edge := b - a
	var edge_length := edge.length()
	if edge_length < 4.2 or height < 2.8:
		return
	var tangent := Vector3(edge.x / edge_length, 0.0, edge.y / edge_length)
	var floors := clampi(int(ceil(height / 3.1)), 1, 8)
	var window_count := clampi(int(floor(edge_length / 5.2)), 1, 5)
	var spacing := edge_length / float(window_count)
	var window_width := clampf(spacing * 0.34, 0.65, 1.25)
	var window_height := 0.95 if floors == 1 else 1.15
	var glass := Color(0.16, 0.25, 0.31) if abs(osm_id) % 3 == 0 else Color(0.22, 0.31, 0.36)
	for floor_index in range(floors):
		var center_y := 1.15 + float(floor_index) * 3.05
		if center_y + window_height * 0.5 > height - 0.25:
			continue
		for window_index in range(window_count):
			var center_distance := (float(window_index) + 0.5) * spacing
			var center := Vector3(a.x, 0.0, a.y) + tangent * center_distance + Vector3.UP * center_y
			var half_width := window_width * 0.5
			var half_height := window_height * 0.5
			surface.set_color(glass)
			var offset := normal * 0.035
			_add_quad(surface,
				center - tangent * half_width - Vector3.UP * half_height + offset,
				center + tangent * half_width - Vector3.UP * half_height + offset,
				center + tangent * half_width + Vector3.UP * half_height + offset,
				center - tangent * half_width + Vector3.UP * half_height + offset)
			if floors >= 2 and building_kind in ["apartments", "residential", "house", "commercial", "office"] and (window_index + abs(osm_id)) % 3 == 0 and floor_index > 0:
				_add_facade_balcony(surface, center, tangent, normal, half_width, center_y - half_height - 0.08)
			# Appui discret sous la fenêtre, légèrement avancé sur la façade.
			surface.set_color(Color(0.72, 0.70, 0.64))
			var sill_center := center - Vector3.UP * (half_height + 0.07)
			var sill_offset := normal * 0.045
			_add_quad(surface,
				sill_center - tangent * (half_width + 0.04) + sill_offset,
				sill_center + tangent * (half_width + 0.04) + sill_offset,
				sill_center + tangent * (half_width + 0.04) + Vector3.UP * 0.08 + sill_offset,
				sill_center - tangent * (half_width + 0.04) + Vector3.UP * 0.08 + sill_offset)


func _add_facade_balcony(surface: SurfaceTool, center: Vector3, tangent: Vector3,
		normal: Vector3, half_width: float, floor_y: float) -> void:
	# Balcon stylisé à faible profondeur : dalle, garde-corps et deux montants.
	# Il s'agit d'un détail visuel procédural, pas d'une donnée OSM.
	var depth := 0.72
	var width := half_width + 0.22
	var front := center + normal * depth
	var back_left := center - tangent * width + normal * 0.05
	var back_right := center + tangent * width + normal * 0.05
	var front_left := front - tangent * width
	var front_right := front + tangent * width
	surface.set_color(Color(0.66, 0.64, 0.59))
	_add_quad(surface,
		back_left + Vector3.UP * floor_y,
		back_right + Vector3.UP * floor_y,
		front_right + Vector3.UP * floor_y,
		front_left + Vector3.UP * floor_y)
	var rail_bottom := floor_y + 0.08
	var rail_top := floor_y + 0.92
	surface.set_color(Color(0.28, 0.31, 0.31))
	_add_quad(surface,
		front_left + Vector3.UP * rail_bottom,
		front_right + Vector3.UP * rail_bottom,
		front_right + Vector3.UP * rail_top,
		front_left + Vector3.UP * rail_top)
	_add_quad(surface,
		back_left + Vector3.UP * rail_bottom,
		back_left + Vector3.UP * rail_top,
		front_left + Vector3.UP * rail_top,
		front_left + Vector3.UP * rail_bottom)
	_add_quad(surface,
		back_right + Vector3.UP * rail_bottom,
		front_right + Vector3.UP * rail_bottom,
		front_right + Vector3.UP * rail_top,
		back_right + Vector3.UP * rail_top)

func _add_facade_door(surface: SurfaceTool, a: Vector2, b: Vector2, normal: Vector3) -> void:
	var edge := b - a
	var edge_length := edge.length()
	if edge_length < 2.8:
		return
	var tangent := Vector3(edge.x / edge_length, 0.0, edge.y / edge_length)
	var center := Vector3(a.x, 1.05, a.y) + tangent * (edge_length * 0.5)
	var half_width := 0.46
	var half_height := 1.05
	surface.set_color(Color(0.27, 0.20, 0.15))
	var offset := normal * 0.05
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
