extends Node
## Bibliothèque partagée de modèles civils GLB.
## Les modèles sont des gabarits visuels réutilisables : l'identité reste dans PopulationManager.

const MODEL_DIRS := [
	"res://assets/characters/library",
	"res://assets/characters/base"
]
const IDLE_NAMES := ["idle-loop", "Idle", "idle", "Idle_Loop", "mixamo.com"]

var model_paths: Array[String] = []
var _scene_cache: Dictionary = {}
var _rejected_paths: Array[String] = []

func _ready() -> void:
	reload_library()

func reload_library() -> void:
	model_paths.clear()
	_scene_cache.clear()
	_rejected_paths.clear()
	for directory_path in MODEL_DIRS:
		_scan_directory(directory_path)
	model_paths.sort()
	print(
		"NPC MODEL LIBRARY | %d modèle(s) GLB détecté(s) | %d rejeté(s)"
		% [model_paths.size(), _rejected_paths.size()]
	)

func _scan_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "glb":
			var full_path := directory_path.path_join(file_name)
			if not model_paths.has(full_path):
				model_paths.append(full_path)
		file_name = directory.get_next()
	directory.list_dir_end()

func get_model_path_for_resident(resident: Dictionary) -> String:
	if model_paths.is_empty():
		return ""
	var resident_id := str(resident.get("id", ""))
	if resident_id.is_empty():
		return ""
	var stable_index := posmod(hash(resident_id), model_paths.size())
	return model_paths[stable_index]

func instantiate_for_resident(resident: Dictionary) -> Node3D:
	var model_path := get_model_path_for_resident(resident)
	if model_path.is_empty():
		return null
	var packed := _get_validated_scene(model_path)
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.set_meta("resident_id", str(resident.get("id", "")))
	var animation_player := _find_animation_player(instance)
	var idle_name := _find_idle_animation(animation_player)
	if animation_player != null and not idle_name.is_empty():
		animation_player.play(idle_name)
	return instance

func _get_validated_scene(model_path: String) -> PackedScene:
	if _scene_cache.has(model_path):
		return _scene_cache[model_path] as PackedScene
	if _rejected_paths.has(model_path) or not ResourceLoader.exists(model_path):
		return null
	var packed := load(model_path) as PackedScene
	if packed == null:
		_rejected_paths.append(model_path)
		return null
	var instance := packed.instantiate()
	if instance == null or not (instance is Node3D):
		_rejected_paths.append(model_path)
		if instance != null:
			instance.free()
		return null
	var skeleton := _find_skeleton(instance)
	var animation_player := _find_animation_player(instance)
	var idle_name := _find_idle_animation(animation_player)
	var valid := (
		skeleton != null
		and skeleton.get_bone_count() > 0
		and animation_player != null
		and not idle_name.is_empty()
	)
	instance.free()
	if not valid:
		_rejected_paths.append(model_path)
		push_warning("NPC MODEL LIBRARY | Modèle ignoré (squelette/idle absent) : " + model_path)
		return null
	_scene_cache[model_path] = packed
	return packed

func _find_idle_animation(player: AnimationPlayer) -> StringName:
	if player == null:
		return &""
	var available := player.get_animation_list()
	for preferred_name in IDLE_NAMES:
		if available.has(preferred_name):
			return StringName(preferred_name)
	for animation_name in available:
		if String(animation_name).to_lower().begins_with("idle"):
			return animation_name
	return &""

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func get_library_stats() -> Dictionary:
	return {
		"detected": model_paths.size(),
		"rejected": _rejected_paths.size(),
		"loaded": _scene_cache.size()
	}
