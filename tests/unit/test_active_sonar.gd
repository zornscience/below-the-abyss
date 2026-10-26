extends GutTest

var _rig: SonarTestRig


func before_each() -> void:
	_rig = SonarTestRig.new()
	add_child_autofree(_rig)


func test_ping_charges_exactly_once_and_starts_cooldown_only_on_acceptance() -> void:
	watch_signals(_rig.sonar)
	watch_signals(_rig.bus)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(_rig.resources.battery, 96.0)
	assert_eq(_rig.sonar.cooldown_remaining(), 4.0)
	assert_eq(_rig.sonar.active_pulse_count(), 1)
	assert_eq(_rig.sonar.request_ping(), ERR_BUSY)
	assert_eq(_rig.resources.battery, 96.0)
	assert_eq(_rig.bus.history_count(), 1)
	assert_signal_emit_count(_rig.sonar, "pulse_emitted", 1)
	assert_signal_emit_count(_rig.bus, "event_dispatched", 1)


func test_insufficient_and_failed_final_cost_do_not_emit_or_start_cooldown() -> void:
	watch_signals(_rig.bus)
	_rig.resources.consume_battery(97.0)
	assert_eq(_rig.sonar.request_ping(), ERR_UNAVAILABLE)
	assert_eq(_rig.resources.battery, 3.0)
	assert_eq(_rig.sonar.cooldown_remaining(), 0.0)
	assert_eq(_rig.sonar.active_pulse_count(), 0)
	assert_eq(_rig.bus.history_count(), 0)
	var rejecting: RejectingSonarBattery = RejectingSonarBattery.new()
	add_child_autofree(rejecting)
	assert_eq(_rig.sonar.setup(_rig.bus, rejecting, _rig.effects), OK)
	assert_eq(_rig.sonar.request_ping(), ERR_UNAVAILABLE)
	assert_eq(rejecting.battery, 100.0)
	assert_eq(_rig.sonar.cooldown_remaining(), 0.0)
	assert_eq(_rig.sonar.active_pulse_count(), 0)
	assert_eq(_rig.bus.history_count(), 0)
	assert_signal_not_emitted(_rig.bus, "event_dispatched")


func test_exact_energy_and_exact_cooldown_boundary_are_accepted() -> void:
	_rig.resources.consume_battery(96.0)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(_rig.resources.battery, 0.0)
	_rig.resources.restore_battery(4.0)
	_rig.sonar.advance(3.9999)
	assert_eq(_rig.sonar.request_ping(), ERR_BUSY)
	_rig.sonar.advance(0.0001)
	assert_eq(_rig.sonar.cooldown_remaining(), 0.0)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(_rig.resources.battery, 0.0)


func test_invalid_duplicate_conflicting_and_full_ledger_requests_never_charge() -> void:
	assert_eq(_rig.sonar.request_ping(&"invalid id"), ERR_INVALID_PARAMETER)
	assert_eq(_rig.resources.battery, 100.0)
	assert_eq(_rig.sonar.request_ping(&"held-id"), OK)
	var original: AcousticEvent = AcousticEvent.create(&"held-id", _rig.sonar.source_id,
		&"active_sonar", &"scientific", Vector2.ZERO, 1.0, 100.0, 0.0)
	assert_eq(_rig.sonar.acoustic_emitter.publish(original,
		_rig.resources.try_consume_battery.bind(4.0)), ERR_ALREADY_EXISTS)
	assert_eq(_rig.resources.battery, 96.0)
	_rig.sonar.advance(4.0)
	assert_eq(_rig.sonar.request_ping(&"held-id"), ERR_INVALID_DATA)
	assert_eq(_rig.resources.battery, 96.0)
	var profile: AcousticDispatchProfile = AcousticDispatchProfile.new()
	profile.maximum_event_history = 1
	assert_eq(_rig.bus.configure(profile), OK)
	assert_eq(_rig.sonar.request_ping(&"new-id"), ERR_OUT_OF_MEMORY)
	assert_eq(_rig.resources.battery, 96.0)
	assert_eq(_rig.sonar.cooldown_remaining(), 0.0)
	assert_eq(_rig.sonar.active_pulse_count(), 0)


