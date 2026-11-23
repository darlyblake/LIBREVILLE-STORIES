extends Node3D
class_name BaieDesRoisPropsPlacement
## Instancie le mobilier 3D autour des deux rangées de kiosques GPS.
## Les coordonnées sont calculées depuis BaieDesRoisSurvey, pas depuis l'ancre
## décorative historique. Les décalages extérieurs restent à valider dans Godot.

const PALM_PATH := "res://assets/models/vegetation/palm_trees.glb"
const LEGACY_PALM_PATH := "res://assets/models/baie_des_rois/palmier_baie_des_rois.glb"
const BENCH_PATH := "res://assets/models/baie_des_rois/banc_baie_des_rois.glb"
const LAMP_PATH := "res://assets/models/baie_des_rois/lampadaire_baie_des_rois.glb"

const PALM_PROGRESS: Array[float] = [0.18, 0.50, 0.82]
const LAMP_PROGRESS: Array[float] = [0.08, 0.36, 0.64, 0.92]
const BENCH_PROGRESS: Array[float] = [0.28, 0.72]

# Distances depuis l'axe extérieur de chaque rangée de kiosques.
# Elles positionnent les objets dans les bandes paysagères supposées,
# mais ne remplacent pas le contrôle des limites de trottoir et de pelouse.
const PALM_OUTER_OFFSET := 7.2
const LAMP_OUTER_OFFSET := 5.7
const BENCH_OUTER_OFFSET := 6.0


func _ready() -> void:
	name = "Mobilier3D_BaieDesRois"
	_build_placements()


func _build_placements() -> void:
	var palm_scene := _load_model(PALM_PATH, "palmier réaliste")
	if palm_scene == null:
		palm_scene = _load_model(LEGACY_PALM_PATH, "palmier de secours")
	var bench_scene := _load_model(BENCH_PATH, "banc")
	var lamp_scene := _load_model(LAMP_PATH, "lampadaire")

	if palm_scene == null and bench_scene == null and lamp_scene == null:
		push_error("Aucun modèle de mobilier Baie des Rois n'a pu être chargé.")
		return

	for row_index in range(2):
		var outward: Vector3 = -BaieDesRoisSurvey.ROW_B_NORMAL if row_index == 0 else BaieDesRoisSurvey.ROW_B_NORMAL
		var row_name := "A" if row_index == 0 else "B"

		if palm_scene != null:
			_place_along_row(palm_scene, PALM_PROGRESS, outward, PALM_OUTER_OFFSET, "Palmier", row_name)

		if lamp_scene != null:
			_place_along_row(lamp_scene, LAMP_PROGRESS, outward, LAMP_OUTER_OFFSET, "Lampadaire", row_name)

		if bench_scene != null:
			_place_along_row(bench_scene, BENCH_PROGRESS, outward, BENCH_OUTER_OFFSET, "Banc", row_name)

	print("LIBREVILLE STORIES | mobilier GPS : %d éléments instanciés" % get_child_count())


func _load_model(path: String, label: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		push_warning("Modèle %s absent : %s" % [label, path])
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Le fichier %s n'est pas une scène 3D valide : %s" % [label, path])
	return packed


func _place_along_row(
	packed: PackedScene,
	progress_values: Array[float],
	outward: Vector3,
	outer_offset: float,
	asset_label: String,
	row_label: String
) -> void:
	for i in range(progress_values.size()):
		var progress: float = progress_values[i]
		var base_position: Vector3
		if row_label == "A":
			base_position = BaieDesRoisSurvey.row_a_position(progress)
		else:
			base_position = BaieDesRoisSurvey.row_b_position(progress)

		var instance := packed.instantiate() as Node3D
		if instance == null:
			push_warning("Impossible d'instancier %s rangée %s n°%d" % [asset_label, row_label, i + 1])
			continue

		instance.name = "%s_Rangee%s_%02d" % [asset_label, row_label, i + 1]
		instance.position = base_position + outward * outer_offset
		add_child(instance)
