extends Node3D
## Charge le mannequin Quaternius (CC0) lorsqu'il est présent dans le projet.
## Un mannequin humanoïde léger sert de secours pour ne jamais afficher le tube bleu.

const MODEL_PATH := "res://assets/models/characters/UAL1_Standard.glb"

var animation_player: AnimationPlayer
var _fallback := false
var _last_motion := ""

func _ready() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var packed := load(MODEL_PATH) as PackedScene
		if packed != null:
			var model := packed.instantiate()
			model.name = "UAL1_Standard"
			add_child(model)
			animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if animation_player != null:
				animation_player.playback_default_blend_time = 0.18
				for loop_name in ["Idle", "Walk", "Jog_Fwd", "Sprint"]:
					if animation_player.has_animation(loop_name):
						animation_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
				play_motion("idle")
			return
	_build_fallback_humanoid()

func play_motion(state: String) -> void:
	if animation_player == null:
		return
	var animation_name := "Idle"
	match state:
		"walk":
			animation_name = "Walk"
		"run":
			animation_name = "Sprint" if animation_player.has_animation("Sprint") else "Jog_Fwd"
		"jump":
			animation_name = "Jump"
		_:
			animation_name = "Idle"
	if animation_player.has_animation(animation_name) and _last_motion != animation_name:
		_last_motion = animation_name
		animation_player.play(animation_name, 0.18)

func _build_fallback_humanoid() -> void:
	_fallback = true
	var jacket := _material(Color(0.12, 0.20, 0.30))
	var trousers := _material(Color(0.075, 0.09, 0.12))
	var skin := _material(Color(0.30, 0.17, 0.11))
	_add_capsule("Torso", Vector3(0, 1.12, 0), Vector3(0.48, 0.68, 0.28), jacket)
	_add_sphere("Head", Vector3(0, 1.92, 0), Vector3(0.24, 0.27, 0.23), skin)
	_add_capsule("LeftArm", Vector3(-0.34, 1.16, 0), Vector3(0.15, 0.52, 0.15), jacket, Vector3(0, 0, -0.12))
	_add_capsule("RightArm", Vector3(0.34, 1.16, 0), Vector3(0.15, 0.52, 0.15), jacket, Vector3(0, 0, 0.12))
	_add_capsule("LeftLeg", Vector3(-0.14, 0.48, 0), Vector3(0.17, 0.56, 0.18), trousers)
	_add_capsule("RightLeg", Vector3(0.14, 0.48, 0), Vector3(0.17, 0.56, 0.18), trousers)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material

func _add_capsule(node_name: String, at: Vector3, dimensions: Vector3, material: Material, tilt := Vector3.ZERO) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = dimensions.x
	mesh.height = dimensions.y * 2.0
	mesh_node.mesh = mesh
	mesh_node.position = at
	mesh_node.rotation = tilt
	mesh_node.material_override = material
	add_child(mesh_node)

func _add_sphere(node_name: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh_node.mesh = mesh
	mesh_node.scale = dimensions
	mesh_node.position = at
	mesh_node.material_override = material
	add_child(mesh_node)
