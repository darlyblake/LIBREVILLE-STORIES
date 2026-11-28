extends SceneTree

const Geometry = preload("res://game/scripts/world_map_geometry_utils.gd")


func _initialize() -> void:
	_test_horizontal_crossings()
	_test_diagonal_corner_crossing()
	_test_negative_coordinates()
	_test_reverse_direction()
	_test_invalid_inputs()
	_test_polygon_sector_coverage()
	_test_triangle_sector_clipping()
	_test_triangle_clipping_area_and_winding()
	_test_triangle_clipping_at_sector_corner()
	_test_weighted_triangle_clipping()
	_test_triangle_attribute_interpolation()
	_test_array_mesh_surface_sector_clipping()
	_test_polyline_zone_intersection()
	_test_junction_patch_detection()
	_test_road_endpoint_join_safety()
	print("WorldMapGeometryUtils: polyline splitting, zone intersection, sector coverage and weighted clipping, attribute interpolation and ArrayMesh sector clipping tests passed")
	quit()


func _test_polyline_zone_intersection() -> void:
	var crossing := PackedVector2Array([Vector2(-1200.0, 0.0), Vector2(1200.0, 0.0)])
	assert(Geometry.polyline_intersects_circle(crossing, Vector2.ZERO, 800.0),
		"A road crossing the loaded radius must be retained even when both endpoints are outside")
	var outside := PackedVector2Array([Vector2(-1200.0, 900.0), Vector2(1200.0, 900.0)])
	assert(not Geometry.polyline_intersects_circle(outside, Vector2.ZERO, 800.0),
		"A road that stays outside the loaded radius must be rejected")
	var touching := PackedVector2Array([Vector2(800.0, 0.0), Vector2(1200.0, 0.0)])
	assert(Geometry.polyline_intersects_circle(touching, Vector2.ZERO, 800.0),
		"A road touching the radius boundary must be retained")
	assert(not Geometry.polyline_intersects_circle(PackedVector2Array(), Vector2.ZERO, 800.0))
	assert(not Geometry.polyline_intersects_circle(crossing, Vector2.ZERO, -1.0))


func _test_junction_patch_detection() -> void:
	var straight := PackedVector2Array([Vector2.RIGHT, Vector2.LEFT])
	assert(not Geometry.junction_needs_patch(straight),
		"Two opposite arms are a continuous straight road and need no junction patch")
	var bend := PackedVector2Array([Vector2.RIGHT, Vector2.UP])
	assert(Geometry.junction_needs_patch(bend),
		"Two connected road segments forming a bend need a joining patch")
	var tee := PackedVector2Array([Vector2.RIGHT, Vector2.LEFT, Vector2.UP])
	assert(Geometry.junction_needs_patch(tee),
		"A T-junction needs a joining patch")
	assert(not Geometry.junction_needs_patch(PackedVector2Array([Vector2.RIGHT])))


func _test_road_endpoint_join_safety() -> void:
	assert(Geometry.road_endpoints_can_join(Vector2.ZERO, Vector2(1.0, 0.0),
		Vector2.LEFT, Vector2.RIGHT), "Close opposing endpoints should join")
	assert(Geometry.road_endpoints_can_join(Vector2.ZERO, Vector2(1.0, 0.0),
		Vector2.LEFT, Vector2.UP), "Close perpendicular endpoints should form a junction")
	assert(not Geometry.road_endpoints_can_join(Vector2.ZERO, Vector2(2.0, 0.0),
		Vector2.LEFT, Vector2.RIGHT), "Endpoints beyond tolerance must stay disconnected")
	assert(not Geometry.road_endpoints_can_join(Vector2.ZERO, Vector2(1.0, 0.0),
		Vector2.RIGHT, Vector2.RIGHT), "Parallel same-direction endpoints must not be merged")
	assert(not Geometry.road_endpoints_can_join(Vector2.ZERO, Vector2.ZERO,
		Vector2.ZERO, Vector2.RIGHT), "Invalid endpoint directions must be rejected")


