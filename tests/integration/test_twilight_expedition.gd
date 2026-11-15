extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta055-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	view.add_child(game)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func _deploy() -> void:
	game.submarine.global_position = Vector2(1280,480)
	assert_eq(game.story.apply_choice(LightBloomEncounter.COLLECT),OK)
	game.bloom.reset_session()
	assert_eq(game.discoveries.discover(SunlitShallowsData.POI,&"test/buoy"),OK)
	game.submarine.global_position = SunlitSurveyData.BUOY
	var records: Array[StringName] = game.research.completed_ids()
	records.append(SunlitShallowsData.BUOY)
	assert_eq(game.saves.commit_research_checkpoint(records),OK)
	game.research.restore_completed(records)
	game.missions.reconcile()
	assert_eq(game.saves.finish_sunlit_return(),OK)
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
func _study(id: StringName) -> void:
	game.submarine.global_position = game.research.definition(id).position-Vector2(90,0)
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_eq(game.submarine.scanner.request_scan(id),OK)
	assert_eq(game.submarine.scanner.advance(5.0),OK)
	assert_true(game.research.is_completed(id))
	game.submarine.set_simulation_enabled(false)
func _all_records(reverse: bool = false) -> void:
	var ids: Array[StringName] = [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]
	if reverse: ids.reverse()
	for id: StringName in ids: await _study(id)
func _choose(id: StringName) -> void:
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(id),OK)
	game.revision.ui.radio_page.hide()
func _return() -> void:
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
func test_catalogs_and_hidden_entries_are_valid_with_unique_stable_ids() -> void:
	assert_true(TwilightShelfData.discoveries().is_valid())
	assert_true(TwilightShelfData.research().is_valid())
	assert_true(TwilightShelfData.missions().is_valid())
	assert_eq(game.journey.expedition.entries().size(),1)
	assert_false(game.journey.expedition.log_text().contains("Mara / field log 01"))
	assert_eq(game.missions.snapshot()[String(TwilightShelfData.MISSION)].state,"available")
func test_deployment_accepts_only_new_mission_and_continue_never_refills() -> void:
	_deploy()
	assert_eq(game.missions.snapshot()[String(TwilightShelfData.MISSION)].state,"accepted")
	game.submarine.resource_system.consume_battery(31)
	game.submarine.resource_system.consume_oxygen(22)
	assert_eq(game.saves.save_current(),OK)
	watch_signals(game.story)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.resource_system.battery,69.0)
	assert_eq(game.submarine.resource_system.oxygen,78.0)
	assert_signal_not_emitted(game.story,"choice_applied")
func test_real_scanner_commits_records_log_and_checkpoint_without_sonar() -> void:
	_deploy()
	await _study(&"twilight-mara-log-one")
	assert_true(game.journey.expedition.log_text().contains("Mara / field log 01"))
	assert_true("twilight-mara-log-one" in game.saves._state.progress.research)
	assert_eq(game.submarine.scanner.request_scan(&"twilight-mara-log-one"),ERR_BUSY) # suspended, not a replay command
	assert_true(game.saves.store.read_file(game.saves.store.path).error==OK)
func test_west_first_release_and_debrief_reward_commit_once() -> void:
	_deploy()
	await _all_records(true)
	_choose(TwilightShelfData.RELEASE)
	assert_true(game.story.has_flag(&"zone2-future-guide"))
	assert_eq(game.story.resonance(),0) # prior bloom -15; release +15, never a displayed score
	var before: int = CampaignData.earned(game.revision.campaign)
	watch_signals(game.missions)
	_return()
	assert_eq(game.missions.snapshot()[String(TwilightShelfData.MISSION)].state,"completed")
	assert_signal_emit_count(game.missions,"mission_completed",1)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	assert_eq(CampaignData.earned(game.revision.campaign),before+2)
	assert_signal_emit_count(game.missions,"acknowledgement_claimed",1)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),ERR_ALREADY_EXISTS)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(CampaignData.earned(game.revision.campaign),before+2)
	assert_signal_emit_count(game.missions,"acknowledgement_claimed",1)
