extends SceneTree
## Contrôle les GLB civils marqués "exported" ou "integrated" dans le manifest.
## Les recettes encore en attente d'export sont ignorées.

const MANIFEST_PATH := "res://data/characters/character_library.json"

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var raw := FileAccess.get_file_as_string(MANIFEST_PATH)
	if raw.is_empty():
		push_error("Manifest de personnages absent ou vide : " + MANIFEST_PATH)
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Manifest de personnages JSON invalide.")
		quit(1)
		return

	var entries: Array = parsed.get("starter_characters", [])
	var checked := 0
	var failed := false
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("Entrée de personnage invalide dans le manifest.")
			failed = true
			continue
		var status := str(entry.get("status", ""))
		if status != "exported" and status != "integrated":
			continue

		var relative_path := str(entry.get("output", ""))
		var resource_path := "res://" + relative_path
		print("\n=== NPC GLB : %s ===" % str(entry.get("id", "unknown")))
		if not ResourceLoader.exists(resource_path):
			push_error("GLB déclaré exporté mais absent : " + resource_path)
			failed = true
			continue

		var packed := load(resource_path) as PackedScene
		if packed == null:
			push_error("Impossible de charger le GLB : " + resource_path)
			failed = true
			continue

		var instance := packed.instantiate()
		var skeleton := _find_skeleton(instance)
		var animation_player := _find_animation_player(instance)
		if skeleton == null or skeleton.get_bone_count() <= 0:
			push_error("Squelette absent ou vide : " + resource_path)
			failed = true
		else:
			print("SQUELETTE : %d os" % skeleton.get_bone_count())

		if animation_player == null:
			push_error("AnimationPlayer absent : " + resource_path)
			failed = true
		else:
			var clips := animation_player.get_animation_list()
			print("ANIMATIONS : %s" % ", ".join(PackedStringArray(clips)))
			if not _has_idle_clip(clips):
				push_error("Animation idle introuvable : " + resource_path)
				failed = true
		instance.free()
		checked += 1

	if failed:
		print("\nÉCHEC : %d modèle(s) inspecté(s)." % checked)
		quit(1)
	else:
		print("\nContrôle GLB terminé : %d modèle(s) inspecté(s), recettes en attente ignorées." % checked)
		quit(0)

func _has_idle_clip(clips: Array[StringName]) -> bool:
	for clip in clips:
		if String(clip).to_lower().begins_with("idle"):
			return true
	return false

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
