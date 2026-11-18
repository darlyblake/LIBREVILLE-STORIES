extends RefCounted
class_name BaieDesRoisSurvey
## Repère topographique provisoire établi à partir des coordonnées GPS fournies.
## Ne pas instancier les kiosques ici : le nombre, les intervalles et les variantes
## doivent être confirmés sur Capture7, Capture8 et Capture9.

const ROW_A_START := Vector3(-1833.4264, 0.0, -437.0061)
const ROW_A_END := Vector3(-1934.1359, 0.0, -428.4268)

# Direction unitaire de P1 vers P2, dans le plan X/Z.
const ROW_DIRECTION := Vector3(-0.9963910, 0.0, 0.0848819)

# Décalage perpendiculaire signé, calculé en projetant P3-P1 sur la normale
# à la rangée A. Il donne environ 8,51 m entre les axes, pas la largeur
# certifiée de la chaussée. Le point P3 est légèrement décalé le long de l'axe.
const ROW_B_OFFSET := Vector3(0.7222, 0.0, 8.4795)

const ROW_LENGTH_METERS := 101.0742
const ROW_SPACING_ESTIMATE_METERS := 8.5102


static func row_a_position(progress: float, longitudinal_offset: float = 0.0) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	return ROW_A_START.lerp(ROW_A_END, t) + ROW_DIRECTION * longitudinal_offset


static func row_b_position(progress: float, longitudinal_offset: float = 0.0) -> Vector3:
	return row_a_position(progress, longitudinal_offset) + ROW_B_OFFSET


static func row_a_yaw() -> float:
	# Le modèle actuel présente son comptoir sur l'axe local Y négatif.
	# L'orientation finale doit encore être validée à partir des captures.
	return atan2(ROW_DIRECTION.x, ROW_DIRECTION.z)


static func row_b_yaw() -> float:
	# Les façades de service doivent se faire face ; orientation opposée.
	return row_a_yaw() + PI
