extends GutTest
## Oxygen exhaustion probes. Probes 1 and 2 were flipped on purpose from the investigation
## (docs/investigations/oxygen-exhaustion.md, PR #52) to the approved behaviour: zero oxygen
## starts a 60 s life-support countdown (simulation time). Expiry or hull destruction leads
## to Halcyon recovery with a free full restock. Probe 3 is unchanged. Every probe asserts
## the behaviour it names, so it fails if that behaviour is absent.
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
## Long waits run the real driver with scaled simulation steps, reset in after_each.
const FAST: float = 8.0
var game: ShelfPrototype
var path: String
var pools: SubmarineResourceSystem
var flow: VesselRecoveryFlow


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://oxygen-probe-%d.json" % Time.get_ticks_usec()
	# Added directly to the tree (as in test_depth_respawn) so real input events reach the scene.
	game = MAIN.instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	pools = game.submarine.resource_system
	flow = game.journey.recovery


func after_each() -> void:
	Engine.time_scale = 1.0
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
	await get_tree().process_frame
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))


# ---------------------------------------------------------------- helpers

func _hide_pages() -> void:
	game.revision.ui.title_page.hide()
	game.revision.ui.radio_page.hide()
	game.revision.ui.dock_page.hide()
	game.route_layer.hide()


func _buoy_evidence() -> void:
	# Same commissioning harness as test_depth_respawn / test_chapter_journey.
	assert_eq(game.story.apply_choice(LightBloomEncounter.COLLECT),OK)
	game.bloom.reset_session()
	assert_eq(game.discoveries.discover(SunlitShallowsData.POI,&"probe/buoy"),OK)
	game.submarine.global_position = SunlitSurveyData.BUOY
	var records: Array[StringName] = game.research.completed_ids()
	records.append(SunlitShallowsData.BUOY)
	assert_eq(game.saves.commit_research_checkpoint(records),OK)
	game.research.restore_completed(records)
	game.missions.reconcile()


func _deploy_twilight() -> void:
	_buoy_evidence()
	assert_eq(game.saves.finish_sunlit_return(),OK)
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
	_hide_pages()
	game.submarine.set_simulation_enabled(false)
	assert_true(game.journey.active())
	assert_eq(pools.configuration,preload("res://resources/balance/twilight_resources.tres"))


func _place(at: Vector2) -> void:
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = at
	game.submarine.velocity = Vector2.ZERO
	game.submarine.reset_physics_interpolation()


## Drains the last `remaining` oxygen through the real per-physics-step drain while the
## vessel travels under real thrust input. Returns the number of physics frames taken.
func _travel_until_oxygen_zero(remaining: float, action: StringName, limit: int) -> int:
	assert_eq(pools.restore_snapshot(pools.battery,remaining),OK)
	_hide_pages()
	game.resume_route()
	assert_true(game.submarine.is_physics_processing(),"probe precondition: simulation running")
	Input.action_press(action)
	for frame: int in range(limit):
		await wait_physics_frames(1)
		if pools.oxygen<=0.0: return frame+1
	return limit


## Runs the real simulation (scaled steps) until recovery begins. Returns frames waited.
func _run_until_recovery(limit: int) -> int:
	Engine.time_scale = FAST
	for frame: int in range(limit):
		await wait_physics_frames(1)
		if flow.pending:
			Engine.time_scale = 1.0
			return frame+1
	Engine.time_scale = 1.0
	return limit


