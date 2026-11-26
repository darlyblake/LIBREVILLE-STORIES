extends Node3D
## Reconstructions 3D de services publics à partir des POI OSM de Libreville.
const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const DATA_PATH := "res://data/osm/extended/pois.geojson"
const MAP_SOUTH := 0.355
const MAP_WEST := 9.400
const MAP_NORTH := 0.445
const MAP_EAST := 9.495
var map: Node
var concrete: StandardMaterial3D
var structural_concrete: StandardMaterial3D
var weathered_concrete: StandardMaterial3D
var white: StandardMaterial3D
var blue: StandardMaterial3D
var red: StandardMaterial3D
var roof: StandardMaterial3D
var steel: StandardMaterial3D
var glass: StandardMaterial3D
var asphalt: StandardMaterial3D
var school_accent: StandardMaterial3D
var hotel_accent: StandardMaterial3D
var count := 0
var school_count := 0
var hotel_count := 0
var use_pbr_textures := true

func _ready() -> void:
	map = get_parent().get_node_or_null("WorldMap")
	if map == null: return
	var graphics_config := ConfigFile.new()
	if graphics_config.load("user://graphics_settings.cfg") == OK:
		use_pbr_textures = bool(graphics_config.get_value("graphics", "pbr_textures", true))
	_make_materials()
	for i in range(600):
		if bool(map.get("_dem_loaded")):
			break
		await get_tree().process_frame
	_build_facilities()

func _make_materials() -> void:
	concrete = _facility_mat(Color(0.72,0.71,0.66), "concrete_floor_01", _texture(false))
	structural_concrete = _facility_mat(Color(0.66,0.65,0.61), "concrete_wall_009", _texture(false))
	weathered_concrete = _facility_mat(Color(0.58,0.57,0.53), "dirty_concrete", _texture(false))
	white = _facility_mat(Color(0.92,0.91,0.84), "white_plaster_02", _texture(false))
	blue = _facility_mat(Color(0.12,0.30,0.52), "white_plaster_02", _texture(false))
	red = _facility_mat(Color(0.72,0.10,0.09), "red_bricks_04", _texture(false))
	roof = _facility_mat(Color(0.78,0.79,0.77), "corrugated_iron_03", _texture(true))
	steel = _facility_mat(Color(0.72,0.73,0.72), "metal_plate_02", _texture(true))
	steel.metallic = 0.72
	asphalt = _facility_mat(Color(0.24,0.25,0.24), "asphalt_03", _texture(false))
	school_accent = _facility_mat(Color(0.12,0.28,0.48), "metal_plate_02", _texture(true))
	hotel_accent = _facility_mat(Color(0.48,0.31,0.18), "brushed_concrete", _texture(false))
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.20,0.40,0.51,0.82)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.2

