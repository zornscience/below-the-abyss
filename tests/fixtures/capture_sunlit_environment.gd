extends SceneTree
## Identical authored poses; staged screenshots are separate from normal-input flight.
const POSES: Dictionary = {"departure":Vector2(420,480),"early-exploration":Vector2(900,480),
	"kelp-seabed":Vector2(1780,530),"plankton":Vector2(1280,480),
	"twin-spires":Vector2(3300,550),"emergency-buoy":Vector2(3500,620),"return-halcyon":Vector2(700,480)}
const PROFILE_POSES: Array[String] = ["departure","plankton","twin-spires"]
var game: ShelfPrototype
var output: String
var results: Dictionary = {}
var expected: Vector2i

func frames(count: int = 8) -> void:
	for unused: int in range(count): await process_frame

func terrain_signature() -> String:
	var shapes: Array[String] = []
	for node: Node in game.region.find_children("*","CollisionPolygon2D",true,false):
		if node.get_parent() is StaticBody2D:
			shapes.append(str(node.global_transform,node.polygon,(node.get_parent() as StaticBody2D).collision_layer))
	for node: Node in game.region.find_children("*","CollisionShape2D",true,false):
		if node.get_parent() is StaticBody2D:
			var geometry: Variant = node.shape.size if node.shape is RectangleShape2D else str(node.shape.get_class())
			shapes.append(str(node.global_transform,geometry,(node.get_parent() as StaticBody2D).collision_layer))
	shapes.sort()
	return JSON.stringify(shapes).sha256_text()

func sample() -> Dictionary:
	await frames(20)
	var times: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for unused: int in range(60):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous = now
	times.sort()
	return {"median_ms":times[floori(float(times.size())/2.0)],"p95_ms":times[floori(times.size()*0.95)],
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,
		"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0}

func mode(dimensions: Vector2i,comfort: bool) -> void:
	expected = dimensions
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta050-capture-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child(game)
	await frames(12)
	root.size = dimensions
	await frames(12)
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.reduced_motion = comfort
	prefs.reduced_flashing = comfort
	prefs.reduced_particles = comfort
	game.settings.set_accessibility(prefs)
	var audio: Dictionary = game.settings.snapshot().audio
	audio.muted = true
	game.settings.set_audio(audio)
	game.settings.set_onboarding({"enabled":false,"seen":[]})
	game.chapter.start()
	game.chapter.launch()
	for label: String in POSES:
		game.submarine.set_simulation_enabled(false)
		game.submarine.global_position = POSES[label]
		game.submarine.velocity = Vector2.ZERO
		var camera: Camera2D = game.submarine.get_node("Camera2D") as Camera2D
		game.submarine.reset_physics_interpolation()
		camera.reset_smoothing()
		camera.force_update_scroll()
		game.submarine.damage_system.advance(0,game.region.depth_at_world(POSES[label]),game.submarine.hull_system)
		if label in ["plankton","emergency-buoy"]:
			game.submarine.set_simulation_enabled(true)
			game.submarine.sonar.advance(10.0)
			assert(game.submarine.sonar.request_ping()==OK)
			game.submarine.sonar.advance(4.0)
			game.submarine.set_simulation_enabled(false)
		await frames(12)
		camera.reset_smoothing()
		camera.force_update_scroll()
		await frames(2)
		var name: String = "%d-%s-%s" % [dimensions.x,"reduced" if comfort else "normal",label]
		var data: Dictionary = {"viewport":[dimensions.x,dimensions.y],"player":str(game.submarine.global_position),
			"camera_center":str(camera.get_screen_center_position()),"camera_zoom":str(camera.zoom),
			"terrain_sha256":terrain_signature()}
		await RenderingServer.frame_post_draw
		assert(root.size==expected)
		var screenshot: Image = root.get_texture().get_image()
		assert(screenshot.get_size()==expected)
		assert(screenshot.save_png(output.path_join(name+".png"))==OK)
		if label in PROFILE_POSES and not OS.get_cmdline_user_args().has("--preview") and not OS.get_cmdline_user_args().has("--stills-only"):
			game.submarine.set_simulation_enabled(true)
			data.performance = await sample()
			game.submarine.set_simulation_enabled(false)
		results[name] = data
		print("SUNLIT_ART_CAPTURE ",name)
	game.queue_free()
	await frames(5)

func _initialize() -> void:
	output = OS.get_environment("BTA_EVIDENCE_DIR")
	assert(not output.is_empty())
	if OS.get_cmdline_user_args().has("--wide"):
		var previous: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.READ)
		assert(previous!=null)
		var parsed: Variant = JSON.parse_string(previous.get_as_text())
		assert(parsed is Dictionary)
		results = parsed
		previous.close()
	if OS.get_cmdline_user_args().has("--preview"):
		await mode(Vector2i(1280,800),false)
	else:
		for dimensions: Vector2i in ([Vector2i(1920,1080)] if OS.get_cmdline_user_args().has("--wide") else [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]):
			for comfort: bool in [false,true]: await mode(dimensions,comfort)
	var report: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	assert(report!=null)
	report.store_string(JSON.stringify(results,"  ")+"\n")
	report.close()
	print("SUNLIT_ART_CAPTURE_PASS")
	quit()
