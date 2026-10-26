extends GutTest

const HUD: PackedScene = preload("res://scenes/ui/submarine_hud.tscn")
var _hud: SubmarineHud
var _resources: SubmarineResourceSystem
var _hull: SubmarineHullSystem
var _damage: SubmarineDamageSystem


func before_each() -> void:
	_resources = SubmarineResourceSystem.new()
	_hull = SubmarineHullSystem.new()
	_damage = SubmarineDamageSystem.new()
	add_child_autofree(_resources)
	add_child_autofree(_hull)
	add_child_autofree(_damage)
	_hud = HUD.instantiate() as SubmarineHud
	add_child_autofree(_hud)


func _bind() -> void:
	assert_eq(_hud.bind_sources(_resources, _hull, _damage), OK)


func _label(path: String) -> String:
	return (_hud.get_node(path) as Label).text


func test_initial_snapshot_includes_changes_before_the_hud_was_bound() -> void:
	_resources.consume_battery(25.0)
	_resources.consume_oxygen(12.5)
	_hull.apply_damage(8.0, &"test")
	_damage.advance(0.0, 270.0, _hull)
	_bind()
	assert_eq(_hud.hull_gauge.current_value, 92.0)
	assert_eq(_hud.battery_gauge.current_value, 75.0)
	assert_eq(_hud.oxygen_gauge.current_value, 87.5)
	assert_eq(_label("%DepthValue"), "270.0 m")
	assert_true(_label("%SafeDepth").contains("300.0 m"))
	assert_true(_label("%WarningState").begins_with("CAUTION"))
	assert_eq((_hud.battery_gauge.get_node("%Bar") as ProgressBar).value, 75.0)


func test_domain_changes_update_numbers_and_bars_without_a_process_tick() -> void:
	_bind()
	_resources.consume_battery(40.0)
	_resources.consume_oxygen(20.0)
	_hull.apply_damage(10.0, &"test")
	assert_eq((_hud.hull_gauge.get_node("%Value") as Label).text, "90.0 / 100.0")
	assert_eq((_hud.oxygen_gauge.get_node("%Bar") as ProgressBar).value, 80.0)
	assert_eq(_hud.battery_gauge.current_value, 60.0)
	_resources.restore_battery(10.0)
	assert_eq(_hud.battery_gauge.current_value, 70.0)


func test_non_default_capacity_is_normalized_and_keeps_numeric_units() -> void:
	_bind()
	var profile: SubmarineResourceConfig = SubmarineResourceConfig.new()
	profile.max_battery = 250.0
	_resources.configure(profile)
	_resources.consume_battery(125.0)
	assert_eq(_hud.battery_gauge.maximum_value, 250.0)
	assert_eq((_hud.battery_gauge.get_node("%Bar") as ProgressBar).value, 50.0)
	assert_eq((_hud.battery_gauge.get_node("%Value") as Label).text, "125.0 / 250.0")


func test_warning_boundaries_and_rating_changes_update_immediately() -> void:
	_bind()
	for depth: float in [0.0, 259.99, 260.0, 300.0, 300.01, 250.0]:
		_damage.advance(0.0, depth, _hull)
		var expected: String = "SAFE"
		if depth > 300.0:
			expected = "DANGER"
		elif depth >= 260.0:
			expected = "CAUTION"
		assert_true(_label("%WarningState").begins_with(expected), str(depth))
	_damage.advance(0.0, 320.0, _hull)
	_damage.set_maximum_depth_m(400.0)
	assert_true(_label("%SafeDepth").contains("400.0 m"))
	assert_true(_label("%WarningState").begins_with("SAFE"))


func test_pressure_grace_is_sampled_from_simulation_and_not_hud_time() -> void:
	_bind()
	_damage.advance(0.5, 350.0, _hull)
	_hud._process(0.0)
	assert_true(_label("%PressureDetail").contains("1.5 s"))
	_hud._process(10.0)
	assert_true(_label("%PressureDetail").contains("1.5 s"), "Menus do not spend simulation grace.")
	_damage.advance(1.5, 350.0, _hull)
	_hud._process(0.0)
	assert_true(_label("%PressureDetail").contains("PRESSURE DAMAGE ACTIVE"))


