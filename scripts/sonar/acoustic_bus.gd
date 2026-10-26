class_name AcousticBus
extends Node
## Synchronous, main-thread, scene-owned dispatch. No singleton or simulation clock.

signal event_dispatched(event_id: StringName, delivery_count: int)
signal source_removed(source_id: StringName)
@export var configuration: AcousticDispatchProfile = AcousticDispatchProfile.new()
var _rules: AcousticDispatchProfile = AcousticDispatchProfile.new()
var _emitters: Dictionary[StringName, Dictionary] = {}
var _receivers: Dictionary[StringName, Dictionary] = {}
var _history: Dictionary[StringName, AcousticEvent] = {}
var _serial: int = 0
var _dispatching: bool = false


func _ready() -> void:
	if configure(configuration) != OK:
		push_error("Invalid acoustic dispatch profile.")


func configure(profile: AcousticDispatchProfile) -> Error:
	if _dispatching:
		return ERR_BUSY
	if profile == null or not profile.is_valid() or profile.maximum_event_history < _history.size():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_rules = profile.duplicate() as AcousticDispatchProfile
	return OK


func register_emitter(emitter: AcousticEmitter) -> Error:
	if not is_instance_valid(emitter) or not AcousticEvent.valid_token(emitter.source_id) \
		or emitter.profile == null or not emitter.profile.is_valid():
		return ERR_INVALID_PARAMETER
	return _register(emitter.source_id, emitter, _emitters)


func register_receiver(receiver: AcousticReceiver) -> Error:
	if not is_instance_valid(receiver) or not AcousticEvent.valid_token(receiver.receiver_id) \
		or receiver.profile == null or not receiver.profile.is_valid():
		return ERR_INVALID_PARAMETER
	return _register(receiver.receiver_id, receiver, _receivers)


func _register(id: StringName, endpoint: Node2D, registry: Dictionary[StringName, Dictionary]) -> Error:
	if not is_inside_tree() or is_queued_for_deletion() or not endpoint.is_inside_tree() or endpoint.is_queued_for_deletion() \
		or endpoint.get_tree() != get_tree():
		return ERR_UNCONFIGURED
	_prune(registry)
	if endpoint.get_bus() != null and endpoint.get_bus() != self:
		return ERR_ALREADY_IN_USE
	if registry.has(id):
		return OK if registry[id]["node"].get_ref() == endpoint else ERR_ALREADY_EXISTS
	# Identity is immutable while bound; no aliases for the same endpoint.
	for record: Dictionary in registry.values():
		if record["node"].get_ref() == endpoint:
			return ERR_ALREADY_IN_USE
	_serial += 1
	var exiting: Callable = _remove.bind(id, _serial, registry)
	registry[id] = {"node": weakref(endpoint), "serial": _serial, "exiting": exiting,
		"source": endpoint is AcousticEmitter}
	endpoint.tree_exiting.connect(exiting, CONNECT_ONE_SHOT)
	endpoint.set("_bus", weakref(self))
	return OK


func unregister_emitter(emitter: AcousticEmitter) -> Error:
	return _unregister(emitter, _emitters)


func unregister_receiver(receiver: AcousticReceiver) -> Error:
	return _unregister(receiver, _receivers)


func _unregister(endpoint: Node2D, registry: Dictionary[StringName, Dictionary]) -> Error:
	if not is_instance_valid(endpoint):
		return ERR_INVALID_PARAMETER
	for id: StringName in registry.keys():
		if registry[id]["node"].get_ref() == endpoint:
			_remove(id, registry[id]["serial"], registry)
			return OK
	return ERR_DOES_NOT_EXIST


func _remove(id: StringName, serial: int, registry: Dictionary[StringName, Dictionary]) -> void:
	if not registry.has(id) or registry[id]["serial"] != serial:
		return
	var record: Dictionary = registry[id]
	var endpoint: Node2D = record["node"].get_ref() as Node2D
	if is_instance_valid(endpoint):
		if endpoint.tree_exiting.is_connected(record["exiting"]):
			endpoint.tree_exiting.disconnect(record["exiting"])
		if endpoint.get_bus() == self:
			endpoint.set("_bus", null)
	registry.erase(id)
	if record["source"]:
		source_removed.emit(id)


func _prune(registry: Dictionary[StringName, Dictionary]) -> void:
	for id: StringName in registry.keys():
		var endpoint: Node2D = registry[id]["node"].get_ref() as Node2D
		if not is_instance_valid(endpoint) or not endpoint.is_inside_tree() or endpoint.is_queued_for_deletion():
			_remove(id, registry[id]["serial"], registry)


