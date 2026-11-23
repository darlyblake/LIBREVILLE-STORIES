extends Node
## Gestion centralisée des commandes clavier. Les événements manette restent séparés.

const SETTINGS_PATH := "user://key_bindings.cfg"

var defaults := {
	"move_forward": KEY_Z,
	"move_back": KEY_S,
	"move_left": KEY_Q,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"enter_exit_vehicle": KEY_F,
	"vehicle_accelerate": KEY_W,
	"vehicle_brake": KEY_S,
	"vehicle_left": KEY_A,
	"vehicle_right": KEY_D,
	"vehicle_camera_next": KEY_C
}

var action_labels := {
	"move_forward": "Marcher vers l'avant",
	"move_back": "Reculer",
	"move_left": "Aller à gauche",
	"move_right": "Aller à droite",
	"jump": "Sauter",
	"sprint": "Courir",
	"enter_exit_vehicle": "Entrer / sortir du véhicule",
	"vehicle_accelerate": "Accélérer",
	"vehicle_brake": "Freiner / marche arrière",
	"vehicle_left": "Tourner à gauche",
	"vehicle_right": "Tourner à droite",
	"vehicle_camera_next": "Changer de caméra"
}


func _ready() -> void:
	for action in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if _keyboard_event(action) == null:
			_add_key_event(action, int(defaults[action]))
	_load_bindings()


func _keyboard_event(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _add_key_event(action: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func get_key_label(action: String) -> String:
	var event := _keyboard_event(action)
	if event == null:
		return "Non assignée"
	var keycode := event.physical_keycode
	if keycode == 0:
		keycode = event.keycode
	return OS.get_keycode_string(keycode)


func set_key(action: String, keycode: int) -> void:
	if not defaults.has(action) or keycode == 0:
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	_add_key_event(action, keycode)
	_save_bindings()


func reset_bindings() -> void:
	for action in defaults:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		_add_key_event(action, int(defaults[action]))
	_save_bindings()


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for action in defaults:
		var keycode := int(config.get_value("keyboard", action, defaults[action]))
		if keycode > 0:
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					InputMap.action_erase_event(action, event)
			_add_key_event(action, keycode)


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action in defaults:
		var event := _keyboard_event(action)
		if event != null:
			var keycode := event.physical_keycode
			if keycode == 0:
				keycode = event.keycode
			config.set_value("keyboard", action, keycode)
	config.save(SETTINGS_PATH)
