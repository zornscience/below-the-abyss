extends SceneTree
## Actual physical-key / joypad events; authored paths and probes come from the arena Resource.
var box: CombatBox
var keyboard: bool = true
var captures: String
var small: bool = false
var saw_telegraph: bool = false
var captures_pending: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _frames(count: int) -> void:
	for index: int in range(count): await physics_frame
func _run() -> void:
	keyboard = not OS.get_cmdline_user_args().has("--controller")
	small = OS.get_cmdline_user_args().has("--small")
	captures = OS.get_environment("BTA_EVIDENCE_DIR")
	box = preload("res://scenes/playtesting/combat_box.tscn").instantiate() as CombatBox
	root.add_child(box)
	root.size = Vector2i(800,600) if small else Vector2i(1280,800)
	await _frames(8)
	var prefs: Dictionary = box.settings.snapshot().accessibility
	prefs.reduced_motion = true
	prefs.reduced_flashing = true
	prefs.reduced_particles = true
	box.settings.set_accessibility(prefs)
	var audio: Dictionary = box.settings.snapshot().audio
	audio.muted = true
	box.settings.set_audio(audio)
	box.observer.store.directory = "user://combat-proof-"+str(Time.get_ticks_usec())
	assert(box.observer.recorder.snapshot().is_empty())
	await _capture("developer-options")
	await _activate(box.record_button)
	assert(box.observer.recorder.recording)
	for id: String in ["weighty","responsive"]:
		await _activate(box.weighty_button if id=="weighty" else box.responsive_button)
		assert(box.submarine.motion==CombatHandling.profile(id))
		await _activate(box.resume_button)
		await _measure(id)
		box.open_options()
		# Measurement staging returns to the Resource's course start; every course leg uses input.
		box.submarine.global_position = CombatBox.DATA.course[0]
		box.submarine.velocity = Vector2.ZERO
		await _activate(box.resume_button)
		var hull: float = box.submarine.hull_system.hull
		for at: Vector2 in CombatBox.DATA.course: await _move(at)
		assert(box.submarine.hull_system.hull==hull)
		print("COMBAT_COURSE_PASS ",id," input=",("keyboard" if keyboard else "controller"))
		await _tap(KEY_P,JOY_BUTTON_START)
	await _activate(box.refit_button)
	for actor: CombatSwarmer in box.swarmers: actor.phase_changed.connect(_phase)
	await _activate(box.resume_button)
	await _move(CombatBox.DATA.stun_probe)
	await _capture("arena")
	await _face_right()
	await _tap(KEY_F,JOY_BUTTON_X)
	assert(box.swarmers[0].model.phase==SwarmerState.Phase.STUN)
	assert(box.stalker.hunt.phase!=RiftStalkerState.Phase.STUN)
	await _capture("sonar-stun")
	await _fire()
	assert(box.swarmers[0]._destroyed)
	assert(box.torpedoes.ammunition==TorpedoLauncher.CAPACITY-1)
	print("COMBAT_ONE_TORPEDO_PASS")
	for tick: int in range(1800):
		await physics_frame
		if box.stalker.hunt.phase==RiftStalkerState.Phase.PURSUE: break
	assert(box.stalker.hunt.phase==RiftStalkerState.Phase.PURSUE)
	for tick: int in range(600):
		await physics_frame
		if box.stalker.global_position.distance_to(box.submarine.global_position)<=box.stalker.hunt.profile.sense_radius*0.5: break
	assert(box.stalker.hunt.phase==RiftStalkerState.Phase.PURSUE)
	assert(box.stalker.global_position.distance_to(box.submarine.global_position)<=box.stalker.hunt.profile.sense_radius*0.5)
	await _capture("stalker-chase")
	assert(saw_telegraph)
	await _move(CombatBox.DATA.escape)
	assert(box.stalker.hunt.phase in [RiftStalkerState.Phase.RETURN,RiftStalkerState.Phase.QUIET])
	assert(box.submarine.hull_system.hull>0)
	await _move(CombatBox.DATA.refit)
	await _tap(KEY_P,JOY_BUTTON_START)
	# Exercise the same fixed-choice post-session UI as participants.
	var rating: Button
	for candidate: Node in box.options.find_children("*","Button",true,false):
		if (candidate as Button).text=="Finish / about right": rating = candidate as Button
	await _activate(rating)
	var report: Dictionary = box.observer.recorder.snapshot()
	assert(PlaytestReport.valid(report))
	var saved: Dictionary = box.observer.store.read_report(box.observer.store.directory.path_join(String(report.session_id)+".json"))
	assert(saved.error==OK)
	assert(saved.data.combat.rating=="about_right")
	assert(not box.observer.recorder.recording)
	assert(report.combat.torpedoes==1 and report.combat.stun_uses>=1 and report.combat.swarm_destroyed>=1)
	assert(report.combat.rating=="about_right")
	assert(report.combat.profile_active_seconds.weighty>0 and report.combat.profile_active_seconds.responsive>0)
	print("COMBAT_INPUT_PASS input=",("keyboard" if keyboard else "controller")," hull=",box.submarine.hull_system.hull," metrics=",JSON.stringify(report.combat))
	while captures_pending>0: await process_frame
	box.queue_free()
	for unused: int in range(4): await process_frame
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false,0)
	for unused: int in range(4): await process_frame
	# Accelerated frames can exit before the Dummy audio thread releases the
	# existing mixer's six loop playbacks. Allow a real audio-thread handoff.
	if DisplayServer.get_name()!="headless": OS.delay_msec(50)
	quit.call_deferred()
