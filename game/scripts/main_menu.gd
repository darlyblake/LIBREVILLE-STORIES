extends Control

const WORLD_SCENE: PackedScene = preload("res://game/scenes/main.tscn")
const SETTINGS_PATH := "user://graphics_settings.cfg"

var _quality: OptionButton
var _shadows: CheckButton
var _buildings: CheckButton
var _vegetation: CheckButton
var _extra_textures: CheckButton
var _fullscreen: CheckButton
var _status: Label
var _menu_box: VBoxContainer
var _settings_box: VBoxContainer

func _ready() -> void:
	_build_interface()
	_load_settings()
	_show_menu()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.055, 0.09, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var title := Label.new()
	title.text = "LIBREVILLE STORIES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.35, 0.72, 1.0))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "EXPLORER LIBREVILLE • CONFIGURER AVANT DE JOUER"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.81, 0.9))
	content.add_child(subtitle)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	content.add_child(_menu_box)
	_add_button(_menu_box, "DÉMARRER", _start_game)
	_add_button(_menu_box, "PARAMÈTRES GRAPHIQUES", _show_settings)
	_add_button(_menu_box, "QUITTER", _quit_game)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	content.add_child(_settings_box)

	var settings_title := Label.new()
	settings_title.text = "PARAMÈTRES AVANT LE CHARGEMENT DU MONDE"
	settings_title.add_theme_font_size_override("font_size", 18)
	_settings_box.add_child(settings_title)

	_add_label(_settings_box, "Qualité graphique")
	_quality = OptionButton.new()
	_quality.add_item("Économique — carte graphique 2 Go")
	_quality.add_item("Équilibrée")
	_quality.add_item("Élevée")
	_quality.item_selected.connect(_on_quality_selected)
	_settings_box.add_child(_quality)

	_shadows = _add_check(_settings_box, "Ombres dynamiques")
	_buildings = _add_check(_settings_box, "Afficher les bâtiments")
	_vegetation = _add_check(_settings_box, "Végétation et herbe 3D")
	_extra_textures = _add_check(_settings_box, "Textures de routes supplémentaires")
	_fullscreen = _add_check(_settings_box, "Plein écran")

	_add_button(_settings_box, "ENREGISTRER ET RETOUR", _save_and_back)
	_add_button(_settings_box, "RETOUR AU MENU", _show_menu)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.85, 0.78, 0.52))
	content.add_child(_status)

func _add_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)

func _add_label(parent: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)

func _add_check(parent: VBoxContainer, caption: String) -> CheckButton:
	var check := CheckButton.new()
	check.text = caption
	parent.add_child(check)
	return check

func _show_menu() -> void:
	_menu_box.visible = true
	_settings_box.visible = false
	_status.text = "Le monde 3D n'est pas chargé. Choisissez vos réglages avant de démarrer."

func _show_settings() -> void:
	_menu_box.visible = false
	_settings_box.visible = true
	_status.text = "Les réglages seront appliqués avant la création du monde ouvert."

func _on_quality_selected(index: int) -> void:
	if index == 0:
		_shadows.button_pressed = false
		_buildings.button_pressed = false
		_vegetation.button_pressed = false
		_extra_textures.button_pressed = false
	elif index == 1:
		_shadows.button_pressed = false
		_buildings.button_pressed = true
		_vegetation.button_pressed = false
		_extra_textures.button_pressed = false
	else:
		_shadows.button_pressed = true
		_buildings.button_pressed = true
		_vegetation.button_pressed = true
		_extra_textures.button_pressed = true

func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		_quality.select(0)
		_shadows.button_pressed = false
		_buildings.button_pressed = false
		_vegetation.button_pressed = false
		_extra_textures.button_pressed = false
		_fullscreen.button_pressed = false
		return
	_quality.select(int(config.get_value("graphics", "quality", 0)))
	_shadows.button_pressed = bool(config.get_value("graphics", "shadows", false))
	_buildings.button_pressed = bool(config.get_value("graphics", "buildings", false))
	_vegetation.button_pressed = bool(config.get_value("graphics", "vegetation", false))
	_extra_textures.button_pressed = bool(config.get_value("graphics", "extra_textures", false))
	_fullscreen.button_pressed = bool(config.get_value("display", "fullscreen", false))
	_apply_display_mode()

func _save_and_back() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", _quality.selected)
	config.set_value("graphics", "shadows", _shadows.button_pressed)
	config.set_value("graphics", "buildings", _buildings.button_pressed)
	config.set_value("graphics", "vegetation", _vegetation.button_pressed)
	config.set_value("graphics", "extra_textures", _extra_textures.button_pressed)
	config.set_value("display", "fullscreen", _fullscreen.button_pressed)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		_status.text = "Impossible d'enregistrer les réglages (code %d)." % error
		return
	_apply_display_mode()
	_show_menu()

func _apply_display_mode() -> void:
	if _fullscreen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _start_game() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", _quality.selected)
	config.set_value("graphics", "shadows", _shadows.button_pressed)
	config.set_value("graphics", "buildings", _buildings.button_pressed)
	config.set_value("graphics", "vegetation", _vegetation.button_pressed)
	config.set_value("graphics", "extra_textures", _extra_textures.button_pressed)
	config.set_value("display", "fullscreen", _fullscreen.button_pressed)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		_status.text = "Impossible d'enregistrer les réglages (code %d)." % error
		return
	_apply_display_mode()
	_status.text = "Préparation du monde…"
	await get_tree().process_frame
	# Remplace réellement le menu : il ne doit jamais rester au-dessus du monde.
	var change_error := get_tree().change_scene_to_packed(WORLD_SCENE)
	if change_error != OK:
		_status.text = "Impossible de démarrer le monde (code %d)." % change_error

func _quit_game() -> void:
	get_tree().quit()
