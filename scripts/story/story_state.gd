class_name StoryState
extends Node
## Central scene-owned story state. Numbers are domain APIs only, never player UI.
signal resonance_changed(previous: int, current: int)
signal tier_changed(previous: int, current: int)
signal flag_changed(flag_id: StringName)
signal choice_applied(choice_id: StringName, encounter_id: StringName)
enum Tier { HOSTILE, NEUTRAL, LISTENER }
const CATALOG: StoryChoiceCatalog = preload("res://resources/story/story_choices.tres")
var checkpoint_writer: Callable
var persistence_required: bool = false
var _catalog: StoryChoiceCatalog
var _data: Dictionary = fresh()
var _busy: bool = false
static func fresh() -> Dictionary:
	return {"resonance": 0, "flags": [], "decisions": []}
static func tier_for(value: int) -> Tier:
	return Tier.LISTENER if value >= 40 else (Tier.HOSTILE if value <= -40 else Tier.NEUTRAL)
func configure(catalog: StoryChoiceCatalog = CATALOG) -> Error:
	if _catalog != null: return ERR_ALREADY_IN_USE
	if catalog == null or not catalog.is_valid(): return ERR_INVALID_PARAMETER
	_catalog = catalog.duplicate(true) as StoryChoiceCatalog
	return OK
func resonance() -> int:
	return int(_data.resonance)
func tier() -> Tier:
	return tier_for(resonance())
func snapshot() -> Dictionary:
	return _data.duplicate(true)
func has_flag(id: StringName) -> bool:
	return String(id) in _data.flags
func has_decision(id: StringName) -> bool:
	return String(id) in _data.decisions
func knows_encounter(id: StringName) -> bool:
	if _catalog==null: return false
	for choice: ChoiceData in _catalog.choices:
		if choice.encounter_id==id: return true
	return false
func resolved(encounter_id: StringName) -> bool:
	if _catalog == null: return false
	for id: String in _data.decisions:
		if _catalog.definition(StringName(id)).encounter_id == encounter_id: return true
	return false
func definition(id: StringName) -> ChoiceData:
	var choice: ChoiceData = _catalog.definition(id) if _catalog != null else null
	return choice.duplicate(true) as ChoiceData if choice != null else null
static func valid_snapshot(value: Variant, catalog: StoryChoiceCatalog = CATALOG) -> bool:
	if catalog == null or not catalog.is_valid() or not value is Dictionary or value.size() != 3:
		return false
	if not InputBindings.is_integer(value.get("resonance")) or value.resonance < -100 or value.resonance > 100:
		return false
	if not value.get("flags") is Array or not value.get("decisions") is Array or value.decisions.size() > catalog.choices.size(): return false
	var expected: int = 0
	var groups: Array[StringName] = []
	var required: Array[String] = []
	for id: Variant in value.decisions:
		if not id is String: return false
		var choice: ChoiceData = catalog.definition(StringName(id))
		if choice == null or choice.encounter_id in groups: return false
		groups.append(choice.encounter_id)
		expected = clampi(expected + choice.resonance_delta, -100, 100)
		for flag: StringName in choice.flags: required.append(String(flag))
	if int(value.resonance) != expected or value.flags.size() > required.size() + catalog.extra_flags.size(): return false
	var seen: Array[String] = []
	for flag: Variant in value.flags:
		if not flag is String or flag in seen or (flag not in required and StringName(flag) not in catalog.extra_flags): return false
		seen.append(flag)
	for flag: String in required:
		if flag not in seen: return false
	return true
func restore(value: Dictionary) -> Error:
	if _busy or _catalog == null or not valid_snapshot(value, _catalog): return ERR_INVALID_DATA
	if not extends_history(value,_data,_catalog): return ERR_BUSY
	_data = value.duplicate(true)
	_data.resonance = int(_data.resonance)
	_data.flags.sort()
	# Restoration is intentionally silent: no rewards, dialogue, reaction or domain signal.
	return OK
func apply_choice(id: StringName) -> Error:
	if _busy: return ERR_BUSY
	var choice: ChoiceData = definition(id)
	if choice == null: return ERR_INVALID_PARAMETER
	if resolved(choice.encounter_id): return ERR_ALREADY_EXISTS
	var next: Dictionary = snapshot()
	next.decisions.append(String(id))
	next.resonance = clampi(resonance() + choice.resonance_delta, -100, 100)
	for flag: StringName in choice.flags: next.flags.append(String(flag))
	next.flags.sort()
	return _commit(next, id)
func set_flag(id: StringName) -> Error:
	if _busy: return ERR_BUSY
	if _catalog == null or id not in _catalog.extra_flags: return ERR_INVALID_PARAMETER
	if has_flag(id): return ERR_ALREADY_EXISTS
	var next: Dictionary = snapshot()
	next.flags.append(String(id))
	next.flags.sort()
	return _commit(next, &"")
func _commit(next: Dictionary, choice_id: StringName) -> Error:
	if not valid_snapshot(next, _catalog): return ERR_INVALID_DATA
	if persistence_required and not checkpoint_writer.is_valid(): return ERR_UNAVAILABLE
	_busy = true
	var result: Error = checkpoint_writer.call(next.duplicate(true), choice_id) if checkpoint_writer.is_valid() else OK
	if result == OK:
		var previous: Dictionary = _data
		_data = next.duplicate(true)
		if previous.resonance != _data.resonance: resonance_changed.emit(int(previous.resonance), resonance())
		if tier_for(int(previous.resonance)) != tier(): tier_changed.emit(tier_for(int(previous.resonance)), tier())
		for flag: String in _data.flags:
			if flag not in previous.flags: flag_changed.emit(StringName(flag))
		if choice_id != &"": choice_applied.emit(choice_id, _catalog.definition(choice_id).encounter_id)
	_busy = false
	return result
static func extends_history(candidate: Dictionary, previous: Dictionary, catalog: StoryChoiceCatalog = CATALOG) -> bool:
	if not valid_snapshot(candidate, catalog) or not valid_snapshot(previous, catalog) or candidate.decisions.size() < previous.decisions.size(): return false
	for index: int in range(previous.decisions.size()):
		if candidate.decisions[index] != previous.decisions[index]: return false
	for flag: String in previous.flags:
		if flag not in candidate.flags: return false
	return true
static func merge_snapshots(a: Dictionary, b: Dictionary, catalog: StoryChoiceCatalog = CATALOG) -> Dictionary:
	if not valid_snapshot(a, catalog) or not valid_snapshot(b, catalog): return {"error": ERR_INVALID_DATA}
	var longer: Dictionary = a if a.decisions.size() >= b.decisions.size() else b
	var shorter: Dictionary = b if a.decisions.size() >= b.decisions.size() else a
	for index: int in range(shorter.decisions.size()):
		if longer.decisions[index] != shorter.decisions[index]: return {"error": ERR_BUSY}
	var merged: Dictionary = longer.duplicate(true)
	for flag: String in shorter.flags:
		if flag not in merged.flags: merged.flags.append(flag)
	merged.flags.sort()
	merged.resonance = int(merged.resonance)
	return {"error": OK, "data": merged}
