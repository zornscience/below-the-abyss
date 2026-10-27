extends GutTest

const STORY: NarrativeCatalog = preload("res://resources/narrative/shelf_chapter.tres")
var _story: NarrativeService
var _missions: MissionService
var _points: DiscoveryRegistry
var _research: ResearchRegistry
var _route: GrayboxRouteCheck
var _path: String


func before_each() -> void:
	_path = "user://bta042-unit-%d.json" % Time.get_ticks_usec()
	_points = DiscoveryRegistry.new()
	_research = ResearchRegistry.new()
	_missions = MissionService.new()
	_story = NarrativeService.new()
	_route = GrayboxRouteCheck.new()
	add_child_autofree(_points)
	add_child_autofree(_research)
	add_child_autofree(_missions)
	add_child_autofree(_story)
	_points.configure(ExpeditionSchema.DISCOVERIES)
	_research.configure(ExpeditionSchema.RESEARCH)
	assert_eq(_missions.setup(ExpeditionSchema.MISSIONS, _points, _research, _route, _path), OK)
	assert_eq(_story.setup(STORY, _missions, _points, _research), OK)


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))


func _ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: NarrativeEntry in _story.available_entries():
		result.append(entry.stable_id)
	return result


func _evidence() -> void:
	_points.discover(NarrativeService.MARKER, &"test/marker")
	_research.complete_scan(NarrativeService.PLATE)
	_points.discover(NarrativeService.SPIRES, &"test/spires")


func _return() -> void:
	_route.sample(false, false, 1.0)
	_route.sample(false, true, 1.0)
	_route.sample(true, false, 1.0)


func test_catalog_has_valid_unique_stable_records_and_rejects_invalid_authored_text() -> void:
	assert_true(STORY.is_valid())
	assert_eq(STORY.entries.size(), 8)
	var broken: NarrativeCatalog = STORY.duplicate(true) as NarrativeCatalog
	broken.entries.append(broken.entries[0])
	assert_false(broken.is_valid())
	broken = STORY.duplicate(true) as NarrativeCatalog
	broken.entries[0].text = ""
	assert_false(broken.is_valid())
	broken = STORY.duplicate(true) as NarrativeCatalog
	broken.entries[0].evidence = 100 as NarrativeEntry.Evidence
	assert_false(broken.is_valid())
	broken = STORY.duplicate(true) as NarrativeCatalog
	broken.entries[0].stable_id = &"INVALID ID"
	assert_false(broken.is_valid())


func test_opening_briefing_is_always_readable_while_all_future_evidence_is_hidden() -> void:
	assert_eq(_ids(), [&"shelf-station-briefing"] as Array[StringName])
	var text: String = _story.available_entries()[0].text
	for phrase: String in ["NERIS", "Shelf Base", "expedition", "sequence", "scan", "Return"]:
		assert_true(text.contains(phrase), phrase)
	assert_false(_story.is_concluded())
	assert_false(_story.can_debrief())
	assert_true(_story.guidance().contains("PLATE"))


func test_intentional_acceptance_uses_existing_two_missions_and_is_repeat_safe() -> void:
	watch_signals(_missions)
	assert_eq(_story.begin_survey(), OK)
	var before: Dictionary = _missions.snapshot()
	assert_eq(before["shelf-expedition"].state, "accepted")
	assert_eq(before["shelf-calibration-study"].state, "accepted")
	assert_true(_ids().has(&"shelf-survey-orders"))
	assert_eq(_story.begin_survey(), OK)
	assert_eq(_missions.snapshot(), before)
	assert_signal_not_emitted(_missions, "acknowledgement_claimed")


func test_discovery_is_not_scan_and_primary_record_requires_deliberate_scientific_completion() -> void:
	watch_signals(_story)
	_points.discover(NarrativeService.MARKER, &"test/marker")
	assert_true(_ids().has(&"shelf-damaged-marker"))
	assert_false(_ids().has(&"shelf-expedition-field-record"))
	_research.complete_scan(NarrativeService.PLATE)
	assert_true(_ids().has(&"shelf-expedition-field-record"))
	assert_signal_emit_count(_story, "record_unlocked", 2)
	assert_eq(_research.complete_scan(NarrativeService.PLATE), ERR_ALREADY_EXISTS)
	assert_eq(_points.discover(NarrativeService.MARKER, &"test/duplicate"), ERR_ALREADY_EXISTS)
	assert_signal_emit_count(_story, "record_unlocked", 2)


