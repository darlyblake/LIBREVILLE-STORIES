extends Node3D
## Galerie technique : affiche un échantillon stable de résidents.
## Un GLB n'est utilisé que s'il possède un squelette et une animation idle.

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
var rejected_glb_count: int = 0

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

	print(
		"NPC GALLERY | %d / %d affichés | GLB valides : %d | prototype : %d | GLB rejetés : %d"
		% [count, SAMPLE_SIZE, glb_count, fallback_count, rejected_glb_count]
	)

func _create_character(resident: Dictionary) -> Node3D:
	var character := NPCModelLibrary.instantiate_for_resident(resident)
	if character != null:
		glb_count += 1
		return character

	fallback_count += 1
	var fallback := FALLBACK_SCENE.instantiate() as Node3D
	if fallback != null:
		fallback.call("configure", resident)
	return fallback

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
