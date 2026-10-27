extends SceneTree
## Actual Godot graybox renders. Safe loop is flown using test-only input steering.
## Only the isolated hazard and authoring overview use explicit presentation setup.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-014-" + name + ".png") == OK)


func _fly_to(target: Vector2) -> void:
	for _index: int in range(1500):
		ShelfRouteDriver.steer(_scene.submarine.global_position, target)
		await physics_frame
		if _scene.submarine.global_position.distance_to(target) < 12.0 and _scene.submarine.velocity.length() < 30.0:
			ShelfRouteDriver.release()
			return
	ShelfRouteDriver.release()
	push_error("Screenshot fixture failed to fly to %s" % target)
	quit(1)


func _point(name: String) -> Vector2:
	return (_scene.region.get_node("RouteMarkers/" + name) as Marker2D).global_position


func _initialize() -> void:
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta014-capture-defaults.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	await _capture("briefing")
	_scene.resume_route()
	await _frames(3)
	await _capture("base")
	for name: String in ShelfRouteDriver.OUTBOUND:
		await _fly_to(_point(name))
		if name == "Cave":
			await _capture("cave")
	await _capture("spires")
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	await _frames(3)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	assert(_scene.submarine.hull_system.hull == 100.0)
	assert(_scene.submarine.resource_system.battery > 15.0)
	await _capture("complete")
	print("BTA014_GRAPHICAL_LOOP_OK seconds=%.2f battery=%.2f oxygen=%.2f" % [
		_scene.route_check.elapsed_seconds, _scene.submarine.resource_system.battery,
		_scene.submarine.resource_system.oxygen])
	_scene.submarine.position = _point("DangerDepth")
	_scene.submarine.velocity = Vector2.ZERO
	_scene.submarine.reset_physics_interpolation()
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _frames(155)
	await _capture("hazard")
	_scene.open_route_menu()
	_scene.route_layer.hide()
	(_scene.get_node("UI") as CanvasLayer).hide()
	camera.limit_left = -10000
	camera.limit_top = -10000
	camera.limit_right = 10000
	camera.limit_bottom = 10000
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(2050, 900)
	camera.zoom = Vector2(0.28, 0.28)
	camera.force_update_scroll()
	await _capture("overview")
	quit()
