extends GutTest

const SCENE: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
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
		for suffix: String in ["", ".tmp", ".bak", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_paths.clear()


func _new_scene(path: String = "") -> ShelfPrototype:
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta023-settings-%d.json" % Time.get_ticks_usec()
	scene.discovery_path = path if not path.is_empty() else "user://bta023-discoveries-%d.json" % Time.get_ticks_usec()
	_paths.append(scene.discovery_path)
	add_child_autofree(scene)
	return scene


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _target(id: String) -> SonarRevealTarget:
	return _scene.region.get_node("SonarTargets/" + id) as SonarRevealTarget


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


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	return event


func _button(code: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	return event


func test_only_wavefront_arrival_discovers_and_permanence_outlives_echo() -> void:
	assert_true(_scene.discoveries.discovered_ids().is_empty())
	var catalog: DiscoveryCatalog = _scene.DISCOVERY_CATALOG
	for point: PointOfInterest in catalog.points:
		assert_eq(point.map_position, _target(String(point.sonar_target_id)).position, "Authored map positions match existing sonar landmarks.")
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_true(_scene.discoveries.discovered_ids().is_empty(), "Acoustic dispatch alone never discovers.")
	_scene.submarine.sonar.advance(340.0 / 600.0 - 0.0001)
	assert_true(_scene.discoveries.discovered_ids().is_empty())
	_scene.submarine.sonar.advance(0.0001)
	assert_eq(_scene.discoveries.discovered_ids(), [&"shelf-navigation-marker"])
	assert_true(_target("shelf-marker").is_revealed())
	assert_eq(_scene.discoveries.state_of(&"shelf-twin-spires"), DiscoveryRegistry.State.HIDDEN)
	_scene.submarine.sonar.advance(8.0)
	assert_false(_target("shelf-marker").is_revealed())
	assert_eq(_scene.discoveries.discovered_ids(), [&"shelf-navigation-marker"])
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)


func test_passive_contacts_and_route_telemetry_do_not_discover() -> void:
	_scene.resume_route()
	await _frames(190)
	assert_false(_scene.submarine.passive.contacts_snapshot().is_empty())
	assert_true(_scene.discoveries.discovered_ids().is_empty())
	_scene.route_check.sample(false, true, 1.0)
	_scene.route_check.sample(true, false, 1.0)
	assert_true(_scene.discoveries.discovered_ids().is_empty())
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 0)


func test_restart_and_reload_preserve_discoveries_without_revealing_temporary_targets() -> void:
	_scene.submarine.sonar.request_ping()
	_scene.submarine.sonar.advance(1.0)
	var ids: Array[StringName] = _scene.discoveries.discovered_ids()
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	_scene.restart_route()
	_scene.open_route_menu()
	assert_eq(_scene.discoveries.discovered_ids(), ids)
	assert_false(_target("shelf-marker").is_revealed())
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	var reloaded: ShelfPrototype = _new_scene(_scene.discovery_path)
	assert_eq(reloaded.discoveries.discovered_ids(), ids)
	assert_false((reloaded.region.get_node("SonarTargets/shelf-marker") as SonarRevealTarget).is_revealed())
	assert_eq(reloaded.route_check.stage, GrayboxRouteCheck.Stage.AT_BASE)


func test_map_shows_only_discovered_points_and_player_without_passive_or_secret_geometry() -> void:
	_scene.open_map()
	assert_true(_scene.exploration_map.visible)
	assert_true(_scene.exploration_map.canvas.points.is_empty())
	assert_eq(_scene.exploration_map.canvas.player_position, _scene.region.to_local(_scene.submarine.global_position))
	assert_eq(_scene.exploration_map.canvas.bounds, Rect2(0, 0, 4100, 1800))
	assert_eq(_scene.exploration_map.get_node("%LandmarkList").get_child_count(), 0)
	_scene.close_map()
	_scene.submarine.sonar.request_ping()
	_scene.submarine.sonar.advance(1.0)
	_scene.open_map()
	assert_eq(_scene.exploration_map.canvas.points.size(), 1)
	assert_eq(_scene.exploration_map.canvas.points[0].stable_id, &"shelf-navigation-marker")
	assert_eq(_scene.exploration_map.get_node("%LandmarkList").get_child_count(), 1)
	assert_false((_scene.exploration_map.get_node("%EmptyMap") as Label).visible)


