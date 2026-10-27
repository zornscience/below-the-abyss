extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
const CREATURE: PackedScene = preload("res://scenes/creatures/acoustic_creature.tscn")
var _scene: ShelfPrototype
var _paths: Array[String] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = MAIN.instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta030-%d.json" % Time.get_ticks_usec()
	_paths.append(_scene.settings_path + ".discoveries.json")
	_paths.append(_scene.settings_path + ".research.json")
	add_child_autofree(_scene)
	await _frames(2)


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	InputBindings.apply(InputBindings.defaults(), 0.25)
	for path: String in _paths:
		for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_paths.clear()


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _emitter(id: StringName, position: Vector2, type: StringName = &"ambient", strength: float = 1.0, maximum_range: float = 650.0) -> AcousticEmitter:
	var emitter: AcousticEmitter = AcousticEmitter.new()
	emitter.source_id = id
	emitter.profile.event_type = type
	emitter.profile.classification = &"mechanical"
	emitter.profile.strength = strength
	emitter.profile.range_units = maximum_range
	_scene.region.add_child(emitter)
	emitter.position = position
	assert_eq(emitter.bind_bus(_scene.get_node("AcousticBus") as AcousticBus), OK)
	return emitter


func test_player_ping_drives_existing_receiver_without_creature_emission_or_damage() -> void:
	_scene.submarine.global_position = Vector2(1400, 400)
	_scene.resume_route()
	watch_signals(_scene.submarine.hull_system)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	await _frames(4)
	assert_eq(_scene.creature.brain.state, CreatureState.State.INVESTIGATE)
	assert_eq(_scene.creature.brain.destination(), Vector2(1400, 400))
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.creature.collision_layer, 0)
	assert_eq(_scene.creature.collision_mask, 1)
	assert_eq(_scene.submarine.collision_mask & _scene.creature.collision_layer, 0)
	_scene.submarine.global_position = Vector2(1450, 410)
	assert_null(_scene.submarine.move_and_collide(Vector2(90, 0)), "Vessel can sweep through the harmless creature.")
	assert_almost_eq(_scene.submarine.global_position.x, 1540.0, 0.01)


func test_passive_listening_produces_no_reaction_and_optional_ambient_event_can_investigate() -> void:
	_scene.resume_route()
	await _frames(190)
	assert_false(_scene.submarine.passive.contacts_snapshot().is_empty())
	assert_eq(_scene.creature.brain.state, CreatureState.State.PATROL)
	var emitter: AcousticEmitter = _emitter(&"test-geology", Vector2(1460, 400))
	assert_eq(emitter.emit_event(&"controlled/ambient", 190.0 / 60.0), OK)
	await _frames(3)
	assert_eq(_scene.creature.brain.state, CreatureState.State.INVESTIGATE)


func test_dispatch_filters_duplicates_and_restart_retains_bounded_bus_history() -> void:
	_scene.resume_route()
	var bus: AcousticBus = _scene.get_node("AcousticBus") as AcousticBus
	var far: AcousticEmitter = _emitter(&"far", Vector2(1460, 400), &"ambient", 1.0, 1.0)
	var weak: AcousticEmitter = _emitter(&"weak", Vector2(1460, 400), &"ambient", 0.1)
	var wrong: AcousticEmitter = _emitter(&"wrong", Vector2(1460, 400), &"passive_listening")
	for emitter: AcousticEmitter in [far, weak, wrong]:
		assert_eq(emitter.emit_event(StringName("filtered/" + String(emitter.source_id)), 0.0), OK)
	await _frames(2)
	assert_eq(_scene.creature.brain.state, CreatureState.State.PATROL)
	var eligible: AcousticEmitter = _emitter(&"eligible", Vector2(1460, 400))
	assert_eq(eligible.emit_event(&"once", 0.0), OK)
	assert_eq(eligible.emit_event(&"once", 0.0), ERR_ALREADY_EXISTS)
	await _frames(2)
	assert_eq(_scene.creature.brain.snapshot().event_id, &"once")
	var count: int = bus.history_count()
	_scene.restart_route()
	_scene.open_route_menu()
	assert_eq(bus.history_count(), count)
	assert_eq(eligible.emit_event(&"once", 0.0), ERR_ALREADY_EXISTS)
	assert_eq(_scene.creature.brain.state, CreatureState.State.PATROL)
	var profile: AcousticDispatchProfile = AcousticDispatchProfile.new()
	profile.maximum_event_history = count
	assert_eq(bus.configure(profile), OK)
	assert_eq(eligible.emit_event(&"capacity", 0.0), ERR_OUT_OF_MEMORY)
	assert_eq(bus.history_count(), count)


func test_all_existing_modal_and_debug_pauses_freeze_creature_and_ignore_sounds() -> void:
	_scene.submarine.global_position = Vector2(1400, 400)
	_scene.resume_route()
	_scene.submarine.sonar.request_ping()
	await _frames(4)
	for mode: int in range(5):
		match mode:
			0: _scene.open_route_menu()
			1: _scene.open_settings()
			2: _scene.open_map()
			3:
				_scene.open_map()
				_scene.open_research()
			4: _scene.resource_panel.focus_test_controls()
		var position: Vector2 = _scene.creature.position
		var state: Dictionary = _scene.creature.brain.snapshot()
		await _frames(10)
		assert_eq(_scene.creature.position, position)
		assert_eq(_scene.creature.brain.snapshot(), state)
		assert_false(_scene.creature.receiver.enabled)
		match mode:
			0: _scene.resume_route()
			1: _scene.close_settings()
			2: _scene.close_map()
			3:
				_scene.close_research()
				_scene.close_map()
			4: (_scene.resource_panel.get_node("%Pilot") as Button).pressed.emit()
		assert_true(_scene.creature.receiver.enabled)


