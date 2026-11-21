extends GutTest
## DC-5: the memory crystal shrine. One exclusive, atomically saved decision (leave +15, take -15), a
## derived one-time sonar calibration for taking, a drawn collapse that blocks nothing, and no mission,
## points or experience. Coordinates come from the authored data; the choice runs through the real UI
## buttons and the real save path.
var game: ShelfPrototype
var path: String
var view: SubViewport
func before_each() -> void:
	view = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	path = "user://dc5-%d.json" % Time.get_ticks_usec()
	game = await _new_game()
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func _new_game() -> ShelfPrototype:
	var scene: ShelfPrototype = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	scene.settings_path = path
	scene.expedition_path = path+".expedition.json"
	view.add_child(scene)
	await wait_physics_frames(3)
	return scene
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
func _descend() -> void:
	_deploy()
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]: await _study(id)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(TwilightShelfData.RELEASE),OK)
	game.revision.ui.radio_page.hide()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	game.journey.caves_entry_enabled = true
	await game.journey.descend_caves()
	await wait_physics_frames(2)
	assert_true(game.journey.caves())
	game.submarine.set_simulation_enabled(false)
func _to_shrine() -> void:
	game.submarine.global_position = DrownedCavesData.shrine_at()+Vector2(-100,0)
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(false)
func _press(button_name: String) -> void:
	var button: Button = game.revision.ui.find_child(button_name,true,false) as Button
	assert_not_null(button,"button %s" % button_name)
	if button!=null: button.pressed.emit()
func _written() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
func _base_sonar() -> float:
	return game.revision.tree.sonar_radii[int(game.revision.campaign.ranks.sonar)]
# ---------------------------------------------------------------- authored data
func test_the_two_choices_are_a_valid_exclusive_encounter_with_the_approved_resonance() -> void:
	assert_true(StoryState.CATALOG.is_valid())
	var leave: ChoiceData = StoryState.CATALOG.definition(DrownedCavesData.CRYSTAL_LEAVE)
	var take: ChoiceData = StoryState.CATALOG.definition(DrownedCavesData.CRYSTAL_TAKE)
	assert_not_null(leave)
	assert_not_null(take)
	assert_eq(leave.encounter_id,DrownedCavesData.CRYSTAL_ENCOUNTER)
	assert_eq(take.encounter_id,DrownedCavesData.CRYSTAL_ENCOUNTER)
	assert_eq(leave.resonance_delta,15,"brief decision E: +15 for leaving")
	assert_eq(take.resonance_delta,-15,"and -15 for taking")
	assert_false(leave.exceptional_weight)
	assert_has(leave.flags,&"zone3-listeners-noticed")
	assert_has(take.flags,&"zone3-keepers-cold")
	for choice: ChoiceData in [leave,take]:
		assert_true(choice.is_valid())
		assert_true(choice.research_record_id.is_empty(),"no research record: no points")
	assert_true(DrownedCavesData.CALIBRATION.is_valid())
	assert_eq(DrownedCavesData.CALIBRATION.sonar_range_bonus,200.0)
func test_the_shrine_sits_in_open_water_away_from_the_anchor_and_the_other_records() -> void:
	await _descend()
	var at: Vector2 = DrownedCavesData.shrine_at()
	assert_true(Rect2(DrownedCavesLayout.CAMERA).has_point(at))
	assert_true(game.saves.position_clear(at,0.0))
	assert_true(game.saves.position_clear(at+Vector2(-100,0),0.0),"room to approach")
	assert_gt(at.distance_to(DrownedCavesLayout.SPAWN),1000.0,"not at the anchor")
	for item: Dictionary in DrownedCavesData.records():
		assert_gt(at.distance_to(item.at),DrownedCavesData.SHRINE_RADIUS*2.0,"%s is not within the shrine's reach" % item.id)
