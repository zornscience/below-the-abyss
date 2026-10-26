extends GutTest

var _hull: SubmarineHullSystem
var _damage: SubmarineDamageSystem


func before_each() -> void:
	_hull = autofree(SubmarineHullSystem.new())
	_hull.configure(SubmarineResourceConfig.new())
	_damage = autofree(SubmarineDamageSystem.new())
	_damage.configure(SubmarineDamageConfig.new())


func test_warning_threshold_boundaries_and_transition_notifications() -> void:
	watch_signals(_damage)
	_damage.advance(0.0, 259.99, _hull)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.SAFE)
	_damage.advance(0.0, 260.0, _hull)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.APPROACHING)
	_damage.advance(10.0, 300.0, _hull)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.APPROACHING)
	assert_eq(_hull.hull, 100.0, "The exact safe limit never incurs pressure damage.")
	_damage.advance(0.0, 300.01, _hull)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.EXCEEDED)
	_damage.advance(0.0, 400.0, _hull)
	assert_signal_emit_count(_damage, "warning_changed", 2, "No repeated warning transition while remaining unsafe.")
	_damage.advance(0.0, 250.0, _hull)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.SAFE)
	assert_signal_emit_count(_damage, "warning_changed", 3)


func test_pressure_grace_split_steps_and_return_to_safe_water() -> void:
	watch_signals(_damage)
	_damage.advance(1.5, 400.0, _hull)
	assert_eq(_hull.hull, 100.0)
	assert_almost_eq(_damage.grace_remaining_seconds, 0.5, 0.000001)
	_damage.advance(0.5, 400.0, _hull)
	assert_eq(_hull.hull, 100.0)
	_damage.advance(0.5, 400.0, _hull)
	assert_eq(_hull.hull, 98.0)
	assert_eq(_hull.last_damage_source, &"pressure")
	assert_signal_emitted_with_parameters(_damage, "pressure_damage_applied", [2.0])
	_damage.advance(0.0, 300.0, _hull)
	assert_eq(_damage.grace_remaining_seconds, 2.0)
	_damage.advance(2.0, 301.0, _hull)
	assert_eq(_hull.hull, 98.0)
	_damage.advance(0.5, 301.0, _hull)
	assert_eq(_hull.hull, 96.0)


func test_long_pressure_steps_are_bounded_and_only_charge_time_after_grace() -> void:
	_damage.advance(10.0, 500.0, _hull)
	assert_eq(_hull.hull, 68.0, "Eight seconds at four hull units per second.")
	watch_signals(_hull)
	_damage.advance(10000.0, 500.0, _hull)
	assert_eq(_hull.hull, 0.0)
	_damage.advance(10000.0, 500.0, _hull)
	assert_eq(_hull.hull, 0.0)
	assert_signal_emit_count(_hull, "vessel_destroyed", 1)


func test_zero_pressure_rate_retains_depth_warning_without_hull_loss() -> void:
	var profile: SubmarineDamageConfig = SubmarineDamageConfig.new()
	profile.pressure_damage_per_second = 0.0
	assert_eq(_damage.configure(profile), OK)
	watch_signals(_damage)
	_damage.advance(100.0, 450.0, _hull)
	assert_eq(_damage.pressure_damage_per_second, 0.0)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.EXCEEDED)
	assert_eq(_hull.hull, 100.0)
	assert_signal_not_emitted(_damage, "pressure_damage_applied")


func test_effective_maximum_depth_interface_updates_rules_without_an_upgrade_system() -> void:
	_damage.advance(1.5, 350.0, _hull)
	assert_eq(_damage.set_maximum_depth_m(300.0), OK)
	assert_eq(_damage.grace_remaining_seconds, 0.5, "Repeated identical ratings cannot refresh grace.")
	watch_signals(_damage)
	assert_eq(_damage.set_maximum_depth_m(450.0), OK)
	assert_eq(_damage.get_maximum_depth_m(), 450.0)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.SAFE)
	assert_signal_emitted_with_parameters(_damage, "maximum_depth_changed", [450.0])
	_damage.advance(10.0, 400.0, _hull)
	assert_eq(_hull.hull, 100.0)
	_damage.advance(0.0, 410.0, _hull)
	assert_eq(_damage.warning_state, SubmarineDamageSystem.WarningState.APPROACHING)
	_damage.advance(10.0, 450.0, _hull)
	assert_eq(_hull.hull, 100.0)
	_damage.advance(3.0, 451.0, _hull)
	assert_eq(_hull.hull, 96.0)
	assert_eq(_damage.configuration.safe_operating_depth_m, 300.0, "Authored defaults remain unchanged.")


