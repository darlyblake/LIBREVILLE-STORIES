extends Node
## Pilote l'éclairage de la scène selon l'heure du calendrier central.

@export var transition_speed: float = 1.8
@export var daylight_energy: float = 1.05
@export var night_energy: float = 0.10

var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _target_energy: float = 1.0
var _target_ambient: float = 0.7
var _target_color: Color = Color.WHITE
var _target_sun_color: Color = Color.WHITE
var _last_hour: int = -1

func _ready() -> void:
	var scene_root := get_parent()
	_world_environment = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = scene_root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _world_environment == null or _sun == null:
		push_warning("WorldLighting : WorldEnvironment ou DirectionalLight3D introuvable.")
		set_process(false)
		return
	_update_targets()
	_apply_immediately()

func _process(delta: float) -> void:
	if not is_instance_valid(_sun) or not is_instance_valid(_world_environment):
		return
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null:
		return
	var current_hour := int(clock.hour)
	if current_hour != _last_hour:
		_update_targets()
	var weight := clampf(delta * transition_speed, 0.0, 1.0)
	_sun.light_energy = lerpf(_sun.light_energy, _target_energy, weight)
	_sun.light_color = _sun.light_color.lerp(_target_sun_color, weight)
	var environment := _world_environment.environment
	if environment != null:
		environment.ambient_light_energy = lerpf(environment.ambient_light_energy, _target_ambient, weight)
		environment.background_color = environment.background_color.lerp(_target_color, weight)
		environment.fog_light_color = environment.fog_light_color.lerp(_target_color.darkened(0.18), weight)

func _update_targets() -> void:
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null:
		return
	_last_hour = int(clock.hour)
	var h := float(clock.hour) + float(clock.minute) / 60.0
	var daylight := clampf(sin((h - 6.0) * PI / 12.0), 0.0, 1.0)
	_target_energy = lerpf(night_energy, daylight_energy, daylight)
	_target_ambient = lerpf(0.16, 0.78, daylight)
	var night_color := Color(0.055, 0.085, 0.16)
	var dawn_color := Color(0.95, 0.48, 0.30)
	var noon_color := Color(0.62, 0.76, 0.88)
	if h >= 5.0 and h < 8.0:
		_target_color = night_color.lerp(dawn_color, clampf((h - 5.0) / 3.0, 0.0, 1.0))
	elif h >= 8.0 and h < 17.0:
		_target_color = noon_color
	elif h >= 17.0 and h < 20.0:
		_target_color = noon_color.lerp(dawn_color, clampf((h - 17.0) / 3.0, 0.0, 1.0))
	else:
		_target_color = night_color
	_target_sun_color = Color(1.0, 0.72, 0.50).lerp(Color(1.0, 0.96, 0.86), daylight)
	if _sun != null:
		_sun.rotation_degrees.x = (h - 6.0) * 15.0 - 90.0

func _apply_immediately() -> void:
	if _sun == null or _world_environment == null:
		return
	_sun.light_energy = _target_energy
	_sun.light_color = _target_sun_color
	if _world_environment.environment != null:
		_world_environment.environment.ambient_light_energy = _target_ambient
		_world_environment.environment.background_color = _target_color
		_world_environment.environment.fog_light_color = _target_color.darkened(0.18)
