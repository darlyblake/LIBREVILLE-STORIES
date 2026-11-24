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
