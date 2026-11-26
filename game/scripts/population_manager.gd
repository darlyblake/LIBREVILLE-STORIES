extends Node
## Gestionnaire de population persistante.
## Les habitants sont des données : aucun personnage 3D n'est instancié ici.

signal population_changed(alive_count: int, total_records: int)
signal resident_died(resident_id: String)
signal resident_born(resident_id: String)

const MAX_POPULATION := 10000
const INITIAL_POPULATION := 5000
const SAVE_PATH := "user://population_state.json"
const DATA_VERSION := 1

const FIRST_NAMES := ["Jean", "Paul", "Pierre", "Michel", "Alain", "Patrick", "Serge", "David", "Marc", "Christian", "Marie", "Anne", "Jeanne", "Sylvie", "Nadine", "Clarisse", "Estelle", "Grâce", "Brigitte", "Sarah"]
const LAST_NAMES := ["Mba", "Obiang", "Nguema", "Ndong", "Moussavou", "Essono", "Ovono", "Biyoghe", "Ayo", "Mintsa", "Ella", "Ekogha", "Oyoue", "Boussougou"]
const DISTRICTS := ["Centre-ville", "Louis", "Glass", "Nombakélé", "Mont-Bouët", "Nkembo", "Akébé"]
const JOBS := ["commerçant", "fonctionnaire", "chauffeur", "enseignant", "étudiant", "artisan", "agent de sécurité", "sans emploi", "soignant"]

var residents: Dictionary = {}
var alive_count: int = 0
var next_id: int = 1
var game_month: int = 1
var game_year: int = 2026
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if not load_population():
		create_initial_population()
	print("POPULATION | %d habitants vivants / plafond %d" % [alive_count, MAX_POPULATION])

func create_initial_population() -> void:
	residents.clear()
	alive_count = 0
	next_id = 1
	for index in range(INITIAL_POPULATION):
		var age := _rng.randi_range(1, 82)
		var resident_id := _new_id()
		residents[resident_id] = {
			"id": resident_id,
			"first_name": FIRST_NAMES[_rng.randi_range(0, FIRST_NAMES.size() - 1)],
			"last_name": LAST_NAMES[_rng.randi_range(0, LAST_NAMES.size() - 1)],
			"age_years": age,
			"age_months": 0,
			"alive": true,
			"district": DISTRICTS[_rng.randi_range(0, DISTRICTS.size() - 1)],
			"job": _job_for_age(age),
			"mother_id": "",
			"father_id": "",
			"spouse_id": "",
			"friends": [],
			"employer_id": "",
			"business_id": "",
			"created_year": game_year,
			"death_year": 0,
			"generation": 1
		}
		alive_count += 1
	save_population()
	population_changed.emit(alive_count, residents.size())

func register_birth(mother_id: String, father_id: String, district: String = "") -> String:
	# Une naissance ne peut être enregistrée que si une place est libre.
	if alive_count >= MAX_POPULATION:
		return ""
	var mother: Dictionary = residents.get(mother_id, {})
	var father: Dictionary = residents.get(father_id, {})
	if mother.is_empty() or father.is_empty():
		return ""
	if not bool(mother.get("alive", false)) or not bool(father.get("alive", false)):
		return ""
	var resident_id := _new_id()
	var child_district := district
	if child_district.is_empty():
		child_district = str(mother.get("district", DISTRICTS[0]))
	residents[resident_id] = {
		"id": resident_id,
		"first_name": FIRST_NAMES[_rng.randi_range(0, FIRST_NAMES.size() - 1)],
		"last_name": str(father.get("last_name", "Mba")),
		"age_years": 0,
		"age_months": 0,
		"alive": true,
		"district": child_district,
		"job": "enfant",
		"mother_id": mother_id,
		"father_id": father_id,
		"spouse_id": "",
		"friends": [],
		"employer_id": "",
		"business_id": "",
		"created_year": game_year,
		"death_year": 0,
		"generation": int(maxi(int(mother.get("generation", 1)), int(father.get("generation", 1)))) + 1
	}
	alive_count += 1
	resident_born.emit(resident_id)
	_save_and_notify()
	return resident_id

func register_death(resident_id: String) -> bool:
	if not residents.has(resident_id):
		return false
	var resident: Dictionary = residents[resident_id]
	if not bool(resident.get("alive", false)):
		return false
	resident["alive"] = false
	resident["death_year"] = game_year
	resident["job"] = "décédé"
	residents[resident_id] = resident
	alive_count = maxi(0, alive_count - 1)
	resident_died.emit(resident_id)
	_save_and_notify()
	return true

func advance_month() -> void:
	# Appelé par le futur calendrier du jeu ; aucune horloge réelle ne tourne ici.
	game_month += 1
	if game_month > 12:
		game_month = 1
		game_year += 1
	for resident_id in residents:
		var resident: Dictionary = residents[resident_id]
		if not bool(resident.get("alive", false)):
			continue
		var age_months := int(resident.get("age_months", 0)) + 1
		if age_months >= 12:
			age_months = 0
			resident["age_years"] = int(resident.get("age_years", 0)) + 1
			resident["job"] = _job_for_age(int(resident["age_years"]))
		resident["age_months"] = age_months
		residents[resident_id] = resident
	_save_and_notify()

func get_population_stats() -> Dictionary:
	return {
		"alive": alive_count,
		"dead_records": residents.size() - alive_count,
		"total_records": residents.size(),
		"capacity": MAX_POPULATION,
		"free_slots": maxi(0, MAX_POPULATION - alive_count),
		"year": game_year,
		"month": game_month
	}

func save_population() -> bool:
	var payload := {
		"version": DATA_VERSION,
		"max_population": MAX_POPULATION,
		"alive_count": alive_count,
		"next_id": next_id,
		"game_month": game_month,
		"game_year": game_year,
		"residents": residents
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'enregistrer la population : " + SAVE_PATH)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func load_population() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary or int(parsed.get("version", -1)) != DATA_VERSION:
		push_warning("Sauvegarde de population absente ou version incompatible ; création d'une nouvelle population.")
		return false
	var loaded: Variant = parsed.get("residents", {})
	if not loaded is Dictionary:
		return false
	residents = loaded
	alive_count = 0
	for resident in residents.values():
		if bool(resident.get("alive", false)):
			alive_count += 1
	alive_count = mini(alive_count, MAX_POPULATION)
	next_id = int(parsed.get("next_id", residents.size() + 1))
	game_month = clampi(int(parsed.get("game_month", 1)), 1, 12)
	game_year = int(parsed.get("game_year", 2026))
	return true

func _new_id() -> String:
	var resident_id := "GL-%06d" % next_id
	next_id += 1
	return resident_id

func _job_for_age(age: int) -> String:
	if age < 6:
		return "petit enfant"
	if age < 18:
		return "élève"
	if age >= 65:
		return "retraité"
	return JOBS[_rng.randi_range(0, JOBS.size() - 1)]

func _save_and_notify() -> void:
	save_population()
	population_changed.emit(alive_count, residents.size())