func test_east_first_live_capture_is_not_paid_until_delivery_and_does_not_stack() -> void:
	_deploy()
	await _all_records()
	var base_range: float = game.revision.capabilities().sonar
	var cost: float = game.submarine.sonar.configuration.battery_cost
	var cooldown: float = game.submarine.sonar.configuration.cooldown_seconds
	_choose(TwilightShelfData.CAPTURE)
	assert_eq(game.revision.capabilities().sonar,base_range)
	assert_false("twilight-specimen" in game.revision.campaign.awards)
	_return()
	var before: int = CampaignData.earned(game.revision.campaign)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	assert_eq(CampaignData.earned(game.revision.campaign),before+3)
	assert_eq(game.revision.capabilities().sonar,base_range+100)
	assert_eq(game.submarine.sonar.configuration.battery_cost,cost)
	assert_eq(game.submarine.sonar.configuration.cooldown_seconds,cooldown)
	assert_true(game.revision.tree.comparison("sonar",0,0,100).contains("1000 → 1300"))
	assert_eq(game.saves.continue_expedition(),OK)
	game.upgrades.reapply()
	assert_eq(game.revision.capabilities().sonar,base_range+100)
	assert_eq(game.story.apply_choice(TwilightShelfData.CAPTURE),ERR_ALREADY_EXISTS)
func test_return_before_resolution_is_refit_without_completion_or_allowance() -> void:
	_deploy()
	await _study(&"twilight-mara-log-one")
	var before: Dictionary = game.revision.campaign.duplicate(true)
	_return()
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),ERR_UNAVAILABLE)
	assert_eq(game.revision.campaign,before)
func test_failed_choice_and_debrief_leave_files_and_live_rewards_unchanged() -> void:
	_deploy()
	await _all_records()
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.saves.store._writable = false
	assert_eq(game.story.apply_choice(TwilightShelfData.CAPTURE),ERR_UNAUTHORIZED)
	assert_false(game.story.resolved(TwilightShelfData.ENCOUNTER))
	game.saves.store._writable = true
	_choose(TwilightShelfData.CAPTURE)
	_return()
	var before: Dictionary = game.saves._state.duplicate(true)
	game.saves.store._writable = false
	watch_signals(game.missions)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),ERR_UNAUTHORIZED)
	assert_eq(game.saves._state,before)
	assert_signal_not_emitted(game.missions,"acknowledgement_claimed")
func test_critical_animal_can_die_without_softlock_or_live_bounty() -> void:
	_deploy()
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(true)
	assert_gt(game.journey.expedition.health.apply_blast(&"test/lethal",TwilightShelfData.NET,200,100),0.0)
	assert_true(game.story.has_decision(TwilightShelfData.LOST))
	assert_false(game.journey.expedition.sentinel.visible)
	game.revision.ui.radio_page.hide()
	await _all_records()
	_return()
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	assert_false("twilight-specimen" in game.revision.campaign.awards)
func test_post_release_loss_is_permanent_without_repeating_choice_resonance() -> void:
	_deploy()
	await _study(&"twilight-net-survey")
	_choose(TwilightShelfData.RELEASE)
	var score: int = game.story.resonance()
	watch_signals(game.story)
	game.submarine.set_simulation_enabled(true)
	game.journey.expedition.health.apply_blast(&"test/after-release",TwilightShelfData.NET,200,100)
	assert_true(game.story.has_flag(&"zone2-released-sentinel-lost"))
	assert_eq(game.story.resonance(),score)
	assert_signal_not_emitted(game.story,"choice_applied")
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.save_current(),OK)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_false(game.journey.expedition.sentinel.visible)
func test_pause_cancellation_range_and_step_consistent_choice_timing() -> void:
	_deploy()
	await _study(&"twilight-net-survey")
	var model: TwilightExpedition = game.journey.expedition
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	for rate: int in [30,60,120]:
		game.submarine.set_simulation_enabled(true)
		model.action = TwilightShelfData.RELEASE
		model.elapsed = 0
		for unused: int in range(rate*3): model.advance(1.0/rate)
		assert_almost_eq(model.elapsed,3.0,0.000001)
		game.submarine.set_simulation_enabled(false)
		model.advance(1.0)
		assert_almost_eq(model.elapsed,3.0,0.000001)
		game.submarine.global_position = TwilightShelfData.NET+Vector2(400,0)
		game.submarine.set_simulation_enabled(true)
		model.advance(1.0/rate)
		assert_eq(model.action,&"")
		game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_false(game.story.resolved(TwilightShelfData.ENCOUNTER))
func test_schema9_migrates_without_new_story_rewards_and_rejects_forged_claims() -> void:
	var old: Dictionary = game.saves.snapshot()
	old.schema_version = 9
	old.progress.missions.erase(String(TwilightShelfData.MISSION))
	var decoded: Dictionary = ExpeditionSchema.decode(old)
	assert_eq(decoded.error,OK)
	assert_true(decoded.migrated)
	assert_eq(decoded.data.story,old.story)
	assert_eq(decoded.data.prototype,old.prototype)
	assert_eq(decoded.data.player,old.player)
	var forged: Dictionary = game.saves.snapshot()
	forged.prototype.campaign.awards.append("twilight-specimen")
	assert_eq(ExpeditionSchema.decode(forged).error,ERR_INVALID_DATA)
