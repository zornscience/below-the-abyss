extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
const TARGET: PackedScene = preload("res://scenes/props/sonar_reveal_target.tscn")
const MAIN_ID: StringName = &"shelf-expedition"
const OPTIONAL_ID: StringName = &"shelf-calibration-study"
var _scene: ShelfPrototype
var _path: String


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_path = "user://bta034-integration-%d.json" % Time.get_ticks_usec()
	_scene = await _new_scene()


func _new_scene() -> ShelfPrototype:
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = _path
	add_child_autofree(scene)
	await _frames(2)
	return scene


func after_each() -> void:
	ShelfRouteDriver.release()
	InputBindings.apply(InputBindings.defaults(), 0.25)
	for file: String in [_path, _path + ".missions.json", _path + ".upgrades.json", _path + ".discoveries.json", _path + ".research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(file + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file + suffix))


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _tap(code: int, controller: bool = false) -> void:
	var event: InputEvent
	if controller:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = code as JoyButton
		button.pressed = true
		event = button
	else:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = code as Key
		key.physical_keycode = code as Key
		key.pressed = true
		event = key
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _frames(2)
	event = event.duplicate() as InputEvent
	if controller:
		(event as InputEventJoypadButton).pressed = false
	else:
		(event as InputEventKey).pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _dock() -> void:
	_scene.resume_route()
	assert_eq(_scene.open_station(), OK)


func _board() -> MissionBoard:
	return _scene.station_menu.get_node("%MissionsPage") as MissionBoard


func test_keyboard_controller_accept_status_pause_claim_and_back_navigation() -> void:
	_scene.resume_route()
	await _tap(KEY_E)
	(_scene.station_menu.get_node("%OpenBoard") as Button).grab_focus()
	await _tap(KEY_ENTER)
	(_scene.station_menu.get_node("%OpenMissions") as Button).grab_focus()
	await _tap(KEY_ENTER)
	assert_true(_board().visible)
	assert_true(_scene.missions.snapshot()[String(MAIN_ID)].state == "available")
	var battery: float = _scene.submarine.resource_system.battery
	var clock: float = _scene.route_check.elapsed_seconds
	await _tap(JOY_BUTTON_DPAD_DOWN, true)
	await _tap(JOY_BUTTON_DPAD_DOWN, true)
	assert_eq(get_viewport().gui_get_focus_owner(), _board().get_node("%MissionList").get_child(1))
	await _tap(JOY_BUTTON_DPAD_DOWN, true)
	assert_eq(get_viewport().gui_get_focus_owner(), _board().get_node("%AcceptMission"))
	await _tap(JOY_BUTTON_A, true)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "accepted")
	assert_true((_scene.get_node("%MissionStatus") as Label).text.contains("Calibration study / ACCEPTED"))
	assert_true((_board().get_node("%ClaimMission") as Button).disabled)
	await _frames(5)
	assert_eq(_scene.submarine.resource_system.battery, battery)
	assert_eq(_scene.route_check.elapsed_seconds, clock)
	_scene.research.complete_scan(&"shelf-calibration-plate")
	assert_false((_board().get_node("%ClaimMission") as Button).disabled)
	(_board().get_node("%ClaimMission") as Button).grab_focus()
	await _tap(KEY_ENTER)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "claimed")
	assert_true((_board().get_node("%MissionDetail") as Label).text.contains("Study acknowledged"))
	await _tap(JOY_BUTTON_B, true)
	assert_true((_scene.station_menu.get_node("%BoardPage") as Control).visible)
	await _tap(JOY_BUTTON_B, true)
	await _tap(JOY_BUTTON_B, true)
	assert_false(_scene.station_menu.visible)
	assert_true(_scene.submarine.is_physics_processing())


func test_real_active_wavefront_and_scanner_signals_complete_optional_not_passive_contacts() -> void:
	_dock()
	_scene.station.mission_action(&"accept", OPTIONAL_ID)
	_scene.close_station()
	_scene.submarine.set_physics_process(false) # Controlled simulation steps, scanner stays unsuspended.
	_scene.submarine.global_position = Vector2(760, 480)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	_scene.submarine.sonar.advance(1.0)
	assert_eq(_scene.discoveries.state_of(&"shelf-navigation-marker"), DiscoveryRegistry.State.DISCOVERED)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "accepted")
	assert_eq(_scene.submarine.scanner.request_scan(), OK)
	_scene.submarine.scanner.advance(2.999)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "accepted")
	_scene.submarine.scanner.advance(0.001)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "completed")
	watch_signals(_scene.missions)
	_scene.research.scan_completed.emit(&"shelf-calibration-plate")
	_scene.submarine.passive.advance(3.0)
	assert_signal_not_emitted(_scene.missions, "mission_completed")
	assert_signal_not_emitted(_scene.missions, "acknowledgement_claimed")


