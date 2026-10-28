class_name FishSchoolState
extends RefCounted
## Bounded fixed-step formation, gentle separation and smooth directional response.
const STEP: float = 1.0/60.0
var rules: FishSchoolProfile
var positions: Array[Vector2] = []
var headings: Array[float] = []
var elapsed: float = 0.0
var startled: float = 0.0
var _away: Vector2 = Vector2.ZERO
var _remainder: float = 0.0
var _seen: Array[StringName] = []

func configure(profile: FishSchoolProfile) -> Error:
	if profile==null or not profile.is_valid(): return ERR_INVALID_PARAMETER
	rules = profile.duplicate(false) as FishSchoolProfile
	reset()
	return OK

func reset() -> void:
	positions.clear()
	headings.clear()
	elapsed = 0.0
	startled = 0.0
	_remainder = 0.0
	_seen.clear()
	if rules==null: return
	for index: int in range(rules.population):
		positions.append(_formation(index))
		headings.append(0.0)

func _formation(index: int) -> Vector2:
	return Vector2((index%4-1.5)*rules.separation,(index/4-0.7)*rules.separation)

func hear(event: AcousticEvent,local_origin: Vector2) -> bool:
	if event==null or not event.is_valid() or event.event_type not in [&"active_sonar",&"explosion"] or event.event_id in _seen: return false
	_seen.append(event.event_id)
	if _seen.size()>64: _seen.pop_front()
	_away = (-local_origin).normalized()
	if _away.is_zero_approx(): _away = Vector2.RIGHT
	startled = rules.reaction_seconds
	return true

func react_to_vessel(local_position: Vector2) -> void:
	if local_position.length()<160 and startled<=0:
		_away = -local_position.normalized()
		startled = minf(1.0,rules.reaction_seconds)

func advance(delta: float) -> Error:
	if rules==null or not is_finite(delta) or delta<0 or delta>1: return ERR_INVALID_PARAMETER
	_remainder += delta
	while _remainder+0.000000001>=STEP:
		_remainder = maxf(0,_remainder-STEP)
		elapsed += STEP
		startled = maxf(0,startled-STEP)
		var center: Vector2 = Vector2(sin(elapsed*0.27)*65,sin(elapsed*0.19)*18)+_away*minf(28,startled*8)
		var previous: Array[Vector2] = positions.duplicate()
		for index: int in range(positions.size()):
			var repel: Vector2 = Vector2.ZERO
			for other: int in range(previous.size()):
				if other==index: continue
				var between: Vector2 = previous[index]-previous[other]
				if between.length_squared()>0.01 and between.length()<rules.separation: repel += between.normalized()*(rules.separation-between.length())
			var target: Vector2 = center+_formation(index)+Vector2(0,sin(elapsed*0.9+index)*4)
			var next: Vector2 = previous[index].move_toward(target,rules.speed*(1.0+sin(index*2.3)*0.08)*STEP)+repel*STEP*0.6
			next = next.clamp(rules.habitat.position+Vector2(8,8),rules.habitat.end-Vector2(8,8))
			var motion: Vector2 = next-previous[index]
			if motion.length_squared()>0.000001: headings[index] = lerp_angle(headings[index],motion.angle(),1.0-exp(-rules.turn_rate*STEP))
			positions[index] = next
	return OK
