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
var _environment_material: StandardMaterial3D
var _road_labels := 0
var _road_material: StandardMaterial3D
var _building_material: StandardMaterial3D

func _ready() -> void:
	_road_material = _make_material(Color(0.16, 0.17, 0.18))
	_environment_material = _make_material(Color.WHITE)
	_environment_material.vertex_color_use_as_albedo = true
	_load_environment()
	_building_material = _make_material(Color(0.76, 0.68, 0.56))
	# Les couleurs attribuées aux bâtiments par type/OSM ID doivent être visibles.
	_building_material.vertex_color_use_as_albedo = true
	if show_roads:
		_load_roads()
	if show_buildings:
		_load_buildings()
	_load_pois()
	print("LIBREVILLE STORIES | routes: %d | bâtiments: %d | lieux identifiables: %d | éléments environnementaux: %d" % [_road_count, _building_count, _poi_count, _environment_count])

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
				surface.add_vertex(Vector3(p0.x, -0.035, p0.y))
				surface.add_vertex(Vector3(p1.x, -0.035, p1.y))
				surface.add_vertex(Vector3(p2.x, -0.035, p2.y))
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
				_add_quad(surface, a + side + Vector3.UP * -0.025, a - side + Vector3.UP * -0.025, b - side + Vector3.UP * -0.025, b + side + Vector3.UP * -0.025)
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


func _load_roads() -> void:
	var data := _read_geojson("res://data/osm/roads.geojson")
	if data.is_empty():
		push_warning("roads.geojson absent : carte routière non chargée.")
		return
	var surface := _new_surface(_road_material)
	var batch_count := 0
	var batch_index := 0
	for feature in data.get("features", []):
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
		var width := _road_width(str(props.get("highway", "residential")))
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

func _load_buildings() -> void:
	var data := _read_geojson("res://data/osm/buildings.geojson")
	if data.is_empty():
		push_warning("buildings.geojson absent : bâtiments non chargés.")
		return
	var features: Array = data.get("features", [])
	var limit := mini(features.size(), BUILDING_LIMIT)
	var surface := _new_surface(_building_material)
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
			_add_building(surface, points, indices, height)
			added = true
		if added:
			_building_count += 1
			batch_count += 1
		if batch_count >= BUILDINGS_PER_MESH:
			_commit_surface(surface, "OSM_Buildings_%03d" % batch_index)
			batch_index += 1
			batch_count = 0
			surface = _new_surface(_building_material)
	if batch_count > 0:
		_commit_surface(surface, "OSM_Buildings_%03d" % batch_index)


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
		if place_name.is_empty():
			continue
		var coordinates: Array = geometry.get("coordinates", [])
		if coordinates.size() < 2:
			continue
		var kind := str(props.get("amenity", props.get("shop", props.get("tourism", props.get("healthcare", props.get("building", "place"))))))
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
	var kind := str(props.get("amenity", props.get("healthcare", props.get("shop", props.get("tourism", props.get("place", ""))))))
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

func _add_building(surface: SurfaceTool, points: PackedVector2Array, indices: PackedInt32Array, height: float) -> void:
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		_add_quad(surface, Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(b.x, height, b.y), Vector3(a.x, height, a.y))
	for i in range(0, indices.size(), 3):
		var p0 := points[indices[i]]
		var p1 := points[indices[i + 1]]
		var p2 := points[indices[i + 2]]
		surface.add_vertex(Vector3(p0.x, height, p0.y))
		surface.add_vertex(Vector3(p1.x, height, p1.y))
		surface.add_vertex(Vector3(p2.x, height, p2.y))

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)
