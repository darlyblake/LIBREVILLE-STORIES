extends Node
## Applique un film humide non destructif aux matériaux StandardMaterial3D du monde.
## Les matériaux originaux restent inchangés : chaque instance reçoit sa copie.

@export var scan_interval: float = 2.5
@export var wet_transition_speed: float = 0.22

var _scan_timer := 0.0
var _wetness := 0.0
var _target_wetness := 0.0
var _tracked: Dictionary = {}


func _ready() -> void:
	var weather := get_node_or_null("/root/WeatherManager")
	if weather != null:
		if weather.has_signal("weather_changed"):
			weather.weather_changed.connect(_on_weather_changed)
		if weather.has_method("get_weather_state"):
			_on_weather_changed(weather.call("get_weather_state"))
	_scan_world()


func _process(delta: float) -> void:
	_wetness = move_toward(_wetness, _target_wetness, wet_transition_speed * delta)
	_apply_wetness()
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		_scan_world()


func _on_weather_changed(state: Dictionary) -> void:
	_target_wetness = clampf(float(state.get("rain_intensity", 0.0)), 0.0, 1.0)


func _scan_world() -> void:
	_scan_node(get_tree().current_scene)


func _scan_node(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		_track_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_scan_node(child)


func _track_mesh(mesh_instance: MeshInstance3D) -> void:
	var instance_id := mesh_instance.get_instance_id()
	if _tracked.has(instance_id) or mesh_instance.mesh == null:
		return
	var entries: Array[Dictionary] = []
	var override_material := mesh_instance.material_override
	if override_material is StandardMaterial3D:
		var copy := (override_material as StandardMaterial3D).duplicate() as StandardMaterial3D
		mesh_instance.material_override = copy
		entries.append(_make_entry(copy))
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source := mesh_instance.get_active_material(surface_index)
		if source is StandardMaterial3D and source != mesh_instance.material_override:
			var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			mesh_instance.set_surface_override_material(surface_index, copy)
			entries.append(_make_entry(copy))
	if not entries.is_empty():
		_tracked[instance_id] = {"node": weakref(mesh_instance), "entries": entries}


func _make_entry(material: StandardMaterial3D) -> Dictionary:
	return {
		"material": material,
		"roughness": material.roughness,
		"color": material.albedo_color
	}


func _apply_wetness() -> void:
	for instance_id in _tracked.keys():
		var record: Dictionary = _tracked[instance_id]
		var reference: WeakRef = record.node
		if reference.get_ref() == null:
			_tracked.erase(instance_id)
			continue
		for entry in record.entries:
			var material := entry.material as StandardMaterial3D
			if not is_instance_valid(material):
				continue
			var base_roughness := float(entry.roughness)
			var base_color: Color = entry.color
			material.roughness = lerpf(base_roughness, minf(base_roughness, 0.28), _wetness)
			var darken := 1.0 - 0.07 * _wetness
			material.albedo_color = Color(base_color.r * darken, base_color.g * darken, base_color.b * darken, base_color.a)
