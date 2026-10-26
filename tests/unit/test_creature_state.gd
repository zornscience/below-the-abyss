extends GutTest

var _profile: CreatureProfile
var _brain: CreatureState
const POSITION: Vector2 = Vector2(-300, 100)


func before_each() -> void:
	_profile = CreatureProfile.new()
	_profile.navigation_bounds = Rect2(-500, -500, 1000, 1000)
	_profile.patrol_points = PackedVector2Array([Vector2(-300, 0), Vector2(-300, 200)])
	_brain = CreatureState.new()
	assert_eq(_brain.configure(_profile), OK)


func _event(id: StringName = &"ping/1", type: StringName = &"active_sonar", timestamp: float = 0.0, origin: Vector2 = Vector2(200, 0), source: StringName = &"player") -> AcousticEvent:
	return AcousticEvent.create(id, source, type, &"mechanical", origin, 1.0, 650.0, timestamp)


func _offer(event: AcousticEvent, strength: float = 1.0, distance: float = 500.0) -> Error:
	return _brain.offer(event, strength, distance, event.origin)


func test_patrol_waypoints_wrap_without_sound() -> void:
	assert_eq(_brain.state, CreatureState.State.PATROL)
	assert_eq(_brain.destination(), Vector2(-300, 0))
	_brain.advance(1.0, Vector2(-300, 0))
	assert_eq(_brain.patrol_index, 1)
	_brain.advance(1.0, Vector2(-300, 200))
	assert_eq(_brain.patrol_index, 0)


func test_sound_receipt_is_pending_until_simulation_advance_then_investigates_origin() -> void:
	assert_eq(_offer(_event()), OK)
	assert_eq(_brain.state, CreatureState.State.PATROL)
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.state, CreatureState.State.INVESTIGATE)
	assert_eq(_brain.destination(), Vector2(200, 0))
	assert_eq(_brain.snapshot().event_id, &"ping/1")


func test_total_priority_is_order_independent_for_overlapping_events() -> void:
	var events: Array[AcousticEvent] = [_event(&"z", &"ambient"), _event(&"b"), _event(&"a")]
	for reverse: bool in [false, true]:
		_brain.reset_session()
		if reverse:
			events.reverse()
		for event: AcousticEvent in events:
			assert_eq(_offer(event), OK)
		_brain.advance(0.0, POSITION)
		assert_eq(_brain.snapshot().event_id, &"a")


func test_strength_then_timestamp_then_source_break_priority_ties() -> void:
	assert_eq(_offer(_event(&"weak"), 0.5), OK)
	assert_eq(_offer(_event(&"strong"), 1.0), OK)
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.snapshot().event_id, &"strong")
	_brain.advance(1.0, POSITION)
	_offer(_event(&"new", &"active_sonar", 1.0, Vector2(100, 0), &"z"))
	_offer(_event(&"other", &"active_sonar", 1.0, Vector2(100, 0), &"a"))
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.snapshot().event_id, &"other")


func test_active_ping_outweighs_stronger_ambient_noise() -> void:
	_offer(_event(&"ambient", &"ambient"), 100.0)
	_offer(_event(&"ping"), 0.2)
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.snapshot().event_id, &"ping")


func test_duplicate_pending_or_current_event_cannot_extend_deadline() -> void:
	assert_eq(_offer(_event()), OK)
	assert_eq(_offer(_event()), ERR_ALREADY_EXISTS)
	_brain.advance(0.0, POSITION)
	_brain.advance(2.0, POSITION)
	assert_eq(_offer(_event()), ERR_ALREADY_EXISTS)
	assert_eq(_brain.snapshot().deadline, 6.0)


func test_retargeting_does_not_restart_fixed_investigation_deadline() -> void:
	_offer(_event())
	_brain.advance(0.0, POSITION)
	_brain.advance(3.0, POSITION)
	_offer(_event(&"new-ping", &"active_sonar", 3.0, Vector2(250, 0)))
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.destination(), Vector2(250, 0))
	assert_eq(_brain.snapshot().deadline, 6.0)
	_brain.advance(3.0, POSITION)
	assert_eq(_brain.state, CreatureState.State.RETURN)
	assert_eq(_brain.reason, "TIMEOUT")