func test_impact_threshold_damage_cap_and_hull_clamping() -> void:
	watch_signals(_damage)
	_damage.observe_contacts(149.99, true, _hull)
	_damage.observe_contacts(150.0, true, _hull)
	assert_eq(_hull.hull, 100.0)
	assert_signal_not_emitted(_damage, "collision_damage_applied")
	_damage.observe_contacts(240.0, true, _hull)
	assert_eq(_hull.hull, 91.0)
	assert_signal_emitted_with_parameters(_damage, "collision_damage_applied", [9.0, 240.0])
	assert_eq(_hull.last_damage_source, &"collision")
	_damage.observe_contacts(0.0, false, _hull)
	_damage.advance(1.0, 0.0, _hull)
	_damage.observe_contacts(10000.0, true, _hull)
	assert_eq(_hull.hull, 71.0, "A severe hit is capped at twenty units.")
	_hull.apply_damage(70.0, &"setup")
	_damage.observe_contacts(0.0, false, _hull)
	_damage.advance(1.0, 0.0, _hull)
	_damage.observe_contacts(10000.0, true, _hull)
	assert_eq(_hull.hull, 0.0)


func test_contact_episode_latch_prevents_continuous_or_corner_repeated_damage() -> void:
	watch_signals(_damage)
	_damage.observe_contacts(240.0, true, _hull)
	for _index: int in range(5):
		_damage.advance(1.0, 0.0, _hull)
		_damage.observe_contacts(240.0, true, _hull)
	assert_eq(_hull.hull, 91.0)
	assert_signal_emit_count(_damage, "collision_damage_applied", 1)
	_damage.observe_contacts(0.0, false, _hull)
	_damage.observe_contacts(240.0, true, _hull)
	assert_eq(_hull.hull, 82.0)


func test_cooldown_suppresses_a_new_episode_without_queuing_a_delayed_hit() -> void:
	_damage.observe_contacts(240.0, true, _hull)
	_damage.observe_contacts(0.0, false, _hull)
	_damage.advance(0.5, 0.0, _hull)
	_damage.observe_contacts(240.0, true, _hull)
	_damage.advance(0.25, 0.0, _hull)
	_damage.observe_contacts(240.0, true, _hull)
	assert_eq(_hull.hull, 91.0, "A suppressed episode stays suppressed after cooldown.")
	_damage.observe_contacts(0.0, false, _hull)
	_damage.observe_contacts(240.0, true, _hull)
	assert_eq(_hull.hull, 82.0, "A fresh episode at the cooldown boundary is allowed.")


func test_pressure_and_cooldown_are_consistent_at_30_60_and_120_steps() -> void:
	for rate: int in [30, 60, 120]:
		_hull.configure(SubmarineResourceConfig.new())
		_damage.configure(SubmarineDamageConfig.new())
		for _step: int in range(5 * rate):
			_damage.advance(1.0 / rate, 400.0, _hull)
		assert_almost_eq(_hull.hull, 88.0, 0.000001, "Pressure rate %d" % rate)
		_hull.configure(SubmarineResourceConfig.new())
		var profile: SubmarineDamageConfig = SubmarineDamageConfig.new()
		profile.collision_cooldown_seconds = 1.0
		_damage.configure(profile)
		_damage.observe_contacts(240.0, true, _hull)
		_damage.observe_contacts(0.0, false, _hull)
		for _step: int in range(rate):
			_damage.advance(1.0 / rate, 0.0, _hull)
		_damage.observe_contacts(240.0, true, _hull)
		assert_eq(_hull.hull, 82.0, "Cooldown rate %d" % rate)


func test_invalid_inputs_and_profiles_preserve_active_state() -> void:
	_damage.advance(1.0, 350.0, _hull)
	for value: float in [-1.0, NAN, INF, -INF]:
		assert_eq(_damage.advance(value, 350.0, _hull), ERR_INVALID_PARAMETER)
		assert_eq(_damage.advance(1.0, value, _hull), ERR_INVALID_PARAMETER)
		assert_eq(_damage.observe_contacts(value, true, _hull), ERR_INVALID_PARAMETER)
		assert_eq(_damage.set_maximum_depth_m(value), ERR_INVALID_PARAMETER)
	assert_eq(_damage.advance(1.0, 350.0, null), ERR_INVALID_PARAMETER)
	assert_eq(_damage.configure(null), ERR_INVALID_PARAMETER)
	for field: String in [
		"safe_operating_depth_m", "warning_margin_m", "pressure_grace_seconds",
		"pressure_damage_per_second", "impact_speed_threshold", "collision_damage_per_speed",
		"maximum_collision_damage", "collision_cooldown_seconds",
	]:
		var invalid: SubmarineDamageConfig = SubmarineDamageConfig.new()
		invalid.set(field, -1.0)
		assert_eq(_damage.configure(invalid), ERR_INVALID_PARAMETER, field)
	var invalid_margin: SubmarineDamageConfig = SubmarineDamageConfig.new()
	invalid_margin.warning_margin_m = 300.0
	assert_eq(_damage.configure(invalid_margin), ERR_INVALID_PARAMETER)
	assert_eq(_damage.depth_m, 350.0)
	assert_eq(_damage.grace_remaining_seconds, 1.0)
	assert_eq(_hull.hull, 100.0)
