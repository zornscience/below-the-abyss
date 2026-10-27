class_name SettingsStore
extends RefCounted
## Small, versioned input preferences. Invalid loads leave current state intact.

signal settings_changed

const DEFAULT_PATH: String = "user://settings.json"
const MAX_BYTES: int = 65536
var last_load_result: Error = OK
var _document: Dictionary = default_document()


static func default_document() -> Dictionary:
	return {"schema_version": 1, "deadzone": 0.25, "bindings": InputBindings.defaults(), "audio": default_audio(), "accessibility": default_accessibility()}


static func default_audio() -> Dictionary:
	return {"Master": 0.8, "Music": 0.5, "Ambience": 0.65, "Effects": 0.8, "UI": 0.7, "muted": false}


static func default_accessibility() -> Dictionary:
	return {"ui_scale": "standard", "reduced_flashing": false, "reduced_particles": false,
		"reduced_motion": false, "high_contrast": false}


static func valid_accessibility(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5 or value.get("ui_scale") not in ["compact", "standard", "large"]:
		return false
	for key: String in ["reduced_flashing", "reduced_particles", "reduced_motion", "high_contrast"]:
		if not value.get(key) is bool:
			return false
	return true


func set_accessibility(value: Dictionary) -> Error:
	if not valid_accessibility(value):
		return ERR_INVALID_PARAMETER
	_document["accessibility"] = value.duplicate(true)
	settings_changed.emit()
	return OK


func reset_input_defaults() -> void:
	_document["bindings"] = InputBindings.defaults()
	_document["deadzone"] = 0.25
	settings_changed.emit()


static func valid_audio(audio: Variant) -> bool:
	if not audio is Dictionary or audio.size() != 6 or not audio.get("muted") is bool:
		return false
	for bus: String in ["Master", "Music", "Ambience", "Effects", "UI"]:
		var value: Variant = audio.get(bus)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
			return false
	return true


func set_audio(audio: Dictionary) -> Error:
	if not valid_audio(audio):
		return ERR_INVALID_PARAMETER
	_document["audio"] = audio.duplicate(true)
	settings_changed.emit()
	return OK


static func valid_document(document: Variant) -> bool:
	if not document is Dictionary or document.size() not in [3, 4, 5]:
		return false
	if not InputBindings.is_integer(document.get("schema_version")) \
		or float(document["schema_version"]) != 1.0:
		return false
	for key: Variant in document:
		if key not in ["schema_version", "deadzone", "bindings", "audio", "accessibility"]:
			return false
	if document.has("accessibility") and not valid_accessibility(document.accessibility):
		return false
	if document.has("audio") and not valid_audio(document.audio):
		return false
	var value: Variant = document.get("deadzone")
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return false
	return is_finite(float(value)) and float(value) >= 0.1 and float(value) <= 0.9 \
		and InputBindings.valid_bindings(document.get("bindings"))


func snapshot() -> Dictionary:
	return _document.duplicate(true)


func reset_defaults() -> void:
	_document = default_document()
	settings_changed.emit()


func set_deadzone(value: float) -> Error:
	if not is_finite(value) or value < 0.1 or value > 0.9:
		return ERR_INVALID_PARAMETER
	_document["deadzone"] = value
	settings_changed.emit()
	return OK


func remap(action: StringName, event: InputEvent) -> Error:
	if action not in InputBindings.ACTIONS:
		return ERR_INVALID_PARAMETER
	var replacement: Dictionary = InputBindings.from_event(event)
	if not InputBindings.valid_descriptor(replacement):
		return ERR_INVALID_PARAMETER
	var next: Dictionary = snapshot()
	var entries: Array[Dictionary] = []
	for entry: Dictionary in next["bindings"][String(action)]:
		if (entry["kind"] == "key") != (replacement["kind"] == "key"):
			entries.append(entry)
	entries.append(replacement)
	next["bindings"][String(action)] = entries
	if not valid_document(next):
		return ERR_INVALID_PARAMETER
	_document = next
	settings_changed.emit()
	return OK


func load_settings(path: String = DEFAULT_PATH) -> Error:
	last_load_result = _read_settings(path)
	return last_load_result


func _read_settings(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	if file.get_length() > MAX_BYTES:
		return ERR_INVALID_DATA
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not valid_document(json.data):
		return ERR_INVALID_DATA
	_document = {
		"schema_version": 1,
		"deadzone": float(json.data["deadzone"]),
		"bindings": InputBindings.normalized(json.data["bindings"]),
		"audio": json.data.get("audio", default_audio()).duplicate(true),
		"accessibility": json.data.get("accessibility", default_accessibility()).duplicate(true),
	}
	settings_changed.emit()
	return OK


func save_settings(path: String = DEFAULT_PATH) -> Error:
	# Explicit Save may recover invalid preferences, but retains rejected bytes first.
	if FileAccess.file_exists(path):
		var probe: SettingsStore = SettingsStore.new()
		if probe.load_settings(path) != OK:
			if FileAccess.file_exists(path + ".invalid"):
				return ERR_ALREADY_EXISTS
			var kept: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".invalid"))
			if kept != OK:
				return kept
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_document, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	else:
		last_load_result = OK
	return error
