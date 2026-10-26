class_name GrayboxRouteZone
extends Area2D
## Authored test volumes, not station interactions or a discovery registry.


func contains_world_position(world_position: Vector2) -> bool:
	if not world_position.is_finite():
		return false
	var boundary: CollisionShape2D = $Boundary
	var rectangle: RectangleShape2D = boundary.shape as RectangleShape2D
	return rectangle != null and Rect2(-rectangle.size * 0.5, rectangle.size).has_point(
		boundary.to_local(world_position))
