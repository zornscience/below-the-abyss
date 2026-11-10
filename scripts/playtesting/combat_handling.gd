class_name CombatHandling
extends RefCounted
const WEIGHTY: SubmarineMotion = preload("res://resources/balance/expedition_motion.tres")
const RESPONSIVE: SubmarineMotion = preload("res://resources/playtesting/responsive_motion.tres")
static func profile(id: String) -> SubmarineMotion:
	return WEIGHTY if id=="weighty" else (RESPONSIVE if id=="responsive" else null)
static func predicted(motion: SubmarineMotion) -> Dictionary:
	# Releasing thrust coasts until the existing 0.5-unit snap. Reversing thrust is
	# constant acceleration toward -top speed; time ends at 90% reverse speed.
	var stop_time: float = log(motion.maximum_speed/0.5)/motion.damping
	return {"top_speed":motion.maximum_speed,"to_90_seconds":0.9*motion.maximum_speed/motion.acceleration,
		"turn_90_seconds":1.9*motion.maximum_speed/motion.acceleration,"facing_reverse_seconds":(motion.maximum_speed+12.0)/motion.acceleration,
		"stop_seconds":stop_time,"stop_distance":(motion.maximum_speed-0.5)/motion.damping}
