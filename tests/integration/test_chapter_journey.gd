extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta053-%d.json" % Time.get_ticks_usec()
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
func _evidence() -> void:
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
func _finish() -> void:
	_evidence()
	assert_eq(game.saves.finish_sunlit_return(),OK)
func _deploy() -> void:
	_finish()
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
func test_fresh_and_v8_migration_preserve_progress_and_do_not_commission() -> void:
	assert_eq(game.journey.snapshot(),ExpeditionJourneyState.fresh())
	var old: Dictionary = game.saves.snapshot()
	old.schema_version = 8
	old.erase("journey")
	var loaded: Dictionary = ExpeditionSchema.decode(old)
	assert_eq(loaded.error,OK)
	assert_eq(loaded.data.progress,old.progress)
	assert_eq(loaded.data.journey,ExpeditionJourneyState.fresh())
	assert_eq(loaded.data.region_id,ExpeditionSchema.REGION)
func test_journey_validation_rejects_unknown_phase_types_and_unearned_commissioning() -> void:
	for state: Variant in [null,{},[],{"phase":"missing","commissioned":false},{"phase":"twilight","commissioned":false},{"phase":"sunlit","commissioned":1},{"phase":"sunlit","commissioned":true}]:
		var data: Dictionary = game.saves.snapshot()
		data.journey = state
		assert_eq(ExpeditionSchema.decode(data).error,ERR_INVALID_DATA)
func test_finish_requires_all_evidence_then_commits_once_without_physics_return() -> void:
	assert_eq(game.saves.finish_sunlit_return(),ERR_UNAVAILABLE)
	_evidence()
	watch_signals(game.missions)
	var returns: Array = []
	game.route_check.base_returned.connect(func() -> void: returns.append(true))
	var before: Dictionary = game.story.snapshot()
	assert_eq(game.saves.finish_sunlit_return(),OK)
	assert_true(game.chapter.concluded())
	assert_eq(game.story.snapshot(),before)
	assert_eq(game.submarine.global_position,SunlitSurveyData.SPAWN)
	assert_signal_emit_count(game.missions,"acknowledgement_claimed",1)
	assert_true(returns.is_empty())
	assert_eq(game.saves.finish_sunlit_return(),ERR_UNAVAILABLE)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_signal_emit_count(game.missions,"acknowledgement_claimed",1)
func test_failed_finish_preserves_pose_records_and_emits_no_reward() -> void:
	_evidence()
	var previous: Dictionary = game.saves.snapshot()
	game.saves.store._writable = false
	watch_signals(game.missions)
	assert_eq(game.saves.finish_sunlit_return(),ERR_UNAUTHORIZED)
	assert_eq(game.saves.snapshot(),previous)
	assert_signal_not_emitted(game.missions,"acknowledgement_claimed")
func test_keep_exploring_does_not_complete_and_log_has_same_explicit_finish_action() -> void:
	_evidence()
	game.journey.offer_finish()
	assert_true(game.revision.ui.radio_page.visible)
	assert_false(game.submarine.is_physics_processing())
	game.journey._dismiss()
	assert_false(game.chapter.concluded())
	assert_true(game.submarine.is_physics_processing())
	game.submarine.set_simulation_enabled(false)
	game.expedition_log.refresh()
	assert_true(game.expedition_log.finish_button.visible)
func test_deployment_is_full_350m_and_suitable_pressure_without_erasing_old_progress() -> void:
	_finish()
	game.submarine.hull_system.restore_snapshot(65)
	game.submarine.resource_system.restore_snapshot(42,53)
	game.torpedoes.restore_ammunition(2)
	var permanent: Dictionary = game.saves.progress_snapshot()
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
	await game.journey.settle_camera()
	assert_eq((game.submarine.get_node("Camera2D") as Camera2D).get_screen_center_position(),TwilightShelfLayout.SPAWN)
	assert_false(game.journey.transitioning)
	# Let signal emission unwind before GUT immediately frees this test scene.
	await wait_process_frames(2)
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN)
	assert_eq(game.region.depth_at_world(game.submarine.global_position),350.0)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_eq(game.submarine.resource_system.battery,100.0)
	assert_eq(game.submarine.resource_system.oxygen,100.0)
	assert_eq(game.torpedoes.ammunition,10)
	assert_gte(game.submarine.damage_system.get_maximum_depth_m(),1000.0)
	assert_false(game.chapter.departure.is_visible_in_tree())
	assert_false(game.chapter.ocean.is_visible_in_tree())
	permanent.missions[String(TwilightShelfData.MISSION)].state = "accepted"
	assert_eq(game.saves.progress_snapshot(),permanent)
