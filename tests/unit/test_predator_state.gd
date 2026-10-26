extends GutTest

var _profile: PredatorProfile
var _brain: PredatorState
const POSITION: Vector2 = Vector2(3200, 350)
const TARGET: Vector2 = Vector2(3060, 390)


func before_each() -> void:
	_profile = PredatorProfile.new()
	_brain = PredatorState.new()
	assert_eq(_brain.configure(_profile), OK)
	_brain.set_target(TARGET, true)


func _event(id: StringName = &"ping/1", type: StringName = &"active_sonar", source: StringName = &"neris-01/sonar", time: float = 0.0, at: Vector2 = TARGET) -> AcousticEvent:
	return AcousticEvent.create(id, source, type, &"scientific", at, 1.0, 900.0, time)


func _alert(at: Vector2 = TARGET) -> void:
	_brain.set_target(at, true)
	assert_eq(_brain.offer(_event(&"ping/1", &"active_sonar", &"neris-01/sonar", 0.0, at), 1.0, 145.0, at), OK)
	assert_eq(_brain.advance(0.0, POSITION), OK)
	assert_eq(_brain.phase, PredatorState.Phase.ALERT)


func test_only_eligible_player_sound_starts_warning_and_passive_listening_is_silent() -> void:
	for event: AcousticEvent in [_event(&"ambient", &"ambient"), _event(&"passive", &"passive_listening"), _event(&"other", &"active_sonar", &"other-source")]:
		assert_eq(_brain.offer(event, 1.0, 145.0, event.origin), ERR_UNAVAILABLE)
	assert_eq(_brain.offer(_event(), 0.1, 145.0, TARGET), ERR_UNAVAILABLE)
	assert_eq(_brain.offer(_event(), 1.0, 501.0, TARGET), ERR_UNAVAILABLE)
	assert_eq(_brain.offer(_event(&"outside", &"active_sonar", &"neris-01/sonar", 0.0, Vector2(3060, 480)), 1.0, 145.0, Vector2(3060, 480)), ERR_UNAVAILABLE)
	assert_eq(_brain.phase, PredatorState.Phase.QUIET)
	_alert()


func test_warning_is_complete_before_pursuit_or_contact_damage_even_at_same_position() -> void:
	_alert(POSITION)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)
	_brain.advance(2.499, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.ALERT)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)
	_brain.advance(0.001, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.PURSUE)
	assert_eq(_brain.contact_cost(0.0, true), 5.0)


func test_duplicate_and_repeated_pings_cannot_restart_warning_or_extend_episode() -> void:
	_alert()
	assert_eq(_brain.offer(_event(), 1.0, 145.0, TARGET), ERR_ALREADY_EXISTS)
	_brain.advance(1.0, POSITION)
	assert_eq(_brain.offer(_event(&"new", &"active_sonar", &"neris-01/sonar", 1.0), 1.0, 145.0, TARGET), ERR_UNAVAILABLE)
	assert_almost_eq(_brain.snapshot().warning_remaining, 1.5, 0.000001)
	_brain.advance(1.5, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.PURSUE)
	assert_eq(_brain.offer(_event(&"another", &"active_sonar", &"neris-01/sonar", 2.5), 1.0, 145.0, TARGET), ERR_UNAVAILABLE)
	_brain.advance(6.0, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.DISENGAGE)
	assert_eq(_brain.reason, "PURSUIT TIME LIMIT")


func test_retreat_outside_habitat_immediately_disengages_and_stops_damage() -> void:
	_alert()
	_brain.advance(2.5, POSITION)
	_brain.set_target(Vector2(3060, 480), true)
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.DISENGAGE)
	assert_eq(_brain.state, CreatureState.State.RETURN)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)


func test_pursuit_distance_boundary_and_missing_target_force_disengagement() -> void:
	_alert()
	_brain.advance(2.5, POSITION)
	_brain.set_target(Vector2(3240, 390), true) # Exactly 180 from ping.
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.PURSUE)
	_brain.set_target(Vector2(3241, 390), true)
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.DISENGAGE)
	_brain.reset_session()
	_alert()
	_brain.set_target(Vector2.ZERO, false)
	_brain.advance(0.0, POSITION)
	assert_eq(_brain.phase, PredatorState.Phase.DISENGAGE)


func test_damage_radius_obstruction_and_exact_cooldown_suppress_contact_jitter() -> void:
	_alert(POSITION)
	_brain.advance(2.5, POSITION)
	assert_eq(_brain.contact_cost(40.001, true), 0.0)
	assert_eq(_brain.contact_cost(0.0, false), 0.0)
	assert_eq(_brain.contact_cost(40.0, true), 5.0)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)
	_brain.advance(2.999, POSITION)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)
	_brain.advance(0.001, POSITION)
	assert_eq(_brain.contact_cost(0.0, true), 5.0)
	assert_eq(_brain.contact_cost(NAN, true), 0.0)


func test_unreachable_target_returns_using_base_fsm_and_recovery_ignores_sounds() -> void:
	_alert()
	_brain.advance(1.5, POSITION, true)
	assert_eq(_brain.phase, PredatorState.Phase.DISENGAGE)
	assert_eq(_brain.reason, "UNREACHABLE")
	assert_eq(_brain.offer(_event(&"ignored"), 1.0, 145.0, TARGET), ERR_UNAVAILABLE)
	_brain.advance(4.0, _brain.destination())
	assert_eq(_brain.phase, PredatorState.Phase.QUIET)


func test_invalid_profile_and_time_cannot_change_valid_state() -> void:
	_alert()
	for property: String in ["warning_seconds", "pursuit_seconds", "pursuit_speed", "contact_damage", "damage_cooldown"]:
		var invalid: PredatorProfile = _profile.duplicate(true) as PredatorProfile
		invalid.set(property, NAN)
		assert_eq(_brain.configure(invalid), ERR_INVALID_PARAMETER)
	var unfair: PredatorProfile = PredatorProfile.new()
	unfair.warning_seconds = 0.0
	assert_false(unfair.is_valid())
	for delta: float in [-1.0, NAN, INF]:
		assert_eq(_brain.advance(delta, POSITION), ERR_INVALID_PARAMETER)
	assert_eq(_brain.phase, PredatorState.Phase.ALERT)


func test_restart_clears_aggression_and_requires_new_warning_before_damage() -> void:
	_alert(POSITION)
	_brain.advance(2.5, POSITION)
	assert_eq(_brain.contact_cost(0.0, true), 5.0)
	_brain.reset_session()
	assert_eq(_brain.phase, PredatorState.Phase.QUIET)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)
	_alert(POSITION)
	assert_eq(_brain.contact_cost(0.0, true), 0.0)


func test_30_60_120_steps_have_identical_phase_deadlines_and_bounded_damage() -> void:
	for rate: int in [30, 60, 120]:
		_brain.reset_session()
		_alert(POSITION)
		var damage: float = 0.0
		for step: int in range(rate * 9):
			_brain.advance(1.0 / rate, POSITION)
			damage += _brain.contact_cost(0.0, true)
			if step < int(rate * 2.5) - 1:
				assert_eq(_brain.phase, PredatorState.Phase.ALERT)
		assert_eq(damage, 10.0, "At most two modest hits in the six-second pursuit.")
		assert_eq(_brain.phase, PredatorState.Phase.DISENGAGE)