# ---------------------------------------------------------------- interaction
func test_the_prompt_and_interact_work_only_beside_the_shrine_in_the_caves() -> void:
	await _descend()
	var shrine: DrownedCavesShrine = game.journey.caves_shrine
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(shrine.prompt(),"")
	assert_false(shrine.interact())
	_to_shrine()
	assert_string_contains(shrine.prompt(),"Examine the crystal")
	assert_true(shrine.interact(),"Interact beside the shrine handles the press")
	assert_false(game.submarine.is_physics_processing(),"the page pauses the vessel")
	assert_not_null(game.revision.ui.find_child("LeaveCrystal",true,false))
	assert_not_null(game.revision.ui.find_child("TakeCrystal",true,false))
	game.revision.ui.radio_page.hide()
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	_to_shrine()
	assert_false(shrine.enabled)
	assert_eq(shrine.prompt(),"","not at Halcyon even at the coordinates")
	assert_false(shrine.interact())
func test_closing_the_page_decides_nothing() -> void:
	await _descend()
	_to_shrine()
	var before: Dictionary = game.story.snapshot()
	assert_true(game.journey.caves_shrine.interact())
	_press("StoryBack")
	assert_eq(game.story.snapshot(),before,"no decision")
	assert_false(game.journey.caves_shrine.resolved())
	assert_true(game.submarine.is_physics_processing(),"piloting resumes")
# ---------------------------------------------------------------- leave
func test_leaving_scores_plus_fifteen_sets_its_flags_and_changes_no_capability() -> void:
	await _descend()
	_to_shrine()
	var resonance: int = game.story.resonance()
	var sonar: float = game.submarine.sonar.maximum_radius()
	assert_true(game.journey.caves_shrine.interact())
	_press("LeaveCrystal")
	assert_true(game.story.has_decision(DrownedCavesData.CRYSTAL_LEAVE))
	assert_eq(game.story.resonance(),resonance+15)
	assert_true(game.story.has_flag(&"zone3-crystal-left"))
	assert_true(game.story.has_flag(&"zone3-listeners-noticed"))
	assert_eq(game.submarine.sonar.maximum_radius(),sonar,"no upgrade for leaving")
	assert_false(game.journey.caves_shrine.taken())
	assert_not_null(game.revision.ui.find_child("ReturnFromShrine",true,false),"the response page shows")
	var written: Dictionary = _written()
	assert_has(written.story.decisions,String(DrownedCavesData.CRYSTAL_LEAVE),"committed atomically with the choice")
	assert_eq(ExpeditionSchema.decode(written.duplicate(true)).error,OK)
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_TAKE),ERR_ALREADY_EXISTS,"the choice is exclusive")
# ---------------------------------------------------------------- take
func test_taking_scores_minus_fifteen_grants_the_derived_calibration_and_collapses_the_shrine() -> void:
	await _descend()
	_to_shrine()
	var resonance: int = game.story.resonance()
	var base: float = game.submarine.sonar.maximum_radius()
	assert_true(game.journey.caves_shrine.interact())
	_press("TakeCrystal")
	assert_not_null(game.revision.ui.find_child("ConfirmTake",true,false),"taking asks to confirm")
	assert_false(game.story.has_decision(DrownedCavesData.CRYSTAL_TAKE),"nothing yet")
	_press("ConfirmTake")
	assert_true(game.story.has_decision(DrownedCavesData.CRYSTAL_TAKE))
	assert_eq(game.story.resonance(),resonance-15)
	assert_true(game.story.has_flag(&"zone3-crystal-taken"))
	assert_true(game.story.has_flag(&"zone3-keepers-cold"))
	assert_eq(game.submarine.sonar.maximum_radius(),base+DrownedCavesData.CALIBRATION.sonar_range_bonus,"one calibration, once")
	assert_true(game.journey.caves_shrine.taken())
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_LEAVE),ERR_ALREADY_EXISTS)
	assert_eq(game.submarine.sonar.maximum_radius(),base+200.0,"it does not stack")
