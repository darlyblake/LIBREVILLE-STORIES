extends Node3D
## Générateur procédural de tabliers routiers à partir des ways OSM explicitement tagués bridge.
## Les dimensions non renseignées par OSM restent des paramètres provisoires, à recaler par ouvrage.

const DEFAULT_CLEARANCE := 4.5
const RAMP_LENGTH := 18.0
const MAX_SAMPLE_STEP := 6.0
const SUPPORT_SPACING := 22.0

var _deck_material: Material
var _concrete_material: StandardMaterial3D
var _rail_material: StandardMaterial3D

func build(features: Array, geo_to_world: Callable, terrain_height: Callable, deck_material: Material) -> int:
	_deck_material = deck_material
	_concrete_material = _make_material(Color(0.48, 0.48, 0.46), 0.94)
	_rail_material = _make_material(Color(0.28, 0.30, 0.30), 0.72)
	var built := 0
	for feature in features:
		var props: Dictionary = feature.get("properties", {})
		if not _is_bridge_road(props):
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var lines: Array = []
		match str(geometry.get("type", "")):
			"LineString":
				lines.append(geometry.get("coordinates", []))
			"MultiLineString":
				lines = geometry.get("coordinates", [])
			_:
				continue
		for line in lines:
			var points: Array[Vector3] = []
			for coordinate in line:
				if not (coordinate is Array) or coordinate.size() < 2:
					continue
				var world_point: Vector3 = geo_to_world.call(coordinate)
				if points.is_empty() or Vector2(points[-1].x - world_point.x, points[-1].z - world_point.z).length() > 0.15:
					points.append(world_point)
			if points.size() < 2:
				continue
			var length := _polyline_length(points)
			if length < 8.0:
				continue
			var width := _road_width(props)
			var clearance := _bridge_clearance(props)
			_build_span(points, width, clearance, props, terrain_height)
			built += 1
	print("LIBREVILLE STORIES | tabliers OSM construits : %d (hauteur par défaut %.1f m si non renseignée)" % [built, DEFAULT_CLEARANCE])
	return built


func _is_bridge_road(props: Dictionary) -> bool:
	var bridge := str(props.get("bridge", "")).to_lower()
	var man_made := str(props.get("man_made", "")).to_lower()
	return str(props.get("highway", "")).strip_edges() != "" and (bridge not in ["", "no", "false", "0"] or man_made == "bridge")


func _road_width(props: Dictionary) -> float:
	var lanes := maxf(1.0, str(props.get("lanes", "2")).to_float())
	var width_tag := str(props.get("width", "")).replace("m", "").strip_edges()
	if width_tag.is_valid_float():
		return clampf(width_tag.to_float(), 4.0, 28.0)
	return clampf(lanes * 3.35 + 1.4, 6.0, 22.0)


func _bridge_clearance(props: Dictionary) -> float:
	for key in ["height", "bridge:height", "maxheight:physical"]:
		var value := str(props.get(key, "")).replace("m", "").strip_edges()
		if value.is_valid_float():
			return clampf(value.to_float(), 2.5, 18.0)
	return DEFAULT_CLEARANCE


func _polyline_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).length()
	return total


func _build_span(source_points: Array[Vector3], width: float, clearance: float, props: Dictionary, terrain_height: Callable) -> void:
	var points := _densify(source_points)
	if points.size() < 2:
		return
	var length := _polyline_length(points)
	var endpoint_ground := maxf(
		float(terrain_height.call(points[0].x, points[0].z)),
		float(terrain_height.call(points[-1].x, points[-1].z))
	)
	var deck_y := endpoint_ground + clearance
	var extended: Array[Vector3] = []
	var first_dir := Vector2(points[1].x - points[0].x, points[1].z - points[0].z).normalized()
	var last_dir := Vector2(points[-1].x - points[-2].x, points[-1].z - points[-2].z).normalized()
	var first_ground := float(terrain_height.call(points[0].x - first_dir.x * RAMP_LENGTH, points[0].z - first_dir.y * RAMP_LENGTH))
	var last_ground := float(terrain_height.call(points[-1].x + last_dir.x * RAMP_LENGTH, points[-1].z + last_dir.y * RAMP_LENGTH))
	extended.append(Vector3(points[0].x - first_dir.x * RAMP_LENGTH, first_ground + 0.16, points[0].z - first_dir.y * RAMP_LENGTH))
	for point in points:
		extended.append(Vector3(point.x, deck_y, point.z))
	extended.append(Vector3(points[-1].x + last_dir.x * RAMP_LENGTH, last_ground + 0.16, points[-1].z + last_dir.y * RAMP_LENGTH))

	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var underside := SurfaceTool.new()
	underside.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(extended.size() - 1):
		var a := extended[i]
		var b := extended[i + 1]
		var delta := Vector2(b.x - a.x, b.z - a.z)
		var segment_length := delta.length()
		if segment_length < 0.05:
			continue
		var side := Vector2(-delta.y, delta.x).normalized() * width * 0.5
		var left_a := Vector3(a.x + side.x, a.y, a.z + side.y)
		var right_a := Vector3(a.x - side.x, a.y, a.z - side.y)
		var left_b := Vector3(b.x + side.x, b.y, b.z + side.y)
		var right_b := Vector3(b.x - side.x, b.y, b.z - side.y)
		_add_quad(deck, left_a + Vector3.UP * 0.12, right_a + Vector3.UP * 0.12, right_b + Vector3.UP * 0.12, left_b + Vector3.UP * 0.12)
		_add_quad(underside, left_a - Vector3.UP * 0.34, left_b - Vector3.UP * 0.34, right_b - Vector3.UP * 0.34, right_a - Vector3.UP * 0.34)
		_add_box_strip(rails, left_a + Vector3.UP * 0.62, left_b + Vector3.UP * 0.62, 0.16)
		_add_box_strip(rails, right_a + Vector3.UP * 0.62, right_b + Vector3.UP * 0.62, 0.16)
		_add_box_strip(rails, left_a + Vector3.UP * 1.08, left_b + Vector3.UP * 1.08, 0.055)
		_add_box_strip(rails, right_a + Vector3.UP * 1.08, right_b + Vector3.UP * 1.08, 0.055)
		_add_box_strip(rails, left_a + Vector3.UP * 0.84, left_b + Vector3.UP * 0.84, 0.055)
		_add_box_strip(rails, right_a + Vector3.UP * 0.84, right_b + Vector3.UP * 0.84, 0.055)

	_commit_mesh(deck, "OSM_Bridge_Deck", _deck_material, true)
	_commit_mesh(underside, "OSM_Bridge_Underside", _concrete_material, false)
	_commit_mesh(rails, "OSM_Bridge_Guardrails", _rail_material, false)
	_build_supports(points, width, deck_y, terrain_height, length)


