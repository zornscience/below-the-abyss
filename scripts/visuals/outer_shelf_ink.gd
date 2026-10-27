class_name OuterShelfInk
extends Node2D
var shaded: bool = false
## Cached original environmental detail. No secret map markers or collision impostors.
func _draw() -> void:
	for index: int in range(100):
		var x: float = 4300+index*190
		var y: float = 1400+sin(index*1.7)*35
		var ink: Color = Color("315e5a")
		for branch: int in range(5):
			draw_line(Vector2(x,y),Vector2(x+(branch-2)*10,y-18-(branch%3)*12),ink,2,true)
		for dot: int in range(3):
			draw_circle(Vector2(x+dot*12,y-14),2,Color("6d9d7f"))
	# The abandoned instrument has a mast, pressure cans and a slack tether.
	draw_polyline(PackedVector2Array([Vector2(6400,1000),Vector2(6500,900),Vector2(6500,720),Vector2(6580,745)]),Color("7b9188"),5,true)
	for x: float in [6460.0,6530.0]:
		draw_rect(Rect2(x,840,28,70),Color("6a8783"))
	# Mineral chimneys are narrow nonsolid surface details below the traversable passage.
	for index: int in range(9):
		var x: float = 12100+index*190
		var tip: Vector2 = Vector2(x+sin(index)*22,1350-(index%4)*45)
		if shaded:
			draw_polygon(PackedVector2Array([Vector2(x-26,1440),tip+Vector2(-5,0),tip+Vector2(8,4),Vector2(x+25,1440)]),PackedColorArray([Color("1b3f49"),Color("89a494"),Color("678c7f"),Color("284e58")]))
		else:
			draw_polyline(PackedVector2Array([Vector2(x-20,1440),tip,Vector2(x+20,1440)]),Color("4d7b78"),5,true)
		draw_circle(tip,6,Color("91b8a1"))
	# Broken cable and debris make the wreck approach visually distinct without arrows.
	for index: int in range(24):
		var at: Vector2 = Vector2(19000+index*100,1490+sin(index*0.9)*18)
		draw_line(at,at+Vector2(50,8),Color("8a8665"),2,true)
