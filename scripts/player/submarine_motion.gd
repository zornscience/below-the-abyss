class_name SubmarineMotion
extends Resource
## Velocity response in pixels/second. No scene, input, or collision dependencies.

@export_range(1.0, 5000.0, 1.0) var acceleration: float = 600.0
@export_range(1.0, 2000.0, 1.0) var maximum_speed: float = 240.0
@export_range(0.0, 20.0, 0.1) var damping: float = 3.0


func next_velocity(current: Vector2, thrust: Vector2, delta: float) -> Vector2:
	if delta <= 0.0:
		return current
	var next: Vector2
	if thrust.is_zero_approx():
		# Exponential drag gives the same decay over an elapsed duration at any
		# step size. Snap only the final sub-pixel drift to a complete stop.
		next = current * exp(-damping * delta)
		if next.length() < 0.5:
			next = Vector2.ZERO
	else:
		var target: Vector2 = thrust.limit_length(1.0) * maximum_speed
		next = current.move_toward(target, acceleration * delta)
	return next.limit_length(maximum_speed)
