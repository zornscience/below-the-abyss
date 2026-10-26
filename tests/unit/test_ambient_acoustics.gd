extends GutTest


func test_global_schedule_order_ids_and_contacts_match_at_30_60_120_and_large_steps() -> void:
	var expected: Array[Dictionary] = []
	for rate: int in [1, 30, 60, 120]:
		var rig: PassiveTestRig = PassiveTestRig.new()
		add_child_autofree(rig)
		rig.ambient(&"z", Vector2(100, 0), 1.0, 3.0, 3)
		rig.ambient(&"a", Vector2(200, 0), 1.0, 2.0, 3)
		assert_eq(rig.field.bind_bus(rig.bus), OK)
		var events: Array[Dictionary] = []
		rig.listener.receiver.event_received.connect(func(event: AcousticEvent, _strength: float, _distance: float) -> void:
			events.append({"id": event.event_id, "source": event.source_id, "time": event.simulation_time}))
		for _step: int in range(rate * 8):
			rig.step(1.0 / rate)
		assert_eq(events.size(), 6)
		if expected.is_empty():
			expected = events.duplicate(true)
		else:
			assert_eq(events, expected)
		assert_eq(events[0].source, &"a", "Equal deadlines use source ID, not scene order.")
		assert_eq(rig.bus.history_count(), 6)
		var contacts: Array[Dictionary] = rig.listener.contacts_snapshot()
		assert_eq(contacts.size(), 2)
		for contact: Dictionary in contacts:
			assert_almost_eq(contact.remaining_seconds, 5.0 if contact.source_id == &"a" else 7.0, 0.00001)


func test_restart_uses_new_epoch_ids_and_retains_acoustic_history() -> void:
	var rig: PassiveTestRig = PassiveTestRig.new()
	add_child_autofree(rig)
	rig.ambient(&"source", Vector2(100, 0))
	assert_eq(rig.field.bind_bus(rig.bus), OK)
	rig.step(1.0)
	var id: StringName = rig.listener.contacts_snapshot()[0].event_id
	assert_eq(rig.field.reset_session(), OK)
	rig.listener.reset_session()
	assert_true(rig.listener.contacts_snapshot().is_empty())
	assert_eq(rig.bus.history_count(), 1)
	rig.step(1.0)
	assert_ne(rig.listener.contacts_snapshot()[0].event_id, id)
	assert_eq(rig.bus.history_count(), 2)


func test_emission_budget_and_full_bus_stop_without_retry_floods() -> void:
	var rig: PassiveTestRig = PassiveTestRig.new()
	add_child_autofree(rig)
	var source: AmbientSoundEmitter = rig.ambient(&"source", Vector2.ZERO, 1.0, 1.0, 2)
	assert_eq(rig.field.bind_bus(rig.bus), OK)
	rig.step(100.0)
	assert_eq(rig.bus.history_count(), 2)
	assert_false(is_finite(source.next_event_time()))
	assert_true(rig.listener.contacts_snapshot().is_empty(), "Large catch-up cannot extend expired events.")
	rig.field.reset_session()
	rig.listener.reset_session()
	var budget: AcousticDispatchProfile = AcousticDispatchProfile.new()
	budget.maximum_event_history = 2
	assert_eq(rig.bus.configure(budget), OK)
	rig.step(2.0)
	assert_eq(source.last_result, ERR_OUT_OF_MEMORY)
	rig.step(100.0)
	assert_eq(rig.bus.history_count(), 2)
	assert_false(is_finite(source.next_event_time()))


func test_emitter_configuration_rejects_active_types_invalid_frequency_and_nonfinite_values() -> void:
	for property: String in ["first_delay", "interval_seconds", "strength", "range_units"]:
		var profile: AmbientEmissionProfile = AmbientEmissionProfile.new()
		profile.set(property, NAN)
		assert_false(profile.is_valid())
	var profile: AmbientEmissionProfile = AmbientEmissionProfile.new()
	profile.event_type = &"active_sonar"
	assert_false(profile.is_valid())

	profile.event_type = &"ambient"
	profile.interval_seconds = 0.01
	assert_false(profile.is_valid())
	profile.interval_seconds = 6.0
	profile.maximum_events = 10000
	assert_false(profile.is_valid())


func test_conflicting_source_registration_rolls_back_only_new_bindings() -> void:
	var rig: PassiveTestRig = PassiveTestRig.new()
	add_child_autofree(rig)
	rig.ambient(&"same", Vector2.ZERO)
	rig.ambient(&"same", Vector2.ZERO)
	assert_eq(rig.field.bind_bus(rig.bus), ERR_ALREADY_EXISTS)
	assert_eq(rig.bus.emitter_count(), 0)
	assert_eq(rig.bus.history_count(), 0)
