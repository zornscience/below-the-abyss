class_name BlastEffect
extends Node2D
## Illustrated pressure ring/debris. Comfort mode omits the bright core and debris.
var radius: float = 150.0
var elapsed: float = 0.0
var reduced_effects: bool = false
func advance(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.65:
		queue_free()
	queue_redraw()
func _draw() -> void:
	var t: float = clampf(elapsed / 0.65, 0.0, 1.0)
	var alpha: float = 1.0 - t
	draw_arc(Vector2.ZERO, maxf(1.0, radius * sqrt(t)), 0, TAU, 64, Color(0.96, 0.78, 0.4, alpha * 0.8), 3.0, true)
	if not reduced_effects:
		draw_circle(Vector2.ZERO, 22.0 * alpha, Color(1.0, 0.85, 0.55, alpha * 0.6))
		for index: int in range(12):
			var direction: Vector2 = Vector2.from_angle(index * TAU / 12.0)
			draw_line(direction * radius * t * 0.4, direction * radius * t * 0.65, Color(0.8, 0.68, 0.45, alpha), 2.0)