func _test_horizontal_crossings() -> void:
	var source := PackedVector3Array([Vector3(-100.0, 4.0, 100.0), Vector3(1700.0, 4.0, 100.0)])
	var pieces := Geometry.split_polyline_by_sectors(source, 800.0)
	assert(pieces.size() == 4, "Expected four sectors for a line crossing x=0, 800 and 1600")
	assert(pieces[0].sector == Vector2i(-1, 0))
	assert(pieces[1].sector == Vector2i(0, 0))
	assert(pieces[2].sector == Vector2i(1, 0))
	assert(pieces[3].sector == Vector2i(2, 0))
	_assert_continuous(pieces, source)


func _test_diagonal_corner_crossing() -> void:
	var source := PackedVector3Array([Vector3(200.0, 0.0, 200.0), Vector3(1000.0, 0.0, 1000.0)])
	var pieces := Geometry.split_polyline_by_sectors(source, 800.0)
	assert(pieces.size() == 2, "A simultaneous X/Z corner crossing must not create phantom side sectors")
	assert(pieces[0].sector == Vector2i(0, 0))
	assert(pieces[1].sector == Vector2i(1, 1))
	_assert_continuous(pieces, source)


func _test_negative_coordinates() -> void:
	var source := PackedVector3Array([Vector3(-900.0, 2.0, -100.0), Vector3(100.0, 2.0, -100.0)])
	var pieces := Geometry.split_polyline_by_sectors(source, 800.0)
	assert(pieces.size() == 3)
	assert(pieces[0].sector == Vector2i(-2, -1))
	assert(pieces[1].sector == Vector2i(-1, -1))
	assert(pieces[2].sector == Vector2i(0, -1))
	_assert_continuous(pieces, source)


func _test_reverse_direction() -> void:
	var forward := PackedVector3Array([Vector3(-100.0, 0.0, 100.0), Vector3(1700.0, 0.0, 100.0)])
	var backward := PackedVector3Array([forward[1], forward[0]])
	var forward_pieces := Geometry.split_polyline_by_sectors(forward, 800.0)
	var backward_pieces := Geometry.split_polyline_by_sectors(backward, 800.0)
	assert(forward_pieces.size() == backward_pieces.size())
	for index in range(forward_pieces.size()):
		var reverse_index := backward_pieces.size() - index - 1
		assert(forward_pieces[index].sector == backward_pieces[reverse_index].sector)
		var a: PackedVector3Array = forward_pieces[index].points
		var b: PackedVector3Array = backward_pieces[reverse_index].points
		assert(a.size() == b.size())
		for point_index in range(a.size()):
			assert(a[point_index].distance_to(b[b.size() - point_index - 1]) <= 0.001)


func _test_invalid_inputs() -> void:
	assert(Geometry.split_polyline_by_sectors(PackedVector3Array(), 800.0).is_empty())
	assert(Geometry.split_polyline_by_sectors(PackedVector3Array([Vector3.ZERO]), 800.0).is_empty())
	assert(Geometry.split_polyline_by_sectors(PackedVector3Array([Vector3.ZERO, Vector3.ONE]), 0.0).is_empty())


func _assert_continuous(pieces: Array[Dictionary], source: PackedVector3Array) -> void:
	assert(not pieces.is_empty())
	var first_points: PackedVector3Array = pieces[0].points
	var last_points: PackedVector3Array = pieces[pieces.size() - 1].points
	assert(first_points[0].distance_to(source[0]) <= 0.001)
	assert(last_points[last_points.size() - 1].distance_to(source[source.size() - 1]) <= 0.001)
	for index in range(pieces.size() - 1):
		var current: PackedVector3Array = pieces[index].points
		var following: PackedVector3Array = pieces[index + 1].points
		assert(current[current.size() - 1].distance_to(following[0]) <= 0.001, "Gap or overlap at a sector boundary")