func _oxygen_gauge_state() -> String:
	return (game.hud.oxygen_gauge.get_node("%State") as Label).text


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _assert_recovered_checkpoint(region: String, progress: Dictionary) -> void:
	var saved: Dictionary = game.saves._state
	assert_eq(saved.size(),12,region+": schema 10 keeps twelve top-level fields")
	assert_eq(saved.player.position,[SunlitSurveyData.SPAWN.x,SunlitSurveyData.SPAWN.y],region+": checkpoint is at the Halcyon berth")
	assert_eq(saved.player.hull,game.submarine.hull_system.max_hull,region+": hull fully restored")
	assert_eq(saved.player.battery,pools.max_battery,region+": battery fully restored")
	assert_eq(saved.player.oxygen,pools.max_oxygen,region+": oxygen fully restored")
	assert_eq(saved.prototype.ammunition,TorpedoLauncher.CAPACITY,region+": torpedoes fully restored")
	assert_eq(game.torpedoes.ammunition,TorpedoLauncher.CAPACITY)
	assert_eq(pools.oxygen,pools.max_oxygen)
	assert_eq(pools.battery,pools.max_battery)
	assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull)
	for kind: String in ["discoveries","research","upgrades"]:
		for id: String in progress[kind]: assert_true(id in saved.progress[kind],region+": "+kind+" record kept: "+id)


## Zero oxygen in open water: the countdown starts, the vessel still travels, checkpoints
## refuse and name oxygen, and after the full grace the vessel is recovered at Halcyon.
func _assert_open_water_zero_starts_countdown(action: StringName, region: String) -> Dictionary:
	watch_signals(pools)
	watch_signals(flow)
	var hull: float = game.submarine.hull_system.hull
	var frames: int = await _travel_until_oxygen_zero(0.05,action,900)
	assert_lt(frames,900,region+": the real drain reaches zero")
	assert_eq(pools.oxygen,0.0,region+": clamped at exactly zero, never negative")
	assert_signal_emit_count(pools,"oxygen_depleted",1)
	await wait_physics_frames(2)
	assert_true(flow.countdown.running,region+": zero oxygen starts the life-support countdown")
	assert_eq(flow.countdown.grace_seconds,60.0,region+": authored grace is 60 s")
	assert_true(flow.warning.visible,region+": border and countdown text are shown")
	assert_true(flow.warning.label.text.begins_with("OXYGEN DEPLETED, LIFE SUPPORT "),flow.warning.label.text)
	var at: Vector2 = game.submarine.global_position
	var left: float = flow.countdown.remaining
	await wait_physics_frames(120)
	assert_true(game.submarine.is_physics_processing(),region+": the vessel keeps simulating during the countdown")
	assert_gt(game.submarine.global_position.distance_to(at),40.0,region+": vessel still moves under thrust during the countdown")
	assert_eq(game.submarine.hull_system.hull,hull,region+": zero oxygen deals no hull damage")
	assert_almost_eq(flow.countdown.remaining,left-2.0,0.1,region+": the countdown runs on simulation time")
	assert_false(flow.pending,region+": no recovery before the grace expires")
	assert_signal_not_emitted(flow,"recovery_started")
	assert_true(_oxygen_gauge_state().contains("EMPTY") or _oxygen_gauge_state().contains("DEPLETED"),region+": HUD gauge reads empty: "+_oxygen_gauge_state())
	Input.action_release(action)
	# Checkpoint writes still refuse at zero oxygen, and now say why.
	_place(game.submarine.global_position)
	assert_false(game.saves.safe_to_save(),region+": safe_to_save refuses at zero oxygen")
	assert_eq(game.saves.save_current(),ERR_UNAVAILABLE,region+": manual save refused at zero oxygen")
	assert_eq(game.saves.status,SaveCoordinator.OXYGEN_SAVE_REFUSAL,region+": the refusal names oxygen")
	assert_eq(game.saves.commit_research_checkpoint(game.research.completed_ids()),ERR_UNAVAILABLE,region+": scan-completion checkpoint refused at zero oxygen")
	assert_eq(pools.restore_snapshot(pools.battery,1.0),OK)
	assert_true(game.saves.safe_to_save(),region+": oxygen alone was the blocker (same pose, 1 unit restored)")
	game.resume_route()
	await wait_physics_frames(2)
	assert_false(flow.countdown.running,region+": oxygen above zero cancels the countdown")
	assert_false(flow.warning.visible,region+": the border clears when oxygen returns")
	# Back to zero: the full grace restarts, then recovery follows expiry.
	game.submarine.set_simulation_enabled(false)
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	var progress: Dictionary = game.saves.progress_snapshot()
	game.resume_route()
	await wait_physics_frames(2)
	assert_true(flow.countdown.running)
	assert_gt(flow.countdown.remaining,59.9,region+": a new depletion starts the full grace")
	var waited: int = await _run_until_recovery(900)
	assert_lt(waited,900,region+": life support expires and recovery begins")
	await get_tree().process_frame
	assert_true(flow.pending)
	assert_eq(flow.cause,VesselRecoveryFlow.CAUSE_OXYGEN)
	assert_signal_emit_count(flow,"recovery_started",1)
	assert_true(flow.panel.visible,region+": recovery card shown")
	assert_true(flow.backdrop.visible,region+": fade to black shown")
	assert_eq(flow.body.text,"LIFE SUPPORT FAILED. Oxygen ran out. Wick sent a distress beacon and Halcyon’s crew recovered Lantern-2. Hull, battery, oxygen and torpedoes are restored. The unfinished scan was cancelled. All records, discoveries and choices are kept.")
	assert_eq(flow.confirm.text,"Continue at Halcyon")
	assert_false(game.submarine.is_physics_processing(),region+": the card freezes the simulation")
	assert_true(flow.committed,region+": recovery checkpoint written before the card is dismissed")
	_assert_recovered_checkpoint(region,progress)
	# The second zero was set directly (restore_snapshot), not drained: no second signal.
	assert_signal_emit_count(pools,"oxygen_depleted",1)
	return progress


