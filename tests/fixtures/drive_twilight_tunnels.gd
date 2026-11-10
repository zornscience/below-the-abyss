extends "res://tests/fixtures/drive_chapter_handoff.gd"
## Seed a completed Sunlit checkpoint, then use real inputs for all tunnel piloting,
## scans, shots, saving, and a separate-process Continue. No authored coordinates here.
var _impacts: int = 0
var _last_hull: float = 100.0
var _losses: Dictionary = {}
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	_keyboard = _argument("--input","controller")=="keyboard"
	_small = OS.get_cmdline_user_args().has("--small")
	_captures = OS.get_environment("BTA_EVIDENCE_DIR")
	_outcome = "tunnels"
	var path: String = "user://"+_argument("--profile","bta061-"+str(Time.get_ticks_usec()))+".json"
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = path
	_scene.expedition_path = path+".expedition.json"
	root.add_child(_scene)
	root.size = Vector2i(800,600) if _small else Vector2i(1280,800)
	await _frames(8)
	var onboarding: Dictionary = _scene.settings.snapshot().onboarding
	onboarding.enabled = false
	_scene.settings.set_onboarding(onboarding)
	var comfort: Dictionary = _scene.settings.snapshot().accessibility
	comfort.reduced_motion = true
	comfort.reduced_flashing = true
	comfort.reduced_particles = true
	_scene.settings.set_accessibility(comfort)
	var audio: Dictionary = _scene.settings.snapshot().audio
	audio.muted = true
	_scene.settings.set_audio(audio)
	if OS.get_cmdline_user_args().has("--tunnel-resume"):
		await _activate(_control("Begin"))
		await _wait_transfer()
		assert(_scene.excavation.snapshot().size()==4)
		assert(_scene.torpedoes.battery_cost()==ChapterJourney.ACTION_COSTS.torpedo_battery)
		for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
			await _travel(profile.approach)
			await _travel(profile.world_path(profile.shortcut))
			await _move(profile.origin+profile.main[-1],true)
			await _travel(profile.return_path)
		print("TUNNEL_CONTINUE_INPUT_PASS device=",("keyboard" if _keyboard else "controller")," cuts=",_scene.excavation.snapshot().size())
		await _finish_process()
		return
	_scene.chapter.start()
	_scene.chapter.launch()
	_scene.submarine.set_simulation_enabled(false)
	var choice: Error = _scene.story.apply_choice(LightBloomEncounter.COLLECT)
	assert(choice==OK)
	_scene.bloom.reset_session()
	var discovery: Error = _scene.discoveries.discover(SunlitShallowsData.POI,&"tunnel-fixture/buoy")
	assert(discovery==OK)
	_scene.submarine.global_position = SunlitSurveyData.BUOY
	var records: Array[StringName] = _scene.research.completed_ids()
	records.append(SunlitShallowsData.BUOY)
	var committed: Error = _scene.saves.commit_research_checkpoint(records)
	assert(committed==OK)
	_scene.research.restore_completed(records)
	_scene.missions.reconcile()
	var finished: Error = _scene.saves.finish_sunlit_return()
	assert(finished==OK)
	var deployed: Error = _scene.saves.transfer_chapter("twilight",true)
	assert(deployed==OK)
	_scene.revision.ui.title_page.hide()
	_scene.revision.ui.radio_page.hide()
	_scene.resume_route()
	_last_hull = _scene.submarine.hull_system.hull
	_scene.submarine.hull_system.hull_changed.connect(_hull_changed)
	_scene.submarine.damage_system.collision_damage_applied.connect(func(_amount: float,_speed: float) -> void: _impacts += 1)
	var original_xp: Dictionary = _scene.revision.campaign.science.duplicate(true)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		print("TUNNEL_INPUT_BEGIN ",profile.stable_id)
		await _travel(profile.approach)
		await _tap(JOY_BUTTON_X)
		await _capture(String(profile.stable_id)+"-entrance")
		var before: int = _impacts
		for at: Vector2 in profile.main:
			await _move(profile.origin+at,true)
			if at==profile.squeeze[0]: await _wait_window(profile)
			if at==profile.squeeze[1]: await _capture(String(profile.stable_id)+"-squeeze")
			if at==profile.branch[0]:
				await _travel(profile.world_path(profile.branch))
				await _interact()
				await _frames(340)
				assert(_scene.research.is_completed(profile.payoff_id))
				await _capture(String(profile.stable_id)+"-dead-end")
				var reverse: PackedVector2Array = profile.world_path(profile.branch)
				reverse.reverse()
				await _travel(reverse)
		assert(_impacts==before,"Careful input must clear the squeeze and dead end without impact damage")
		await _travel(profile.return_path)
		await _travel(profile.approach)
		await _move(profile.origin+profile.fire_from,true)
		# Both authored gates face the actual horizontal torpedo launcher.
		await _face_right()
		await _tap(JOY_BUTTON_X)
		await _capture_gate(profile,"before")
		var battery: float = _scene.submarine.resource_system.battery
		await _fire()
		await _fire()
		assert(_scene.submarine.resource_system.battery<battery-ChapterJourney.ACTION_COSTS.torpedo_battery*2)
		await _capture_gate(profile,"after")
		await _travel(profile.world_path(profile.shortcut))
		# Careless full thrust into the dead end exercises existing collision rules.
		await _move(profile.origin+profile.branch[0],true)
		var hull: float = _scene.submarine.hull_system.hull
		var delta: Vector2 = (profile.branch[-1]-profile.branch[0]).normalized()
		_hold(delta)
		await _frames(180)
		_release_motion()
		await _frames(20)
		assert(_scene.submarine.hull_system.hull<hull,"Reckless speed must cost hull through existing impacts")
		print("TUNNEL_RECKLESS_IMPACT ",profile.stable_id," hull_cost=",hull-_scene.submarine.hull_system.hull)
		await _move(profile.origin+profile.branch[0],true)
		# Follow the remaining main path to the open shelf, never cross a solid corner.
		var leaving: bool = false
		for at: Vector2 in profile.main:
			if at==profile.branch[0]: leaving = true
			if leaving: await _move(profile.origin+at,true)
		await _travel(profile.return_path)
	assert(_scene.revision.campaign.science==original_xp)
	assert(_scene.excavation.snapshot().size()==4)
	await _tap(JOY_BUTTON_START)
	await _activate(_scene.route_menu.get_node("%SaveExpedition") as Control)
	assert(_scene.saves._state.terrain.size()==4)
	print("TUNNEL_DAMAGE_TOTALS ",JSON.stringify(_losses))
	print("TUNNEL_INPUT_PASS device=",("keyboard" if _keyboard else "controller")," cuts=",_scene.excavation.snapshot().size()," hull=",_scene.submarine.hull_system.hull," battery=",_scene.submarine.resource_system.battery)
	await _finish_process()
