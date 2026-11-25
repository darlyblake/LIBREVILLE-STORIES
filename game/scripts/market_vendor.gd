extends Node3D
## Vendeur fictif du marché Mont-Bouët : animation légère et dialogue contextuel.

@export var vendor_index: int = 0

var _dialog: AcceptDialog
var _elapsed := 0.0
var _talk_time := 0.0
var _left_arm: Node3D
var _right_arm: Node3D
var _head: Node3D
var _torso: Node3D


func _ready() -> void:
	add_to_group("world_interactables")
	_left_arm = get_node_or_null("BrasGauchePivot") as Node3D
	_right_arm = get_node_or_null("BrasDroitPivot") as Node3D
	_head = get_node_or_null("TetePivot") as Node3D
	_torso = get_node_or_null("TorsoPivot") as Node3D
	_dialog = AcceptDialog.new()
	_dialog.name = "DialogueVendeur"
	_dialog.title = "Marché Mont-Bouët"
	_dialog.dialog_text = _dialogue_for_vendor()
	_dialog.min_size = Vector2i(420, 150)
	add_child(_dialog)


func _process(delta: float) -> void:
	_elapsed += delta
	_talk_time = maxf(0.0, _talk_time - delta)
	var idle_sway := sin(_elapsed * 1.7 + float(vendor_index)) * 0.035
	if is_instance_valid(_torso):
		_torso.rotation.z = idle_sway
	if is_instance_valid(_head):
		_head.rotation.y = sin(_elapsed * 0.8 + float(vendor_index)) * 0.10
	if is_instance_valid(_left_arm):
		_left_arm.rotation.x = -0.10 + sin(_elapsed * 1.4 + float(vendor_index)) * 0.045
	if is_instance_valid(_right_arm):
		var gesture := sin(_elapsed * 1.8 + float(vendor_index)) * 0.06
		if _talk_time > 0.0:
			gesture += sin(_elapsed * 8.0) * 0.28
		_right_arm.rotation.x = -0.12 + gesture


func get_interaction_prompt() -> String:
	return "E : discuter avec le vendeur"


func interact(_player: Node) -> void:
	if not is_instance_valid(_dialog):
		return
	_talk_time = 3.5
	_dialog.dialog_text = _dialogue_for_vendor()
	_dialog.popup_centered()


func _dialogue_for_vendor() -> String:
	var lines: Array[String] = [
		"Bonjour mon frère ! Les fruits sont arrivés tôt ce matin. Tu cherches quelque chose de précis ?",
		"Ça va aller ! Ici, prends le temps de comparer les prix et de regarder la marchandise.",
		"Le marché est déjà animé aujourd'hui. Fais attention aux motos et aux voitures quand tu traverses.",
		"Bienvenue à Mont-Bouët ! Si tu cherches du travail, renseigne-toi auprès des commerçants du coin.",
		"Il fait chaud aujourd'hui ! N'hésite pas à faire un tour dans les allées, il y a plusieurs étals.",
		"On reçoit des produits de plusieurs quartiers. La journée commence tôt ici, surtout les jours de marché."
	]
	return lines[posmod(vendor_index / 3, lines.size())]
