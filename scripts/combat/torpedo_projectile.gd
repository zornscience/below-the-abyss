class_name TorpedoProjectile
extends Node2D
## Swept center-line collision, independent of render rate. Launcher owns stepping.
var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var remaining: float = 3.0
var event_id: StringName
var exploded: bool = false
var ignore: Array[RID] = []
signal impact(projectile: TorpedoProjectile, at: Vector2)
func advance(delta: float) -> void:
	if exploded or not is_finite(delta) or delta < 0.0:
		return
	var step: float = minf(delta, remaining)
	var next: Vector2 = global_position + direction * speed * step
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, next, 1 | 8, ignore)
	query.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	remaining = maxf(0.0, remaining - step)
	global_position = (hit.position + hit.normal * 0.1) if not hit.is_empty() else next
	if not hit.is_empty() or remaining <= 0.0:
		exploded = true
		impact.emit(self, global_position)
		queue_free()
func _draw() -> void:
	draw_line(-direction * 15.0, direction * 9.0, Color("d2d6c5"), 5.0, true)
	draw_circle(-direction * 16.0, 3.0, Color("e9c46a"))