func test_wavefront_and_exact_range_wait_for_arrival_and_outside_stays_hidden() -> void:
	var near: SonarRevealTarget = _rig.target(&"near", Vector2(50, 0))
	var edge: SonarRevealTarget = _rig.target(&"edge", Vector2(100, 0))
	var outside: SonarRevealTarget = _rig.target(&"outside", Vector2(100.01, 0))
	watch_signals(near)
	watch_signals(edge)
	watch_signals(outside)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_false(near.is_revealed())
	assert_false(edge.is_revealed())
	_rig.sonar.advance(0.4999)
	assert_false(near.is_revealed())
	_rig.sonar.advance(0.0001)
	assert_true(near.is_revealed())
	assert_false(edge.is_revealed())
	_rig.sonar.advance(0.4999)
	assert_false(edge.is_revealed())
	_rig.sonar.advance(0.0001)
	assert_true(edge.is_revealed())
	assert_false(outside.is_revealed())
	_rig.sonar.advance(0.3)
	assert_signal_emit_count(near, "revealed_for_ping", 1)
	assert_signal_emit_count(edge, "revealed_for_ping", 1)
	assert_signal_not_emitted(outside, "revealed_for_ping")


func test_duplicate_receipts_and_repeat_reveals_are_suppressed_per_ping() -> void:
	var target: SonarRevealTarget = _rig.target(&"target", Vector2(50, 0))
	watch_signals(target)
	var events: Array[AcousticEvent] = []
	_rig.sonar.pulse_emitted.connect(func(event: AcousticEvent) -> void: events.append(event))
	assert_eq(_rig.sonar.request_ping(), OK)
	target.echo_received.emit(target, events[0], 50.0)
	target.echo_received.emit(target, events[0], 50.0)
	_rig.sonar.advance(1.0)
	assert_signal_emit_count(target, "revealed_for_ping", 1)
	assert_eq(target.reveal_for_ping(events[0].event_id, 2.0), ERR_ALREADY_EXISTS)
	assert_eq(_rig.sonar.echo_count(), 1)


func test_removed_unbound_rebound_and_freed_targets_cancel_pending_reveals() -> void:
	var freed: SonarRevealTarget = _rig.target(&"freed", Vector2(50, 0))
	var rebound: SonarRevealTarget = _rig.target(&"rebound", Vector2(50, 0))
	var exited: SonarRevealTarget = _rig.target(&"exited", Vector2(50, 0))
	watch_signals(rebound)
	watch_signals(exited)
	assert_eq(_rig.sonar.request_ping(), OK)
	freed.free()
	rebound.bind_bus(null)
	rebound.bind_bus(_rig.bus)
	_rig.remove_child(exited)
	_rig.add_child(exited)
	exited.bind_bus(_rig.bus)
	_rig.sonar.advance(1.0)
	assert_false(rebound.is_revealed())
	assert_false(exited.is_revealed())
	assert_signal_not_emitted(rebound, "revealed_for_ping")
	assert_signal_not_emitted(exited, "revealed_for_ping")
	assert_eq(_rig.sonar.echo_count(), 0)


func test_target_added_after_emission_receives_no_old_ping_or_late_reveal() -> void:
	assert_eq(_rig.sonar.request_ping(), OK)
	var late: SonarRevealTarget = _rig.target(&"late", Vector2(50, 0))
	_rig.sonar.advance(1.0)
	assert_false(late.is_revealed())
	assert_eq(_rig.bus.history_count(), 1)


