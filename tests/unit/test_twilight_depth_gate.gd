extends GutTest
func test_rating_grace_and_buckling_at_authored_depth_for_each_rank() -> void:
	var tree: ResearchTree = preload("res://resources/campaign/research_tree.tres")
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	for rank: int in range(4):
		var damage: SubmarineDamageSystem = SubmarineDamageSystem.new()
		var hull: SubmarineHullSystem = SubmarineHullSystem.new()
		add_child_autofree(damage)
		add_child_autofree(hull)
		var rating: float = tree.hull_ratings[rank]+ChapterJourney.PRESSURE_FIT.baseline_safe_depth_m-tree.hull_ratings[0]
		assert_eq(damage.set_maximum_depth_m(rating),OK)
		assert_eq(damage.advance(2.0,gate.depth_m,hull),OK)
		assert_eq(hull.hull,100.0)
		assert_eq(damage.advance(24.0,gate.depth_m,hull),OK)
		assert_eq(hull.hull,4.0 if rank<gate.gate_rank else 100.0)
		assert_eq(damage.advance(1.0,gate.depth_m,hull),OK)
		assert_eq(hull.hull,0.0 if rank<gate.gate_rank else 100.0)
func test_twilight_budget_and_old_records_never_retroactively_award_or_double_award() -> void:
	var rules: ResearchExperienceRules = ResearchExperienceData.TWILIGHT
	assert_true(rules.is_valid())
	var before_gate: Array = Array(rules.study_ids).slice(0,9)
	var most: Array = before_gate.slice(0,7)
	var credited: Dictionary = ResearchExperienceData.reconcile(ResearchExperienceData.fresh(),most,rules.study_ids)
	assert_eq(ResearchExperienceData.total(credited),280)
	assert_eq(ResearchExperienceData.points(credited),2)
	assert_eq(4+ResearchExperienceData.points(credited),6)
	assert_eq(ResearchExperienceData.points(ResearchExperienceData.fresh()),0)
	var old: Dictionary = ResearchExperienceData.reconcile(ResearchExperienceData.fresh(),most)
	assert_eq(ResearchExperienceData.points(old),0)
	assert_eq(ResearchExperienceData.reconcile(old,most,rules.study_ids),old)
	assert_eq(ResearchExperienceData.reconcile(credited,most,rules.study_ids),credited)
	assert_eq(ResearchExperienceData.RULES.maximum_extra_points,2)

func test_old_save_can_fund_gate_from_five_new_safe_studies_without_retroactive_awards() -> void:
	var old: Dictionary = ResearchExperienceData.reconcile(ResearchExperienceData.fresh(),Array(TwilightShelfData.OPTIONAL_SURVEY))
	var new_ids: Array[StringName] = [&"twilight-depth-margin",&"twilight-depth-layers",&"twilight-upper-grains",&"twilight-cable-crust",&"twilight-wreck-silt"]
	var completed: Array = Array(TwilightShelfData.OPTIONAL_SURVEY)+Array(new_ids)
	var next: Dictionary = ResearchExperienceData.reconcile(old,completed,new_ids)
	assert_eq(ResearchExperienceData.total(next),200)
	assert_eq(ResearchExperienceData.points(next),2)
	assert_eq(next.imported,old.imported)
