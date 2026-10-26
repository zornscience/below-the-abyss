class_name PredatorState
extends CreatureState
## Threat overlay uses the BTA-030 arbitration/patrol/return FSM unchanged by default.

enum Phase { QUIET, ALERT, PURSUE, DISENGAGE }
var phase: Phase = Phase.QUIET
var _threat: PredatorProfile
var _target: Vector2
var _target_valid: bool = false
var _leash_origin: Vector2
var _alert_until: float = 0.0
var _pursue_until: float = 0.0
var _next_damage_at: float = 0.0
var _next_target_at: float = 0.0
var _chase_point: Vector2


func configure(profile: CreatureProfile) -> Error:
	if not profile is PredatorProfile or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	_threat = profile.duplicate(true) as PredatorProfile
	return super.configure(profile)


func reset_session() -> void:
	super.reset_session()
	phase = Phase.QUIET
	_alert_until = 0.0
	_pursue_until = 0.0
	_next_damage_at = 0.0
	_next_target_at = 0.0
	_target_valid = false


func set_target(position: Vector2, valid: bool) -> void:
	_target_valid = valid and position.is_finite()
	if _target_valid:
		_target = position


func offer(event: AcousticEvent, strength: float, distance: float, local_origin: Vector2) -> Error:
	if event == null or _threat == null:
		return ERR_INVALID_PARAMETER
	if event.event_id == _last_id or (not _pending.is_empty() and event.event_id == _pending.id):
		return ERR_ALREADY_EXISTS
	if phase != Phase.QUIET or event.source_id != _threat.trigger_source_id:
		return ERR_UNAVAILABLE
	return super.offer(event, strength, distance, local_origin)


func _arrival_allowed() -> bool:
	return state != State.INVESTIGATE


func destination() -> Vector2:
	return _chase_point if phase == Phase.PURSUE else super.destination()


func speed() -> float:
	return _threat.pursuit_speed if phase == Phase.PURSUE else super.speed()


func _can_continue(position: Vector2) -> bool:
	return _target_valid and _rules.center_bounds().has_point(_target) \
		and _target.distance_to(_leash_origin) <= _threat.pursuit_distance \
		and _target.distance_to(position) <= _threat.target_distance


func _disengage(position: Vector2, why: String) -> void:
	phase = Phase.DISENGAGE
	_pending.clear()
	_return(position, why)


func advance(delta: float, position: Vector2, blocked: bool = false) -> Error:
	var result: Error = super.advance(delta, position, blocked)
	if result != OK:
		return result
	if phase == Phase.QUIET and state == State.INVESTIGATE:
		phase = Phase.ALERT
		_leash_origin = _focus.origin
		_alert_until = _focus.timestamp + _threat.warning_seconds
		_pursue_until = _alert_until + _threat.pursuit_seconds
	if phase == Phase.ALERT or phase == Phase.PURSUE:
		if state == State.RETURN:
			phase = Phase.DISENGAGE
		elif not _can_continue(position):
			_disengage(position, "TARGET RETREATED / LIMIT")
		elif _time + 0.000000001 >= _pursue_until:
			_disengage(position, "PURSUIT TIME LIMIT")
		elif phase == Phase.ALERT and _time + 0.000000001 >= _alert_until:
			phase = Phase.PURSUE
			_chase_point = _target
			_next_target_at = _time + _threat.target_replan_seconds
		elif phase == Phase.PURSUE and _time + 0.000000001 >= _next_target_at:
			_chase_point = _target
			_next_target_at = _time + _threat.target_replan_seconds
	elif phase == Phase.DISENGAGE and state == State.PATROL and _time + 0.000000001 >= _recover_until:
		phase = Phase.QUIET
	return OK


func contact_cost(distance: float, unobstructed: bool) -> float:
	if _threat == null or phase != Phase.PURSUE or not _target_valid or not unobstructed \
		or not is_finite(distance) or distance < 0.0 or distance > _threat.contact_radius \
		or _time + 0.000000001 < _next_damage_at:
		return 0.0
	_next_damage_at = _time + _threat.damage_cooldown
	return _threat.contact_damage


func snapshot() -> Dictionary:
	var value: Dictionary = super.snapshot()
	value.merge({"phase": phase, "warning_remaining": maxf(0.0, _alert_until - _time),
		"pursuit_remaining": maxf(0.0, _pursue_until - _time), "next_damage_at": _next_damage_at})
	return value
