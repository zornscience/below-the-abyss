extends Node2D
## Presentation-only facing/propeller/lamplight. Never rotates the physics body.
var reduced_motion: bool = false
var _phase: float = 0.0


func _process(delta: float) -> void:
	var old_facing: float = scale.x
	var body: CharacterBody2D = get_parent() as CharacterBody2D
	if absf(body.velocity.x) > 12.0:
		scale.x = -1.0 if body.velocity.x < 0.0 else 1.0
	if body.is_physics_processing() and not reduced_motion:
		_phase = fmod(_phase + delta * (4.0 + body.velocity.length() * 0.06), TAU)
	if not reduced_motion or old_facing != scale.x:
		queue_redraw()


func _draw() -> void:
	for index: int in range(4):
		var reach: float = 110.0 + index * 28.0
		draw_colored_polygon(PackedVector2Array([Vector2(29, 0), Vector2(reach, -reach * 0.19), Vector2(reach, reach * 0.19)]), Color(0.58, 0.82, 0.72, 0.018))
	draw_line(Vector2(-34, -8 * cos(_phase)), Vector2(-34, 8 * cos(_phase)), Color("a6c3c5"), 2.0, true)
