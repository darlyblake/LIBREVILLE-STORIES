extends Node3D
## Population légère de Libreville : circulation visuelle et piétons animés.
## Les véhicules sont cinématiques (sans physique) pour préserver les performances.

const ROAD_PATH_A: Array[Vector3] = [
	Vector3(-1980.46, 0.0, -399.26),
	Vector3(-1971.59, 0.0, -413.77),
	Vector3(-1948.99, 0.0, -419.87),
	Vector3(-1931.77, 0.0, -424.52),
	Vector3(-1906.84, 0.0, -428.24),
	Vector3(-1880.79, 0.0, -431.12),
	Vector3(-1853.04, 0.0, -432.66),
	Vector3(-1826.51, 0.0, -432.77),
	Vector3(-1800.30, 0.0, -431.94)
]
const PEDESTRIAN_PATH_A: Array[Vector3] = [
	Vector3(-1931.77, 0.0, -424.52),
	Vector3(-1930.98, 0.0, -410.96),
	Vector3(-1928.93, 0.0, -392.10),
	Vector3(-1904.45, 0.0, -396.46),
	Vector3(-1885.44, 0.0, -399.41),
	Vector3(-1861.82, 0.0, -401.70),
	Vector3(-1846.16, 0.0, -402.28),
	Vector3(-1827.04, 0.0, -401.82)
]
const PEDESTRIAN_PATH_B: Array[Vector3] = [
	Vector3(-1953.45, 0.0, -557.50),
	Vector3(-1954.81, 0.0, -606.84),
	Vector3(-1954.05, 0.0, -634.48),
	Vector3(-1953.45, 0.0, -667.02),
	Vector3(-1951.55, 0.0, -692.76),
	Vector3(-1949.88, 0.0, -712.44),
	Vector3(-1946.96, 0.0, -735.38)
]

var _traffic: Array[Dictionary] = []
var _pedestrians: Array[Dictionary] = []
var _road_materials: Array[StandardMaterial3D] = []
var _skin_materials: Array[StandardMaterial3D] = []
var _clothing_materials: Array[StandardMaterial3D] = []
var _wheel_material: StandardMaterial3D
var _world_map: Node
var _traffic_signs: Node

func _ready() -> void:
	_world_map = get_parent().get_node_or_null("WorldMap")
	_traffic_signs = get_parent().get_node_or_null("TrafficSigns")
	_create_materials()
	_spawn_traffic()
	_spawn_pedestrians()
	print("LIBREVILLE STORIES | circulation : %d véhicules, %d piétons" % [_traffic.size(), _pedestrians.size()])

func _process(delta: float) -> void:
	for actor in _traffic:
		_advance_actor(actor, delta, false)
	for actor in _pedestrians:
		_advance_actor(actor, delta, true)

func _create_materials() -> void:
	for color in [Color(0.72, 0.12, 0.08), Color(0.12, 0.28, 0.62), Color(0.86, 0.78, 0.54), Color(0.12, 0.42, 0.30), Color(0.72, 0.72, 0.70)]:
		_road_materials.append(_material(color, 0.48))
	for color in [Color(0.48, 0.30, 0.20), Color(0.28, 0.18, 0.12), Color(0.72, 0.52, 0.36), Color(0.82, 0.67, 0.52)]:
		_skin_materials.append(_material(color, 0.9))
	for color in [Color(0.10, 0.24, 0.56), Color(0.72, 0.18, 0.12), Color(0.12, 0.38, 0.24), Color(0.82, 0.68, 0.20), Color(0.22, 0.20, 0.22), Color(0.72, 0.72, 0.68)]:
		_clothing_materials.append(_material(color, 0.85))
	_wheel_material = _material(Color(0.035, 0.04, 0.045), 0.95)