# ---------------------------------------------------------------- probe 1: open water

func test_probe1_sunlit_open_water_zero_oxygen_counts_down_then_recovers_at_halcyon() -> void:
	assert_false(game.journey.active())
	_place(SunlitSurveyData.MAIN_ROUTE[0])
	await _assert_open_water_zero_starts_countdown(&"move_right","Sunlit")
	assert_eq(game.saves._state.journey.phase,"sunlit","Sunlit recovery stays in the Sunlit chapter")
	await _press(&"ui_accept")
	assert_false(flow.pending,"Enter / A continues")
	assert_false(flow.panel.visible)
	assert_true(game.submarine.is_physics_processing(),"Sunlit: piloting resumes at the Halcyon berth")
	assert_eq(game.submarine.global_position,SunlitSurveyData.SPAWN)


func test_probe1_twilight_open_water_zero_oxygen_counts_down_then_recovers_at_halcyon_refit() -> void:
	_deploy_twilight()
	_place(TwilightShelfLayout.SPAWN)
	await _assert_open_water_zero_starts_countdown(&"move_left","Twilight")
	assert_eq(game.saves._state.journey.phase,"refit","Twilight recovery reuses the Halcyon refit transfer")
	assert_true(game.journey.at_station())
	await _press(&"ui_accept")
	assert_false(flow.pending)
	assert_true(game.revision.ui.dock_page.visible,"Twilight: the Halcyon refit page is shown")
	assert_false(game.submarine.is_physics_processing())


