extends Node3D
## Signalisation 3D implantée à partir des intersections OpenStreetMap.
## Les panneaux sont des modèles procéduraux originaux inspirés de la signalisation
## routière francophone : aucune ressource externe de licence incertaine n'est requise.

const ROADS_PATH := "res://data/osm/extended/roads.geojson"
const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG := 111320.0
const SEARCH_RADIUS := 1850.0
const MAX_STOP_SIGNS := 28
const MAX_CROSSING_SIGNS := 18
const MAX_TRAFFIC_LIGHTS := 10

var _world_map: Node3D
var _materials: Dictionary = {}
var _traffic_lights: Array[Dictionary] = []
var _traffic_elapsed := 0.0


func _ready() -> void:
	_world_map = get_parent().get_node_or_null("WorldMap") as Node3D
	for frame in range(600):
		if _world_map != null and bool(_world_map.get("_dem_loaded")):
			break
		await get_tree().process_frame
	_build_signage()


func _process(delta: float) -> void:
	_traffic_elapsed += delta
	var colors: Array[Color] = [
		Color(0.95, 0.035, 0.018),
		Color(1.0, 0.56, 0.025),
		Color(0.04, 0.72, 0.18)
	]
	for signal_data in _traffic_lights:
		var cycle := fposmod(_traffic_elapsed + float(signal_data.offset), 18.0)
		var active_index := 0 if cycle < 6.0 else (2 if cycle < 16.0 else 1)
		var lenses: Array = signal_data.materials
		for lens_index in range(lenses.size()):
			var lens := lenses[lens_index] as StandardMaterial3D
			var active := lens_index == active_index
			lens.albedo_color = colors[lens_index] * (0.72 if active else 0.14)
			lens.emission_enabled = active
			lens.emission = colors[lens_index]
			lens.emission_energy_multiplier = 1.35 if active else 0.0


func is_red_for_vehicle(vehicle_position: Vector3, vehicle_direction: Vector3) -> bool:
	var direction_2d := Vector2(vehicle_direction.x, vehicle_direction.z).normalized()
	if direction_2d.length_squared() < 0.1:
		return false
	for signal_data in _traffic_lights:
		var signal_position: Vector3 = signal_data.get("position", Vector3.ZERO)
		var to_signal := Vector2(signal_position.x - vehicle_position.x, signal_position.z - vehicle_position.z)
		var distance := to_signal.length()
		if distance < 2.0 or distance > 19.0:
			continue
		if direction_2d.dot(to_signal.normalized()) < 0.35:
			continue
		var cycle := fposmod(_traffic_elapsed + float(signal_data.offset), 18.0)
		if cycle < 6.0 or cycle >= 16.0:
			return true
	return false


