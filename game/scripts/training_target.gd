extends StaticBody3D
## Cible d'entraînement : reçoit les tirs hitscan du joueur.

@export var maximum_health: float = 100.0
var health: float
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color := Color(0.72, 0.22, 0.12)
var _health_label: Label3D

func _ready() -> void:
	add_to_group("damageables")
	health = maximum_health
	_mesh = get_node_or_null("TargetMesh") as MeshInstance3D
	if _mesh != null:
		_material = _mesh.material_override as StandardMaterial3D
	_health_label = Label3D.new()
	_health_label.name = "HealthLabel"
	_health_label.position = Vector3(0, 2.05, 0)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 48
	_health_label.pixel_size = 0.004
	add_child(_health_label)
	_update_health_label()
	print("LIBREVILLE STORIES | Cible d'entraînement prête (", health, " PV).")

func damage(hit_position: Vector3, impulse: Vector3) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - 34.0)
	_update_health_label()
	_show_hit_effect(hit_position, impulse)
	if _material != null:
		_material.albedo_color = Color(1.0, 0.82, 0.18)
		var tween := create_tween()
		tween.tween_property(_material, "albedo_color", _base_color, 0.18)
	print("LIBREVILLE STORIES | Cible touchée : %.0f / %.0f PV" % [health, maximum_health])
	if health <= 0.0:
		_disable_target()

func _show_hit_effect(hit_position: Vector3, impulse: Vector3) -> void:
	var impact := MeshInstance3D.new()
	impact.name = "ImpactFlash"
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	impact.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.58, 0.12)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.22, 0.025)
	glow.emission_energy_multiplier = 2.0
	impact.material_override = glow
	get_tree().current_scene.add_child(impact)
	impact.global_position = hit_position
	var direction := impulse.normalized()
	if direction.length_squared() > 0.01:
		impact.look_at(hit_position + direction, Vector3.UP)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", Vector3.ZERO, 0.18)
	tween.tween_property(glow, "albedo_color", Color(1.0, 0.58, 0.12, 0.0), 0.18)
	tween.chain().tween_callback(impact.queue_free)

func _disable_target() -> void:
	collision_layer = 0
	collision_mask = 0
	visible = false
	await get_tree().create_timer(2.0).timeout
	health = maximum_health
	_update_health_label()
	collision_layer = 1
	collision_mask = 1
	visible = true
	print("LIBREVILLE STORIES | Cible réinitialisée.")

func _update_health_label() -> void:
	if is_instance_valid(_health_label):
		_health_label.text = "CIBLE  |  %d / %d" % [roundi(health), roundi(maximum_health)]
