extends GutTest
class ThreeContacts:
	extends PassiveReceiver
	func _ready() -> void:
		pass
	func status_text() -> String:
		return "LISTENING"
	func contacts_snapshot() -> Array[Dictionary]:
		return [{"classification": &"mechanical", "bearing_degrees": -180.0, "signal_strength": 0.8, "remaining_seconds": 7.9},
			{"classification": &"geological", "bearing_degrees": 90.0, "signal_strength": 0.6, "remaining_seconds": 6.9},
			{"classification": &"marine_life", "bearing_degrees": -45.0, "signal_strength": 0.4, "remaining_seconds": 5.9}]

const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var _scene: ShelfPrototype
var _paths: Array[String] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = _spawn()
	await _frames()


func _spawn(parent: Node = null) -> ShelfPrototype:
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta043-ui-%d.json" % Time.get_ticks_usec()
	scene.expedition_path = scene.settings_path + ".expedition.json"
	_paths.append(scene.settings_path)
	if parent == null:
		add_child_autofree(scene)
	else:
		parent.add_child(scene)
	return scene


func _frames() -> void:
	for _index: int in range(5):
		await get_tree().process_frame


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS + InputBindings.MENU_ACTIONS:
		Input.action_release(action)
	for path: String in _paths:
		for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".upgrades.json", ".missions.json"]:
			for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected", ".invalid"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + stem + suffix))
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _tap(code: int, controller: bool = true) -> void:
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
	await get_tree().process_frame
	event = event.duplicate() as InputEvent
	if controller:
		(event as InputEventJoypadButton).pressed = false
	else:
		(event as InputEventKey).pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func test_accessibility_panel_controller_preview_save_cancel_and_scoped_defaults() -> void:
	_scene.open_accessibility()
	var panel: AccessibilityPanel = _scene.accessibility_panel
	assert_false(_scene.submarine.is_physics_processing())
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	assert_true(_scene.settings.snapshot().accessibility.reduced_flashing)
	panel.save_button.grab_focus()
	await _tap(JOY_BUTTON_A)
	assert_true(panel.status.text.contains("saved"))
	panel.toggles.reduced_motion.grab_focus()
	await _tap(JOY_BUTTON_A)
	await _tap(JOY_BUTTON_B)
	assert_false(_scene.settings.snapshot().accessibility.reduced_motion)
	assert_true(_scene.settings.snapshot().accessibility.reduced_flashing)
	assert_true(_scene.route_layer.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.route_menu.get_node("%Accessibility"))
	var loaded: SettingsStore = SettingsStore.new()
	assert_eq(loaded.load_settings(_scene.settings_path), OK)
	assert_true(loaded.snapshot().accessibility.reduced_flashing)


func test_remapped_pause_confirm_and_map_confirm_preserve_menu_accept_and_fixed_cancel() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	_scene.settings.remap(&"pause", key)
	_scene.settings.save_settings(_scene.settings_path)
	InputBindings.apply(_scene.settings.snapshot().bindings, 0.25)
	_scene.open_accessibility()
	_scene.accessibility_panel.toggles.high_contrast.grab_focus()
	await _tap(KEY_ENTER, false)
	assert_true(_scene.accessibility_panel.visible)
	assert_true(_scene.settings.snapshot().accessibility.high_contrast)
	await _tap(KEY_ESCAPE, false)
	assert_false(_scene.accessibility_panel.visible)


func test_disconnect_pauses_piloting_releases_thrust_and_keeps_confirmation_modal() -> void:
	_scene.resume_route()
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.device = 5
	event.pressed = true
	_scene.input_context.observe(event)
	Input.action_press("move_right")
	_scene.input_context.connection_changed(5, false)
	assert_false(_scene.submarine.is_physics_processing())
	assert_false(Input.is_action_pressed("move_right"))
	assert_true(_scene.route_layer.visible)
	_scene.route_menu.show_new_confirmation()
	_scene.input_context.observe(event)
	_scene.input_context.connection_changed(5, false)
	assert_true((_scene.route_menu.get_node("%NewConfirmation") as Control).visible)
	await _tap(KEY_ESCAPE, false)
	assert_false((_scene.route_menu.get_node("%NewConfirmation") as Control).visible)


func test_disconnect_cancels_remap_capture_and_keyboard_can_exit_embedded_settings() -> void:
	_scene._route_settings_requested()
	_scene._menu._begin_remap()
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.device = 5
	event.pressed = true
	_scene.input_context.observe(event)
	_scene.input_context.connection_changed(5, false)
	assert_false(_scene._menu.capturing)
	assert_true(_scene._menu.status.text.contains("disconnected"))
	await _tap(KEY_ESCAPE, false)
	assert_null(_scene._menu)
	assert_true(_scene.submarine.is_physics_processing())


