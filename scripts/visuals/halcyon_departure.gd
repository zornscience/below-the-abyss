class_name HalcyonDeparture
extends Node2D
## Local art dressing at the existing dock. No collision, navigation or motion writes.
const STATION: Texture2D = HalcyonDescent.STATION
const CLIFF: Texture2D = HalcyonDescent.CLIFF
func _ready() -> void:
	z_index = -1
func _draw() -> void:
	# Distant relief stops within the immediate departure vignette.
	draw_texture_rect(CLIFF,Rect2(580,230,330,520),false,Color(0.4,0.63,0.67,0.16))
	draw_texture_rect(STATION,Rect2(180,250,480,180),false)
	# Umbilicals connect familiar modules to the existing solid post/platform.
	draw_polyline(PackedVector2Array([Vector2(232,414),Vector2(218,453),Vector2(217,635),Vector2(237,690)]),Color("3b7078"),3.0,true)
	draw_line(Vector2(190,402),Vector2(190,688),Color("b5a779"),2.0,true)
	for x: int in range(230,650,35):
		draw_line(Vector2(x,695),Vector2(x-12,722),Color("b5a779"),3.0,true)
	# Faint illustrated light shafts are static and non-occluding, like the title lamp.
	for index: int in range(3):
		var at: Vector2 = Vector2(292+index*103,382)
		draw_colored_polygon(PackedVector2Array([at,at+Vector2(-35,240),at+Vector2(70,240)]),Color(0.71,0.65,0.47,0.026))
