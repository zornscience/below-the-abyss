class_name ServiceStation
extends Node2D
## Explicit validated interaction/service only. No area-entered resource mutation.

signal service_applied(result: Dictionary)
signal availability_changed
@export var configuration: StationProfile = StationProfile.new()
var missions: MissionService
var upgrades: SubmarineUpgrades
var _rules: StationProfile
var _player: WeakRef
var _busy: bool = false
var _enabled: bool = true
const SERVICES: Array[StringName] = [&"hull", &"battery", &"oxygen", &"all"]


func _ready() -> void:
	if configure(configuration) != OK:
		push_error("Invalid service station profile.")


func configure(profile: StationProfile) -> Error:
	if _busy or _live_player() != null:
		return ERR_BUSY
	if profile == null or not profile.is_valid():
		return ERR_INVALID_PARAMETER
	configuration = profile
	_rules = profile.duplicate(true) as StationProfile
	queue_redraw()
	return OK


func set_service_enabled(value: bool) -> void:
	_enabled = value
	availability_changed.emit()


func is_in_range(at: Vector2) -> bool:
	return _rules != null and at.is_finite() and global_position.distance_to(at) <= _rules.docking_radius


func _live_player() -> SubmarineController:
	var player: SubmarineController = _player.get_ref() as SubmarineController if _player != null else null
	return player if is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() else null


func _dock_check(player: SubmarineController, paused: bool) -> Dictionary:
	if _rules == null or not _enabled:
		return {"error": ERR_UNAVAILABLE, "reason": "Station services offline"}
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or not player.is_node_ready():
		return {"error": ERR_UNCONFIGURED, "reason": "No vessel connected"}
	if not is_in_range(player.global_position):
		return {"error": ERR_UNAVAILABLE, "reason": "Outside docking radius"}
	if not player.velocity.is_finite() or player.velocity.length() > _rules.maximum_docking_speed:
		return {"error": ERR_UNAVAILABLE, "reason": "Slow down to dock"}
	if paused and player.is_physics_processing():
		return {"error": ERR_BUSY, "reason": "Docking pause required"}
	return {"error": OK, "reason": "Docked"}


func can_interact(player: SubmarineController) -> bool:
	return not _busy and _live_player() == null and _dock_check(player, false).error == OK


func interact(player: SubmarineController) -> Error:
	if _busy:
		return ERR_BUSY
	if _live_player() != null:
		return ERR_ALREADY_IN_USE
	var result: Dictionary = _dock_check(player, false)
	if result.error == OK:
		_player = weakref(player)
	return result.error


func end_interaction() -> Error:
	if _busy:
		return ERR_BUSY
	_player = null
	return OK


func docking_hint(player: SubmarineController) -> String:
	var check: Dictionary = _dock_check(player, false)
	return "STATION / Interact: services · FREE" if check.error == OK else "STATION / " + String(check.reason)


func notices_snapshot() -> Array[StationNotice]:
	var result: Array[StationNotice] = []
	if _rules != null:
		for notice: StationNotice in _rules.notices:
			result.append(notice.duplicate(true) as StationNotice)
	return result


func station_name() -> String:
	return _rules.display_name if _rules != null else "Station unavailable"


func _values(player: SubmarineController) -> Dictionary:
	return {"hull": player.hull_system.hull, "battery": player.resource_system.battery, "oxygen": player.resource_system.oxygen,
		"max_hull": player.hull_system.max_hull, "max_battery": player.resource_system.max_battery, "max_oxygen": player.resource_system.max_oxygen}


func quote(service: StringName) -> Dictionary:
	if service not in SERVICES:
		return {"error": ERR_INVALID_PARAMETER, "reason": "Unknown service"}
	if _busy:
		return {"error": ERR_BUSY, "reason": "Service already in progress"}
	var player: SubmarineController = _live_player()
	var check: Dictionary = _dock_check(player, true)
	if check.error != OK:
		return check
	var before: Dictionary = _values(player)
	var after: Dictionary = before.duplicate()
	var transfer: Dictionary = {"hull": 0.0, "battery": 0.0, "oxygen": 0.0}
	var limits: Dictionary = {"hull": _rules.hull_per_service, "battery": _rules.battery_per_service, "oxygen": _rules.oxygen_per_service}
	var total: float = 0.0
	for kind: StringName in [&"hull", &"battery", &"oxygen"]:
		if service == &"all" or service == kind:
			after[kind] = minf(before["max_" + String(kind)], before[kind] + minf(limits[kind], maxf(0.0, before["max_" + String(kind)] - before[kind])))
			transfer[kind] = after[kind] - before[kind]
			total += transfer[kind]
	var reason: String = "Free prototype service"
	if total <= 0.0:
		if service != &"all":
			reason = "Service disabled (limit 0)" if limits[service] <= 0.0 else "Already full"
		else:
			var missing: bool = before.hull < before.max_hull or before.battery < before.max_battery or before.oxygen < before.max_oxygen
			reason = "Service limits disabled" if missing else "All supplies full"
	return {"error": OK if total > 0.0 else ERR_UNAVAILABLE, "reason": reason, "service": service,
		"cost": "FREE", "before": before, "after": after, "transfer": transfer}


func perform(service: StringName) -> Dictionary:
	var result: Dictionary = quote(service)
	if result.error != OK:
		return result
	var player: SubmarineController = _live_player()
	_busy = true
	# Fixed order, existing domain APIs only. Never configure/reset vessel systems.
	player.hull_system.restore_hull(result.transfer.hull)
	player.resource_system.restore_battery(result.transfer.battery)
	player.resource_system.restore_oxygen(result.transfer.oxygen)
	result.after = _values(player)
	service_applied.emit(result.duplicate(true))
	_busy = false
	return result


func _draw() -> void:
	# Painted station infrastructure and the context HUD identify docking.
	# Interaction radii are domain data, not floating instructions or world circles.
	pass


func install_upgrade(id: StringName) -> Error:
	if _busy:
		return ERR_BUSY
	var check: Dictionary = _dock_check(_live_player(), true)
	if check.error != OK:
		return check.error
	if not is_instance_valid(upgrades):
		return ERR_UNCONFIGURED
	_busy = true
	var result: Error = upgrades.install(id)
	_busy = false
	return result


func recover_upgrades() -> Error:
	if _busy:
		return ERR_BUSY
	var check: Dictionary = _dock_check(_live_player(), true)
	if check.error != OK:
		return check.error
	if not is_instance_valid(upgrades):
		return ERR_UNCONFIGURED
	_busy = true
	var result: Error = upgrades.recover_backup()
	_busy = false
	return result


func mission_action(action: StringName, id: StringName = &"") -> Error:
	if _busy:
		return ERR_BUSY
	var check: Dictionary = _dock_check(_live_player(), true)
	if check.error != OK:
		return check.error
	if not is_instance_valid(missions):
		return ERR_UNCONFIGURED
	_busy = true
	var result: Error = ERR_INVALID_PARAMETER
	match action:
		&"accept": result = missions.accept(id)
		&"claim": result = missions.claim(id)
		&"recover": result = missions.recover_backup()
		&"sync": result = missions.reconcile()
	_busy = false
	return result
