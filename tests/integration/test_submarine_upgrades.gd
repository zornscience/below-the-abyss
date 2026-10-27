extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
const TARGET: PackedScene = preload("res://scenes/props/sonar_reveal_target.tscn")
const SONAR: StringName = &"sonar-range-1200"
const HULL: StringName = &"pressure-hull-400"
var _scene: ShelfPrototype
var _path: String


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_path = "user://bta033-integration-%d.json" % Time.get_ticks_usec()
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
	for file: String in [_path, _path + ".upgrades.json", _path + ".discoveries.json", _path + ".research.json"]:
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


func _target(distance: float, id: String) -> SonarRevealTarget:
	var target: SonarRevealTarget = TARGET.instantiate() as SonarRevealTarget
	target.target_id = StringName(id)
	_scene.region.add_child(target)
	target.global_position = _scene.submarine.sonar.global_position + Vector2(distance, 0)
	assert_eq(target.bind_bus(_scene.get_node("AcousticBus") as AcousticBus), OK)
	assert_eq(_scene.submarine.sonar.listen_to(target), OK)
	return target


func test_baseline_install_duplicates_invalid_ids_and_copied_catalog() -> void:
	assert_eq(_scene.submarine.sonar.maximum_radius(), 900.0)
	assert_eq(_scene.submarine.damage_system.get_maximum_depth_m(), 300.0)
	assert_eq(_scene.station.install_upgrade(SONAR), ERR_UNCONFIGURED)
	_dock()
	var hull: float = _scene.submarine.hull_system.hull
	var battery: float = _scene.submarine.resource_system.battery
	watch_signals(_scene.upgrades)
	assert_eq(_scene.station.install_upgrade(SONAR), OK)
	assert_eq(_scene.station.install_upgrade(SONAR), ERR_ALREADY_EXISTS)
	assert_eq(_scene.station.install_upgrade(&"unknown"), ERR_INVALID_PARAMETER)
	assert_signal_emit_count(_scene.upgrades, "upgrade_installed", 1)
	assert_eq(_scene.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq(_scene.submarine.hull_system.hull, hull)
	assert_eq(_scene.submarine.resource_system.battery, battery)
	var definitions: Array[UpgradeDefinition] = _scene.upgrades.definitions()
	definitions[1].upgraded_value = 9999.0
	assert_eq(_scene.station.install_upgrade(HULL), OK)
	for _index: int in range(5):
		_scene.upgrades.reapply()
	assert_eq(_scene.submarine.damage_system.get_maximum_depth_m(), 400.0)
	assert_eq(_scene.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq(_scene.submarine.damage_system.configuration.safe_operating_depth_m, 300.0)


func test_sonar_range_inclusive_boundaries_wavefront_cost_and_cooldown_remain_real() -> void:
	var targets: Array[SonarRevealTarget] = []
	for distance: float in [899.999, 900.0, 900.001, 1199.999, 1200.0, 1200.001]:
		targets.append(_target(distance, "boundary-%d" % targets.size()))
	var sonar: SonarEmitter = _scene.submarine.sonar
	var resources: SubmarineResourceSystem = _scene.submarine.resource_system
	assert_eq(sonar.request_ping(), OK)
	assert_eq(resources.battery, 96.0)
	sonar.advance(1.5)
	for index: int in range(targets.size()):
		assert_eq(targets[index].is_revealed(), index < 2)
	_dock()
	var pending_id: StringName = sonar.next_event_id()
	var cooldown: float = sonar.cooldown_remaining()
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	assert_eq(_scene.station.install_upgrade(SONAR), OK)
	assert_eq(sonar.next_event_id(), pending_id)
	assert_eq(sonar.cooldown_remaining(), cooldown)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	assert_eq(sonar.request_ping(), ERR_BUSY)
	assert_eq(resources.battery, 96.0)
	sonar.advance(2.5)
	assert_eq(sonar.request_ping(), OK)
	assert_eq(resources.battery, 92.0)
	sonar.advance(1.999)
	assert_false(targets[4].is_revealed())
	sonar.advance(0.001)
	assert_true(targets[4].is_revealed())
	assert_false(targets[5].is_revealed())
	sonar.advance(2.0)
	resources.consume_battery(100)
	var id: StringName = sonar.next_event_id()
	assert_eq(sonar.request_ping(), ERR_UNAVAILABLE)
	assert_eq(sonar.next_event_id(), id)
	assert_eq(sonar.cooldown_remaining(), 0.0)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history + 1)


func test_in_flight_baseline_pulse_does_not_gain_range_when_installing() -> void:
	var target: SonarRevealTarget = _target(1100, "in-flight-range")
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	_dock()
	assert_eq(_scene.station.install_upgrade(SONAR), OK)
	_scene.submarine.sonar.advance(4.0)
	assert_false(target.is_revealed())
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	_scene.submarine.sonar.advance(1100.0 / 600.0)
	assert_true(target.is_revealed())


func test_depth_warning_boundaries_and_damage_follow_upgraded_maximum_api() -> void:
	var damage: SubmarineDamageSystem = _scene.submarine.damage_system
	var hull: SubmarineHullSystem = _scene.submarine.hull_system
	damage.advance(0.0, 300.001, hull)
	assert_eq(damage.warning_state, SubmarineDamageSystem.WarningState.EXCEEDED)
	_dock()
	assert_eq(_scene.station.install_upgrade(HULL), OK)
	assert_eq(damage.warning_state, SubmarineDamageSystem.WarningState.SAFE)
	assert_true((_scene.hud.get_node("%SafeDepth") as Label).text.contains("400.0"))
	assert_true((_scene.hud.get_node("%WarningState") as Label).text.begins_with("SAFE"))
	for depth: float in [359.999, 360.0, 400.0, 400.001]:
		damage.advance(0.0, depth, hull)
		var expected: int = SubmarineDamageSystem.WarningState.SAFE if depth < 360.0 else (SubmarineDamageSystem.WarningState.APPROACHING if depth <= 400.0 else SubmarineDamageSystem.WarningState.EXCEEDED)
		assert_eq(damage.warning_state, expected)
	damage.advance(3.0, 400.001, hull)
	assert_almost_eq(hull.hull, 96.0, 0.000001)
	damage.advance(20.0, 335.0, hull)
	assert_eq(damage.warning_state, SubmarineDamageSystem.WarningState.SAFE)
	assert_eq(hull.hull, 96.0)


func test_restart_services_reopen_and_reload_keep_installed_ids_and_records() -> void:
	_dock()
	assert_eq(_scene.station.install_upgrade(SONAR), OK)
	assert_eq(_scene.station.install_upgrade(HULL), OK)
	_scene.discoveries.restore_discoveries([&"shelf-navigation-marker"])
	_scene.discovery_store.save_registry(_scene.discoveries)
	_scene.research.complete_scan(&"shelf-calibration-plate")
	_scene.submarine.sonar.request_ping()
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	_scene.submarine.resource_system.consume_battery(10)
	assert_eq(_scene.station.perform(&"all").error, OK)
	assert_eq(_scene.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	_scene.restart_route()
	assert_eq(_scene.submarine.damage_system.get_maximum_depth_m(), 400.0)
	assert_eq(_scene.submarine.sonar.maximum_radius(), 1200.0)
	assert_true(_scene.upgrades.is_installed(HULL))
	_scene.set_process(false)
	_scene.submarine.set_simulation_enabled(false)
	var reloaded: ShelfPrototype = await _new_scene()
	assert_eq(reloaded.upgrades.installed_ids().size(), 2)
	assert_eq(reloaded.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq(reloaded.submarine.damage_system.get_maximum_depth_m(), 400.0)
	assert_eq(reloaded.discoveries.state_of(&"shelf-navigation-marker"), DiscoveryRegistry.State.DISCOVERED)
	assert_true(reloaded.research.is_completed(&"shelf-calibration-plate"))


func test_corruption_blocks_install_recovery_restores_absolute_ids_and_failed_write_does_not_install() -> void:
	_dock()
	assert_eq(_scene.station.install_upgrade(SONAR), OK)
	assert_eq(_scene.station.install_upgrade(HULL), OK)
	var path: String = _scene.upgrades.store.path
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupted")
	file.close()
	_scene.submarine.set_simulation_enabled(false)
	var reloaded: ShelfPrototype = await _new_scene()
	assert_eq(reloaded.submarine.sonar.maximum_radius(), 900.0)
	reloaded.resume_route()
	assert_eq(reloaded.open_station(), OK)
	assert_ne(reloaded.station.install_upgrade(SONAR), OK)
	assert_false(reloaded.upgrades.is_installed(SONAR))
	assert_eq(reloaded.station.recover_upgrades(), OK)
	assert_true(reloaded.upgrades.is_installed(SONAR))
	assert_false(reloaded.upgrades.is_installed(HULL))
	assert_eq(reloaded.submarine.sonar.maximum_radius(), 1200.0)
	assert_eq(reloaded.submarine.damage_system.get_maximum_depth_m(), 300.0)
	assert_eq(FileAccess.get_file_as_string(path + ".rejected"), "corrupted")
	# A regular-file ancestor produces a deterministic write failure, no volatile install.
	reloaded.upgrades.store.path = path + "/blocked/file.json"
	reloaded.upgrades.store.load_ids(ShelfPrototype.UPGRADE_CATALOG)
	assert_ne(reloaded.station.install_upgrade(HULL), OK)
	assert_false(reloaded.upgrades.is_installed(HULL))
	assert_eq(reloaded.submarine.damage_system.get_maximum_depth_m(), 300.0)


func test_keyboard_and_controller_upgrade_navigation_pause_and_no_automatic_install() -> void:
	_scene.resume_route()
	await _tap(KEY_E)
	assert_true(_scene.station_menu.visible)
	assert_true(_scene.upgrades.installed_ids().is_empty())
	(_scene.station_menu.get_node("%OpenUpgrades") as Button).grab_focus()
	await _tap(KEY_ENTER)
	assert_true((_scene.station_menu.get_node("%UpgradesPage") as Control).visible)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.station_menu.get_node("%BackUpgrades"))
	var clock: float = _scene.route_check.elapsed_seconds
	var battery: float = _scene.submarine.resource_system.battery
	await _tap(KEY_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.station_menu.get_node("%InstallSonar"))
	await _tap(KEY_ENTER)
	assert_true(_scene.upgrades.is_installed(SONAR))
	assert_true((_scene.station_menu.get_node("%UpgradeFeedback") as Label).text.contains("900 → 1200"))
	await _tap(JOY_BUTTON_DPAD_DOWN, true)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.station_menu.get_node("%InstallDepth"))
	await _tap(JOY_BUTTON_A, true)
	assert_true(_scene.upgrades.is_installed(HULL))
	assert_true((_scene.station_menu.get_node("%UpgradePreview") as Label).text.contains("INSTALLED / PERSISTENT"))
	await _frames(8)
	assert_eq(_scene.route_check.elapsed_seconds, clock)
	assert_eq(_scene.submarine.resource_system.battery, battery)
	assert_true((_scene.hud.get_node("%Sonar") as Label).text.contains("RANGE 1200"))
	await _tap(JOY_BUTTON_B, true)
	assert_true((_scene.station_menu.get_node("%ServicesPage") as Control).visible)
	await _tap(JOY_BUTTON_B, true)
	assert_false(_scene.station_menu.visible)
	assert_true(_scene.submarine.is_physics_processing())


func test_upgraded_wavefront_and_pressure_damage_match_30_60_120_steps() -> void:
	_dock()
	_scene.station.install_upgrade(SONAR)
	_scene.station.install_upgrade(HULL)
	var target: SonarRevealTarget = _target(1200, "rate-boundary")
	for rate: int in [30, 60, 120]:
		_scene.submarine.sonar.reset_session()
		_scene.submarine.hull_system.configure(_scene.submarine.hull_system.configuration)
		_scene.submarine.damage_system.configure(_scene.submarine.damage_system.configuration)
		_scene.upgrades.reapply()
		assert_eq(_scene.submarine.sonar.request_ping(), OK)
		for step: int in range(rate * 3):
			_scene.submarine.sonar.advance(1.0 / rate)
			_scene.submarine.damage_system.advance(1.0 / rate, 401.0, _scene.submarine.hull_system)
			assert_eq(target.is_revealed(), step + 1 >= rate * 2)
		assert_almost_eq(_scene.submarine.hull_system.hull, 96.0, 0.000001)
		assert_almost_eq(_scene.submarine.sonar.cooldown_remaining(), 1.0, 0.000001)
		assert_eq(_scene.submarine.sonar.maximum_radius(), 1200.0)


func test_station_install_revalidates_range_pause_speed_and_availability() -> void:
	_dock()
	_scene.submarine.global_position.x += 140.001
	assert_eq(_scene.station.install_upgrade(SONAR), ERR_UNAVAILABLE)
	_scene.submarine.global_position = _scene.region.spawn.global_position
	_scene.submarine.set_simulation_enabled(true)
	assert_eq(_scene.station.install_upgrade(SONAR), ERR_BUSY)
	_scene.submarine.set_simulation_enabled(false)
	_scene.station.set_service_enabled(false)
	assert_eq(_scene.station.install_upgrade(SONAR), ERR_UNAVAILABLE)
	_scene.station.set_service_enabled(true)
	_scene.submarine.velocity = Vector2(40.001, 0)
	assert_eq(_scene.station.install_upgrade(SONAR), ERR_UNAVAILABLE)
	_scene.submarine.velocity = Vector2.ZERO
	assert_true(_scene.upgrades.installed_ids().is_empty())
	assert_false(FileAccess.file_exists(_scene.upgrades.store.path))
	assert_eq(_scene.station.install_upgrade(SONAR), OK)


func test_reentrant_install_is_rejected_and_duplicate_does_not_extend_pressure_grace() -> void:
	_dock()
	var reactions: Array[int] = []
	_scene.upgrades.upgrade_installed.connect(func(_id: StringName) -> void:
		reactions.append(_scene.station.install_upgrade(HULL))
		reactions.append(_scene.upgrades.install(HULL)))
	assert_eq(_scene.station.install_upgrade(SONAR), OK)
	assert_eq(reactions, [ERR_BUSY, ERR_BUSY])
	assert_false(_scene.upgrades.is_installed(HULL))
	assert_eq(_scene.station.install_upgrade(HULL), OK)
	_scene.submarine.damage_system.advance(1.5, 401.0, _scene.submarine.hull_system)
	var grace: float = _scene.submarine.damage_system.grace_remaining_seconds
	assert_eq(_scene.station.install_upgrade(HULL), ERR_ALREADY_EXISTS)
	assert_eq(_scene.submarine.damage_system.grace_remaining_seconds, grace)
	assert_eq(_scene.submarine.damage_system.warning_state, SubmarineDamageSystem.WarningState.EXCEEDED)


func _check_bounds(node: Node, bounds: Rect2) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		assert_true(bounds.encloses((node as Control).get_global_rect()), String(node.name))
	for child: Node in node.get_children():
		_check_bounds(child, bounds)


func test_upgrade_page_and_capability_hud_fit_supported_windows() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = _path
	viewport.add_child(scene)
	scene.resume_route()
	assert_eq(scene.open_station(), OK)
	scene.station.install_upgrade(SONAR)
	scene.station.install_upgrade(HULL)
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		scene.station_menu.show_upgrades()
		await get_tree().process_frame
		await get_tree().process_frame
		_check_bounds(scene.station_menu, Rect2(Vector2.ZERO, Vector2(size)))
		assert_true((scene.hud.get_node("%Sonar") as Label).text.contains("1200"))
		assert_true((scene.hud.get_node("%SafeDepth") as Label).text.contains("400.0"))
