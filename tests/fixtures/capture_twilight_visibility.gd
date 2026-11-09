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
	game.settings.set_accessibility(SettingsStore.default_accessibility())
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
	var middle: float = view.pings[0].w/(2.0*view.speeds[0])
	for tick: int in range(180):
		if view.pings[0].z>=middle: break
		await frames(1)
	if view.pings[0].z<middle:
		push_error("Pulse did not reach its middle travel phase")
		quit(1)
		return
	await capture("mid-pulse")
	game.open_accessibility()
	var panel: AccessibilityPanel = game.accessibility_panel
	await focus_control(panel.darkness_picker)
	await tap(KEY_ENTER,JOY_BUTTON_A)
	await tap(KEY_DOWN,JOY_BUTTON_DPAD_DOWN)
	await tap(KEY_ENTER,JOY_BUTTON_A)
	if game.settings.snapshot().accessibility.get("darkness", "standard")!="reduced":
		push_error("Input could not select Reduced darkness")
		quit(1)
		return
	await focus_control(panel.save_button)
	await tap(KEY_ENTER,JOY_BUTTON_A)
	var restored: SettingsStore = SettingsStore.new()
	if restored.load_settings(game.settings_path)!=OK or restored.snapshot().accessibility.get("darkness")!="reduced":
		push_error("Input-selected darkness did not persist")
		quit(1)
		return
	await tap(KEY_ESCAPE,JOY_BUTTON_B)
	game.resume_route()
	var preferences: Dictionary = game.settings.snapshot().accessibility
	preferences.darkness = "reduced"
	preferences.high_contrast = true
	preferences.reduced_motion = true
	preferences.reduced_flashing = true
	if game.settings.set_accessibility(preferences)!=OK: quit(1)
	await capture("reduced")
	game.submarine.set_simulation_enabled(false)
	game.queue_free()
	await frames(8)
	game = null
	print("BTA057_NATIVE_PASS")
	quit()

func tap(key: Key, button: JoyButton) -> void:
	var event: InputEvent
	if OS.get_cmdline_user_args().has("--controller"):
		var joy: InputEventJoypadButton = InputEventJoypadButton.new()
		joy.button_index = button
		joy.pressed = true
		event = joy
	else:
		var keyboard: InputEventKey = InputEventKey.new()
		keyboard.keycode = key
		keyboard.physical_keycode = key
		keyboard.pressed = true
		event = keyboard
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(3)
	if event is InputEventKey: (event as InputEventKey).pressed = false
	else: (event as InputEventJoypadButton).pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
func focus_control(target: Control) -> void:
	for index: int in range(30):
		if root.gui_get_focus_owner()==target: return
		await tap(KEY_TAB,JOY_BUTTON_RIGHT_SHOULDER)
	push_error("Could not navigate to "+target.name)
	quit(1)