func test_services_upgrades_restart_reload_retain_claims_without_replaying_events() -> void:
	_dock()
	_scene.station.mission_action(&"accept", MAIN_ID)
	_scene.discoveries.discover(&"shelf-twin-spires", &"integration/ping")
	_scene.route_check.sample(false, true, 1.0)
	_scene.route_check.sample(true, false, 1.0)
	assert_eq(_scene.station.mission_action(&"claim", MAIN_ID), OK)
	_scene.station.install_upgrade(&"sonar-range-1200")
	_scene.station.install_upgrade(&"pressure-hull-400")
	_scene.submarine.resource_system.consume_battery(20)
	_scene.station.perform(&"all")
	watch_signals(_scene.missions)
	_scene.restart_route()
	assert_eq(_scene.missions.snapshot()[String(MAIN_ID)].state, "claimed")
	_scene.submarine.set_simulation_enabled(false)
	var reloaded: ShelfPrototype = await _new_scene()
	watch_signals(reloaded.missions)
	assert_eq(reloaded.missions.snapshot()[String(MAIN_ID)].state, "claimed")
	assert_eq(reloaded.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq(reloaded.submarine.damage_system.get_maximum_depth_m(), 400.0)
	assert_eq(reloaded.discoveries.state_of(&"shelf-twin-spires"), DiscoveryRegistry.State.DISCOVERED)
	assert_eq(reloaded.missions.claim(MAIN_ID), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(_scene.missions, "mission_completed")
	assert_signal_not_emitted(reloaded.missions, "acknowledgement_claimed")


func test_corruption_recovery_restores_claim_without_regrant_or_progress_loss() -> void:
	_dock()
	_scene.station.mission_action(&"accept", OPTIONAL_ID)
	_scene.research.complete_scan(&"shelf-calibration-plate")
	_scene.station.mission_action(&"claim", OPTIONAL_ID)
	var path: String = _scene.missions.store.path
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var reloaded: ShelfPrototype = await _new_scene()
	reloaded.resume_route()
	reloaded.open_station()
	watch_signals(reloaded.missions)
	assert_ne(reloaded.station.mission_action(&"accept", OPTIONAL_ID), OK)
	assert_eq(reloaded.station.mission_action(&"recover"), OK)
	assert_eq(reloaded.missions.snapshot()[String(OPTIONAL_ID)].state, "claimed")
	assert_eq(reloaded.station.mission_action(&"claim", OPTIONAL_ID), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(reloaded.missions, "acknowledgement_claimed")
	assert_signal_not_emitted(reloaded.missions, "mission_completed")
	assert_eq(FileAccess.get_file_as_string(path + ".rejected"), "broken")


func test_station_mission_actions_require_eligible_paused_session() -> void:
	assert_eq(_scene.station.mission_action(&"accept", MAIN_ID), ERR_UNCONFIGURED)
	_dock()
	_scene.submarine.global_position.x += 140.01
	assert_eq(_scene.station.mission_action(&"accept", MAIN_ID), ERR_UNAVAILABLE)
	_scene.submarine.global_position = _scene.region.spawn.global_position
	_scene.submarine.set_simulation_enabled(true)
	assert_eq(_scene.station.mission_action(&"accept", MAIN_ID), ERR_BUSY)
	_scene.submarine.set_simulation_enabled(false)
	_scene.station.set_service_enabled(false)
	assert_eq(_scene.station.mission_action(&"accept", MAIN_ID), ERR_UNAVAILABLE)
	assert_eq(_scene.missions.snapshot()[String(MAIN_ID)].state, "available")


func test_board_reopening_and_prior_scan_acceptance_never_autoclaim_or_duplicate() -> void:
	_scene.research.complete_scan(&"shelf-calibration-plate")
	_dock()
	_scene.station_menu.show_missions()
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "available")
	assert_eq(_scene.station.mission_action(&"accept", OPTIONAL_ID), OK)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "completed")
	watch_signals(_scene.missions)
	_scene.station_menu.show_services()
	_scene.station_menu.show_missions()
	assert_eq(_scene.station.mission_action(&"accept", OPTIONAL_ID), ERR_ALREADY_EXISTS)
	assert_eq(_scene.missions.snapshot()[String(OPTIONAL_ID)].state, "completed")
	assert_signal_not_emitted(_scene.missions, "mission_completed")
	assert_signal_not_emitted(_scene.missions, "acknowledgement_claimed")


func test_mission_page_buttons_and_expedition_status_fit_reference_and_minimum_windows() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = _path
	viewport.add_child(scene)
	scene.resume_route()
	scene.open_station()
	scene.station.mission_action(&"accept", MAIN_ID)
	scene.station.mission_action(&"accept", OPTIONAL_ID)
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		scene.station_menu.show_missions()
		await get_tree().process_frame
		await get_tree().process_frame
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
		var board: MissionBoard = scene.station_menu.get_node("%MissionsPage") as MissionBoard
		for node: Control in [board, board.get_node("%BackMissions"), board.get_node("%SyncMissions"), board.get_node("%RecoverMissions"), board.get_node("%MissionDetailScroll")]:
			assert_true(bounds.encloses(node.get_global_rect()), node.name)
		var status: Label = scene.get_node("%MissionStatus") as Label
		assert_true(bounds.encloses(status.get_global_rect()))
		assert_true(status.text.contains("ACCEPTED"))
		var reading_key: InputEventKey = InputEventKey.new()
		reading_key.keycode = KEY_PAGEDOWN
		reading_key.pressed = true
		(board.get_node("%MissionDetailScroll") as UiScrollReader).handle_reading_input(reading_key)
		if size.x == 800:
			assert_gt((board.get_node("%MissionDetailScroll") as ScrollContainer).scroll_vertical, 0, "Details action exposes clipped text without a mouse.")
		else:
			assert_gte((board.get_node("%MissionDetailScroll") as ScrollContainer).scroll_vertical, 0)
