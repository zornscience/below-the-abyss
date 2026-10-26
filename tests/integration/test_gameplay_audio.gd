extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var _scene: ShelfPrototype
var _path: String
var _heard: Array[StringName] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_path = "user://bta041-game-%d.json" % Time.get_ticks_usec()
	_scene = MAIN.instantiate() as ShelfPrototype
	_scene.settings_path = _path
	_scene.expedition_path = _path + ".expedition.json"
	add_child_autofree(_scene)
	await get_tree().process_frame
	_scene.audio.cue_played.connect(func(id: StringName, _bus: String) -> void: _heard.append(id))
	_scene.audio.reset_session()
	_scene.audio.set_process(false)
	_scene.gameplay_audio.set_process(false)
	_heard.clear()


func after_each() -> void:
	_scene.audio.apply_audio(SettingsStore.default_audio())
	for file: String in [_path, _path + ".expedition.json", _path + ".discoveries.json", _path + ".research.json", _path + ".upgrades.json", _path + ".missions.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file + suffix))
	InputBindings.apply(InputBindings.defaults(), 0.25)


func test_ping_acceptance_and_wavefront_gate_audio_without_recursive_acoustics() -> void:
	var sonar: SonarEmitter = _scene.submarine.sonar
	var bus: AcousticBus = _scene.get_node("AcousticBus") as AcousticBus
	var receivers: int = bus.receiver_count()
	assert_eq(sonar.request_ping(), OK)
	assert_eq(_heard.count(&"ping"), 1)
	assert_false(_heard.has(&"echo"), "No echo at emission/receiver receipt")
	assert_eq(sonar.request_ping(), ERR_BUSY)
	assert_eq(_heard.count(&"ping"), 1)
	sonar.advance(0.6)
	assert_eq(_heard.count(&"echo"), 1)
	assert_eq(bus.history_count(), 1)
	assert_eq(bus.receiver_count(), receivers, "Audio never registers acoustic listeners")
	_scene.audio.advance(5.0)
	sonar.advance(4.0)
	assert_ne(sonar.request_ping(&"shelf-playtest/neris-01/sonar/0/1"), OK)
	assert_eq(_heard.count(&"ping"), 1)
	assert_eq(bus.history_count(), 1)


func test_failed_energy_does_not_play_ping_or_modify_acoustics() -> void:
	_scene.submarine.resource_system.consume_battery(100.0)
	assert_eq(_scene.submarine.sonar.request_ping(), ERR_UNAVAILABLE)
	assert_false(_heard.has(&"ping"))
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 0)


func test_passive_contact_audio_is_gated_and_repeated_snapshots_do_not_replay() -> void:
	_scene.resume_route()
	_scene.submarine.set_physics_process(false)
	_scene.ambient.advance(2.1)
	var contacts: Array[Dictionary] = _scene.submarine.passive.contacts_snapshot()
	assert_gt(contacts.size(), 0)
	var count: int = _heard.size()
	_scene.submarine.passive.advance(0.0)
	_scene.gameplay_audio._passive_changed()
	assert_eq(_heard.size(), count)
	assert_gt(_heard.count(&"mechanical"), 0)
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 0)
	assert_eq(_scene.submarine.resource_system.battery, 100.0)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.QUIET)


func test_scan_activation_progress_and_completion_come_from_real_scanner() -> void:
	var body: SubmarineController = _scene.submarine
	body.sonar.request_ping()
	body.sonar.advance(0.6)
	body.global_position = Vector2(760, 480)
	_scene.resume_route()
	body.set_physics_process(false)
	assert_eq(body.scanner.request_scan(), OK)
	assert_true(_heard.has(&"scan_start"))
	body.scanner.advance(1.5)
	_scene.gameplay_audio._process(0.1)
	assert_false(_heard.has(&"complete"))
	body.scanner.advance(2.0)
	assert_eq(_heard.count(&"complete"), 1)
	body.scanner.request_scan()
	assert_eq(_heard.count(&"complete"), 1)
	assert_eq(_scene.research.completed_ids().size(), 1)


func test_damage_cues_and_low_resources_have_visual_equivalents_and_no_alarm_stack() -> void:
	_scene.resume_route()
	_scene.submarine.damage_system.observe_contacts(240.0, true, _scene.submarine.hull_system)
	assert_true(_heard.has(&"impact"))
	assert_true(_heard.has(&"damage"))
	_scene.submarine.damage_system.advance(3.0, 350.0, _scene.submarine.hull_system)
	assert_true(_heard.has(&"creak"))
	_scene.submarine.resource_system.consume_battery(100.0)
	_scene.submarine.resource_system.consume_oxygen(100.0)
	_scene.submarine.hull_system.apply_damage(100.0, &"test")
	_scene.gameplay_audio._process(0.1)
	assert_eq(_heard.count(&"hull"), 1)
	assert_eq(_heard.count(&"oxygen"), 0)
	_scene.audio.advance(2.1)
	_scene.gameplay_audio._process(2.1)
	assert_eq(_heard.count(&"oxygen"), 1)
	_scene.audio.advance(2.1)
	_scene.gameplay_audio._process(2.1)
	assert_eq(_heard.count(&"battery"), 1)
	_scene.audio.advance(20.0)
	_scene.gameplay_audio._process(20.0)
	assert_eq(_heard.count(&"battery"), 1, "Only once per low-resource episode")
	for gauge: ResourceGauge in [_scene.hud.hull_gauge, _scene.hud.battery_gauge, _scene.hud.oxygen_gauge]:
		assert_true((gauge.get_node("%LowWarning") as Label).text.contains("LOW"))
		assert_eq((gauge.get_node("%State") as Label).text, "DEPLETED")


