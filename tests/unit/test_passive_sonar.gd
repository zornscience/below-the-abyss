extends GutTest

var _rig: PassiveTestRig


func before_each() -> void:
	_rig = PassiveTestRig.new()
	add_child_autofree(_rig)


func test_receives_ambient_classification_and_approximate_strength_without_producing_events() -> void:
	var source: AcousticEmitter = _rig.emitter(&"mechanical", Vector2(400, 0))
	watch_signals(_rig.bus)
	assert_eq(source.emit_event(&"event-1", 0.0), OK)
	var contacts: Array[Dictionary] = _rig.listener.contacts_snapshot()
	assert_eq(contacts.size(), 1)
	assert_eq(contacts[0].classification, &"mechanical")
	assert_eq(contacts[0].source_id, &"mechanical")
	assert_eq(contacts[0].bearing_degrees, 0.0)
	assert_almost_eq(contacts[0].signal_strength, 0.6, 0.00001)
	assert_signal_emit_count(_rig.bus, "event_dispatched", 1)
	_rig.listener.advance(1.0)
	assert_signal_emit_count(_rig.bus, "event_dispatched", 1, "Listening is receive-only.")


func test_range_strength_classification_and_active_event_filters_use_acoustic_receiver() -> void:
	var edge: AcousticEmitter = _rig.emitter(&"edge", Vector2(1000, 0))
	var outside: AcousticEmitter = _rig.emitter(&"outside", Vector2(1000.1, 0))
	var weak: AcousticEmitter = _rig.emitter(&"weak")
	weak.profile.strength = 0.04
	var active: AcousticEmitter = _rig.emitter(&"active")
	active.profile.event_type = &"active_sonar"
	var filtered: AcousticEmitter = _rig.emitter(&"class")
	filtered.profile.classification = &"geological"
	var profile: PassiveSonarProfile = PassiveSonarProfile.new()
	profile.accepted_classifications = [&"mechanical"]
	profile.maximum_range_units = 1000.0
	assert_eq(_rig.listener.configure(profile), OK)
	for source: AcousticEmitter in [edge, outside, weak, active, filtered]:
		assert_eq(source.emit_event(StringName("event/" + String(source.source_id)), 0.0), OK)
	assert_eq(_rig.listener.contacts_snapshot().size(), 1)
	assert_eq(_rig.listener.contacts_snapshot()[0].source_id, &"edge")
	assert_eq(_rig.listener.contacts_snapshot()[0].signal_strength, 0.0, "Range edge is eligible, but approximate signal may be very weak.")
	profile.accepted_event_types = []
	assert_eq(_rig.listener.configure(profile), OK)
	assert_eq(active.emit_event(&"active-wildcard", 0.0), OK)
	assert_eq(_rig.listener.contacts_snapshot().size(), 1, "The passive component never treats active pings as ambient, even with a wildcard profile.")


func test_relative_bearings_cover_cardinals_rotation_wrap_and_coincident_source() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	var positions: Array[Vector2] = [Vector2(100, 0), Vector2(0, 100), Vector2(-100, 0), Vector2(0, -100), Vector2.ZERO]
	var expected: Array[float] = [0.0, 90.0, -180.0, -90.0, 0.0]
	for index: int in range(positions.size()):
		source.position = positions[index]
		assert_eq(source.emit_event(StringName("bearing/%d" % index), 0.0), OK)
		assert_eq(_rig.listener.contacts_snapshot()[0].bearing_degrees, expected[index])
	source.position = Vector2(100, 0)
	assert_eq(source.emit_event(&"rotated", 0.0), OK)
	_rig.listener.rotation = PI * 0.5
	assert_eq(_rig.listener.contacts_snapshot()[0].bearing_degrees, -90.0)
	_rig.listener.position = Vector2(100, 100)
	_rig.listener.rotation = 0.0
	assert_eq(_rig.listener.contacts_snapshot()[0].bearing_degrees, -90.0, "Bearing uses the last heard origin and current listener pose.")


func test_quantization_is_configurable_and_unknown_classification_is_preserved_in_api() -> void:
	var profile: PassiveSonarProfile = PassiveSonarProfile.new()
	profile.bearing_quantum_degrees = 30.0
	profile.strength_quantum = 0.25
	profile.distance_falloff = false
	profile.strength_reference = 2.0
	assert_eq(_rig.listener.configure(profile), OK)
	var source: AcousticEmitter = _rig.emitter(&"source", Vector2(100, 50))
	source.profile.classification = &"unclassified_signal"
	assert_eq(source.emit_event(&"quantized", 0.0), OK)
	assert_eq(_rig.listener.contacts_snapshot()[0].bearing_degrees, 30.0)
	assert_eq(_rig.listener.contacts_snapshot()[0].signal_strength, 0.5)
	assert_eq(_rig.listener.contacts_snapshot()[0].classification, &"unclassified_signal")


