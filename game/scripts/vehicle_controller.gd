extends CharacterBody3D
class_name VehicleController
## Conduite arcade, caméras multiples et tableau de bord.

@export_group("Motorisation")
@export var acceleration: float = 5.8
@export var reverse_acceleration: float = 3.8
@export var max_speed: float = 42.0
@export var reverse_speed: float = 12.0
@export var service_brake: float = 19.0
@export var coast_deceleration: float = 1.15
@export var rolling_resistance: float = 0.12

@export_group("Direction et adhérence")
@export var wheel_base: float = 3.0
@export var front_track: float = 1.62
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

var player_driving := false
var current_speed := 0.0
var odometer_meters := 0.0
var _wheel_nodes: Array[Node3D] = []
var _wheel_base_basis: Array[Basis] = []
var _wheel_local_positions: Array[Vector3] = []
var _wheel_is_front: Array[bool] = []
var _wheel_is_left: Array[bool] = []
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

const CAMERA_NAMES := ["EXTÉRIEURE PROCHE", "EXTÉRIEURE ÉLOIGNÉE", "COCKPIT", "CINÉMATIQUE"]

func _ready() -> void:
	add_to_group("drivable_vehicle")
	var jeep := get_node_or_null("JeepModel")
	if jeep != null:
		_collect_wheel_nodes(jeep, false)
	_classify_wheels()
	if _wheel_nodes.size() < 4:
		push_warning("Jeep : %d éléments de roue détectés. Les pivots du GLB doivent être vérifiés avant de corriger les axes." % _wheel_nodes.size())
	_setup_vehicle_cameras()
	_setup_vehicle_hud()

func _physics_process(delta: float) -> void:
	if not player_driving:
		_planar_velocity = _planar_velocity.move_toward(Vector3.ZERO, service_brake * delta)
		velocity.x = _planar_velocity.x
		velocity.z = _planar_velocity.z
		_apply_gravity(delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("vehicle_camera_next"):
		_set_camera_mode((_camera_mode + 1) % CAMERA_NAMES.size())

	var controls := _read_drive_controls()
	_update_longitudinal_speed(controls.x, controls.y, delta)
	_steering_input = controls.z
	_update_steering_and_heading(delta)
	_update_planar_motion(delta)
	var previous_position := global_position
	_apply_gravity(delta)
	move_and_slide()
	var travelled := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z).length()
	odometer_meters += travelled
	if wheel_radius > 0.05:
		_wheel_roll_angle -= signf(current_speed) * travelled / wheel_radius
	_update_wheel_animation()
	_update_vehicle_hud()
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

func _update_longitudinal_speed(throttle: float, brake: float, delta: float) -> void:
	if brake > 0.03:
		if current_speed > 0.35:
			current_speed = move_toward(current_speed, 0.0, service_brake * brake * delta)
		elif throttle < 0.03:
			current_speed = move_toward(current_speed, -reverse_speed, reverse_acceleration * brake * delta)
	elif throttle > 0.03:
		if current_speed < -0.35:
			current_speed = move_toward(current_speed, 0.0, service_brake * throttle * delta)
		else:
			var speed_ratio := clampf(current_speed / max_speed, 0.0, 1.0)
			var torque_factor := 1.0 - 0.62 * pow(speed_ratio, 1.55)
			current_speed = move_toward(current_speed, max_speed, acceleration * torque_factor * throttle * delta)
	else:
		var drag := coast_deceleration + absf(current_speed) * rolling_resistance
		current_speed = move_toward(current_speed, 0.0, drag * delta)
	current_speed = clampf(current_speed, -reverse_speed, max_speed)

func _update_steering_and_heading(delta: float) -> void:
	var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var allowed_angle := lerpf(max_steering_angle, high_speed_steering_angle, speed_ratio)
	_steering_angle = move_toward(_steering_angle, _steering_input * allowed_angle, steering_response * delta)
	if absf(current_speed) > 0.08 and wheel_base > 0.5:
		rotation.y += -(current_speed / wheel_base) * tan(_steering_angle) * delta

func _update_planar_motion(delta: float) -> void:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var forward_speed := _planar_velocity.dot(forward)
	var lateral_speed := _planar_velocity.dot(right)
	var lateral_limit := lateral_grip * (0.72 if absf(current_speed) > 28.0 else 1.0)
	lateral_speed = move_toward(lateral_speed, 0.0, lateral_limit * delta)
	forward_speed = move_toward(forward_speed, current_speed, 28.0 * delta)
	_planar_velocity = forward * forward_speed + right * lateral_speed
	velocity.x = _planar_velocity.x
	velocity.z = _planar_velocity.z

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = -0.2

func _collect_wheel_nodes(root: Node, inside_wheel: bool) -> void:
	for child in root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		var wheel_name := node.name.to_lower()
		var is_candidate := false
		if not inside_wheel:
			is_candidate = wheel_name.contains("wheel") or wheel_name.contains("tire") or wheel_name.contains("tyre") or wheel_name.contains("roue") or wheel_name.contains("pneu")
			for excluded in ["arch", "flare", "well", "fender", "mudguard", "cover", "guard"]:
				if wheel_name.contains(excluded):
					is_candidate = false
					break
		if is_candidate:
			_wheel_nodes.append(node)
			_wheel_base_basis.append(node.transform.basis.orthonormalized())
			_wheel_local_positions.append(to_local(node.global_position))
			continue
		_collect_wheel_nodes(node, inside_wheel)

func _classify_wheels() -> void:
	if _wheel_nodes.is_empty():
		return
	var min_z := INF
	var max_z := -INF
	for local_position in _wheel_local_positions:
		min_z = minf(min_z, local_position.z)
		max_z = maxf(max_z, local_position.z)
	var middle_z := (min_z + max_z) * 0.5
	for i in range(_wheel_nodes.size()):
		var local_position := _wheel_local_positions[i]
		_wheel_is_front.append(local_position.z < middle_z)
		_wheel_is_left.append(local_position.x < 0.0)

func _ackermann_angle(is_left: bool) -> float:
	if absf(_steering_angle) < 0.001:
		return 0.0
	var radius := wheel_base / maxf(absf(tan(_steering_angle)), 0.001)
	var inner_radius := maxf(0.5, radius - front_track * 0.5)
	var outer_radius := radius + front_track * 0.5
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
		if _wheel_is_front[i]:
			steering_angle = _ackermann_angle(_wheel_is_left[i]) * wheel_steer_visual_multiplier
		var steering_basis := Basis(steer_axis, -steering_angle)
		var rolling_basis := Basis(spin_axis, _wheel_roll_angle)
		_wheel_nodes[i].transform.basis = (_wheel_base_basis[i] * steering_basis * rolling_basis).orthonormalized()

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
	current_speed = 0.0
	_planar_velocity = Vector3.ZERO
	_steering_angle = 0.0
	_steering_input = 0.0
	velocity = Vector3.ZERO
	_set_camera_mode(_camera_mode)

func exit_vehicle() -> void:
	player_driving = false
	_hud_layer.visible = false
	current_speed = 0.0
	_planar_velocity = Vector3.ZERO
	_steering_angle = 0.0
	_steering_input = 0.0
	velocity = Vector3.ZERO
