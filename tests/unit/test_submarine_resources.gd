extends GutTest


func _resources(profile: SubmarineResourceConfig = null) -> SubmarineResourceSystem:
	var system: SubmarineResourceSystem = autofree(SubmarineResourceSystem.new())
	assert_eq(system.configure(profile if profile != null else SubmarineResourceConfig.new()), OK)
	return system


func test_configurable_capacities_and_transfer_interfaces() -> void:
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	profile.max_battery = 12.0
	profile.max_oxygen = 8.0
	var system: SubmarineResourceSystem = _resources(profile)
	assert_eq(system.battery, 12.0)
	assert_eq(system.oxygen, 8.0)
	assert_true(system.try_consume_battery(5.0))
	assert_false(system.try_consume_battery(8.0))
	assert_eq(system.battery, 7.0)
	assert_eq(system.restore_battery(100.0), 5.0)
	assert_eq(system.consume_battery(100.0), 12.0)
	assert_true(system.try_consume_oxygen(8.0))
	assert_false(system.try_consume_oxygen(1.0))
	assert_eq(system.restore_oxygen(100.0), 8.0)
	assert_eq(system.consume_oxygen(3.0), 3.0)


func test_idle_thrust_and_oxygen_drains_use_elapsed_seconds() -> void:
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	profile.battery_idle_drain_per_second = 1.0
	profile.battery_thrust_drain_per_second = 2.0
	profile.oxygen_drain_per_second = 0.5
	var system: SubmarineResourceSystem = _resources(profile)
	assert_eq(system.advance(2.0, 0.0), OK)
	assert_eq(system.battery, 98.0)
	assert_eq(system.oxygen, 99.0)
	assert_eq(system.advance(2.0, 0.5), OK)
	assert_eq(system.battery, 94.0)
	assert_eq(system.oxygen, 98.0)
	assert_eq(system.advance(1.0, 10.0), OK, "External thrust strength is capped at full input.")
	assert_eq(system.battery, 91.0)


func test_change_signals_include_current_and_maximum_and_noops_are_silent() -> void:
	var system: SubmarineResourceSystem = _resources()
	watch_signals(system)
	system.advance(1.0, 0.5)
	assert_signal_emitted_with_parameters(system, "battery_changed", [99.0, 100.0])
	assert_signal_emitted_with_parameters(system, "oxygen_changed", [99.5, 100.0])
	assert_signal_emit_count(system, "battery_changed", 1)
	assert_signal_emit_count(system, "oxygen_changed", 1)
	system.advance(0.0)
	system.restore_battery(0.0)
	system.consume_oxygen(0.0)
	assert_signal_emit_count(system, "battery_changed", 1)
	assert_signal_emit_count(system, "oxygen_changed", 1)


func test_depletion_signals_once_per_emptying_and_refills_rearm() -> void:
	var system: SubmarineResourceSystem = _resources()
	watch_signals(system)
	system.advance(10000.0, 1.0)
	system.advance(10000.0, 1.0)
	assert_eq(system.battery, 0.0)
	assert_eq(system.oxygen, 0.0)
	assert_signal_emit_count(system, "battery_depleted", 1)
	assert_signal_emit_count(system, "oxygen_depleted", 1)
	system.restore_battery(10.0)
	system.restore_oxygen(10.0)
	system.consume_battery(100.0)
	system.consume_oxygen(100.0)
	assert_signal_emit_count(system, "battery_depleted", 2)
	assert_signal_emit_count(system, "oxygen_depleted", 2)


