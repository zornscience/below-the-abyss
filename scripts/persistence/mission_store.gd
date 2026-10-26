class_name MissionStore
extends RefCounted
## Mission records only. Backup is a write-ahead checkpoint, not an economic ledger.

signal status_changed
const DEFAULT_PATH: String = "user://saves/missions.json"
const MAX_BYTES: int = 16384
var path: String = DEFAULT_PATH
var status: String = "Missions not loaded."
var _writable: bool = false


func _report(message: String, result: Error) -> Error:
	status = message
	status_changed.emit()
	return result


func _read(candidate: String, catalog: MissionCatalog) -> Dictionary:
	if not FileAccess.file_exists(candidate):
		return {"error": ERR_FILE_NOT_FOUND}
	var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error()}
	if file.get_length() > MAX_BYTES:
		return {"error": ERR_INVALID_DATA}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {"error": ERR_INVALID_DATA}
	var data: Dictionary = json.data
	if not InputBindings.is_integer(data.get("schema_version")):
		return {"error": ERR_INVALID_DATA}
	if float(data.schema_version) != 1.0:
		return {"error": ERR_UNAVAILABLE}
	if data.size() != 4 or data.get("format") != "bta-missions" or data.get("catalog_id") != String(catalog.stable_id) \
		or not data.get("missions") is Dictionary or not catalog.valid_records(data.missions):
		return {"error": ERR_INVALID_DATA}
	return {"error": OK, "records": data.missions}


func load_records(catalog: MissionCatalog) -> Dictionary:
	_writable = false
	var document: Dictionary = _read(path, catalog)
	if document.error == ERR_FILE_NOT_FOUND and FileAccess.file_exists(path + ".bak"):
		_report("Mission primary missing; backup preserved. Explicit recovery required.", ERR_FILE_NOT_FOUND)
		return document
	if document.error == OK or document.error == ERR_FILE_NOT_FOUND:
		_writable = true
		_report("Missions loaded." if document.error == OK else "New mission record; choose Accept at the station.", document.error)
	else:
		_report("Mission file unreadable (%s); progress writes blocked. Recover backup or inspect file." % error_string(document.error), document.error)
	return document


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




func save_records(records: Dictionary, catalog: MissionCatalog) -> Error:
	if not catalog.valid_records(records):
		return _report("Invalid mission state; file unchanged.", ERR_INVALID_DATA)
	if not _writable:
		return _report("Mission saving blocked to preserve existing progress. Recover backup or inspect file.", ERR_UNAUTHORIZED)
	var previous: Dictionary = _read(path, catalog)
	if previous.error != OK and previous.error != ERR_FILE_NOT_FOUND:
		_writable = false
		return _report("Mission file became unreadable; original preserved.", previous.error)
	# Include every previously persisted claim/objective, never roll back through a stale caller.
	var merged: Dictionary = catalog.merge_records(records, previous.records) if previous.error == OK else records
	if FileAccess.file_exists(path + ".bak"):
		var checkpoint: Dictionary = _read(path + ".bak", catalog)
		if checkpoint.error != OK:
			_writable = false
			return _report("Mission backup unreadable; checkpoint preserved. Inspect files before continuing.", checkpoint.error)
		merged = catalog.merge_records(merged, checkpoint.records)
	if merged != records:
		_writable = false
		return _report("Mission file changed; reload/recover before continuing.", ERR_BUSY)
	var text: String = JSON.stringify({"format": "bta-missions", "schema_version": 1,
		"catalog_id": String(catalog.stable_id), "missions": records}, "\t")
	# The successful transition's backup contains its claim too, avoiding old pre-claim replay.
	var result: Error = _atomic_write(path + ".bak", text)
	if result == OK:
		result = _atomic_write(path, text)
	return _report("Mission progress saved." if result == OK else "Mission transition not applied; save failed (%s)." % error_string(result), result)


func recover_backup(catalog: MissionCatalog, current: Dictionary) -> Dictionary:
	var backup: Dictionary = _read(path + ".bak", catalog)
	if backup.error != OK:
		_report("Mission backup not recovered (%s); files/progress preserved." % error_string(backup.error), backup.error)
		return backup
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".rejected"):
			_report("Recovery blocked: .rejected already exists. Preserve/move it before retrying.", ERR_ALREADY_EXISTS)
			return {"error": ERR_ALREADY_EXISTS}
		var result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".rejected"))
		if result != OK:
			return {"error": _report("Could not preserve current mission file.", result)}
	var restored: Dictionary = catalog.merge_records(current, backup.records)
	_writable = true
	var result: Error = save_records(restored, catalog)
	return {"error": result, "records": restored}


func can_write() -> bool:
	return _writable
