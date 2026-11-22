extends GutTest
## DC-1 foundation: the Drowned Caves journey phase, save validation, pressure fit, geometry,
## recovery and the Twilight round trip. Rules and authored data only; no level coordinates are
## hard-coded here, they come from DrownedCavesLayout.
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://dc1-%d.json" % Time.get_ticks_usec()
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
# ---------------------------------------------------------------- helpers
func _deploy() -> void:
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
## Twilight evidence, the released sentinel, the tether return and the claimed debrief.
func _claim_twilight() -> void:
	_deploy()
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]: await _study(id)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(TwilightShelfData.RELEASE),OK)
	game.revision.ui.radio_page.hide()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	assert_true(game.journey.at_station())
func _descend() -> void:
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.transfer_chapter("caves",true),OK)
## The dock hides replaced buttons and queues them for deletion; only a button not queued for deletion is the player's.
func _live_dock_button(button_name: String) -> Button:
	for found: Node in game.revision.ui.find_children(button_name,"Button",true,false):
		if not found.is_queued_for_deletion(): return found as Button
	return null
func _journey_data(phase: String,twilight_state: String) -> Dictionary:
	var progress: Dictionary = game.saves.progress_snapshot()
	progress.missions[String(TwilightShelfData.MISSION)].state = twilight_state
	return {"progress":progress,"journey":{"phase":phase,"commissioned":true}}
# ---------------------------------------------------------------- authorisation
func test_descent_is_refused_until_the_twilight_debrief_is_claimed() -> void:
	_deploy()
	assert_false(game.journey.caves_unlocked())
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.transfer_chapter("caves",true),ERR_UNAVAILABLE,"not from the Twilight shelf")
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.saves.transfer_chapter("caves",true),ERR_UNAVAILABLE,"returned but the debrief is unclaimed")
	assert_true(game.journey.at_station())
func test_descent_needs_a_full_restock_and_halcyon_and_the_dock_offer_follows_the_switch() -> void:
	await _claim_twilight()
	assert_true(game.journey.caves_unlocked())
	assert_true(game.journey.caves_entry_enabled,"on by default since DC-6; --no-drowned-caves turns it off")
	assert_true(game.journey.caves_entry_available())
	game.revision.ui.show_dock()
	assert_not_null(_live_dock_button("CavesDescent"),"the dock offers the descent")
	assert_eq(game.saves.transfer_chapter("caves",false),ERR_UNAVAILABLE,"arrival is fully supplied")
	game.journey.caves_entry_enabled = false
	assert_false(game.journey.caves_entry_available())
	game.revision.ui.show_dock()
	assert_null(_live_dock_button("CavesDescent"),"no dock button when switched off")
# ---------------------------------------------------------------- phase and save
func test_descent_commits_a_valid_caves_checkpoint_pressure_fit_and_region() -> void:
	await _claim_twilight()
	_descend()
	assert_true(game.journey.caves())
	assert_false(game.journey.active())
	assert_true(game.journey.in_field())
	assert_eq(game.journey.snapshot(),{"phase":"caves","commissioned":true})
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
	assert_eq(written.region_id,ExpeditionJourneyState.CAVES)
	assert_eq(int(written.schema_version),ExpeditionSchema.VERSION,"no schema number change")
	assert_eq(written.size(),12,"still twelve top-level fields")
	assert_eq(ExpeditionSchema.decode(written).error,OK)
	var at: Array = written.player.position
	assert_eq(Vector2(at[0],at[1]),DrownedCavesLayout.SPAWN)
	var rating: float = game.submarine.damage_system.get_maximum_depth_m()
	assert_eq(rating,game.revision.tree.hull_ratings[int(game.revision.campaign.ranks.hull)]+ChapterJourney.CAVES_PRESSURE_FIT.baseline_safe_depth_m-game.revision.tree.hull_ratings[0])
	assert_gte(rating,ChapterJourney.CAVES_PRESSURE_FIT.baseline_safe_depth_m,"every rank rates the cave range safe")
	game.submarine.damage_system.advance(0.0,game.region.depth_at_world(DrownedCavesLayout.SPAWN),game.submarine.hull_system)
	assert_between(game.submarine.damage_system.depth_m,1000.0,2000.0,"authored at the Bible's 1,000 to 2,000 m")
	assert_gt(rating,game.submarine.damage_system.depth_m)
