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

func _ready() -> void:
	_world_map = get_parent().get_node_or_null("WorldMap")
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
	var lanes: Array[float] = [-2.15, 2.15, -2.15, 2.15, 0.0]
	var speeds: Array[float] = [7.2, 6.5, 8.0, 5.8, 6.8]
	for index in range(5):
		var route: Array[Vector3] = []
		for point in ROAD_PATH_A:
			route.append(Vector3(point.x, point.y, point.z + lanes[index]))
		if index % 2 == 1:
			route.reverse()
		var car := _build_car("TrafficCar_%02d" % index, _road_materials[index])
		add_child(car)
		_traffic.append({"node": car, "route": route, "distance": float(index) * 34.0, "speed": speeds[index], "phase": float(index) * 0.8})

func _build_car(car_name: String, paint: StandardMaterial3D) -> Node3D:
	var car := Node3D.new()
	car.name = car_name
	_add_box(car, "Body", Vector3(4.0, 0.82, 1.78), Vector3(0.0, 0.82, 0.0), paint)
	_add_box(car, "Cabin", Vector3(2.05, 0.78, 1.55), Vector3(-0.18, 1.55, 0.0), paint)
	var glass := _material(Color(0.09, 0.17, 0.22), 0.18)
	_add_box(car, "Windshield", Vector3(0.06, 0.55, 1.42), Vector3(0.88, 1.57, 0.0), glass)
	_add_box(car, "RearWindow", Vector3(0.06, 0.52, 1.38), Vector3(-1.22, 1.57, 0.0), glass)
	var lamp := _material(Color(1.0, 0.86, 0.56), 0.3)
	var tail := _material(Color(0.72, 0.035, 0.025), 0.35)
	for side in [-1.0, 1.0]:
		_add_box(car, "Headlight", Vector3(0.10, 0.20, 0.34), Vector3(2.02, 0.82, side * 0.58), lamp)
		_add_box(car, "Taillight", Vector3(0.10, 0.20, 0.34), Vector3(-2.02, 0.82, side * 0.58), tail)
		for axle in [-1.25, 1.25]:
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

func _spawn_pedestrians() -> void:
	for index in range(8):
		var route: Array[Vector3] = PEDESTRIAN_PATH_A.duplicate() if index < 4 else PEDESTRIAN_PATH_B.duplicate()
		if index % 2 == 1:
			route.reverse()
		var pedestrian := _build_pedestrian("Pedestrian_%02d" % index, index)
		add_child(pedestrian)
		_pedestrians.append({"node": pedestrian, "route": route, "distance": float(index) * 17.0, "speed": 0.85 + float(index % 3) * 0.18, "phase": float(index) * 1.3})

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
	var distance := fposmod(float(actor["distance"]) + float(actor["speed"]) * delta, route_length)
	actor["distance"] = distance
	var sample := _sample_route(route, distance)
	var node: Node3D = actor["node"]
	var position: Vector3 = sample["position"]
	position.y = _ground_height(position.x, position.z) + (0.04 if not is_pedestrian else 0.02)
	node.global_position = position
	var direction: Vector3 = sample["direction"]
	if direction.length_squared() > 0.001:
		node.rotation.y = atan2(direction.x, direction.z)
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

func _route_length(route: Array) -> float:
	var total := 0.0
	for index in range(route.size() - 1):
		total += (route[index + 1] as Vector3).distance_to(route[index] as Vector3)
	return total

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
