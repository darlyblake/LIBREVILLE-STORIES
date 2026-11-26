extends Node3D
## Personnage civil modulaire léger. L'apparence vient de la fiche persistante du résident.
## Les meshes sont générés à la demande et restent déterministes pour une même identité.

var resident_id: String = ""
var appearance: Dictionary = {}

const SKIN := {
	"ebene": Color("#38221c"), "brun_fonce": Color("#573328"),
	"brun": Color("#704632"), "brun_moyen": Color("#895b42"),
	"caramel": Color("#a87350"), "cuivre": Color("#b98260"), "clair": Color("#c99776")
}
const HAIR := {
	"noir": Color("#171311"), "brun_fonce": Color("#2b1b16"),
	"brun": Color("#493026"), "chatain": Color("#67402c"),
	"gris": Color("#77736e"), "blanc": Color("#c8c5bd"), "teinte_bordeaux": Color("#48202b")
}
const OUTFITS: Array[Color] = [
	Color("#263d59"), Color("#9b3f32"), Color("#d2b66f"), Color("#426b55"),
	Color("#6a426e"), Color("#e0e0d8"), Color("#30343b"), Color("#b76a35"),
	Color("#397b83"), Color("#8b8c91"), Color("#6d4935"), Color("#bd9b83")
]

func configure(resident: Dictionary) -> void:
	resident_id = str(resident.get("id", "resident_unknown"))
	appearance = resident.get("appearance", {}) as Dictionary
	if appearance.is_empty():
		appearance = _fallback_appearance(resident)
	_build_body()

func _fallback_appearance(resident: Dictionary) -> Dictionary:
	var seed_value := abs(resident_id.hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"seed": seed_value, "skin_tone": "brun_fonce",
		"hair_color": "noir", "hair_style": "coupe_courte",
		"face_shape": "ovale", "body_type": "moyen",
		"height_cm": 170, "outfit_palette": rng.randi_range(0, OUTFITS.size() - 1),
		"facial_hair": "aucune", "gender_presentation": str(resident.get("gender", "homme"))
	}

func _build_body() -> void:
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(appearance.get("seed", resident_id.hash()))
	var skin: Color = SKIN.get(str(appearance.get("skin_tone", "brun_fonce")), SKIN["brun_fonce"])
	var hair: Color = HAIR.get(str(appearance.get("hair_color", "noir")), HAIR["noir"])
	var outfit_index := posmod(int(appearance.get("outfit_palette", 0)), OUTFITS.size())
	var outfit := OUTFITS[outfit_index]
	var height_scale := clampf(float(appearance.get("height_cm", 170)) / 170.0, 0.55, 1.16)
	var body_type := str(appearance.get("body_type", "moyen"))
	var width := 1.0
	if body_type == "mince":
		width = 0.82
	elif body_type == "athletique":
		width = 1.08
	elif body_type == "fort":
		width = 1.22
	elif body_type == "corpulence_moyenne":
		width = 1.12
	scale = Vector3(width, height_scale, 1.0)

	_add_capsule("Jambes", Vector3(-0.115, 0.43, 0), Vector3(0.09, 0.58, 0), outfit.darkened(0.22))
	_add_capsule("Jambes2", Vector3(0.115, 0.43, 0), Vector3(0.09, 0.58, 0), outfit.darkened(0.22))
	_add_sphere("ChaussureG", Vector3(-0.12, 0.09, -0.045), Vector3(0.12, 0.07, 0.20), Color("#282522"))
	_add_sphere("ChaussureD", Vector3(0.12, 0.09, -0.045), Vector3(0.12, 0.07, 0.20), Color("#282522"))
	_add_capsule("Torse", Vector3(0, 1.02, 0), Vector3(0.27, 0.39, 0.15), outfit)
	_add_capsule("BrasG", Vector3(-0.34, 0.99, 0), Vector3(0.075, 0.34, 0.075), outfit)
	_add_capsule("BrasD", Vector3(0.34, 0.99, 0), Vector3(0.075, 0.34, 0.075), outfit)
	_add_capsule("AvantBrasG", Vector3(-0.36, 0.62, -0.005), Vector3(0.06, 0.22, 0.06), skin)
	_add_capsule("AvantBrasD", Vector3(0.36, 0.62, -0.005), Vector3(0.06, 0.22, 0.06), skin)
	_add_capsule("Cou", Vector3(0, 1.43, 0), Vector3(0.075, 0.11, 0.075), skin)

	var face_shape := str(appearance.get("face_shape", "ovale"))
	var head_scale := Vector3(0.205, 0.245, 0.19)
	if face_shape == "rond":
		head_scale = Vector3(0.22, 0.22, 0.20)
	elif face_shape == "allonge":
		head_scale = Vector3(0.19, 0.265, 0.18)
	elif face_shape == "carre":
		head_scale = Vector3(0.22, 0.235, 0.19)
	_add_sphere("Visage", Vector3(0, 1.69, 0), head_scale, skin)
	_add_sphere("OreilleG", Vector3(-0.205, 1.68, 0), Vector3(0.045, 0.075, 0.045), skin)
	_add_sphere("OreilleD", Vector3(0.205, 1.68, 0), Vector3(0.045, 0.075, 0.045), skin)

	var eye_width := 0.035 if str(appearance.get("eye_shape", "amande")) == "fins" else 0.042
	_add_sphere("OeilG", Vector3(-0.078, 1.72, -0.174), Vector3(eye_width, 0.022, 0.014), Color("#f4eee4"))
	_add_sphere("OeilD", Vector3(0.078, 1.72, -0.174), Vector3(eye_width, 0.022, 0.014), Color("#f4eee4"))
	_add_sphere("PupilleG", Vector3(-0.078, 1.72, -0.188), Vector3(0.014, 0.016, 0.009), Color("#211713"))
	_add_sphere("PupilleD", Vector3(0.078, 1.72, -0.188), Vector3(0.014, 0.016, 0.009), Color("#211713"))
	var nose_width := 0.052 if str(appearance.get("nose_shape", "arrondi")) == "large" else 0.034
	_add_sphere("Nez", Vector3(0, 1.665, -0.19), Vector3(nose_width, 0.07, 0.045), skin.darkened(0.04))
	_add_sphere("Bouche", Vector3(0, 1.59, -0.177), Vector3(0.045, 0.012, 0.012), Color("#542b2b"))

	_build_hair(hair, rng)
	_build_facial_hair(hair)
	_build_accessory(skin)

