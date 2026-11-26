extends CanvasLayer
## Affichage compact de l'heure, de la date et de l'événement en cours.

var _date_label: Label
var _time_label: Label
var _event_label: Label

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.name = "ClockPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -292.0
	panel.offset_right = -18.0
	panel.offset_top = 18.0
	panel.offset_bottom = 112.0
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	panel.add_child(layout)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(_date_label)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 25)
	_time_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	layout.add_child(_time_label)
	_event_label = Label.new()
	_event_label.add_theme_font_size_override("font_size", 12)
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_event_label)
	var clock := get_node_or_null("/root/WorldClock")
	if clock != null:
		clock.minute_changed.connect(_on_clock_changed)
		clock.active_events_changed.connect(_on_events_changed)
	_refresh()

func _on_clock_changed(_date_time: Dictionary) -> void:
	_refresh()

func _on_events_changed(_events: Array) -> void:
	_refresh()

func _refresh() -> void:
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null or _date_label == null:
		return
	var months := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
	var month_name: String = months[int(clock.current_month) - 1]
	_date_label.text = "%02d %s %04d" % [int(clock.current_day), month_name, int(clock.current_year)]
	_time_label.text = "%02d:%02d  ·  %s" % [int(clock.hour), int(clock.minute), str(clock.get_day_period()).replace("_", " ")]
	var active: Array = clock.get_active_events()
	if active.is_empty():
		_event_label.text = "Aucun événement particulier"
	else:
		var names: Array[String] = []
		for event in active:
			names.append(str(event.get("title", "Événement")))
		_event_label.text = "ÉVÉNEMENT : " + ", ".join(names)
