class_name MissionService
extends Node
## Scene-owned deterministic state machine; domain registries remain authoritative.

signal records_restored
signal missions_changed
signal mission_completed(mission_id: StringName)
signal acknowledgement_claimed(mission_id: StringName, acknowledgement_id: StringName)
var store: MissionStore = MissionStore.new()
var _catalog: MissionCatalog
var _records: Dictionary = {}
var _discoveries: DiscoveryRegistry
var _research: ResearchRegistry
var _route: GrayboxRouteCheck
var _busy: bool = false
var _route_returns: Dictionary[String, bool] = {}


func setup(catalog: MissionCatalog, discoveries: DiscoveryRegistry, research: ResearchRegistry,
		route: GrayboxRouteCheck, path: String) -> Error:
	if _catalog != null:
		return ERR_ALREADY_IN_USE
	if catalog == null or not catalog.is_valid() or discoveries == null or research == null or route == null:
		return ERR_INVALID_PARAMETER
	for definition: MissionDefinition in catalog.missions:
		for objective: MissionObjective in definition.objectives:
			if objective.kind == MissionObjective.Kind.DISCOVERY and not discoveries.knows_id(objective.target_id):
				return ERR_INVALID_PARAMETER
			if objective.kind == MissionObjective.Kind.SCAN and not research.knows_id(objective.target_id):
				return ERR_INVALID_PARAMETER
			if objective.kind == MissionObjective.Kind.ROUTE_RETURN and objective.target_id != &"continental-shelf-loop":
				return ERR_INVALID_PARAMETER
	_catalog = catalog.duplicate(true) as MissionCatalog
	_discoveries = discoveries
	_research = research
	_route = route
	_records = _catalog.initial_records()
	store.path = path
	var loaded: Dictionary = store.load_records(_catalog)
	if loaded.error == OK:
		_records = loaded.records.duplicate(true)
	discoveries.point_discovered.connect(_point_discovered)
	research.scan_completed.connect(_scan_completed)
	route.stage_changed.connect(_route_changed)
	# Restore silently. No completion/reward events are replayed by loading.
	missions_changed.emit()
	return OK


func definitions() -> Array[MissionDefinition]:
	var result: Array[MissionDefinition] = []
	if _catalog != null:
		for definition: MissionDefinition in _catalog.missions:
			result.append(definition.duplicate(true) as MissionDefinition)
	return result


func snapshot() -> Dictionary:
	return _records.duplicate(true)


func _satisfied(objective: MissionObjective) -> bool:
	match objective.kind:
		MissionObjective.Kind.DISCOVERY:
			return _discoveries.state_of(objective.target_id) == DiscoveryRegistry.State.DISCOVERED
		MissionObjective.Kind.SCAN:
			return _research.is_completed(objective.target_id)
		MissionObjective.Kind.ROUTE_RETURN:
			return _route.stage == GrayboxRouteCheck.Stage.COMPLETE
	return false


func _collect(candidate: Dictionary) -> void:
	for definition: MissionDefinition in _catalog.missions:
		var record: Dictionary = candidate[String(definition.stable_id)]
		if record.state != "accepted":
			continue
		for objective: MissionObjective in definition.objectives:
			var witnessed_return: bool = objective.kind == MissionObjective.Kind.ROUTE_RETURN and _route_returns.has(String(definition.stable_id) + "/" + String(objective.stable_id))
			if (_satisfied(objective) or witnessed_return) and String(objective.stable_id) not in record.objectives:
				record.objectives.append(String(objective.stable_id))
		record.objectives.sort()
		if record.objectives.size() == definition.objectives.size():
			record.state = "completed"


func _commit(candidate: Dictionary) -> Error:
	if candidate == _records:
		return OK
	_busy = true
	var result: Error = store.save_records(candidate, _catalog)
	if result == OK:
		var previous: Dictionary = _records
		_records = candidate
		missions_changed.emit()
		for definition: MissionDefinition in _catalog.missions:
			var id: String = String(definition.stable_id)
			if previous[id].state == "accepted" or previous[id].state == "available":
				if _records[id].state == "completed":
					mission_completed.emit(definition.stable_id)
			if _records[id].state == "claimed" and previous[id].state != "claimed":
				acknowledgement_claimed.emit(definition.stable_id, definition.acknowledgement_id)
	_busy = false
	return result


func accept(id: StringName) -> Error:
	if _busy:
		return ERR_BUSY
	if _catalog == null or _catalog.definition(id) == null:
		return ERR_INVALID_PARAMETER
	if _records[String(id)].state != "available":
		return ERR_ALREADY_EXISTS
	var candidate: Dictionary = snapshot()
	candidate[String(id)].state = "accepted"
	_collect(candidate)
	return _commit(candidate)


func claim(id: StringName) -> Error:
	if _busy:
		return ERR_BUSY
	if _catalog == null or _catalog.definition(id) == null:
		return ERR_INVALID_PARAMETER
	var state: String = _records[String(id)].state
	if state == "claimed":
		return ERR_ALREADY_EXISTS
	if state != "completed":
		return ERR_UNAVAILABLE
	var candidate: Dictionary = snapshot()
	candidate[String(id)].state = "claimed"
	return _commit(candidate)


func reconcile() -> Error:
	if _busy or _catalog == null:
		return ERR_BUSY
	var candidate: Dictionary = snapshot()
	_collect(candidate)
	return _commit(candidate)


func recover_backup() -> Error:
	if _busy or _catalog == null:
		return ERR_BUSY
	_busy = true
	var restored: Dictionary = store.recover_backup(_catalog, _records)
	if restored.error == OK:
		_records = restored.records
		missions_changed.emit()
		records_restored.emit()
	_busy = false
	return restored.error


func _point_discovered(_id: StringName) -> void:
	reconcile()


func _scan_completed(_id: StringName) -> void:
	reconcile()


func _route_changed(stage: GrayboxRouteCheck.Stage) -> void:
	if stage == GrayboxRouteCheck.Stage.COMPLETE:
		for definition: MissionDefinition in _catalog.missions:
			if _records[String(definition.stable_id)].state == "accepted":
				for objective: MissionObjective in definition.objectives:
					if objective.kind == MissionObjective.Kind.ROUTE_RETURN:
						_route_returns[String(definition.stable_id) + "/" + String(objective.stable_id)] = true
	reconcile()


func status_text() -> String:
	var lines: PackedStringArray = []
	for definition: MissionDefinition in definitions():
		var record: Dictionary = _records[String(definition.stable_id)]
		if record.state != "available":
			lines.append("%s / %s %d/%d" % [definition.title, String(record.state).to_upper(), record.objectives.size(), definition.objectives.size()])
	return "MISSIONS / Accept objectives at Shelf Base" if lines.is_empty() else "MISSIONS / " + " · ".join(lines)


func _exit_tree() -> void:
	if _route != null and _route.stage_changed.is_connected(_route_changed):
		_route.stage_changed.disconnect(_route_changed)


func restore_records(records: Dictionary) -> Error:
	if _busy or _catalog == null or not _catalog.valid_records(records):
		return ERR_INVALID_DATA
	_records = records.duplicate(true)
	records_restored.emit()
	# Retain bounded, witnessed returns on same-process recovery; fresh nodes start empty.
	missions_changed.emit()
	return OK
