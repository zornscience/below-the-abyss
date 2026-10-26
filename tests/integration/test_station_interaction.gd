extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var _scene: ShelfPrototype
var _paths: Array[String] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = MAIN.instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta032-%d.json" % Time.get_ticks_usec()
	_paths.append(_scene.settings_path + ".discoveries.json")
	_paths.append(_scene.settings_path + ".research.json")
	add_child_autofree(_scene)
	await _frames(2)


func after_each() -> void:
	ShelfRouteDriver.release()
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


func _drain() -> void:
	_scene.submarine.hull_system.apply_damage(25, &"fixture")
	_scene.submarine.resource_system.consume_battery(30)
	_scene.submarine.resource_system.consume_oxygen(40)


func test_keyboard_docking_requires_explicit_service_and_displays_before_after() -> void:
	_scene.resume_route()
	_drain()
	await _tap(_key(KEY_E))
	assert_true(_scene.station_menu.visible)
	assert_eq(_scene.submarine.hull_system.hull, 75.0)
	assert_lt(_scene.submarine.resource_system.battery, 71.0)
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"")
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.station_menu.get_node("%Undock"))
	for _step: int in range(4):
		await _tap(_key(KEY_DOWN))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.station_menu.get_node("%ServiceAll"))
	await _tap(_key(KEY_ENTER))
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.submarine.resource_system.battery, 100.0)
	assert_eq(_scene.submarine.resource_system.oxygen, 100.0)
	assert_true((_scene.station_menu.get_node("%ServiceFeedback") as Label).text.contains("75.0 → 100.0"))
	assert_true((_scene.station_menu.get_node("%ServiceAll") as Button).disabled)
	await _tap(_key(KEY_ESCAPE))
	assert_false(_scene.station_menu.visible)
	assert_true(_scene.submarine.is_physics_processing())


func test_controller_can_read_board_and_leave_without_mission_or_service_side_effects() -> void:
	_scene.resume_route()
	await _tap(_button(JOY_BUTTON_A))
	assert_true(_scene.station_menu.visible)
	var battery: float = _scene.submarine.resource_system.battery
	# Tiny departure drain may leave battery/oxygen available; select board directly,
	# then exercise its fixed keyboard/controller navigation.
	(_scene.station_menu.get_node("%OpenBoard") as Button).grab_focus()
	await _tap(_button(JOY_BUTTON_A))
	assert_true((_scene.station_menu.get_node("%BoardPage") as Control).visible)
	await _tap(_button(JOY_BUTTON_DPAD_DOWN))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.station_menu.get_node("%NoticeList").get_child(0))
	await _tap(_button(JOY_BUTTON_A))
	assert_true((_scene.station_menu.get_node("%NoticeText") as Label).text.contains("Shelf research bulletin"))
	assert_eq(_scene.submarine.resource_system.battery, battery)
	assert_true(_scene.discoveries.discovered_ids().is_empty())
	assert_true(_scene.research.completed_ids().is_empty())
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 0)
	await _tap(_button(JOY_BUTTON_B))
	assert_true((_scene.station_menu.get_node("%ServicesPage") as Control).visible)
	await _tap(_button(JOY_BUTTON_B))
	assert_false(_scene.station_menu.visible)
	assert_true(_scene.submarine.is_physics_processing())


func test_remapped_interact_prioritizes_station_over_scan_inside_radius_and_scan_outside() -> void:
	_scene.discoveries.restore_discoveries([&"shelf-navigation-marker"])
	_scene.submarine.global_position = Vector2(540, 480)
	_scene.resume_route()
	assert_eq(_scene.submarine.scanner.candidate_id(), &"shelf-calibration-plate")
	assert_eq(_scene.settings.remap(&"interact", _key(KEY_G)), OK)
	var settings: Dictionary = _scene.settings.snapshot()
	InputBindings.apply(settings.bindings, settings.deadzone)
	await _tap(_key(KEY_E))
	assert_false(_scene.station_menu.visible)
	await _tap(_key(KEY_G))
	assert_true(_scene.station_menu.visible)
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"")
	_scene.close_station()
	_scene.submarine.global_position = Vector2(600, 480)
	await _tap(_key(KEY_G))
	assert_false(_scene.station_menu.visible)
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"shelf-calibration-plate")


