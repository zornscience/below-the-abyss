extends SceneTree
## Native presentation capture and input navigation, not a substitute for chapter flight.
var game: ShelfPrototype
var output: String
func frames(count: int = 8) -> void:
	for index: int in range(count): await process_frame
func shot(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
	print("HALCYON_SCREENSHOT ",name," viewport=",root.size)
func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
func joy(code: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
func activate(id: String) -> void:
	var target: Control = game.revision.ui.find_child(id,true,false) as Control
	if target==null:
		push_error("Missing title control "+id)
		quit(1)
		return
	for index: int in range(60):
		if root.gui_get_focus_owner()==target:
			await joy(JOY_BUTTON_A)
			return
		await joy(JOY_BUTTON_RIGHT_SHOULDER)
	push_error("Focus could not reach "+id)
	quit(1)
func benchmark(label: String) -> void:
	await frames(30)
	var intervals: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for index: int in range(150):
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append((now-previous)/1000.0)
		previous = now
	intervals.sort()
	print("HALCYON_PERF ",label," size=",root.size," p50_ms=",intervals[75]," p95_ms=",intervals[142]," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," texture_MiB=",Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0)
func _initialize() -> void:
	output = OS.get_environment("BTA_EVIDENCE_DIR")
	if not OS.get_cmdline_user_args().has("--quit-test"): assert(not output.is_empty())
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta049-capture-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child.call_deferred(game)
	await frames(12)
	if OS.get_cmdline_user_args().has("--quit-test"):
		print("HALCYON_QUIT_INPUT_ACTIVATING")
		var target: Control = game.revision.ui.find_child("TitleQuit",true,false) as Control
		for index: int in range(60):
			if root.gui_get_focus_owner()==target: break
			await joy(JOY_BUTTON_RIGHT_SHOULDER)
		assert(root.gui_get_focus_owner()==target)
		# Return from all awaited navigation before Quit tears down the SceneTree.
		_quit_input.call_deferred()
		return
	var audio: Dictionary = game.settings.snapshot().audio
	audio.muted = true
	game.settings.set_audio(audio)
	game.settings.set_onboarding({"enabled":false,"seen":[]})
	for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size = dimensions
		await shot("title-"+str(dimensions.x))
		await benchmark("title-standard")
	root.size = Vector2i(800,600)
	var preferences: Dictionary = SettingsStore.default_accessibility()
	preferences.ui_scale = "large"
	preferences.high_contrast = true
	preferences.reduced_motion = true
	preferences.reduced_particles = true
	preferences.reduced_flashing = true
	game.settings.set_accessibility(preferences)
	await shot("title-800-accessible")
	await benchmark("title-static-comfort")
	await key(KEY_DOWN)
	assert(root.gui_get_focus_owner().name==&"TitleOptions")
	await key(KEY_ENTER)
	await shot("options-800-accessible")
	await activate("TitleAccessibility")
	assert(game.accessibility_panel.visible)
	await shot("accessibility-800")
	await joy(JOY_BUTTON_B)
	assert(game.revision.ui.title_page.visible)
	await activate("Begin")
	await activate("LaunchSunlit")
	assert(game.submarine.is_physics_processing())
	assert(game.chapter.active)
	assert(game.chapter.departure.visible)
	await shot("halcyon-gameplay-800-accessible")
	root.size = Vector2i(1280,800)
	game.settings.set_accessibility(SettingsStore.default_accessibility())
	await shot("halcyon-gameplay-1280")
	await benchmark("departure-gameplay")
	print("HALCYON_CAPTURE_PASS keyboard=options controller=begin/briefing muted=true")
	game.queue_free()
	await frames(4)
	quit()

func _quit_input() -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