func test_continue_restores_the_caves_phase_geometry_and_camera() -> void:
	await _claim_twilight()
	_descend()
	assert_eq(game.saves.continue_expedition(),OK)
	assert_true(game.journey.caves())
	assert_true(game.journey.caves_layout.visible)
	assert_false(game.journey.layout.visible,"the Twilight shelf is hidden")
	assert_eq(game.region.camera_bounds,DrownedCavesLayout.CAMERA)
	assert_eq(game.submarine.global_position,DrownedCavesLayout.SPAWN)
func test_validator_accepts_only_a_commissioned_caves_phase_after_a_claimed_debrief() -> void:
	await _claim_twilight()
	var good: Dictionary = _journey_data("caves","claimed")
	assert_true(ExpeditionJourneyState.valid(good.journey,good.progress))
	var unclaimed: Dictionary = _journey_data("caves","completed")
	assert_false(ExpeditionJourneyState.valid(unclaimed.journey,unclaimed.progress),"debrief not claimed")
	assert_false(ExpeditionJourneyState.valid({"phase":"caves","commissioned":false},good.progress),"must be commissioned")
	assert_false(ExpeditionJourneyState.valid({"phase":"caves","commissioned":true,"extra":1},good.progress),"exactly two fields")
	assert_false(ExpeditionJourneyState.valid({"phase":"depths","commissioned":true},good.progress),"unknown phase")
	assert_eq(ExpeditionJourneyState.region({"phase":"caves","commissioned":true}),ExpeditionJourneyState.CAVES)
	assert_eq(ExpeditionJourneyState.region({"phase":"twilight","commissioned":true}),ExpeditionJourneyState.TWILIGHT,"older regions unchanged")
	assert_eq(ExpeditionJourneyState.region({"phase":"refit","commissioned":true}),ExpeditionJourneyState.SHELF)
func test_schema_rejects_a_caves_checkpoint_with_a_mismatched_region_or_unclaimed_debrief() -> void:
	await _claim_twilight()
	_descend()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
	var forged: Dictionary = data.duplicate(true)
	forged.region_id = ExpeditionJourneyState.TWILIGHT
	assert_eq(ExpeditionSchema.decode(forged).error,ERR_INVALID_DATA,"region must match the phase")
	forged = data.duplicate(true)
	forged.journey = {"phase":"refit","commissioned":true}
	assert_eq(ExpeditionSchema.decode(forged).error,ERR_INVALID_DATA,"caves region with a refit phase")
	forged = data.duplicate(true)
	forged.progress.missions[String(TwilightShelfData.MISSION)].state = "completed"
	assert_eq(ExpeditionSchema.decode(forged).error,ERR_INVALID_DATA,"the award and debrief state must agree")
	assert_eq(ExpeditionSchema.decode(data.duplicate(true)).error,OK)
func test_a_twilight_checkpoint_from_before_this_change_still_loads_unchanged() -> void:
	await _claim_twilight()
	game.submarine.set_simulation_enabled(false)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
	assert_eq(data.journey.phase,"refit")
	assert_eq(data.region_id,ExpeditionJourneyState.SHELF)
	assert_eq(ExpeditionSchema.decode(data).error,OK)
# ---------------------------------------------------------------- return, recovery, round trip
func test_the_cave_anchor_returns_to_halcyon_and_twilight_resumes_with_its_own_rating() -> void:
	await _claim_twilight()
	_descend()
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = DrownedCavesLayout.SPAWN+Vector2(120,0)
	assert_true(game.journey.near_tether())
	game.submarine.global_position = DrownedCavesLayout.SPAWN+Vector2(400,0)
	assert_false(game.journey.near_tether(),"only at the anchor")
	assert_eq(game.saves.transfer_chapter("refit",true),ERR_UNAVAILABLE)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_true(game.journey.at_station())
	assert_false(game.journey.caves_layout.visible)
	assert_ne(game.region.spawn.position,DrownedCavesLayout.SPAWN,"the Halcyon spawn is restored")
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_true(game.journey.active())
	assert_true(game.journey.layout.visible)
	assert_false(game.journey.caves_layout.visible)
	assert_eq(game.submarine.damage_system.get_maximum_depth_m(),game.revision.tree.hull_ratings[int(game.revision.campaign.ranks.hull)]+ChapterJourney.PRESSURE_FIT.baseline_safe_depth_m-game.revision.tree.hull_ratings[0])
