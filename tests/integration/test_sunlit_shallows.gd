extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var viewport: SubViewport
var path: String
func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://bta047-%d.json" % Time.get_ticks_usec()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	game = _create()
func _create() -> ShelfPrototype:
	var node: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	node.settings_path = path
	node.expedition_path = path+".expedition.json"
	viewport.add_child(node)
	return node
func after_each() -> void:
	await get_tree().process_frame
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected", ".invalid"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
func _launch() -> void:
	game.chapter.start()
	assert_true(game.revision.ui.radio_page.visible)
	game.chapter.launch()
	assert_true(game.chapter.active)
	assert_eq(game.chapter.state(),"accepted")
func _bloom(collect: bool) -> void:
	game.submarine.global_position = Vector2(1280,480)
	game.submarine.velocity = Vector2.ZERO
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(2.0)
	assert_eq(game.bloom.interact(),OK)
	if collect: assert_eq(game.bloom.choose_collect(),OK)
	else:
		assert_eq(game.bloom.choose_observe(),OK)
		game.submarine.scanner.advance(3.0)
	game.bloom.leave()
func _buoy() -> void:
	game.submarine.sonar.advance(10.0)
	game.submarine.global_position = Vector2(3500,620)
	game.submarine.velocity = Vector2.ZERO
	game.route_check.sample(false,true,1.0)
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(2.0)
	assert_eq(game.discoveries.state_of(SunlitShallowsData.POI),DiscoveryRegistry.State.DISCOVERED)
	assert_eq(game.submarine.scanner.request_scan(SunlitShallowsData.BUOY),OK)
	game.submarine.scanner.advance(4.0)
	assert_true(game.research.is_completed(SunlitShallowsData.BUOY))
	game.chapter.close_buoy_message()
func _return_and_dock() -> void:
	game.submarine.global_position = game.region.spawn.global_position
	game.submarine.velocity = Vector2.ZERO
	game.route_check.sample(true,false,1.0)
	assert_eq(game.open_station(),OK)
func test_fresh_title_introduces_canon_without_accepting_or_scoring() -> void:
	assert_eq(game.chapter.state(),"available")
	assert_eq(game.story.resonance(),0)
	assert_false(game.chapter.active)
	assert_eq(game.missions.definitions().size(),6)
	var primary: Button = game.revision.ui.find_child("Begin",true,false) as Button
	assert_true(primary.text.contains("Sunlit Shallows"))
	game.chapter.start()
	game.chapter.ask_okafor()
	assert_eq(game.chapter.state(),"available")
	assert_false(game.submarine.is_physics_processing())
	game.chapter.cancel_briefing()
	assert_true(game.revision.ui.title_page.visible)
func test_peaceful_chapter_uses_existing_mission_research_route_and_station_apis() -> void:
	_launch()
	var previous: Dictionary = game.missions.snapshot()
	_bloom(false)
	_buoy()
	assert_true(game.chapter.log_text().contains(SunlitShallowsData.MESSAGE))
	assert_eq(game.chapter.state(),"accepted")
	_return_and_dock()
	assert_eq(game.chapter.state(),"completed")
	watch_signals(game.missions)
	assert_eq(game.chapter.debrief(game.station),OK)
	assert_eq(game.chapter.state(),"claimed")
	assert_true(game.chapter.concluded())
	assert_eq(game.story.resonance(),15)
	assert_eq(game.chapter.debrief(game.station),ERR_UNAVAILABLE)
	assert_signal_emit_count(game.missions,"acknowledgement_claimed",1)
	for id: String in previous:
		if id!=String(SunlitShallowsData.MISSION): assert_eq(game.missions.snapshot()[id],previous[id])
	assert_eq(game.revision.campaign.awards,["commission"])
func test_aggressive_choice_also_completes_without_combat_or_extra_rewards() -> void:
	_launch()
	_bloom(true)
	_buoy()
	_return_and_dock()
	assert_eq(game.chapter.debrief(game.station),OK)
	assert_eq(game.story.resonance(),-15)
	assert_eq(game.torpedoes.ammunition,10)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_eq(game.revision.campaign.awards,["commission"])
	assert_true(game.chapter.entries().back().text.contains("Twilight Shelf"))
func test_buoy_is_hidden_until_wavefront_and_intentional_scan_then_persists() -> void:
	_launch()
	assert_false(game.chapter.log_text().contains(SunlitShallowsData.MESSAGE))
	game.submarine.global_position = Vector2(3500,620)
	assert_ne(game.submarine.scanner.request_scan(SunlitShallowsData.BUOY),OK)
	_buoy()
	var saved: Dictionary = game.saves.store.read_file(game.expedition_path).data
	assert_has(saved.progress.research,String(SunlitShallowsData.BUOY))
	assert_false(saved.progress.missions[String(SunlitShallowsData.MISSION)].state=="claimed")
	game.free()
	game = _create()
	watch_signals(game.research)
	game.chapter.start()
	assert_true(game.chapter.log_text().contains(SunlitShallowsData.MESSAGE))
	assert_true(game.research.is_completed(SunlitShallowsData.BUOY))
	assert_signal_not_emitted(game.research,"scan_completed")
