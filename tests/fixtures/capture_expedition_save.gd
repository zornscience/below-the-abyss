extends SceneTree
## Actual two-process expedition verification. The resume phase never clears saves.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-035-" + name + ".png") == OK)


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


func _spawn() -> void:
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta035-capture.json"
	_scene.expedition_path = "user://bta035-capture-expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)


func _resume_capture() -> void:
	var replayed: Array[String] = []
	node_added.connect(func(node: Node) -> void:
		if node is MissionService:
			(node as MissionService).mission_completed.connect(func(_id: StringName) -> void: replayed.append("mission"))
			(node as MissionService).acknowledgement_claimed.connect(func(_id: StringName, _ack: StringName) -> void: replayed.append("claim"))
		if node is ResearchRegistry:
			(node as ResearchRegistry).scan_completed.connect(func(_id: StringName) -> void: replayed.append("scan"))
		if node is SonarEmitter:
			(node as SonarEmitter).pulse_emitted.connect(func(_event: AcousticEvent) -> void: replayed.append("ping")))
	await _spawn()
	assert(_scene.saves.has_checkpoint())
	var expected: Dictionary = _scene.saves.store.read_file(_scene.saves.store.path).data
	assert((_scene.route_menu.get_node("%Resume") as Button).text == "Continue saved expedition")
	await _capture("continue")
	await _tap_button(JOY_BUTTON_A)
	_scene.open_route_menu()
	assert(_scene.submarine.global_position.distance_to(Vector2(expected.player.position[0], expected.player.position[1])) < 0.01)
	assert(absf(_scene.submarine.resource_system.battery - expected.player.battery) < 0.1)
	assert(absf(_scene.submarine.resource_system.oxygen - expected.player.oxygen) < 0.1)
	assert(_scene.submarine.hull_system.hull == expected.player.hull)
	assert(_scene.submarine.sonar.maximum_radius() == 1200.0)
	assert(_scene.submarine.damage_system.get_maximum_depth_m() == 400.0)
	assert(_scene.discoveries.state_of(&"shelf-twin-spires") == DiscoveryRegistry.State.DISCOVERED)
	assert(_scene.research.is_completed(&"shelf-calibration-plate"))
	assert(_scene.missions.snapshot()["shelf-expedition"].state == "claimed")
	assert(_scene.missions.snapshot()["shelf-calibration-study"].state == "claimed")
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	assert(replayed.is_empty())
	_scene.resume_route()
	await _frames(2)
	await _capture("resumed")
	var before: Vector2 = _scene.submarine.global_position
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	assert(_scene.submarine.global_position.x > before.x)
	_scene.open_route_menu()
	(_scene.route_menu.get_node("%SaveExpedition") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.saves.status.begins_with("Expedition saved"))
	(_scene.route_menu.get_node("%NewExpedition") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	await _capture("confirm")
	await _tap_button(JOY_BUTTON_DPAD_RIGHT)
	assert(root.gui_get_focus_owner() == _scene.route_menu.get_node("%ConfirmNew"))
	await _tap_button(JOY_BUTTON_B)
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact")
	_scene.resume_route()
	await _tap_key(KEY_E)
	(_scene.station_menu.get_node("%OpenUpgrades") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	await _capture("station-compact")
	print("BTA035_FRESH_PROCESS_CONTINUE_OK position_supplies_upgrades_research_discoveries_claims_route=true replayed_events=0 movement_after_load=true")
	quit()


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--resume-capture"):
		await _resume_capture()
		return
	for path: String in ["user://bta035-capture.json", "user://bta035-capture-expedition.json", "user://bta035-capture.json.missions.json", "user://bta035-capture.json.upgrades.json", "user://bta035-capture.json.discoveries.json", "user://bta035-capture.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	await _spawn()
	await _capture("start")
	(_scene.route_menu.get_node("%NewExpedition") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	await _capture("confirm")
	(_scene.route_menu.get_node("%ConfirmNew") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.is_physics_processing())
	await _tap_key(KEY_E)
	await _open_board()
	(_mission_board().get_node("%AcceptMission") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_mission_board().get_node("%MissionList").get_child(1) as Button).grab_focus()
	(_mission_board().get_node("%AcceptMission") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	await _fly_to(Vector2(760, 480))
	await _tap_key(KEY_F)
	await _frames(65)
	await _tap_key(KEY_E)
	await _frames(190)
	assert(_scene.research.is_completed(&"shelf-calibration-plate"))
	await _fly_to(_point("UpperGate"))
	await _fly_to(Vector2(1450, 400))
	await _tap_key(KEY_F)
	await _frames(4)
	assert(_scene.creature.brain.state == CreatureState.State.INVESTIGATE)
	await _capture("observer")
	for name: String in ["Cave", "EastChamber", "TwinSpires"]:
		await _fly_to(_point(name))
	await _tap_key(KEY_F)
	await _frames(65)
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	await _tap_key(KEY_E)
	(_scene.station_menu.get_node("%ServiceAll") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.resource_system.battery == 100.0)
	(_scene.station_menu.get_node("%OpenUpgrades") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_scene.station_menu.get_node("%InstallSonar") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_scene.station_menu.get_node("%InstallDepth") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	await _capture("station-saved")
	await _tap_button(JOY_BUTTON_B)
	await _open_board()
	(_mission_board().get_node("%ClaimMission") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	(_mission_board().get_node("%MissionList").get_child(1) as Button).grab_focus()
	(_mission_board().get_node("%ClaimMission") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	await _tap_key(KEY_ESCAPE)
	(_scene.route_menu.get_node("%SaveExpedition") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.saves.status.begins_with("Expedition saved"))
	await _capture("saved")
	print("BTA035_SAVE_EXIT_OK complete_route_scan_observer_services_two_upgrades_two_claims=true")
	quit()
