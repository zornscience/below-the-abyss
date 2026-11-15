extends GutTest
## Oxygen exhaustion and Halcyon recovery in the real campaign scene. The countdown is
## driven only by the real physics step. Long waits scale simulation steps (FAST) and
## always reset Engine.time_scale. Rules, not coordinates: see VesselRecoveryFlow.
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
const FAST: float = 8.0
var game: ShelfPrototype
var path: String
var pools: SubmarineResourceSystem
var flow: VesselRecoveryFlow
var clock: SimClock


## Sums the physics delta actually applied while the vessel simulates.
class SimClock extends Node:
	var vessel: SubmarineController
	var seconds: float = 0.0
	func _physics_process(delta: float) -> void:
		if vessel.is_physics_processing(): seconds += delta


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://vessel-recovery-%d.json" % Time.get_ticks_usec()
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
	clock = SimClock.new()
	clock.vessel = game.submarine
	game.add_child(clock)


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


func _deploy_twilight() -> void:
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
	_hide_pages()
	game.submarine.set_simulation_enabled(false)
	assert_true(game.journey.active())


func _place(at: Vector2) -> void:
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = at
	game.submarine.velocity = Vector2.ZERO
	game.submarine.reset_physics_interpolation()


## Zero oxygen at `at`, simulation running, countdown started by the real step.
func _start_countdown(at: Vector2) -> void:
	_place(at)
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	_hide_pages()
	game.resume_route()
	await wait_physics_frames(2)
	assert_true(flow.countdown.running,"precondition: countdown running")
	assert_true(flow.warning.visible)


## Runs the real simulation with scaled steps for at least `seconds` of simulation time,
## measured from the physics delta actually applied (SimClock).
func _simulate(seconds: float) -> void:
	var target: float = clock.seconds + seconds
	Engine.time_scale = FAST
	while clock.seconds < target:
		await get_tree().physics_frame
	Engine.time_scale = 1.0


## Simulation time until the countdown reads at most `left` seconds, at unscaled steps near the end.
func _simulate_until_remaining(left: float) -> void:
	if flow.countdown.remaining - left > 2.0:
		await _simulate(flow.countdown.remaining - left - 2.0)
	while flow.countdown.running and flow.countdown.remaining > left:
		await get_tree().physics_frame


func _clear_radio() -> void:
	for id: String in game.revision.ui.notifications.pending.duplicate():
		game.revision.ui.notifications.remove_message(id)
	game.revision.ui.notifications.collapse()
	await get_tree().process_frame


func _run_until_recovery(limit: int) -> int:
	Engine.time_scale = FAST
	for frame: int in range(limit):
		await wait_physics_frames(1)
		if flow.pending:
			Engine.time_scale = 1.0
			return frame+1
	Engine.time_scale = 1.0
	return limit


## The card ignores accept until its fade has finished plus the accept delay.
func _wait_card_ready() -> void:
	for frame: int in range(600):
		if flow.accept_ready(): return
		if not flow.pending: break
		await get_tree().process_frame
	fail_test("recovery card never became ready for accept")


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame
	var release: InputEvent = event.duplicate()
	release.set("pressed",false)
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _set_accessibility(reduced_flashing: bool, high_contrast: bool) -> void:
	var preferences: Dictionary = SettingsStore.default_accessibility()
	preferences.reduced_flashing = reduced_flashing
	preferences.high_contrast = high_contrast
	assert_eq(game.settings.set_accessibility(preferences),OK)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(flow.warning.reduced_flashing,reduced_flashing,"preference reaches the border")
	assert_eq(flow.warning.high_contrast,high_contrast)


# ---------------------------------------------------------------- cancel on refit

func test_halcyon_dock_refill_cancels_countdown_and_no_recovery_follows() -> void:
	watch_signals(flow)
	await _start_countdown(game.region.spawn.global_position)
	await wait_physics_frames(30)
	assert_lt(flow.countdown.remaining,60.0)
	# Real Interact (E) docks at Halcyon. Service refills oxygen while paused.
	await _send(_key(KEY_E))
	assert_true(game.station_menu.visible or game.revision.ui.dock_page.visible,"docked at Halcyon")
	assert_eq(pools.oxygen,pools.max_oxygen,"dock service refills oxygen")
	await wait_physics_frames(2)
	assert_false(flow.countdown.running,"refill cancels the countdown while docked")
	assert_false(flow.warning.visible,"border cleared at once")
	game.revision.ui.dock_page.hide()
	game.station.end_interaction()
	game.station_menu.hide()
	_hide_pages()
	game.resume_route()
	await _simulate(75.0)
	assert_false(flow.pending,"no recovery after a cancelled countdown")
	assert_signal_not_emitted(flow,"recovery_started")
	assert_gt(pools.oxygen,0.0)


