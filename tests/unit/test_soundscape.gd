extends GutTest

var _mixer: SoundscapeMixer
var _path: String


func before_each() -> void:
	_path = "user://bta041-audio-%d.json" % Time.get_ticks_usec()
	_mixer = SoundscapeMixer.new()
	add_child_autofree(_mixer)
	_mixer.set_process(false)
	_mixer.apply_audio(SettingsStore.default_audio())


func after_each() -> void:
	_mixer.apply_audio(SettingsStore.default_audio())
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))


func test_buses_routes_and_original_loop_imports() -> void:
	for bus: String in SoundscapeMixer.BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		assert_gte(index, 0)
		if bus != "Master":
			assert_eq(AudioServer.get_bus_send(index), &"Master")
	for id: String in SoundscapeMixer.LOOP_NAMES:
		var stream: AudioStreamWAV = _mixer._loops[id].stream as AudioStreamWAV
		assert_eq(stream.mix_rate, 22050)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_gt(stream.get_length(), 1.0)
		assert_eq(_mixer._loops[id].bus, &"Ambience" if id in ["ocean", "current", "tension"] else &"Effects")
	watch_signals(_mixer)
	assert_true(_mixer.request(&"ping"))
	assert_signal_emitted_with_parameters(_mixer, "cue_played", [&"ping", "Effects"])
	assert_true(_mixer.request(&"ui"))
	assert_signal_emitted_with_parameters(_mixer, "cue_played", [&"ui", "UI"])


func test_settings_roundtrip_and_legacy_input_only_file() -> void:
	var store: SettingsStore = SettingsStore.new()
	var audio: Dictionary = SettingsStore.default_audio()
	audio.Master = 0.25
	audio.Effects = 0.45
	audio.muted = true
	assert_eq(store.set_audio(audio), OK)
	assert_eq(store.save_settings(_path), OK)
	var reload: SettingsStore = SettingsStore.new()
	assert_eq(reload.load_settings(_path), OK)
	assert_eq(reload.snapshot().audio, audio)
	var legacy: Dictionary = store.snapshot()
	legacy.erase("audio")
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	assert_eq(reload.load_settings(_path), OK)
	assert_eq(reload.snapshot().audio, SettingsStore.default_audio())
	assert_eq(reload.snapshot().bindings, legacy.bindings)


func test_invalid_audio_is_rejected_without_partial_application() -> void:
	var store: SettingsStore = SettingsStore.new()
	var before: Dictionary = store.snapshot()
	for value: Variant in [NAN, INF, -0.01, 1.01, true, "0.5", null]:
		var audio: Dictionary = SettingsStore.default_audio()
		audio.Effects = value
		assert_eq(store.set_audio(audio), ERR_INVALID_PARAMETER)
		assert_eq(_mixer.apply_audio(audio), ERR_INVALID_PARAMETER)
		assert_eq(store.snapshot(), before)
	var audio: Dictionary = SettingsStore.default_audio()
	audio["unknown"] = 0.5
	assert_false(SettingsStore.valid_audio(audio))
	audio = SettingsStore.default_audio()
	audio.muted = 1
	assert_false(SettingsStore.valid_audio(audio))


func test_missing_sounds_and_invalid_cues_fail_safely() -> void:
	assert_false(_mixer.request(&"missing"))
	_mixer._cues[&"ping"].stream = null
	assert_false(_mixer.request(&"ping"))
	assert_eq(_mixer.active_voice_count(), 0)
	_mixer._cues[&"ping"].stream = AudioStreamWAV.new()
	assert_false(_mixer.request(&"ping"), "Empty/unbounded streams cannot bypass voice limits")
	var cue: AudioCue = AudioCue.new()
	cue.cue_id = &"valid"
	cue.bus = "Master"
	assert_false(cue.is_valid())
	cue.bus = "Effects"
	cue.maximum_voices = 0
	assert_false(cue.is_valid())


func test_cue_and_global_concurrency_caps_and_expiry() -> void:
	assert_true(_mixer.request(&"ping"))
	assert_false(_mixer.request(&"ping"))
	for id: StringName in [&"echo", &"ui", &"dock", &"service", &"scan_start", &"complete", &"unknown", &"creak", &"hull"]:
		assert_true(_mixer.request(id))
	assert_eq(_mixer.active_voice_count(), 10)
	assert_false(_mixer.request(&"oxygen"))
	_mixer.advance(2.0)
	assert_eq(_mixer.active_voice_count(), 0)
	assert_true(_mixer.request(&"oxygen"))


