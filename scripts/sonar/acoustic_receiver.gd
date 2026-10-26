class_name AcousticReceiver
extends Node2D
## Signal-only endpoint; owns no detection, reveal, listening UI or AI rules.

signal event_received(event: AcousticEvent, received_strength: float, distance_units: float)
@export var receiver_id: StringName = &""
@export var profile: AcousticReceiverProfile = AcousticReceiverProfile.new()
@export var enabled: bool = true
var _bus: WeakRef


func get_bus() -> AcousticBus:
	return _bus.get_ref() as AcousticBus if _bus != null else null


func bind_bus(bus: AcousticBus) -> Error:
	if bus == null:
		var current: AcousticBus = get_bus()
		return current.unregister_receiver(self) if current != null else OK
	return bus.register_receiver(self)
