extends GutTest

func _school() -> FishSchoolState:
	var model: FishSchoolState = FishSchoolState.new()
	assert_eq(model.configure(FishSchoolProfile.new()),OK)
	return model

func test_population_and_invalid_configuration_are_bounded() -> void:
	var rules: FishSchoolProfile = FishSchoolProfile.new()
	assert_true(rules.is_valid())
	for count: int in [4,13]:
		rules.population = count
		assert_false(rules.is_valid())
	rules.population = 12
	assert_eq(_school().positions.size(),8)
	var model: FishSchoolState = FishSchoolState.new()
	assert_eq(model.configure(rules),OK)
	assert_eq(model.positions.size(),12)
	assert_eq(model.advance(-1),ERR_INVALID_PARAMETER)

func test_schooling_separation_and_smooth_turns_stay_in_habitat() -> void:
	var model: FishSchoolState = _school()
	for step: int in range(600):
		var before: Array[Vector2] = model.positions.duplicate()
		model.advance(1.0/60.0)
		for index: int in range(model.positions.size()):
			assert_true(model.rules.habitat.has_point(model.positions[index]))
			assert_lt(before[index].distance_to(model.positions[index]),2.0)
	assert_gt(model.positions[0].distance_to(model.positions[1]),8.0)

func test_only_eligible_loud_sounds_startle_once_with_bounded_history() -> void:
	var model: FishSchoolState = _school()
	var ping: AcousticEvent = AcousticEvent.create(&"fish-test/ping",&"player",&"active_sonar",&"scientific",Vector2.ZERO,100,900,0)
	assert_true(model.hear(ping,Vector2(-100,0)))
	model.advance(0.1)
	var remaining: float = model.startled
	assert_false(model.hear(ping,Vector2(-100,0)))
	assert_eq(model.startled,remaining)
	var quiet: AcousticEvent = AcousticEvent.create(&"fish-test/passive",&"receiver",&"ambient",&"biological",Vector2.ZERO,1,100,0)
	assert_false(model.hear(quiet,Vector2.ZERO))
	for index: int in range(100):
		model.hear(AcousticEvent.create(StringName("blast/%d" % index),&"player",&"explosion",&"mechanical",Vector2.ZERO,100,100,0),Vector2(-1,0))
	assert_eq(model._seen.size(),64)

func test_fixed_step_school_motion_matches_at_30_60_120_and_reset() -> void:
	var results: Array[Array] = []
	for rate: int in [30,60,120]:
		var model: FishSchoolState = _school()
		for step: int in range(rate*5): model.advance(1.0/rate)
		results.append(model.positions.duplicate())
		model.reset()
		assert_eq(model.elapsed,0.0)
		assert_eq(model.positions[0],model._formation(0))
	for index: int in range(8):
		assert_lt(results[0][index].distance_to(results[1][index]),0.00001)
		assert_lt(results[0][index].distance_to(results[2][index]),0.00001)
