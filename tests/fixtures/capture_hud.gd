extends SceneTree
## Reproducible presentation fixture: deliberate API-driven values, not recorded play.
## Run with a graphical display: godot --path . --script res://tests/fixtures/capture_hud.gd

func frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame

func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

func place(body: SubmarineController, position: Vector2) -> void:
	body.position = position
	body.velocity = Vector2.ZERO
	body.reset_physics_interpolation()
	var camera: Camera2D = body.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()

func _initialize() -> void:
	var scene: MovementPrototype = load("res://scenes/main/main.tscn").instantiate() as MovementPrototype
	scene.settings_path = "user://bta013-visual-defaults.json"
	root.add_child.call_deferred(scene)
	await frames(5)
	assert(not scene.development_mode)
	assert(not scene.resource_panel.is_visible_in_tree())
	await capture("res://docs/testing/bta-013-safe.png")
	scene.submarine.resource_system.consume_battery(22.0)
	scene.submarine.resource_system.consume_oxygen(12.0)
	place(scene.submarine, Vector2(325.0, 1080.0))
	await frames(5)
	await capture("res://docs/testing/bta-013-caution.png")
	place(scene.submarine, Vector2(325.0, 1800.0))
	await frames(150)
	await capture("res://docs/testing/bta-013-danger.png")
	scene.submarine.resource_system.consume_battery(1000.0)
	scene.submarine.resource_system.consume_oxygen(1000.0)
	place(scene.submarine, Vector2(400.0, 520.0))
	await frames(2)
	root.size = Vector2i(800, 600)
	await frames(5)
	await capture("res://docs/testing/bta-013-compact-depleted.png")
	root.size = Vector2i(1280, 800)
	scene.submarine.resource_system.restore_battery(80.0)
	scene.submarine.resource_system.restore_oxygen(90.0)
	await frames(160)
	Input.action_press("move_left")
	await frames(100)
	Input.action_release("move_left")
	assert(scene.submarine.hull_system.last_damage_source == &"collision")
	await capture("res://docs/testing/bta-013-impact.png")
	place(scene.submarine, Vector2(400.0, 520.0))
	scene.development_mode = true
	(scene.get_node("DevelopmentUI") as CanvasLayer).show()
	scene.resource_panel.focus_test_controls()
	await capture("res://docs/testing/bta-013-development.png")
	print("BTA013_GRAPHICAL_SAFE_CAUTION_DANGER_DEPLETION_DEBUG_OK")
	quit()
