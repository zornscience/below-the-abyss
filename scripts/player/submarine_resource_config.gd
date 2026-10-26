class_name SubmarineResourceConfig
extends Resource
## Authored capacities/rates only; current values belong to vessel components.

@export_range(0.001, 100000.0) var max_hull: float = 100.0
@export_range(0.001, 100000.0) var max_battery: float = 100.0
@export_range(0.001, 100000.0) var max_oxygen: float = 100.0
@export_range(0.0, 1000.0) var battery_idle_drain_per_second: float = 0.25
@export_range(0.0, 1000.0) var battery_thrust_drain_per_second: float = 1.5
@export_range(0.0, 1000.0) var oxygen_drain_per_second: float = 0.5


func is_valid() -> bool:
	for capacity: float in [max_hull, max_battery, max_oxygen]:
		if not is_finite(capacity) or capacity <= 0.0:
			return false
	for rate: float in [
		battery_idle_drain_per_second, battery_thrust_drain_per_second, oxygen_drain_per_second,
	]:
		if not is_finite(rate) or rate < 0.0:
			return false
	return true
