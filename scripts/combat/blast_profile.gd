class_name BlastProfile
extends Resource
@export var radius: float = 150.0
@export var damage: float = 60.0
@export var speed: float = 800.0
@export var lifetime: float = 3.0
@export var cooldown: float = 1.2
@export var battery_cost: float = 2.0

func is_valid() -> bool:
	for value: float in [radius, damage, speed, lifetime, cooldown]:
		if not is_finite(value) or value <= 0.0 or value > 5000.0:
			return false
	return radius >= 1.0 and radius <= 160.0 and is_finite(battery_cost) and battery_cost >= 0.0 and battery_cost <= 100.0