func test_exact_timeout_and_recovery_are_simulation_time() -> void:
	_offer(_event())
	_brain.advance(5.999, POSITION)
	assert_eq(_brain.state, CreatureState.State.PATROL, "Old samples expire before first processing.")
	_brain.reset_session()
	_offer(_event())
	_brain.advance(0.0, POSITION)
	_brain.advance(5.999, POSITION)
	assert_eq(_brain.state, CreatureState.State.INVESTIGATE)
	_brain.advance(0.001, POSITION)
	assert_eq(_brain.state, CreatureState.State.RETURN)
	assert_eq(_offer(_event(&"during-return", &"active_sonar", 6.0)), ERR_UNAVAILABLE)
	_brain.advance(0.0, Vector2(-300, 0))
	assert_eq(_brain.state, CreatureState.State.PATROL)
	assert_eq(_offer(_event(&"cooldown", &"active_sonar", 6.0)), ERR_UNAVAILABLE)
	_brain.advance(2.0, POSITION)
	assert_eq(_offer(_event(&"later", &"active_sonar", 8.0)), OK)


func test_arrival_returns_to_nearest_patrol_location() -> void:
	_offer(_event())
	_brain.advance(0.0, POSITION)
	_brain.advance(1.0, Vector2(200, 0))
	assert_eq(_brain.state, CreatureState.State.RETURN)
	assert_eq(_brain.reason, "ARRIVED")
	assert_eq(_brain.destination(), Vector2(-300, 0))
	_brain.advance(0.0, Vector2(-300, 0))
	assert_eq(_brain.state, CreatureState.State.PATROL)
	assert_eq(_brain.patrol_index, 1)


func test_unreachable_goal_returns_and_blocked_patrol_skips_without_teleport_logic() -> void:
	_offer(_event())
	_brain.advance(0.0, POSITION)
	_brain.advance(1.5, POSITION, true)
	assert_eq(_brain.state, CreatureState.State.RETURN)
	assert_eq(_brain.reason, "UNREACHABLE")
	var previous: int = _brain.patrol_index
	_brain.advance(1.5, POSITION, true)
	assert_ne(_brain.patrol_index, previous)


func test_range_strength_filters_bounds_and_unknown_types_fail_closed() -> void:
	assert_eq(_offer(_event(), 0.199), ERR_UNAVAILABLE)
	assert_eq(_offer(_event(), 1.0, 650.001), ERR_UNAVAILABLE)
	assert_eq(_offer(_event(&"type", &"passive_listening")), ERR_UNAVAILABLE)
	assert_eq(_offer(_event(&"outside", &"ambient", 0.0, Vector2(900, 0))), ERR_UNAVAILABLE)
	assert_eq(_offer(_event(), 0.2, 650.0), OK)


func test_stale_and_far_future_timestamps_are_rejected_and_near_future_waits() -> void:
	_brain.advance(3.0, POSITION)
	assert_eq(_offer(_event()), ERR_UNAVAILABLE)
	assert_eq(_offer(_event(&"future", &"ambient", 6.0)), ERR_UNAVAILABLE)
	assert_eq(_offer(_event(&"scheduled", &"ambient", 4.0)), OK)
	_brain.advance(0.5, POSITION)
	assert_eq(_brain.state, CreatureState.State.PATROL)
	_brain.advance(0.5, POSITION)
	assert_eq(_brain.state, CreatureState.State.INVESTIGATE)


func test_invalid_tuning_or_time_cannot_mutate_valid_runtime_rules() -> void:
	for property: String in ["patrol_speed", "investigation_seconds", "body_radius", "grid_spacing"]:
		var invalid: CreatureProfile = _profile.duplicate(true) as CreatureProfile
		invalid.set(property, NAN)
		assert_eq(_brain.configure(invalid), ERR_INVALID_PARAMETER)
	for delta: float in [-1.0, NAN, INF]:
		assert_eq(_brain.advance(delta, POSITION), ERR_INVALID_PARAMETER)
	_profile.patrol_points[0] = Vector2(999, 999)
	assert_eq(_brain.destination(), Vector2(-300, 0), "Runtime tuning is copied.")


func test_timeout_is_identical_at_30_60_120_steps() -> void:
	for rate: int in [30, 60, 120]:
		_brain.reset_session()
		_offer(_event())
		_brain.advance(0.0, POSITION)
		for _step: int in range(rate * 6 - 1):
			_brain.advance(1.0 / rate, POSITION)
		assert_eq(_brain.state, CreatureState.State.INVESTIGATE)
		_brain.advance(1.0 / rate, POSITION)
		assert_eq(_brain.state, CreatureState.State.RETURN)
		assert_almost_eq(_brain.snapshot().time, 6.0, 0.000001)
