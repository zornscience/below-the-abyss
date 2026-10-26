extends GutTest

const CATALOG: UpgradeCatalog = preload("res://resources/equipment/shelf_upgrades.tres")
const SONAR: StringName = &"sonar-range-1200"
const HULL: StringName = &"pressure-hull-400"
var _store: UpgradeStore


func before_each() -> void:
	_store = UpgradeStore.new()
	_store.path = "user://bta033-store-%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
		if FileAccess.file_exists(_store.path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_store.path + suffix))


func _write(text: String, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(_store.path + suffix, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _document() -> Dictionary:
	return {"format": "bta-upgrades", "schema_version": 1, "catalog_id": "neris-prototype", "installed_upgrade_ids": [String(SONAR)]}


func test_catalog_has_precisely_two_unique_stable_absolute_upgrades() -> void:
	assert_true(CATALOG.is_valid())
	assert_eq(CATALOG.upgrades.size(), 2)
	assert_eq(CATALOG.upgrades[0].baseline_value, 900.0)
	assert_eq(CATALOG.upgrades[0].upgraded_value, 1200.0)
	assert_eq(CATALOG.upgrades[1].baseline_value, 300.0)
	assert_eq(CATALOG.upgrades[1].upgraded_value, 400.0)
	assert_true(CATALOG.valid_ids([SONAR, HULL]))
	assert_false(CATALOG.valid_ids([SONAR, SONAR]))
	assert_false(CATALOG.valid_ids([&"unknown"]))


func test_invalid_authored_definitions_and_baselines_rejected() -> void:
	for value: float in [NAN, INF, -1.0, 0.0, 900.0, 1000001.0]:
		var catalog: UpgradeCatalog = CATALOG.duplicate(true) as UpgradeCatalog
		catalog.upgrades[0].upgraded_value = value
		assert_false(catalog.is_valid())
	var wrong: UpgradeCatalog = CATALOG.duplicate(true) as UpgradeCatalog
	wrong.upgrades[0].baseline_value = 901.0
	assert_false(wrong.is_valid())
	wrong = CATALOG.duplicate(true) as UpgradeCatalog
	wrong.upgrades[1].stable_id = SONAR
	assert_false(wrong.is_valid())
	wrong = CATALOG.duplicate(true) as UpgradeCatalog
	wrong.upgrades[1].capability = UpgradeDefinition.Capability.SONAR_RADIUS
	assert_false(wrong.is_valid())
	wrong = CATALOG.duplicate(true) as UpgradeCatalog
	wrong.upgrades.append(wrong.upgrades[0])
	assert_false(wrong.is_valid())


func test_missing_roundtrip_last_good_backup_and_no_runtime_values_saved() -> void:
	assert_eq(_store.load_ids(CATALOG).error, ERR_FILE_NOT_FOUND)
	assert_eq(_store.save_ids([SONAR], CATALOG), OK)
	var previous: String = FileAccess.get_file_as_string(_store.path)
	assert_eq(_store.save_ids([HULL, SONAR], CATALOG), OK)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".bak"), previous)
	assert_false(FileAccess.file_exists(_store.path + ".tmp"))
	var fresh: UpgradeStore = UpgradeStore.new()
	fresh.path = _store.path
	var document: Dictionary = fresh.load_ids(CATALOG)
	assert_eq(document.error, OK)
	assert_eq(document.ids, [HULL, SONAR])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_store.path))
	assert_eq(data.size(), 4)
	assert_false(data.has("maximum_radius"))
	assert_false(data.has("position"))


func test_strict_invalid_documents_block_install_without_partial_state_or_overwrite() -> void:
	var invalid: Array[Variant] = [null, [], true, {"schema_version": 1}]
	for ids: Variant in [[String(SONAR), "unknown"], [String(SONAR), String(SONAR)], [1], [true], {}, null, [String(SONAR), String(HULL), "extra"]]:
		var document: Dictionary = _document()
		document.installed_upgrade_ids = ids
		invalid.append(document)
	for field: String in ["format", "catalog_id"]:
		var document: Dictionary = _document()
		document[field] = "wrong"
		invalid.append(document)
	var extra: Dictionary = _document()
	extra.currency = 100
	invalid.append(extra)
	for value: Variant in invalid:
		var text: String = JSON.stringify(value)
		_write(text)
		assert_eq(_store.load_ids(CATALOG).error, ERR_INVALID_DATA)
		assert_eq(_store.save_ids([SONAR], CATALOG), ERR_UNAUTHORIZED)
		assert_eq(FileAccess.get_file_as_string(_store.path), text)


func test_incompatible_schema_fractional_boolean_and_oversize_rejected() -> void:
	for version: Variant in [2, -1, 1.5, true, "1", null]:
		var document: Dictionary = _document()
		document.schema_version = version
		_write(JSON.stringify(document))
		assert_ne(_store.load_ids(CATALOG).error, OK)
		assert_eq(_store.save_ids([], CATALOG), ERR_UNAUTHORIZED)
	_write("{" )
	assert_eq(_store.load_ids(CATALOG).error, ERR_INVALID_DATA)
	_write(" ".repeat(UpgradeStore.MAX_BYTES + 1))
	assert_eq(_store.load_ids(CATALOG).error, ERR_INVALID_DATA)


func test_external_corruption_retains_backup_and_blocks_subsequent_write() -> void:
	_store.load_ids(CATALOG)
	assert_eq(_store.save_ids([], CATALOG), OK)
	assert_eq(_store.save_ids([SONAR], CATALOG), OK)
	var backup: String = FileAccess.get_file_as_string(_store.path + ".bak")
	_write("broken externally")
	assert_eq(_store.save_ids([SONAR, HULL], CATALOG), ERR_INVALID_DATA)
	assert_eq(FileAccess.get_file_as_string(_store.path), "broken externally")
	assert_eq(FileAccess.get_file_as_string(_store.path + ".bak"), backup)


func test_explicit_recovery_preserves_rejected_and_never_overwrites_it() -> void:
	_write(JSON.stringify(_document()), ".bak")
	_write("bad primary")
	assert_eq(_store.load_ids(CATALOG).error, ERR_INVALID_DATA)
	var recovered: Dictionary = _store.recover_backup(CATALOG)
	assert_eq(recovered.error, OK)
	assert_eq(recovered.ids, [SONAR])
	assert_eq(FileAccess.get_file_as_string(_store.path + ".rejected"), "bad primary")
	assert_eq(_store.load_ids(CATALOG).ids, [SONAR])
	assert_eq(_store.recover_backup(CATALOG).error, ERR_ALREADY_EXISTS)
	assert_eq(FileAccess.get_file_as_string(_store.path + ".rejected"), "bad primary")


func test_missing_bad_backup_and_failed_write_are_safe() -> void:
	assert_eq(_store.recover_backup(CATALOG).error, ERR_FILE_NOT_FOUND)
	_write("bad backup", ".bak")
	assert_eq(_store.recover_backup(CATALOG).error, ERR_INVALID_DATA)
	_write("blocks parent")
	var original: String = _store.path
	_store.path += "/child/file.json"
	assert_eq(_store.load_ids(CATALOG).error, ERR_FILE_NOT_FOUND)
	assert_ne(_store.save_ids([SONAR], CATALOG), OK)
	assert_eq(FileAccess.get_file_as_string(original), "blocks parent")
	_store.path = original
