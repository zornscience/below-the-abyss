extends GutTest

const SCENE: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
const EXAMPLE: PackedScene = preload("res://scenes/main/passive_sonar_example.tscn")
var _scene: ShelfPrototype
var _old_fps: int


func before_each() -> void:
	_old_fps = Engine.max_fps
	_scene = SCENE.instantiate() as ShelfPrototype
	_scene.development_mode = true
	_scene.settings_path = "user://bta022-no-settings-%d.json" % Time.get_ticks_usec()
	add_child_autofree(_scene)
	await _frames(2)


func after_each() -> void:
	Engine.max_fps = _old_fps
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func test_example_demonstrates_receive_only_contact_and_expiry() -> void:
	var example: PassiveSonarExample = EXAMPLE.instantiate() as PassiveSonarExample
	example.quit_when_finished = false
	add_child_autofree(example)
	assert_eq(example.result, OK)


func test_real_shelf_receives_ambient_without_ping_energy_or_active_pulses() -> void:
	assert_eq(_scene.submarine.passive.status_text(), "PAUSED")
	_scene.resume_route()
	watch_signals(_scene.submarine.sonar)
	await _frames(200)
	var contacts: Array[Dictionary] = _scene.submarine.passive.contacts_snapshot()
	assert_eq(contacts.size(), 2)
	assert_true(contacts.any(func(contact: Dictionary) -> bool: return contact.classification == &"mechanical"))
	assert_true(contacts.any(func(contact: Dictionary) -> bool: return contact.classification == &"geological"))
	assert_almost_eq(_scene.submarine.resource_system.battery, 100.0 - 200.0 / 60.0 * 0.005, 0.001)
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 0)
	assert_signal_not_emitted(_scene.submarine.sonar, "pulse_emitted")
	assert_false((_scene.region.get_node("SonarTargets/shelf-marker") as SonarRevealTarget).is_revealed())
	var panel: PassiveContactsPanel = _scene.hud.get_node("%PassiveContacts") as PassiveContactsPanel
	assert_true((panel.get_node("%PassiveHeader") as Label).text.contains("LISTENING"))
	assert_false((panel.get_node("%PassiveEmpty") as Label).visible)


func test_route_settings_and_debug_pause_freeze_ambient_schedule_contacts_and_expiry() -> void:
	_scene.resume_route()
	await _frames(190)
	for mode: int in range(3):
		if mode == 0:
			_scene.open_route_menu()
		elif mode == 1:
			_scene.open_settings()
		else:
			_scene.resource_panel.focus_test_controls()
		var contacts: Array[Dictionary] = _scene.submarine.passive.contacts_snapshot()
		var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
		await _frames(20)
		assert_eq(_scene.submarine.passive.status_text(), "PAUSED")
		assert_eq(_scene.submarine.passive.contacts_snapshot(), contacts)
		assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
		if mode == 0:
			_scene.resume_route()
		elif mode == 1:
			_scene.close_settings()
		else:
			(_scene.resource_panel.get_node("%Pilot") as Button).pressed.emit()
		assert_eq(_scene.submarine.passive.status_text(), "LISTENING")


func test_restart_clears_contacts_restarts_ambient_epoch_and_keeps_active_history() -> void:
	_scene.resume_route()
	await _frames(190)
	var previous: Array[Dictionary] = _scene.submarine.passive.contacts_snapshot()
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	_scene.restart_route()
	assert_true(_scene.submarine.passive.contacts_snapshot().is_empty())
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history + 1)
	await _frames(190)
	var next: Array[Dictionary] = _scene.submarine.passive.contacts_snapshot()
	assert_eq(next.size(), 2)
	assert_ne(previous[0].event_id, next[0].event_id)
	assert_eq(_scene.submarine.sonar.echo_count(), 2, "Active sonar remains independent and functional.")


func test_source_free_removes_contact_immediately_and_no_passive_world_reveal_occurs() -> void:
	_scene.resume_route()
	await _frames(190)
	var source: AmbientSoundEmitter = _scene.ambient.get_node("station-machinery") as AmbientSoundEmitter
	source.free()
	assert_eq(_scene.submarine.passive.contacts_snapshot().size(), 1)
	assert_eq(_scene.submarine.passive.contacts_snapshot()[0].classification, &"geological")
	for target: Node in _scene.region.get_node("SonarTargets").get_children():
		assert_false((target as SonarRevealTarget).is_revealed())


func _check_controls(node: Node, bounds: Rect2) -> void:
	if node is Control:
		var control: Control = node as Control
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)
		if control.is_visible_in_tree():
			assert_true(bounds.encloses(control.get_global_rect()), String(node.name))
	if node is Label and (node as Label).is_visible_in_tree():
		var label: Label = node as Label
		for line: String in label.text.split("\n"):
			assert_lte(label.get_theme_font("font").get_string_size(line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x, label.size.x + 1.0, String(node.name))
	for child: Node in node.get_children():
		_check_controls(child, bounds)


func test_three_contact_hud_fits_reference_and_minimum_window_without_focus() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta022-layout-no-settings.json"
	viewport.add_child(scene)
	scene.submarine.position = Vector2(1250, 480)
	scene.resume_route()
	await _frames(250)
	scene.open_route_menu()
	assert_eq(scene.submarine.passive.contacts_snapshot().size(), 3)
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(1920, 1080)]:
		viewport.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		var panel: Control = scene.hud.get_node("%PassiveContacts") as Control
		_check_controls(panel, Rect2(Vector2.ZERO, Vector2(size)))
		assert_lt(panel.get_global_rect().end.x, size.x * 0.5 - 32.0, "Keep the vessel's central space clear.")
		assert_lte(panel.get_global_rect().end.y, (scene.get_node("UI/RouteGuide") as Control).get_global_rect().position.y)
