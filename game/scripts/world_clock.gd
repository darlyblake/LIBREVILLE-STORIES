extends Node
## Horloge et calendrier central de Libreville Stories.
## Une minute de jeu = 1 seconde réelle par défaut (modifiable dans l'inspecteur).
## Tous les systèmes (PNJ, commerces, écoles, médias, météo) écoutent ces signaux.

signal minute_changed(date_time: Dictionary)
signal hour_changed(hour: int, period: String)
signal day_started(date: Dictionary)
signal day_ended(date: Dictionary)
signal month_changed(month: int, year: int)
signal year_changed(year: int)
signal event_started(event: Dictionary)
signal event_ended(event: Dictionary)
signal active_events_changed(events: Array)

const SAVE_PATH := "user://world_clock_state.json"
const EVENTS_PATH := "res://data/calendar/gabon_events.json"
const SCHEDULES_PATH := "res://data/calendar/opening_hours.json"
const DEFAULT_START_YEAR := 2026
const DEFAULT_START_MONTH := 1
const DEFAULT_START_DAY := 1

@export_range(0.05, 60.0, 0.05) var real_seconds_per_game_minute: float = 1.0
@export var start_paused: bool = false
@export var start_year: int = DEFAULT_START_YEAR
@export_range(1, 12, 1) var start_month: int = DEFAULT_START_MONTH
@export_range(1, 31, 1) var start_day: int = DEFAULT_START_DAY

var current_year: int = DEFAULT_START_YEAR
var current_month: int = DEFAULT_START_MONTH
var current_day: int = DEFAULT_START_DAY
var hour: int = 6
var minute: int = 0
var time_scale: float = 1.0
var is_paused: bool = false
var _accumulator: float = 0.0
var _events: Array[Dictionary] = []
var _schedule_profiles: Dictionary = {}
var _active_event_ids: Dictionary = {}

func _ready() -> void:
	_load_events()
	_load_schedules()
	is_paused = start_paused
	if not _load_state():
		current_year = start_year
		current_month = start_month
		current_day = mini(start_day, _days_in_month(start_year, start_month))
		_save_state()
	_sync_population_date()
	_refresh_active_events(true)
	print("WORLD CLOCK | %s %02d:%02d" % [get_date_string(), hour, minute])

func _process(delta: float) -> void:
	if is_paused or real_seconds_per_game_minute <= 0.0:
		return
	_accumulator += delta * time_scale
	var step := real_seconds_per_game_minute
	while _accumulator >= step:
		_accumulator -= step
		advance_minutes(1)

func pause() -> void:
	is_paused = true

func resume() -> void:
	is_paused = false

func toggle_pause() -> void:
	is_paused = not is_paused

func set_time_scale(value: float) -> void:
	time_scale = clampf(value, 0.1, 120.0)

func set_time(new_hour: int, new_minute: int = 0) -> void:
	var previous_hour := hour
	hour = clampi(new_hour, 0, 23)
	minute = clampi(new_minute, 0, 59)
	if hour != previous_hour:
		hour_changed.emit(hour, get_day_period())
	minute_changed.emit(get_datetime())
	_save_state()

func set_date(new_year: int, new_month: int, new_day: int) -> void:
	var previous_year := current_year
	var previous_month := current_month
	var previous_date := get_date()
	current_year = maxi(1, new_year)
	current_month = clampi(new_month, 1, 12)
	current_day = clampi(new_day, 1, _days_in_month(current_year, current_month))
	if current_year != previous_year:
		year_changed.emit(current_year)
	if current_year != previous_year or current_month != previous_month:
		month_changed.emit(current_month, current_year)
	_sync_population_date()
	_refresh_active_events()
	if previous_date != get_date():
		day_started.emit(get_date())
	minute_changed.emit(get_datetime())
	_save_state()

func advance_minutes(amount: int) -> void:
	if amount <= 0:
		return
	for _i in range(amount):
		var previous_hour := hour
		minute += 1
		if minute >= 60:
			minute = 0
			hour += 1
			if hour >= 24:
				hour = 0
				day_ended.emit(get_date())
				_advance_day()
			if hour != previous_hour:
				hour_changed.emit(hour, get_day_period())
		minute_changed.emit(get_datetime())
	if minute == 0 and hour % 6 == 0:
		_save_state()

func advance_hours(amount: int) -> void:
	if amount > 0:
		advance_minutes(amount * 60)

