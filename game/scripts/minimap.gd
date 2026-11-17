extends Control
## Mini-carte nord en haut, basée sur les routes OSM et la position réelle du joueur.

const SOUTH := 0.355
const WEST := 9.400
const NORTH := 0.445
const EAST := 9.495
const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const MAP_SIZE := 240

var _road_texture: Texture2D
var _player_position := Vector2.ZERO
var _player_inside := false
var _refresh_elapsed := 0.0


func _ready() -> void:
	name = "LibrevilleMinimap"
	custom_minimum_size = Vector2(260, 300)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -278.0
	offset_top = 18.0
	offset_right = -18.0
	offset_bottom = 318.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_road_texture()
	_update_player_marker()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.12:
		return
	_refresh_elapsed = 0.0
	_update_player_marker()
	queue_redraw()


func _build_road_texture() -> void:
	var image := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.10, 0.16, 0.18, 1.0))
	var file := FileAccess.open("res://data/osm/roads.geojson", FileAccess.READ)
	if file == null:
		push_warning("Mini-carte : roads.geojson introuvable.")
		_draw_poi_markers(image)
		_road_texture = ImageTexture.create_from_image(image)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_warning("Mini-carte : GeoJSON des routes invalide.")
		_draw_poi_markers(image)
		_road_texture = ImageTexture.create_from_image(image)
		return

	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var properties: Dictionary = feature.get("properties", {})
		var road_kind := str(properties.get("highway", "residential"))
		var color := _road_color(road_kind)
		var geometry_type := str(geometry.get("type", ""))
		var lines: Array = []
		if geometry_type == "LineString":
			lines.append(geometry.get("coordinates", []))
		elif geometry_type == "MultiLineString":
			lines = geometry.get("coordinates", [])
		else:
			continue
		for line in lines:
			if line.size() < 2:
				continue
			for index in range(line.size() - 1):
				var a := _coordinate_to_pixel(line[index])
				var b := _coordinate_to_pixel(line[index + 1])
				if a.x < -1.0 or a.x > MAP_SIZE or a.y < -1.0 or a.y > MAP_SIZE:
					continue
				if b.x < -1.0 or b.x > MAP_SIZE or b.y < -1.0 or b.y > MAP_SIZE:
					continue
				_draw_image_line(image, Vector2i(roundi(a.x), roundi(a.y)),
					Vector2i(roundi(b.x), roundi(b.y)), color,
					2 if road_kind in ["trunk", "primary", "secondary"] else 1)

	_draw_environment_features(image)
	_draw_poi_markers(image)
	_road_texture = ImageTexture.create_from_image(image)


func _draw_environment_features(image: Image) -> void:
	var file := FileAccess.open("res://data/osm/environment.geojson", FileAccess.READ)
	if file == null:
		push_warning("Mini-carte : environment.geojson introuvable.")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_warning("Mini-carte : GeoJSON environnemental invalide.")
		return
	for feature in data.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var properties: Dictionary = feature.get("properties", {})
		var kind := str(properties.get("environment_kind", ""))
		var color := Color(0.0, 0.0, 0.0, 0.0)
		var thickness := 1
		match kind:
			"coastline":
				color = Color(0.88, 0.73, 0.49, 1.0)
				thickness = 2
			"water", "waterway":
				color = Color(0.24, 0.66, 0.86, 1.0)
			"natural_surface":
				color = Color(0.79, 0.69, 0.49, 1.0)
			_:
				continue
		var geometry_type := str(geometry.get("type", ""))
		var lines: Array = []
		if geometry_type == "LineString":
			lines.append(geometry.get("coordinates", []))
		elif geometry_type == "MultiLineString":
			lines = geometry.get("coordinates", [])
		elif geometry_type == "Polygon":
			var rings: Array = geometry.get("coordinates", [])
			if not rings.is_empty():
				lines.append(rings[0])
		else:
			continue
		for line in lines:
			if line.size() < 2:
				continue
			for index in range(line.size() - 1):
				var a := _coordinate_to_pixel(line[index])
				var b := _coordinate_to_pixel(line[index + 1])
				if a.x < -1.0 or a.x > MAP_SIZE or a.y < -1.0 or a.y > MAP_SIZE:
					continue
				if b.x < -1.0 or b.x > MAP_SIZE or b.y < -1.0 or b.y > MAP_SIZE:
					continue
				_draw_image_line(image, Vector2i(roundi(a.x), roundi(a.y)),
					Vector2i(roundi(b.x), roundi(b.y)), color, thickness)


