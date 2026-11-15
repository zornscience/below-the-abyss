extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/shelf_prototype_fixture.tscn")
var scene: ShelfPrototype
var observer: PlaytestObserver
var path: String


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	path = "user://bta044-integration-%d" % Time.get_ticks_usec()
	scene = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = path + ".json"
	scene.expedition_path = path + ".expedition.json"
	add_child_autofree(scene)
	observer = PlaytestObserver.new()
	scene.add_child(observer)
	observer.setup(scene)
	observer.store.directory = path + "-reports"


func after_each() -> void:
	if observer.recorder.recording:
		observer.stop()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(observer.store.directory)):
		for name: String in DirAccess.get_files_at(observer.store.directory):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(observer.store.directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(observer.store.directory))
	for stem: String in [".json", ".expedition.json", ".json.discoveries.json", ".json.research.json", ".json.upgrades.json", ".json.missions.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + stem + suffix))
	for action: StringName in InputBindings.ACTIONS + InputBindings.MENU_ACTIONS:
		Input.action_release(action)


func test_normal_mode_has_no_ui_recorder_or_files_and_opt_out_does_not_observe() -> void:
	assert_null(scene.playtest_observer)
	assert_false((scene.route_menu.get_node("%Playtest") as Button).visible)
	scene.submarine.sonar.request_ping()
	assert_eq(observer.recorder.snapshot(), {})
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(observer.store.directory)))


func test_opt_in_observes_actual_domain_events_and_idempotent_signals() -> void:
	assert_eq(observer.start(), OK)
	assert_eq(scene.narrative.begin_survey(), OK)
	scene.resume_route()
	scene.submarine.set_physics_process(false)
	assert_eq(scene.submarine.sonar.request_ping(), OK)
	scene.submarine.sonar.advance(0.6)
	scene.submarine.global_position = Vector2(760,480)
	assert_eq(scene.submarine.scanner.request_scan(), OK)
	scene.submarine.scanner.advance(3.0)
	scene.research.scan_completed.emit(NarrativeService.PLATE)
	var report: Dictionary = observer.recorder.snapshot()
	assert_eq(report.counts.sonar, 1)
	assert_eq(report.counts.discovery, 1)
	assert_eq(report.counts.scan_started, 1)
	assert_eq(report.counts.scan_completed, 1)
	assert_eq(report.counts.mission_accepted, 2)
	assert_eq(report.counts.mission_completed, 1)
	assert_true(PlaytestReport.valid(report))


func test_continue_and_restart_do_not_replay_progress_damage_or_warnings() -> void:
	observer.start()
	scene.narrative.begin_survey()
	scene.submarine.sonar.request_ping()
	scene.submarine.sonar.advance(0.6)
	scene.submarine.hull_system.apply_damage(5.0, &"collision")
	assert_eq(scene.saves.save_current(), OK)
	var before: Dictionary = observer.recorder.snapshot().counts
	assert_eq(scene.saves.continue_expedition(), OK)
	scene.restart_route()
	var after: Dictionary = observer.recorder.snapshot().counts
	for key: String in ["discovery", "scan_completed", "mission_accepted", "mission_completed", "damage", "resource_warning", "chapter_completed", "station_return"]:
		assert_eq(after[key], before[key], key)
	assert_eq(after.milestone, before.milestone + 1, "Direct developer restart has no UI request signal; Continue is recorded once")
	assert_eq(scene.submarine.hull_system.hull, 100.0)
	assert_true(PlaytestReport.valid(observer.recorder.snapshot()))


func test_reporting_never_mutates_campaign_acoustic_history_or_supplies() -> void:
	var before: Dictionary = scene.saves.snapshot()
	var history: int = (scene.get_node("AcousticBus") as AcousticBus).history_count()
	observer.start()
	observer.export_report()
	observer.stop()
	assert_eq(scene.saves.snapshot(), before)
	assert_eq((scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	assert_false(observer.recorder.recording)
	var frozen: Dictionary = observer.recorder.snapshot()
	scene.submarine.sonar.request_ping()
	assert_eq(observer.recorder.snapshot(), frozen)


func test_route_samples_count_repeated_base_returns_without_extra_progression() -> void:
	observer.start()
	for _index: int in range(2):
		scene.route_check.sample(false, false, 0.1)
		scene.route_check.sample(true, false, 0.1)
	assert_eq(observer.recorder.snapshot().counts.station_return, 2)
	assert_eq(scene.route_check.stage, GrayboxRouteCheck.Stage.OUTBOUND)
	scene.route_check.synchronize_base_state(false)
	var before: int = observer.recorder.snapshot().counts.station_return
	assert_eq(before, 2, "Silent restore must never count a visit")


func test_resource_episodes_damage_failure_and_disable_are_distinct() -> void:
	observer.start()
	scene.submarine.resource_system.consume_battery(85.0)
	scene.submarine.resource_system.consume_battery(1.0)
	scene.submarine.hull_system.apply_damage(100.0, &"collision")
	var data: Dictionary = observer.recorder.snapshot()
	assert_eq(data.counts.damage, 1)
	assert_eq(data.damage_total, 100.0)
	# Rewritten on purpose (designer decision 6): failure fires on the real Halcyon
	# recovery trigger, which the legacy prototype fixture does not have. A depleted
	# hull here is a resource warning only. Campaign coverage: test_vessel_recovery.gd.
	assert_eq(int(data.counts.get("failure", 0)), 0, "Depletion alone is not a failure event")
	assert_eq(data.counts.resource_warning, 3)
	assert_eq(observer.stop(), OK)
	assert_eq(observer.recorder.snapshot().status, "disabled")


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


func test_controller_can_decline_opt_in_export_disable_and_leave_modal() -> void:
	var panel: PlaytestPanel = PlaytestPanel.new()
	add_child_autofree(panel)
	panel.present(observer)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.close_button, "Default focus does not consent")
	await get_tree().process_frame
	assert_lt(panel.close_button.get_global_rect().position.y, panel.start_button.get_global_rect().position.y, "Safe default is above the disclosure, so focus starts at its top")
	await _tap(JOY_BUTTON_B)
	assert_false(panel.visible)
	assert_false(observer.recorder.recording)
	panel.present(observer)
	panel.start_button.grab_focus()
	await _tap(JOY_BUTTON_A)
	assert_true(observer.recorder.recording)
	panel.export_button.grab_focus()
	await _tap(JOY_BUTTON_A)
	panel.stop_button.grab_focus()
	await _tap(JOY_BUTTON_A)
	assert_false(observer.recorder.recording)
	await _tap(JOY_BUTTON_B)
	assert_false(panel.visible)
