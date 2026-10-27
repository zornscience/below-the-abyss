extends GutTest
func test_swept_ray_hits_thin_wall_exactly_once_at_every_step_rate() -> void:
	var world: Node2D = Node2D.new()
	add_child_autofree(world)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = Vector2(100,-500)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(2,200)
	collision.shape = rectangle
	wall.add_child(collision)
	world.add_child(wall)
	await wait_physics_frames(2)
	for rate: int in [30,60,120]:
		var projectile: TorpedoProjectile = TorpedoProjectile.new()
		world.add_child(projectile)
		projectile.position = Vector2(0,-500)
		watch_signals(projectile)
		for step: int in range(rate):
			projectile.advance(1.0/rate)
			if projectile.exploded: break
		assert_true(projectile.exploded)
		assert_almost_eq(projectile.position.x,98.9,0.001)
		assert_signal_emit_count(projectile,"impact",1)
		projectile.advance(1.0)
		assert_signal_emit_count(projectile,"impact",1)
