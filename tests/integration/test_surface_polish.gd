extends GutTest
## Integrated rules for the surface departure, direct scanning and finite technology.
var game: ShelfPrototype
var view: SubViewport
var path: String
func before_each() -> void:
	view = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta052-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	view.add_child(game)
	await wait_physics_frames(3)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_physics_process(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func test_surface_departure_is_submerged_and_surface_blocks_full_ascent() -> void:
	assert_eq(game.region.spawn.position,SunlitSurveyData.SPAWN)
	assert_eq(game.submarine.position,SunlitSurveyData.SPAWN)
	assert_true(game.saves.position_clear(SunlitSurveyData.SPAWN,0))
	assert_false(game.saves.position_clear(Vector2(1000,-20),0))
	var hit: KinematicCollision2D = KinematicCollision2D.new()
	assert_true(game.submarine.test_move(game.submarine.global_transform,Vector2(0,-400),hit))
	assert_gt(hit.get_travel().y,-80.0)
	assert_almost_eq(game.region.depth_at_world(Vector2(1000,800)),200.0,0.001)
	assert_eq(game.saves._state.player.position,[420.0,80.0])
func test_open_water_route_needs_no_blasting_and_optional_tunnels_remain_solid() -> void:
	for at: Vector2 in SunlitSurveyData.MAIN_ROUTE:
		assert_true(game.saves.position_clear(at,0),"Clear waypoint "+str(at))
	for at: Vector2 in [Vector2(6200,1000),Vector2(11350,1000),Vector2(9800,650)]:
		assert_true(game.saves.position_clear(at,0),"Excavation approach "+str(at))
	for mouth: DestructibleRock in game.chapter.guide.layout.tunnels:
		assert_false(mouth.pieces.is_empty())
		var center: Vector2 = Vector2.ZERO
		for point: Vector2 in mouth.original: center+=point/mouth.original.size()
		assert_gt(game.excavation.excavate(center,150),0)
	assert_eq(game.excavation.snapshot().size(),3)
func test_visible_bloom_can_be_observed_without_emitting_sonar() -> void:
	game.submarine.global_position = Vector2(1280,480)
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_physics_process(true)
	var history: int = (game.get_node("AcousticBus") as AcousticBus).history_count()
	assert_eq(game.bloom.interact(),OK)
	assert_eq(game.bloom.choose_observe(),OK)
	game.submarine.scanner.advance(3.0)
	assert_true(game.research.is_completed(LightBloomEncounter.SCAN))
	assert_eq(game.story.resonance(),15)
	assert_eq((game.get_node("AcousticBus") as AcousticBus).history_count(),history)
	game.bloom.leave()
func test_visible_subject_scans_directly_but_wall_and_hidden_buoy_still_gate() -> void:
	game.submarine.global_position = Vector2(6000,600)
	assert_eq(game.submarine.scanner.candidate_id(),&"sunlit-silver-shoal")
	assert_eq(game.submarine.scanner.request_scan(&"sunlit-silver-shoal"),OK)
	game.submarine.scanner.advance(5.0)
	assert_true(game.research.is_completed(&"sunlit-silver-shoal"))
	game.submarine.global_position = SunlitSurveyData.BUOY
	assert_false(game.submarine.scanner.eligible(SunlitShallowsData.BUOY))
	game.submarine.global_position = Vector2(10600,410)
	assert_false(game.submarine.scanner.eligible(&"sunlit-basalt-arch"),"Visible scanning cannot cross the cave roof.")
func test_engine_and_torpedo_upgrade_reconstruct_baselines_and_keep_inflight_snapshot() -> void:
	game.submarine.global_position = SunlitSurveyData.SPAWN
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_physics_process(true)
	assert_eq(game.open_station(),OK)
	assert_eq(game.revision.assign("engine",1),OK)
	assert_eq(game.submarine.motion.acceleration,180.0)
	assert_eq(game.revision.assign("torpedo_area",1),ERR_UNAVAILABLE)
	assert_eq(game.revision.respec(),OK)
	assert_eq(game.submarine.motion.acceleration,120.0)
	assert_eq(game.revision.assign("torpedo_area",1),OK)
	game.revision.undock()
	assert_eq(game.torpedoes.request_fire(),OK)
	var launched: TorpedoProjectile = game.torpedoes._projectiles[0]
	assert_eq(launched.blast_radius,190.0)
	assert_eq(game.torpedoes.configure_capabilities(750,150),OK)
	assert_eq(launched.blast_radius,190.0)
	assert_eq(launched.acceleration,500.0)
func test_ammunition_is_in_resource_deck_and_no_world_helper_labels_exist() -> void:
	assert_eq(game.revision._ammo_label.get_parent(),game.hud.get_node("%InstrumentDeck"))
	assert_true(game.revision._ammo_label.text.contains("10/10"))
	for label: Node in game.chapter.guide.layout.find_children("*","Label",true,false):
		assert_false((label as Label).visible)
	assert_null(game.revision.ui.radio_page.find_child("TextDown",true,false))

func test_radio_types_follows_and_expires_without_accepting_or_erasing_message() -> void:
	game.submarine.set_physics_process(true)
	var radio: RadioNotifications = game.revision.ui.notifications
	radio.enqueue("relay","A long field transmission. ".repeat(45),"Wick")
	radio._process(1.0)
	assert_gt(radio.preview.text.length(),0)
	assert_lt(radio.preview.text.length(),radio.texts["relay"].length())
	radio._process(25.0)
	await wait_process_frames(4)
	assert_gt(radio.scroll.scroll_vertical,0)
	radio._process(120.0)
	assert_false(radio.panel.visible)
	assert_true(radio.badge.visible)
	assert_true(radio.contains_message("relay"))
	assert_false("relay" in game.revision.campaign.messages)
	radio.toggle()
	assert_true(radio.expanded)
	assert_eq(radio.transcript.text,radio.texts["relay"])
	radio._process(120.0)
	assert_true(radio.panel.visible,"Deliberately opened archive waits for the reader.")

func test_context_prompt_stays_short_at_small_large_text_departure() -> void:
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "large"
	prefs.high_contrast = true
	game.settings.set_accessibility(prefs)
	game.submarine.set_simulation_enabled(true)
	await wait_process_frames(12)
	assert_lt(game.pilot_context.size.y,120.0)
