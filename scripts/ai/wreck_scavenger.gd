class_name WreckScavenger
extends AcousticCreature
var player: SubmarineController
var encounter_started: bool = false
signal fled
func _before_step(_delta: float) -> void:
	if not encounter_started and is_instance_valid(player) and global_position.distance_to(player.global_position)<=620.0:
		var refuge: Vector2 = Vector2(22950,1120) if player.global_position.x<global_position.x else Vector2(21030,1110)
		if brain.request_flee(refuge)==OK:
			encounter_started = true
			fled.emit()
func reset_session() -> void:
	encounter_started = false
	super.reset_session()
