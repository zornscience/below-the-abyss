extends GutTest
## DC-4: the first-contact site. Four scan records (one required, three optional) registered with the
## real scan gate and the save validator, no mission, no research points, no experience. Coordinates come
## from the authored data; scans, collision and checkpoints are real.
var game: ShelfPrototype
var path: String
var view: SubViewport
func before_each() -> void:
	view = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	path = "user://dc4-%d.json" % Time.get_ticks_usec()
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
## Scan a cave record with the real scanner from beside it, in open water.
func _scan(id: StringName) -> void:
	game.submarine.global_position = DrownedCavesData.record(id).at-Vector2(90,0)
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_eq(game.submarine.scanner.request_scan(id),OK,"scan %s" % id)
	assert_eq(game.submarine.scanner.advance(5.0),OK)
	game.submarine.set_simulation_enabled(false)
	assert_true(game.research.is_completed(id),"%s recorded" % id)
func _written() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
# ---------------------------------------------------------------- authored data
func test_four_records_one_required_registered_in_the_shared_catalogs() -> void:
	var records: Array[Dictionary] = DrownedCavesData.records()
	assert_eq(records.size(),4)
	assert_eq(DrownedCavesData.REQUIRED,DrownedCavesData.MARA_LOG_ONE)
	var ids: Array[String] = []
	for item: Dictionary in records:
		assert_false(String(item.id) in ids,"unique id")
		ids.append(String(item.id))
		assert_false(TwilightShelfData.knows(StringName(item.id)),"Twilight's own lookups never see a cave record")
	assert_eq(TwilightShelfData.RECORDS.size(),17,"Twilight's authored list is unchanged")
	assert_eq(TwilightShelfData.all_records().size(),TwilightShelfData.RECORDS.size()+TwilightTunnelCatalog.records().size())
	assert_eq(TwilightShelfData.catalog_records().size(),TwilightShelfData.all_records().size()+4)
	assert_true(TwilightShelfData.research().is_valid())
	assert_true(TwilightShelfData.discoveries().is_valid())
	var catalog_ids: Array[StringName] = []
	for target: Resource in TwilightShelfData.research().targets: catalog_ids.append(target.stable_id)
	for id: String in ids: assert_has(catalog_ids,StringName(id))
func test_every_record_is_a_valid_log_entry_and_the_text_stays_within_the_bible() -> void:
	for item: Dictionary in DrownedCavesData.records():
		var entry: NarrativeEntry = NarrativeEntry.new()
		entry.stable_id = StringName(item.id)
		entry.title = item.title
		entry.text = item.text
		assert_true(entry.is_valid(),String(item.id))
		assert_true(item.source in ["Wick","Mara"])
		assert_eq(item.source=="Mara",String(item.id).contains("mara-log"))
		if item.source=="Mara": assert_true(String(item.text).begins_with("Mara Voss /"),"Mara's logs use her recorder header")
	assert_string_contains(DrownedCavesData.record(DrownedCavesData.GLYPH_WALL).text,"Vow of Silence")
	assert_string_contains(DrownedCavesData.record(DrownedCavesData.GLYPH_WALL).text,"Silence. Deep water. Withdrawal.")
	assert_string_contains(DrownedCavesData.record(DrownedCavesData.PAINTINGS).text,"handprints")
	assert_string_contains(DrownedCavesData.record(DrownedCavesData.MARA_LOG_ONE).text,"language")
func test_records_sit_in_open_water_in_the_far_chamber_and_the_blind_pocket() -> void:
	await _descend()
	var profile: TunnelProfile = DrownedCavesLayout.TUNNELS.systems[0] as TunnelProfile
	for item: Dictionary in DrownedCavesData.records():
		assert_true(Rect2(DrownedCavesLayout.CAMERA).has_point(item.at),"%s inside the cave" % item.id)
		assert_true(game.saves.position_clear(item.at,0.0),"%s sits in open water" % item.id)
		assert_true(game.saves.position_clear(item.at-Vector2(90,0),0.0),"%s has room to scan from" % item.id)
	assert_lt(DrownedCavesData.record(DrownedCavesData.REQUIRED).at.distance_to(DrownedCavesLayout.FAR_CHAMBER),1800.0,"the required log is in the far chamber")
	assert_eq(DrownedCavesData.record(DrownedCavesData.MARA_LOG_TWO).at,profile.origin+profile.branch[-1],"the optional log fills the blind pocket")
# ---------------------------------------------------------------- scanning
func test_each_record_is_scanned_with_the_real_scanner_and_its_text_is_delivered() -> void:
	await _descend()
	for item: Dictionary in DrownedCavesData.records():
		var id: StringName = StringName(item.id)
		await _scan(id)
		assert_eq(String(game.revision.ui.notifications.texts.get(String(id),"")),String(item.text),"the scan delivers the authored text")
		assert_eq(String(game.revision.ui.notifications.sources.get(String(id),"")),String(item.source))
	var logged: Array[StringName] = []
	for entry: NarrativeEntry in game.journey.entries(): logged.append(entry.stable_id)
	for id: StringName in DrownedCavesData.ids(): assert_has(logged,id)
