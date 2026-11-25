extends VehicleBody3D
class_name VehicleController
## Conduite arcade, caméras multiples et tableau de bord.

@export_group("Motorisation")
@export var acceleration: float = 5.8
@export var reverse_acceleration: float = 3.8
@export var max_speed: float = 42.0
@export var reverse_speed: float = 12.0
@export var service_brake: float = 32.0
@export var coast_deceleration: float = 1.15
@export var rolling_resistance: float = 0.12

@export_group("Direction et adhérence")
@export var wheel_base: float = 3.0
@export var front_track: float = 1.62
@export var rear_track: float = 1.48
@export var max_steering_angle: float = 0.52
@export var high_speed_steering_angle: float = 0.15
@export var steering_response: float = 4.8
@export var lateral_grip: float = 8.5
@export var gamepad_deadzone: float = 0.14

@export_group("Animation des roues")
@export var wheel_radius: float = 0.43
@export var wheel_spin_axis: Vector3 = Vector3.RIGHT
@export var wheel_steer_axis: Vector3 = Vector3.UP
@export var wheel_steer_visual_multiplier: float = 1.0

@export_group("Détection des roues")
@export var minimum_wheel_dimension: float = 0.18
@export var maximum_wheel_dimension: float = 1.4

@export_group("Architecture du véhicule")
@export var vehicle_model_path: NodePath = ^"VehicleModel"
@export_enum("Avant", "Arrière", "Aucun") var steering_axle: int = 0
@export_enum("Avant", "Arrière", "Intégrale", "Aucune") var drive_axle: int = 1

var player_driving := false
var current_speed := 0.0
var odometer_meters := 0.0
var _last_odometer_position := Vector3.ZERO
var _wheel_nodes: Array[Node3D] = []
var _wheel_base_basis: Array[Basis] = []
var _wheel_local_positions: Array[Vector3] = []
var _wheel_is_front: Array[bool] = []
var _wheel_is_steering: Array[bool] = []
var _wheel_is_driven: Array[bool] = []
var _wheel_is_left: Array[bool] = []
var _wheel_rays: Array[RayCast3D] = []
var _wheel_grounded_count := 0
var _average_surface_grip := 1.0
var _door_nodes: Array[Node3D] = []
var _driver_door_nodes: Array[Node3D] = []
var _door_closed_rotations: Array[Vector3] = []
var _wheel_roll_angle := 0.0
var _steering_input := 0.0
var _steering_angle := 0.0
var _planar_velocity := Vector3.ZERO
var _camera_pivot: Node3D
var _camera_arm: SpringArm3D
var _hud_layer: CanvasLayer
var _chase_camera: Camera3D
var _cockpit_camera: Camera3D
var _camera_mode := 0
var _hud_speed: Label
var _hud_odo: Label
var _hud_camera: Label
var _cinematic_time := 0.0
var _engine_audio: AudioStreamPlayer
var _starter_audio: AudioStreamPlayer
var _brake_audio: AudioStreamPlayer
var _tutorial_panel: PanelContainer
var _tutorial_label: Label
var _tutorial_index := 0
var _tutorial_steps: Array[String] = []
var _brake_lights: Array[OmniLight3D] = []
var _brake_lamp_materials: Array[StandardMaterial3D] = []

const CAMERA_NAMES := ["EXTÉRIEURE PROCHE", "EXTÉRIEURE ÉLOIGNÉE", "COCKPIT", "CINÉMATIQUE"]

func _ready() -> void:
	add_to_group("drivable_vehicle")
	_last_odometer_position = global_position
	mass = 1850.0
	center_of_mass_mode = 1
	center_of_mass = Vector3(0.0, 0.28, 0.0)
	linear_damp = 0.08
	angular_damp = 1.4
	can_sleep = false
	var vehicle_model := get_node_or_null(vehicle_model_path) as Node3D
	if vehicle_model != null:
		_collect_wheel_nodes(vehicle_model, false)
		_classify_wheels()
		_setup_brake_lights(vehicle_model)
	else:
		push_warning("Véhicule : modèle introuvable au chemin configuré (%s)." % str(vehicle_model_path))
	_collect_door_nodes(vehicle_model)
	_setup_vehicle_cameras()
	_setup_vehicle_hud()
	_setup_vehicle_audio()
	_setup_driving_lesson()

