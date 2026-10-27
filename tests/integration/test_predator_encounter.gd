extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
const PREDATOR: PackedScene = preload("res://scenes/creatures/shelf_predator.tscn")
var _scene: ShelfPrototype
var _paths: Array[String] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = _new_scene()
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


func _new_scene() -> ShelfPrototype:
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta031-%d.json" % Time.get_ticks_usec()
	_paths.append(scene.settings_path + ".discoveries.json")
	_paths.append(scene.settings_path + ".research.json")
	add_child_autofree(scene)
	return scene


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _prepare(at: Vector2 = Vector2(3060, 390)) -> void:
	_scene.submarine.global_position = at
	_scene.submarine.velocity = Vector2.ZERO
	_scene.resume_route()


func _ping() -> void:
	assert_eq(_scene.submarine.sonar.request_ping(), OK)


func test_actual_ping_warns_before_aggression_and_hud_provides_depth_retreat_cue() -> void:
	_prepare()
	_ping()
	await _frames(4)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.ALERT)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	var panel: ThreatIndicator = _scene.hud.get_node("%ThreatIndicator") as ThreatIndicator
	assert_true(panel.visible)
	assert_true((panel.get_node("Content/Title") as Label).text.contains("WARNING"))
	assert_true((panel.get_node("Content/Hint") as Label).text.contains("115 m"))
	assert_eq(_scene.region.depth_at_world(_scene.region.to_global(Vector2(3060, 460))), 115.0)
	assert_eq(_scene.predator.collision_layer, 0)
	assert_eq(_scene.predator.collision_mask, 1)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)


func test_keyboard_retreat_during_warning_is_escapable_without_damage_or_combat() -> void:
	_prepare()
	_ping()
	await _frames(4)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.ALERT)
	Input.action_press("move_down")
	await _frames(42)
	Input.action_release("move_down")
	assert_gt(_scene.submarine.global_position.y, 460.0)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.DISENGAGE)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_lte(_scene.predator.position.y, 429.0)


func test_modest_hull_damage_is_warning_gated_and_cooldown_limited() -> void:
	_prepare(Vector2(3200, 350))
	var predator: PredatorCreature = _scene.predator
	predator.set_physics_process(false)
	watch_signals(predator)
	_ping()
	predator.advance_simulation(1.0)
	predator.advance_simulation(1.0)
	predator.advance_simulation(0.499)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	predator.advance_simulation(0.001)
	assert_eq(predator.threat.phase, PredatorState.Phase.PURSUE)
	assert_eq(_scene.submarine.hull_system.hull, 95.0)
	for _step: int in range(3):
		predator.advance_simulation(1.0)
	assert_eq(_scene.submarine.hull_system.hull, 90.0)
	assert_eq(_scene.submarine.hull_system.last_damage_source, &"shelf-predator/contact")
	for _step: int in range(3):
		predator.advance_simulation(1.0)
	assert_eq(predator.threat.phase, PredatorState.Phase.DISENGAGE)
	assert_eq(_scene.submarine.hull_system.hull, 90.0)
	assert_signal_emit_count(predator, "contact_damage_applied", 2)


func test_player_can_retreat_after_pursuit_starts_and_damage_stops_outside_zone() -> void:
	_prepare()
	_ping()
	await _frames(155)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.PURSUE)
	Input.action_press("move_down")
	await _frames(45)
	Input.action_release("move_down")
	assert_gt(_scene.submarine.global_position.y, 460.0)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.DISENGAGE)
	var hull: float = _scene.submarine.hull_system.hull
	assert_gte(hull, 95.0)
	await _frames(45)
	assert_eq(_scene.submarine.hull_system.hull, hull)


func test_passive_listening_and_main_route_pings_do_not_engage_predator() -> void:
	_prepare(Vector2(3050, 480))
	_ping()
	await _frames(250)
	assert_false(_scene.submarine.passive.contacts_snapshot().is_empty())
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.QUIET)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.predator.hud_snapshot().title, "SAFE / MAIN PASSAGE")
	assert_true((_scene.region.get_node("SonarTargets/spire-marker") as SonarRevealTarget).is_revealed())


func test_all_pauses_freeze_warning_motion_damage_clock_and_receiver() -> void:
	_prepare()
	_ping()
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
		var state: Dictionary = _scene.predator.threat.snapshot()
		var at: Vector2 = _scene.predator.position
		var hull: float = _scene.submarine.hull_system.hull
		await _frames(10)
		assert_eq(_scene.predator.threat.snapshot(), state)
		assert_eq(_scene.predator.position, at)
		assert_eq(_scene.submarine.hull_system.hull, hull)
		assert_false(_scene.predator.receiver.enabled)
		match mode:
			0: _scene.resume_route()
			1: _scene.close_settings()
			2: _scene.close_map()
			3:
				_scene.close_research()
				_scene.close_map()
			4: (_scene.resource_panel.get_node("%Pilot") as Button).pressed.emit()
		assert_true(_scene.predator.receiver.enabled)