func emitter_count() -> int:
	_prune(_emitters)
	return _emitters.size()


func receiver_count() -> int:
	_prune(_receivers)
	return _receivers.size()


func history_count() -> int:
	return _history.size()


func get_emitter(source_id: StringName) -> AcousticEmitter:
	_prune(_emitters)
	return _emitters[source_id]["node"].get_ref() as AcousticEmitter if _emitters.has(source_id) else null


func check_dispatch(emitter: AcousticEmitter, event: AcousticEvent) -> Error:
	if _dispatching:
		return ERR_BUSY
	if event == null or not event.is_valid() or not is_instance_valid(emitter):
		return ERR_INVALID_PARAMETER
	_prune(_emitters)
	_prune(_receivers)
	if not is_inside_tree() or is_queued_for_deletion() or not _emitters.has(event.source_id) \
		or _emitters[event.source_id]["node"].get_ref() != emitter or emitter.source_id != event.source_id:
		return ERR_UNCONFIGURED
	if _history.has(event.event_id):
		return ERR_ALREADY_EXISTS if _history[event.event_id].same_payload(event) else ERR_INVALID_DATA
	if _history.size() >= _rules.maximum_event_history:
		return ERR_OUT_OF_MEMORY
	return OK


func dispatch(emitter: AcousticEmitter, event: AcousticEvent, acceptance: Callable = Callable()) -> Error:
	var validation: Error = check_dispatch(emitter, event)
	if validation != OK:
		return validation
	if not acceptance.is_null() and not acceptance.is_valid():
		return ERR_INVALID_PARAMETER
	var frozen: AcousticEvent = event.snapshot()
	_dispatching = true
	# Optional atomic producer gate (e.g. try_consume_battery). It runs only after
	# validation/dedup/capacity, under the existing reentrancy lock, before history.
	if not acceptance.is_null():
		var accepted: Variant = acceptance.call()
		if not accepted is bool or not accepted:
			_dispatching = false
			return ERR_UNAVAILABLE
	# Record before any callback: duplicate IDs cannot reenter this event.
	_history[frozen.event_id] = frozen.snapshot()
	var deliveries: Array[Dictionary] = []
	var ids: Array[StringName] = _receivers.keys()
	ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for id: StringName in ids:
		var receiver: AcousticReceiver = _receivers[id]["node"].get_ref() as AcousticReceiver
		if receiver.receiver_id != id or not receiver.enabled or receiver.profile == null \
			or not receiver.profile.is_valid() or not receiver.global_position.is_finite():
			continue
		var rules: AcousticReceiverProfile = receiver.profile.duplicate(true) as AcousticReceiverProfile
		if not rules.accepts(frozen):
			continue
		# Explicit double intermediates avoid Vector2 float32 distance overflow.
		var dx: float = float(receiver.global_position.x) - float(frozen.origin.x)
		var dy: float = float(receiver.global_position.y) - float(frozen.origin.y)
		var distance: float = sqrt(dx * dx + dy * dy)
		if distance > minf(frozen.range_units, rules.maximum_range_units):
			continue
		var strength: float = _rules.received_strength(frozen, distance)
		if strength >= rules.minimum_strength:
			deliveries.append({"id": id, "serial": _receivers[id]["serial"],
				"node": weakref(receiver), "strength": strength, "distance": distance})
	var count: int = 0
	for delivery: Dictionary in deliveries:
		if is_queued_for_deletion() or not is_inside_tree():
			break
		var receiver: AcousticReceiver = delivery["node"].get_ref() as AcousticReceiver
		if not is_instance_valid(receiver) or receiver.is_queued_for_deletion() or not receiver.is_inside_tree() \
			or not _receivers.has(delivery["id"]) \
			or receiver.receiver_id != delivery["id"] \
			or _receivers[delivery["id"]]["serial"] != delivery["serial"]:
			continue
		count += 1
		receiver.event_received.emit(frozen.snapshot(), delivery["strength"], delivery["distance"])
	event_dispatched.emit(frozen.event_id, count)
	_dispatching = false
	return OK


func _exit_tree() -> void:
	for registry: Dictionary[StringName, Dictionary] in [_emitters, _receivers]:
		for id: StringName in registry.keys():
			_remove(id, registry[id]["serial"], registry)
