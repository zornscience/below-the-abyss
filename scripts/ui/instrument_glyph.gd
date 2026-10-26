class_name InstrumentGlyph
extends Control
## Small authored vector marks: decorative, always paired with text.

enum Kind { HULL, BATTERY, OXYGEN }
@export var kind: Kind = Kind.HULL
@export var ink: Color = Color("85d8cc")


func _draw() -> void:
	var center: Vector2 = size * 0.5
	match kind:
		Kind.HULL:
			var points: PackedVector2Array = PackedVector2Array([
				center + Vector2(-9, -9), center + Vector2(9, -9),
				center + Vector2(8, 3), center + Vector2(0, 10),
				center + Vector2(-8, 3), center + Vector2(-9, -9)])
			draw_polyline(points, ink, 2.0, true)
			draw_line(center + Vector2(-4, 0), center + Vector2(-1, 3), ink, 2.0, true)
			draw_line(center + Vector2(-1, 3), center + Vector2(5, -4), ink, 2.0, true)
		Kind.BATTERY:
			draw_rect(Rect2(center - Vector2(10, 7), Vector2(18, 14)), ink, false, 2.0)
			draw_line(center + Vector2(11, -3), center + Vector2(11, 3), ink, 2.0, true)
			for x: int in [-5, 0, 5]:
				draw_line(center + Vector2(x, -3), center + Vector2(x, 3), ink, 2.0, true)
		Kind.OXYGEN:
			draw_arc(center + Vector2(-4, 1), 7, 0, TAU, 32, ink, 2.0, true)
			draw_arc(center + Vector2(6, -4), 4, 0, TAU, 24, ink, 2.0, true)
