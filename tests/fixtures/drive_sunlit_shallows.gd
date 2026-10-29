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
var _wall_started: int = 0
var _clock: RouteClock
var _pings: int = 0
var _threat_captured: bool = false
class RouteClock extends Node:
	var player: SubmarineController
	var seconds: float = 0.0
	func _physics_process(delta: float) -> void:
		if is_instance_valid(player) and player.is_physics_processing(): seconds += delta
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


func _move(target: Vector2,precise: bool = false) -> void:
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
		# Digital steering has a 12-unit dead band on each axis (17 diagonally).
		if _scene.submarine.global_position.distance_to(target) < (18.0 if precise else (28.0 if _keyboard else 12.0)) and _scene.submarine.velocity.length() < (15.0 if precise else (150.0 if _keyboard else 30.0)):
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

func _fire() -> void:
	await _frames(2)
	if _keyboard:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(3)
		event = event.duplicate() as InputEventKey
		event.pressed = false
		Input.parse_input_event(event)
	else:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_TRIGGER_RIGHT
		event.axis_value = 1.0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(3)
		event = event.duplicate() as InputEventJoypadMotion
		event.axis_value = 0.0
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(90)

func _round_fired(_id: StringName) -> void:
	_shots += 1
	if not _captures.is_empty() and _shots==1:
		await _frames(24)
		await _capture("torpedo-in-flight")

func _study(id: StringName) -> void:
	assert(_scene.submarine.scanner.candidate_id()==id,"Expected subject %s, got %s at %s" % [id,_scene.submarine.scanner.candidate_id(),_scene.submarine.global_position])
	await _interact()
	await _frames(420)
	assert(_scene.research.is_completed(id))
	assert(String(id) in _scene.revision.campaign.science.credited)
	await _capture("scan-"+String(id))
	print("SUNLIT_ROUTE_SCAN ",id," shots=",_shots)

func _supply_edge_cases() -> void:
	if OS.get_cmdline_user_args().has("--low-energy-demo"):
		for unused: int in range(30):
			if _scene.submarine.resource_system.battery<4: break
			await _tap(JOY_BUTTON_X)
			await _frames(250)
		var accepted: int = _pings
		await _tap(JOY_BUTTON_X)
		assert(_pings==accepted and _scene.submarine.sonar.cooldown_remaining()==0.0)
		await _capture("low-sonar-energy")
		await _interact()
		assert(_scene.revision.ui.dock_page.visible)
		await _capture("energy-service-recovery")
		await _activate(_control("Depart"))
	if OS.get_cmdline_user_args().has("--empty-ammo-demo"):
		# Intentional normal-input launches into the protected station support west.
		await _move(Vector2(340,80))
		for unused: int in range(10): await _fire()
		assert(_scene.torpedoes.ammunition==0 and _shots==10)
		assert(not _scene.chapter.guide.layout.passage_clear())
		assert(not _scene.creature._destroyed)

func _map_lesson() -> void:
	await _move(Vector2(900,480))
	await _tap(JOY_BUTTON_BACK)
	assert(_scene.exploration_map.visible and _scene.exploration_map.canvas.has_report)
	assert(not _scene.exploration_map.canvas.points.any(func(point: PointOfInterest) -> bool: return point.stable_id==SunlitShallowsData.POI))
	await _capture("expanded-map")
	await _activate(_scene.exploration_map.find_child("ZoomIn",true,false) as Control)
	assert(_scene.exploration_map.canvas.zoom==2.0)
	await _activate(_scene.exploration_map.find_child("PanEast",true,false) as Control)
	await _capture("expanded-map-zoom")
	await _tap(JOY_BUTTON_BACK)
	assert(_scene.submarine.is_physics_processing())