func test_prompts_track_remaps_and_last_deliberate_device() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	_scene.settings.remap(&"sonar_ping", key)
	assert_true((_scene.hud.get_node("%SettingsHint") as Label).text.contains("G: sonar"))
	assert_false((_scene.hud.get_node("%SettingsHint") as Label).text.contains("F: sonar"))
	await _tap(JOY_BUTTON_DPAD_DOWN)
	assert_true((_scene.hud.get_node("%SettingsHint") as Label).text.contains("X: sonar"))
	await _tap(KEY_TAB, false)
	assert_true((_scene.hud.get_node("%SettingsHint") as Label).text.contains("G: sonar"))


func test_reduced_effects_change_presentation_only_and_new_pulses_inherit_preferences() -> void:
	var value: Dictionary = SettingsStore.default_accessibility()
	value.reduced_motion = true
	value.reduced_particles = true
	value.reduced_flashing = true
	_scene.settings.set_accessibility(value)
	await _frames()
	var atmosphere: Parallax2D = _scene.region.get_node("Atmosphere") as Parallax2D
	assert_eq(atmosphere.scroll_scale, Vector2.ZERO)
	assert_false((atmosphere.get_node("Motes") as Node2D).visible)
	assert_false(atmosphere.get_node("Motes").is_processing())
	assert_true(_scene.submarine.get_node("Visual").get("reduced_motion"))
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	await _frames()
	for node: Node in _scene.get_node("WorldRoot/WorldEffects").get_children():
		assert_true((node as SonarPulse).reduced_flashing)
	_scene.submarine.sonar.advance(0.6)
	assert_eq(_scene.discoveries.state_of(NarrativeService.MARKER), DiscoveryRegistry.State.DISCOVERED)
	assert_eq(_scene.submarine.resource_system.battery, 96.0)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), 1)


func test_large_hud_and_all_menu_controls_fit_or_scroll_at_supported_resolutions() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(800, 600)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = _spawn(viewport)
	var contacts: ThreeContacts = ThreeContacts.new()
	var receiver: AcousticReceiver = AcousticReceiver.new()
	receiver.name = "AcousticReceiver"
	contacts.add_child(receiver)
	viewport.add_child(contacts)
	scene.hud.bind_passive(contacts)
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "large"
	prefs.high_contrast = true
	scene.settings.set_accessibility(prefs)
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		viewport.size = size
		await _frames()
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
		for control: Control in [scene.hud.get_node("%InstrumentDeck"), scene.hud.get_node("%DepthPanel"), scene.get_node("UI/RouteGuide")]:
			assert_true(bounds.encloses(control.get_global_rect()), "%s at %s: %s" % [control.name, size, control.get_global_rect()])
		var passive: Control = scene.hud.get_node("%PassiveContacts") as Control
		var guide: Control = scene.get_node("UI/RouteGuide") as Control
		assert_lte(passive.get_global_rect().end.y, guide.get_global_rect().position.y, "All three contacts must clear the guidance panel")
		assert_gt(guide.get_global_rect().position.y, size.y * 0.5 + 16.0, "The guide must clear the vessel at screen center")
		# Stress the actual instrument slots with both damage notices and a threat.
		var threat: Control = scene.hud.get_node("%ThreatIndicator") as Control
		(threat.get_node("Content/Title") as Label).text = "PREDATOR ! WARN 2.5s"
		(threat.get_node("Content/Hint") as Label).text = "RETREAT ↓ PAST 115 m"
		threat.show()
		scene.hud._impact_applied(12.0, 240.0)
		scene.hud._pressure_applied(0.2)
		scene.accessibility_service.queue_fit()
		await _frames()
		var feedback: Control = scene.hud.get_node("Feedback") as Control
		assert_true(bounds.encloses(threat.get_global_rect()))
		assert_lte((scene.hud.get_node("%DepthPanel") as Control).get_global_rect().end.y, threat.get_global_rect().position.y)
		assert_lte(threat.get_global_rect().end.y, feedback.get_global_rect().position.y, "Threat must clear damage notices at %s: threat=%s depth=%s feedback=%s" % [size, threat.get_global_rect(), (scene.hud.get_node("%DepthPanel") as Control).get_global_rect(), feedback.get_global_rect()])
		assert_lte(feedback.get_global_rect().end.y, guide.get_global_rect().position.y)
		threat.hide()
		assert_gte((scene.hud.hull_gauge.get_node("%Value") as Label).get_theme_font_size("font_size"), 35)
		scene.open_story()
		await _frames()
		assert_true(scene.expedition_log.close_button.is_visible_in_tree())
		assert_true(bounds.encloses(scene.expedition_log.get_node("Margin").get_global_rect()))
		scene.close_story()
		var before: Control = scene.route_menu.get_node("%Accessibility") as Control
		before.grab_focus()
		scene.accessibility_service.apply()
		await _frames()
		assert_eq(viewport.gui_get_focus_owner(), before)
	prefs.ui_scale = "standard"
	scene.settings.set_accessibility(prefs)
	await _frames()
	assert_eq((scene.hud.hull_gauge.get_node("%Value") as Label).get_theme_font_size("font_size"), 28)


