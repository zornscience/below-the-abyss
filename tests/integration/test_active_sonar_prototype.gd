extends GutTest

const SCENE: PackedScene = preload("res://scenes/main/main.tscn")
var _scene: ShelfPrototype
var _old_fps: int


func before_each() -> void:
	_old_fps = Engine.max_fps
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = SCENE.instantiate() as ShelfPrototype
	_scene.development_mode = true
	_scene.settings_path = "user://bta021-no-settings-%d.json" % Time.get_ticks_usec()
	add_child_autofree(_scene)
	await _frames(2)


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	InputBindings.apply(InputBindings.defaults(), 0.25)
	Engine.max_fps = _old_fps
	if FileAccess.file_exists(_scene.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scene.settings_path))


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _target(name: String) -> SonarRevealTarget:
	return _scene.region.get_node("SonarTargets/" + name) as SonarRevealTarget


func _pulse() -> SonarPulse:
	return _scene.get_node("WorldRoot/WorldEffects").get_child(0) as SonarPulse


func _tap_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _frames(2)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _frames(1)


func _tap_button(code: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _frames(2)
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await _frames(1)


func test_initial_readiness_hidden_targets_and_keyboard_wavefront_reveal() -> void:
	assert_eq((_scene.hud.get_node("%Sonar") as Label).text, "SONAR / READY · COST 4.0\nLAST PING / ECHOES 0")
	assert_false(_target("shelf-marker").is_revealed())
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).receiver_count(), 6)
	_scene.resume_route()
	await _tap_key(KEY_F)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)
	assert_almost_eq(_scene.submarine.resource_system.battery, 96.0, 0.1)
	assert_false(_target("shelf-marker").is_revealed())
	assert_true((_scene.hud.get_node("%Sonar") as Label).text.contains("COOLING"))
	await _frames(20)
	assert_false(_target("shelf-marker").is_revealed())
	await _frames(20)
	assert_true(_target("shelf-marker").is_revealed())
	assert_false(_target("cave-marker").is_revealed())
	await _frames(35)
	assert_true(_target("cave-marker").is_revealed())
	assert_false(_target("overlook-marker").is_revealed())
	assert_false(_target("spire-marker").is_revealed())
	assert_eq(_scene.submarine.sonar.echo_count(), 2)
	assert_true((_scene.hud.get_node("%Sonar") as Label).text.contains("ECHOES 2"))
	await _tap_key(KEY_F)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)


func test_gamepad_ping_uses_the_same_action_and_wave_origin_does_not_follow_vessel() -> void:
	_scene.resume_route()
	var origin: Vector2 = _scene.submarine.global_position
	await _tap_button(JOY_BUTTON_X)
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 1)
	Input.action_press("move_right")
	await _frames(25)
	Input.action_release("move_right")
	assert_gt(_scene.submarine.global_position.x, origin.x + 20.0)
	assert_eq(_pulse().global_position, origin)
	assert_gt(_pulse().get_radius(), 200.0)
	assert_almost_eq(_scene.submarine.resource_system.battery, 95.3, 0.3)


func test_route_settings_and_debug_pauses_freeze_wave_cooldown_and_reveal_clocks() -> void:
	_scene.resume_route()
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	await _frames(10)
	_scene.open_route_menu()
	var radius: float = _pulse().get_radius()
	var cooldown: float = _scene.submarine.sonar.cooldown_remaining()
	await _frames(30)
	assert_eq(_pulse().get_radius(), radius)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), cooldown)
	await _tap_key(KEY_F)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)
	_scene.resume_route()
	await _frames(35)
	assert_true(_target("shelf-marker").is_revealed())
	_scene.open_settings()
	cooldown = _scene.submarine.sonar.cooldown_remaining()
	await _frames(30)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), cooldown)
	assert_true(_target("shelf-marker").is_revealed())
	_scene.close_settings()
	_scene.resource_panel.focus_test_controls()
	cooldown = _scene.submarine.sonar.cooldown_remaining()
	await _frames(30)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), cooldown)
	(_scene.resource_panel.get_node("%Pilot") as Button).pressed.emit()
	await _frames(3)
	assert_lt(_scene.submarine.sonar.cooldown_remaining(), cooldown)


