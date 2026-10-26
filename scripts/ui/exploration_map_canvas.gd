class_name ExplorationMapCanvas
extends Control
## Draw only an explicit discovered snapshot, public survey extent and own position.

var bounds: Rect2
var points: Array[PointOfInterest] = []
var player_position: Vector2
var selected_id: StringName


func _point(world: Vector2) -> Vector2:
	var available: Vector2 = size - Vector2(48, 64)
	var scale_value: float = minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var origin: Vector2 = (size - bounds.size * scale_value) * 0.5
	return origin + (world - bounds.position) * scale_value


func _draw() -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var ink: Color = Color("8ed9d3")
	var start: Vector2 = _point(bounds.position)
	var end: Vector2 = _point(bounds.end)
	draw_rect(Rect2(start, end - start), Color("0b202c"), true)
	for index: int in range(1, 5):
		var x: float = lerpf(start.x, end.x, index / 5.0)
		draw_line(Vector2(x, start.y), Vector2(x, end.y), Color("23404b"))
	for index: int in range(1, 4):
		var y: float = lerpf(start.y, end.y, index / 4.0)
		draw_line(Vector2(start.x, y), Vector2(end.x, y), Color("23404b"))
	draw_rect(Rect2(start, end - start), ink, false, 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, start - Vector2(0, 8), "SURVEY EXTENT / SURFACE Y = 0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	for index: int in range(points.size()):
		var point: PointOfInterest = points[index]
		var at: Vector2 = _point(point.map_position)
		draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), ink, false, 2.0)
		if selected_id == point.stable_id:
			draw_arc(at, 12, 0, TAU, 32, Color("f4dc94"), 2.0, true)
		draw_string(font, at + Vector2(10, -8), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	var player: Vector2 = _point(player_position)
	draw_colored_polygon(PackedVector2Array([player + Vector2(0, -9), player + Vector2(9, 5), player + Vector2(-9, 5)]), Color("f4dc94"))
	draw_string(font, player + Vector2(12, 18), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f4dc94"))
