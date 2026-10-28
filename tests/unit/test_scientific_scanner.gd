extends GutTest

const CATALOG: ResearchCatalog = preload("res://resources/regions/shelf_research.tres")
const DISCOVERIES: DiscoveryCatalog = preload("res://resources/regions/shelf_discoveries.tres")
var _scanner: ScientificScanner
var _research: ResearchRegistry
var _discoveries: DiscoveryRegistry
var _target: ScientificScanTarget


func before_each() -> void:
	_research = ResearchRegistry.new()
	_discoveries = DiscoveryRegistry.new()
	_scanner = ScientificScanner.new()
	_target = ScientificScanTarget.new()
	_target.target_id = &"shelf-calibration-plate"
	_target.position = Vector2(240, 0)
	for node: Node in [_research, _discoveries, _scanner, _target]:
		add_child_autofree(node)
	var hidden_catalog: ResearchCatalog = CATALOG.duplicate(true) as ResearchCatalog
	for definition: ScanDefinition in hidden_catalog.targets: definition.requires_sonar = true
	assert_eq(_research.configure(hidden_catalog), OK)
	assert_eq(_discoveries.configure(DISCOVERIES), OK)
	assert_eq(_scanner.setup(_research, _discoveries, [_target]), OK)


func _discover() -> void:
	assert_eq(_discoveries.discover(&"shelf-navigation-marker", &"ping/1"), OK)


func test_hidden_targets_are_ineligible_and_never_show_scientific_metadata() -> void:
	assert_eq(_scanner.request_scan(), ERR_UNAVAILABLE)
	assert_eq(_scanner.candidate_id(), &"")
	assert_false(String(_scanner.snapshot().text).contains("Calibration"))
	_scanner.advance(10.0)
	assert_true(_research.completed_ids().is_empty())


func test_inclusive_range_boundary_and_outside_rejection() -> void:
	_discover()
	assert_eq(_scanner.candidate_id(), _target.target_id)
	_target.position.x = 240.0001
	assert_eq(_scanner.request_scan(), ERR_UNAVAILABLE)
	_target.position.x = 240.0
	assert_eq(_scanner.request_scan(), OK)
	_scanner.advance(2.999)
	assert_false(_research.is_completed(_target.target_id))
	assert_almost_eq(_scanner.snapshot().progress, 2.999 / 3.0, 0.00001)
	_scanner.advance(0.001)
	assert_true(_research.is_completed(_target.target_id))
	assert_eq(_scanner.snapshot().progress, 0.0)


func test_completion_and_repeated_attempts_emit_exactly_once() -> void:
	_discover()
	watch_signals(_research)
	assert_eq(_scanner.request_scan(), OK)
	_scanner.advance(3.0)
	assert_signal_emit_count(_research, "scan_completed", 1)
	assert_eq(_scanner.request_scan(), ERR_UNAVAILABLE)
	assert_true(String(_scanner.snapshot().text).contains("ALREADY RECORDED"))
	assert_eq(_research.complete_scan(_target.target_id), ERR_ALREADY_EXISTS)
	_scanner.advance(1000.0)
	assert_eq(_research.completed_records().size(), 1)
	assert_signal_emit_count(_research, "scan_completed", 1)


func test_intentional_second_activation_cancels_and_resets_progress() -> void:
	_discover()
	_scanner.request_scan()
	_scanner.advance(1.5)
	assert_eq(_scanner.request_scan(), OK)
	assert_eq(_scanner.snapshot().active_id, &"")
	assert_true(String(_scanner.snapshot().text).contains("CANCELLED"))
	assert_eq(_scanner.request_scan(), OK)
	assert_eq(_scanner.snapshot().progress, 0.0)
	_scanner.advance(1.5)
	assert_true(_research.completed_ids().is_empty())


func test_leaving_range_interrupts_without_banking_partial_progress() -> void:
	_discover()
	_scanner.request_scan()
	_scanner.advance(2.0)
	_target.position.x = 241
	_scanner.advance(1.0)
	assert_eq(_scanner.snapshot().active_id, &"")
	assert_true(String(_scanner.snapshot().text).contains("INTERRUPTED"))
	assert_true(_research.completed_ids().is_empty())
	_target.position.x = 239
	_scanner.request_scan()
	assert_eq(_scanner.snapshot().progress, 0.0)


