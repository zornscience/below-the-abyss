extends SceneTree
## Staged native compositions for art review, not a claim of input-driven route flight.
var _scene: ShelfPrototype
var _prefix: String = "after"
var _samples: Array[float] = []


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _capture(name: String, at: Vector2) -> void:
	_scene.submarine.set_simulation_enabled(false)
	_scene.submarine.global_position = at
	_scene.submarine.velocity = Vector2.ZERO
	_scene.submarine.damage_system.advance(0, _scene.region.depth_at_world(at), _scene.submarine.hull_system)
	_scene.submarine.reset_physics_interpolation()
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	_scene._refresh_scan_status()
	await _frames(6)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-040-" + _prefix + "-" + name + ".png") == OK)


func _initialize() -> void:
	_prefix = "before" if OS.get_cmdline_user_args().has("--before") else "after"
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta040-art-" + _prefix + ".json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.resume_route()
	await _capture("base", Vector2(420, 480))
	await _capture("cave", Vector2(2350, 480))
	await _capture("spires", Vector2(3500, 650))
	assert(_scene.submarine.sonar.request_ping() == OK)
	_scene.submarine.sonar.advance(0.7)
	await _capture("sonar", Vector2(3500, 650))
	await _capture("deep", Vector2(3080, 1340))
	root.size = Vector2i(800, 600)
	await _capture("compact", Vector2(760, 480))
	_scene.open_route_menu()
	await _frames(4)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-040-" + _prefix + "-menu.png") == OK)
	# Observe rendered frame duration after warmup; not a hardware certification.
	_scene.resume_route()
	var previous: int = Time.get_ticks_usec()
	for _index: int in range(180):
		await process_frame
		var now: int = Time.get_ticks_usec()
		_samples.append((now - previous) / 1000000.0)
		previous = now
	_samples.sort()
	print("BTA040_RENDER_FRAME_SECONDS median=%.6f p95=%.6f renderer=%s" % [_samples[90], _samples[171], RenderingServer.get_video_adapter_name()])
	quit()