func _phase(phase: int) -> void:
	if phase==SwarmerState.Phase.TELEGRAPH and not saw_telegraph:
		saw_telegraph = true
		_capture("dash-telegraph")
func _tap(code: Key,button: JoyButton) -> void:
	var event: InputEvent
	if keyboard:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = code
		key.keycode = code
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
	if keyboard: (event as InputEventKey).pressed = false
	else: (event as InputEventJoypadButton).pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func _activate(button: Button) -> void:
	assert(button!=null and not button.disabled)
	for step: int in range(60):
		if root.gui_get_focus_owner()==button:
			await _tap(KEY_ENTER,JOY_BUTTON_A)
			return
		await _tap(KEY_TAB,JOY_BUTTON_RIGHT_SHOULDER)
	push_error("Combat option focus could not reach "+button.text)
	quit(1)
func _hold(value: Vector2) -> void:
	if keyboard:
		for pair: Array in [[KEY_A,value.x<0],[KEY_D,value.x>0],[KEY_W,value.y<0],[KEY_S,value.y>0]]:
			var key: InputEventKey = InputEventKey.new()
			key.keycode = pair[0]
			key.physical_keycode = pair[0]
			key.pressed = pair[1]
			Input.parse_input_event(key)
	else:
		var encoded: Vector2 = value
		if value.length()<1 and not value.is_zero_approx(): encoded = value.normalized()*lerpf(InputMap.action_get_deadzone("move_left"),1,value.length())
		for axis: int in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var joy: InputEventJoypadMotion = InputEventJoypadMotion.new()
			joy.axis = axis
			joy.axis_value = encoded.x if axis==JOY_AXIS_LEFT_X else encoded.y
			Input.parse_input_event(joy)
	Input.flush_buffered_events()
func _move(target: Vector2) -> void:
	for tick: int in range(4800):
		var error: Vector2 = target-box.submarine.global_position
		var velocity: Vector2 = box.submarine.velocity
		var steering: Vector2 = (error*1.1-velocity*0.7).limit_length(160)/box.submarine.motion.maximum_speed
		if keyboard:
			var stopping: Vector2 = Vector2(velocity.x*absf(velocity.x),velocity.y*absf(velocity.y))/(2*box.submarine.motion.acceleration)
			var projected: Vector2 = error-stopping-velocity*0.1
			steering = Vector2(signf(projected.x) if absf(projected.x)>12 else 0,signf(projected.y) if absf(projected.y)>12 else 0)
		_hold(steering)
		await physics_frame
		if error.length()<18 and velocity.length()<15:
			_hold(Vector2.ZERO)
			await _frames(20)
			return
	_hold(Vector2.ZERO)
	push_error("Combat input course failed at "+str(target)+" actual="+str(box.submarine.global_position))
	quit(1)
