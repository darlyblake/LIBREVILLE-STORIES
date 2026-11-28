extends SceneTree

const StreamingManager = preload("res://game/scripts/world_streaming_manager.gd")


func _initialize() -> void:
	_test_shared_road_node_lifetime()
	print("WorldStreamingManager: multi-sector shared-node tests passed")
	quit()


func _test_shared_road_node_lifetime() -> void:
	var manager := StreamingManager.new()
	root.add_child(manager)
	manager.sector_size = 800.0
	manager.load_radius = 2
	manager.unload_radius = 3
	manager._current_center = Vector2i.ZERO

	var road_batch := Node3D.new()
	root.add_child(road_batch)
	manager.register_node_in_sectors(road_batch, "Roads", [Vector2i(2, 0), Vector2i(3, 0)])
	assert(road_batch.visible, "Road must activate when one covered sector is in load radius")

	manager.update_streaming(Vector3(2400.0, 0.0, 0.0))
	assert(road_batch.visible, "Road must remain active while a covered sector is nearby")

	manager.update_streaming(Vector3(5600.0, 0.0, 0.0))
	assert(not road_batch.visible, "Road must deactivate after all covered sectors leave unload radius")

	manager.update_streaming(Vector3(4000.0, 0.0, 0.0))
	assert(road_batch.visible, "Road must reactivate when a covered sector re-enters load radius")

	road_batch.queue_free()
	manager.queue_free()
