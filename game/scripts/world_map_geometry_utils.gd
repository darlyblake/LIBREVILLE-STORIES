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
