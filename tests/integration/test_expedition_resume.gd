extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var _scene: ShelfPrototype
var _path: String


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_path = "user://bta035-integration-%d.json" % Time.get_ticks_usec()
	_scene = await _new_scene()


func _new_scene(enabled: bool = true) -> ShelfPrototype:
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = _path
	if enabled:
		scene.expedition_path = _path + ".expedition.json"
	add_child_autofree(scene)
	await _frames(3)
	return scene


func after_each() -> void:
	ShelfRouteDriver.release()
	InputBindings.apply(InputBindings.defaults(), 0.25)
	for file: String in [_path, _path + ".expedition.json", _path + ".missions.json", _path + ".upgrades.json", _path + ".discoveries.json", _path + ".research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(file + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file + suffix))


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _earn_progress() -> void:
	_scene.resume_route()
	assert_eq(_scene.open_station(), OK)
	assert_eq(_scene.station.mission_action(&"accept", &"shelf-calibration-study"), OK)
	_scene.research.complete_scan(&"shelf-calibration-plate")
	assert_eq(_scene.station.mission_action(&"claim", &"shelf-calibration-study"), OK)
	assert_eq(_scene.station.install_upgrade(&"sonar-range-1200"), OK)
	assert_eq(_scene.station.install_upgrade(&"pressure-hull-400"), OK)
	_scene.discoveries.discover(&"shelf-navigation-marker", &"integration/ping")
	_scene.station.end_interaction()
	_scene.station_menu.hide()


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


func test_save_restore_position_orientation_resources_cooldown_and_route_without_motion() -> void:
	_scene.submarine.global_position = Vector2(760, 480)
	_scene.submarine.rotation = 0.2
	_scene.submarine.hull_system.apply_damage(23, &"fixture")
	_scene.submarine.resource_system.consume_battery(31)
	_scene.submarine.resource_system.consume_oxygen(17)
	_scene.submarine.sonar.restore_cooldown(2.5)
	_scene.route_check.stage = GrayboxRouteCheck.Stage.OUTBOUND
	_scene.route_check.elapsed_seconds = 12.0
	assert_eq(_scene.saves.save_current(), OK)
	_scene.submarine.global_position = Vector2(900, 480)
	_scene.submarine.velocity = Vector2(999, 999)
	assert_eq(_scene.saves.continue_expedition(), OK)
	assert_eq(_scene.submarine.global_position, Vector2(760, 480))
	assert_almost_eq(_scene.submarine.rotation, 0.2, 0.000001)
	assert_eq(_scene.submarine.velocity, Vector2.ZERO)
	assert_eq(_scene.submarine.hull_system.hull, 77.0)
	assert_eq(_scene.submarine.resource_system.battery, 69.0)
	assert_eq(_scene.submarine.resource_system.oxygen, 83.0)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), 2.5)
	assert_eq(_scene.route_check.stage, GrayboxRouteCheck.Stage.OUTBOUND)
	assert_eq(_scene.route_check.elapsed_seconds, 12.0)


