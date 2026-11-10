class_name SwarmerProfile
extends CreatureProfile
@export var dash_speed: float = 280.0
@export var dash_range: float = 350.0
@export var telegraph_seconds: float = 0.9
@export var dash_seconds: float = 1.0
@export var cooldown_seconds: float = 2.0
@export var bite_radius: float = 42.0
@export var bite_damage: float = 4.0
@export var maximum_health: float = 12.0
func is_valid() -> bool:
	if not super.is_valid(): return false
	for value: float in [dash_speed,dash_range,telegraph_seconds,dash_seconds,cooldown_seconds,bite_radius,bite_damage,maximum_health]:
		if not is_finite(value) or value<=0: return false
	return telegraph_seconds>=0.5 and bite_damage<=10 and maximum_health<=15 and dash_speed<=400
