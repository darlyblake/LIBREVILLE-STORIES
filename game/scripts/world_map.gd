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
			var width := 2.0 if kind == "waterway" else 1.2
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


func _environment_color(kind: String) -> Color:
	match kind:
		"water", "waterway", "coastline":
			return Color(0.20, 0.48, 0.66)
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
				_add_map_label(str(props.get("name")), _geo_to_world(midpoint) + Vector3.UP * 3.0, Color(0.92, 0.95, 1.0), 280.0)
				_road_labels += 1
		var road_kind := str(props.get("highway", "residential"))
		var width := _road_width(road_kind)
		surface.set_color(_road_color(road_kind))
		var added := false
		for coords in lines:
			if coords.size() < 2:
				continue
			for i in range(coords.size() - 1):
				var a := _geo_to_world(coords[i])
				var b := _geo_to_world(coords[i + 1])
				var direction := Vector2(b.x - a.x, b.z - a.z)
				if direction.length_squared() < 0.01:
					continue
				var side := Vector3(-direction.normalized().y, 0.0, direction.normalized().x) * width * 0.5
				_add_quad(surface, a + side + Vector3.UP * 0.025, a - side + Vector3.UP * 0.025, b - side + Vector3.UP * 0.025, b + side + Vector3.UP * 0.025)
				added = true
		if added:
			_road_count += 1
			batch_count += 1
		if batch_count >= ROADS_PER_MESH:
			_commit_surface(surface, "OSM_Roads_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(_road_material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Roads_%03d" % batch_index)

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
			surface.set_color(_building_color(building_kind, osm_id))
			_add_building(surface, roof_surface, detail_surface, points, indices, height, _roof_color(building_kind, osm_id), building_kind, osm_id)
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
		_add_map_label(label_text, world_position + Vector3.UP * 5.5, Color(1.0, 0.84, 0.48), 900.0)
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
		_add_map_label(place_name, _geo_to_world(coordinates) + Vector3.UP * 4.0, _poi_color(kind), 500.0)
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
	label.font_size = 32
	label.pixel_size = 0.01
	label.modulate = label_color
	label.outline_size = 8
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

func _road_color(kind: String) -> Color:
	# Hiérarchie visuelle lisible : axes structurants plus clairs, rues locales sobres.
	match kind:
		"motorway", "trunk":
			return Color(0.88, 0.62, 0.34)
		"primary":
			return Color(0.82, 0.69, 0.48)
		"secondary":
			return Color(0.70, 0.68, 0.60)
		"tertiary":
			return Color(0.56, 0.58, 0.57)
		"residential", "unclassified":
			return Color(0.39, 0.42, 0.43)
		"service":
			return Color(0.32, 0.35, 0.36)
		"footway", "path", "steps", "cycleway":
			return Color(0.48, 0.43, 0.34)
		_:
			return Color(0.43, 0.45, 0.45)

func _road_width(kind: String) -> float:
	match kind:
		"motorway", "trunk": return 13.0
		"primary": return 10.0
		"secondary": return 8.0
		"tertiary": return 6.5
		"residential", "unclassified": return 5.5
		"service": return 3.2
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

func _building_color(kind: String, osm_id: int) -> Color:
	var variation := float(abs(osm_id) % 8) * 0.008
	match kind:
		"commercial", "retail", "supermarket", "office":
			return Color(0.70 + variation, 0.66 + variation, 0.58 + variation)
		"industrial", "warehouse":
			return Color(0.57 + variation, 0.59 + variation, 0.57 + variation)
		"cathedral", "church", "chapel", "mosque":
			return Color(0.78 + variation, 0.73 + variation, 0.63 + variation)
		_:
			return Color(0.76 + variation, 0.68 + variation, 0.56 + variation)

func _roof_color(kind: String, osm_id: int) -> Color:
	# Variantes visuelles de toiture : ce ne sont pas des matériaux mesurés sur le terrain.
	var variation := float(abs(osm_id) % 7) * 0.018
	match kind:
		"industrial", "warehouse":
			return Color(0.66 + variation, 0.70 + variation, 0.68 + variation)
		"commercial", "retail", "office":
			return Color(0.58 + variation, 0.59 + variation, 0.56 + variation)
		_:
			return Color(0.78 + variation, 0.48 + variation, 0.34 + variation)


func _make_roof_tile_texture() -> Texture2D:
	# Texture procédurale répétable de petites tuiles, sans image externe à télécharger.
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.48, 0.25, 0.18, 1.0))
	for y in range(128):
		var row := int(y / 16)
		for x in range(128):
			var local_y := y % 16
			var local_x := (x + (16 if row % 2 == 1 else 0)) % 32
			var shade := 0.92 if (local_y == 0 or local_x == 0) else 1.0
			if local_y == 15:
				shade *= 0.72
			image.set_pixel(x, y, Color(0.56 * shade, 0.29 * shade, 0.21 * shade, 1.0))
	return ImageTexture.create_from_image(image)


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
		roof_tint: Color, building_kind: String, osm_id: int) -> void:
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
	for i in range(0, indices.size(), 3):
		var p0 := points[indices[i]]
		var p1 := points[indices[i + 1]]
		var p2 := points[indices[i + 2]]
		_add_uv_triangle(roofs, Vector3(p0.x, height + 0.035, p0.y),
			Vector3(p1.x, height + 0.035, p1.y), Vector3(p2.x, height + 0.035, p2.y))


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
			# Appui discret sous la fenêtre, légèrement avancé sur la façade.
			surface.set_color(Color(0.72, 0.70, 0.64))
			var sill_center := center - Vector3.UP * (half_height + 0.07)
			var sill_offset := normal * 0.045
			_add_quad(surface,
				sill_center - tangent * (half_width + 0.04) + sill_offset,
				sill_center + tangent * (half_width + 0.04) + sill_offset,
				sill_center + tangent * (half_width + 0.04) + Vector3.UP * 0.08 + sill_offset,
				sill_center - tangent * (half_width + 0.04) + Vector3.UP * 0.08 + sill_offset)


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
