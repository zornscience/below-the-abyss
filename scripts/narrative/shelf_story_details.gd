class_name ShelfStoryDetails
extends Node2D
## Original nonsolid line art on existing landmarks; no interaction or detection logic.
var _story: NarrativeService


func bind_story(story: NarrativeService) -> void:
	_story = story
	story.log_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var brass: Color = Color("b5a779")
	# Broken instrument mounting ear and engraved field-reference face.
	draw_style_box(_plate_style(), Rect2(738, 494, 46, 16))
	for offset: int in range(5):
		draw_line(Vector2(744 + offset * 7, 498), Vector2(744 + offset * 7, 506), brass, 1.0)
	draw_polyline(PackedVector2Array([Vector2(733, 492), Vector2(726, 497), Vector2(731, 501)]), brass, 2.0)
	# Empty retaining strap on the authored spire survey marker; passage stays clear.
	draw_polyline(PackedVector2Array([Vector2(3538, 676), Vector2(3538, 684), Vector2(3582, 684), Vector2(3582, 676)]), brass, 2.0)
	draw_line(Vector2(3548, 677), Vector2(3553, 669), brass, 1.5)
	if _story != null and _story.research.is_completed(NarrativeService.PLATE):
		draw_string(ThemeDB.fallback_font, Vector2(720, 530), "FIELD RECORD / RECOVERED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, brass)


func _plate_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("112e36")
	style.border_color = Color("b5a779")
	style.set_border_width_all(1)
	return style
