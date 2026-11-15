extends GutTest
## Rules for the session-only life-support countdown and its visible presentation.

func _profile(seconds: float) -> VesselRecoveryProfile:
	var profile: VesselRecoveryProfile = VesselRecoveryProfile.new()
	profile.grace_seconds = seconds
	return profile


func test_authored_profile_is_sixty_seconds_and_invalid_grace_is_rejected() -> void:
	var authored: VesselRecoveryProfile = preload("res://resources/balance/vessel_recovery.tres")
	assert_true(authored.is_valid())
	assert_eq(authored.grace_seconds,60.0)
	for invalid: float in [0.0,-1.0,NAN,INF]:
		assert_false(_profile(invalid).is_valid(),"grace %s rejected" % invalid)
		assert_eq(LifeSupportCountdown.new().configure(_profile(invalid)),ERR_INVALID_PARAMETER)
	assert_eq(LifeSupportCountdown.new().configure(null),ERR_INVALID_PARAMETER)


func test_authored_drain_rates_are_the_approved_retune() -> void:
	assert_eq(preload("res://resources/balance/prototype_resources.tres").oxygen_drain_per_second,0.048,"Sunlit")
	assert_eq(preload("res://resources/balance/twilight_resources.tres").oxygen_drain_per_second,0.03,"Twilight")


func test_countdown_starts_full_on_first_zero_step_then_runs_on_supplied_time() -> void:
	var countdown: LifeSupportCountdown = LifeSupportCountdown.new()
	assert_eq(countdown.configure(_profile(60.0)),OK)
	watch_signals(countdown)
	assert_false(countdown.advance(1.0,5.0),"oxygen above zero never starts it")
	assert_false(countdown.running)
	assert_false(countdown.advance(1.0,0.0))
	assert_true(countdown.running)
	assert_eq(countdown.remaining,60.0,"the first zero step starts the full grace")
	assert_signal_emit_count(countdown,"started",1)
	assert_false(countdown.advance(0.0,0.0))
	assert_eq(countdown.remaining,60.0,"zero elapsed time does not run the countdown")
	for step: int in range(49): countdown.advance(1.0,0.0)
	assert_eq(countdown.remaining,11.0)
	assert_signal_not_emitted(countdown,"critical")
	countdown.advance(1.0,0.0)
	assert_signal_emit_count(countdown,"critical",1)
	for step: int in range(9): assert_false(countdown.advance(1.0,0.0))
	assert_true(countdown.advance(1.0,0.0),"expires on the 60th second")
	assert_signal_emit_count(countdown,"expired",1)
	assert_signal_emit_count(countdown,"critical",1)
	for step: int in range(5): assert_false(countdown.advance(1.0,0.0),"expiry fires once")
	assert_signal_emit_count(countdown,"expired",1)
	assert_signal_emit_count(countdown,"started",1)


func test_oxygen_above_zero_cancels_and_reset_restores_full_grace() -> void:
	var countdown: LifeSupportCountdown = LifeSupportCountdown.new()
	countdown.configure(_profile(60.0))
	watch_signals(countdown)
	countdown.advance(0.0,0.0)
	countdown.advance(42.0,0.0)
	assert_eq(countdown.remaining,18.0)
	countdown.advance(0.0,0.5)
	assert_false(countdown.running,"refill cancels")
	assert_signal_emit_count(countdown,"cancelled",1)
	assert_eq(countdown.remaining,60.0)
	countdown.advance(1.0,0.0)
	assert_eq(countdown.remaining,60.0,"a later depletion restarts the full grace")
	countdown.advance(30.0,0.0)
	countdown.reset_session()
	assert_false(countdown.running)
	assert_eq(countdown.remaining,60.0)
	assert_signal_not_emitted(countdown,"expired")


func test_invalid_steps_are_ignored() -> void:
	var countdown: LifeSupportCountdown = LifeSupportCountdown.new()
	countdown.configure(_profile(60.0))
	countdown.advance(0.0,0.0)
	for delta: float in [-1.0,NAN,INF]:
		assert_false(countdown.advance(delta,0.0))
	assert_false(countdown.advance(1.0,NAN))
	assert_eq(countdown.remaining,60.0)


func test_pulse_rate_ramps_from_half_hertz_to_one_and_a_half_and_never_exceeds_two() -> void:
	assert_eq(LifeSupportWarning.pulse_rate(60.0,60.0),0.5)
	assert_eq(LifeSupportWarning.pulse_rate(20.0,60.0),0.5,"no ramp before the last 20 s")
	assert_almost_eq(LifeSupportWarning.pulse_rate(10.0,60.0),1.0,0.0001)
	assert_almost_eq(LifeSupportWarning.pulse_rate(0.0,60.0),1.5,0.0001)
	var previous: float = 0.0
	for tenth: int in range(600,-1,-1):
		var rate: float = LifeSupportWarning.pulse_rate(tenth/10.0,60.0)
		assert_true(rate>=previous-0.000001,"rate never falls as time runs out")
		assert_lte(rate,2.0,"never above 2 pulses per second")
		assert_gte(rate,0.5)
		previous = rate
	for grace: float in [1.0,5.0,20.0,600.0]:
		for remaining: float in [grace,grace*0.5,0.0,-3.0]:
			assert_lte(LifeSupportWarning.pulse_rate(remaining,grace),LifeSupportWarning.MAX_HZ)


func test_countdown_text_reads_minutes_and_seconds_and_marks_critical_in_words() -> void:
	assert_eq(LifeSupportWarning.countdown_text(60.0),"OXYGEN DEPLETED, LIFE SUPPORT 1:00")
	assert_eq(LifeSupportWarning.countdown_text(41.2),"OXYGEN DEPLETED, LIFE SUPPORT 0:42")
	assert_eq(LifeSupportWarning.countdown_text(10.0),"OXYGEN DEPLETED, LIFE SUPPORT CRITICAL 0:10")
	assert_eq(LifeSupportWarning.countdown_text(0.0),"OXYGEN DEPLETED, LIFE SUPPORT CRITICAL 0:00")


func test_new_player_facing_text_has_no_em_dashes_or_semicolons() -> void:
	var texts: Array[String] = [VesselRecoveryFlow.OXYGEN_TEXT,VesselRecoveryFlow.SHARED_TEXT,VesselRecoveryFlow.CONFIRM_TEXT,
		VesselRecoveryFlow.RETRY_TEXT,SaveCoordinator.OXYGEN_SAVE_REFUSAL,ScientificScanner.OXYGEN_REFUSAL,ChapterJourney.FINISH_OXYGEN_REFUSAL,
		LifeSupportWarning.countdown_text(42.0),LifeSupportWarning.countdown_text(3.0)]
	for text: String in texts:
		assert_false(text.contains(";"),"no semicolon: "+text)
		assert_false(text.contains("—"),"no em dash: "+text)
		assert_false(text.contains("–"),"no en dash: "+text)
	assert_eq(VesselRecoveryFlow.OXYGEN_TEXT,"LIFE SUPPORT FAILED. Oxygen ran out. Wick sent a distress beacon and Halcyon’s crew recovered Lantern-2. Hull, battery, oxygen and torpedoes are restored. The unfinished scan was cancelled. All records, discoveries and choices are kept.")
	assert_eq(VesselRecoveryFlow.CONFIRM_TEXT,"Continue at Halcyon")