func test_navigation_routes_around_pillar_and_checks_every_edge_against_terrain() -> void:
	var creature: AcousticCreature = _scene.creature
	assert_eq(creature.navigation.build(creature.configuration, _scene.region), OK)
	var path: PackedVector2Array = creature.navigation.route(Vector2(1510, 380), Vector2(1860, 380))
	assert_gt(path.size(), 1, "Direct line crosses the solid overlook pillar.")
	var previous: Vector2 = Vector2(1510, 380)
	for point: Vector2 in path:
		assert_true(creature.navigation.segment_clear(previous, point))
		assert_true(creature.configuration.center_bounds().has_point(point))
		previous = point
	assert_true(creature.navigation.route(Vector2(1510, 380), Vector2(1700, 360)).is_empty(), "Solid destinations fail closed.")
	assert_true(creature.navigation.route(Vector2(1510, 380), Vector2(2500, 480)).is_empty(), "Never leave the bounded optional area.")


func test_unreachable_solid_sound_destination_returns_without_wall_penetration() -> void:
	var creature: AcousticCreature = _scene.creature
	creature.set_physics_process(false)
	creature.set_suspended(false)
	var emitter: AcousticEmitter = _emitter(&"inside-rock", Vector2(1700, 360))
	assert_eq(emitter.emit_event(&"blocked-sound", 0.0), OK)
	var start: Vector2 = creature.position
	for _step: int in range(60):
		assert_eq(creature.advance_simulation(1.0 / 30.0), OK)
	assert_eq(creature.brain.state, CreatureState.State.PATROL)
	assert_true(creature.navigation.clear(creature.position))
	assert_lt(creature.position.distance_to(start), 100.0)


func test_controller_motion_and_state_are_equivalent_at_30_60_120_steps() -> void:
	var expected: Dictionary = {}
	for rate: int in [30, 60, 120]:
		var creature: AcousticCreature = CREATURE.instantiate() as AcousticCreature
		creature.creature_id = StringName("consistency-%d" % rate)
		creature.position = Vector2(1510, 420)
		_scene.region.add_child(creature)
		creature.set_physics_process(false)
		creature.set_suspended(false)
		var event: AcousticEvent = AcousticEvent.create(&"consistent", &"player", &"active_sonar", &"player", Vector2(1400, 400), 1.0, 900.0, 0.0)
		creature.brain.offer(event, 1.0, 110.0, event.origin)
		for _step: int in range(rate * 8):
			assert_eq(creature.advance_simulation(1.0 / rate), OK)
			assert_true(creature.configuration.center_bounds().has_point(creature.position))
		if expected.is_empty():
			expected = {"position": creature.position, "state": creature.brain.state, "index": creature.brain.patrol_index}
		else:
			assert_almost_eq(creature.position.x, expected.position.x, 0.01)
			assert_almost_eq(creature.position.y, expected.position.y, 0.01)
			assert_eq(creature.brain.state, expected.state)
			assert_eq(creature.brain.patrol_index, expected.index)
		creature.queue_free()


func test_receiver_lifecycle_cleanup_does_not_change_history() -> void:
	var bus: AcousticBus = _scene.get_node("AcousticBus") as AcousticBus
	var count: int = bus.receiver_count()
	var history: int = bus.history_count()
	_scene.creature.free()
	assert_eq(bus.receiver_count(), count - 1)
	assert_eq(bus.history_count(), history)


func test_actual_motion_routes_around_pillar_and_recovers_patrol_without_position_jumps() -> void:
	var creature: AcousticCreature = _scene.creature
	creature.set_physics_process(false)
	creature.set_suspended(false)
	creature.position = Vector2(1510, 380) # Test starting pose, not navigation.
	var emitter: AcousticEmitter = _emitter(&"east-sound", Vector2(1860, 380))
	assert_eq(emitter.emit_event(&"around-pillar", 0.0), OK)
	var went_above: bool = false
	for _step: int in range(120 * 12):
		var previous: Vector2 = creature.position
		assert_eq(creature.advance_simulation(1.0 / 120.0), OK)
		assert_lte(creature.position.distance_to(previous), 85.0 / 120.0 + 0.01, "Only speed-bounded swept motion.")
		assert_true(creature.navigation.clear(creature.position))
		went_above = went_above or creature.position.y < 280.0
	assert_true(went_above, "The solid pillar requires a detour.")
	assert_eq(creature.brain.state, CreatureState.State.PATROL)


func test_new_thin_obstacle_cannot_be_tunnelled_through_and_causes_safe_recovery() -> void:
	var creature: AcousticCreature = _scene.creature
	creature.set_physics_process(false)
	creature.set_suspended(false)
	assert_eq(creature.advance_simulation(0.0), OK) # Build before obstacle insertion.
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(2, 300)
	shape.shape = rectangle
	wall.add_child(shape)
	_scene.region.add_child(wall)
	wall.position = Vector2(1450, 350)
	await _frames(2)
	var emitter: AcousticEmitter = _emitter(&"west-sound", Vector2(1400, 400))
	assert_eq(emitter.emit_event(&"new-obstacle", 0.0), OK)
	var recovered: bool = false
	for _step: int in range(120 * 8):
		creature.advance_simulation(1.0 / 120.0)
		assert_gte(creature.position.x, 1467.0 - 0.1, "Cannot cross the two-unit wall.")
		recovered = recovered or creature.brain.reason == "UNREACHABLE"
	assert_true(recovered)
	assert_eq(creature.brain.state, CreatureState.State.PATROL)
