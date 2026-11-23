extends Node3D
## Repères patrimoniaux du front de mer : monument Georges-Damas-Aleka et tribune officielle.
## Les deux ouvrages sont positionnés à partir de leurs références cartographiques OpenStreetMap.

const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const METERS_PER_DEG_LAT := 111320.0
const MONUMENT_LAT := 0.3879
const MONUMENT_LON := 9.44288
# Centroïde du toit de la tribune officielle (OSM way 1495944465).
const TRIBUNE_LAT := 0.38831
const TRIBUNE_LON := 9.44356
const STELE_LAT := 0.39155
const STELE_LON := 9.44067
const PRESIDENTIAL_PALACE_LAT := 0.39237
const PRESIDENTIAL_PALACE_LON := 9.44235
const PAVILION_PROVINCES := ["HAUT-OGOOUE", "MOYEN-OGOOUE", "NGOUNIE", "NYANGA", "OGOOUE-IVINDO", "OGOOUE-LOLO", "OGOOUE-MARITIME", "WOLEU-NTEM"]

var _stone: Material
var _white: Material
var _gold: StandardMaterial3D
var _roof: Material
var _glass: StandardMaterial3D
var _dark: StandardMaterial3D
var _paving: Material
var _yellow: Material

func _ready() -> void:
	_make_materials()
	_build_monument()
	_build_official_tribune()
	_build_freedom_stele()
	print("LIBREVILLE STORIES | repères du front de mer : monument Georges-Damas-Aleka + tribune officielle")


func _make_materials() -> void:
	# Surfaces procédurales PBR : variations minérales, grain fin et rugosité irrégulière.
	# Les textures rocheuses PBR déjà présentes servent uniquement aux socles,
	# plinthes et dalles minérales (pas aux façades peintes ni aux toitures).
	_stone = _make_rock_material(
		"res://assets/models/environment/coastal_rocks/rock_face_01_4k.gltf/textures/rock_face_01_diff_4k.jpg",
		"res://assets/models/environment/coastal_rocks/rock_face_01_4k.gltf/textures/rock_face_01_nor_gl_4k.jpg",
		"res://assets/models/environment/coastal_rocks/rock_face_01_4k.gltf/textures/rock_face_01_arm_4k.jpg",
		Color(0.88, 0.86, 0.82), 1.7)
	_white = _make_surface_shader(Color(0.82, 0.82, 0.78), 0.72, 0.52, 0.0)
	_gold = _mat(Color(0.73, 0.57, 0.27), 0.34, 0.62)
	_roof = _make_surface_shader(Color(0.67, 0.62, 0.49), 0.52, 0.7, 0.22)
	_glass = _mat(Color(0.055, 0.12, 0.16), 0.12, 0.72)
	_glass.metallic_specular = 0.9
	_glass.clearcoat_enabled = true
	_glass.clearcoat = 0.8
	_dark = _mat(Color(0.075, 0.085, 0.09), 0.62, 0.48)
	_paving = _make_rock_material(
		"res://assets/models/environment/coastal_rocks/rock_face_02_4k.gltf/textures/rock_face_02_diff_4k.jpg",
		"res://assets/models/environment/coastal_rocks/rock_face_02_4k.gltf/textures/rock_face_02_nor_gl_4k.jpg",
		"res://assets/models/environment/coastal_rocks/rock_face_02_4k.gltf/textures/rock_face_02_arm_4k.jpg",
		Color(0.82, 0.81, 0.77), 2.3)
	_yellow = _make_surface_shader(Color(0.82, 0.55, 0.13), 0.48, 0.75, 0.28)


