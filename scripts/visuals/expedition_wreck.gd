class_name ExpeditionWreck
extends Node2D
## Original illustrated wreck silhouette and floor debris; stable research target lives beside it.
func _ready() -> void:
	var hull: StaticBody2D = StaticBody2D.new()
	hull.collision_layer = 1
	hull.collision_mask = 2
	var shape: CollisionPolygon2D = CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(-235,38),Vector2(-195,-50),Vector2(-80,-85),Vector2(120,-65),Vector2(220,-5),Vector2(150,62),Vector2(-160,68)])
	hull.add_child(shape)
	add_child(hull)
func _draw() -> void:
	var hull: PackedVector2Array = PackedVector2Array([Vector2(-235,38),Vector2(-195,-50),Vector2(-80,-85),Vector2(120,-65),Vector2(220,-5),Vector2(150,62),Vector2(-160,68)])
	draw_colored_polygon(hull,Color("29434a"))
	var rim: PackedVector2Array = hull.duplicate()
	rim.append(hull[0])
	draw_polyline(rim,Color("698782"),3.0,true)
	for index: int in range(7):
		var x: float = -150+index*42
		draw_polyline(PackedVector2Array([Vector2(x,-54),Vector2(x-12,15),Vector2(x+9,56)]),Color("132d35"),7.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(115,-55),Vector2(200,-5),Vector2(150,42),Vector2(130,10),Vector2(148,-12)]),Color("07151d"))
	draw_line(Vector2(-90,-80),Vector2(-75,-145),Color("698782"),5.0)
	draw_line(Vector2(-75,-145),Vector2(30,-145),Color("698782"),4.0)
	for index: int in range(4):
		draw_circle(Vector2(-126+index*48,-22),12,Color("0c242c"))
		draw_arc(Vector2(-126+index*48,-22),14,0,TAU,24,Color("7c9a93"),2.0)
	draw_string(ThemeDB.fallback_font,Vector2(-90,31),"SURVEY  /  07",HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"hud"),Color("9aab9b"))
	for index: int in range(18):
		var at: Vector2 = Vector2(-330+index*39,72+sin(index*2.8)*16)
		draw_line(at,at+Vector2(18,-7),Color("648074"),4.0)
	draw_polyline(PackedVector2Array([Vector2(-260,60),Vector2(-340,12),Vector2(-410,50),Vector2(-460,42)]),Color("9e9671"),3.0,true)
