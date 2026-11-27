extends RefCounted
class_name VehicleProfileDatabase

const PROFILE_PATH := "res://data/vehicles/vehicle_profiles.json"
static var _cache: Dictionary = {}

static func get_profile(profile_id: String) -> Dictionary:
	if _cache.is_empty():
		_load_profiles()
	return (_cache.get("vehicles", {}) as Dictionary).get(profile_id, {}).duplicate(true)

static func _load_profiles() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		push_error("VehicleProfileDatabase: fichier absent: " + PROFILE_PATH)
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_error("VehicleProfileDatabase: lecture impossible.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_cache = parsed
	else:
		push_error("VehicleProfileDatabase: JSON invalide.")
