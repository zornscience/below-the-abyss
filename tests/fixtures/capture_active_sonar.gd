extends SceneTree
## Real Godot renders using the named keyboard input; only low energy is injected.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-021-" + name + ".png") == OK)


func _target(name: String) -> SonarRevealTarget:
	return _scene.region.get_node("SonarTargets/" + name) as SonarRevealTarget


func _initialize() -> void:
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta021-capture-defaults.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.resume_route()
	await _frames(2)
	await _capture("ready")
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await _frames(15)
	assert(_scene.submarine.sonar.active_pulse_count() == 1)
	assert(not _target("shelf-marker").is_revealed())
	await _capture("travelling")
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(25)
	assert(_target("shelf-marker").is_revealed())
	assert(not _target("cave-marker").is_revealed())
	await _capture("first-echo")
	await _frames(34)
	assert(_target("cave-marker").is_revealed())
	assert(not _target("overlook-marker").is_revealed())
	assert(_scene.submarine.sonar.echo_count() == 2)
	await _capture("echoes")
	_scene.open_route_menu()
	var cooldown: float = _scene.submarine.sonar.cooldown_remaining()
	await _frames(30)
	assert(_scene.submarine.sonar.cooldown_remaining() == cooldown)
	_scene.resume_route()
	await _frames(180)
	_scene.submarine.resource_system.consume_battery(1000.0)
	assert(_scene.submarine.sonar.status_text() == "LOW BATTERY")
	await _capture("low-battery")
	var retained_history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	_scene.restart_route()
	await _frames(3)
	assert(not _target("shelf-marker").is_revealed())
	assert(_scene.submarine.sonar.status_text() == "READY")
	assert((_scene.get_node("AcousticBus") as AcousticBus).history_count() == retained_history)
	await _capture("restart")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	print("BTA021_GRAPHICAL_TRAVEL_ARRIVAL_ENERGY_PAUSE_RESTART_OK")
	quit()
