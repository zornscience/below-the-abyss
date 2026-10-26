extends GutTest

var _bus: AcousticBus
var _emitter: AcousticEmitter
var _deliveries: Array[Dictionary] = []


func before_each() -> void:
	_deliveries.clear()
	_bus = AcousticBus.new()
	add_child_autofree(_bus)
	_emitter = AcousticEmitter.new()
	_emitter.source_id = &"vessel-01"
	_emitter.profile.range_units = 100.0
	_emitter.profile.strength = 10.0
	add_child_autofree(_emitter)
	assert_eq(_emitter.bind_bus(_bus), OK)


func _receiver(id: StringName, position: Vector2 = Vector2.ZERO) -> AcousticReceiver:
	var receiver: AcousticReceiver = AcousticReceiver.new()
	receiver.receiver_id = id
	receiver.position = position
	add_child_autofree(receiver)
	receiver.event_received.connect(_record.bind(id))
	assert_eq(receiver.bind_bus(_bus), OK)
	return receiver


func _record(event: AcousticEvent, strength: float, distance: float, id: StringName) -> void:
	_deliveries.append({"event": event, "strength": strength, "distance": distance, "id": id})


func _event(id: StringName = &"session/vessel/1", source: StringName = &"vessel-01") -> AcousticEvent:
	return AcousticEvent.create(id, source, &"test_impulse", &"mechanical", Vector2.ZERO, 10.0, 100.0, 2.0)


func test_registration_is_idempotent_and_conflicting_stable_ids_are_rejected() -> void:
	var receiver: AcousticReceiver = _receiver(&"receiver-01")
	assert_eq(_bus.register_receiver(receiver), OK)
	assert_eq(_bus.register_emitter(_emitter), OK)
	assert_eq(_bus.receiver_count(), 1)
	assert_eq(_bus.emitter_count(), 1)
	var duplicate: AcousticReceiver = AcousticReceiver.new()
	duplicate.receiver_id = receiver.receiver_id
	add_child_autofree(duplicate)
	assert_eq(_bus.register_receiver(duplicate), ERR_ALREADY_EXISTS)
	var duplicate_source: AcousticEmitter = AcousticEmitter.new()
	duplicate_source.source_id = _emitter.source_id
	add_child_autofree(duplicate_source)
	assert_eq(_bus.register_emitter(duplicate_source), ERR_ALREADY_EXISTS)
	assert_null(duplicate.get_bus())
	assert_eq(_emitter.emit_event(&"session/vessel/1", 2.0), OK)
	assert_eq(_deliveries.size(), 1)


func test_invalid_outside_tree_and_cross_bus_registration_are_rejected() -> void:
	var receiver: AcousticReceiver = autofree(AcousticReceiver.new())
	assert_eq(_bus.register_receiver(receiver), ERR_INVALID_PARAMETER)
	receiver.receiver_id = &"outside"
	assert_eq(_bus.register_receiver(receiver), ERR_UNCONFIGURED)
	var bound: AcousticReceiver = _receiver(&"bound")
	var other: AcousticBus = AcousticBus.new()
	add_child_autofree(other)
	assert_eq(other.register_receiver(bound), ERR_ALREADY_IN_USE)
	assert_eq(bound.get_bus(), _bus)
	assert_eq(bound.bind_bus(null), OK)
	assert_eq(bound.bind_bus(other), OK)
	assert_eq(_bus.receiver_count(), 0)
	assert_eq(other.receiver_count(), 1)


func test_removal_is_explicit_and_removed_receivers_never_receive() -> void:
	var receiver: AcousticReceiver = _receiver(&"removed")
	assert_eq(_bus.unregister_receiver(receiver), OK)
	assert_null(receiver.get_bus())
	assert_eq(_bus.unregister_receiver(receiver), ERR_DOES_NOT_EXIST)
	assert_eq(_emitter.emit_event(&"session/vessel/1", 2.0), OK)
	assert_true(_deliveries.is_empty())
	assert_eq(_emitter.bind_bus(null), OK)
	assert_eq(_emitter.emit_event(&"session/vessel/2", 2.0), ERR_UNCONFIGURED)


func test_range_and_receiver_radius_boundaries_are_inclusive_and_zero_is_coincident_only() -> void:
	_receiver(&"inside", Vector2(60, 79))
	_receiver(&"boundary", Vector2(60, 80))
	_receiver(&"outside", Vector2(60, 80.01))
	var limited: AcousticReceiver = _receiver(&"limited", Vector2(3, 4))
	limited.profile.maximum_range_units = 5.0
	var rejected: AcousticReceiver = _receiver(&"receiver-radius-outside", Vector2(5.01, 0))
	rejected.profile.maximum_range_units = 5.0
	assert_eq(_bus.dispatch(_emitter, _event()), OK)
	assert_eq(_deliveries.map(func(item: Dictionary) -> StringName: return item.id), [&"boundary", &"inside", &"limited"])
	_deliveries.clear()
	_receiver(&"coincident")
	var zero: AcousticEvent = AcousticEvent.create(&"zero", _emitter.source_id, &"test_impulse", &"mechanical", Vector2.ZERO, 1.0, 0.0, 2.0)
	assert_eq(_bus.dispatch(_emitter, zero), OK)
	assert_eq(_deliveries.size(), 1)
	assert_eq(_deliveries[0].id, &"coincident")