func test_old_return_does_not_count_until_message_is_recovered_and_brought_home() -> void:
	game.route_check.stage = GrayboxRouteCheck.Stage.COMPLETE
	_launch()
	assert_false("return-message-to-halcyon" in game.missions.snapshot()[String(SunlitShallowsData.MISSION)].objectives)
	game.route_check.sample(false,true,1.0)
	game.route_check.sample(true,false,1.0)
	assert_false("return-message-to-halcyon" in game.missions.snapshot()[String(SunlitShallowsData.MISSION)].objectives)
	_buoy()
	game.route_check.sample(true,false,0.0)
	assert_has(game.missions.snapshot()[String(SunlitShallowsData.MISSION)].objectives,"return-message-to-halcyon")
func test_boundaries_camera_and_map_stay_in_zone1_and_prototype_can_be_restored() -> void:
	_launch()
	assert_eq(game.chapter.boundary.collision_layer,1)
	assert_eq(game.region.camera_bounds,Rect2i(0,0,3900,800))
	assert_eq(game.exploration_map.canvas.bounds,SunlitShallowsData.BOUNDS)
	assert_lte(game.region.depth_at_world(Vector2(3500,620)),200.0)
	game.chapter._activate(false)
	assert_eq(game.chapter.boundary.collision_layer,0)
	assert_eq(game.region.camera_bounds,ShelfChapterData.BOUNDS)
func test_version_five_adds_unaccepted_chapter_without_rewriting_legacy_claims() -> void:
	var document: Dictionary = game.saves.snapshot()
	document.schema_version = 5
	document.progress.missions.erase(String(SunlitShallowsData.MISSION))
	var old: Dictionary = document.progress.duplicate(true)
	var loaded: Dictionary = ExpeditionSchema.decode(document)
	assert_eq(loaded.error,OK)
	assert_eq(loaded.data.schema_version,6)
	assert_eq(loaded.data.progress,old)
	var merged: Dictionary = ExpeditionSchema.merge_progress(loaded.data.progress,game.saves.progress_snapshot())
	assert_eq(merged.missions[String(SunlitShallowsData.MISSION)].state,"available")
	for id: String in old.missions: assert_eq(merged.missions[id],old.missions[id])
func test_failed_launch_and_forged_completion_do_not_grant_chapter_progress() -> void:
	game.chapter.start()
	game.saves._ready_to_write = false
	game.chapter.launch()
	assert_eq(game.chapter.state(),"available")
	assert_eq(game.story.resonance(),0)
	var data: Dictionary = game.saves.snapshot()
	data.progress.missions[String(SunlitShallowsData.MISSION)] = {"state":"claimed","objectives":["study-light-bloom","recover-maras-message","return-message-to-halcyon"]}
	assert_ne(ExpeditionSchema.decode(data).error,OK)

func test_briefing_focus_visits_every_action_and_never_duplicates_footer_controls() -> void:
	game.chapter.start()
	var ui: ExpeditionInterface = game.revision.ui
	var ask: Control = ui.find_child("AskOkafor",true,false) as Control
	var visited: Array[Control] = []
	var current: Control = ui._buttons[0]
	for index: int in range(ui._buttons.size()):
		assert_false(current in visited)
		visited.append(current)
		current = current.get_node(current.focus_next) as Control
	assert_has(visited,ask)
	assert_eq(current,visited[0])
func test_buoy_checkpoint_failure_leaves_no_record_message_or_completion() -> void:
	_launch()
	game.submarine.global_position = Vector2(3500,620)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2.0)
	assert_eq(game.submarine.scanner.request_scan(SunlitShallowsData.BUOY),OK)
	game.saves._ready_to_write = false
	game.submarine.scanner.advance(4.0)
	assert_false(game.research.is_completed(SunlitShallowsData.BUOY))
	assert_false(game.revision.ui.radio_page.visible)
	assert_false(game.chapter.log_text().contains(SunlitShallowsData.MESSAGE))
	assert_true(game.submarine.scanner.snapshot().text.contains("NOT RECORDED"))
