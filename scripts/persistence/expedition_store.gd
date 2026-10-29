class_name ExpeditionStore
extends RefCounted
## Canonical expedition checkpoint. Always preserve unreadable data until explicit recovery.

const DEFAULT_PATH: String = "user://saves/expedition.json"
const MAX_BYTES: int = 65536
var path: String = DEFAULT_PATH
var _writable: bool = false


func read_file(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate):
		return {"error": ERR_FILE_NOT_FOUND}
	var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error()}
	if file.get_length() > MAX_BYTES:
		return {"error": ERR_INVALID_DATA}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"error": ERR_INVALID_DATA}
	return ExpeditionSchema.decode(json.data)


func load_checkpoint() -> Dictionary:
	var result: Dictionary = read_file(path)
	_writable = result.error == OK or (result.error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path + ".bak"))
	return result


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





func write_checkpoint(data: Dictionary) -> Error:
	if not _writable:
		return ERR_UNAUTHORIZED
	if ExpeditionSchema.decode(data).error != OK:
		return ERR_INVALID_DATA
	var previous: Dictionary = read_file(path)
	if previous.error != OK and previous.error != ERR_FILE_NOT_FOUND:
		_writable = false
		return previous.error
	# Monotonic records cannot be rolled back by stale writers or a deleted primary.
	for candidate: String in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var document: Dictionary = read_file(candidate)
			if document.error != OK:
				_writable = false
				return document.error
			if document.data.journey.commissioned and not data.journey.commissioned: return ERR_BUSY
			if not StoryState.extends_history(data.story,document.data.story): return ERR_BUSY
			if not CampaignData.contains_earned(data.prototype.campaign,document.data.prototype.campaign): return ERR_BUSY
			if ExpeditionSchema.merge_progress(data.progress, document.data.progress) != data.progress:
				return ERR_BUSY
	var text: String = JSON.stringify(data, "\t")
	# Latest valid progress (including claims) is in the backup before primary replacement.
	var result: Error = _atomic_write(path + ".bak", text)
	return _atomic_write(path, text) if result == OK else result


func recover_checkpoint(current_progress: Dictionary, current_prototype: Dictionary = {}, current_story: Dictionary = {}, current_journey: Dictionary = {}) -> Dictionary:
	var backup: Dictionary = read_file(path + ".bak")
	if backup.error != OK:
		return backup
	var restored: Dictionary = backup.data
	if current_journey.get("commissioned",false): restored.journey.commissioned = true
	if not current_story.is_empty():
		var merged_story: Dictionary = StoryState.merge_snapshots(restored.story,current_story)
		if merged_story.error!=OK: return merged_story
		restored.story = merged_story.data
	restored.progress = ExpeditionSchema.merge_progress(restored.progress, current_progress)
	if ExpeditionSchema.valid_prototype(current_prototype):
		restored.prototype.campaign = CampaignData.merge_earned(restored.prototype.campaign,current_prototype.campaign)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".rejected"):
			return {"error": ERR_ALREADY_EXISTS}
		var move: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".rejected"))
		if move != OK:
			return {"error": move}
	_writable = true
	var result: Error = write_checkpoint(restored)
	return {"error": result, "data": restored}