func _build_supports(points: Array[Vector3], width: float, deck_y: float, terrain_height: Callable, total_length: float) -> void:
	if total_length < 26.0:
		return
	var travelled := 0.0
	var next_support := SUPPORT_SPACING
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := Vector2(b.x - a.x, b.z - a.z).length()
		if segment < 0.01:
			continue
		while next_support <= travelled + segment and next_support < total_length - 8.0:
			var t := (next_support - travelled) / segment
			var p := a.lerp(b, t)
			var ground := float(terrain_height.call(p.x, p.z))
			var height := deck_y - ground - 0.34
			if height > 1.2:
				_add_pier(p, height, width)
			next_support += SUPPORT_SPACING
		travelled += segment


func _add_pier(point: Vector3, height: float, deck_width: float) -> void:
	var pier := MeshInstance3D.new()
	pier.name = "OSM_Bridge_Pier"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.68
	mesh.height = height
	mesh.radial_segments = 10
	pier.mesh = mesh
	pier.material_override = _concrete_material
	pier.position = Vector3(point.x, point.y - height * 0.5 - 0.20, point.z)
	add_child(pier)


func _densify(source: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = [source[0]]
	for i in range(source.size() - 1):
		var a := source[i]
		var b := source[i + 1]
		var distance := Vector2(b.x - a.x, b.z - a.z).length()
		var steps := maxi(1, ceili(distance / MAX_SAMPLE_STEP))
		for step in range(1, steps + 1):
			result.append(a.lerp(b, float(step) / float(steps)))
	return result


func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _add_box_strip(surface: SurfaceTool, a: Vector3, b: Vector3, thickness: float) -> void:
	var direction := Vector2(b.x - a.x, b.z - a.z)
	if direction.length() < 0.01:
		return
	var side := direction.normalized().orthogonal() * thickness * 0.5
	var low_a := a - Vector3.UP * thickness * 0.5
	var low_b := b - Vector3.UP * thickness * 0.5
	var high_a := a + Vector3.UP * thickness * 0.5
	var high_b := b + Vector3.UP * thickness * 0.5
	var a_left := Vector3(low_a.x + side.x, low_a.y, low_a.z + side.y)
	var a_right := Vector3(low_a.x - side.x, low_a.y, low_a.z - side.y)
	var b_left := Vector3(low_b.x + side.x, low_b.y, low_b.z + side.y)
	var b_right := Vector3(low_b.x - side.x, low_b.y, low_b.z - side.y)
	var a_left_top := Vector3(high_a.x + side.x, high_a.y, high_a.z + side.y)
	var a_right_top := Vector3(high_a.x - side.x, high_a.y, high_a.z - side.y)
	var b_left_top := Vector3(high_b.x + side.x, high_b.y, high_b.z + side.y)
	var b_right_top := Vector3(high_b.x - side.x, high_b.y, high_b.z - side.y)
	_add_quad(surface, a_left, a_left_top, b_left_top, b_left)
	_add_quad(surface, b_right, b_right_top, a_right_top, a_right)
	_add_quad(surface, a_left_top, a_right_top, b_right_top, b_left_top)


func _commit_mesh(surface: SurfaceTool, mesh_name: String, material: Material, with_collision: bool) -> void:
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	if not with_collision:
		return
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	if shape == null:
		return
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = mesh_name + "_Collision"
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