func _physics_process(delta: float) -> void:
	current_speed = linear_velocity.dot(-global_transform.basis.z)
	if not player_driving:
		engine_force = 0.0
		brake = service_brake
		steering = move_toward(steering, 0.0, steering_response * delta)
		_steering_angle = move_toward(_steering_angle, 0.0, steering_response * delta)
		_update_wheel_animation()
		_last_odometer_position = global_position
		return

	if Input.is_action_just_pressed("vehicle_camera_next"):
		_set_camera_mode((_camera_mode + 1) % CAMERA_NAMES.size())

	var controls := _read_drive_controls()
	var speed_before_update := absf(current_speed)
	_update_longitudinal_speed(controls.x, controls.y, delta)
	_update_brake_lights(controls.y, speed_before_update, delta)
	_steering_input = controls.z
	_update_steering_and_heading(delta)

	current_speed = linear_velocity.dot(-global_transform.basis.z)
	_wheel_roll_angle = fposmod(_wheel_roll_angle + current_speed * delta / maxf(wheel_radius, 0.1), TAU)
	_update_wheel_animation()
	odometer_meters += Vector2(global_position.x - _last_odometer_position.x, global_position.z - _last_odometer_position.z).length()
	_last_odometer_position = global_position
	_update_vehicle_hud()
	_update_vehicle_audio(controls.x, controls.y)
	if _camera_mode == 3:
		_cinematic_time += delta
		_camera_pivot.rotation.y = sin(_cinematic_time * 0.22) * 0.72

func _read_drive_controls() -> Vector3:
	var steer := Input.get_axis("vehicle_left", "vehicle_right")
	var throttle := Input.get_action_strength("vehicle_accelerate")
	var brake := Input.get_action_strength("vehicle_brake")
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		var device := devices[0]
		var pad_steer := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if absf(pad_steer) < gamepad_deadzone:
			pad_steer = 0.0
		if absf(pad_steer) > absf(steer):
			steer = pad_steer
		throttle = maxf(throttle, _read_trigger(device, JOY_AXIS_TRIGGER_RIGHT))
		brake = maxf(brake, _read_trigger(device, JOY_AXIS_TRIGGER_LEFT))
	return Vector3(clampf(throttle, 0.0, 1.0), clampf(brake, 0.0, 1.0), clampf(steer, -1.0, 1.0))

func _read_trigger(device: int, axis: JoyAxis) -> float:
	var raw := Input.get_joy_axis(device, axis)
	if raw < -0.5:
		return clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	return clampf(raw, 0.0, 1.0)

func _update_longitudinal_speed(throttle: float, brake_input: float, _delta: float) -> void:
	current_speed = linear_velocity.dot(-global_transform.basis.z)
	engine_force = 0.0
	brake = 0.0

	# Le frein hydraulique ralentit d'abord ; la marche arrière ne s'engage
	# qu'une fois le véhicule presque arrêté.
	if brake_input > 0.03:
		if absf(current_speed) > 0.45:
			brake = service_brake * brake_input
		elif throttle < 0.03:
			engine_force = -reverse_acceleration * mass * brake_input
	elif throttle > 0.03:
		if current_speed < -0.45:
			brake = service_brake * throttle
		else:
			var speed_ratio := clampf(maxf(current_speed, 0.0) / max_speed, 0.0, 1.0)
			var torque_factor := 1.0 - 0.48 * pow(speed_ratio, 1.35)
			engine_force = acceleration * mass * torque_factor * throttle
	else:
		# Frein moteur et résistance au roulement lorsque l'accélérateur est relâché.
		brake = coast_deceleration + absf(current_speed) * rolling_resistance

	# Limiteur simple pour éviter que le moteur pousse au-delà des vitesses réglées.
	if current_speed >= max_speed and engine_force > 0.0:
		engine_force = 0.0
		brake = maxf(brake, 1.5)
	elif current_speed <= -reverse_speed and engine_force < 0.0:
		engine_force = 0.0
		brake = maxf(brake, 1.5)

