extends GutTest

const PROTOTYPE: PackedScene = preload("res://scenes/main/main.tscn")
var _prototype: MovementPrototype


func before_each() -> void:
	_prototype = PROTOTYPE.instantiate() as MovementPrototype
	_prototype.development_mode = true
	_prototype.settings_path = "user://bta011-test-no-settings-%d.json" % Time.get_ticks_usec()
	add_child_autofree(_prototype)
	await _frames(2)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _tap_key(code: Key) -> void:
	var pressed: InputEventKey = InputEventKey.new()
	pressed.physical_keycode = code
	pressed.keycode = code
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released: InputEventKey = pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _tap_button(code: JoyButton) -> void:
	var pressed: InputEventJoypadButton = InputEventJoypadButton.new()
	pressed.button_index = code
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released: InputEventJoypadButton = pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func test_movement_advances_resources_without_altering_hull_or_motor() -> void:
	var body: SubmarineController = _prototype.submarine
	var battery: float = body.resource_system.battery
	var oxygen: float = body.resource_system.oxygen
	var start: Vector2 = body.position
	Input.action_press("move_right")
	await _frames(30)
	assert_lt(body.resource_system.battery, battery - 0.5)
	assert_lt(body.resource_system.oxygen, oxygen)
	assert_eq(body.hull_system.hull, body.hull_system.max_hull)
	assert_gt(body.position.x, start.x + 30.0)
	assert_true((_prototype.resource_panel.get_node("%Battery") as Label).text.contains("Battery:"))
	assert_false((_prototype.resource_panel.get_node("%Buttons") as HFlowContainer).visible, "Test controls stay compact during piloting.")


func test_settings_stop_drains_and_depletion_does_not_disable_movement() -> void:
	var body: SubmarineController = _prototype.submarine
	_prototype.open_settings()
	var battery: float = body.resource_system.battery
	var oxygen: float = body.resource_system.oxygen
	await _frames(10)
	assert_eq(body.resource_system.battery, battery)
	assert_eq(body.resource_system.oxygen, oxygen)
	_prototype.close_settings()
	body.resource_system.consume_battery(1000.0)
	body.resource_system.consume_oxygen(1000.0)
	body.hull_system.apply_damage(1000.0, &"integration_test")
	var start: Vector2 = body.position
	Input.action_press("move_right")
	await _frames(30)
	assert_gt(body.position.x, start.x + 30.0, "Loss consequences are outside BTA-011.")
	assert_eq(body.resource_system.battery, 0.0)
	assert_eq(body.resource_system.oxygen, 0.0)
	assert_eq(body.hull_system.hull, 0.0)


func test_severe_wall_contact_damages_once_without_changing_resource_interfaces() -> void:
	var body: SubmarineController = _prototype.submarine
	watch_signals(body)
	watch_signals(body.damage_system)
	Input.action_press("move_left")
	await _frames(100)
	assert_signal_emitted(body, "collision_occurred")
	assert_almost_eq(body.hull_system.hull, 91.0, 0.1)
	assert_eq(body.hull_system.last_damage_source, &"collision")
	var remaining: float = body.hull_system.hull
	await _frames(100)
	assert_eq(body.hull_system.hull, remaining, "Continuing to push must not deal jitter damage.")
	assert_signal_emit_count(body.damage_system, "collision_damage_applied", 1)


func test_keyboard_can_deplete_refill_and_resume_using_test_controls() -> void:
	var panel: PrototypeResourcePanel = _prototype.resource_panel
	await _tap_key(KEY_E)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_node("%TestHull"))
	assert_false(_prototype.submarine.is_physics_processing())
	assert_true((panel.get_node("%Buttons") as HFlowContainer).visible)
	var battery: float = _prototype.submarine.resource_system.battery
	await _frames(5)
	assert_eq(_prototype.submarine.resource_system.battery, battery)
	for _index: int in range(4):
		await _tap_key(KEY_ENTER)
	assert_eq(_prototype.submarine.hull_system.hull, 0.0)
	assert_true((panel.get_node("%Hull") as Label).text.contains("DEPLETED"))
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_TAB)
	for _index: int in range(4):
		await _tap_key(KEY_ENTER)
	assert_eq(_prototype.submarine.resource_system.battery, 0.0)
	await _tap_key(KEY_TAB)
	for _index: int in range(4):
		await _tap_key(KEY_ENTER)
	assert_eq(_prototype.submarine.resource_system.oxygen, 0.0)
	var counts: String = (panel.get_node("%Depletions") as Label).text
	assert_true(counts.contains("hull: 1"))
	assert_true(counts.contains("battery: 1"))
	assert_true(counts.contains("oxygen: 1"))
	await _tap_key(KEY_TAB)
	await _tap_key(KEY_ENTER)
	assert_eq(_prototype.submarine.hull_system.hull, 100.0)
	assert_eq(_prototype.submarine.resource_system.battery, 100.0)
	assert_eq(_prototype.submarine.resource_system.oxygen, 100.0)
	await _tap_key(KEY_TAB)
	await _tap_key(KEY_ENTER)
	assert_true(_prototype.submarine.is_physics_processing())
	assert_null(get_viewport().gui_get_focus_owner())
	assert_false((panel.get_node("%Buttons") as HFlowContainer).visible)


func test_controller_can_navigate_test_controls_and_trigger_domain_requests() -> void:
	var panel: PrototypeResourcePanel = _prototype.resource_panel
	await _tap_button(JOY_BUTTON_A)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_node("%TestHull"))
	assert_false(_prototype.submarine.is_physics_processing())
	await _tap_button(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_node("%TestBattery"))
	var previous: float = _prototype.submarine.resource_system.battery
	await _tap_button(JOY_BUTTON_A)
	assert_eq(_prototype.submarine.resource_system.battery, previous - 25.0)
	for _index: int in range(3):
		await _tap_button(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_node("%Pilot"))
	await _tap_button(JOY_BUTTON_A)
	assert_true(_prototype.submarine.is_physics_processing())
	assert_null(get_viewport().gui_get_focus_owner())
