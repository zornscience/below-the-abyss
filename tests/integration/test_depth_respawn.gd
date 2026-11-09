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
func test_failure_saves_zero_hull_and_continue_derives_panel_then_respawns_without_refill() -> void:
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	pools.consume_battery(50)
	pools.consume_oxygen(20)
	var progress: Dictionary = game.saves.progress_snapshot()
	game.submarine.hull_system.apply_damage(100,&"pressure")
	await wait_physics_frames(3)
	assert_true(game.journey.depth_gate.pending)
	assert_true(game.journey.depth_gate.panel.visible)
	assert_false(game.submarine.is_physics_processing())
	assert_eq(game.saves._state.player.hull,0.0)
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(3)
	assert_true(game.journey.depth_gate.pending)
	game.journey.depth_gate.respawn()
	assert_false(game.journey.depth_gate.pending)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_eq(pools.battery,50.0)
	assert_eq(pools.oxygen,80.0)
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN)
	assert_eq(game.saves.progress_snapshot(),progress)
	assert_eq(game.saves._state.size(),12)
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
	assert_true(game.submarine.hull_system.vessel_destroyed.is_connected(game.journey.depth_gate._destroyed))

func test_failure_keyboard_and_gamepad_cancel_stays_and_confirm_respawns() -> void:
	for controller: bool in [false,true]:
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
		assert_true(game.journey.depth_gate.pending)
		Input.parse_input_event(accept)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_false(game.journey.depth_gate.pending,"controller="+str(controller))
		assert_eq(game.submarine.hull_system.hull,100.0)
