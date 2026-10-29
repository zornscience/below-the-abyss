class_name ThermalVentProfile
extends Resource
## A local hydrothermal jet, not depth pressure. Distances are world units.
@export var quiet_seconds: float = 8.0
@export var warning_seconds: float = 4.0
@export var erupt_seconds: float = 3.0
@export var cooling_seconds: float = 5.0
@export var hull_per_second: float = 4.0
@export var plume: Rect2 = Rect2(-140,-550,190,290)
@export var warning_radius: float = 650.0
func is_valid() -> bool:
	for duration: float in [quiet_seconds,warning_seconds,erupt_seconds,cooling_seconds]:
		if not is_finite(duration) or duration<1.0 or duration>120.0: return false
	var reach: Vector2 = Vector2(maxf(absf(plume.position.x),absf(plume.end.x)),maxf(absf(plume.position.y),absf(plume.end.y)))
	return is_finite(hull_per_second) and hull_per_second>=0.0 and hull_per_second<=20.0 \
		and plume.position.is_finite() and plume.size.is_finite() and plume.size.x>=40 and plume.size.x<=400 \
		and plume.size.y>=40 and plume.size.y<=800 and plume.end.y<=0 \
		and is_finite(warning_radius) and warning_radius>=(reach+Vector2.ONE*28.0).length() and warning_radius<=2000
func cycle_seconds() -> float:
	return quiet_seconds+warning_seconds+erupt_seconds+cooling_seconds
