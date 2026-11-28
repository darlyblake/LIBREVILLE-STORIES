extends Node3D
class_name GrassGenerator
## Générateur d'herbe 3D légère pour les parcelles herbeuses OSM.
## Les touffes sont de vrais petits rubans triangulés, regroupés dans un MultiMesh
## pour limiter les draw calls sur les configurations modestes.

const MAX_GRASS_CLUMPS := 3200
const MAX_CLUMPS_PER_PATCH := 900
const DENSITY_PER_SQUARE_METER := 0.72
const MIN_BLADE_SPACING := 0.22

var _transforms: Array[Transform3D] = []
var _colors: Array[Color] = []
var _built := false


func add_patch(points: PackedVector2Array, osm_id: int, relief_center: Vector2, relief_radius: float, kind: String, ground_sampler: Callable = Callable(), road_exclusion: Callable = Callable()) -> void:
	if _built or points.size() < 3 or _transforms.size() >= MAX_GRASS_CLUMPS:
		return

	var min_x := points[0].x
	var max_x := points[0].x
	var min_z := points[0].y
	var max_z := points[0].y
	var twice_area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		min_x = minf(min_x, a.x)
		max_x = maxf(max_x, a.x)
		min_z = minf(min_z, a.y)
		max_z = maxf(max_z, a.y)
		twice_area += a.x * b.y - b.x * a.y

	var area := absf(twice_area) * 0.5
	if area < 12.0:
		return

	var remaining := MAX_GRASS_CLUMPS - _transforms.size()
	var target := mini(ceili(area * DENSITY_PER_SQUARE_METER), MAX_CLUMPS_PER_PATCH)
	target = mini(target, remaining)
	if target <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(osm_id) * 7919 + 20261118
	var min_spacing_sq := MIN_BLADE_SPACING * MIN_BLADE_SPACING
	var added := 0
	var attempts := 0
	var patch_positions: Array[Vector2] = []
	while added < target and attempts < target * 28:
		attempts += 1
		var candidate := Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_z, max_z))
		if not Geometry2D.is_point_in_polygon(candidate, points):
			continue
		if road_exclusion.is_valid() and bool(road_exclusion.call(candidate, 1.8)):
			continue

		var crowded := false
		for previous in patch_positions:
			if candidate.distance_squared_to(previous) < min_spacing_sq:
				crowded = true
				break
		if crowded:
			continue

		patch_positions.append(candidate)
		var ground_y := float(ground_sampler.call(candidate.x, candidate.y)) if ground_sampler.is_valid() else _relief_height(candidate, relief_center, relief_radius, kind)
		var height := rng.randf_range(0.24, 0.48)
		var width := rng.randf_range(0.72, 1.24)
		var yaw := rng.randf_range(0.0, TAU)
		var scale := Vector3(width, height / 0.36, width)
		var basis := Basis(Vector3.UP, yaw).scaled(scale)
		_transforms.append(Transform3D(basis, Vector3(candidate.x, ground_y + 0.008, candidate.y)))
		_colors.append(_grass_palette_color(rng))
		added += 1