func test_continue_preserves_actual_pose_supplies_and_does_not_recommission_or_reset_history() -> void:
	_deploy()
	game.submarine.global_position = Vector2(30600,1400)
	game.submarine.hull_system.restore_snapshot(71)
	game.submarine.resource_system.restore_snapshot(61,52)
	game.torpedoes.restore_ammunition(4)
	assert_eq(game.saves.save_current(),OK)
	var bus: AcousticBus = game.get_node("AcousticBus") as AcousticBus
	var history: int = bus.history_count()
	for unused: int in range(3):
		assert_eq(game.saves.continue_expedition(),OK)
		assert_eq(game.submarine.global_position,Vector2(30600,1400))
		assert_eq(game.submarine.hull_system.hull,71.0)
		assert_eq(game.submarine.resource_system.battery,61.0)
		assert_eq(game.submarine.resource_system.oxygen,52.0)
		assert_eq(game.torpedoes.ammunition,4)
		assert_eq(bus.history_count(),history)
		assert_eq(game.submarine.damage_system.get_maximum_depth_m(),1000.0)
	assert_eq(game.saves.transfer_chapter("twilight",true),ERR_UNAVAILABLE)
func test_tether_boundary_explicit_service_refit_and_resume_preserve_records() -> void:
	_deploy()
	game.submarine.global_position = TwilightShelfLayout.SPAWN+Vector2(181,0)
	game.submarine.resource_system.restore_snapshot(40,60)
	assert_false(game.journey.near_tether())
	assert_eq(game.saves.transfer_chapter("refit",true),ERR_UNAVAILABLE)
	game.submarine.global_position = TwilightShelfLayout.SPAWN+Vector2(180,0)
	assert_true(game.journey.near_tether())
	assert_eq(game.submarine.resource_system.battery,40.0)
	var evidence: Dictionary = game.saves.progress_snapshot()
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	game.journey.show_station()
	assert_true(game.revision.ui.dock_page.visible)
	assert_false(game.submarine.is_physics_processing())
	assert_eq(game.submarine.resource_system.battery,100.0)
	assert_eq(game.revision.assign("sonar",1),OK)
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_eq(game.revision.campaign.ranks.sonar,1)
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN)
	assert_eq(game.saves.progress_snapshot(),evidence)
func test_failed_transfer_keeps_original_region_resources_and_checkpoint() -> void:
	_finish()
	var original: Dictionary = game.saves.snapshot()
	game.saves.store._writable = false
	assert_eq(game.saves.transfer_chapter("twilight",true),ERR_UNAUTHORIZED)
	assert_eq(game.saves.snapshot(),original)
	assert_false(game.journey.active())
func test_both_hull_width_loops_and_all_contours_have_clearance() -> void:
	_deploy()
	await wait_physics_frames(2)
	for polygon: PackedVector2Array in TwilightShelfLayout.contours(): assert_false(Geometry2D.triangulate_polygon(polygon).is_empty())
	var shape: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.collision_mask = 1
	for loop: Array[Vector2] in [TwilightShelfLayout.WEST_LOOP,TwilightShelfLayout.EAST_LOOP]:
		var before: Vector2 = loop[0]
		for at: Vector2 in loop:
			query.transform = Transform2D(0,before)*shape.transform
			query.motion = at-before
			assert_gte(game.submarine.get_world_2d().direct_space_state.cast_motion(query)[0],0.99999,str(before," → ",at))
			before = at