func test_invalid_amounts_steps_and_profiles_preserve_valid_state() -> void:
	var system: SubmarineResourceSystem = _resources()
	system.consume_battery(20.0)
	for amount: float in [-1.0, NAN, INF, -INF]:
		assert_false(system.try_consume_battery(amount))
		assert_false(system.try_consume_oxygen(amount))
		assert_eq(system.consume_battery(amount), 0.0)
		assert_eq(system.consume_oxygen(amount), 0.0)
		assert_eq(system.restore_battery(amount), 0.0)
		assert_eq(system.restore_oxygen(amount), 0.0)
		assert_eq(system.advance(amount), ERR_INVALID_PARAMETER)
		assert_eq(system.advance(1.0, amount), ERR_INVALID_PARAMETER)
	assert_eq(system.configure(null), ERR_INVALID_PARAMETER)
	for field: String in [
		"max_hull", "max_battery", "max_oxygen",
		"battery_idle_drain_per_second", "battery_thrust_drain_per_second", "oxygen_drain_per_second",
	]:
		for value: float in [-1.0, NAN, INF]:
			var invalid: SubmarineResourceConfig = SubmarineResourceConfig.new()
			invalid.set(field, value)
			assert_eq(system.configure(invalid), ERR_INVALID_PARAMETER, field)
	var zero_capacity: SubmarineResourceConfig = SubmarineResourceConfig.new()
	zero_capacity.max_battery = 0.0
	assert_eq(system.configure(zero_capacity), ERR_INVALID_PARAMETER)
	assert_eq(system.battery, 80.0)
	assert_eq(system.oxygen, 100.0)


func test_zero_rates_and_extreme_finite_duration_are_safe() -> void:
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	profile.battery_idle_drain_per_second = 0.0
	profile.battery_thrust_drain_per_second = 0.0
	profile.oxygen_drain_per_second = 0.0
	var system: SubmarineResourceSystem = _resources(profile)
	system.advance(1.0e300, 1.0)
	assert_eq(system.battery, 100.0)
	assert_eq(system.oxygen, 100.0)
	system.configure(SubmarineResourceConfig.new())
	system.advance(1.0e300, 1.0)
	assert_eq(system.battery, 0.0)
	assert_eq(system.oxygen, 0.0)
	profile.battery_idle_drain_per_second = 1.0e150
	profile.battery_thrust_drain_per_second = 1.0e150
	profile.oxygen_drain_per_second = 1.0e150
	system.configure(profile)
	system.advance(1.0e-150, 1.0)
	assert_almost_eq(system.battery, 98.0, 0.000001)
	assert_almost_eq(system.oxygen, 99.0, 0.000001)
	profile.battery_idle_drain_per_second = 1.0e308
	profile.battery_thrust_drain_per_second = 1.0e308
	profile.oxygen_drain_per_second = 1.0e308
	system.configure(profile)
	system.advance(10.0, 1.0)
	assert_eq(system.battery, 0.0)
	assert_eq(system.oxygen, 0.0)


func test_drain_and_depletion_match_at_30_60_and_120_steps_per_second() -> void:
	for rate: int in [30, 60, 120]:
		var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
		profile.max_battery = 3.0
		profile.max_oxygen = 2.0
		profile.battery_idle_drain_per_second = 0.1
		profile.battery_thrust_drain_per_second = 0.2
		profile.oxygen_drain_per_second = 0.1
		var system: SubmarineResourceSystem = _resources(profile)
		watch_signals(system)
		for _step: int in range(10 * rate):
			system.advance(1.0 / rate, 0.5)
		assert_almost_eq(system.battery, 1.0, 0.000001)
		assert_almost_eq(system.oxygen, 1.0, 0.000001)
		for _step: int in range(10 * rate):
			system.advance(1.0 / rate, 0.5)
		assert_eq(system.battery, 0.0)
		assert_eq(system.oxygen, 0.0)
		assert_signal_emit_count(system, "battery_depleted", 1)
		assert_signal_emit_count(system, "oxygen_depleted", 1)


func test_vessels_share_authoring_data_but_not_current_values() -> void:
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	var first: SubmarineResourceSystem = _resources(profile)
	var second: SubmarineResourceSystem = _resources(profile)
	first.consume_battery(75.0)
	first.consume_oxygen(25.0)
	assert_eq(first.battery, 25.0)
	assert_eq(second.battery, 100.0)
	assert_eq(second.oxygen, 100.0)
	assert_eq(profile.max_battery, 100.0)
	assert_eq(profile.max_oxygen, 100.0)
	profile.max_battery = 200.0
	assert_eq(first.max_battery, 100.0, "Applying a profile snapshots its validated parameters.")
	assert_eq(second.max_battery, 100.0)