func test_restart_cancels_pulses_and_reveals_without_clearing_acoustic_history() -> void:
	var target: SonarRevealTarget = _rig.target(&"target", Vector2(50, 0))
	var ids: Array[StringName] = []
	_rig.sonar.pulse_emitted.connect(func(event: AcousticEvent) -> void: ids.append(event.event_id))
	_rig.sonar.request_ping()
	_rig.sonar.advance(0.5)
	assert_true(target.is_revealed())
	assert_eq(_rig.sonar.reset_session(), OK)
	assert_false(target.is_revealed())
	assert_eq(_rig.sonar.active_pulse_count(), 0)
	assert_eq(_rig.sonar.cooldown_remaining(), 0.0)
	assert_eq(_rig.bus.history_count(), 1)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_ne(ids[0], ids[1])
	assert_eq(_rig.bus.history_count(), 2)
	assert_false(target.is_revealed())
	_rig.sonar.advance(0.5)
	assert_true(target.is_revealed())


func test_large_steps_and_30_60_120_steps_preserve_arrival_expiry_cooldown_and_cost() -> void:
	for rate: int in [1, 30, 60, 120]:
		_rig.sonar.reset_session()
		_rig.resources.restore_battery(100.0)
		var target: SonarRevealTarget = _rig.target(StringName("target-%d" % rate), Vector2(50, 0))
		watch_signals(target)
		assert_eq(_rig.sonar.request_ping(), OK)
		for _step: int in range(rate):
			_rig.sonar.advance(1.0 / rate)
		assert_true(target.is_revealed())
		assert_signal_emit_count(target, "revealed_for_ping", 1)
		assert_almost_eq(_rig.sonar.cooldown_remaining(), 3.0, 0.000001)
		for _step: int in range(rate * 2):
			_rig.sonar.advance(1.0 / rate)
		assert_false(target.is_revealed(), "Expiration is arrival+duration, not end-of-step+duration.")
		assert_eq(_rig.resources.battery, 96.0)
	_rig.sonar.reset_session()
	var skipped: SonarRevealTarget = _rig.target(&"skipped-window", Vector2(50, 0))
	watch_signals(skipped)
	assert_eq(_rig.sonar.request_ping(), OK)
	_rig.sonar.advance(10.0)
	assert_false(skipped.is_revealed())
	assert_signal_emit_count(skipped, "revealed_for_ping", 1)


func test_invalid_config_preserves_rules_and_invalid_delta_preserves_clock() -> void:
	for property: String in ["battery_cost", "cooldown_seconds", "travel_speed", "maximum_radius", "signal_strength", "reveal_seconds", "fade_seconds"]:
		var profile: ActiveSonarProfile = ActiveSonarProfile.new()
		profile.set(property, NAN)
		assert_eq(_rig.sonar.configure(profile), ERR_INVALID_PARAMETER)
	var zero: ActiveSonarProfile = ActiveSonarProfile.new()
	zero.travel_speed = 0.0
	assert_eq(_rig.sonar.configure(zero), ERR_INVALID_PARAMETER)
	assert_eq(_rig.sonar.request_ping(), OK)
	for delta: float in [-1.0, NAN, INF]:
		assert_eq(_rig.sonar.advance(delta), ERR_INVALID_PARAMETER)
	assert_eq(_rig.sonar.cooldown_remaining(), 4.0)
	assert_eq(_rig.resources.battery, 96.0)


func test_battery_signal_reentrancy_cannot_double_charge_or_emit() -> void:
	var results: Array[Error] = []
	_rig.resources.battery_changed.connect(func(_current: float, _maximum: float) -> void:
		results.append(_rig.sonar.request_ping()))
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(results, [ERR_BUSY])
	assert_eq(_rig.resources.battery, 96.0)
	assert_eq(_rig.bus.history_count(), 1)


func test_eligible_filters_are_owned_by_the_bus_and_direct_acoustics_do_not_spawn_waves() -> void:
	var filtered: SonarRevealTarget = _rig.target(&"filtered", Vector2(50, 0))
	filtered.receiver.profile.excluded_source_ids = [_rig.sonar.source_id]
	assert_eq(_rig.sonar.request_ping(), OK)
	_rig.sonar.advance(1.0)
	assert_false(filtered.is_revealed())

	_rig.sonar.reset_session()
	var other: AcousticEvent = AcousticEvent.create(&"unrelated", _rig.sonar.source_id,
		&"active_sonar", &"scientific", Vector2.ZERO, 1.0, 100.0, 0.0)
	assert_eq(_rig.bus.dispatch(_rig.sonar.acoustic_emitter, other), OK)
	assert_eq(_rig.sonar.active_pulse_count(), 0)
	assert_false(filtered.is_revealed())