func _material(color: Color, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	return material

func _spawn_traffic() -> void:
	var routes := _load_osm_routes(["motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified", "service"], 75.0, 1500.0)
	if routes.is_empty():
		push_warning("Routes OSM absentes dans le secteur : circulation non instanciée.")
		return
	# Répartition volontaire : petits taxis et taxi-bus des trois communes,
	# puis clandos sans livrée municipale.
	for index in range(9):
		var route: Array[Vector3] = routes[index % routes.size()]["points"].duplicate()
		if index % 2 == 1:
			route.reverse()
		var car := _build_car("TrafficCar_%02d" % index, index)
		add_child(car)
		var length := _route_length(route)
		var cruise := 5.4 + float(index % 4) * 0.55
		_traffic.append({"node": car, "route": route, "distance": fposmod(float(index) * 27.0, maxf(length, 1.0)), "speed": cruise, "cruise_speed": cruise, "lane_offset": -1.25, "phase": float(index) * 0.8})


func _build_car(car_name: String, vehicle_index: int) -> Node3D:
	var car := Node3D.new()
	car.name = car_name
	var is_clando := vehicle_index >= 6
	var is_minibus := vehicle_index >= 3 and vehicle_index <= 5
	var commune_color := Color(0.78, 0.055, 0.045) # Libreville : rouge et blanc
	if vehicle_index % 3 == 1:
		commune_color = Color(0.10, 0.43, 0.20) # Akanda : vert et blanc
	elif vehicle_index % 3 == 2:
		commune_color = Color(0.055, 0.22, 0.72) # Owendo : bleu et blanc
	var body_color := Color(0.91, 0.91, 0.87)
	if is_clando:
		var clando_colors := [Color(0.55, 0.57, 0.54), Color(0.66, 0.57, 0.43), Color(0.34, 0.38, 0.40)]
		body_color = clando_colors[(vehicle_index - 6) % clando_colors.size()]
	var paint := _material(body_color, 0.58 if is_clando else 0.42)
	var accent := _material(commune_color if not is_clando else Color(0.25, 0.25, 0.23), 0.62)
	var body_length := 4.9 if is_minibus else 4.0
	var body_width := 1.88 if is_minibus else 1.78
	var cabin_length := 2.85 if is_minibus else 2.05
	var cabin_height := 0.98 if is_minibus else 0.78
	_add_box(car, "Body", Vector3(body_length, 0.82, body_width), Vector3(0.0, 0.82, 0.0), paint)
	_add_box(car, "Cabin", Vector3(cabin_length, cabin_height, 1.62 if is_minibus else 1.55), Vector3(-0.12, 1.62 if is_minibus else 1.55, 0.0), paint)
	if not is_clando:
		# Bande latérale bicolore, visible sur les deux flancs comme livrée communale.
		for side in [-1.0, 1.0]:
			_add_box(car, "CommuneStripe", Vector3(body_length * 0.72, 0.22, 0.035), Vector3(-0.02, 0.78, side * (body_width * 0.5 + 0.02)), accent)
		var taxi_sign_material := _material(Color(0.92, 0.91, 0.83), 0.55)
		var taxi_sign := _add_box(car, "TaxiRoofSign", Vector3(0.66 if is_minibus else 0.54, 0.16, 0.32), Vector3(-0.18, 2.16 if is_minibus else 2.04, 0.0), accent)
		var taxi_label := Label3D.new()
		taxi_label.name = "TaxiLabel"
		taxi_label.text = "TAXI-BUS" if is_minibus else "TAXI"
		taxi_label.font_size = 18 if is_minibus else 22
		taxi_label.pixel_size = 0.004
		taxi_label.position = Vector3(0.0, 0.0, 0.18)
		taxi_label.modulate = Color(1.0, 1.0, 1.0)
		taxi_sign.add_child(taxi_label)
	var glass := _material(Color(0.055, 0.12, 0.16), 0.16)
	_add_box(car, "Windshield", Vector3(0.06, 0.55, 1.42), Vector3(0.88, 1.57, 0.0), glass)
	_add_box(car, "RearWindow", Vector3(0.06, 0.52, 1.38), Vector3(-1.22, 1.57, 0.0), glass)
	# Vitres latérales distinctes ; le taxi-bus reçoit une rangée de fenêtres plus longue.
	var window_positions := [-0.72, 0.30, 1.05] if is_minibus else [-0.55, 0.55]
	for side in [-1.0, 1.0]:
		for window_x in window_positions:
			_add_box(car, "SideWindow", Vector3(0.72 if is_minibus else 0.62, 0.43, 0.035), Vector3(window_x, 1.62 if is_minibus else 1.57, side * 0.82), glass)
		if is_minibus:
			# Trait de porte coulissante caractéristique du taxi-bus.
			var door_line := _material(Color(0.34, 0.35, 0.33), 0.75)
			_add_box(car, "SlidingDoorSeam", Vector3(0.025, 0.68, 0.025), Vector3(-0.12, 0.96, side * 0.96), door_line)
	# Les taxis du quotidien ne sortent pas tous du garage : poussière,
	# peinture ternie, petites rayures et quelques bosses discrètes.
	_add_vehicle_wear(car, vehicle_index, body_length, body_width, is_clando, is_minibus)
	var lamp := _material(Color(1.0, 0.86, 0.56), 0.3)
	var tail := _material(Color(0.72, 0.035, 0.025), 0.35)
	var brake := _material(Color(0.95, 0.025, 0.012), 0.28)
	brake.emission_enabled = true
	brake.emission = Color(1.0, 0.015, 0.005)
	brake.emission_energy_multiplier = 0.0
	for side in [-1.0, 1.0]:
		var indicator := _material(Color(1.0, 0.32, 0.015), 0.32)
		indicator.emission_enabled = true
		indicator.emission = Color(1.0, 0.22, 0.005)
		indicator.emission_energy_multiplier = 0.0
		_add_box(car, "Headlight", Vector3(0.10, 0.20, 0.34), Vector3(body_length * 0.5 + 0.02, 0.82, side * 0.58), lamp)
		_add_box(car, "Taillight", Vector3(0.10, 0.20, 0.34), Vector3(-body_length * 0.5 - 0.02, 0.82, side * 0.58), tail)
		var brake_lamp := _add_box(car, "BrakeLight_%s" % str(side), Vector3(0.09, 0.14, 0.24), Vector3(-body_length * 0.5 - 0.075, 0.82, side * 0.58), brake)
		brake_lamp.set_meta("lamp_material", brake)
		var front_indicator := _add_box(car, "FrontIndicator_%s" % str(side), Vector3(0.08, 0.10, 0.22), Vector3(body_length * 0.5 + 0.075, 0.83, side * 0.72), indicator)
		front_indicator.set_meta("indicator_material", indicator)
		front_indicator.set_meta("indicator_side", side)
		var rear_indicator := _add_box(car, "RearIndicator_%s" % str(side), Vector3(0.08, 0.10, 0.22), Vector3(-body_length * 0.5 - 0.075, 0.83, side * 0.72), indicator)
		rear_indicator.set_meta("indicator_material", indicator)
		rear_indicator.set_meta("indicator_side", side)
		for axle in ([-1.65, 1.65] if is_minibus else [-1.25, 1.25]):
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.38
			mesh.bottom_radius = 0.38
			mesh.height = 0.22
			mesh.radial_segments = 10
			wheel.mesh = mesh
			wheel.material_override = _wheel_material
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(axle, 0.38, side * 0.88)
			car.add_child(wheel)
	return car


func _add_vehicle_wear(car: Node3D, vehicle_index: int, body_length: float, body_width: float, is_clando: bool, is_minibus: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8300 + vehicle_index * 97
	var dusty_material := _material(Color(0.39, 0.34, 0.27), 0.96)
	var scratch_material := _material(Color(0.30, 0.29, 0.26), 0.9)
	var faded_material := _material(Color(0.68, 0.66, 0.59) if not is_clando else Color(0.43, 0.43, 0.40), 0.88)
	var wear_level := 0.38 + float(vehicle_index % 4) * 0.16
	if is_clando:
		wear_level = 0.72
	# Bande de poussière et de boue légère au bas des portières.
	for side in [-1.0, 1.0]:
		var dirt := _add_box(car, "RoadDust", Vector3(body_length * 0.70, 0.10 + wear_level * 0.06, 0.025), Vector3(0.0, 0.48, side * (body_width * 0.5 + 0.025)), dusty_material)
		dirt.rotation.x = rng.randf_range(-0.035, 0.035)
		var marks := 1 + int(wear_level * 3.0)
		for mark_index in range(marks):
			var x := rng.randf_range(-body_length * 0.38, body_length * 0.38)
			var y := rng.randf_range(0.62, 0.91)
			var length := rng.randf_range(0.10, 0.34)
			var scratch := _add_box(car, "PaintScuff", Vector3(length, rng.randf_range(0.018, 0.045), 0.018), Vector3(x, y, side * (body_width * 0.5 + 0.027)), faded_material if mark_index % 2 == 0 else scratch_material)
			scratch.rotation.z = rng.randf_range(-0.12, 0.12)
	# Quelques impacts de pare-chocs et panneaux légèrement cabossés.
	if vehicle_index % 3 != 1 or is_clando:
		var bumper_scuff := _add_box(car, "BumperScuff", Vector3(rng.randf_range(0.30, 0.62), 0.12, 0.025), Vector3(-body_length * 0.5 - 0.035, 0.70, rng.randf_range(-0.48, 0.48)), scratch_material)
		bumper_scuff.rotation.y = rng.randf_range(-0.18, 0.18)
	if vehicle_index % 2 == 0 or is_clando:
		var dent_side := -1.0 if vehicle_index % 2 == 0 else 1.0
		var dent := _add_box(car, "SmallDentShadow", Vector3(rng.randf_range(0.18, 0.32), 0.07, 0.018), Vector3(rng.randf_range(-0.75, 0.65), rng.randf_range(0.70, 0.88), dent_side * (body_width * 0.5 + 0.03)), scratch_material)
		dent.rotation.z = rng.randf_range(-0.16, 0.16)
	# Le taxi-bus ancien peut avoir une carrosserie plus marquée, sans devenir une épave.
	if is_minibus and vehicle_index % 2 == 1:
		var faded_panel := _add_box(car, "FadedSlidingDoor", Vector3(0.62, 0.40, 0.02), Vector3(-0.12, 0.90, body_width * 0.5 + 0.035), faded_material)
		faded_panel.rotation.z = -0.025

func _spawn_pedestrians() -> void:
	var routes := _load_osm_routes(["footway", "pedestrian", "path", "steps", "living_street"], 22.0, 1100.0)
	if routes.is_empty():
		routes = [{"points": PEDESTRIAN_PATH_A}, {"points": PEDESTRIAN_PATH_B}]
	for index in range(8):
		var route: Array[Vector3] = routes[index % routes.size()]["points"].duplicate()
		if index % 2 == 1:
			route.reverse()
		var pedestrian := _build_pedestrian("Pedestrian_%02d" % index, index)
		add_child(pedestrian)
		var length := _route_length(route)
		_pedestrians.append({"node": pedestrian, "route": route, "distance": fposmod(float(index) * 13.0, maxf(length, 1.0)), "speed": 0.72 + float(index % 3) * 0.16, "cruise_speed": 0.72 + float(index % 3) * 0.16, "phase": float(index) * 1.3})

func _load_osm_routes(highway_types: Array, minimum_length: float, maximum_distance: float) -> Array[Dictionary]:
	var path := "res://data/osm/extended/roads.geojson"
	if not FileAccess.file_exists(path):
		path = "res://data/osm/roads.geojson"
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("features"):
		push_warning("GeoJSON des routes illisible.")
		return []
	var candidates: Array[Dictionary] = []
	for feature in parsed["features"]:
		var properties: Dictionary = feature.get("properties", {})
		if not highway_types.has(str(properties.get("highway", ""))):
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var lines: Array = []
		if geometry.get("type", "") == "LineString":
			lines.append(geometry.get("coordinates", []))
		elif geometry.get("type", "") == "MultiLineString":
			lines = geometry.get("coordinates", [])
		for coordinates in lines:
			var points: Array[Vector3] = []
			var nearest := INF
			for coordinate in coordinates:
				if coordinate.size() < 2:
					continue
				var x := (float(coordinate[0]) - 9.4475) * 111320.0 * cos(deg_to_rad(0.400))
				var z := (0.400 - float(coordinate[1])) * 111320.0
				points.append(Vector3(x, 0.0, z))
				nearest = minf(nearest, Vector2(x, z).length())
			if points.size() < 2 or nearest > maximum_distance or _route_length(points) < minimum_length:
				continue
			var sampled: Array[Vector3] = []
			var stride := maxi(1, int(ceil(float(points.size()) / 24.0)))
			for point_index in range(0, points.size(), stride):
				sampled.append(points[point_index])
			if sampled.back() != points.back():
				sampled.append(points.back())
			candidates.append({"points": sampled, "score": nearest})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["score"]) < float(right["score"]))
	var selected: Array[Dictionary] = []
	for candidate in candidates:
		var center: Vector3 = candidate["points"][candidate["points"].size() / 2]
		var duplicate := false
		for chosen in selected:
			var chosen_center: Vector3 = chosen["points"][chosen["points"].size() / 2]
			if center.distance_to(chosen_center) < 18.0:
				duplicate = true
				break
		if not duplicate:
			selected.append(candidate)
		if selected.size() >= 8:
			break
	return selected

