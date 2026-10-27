extends GutTest

const SCENE: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
var _scene: ShelfPrototype
var _paths: Array[String] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = _spawn()
	await _frames(2)


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	InputBindings.apply(InputBindings.defaults(), 0.25)
	for path: String in _paths:
		for suffix: String in ["", ".tmp", ".bak", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_paths.clear()


func _spawn(research_path: String = "", discovery_path: String = "") -> ShelfPrototype:
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta024-controls-%d.json" % Time.get_ticks_usec()
	scene.research_path = research_path if not research_path.is_empty() else "user://bta024-research-%d.json" % Time.get_ticks_usec()
	scene.discovery_path = discovery_path if not discovery_path.is_empty() else "user://bta024-discoveries-%d.json" % Time.get_ticks_usec()
	_paths.append(scene.research_path)
	_paths.append(scene.discovery_path)
	add_child_autofree(scene)
	return scene


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	return event


func _button(code: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	return event


func _tap(event: InputEvent) -> void:
	if event is InputEventKey:
		(event as InputEventKey).pressed = true
	else:
		(event as InputEventJoypadButton).pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _frames(2)
	event = event.duplicate() as InputEvent
	if event is InputEventKey:
		(event as InputEventKey).pressed = false
	else:
		(event as InputEventJoypadButton).pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _prepare_plate() -> void:
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_true(_scene.research.completed_ids().is_empty())
	_scene.submarine.sonar.advance(0.6)
	assert_eq(_scene.discoveries.state_of(&"shelf-navigation-marker"), DiscoveryRegistry.State.DISCOVERED)
	assert_true(_scene.research.completed_ids().is_empty(), "Sonar arrival is not scientific completion.")
	_scene.submarine.global_position = Vector2(760, 480)
	_scene.submarine.velocity = Vector2.ZERO
	_scene.resume_route()


func test_keyboard_scan_progress_completes_once_and_persists_without_extra_energy_cost() -> void:
	_prepare_plate()
	watch_signals(_scene.research)
	var battery: float = _scene.submarine.resource_system.battery
	await _tap(_key(KEY_E))
	await _frames(85)
	assert_gt(_scene.submarine.scanner.snapshot().progress, 0.4)
	assert_lt(_scene.submarine.scanner.snapshot().progress, 0.7)
	assert_true((_scene.get_node("%ScanStatus") as Label).text.contains("SCANNING"))
	await _frames(100)
	assert_eq(_scene.research.completed_ids(), [&"shelf-calibration-plate"])
	assert_signal_emit_count(_scene.research, "scan_completed", 1)
	assert_gt(_scene.submarine.resource_system.battery, battery - 1.0, "Only existing idle drain, no scan energy cost.")
	await _tap(_key(KEY_E))
	assert_signal_emit_count(_scene.research, "scan_completed", 1)
	assert_true(FileAccess.file_exists(_scene.research_path))


func test_controller_activation_cancellation_and_remapped_interact() -> void:
	_prepare_plate()
	await _tap(_button(JOY_BUTTON_A))
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"shelf-calibration-plate")
	await _tap(_button(JOY_BUTTON_A))
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"")
	assert_true(String(_scene.submarine.scanner.snapshot().text).contains("CANCELLED"))
	assert_eq(_scene.settings.remap(&"interact", _key(KEY_G)), OK)
	var settings: Dictionary = _scene.settings.snapshot()
	InputBindings.apply(settings.bindings, settings.deadzone)
	await _tap(_key(KEY_E))
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"")
	await _tap(_key(KEY_G))
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"shelf-calibration-plate")


func test_map_settings_and_route_pause_freeze_scanning_and_resume() -> void:
	_prepare_plate()
	_scene.submarine.scanner.request_scan()
	_scene.submarine.scanner.advance(1.0)
	for mode: int in range(3):
		if mode == 0:
			_scene.open_map()
		elif mode == 1:
			_scene.open_settings()
		else:
			_scene.open_route_menu()
		var before: float = _scene.submarine.scanner.snapshot().progress
		await _frames(12)
		assert_eq(_scene.submarine.scanner.snapshot().progress, before)
		assert_true(String(_scene.submarine.scanner.snapshot().text).contains("PAUSED"))
		if mode == 0:
			_scene.close_map()
		elif mode == 1:
			_scene.close_settings()
		else:
			_scene.resume_route()
	_scene.submarine.scanner.advance(2.0)
	assert_true(_scene.research.is_completed(&"shelf-calibration-plate"))


