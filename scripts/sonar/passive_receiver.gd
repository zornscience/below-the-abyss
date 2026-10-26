class_name PassiveReceiver
extends Node2D
## Receive-only ambient contacts; no emitter, battery, active pulse or discovery API.

signal contacts_changed
@export var listener_id: StringName = &"neris-01/passive"
@export var configuration: PassiveSonarProfile = PassiveSonarProfile.new()
var _rules: PassiveSonarProfile = PassiveSonarProfile.new()
var _contacts: Dictionary[StringName, Dictionary] = {}
var _clock: float = 0.0
var _observed_bus: WeakRef
var _suspended: bool = false
@onready var receiver: AcousticReceiver = $AcousticReceiver


func _ready() -> void:
	receiver.receiver_id = listener_id
	receiver.event_received.connect(_received)
	if configure(configuration) != OK:
		push_error("Invalid passive sonar profile.")


func configure(profile: PassiveSonarProfile) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_rules = profile.duplicate(true) as PassiveSonarProfile
	receiver.profile = _rules
	_trim()
	contacts_changed.emit()
	return OK


func bind_bus(bus: AcousticBus) -> Error:
	var result: Error = receiver.bind_bus(bus)
	if result != OK:
		return result
	var previous: AcousticBus = _observed_bus.get_ref() as AcousticBus if _observed_bus != null else null
	if previous == bus:
		return OK
	if is_instance_valid(previous) and previous.source_removed.is_connected(_source_removed):
		previous.source_removed.disconnect(_source_removed)
	_observed_bus = weakref(bus) if bus != null else null
	if bus != null:
		bus.source_removed.connect(_source_removed)
	_contacts.clear()
	contacts_changed.emit()
	return OK


func set_suspended(value: bool) -> void:
	_suspended = value
	receiver.enabled = not value
	contacts_changed.emit()


func status_text() -> String:
	if receiver.get_bus() == null:
		return "OFFLINE"
	return "PAUSED" if _suspended else "LISTENING"


func _received(event: AcousticEvent, strength: float, distance: float) -> void:
	if _suspended or event == null or not event.is_valid() or event.event_type != &"ambient":
		return
	var bus: AcousticBus = receiver.get_bus()
	if bus == null or bus.get_emitter(event.source_id) == null:
		return
	var expiry: float = event.simulation_time + _rules.contact_seconds
	if not is_finite(expiry) or expiry <= _clock + 0.000000001:
		return
	if _contacts.has(event.source_id):
		var existing: Dictionary = _contacts[event.source_id]
		if existing.event_id == event.event_id or existing.timestamp > event.simulation_time:
			return
	_contacts[event.source_id] = {"event_id": event.event_id, "source_id": event.source_id,
		"classification": event.classification, "origin": event.origin,
		"timestamp": event.simulation_time, "expires_at": expiry,
		"signal_strength": _rules.approximate_strength(event, strength, distance)}
	_trim()
	contacts_changed.emit()


func _ordered() -> Array[Dictionary]:
	var values: Array[Dictionary] = _contacts.values()
	values.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left.signal_strength > right.signal_strength if left.signal_strength != right.signal_strength \
			else String(left.source_id) < String(right.source_id))
	return values


func _trim() -> void:
	var values: Array[Dictionary] = _ordered()
	for index: int in range(_rules.maximum_contacts, values.size()):
		_contacts.erase(values[index].source_id)


func _source_removed(source_id: StringName) -> void:
	if _contacts.erase(source_id):
		contacts_changed.emit()


func advance(delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0 or not is_finite(_clock + delta):
		return ERR_INVALID_PARAMETER
	if _suspended:
		return OK
	_clock += delta
	var bus: AcousticBus = receiver.get_bus()
	for source_id: StringName in _contacts.keys():
		if not _contacts.has(source_id):
			continue
		if _contacts[source_id].expires_at <= _clock + 0.000000001 \
			or bus == null or bus.get_emitter(source_id) == null:
			_contacts.erase(source_id)
	contacts_changed.emit()
	return OK


func contacts_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for contact: Dictionary in _ordered():
		var dx: float = float(contact.origin.x) - float(receiver.global_position.x)
		var dy: float = float(contact.origin.y) - float(receiver.global_position.y)
		var bearing: float = 0.0 if dx == 0.0 and dy == 0.0 else wrapf(rad_to_deg(atan2(dy, dx) - receiver.global_rotation), -180.0, 180.0)
		bearing = wrapf(roundf(bearing / _rules.bearing_quantum_degrees) * _rules.bearing_quantum_degrees, -180.0, 180.0)
		if is_zero_approx(bearing):
			bearing = 0.0
		result.append({"source_id": contact.source_id, "event_id": contact.event_id,
			"classification": contact.classification, "bearing_degrees": bearing,
			"signal_strength": contact.signal_strength, "expires_at": contact.expires_at,
			"remaining_seconds": maxf(0.0, contact.expires_at - _clock)})
	return result


func reset_session() -> void:
	_contacts.clear()
	_clock = 0.0
	contacts_changed.emit()


func _exit_tree() -> void:
	var bus: AcousticBus = _observed_bus.get_ref() as AcousticBus if _observed_bus != null else null
	if is_instance_valid(bus) and bus.source_removed.is_connected(_source_removed):
		bus.source_removed.disconnect(_source_removed)
	_contacts.clear()
	contacts_changed.emit()