func test_removed_target_interrupts_safely() -> void:
	_discover()
	_scanner.request_scan()
	_scanner.advance(2.9)
	_target.free()
	_scanner.advance(1.0)
	assert_eq(_scanner.snapshot().active_id, &"")
	assert_true(_research.completed_ids().is_empty())


func test_pause_preserves_progress_rejects_activation_and_invalid_time_preserves_state() -> void:
	_discover()
	_scanner.request_scan()
	_scanner.advance(1.0)
	_scanner.set_suspended(true)
	assert_eq(_scanner.request_scan(), ERR_BUSY)
	_scanner.advance(100.0)
	assert_almost_eq(_scanner.snapshot().progress, 1.0 / 3.0, 0.00001)
	assert_true(String(_scanner.snapshot().text).contains("PAUSED"))
	for delta: float in [-1.0, NAN, INF]:
		assert_eq(_scanner.advance(delta), ERR_INVALID_PARAMETER)
	_scanner.set_suspended(false)
	_scanner.advance(2.0)
	assert_true(_research.is_completed(_target.target_id))


func test_30_60_120_steps_complete_at_same_simulation_deadline() -> void:
	_discover()
	for rate: int in [30, 60, 120]:
		var research: ResearchRegistry = ResearchRegistry.new()
		add_child_autofree(research)
		assert_eq(research.configure(CATALOG), OK)
		assert_eq(_scanner.setup(research, _discoveries, [_target]), OK)
		watch_signals(research)
		_scanner.request_scan()
		for _step: int in range(rate * 3 - 1):
			_scanner.advance(1.0 / rate)
		assert_true(research.completed_ids().is_empty())
		_scanner.advance(1.0 / rate)
		assert_eq(research.completed_ids(), [&"shelf-calibration-plate"])
		assert_signal_emit_count(research, "scan_completed", 1)


func test_nearest_selection_and_lexical_id_tie_are_deterministic() -> void:
	_discover()
	_discoveries.discover(&"shelf-overlook", &"ping/2")
	var other: ScientificScanTarget = ScientificScanTarget.new()
	other.target_id = &"shelf-overlook-formation"
	other.position = _target.position
	add_child_autofree(other)
	assert_eq(_scanner.setup(_research, _discoveries, [other, _target]), OK)
	assert_eq(_scanner.candidate_id(), &"shelf-calibration-plate")
	other.position.x = 239
	assert_eq(_scanner.candidate_id(), other.target_id)


func test_invalid_catalogs_and_bindings_are_rejected_without_reconfiguring() -> void:
	for property: String in ["radius", "duration"]:
		var catalog: ResearchCatalog = CATALOG.duplicate(true) as ResearchCatalog
		catalog.targets[0].set(property, NAN)
		assert_false(catalog.is_valid())
	var catalog: ResearchCatalog = CATALOG.duplicate(true) as ResearchCatalog
	catalog.targets[1].stable_id = catalog.targets[0].stable_id
	assert_false(catalog.is_valid())
	assert_eq(_scanner.setup(_research, _discoveries, [_target, _target]), ERR_INVALID_PARAMETER)
	assert_eq(_research.configure(CATALOG), ERR_ALREADY_IN_USE)
	assert_eq(_research.complete_scan(&"unknown"), ERR_INVALID_PARAMETER)


func test_restore_is_atomic_merges_and_never_replays_completion_events() -> void:
	watch_signals(_research)
	assert_eq(_research.restore_completed([&"shelf-calibration-plate", &"unknown"]), ERR_INVALID_DATA)
	assert_true(_research.completed_ids().is_empty())
	assert_eq(_research.restore_completed([&"shelf-calibration-plate"]), OK)
	assert_eq(_research.restore_completed([]), OK)
	assert_eq(_research.complete_scan(&"shelf-calibration-plate"), ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(_research, "scan_completed")
	var records: Array[ScanDefinition] = _research.completed_records()
	records[0].description = "mutated"
	assert_ne(_research.completed_records()[0].description, "mutated")


func test_restart_cancels_partial_scan_and_preserves_completed_records() -> void:
	_discover()
	_scanner.request_scan()
	_scanner.advance(1.0)
	_scanner.reset_session()
	assert_eq(_scanner.snapshot().progress, 0.0)
	assert_true(_research.completed_ids().is_empty())
	_scanner.request_scan()
	_scanner.advance(3.0)
	_scanner.reset_session()
	assert_true(_research.is_completed(_target.target_id))
