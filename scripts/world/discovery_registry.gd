class_name DiscoveryRegistry
extends Node
## Permanent POI state, independent of echo lifetime, acoustic history and route checks.

signal point_discovered(poi_id: StringName)
signal registry_changed

enum State { HIDDEN, DISCOVERED }
var _catalog: DiscoveryCatalog
var _discovered: Dictionary[StringName, bool] = {}
var _bindings: Dictionary[StringName, WeakRef] = {}


func configure(catalog: DiscoveryCatalog) -> Error:
	if catalog == null or not catalog.is_valid():
		return ERR_INVALID_PARAMETER
	if _catalog != null:
		return ERR_ALREADY_IN_USE
	_catalog = catalog.duplicate(true) as DiscoveryCatalog
	registry_changed.emit()
	return OK


func region_id() -> StringName:
	return _catalog.region_id if _catalog != null else &""


func survey_bounds() -> Rect2:
	return _catalog.survey_bounds if _catalog != null else Rect2()


func knows_id(id: StringName) -> bool:
	if _catalog != null:
		for point: PointOfInterest in _catalog.points:
			if point.stable_id == id:
				return true
	return false


func state_of(id: StringName) -> int:
	return State.DISCOVERED if _discovered.has(id) else State.HIDDEN


func discover(id: StringName, evidence_id: StringName) -> Error:
	# Trusted gameplay adapter API, not an acoustic receipt or UI command.
	if not knows_id(id) or not AcousticEvent.valid_token(evidence_id):
		return ERR_INVALID_PARAMETER
	if _discovered.has(id):
		return ERR_ALREADY_EXISTS
	_discovered[id] = true
	point_discovered.emit(id)
	registry_changed.emit()
	return OK


func is_sonar_bound(target: SonarRevealTarget) -> bool:
	for reference: WeakRef in _bindings.values():
		if reference.get_ref() == target:
			return true
	return false


func connect_sonar_target(target: SonarRevealTarget) -> Error:
	if target == null or not target.is_inside_tree() or target.is_queued_for_deletion() or _catalog == null:
		return ERR_INVALID_PARAMETER
	var poi_id: StringName = &""
	for point: PointOfInterest in _catalog.points:
		if point.sonar_target_id == target.target_id:
			poi_id = point.stable_id
	if poi_id == &"":
		return ERR_DOES_NOT_EXIST
	if _bindings.has(poi_id):
		var previous: SonarRevealTarget = _bindings[poi_id].get_ref() as SonarRevealTarget
		if previous == target:
			return OK
		if is_instance_valid(previous) and previous.is_inside_tree():
			return ERR_ALREADY_EXISTS
	_bindings[poi_id] = weakref(target)
	var authored_target: StringName = target.target_id
	var reference: WeakRef = weakref(target)
	target.revealed_for_ping.connect(func(event_id: StringName) -> void:
		var live: SonarRevealTarget = reference.get_ref() as SonarRevealTarget
		if is_instance_valid(live) and live.is_inside_tree() and not live.is_queued_for_deletion() \
			and live.target_id == authored_target:
			discover(poi_id, event_id))
	return OK


func discovered_ids() -> Array[StringName]:
	var ids: Array[StringName] = _discovered.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func restore_discoveries(ids: Array[StringName]) -> Error:
	# Validate everything before merging. Recovery never erases unsaved discoveries.
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if not knows_id(id) or seen.has(id):
			return ERR_INVALID_DATA
		seen[id] = true
	for id: StringName in ids:
		_discovered[id] = true
	registry_changed.emit()
	return OK


func discovered_points() -> Array[PointOfInterest]:
	var result: Array[PointOfInterest] = []
	if _catalog != null:
		for point: PointOfInterest in _catalog.points:
			if _discovered.has(point.stable_id):
				result.append(point.duplicate(true) as PointOfInterest)
	result.sort_custom(func(a: PointOfInterest, b: PointOfInterest) -> bool: return String(a.stable_id) < String(b.stable_id))
	return result
