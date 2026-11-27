extends Node3D
## Trafic routier léger sur les axes OSM de l'emprise jouable de Libreville.
## Les véhicules procéduraux sont des proxies temporaires en attendant l'import des GLB.

const ROADS_PATH := "res://data/osm/roads.geojson"
const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG := 111320.0
const PLAYABLE_SOUTH := 0.355
const PLAYABLE_NORTH := 0.445
const PLAYABLE_WEST := 9.400
const PLAYABLE_EAST := 9.495
const PLAYABLE_RADIUS := 1450.0
const MIN_ROUTE_LENGTH := 65.0
const MIN_SEGMENT_LENGTH := 18.0
const LANE_OFFSET := 1.35
const VEHICLE_LENGTH := 4.1
const WHEEL_RADIUS := 0.34

@export_range(0, 40, 1) var max_vehicles := 12
@export_range(2.0, 18.0, 0.5) var traffic_speed_min := 6.0
@export_range(2.0, 18.0, 0.5) var traffic_speed_max := 11.5
@export var enable_traffic_lights := true

var _world_map: Node3D
var _traffic_signs: Node
var _rng := RandomNumberGenerator.new()
var _routes: Array[Dictionary] = []
var _agents: Array[Dictionary] = []
var _paint_materials: Array[StandardMaterial3D] = []
var _glass_material: StandardMaterial3D
var _tyre_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _elapsed := 0.0


func _ready() -> void:
	_rng.randomize()
	_world_map = get_parent().get_node_or_null("WorldMap") as Node3D
	_traffic_signs = get_parent().get_node_or_null("TrafficSigns")
	# Le relief et les collisions routières sont construits de façon asynchrone.
	for frame_index in range(900):
		if _world_map != null and bool(_world_map.get("_dem_loaded")):
			break
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_load_road_routes()
	_prepare_materials()
	_spawn_traffic()
	print("LIBREVILLE STORIES | trafic : %d véhicules actifs sur %d tronçons OSM jouables" % [_agents.size(), _routes.size()])


func _process(delta: float) -> void:
	_elapsed += delta
	for agent_index in range(_agents.size()):
		_update_agent(agent_index, delta)


