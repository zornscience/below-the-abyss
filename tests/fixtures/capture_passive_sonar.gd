extends SceneTree
## Actual rendered HUD. The observer pose and one-shot source budgets are fixture setup.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-022-" + name + ".png") == OK)


func _initialize() -> void:
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta022-capture-defaults.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.resume_route()
	await _frames(2)
	await _capture("listening")
	for child: Node in _scene.ambient.get_children():
		var source: AmbientSoundEmitter = child as AmbientSoundEmitter
		var profile: AmbientEmissionProfile = source.configuration.duplicate(true) as AmbientEmissionProfile
		profile.maximum_events = 1
		assert(source.configure(profile) == OK)
	_scene.restart_route()
	_scene.submarine.global_position = Vector2(1250, 480)
	_scene.submarine.velocity = Vector2.ZERO
	_scene.submarine.reset_physics_interpolation()
	await _frames(250)
	assert(_scene.submarine.passive.contacts_snapshot().size() == 3)
	assert(_scene.submarine.sonar.active_pulse_count() == 0)
	await _capture("contacts")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	root.size = Vector2i(1280, 800)
	await _frames(600)
	assert(_scene.submarine.passive.contacts_snapshot().is_empty())
	await _capture("expired")
	print("BTA022_GRAPHICAL_CONTACTS_COMPACT_EXPIRY_OK")
	quit()
