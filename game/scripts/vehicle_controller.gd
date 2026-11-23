extends CharacterBody3D
class_name VehicleController
## Conduite arcade de la Jeep Wrangler : stick gauche pour diriger,
## gâchette R2/RT pour avancer et gâchette L2/LT pour reculer.

@export var acceleration: float = 18.0
@export var reverse_acceleration: float = 12.0
@export var max_speed: float = 27.0
@export var reverse_speed: float = 10.0
@export var brake_power: float = 30.0
@export var steering_speed: float = 1.65
@export var gamepad_deadzone: float = 0.16

var player_driving := false
var current_speed := 0.0

func _ready() -> void:
	add_to_group("drivable_vehicle")

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
		# Xbox standard : RT/R2 = axe 5, LT/L2 = axe 4.
		# Certains pilotes renvoient -1..1 (repos=-1), d'autres 0..1.
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

	if throttle > 0.03 and reverse > 0.03:
		current_speed = move_toward(current_speed, 0.0, brake_power * maxf(throttle, reverse) * delta)
	elif throttle > 0.03:
		current_speed = move_toward(current_speed, max_speed, acceleration * throttle * delta)
	elif reverse > 0.03:
		current_speed = move_toward(current_speed, -reverse_speed, reverse_acceleration * reverse * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, 3.5 * delta)

	var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var direction_sign := -1.0 if current_speed < -0.1 else 1.0
	rotate_y(-steer * steering_speed * maxf(speed_ratio, 0.12) * delta * direction_sign)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = -0.2
	move_and_slide()

func _read_trigger(device: int, axis: JoyAxis) -> float:
	var raw := Input.get_joy_axis(device, axis)
	if raw < -0.5:
		return clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	return clampf(raw, 0.0, 1.0)

func enter_vehicle() -> void:
	player_driving = true
	current_speed = 0.0

func exit_vehicle() -> void:
	player_driving = false
	current_speed = 0.0
	velocity = Vector3.ZERO
