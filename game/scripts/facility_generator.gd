extends Node3D
## Reconstructions 3D de services publics à partir des POI OSM de Libreville.
const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const DATA_PATH := "res://data/osm/extended/pois.geojson"
const MAP_SOUTH := 0.355
const MAP_WEST := 9.400
const MAP_NORTH := 0.445
const MAP_EAST := 9.495
const MAX_FACILITIES := 100
const MAX_SCHOOLS := 8
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
		var kind := _kind(p)
		if kind=="": continue
		var pos := _geo(c)
		var label := str(p.get("name:fr",""))
		if label.is_empty(): label=str(p.get("name",""))
		if label.is_empty(): label=_default_name(kind)
		var osm_id := int(p.get("osm_id",0))
		if osm_id == 0: osm_id=int(str(p.get("@id","0")).replace("way/","").replace("node/","").replace("relation/",""))
		entries.append({"kind":kind,"label":label,"pos":pos,"id":osm_id,"lat":latitude,"lon":longitude})
	# Priorité aux établissements demandés : les écoles et hôtels sont placés
	# avant les autres équipements pour ne pas être éliminés par le plafond.
	# À priorité égale, les sites les plus proches du centre jouable passent d'abord.
	entries.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var a_priority := 0 if a.kind in ["school", "university", "hotel", "hospital", "clinic"] else 1
		var b_priority := 0 if b.kind in ["school", "university", "hotel", "hospital", "clinic"] else 1
		if a_priority != b_priority:
			return a_priority < b_priority
		return Vector2(a.pos.x,a.pos.z).distance_squared_to(origin)<Vector2(b.pos.x,b.pos.z).distance_squared_to(origin))
	var seen:={}
	var placed: Array[Dictionary] = []
	var selected_school_count := 0
	for e in entries:
		if count>=MAX_FACILITIES: break
		if e.kind == "school" and selected_school_count >= MAX_SCHOOLS:
			continue
		var key:=str(e.id) if e.id!=0 else str(e.kind)+str(e.label)
		if seen.has(key): continue
		var duplicate := false
		for prior in placed:
			if prior.kind == e.kind and Vector2(prior.pos.x,prior.pos.z).distance_to(Vector2(e.pos.x,e.pos.z)) < 18.0:
				duplicate = true
				break
		if duplicate: continue
		seen[key]=true
		_create_one(e.kind,e.label,e.pos,count)
		placed.append({"kind":e.kind,"pos":e.pos})
		count+=1
		if e.kind == "school":
			school_count += 1
			selected_school_count += 1
		if e.kind == "hotel": hotel_count += 1
		print("SITE OSM | ",e.kind," | ",e.label," | OSM ",e.id," | GPS ",e.lat,", ",e.lon)
	print("INFRASTRUCTURES LIBREVILLE | ",count," sites dans l'emprise validée | écoles : ",school_count," (max. ",MAX_SCHOOLS,") | hôtels : ",hotel_count)

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
	if a=="townhall" or b in ["government","civic","public"] or str(p.get("office","")) in ["government","administrative"]: return "admin"
	return ""

func _default_name(k:String)->String:
	match k:
		"hospital": return "Hôpital"
		"clinic": return "Centre de santé"
		"police": return "Commissariat"
		"fire": return "Sapeurs-pompiers"
		"bus": return "Gare routière"
		"fuel": return "Station-service"
		"school": return "Établissement scolaire"
		"university": return "Université"
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

func _geo(c:Array)->Vector3:
	var x:=(float(c[0])-CENTER_LON)*111320.0*cos(deg_to_rad(CENTER_LAT))
	var z:=-(float(c[1])-CENTER_LAT)*111320.0
	var y:=float(map.call("terrain_height_at_world",x,z)) if map.has_method("terrain_height_at_world") else 0.0
	return Vector3(x,y,z)