func _expanded_course() -> void:
	var no_excavation: bool = OS.get_cmdline_user_args().has("--no-excavation")
	if no_excavation:
		for at: Vector2 in [Vector2(2350,480),Vector2(3500,480),Vector2(4300,180),Vector2(5100,180)]: await _move(at)
		assert(not _scene.chapter.guide.layout.passage_clear())
		await _capture("open-water-bypass")
	else:
		for at: Vector2 in [Vector2(2350,480),Vector2(3500,480),Vector2(4300,480)]: await _move(at)
		assert(not _scene.chapter.guide.layout.passage_clear())
		await _capture("rockfall-before")
		if OS.get_cmdline_user_args().has("--empty-ammo-demo"):
			await _fire()
			assert(_scene.torpedoes.ammunition==0 and not _scene.chapter.guide.layout.passage_clear())
			for at: Vector2 in [Vector2(3500,480),Vector2(1280,480),SunlitSurveyData.SPAWN]: await _move(at)
			await _interact()
			assert(_scene.torpedoes.ammunition==10)
			await _capture("ammunition-service-recovery")
			await _activate(_control("Depart"))
			for at: Vector2 in [Vector2(1280,480),Vector2(3500,480),Vector2(4300,480)]: await _move(at)
		for shot: int in range(3):
			await _fire()
			assert(_scene.chapter.guide.layout.passage_clear()==(shot==2))
		await _capture("underwater-blast-aftermath")
		assert(_scene.chapter.guide.layout.passage_clear())
		assert(_scene.discoveries.state_of(SunlitSurveyData.CLEARED)==DiscoveryRegistry.State.DISCOVERED)
		await _capture("rockfall-after")
	for at: Vector2 in ([Vector2(5400,600),Vector2(6000,600)] if no_excavation else [Vector2(4900,480),Vector2(5400,600),Vector2(6000,600)]): await _move(at)
	await _study(&"sunlit-silver-shoal")
	await _capture("fish-school")
	if OS.get_cmdline_user_args().has("--survey-studies"):
		for at: Vector2 in [Vector2(6200,600),Vector2(6200,1000),Vector2(6260,1000)]: await _move(at)
		await _capture("optional-cave-before")
		await _fire()
		await _move(Vector2(6750,1000))
		await _capture("optional-cave-inside")
		for at: Vector2 in [Vector2(6200,1000),Vector2(6200,260)]: await _move(at)
	if OS.get_cmdline_user_args().has("--fauna-demo"):
		for at: Vector2 in [Vector2(6100,260),Vector2(7100,260),Vector2(7100,430),Vector2(6750,430)]: await _move(at)
		await _capture("dead-end-alcove")
		for at: Vector2 in [Vector2(7100,430),Vector2(7100,260)]: await _move(at)
	var all_studies: bool = OS.get_cmdline_user_args().has("--survey-studies")
	for at: Vector2 in [Vector2(6100,260),Vector2(7100,260),Vector2(7150,360),Vector2(7650,370)]: await _move(at)
	await _study(&"sunlit-mineral-terrace")
	await _capture("sea-turtle")
	await _move(Vector2(8500,360))
	if OS.get_cmdline_user_args().has("--fauna-demo"):
		await _move(Vector2(8500,650))
		await _capture("moray-eel")
	for at: Vector2 in [Vector2(8650,200),Vector2(9800,200),Vector2(9800,620),Vector2(9100,620)]: await _move(at)
	if all_studies: await _study(&"sunlit-amber-darter")
	await _move(Vector2(9750,620))
	if all_studies:
		await _move(Vector2(9800,650))
		await _fire()
		await _move(Vector2(10600,650))
		await _study(&"sunlit-basalt-arch")
		await _move(Vector2(9800,650))
	await _move(Vector2(9800,200))
	await _capture("rock-arch-passages")
	for at: Vector2 in [Vector2(11780,200),Vector2(12300,200),Vector2(13000,400),Vector2(14000,480)]: await _move(at)
	if all_studies:
		await _move(Vector2(14000,1020))
		await _study(&"sunlit-vent-survey")
		await _capture("vent-safe")
		if OS.get_cmdline_user_args().has("--vent-damage-demo"):
			await _move(Vector2(14000,1450))
			await _frames(90)
			assert(_scene.submarine.damage_system.warning_state==SubmarineDamageSystem.WarningState.EXCEEDED)
			assert(_scene.submarine.hull_system.hull<100 and _scene.submarine.hull_system.hull>0)
			await _capture("vent-danger")
		await _move(Vector2(14000,480))
		assert(_scene.submarine.damage_system.warning_state==SubmarineDamageSystem.WarningState.SAFE)
	for at: Vector2 in [Vector2(14700,260),Vector2(16400,260),Vector2(16400,650),Vector2(15500,650)]: await _move(at)
	if all_studies: await _study(&"sunlit-blue-grazer")
	await _move(Vector2(16600,650))
	if all_studies:
		await _move(Vector2(16800,680))
		await _study(&"sunlit-pillow-basalt")
	for at: Vector2 in [Vector2(16900,320),Vector2(17800,320)]: await _move(at)
	if all_studies: await _study(&"sunlit-sediment-fan")
	await _move(Vector2(19000,320))
	if OS.get_cmdline_user_args().has("--missed-ping-demo"):
		await _tap(JOY_BUTTON_X)
		await _frames(120)
		assert(not _scene.chapter.buoy.visible)
		assert(_scene.discoveries.state_of(SunlitShallowsData.POI)==DiscoveryRegistry.State.HIDDEN)
		await _capture("buoy-missed-ping")
	if OS.get_cmdline_user_args().has("--fauna-demo"):
		var hull: float = _scene.submarine.hull_system.hull
		# Leave braking room inside the leash and space for a genuine head-first run,
		# rather than settling on top of a stationary animal (which cannot ram).
		await _move(Vector2(19300,900) if _keyboard else Vector2(19000,900),_keyboard)
		await _capture("hammerhead-warning")
		# A free patrol may initially be swimming away; wait, without moving either
		# actor or altering its state, for the normal perception / warning / charge.
		if _keyboard:
			for unused: int in range(1800):
				if _scene.submarine.hull_system.hull<hull: break
				await physics_frame
		else: await _frames(240)
		assert(_scene.submarine.hull_system.hull<hull)
		await _capture("hammerhead-ram")
		await _move(Vector2(19000,400))
		assert(_scene.chapter.guide.hammerhead.threat.phase!=PredatorState.Phase.PURSUE)
		await _capture("hammerhead-safe-retreat")
	for at: Vector2 in [Vector2(19650,320),Vector2(19750,320),Vector2(19750,600)]: await _move(at)
	assert(not _scene.chapter.buoy.visible)
	await _tap(JOY_BUTTON_X)
	await _frames(110)
	assert(not _scene.chapter.buoy.visible,"A sweep at the shelter entrance cannot skip the baffles.")
	await _capture("shelter-entrance")
	for at: Vector2 in [Vector2(19900,710),Vector2(20300,710),Vector2(20300,560),Vector2(20600,560)]: await _move(at)
	assert(not _scene.chapter.buoy.visible)
	await _capture("buoy-before-sonar")
	await _tap(JOY_BUTTON_X)
	await _frames(2)
	assert(not _scene.chapter.buoy.visible)
	await _capture("sonar-travelling")
	await _frames(95)
	assert(_scene.chapter.buoy.visible)
	await _capture("sonar-buoy-arrival")
	await _move(SunlitSurveyData.BUOY)

