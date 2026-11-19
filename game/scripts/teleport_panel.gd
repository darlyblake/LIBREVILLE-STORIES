extends CanvasLayer
## Téléportation dynamique vers les localités réelles présentes dans localities.geojson.

func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.name = "TeleportPanel"
	panel.position = Vector2(18, 120)
	panel.custom_minimum_size = Vector2(230, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Quartiers de Libreville"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	vbox.add_child(title)

	var world_map := get_tree().current_scene.get_node_or_null("WorldMap")
	if world_map == null or not world_map.has_method("get_locality_destinations"):
		var warning := Label.new()
		warning.text = "Données des quartiers indisponibles"
		vbox.add_child(warning)
		return

	var destinations: Array = world_map.call("get_locality_destinations")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(210, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for destination in destinations:
		var btn := Button.new()
		btn.text = str(destination.name)
		btn.custom_minimum_size = Vector2(195, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_teleport.bind(destination.position))
		list.add_child(btn)

	if destinations.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucun quartier dans la zone cartographiée."
		list.add_child(empty_label)


func _on_teleport(world_pos: Vector3) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_warning("Téléport : joueur introuvable")
		return
	player.global_position = world_pos
	player.velocity = Vector3.ZERO
	print("LIBREVILLE STORIES | téléporté vers ", world_pos)
