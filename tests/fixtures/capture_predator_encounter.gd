extends SceneTree
## Real graphical keyboard/controller playthrough; entry pose is fixture setup.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-031-" + name + ".png") == OK)


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _stick(value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _entry() -> void:
	_scene.submarine.global_position = Vector2(3060, 390)
	_scene.submarine.velocity = Vector2.ZERO
	_scene.submarine.reset_physics_interpolation()
	(_scene.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	_scene.resume_route()
	await _frames(5)


func _initialize() -> void:
	for path: String in ["user://bta031-capture.json.discoveries.json", "user://bta031-capture.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta031-capture.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	await _entry()
	await _capture("quiet")
	await _key(KEY_F, true)
	await _frames(6)
	await _key(KEY_F, false)
	assert(_scene.predator.threat.phase == PredatorState.Phase.ALERT)
	assert(_scene.submarine.hull_system.hull == 100.0)
	print("BTA031_KEYBOARD_WARNING hull=100 cue=RETREAT_DOWN_PAST_115m")
	await _capture("warning")
	for _step: int in range(400):
		if _scene.predator.threat.phase == PredatorState.Phase.PURSUE:
			break
		await _frames(1)
	assert(_scene.predator.threat.phase == PredatorState.Phase.PURSUE)
	await _capture("pursuit")
	await _frames(15)
	assert(_scene.submarine.hull_system.hull >= 95.0)
	await _capture("contact")
	await _key(KEY_S, true)
	await _frames(37)
	await _key(KEY_S, false)
	assert(_scene.submarine.global_position.y > 460.0)
	assert(_scene.predator.threat.phase == PredatorState.Phase.DISENGAGE)
	assert(_scene.predator.position.y <= 429.0)
	var hull: float = _scene.submarine.hull_system.hull
	assert(hull >= 95.0)
	print("BTA031_KEYBOARD_PURSUIT_ESCAPE hull=%s player_depth=%s" % [hull, _scene.region.depth_at_world(_scene.submarine.global_position)])
	await _capture("escaped")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	await _frames(90)
	assert(_scene.submarine.hull_system.hull == hull)
	root.size = Vector2i(1280, 800)
	_scene.restart_route()
	await _entry()
	await _key(KEY_F, true)
	await _frames(6)
	await _key(KEY_F, false)
	assert(_scene.predator.threat.phase == PredatorState.Phase.ALERT)
	await _stick(1.0)
	await _frames(37)
	await _stick(0.0)
	assert(_scene.submarine.global_position.y > 460.0)
	assert(_scene.predator.threat.phase == PredatorState.Phase.DISENGAGE)
	assert(_scene.submarine.hull_system.hull == 100.0)
	print("BTA031_CONTROLLER_WARNING_ESCAPE hull=100 pursuit_avoided=true")
	await _capture("controller-escape")
	print("BTA031_GRAPHICAL_WARNING_PURSUIT_DAMAGE_ESCAPE_CONTROLLER_OK")
	quit()