func _face_right() -> void:
	_hold(Vector2.RIGHT)
	for tick: int in range(120):
		await physics_frame
		if box.submarine.velocity.x>30: break
	_hold(Vector2.ZERO)
	await _frames(24)
	assert(box.submarine.facing_direction()==Vector2.RIGHT)
func _fire() -> void:
	if keyboard: await _tap(KEY_SPACE,JOY_BUTTON_INVALID)
	else:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_TRIGGER_RIGHT
		event.axis_value = 1
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(3)
		event.axis_value = 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _frames(90)
func _measure(id: String) -> void:
	var motion: SubmarineMotion = box.submarine.motion
	var expected: Dictionary = CombatHandling.predicted(motion)
	box.submarine.global_position = CombatBox.DATA.measurement_start
	box.submarine.velocity = Vector2.ZERO
	await _frames(2)
	_hold(Vector2.RIGHT)
	var elapsed: float = 0
	var first90: float = -1
	for tick: int in range(600):
		await physics_frame
		elapsed += 1.0/60
		if first90<0 and box.submarine.velocity.x>=motion.maximum_speed*0.9: first90 = elapsed
		if box.submarine.velocity.x>=motion.maximum_speed: break
	assert(first90>0 and absf(first90-expected.to_90_seconds)<=2.0/60+0.0001)
	var top: float = box.submarine.velocity.x
	var at: Vector2 = box.submarine.global_position
	_hold(Vector2.ZERO)
	for tick: int in range(1200):
		await physics_frame
		if box.submarine.velocity.is_zero_approx(): break
	var distance: float = box.submarine.global_position.distance_to(at)
	assert(absf(distance-expected.stop_distance)<=motion.maximum_speed/60+0.01)
	box.submarine.global_position = CombatBox.DATA.measurement_start
	box.submarine.velocity = Vector2.ZERO
	_hold(Vector2.RIGHT)
	for tick: int in range(600):
		await physics_frame
		if box.submarine.velocity.x>=motion.maximum_speed: break
	_hold(Vector2.LEFT)
	elapsed = 0
	var facing_seconds: float = -1
	for tick: int in range(600):
		await physics_frame
		elapsed += 1.0/60
		if facing_seconds<0 and box.submarine.facing_direction()==Vector2.LEFT: facing_seconds = elapsed
		if box.submarine.velocity.x<=-motion.maximum_speed*0.9: break
	assert(absf(elapsed-expected.turn_90_seconds)<=2.0/60+0.0001)
	assert(facing_seconds>0 and absf(facing_seconds-expected.facing_reverse_seconds)<=2.0/60+0.0001)
	_hold(Vector2.ZERO)
	await _frames(480)
	print("COMBAT_HANDLING_INPUT ",id," to90=",first90," coast=",distance," reverse90=",elapsed," facing=",facing_seconds," top=",top)
func _capture(label: String) -> void:
	if captures.is_empty(): return
	captures_pending += 1
	await _frames(2)
	var camera: Camera2D = box.submarine.get_node("Camera2D") as Camera2D
	var old_zoom: Vector2 = camera.zoom
	if label=="arena": camera.zoom = Vector2.ONE*minf(float(root.size.x)/CombatBox.DATA.bounds.size.x,float(root.size.y)/CombatBox.DATA.bounds.size.y)
	camera.reset_smoothing()
	camera.reset_physics_interpolation()
	camera.force_update_scroll()
	await process_frame
	RenderingServer.force_draw(false,0)
	var picture: Image = root.get_texture().get_image()
	assert(picture.get_size()==root.size)
	var saved: Error = picture.save_png(captures.path_join(label+("-800x600" if small else "-1280x800")+".png"))
	assert(saved==OK)
	camera.zoom = old_zoom
	camera.reset_smoothing()
	camera.force_update_scroll()
	captures_pending -= 1