func _create_one(k:String,label:String,p:Vector3,index:int)->void:
	var root:=Node3D.new()
	root.name="Infrastructure_%s_%03d"%[k,index]
	root.position=p
	add_child(root)
	var w:=20.0
	var d:=15.0
	var h:=6.5
	var wall:=structural_concrete
	match k:
		"hospital": w=34; d=25; h=13; wall=white
		"clinic": w=17; d=13; h=6; wall=white
		"police": w=19; d=15; h=6.5; wall=blue
		"fire": w=25; d=19; h=8; wall=red
		"bus": w=36; d=25; h=5
		"fuel": w=28; d=24; h=5.5; wall=white
		"admin": w=24; d=18; h=10; wall=white
		"school": w=38; d=28; h=9; wall=white
		"hotel": w=30; d=22; h=16; wall=white
	var lower_label := label.to_lower()
	# Silhouettes renforcées pour les grands sites identifiés dans les données OSM.
	# Les dimensions sont des proportions de gameplay, pas des mesures cadastrales.
	if k == "hospital":
		if "chul" in lower_label or "universitaire" in lower_label:
			w=54; d=38; h=18
		elif "akanda" in lower_label or "hiaobo" in lower_label:
			w=43; d=32; h=15
	if k == "bus" and ("pk8" in lower_label or "pk 8" in lower_label):
		w=46; d=32
	_box(root,Vector3(0,0.1,0),Vector3(w+6,0.2,d+6),asphalt)
	_box(root,Vector3(0,h/2,0),Vector3(w,h,d),wall)
	_box(root,Vector3(0,h+0.18,0),Vector3(w+0.8,0.36,d+0.8),roof)
	_windows(root,w,d,h)
	_add_facade_construction_details(root,w,d,h)
	_add_rainwater_details(root,w,d,h)
	match k:
		"school":
			_sign(root, "ÉCOLE", Vector3(0, h + 1.0, d / 2 + 0.3), school_accent)
			_box(root, Vector3(0, 0.35, d / 2 + 4.0), Vector3(w * 0.62, 0.35, 6.5), school_accent)
			_box(root, Vector3(0, 1.15, d / 2 + 7.2), Vector3(4.0, 2.3, 0.25), blue)
			_box(root, Vector3(-w * 0.36, 0.08, -d / 2 - 4.5), Vector3(5.0, 0.16, 7.0), asphalt)
			for i in range(4):
				_box(root, Vector3(-w * 0.36 + i * 3.2, 1.2, d / 2 + 7.0), Vector3(0.12, 2.4, 0.12), school_accent)
		"hotel":
			_sign(root, "HÔTEL", Vector3(0, h + 1.0, d / 2 + 0.3), hotel_accent)
			_box(root, Vector3(0, h + 0.42, 0), Vector3(w + 2.0, 0.42, d + 2.0), hotel_accent)
			_box(root, Vector3(0, 1.25, d / 2 + 2.1), Vector3(5.0, 2.5, 0.18), glass)
			_box(root, Vector3(0, 0.18, d / 2 + 4.0), Vector3(w * 0.72, 0.18, 6.0), concrete)
			for x in [-w * 0.32, w * 0.32]:
				_box(root, Vector3(x, 2.1, d / 2 + 3.2), Vector3(0.35, 4.2, 0.35), hotel_accent)
		"hospital","clinic":
			_sign(root,"✚",Vector3(-w/2+2,h+1.4,0),red)
			_sign(root,"URGENCES",Vector3(0,2.4,d/2+0.4),blue)
			_box(root,Vector3(0,2.1,d/2+2.2),Vector3(10,0.35,4),blue)
			_box(root,Vector3(0,1.25,d/2+0.09),Vector3(3.2,2.5,0.12),glass)
			_box(root,Vector3(0,0.25,d/2+3.8),Vector3(7,0.5,5.5),concrete)
			if k=="hospital":
				_box(root,Vector3(w*0.28,h+2.4,-d*0.12),Vector3(maxf(12.0,w*0.34),4.8,d*0.7),white)
				_box(root,Vector3(w*0.28,h+4.9,-d*0.12),Vector3(maxf(12.0,w*0.35),0.25,d*0.72),roof)
				_box(root,Vector3(-w*0.20,2.9,d/2+3.0),Vector3(15,0.32,5.5),blue)
				if "chul" in lower_label:
					_sign(root,"CHUL",Vector3(0,h+2.0,d/2+0.4),blue)
				elif "akanda" in lower_label:
					_sign(root,"CHU AKANDA",Vector3(0,h+2.0,d/2+0.4),blue)
		"police":
			_sign(root,"POLICE",Vector3(0,h+1,d/2+0.3),blue)
			_box(root,Vector3(-w/2-1.8,1.5,d*0.25),Vector3(3,3,3),white)
		"fire":
			_sign(root,"SAPEURS-POMPIERS",Vector3(0,h+1,d/2+0.3),red)
			for i in range(2):
				var bay_x := -6.0 + i * 12.0
				_box(root,Vector3(bay_x,2,d/2+0.16),Vector3(8,4,0.2),asphalt)
				# Rideau métallique réaliste : tôle photographique PBR, encadrement peint.
				_box(root,Vector3(bay_x,2,d/2+0.29),Vector3(7.45,3.65,0.12),steel)
				for slat in range(9):
					_box(root,Vector3(bay_x,0.35+slat*0.41,d/2+0.37),Vector3(7.35,0.045,0.035),concrete)
				_box(root,Vector3(-10+i*12,2,d/2+0.3),Vector3(0.35,4.3,0.45),red)
				_box(root,Vector3(-2+i*12,2,d/2+0.3),Vector3(0.35,4.3,0.45),red)
				_box(root,Vector3(bay_x,4.15,d/2+0.3),Vector3(8.3,0.35,0.45),red)
		"bus":
			_sign(root,"GARE ROUTIÈRE",Vector3(0,h+1,d/2+0.3),blue)
			_box(root,Vector3(0,4.3,0),Vector3(w+9,0.35,d+9),roof)
			for x in [-w*0.42,w*0.42]:
				for z in [-d*0.38,d*0.38]:
					_box(root,Vector3(x,2.15,z),Vector3(0.65,4.3,0.65),blue)
			for i in range(4):
				_box(root,Vector3(-12+i*8,0.08,d/2+6),Vector3(6,0.12,9),white)
		"fuel":
			_sign(root,"STATION-SERVICE",Vector3(0,h+1,d/2+0.3),red)
			_box(root,Vector3(0,5,-1),Vector3(w+8,0.35,13),roof)
			for x in [-w*0.42,w*0.42]:
				for z in [-5.5,3.5]:
					_box(root,Vector3(x,2.5,z),Vector3(0.55,5,0.55),red)
			for i in range(3):
				var x:=-8.0+i*8.0
				_box(root,Vector3(x,1.25,0),Vector3(1.2,2.5,0.9),red)
				_box(root,Vector3(x,2.35,0.5),Vector3(0.75,0.45,0.08),white)
		"admin":
			_sign(root,"ADMINISTRATION",Vector3(0,h+1,d/2+0.3),blue)
	_name(root,label,Vector3(0,h+2,-d/2-1))

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
