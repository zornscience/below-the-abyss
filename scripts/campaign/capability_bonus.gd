class_name CapabilityBonus
extends Resource
## A one-time, authored capability bonus granted by a story decision (DC-5: the Tethys calibration).
## Derived from the saved decision at read time, so it cannot disagree with the story state.
@export var stable_id: StringName
@export_range(0.0, 1000.0) var sonar_range_bonus: float = 0.0
func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and is_finite(sonar_range_bonus) and sonar_range_bonus>=0.0 and sonar_range_bonus<=1000.0
