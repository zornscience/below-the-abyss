class_name DiscoveryStore
extends RefCounted
## Narrow BTA-023 POI file only. No player/resources/mission/slot serialization.

var checkpoint_writer: Callable
var last_result: Error = OK
signal status_changed
const DEFAULT_PATH: String = "user://saves/discoveries.json"
const MAX_BYTES: int = 16384
var path: String = DEFAULT_PATH
var status: String = "Discoveries not loaded."
var _writable: bool = false


func _report(message: String, result: Error) -> Error:
	last_result = result
	status = message
	status_changed.emit()
	return result


func _read(candidate: String, registry: DiscoveryRegistry) -> Dictionary:
	if not FileAccess.file_exists(candidate):
		return {"error": ERR_FILE_NOT_FOUND}
	var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error()}
	if file.get_length() > MAX_BYTES:
		return {"error": ERR_INVALID_DATA}
	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"error": ERR_INVALID_DATA}
	var data: Dictionary = json.data
	if not InputBindings.is_integer(data.get("schema_version")):
		return {"error": ERR_INVALID_DATA}
	if float(data.schema_version) != 1.0:
		return {"error": ERR_UNAVAILABLE}
	if data.size() != 4 or data.get("format") != "bta-discoveries" \
		or data.get("region_id") != String(registry.region_id()) \
		or not data.get("discovered_poi_ids") is Array or data.discovered_poi_ids.size() > 128:
		return {"error": ERR_INVALID_DATA}
	var ids: Array[StringName] = []
	for value: Variant in data.discovered_poi_ids:
		if not value is String or not PointOfInterest.valid_id(StringName(value)) \
			or not registry.knows_id(StringName(value)) or StringName(value) in ids:
			return {"error": ERR_INVALID_DATA}
		ids.append(StringName(value))
	return {"error": OK, "ids": ids, "text": text}


func load_registry(registry: DiscoveryRegistry) -> Error:
	_writable = false
	var document: Dictionary = _read(path, registry)
	var result: Error = document.error
	if result == ERR_FILE_NOT_FOUND:
		_writable = true
		return _report("No discovery file yet; new discoveries will be saved.", result)
	if result != OK:
		return _report("Discovery file not loaded (%s). File preserved; saving blocked. Recover backup or inspect the file." % error_string(result), result)
	registry.restore_discoveries(document.ids)
	_writable = true
	return _report("Discoveries loaded.", OK)


func _atomic_write(destination: String, text: String) -> Error:
	var absolute: String = ProjectSettings.globalize_path(destination)
	var parent: String = absolute.get_base_dir()
	var ancestor: String = parent
	while not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor):
			return ERR_CANT_CREATE
		var next: String = ancestor.get_base_dir()
		if next == ancestor:
			return ERR_CANT_CREATE
		ancestor = next
	var result: Error = DirAccess.make_dir_recursive_absolute(parent)
	if result != OK:
		return result
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	result = file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(temporary, absolute)
	if result != OK:
		DirAccess.remove_absolute(temporary)
	return result


func save_registry(registry: DiscoveryRegistry) -> Error:
	if checkpoint_writer.is_valid():
		var committed: Error = checkpoint_writer.call(&"discoveries", registry.discovered_ids())
		return _report("Progress committed to expedition checkpoint; legacy file preserved." if committed == OK else "Expedition checkpoint failed (%s); progress not committed." % error_string(committed), committed)
	if not _writable:
		return _report("Saving blocked to preserve an unreadable discovery file. Recover backup or inspect the file.", ERR_UNAUTHORIZED)
	# Revalidate before replacing: an externally corrupted/new-version file is not overwritten.
	var previous: Dictionary = _read(path, registry)
	if previous.error != OK and previous.error != ERR_FILE_NOT_FOUND:
		_writable = false
		return _report("Discovery file changed or became unreadable; saving blocked, original preserved.", previous.error)
	var result: Error = OK
	if previous.error == OK:
		result = _atomic_write(path + ".bak", previous.text)
	if result == OK:
		var document: Dictionary = {"format": "bta-discoveries", "schema_version": 1,
			"region_id": String(registry.region_id()), "discovered_poi_ids": registry.discovered_ids()}
		result = _atomic_write(path, JSON.stringify(document, "\t"))
	return _report("Discoveries saved." if result == OK else "Discoveries remain in memory; save failed (%s). Retry save." % error_string(result), result)


func recover_backup(registry: DiscoveryRegistry) -> Error:
	if checkpoint_writer.is_valid():
		_report("Use Recover expedition backup in the pause menu. Legacy files remain preserved.", ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE
	var backup: Dictionary = _read(path + ".bak", registry)
	if backup.error != OK:
		return _report("Backup not recovered (%s); current discoveries and files preserved." % error_string(backup.error), backup.error)
	# Explicit UI recovery preserves rejected data for inspection; never silently deletes it.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".rejected"):
			return _report("Recovery blocked: .rejected already exists. Preserve/move it before retrying.", ERR_ALREADY_EXISTS)
		var result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".rejected"))
		if result != OK:
			return _report("Could not preserve current file; recovery cancelled.", result)
	registry.restore_discoveries(backup.ids)
	_writable = true
	return save_registry(registry)


func retry_save(registry: DiscoveryRegistry) -> Error:
	if checkpoint_writer.is_valid():
		return save_registry(registry)
	var result: Error = load_registry(registry)
	return save_registry(registry) if result == OK or result == ERR_FILE_NOT_FOUND else result
