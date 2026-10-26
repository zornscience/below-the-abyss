class_name ActiveSonarProfile
extends Resource
## Prototype values in native battery units, world pixels and simulation seconds.

@export var battery_cost: float = 4.0
@export var cooldown_seconds: float = 4.0
@export var travel_speed: float = 600.0
@export var maximum_radius: float = 900.0
@export var signal_strength: float = 1.0
@export var reveal_seconds: float = 6.0
@export var fade_seconds: float = 0.2
@export_range(1, 64) var maximum_active_pulses: int = 8


func is_valid() -> bool:
	for value: float in [battery_cost, cooldown_seconds, signal_strength, fade_seconds]:
		if not is_finite(value) or value < 0.0:
			return false
	return is_finite(travel_speed) and travel_speed > 0.0 and travel_speed <= 1000000.0 \
		and is_finite(maximum_radius) and maximum_radius > 0.0 and maximum_radius <= 1000000.0 \
		and is_finite(reveal_seconds) and reveal_seconds > 0.0 \
		and is_finite(maximum_radius / travel_speed + fade_seconds) \
		and maximum_active_pulses >= 1 and maximum_active_pulses <= 64
