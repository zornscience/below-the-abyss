class_name SubmarineDamageConfig
extends Resource
## Prototype operating rating and bounded damage rules, not an upgrade system.

@export_range(1.0, 10000.0) var safe_operating_depth_m: float = 300.0
@export_range(0.0, 1000.0) var warning_margin_m: float = 40.0
@export_range(0.0, 60.0) var pressure_grace_seconds: float = 2.0
@export_range(0.0, 100.0) var pressure_damage_per_second: float = 4.0
@export_range(0.0, 2000.0) var impact_speed_threshold: float = 150.0
@export_range(0.0, 10.0) var collision_damage_per_speed: float = 0.1
@export_range(0.0, 100.0) var maximum_collision_damage: float = 20.0
@export_range(0.01, 10.0) var collision_cooldown_seconds: float = 0.75


func is_valid() -> bool:
	for value: float in [
		safe_operating_depth_m, warning_margin_m, pressure_grace_seconds,
		pressure_damage_per_second, impact_speed_threshold,
		collision_damage_per_speed, maximum_collision_damage,
	]:
		if not is_finite(value) or value < 0.0:
			return false
	return safe_operating_depth_m > warning_margin_m \
		and is_finite(collision_cooldown_seconds) and collision_cooldown_seconds > 0.0
