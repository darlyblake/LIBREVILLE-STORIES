extends Node
## Population persistante : identites, familles, naissances, vieillissement et mortalite.
## Les residents sont des donnees. Les personnages 3D seront geres par un systeme distinct.

signal population_changed(alive_count: int, total_records: int)
signal resident_died(resident_id: String)
signal resident_born(resident_id: String)
signal resident_birthday(resident_id: String)

const MAX_POPULATION := 10000
const INITIAL_POPULATION := 5000
const SAVE_PATH := "user://population_state.json"
const DATA_VERSION := 2
const MAX_CHILDREN_PER_COUPLE := 4
const MIN_MOTHER_AGE := 18
const MAX_MOTHER_AGE := 42
const MIN_BIRTH_INTERVAL_MONTHS := 18
const MONTHLY_BIRTH_CHANCE := 0.008

const MALE_FIRST_NAMES := ["Jean", "Paul", "Pierre", "Michel", "Alain", "Patrick", "Serge", "David", "Marc", "Christian", "Emmanuel", "André", "Fabrice", "Brice"]
const FEMALE_FIRST_NAMES := ["Marie", "Anne", "Jeanne", "Sylvie", "Nadine", "Clarisse", "Estelle", "Grâce", "Brigitte", "Sarah", "Patricia", "Sandrine", "Jessica", "Carine"]
const LAST_NAMES := ["Mba", "Obiang", "Nguema", "Ndong", "Moussavou", "Essono", "Ovono", "Biyoghe", "Ayo", "Mintsa", "Ella", "Ekogha", "Oyoue", "Boussougou"]
const DISTRICTS := ["Centre-ville", "Louis", "Glass", "Nombakélé", "Mont-Bouët", "Nkembo", "Akébé"]
const JOBS := ["agriculteur", "pêcheur", "maraîcher", "agent SEEG électricité", "agent SEEG eau", "technicien réseau électrique", "technicien fibre optique", "plombier", "éboueur", "chauffeur camion poubelle", "agent de nettoyage urbain", "médecin", "infirmier", "sage-femme", "pharmacien", "ambulancier", "psychologue", "travailleur social", "enseignant", "éducateur", "professeur université", "chauffeur taxi", "chauffeur bus", "livreur", "mécanicien automobile", "maçon", "menuisier", "électricien bâtiment", "architecte", "commerçant", "vendeur marché", "restaurateur", "cuisinier", "serveur", "boulanger", "policier", "gendarme", "pompier", "agent municipal", "magistrat", "fonctionnaire", "comptable", "informaticien", "journaliste", "artiste", "coiffeur", "couturier", "entrepreneur", "chef entreprise", "artisan", "employé", "sans emploi"]

var residents: Dictionary = {}
var alive_count: int = 0
var next_id: int = 1
var game_month: int = 1
var game_year: int = 2026
var births_this_month: int = 0
var deaths_this_month: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if not load_population():
		create_initial_population()
	print("POPULATION | %d habitants vivants / plafond %d" % [alive_count, MAX_POPULATION])

## Cree une population de depart et constitue des couples et des liens parent-enfant plausibles.
func create_initial_population() -> void:
	residents.clear()
	alive_count = 0
	next_id = 1
	var male_ids: Array[String] = []
	var female_ids: Array[String] = []
	var child_ids: Array[String] = []

	for index in range(INITIAL_POPULATION):
		var age := _rng.randi_range(0, 82)
		var gender := "homme" if _rng.randf() < 0.49 else "femme"
		var resident_id := _new_id()
		var first_name := _random_first_name(gender)
		var resident := _make_resident(resident_id, first_name, LAST_NAMES[_rng.randi_range(0, LAST_NAMES.size() - 1)], age, gender)
		residents[resident_id] = resident
		if age >= 20 and age <= 60:
			if gender == "homme":
				male_ids.append(resident_id)
			else:
				female_ids.append(resident_id)
		elif age < 18:
			child_ids.append(resident_id)
		alive_count += 1

	_pair_initial_adults(male_ids, female_ids)
	_assign_initial_children(child_ids)
	save_population()
	population_changed.emit(alive_count, residents.size())

