extends GutTest
## DC-6: the chapter close. The descent is on by default, the Halcyon debrief is derived (nothing is
## saved or awarded), the Twilight text no longer says the caves are closed, the dock log lists the cave
## records, and the Twilight/first-chapter debrief buttons stay exclusive (a DC-1 dock bug fixed here).
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	path = "user://dc6-%d.json" % Time.get_ticks_usec()
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
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
## To the Halcyon dock with the Twilight debrief claimed. Deliberately never touches caves_entry_enabled.
func _claim_twilight(choice: StringName,then_killed: bool = false) -> void:
	_deploy()
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]: await _study(id)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(choice),OK)
	if then_killed: assert_eq(game.story.set_flag(&"zone2-released-sentinel-lost"),OK)
	game.revision.ui.radio_page.hide()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
func _descend() -> void:
	await game.journey.descend_caves()
	await wait_physics_frames(2)
	assert_true(game.journey.caves())
	game.submarine.set_simulation_enabled(false)
func _scan(id: StringName) -> void:
	game.submarine.global_position = DrownedCavesData.record(id).at-Vector2(90,0)
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_eq(game.submarine.scanner.request_scan(id),OK)
	assert_eq(game.submarine.scanner.advance(5.0),OK)
	game.submarine.set_simulation_enabled(false)
	assert_true(game.research.is_completed(id))
func _return_to_halcyon() -> void:
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	game.revision.ui.show_dock()
func _crystal(id: StringName) -> void:
	game.submarine.global_position = DrownedCavesData.shrine_at()+Vector2(-100,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(id),OK)
	game.revision.ui.radio_page.hide()
func _texts(root: Node) -> String:
	var result: PackedStringArray = []
	for node: Node in root.find_children("*","Label",true,false): result.append((node as Label).text)
	return "\n".join(result)
## The dock keeps its replaced buttons hidden and queued for deletion until the frame ends, so a plain find_child
## can return a button the player no longer has. Only a live one counts.
func _button(button_name: String) -> Button:
	for found: Node in game.revision.ui.find_children(button_name,"Button",true,false):
		if not found.is_queued_for_deletion(): return found as Button
	return null
func _debrief_after(choice: StringName,then_killed: bool,crystal: StringName) -> String:
	await _claim_twilight(choice,then_killed)
	await _descend()
	await _scan(DrownedCavesData.MARA_LOG_ONE)
	if crystal!=&"": _crystal(crystal)
	_return_to_halcyon()
	assert_true(game.journey.caves_debrief_available())
	return game.journey.caves_debrief_text()
# ---------------------------------------------------------------- the descent
func test_the_descent_is_offered_by_default_and_the_dock_buttons_stay_exclusive() -> void:
	await _claim_twilight(TwilightShelfData.RELEASE)
	assert_true(game.journey.caves_entry_enabled)
	game.revision.ui.show_dock()
	assert_not_null(_button("TwilightDebrief"),"the Twilight debrief")
	assert_null(_button("ChapterDebrief"),"never the first-chapter debrief beside it (the DC-1 dock bug)")
	assert_not_null(_button("CavesDescent"),"the descent, with no developer flag")
	assert_null(_button("CavesDebrief"),"no caves debrief before Mara's log is recorded")
	await game.journey.descend_caves()
	await wait_physics_frames(2)
	assert_true(game.journey.caves())
func test_the_player_facing_text_no_longer_says_foundation_or_closed() -> void:
	await _claim_twilight(TwilightShelfData.RELEASE)
	game.journey.offer_caves()
	var offer: String = _texts(game.revision.ui.radio_page)
	assert_false(offer.to_lower().contains("foundation"),"descent offer")
	assert_string_contains(offer,"THE DROWNED CAVES / DESCENT")
	var minutes: String = "%.0f" % (ChapterJourney.CAVES_RESOURCES.max_oxygen/ChapterJourney.CAVES_RESOURCES.oxygen_drain_per_second/60.0)
	assert_string_contains(offer,"about "+minutes+" minutes")
	game.revision.ui.radio_page.hide()
	await _descend()
	assert_false(String(game.revision.ui.notifications.texts.get("caves-arrival","")).to_lower().contains("foundation"),"arrival notice")
	assert_false((game.route_menu.get_node("%Brief") as Label).text.to_lower().contains("foundation"),"pause brief")
	assert_false(game.journey.expedition.debrief_text().contains("not playable"),"the Twilight debrief no longer says the caves are closed")
	assert_string_contains(game.journey.expedition.debrief_text(),"The Drowned Caves are open")
	assert_false(TwilightShelfData.missions().definition(TwilightShelfData.MISSION).acknowledgement.contains("not playable"))
# ---------------------------------------------------------------- the debrief
func test_the_debrief_waits_for_mara_s_log_and_for_halcyon() -> void:
	await _claim_twilight(TwilightShelfData.RELEASE)
	await _descend()
	assert_false(game.journey.caves_debrief_available(),"not before the required log, and not in the caves")
	await _scan(DrownedCavesData.PAINTINGS)
	_return_to_halcyon()
	assert_false(game.journey.caves_debrief_available(),"an optional record does not unlock it")
	assert_null(_button("CavesDebrief"))
	game.journey.caves_entry_enabled = true
	await _descend()
	await _scan(DrownedCavesData.MARA_LOG_ONE)
	assert_false(game.journey.caves_debrief_available(),"still in the caves")
	_return_to_halcyon()
	assert_true(game.journey.caves_debrief_available())
	assert_not_null(_button("CavesDebrief"))
	game.journey.caves_debrief_enabled = false
	assert_false(game.journey.caves_debrief_available(),"the smoke seam closes it")
