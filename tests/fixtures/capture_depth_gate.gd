extends SceneTree
var game: ShelfPrototype
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for tick: int in range(n): await process_frame
func capture(label: String) -> void:
	await frames(4)
	RenderingServer.force_draw(false,0)
	await frames(2)
	var result: Error = root.get_texture().get_image().save_png(OS.get_environment("BTA_EVIDENCE_DIR")+"/%s-%dx%d.png" % [label,root.size.x,root.size.y])
	if result!=OK: quit(1)
func pose(at: Vector2) -> void:
	game.submarine.global_position = at
	game.submarine.velocity = Vector2.ZERO
	game.submarine.damage_system.advance(0,game.region.depth_at_world(at),game.submarine.hull_system)
	var camera: Camera2D = game.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await frames(4)
func run() -> void:
	for size: Vector2i in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size = size
		game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
		game.settings_path = "user://capture059-%d.json" % Time.get_ticks_usec()
		game.expedition_path = game.settings_path+".expedition.json"
		root.add_child(game)
		await frames(5)
		game.chapter.start()
		game.chapter.launch()
		game.submarine.set_simulation_enabled(false)
		game.story.apply_choice(LightBloomEncounter.COLLECT)
		game.bloom.reset_session()
		game.discoveries.discover(SunlitShallowsData.POI,&"capture/buoy")
		game.submarine.global_position = SunlitSurveyData.BUOY
		var records: Array[StringName] = game.research.completed_ids()
		records.append(SunlitShallowsData.BUOY)
		game.saves.commit_research_checkpoint(records)
		game.research.restore_completed(records)
		game.missions.reconcile()
		var finished: Error = game.saves.finish_sunlit_return()
		var deployed: Error = game.saves.transfer_chapter("twilight",true)
		if finished!=OK or deployed!=OK:
			push_error("Capture commissioning failed")
			quit(1)
			return
		game.revision.ui.title_page.hide()
		game.route_layer.hide()
		game.revision.ui.radio_page.hide()
		var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
		await pose(gate.approach)
		game.tutorial.show_hint("twilight-depth")
		await capture("warning")
		await pose(gate.lower_left)
		game.submarine.damage_system.advance(8,gate.depth_m,game.submarine.hull_system)
		await capture("hull-stress")
		await pose((gate.lower_left+gate.lower_right)*0.5)
		await capture("deep-section")
		game.submarine.hull_system.apply_damage(100,&"pressure")
		await frames(5)
		await capture("failure")
		print("BTA059_FRAME process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		game.queue_free()
		await frames(3)
	print("BTA059_CAPTURE_PASS")
	quit()
