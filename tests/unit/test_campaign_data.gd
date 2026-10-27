extends GutTest
func test_finite_budget_requires_real_authored_award_ids_and_cannot_overspend() -> void:
	var data: Dictionary = CampaignData.fresh()
	assert_true(CampaignData.valid(data))
	assert_eq(CampaignData.earned(data),2)
	data.ranks = {"sonar":1,"hull":1}
	assert_eq(CampaignData.available(data),0)
	assert_true(CampaignData.valid(data))
	data.ranks.sonar = 2
	assert_false(CampaignData.valid(data))
	data.awards.append("outer-survey")
	assert_true(CampaignData.valid(data))
	data.awards.append("wreck-decoded")
	data.decoded = true
	assert_eq(CampaignData.earned(data),4)
	data.ranks = {"sonar":3,"hull":1}
	assert_true(CampaignData.valid(data))
	data.ranks.hull = 2
	assert_false(CampaignData.valid(data))
func test_duplicate_invalid_and_malformed_ledgers_are_rejected() -> void:
	for modification: Dictionary in [{"awards":["commission","commission"]},{"awards":["infinite-money"]},{"decoded":true},{"messages":["unknown"]},{"ranks":{"sonar":true,"hull":0}},{"ranks":{"sonar":-1,"hull":0}},{"ranks":{"sonar":0,"hull":0,"extra":0}}]:
		var data: Dictionary = CampaignData.fresh()
		data.merge(modification,true)
		assert_false(CampaignData.valid(data))
func test_reassignment_preserves_total_earned_and_permanent_awards() -> void:
	var previous: Dictionary = CampaignData.fresh()
	previous.ranks = {"sonar":1,"hull":1}
	var next: Dictionary = previous.duplicate(true)
	next.ranks = {"sonar":2,"hull":0}
	assert_true(CampaignData.contains_earned(next,previous))
	assert_eq(CampaignData.available(next),0)
	next.awards = []
	assert_false(CampaignData.contains_earned(next,previous))
func test_legacy_upgrade_ids_migrate_into_paid_ranks_without_double_stacking() -> void:
	var progress: Dictionary = {"upgrades":["sonar-range-1200","pressure-hull-400"],"research":[],"missions":{}}
	var migrated: Dictionary = CampaignData.migrate(progress)
	assert_true(CampaignData.valid(migrated))
	assert_eq(migrated.ranks,{"sonar":1,"hull":1})
	assert_eq(CampaignData.available(migrated),0)
func test_v3_save_migrates_ammunition_and_allocations_in_memory() -> void:
	var old: Dictionary = ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data
	old.schema_version = 3
	old.erase("prototype")
	old.erase("story")
	var loaded: Dictionary = ExpeditionSchema.decode(old)
	assert_eq(loaded.error,OK)
	assert_true(loaded.migrated)
	assert_eq(loaded.data.schema_version,5)
	assert_eq(loaded.data.prototype.ammunition,10)
	assert_eq(loaded.data.prototype.campaign.ranks.sonar,1)
	assert_false(old.has("prototype"))
func test_prototype_save_rejects_invalid_ammunition_and_unknown_fields() -> void:
	for bad: Variant in [-1,11,true,1.5,"10",null]:
		assert_false(ExpeditionSchema.valid_prototype({"ammunition":bad,"campaign":CampaignData.fresh()}))
	assert_false(ExpeditionSchema.valid_prototype({"ammunition":10,"campaign":CampaignData.fresh(),"untrusted":true}))
func test_research_tree_resource_has_monotonic_capabilities_and_valid_bounds() -> void:
	var tree: ResearchTree = load("res://resources/campaign/research_tree.tres").duplicate(true) as ResearchTree
	assert_true(tree.is_valid())
	tree.hull_ratings[2] = 300
	assert_false(tree.is_valid())
func test_launch_profile_rejects_invalid_acceleration_or_cruise_speed() -> void:
	var profile: BlastProfile = BlastProfile.new()
	assert_true(profile.is_valid())
	profile.propulsion_acceleration = 0
	assert_false(profile.is_valid())
	profile.propulsion_acceleration = 500
	profile.cruise_speed = profile.launch_speed-1
	assert_false(profile.is_valid())
func test_recovery_merges_earned_progress_without_creating_additional_currency() -> void:
	var backup: Dictionary = CampaignData.fresh()
	backup.ranks.hull = 1
	var current: Dictionary = CampaignData.fresh()
	current.awards.append("wreck-decoded")
	current.decoded = true
	current.messages.append("wreck-recovered")
	var recovered: Dictionary = CampaignData.merge_earned(backup,current)
	assert_true(CampaignData.valid(recovered))
	assert_true(recovered.decoded)
	assert_eq(CampaignData.earned(recovered),3)
	assert_eq(recovered.ranks.hull,1)
	assert_eq(CampaignData.merge_earned(recovered,current),recovered)