func test_probe1_sunlit_zero_oxygen_blocks_buoy_scan_and_offscreen_finish_with_oxygen_named() -> void:
	assert_eq(game.story.apply_choice(LightBloomEncounter.COLLECT),OK)
	game.bloom.reset_session()
	_hide_pages()
	_place(SunlitSurveyData.BUOY)
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(2.0)
	assert_eq(game.discoveries.state_of(SunlitShallowsData.POI),DiscoveryRegistry.State.DISCOVERED)
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	game.resume_route()  # the scanner is suspended while the simulation is paused
	assert_eq(game.submarine.scanner.request_scan(SunlitShallowsData.BUOY),OK,"a scan can START at zero oxygen")
	game.submarine.scanner.advance(4.0)
	assert_false(game.research.is_completed(SunlitShallowsData.BUOY),"but it is not recorded")
	assert_eq(game.submarine.scanner.snapshot().text,ScientificScanner.OXYGEN_REFUSAL,"player sees: "+String(game.submarine.scanner.snapshot().text))
	assert_true(game.submarine.scanner.snapshot().text.contains("NOT RECORDED"))
	assert_true(game.submarine.scanner.snapshot().text.contains("Oxygen depleted"),"the scan refusal names oxygen")
	# Same pose, oxygen restored: the identical scan is recorded.
	assert_eq(pools.restore_snapshot(pools.battery,1.0),OK)
	assert_eq(game.submarine.scanner.request_scan(SunlitShallowsData.BUOY),OK)
	game.submarine.scanner.advance(4.0)
	assert_true(game.research.is_completed(SunlitShallowsData.BUOY))
	game.chapter.close_buoy_message()
	_hide_pages()
	_place(SunlitSurveyData.BUOY)
	game.missions.reconcile()
	assert_true(game.journey.can_finish())
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	assert_eq(game.saves.finish_sunlit_return(),ERR_UNAVAILABLE,"off-screen return to Halcyon refused at zero oxygen")
	await game.journey._finish()
	var notices: Array[String] = []
	for child: Node in game.revision.ui._radio_body.get_children():
		if child is Label: notices.append((child as Label).text)
	assert_true(ChapterJourney.FINISH_OXYGEN_REFUSAL in notices,"the buoy-finish refusal names oxygen: "+str(notices))
	assert_false(game.chapter.concluded())
	assert_eq(pools.restore_snapshot(pools.battery,1.0),OK)
	assert_eq(game.saves.finish_sunlit_return(),OK,"same request succeeds once oxygen is above zero")


# ---------------------------------------------------------------- probe 2: zero oxygen, hull death

func test_probe2_twilight_zero_oxygen_hull_death_recovers_at_halcyon_with_full_restock() -> void:
	_deploy_twilight()
	var far: Vector2 = TwilightShelfLayout.WEST_LOOP[1]
	_place(far)
	await _travel_until_oxygen_zero(0.02,&"move_left",600)
	Input.action_release(&"move_left")
	assert_eq(pools.oxygen,0.0)
	assert_false(game.journey.near_tether(),"death happens away from the tether")
	game.torpedoes.ammunition = 2
	var progress: Dictionary = game.saves.progress_snapshot()
	watch_signals(flow)
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"pressure")
	await wait_physics_frames(3)
	assert_true(flow.pending,"hull failure starts Halcyon recovery")
	assert_signal_emit_count(flow,"recovery_started",1)
	assert_false(game.submarine.is_physics_processing(),"the card freezes the simulation")
	assert_true(flow.panel.visible)
	assert_eq(flow.body.text,"HULL FAILURE. Pressure exceeded the hull rating. "+VesselRecoveryFlow.SHARED_TEXT)
	assert_eq(flow.confirm.text,"Continue at Halcyon")
	assert_false(flow.countdown.running,"recovery clears the life-support countdown")
	assert_false(flow.warning.visible)
	_assert_recovered_checkpoint("Twilight hull",progress)
	assert_eq(game.saves._state.journey.phase,"refit")
	await _press(&"ui_accept")
	assert_false(flow.pending,"recovery confirmed")
	assert_true(game.journey.at_station(),"recovered to the Halcyon refit, not the ascent tether")
	assert_eq(game.saves.progress_snapshot(),progress)
	# A separate Continue from that checkpoint is alive at Halcyon with full oxygen: no loop.
	game.revision.ui.dock_page.hide()
	game.station.end_interaction()
	game.station_menu.hide()
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(3)
	assert_false(flow.pending,"no failure loop on Continue")
	assert_eq(pools.oxygen,pools.max_oxygen)
	assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull)
	assert_signal_emit_count(flow,"recovery_started",1)


# ---------------------------------------------------------------- probe 2b: Sunlit hull death (new)