func test_mute_and_category_zero_stop_or_suppress_requests() -> void:
	assert_true(_mixer.request(&"ping"))
	var audio: Dictionary = SettingsStore.default_audio()
	audio.muted = true
	assert_eq(_mixer.apply_audio(audio), OK)
	assert_eq(_mixer.active_voice_count(), 0)
	assert_true(AudioServer.is_bus_mute(0))
	assert_false(_mixer.request(&"echo"))
	audio.muted = false
	audio.Effects = 0.0
	_mixer.apply_audio(audio)
	assert_false(_mixer.request(&"echo"))
	assert_true(_mixer.request(&"ui"))
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))


func test_settings_binding_updates_levels_live_without_changing_input() -> void:
	var store: SettingsStore = SettingsStore.new()
	_mixer.bind_settings(store)
	var bindings: Dictionary = store.snapshot().bindings
	var audio: Dictionary = store.snapshot().audio
	audio.Ambience = 0.3
	store.set_audio(audio)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Ambience")), 0.3, 0.0001)
	assert_eq(store.snapshot().bindings, bindings)


func test_mix_fades_and_crossfades_consistently_at_30_60_120_steps() -> void:
	var outputs: Array[float] = []
	for steps: int in [30, 60, 120]:
		for player: AudioStreamPlayer in _mixer._loops.values():
			player.volume_linear = 0.0
		_mixer.set_context(true, 350.0, 1.0, true, 1.0, true)
		for _index: int in range(steps * 2):
			_mixer.advance(1.0 / steps)
		outputs.append(_mixer._loops.ocean.volume_linear)
		assert_gt(_mixer._loops.engine.volume_linear, 0.4)
		assert_gt(_mixer._loops.tension.volume_linear, 0.4)
		var engine: float = _mixer._loops.engine.volume_linear
		_mixer.set_context(false, 0.0, 0.0, false, 0.0, false)
		_mixer.advance(0.1)
		assert_lt(_mixer._loops.engine.volume_linear, engine)
		assert_gt(_mixer._loops.engine.volume_linear, 0.0, "Fade, not abrupt cut")
	assert_almost_eq(outputs[0], outputs[1], 0.00001)
	assert_almost_eq(outputs[1], outputs[2], 0.00001)


func test_contact_classifications_do_not_add_directional_precision() -> void:
	for id: StringName in [&"mechanical", &"biological", &"geological"]:
		assert_eq(GameplayAudio.contact_cue(id), id)
	assert_eq(GameplayAudio.contact_cue(&"unclassified"), &"unknown")


func test_corrupt_audio_file_preserves_input_and_current_mix_settings() -> void:
	var store: SettingsStore = SettingsStore.new()
	store.set_deadzone(0.4)
	var document: Dictionary = store.snapshot()
	document.audio.Master = "loud"
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	var before: Dictionary = store.snapshot()
	assert_eq(store.load_settings(_path), ERR_INVALID_DATA)
	assert_eq(store.snapshot(), before)
	assert_eq(FileAccess.get_file_as_string(_path), JSON.stringify(document))


func test_echo_duck_is_restrained_and_recovers_smoothly() -> void:
	_mixer.set_context(true, 150.0, 0.0, false, 0.0, false)
	_mixer.advance(10.0)
	var before: float = _mixer._loops.ocean.volume_linear
	assert_true(_mixer.request(&"echo"))
	_mixer.advance(0.1)
	assert_lt(_mixer._loops.ocean.volume_linear, before)
	assert_gt(_mixer._loops.ocean.volume_linear, before * 0.65)
	_mixer.advance(10.0)
	assert_almost_eq(_mixer._loops.ocean.volume_linear, before, 0.0001)


func test_resource_and_predator_alarms_never_overlap_or_queue_stale_warnings() -> void:
	assert_true(_mixer.request(&"hull"))
	assert_false(_mixer.request(&"oxygen"))
	assert_false(_mixer.request(&"predator_alert"))
	_mixer.advance(0.7)
	assert_eq(_mixer.active_voice_count(), 0, "Suppressed alarms are not queued")
	assert_true(_mixer.request(&"predator_alert"))
	assert_false(_mixer.request(&"battery"))
	assert_false(_mixer.request(&"predator_pursue"))
	_mixer.advance(1.9)
	assert_true(_mixer.request(&"predator_pursue"))
