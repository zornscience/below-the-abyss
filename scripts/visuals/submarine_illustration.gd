extends Node2D
## Presentation-only facing/propeller/lamplight. Never rotates the physics body.
var reduced_motion: bool = false
var reduced_flashing: bool = false
var beam_length: float = 220.0
var _beacon_phase: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	# Instrument paint (including the red beacon) sits above the shared hull sprite.
	(get_node("NerisIllustration") as Sprite2D).show_behind_parent = true

func _process(delta: float) -> void:
	var old_facing: float = scale.x
	var body: SubmarineController = get_parent() as SubmarineController
	scale.x = body.facing_direction().x
	if body.is_physics_processing() and not reduced_motion and not reduced_flashing:
		_beacon_phase = fmod(_beacon_phase+delta*TAU/3.0,TAU)
	if body.is_physics_processing() and not reduced_motion:
		_phase = fmod(_phase + delta * (4.0 + body.velocity.length() * 0.06), TAU)
	if not reduced_motion or old_facing != scale.x:
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(HalcyonDescent.SEARCHLIGHT,Rect2(19,-maxf(24,beam_length*0.12),beam_length,maxf(48,beam_length*0.24)),false,Color(0.67,0.83,0.76,0.28))

	var glow: float = 0.55 if reduced_motion or reduced_flashing else 0.35+0.3*(0.5+0.5*cos(_beacon_phase))
	draw_circle(Vector2(4,-17),5,Color(0.95,0.08,0.05,glow*0.18))
	draw_circle(Vector2(4,-17),1.7,Color(1.0,0.13,0.09,glow))
	draw_line(Vector2(-34, -8 * cos(_phase)), Vector2(-34, 8 * cos(_phase)), Color("a6c3c5"), 2.0, true)
