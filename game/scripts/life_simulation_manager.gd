extends Node
## Simulation abstraite des rythmes de vie : travail, repos, congés et loisirs.
## Les 5 000+ habitants restent des données ; seuls les acteurs proches seront rendus en 3D.

signal resident_activity_changed(resident_id: String, activity: String)
signal crowd_level_changed(location_type: String, multiplier: float)

const CONFIG_PATH := "res://data/simulation/life_profiles.json"
const STANDARD_WORK_JOBS := ["fonctionnaire", "enseignant", "employé", "artisan", "commerçant"]
const SHIFT_WORK_JOBS := ["chauffeur", "agent de sécurité", "soignant"]
const NON_WORK_JOBS := ["sans emploi", "retraité", "nourrisson", "petit enfant", "élève", "décédé"]

var _config: Dictionary = {}
var _runtime: Dictionary = {}
var _last_crowd_levels: Dictionary = {}

func _ready() -> void:
	_load_config()
	var clock := get_node_or_null("/root/WorldClock")
	if clock != null:
		clock.hour_changed.connect(_on_hour_changed)
		clock.day_started.connect(_on_day_started)
	_refresh_all_activities()

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("LifeSimulationManager : profils de vie absents.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		_config = parsed
	else:
		push_error("LifeSimulationManager : JSON des profils de vie invalide.")

func _on_day_started(_date: Dictionary) -> void:
	for resident_id in _runtime:
		var state: Dictionary = _runtime[resident_id]
		state["nightlife_until"] = -1
		_runtime[resident_id] = state
	_refresh_all_activities()
	_emit_crowd_levels()

func _on_hour_changed(new_hour: int, _period: String) -> void:
	var population := get_node_or_null("/root/PopulationManager")
	if population == null:
		return
	for resident_id in population.residents:
		var resident: Dictionary = population.residents[resident_id]
		if not bool(resident.get("alive", false)):
			continue
		var state := _state_for(str(resident_id), resident)
		_update_needs(state, new_hour)
		if new_hour == 19:
			_consider_nightlife(str(resident_id), resident, state)
		_update_activity(str(resident_id), resident, state, new_hour)
		_runtime[str(resident_id)] = state
	_emit_crowd_levels()

func _refresh_all_activities() -> void:
	var population := get_node_or_null("/root/PopulationManager")
	var clock := get_node_or_null("/root/WorldClock")
	if population == null or clock == null:
		return
	var current_hour := int(clock.hour)
	for resident_id in population.residents:
		var resident: Dictionary = population.residents[resident_id]
		if not bool(resident.get("alive", false)):
			continue
		var state := _state_for(str(resident_id), resident)
		_update_activity(str(resident_id), resident, state, current_hour)
		_runtime[str(resident_id)] = state
	_emit_crowd_levels()

func _state_for(resident_id: String, resident: Dictionary) -> Dictionary:
	if _runtime.has(resident_id):
		return _runtime[resident_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(resident_id)
	var rest_days: Array[int] = []
	if rng.randf() < 0.80:
		rest_days = [0, 6] # dimanche et samedi
	else:
		while rest_days.size() < 2:
			var candidate := rng.randi_range(0, 6)
			if not rest_days.has(candidate):
				rest_days.append(candidate)
	var state := {
		"rest_days": rest_days,
		"leave_year": -1,
		"leave_start_day": 0,
		"leave_end_day": 0,
		"activity": "maison",
		"destination": "home",
		"alcohol": 0.0,
		"fatigue": 0.0,
		"nightlife_until": -1,
		"last_updated_hour": -1
	}
	_prepare_annual_leave(state, resident_id, int(get_node("/root/WorldClock").current_year))
	return state

func _prepare_annual_leave(state: Dictionary, resident_id: String, year: int) -> void:
	if int(state.get("leave_year", -1)) == year:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed("%s:%d:leave" % [resident_id, year])
	var leave_days := int(_config.get("employment", {}).get("annual_leave_calendar_days", 20))
	var start_day := rng.randi_range(1, maxi(1, 365 - leave_days))
	state["leave_year"] = year
	state["leave_start_day"] = start_day
	state["leave_end_day"] = start_day + leave_days - 1

func _update_needs(state: Dictionary, hour: int) -> void:
	var alcohol := float(state.get("alcohol", 0.0))
	var fatigue := float(state.get("fatigue", 0.0))
	if str(state.get("activity", "")) == "bar":
		alcohol = minf(1.0, alcohol + float(_config.get("nightlife", {}).get("alcohol_per_hour", 0.22)))
		fatigue = minf(1.0, fatigue + 0.08)
	else:
		alcohol = maxf(0.0, alcohol - 0.12)
		if hour >= 6 and hour <= 9:
			fatigue = maxf(0.0, fatigue - 0.025)
		elif hour >= 22 or hour < 6:
			fatigue = maxf(0.0, fatigue - 0.06)
		else:
			fatigue = minf(1.0, fatigue + 0.008)
	state["alcohol"] = alcohol
	state["fatigue"] = fatigue

func _consider_nightlife(resident_id: String, resident: Dictionary, state: Dictionary) -> void:
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null:
		return
	var date: Dictionary = clock.get_date()
	var weekday := _weekday(date)
	var job := str(resident.get("job", ""))
	if NON_WORK_JOBS.has(job) or job == "élève":
		return
	var chance := float(_config.get("nightlife", {}).get("weekday_chance", 0.08))
	if weekday == 0 or weekday == 6:
		chance = float(_config.get("nightlife", {}).get("weekend_chance", 0.28))
	if not bool(clock.call("is_school_period")):
		chance = maxf(chance, float(_config.get("nightlife", {}).get("holiday_chance", 0.32)))
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed("%s:%s:night" % [resident_id, clock.get_date_string()])
	if rng.randf() < chance:
		state["nightlife_until"] = rng.randi_range(22, 24)

func _update_activity(resident_id: String, resident: Dictionary, state: Dictionary, hour: int) -> void:
	var previous := str(state.get("activity", "maison"))
	var clock := get_node_or_null("/root/WorldClock")
	if not bool(resident.get("alive", false)):
		state["activity"] = "décédé"
		state["destination"] = ""
	elif clock == null:
		state["activity"] = "maison"
	elif hour >= 19 and hour <= int(state.get("nightlife_until", -1)):
		state["activity"] = "bar"
		state["destination"] = "nightlife"
	elif _is_at_work(resident_id, resident, state, hour):
		state["activity"] = "travail"
		state["destination"] = "work"
	elif str(resident.get("job", "")) == "élève" and _is_school_day(hour):
		state["activity"] = "école"
		state["destination"] = "school"
	elif str(resident.get("job", "")) == "élève" and not bool(clock.call("is_school_period")) and hour >= 10 and hour < 18:
		state["activity"] = "loisirs"
		state["destination"] = "leisure"
	elif hour >= 11 and hour < 14 and _is_working_day(resident_id, resident, state, clock.get_date()):
		state["activity"] = "restaurant"
		state["destination"] = "restaurant"
	elif hour >= 16 and hour < 19 and (_weekday(clock.get_date()) == 0 or _weekday(clock.get_date()) == 6):
		state["activity"] = "loisirs"
		state["destination"] = "leisure"
	else:
		state["activity"] = "maison"
		state["destination"] = "home"
	if previous != str(state["activity"]):
		resident_activity_changed.emit(resident_id, str(state["activity"]))

func _is_at_work(resident_id: String, resident: Dictionary, state: Dictionary, hour: int) -> bool:
	var job := str(resident.get("job", ""))
	if NON_WORK_JOBS.has(job) or job == "élève":
		return false
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null or not _is_working_day(resident_id, resident, state, clock.get_date()):
		return false
	var profile := _profile_for_job(job)
	var start_hour := int(profile.get("start_hour", 8))
	var end_hour := int(profile.get("end_hour", 17))
	if start_hour < end_hour:
		return hour >= start_hour and hour < end_hour
	return hour >= start_hour or hour < end_hour

func _is_working_day(resident_id: String, resident: Dictionary, state: Dictionary, date: Dictionary) -> bool:
	var job := str(resident.get("job", ""))
	if NON_WORK_JOBS.has(job) or job == "élève":
		return false
	var weekday := _weekday(date)
	if (state.get("rest_days", []) as Array).has(weekday):
		return false
	if _is_public_holiday():
		return false
	_prepare_annual_leave(state, resident_id, int(date.get("year", 2026)))
	var day_of_year := _day_of_year(date)
	if day_of_year >= int(state.get("leave_start_day", 0)) and day_of_year <= int(state.get("leave_end_day", -1)):
		return false
	return true

func _is_school_day(hour: int) -> bool:
	var clock := get_node_or_null("/root/WorldClock")
	return clock != null and bool(clock.call("is_schedule_open", "school")) and hour >= 7 and hour < 17

func _is_public_holiday() -> bool:
	var clock := get_node_or_null("/root/WorldClock")
	return clock != null and bool(clock.call("has_event_category", "public_holiday"))

func _profile_for_job(job: String) -> Dictionary:
	var profiles: Dictionary = _config.get("job_profiles", {})
	if profiles.has(job):
		return profiles[job]
	if SHIFT_WORK_JOBS.has(job):
		return profiles.get("shift_worker", {})
	return profiles.get("standard_worker", {})

func _weekday(date: Dictionary) -> int:
	var stamp := Time.get_unix_time_from_datetime_dict({
		"year": int(date.get("year", 2026)), "month": int(date.get("month", 1)),
		"day": int(date.get("day", 1)), "hour": 12, "minute": 0, "second": 0
	})
	return int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", 1))

func _day_of_year(date: Dictionary) -> int:
	var start := Time.get_unix_time_from_datetime_dict({"year": int(date.get("year", 2026)), "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var current := Time.get_unix_time_from_datetime_dict({"year": int(date.get("year", 2026)), "month": int(date.get("month", 1)), "day": int(date.get("day", 1)), "hour": 0, "minute": 0, "second": 0})
	return int(floor((current - start) / 86400.0)) + 1

func _stable_seed(value: String) -> int:
	var result := 2166136261
	for character in value.to_utf8_buffer():
		result = int((result ^ int(character)) * 16777619) & 0x7fffffff
	return maxi(1, result)

func _emit_crowd_levels() -> void:
	var clock := get_node_or_null("/root/WorldClock")
	if clock == null:
		return
	var date: Dictionary = clock.get_date()
	var weekday := _weekday(date)
	var weekend := weekday == 0 or weekday == 6
	var holiday := not bool(clock.call("is_school_period"))
	var hour := int(clock.hour)
	var levels: Dictionary = _config.get("crowds", {})
	for location_type in levels:
		var profile: Dictionary = levels[location_type]
		var multiplier := float(profile.get("weekday_day", 1.0))
		if weekend:
			multiplier = float(profile.get("weekend_day", multiplier))
		if holiday:
			multiplier *= float(profile.get("school_holiday_factor", 1.0))
		var night_hours: Dictionary = profile.get("night_hours", {})
		if hour >= 19 or hour < 5:
			multiplier *= float(night_hours.get("factor", 1.0))
		if location_type == "market" and (hour < 6 or hour >= 19):
			multiplier *= 0.15
		if location_type == "restaurant" and hour >= 11 and hour < 14:
			multiplier *= 1.35
		if location_type == "bar" and hour >= 20 and hour < 24:
			multiplier *= 1.8
		multiplier = clampf(multiplier, 0.0, 3.0)
		if not _last_crowd_levels.has(location_type) or not is_equal_approx(float(_last_crowd_levels[location_type]), multiplier):
			_last_crowd_levels[location_type] = multiplier
			crowd_level_changed.emit(str(location_type), multiplier)

func get_crowd_multiplier(location_type: String) -> float:
	return float(_last_crowd_levels.get(location_type, 1.0))

func get_resident_activity(resident_id: String) -> Dictionary:
	if not _runtime.has(resident_id):
		return {}
	var state: Dictionary = _runtime[resident_id]
	return {
		"activity": state.get("activity", "maison"),
		"destination": state.get("destination", "home"),
		"alcohol": float(state.get("alcohol", 0.0)),
		"fatigue": float(state.get("fatigue", 0.0))
	}

func get_work_performance_multiplier(resident_id: String) -> float:
	var state: Dictionary = _runtime.get(resident_id, {})
	var alcohol := float(state.get("alcohol", 0.0))
	var fatigue := float(state.get("fatigue", 0.0))
	return clampf(1.0 - alcohol * 0.55 - fatigue * 0.30, 0.45, 1.0)

func get_driving_risk_multiplier(resident_id: String) -> float:
	var state: Dictionary = _runtime.get(resident_id, {})
	var alcohol := float(state.get("alcohol", 0.0))
	var fatigue := float(state.get("fatigue", 0.0))
	return 1.0 + alcohol * 2.0 + fatigue * 0.65
