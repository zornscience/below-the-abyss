class_name HammerheadCreature
extends PredatorCreature
## Head-first ram overlay; all hearing, navigation, pursuit limits and cooldowns are inherited.
func _after_step(delta: float) -> void:
	var player: SubmarineController = _live_player()
	if player==null or velocity.length()<20 or velocity.normalized().dot((player.global_position-global_position).normalized())<0.45:
		_hit_feedback = maxf(0,_hit_feedback-delta)
		return
	super._after_step(delta)

func hud_snapshot() -> Dictionary:
	var value: Dictionary = super.hud_snapshot()
	value.title = String(value.title).replace("PREDATOR","HAMMERHEAD")
	if threat.phase==PredatorState.Phase.QUIET: value.hint = "TERRITORIAL LAGOON · SHALLOW WATER IS SAFE"
	elif threat.phase==PredatorState.Phase.DISENGAGE: value.hint = "ASCEND ABOVE 110 m"
	return value

func _draw() -> void:
	# Detailed painted body is a child; the alert symbol remains accessible without colour.
	if threat.phase in [PredatorState.Phase.ALERT,PredatorState.Phase.PURSUE]:
		draw_string(ThemeDB.fallback_font,Vector2(-4,-45),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,UiTypography.base(&"heading"),Color("f4dc94"))
