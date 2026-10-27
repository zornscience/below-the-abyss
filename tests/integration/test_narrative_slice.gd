extends GutTest

const MAIN: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
var _scene: ShelfPrototype
var _paths: Array[String] = []


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = _spawn()
	await get_tree().process_frame


func _spawn(path: String = "", parent: Node = null) -> ShelfPrototype:
	var scene: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = path if not path.is_empty() else "user://bta042-integration-%d.json" % Time.get_ticks_usec()
	scene.expedition_path = scene.settings_path + ".expedition.json"
	_paths.append(scene.settings_path)
	if parent != null:
		parent.add_child(scene)
	else:
		add_child_autofree(scene)
	return scene


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	for path: String in _paths:
		for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".upgrades.json", ".missions.json"]:
			for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + stem + suffix))
	_paths.clear()
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _ids(scene: ShelfPrototype = _scene) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: NarrativeEntry in scene.narrative.available_entries():
		ids.append(entry.stable_id)
	return ids


func _evidence(scene: ShelfPrototype) -> void:
	scene.resume_route()
	scene.submarine.set_physics_process(false)
	scene.narrative.begin_survey()
	assert_eq(scene.submarine.sonar.request_ping(), OK)
	scene.submarine.sonar.advance(0.6)
	assert_false(scene.research.is_completed(NarrativeService.PLATE))
	scene.submarine.global_position = Vector2(760, 480)
	assert_eq(scene.submarine.scanner.request_scan(), OK)
	scene.submarine.scanner.advance(3.0)
	scene.submarine.sonar.advance(4.0)
	scene.submarine.global_position = Vector2(3500, 650)
	assert_eq(scene.submarine.sonar.request_ping(), OK)
	scene.submarine.sonar.advance(0.2)
	# Adapter integration: drive the existing route sampler, not new story flags.
	scene.route_check.sample(false, false, 0.1)
	scene.route_check.sample(false, true, 0.1)
	scene.submarine.global_position = scene.region.spawn.global_position
	scene.route_check.sample(true, false, 0.1)


func _debrief(scene: ShelfPrototype) -> void:
	assert_eq(scene.open_station(), OK)
	scene.open_station_story()
	assert_true(scene.expedition_log.visible)
	(scene.expedition_log.get_node("%SubmitDebrief") as Button).pressed.emit()
	assert_true(scene.narrative.is_concluded())


func test_start_page_briefing_and_log_are_skippable_paused_and_spoiler_free() -> void:
	var briefing: String = (_scene.route_menu.get_node("%Brief") as Label).text
	assert_true(briefing.contains("NERIS"))
	assert_true(briefing.contains("missing"))
	assert_true(briefing.contains("scan"))
	_scene.open_story()
	assert_false(_scene.submarine.is_physics_processing())
	assert_eq(_scene.expedition_log.entry_list.get_child_count(), 1)
	assert_false(_scene.expedition_log.detail.text.contains("They took the receiver"))
	assert_true(_scene.expedition_log.debrief_button.disabled)
	_scene.close_story()
	assert_true(_scene.route_layer.visible)
	_scene.resume_route()
	assert_true(_scene.submarine.is_physics_processing(), "No compulsory reading gate")


func test_actual_wavefront_and_scanner_unlock_evidence_without_passive_or_audio_discovery() -> void:
	_scene.resume_route()
	_scene.submarine.set_physics_process(false)
	_scene.ambient.advance(2.1)
	assert_eq(_ids(), [&"shelf-station-briefing"] as Array[StringName])
	assert_eq(_scene.submarine.sonar.request_ping(), OK)
	assert_false(_ids().has(&"shelf-damaged-marker"))
	_scene.submarine.sonar.advance(0.6)
	assert_true(_ids().has(&"shelf-damaged-marker"))
	assert_false(_ids().has(&"shelf-expedition-field-record"))
	_scene.submarine.global_position = Vector2(760, 480)
	_scene.submarine.scanner.request_scan()
	_scene.submarine.scanner.advance(3.0)
	assert_true(_ids().has(&"shelf-expedition-field-record"))
	assert_eq(_scene.submarine.sonar.active_pulse_count(), 1)
	assert_eq(_scene.predator.threat.phase, PredatorState.Phase.QUIET)
	assert_eq(_scene.submarine.resource_system.battery, 96.0)