func _route_length(route: Array) -> float:
	var total := 0.0
	for index in range(route.size() - 1):
		var first: Vector3 = route[index]
		var second: Vector3 = route[index + 1]
		total += first.distance_to(second)
	return total


func _build_pedestrian(actor_name: String, index: int) -> Node3D:
	var actor := Node3D.new()
	actor.name = actor_name
	var shirt := _clothing_materials[index % _clothing_materials.size()]
	var skin := _skin_materials[index % _skin_materials.size()]
	var pants := _clothing_materials[(index + 2) % _clothing_materials.size()]
	_add_capsule(actor, "Torso", 0.23, 0.68, Vector3(0.0, 1.18, 0.0), shirt)
	_add_sphere(actor, "Head", 0.17, Vector3(0.0, 1.72, 0.0), skin)
	_add_box(actor, "LeftLeg", Vector3(0.16, 0.55, 0.18), Vector3(-0.12, 0.43, 0.0), pants)
	_add_box(actor, "RightLeg", Vector3(0.16, 0.55, 0.18), Vector3(0.12, 0.43, 0.0), pants)
	_add_box(actor, "LeftArm", Vector3(0.13, 0.52, 0.14), Vector3(-0.30, 1.15, 0.0), skin)
	_add_box(actor, "RightArm", Vector3(0.13, 0.52, 0.14), Vector3(0.30, 1.15, 0.0), skin)
	return actor

