class_name NarrativeService
extends Node
## A projection/interaction adapter for the existing mission system, not a second ledger.
## Text records derive from persistent mission/discovery/research evidence. No new save.

signal log_changed
signal record_unlocked(record_id: StringName)
signal chapter_concluded
const MAIN: StringName = &"shelf-expedition"
const SCIENCE: StringName = &"shelf-calibration-study"
const PLATE: StringName = &"shelf-calibration-plate"
const MARKER: StringName = &"shelf-navigation-marker"
const SPIRES: StringName = &"shelf-twin-spires"
var extended_chapter: bool = false
var legacy_conclusion: bool = false
var _catalog: NarrativeCatalog
var missions: MissionService
var discoveries: DiscoveryRegistry
var research: ResearchRegistry
var _emitted: Array[StringName] = []
var _links: Array[Dictionary] = []
var _concluded_seen: bool = false
var radio_assignments: bool = false
var debrief_guard: Callable
var progress_guard: Callable


func setup(catalog: NarrativeCatalog, mission_source: MissionService, points: DiscoveryRegistry, science: ResearchRegistry) -> Error:
	if _catalog != null:
		return ERR_ALREADY_IN_USE
	if catalog == null or not catalog.is_valid() or mission_source == null or points == null or science == null \
		or not mission_source.snapshot().has(String(MAIN)) or not mission_source.snapshot().has(String(SCIENCE)) \
		or not points.knows_id(MARKER) or not points.knows_id(SPIRES) or not science.knows_id(PLATE):
		return ERR_INVALID_PARAMETER
	_catalog = catalog.duplicate(true) as NarrativeCatalog
	missions = mission_source
	discoveries = points
	research = science
	_concluded_seen = is_concluded()
	for entry: NarrativeEntry in available_entries():
		_emitted.append(entry.stable_id)
	_link(points.registry_changed, _silent_refresh)
	_link(science.records_changed, _silent_refresh)
	_link(missions.missions_changed, _refresh)
	_link(missions.records_restored, _silent_refresh)
	_link(points.point_discovered, _evidence_event)
	_link(science.scan_completed, _evidence_event)
	_link(missions.mission_completed, _evidence_event)
	_link(missions.acknowledgement_claimed, _acknowledged)
	return OK