func test_twilight_tether_refit_cancels_countdown_and_no_recovery_follows() -> void:
	_deploy_twilight()
	watch_signals(flow)
	await _start_countdown(TwilightShelfLayout.SPAWN)
	await wait_physics_frames(30)
	await _send(_key(KEY_E))
	assert_true(game.revision.ui.radio_page.visible,"Interact at the tether offers the Halcyon transfer")
	(game.revision.ui.find_child("ReturnHalcyon",true,false) as Button).pressed.emit()
	for frame: int in range(30):
		await wait_physics_frames(1)
		if game.journey.at_station() and not game.journey.transitioning: break
	assert_true(game.journey.at_station())
	assert_eq(pools.oxygen,pools.max_oxygen)
	assert_false(flow.countdown.running,"tether refit cancels the countdown")
	assert_false(flow.warning.visible)
	await game.journey.resume_expedition()
	_hide_pages()
	game.resume_route()
	await _simulate(75.0)
	assert_false(flow.pending)
	assert_signal_not_emitted(flow,"recovery_started")


# ---------------------------------------------------------------- freeze on pause

func test_countdown_and_pulse_freeze_while_paused_by_keyboard_and_gamepad() -> void:
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	for pause: InputEvent in [_key(KEY_ESCAPE),_button(JOY_BUTTON_START)]:
		await wait_physics_frames(20)
		# An unread radio preview takes the first Escape (existing behaviour). Clear it.
		await _clear_radio()
		await _send(pause)
		assert_true(game.route_layer.visible,"pause menu open: "+pause.as_text())
		assert_false(game.submarine.is_physics_processing())
		var frozen: float = flow.countdown.remaining
		var alpha: float = flow.warning.border_alpha
		await wait_physics_frames(90)
		assert_eq(flow.countdown.remaining,frozen,"countdown frozen while paused")
		assert_false(flow.warning.animating,"pulse frozen while paused")
		assert_eq(flow.warning.border_alpha,alpha)
		assert_true(flow.warning.visible,"the state stays readable while paused")
		game.resume_route()
		await wait_physics_frames(30)
		assert_lt(flow.countdown.remaining,frozen,"countdown resumes with the simulation")
	# The map also pauses the simulation.
	var before: float = flow.countdown.remaining
	game.open_map()
	await wait_physics_frames(60)
	assert_eq(flow.countdown.remaining,before,"countdown frozen while the map is open")
	assert_false(flow.pending)


# ---------------------------------------------------------------- Continue mid-countdown

func test_continue_mid_countdown_restarts_the_full_grace() -> void:
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	game.submarine.set_simulation_enabled(false)
	# A checkpoint holding zero oxygen, as BTA-059 respawns and sentinel decisions wrote.
	assert_eq(game.saves._write(game.saves.snapshot(),"probe zero-oxygen checkpoint"),OK)
	assert_eq(game.saves._state.player.oxygen,0.0)
	game.resume_route()
	await _simulate(30.0)
	assert_lt(flow.countdown.remaining,31.0)
	assert_true(flow.countdown.running)
	game.open_route_menu()
	assert_eq(game.saves.continue_expedition(),OK)
	assert_false(flow.countdown.running,"Continue clears the session countdown")
	assert_false(flow.pending,"loading zero oxygen never fails instantly")
	await wait_physics_frames(5)
	assert_false(flow.pending)
	_hide_pages()
	game.resume_route()
	await wait_physics_frames(2)
	assert_true(flow.countdown.running)
	assert_gt(flow.countdown.remaining,59.9,"the full countdown restarts after Continue")
	assert_eq(flow.warning.label.text,LifeSupportWarning.countdown_text(flow.countdown.remaining))


func test_continue_from_a_bta059_zero_hull_checkpoint_recovers_at_halcyon() -> void:
	_deploy_twilight()
	_place(TwilightShelfLayout.WEST_LOOP[1])
	game.submarine.hull_system.restore_snapshot(0.0)
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	# The BTA-059 failure checkpoint: hull 0, written before the respawn choice.
	assert_eq(game.saves._write(game.saves.snapshot(),"Hull failure recorded."),OK)
	game.submarine.hull_system.restore_snapshot(100.0)
	watch_signals(flow)
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(3)
	assert_true(flow.pending,"a hull-failure checkpoint is recovered on Continue")
	assert_signal_emit_count(flow,"recovery_started",1)
	assert_true(game.journey.at_station())
	assert_eq(game.saves._state.player.hull,100.0)
	assert_eq(game.saves._state.player.oxygen,pools.max_oxygen)