func _make_resident(resident_id: String, first_name: String, last_name: String, age: int, gender: String) -> Dictionary:
	var occupation := _job_for_age(age)
	var nationality := _nationality_for_job(occupation)
	return {
		"id": resident_id,
		"first_name": first_name,
		"last_name": last_name,
		"gender": gender,
		"age_years": age,
		"age_months": _rng.randi_range(0, 11),
		"alive": true,
		"nationality": nationality,
		"origin_region": _region_for_nationality(nationality),
		"district": DISTRICTS[_rng.randi_range(0, DISTRICTS.size() - 1)],
		"job": occupation,
		"mother_id": "",
		"father_id": "",
		"spouse_id": "",
		"marital_status": "célibataire",
		"friends": [],
		"employer_id": "",
		"business_id": "",
		"children_ids": [],
		"last_birth_month": -1000,
		"created_year": game_year,
		"death_year": 0,
		"generation": 1,
		"appearance": _generate_appearance(gender, age)
	}

func _pair_initial_adults(male_ids: Array[String], female_ids: Array[String]) -> void:
	male_ids.shuffle()
	female_ids.shuffle()
	var used_males: Dictionary = {}
	for female_id in female_ids:
		var female: Dictionary = residents[female_id]
		var best_match := ""
		var best_difference := 999
		for male_id in male_ids:
			if used_males.has(male_id):
				continue
			var male: Dictionary = residents[male_id]
			var difference := absi(int(female["age_years"]) - int(male["age_years"]))
			if difference <= 12 and difference < best_difference:
				best_match = male_id
				best_difference = difference
		# Une partie des adultes reste célibataire.
		if best_match != "" and _rng.randf() < 0.72:
			_link_spouses(female_id, best_match)
			used_males[best_match] = true

func _assign_initial_children(child_ids: Array[String]) -> void:
	var couples: Array[String] = []
	for resident_id in residents:
		var resident: Dictionary = residents[resident_id]
		if str(resident.get("gender", "")) == "femme" and str(resident.get("spouse_id", "")) != "":
			couples.append(resident_id)
	couples.shuffle()
	for child_id in child_ids:
		var child: Dictionary = residents[child_id]
		var child_age := int(child["age_years"])
		var possible_mothers: Array[String] = []
		for mother_id in couples:
			var mother: Dictionary = residents[mother_id]
			var father_id := str(mother.get("spouse_id", ""))
			var father: Dictionary = residents.get(father_id, {})
			if int(mother["age_years"]) >= child_age + 18 and int(father.get("age_years", 0)) >= child_age + 18:
				if (mother["children_ids"] as Array).size() < MAX_CHILDREN_PER_COUPLE:
					possible_mothers.append(mother_id)
		if possible_mothers.is_empty() or _rng.randf() > 0.78:
			continue
		var mother_id := possible_mothers[_rng.randi_range(0, possible_mothers.size() - 1)]
		var mother: Dictionary = residents[mother_id]
		var father_id := str(mother["spouse_id"])
		child["mother_id"] = mother_id
		child["father_id"] = father_id
		child["last_name"] = str(residents[father_id]["last_name"])
		child["nationality"] = str(mother.get("nationality", "Gabon"))
		child["origin_region"] = str(mother.get("origin_region", "Afrique centrale"))
		child["generation"] = 2
		residents[child_id] = child
		_append_child_to_parent(mother_id, child_id)
		_append_child_to_parent(father_id, child_id)