func build() -> void:
	if _built:
		return
	_built = true
	if _transforms.is_empty():
		return

	var grass_mesh := _create_blade_cluster_mesh()
	var grass_material := StandardMaterial3D.new()
	grass_material.vertex_color_use_as_albedo = true
	grass_material.roughness = 1.0
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	grass_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Des MultiMeshes indépendants par secteur évitent un unique volume d'herbe
	# qui englobe toute la carte et reste considéré visible en permanence.
	var sectors: Dictionary = {}
	for index in range(_transforms.size()):
		var origin := _transforms[index].origin
		var key := Vector2i(floori(origin.x / 800.0), floori(origin.z / 800.0))
		if not sectors.has(key):
			sectors[key] = []
		sectors[key].append(index)
	for key in sectors.keys():
		var tile_origin := Vector3((float(key.x) + 0.5) * 800.0, 0.0, (float(key.y) + 0.5) * 800.0)
		var indices: Array = sectors[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = grass_mesh
		multimesh.instance_count = indices.size()
		for local_index in range(indices.size()):
			var source_index: int = indices[local_index]
			var local_transform: Transform3D = _transforms[source_index]
			local_transform.origin -= tile_origin
			multimesh.set_instance_transform(local_index, local_transform)
			multimesh.set_instance_color(local_index, _colors[source_index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Grass_Sector_%d_%d" % [key.x, key.y]
		instance.multimesh = multimesh
		instance.position = tile_origin
		instance.material_override = grass_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(instance)
		# Même grille de 800 m que les routes, bâtiments et autres couches.
		# Le gestionnaire masque le MultiMesh et coupe ses éventuelles collisions
		# avec le secteur lorsqu'il sort du rayon actif.
		var world_map := get_parent()
		var streaming_manager := world_map.get_parent().get_node_or_null("WorldStreamingManager") if world_map != null and world_map.get_parent() != null else null
		if streaming_manager != null:
			streaming_manager.register_node(instance, "Vegetation", tile_origin)
	print("LIBREVILLE STORIES | touffes d'herbe réparties en %d secteurs de 800 m (%d touffes)" % [sectors.size(), _transforms.size()])


func _create_blade_cluster_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Trois brins croisés par touffe. Chaque brin est une lame effilée
	# composée de deux sections pour donner une silhouette moins plate.
	for angle_degrees in [0.0, 60.0, 120.0]:
		var angle := deg_to_rad(angle_degrees)
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.045
		var forward := Vector3(-sin(angle), 0.0, cos(angle))
		var base_left := -side
		var base_right := side
		var middle_left := forward * 0.045 - side * 0.026 + Vector3.UP * 0.19
		var middle_right := forward * 0.045 + side * 0.026 + Vector3.UP * 0.19
		var tip := forward * 0.11 + Vector3.UP * 0.36
		var dark := Color(0.045, 0.16, 0.055, 1.0)
		var mid := Color(0.12, 0.34, 0.095, 1.0)
		var light := Color(0.25, 0.48, 0.13, 1.0)
		_add_triangle(surface, base_left, middle_left, middle_right, dark, mid, mid)
		_add_triangle(surface, base_left, middle_right, base_right, dark, mid, dark)
		_add_triangle(surface, middle_left, tip, middle_right, mid, light, mid)
	surface.generate_normals()
	var mesh := surface.commit()
	return mesh if mesh != null else ArrayMesh.new()


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color_a: Color, color_b: Color, color_c: Color) -> void:
	surface.set_color(color_a)
	surface.add_vertex(a)
	surface.set_color(color_b)
	surface.add_vertex(b)
	surface.set_color(color_c)
	surface.add_vertex(c)


func _grass_palette_color(rng: RandomNumberGenerator) -> Color:
	var palette: Array[Color] = [
		Color(0.82, 0.96, 0.72),
		Color(0.70, 0.88, 0.58),
		Color(0.91, 0.94, 0.66),
		Color(0.62, 0.83, 0.52),
		Color(0.78, 0.91, 0.62),
		Color(0.55, 0.76, 0.43)
	]
	return palette[rng.randi_range(0, palette.size() - 1)]


func _relief_height(point: Vector2, center: Vector2, radius: float, kind: String) -> float:
	var max_height := 0.65 if kind == "green_space" else 0.38
	var normalized_distance := clampf(point.distance_to(center) / maxf(radius, 1.0), 0.0, 1.0)
	var mound := pow(1.0 - normalized_distance, 1.45)
	var broad := sin(point.x * 0.075 + center.y * 0.031) * cos(point.y * 0.082 - center.x * 0.027)
	var fine := sin(point.x * 0.19 + point.y * 0.13) * 0.35
	var variation := (broad * 0.045 + fine * 0.018) * mound
	return maxf(0.012, 0.035 + max_height * mound + variation)