# ---------------------------------------------------------------- loop guards

func test_loop_guard_sunlit_life_support_recovery_is_not_followed_by_a_second_failure() -> void:
	watch_signals(flow)
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	assert_lt(await _run_until_recovery(900),900)
	await get_tree().process_frame
	flow.acknowledge()
	assert_true(game.submarine.is_physics_processing())
	await _simulate(75.0)
	assert_signal_emit_count(flow,"recovery_started",1,"no second failure after recovery")
	assert_false(flow.pending)
	assert_false(flow.countdown.running)
	assert_gt(pools.oxygen,90.0)


func test_loop_guard_twilight_hull_recovery_is_not_followed_by_a_second_failure() -> void:
	_deploy_twilight()
	_place(TwilightShelfLayout.WEST_LOOP[1])
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	watch_signals(flow)
	game.submarine.hull_system.apply_damage(100.0,&"pressure")
	await wait_physics_frames(3)
	assert_true(flow.pending)
	flow.acknowledge()
	assert_true(game.journey.at_station())
	await game.journey.resume_expedition()
	_hide_pages()
	game.resume_route()
	assert_true(game.submarine.is_physics_processing())
	await _simulate(75.0)
	assert_signal_emit_count(flow,"recovery_started",1,"no second failure after recovery")
	assert_false(flow.pending)
	assert_gt(pools.oxygen,90.0)


# ---------------------------------------------------------------- presentation and accessibility

func test_default_border_pulses_slowly_never_strobes_and_ramps_in_the_last_twenty_seconds() -> void:
	await _set_accessibility(false,false)
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	var low: float = 1.0
	var high: float = 0.0
	var phase: float = flow.warning._phase
	var cycles: float = 0.0
	var seconds: float = 0.0
	for frame: int in range(180):
		await get_tree().process_frame
		seconds += get_process_delta_time()
		var now: float = flow.warning._phase
		cycles += fmod(now - phase + 1.0, 1.0)
		phase = now
		low = minf(low,flow.warning.border_alpha)
		high = maxf(high,flow.warning.border_alpha)
		assert_lte(flow.warning.pulse_hz,2.0)
	assert_gte(low,LifeSupportWarning.MIN_ALPHA-0.0001,"never fades out: not a strobe")
	assert_lte(high,1.0)
	assert_gt(high-low,0.2,"the default border visibly pulses")
	assert_lte(cycles/seconds,0.5+0.01,"0.5 pulses per second early in the countdown")
	assert_eq(flow.warning.border_width,LifeSupportWarning.DEFAULT_WIDTH)
	assert_eq(Color(flow.warning._edges[0].color,1.0),LifeSupportWarning.DEFAULT_COLOR)
	assert_false(flow.warning._inner[0].visible)
	# Ramp: drive simulation time to the last 20 s, then near zero.
	for target: float in [15.0,1.0]:
		await _simulate_until_remaining(target)
		await get_tree().process_frame
		assert_almost_eq(flow.warning.remaining,flow.countdown.remaining,0.05,"the border shows the live countdown")
		assert_almost_eq(flow.warning.pulse_hz,LifeSupportWarning.pulse_rate(flow.warning.remaining,60.0),0.0001)
		assert_gt(flow.warning.pulse_hz,0.5)
		assert_lte(flow.warning.pulse_hz,1.5)
	cycles = 0.0
	seconds = 0.0
	phase = flow.warning._phase
	game.submarine.set_simulation_enabled(false)
	flow.warning.animating = true  # measure the fastest rate the border can reach
	for frame: int in range(120):
		await get_tree().process_frame
		seconds += get_process_delta_time()
		var now: float = flow.warning._phase
		cycles += fmod(now - phase + 1.0, 1.0)
		phase = now
	assert_lte(cycles/seconds,2.0,"never more than 2 pulses per second")
	assert_true(flow.warning.label.text.contains("CRITICAL"),"critical state is in words, not only colour")


func test_reduced_flashing_border_is_static_and_thickens_as_time_falls() -> void:
	await _set_accessibility(true,false)
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	var widths: Array[float] = []
	for target: float in [59.0,30.0,5.0]:
		await _simulate_until_remaining(target)
		for frame: int in range(40):
			await get_tree().process_frame
			assert_eq(flow.warning.border_alpha,1.0,"static: no opacity change")
		widths.append(flow.warning.border_width)
		assert_true(flow.warning.label.text.begins_with("OXYGEN DEPLETED, LIFE SUPPORT "))
	assert_lt(widths[0],widths[1],"thicker as time falls")
	assert_lt(widths[1],widths[2])
	assert_lte(widths[2],LifeSupportWarning.STATIC_MAX_WIDTH)
	assert_gte(widths[0],LifeSupportWarning.STATIC_MIN_WIDTH)


