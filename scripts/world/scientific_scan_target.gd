class_name ScientificScanTarget
extends Node2D
## Non-colliding placeholder; no secrets shown before the associated discovery.

@export var target_id: StringName
var scan_enabled: bool = true
var _completed: bool = false
var _known: bool = false
var _classification: String = ""


func present(known: bool, category: String, completed: bool = false) -> void:
	_completed = completed
	_known = known
	_classification = category
	queue_redraw()


func _draw() -> void:
	if not _known:
		return
	var ink: Color = Color("f4dc94")
	if _classification == "geological":
		draw_polyline(PackedVector2Array([Vector2(-12, 8), Vector2(-3, -12), Vector2(12, 8), Vector2(-12, 8)]), ink, 2.0, true)
	else:
		draw_rect(Rect2(-10, -8, 20, 16), ink, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(16, 25), "RECORDED" if _completed else "SCAN SUBJECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