func _load_road_routes() -> void:
	_routes.clear()
	if not FileAccess.file_exists(ROADS_PATH):
		push_warning("Trafic : roads.geojson absent, aucun véhicule ne sera généré.")
		return
	var file := FileAccess.open(ROADS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Trafic : impossible d'ouvrir roads.geojson.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Trafic : GeoJSON routier invalide.")
		return

	var player := get_parent().get_node_or_null("Player") as Node3D
	var origin := Vector2.ZERO
	if player != null:
		origin = Vector2(player.global_position.x, player.global_position.z)
	var features: Array = parsed.get("features", [])
	for feature_index in range(features.size()):
		var feature: Dictionary = features[feature_index]
		var properties: Dictionary = feature.get("properties", {})
		var kind := str(properties.get("highway", ""))
		if not kind in ["primary", "secondary", "tertiary", "residential", "unclassified", "service"]:
			continue
		# Les voies piétonnes, pistes et ouvrages non vérifiés ne reçoivent pas de trafic.
		if str(properties.get("bridge", "no")) not in ["", "no"] or str(properties.get("tunnel", "no")) not in ["", "no"]:
			continue
		if str(properties.get("access", "")).to_lower() in ["no", "private"] or str(properties.get("motor_vehicle", "")).to_lower() in ["no", "private"]:
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
		for line in lines:
			if line.size() < 2:
				continue
			var current_points: Array[Vector3] = []
			for coordinate in line:
				if not _coordinate_inside_playable(coordinate):
					if current_points.size() >= 2:
						_add_route_if_valid(current_points, origin)
					current_points = []
					continue
				var world_point := _geo_to_world(coordinate)
				if Vector2(world_point.x - origin.x, world_point.z - origin.y).length() > PLAYABLE_RADIUS:
					if current_points.size() >= 2:
						_add_route_if_valid(current_points, origin)
					current_points = []
					continue
				if current_points.is_empty() or Vector2(world_point.x - current_points[-1].x, world_point.z - current_points[-1].z).length() > 0.8:
					current_points.append(world_point)
			if current_points.size() >= 2:
				_add_route_if_valid(current_points, origin)
		if feature_index % 180 == 0:
			await get_tree().process_frame


func _coordinate_inside_playable(coordinate: Array) -> bool:
	if coordinate.size() < 2:
		return false
	var lon := float(coordinate[0])
	var lat := float(coordinate[1])
	return lon >= PLAYABLE_WEST and lon <= PLAYABLE_EAST and lat >= PLAYABLE_SOUTH and lat <= PLAYABLE_NORTH


func _geo_to_world(coordinate: Array) -> Vector3:
	var lon := float(coordinate[0])
	var lat := float(coordinate[1])
	var x := (lon - CENTER_LON) * METERS_PER_DEG * cos(deg_to_rad(CENTER_LAT))
	var z := (CENTER_LAT - lat) * METERS_PER_DEG
	var ground_y := 0.0
	if _world_map != null and _world_map.has_method("terrain_height_at_world"):
		ground_y = float(_world_map.call("terrain_height_at_world", x, z))
	return Vector3(x, ground_y, z)


func _add_route_if_valid(points: Array[Vector3], origin: Vector2) -> void:
	if points.size() < 2:
		return
	var clean_points: Array[Vector3] = []
	var total_length := 0.0
	for point_index in range(points.size()):
		var point := points[point_index]
		if not clean_points.is_empty():
			var segment_length := Vector2(point.x - clean_points[-1].x, point.z - clean_points[-1].z).length()
			if segment_length < MIN_SEGMENT_LENGTH:
				continue
			total_length += segment_length
		clean_points.append(point)
	if clean_points.size() < 2 or total_length < MIN_ROUTE_LENGTH:
		return
	var center := Vector2.ZERO
	for point in clean_points:
		center += Vector2(point.x, point.z)
	center /= float(clean_points.size())
	if center.distance_to(origin) > PLAYABLE_RADIUS:
		return
	_routes.append({"points": clean_points, "length": total_length})


func _prepare_materials() -> void:
	_glass_material = StandardMaterial3D.new()
	_glass_material.albedo_color = Color(0.045, 0.075, 0.09, 1.0)
	_glass_material.roughness = 0.22
	_glass_material.metallic = 0.18
	_tyre_material = StandardMaterial3D.new()
	_tyre_material.albedo_color = Color(0.025, 0.028, 0.03)
	_tyre_material.roughness = 0.92
	_trim_material = StandardMaterial3D.new()
	_trim_material.albedo_color = Color(0.12, 0.13, 0.14)
	_trim_material.metallic = 0.45
	_trim_material.roughness = 0.42
	for color in [
		Color(0.78, 0.80, 0.82), Color(0.12, 0.18, 0.24),
		Color(0.62, 0.08, 0.055), Color(0.12, 0.30, 0.18),
		Color(0.72, 0.62, 0.28), Color(0.18, 0.20, 0.22),
		Color(0.78, 0.76, 0.68)
	]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.58
		material.metallic = 0.12
		_paint_materials.append(material)


func _spawn_traffic() -> void:
	if _routes.is_empty() or max_vehicles <= 0:
		push_warning("Trafic : aucun axe routier admissible dans le rayon de la zone jouable.")
		return
	var route_indices: Array[int] = []
	for route_index in range(_routes.size()):
		route_indices.append(route_index)
	route_indices.shuffle()
	var spawned := 0
	for route_index in route_indices:
		if spawned >= max_vehicles:
			break
		var route: Dictionary = _routes[route_index]
		var points: Array[Vector3] = route.points
		if points.size() < 2:
			continue
		var direction := -1 if _rng.randf() < 0.5 else 1
		var segment_index := _rng.randi_range(0, points.size() - 2)
		if direction < 0:
			segment_index += 1
		var segment_end_index := segment_index + direction
		var segment_length := Vector2(
			points[segment_end_index].x - points[segment_index].x,
			points[segment_end_index].z - points[segment_index].z
		).length()
		if segment_length < MIN_SEGMENT_LENGTH:
			continue
		var vehicle := _build_vehicle(spawned)
		add_child(vehicle.root)
		_agents.append({
			"root": vehicle.root,
			"wheels": vehicle.wheels,
			"route_index": route_index,
			"point_index": segment_index,
			"direction": direction,
			"progress": _rng.randf_range(0.0, segment_length * 0.75),
			"speed": _rng.randf_range(traffic_speed_min, traffic_speed_max),
			"current_speed": 0.0,
			"lane": LANE_OFFSET if direction > 0 else -LANE_OFFSET,
			"paint_index": vehicle.paint_index
		})
		spawned += 1


func _build_vehicle(vehicle_index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "TrafficVehicle_%02d" % vehicle_index
	var taxi := _rng.randf() < 0.32
	var paint_index := _rng.randi_range(0, _paint_materials.size() - 1)
	var paint := _paint_materials[paint_index]
	var taxi_color := Color.WHITE
	if taxi:
		# Les trois livrées locales : Libreville rouge, Akanda vert, Owendo bleu.
		var taxi_choice := _rng.randi_range(0, 2)
		taxi_color = [Color(0.78, 0.07, 0.045), Color(0.08, 0.38, 0.18), Color(0.06, 0.22, 0.58)][taxi_choice]
		paint = StandardMaterial3D.new()
		paint.albedo_color = Color(0.88, 0.88, 0.84)
		paint.roughness = 0.58
		_paint_materials.append(paint)
		paint_index = _paint_materials.size() - 1

	var body := MeshInstance3D.new()
	body.name = "Carrosserie"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.82, 0.66, 4.1)
	body.mesh = body_mesh
	body.position.y = 0.72
	body.material_override = paint
	root.add_child(body)

	var cabin := MeshInstance3D.new()
	cabin.name = "Habitacle_vitres"
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.48, 0.68, 2.05)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.34, -0.12)
	cabin.material_override = _glass_material
	root.add_child(cabin)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.50, 0.10, 1.82)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 1.72, -0.12)
	roof.material_override = paint
	root.add_child(roof)

	if taxi:
		for side in [-1.0, 1.0]:
			var stripe := MeshInstance3D.new()
			var stripe_mesh := BoxMesh.new()
			stripe_mesh.size = Vector3(0.035, 0.15, 2.25)
			stripe.mesh = stripe_mesh
			stripe.position = Vector3(side * 0.925, 0.77, -0.08)
			stripe.material_override = _make_material(taxi_color)
			root.add_child(stripe)
		var roof_sign := MeshInstance3D.new()
		var sign_mesh := BoxMesh.new()
		sign_mesh.size = Vector3(0.48, 0.16, 0.30)
		roof_sign.mesh = sign_mesh
		roof_sign.position = Vector3(0, 1.85, 0.0)
		roof_sign.material_override = _make_material(Color(0.94, 0.90, 0.72))
		root.add_child(roof_sign)

	var wheels: Array[MeshInstance3D] = []
	for side in [-1.0, 1.0]:
		for axle_z in [-1.28, 1.28]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%s" % ["L" if side < 0 else "R", "F" if axle_z > 0 else "R"]
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = WHEEL_RADIUS
			wheel_mesh.bottom_radius = WHEEL_RADIUS
			wheel_mesh.height = 0.22
			wheel_mesh.radial_segments = 12
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(side * 0.91, 0.36, axle_z)
			wheel.material_override = _tyre_material
			root.add_child(wheel)
			wheels.append(wheel)

	var front_lights := _make_light_bar(Color(0.94, 0.91, 0.78))
	front_lights.position = Vector3(0, 0.77, 2.06)
	root.add_child(front_lights)
	var rear_lights := _make_light_bar(Color(0.62, 0.035, 0.025))
	rear_lights.position = Vector3(0, 0.77, -2.06)
	root.add_child(rear_lights)
	return {"root": root, "wheels": wheels, "paint_index": paint_index}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.64
	return material


