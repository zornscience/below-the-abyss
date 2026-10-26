extends GutTest

const CATALOG: ResearchCatalog = preload("res://resources/regions/shelf_research.tres")
var _registry: ResearchRegistry
var _store: ResearchStore


func before_each() -> void:
	_registry = _new_registry()
	_store = ResearchStore.new()
	_store.path = "user://bta024-store-%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".bak.tmp", ".rejected"]:
		if FileAccess.file_exists(_store.path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_store.path + suffix))


func _new_registry() -> ResearchRegistry:
	var result: ResearchRegistry = ResearchRegistry.new()
	add_child_autofree(result)
	assert_eq(result.configure(CATALOG), OK)
	return result


func _write(text: String, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(_store.path + suffix, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _document() -> Dictionary:
	return {"format": "bta-research", "schema_version": 1, "region_id": "continental_shelf",
		"completed_target_ids": ["shelf-calibration-plate"]}


func test_missing_file_roundtrip_atomic_replace_and_last_valid_backup() -> void:
	assert_eq(_store.load_registry(_registry), ERR_FILE_NOT_FOUND)
	_registry.complete_scan(&"shelf-calibration-plate")
	assert_eq(_store.save_registry(_registry), OK)
	var original: String = FileAccess.get_file_as_string(_store.path)
	_registry.complete_scan(&"shelf-overlook-formation")
	assert_eq(_store.save_registry(_registry), OK)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".bak"), original)
	assert_false(FileAccess.file_exists(_store.path + ".tmp"))
	var reloaded: ResearchRegistry = _new_registry()
	assert_eq(_store.load_registry(reloaded), OK)
	assert_eq(reloaded.completed_ids(), _registry.completed_ids())
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(_store.path)).size(), 4)


func test_corrupt_unknown_ids_duplicates_and_wrong_types_never_partially_load_or_overwrite() -> void:
	var invalid: Array[Variant] = [null, [], true, {"schema_version": 1}]
	for value: Variant in [["shelf-calibration-plate", "unknown"], ["shelf-calibration-plate", "shelf-calibration-plate"], [1], {}, null]:
		var data: Dictionary = _document()
		data.completed_target_ids = value
		invalid.append(data)
	var wrong_region: Dictionary = _document()
	wrong_region.region_id = "another_region"
	invalid.append(wrong_region)
	for value: Variant in invalid:
		var text: String = JSON.stringify(value)
		_write(text)
		assert_eq(_store.load_registry(_registry), ERR_INVALID_DATA)
		assert_eq(_store.save_registry(_registry), ERR_UNAUTHORIZED)
		assert_eq(FileAccess.get_file_as_string(_store.path), text)
		assert_true(_registry.completed_ids().is_empty())
	_write("{broken")
	assert_eq(_store.load_registry(_registry), ERR_INVALID_DATA)


func test_incompatible_version_and_oversize_are_preserved() -> void:
	var data: Dictionary = _document()
	data.schema_version = 99
	var text: String = JSON.stringify(data)
	_write(text)
	assert_eq(_store.load_registry(_registry), ERR_UNAVAILABLE)
	assert_eq(_store.retry_save(_registry), ERR_UNAVAILABLE)
	assert_eq(FileAccess.get_file_as_string(_store.path), text)
	_write(" ".repeat(ResearchStore.MAX_BYTES + 1))
	assert_eq(_store.load_registry(_registry), ERR_INVALID_DATA)


func test_external_corruption_blocks_save_without_destroying_valid_backup() -> void:
	assert_eq(_store.load_registry(_registry), ERR_FILE_NOT_FOUND)
	assert_eq(_store.save_registry(_registry), OK)
	_registry.complete_scan(&"shelf-calibration-plate")
	assert_eq(_store.save_registry(_registry), OK)
	var backup: String = FileAccess.get_file_as_string(_store.path + ".bak")
	_write("corrupt externally")
	assert_eq(_store.save_registry(_registry), ERR_INVALID_DATA)
	assert_eq(FileAccess.get_file_as_string(_store.path), "corrupt externally")
	assert_eq(FileAccess.get_file_as_string(_store.path + ".bak"), backup)


func test_explicit_backup_recovery_preserves_rejected_file_and_unsaved_records() -> void:
	_write(JSON.stringify(_document()), ".bak")
	_write("rejected content")
	assert_eq(_store.load_registry(_registry), ERR_INVALID_DATA)
	_registry.complete_scan(&"shelf-overlook-formation")
	assert_eq(_store.recover_backup(_registry), OK)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".rejected"), "rejected content")
	assert_eq(_registry.completed_ids(), [&"shelf-calibration-plate", &"shelf-overlook-formation"])
	assert_eq(_store.recover_backup(_registry), ERR_ALREADY_EXISTS)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".rejected"), "rejected content")


func test_invalid_or_missing_backup_and_failed_write_preserve_memory() -> void:
	assert_eq(_store.recover_backup(_registry), ERR_FILE_NOT_FOUND)
	_write("bad backup", ".bak")
	assert_eq(_store.recover_backup(_registry), ERR_INVALID_DATA)
	_registry.complete_scan(&"shelf-calibration-plate")
	var original: String = _store.path
	_store.path = original + "/not-a-directory/data.json"
	# A regular file in the parent chain makes directory creation fail deterministically.
	var file: FileAccess = FileAccess.open(original, FileAccess.WRITE)
	file.store_string("block")
	file.close()
	assert_eq(_store.load_registry(_registry), ERR_FILE_NOT_FOUND)
	assert_ne(_store.save_registry(_registry), OK)
	assert_eq(_registry.completed_ids(), [&"shelf-calibration-plate"])
	_store.path = original


func test_retry_after_manual_file_repair_merges_and_saves_pending_records() -> void:
	_write("bad")
	assert_eq(_store.load_registry(_registry), ERR_INVALID_DATA)
	_registry.complete_scan(&"shelf-overlook-formation")
	_write(JSON.stringify(_document()))
	assert_eq(_store.retry_save(_registry), OK)
	var reloaded: ResearchRegistry = _new_registry()
	assert_eq(_store.load_registry(reloaded), OK)
	assert_eq(reloaded.completed_ids(), [&"shelf-calibration-plate", &"shelf-overlook-formation"])
