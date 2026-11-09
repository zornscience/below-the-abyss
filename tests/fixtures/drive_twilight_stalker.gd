extends "res://tests/fixtures/drive_twilight_expedition.gd"
var _quiet: bool = false
var _heard_pings: int = 0
var _met: bool = false
func _tap(button: JoyButton) -> void:
	if _quiet and _scene!=null and _scene.journey!=null and _scene.journey.active() and button==JOY_BUTTON_X: return
	await super._tap(button)
func _observe() -> void:
	if not _quiet or _scene==null or _scene.journey==null or not _scene.journey.active(): return
	var actor: RiftStalker = _scene.journey.hunt.actors[0]
	if actor.hunt.phase!=RiftStalkerState.Phase.QUIET or actor.global_position.distance_to(_scene.submarine.global_position)<TwilightHunt.PROFILE.sense_radius: _met = true
func _cable_records() -> void:
	if _quiet:
		for index: int in [3,2,1,0]: await _move(TwilightShelfLayout.WEST_LOOP[index])
		await _move(TwilightShelfLayout.EAST_LOOP[1])
		for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one"]:
			await _move(TwilightShelfData.record(id).at)
			await _record(id)
	else: await super._cable_records()
func _after_deployment() -> bool:
	_quiet = OS.get_cmdline_user_args().has("--quiet-stalker")
	if _quiet:
		_scene.submarine.sonar.pulse_emitted.connect(func(_event: AcousticEvent) -> void: _heard_pings += 1)
		physics_frame.connect(_observe)
		return await super._after_deployment()
	var hunt: TwilightHunt = _scene.journey.hunt
	var actor: RiftStalker = hunt.actors[0]
	for index: int in range(1,5): await _move(TwilightShelfLayout.INNER_LOOP[index])
	await _move(actor.global_position-Vector2(TwilightHunt.PROFILE.sense_radius*0.5,0))
	await _tap(JOY_BUTTON_X)
	for tick: int in range(900):
		await physics_frame
		if actor.hunt.phase==RiftStalkerState.Phase.WARNING: break
	if actor.hunt.phase!=RiftStalkerState.Phase.WARNING:
		push_error("STALKER_ROUTE_FAIL no warning after real ping")
		quit(1)
		return true
	await _capture("stalker-warning")
	for tick: int in range(300):
		await physics_frame
		if actor.hunt.phase==RiftStalkerState.Phase.PURSUE: break
	if actor.hunt.phase!=RiftStalkerState.Phase.PURSUE:
		push_error("STALKER_ROUTE_FAIL no pursuit")
		quit(1)
		return true
	await _capture("stalker-pursuit")
	var exit: Vector2 = Vector2(_scene.submarine.global_position.x,TwilightHunt.PROFILE.navigation_bounds.end.y+TwilightHunt.PROFILE.body_radius*4)
	await _move(exit)
	if actor.hunt.phase not in [RiftStalkerState.Phase.RETURN,RiftStalkerState.Phase.QUIET] or _scene.submarine.hull_system.hull<=0:
		push_error("STALKER_ROUTE_FAIL escape")
		quit(1)
		return true
	print("STALKER_ESCAPE_PASS input=",("keyboard" if _keyboard else "controller")," hull=",_scene.submarine.hull_system.hull)
	await super._finish_process()
	return true
func _finish_process() -> void:
	if _quiet:
		if _met or _heard_pings!=0 or not _scene.journey.expedition.concluded():
			push_error("STALKER_QUIET_ROUTE_FAIL met=",_met," pings=",_heard_pings)
			quit(1)
			return
		print("STALKER_QUIET_CHAPTER_PASS no_pings=true no_encounter=true")
	await super._finish_process()