func test_reload_canonical_progress_preserves_claims_and_redirects_legacy_writes() -> void:
	_earn_progress()
	assert_eq(_scene.saves.save_current(), OK)
	assert_false(FileAccess.file_exists(_path + ".missions.json"))
	assert_false(FileAccess.file_exists(_path + ".upgrades.json"))
	var reloaded: ShelfPrototype = await _new_scene()
	watch_signals(reloaded.missions)
	watch_signals(reloaded.research)
	watch_signals(reloaded.submarine.sonar)
	assert_true(reloaded.saves.has_checkpoint())
	assert_true(reloaded.upgrades.store.status.contains("expedition checkpoint"))
	assert_eq(reloaded.saves.continue_expedition(), OK)
	assert_eq(reloaded.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq(reloaded.submarine.damage_system.get_maximum_depth_m(), 400.0)
	assert_true(reloaded.research.is_completed(&"shelf-calibration-plate"))
	assert_eq(reloaded.missions.claim(&"shelf-calibration-study"), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(reloaded.missions, "acknowledgement_claimed")
	assert_signal_not_emitted(reloaded.research, "scan_completed")
	assert_signal_not_emitted(reloaded.submarine.sonar, "pulse_emitted")


func test_legacy_import_preserves_files_and_all_records_then_uses_single_checkpoint() -> void:
	_scene.queue_free()
	await _frames(2)
	var legacy: ShelfPrototype = await _new_scene(false)
	legacy.resume_route()
	legacy.open_station()
	legacy.station.install_upgrade(&"sonar-range-1200")
	legacy.station.mission_action(&"accept", &"shelf-calibration-study")
	legacy.research.complete_scan(&"shelf-calibration-plate")
	legacy.station.mission_action(&"claim", &"shelf-calibration-study")
	legacy.discoveries.discover(&"shelf-navigation-marker", &"legacy/ping")
	var original: String = FileAccess.get_file_as_string(_path + ".missions.json")
	legacy.queue_free()
	await _frames(2)
	_scene = await _new_scene()
	assert_eq(_scene.saves.save_current(), OK)
	assert_eq(FileAccess.get_file_as_string(_path + ".missions.json"), original)
	assert_true(_scene.research.is_completed(&"shelf-calibration-plate"))
	assert_true(_scene.upgrades.is_installed(&"sonar-range-1200"))
	assert_eq(_scene.missions.snapshot()["shelf-calibration-study"].state, "claimed")


func test_safe_position_recovery_preserves_supplies_and_resets_ephemeral_route() -> void:
	_scene.saves.save_current()
	var data: Dictionary = _scene.saves.snapshot()
	data.player.position = [100, 20] # Authored solid roof.
	data.player.battery = 42.0
	data.route.stage = 2
	assert_eq(_scene.saves.store.write_checkpoint(data), OK)
	var reloaded: ShelfPrototype = await _new_scene()
	assert_eq(reloaded.saves.continue_expedition(), OK)
	assert_eq(reloaded.submarine.global_position, reloaded.region.spawn.global_position)
	assert_eq(reloaded.submarine.resource_system.battery, 42.0)
	assert_eq(reloaded.route_check.stage, GrayboxRouteCheck.Stage.AT_BASE)
	assert_true(reloaded.saves.status.contains("fallback"))


func test_corruption_blocks_save_and_explicit_backup_recovery_retains_claims() -> void:
	_earn_progress()
	_scene.saves.save_current()
	var file: FileAccess = FileAccess.open(_scene.saves.store.path, FileAccess.WRITE)
	file.store_string("broken primary")
	file.close()
	var reloaded: ShelfPrototype = await _new_scene()
	assert_false(reloaded.saves.has_checkpoint())
	assert_ne(reloaded.saves.save_current(), OK)
	watch_signals(reloaded.missions)
	assert_eq(reloaded.saves.recover_backup(), OK)
	assert_eq(reloaded.saves.continue_expedition(), OK)
	assert_eq(reloaded.missions.claim(&"shelf-calibration-study"), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(reloaded.missions, "acknowledgement_claimed")
	assert_eq(FileAccess.get_file_as_string(reloaded.saves.store.path + ".rejected"), "broken primary")


func test_manual_save_rejects_running_pressure_danger_and_threat_and_guards_reentry() -> void:
	_scene.resume_route()
	assert_eq(_scene.saves.save_current(), ERR_UNAVAILABLE)
	_scene.open_route_menu()
	_scene.submarine.damage_system.advance(0.0, 401.0, _scene.submarine.hull_system)
	assert_eq(_scene.saves.save_current(), ERR_UNAVAILABLE)
	_scene.submarine.damage_system.advance(0.0, 120.0, _scene.submarine.hull_system)
	_scene.predator.threat.phase = PredatorState.Phase.ALERT
	assert_eq(_scene.saves.save_current(), ERR_UNAVAILABLE)
	_scene.predator.threat.phase = PredatorState.Phase.QUIET
	var nested: Array[int] = []
	_scene.saves.status_changed.connect(func() -> void:
		if nested.is_empty():
			nested.append(ERR_BUSY)
			nested[0] = _scene.saves.save_current())
	assert_eq(_scene.saves.save_current(), OK)
	assert_eq(nested, [ERR_BUSY])


func test_new_expedition_requires_ui_confirmation_and_retains_permanent_records() -> void:
	_earn_progress()
	_scene.open_route_menu()
	(_scene.route_menu.get_node("%NewExpedition") as Button).grab_focus()
	await _tap(JOY_BUTTON_A, true)
	assert_true((_scene.route_menu.get_node("%NewConfirmation") as Control).visible)
	await _tap(JOY_BUTTON_B, true)
	assert_false((_scene.route_menu.get_node("%NewConfirmation") as Control).visible)
	assert_eq(_scene.missions.snapshot()["shelf-calibration-study"].state, "claimed")
	(_scene.route_menu.get_node("%NewExpedition") as Button).pressed.emit()
	(_scene.route_menu.get_node("%ConfirmNew") as Button).grab_focus()
	await _tap(KEY_ENTER)
	assert_eq(_scene.submarine.global_position, _scene.region.spawn.global_position)
	assert_true(_scene.upgrades.is_installed(&"pressure-hull-400"))
	assert_true(_scene.research.is_completed(&"shelf-calibration-plate"))
	assert_eq(_scene.missions.snapshot()["shelf-calibration-study"].state, "claimed")


func test_repeated_save_continue_reset_transients_without_resetting_history_or_awards() -> void:
	_earn_progress()
	_scene.saves.save_current()
	var bus: AcousticBus = _scene.get_node("AcousticBus") as AcousticBus
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	var history: int = bus.history_count()
	watch_signals(_scene.missions)
	for _index: int in range(3):
		assert_eq(_scene.saves.continue_expedition(), OK)
		assert_eq(_scene.submarine.sonar.active_pulse_count(), 0)
		assert_eq(bus.history_count(), history)
		assert_eq(_scene.saves.save_current(), OK)
	assert_signal_not_emitted(_scene.missions, "mission_completed")
	assert_signal_not_emitted(_scene.missions, "acknowledgement_claimed")


func test_legacy_corruption_blocks_migration_until_validated_backup_recovery() -> void:
	_scene.queue_free()
	await _frames(2)
	var legacy: ShelfPrototype = await _new_scene(false)
	legacy.resume_route()
	legacy.open_station()
	legacy.station.install_upgrade(&"sonar-range-1200")
	legacy.station.install_upgrade(&"pressure-hull-400")
	var file: FileAccess = FileAccess.open(legacy.upgrades.store.path, FileAccess.WRITE)
	file.store_string("corrupt legacy")
	file.close()
	legacy.queue_free()
	await _frames(2)
	_scene = await _new_scene()
	assert_false(_scene.saves.can_write())
	assert_true((_scene.route_menu.get_node("%Resume") as Button).disabled)
	assert_eq(_scene.saves.recover_backup(), OK)
	assert_true(_scene.saves.has_checkpoint())
	assert_true(_scene.upgrades.is_installed(&"sonar-range-1200"))
	assert_eq(FileAccess.get_file_as_string(_path + ".upgrades.json.rejected"), "corrupt legacy")


func test_station_docking_autosaves_current_values_without_automatic_refill() -> void:
	_scene.resume_route()
	_scene.submarine.hull_system.apply_damage(17, &"fixture")
	_scene.submarine.resource_system.consume_battery(25)
	assert_eq(_scene.open_station(), OK)
	var saved: Dictionary = _scene.saves.store.load_checkpoint().data
	assert_eq(saved.player.hull, 83.0)
	assert_lte(saved.player.battery, 75.0)
	assert_eq(_scene.submarine.hull_system.hull, 83.0)
	_scene.station.perform(&"all")
	saved = _scene.saves.store.load_checkpoint().data
	assert_eq(saved.player.hull, 100.0)
	assert_eq(saved.player.battery, 100.0)
	assert_eq(saved.player.oxygen, 100.0)


func test_invalid_saved_resources_block_start_without_partial_restore() -> void:
	_scene.saves.save_current()
	var data: Dictionary = _scene.saves.snapshot()
	data.player.hull = -1
	var file: FileAccess = FileAccess.open(_scene.saves.store.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var reloaded: ShelfPrototype = await _new_scene()
	assert_false(reloaded.saves.has_checkpoint())
	assert_ne(reloaded.saves.continue_expedition(), OK)
	assert_eq(reloaded.submarine.hull_system.hull, 100.0)
	assert_eq(reloaded.submarine.global_position, reloaded.region.spawn.global_position)
	assert_true((reloaded.route_menu.get_node("%Resume") as Button).disabled)


func test_pause_confirmation_and_save_controls_fit_supported_window_sizes() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = _path
	scene.expedition_path = _path + ".expedition.json"
	viewport.add_child(scene)
	await _frames(2)
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		for confirm: bool in [false, true]:
			(scene.route_menu.get_node("%NewConfirmation") as Control).visible = confirm
			(scene.route_menu.get_node("%Brief") as Control).visible = not confirm
			await get_tree().process_frame
			await get_tree().process_frame
			var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
			for name: String in ["Resume", "Settings", "Restart", "SaveExpedition", "NewExpedition", "RecoverExpedition", "ExpeditionSaveStatus"]:
				assert_true(bounds.encloses((scene.route_menu.get_node("%" + name) as Control).get_global_rect()), name)
			if confirm:
				assert_true(bounds.encloses((scene.route_menu.get_node("%ConfirmNew") as Control).get_global_rect()))


func test_recovery_with_no_files_does_not_create_a_checkpoint_or_change_vessel() -> void:
	assert_eq(_scene.saves.recover_backup(), ERR_FILE_NOT_FOUND)
	assert_false(_scene.saves.has_checkpoint())
	assert_false(FileAccess.file_exists(_scene.saves.store.path))
	assert_eq(_scene.submarine.global_position, _scene.region.spawn.global_position)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
