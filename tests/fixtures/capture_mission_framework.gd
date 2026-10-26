extends SceneTree
## Native full mission walkthrough: UI acceptance/claim and real-input flight.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-034-" + name + ".png") == OK)


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


func _mission_board() -> MissionBoard:
	return _scene.station_menu.get_node("%MissionsPage") as MissionBoard


func _open_board() -> void:
	(_scene.station_menu.get_node("%OpenBoard") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_scene.station_menu.get_node("%OpenMissions") as Button).grab_focus()
	await _tap_key(KEY_ENTER)


func _initialize() -> void:
	for path: String in ["user://bta034-capture.json", "user://bta034-capture.json.missions.json", "user://bta034-capture.json.upgrades.json", "user://bta034-capture.json.discoveries.json", "user://bta034-capture.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta034-capture.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	var completions: Array[StringName] = []
	var acknowledgements: Array[StringName] = []
	_scene.missions.mission_completed.connect(func(id: StringName) -> void: completions.append(id))
	_scene.missions.acknowledgement_claimed.connect(func(_id: StringName, ack: StringName) -> void: acknowledgements.append(ack))
	_scene.resume_route()
	await _tap_key(KEY_E)
	await _open_board()
	await _capture("available")
	(_mission_board().get_node("%AcceptMission") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_mission_board().get_node("%MissionList").get_child(1) as Button).grab_focus()
	(_mission_board().get_node("%AcceptMission") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	assert(_scene.missions.snapshot()["shelf-expedition"].state == "accepted")
	assert(_scene.missions.snapshot()["shelf-calibration-study"].state == "accepted")
	await _capture("accepted")
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	assert(_scene.submarine.is_physics_processing())
	await _fly_to(Vector2(760, 480))
	await _tap_key(KEY_F)
	await _frames(65)
	await _tap_key(KEY_E)
	await _frames(190)
	assert(_scene.research.is_completed(&"shelf-calibration-plate"))
	assert(_scene.missions.snapshot()["shelf-calibration-study"].state == "completed")
	await _capture("scan-complete")
	for name: String in ShelfRouteDriver.OUTBOUND:
		await _fly_to(_point(name))
	await _tap_key(KEY_F)
	await _frames(65)
	assert(_scene.discoveries.state_of(&"shelf-twin-spires") == DiscoveryRegistry.State.DISCOVERED)
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	assert(_scene.missions.snapshot()["shelf-expedition"].state == "completed")
	assert(_scene.submarine.hull_system.hull == 100.0)
	assert(_scene.submarine.resource_system.battery > 15.0)
	await _capture("returned")
	await _tap_key(KEY_E)
	await _open_board()
	await _capture("ready-to-claim")
	(_mission_board().get_node("%ClaimMission") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_mission_board().get_node("%MissionList").get_child(1) as Button).grab_focus()
	(_mission_board().get_node("%ClaimMission") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	assert(completions.size() == 2 and acknowledgements.size() == 2)
	await _capture("claimed")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	root.size = Vector2i(1280, 800)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	(_scene.station_menu.get_node("%ServiceAll") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.resource_system.battery == 100.0)
	_scene.restart_route()
	assert(_scene.missions.snapshot()["shelf-expedition"].state == "claimed")
	assert(_scene.missions.snapshot()["shelf-calibration-study"].state == "claimed")
	assert(completions.size() == 2 and acknowledgements.size() == 2)
	_scene.submarine.set_simulation_enabled(false)
	_scene.queue_free()
	await _frames(3)
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta034-capture.json"
	root.add_child(_scene)
	await _frames(3)
	assert(_scene.missions.snapshot()["shelf-expedition"].state == "claimed")
	assert(_scene.missions.snapshot()["shelf-calibration-study"].state == "claimed")
	print("BTA034_NATIVE_ACCEPT_SCAN_DISCOVER_RETURN_CLAIM_SERVICE_RESTART_RELOAD_OK completions=2 acknowledgements=2")
	quit()
