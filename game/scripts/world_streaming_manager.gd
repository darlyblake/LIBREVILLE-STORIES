extends Node
class_name WorldStreamingManager
## Gestionnaire spatial central du monde ouvert.
## Les contenus sont enregistrés dans des secteurs et activés selon
## la distance au joueur. Les données sources restent la responsabilité
## des générateurs (routes, bâtiments, environnement, végétation, POI).

signal sector_activated(sector_key: Vector2i)
signal sector_deactivated(sector_key: Vector2i)
signal active_sectors_changed(active_count: int)

@export_range(64.0, 2048.0, 32.0) var sector_size: float = 800.0
@export_range(1, 8, 1) var load_radius: int = 2
@export_range(1, 10, 1) var unload_radius: int = 3
@export_range(0.05, 1.0, 0.05) var update_interval: float = 0.20
@export_range(0.0, 5.0, 0.5) var on_foot_preload_seconds: float = 2.0
@export_range(0.0, 12.0, 0.5) var vehicle_preload_seconds: float = 6.0

var _player: Node3D
var _sectors: Dictionary = {}
var _active_sectors: Dictionary = {}
var _shared_nodes: Dictionary = {}
var _current_center := Vector2i(2147483647, 2147483647)
var _update_timer := 0.0


func _ready() -> void:
	unload_radius = maxi(unload_radius, load_radius)
	_player = get_parent().get_node_or_null("Player") as Node3D
	set_process(true)


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0
	if not is_instance_valid(_player):
		_player = get_parent().get_node_or_null("Player") as Node3D
	if _player == null:
		return

	var streaming_position := _player.global_position
	var movement_velocity := (_player as CharacterBody3D).velocity if _player is CharacterBody3D else Vector3.ZERO
	var preload_seconds := on_foot_preload_seconds

	# Le véhicule n'est considéré comme conduit que lorsque son contrôleur
	# confirme que le joueur est au volant. Être simplement proche du véhicule
	# ne doit pas déclencher le préchargement longue distance.
	var vehicle := get_parent().get_node_or_null("Vehicle") as VehicleBody3D
	var player_is_driving := vehicle != null and vehicle.get("player_driving") == true
	if player_is_driving:
		movement_velocity = vehicle.linear_velocity
		preload_seconds = vehicle_preload_seconds

	var horizontal_velocity := Vector3(movement_velocity.x, 0.0, movement_velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var minimum_preload_speed := 1.0 if player_is_driving else 1.5
	if horizontal_speed > minimum_preload_speed and preload_seconds > 0.0:
		var lookahead_distance := minf(horizontal_speed * preload_seconds, sector_size * 2.0)
		streaming_position += horizontal_velocity.normalized() * lookahead_distance
	update_streaming(streaming_position)


## Convertit une position monde en coordonnée entière de secteur.
func world_to_sector(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / sector_size),
		floori(world_position.z / sector_size)
	)


## Renvoie le conteneur d'un secteur, en le créant à la demande.
func get_or_create_sector(sector_key: Vector2i) -> Node3D:
	if _sectors.has(sector_key) and is_instance_valid(_sectors[sector_key]):
		return _sectors[sector_key] as Node3D
	var sector := Node3D.new()
	sector.name = "Sector_%d_%d" % [sector_key.x, sector_key.y]
	sector.position = Vector3(
		float(sector_key.x) * sector_size,
		0.0,
		float(sector_key.y) * sector_size
	)
	sector.visible = false
	sector.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(sector)
	_sectors[sector_key] = sector
	_set_sector_active(sector_key, _is_inside_load_radius(sector_key))
	return sector


## Enregistre un élément généré dans le secteur correspondant à sa position.
## Le reparentage conserve sa transformation globale.
func register_node(node: Node3D, category: String, world_position: Vector3 = Vector3.INF) -> void:
	if not is_instance_valid(node):
		return
	var position_to_use := node.global_position if world_position == Vector3.INF else world_position
	var sector_key := world_to_sector(position_to_use)
	var sector := get_or_create_sector(sector_key)
	var category_name := category.strip_edges().replace("/", "_")
	if category_name.is_empty():
		category_name = "Misc"
	var category_root := sector.get_node_or_null(category_name) as Node3D
	if category_root == null:
		category_root = Node3D.new()
		category_root.name = category_name
		sector.add_child(category_root)
	if node.get_parent() != null:
		node.reparent(category_root, true)
	else:
		category_root.add_child(node)
	var should_be_active := _is_inside_load_radius(sector_key)
	if should_be_active:
		_set_sector_active(sector_key, true)
	else:
		# Le secteur parent gère visibilité et traitement ; on ne désactive
		# pas individuellement le nouveau nœud, sinon il resterait caché au réveil.
		_set_collision_state_recursive(node, false)


