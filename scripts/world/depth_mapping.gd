class_name DepthMapping
extends Resource
## Authored region-local water-surface plane; positive local Y points deeper.

@export var water_surface_local_y: float = 0.0
@export_range(0.0001, 1000.0) var meters_per_unit: float = 0.25


func is_valid() -> bool:
	return is_finite(water_surface_local_y) and is_finite(meters_per_unit) and meters_per_unit > 0.0


func depth_at_local(position: Vector2) -> float:
	if not is_valid() or not position.is_finite():
		return NAN
	return maxf(0.0, (position.y - water_surface_local_y) * meters_per_unit)
