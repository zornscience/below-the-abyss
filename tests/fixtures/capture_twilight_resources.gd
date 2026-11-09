extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for index: int in range(count): await process_frame
func run() -> void:
	var game: ShelfPrototype = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta058-capture-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child(game)
	await frames(8)
	game.journey.prepare({"phase":"twilight","commissioned":true})
	game.submarine.damage_system.set_maximum_depth_m(1000)
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	game.revision.ui.title_page.hide()
	game.route_layer.hide()
	game.resume_route()
	var camera: Camera2D = game.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await frames(8)
	game.submarine.resource_system.consume_battery(99)
	game.submarine.set_simulation_enabled(false)
	for size: Vector2i in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size = size
		await frames(12)
		RenderingServer.force_draw(false,0)
		await frames(2)
		var result: Error = root.get_texture().get_image().save_png(OS.get_environment("BTA_EVIDENCE_DIR")+"/low-battery-%dx%d.png" % [size.x,size.y])
		if result!=OK:
			quit(1)
			return
	print("BTA058_CAPTURE_PASS")
	quit()