func _test_polygon_sector_coverage() -> void:
	var crossing := PackedVector2Array([Vector2(790.0, 20.0), Vector2(820.0, 20.0), Vector2(820.0, 40.0), Vector2(790.0, 40.0)])
	var keys := Geometry.polygon_sector_keys(crossing, 800.0)
	assert(keys.size() == 2, "A footprint crossing x=800 must cover both sectors")
	assert(keys.has(Vector2i(0, 0)))
	assert(keys.has(Vector2i(1, 0)))
	var negative := PackedVector2Array([Vector2(-805.0, -10.0), Vector2(-795.0, -10.0), Vector2(-795.0, 10.0), Vector2(-805.0, 10.0)])
	var negative_keys := Geometry.polygon_sector_keys(negative, 800.0)
	assert(negative_keys.has(Vector2i(-2, -1)))
	assert(negative_keys.has(Vector2i(-1, -1)))
	var boundary := PackedVector2Array([Vector2(0.0, 0.0), Vector2(800.0, 0.0), Vector2(800.0, 200.0), Vector2(0.0, 200.0)])
	var boundary_keys := Geometry.polygon_sector_keys(boundary, 800.0)
	assert(boundary_keys.size() == 1 and boundary_keys[0] == Vector2i(0, 0), "An exact maximum boundary must not add an empty adjacent sector")
	var expanded := Geometry.polygon_sector_keys(boundary, 800.0, 1.0)
	assert(expanded.size() == 4, "A positive margin around a sector corner must cover neighboring sectors")
	assert(Geometry.polygon_sector_keys(PackedVector2Array(), 800.0).is_empty())
	assert(Geometry.polygon_sector_keys(crossing, 0.0).is_empty())


func _test_triangle_sector_clipping() -> void:
	var triangle := PackedVector2Array([Vector2(700.0, 100.0), Vector2(900.0, 100.0), Vector2(800.0, 300.0)])
	var left := Geometry.clip_triangle_to_rect(triangle, Vector2(0.0, 0.0), Vector2(800.0, 800.0))
	var right := Geometry.clip_triangle_to_rect(triangle, Vector2(800.0, 0.0), Vector2(1600.0, 800.0))
	assert(left.size() >= 3 and right.size() >= 3, "A triangle crossing x=800 must produce two clipped polygons")
	for point in left:
		assert(point.x >= -0.001 and point.x <= 800.001 and point.y >= -0.001 and point.y <= 800.001)
	for point in right:
		assert(point.x >= 799.999 and point.x <= 1600.001 and point.y >= -0.001 and point.y <= 800.001)
	var original_area := Geometry.polygon_area_abs(triangle)
	var split_area := Geometry.polygon_area_abs(left) + Geometry.polygon_area_abs(right)
	assert(absf(original_area - split_area) <= 0.01, "Sector clipping must preserve triangle area")
	var untouched := Geometry.clip_triangle_to_rect(triangle, Vector2(0.0, 0.0), Vector2(800.0, 800.0))
	assert(untouched.size() >= 3)
	var outside := Geometry.clip_triangle_to_rect(triangle, Vector2(1000.0, 1000.0), Vector2(1800.0, 1800.0))
	assert(outside.is_empty(), "A triangle outside the sector must produce no geometry")
	assert(Geometry.clip_triangle_to_rect(PackedVector2Array(), Vector2.ZERO, Vector2.ONE).is_empty())
	assert(Geometry.clip_triangle_to_rect(triangle, Vector2.ZERO, Vector2.ZERO).is_empty())


func _test_triangle_clipping_area_and_winding() -> void:
	var clockwise := PackedVector2Array([Vector2(760.0, 760.0), Vector2(860.0, 760.0), Vector2(810.0, 860.0)])
	var counter_clockwise := PackedVector2Array([clockwise[2], clockwise[1], clockwise[0]])
	var negative_triangle := PackedVector2Array([Vector2(-840.0, -840.0), Vector2(-760.0, -840.0), Vector2(-800.0, -760.0)])
	for triangle in [clockwise, counter_clockwise, negative_triangle]:
		var total_area := 0.0
		var keys := Geometry.polygon_sector_keys(triangle, 800.0)
		for key in keys:
			var rect_min := Vector2(float(key.x) * 800.0, float(key.y) * 800.0)
			var rect_max := rect_min + Vector2.ONE * 800.0
			var clipped := Geometry.clip_triangle_to_rect(triangle, rect_min, rect_max)
			if clipped.is_empty():
				continue
			for point in clipped:
				assert(point.x >= rect_min.x - 0.001 and point.x <= rect_max.x + 0.001)
				assert(point.y >= rect_min.y - 0.001 and point.y <= rect_max.y + 0.001)
			total_area += Geometry.polygon_area_abs(clipped)
		assert(absf(total_area - Geometry.polygon_area_abs(triangle)) <= 0.01,
			"Clipping must preserve area for either triangle winding and negative/positive sector keys")


