extends "res://tests/fixtures/capture_expedition_save.gd"
## Native input-driven walkthrough. Only the warning exercise explicitly consumes supplies.
## --resume-audio uses the previous process's isolated checkpoint, never canonical user saves.

var _events: Array[Dictionary] = []
var _recording: AudioEffectRecord
var _frame_samples: Array[float] = []


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-041-" + name + ".png") == OK)


func _spawn() -> void:
	_scene = load("res://scenes/main/shelf_prototype_fixture.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta041-native.json"
	_scene.expedition_path = "user://bta041-native-expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.audio.cue_played.connect(func(id: StringName, bus: String) -> void:
		var event: Dictionary = {"cue": id, "bus": bus, "seconds": Time.get_ticks_msec() / 1000.0}
		_events.append(event)
		print("BTA041_AUDIO ", JSON.stringify(event)))


func _shutdown() -> void:
	_scene.submarine.set_simulation_enabled(false)
	_scene.audio.set_process(false)
	_scene.audio.stop_cues()
	for player: AudioStreamPlayer in _scene.audio._loops.values():
		player.stop()
		player.stream = null
	# Let native mixer retire stopped playback handles before process exit.
	await create_timer(0.3).timeout
	quit()


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--resume-audio"):
		await _spawn()
		assert(_scene.saves.has_checkpoint())
		await _tap_button(JOY_BUTTON_A)
		assert(_scene.research.is_completed(&"shelf-calibration-plate"))
		assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
		assert(not _events.any(func(event: Dictionary) -> bool: return event.cue in [&"ping", &"complete"]))
		await _capture("continued")
		# Refresh the settings compositions with final focus styling, preserve fixture progress.
		_scene.open_route_menu()
		_scene.open_audio_settings()
		await _capture("audio-settings")
		root.size = Vector2i(800, 600)
		await _capture("audio-compact")
		_scene.audio_settings.cancel()
		root.size = Vector2i(1280, 800)
		_scene.resume_route()
		var previous: int = Time.get_ticks_usec()
		var samples: Array[float] = []
		for _index: int in range(180):
			await process_frame
			var now: int = Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		print("BTA041_CONTINUE_FRAME_MS median=%.3f p95=%.3f adapter=%s" % [samples[90], samples[171], RenderingServer.get_video_adapter_name()])
		print("BTA041_FRESH_PROCESS_CONTINUE_OK no_ping_or_research_replay=true")
		await _shutdown()
		return
	for path: String in ["user://bta041-native.json", "user://bta041-native-expedition.json", "user://bta041-native.json.missions.json", "user://bta041-native.json.upgrades.json", "user://bta041-native.json.discoveries.json", "user://bta041-native.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	await _spawn()
	_scene.open_audio_settings()
	await _capture("audio-settings")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("audio-compact")
	_scene.audio_settings.cancel()
	root.size = Vector2i(1280, 800)
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.is_physics_processing())
	await _fly_to(Vector2(760, 480))
	_recording = AudioEffectRecord.new()
	_recording.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _recording)
	_recording.set_recording_active(true)
	await _tap_key(KEY_F)
	await _frames(65)
	await _tap_key(KEY_E)
	await _frames(195)
	assert(_scene.research.is_completed(&"shelf-calibration-plate"))
	_recording.set_recording_active(false)
	var recording: AudioStreamWAV = _recording.get_recording()
	if recording != null and recording.data.size() > 0:
		assert(recording.save_to_wav("res://docs/testing/bta-041-sonar-scan-mix.wav") == OK)
		print("BTA041_NATIVE_RECORDING bytes=", recording.data.size())
	else:
		print("BTA041_NATIVE_RECORDING unavailable on this driver")
	AudioServer.remove_bus_effect(0, 0)
	await _capture("research")
	await _fly_to(_point("UpperGate"))
	await _fly_to(Vector2(1450, 400))
	await _tap_key(KEY_F)
	await _frames(4)
	assert(_scene.creature.brain.state == CreatureState.State.INVESTIGATE)
	await _capture("observer")
	await _fly_to(_point("Cave"))
	await _fly_to(_point("EastChamber"))
	await _fly_to(Vector2(3060, 480))
	await _fly_to(Vector2(3060, 390))
	await _tap_key(KEY_F)
	await _frames(4)
	assert(_scene.predator.threat.phase == PredatorState.Phase.ALERT)
	await _capture("warning")
	await _frames(155)
	assert(_scene.predator.threat.phase == PredatorState.Phase.PURSUE)
	await _capture("pursuit")
	await _fly_to(Vector2(3060, 500))
	assert(_scene.predator.threat.phase == PredatorState.Phase.DISENGAGE)
	await _capture("retreat")
	await _fly_to(_point("TwinSpires"))
	await _tap_key(KEY_F)
	await _frames(65)
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	# Labelled test-only resource exercise, not a simulated discovery or encounter.
	_scene.submarine.resource_system.consume_battery(maxf(0.0, _scene.submarine.resource_system.battery - 18.0))
	_scene.submarine.resource_system.consume_oxygen(maxf(0.0, _scene.submarine.resource_system.oxygen - 18.0))
	_scene.submarine.hull_system.apply_damage(82.0, &"audio-verification")
	await _frames(275)
	await _capture("resource-warnings")
	await _tap_key(KEY_E)
	(_scene.station_menu.get_node("%ServiceAll") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	assert(_scene.submarine.resource_system.oxygen == 100.0)
	await _capture("station")
	await _tap_button(JOY_BUTTON_B)
	_scene.open_route_menu()
	assert(_scene.saves.save_current() == OK)
	assert(_events.any(func(event: Dictionary) -> bool: return event.cue == &"predator_pursue"))
	assert(_events.any(func(event: Dictionary) -> bool: return event.cue == &"complete"))
	assert(_events.any(func(event: Dictionary) -> bool: return event.cue == &"mechanical"))
	# Observe frame intervals in a clear native view, not a hardware certification.
	_scene.resume_route()
	var previous: int = Time.get_ticks_usec()
	for _index: int in range(180):
		await process_frame
		var now: int = Time.get_ticks_usec()
		_frame_samples.append((now - previous) / 1000.0)
		previous = now
	_frame_samples.sort()
	print("BTA041_NATIVE_FRAME_MS median=%.3f p95=%.3f adapter=%s" % [_frame_samples[90], _frame_samples[171], RenderingServer.get_video_adapter_name()])
	print("BTA041_NATIVE_WALKTHROUGH_OK route_scan_passive_observer_threat_escape_warnings_services_save=true accepted_cues=", _events.size())
	await _shutdown()
