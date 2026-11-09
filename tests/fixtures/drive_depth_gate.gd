extends SceneTree
var game: ShelfPrototype
var exposure: float = 0.0
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for tick: int in range(n): await physics_frame
func move_to(target: Vector2) -> bool:
	for tick: int in range(3000):
		var offset: Vector2 = target-game.submarine.global_position
		if offset.length()<24 and game.submarine.velocity.length()<30: return true
		var desired: Vector2 = (offset*1.1-game.submarine.velocity*0.7).limit_length(240.0)/240.0
		var deadzone: float = InputMap.action_get_deadzone("move_left")
		var direction: Vector2 = desired.normalized()*lerpf(deadzone,1.0,desired.length()) if not desired.is_zero_approx() else Vector2.ZERO
		for pair: Array in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			Input.action_press(pair[0],maxf(0,pair[1]))
		await physics_frame
		if game.submarine.damage_system.warning_state==SubmarineDamageSystem.WarningState.EXCEEDED: exposure += 1.0/60.0
		if game.submarine.hull_system.hull<=0: return false
	push_error("DEPTH_ROUTE_TIMEOUT")
	return false
func run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta059-route-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child(game)
	await frames(5)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	game.story.apply_choice(LightBloomEncounter.COLLECT)
	game.bloom.reset_session()
	game.discoveries.discover(SunlitShallowsData.POI,&"route/buoy")
	game.submarine.global_position = SunlitSurveyData.BUOY
	var records: Array[StringName] = game.research.completed_ids()
	records.append(SunlitShallowsData.BUOY)
	game.saves.commit_research_checkpoint(records)
	game.research.restore_completed(records)
	game.missions.reconcile()
	var finished: Error = game.saves.finish_sunlit_return()
	var deployed: Error = game.saves.transfer_chapter("twilight",true)
	if finished!=OK or deployed!=OK:
		push_error("Depth route commissioning failed")
		quit(1)
		return
	game.revision.ui.title_page.hide()
	game.route_layer.hide()
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	for rank: int in [0,1,2]:
		game.submarine.set_simulation_enabled(false)
		game.submarine.global_position = TwilightShelfLayout.SPAWN
		game.submarine.velocity = Vector2.ZERO
		game.submarine.hull_system.restore_snapshot(100)
		var tree: ResearchTree = game.revision.tree
		game.revision.campaign.ranks.hull = rank
		game.upgrades.reapply()
		game.submarine.damage_system.advance(0,game.region.depth_at_world(gate.approach),game.submarine.hull_system)
		exposure = 0.0
		game.resume_route()
		for point: Vector2 in TwilightShelfLayout.WEST_LOOP.slice(1,4):
			if not await move_to(point):
				push_error("Safe shelf approach was unreachable")
				quit(1)
				return
		for point: Vector2 in gate.crossing():
			if not await move_to(point):
				push_error("DEPTH_ROUTE_FAIL rank="+str(rank)+" exposure="+str(exposure)+" pos="+str(game.submarine.global_position))
				quit(1)
				return
		for action: String in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
		if rank==gate.gate_rank and game.submarine.hull_system.hull!=100.0:
			push_error("Rated crossing took damage")
			quit(1)
			return
		print("DEPTH_CROSSING rank=",rank," unsafe_seconds=",exposure," hull=",game.submarine.hull_system.hull)
	game.revision.campaign.ranks.hull = 0
	game.upgrades.reapply()
	game.submarine.hull_system.restore_snapshot(100)
	game.submarine.global_position = gate.lower_left
	game.submarine.velocity = Vector2.ZERO
	for tick: int in range(1800):
		await physics_frame
		if game.journey.depth_gate.pending: break
	if not game.journey.depth_gate.pending or game.saves._state.player.hull!=0.0:
		push_error("Lingering did not produce a durable hull failure")
		quit(1)
		return
	var battery: float = game.submarine.resource_system.battery
	var oxygen: float = game.submarine.resource_system.oxygen
	game.journey.depth_gate.respawn()
	if game.journey.depth_gate.pending or game.submarine.resource_system.battery!=battery or game.submarine.resource_system.oxygen!=oxygen:
		push_error("Respawn did not preserve supplies")
		quit(1)
		return
	game.submarine.set_simulation_enabled(false)
	print("DEPTH_LINGER_RESPAWN_PASS")
	print("DEPTH_ROUTE_PASS")
	quit()