func _test_weighted_triangle_clipping() -> void:
	var triangle := PackedVector2Array([
		Vector2(700.0, 100.0),
		Vector2(900.0, 100.0),
		Vector2(800.0, 300.0)
	])
	var clipped := Geometry.clip_triangle_to_rect_with_weights(
		triangle, Vector2(0.0, 0.0), Vector2(800.0, 800.0))
	assert(clipped.size() >= 3, "Weighted clipping must retain the in-sector polygon")
	for vertex in clipped:
		var position: Vector2 = vertex["position"]
		var weights: Vector3 = vertex["weights"]
		assert(position.x >= -0.001 and position.x <= 800.001)
		assert(absf(weights.x + weights.y + weights.z - 1.0) <= 0.0001,
			"Barycentric weights must sum to one")
		var reconstructed := triangle[0] * weights.x + triangle[1] * weights.y + triangle[2] * weights.z
		assert(reconstructed.distance_to(position) <= 0.001,
			"Interpolated weights must reconstruct the clipped vertex")
	var original_area := Geometry.polygon_area_abs(triangle)
	var weighted_area := 0.0
	for sector_key in Geometry.polygon_sector_keys(triangle, 800.0):
		var rect_min := Vector2(float(sector_key.x) * 800.0, float(sector_key.y) * 800.0)
		var rect_max := rect_min + Vector2.ONE * 800.0
		var sector_vertices := Geometry.clip_triangle_to_rect_with_weights(triangle, rect_min, rect_max)
		var sector_polygon := PackedVector2Array()
		for vertex in sector_vertices:
			sector_polygon.append(vertex["position"])
		weighted_area += Geometry.polygon_area_abs(sector_polygon)
	assert(absf(weighted_area - original_area) <= 0.01,
		"Weighted clipping must preserve total triangle area")
	assert(Geometry.clip_triangle_to_rect_with_weights(
		triangle, Vector2(1200.0, 1200.0), Vector2(1600.0, 1600.0)).is_empty())


func _test_triangle_attribute_interpolation() -> void:
	var weights := Vector3(0.25, 0.50, 0.25)
	var uv_values: Array = [Vector2(0.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, 2.0)]
	var uv: Variant = Geometry.interpolate_triangle_attribute(uv_values, weights)
	assert(uv is Vector2 and uv.distance_to(Vector2(1.0, 0.5)) <= 0.0001,
		"UV interpolation must preserve barycentric coordinates")
	var normal_values: Array = [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD]
	var normal: Variant = Geometry.interpolate_triangle_attribute(normal_values, weights)
	assert(normal is Vector3 and normal.distance_to(Vector3(0.5, 0.25, -0.25)) <= 0.0001,
		"Normal interpolation must be linear before caller normalization")
	var tangent_values: Array = [Vector4(1.0, 0.0, 0.0, 1.0), Vector4(0.0, 1.0, 0.0, 1.0), Vector4(0.0, 0.0, 1.0, -1.0)]
	var tangent: Variant = Geometry.interpolate_triangle_attribute(tangent_values, weights)
	assert(tangent is Vector4 and tangent.distance_to(Vector4(0.25, 0.50, 0.25, 0.0)) <= 0.0001,
		"Tangent interpolation must retain all four components")
	var color_values: Array = [Color(1.0, 0.0, 0.0, 1.0), Color(0.0, 1.0, 0.0, 0.5), Color(0.0, 0.0, 1.0, 0.0)]
	var color: Variant = Geometry.interpolate_triangle_attribute(color_values, weights)
	assert(color is Color and color.is_equal_approx(Color(0.25, 0.50, 0.25, 0.5)),
		"Vertex colors must be interpolated without losing alpha")
	var scalar_values: Array = [0.0, 10.0, 20.0]
	var scalar: Variant = Geometry.interpolate_triangle_attribute(scalar_values, weights)
	assert(is_equal_approx(float(scalar), 10.0), "Scalar vertex attributes must interpolate linearly")
	assert(Geometry.interpolate_triangle_attribute([Vector2.ZERO], weights) == null,
		"Invalid attribute triplets must be rejected")
	assert(Geometry.interpolate_triangle_attribute(["a", "b", "c"], weights) == null,
		"Unsupported attribute types must be rejected")


