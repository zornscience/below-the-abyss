class_name SaveCoordinator
extends Node
## Scene-owned checkpoint coordinator. All domain stores use its optional write port.

signal status_changed
var status: String = "No expedition save loaded."
var store: ExpeditionStore = ExpeditionStore.new()
var _scene: ShelfPrototype
var _state: Dictionary = {}
var _busy: bool = false
var _ready_to_write: bool = false
var _has_checkpoint: bool = false


func _report(message: String, result: Error) -> Error:
	status = message
	status_changed.emit()
	return result


func setup(scene: ShelfPrototype, path: String) -> Error:
	_scene = scene
	store.path = path
	var document: Dictionary = store.load_checkpoint()
	if document.error == OK:
		_state = document.data
		_state.progress = ExpeditionSchema.merge_progress(_state.progress, progress_snapshot())
		apply_progress(_state.progress)
		_has_checkpoint = true
	elif document.error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path + ".bak"):
		# Reject unreadable legacy data on the first migration, not silently starting fresh.
		for legacy: Variant in [scene.discovery_store, scene.research_store, scene.upgrades.store, scene.missions.store]:
			if legacy.last_result != OK and (legacy.last_result != ERR_FILE_NOT_FOUND or FileAccess.file_exists(legacy.path + ".bak")):
				return _report("Legacy progress needs recovery before migration. Use its existing recovery page, then retry Save.", ERR_INVALID_DATA)
		_state = snapshot()
	else:
		return _report("Expedition file unavailable (%s). Preserved; use Recover expedition backup." % error_string(document.error), document.error)
	_ready_to_write = true
	_delegate_stores()
	return _report("Continue is available; checkpoint validated." if _has_checkpoint else "No expedition checkpoint yet. Begin exploration, then Save or use station services.", OK)


func _delegate_stores() -> void:
	for legacy: Variant in [_scene.discovery_store, _scene.research_store, _scene.upgrades.store, _scene.missions.store]:
		legacy.checkpoint_writer = commit_progress
		legacy._report("Progress managed by expedition checkpoint; legacy files preserved.", OK)


func progress_snapshot() -> Dictionary:
	# JSON-shaped strings are canonical, not runtime instance IDs or Resources.
	return {"discoveries": _strings(_scene.discoveries.discovered_ids()), "research": _strings(_scene.research.completed_ids()),
		"upgrades": _strings(_scene.upgrades.installed_ids()), "missions": _scene.missions.snapshot()}


func _strings(ids: Array[StringName]) -> Array:
	var result: Array = []
	for id: StringName in ids:
		result.append(String(id))
	result.sort()
	return result


