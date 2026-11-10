class_name PlaytestRecorder
extends RefCounted
## Pure observation state. Sessions never restore themselves from a campaign/save.
var recording: bool = false
var _data: Dictionary = {}
var _seen: Dictionary[String, bool] = {}
const MAX_IDENTITIES: int = 2048


func begin(build_id: String = "source",combat: bool = false) -> Error:
	if recording:
		return ERR_ALREADY_IN_USE
	var counts: Dictionary = {}
	for kind: String in PlaytestReport.details(2 if combat else 1):
		counts[kind] = 0
	var candidate: Dictionary = {"schema_version": 2 if combat else 1, "session_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"game_version": "0.1.0-playtest", "build_id": build_id, "status": "active", "active_seconds": 0.0, "menu_seconds": 0.0,
		"completed": false, "completion_seconds": null, "completion_active_seconds": null, "counts": counts,
		"damage_total": 0.0, "events": [], "omitted_events": 0}
	if build_id != "source" and not PlaytestReport.hex_id(build_id, 40):
		return ERR_INVALID_PARAMETER
	if combat: candidate.combat = CombatMetrics.fresh()
	_data = candidate
	_seen.clear()
	recording = true
	return record("session_start", "opt_in")


func advance(seconds: float, active: bool) -> Error:
	if not recording:
		return ERR_UNAVAILABLE
	if not PlaytestReport.number(seconds, PlaytestReport.MAX_SECONDS) or _data.active_seconds + _data.menu_seconds + seconds > PlaytestReport.MAX_SECONDS:
		return ERR_INVALID_PARAMETER
	_data["active_seconds" if active else "menu_seconds"] += seconds
	if _data.schema_version==2 and active: _data.combat.profile_active_seconds[_data.combat.profile] += seconds
	return OK


func record(kind: String, detail: String, amount: float = 0.0, identity: String = "") -> Error:
	if not recording:
		return ERR_UNAVAILABLE
	var details: Dictionary = PlaytestReport.details(_data.schema_version)
	if not details.has(kind) or detail not in details[kind] or not PlaytestReport.number(amount):
		return ERR_INVALID_PARAMETER
	if not identity.is_empty():
		if _seen.has(kind + ":" + identity):
			return ERR_ALREADY_EXISTS
		if _seen.size() >= MAX_IDENTITIES:
			return ERR_OUT_OF_MEMORY
		_seen[kind + ":" + identity] = true
	if kind == "chapter_completed":
		if _data.completed:
			return ERR_ALREADY_EXISTS
		_data.completed = true
		_data.completion_seconds = _data.active_seconds + _data.menu_seconds
		_data.completion_active_seconds = _data.active_seconds
	_data.counts[kind] += 1
	if _data.schema_version==2: CombatMetrics.record(_data.combat,kind,detail,_data.active_seconds,amount)
	if kind == "damage":
		_data.damage_total += amount
	if _data.events.size() < PlaytestReport.MAX_EVENTS:
		_data.events.append({"kind": kind, "detail": detail, "seconds": _data.active_seconds + _data.menu_seconds, "amount": amount})
	else:
		_data.omitted_events += 1
	return OK


func finish(reason: String = "disabled") -> Error:
	if not recording:
		return ERR_UNAVAILABLE
	if reason not in ["disabled", "quit"]:
		return ERR_INVALID_PARAMETER
	record("session_end", reason)
	_data.status = reason
	recording = false
	return OK


func snapshot() -> Dictionary:
	return _data.duplicate(true)
