class_name CreaturePaint
extends Node2D
var phase: float = 0.0
var hostile: bool = false
var reduced_motion: bool = false
func _process(delta: float) -> void:
	var creature: AcousticCreature = get_parent() as AcousticCreature
	if not creature._suspended and not reduced_motion: phase += delta*4.0
	if absf(creature.velocity.x)>2: scale.x = signf(creature.velocity.x)
	queue_redraw()
func _draw() -> void:
	var points: PackedVector2Array = []
	var colors: PackedColorArray = []
	for index: int in range(25):
		var angle: float = index*TAU/24.0
		points.append(Vector2(cos(angle)*25.0,sin(angle)*14.0))
		colors.append((Color("d4b88b") if hostile else Color("9cccbf")).lerp(Color("142e40"),(sin(angle)+1.0)*0.43))
	draw_polygon(points,colors)
	var fin: Color = Color("a3c7b2") if not hostile else Color("ba8f6c")
	draw_colored_polygon(PackedVector2Array([Vector2(-21,0),Vector2(-40,-15+sin(phase)*4),Vector2(-34,0),Vector2(-40,15+sin(phase)*4)]),fin.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-9,-10),Vector2(0,-24),Vector2(15,-10)]),fin)
	draw_colored_polygon(PackedVector2Array([Vector2(0,5),Vector2(-8,21+sin(phase)*3),Vector2(15,8)]),fin.darkened(0.4))
	for index: int in range(5): draw_arc(Vector2(-10+index*5,0),6,-PI*0.4,PI*0.4,10,Color(0.7,0.92,0.85,0.22),1,true)
	draw_circle(Vector2(16,-3),4,Color("e5e4ae"))
	draw_circle(Vector2(17,-3),2.2,Color("0b1e2a"))
	for index: int in range(3): draw_circle(Vector2(-10+index*8,6),1.5,Color("b4e7d3"))
