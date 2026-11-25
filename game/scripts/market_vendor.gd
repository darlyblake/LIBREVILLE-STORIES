extends Node3D
## Vendeur fictif du marché Mont-Bouët : dialogue local léger, sans économie simulée.

@export var vendor_index: int = 0

var _dialog: AcceptDialog


func _ready() -> void:
	add_to_group("world_interactables")
	_dialog = AcceptDialog.new()
	_dialog.name = "DialogueVendeur"
	_dialog.title = "Marché Mont-Bouët"
	_dialog.dialog_text = _dialogue_for_vendor()
	add_child(_dialog)


func get_interaction_prompt() -> String:
	return "E : discuter avec le vendeur"


func interact(_player: Node) -> void:
	if is_instance_valid(_dialog):
		_dialog.dialog_text = _dialogue_for_vendor()
		_dialog.popup_centered()


func _dialogue_for_vendor() -> String:
	var lines: Array[String] = [
		"Bonjour mon frère ! Les fruits sont arrivés tôt ce matin. Tu cherches quelque chose de précis ?",
		"Ça va aller ! Ici, il faut comparer les prix et bien regarder la marchandise avant d'acheter.",
		"Le marché est déjà animé aujourd'hui. Fais attention aux motos et aux voitures quand tu traverses.",
		"Bienvenue à Mont-Bouët ! Si tu veux travailler, renseigne-toi auprès des commerçants du coin."
	]
	return lines[posmod(vendor_index / 3, lines.size())]