func _make_rock_material(albedo_path: String, normal_path: String, arm_path: String,
		tint: Color, tiling: float) -> Material:
	var albedo := load(albedo_path) as Texture2D
	var normal := load(normal_path) as Texture2D
	var arm := load(arm_path) as Texture2D
	if albedo == null or normal == null or arm == null:
		push_warning("Texture roche PBR introuvable : matériau minéral procédural utilisé.")
		return _make_surface_shader(tint, 0.88, 0.34, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = 0.62
	material.ao_enabled = true
	material.ao_texture = arm
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = 0.88
	material.roughness_texture = arm
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.uv1_scale = Vector3(tiling, tiling, tiling)
	return material


func _make_surface_shader(base_color: Color, roughness: float, scale: float, metallic: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec3 base_color : source_color = vec3(0.8, 0.8, 0.8);
uniform float base_roughness = 0.8;
uniform float texture_scale = 0.5;
uniform float metalness = 0.0;
varying vec3 world_position;
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz * texture_scale;
	float broad = noise21(p * 0.16);
	float medium = noise21(p * 1.7);
	float grain = noise21(p * 15.0);
	float pores = noise21(p * 43.0);
	float variation = (broad - 0.5) * 0.075 + (medium - 0.5) * 0.045 + (grain - 0.5) * 0.025;
	float fine = smoothstep(0.25, 0.78, pores);
	ALBEDO = base_color * (1.0 + variation - fine * 0.018);
	ROUGHNESS = clamp(base_roughness + (grain - 0.5) * 0.12 + fine * 0.035, 0.22, 1.0);
	METALLIC = metalness;
	SPECULAR = 0.5;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("base_roughness", roughness)
	material.set_shader_parameter("texture_scale", scale)
	material.set_shader_parameter("metalness", metallic)
	return material


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _geo_to_world(latitude: float, longitude: float) -> Vector3:
	var x := (longitude - CENTER_LON) * METERS_PER_DEG_LAT * cos(deg_to_rad(CENTER_LAT))
	var z := (CENTER_LAT - latitude) * METERS_PER_DEG_LAT
	var y := 0.0
	var world_map := get_parent().get_node_or_null("WorldMap")
	if world_map != null and world_map.has_method("terrain_height_at_world"):
		y = world_map.terrain_height_at_world(x, z)
	return Vector3(x, y, z)


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, radial_segments: int = 16) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_monument() -> void:
	var site := Node3D.new()
	site.name = "Monument_Georges_Damas_Aleka"
	site.position = _geo_to_world(MONUMENT_LAT, MONUMENT_LON)
	add_child(site)

	# Parvis principal : dalle claire, joints de dilatation et cheminement axial.
	_box(site, "Parvis_pierre_naturelle", Vector3(90.0, 0.32, 48.0), Vector3(0, 0.16, 0), _paving)
	_add_platform_collision(site, Vector3(90.0, 0.4, 48.0), Vector3(0, 0.2, 0))
	for x in range(-40, 41, 10):
		_box(site, "Joint_parvis_%d" % x, Vector3(0.045, 0.012, 46.0), Vector3(float(x), 0.33, 0), _dark)
	_box(site, "Socle_batiment", Vector3(39.0, 0.9, 22.0), Vector3(0, 0.62, 0), _stone)

	# Arc monumental principal : 30 m de haut, véritable ouverture traversante.
	# Les deux jambages portent l'arc elliptique extrudé, plutôt qu'un linteau cubique.
	_box(site, "Jambage_gauche_arc", Vector3(8.0, 20.0, 17.0), Vector3(-14.0, 10.0, 0), _white)
	_box(site, "Jambage_droit_arc", Vector3(8.0, 20.0, 17.0), Vector3(14.0, 10.0, 0), _white)
	_add_platform_collision(site, Vector3(8.0, 20.0, 17.0), Vector3(-14.0, 10.0, 0))
	_add_platform_collision(site, Vector3(8.0, 20.0, 17.0), Vector3(14.0, 10.0, 0))
	_add_arch_band(site, 18.0, 10.0, 10.0, 7.0, 20.0, 17.0, 48, _white)

	# Socles, joints de panneaux et encadrements minéraux des grands jambages.
	for side in [-1.0, 1.0]:
		_box(site, "Socle_jambage_%s" % str(side), Vector3(8.6, 0.75, 18.0), Vector3(side * 14.0, 0.38, 0), _stone)
		for groove in range(4):
			var gx: float = float(side) * 14.0 + (float(groove) - 1.5) * 1.72
			_box(site, "Joint_vertical_arc_%s_%d" % [str(side), groove], Vector3(0.045, 18.5, 0.025), Vector3(gx, 10.0, 8.53), _stone)
		_box(site, "Bandeau_base_arc_%s" % str(side), Vector3(8.1, 0.22, 17.2), Vector3(side * 14.0, 1.05, 0), _gold)

	# Musée et hall d'exposition placés en retrait : l'ouverture monumentale reste lisible.
	_box(site, "Volume_musee_en_retrait", Vector3(19.0, 8.0, 12.0), Vector3(0, 4.2, -5.5), _stone)
	_add_platform_collision(site, Vector3(19.0, 8.0, 12.0), Vector3(0, 4.2, -5.5))
	_box(site, "Facade_vitree_musee", Vector3(17.0, 6.6, 0.20), Vector3(0, 4.2, 0.62), _glass)
	# La façade arrière reçoit également son vitrage et ses meneaux : le musée
	# reste fermé et détaillé lorsque le joueur contourne le bâtiment.
	_box(site, "Facade_vitree_musee_arriere", Vector3(17.0, 6.6, 0.20), Vector3(0, 4.2, -11.62), _glass)
	for mullion in range(9):
		var mx := -7.6 + float(mullion) * 1.9
		_box(site, "Meneau_musee_%02d" % mullion, Vector3(0.10, 6.4, 0.16), Vector3(mx, 4.2, 0.78), _dark)
		_box(site, "Meneau_musee_arriere_%02d" % mullion, Vector3(0.10, 6.4, 0.16), Vector3(mx, 4.2, -11.78), _dark)
	_box(site, "Auvent_musee", Vector3(21.0, 0.45, 13.5), Vector3(0, 8.45, -5.5), _white)

	# Structure supérieure sculpturale : deux montants courbes qui culminent à environ 47 m.
	# Les traverses donnent une vraie lecture de charpente métallique, sans bloc plein.
	var crest_left: Array[Vector3] = [Vector3(-4.5, 30.0, -0.2), Vector3(-4.0, 35.5, -0.2), Vector3(-2.2, 41.5, -0.2), Vector3(0.0, 47.0, -0.2)]
	var crest_right: Array[Vector3] = [Vector3(4.5, 30.0, -0.2), Vector3(4.0, 35.5, -0.2), Vector3(2.2, 41.5, -0.2), Vector3(0.0, 47.0, -0.2)]
	for segment in range(crest_left.size() - 1):
		_add_arch_beam(site, "Aile_sculpturale_gauche_%d" % segment, crest_left[segment], crest_left[segment + 1], 1.0, 1.45, _gold)
		_add_arch_beam(site, "Aile_sculpturale_droite_%d" % segment, crest_right[segment], crest_right[segment + 1], 1.0, 1.45, _gold)
		_add_arch_beam(site, "Traverse_sculpturale_%d" % segment, crest_left[segment], crest_right[segment], 0.42, 1.15, _dark)
	_add_arch_beam(site, "Liaison_sommet", crest_left[-1], crest_right[-1], 0.8, 1.6, _gold)
	_box(site, "Socle_structure_superieure", Vector3(19.0, 0.65, 14.0), Vector3(0, 29.8, -0.2), _stone)

	# Inscriptions patrimoniales sur les deux piliers et stèle au pied de l'arc.
	_add_3d_text(site, "AUTEUR DE LA CONCORDE", Vector3(-14.0, 14.0, 8.72), 17, _gold)
	_add_3d_text(site, "LA CONCORDE", Vector3(14.0, 14.0, 8.72), 20, _gold)
	_box(site, "Stele_memorielle", Vector3(3.2, 4.6, 0.38), Vector3(0, 2.7, 9.0), _stone)
	_add_3d_text(site, "GEORGES DAMAS ALEKA", Vector3(0, 3.2, 9.25), 15, _gold)
	_add_3d_text(site, "MONUMENT DE LA CONCORDE", Vector3(0, 1.35, 9.25), 11, _white)

	# Huit pavillons d'exposition périphériques (le bâtiment central représente l'Estuaire).
	var pavilion_positions: Array[Vector3] = [
		Vector3(-34, 0, -20), Vector3(-22, 0, -20), Vector3(-10, 0, -20), Vector3(10, 0, -20),
		Vector3(22, 0, -20), Vector3(34, 0, -20), Vector3(-17, 0, 20), Vector3(17, 0, 20)
	]
	for i in range(pavilion_positions.size()):
		_build_pavilion(site, i + 1, pavilion_positions[i])

	# Allée cérémonielle, bassins peu profonds et éclairage de mise en valeur.
	_box(site, "Axe_promenade", Vector3(8.0, 0.08, 42.0), Vector3(0, 0.36, -1.0), _white)
	for side in [-1.0, 1.0]:
		_box(site, "Bassin_reflet_%s" % str(side), Vector3(5.0, 0.16, 18.0), Vector3(side * 39.0, 0.40, 0), _glass)
		for lamp_index in range(5):
			var lz := -16.0 + float(lamp_index) * 8.0
			_cylinder(site, "Mât_eclairage_%s_%d" % [str(side), lamp_index], 0.10, 5.0, Vector3(side * 42.0, 2.8, lz), _dark, 12)
			_box(site, "Luminaire_%s_%d" % [str(side), lamp_index], Vector3(0.8, 0.22, 0.35), Vector3(side * 42.0, 5.4, lz), _gold)

	# Drapeaux gabonais devant le monument.
	for i in range(3):
		var flag_x := float(i - 1) * 4.0
		_cylinder(site, "Mât_drapeau_%d" % i, 0.07, 9.0, Vector3(flag_x, 4.8, -23.0), _dark, 12)
		_box(site, "Drapeau_%d" % i, Vector3(2.2, 1.25, 0.06), Vector3(flag_x + 1.1, 7.2, -23.0), _yellow)


func _add_quad_to_surface(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _add_arch_band(parent: Node3D, outer_radius_x: float, inner_radius_x: float, outer_rise: float, inner_rise: float, spring_height: float, depth: float, segments: int, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var half_depth := depth * 0.5
	for index in range(segments):
		var angle_0 := PI - PI * float(index) / float(segments)
		var angle_1 := PI - PI * float(index + 1) / float(segments)
		var outer_0 := Vector3(outer_radius_x * cos(angle_0), spring_height + outer_rise * sin(angle_0), half_depth)
		var outer_1 := Vector3(outer_radius_x * cos(angle_1), spring_height + outer_rise * sin(angle_1), half_depth)
		var inner_0 := Vector3(inner_radius_x * cos(angle_0), spring_height + inner_rise * sin(angle_0), half_depth)
		var inner_1 := Vector3(inner_radius_x * cos(angle_1), spring_height + inner_rise * sin(angle_1), half_depth)
		var outer_0_back := Vector3(outer_0.x, outer_0.y, -half_depth)
		var outer_1_back := Vector3(outer_1.x, outer_1.y, -half_depth)
		var inner_0_back := Vector3(inner_0.x, inner_0.y, -half_depth)
		var inner_1_back := Vector3(inner_1.x, inner_1.y, -half_depth)
		_add_quad_to_surface(surface, outer_0, outer_1, inner_1, inner_0)
		_add_quad_to_surface(surface, outer_1_back, outer_0_back, inner_0_back, inner_1_back)
		_add_quad_to_surface(surface, outer_0_back, outer_0, outer_1, outer_1_back)
		_add_quad_to_surface(surface, inner_1_back, inner_1, inner_0, inner_0_back)
		if index == 0:
			_add_quad_to_surface(surface, outer_0_back, outer_0, inner_0, inner_0_back)
		if index == segments - 1:
			_add_quad_to_surface(surface, outer_1, outer_1_back, inner_1_back, inner_1)
	surface.generate_normals()
	var arch_mesh := surface.commit()
	var arch_instance := MeshInstance3D.new()
	arch_instance.name = "Arc_elliptique_structurel"
	arch_instance.mesh = arch_mesh
	arch_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(arch_instance)
	var arch_body := StaticBody3D.new()
	arch_body.name = "Collision_arc_monumental"
	var arch_collision := CollisionShape3D.new()
	arch_collision.shape = arch_mesh.create_trimesh_shape()
	arch_body.add_child(arch_collision)
	parent.add_child(arch_body)


func _add_arch_beam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, width: float, depth: float, material: Material) -> void:
	var delta := finish - start
	var beam := MeshInstance3D.new()
	beam.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, delta.length() + 0.12, depth)
	beam.mesh = mesh
	beam.position = (start + finish) * 0.5
	beam.rotation.z = atan2(delta.y, delta.x) - PI * 0.5
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(beam)


func _build_pavilion(parent: Node3D, number: int, center: Vector3) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "Pavillon_province_%02d" % number
	pavilion.position = center
	parent.add_child(pavilion)
	_box(pavilion, "Socle_granit", Vector3(10.5, 0.55, 8.5), Vector3(0, 0.28, 0), _stone)
	_box(pavilion, "Volume_blanc", Vector3(9.8, 4.8, 7.8), Vector3(0, 2.85, 0), _white)
	_add_platform_collision(pavilion, Vector3(9.8, 4.8, 7.8), Vector3(0, 2.85, 0))
	_box(pavilion, "Toiture_debordante", Vector3(10.8, 0.42, 8.8), Vector3(0, 5.45, 0), _dark)
	_box(pavilion, "Bandeau_verre", Vector3(8.6, 2.0, 0.16), Vector3(0, 3.3, 3.98), _glass)
	for mullion in range(7):
		var px := -3.6 + float(mullion) * 1.2
		_box(pavilion, "Meneau_pavillon_%02d" % mullion, Vector3(0.08, 1.9, 0.12), Vector3(px, 3.3, 4.08), _dark)
	_box(pavilion, "Plaque_province", Vector3(5.6, 0.55, 0.18), Vector3(0, 4.65, 4.08), _gold)
	_add_3d_text(pavilion, PAVILION_PROVINCES[number - 1], Vector3(0, 4.55, 4.22), 10, _white)
	for side in [-1.0, 1.0]:
		_box(pavilion, "Pilastre_%s" % str(side), Vector3(0.22, 4.2, 0.28), Vector3(side * 4.65, 2.8, 4.0), _stone)


func _build_official_tribune() -> void:
	var site := Node3D.new()
	site.name = "Tribune_Officielle_Independance"
	site.position = _geo_to_world(TRIBUNE_LAT, TRIBUNE_LON)
	add_child(site)

	# Tribune monumentale jaune : gradins, allées rouges et assises vertes.
	_box(site, "Plateforme_beton", Vector3(82.0, 0.9, 38.0), Vector3(0, 0.45, 0), _stone)
	_add_platform_collision(site, Vector3(82.0, 1.0, 38.0), Vector3(0, 0.5, 0))
	var seat_transforms: Array[Transform3D] = []
	var backrest_transforms: Array[Transform3D] = []
	for row in range(10):
		var rz := -13.0 + float(row) * 2.35
		var ry := 1.0 + float(row) * 0.42
		_box(site, "Marche_gradin_%02d" % row, Vector3(74.0, 0.42, 2.7), Vector3(0, ry, rz), _stone)
		_add_platform_collision(site, Vector3(74.0, 0.42, 2.7), Vector3(0, ry, rz))
		for seat_index in range(9):
			var seat_x_left := -33.0 + float(seat_index) * 3.6
			var seat_x_right := 4.5 + float(seat_index) * 3.6
			for seat_x in [seat_x_left, seat_x_right]:
				seat_transforms.append(Transform3D(Basis.IDENTITY, Vector3(seat_x, ry + 0.68, rz - 0.18)))
				backrest_transforms.append(Transform3D(Basis.IDENTITY, Vector3(seat_x, ry + 0.94, rz + 0.20)))
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(3.35, 0.24, 0.88)
	seat_mesh.material = _dark
	var seat_multi := MultiMesh.new()
	seat_multi.transform_format = MultiMesh.TRANSFORM_3D
	seat_multi.mesh = seat_mesh
	seat_multi.instance_count = seat_transforms.size()
	for seat_index in range(seat_transforms.size()):
		seat_multi.set_instance_transform(seat_index, seat_transforms[seat_index])
	var seats := MultiMeshInstance3D.new()
	seats.name = "Sieges_individuels_tribune"
	seats.multimesh = seat_multi
	seats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(seats)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(3.35, 0.55, 0.16)
	back_mesh.material = _dark
	var back_multi := MultiMesh.new()
	back_multi.transform_format = MultiMesh.TRANSFORM_3D
	back_multi.mesh = back_mesh
	back_multi.instance_count = backrest_transforms.size()
	for seat_index in range(backrest_transforms.size()):
		back_multi.set_instance_transform(seat_index, backrest_transforms[seat_index])
	var backs := MultiMeshInstance3D.new()
	backs.name = "Dossiers_sieges_tribune"
	backs.multimesh = back_multi
	backs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(backs)
	var red_carpet := _mat(Color(0.48, 0.035, 0.045), 0.88)
	_box(site, "Alee_centrale_moquette_rouge", Vector3(4.2, 0.16, 28.0), Vector3(0, 1.2, 0), red_carpet)
	_box(site, "Estrade_officielle", Vector3(32.0, 1.0, 7.0), Vector3(0, 5.3, 14.0), _white)
	_add_platform_collision(site, Vector3(32.0, 1.0, 7.0), Vector3(0, 5.3, 14.0))
	_box(site, "Face_estrade", Vector3(30.0, 1.2, 0.35), Vector3(0, 5.0, 17.55), _yellow)
	_box(site, "Moquette_protocolaire", Vector3(25.0, 0.08, 8.0), Vector3(0, 5.85, 14.0), _gold)

	# Façade arrière jaune avec panneaux verticaux et baies sombres.
	_box(site, "Facade_arriere_jaune", Vector3(80.0, 12.0, 1.2), Vector3(0, 8.0, -16.0), _yellow)
	_add_platform_collision(site, Vector3(80.0, 12.0, 1.2), Vector3(0, 8.0, -16.0))
	for fin in range(41):
		var fx := -39.0 + float(fin) * 1.95
		_box(site, "Lame_facade_%02d" % fin, Vector3(0.22, 11.5, 0.34), Vector3(fx, 8.0, -15.25), _gold)
	for window_index in range(8):
		var wx := -32.0 + float(window_index) * 9.0
		_box(site, "Baie_facade_%02d" % window_index, Vector3(5.8, 2.6, 0.16), Vector3(wx, 5.0, -15.25), _glass)

	# Poteaux, poutres et charpente métallique apparente sous la couverture.
	for i in range(17):
		var px := -39.0 + float(i) * 4.875
		_cylinder(site, "Poteau_acier_%02d" % i, 0.24, 12.0, Vector3(px, 6.6, -1.0), _dark, 16)
		_box(site, "Console_poteau_%02d" % i, Vector3(0.7, 0.7, 1.0), Vector3(px, 11.5, -1.0), _yellow)
	for beam in range(9):
		var bz := -14.0 + float(beam) * 3.5
		_box(site, "Poutre_transversale_%02d" % beam, Vector3(80.0, 0.34, 0.38), Vector3(0, 12.3, bz), _dark)
	for brace in range(16):
		var bx := -38.0 + float(brace) * 5.0
		var brace_mesh := _box(site, "Contreventement_%02d" % brace, Vector3(0.22, 5.0, 0.22), Vector3(bx, 10.4, -1.0), _dark)
		brace_mesh.rotation.z = deg_to_rad(24.0 if brace % 2 == 0 else -24.0)

	# Couverture à dents de scie : alternance de panneaux et bandeaux de rive.
	_box(site, "Sous_face_toiture", Vector3(86.0, 0.55, 38.0), Vector3(0, 13.0, 0), _dark)
	for segment in range(16):
		var sx := -40.0 + float(segment) * 5.35
		var sy := 13.65 + (0.95 if segment % 2 == 0 else 0.0)
		var roof_panel := _box(site, "Panneau_toiture_%02d" % segment, Vector3(5.6, 0.38, 38.5), Vector3(sx, sy, 0), _yellow)
		roof_panel.rotation.z = deg_to_rad(3.0 if segment % 2 == 0 else -3.0)
		_box(site, "Nervure_toiture_%02d" % segment, Vector3(0.14, 0.5, 38.0), Vector3(sx + 2.7, sy + 0.18, 0), _dark)
	# Bande tricolore discrète sous l'avant de la couverture.
	for color_index in range(3):
		var stripe_color: Color = [Color(0.0, 0.42, 0.20), Color(0.96, 0.76, 0.10), Color(0.10, 0.26, 0.62)][color_index]
		var stripe_material := _mat(stripe_color, 0.72)
		_box(site, "Bandeau_national_%d" % color_index, Vector3(86.0, 0.16, 0.38), Vector3(0, 12.65, 18.8 + float(color_index) * 0.42), stripe_material)

	# Escaliers d'accès et rampes latérales.
	for side in [-1.0, 1.0]:
		for step in range(8):
			_box(site, "Marche_acces_%s_%d" % [str(side), step], Vector3(5.0, 0.24, 1.1), Vector3(side * 38.0, 1.0 + float(step) * 0.34, 13.0 - float(step) * 1.2), _stone)
			_add_platform_collision(site, Vector3(5.0, 0.24, 1.1), Vector3(side * 38.0, 1.0 + float(step) * 0.34, 13.0 - float(step) * 1.2))
		_cylinder(site, "Main_courante_%s" % str(side), 0.07, 12.0, Vector3(side * 40.5, 3.2, 8.0), _dark, 10)


func _build_freedom_stele() -> void:
	# Emplacement OSM de la Stèle de la Liberté : 0.39155, 9.44067.
	# Le personnage central est une interprétation de jeu, pas une copie sculpturale exacte.
	var site := Node3D.new()
	site.name = "Stele_Liberte"
	site.position = _geo_to_world(STELE_LAT, STELE_LON)
	var palace_position := _geo_to_world(PRESIDENTIAL_PALACE_LAT, PRESIDENTIAL_PALACE_LON)
	var facing := Vector2(palace_position.x - site.position.x, palace_position.z - site.position.z).normalized()
	site.rotation.y = atan2(-facing.x, -facing.y)
	add_child(site)

	_box(site, "Socle_stele_liberté", Vector3(18.0, 0.42, 12.0), Vector3(0, 0.21, 0), _paving)
	_add_platform_collision(site, Vector3(18.0, 0.5, 12.0), Vector3(0, 0.25, 0))
	_box(site, "Dalle_centrale", Vector3(8.8, 0.48, 5.4), Vector3(0, 0.45, 0), _stone)

	# Deux piliers de pierre encadrent la figure, conformément aux descriptions
	# documentaires de la stèle : reliefs géométriques et motifs sculptés stylisés.
	for side in [-1.0, 1.0]:
		var x := side * 4.0
		_box(site, "Pilier_sculpte_%s" % str(side), Vector3(0.95, 7.0, 1.0), Vector3(x, 3.95, -0.15), _stone)
		_box(site, "Chapiteau_pilier_%s" % str(side), Vector3(1.35, 0.38, 1.35), Vector3(x, 7.62, -0.15), _white)
		for band in range(5):
			var y := 1.25 + float(band) * 1.12
			var relief := _box(site, "Relief_geometrique_%s_%d" % [str(side), band],
				Vector3(0.58, 0.12, 0.08), Vector3(x, y, -0.68), _gold)
			relief.rotation.z = deg_to_rad(18.0 if band % 2 == 0 else -18.0)
		_box(site, "Bande_sculptee_pilier_%s" % str(side), Vector3(0.72, 0.34, 0.10), Vector3(x, 6.85, -0.70), _dark)

	# Figure androgyne en mouvement : buste, tête, jambes et bras tendus vers les chaînes.
	var body := MeshInstance3D.new()
	body.name = "Figure_liberation_buste"
	var torso := CapsuleMesh.new()
	torso.radius = 0.48
	torso.height = 2.05
	body.mesh = torso
	body.position = Vector3(0, 3.05, -0.55)
	body.material_override = _white
	site.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Figure_liberation_tete"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.42
	head_mesh.height = 0.84
	head.mesh = head_mesh
	head.position = Vector3(0, 4.55, -0.55)
	head.material_override = _white
	site.add_child(head)

	_cylinder_between(site, "Jambe_gauche", Vector3(-0.22, 1.95, -0.55), Vector3(-0.55, 0.85, -0.30), 0.22, _white)
	_cylinder_between(site, "Jambe_droite", Vector3(0.22, 1.95, -0.55), Vector3(0.55, 0.85, -0.80), 0.22, _white)
	_cylinder_between(site, "Bras_gauche_tendu", Vector3(-0.36, 3.75, -0.55), Vector3(-1.65, 4.55, -0.55), 0.19, _white)
	_cylinder_between(site, "Bras_droit_tendu", Vector3(0.36, 3.75, -0.55), Vector3(1.65, 4.55, -0.55), 0.19, _white)
	_cylinder_between(site, "Avant_bras_gauche", Vector3(-1.65, 4.55, -0.55), Vector3(-2.15, 4.15, -0.55), 0.15, _white)
	_cylinder_between(site, "Avant_bras_droit", Vector3(1.65, 4.55, -0.55), Vector3(2.15, 4.15, -0.55), 0.15, _white)

	# Chaînes rompues reliant les poignets aux piliers : maillons espacés et extrémités tombées.
	for side in [-1.0, 1.0]:
		for link in range(5):
			var t := float(link) / 5.0
			var start := Vector3(side * lerpf(2.15, 3.55, t), lerpf(4.15, 4.55, t), -0.60)
			var finish := start + Vector3(side * 0.22, -0.04, 0.0)
			_cylinder_between(site, "Chaine_rompue_%s_%d" % [str(side), link], start, finish, 0.055, _dark)
		_cylinder_between(site, "Chaine_tombee_%s" % str(side),
			Vector3(side * 2.7, 0.72, -0.75), Vector3(side * 3.3, 0.55, -0.75), 0.045, _gold)

	_add_3d_text(site, "STELE DE LA LIBERTE", Vector3(0, 0.85, -5.7), 18, _gold)
	_add_3d_text(site, "1848 - 1849", Vector3(0, 0.52, -5.7), 12, _white)


func _cylinder_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3,
		radius: float, material: Material) -> MeshInstance3D:
	var delta := finish - start
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(delta.length(), 0.05)
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = (start + finish) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, delta.normalized())
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_3d_text(parent: Node3D, value: String, position: Vector3, font_size: int, material: Material) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = Color.WHITE
	label.outline_size = 4
	label.outline_modulate = Color(0.12, 0.12, 0.12)
	label.material_override = material
	parent.add_child(label)


