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
var _target_fog_density: float = 0.0
var _last_hour: int = -1
var _weather_cloud_cover: float = 0.0
var _weather_rain_intensity: float = 0.0

func _ready() -> void:
	var scene_root := get_parent()
	_world_environment = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = scene_root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _world_environment == null or _sun == null:
		push_warning("WorldLighting : WorldEnvironment ou DirectionalLight3D introuvable.")
		set_process(false)
		return
	var weather_manager := get_node_or_null("/root/WeatherManager")
	if weather_manager != null:
		if not weather_manager.weather_changed.is_connected(_on_weather_changed):
			weather_manager.weather_changed.connect(_on_weather_changed)
		if weather_manager.has_method("get_weather_state"):
			_on_weather_changed(weather_manager.call("get_weather_state"))
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
	_apply_weather_to_targets()
	if _sun != null:
		_sun.rotation_degrees.x = (h - 6.0) * 15.0 - 90.0


func _on_weather_changed(state: Dictionary) -> void:
	_weather_cloud_cover = clampf(float(state.get("cloud_cover", 0.0)), 0.0, 1.0)
	_weather_rain_intensity = clampf(float(state.get("rain_intensity", 0.0)), 0.0, 1.0)
	_update_targets()

func _apply_weather_to_targets() -> void:
	# Les nuages et les averses atténuent la lumière directe sans éteindre le jour.
	var cloud_dim := _weather_cloud_cover * 0.34
	var rain_dim := _weather_rain_intensity * 0.18
	_target_energy *= 1.0 - cloud_dim - rain_dim
	_target_ambient *= 1.0 - _weather_cloud_cover * 0.16
	_target_fog_density = 0.00015 + _weather_cloud_cover * 0.00035 + _weather_rain_intensity * 0.0010
	var overcast := Color(0.48, 0.55, 0.60)
	_target_color = _target_color.lerp(overcast, _weather_cloud_cover * 0.42)
	_target_sun_color = _target_sun_color.lerp(Color(0.68, 0.73, 0.78), _weather_cloud_cover * 0.58)

func _apply_immediately() -> void:
	if _sun == null or _world_environment == null:
		return
	_sun.light_energy = _target_energy
	_sun.light_color = _target_sun_color
	if _world_environment.environment != null:
		_world_environment.environment.ambient_light_energy = _target_ambient
		_world_environment.environment.background_color = _target_color
		_world_environment.environment.fog_light_color = _target_color.darkened(0.18)
		_world_environment.environment.fog_enabled = _target_fog_density > 0.0001
		_world_environment.environment.fog_density = _target_fog_density
		if _target_fog_density > 0.0001:
			_world_environment.environment.fog_depth_begin = 45.0
			_world_environment.environment.fog_depth_end = 260.0
