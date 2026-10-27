extends SceneTree
## Actual rendering and sonar input. Only observer relocation is capture setup.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-030-" + name + ".png") == OK)


func _initialize() -> void:
	for path: String in ["user://bta030-capture-settings.json.discoveries.json", "user://bta030-capture-settings.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta030-capture-settings.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.submarine.global_position = Vector2(1400, 400)
	_scene.submarine.reset_physics_interpolation()
	(_scene.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	_scene.resume_route()
	await _frames(5)
	assert(_scene.creature.brain.state == CreatureState.State.PATROL)
	await _capture("patrol")
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await _frames(12)
	assert(_scene.creature.brain.state == CreatureState.State.INVESTIGATE)
	await _capture("investigate")
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for _step: int in range(600):
		if _scene.creature.brain.state == CreatureState.State.RETURN:
			break
		await _frames(1)
	assert(_scene.creature.brain.state == CreatureState.State.RETURN)
	await _capture("return")
	for _step: int in range(600):
		if _scene.creature.brain.state == CreatureState.State.PATROL:
			break
		await _frames(1)
	assert(_scene.creature.brain.state == CreatureState.State.PATROL)
	assert(_scene.submarine.hull_system.hull == 100.0)
	await _capture("recovered")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	print("BTA030_GRAPHICAL_PATROL_PING_INVESTIGATE_RETURN_RECOVERY_OK")
	quit()
