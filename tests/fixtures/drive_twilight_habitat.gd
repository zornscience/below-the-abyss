extends "res://tests/fixtures/drive_chapter_handoff.gd"
## Complete chapter/deployment by real input, then deliberately test thermal exposure.
func _after_deployment() -> bool:
	var habitat: TwilightHabitat = _scene.journey.habitat
	var records: Dictionary = _scene.saves.progress_snapshot()
	await _move(Vector2(29100,1440))
	var eel_view: Vector2 = habitat.fauna[0].global_position+Vector2(0,-130)
	eel_view.x = clampf(eel_view.x,28400,29700)
	eel_view.y = clampf(eel_view.y,1380,1900)
	await _move(eel_view)
	await _capture("deep-eel-gallery")
	await _move(Vector2(29000,2900))
	await _move(Vector2(29100,3120))
	await _capture("historic-whaler")
	await _move(Vector2(29400,3200))
	await _move(Vector2(29750,3520))
	var vent: ThermalVent = habitat.vents[0]
	await _wait_phase(vent,ThermalVentState.Phase.WARNING)
	await _capture("vent-warning")
	var safe_hull: float = _scene.submarine.hull_system.hull
	await _wait_phase(vent,ThermalVentState.Phase.ERUPTING)
	await _frames(60)
	assert(is_equal_approx(_scene.submarine.hull_system.hull,safe_hull))
	await _capture("vent-eruption-safe-bypass")
	await _move(vent.to_global(vent.configuration.plume.get_center()))
	await _wait_phase(vent,ThermalVentState.Phase.WARNING)
	await _capture("vent-clear-the-jet")
	var before: float = _scene.submarine.hull_system.hull
	await _wait_phase(vent,ThermalVentState.Phase.ERUPTING)
	await _frames(60)
	assert(_scene.submarine.hull_system.hull<before-3.0)
	assert(String(_scene.submarine.hull_system.last_damage_source).begins_with("thermal/"))
	await _capture("thermal-hull-damage")
	await _tap(JOY_BUTTON_START)
	var clock: float = vent.model.clock
	var damaged: float = _scene.submarine.hull_system.hull
	await _frames(60)
	assert(is_equal_approx(vent.model.clock,clock))
	assert(is_equal_approx(_scene.submarine.hull_system.hull,damaged))
	await _tap(JOY_BUTTON_START)
	await _move(Vector2(29750,3200))
	await _move(Vector2(30000,2900))
	await _move(Vector2(33800,2870))
	var observation: Vector2 = habitat.fauna[1].global_position+Vector2(0,-180)
	observation.x = clampf(observation.x,33580,34920)
	observation.y = clampf(observation.y,2770,3100)
	await _move(observation)
	await _capture("squid-patrol")
	var reactions: Array[int] = []
	var reacted: Callable = func(state: int) -> void: reactions.append(state)
	habitat.fauna[1].brain.state_changed.connect(reacted)
	await _tap(JOY_BUTTON_X)
	await _frames(10)
	print("TWILIGHT_SONAR_REACTION states=",reactions," accepted=",habitat.fauna[1].brain.snapshot().event_id," at=",_scene.submarine.global_position)
	if CreatureState.State.INVESTIGATE not in reactions:
		push_error("The actual sonar input did not produce an eligible squid investigation.")
		quit(1)
		return true
	habitat.fauna[1].brain.state_changed.disconnect(reacted)
	await _capture("squid-investigates-sonar")
	await _move(Vector2(35800,2900))
	await _capture("mineral-garden-and-east-vent")
	await _move(Vector2(35800,1400))
	await _move(Vector2(37700,1760))
	var jelly_view: Vector2 = habitat.fauna[2].global_position+Vector2(-220,40)
	jelly_view.x = clampf(jelly_view.x,37480,38320)
	jelly_view.y = clampf(jelly_view.y,1660,1940)
	await _move(jelly_view)
	await _capture("jelly-drift")
	await _move(Vector2(35800,1400))
	await _move(TwilightShelfLayout.SPAWN)
	var current: Dictionary = _scene.saves.progress_snapshot()
	for field: String in ["research","missions","upgrades"]: assert(current[field]==records[field])
	for id: String in records.discoveries: assert(id in current.discoveries)
	var eligible: Array[String] = []
	for id: StringName in TwilightShelfData.OPTIONAL_SURVEY: eligible.append(String(id)+"-poi")
	for id: String in current.discoveries:
		if id not in records.discoveries: assert(id in eligible)
	# A real active ping may discover an added optional subject at wavefront arrival;
	# it must never scan it, alter missions/upgrades or erase an earlier discovery.
	await _tap(JOY_BUTTON_START)
	await _activate(_scene.route_menu.get_node("%SaveExpedition") as Control)
	assert(_scene.saves._state.player.hull<100)
	assert(_scene.saves._state.player.battery<99)
	print("TWILIGHT_HABITAT_WALK_PASS input=",("keyboard" if _keyboard else "controller")," hull=",_scene.saves._state.player.hull," research_missions_upgrades_preserved=true optional_sonar_discoveries=",current.discoveries.size()-records.discoveries.size()," shots=",_shots)
	await _finish_process()
	return true
func _wait_phase(vent: ThermalVent,desired: ThermalVentState.Phase) -> void:
	for index: int in range(1500):
		if vent.model.phase()==desired: return
		await physics_frame
	push_error("Vent did not reach requested phase during normal simulation.")
	quit(1)
func _capture(name: String) -> void:
	if not _captures.is_empty():
		# Normal rendering continuously settles text/layout. On-demand software
		# capture needs a warm-up draw before reading the next complete viewport.
		await process_frame
		RenderingServer.force_draw(false,0.0)
		await process_frame
	await super._capture(name)
	if not _captures.is_empty():
		print("TWILIGHT_RENDER_SAMPLE ",name," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," texture_bytes=",Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
