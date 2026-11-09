class_name ActionCostProfile
extends Resource
## Regional action costs; holds no supplies or persisted state.
@export var ping_battery: float = 5.0
@export var torpedo_battery: float = 5.0
func is_valid() -> bool:
	return is_finite(ping_battery) and ping_battery > 0 and is_finite(torpedo_battery) and torpedo_battery > 0
