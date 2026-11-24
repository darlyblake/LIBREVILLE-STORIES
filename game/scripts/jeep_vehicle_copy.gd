extends Node3D
## Génère une instance visuelle indépendante du Jeep à partir du modèle source.
## Le GLB original reste inchangé : géométrie, matériaux, textures et détails sont conservés.

const SOURCE_MODEL: PackedScene = preload("res://assets/models/vehicles/jeep_wrangler_rubicon_4xe_2024/jeep_wrangler_rubicon_4xe_2024.glb")
const GENERATED_NODE_NAME := "ModelSource"

func _ready() -> void:
	if has_node(GENERATED_NODE_NAME):
		return
	var generated_vehicle := SOURCE_MODEL.instantiate()
	generated_vehicle.name = GENERATED_NODE_NAME
	add_child(generated_vehicle)
