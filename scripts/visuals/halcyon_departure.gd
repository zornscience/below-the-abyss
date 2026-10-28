class_name HalcyonDeparture
extends Node2D
## Local art dressing at the existing dock. No collision, navigation or motion writes.
const STATION: Texture2D = HalcyonDescent.STATION
const CLIFF: Texture2D = HalcyonDescent.CLIFF
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	# Shared painted optics, rotated locally; never a physics or screen-read effect.
	for index: int in range(3):
		draw_set_transform(Vector2(292+index*103,382),PI*0.5)
		draw_texture_rect(HalcyonDescent.SEARCHLIGHT,Rect2(-12,-36,240,72),false,Color(0.71,0.74,0.60,0.10))
	draw_set_transform(Vector2.ZERO)
