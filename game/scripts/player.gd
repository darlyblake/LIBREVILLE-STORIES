extends CharacterBody3D
## Déplacement troisième personne : marche, course, saut, escalade de rebords et véhicules.

@export var move_speed: float = 4.8
@export var sprint_speed: float = 8.8
@export var acceleration: float = 18.0
@export var air_control: float = 5.0
@export var jump_velocity: float = 5.4
@export var turn_speed: float = 13.0
@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_sensitivity: float = 2.2
@export var gamepad_deadzone: float = 0.18
@export var climb_forward_distance: float = 0.85
@export var climb_height: float = 1.55

@onready var camera_pivot: Node3D = $CameraPivot
@onready var player_camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var character_visual: Node3D = $Visual
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = -0.18
var _vehicle: VehicleController
var _jump_was_pressed := false
var _interaction_busy := false
var _climbing := false
var _climb_target := Vector3.ZERO
var _running := false

func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_log_connected_gamepads()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _log_connected_gamepads() -> void:
	for device in Input.get_connected_joypads():
		print("LIBREVILLE STORIES | manette : %s (ID %d)" % [Input.get_joy_name(device), device])

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	print("LIBREVILLE STORIES | manette %s (ID %d)" % ["connectée" if connected else "déconnectée", device])
	if connected:
		_jump_was_pressed = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _vehicle == null:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -0.85, 0.35)
		camera_pivot.rotation.x = camera_pitch
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("enter_exit_vehicle") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		if not _interaction_busy:
			_toggle_vehicle()

func _physics_process(delta: float) -> void:
	_update_gamepad_camera(delta)
	if _vehicle != null:
		global_position = _vehicle.global_position + Vector3.UP * 1.05
		velocity = Vector3.ZERO
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		var device := devices[0]
		var pad_move := _read_gamepad_move(device)
		if pad_move.length() > input_vector.length():
			input_vector = pad_move
		var jump_now := Input.is_joy_button_pressed(device, JOY_BUTTON_A)
		jump_pressed = jump_pressed or (jump_now and not _jump_was_pressed)
		_jump_was_pressed = jump_now
	else:
		_jump_was_pressed = false

	if _climbing:
		_process_climb(delta)
		return

	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var move_direction := (global_transform.basis * local_direction).normalized()
	_running = Input.is_action_pressed("sprint") or Input.is_action_pressed("ui_select")
	var target_speed := sprint_speed if _running else move_speed
	var control_rate := acceleration if is_on_floor() else air_control

	if jump_pressed:
		if is_on_floor():
			velocity.y = jump_velocity
		elif _try_start_climb():
			_process_climb(delta)
			return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if move_direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_direction.x * target_speed, control_rate * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * target_speed, control_rate * delta)
		var target_yaw := atan2(move_direction.x, move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(turn_speed * delta, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	move_and_slide()
	_update_character_animation()

func _try_start_climb() -> bool:
	var space := get_world_3d().direct_space_state
	var forward := -global_transform.basis.z
	var chest := global_position + Vector3.UP * 1.0
	var wall_query := PhysicsRayQueryParameters3D.create(chest, chest + forward * climb_forward_distance)
	wall_query.exclude = [self]
	var wall_hit := space.intersect_ray(wall_query)
	if wall_hit.is_empty():
		return false

	var top_start := global_position + Vector3.UP * (climb_height + 0.35) + forward * (climb_forward_distance + 0.12)
	var top_end := top_start - Vector3.UP * (climb_height + 0.75)
	var top_query := PhysicsRayQueryParameters3D.create(top_start, top_end)
	top_query.exclude = [self]
	var top_hit := space.intersect_ray(top_query)
	if top_hit.is_empty():
		return false
	var height_delta := float(top_hit.position.y) - global_position.y
	if height_delta < 0.35 or height_delta > climb_height:
		return false

	_climb_target = Vector3(top_hit.position.x, top_hit.position.y + 0.08, top_hit.position.z) + forward * 0.35
	_climbing = true
	velocity = Vector3.ZERO
	character_visual.call("play_motion", "jump")
	return true

func _process_climb(delta: float) -> void:
	var offset := _climb_target - global_position
	if offset.length() < 0.16:
		global_position = _climb_target
		velocity = Vector3.ZERO
		_climbing = false
		return
	velocity = offset.normalized() * minf(4.0, offset.length() * 7.0)
	move_and_slide()

func _update_character_animation() -> void:
	var state := "idle"
	if not is_on_floor() or _climbing:
		state = "jump"
	elif Vector2(velocity.x, velocity.z).length() > 0.25:
		state = "run" if _running else "walk"
	character_visual.call("play_motion", state)

func _read_gamepad_move(device: int) -> Vector2:
	var value := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	if value.length() < gamepad_deadzone:
		value = Vector2.ZERO
	else:
		value = value.normalized() * clampf((value.length() - gamepad_deadzone) / (1.0 - gamepad_deadzone), 0.0, 1.0)
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		value.x = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		value.x = 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		value.y = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		value.y = 1.0
	return value

func _toggle_vehicle() -> void:
	_interaction_busy = true
	if _vehicle != null:
		if absf(_vehicle.current_speed) > 1.2:
			print("LIBREVILLE STORIES | Arrête le véhicule avant de descendre.")
			_interaction_busy = false
			return
		var exiting_vehicle := _vehicle
		await exiting_vehicle.open_driver_door()
		var exit_side := -exiting_vehicle.global_transform.basis.x * 1.65
		var exit_position := exiting_vehicle.global_position + exit_side + Vector3.UP * 0.15
		exiting_vehicle.exit_vehicle()
		_vehicle = null
		global_position = exit_position
		visible = true
		player_camera.make_current()
		await get_tree().create_timer(0.35).timeout
		await exiting_vehicle.close_driver_door()
		_interaction_busy = false
		return

	var nearest: VehicleController
	var nearest_distance := 3.6
	for candidate in get_tree().get_nodes_in_group("drivable_vehicle"):
		if candidate is VehicleController:
			var distance := global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
	if nearest != null:
		await nearest.open_driver_door()
		_vehicle = nearest
		nearest.enter_vehicle()
		visible = false
		await get_tree().create_timer(0.3).timeout
		await nearest.close_driver_door()
		print("LIBREVILLE STORIES | Installation au volant terminée.")
	_interaction_busy = false

func _update_gamepad_camera(delta: float) -> void:
	if _vehicle != null:
		return
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		return
	var device := devices[0]
	var look_x := Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
	var look_y := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	if absf(look_x) < gamepad_deadzone:
		look_x = 0.0
	if absf(look_y) < gamepad_deadzone:
		look_y = 0.0
	rotate_y(-look_x * gamepad_look_sensitivity * delta)
	camera_pitch = clampf(camera_pitch - look_y * gamepad_look_sensitivity * delta, -0.85, 0.35)
	camera_pivot.rotation.x = camera_pitch
