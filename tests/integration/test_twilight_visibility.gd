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
func test_visibility_scopes_accepted_pings_pause_and_restore_without_discovering() -> void:
	var view: TwilightVisibility = game.journey.visibility
	assert_gte(view.contours.get_child_count(),game.journey.layout.bodies.size())
	game.submarine.sonar.pulse_emitted.emit(AcousticEvent.create(&"test/early",&"test/source",&"active_sonar",&"scientific",Vector2.ZERO,1,100,0))
	assert_eq(view.speeds[0],0.0)
	_deploy()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	var before: Dictionary = game.saves.progress_snapshot()
	assert_eq(game.submarine.sonar.request_ping(),OK)
	assert_gt(view.speeds[0],0.0)
	var origin: Vector4 = view.pings[0]
	game.submarine.set_simulation_enabled(false)
	view._process(0.5)
	assert_eq(view.pings[0].z,0.0)
	assert_eq(game.saves.progress_snapshot(),before)
	assert_eq(view.pings[0].x,origin.x)
	view.clear_echoes()
	assert_eq(view.speeds[0],0.0)
