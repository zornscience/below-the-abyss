class_name CreatureState
extends RefCounted
## Pure state/arbitration. The bus owns lifetime duplicate history, not this model.

signal state_changed(state: int)
enum State { PATROL, INVESTIGATE, RETURN }
var state: State = State.PATROL
var reason: String = "PATROL"
var patrol_index: int = 0
var _rules: CreatureProfile
var _time: float = 0.0
var _deadline: float = 0.0
var _recover_until: float = 0.0
var _blocked: float = 0.0
var _pending: Dictionary = {}
var _focus: Dictionary = {}
var _last_id: StringName


func configure(profile: CreatureProfile) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	_rules = profile.duplicate(true) as CreatureProfile
	reset_session()
	return OK


func reset_session() -> void:
	state = State.PATROL
	reason = "PATROL"
	patrol_index = 0
	_time = 0.0
	_deadline = 0.0
	_recover_until = 0.0
	_blocked = 0.0
	_pending.clear()
	_focus.clear()
	_last_id = &""
	state_changed.emit(state)


static func preferred(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	for key: String in ["priority", "strength", "timestamp"]:
		if a[key] != b[key]:
			return a[key] > b[key]
	if a.source != b.source:
		return String(a.source) < String(b.source)
	return String(a.id) < String(b.id)


func offer(event: AcousticEvent, strength: float, distance: float, local_origin: Vector2) -> Error:
	if _rules == null or event == null or not event.is_valid() or not is_finite(strength) or strength < 0.0 \
		or not is_finite(distance) or distance < 0.0 or not local_origin.is_finite():
		return ERR_INVALID_PARAMETER
	if event.event_id == _last_id or (not _pending.is_empty() and event.event_id == _pending.id):
		return ERR_ALREADY_EXISTS
	if state == State.RETURN or _time < _recover_until or not _rules.hearing.accepts(event) \
		or not _rules.event_priorities.has(event.event_type) or strength < _rules.hearing.minimum_strength \
		or distance > minf(event.range_units, _rules.hearing.maximum_range_units) \
		or not _rules.center_bounds().has_point(local_origin) \
		or event.simulation_time + _rules.sound_memory_seconds < _time \
		or event.simulation_time > _time + _rules.sound_memory_seconds:
		return ERR_UNAVAILABLE
	var candidate: Dictionary = {"id": event.event_id, "source": event.source_id,
		"priority": _rules.event_priorities[event.event_type], "strength": strength,
		"timestamp": event.simulation_time, "origin": local_origin}
	if preferred(candidate, _pending):
		_pending = candidate
	return OK


func destination() -> Vector2:
	return _focus.origin if state == State.INVESTIGATE else _rules.patrol_points[patrol_index]


func speed() -> float:
	match state:
		State.INVESTIGATE: return _rules.investigate_speed
		State.RETURN: return _rules.return_speed
		_: return _rules.patrol_speed


func _transition(next: State, why: String) -> void:
	state = next
	reason = why
	_blocked = 0.0
	state_changed.emit(state)


func _return(position: Vector2, why: String) -> void:
	var best: float = INF
	for index: int in range(_rules.patrol_points.size()):
		var distance: float = position.distance_squared_to(_rules.patrol_points[index])
		if distance < best:
			best = distance
			patrol_index = index
	_recover_until = _time + _rules.recovery_seconds
	_transition(State.RETURN, why)


func advance(delta: float, position: Vector2, blocked: bool = false) -> Error:
	if _rules == null or not is_finite(delta) or delta < 0.0 or not is_finite(_time + delta) or not position.is_finite():
		return ERR_INVALID_PARAMETER
	_time += delta
	if not _pending.is_empty() and _pending.timestamp <= _time + 0.000000001:
		var candidate: Dictionary = _pending
		_pending = {}
		if state != State.RETURN and _time >= _recover_until \
			and candidate.timestamp + _rules.sound_memory_seconds >= _time \
			and candidate.timestamp + _rules.investigation_seconds > _time \
			and (state != State.INVESTIGATE or preferred(candidate, _focus)):
			if state != State.INVESTIGATE:
				_deadline = candidate.timestamp + _rules.investigation_seconds
			_focus = candidate
			_last_id = candidate.id
			_transition(State.INVESTIGATE, "SOUND / " + String(candidate.id))
	_blocked = _blocked + delta if blocked else 0.0
	if state == State.INVESTIGATE:
		if position.distance_to(destination()) <= _rules.arrival_radius:
			_return(position, "ARRIVED")
		elif _time + 0.000000001 >= _deadline:
			_return(position, "TIMEOUT")
		elif _blocked + 0.000000001 >= _rules.unreachable_seconds:
			_return(position, "UNREACHABLE")
	elif position.distance_to(destination()) <= _rules.arrival_radius:
		if state == State.RETURN:
			_transition(State.PATROL, "PATROL RECOVERED")
		patrol_index = (patrol_index + 1) % _rules.patrol_points.size()
	elif _blocked + 0.000000001 >= _rules.unreachable_seconds:
		patrol_index = (patrol_index + 1) % _rules.patrol_points.size()
		_blocked = 0.0
		reason = "BLOCKED / TRY NEXT PATROL POINT"
	return OK


func snapshot() -> Dictionary:
	return {"state": state, "reason": reason, "destination": destination(),
		"event_id": _last_id, "time": _time, "deadline": _deadline, "patrol_index": patrol_index}