func test_real_predator_warns_pursues_and_disengages_once_per_transition() -> void:
	_scene.submarine.global_position = Vector2(3060, 390)
	_scene.resume_route()
	_scene.submarine.set_physics_process(false)
	_scene.predator.set_physics_process(false)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	for _index: int in range(3):
		_scene.predator.advance_simulation(1.0)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.PURSUE)
	assert_eq(_heard.count(&"predator_alert"), 1)
	assert_eq(_heard.count(&"predator_pursue"), 1)
	_scene.submarine.global_position = Vector2(3060, 500)
	_scene.predator.advance_simulation(0.1)
	assert_eq(_heard.count(&"retreat"), 1)
	_scene.gameplay_audio._threat_changed()
	assert_eq(_heard.count(&"retreat"), 1)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)


func test_station_audio_menu_pause_and_services_use_real_operations() -> void:
	_scene.resume_route()
	_scene.submarine.resource_system.consume_battery(20.0)
	assert_eq(_scene.open_station(), OK)
	assert_true(_heard.has(&"dock"))
	assert_false(_scene.submarine.is_physics_processing())
	assert_eq(_scene.station.perform(&"battery").error, OK)
	assert_true(_heard.has(&"service"))
	assert_eq(_scene.submarine.resource_system.battery, 100.0)
	_scene.close_station()
	assert_true(_scene.submarine.is_physics_processing())


func test_restart_continue_and_mute_preserve_checkpoint_schema_and_progress() -> void:
	var audio: Dictionary = _scene.settings.snapshot().audio
	audio.muted = true
	_scene.settings.set_audio(audio)
	_scene.settings.save_settings(_path)
	_scene.discoveries.discover(&"shelf-navigation-marker", &"test/ping")
	assert_eq(_scene.saves.save_current(), OK)
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	_scene.restart_route()
	_scene.open_route_menu()
	assert_eq(_scene.saves.continue_expedition(), OK)
	assert_true(_scene.discoveries.state_of(&"shelf-navigation-marker") == DiscoveryRegistry.State.DISCOVERED)
	assert_true(_scene.settings.snapshot().audio.muted)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_false(_heard.has(&"ping"))
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history + 1)
	assert_eq(_scene.audio.active_voice_count(), 0)


func _tap(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func test_controller_audio_settings_save_and_cancel_without_mouse_or_simulation() -> void:
	_scene.open_audio_settings()
	var panel: AudioSettingsPanel = _scene.audio_settings
	assert_false(_scene.submarine.is_physics_processing())
	assert_eq(get_viewport().gui_get_focus_owner(), panel.sliders.Master)
	await _tap(JOY_BUTTON_DPAD_LEFT)
	assert_almost_eq(panel.sliders.Master.value, 0.75, 0.0001)
	for _index: int in range(5):
		await _tap(JOY_BUTTON_DPAD_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.mute_button)
	await _tap(JOY_BUTTON_A)
	assert_true(AudioServer.is_bus_mute(0))
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	assert_true(panel.status.text.contains("saved"))
	await _tap(JOY_BUTTON_B)
	assert_false(panel.visible)
	assert_true(_scene.route_layer.visible)
	assert_false(_scene.submarine.is_physics_processing())
	var loaded: SettingsStore = SettingsStore.new()
	assert_eq(loaded.load_settings(_path), OK)
	assert_true(loaded.snapshot().audio.muted)
	assert_almost_eq(float(loaded.snapshot().audio.Master), 0.75, 0.0001)


func _tap_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func test_keyboard_audio_preview_cancel_and_failed_save_preserve_preferences() -> void:
	_scene.open_audio_settings()
	var panel: AudioSettingsPanel = _scene.audio_settings
	assert_true(panel.volume_labels.Master.text.begins_with("▶ "))
	await _tap_key(KEY_RIGHT)
	assert_almost_eq(AudioServer.get_bus_volume_linear(0), 0.85, 0.0001)
	await _tap_key(KEY_TAB)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.sliders.Music)
	await _tap_key(KEY_ESCAPE)
	assert_almost_eq(AudioServer.get_bus_volume_linear(0), 0.8, 0.0001)
	assert_true(_scene.route_layer.visible)
	_scene.open_audio_settings()
	await _tap_key(KEY_LEFT)
	panel.settings_path = _path + "/not-a-directory/settings.json"
	panel._save()
	assert_true(panel.status.text.contains("Save failed"))
	assert_almost_eq(float(_scene.settings.snapshot().audio.Master), 0.8, 0.0001)
	panel.cancel()
	assert_almost_eq(AudioServer.get_bus_volume_linear(0), 0.8, 0.0001)
