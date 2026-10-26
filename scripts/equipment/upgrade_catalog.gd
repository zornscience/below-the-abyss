class_name UpgradeCatalog
extends Resource
## BTA-033 intentionally supports exactly one sonar and one pressure-hull upgrade.

@export var stable_id: StringName = &"neris-prototype"
@export var baseline_sonar: ActiveSonarProfile
@export var baseline_damage: SubmarineDamageConfig
@export var upgrades: Array[UpgradeDefinition] = []


func is_valid() -> bool:
	if not PointOfInterest.valid_id(stable_id) or baseline_sonar == null or not baseline_sonar.is_valid() \
		or baseline_damage == null or not baseline_damage.is_valid() or upgrades.size() != 2:
		return false
	var ids: Array[StringName] = []
	var capabilities: Array[int] = []
	for definition: UpgradeDefinition in upgrades:
		if definition == null or not definition.is_valid() or definition.stable_id in ids or definition.capability in capabilities:
			return false
		var baseline: float = baseline_sonar.maximum_radius if definition.capability == UpgradeDefinition.Capability.SONAR_RADIUS else baseline_damage.safe_operating_depth_m
		if definition.baseline_value != baseline:
			return false
		ids.append(definition.stable_id)
		capabilities.append(definition.capability)
	return true


func knows_id(id: StringName) -> bool:
	for definition: UpgradeDefinition in upgrades:
		if definition.stable_id == id:
			return true
	return false


func valid_ids(ids: Array[StringName]) -> bool:
	if ids.size() > 2:
		return false
	var seen: Array[StringName] = []
	for id: StringName in ids:
		if not knows_id(id) or id in seen:
			return false
		seen.append(id)
	return true