func test_keyboard_remapping_open_close_and_map_pause_restore_previous_mode() -> void:
	assert_true(_scene.route_layer.visible)
	await _tap(_key(KEY_M))
	assert_true(_scene.exploration_map.visible)
	assert_false(_scene.submarine.is_physics_processing())
	await _tap(_key(KEY_ESCAPE))
	assert_false(_scene.exploration_map.visible)
	assert_true(_scene.route_layer.visible, "Opening from briefing returns to briefing.")
	assert_eq(_scene.settings.remap(&"open_map", _key(KEY_N)), OK)
	var settings: Dictionary = _scene.settings.snapshot()
	InputBindings.apply(settings.bindings, settings.deadzone)
	_scene.resume_route()
	await _tap(_key(KEY_M))
	assert_false(_scene.exploration_map.visible)
	await _tap(_key(KEY_N))
	assert_true(_scene.exploration_map.visible)
	var battery: float = _scene.submarine.resource_system.battery
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	await _frames(20)
	assert_eq(_scene.submarine.resource_system.battery, battery)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	await _tap(_key(KEY_N))
	assert_false(_scene.exploration_map.visible)
	assert_true(_scene.submarine.is_physics_processing())


func test_controller_can_open_navigate_select_and_close_without_mouse() -> void:
	_scene.submarine.sonar.request_ping()
	_scene.submarine.sonar.advance(1.0)
	await _tap(_button(JOY_BUTTON_BACK))
	assert_true(_scene.exploration_map.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.exploration_map.get_node("%CloseMap"))
	for _step: int in range(3):
		await _tap(_button(JOY_BUTTON_DPAD_DOWN))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.exploration_map.get_node("%LandmarkList").get_child(0))
	await _tap(_button(JOY_BUTTON_A))
	assert_eq(_scene.exploration_map.canvas.selected_id, &"shelf-navigation-marker")
	assert_true((_scene.exploration_map.get_node("%SelectedLandmark") as Label).text.contains("Shelf navigation marker"))
	await _tap(_button(JOY_BUTTON_B))
	assert_false(_scene.exploration_map.visible)
	assert_true(_scene.route_layer.visible)


func test_discovery_consistent_at_30_60_120_steps_and_removed_target_cannot_discover() -> void:
	for rate: int in [30, 60, 120]:
		var scene: ShelfPrototype = _new_scene()
		watch_signals(scene.discoveries)
		assert_eq(scene.submarine.sonar.request_ping(), OK)
		for _step: int in range(rate * 8):
			assert_eq(scene.submarine.sonar.advance(1.0 / rate), OK)
		assert_eq(scene.discoveries.discovered_ids(), [&"shelf-navigation-marker"])
		assert_signal_emit_count(scene.discoveries, "point_discovered", 1)
		assert_false((scene.region.get_node("SonarTargets/shelf-marker") as SonarRevealTarget).is_revealed())
	_scene.submarine.sonar.request_ping()
	_target("shelf-marker").free()
	_scene.submarine.sonar.advance(1.0)
	assert_true(_scene.discoveries.discovered_ids().is_empty())


func test_map_fits_reference_compact_and_large_windows() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta023-layout-no-settings.json"
	scene.discovery_path = "user://bta023-layout-%d.json" % Time.get_ticks_usec()
	_paths.append(scene.discovery_path)
	viewport.add_child(scene)
	scene.open_map()
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		for name: String in ["MapCanvas", "CloseMap", "RetrySave", "RecoverBackup", "EmptyMap", "DiscoverySaveStatus"]:
			var control: Control = scene.exploration_map.get_node("%" + name) as Control
			assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(control.get_global_rect()), name)
		assert_gte(scene.exploration_map.canvas.size.x, 200.0)
		assert_gte(scene.exploration_map.canvas.size.y, 180.0)


func test_corrupt_file_is_visible_and_explicit_ui_recovery_preserves_pending_state() -> void:
	assert_eq(_scene.discovery_store.save_registry(_scene.discoveries), OK)
	assert_eq(_scene.discoveries.discover(&"shelf-overlook", &"test/first"), OK)
	var file: FileAccess = FileAccess.open(_scene.discovery_path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	assert_eq(_scene.discovery_store.load_registry(_scene.discoveries), ERR_INVALID_DATA)
	_scene.open_map()
	assert_true((_scene.exploration_map.get_node("%DiscoverySaveStatus") as Label).text.contains("preserved"))
	assert_eq(_scene.discoveries.discover(&"shelf-twin-spires", &"test/unsaved"), OK)
	assert_eq(FileAccess.get_file_as_string(_scene.discovery_path), "corrupt")
	(_scene.exploration_map.get_node("%RecoverBackup") as Button).pressed.emit()
	assert_eq(FileAccess.get_file_as_string(_scene.discovery_path + ".rejected"), "corrupt")
	assert_eq(_scene.discoveries.discovered_ids(), [&"shelf-overlook", &"shelf-twin-spires"])
	assert_true((_scene.exploration_map.get_node("%DiscoverySaveStatus") as Label).text.contains("saved"))
