extends StaticBody3D
## Sac de ciment récupérable pour la première mission de manutention.

func _ready() -> void:
	add_to_group("world_interactables")

func get_interaction_prompt() -> String:
	return "E : prendre le sac de ciment"

func interact(_player: Node) -> void:
	var board := get_tree().get_first_node_in_group("work_mission_board")
	if board == null or not board.has_method("collect_cement_sack"):
		print("LIBREVILLE STORIES | Accepte d'abord la mission au tableau.")
		return
	board.call("collect_cement_sack", self)
