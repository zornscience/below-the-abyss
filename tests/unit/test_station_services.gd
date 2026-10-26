extends GutTest

const VESSEL: PackedScene = preload("res://scenes/player/submarine.tscn")
var _station: ServiceStation
var _player: SubmarineController


func before_each() -> void:
	_station = ServiceStation.new()
	add_child_autofree(_station)
	_player = VESSEL.instantiate() as SubmarineController
	add_child_autofree(_player)
	_player.set_simulation_enabled(false)


func _drain() -> void:
	_player.hull_system.apply_damage(37.0, &"fixture")
	_player.resource_system.consume_battery(52.0)
	_player.resource_system.consume_oxygen(64.0)


func test_docking_radius_is_inclusive_speed_limited_and_world_position_based() -> void:
	_player.position = Vector2(140, 0)
	assert_true(_station.can_interact(_player))
	_player.position.x = 140.001
	assert_false(_station.can_interact(_player))
	_player.position.x = 140
	_player.velocity = Vector2(40, 0)
	assert_true(_station.can_interact(_player))
	_player.velocity.x = 40.01
	assert_false(_station.can_interact(_player))
	_station.position = Vector2(300, 200)
	_player.position = Vector2(440, 200)
	_player.velocity = Vector2.ZERO
	assert_true(_station.can_interact(_player))


func test_arrival_and_opening_interaction_never_restore_resources() -> void:
	_drain()
	assert_true(_station.can_interact(_player))
	assert_eq(_station.interact(_player), OK)
	assert_eq(_player.hull_system.hull, 63.0)
	assert_eq(_player.resource_system.battery, 48.0)
	assert_eq(_player.resource_system.oxygen, 36.0)
	assert_eq(_station.interact(_player), ERR_ALREADY_IN_USE)


func test_explicit_free_service_restores_using_domain_apis_and_reports_before_after() -> void:
	_drain()
	_station.interact(_player)
	watch_signals(_station)
	var result: Dictionary = _station.perform(&"all")
	assert_eq(result.error, OK)
	assert_eq(result.cost, "FREE")
	assert_eq(result.before.hull, 63.0)
	assert_eq(result.before.battery, 48.0)
	assert_eq(result.after.hull, 100.0)
	assert_eq(result.after.battery, 100.0)
	assert_eq(result.after.oxygen, 100.0)
	assert_eq(result.transfer.oxygen, 64.0)
	assert_signal_emit_count(_station, "service_applied", 1)
	assert_eq(_station.perform(&"all").error, ERR_UNAVAILABLE)
	assert_signal_emit_count(_station, "service_applied", 1)


func test_individual_services_and_limits_clamp_without_changing_other_resources() -> void:
	var profile: StationProfile = StationProfile.new()
	profile.hull_per_service = 20.0
	profile.battery_per_service = 1000.0
	profile.oxygen_per_service = 0.0
	assert_eq(_station.configure(profile), OK)
	_drain()
	_station.interact(_player)
	assert_eq(_station.perform(&"hull").after.hull, 83.0)
	assert_eq(_player.resource_system.battery, 48.0)
	assert_eq(_station.perform(&"hull").after.hull, 100.0)
	assert_eq(_station.perform(&"battery").after.battery, 100.0)
	assert_eq(_station.perform(&"oxygen").error, ERR_UNAVAILABLE)
	assert_true(String(_station.quote(&"oxygen").reason).contains("disabled"))
	assert_eq(_player.resource_system.oxygen, 36.0)


