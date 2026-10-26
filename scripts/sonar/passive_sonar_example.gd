class_name PassiveSonarExample
extends Node
## Text-only contract demonstration, independent of the playable region.

@export var quit_when_finished: bool = true
var result: Error = ERR_UNCONFIGURED


func _ready() -> void:
	var bus: AcousticBus = AcousticBus.new()
	add_child(bus)
	var battery: SubmarineResourceSystem = SubmarineResourceSystem.new()
	add_child(battery)
	var listener: PassiveReceiver = preload("res://scenes/player/passive_receiver.tscn").instantiate() as PassiveReceiver
	add_child(listener)
	listener.bind_bus(bus)
	var field: AmbientAcousticField = AmbientAcousticField.new()
	add_child(field)
	var source: AmbientSoundEmitter = AmbientSoundEmitter.new()
	source.source_id = &"example-machinery"
	source.position = Vector2(400, 0)
	var emitter: AcousticEmitter = AcousticEmitter.new()
	emitter.name = "AcousticEmitter"
	source.add_child(emitter)
	field.add_child(source)
	var profile: AmbientEmissionProfile = AmbientEmissionProfile.new()
	profile.first_delay = 1.0
	profile.maximum_events = 1
	profile.range_units = 1000.0
	source.configure(profile)
	field.bind_bus(bus)
	field.advance(1.0)
	listener.advance(1.0)
	var contacts: Array[Dictionary] = listener.contacts_snapshot()
	var valid: bool = contacts.size() == 1 and battery.battery == 100.0 and bus.history_count() == 1
	if valid:
		valid = contacts[0].classification == &"mechanical" and contacts[0].bearing_degrees == 0.0 \
			and is_equal_approx(contacts[0].signal_strength, 0.6)
		print("PASSIVE_EXAMPLE classification=mechanical bearing=0 signal=60% contacts=1 battery=100 active_pings=0")
	listener.advance(8.0)
	valid = valid and listener.contacts_snapshot().is_empty()
	print("PASSIVE_EXAMPLE expired_contacts=%d" % listener.contacts_snapshot().size())
	result = OK if valid else ERR_INVALID_DATA
	if quit_when_finished:
		get_tree().quit(0 if result == OK else 1)
