extends GutTest


func test_base_alone_and_a_return_without_the_landmark_do_not_complete() -> void:
	var check: GrayboxRouteCheck = GrayboxRouteCheck.new()
	assert_eq(check.sample(true, false, 20.0), OK)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.AT_BASE)
	assert_eq(check.elapsed_seconds, 0.0)
	check.sample(false, false, 2.0)
	check.sample(true, false, 1.0)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.OUTBOUND)
	assert_eq(check.elapsed_seconds, 3.0)


func test_landmark_then_return_completes_once_and_freezes_the_result() -> void:
	var check: GrayboxRouteCheck = GrayboxRouteCheck.new()
	watch_signals(check)
	check.sample(false, false, 2.0)
	check.sample(false, true, 3.0)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.RETURNING)
	check.sample(true, false, 0.1)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.COMPLETE)
	assert_eq(check.elapsed_seconds, 5.0)
	check.sample(false, true, 50.0)
	check.sample(true, false, 50.0)
	assert_eq(check.elapsed_seconds, 5.0)
	assert_signal_emit_count(check, "stage_changed", 3)
	check.reset()
	assert_eq(check.stage, GrayboxRouteCheck.Stage.AT_BASE)
	assert_eq(check.elapsed_seconds, 0.0)
	assert_signal_emit_count(check, "stage_changed", 4)


func test_invalid_time_and_ambiguous_zone_samples_do_not_fake_completion() -> void:
	var check: GrayboxRouteCheck = GrayboxRouteCheck.new()
	for delta: float in [-1.0, NAN, INF]:
		assert_eq(check.sample(false, true, delta), ERR_INVALID_PARAMETER)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.AT_BASE)
	check.sample(true, true, 1.0)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.AT_BASE)
	check.sample(false, false, 1.0)
	check.sample(true, true, 1.0)
	assert_eq(check.stage, GrayboxRouteCheck.Stage.OUTBOUND)


func test_route_clock_is_consistent_at_30_60_and_120_steps() -> void:
	for rate: int in [30, 60, 120]:
		var check: GrayboxRouteCheck = GrayboxRouteCheck.new()
		for index: int in range(rate * 10):
			check.sample(false, index > rate * 5, 1.0 / rate)
		check.sample(true, false, 0.0)
		assert_eq(check.stage, GrayboxRouteCheck.Stage.COMPLETE)
		assert_almost_eq(check.elapsed_seconds, 10.0, 0.00001)


func test_zone_uses_its_authored_collision_shape_and_transform() -> void:
	var zone: GrayboxRouteZone = GrayboxRouteZone.new()
	var boundary: CollisionShape2D = CollisionShape2D.new()
	boundary.name = "Boundary"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(100, 80)
	boundary.shape = rectangle
	zone.add_child(boundary)
	zone.position = Vector2(400, 300)
	zone.rotation = 0.4
	zone.scale = Vector2(2, 1.5)
	add_child_autofree(zone)
	assert_true(zone.contains_world_position(zone.to_global(Vector2(40, 30))))
	assert_false(zone.contains_world_position(zone.to_global(Vector2(60, 30))))
	assert_false(zone.contains_world_position(Vector2(NAN, 0)))
