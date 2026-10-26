class_name AcousticContractExample
extends Node
## Text-only BTA-020 example. No sonar, reveal, AI, resource or audio behavior.

@export var quit_when_finished: bool = true
var deliveries: Array[StringName] = []
var result: Error = ERR_UNCONFIGURED


func _ready() -> void:
	var bus: AcousticBus = $AcousticBus
	var emitter: AcousticEmitter = $Emitter
	var near: AcousticReceiver = $Near
	var boundary: AcousticReceiver = $Boundary
	var far: AcousticReceiver = $Far
	var filtered: AcousticReceiver = $Filtered
	for receiver: AcousticReceiver in [near, boundary, far, filtered]:
		receiver.event_received.connect(_received.bind(receiver.receiver_id))
		if receiver.bind_bus(bus) != OK:
			_finish(ERR_INVALID_DATA)
			return
	if emitter.bind_bus(bus) != OK:
		_finish(ERR_INVALID_DATA)
		return
	var first: Error = emitter.emit_event(&"example-session/source-01/0001", 1.0)
	var duplicate: Error = emitter.emit_event(&"example-session/source-01/0001", 1.0)
	var valid: bool = first == OK and duplicate == ERR_ALREADY_EXISTS \
		and deliveries == [&"boundary", &"near"] and bus.history_count() == 1
	print("ACOUSTIC_EXAMPLE deliveries=%s duplicate=%s eligible=2 far=0 filtered=0" % [deliveries, error_string(duplicate)])
	_finish(OK if valid else ERR_INVALID_DATA)


func _received(_event: AcousticEvent, _strength: float, _distance: float, id: StringName) -> void:
	deliveries.append(id)


func _finish(value: Error) -> void:
	result = value
	if quit_when_finished:
		get_tree().quit(0 if value == OK else 1)
