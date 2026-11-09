extends SceneTree
var game: ShelfPrototype
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for index: int in range(count): await process_frame
func capture(label: String) -> void:
	await frames(3)
	RenderingServer.force_draw(false,0)
	await frames(2)
	var folder: String = OS.get_environment("BTA_EVIDENCE_DIR")
	if not folder.is_empty():
		var result: Error = root.get_texture().get_image().save_png(folder+"/"+label+".png")
		if result!=OK: quit(1)
func measure(label: String) -> void:
	var start: int = Time.get_ticks_usec()
	for index: int in range(120):
		RenderingServer.force_draw(false,0)
		await process_frame
	print("BTA057_FRAME_MS ",label," ",(Time.get_ticks_usec()-start)/120000.0," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," texture_bytes=",Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
func run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta057-capture.json"
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child(game)
	root.size = Vector2i(800,600) if OS.get_cmdline_user_args().has("--small") else Vector2i(1280,800)
	await frames(8)
	game.journey.prepare({"phase":"twilight","commissioned":true})
	game.submarine.damage_system.set_maximum_depth_m(1000)
	var onboarding: Dictionary = game.settings.snapshot().onboarding
	onboarding.enabled = false
	game.settings.set_onboarding(onboarding)
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	game.revision.ui.title_page.hide()
	game.route_layer.hide()
	game.resume_route()
	var camera: Camera2D = game.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await frames(10)
	var view: TwilightVisibility = game.journey.visibility
	view.set_process(false)
	view.veil.hide()
	view.edges.hide()
	await capture("lit")
	await measure("lit")
	view.set_process(true)
	await frames(4)
	await capture("dark")
	await measure("dark")
	var event: InputEvent
	if OS.get_cmdline_user_args().has("--controller"):
		var joy: InputEventJoypadButton = InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_X
		joy.pressed = true
		event = joy
	else:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_F
		key.physical_keycode = KEY_F
		key.pressed = true
		event = key
	Input.parse_input_event(event)
	await frames(20)
	if view.speeds[0]<=0:
		push_error("Visibility did not receive input-driven ping")
		quit(1)
		return
	await capture("mid-pulse")
	var preferences: Dictionary = game.settings.snapshot().accessibility
	preferences.darkness = "reduced"
	preferences.high_contrast = true
	preferences.reduced_motion = true
	preferences.reduced_flashing = true
	if game.settings.set_accessibility(preferences)!=OK: quit(1)
	await capture("reduced")
	print("BTA057_NATIVE_PASS")
	quit()
