class_name UpgradeStore
extends RefCounted
## Narrow ID-only BTA-033 save, using the discovery/research preservation policy.

signal status_changed
const DEFAULT_PATH: String = "user://saves/upgrades.json"
const MAX_BYTES: int = 4096
var path: String = DEFAULT_PATH
var status: String = "Upgrades not loaded."
var _writable: bool = false


func _report(message: String, result: Error) -> Error:
	status = message
	status_changed.emit()
	return result


func _read(candidate: String, catalog: UpgradeCatalog) -> Dictionary:
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
	if data.size() != 4 or data.get("format") != "bta-upgrades" or data.get("catalog_id") != String(catalog.stable_id) \
		or not data.get("installed_upgrade_ids") is Array or data.installed_upgrade_ids.size() > 2:
		return {"error": ERR_INVALID_DATA}
	var ids: Array[StringName] = []
	for value: Variant in data.installed_upgrade_ids:
		if not value is String or not PointOfInterest.valid_id(StringName(value)):
			return {"error": ERR_INVALID_DATA}
		ids.append(StringName(value))
	if not catalog.valid_ids(ids):
		return {"error": ERR_INVALID_DATA}
	return {"error": OK, "ids": ids, "text": text}


func load_ids(catalog: UpgradeCatalog) -> Dictionary:
	_writable = false
	var document: Dictionary = _read(path, catalog)
	if document.error == OK or document.error == ERR_FILE_NOT_FOUND:
		_writable = true
		_report("Installed upgrades loaded." if document.error == OK else "No upgrades file yet; FREE installation available.", document.error)
	else:
		_report("Upgrade file unreadable (%s). Baseline retained; installation blocked. Recover backup or inspect file." % error_string(document.error), document.error)
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



func save_ids(ids: Array[StringName], catalog: UpgradeCatalog) -> Error:
	if not catalog.valid_ids(ids):
		return _report("Invalid upgrade IDs; file unchanged.", ERR_INVALID_DATA)
	if not _writable:
		return _report("Installation blocked to preserve an unreadable upgrade file. Recover backup or inspect file.", ERR_UNAUTHORIZED)
	var previous: Dictionary = _read(path, catalog)
	if previous.error != OK and previous.error != ERR_FILE_NOT_FOUND:
		_writable = false
		return _report("Upgrade file changed or became unreadable; original preserved.", previous.error)
	var result: Error = OK
	if previous.error == OK:
		result = _atomic_write(path + ".bak", previous.text)
	if result == OK:
		var sorted: Array[StringName] = ids.duplicate()
		sorted.sort()
		result = _atomic_write(path, JSON.stringify({"format": "bta-upgrades", "schema_version": 1,
			"catalog_id": String(catalog.stable_id), "installed_upgrade_ids": sorted}, "\t"))
	return _report("Installed upgrades saved." if result == OK else "Installation not applied: save failed (%s)." % error_string(result), result)


func recover_backup(catalog: UpgradeCatalog) -> Dictionary:
	var backup: Dictionary = _read(path + ".bak", catalog)
	if backup.error != OK:
		_report("Backup not recovered (%s); current capabilities/files preserved." % error_string(backup.error), backup.error)
		return backup
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".rejected"):
			_report("Recovery blocked: .rejected already exists. Preserve/move it before retrying.", ERR_ALREADY_EXISTS)
			return {"error": ERR_ALREADY_EXISTS}
		var move: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".rejected"))
		if move != OK:
			_report("Could not preserve current file; recovery cancelled.", move)
			return {"error": move}
	var result: Error = _atomic_write(path, backup.text)
	if result != OK:
		_report("Backup write failed; capabilities unchanged. Files retained for retry.", result)
		return {"error": result}
	_writable = true
	_report("Upgrade backup recovered. Last-known-good installation IDs restored.", OK)
	return backup