func test_duplicate_events_do_not_refresh_contacts_and_expiry_is_exact_simulation_time() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	assert_eq(source.emit_event(&"first", 0.0), OK)
	_rig.listener.advance(7.999)
	assert_eq(source.emit_event(&"first", 0.0), ERR_ALREADY_EXISTS)
	assert_eq(_rig.listener.contacts_snapshot()[0].expires_at, 8.0)
	_rig.listener.advance(0.001)
	assert_true(_rig.listener.contacts_snapshot().is_empty())
	assert_eq(source.emit_event(&"first", 0.0), ERR_ALREADY_EXISTS)
	assert_true(_rig.listener.contacts_snapshot().is_empty())
	# Even a direct stale receipt cannot revive an expired timestamp.
	var stale: AcousticEvent = AcousticEvent.create(&"stale", source.source_id, &"ambient", &"mechanical", Vector2.ZERO, 1.0, 1000.0, 0.0)
	_rig.listener.receiver.event_received.emit(stale, 1.0, 0.0)
	assert_true(_rig.listener.contacts_snapshot().is_empty())


func test_new_events_refresh_one_contact_per_source_and_old_samples_cannot_replace_newer() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	assert_eq(source.emit_event(&"first", 0.0), OK)
	_rig.listener.advance(2.0)
	assert_eq(source.emit_event(&"second", 2.0), OK)
	assert_eq(_rig.listener.contacts_snapshot().size(), 1)
	assert_eq(_rig.listener.contacts_snapshot()[0].expires_at, 10.0)
	assert_eq(source.emit_event(&"older-distinct-id", 1.0), OK)
	assert_eq(_rig.listener.contacts_snapshot()[0].event_id, &"second")


func test_bounded_contacts_keep_strongest_with_stable_id_ties_and_snapshot_isolation() -> void:
	for id: StringName in [&"z", &"a", &"c", &"b", &"d"]:
		var source: AcousticEmitter = _rig.emitter(id)
		assert_eq(source.emit_event(StringName("id/" + String(id)), 0.0), OK)
	var contacts: Array[Dictionary] = _rig.listener.contacts_snapshot()
	assert_eq(contacts.map(func(contact: Dictionary) -> StringName: return contact.source_id), [&"a", &"b", &"c"])
	contacts[0].classification = &"edited"
	assert_eq(_rig.listener.contacts_snapshot()[0].classification, &"mechanical")


func test_source_unbind_free_and_identity_replacement_remove_contacts_without_clearing_history() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	assert_eq(source.emit_event(&"first", 0.0), OK)
	assert_eq(_rig.bus.get_emitter(&"source"), source)
	assert_eq(source.bind_bus(null), OK)
	assert_true(_rig.listener.contacts_snapshot().is_empty())
	assert_eq(_rig.bus.history_count(), 1)
	assert_eq(source.bind_bus(_rig.bus), OK)
	assert_eq(source.emit_event(&"first", 0.0), ERR_ALREADY_EXISTS)
	assert_true(_rig.listener.contacts_snapshot().is_empty())
	assert_eq(source.emit_event(&"second", 1.0), OK)
	source.free()
	assert_true(_rig.listener.contacts_snapshot().is_empty())
	assert_null(_rig.bus.get_emitter(&"source"))
	assert_eq(_rig.bus.history_count(), 2)


func test_suspend_resume_freezes_expiry_and_ignores_incoming_ambient_events() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	source.emit_event(&"first", 0.0)
	_rig.listener.advance(2.0)
	_rig.listener.set_suspended(true)
	_rig.listener.advance(20.0)
	assert_eq(source.emit_event(&"during-pause", 2.0), OK)
	assert_eq(_rig.listener.contacts_snapshot()[0].event_id, &"first")
	assert_eq(_rig.listener.contacts_snapshot()[0].remaining_seconds, 6.0)
	assert_eq(_rig.listener.status_text(), "PAUSED")
	_rig.listener.set_suspended(false)
	_rig.listener.advance(6.0)
	assert_true(_rig.listener.contacts_snapshot().is_empty())


func test_invalid_profiles_and_time_preserve_valid_rules_and_contacts() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	source.emit_event(&"first", 0.0)
	for property: String in ["contact_seconds", "strength_reference", "strength_quantum", "bearing_quantum_degrees", "maximum_range_units", "minimum_strength"]:
		var profile: PassiveSonarProfile = PassiveSonarProfile.new()
		profile.set(property, NAN)
		assert_eq(_rig.listener.configure(profile), ERR_INVALID_PARAMETER)
	for delta: float in [-1.0, NAN, INF]:
		assert_eq(_rig.listener.advance(delta), ERR_INVALID_PARAMETER)
	assert_eq(_rig.listener.contacts_snapshot()[0].remaining_seconds, 8.0)


func test_bus_teardown_detaches_listener_and_clears_contacts() -> void:
	var source: AcousticEmitter = _rig.emitter(&"source")
	source.emit_event(&"first", 0.0)
	_rig.bus.free()
	_rig.listener.advance(0.0)
	assert_true(_rig.listener.contacts_snapshot().is_empty())
	assert_eq(_rig.listener.status_text(), "OFFLINE")