func test_vessel_recovery_from_the_caves_restocks_at_halcyon_and_keeps_records() -> void:
	await _claim_twilight()
	_descend()
	var earned: int = CampaignData.earned(game.revision.campaign)
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	assert_eq(pools.restore_snapshot(10.0,0.0),OK)
	game.submarine.hull_system.restore_snapshot(5.0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.recover_vessel(),OK)
	assert_true(game.journey.at_station())
	assert_eq(game.journey.snapshot(),{"phase":"refit","commissioned":true})
	assert_eq(pools.oxygen,pools.max_oxygen)
	assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull)
	assert_eq(CampaignData.earned(game.revision.campaign),earned,"records and allowance are kept")
	assert_true(game.journey.caves_unlocked())
func test_the_recovery_flow_treats_the_caves_as_a_campaign_chapter() -> void:
	await _claim_twilight()
	_descend()
	assert_true(game.journey.recovery.campaign_active())
# ---------------------------------------------------------------- geometry
func test_chamber_passage_and_sealed_end_are_authored_and_collidable() -> void:
	await _claim_twilight()
	_descend()
	var layout: DrownedCavesLayout = game.journey.caves_layout
	assert_eq(layout.bodies.size(),DrownedCavesLayout.contours().size())
	for body: GrayboxRock in layout.bodies: assert_eq(body.collision_layer,1,"solid while the caves are active")
	assert_true(game.saves.position_clear(DrownedCavesLayout.SPAWN,0.0),"the anchor is open water")
	assert_true(game.saves.position_clear(DrownedCavesLayout.PASSAGE_END,0.0),"the passage is flyable to its end")
	assert_true(Rect2(DrownedCavesLayout.CAMERA).has_point(DrownedCavesLayout.SPAWN))
	assert_true(Rect2(DrownedCavesLayout.CAMERA).has_point(DrownedCavesLayout.PASSAGE_END))
	# A point inside the east wall but still inside the camera bounds, so rock (not the bounds
	# check) is what refuses it. Without the wall this point is open water.
	var sealed: Vector2 = Vector2(float(DrownedCavesLayout.CAMERA.end.x)-50.0,DrownedCavesLayout.PASSAGE_END.y)
	assert_true(Rect2(DrownedCavesLayout.CAMERA).has_point(sealed),"the probe is inside the bounds")
	assert_false(game.saves.position_clear(sealed,0.0),"the passage is sealed by rock at its end")
	game.journey.caves_layout.set_enabled(false)
	for body: GrayboxRock in layout.bodies: assert_eq(body.collision_layer,0,"inert when another chapter is active")
func test_the_chamber_is_connected_to_the_passage_by_a_real_vessel_sweep() -> void:
	await _claim_twilight()
	_descend()
	var vessel: SubmarineController = game.submarine
	var shape: Shape2D = (vessel.get_node("CollisionShape2D") as CollisionShape2D).shape
	var from: Vector2 = DrownedCavesLayout.SPAWN
	var to: Vector2 = DrownedCavesLayout.PASSAGE_END
	var steps: int = 120
	var corridor: Array[Vector2] = [from,Vector2(from.x,to.y),to]
	var blocked: bool = false
	for leg: int in range(corridor.size()-1):
		for step: int in range(steps+1):
			var at: Vector2 = corridor[leg].lerp(corridor[leg+1],float(step)/steps)
			if not game.saves.position_clear(at,0.0): blocked = true
	assert_false(blocked,"anchor, chamber and passage form one navigable route")
	assert_not_null(shape)
