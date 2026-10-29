class_name ExpeditionPressureFit
extends Resource
## Authored commissioning baseline; existing purchased hull ranks supply their margin.
@export var stable_id: StringName = &"twilight-pressure-1000"
@export var baseline_safe_depth_m: float = 1000.0
func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and is_finite(baseline_safe_depth_m) and baseline_safe_depth_m>=1000.0 and baseline_safe_depth_m<=2000.0
