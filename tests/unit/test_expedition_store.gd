extends GutTest

var _store: ExpeditionStore


func before_each() -> void:
	_store = ExpeditionStore.new()
	_store.path = "user://bta035-store-%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
		if FileAccess.file_exists(_store.path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_store.path + suffix))


func _document() -> Dictionary:
	return ExpeditionSchema.decode(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json"))).data


func _write(text: String, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(_store.path + suffix, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_version_one_migrates_in_memory_without_overwriting_original() -> void:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/expedition_v1.json")
	_write(text)
	var document: Dictionary = _store.load_checkpoint()
	assert_eq(document.error, OK)
	assert_true(document.migrated)
	assert_eq(document.data.schema_version, 2)
	assert_eq(document.data.player.rotation, 0.0)
	assert_eq(document.data.player.sonar_cooldown, 0.0)
	assert_eq(document.data.progress.missions["shelf-calibration-study"].state, "claimed")
	assert_eq(FileAccess.get_file_as_string(_store.path), text)
	assert_eq(_store.write_checkpoint(document.data), OK)
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(_store.path)).schema_version, 2.0)


func test_missing_atomic_roundtrip_and_checkpoint_backup_preserve_latest_claims() -> void:
	assert_eq(_store.load_checkpoint().error, ERR_FILE_NOT_FOUND)
	var data: Dictionary = _document()
	assert_eq(_store.write_checkpoint(data), OK)
	data.player.hull = 40.0
	assert_eq(_store.write_checkpoint(data), OK)
	assert_eq(_store.load_checkpoint().data, data)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".bak"), FileAccess.get_file_as_string(_store.path))
	assert_false(FileAccess.file_exists(_store.path + ".tmp"))


func test_wrong_versions_types_fields_regions_and_resource_bounds_are_rejected() -> void:
	var invalid: Array[Variant] = [null, [], true, {}]
	for key: String in ["format", "region_id", "legacy_imported"]:
		var data: Dictionary = _document()
		data[key] = "invalid"
		invalid.append(data)
	for value: Variant in [0, 3, -1, 1.1, true, "2"]:
		var data: Dictionary = _document()
		data.schema_version = value
		invalid.append(data)
	for key: String in ["hull", "battery", "oxygen", "sonar_cooldown", "rotation"]:
		for value: Variant in [-100.0, 101.0, true, null, "NaN"]:
			var data: Dictionary = _document()
			data.player[key] = value
			invalid.append(data)
	var extra: Dictionary = _document()
	extra.player.velocity = [999, 999]
	invalid.append(extra)
	for value: Variant in invalid:
		_write(JSON.stringify(value))
		assert_ne(_store.load_checkpoint().error, OK)
		assert_eq(_store.write_checkpoint(_document()), ERR_UNAUTHORIZED)


func test_invalid_position_structure_progress_and_route_never_partially_validate() -> void:
	for position: Variant in [null, {}, [1], [0, 0, 0], [true, 2], [1000001, 1]]:
		var data: Dictionary = _document()
		data.player.position = position
		assert_eq(ExpeditionSchema.decode(data).error, ERR_INVALID_DATA)
	for key: String in ["discoveries", "research", "upgrades"]:
		for ids: Variant in [["unknown"], [1], null, ["sonar-range-1200", "sonar-range-1200"]]:
			var data: Dictionary = _document()
			data.progress[key] = ids
			assert_eq(ExpeditionSchema.decode(data).error, ERR_INVALID_DATA)
	var data: Dictionary = _document()
	data.route.stage = 4
	assert_eq(ExpeditionSchema.decode(data).error, ERR_INVALID_DATA)
	data = _document()
	data.progress.missions["shelf-expedition"].state = "claimed"
	assert_eq(ExpeditionSchema.decode(data).error, ERR_INVALID_DATA)
	data = _document()
	data.player.hull = NAN
	assert_eq(ExpeditionSchema.decode(data).error, ERR_INVALID_DATA)


func test_corruption_explicit_recovery_keeps_rejected_claim_and_blocks_second_recovery() -> void:
	_store.load_checkpoint()
	_store.write_checkpoint(_document())
	_write("broken")
	assert_eq(_store.load_checkpoint().error, ERR_INVALID_DATA)
	assert_eq(_store.write_checkpoint(_document()), ERR_UNAUTHORIZED)
	var recovered: Dictionary = _store.recover_checkpoint(_document().progress)
	assert_eq(recovered.error, OK)
	assert_eq(recovered.data.progress.missions["shelf-calibration-study"].state, "claimed")
	assert_eq(FileAccess.get_file_as_string(_store.path + ".rejected"), "broken")
	assert_eq(_store.recover_checkpoint(_document().progress).error, ERR_ALREADY_EXISTS)


func test_missing_primary_with_backup_is_not_silently_replaced() -> void:
	_write(JSON.stringify(_document()), ".bak")
	assert_eq(_store.load_checkpoint().error, ERR_FILE_NOT_FOUND)
	assert_eq(_store.write_checkpoint(_document()), ERR_UNAUTHORIZED)
	assert_eq(_store.recover_checkpoint(_document().progress).error, OK)


func test_invalid_backup_size_limit_and_write_failure_preserve_originals() -> void:
	assert_eq(_store.recover_checkpoint(_document().progress).error, ERR_FILE_NOT_FOUND)
	_write("bad backup", ".bak")
	assert_eq(_store.recover_checkpoint(_document().progress).error, ERR_INVALID_DATA)
	_write(" ".repeat(ExpeditionStore.MAX_BYTES + 1))
	assert_eq(_store.load_checkpoint().error, ERR_INVALID_DATA)
	_write("regular parent file")
	var original: String = _store.path
	_store.path += "/child/expedition.json"
	_store.load_checkpoint()
	assert_ne(_store.write_checkpoint(_document()), OK)
	assert_eq(FileAccess.get_file_as_string(original), "regular parent file")
	_store.path = original


func test_stale_writer_cannot_remove_persistent_claim_or_upgrade() -> void:
	_store.load_checkpoint()
	var data: Dictionary = _document()
	_store.write_checkpoint(data)
	data.progress.upgrades = []
	assert_eq(_store.write_checkpoint(data), ERR_BUSY)
	assert_eq(_store.load_checkpoint().data.progress.upgrades, ["sonar-range-1200"])