func test_map_and_tracker_use_deep_bounds_without_old_halcyon_or_buoy_markers() -> void:
	_deploy()
	game.mission_tracker.refresh()
	game.exploration_map.canvas.selected_id = SunlitShallowsData.POI
	game.revision._refresh_map_marker()
	assert_eq(game.exploration_map.canvas.bounds,Rect2(TwilightShelfLayout.CAMERA))
	assert_true(game.exploration_map.canvas.points.is_empty())
	assert_false(game.exploration_map.canvas.has_report)
	assert_eq(game.exploration_map.canvas.public_anchor,TwilightShelfLayout.SPAWN)
	assert_eq(game.exploration_map.canvas.selected_id,&"")
	assert_true(game.mission_tracker.title.text.contains("TWILIGHT"))
	assert_false(game.narrative.is_concluded())
func test_backup_recovery_preserves_commissioning_and_does_not_replay_acknowledgement() -> void:
	_deploy()
	# Simulate the default presentation on a cold start with an unreadable primary.
	game.journey.prepare(ExpeditionJourneyState.fresh())
	var file: FileAccess = FileAccess.open(game.saves.store.path,FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	watch_signals(game.missions)
	assert_eq(game.saves.recover_backup(),OK)
	assert_eq(game.journey.state.phase,"twilight")
	assert_eq(game.chapter.primary_title(),"Continue The Twilight Shelf")
	assert_eq(game.saves.continue_expedition(),OK)
	assert_true(game.journey.state.commissioned)
	assert_signal_not_emitted(game.missions,"acknowledgement_claimed")
func test_commission_preserves_paid_hull_margin_and_displays_actual_comparison() -> void:
	_finish()
	assert_eq(game.open_station(),OK)
	assert_eq(game.revision.assign("hull",1),OK)
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
	assert_eq(game.submarine.damage_system.get_maximum_depth_m(),1100.0)
	assert_eq(game.revision.tree.comparison("hull",1,700),"Rated depth 1100 → 1150 m")
func test_legacy_prototype_selection_preserves_records_and_uses_its_original_spawn() -> void:
	_deploy()
	var progress: Dictionary = game.saves.progress_snapshot()
	assert_eq(game.saves.transfer_prototype(),OK)
	assert_false(game.chapter.active)
	assert_false(game.journey.active())
	assert_eq(game.submarine.global_position,game.chapter._old_spawn)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_false(game.chapter.active)
	assert_eq(game.saves.progress_snapshot(),progress)
func test_stale_writer_cannot_uninstall_commissioning() -> void:
	_deploy()
	var candidate: Dictionary = game.saves.snapshot()
	candidate.journey = ExpeditionJourneyState.fresh()
	candidate.region_id = ExpeditionSchema.REGION
	assert_eq(ExpeditionSchema.decode(candidate).error,OK)
	assert_eq(game.saves.store.write_checkpoint(candidate),ERR_BUSY)
func test_offscreen_service_obeys_existing_limits_and_offline_eligibility() -> void:
	_deploy()
	game.submarine.resource_system.restore_snapshot(40,60)
	var profile: StationProfile = game.station.configuration.duplicate(true) as StationProfile
	profile.battery_per_service = 10
	assert_eq(game.station.configure(profile),OK)
	game.station.set_service_enabled(false)
	assert_eq(game.saves.transfer_chapter("refit",true),ERR_UNAVAILABLE)
	assert_true(game.journey.active())
	assert_eq(game.submarine.resource_system.battery,40.0)
	game.station.set_service_enabled(true)
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.submarine.resource_system.battery,50.0)
func test_queued_decorative_region_rebuild_can_be_freed_during_camera_settle() -> void:
	var garden: BenthicGarden = BenthicGarden.new()
	game.region.add_child(garden)
	garden.refresh()
	await wait_physics_frames(1)
	garden.queue_free()
	await wait_physics_frames(3)
	assert_false(is_instance_valid(garden))