func test_types_classifications_sources_enablement_and_thresholds_filter_without_duplicates() -> void:
	var accepted: AcousticReceiver = _receiver(&"accepted")
	accepted.profile.accepted_event_types = [&"test_impulse", &"test_impulse"]
	accepted.profile.accepted_classifications = [&"mechanical"]
	accepted.profile.minimum_strength = 10.0
	var type_rejected: AcousticReceiver = _receiver(&"type")
	type_rejected.profile.accepted_event_types = [&"other"]
	var class_rejected: AcousticReceiver = _receiver(&"class")
	class_rejected.profile.accepted_classifications = [&"geological"]
	var source_rejected: AcousticReceiver = _receiver(&"source")
	source_rejected.profile.excluded_source_ids = [_emitter.source_id]
	var weak: AcousticReceiver = _receiver(&"weak")
	weak.profile.minimum_strength = 10.01
	var disabled: AcousticReceiver = _receiver(&"disabled")
	disabled.enabled = false
	var invalid: AcousticReceiver = _receiver(&"invalid-profile")
	invalid.profile.minimum_strength = NAN
	assert_eq(_bus.dispatch(_emitter, _event()), OK)
	assert_eq(_deliveries.size(), 1)
	assert_eq(_deliveries[0].id, &"accepted")


func test_attenuation_is_optional_and_minimum_strength_uses_the_attenuated_value() -> void:
	var edge: AcousticReceiver = _receiver(&"edge", Vector2(100, 0))
	var middle: AcousticReceiver = _receiver(&"middle", Vector2(50, 0))
	middle.profile.minimum_strength = 5.0
	var weak: AcousticReceiver = _receiver(&"weak", Vector2(50.01, 0))
	weak.profile.minimum_strength = 5.0
	var rules: AcousticDispatchProfile = AcousticDispatchProfile.new()
	rules.attenuation = AcousticDispatchProfile.Attenuation.LINEAR
	assert_eq(_bus.configure(rules), OK)
	assert_eq(_bus.dispatch(_emitter, _event()), OK)
	assert_eq(_deliveries.size(), 2)
	assert_eq(_deliveries[0].id, edge.receiver_id)
	assert_eq(_deliveries[0].strength, 0.0)
	assert_eq(_deliveries[1].strength, 5.0)
	assert_eq(_deliveries[1].distance, 50.0)


func test_duplicate_ids_are_suppressed_and_conflicting_payloads_are_rejected() -> void:
	_receiver(&"first")
	var event: AcousticEvent = _event()
	assert_eq(_bus.dispatch(_emitter, event), OK)
	assert_eq(_bus.dispatch(_emitter, event.snapshot()), ERR_ALREADY_EXISTS)
	_receiver(&"late")
	assert_eq(_bus.dispatch(_emitter, event), ERR_ALREADY_EXISTS)
	event._strength = 11.0
	assert_eq(_bus.dispatch(_emitter, event), ERR_INVALID_DATA)
	assert_eq(_deliveries.size(), 1)
	assert_eq(_bus.history_count(), 1)


func test_history_capacity_fails_closed_without_eviction_and_configure_preserves_history() -> void:
	_receiver(&"listener")
	var rules: AcousticDispatchProfile = AcousticDispatchProfile.new()
	rules.maximum_event_history = 1
	assert_eq(_bus.configure(rules), OK)
	rules.maximum_event_history = 999
	assert_eq(_bus.dispatch(_emitter, _event()), OK)
	assert_eq(_bus.dispatch(_emitter, _event(&"second")), ERR_OUT_OF_MEMORY)
	assert_eq(_bus.dispatch(_emitter, _event()), ERR_ALREADY_EXISTS)
	rules.maximum_event_history = 2
	assert_eq(_bus.configure(rules), OK)
	assert_eq(_bus.dispatch(_emitter, _event(&"second")), OK)
	var invalid: AcousticDispatchProfile = AcousticDispatchProfile.new()
	invalid.maximum_event_history = 1
	assert_eq(_bus.configure(invalid), ERR_INVALID_PARAMETER)
	assert_eq(_deliveries.size(), 2)
	assert_eq(_bus.history_count(), 2)


