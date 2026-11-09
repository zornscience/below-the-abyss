extends GutTest

const CATALOG: MissionCatalog = preload("res://resources/missions/shelf_missions.tres")
const MAIN: StringName = &"shelf-expedition"
const OPTIONAL: StringName = &"shelf-calibration-study"
var _service: MissionService
var _discoveries: DiscoveryRegistry
var _research: ResearchRegistry
var _route: GrayboxRouteCheck
var _path: String


func before_each() -> void:
	_discoveries = DiscoveryRegistry.new()
	_research = ResearchRegistry.new()
	_route = GrayboxRouteCheck.new()
	add_child_autofree(_discoveries)
	add_child_autofree(_research)
	_discoveries.configure(load("res://resources/regions/shelf_discoveries.tres") as DiscoveryCatalog)
	_research.configure(load("res://resources/regions/shelf_research.tres") as ResearchCatalog)
	_path = "user://bta034-unit-%d.json" % Time.get_ticks_usec()
	_service = _new_service()


func _new_service() -> MissionService:
	var service: MissionService = MissionService.new()
	add_child_autofree(service)
	assert_eq(service.setup(CATALOG, _discoveries, _research, _route, _path), OK)
	return service


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))


func _finish_route(delta: float = 1.0) -> void:
	_route.sample(false, false, delta)
	_route.sample(false, true, delta)
	_route.sample(true, false, delta)


func test_catalog_validation_stable_ids_target_validation_and_defensive_snapshots() -> void:
	assert_true(CATALOG.is_valid())
	assert_eq(CATALOG.missions.size(), 2)
	var invalid: MissionCatalog = CATALOG.duplicate(true) as MissionCatalog
	invalid.missions[0].objectives[0].target_id = &"unknown"
	var service: MissionService = MissionService.new()
	add_child_autofree(service)
	assert_eq(service.setup(invalid, _discoveries, _research, _route, _path), ERR_INVALID_PARAMETER)
	invalid = CATALOG.duplicate(true) as MissionCatalog
	invalid.missions[1].stable_id = MAIN
	assert_false(invalid.is_valid())
	invalid = CATALOG.duplicate(true) as MissionCatalog
	invalid.missions[1].acknowledgement_id = invalid.missions[0].acknowledgement_id
	assert_false(invalid.is_valid())
	invalid = CATALOG.duplicate(true) as MissionCatalog
	invalid.missions[0].objectives.append(invalid.missions[0].objectives[0])
	assert_false(invalid.is_valid())
	invalid = CATALOG.duplicate(true) as MissionCatalog
	invalid.missions[0].objectives[0].description = ""
	assert_false(invalid.is_valid())
	var definitions: Array[MissionDefinition] = _service.definitions()
	definitions[0].title = "mutated"
	assert_eq(_service.definitions()[0].title, "Shelf expedition")
	var records: Dictionary = _service.snapshot()
	records[String(MAIN)].state = "claimed"
	assert_eq(_service.snapshot()[String(MAIN)].state, "available")


func test_accept_unknown_repeat_and_claim_before_completion_are_noops() -> void:
	watch_signals(_service)
	assert_eq(_service.accept(&"unknown"), ERR_INVALID_PARAMETER)
	assert_eq(_service.claim(MAIN), ERR_UNAVAILABLE)
	assert_eq(_service.accept(MAIN), OK)
	assert_eq(_service.accept(MAIN), ERR_ALREADY_EXISTS)
	assert_eq(_service.snapshot()[String(MAIN)].state, "accepted")
	assert_eq(_service.claim(MAIN), ERR_UNAVAILABLE)
	assert_signal_not_emitted(_service, "mission_completed")
	assert_signal_not_emitted(_service, "acknowledgement_claimed")


func test_domain_signal_progress_duplicates_and_route_order_are_idempotent() -> void:
	_service.accept(MAIN)
	watch_signals(_service)
	_discoveries.point_discovered.emit(&"shelf-twin-spires") # Forged signal is not domain evidence.
	assert_true(_service.snapshot()[String(MAIN)].objectives.is_empty())
	_discoveries.discover(&"shelf-twin-spires", &"test/ping")
	assert_eq(_service.snapshot()[String(MAIN)].objectives, ["identify-spires"])
	for _index: int in range(3):
		_discoveries.point_discovered.emit(&"shelf-twin-spires")
	assert_signal_not_emitted(_service, "mission_completed")
	_finish_route()
	assert_eq(_service.snapshot()[String(MAIN)].state, "completed")
	assert_signal_emit_count(_service, "mission_completed", 1)
	for _index: int in range(3):
		_route.stage_changed.emit(GrayboxRouteCheck.Stage.COMPLETE)
		_service.reconcile()
	assert_signal_emit_count(_service, "mission_completed", 1)
	assert_signal_not_emitted(_service, "acknowledgement_claimed")
	assert_eq(_service.claim(MAIN), OK)
	assert_eq(_service.claim(MAIN), ERR_ALREADY_EXISTS)
	assert_signal_emit_count(_service, "acknowledgement_claimed", 1)


