extends StaticBody3D
## Premier point d'intérêt jouable : un panneau d'offres près du point de départ.
## Il introduit le système de petits boulots du quartier.

@export var interaction_prompt := "E : consulter les offres du chantier"

var _panel: PanelContainer
var _message: Label

func _ready() -> void:
	add_to_group("world_interactables")
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
		print("LIBREVILLE STORIES | Le joueur consulte les offres du chantier.")

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
	_panel.offset_left = -250.0
	_panel.offset_top = -125.0
	_panel.offset_right = 250.0
	_panel.offset_bottom = 125.0
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
	_message.text = "OFFRE DU JOUR\n\nManutentionnaire : aider à déplacer des sacs de ciment et des brouettes.\n\nPrésente-toi au chef de chantier pour connaître les horaires et la rémunération.\n\nCette activité sera développée en mission jouable."
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(450, 145)
	column.add_child(_message)
	var close_hint := Label.new()
	close_hint.text = "ÉCHAP : fermer"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.86))
	column.add_child(close_hint)