func test_ineligible_missing_session_unpaused_out_of_range_offline_and_unknown_service_fail_without_mutation() -> void:
	_drain()
	assert_eq(_station.perform(&"all").error, ERR_UNCONFIGURED)
	_station.interact(_player)
	_player.set_simulation_enabled(true)
	assert_eq(_station.perform(&"all").error, ERR_BUSY)
	_player.set_simulation_enabled(false)
	_player.position.x = 141
	assert_eq(_station.perform(&"all").error, ERR_UNAVAILABLE)
	_player.position.x = 0
	_station.set_service_enabled(false)
	assert_eq(_station.perform(&"all").error, ERR_UNAVAILABLE)
	_station.set_service_enabled(true)
	assert_eq(_station.perform(&"upgrades").error, ERR_INVALID_PARAMETER)
	assert_eq(_player.hull_system.hull, 63.0)
	assert_eq(_player.resource_system.battery, 48.0)
	assert_eq(_player.resource_system.oxygen, 36.0)


func test_reentrant_resource_or_service_callbacks_cannot_duplicate_operation() -> void:
	_drain()
	_station.interact(_player)
	var errors: Array[int] = []
	_player.hull_system.hull_changed.connect(func(_value: float, _max: float) -> void: errors.append(_station.perform(&"all").error))
	_station.service_applied.connect(func(_result: Dictionary) -> void:
		errors.append(_station.perform(&"all").error)
		errors.append(_station.end_interaction()))
	assert_eq(_station.perform(&"all").error, OK)
	assert_eq(errors, [ERR_BUSY, ERR_BUSY, ERR_BUSY])
	assert_eq(_player.hull_system.hull, 100.0)
	assert_eq(_station.end_interaction(), OK)


func test_invalid_profiles_and_duplicate_notices_preserve_valid_configuration() -> void:
	for property: String in ["docking_radius", "maximum_docking_speed", "hull_per_service", "battery_per_service", "oxygen_per_service"]:
		var profile: StationProfile = StationProfile.new()
		profile.set(property, NAN)
		assert_eq(_station.configure(profile), ERR_INVALID_PARAMETER)
	var notice: StationNotice = StationNotice.new()
	notice.stable_id = &"test-notice"
	notice.title = "Notice"
	notice.description = "Information only"
	var profile: StationProfile = StationProfile.new()
	profile.notices = [notice, notice]
	assert_false(profile.is_valid())
	assert_true(_station.is_in_range(Vector2(140, 0)))
	assert_false(_station.is_in_range(Vector2(INF, 0)))


func test_runtime_tuning_and_notice_snapshots_are_copied_and_board_has_no_progression_state() -> void:
	var notice: StationNotice = StationNotice.new()
	notice.stable_id = &"test-notice"
	notice.title = "Notice"
	notice.description = "Information only"
	var profile: StationProfile = StationProfile.new()
	profile.notices = [notice]
	assert_eq(_station.configure(profile), OK)
	profile.docking_radius = 1.0
	notice.description = "Mutated source"
	assert_true(_station.is_in_range(Vector2(140, 0)))
	assert_eq(_station.notices_snapshot()[0].description, "Information only")
	_station.notices_snapshot()[0].description = "Mutated snapshot"
	assert_eq(_station.notices_snapshot()[0].description, "Information only")
	assert_false(_station.has_signal("mission_accepted"))


func test_depleted_resources_can_be_restored_without_resetting_component_identity() -> void:
	_player.hull_system.apply_damage(1000, &"fixture")
	_player.resource_system.consume_battery(1000)
	_player.resource_system.consume_oxygen(1000)
	var hull: SubmarineHullSystem = _player.hull_system
	var resources: SubmarineResourceSystem = _player.resource_system
	_station.interact(_player)
	assert_eq(_station.perform(&"all").error, OK)
	assert_eq(_player.hull_system, hull)
	assert_eq(_player.resource_system, resources)
	assert_eq(hull.hull, 100.0)
	assert_eq(resources.battery, 100.0)
	assert_eq(resources.oxygen, 100.0)


func test_departed_or_removed_vessel_cannot_use_stale_session() -> void:
	_drain()
	_station.interact(_player)
	assert_eq(_station.end_interaction(), OK)
	assert_eq(_station.perform(&"hull").error, ERR_UNCONFIGURED)
	assert_eq(_station.interact(_player), OK)
	_player.free()
	assert_eq(_station.perform(&"all").error, ERR_UNCONFIGURED)
