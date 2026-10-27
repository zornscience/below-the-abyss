class_name LightBloomVisual
extends Node2D
## Original illustrated colony, with a static comfort-mode reaction.
var collected: bool = false
var observed: bool = false
var reduced_effects: bool = false
var reaction: float = 0.0
func set_outcome(is_collected: bool, is_observed: bool, animate: bool = false) -> void:
	collected = is_collected
	observed = is_observed
	reaction = 1.4 if animate and not reduced_effects else 0.0
	queue_redraw()
func _process(delta: float) -> void:
	if reaction > 0.0:
		reaction = maxf(0.0,reaction-delta)
		queue_redraw()
func _draw() -> void:
	var pulse: float = sin((1.4-reaction)/1.4*PI)*0.12 if reaction>0.0 else 0.0
	if collected:
		draw_line(Vector2(-12,0),Vector2(1,-10),Color("586d70"),5,true)
		draw_line(Vector2(1,-10),Vector2(15,-5),Color("586d70"),4,true)
		draw_circle(Vector2(0,-9),5,Color("203d43"))
		return
	var center: Vector2 = Vector2(0,-42)
	for index: int in range(7):
		var angle: float = -PI+index*PI/6.0
		var tip: Vector2 = center+Vector2.from_angle(angle)*Vector2(40,35)*(1.0+pulse)
		var petal: PackedVector2Array = PackedVector2Array([Vector2(-5,0),center+Vector2.from_angle(angle-0.25)*22,tip,center+Vector2.from_angle(angle+0.25)*22,Vector2(6,0)])
		draw_polygon(petal,PackedColorArray([Color("284c52"),Color("488078"),Color("add9b4") if observed else Color("82bcc0"),Color("386d73"),Color("284c52")]))
	for index: int in range(5,0,-1):
		draw_circle(center,float(index)*7.0,Color(0.55,0.85,0.72,0.025+(0.008 if observed else 0.0)))
	draw_circle(center,8,Color("d6e5b1") if observed else Color("a2d8d2"))
	draw_line(Vector2.ZERO,center,Color("7aab91"),3,true)
