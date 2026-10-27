class_name SeascapeRelief
extends Node2D
## Distant painted relief: deliberately behind solid terrain, never a collision boundary.
func _ready() -> void:
	z_index = -7
func _draw() -> void:
	for layer: int in range(4):
		var points: PackedVector2Array = []
		var colors: PackedColorArray = []
		for index: int in range(161):
			var x: float = index*150.0
			var y: float = 1120+layer*130+sin(index*0.42+layer)*105+sin(index*0.13)*95
			points.append(Vector2(x,y))
			colors.append(Color(0.04+layer*0.006,0.13+layer*0.018,0.18+layer*0.02,1))
		points.append(Vector2(24000,1800)); colors.append(Color("081927"))
		points.append(Vector2(0,1800)); colors.append(Color("081927"))
		draw_polygon(points,colors)
	for index: int in range(180):
		var at: Vector2 = Vector2(120+index*133,1510+sin((120+index*133)/150.0*0.42+3)*105+sin((120+index*133)/150.0*0.13)*95)
		for leaf: int in range(7):
			var tip: Vector2 = at+Vector2(sin(index+leaf)*24,-18-leaf*10)
			var shape: PackedVector2Array = PackedVector2Array([at,tip+Vector2(-6,-7),tip+Vector2(2,-17),tip+Vector2(8,-4)])
			draw_colored_polygon(shape,Color(0.09,0.25+leaf*0.006,0.24,0.7))
		for bud: int in range(4):
			draw_circle(at+Vector2(bud*8-12,-40+sin(index+bud)*13),3,Color("416f66"))
