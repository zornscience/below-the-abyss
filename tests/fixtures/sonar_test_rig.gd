class_name SonarTestRig
extends Node

const TARGET: PackedScene = preload("res://scenes/props/sonar_reveal_target.tscn")
var bus: AcousticBus
var resources: SubmarineResourceSystem
var effects: Node2D
var sonar: SonarEmitter


func _ready() -> void:
	bus = AcousticBus.new()
	add_child(bus)
	resources = SubmarineResourceSystem.new()
	add_child(resources)
	effects = Node2D.new()
	add_child(effects)
	sonar = SonarEmitter.new()
	sonar.source_id = &"test-vessel/sonar"
	sonar.session_id = &"sonar-tests"
	var acoustic: AcousticEmitter = AcousticEmitter.new()
	acoustic.name = "AcousticEmitter"
	sonar.add_child(acoustic)
	add_child(sonar)
	var profile: ActiveSonarProfile = ActiveSonarProfile.new()
	profile.maximum_radius = 100.0
	profile.travel_speed = 100.0
	profile.reveal_seconds = 2.0
	assert(sonar.configure(profile) == OK)
	assert(sonar.setup(bus, resources, effects) == OK)


func target(id: StringName, position: Vector2) -> SonarRevealTarget:
	var result: SonarRevealTarget = TARGET.instantiate() as SonarRevealTarget
	result.target_id = id
	result.position = position
	add_child(result)
	assert(result.bind_bus(bus) == OK)
	assert(sonar.listen_to(result) == OK)
	return result
