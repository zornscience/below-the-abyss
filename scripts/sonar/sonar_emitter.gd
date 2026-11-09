class_name SonarEmitter
extends Node2D
## Active sonar composition. All eligibility comes from AcousticBus receipts.

signal pulse_emitted(event: AcousticEvent)
signal echo_revealed(event_id: StringName, target_id: StringName)
signal state_changed
@export var source_id: StringName = &"neris-01/sonar"
@export var session_id: StringName = &"shelf-playtest"
@export var configuration: ActiveSonarProfile = ActiveSonarProfile.new()
var _rules: ActiveSonarProfile = ActiveSonarProfile.new()
var _resources: SubmarineResourceSystem
var _effects: Node2D
var _listeners: Array[WeakRef] = []
var _pulses: Dictionary[StringName, WeakRef] = {}
var _time: float = 0.0
var _cooldown: float = 0.0
var _epoch: int = 0
var _sequence: int = 0
var _requesting: bool = false
var _advancing: bool = false
var _last_ping: StringName = &""
var _echo_count: int = 0
@onready var acoustic_emitter: AcousticEmitter = $AcousticEmitter


func _ready() -> void:
	acoustic_emitter.source_id = source_id
	if configure(configuration) != OK:
		push_error("Invalid active sonar profile.")


func configure(profile: ActiveSonarProfile) -> Error:
	if _requesting or _advancing:
		return ERR_BUSY
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_rules = profile.duplicate() as ActiveSonarProfile
	var emission: AcousticEmissionProfile = AcousticEmissionProfile.new()
	emission.event_type = &"active_sonar"
	emission.classification = &"scientific"
	emission.strength = _rules.signal_strength
	emission.range_units = _rules.maximum_radius
	acoustic_emitter.profile = emission
	state_changed.emit()
	return OK


func setup(bus: AcousticBus, resources: SubmarineResourceSystem, effects: Node2D) -> Error:
	if not is_instance_valid(bus) or not is_instance_valid(resources) or not is_instance_valid(effects) \
		or not effects.is_inside_tree() or not resources.is_inside_tree() \
		or not AcousticEvent.valid_token(source_id) or not AcousticEvent.valid_token(session_id):
		return ERR_INVALID_PARAMETER
	var result: Error = acoustic_emitter.bind_bus(bus)
	if result != OK:
		return result
	if is_instance_valid(_resources) and _resources.battery_changed.is_connected(_battery_changed):
		_resources.battery_changed.disconnect(_battery_changed)
	_resources = resources
	_effects = effects
	_resources.battery_changed.connect(_battery_changed)
	state_changed.emit()
	return OK


func listen_to(target: SonarRevealTarget) -> Error:
	if not is_instance_valid(target) or not target.is_inside_tree() \
		or not AcousticEvent.valid_token(target.target_id) \
		or target.receiver.get_bus() != acoustic_emitter.get_bus() or acoustic_emitter.get_bus() == null:
		return ERR_INVALID_PARAMETER
	for reference: WeakRef in _listeners:
		var existing: SonarRevealTarget = reference.get_ref() as SonarRevealTarget
		if existing == target:
			return OK
		if is_instance_valid(existing) and existing.target_id == target.target_id:
			return ERR_ALREADY_EXISTS
	target.reset_reveal(_time)
	_listeners.append(weakref(target))
	target.echo_received.connect(_echo_received)
	return OK


func next_event_id() -> StringName:
	return StringName("%s/%s/%d/%d" % [session_id, source_id, _epoch, _sequence + 1])


func _make_event(id: StringName) -> AcousticEvent:
	return AcousticEvent.create(id, acoustic_emitter.source_id, &"active_sonar", &"scientific",
		acoustic_emitter.global_position, _rules.signal_strength, _rules.maximum_radius, _time)


func availability(id: StringName = &"") -> Error:
	if _requesting or _advancing or _cooldown > 0.0 or active_pulse_count() >= _rules.maximum_active_pulses:
		return ERR_BUSY
	if not is_instance_valid(_resources) or not is_instance_valid(_effects) \
		or not _effects.is_inside_tree() or acoustic_emitter.get_bus() == null:
		return ERR_UNCONFIGURED
	if _resources.battery < _rules.battery_cost:
		return ERR_UNAVAILABLE
	return acoustic_emitter.get_bus().check_dispatch(acoustic_emitter, _make_event(id if id != &"" else next_event_id()))


