extends SceneTree

const Geometry = preload("res://game/scripts/world_map_geometry_utils.gd")


func _initialize() -> void:
	_test_horizontal_crossings()
	_test_diagonal_corner_crossing()
	_test_negative_coordinates()
	_test_reverse_direction()
	_test_invalid_inputs()
	print("WorldMapGeometryUtils: polyline sector-splitting tests passed")
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
	assert(pieces.size() == 2)
	assert(pieces[0].sector == Vector2i(-2, -1))
	assert(pieces[1].sector == Vector2i(-1, -1))
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