func test_disabled_pressure_profile_is_not_presented_as_active_damage() -> void:
	var profile: SubmarineDamageConfig = SubmarineDamageConfig.new()
	profile.pressure_damage_per_second = 0.0
	_damage.configure(profile)
	_bind()
	_damage.advance(5.0, 350.0, _hull)
	_hud._process(0.0)
	assert_true(_label("%WarningState").begins_with("DANGER"))
	assert_true(_label("%PressureDetail").contains("disabled by profile"))
	assert_eq(_label("%PressureFeedback"), "")


func test_all_depletions_persist_and_positive_refill_clears_each_warning() -> void:
	_resources.consume_battery(100.0)
	_bind()
	_resources.consume_oxygen(100.0)
	_hull.apply_damage(100.0, &"test")
	for gauge: ResourceGauge in [_hud.hull_gauge, _hud.battery_gauge, _hud.oxygen_gauge]:
		assert_eq((gauge.get_node("%State") as Label).text, "DEPLETED")
		assert_eq((gauge.get_node("%Bar") as ProgressBar).value, 0.0)
		assert_true((gauge.get_node("%Value") as Label).text.begins_with("0.0 /"))
	_hud._process(100.0)
	assert_eq((_hud.battery_gauge.get_node("%State") as Label).text, "DEPLETED")
	_resources.restore_battery(1.0)
	assert_eq((_hud.battery_gauge.get_node("%State") as Label).text, "AVAILABLE")
	assert_eq((_hud.oxygen_gauge.get_node("%State") as Label).text, "DEPLETED")
	_resources.restore_oxygen(1.0)
	_hull.restore_hull(1.0)
	assert_eq((_hud.oxygen_gauge.get_node("%State") as Label).text, "AVAILABLE")
	assert_eq((_hud.hull_gauge.get_node("%State") as Label).text, "AVAILABLE")


func test_damage_feedback_uses_actual_damage_and_independent_bounded_lifetimes() -> void:
	_bind()
	_damage.observe_contacts(240.0, true, _hull)
	assert_true(_label("%ImpactFeedback").contains("Hull −9.0"))
	_damage.advance(2.5, 350.0, _hull)
	_damage.advance(0.5, 350.0, _hull)
	assert_true(_label("%PressureFeedback").contains("Hull −4.0"), "Continuous pressure is accumulated.")
	assert_true(_label("%ImpactFeedback").contains("IMPACT"), "Pressure cannot overwrite an impact.")
	_hud._process(SubmarineHud.FEEDBACK_SECONDS + 0.1)
	assert_eq(_label("%ImpactFeedback"), "")
	assert_eq(_label("%PressureFeedback"), "")
	_damage.advance(0.5, 350.0, _hull)
	assert_true(_label("%PressureFeedback").contains("Hull −2.0"), "A new episode resets the aggregate.")


func test_rebinding_disconnects_old_sources_and_never_duplicates_listeners() -> void:
	_bind()
	_bind()
	var replacement: SubmarineResourceSystem = SubmarineResourceSystem.new()
	add_child_autofree(replacement)
	assert_eq(_hud.bind_sources(replacement, _hull, _damage), OK)
	_resources.consume_battery(50.0)
	assert_eq(_hud.battery_gauge.current_value, 100.0)
	replacement.consume_battery(10.0)
	assert_eq(_hud.battery_gauge.current_value, 90.0)
	_damage.advance(3.0, 350.0, _hull)
	assert_true(_label("%PressureFeedback").contains("Hull −4.0"), "Rebinding did not duplicate pressure callbacks.")


func test_unbound_or_destroyed_sources_show_disconnected_not_stale_healthy_values() -> void:
	assert_true((_hud.get_node("%ConnectionStatus") as Control).visible)
	assert_false((_hud.get_node("%InstrumentDeck") as Control).visible)
	_bind()
	assert_eq(_hud.bind_sources(null, _hull, _damage), ERR_INVALID_PARAMETER)
	assert_eq(_hud.hull_gauge.current_value, 100.0, "Invalid bind preserves the valid source.")
	_damage.free()
	_hud._process(0.0)
	assert_true((_hud.get_node("%ConnectionStatus") as Control).visible)
	assert_false((_hud.get_node("%InstrumentDeck") as Control).visible)
