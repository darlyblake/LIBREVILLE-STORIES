extends Control
## Mini-carte style GTA : zone locale centrée sur le joueur (pas toute la ville).
## Affiche les routes proches, le littoral et un marqueur de position clair.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const MAP_SIZE := 220
## Rayon visible autour du joueur (mètres) — style radar GTA.
const VIEW_RADIUS_M := 650.0

var _road_segments: Array = []  # [{a: Vector2, b: Vector2, kind: String}]
var _water_segments: Array = []
var _player_world := Vector2.ZERO
var _player_heading := 0.0
var _refresh_elapsed := 0.0
var _data_ready := false


func _ready() -> void:
	name = "LibrevilleMinimap"
	custom_minimum_size = Vector2(240, 270)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -258.0
	offset_top = 16.0
	offset_right = -18.0
	offset_bottom = 286.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_road_segments()
	_load_water_segments()
	_data_ready = true


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.08:
		return
	_refresh_elapsed = 0.0
	_update_player()
	queue_redraw()


func _load_road_segments() -> void:
	_road_segments.clear()
	var file := FileAccess.open("res://data/osm/roads.geojson", FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		var road_kind := str(props.get("highway", "residential"))
		var lines: Array = []
		match str(geometry.get("type", "")):
			"LineString":
				lines.append(geometry.get("coordinates", []))
			"MultiLineString":
				lines = geometry.get("coordinates", [])
			_:
				continue
		for line in lines:
			if line.size() < 2:
				continue
			for i in range(line.size() - 1):
				var a_geo: Array = line[i]
				var b_geo: Array = line[i + 1]
				if a_geo.size() < 2 or b_geo.size() < 2:
					continue
				var a := _geo_to_world_xz(a_geo)
				var b := _geo_to_world_xz(b_geo)
				_road_segments.append({"a": a, "b": b, "kind": road_kind})


func _load_water_segments() -> void:
	_water_segments.clear()
	var file := FileAccess.open("res://data/osm/environment.geojson", FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		var kind := str(props.get("environment_kind", ""))
		if kind not in ["coastline", "water", "waterway"]:
			continue
		var lines: Array = []
		match str(geometry.get("type", "")):
			"LineString":
				lines.append(geometry.get("coordinates", []))
			"MultiLineString":
				lines = geometry.get("coordinates", [])
			"Polygon":
				var rings: Array = geometry.get("coordinates", [])
				if not rings.is_empty():
					lines.append(rings[0])
			_:
				continue
		for line in lines:
			if line.size() < 2:
				continue
			for i in range(line.size() - 1):
				var a_geo: Array = line[i]
				var b_geo: Array = line[i + 1]
				if a_geo.size() < 2 or b_geo.size() < 2:
					continue
				_water_segments.append({
					"a": _geo_to_world_xz(a_geo),
					"b": _geo_to_world_xz(b_geo),
					"kind": kind
				})


func _geo_to_world_xz(coordinate: Array) -> Vector2:
	var lon := float(coordinate[0])
	var lat := float(coordinate[1])
	var x := (lon - CENTER_LON) * METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT))
	var z := (CENTER_LAT - lat) * METERS_PER_DEG_LAT
	return Vector2(x, z)


func _update_player() -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		return
	_player_world = Vector2(player.global_position.x, player.global_position.z)
	_player_heading = player.global_rotation.y


func _world_to_map(world: Vector2) -> Vector2:
	# Convertit une position monde (XZ) en pixel local centré sur le joueur.
	var relative := world - _player_world
	var scale := float(MAP_SIZE) / (VIEW_RADIUS_M * 2.0)
	# Nord en haut : -Z vers le haut de l'écran.
	return Vector2(
		MAP_SIZE * 0.5 + relative.x * scale,
		MAP_SIZE * 0.5 + relative.y * scale
	)


func _road_color(kind: String) -> Color:
	if kind in ["motorway", "trunk", "primary"]:
		return Color(0.95, 0.78, 0.35, 1.0)
	if kind in ["secondary", "tertiary"]:
		return Color(0.82, 0.84, 0.78, 1.0)
	return Color(0.45, 0.55, 0.56, 1.0)


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	# Fond sombre semi-transparent style GTA.
	draw_rect(panel, Color(0.04, 0.07, 0.09, 0.92), true)
	draw_rect(panel, Color(0.55, 0.70, 0.78, 0.90), false, 2.0)

	var map_origin := Vector2(10, 28)
	var map_rect := Rect2(map_origin, Vector2(MAP_SIZE, MAP_SIZE))

	# Clip circulaire approximatif via fond.
	draw_rect(map_rect, Color(0.08, 0.14, 0.16, 1.0), true)

	if not _data_ready:
		draw_string(ThemeDB.fallback_font, Vector2(20, 140), "Chargement...", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.85, 0.9))
		return

	# Eau / littoral dans la zone visible.
	for seg in _water_segments:
		var a: Vector2 = seg.a
		var b: Vector2 = seg.b
		if a.distance_to(_player_world) > VIEW_RADIUS_M * 1.4 and b.distance_to(_player_world) > VIEW_RADIUS_M * 1.4:
			continue
		var pa := map_origin + _world_to_map(a)
		var pb := map_origin + _world_to_map(b)
		var col := Color(0.25, 0.55, 0.78, 1.0) if seg.kind != "coastline" else Color(0.85, 0.72, 0.48, 1.0)
		var thick := 2.5 if seg.kind == "coastline" else 1.8
		draw_line(pa, pb, col, thick)

	# Routes proches uniquement.
	for seg in _road_segments:
		var a: Vector2 = seg.a
		var b: Vector2 = seg.b
		if a.distance_to(_player_world) > VIEW_RADIUS_M * 1.35 and b.distance_to(_player_world) > VIEW_RADIUS_M * 1.35:
			continue
		var pa := map_origin + _world_to_map(a)
		var pb := map_origin + _world_to_map(b)
		var kind: String = seg.kind
		var thick := 2.4 if kind in ["motorway", "trunk", "primary"] else (1.6 if kind in ["secondary", "tertiary"] else 1.1)
		draw_line(pa, pb, _road_color(kind), thick)

	# Marqueur joueur au centre (toujours).
	var center := map_origin + Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5)
	draw_circle(center, 7.0, Color(0.05, 0.12, 0.20, 1.0))
	draw_circle(center, 5.0, Color(0.20, 0.85, 1.0, 1.0))
	# Petite flèche de direction.
	var dir := Vector2(-sin(_player_heading), -cos(_player_heading))
	var tip := center + dir * 12.0
	draw_line(center, tip, Color(1.0, 0.95, 0.4, 1.0), 2.0)
	draw_circle(tip, 2.5, Color(1.0, 0.92, 0.35, 1.0))

	# Cadre et labels.
	draw_rect(map_rect, Color(0.60, 0.75, 0.82, 0.85), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(14, 18), "LIBREVILLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.96, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 28, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.95, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(14, size.y - 8), "Zone locale · 650 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.70, 0.78, 0.82))
