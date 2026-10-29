class_name ScientificScanner
extends Node2D
## Toggle to start/cancel. Simulation owner advances exactly once per physics step.

signal state_changed
var _research: ResearchRegistry
var _discoveries: DiscoveryRegistry
var _targets: Dictionary[StringName, WeakRef] = {}
var _definitions: Dictionary[StringName,ScanDefinition] = {}
var _active: StringName
var _elapsed: float = 0.0
var _suspended: bool = false
var _feedback_seconds: float = 0.0
var _feedback: String = "SCANNER / OFFLINE"


func setup(research: ResearchRegistry, discoveries: DiscoveryRegistry, targets: Array[ScientificScanTarget]) -> Error:
	if research == null or discoveries == null or research.region_id() != discoveries.region_id() or targets.size() > 128:
		return ERR_INVALID_PARAMETER
	var prepared: Dictionary[StringName, WeakRef] = {}
	var definitions: Dictionary[StringName,ScanDefinition] = {}
	for target: ScientificScanTarget in targets:
		if target == null or not target.is_inside_tree() or prepared.has(target.target_id):
			return ERR_INVALID_PARAMETER
		var definition: ScanDefinition = research.definition(target.target_id)
		if definition == null or not discoveries.knows_id(definition.required_poi_id):
			return ERR_INVALID_PARAMETER
		prepared[target.target_id] = weakref(target)
		definitions[target.target_id] = definition
	_research = research
	_discoveries = discoveries
	_targets = prepared
	_definitions = definitions
	reset_session()
	return OK


func _target(id: StringName) -> ScientificScanTarget:
	var target: ScientificScanTarget = _targets[id].get_ref() as ScientificScanTarget if _targets.has(id) else null
	return target if is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.scan_enabled else null


func _known(id: StringName) -> bool:
	var definition: ScanDefinition = _definitions.get(id) as ScanDefinition
	return definition != null and (not definition.requires_sonar or _discoveries.state_of(definition.required_poi_id) == DiscoveryRegistry.State.DISCOVERED)


func _in_range(id: StringName) -> bool:
	var target: ScientificScanTarget = _target(id)
	var definition: ScanDefinition = _definitions.get(id) as ScanDefinition
	if target==null or definition==null or global_position.distance_to(target.global_position)>definition.radius: return false
	if (definition.requires_sonar and not definition.requires_clear_path) or not is_inside_tree(): return true
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector2).distance_to(target.global_position)<=definition.visibility_surface_radius


func candidate_id() -> StringName:
	if _research == null:
		return &""
	var best: StringName = &""
	var distance: float = INF
	for id: StringName in _targets:
		var target: ScientificScanTarget = _target(id)
		if target == null or not eligible(id):
			continue
		var current: float = global_position.distance_to(target.global_position)
		if current < distance or (current == distance and String(id) < String(best)):
			best = id
			distance = current
	return best


func request_scan(requested_id: StringName = &"") -> Error:
	if _research == null:
		return ERR_UNCONFIGURED
	if _suspended:
		return ERR_BUSY
	if _active != &"":
		cancel_scan("CANCELLED / Progress reset")
		return OK
	var candidate: StringName = candidate_id() if requested_id==&"" else (requested_id if eligible(requested_id) else &"")
	if candidate == &"":
		_feedback_seconds = 2.0
		_feedback = "NO SUBJECT IN RANGE / Approach visible specimens; sonar locates hidden subjects"
		for id: StringName in _targets:
			if _known(id) and _in_range(id) and _research.is_completed(id):
				_feedback = "ALREADY RECORDED / " + _definitions[id].title
		state_changed.emit()
		return ERR_UNAVAILABLE
	var definition: ScanDefinition = _definitions[candidate]
	if not definition.requires_sonar and _discoveries.state_of(definition.required_poi_id)!=DiscoveryRegistry.State.DISCOVERED:
		var found: Error = _discoveries.discover(definition.required_poi_id,&"scanner/visual-acquisition")
		if found!=OK: return found
	_active = candidate
	_elapsed = 0.0
	_feedback = "SCANNING"
	state_changed.emit()
	return OK


func cancel_scan(reason: String = "CANCELLED / Progress reset") -> void:
	_active = &""
	_elapsed = 0.0
	_feedback_seconds = 2.0
	_feedback = reason
	state_changed.emit()


func set_suspended(value: bool) -> void:
	_suspended = value
	state_changed.emit()


func advance(delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0:
		return ERR_INVALID_PARAMETER
	if _research == null or _suspended:
		return OK
	_feedback_seconds = maxf(0.0, _feedback_seconds - delta)
	for id: StringName in _targets:
		var target: ScientificScanTarget = _target(id)
		if target != null:
			target.present(_known(id), _definitions[id].classification, _research.is_completed(id))
	if _active != &"":
		if _target(_active) == null or not _known(_active) or not _in_range(_active):
			cancel_scan("INTERRUPTED / Subject removed or out of range; progress reset")
		elif _research.is_completed(_active):
			cancel_scan("ALREADY RECORDED / No duplicate research")
		else:
			_elapsed = minf(_elapsed + delta, _definitions[_active].duration)
			if _elapsed + 0.000000001 >= _definitions[_active].duration:
				var completed: StringName = _active
				_active = &""
				_elapsed = 0.0
				_feedback_seconds = 3.0
				_feedback = "COMPLETE / " + _definitions[completed].title + " · Map → Research log"
				var result: Error = _research.complete_scan(completed)
				if result!=OK: _feedback = "NOT RECORDED / Save unavailable; no outcome committed. Try again after recovery."
	state_changed.emit()
	return OK


func snapshot() -> Dictionary:
	if _active != &"":
		var definition: ScanDefinition = _definitions[_active]
		return {"active_id": _active, "progress": _elapsed / definition.duration,
			"text": "%s / %s · %.0f%% · activate Interact again to cancel" % ["PAUSED" if _suspended else "SCANNING", definition.title, _elapsed / definition.duration * 100.0]}
	var candidate: StringName = candidate_id()
	var text: String = _feedback
	if candidate != &"" and _feedback_seconds <= 0.0:
		var definition: ScanDefinition = _definitions[candidate]
		text = "READY / %s · range %.0f units · Interact: scan" % [definition.title, definition.radius]
	if candidate == &"" and _research != null and _feedback_seconds <= 0.0:
		var known: bool = false
		var pending: bool = false
		for id: StringName in _targets:
			if _target(id) != null and _known(id):
				known = true
				pending = pending or not _research.is_completed(id)
		if known:
			text = "OUT OF RANGE / Approach a discovered subject" if pending else "ALREADY RECORDED / Known subjects complete · Map → Research log"
	return {"active_id": &"", "progress": 0.0, "text": text}


func reset_session() -> void:
	cancel_scan("SCANNER / Approach a visible subject and Interact to scan")

func eligible(id: StringName) -> bool:
	return _research!=null and _target(id)!=null and _known(id) and not _research.is_completed(id) and _in_range(id)