func test_out_of_order_prior_scan_discovery_and_completed_route_are_credited_on_acceptance() -> void:
	_evidence()
	_return()
	assert_eq(_story.begin_survey(), OK)
	assert_eq(_missions.snapshot()["shelf-expedition"].state, "completed")
	assert_eq(_missions.snapshot()["shelf-calibration-study"].state, "completed")
	assert_true(_story.can_debrief())
	assert_true(_story.returned())
	assert_false(_story.is_concluded())
	assert_eq(_story.debrief(null), ERR_UNAVAILABLE)


func test_return_before_scan_and_scan_after_return_never_softlock() -> void:
	_story.begin_survey()
	_points.discover(NarrativeService.SPIRES, &"test/spires")
	_return()
	assert_true(_story.returned())
	assert_false(_story.can_debrief())
	assert_true(_story.guidance().contains("PLATE"))
	_research.complete_scan(NarrativeService.PLATE)
	assert_true(_story.can_debrief())
	assert_true(_story.guidance().contains("DEBRIEF"))


func test_restart_telemetry_does_not_erase_permanent_return_objective_or_records() -> void:
	_story.begin_survey()
	_evidence()
	_return()
	var before: Array[StringName] = _ids()
	_route.reset()
	assert_eq(_ids(), before)
	assert_true(_story.can_debrief())
	assert_true(_story.returned())


func test_optional_geology_is_not_required_for_debrief() -> void:
	_story.begin_survey()
	_evidence()
	_return()
	assert_true(_story.can_debrief())
	assert_false(_ids().has(&"shelf-optional-strata-note"))
	_research.complete_scan(&"shelf-overlook-formation")
	assert_true(_ids().has(&"shelf-optional-strata-note"))


func test_restore_is_silent_and_records_do_not_duplicate_when_loaded_or_reconciled() -> void:
	_story.begin_survey()
	_evidence()
	_return()
	var records: Dictionary = _missions.snapshot()
	records["shelf-expedition"].state = "claimed"
	records["shelf-calibration-study"].state = "claimed"
	watch_signals(_story)
	assert_eq(_missions.restore_records(records), OK)
	assert_true(_story.is_concluded())
	assert_signal_not_emitted(_story, "record_unlocked")
	assert_signal_not_emitted(_story, "chapter_concluded")
	_story.begin_survey()
	_missions.reconcile()
	assert_signal_not_emitted(_story, "record_unlocked")
	assert_signal_not_emitted(_story, "chapter_concluded")
	assert_eq(_ids().count(&"shelf-concluding-debrief"), 1)


func test_invalid_setup_and_failed_write_do_not_claim_or_hide_progress() -> void:
	assert_eq(_story.setup(STORY, _missions, _points, _research), ERR_ALREADY_IN_USE)
	var other: NarrativeService = NarrativeService.new()
	add_child_autofree(other)
	assert_eq(other.setup(null, _missions, _points, _research), ERR_INVALID_PARAMETER)
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	assert_ne(_story.begin_survey(), OK)
	assert_eq(_missions.snapshot()["shelf-expedition"].state, "available")
	assert_eq(FileAccess.get_file_as_string(_path), "corrupt")


func test_same_story_progress_at_30_60_120_simulation_steps() -> void:
	var snapshots: Array[Dictionary] = []
	for steps: int in [30, 60, 120]:
		var route: GrayboxRouteCheck = GrayboxRouteCheck.new()
		var missions: MissionService = MissionService.new()
		var story: NarrativeService = NarrativeService.new()
		add_child_autofree(missions)
		add_child_autofree(story)
		var path: String = _path + str(steps)
		missions.setup(ExpeditionSchema.MISSIONS, _points, _research, route, path)
		story.setup(STORY, missions, _points, _research)
		story.begin_survey()
		_evidence()
		for _step: int in range(steps):
			route.sample(false, false, 1.0 / steps)
		route.sample(false, true, 0.0)
		route.sample(true, false, 0.0)
		snapshots.append(missions.snapshot())
		assert_true(story.can_debrief())
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	assert_eq(snapshots[0], snapshots[1])
	assert_eq(snapshots[1], snapshots[2])
