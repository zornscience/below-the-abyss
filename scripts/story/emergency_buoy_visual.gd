class_name EmergencyBuoyVisual
extends Node2D
## Original environmental prop; no final-submarine wreck or later-zone imagery.
var recovered: bool = false
const PAINT: Texture2D = preload("res://assets/art/sunlit/emergency_buoy.png")
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _draw() -> void:
	draw_texture_rect(PAINT,Rect2(-42,-65,84,140),false,Color(0.72,0.8,0.82) if recovered else Color.WHITE)
	draw_circle(Vector2(0,-56),2.2,Color("c8dd9d") if not recovered else Color("718a8d"))
	draw_string(ThemeDB.fallback_font,Vector2(-10,-3),"L-1",HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"secondary"),Color("dfe3c9"))
