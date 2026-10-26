extends GutTest


func test_acceptance_gate_runs_only_for_valid_new_events_and_preserves_history_semantics() -> void:
	var rig: SonarTestRig = SonarTestRig.new()
	add_child_autofree(rig)
	var calls: Array[int] = []
	var event: AcousticEvent = AcousticEvent.create(&"gate-test", rig.sonar.source_id,
		&"test", &"test", Vector2.ZERO, 1.0, 100.0, 0.0)
	var reject: Callable = func() -> bool: calls.append(0); return false
	var accept: Callable = func() -> bool: calls.append(1); return true
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, null, accept), ERR_INVALID_PARAMETER)
	assert_true(calls.is_empty())
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, event, reject), ERR_UNAVAILABLE)
	assert_eq(rig.bus.history_count(), 0)
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, event, accept), OK)
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, event, accept), ERR_ALREADY_EXISTS)
	event._strength = 2.0
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, event, accept), ERR_INVALID_DATA)
	assert_eq(calls, [0, 1])
	assert_eq(rig.bus.history_count(), 1)


func test_acceptance_gate_is_locked_and_cannot_mutate_the_frozen_payload() -> void:
	var rig: SonarTestRig = SonarTestRig.new()
	add_child_autofree(rig)
	var event: AcousticEvent = AcousticEvent.create(&"gate-test", rig.sonar.source_id,
		&"test", &"test", Vector2.ZERO, 1.0, 100.0, 0.0)
	var original: AcousticEvent = event.snapshot()
	var nested: Array[Error] = []
	var accept: Callable = func() -> bool:
		event._strength = 999.0
		nested.append(rig.bus.dispatch(rig.sonar.acoustic_emitter, original))
		return true
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, event, accept), OK)
	assert_eq(nested, [ERR_BUSY])
	assert_eq(rig.bus.dispatch(rig.sonar.acoustic_emitter, original), ERR_ALREADY_EXISTS)