func test_fast_docking_attempt_is_consumed_without_scanning_or_restoration() -> void:
	_scene.discoveries.restore_discoveries([&"shelf-navigation-marker"])
	_scene.submarine.global_position = Vector2(530, 480)
	_scene.resume_route()
	_scene.submarine.velocity = Vector2(80, 0)
	_drain()
	await _tap(_key(KEY_E))
	assert_false(_scene.station_menu.visible)
	assert_eq(_scene.submarine.scanner.snapshot().active_id, &"")
	assert_eq(_scene.submarine.hull_system.hull, 75.0)
	assert_true((_scene.get_node("%ScanStatus") as Label).text.contains("Slow down"))
	_scene.submarine.velocity = Vector2.ZERO
	await _tap(_key(KEY_E))
	assert_true(_scene.station_menu.visible)


func test_station_pause_freezes_all_gameplay_and_services_do_not_reset_clocks_or_records() -> void:
	_scene.discoveries.restore_discoveries([&"shelf-navigation-marker"])
	_scene.research.restore_completed([&"shelf-calibration-plate"])
	_scene.resume_route()
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	await _frames(3)
	_drain()
	assert_eq(_scene.open_station(), OK)
	var brain: Dictionary = _scene.creature.brain.snapshot()
	var predator: Dictionary = _scene.predator.threat.snapshot()
	var contacts: Array[Dictionary] = _scene.submarine.passive.contacts_snapshot()
	var cooldown: float = _scene.submarine.sonar.cooldown_remaining()
	var route_elapsed: float = _scene.route_check.elapsed_seconds
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	var position: Vector2 = _scene.submarine.global_position
	await _frames(20)
	assert_eq(_scene.creature.brain.snapshot(), brain)
	assert_eq(_scene.predator.threat.snapshot(), predator)
	assert_eq(_scene.submarine.passive.contacts_snapshot(), contacts)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), cooldown)
	assert_eq(_scene.submarine.hull_system.hull, 75.0)
	(_scene.station_menu.get_node("%ServiceAll") as Button).pressed.emit()
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), cooldown)
	assert_eq(_scene.route_check.elapsed_seconds, route_elapsed)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	assert_eq(_scene.submarine.global_position, position)
	assert_eq(_scene.discoveries.discovered_ids(), [&"shelf-navigation-marker"])
	assert_eq(_scene.research.completed_ids(), [&"shelf-calibration-plate"])
	assert_false(_scene.creature.receiver.enabled)
	assert_false(_scene.predator.receiver.enabled)
	_scene.close_station()
	assert_true(_scene.creature.receiver.enabled)
	assert_true(_scene.predator.receiver.enabled)


func test_restart_is_distinct_from_services_and_closes_station_session() -> void:
	_scene.resume_route()
	_drain()
	assert_eq(_scene.open_station(), OK)
	assert_eq(_scene.station.perform(&"hull").error, OK)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_lt(_scene.submarine.resource_system.battery, 75.0)
	assert_eq(_scene.submarine.resource_system.oxygen, 60.0)
	_scene.restart_route()
	assert_false(_scene.station_menu.visible)
	assert_true(_scene.submarine.is_physics_processing())
	assert_eq(_scene.station.perform(&"all").error, ERR_UNCONFIGURED)
	assert_eq(_scene.submarine.resource_system.battery, 100.0)
	assert_eq(_scene.submarine.resource_system.oxygen, 100.0)
	assert_eq(_scene.route_check.stage, GrayboxRouteCheck.Stage.AT_BASE)


func test_unavailable_service_states_keep_safe_return_available() -> void:
	_scene.resume_route()
	_drain()
	assert_eq(_scene.open_station(), OK)
	_scene.station.set_service_enabled(false)
	await get_tree().process_frame
	assert_true((_scene.station_menu.get_node("%ServiceAll") as Button).disabled)
	assert_true((_scene.station_menu.get_node("%ServicePreview") as Label).text.contains("offline"))
	assert_false((_scene.station_menu.get_node("%Undock") as Button).disabled)
	await _tap(_key(KEY_ESCAPE))
	assert_true(_scene.submarine.is_physics_processing())
	assert_eq(_scene.submarine.hull_system.hull, 75.0)


func _check_visible_bounds(node: Node, bounds: Rect2) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		assert_true(bounds.encloses((node as Control).get_global_rect()), String(node.name))
	for child: Node in node.get_children():
		_check_visible_bounds(child, bounds)


func test_station_and_board_fit_reference_minimum_and_large_windows() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta032-layout-no-settings.json"
	viewport.add_child(scene)
	scene.resume_route()
	assert_eq(scene.open_station(), OK)
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		scene.station_menu.show_services()
		await get_tree().process_frame
		await get_tree().process_frame
		_check_visible_bounds(scene.station_menu, Rect2(Vector2.ZERO, Vector2(size)))
		scene.station_menu.show_board()
		await get_tree().process_frame
		await get_tree().process_frame
		_check_visible_bounds(scene.station_menu, Rect2(Vector2.ZERO, Vector2(size)))
