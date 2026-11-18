extends RefCounted
class_name BaieDesRoisSurvey
## Repère topographique provisoire établi à partir des coordonnées GPS fournies.
## Base d'implantation utilisée par baie_des_rois.gd : deux rangées face à face.
## Les coordonnées et le décalage transversal viennent des points GPS fournis.
## Le nombre de huit kiosques et leur répartition régulière sont un placement de travail.

const ROW_A_START := Vector3(-1833.4264, 0.0, -437.0061)
const ROW_A_END := Vector3(-1934.1359, 0.0, -428.4268)

# Direction unitaire de P1 vers P2, dans le plan X/Z.
const ROW_DIRECTION := Vector3(-0.9963910, 0.0, 0.0848819)

# Décalage perpendiculaire signé, calculé en projetant P3-P1 sur la normale
# à la rangée A. Il donne environ 8,51 m entre les axes, pas la largeur
# certifiée de la chaussée. Le point P3 est légèrement décalé le long de l'axe.
const ROW_B_OFFSET := Vector3(0.7222, 0.0, 8.4795)

# Reculs extérieurs provisoires, différenciés selon la proximité de la route.
# La rangée A est du côté de la route secondaire : son axe est à 1,84 m
# de l'axe routier. Le modèle du jeu prévoit 9 m de chaussée, 1,55 m
# de trottoir et 0,22 m de bordure de chaque côté. Le recul A de 6,5 m
# dégage le gabarit théorique chaussée + trottoir pour un kiosque
# de 3,6 m de profondeur. Ces largeurs restent des hypothèses de rendu,
# pas un relevé topographique : contrôle visuel Godot obligatoire.
# La rangée B conserve 4,5 m, suffisants selon le même gabarit théorique.
const ROW_B_NORMAL := Vector3(0.08486, 0.0, 0.99639)
const ROW_A_OUTWARD_SETBACK_METERS := 6.5
const ROW_B_OUTWARD_SETBACK_METERS := 4.5

const ROW_LENGTH_METERS := 101.0742
const ROW_SPACING_ESTIMATE_METERS := 8.5102


static func row_a_position(progress: float, longitudinal_offset: float = 0.0) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	return ROW_A_START.lerp(ROW_A_END, t) + ROW_DIRECTION * longitudinal_offset - ROW_B_NORMAL * ROW_A_OUTWARD_SETBACK_METERS


static func row_b_position(progress: float, longitudinal_offset: float = 0.0) -> Vector3:
	return ROW_A_START.lerp(ROW_A_END, clampf(progress, 0.0, 1.0)) + ROW_DIRECTION * longitudinal_offset + ROW_B_OFFSET + ROW_B_NORMAL * ROW_B_OUTWARD_SETBACK_METERS

