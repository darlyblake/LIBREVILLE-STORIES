extends CharacterBody3D
class_name VehicleController
## Véhicule provisoire procédural. Remplacer son visuel par un GLB quand le modèle est choisi.

@export var acceleration := 22.0
@export var reverse_acceleration := 10.0
@export var max_speed := 34.0
@export var reverse_speed := 12.0
@export var brake_power := 38.0
@export var steering_speed := 1.65
@export var gamepad_deadzone := 0.16

var player_driving := false
var current_speed := 0.0
var _wheels: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("drivable_vehicle")
	_build_procedural_car()

func _physics_process(delta: float) -> void:
	if not player_driving:
		velocity = velocity.move_toward(Vector3.ZERO, brake_power * delta)
		move_and_slide()
		return
	var devices := Input.get_connected_joypads()
	var steer := Input.get_axis("move_left", "move_right")
	var throttle := 0.0
	var brake := 0.0
	if not devices.is_empty():
		var device := devices[0]
		steer = Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if absf(steer) < gamepad_deadzone:
			steer = 0.0
		# Sur les manettes standard Godot, les gâchettes vont de -1 (relâchée) à +1.
		throttle = maxf(0.0, (Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) + 1.0) * 0.5)
		brake = maxf(0.0, (Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) + 1.0) * 0.5)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		brake = 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer = -1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer = 1.0
	if brake > 0.05:
		current_speed = move_toward(current_speed, 0.0, brake_power * brake * delta)
	elif throttle > 0.02:
		current_speed = move_toward(current_speed, max_speed, acceleration * throttle * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, 5.0 * delta)
	if current_speed < -0.1:
		current_speed = maxf(current_speed, -reverse_speed)
	var speed_ratio := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	rotate_y(-steer * steering_speed * speed_ratio * delta * signf(current_speed if absf(current_speed) > 0.1 else 1.0))
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	for wheel in _wheels:
		wheel.rotate_x(-current_speed * delta / 0.42)

func enter_vehicle() -> void:
	player_driving = true

func exit_vehicle() -> void:
	player_driving = false
	current_speed = 0.0
	velocity = Vector3.ZERO

func _build_procedural_car() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.12, 0.32, 0.68)
	paint.metallic = 0.55
	paint.roughness = 0.28
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.07, 0.13, 0.18)
	glass.metallic = 0.25
	glass.roughness = 0.16
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.025, 0.025, 0.028)
	var body := _box("CarBody", Vector3(1.9, 0.55, 4.0), Vector3(0, 0.72, 0), paint)
	var cabin := _box("Cabin", Vector3(1.55, 0.68, 1.9), Vector3(0, 1.28, -0.15), glass)
	_box("Bonnet", Vector3(1.72, 0.22, 1.0), Vector3(0, 1.02, -1.35), paint)
	_box("Rear", Vector3(1.72, 0.22, 0.75), Vector3(0, 1.02, 1.45), paint)
	for x in [-0.98, 0.98]:
		for z in [-1.28, 1.28]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.42
			mesh.bottom_radius = 0.42
			mesh.height = 0.24
			mesh.radial_segments = 16
			wheel.mesh = mesh
			wheel.material_override = rubber
			wheel.position = Vector3(x, 0.42, z)
			wheel.rotation.z = PI * 0.5
			add_child(wheel)
			_wheels.append(wheel)
	_box("Headlights", Vector3(1.25, 0.12, 0.08), Vector3(0, 0.85, -2.02), _make_color(Color(1.0, 0.92, 0.68)))
	_box("Taillights", Vector3(1.25, 0.12, 0.08), Vector3(0, 0.85, 2.02), _make_color(Color(0.72, 0.04, 0.025)))

func _box(label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node

func _make_color(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.45
	return material
