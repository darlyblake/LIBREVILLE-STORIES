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
			if label.to_lower().contains("communication"):
				marker_text = "COMMUNICATION"
				marker_material = school_accent
			if label.to_lower().contains("senat") or label.to_lower().contains("omar bongo"):
				marker_text = "SÉNAT"
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
		"embassy":
			marker_text = "AMBASSADE"
		"court":
			marker_text = "JUSTICE"
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
