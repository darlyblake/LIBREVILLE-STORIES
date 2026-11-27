extends Node
## Météo dynamique de Libreville, synchronisée avec WorldClock.
## Les probabilités représentent les saisons équatoriales locales, pas une prévision réelle.

signal weather_changed(state: Dictionary)

const WEATHER_TYPES := ["sunny", "cloudy", "light_rain", "heavy_rain", "storm"]
const CHECK_INTERVAL_HOURS := 3

var current_weather := "cloudy"
var rain_intensity := 0.0
var wind_strength := 0.18
var cloud_cover := 0.45
var _rng := RandomNumberGenerator.new()
var _last_roll_key := ""

func _ready() -> void:
	_rng.randomize()
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null:
		push_warning("WeatherManager : WorldClock introuvable.")
		return
	if not clock.minute_changed.is_connected(_on_clock_minute_changed):
		clock.minute_changed.connect(_on_clock_minute_changed)
	_roll_weather(clock.get_datetime(), true)

func _on_clock_minute_changed(date_time: Dictionary) -> void:
	var hour := int(date_time.get("hour", 0))
	var minute := int(date_time.get("minute", 0))
	if minute != 0 or hour % CHECK_INTERVAL_HOURS != 0:
		return
	_roll_weather(date_time)

func _roll_weather(date_time: Dictionary, force: bool = false) -> void:
	var year := int(date_time.get("year", 2026))
	var month := int(date_time.get("month", 1))
	var day := int(date_time.get("day", 1))
	var hour := int(date_time.get("hour", 6))
	var roll_key := "%04d-%02d-%02d-%02d" % [year, month, day, hour]
	if not force and roll_key == _last_roll_key:
		return
	_last_roll_key = roll_key

	var weights := _season_weights(month)
	var total := 0.0
	for value in weights.values():
		total += float(value)
	var pick := _rng.randf() * total
	var selected := "cloudy"
	for weather_type in WEATHER_TYPES:
		pick -= float(weights.get(weather_type, 0.0))
		if pick <= 0.0:
			selected = weather_type
			break
	_set_weather(selected)

func _season_weights(month: int) -> Dictionary:
	# Libreville : pluies marquées autour d'octobre-novembre,
	# autre période humide de février à mai, saisons moins pluvieuses entre les deux.
	match month:
		10, 11:
			return {"sunny": 8.0, "cloudy": 24.0, "light_rain": 34.0, "heavy_rain": 25.0, "storm": 9.0}
		2, 3, 4, 5:
			return {"sunny": 14.0, "cloudy": 28.0, "light_rain": 34.0, "heavy_rain": 19.0, "storm": 5.0}
		12:
			return {"sunny": 32.0, "cloudy": 35.0, "light_rain": 22.0, "heavy_rain": 9.0, "storm": 2.0}
		1:
			return {"sunny": 42.0, "cloudy": 34.0, "light_rain": 17.0, "heavy_rain": 6.0, "storm": 1.0}
		6, 7, 8, 9:
			return {"sunny": 48.0, "cloudy": 34.0, "light_rain": 13.0, "heavy_rain": 4.0, "storm": 1.0}
		_:
			return {"sunny": 24.0, "cloudy": 36.0, "light_rain": 26.0, "heavy_rain": 11.0, "storm": 3.0}

func _set_weather(weather_type: String) -> void:
	current_weather = weather_type
	match weather_type:
		"sunny":
			rain_intensity = 0.0
			cloud_cover = 0.12
			wind_strength = 0.16
		"cloudy":
			rain_intensity = 0.0
			cloud_cover = 0.72
			wind_strength = 0.28
		"light_rain":
			rain_intensity = 0.32
			cloud_cover = 0.86
			wind_strength = 0.38
		"heavy_rain":
			rain_intensity = 0.72
			cloud_cover = 0.96
			wind_strength = 0.62
		"storm":
			rain_intensity = 1.0
			cloud_cover = 1.0
			wind_strength = 0.9
	_apply_to_world()
	weather_changed.emit(get_weather_state())
	print("WEATHER | %s | rain %.2f | wind %.2f" % [current_weather, rain_intensity, wind_strength])

func register_bay_water_controller(controller: Node) -> void:
	if controller != null and controller.has_method("set_bay_rain_intensity"):
		controller.call("set_bay_rain_intensity", rain_intensity, 0.0)

func _apply_to_world() -> void:
	for controller in get_tree().get_nodes_in_group("bay_water_controller"):
		if controller.has_method("set_bay_rain_intensity"):
			controller.call("set_bay_rain_intensity", rain_intensity, 3.0)

func get_weather_state() -> Dictionary:
	return {
		"type": current_weather,
		"rain_intensity": rain_intensity,
		"cloud_cover": cloud_cover,
		"wind_strength": wind_strength
	}
