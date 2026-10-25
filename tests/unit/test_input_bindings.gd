extends GutTest

var _store: SettingsStore


func before_each() -> void:
	_store = SettingsStore.new()
	InputBindings.apply(_store.snapshot()["bindings"], 0.25)


func after_each() -> void:
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = 0.0
		Input.parse_input_event(event)
	await get_tree().process_frame
	InputBindings.apply(InputBindings.defaults(), 0.25)


func test_defaults_cover_keyboard_controller_and_menu_navigation() -> void:
	var bindings: Dictionary = InputBindings.defaults()
	assert_true(InputBindings.valid_bindings(bindings))
	for action: StringName in InputBindings.ACTIONS + InputBindings.MENU_ACTIONS:
		assert_true(InputMap.has_action(action), String(action))
		var has_key: bool = false
		var has_controller: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_controller = has_controller or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(has_key, String(action) + " keyboard")
		assert_true(has_controller, String(action) + " controller")


func test_remap_replaces_one_device_group_and_preserves_the_other() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	assert_eq(_store.remap(&"sonar_ping", key), OK)
	var bindings: Dictionary = _store.snapshot()["bindings"]
	assert_eq(bindings["sonar_ping"].size(), 2)
	assert_has(bindings["sonar_ping"], {"kind": "button", "code": JOY_BUTTON_X})
	InputBindings.apply(bindings, 0.4)
	assert_true(InputMap.action_has_event("sonar_ping", key))
	assert_almost_eq(InputMap.action_get_deadzone("move_left"), 0.4, 0.001)
	assert_eq(InputMap.action_get_events("ui_accept").size(), 3, "Fixed recovery controls survive remapping.")


func test_conflicting_unknown_and_unsupported_remaps_leave_state_unchanged() -> void:
	var previous: Dictionary = _store.snapshot()
	var conflict: InputEventKey = InputEventKey.new()
	conflict.physical_keycode = KEY_E
	assert_eq(_store.remap(&"sonar_ping", conflict), ERR_INVALID_PARAMETER)
	assert_eq(_store.remap(&"unknown", conflict), ERR_INVALID_PARAMETER)
	assert_eq(_store.remap(&"ui_accept", conflict), ERR_INVALID_PARAMETER)
	assert_eq(_store.remap(&"sonar_ping", InputEventMouseButton.new()), ERR_INVALID_PARAMETER)
	conflict.physical_keycode = KEY_G
	conflict.ctrl_pressed = true
	assert_eq(_store.remap(&"sonar_ping", conflict), ERR_INVALID_PARAMETER)
	assert_eq(_store.snapshot(), previous)


func test_controller_axis_remap_round_trip() -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = -0.9
	assert_eq(_store.remap(&"move_left", motion), OK)
	var entry: Dictionary = _store.snapshot()["bindings"]["move_left"].back()
	assert_eq(entry, {"kind": "axis", "axis": JOY_AXIS_RIGHT_X, "direction": -1})
	var restored: InputEventJoypadMotion = InputBindings.to_event(entry) as InputEventJoypadMotion
	assert_eq(restored.device, -1, "Bindings accept any connected controller.")
	assert_eq(restored.axis, JOY_AXIS_RIGHT_X)
	assert_eq(restored.axis_value, -1.0)
	motion.axis_value = 0.1
	assert_eq(_store.remap(&"move_left", motion), ERR_INVALID_PARAMETER, "Ignore stick drift during capture.")


func test_analog_deadzone_and_diagonal_vector_are_applied_by_godot() -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.1
	Input.parse_input_event(motion)
	await get_tree().process_frame
	assert_eq(Input.get_vector("move_left", "move_right", "move_up", "move_down"), Vector2.ZERO)
	motion.axis_value = 0.9
	Input.parse_input_event(motion.duplicate())
	await get_tree().process_frame
	assert_gt(Input.get_action_strength("move_right"), 0.0)
	assert_gt(Input.get_vector("move_left", "move_right", "move_up", "move_down").x, 0.0)
	var vertical: InputEventJoypadMotion = InputEventJoypadMotion.new()
	vertical.axis = JOY_AXIS_LEFT_Y
	vertical.axis_value = 0.9
	Input.parse_input_event(vertical)
	await get_tree().process_frame
	assert_lte(Input.get_vector("move_left", "move_right", "move_up", "move_down").length(), 1.001)


func test_reapplying_bindings_releases_held_actions_and_rejects_invalid_data() -> void:
	Input.action_press("move_left")
	assert_true(Input.is_action_pressed("move_left"))
	assert_eq(InputBindings.apply(_store.snapshot()["bindings"], 0.25), OK)
	assert_false(Input.is_action_pressed("move_left"))
	assert_eq(InputBindings.apply({}, 0.25), ERR_INVALID_PARAMETER)
	assert_eq(InputBindings.apply(_store.snapshot()["bindings"], NAN), ERR_INVALID_PARAMETER)
	assert_eq(InputMap.action_get_deadzone("move_left"), 0.25)
