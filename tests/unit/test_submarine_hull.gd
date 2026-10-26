extends GutTest


func _hull(profile: SubmarineResourceConfig = null) -> SubmarineHullSystem:
	var system: SubmarineHullSystem = autofree(SubmarineHullSystem.new())
	assert_eq(system.configure(profile if profile != null else SubmarineResourceConfig.new()), OK)
	return system


func test_damage_repair_and_source_are_explicit_and_clamped() -> void:
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	profile.max_hull = 50.0
	var hull: SubmarineHullSystem = _hull(profile)
	watch_signals(hull)
	assert_eq(hull.apply_damage(20.0, &"manual_test"), 20.0)
	assert_eq(hull.hull, 30.0)
	assert_eq(hull.last_damage_source, &"manual_test")
	assert_signal_emitted_with_parameters(hull, "hull_changed", [30.0, 50.0])
	assert_eq(hull.restore_hull(1000.0), 20.0)
	assert_eq(hull.hull, 50.0)
	assert_signal_not_emitted(hull, "vessel_destroyed")
	assert_eq(profile.max_hull, 50.0)


func test_destroyed_emits_once_until_positive_repair() -> void:
	var hull: SubmarineHullSystem = _hull()
	watch_signals(hull)
	assert_eq(hull.apply_damage(1000.0, &"manual_test"), 100.0)
	assert_eq(hull.apply_damage(1000.0, &"ignored_empty"), 0.0)
	assert_eq(hull.hull, 0.0)
	assert_eq(hull.last_damage_source, &"manual_test")
	assert_signal_emit_count(hull, "vessel_destroyed", 1)
	assert_signal_emit_count(hull, "hull_changed", 1)
	hull.restore_hull(5.0)
	hull.apply_damage(5.0, &"second_test")
	assert_signal_emit_count(hull, "vessel_destroyed", 2)
	assert_eq(hull.last_damage_source, &"second_test")


func test_invalid_damage_repairs_and_profiles_leave_state_and_signals_intact() -> void:
	var hull: SubmarineHullSystem = _hull()
	hull.apply_damage(25.0, &"valid")
	watch_signals(hull)
	for amount: float in [-1.0, NAN, INF, -INF]:
		assert_eq(hull.apply_damage(amount, &"invalid"), 0.0)
		assert_eq(hull.restore_hull(amount), 0.0)
	assert_eq(hull.apply_damage(0.0, &"zero"), 0.0)
	assert_eq(hull.restore_hull(0.0), 0.0)
	assert_eq(hull.configure(null), ERR_INVALID_PARAMETER)
	var invalid: SubmarineResourceConfig = SubmarineResourceConfig.new()
	invalid.max_hull = 0.0
	assert_eq(hull.configure(invalid), ERR_INVALID_PARAMETER)
	assert_eq(hull.hull, 75.0)
	assert_eq(hull.last_damage_source, &"valid")
	assert_signal_not_emitted(hull, "hull_changed")
	assert_signal_not_emitted(hull, "vessel_destroyed")


func test_independent_hulls_and_reconfiguration_start_full() -> void:
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	var first: SubmarineHullSystem = _hull(profile)
	var second: SubmarineHullSystem = _hull(profile)
	first.apply_damage(100.0)
	assert_eq(second.hull, 100.0)
	profile.max_hull = 40.0
	assert_eq(first.configure(profile), OK)
	assert_eq(first.hull, 40.0)
	assert_eq(first.max_hull, 40.0)
	assert_eq(second.max_hull, 100.0)
