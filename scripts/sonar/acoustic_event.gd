class_name AcousticEvent
extends RefCounted
## Value contract. Use create(); public properties are read-only views.
## Underscore fields are private by convention; the bus also snapshots per delivery.

var _event_id: StringName
var _source_id: StringName
var _event_type: StringName
var _classification: StringName
var _origin: Vector2
var _strength: float
var _range: float
var _simulation_time: float

var event_id: StringName:
	get: return _event_id
var source_id: StringName:
	get: return _source_id
var event_type: StringName:
	get: return _event_type
var classification: StringName:
	get: return _classification
var origin: Vector2:
	get: return _origin
var strength: float:
	get: return _strength
var range_units: float:
	get: return _range
var simulation_time: float:
	get: return _simulation_time


static func valid_token(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty() or text.length() > 128:
		return false
	for character: String in text:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./:-":
			return false
	return true


static func create(id: StringName, source: StringName, type: StringName,
		category: StringName, position: Vector2, signal_strength: float,
		maximum_range: float, timestamp: float) -> AcousticEvent:
	var event: AcousticEvent = AcousticEvent.new()
	event._event_id = id
	event._source_id = source
	event._event_type = type
	event._classification = category
	event._origin = position
	event._strength = signal_strength
	event._range = maximum_range
	event._simulation_time = timestamp
	return event if event.is_valid() else null


func is_valid() -> bool:
	return valid_token(event_id) and valid_token(source_id) and valid_token(event_type) \
		and valid_token(classification) and origin.is_finite() \
		and is_finite(strength) and strength >= 0.0 \
		and is_finite(range_units) and range_units >= 0.0 \
		and is_finite(simulation_time) and simulation_time >= 0.0


func snapshot() -> AcousticEvent:
	return create(event_id, source_id, event_type, classification, origin,
		strength, range_units, simulation_time)


func same_payload(other: AcousticEvent) -> bool:
	return other != null and event_id == other.event_id and source_id == other.source_id \
		and event_type == other.event_type and classification == other.classification \
		and origin == other.origin and strength == other.strength \
		and range_units == other.range_units and simulation_time == other.simulation_time