func test_prior_permanent_discoveries_and_scans_and_current_complete_route_count_on_accept() -> void:
	_discoveries.discover(&"shelf-twin-spires", &"prior/ping")
	_research.complete_scan(&"shelf-calibration-plate")
	_finish_route()
	assert_eq(_service.snapshot()[String(MAIN)].state, "available")
	watch_signals(_service)
	assert_eq(_service.accept(MAIN), OK)
	assert_eq(_service.snapshot()[String(MAIN)].state, "completed")
	assert_eq(_service.accept(OPTIONAL), OK)
	assert_eq(_service.snapshot()[String(OPTIONAL)].state, "completed")
	assert_signal_emit_count(_service, "mission_completed", 2)
	assert_signal_not_emitted(_service, "acknowledgement_claimed")


func test_scan_must_be_completed_and_unrelated_evidence_does_not_count() -> void:
	_service.accept(OPTIONAL)
	_discoveries.discover(&"shelf-navigation-marker", &"ping/1")
	_research.complete_scan(&"shelf-overlook-formation")
	_research.scan_completed.emit(&"shelf-calibration-plate")
	assert_eq(_service.snapshot()[String(OPTIONAL)].state, "accepted")
	_research.complete_scan(&"shelf-calibration-plate")
	assert_eq(_service.snapshot()[String(OPTIONAL)].state, "completed")
	watch_signals(_service)
	_research.scan_completed.emit(&"shelf-calibration-plate")
	assert_signal_not_emitted(_service, "mission_completed")


func test_restart_and_reload_never_replay_completion_or_claim_and_keep_partial_route_evidence() -> void:
	_service.accept(MAIN)
	_finish_route()
	_route.reset()
	assert_eq(_service.snapshot()[String(MAIN)].objectives, ["return-to-base"])
	var reloaded: MissionService = _new_service()
	watch_signals(reloaded)
	_discoveries.discover(&"shelf-twin-spires", &"later/ping")
	assert_eq(reloaded.snapshot()[String(MAIN)].state, "completed")
	assert_eq(reloaded.claim(MAIN), OK)
	var claimed: MissionService = _new_service()
	watch_signals(claimed)
	claimed.reconcile()
	_route.reset()
	assert_eq(claimed.claim(MAIN), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(claimed, "mission_completed")
	assert_signal_not_emitted(claimed, "acknowledgement_claimed")


func test_reentrant_transitions_are_blocked_and_acknowledgement_is_saved_before_signal() -> void:
	_service.accept(OPTIONAL)
	_research.complete_scan(&"shelf-calibration-plate")
	var attempts: Array[int] = []
	_service.acknowledgement_claimed.connect(func(_id: StringName, ack: StringName) -> void:
		attempts.append(_service.claim(OPTIONAL))
		attempts.append(_service.accept(MAIN))
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
		assert_eq(data.missions[String(OPTIONAL)].state, "claimed")
		assert_eq(ack, &"shelf-calibration-ack"))
	assert_eq(_service.claim(OPTIONAL), OK)
	assert_eq(attempts, [ERR_BUSY, ERR_BUSY])


func test_save_failure_and_corruption_do_not_grant_completion_or_rewards() -> void:
	_service.accept(OPTIONAL)
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("corrupted")
	file.close()
	watch_signals(_service)
	_research.complete_scan(&"shelf-calibration-plate")
	assert_eq(_service.snapshot()[String(OPTIONAL)].state, "accepted")
	assert_ne(_service.reconcile(), OK)
	assert_eq(_service.claim(OPTIONAL), ERR_UNAVAILABLE)
	assert_signal_not_emitted(_service, "mission_completed")
	assert_signal_not_emitted(_service, "acknowledgement_claimed")
	assert_eq(_service.recover_backup(), OK)
	assert_eq(_service.reconcile(), OK)
	assert_eq(_service.snapshot()[String(OPTIONAL)].state, "completed")


func test_30_60_120_steps_produce_identical_persistent_state_and_one_completion() -> void:
	_service.accept(MAIN)
	_discoveries.discover(&"shelf-twin-spires", &"steps/ping")
	var reference: Dictionary = {}
	for rate: int in [30, 60, 120]:
		var service: MissionService = MissionService.new()
		add_child_autofree(service)
		var route: GrayboxRouteCheck = GrayboxRouteCheck.new()
		var path: String = _path + ".rate%d" % rate
		service.setup(CATALOG, _discoveries, _research, route, path)
		service.accept(MAIN)
		watch_signals(service)
		for step: int in range(rate * 3):
			route.sample(step >= rate * 2, step >= rate and step < rate * 2, 1.0 / rate)
		assert_signal_emit_count(service, "mission_completed", 1)
		service.claim(MAIN)
		if reference.is_empty():
			reference = service.snapshot()
		assert_eq(service.snapshot(), reference)
		for suffix: String in ["", ".bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_failed_route_progress_can_be_retried_after_test_restart_without_redetecting_route() -> void:
	_service.accept(MAIN)
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	_finish_route()
	_route.reset()
	assert_true(_service.snapshot()[String(MAIN)].objectives.is_empty())
	assert_eq(_service.recover_backup(), OK)
	assert_eq(_service.reconcile(), OK)
	assert_eq(_service.snapshot()[String(MAIN)].objectives, ["return-to-base"])


func test_state_of_matches_snapshot_without_copying_and_tracks_changes() -> void:
	var before: String = _service.state_of(MAIN)
	assert_eq(before, String(_service.snapshot()[String(MAIN)].state))
	assert_eq(_service.accept(MAIN), OK)
	assert_eq(_service.state_of(MAIN), "accepted", "no stale value after a change")
	assert_eq(_service.state_of(&"unknown"), "", "unknown ids read as empty, not an error")
