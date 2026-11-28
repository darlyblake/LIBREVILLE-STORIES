class_name WorldMapColorUtils
extends RefCounted
## Palettes et règles déterministes de rendu pour les couches de la carte.
## Aucun accès à la scène, aux ressources ou aux données globales.

static func environment_color(kind: String) -> Color:
	match kind:
		"water", "waterway":
			return Color(0.12, 0.42, 0.62)   # mer / rivières plus visibles
		"coastline":
			return Color(0.86, 0.76, 0.52)   # bande sable littoral
		"vegetation":
			return Color(0.16, 0.38, 0.22)
		"green_space":
			return Color(0.24, 0.46, 0.24)
		"natural_surface":
			return Color(0.76, 0.68, 0.49)  # sable chaud des plages de Libreville
		_:
			return Color(0.34, 0.42, 0.30)

static func poi_color(kind: String) -> Color:
	match kind:
		"city", "town", "suburb", "neighbourhood", "quarter", "district", "village", "hamlet":
			return Color(1.0, 0.88, 0.58)
		"hospital", "clinic", "doctors", "pharmacy", "healthcare":
			return Color(1.0, 0.48, 0.43)
		"school", "college", "university", "kindergarten", "school_building":
			return Color(0.48, 0.72, 1.0)
		"police", "fire_station", "government", "townhall", "civic", "administrative":
			return Color(0.72, 0.78, 1.0)
		"marketplace", "supermarket", "mall", "convenience":
			return Color(1.0, 0.82, 0.42)
		"hotel", "museum", "attraction", "viewpoint":
			return Color(0.60, 0.90, 0.72)
		_:
			return Color(0.96, 0.96, 0.90)

static func road_color(kind: String, props: Dictionary = {}) -> Color:
	# Palette asphalte plus propre / GTA, teintée par la texture procédurale.
	var surface_tag := str(props.get("surface", "")).to_lower()
	match surface_tag:
		"asphalt", "paved":
			return Color(0.55, 0.56, 0.55)
		"concrete":
			return Color(0.72, 0.72, 0.70)
		"paving_stones", "sett":
			return Color(0.68, 0.66, 0.60)
		"gravel", "fine_gravel":
			return Color(0.62, 0.58, 0.50)
		"ground", "dirt", "earth", "unpaved":
			return Color(0.58, 0.50, 0.40)
	match kind:
		"motorway", "trunk":
			return Color(0.48, 0.50, 0.50)   # axes principaux plus sombres
		"primary":
			return Color(0.52, 0.53, 0.53)
		"secondary":
			return Color(0.56, 0.57, 0.56)
		"tertiary":
			return Color(0.58, 0.59, 0.57)
		"residential", "unclassified":
			return Color(0.60, 0.60, 0.58)
		"service":
			return Color(0.58, 0.58, 0.56)
		"footway", "path", "steps", "cycleway":
			return Color(0.70, 0.66, 0.58)
		_:
			return Color(0.58, 0.58, 0.56)

static func road_surface_key(kind: String, props: Dictionary) -> String:
	var surface_tag := str(props.get("surface", "")).to_lower()
	if surface_tag in ["unpaved", "ground", "dirt", "earth", "compacted", "gravel", "fine_gravel", "sand", "mud", "grass", "pebblestone"]:
		return "dirt"
	if kind in ["track", "construction"]:
		return "dirt"
	var smoothness := str(props.get("smoothness", "")).to_lower()
	if surface_tag in ["", "asphalt", "paved"] and smoothness in ["bad", "very_bad", "horrible", "very_horrible", "impassable"]:
		return "damaged"
	if surface_tag in ["concrete", "paving_stones", "sett", "cobblestone", "concrete:plates", "concrete:lanes", "paved_stones"]:
		return "paving"
	if kind in ["footway", "pedestrian", "steps", "cycleway"]:
		return "paving"
	if kind == "path" and surface_tag == "":
		return "dirt"
	return "asphalt"

static func road_tint(kind: String, props: Dictionary, surface_key: String) -> Color:
	var shade := 0.95
	var wear := 1.0
	if surface_key == "asphalt":
		match kind:
			"motorway", "trunk", "motorway_link", "trunk_link":
				shade = 0.84
				wear = 0.35
			"primary", "primary_link":
				shade = 0.88
				wear = 0.45
			"secondary", "secondary_link":
				shade = 0.91
				wear = 0.6
			"tertiary", "tertiary_link":
				shade = 0.94
				wear = 0.8
			"service":
				shade = 1.0
				wear = 1.3
			_:
				shade = 0.97
				wear = 1.0
	elif surface_key == "dirt":
		shade = 1.0
	elif surface_key == "damaged":
		shade = 0.92
		wear = 1.35
	var smoothness := str(props.get("smoothness", "")).to_lower()
	if smoothness in ["bad", "very_bad", "horrible", "very_horrible", "impassable"]:
		shade *= 0.86
		wear += 0.4
	elif smoothness == "intermediate":
		shade *= 0.94
		wear += 0.2
	# Légère variation déterministe par route : casse l'uniformité sans aléatoire.
	var id_value := str(props.get("osm_id", "0")).to_int()
	shade = clampf(shade + (float(id_value % 17) / 16.0 - 0.5) * 0.08, 0.6, 1.0)
	wear = clampf(wear + (float(id_value % 11) / 10.0 - 0.5) * 0.3, 0.1, 1.5)
	if surface_key == "dirt":
		return Color(shade, shade * 0.95, shade * 0.90)
	if surface_key == "damaged":
		return Color(shade, shade * 0.98, shade * 0.94, wear)
	if surface_key == "paving":
		# La texture asphalt_floor est beige : on la refroidit pour obtenir un béton gris.
		return Color(shade * 0.80, shade * 0.85, shade * 0.92)
	# L'alpha porte le niveau d'usure lu par le shader d'asphalte.
	return Color(shade, shade, shade, wear)