func test_the_calibration_survives_continue_and_a_fresh_launch() -> void:
	await _descend()
	_to_shrine()
	var base: float = game.submarine.sonar.maximum_radius()
	assert_true(game.journey.caves_shrine.interact())
	_press("TakeCrystal")
	_press("ConfirmTake")
	game.revision.ui.radio_page.hide()
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.save_current(),OK)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.sonar.maximum_radius(),base+200.0,"Continue re-derives it")
	var reloaded: ShelfPrototype = await _new_game()
	assert_eq(reloaded.saves.continue_expedition(),OK)
	assert_true(reloaded.story.has_decision(DrownedCavesData.CRYSTAL_TAKE))
	assert_eq(reloaded.submarine.sonar.maximum_radius(),base+200.0,"a fresh launch re-derives it")
	assert_true(reloaded.journey.caves_shrine.taken())
func test_no_points_no_experience_and_no_mission_change_for_either_choice() -> void:
	await _descend()
	_to_shrine()
	var points: int = CampaignData.earned(game.revision.campaign)
	var experience: int = ResearchExperienceData.total(game.revision.campaign.science)
	var missions: Dictionary = game.missions.snapshot().duplicate(true)
	var awards: Array = game.revision.campaign.awards.duplicate()
	assert_true(game.journey.caves_shrine.interact())
	_press("TakeCrystal")
	_press("ConfirmTake")
	assert_eq(CampaignData.earned(game.revision.campaign),points)
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),experience)
	assert_eq(game.missions.snapshot(),missions)
	assert_eq(game.revision.campaign.awards,awards,"no award: the upgrade is derived from the decision")
	assert_eq(game.journey.snapshot(),{"phase":"caves","commissioned":true})
	var written: Dictionary = _written()
	assert_eq(int(written.schema_version),ExpeditionSchema.VERSION)
	assert_eq(written.size(),12)
# ---------------------------------------------------------------- authority and validation
func test_the_decision_is_refused_away_from_the_shrine_and_outside_the_caves() -> void:
	await _descend()
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_LEAVE),ERR_UNAUTHORIZED,"not beside the shrine")
	assert_false(game.story.has_decision(DrownedCavesData.CRYSTAL_LEAVE))
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	_to_shrine()
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_TAKE),ERR_UNAVAILABLE,"not at Halcyon")
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	_to_shrine()
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_TAKE),ERR_UNAVAILABLE,"not in Twilight")
	assert_false(game.story.has_decision(DrownedCavesData.CRYSTAL_TAKE))
func test_a_checkpoint_with_a_crystal_decision_before_the_debrief_is_rejected() -> void:
	await _descend()
	_to_shrine()
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_LEAVE),OK)
	var written: Dictionary = _written()
	assert_eq(ExpeditionSchema.decode(written.duplicate(true)).error,OK)
	# The same story in a Twilight-era checkpoint: the debrief unclaimed (state and its award reverted).
	var forged: Dictionary = written.duplicate(true)
	forged.journey = {"phase":"refit","commissioned":true}
	forged.region_id = ExpeditionJourneyState.SHELF
	forged.progress.missions[String(TwilightShelfData.MISSION)].state = "completed"
	forged.prototype.campaign.awards.erase("twilight-expedition")
	assert_eq(ExpeditionSchema.decode(forged).error,ERR_INVALID_DATA,"a crystal decision needs the claimed debrief")
func test_guidance_mentions_the_shrine_until_it_is_decided() -> void:
	await _descend()
	game.submarine.global_position = DrownedCavesData.record(DrownedCavesData.MARA_LOG_ONE).at-Vector2(90,0)
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_eq(game.submarine.scanner.request_scan(DrownedCavesData.MARA_LOG_ONE),OK)
	assert_eq(game.submarine.scanner.advance(5.0),OK)
	game.submarine.set_simulation_enabled(false)
	assert_string_contains(game.journey.caves_guidance(),"crystal shrine")
	_to_shrine()
	assert_eq(game.story.apply_choice(DrownedCavesData.CRYSTAL_LEAVE),OK)
	assert_false(game.journey.caves_guidance().contains("crystal shrine"),"decided")
	assert_string_contains(game.journey.caves_guidance(),"Mara's log recorded")
