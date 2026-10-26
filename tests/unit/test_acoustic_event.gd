extends GutTest


func _event(changes: Dictionary = {}) -> AcousticEvent:
	var values: Dictionary = {"id": &"run-01/vessel-01/0001", "source": &"vessel-01",
		"type": &"impulse", "category": &"mechanical", "position": Vector2(40, -20),
		"strength": 10.0, "range": 100.0, "time": 12.5}
	values.merge(changes, true)
	return AcousticEvent.create(values.id, values.source, values.type, values.category,
		values.position, values.strength, values.range, values.time)


func test_valid_event_has_explicit_stable_identity_units_and_time() -> void:
	var event: AcousticEvent = _event()
	assert_not_null(event)
	assert_true(event.is_valid())
	assert_eq(event.event_id, &"run-01/vessel-01/0001")
	assert_eq(event.source_id, &"vessel-01")
	assert_eq(event.event_type, &"impulse")
	assert_eq(event.classification, &"mechanical")
	assert_eq(event.origin, Vector2(40, -20))
	assert_eq(event.strength, 10.0)
	assert_eq(event.range_units, 100.0)
	assert_eq(event.simulation_time, 12.5)
	assert_false(AcousticEvent.new().is_valid())


func test_empty_oversized_or_unsupported_tokens_are_rejected_in_every_field() -> void:
	for key: String in ["id", "source", "type", "category"]:
		for token: StringName in [&"", &"contains space", &"unicode-魚", StringName("x".repeat(129))]:
			assert_null(_event({key: token}), key + ":" + String(token))
	assert_true(AcousticEvent.valid_token(&"session/vessel:001.impulse_test-2"))
	assert_true(AcousticEvent.valid_token(StringName("a".repeat(128))))


func test_negative_nonfinite_and_nonfinite_position_values_are_rejected() -> void:
	for key: String in ["strength", "range", "time"]:
		for value: float in [-0.001, INF, -INF, NAN]:
			assert_null(_event({key: value}))
	for position: Vector2 in [Vector2(NAN, 0), Vector2(0, INF), Vector2(-INF, 0)]:
		assert_null(_event({"position": position}))
	assert_not_null(_event({"strength": 0.0, "range": 0.0, "time": 0.0}))


func test_snapshots_are_distinct_and_payload_comparison_uses_all_fields() -> void:
	var event: AcousticEvent = _event()
	var copy: AcousticEvent = event.snapshot()
	assert_ne(event, copy)
	assert_true(event.same_payload(copy))
	for change: Dictionary in [{"id": &"different"}, {"source": &"different"},
		{"type": &"different"}, {"category": &"different"}, {"position": Vector2.ZERO},
		{"strength": 9.0}, {"range": 99.0}, {"time": 12.6}]:
		assert_false(event.same_payload(_event(change)))
	copy._strength = 1.0
	assert_eq(event.strength, 10.0)


func test_profiles_validate_finite_bounds_tokens_and_modes() -> void:
	var emission: AcousticEmissionProfile = AcousticEmissionProfile.new()
	var receiver: AcousticReceiverProfile = AcousticReceiverProfile.new()
	var dispatch: AcousticDispatchProfile = AcousticDispatchProfile.new()
	assert_true(emission.is_valid())
	assert_true(receiver.is_valid())
	assert_true(dispatch.is_valid())
	emission.event_type = &"invalid type"
	assert_false(emission.is_valid())
	emission.event_type = &"impulse"
	emission.range_units = -1.0
	assert_false(emission.is_valid())
	receiver.accepted_classifications = [&"invalid classification"]
	assert_false(receiver.is_valid())
	receiver.accepted_classifications = []
	receiver.minimum_strength = NAN
	assert_false(receiver.is_valid())
	dispatch.maximum_event_history = 0
	assert_false(dispatch.is_valid())
	dispatch.maximum_event_history = 4
	dispatch.attenuation = 42 as AcousticDispatchProfile.Attenuation
	assert_false(dispatch.is_valid())


func test_optional_attenuation_is_bounded_and_zero_range_has_no_division() -> void:
	var rules: AcousticDispatchProfile = AcousticDispatchProfile.new()
	var event: AcousticEvent = _event()
	assert_eq(rules.received_strength(event, 50.0), 10.0)
	rules.attenuation = AcousticDispatchProfile.Attenuation.LINEAR
	assert_eq(rules.received_strength(event, 0.0), 10.0)
	assert_eq(rules.received_strength(event, 50.0), 5.0)
	assert_eq(rules.received_strength(event, 100.0), 0.0)
	assert_eq(rules.received_strength(_event({"range": 0.0}), 0.0), 10.0)