func advance_days(amount: int) -> void:
	for _i in range(maxi(0, amount)):
		day_ended.emit(get_date())
		_advance_day()
	_save_state()

func _advance_day() -> void:
	current_day += 1
	if current_day > _days_in_month(current_year, current_month):
		current_day = 1
		current_month += 1
		if current_month > 12:
			current_month = 1
			current_year += 1
			year_changed.emit(current_year)
		if has_node("/root/PopulationManager"):
			get_node("/root/PopulationManager").advance_month()
		month_changed.emit(current_month, current_year)
	_refresh_active_events()
	day_started.emit(get_date())

func _sync_population_date() -> void:
	var population := get_node_or_null("/root/PopulationManager")
	if population != null:
		population.game_year = current_year
		population.game_month = current_month

func get_date() -> Dictionary:
	return {"year": current_year, "month": current_month, "day": current_day}

func get_datetime() -> Dictionary:
	return {"year": current_year, "month": current_month, "day": current_day, "hour": hour, "minute": minute}

func get_date_string() -> String:
	return "%04d-%02d-%02d" % [current_year, current_month, current_day]

func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]

func get_day_period() -> String:
	if hour >= 5 and hour < 12:
		return "matin"
	if hour >= 12 and hour < 18:
		return "apres_midi"
	if hour >= 18 and hour < 22:
		return "soir"
	return "nuit"

func is_night() -> bool:
	return hour >= 20 or hour < 6

func is_weekend() -> bool:
	var unix_time := Time.get_unix_time_from_datetime_dict({"year": current_year, "month": current_month, "day": current_day, "hour": 12, "minute": 0, "second": 0})
	var weekday := int(Time.get_datetime_dict_from_unix_time(unix_time).get("weekday", 1))
	return weekday == 0 or weekday == 6

func get_events_for_date(year: int = -1, month: int = -1, day: int = -1) -> Array[Dictionary]:
	var y := current_year if year < 0 else year
	var m := current_month if month < 0 else month
	var d := current_day if day < 0 else day
	var result: Array[Dictionary] = []
	var current_ordinal := m * 100 + d
	for event in _events:
		var start_parts := _parse_date(str(event.get("start_date", "")))
		var end_parts := _parse_date(str(event.get("end_date", event.get("start_date", ""))))
		if start_parts.size() != 3 or end_parts.size() != 3:
			continue
		var matches := false
		if bool(event.get("annual", false)):
			var start_ordinal := start_parts[1] * 100 + start_parts[2]
			var end_ordinal := end_parts[1] * 100 + end_parts[2]
			# Une plage annuelle peut traverser le 31 décembre (ex. 20/12 au 05/01).
			if start_ordinal <= end_ordinal:
				matches = current_ordinal >= start_ordinal and current_ordinal <= end_ordinal
			else:
				matches = current_ordinal >= start_ordinal or current_ordinal <= end_ordinal
		else:
			var current_key := y * 10000 + m * 100 + d
			var start_key := start_parts[0] * 10000 + start_parts[1] * 100 + start_parts[2]
			var end_key := end_parts[0] * 10000 + end_parts[1] * 100 + end_parts[2]
			matches = current_key >= start_key and current_key <= end_key
		if matches:
			var copy := event.duplicate(true)
			copy["occurrence_year"] = y
			result.append(copy)
	return result

func get_active_events() -> Array[Dictionary]:
	return get_events_for_date()

func has_event_category(category: String) -> bool:
	for event in get_active_events():
		if str(event.get("category", "")) == category:
			return true
	return false

func _has_active_tag(tag: String) -> bool:
	for event in get_active_events():
		if event.get("tags", []).has(tag):
			return true
	return false

func is_school_period() -> bool:
	return _has_active_tag("school_in_session") and not _has_active_tag("school_holidays")

func are_schools_open_now() -> bool:
	return is_school_period() and not is_weekend() and not has_event_category("public_holiday") and hour >= 7 and hour < 17

func are_shops_open_now() -> bool:
	return is_schedule_open("retail")

func get_weekday() -> int:
	var unix_time := Time.get_unix_time_from_datetime_dict({"year": current_year, "month": current_month, "day": current_day, "hour": 12, "minute": 0, "second": 0})
	return int(Time.get_datetime_dict_from_unix_time(unix_time).get("weekday", 1))

func is_schedule_open(profile_id: String) -> bool:
	return bool(get_schedule_status(profile_id).get("open", false))