## Enregistre une naissance uniquement pour deux parents vivants et un couple valide.
func register_birth(mother_id: String, father_id: String, district: String = "", persist: bool = true) -> String:
	if alive_count >= MAX_POPULATION:
		return ""
	if not residents.has(mother_id) or not residents.has(father_id):
		return ""
	var mother: Dictionary = residents[mother_id]
	var father: Dictionary = residents[father_id]
	if not bool(mother.get("alive", false)) or not bool(father.get("alive", false)):
		return ""
	if str(mother.get("gender", "")) != "femme" or str(father.get("gender", "")) != "homme":
		return ""
	if int(mother.get("age_years", 0)) < MIN_MOTHER_AGE or int(mother.get("age_years", 0)) > MAX_MOTHER_AGE:
		return ""
	if str(mother.get("spouse_id", "")) != father_id or str(father.get("spouse_id", "")) != mother_id:
		return ""
	if _count_children(mother_id) >= MAX_CHILDREN_PER_COUPLE:
		return ""
	var current_month_index := _current_month_index()
	if current_month_index - int(mother.get("last_birth_month", -1000)) < MIN_BIRTH_INTERVAL_MONTHS:
		return ""

	var resident_id := _new_id()
	var child_district := district
	if child_district.is_empty():
		child_district = str(mother.get("district", DISTRICTS[0]))
	var child := _make_resident(resident_id, _random_first_name(""), str(father.get("last_name", "Mba")), 0, "femme" if _rng.randf() < 0.5 else "homme")
	child["age_months"] = 0
	child["job"] = "nourrisson"
	child["nationality"] = str(mother.get("nationality", "Gabon"))
	child["origin_region"] = str(mother.get("origin_region", "Afrique centrale"))
	child["district"] = child_district
	child["mother_id"] = mother_id
	child["father_id"] = father_id
	child["generation"] = maxi(int(mother.get("generation", 1)), int(father.get("generation", 1))) + 1
	child["created_year"] = game_year
	residents[resident_id] = child
	_append_child_to_parent(mother_id, resident_id)
	_append_child_to_parent(father_id, resident_id)
	mother["last_birth_month"] = current_month_index
	residents[mother_id] = mother
	alive_count += 1
	births_this_month += 1
	resident_born.emit(resident_id)
	if persist:
		_save_and_notify()
	return resident_id

## Lie deux adultes comme conjoints. Cette fonction ne cree pas automatiquement d'enfant.
func register_marriage(first_id: String, second_id: String) -> bool:
	if first_id == second_id or not residents.has(first_id) or not residents.has(second_id):
		return false
	var first: Dictionary = residents[first_id]
	var second: Dictionary = residents[second_id]
	if not bool(first.get("alive", false)) or not bool(second.get("alive", false)):
		return false
	if int(first.get("age_years", 0)) < 18 or int(second.get("age_years", 0)) < 18:
		return false
	if str(first.get("spouse_id", "")) != "" or str(second.get("spouse_id", "")) != "":
		return false
	_link_spouses(first_id, second_id)
	_save_and_notify()
	return true

func _link_spouses(first_id: String, second_id: String) -> void:
	var first: Dictionary = residents[first_id]
	var second: Dictionary = residents[second_id]
	first["spouse_id"] = second_id
	second["spouse_id"] = first_id
	first["marital_status"] = "marié"
	second["marital_status"] = "marié"
	residents[first_id] = first
	residents[second_id] = second

func add_friend(resident_id: String, friend_id: String) -> bool:
	if resident_id == friend_id or not residents.has(resident_id) or not residents.has(friend_id):
		return false
	var resident: Dictionary = residents[resident_id]
	var friend: Dictionary = residents[friend_id]
	if not bool(resident.get("alive", false)) or not bool(friend.get("alive", false)):
		return false
	var friends: Array = resident.get("friends", [])
	if friends.has(friend_id):
		return false
	friends.append(friend_id)
	resident["friends"] = friends
	residents[resident_id] = resident
	var reverse_friends: Array = friend.get("friends", [])
	if not reverse_friends.has(resident_id):
		reverse_friends.append(resident_id)
	friend["friends"] = reverse_friends
	residents[friend_id] = friend
	_save_and_notify()
	return true