func test_pause_freezes_buoy_scanning_and_mute_does_not_hide_its_message() -> void:
	_launch()
	var audio: Dictionary = game.settings.snapshot().audio
	audio.muted = true
	game.settings.set_audio(audio)
	game.submarine.global_position = Vector2(3500,620)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2.0)
	game.submarine.scanner.request_scan(SunlitShallowsData.BUOY)
	game.submarine.scanner.advance(1.0)
	var before: float = game.submarine.scanner.snapshot().progress
	game.submarine.set_simulation_enabled(false)
	game.submarine.scanner.advance(30.0)
	assert_eq(game.submarine.scanner.snapshot().progress,before)
	game.submarine.set_simulation_enabled(true)
	game.submarine.scanner.advance(3.0)
	assert_true(game.revision.ui.notifications.contains_message("sunlit-buoy-recovered"))
	assert_true(game.submarine.is_physics_processing())
	game.revision.ui.notifications.toggle()
	assert_true(game.revision.ui.notifications.transcript.text.contains(SunlitShallowsData.MESSAGE))
	assert_true(game.submarine.is_physics_processing())
func test_recovery_and_restart_keep_recorded_choice_message_and_claim_without_replay() -> void:
	_launch()
	_bloom(false)
	_buoy()
	_return_and_dock()
	assert_eq(game.chapter.debrief(game.station),OK)
	game.revision.ui.dock_page.hide()
	watch_signals(game.story)
	watch_signals(game.research)
	watch_signals(game.missions)
	var corrupt: FileAccess = FileAccess.open(game.expedition_path,FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	assert_eq(game.saves.recover_backup(),OK)
	assert_eq(game.chapter.state(),"claimed")
	assert_eq(game.story.resonance(),15)
	assert_true(game.chapter.log_text().contains(SunlitShallowsData.MESSAGE))
	assert_signal_not_emitted(game.research,"scan_completed")
	assert_signal_not_emitted(game.story,"choice_applied")
	assert_signal_not_emitted(game.missions,"acknowledgement_claimed")
	game.restart_route()
	assert_eq(game.chapter.state(),"claimed")
	assert_eq(game.story.resonance(),15)
	assert_true(game.research.is_completed(SunlitShallowsData.BUOY))
func test_legacy_checkpoint_import_preserves_claims_and_requires_intentional_launch() -> void:
	game.free()
	var old: String = FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json")
	var file: FileAccess = FileAccess.open(path+".expedition.json",FileAccess.WRITE)
	file.store_string(old)
	file.close()
	game = _create()
	assert_true(game.saves.can_write())
	assert_eq(game.chapter.state(),"available")
	assert_eq(game.missions.snapshot()["shelf-calibration-study"].state,"claimed")
	assert_eq(game.missions.snapshot()["shelf-expedition"].state,"available")
	assert_true(game.chapter.can_offer_prototype())
	assert_eq(FileAccess.get_file_as_string(path+".expedition.json"),old)
	_launch()
	assert_eq(game.missions.snapshot()["shelf-calibration-study"].state,"claimed")
	assert_eq(game.missions.snapshot()["shelf-expedition"].state,"available")
	assert_eq(game.story.resonance(),0)
	assert_false(game.chapter.concluded())
func test_zone_boundary_blocks_swept_motion_and_upgrades_do_not_open_zone2() -> void:
	_launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(2)
	var collision: KinematicCollision2D = KinematicCollision2D.new()
	game.submarine.global_position = Vector2(3050,650)
	assert_true(game.submarine.test_move(game.submarine.global_transform,Vector2(0,500),collision))
	assert_lte(collision.get_travel().y,150.0)
	game.submarine.global_position = Vector2(3750,650)
	assert_true(game.submarine.test_move(game.submarine.global_transform,Vector2(1000,0),collision))
	assert_lte(collision.get_travel().x,150.0)
	assert_eq(game.region.camera_bounds.end.y,800)
func test_large_small_window_briefing_keeps_reading_controls_and_all_actions_reachable() -> void:
	viewport.size = Vector2i(800,600)
	var comfort: Dictionary = game.settings.snapshot().accessibility
	comfort.ui_scale = "large"
	comfort.reduced_motion = true
	game.settings.set_accessibility(comfort)
	game.chapter.start()
	await wait_process_frames(8)
	var ui: ExpeditionInterface = game.revision.ui
	var tools: Control = ui._tools[ui.radio_page] as Control
	assert_true(tools.is_visible_in_tree())
	assert_lte(tools.get_global_rect().end.y,600.0)
	var launch: Button = ui.find_child("LaunchSunlit",true,false) as Button
	var ask: Button = ui.find_child("AskOkafor",true,false) as Button
	assert_false(launch.disabled)
	assert_false(ask.disabled)
	assert_true(launch.is_visible_in_tree())
	assert_true(ask.is_visible_in_tree())
func test_prior_bloom_decision_counts_on_accept_and_cannot_be_reversed_for_rewards() -> void:
	game.revision.start()
	_bloom(true)
	game.open_route_menu()
	game.revision.ui.show_title()
	_launch()
	assert_has(game.missions.snapshot()[String(SunlitShallowsData.MISSION)].objectives,"study-light-bloom")
	assert_eq(game.story.apply_choice(LightBloomEncounter.OBSERVE),ERR_ALREADY_EXISTS)
	assert_eq(game.story.resonance(),-15)
