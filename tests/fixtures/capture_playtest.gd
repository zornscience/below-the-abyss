extends SceneTree
## Synthetic controller/keyboard walkthrough through real input, never a hardware claim.
var _scene: ShelfPrototype
var _keyboard: bool = false
var _size: Vector2i = Vector2i(1280, 800)
var _tag: String
var _story_events: int = 0
var _started: int


func _frames(count: int = 4) -> void:
	for _index: int in range(count):
		await physics_frame


func _tap(button: JoyButton) -> void:
	var event: InputEvent
	if _keyboard:
		var key: InputEventKey = InputEventKey.new()
		var keys: Dictionary = {JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE,
			JOY_BUTTON_START: KEY_P, JOY_BUTTON_BACK: KEY_M, JOY_BUTTON_X: KEY_F,
			JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_UP: KEY_UP,
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
			JOY_BUTTON_RIGHT_SHOULDER: KEY_TAB}
		key.keycode = keys[button]
		key.physical_keycode = key.keycode
		key.pressed = true
		event = key
	else:
		var joy: InputEventJoypadButton = InputEventJoypadButton.new()
		joy.button_index = button
		joy.pressed = true
		event = joy
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await _frames(2)
	event = event.duplicate() as InputEvent
	if event is InputEventKey:
		(event as InputEventKey).pressed = false
	else:
		(event as InputEventJoypadButton).pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _activate(control: Control) -> void:
	# Follow the actual fixed focus-next binding; no mouse or programmatic grab_focus.
	for _index: int in range(80):
		if root.gui_get_focus_owner() == control:
			await _tap(JOY_BUTTON_A)
			return
		await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	push_error("Controller focus could not reach " + control.name)
	quit(1)


func _move(target: Vector2) -> void:
	for _step: int in range(1800):
		var desired: Vector2 = ((target - _scene.submarine.global_position) * 2.5).limit_length(185.0) / 240.0
		var deadzone: float = InputMap.action_get_deadzone("move_left")
		var encoded: Vector2 = desired.normalized() * lerpf(deadzone, 1.0, desired.length()) if not desired.is_zero_approx() else Vector2.ZERO
		if _keyboard:
			encoded = target - _scene.submarine.global_position - _scene.submarine.velocity * 0.3
			# Keyboard-only steering: press/release physical keys at the same steering thresholds.
			for pair: Array in [[KEY_A, encoded.x < -12.0], [KEY_D, encoded.x > 12.0], [KEY_W, encoded.y < -12.0], [KEY_S, encoded.y > 12.0]]:
				var event: InputEventKey = InputEventKey.new()
				event.keycode = pair[0]
				event.physical_keycode = pair[0]
				event.pressed = pair[1]
				Input.parse_input_event(event)
		else:
			for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
				var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
				motion.axis = axis
				motion.axis_value = encoded.x if axis == JOY_AXIS_LEFT_X else encoded.y
				Input.parse_input_event(motion)
		await physics_frame
		if _scene.submarine.global_position.distance_to(target) < (28.0 if _keyboard else 12.0) and _scene.submarine.velocity.length() < (150.0 if _keyboard else 30.0):
			_release_motion()
			await _frames(20)
			return
	_release_motion()
	push_error("Input-driven accessibility route failed to reach %s: position=%s velocity=%s running=%s" % [target, _scene.submarine.global_position, _scene.submarine.velocity, _scene.submarine.is_physics_processing()])
	quit(1)


func _release_motion() -> void:
	if _keyboard:
		for code: Key in [KEY_A, KEY_D, KEY_W, KEY_S]:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			Input.parse_input_event(event)
	else:
		for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
			event.axis = axis
			Input.parse_input_event(event)


func _point(name: String) -> Vector2:
	return (_scene.region.get_node("RouteMarkers/" + name) as Marker2D).global_position


func _capture(name: String) -> void:
	if name not in ["consent", "hud", "continued"]:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_environment("BTA_EVIDENCE_DIR").path_join("bta-044-" + name + ".png")) == OK)


func _measure_frames() -> void:
	var samples: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for _index: int in range(120):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var total: float = 0.0
	for sample: float in samples:
		total += sample
	print("BTA044_FRAME_INTERVALS ", _tag, " samples=120 mean_ms=", total / 120.0, " median_ms=", samples[60], " p95_ms=", samples[113], " renderer=software_llvmpipe")


