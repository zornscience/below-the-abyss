class_name EmergencyBuoyVisual
extends Node2D
## Original environmental prop; no final-submarine wreck or later-zone imagery.
var recovered: bool = false
func _draw() -> void:
	var rim: Color = Color("a8c7c2")
	draw_line(Vector2(0,-55),Vector2(0,-24),rim,3,true)
	draw_circle(Vector2(0,-56),5,Color("c8dd9d") if not recovered else Color("718a8d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-27,-22),Vector2(-18,-35),Vector2(18,-35),Vector2(27,-22),Vector2(20,14),Vector2(-20,14)]),Color("ab8952"))
	draw_rect(Rect2(-20,-17,40,19),Color("233d49"))
	draw_line(Vector2(-21,4),Vector2(21,4),rim,3,true)
	draw_line(Vector2(-14,17),Vector2(-32,62),Color("506d66"),2,true)
	draw_line(Vector2(-32,62),Vector2(-40,78),Color("506d66"),2,true)
	draw_string(ThemeDB.fallback_font,Vector2(-18,-3),"L-1",HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"secondary"),Color("dfe3c9"))
