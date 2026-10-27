class_name PlaytestObserver
extends Node
## Read-only scene-owned signal adapter. No campaign, acoustic or input writes.
signal status_changed
var recorder: PlaytestRecorder = PlaytestRecorder.new()
var store: PlaytestStore = PlaytestStore.new()
var status: String = "Recording OFF. Nothing is collected until you opt in."
var _scene: ShelfPrototype
var _links: Array[Dictionary] = []
var _missions: Dictionary = {}
var _low: Dictionary[String, bool] = {}
var _hull: float = 0.0
var _scan: StringName
var _last_usec: int = 0
var _active: bool = false
var _since_write: float = 0.0
var _build_id: String = "source"


func setup(scene: ShelfPrototype) -> void:
	_scene = scene
	process_mode = Node.PROCESS_MODE_ALWAYS
	var build: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/playtesting/build_info.json"))
	if build is Dictionary:
		_build_id = String(build.get("build_id", "source"))
	_baseline()
	_link(scene.submarine.sonar.pulse_emitted, _ping)
	_link(scene.discoveries.point_discovered, func(id: StringName) -> void: _record("discovery", String(id), 0.0, String(id)))
	_link(scene.research.scan_completed, func(id: StringName) -> void: _record("scan_completed", String(id), 0.0, String(id)))
	_link(scene.submarine.scanner.state_changed, _scan_changed)
	_link(scene.missions.records_restored, _baseline)
	_link(scene.missions.missions_changed, _missions_changed)
	_link(scene.route_check.stage_changed, _route_changed)
	_link(scene.route_check.base_returned, func() -> void: _record("station_return", "route_return"))
	_link(scene.submarine.hull_system.hull_changed, _hull_changed)
	_link(scene.submarine.resource_system.battery_changed, func(value: float, maximum: float) -> void: _resource("battery", value, maximum))
	_link(scene.submarine.resource_system.oxygen_changed, func(value: float, maximum: float) -> void: _resource("oxygen", value, maximum))
	_link(scene.submarine.damage_system.warning_changed, func(state: int) -> void:
		if state != SubmarineDamageSystem.WarningState.SAFE:
			_record("resource_warning", "depth_caution" if state == SubmarineDamageSystem.WarningState.APPROACHING else "depth_danger"))
	_link(scene.narrative.chapter_concluded, func() -> void: _record("chapter_completed", "the_quiet_run", 0.0, "chapter"))
	_link(scene.submarine.simulation_enabled_changed, func(enabled: bool) -> void:
		_tick()
		_active = enabled and not get_tree().paused)
	_link(scene.route_menu.restart_requested, func() -> void:
		_baseline()
		_record("milestone", "route_restart"))
	if scene.saves != null:
		_link(scene.saves.checkpoint_restored, func() -> void:
			_baseline()
			_record("milestone", "continue"))
		_link(scene.saves.status_changed, func() -> void:
			if not scene.saves.can_write():
				_record("error", "checkpoint_blocked", 0.0, "checkpoint_blocked"))


func _restoring() -> bool:
	return _scene.saves != null and _scene.saves.is_restoring()


func _baseline() -> void:
	_missions = _scene.missions.snapshot()
	_hull = _scene.submarine.hull_system.hull
	_scan = _scene.submarine.scanner.snapshot().active_id
	_low = {"hull": _hull / _scene.submarine.hull_system.max_hull <= 0.2,
		"battery": _scene.submarine.resource_system.battery / _scene.submarine.resource_system.max_battery <= 0.2,
		"oxygen": _scene.submarine.resource_system.oxygen / _scene.submarine.resource_system.max_oxygen <= 0.2}

	for kind: String in ["hull", "battery", "oxygen"]:
		var value: float = _hull if kind == "hull" else (_scene.submarine.resource_system.battery if kind == "battery" else _scene.submarine.resource_system.oxygen)
		_low[kind + "_depleted"] = value <= 0.0