func _capture(name: String) -> void:
	if _captures.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_captures.path_join(_outcome+"-"+name+("-small" if _small else "")+".png"))==OK)
func _initialize() -> void:
	_wall_started = Time.get_ticks_usec()
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
	var dimensions: Vector2i = Vector2i(800,600) if _small else (Vector2i(1920,1080) if OS.get_cmdline_user_args().has("--wide") else Vector2i(1280,800))
	root.size = dimensions
	await _frames(8)
	assert(root.get_visible_rect().size==Vector2(dimensions))
	var comfort: Dictionary = _scene.settings.snapshot().accessibility
	comfort.reduced_motion = _small or OS.get_cmdline_user_args().has("--comfort")
	comfort.reduced_flashing = comfort.reduced_motion
	comfort.reduced_particles = comfort.reduced_motion
	comfort.high_contrast = OS.get_cmdline_user_args().has("--high-contrast")
	if _small: comfort.ui_scale = "large"
	_scene.settings.set_accessibility(comfort)
	var audio: Dictionary = _scene.settings.snapshot().audio
	audio.muted = true
	_scene.settings.set_audio(audio)
	_clock = RouteClock.new()
	_clock.player = _scene.submarine
	root.add_child(_clock)
	_scene.submarine.sonar.pulse_emitted.connect(func(_event: AcousticEvent) -> void: _pings+=1)
	_scene.torpedoes.fired.connect(_round_fired)
	_scene.torpedoes.detonated.connect(func(_id: StringName,at: Vector2) -> void:
		if not _captures.is_empty() and at.x>4500 and at.x<5050: _capture("underwater-detonation-"+str(_shots)))
	if not _captures.is_empty():
		_scene.chapter.guide.hammerhead.threat_changed.connect(func() -> void:
			if not _threat_captured and _scene.chapter.guide.hammerhead.threat.phase==PredatorState.Phase.ALERT:
				_threat_captured = true
				_capture("hammerhead-warning-start"))
	_scene.story.choice_applied.connect(func(_id: StringName,_encounter: StringName) -> void: _choice_events+=1)
	_scene.missions.acknowledgement_claimed.connect(func(_id: StringName,_ack: StringName) -> void: _ack_events+=1)
	_scene.research.scan_completed.connect(func(_id: StringName) -> void: _scan_events+=1)
	await _capture("title")
	if OS.get_cmdline_user_args().has("--fauna-demo"):
		await _activate(_control("NewGame"))
		await _capture("new-game-confirmation")
		await _activate(_control("StoryBack"))
	await _activate(_control("Begin"))
	if not _resume:
		assert(_scene.chapter.state()=="available")
		await _capture("briefing")
		await _activate(_control("AskOkafor"))
		await _activate(_control("BackBriefing"))
		await _activate(_control("LaunchSunlit"))
		assert(_scene.chapter.active and _scene.chapter.state()=="accepted")
		await _frames(6)
		assert(_scene.pilot_context.size.y<140.0)
		await _capture("surface-departure")
		# Research technology remains accessible before this mission; no new currency.
		await _interact()
		await _activate(_control("Technology"))
		await _capture("technology-icons")
		await _activate(_control("sonarAssign"))
		assert(int(_scene.revision.campaign.ranks.sonar)==1)
		await _activate(_control("BackOperations"))
		await _activate(_control("Depart"))
		await _supply_edge_cases()
		await _map_lesson()
		if OS.get_cmdline_user_args().has("--stop-after-map"):
			print("SUNLIT_MAP_REVIEW_PASS")
			_clock.queue_free()
			_scene.queue_free()
			await _frames(4)
			quit()
			return
		await _move(Vector2(1280,480))
		await _interact()
		assert(_scene.bloom.modal())
		await _capture("bloom-choice")
		await _activate(_scene.bloom.panel.page.find_child("ObserveBloom" if _outcome=="observe" else "CollectBloom",true,false) as Control)
		await _frames(240)
		assert(_scene.bloom.modal())
		await _capture("bloom-outcome")
		await _activate(_scene.bloom.panel.page.find_child("ReturnFromBloom",true,false) as Control)
		await _tap(JOY_BUTTON_LEFT_SHOULDER)
		for unused: int in range(12):
			if _scene.revision.ui.notifications.selected=="sunlit-bloom-response": break
			await _activate(_control("NextRadio"))
		assert(_scene.revision.ui.notifications.selected=="sunlit-bloom-response")
		await _capture("bloom-radio-portrait")
		await _activate(_control("CloseRadio"))
		await _expanded_course()
		await _capture("buoy-environment")
		await _interact()
		await _frames(300)
		assert(_scene.research.is_completed(SunlitShallowsData.BUOY))
		assert(_scene.revision.ui.notifications.contains_message("sunlit-buoy-recovered"))
		assert(_scene.submarine.is_physics_processing())
		await _tap(JOY_BUTTON_LEFT_SHOULDER)
		for unused: int in range(12):
			if _scene.revision.ui.notifications.selected=="sunlit-buoy-recovered": break
			await _activate(_control("NextRadio"))
		assert(_scene.revision.ui.notifications.selected=="sunlit-buoy-recovered")
		for unused: int in range(80):
			if root.gui_get_focus_owner()==_scene.revision.ui.notifications.scroll: break
			await _tap(JOY_BUTTON_RIGHT_SHOULDER)
		await _tap(JOY_BUTTON_DPAD_DOWN)
		assert(_scene.revision.ui.notifications.scroll.scroll_vertical>0)
		assert(_scene.submarine.is_physics_processing())
		await _capture("maras-message")
		if OS.get_cmdline_user_args().has("--stop-at-buoy"):
			print("SUNLIT_BUOY_CHECKPOINT_PASS outcome=",_outcome," input=",("keyboard" if _keyboard else "controller"))
			_clock.queue_free()
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
		var home: Array[Vector2] = SunlitSurveyData.MAIN_ROUTE.duplicate()
		home.reverse()
		for at: Vector2 in home: await _move(at)
		await _move(SunlitSurveyData.SPAWN)
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
	assert(_scene.torpedoes.ammunition==10)
	assert(_shots==(0 if _resume or OS.get_cmdline_user_args().has("--no-excavation") else ((10 if OS.get_cmdline_user_args().has("--empty-ammo-demo") else 0)+3+(2 if OS.get_cmdline_user_args().has("--survey-studies") else 0))))
	if OS.get_cmdline_user_args().has("--no-excavation"):
		assert(not _scene.chapter.guide.layout.passage_clear())
		assert(_scene.excavation.snapshot().is_empty())
	else:
		assert(_scene.chapter.guide.layout.passage_clear())
		assert(_scene.excavation.snapshot().any(func(cut: Dictionary) -> bool: return cut.rock=="sunlit-cavein"))
	assert(_scene.revision.campaign.awards==["commission"])
	assert(_scene.research.is_completed(SunlitShallowsData.BUOY))
	await _activate(_control("Technology"))
	await _capture("research-xp")
	if OS.get_cmdline_user_args().has("--survey-studies"):
		assert(ResearchExperienceData.points(_scene.revision.campaign.science)==2)
		# Spend beyond the two-point commissioning budget through real station UI.
		assert(CampaignData.available(_scene.revision.campaign)==2)
		assert((_control("hullAssign") as Button).disabled)
		await _activate(_control("ReassignAll"))
		await _activate(_control("engineAssign"))
		assert(int(_scene.revision.campaign.ranks.engine)==1)
		assert(_scene.submarine.motion.acceleration==180.0)
		await _capture("research-xp-assigned")
	print("SUNLIT_CHAPTER_WALK_PASS outcome=",_outcome," input=",("keyboard" if _keyboard else "controller")," resumed=",_resume," choices=",_choice_events," claims=",_ack_events," simulation_seconds=",_clock.seconds," wall_seconds=",(Time.get_ticks_usec()-_wall_started)/1000000.0," research_xp=",ResearchExperienceData.total(_scene.revision.campaign.science)," shots=",_shots," muted=true")
	_clock.queue_free()
	_scene.queue_free()
	await _frames(4)
	quit()
