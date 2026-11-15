extends GutTest
var game: ShelfPrototype
func before_each() -> void:
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta059-test-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(LightBloomEncounter.COLLECT),OK)
	game.bloom.reset_session()
	assert_eq(game.discoveries.discover(SunlitShallowsData.POI,&"test/buoy"),OK)
	game.submarine.global_position = SunlitSurveyData.BUOY
	var records: Array[StringName] = game.research.completed_ids()
	records.append(SunlitShallowsData.BUOY)
	assert_eq(game.saves.commit_research_checkpoint(records),OK)
	game.research.restore_completed(records)
	game.missions.reconcile()
	assert_eq(game.saves.finish_sunlit_return(),OK)
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
	game.revision.ui.title_page.hide()
	game.revision.ui.radio_page.hide()
	game.route_layer.hide()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	game.submarine.set_simulation_enabled(false)
## Rewritten on purpose (designer decision 3): hull failure no longer writes a zero-hull
## checkpoint and respawns at the tether with supplies kept. It recovers the vessel at
## Halcyon through the refit transfer with a free full restock. Old zero-hull checkpoints
## are recovered on Continue (test_vessel_recovery.gd).
func test_failure_recovers_at_halcyon_with_full_restock_and_continue_does_not_loop() -> void:
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	pools.consume_battery(50)
	pools.consume_oxygen(20)
	game.torpedoes.ammunition = 4
	var progress: Dictionary = game.saves.progress_snapshot()
	game.submarine.hull_system.apply_damage(100,&"pressure")
	await wait_physics_frames(3)
	var flow: VesselRecoveryFlow = game.journey.recovery
	assert_true(flow.pending)
	assert_true(flow.panel.visible)
	assert_false(game.submarine.is_physics_processing())
	assert_true(flow.committed)
	assert_eq(game.saves._state.player.hull,100.0,"no zero-hull checkpoint is written")
	assert_eq(game.saves._state.player.battery,100.0)
	assert_eq(game.saves._state.player.oxygen,100.0)
	assert_eq(game.saves._state.prototype.ammunition,TorpedoLauncher.CAPACITY)
	assert_eq(game.saves._state.journey.phase,"refit")
	flow.acknowledge()
	assert_false(flow.pending)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_eq(pools.battery,100.0)
	assert_eq(pools.oxygen,100.0)
	assert_eq(game.submarine.global_position,SunlitSurveyData.SPAWN)
	assert_true(game.journey.at_station())
	assert_eq(game.saves.progress_snapshot(),progress)
	assert_eq(game.saves._state.size(),12)
	game.revision.ui.dock_page.hide()
	game.station.end_interaction()
	game.station_menu.hide()
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(3)
	assert_false(flow.pending,"Continue from the recovery checkpoint does not fail again")
func test_deep_route_and_subjects_are_registered_without_required_evidence() -> void:
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	for point: Vector2 in gate.crossing():
		assert_true(game.saves.position_clear(point,0))
	assert_eq(game.region.depth_at_world(gate.lower_left),gate.depth_m)
	for id: StringName in TwilightShelfData.DEPTH_SURVEY:
		var record: Dictionary = TwilightShelfData.record(id)
		assert_true(game.saves.position_clear(record.at,0))
		for objective: MissionObjective in TwilightShelfData.missions().definition(TwilightShelfData.MISSION).objectives: assert_ne(objective.target_id,id)
	assert_true(game.submarine.scanner._known(&"twilight-deep-crust"))
	assert_true(game.submarine.hull_system.vessel_destroyed.is_connected(game.journey.recovery._destroyed))

## Rewritten on purpose (designer decision 3): the same keys now drive the recovery card.
func test_failure_keyboard_and_gamepad_cancel_stays_and_confirm_continues_at_halcyon() -> void:
	var flow: VesselRecoveryFlow = game.journey.recovery
	for controller: bool in [false,true]:
		if game.journey.at_station():
			game.revision.ui.dock_page.hide()
			game.station.end_interaction()
			game.station_menu.hide()
			assert_eq(game.saves.transfer_chapter("twilight",false),OK)
			game.revision.ui.radio_page.hide()
			game.route_layer.hide()
		game.submarine.set_simulation_enabled(false)
		game.submarine.hull_system.apply_damage(100,&"pressure")
		await wait_physics_frames(3)
		var cancel: InputEvent
		var accept: InputEvent
		if controller:
			var back: InputEventJoypadButton = InputEventJoypadButton.new()
			back.button_index = JOY_BUTTON_B
			back.pressed = true
			cancel = back
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = JOY_BUTTON_A
			button.pressed = true
			accept = button
		else:
			var escape: InputEventKey = InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.physical_keycode = KEY_ESCAPE
			escape.pressed = true
			cancel = escape
			var enter: InputEventKey = InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.physical_keycode = KEY_ENTER
			enter.pressed = true
			accept = enter
		Input.parse_input_event(cancel)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(flow.pending)
		# The card ignores accept until its fade has finished plus the accept delay.
		for frame: int in range(600):
			if flow.accept_ready() or not flow.pending: break
			await get_tree().process_frame
		assert_true(flow.accept_ready())
		Input.parse_input_event(accept)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_false(flow.pending,"controller="+str(controller))
		assert_eq(game.submarine.hull_system.hull,100.0)
		assert_true(game.journey.at_station(),"controller="+str(controller))
