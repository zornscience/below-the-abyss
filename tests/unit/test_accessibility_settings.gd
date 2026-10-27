extends GutTest
var _path: String


func before_each() -> void:
	_path = "user://bta043-settings-%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".invalid"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))


func test_preferences_roundtrip_preserves_audio_and_bindings() -> void:
	var store: SettingsStore = SettingsStore.new()
	var audio: Dictionary = store.snapshot().audio
	audio.muted = true
	store.set_audio(audio)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	store.remap(&"sonar_ping", key)
	var value: Dictionary = SettingsStore.default_accessibility()
	value.ui_scale = "large"
	value.reduced_motion = true
	value.high_contrast = true
	assert_eq(store.set_accessibility(value), OK)
	assert_eq(store.save_settings(_path), OK)
	var loaded: SettingsStore = SettingsStore.new()
	assert_eq(loaded.load_settings(_path), OK)
	assert_eq(loaded.snapshot(), store.snapshot())
	loaded.reset_input_defaults()
	assert_eq(loaded.snapshot().audio, audio)
	assert_eq(loaded.snapshot().accessibility, value)
	assert_eq(loaded.snapshot().bindings, InputBindings.defaults())


func test_legacy_three_and_four_field_settings_gain_defaults_in_memory_only() -> void:
	for with_audio: bool in [false, true]:
		var legacy: Dictionary = SettingsStore.default_document()
		legacy.erase("accessibility")
		if not with_audio:
			legacy.erase("audio")
		var text: String = JSON.stringify(legacy)
		var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var store: SettingsStore = SettingsStore.new()
		assert_eq(store.load_settings(_path), OK)
		assert_eq(store.snapshot().accessibility, SettingsStore.default_accessibility())
		assert_eq(FileAccess.get_file_as_string(_path), text)


func test_invalid_preferences_reject_without_partial_application() -> void:
	var store: SettingsStore = SettingsStore.new()
	var before: Dictionary = store.snapshot()
	for key: String in SettingsStore.default_accessibility():
		for bad: Variant in [null, 1, 1.0, "invalid", [], {}]:
			var value: Dictionary = SettingsStore.default_accessibility()
			value[key] = bad
			assert_eq(store.set_accessibility(value), ERR_INVALID_PARAMETER)
			assert_eq(store.snapshot(), before)
	var extra: Dictionary = SettingsStore.default_accessibility()
	extra.arbitrary = false
	assert_false(SettingsStore.valid_accessibility(extra))


func test_explicit_invalid_settings_recovery_preserves_original_and_never_overwrites_backup() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("broken preferences")
	file.close()
	var store: SettingsStore = SettingsStore.new()
	assert_eq(store.load_settings(_path), ERR_INVALID_DATA)
	assert_eq(store.last_load_result, ERR_INVALID_DATA)
	assert_eq(store.save_settings(_path), OK)
	assert_eq(store.last_load_result, OK)
	assert_eq(FileAccess.get_file_as_string(_path + ".invalid"), "broken preferences")
	file = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("second bad file")
	file.close()
	assert_eq(store.save_settings(_path), ERR_ALREADY_EXISTS)
	assert_eq(FileAccess.get_file_as_string(_path), "second bad file")
	assert_eq(FileAccess.get_file_as_string(_path + ".invalid"), "broken preferences")


func test_gameplay_remap_cannot_replace_fixed_menu_recovery() -> void:
	var store: SettingsStore = SettingsStore.new()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	assert_eq(store.remap(&"pause", key), OK)
	InputBindings.apply(store.snapshot().bindings, 0.25)
	key.pressed = true
	assert_true(key.is_action_pressed("pause"))
	assert_false(InputBindings.is_menu_back(key), "Confirm takes priority inside a menu")
	key.physical_keycode = KEY_ESCAPE
	assert_true(InputBindings.is_menu_back(key), "Escape is always a recovery path")
	InputBindings.apply(InputBindings.defaults(), 0.25)


func test_last_device_filters_prompts_and_ignores_drift() -> void:
	var context: InputContext = InputContext.new()
	add_child_autofree(context)
	context.setup(SettingsStore.new())
	assert_true(context.describe(&"sonar_ping").contains("F"))
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis_value = 0.1
	context.observe(motion)
	assert_false(context.controller)
	motion.axis_value = 0.8
	motion.device = 7
	context.observe(motion)
	assert_true(context.controller)
	assert_eq(context.describe(&"sonar_ping"), "X")
	watch_signals(context)
	context.connection_changed(2, false)
	assert_signal_not_emitted(context, "controller_lost")
	Input.action_press("move_right")
	context.connection_changed(7, false)
	assert_signal_emit_count(context, "controller_lost", 1)
	assert_false(Input.is_action_pressed("move_right"))
	assert_false(context.controller)
	assert_true(context.describe(&"sonar_ping").contains("F"))
