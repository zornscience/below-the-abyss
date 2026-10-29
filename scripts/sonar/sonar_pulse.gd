class_name SonarPulse
extends Node2D
## Fixed-origin visual and arrival schedule, fed only by AcousticReceiver receipts.

signal target_revealed(event_id: StringName, target_id: StringName)
const EPSILON: float = 0.000000001
var reduced_flashing: bool = false
var _event: AcousticEvent
var _rules: ActiveSonarProfile
var _bus: WeakRef
var _elapsed: float = 0.0
var _pending: Array[Dictionary] = []
var _scheduled: Dictionary[StringName, bool] = {}
var _dirty: bool = false
var _advancing: bool = false
var _finished: bool = false


func configure(event: AcousticEvent, profile: ActiveSonarProfile, bus: AcousticBus) -> Error:
	if event == null or not event.is_valid() or profile == null or not profile.is_valid() \
		or not is_instance_valid(bus) or event.range_units != profile.maximum_radius:
		return ERR_INVALID_PARAMETER
	_event = event.snapshot()
	_rules = profile.duplicate() as ActiveSonarProfile
	_bus = weakref(bus)
	z_index = 5
	return OK


func matches(event: AcousticEvent) -> bool:
	return _event != null and _event.same_payload(event)


func schedule_reveal(target: SonarRevealTarget, distance: float) -> Error:
	if _finished:
		return ERR_UNAVAILABLE
	if _event == null or not is_instance_valid(target) or not target.is_inside_tree() \
		or target.is_queued_for_deletion() or not is_finite(distance) or distance < 0.0 \
		or distance > _event.range_units or target.receiver.get_bus() != _bus.get_ref():
		return ERR_INVALID_PARAMETER
	if _scheduled.has(target.target_id):
		return ERR_ALREADY_EXISTS
	_scheduled[target.target_id] = true
	_pending.append({"target": weakref(target), "id": target.target_id,
		"generation": target.registration_generation, "distance": distance, "done": false})
	_dirty = true
	return OK


func get_radius() -> float:
	return minf(_event.range_units, _elapsed * _rules.travel_speed) if _event != null else 0.0


func advance(delta: float) -> Error:
	if _event == null or not is_finite(delta) or delta < 0.0:
		return ERR_INVALID_PARAMETER
	if _advancing:
		return ERR_BUSY
	if _finished:
		return OK
	var bus: AcousticBus = _bus.get_ref() as AcousticBus
	if not is_instance_valid(bus) or not bus.is_inside_tree() or bus.is_queued_for_deletion():
		_finished = true
		queue_free()
		return OK
	_advancing = true
	var lifetime: float = _event.range_units / _rules.travel_speed + _rules.fade_seconds
	_elapsed = minf(lifetime, _elapsed + minf(delta, lifetime))
	if _dirty:
		_pending.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return left.distance < right.distance if left.distance != right.distance else String(left.id) < String(right.id))
		_dirty = false
	for delivery: Dictionary in _pending:
		if delivery.done or _elapsed + EPSILON < float(delivery.distance) / _rules.travel_speed:
			continue
		delivery.done = true
		var target: SonarRevealTarget = delivery.target.get_ref() as SonarRevealTarget
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree() \
			or target.registration_generation != delivery.generation or target.target_id != delivery.id \
			or target.receiver.get_bus() != _bus.get_ref():
			continue
		if target.reveal_for_ping(_event.event_id, _rules.reveal_seconds,
			_event.simulation_time + float(delivery.distance) / _rules.travel_speed) == OK:
			target_revealed.emit(_event.event_id, target.target_id)
	queue_redraw()
	if _elapsed + EPSILON >= lifetime:
		_finished = true
		queue_free()
	_advancing = false
	return OK


func _draw() -> void:
	if _event == null:
		return
	var fade: float = 1.0
	if _rules.fade_seconds > 0.0:
		fade = clampf((_event.range_units / _rules.travel_speed + _rules.fade_seconds - _elapsed) / _rules.fade_seconds, 0.0, 1.0)
	if reduced_flashing:
		fade *= 0.45
	var radius: float = get_radius()
	if radius > 0.0:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 256, Color(0.42, 0.95, 0.87, fade * 0.9), 3.0, true)
		if radius > 10.0:
			draw_arc(Vector2.ZERO, radius - 10.0, 0.0, TAU, 256, Color(0.42, 0.95, 0.87, fade * 0.18), 2.0, true)

		# Sparse range ticks read as an instrument sweep without obscuring navigation.
		for index: int in range(24):
			var direction: Vector2 = Vector2.from_angle(index * TAU / 24.0)
			draw_line(direction * maxf(0.0, radius - 5.0), direction * radius, Color(0.7, 1.0, 0.9, fade * 0.65), 1.0, true)
