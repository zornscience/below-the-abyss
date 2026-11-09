class_name RiftStalkerState
extends CreatureState
## Reuses arbitration, bounded investigation, patrol and return; legacy PredatorState is unchanged.
enum Phase { QUIET, INVESTIGATE, WARNING, PURSUE, STUN, FLEE, RETURN }
var phase: Phase = Phase.QUIET
var profile: RiftStalkerProfile
var target: Vector2
var target_valid: bool = false
var target_visible: bool = false
var _until: float = 0.0
var _stun_until: float = 0.0
var _flee_until: float = 0.0
var _next_damage: float = 0.0
var _chase: Vector2
var _next_replan: float = 0.0
func configure(rules: CreatureProfile) -> Error:
	if not rules is RiftStalkerProfile or not rules.is_valid(): return ERR_INVALID_PARAMETER
	profile = rules.duplicate(true) as RiftStalkerProfile
	return super.configure(rules)
func reset_session() -> void:
	super.reset_session()
	phase = Phase.QUIET
	target_valid = false
	_until = 0
	_next_damage = 0
	_stun_until = 0
	_flee_until = 0
func offer(event: AcousticEvent,strength: float,distance: float,origin: Vector2) -> Error:
	if profile==null or event==null or not event.is_valid() or not origin.is_finite() or not is_finite(strength) or not is_finite(distance) or distance<0: return ERR_INVALID_PARAMETER
	if event.event_id==_last_id or (not _pending.is_empty() and event.event_id==_pending.id): return ERR_ALREADY_EXISTS
	if phase not in [Phase.QUIET,Phase.INVESTIGATE] or _time<_recover_until or state==State.RETURN or event.source_id not in [profile.trigger_source_id,&"neris-01/torpedo"] \
		or not profile.hearing.accepts(event) or not profile.event_priorities.has(event.event_type) or strength<profile.hearing.minimum_strength or distance>minf(event.range_units,profile.hearing.maximum_range_units): return ERR_UNAVAILABLE
	# Receipt-local deadlines: sonar and the launcher retain different epochs across Continue.
	# Canonical events/history are untouched. No new event is created or published.
	var bounds: Rect2 = profile.center_bounds()
	var goal: Vector2 = origin.clamp(bounds.position+Vector2.ONE,bounds.end-Vector2.ONE)
	var candidate: Dictionary = {"id":event.event_id,"source":event.source_id,"priority":profile.event_priorities[event.event_type],"strength":strength,"timestamp":_time,"origin":goal}
	if preferred(candidate,_pending): _pending = candidate
	return OK
func sense(at: Vector2,valid: bool,visible: bool) -> void:
	target = at
	target_valid = valid
	target_visible = visible
func _arrival_allowed() -> bool:
	return state!=State.INVESTIGATE
func destination() -> Vector2:
	return _chase if phase==Phase.PURSUE else super.destination()
func speed() -> float:
	if phase==Phase.WARNING or phase==Phase.STUN: return 0.0
	if phase==Phase.PURSUE: return profile.pursuit_speed
	if phase==Phase.FLEE: return profile.flee_speed
	return super.speed()
func _safe_return(at: Vector2) -> void:
	phase = Phase.RETURN
	_pending.clear()
	_return(at,"STALKER / RETURN TO TERRITORY")
func advance(delta: float,at: Vector2,blocked: bool = false) -> Error:
	var result: Error = super.advance(delta,at,blocked)
	if result!=OK: return result
	if phase==Phase.STUN or phase==Phase.FLEE:
		if _time>=_flee_until: _safe_return(at)
		elif _time>=_stun_until: phase = Phase.FLEE
		return OK
	if phase==Phase.QUIET and state==State.INVESTIGATE: phase = Phase.INVESTIGATE
	var sensed: bool = target_valid and target_visible and profile.center_bounds().has_point(target) and at.distance_to(target)<=profile.sense_radius
	if phase==Phase.INVESTIGATE and sensed:
		phase = Phase.WARNING
		_until = _time+profile.warning_seconds
	if phase==Phase.WARNING or phase==Phase.PURSUE:
		if not target_valid or not target_visible or not profile.center_bounds().has_point(target) or at.distance_to(target)>profile.target_distance or state==State.RETURN:
			_safe_return(at)
		elif phase==Phase.WARNING and _time>=_until:
			phase = Phase.PURSUE
			_chase = target
			_next_replan = _time+profile.target_replan_seconds
			_until = _time+profile.pursuit_seconds
		elif phase==Phase.PURSUE and _time>=_until: _safe_return(at)
		elif phase==Phase.PURSUE and _time>=_next_replan:
			_chase = target
			_next_replan = _time+profile.target_replan_seconds
	elif phase==Phase.INVESTIGATE and state==State.RETURN: phase = Phase.RETURN
	elif phase==Phase.RETURN and state==State.PATROL and _time>=_recover_until: phase = Phase.QUIET
	return OK
func scare(origin: Vector2,at: Vector2) -> Error:
	if profile==null or not origin.is_finite() or at.distance_to(origin)>profile.scare_radius: return ERR_UNAVAILABLE
	# Nearest opted-in actor is selected by the scene adapter. No damage authority here.
	var refuge: Vector2 = profile.patrol_points[0]
	for point: Vector2 in profile.patrol_points:
		if point.distance_squared_to(origin)>refuge.distance_squared_to(origin): refuge = point
	if state==State.FLEE: return ERR_BUSY
	var result: Error = request_flee(refuge)
	if result!=OK: return result
	phase = Phase.STUN
	_stun_until = _time+profile.stun_seconds
	_flee_until = _stun_until+profile.flee_seconds
	return OK
func contact_ready(distance: float) -> bool:
	return phase==Phase.PURSUE and target_valid and is_finite(distance) and distance>=0 and distance<=profile.contact_radius and _time>=_next_damage
func contact_cost(distance: float,clear: bool) -> float:
	if not clear or not contact_ready(distance): return 0.0
	_next_damage = _time+profile.damage_cooldown
	return profile.contact_damage
