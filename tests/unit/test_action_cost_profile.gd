extends GutTest
func test_resource_budget_is_computed_with_slow_travel_unchanged() -> void:
	var costs: ActionCostProfile = ChapterJourney.ACTION_COSTS
	var travel: SubmarineResourceConfig = preload("res://resources/balance/twilight_resources.tres")
	assert_true(costs.is_valid())
	assert_eq(int(travel.max_battery/costs.ping_battery),20)
	assert_eq(int(travel.max_battery/costs.torpedo_battery),20)
	# 30 min, 50% thrust: idle + additional thrust, three optional shots.
	var travel_cost: float = 1800.0*(travel.battery_idle_drain_per_second+travel.battery_thrust_drain_per_second*0.5)
	var pings: int = int((travel.max_battery-travel_cost-3.0*costs.torpedo_battery)/costs.ping_battery)
	assert_gte(pings,12)
	assert_lte(pings,15)
	assert_eq(travel.battery_idle_drain_per_second,0.003)
	assert_eq(travel.battery_thrust_drain_per_second,0.009)
	# Approved oxygen-exhaustion retune (designer decision 5): Twilight travel drain 0.03/s.
	assert_eq(travel.oxygen_drain_per_second,0.03)

func test_profile_rejects_invalid_costs() -> void:
	var profile: ActionCostProfile = ActionCostProfile.new()
	for invalid: float in [0.0,-1.0,NAN,INF]:
		profile.ping_battery = invalid
		assert_false(profile.is_valid())
		profile.ping_battery = 5.0
		profile.torpedo_battery = invalid
		assert_false(profile.is_valid())
		profile.torpedo_battery = 5.0
