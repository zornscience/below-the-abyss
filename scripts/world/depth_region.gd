class_name DepthRegion
extends Node2D
## Converts world positions through an authored region frame before mapping depth.

@export var mapping: DepthMapping = DepthMapping.new()


func _ready() -> void:
	if mapping == null or not mapping.is_valid():
		push_error("DepthRegion needs a valid authored water-surface mapping.")


func depth_at_world(world_position: Vector2) -> float:
	if mapping == null or not world_position.is_finite() or absf(global_transform.determinant()) < 0.000001:
		return NAN
	return mapping.depth_at_local(to_local(world_position))