func _draw_poi_markers(image: Image) -> void:
	var file := FileAccess.open("res://data/osm/pois.geojson", FileAccess.READ)
	if file == null:
		push_warning("Mini-carte : pois.geojson introuvable.")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_warning("Mini-carte : GeoJSON des lieux invalide.")
		return
	var shown := 0
	for feature in data.get("features", []):
		if shown >= 900:
			break
		var geometry: Dictionary = feature.get("geometry", {})
		if str(geometry.get("type", "")) != "Point":
			continue
		var properties: Dictionary = feature.get("properties", {})
		var kind := str(properties.get("amenity", properties.get("healthcare",
			properties.get("shop", properties.get("tourism", properties.get("historic", ""))))))
		var color := _poi_color(kind)
		if kind.is_empty() or color.a < 0.5:
			continue
		var coordinates: Array = geometry.get("coordinates", [])
		if coordinates.size() < 2:
			continue
		var pixel := _coordinate_to_pixel(coordinates)
		if pixel.x < 0.0 or pixel.x >= MAP_SIZE or pixel.y < 0.0 or pixel.y >= MAP_SIZE:
			continue
		_draw_image_disc(image, Vector2i(roundi(pixel.x), roundi(pixel.y)), 2, color)
		shown += 1


func _draw_image_disc(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if x * x + y * y > radius * radius:
				continue
			var px := center.x + x
			var py := center.y + y
			if px >= 0 and px < MAP_SIZE and py >= 0 and py < MAP_SIZE:
				image.set_pixel(px, py, color)


func _poi_color(kind: String) -> Color:
	match kind:
		"hospital", "clinic", "doctors", "pharmacy", "healthcare":
			return Color(1.0, 0.38, 0.34, 1.0)
		"school", "college", "university", "kindergarten":
			return Color(0.35, 0.72, 1.0, 1.0)
		"police", "fire_station", "townhall", "government":
			return Color(0.68, 0.72, 1.0, 1.0)
		"supermarket", "mall", "marketplace", "convenience":
			return Color(1.0, 0.78, 0.28, 1.0)
		"museum", "attraction", "monument", "viewpoint", "hotel":
			return Color(0.40, 0.92, 0.66, 1.0)
		_:
			return Color(0, 0, 0, 0)


func _coordinate_to_pixel(coordinate: Array) -> Vector2:
	var longitude := float(coordinate[0])
	var latitude := float(coordinate[1])
	return Vector2(
		(longitude - WEST) / (EAST - WEST) * float(MAP_SIZE - 1),
		(NORTH - latitude) / (NORTH - SOUTH) * float(MAP_SIZE - 1)
	)


func _draw_image_line(image: Image, start: Vector2i, finish: Vector2i,
		color: Color, thickness: int) -> void:
	var x := start.x
	var y := start.y
	var dx := absi(finish.x - start.x)
	var sx := 1 if start.x < finish.x else -1
	var dy := -absi(finish.y - start.y)
	var sy := 1 if start.y < finish.y else -1
	var error := dx + dy
	while true:
		for ox in range(-thickness + 1, thickness):
			for oy in range(-thickness + 1, thickness):
				var px := x + ox
				var py := y + oy
				if px >= 0 and px < MAP_SIZE and py >= 0 and py < MAP_SIZE:
					image.set_pixel(px, py, color)
		if x == finish.x and y == finish.y:
			break
		var twice_error := 2 * error
		if twice_error >= dy:
			error += dy
			x += sx
		if twice_error <= dx:
			error += dx
			y += sy


func _road_color(kind: String) -> Color:
	if kind in ["motorway", "trunk", "primary"]:
		return Color(0.98, 0.72, 0.34, 1.0)
	if kind in ["secondary", "tertiary"]:
		return Color(0.83, 0.85, 0.78, 1.0)
	return Color(0.48, 0.61, 0.62, 1.0)


func _update_player_marker() -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		_player_inside = false
		return
	var latitude := CENTER_LAT - player.global_position.z / METERS_PER_DEG_LAT
	var longitude := CENTER_LON + player.global_position.x / (METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT)))
	_player_position = Vector2(
		(longitude - WEST) / (EAST - WEST) * float(MAP_SIZE - 1),
		(NORTH - latitude) / (NORTH - SOUTH) * float(MAP_SIZE - 1)
	)
	_player_inside = longitude >= WEST and longitude <= EAST and latitude >= SOUTH and latitude <= NORTH


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.055, 0.07, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.60, 0.72, 0.78, 0.95), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), "LIBREVILLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.94, 0.97, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(235, 20), "N", HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.94, 0.97, 1.0))
	var map_rect := Rect2(Vector2(10, 30), Vector2(240, 240))
	if _road_texture != null:
		draw_texture_rect(_road_texture, map_rect, false)
	if _player_inside:
		var marker := map_rect.position + _player_position
		draw_circle(marker, 6.0, Color(0.08, 0.18, 0.30, 1.0))
		draw_circle(marker, 4.0, Color(0.25, 0.78, 1.0, 1.0))
		draw_arc(marker, 8.0, 0.0, TAU, 24, Color(0.95, 0.98, 1.0, 1.0), 1.2)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(12, 270), "Joueur hors carte", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.98, 0.78, 0.48))
	draw_circle(Vector2(17, 287), 3.0, Color(1.0, 0.78, 0.28, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(26, 291), "Lieux importants", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.88, 0.92, 0.96))
