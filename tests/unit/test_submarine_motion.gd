extends GutTest

var _motion: SubmarineMotion


func before_each() -> void:
	_motion = SubmarineMotion.new()


func _simulate(initial: Vector2, thrust: Vector2, seconds: float, rate: int) -> Vector2:
	var velocity: Vector2 = initial
	for _step: int in range(roundi(seconds * rate)):
		velocity = _motion.next_velocity(velocity, thrust, 1.0 / rate)
	return velocity


func test_acceleration_and_reversal_do_not_instantly_change_velocity() -> void:
	assert_eq(_motion.next_velocity(Vector2.ZERO, Vector2.RIGHT, 0.1), Vector2(60.0, 0.0))
	var reversed: Vector2 = _motion.next_velocity(Vector2(240.0, 0.0), Vector2.LEFT, 0.1)
	assert_eq(reversed, Vector2(180.0, 0.0), "Reversal brakes existing momentum first.")
	assert_eq(_motion.next_velocity(Vector2.ZERO, Vector2.UP, 0.1), Vector2(0.0, -60.0))


func test_neutral_damping_coasts_then_stops_without_reversing() -> void:
	var coast: Vector2 = _motion.next_velocity(Vector2(200.0, 0.0), Vector2.ZERO, 0.2)
	assert_almost_eq(coast.x, 200.0 * exp(-0.6), 0.001)
	assert_gt(coast.x, 0.0)
	assert_lt(coast.x, 200.0)
	assert_eq(_simulate(Vector2(240.0, 0.0), Vector2.ZERO, 3.0, 60), Vector2.ZERO)


func test_speed_limit_includes_diagonal_and_oversized_input() -> void:
	var diagonal: Vector2 = _simulate(Vector2.ZERO, Vector2(1.0, 1.0), 2.0, 60)
	assert_almost_eq(diagonal.length(), 240.0, 0.001)
	assert_almost_eq(diagonal.x, diagonal.y, 0.001)
	var oversized: Vector2 = _simulate(Vector2.ZERO, Vector2(100.0, 0.0), 2.0, 60)
	assert_almost_eq(oversized.length(), 240.0, 0.001)
	assert_lte(_motion.next_velocity(Vector2(1000.0, 0.0), Vector2.RIGHT, 0.1).length(), 240.0)


func test_partial_analog_input_sets_a_proportional_target_speed() -> void:
	var velocity: Vector2 = _simulate(Vector2.ZERO, Vector2(0.25, 0.0), 1.0, 60)
	assert_almost_eq(velocity.x, 60.0, 0.001)


func test_acceleration_and_drag_match_at_30_60_and_120_steps_per_second() -> void:
	for rate: int in [30, 60, 120]:
		var accelerating: Vector2 = _simulate(Vector2.ZERO, Vector2.RIGHT, 0.2, rate)
		assert_almost_eq(accelerating.x, 120.0, 0.001, "Acceleration rate %d" % rate)
		var coasting: Vector2 = _simulate(Vector2(200.0, 0.0), Vector2.ZERO, 1.0, rate)
		assert_almost_eq(coasting.x, 200.0 * exp(-3.0), 0.001, "Damping rate %d" % rate)


func test_parameters_are_configurable_without_mutating_authored_data() -> void:
	_motion.acceleration = 200.0
	_motion.maximum_speed = 80.0
	_motion.damping = 1.0
	assert_eq(_motion.next_velocity(Vector2.ZERO, Vector2.RIGHT, 0.1), Vector2(20.0, 0.0))
	assert_eq(_simulate(Vector2.ZERO, Vector2.RIGHT, 1.0, 60), Vector2(80.0, 0.0))
	assert_almost_eq(_simulate(Vector2(80.0, 0.0), Vector2.ZERO, 1.0, 60).x, 80.0 * exp(-1.0), 0.001)
	assert_eq(_motion.acceleration, 200.0)
	assert_eq(_motion.maximum_speed, 80.0)


func test_zero_time_and_rest_are_stable() -> void:
	assert_eq(_motion.next_velocity(Vector2(20.0, 10.0), Vector2.LEFT, 0.0), Vector2(20.0, 10.0))
	assert_eq(_motion.next_velocity(Vector2.ZERO, Vector2.ZERO, 1.0), Vector2.ZERO)
