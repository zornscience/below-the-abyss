extends SceneTree
## Actual keyboard/controller flow; two separate launches prove durable Continue.
var _scene: ShelfPrototype
var _keyboard: bool = false
var _outcome: String
var _resume: bool
var _captures: String
var _choice_events: int = 0
var _arrival_captured: bool = false
var _shots: int = 0
var _ack_events: int = 0
var _scan_events: int = 0
var _small: bool = false
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
			JOY_BUTTON_RIGHT_SHOULDER: KEY_TAB, JOY_BUTTON_LEFT_SHOULDER: KEY_R}
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
	# Chapter pages are activated explicitly at the corresponding input steps.
	pass
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
	assert(root.get_texture().get_image().save_png(_captures.path_join(_outcome+"-"+name+("-small" if _small else "")+".png"))==OK)
func _initialize() -> void:
	_keyboard = _argument("--input","controller")=="keyboard"
	_outcome = _argument("--outcome","observe")
	_resume = OS.get_cmdline_user_args().has("--resume")
	_small = OS.get_cmdline_user_args().has("--small")
	_captures = OS.get_environment("BTA_EVIDENCE_DIR")
	var profile: String = _argument("--profile","bta047-route-"+str(Time.get_ticks_usec()))
	assert(PointOfInterest.valid_id(StringName(profile)))
	var path: String = "user://"+profile+".json"
	if not _resume:
		for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
			for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = path
	_scene.expedition_path = path+".expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(8)
	root.size = Vector2i(800,600) if _small else Vector2i(1280,800)
	await _frames(8)
	assert(root.get_visible_rect().size==Vector2(800,600) if _small else root.get_visible_rect().size==Vector2(1280,800))
	var comfort: Dictionary = _scene.settings.snapshot().accessibility
	comfort.reduced_motion = _small or OS.get_cmdline_user_args().has("--comfort")
	comfort.reduced_flashing = comfort.reduced_motion
	if _small: comfort.ui_scale = "large"
	_scene.settings.set_accessibility(comfort)
	var audio: Dictionary = _scene.settings.snapshot().audio
	audio.muted = true
	_scene.settings.set_audio(audio)
	_scene.torpedoes.fired.connect(func(_id: StringName) -> void: _shots+=1)
	_scene.story.choice_applied.connect(func(_id: StringName,_encounter: StringName) -> void: _choice_events+=1)
	_scene.missions.acknowledgement_claimed.connect(func(_id: StringName,_ack: StringName) -> void: _ack_events+=1)
	_scene.research.scan_completed.connect(func(_id: StringName) -> void: _scan_events+=1)
	await _capture("title")
	await _activate(_control("Begin"))
	if not _resume:
		assert(_scene.chapter.state()=="available")
		await _capture("briefing")
		await _activate(_control("AskOkafor"))
		await _activate(_control("BackBriefing"))
		await _activate(_control("LaunchSunlit"))
		assert(_scene.chapter.active and _scene.chapter.state()=="accepted")
		# Research technology remains accessible before this mission; no new currency.
		await _interact()
		await _activate(_control("Technology"))
		await _activate(_control("sonarAssign"))
		assert(int(_scene.revision.campaign.ranks.sonar)==1)
		await _activate(_control("BackOperations"))
		await _activate(_control("Depart"))
		await _move(Vector2(1280,480))
		await _tap(JOY_BUTTON_X)
		await _frames(100)
		await _interact()
		assert(_scene.bloom.modal())
		await _capture("bloom-choice")
		await _activate(_scene.bloom.panel.page.find_child("ObserveBloom" if _outcome=="observe" else "CollectBloom",true,false) as Control)
		await _frames(240)
		assert(_scene.bloom.modal())
		await _capture("bloom-outcome")
		await _activate(_scene.bloom.panel.page.find_child("ReturnFromBloom",true,false) as Control)
		for at: Vector2 in [Vector2(2350,480),Vector2(3050,480),Vector2(3500,620)]: await _move(at)
		await _capture("buoy-environment")
		await _tap(JOY_BUTTON_X)
		await _frames(100)
		await _interact()
		await _frames(300)
		assert(_scene.research.is_completed(SunlitShallowsData.BUOY))
		assert(_scene.revision.ui.notifications.contains_message("sunlit-buoy-recovered"))
		assert(_scene.submarine.is_physics_processing())
		await _tap(JOY_BUTTON_LEFT_SHOULDER)
		await _activate(_control("RadioDown"))
		assert(_scene.revision.ui.notifications.scroll.scroll_vertical>0)
		assert(_scene.submarine.is_physics_processing())
		await _capture("maras-message")
		if OS.get_cmdline_user_args().has("--stop-at-buoy"):
			print("SUNLIT_BUOY_CHECKPOINT_PASS outcome=",_outcome," input=",("keyboard" if _keyboard else "controller"))
			_scene.queue_free()
			await _frames(4)
			quit()
			return
		await _activate(_control("CloseRadio"))
	else:
		assert(_choice_events==0 and _scan_events==0 and _ack_events==0)
		assert(_scene.chapter.active)
		assert(_scene.research.is_completed(SunlitShallowsData.BUOY))
		assert(_scene.chapter.log_text().contains(SunlitShallowsData.MESSAGE))
		assert(not _scene.revision.ui.radio_page.visible)
	assert(_scene.story.resonance()==(15 if _outcome=="observe" else -15))
	assert(_scene.story.apply_choice(LightBloomEncounter.OBSERVE)==ERR_ALREADY_EXISTS)
	assert(_scene.story.apply_choice(LightBloomEncounter.COLLECT)==ERR_ALREADY_EXISTS)
	if not _scene.chapter.concluded():
		for at: Vector2 in [Vector2(3050,480),Vector2(2350,480),Vector2(1200,480),Vector2(420,480)]: await _move(at)
		assert(_scene.chapter.state()=="completed")
	await _frames(90) # Coast below the station's validated docking-speed limit.
	await _interact()
	assert(_scene.revision.ui.dock_page.visible)
	await _capture("halcyon-return")
	await _activate(_control("ChapterDebrief"))
	await _capture("debrief")
	await _activate(_control("SubmitSunlitDebrief"))
	if _scene.revision.ui.radio_page.visible:
		await _capture("chapter-complete")
		await _activate(_control("FinishSunlit"))
	assert(_scene.chapter.concluded())
	assert(_ack_events==(0 if _resume and _argument("--checkpoint","complete")=="complete" else 1))
	assert(_scene.submarine.hull_system.hull==100.0)
	assert(_scene.torpedoes.ammunition==10 and _shots==0)
	assert(_scene.excavation.snapshot().is_empty())
	assert(_scene.revision.campaign.awards==["commission"])
	assert(_scene.research.is_completed(SunlitShallowsData.BUOY))
	print("SUNLIT_CHAPTER_WALK_PASS outcome=",_outcome," input=",("keyboard" if _keyboard else "controller")," resumed=",_resume," choices=",_choice_events," claims=",_ack_events," simulation_seconds=",_scene.route_check.elapsed_seconds," muted=true")
	_scene.queue_free()
	await _frames(4)
	quit()
