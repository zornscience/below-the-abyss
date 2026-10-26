class_name AmbientSoundEmitter
extends Node2D
## Logical ambient source only. No audio assets, AI, interaction or discovery.

@export var source_id: StringName = &""
@export var session_id: StringName = &"shelf-ambient"
@export var configuration: AmbientEmissionProfile = AmbientEmissionProfile.new()
var _rules: AmbientEmissionProfile = AmbientEmissionProfile.new()
var _epoch: int = 0
var _count: int = 0
var _halted: bool = false
var last_result: Error = OK
@onready var emitter: AcousticEmitter = $AcousticEmitter


func _ready() -> void:
	emitter.source_id = source_id
	if configure(configuration) != OK:
		push_error("Invalid ambient acoustic profile.")


func configure(profile: AmbientEmissionProfile) -> Error:
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_rules = profile.duplicate() as AmbientEmissionProfile
	emitter.profile = _rules
	return OK


func bind_bus(bus: AcousticBus) -> Error:
	if not AcousticEvent.valid_token(session_id):
		return ERR_INVALID_PARAMETER
	return emitter.bind_bus(bus)


func next_event_time() -> float:
	if _halted or _count >= _rules.maximum_events or is_queued_for_deletion():
		return INF
	return _rules.first_delay + _count * _rules.interval_seconds


func emit_next() -> Error:
	if not is_finite(next_event_time()):
		return ERR_UNAVAILABLE
	var id: StringName = StringName("%s/%s/%d/%d" % [session_id, source_id, _epoch, _count + 1])
	last_result = emitter.emit_event(id, next_event_time())
	if last_result == OK:
		_count += 1
	else:
		_halted = true
	return last_result


func reset_session() -> void:
	_epoch += 1
	_count = 0
	_halted = false
	last_result = OK