func test_restart_preserves_permanent_records_and_acoustic_duplicate_identity() -> void:
	_scene.discoveries.restore_discoveries([&"shelf-navigation-marker"])
	_scene.research.restore_completed([&"shelf-calibration-plate"])
	_prepare()
	var events: Array[AcousticEvent] = []
	_scene.submarine.sonar.pulse_emitted.connect(func(event: AcousticEvent) -> void: events.append(event.snapshot()))
	_ping()
	await _frames(4)
	var bus: AcousticBus = _scene.get_node("AcousticBus") as AcousticBus
	var history: int = bus.history_count()
	assert_eq(_scene.submarine.sonar.acoustic_emitter.publish(events[0]), ERR_ALREADY_EXISTS)
	_scene.restart_route()
	_scene.open_route_menu()
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.QUIET)
	assert_eq(_scene.predator.position, Vector2(3200, 350))
	assert_eq(bus.history_count(), history)
	assert_eq(_scene.submarine.sonar.acoustic_emitter.publish(events[0]), ERR_ALREADY_EXISTS)
	assert_eq(_scene.discoveries.discovered_ids(), [&"shelf-navigation-marker"])
	assert_eq(_scene.research.completed_ids(), [&"shelf-calibration-plate"])


func test_obstacle_navigation_blocks_contact_and_never_tunnels_or_traps_player() -> void:
	_prepare(Vector2(3135, 350))
	var predator: PredatorCreature = _scene.predator
	predator.set_physics_process(false)
	predator.position = Vector2(3170, 350) # Isolated obstacle-test starting pose.
	predator.advance_simulation(0.0)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(2, 130)
	shape.shape = rectangle
	wall.add_child(shape)
	_scene.region.add_child(wall)
	wall.position = Vector2(3152, 370)
	await _frames(2)
	_ping()
	for _step: int in range(120 * 5):
		var previous: Vector2 = predator.position
		predator.advance_simulation(1.0 / 120.0)
		assert_gte(predator.position.x, 3169.0 - 0.1)
		assert_lte(predator.position.distance_to(previous), 90.0 / 120.0 + 0.01)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_ne(predator.threat.phase, PredatorState.Phase.PURSUE)
	assert_true(predator.navigation.clear(predator.position))


func test_motion_and_damage_are_consistent_at_30_60_120_steps() -> void:
	_scene.submarine.global_position = Vector2(3060, 390)
	var expected: Dictionary = {}
	for rate: int in [30, 60, 120]:
		_scene.submarine.hull_system.configure(_scene.submarine.hull_system.configuration)
		var predator: PredatorCreature = PREDATOR.instantiate() as PredatorCreature
		predator.creature_id = StringName("predator-consistency-%d" % rate)
		predator.position = Vector2(3200, 350)
		_scene.region.add_child(predator)
		assert_eq(predator.setup_player(_scene.submarine), OK)
		predator.set_physics_process(false)
		predator.set_suspended(false)
		var event: AcousticEvent = AcousticEvent.create(&"same", &"neris-01/sonar", &"active_sonar", &"scientific", Vector2(3060, 390), 1.0, 900.0, 0.0)
		assert_eq(predator.brain.offer(event, 1.0, 145.0, event.origin), OK)
		for _step: int in range(rate * 9):
			assert_eq(predator.advance_simulation(1.0 / rate), OK)
			assert_true(predator.configuration.center_bounds().has_point(predator.position))
		if expected.is_empty():
			expected = {"position": predator.position, "phase": predator.threat.phase, "hull": _scene.submarine.hull_system.hull}
		else:
			assert_almost_eq(predator.position.x, expected.position.x, 0.01)
			assert_almost_eq(predator.position.y, expected.position.y, 0.01)
			assert_eq(predator.threat.phase, expected.phase)
			assert_eq(_scene.submarine.hull_system.hull, expected.hull)
		predator.queue_free()


func test_threat_indicator_is_legible_and_keeps_central_view_clear_at_all_window_sizes() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta031-layout-%d.json" % Time.get_ticks_usec()
	_paths.append(scene.settings_path + ".discoveries.json")
	viewport.add_child(scene)
	scene.submarine.global_position = Vector2(3060, 390)
	scene.resume_route()
	scene.submarine.sonar.request_ping()
	scene.predator.advance_simulation(0.05)
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		var panel: ThreatIndicator = scene.hud.get_node("%ThreatIndicator") as ThreatIndicator
		assert_true(panel.visible)
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(panel.get_global_rect()))
		assert_false(panel.get_global_rect().intersects(Rect2(Vector2(size) * 0.5 - Vector2(32, 16), Vector2(64, 32))))
		assert_gte(panel.position.y, (scene.hud.get_node("%DepthPanel") as Control).get_global_rect().end.y)
		for label_name: String in ["Title", "Hint"]:
			var label: Label = panel.get_node("Content/" + label_name) as Label
			assert_lte(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x, label.size.x + 1.0)
			assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_eq(label.focus_mode, Control.FOCUS_NONE)


func test_contact_uses_existing_hull_clamping_without_duplicate_depletion_events() -> void:
	_prepare(Vector2(3200, 350))
	_scene.submarine.hull_system.apply_damage(97.0, &"test-fixture")
	watch_signals(_scene.submarine.hull_system)
	watch_signals(_scene.predator)
	_scene.predator.set_physics_process(false)
	_ping()
	for _step: int in range(3):
		_scene.predator.advance_simulation(1.0)
	assert_eq(_scene.submarine.hull_system.hull, 0.0)
	assert_signal_emit_count(_scene.submarine.hull_system, "vessel_destroyed", 1)
	assert_signal_emit_count(_scene.predator, "contact_damage_applied", 1)
	assert_eq(get_signal_parameters(_scene.predator, "contact_damage_applied")[0], 3.0)
	_scene.predator.advance_simulation(1.0)
	assert_signal_emit_count(_scene.submarine.hull_system, "vessel_destroyed", 1)
