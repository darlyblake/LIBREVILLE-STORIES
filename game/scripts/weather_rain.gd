extends Node3D
## Pluie locale légère, centrée sur la caméra active pour suivre le joueur.

@export_range(80, 500, 20) var max_particle_count: int = 260
@export var follow_height: float = 7.0
@export var follow_ahead: float = 5.0

var _particles: CPUParticles3D
var _process_material: ParticleProcessMaterial
var _weather_manager: Node
var _rain_intensity: float = 0.0
var _wind_strength: float = 0.2
var _camera: Camera3D


func _ready() -> void:
	_weather_manager = get_node_or_null("/root/WeatherManager")
	if _weather_manager != null:
		if _weather_manager.has_signal("weather_changed"):
			_weather_manager.weather_changed.connect(_on_weather_changed)
		if _weather_manager.has_method("get_weather_state"):
			_on_weather_changed(_weather_manager.call("get_weather_state"))
	_create_particles()


func _process(_delta: float) -> void:
	if not is_instance_valid(_camera) or not _camera.is_current():
		_camera = get_viewport().get_camera_3d()
	if is_instance_valid(_camera) and is_instance_valid(_particles):
		var forward := -_camera.global_transform.basis.z
		_particles.global_position = _camera.global_position + Vector3.UP * follow_height + forward * follow_ahead


func _create_particles() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "RainParticles"
	_particles.amount = max_particle_count
	_particles.lifetime = 1.35
	_particles.explosiveness = 0.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(22.0, 7.0, 22.0)
	_particles.local_coords = false
	_particles.emitting = false
	_process_material = ParticleProcessMaterial.new()
	_process_material.direction = Vector3(0.0, -1.0, 0.0)
	_process_material.spread = 3.0
	_process_material.initial_velocity_min = 17.0
	_process_material.initial_velocity_max = 22.0
	_process_material.gravity = Vector3(0.0, -1.5, 0.0)
	_process_material.scale_min = 0.8
	_process_material.scale_max = 1.15
	_particles.process_material = _process_material

	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.48)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.68, 0.79, 0.88, 0.48)
	streak_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	streak_material.no_depth_test = false
	streak.material = streak_material
	_particles.draw_pass_1 = streak
	add_child(_particles)


func _on_weather_changed(state: Dictionary) -> void:
	_rain_intensity = clampf(float(state.get("rain_intensity", 0.0)), 0.0, 1.0)
	_wind_strength = clampf(float(state.get("wind_strength", 0.2)), 0.0, 1.0)
	if not is_instance_valid(_particles):
		return
	_particles.amount_ratio = lerpf(0.0, 1.0, _rain_intensity)
	_particles.emitting = _rain_intensity > 0.04
	if is_instance_valid(_process_material):
		_process_material.gravity = Vector3(_wind_strength * 2.4, -1.5, _wind_strength * 0.8)
