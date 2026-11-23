extends CanvasLayer
## Menu de téléportation : monument en accès direct, puis quartiers classés par arrondissement.

const ARRONDISSEMENTS := [
	"1er arrondissement",
	"2e arrondissement",
	"3e arrondissement",
	"4e arrondissement",
	"5e arrondissement",
	"6e arrondissement"
]

var _world_map: Node3D
var _groups: Dictionary = {}

func _ready() -> void:
	layer = 20
	_world_map = get_tree().current_scene.get_node_or_null("WorldMap") as Node3D
	var panel := PanelContainer.new()
	panel.name = "TeleportPanel"
	panel.position = Vector2(18, 104)
	panel.custom_minimum_size = Vector2(286, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DÉPLACEMENT RAPIDE"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	vbox.add_child(title)

	var monument_button := Button.new()
	monument_button.text = "★  Monument Georges-Damas-Aleka"
	monument_button.custom_minimum_size = Vector2(260, 40)
	monument_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	monument_button.pressed.connect(_on_monument_teleport)
	vbox.add_child(monument_button)

	var stele_button := Button.new()
	stele_button.text = "★  Stèle de la Liberté"
	stele_button.custom_minimum_size = Vector2(260, 36)
	stele_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stele_button.pressed.connect(_on_stele_teleport)
	vbox.add_child(stele_button)

	var subtitle := Label.new()
	subtitle.text = "CHOISIR UN ARRONDISSEMENT"
	subtitle.add_theme_font_size_override("font_size", 12)
	vbox.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)

	var destinations: Array = []
	if _world_map != null and _world_map.has_method("get_locality_destinations"):
		destinations = _world_map.call("get_locality_destinations")

	for arrondissement in ARRONDISSEMENTS:
		var section := VBoxContainer.new()
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation", 3)
		list.add_child(section)

		var quartier_list := VBoxContainer.new()
		quartier_list.visible = false
		quartier_list.add_theme_constant_override("separation", 3)
		section.add_child(quartier_list)
		_groups[arrondissement] = quartier_list

		var arrondissement_button := Button.new()
		arrondissement_button.text = "▸  " + arrondissement
		arrondissement_button.custom_minimum_size = Vector2(250, 34)
		arrondissement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arrondissement_button.pressed.connect(_toggle_arrondissement.bind(arrondissement))
		section.add_child(arrondissement_button)

		var matching: Array = []
		for destination in destinations:
			if str(destination.get("arrondissement", "")) == arrondissement:
				matching.append(destination)
		matching.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("name", "")) < str(b.get("name", ""))
		)

		if matching.is_empty():
			var empty_label := Label.new()
			empty_label.text = "  Aucun quartier géolocalisé dans les données."
			empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			quartier_list.add_child(empty_label)
		else:
			for destination in matching:
				var btn := Button.new()
				btn.text = "   " + str(destination.get("name", "Quartier"))
				btn.custom_minimum_size = Vector2(245, 31)
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.pressed.connect(_on_teleport.bind(destination.get("position", Vector3.ZERO)))
				quartier_list.add_child(btn)

	if destinations.is_empty():
		var warning := Label.new()
		warning.text = "Les contours des quartiers ne sont pas chargés."
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(warning)


func _toggle_arrondissement(arrondissement: String) -> void:
	var selected: VBoxContainer = _groups.get(arrondissement)
	if selected == null:
		return
	var should_show := not selected.visible
	for key in _groups.keys():
		(_groups[key] as VBoxContainer).visible = false
	selected.visible = should_show


func _on_teleport(world_map_position: Vector3) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null or _world_map == null:
		push_warning("Téléport : joueur ou carte introuvable")
		return
	player.global_position = _world_map.to_global(world_map_position)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	print("LIBREVILLE STORIES | téléport vers un quartier : ", player.global_position)


func _on_monument_teleport() -> void:
	var landmarks := get_tree().current_scene.get_node_or_null("WaterfrontLandmarks")
	var monument := landmarks.get_node_or_null("Monument_Georges_Damas_Aleka") as Node3D if landmarks != null else null
	if monument == null:
		push_warning("Téléport : monument Georges-Damas-Aleka introuvable")
		return
	_teleport_global(monument.to_global(Vector3(0.0, 2.4, 19.0)))


func _on_stele_teleport() -> void:
	var landmarks := get_tree().current_scene.get_node_or_null("WaterfrontLandmarks")
	var stele := landmarks.get_node_or_null("Stele_Liberte") as Node3D if landmarks != null else null
	if stele == null:
		push_warning("Téléport : Stèle de la Liberté introuvable")
		return
	_teleport_global(stele.to_global(Vector3(0.0, 2.0, 7.5)))


func _teleport_global(target: Vector3) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_warning("Téléport : joueur introuvable")
		return
	player.global_position = target
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	print("LIBREVILLE STORIES | téléport patrimonial : ", target)
