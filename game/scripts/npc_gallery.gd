extends Node3D
## Galerie technique : affiche un échantillon stable de 100 habitants sauvegardés.

const CHARACTER_SCENE := preload("res://game/scenes/npc_character.tscn")
const SAMPLE_SIZE := 100
const COLUMNS := 10
const SPACING := 2.8

func _ready() -> void:
	var ids: Array = PopulationManager.residents.keys()
	ids.sort()
	var count := mini(SAMPLE_SIZE, ids.size())
	for index in range(count):
		var resident: Dictionary = PopulationManager.residents[ids[index]]
		var character := CHARACTER_SCENE.instantiate() as Node3D
		character.name = str(resident.get("id", "Resident"))
		character.set("position", Vector3(float(index % COLUMNS) * SPACING, 0.0, float(index / COLUMNS) * SPACING))
		add_child(character)
		character.call("configure", resident)
	print("NPC GALLERY | %d / %d personnages affichés" % [count, SAMPLE_SIZE])
