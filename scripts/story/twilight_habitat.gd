class_name TwilightHabitat
extends Node
## Scene-owned fauna/thermal ecology. Existing AI, dispatcher, hull and pause APIs only.
const VENT_SITES: Array[Vector2] = [Vector2(29500,3880),Vector2(36000,3490)]
const VENT_IDS: Array[StringName] = [&"twilight-west-vent",&"twilight-east-vent"]
var scene: ShelfPrototype
var layout: TwilightShelfLayout
var vents: Array[ThermalVent] = []
var fauna: Array[AcousticCreature] = []
var ambient: AmbientAcousticField
var dressing: TwilightDressing
var enabled: bool = false
func setup(game: ShelfPrototype,world: TwilightShelfLayout) -> void:
	scene = game
	layout = world
	dressing = TwilightDressing.new()
	layout.add_child(dressing)
	dressing.setup(game,world)
	ambient = AmbientAcousticField.new()
	layout.add_child(ambient)
	for index: int in range(VENT_SITES.size()):
		var vent: ThermalVent = ThermalVent.new()
		vent.stable_id = VENT_IDS[index]
		vent.position = VENT_SITES[index]
		layout.add_child(vent)
		_require(vent.setup(scene))
		vent.damage_applied.connect(scene.hud.show_thermal_damage)
		vents.append(vent)
		_add_source(VENT_IDS[index],VENT_SITES[index]-Vector2(0,300),&"geological",12.0)
	_make_fauna()
	_add_source(&"twilight-jelly-drift",Vector2(37900,1800),&"marine_life",17.0)
	_require(ambient.bind_bus(scene.get_node("AcousticBus") as AcousticBus))
	scene.submarine.simulation_enabled_changed.connect(_simulation)
	scene.saves.checkpoint_restored.connect(reset_session)
	scene.settings.settings_changed.connect(_preferences)
	set_enabled(false)
func _add_source(id: StringName,at: Vector2,kind: StringName,interval: float) -> void:
	var source: AmbientSoundEmitter = AmbientSoundEmitter.new()
	source.source_id = id
	source.session_id = &"twilight-ecology"
	source.position = at
	source.configuration = AmbientEmissionProfile.new()
	source.configuration.classification = kind
	source.configuration.interval_seconds = interval
	source.configuration.maximum_events = 256
	source.configuration.range_units = 1100
	source.configuration.strength = 55
	var emitter: AcousticEmitter = AcousticEmitter.new()
	emitter.name = "AcousticEmitter"
	source.add_child(emitter)
	ambient.add_child(source)
func _make_fauna() -> void:
	var bounds: Array[Rect2] = [Rect2(28300,1300,1500,700),Rect2(33500,2670,1500,550),Rect2(37400,1600,1100,400)]
	for index: int in range(bounds.size()):
		var profile: CreatureProfile = CreatureProfile.new()
		profile.navigation_bounds = bounds[index]
		profile.grid_spacing = 80
		profile.patrol_speed = [55.0,48.0,22.0][index]
		profile.investigate_speed = profile.patrol_speed*1.4
		profile.body_radius = 18
		profile.patrol_points = PackedVector2Array([bounds[index].position+Vector2(150,140),bounds[index].end-Vector2(150,140)])
		profile.event_priorities = {&"active_sonar":20,&"explosion":30}
		profile.hearing.accepted_event_types = [&"active_sonar",&"explosion"]
		var animal: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
		animal.creature_id = StringName(["twilight-eel","twilight-squid","twilight-jelly"][index])
		animal.configuration = profile
		animal.position = profile.patrol_points[0]
		animal.damageable = true
		layout.add_child(animal)
		(animal.get_node("StateCaption") as Label).hide()
		_require(animal.bind_bus(scene.get_node("AcousticBus") as AcousticBus))
		var paint: TwilightFaunaPaint = TwilightFaunaPaint.new()
		animal.add_child(paint)
		paint.setup(animal,scene,index)
		var receiver: BlastReceiver = BlastReceiver.new()
		animal.add_child(receiver)
		receiver.setup(animal)
		scene.torpedoes._receivers.append(receiver)
		fauna.append(animal)
func set_enabled(value: bool) -> void:
	var changed: bool = enabled!=value
	enabled = value
	for vent: ThermalVent in vents: vent.enabled = value
	dressing.set_enabled(value)
	if changed: reset_session()
	_simulation(scene.submarine.is_physics_processing())
func _simulation(simulating: bool) -> void:
	for animal: AcousticCreature in fauna:
		animal.set_suspended(not enabled or not simulating)
		animal.visible = enabled and not animal._destroyed
		animal.collision_layer = 8 if enabled and not animal._destroyed else 0
func reset_session() -> void:
	for vent: ThermalVent in vents: vent.reset_session()
	for animal: AcousticCreature in fauna:
		animal.reset_session()
		for child: Node in animal.get_children():
			if child is BlastReceiver: (child as BlastReceiver).reset_session()
	ambient.reset_session()
	dressing.reset_session()
	_simulation(scene.submarine.is_physics_processing())
func _preferences() -> void:
	for vent: ThermalVent in vents: vent.refresh_visuals()
func hazard_prompt() -> String:
	var nearest: ThermalVent
	for vent: ThermalVent in vents:
		if vent.prompt(scene.submarine.global_position).is_empty(): continue
		if nearest==null or vent.global_position.distance_to(scene.submarine.global_position)<nearest.global_position.distance_to(scene.submarine.global_position): nearest = vent
	return nearest.prompt(scene.submarine.global_position) if nearest!=null else ""
func unsafe_at(at: Vector2) -> bool:
	for vent: ThermalVent in vents:
		if vent.danger_at(at): return true
	return false
func _physics_process(delta: float) -> void:
	if not enabled or not scene.submarine.is_physics_processing(): return
	for vent: ThermalVent in vents: vent.advance(delta)
	ambient.advance(delta)
	dressing.advance(delta)

func _require(result: Error) -> void:
	if result!=OK: push_error("Invalid authored Twilight habitat: "+error_string(result))