func _update_steering_and_heading(delta: float) -> void:
	var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var allowed_angle := lerpf(max_steering_angle, high_speed_steering_angle, pow(speed_ratio, 0.72))
	_steering_angle = move_toward(_steering_angle, _steering_input * allowed_angle, steering_response * delta)
	# VehicleBody3D transmet cet angle aux deux roues avant réellement directrices.
	steering = _steering_angle

func _collect_door_nodes(root: Node) -> void:
	_door_nodes.clear()
	_driver_door_nodes.clear()
	_door_closed_rotations.clear()
	if root == null:
		return
	_find_door_nodes(root)
	for door in _door_nodes:
		_door_closed_rotations.append(door.rotation)
		var door_name := door.name.to_lower()
		if door_name.contains("left") or door_name.contains("driver") or door_name.contains("conducteur") or door_name.contains("fl"):
			_driver_door_nodes.append(door)
	if _door_nodes.is_empty():
		_create_fallback_driver_door()
		push_warning("Véhicule : porte provisoire créée, le modèle GLB ne fournit pas de porte animable.")

func _create_fallback_driver_door() -> void:
	var hinge := Node3D.new()
	hinge.name = "DriverDoor_Test"
	hinge.position = Vector3(-1.08, 0.92, -1.05)
	add_child(hinge)
	var panel := MeshInstance3D.new()
	panel.name = "DoorPanel"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.09, 0.76, 1.22)
	panel.mesh = panel_mesh
	panel.position = Vector3(-0.015, 0.0, 0.58)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.10, 0.17, 0.24)
	body_material.metallic = 0.28
	body_material.roughness = 0.48
	panel.material_override = body_material
	hinge.add_child(panel)
	var window := MeshInstance3D.new()
	window.name = "DoorWindow"
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.07, 0.36, 1.08)
	window.mesh = window_mesh
	window.position = Vector3(-0.01, 0.22, 0.58)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.035, 0.075, 0.11, 0.82)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.roughness = 0.16
	window.material_override = glass_material
	hinge.add_child(window)
	_door_nodes.append(hinge)
	_driver_door_nodes.append(hinge)
	_door_closed_rotations.append(hinge.rotation)

func _find_door_nodes(root: Node) -> void:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		var node_name := node.name.to_lower()
		var is_door := node_name.contains("door") or node_name.contains("porte")
		if is_door and not node_name.contains("handle") and not node_name.contains("poignee"):
			_door_nodes.append(node)
			continue
		_find_door_nodes(node)

func open_driver_door() -> void:
	await _animate_driver_door(true)

func close_driver_door() -> void:
	await _animate_driver_door(false)

