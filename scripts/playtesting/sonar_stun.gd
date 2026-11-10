class_name SonarStun
extends Node
signal used(affected: int)
var profile: SonarStunProfile = preload("res://resources/playtesting/sonar_stun.tres")
var targets: Array[CombatSwarmer] = []
func setup(player: SubmarineController,swarmers: Array[CombatSwarmer]) -> Error:
	if not profile.is_valid(): return ERR_INVALID_PARAMETER
	targets = swarmers
	player.sonar.pulse_emitted.connect(_ping)
	return OK
func _ping(event: AcousticEvent) -> void:
	var count: int = 0
	for actor: CombatSwarmer in targets:
		if actor._destroyed or actor._suspended or actor.global_position.distance_to(event.origin)>profile.range_units: continue
		if profile.requires_clear_path and not actor._clear(event.origin): continue
		if actor.model.stun(profile.seconds): count += 1
	used.emit(count)