func test_forty_five_minute_resource_budget_leaves_reserve_with_ten_pings() -> void:
	_deploy()
	game.submarine.resource_system.advance(2700,1.0)
	game.submarine.resource_system.consume_battery(10*game.submarine.sonar.configuration.battery_cost)
	assert_gte(game.submarine.resource_system.battery,25.0)
	# Rewritten on purpose: the approved retune (Twilight 0.03/s, designer decision 5) leaves
	# exactly 19 oxygen after 45 minutes. This replaces the BTA-058 reserve of at least 25,
	# which the new rate cannot meet. Oxygen still lasts beyond 45 minutes.
	assert_gt(game.submarine.resource_system.oxygen,0.0,"a 45-minute run does not exhaust oxygen")
	assert_almost_eq(game.submarine.resource_system.oxygen,19.0,0.0001)
func test_optional_records_use_existing_capped_xp_once() -> void:
	_deploy()
	var before: int = ResearchExperienceData.total(game.revision.campaign.science)
	await _study(&"twilight-mara-log-two")
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),before+30)
	assert_eq(game.research.complete_scan(&"twilight-mara-log-two"),ERR_ALREADY_EXISTS)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),before+30)
func test_mid_expedition_backup_recovery_preserves_evidence_and_decision_silently() -> void:
	_deploy()
	await _study(&"twilight-net-survey")
	await _study(&"twilight-mara-log-one")
	_choose(TwilightShelfData.RELEASE)
	var expected: Dictionary = game.saves._state.duplicate(true)
	var file: FileAccess = FileAccess.open(game.saves.store.path,FileAccess.WRITE)
	file.store_string("{damaged"); file.close()
	watch_signals(game.story)
	assert_eq(game.saves.recover_backup(),OK)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.story.snapshot(),expected.story)
	assert_eq(game.saves.progress_snapshot(),expected.progress)
	assert_signal_not_emitted(game.story,"choice_applied")
	assert_true(game.journey.expedition.sentinel.released)
func test_failed_casualty_write_blocks_other_saves_until_explicit_retry() -> void:
	_deploy()
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.saves.store._writable = false
	game.journey.expedition.health.apply_blast(&"test/unsaved-casualty",TwilightShelfData.NET,200,100)
	assert_true(game.journey.expedition.pending_loss)
	assert_false(game.story.resolved(TwilightShelfData.ENCOUNTER))
	assert_eq(game.saves.save_current(),ERR_UNAVAILABLE)
	game.saves.store._writable = true
	assert_true(game.journey.expedition.interact())
	assert_false(game.journey.expedition.pending_loss)
	assert_true(game.story.has_decision(TwilightShelfData.LOST))
func test_release_uses_existing_collision_safe_navigation_and_passive_listening_is_silent() -> void:
	_deploy()
	await _study(&"twilight-net-survey")
	var count: int = (game.get_node("AcousticBus") as AcousticBus).history_count()
	game.submarine.passive.advance(1.0)
	assert_eq((game.get_node("AcousticBus") as AcousticBus).history_count(),count)
	_choose(TwilightShelfData.RELEASE)
	var before: Vector2 = game.journey.expedition.sentinel.position
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(120)
	assert_gt(before.distance_to(game.journey.expedition.sentinel.position),10.0)
	var at: Vector2 = game.journey.expedition.sentinel.position
	for polygon: PackedVector2Array in TwilightShelfLayout.contours(): assert_false(Geometry2D.is_point_in_polygon(at,polygon))
	game.submarine.set_simulation_enabled(false)
func test_passive_sentinel_contact_is_temporary_and_capture_removes_source() -> void:
	_deploy()
	await _study(&"twilight-net-survey")
	game.submarine.set_simulation_enabled(true)
	var source: AmbientSoundEmitter = game.journey.expedition.contact
	assert_eq(source.emit_next(),OK)
	assert_true(game.submarine.passive.contacts_snapshot().any(func(item: Dictionary) -> bool: return item.source_id==&"twilight-net-contact" and item.classification==&"marine_life"))
	game.submarine.set_simulation_enabled(false)
	_choose(TwilightShelfData.CAPTURE)
	assert_null(source.emitter.get_bus())
	assert_false(game.submarine.passive.contacts_snapshot().any(func(item: Dictionary) -> bool: return item.source_id==&"twilight-net-contact"))
