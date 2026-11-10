class_name SwarmerState
extends CreatureState
## Sound is the only engagement trigger. Contact, stun and dash deadlines are pure.
enum Phase { QUIET, INVESTIGATE, TELEGRAPH, DASH, COOLDOWN, STUN }
var phase: Phase = Phase.QUIET
var profile: SwarmerProfile
var goal: Vector2
var target: Vector2
var sees_target: bool = false
var clock: float = 0.0
var until: float = 0.0
var engaged_until: float = 0.0
var bitten: bool = false
func configure(rules: CreatureProfile) -> Error:
	if not rules is SwarmerProfile or not rules.is_valid(): return ERR_INVALID_PARAMETER
	profile = rules as SwarmerProfile
	return super.configure(rules)
func reset_session() -> void:
	super.reset_session()
	phase = Phase.QUIET
	clock = 0
	until = 0
	engaged_until = 0
	bitten = false
	sees_target = false
	if profile!=null: goal = profile.patrol_points[0]
func offer(event: AcousticEvent,strength: float,distance: float,origin: Vector2) -> Error:
	if profile==null or event==null or not event.is_valid() or not origin.is_finite() or not is_finite(distance) or distance<0 or not is_finite(strength): return ERR_INVALID_PARAMETER
	if event.event_id==_last_id: return ERR_ALREADY_EXISTS
	if phase not in [Phase.QUIET,Phase.INVESTIGATE] or event.source_id not in [&"neris-01/sonar",&"neris-01/torpedo"] or not profile.hearing.accepts(event) or strength<profile.hearing.minimum_strength or distance>minf(event.range_units,profile.hearing.maximum_range_units): return ERR_UNAVAILABLE
	_last_id = event.event_id
	var bounds: Rect2 = profile.center_bounds()
	goal = origin.clamp(bounds.position+Vector2.ONE,bounds.end-Vector2.ONE)
	phase = Phase.INVESTIGATE
	engaged_until = clock+profile.investigation_seconds
	return OK
func sense(at: Vector2,clear: bool) -> void:
	target = at
	sees_target = clear and profile.center_bounds().has_point(at)
func stun(seconds: float) -> bool:
	if profile==null or not is_finite(seconds) or seconds<=0: return false
	phase = Phase.STUN
	until = clock+seconds
	return true
func advance(delta: float,at: Vector2,_blocked_path: bool = false) -> Error:
	if profile==null or not is_finite(delta) or delta<0: return ERR_INVALID_PARAMETER
	clock += delta
	if phase==Phase.INVESTIGATE:
		if clock>=engaged_until: phase = Phase.QUIET
		elif sees_target and at.distance_to(target)<=profile.dash_range:
			goal = target
			phase = Phase.TELEGRAPH
			until = clock+profile.telegraph_seconds
	elif phase==Phase.TELEGRAPH and clock>=until:
		phase = Phase.DASH
		bitten = false
		until = clock+profile.dash_seconds
	elif phase==Phase.STUN and clock>=until:
		phase = Phase.INVESTIGATE if clock<engaged_until else Phase.QUIET
	elif phase==Phase.DASH and clock>=until:
		phase = Phase.COOLDOWN
		until = clock+profile.cooldown_seconds
	elif phase==Phase.COOLDOWN and clock>=until:
		phase = Phase.INVESTIGATE if clock<engaged_until else Phase.QUIET
	return OK
func destination() -> Vector2:
	return goal
func speed() -> float:
	if phase==Phase.INVESTIGATE: return profile.investigate_speed
	if phase==Phase.DASH: return profile.dash_speed
	return 0.0
func bite(distance: float,clear: bool) -> float:
	if phase!=Phase.DASH or bitten or not clear or not is_finite(distance) or distance<0 or distance>profile.bite_radius: return 0.0
	bitten = true
	return profile.bite_damage
