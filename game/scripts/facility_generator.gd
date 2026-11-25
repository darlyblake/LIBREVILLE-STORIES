extends Node3D
## Reconstructions 3D de services publics à partir des POI OSM de Libreville.
const CENTER_LAT := 0.400
const CENTER_LON := 9.4475
const DATA_PATH := "res://data/osm/extended/pois.geojson"
const RADIUS := 2600.0
const MAX_FACILITIES := 60
var map: Node
var concrete: StandardMaterial3D
var white: StandardMaterial3D
var blue: StandardMaterial3D
var red: StandardMaterial3D
var roof: StandardMaterial3D
var glass: StandardMaterial3D
var asphalt: StandardMaterial3D
var count := 0

func _ready() -> void:
	map = get_parent().get_node_or_null("WorldMap")
	if map == null: return
	_make_materials()
	for i in range(600):
		if bool(map.get("_dem_loaded")):
			break
		await get_tree().process_frame
	_build_facilities()

func _make_materials() -> void:
	concrete = _mat(Color(0.72,0.71,0.66), _texture(false))
	white = _mat(Color(0.92,0.91,0.84), _texture(false))
	blue = _mat(Color(0.12,0.30,0.52), _texture(false))
	red = _mat(Color(0.72,0.10,0.09), _texture(false))
	roof = _mat(Color(0.65,0.68,0.67), _texture(true))
	asphalt = _mat(Color(0.24,0.25,0.24), _texture(false))
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
		var p: Dictionary=item.get("properties",{})
		var kind := _kind(p)
		if kind=="": continue
		var pos := _geo(c)
		if Vector2(pos.x,pos.z).distance_to(origin)>RADIUS: continue
		var label := str(p.get("name:fr",""))
		if label.is_empty(): label=str(p.get("name",""))
		if label.is_empty(): label=_default_name(kind)
		var osm_id := int(p.get("osm_id",0))
		if osm_id == 0: osm_id=int(str(p.get("@id","0")).replace("way/","").replace("node/","").replace("relation/",""))
		entries.append({"kind":kind,"label":label,"pos":pos,"id":osm_id})
	entries.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		return Vector2(a.pos.x,a.pos.z).distance_squared_to(origin)<Vector2(b.pos.x,b.pos.z).distance_squared_to(origin))
	var seen:={}
	var placed: Array[Dictionary] = []
	for e in entries:
		if count>=MAX_FACILITIES: break
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
	print("INFRASTRUCTURES LIBREVILLE | ",count," sites spécialisés")

func _kind(p:Dictionary)->String:
	var a:=str(p.get("amenity","")).to_lower()
	var h:=str(p.get("healthcare","")).to_lower()
	var b:=str(p.get("building","")).to_lower()
	var s:=str(p.get("shop","")).to_lower()
	if a=="hospital" or h=="hospital" or b=="hospital": return "hospital"
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
		_: return "Administration"

func _geometry_center(g:Dictionary)->Array:
	var kind := str(g.get("type",""))
	var coords: Variant = g.get("coordinates",[])
	if kind == "Point" and coords is Array:
		return coords
	var ring: Array = []
	if kind == "Polygon" and coords is Array and not coords.is_empty():
		ring = coords[0]
	elif kind == "MultiPolygon" and coords is Array and not coords.is_empty():
		var largest: Array = []
		for polygon in coords:
			if polygon is Array and not polygon.is_empty() and polygon[0] is Array and polygon[0].size()>largest.size():
				largest = polygon[0]
		ring = largest
	if ring.is_empty(): return []
	var lon := 0.0
	var lat := 0.0
	var n := 0
	for point in ring:
		if point is Array and point.size()>=2:
			lon += float(point[0]); lat += float(point[1]); n += 1
	if n == 0: return []
	return [lon/n,lat/n]

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
	var wall:=concrete
	match k:
		"hospital": w=34; d=25; h=13; wall=white
		"clinic": w=17; d=13; h=6; wall=white
		"police": w=19; d=15; h=6.5; wall=blue
		"fire": w=25; d=19; h=8; wall=red
		"bus": w=36; d=25; h=5
		"fuel": w=28; d=24; h=5.5; wall=white
		"admin": w=24; d=18; h=10; wall=white
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
	match k:
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
				_box(root,Vector3(-6+i*12,2,d/2+0.16),Vector3(8,4,0.2),asphalt)
				_box(root,Vector3(-10+i*12,2,d/2+0.3),Vector3(0.35,4.3,0.45),red)
				_box(root,Vector3(-2+i*12,2,d/2+0.3),Vector3(0.35,4.3,0.45),red)
				_box(root,Vector3(-6+i*12,4.15,d/2+0.3),Vector3(8.3,0.35,0.45),red)
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

func _windows(root:Node3D,w:float,d:float,h:float)->void:
	var floors:=maxi(1, int(ceil(h / 3.2)))
	for floor in range(floors):
		var y:=1.7+floor*3.0
		for col in range(5):
			var x:=-w*0.36+col*w*0.18
			_box(root,Vector3(x,y,d/2+0.05),Vector3(2.2,1.35,0.08),glass)
			_box(root,Vector3(x,y,-d/2-0.05),Vector3(2.2,1.35,0.08),glass)

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