func test_a_scan_commits_an_atomic_checkpoint_that_decodes_and_survives_continue() -> void:
	await _descend()
	await _scan(DrownedCavesData.MARA_LOG_ONE)
	var written: Dictionary = _written()
	assert_has(written.progress.research,String(DrownedCavesData.MARA_LOG_ONE))
	assert_eq(int(written.schema_version),ExpeditionSchema.VERSION)
	assert_eq(written.size(),12)
	assert_eq(ExpeditionSchema.decode(written.duplicate(true)).error,OK,"the schema accepts a cave record")
	var forged: Dictionary = written.duplicate(true)
	forged.progress.research.append("caves-forged-record")
	assert_eq(ExpeditionSchema.decode(forged).error,ERR_INVALID_DATA,"an unknown cave record is rejected")
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.continue_expedition(),OK)
	assert_true(game.research.is_completed(DrownedCavesData.MARA_LOG_ONE),"Continue keeps the record")
func test_scanning_is_refused_out_of_range_and_outside_the_caves() -> void:
	await _descend()
	var id: StringName = DrownedCavesData.MARA_LOG_ONE
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_ne(game.submarine.scanner.request_scan(id),OK,"out of range")
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	game.submarine.global_position = DrownedCavesData.record(id).at-Vector2(90,0)
	assert_false(game.journey.caves_site.enabled)
	assert_false(game.submarine.scanner.eligible(id),"not scannable at Halcyon even beside the record")
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	game.submarine.global_position = DrownedCavesData.record(id).at-Vector2(90,0)
	assert_false(game.submarine.scanner.eligible(id),"not scannable in Twilight")
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.saves.transfer_chapter("caves",true),OK)
	assert_true(game.journey.caves_site.enabled)
	game.submarine.global_position = DrownedCavesData.record(id).at-Vector2(90,0)
	assert_true(game.submarine.scanner.eligible(id),"scannable again in the caves")
## A scan is an atomic checkpoint, and a checkpoint is refused at zero oxygen: the scan must then be
## NOT RECORDED, in the caves exactly as in Twilight. Without the gate it would be recorded anyway
## (and saved by the next autosave), which would hide the rule in the zone where oxygen is the pressure.
func _attempt_at_zero_oxygen(id: StringName,at: Vector2) -> void:
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	game.submarine.global_position = at
	game.submarine.velocity = Vector2.ZERO
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_eq(game.submarine.scanner.request_scan(id),OK)
	assert_eq(game.submarine.scanner.advance(5.0),OK)
	game.submarine.set_simulation_enabled(false)
func test_a_cave_scan_at_zero_oxygen_is_refused_and_says_so() -> void:
	await _descend()
	var id: StringName = DrownedCavesData.MARA_LOG_ONE
	await _attempt_at_zero_oxygen(id,DrownedCavesData.record(id).at-Vector2(90,0))
	assert_false(game.research.is_completed(id),"not recorded without oxygen for the checkpoint")
	assert_string_contains(game.submarine.scanner.snapshot().text,"NOT RECORDED")
	assert_string_contains(game.submarine.scanner.snapshot().text,"Oxygen depleted")
func test_a_twilight_scan_at_zero_oxygen_is_still_refused_through_the_chain() -> void:
	_deploy()
	var id: StringName = &"twilight-severed-cable"
	await _attempt_at_zero_oxygen(id,game.research.definition(id).position-Vector2(90,0))
	assert_false(game.research.is_completed(id),"the Twilight gate still runs behind the cave gate")
	assert_string_contains(game.submarine.scanner.snapshot().text,"NOT RECORDED")
func test_twilight_scans_still_work_alongside_the_cave_gate() -> void:
	_deploy()
	await _study(&"twilight-severed-cable")
	assert_true(game.research.is_completed(&"twilight-severed-cable"))
	assert_has(_written().progress.research,"twilight-severed-cable")
# ---------------------------------------------------------------- economy, missions, guidance
func test_the_site_changes_no_points_no_experience_and_no_mission() -> void:
	await _descend()
	var points: int = CampaignData.earned(game.revision.campaign)
	var experience: int = ResearchExperienceData.total(game.revision.campaign.science)
	var missions: Dictionary = game.missions.snapshot().duplicate(true)
	for id: StringName in DrownedCavesData.ids():
		assert_eq(ResearchExperienceData.RULES.award_for(id),0)
		assert_eq(ResearchExperienceData.TWILIGHT.award_for(id),0)
		await _scan(id)
	assert_eq(CampaignData.earned(game.revision.campaign),points,"no research points")
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),experience,"no experience")
	assert_eq(game.missions.snapshot(),missions,"no mission changed")
	assert_eq(game.journey.snapshot(),{"phase":"caves","commissioned":true})
func test_guidance_asks_for_the_required_log_then_calls_the_rest_optional() -> void:
	await _descend()
	assert_string_contains(game.journey.caves_guidance(),"scan Mara's recorder")
	await _scan(DrownedCavesData.PAINTINGS)
	assert_string_contains(game.journey.caves_guidance(),"scan Mara's recorder","an optional scan does not finish the goal")
	await _scan(DrownedCavesData.MARA_LOG_ONE)
	assert_string_contains(game.journey.caves_guidance(),"Mara's log recorded")
	assert_string_contains(game.journey.caves_guidance(),"optional")
	assert_eq(game.mission_tracker.detail.text,game.journey.caves_guidance(),"the tracker shows it")
func test_the_placeholder_art_is_drawn_only_in_the_caves() -> void:
	await _descend()
	assert_true(game.journey.caves_site.visible)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_false(game.journey.caves_site.visible)
