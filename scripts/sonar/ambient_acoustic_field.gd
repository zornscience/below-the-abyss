class_name AmbientAcousticField
extends Node2D
## Deterministic scheduled publication, sorted globally by deadline then source ID.

var _sources: Array[WeakRef] = []
var _clock: float = 0.0
var _advancing: bool = false


func bind_bus(bus: AcousticBus) -> Error:
	if _advancing:
		return ERR_BUSY
	if get_child_count() > 8:
		return ERR_INVALID_PARAMETER
	var prepared: Array[WeakRef] = []
	var newly_bound: Array[AmbientSoundEmitter] = []
	for child: Node in get_children():
		var source: AmbientSoundEmitter = child as AmbientSoundEmitter
		if source == null:
			for added: AmbientSoundEmitter in newly_bound:
				added.bind_bus(null)
			return ERR_INVALID_PARAMETER
		var previous: AcousticBus = source.emitter.get_bus()
		var result: Error = source.bind_bus(bus)
		if result != OK:
			for added: AmbientSoundEmitter in newly_bound:
				added.bind_bus(null)
			return result
		if previous == null and bus != null:
			newly_bound.append(source)
		prepared.append(weakref(source))
	_sources = prepared
	if bus == null:
		_sources.clear()
	return OK


func advance(delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0 or not is_finite(_clock + delta):
		return ERR_INVALID_PARAMETER
	if _advancing:
		return ERR_BUSY
	_advancing = true
	_clock += delta
	while true:
		var earliest: AmbientSoundEmitter = null
		for reference: WeakRef in _sources:
			var source: AmbientSoundEmitter = reference.get_ref() as AmbientSoundEmitter
			if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion():
				continue
			var time: float = source.next_event_time()
			if not is_finite(time) or time > _clock + 0.000000001:
				continue
			if earliest == null or time < earliest.next_event_time() \
				or (time == earliest.next_event_time() and String(source.source_id) < String(earliest.source_id)):
				earliest = source
		if earliest == null:
			break
		earliest.emit_next()
	_advancing = false
	return OK


func reset_session() -> Error:
	if _advancing:
		return ERR_BUSY
	_clock = 0.0
	for reference: WeakRef in _sources:
		var source: AmbientSoundEmitter = reference.get_ref() as AmbientSoundEmitter
		if is_instance_valid(source):
			source.reset_session()
	return OK