func _build_hair(color: Color, rng: RandomNumberGenerator) -> void:
	var style := str(appearance.get("hair_style", "coupe_courte"))
	var cap_scale := Vector3(0.21, 0.09, 0.19)
	var cap_y := 1.91
	if style == "afro":
		cap_scale = Vector3(0.255, 0.17, 0.235)
		cap_y = 1.94
	elif style == "locks":
		cap_scale = Vector3(0.22, 0.14, 0.20)
		cap_y = 1.94
	elif style == "tresses" or style == "nattes":
		cap_scale = Vector3(0.215, 0.11, 0.195)
		cap_y = 1.93
	elif style == "rasé" or style == "tres_court":
		cap_scale = Vector3(0.205, 0.045, 0.185)
		cap_y = 1.90
	_add_sphere("Chevelure", Vector3(0, cap_y, 0.005), cap_scale, color)
	if style == "tresses" or style == "nattes" or style == "locks":
		for index in range(5):
			var x := -0.16 + float(index) * 0.08
			_add_capsule("Mèche_%d" % index, Vector3(x, 1.80, 0.035), Vector3(0.018, 0.13, 0.018), color)
	elif style == "queue_cheval" or style == "chignon":
		_add_sphere("AttacheCheveux", Vector3(0, 1.84, 0.18), Vector3(0.09, 0.10, 0.10), color)

func _build_facial_hair(color: Color) -> void:
	var style := str(appearance.get("facial_hair", "aucune"))
	if style == "aucune":
		return
	if style == "barbe_complete":
		_add_sphere("Barbe", Vector3(0, 1.535, -0.105), Vector3(0.145, 0.09, 0.10), color)
	elif style == "moustache":
		_add_sphere("Moustache", Vector3(0, 1.615, -0.185), Vector3(0.075, 0.022, 0.018), color)
	else:
		_add_sphere("BarbeCourte", Vector3(0, 1.55, -0.16), Vector3(0.09, 0.045, 0.025), color)

func _build_accessory(skin: Color) -> void:
	var accessory := str(appearance.get("accessory", "aucun"))
	if accessory == "lunettes":
		var frame := Color("#24201d")
		_add_box("LunetteG", Vector3(-0.078, 1.73, -0.196), Vector3(0.085, 0.055, 0.018), frame)
		_add_box("LunetteD", Vector3(0.078, 1.73, -0.196), Vector3(0.085, 0.055, 0.018), frame)
	elif accessory == "collier":
		_add_torus("Collier", Vector3(0, 1.36, 0), 0.12, 0.009, Color("#c49b42"))

func _add_sphere(label: String, position: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	node.scale = dimensions
	node.material_override = _material(color)
	add_child(node)

func _add_capsule(label: String, position: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	node.scale = dimensions
	node.material_override = _material(color)
	add_child(node)

func _add_box(label: String, position: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	node.scale = dimensions
	node.material_override = _material(color)
	add_child(node)

func _add_torus(label: String, position: Vector3, radius: float, thickness: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	add_child(node)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material
