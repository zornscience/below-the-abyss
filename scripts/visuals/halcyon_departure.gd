class_name HalcyonDeparture
extends Node2D
## Local art dressing at the existing dock. No collision, navigation or motion writes.
const STATION: Texture2D = HalcyonDescent.STATION
const CLIFF: Texture2D = HalcyonDescent.CLIFF
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index = -1
func _draw() -> void:
	# The painted platform deck sits above the fixed water surface (world y=0).
	draw_texture_rect(STATION,Rect2(160,-166,520,195),false)
	for x: int in [218,620]:
		draw_polyline(PackedVector2Array([Vector2(x,-18),Vector2(x,55),Vector2(x+12,190),Vector2(x+12,260)]),Color("3b7078"),3.0,true)
	for index: int in range(3):
		draw_set_transform(Vector2(292+index*103,8),PI*0.5)
		draw_texture_rect(HalcyonDescent.SEARCHLIGHT,Rect2(-12,-36,240,72),false,Color(0.71,0.74,0.60,0.10))
	draw_set_transform(Vector2.ZERO)
