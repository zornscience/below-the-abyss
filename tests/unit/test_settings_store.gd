extends GutTest

var _path: String
var _store: SettingsStore


func before_each() -> void:
	_path = "user://bta004-settings-%d.json" % Time.get_ticks_usec()
	_store = SettingsStore.new()


func after_each() -> void:
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + suffix))


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_save_reload_round_trip_and_overwrite() -> void:
	assert_eq(_store.save_settings(_path), OK)
	assert_eq(_store.set_deadzone(0.4), OK)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	assert_eq(_store.remap(&"sonar_ping", key), OK)
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_RIGHT_SHOULDER
	assert_eq(_store.remap(&"sonar_ping", button), OK)
	assert_eq(_store.save_settings(_path), OK, "Replace an existing saved file.")
	var loaded: SettingsStore = SettingsStore.new()
	assert_eq(loaded.load_settings(_path), OK)
	assert_eq(loaded.snapshot(), _store.snapshot())
	assert_false(FileAccess.file_exists(_path + ".tmp"))


func test_missing_and_corrupt_files_preserve_current_settings() -> void:
	assert_eq(_store.set_deadzone(0.45), OK)
	var previous: Dictionary = _store.snapshot()
	assert_eq(_store.load_settings(_path), ERR_FILE_NOT_FOUND)
	_write("{broken json")
	assert_eq(_store.load_settings(_path), ERR_INVALID_DATA)
	assert_eq(_store.snapshot(), previous)
	assert_eq(FileAccess.get_file_as_string(_path), "{broken json", "Invalid input is not overwritten.")


func test_invalid_documents_are_rejected_without_partial_application() -> void:
	var base: Dictionary = _store.snapshot()
	var invalid: Array[Dictionary] = []
	for version: Variant in [null, true, 2, 1.5, "1"]:
		var document: Dictionary = base.duplicate(true)
		document["schema_version"] = version
		invalid.append(document)
	for value: Variant in [-1.0, 0.0, 0.95, "0.25", true, null]:
		var document: Dictionary = base.duplicate(true)
		document["deadzone"] = value
		invalid.append(document)
	var unknown: Dictionary = base.duplicate(true)
	unknown["bindings"]["unknown_action"] = []
	invalid.append(unknown)
	var missing: Dictionary = base.duplicate(true)
	missing["bindings"].erase("move_left")
	invalid.append(missing)
	var unbound: Dictionary = base.duplicate(true)
	unbound["bindings"]["sonar_ping"] = []
	invalid.append(unbound)
	for entry: Dictionary in [
		{"kind": "script", "code": "res://malicious.gd"},
		{"kind": "key", "code": 99999999},
		{"kind": "key", "code": KEY_SHIFT},
		{"kind": "button", "code": -1},
		{"kind": "button", "code": true},
		{"kind": "axis", "axis": JOY_AXIS_MAX, "direction": 1},
		{"kind": "axis", "axis": 0, "direction": 0},
		{"kind": "key", "code": KEY_G, "unexpected": true},
	]:
		var document: Dictionary = base.duplicate(true)
		document["bindings"]["sonar_ping"][0] = entry
		invalid.append(document)
	for document: Dictionary in invalid:
		_write(JSON.stringify(document))
		assert_false(SettingsStore.valid_document(document))
		assert_eq(_store.load_settings(_path), ERR_INVALID_DATA)
		assert_eq(_store.snapshot(), base)
	assert_false(SettingsStore.valid_document([]))


func test_oversized_file_and_write_failure_are_reported() -> void:
	_write(" ".repeat(SettingsStore.MAX_BYTES + 1))
	assert_eq(_store.load_settings(_path), ERR_INVALID_DATA)
	assert_ne(_store.save_settings(_path + "/missing/settings.json"), OK)


func test_invalid_deadzone_and_snapshot_mutation_do_not_change_state() -> void:
	var previous: Dictionary = _store.snapshot()
	for value: float in [NAN, INF, -INF, 0.01, 1.0]:
		assert_eq(_store.set_deadzone(value), ERR_INVALID_PARAMETER)
	var copy: Dictionary = _store.snapshot()
	copy["bindings"]["move_left"].clear()
	assert_eq(_store.snapshot(), previous)
	_store.set_deadzone(0.5)
	_store.reset_defaults()
	assert_eq(_store.snapshot(), previous)


func test_per_frame_accessors_match_snapshot_and_follow_changes() -> void:
	var access: Dictionary = _store.snapshot().accessibility
	assert_eq(_store.accessibility_flag(&"reduced_motion"), bool(access.reduced_motion))
	assert_false(_store.accessibility_flag(&"no_such_flag"))
	access.reduced_motion = not bool(access.reduced_motion)
	assert_eq(_store.set_accessibility(access), OK)
	assert_eq(_store.accessibility_flag(&"reduced_motion"), bool(access.reduced_motion), "no stale value after a change")
	assert_false(_store.onboarding_has_seen("movement"))
	assert_eq(_store.set_onboarding({"enabled": true, "seen": ["movement"]}), OK)
	assert_true(_store.onboarding_has_seen("movement"))
