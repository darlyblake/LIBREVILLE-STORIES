class_name WorldMapRoadUtils
extends RefCounted
## Fonctions déterministes de lecture des tags OSM liés aux chaussées.

static func road_lane_count(props: Dictionary) -> int:
	# lanes:both_ways décrit une voie centrale partagée, pas le total des voies.
	var forward := str(props.get("lanes:forward", "")).to_int()
	var backward := str(props.get("lanes:backward", "")).to_int()
	if forward > 0 or backward > 0:
		return clampi(forward + backward, 1, 8)
	return clampi(str(props.get("lanes", "")).to_int(), 0, 8)


static func road_is_oneway(props: Dictionary) -> bool:
	var value := str(props.get("oneway", "")).to_lower()
	return value in ["yes", "true", "1", "-1"]


static func road_has_bridge_structure(props: Dictionary) -> bool:
	# layer décrit une relation topologique, pas une hauteur mesurée.
	# Une voie n'est reconnue comme ouvrage que si bridge/man_made le confirme.
	var bridge_tag := str(props.get("bridge", "")).to_lower()
	var structure_tag := str(props.get("man_made", "")).to_lower()
	return bridge_tag in ["yes", "true", "1", "viaduct", "aqueduct", "movable"] or structure_tag == "bridge"


static func road_bridge_height(props: Dictionary) -> float:
	# Aucune hauteur générique ne doit être inventée à partir de layer=1.
	# Les tags OSM bridge/layer identifient l'ouvrage, mais ne donnent pas
	# l'altitude du tablier par rapport au terrain local.
	# La hauteur n'est activée que par une mesure dédiée, ajoutée après
	# relevé du profil longitudinal de l'ouvrage concerné.
	var measured_profile_height := str(props.get("game:deck_height_m", "")).to_float()
	if measured_profile_height > 0.0 and road_has_bridge_structure(props):
		return measured_profile_height
	return 0.0


static func parse_osm_height(raw_value: String) -> float:
	# OSM accepte des hauteurs en mètres, centimètres ou pieds.
	# Sans unité explicite, la convention OSM est le mètre.
	var value := raw_value.strip_edges().to_lower().replace(",", ".")
	if value.is_empty():
		return -1.0
	var multiplier := 1.0
	if value.ends_with("ft") or value.ends_with("feet"):
		multiplier = 0.3048
		value = value.replace("feet", "").replace("ft", "").strip_edges()
	elif value.ends_with("cm"):
		multiplier = 0.01
		value = value.replace("cm", "").strip_edges()
	elif value.ends_with("m"):
		value = value.substr(0, value.length() - 1).strip_edges()
	elif value.ends_with("'"):
		multiplier = 0.3048
		value = value.substr(0, value.length() - 1).strip_edges()
	var parsed := value.to_float()
	if parsed <= 0.0:
		return -1.0
	return parsed * multiplier


static func road_width(kind: String, props: Dictionary = {}) -> float:
	# Les voies OSM priment sur les largeurs manifestement incohérentes.
	# Ex. Libreville : width=5 avec lanes=2 ne peut pas contenir deux voies.
	var lanes := road_lane_count(props)
	var tagged_width := parse_osm_height(str(props.get("width", "")))
	if tagged_width >= 1.5 and tagged_width <= 40.0:
		if lanes == 0 or tagged_width >= float(lanes) * 2.65:
			return tagged_width
	if lanes >= 1:
		return clampf(float(lanes) * 3.4 + 1.2, 3.5, 28.0)
	match kind:
		"motorway", "trunk":
			return 8.0 if road_is_oneway(props) else 16.0
		"primary":
			return 7.2 if road_is_oneway(props) else 13.6
		"secondary":
			return 4.8 if road_is_oneway(props) else 9.2
		"tertiary":
			return 7.0
		"residential", "unclassified":
			return 5.5
		"service":
			return 3.6
		"motorway_link", "trunk_link", "primary_link":
			return 7.0
		"secondary_link":
			return 6.0
		"tertiary_link":
			return 5.5
		"construction":
			return 6.0
		"track":
			return 3.5
		"pedestrian":
			return 4.0
		"footway", "path", "steps", "cycleway":
			return 1.8
		_:
			return 5.0
