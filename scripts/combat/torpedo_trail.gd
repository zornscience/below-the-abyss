class_name TorpedoTrail
extends Node2D
## Scene-local world-space wake. Samples expire independently after impact.
var points: Array[Vector2] = []
var ages: Array[float] = []
var remainder: float = 0.0
var active: bool = true
var reduced: bool = false
func sample(at: Vector2, delta: float) -> void:
	for index: int in range(ages.size()): ages[index] += delta
	while not ages.is_empty() and ages[0] >= 1.2:
		ages.pop_front()
		points.pop_front()
	remainder += delta
	if active and remainder >= 1.0/60.0:
		remainder = fmod(remainder,1.0/60.0)
		points.append(at)
		ages.append(0.0)
	if not active and points.is_empty(): queue_free()
	queue_redraw()
func _draw() -> void:
	if reduced: return
	for index: int in range(1,points.size()):
		var alpha: float = pow(1.0-ages[index]/1.2,2.0)*0.45
		draw_line(points[index-1],points[index],Color(0.7,0.94,1.0,alpha),lerpf(9.0,2.0,alpha/0.45),true)
		if index%4 == 0: draw_circle(points[index],2.2,Color(0.83,0.97,1.0,alpha))
