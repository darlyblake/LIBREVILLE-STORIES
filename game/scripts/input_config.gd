extends Node
## Couche d'entrée multiplateforme : les scripts de gameplay ne lisent que des actions logiques.

const SETTINGS_PATH := "user://key_bindings.cfg"
const GAMEPAD_DEADZONE := 0.20

var defaults := {
	"move_forward": KEY_Z,
	"move_back": KEY_S,
	"move_left": KEY_Q,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"enter_exit_vehicle": KEY_F,
	"interact": KEY_E,
	"vehicle_accelerate": KEY_W,
	"vehicle_brake": KEY_S,
	"vehicle_left": KEY_A,
	"vehicle_right": KEY_D,
	"vehicle_camera_next": KEY_C,
	"aim": KEY_NONE,
	"shoot": KEY_NONE,
	"reload": KEY_R,
	"camera_look_left": KEY_NONE,
	"camera_look_right": KEY_NONE,
	"camera_look_up": KEY_NONE,
	"camera_look_down": KEY_NONE
}

var action_labels := {
	"move_forward": "Marcher vers l'avant",
	"move_back": "Reculer",
	"move_left": "Aller à gauche",
	"move_right": "Aller à droite",
	"jump": "Sauter",
	"sprint": "Courir",
	"enter_exit_vehicle": "Entrer / sortir du véhicule",
	"interact": "Interagir",
	"vehicle_accelerate": "Accélérer",
	"vehicle_brake": "Freiner / marche arrière",
	"vehicle_left": "Tourner à gauche",
	"vehicle_right": "Tourner à droite",
	"vehicle_camera_next": "Changer de caméra",
	"aim": "Viser",
	"shoot": "Tirer",
	"reload": "Recharger"
}

var _keyboard_defaults := {
	"move_forward": KEY_Z, "move_back": KEY_S,
	"move_left": KEY_Q, "move_right": KEY_D,
	"jump": KEY_SPACE, "sprint": KEY_SHIFT,
	"enter_exit_vehicle": KEY_F, "interact": KEY_E,
	"vehicle_accelerate": KEY_W, "vehicle_brake": KEY_S,
	"vehicle_left": KEY_A, "vehicle_right": KEY_D,
	"vehicle_camera_next": KEY_C, "reload": KEY_R
}


func _ready() -> void:
	for action in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action, GAMEPAD_DEADZONE)
		if _keyboard_defaults.has(action) and _keyboard_event(action) == null:
			_add_key_event(action, int(_keyboard_defaults[action]))
	_register_mouse_and_gamepad_events()
	_load_bindings()


func _register_mouse_and_gamepad_events() -> void:
	_add_mouse_button("aim", MOUSE_BUTTON_RIGHT)
	_add_mouse_button("shoot", MOUSE_BUTTON_LEFT)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("enter_exit_vehicle", JOY_BUTTON_Y)
	_add_joy_button("interact", JOY_BUTTON_B)
	_add_joy_button("reload", JOY_BUTTON_X)
	_add_joy_button("vehicle_camera_next", JOY_BUTTON_RIGHT_STICK)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("vehicle_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("vehicle_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("vehicle_accelerate", JOY_AXIS_TRIGGER_RIGHT, 0.55)
	_add_joy_axis("vehicle_brake", JOY_AXIS_TRIGGER_LEFT, 0.55)
	_add_joy_axis("aim", JOY_AXIS_TRIGGER_LEFT, 0.55)
	_add_joy_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 0.55)
	_add_joy_axis("camera_look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis("camera_look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis("camera_look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis("camera_look_down", JOY_AXIS_RIGHT_Y, 1.0)


func _add_mouse_button(action: String, button_index: MouseButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button_index:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)


func _add_joy_button(action: String, button_index: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: String, axis: JoyAxis, direction: float) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, direction):
				return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


func _keyboard_event(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _add_key_event(action: String, keycode: int) -> void:
	if keycode <= 0:
		return
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
	if not defaults.has(action) or keycode == 0 or not _keyboard_defaults.has(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	_add_key_event(action, keycode)
	_save_bindings()


func reset_bindings() -> void:
	for action in _keyboard_defaults:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		_add_key_event(action, int(_keyboard_defaults[action]))
	_save_bindings()


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for action in _keyboard_defaults:
		var keycode := int(config.get_value("keyboard", action, _keyboard_defaults[action]))
		if keycode > 0:
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					InputMap.action_erase_event(action, event)
			_add_key_event(action, keycode)


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action in _keyboard_defaults:
		var event := _keyboard_event(action)
		if event != null:
			var keycode := event.physical_keycode
			if keycode == 0:
				keycode = event.keycode
			config.set_value("keyboard", action, keycode)
	config.save(SETTINGS_PATH)
