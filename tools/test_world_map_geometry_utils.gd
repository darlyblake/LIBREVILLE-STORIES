extends SceneTree

const Geometry = preload("res://game/scripts/world_map_geometry_utils.gd")


func _initialize() -> void:
	_test_horizontal_crossings()
	_test_diagonal_corner_crossing()
	_test_negative_coordinates()
	_test_reverse_direction()
	_test_invalid_inputs()
	_test_polygon_sector_coverage()
	print("WorldMapGeometryUtils: polyline splitting and polygon sector coverage tests passed")
	quit()


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
