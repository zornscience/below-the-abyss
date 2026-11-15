extends GutTest
## Investigation probes: what the campaign does today when oxygen reaches zero.
## These record CURRENT behaviour on main; they are not a fix and add no gameplay.
## Every probe asserts the behaviour it names, so it fails if that behaviour is absent.
## Findings and the proposed (unimplemented) fix: docs/investigations/oxygen-exhaustion.md
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
const RESPAWN_TEXT: String = "Battery and oxygen stay as they are"
var game: ShelfPrototype
var path: String
var pools: SubmarineResourceSystem


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


func after_each() -> void:
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


func _oxygen_gauge_state() -> String:
	return (game.hud.oxygen_gauge.get_node("%State") as Label).text


func _assert_open_water_zero_is_inert(action: StringName, region: String) -> void:
	watch_signals(pools)
	var hull: float = game.submarine.hull_system.hull
	var frames: int = await _travel_until_oxygen_zero(0.05,action,900)
	assert_lt(frames,900,region+": the real drain reaches zero")
	assert_eq(pools.oxygen,0.0,region+": clamped at exactly zero, never negative")
	assert_signal_emit_count(pools,"oxygen_depleted",1)
	var at: Vector2 = game.submarine.global_position
	await wait_physics_frames(120)
	# The claimed behaviour: oxygen zero changes nothing about the vessel's survival.
	assert_true(game.submarine.is_physics_processing(),region+": vessel keeps simulating at zero oxygen")
	assert_gt(game.submarine.global_position.distance_to(at),40.0,region+": vessel still moves under thrust at zero oxygen")
	assert_eq(game.submarine.hull_system.hull,hull,region+": zero oxygen deals no hull damage")
	assert_eq(pools.oxygen,0.0)
	assert_signal_emit_count(pools,"oxygen_depleted",1,region+": depletion is announced once, not repeated")
	assert_true(_oxygen_gauge_state().contains("EMPTY") or _oxygen_gauge_state().contains("DEPLETED"),region+": HUD gauge reads empty: "+_oxygen_gauge_state())
	Input.action_release(action)
	# The one real consequence: checkpoint writes refuse while oxygen is zero.
	_place(game.submarine.global_position)
	assert_false(game.saves.safe_to_save(),region+": safe_to_save refuses at zero oxygen")
	assert_eq(game.saves.save_current(),ERR_UNAVAILABLE,region+": manual save refused at zero oxygen")
	assert_eq(game.saves.commit_research_checkpoint(game.research.completed_ids()),ERR_UNAVAILABLE,region+": scan-completion checkpoint refused at zero oxygen")
	assert_eq(pools.restore_snapshot(pools.battery,1.0),OK)
	assert_true(game.saves.safe_to_save(),region+": oxygen alone was the blocker (same pose, 1 unit restored)")


# ---------------------------------------------------------------- probe 1: open water

func test_probe1_sunlit_open_water_zero_oxygen_is_inert_except_checkpoint_refusal() -> void:
	assert_false(game.journey.active())
	_place(SunlitSurveyData.MAIN_ROUTE[0])
	await _assert_open_water_zero_is_inert(&"move_right","Sunlit")


func test_probe1_twilight_open_water_zero_oxygen_is_inert_and_shows_no_failure() -> void:
	_deploy_twilight()
	_place(TwilightShelfLayout.SPAWN)
	await _assert_open_water_zero_is_inert(&"move_left","Twilight")
	assert_false(game.journey.depth_gate.pending,"no failure flow is triggered by oxygen")
	assert_false(game.journey.depth_gate.panel.visible)


func test_probe1_sunlit_zero_oxygen_blocks_buoy_scan_and_offscreen_finish_until_refilled() -> void:
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
	assert_true(game.submarine.scanner.snapshot().text.contains("NOT RECORDED"),"player sees: "+String(game.submarine.scanner.snapshot().text))
	assert_true(game.submarine.scanner.snapshot().text.contains("Save unavailable"))
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
	assert_false(game.chapter.concluded())
	assert_eq(pools.restore_snapshot(pools.battery,1.0),OK)
	assert_eq(game.saves.finish_sunlit_return(),OK,"same request succeeds once oxygen is above zero")


# ---------------------------------------------------------------- probe 2: zero oxygen, hull death, respawn

func test_probe2_twilight_zero_oxygen_hull_death_respawns_at_tether_without_oxygen() -> void:
	_deploy_twilight()
	var far: Vector2 = TwilightShelfLayout.WEST_LOOP[1]
	_place(far)
	await _travel_until_oxygen_zero(0.02,&"move_left",600)
	Input.action_release(&"move_left")
	assert_eq(pools.oxygen,0.0)
	assert_false(game.journey.near_tether(),"death happens away from the tether")
	var progress: Dictionary = game.saves.progress_snapshot()
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"pressure")
	await wait_physics_frames(3)
	var gate: TwilightDepthGate = game.journey.depth_gate
	assert_true(gate.pending,"hull failure opens the respawn dialog")
	assert_false(game.submarine.is_physics_processing(),"dialog freezes the simulation")
	var battery: float = pools.battery
	assert_true(gate.panel.visible)
	assert_true(gate.body.text.contains(RESPAWN_TEXT),"dialog says oxygen is not restored: "+gate.body.text)
	assert_true(gate.body.text.contains("Respawn restores hull at the ascent tether"))
	assert_eq(gate.confirm.text,"Respawn at ascent tether")
	assert_eq(game.saves._state.player.hull,0.0,"failure checkpoint is written with zero hull")
	assert_eq(game.saves._state.player.oxygen,0.0,"failure checkpoint is written with zero oxygen")
	# Confirm with the real accept input (Enter / A both map to ui_accept).
	var accept: InputEventAction = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(gate.pending,"respawn confirmed")
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN,"respawned at the ascent tether")
	assert_true(game.journey.near_tether())
	assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull,"hull restored")
	assert_eq(pools.oxygen,0.0,"oxygen NOT restored, as the dialog says")
	assert_eq(game.saves._state.player.battery,battery,"battery NOT restored in the respawn checkpoint, as the dialog says")
	# Live value: play has resumed, so a few frames of idle drain (0.003/s) have elapsed.
	assert_almost_eq(pools.battery,battery,0.01,"battery NOT refilled live")
	assert_eq(game.saves._state.player.oxygen,0.0,"respawn checkpoint keeps zero oxygen")
	assert_eq(game.saves.progress_snapshot(),progress)
	assert_eq(game.saves._state.size(),12,"schema 10 keeps twelve top-level fields")
	assert_true(game.submarine.is_physics_processing(),"play resumes at zero oxygen")
	# A separate Continue from that checkpoint lands at the tether, alive, still at zero oxygen.
	_place(game.submarine.global_position)
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(3)
	assert_false(gate.pending,"no failure loop on Continue")
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN)
	assert_eq(pools.oxygen,0.0)
	assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull)


# ---------------------------------------------------------------- probe 3: zero oxygen at a station

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
