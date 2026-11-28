class_name WorldMapGeometryUtils
extends RefCounted
## Outils géométriques 2D sans dépendance à la scène ou aux données du monde.

static func point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# Conserver la convention actuelle : les anneaux GeoJSON sont fermés.
	if polygon.size() < 4:
		return false
	var inside := false
	var previous := polygon.size() - 1
	for current in range(polygon.size()):
		var a := polygon[current]
		var b := polygon[previous]
		if (a.y > point.y) != (b.y > point.y):
			var crossing_x := (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
			if point.x < crossing_x:
				inside = not inside
		previous = current
	return inside


static func polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var twice_area := 0.0
	var centroid_x := 0.0
	var centroid_y := 0.0
	for index in range(polygon.size() - 1):
		var a := polygon[index]
		var b := polygon[index + 1]
		var cross := a.x * b.y - b.x * a.y
		twice_area += cross
		centroid_x += (a.x + b.x) * cross
		centroid_y += (a.y + b.y) * cross
	if absf(twice_area) < 0.001:
		var average := Vector2.ZERO
		for point in polygon:
			average += point
		return average / maxf(1.0, float(polygon.size()))
	return Vector2(centroid_x / (3.0 * twice_area), centroid_y / (3.0 * twice_area))


## Nombre de secteurs 2D touchés par la boîte englobante d'une empreinte.
## Le maximum est traité comme une limite exclusive pour éviter de compter
## deux secteurs lorsqu'un sommet tombe exactement sur une frontière.
static func polygon_sector_span(points: PackedVector2Array, sector_size: float = 800.0) -> Vector2i:
	if points.is_empty() or sector_size <= 0.0:
		return Vector2i.ZERO
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	var last_x := maxf(min_x, max_x - 0.001)
	var last_y := maxf(min_y, max_y - 0.001)
	var min_sector_x := floori(min_x / sector_size)
	var min_sector_y := floori(min_y / sector_size)
	var max_sector_x := floori(last_x / sector_size)
	var max_sector_y := floori(last_y / sector_size)
	return Vector2i(max_sector_x - min_sector_x + 1, max_sector_y - min_sector_y + 1)


## Secteurs couverts par la boîte englobante d'une géométrie, avec marge optionnelle.
## L'emprise est volontairement conservative : aucun morceau du mesh ne peut
## sortir d'un secteur déclaré, au prix de quelques secteurs parfois surnuméraires.
static func polygon_sector_keys(points: PackedVector2Array, sector_size: float = 800.0, margin: float = 0.0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if points.is_empty() or sector_size <= 0.0:
		return result
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	min_x -= maxf(margin, 0.0)
	min_y -= maxf(margin, 0.0)
	max_x += maxf(margin, 0.0)
	max_y += maxf(margin, 0.0)
	var first_x := floori(min_x / sector_size)
	var first_y := floori(min_y / sector_size)
	var last_x := floori(maxf(min_x, max_x - 0.001) / sector_size)
	var last_y := floori(maxf(min_y, max_y - 0.001) / sector_size)
	for x in range(first_x, last_x + 1):
		for y in range(first_y, last_y + 1):
			result.append(Vector2i(x, y))
	return result


## Emprise d'une ligne routière sur la grille des secteurs.
## Les coordonnées sont en X/Z monde ; le maximum est traité comme exclusif.
## Vrai si une polyligne touche un disque, même lorsque ses deux extrémités
## sont hors du rayon. Utilisé pour conserver les axes qui traversent la zone chargée.
static func polyline_intersects_circle(points: PackedVector2Array, center: Vector2, radius: float) -> bool:
	if points.is_empty() or radius < 0.0:
		return false
	var radius_squared := radius * radius
	for point in points:
		if point.distance_squared_to(center) <= radius_squared:
			return true
	for index in range(points.size() - 1):
		var nearest := Geometry2D.get_closest_point_to_segment(center, points[index], points[index + 1])
		if nearest.distance_squared_to(center) <= radius_squared:
			return true
	return false


static func line_sector_span(points: PackedVector2Array, sector_size: float = 800.0) -> Vector2i:
	if points.is_empty() or sector_size <= 0.0:
		return Vector2i.ZERO
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	var last_x := maxf(min_x, max_x - 0.001)
	var last_y := maxf(min_y, max_y - 0.001)
	var min_sector_x := floori(min_x / sector_size)
	var min_sector_y := floori(min_y / sector_size)
	var max_sector_x := floori(last_x / sector_size)
	var max_sector_y := floori(last_y / sector_size)
	return Vector2i(max_sector_x - min_sector_x + 1, max_sector_y - min_sector_y + 1)


## Découpe une polyligne X/Z aux frontières de secteurs sans perdre sa continuité.
## Chaque entrée contient le secteur propriétaire et les sommets du morceau.
## Les points de frontière sont partagés exactement entre deux morceaux voisins.
static func split_polyline_by_sectors(points: PackedVector3Array, sector_size: float = 800.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if points.size() < 2 or sector_size <= 0.0:
		return result

	for segment_index in range(points.size() - 1):
		var start := points[segment_index]
		var finish := points[segment_index + 1]
		var delta := finish - start
		var cuts: Array[float] = [0.0, 1.0]

		if absf(delta.x) > 0.000001:
			var min_x := minf(start.x, finish.x)
			var max_x := maxf(start.x, finish.x)
			var first_boundary := floori(min_x / sector_size) + 1
			var last_boundary := floori(max_x / sector_size)
			for boundary_index in range(first_boundary, last_boundary + 1):
				var boundary_x := float(boundary_index) * sector_size
				var t_x := (boundary_x - start.x) / delta.x
				if t_x > 0.000001 and t_x < 0.999999:
					cuts.append(t_x)

		if absf(delta.z) > 0.000001:
			var min_z := minf(start.z, finish.z)
			var max_z := maxf(start.z, finish.z)
			var first_boundary_z := floori(min_z / sector_size) + 1
			var last_boundary_z := floori(max_z / sector_size)
			for boundary_index_z in range(first_boundary_z, last_boundary_z + 1):
				var boundary_z := float(boundary_index_z) * sector_size
				var t_z := (boundary_z - start.z) / delta.z
				if t_z > 0.000001 and t_z < 0.999999:
					cuts.append(t_z)

		cuts.sort()
		var unique_cuts: Array[float] = []
		for cut in cuts:
			if unique_cuts.is_empty() or absf(cut - unique_cuts[unique_cuts.size() - 1]) > 0.000001:
				unique_cuts.append(cut)

		for cut_index in range(unique_cuts.size() - 1):
			var t0: float = unique_cuts[cut_index]
			var t1: float = unique_cuts[cut_index + 1]
			if t1 - t0 <= 0.000001:
				continue
			var piece_start := start.lerp(finish, t0)
			var piece_end := start.lerp(finish, t1)
			var midpoint := start.lerp(finish, (t0 + t1) * 0.5)
			var sector := Vector2i(floori(midpoint.x / sector_size), floori(midpoint.z / sector_size))

			if not result.is_empty() and result[result.size() - 1].sector == sector:
				var previous_points: PackedVector3Array = result[result.size() - 1].points
				if previous_points[previous_points.size() - 1].distance_to(piece_start) <= 0.001:
					previous_points.append(piece_end)
					result[result.size() - 1].points = previous_points
					continue

			var piece_points := PackedVector3Array([piece_start, piece_end])
			result.append({"sector": sector, "points": piece_points})

	return result


static func polygon_area_abs(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var twice_area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		twice_area += a.x * b.y - b.x * a.y
	return absf(twice_area) * 0.5



static func longest_polygon_edge(points: PackedVector2Array) -> Vector2:
	# x = index de la plus longue arête, y = sa longueur.
	# Le test strict conserve la première arête en cas d'égalité.
	var longest_index := 0
	var longest_length := 0.0
	for index in range(points.size()):
		var edge_length := points[index].distance_to(points[(index + 1) % points.size()])
		if edge_length > longest_length:
			longest_length = edge_length
			longest_index = index
	return Vector2(float(longest_index), longest_length)

static func polygon_signed_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(points.size()):
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		twice_area += a.x * b.y - b.x * a.y
	return twice_area * 0.5

static func pitched_roof_triangles(points: PackedVector2Array, wall_height: float, base_y: float = 0.0, shape: String = "gabled") -> PackedVector3Array:
	# Retourne les 6 triangles d'un toit à deux pans, sans toucher à une scène.
	# Un tableau vide signifie que l'empreinte ne convient pas à ce type de toit.
	if points.size() != 4:
		return PackedVector3Array()
	if shape == "skillion" or shape == "shed":
		var low_y := base_y + wall_height + 0.035
		var high_y := low_y + 0.9
		var skillion_p0 := Vector3(points[0].x, high_y, points[0].y)
		var skillion_p1 := Vector3(points[1].x, high_y, points[1].y)
		var skillion_p2 := Vector3(points[2].x, low_y, points[2].y)
		var skillion_p3 := Vector3(points[3].x, low_y, points[3].y)
		return PackedVector3Array([skillion_p0, skillion_p1, skillion_p2, skillion_p0, skillion_p2, skillion_p3])
	if shape == "hipped":
		var hip_longest_index := 0
		var hip_longest_length := 0.0
		for i in range(4):
			var hip_edge_length := points[i].distance_to(points[(i + 1) % 4])
			if hip_edge_length > hip_longest_length:
				hip_longest_length = hip_edge_length
				hip_longest_index = i
		var skillion_p0 := points[hip_longest_index]
		var skillion_p1 := points[(hip_longest_index + 1) % 4]
		var skillion_p2 := points[(hip_longest_index + 2) % 4]
		var skillion_p3 := points[(hip_longest_index + 3) % 4]
		var hip_roof_y := base_y + wall_height + 0.035
		var hip_short_side := minf(skillion_p0.distance_to(skillion_p3), skillion_p1.distance_to(skillion_p2))
		if hip_short_side <= 0.1 or hip_longest_length <= hip_short_side:
			return PackedVector3Array()
		var hip_inset := clampf((hip_longest_length - hip_short_side) * 0.18, 0.35, hip_longest_length * 0.22)
		var hip_start_mid := (skillion_p0 + skillion_p3) * 0.5
		var hip_end_mid := (skillion_p1 + skillion_p2) * 0.5
		var hip_axis := (hip_end_mid - hip_start_mid).normalized()
		var hip_ridge_start_2d := hip_start_mid + hip_axis * hip_inset
		var hip_ridge_end_2d := hip_end_mid - hip_axis * hip_inset
		var hip_ridge_y := hip_roof_y + clampf(hip_short_side * 0.24, 0.55, 1.5)
		var va := Vector3(skillion_p0.x, hip_roof_y, skillion_p0.y)
		var vb := Vector3(skillion_p1.x, hip_roof_y, skillion_p1.y)
		var vc := Vector3(skillion_p2.x, hip_roof_y, skillion_p2.y)
		var vd := Vector3(skillion_p3.x, hip_roof_y, skillion_p3.y)
		var hip_r0 := Vector3(hip_ridge_start_2d.x, hip_ridge_y, hip_ridge_start_2d.y)
		var hip_r1 := Vector3(hip_ridge_end_2d.x, hip_ridge_y, hip_ridge_end_2d.y)
		return PackedVector3Array([
			va, vb, hip_r1, va, hip_r1, hip_r0,
			vd, vc, hip_r1, vd, hip_r1, hip_r0,
			va, vd, hip_r0, vb, vc, hip_r1
		])
	if shape == "pyramidal":
		var center := Vector2.ZERO
		var min_edge := INF
		for i in range(4):
			center += points[i]
			min_edge = minf(min_edge, points[i].distance_to(points[(i + 1) % 4]))
		center /= 4.0
		if min_edge <= 0.1:
			return PackedVector3Array()
		var base_y_roof := base_y + wall_height + 0.035
		var apex := Vector3(center.x, base_y_roof + clampf(min_edge * 0.42, 0.8, 2.2), center.y)
		var pyramid := PackedVector3Array()
		for i in range(4):
			var a := points[i]
			var b := points[(i + 1) % 4]
			pyramid.append(Vector3(a.x, base_y_roof, a.y))
			pyramid.append(Vector3(b.x, base_y_roof, b.y))
			pyramid.append(apex)
		return pyramid
	var longest_index := 0
	var longest_length := 0.0
	var shortest_side := INF
	var cross_sign := 0.0
	for i in range(4):
		var edge := points[(i + 1) % 4] - points[i]
		var next_edge := points[(i + 2) % 4] - points[(i + 1) % 4]
		var edge_length := edge.length()
		longest_length = maxf(longest_length, edge_length)
		if edge_length > longest_length - 0.001:
			longest_index = i
		var cross_value := edge.cross(next_edge)
		if absf(cross_value) < 0.01:
			return PackedVector3Array()
		if cross_sign == 0.0:
			cross_sign = signf(cross_value)
		elif signf(cross_value) != cross_sign:
			return PackedVector3Array()
	for i in [((longest_index + 1) % 4), ((longest_index + 3) % 4)]:
		shortest_side = minf(shortest_side, points[i].distance_to(points[(i + 1) % 4]))
	if shortest_side <= 0.1 or longest_length / shortest_side < 1.18:
		return PackedVector3Array()

	var p0 := points[longest_index]
	var p1 := points[(longest_index + 1) % 4]
	var p2 := points[(longest_index + 2) % 4]
	var p3 := points[(longest_index + 3) % 4]
	var roof_y := base_y + wall_height + 0.035
	var ridge_y := roof_y + clampf(shortest_side * 0.30, 0.75, 1.9)
	var a := Vector3(p0.x, roof_y, p0.y)
	var b := Vector3(p1.x, roof_y, p1.y)
	var c := Vector3(p2.x, roof_y, p2.y)
	var d := Vector3(p3.x, roof_y, p3.y)
	var ridge_start_2d := (p0 + p3) * 0.5
	var ridge_end_2d := (p1 + p2) * 0.5
	var ridge_start := Vector3(ridge_start_2d.x, ridge_y, ridge_start_2d.y)
	var ridge_end := Vector3(ridge_end_2d.x, ridge_y, ridge_end_2d.y)
	return PackedVector3Array([
		a, b, ridge_end,
		a, ridge_end, ridge_start,
		ridge_start, ridge_end, c,
		ridge_start, c, d,
		a, ridge_start, d,
		b, c, ridge_end
	])


## Découpe un triangle 2D contre le rectangle d'un secteur.
## L'entrée est convexe (un triangle) : le résultat reste un polygone convexe
## directement triangulable en éventail. Les intersections sont calculées
## exactement sur les limites, sans epsilon visuel ajouté.
static func clip_triangle_to_rect(triangle: PackedVector2Array, rect_min: Vector2, rect_max: Vector2) -> PackedVector2Array:
	if triangle.size() != 3 or rect_min.x >= rect_max.x or rect_min.y >= rect_max.y:
		return PackedVector2Array()
	var clipped := triangle
	clipped = _clip_polygon_axis(clipped, 0, rect_min.x, true)
	clipped = _clip_polygon_axis(clipped, 0, rect_max.x, false)
	clipped = _clip_polygon_axis(clipped, 1, rect_min.y, true)
	clipped = _clip_polygon_axis(clipped, 1, rect_max.y, false)
	if clipped.size() < 3 or polygon_area_abs(clipped) < 0.000001:
		return PackedVector2Array()
	return clipped


## Variante du clipping qui conserve les coordonnées barycentriques de chaque
## sommet dans le triangle source. Elles permettent de reconstruire sans perte
## les UV, couleurs, normales et altitudes lors du découpage des meshes routiers.
## Chaque entrée contient position (Vector2) et weights (Vector3).
static func clip_triangle_to_rect_with_weights(triangle: PackedVector2Array,
		rect_min: Vector2, rect_max: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if triangle.size() != 3 or rect_min.x >= rect_max.x or rect_min.y >= rect_max.y:
		return result
	var vertices: Array[Dictionary] = [
		{"position": triangle[0], "weights": Vector3(1.0, 0.0, 0.0)},
		{"position": triangle[1], "weights": Vector3(0.0, 1.0, 0.0)},
		{"position": triangle[2], "weights": Vector3(0.0, 0.0, 1.0)}
	]
	vertices = _clip_weighted_axis(vertices, 0, rect_min.x, true)
	vertices = _clip_weighted_axis(vertices, 0, rect_max.x, false)
	vertices = _clip_weighted_axis(vertices, 1, rect_min.y, true)
	vertices = _clip_weighted_axis(vertices, 1, rect_max.y, false)
	if vertices.size() < 3:
		return result
	var positions := PackedVector2Array()
	for vertex in vertices:
		positions.append(vertex.position)
	if polygon_area_abs(positions) < 0.000001:
		return result
	return vertices



## Interpole un attribut porté par les trois sommets d'un triangle à partir
## de coordonnées barycentriques. Les normales doivent être renormalisées par
## l'appelant ; les tangentes doivent aussi être réorthogonalisées si nécessaire.
## Les types pris en charge correspondent aux attributs courants d'ArrayMesh.
static func interpolate_triangle_attribute(values: Array, weights: Vector3) -> Variant:
	if values.size() != 3:
		return null
	var a: Variant = values[0]
	var b: Variant = values[1]
	var c: Variant = values[2]
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return float(a) * weights.x + float(b) * weights.y + float(c) * weights.z
		TYPE_VECTOR2:
			var va: Vector2 = a
			var vb: Vector2 = b
			var vc: Vector2 = c
			return va * weights.x + vb * weights.y + vc * weights.z
		TYPE_VECTOR3:
			var va: Vector3 = a
			var vb: Vector3 = b
			var vc: Vector3 = c
			return va * weights.x + vb * weights.y + vc * weights.z
		TYPE_VECTOR4:
			var va: Vector4 = a
			var vb: Vector4 = b
			var vc: Vector4 = c
			return va * weights.x + vb * weights.y + vc * weights.z
		TYPE_COLOR:
			var ca: Color = a
			var cb: Color = b
			var cc: Color = c
			return ca * weights.x + cb * weights.y + cc * weights.z
		_:
			return null



## Découpe une surface triangulaire ArrayMesh dans un rectangle X/Z.
## Les attributs standards sont reconstruits par coordonnées barycentriques.
## Retourne null pour les primitives ou attributs de skinning non pris en charge.
static func clip_array_mesh_surface_to_rect(source_mesh: ArrayMesh, surface_index: int,
		rect_min: Vector2, rect_max: Vector2) -> ArrayMesh:
	if source_mesh == null or surface_index < 0 or surface_index >= source_mesh.get_surface_count():
		return null
	if source_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
		return null
	if rect_min.x >= rect_max.x or rect_min.y >= rect_max.y:
		return null
	var source_arrays: Array = source_mesh.surface_get_arrays(surface_index)
	if source_arrays.size() != Mesh.ARRAY_MAX:
		return null
	var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	if source_vertices.size() < 3:
		return null
	var source_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
	if source_indices.is_empty():
		source_indices.resize(source_vertices.size())
		for index in range(source_indices.size()):
			source_indices[index] = index
	if source_indices.size() < 3 or source_indices.size() % 3 != 0:
		return null
	var source_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
	var source_tangents: PackedFloat32Array = source_arrays[Mesh.ARRAY_TANGENT]
	var source_colors: PackedColorArray = source_arrays[Mesh.ARRAY_COLOR]
	var source_uv: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV]
	var source_uv2: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV2]
	var source_bones: PackedInt32Array = source_arrays[Mesh.ARRAY_BONES]
	var source_weights: PackedFloat32Array = source_arrays[Mesh.ARRAY_WEIGHTS]
	if (not source_bones.is_empty() and source_bones.size() != source_vertices.size() * 4) or (not source_weights.is_empty() and source_weights.size() != source_vertices.size() * 4):
		return null
	if not source_bones.is_empty() or not source_weights.is_empty():
		return null
	if not source_normals.is_empty() and source_normals.size() != source_vertices.size():
		return null
	if not source_colors.is_empty() and source_colors.size() != source_vertices.size():
		return null
	if not source_uv.is_empty() and source_uv.size() != source_vertices.size():
		return null
	if not source_uv2.is_empty() and source_uv2.size() != source_vertices.size():
		return null
	if not source_tangents.is_empty() and source_tangents.size() != source_vertices.size() * 4:
		return null
	var output_vertices := PackedVector3Array()
	var output_normals := PackedVector3Array()
	var output_tangents := PackedFloat32Array()
	var output_colors := PackedColorArray()
	var output_uv := PackedVector2Array()
	var output_uv2 := PackedVector2Array()
	for triangle_start in range(0, source_indices.size(), 3):
		var ia := source_indices[triangle_start]
		var ib := source_indices[triangle_start + 1]
		var ic := source_indices[triangle_start + 2]
		if ia < 0 or ib < 0 or ic < 0 or ia >= source_vertices.size() or ib >= source_vertices.size() or ic >= source_vertices.size():
			return null
		var source_ids := [ia, ib, ic]
		var source_triangle := PackedVector2Array([
			Vector2(source_vertices[ia].x, source_vertices[ia].z),
			Vector2(source_vertices[ib].x, source_vertices[ib].z),
			Vector2(source_vertices[ic].x, source_vertices[ic].z)
		])
		var clipped := clip_triangle_to_rect_with_weights(source_triangle, rect_min, rect_max)
		if clipped.size() < 3:
			continue
		for fan_index in range(1, clipped.size() - 1):
			var polygon_indices := [0, fan_index, fan_index + 1]
			for polygon_index in polygon_indices:
				var weights: Vector3 = clipped[polygon_index]["weights"]
				var position_values: Array = [source_vertices[ia], source_vertices[ib], source_vertices[ic]]
				var position: Vector3 = interpolate_triangle_attribute(position_values, weights)
				output_vertices.append(position)
				if not source_normals.is_empty():
					var normal_values: Array = [source_normals[ia], source_normals[ib], source_normals[ic]]
					var normal: Vector3 = interpolate_triangle_attribute(normal_values, weights)
					output_normals.append(normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP)
				if not source_tangents.is_empty():
					var tangent_values: Array = [
						Vector4(source_tangents[ia * 4], source_tangents[ia * 4 + 1], source_tangents[ia * 4 + 2], source_tangents[ia * 4 + 3]),
						Vector4(source_tangents[ib * 4], source_tangents[ib * 4 + 1], source_tangents[ib * 4 + 2], source_tangents[ib * 4 + 3]),
						Vector4(source_tangents[ic * 4], source_tangents[ic * 4 + 1], source_tangents[ic * 4 + 2], source_tangents[ic * 4 + 3])
					]
					var tangent: Vector4 = interpolate_triangle_attribute(tangent_values, weights)
					var tangent_direction := Vector3(tangent.x, tangent.y, tangent.z).normalized()
					output_tangents.append(tangent_direction.x)
					output_tangents.append(tangent_direction.y)
					output_tangents.append(tangent_direction.z)
					output_tangents.append(-1.0 if tangent.w < 0.0 else 1.0)
				if not source_colors.is_empty():
					output_colors.append(interpolate_triangle_attribute([source_colors[ia], source_colors[ib], source_colors[ic]], weights))
				if not source_uv.is_empty():
					output_uv.append(interpolate_triangle_attribute([source_uv[ia], source_uv[ib], source_uv[ic]], weights))
				if not source_uv2.is_empty():
					output_uv2.append(interpolate_triangle_attribute([source_uv2[ia], source_uv2[ib], source_uv2[ic]], weights))
	if output_vertices.is_empty():
		return null
	var output_arrays: Array = []
	output_arrays.resize(Mesh.ARRAY_MAX)
	output_arrays[Mesh.ARRAY_VERTEX] = output_vertices
	if not output_normals.is_empty():
		output_arrays[Mesh.ARRAY_NORMAL] = output_normals
	if not output_tangents.is_empty():
		output_arrays[Mesh.ARRAY_TANGENT] = output_tangents
	if not output_colors.is_empty():
		output_arrays[Mesh.ARRAY_COLOR] = output_colors
	if not output_uv.is_empty():
		output_arrays[Mesh.ARRAY_TEX_UV] = output_uv
	if not output_uv2.is_empty():
		output_arrays[Mesh.ARRAY_TEX_UV2] = output_uv2
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output_arrays)
	result.surface_set_material(0, source_mesh.surface_get_material(surface_index))
	return result


static func _clip_weighted_axis(vertices: Array[Dictionary], axis: int,
		boundary: float, keep_greater: bool) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if vertices.is_empty():
		return output
	var previous: Dictionary = vertices[vertices.size() - 1]
	var previous_position: Vector2 = previous.position
	var previous_value := previous_position.x if axis == 0 else previous_position.y
	var previous_inside := previous_value >= boundary if keep_greater else previous_value <= boundary
	for current_variant in vertices:
		var current: Dictionary = current_variant
		var current_position: Vector2 = current.position
		var current_value := current_position.x if axis == 0 else current_position.y
		var current_inside := current_value >= boundary if keep_greater else current_value <= boundary
		if current_inside != previous_inside:
			var denominator := current_value - previous_value
			if absf(denominator) > 0.0000001:
				var weight := (boundary - previous_value) / denominator
				var previous_weights: Vector3 = previous["weights"]
				var current_weights: Vector3 = current["weights"]
				output.append({
					"position": previous_position.lerp(current_position, weight),
					"weights": previous_weights.lerp(current_weights, weight)
				})
		if current_inside:
			output.append(current)
		previous = current
		previous_position = current_position
		previous_value = current_value
		previous_inside = current_inside
	var cleaned: Array[Dictionary] = []
	for vertex in output:
		var position: Vector2 = vertex.position
		var last_position: Vector2 = cleaned[cleaned.size() - 1]["position"] if not cleaned.is_empty() else Vector2.ZERO
		if cleaned.is_empty() or last_position.distance_to(position) > 0.00001:
			cleaned.append(vertex)
	if cleaned.size() > 1:
		var first_position: Vector2 = cleaned[0]["position"]
		var last_position: Vector2 = cleaned[cleaned.size() - 1]["position"]
		if first_position.distance_to(last_position) <= 0.00001:
			cleaned.remove_at(cleaned.size() - 1)
	return cleaned


static func _clip_polygon_axis(points: PackedVector2Array, axis: int, boundary: float, keep_greater: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	if points.is_empty():
		return output
	var previous := points[points.size() - 1]
	var previous_value := previous.x if axis == 0 else previous.y
	var previous_inside := previous_value >= boundary if keep_greater else previous_value <= boundary
	for current in points:
		var current_value := current.x if axis == 0 else current.y
		var current_inside := current_value >= boundary if keep_greater else current_value <= boundary
		if current_inside != previous_inside:
			var denominator := current_value - previous_value
			if absf(denominator) > 0.0000001:
				var weight := (boundary - previous_value) / denominator
				output.append(previous.lerp(current, weight))
		if current_inside:
			output.append(current)
		previous = current
		previous_value = current_value
		previous_inside = current_inside
	# Remove consecutive duplicate vertices created when an edge lies on a boundary.
	var cleaned := PackedVector2Array()
	for point in output:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > 0.00001:
			cleaned.append(point)
	if cleaned.size() > 1 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= 0.00001:
		cleaned.remove_at(cleaned.size() - 1)
	return cleaned