func _animate_driver_door(open: bool) -> void:
	var targets := _driver_door_nodes if not _driver_door_nodes.is_empty() else _door_nodes
	if targets.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for door in targets:
		var index := _door_nodes.find(door)
		if index < 0:
			continue
		var closed := _door_closed_rotations[index]
		var side := -1.0 if to_local(door.global_position).x < 0.0 else 1.0
		var open_rotation := Vector3(closed.x, closed.y + deg_to_rad(64.0) * side, closed.z)
		tween.tween_property(door, "rotation", open_rotation if open else closed, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _collect_wheel_nodes(root: Node, inside_wheel: bool) -> void:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		var wheel_name := node.name.to_lower()
		var is_candidate := false
		if not inside_wheel:
			is_candidate = wheel_name.contains("wheel") or wheel_name.contains("tire") or wheel_name.contains("tyre") or wheel_name.contains("roue") or wheel_name.contains("pneu")
			for excluded in ["arch", "flare", "well", "fender", "mudguard", "cover", "guard", "plate", "spare"]:
				if wheel_name.contains(excluded):
					is_candidate = false
					break
			# Certains GLB donnent des noms génériques aux meshes des pneus.
			# On les repère aussi par leur forme et leur position basse aux quatre coins.
			if not is_candidate and node is MeshInstance3D:
				var bounds := _get_subtree_world_aabb(node)
				var dimensions := bounds.size
				var largest := maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
				var smallest := minf(dimensions.x, minf(dimensions.y, dimensions.z))
				var center := to_local(bounds.get_center())
				is_candidate = largest >= 0.34 and largest <= 1.12 and smallest >= 0.12 and smallest <= 0.48 and center.y < 0.85 and absf(center.x) > 0.48 and absf(center.z) > 0.72
		if is_candidate and _create_wheel_pivot(node):
			continue
		# Un parent nommé "wheels" peut contenir plusieurs roues et avoir
		# une boîte englobante de la taille du véhicule : on explore ses enfants.
		_collect_wheel_nodes(node, inside_wheel)


func _create_wheel_pivot(wheel_node: Node3D) -> bool:
	var original_parent := wheel_node.get_parent()
	if original_parent == null:
		return false
	var world_bounds := _get_subtree_world_aabb(wheel_node)
	if world_bounds.size.length_squared() < 0.0001:
		return false
	var dimensions := world_bounds.size
	var largest_dimension := maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	var smallest_dimension := minf(dimensions.x, minf(dimensions.y, dimensions.z))
	# Une roue individuelle mesure moins d'environ 1,4 m. Les blocs
	# contenant tout le véhicule et les petites plaques de secours sont exclus.
	if largest_dimension > maximum_wheel_dimension or smallest_dimension < minimum_wheel_dimension:
		return false
	var wheel_center := world_bounds.get_center()
	var original_global := wheel_node.global_transform
	var pivot := Node3D.new()
	pivot.name = "%s_RotationPivot" % wheel_node.name
	original_parent.add_child(pivot)
	pivot.global_transform = Transform3D(global_transform.basis.orthonormalized(), wheel_center)
	original_parent.remove_child(wheel_node)
	pivot.add_child(wheel_node)
	wheel_node.global_transform = original_global
	_wheel_nodes.append(pivot)
	_wheel_base_basis.append(pivot.transform.basis.orthonormalized())
	_wheel_local_positions.append(to_local(wheel_center))
	return true


func _get_subtree_world_aabb(root: Node) -> AABB:
	var result := AABB()
	var found := false
	if root is MeshInstance3D:
		var mesh_node := root as MeshInstance3D
		if mesh_node.mesh != null:
			var local_bounds := mesh_node.mesh.get_aabb()
			for corner_index in range(8):
				var corner := Vector3(
					local_bounds.position.x + (local_bounds.size.x if (corner_index & 1) != 0 else 0.0),
					local_bounds.position.y + (local_bounds.size.y if (corner_index & 2) != 0 else 0.0),
					local_bounds.position.z + (local_bounds.size.z if (corner_index & 4) != 0 else 0.0)
				)
				var world_corner := mesh_node.global_transform * corner
				if not found:
					result = AABB(world_corner, Vector3.ZERO)
					found = true
				else:
					result = result.expand(world_corner)
	for child in root.get_children():
		var child_bounds := _get_subtree_world_aabb(child)
		if child_bounds.size.length_squared() > 0.0001:
			if not found:
				result = child_bounds
				found = true
			else:
				result = result.merge(child_bounds)
	return result

func _classify_wheels() -> void:
	_wheel_is_front.clear()
	_wheel_is_steering.clear()
	_wheel_is_driven.clear()
	_wheel_is_left.clear()
	if _wheel_nodes.is_empty():
		return
	var min_z := INF
	var max_z := -INF
	for local_position in _wheel_local_positions:
		min_z = minf(min_z, local_position.z)
		max_z = maxf(max_z, local_position.z)
	# Le véhicule regarde vers -Z : les roues les plus en avant ont le Z
	# le plus faible. La classification reste indépendante de l'ordre des meshes.
	var middle_z := (min_z + max_z) * 0.5
	for local_position in _wheel_local_positions:
		var is_front_axle := local_position.z < middle_z
		var is_steering := false
		match steering_axle:
			0:
				is_steering = is_front_axle
			1:
				is_steering = not is_front_axle
			_:
				is_steering = false
		var is_driven := false
		match drive_axle:
			0:
				is_driven = is_front_axle
			1:
				is_driven = not is_front_axle
			2:
				is_driven = true
			_:
				is_driven = false
		_wheel_is_front.append(is_front_axle)
		_wheel_is_steering.append(is_steering)
		_wheel_is_driven.append(is_driven)
		_wheel_is_left.append(local_position.x < 0.0)

	# Les configurations à quatre roues doivent avoir une roue à chaque coin.
	# Les véhicules à trois roues (certains chariots) restent acceptés.
	if _wheel_nodes.size() == 4:
		var front_left := 0
		var front_right := 0
		var rear_left := 0
		var rear_right := 0
		for i in range(_wheel_nodes.size()):
			if _wheel_is_front[i]:
				if _wheel_is_left[i]:
					front_left += 1
				else:
					front_right += 1
			else:
				if _wheel_is_left[i]:
					rear_left += 1
				else:
					rear_right += 1
		if front_left != 1 or front_right != 1 or rear_left != 1 or rear_right != 1:
			push_warning("Véhicule : les quatre roues ne forment pas exactement une roue à chaque coin.")
	elif _wheel_nodes.size() < 2:
		push_warning("Véhicule : %d roue(s) détectée(s) ; vérifiez la hiérarchie du modèle 3D." % _wheel_nodes.size())
	else:
		var front_count := 0
		var rear_count := 0
		for is_front_axle in _wheel_is_front:
			if is_front_axle:
				front_count += 1
			else:
				rear_count += 1
		if front_count == 0 or rear_count == 0:
			push_warning("Véhicule : impossible d'identifier les deux essieux à partir des pivots détectés.")

func _ackermann_angle(is_left: bool, axle_track: float) -> float:
	if absf(_steering_angle) < 0.001:
		return 0.0
	var radius := wheel_base / maxf(absf(tan(_steering_angle)), 0.001)
	var inner_radius := maxf(0.5, radius - axle_track * 0.5)
	var outer_radius := radius + axle_track * 0.5
	var is_inner := (_steering_angle < 0.0 and is_left) or (_steering_angle > 0.0 and not is_left)
	var angle := atan(wheel_base / (inner_radius if is_inner else outer_radius))
	return signf(_steering_angle) * angle

func _update_wheel_animation() -> void:
	var spin_axis := wheel_spin_axis.normalized()
	var steer_axis := wheel_steer_axis.normalized()
	if spin_axis.length_squared() < 0.9:
		spin_axis = Vector3.RIGHT
	if steer_axis.length_squared() < 0.9:
		steer_axis = Vector3.UP
	for i in range(_wheel_nodes.size()):
		var steering_angle := 0.0
		if _wheel_is_steering[i]:
			var axle_wheel_count := 0
			for j in range(_wheel_nodes.size()):
				if _wheel_is_front[j] == _wheel_is_front[i]:
					axle_wheel_count += 1
			var axle_track := front_track if _wheel_is_front[i] else rear_track
			# Une roue centrale seule (tricycle ou transpalette) n'a pas
			# besoin de correction Ackermann gauche/droite.
			if axle_wheel_count > 1:
				steering_angle = _ackermann_angle(_wheel_is_left[i], axle_track)
			else:
				steering_angle = _steering_angle
			steering_angle *= wheel_steer_visual_multiplier
			# Sur un chariot à direction arrière, les roues arrière braquent
			# dans le sens opposé à l'angle de référence du châssis.
			if steering_axle == 1:
				steering_angle = -steering_angle
		# Toutes les roues roulent visuellement ; drive_axle décrit l'essieu
		# moteur pour chaque type, sans simuler un couple physique par roue.
		var steering_basis := Basis(steer_axis, -steering_angle)
		var rolling_basis := Basis(spin_axis, _wheel_roll_angle)
		_wheel_nodes[i].transform.basis = (_wheel_base_basis[i] * steering_basis * rolling_basis).orthonormalized()

func _setup_brake_lights(model_root: Node3D) -> void:
	# Le véhicule avance vers -Z : l'arrière se trouve du côté +Z.
	var bounds := _get_subtree_world_aabb(model_root)
	if bounds.size.length_squared() < 0.01:
		push_warning("Feux stop : dimensions du modèle indisponibles.")
		return
	var center := to_local(bounds.get_center())
	var rear_world_z := bounds.position.z + bounds.size.z
	var rear_local := to_local(Vector3(bounds.get_center().x, bounds.get_center().y, rear_world_z))
	var half_width := maxf(0.45, bounds.size.x * 0.34)
	var lamp_y := center.y + bounds.size.y * 0.12
	var rear_offset := maxf(0.06, absf(rear_local.z - center.z) * 0.015)
	for side in [-1.0, 1.0]:
		var lamp_position := Vector3(center.x + side * half_width, lamp_y, rear_local.z - rear_offset)
		var lamp_mesh := MeshInstance3D.new()
		lamp_mesh.name = "BrakeLamp_%s" % ("Left" if side < 0.0 else "Right")
		var sphere := SphereMesh.new()
		sphere.radius = 0.105
		sphere.height = 0.21
		lamp_mesh.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.22, 0.008, 0.012)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.015, 0.025)
		material.emission_energy_multiplier = 0.35
		lamp_mesh.material_override = material
		add_child(lamp_mesh)
		lamp_mesh.position = lamp_position
		_brake_lamp_materials.append(material)
		var glow := OmniLight3D.new()
		glow.name = "BrakeLightGlow_%s" % ("Left" if side < 0.0 else "Right")
		glow.position = lamp_position
		glow.light_color = Color(1.0, 0.025, 0.035)
		glow.light_energy = 0.0
		glow.omni_range = 3.0
		glow.shadow_enabled = false
		add_child(glow)
		_brake_lights.append(glow)


