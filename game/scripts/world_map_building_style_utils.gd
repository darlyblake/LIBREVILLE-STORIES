class_name WorldMapBuildingStyleUtils
extends RefCounted
## Règles déterministes de style architectural basées sur les tags OSM.
## Ces fonctions ne créent aucun nœud et ne modifient pas la géométrie.

static func building_color(kind: String, osm_id: int, props: Dictionary = {}) -> Color:
	# Priorité aux couleurs réellement renseignées dans OSM.
	var tagged := str(props.get("building:colour", props.get("building:color", ""))).strip_edges()
	if not tagged.is_empty():
		return Color.from_string(tagged, Color(0.76, 0.70, 0.62))
	# Palette inspirée de Libreville (enduits clairs, parpaings, planches, ocre) :
	# tons sable, crème, gris ciment, blanc cassé, quelques pastels chauds.
	var palette: Array[Color] = [
		Color(0.82, 0.76, 0.66),  # sable clair
		Color(0.74, 0.70, 0.62),  # beige ciment
		Color(0.88, 0.84, 0.76),  # blanc cassé
		Color(0.66, 0.66, 0.61),  # gris clair
		Color(0.80, 0.70, 0.58),  # ocre doux
		Color(0.90, 0.86, 0.78),  # crème
		Color(0.70, 0.73, 0.68),  # vert-gris très pâle
		Color(0.78, 0.64, 0.52),  # terre cuite claire
		Color(0.72, 0.68, 0.60),  # taupe
		Color(0.84, 0.80, 0.72)   # ivoire
	]
	var selected := palette[abs(osm_id) % palette.size()]
	if kind in ["industrial", "warehouse"]:
		selected = Color(0.58, 0.61, 0.59) if abs(osm_id) % 3 == 0 else Color(0.67, 0.67, 0.62)
	elif kind in ["commercial", "retail", "supermarket", "office"]:
		selected = Color(0.76, 0.76, 0.71) if abs(osm_id) % 2 == 0 else Color(0.82, 0.78, 0.70)
	elif kind in ["apartments", "hotel"]:
		selected = Color(0.80, 0.76, 0.68) if abs(osm_id) % 2 == 0 else Color(0.72, 0.70, 0.64)
	# building:material module la teinte quand aucune couleur explicite n'est fournie.
	var material_tag := str(props.get("building:material", "")).strip_edges().to_lower()
	var material_tint := Color.WHITE
	match material_tag:
		"brick", "bricks":
			material_tint = Color(1.06, 0.90, 0.80)
		"wood", "timber":
			material_tint = Color(1.06, 0.93, 0.80)
		"concrete", "cement_block", "concrete_block":
			material_tint = Color(0.93, 0.95, 0.96)
		"metal", "steel", "aluminium":
			material_tint = Color(0.88, 0.93, 0.97)
		"stone", "limestone":
			material_tint = Color(1.03, 1.00, 0.92)
		"glass":
			material_tint = Color(0.84, 0.94, 1.06)
		"plaster", "render", "stucco":
			material_tint = Color(1.03, 1.02, 0.98)
	return Color(
		clampf(selected.r * material_tint.r, 0.0, 1.0),
		clampf(selected.g * material_tint.g, 0.0, 1.0),
		clampf(selected.b * material_tint.b, 0.0, 1.0),
		selected.a
	)


static func should_use_pitched_roof(kind: String, props: Dictionary, point_count: int) -> bool:
	if point_count != 4:
		return false
	# roof:shape explicite prime sur la règle heuristique par type de bâtiment.
	var shape := str(props.get("roof:shape", "")).strip_edges().to_lower()
	if shape in ["flat", "none"]:
		return false
	if shape == "gabled":
		return true
	# Ces formes nécessitent une géométrie dédiée ; ne pas les dessiner à tort en deux pans.
	if shape in ["hipped", "pyramidal", "skillion", "shed", "round", "dome", "onion"]:
		return false
	return kind in ["house", "residential", "detached", "semidetached_house", "bungalow"]


static func roof_style(kind: String, osm_id: int, props: Dictionary = {}) -> int:
	# Les tags de matériau OSM priment sur la règle visuelle de secours.
	var material_tag := str(props.get("roof:material", "")).to_lower()
	if material_tag in ["metal", "tin", "corrugated_metal", "sheet", "steel", "aluminium"]:
		return 1
	if material_tag in ["concrete", "concrete_plates", "asphalt"]:
		return 2
	if material_tag in ["tile", "tiles", "roof_tiles", "terracotta", "slate"]:
		return 0
	# 0 = tuiles, 1 = tôle nervurée (très répandue à Libreville), 2 = dalle béton.
	# Répartition inspirée des quartiers populaires et résidentiels de la capitale :
	# tôle ondulée dominante, béton sur le tertiaire, tuiles plus rares.
	match kind:
		"industrial", "warehouse", "carport", "shed", "garage", "hangar":
			return 1
		"commercial", "retail", "office", "supermarket", "government", "hospital", "university":
			return 2 if abs(osm_id) % 4 != 0 else 1
		"apartments", "hotel", "dormitory":
			return 1 if abs(osm_id) % 3 != 0 else 2
		"house", "detached", "residential", "semidetached_house", "bungalow":
			# Majorité de tôles, quelques toits en tuiles ou béton.
			var roll: int = abs(osm_id) % 10
			if roll < 7:
				return 1
			if roll < 9:
				return 0
			return 2
		_:
			return 1 if abs(osm_id) % 5 < 3 else (0 if abs(osm_id) % 2 == 0 else 2)


