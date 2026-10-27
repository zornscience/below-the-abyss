extends SceneTree
## Native presentation evidence; deliberately staged positions, NOT a route-duration measurement.
var scene: ShelfPrototype
func frames(count: int = 4) -> void:
	for index: int in range(count): await physics_frame
func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("BTA_EVIDENCE_DIR")
	assert(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK)
	print("FEEDBACK_CAPTURE ",label," size=",root.size)
func move_to(at: Vector2) -> void:
	scene.submarine.global_position = at
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.reset_physics_interpolation()
	await frames(3)
	var camera: Camera2D = scene.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await frames(10)
	print("STAGED_POSITION ",at," actual=",scene.submarine.global_position," camera=",camera.get_screen_center_position())
func _initialize() -> void:
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	scene.revised_expedition = false
	scene.settings_path = "user://feedback-capture-%d.json" % Time.get_ticks_usec()
	scene.expedition_path = scene.settings_path+".expedition.json"
	root.add_child.call_deferred(scene)
	await frames(6)
	root.size = Vector2i(1280,800)
	scene._route_resume_requested()
	await capture("first-helm")
	assert(scene.open_station()==OK)
	await capture("station-overview")
	scene.station_menu.show_upgrades()
	assert(scene.upgrades.install(&"pressure-hull-400")==OK)
	assert(scene.upgrades.install(&"sonar-range-1200")==OK)
	scene.close_station()
	scene.tutorial.toggle()
	await move_to(Vector2(6500,700))
	assert(scene.submarine.sonar.request_ping()==OK)
	await frames(45)
	assert(scene.submarine.scanner.request_scan()==OK)
	await capture("hydrophone-scan")
	await frames(420)
	await move_to(Vector2(21600,1290))
	scene.submarine.scanner._feedback_seconds = 0.0
	await capture("expedition-wreck")
	await move_to(Vector2(19150,1100))
	scene.torpedoes.aim = Vector2.RIGHT
	assert(scene.torpedoes.request_fire()==OK)
	await frames(18)
	await capture("terrain-explosion")
	scene.open_map()
	await capture("unrouted-map")
	scene.close_map()
	await move_to(Vector2(1430,420))
	scene.creature.set_suspended(true)
	scene.creature.global_position = Vector2(1510,420)
	scene.torpedoes.reset_session()
	scene.torpedoes.aim = Vector2.RIGHT
	assert(scene.torpedoes.request_fire()==OK)
	await frames(8)
	assert(not scene.creature.visible)
	await capture("wildlife-blast")
	root.size = Vector2i(800,600)
	var preferences: Dictionary = scene.settings.snapshot().accessibility
	preferences.ui_scale = "large"
	scene.settings.set_accessibility(preferences)
	await move_to(scene.region.spawn.global_position)
	assert(scene.open_station()==OK)
	await capture("station-compact-large")
	scene.close_station()
	await capture("hud-compact-large")
	print("FEEDBACK_NATIVE_PASS")
	quit()