func request_ping(id: StringName = &"") -> Error:
	var validation: Error = availability(id)
	if validation != OK:
		return validation
	var event: AcousticEvent = _make_event(id if id != &"" else next_event_id())
	if id == &"":
		_sequence += 1
	var pulse: SonarPulse = SonarPulse.new()
	if pulse.configure(event, _rules, acoustic_emitter.get_bus()) != OK:
		pulse.free()
		return ERR_INVALID_PARAMETER
	# Receivers synchronously offer eligible echoes during publish; the pending
	# pulse exists but is not in the scene and cannot reveal or draw yet.
	_pulses[event.event_id] = weakref(pulse)
	_requesting = true
	var result: Error = acoustic_emitter.publish(event, _resources.try_consume_battery.bind(_rules.battery_cost))
	if result != OK:
		_pulses.erase(event.event_id)
		pulse.free()
		_requesting = false
		state_changed.emit()
		return result
	_effects.add_child(pulse)
	pulse.global_position = event.origin
	pulse.target_revealed.connect(_target_revealed)
	_cooldown = _rules.cooldown_seconds
	_last_ping = event.event_id
	_echo_count = 0
	_requesting = false
	state_changed.emit()
	pulse_emitted.emit(event.snapshot())
	return OK


func _echo_received(target: SonarRevealTarget, event: AcousticEvent, distance: float) -> void:
	if _pulses.has(event.event_id):
		var pulse: SonarPulse = _pulses[event.event_id].get_ref() as SonarPulse
		if is_instance_valid(pulse) and not pulse.is_queued_for_deletion() and pulse.matches(event):
			pulse.schedule_reveal(target, distance)


func _target_revealed(event_id: StringName, target_id: StringName) -> void:
	if event_id == _last_ping:
		_echo_count += 1
		state_changed.emit()
	echo_revealed.emit(event_id, target_id)


func _battery_changed(_current: float, _maximum: float) -> void:
	state_changed.emit()


func advance(delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0 or not is_finite(_time + delta):
		return ERR_INVALID_PARAMETER
	if _advancing or _requesting:
		return ERR_BUSY
	_advancing = true
	_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown < SonarPulse.EPSILON:
		_cooldown = 0.0
	for index: int in range(_listeners.size() - 1, -1, -1):
		var target: SonarRevealTarget = _listeners[index].get_ref() as SonarRevealTarget
		if not is_instance_valid(target):
			_listeners.remove_at(index)
		elif target.is_inside_tree() and not target.is_queued_for_deletion():
			target.advance_to(_time)
	for id: StringName in _pulses.keys():
		var pulse: SonarPulse = _pulses[id].get_ref() as SonarPulse
		if not is_instance_valid(pulse) or pulse.is_queued_for_deletion():
			_pulses.erase(id)
		else:
			pulse.advance(delta)
	_advancing = false
	state_changed.emit()
	return OK


func active_pulse_count() -> int:
	var count: int = 0
	for reference: WeakRef in _pulses.values():
		var pulse: SonarPulse = reference.get_ref() as SonarPulse
		if is_instance_valid(pulse) and not pulse.is_queued_for_deletion():
			count += 1
	return count


func cooldown_remaining() -> float:
	return _cooldown


func battery_cost() -> float:
	return _rules.battery_cost


func status_text() -> String:
	if _cooldown > 0.0:
		return "COOLING %.1f s" % _cooldown
	match availability():
		OK: return "READY"
		ERR_UNAVAILABLE: return "LOW BATTERY"
		ERR_BUSY: return "BUSY"
		ERR_UNCONFIGURED: return "OFFLINE"
		_: return "BLOCKED"


func echo_count() -> int:
	return _echo_count


func reset_session() -> Error:
	if _requesting or _advancing:
		return ERR_BUSY
	_clear_pulses()
	for reference: WeakRef in _listeners:
		var target: SonarRevealTarget = reference.get_ref() as SonarRevealTarget
		if is_instance_valid(target):
			target.reset_reveal()
	_epoch += 1
	_sequence = 0
	_time = 0.0
	_cooldown = 0.0
	_last_ping = &""
	_echo_count = 0
	state_changed.emit()
	return OK


func _clear_pulses() -> void:
	for reference: WeakRef in _pulses.values():
		var pulse: SonarPulse = reference.get_ref() as SonarPulse
		if is_instance_valid(pulse) and not pulse.is_queued_for_deletion():
			pulse.queue_free()
	_pulses.clear()


func _exit_tree() -> void:
	_clear_pulses()
	for reference: WeakRef in _listeners:
		var target: SonarRevealTarget = reference.get_ref() as SonarRevealTarget
		if is_instance_valid(target) and target.echo_received.is_connected(_echo_received):
			target.reset_reveal()
			target.echo_received.disconnect(_echo_received)
	_listeners.clear()


func maximum_radius() -> float:
	return _rules.maximum_radius


func is_mutating() -> bool:
	return _requesting or _advancing


func restore_cooldown(seconds: float) -> Error:
	if not is_finite(seconds) or seconds < 0.0 or seconds > _rules.cooldown_seconds or is_mutating():
		return ERR_INVALID_PARAMETER
	_cooldown = seconds
	state_changed.emit()
	return OK


func pulse_speed(id: StringName) -> float:
	# Read the accepted pulse snapshot, never a subsequently reconfigured profile.
	var reference: WeakRef = _pulses.get(id)
	if reference==null: return 0.0
	var pulse: SonarPulse = reference.get_ref() as SonarPulse
	return pulse.travel_speed() if is_instance_valid(pulse) and not pulse.is_queued_for_deletion() else 0.0
