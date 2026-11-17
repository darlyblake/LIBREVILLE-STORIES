extends Node3D
## Ville 3D légère depuis les géométries OpenStreetMap.
## Les meshes sont découpés en lots pour limiter les pics mémoire et les draw calls.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const BUILDING_LIMIT := 60000
const BUILDINGS_PER_MESH := 1200
const ROADS_PER_MESH := 700

@export var show_roads := true
@export var show_buildings := true

var _road_count := 0
var _building_count := 0
var _road_material: StandardMaterial3D
var _building_material: StandardMaterial3D

func _ready() -> void:
	_road_material = _make_material(Color(0.16, 0.17, 0.18))
	_building_material = _make_material(Color(0.76, 0.68, 0.56))
	if show_roads:
		_load_roads()
	if show_buildings:
		_load_buildings()
	print("LIBREVILLE STORIES | routes: %d | bâtiments: %d" % [_road_count, _building_count])

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