func test_high_contrast_border_is_brighter_with_a_white_inner_edge() -> void:
	await _set_accessibility(false,true)
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	await get_tree().process_frame
	var edge: Color = flow.warning._edges[0].color
	assert_eq(Color(edge,1.0),LifeSupportWarning.HIGH_CONTRAST_COLOR)
	assert_gt(LifeSupportWarning.HIGH_CONTRAST_COLOR.get_luminance(),LifeSupportWarning.DEFAULT_COLOR.get_luminance(),"brighter than default")
	assert_true(flow.warning._inner[0].visible,"white inner edge separates the border by shape as well as colour")
	assert_eq(flow.warning._inner[0].color,Color.WHITE)
	assert_eq(flow.warning.border_width,LifeSupportWarning.DEFAULT_WIDTH+LifeSupportWarning.HIGH_CONTRAST_EXTRA)
	await _set_accessibility(true,true)
	await get_tree().process_frame
	assert_eq(flow.warning.border_alpha,1.0,"High contrast with Reduced flashing stays static")
	assert_true(flow.warning._inner[0].visible)


func test_countdown_text_sits_below_the_oxygen_gauge_clear_of_the_depth_readout_at_both_sizes() -> void:
	var original: Vector2i = get_window().size
	for size: Vector2i in [Vector2i(1280,800),Vector2i(800,600)]:
		get_window().size = size
		await get_tree().process_frame
		await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
		for frame: int in range(6): await get_tree().process_frame
		var text: Rect2 = flow.warning._panel.get_global_rect()
		var depth: Rect2 = (game.hud.get_node("%DepthPanel") as Control).get_global_rect()
		var gauge: Rect2 = game.hud.oxygen_gauge.get_global_rect()
		var screen: Rect2 = Rect2(Vector2.ZERO,flow.warning.size)
		assert_eq(flow.warning.size,Vector2(size),"the overlay covers the resized window")
		assert_false(text.intersects(depth),"text clear of the depth readout at %s: %s vs %s" % [size,text,depth])
		assert_false(text.intersects(gauge),"text does not cover the oxygen gauge at %s" % size)
		assert_gte(text.position.y,gauge.end.y,"text is below the oxygen gauge at %s" % size)
		assert_true(screen.encloses(text),"text fully on screen at %s: %s in %s" % [size,text,screen])
		game.submarine.set_simulation_enabled(false)
	get_window().size = original
	await get_tree().process_frame


# ---------------------------------------------------------------- keyboard and gamepad routes

func test_recovery_card_keyboard_and_gamepad_back_stays_and_accept_continues() -> void:
	_deploy_twilight()
	for controller: bool in [false,true]:
		if game.journey.at_station():
			game.revision.ui.dock_page.hide()
			game.station.end_interaction()
			game.station_menu.hide()
			assert_eq(game.saves.transfer_chapter("twilight",false),OK)
			_hide_pages()
		await _start_countdown(TwilightShelfLayout.WEST_LOOP[1])
		assert_lt(await _run_until_recovery(900),900)
		await get_tree().process_frame
		assert_true(flow.pending)
		await _send(_button(JOY_BUTTON_B) if controller else _key(KEY_ESCAPE))
		assert_true(flow.pending,"Esc / B stays on the card, controller=%s" % controller)
		assert_true(flow.panel.visible)
		assert_false(game.route_layer.visible,"Esc / B does not open the pause menu behind the card")
		assert_false(game.submarine.is_physics_processing())
		await _wait_card_ready()
		await _send(_button(JOY_BUTTON_A) if controller else _key(KEY_ENTER))
		assert_false(flow.pending,"Enter / A continues, controller=%s" % controller)
		assert_true(game.journey.at_station())
		assert_true(game.revision.ui.dock_page.visible,"Halcyon refit page")
		assert_eq(pools.oxygen,pools.max_oxygen)


