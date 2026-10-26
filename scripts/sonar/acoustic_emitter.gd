class_name AcousticEmitter
extends Node2D
## Explicitly bind to a scene-owned bus after both nodes enter the tree.

signal event_emitted(event: AcousticEvent)
@export var source_id: StringName = &""
@export var profile: AcousticEmissionProfile = AcousticEmissionProfile.new()
var _bus: WeakRef


func get_bus() -> AcousticBus:
	return _bus.get_ref() as AcousticBus if _bus != null else null


func bind_bus(bus: AcousticBus) -> Error:
	if bus == null:
		var current: AcousticBus = get_bus()
		return current.unregister_emitter(self) if current != null else OK
	return bus.register_emitter(self)


func emit_event(event_id: StringName, simulation_time: float) -> Error:
	var bus: AcousticBus = get_bus()
	if bus == null:
		return ERR_UNCONFIGURED
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	var event: AcousticEvent = AcousticEvent.create(event_id, source_id, profile.event_type,
		profile.classification, global_position, profile.strength, profile.range_units, simulation_time)
	if event == null:
		return ERR_INVALID_PARAMETER
	return publish(event)


func publish(event: AcousticEvent, acceptance: Callable = Callable()) -> Error:
	var bus: AcousticBus = get_bus()
	if bus == null:
		return ERR_UNCONFIGURED
	# Preserve emitted metadata even if a consumer modifies the caller's object.
	var snapshot: AcousticEvent = event.snapshot() if event != null and event.is_valid() else null
	var result: Error = bus.dispatch(self, snapshot, acceptance)
	if result == OK:
		event_emitted.emit(snapshot.snapshot())
	return result
