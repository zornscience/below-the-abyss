extends GutTest
func test_accelerated_distance_and_cruise_cap_match_30_60_120_steps() -> void:
	for rate: int in [30,60,120]:
		var projectile: TorpedoProjectile = TorpedoProjectile.new()
		projectile.position = Vector2(0,-5000)
		projectile.speed = 80
		projectile.acceleration = 500
		projectile.maximum_speed = 1100
		projectile.remaining = 5
		add_child_autofree(projectile)
		for step: int in range(rate*3): projectile.advance(1.0/rate)
		assert_almost_eq(projectile.position.x,2259.6,0.03)
		assert_eq(projectile.speed,1100.0)
		assert_almost_eq(projectile.remaining,2.0,0.000001)
func test_launch_is_slow_before_it_reaches_cruise_speed() -> void:
	var projectile: TorpedoProjectile = TorpedoProjectile.new()
	projectile.position = Vector2(0,-5000)
	projectile.speed = 80
	projectile.acceleration = 500
	projectile.remaining = 5
	add_child_autofree(projectile)
	projectile.advance(0.1)
	assert_almost_eq(projectile.position.x,10.5,0.001)
	assert_eq(projectile.speed,130.0)
func test_trail_remains_bounded_fades_and_survives_impact_until_expiry() -> void:
	var trail: TorpedoTrail = TorpedoTrail.new()
	add_child_autofree(trail)
	for step: int in range(1200): trail.sample(Vector2(step,0),1.0/120)
	assert_lte(trail.points.size(),73)
	assert_eq(trail.points.size(),trail.ages.size())
	assert_gt(trail.ages[0],trail.ages[-1])
	trail.active = false
	trail.sample(Vector2.ZERO,2.0)
	assert_true(trail.points.is_empty())
	assert_true(trail.is_queued_for_deletion())
func test_distortion_is_local_and_comfort_mode_suppresses_lens_and_flash() -> void:
	var effect: BlastEffect = BlastEffect.new()
	effect.refractive = true
	add_child_autofree(effect)
	assert_not_null(effect._lens)
	assert_eq(effect._lens.size,Vector2(600,600))
	effect.advance(0.2)
	assert_gt(float((effect._lens.material as ShaderMaterial).get_shader_parameter("phase")),0.0)
	var quiet: BlastEffect = BlastEffect.new()
	quiet.refractive = true
	quiet.reduced_effects = true
	add_child_autofree(quiet)
	assert_null(quiet._lens)