func _mat(tint: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex
	m.roughness = 0.86
	m.uv1_scale = Vector3(2,2,2)
	return m

func _facility_mat(tint: Color, asset_id: String, fallback: Texture2D) -> StandardMaterial3D:
	if use_pbr_textures:
		return _pbr_mat(tint, asset_id, fallback)
	return _mat(tint, fallback)

func _pbr_mat(tint: Color, asset_id: String, fallback: Texture2D) -> StandardMaterial3D:
	var material := _mat(tint, fallback)
	var folder := "res://assets/textures/pbr/%s/" % asset_id
	var diffuse := _find_pbr_map(folder, asset_id, "diff")
	var normal := _find_pbr_map(folder, asset_id, "nor_gl")
	var roughness := _find_pbr_map(folder, asset_id, "rough")
	var ao := _find_pbr_map(folder, asset_id, "ao")
	var metal_map := _find_pbr_map(folder, asset_id, "metal")
	if diffuse != null:
		material.albedo_texture = diffuse
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.8
	if roughness != null:
		material.roughness_texture = roughness
	if ao != null:
		material.ao_enabled = true
		material.ao_texture = ao
	if metal_map != null:
		material.metallic = 1.0
		material.metallic_texture = metal_map
	material.uv1_scale = Vector3(2.0, 2.0, 2.0)
	return material

func _find_pbr_map(folder: String, asset_id: String, map_suffix: String) -> Texture2D:
	var absolute_folder := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(absolute_folder):
		return null
	for filename in DirAccess.get_files_at(absolute_folder):
		if filename.get_basename().ends_with("_" + map_suffix):
			return load(folder + filename) as Texture2D
	return null

func _texture(metal: bool) -> ImageTexture:
	var img := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var noise := float(posmod(x*37+y*71+x*y*3,29))/29.0
			var v := 0.78+(noise-0.5)*0.09
			if metal and posmod(x,8)<2: v=0.61
			img.set_pixel(x,y,Color(v,v*0.99,v*0.96,1))
	return ImageTexture.create_from_image(img)

func _build_facilities() -> void:
	var f := FileAccess.open(DATA_PATH,FileAccess.READ)
	if f == null:
		push_warning("POI étendus absents : infrastructures non générées.")
		return
	var doc: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not doc is Dictionary: return
	var player := get_parent().get_node_or_null("Player") as Node3D
	var origin := Vector2.ZERO
	if player: origin=Vector2(player.global_position.x,player.global_position.z)
	var entries: Array[Dictionary]=[]
	var has_water_forests_site := false
	var has_senate_site := false
	var has_public_service_site := false
	var has_justice_site := false
	var has_health_ministry_site := false
	var has_foreign_affairs_site := false
	var has_tpi_annex_site := false
	var has_budget_directorate_site := false
	var has_communication_ministry_site := false
	var has_interior_ministry_site := false
	var has_education_ministry_site := false
	var has_aninf_site := false
	var has_treasury_site := false
	var has_cima_site := false
	var has_presidential_palace_site := false
	var has_labour_ministry_site := false
	var has_planning_ministry_site := false
	var has_ceeac_site := false
	var has_anuttc_site := false
	var has_brac_oif_site := false
	var has_dgttc_site := false
	var has_dgel_site := false
	var has_cnee_site := false
	var has_cnd_site := false
	var has_customs_site := false
	var has_constitutional_court_site := false
	var has_agasa_site := false
	var has_cartography_institute_site := false
	var has_cppf_site := false
	var has_cntippee_site := false
	var has_egabon_site := false
	var has_seeg_site := false
	var has_dgdi_site := false
	var has_habitat_technical_center_site := false
	var has_mairie_nombakele_site := false
	var has_mairie_nzeng_ayong_site := false
	var has_mairie_hauts_guegue_site := false
	var has_mairie_2e_arrondissement_site := false
	var has_mairie_4e_arrondissement_site := false
	var has_chamber_of_commerce_site := false
	var has_assembly_site := false
	for item in doc.get("features",[]):
		if not item is Dictionary: continue
		var g: Dictionary=item.get("geometry",{})
		var c := _geometry_center(g)
		if c.size()<2: continue
		# Filtre géographique strict : aucun POI hors de l'emprise validée
		# ne peut être instancié, même s'il est présent dans l'extraction étendue.
		var longitude := float(c[0])
		var latitude := float(c[1])
		if latitude < MAP_SOUTH or latitude > MAP_NORTH or longitude < MAP_WEST or longitude > MAP_EAST:
			continue
		var p: Dictionary=item.get("properties",{})
		var poi_name := str(p.get("name:fr", p.get("name", ""))).to_lower()
		var poi_osm_id := int(p.get("osm_id", 0))
		if poi_osm_id == 249526245 or (poi_name.contains("eaux") and poi_name.contains("foret")):
			has_water_forests_site = true
		if poi_name.contains("senat") or poi_name.contains("palais omar bongo"):
			has_senate_site = true
		if poi_name.contains("fonction publique"):
			has_public_service_site = true
		if poi_name.contains("ministere de la justice") or poi_name.contains("ministere de justice"):
			has_justice_site = true
		if poi_osm_id == 430390761 or (poi_name.contains("ministere") and poi_name.contains("sante")):
			has_health_ministry_site = true
		if poi_osm_id == 13375677182 or poi_name.contains("maison jean ping") or poi_name.contains("hotel des affaires etrangeres"):
			has_foreign_affairs_site = true
		if poi_osm_id == 1549705432 or poi_name.contains("tribunal de premiere instance"):
			has_tpi_annex_site = true
		if poi_name.contains("direction generale du budget") or poi_name == "dgb":
			has_budget_directorate_site = true
		if poi_osm_id == 5763821475 or poi_name.contains("ministere de la communication"):
			has_communication_ministry_site = true
		if poi_osm_id == 14091673588 or poi_name.contains("ministere de l interieur"):
			has_interior_ministry_site = true
		if poi_osm_id == 410354024 or poi_name.contains("ministere de l education nationale"):
			has_education_ministry_site = true
		if poi_osm_id == 455714440 or poi_name.contains("agence nationale des infrastructures numeriques") or poi_name.contains("aninf"):
			has_aninf_site = true
		if poi_osm_id == 455714429 or poi_name.contains("direction generale de la comptabilite publique") or poi_name.contains("dgcpt"):
			has_treasury_site = true
		if poi_osm_id == 455714470 or poi_name.contains("conference interafricaine des marches d assurances") or poi_name.contains("cima"):
			has_cima_site = true
		if poi_osm_id == 168587922 or poi_name.contains("palais presidentiel") or poi_name.contains("palais du bord de mer"):
			has_presidential_palace_site = true
		if poi_osm_id == 4686643890 or poi_name.contains("ministere du travail"):
			has_labour_ministry_site = true
		if poi_osm_id == 1243106067 or poi_name.contains("ministere de la planification"):
			has_planning_ministry_site = true
		if poi_osm_id == 424241587 or poi_name.contains("ceeac"):
			has_ceeac_site = true
		if poi_osm_id == 806267454 or poi_name.contains("agence nationale de l urbanisme") or poi_name.contains("anut tc") or poi_name.contains("anuttc"):
			has_anuttc_site = true
		if poi_osm_id == 625614944 or poi_name.contains("bureau de l oif") or poi_name.contains("brac-oif") or poi_name.contains("organisation internationale de la francophonie"):
			has_brac_oif_site = true
		if poi_osm_id == 816220349 or poi_name.contains("direction generale des travaux topographiques") or poi_name.contains("d g t t c"):
			has_dgttc_site = true
		if poi_osm_id == 11421865904 or poi_name.contains("direction generale des etudes et laboratoires"):
			has_dgel_site = true
		if poi_osm_id == 12150167700 or poi_name.contains("conseil national de l eau") or poi_name.contains("conseil national de l'électricité"):
			has_cnee_site = true
		if poi_osm_id == 11529395192 or poi_name.contains("conseil national de la democratie"):
			has_cnd_site = true
		if poi_name.contains("palais leon mba") or poi_name.contains("assemblee nationale"):
			has_assembly_site = true
		if poi_osm_id == 12727052424 or poi_name.contains("direction generale des douanes") or poi_name.contains("douanes et droits indirects"):
			has_customs_site = true
		if poi_osm_id == 410343353 or poi_name.contains("cour constitutionnelle"):
			has_constitutional_court_site = true
		if poi_osm_id == 12832789224 or poi_name == "agasa" or poi_name.contains("agence gabonaise de securite alimentaire"):
			has_agasa_site = true
		if poi_osm_id == 793967943 or poi_name.contains("institut national de cartographie") or poi_name == "inc":
			has_cartography_institute_site = true
		if poi_osm_id == 12099801407 or poi_name.contains("caisse des pensions et des prestations familiales") or poi_name == "cppf":
			has_cppf_site = true
		if poi_osm_id == 12099801403 or poi_name.contains("commission nationale des travaux d interet public") or poi_name.contains("cntippee"):
			has_cntippee_site = true
		if poi_osm_id == 636626338 or poi_name == "egabon":
			has_egabon_site = true
		if poi_osm_id == 456742208 or poi_name.contains("societe d energie et d eau du gabon") or poi_name == "seeg":
			has_seeg_site = true
		if poi_osm_id == 2910360231 or poi_name.contains("direction generale de la documentation et de l immigration") or poi_name == "dgdi":
			has_dgdi_site = true
		if poi_osm_id == 11133203583 or poi_name.contains("centre technique de l habitat"):
			has_habitat_technical_center_site = true
		if poi_osm_id == 1343319442 or poi_name.contains("mairie de nombakele") or poi_name.contains("mairie 3eme arrondissement"):
			has_mairie_nombakele_site = true
		if poi_osm_id == 1348678391 or poi_name.contains("mairie de nzeng ayong"):
			has_mairie_nzeng_ayong_site = true
		if poi_osm_id == 4040655377 or poi_name.contains("mairie hauts de guegue"):
			has_mairie_hauts_guegue_site = true
		if poi_osm_id == 11458214434 or poi_name.contains("mairie du 2eme arrondissement") or poi_name.contains("mairie du 2e arrondissement"):
			has_mairie_2e_arrondissement_site = true
		if poi_osm_id == 1346923818 or poi_name.contains("mairie de plaine niger") or poi_name.contains("mairie du 4eme arrondissement"):
			has_mairie_4e_arrondissement_site = true
		if poi_osm_id == 456350865 or poi_name.contains("chambre de commerce"):
			has_chamber_of_commerce_site = true
		var kind := _kind(p)
		if kind=="": continue
		var pos := _geo(c)
		var label := str(p.get("name:fr",""))
		if label.is_empty(): label=str(p.get("name",""))
		if label.is_empty(): label=_default_name(kind)
		var osm_id := int(p.get("osm_id",0))
		if osm_id == 0: osm_id=int(str(p.get("@id","0")).replace("way/","").replace("node/","").replace("relation/",""))
		var footprint_size := _geometry_size_m(g)
		var footprint := _geometry_outer_ring(g, pos)
		entries.append({"kind":kind,"label":label,"pos":pos,"id":osm_id,"lat":latitude,"lon":longitude,"footprint_size":footprint_size,"footprint":footprint})
	# Le siège historique des Eaux et Forêts est cartographié sur le boulevard Triomphal
	# (OSM way 249526245). Si l'extraction POI ne l'a pas retenu, ajouter uniquement
	# son repère au centroïde OSM connu : le bâtiment 3D reste celui de buildings.geojson.
	# Aucun volume ni aucune parcelle artificielle ne sont créés ici.
	if not has_water_forests_site:
		var water_forests_position := _geo([9.44034, 0.40887])
		entries.append({
			"kind": "ministry",
			"label": "Immeuble des Eaux et Forêts",
			"pos": water_forests_position,
			"id": 249526245,
			"lat": 0.40887,
			"lon": 9.44034,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Le Palais Omar Bongo Ondimba est le siège du Sénat, boulevard Triomphal.
	# Repère de secours uniquement : le volume architectural reste issu de buildings.geojson.
	if not has_senate_site:
		var senate_position := _geo([9.442867, 0.4085292])
		entries.append({
			"kind": "admin",
			"label": "Palais Omar Bongo Ondimba — Sénat",
			"pos": senate_position,
			"id": 3369330,
			"lat": 0.4085292,
			"lon": 9.442867,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Le ministère est cartographié comme nœud OSM 4940709339, face à l'ambassade de Chine.
	# Repère de secours seulement si le POI n'est pas présent dans l'extraction ; aucun bâtiment n'est créé.
	if not has_public_service_site:
		var public_service_position := _geo([9.44544, 0.41146])
		entries.append({
			"kind": "ministry",
			"label": "Ministère de la Fonction publique",
			"pos": public_service_position,
			"id": 4940709339,
			"lat": 0.41146,
			"lon": 9.44544,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère de la Justice, rue Pecqueur : repère GPS vérifié dans la zone.
	# N'ajoute aucun volume ; le bâtiment demeure celui de l'extraction buildings.geojson.
	if not has_justice_site:
		var justice_position := _geo([9.4460964, 0.3858865])
		entries.append({
			"kind": "court",
			"label": "Ministère de la Justice — Rue Pecqueur",
			"pos": justice_position,
			"id": 0,
			"lat": 0.3858865,
			"lon": 9.4460964,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère de la Santé, Immeuble Alu-Suisse, secteur du Tribunal.
	# Repère GPS issu de la cartographie OSM ; aucun volume architectural n'est créé ici.
	if not has_health_ministry_site:
		var health_ministry_position := _geo([9.44909, 0.42724])
		entries.append({
			"kind": "ministry",
			"label": "Ministère de la Santé — Immeuble Alu-Suisse",
			"pos": health_ministry_position,
			"id": 430390761,
			"lat": 0.42724,
			"lon": 9.44909,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Maison Jean Ping : nouvel Hôtel des Affaires étrangères, inauguré en 2026.
	# Le point OSM sert de repère uniquement ; aucun volume de bâtiment n'est ajouté.
	if not has_foreign_affairs_site:
		var foreign_affairs_position := _geo([9.43495, 0.40492])
		entries.append({
			"kind": "ministry",
			"label": "Maison Jean Ping — Affaires étrangères",
			"pos": foreign_affairs_position,
			"id": 13375677182,
			"lat": 0.40492,
			"lon": 9.43495,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Annexe du Tribunal de Première Instance de Libreville, inaugurée en mai 2026.
	# Le contour physique reste fourni par buildings.geojson ; ce bloc ajoute uniquement
	# le repère nommé si le POI OSM correspondant manque dans l'extraction.
	if not has_tpi_annex_site:
		var tpi_annex_position := _geo([9.45096, 0.42648])
		entries.append({
			"kind": "court",
			"label": "Annexe du Tribunal de Première Instance de Libreville",
			"pos": tpi_annex_position,
			"id": 1549705432,
			"lat": 0.42648,
			"lon": 9.45096,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Direction Générale du Budget, avenue Félix Éboué : coordonnées GPS publiées
	# par l'institution. Repère de POI uniquement ; le bâtiment physique provient
	# exclusivement de buildings.geojson.
	if not has_budget_directorate_site:
		var budget_directorate_position := _geo([9.44900, 0.38800])
		entries.append({
			"kind": "admin",
			"label": "Direction Générale du Budget — Avenue Félix Éboué",
			"pos": budget_directorate_position,
			"id": 0,
			"lat": 0.38800,
			"lon": 9.44900,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère de la Communication et des Médias, derrière la Poste,
	# avenue Augustin-Boumah. Point OSM 5763821475 confirmé par la cartographie.
	# Repère uniquement : aucun volume n'est généré ici.
	if not has_communication_ministry_site:
		var communication_ministry_position := _geo([9.44478, 0.38752])
		entries.append({
			"kind": "admin",
			"label": "Ministère de la Communication et des Médias",
			"pos": communication_ministry_position,
			"id": 5763821475,
			"lat": 0.38752,
			"lon": 9.44478,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère de l'Intérieur, de la Sécurité et de la Décentralisation.
	# Adresse officielle : 119 rue Jean-Baptiste Ndende, avenue de Cointet.
	# Le point OSM 14091673588 sert de repère ; aucun volume n'est ajouté.
	if not has_interior_ministry_site:
		var interior_ministry_position := _geo([9.4476, 0.39078])
		entries.append({
			"kind": "ministry",
			"label": "Ministère de l’Intérieur, de la Sécurité et de la Décentralisation",
			"pos": interior_ministry_position,
			"id": 14091673588,
			"lat": 0.39078,
			"lon": 9.4476,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère de l'Éducation nationale, chargé de la Formation civique.
	# OSM way 410354024 ; point cartographique vérifié à Libreville.
	# Repère uniquement : le bâtiment physique vient de buildings.geojson.
	if not has_education_ministry_site:
		var education_ministry_position := _geo([9.44551, 0.39396])
		entries.append({
			"kind": "ministry",
			"label": "Ministère de l’Éducation nationale — Formation civique",
			"pos": education_ministry_position,
			"id": 410354024,
			"lat": 0.39396,
			"lon": 9.44551,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Agence Nationale des Infrastructures Numériques et des Fréquences (ANINF).
	# OSM way 455714440, Immeuble de la Solde, 393 avenue Rose Francine Rogombe.
	# Repère seulement : la géométrie du bâtiment est fournie par buildings.geojson.
	if not has_aninf_site:
		var aninf_position := _geo([9.44510, 0.39245])
		entries.append({
			"kind": "admin",
			"label": "Agence Nationale des Infrastructures Numériques et des Fréquences (ANINF)",
			"pos": aninf_position,
			"id": 455714440,
			"lat": 0.39245,
			"lon": 9.44510,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Direction Générale de la Comptabilité Publique et du Trésor (DGCPT).
	# OSM way 455714429, 321 avenue Rose Francine Rogombe.
	# Le bâtiment est représenté par son empreinte buildings.geojson ; repère seulement.
	if not has_treasury_site:
		var treasury_position := _geo([9.44461, 0.39216])
		entries.append({
			"kind": "admin",
			"label": "Direction Générale de la Comptabilité Publique et du Trésor",
			"pos": treasury_position,
			"id": 455714429,
			"lat": 0.39216,
			"lon": 9.44461,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Conférence Interafricaine des Marchés d’Assurances (CIMA), centre-ville.
	# OSM way 455714470 ; centroïde cartographique dans l’emprise validée.
	# Repère uniquement : le bâtiment physique provient de buildings.geojson.
	if not has_cima_site:
		var cima_position := _geo([9.44528, 0.3904])
		entries.append({
			"kind": "admin",
			"label": "Conférence Interafricaine des Marchés d’Assurances (CIMA)",
			"pos": cima_position,
			"id": 455714470,
			"lat": 0.3904,
			"lon": 9.44528,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Palais présidentiel du Bord de mer, boulevard de l’Indépendance.
	# OSM way 168587922 ; point cartographique confirmé dans la zone jouable.
	# Repère uniquement : le volume physique provient de buildings.geojson.
	if not has_presidential_palace_site:
		var presidential_palace_position := _geo([9.44235, 0.39237])
		entries.append({
			"kind": "admin",
			"label": "Palais présidentiel du Bord de mer",
			"pos": presidential_palace_position,
			"id": 168587922,
			"lat": 0.39237,
			"lon": 9.44235,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère du Travail et de la Formation professionnelle, point OSM node 4686643890.
	# Coordonnées cartographiques vérifiées dans l'emprise jouable ; repère seulement.
	if not has_labour_ministry_site:
		entries.append({
			"kind": "ministry",
			"label": "Ministère du Travail et de la Formation professionnelle",
			"pos": _geo([9.44887, 0.42757]),
			"id": 4686643890,
			"lat": 0.42757,
			"lon": 9.44887,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Ministère de la Planification et de la Prospective, OSM way 1243106067.
	# Le bâtiment réel reste issu de buildings.geojson ; aucun volume de secours.
	if not has_planning_ministry_site:
		entries.append({
			"kind": "ministry",
			"label": "Ministère de la Planification et de la Prospective",
			"pos": _geo([9.42566, 0.4226]),
			"id": 1243106067,
			"lat": 0.4226,
			"lon": 9.42566,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# CEEAC, Haut de Gué-Gué, OSM way 424241587 ; point dans la zone validée.
	# Repère de site uniquement, le bâtiment physique provient de buildings.geojson.
	if not has_ceeac_site:
		entries.append({
			"kind": "admin",
			"label": "Communauté Économique des États de l’Afrique Centrale (CEEAC)",
			"pos": _geo([9.43105, 0.42858]),
			"id": 424241587,
			"lat": 0.42858,
			"lon": 9.43105,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# ANUTTC — Agence Nationale de l'Urbanisme, des Travaux Topographiques et du Cadastre.
	# OSM way 806267454, bâtiment de bureaux cartographié à Oloumi.
	# Repère nommé uniquement ; le contour réel reste celui de buildings.geojson.
	if not has_anuttc_site:
		entries.append({
			"kind": "admin",
			"label": "Agence Nationale de l’Urbanisme, des Travaux Topographiques et du Cadastre (ANUTTC)",
			"pos": _geo([9.46208, 0.38001]),
			"id": 806267454,
			"lat": 0.38001,
			"lon": 9.46208,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Bureau régional de l'OIF pour l'Afrique centrale (BRAC-OIF), OSM way 625614944.
	# Bâtiment cartographié ; le volume physique reste issu de buildings.geojson.
	if not has_brac_oif_site:
		entries.append({
			"kind": "admin",
			"label": "Bureau régional de l’OIF — Afrique centrale (BRAC-OIF)",
			"pos": _geo([9.42647, 0.43037]),
			"id": 625614944,
			"lat": 0.43037,
			"lon": 9.42647,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Direction Générale des Travaux Topographiques et du Cadastre (DGTTC), OSM way 816220349.
	# Site distinct de l'ANUTTC d'Oloumi ; bâtiment physique fourni par buildings.geojson.
	if not has_dgttc_site:
		entries.append({
			"kind": "admin",
			"label": "Direction Générale des Travaux Topographiques et du Cadastre (DGTTC)",
			"pos": _geo([9.42733, 0.42335]),
			"id": 816220349,
			"lat": 0.42335,
			"lon": 9.42733,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Direction Générale des Études et Laboratoires (DGEL), OSM node 11421865904.
	# Bureau gouvernemental à Ancien Sobraga ; repère sans volume artificiel.
	if not has_dgel_site:
		entries.append({
			"kind": "admin",
			"label": "Direction Générale des Études et Laboratoires (DGEL)",
			"pos": _geo([9.4492, 0.4182]),
			"id": 11421865904,
			"lat": 0.4182,
			"lon": 9.4492,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Conseil National de l'Eau et de l'Electricité (CNEE), OSM node 12150167700.
	# Siège social à Haut de Gué-Gué ; bâtiment physique issu de buildings.geojson.
	if not has_cnee_site:
		entries.append({
			"kind": "admin",
			"label": "Conseil National de l’Eau et de l’Électricité (CNEE)",
			"pos": _geo([9.43147, 0.42836]),
			"id": 12150167700,
			"lat": 0.42836,
			"lon": 9.43147,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Conseil National de la Démocratie (CND), OSM node 11529395192.
	# Point Mapcarta/OSM ; le bâtiment physique reste issu de buildings.geojson.
	if not has_cnd_site:
		entries.append({
			"kind": "admin",
			"label": "Conseil National de la Démocratie (CND)",
			"pos": _geo([9.45075, 0.41810]),
			"id": 11529395192,
			"lat": 0.41810,
			"lon": 9.45075,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Palais Léon Mba — Assemblée nationale. Coordonnées publiées : 0°24′44″N, 9°26′34″E.
	# Conversion DMS -> degrés décimaux ; repère seul, volume depuis buildings.geojson.
	if not has_assembly_site:
		entries.append({
			"kind": "admin",
			"label": "Palais Léon Mba — Assemblée nationale",
			"pos": _geo([9.4427778, 0.4122222]),
			"id": 0,
			"lat": 0.4122222,
			"lon": 9.4427778,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Direction Générale des Douanes et Droits Indirects, OSM node 12727052424.
	# 823 Avenue Edouard Ekomie Mba, Oloumi ; point dans l'emprise validée.
	if not has_customs_site:
		entries.append({
			"kind": "admin",
			"label": "Direction Générale des Douanes et Droits Indirects",
			"pos": _geo([9.46677, 0.37618]),
			"id": 12727052424,
			"lat": 0.37618,
			"lon": 9.46677,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Cour constitutionnelle du Gabon, boulevard de l’Indépendance.
	# OSM way 410343353 ; le repère reste indépendant de l’empreinte physique buildings.geojson.
	if not has_constitutional_court_site:
		entries.append({
			"kind": "court",
			"label": "Cour constitutionnelle du Gabon",
			"pos": _geo([9.43989, 0.39687]),
			"id": 410343353,
			"lat": 0.39687,
			"lon": 9.43989,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Agence Gabonaise de Sécurité Alimentaire (AGASA), Batterie 4.
	# OSM node 12832789224 ; repère seulement, volume physique depuis buildings.geojson.
	if not has_agasa_site:
		entries.append({
			"kind": "admin",
			"label": "Agence Gabonaise de Sécurité Alimentaire (AGASA)",
			"pos": _geo([9.42785, 0.41896]),
			"id": 12832789224,
			"lat": 0.41896,
			"lon": 9.42785,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Direction générale de l'Institut National de Cartographie (INC), Camp de police.
	# OSM way 793967943 ; l'INC publie cette adresse comme Direction générale.
	# Le siège technique de Batterie IV est une autre implantation, non ajoutée ici.
	if not has_cartography_institute_site:
		entries.append({
			"kind": "admin",
			"label": "Institut National de Cartographie — Direction générale",
			"pos": _geo([9.44126, 0.40102]),
			"id": 793967943,
			"lat": 0.40102,
			"lon": 9.44126,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# CPPF — Caisse des Pensions et des Prestations Familiales, OSM node 12099801407.
	# CNTIPPEE — OSM node 12099801403 ; les deux implantations sont dans la zone jouable.
	# Ces repères n’ajoutent aucun volume 3D : les bâtiments restent issus de buildings.geojson.
	if not has_cppf_site:
		entries.append({
			"kind": "admin",
			"label": "Caisse des Pensions et des Prestations Familiales (CPPF)",
			"pos": _geo([9.41896, 0.43855]),
			"id": 12099801407,
			"lat": 0.43855,
			"lon": 9.41896,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	if not has_cntippee_site:
		entries.append({
			"kind": "admin",
			"label": "Commission Nationale des Travaux d’Intérêt Public pour la Promotion de l’Entreprenariat et de l’Emploi (CNTIPPEE)",
			"pos": _geo([9.41887, 0.44026]),
			"id": 12099801403,
			"lat": 0.44026,
			"lon": 9.41887,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# eGabon et siège social SEEG : services publics distincts, repères sur empreintes existantes.
	if not has_egabon_site:
		entries.append({
			"kind": "admin",
			"label": "eGabon — Service public numérique",
			"pos": _geo([9.44786, 0.38566]),
			"id": 636626338,
			"lat": 0.38566,
			"lon": 9.44786,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	if not has_seeg_site:
		entries.append({
			"kind": "admin",
			"label": "Société d’Énergie et d’Eau du Gabon (SEEG) — Siège social",
			"pos": _geo([9.44671, 0.39300]),
			"id": 456742208,
			"lat": 0.39300,
			"lon": 9.44671,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Deux services administratifs cartographiés dans la zone : DGDI à Oloumi
	# et Centre Technique de l’Habitat à Nzeng-Ayong. Repères uniquement.
	if not has_dgdi_site:
		entries.append({
			"kind": "admin",
			"label": "Direction Générale de la Documentation et de l’Immigration (DGDI)",
			"pos": _geo([9.467, 0.38207]),
			"id": 2910360231,
			"lat": 0.38207,
			"lon": 9.467,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	if not has_habitat_technical_center_site:
		entries.append({
			"kind": "admin",
			"label": "Centre Technique de l’Habitat — Nzeng-Ayong",
			"pos": _geo([9.48454, 0.42044]),
			"id": 11133203583,
			"lat": 0.42044,
			"lon": 9.48454,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Mairies d’arrondissement cartographiées dans la zone jouable.
	if not has_mairie_nombakele_site:
		entries.append({
			"kind": "admin", "label": "Mairie de Nombakélé — 3e arrondissement",
			"pos": _geo([9.45077, 0.39109]), "id": 1343319442,
			"lat": 0.39109, "lon": 9.45077,
			"footprint_size": Vector2.ZERO, "footprint": PackedVector2Array()
		})
	if not has_mairie_nzeng_ayong_site:
		entries.append({
			"kind": "admin", "label": "Mairie de Nzeng-Ayong",
			"pos": _geo([9.47159, 0.42399]), "id": 1348678391,
			"lat": 0.42399, "lon": 9.47159,
			"footprint_size": Vector2.ZERO, "footprint": PackedVector2Array()
		})
	if not has_mairie_hauts_guegue_site:
		entries.append({
			"kind": "admin", "label": "Mairie des Hauts de Gué-Gué",
			"pos": _geo([9.43262, 0.42802]), "id": 4040655377,
			"lat": 0.42802, "lon": 9.43262,
			"footprint_size": Vector2.ZERO, "footprint": PackedVector2Array()
		})
	if not has_mairie_2e_arrondissement_site:
		entries.append({
			"kind": "admin", "label": "Mairie du 2e arrondissement — avenue Jean-Paul II",
			"pos": _geo([9.44285, 0.4039]), "id": 11458214434,
			"lat": 0.4039, "lon": 9.44285,
			"footprint_size": Vector2.ZERO, "footprint": PackedVector2Array()
		})
	if not has_mairie_4e_arrondissement_site:
		entries.append({
			"kind": "admin", "label": "Mairie de Plaine Niger — 4e arrondissement",
			"pos": _geo([9.4593, 0.37406]), "id": 1346923818,
			"lat": 0.37406, "lon": 9.4593,
			"footprint_size": Vector2.ZERO, "footprint": PackedVector2Array()
		})
	# Chambre de Commerce du Gabon — OSM way 456350865, centroïde Mapcarta/OSM.
	# Le repère est placé sur le bâtiment public existant ; aucune géométrie dupliquée.
	if not has_chamber_of_commerce_site:
		entries.append({
			"kind": "admin",
			"label": "Chambre de Commerce du Gabon",
			"pos": _geo([9.44697, 0.38419]),
			"id": 456350865,
			"lat": 0.38419,
			"lon": 9.44697,
			"footprint_size": Vector2.ZERO,
			"footprint": PackedVector2Array()
		})
	# Priorité aux établissements demandés pour stabiliser l'ordre de création.
	# Aucun plafond ne supprime les sites : tous les POI admissibles sont parcourus.
	# À priorité égale, les sites les plus proches du centre jouable passent d'abord.
	entries.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var a_priority := 0 if a.kind in ["school", "university", "hotel", "hospital", "clinic"] else 1
		var b_priority := 0 if b.kind in ["school", "university", "hotel", "hospital", "clinic"] else 1
		if a_priority != b_priority:
			return a_priority < b_priority
		return Vector2(a.pos.x,a.pos.z).distance_squared_to(origin)<Vector2(b.pos.x,b.pos.z).distance_squared_to(origin))
	var seen:={}
	var placed: Array[Dictionary] = []
	# Export des coordonnées OSM réellement retenues pour contrôle SIG.
	var gps_report := FileAccess.open("user://libreville_facilities_gps.csv", FileAccess.WRITE)
	if gps_report:
		gps_report.store_line("type;nom;osm_id;latitude;longitude")
	for e in entries:
		var key:=str(e.id) if e.id!=0 else str(e.kind)+str(e.label)
		if seen.has(key): continue
		var duplicate := false
		for prior in placed:
			if prior.kind == e.kind and Vector2(prior.pos.x,prior.pos.z).distance_to(Vector2(e.pos.x,e.pos.z)) < 18.0:
				duplicate = true
				break
		if duplicate: continue
		seen[key]=true
		_create_one(e.kind,e.label,e.pos,count,e.footprint_size,e.footprint)
		placed.append({"kind":e.kind,"pos":e.pos})
		count+=1
		if e.kind in ["school", "university"]: school_count += 1
		if e.kind == "hotel": hotel_count += 1
		print("SITE OSM | ",e.kind," | ",e.label," | OSM ",e.id," | GPS ",e.lat,", ",e.lon)
		if gps_report:
			var safe_label := str(e.label).replace(";", ",").replace("\n", " ")
			gps_report.store_line("%s;%s;%s;%.7f;%.7f" % [e.kind, safe_label, str(e.id), float(e.lat), float(e.lon)])
	if gps_report:
		gps_report.close()
	print("COORDONNÉES GPS OSM exportées : user://libreville_facilities_gps.csv")
	print("INFRASTRUCTURES LIBREVILLE | ",count," sites dans l'emprise validée | établissements scolaires et universitaires : ",school_count," | hôtels : ",hotel_count)

func _kind(p:Dictionary)->String:
	var a:=str(p.get("amenity","")).to_lower()
	var h:=str(p.get("healthcare","")).to_lower()
	var b:=str(p.get("building","")).to_lower()
	var s:=str(p.get("shop","")).to_lower()
	if a=="hospital" or h=="hospital" or b=="hospital": return "hospital"
	if a == "university" or b == "university": return "university"
	if a in ["school", "kindergarten", "college"] or b in ["school", "college", "kindergarten"]: return "school"
	if str(p.get("tourism", "")).to_lower() in ["hotel", "guest_house", "hostel", "motel"] or b in ["hotel", "guest_house"]: return "hotel"
	if a=="clinic" or h in ["clinic","doctor","health_post"] or b=="clinic": return "clinic"
	if a=="police" or b=="police": return "police"
	if a=="fire_station" or b=="fire_station": return "fire"
	if a=="bus_station" or b=="train_station" or str(p.get("public_transport",""))=="station": return "bus"
	if a=="fuel" or s=="fuel": return "fuel"
	if a=="conference_centre" or b=="conference_centre": return "conference"
	var admin_kind := _administrative_kind(p)
	if admin_kind != "": return admin_kind
	return ""


func _administrative_kind(p: Dictionary) -> String:
	var name := str(p.get("name:fr", "")).strip_edges()
	if name.is_empty():
		name = str(p.get("name", "")).strip_edges()
	name = name.to_lower()
	name = name.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	name = name.replace("ô", "o").replace("ö", "o").replace("à", "a").replace("â", "a")
	name = name.replace("ù", "u").replace("û", "u").replace("ç", "c")
	var office := str(p.get("office", "")).to_lower()
	var amenity := str(p.get("amenity", "")).to_lower()
	var building := str(p.get("building", "")).to_lower()
	var government := str(p.get("government", "")).to_lower()
	if amenity == "townhall" or building == "townhall" or name.contains("mairie") or name.contains("hotel de ville"):
		return "city_hall"
	if name.contains("eaux") and name.contains("foret"):
		return "ministry"
	# Maison Jean Ping et Hôtel des Affaires étrangères : éviter le classement générique office=government.
	if name.contains("maison jean ping") or name.contains("affaires etrangeres") or name.contains("hotel des affaires etrangeres"):
		return "ministry"
	if name.contains("ministere de la justice") or name.contains("ministere de justice"):
		return "court"
	if name.contains("senat") or name.contains("palais omar bongo"):
		return "admin"
	if name.contains("immeuble du 2 decembre") or name.contains("ministere des mines"):
		return "ministry"
	if name.contains("ministere") or name.contains("primature") or government == "ministry":
		return "ministry"
	if name.contains("ambassade") or name.contains("consulat") or office == "diplomatic":
		return "embassy"
	if name.contains("cour constitutionnelle") or name.contains("tribunal") or name.contains("cour supreme"):
		return "court"
	if office in ["government", "administrative"] or building in ["government", "civic", "public"] or amenity == "government" or government in ["administrative", "government", "parliament", "public_service"]:
		return "admin"
	return ""

func _default_name(k:String)->String:
	match k:
		"hospital": return "Hôpital"
		"clinic": return "Centre de santé"
		"police": return "Commissariat"
		"fire": return "Sapeurs-pompiers"
		"bus": return "Gare routière"
		"fuel": return "Station-service"
		"conference": return "Palais des Congrès"
		"school": return "Établissement scolaire"
		"university": return "Université"
		"city_hall": return "Mairie"
		"ministry": return "Ministère"
		"embassy": return "Ambassade"
		"court": return "Justice"
		"hotel": return "Hôtel"
		_: return "Administration"

func _geometry_center(g:Dictionary)->Array:
	var kind := str(g.get("type",""))
	var coords: Variant = g.get("coordinates",[])
	if kind == "Point" and coords is Array:
		return coords
	var selected_ring: Array = []
	var selected_area := 0.0
	if kind == "Polygon" and coords is Array and not coords.is_empty():
		selected_ring = coords[0]
	elif kind == "MultiPolygon" and coords is Array:
		# Retenir la composante extérieure la plus étendue, pas celle qui
		# possède simplement le plus grand nombre de sommets.
		for polygon in coords:
			if not polygon is Array or polygon.is_empty() or not polygon[0] is Array:
				continue
			var candidate: Array = polygon[0]
			var metrics := _ring_centroid(candidate)
			if metrics.size() >= 3 and float(metrics[2]) > selected_area:
				selected_area = float(metrics[2])
				selected_ring = candidate
	if selected_ring.is_empty():
		return []
	var result := _ring_centroid(selected_ring)
	if result.size() < 2:
		# Certains polygones OSM sont dégénérés ou incomplets ; conserver
		# malgré tout un point de placement au lieu de supprimer le site.
		result = _ring_vertex_mean(selected_ring)
	if result.size() < 2:
		return []
	return [result[0], result[1]]

func _ring_vertex_mean(ring: Array) -> Array:
	var lon_sum := 0.0
	var lat_sum := 0.0
	var count_points := 0
	for point in ring:
		if point is Array and point.size() >= 2:
			lon_sum += float(point[0])
			lat_sum += float(point[1])
			count_points += 1
	if count_points == 0:
		return []
	return [lon_sum / count_points, lat_sum / count_points]

func _ring_centroid(ring: Array) -> Array:
	# Centroïde surfacique (formule des lacets) en coordonnées longitude/latitude.
	# L'aire sert aussi à choisir la plus grande composante d'un MultiPolygon.
	if ring.size() < 3:
		return []
	var twice_area := 0.0
	var weighted_lon := 0.0
	var weighted_lat := 0.0
	for i in range(ring.size()):
		var a: Variant = ring[i]
		var b: Variant = ring[(i + 1) % ring.size()]
		if not a is Array or not b is Array or a.size() < 2 or b.size() < 2:
			continue
		var ax := float(a[0])
		var ay := float(a[1])
		var bx := float(b[0])
		var by := float(b[1])
		var cross := ax * by - bx * ay
		twice_area += cross
		weighted_lon += (ax + bx) * cross
		weighted_lat += (ay + by) * cross
	if absf(twice_area) < 0.000000000001:
		return []
	var centroid_lon := weighted_lon / (3.0 * twice_area)
	var centroid_lat := weighted_lat / (3.0 * twice_area)
	return [centroid_lon, centroid_lat, absf(twice_area) * 0.5]

func _geometry_outer_ring(g: Dictionary, center: Vector3) -> PackedVector2Array:
	# Conserve le contour réel du POI OSM surfacique pour matérialiser son emprise.
	var geometry_type := str(g.get("type", ""))
	var coords: Variant = g.get("coordinates", [])
	var ring: Array = []
	if geometry_type == "Polygon" and coords is Array and not coords.is_empty():
		ring = coords[0]
	elif geometry_type == "MultiPolygon" and coords is Array:
		var largest_area := -1.0
		for polygon in coords:
			if not polygon is Array or polygon.is_empty() or not polygon[0] is Array:
				continue
			var candidate: Array = polygon[0]
			var metrics := _ring_centroid(candidate)
			if metrics.size() >= 3 and float(metrics[2]) > largest_area:
				largest_area = float(metrics[2])
				ring = candidate
	var result := PackedVector2Array()
	for point in ring:
		if not point is Array or point.size() < 2:
			continue
		var world_point := _geo([float(point[0]), float(point[1])])
		result.append(Vector2(world_point.x - center.x, world_point.z - center.z))
	if result.size() > 2 and result[0].distance_to(result[result.size() - 1]) < 0.05:
		result.remove_at(result.size() - 1)
	return result

func _geometry_size_m(g: Dictionary) -> Vector2:
	# Dimensions issues de l'emprise OSM des POI surfaciques.
	# Les POI ponctuels conservent les gabarits de leur catégorie.
	var geometry_type := str(g.get("type", ""))
	var coords: Variant = g.get("coordinates", [])
	var ring: Array = []
	if geometry_type == "Polygon" and coords is Array and not coords.is_empty():
		ring = coords[0]
	elif geometry_type == "MultiPolygon" and coords is Array:
		var largest_area := -1.0
		for polygon in coords:
			if not polygon is Array or polygon.is_empty() or not polygon[0] is Array:
				continue
			var candidate: Array = polygon[0]
			var metrics := _ring_centroid(candidate)
			if metrics.size() >= 3 and float(metrics[2]) > largest_area:
				largest_area = float(metrics[2])
				ring = candidate
	if ring.size() < 3:
		return Vector2.ZERO
	var min_lon := INF
	var max_lon := -INF
	var min_lat := INF
	var max_lat := -INF
	for point in ring:
		if not point is Array or point.size() < 2:
			continue
		var lon := float(point[0])
		var lat := float(point[1])
		min_lon = minf(min_lon, lon)
		max_lon = maxf(max_lon, lon)
		min_lat = minf(min_lat, lat)
		max_lat = maxf(max_lat, lat)
	if min_lon == INF or min_lat == INF:
		return Vector2.ZERO
	var width_m := (max_lon - min_lon) * 111320.0 * cos(deg_to_rad(CENTER_LAT))
	var depth_m := (max_lat - min_lat) * 111320.0
	return Vector2(width_m, depth_m)

func _geo(c:Array)->Vector3:
	var x:=(float(c[0])-CENTER_LON)*111320.0*cos(deg_to_rad(CENTER_LAT))
	var z:=-(float(c[1])-CENTER_LAT)*111320.0
	var y:=float(map.call("terrain_height_at_world",x,z)) if map.has_method("terrain_height_at_world") else 0.0
	return Vector3(x,y,z)

func _create_one(k:String,label:String,p:Vector3,index:int,footprint_size:Vector2 = Vector2.ZERO,footprint:PackedVector2Array = PackedVector2Array())->void:
	# Les bâtiments physiques sont reconstruits une seule fois par WorldMap depuis
	# buildings.geojson. Ce générateur ajoute uniquement un repère de POI nommé :
	# aucune boîte générique ne vient doubler ou déformer l'empreinte OSM.
	var root := Node3D.new()
	root.name = "Infrastructure_POI_%s_%03d" % [k, index]
	root.position = p
	add_child(root)
	var marker_text := "ÉTABLISSEMENT"
	var marker_material: Material = blue
	match k:
		"school":
			marker_text = "ÉCOLE"
			marker_material = school_accent
		"university":
			marker_text = "UNIVERSITÉ"
			marker_material = school_accent
		"hotel":
			marker_text = "HÔTEL"
			marker_material = hotel_accent
		"hospital":
			marker_text = "HÔPITAL"
			marker_material = red
		"clinic":
			marker_text = "SANTÉ"
			marker_material = red
		"police":
			marker_text = "POLICE"
		"fire":
			marker_text = "SECOURS"
			marker_material = red
		"bus":
			marker_text = "TRANSPORT"
		"fuel":
			marker_text = "CARBURANT"
		"conference":
			marker_text = "CONGRÈS"
		"admin":
			marker_text = "ADMINISTRATION"
			if label.to_lower().contains("mairie de plaine niger") or label.to_lower().contains("mairie du 4e arrondissement") or label.to_lower().contains("mairie du 4eme arrondissement"):
				marker_text = "MAIRIE 4E"
				marker_material = school_accent
			if label.to_lower().contains("mairie du 2e arrondissement") or label.to_lower().contains("mairie du 2eme arrondissement"):
				marker_text = "MAIRIE 2E"
				marker_material = school_accent
			if label.to_lower().contains("mairie de nombakele") or label.to_lower().contains("3e arrondissement"):
				marker_text = "MAIRIE 3E"
				marker_material = school_accent
			if label.to_lower().contains("mairie de nzeng-ayong") or label.to_lower().contains("mairie de nzeng ayong"):
				marker_text = "MAIRIE NZENG-AYONG"
				marker_material = school_accent
			if label.to_lower().contains("mairie des hauts de guegue") or label.to_lower().contains("mairie hauts de guegue"):
				marker_text = "MAIRIE GUÉ-GUÉ"
				marker_material = school_accent
			if label.to_lower().contains("documentation et de l immigration") or label.to_lower().contains("dgdi"):
				marker_text = "DGDI"
				marker_material = school_accent
			if label.to_lower().contains("centre technique de l habitat"):
				marker_text = "HABITAT"
				marker_material = school_accent
			if label.to_lower().contains("egabon"):
				marker_text = "eGABON"
				marker_material = school_accent
			if label.to_lower().contains("seeg") or label.to_lower().contains("energie et d eau du gabon") or label.to_lower().contains("énergie et d’eau du gabon"):
				marker_text = "SEEG"
				marker_material = school_accent
			if label.to_lower().contains("cppf") or label.to_lower().contains("caisse des pensions"):
				marker_text = "CPPF"
				marker_material = school_accent
			if label.to_lower().contains("cntippee") or label.to_lower().contains("travaux d’intérêt public") or label.to_lower().contains("travaux d interet public"):
				marker_text = "CNTIPPEE"
				marker_material = school_accent
			if label.to_lower().contains("chambre de commerce"):
				marker_text = "CHAMBRE DE COMMERCE"
				marker_material = school_accent
			if label.to_lower().contains("comptabilite publique") or label.to_lower().contains("comptabilité publique") or label.to_lower().contains("dgcpt"):
				marker_text = "TRÉSOR PUBLIC"
				marker_material = school_accent
			if label.to_lower().contains("aninf") or label.to_lower().contains("infrastructures numeriques") or label.to_lower().contains("infrastructures numériques"):
				marker_text = "ANINF"
				marker_material = school_accent
			if label.to_lower().contains("agasa") or label.to_lower().contains("securite alimentaire") or label.to_lower().contains("sécurité alimentaire"):
				marker_text = "AGASA"
				marker_material = school_accent
			if label.to_lower().contains("institut national de cartographie"):
				marker_text = "CARTOGRAPHIE"
				marker_material = school_accent
			if label.to_lower().contains("communication"):
				marker_text = "COMMUNICATION"
				marker_material = school_accent
			if label.to_lower().contains("senat") or label.to_lower().contains("omar bongo"):
				marker_text = "SÉNAT"
				marker_material = school_accent
			if label.to_lower().contains("cima") or label.to_lower().contains("marches d’assurances") or label.to_lower().contains("marchés d’assurances"):
				marker_text = "CIMA"
				marker_material = school_accent
			if label.to_lower().contains("palais presidentiel") or label.to_lower().contains("palais du bord de mer"):
				marker_text = "PRÉSIDENCE"
				marker_material = school_accent
			if label.to_lower().contains("ceeac"):
				marker_text = "CEEAC"
				marker_material = school_accent
			if label.to_lower().contains("anuttc") or label.to_lower().contains("urbanisme"):
				marker_text = "ANUTTC"
				marker_material = school_accent
			if label.to_lower().contains("brac-oif") or label.to_lower().contains("bureau regional de l oif"):
				marker_text = "OIF AFRIQUE CENTRALE"
				marker_material = school_accent
			if label.to_lower().contains("travaux topographiques") or label.to_lower().contains("dgttc"):
				marker_text = "CADASTRE & TOPOGRAPHIE"
				marker_material = school_accent
			if label.to_lower().contains("etudes et laboratoires") or label.to_lower().contains("dgel"):
				marker_text = "ÉTUDES & LABORATOIRES"
				marker_material = school_accent
			if label.to_lower().contains("conseil national de la democratie") or label.to_lower().contains("cnd"):
				marker_text = "DÉMOCRATIE"
				marker_material = school_accent
			if label.to_lower().contains("palais leon mba") or label.to_lower().contains("assemblee nationale"):
				marker_text = "ASSEMBLÉE NATIONALE"
				marker_material = school_accent
			if label.to_lower().contains("direction generale des douanes") or label.to_lower().contains("droits indirects"):
				marker_text = "DOUANES"
				marker_material = school_accent
			if label.to_lower().contains("conseil national de l eau") or label.to_lower().contains("cnee"):
				marker_text = "EAU & ÉLECTRICITÉ"
				marker_material = school_accent
		"city_hall":
			marker_text = "MAIRIE"
		"ministry":
			marker_text = "MINISTÈRE"
			if label.to_lower().contains("education") or label.to_lower().contains("éducation"):
				marker_text = "ÉDUCATION"
				marker_material = school_accent
			if label.to_lower().contains("interieur") or label.to_lower().contains("intérieur"):
				marker_text = "INTÉRIEUR"
				marker_material = school_accent
			if label.to_lower().contains("2 decembre") or label.to_lower().contains("mines"):
				marker_text = "MINES"
				marker_material = school_accent
			if label.to_lower().contains("sante") or label.to_lower().contains("santé"):
				marker_text = "SANTÉ"
				marker_material = red
			if label.to_lower().contains("affaires etrangeres") or label.to_lower().contains("jean ping"):
				marker_text = "DIPLOMATIE"
				marker_material = school_accent
			if label.to_lower().contains("fonction publique"):
				marker_text = "FONCTION PUBLIQUE"
				marker_material = school_accent
			if label.to_lower().contains("eaux") and label.to_lower().contains("foret"):
				marker_text = "EAUX & FORÊTS"
				marker_material = school_accent
			if label.to_lower().contains("travail"):
				marker_text = "TRAVAIL"
				marker_material = school_accent
			if label.to_lower().contains("planification"):
				marker_text = "PLANIFICATION"
				marker_material = school_accent
		"embassy":
			marker_text = "AMBASSADE"
		"court":
			marker_text = "JUSTICE"
			if label.to_lower().contains("cour constitutionnelle"):
				marker_text = "COUR CONSTITUTIONNELLE"
				marker_material = school_accent
	_sign(root, marker_text, Vector3(0, 2.2, 0), marker_material)
	_name(root, label, Vector3(0, 3.35, 0))

func _add_entry_canopy(root: Node3D, kind: String, w: float, d: float) -> void:
	# Auvents et poteaux d'entrée adaptés aux pluies tropicales.
	var canopy_width := minf(w * 0.42, 13.0)
	var canopy_depth := 3.2 if kind in ["hospital", "clinic"] else 2.5
	var canopy_y := 3.2 if kind in ["hospital", "clinic"] else 2.8
	_box(root, Vector3(0, canopy_y, d / 2.0 + canopy_depth * 0.42), Vector3(canopy_width, 0.22, canopy_depth), roof)
	for x in [-canopy_width * 0.43, canopy_width * 0.43]:
		_box(root, Vector3(x, canopy_y / 2.0, d / 2.0 + canopy_depth * 0.42), Vector3(0.22, canopy_y, 0.22), structural_concrete)
	if kind in ["school", "university", "admin"]:
		_box(root, Vector3(0, 0.16, d / 2.0 + 5.8), Vector3(w * 0.48, 0.18, 5.2), concrete)

func _add_school_campus(root: Node3D, w: float, d: float, h: float, index: int) -> void:
	# Petit campus en plusieurs volumes : bloc pédagogique, aile secondaire et cour.
	var wing_width := w * 0.30
	var wing_depth := d * 0.72
	var wing_x := -w * 0.34 if index % 2 == 0 else w * 0.34
	_box(root, Vector3(wing_x, h * 0.39, -d * 0.10), Vector3(wing_width, h * 0.78, wing_depth), white)
	_box(root, Vector3(wing_x, h * 0.80, -d * 0.10), Vector3(wing_width + 0.5, 0.22, wing_depth + 0.5), roof)
	for floor_y in [2.0, 5.0]:
		if floor_y < h:
			for col in range(3):
				_box(root, Vector3(wing_x - wing_width * 0.30 + col * wing_width * 0.30, floor_y, d * 0.27), Vector3(1.7, 1.1, 0.08), glass)
	# Préau couvert dans la cour, élément courant des établissements tropicaux.
	_box(root, Vector3(w * 0.12, 2.8, -d * 0.30), Vector3(w * 0.34, 0.18, d * 0.24), roof)
	for x in [w * -0.03, w * 0.27]:
		_box(root, Vector3(x, 1.4, -d * 0.30), Vector3(0.18, 2.8, 0.18), steel)

func _add_university_campus(root: Node3D, w: float, d: float, h: float, index: int) -> void:
	# Ensemble universitaire : deux ailes basses encadrant une cour centrale.
	for side in [-1.0, 1.0]:
		var wing_x := side * w * 0.34
		_box(root, Vector3(wing_x, h * 0.30, -d * 0.20), Vector3(w * 0.24, h * 0.60, d * 0.70), white)
		_box(root, Vector3(wing_x, h * 0.61, -d * 0.20), Vector3(w * 0.25, 0.24, d * 0.72), roof)
		for floor in range(2):
			for col in range(3):
				_box(root, Vector3(wing_x - w * 0.075 + col * w * 0.075, 2.0 + floor * 3.1, d * 0.16), Vector3(2.0, 1.35, 0.08), glass)
	_box(root, Vector3(0, 0.16, d * 0.10), Vector3(w * 0.32, 0.18, d * 0.44), concrete)
	_box(root, Vector3(0, 2.3, d * 0.10), Vector3(w * 0.30, 0.18, d * 0.42), roof)
	for x in [-w * 0.14, w * 0.14]:
		_box(root, Vector3(x, 1.2, d * 0.10), Vector3(0.22, 2.4, 0.22), structural_concrete)

func _add_hospital_wings(root: Node3D, w: float, d: float, h: float) -> void:
	# Bloc de consultations et aile de soins ; volumes différenciés mais non cadastraux.
	_box(root, Vector3(-w * 0.31, h * 0.25, -d * 0.10), Vector3(w * 0.28, h * 0.50, d * 0.72), white)
	_box(root, Vector3(-w * 0.31, h * 0.51, -d * 0.10), Vector3(w * 0.29, 0.24, d * 0.74), roof)
	_box(root, Vector3(w * 0.28, h * 0.20, -d * 0.12), Vector3(w * 0.30, h * 0.40, d * 0.68), white)
	_box(root, Vector3(w * 0.28, h * 0.41, -d * 0.12), Vector3(w * 0.31, 0.24, d * 0.70), roof)
	# Marquage et accès dégagé pour les ambulances.
	_box(root, Vector3(0, 0.08, d / 2.0 + 7.0), Vector3(w * 0.70, 0.12, 10.0), asphalt)

func _add_hotel_balconies(root: Node3D, w: float, d: float, h: float, index: int) -> void:
	# Balcons filants et garde-corps métalliques, avec alternance déterministe.
	var floors := maxi(2, int(ceil(h / 3.2)))
	for floor in range(1, floors):
		var y := minf(1.8 + floor * 3.0, h - 0.4)
		for col in range(4):
			var x := -w * 0.34 + col * w * 0.22
			if (col + floor + index) % 2 == 0:
				_box(root, Vector3(x, y - 0.82, d / 2.0 + 0.85), Vector3(w * 0.16, 0.12, 1.4), concrete)
				_box(root, Vector3(x, y - 0.30, d / 2.0 + 1.48), Vector3(w * 0.16, 0.08, 0.08), steel)
				for post in range(4):
					_box(root, Vector3(x - w * 0.08 + post * w * 0.053, y - 0.56, d / 2.0 + 1.48), Vector3(0.045, 0.48, 0.045), steel)

func _add_clinic_verandah(root: Node3D, w: float, d: float) -> void:
	# Galerie ombragée et rampe d'accès pour les structures de santé de proximité.
	_box(root, Vector3(0, 2.9, d / 2.0 + 1.8), Vector3(w * 0.88, 0.18, 3.6), roof)
	for x in [-w * 0.38, -w * 0.13, w * 0.13, w * 0.38]:
		_box(root, Vector3(x, 1.45, d / 2.0 + 2.7), Vector3(0.16, 2.9, 0.16), structural_concrete)
	_box(root, Vector3(0, 0.10, d / 2.0 + 5.0), Vector3(5.0, 0.20, 6.0), concrete)

func _add_osm_footprint(root: Node3D, polygon: PackedVector2Array) -> void:
	# Surface triangulée à partir du contour OSM original (sans inventer de parcelle).
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var point := polygon[index]
		surface.add_vertex(Vector3(point.x, 0.075, point.y))
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = "OSM_Footprint"
	instance.mesh = mesh
	instance.material_override = concrete
	root.add_child(instance)

func _add_facade_construction_details(root: Node3D, w: float, d: float, h: float) -> void:
	# Détails architecturaux génériques : soubassement béton, bandeaux de dalle
	# et encadrements. Ils enrichissent les volumes OSM sans prétendre reproduire
	# une façade réelle non documentée.
	_box(root, Vector3(0, 0.52, d / 2.0 + 0.07), Vector3(w + 0.12, 0.24, 0.16), weathered_concrete)
	_box(root, Vector3(0, 0.52, -d / 2.0 - 0.07), Vector3(w + 0.12, 0.24, 0.16), weathered_concrete)
	_box(root, Vector3(-w / 2.0 - 0.07, 0.52, 0), Vector3(0.16, 0.24, d + 0.12), weathered_concrete)
	_box(root, Vector3(w / 2.0 + 0.07, 0.52, 0), Vector3(0.16, 0.24, d + 0.12), weathered_concrete)
	var floors := maxi(1, int(ceil(h / 3.2)))
	for floor in range(1, floors):
		var y := minf(0.24 + floor * 3.2, h - 0.35)
		_box(root, Vector3(0, y, d / 2.0 + 0.10), Vector3(w + 0.35, 0.14, 0.22), structural_concrete)
		_box(root, Vector3(0, y, -d / 2.0 - 0.10), Vector3(w + 0.35, 0.14, 0.22), structural_concrete)
		_box(root, Vector3(-w / 2.0 - 0.10, y, 0), Vector3(0.22, 0.14, d + 0.35), structural_concrete)
		_box(root, Vector3(w / 2.0 + 0.10, y, 0), Vector3(0.22, 0.14, d + 0.35), structural_concrete)

func _windows(root:Node3D,w:float,d:float,h:float)->void:
	var floors:=maxi(1, int(ceil(h / 3.2)))
	for floor in range(floors):
		var y:=1.7+floor*3.0
		for col in range(5):
			var x:=-w*0.36+col*w*0.18
			_box(root,Vector3(x,y,d/2+0.05),Vector3(2.2,1.35,0.08),glass)
			_box(root,Vector3(x,y,-d/2-0.05),Vector3(2.2,1.35,0.08),glass)
		# Les façades latérales reçoivent aussi des ouvertures : le bâtiment
		# reste cohérent lorsqu'on le contourne, pas seulement depuis la rue.
		for side_col in range(3):
			var side_z := -d * 0.30 + side_col * d * 0.30
			_box(root,Vector3(w/2+0.05,y,side_z),Vector3(0.08,1.35,2.0),glass)
			_box(root,Vector3(-w/2-0.05,y,side_z),Vector3(0.08,1.35,2.0),glass)
		# Appuis et linteaux continus : détail sobre qui donne une vraie lecture
		# de façade sans multiplier les objets 3D autour de chaque fenêtre.
		var band_width := w * 0.84
		for facade_z in [d / 2.0 + 0.10, -d / 2.0 - 0.10]:
			_box(root, Vector3(0, y - 0.76, facade_z), Vector3(band_width, 0.12, 0.20), weathered_concrete)
			_box(root, Vector3(0, y + 0.76, facade_z), Vector3(band_width, 0.10, 0.18), structural_concrete)
		for facade_x in [w / 2.0 + 0.10, -w / 2.0 - 0.10]:
			_box(root, Vector3(facade_x, y - 0.76, 0), Vector3(0.20, 0.12, d * 0.72), weathered_concrete)
			_box(root, Vector3(facade_x, y + 0.76, 0), Vector3(0.18, 0.10, d * 0.72), structural_concrete)

func _add_rainwater_details(root: Node3D, w: float, d: float, h: float) -> void:
	# Évacuation pluviale discrète, pertinente pour le climat tropical humide.
	# Les descentes restent en retrait des angles pour éviter les arêtes visuelles.
	var gutter_y := h + 0.34
	_box(root, Vector3(0, gutter_y, d / 2.0 + 0.48), Vector3(w + 0.35, 0.12, 0.16), steel)
	_box(root, Vector3(0, gutter_y, -d / 2.0 - 0.48), Vector3(w + 0.35, 0.12, 0.16), steel)
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			var pipe_x := side * (w / 2.0 - 0.28)
			var pipe_z := front * (d / 2.0 + 0.49)
			_box(root, Vector3(pipe_x, h / 2.0, pipe_z), Vector3(0.10, h, 0.10), steel)

func _sign(root:Node3D,t:String,p:Vector3,m:Material)->void:
	_box(root,p,Vector3(maxf(5,float(t.length())*0.42),1.15,0.22),m)
	var l:=Label3D.new()
	l.text=t; l.font_size=44; l.pixel_size=0.012; l.position=p+Vector3(0,-0.04,0.14)
	l.modulate=Color.WHITE; l.outline_size=7
	root.add_child(l)

func _name(root:Node3D,t:String,p:Vector3)->void:
	var l:=Label3D.new()
	l.text=t; l.font_size=34; l.pixel_size=0.01; l.position=p
	l.modulate=Color(1,0.96,0.82); l.outline_size=7
	l.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(l)

func _box(root:Node3D,p:Vector3,s:Vector3,m:Material)->void:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new(); mesh.size=s
	node.mesh=mesh; node.material_override=m; node.position=p
	root.add_child(node)
