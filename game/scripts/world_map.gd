extends Node3D
## Construit une ville 3D légère à partir des GeoJSON OpenStreetMap.
## Projection locale en mètres autour du centre de la zone extraite.
## Les données sont chargées au lancement ; les meshes sont regroupés pour limiter les draw calls.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const BUILDING_LIMIT := 60000

@export var show_roads := true
@export var show_buildings := true

var _road_surface: SurfaceTool
var _building_surface: SurfaceTool
var _road_count := 0
var _building_count := 0

func _ready() -> void:
	_build_road_material()
	_build_building_material()
	if show_roads:
		_load_roads()
	if show_buildings:
		_load_buildings()
	print("LIBREVILLE STORIES | routes: %d | bâtiments: %d" % [_road_count, _building_count])

func _build_road_material() -> void:
	_road_surface = SurfaceTool.new()
	_road_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_road_surface.set_material(_make_material(Color(0.16, 0.17, 0.18), 0.0))

func _build_building_material() -> void:
	_building_surface = SurfaceTool.new()
	_building_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_building_surface.set_material(_make_material(Color(0.72, 0.66, 0.54), 0.0))

func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95 if roughness == 0.0 else roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED\n\tmaterial.vertex_color_use_as_albedo = true
	return material

func _load_roads() -> void:
	var data := _read_geojson("res://data/osm/roads.geojson")
	if data.is_empty():
		push_warning("roads.geojson absent : carte routière non chargée.")
		return
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		if geometry.get("type") != "LineString":
			continue
		var coords: Array = geometry.get("coordinates", [])
		if coords.size() < 2:
			continue
		var props: Dictionary = feature.get("properties", {})
		var width := _road_width(str(props.get("highway", "residential")))
		for i in range(coords.size() - 1):
			var a := _geo_to_world(coords[i])
			var b := _geo_to_world(coords[i + 1])
			var direction := Vector2(b.x - a.x, b.z - a.z)
			if direction.length_squared() < 0.01:
				continue
			var side := Vector3(-direction.normalized().y, 0.0, direction.normalized().x) * width * 0.5
			_add_quad(_road_surface, a + side + Vector3.UP * 0.025, a - side + Vector3.UP * 0.025, b - side + Vector3.UP * 0.025, b + side + Vector3.UP * 0.025)
		_road_count += 1
	_road_surface.generate_normals()
	var mesh := _road_surface.commit()
	if mesh != null:
		var instance := MeshInstance3D.new()
		instance.name = "OSM_Road_Network"
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

func _load_buildings() -> void:
	var data := _read_geojson("res://data/osm/buildings.geojson")
	if data.is_empty():
		push_warning("buildings.geojson absent : bâtiments non chargés.")
		return
	var features: Array = data.get("features", [])
	var count := mini(features.size(), BUILDING_LIMIT)
	for index in range(count):
		var feature: Dictionary = features[index]
		var geometry: Dictionary = feature.get("geometry", {})
		if geometry.get("type") != "Polygon":
			continue
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
		var props: Dictionary = feature.get("properties", {})
		var kind := str(props.get("building", "yes"))
		var osm_id := int(props.get("osm_id", index))
		var height := _building_height(kind, osm_id)
		_add_building(points, indices, height)
		_building_count += 1
	_building_surface.generate_normals()
	var mesh := _building_surface.commit()
	if mesh != null:
		var instance := MeshInstance3D.new()
		instance.name = "OSM_Building_Block"
		instance.mesh = mesh
		add_child(instance)

func _read_geojson(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

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
	# Utilise les mesures OSM lorsqu'elles existent, puis les niveaux déclarés.
	var tagged_height := str(props.get("height", "")).to_float()
	if tagged_height >= 2.5 and tagged_height <= 150.0:
		return tagged_height
	var levels := str(props.get("building:levels", "")).to_int()
	if levels > 0 and levels <= 40:
		return clampf(float(levels) * 3.1, 3.0, 120.0)
	# Hauteur visuelle de secours : estimation, jamais une mesure réelle.
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

func _add_building(points: PackedVector2Array, indices: PackedInt32Array, height: float) -> void:
	var n := points.size()
	for i in range(n):
		var a := points[i]
		var b := points[(i + 1) % n]
		var a0 := Vector3(a.x, 0.0, a.y)
		var b0 := Vector3(b.x, 0.0, b.y)
		var a1 := Vector3(a.x, height, a.y)
		var b1 := Vector3(b.x, height, b.y)
		_add_quad(_building_surface, a0, b0, b1, a1)
	for i in range(0, indices.size(), 3):
		var p0 := points[indices[i]]
		var p1 := points[indices[i + 1]]
		var p2 := points[indices[i + 2]]
		_building_surface.add_vertex(Vector3(p0.x, height, p0.y))
		_building_surface.add_vertex(Vector3(p1.x, height, p1.y))
		_building_surface.add_vertex(Vector3(p2.x, height, p2.y))

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)
