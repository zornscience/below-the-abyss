extends GutTest
var recorder: PlaytestRecorder


func before_each() -> void:
	recorder = PlaytestRecorder.new()


func test_disabled_by_default_and_no_data_before_opt_in() -> void:
	assert_false(recorder.recording)
	assert_eq(recorder.snapshot(), {})
	assert_eq(recorder.record("sonar", "active_ping"), ERR_UNAVAILABLE)
	assert_eq(recorder.advance(1.0, true), ERR_UNAVAILABLE)


func test_random_sessions_build_identity_and_valid_lifecycle() -> void:
	assert_eq(recorder.begin(), OK)
	var first: String = recorder.snapshot().session_id
	assert_true(PlaytestReport.hex_id(first, 32))
	assert_true(PlaytestReport.valid(recorder.snapshot()))
	assert_eq(recorder.begin(), ERR_ALREADY_IN_USE)
	assert_eq(recorder.finish(), OK)
	assert_true(PlaytestReport.valid(recorder.snapshot()))
	assert_eq(recorder.begin("bad"), ERR_INVALID_PARAMETER)
	assert_eq(recorder.begin("a".repeat(40)), OK)
	assert_ne(recorder.snapshot().session_id, first)


func test_counts_duplicate_ids_and_bounded_history_preserve_totals() -> void:
	recorder.begin()
	assert_eq(recorder.record("sonar", "active_ping", 0.0, "ping:1"), OK)
	assert_eq(recorder.record("sonar", "active_ping", 0.0, "ping:1"), ERR_ALREADY_EXISTS)
	for _index: int in range(600):
		recorder.record("damage", "pressure", 0.1)
	var report: Dictionary = recorder.snapshot()
	assert_eq(report.counts.sonar, 1)
	assert_eq(report.counts.damage, 600)
	assert_eq(report.events.size(), 512)
	assert_eq(report.omitted_events, 90)
	assert_almost_eq(report.damage_total, 60.0, 0.00001)
	assert_true(PlaytestReport.valid(report))


func test_exact_split_timing_completion_and_thirty_sixty_one_twenty_steps() -> void:
	for steps: int in [30, 60, 120]:
		var run: PlaytestRecorder = PlaytestRecorder.new()
		run.begin()
		for _index: int in range(steps):
			run.advance(1.0 / steps, true)
		run.advance(2.0, false)
		assert_eq(run.record("chapter_completed", "the_quiet_run"), OK)
		assert_eq(run.record("chapter_completed", "the_quiet_run"), ERR_ALREADY_EXISTS)
		var data: Dictionary = run.snapshot()
		assert_almost_eq(data.active_seconds, 1.0, 0.000001)
		assert_almost_eq(data.menu_seconds, 2.0, 0.000001)
		assert_almost_eq(data.completion_seconds, 3.0, 0.000001)
		assert_true(PlaytestReport.valid(data))
	assert_eq(recorder.begin(), OK)
	assert_eq(recorder.advance(NAN, true), ERR_INVALID_PARAMETER)
	assert_eq(recorder.advance(-1.0, true), ERR_INVALID_PARAMETER)


func test_privacy_allowlist_rejects_arbitrary_keys_text_and_invalid_numbers() -> void:
	recorder.begin()
	assert_eq(recorder.record("raw_input", "key"), ERR_INVALID_PARAMETER)
	assert_eq(recorder.record("discovery", "someone@example.com"), ERR_INVALID_PARAMETER)
	assert_eq(recorder.record("damage", "impact", INF), ERR_INVALID_PARAMETER)
	var data: Dictionary = recorder.snapshot()
	for key: String in ["name", "email", "ip", "device_id", "position", "keyboard"]:
		var bad: Dictionary = data.duplicate(true)
		bad[key] = "unrelated"
		assert_false(PlaytestReport.valid(bad))
	data.events[0].detail = "arbitrary user text"
	assert_false(PlaytestReport.valid(data))


func test_store_roundtrip_text_interrupted_checkpoint_and_corruption_preservation() -> void:
	var store: PlaytestStore = PlaytestStore.new()
	store.directory = "user://bta044-store-%d" % Time.get_ticks_usec()
	recorder.begin()
	recorder.advance(5.0, true)
	var data: Dictionary = recorder.snapshot()
	assert_eq(store.write_report(data, true), OK)
	var path: String = store.directory.path_join(data.session_id + ".json")
	assert_eq(store.read_report(path).error, OK)
	assert_true(PlaytestReport.summary(store.read_report(path).data).contains("INTERRUPTED"))
	assert_true(FileAccess.get_file_as_string(store.directory.path_join(data.session_id + "-summary.txt")).contains(data.session_id))
	recorder.finish("quit")
	assert_eq(store.write_report(recorder.snapshot(), true), OK)
	assert_eq(store.read_report(path + ".bak").data.status, "active")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	assert_eq(store.read_report(path).error, ERR_INVALID_DATA)
	assert_eq(store.write_report(recorder.snapshot()), ERR_INVALID_DATA)
	assert_eq(FileAccess.get_file_as_string(path), "corrupt")
	for suffix: String in [".json", ".json.bak", "-summary.txt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.directory.path_join(data.session_id + suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.directory))


func test_authored_creature_hearing_survives_binary_resource_roundtrip() -> void:
	# Export converts .tres to binary; nested default Resources must be explicit.
	for name: String in ["shelf_observer", "shelf_predator"]:
		var authored: CreatureProfile = load("res://resources/creatures/" + name + ".tres") as CreatureProfile
		var path: String = "user://bta044-" + name + ".res"
		assert_eq(ResourceSaver.save(authored, path), OK)
		var restored: CreatureProfile = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CreatureProfile
		assert_true(restored.is_valid())
		assert_not_null(restored.hearing)
		assert_eq(restored.hearing.accepted_event_types, authored.hearing.accepted_event_types)
		assert_eq(restored.hearing.maximum_range_units, authored.hearing.maximum_range_units)
		assert_eq(restored.navigation_bounds, authored.navigation_bounds)
		assert_eq(restored.patrol_points, authored.patrol_points)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
