extends GutTest
func test_profile_rejects_invalid_damage_durations_and_unsafe_plumes() -> void:
	var profile: ThermalVentProfile = ThermalVentProfile.new()
	assert_true(profile.is_valid())
	for value: float in [-1.0,NAN,INF,21.0]:
		profile.hull_per_second = value
		assert_false(profile.is_valid())
	profile.hull_per_second = 4
	profile.warning_seconds = 0
	assert_false(profile.is_valid())
	profile.warning_seconds = 4
	profile.warning_radius = 600
	assert_false(profile.is_valid(),"Warning must cover even the padded jet corners")
	profile.warning_radius = 650
	profile.plume = Rect2(10000,-550,190,290)
	assert_false(profile.is_valid(),"A valid warning must reach the entire dangerous plume")
	profile.plume = Rect2(0,0,100,200)
	assert_false(profile.is_valid())
func test_exact_phase_boundaries_and_no_pre_warning_damage() -> void:
	var model: ThermalVentState = ThermalVentState.new()
	assert_eq(model.configure(ThermalVentProfile.new()),OK)
	assert_eq(model.phase(),ThermalVentState.Phase.QUIET)
	for step: int in range(8): assert_eq(model.advance(1,true),0.0)
	assert_eq(model.phase(),ThermalVentState.Phase.WARNING)
	assert_eq(model.seconds_to_eruption(),4.0)
	for step: int in range(4): assert_eq(model.advance(1,true),0.0)
	assert_eq(model.phase(),ThermalVentState.Phase.ERUPTING)
	assert_eq(model.advance(1,true),4.0)
	assert_eq(model.advance(1,true),4.0)
	assert_eq(model.advance(1,true),4.0)
	assert_eq(model.phase(),ThermalVentState.Phase.COOLING)
	for step: int in range(5): assert_eq(model.advance(1,true),0.0)
	assert_eq(model.phase(),ThermalVentState.Phase.QUIET)
func test_frame_rate_consistency_and_damage_bound_per_cycle() -> void:
	for hz: int in [30,60,120]:
		var model: ThermalVentState = ThermalVentState.new()
		model.configure(ThermalVentProfile.new())
		var total: float = 0
		for step: int in range(60*hz): total += model.advance(1.0/hz,true)
		assert_almost_eq(total,36.0,0.00001,str(hz))
		assert_almost_eq(model.clock,0.0,0.00001)
func test_crossing_eruption_edge_only_charges_overlapping_time() -> void:
	var model: ThermalVentState = ThermalVentState.new()
	model.configure(ThermalVentProfile.new())
	for step: int in range(11): model.advance(1,true)
	model.advance(0.9,true)
	assert_almost_eq(model.advance(0.2,true),0.4,0.00001)
func test_outside_jet_never_damages_and_reset_provides_quiet_arrival() -> void:
	var model: ThermalVentState = ThermalVentState.new()
	model.configure(ThermalVentProfile.new())
	for step: int in range(40): assert_eq(model.advance(1,false),0.0)
	model.reset()
	assert_eq(model.clock,0.0)
	assert_eq(model.phase(),ThermalVentState.Phase.QUIET)
func test_invalid_advance_does_not_change_clock_or_charge_damage() -> void:
	var model: ThermalVentState = ThermalVentState.new()
	model.configure(ThermalVentProfile.new())
	for delta: float in [-1.0,INF,NAN,1.1]: assert_eq(model.advance(delta,true),0.0)
	assert_eq(model.clock,0.0)
