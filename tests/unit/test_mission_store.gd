extends GutTest

const CATALOG: MissionCatalog = preload("res://resources/missions/shelf_missions.tres")
var _store: MissionStore


func before_each() -> void:
	_store = MissionStore.new()
	_store.path = "user://bta034-store-%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
		if FileAccess.file_exists(_store.path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_store.path + suffix))


func _write(text: String, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(_store.path + suffix, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _document() -> Dictionary:
	return {"format": "bta-missions", "schema_version": 1, "catalog_id": "shelf-prototype", "missions": CATALOG.initial_records()}


func test_missing_roundtrip_atomic_checkpoint_contains_latest_claim() -> void:
	assert_eq(_store.load_records(CATALOG).error, ERR_FILE_NOT_FOUND)
	var records: Dictionary = CATALOG.initial_records()
	records["shelf-calibration-study"] = {"state": "claimed", "objectives": ["scan-calibration-plate"]}
	assert_eq(_store.save_records(records, CATALOG), OK)
	assert_eq(_store.load_records(CATALOG).records, records)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".bak"), FileAccess.get_file_as_string(_store.path))
	assert_false(FileAccess.file_exists(_store.path + ".tmp"))
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(_store.path)).size(), 4)


func test_invalid_states_ids_progress_and_reward_combinations_are_rejected() -> void:
	var invalid: Array[Variant] = [null, [], true, {}, {"schema_version": 1}]
	for record: Variant in [{"state": "unknown", "objectives": []}, {"state": "claimed", "objectives": []},
		{"state": "available", "objectives": ["scan-calibration-plate"]}, {"state": "accepted", "objectives": ["scan-calibration-plate"]},
		{"state": "accepted", "objectives": ["unknown"]}, {"state": "accepted", "objectives": [1]},
		{"state": "completed", "objectives": ["scan-calibration-plate", "scan-calibration-plate"]},
		{"state": "available", "objectives": [], "reward": 100}, null]:
		var data: Dictionary = _document()
		data.missions["shelf-calibration-study"] = record
		invalid.append(data)
	var unknown: Dictionary = _document()
	unknown.missions["unknown"] = {"state": "available", "objectives": []}
	invalid.append(unknown)
	for value: Variant in invalid:
		var text: String = JSON.stringify(value)
		_write(text)
		assert_eq(_store.load_records(CATALOG).error, ERR_INVALID_DATA)
		assert_eq(_store.save_records(CATALOG.initial_records(), CATALOG), ERR_UNAUTHORIZED)
		assert_eq(FileAccess.get_file_as_string(_store.path), text)


func test_wrong_schema_catalog_format_extra_fields_malformed_and_size_limit() -> void:
	for field: String in ["format", "catalog_id", "schema_version"]:
		var data: Dictionary = _document()
		data[field] = "wrong"
		_write(JSON.stringify(data))
		assert_ne(_store.load_records(CATALOG).error, OK)
	for version: Variant in [2, -1, 1.1, true, null]:
		var data: Dictionary = _document()
		data.schema_version = version
		_write(JSON.stringify(data))
		assert_ne(_store.load_records(CATALOG).error, OK)
	var extra: Dictionary = _document()
	extra.currency = 1
	_write(JSON.stringify(extra))
	assert_eq(_store.load_records(CATALOG).error, ERR_INVALID_DATA)
	_write("{")
	assert_eq(_store.load_records(CATALOG).error, ERR_INVALID_DATA)
	_write(" ".repeat(MissionStore.MAX_BYTES + 1))
	assert_eq(_store.load_records(CATALOG).error, ERR_INVALID_DATA)


func test_corruption_recovery_preserves_claim_and_rejected_and_blocks_second_recovery() -> void:
	_store.load_records(CATALOG)
	var records: Dictionary = CATALOG.initial_records()
	records["shelf-calibration-study"] = {"state": "claimed", "objectives": ["scan-calibration-plate"]}
	_store.save_records(records, CATALOG)
	_write("bad primary")
	assert_eq(_store.load_records(CATALOG).error, ERR_INVALID_DATA)
	assert_eq(_store.save_records(records, CATALOG), ERR_UNAUTHORIZED)
	var recovered: Dictionary = _store.recover_backup(CATALOG, CATALOG.initial_records())
	assert_eq(recovered.error, OK)
	assert_eq(recovered.records, records)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".rejected"), "bad primary")
	assert_eq(_store.recover_backup(CATALOG, records).error, ERR_ALREADY_EXISTS)


func test_missing_primary_with_backup_requires_explicit_recovery() -> void:
	_write(JSON.stringify(_document()), ".bak")
	assert_eq(_store.load_records(CATALOG).error, ERR_FILE_NOT_FOUND)
	assert_eq(_store.save_records(CATALOG.initial_records(), CATALOG), ERR_UNAUTHORIZED)
	assert_eq(_store.recover_backup(CATALOG, CATALOG.initial_records()).error, OK)


func test_monotonic_recovery_merge_and_stale_write_cannot_erase_claims() -> void:
	_store.load_records(CATALOG)
	var records: Dictionary = CATALOG.initial_records()
	records["shelf-calibration-study"] = {"state": "claimed", "objectives": ["scan-calibration-plate"]}
	_store.save_records(records, CATALOG)
	assert_eq(_store.save_records(CATALOG.initial_records(), CATALOG), ERR_BUSY)
	assert_eq(_store.load_records(CATALOG).records, records)
	_write(JSON.stringify(_document()), ".bak")
	var recovered: Dictionary = _store.recover_backup(CATALOG, records)
	assert_eq(recovered.error, OK)
	assert_eq(recovered.records, records)


func test_failed_write_and_missing_invalid_backup_preserve_files() -> void:
	assert_eq(_store.recover_backup(CATALOG, CATALOG.initial_records()).error, ERR_FILE_NOT_FOUND)
	_write("bad", ".bak")
	assert_eq(_store.recover_backup(CATALOG, CATALOG.initial_records()).error, ERR_INVALID_DATA)
	_write("blocks directory")
	var original: String = _store.path
	_store.path += "/child/file.json"
	_store.load_records(CATALOG)
	assert_ne(_store.save_records(CATALOG.initial_records(), CATALOG), OK)
	assert_eq(FileAccess.get_file_as_string(original), "blocks directory")
	_store.path = original


func test_deleted_or_stale_primary_cannot_overwrite_newer_claim_checkpoint() -> void:
	_store.load_records(CATALOG)
	var records: Dictionary = CATALOG.initial_records()
	records["shelf-calibration-study"] = {"state": "claimed", "objectives": ["scan-calibration-plate"]}
	_store.save_records(records, CATALOG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_store.path))
	assert_eq(_store.save_records(CATALOG.initial_records(), CATALOG), ERR_BUSY)
	assert_eq(_store.recover_backup(CATALOG, CATALOG.initial_records()).records, records)
	_write(JSON.stringify(_document()))
	assert_eq(_store.save_records(CATALOG.initial_records(), CATALOG), ERR_BUSY)