func _link(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	_links.append({"source": source, "callback": callback})


func start() -> Error:
	var result: Error = recorder.begin(_build_id)
	if result != OK:
		return result
	_baseline()
	_last_usec = Time.get_ticks_usec()
	_since_write = 0.0
	_active = _scene.submarine.is_physics_processing() and not get_tree().paused
	return export_report()


func stop(reason: String = "disabled") -> Error:
	_tick()
	var result: Error = recorder.finish(reason)
	return export_report() if result == OK else result


func export_report() -> Error:
	_tick()
	var result: Error = store.write_report(recorder.snapshot(), true)
	status = "Saved local JSON + text report: " + ProjectSettings.globalize_path(store.directory) if result == OK else "Report not saved (%s). Existing files preserved; recording can be disabled." % error_string(result)
	status_changed.emit()
	return result


func _tick() -> void:
	var now: int = Time.get_ticks_usec()
	if recorder.recording and _last_usec > 0:
		var seconds: float = (now - _last_usec) / 1000000.0
		if recorder.advance(seconds, _active) != OK:
			recorder.finish("disabled")
		_since_write += seconds
	_last_usec = now


func _process(_delta: float) -> void:
	_tick()
	_active = _scene.submarine.is_physics_processing() and not get_tree().paused
	if recorder.recording and _since_write >= 15.0:
		_since_write = 0.0
		var result: Error = store.write_report(recorder.snapshot())
		if result != OK:
			status = "Local report checkpoint failed (%s); export or disable from Playtest reports." % error_string(result)
			_record("error", "write_failed", 0.0, "write_failed")
			status_changed.emit()


func _record(kind: String, detail: String, amount: float = 0.0, identity: String = "") -> void:
	if not recorder.recording or _restoring():
		return
	_tick()
	var result: Error = recorder.record(kind, detail, amount, identity)
	if result == ERR_OUT_OF_MEMORY:
		stop()


func _ping(event: AcousticEvent) -> void:
	_record("sonar", "active_ping", 0.0, String(event.event_id))


func _scan_changed() -> void:
	var active: StringName = _scene.submarine.scanner.snapshot().active_id
	if active != &"" and active != _scan:
		_record("scan_started", String(active))
	_scan = active


func _missions_changed() -> void:
	var current: Dictionary = _scene.missions.snapshot()
	for id: String in current:
		var previous: String = _missions.get(id, {}).get("state", "available")
		var next: String = current[id].state
		if previous == "available" and next != "available":
			_record("mission_accepted", id, 0.0, id)
		if next in ["completed", "claimed"] and previous not in ["completed", "claimed"]:
			_record("mission_completed", id, 0.0, id)
		if next == "claimed" and previous != "claimed":
			_record("mission_claimed", id, 0.0, id)
	_missions = current


func _route_changed(stage: int) -> void:
	match stage:
		GrayboxRouteCheck.Stage.OUTBOUND: _record("milestone", "outbound")
		GrayboxRouteCheck.Stage.RETURNING: _record("milestone", "twin_spires")
		GrayboxRouteCheck.Stage.COMPLETE:
			_record("milestone", "returned_to_base")


func _resource(kind: String, value: float, maximum: float) -> void:
	if _restoring():
		return
	var low: bool = value / maximum <= 0.2
	if low and not _low.get(kind, false):
		_record("resource_warning", kind + "_low")
	if value <= 0.0 and not _low.get(kind + "_depleted", false):
		_record("resource_warning", kind + "_depleted")
		if kind in ["hull", "oxygen"]:
			_record("failure", "hull_destroyed" if kind == "hull" else "oxygen_depleted")
	_low[kind] = low
	_low[kind + "_depleted"] = value <= 0.0


func _hull_changed(value: float, maximum: float) -> void:
	if not _restoring() and value < _hull:
		var source: StringName = _scene.submarine.hull_system.last_damage_source
		var detail: String = "pressure" if source == &"pressure" else ("impact" if source == &"collision" else ("creature" if String(source).ends_with("/contact") else "other"))
		_record("damage", detail, _hull - value)
	_hull = value
	_resource("hull", value, maximum)


func _exit_tree() -> void:
	if recorder.recording:
		stop("quit")
	for link: Dictionary in _links:
		var source: Signal = link.source
		if not source.is_null() and is_instance_valid(source.get_object()) and source.is_connected(link.callback):
			source.disconnect(link.callback)