func test_zero_cost_empty_battery_and_configurable_pulse_limit() -> void:
	var profile: ActiveSonarProfile = _rig.sonar.configuration.duplicate() as ActiveSonarProfile
	profile.battery_cost = 0.0
	profile.cooldown_seconds = 0.0
	profile.maximum_active_pulses = 1
	assert_eq(_rig.sonar.configure(profile), OK)
	_rig.resources.consume_battery(100.0)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(_rig.resources.battery, 0.0)
	assert_eq(_rig.sonar.request_ping(), ERR_BUSY)
	_rig.sonar.advance(1.2)
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(_rig.bus.history_count(), 2)


func test_pulse_radius_is_bounded_and_shared_profile_edits_do_not_change_active_rules() -> void:
	_rig.sonar.configuration.battery_cost = 99.0
	assert_eq(_rig.sonar.request_ping(), OK)
	assert_eq(_rig.resources.battery, 96.0)
	var pulse: SonarPulse = _rig.effects.get_child(0) as SonarPulse
	assert_eq(pulse.get_radius(), 0.0)
	_rig.sonar.advance(0.5)
	assert_eq(pulse.get_radius(), 50.0)
	_rig.sonar.advance(10.0)
	assert_eq(pulse.get_radius(), 100.0)


func test_bus_teardown_cancels_pending_arrivals_and_reports_offline() -> void:
	var target: SonarRevealTarget = _rig.target(&"target", Vector2(50, 0))
	watch_signals(target)
	assert_eq(_rig.sonar.request_ping(), OK)
	_rig.bus.free()
	_rig.sonar.advance(1.0)
	assert_false(target.is_revealed())
	assert_signal_not_emitted(target, "revealed_for_ping")
	assert_eq(_rig.sonar.active_pulse_count(), 0)
	assert_eq(_rig.sonar.status_text(), "COOLING 3.0 s")
	_rig.sonar.advance(3.0)
	assert_eq(_rig.sonar.status_text(), "OFFLINE")


func test_overlapping_pings_refresh_visibility_from_arrival_times_without_duplicate_reveals() -> void:
	var profile: ActiveSonarProfile = _rig.sonar.configuration.duplicate() as ActiveSonarProfile
	profile.cooldown_seconds = 0.1
	assert_eq(_rig.sonar.configure(profile), OK)
	var target: SonarRevealTarget = _rig.target(&"target", Vector2(50, 0))
	watch_signals(target)
	assert_eq(_rig.sonar.request_ping(), OK)
	_rig.sonar.advance(0.4)
	assert_eq(_rig.sonar.request_ping(), OK)
	_rig.sonar.advance(0.6)
	assert_true(target.is_revealed())
	assert_signal_emit_count(target, "revealed_for_ping", 2)
	_rig.sonar.advance(1.89)
	assert_true(target.is_revealed())
	_rig.sonar.advance(0.01)
	assert_false(target.is_revealed())
	assert_eq(_rig.resources.battery, 92.0)


func test_removing_the_sonar_owner_clears_its_temporary_reveals_and_visuals() -> void:
	var target: SonarRevealTarget = _rig.target(&"target", Vector2(50, 0))
	assert_eq(_rig.sonar.request_ping(), OK)
	_rig.sonar.advance(0.5)
	assert_true(target.is_revealed())
	_rig.sonar.free()
	assert_false(target.is_revealed())
	assert_eq(_rig.bus.emitter_count(), 0)
	await get_tree().process_frame
	assert_eq(_rig.effects.get_child_count(), 0)