func _update_brake_lights(brake_input: float, speed_before: float, delta: float) -> void:
	var speed_now := absf(current_speed)
	var deceleration := (speed_before - speed_now) / maxf(delta, 0.0001)
	var braking := player_driving and (
		brake_input > 0.04 or (speed_before > 1.2 and deceleration > 1.0 and speed_now > 0.8)
	)
	for light in _brake_lights:
		light.light_energy = 1.8 if braking else 0.0
	for material in _brake_lamp_materials:
		material.emission_energy_multiplier = 3.0 if braking else 0.35


func _setup_vehicle_cameras() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "VehicleCameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.65, 0.25)
	add_child(_camera_pivot)
	_camera_arm = SpringArm3D.new()
	_camera_arm.name = "ChaseSpringArm"
	_camera_arm.spring_length = 4.8
	_camera_arm.margin = 0.25
	_camera_pivot.add_child(_camera_arm)
	_chase_camera = Camera3D.new()
	_chase_camera.name = "ChaseCamera"
	_chase_camera.fov = 72.0
	_camera_arm.add_child(_chase_camera)
	_cockpit_camera = Camera3D.new()
	_cockpit_camera.name = "CockpitCamera"
	_cockpit_camera.position = Vector3(-0.38, 1.38, 0.28)
	_cockpit_camera.fov = 78.0
	add_child(_cockpit_camera)