func _build_gabon_emblem(parent: Node3D, position: Vector3) -> void:
	_box(parent, "Support_armoiries", Vector3(1.5, 1.8, 0.22), position, _gold)
	_box(parent, "Bande_armoiries_verte", Vector3(1.15, 0.42, 0.10), position + Vector3(0, 0.42, 0.16), _mat(Color(0.0, 0.42, 0.20), 0.72))
	_box(parent, "Bande_armoiries_jaune", Vector3(1.15, 0.42, 0.10), position + Vector3(0, 0, 0.16), _mat(Color(0.96, 0.76, 0.10), 0.72))
	_box(parent, "Bande_armoiries_bleue", Vector3(1.15, 0.42, 0.10), position + Vector3(0, -0.42, 0.16), _mat(Color(0.10, 0.26, 0.62), 0.72))


func _build_province_shield(parent: Node3D, position: Vector3, side: int) -> void:
	_box(parent, "Blason_province_%d" % side, Vector3(1.35, 1.65, 0.16), position, _gold)
	_box(parent, "Couleur_blason_%d" % side, Vector3(0.95, 1.1, 0.10), position + Vector3(0, 0, 0.12), _mat(Color(0.10, 0.36, 0.25), 0.7))


func _add_platform_collision(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision_plateforme"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = position
	body.add_child(shape_node)
	parent.add_child(body)


func _add_memorial_title(parent: Node3D) -> void:
	var title := Label3D.new()
	title.name = "Inscription_Georges_Damas_Aleka"
	title.text = "GEORGES DAMAS ALEKA\nLA CONCORDE"
	title.font_size = 48
	title.pixel_size = 0.012
	title.modulate = Color(0.96, 0.91, 0.76)
	title.position = Vector3(0, 3.35, 3.9)
	title.rotation_degrees = Vector3(0, 180, 0)
	title.outline_size = 8
	title.outline_modulate = Color(0.12, 0.12, 0.12)
	parent.add_child(title)
