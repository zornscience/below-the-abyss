extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta058-%d" % Time.get_ticks_usec()
	game.settings_path = path+".json"
	game.expedition_path = path+".expedition.json"
	view.add_child(game)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for file: String in DirAccess.get_files_at("user://"):
		if file.begins_with(path.get_file()): DirAccess.remove_absolute("user://"+file)
func test_selection_preserves_supplies_upgrades_and_shallow_costs() -> void:
	var sonar: SonarEmitter = game.submarine.sonar
	var torpedoes: TorpedoLauncher = game.torpedoes
	assert_eq(sonar.battery_cost(),4.0)
	assert_eq(torpedoes._rules.battery_cost,2.0)
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	pools.consume_battery(37.0)
	pools.consume_oxygen(19.0)
	var radius: float = sonar._rules.maximum_radius
	for phase: String in ["twilight","refit","sunlit","prototype","twilight"]:
		game.journey.prepare({"phase":phase,"commissioned":true})
		assert_eq(sonar.battery_cost(),ChapterJourney.ACTION_COSTS.ping_battery if phase=="twilight" else 4.0)
		assert_eq(torpedoes._rules.battery_cost,ChapterJourney.ACTION_COSTS.torpedo_battery if phase=="twilight" else 2.0)
		assert_eq(pools.battery,63.0)
		assert_eq(pools.oxygen,81.0)
		assert_eq(sonar._rules.maximum_radius,radius)
	assert_eq(preload("res://resources/balance/prototype_sonar.tres").battery_cost,4.0)
	assert_eq(preload("res://resources/balance/torpedo_profile.tres").battery_cost,2.0)
func test_actions_debit_exactly_and_rejection_preserves_ammo_cooldown_and_events() -> void:
	game.journey.prepare({"phase":"twilight","commissioned":true})
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	var costs: ActionCostProfile = ChapterJourney.ACTION_COSTS
	game.submarine.set_simulation_enabled(true)
	watch_signals(game.submarine.sonar)
	watch_signals(game.torpedoes)
	var before: float = pools.battery
	assert_eq(game.submarine.sonar.request_ping(),OK)
	assert_eq(pools.battery,before-costs.ping_battery)
	assert_eq(game.torpedoes.request_fire(),OK)
	assert_eq(pools.battery,before-costs.ping_battery-costs.torpedo_battery)
	game.submarine.sonar.advance(game.submarine.sonar._rules.cooldown_seconds)
	game.torpedoes._cooldown = 0.0
	pools.consume_battery(pools.battery)
	pools.restore_battery(minf(costs.ping_battery,costs.torpedo_battery)-0.1)
	var insufficient: float = pools.battery
	var ammo: int = game.torpedoes.ammunition
	var sequence: int = game.torpedoes._sequence
	assert_eq(game.submarine.sonar.request_ping(),ERR_UNAVAILABLE)
	assert_eq(game.torpedoes.request_fire(),ERR_UNAVAILABLE)
	assert_eq(game.torpedoes.ammunition,ammo)
	assert_eq(game.torpedoes._sequence,sequence)
	assert_eq(game.torpedoes._cooldown,0.0)
	assert_eq(game.submarine.sonar.cooldown_remaining(),0.0)
	assert_eq(pools.battery,insufficient)
	assert_signal_emit_count(game.submarine.sonar,"pulse_emitted",1)
	assert_signal_emit_count(game.torpedoes,"fired",1)
	pools.consume_battery(pools.battery)
	var start: Vector2 = game.submarine.global_position
	Input.action_press("move_right")
	await wait_physics_frames(20)
	Input.action_release("move_right")
	assert_gt(game.submarine.global_position.distance_to(start),0.0,"Empty battery does not disable thrust")

func test_empty_battery_tether_refit_and_continue_preserve_actual_supplies() -> void:
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
	game.submarine.resource_system.consume_battery(100.0)
	game.submarine.resource_system.consume_oxygen(17.0)
	assert_true(game.journey.near_tether(),"Empty battery leaves tether access available")
	assert_eq(game.saves.save_current(),OK)
	game.submarine.resource_system.restore_battery(50.0)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.resource_system.battery,0.0)
	assert_eq(game.submarine.resource_system.oxygen,83.0)
	assert_eq(game.submarine.sonar.battery_cost(),ChapterJourney.ACTION_COSTS.ping_battery)
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.submarine.resource_system.battery,100.0)
	assert_eq(game.torpedoes.ammunition,TorpedoLauncher.CAPACITY)
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_eq(game.submarine.resource_system.battery,100.0)