func register_death(resident_id: String, cause: String = "inconnue", persist: bool = true) -> bool:
	if not residents.has(resident_id):
		return false
	var resident: Dictionary = residents[resident_id]
	if not bool(resident.get("alive", false)):
		return false
	resident["alive"] = false
	resident["death_year"] = game_year
	resident["death_month"] = game_month
	resident["death_cause"] = cause
	resident["job"] = "décédé"
	residents[resident_id] = resident
	alive_count = maxi(0, alive_count - 1)

	var spouse_id := str(resident.get("spouse_id", ""))
	if residents.has(spouse_id):
		var spouse: Dictionary = residents[spouse_id]
		if bool(spouse.get("alive", false)):
			spouse["marital_status"] = "veuf" if str(spouse.get("gender", "")) == "homme" else "veuve"
			residents[spouse_id] = spouse

	deaths_this_month += 1
	resident_died.emit(resident_id)
	if persist:
		_save_and_notify()
	return true

## Avance d'un mois de jeu : vieillissement, mortalité naturelle, puis naissances.
func advance_month() -> void:
	game_month += 1
	if game_month > 12:
		game_month = 1
		game_year += 1
	births_this_month = 0
	deaths_this_month = 0

	var living_ids: Array[String] = []
	for resident_id in residents:
		var resident: Dictionary = residents[resident_id]
		if bool(resident.get("alive", false)):
			living_ids.append(str(resident_id))

	# Vieillissement et mortalite naturelle : chaque habitant est examine une fois par mois.
	for resident_id in living_ids:
		if not residents.has(resident_id):
			continue
		var resident: Dictionary = residents[resident_id]
		if not bool(resident.get("alive", false)):
			continue
		var age_months := int(resident.get("age_months", 0)) + 1
		if age_months >= 12:
			age_months = 0
			resident["age_years"] = int(resident.get("age_years", 0)) + 1
			resident["job"] = _job_for_age(int(resident["age_years"]))
			resident_birthday.emit(resident_id)
		resident["age_months"] = age_months
		residents[resident_id] = resident
		if _rng.randf() < _monthly_mortality(int(resident["age_years"])):
			register_death(resident_id, "naturelle", false)

	# Les naissances ne concernent que les couples eligibles et respectent le plafond global.
	var mother_ids: Array[String] = []
	for resident_id in living_ids:
		if not residents.has(resident_id):
			continue
		var resident: Dictionary = residents[resident_id]
		if bool(resident.get("alive", false)) and str(resident.get("gender", "")) == "femme":
			mother_ids.append(resident_id)
	for mother_id in mother_ids:
		if alive_count >= MAX_POPULATION:
			break
		if not residents.has(mother_id):
			continue
		var mother: Dictionary = residents[mother_id]
		var father_id := str(mother.get("spouse_id", ""))
		if father_id == "" or not residents.has(father_id):
			continue
		var father: Dictionary = residents[father_id]
		if not bool(mother.get("alive", false)) or not bool(father.get("alive", false)):
			continue
		var mother_age := int(mother.get("age_years", 0))
		if mother_age < MIN_MOTHER_AGE or mother_age > MAX_MOTHER_AGE:
			continue
		if _count_children(mother_id) >= MAX_CHILDREN_PER_COUPLE:
			continue
		if _current_month_index() - int(mother.get("last_birth_month", -1000)) < MIN_BIRTH_INTERVAL_MONTHS:
			continue
		if _rng.randf() < MONTHLY_BIRTH_CHANCE:
			register_birth(mother_id, father_id, "", false)

	_save_and_notify()

func _monthly_mortality(age: int) -> float:
	if age < 1:
		return 0.0012
	if age < 15:
		return 0.00008
	if age < 50:
		return 0.00015
	if age < 65:
		return 0.0008
	if age < 80:
		return 0.004
	return 0.012

func _count_children(parent_id: String) -> int:
	if not residents.has(parent_id):
		return 0
	var parent: Dictionary = residents[parent_id]
	var children: Array = parent.get("children_ids", [])
	return children.size()

func _append_child_to_parent(parent_id: String, child_id: String) -> void:
	if not residents.has(parent_id):
		return
	var parent: Dictionary = residents[parent_id]
	var children: Array = parent.get("children_ids", [])
	if not children.has(child_id):
		children.append(child_id)
	parent["children_ids"] = children
	residents[parent_id] = parent

