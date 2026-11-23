extends CharacterBody3D
class_name VehicleController
## Conduite arcade de la Jeep Wrangler : R2/RT accélère, L2/LT recule,
## stick gauche dirige. Les pivots de roues du GLB sont animés à partir
## de la distance réellement parcourue.

@export var acceleration: float = 30.0
@export var reverse_acceleration: float = 22.0
@export var max_speed: float = 44.0
@export var reverse_speed: float = 16.0
@export var brake_power: float = 42.0
@export var coast_deceleration: float = 2.6
@export var steering_speed: float = 1.45
@export var wheel_radius: float = 0.43
@export var front_wheel_steer_angle: float = 0.42
@export var gamepad_deadzone: float = 0.14

var player_driving := false
var current_speed := 0.0
var _wheel_nodes: Array[Node3D] = []
var _wheel_base_rotations: Array[Vector3] = []
var _wheel_is_front: Array[bool] = []
var _wheel_roll_angle := 0.0
var _steering_input := 0.0

func _ready() -> void:
	add_to_group("drivable_vehicle")
	var jeep := get_node_or_null("JeepModel")
	if jeep != null:
		_collect_wheel_nodes(jeep)
	if _wheel_nodes.is_empty():
		push_warning("Jeep : aucun pivot de roue identifiable dans le GLB ; vérifier les noms des roues.")

func _physics_process(delta: float) -> void:
	if not player_driving:
		velocity.x = move_toward(velocity.x, 0.0, brake_power * delta)
		velocity.z = move_toward(velocity.z, 0.0, brake_power * delta)
		if not is_on_floor():
			velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
		else:
			velocity.y = -0.2
		move_and_slide()
		return

	var steer := Input.get_axis("move_left", "move_right")
	var throttle := 0.0
	var reverse := 0.0
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		var device := devices[0]
		steer = Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if absf(steer) < gamepad_deadzone:
			steer = 0.0
		# Godot : gâchette gauche = axe 4, gâchette droite = axe 5.
		throttle = _read_trigger(device, JOY_AXIS_TRIGGER_RIGHT)
		reverse = _read_trigger(device, JOY_AXIS_TRIGGER_LEFT)

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		reverse = 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer = -1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer = 1.0

	_steering_input = clampf(steer, -1.0, 1.0)
	if throttle > 0.03 and reverse > 0.03:
		current_speed = move_toward(current_speed, 0.0, brake_power * maxf(throttle, reverse) * delta)
	elif throttle > 0.03:
		current_speed = move_toward(current_speed, max_speed, acceleration * throttle * delta)
	elif reverse > 0.03:
		current_speed = move_toward(current_speed, -reverse_speed, reverse_acceleration * reverse * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, coast_deceleration * delta)

	# Direction arcade : braquage progressif à basse vitesse, plus stable à haute vitesse.
	var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var steering_authority := clampf(absf(current_speed) / 5.0, 0.0, 1.0)
	steering_authority *= lerpf(1.0, 0.72, speed_ratio)
	var direction_sign := -1.0 if current_speed < -0.1 else 1.0
	rotate_y(-_steering_input * steering_speed * steering_authority * delta * direction_sign)

	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = -0.2

	var previous_position := global_position
	move_and_slide()
	var travelled := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z).length()
	if wheel_radius > 0.05 and absf(current_speed) > 0.05:
		_wheel_roll_angle -= signf(current_speed) * travelled / wheel_radius
	_update_wheel_animation()

func _read_trigger(device: int, axis: JoyAxis) -> float:
	var raw := Input.get_joy_axis(device, axis)
	# Selon le pilote, une gâchette au repos vaut -1 ou 0.
	if raw < -0.5:
		return clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	return clampf(raw, 0.0, 1.0)

func _collect_wheel_nodes(root: Node) -> void:
	for child in root.get_children():
		if child is Node3D:
			var wheel_name := child.name.to_lower()
			var is_wheel := wheel_name.contains("wheel") or wheel_name.contains("tire") or wheel_name.contains("tyre") or wheel_name.contains("roue") or wheel_name.contains("pneu")
			if is_wheel:
				_wheel_nodes.append(child as Node3D)
				_wheel_base_rotations.append((child as Node3D).rotation)
				_wheel_is_front.append(wheel_name.contains("front") or wheel_name.contains("avant") or wheel_name.contains("fl") or wheel_name.contains("fr"))
		_collect_wheel_nodes(child)

func _update_wheel_animation() -> void:
	for i in range(_wheel_nodes.size()):
		var steering_angle := 0.0
		if _wheel_is_front[i]:
			steering_angle = -_steering_input * front_wheel_steer_angle
		_wheel_nodes[i].rotation = _wheel_base_rotations[i] + Vector3(_wheel_roll_angle, steering_angle, 0.0)

func enter_vehicle() -> void:
	player_driving = true
	current_speed = 0.0

func exit_vehicle() -> void:
	player_driving = false
	current_speed = 0.0
	velocity = Vector3.ZERO
	_steering_input = 0.0
	_update_wheel_animation()
