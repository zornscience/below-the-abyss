class_name UpgradeDefinition
extends Resource
## One absolute authored capability replacement; never a multiplier.

enum Capability { SONAR_RADIUS, SAFE_DEPTH }
@export var stable_id: StringName = &""
@export var display_name: String = ""
@export var capability: Capability = Capability.SONAR_RADIUS
@export var baseline_value: float = 900.0
@export var upgraded_value: float = 1200.0


func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and not display_name.strip_edges().is_empty() \
		and display_name.length() <= 64 and capability in [Capability.SONAR_RADIUS, Capability.SAFE_DEPTH] \
		and is_finite(baseline_value) and baseline_value > 0.0 \
		and is_finite(upgraded_value) and upgraded_value > baseline_value and upgraded_value <= 1000000.0
