extends CanvasLayer
## Boutons de téléportation vers les zones clés pour inspecter les modifications.

const DESTINATIONS := [
	{"name": "Baie des Rois", "pos": Vector3(-1790.0, 2.0, -570.0)},
	{"name": "Centre-ville", "pos": Vector3(-400.0, 2.0, -150.0)},
	{"name": "Boulevard Triomphal", "pos": Vector3(-900.0, 2.0, -200.0)},
	{"name": "Port Môle / Cathédrale", "pos": Vector3(-1250.0, 2.0, -310.0)},
	{"name": "Mont-Bouët", "pos": Vector3(200.0, 2.0, 100.0)},
	{"name": "Glass", "pos": Vector3(650.0, 2.0, 2550.0)},
]


func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.name = "TeleportPanel"
	panel.position = Vector2(18, 120)
	panel.custom_minimum_size = Vector2(200, 0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	# On enveloppe le vbox dans le margin via structure simple :
	panel.remove_child(vbox)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "Aller à…"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	vbox.add_child(title)

	for dest in DESTINATIONS:
		var btn := Button.new()
		btn.text = str(dest.name)
		btn.custom_minimum_size = Vector2(180, 28)
		btn.pressed.connect(_on_teleport.bind(dest.pos as Vector3))
		vbox.add_child(btn)


func _on_teleport(world_pos: Vector3) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_warning("Téléport : joueur introuvable")
		return
	player.global_position = world_pos
	player.velocity = Vector3.ZERO
	print("LIBREVILLE STORIES | téléporté vers ", world_pos)
