extends SceneTree
## Real rendering/input. Only observer relocation and isolated file paths are fixture setup.

const RESEARCH_PATH: String = "user://bta024-capture-research.json"
const DISCOVERY_PATH: String = "user://bta024-capture-discoveries.json"
var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-024-" + name + ".png") == OK)


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
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta024-capture-controls.json"
	_scene.research_path = RESEARCH_PATH
	_scene.discovery_path = DISCOVERY_PATH
	root.add_child.call_deferred(_scene)
	await _frames(5)


func _initialize() -> void:
	for path: String in [RESEARCH_PATH, DISCOVERY_PATH]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	await _spawn()
	_scene.open_map()
	_scene.open_research()
	assert(_scene.research_log.get_node("%ResearchEntries").get_child_count() == 0)
	await _capture("empty-log")
	_scene.close_research()
	_scene.close_map()
	_scene.resume_route()
	await _key(KEY_F)
	await _frames(40)
	assert(_scene.discoveries.discovered_ids().size() == 1)
	assert(_scene.research.completed_ids().is_empty())
	_scene.submarine.global_position = Vector2(760, 480)
	_scene.submarine.velocity = Vector2.ZERO
	_scene.submarine.reset_physics_interpolation()
	(_scene.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	await _key(KEY_E)
	await _frames(80)
	assert(_scene.submarine.scanner.snapshot().progress > 0.3)
	await _capture("progress")
	await _frames(110)
	assert(_scene.research.completed_ids().size() == 1)
	await _capture("completed")
	_scene.restart_route()
	_scene.submarine.global_position = Vector2(1750, 480)
	_scene.submarine.velocity = Vector2.ZERO
	_scene.submarine.reset_physics_interpolation()
	(_scene.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	await _key(KEY_F)
	await _frames(20)
	await _key(KEY_E)
	await _frames(250)
	assert(_scene.research.completed_ids().size() == 2)
	_scene.open_map()
	_scene.open_research()
	(_scene.research_log.get_node("%ResearchEntries").get_child(1) as Button).grab_focus()
	await _capture("research-log")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact-log")
	root.size = Vector2i(1280, 800)
	_scene.free()
	await _spawn()
	assert(_scene.research.completed_ids().size() == 2)
	_scene.open_map()
	_scene.open_research()
	await _capture("reloaded")
	print("BTA024_GRAPHICAL_INTENT_PROGRESS_COMPLETION_LOG_RELOAD_OK")
	quit()
