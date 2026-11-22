extends CharacterBody3D

## Exploration à pied : stick gauche/ZQSD. Triangle ou F : entrer/sortir du véhicule.
## Dans le véhicule : stick gauche pour tourner, RT accélérer, LT freiner.

@export var move_speed: float = 8.5
@export var sprint_speed: float = 16.0
@export var jump_velocity: float = 5.2
@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_sensitivity: float = 2.2
@export var gamepad_deadzone: float = 0.18

@onready var camera_pivot: Node3D = $CameraPivot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = -0.18
var _vehicle: VehicleController

func _ready() -> void:
	_register_gamepad_inputs()
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
		_register_gamepad_inputs()

func _register_gamepad_inputs() -> void:
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("move_forward", JOY_BUTTON_DPAD_UP)
	_add_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("jump", JOY_BUTTON_A)

func _add_joy_axis(action: StringName, axis: int, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _add_joy_button(action: StringName, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -0.85, 0.35)
		camera_pivot.rotation.x = camera_pitch
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_toggle_vehicle()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		_toggle_vehicle()

func _physics_process(delta: float) -> void:
	if _vehicle != null:
		global_position = _vehicle.global_position + Vector3.UP * 1.5
		velocity = Vector3.ZERO
		_update_gamepad_camera(delta)
		return
	_update_gamepad_camera(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("ui_select")
	var current_speed := sprint_speed if sprinting else move_speed
	if move_direction.length() > 0.001:
		velocity.x = move_direction.x * current_speed
		velocity.z = move_direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, current_speed * 5.0 * delta)
	move_and_slide()

func _toggle_vehicle() -> void:
	if _vehicle != null:
		var exit_side := _vehicle.global_transform.basis.x * 2.2
		var exit_position := _vehicle.global_position + exit_side + Vector3.UP * 1.0
		_vehicle.exit_vehicle()
		_vehicle = null
		global_position = exit_position
		visible = true
		return
	var nearest: VehicleController
	var nearest_distance := 5.0
	for candidate in get_tree().get_nodes_in_group("drivable_vehicle"):
		if candidate is VehicleController:
			var distance := global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
	if nearest != null:
		_vehicle = nearest
		_vehicle.enter_vehicle()
		visible = false
		print("LIBREVILLE STORIES | véhicule pris en charge — RT accélérer, LT freiner, stick gauche diriger")

func _update_gamepad_camera(delta: float) -> void:
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
