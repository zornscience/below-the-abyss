extends SceneTree
## Input-driven full expanded expedition. Works with an exported PCK using an external driver.
var _scene: ShelfPrototype
var _keyboard: bool = false
var steps: int = 0
func _frames(count: int = 4) -> void:
	for _index: int in range(count):
		await physics_frame


func _tap(button: JoyButton) -> void:
	var event: InputEvent
	if _keyboard:
		var key: InputEventKey = InputEventKey.new()
		var keys: Dictionary = {JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE,
			JOY_BUTTON_START: KEY_P, JOY_BUTTON_BACK: KEY_M, JOY_BUTTON_X: KEY_F,
			JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_UP: KEY_UP,
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
			JOY_BUTTON_RIGHT_SHOULDER: KEY_TAB}
		key.keycode = keys[button]
		key.physical_keycode = key.keycode
		key.pressed = true
		event = key
	else:
		var joy: InputEventJoypadButton = InputEventJoypadButton.new()
		joy.button_index = button
		joy.pressed = true
		event = joy
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await _frames(2)
	event = event.duplicate() as InputEvent
	if event is InputEventKey:
		(event as InputEventKey).pressed = false
	else:
		(event as InputEventJoypadButton).pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _activate(control: Control) -> void:
	# Follow the actual fixed focus-next binding; no mouse or programmatic grab_focus.
	for _index: int in range(80):
		if root.gui_get_focus_owner() == control:
			await _tap(JOY_BUTTON_A)
			return
		await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	push_error("Controller focus could not reach " + control.name)
	quit(1)


func _move(target: Vector2) -> void:
	for _step: int in range(4800):
		var desired: Vector2 = ((target - _scene.submarine.global_position) * 2.5).limit_length(185.0) / 240.0
		var deadzone: float = InputMap.action_get_deadzone("move_left")
		var encoded: Vector2 = desired.normalized() * lerpf(deadzone, 1.0, desired.length()) if not desired.is_zero_approx() else Vector2.ZERO
		if _keyboard:
			encoded = target - _scene.submarine.global_position - _scene.submarine.velocity * 0.3
			# Keyboard-only steering: press/release physical keys at the same steering thresholds.
			for pair: Array in [[KEY_A, encoded.x < -12.0], [KEY_D, encoded.x > 12.0], [KEY_W, encoded.y < -12.0], [KEY_S, encoded.y > 12.0]]:
				var event: InputEventKey = InputEventKey.new()
				event.keycode = pair[0]
				event.physical_keycode = pair[0]
				event.pressed = pair[1]
				Input.parse_input_event(event)
		else:
			for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
				var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
				motion.axis = axis
				motion.axis_value = encoded.x if axis == JOY_AXIS_LEFT_X else encoded.y
				Input.parse_input_event(motion)
		await physics_frame
		if _scene.submarine.global_position.distance_to(target) < (28.0 if _keyboard else 12.0) and _scene.submarine.velocity.length() < (150.0 if _keyboard else 30.0):
			_release_motion()
			await _frames(20)
			return
	_release_motion()
	push_error("Input-driven accessibility route failed to reach %s: position=%s velocity=%s running=%s" % [target, _scene.submarine.global_position, _scene.submarine.velocity, _scene.submarine.is_physics_processing()])
	quit(1)


func _release_motion() -> void:
	if _keyboard:
		for code: Key in [KEY_A, KEY_D, KEY_W, KEY_S]:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			Input.parse_input_event(event)
	else:
		for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
			event.axis = axis
			Input.parse_input_event(event)


func _point(name: String) -> Vector2:
	return (_scene.region.get_node("RouteMarkers/" + name) as Marker2D).global_position



func _scan(id: StringName) -> void:
	await _tap(JOY_BUTTON_X)
	await _frames(120)
	await _tap(JOY_BUTTON_A)
	await _frames(650)
	assert(_scene.research.is_completed(id),"Scan incomplete: "+String(id))
	print("EXPANDED_SCAN ",id," at=",_scene.submarine.global_position)
func _initialize() -> void:
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://feedback-flight-%d.json" % Time.get_ticks_usec()
	_scene.expedition_path = _scene.settings_path+".expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(6)
	await _activate(_scene.route_menu.get_node("%Resume") as Control)
	await _tap(JOY_BUTTON_A)
	assert(_scene.station_menu.visible)
	await _activate(_scene.station_menu.get_node("%OpenUpgrades") as Control)
	await _activate(_scene.station_menu.get_node("%InstallDepth") as Control)
	assert(_scene.upgrades.is_installed(&"pressure-hull-400"))
	await _tap(JOY_BUTTON_B)
	await _activate(_scene.station_menu.get_node("%Undock") as Control)
	await _move(Vector2(760,480))
	await _scan(&"shelf-calibration-plate")
	for name: String in ["UpperGate","Cave","EastChamber","TwinSpires"]:
		await _move(_point(name))
	await _tap(JOY_BUTTON_X)
	await _frames(120)
	for at: Vector2 in [Vector2(4300,700),Vector2(4700,700),Vector2(6200,700),Vector2(6500,700)]: await _move(at)
	await _scan(&"outer-hydrophone-record")
	for at: Vector2 in [Vector2(8000,1100),Vector2(11200,1100),Vector2(12800,1100)]: await _move(at)
	await _scan(&"outer-vent-study")
	for at: Vector2 in [Vector2(15000,1100),Vector2(18400,1100),Vector2(18800,600),Vector2(19800,600),Vector2(19900,1100),Vector2(21600,1240)]: await _move(at)
	await _scan(&"lost-expedition-blackbox")
	assert(not _scene.narrative.is_concluded())
	for at: Vector2 in [Vector2(19900,1100),Vector2(19800,600),Vector2(18800,600),Vector2(18400,1100),Vector2(15000,1100),Vector2(12800,1100),Vector2(11200,1100),Vector2(8000,1100),Vector2(6500,700),Vector2(6200,700),Vector2(4700,700),Vector2(4300,700),Vector2(3560,650)]: await _move(at)
	for name: String in ["ReturnTurn","LowerEast","LowerWest","BaseRise"]: await _move(_point(name))
	await _move(_scene.region.spawn.global_position)
	assert(_scene.narrative.can_debrief())
	await _tap(JOY_BUTTON_A)
	await _activate(_scene.station_menu.get_node("%OpenStationStory") as Control)
	await _activate(_scene.expedition_log.debrief_button)
	assert(_scene.narrative.is_concluded())
	assert(_scene.submarine.hull_system.hull==100.0)
	print("EXPANDED_FLIGHT_PASS simulation_seconds=",_scene.route_check.elapsed_seconds," battery=",_scene.submarine.resource_system.battery," oxygen=",_scene.submarine.resource_system.oxygen," hull=",_scene.submarine.hull_system.hull," excavations=",_scene.excavation.snapshot().size())
	quit()
