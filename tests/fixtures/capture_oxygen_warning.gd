extends SceneTree
## Native evidence for the life-support border: default, Reduced flashing and High contrast at
## 1280x800 and 800x600, plus the Halcyon recovery card. Real scene, real countdown driver.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tests/fixtures/capture_oxygen_warning.gd
## Output: $BTA_EVIDENCE_DIR/<label>-<w>x<h>.png
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
func run() -> void:
	for size: Vector2i in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size = size
		for mode: String in ["default","reduced-flashing","high-contrast"]:
			game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
			game.settings_path = "user://capture-oxygen-%d.json" % Time.get_ticks_usec()
			game.expedition_path = game.settings_path+".expedition.json"
			root.add_child(game)
			await frames(5)
			game.chapter.start()
			game.chapter.launch()
			var preferences: Dictionary = SettingsStore.default_accessibility()
			preferences.reduced_flashing = mode=="reduced-flashing"
			preferences.high_contrast = mode=="high-contrast"
			if game.settings.set_accessibility(preferences)!=OK:
				push_error("Capture preferences rejected")
				quit(1)
				return
			game.submarine.set_simulation_enabled(false)
			game.submarine.global_position = SunlitSurveyData.MAIN_ROUTE[0]
			game.submarine.velocity = Vector2.ZERO
			game.submarine.resource_system.restore_snapshot(game.submarine.resource_system.battery,0.0)
			game.revision.ui.title_page.hide()
			game.revision.ui.radio_page.hide()
			game.route_layer.hide()
			for id: String in game.revision.ui.notifications.pending.duplicate(): game.revision.ui.notifications.remove_message(id)
			game.resume_route()
			for tick: int in range(4): await physics_frame
			var flow: VesselRecoveryFlow = game.journey.recovery
			if not flow.countdown.running or not flow.warning.visible:
				push_error("Countdown did not start")
				quit(1)
				return
			# Bring the readout to 0:42 through the real countdown API, then hold the pose.
			flow.countdown.advance(flow.countdown.remaining-41.2,0.0)
			game.submarine.set_simulation_enabled(false)
			flow.warning.present(flow.countdown.remaining,flow.countdown.grace_seconds)
			await frames(3)
			await capture("oxygen-border-"+mode)
			if mode=="default":
				game.resume_route()
				flow.countdown.advance(flow.countdown.remaining,0.0)
				await frames(30)
				await capture("recovery-card")
			game.queue_free()
			await frames(3)
	print("OXYGEN_CAPTURE_PASS")
	quit()
