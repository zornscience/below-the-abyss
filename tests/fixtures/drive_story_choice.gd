extends SceneTree
## Actual keyboard/controller flow; two separate launches prove durable Continue.
var _scene: ShelfPrototype
var _keyboard: bool = false
var _outcome: String
var _resume: bool
var _captures: String
var _choice_events: int = 0
var _arrival_captured: bool = false
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
		await _respond_radio()
		if not _captures.is_empty() and not _arrival_captured and _scene.bloom.visual.arrival_active() and _scene.bloom.visual.arrival_elapsed>0.4:
			_arrival_captured = true
			await _capture("arrival-"+_outcome)
		var desired: Vector2 = ((target - _scene.submarine.global_position)*1.1-_scene.submarine.velocity*0.7).limit_length(160.0) / 240.0
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




func _respond_radio() -> void:
	if _scene.revision.ui.radio_page.visible:
		await _activate(_scene.revision.ui.find_child("AcceptTransmission",true,false) as Control)
func _control(id: String) -> Control:
	return _scene.revision.ui.find_child(id,true,false) as Control

func _argument(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(name+"="): return arg.substr(name.length()+1)
	return fallback
func _interact() -> void:
	if not _keyboard:
		await _tap(JOY_BUTTON_A)
		return
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)
func _capture(name: String) -> void:
	if _captures.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_captures.path_join(name+".png"))==OK)
func _initialize() -> void:
	_keyboard = _argument("--input","controller")=="keyboard"
	_outcome = _argument("--outcome","observe")
	_resume = OS.get_cmdline_user_args().has("--resume")
	_captures = OS.get_environment("BTA_EVIDENCE_DIR")
	var small: bool = OS.get_cmdline_user_args().has("--small")
	root.size = Vector2i(800,600) if small else Vector2i(1280,800)
	var token: String = _argument("--profile","bta046-native-"+str(Time.get_ticks_usec()))
	assert(PointOfInterest.valid_id(StringName(token)))
	var path: String = "user://"+token+".json"
	if not _resume:
		for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
			for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.canonical_chapter = false
	_scene.settings_path = path
	_scene.expedition_path = path+".expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(8)
	# Apply after the engine has initialized its project window dimensions.
	root.size = Vector2i(800,600) if small else Vector2i(1280,800)
	await _frames(8)
	assert(root.get_visible_rect().size==Vector2(800,600) if small else root.get_visible_rect().size==Vector2(1280,800))
	_scene.story.choice_applied.connect(func(_choice: StringName,_encounter: StringName) -> void: _choice_events += 1)
	var prefs: Dictionary = _scene.settings.snapshot().accessibility
	prefs.reduced_motion = small or OS.get_cmdline_user_args().has("--comfort")
	prefs.reduced_flashing = prefs.reduced_motion
	if small: prefs.ui_scale = "large"
	_scene.settings.set_accessibility(prefs)
	var audio: Dictionary = _scene.settings.snapshot().audio
	audio.muted = true
	_scene.settings.set_audio(audio)
	await _activate(_control("Begin"))
	await _move(Vector2(1280,480))
	await _respond_radio()
	if not _resume:
		assert(_scene.story.resonance()==0)
		await _tap(JOY_BUTTON_X)
		await _frames(100)
		assert(_scene.bloom.identified())
		await _interact()
		assert(_scene.bloom.modal())
		await _capture("choice-"+_outcome+("-small" if small else ""))
		var id: String = "ObserveBloom" if _outcome=="observe" else "CollectBloom"
		await _activate(_scene.bloom.panel.page.find_child(id,true,false) as Control)
		await _frames(240)
		assert(_scene.bloom.modal())
		assert(_choice_events==1)
		assert(_scene.story.resonance()==(15 if _outcome=="observe" else -15))
		assert(_scene.bloom.visual.collected==(_outcome=="collect"))
		assert(_scene.research.is_completed(LightBloomEncounter.SCAN)==(_outcome=="observe"))
		await _capture("feedback-"+_outcome+("-small" if small else ""))
	else:
		assert(_choice_events==0)
		assert(_scene.story.resonance()==(15 if _outcome=="observe" else -15))
		await _interact()
		assert(_scene.bloom.modal())
		assert(_scene.bloom.panel.page.find_child("ObserveBloom",true,false)==null)
		assert(_scene.bloom.visual.reaction==0.0)
	await _activate(_scene.bloom.panel.page.find_child("ReturnFromBloom",true,false) as Control)
	assert(_scene.submarine.is_physics_processing())
	await _frames(8)
	await _capture("habitat-"+_outcome+("-small" if small else ""))
	assert(_scene.story.apply_choice(LightBloomEncounter.OBSERVE)==ERR_ALREADY_EXISTS)
	assert(_scene.story.apply_choice(LightBloomEncounter.COLLECT)==ERR_ALREADY_EXISTS)
	assert(_scene.torpedoes.ammunition==10)
	assert(_scene.revision.campaign.awards==["commission"])
	print("STORY_CHOICE_WALK_PASS outcome=",_outcome," input=",("keyboard" if _keyboard else "controller")," resumed=",_resume," events=",_choice_events," mute=true")
	_scene.queue_free()
	await _frames(4)
	quit()
