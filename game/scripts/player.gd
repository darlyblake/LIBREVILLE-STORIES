extends CharacterBody3D

## Contrôles clavier/souris et manettes reconnues par Godot.
## ZQSD/WASD : déplacement | Espace/A : saut | souris ou stick droit : caméra

@export var move_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025

@onready var camera_pivot: Node3D = $CameraPivot

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = -0.18
@export var gamepad_look_sensitivity: float = 2.2
@export var gamepad_deadzone: float = 0.18

func _ready() -> void:
	_register_gamepad_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _register_gamepad_inputs() -> void:
	# Conserve le clavier et ajoute les axes analogiques et la croix directionnelle.
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("move_forward", JOY_BUTTON_DPAD_UP)
	_add_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("jump", JOY_BUTTON_A)
	print("LIBREVILLE STORIES | manettes détectées : %d" % Input.get_connected_joypads().size())


func _add_joy_axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_joy_button(action: StringName, button: JoyButton) -> void:
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

func _physics_process(delta: float) -> void:
	_update_gamepad_camera(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()

	if move_direction.length() > 0.001:
		velocity.x = move_direction.x * move_speed
		velocity.z = move_direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)

	move_and_slide()


func _update_gamepad_camera(delta: float) -> void:
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		return
	# Le stick droit pilote la caméra ; la zone morte évite les mouvements fantômes.
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
