extends StaticBody3D
## Tableau des petits boulots : accepte et suit la première mission de manutention.

@export var interaction_prompt := "E : consulter les offres du chantier"

var _panel: PanelContainer
var _message: Label
var _accept_button: Button
var _mission_active := false
var _mission_completed := false
var _collected_sacks := 0
const REQUIRED_SACKS := 3

func _ready() -> void:
	add_to_group("world_interactables")
	add_to_group("work_mission_board")
	_build_notice_ui()
	_build_board_sign()

func _build_board_sign() -> void:
	var sign_label := Label3D.new()
	sign_label.name = "BoardSign"
	sign_label.text = "OFFRES\nCHANTIER"
	sign_label.position = Vector3(0.0, 1.45, -0.071)
	sign_label.font_size = 64
	sign_label.pixel_size = 0.0045
	sign_label.modulate = Color(1.0, 0.88, 0.58)
	sign_label.outline_size = 8
	sign_label.outline_modulate = Color(0.08, 0.055, 0.035)
	add_child(sign_label)

func get_interaction_prompt() -> String:
	return interaction_prompt

func interact(_player: Node) -> void:
	if not is_instance_valid(_panel):
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_mission_text()
		print("LIBREVILLE STORIES | Consultation du tableau des offres.")

func _accept_offer() -> void:
	if _mission_active or _mission_completed:
		return
	_mission_active = true
	_refresh_mission_text()
	print("LIBREVILLE STORIES | Mission acceptée : manutention au chantier.")

func collect_cement_sack(sack: Node) -> void:
	if not _mission_active or _mission_completed or not is_instance_valid(sack):
		return
	_collected_sacks += 1
	sack.queue_free()
	if _collected_sacks >= REQUIRED_SACKS:
		_mission_completed = true
		_mission_active = false
	_refresh_mission_text()
	print("LIBREVILLE STORIES | Mission de manutention terminée.")

func _refresh_mission_text() -> void:
	if not is_instance_valid(_message):
		return
	if _mission_completed:
		_message.text = "MISSION TERMINÉE\n\nLes trois sacs de ciment ont été déplacés. Le chef de chantier te remercie.\n\nTu viens de gagner ta première expérience de travail."
		_accept_button.visible = false
	elif _mission_active:
		_message.text = "OBJECTIF : DÉPLACER LES SACS DE CIMENT\n\nRécupère les sacs repérés autour du point de départ et rapporte-les au chantier.\n\nProgression : %d / %d" % [_collected_sacks, REQUIRED_SACKS]
		_accept_button.visible = false
	else:
		_message.text = "OFFRE DU JOUR\n\nManutentionnaire : aider à déplacer trois sacs de ciment pour le chantier du quartier.\n\nLe chef de chantier attend un coup de main. Accepte cette première tâche pour commencer."
		_accept_button.visible = true

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_panel) and _panel.visible:
		_panel.visible = false
		get_viewport().set_input_as_handled()

func _build_notice_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorkNoticeOverlay"
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.name = "WorkNotice"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -260.0
	_panel.offset_top = -150.0
	_panel.offset_right = 260.0
	_panel.offset_bottom = 150.0
	_panel.visible = false
	layer.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "CHANTIER DU QUARTIER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(470, 170)
	column.add_child(_message)
	_accept_button = Button.new()
	_accept_button.text = "ACCEPTER LA MISSION"
	_accept_button.custom_minimum_size = Vector2(0, 42)
	_accept_button.pressed.connect(_accept_offer)
	column.add_child(_accept_button)
	var close_hint := Label.new()
	close_hint.text = "ÉCHAP : fermer"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.86))
	column.add_child(close_hint)
	_refresh_mission_text()