func _travel(path: PackedVector2Array) -> void:
	for at: Vector2 in path: await _move(at,true)
func _face_right() -> void:
	_hold(Vector2.RIGHT)
	for tick: int in range(60):
		await physics_frame
		if _scene.submarine.velocity.x>30: break
	assert(_scene.submarine.velocity.x>30)
	_release_motion()
	await _frames(24)
	assert(_scene.submarine.facing_direction()==Vector2.RIGHT)
func _hold(direction: Vector2) -> void:
	if _keyboard:
		for pair: Array in [[KEY_A,direction.x<0],[KEY_D,direction.x>0],[KEY_W,direction.y<0],[KEY_S,direction.y>0]]:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = pair[0]
			event.physical_keycode = pair[0]
			event.pressed = pair[1]
			Input.parse_input_event(event)
	else:
		for axis: int in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
			event.axis = axis
			event.axis_value = direction.x if axis==JOY_AXIS_LEFT_X else direction.y
			Input.parse_input_event(event)
	Input.flush_buffered_events()
func _wait_window(profile: TunnelProfile) -> void:
	if profile.vent_id.is_empty(): return
	var vent: ThermalVent = _scene.journey.tunnels.vents[0]
	# Wait outside the jet, show the existing timed warning, then use the next quiet window.
	for tick: int in range(int(vent.configuration.cycle_seconds()*60)+1):
		if vent.model.phase()==ThermalVentState.Phase.WARNING:
			await _capture("vent-warning")
			break
		await physics_frame
	var eruption_captured: bool = false
	for tick: int in range(int(vent.configuration.cycle_seconds()*60)+1):
		if not eruption_captured and vent.model.phase()==ThermalVentState.Phase.ERUPTING:
			eruption_captured = true
			await _capture("vent-erupting")
		if vent.model.phase()==ThermalVentState.Phase.QUIET and vent.model.clock<1.0: break
		await physics_frame
	assert(vent.model.phase()==ThermalVentState.Phase.QUIET)
	await _capture("vent-quiet")
func _capture(label: String) -> void:
	if _captures.is_empty(): return
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	await _frames(4)
	camera.reset_physics_interpolation()
	camera.reset_smoothing()
	camera.force_update_scroll()
	await super._capture(label)

func _hull_changed(current: float,_maximum: float) -> void:
	var amount: float = _last_hull-current
	_last_hull = current
	if amount<=0: return
	var source: String = String(_scene.submarine.hull_system.last_damage_source)
	if not _losses.has(source): print("TUNNEL_DAMAGE_SOURCE ",source," at=",_scene.submarine.global_position)
	_losses[source] = float(_losses.get(source,0.0))+amount
func _finish_process() -> void:
	_scene.queue_free()
	# Native readbacks can retain a rendered frame beyond five physics ticks.
	# Let the deferred deletion and rendering submission finish before closing.
	for unused: int in range(4): await process_frame
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false,0.0)
	for unused: int in range(4): await process_frame
	quit()

func _capture_gate(profile: TunnelProfile,phase: String) -> void:
	if _captures.is_empty(): return
	# Walk closer for the native gate pair so the whole plug fits even at 800x600.
	# Keep the normal camera/HUD; return and face the authored firing position.
	var firing_at: Vector2 = _scene.submarine.global_position
	var hull: CapsuleShape2D = (_scene.submarine.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	var gate: Rect2 = profile.world_gate()
	var view: Vector2 = gate.get_center()-Vector2.RIGHT*(gate.size.x*0.5+hull.height*1.25)
	await _move(view,true)
	await _face_right()
	await _capture(String(profile.stable_id)+"-gate-"+phase)
	await _move(firing_at,true)
	await _face_right()
