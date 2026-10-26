class_name GrayboxRouteCheck
extends RefCounted
## Ephemeral playtest telemetry only. No mission, reward, save or unlock state.

enum Stage { AT_BASE, OUTBOUND, RETURNING, COMPLETE }
signal stage_changed(stage: Stage)
var stage: Stage = Stage.AT_BASE
var elapsed_seconds: float = 0.0


func reset() -> void:
	stage = Stage.AT_BASE
	elapsed_seconds = 0.0
	stage_changed.emit(stage)


func sample(in_base: bool, in_point_of_interest: bool, delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0:
		return ERR_INVALID_PARAMETER
	var previous: Stage = stage
	if stage == Stage.AT_BASE and not in_base:
		stage = Stage.OUTBOUND
	if stage == Stage.OUTBOUND and in_point_of_interest and not in_base:
		stage = Stage.RETURNING
	if stage == Stage.RETURNING and in_base:
		stage = Stage.COMPLETE
	if stage == Stage.OUTBOUND or stage == Stage.RETURNING:
		elapsed_seconds += delta
	if stage != previous:
		stage_changed.emit(stage)
	return OK
