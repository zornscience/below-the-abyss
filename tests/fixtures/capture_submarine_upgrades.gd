extends SceneTree
## Native upgrade UI plus a real-input route/trench flight.
## Only the baseline depth comparison is explicitly staged before the actual flight.

var _scene: ShelfPrototype


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-033-" + name + ".png") == OK)


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


func _frame_camera() -> void:
	_scene.submarine.reset_physics_interpolation()
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()


func _initialize() -> void:
	for path: String in ["user://bta033-capture.json", "user://bta033-capture.json.upgrades.json", "user://bta033-capture.json.discoveries.json", "user://bta033-capture.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta033-capture.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	# Presentation-only baseline at the same depth later reached by actual piloting.
	_scene.route_layer.hide()
	_scene.submarine.global_position = Vector2(3080, 1340)
	_scene.submarine.damage_system.advance(0.0, 335.0, _scene.submarine.hull_system)
	_frame_camera()
	_scene._refresh_scan_status()
	await _capture("depth-before")
	_scene.submarine.global_position = _scene.region.spawn.global_position
	_scene.submarine.damage_system.advance(0.0, 120.0, _scene.submarine.hull_system)
	_frame_camera()
	_scene.resume_route()
	await _tap_key(KEY_E)
	(_scene.station_menu.get_node("%OpenUpgrades") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	await _capture("upgrades-before")
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_ENTER)
	assert(_scene.upgrades.is_installed(&"sonar-range-1200"))
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	await _tap_button(JOY_BUTTON_A)
	assert(_scene.upgrades.is_installed(&"pressure-hull-400"))
	await _capture("upgrades-after")
	root.size = Vector2i(800, 600)
	await _frames(4)
	await _capture("upgrades-compact")
	root.size = Vector2i(1280, 800)
	await _tap_button(JOY_BUTTON_B)
	await _tap_button(JOY_BUTTON_B)
	assert(_scene.submarine.is_physics_processing())
	# All subsequent movement uses existing input steering, never pose/velocity writes.
	await _fly_to(Vector2(760, 480))
	await _tap_key(KEY_F)
	await _frames(130)
	var overlook: SonarRevealTarget = _scene.region.get_node("SonarTargets/overlook-marker") as SonarRevealTarget
	assert(overlook.is_revealed()) # ~1019 u: beyond baseline 900, inside upgraded 1200.
	print("BTA033_GRAPHICAL_EXTENDED_RANGE_ECHO_OK cost=4 cooldown=4")
	for name: String in ShelfRouteDriver.OUTBOUND:
		await _fly_to(_point(name))
	await _fly_to(_point("ReturnTurn"))
	await _fly_to(_point("LowerEast"))
	await _fly_to(_point("DangerDepth"))
	await _fly_to(Vector2(3080, 1340))
	await _frames(185)
	assert(_scene.submarine.damage_system.warning_state == SubmarineDamageSystem.WarningState.SAFE)
	assert(_scene.submarine.hull_system.hull == 100.0)
	await _capture("depth-after")
	await _fly_to(_point("LowerEast"))
	for name: String in ["LowerWest", "BaseRise"]:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	await _tap_key(KEY_E)
	(_scene.station_menu.get_node("%ServiceAll") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.resource_system.battery == 100.0)
	assert(_scene.upgrades.installed_ids().size() == 2)
	_scene.restart_route()
	assert(_scene.submarine.sonar.maximum_radius() == 1200.0)
	assert(_scene.submarine.damage_system.get_maximum_depth_m() == 400.0)
	print("BTA033_GRAPHICAL_INSTALL_EXPLORE_335M_RETURN_SERVICE_RESTART_OK")
	quit()