func test_research_page_hides_uncompleted_metadata_and_controller_can_read_completed_entry() -> void:
	_scene.open_map()
	(_scene.exploration_map.get_node("%OpenResearch") as Button).pressed.emit()
	assert_true(_scene.research_log.visible)
	assert_eq(_scene.research_log.get_node("%ResearchEntries").get_child_count(), 0)
	assert_false((_scene.research_log.get_node("%ResearchDetail") as Label).text.contains("Calibration"))
	await _tap(_button(JOY_BUTTON_B))
	assert_true(_scene.exploration_map.visible)
	_scene.close_map()
	_prepare_plate()
	_scene.submarine.scanner.request_scan()
	_scene.submarine.scanner.advance(3.0)
	_scene.open_map()
	# Map focus cycle: close, save, recovery, discovered landmark, research page.
	for _step: int in range(4):
		await _tap(_button(JOY_BUTTON_DPAD_DOWN))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.exploration_map.get_node("%OpenResearch"))
	await _tap(_button(JOY_BUTTON_A))
	assert_true(_scene.research_log.visible)
	for _step: int in range(3):
		await _tap(_button(JOY_BUTTON_DPAD_DOWN))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.research_log.get_node("%ResearchEntries").get_child(0))
	await _tap(_button(JOY_BUTTON_A))
	var text: String = (_scene.research_log.get_node("%ResearchDetail") as Label).text
	assert_true(text.contains("Calibration plate"))
	assert_false(text.contains("Overlook formation"))
	await _tap(_button(JOY_BUTTON_B))
	assert_true(_scene.exploration_map.visible)


func test_restart_reload_and_partial_scan_do_not_duplicate_completion_events() -> void:
	_prepare_plate()
	watch_signals(_scene.research)
	_scene.submarine.scanner.request_scan()
	_scene.submarine.scanner.advance(1.0)
	_scene.restart_route()
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"")
	assert_true(_scene.research.completed_ids().is_empty())
	_scene.submarine.global_position = Vector2(760, 480)
	_scene.submarine.scanner.request_scan()
	_scene.submarine.scanner.advance(3.0)
	_scene.restart_route()
	_scene.open_route_menu()
	assert_eq(_scene.research.completed_ids(), [&"shelf-calibration-plate"])
	assert_signal_emit_count(_scene.research, "scan_completed", 1)
	var reloaded: ShelfPrototype = _spawn(_scene.research_path, _scene.discovery_path)
	watch_signals(reloaded.research)
	assert_eq(reloaded.research.completed_ids(), [&"shelf-calibration-plate"])
	assert_eq(reloaded.research.complete_scan(&"shelf-calibration-plate"), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(reloaded.research, "scan_completed")


func test_movement_sonar_and_passive_listening_remain_independent_of_scanner() -> void:
	_prepare_plate()
	_scene.submarine.sonar.advance(4.0)
	_scene.submarine.scanner.request_scan()
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_ne(_scene.submarine.scanner.snapshot().active_id, &"")
	var start: Vector2 = _scene.submarine.global_position
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	assert_gt(_scene.submarine.global_position.x, start.x + 50.0)
	assert_true(_scene.research.completed_ids().is_empty())
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 2, "Scanner publishes no acoustic events.")
	await _frames(140)
	assert_false(_scene.submarine.passive.contacts_snapshot().is_empty())
	assert_true(_scene.research.completed_ids().is_empty())


func test_geological_target_and_research_log_fit_reference_and_compact_windows() -> void:
	_scene.submarine.global_position = Vector2(1750, 480)
	_scene.submarine.sonar.request_ping()
	_scene.submarine.sonar.advance(1.0)
	_scene.resume_route()
	assert_eq(_scene.submarine.scanner.candidate_id(), &"shelf-overlook-formation")
	_scene.submarine.scanner.request_scan()
	_scene.submarine.scanner.advance(4.0)
	assert_eq(_scene.research.completed_records()[0].classification, "geological")
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta024-layout-no-settings.json"
	scene.research_path = "user://bta024-layout-%d.json" % Time.get_ticks_usec()
	_paths.append(scene.research_path)
	viewport.add_child(scene)
	scene.research.restore_completed([&"shelf-calibration-plate", &"shelf-overlook-formation"])
	scene.open_map()
	scene.open_research()
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		for name: String in ["ResearchEntries", "ResearchDetail", "CloseResearch", "RetryResearch", "RecoverResearch", "ResearchSaveStatus"]:
			var control: Control = scene.research_log.get_node("%" + name) as Control
			assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(control.get_global_rect()), name)
