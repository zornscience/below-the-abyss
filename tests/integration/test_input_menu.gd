extends GutTest

const MENU: PackedScene = preload("res://scenes/ui/input_test_menu.tscn")
var _menu: InputTestMenu
var _path: String


func before_each() -> void:
	_path = "user://bta004-menu-%d.json" % Time.get_ticks_usec()
	_menu = MENU.instantiate() as InputTestMenu
	_menu.settings_path = _path
	add_child_autofree(_menu)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var neutral: InputEventJoypadMotion = InputEventJoypadMotion.new()
		neutral.axis = axis
		Input.parse_input_event(neutral)
	await get_tree().process_frame
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_key(code: Key) -> void:
	_key(code, true)
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame


func _button(code: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_button(code: JoyButton) -> void:
	_button(code, true)
	await get_tree().process_frame
	_button(code, false)
	await get_tree().process_frame


func test_keyboard_can_cycle_every_control_and_activate_without_mouse() -> void:
	assert_gte((_menu.get_node("%Activate") as Button).get_theme_font_size("font_size"), 20)
	for name: String in ["Activate", "ActionPicker", "Rebind", "Deadzone", "Save", "Reload", "Reset", "Quit"]:
		assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.get_node("%" + name))
		await _tap_key(KEY_TAB)
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.get_node("%Activate"), "Focus wraps.")
	await _tap_key(KEY_ENTER)
	assert_true(_menu.status.text.contains("Test activated 1"))


func test_controller_can_navigate_and_activate_without_mouse() -> void:
	await _tap_button(JOY_BUTTON_A)
	assert_true(_menu.status.text.contains("Test activated 1"))
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.action_picker)
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.rebind_button)
	await _tap_button(JOY_BUTTON_B)
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.get_node("%Activate"))


func test_controller_can_reach_all_controls_change_deadzone_and_save() -> void:
	for name: String in ["Activate", "ActionPicker", "Rebind", "Deadzone", "Save", "Reload", "Reset", "Quit"]:
		assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.get_node("%" + name))
		await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	for _index: int in range(3):
		await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.deadzone_slider)
	await _tap_button(JOY_BUTTON_DPAD_RIGHT)
	assert_almost_eq(float(_menu.settings.snapshot()["deadzone"]), 0.30, 0.001)
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _tap_button(JOY_BUTTON_A)
	assert_true(FileAccess.file_exists(_path))
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _tap_button(JOY_BUTTON_A)
	assert_eq(float(_menu.settings.snapshot()["deadzone"]), 0.25, "Reset is usable with controller.")
	await _tap_button(JOY_BUTTON_LEFT_SHOULDER)
	await _tap_button(JOY_BUTTON_A)
	assert_almost_eq(float(_menu.settings.snapshot()["deadzone"]), 0.30, 0.001, "Reload restores saved value.")


func test_controller_can_select_an_action_in_the_popup() -> void:
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_button(JOY_BUTTON_A)
	assert_true(_menu.action_picker.get_popup().visible)
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_button(JOY_BUTTON_A)
	assert_false(_menu.action_picker.get_popup().visible)
	assert_eq(_menu.action_picker.selected, 1)


func test_analog_stick_can_navigate_with_drift_filtered_out() -> void:
	var drift: InputEventJoypadMotion = InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_Y
	drift.axis_value = 0.1
	Input.parse_input_event(drift)
	await get_tree().process_frame
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.get_node("%Activate"))
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = 0.9
	Input.parse_input_event(motion)
	await get_tree().process_frame
	assert_eq(_menu.get_viewport().gui_get_focus_owner(), _menu.action_picker)


func test_invalid_reload_is_visible_and_preserves_settings() -> void:
	_menu.settings.set_deadzone(0.4)
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	(_menu.get_node("%Reload") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert_true(_menu.status.text.contains("Load failed"))
	assert_eq(float(_menu.settings.snapshot()["deadzone"]), 0.4)
	assert_eq(FileAccess.get_file_as_string(_path), "{broken json")


func test_keyboard_remap_save_and_reload_from_the_menu() -> void:
	_menu.action_picker.select(InputBindings.ACTIONS.find(&"sonar_ping"))
	_menu.rebind_button.grab_focus()
	await _tap_key(KEY_ENTER)
	assert_true(_menu.capturing)
	await _tap_key(KEY_G)
	assert_false(_menu.capturing)
	assert_has(_menu.settings.snapshot()["bindings"]["sonar_ping"], {"kind": "key", "code": KEY_G})
	(_menu.get_node("%Save") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert_true(FileAccess.file_exists(_path))
	_menu.settings.reset_defaults()
	(_menu.get_node("%Reload") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert_has(_menu.settings.snapshot()["bindings"]["sonar_ping"], {"kind": "key", "code": KEY_G})


func test_controller_remap_and_cancel_capture() -> void:
	_menu.action_picker.select(InputBindings.ACTIONS.find(&"sonar_ping"))
	_menu.rebind_button.grab_focus()
	await _tap_button(JOY_BUTTON_A)
	assert_true(_menu.capturing)
	await _tap_button(JOY_BUTTON_LEFT_STICK)
	assert_false(_menu.capturing)
	assert_has(_menu.settings.snapshot()["bindings"]["sonar_ping"], {"kind": "button", "code": JOY_BUTTON_LEFT_STICK})
	var previous: Dictionary = _menu.settings.snapshot()
	await _tap_button(JOY_BUTTON_A)
	assert_true(_menu.capturing)
	await _tap_button(JOY_BUTTON_B)
	assert_false(_menu.capturing)
	assert_eq(_menu.settings.snapshot(), previous)


func test_conflicting_keyboard_capture_is_rejected_and_can_be_cancelled() -> void:
	_menu.action_picker.select(InputBindings.ACTIONS.find(&"sonar_ping"))
	var previous: Dictionary = _menu.settings.snapshot()
	_menu.rebind_button.grab_focus()
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_E)
	assert_true(_menu.capturing)
	assert_true(_menu.status.text.contains("Binding rejected"))
	await _tap_key(KEY_ESCAPE)
	assert_false(_menu.capturing)
	assert_eq(_menu.settings.snapshot(), previous)


func test_new_menu_loads_saved_settings() -> void:
	_menu.settings.set_deadzone(0.4)
	assert_eq(_menu.settings.save_settings(_path), OK)
	var reopened: InputTestMenu = MENU.instantiate() as InputTestMenu
	reopened.settings_path = _path
	add_child_autofree(reopened)
	await get_tree().process_frame
	assert_eq(float(reopened.settings.snapshot()["deadzone"]), 0.4)
	assert_almost_eq(InputMap.action_get_deadzone("move_left"), 0.4, 0.001)


func test_pause_action_reports_input_without_pausing_the_scene_tree() -> void:
	await _tap_key(KEY_P)
	assert_true(_menu.status.text.contains("Pause input test: on"))
	await _tap_button(JOY_BUTTON_START)
	assert_true(_menu.status.text.contains("Pause input test: off"))
	assert_false(get_tree().paused)
