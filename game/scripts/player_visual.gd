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
				for animation in animation_player.get_animation_list():
					var lower_name := String(animation).to_lower()
					if lower_name.contains("idle") or lower_name.contains("walk") or lower_name.contains("run") or lower_name.contains("jog") or lower_name.contains("sprint") or lower_name.contains("pistol_aim") or lower_name == "jump_loop":
						animation_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
				print("LIBREVILLE STORIES | Animations disponibles : ", animation_player.get_animation_list())
				play_motion("idle")
			_create_test_pistol(model)
			return
	_build_fallback_humanoid()
	_create_test_pistol(self)

func play_motion(state: String) -> void:
	if animation_player == null:
		return
	var animation_name := _resolve_animation(state)
	if animation_name.is_empty() or _last_motion == animation_name:
		return
	_last_motion = animation_name
	animation_player.play(animation_name, 0.16)

func _resolve_animation(state: String) -> StringName:
	var aliases := {
		"idle": ["idle_loop", "idle", "stand", "breathing"],
		"walk": ["walk_loop", "walk_fwd_loop", "walk", "walking"],
		"run": ["sprint_loop", "sprint", "jog_fwd_loop", "jog_fwd", "run", "jog"],
		"jump": ["jump_start", "jump"],
		"jump_loop": ["jump_loop", "jump"],
		"aim": ["pistol_aim_neutral", "pistol_aim", "aim", "pistol_idle_loop", "rifle_idle", "shoot_idle"],
		"aim_walk": ["walk_loop", "walk_fwd_loop", "walk"],
		"shoot": ["pistol_shoot", "shoot", "fire", "attack", "pistol_fire", "rifle_fire"],
		"reload": ["pistol_reload", "reload"],
		"climb": ["climb", "climbup", "safetyvault", "stepup", "jump_loop", "jump"],
		"fall": ["jump_loop", "fall", "falling", "air"],
		"land": ["jump_land", "land", "landing"],
	}
	var candidates: Array = aliases.get(state, aliases["idle"])
	var names := animation_player.get_animation_list()
	for candidate in candidates:
		for animation in names:
			if String(animation).to_lower() == String(candidate):
				return animation
	for candidate in candidates:
		for animation in names:
			if String(animation).to_lower().contains(String(candidate)):
				return animation
	return &""

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

func _create_test_pistol(model: Node3D) -> void:
	# Arme provisoire de test : attachée à l'os de la main droite si le squelette le fournit.
	var attachment: Node3D = model
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := String(skeleton.get_bone_name(bone_index)).to_lower()
			var right_hand := bone_name.contains("hand") and (
				bone_name.contains("right") or bone_name.ends_with(".r")
				or bone_name.ends_with("_r") or bone_name.contains("handr")
			)
			if right_hand:
				var bone_attachment := BoneAttachment3D.new()
				bone_attachment.name = "RightHandWeaponAttachment"
				bone_attachment.bone_name = skeleton.get_bone_name(bone_index)
				skeleton.add_child(bone_attachment)
				attachment = bone_attachment
				print("LIBREVILLE STORIES | Pistolet attaché à l'os : ", bone_name)
				break
	if attachment == model:
		print("LIBREVILLE STORIES | Os de main droite non détecté : arme de test positionnée provisoirement sur le modèle.")
	var pistol := Node3D.new()
	pistol.name = "TestPistol"
	attachment.add_child(pistol)
	if attachment == model:
		pistol.position = Vector3(0.34, 1.18, -0.24)
		pistol.rotation.y = PI
	else:
		pistol.position = Vector3(0.035, 0.015, -0.055)
		pistol.rotation = Vector3(deg_to_rad(-8.0), PI, deg_to_rad(2.0))
	pistol.scale = Vector3.ONE * 0.72
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.055, 0.065, 0.075)
	metal.metallic = 0.72
	metal.roughness = 0.34
	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color(0.12, 0.095, 0.07)
	grip_material.roughness = 0.82
	_add_pistol_box(pistol, "Slide", Vector3(0.0, 0.025, -0.045), Vector3(0.105, 0.105, 0.29), metal)
	_add_pistol_box(pistol, "Grip", Vector3(0.0, -0.105, 0.045), Vector3(0.085, 0.19, 0.105), grip_material, Vector3(deg_to_rad(-12.0), 0.0, 0.0))
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.026
	barrel_mesh.bottom_radius = 0.026
	barrel_mesh.height = 0.13
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0.0, 0.025, -0.235)
	barrel.material_override = metal
	pistol.add_child(barrel)

func _add_pistol_box(parent: Node3D, node_name: String, at: Vector3, dimensions: Vector3, material: Material, tilt := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.rotation = tilt
	part.material_override = material
	parent.add_child(part)