func get_schedule_status(profile_id: String) -> Dictionary:
	var profile: Dictionary = _schedule_profiles.get(profile_id, {})
	if profile.is_empty():
		return {"open": false, "reason": "unknown_profile", "profile_id": profile_id}
	if bool(profile.get("always_open", false)):
		return {"open": true, "reason": "always_open", "profile_id": profile_id}
	var active_holiday := has_event_category("public_holiday")
	if active_holiday and bool(profile.get("closed_on_public_holidays", false)):
		return {"open": false, "reason": "public_holiday", "profile_id": profile_id}
	if bool(profile.get("requires_school_term", false)):
		if not is_school_period():
			return {"open": false, "reason": "school_break", "profile_id": profile_id}
		if is_weekend():
			return {"open": false, "reason": "weekend", "profile_id": profile_id}
	var weekday_key := str(get_weekday())
	var day_ranges: Array = profile.get("days", {}).get(weekday_key, [])
	if day_ranges.is_empty():
		return {"open": false, "reason": "closed_day", "profile_id": profile_id}
	var now_minutes := hour * 60 + minute
	for range_value in day_ranges:
		if not range_value is Array or range_value.size() != 2 and range_value.size() != 4:
			continue
		var start_minutes := int(range_value[0]) * 60
		var end_minutes := int(range_value[1]) * 60
		if range_value.size() == 4:
			start_minutes += int(range_value[1])
			end_minutes = int(range_value[2]) * 60 + int(range_value[3])
		if now_minutes >= start_minutes and now_minutes < end_minutes:
			return {"open": true, "reason": "within_opening_hours", "profile_id": profile_id, "closes_at": "%02d:%02d" % [int(end_minutes / 60), end_minutes % 60]}
	var first_range: Array = day_ranges[0]
	var opening_hour := int(first_range[0])
	var opening_minute := int(first_range[1]) if first_range.size() == 4 else 0
	return {"open": false, "reason": "outside_opening_hours", "profile_id": profile_id, "opens_at": "%02d:%02d" % [opening_hour, opening_minute]}

func get_seasonal_tags() -> Array[String]:
	var tags: Array[String] = []
	for event in get_active_events():
		for tag in event.get("tags", []):
			if not tags.has(str(tag)):
				tags.append(str(tag))
	return tags

func _refresh_active_events(initial: bool = false) -> void:
	var now_active: Dictionary = {}
	var current_events := get_active_events()
	for event in current_events:
		var event_id := str(event.get("id", event.get("title", "")))
		now_active[event_id] = event
		if not _active_event_ids.has(event_id):
			event_started.emit(event)
	if not initial:
		for old_id in _active_event_ids:
			if not now_active.has(old_id):
				event_ended.emit(_active_event_ids[old_id])
	_active_event_ids = now_active
	active_events_changed.emit(current_events)

func _load_schedules() -> void:
	if not FileAccess.file_exists(SCHEDULES_PATH):
		push_warning("Fichier des horaires introuvable : " + SCHEDULES_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEDULES_PATH))
	if parsed is Dictionary and parsed.get("profiles", {}) is Dictionary:
		_schedule_profiles = parsed.get("profiles", {})

func _load_events() -> void:
	if not FileAccess.file_exists(EVENTS_PATH):
		push_warning("Fichier calendrier introuvable : " + EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if parsed is Dictionary:
		for item in parsed.get("events", []):
			if item is Dictionary:
				_events.append(item)

func _load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return false
	current_year = maxi(1, int(parsed.get("year", DEFAULT_START_YEAR)))
	current_month = clampi(int(parsed.get("month", DEFAULT_START_MONTH)), 1, 12)
	current_day = clampi(int(parsed.get("day", DEFAULT_START_DAY)), 1, _days_in_month(current_year, current_month))
	hour = clampi(int(parsed.get("hour", 6)), 0, 23)
	minute = clampi(int(parsed.get("minute", 0)), 0, 59)
	return true

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Impossible d'enregistrer l'horloge.")
		return
	file.store_string(JSON.stringify(get_datetime()))
	file.close()

func _parse_date(value: String) -> Array[int]:
	var parts: PackedStringArray = value.split("-")
	if parts.size() != 3:
		return []
	return [parts[0].to_int(), parts[1].to_int(), parts[2].to_int()]

func _days_in_month(year: int, month: int) -> int:
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and (year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)):
		return 29
	return days[month - 1]