func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _advance_actor(actor: Dictionary, delta: float, is_pedestrian: bool) -> void:
	var route: Array = actor["route"]
	var route_length := _route_length(route)
	if route_length <= 0.1:
		return
	var node: Node3D = actor["node"]
	var current_sample := _sample_route(route, float(actor["distance"]))
	var current_position: Vector3 = current_sample["position"]
	var current_direction: Vector3 = current_sample["direction"]
	var cruise_speed := float(actor.get("cruise_speed", actor["speed"]))
	var desired_speed := cruise_speed
	if not is_pedestrian and is_instance_valid(_traffic_signs):
		if _traffic_signs.has_method("is_red_for_vehicle") and bool(_traffic_signs.call("is_red_for_vehicle", current_position, current_direction)):
			desired_speed = 0.0
		elif _traffic_signs.has_method("should_vehicle_yield"):
			var pedestrian_positions: Array = []
			for pedestrian_actor in _pedestrians:
				var pedestrian_node := pedestrian_actor.get("node") as Node3D
				if is_instance_valid(pedestrian_node):
					pedestrian_positions.append(pedestrian_node.global_position)
			if bool(_traffic_signs.call("should_vehicle_yield", current_position, current_direction, pedestrian_positions)):
				desired_speed = 0.0
	elif is_pedestrian and _is_vehicle_near(current_position, 5.0):
		desired_speed = 0.0
	var acceleration := 10.0 if desired_speed < float(actor["speed"]) else 2.0
	var previous_speed := float(actor["speed"])
	actor["speed"] = move_toward(previous_speed, desired_speed, acceleration * delta)
	if not is_pedestrian:
		_update_vehicle_lights(node, previous_speed, float(actor["speed"]), current_direction, route, float(actor["distance"]))
	var distance := fposmod(float(actor["distance"]) + float(actor["speed"]) * delta, route_length)
	actor["distance"] = distance
	var sample := _sample_route(route, distance)
	var position: Vector3 = sample["position"]
	var direction: Vector3 = sample["direction"]
	if not is_pedestrian and direction.length_squared() > 0.001:
		var lateral := Vector3(-direction.z, 0.0, direction.x)
		position += lateral * float(actor.get("lane_offset", 0.0))
	position.y = _ground_height(position.x, position.z) + (0.04 if not is_pedestrian else 0.02)
	node.global_position = position
	if direction.length_squared() > 0.001:
		node.rotation.y = atan2(direction.x, direction.z)
	if not is_pedestrian:
		for wheel in node.get_children():
			if wheel is MeshInstance3D and wheel.name == "Wheel":
				wheel.rotation.x += float(actor["speed"]) * delta / 0.38
	if is_pedestrian:
		var phase := float(actor["phase"]) + distance * 0.65
		var leg_swing := sin(phase) * 0.42
		var left_leg := node.get_node_or_null("LeftLeg") as Node3D
		var right_leg := node.get_node_or_null("RightLeg") as Node3D
		var left_arm := node.get_node_or_null("LeftArm") as Node3D
		var right_arm := node.get_node_or_null("RightArm") as Node3D
		if left_leg != null:
			left_leg.rotation.x = leg_swing
		if right_leg != null:
			right_leg.rotation.x = -leg_swing
		if left_arm != null:
			left_arm.rotation.x = -leg_swing * 0.55
		if right_arm != null:
			right_arm.rotation.x = leg_swing * 0.55