func _link(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	_links.append({"signal": source, "callback": callback})


func _silent_refresh() -> void:
	_concluded_seen = _concluded_seen or is_concluded()
	for entry: NarrativeEntry in available_entries():
		if entry.stable_id not in _emitted:
			_emitted.append(entry.stable_id)
	log_changed.emit()


func _refresh() -> void:
	# Restore APIs emit only generic changes. Refresh presentation without story events.
	log_changed.emit()


func _evidence_event(_id: StringName) -> void:
	_announce()


func _acknowledged(_id: StringName, _ack_id: StringName) -> void:
	_announce()
	if is_concluded() and not _concluded_seen:
		_concluded_seen = true
		chapter_concluded.emit()


func _announce() -> void:
	for entry: NarrativeEntry in available_entries():
		if entry.stable_id not in _emitted:
			_emitted.append(entry.stable_id)
			record_unlocked.emit(entry.stable_id)
	log_changed.emit()


func _state(id: StringName) -> String:
	return String(missions.snapshot()[String(id)].state)


func is_concluded() -> bool:
	if extended_chapter and not legacy_conclusion:
		if missions == null or _state(ShelfChapterData.OUTER) != "claimed" or _state(ShelfChapterData.WRECK) != "claimed": return false
	return missions != null and _state(MAIN) == "claimed" and _state(SCIENCE) == "claimed" \
		and research.is_completed(PLATE) and discoveries.state_of(SPIRES) == DiscoveryRegistry.State.DISCOVERED


func returned() -> bool:
	return missions != null and "return-to-base" in missions.snapshot()[String(MAIN)].objectives


func _eligible(evidence: NarrativeEntry.Evidence) -> bool:
	match evidence:
		NarrativeEntry.Evidence.BRIEFING: return true
		NarrativeEntry.Evidence.ACCEPTED: return _state(MAIN) != "available"
		NarrativeEntry.Evidence.MARKER: return discoveries.state_of(MARKER) == DiscoveryRegistry.State.DISCOVERED
		NarrativeEntry.Evidence.SCAN: return research.is_completed(PLATE)
		NarrativeEntry.Evidence.SPIRES: return discoveries.state_of(SPIRES) == DiscoveryRegistry.State.DISCOVERED
		NarrativeEntry.Evidence.RETURNED: return returned()
		NarrativeEntry.Evidence.CONCLUDED: return is_concluded()
		NarrativeEntry.Evidence.HYDROPHONE: return research.is_completed(&"outer-hydrophone-record")
		NarrativeEntry.Evidence.VENT: return research.is_completed(&"outer-vent-study")
		NarrativeEntry.Evidence.WRECK: return research.is_completed(&"lost-expedition-blackbox")
		NarrativeEntry.Evidence.GEOLOGY: return research.is_completed(&"shelf-overlook-formation")
	return false


func available_entries() -> Array[NarrativeEntry]:
	var entries: Array[NarrativeEntry] = []
	if _catalog != null:
		for entry: NarrativeEntry in _catalog.entries:
			if _eligible(entry.evidence):
				entries.append(entry.duplicate(true) as NarrativeEntry)
	return entries


func progress_allowed() -> bool:
	return not progress_guard.is_valid() or bool(progress_guard.call())


func begin_survey() -> Error:
	if not progress_allowed():
		return ERR_UNAUTHORIZED
	if missions == null:
		return ERR_UNCONFIGURED
	for id: StringName in required_missions():
		if _state(id) == "available":
			var result: Error = missions.accept(id)
			if result != OK:
				return result
	_announce()
	return missions.reconcile()


func can_debrief() -> bool:
	if debrief_guard.is_valid() and not debrief_guard.call(): return false
	if extended_chapter and not legacy_conclusion:
		for id: StringName in [ShelfChapterData.OUTER,ShelfChapterData.WRECK]:
			if _state(id) not in ["completed","claimed"]: return false
	return missions != null and research.is_completed(PLATE) and discoveries.state_of(SPIRES) == DiscoveryRegistry.State.DISCOVERED \
		and _state(MAIN) in ["completed", "claimed"] \
		and _state(SCIENCE) in ["completed", "claimed"] and not is_concluded()


func debrief(station: ServiceStation) -> Error:
	if not progress_allowed():
		return ERR_UNAUTHORIZED
	if is_concluded():
		return ERR_ALREADY_EXISTS
	if not can_debrief() or not is_instance_valid(station) or station.missions != missions:
		return ERR_UNAVAILABLE
	# Existing docking/pause guard and durable, idempotent claims remain authoritative.
	for id: StringName in required_missions():
		if _state(id) == "completed":
			var result: Error = station.mission_action(&"claim", id)
			if result != OK:
				return result
	return OK


func guidance() -> String:
	if missions == null:
		return "EXPEDITION LOG / OFFLINE"
	if radio_assignments and _state(ShelfChapterData.OUTER)=="available": return "BASE RADIO / Depart station to receive and accept the investigation"
	if extended_chapter and research.is_completed(PLATE) and not research.is_completed(&"lost-expedition-blackbox"):
		return "OUTER SHELF / Follow the expedition evidence in your research log"
	if is_concluded():
		return "CHAPTER CONCLUDED / NERIS is home · Pause: expedition log"
	if not research.is_completed(PLATE):
		return "PLATE EAST / Sonar → approach → Interact: scan · Pause: expedition log"
	if discoveries.state_of(SPIRES) != DiscoveryRegistry.State.DISCOVERED:
		return "RECORD RECOVERED / Cave → Twin Spires · Sonar: identify landmark"
	if _state(MAIN) == "available" or _state(SCIENCE) == "available":
		return "EVIDENCE KEPT / Pause → Expedition log → Begin survey; earlier scans count"
	if not returned():
		return "RETURN / Lower BASE arrows → Shelf Base · Dock to debrief"
	return "DEBRIEF READY / Dock → Expedition log · Your record stays available"


func _exit_tree() -> void:
	for link: Dictionary in _links:
		var source: Signal = link.signal
		if not source.is_null() and is_instance_valid(source.get_object()) and source.is_connected(link.callback):
			source.disconnect(link.callback)
	_links.clear()


func required_missions() -> Array[StringName]:
	var ids: Array[StringName] = [MAIN,SCIENCE]
	if extended_chapter: ids.append_array([ShelfChapterData.OUTER,ShelfChapterData.WRECK])
	return ids