func test_sunlit_hull_card_keyboard_and_gamepad_routes() -> void:
	for controller: bool in [false,true]:
		_place(SunlitSurveyData.MAIN_ROUTE[0])
		_hide_pages()
		game.resume_route()
		game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"collision")
		await wait_physics_frames(3)
		assert_true(flow.pending)
		await _send(_button(JOY_BUTTON_B) if controller else _key(KEY_ESCAPE))
		assert_true(flow.pending)
		await _wait_card_ready()
		await _send(_button(JOY_BUTTON_A) if controller else _key(KEY_ENTER))
		assert_false(flow.pending,"controller=%s" % controller)
		assert_true(game.submarine.is_physics_processing(),"piloting resumes at the Halcyon berth")
		assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull)


# ---------------------------------------------------------------- alarm and telemetry

func test_existing_oxygen_alarm_sounds_at_zero_and_at_ten_seconds_with_visible_equivalents() -> void:
	var played: Array[StringName] = []
	game.audio.cue_played.connect(func(cue: StringName,_bus: String) -> void: played.append(cue))
	game.audio.reset_session()
	await _start_countdown(SunlitSurveyData.MAIN_ROUTE[0])
	assert_eq(flow.alarms_requested,1,"alarm requested when oxygen reaches zero")
	assert_true(&"oxygen" in played,"the existing oxygen cue plays at zero: "+str(played))
	assert_true(flow.warning.visible,"visible equivalent at zero: border and text")
	var zero_count: int = played.count(&"oxygen")
	await _simulate_until_remaining(10.5)
	assert_eq(flow.alarms_requested,1)
	await _simulate_until_remaining(9.5)
	assert_eq(flow.alarms_requested,2,"alarm requested at 10 s remaining")
	assert_eq(played.count(&"oxygen"),zero_count+1,"the same oxygen cue plays again at 10 s")
	assert_true(flow.warning.label.text.contains("CRITICAL"),"visible equivalent at 10 s: CRITICAL in words")


func test_low_oxygen_alarm_has_its_visible_gauge_state() -> void:
	var played: Array[StringName] = []
	game.audio.cue_played.connect(func(cue: StringName,_bus: String) -> void: played.append(cue))
	game.audio.reset_session()
	game.gameplay_audio.reset_session()
	_place(SunlitSurveyData.MAIN_ROUTE[0])
	assert_eq(pools.restore_snapshot(pools.battery,pools.max_oxygen*game.audio.configuration.low_resource_fraction*0.5),OK)
	_hide_pages()
	game.resume_route()
	# GameplayAudio checks thresholds on process frames.
	for frame: int in range(30):
		await get_tree().process_frame
		if &"oxygen" in played: break
	assert_true(&"oxygen" in played,"low-oxygen alarm plays")
	var state: String = (game.hud.oxygen_gauge.get_node("%State") as Label).text
	assert_true(state.contains("LOW"),"its visible equivalent is the gauge state word: "+state)


func test_playtest_failure_fires_on_recovery_and_oxygen_depleted_is_only_a_warning() -> void:
	var observer: PlaytestObserver = PlaytestObserver.new()
	game.add_child(observer)
	observer.setup(game)
	observer.store.directory = path+"-reports"
	game.playtest_observer = observer
	assert_eq(observer.start(),OK)
	_place(SunlitSurveyData.MAIN_ROUTE[0])
	assert_eq(pools.restore_snapshot(pools.battery,0.02),OK)
	_hide_pages()
	game.resume_route()
	await wait_physics_frames(60)
	assert_eq(pools.oxygen,0.0)
	var data: Dictionary = observer.recorder.snapshot()
	assert_eq(int(data.counts.get("failure",0)),0,"oxygen reaching zero is not a failure")
	var warnings: Array = data.events.filter(func(event: Dictionary) -> bool: return event.kind=="resource_warning" and event.detail=="oxygen_depleted")
	assert_eq(warnings.size(),1,"oxygen_depleted is a resource warning")
	assert_lt(await _run_until_recovery(900),900)
	data = observer.recorder.snapshot()
	assert_eq(int(data.counts.failure),1,"failure fires on the real recovery trigger")
	var failures: Array = data.events.filter(func(event: Dictionary) -> bool: return event.kind=="failure")
	assert_eq(failures[0].detail,"life_support_expired")
	assert_true(PlaytestReport.valid(data))
	flow.acknowledge()
	game.submarine.hull_system.apply_damage(100.0,&"collision")
	await wait_physics_frames(3)
	data = observer.recorder.snapshot()
	failures = data.events.filter(func(event: Dictionary) -> bool: return event.kind=="failure")
	assert_eq(failures.size(),2)
	assert_eq(failures[1].detail,"hull_destroyed")
	assert_true(PlaytestReport.valid(data))
	flow.acknowledge()
	observer.stop()
	for name: String in DirAccess.get_files_at(observer.store.directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(observer.store.directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(observer.store.directory))
