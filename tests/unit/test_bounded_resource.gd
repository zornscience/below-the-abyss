extends GutTest


func test_consumption_and_refill_saturate_and_return_actual_transfers() -> void:
	var pool: BoundedResource = BoundedResource.new(10.0)
	assert_eq(pool.consume(3.0), 3.0)
	assert_eq(pool.value, 7.0)
	assert_eq(pool.replenish(100.0), 3.0)
	assert_eq(pool.value, 10.0)
	assert_eq(pool.consume(100.0), 10.0)
	assert_eq(pool.value, 0.0)
	assert_eq(pool.replenish(4.0), 4.0)


func test_discrete_costs_are_all_or_nothing() -> void:
	var pool: BoundedResource = BoundedResource.new(10.0)
	watch_signals(pool)
	assert_false(pool.try_consume(11.0))
	assert_eq(pool.value, 10.0)
	assert_signal_not_emitted(pool, "changed")
	assert_true(pool.try_consume(10.0))
	assert_true(pool.try_consume(0.0))
	assert_false(pool.try_consume(1.0))
	assert_eq(pool.value, 0.0)


func test_depletion_is_an_edge_and_rearms_after_refill() -> void:
	var pool: BoundedResource = BoundedResource.new(10.0)
	watch_signals(pool)
	pool.consume(10.0)
	pool.consume(10.0)
	assert_signal_emit_count(pool, "depleted", 1)
	assert_signal_emit_count(pool, "changed", 1)
	assert_signal_emitted_with_parameters(pool, "changed", [0.0, 10.0])
	pool.replenish(2.0)
	pool.consume(2.0)
	assert_signal_emit_count(pool, "depleted", 2)
	assert_signal_emit_count(pool, "changed", 3)


func test_zero_and_invalid_transfers_do_not_change_state_or_emit() -> void:
	var pool: BoundedResource = BoundedResource.new(10.0)
	watch_signals(pool)
	for amount: float in [-1.0, NAN, INF, -INF]:
		assert_eq(pool.consume(amount), 0.0)
		assert_eq(pool.replenish(amount), 0.0)
		assert_false(pool.try_consume(amount))
	assert_eq(pool.consume(0.0), 0.0)
	assert_eq(pool.replenish(0.0), 0.0)
	assert_true(pool.try_consume(0.0))
	assert_eq(pool.value, 10.0)
	assert_signal_not_emitted(pool, "changed")
	assert_signal_not_emitted(pool, "depleted")


func test_explicit_values_clamp_but_nonfinite_values_are_rejected() -> void:
	var pool: BoundedResource = BoundedResource.new(10.0)
	assert_eq(pool.set_value(-10.0), OK)
	assert_eq(pool.value, 0.0)
	assert_eq(pool.set_value(100.0), OK)
	assert_eq(pool.value, 10.0)
	for value: float in [NAN, INF, -INF]:
		assert_eq(pool.set_value(value), ERR_INVALID_PARAMETER)
		assert_eq(pool.value, 10.0)


func test_small_capacities_and_fractional_endpoint_drift_are_supported() -> void:
	var small: BoundedResource = BoundedResource.new(0.001)
	assert_eq(small.consume(0.0), 0.0)
	assert_eq(small.value, 0.001)
	assert_gt(small.consume(0.00001), 0.0)
	var pool: BoundedResource = BoundedResource.new(1.0)
	watch_signals(pool)
	for _index: int in range(600):
		pool.consume(0.1 / 60.0)
	assert_eq(pool.value, 0.0)
	assert_signal_emit_count(pool, "depleted", 1)
	pool.replenish(1.0)
	assert_eq(pool.value, 1.0)


func test_transfer_result_is_stable_when_an_observer_refills_on_depletion() -> void:
	var pool: BoundedResource = BoundedResource.new(5.0)
	var callback: Callable = func(current: float, _maximum: float) -> void:
		if current == 0.0:
			pool.replenish(3.0)
	pool.changed.connect(callback)
	watch_signals(pool)
	assert_eq(pool.consume(10.0), 5.0, "Return the original transfer, not an observer's subsequent refill.")
	assert_eq(pool.value, 3.0)
	assert_signal_emit_count(pool, "depleted", 1)
	pool.changed.disconnect(callback)