func _setup_vehicle_audio() -> void:
	_engine_audio = AudioStreamPlayer.new()
	_engine_audio.name = "EngineLoop"
	_engine_audio.stream = _build_vehicle_tone(1.0, 48.0, 96.0, true)
	_engine_audio.volume_db = -17.0
	add_child(_engine_audio)
	_starter_audio = AudioStreamPlayer.new()
	_starter_audio.name = "EngineStarter"
	_starter_audio.stream = _build_vehicle_tone(0.48, 72.0, 145.0, false)
	_starter_audio.volume_db = -9.0
	add_child(_starter_audio)
	_brake_audio = AudioStreamPlayer.new()
	_brake_audio.name = "BrakeSqueal"
	_brake_audio.stream = _build_vehicle_tone(0.8, 690.0, 1040.0, true)
	_brake_audio.volume_db = -25.0
	add_child(_brake_audio)


func _build_vehicle_tone(duration: float, base_frequency: float, harmonic: float, looping: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(1, int(sample_rate * duration))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var time := float(i) / float(sample_rate)
		var envelope := 1.0
		if not looping:
			envelope = minf(1.0, time * 18.0) * pow(maxf(0.0, 1.0 - time / duration), 1.7)
		var wave := sin(TAU * base_frequency * time) * 0.48 + sin(TAU * harmonic * time) * 0.20
		if looping and base_frequency < 100.0:
			wave += sin(TAU * 24.0 * time) * 0.16
		else:
			wave += sin(TAU * (harmonic * 1.37) * time) * 0.10
		bytes.encode_s16(i * 2, int(clampf(wave * envelope, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream


func _update_vehicle_audio(throttle: float, brake: float) -> void:
	if not player_driving:
		if _engine_audio.playing:
			_engine_audio.stop()
		if _brake_audio.playing:
			_brake_audio.stop()
		return
	if not _engine_audio.playing:
		_engine_audio.play()
	var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	_engine_audio.pitch_scale = 0.82 + speed_ratio * 1.25 + throttle * 0.12
	_engine_audio.volume_db = -18.0 + throttle * 2.5
	if brake > 0.72 and absf(current_speed) > 8.0:
		if not _brake_audio.playing:
			_brake_audio.play()
	elif _brake_audio.playing:
		_brake_audio.stop()


func _setup_driving_lesson() -> void:
	_tutorial_steps = [
		"1 / DÉMARRER\nAppuie sur W (clavier) ou RT (manette) progressivement pour démarrer le véhicule. La vitesse s'affiche en km/h.",
		"2 / ACCÉLÉRER\nMaintiens W ou RT. La vitesse augmente progressivement : relâche pour laisser le véhicule ralentir.",
		"3 / TOURNER\nUtilise A et D ou le stick gauche. À grande vitesse, braque moins fort pour garder le contrôle.",
		"4 / FREINER\nMaintiens S ou LT pour ralentir. À l'arrêt, maintenir S ou LT engage la marche arrière.",
		"5 / CAMÉRAS\nAppuie sur C pour passer de la vue proche à la vue éloignée, au cockpit puis à la vue cinématique.",
		"6 / QUITTER LE VÉHICULE\nAppuie sur F ou Y (manette) pour sortir. Arrête-toi avant de quitter le véhicule."
	]
	var panel := PanelContainer.new()
	panel.name = "DrivingLesson"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-220, 22)
	panel.custom_minimum_size = Vector2(440, 0)
	panel.visible = false
	_hud_layer.add_child(panel)
	_tutorial_panel = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "ÉCOLE DE CONDUITE — VÉHICULE"
	heading.add_theme_font_size_override("font_size", 17)
	column.add_child(heading)
	_tutorial_label = Label.new()
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_label.custom_minimum_size = Vector2(400, 76)
	column.add_child(_tutorial_label)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var next_button := Button.new()
	next_button.text = "SUIVANT"
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(_next_tutorial_step)
	buttons.add_child(next_button)
	var close_button := Button.new()
	close_button.text = "IGNORER"
	close_button.pressed.connect(_hide_driving_lesson)
	buttons.add_child(close_button)


func _next_tutorial_step() -> void:
	_tutorial_index += 1
	if _tutorial_index >= _tutorial_steps.size():
		_hide_driving_lesson()
		return
	_tutorial_label.text = _tutorial_steps[_tutorial_index]


func _hide_driving_lesson() -> void:
	if _tutorial_panel != null:
		_tutorial_panel.visible = false


func _show_driving_lesson() -> void:
	if _tutorial_panel == null:
		return
	_tutorial_index = 0
	_tutorial_label.text = _tutorial_steps[_tutorial_index]
	_tutorial_panel.visible = true

func _setup_vehicle_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "VehicleDashboard"
	_hud_layer.layer = 8
	_hud_layer.visible = false
	add_child(_hud_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 150)
	panel.custom_minimum_size = Vector2(190, 100)
	_hud_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	_hud_speed = Label.new()
	_hud_speed.add_theme_font_size_override("font_size", 24)
	_hud_speed.text = "0 km/h"
	column.add_child(_hud_speed)
	_hud_odo = Label.new()
	_hud_odo.text = "ODO 0.0 km"
	column.add_child(_hud_odo)
	_hud_camera = Label.new()
	_hud_camera.text = CAMERA_NAMES[0]
	column.add_child(_hud_camera)
	_update_vehicle_hud()

func _update_vehicle_hud() -> void:
	if _hud_speed == null:
		return
	_hud_speed.text = "%03d km/h" % int(round(absf(current_speed) * 3.6))
	_hud_odo.text = "ODO  %.1f km" % (odometer_meters / 1000.0)
	_hud_camera.text = CAMERA_NAMES[_camera_mode]

func _set_camera_mode(mode: int) -> void:
	_camera_mode = clampi(mode, 0, CAMERA_NAMES.size() - 1)
	if _chase_camera == null or _cockpit_camera == null:
		return
	if _camera_mode == 2:
		_chase_camera.current = false
		_cockpit_camera.make_current()
	else:
		_cockpit_camera.current = false
		_chase_camera.make_current()
		if _camera_mode == 0:
			_camera_pivot.position = Vector3(0.0, 1.65, 0.25)
			_camera_pivot.rotation = Vector3(-0.12, 0.0, 0.0)
			_camera_arm.spring_length = 4.8
		elif _camera_mode == 1:
			_camera_pivot.position = Vector3(0.0, 1.85, 0.25)
			_camera_pivot.rotation = Vector3(-0.10, 0.0, 0.0)
			_camera_arm.spring_length = 8.0
		else:
			_camera_pivot.position = Vector3(0.0, 2.2, 0.25)
			_camera_pivot.rotation = Vector3(-0.22, 0.0, 0.0)
			_camera_arm.spring_length = 7.0
	_update_vehicle_hud()

func enter_vehicle() -> void:
	player_driving = true
	_hud_layer.visible = true
	_starter_audio.play()
	_show_driving_lesson()
	current_speed = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_odometer_position = global_position
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	_steering_angle = 0.0
	_steering_input = 0.0
	_set_camera_mode(_camera_mode)

func exit_vehicle() -> void:
	player_driving = false
	_hud_layer.visible = false
	_hide_driving_lesson()
	_update_vehicle_audio(0.0, 0.0)
	current_speed = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0.0
	brake = service_brake
	steering = 0.0
	_steering_angle = 0.0
	_steering_input = 0.0
