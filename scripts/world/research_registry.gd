class_name ResearchRegistry
extends Node
## Completion is permanent and idempotent; restoration never replays domain events.

signal scan_completed(target_id: StringName)
signal records_changed
var _catalog: ResearchCatalog
var _completed: Dictionary[StringName, bool] = {}


func configure(catalog: ResearchCatalog) -> Error:
	if catalog == null or not catalog.is_valid():
		return ERR_INVALID_PARAMETER
	if _catalog != null:
		return ERR_ALREADY_IN_USE
	_catalog = catalog.duplicate(true) as ResearchCatalog
	return OK


func region_id() -> StringName:
	return _catalog.region_id if _catalog != null else &""


func knows_id(id: StringName) -> bool:
	return definition(id) != null


func definition(id: StringName) -> ScanDefinition:
	if _catalog != null:
		for entry: ScanDefinition in _catalog.targets:
			if entry.stable_id == id:
				return entry.duplicate(true) as ScanDefinition
	return null


func is_completed(id: StringName) -> bool:
	return _completed.has(id)


func complete_scan(id: StringName) -> Error:
	# Trusted scanner completion adapter, not a UI or sonar receipt command.
	if not knows_id(id):
		return ERR_INVALID_PARAMETER
	if is_completed(id):
		return ERR_ALREADY_EXISTS
	_completed[id] = true
	scan_completed.emit(id)
	records_changed.emit()
	return OK


func completed_ids() -> Array[StringName]:
	var ids: Array[StringName] = _completed.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func restore_completed(ids: Array[StringName]) -> Error:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if not knows_id(id) or seen.has(id):
			return ERR_INVALID_DATA
		seen[id] = true
	for id: StringName in ids:
		_completed[id] = true
	records_changed.emit()
	return OK


func completed_records() -> Array[ScanDefinition]:
	var result: Array[ScanDefinition] = []
	for id: StringName in completed_ids():
		result.append(definition(id))
	return result
