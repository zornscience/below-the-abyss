class_name PlaytestStore
extends RefCounted
## Local, bounded, validated JSON and derived text. Never executes data or sends it.
var directory: String = "user://playtests"


func read_report(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "data": {}}
	if file.get_length() > PlaytestReport.MAX_BYTES:
		return {"error": ERR_INVALID_DATA, "data": {}}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not PlaytestReport.valid(json.data):
		return {"error": ERR_INVALID_DATA, "data": {}}
	return {"error": OK, "data": json.data}


func _atomic(path: String, text: String) -> Error:
	if FileAccess.file_exists(path + ".tmp"):
		return ERR_ALREADY_EXISTS
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	return result


func write_report(data: Dictionary, include_summary: bool = false) -> Error:
	if not PlaytestReport.valid(data):
		return ERR_INVALID_DATA
	var result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if result != OK:
		return result
	var path: String = directory.path_join(String(data.session_id) + ".json")
	if not FileAccess.file_exists(path):
		var primary_count: int = 0
		for name: String in DirAccess.get_files_at(directory):
			if name.ends_with(".json"):
				primary_count += 1
		if primary_count >= 64:
			return ERR_OUT_OF_MEMORY
	if FileAccess.file_exists(path):
		var original: Dictionary = read_report(path)
		if original.error != OK or original.data.session_id != data.session_id:
			return ERR_INVALID_DATA
		result = _atomic(path + ".bak", FileAccess.get_file_as_string(path))
		if result != OK:
			return result
	result = _atomic(path, JSON.stringify(data, "\t"))
	if result == OK and include_summary:
		result = _atomic(directory.path_join(String(data.session_id) + "-summary.txt"), PlaytestReport.summary(data))
	return result