func test_full_domain_adapter_debrief_requires_docking_and_is_idempotent() -> void:
	_evidence(_scene)
	watch_signals(_scene.narrative)
	watch_signals(_scene.missions)
	assert_true(_scene.narrative.can_debrief())
	assert_ne(_scene.narrative.debrief(_scene.station), OK, "Merely being at base does not dock")
	assert_false(_scene.narrative.is_concluded())
	_debrief(_scene)
	assert_signal_emit_count(_scene.narrative, "chapter_concluded", 1)
	assert_signal_emit_count(_scene.missions, "acknowledgement_claimed", 2)
	assert_true(_scene.expedition_log.detail.text.contains("They were preparing to listen to the silence"))
	assert_eq(_scene.narrative.debrief(_scene.station), ERR_ALREADY_EXISTS)
	_scene.narrative.begin_survey()
	assert_signal_emit_count(_scene.narrative, "chapter_concluded", 1)
	assert_signal_emit_count(_scene.missions, "acknowledgement_claimed", 2)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.submarine.resource_system.battery, 92.0, "No narrative resource cost/reward")


func test_checkpoint_reload_and_continue_reconstruct_same_log_without_story_events() -> void:
	_evidence(_scene)
	_debrief(_scene)
	_scene.close_story()
	_scene.close_station()
	_scene.open_route_menu()
	assert_eq(_scene.saves.save_current(), OK)
	var path: String = _scene.settings_path
	var expected: Array[StringName] = _ids()
	_scene.free()
	var events: Array[StringName] = []
	var observe: Callable = func(node: Node) -> void:
		if node is NarrativeService:
			(node as NarrativeService).record_unlocked.connect(func(id: StringName) -> void: events.append(id))
			(node as NarrativeService).chapter_concluded.connect(func() -> void: events.append(&"concluded"))
	get_tree().node_added.connect(observe)
	_scene = _spawn(path)
	assert_eq(_scene.saves.continue_expedition(), OK)
	get_tree().node_added.disconnect(observe)
	assert_eq(_ids(), expected)
	assert_true(_scene.narrative.is_concluded())
	assert_true(events.is_empty())
	assert_eq(ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string(_scene.expedition_path))).error, OK)
	assert_eq(int(JSON.parse_string(FileAccess.get_file_as_string(_scene.expedition_path)).schema_version), 5)


func test_restart_and_services_keep_records_and_do_not_repeat_debrief() -> void:
	_evidence(_scene)
	_debrief(_scene)
	var before: Array[StringName] = _ids()
	watch_signals(_scene.narrative)
	_scene.close_story()
	_scene.station.perform(&"all")
	_scene.close_station()
	_scene.open_route_menu()
	_scene.restart_route()
	assert_eq(_ids(), before)
	assert_true(_scene.narrative.is_concluded())
	assert_signal_not_emitted(_scene.narrative, "record_unlocked")
	assert_signal_not_emitted(_scene.narrative, "chapter_concluded")


func test_prior_v1_checkpoint_records_unlock_without_migration_or_overwrite() -> void:
	var path: String = "user://bta042-v1-%d.json" % Time.get_ticks_usec()
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json")
	var file: FileAccess = FileAccess.open(path + ".expedition.json", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var legacy: ShelfPrototype = _spawn(path)
	assert_true(_ids(legacy).has(&"shelf-expedition-field-record"))
	assert_eq(FileAccess.get_file_as_string(path + ".expedition.json"), text)
	assert_eq(legacy.saves.continue_expedition(), OK)


func test_corrupt_checkpoint_preserved_while_briefing_stays_readable_and_actions_block() -> void:
	var path: String = "user://bta042-corrupt-%d.json" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(path + ".expedition.json", FileAccess.WRITE)
	file.store_string("broken checkpoint")
	file.close()
	var broken: ShelfPrototype = _spawn(path)
	broken.open_story()
	assert_true(broken.expedition_log.begin_button.disabled)
	assert_eq(broken.narrative.begin_survey(), ERR_UNAUTHORIZED)
	assert_eq(_ids(broken), [&"shelf-station-briefing"] as Array[StringName])
	assert_eq(FileAccess.get_file_as_string(path + ".expedition.json"), "broken checkpoint")


func _tap(code: int, controller: bool) -> void:
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


func test_keyboard_can_open_accept_scroll_and_close_without_a_mouse() -> void:
	(_scene.route_menu.get_node("%OpenStory") as Button).grab_focus()
	await _tap(KEY_ENTER, false)
	assert_true(_scene.expedition_log.visible)
	await _tap(KEY_TAB, false)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.expedition_log.begin_button)
	await _tap(KEY_ENTER, false)
	assert_eq(_scene.missions.snapshot()["shelf-expedition"].state, "accepted")
	assert_true(_scene.expedition_log.detail.text.contains("Survey accepted"))
	await _tap(KEY_ESCAPE, false)
	assert_false(_scene.expedition_log.visible)
	assert_false(_scene.submarine.is_physics_processing())


