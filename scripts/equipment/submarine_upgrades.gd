class_name SubmarineUpgrades
extends Node
## Persistent installed IDs, independent of transient route/sonar/resource state.

signal capabilities_changed
signal upgrade_installed(id: StringName)
var store: UpgradeStore = UpgradeStore.new()
var _catalog: UpgradeCatalog
var _sonar: SonarEmitter
var _damage: SubmarineDamageSystem
var _installed: Array[StringName] = []
var _busy: bool = false


func setup(catalog: UpgradeCatalog, sonar: SonarEmitter, damage: SubmarineDamageSystem, path: String) -> Error:
	if _catalog != null:
		return ERR_ALREADY_IN_USE
	if catalog == null or not catalog.is_valid() or not is_instance_valid(sonar) or not is_instance_valid(damage) \
		or not sonar.is_node_ready() or not damage.is_node_ready() \
		or damage.configuration.safe_operating_depth_m != catalog.baseline_damage.safe_operating_depth_m \
		or sonar.configuration.maximum_radius != catalog.baseline_sonar.maximum_radius:
		return ERR_INVALID_PARAMETER
	_catalog = catalog.duplicate(true) as UpgradeCatalog
	_sonar = sonar
	_damage = damage
	store.path = path
	var document: Dictionary = store.load_ids(_catalog)
	if document.error == OK:
		_installed.assign(document.ids)
	_apply()
	return OK


func installed_ids() -> Array[StringName]:
	return _installed.duplicate()


func definitions() -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	if _catalog != null:
		for definition: UpgradeDefinition in _catalog.upgrades:
			result.append(definition.duplicate() as UpgradeDefinition)
	return result


func is_installed(id: StringName) -> bool:
	return id in _installed


func install(id: StringName) -> Error:
	if _busy:
		return ERR_BUSY
	if _catalog == null or not _catalog.knows_id(id):
		return ERR_INVALID_PARAMETER
	if is_installed(id):
		return ERR_ALREADY_EXISTS
	if not is_instance_valid(_sonar) or not is_instance_valid(_damage):
		return ERR_UNCONFIGURED
	if _sonar.is_mutating():
		return ERR_BUSY
	_busy = true
	var candidate: Array[StringName] = installed_ids()
	candidate.append(id)
	# Commit ID-only persistence before exposing the capability. Failed saves do not install.
	var result: Error = store.save_ids(candidate, _catalog)
	if result == OK:
		_installed = candidate
		_apply()
		upgrade_installed.emit(id)
	_busy = false
	return result


func recover_backup() -> Error:
	if _busy or _catalog == null or not is_instance_valid(_sonar) or not is_instance_valid(_damage) or _sonar.is_mutating():
		return ERR_BUSY
	_busy = true
	var document: Dictionary = store.recover_backup(_catalog)
	if document.error == OK:
		_installed.assign(document.ids)
		_apply()
	_busy = false
	return document.error


func reapply() -> void:
	# Called after the existing test-route damage reset. Does not reload or install.
	if _catalog != null:
		_apply()


func _apply() -> void:
	var sonar_profile: ActiveSonarProfile = _catalog.baseline_sonar.duplicate() as ActiveSonarProfile
	var depth: float = _catalog.baseline_damage.safe_operating_depth_m
	for definition: UpgradeDefinition in _catalog.upgrades:
		if definition.stable_id in _installed:
			if definition.capability == UpgradeDefinition.Capability.SONAR_RADIUS:
				sonar_profile.maximum_radius = definition.upgraded_value
			else:
				depth = definition.upgraded_value
	# configure snapshots tuning only; it preserves pulses, cooldown, time and event IDs.
	_sonar.configure(sonar_profile)
	_damage.set_maximum_depth_m(depth)
	capabilities_changed.emit()