func test_probe2_sunlit_hull_death_recovers_at_halcyon_berth_with_full_restock() -> void:
	_hide_pages()
	_place(SunlitSurveyData.MAIN_ROUTE[1])
	game.resume_route()
	await wait_physics_frames(2)
	game.submarine.set_simulation_enabled(false)
	assert_eq(pools.restore_snapshot(31.0,44.0),OK)
	game.torpedoes.ammunition = 1
	var progress: Dictionary = game.saves.progress_snapshot()
	var sunlit_mission: Dictionary = game.missions.snapshot()[String(SunlitShallowsData.MISSION)].duplicate(true)
	watch_signals(flow)
	game.resume_route()
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"collision")
	await wait_physics_frames(3)
	assert_true(flow.pending,"Sunlit hull destruction starts Halcyon recovery")
	assert_signal_emit_count(flow,"recovery_started",1)
	assert_eq(flow.body.text,"HULL FAILURE. A collision depleted hull integrity. "+VesselRecoveryFlow.SHARED_TEXT)
	assert_false(game.submarine.is_physics_processing())
	_assert_recovered_checkpoint("Sunlit hull",progress)
	assert_eq(game.saves._state.journey.phase,"sunlit")
	assert_eq(game.missions.snapshot()[String(SunlitShallowsData.MISSION)],sunlit_mission,"Sunlit mission state is not advanced by recovery")
	for id: String in ["sunlit-recovery-guidance"]:
		assert_false(id in game.revision.ui.notifications.pending,"the old Continue-the-checkpoint guidance is gone")
	await _press(&"ui_accept")
	assert_false(flow.pending)
	assert_true(game.submarine.is_physics_processing(),"piloting resumes at the Halcyon berth")
	assert_eq(game.submarine.global_position,SunlitSurveyData.SPAWN)
	await wait_physics_frames(30)
	assert_false(flow.pending,"no second failure")
	assert_signal_emit_count(flow,"recovery_started",1)


# ---------------------------------------------------------------- probe 3: zero oxygen at a station (unchanged)

func test_probe3_sunlit_zero_oxygen_at_halcyon_dock_refills_and_checkpoints() -> void:
	_hide_pages()
	_place(game.region.spawn.global_position)
	game.route_check.sample(true,false,1.0)
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	assert_false(game.saves.safe_to_save(),"undocked at Halcyon, zero oxygen still refuses a save")
	assert_eq(game.open_station(),OK,"docking is not gated on oxygen")
	assert_eq(pools.oxygen,pools.max_oxygen,"dock service refills oxygen")
	assert_true(game.revision.docking_report.contains("Oxygen 0 → 100"),game.revision.docking_report)
	assert_false(game.revision.docking_report.contains("CHECKPOINT NOT SAVED"))
	assert_eq(game.saves._state.player.oxygen,pools.max_oxygen,"docking checkpoint stores full oxygen")


func test_probe3_twilight_zero_oxygen_at_ascent_tether_refits_through_real_interact() -> void:
	_deploy_twilight()
	_place(TwilightShelfLayout.SPAWN)
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	_hide_pages()
	game.resume_route()
	await wait_physics_frames(2)
	assert_true(game.journey.near_tether())
	var interact: InputEventAction = InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(game.revision.ui.radio_page.visible,"Interact at the tether offers the Halcyon transfer")
	var go: Button = game.revision.ui.find_child("ReturnHalcyon",true,false) as Button
	assert_not_null(go)
	go.pressed.emit()
	for frame: int in range(30):
		await wait_physics_frames(1)
		if game.journey.at_station() and not game.journey.transitioning: break
	assert_true(game.journey.at_station(),"transfer to refit is not gated on oxygen")
	assert_eq(pools.oxygen,pools.max_oxygen,"refit restores oxygen")
	assert_eq(game.saves._state.player.oxygen,pools.max_oxygen,"refit checkpoint stores full oxygen")
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN)
	assert_eq(pools.oxygen,pools.max_oxygen,"resuming the shelf keeps the refilled oxygen")
