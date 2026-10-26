extends GutTest

const PROTOTYPE: PackedScene = preload("res://scenes/main/movement_prototype.tscn")
const HUD: PackedScene = preload("res://scenes/ui/submarine_hud.tscn")


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _prototype(development: bool = false) -> MovementPrototype:
	var scene: MovementPrototype = PROTOTYPE.instantiate() as MovementPrototype
	scene.development_mode = development
	scene.settings_path = "user://bta013-no-settings-%d.json" % Time.get_ticks_usec()
	add_child_autofree(scene)
	return scene


func _check_text_and_input(node: Node, viewport_rect: Rect2) -> void:
	if node is Control:
		var control: Control = node as Control
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)
		if control.is_visible_in_tree():
			assert_true(viewport_rect.encloses(control.get_global_rect()), "%s fits inside viewport" % node.name)
	if node is Label and (node as Label).is_visible_in_tree():
		var label: Label = node as Label
		var font_size: int = label.get_theme_font_size("font_size")
		assert_gte(font_size, 16, "No tiny labels: %s" % label.name)
		for line: String in label.text.split("\n"):
			var width: float = label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			assert_lte(width, label.size.x + 1.0, "No clipped label: %s" % label.name)
	for child: Node in node.get_children():
		_check_text_and_input(child, viewport_rect)


func test_responsive_layout_keeps_text_visible_and_center_clear() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var hud: SubmarineHud = HUD.instantiate() as SubmarineHud
	viewport.add_child(hud)
	var resources: SubmarineResourceSystem = SubmarineResourceSystem.new()
	var hull: SubmarineHullSystem = SubmarineHullSystem.new()
	var damage: SubmarineDamageSystem = SubmarineDamageSystem.new()
	add_child_autofree(resources)
	add_child_autofree(hull)
	add_child_autofree(damage)
	hud.bind_sources(resources, hull, damage)
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080), Vector2i(800, 1000), Vector2i(1280, 800)]:
		viewport.size = dimensions
		for depth: float in [130.0, 270.0, 350.0]:
			damage.advance(3.0, depth, hull)
			await get_tree().process_frame
			await get_tree().process_frame
			assert_eq(hud.size, Vector2(dimensions))
			_check_text_and_input(hud, Rect2(Vector2.ZERO, Vector2(dimensions)))
			var center: Rect2 = Rect2(Vector2(dimensions) * Vector2(0.3, 0.35), Vector2(dimensions) * Vector2(0.4, 0.25))
			for name: String in ["%DepthPanel", "%InstrumentDeck"]:
				assert_false((hud.get_node(name) as Control).get_global_rect().intersects(center), "Gameplay center clear at %s" % dimensions)


func test_main_scene_initializes_hud_and_real_physics_updates_its_values() -> void:
	var scene: MovementPrototype = _prototype()
	assert_eq(scene.hud.hull_gauge.current_value, 100.0)
	assert_eq((scene.hud.get_node("%DepthValue") as Label).text, "130.0 m")
	assert_true((scene.hud.get_node("%WarningState") as Label).text.begins_with("SAFE"))
	Input.action_press("move_down")
	for _index: int in range(30):
		await get_tree().physics_frame
	Input.action_release("move_down")
	assert_lt(scene.hud.battery_gauge.current_value, 100.0)
	assert_eq(scene.hud.battery_gauge.current_value, scene.submarine.resource_system.battery)
	assert_gt(scene.submarine.damage_system.depth_m, 130.0)
	assert_eq((scene.hud.get_node("%DepthValue") as Label).text, "%.1f m" % scene.submarine.damage_system.depth_m)


func test_production_hud_has_no_debug_controls_or_focus_and_interact_keeps_piloting() -> void:
	var scene: MovementPrototype = _prototype()
	assert_false((scene.get_node("DevelopmentUI") as CanvasLayer).visible)
	assert_false(scene.resource_panel.is_visible_in_tree())
	assert_true(scene.hud.find_children("*", "Button", true, false).is_empty())
	for event: InputEvent in [_key_interact(), _controller_interact()]:
		scene._unhandled_input(event)
		assert_true(scene.submarine.is_physics_processing())
		assert_false(scene.resource_panel.is_visible_in_tree())
		assert_false(scene.resource_panel.has_test_focus())


func _key_interact() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	return event


func _controller_interact() -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func test_debug_controls_update_the_hud_and_resume_without_modifying_production_scene() -> void:
	var scene: MovementPrototype = _prototype(true)
	assert_true((scene.get_node("DevelopmentUI") as CanvasLayer).visible)
	scene._unhandled_input(_controller_interact())
	assert_true(scene.resource_panel.is_visible_in_tree())
	assert_false(scene.submarine.is_physics_processing())
	for _index: int in range(4):
		(scene.resource_panel.get_node("%TestBattery") as Button).pressed.emit()
	assert_eq(scene.hud.battery_gauge.current_value, 0.0)
	assert_eq((scene.hud.battery_gauge.get_node("%State") as Label).text, "DEPLETED")
	(scene.resource_panel.get_node("%RefillAll") as Button).pressed.emit()
	assert_eq(scene.hud.battery_gauge.current_value, 100.0)
	assert_eq((scene.hud.battery_gauge.get_node("%State") as Label).text, "AVAILABLE")
	(scene.resource_panel.get_node("%Pilot") as Button).pressed.emit()
	assert_true(scene.submarine.is_physics_processing())
	assert_false(scene.resource_panel.is_visible_in_tree())
	assert_null(get_viewport().gui_get_focus_owner())


func test_pressure_and_depth_hud_track_existing_simulation_pause_contract() -> void:
	var scene: MovementPrototype = _prototype()
	scene.submarine.position = Vector2(325.0, 1800.0)
	scene.submarine.reset_physics_interpolation()
	for _index: int in range(30):
		await get_tree().physics_frame
	scene.open_settings()
	var remaining: float = scene.submarine.damage_system.grace_remaining_seconds
	var battery: float = scene.hud.battery_gauge.current_value
	for _index: int in range(10):
		await get_tree().physics_frame
	assert_eq(scene.submarine.damage_system.grace_remaining_seconds, remaining)
	assert_eq(scene.hud.battery_gauge.current_value, battery)
	scene.close_settings()
	for _index: int in range(120):
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_true((scene.hud.get_node("%WarningState") as Label).text.begins_with("DANGER"))
	assert_true((scene.hud.get_node("%PressureFeedback") as Label).text.contains("PRESSURE"))
	assert_eq(scene.hud.hull_gauge.current_value, scene.submarine.hull_system.hull)
	assert_lt(scene.hud.hull_gauge.current_value, 100.0)


func test_development_panel_wraps_inside_the_minimum_window() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var scene: MovementPrototype = PROTOTYPE.instantiate() as MovementPrototype
	scene.development_mode = true
	scene.settings_path = "user://bta013-debug-layout-no-settings.json"
	viewport.add_child(scene)
	scene.resource_panel.focus_test_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(800, 600))
	var panel: PrototypeResourcePanel = scene.resource_panel
	assert_true(bounds.encloses(panel.get_global_rect()))
	for name: String in ["%TestHull", "%TestBattery", "%TestOxygen", "%RefillAll", "%Pilot", "%Hull", "%Battery", "%Oxygen", "%Depletions"]:
		assert_true(panel.get_global_rect().encloses((panel.get_node(name) as Control).get_global_rect()), name)
	assert_false((scene.get_node("DevelopmentUI/Banner") as Control).visible, "The modal test panel replaces the development banner.")