func get_resident(resident_id: String) -> Dictionary:
	if not residents.has(resident_id):
		return {}
	return residents[resident_id].duplicate(true)

func get_family(resident_id: String) -> Dictionary:
	if not residents.has(resident_id):
		return {}
	var resident: Dictionary = residents[resident_id]
	var family := {
		"resident": get_resident(resident_id),
		"mother": get_resident(str(resident.get("mother_id", ""))),
		"father": get_resident(str(resident.get("father_id", ""))),
		"spouse": get_resident(str(resident.get("spouse_id", ""))),
		"children": []
	}
	var children: Array = resident.get("children_ids", [])
	for child_id in children:
		(family["children"] as Array).append(get_resident(str(child_id)))
	return family

func get_population_stats() -> Dictionary:
	return {
		"alive": alive_count,
		"dead_records": residents.size() - alive_count,
		"total_records": residents.size(),
		"capacity": MAX_POPULATION,
		"free_slots": maxi(0, MAX_POPULATION - alive_count),
		"births_this_month": births_this_month,
		"deaths_this_month": deaths_this_month,
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
	if not parsed is Dictionary:
		push_warning("Sauvegarde de population illisible ; creation d'une nouvelle population.")
		return false
	var version := int(parsed.get("version", -1))
	if version < 1 or version > DATA_VERSION:
		push_warning("Version de sauvegarde de population incompatible.")
		return false
	var loaded: Variant = parsed.get("residents", {})
	if not loaded is Dictionary:
		return false

	residents = loaded
	alive_count = 0
	var highest_id := 0
	for resident_id in residents:
		var resident: Dictionary = residents[resident_id]
		_normalize_resident(resident)
		residents[resident_id] = resident
		if bool(resident.get("alive", false)):
			alive_count += 1
		var numeric_id := str(resident_id).trim_prefix("GL-").to_int()
		highest_id = maxi(highest_id, numeric_id)

	# Protection des anciennes sauvegardes ou fichiers modifies manuellement.
	if alive_count > MAX_POPULATION:
		var excess := alive_count - MAX_POPULATION
		for resident_id in residents:
			if excess <= 0:
				break
			var resident: Dictionary = residents[resident_id]
			if bool(resident.get("alive", false)):
				resident["alive"] = false
				resident["death_year"] = int(parsed.get("game_year", 2026))
				resident["death_cause"] = "rééquilibrage de sauvegarde"
				resident["job"] = "décédé"
				residents[resident_id] = resident
				excess -= 1
		alive_count = MAX_POPULATION

	next_id = maxi(int(parsed.get("next_id", 1)), highest_id + 1)
	game_month = clampi(int(parsed.get("game_month", 1)), 1, 12)
	game_year = int(parsed.get("game_year", 2026))
	_save_and_notify()
	return true

## Chaque fiche reçoit une identité visuelle persistante, indépendante du métier.
## Les paramètres seront interprétés par le futur générateur de modèles 3D.
## Pondérations provisoires de gameplay, non présentées comme statistiques officielles.
## Les boutiques ont davantage de commerçants ouest-africains ; le marché reste plus mixte.
func _nationality_for_job(occupation: String) -> String:
	var roll := _rng.randf()
	if occupation == "commerçant" or occupation == "gérant boutique":
		if roll < 0.30: return "Gabon"
		if roll < 0.48: return "Bénin"
		if roll < 0.63: return "Sénégal"
		if roll < 0.75: return "Mali"
		if roll < 0.85: return "Burkina Faso"
		if roll < 0.92: return "Cameroun"
		if roll < 0.96: return "Togo"
		if roll < 0.98: return "Nigeria"
		return "Congo"
	if occupation == "vendeur marché":
		if roll < 0.75: return "Gabon"
		if roll < 0.83: return "Bénin"
		if roll < 0.90: return "Cameroun"
		if roll < 0.95: return "Mali"
		return "Sénégal"
	if roll < 0.88: return "Gabon"
	if roll < 0.90: return "Cameroun"
	if roll < 0.92: return "Congo"
	if roll < 0.94: return "République démocratique du Congo"
	if roll < 0.96: return "Bénin"
	if roll < 0.975: return "Sénégal"
	if roll < 0.985: return "Mali"
	if roll < 0.993: return "Burkina Faso"
	return "Togo"

func _region_for_nationality(nationality: String) -> String:
	match nationality:
		"Gabon", "Cameroun", "Congo", "République démocratique du Congo":
			return "Afrique centrale"
		"Bénin", "Sénégal", "Mali", "Burkina Faso", "Togo", "Nigeria":
			return "Afrique de l'Ouest"
		_:
			return "Afrique"

func _generate_appearance(gender: String, age: int) -> Dictionary:
	var hair_styles: Array[String] = ["coupe_courte", "degrade", "boucles", "tresses", "nattes", "locks", "afro", "rasé", "queue_cheval", "chignon", "carre"]
	var hair_colors: Array[String] = ["noir", "brun_fonce", "brun", "chatain", "gris", "blanc", "teinte_bordeaux"]
	var skin_tones: Array[String] = ["ebene", "ebene", "brun_fonce", "brun_fonce", "brun", "brun_moyen", "caramel", "cuivre", "clair"]
	var face_shapes: Array[String] = ["ovale", "rond", "carre", "allonge", "coeur", "losange"]
	var eye_shapes: Array[String] = ["amande", "ronds", "fins", "tombants"]
	var nose_shapes: Array[String] = ["fin", "large", "droit", "arrondi", "court"]
	var body_types: Array[String] = ["mince", "moyen", "athletique", "corpulence_moyenne", "fort"]
	var tops: Array[String] = ["tshirt", "polo", "chemise", "blouse", "debardeur", "pull", "veste", "robe", "tenue_travail"]
	var bottoms: Array[String] = ["jean", "pantalon", "short", "jupe", "pantalon_travail", "robe"]
	var shoes: Array[String] = ["baskets", "sandales", "chaussures_ville", "bottes", "tongs"]
	var accessories: Array[String] = ["aucun", "lunettes", "casquette", "chapeau", "boucles_oreilles", "collier", "sac", "montre"]
	var facial_hair := "aucune"
	if gender == "homme" and age >= 16:
		facial_hair = ["aucune", "barbe_courte", "barbe_complete", "bouc", "moustache"][ _rng.randi_range(0, 4) ]
	var selected_hair := hair_styles[_rng.randi_range(0, hair_styles.size() - 1)]
	if age < 3:
		selected_hair = ["tres_court", "boucles", "tresses"][ _rng.randi_range(0, 2) ]
	var height_min := 90 if age < 6 else (110 if age < 12 else (145 if age < 16 else 155))
	var height_max := 105 if age < 6 else (145 if age < 12 else (175 if age < 16 else 198))
	var palette_index := _rng.randi_range(0, 11)
	return {
		"identity": "look-" + str(next_id),
		"seed": _rng.randi(),
		"face_detail": _generate_face_detail(),
		"gender_presentation": gender,
		"skin_tone": skin_tones[_rng.randi_range(0, skin_tones.size() - 1)],
		"face_shape": face_shapes[_rng.randi_range(0, face_shapes.size() - 1)],
		"eye_shape": eye_shapes[_rng.randi_range(0, eye_shapes.size() - 1)],
		"nose_shape": nose_shapes[_rng.randi_range(0, nose_shapes.size() - 1)],
		"hair_style": selected_hair,
		"hair_color": hair_colors[_rng.randi_range(0, hair_colors.size() - 1)],
		"facial_hair": facial_hair,
		"height_cm": _rng.randi_range(height_min, height_max),
		"body_type": body_types[_rng.randi_range(0, body_types.size() - 1)],
		"top": tops[_rng.randi_range(0, tops.size() - 1)],
		"bottom": bottoms[_rng.randi_range(0, bottoms.size() - 1)],
		"shoes": shoes[_rng.randi_range(0, shoes.size() - 1)],
		"accessory": accessories[_rng.randi_range(0, accessories.size() - 1)],
		"outfit_palette": palette_index
	}

## Morphologie faciale individuelle persistante, générée une seule fois par résident.
func _generate_face_detail() -> Dictionary:
	return {
		"head_width": _rng.randf_range(0.92, 1.09),
		"head_height": _rng.randf_range(0.93, 1.08),
		"head_depth": _rng.randf_range(0.92, 1.08),
		"eye_width": _rng.randf_range(0.88, 1.14),
		"eye_spacing": _rng.randf_range(0.88, 1.13),
		"eye_height": _rng.randf_range(-0.018, 0.018),
		"eye_depth": _rng.randf_range(-0.012, 0.012),
		"nose_width": _rng.randf_range(0.82, 1.24),
		"nose_length": _rng.randf_range(0.86, 1.18),
		"nose_height": _rng.randf_range(-0.018, 0.018),
		"nose_projection": _rng.randf_range(-0.012, 0.018),
		"mouth_width": _rng.randf_range(0.82, 1.22),
		"mouth_height": _rng.randf_range(-0.012, 0.012),
		"chin_width": _rng.randf_range(0.84, 1.18),
		"chin_height": _rng.randf_range(0.85, 1.18),
		"cheek_volume": _rng.randf_range(0.82, 1.2),
		"ear_size": _rng.randf_range(0.88, 1.14)
	}

func _normalize_resident(resident: Dictionary) -> void:
	if not resident.has("gender"):
		resident["gender"] = "homme" if _rng.randf() < 0.49 else "femme"
	if not resident.has("friends"):
		resident["friends"] = []
	if not resident.has("children_ids"):
		resident["children_ids"] = []
	if not resident.has("marital_status"):
		resident["marital_status"] = "marié" if str(resident.get("spouse_id", "")) != "" else "célibataire"
	if not resident.has("last_birth_month"):
		resident["last_birth_month"] = -1000
	if not resident.has("death_cause"):
		resident["death_cause"] = ""
	if not resident.has("generation"):
		resident["generation"] = 1
	if not resident.has("nationality"):
		resident["nationality"] = _nationality_for_job(str(resident.get("job", "sans emploi")))
	if not resident.has("origin_region"):
		resident["origin_region"] = _region_for_nationality(str(resident["nationality"]))
	if not resident.has("appearance") or not resident["appearance"] is Dictionary:
		resident["appearance"] = _generate_appearance(str(resident.get("gender", "homme")), int(resident.get("age_years", 18)))
	else:
		var appearance: Dictionary = resident["appearance"]
		if not appearance.has("face_detail") or not appearance["face_detail"] is Dictionary:
			appearance["face_detail"] = _generate_face_detail()
			resident["appearance"] = appearance

func _random_first_name(gender: String) -> String:
	if gender == "homme":
		return MALE_FIRST_NAMES[_rng.randi_range(0, MALE_FIRST_NAMES.size() - 1)]
	return FEMALE_FIRST_NAMES[_rng.randi_range(0, FEMALE_FIRST_NAMES.size() - 1)]

func _new_id() -> String:
	var resident_id := "GL-%06d" % next_id
	next_id += 1
	return resident_id

func _job_for_age(age: int) -> String:
	if age < 1:
		return "nourrisson"
	if age < 6:
		return "petit enfant"
	if age < 18:
		return "élève"
	if age >= 65:
		return "retraité"
	var leadership_roll := _rng.randf()
	if leadership_roll < 0.0001:
		return "président de la République"
	if leadership_roll < 0.001:
		return "ministre"
	if leadership_roll < 0.004:
		return "député" if _rng.randf() < 0.5 else "sénateur"
	return JOBS[_rng.randi_range(0, JOBS.size() - 1)]

func _current_month_index() -> int:
	return game_year * 12 + game_month

func _save_and_notify() -> void:
	save_population()
	population_changed.emit(alive_count, residents.size())