func _test_array_mesh_surface_sector_clipping() -> void:
	var source := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-10.0, 2.0, 0.0),
		Vector3(10.0, 6.0, 0.0),
		Vector3(0.0, 4.0, 20.0)
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([
		1.0, 0.0, 0.0, 1.0,
		1.0, 0.0, 0.0, 1.0,
		1.0, 0.0, 0.0, 1.0
	])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0)])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(2.0, 0.0), Vector2(1.0, 2.0)])
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var clipped := Geometry.clip_array_mesh_surface_to_rect(source, 0, Vector2(0.0, 0.0), Vector2(10.0, 20.0))
	assert(clipped != null and clipped.get_surface_count() == 1, "A triangle intersecting a sector must produce one clipped mesh surface")
	var clipped_arrays: Array = clipped.surface_get_arrays(0)
	var vertices: PackedVector3Array = clipped_arrays[Mesh.ARRAY_VERTEX]
	assert(vertices.size() >= 3 and vertices.size() % 3 == 0, "Clipped mesh output must contain complete triangles")
	for vertex in vertices:
		assert(vertex.x >= -0.0001 and vertex.x <= 10.0001 and vertex.z >= -0.0001 and vertex.z <= 20.0001,
			"Every clipped mesh vertex must lie inside the sector rectangle")
	assert(clipped_arrays[Mesh.ARRAY_NORMAL].size() == vertices.size(), "Normals must be retained")
	assert(clipped_arrays[Mesh.ARRAY_TANGENT].size() == vertices.size() * 4, "Tangents must retain four components")
	assert(clipped_arrays[Mesh.ARRAY_COLOR].size() == vertices.size(), "Vertex colors must be retained")
	assert(clipped_arrays[Mesh.ARRAY_TEX_UV].size() == vertices.size(), "UVs must be retained")
	assert(clipped_arrays[Mesh.ARRAY_TEX_UV2].size() == vertices.size(), "UV2s must be retained")
	for normal in clipped_arrays[Mesh.ARRAY_NORMAL]:
		assert(normal.length() > 0.99, "Interpolated normals must be normalized")
	var outside := Geometry.clip_array_mesh_surface_to_rect(source, 0, Vector2(30.0, 30.0), Vector2(40.0, 40.0))
	assert(outside == null, "A triangle outside the sector must produce no mesh")
	assert(Geometry.clip_array_mesh_surface_to_rect(source, 0, Vector2(1.0, 1.0), Vector2(1.0, 2.0)) == null,
		"An invalid sector rectangle must be rejected")


func _test_triangle_clipping_at_sector_corner() -> void:
	var triangle := PackedVector2Array([
		Vector2(760.0, 760.0),
		Vector2(840.0, 760.0),
		Vector2(800.0, 840.0)
	])
	var keys := Geometry.polygon_sector_keys(triangle, 800.0)
	var total_area := 0.0
	for key in keys:
		var rect_min := Vector2(float(key.x) * 800.0, float(key.y) * 800.0)
		var rect_max := rect_min + Vector2.ONE * 800.0
		var clipped := Geometry.clip_triangle_to_rect(triangle, rect_min, rect_max)
		if clipped.size() >= 3:
			total_area += Geometry.polygon_area_abs(clipped)
	assert(absf(total_area - Geometry.polygon_area_abs(triangle)) <= 0.01,
		"A triangle touching four sectors at a corner must not lose or duplicate area")
