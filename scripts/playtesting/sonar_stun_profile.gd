class_name SonarStunProfile
extends Resource
@export var range_units: float = 220.0
@export var seconds: float = 2.0
@export var requires_clear_path: bool = true
func is_valid() -> bool:
	return is_finite(range_units) and range_units>0 and range_units<=500 and is_finite(seconds) and seconds>=1 and seconds<=3