func test_controller_can_read_station_debrief_and_return_safely_to_piloting() -> void:
	_evidence(_scene)
	_scene.open_station()
	(_scene.station_menu.get_node("%OpenStationStory") as Button).grab_focus()
	await _tap(JOY_BUTTON_A, true)
	assert_true(_scene.expedition_log.visible)
	await _tap(JOY_BUTTON_DPAD_DOWN, true)
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.expedition_log.debrief_button)
	await _tap(JOY_BUTTON_A, true)
	assert_true(_scene.narrative.is_concluded())
	await _tap(JOY_BUTTON_B, true)
	assert_true(_scene.station_menu.visible)
	assert_false(_scene.submarine.is_physics_processing())
	await _tap(JOY_BUTTON_B, true)
	assert_true(_scene.submarine.is_physics_processing())


func test_log_controls_readable_at_reference_and_compact_sizes_with_scroll_actions() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(800, 600)
	add_child_autofree(viewport)
	var scene: ShelfPrototype = _spawn("", viewport)
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		viewport.size = size
		scene.open_story()
		await get_tree().process_frame
		await get_tree().process_frame
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
		for control: Control in [scene.expedition_log.close_button, scene.expedition_log.begin_button, scene.expedition_log.debrief_button, scene.expedition_log.get_node("%StoryScroll"), scene.expedition_log.get_node("%StoryDown")]:
			assert_true(bounds.encloses(control.get_global_rect()), control.name)
		assert_gte(scene.expedition_log.detail.get_theme_font_size("font_size"), 18)
		(scene.expedition_log.get_node("%StoryDown") as Button).pressed.emit()
		if size.x == 800:
			assert_gt((scene.expedition_log.get_node("%StoryScroll") as ScrollContainer).scroll_vertical, 0)
		scene.close_story()


func test_partial_debrief_write_failure_keeps_first_ack_and_retry_cannot_duplicate_it() -> void:
	_evidence(_scene)
	_scene.open_station()
	var original: Callable = _scene.missions.store.checkpoint_writer
	var calls: Array[int] = [0]
	_scene.missions.store.checkpoint_writer = func(kind: StringName, proposed: Variant) -> Error:
		calls[0] += 1
		return ERR_FILE_CANT_WRITE if calls[0] == 2 else original.call(kind, proposed) as Error
	watch_signals(_scene.missions)
	watch_signals(_scene.narrative)
	assert_eq(_scene.narrative.debrief(_scene.station), ERR_FILE_CANT_WRITE)
	assert_eq(_scene.missions.snapshot()[String(NarrativeService.MAIN)].state, "claimed")
	assert_eq(_scene.missions.snapshot()[String(NarrativeService.SCIENCE)].state, "completed")
	assert_false(_scene.narrative.is_concluded())
	assert_signal_emit_count(_scene.missions, "acknowledgement_claimed", 1)
	assert_signal_not_emitted(_scene.narrative, "chapter_concluded")
	_scene.missions.store.checkpoint_writer = original
	assert_eq(_scene.narrative.debrief(_scene.station), OK)
	assert_signal_emit_count(_scene.missions, "acknowledgement_claimed", 2)
	assert_signal_emit_count(_scene.narrative, "chapter_concluded", 1)
	assert_eq(_scene.narrative.debrief(_scene.station), ERR_ALREADY_EXISTS)
