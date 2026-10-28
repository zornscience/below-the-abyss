extends GutTest

func test_authored_awards_thresholds_and_cap_are_derived_not_stacked() -> void:
	var science: Dictionary = ResearchExperienceData.fresh()
	assert_true(ResearchExperienceData.valid(science))
	assert_eq(ResearchExperienceData.total(science),0)
	var ids: Array[StringName] = [&"sunlit-silver-shoal",&"sunlit-amber-darter",&"sunlit-basalt-arch",&"sunlit-mineral-terrace"]
	science = ResearchExperienceData.reconcile(science,ids,ids)
	assert_eq(ResearchExperienceData.total(science),100)
	assert_eq(ResearchExperienceData.points(science),1)
	assert_eq(ResearchExperienceData.reconcile(science,ids,ids),science)
	var all_ids: Array[StringName] = ResearchExperienceData.RULES.species_ids+ResearchExperienceData.RULES.study_ids
	science = ResearchExperienceData.reconcile(science,all_ids,all_ids)
	assert_gt(ResearchExperienceData.total(science),200)
	assert_eq(ResearchExperienceData.points(science),2)
	var campaign: Dictionary = CampaignData.fresh()
	campaign.science = science
	assert_eq(CampaignData.earned(campaign),4)
	assert_true(CampaignData.valid(campaign))

func test_imported_and_prototype_records_never_gain_retroactive_xp() -> void:
	var ids: Array[StringName] = [&"shelf-calibration-plate",&"sunlit-silver-shoal"]
	var science: Dictionary = ResearchExperienceData.reconcile(ResearchExperienceData.fresh(),ids)
	assert_eq(science.imported,["shelf-calibration-plate","sunlit-silver-shoal"])
	assert_eq(ResearchExperienceData.reconcile(science,ids,ids),science)
	assert_eq(ResearchExperienceData.total(science),0)
	assert_eq(CampaignData.earned(CampaignData.fresh()),2)

func test_unknown_duplicate_malformed_or_orphan_awards_are_rejected() -> void:
	for bad: Variant in [null,{},[],{"credited":["unknown"],"imported":[]},{"credited":[true],"imported":[]},
		{"credited":["sunlit-silver-shoal","sunlit-silver-shoal"],"imported":[]},
		{"credited":["sunlit-silver-shoal"],"imported":["sunlit-silver-shoal"]}]:
		assert_false(ResearchExperienceData.valid(bad))
	var science: Dictionary = {"credited":["sunlit-silver-shoal"],"imported":[]}
	assert_false(ResearchExperienceData.valid_against(science,[]))
	assert_true(ResearchExperienceData.valid_against(science,["sunlit-silver-shoal"]))

func test_backup_merges_earned_once_and_keeps_allocations_intentional() -> void:
	var backup: Dictionary = CampaignData.fresh()
	backup.ranks.sonar = 1
	var current: Dictionary = CampaignData.fresh()
	var ids: Array[StringName] = [&"sunlit-silver-shoal",&"sunlit-amber-darter",&"sunlit-basalt-arch",&"sunlit-mineral-terrace"]
	current.science = ResearchExperienceData.reconcile(current.science,ids,ids)
	var merged: Dictionary = CampaignData.merge_earned(backup,current)
	assert_true(CampaignData.contains_earned(merged,current))
	assert_eq(merged.ranks.sonar,1)
	assert_eq(CampaignData.earned(merged),3)
	assert_eq(CampaignData.merge_earned(merged,current),merged)

func test_version_six_migrates_records_without_xp_or_loss_of_prior_state() -> void:
	var old: Dictionary = ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data
	old.schema_version = 6
	old.prototype.campaign.erase("science")
	old.prototype.campaign.erase("legacy_ranks")
	old.prototype.campaign.ranks = {"sonar":old.prototype.campaign.ranks.sonar,"hull":old.prototype.campaign.ranks.hull}
	var previous: Dictionary = old.duplicate(true)
	var migrated: Dictionary = ExpeditionSchema.decode(old)
	assert_eq(migrated.error,OK)
	assert_true(migrated.migrated)
	assert_eq(migrated.data.schema_version,ExpeditionSchema.VERSION)
	assert_eq(ResearchExperienceData.total(migrated.data.prototype.campaign.science),0)
	assert_true("shelf-calibration-plate" in migrated.data.prototype.campaign.science.imported)
	for key: String in ["progress","player","route","terrain","story"]: assert_eq(migrated.data[key],previous[key])
	assert_eq(old,previous,"Migration does not mutate caller data or disk.")

func test_xp_configuration_rejects_invalid_or_duplicate_authored_rules() -> void:
	var rules: ResearchExperienceRules = ResearchExperienceData.RULES.duplicate(true) as ResearchExperienceRules
	assert_true(rules.is_valid())
	rules.maximum_extra_points = 3
	assert_false(rules.is_valid())

	rules.maximum_extra_points = 2
	rules.species_ids.append(rules.study_ids[0])
	assert_false(rules.is_valid())

func test_malformed_legacy_progress_is_rejected_before_migration_reads_nested_fields() -> void:
	for invalid: Variant in [null,[],true,"bad",{}, {"research":null}]:
		var data: Dictionary = ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data
		data.schema_version = 6
		data.prototype.campaign.erase("science")
		data.progress = invalid
		assert_eq(ExpeditionSchema.decode(data).error,ERR_INVALID_DATA)
