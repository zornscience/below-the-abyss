extends SceneTree
## Actual route flown with existing input steering; station controls use input events.
## A pre-trip 20-hull deficit is the only injected resource state, to show repair.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-032-" + name + ".png") == OK)


func _tap_key(code: Key) -> void:
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


func _tap_button(code: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await _frames(2)
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _fly_to(target: Vector2) -> void:
	for _step: int in range(1500):
		ShelfRouteDriver.steer(_scene.submarine.global_position, target)
		await physics_frame
		if _scene.submarine.global_position.distance_to(target) < 12.0 and _scene.submarine.velocity.length() < 30.0:
			ShelfRouteDriver.release()
			return
	ShelfRouteDriver.release()
	push_error("Station capture could not pilot to %s" % target)
	quit(1)


func _point(name: String) -> Vector2:
	return (_scene.region.get_node("RouteMarkers/" + name) as Marker2D).global_position


func _initialize() -> void:
	for path: String in ["user://bta032-capture.json.discoveries.json", "user://bta032-capture.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta032-capture.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.resume_route()
	await _frames(3)
	await _capture("station")
	_scene.submarine.hull_system.apply_damage(20.0, &"capture-fixture")
	await _fly_to(Vector2(760, 480))
	await _tap_key(KEY_F)
	await _frames(65)
	await _tap_key(KEY_E)
	await _frames(190)
	assert(_scene.research.is_completed(&"shelf-calibration-plate"))
	for name: String in ShelfRouteDriver.OUTBOUND:
		await _fly_to(_point(name))
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	await _frames(2)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	assert(_scene.submarine.hull_system.hull == 80.0)
	assert(_scene.submarine.resource_system.battery < 90.0)
	print("BTA032_EXPEDITION_RETURN hull=%s battery=%s oxygen=%s route=COMPLETE research=1" % [_scene.submarine.hull_system.hull, _scene.submarine.resource_system.battery, _scene.submarine.resource_system.oxygen])
	await _capture("returned")
	await _tap_key(KEY_E)
	assert(_scene.station_menu.visible)
	assert(_scene.submarine.hull_system.hull == 80.0)
	var ids: Array[StringName] = _scene.discoveries.discovered_ids()
	var research: Array[StringName] = _scene.research.completed_ids()
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	var elapsed: float = _scene.route_check.elapsed_seconds
	await _capture("before-service")
	for _step: int in range(4):
		await _tap_key(KEY_DOWN)
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.hull_system.hull == 100.0)
	assert(_scene.submarine.resource_system.battery == 100.0)
	assert(_scene.submarine.resource_system.oxygen == 100.0)
	assert(_scene.discoveries.discovered_ids() == ids)
	assert(_scene.research.completed_ids() == research)
	assert((_scene.get_node("AcousticBus") as AcousticBus).history_count() == history)
	assert(_scene.route_check.elapsed_seconds == elapsed)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	print("BTA032_SERVICE_COMPLETE hull=100 battery=100 oxygen=100 route_records_history_preserved=true")
	await _capture("after-service")
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_button(JOY_BUTTON_A)
	assert((_scene.station_menu.get_node("%BoardPage") as Control).visible)
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_button(JOY_BUTTON_A)
	await _capture("notices")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact-board")
	await _tap_button(JOY_BUTTON_B)
	await _capture("compact-services")
	await _tap_button(JOY_BUTTON_B)
	assert(_scene.submarine.is_physics_processing())
	await _tap_button(JOY_BUTTON_A)
	assert(_scene.station_menu.visible)
	await _tap_button(JOY_BUTTON_B)
	assert(_scene.submarine.is_physics_processing())
	print("BTA032_GRAPHICAL_DEPART_SCAN_EXPLORE_RETURN_SERVICE_BOARD_CONTROLLER_OK")
	quit()
