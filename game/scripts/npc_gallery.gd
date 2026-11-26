extends Node3D
## Galerie technique : affiche un échantillon stable de résidents.
## Utilise les modèles GLB validés lorsqu'ils existent, sinon le prototype procédural.

const FALLBACK_SCENE := preload("res://game/scenes/npc_character.tscn")
const SAMPLE_SIZE := 100
const COLUMNS := 10
const SPACING := 2.8
const MODEL_BY_GENDER := {
	"homme": "res://assets/characters/base/civilian_male_01.glb",
	"femme": "res://assets/characters/base/civilian_female_01.glb"
}
const IDLE_NAMES := ["idle-loop", "Idle", "idle", "Idle_Loop", "mixamo.com"]

var glb_count: int = 0
var fallback_count: int = 0

func _ready() -> void:
	if not is_instance_valid(PopulationManager):
		push_error("NPC GALLERY | PopulationManager indisponible.")
		return

	var ids: Array = PopulationManager.residents.keys()
	ids.sort()
	var count := mini(SAMPLE_SIZE, ids.size())

	for index in range(count):
		var resident: Dictionary = PopulationManager.residents[ids[index]]
		var character := _create_character(resident)
		if character == null:
			continue
		character.name = str(resident.get("id", "Resident"))
		character.position = Vector3(
			float(index % COLUMNS) * SPACING,
			0.0,
			float(index / COLUMNS) * SPACING
		)
		add_child(character)
		_play_idle_if_available(character)

	print(
		"NPC GALLERY | %d / %d affichés | GLB : %d | prototype : %d"
		% [count, SAMPLE_SIZE, glb_count, fallback_count]
	)

func _create_character(resident: Dictionary) -> Node3D:
	var gender := str(resident.get("gender", "homme"))
	var model_path := str(MODEL_BY_GENDER.get(gender, ""))
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed != null:
			var instance := packed.instantiate() as Node3D
			if instance != null:
				glb_count += 1
				instance.set_meta("resident_id", str(resident.get("id", "")))
				return instance
			push_warning("NPC GALLERY | La scène GLB doit avoir une racine Node3D : " + model_path)

	fallback_count += 1
	var fallback := FALLBACK_SCENE.instantiate() as Node3D
	if fallback != null:
		fallback.call("configure", resident)
	return fallback

func _play_idle_if_available(root: Node) -> void:
	var player := _find_animation_player(root)
	if player == null:
		return
	var available := player.get_animation_list()
	for preferred_name in IDLE_NAMES:
		if available.has(preferred_name):
			player.play(preferred_name)
			return
	for animation_name in available:
		if String(animation_name).to_lower().begins_with("idle"):
			player.play(animation_name)
			return

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