func _names(ids: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: String in ids:
		result.append(StringName(id))
	return result


func snapshot() -> Dictionary:
	var vessel: SubmarineController = _scene.submarine
	return {"format": "bta-expedition", "schema_version": 2, "region_id": ExpeditionSchema.REGION, "legacy_imported": true,
		"player": {"position": [vessel.global_position.x, vessel.global_position.y], "rotation": wrapf(vessel.rotation, -PI, PI),
			"hull": vessel.hull_system.hull, "battery": vessel.resource_system.battery, "oxygen": vessel.resource_system.oxygen,
			"sonar_cooldown": vessel.sonar.cooldown_remaining()},
		"progress": progress_snapshot(), "route": {"stage": _scene.route_check.stage, "elapsed_seconds": _scene.route_check.elapsed_seconds}}


func has_checkpoint() -> bool:
	return _has_checkpoint


func position_clear(at: Vector2, orientation: float) -> bool:
	if not at.is_finite() or not is_finite(orientation) or not Rect2(_scene.region.camera_bounds).has_point(at):
		return false
	var vessel: SubmarineController = _scene.submarine
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = (vessel.get_node("CollisionShape2D") as CollisionShape2D).shape
	query.transform = Transform2D(orientation, at)
	query.collision_mask = vessel.collision_mask
	query.exclude = [vessel.get_rid()]
	return vessel.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func safe_to_save() -> bool:
	return not _scene.submarine.is_physics_processing() and position_clear(_scene.submarine.global_position, _scene.submarine.rotation) \
		and _scene.submarine.damage_system.warning_state != SubmarineDamageSystem.WarningState.EXCEEDED \
		and _scene.predator.threat.phase not in [PredatorState.Phase.ALERT, PredatorState.Phase.PURSUE]


func _write(candidate: Dictionary, message: String) -> Error:
	if _busy or not _ready_to_write:
		return _report("Save blocked; recover the existing checkpoint before writing.", ERR_BUSY)
	_busy = true
	candidate.progress = ExpeditionSchema.merge_progress(candidate.progress, _state.progress)
	var result: Error = store.write_checkpoint(candidate)
	if result == OK:
		_state = candidate.duplicate(true)
		_has_checkpoint = true
	_report(message if result == OK else "Not saved (%s). Files preserved; recover or inspect checkpoint." % error_string(result), result)
	_busy = false
	return result


func save_current() -> Error:
	if not _ready_to_write:
		var result: Error = setup(_scene, store.path)
		if result != OK:
			return result
	if not safe_to_save():
		return _report("Not saved: pause in clear terrain, outside pressure danger and predator alert/pursuit.", ERR_UNAVAILABLE)
	return _write(snapshot(), "Expedition saved: position, supplies and progress committed.")


func commit_progress(kind: StringName, proposed: Variant) -> Error:
	if _busy or not _ready_to_write:
		return ERR_BUSY
	var candidate: Dictionary = _state.duplicate(true)
	candidate.progress = progress_snapshot()
	candidate.progress[String(kind)] = proposed.duplicate(true) if proposed is Dictionary else _strings(proposed)
	if not ExpeditionSchema.valid_progress(candidate.progress):
		return ERR_INVALID_DATA
	# Docked domain operations are safe checkpoints. Else only permanent records advance.
	if _scene.station_menu.visible and safe_to_save():
		var current: Dictionary = snapshot()
		candidate.player = current.player
		candidate.route = current.route
	return _write(candidate, "Progress committed; expedition checkpoint retained." if not _scene.station_menu.visible else "Station checkpoint saved with permanent progress.")


func apply_progress(progress: Dictionary) -> void:
	_scene.discoveries.restore_discoveries(_names(progress.discoveries))
	_scene.research.restore_completed(_names(progress.research))
	_scene.upgrades.restore_installed(_names(progress.upgrades))
	_scene.missions.restore_records(progress.missions)


func continue_expedition() -> Error:
	if _busy or not _has_checkpoint or _scene.submarine.sonar.is_mutating():
		return _report("No validated checkpoint available to continue.", ERR_UNAVAILABLE)
	var validated: Dictionary = ExpeditionSchema.decode(_state)
	if validated.error != OK:
		return _report("Checkpoint validation failed; vessel unchanged.", validated.error)
	var saved: Dictionary = validated.data
	var at: Vector2 = Vector2(saved.player.position[0], saved.player.position[1])
	var angle: float = saved.player.rotation
	var relocated: bool = not position_clear(at, angle)
	if relocated:
		at = _scene.region.spawn.global_position
		angle = 0.0
		if not position_clear(at, angle):
			return _report("No clear station fallback; load cancelled without changing the vessel.", ERR_UNAVAILABLE)
	_busy = true
	# This coordinator never issues gameplay discovery, scan, claim or ping commands.
	_scene.submarine.set_simulation_enabled(false)
	_scene.station.end_interaction()
	_scene.station_menu.hide()
	_scene.submarine.scanner.reset_session()
	_scene.submarine.sonar.reset_session()
	_scene.submarine.passive.reset_session()
	_scene.ambient.reset_session()
	_scene.creature.reset_session()
	_scene.predator.reset_session()
	apply_progress(saved.progress)
	var vessel: SubmarineController = _scene.submarine
	vessel.global_position = at
	vessel.rotation = angle
	vessel.velocity = Vector2.ZERO
	vessel.resource_system.restore_snapshot(saved.player.battery, saved.player.oxygen)
	vessel.hull_system.restore_snapshot(saved.player.hull)
	vessel.damage_system.configure(vessel.damage_system.configuration)
	_scene.upgrades.reapply()
	vessel.damage_system.advance(0.0, _scene.region.depth_at_world(at), vessel.hull_system)
	vessel.sonar.restore_cooldown(saved.player.sonar_cooldown)
	_scene.route_check.stage = GrayboxRouteCheck.Stage.AT_BASE if relocated else int(saved.route.stage) as GrayboxRouteCheck.Stage
	_scene.route_check.elapsed_seconds = 0.0 if relocated else saved.route.elapsed_seconds
	_scene._refresh_route_status()
	_scene._refresh_scan_status()
	vessel.reset_physics_interpolation()
	var camera: Camera2D = vessel.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	_busy = false
	return _report("Continued at clear Shelf Base fallback; supplies/progress preserved, temporary route reset." if relocated else "Expedition restored. Temporary echoes, contacts and creature pursuit cleared.", OK)


func recover_backup() -> Error:
	if not FileAccess.file_exists(store.path) and not FileAccess.file_exists(store.path + ".bak"):
		return _recover_legacy()
	if _busy:
		return ERR_BUSY
	_busy = true
	var restored: Dictionary = store.recover_checkpoint(progress_snapshot())
	if restored.error == OK:
		_state = restored.data
		_has_checkpoint = true
		_ready_to_write = true
		_delegate_stores()
		apply_progress(_state.progress)
	_report("Backup recovered; rejected file preserved. Continue to resume." if restored.error == OK else "Backup not recovered (%s); files/vessel preserved." % error_string(restored.error), restored.error)
	_busy = false
	return restored.error


func new_expedition() -> Error:
	if not _ready_to_write or _busy or _scene.submarine.is_physics_processing() or not position_clear(_scene.region.spawn.global_position, 0.0):
		return _report("New Expedition blocked: recover checkpoint or pause safely first.", ERR_UNAVAILABLE)
	var candidate: Dictionary = snapshot()
	candidate.player = {"position": [_scene.region.spawn.global_position.x, _scene.region.spawn.global_position.y], "rotation": 0.0,
		"hull": _scene.submarine.hull_system.max_hull, "battery": _scene.submarine.resource_system.max_battery,
		"oxygen": _scene.submarine.resource_system.max_oxygen, "sonar_cooldown": 0.0}
	candidate.route = {"stage": 0, "elapsed_seconds": 0.0}
	var result: Error = _write(candidate, "New Expedition checkpoint saved; all permanent progress retained.")
	return continue_expedition() if result == OK else result


func can_write() -> bool:
	return _ready_to_write


func _recover_legacy() -> Error:
	if _busy:
		return ERR_BUSY
	var pending: Array[int] = []
	var stores: Array = [_scene.discovery_store, _scene.research_store, _scene.upgrades.store, _scene.missions.store]
	for index: int in range(stores.size()):
		var legacy: Variant = stores[index]
		if legacy.last_result == OK or (legacy.last_result == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(legacy.path + ".bak")):
			continue
		var inspected: Dictionary
		match index:
			0: inspected = legacy._read(legacy.path + ".bak", _scene.discoveries)
			1: inspected = legacy._read(legacy.path + ".bak", _scene.research)
			2: inspected = legacy._read(legacy.path + ".bak", ExpeditionSchema.UPGRADES)
			3: inspected = legacy._read(legacy.path + ".bak", ExpeditionSchema.MISSIONS)
		if inspected.error != OK or FileAccess.file_exists(legacy.path + ".rejected"):
			return _report("Legacy backup unavailable or rejected-file conflict; migration cancelled, files preserved.", ERR_INVALID_DATA)
		pending.append(index)
	if pending.is_empty():
		return _report("No expedition or legacy backup available; nothing changed.", ERR_FILE_NOT_FOUND)
	_busy = true
	for index: int in pending:
		var result: Error
		match index:
			0: result = _scene.discovery_store.recover_backup(_scene.discoveries)
			1: result = _scene.research_store.recover_backup(_scene.research)
			2: result = _scene.upgrades.recover_backup()
			3: result = _scene.missions.recover_backup()
		if result != OK:
			_busy = false
			return _report("Legacy recovery incomplete; play remains blocked. Inspect preserved files.", result)
	_busy = false
	var configured: Error = setup(_scene, store.path)
	if configured != OK:
		return configured
	return save_current()
