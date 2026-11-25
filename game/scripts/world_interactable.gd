extends Node3D
## Contrat commun des objets interactifs du monde.
## Ajouter ce script à un Node3D parent qui possède un CollisionObject3D enfant.
## Les sous-classes redéfinissent interact(player) pour réaliser leur action.

@export var prompt_text: String = "E : interagir"

func _ready() -> void:
	add_to_group("world_interactables")

func get_interaction_prompt() -> String:
	return prompt_text

func interact(_player: Node) -> void:
	push_warning("LIBREVILLE STORIES | Objet interactif sans action définie : %s" % get_path())