## Enregistre un nœud unique partagé par plusieurs secteurs traversés.
## Le nœud reste actif si au moins un secteur couvert est dans le rayon actif.
## Contrairement à register_node(), il n'est pas reparenté dans un secteur.
func register_node_in_sectors(node: Node3D, category: String, sector_keys: Array[Vector2i]) -> void:
	if not is_instance_valid(node) or sector_keys.is_empty():
		return
	var unique_sectors: Array[Vector2i] = []
	for key in sector_keys:
		if not unique_sectors.has(key):
			unique_sectors.append(key)
	if unique_sectors.is_empty():
		return
	var node_id := node.get_instance_id()
	var record := {
		"node": node,
		"category": category,
		"sectors": unique_sectors,
		"active": false
	}
	_shared_nodes[node_id] = record
	var should_be_active := _shared_record_inside_radius(record, load_radius)
	_set_shared_node_active(node, should_be_active)
	_shared_nodes[node_id].active = should_be_active


func _shared_record_inside_radius(record: Dictionary, radius: int) -> bool:
	for sector_key in record.sectors:
		var offset: Vector2i = sector_key - _current_center
		if Vector2(offset.x, offset.y).length_squared() <= float(radius * radius):
			return true
	return false


func _set_shared_node_active(node: Node3D, active: bool) -> void:
	if not is_instance_valid(node):
		return
	node.visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_collision_state_recursive(node, active)


func _update_shared_nodes() -> void:
	for node_id_variant in _shared_nodes.keys():
		var node_id: int = node_id_variant
		var record: Dictionary = _shared_nodes[node_id]
		var node: Node3D = record.node
		if not is_instance_valid(node):
			_shared_nodes.erase(node_id)
			continue
		var was_active: bool = record.active
		var radius := unload_radius if was_active else load_radius
		var should_be_active := _shared_record_inside_radius(record, radius)
		if should_be_active != was_active:
			_set_shared_node_active(node, should_be_active)
			record.active = should_be_active
			_shared_nodes[node_id] = record


## Met à jour les secteurs proches. Les distances sont circulaires en unités
## de secteur ; le rayon de sortie plus large fournit l'hystérésis.
func update_streaming(world_position: Vector3, force: bool = false) -> void:
	var center := world_to_sector(world_position)
	if not force and center == _current_center:
		return
	_current_center = center
	var changed := false
	for key_variant in _sectors.keys():
		var key: Vector2i = key_variant
		var offset := key - center
		var distance_squared := Vector2(offset.x, offset.y).length_squared()
		var was_active := _active_sectors.has(key)
		var should_be_active := distance_squared <= float(unload_radius * unload_radius) if was_active else distance_squared <= float(load_radius * load_radius)
		if should_be_active != was_active:
			_set_sector_active(key, should_be_active)
			changed = true
	_update_shared_nodes()
	if changed:
		active_sectors_changed.emit(_active_sectors.size())


func _is_inside_load_radius(sector_key: Vector2i) -> bool:
	var offset := sector_key - _current_center
	return Vector2(offset.x, offset.y).length_squared() <= float(load_radius * load_radius)


func _set_sector_active(sector_key: Vector2i, active: bool) -> void:
	if not _sectors.has(sector_key):
		return
	var sector := _sectors[sector_key] as Node3D
	if not is_instance_valid(sector):
		return
	if active:
		if _active_sectors.has(sector_key):
			return
		_active_sectors[sector_key] = true
		sector.visible = true
		sector.process_mode = Node.PROCESS_MODE_INHERIT
		_set_collision_state_recursive(sector, true)
		sector_activated.emit(sector_key)
	else:
		if not _active_sectors.has(sector_key):
			return
		_active_sectors.erase(sector_key)
		sector.visible = false
		sector.process_mode = Node.PROCESS_MODE_DISABLED
		_set_collision_state_recursive(sector, false)
		sector_deactivated.emit(sector_key)


func _set_collision_state_recursive(root: Node, enabled: bool) -> void:
	if root is CollisionObject3D:
		var collision := root as CollisionObject3D
		if enabled:
			if collision.has_meta("stream_saved_collision_layer"):
				collision.collision_layer = int(collision.get_meta("stream_saved_collision_layer"))
				collision.collision_mask = int(collision.get_meta("stream_saved_collision_mask"))
				collision.remove_meta("stream_saved_collision_layer")
				collision.remove_meta("stream_saved_collision_mask")
		else:
			if not collision.has_meta("stream_saved_collision_layer"):
				collision.set_meta("stream_saved_collision_layer", collision.collision_layer)
				collision.set_meta("stream_saved_collision_mask", collision.collision_mask)
			collision.collision_layer = 0
			collision.collision_mask = 0
	for child in root.get_children():
		_set_collision_state_recursive(child, enabled)


func get_streaming_stats() -> Dictionary:
	var active_shared_nodes := 0
	for record_variant in _shared_nodes.values():
		var record: Dictionary = record_variant
		if bool(record.active):
			active_shared_nodes += 1
	return {
		"sector_size_m": sector_size,
		"loaded_sector_containers": _sectors.size(),
		"active_sectors": _active_sectors.size(),
		"shared_streaming_nodes": _shared_nodes.size(),
		"active_shared_streaming_nodes": active_shared_nodes,
		"center_sector": _current_center,
		"load_radius": load_radius,
		"unload_radius": unload_radius,
		"on_foot_preload_seconds": on_foot_preload_seconds,
		"vehicle_preload_seconds": vehicle_preload_seconds
	}