func _build_signage() -> void:
	if not FileAccess.file_exists(ROADS_PATH):
		push_warning("Signalisation : données routières OSM absentes.")
		return
	var file := FileAccess.open(ROADS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Signalisation : GeoJSON routier invalide.")
		return

	var player := get_parent().get_node_or_null("Player") as Node3D
	var origin := Vector2.ZERO
	if player != null:
		origin = Vector2(player.global_position.x, player.global_position.z)
	var junctions: Dictionary = {}
	var crossing_points: Array[Vector2] = []
	var features: Array = parsed.get("features", [])
	for feature_index in range(features.size()):
		var feature: Dictionary = features[feature_index]
		var props: Dictionary = feature.get("properties", {})
		var geometry: Dictionary = feature.get("geometry", {})
		var kind := str(props.get("highway", ""))
		var geometry_type := str(geometry.get("type", ""))
		if kind == "crossing":
			if geometry_type == "Point":
				var point: Vector2 = _geo_to_world(geometry.get("coordinates", []))
				if point.distance_to(origin) <= SEARCH_RADIUS:
					crossing_points.append(point)
			continue
		if not kind in ["motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified", "service"]:
			continue

		var lines: Array = []
		if geometry_type == "LineString":
			lines.append(geometry.get("coordinates", []))
		elif geometry_type == "MultiLineString":
			lines = geometry.get("coordinates", [])
		else:
			continue

		var way_id := str(props.get("osm_id", props.get("@id", "way_%d" % feature_index)))
		var road_name := str(props.get("name:fr", props.get("name", "")))
		for line in lines:
			if line.size() < 2:
				continue
			for point_index in range(line.size()):
				var coordinate: Array = line[point_index]
				var world_point := _geo_to_world(coordinate)
				if world_point.distance_to(origin) > SEARCH_RADIUS:
					continue
				var key := "%.5f:%.5f" % [float(coordinate[0]), float(coordinate[1])]
				var entry: Dictionary = junctions.get(key, {
					"coordinate": coordinate,
					"ways": {},
					"approaches": []
				})
				var ways: Dictionary = entry.get("ways", {})
				ways[way_id] = true
				entry["ways"] = ways
				var neighbour_index := point_index - 1 if point_index > 0 else point_index + 1
				var neighbour: Array = line[neighbour_index]
				var neighbour_world := _geo_to_world(neighbour)
				var approaches: Array = entry.get("approaches", [])
				if not ways.has(way_id + "_approach"):
					approaches.append({
						"world": neighbour_world,
						"kind": kind,
						"name": road_name
					})
					ways[way_id + "_approach"] = true
				entry["approaches"] = approaches
				junctions[key] = entry
		if feature_index % 120 == 0:
			await get_tree().process_frame

	var stop_count := 0
	var traffic_light_count := 0
	for key in junctions:
		if stop_count >= MAX_STOP_SIGNS:
			break
		var entry: Dictionary = junctions[key]
		var ways: Dictionary = entry.get("ways", {})
		var way_count := 0
		for way_id in ways:
			if not str(way_id).ends_with("_approach"):
				way_count += 1
		if way_count < 3:
			continue
		var approaches: Array = entry.get("approaches", [])
		if approaches.is_empty():
			continue
		var intersection: Vector2 = _geo_to_world(entry.coordinate)
		var selected: Dictionary = approaches[0]
		var selected_score := 99
		for approach in approaches:
			var score := _road_priority(str(approach.kind))
			if score < selected_score:
				selected = approach
				selected_score = score
		var direction: Vector2 = (selected.world - intersection).normalized()
		if direction.length_squared() < 0.1:
			continue
		var side := Vector2(-direction.y, direction.x)
		var sign_position := intersection + direction * 6.5 + side * 3.0
		var terrain_y := _terrain_height(sign_position)
		if way_count >= 4 and selected_score >= 2 and traffic_light_count < MAX_TRAFFIC_LIGHTS:
			_add_traffic_light(intersection + direction * 5.0 + side * 4.0, terrain_y, direction)
			traffic_light_count += 1
		else:
			_add_stop_sign(sign_position, terrain_y, direction, str(selected.name))
			stop_count += 1

	var crossing_count := 0
	for point in crossing_points:
		if crossing_count >= MAX_CROSSING_SIGNS:
			break
		var direction := Vector2.RIGHT if crossing_count % 2 == 0 else Vector2.LEFT
		_add_pedestrian_sign(point + direction * 3.0, _terrain_height(point), direction)
		crossing_count += 1

	print("LIBREVILLE STORIES | signalisation : %d STOP, %d feux tricolores, %d panneaux piétons issus des données OSM" % [stop_count, traffic_light_count, crossing_count])


func _road_priority(kind: String) -> int:
	match kind:
		"service", "residential", "unclassified":
			return 0
		"tertiary":
			return 1
		"secondary":
			return 2
		"primary":
			return 3
		"trunk":
			return 4
	return 5


func _geo_to_world(coordinate: Array) -> Vector2:
	if coordinate.size() < 2:
		return Vector2.ZERO
	var longitude := float(coordinate[0])
	var latitude := float(coordinate[1])
	var x := (longitude - CENTER_LON) * METERS_PER_DEG * cos(deg_to_rad(CENTER_LAT))
	var z := (CENTER_LAT - latitude) * METERS_PER_DEG
	return Vector2(x, z)


func _terrain_height(point: Vector2) -> float:
	if _world_map != null and _world_map.has_method("terrain_height_at_world"):
		return float(_world_map.call("terrain_height_at_world", point.x, point.y))
	return 0.0


func _material(key: String, color: Color, metallic: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	_materials[key] = material
	return material


func _add_stop_sign(point: Vector2, ground_y: float, direction: Vector2, street_name: String) -> void:
	var root := Node3D.new()
	root.name = "Panneau_STOP_%02d" % get_child_count()
	root.position = Vector3(point.x, ground_y, point.y)
	root.rotation.y = atan2(direction.x, direction.y)
	add_child(root)

	var pole := MeshInstance3D.new()
	pole.name = "Poteau_galvanise"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.035
	pole_mesh.bottom_radius = 0.055
	pole_mesh.height = 2.85
	pole.mesh = pole_mesh
	pole.position.y = 1.42
	pole.material_override = _material("galvanised", Color(0.48, 0.53, 0.55), 0.68, 0.38)
	root.add_child(pole)

	var border := MeshInstance3D.new()
	border.name = "Contour_blanc_octogonal"
	var border_mesh := CylinderMesh.new()
	border_mesh.top_radius = 0.61
	border_mesh.bottom_radius = 0.61
	border_mesh.height = 0.075
	border_mesh.radial_segments = 8
	border.mesh = border_mesh
	border.rotation.x = PI * 0.5
	border.position.y = 2.43
	border.material_override = _material("sign_white", Color(0.96, 0.96, 0.92), 0.0, 0.62)
	root.add_child(border)

	var face := MeshInstance3D.new()
	face.name = "Face_rouge_STOP"
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 0.54
	face_mesh.bottom_radius = 0.54
	face_mesh.height = 0.082
	face_mesh.radial_segments = 8
	face.mesh = face_mesh
	face.rotation.x = PI * 0.5
	face.position = Vector3(0, 2.43, 0.055)
	face.material_override = _material("sign_red", Color(0.76, 0.035, 0.025), 0.0, 0.52)
	root.add_child(face)

	var label := Label3D.new()
	label.name = "Texte_STOP"
	label.text = "STOP"
	label.font_size = 68
	label.pixel_size = 0.008
	label.position = Vector3(0, 2.43, 0.105)
	label.modulate = Color.WHITE
	label.outline_size = 5
	label.outline_modulate = Color(0.36, 0.015, 0.01)
	root.add_child(label)

	if not street_name.strip_edges().is_empty():
		var plate_width := clampf(float(mini(street_name.length(), 24)) * 0.105, 1.5, 2.7)
		var plate := MeshInstance3D.new()
		plate.name = "Plaque_nom_rue"
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(plate_width, 0.34, 0.07)
		plate.mesh = plate_mesh
		plate.position = Vector3(0, 3.05, 0.015)
		plate.material_override = _material("street_blue", Color(0.035, 0.20, 0.39), 0.0, 0.68)
		root.add_child(plate)
		var street_label := Label3D.new()
		street_label.text = street_name.substr(0, 24).to_upper()
		street_label.font_size = 25
		street_label.pixel_size = 0.005
		street_label.position = Vector3(0, 3.05, 0.065)
		street_label.modulate = Color.WHITE
		street_label.outline_size = 3
		street_label.outline_modulate = Color(0.02, 0.08, 0.16)
		root.add_child(street_label)


func _add_traffic_light(point: Vector2, ground_y: float, direction: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Feu_tricolore_%02d" % get_child_count()
	root.position = Vector3(point.x, ground_y, point.y)
	root.rotation.y = atan2(direction.x, direction.y)
	add_child(root)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 3.75
	pole.mesh = pole_mesh
	pole.position.y = 1.87
	pole.material_override = _material("traffic_pole", Color(0.18, 0.20, 0.21), 0.58, 0.42)
	root.add_child(pole)

	var housing := MeshInstance3D.new()
	housing.name = "Boitier_feu"
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(0.42, 1.16, 0.30)
	housing.mesh = housing_mesh
	housing.position = Vector3(0, 3.05, 0.02)
	housing.material_override = _material("traffic_housing", Color(0.055, 0.065, 0.07), 0.22, 0.58)
	root.add_child(housing)

	var light_colors: Array[Color] = [
		Color(0.95, 0.035, 0.018),
		Color(1.0, 0.56, 0.025),
		Color(0.04, 0.72, 0.18)
	]
	var signal_materials: Array[StandardMaterial3D] = []
	for light_index in range(3):
		var lamp := MeshInstance3D.new()
		lamp.name = ["Feu_rouge", "Feu_orange", "Feu_vert"][light_index]
		var sphere := SphereMesh.new()
		sphere.radius = 0.115
		sphere.height = 0.23
		sphere.radial_segments = 12
		sphere.rings = 6
		lamp.mesh = sphere
		lamp.position = Vector3(0, 3.42 - float(light_index) * 0.37, 0.19)
		var lens := StandardMaterial3D.new()
		lens.albedo_color = light_colors[light_index] * 0.52
		lens.emission_enabled = false
		lens.emission = light_colors[light_index]
		lens.emission_energy_multiplier = 0.0
		lens.roughness = 0.25
		lamp.material_override = lens
		root.add_child(lamp)
		signal_materials.append(lens)
	_traffic_lights.append({
		"materials": signal_materials,
		"offset": float(get_child_count()) * 2.7,
		"position": Vector3(point.x, ground_y, point.y),
		"direction": Vector3(direction.x, 0.0, direction.y)
	})


func _add_pedestrian_sign(point: Vector2, ground_y: float, direction: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Panneau_Pietons_%02d" % get_child_count()
	root.position = Vector3(point.x, ground_y, point.y)
	root.rotation.y = atan2(direction.x, direction.y)
	add_child(root)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.035
	pole_mesh.bottom_radius = 0.045
	pole_mesh.height = 2.45
	pole.mesh = pole_mesh
	pole.position.y = 1.22
	pole.material_override = _material("galvanised", Color(0.48, 0.53, 0.55), 0.68, 0.38)
	root.add_child(pole)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.78, 0.78, 0.08)
	board.mesh = board_mesh
	board.position.y = 2.15
	board.material_override = _material("pedestrian_blue", Color(0.025, 0.22, 0.56), 0.0, 0.62)
	root.add_child(board)
	var label := Label3D.new()
	label.text = "PIÉTONS"
	label.font_size = 25
	label.pixel_size = 0.005
	label.position = Vector3(0, 2.15, 0.055)
	label.modulate = Color.WHITE
	label.outline_size = 3
	label.outline_modulate = Color(0.02, 0.08, 0.16)
	root.add_child(label)