func test_research_and_notice_text_have_controller_reachable_scroll_controls() -> void:
	_scene.research.complete_scan(NarrativeService.PLATE)
	_scene.open_map()
	_scene.open_research()
	(_scene.research_log.get_node("%ScrollResearchDown") as Button).grab_focus()
	await _tap(JOY_BUTTON_A)
	assert_true(_scene.research_log.visible)
	_scene.close_research()
	_scene.close_map()
	_scene.resume_route()
	assert_eq(_scene.open_station(), OK)
	_scene.station_menu.show_board()
	assert_true((_scene.station_menu.get_node("%NoticeDown") as Button).is_visible_in_tree())
	_scene.station_menu.get_node("%NoticeDown").call("grab_focus")
	await _tap(JOY_BUTTON_A)
	assert_false(_scene.submarine.is_physics_processing())


func test_muted_large_controller_debrief_and_checkpoint_reload_keep_accessibility_separate() -> void:
	# Domain-adapter coverage; the native fixture separately pilots the complete route.
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "large"
	prefs.reduced_motion = true
	prefs.reduced_particles = true
	prefs.reduced_flashing = true
	_scene.settings.set_accessibility(prefs)
	var audio: Dictionary = _scene.settings.snapshot().audio
	audio.muted = true
	_scene.settings.set_audio(audio)
	assert_eq(_scene.settings.save_settings(_scene.settings_path), OK)
	_scene.open_story()
	_scene.expedition_log.begin_button.grab_focus()
	await _tap(JOY_BUTTON_A)
	await _tap(JOY_BUTTON_B)
	_scene.resume_route()
	_scene.submarine.set_physics_process(false)
	# Existing wavefront/scanner/route adapters, never invented narrative flags.
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	_scene.submarine.sonar.advance(0.6)
	_scene.submarine.global_position = Vector2(760, 480)
	assert_eq(_scene.submarine.scanner.request_scan(), OK)
	_scene.submarine.scanner.advance(3.0)
	_scene.submarine.sonar.advance(4.0)
	_scene.submarine.global_position = Vector2(3500, 650)
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	_scene.submarine.sonar.advance(0.2)
	_scene.route_check.sample(false, false, 0.1)
	_scene.route_check.sample(false, true, 0.1)
	_scene.submarine.global_position = _scene.region.spawn.global_position
	_scene.route_check.sample(true, false, 0.1)
	assert_eq(_scene.open_station(), OK)
	(_scene.station_menu.get_node("%OpenStationStory") as Control).grab_focus()
	await _tap(JOY_BUTTON_A)
	_scene.expedition_log.debrief_button.grab_focus()
	await _tap(JOY_BUTTON_A)
	assert_true(_scene.narrative.is_concluded())
	assert_true(_scene.settings.snapshot().audio.muted)
	assert_eq(_scene.settings.snapshot().accessibility, prefs)
	var loaded: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	loaded.settings_path = _scene.settings_path
	loaded.expedition_path = _scene.expedition_path
	add_child_autofree(loaded)
	await _frames()
	assert_true(loaded.settings.snapshot().audio.muted)
	assert_eq(loaded.settings.snapshot().accessibility, prefs)
	assert_true(loaded.narrative.is_concluded(), "Existing campaign format reloads without accessibility fields")
	assert_true(loaded.route_layer.visible)


func test_compact_font_floor_and_high_contrast_focus_restore_without_accumulation() -> void:
	var label: Label = _scene.hud.get_node("%SettingsHint") as Label
	var button: Button = _scene.route_menu.get_node("%Resume") as Button
	var original_size: int = label.get_theme_font_size("font_size")
	var original_focus: StyleBox = button.get_theme_stylebox("focus")
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "compact"
	prefs.high_contrast = true
	_scene.settings.set_accessibility(prefs)
	await _frames()
	assert_eq(label.get_theme_font_size("font_size"), maxi(16, roundi(original_size * 0.9)))
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
	assert_eq(focus.border_width_top, 4, "Focus differs by border thickness as well as color")
	_scene.accessibility_service.apply()
	assert_eq(label.get_theme_font_size("font_size"), maxi(16, roundi(original_size * 0.9)))
	_scene.settings.set_accessibility(SettingsStore.default_accessibility())
	await _frames()
	assert_eq(label.get_theme_font_size("font_size"), original_size)
	assert_eq(button.get_theme_stylebox("focus"), original_focus)