static func roof_color(kind: String, osm_id: int, props: Dictionary = {}) -> Color:
	var tagged := str(props.get("roof:colour", props.get("roof:color", ""))).strip_edges()
	if not tagged.is_empty():
		return Color.from_string(tagged, Color(0.62, 0.34, 0.25))
	# Teintes inspirées de Libreville : tôle grise/rouille, béton clair, tuiles orangées.
	var variation := float(abs(osm_id) % 9) * 0.015
	match roof_style(kind, osm_id, props):
		1:
			# Tôle ondulée : grise neuve ou légèrement oxydée (très courant).
			if abs(osm_id) % 5 == 0:
				return Color(0.62 + variation, 0.48 + variation * 0.6, 0.38 + variation * 0.4)  # rouille douce
			return Color(0.72 + variation * 0.4, 0.74 + variation * 0.3, 0.73 + variation * 0.3)
		2:
			return Color(0.78 + variation * 0.25, 0.79 + variation * 0.25, 0.75 + variation * 0.25)
		_:
			# Tuiles / terre cuite claire, style tropical.
			return Color(0.78 + variation * 0.15, 0.42 + variation * 0.2, 0.28 + variation * 0.15)


static func building_height(kind: String, osm_id: int, props: Dictionary) -> float:
	var tagged_height := WorldMapRoadUtils.parse_osm_height(str(props.get("height", "")))
	if tagged_height >= 2.5 and tagged_height <= 150.0:
		return tagged_height
	var levels := str(props.get("building:levels", "")).to_int()
	if levels > 0 and levels <= 40:
		return clampf(float(levels) * 3.15, 3.0, 120.0)
	# Hauteurs différenciées inspirées de Libreville :
	# cathédrale, bâtiments admin (Bd Triomphal), immeubles, maisons populaires.
	match kind:
		"cathedral", "church", "mosque", "temple":
			return 14.0 + float(abs(osm_id) % 60) / 10.0
		"government", "public", "civic":
			return 16.0 + float(abs(osm_id) % 80) / 8.0
		"university", "hospital", "school", "college":
			return 11.0 + float(abs(osm_id) % 70) / 10.0
		"commercial", "office", "retail":
			return 12.0 + float(abs(osm_id) % 90) / 8.0
		"apartments", "hotel", "dormitory":
			return 10.0 + float(abs(osm_id) % 80) / 8.0
		"house", "detached", "residential", "semidetached_house", "bungalow":
			return 4.2 + float(abs(osm_id) % 28) / 10.0
		"warehouse", "industrial", "supermarket", "hangar":
			return 6.0 + float(abs(osm_id) % 40) / 10.0
		_:
			return 4.0 + float(abs(osm_id) % 40) / 10.0

static func is_baie_des_rois_restaurant_candidate(props: Dictionary, center: Vector2, site_center: Vector2, site_radius: float) -> bool:
	if center.distance_to(site_center) > site_radius:
		return false
	var amenity := str(props.get("amenity", "")).to_lower()
	var building := str(props.get("building", "")).to_lower()
	var shop := str(props.get("shop", "")).to_lower()
	var name := str(props.get("name", "")).to_lower()
	var osm_id := int(props.get("osm_id", 0))
	# Ces cinq empreintes OSM sont les petits commerces/kiosques identifiés sur
	# la promenade nord ; ne pas transformer les immeubles voisins en restaurants.
	if osm_id in [1070652037, 1070652038, 1070652039, 1070652040, 1070652041]:
		return true
	var food_tags := ["restaurant", "cafe", "fast_food", "food_court", "bar"]
	if amenity in food_tags or building in ["restaurant", "catering"]:
		return true
	if building in ["commercial", "retail"] and (shop in ["food", "bakery", "convenience", "restaurant"] or not name.is_empty()):
		return true
	for keyword in ["restaurant", "resto", "cafe", "café", "snack", "pavillon"]:
		if name.contains(keyword):
			return true
	return false

static func facade_window_parameters(edge_length: float, height: float) -> Vector4:
	# x = nombre d'étages, y = nombre de fenêtres, z = demi-largeur,
	# w = demi-hauteur. Les seuils et dimensions reprennent le calcul historique.
	var floors := clampi(int(ceil(height / 3.05)), 1, 8)
	var window_count := clampi(int(floor(edge_length / 4.8)), 1, 6)
	var spacing := edge_length / float(window_count)
	var window_width := clampf(spacing * 0.36, 0.60, 1.20)
	var window_height := 0.92 if floors == 1 else 1.10
	return Vector4(float(floors), float(window_count), window_width * 0.5, window_height * 0.5)

static func facade_door_parameters(edge_length: float) -> Vector3:
	# x = demi-largeur, y = demi-hauteur, z = hauteur du centre.
	# Une arête trop courte ne reçoit pas de porte, comme dans le générateur historique.
	if edge_length < 2.8:
		return Vector3.ZERO
	return Vector3(0.44, 1.05, 1.05)
