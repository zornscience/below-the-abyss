extends Node2D
## Presentation-only facing/propeller/lamplight. Never rotates the physics body.
var reduced_motion: bool = false
var _phase: float = 0.0


func _process(delta: float) -> void:
	var old_facing: float = scale.x
	var body: SubmarineController = get_parent() as SubmarineController
	scale.x = body.facing_direction().x
	if body.is_physics_processing() and not reduced_motion:
		_phase = fmod(_phase + delta * (4.0 + body.velocity.length() * 0.06), TAU)
	if not reduced_motion or old_facing != scale.x:
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(HalcyonDescent.SEARCHLIGHT,Rect2(19,-24,220,48),false,Color(0.67,0.83,0.76,0.28))

	draw_line(Vector2(-34, -8 * cos(_phase)), Vector2(-34, 8 * cos(_phase)), Color("a6c3c5"), 2.0, true)