func _make_light_bar(color: Color) -> MeshInstance3D:
	var light := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.30, 0.10, 0.035)
	light.mesh = mesh
	light.material_override = _make_material(color)
	return light


func _update_agent(agent_index: int, delta: float) -> void:
	var agent: Dictionary = _agents[agent_index]
	var route: Dictionary = _routes[int(agent.route_index)]
	var points: Array[Vector3] = route.points
	var point_index := int(agent.point_index)
	var direction := int(agent.direction)
	if point_index < 0 or point_index >= points.size():
		return
	var next_index := point_index + direction
	if next_index < 0 or next_index >= points.size():
		direction *= -1
		next_index = point_index + direction
		if next_index < 0 or next_index >= points.size():
			return
		agent.direction = direction
	var start := points[point_index]
	var finish := points[next_index]
	var segment_length := Vector2(finish.x - start.x, finish.z - start.z).length()
	if segment_length < 0.05:
		return

	var target_speed := float(agent.speed)
	var forward := Vector3(finish.x - start.x, 0.0, finish.z - start.z).normalized()
	var root := agent.root as Node3D
	if enable_traffic_lights and _traffic_signs != null and _traffic_signs.has_method("is_red_for_vehicle"):
		if bool(_traffic_signs.call("is_red_for_vehicle", root.global_position, forward)):
			target_speed = 0.0
	var current_speed := move_toward(float(agent.current_speed), target_speed, 4.5 * delta)
	var progress := float(agent.progress) + current_speed * delta
	var guard := 0
	while progress >= segment_length and guard < 8:
		progress -= segment_length
		point_index = next_index
		next_index = point_index + direction
		if next_index < 0 or next_index >= points.size():
			direction *= -1
			next_index = point_index + direction
			if next_index < 0 or next_index >= points.size():
				break
			agent.direction = direction
		start = points[point_index]
		finish = points[next_index]
		segment_length = Vector2(finish.x - start.x, finish.z - start.z).length()
		guard += 1
	var t := clampf(progress / maxf(segment_length, 0.01), 0.0, 1.0)
	var road_position := start.lerp(finish, t)
	forward = Vector3(finish.x - start.x, 0.0, finish.z - start.z).normalized()
	var right := Vector2(forward.z, -forward.x)
	var lane := LANE_OFFSET if direction > 0 else -LANE_OFFSET
	var world_x := road_position.x + right.x * lane
	var world_z := road_position.z + right.y * lane
	var ground_y := road_position.y
	if _world_map != null and _world_map.has_method("terrain_height_at_world"):
		ground_y = float(_world_map.call("terrain_height_at_world", world_x, world_z))
	root.global_position = Vector3(world_x, ground_y + 0.08, world_z)
	root.rotation.y = atan2(forward.x, forward.z)
	for wheel in agent.wheels:
		(wheel as MeshInstance3D).rotation.x += current_speed * delta / WHEEL_RADIUS
	agent.point_index = point_index
	agent.progress = progress
	agent.direction = direction
	agent.current_speed = current_speed
	_agents[agent_index] = agent
