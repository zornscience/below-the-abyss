class_name PassiveTestRig
extends Node

const LISTENER: PackedScene = preload("res://scenes/player/passive_receiver.tscn")
var bus: AcousticBus
var listener: PassiveReceiver
var field: AmbientAcousticField


func _ready() -> void:
	bus = AcousticBus.new()
	add_child(bus)
	listener = LISTENER.instantiate() as PassiveReceiver
	add_child(listener)
	assert(listener.bind_bus(bus) == OK)
	field = AmbientAcousticField.new()
	add_child(field)


func emitter(id: StringName, position: Vector2 = Vector2.ZERO) -> AcousticEmitter:
	var source: AcousticEmitter = AcousticEmitter.new()
	source.source_id = id
	source.position = position
	source.profile.event_type = &"ambient"
	source.profile.strength = 1.0
	source.profile.range_units = 1000.0
	add_child(source)
	assert(source.bind_bus(bus) == OK)
	return source


func ambient(id: StringName, position: Vector2, first: float = 1.0,
		interval: float = 3.0, budget: int = 4) -> AmbientSoundEmitter:
	var source: AmbientSoundEmitter = AmbientSoundEmitter.new()
	source.source_id = id
	source.position = position
	var emission: AcousticEmitter = AcousticEmitter.new()
	emission.name = "AcousticEmitter"
	source.add_child(emission)
	field.add_child(source)
	var profile: AmbientEmissionProfile = AmbientEmissionProfile.new()
	profile.first_delay = first
	profile.interval_seconds = interval
	profile.maximum_events = budget
	profile.range_units = 1000.0
	assert(source.configure(profile) == OK)
	return source


func step(delta: float) -> void:
	assert(field.advance(delta) == OK)
	assert(listener.advance(delta) == OK)
