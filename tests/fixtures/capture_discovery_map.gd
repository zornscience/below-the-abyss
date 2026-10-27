extends SceneTree
## Real renders. Observer relocations are fixture setup; discovery uses actual pings.

const PATH: String = "user://bta023-capture-discoveries.json"
var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-023-" + name + ".png") == OK)


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await _frames(2)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _spawn() -> void:
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta023-capture-controls.json"
	_scene.discovery_path = PATH
	root.add_child.call_deferred(_scene)
	await _frames(5)


func _initialize() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	await _spawn()
	await _key(KEY_M)
	assert(_scene.exploration_map.visible)
	assert(_scene.exploration_map.canvas.points.is_empty())
	await _capture("hidden")
	await _key(KEY_M)
	_scene.resume_route()
	await _key(KEY_F)
	assert(_scene.discoveries.discovered_ids().is_empty())
	await _frames(40)
	assert(_scene.discoveries.discovered_ids().size() == 1)
	await _key(KEY_M)
	await _capture("first-discovery")
	for position: Vector2 in [Vector2(1400, 480), Vector2(3100, 650)]:
		_scene.restart_route()
		_scene.submarine.global_position = position
		_scene.submarine.velocity = Vector2.ZERO
		_scene.submarine.reset_physics_interpolation()
		(_scene.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
		await _key(KEY_F)
		await _frames(65)
	assert(_scene.discoveries.discovered_ids().size() == 3)
	await _key(KEY_M)
	(_scene.exploration_map.get_node("%LandmarkList").get_child(2) as Button).grab_focus()
	await _capture("landmarks")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	root.size = Vector2i(1280, 800)
	_scene.free()
	await _spawn()
	assert(_scene.discoveries.discovered_ids().size() == 3)
	assert(not (_scene.region.get_node("SonarTargets/spire-marker") as SonarRevealTarget).is_revealed())
	await _key(KEY_M)
	await _capture("reloaded")
	print("BTA023_GRAPHICAL_HIDDEN_ARRIVAL_MAP_COMPACT_RELOAD_OK")
	quit()