func test_a_released_sentinel_and_a_left_crystal_read_as_gratitude() -> void:
	var text: String = await _debrief_after(TwilightShelfData.RELEASE,false,DrownedCavesData.CRYSTAL_LEAVE)
	assert_string_contains(text,"The animal you freed kept its distance and lit the way")
	assert_string_contains(text,"You left the crystal in its niche")
	assert_string_contains(text,"1 of 4 records","only Mara's log is recorded")
func test_a_captured_sentinel_and_a_taken_crystal_name_the_upgrade_from_the_resource() -> void:
	var text: String = await _debrief_after(TwilightShelfData.CAPTURE,false,DrownedCavesData.CRYSTAL_TAKE)
	assert_string_contains(text,"The specimen is safe aboard")
	assert_string_contains(text,"%.0f units farther" % DrownedCavesData.CALIBRATION.sonar_range_bonus)
	assert_string_contains(text,"Write down what you took")
func test_a_lost_sentinel_with_an_undecided_shrine_says_the_shrine_remains() -> void:
	var text: String = await _debrief_after(TwilightShelfData.LOST,false,&"")
	assert_string_contains(text,"The animal died in the net")
	assert_string_contains(text,"The shrine is still there")
func test_a_released_sentinel_that_was_killed_is_a_loss_not_a_guide() -> void:
	var text: String = await _debrief_after(TwilightShelfData.RELEASE,true,&"")
	assert_string_contains(text,"The animal that would have gone first is dead")
	assert_false(text.contains("lit the way"))
func test_every_debrief_has_the_teaser_the_record_count_and_nothing_hostile() -> void:
	var text: String = await _debrief_after(TwilightShelfData.RELEASE,false,&"")
	assert_string_contains(text,"The Furnace Vents are the next investigation; that region is not playable in this build.")
	assert_string_contains(text,"Nothing is awarded for this debrief.")
	assert_string_contains(text,"Archived from the site: 1 of 4 records.")
	for word: String in ["attack","hostile","hunt","weapon","enemy","kill"]:
		assert_false(text.to_lower().contains(word),word)
	assert_false(text.to_lower().contains("foundation"))
func test_showing_the_debrief_saves_and_awards_nothing_and_returns_to_the_dock() -> void:
	await _debrief_after(TwilightShelfData.RELEASE,false,&"")
	var file_before: String = FileAccess.get_file_as_string(game.saves.store.path)
	var story: Dictionary = game.story.snapshot()
	var missions: Dictionary = game.missions.snapshot().duplicate(true)
	var points: int = CampaignData.earned(game.revision.campaign)
	var awards: Array = game.revision.campaign.awards.duplicate()
	var research: Array[StringName] = game.research.completed_ids()
	_button("CavesDebrief").pressed.emit()
	assert_true(game.revision.ui.radio_page.visible)
	assert_string_contains(_texts(game.revision.ui.radio_page),"HALCYON / THE DROWNED CAVES")
	assert_string_contains(_texts(game.revision.ui.radio_page),game.journey.caves_debrief_text().substr(0,40))
	assert_not_null(_button("CavesDebriefBack"))
	_button("CavesDebriefBack").pressed.emit()
	assert_false(game.revision.ui.radio_page.visible)
	assert_eq(FileAccess.get_file_as_string(game.saves.store.path),file_before,"no checkpoint written")
	assert_eq(game.story.snapshot(),story)
	assert_eq(game.missions.snapshot(),missions)
	assert_eq(CampaignData.earned(game.revision.campaign),points)
	assert_eq(game.revision.campaign.awards,awards)
	assert_eq(game.research.completed_ids(),research)
func test_the_dock_log_lists_the_recorded_cave_records_after_the_twilight_entries() -> void:
	await _claim_twilight(TwilightShelfData.RELEASE)
	await _descend()
	await _scan(DrownedCavesData.MARA_LOG_ONE)
	await _scan(DrownedCavesData.GLYPH_WALL)
	_return_to_halcyon()
	var log: String = game.journey.log_text()
	assert_true(log.find("Twilight Shelf")>=0,"Twilight's entries are first")
	for id: StringName in [DrownedCavesData.MARA_LOG_ONE,DrownedCavesData.GLYPH_WALL]:
		assert_true(log.find(String(DrownedCavesData.record(id).title))>log.find("Twilight Shelf"),"%s follows" % id)
	assert_false(log.contains(String(DrownedCavesData.record(DrownedCavesData.PAINTINGS).title)),"unrecorded records are not listed")
	game.revision.ui.show_dock("logs")
	assert_string_contains(_texts(game.revision.ui.dock_page),String(DrownedCavesData.record(DrownedCavesData.GLYPH_WALL).title))