func test_route_restart_clears_sonar_state_preserves_history_and_can_ping_again() -> void:
	_scene.resume_route()
	var ids: Array[StringName] = []
	_scene.submarine.sonar.pulse_emitted.connect(func(event: AcousticEvent) -> void: ids.append(event.event_id))
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	await _frames(40)
	assert_true(_target("shelf-marker").is_revealed())
	_scene.open_route_menu()
	await _tap_key(KEY_UP)
	await _tap_key(KEY_ENTER)
	await _frames(2)
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 0)
	assert_eq(_scene.get_node("WorldRoot/WorldEffects").get_child_count(), 0)
	assert_false(_target("shelf-marker").is_revealed())
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), 0.0)
	assert_almost_eq(_scene.submarine.resource_system.battery, 100.0, 0.1)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)
	assert_true((_scene.hud.get_node("%Sonar") as Label).text.contains("READY"))
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_ne(ids[0], ids[1])
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 2)


func test_low_energy_hud_and_removed_targets_do_not_break_a_ping() -> void:
	_scene.resume_route()
	_scene.submarine.resource_system.consume_battery(98.0)
	assert_true((_scene.hud.get_node("%Sonar") as Label).text.contains("LOW BATTERY"))
	await _tap_button(JOY_BUTTON_X)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 0)
	assert_eq(_scene.submarine.sonar.cooldown_remaining(), 0.0)
	_scene.submarine.resource_system.restore_battery(98.0)
	for target: Node in _scene.region.get_node("SonarTargets").get_children():
		target.queue_free()
	await _frames(2)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).receiver_count(), 2)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	await _frames(75)
	assert_eq(_scene.submarine.sonar.echo_count(), 0)
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 1, "The visual is still travelling at this time.")


func test_actual_30_60_and_120_render_caps_keep_fixed_physics_sonar_consistent() -> void:
	for cap: int in [30, 60, 120]:
		Engine.max_fps = cap
		_scene.restart_route()
		assert_eq(_scene.submarine.sonar.request_ping(), OK)
		await _frames(37)
		assert_true(_target("shelf-marker").is_revealed())
		assert_false(_target("cave-marker").is_revealed())
		await _frames(80)
		assert_true(_target("cave-marker").is_revealed())
		assert_false(_target("overlook-marker").is_revealed())
		assert_eq(_scene.submarine.sonar.echo_count(), 2)
		assert_eq(_scene.submarine.sonar.active_pulse_count(), 0)
		assert_almost_eq(_scene.submarine.sonar.cooldown_remaining(), 2.05, 0.06)
		assert_almost_eq(_scene.submarine.resource_system.battery, 95.51, 0.06)


func test_sonar_hud_states_fit_the_minimum_window() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta021-layout-no-settings.json"
	viewport.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var label: Label = scene.hud.get_node("%Sonar") as Label
	assert_true(Rect2(Vector2.ZERO, Vector2(800, 600)).encloses(label.get_global_rect()))
	for phase: int in range(3):
		if phase == 1:
			scene.submarine.sonar.request_ping()
		elif phase == 2:
			scene.submarine.sonar.advance(4.0)
			scene.submarine.resource_system.consume_battery(100.0)
		await get_tree().process_frame
		for line: String in label.text.split("\n"):
			assert_lte(label.get_theme_font("font").get_string_size(line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x, label.size.x)


func test_saved_sonar_remapping_survives_route_restart() -> void:
	var binding: InputEventKey = InputEventKey.new()
	binding.physical_keycode = KEY_G
	assert_eq(_scene.settings.remap(&"sonar_ping", binding), OK)
	assert_eq(_scene.settings.save_settings(_scene.settings_path), OK)
	_scene._route_settings_requested()
	_scene.close_settings()
	await _tap_key(KEY_F)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 0)
	await _tap_key(KEY_G)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)
	_scene.restart_route()
	assert_true(InputMap.action_has_event("sonar_ping", binding))
	await _tap_key(KEY_G)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 2)
