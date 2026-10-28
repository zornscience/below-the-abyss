extends GutTest

func _funded() -> Dictionary:
	var data: Dictionary = CampaignData.fresh()
	data.awards = ["commission","outer-survey","wreck-decoded"]
	data.decoded = true
	for item: Dictionary in SunlitSurveyData.STUDIES: data.science.credited.append(String(item.id))
	return data

func test_starting_budget_purchases_one_rank_and_complete_chapter_at_most_two() -> void:
	var fresh: Dictionary = CampaignData.fresh()
	assert_eq(CampaignData.next_cost(fresh),2)
	fresh.ranks.engine = 1
	assert_true(CampaignData.valid(fresh))
	assert_eq(CampaignData.available(fresh),0)
	var data: Dictionary = _funded()
	assert_eq(CampaignData.earned(data),6)
	data.ranks.engine = 1
	data.ranks.torpedo_area = 1
	assert_true(CampaignData.valid(data))
	assert_eq(CampaignData.available(data),1)
	data.ranks.torpedo_acceleration = 1
	assert_false(CampaignData.valid(data))

func test_refunding_and_reassigning_cannot_multiply_points() -> void:
	var data: Dictionary = _funded()
	data.ranks.engine = 1
	data.ranks.torpedo_area = 1
	assert_eq(CampaignData.refund_cost(data,"engine"),3)
	data.ranks.engine = 0
	assert_eq(CampaignData.refund_cost(data,"torpedo_area"),2)
	data.ranks.torpedo_area = 0
	assert_eq(CampaignData.available(data),6)
	for repeat: int in range(10):
		data.ranks.hull = 1
		assert_eq(CampaignData.available(data),4)
		data.ranks.hull = 0
		assert_eq(CampaignData.available(data),6)

func test_old_fits_keep_their_effects_and_original_paid_cost() -> void:
	var old: Dictionary = {"ranks":{"sonar":2,"hull":2},"awards":["commission","outer-survey","wreck-decoded"],"messages":[],"decoded":true,"science":ResearchExperienceData.fresh()}
	var migrated: Dictionary = CampaignData.migrate_previous(old)
	assert_true(CampaignData.valid(migrated))
	assert_eq(migrated.ranks.sonar,2)
	assert_eq(migrated.ranks.hull,2)
	assert_eq(CampaignData.spent(migrated),4)
	assert_eq(CampaignData.refund_cost(migrated,"hull"),1)
	old.ranks.sonar = 3
	assert_true(CampaignData.migrate_previous(old).is_empty(),"Over-budget old saves remain invalid.")

func test_every_branch_has_valid_authored_values_and_a_unique_icon() -> void:
	var tree: ResearchTree = CampaignData.PRICING
	assert_true(tree.is_valid())
	var paths: Array[String] = []
	for branch: String in CampaignData.BRANCHES:
		assert_eq(tree.values(branch).size(),4)
		var icon: Texture2D = ResearchTree.ICONS[branch]
		assert_false(icon.resource_path in paths)
		paths.append(icon.resource_path)
		assert_gt(icon.get_width(),0)

func test_version_seven_migrates_all_existing_progress_and_paid_allocations_without_mutation() -> void:
	var latest: Dictionary = ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data
	var old: Dictionary = latest.duplicate(true)
	old.schema_version = 7
	old.prototype.campaign.erase("legacy_ranks")
	old.prototype.campaign.ranks = {"sonar":1,"hull":1}
	var before: Dictionary = old.duplicate(true)
	var loaded: Dictionary = ExpeditionSchema.decode(old)
	assert_eq(loaded.error,OK)
	assert_true(loaded.migrated)
	assert_eq(old,before)
	assert_eq(loaded.data.prototype.campaign.legacy_ranks,{"sonar":1,"hull":1})
	assert_eq(CampaignData.spent(loaded.data.prototype.campaign),2)
	for key: String in ["player","progress","story","route","terrain"]: assert_eq(loaded.data[key],before[key])
	assert_eq(ExpeditionSchema.decode(loaded.data).error,OK)

func test_new_blast_size_is_valid_only_in_new_save_version_and_unknown_ranks_are_rejected() -> void:
	var latest: Dictionary = ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data
	latest.terrain = [{"rock":"sunlit-sediment-tunnel","at":[6410,1000],"radius":240}]
	assert_eq(ExpeditionSchema.decode(latest).error,OK)
	latest.prototype.campaign.ranks["unearned-engine"] = 1
	assert_eq(ExpeditionSchema.decode(latest).error,ERR_INVALID_DATA)

func test_authored_engine_ranks_keep_one_second_response_consistent_across_physics_rates() -> void:
	for acceleration: float in CampaignData.PRICING.engine_accelerations:
		var outcomes: Array[float] = []
		for rate: int in [30,60,120]:
			var model: SubmarineMotion = preload("res://resources/balance/expedition_motion.tres").duplicate(true) as SubmarineMotion
			model.acceleration = acceleration
			var velocity: Vector2 = Vector2.ZERO
			for step: int in range(rate): velocity = model.next_velocity(velocity,Vector2.RIGHT,1.0/rate)
			outcomes.append(velocity.x)
		assert_almost_eq(outcomes[0],outcomes[2],0.0001)
		assert_almost_eq(outcomes[1],outcomes[2],0.0001)
