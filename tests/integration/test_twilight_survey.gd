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
func test_new_passages_pockets_and_old_outer_loops_clear_the_actual_hull() -> void:
	_deploy()
	await wait_physics_frames(2)
	var routes: Array = [TwilightShelfLayout.INNER_LOOP,TwilightShelfLayout.WEST_LOOP,TwilightShelfLayout.EAST_LOOP,
		[Vector2(31950,2300),TwilightShelfLayout.WEST_POCKET,Vector2(31950,2300),TwilightShelfLayout.EAST_POCKET,Vector2(33450,2300)]]
	for route: Array in routes:
		for index: int in range(1,route.size()):
			var a: Vector2 = route[index-1]
			var b: Vector2 = route[index]
			var count: int = ceili(a.distance_to(b)/35.0)
			for step: int in range(count+1):
				var at: Vector2 = a.lerp(b,float(step)/count)
				assert_true(game.saves.position_clear(at,0),"Blocked hull at "+str(at))
	assert_false(game.saves.position_clear(Vector2(30800,2300),0),"West pocket has a real closed end")
	assert_false(game.saves.position_clear(Vector2(34500,2300),0),"East pocket has a real closed end")

func test_optional_records_persist_without_gating_or_resolving_the_required_encounter() -> void:
	_deploy()
	for id: StringName in TwilightShelfData.OPTIONAL_SURVEY: await _study(id)
	assert_false(TwilightShelfData.ready(game.research,game.story))
	assert_false(game.story.resolved(TwilightShelfData.ENCOUNTER))
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.save_current(),OK)
	watch_signals(game.research)
	assert_eq(game.saves.continue_expedition(),OK)
	for id: StringName in TwilightShelfData.OPTIONAL_SURVEY: assert_true(game.research.is_completed(id))
	assert_signal_not_emitted(game.research,"scan_completed")
	assert_eq(game.missions.snapshot()[String(TwilightShelfData.MISSION)].state,"accepted")

func test_sighting_is_transient_silent_paused_and_not_a_second_actor_or_discovery() -> void:
	_deploy()
	var expedition: TwilightExpedition = game.journey.expedition
	expedition.set_physics_process(false)
	game.submarine.global_position = Vector2(37800,2900)
	await wait_physics_frames(2)
	var before: Dictionary = game.saves.progress_snapshot()
	var bus: AcousticBus = game.get_node("AcousticBus") as AcousticBus
	watch_signals(bus)
	expedition.advance(0.5)
	assert_false(expedition.glimpse_seen,"Paused simulation cannot trigger a sighting")
	game.submarine.set_simulation_enabled(true)
	expedition.advance(0.5)
	assert_true(expedition.glimpse_seen)
	expedition.advance(0.5)
	assert_eq(game.saves.progress_snapshot(),before)
	assert_signal_not_emitted(bus,"event_dispatched")
	game.submarine.set_simulation_enabled(false)
	expedition.reset_session()
	assert_false(expedition.glimpse_seen)

func test_net_prompt_never_offers_a_scan_outside_scanner_radius() -> void:
	_deploy()
	game.submarine.global_position = TwilightShelfData.NET+Vector2(220,0)
	assert_true(game.journey.expedition.prompt().contains("Approach"))
	game.submarine.global_position = TwilightShelfData.NET+Vector2(189,0)
	assert_true(game.journey.expedition.prompt().contains("Scan"))

func test_guidance_respects_the_western_approach_before_eastern_evidence() -> void:
	_deploy()
	game.submarine.global_position = Vector2(29000,2900)
	assert_true(game.journey.expedition.guidance().contains("western whaler"))
	assert_false(game.research.is_completed(&"twilight-severed-cable"))
	game.submarine.global_position = Vector2(35800,1400)
	assert_true(game.journey.expedition.guidance().contains("sensor line"))

func test_research_log_only_shows_images_for_completed_records_and_keeps_them_scrollable() -> void:
	var image: TextureRect = game.research_log.get_node("%SubjectImage") as TextureRect
	assert_false(image.visible)
	_deploy()
	await _study(&"twilight-cargo-timber")
	game.research_log._select(&"twilight-cargo-timber")
	assert_true(image.visible)
	assert_true(image.texture is AtlasTexture)
	var original: Texture2D = image.texture
	game.research_log._select(&"twilight-net-survey")
	assert_eq(image.texture,original,"Undiscovered record cannot expose its image")
	assert_true(game.research_log.get_node("%DetailScroll").is_ancestor_of(image))