func _is_vehicle_near(position: Vector3, radius: float) -> bool:
	for vehicle in _traffic:
		var vehicle_node := vehicle.get("node") as Node3D
		if is_instance_valid(vehicle_node) and vehicle_node.global_position.distance_to(position) < radius:
			return true
	return false

func _update_vehicle_lights(car: Node3D, previous_speed: float, current_speed: float, current_direction: Vector3, route: Array, distance: float) -> void:
	var braking := current_speed < previous_speed - 0.025 or current_speed < 0.8
	var brake_materials: Array[StandardMaterial3D] = []
	var indicator_materials: Array[Dictionary] = []
	for child in car.get_children():
		if child is MeshInstance3D:
			if str(child.name).begins_with("BrakeLight"):
				var brake_material := child.get_meta("lamp_material", null) as StandardMaterial3D
				if brake_material != null and not brake_materials.has(brake_material):
					brake_materials.append(brake_material)
			elif str(child.name).begins_with("FrontIndicator") or str(child.name).begins_with("RearIndicator"):
				var indicator_material := child.get_meta("indicator_material", null) as StandardMaterial3D
				if indicator_material != null:
					var indicator_entry := {"material": indicator_material, "side": float(child.get_meta("indicator_side", 0.0))}
					if not indicator_materials.has(indicator_entry):
						indicator_materials.append(indicator_entry)
	for material in brake_materials:
		material.emission_energy_multiplier = 2.0 if braking else 0.0
	var next_sample := _sample_route(route, fposmod(distance + 7.0, _route_length(route)))
	var next_direction: Vector3 = next_sample.direction
	var turn_cross := current_direction.x * next_direction.z - current_direction.z * next_direction.x
	var turn_dot := current_direction.dot(next_direction)
	var turning := absf(turn_cross) > 0.12 and turn_dot > 0.45
	var flash_on := turning and fposmod(float(Time.get_ticks_msec()) / 1000.0, 0.9) < 0.42
	var turn_side := -1.0 if turn_cross > 0.0 else 1.0
	for entry in indicator_materials:
		var material: StandardMaterial3D = entry.material
		var selected_side := is_equal_approx(float(entry.side), turn_side)
		material.emission_energy_multiplier = 1.7 if flash_on and selected_side else 0.0

func _sample_route(route: Array, distance: float) -> Dictionary:
	var remaining := distance
	for index in range(route.size() - 1):
		var start: Vector3 = route[index]
		var finish: Vector3 = route[index + 1]
		var segment_length := start.distance_to(finish)
		if remaining <= segment_length:
			var direction := (finish - start).normalized()
			return {"position": start.lerp(finish, remaining / maxf(segment_length, 0.001)), "direction": direction}
		remaining -= segment_length
	var last: Vector3 = route[route.size() - 1]
	return {"position": last, "direction": (last - route[route.size() - 2]).normalized()}

func _ground_height(x: float, z: float) -> float:
	if is_instance_valid(_world_map) and _world_map.has_method("terrain_height_at_world"):
		return float(_world_map.call("terrain_height_at_world", x, z))
	return 0.0
