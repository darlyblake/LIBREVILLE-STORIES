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
