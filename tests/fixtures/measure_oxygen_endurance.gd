extends SceneTree
## Investigation probe: measure full-to-empty oxygen in the real campaign scene at normal travel.
## The vessel patrols between two authored open-water waypoints under real input actions
## (full stick deflection) until oxygen reaches zero. Nothing is derived from the resource profile.
## Usage (one region per process; do not run alongside another Godot job):
##   godot --headless --path . --script res://tests/fixtures/measure_oxygen_endurance.gd -- sunlit
##   godot --headless --path . --script res://tests/fixtures/measure_oxygen_endurance.gd -- twilight
## Without --fixed-fps the physics clock follows the wall clock, so wall_s is real elapsed time.
## Prints OXYGEN_ENDURANCE_PASS on success; any pause, hull loss or stall is a failure.
var game: ShelfPrototype
var region: String = "sunlit"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): region = args[0]
	call_deferred("run")


func fail(message: String) -> void:
	for action: String in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	push_error("OXYGEN_ENDURANCE_FAIL "+message)
	quit(1)


func run() -> void:
	if region not in ["sunlit","twilight"]:
		fail("unknown region "+region)
		return
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://oxygen-endurance-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child(game)
	for tick: int in range(5): await physics_frame
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	var waypoints: Array[Vector2] = [SunlitSurveyData.MAIN_ROUTE[0],SunlitSurveyData.MAIN_ROUTE[1]]
	if region=="twilight":
		# Commissioning harness shared with drive_depth_gate.gd; the deployment itself is real.
		game.story.apply_choice(LightBloomEncounter.COLLECT)
		game.bloom.reset_session()
		game.discoveries.discover(SunlitShallowsData.POI,&"endurance/buoy")
		game.submarine.global_position = SunlitSurveyData.BUOY
		var records: Array[StringName] = game.research.completed_ids()
		records.append(SunlitShallowsData.BUOY)
		game.saves.commit_research_checkpoint(records)
		game.research.restore_completed(records)
		game.missions.reconcile()
		if game.saves.finish_sunlit_return()!=OK or game.saves.transfer_chapter("twilight",true)!=OK:
			fail("twilight commissioning failed")
			return
		waypoints = [TwilightShelfLayout.WEST_LOOP[1],TwilightShelfLayout.SPAWN]
	game.revision.ui.title_page.hide()
	game.revision.ui.radio_page.hide()
	game.route_layer.hide()
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	if pools.oxygen!=pools.max_oxygen:
		fail("did not start from full oxygen: "+str(pools.oxygen))
		return
	print("OXYGEN_ENDURANCE_START region=",region," profile=",pools.configuration.resource_path," oxygen=",pools.oxygen," battery=",pools.battery," hull=",game.submarine.hull_system.hull," at=",game.submarine.global_position," physics_ticks=",Engine.physics_ticks_per_second)
	game.resume_route()
	var start_usec: int = Time.get_ticks_usec()
	var sim_seconds: float = 0.0
	var frames: int = 0
	var paused_frames: int = 0
	var full_thrust_frames: int = 0
	var distance: float = 0.0
	var legs: int = 0
	var target: int = 0
	var last: Vector2 = game.submarine.global_position
	var hull_start: float = game.submarine.hull_system.hull
	var next_report: float = 300.0
	var deadzone: float = InputMap.action_get_deadzone("move_left")
	while pools.oxygen>0.0:
		if not game.submarine.is_physics_processing():
			paused_frames += 1
			fail("simulation paused during the measurement (frame "+str(frames)+")")
			return
		var offset: Vector2 = waypoints[target]-game.submarine.global_position
		if offset.length()<120.0:
			target = 1-target
			legs += 1
			offset = waypoints[target]-game.submarine.global_position
		# Full deflection toward the waypoint; damp only the perpendicular drift so the
		# vessel stays on the open-water line instead of grazing terrain.
		var desired: Vector2 = offset.normalized()-game.submarine.velocity.slide(offset.normalized())/240.0
		var direction: Vector2 = desired.normalized()
		for pair: Array in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if pair[1]>deadzone: Input.action_press(pair[0],minf(1.0,pair[1]))
			else: Input.action_release(pair[0])
		await physics_frame
		frames += 1
		sim_seconds += game.submarine.get_physics_process_delta_time()
		if Input.get_vector("move_left","move_right","move_up","move_down").length()>=0.99: full_thrust_frames += 1
		distance += game.submarine.global_position.distance_to(last)
		last = game.submarine.global_position
		if game.submarine.hull_system.hull<hull_start:
			fail("hull damaged during normal travel: "+str(game.submarine.hull_system.hull)+" at "+str(last)+" source="+String(game.submarine.hull_system.last_damage_source))
			return
		if sim_seconds>=next_report:
			next_report += 300.0
			print("OXYGEN_ENDURANCE_PROGRESS region=",region," sim_s=%.1f wall_s=%.1f oxygen=%.3f battery=%.3f legs=%d at=%s" % [sim_seconds,(Time.get_ticks_usec()-start_usec)/1000000.0,pools.oxygen,pools.battery,legs,str(last)])
		if frames>60*60*60*3:
			fail("oxygen did not reach zero within three simulated hours")
			return
	var wall: float = (Time.get_ticks_usec()-start_usec)/1000000.0
	for action: String in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	print("OXYGEN_ENDURANCE region=%s wall_s=%.2f sim_s=%.2f wall_min=%.2f frames=%d full_thrust_pct=%.1f distance_u=%.0f legs=%d battery_end=%.3f hull_end=%.1f paused_frames=%d" % [region,wall,sim_seconds,wall/60.0,frames,100.0*full_thrust_frames/maxf(1,frames),distance,legs,pools.battery,game.submarine.hull_system.hull,paused_frames])
	print("OXYGEN_ENDURANCE_PASS")
	quit()