func test_invalid_events_or_unregistered_and_spoofed_sources_do_not_consume_history() -> void:
	_receiver(&"listener")
	assert_eq(_bus.dispatch(_emitter, null), ERR_INVALID_PARAMETER)
	assert_eq(_bus.dispatch(_emitter, AcousticEvent.new()), ERR_INVALID_PARAMETER)
	assert_eq(_bus.dispatch(_emitter, _event(&"spoof", &"other-source")), ERR_UNCONFIGURED)
	var impostor: AcousticEmitter = AcousticEmitter.new()
	impostor.source_id = _emitter.source_id
	add_child_autofree(impostor)
	assert_eq(_bus.dispatch(impostor, _event()), ERR_UNCONFIGURED)
	assert_eq(_bus.history_count(), 0)
	assert_true(_deliveries.is_empty())


func test_delivery_is_sorted_by_stable_receiver_id_not_registration_order() -> void:
	for id: StringName in [&"zulu", &"alpha", &"middle"]:
		_receiver(id)
	watch_signals(_bus)
	assert_eq(_bus.dispatch(_emitter, _event()), OK)
	assert_eq(_deliveries.map(func(item: Dictionary) -> StringName: return item.id), [&"alpha", &"middle", &"zulu"])
	assert_signal_emitted_with_parameters(_bus, "event_dispatched", [&"session/vessel/1", 3])


func test_callback_mutations_cannot_change_other_recipients_or_the_history_payload() -> void:
	var first: AcousticReceiver = _receiver(&"a")
	var later: AcousticReceiver = _receiver(&"b", Vector2(50, 0))
	first.event_received.connect(func(event: AcousticEvent, _strength: float, _distance: float) -> void:
		event._strength = 999.0
		later.position = Vector2(1000, 0)
		later.enabled = false
		later.profile.accepted_event_types = [&"other"])
	var original: AcousticEvent = _event()
	assert_eq(_bus.dispatch(_emitter, original), OK)
	assert_eq(_deliveries.size(), 2)
	assert_eq((_deliveries[1].event as AcousticEvent).strength, 10.0)
	assert_eq(_deliveries[1].distance, 50.0, "Eligibility/positions are frozen before callbacks.")
	assert_eq(original.strength, 10.0)
	assert_eq(_bus.dispatch(_emitter, original), ERR_ALREADY_EXISTS)
	_deliveries.clear()
	assert_eq(_bus.dispatch(_emitter, _event(&"next")), OK)
	assert_eq(_deliveries.size(), 1, "Changes affect the next distinct event.")


func test_reentrant_dispatch_is_busy_and_does_not_record_a_rejected_event() -> void:
	var receiver: AcousticReceiver = _receiver(&"listener")
	var attempts: Array[Error] = []
	receiver.event_received.connect(func(_event_value: AcousticEvent, _strength: float, _distance: float) -> void:
		attempts.append(_bus.dispatch(_emitter, _event(&"nested")))
		attempts.append(_bus.configure(AcousticDispatchProfile.new())))
	assert_eq(_bus.dispatch(_emitter, _event()), OK)
	assert_eq(attempts, [ERR_BUSY, ERR_BUSY])
	assert_eq(_bus.history_count(), 1)


func test_large_finite_world_coordinates_do_not_overflow_distance_calculation() -> void:
	var receiver: AcousticReceiver = _receiver(&"distant", Vector2(1.0e20, 0))
	var event: AcousticEvent = AcousticEvent.create(&"large", _emitter.source_id, &"impulse",
		&"mechanical", Vector2.ZERO, 10.0, 2.0e20, 2.0)
	receiver.profile.maximum_range_units = 2.0e20
	assert_eq(_bus.dispatch(_emitter, event), OK)
	assert_eq(_deliveries.size(), 1)
	assert_true(is_finite(_deliveries[0].distance))
	assert_gt(_deliveries[0].distance, 9.0e19)


func test_emitter_validates_requests_and_notifies_only_for_accepted_events() -> void:
	_receiver(&"listener")
	watch_signals(_emitter)
	_emitter.profile.range_units = NAN
	assert_eq(_emitter.emit_event(&"first", 1.0), ERR_INVALID_PARAMETER)
	_emitter.profile.range_units = 100.0
	assert_eq(_emitter.emit_event(&"invalid id", 1.0), ERR_INVALID_PARAMETER)
	assert_eq(_emitter.emit_event(&"first", -1.0), ERR_INVALID_PARAMETER)
	assert_eq(_bus.history_count(), 0)
	assert_signal_not_emitted(_emitter, "event_emitted")
	assert_eq(_emitter.emit_event(&"first", 1.0), OK)
	assert_eq(_emitter.emit_event(&"first", 1.0), ERR_ALREADY_EXISTS)
	assert_signal_emit_count(_emitter, "event_emitted", 1)
	assert_eq(_deliveries.size(), 1)
