extends GutTest
func test_catalogue_addition_preserves_each_old_record_and_stable_id() -> void:
	var old: Dictionary = SunlitShallowsData.missions().initial_records()
	old["shelf-expedition"].state = "accepted"
	var upgraded: Dictionary = TwilightShelfData.upgrade_records(old)
	assert_eq(upgraded.size(),7)
	for id: String in old: assert_eq(upgraded[id],old[id])
	assert_eq(upgraded[String(TwilightShelfData.MISSION)],{"state":"available","objectives":[]})
func test_required_objectives_exclude_optional_loggers_and_use_domain_kinds() -> void:
	var mission: MissionDefinition = TwilightShelfData.missions().definition(TwilightShelfData.MISSION)
	assert_eq(mission.objectives.size(),6)
	assert_eq(mission.objectives.back().kind,MissionObjective.Kind.RETURN_AFTER_SCAN)
	for objective: MissionObjective in mission.objectives:
		assert_false(objective.target_id in [&"twilight-mara-log-two",&"twilight-mara-log-three"])
		assert_true(objective.kind in [MissionObjective.Kind.SCAN,MissionObjective.Kind.STORY_CHOICE,MissionObjective.Kind.RETURN_AFTER_SCAN])
func test_choices_are_exclusive_with_provisional_weight_and_explicit_failure() -> void:
	var state: StoryState = StoryState.new()
	add_child_autofree(state)
	assert_eq(state.configure(),OK)
	assert_eq(state.apply_choice(TwilightShelfData.RELEASE),OK)
	assert_eq(state.resonance(),15)
	assert_eq(state.apply_choice(TwilightShelfData.CAPTURE),ERR_ALREADY_EXISTS)
	assert_eq(state.apply_choice(TwilightShelfData.LOST),ERR_ALREADY_EXISTS)
	assert_true(state.has_flag(&"zone2-future-guide"))
func test_optional_science_reuses_existing_lifetime_cap_and_does_not_double_credit() -> void:
	var ids: Array = ["twilight-mara-log-two","twilight-mara-log-three"]
	var first: Dictionary = ResearchExperienceData.reconcile(ResearchExperienceData.fresh(),ids,[&"twilight-mara-log-two",&"twilight-mara-log-three"])
	assert_eq(ResearchExperienceData.total(first),60)
	assert_eq(ResearchExperienceData.reconcile(first,ids,[&"twilight-mara-log-two"]),first)
	assert_lte(ResearchExperienceData.points(first),ResearchExperienceData.RULES.maximum_extra_points)
func test_profile_rates_are_finite_and_budget_scales_at_30_60_120_steps() -> void:
	var profile: SubmarineResourceConfig = preload("res://resources/balance/twilight_resources.tres")
	assert_true(profile.is_valid())
	for steps: int in [30,60,120]:
		var pools: SubmarineResourceSystem = SubmarineResourceSystem.new()
		add_child_autofree(pools)
		pools.configure(profile)
		for index: int in range(steps*45): pools.advance(1.0/steps,1.0)
		assert_almost_eq(pools.battery,99.46,0.000001)
		# Approved oxygen retune (Twilight 0.03/s): 45 s costs exactly 1.35 at every step size.
		assert_almost_eq(pools.oxygen,98.65,0.000001)