func _shutdown() -> void:
	_release_motion()
	_scene.submarine.set_simulation_enabled(false)
	_scene.audio.set_process(false)
	_scene.audio.stop_cues()
	for player: AudioStreamPlayer in _scene.audio._loops.values():
		player.stop()
		player.stream = null
	await create_timer(0.3).timeout
	quit()


func _initialize() -> void:
	assert(OS.has_feature("playtest"))
	assert(not ResourceLoader.exists("res://tests/fixtures/capture_accessibility.gd"))
	assert(not ResourceLoader.exists("res://addons/gut/gut_cmdln.gd"))
	if OS.get_cmdline_user_args().has("--probe-only"):
		print("BTA044_BUNDLE_FILTERS_PASS playtest=true fixtures=false gut=false")
		quit()
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_keyboard = args.has("--keyboard")
	_size = Vector2i(1920, 1080) if args.has("--1080") else (Vector2i(1280, 800) if _keyboard else Vector2i(1280, 800))
	_tag = ("keyboard-" if _keyboard else "controller-") + str(_size.x)
	var profile: String = "user://bta044-native-" + _tag + ".json"
	if not args.has("--continue-accessibility"):
		for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".upgrades.json", ".missions.json"]:
			for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected", ".invalid"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(profile + stem + suffix))
	root.size = _size
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.revised_expedition = false
	_scene.settings_path = profile
	_scene.expedition_path = profile + ".expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(6)
	root.size = _size
	await _frames(4)
	assert(root.size == _size)
	assert(not _scene.development_mode)
	assert(not (_scene.route_menu.get_node("%Restart") as Button).visible)
	assert(not _scene.playtest_observer.recorder.recording)
	_scene.playtest_observer.store.directory = "user://bta044-native-reports"
	_scene.narrative.chapter_concluded.connect(func() -> void: _story_events += 1)
	if args.has("--continue-accessibility"):
		assert(_scene.settings.snapshot().audio.muted)
		assert(_scene.settings.snapshot().accessibility.ui_scale == "large")
		await _activate(_scene.route_menu.get_node("%RecoverExpedition") as Control)
		assert(_scene.saves.status.begins_with("Backup recovered"))
		await _activate(_scene.route_menu.get_node("%Resume") as Control)
		assert(_scene.narrative.is_concluded())
		assert(_scene.upgrades.is_installed(&"sonar-range-1200"))
		assert(_story_events == 0)
		await _tap(JOY_BUTTON_START)
		await _activate(_scene.route_menu.get_node("%OpenStory") as Control)
		await _capture("continued")
		print("BTA044_CONTINUE_OK ", _tag, " chapter=true upgrade=true large=true muted=true story_replays=0")
		await _shutdown()
		return
	_started = Time.get_ticks_usec()
	await _activate(_scene.route_menu.get_node("%Playtest") as Control)
	await _capture("consent")
	if args.has("--consent-only"):
		await _shutdown()
		return
	assert(not _scene.playtest_observer.recorder.recording)
	await _activate(_scene.playtest_panel.start_button)
	assert(_scene.playtest_observer.recorder.recording)
	await _tap(JOY_BUTTON_B)
	await _activate(_scene.route_menu.get_node("%Accessibility") as Control)
	var panel: AccessibilityPanel = _scene.accessibility_panel
	await _tap(JOY_BUTTON_A)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	assert(_scene.settings.snapshot().accessibility.ui_scale == "large")
	for key: String in panel.toggles:
		await _activate(panel.toggles[key])
	await _activate(panel.save_button)
	await _capture("settings")
	await _tap(JOY_BUTTON_B)
	await _activate(_scene.route_menu.get_node("%AudioSettings") as Control)
	await _activate(_scene.audio_settings.mute_button)
	await _activate(_scene.audio_settings.save_button)
	await _tap(JOY_BUTTON_B)
	await _activate(_scene.route_menu.get_node("%NewExpedition") as Control)
	await _capture("confirmation")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_A)
	await _tap(JOY_BUTTON_START)
	await _activate(_scene.route_menu.get_node("%OpenStory") as Control)
	await _capture("briefing")
	await _activate(_scene.expedition_log.begin_button)
	await _tap(JOY_BUTTON_B)
	await _tap(JOY_BUTTON_A)
	await _move(Vector2(760, 480))
	await _tap(JOY_BUTTON_X)
	await _frames(65)
	assert(_scene.discoveries.state_of(NarrativeService.MARKER) == DiscoveryRegistry.State.DISCOVERED)
	# Gameplay Interact uses E on keyboard, menu Accept uses Enter.
	if _keyboard:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = true
		Input.parse_input_event(event)
		await _frames(2)
		event.pressed = false
		Input.parse_input_event(event)
	else:
		await _tap(JOY_BUTTON_A)
	await _frames(190)
	assert(_scene.research.is_completed(NarrativeService.PLATE))
	await _capture("hud")
	await _measure_frames()
	await _tap(JOY_BUTTON_BACK)
	await _activate(_scene.exploration_map.get_node("%OpenResearch") as Control)
	await _capture("research")
	(_scene.research_log.get_node("%DetailScroll") as Control).grab_focus()
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_B)
	await _tap(JOY_BUTTON_B)
	for name: String in ["UpperGate", "Cave", "EastChamber", "TwinSpires"]:
		await _move(_point(name))
	await _tap(JOY_BUTTON_X)
	await _frames(65)
	for name: String in ["ReturnTurn", "LowerEast", "LowerWest", "BaseRise"]:
		await _move(_point(name))
	await _move(_scene.region.spawn.global_position)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	if _keyboard:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = true
		Input.parse_input_event(event)
		await _frames(2)
		event.pressed = false
		Input.parse_input_event(event)
	else:
		await _tap(JOY_BUTTON_A)
	await _activate(_scene.station_menu.get_node("%OpenStationStory") as Control)
	await _activate(_scene.expedition_log.debrief_button)
	assert(_scene.narrative.is_concluded())
	await _capture("debrief")
	(_scene.expedition_log.get_node("%StoryScroll") as Control).grab_focus()
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_B)
	await _activate(_scene.station_menu.get_node("%OpenUpgrades") as Control)
	await _activate(_scene.station_menu.get_node("%InstallSonar") as Control)
	assert(_scene.upgrades.is_installed(&"sonar-range-1200"))
	await _tap(JOY_BUTTON_B)
	await _activate(_scene.station_menu.get_node("%ServiceAll") as Control)
	await _tap(JOY_BUTTON_B)
	await _tap(JOY_BUTTON_START)
	await _activate(_scene.route_menu.get_node("%Settings") as Control)
	# Select sonar using the controller/keyboard popup, deliberately try a conflict,
	# capture a free shoulder/key, save, then restore input defaults only.
	await _activate(_scene._menu.action_picker)
	for _index: int in range(5):
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	await _activate(_scene._menu.rebind_button)
	if not _keyboard:
		await _tap(JOY_BUTTON_A)
		assert(_scene._menu.capturing)
		await _tap(JOY_BUTTON_B)
		await _activate(_scene._menu.rebind_button)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	assert(not _scene._menu.capturing)
	await _activate(_scene._menu.get_node("%Save") as Control)
	await _capture("remapping")
	await _activate(_scene._menu.get_node("%Reset") as Control)
	await _activate(_scene._menu.get_node("%Save") as Control)
	await _tap(JOY_BUTTON_B)
	assert(_scene.settings.snapshot().audio.muted)
	assert(_scene.settings.snapshot().accessibility.ui_scale == "large")
	await _tap(JOY_BUTTON_START)
	await _activate(_scene.route_menu.get_node("%SaveExpedition") as Control)
	assert(_scene.saves.status.begins_with("Expedition saved"))
	assert(_scene.playtest_observer.stop() == OK)
	var report: Dictionary = _scene.playtest_observer.recorder.snapshot()
	assert(PlaytestReport.valid(report))
	assert(report.completed and report.counts.sonar == 2 and report.counts.scan_completed == 1 and report.counts.station_return == 1)
	assert(report.counts.mission_accepted == 2 and report.counts.mission_completed == 2 and report.counts.mission_claimed == 2)
	var output: FileAccess = FileAccess.open(OS.get_environment("BTA_SYNTHETIC_REPORT"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("BTA044_REPORT ", JSON.stringify({"completed": report.completed, "counts": report.counts, "active_seconds": report.active_seconds, "menu_seconds": report.menu_seconds, "completion_seconds": report.completion_seconds}))
	print("BTA044_NATIVE_COMPLETE ", _tag, " wall_seconds=", (Time.get_ticks_usec() - _started) / 1000000.0, " route_seconds=", _scene.route_check.elapsed_seconds, " chapter_events=", _story_events, " controller_events_only=", not _keyboard, " mouse_events=0 muted=true large=true reduced=true")
	await _shutdown()
