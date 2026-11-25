extends SceneTree
## Diagnostic CI : liste les clips GLB et compare les squelettes UAL1 / UAL2.

const CHARACTER_PATHS := [
	"res://assets/models/characters/UAL1_Standard.glb",
	"res://assets/models/characters/UAL2_Standard.glb",
]

func _initialize() -> void:
	call_deferred("_inspect_libraries")

func _inspect_libraries() -> void:
	var skeleton_bones: Dictionary = {}
	var failed := false
	for path in CHARACTER_PATHS:
		print("\n=== LIBREVILLE STORIES | Animation library: %s ===" % path)
		if not ResourceLoader.exists(path):
			push_error("Fichier GLB absent : %s" % path)
			failed = true
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Impossible de charger le GLB : %s" % path)
			failed = true
			continue
		var instance := packed.instantiate()
		var animation_player := _find_first_of_type(instance, "AnimationPlayer") as AnimationPlayer
		var skeleton := _find_first_of_type(instance, "Skeleton3D") as Skeleton3D
		if animation_player == null:
			push_error("AnimationPlayer absent dans %s" % path)
			failed = true
		else:
			var clips := animation_player.get_animation_list()
			print("CLIPS (%d) : %s" % [clips.size(), ", ".join(PackedStringArray(clips))])
			if clips.is_empty():
				failed = true
		if skeleton == null:
			push_error("Skeleton3D absent dans %s" % path)
			failed = true
		else:
			var bones: Array[String] = []
			for bone_index in range(skeleton.get_bone_count()):
				bones.append(String(skeleton.get_bone_name(bone_index)))
			skeleton_bones[path] = bones
			print("SQUELETTE : %d os" % bones.size())
			print("OS : %s" % ", ".join(bones))
		instance.free()
	if skeleton_bones.has(CHARACTER_PATHS[0]) and skeleton_bones.has(CHARACTER_PATHS[1]):
		var base_bones: Array = skeleton_bones[CHARACTER_PATHS[0]]
		var extra_bones: Array = skeleton_bones[CHARACTER_PATHS[1]]
		var same := base_bones == extra_bones
		print("\nCOMPARAISON UAL1 / UAL2 : %s" % ("IDENTIQUE" if same else "DIFFÉRENTE"))
		if not same:
			var missing_from_ual2: Array[String] = []
			var missing_from_ual1: Array[String] = []
			for bone in base_bones:
				if not extra_bones.has(bone):
					missing_from_ual2.append(bone)
			for bone in extra_bones:
				if not base_bones.has(bone):
					missing_from_ual1.append(bone)
			print("Absents UAL2 : %s" % ", ".join(missing_from_ual2))
			print("Absents UAL1 : %s" % ", ".join(missing_from_ual1))
	if failed:
		quit(1)
	else:
		print("\nDiagnostic des bibliothèques terminé.")
		quit(0)

func _find_first_of_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_first_of_type(child, type_name)
		if found != null:
			return found
	return null
