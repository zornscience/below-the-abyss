extends GutTest
func _model() -> SwarmerState:
	var result: SwarmerState = SwarmerState.new()
	assert_eq(result.configure(CombatBox.SWARM),OK)
	return result
func _sound(kind: StringName,at: Vector2) -> AcousticEvent:
	return AcousticEvent.create(&"combat/test-1",&"neris-01/sonar" if kind==&"active_sonar" else &"neris-01/torpedo",kind,&"scientific",at,1.0,1800.0,0)
func test_quiet_proximity_never_attacks_and_sound_is_filtered_by_resource_hearing() -> void:
	var model: SwarmerState = _model()
	var at: Vector2 = CombatBox.DATA.swarm_spawns[0]
	model.sense(at,true)
	for step: int in range(20): assert_eq(model.advance(0.5,at),OK)
	assert_eq(model.phase,SwarmerState.Phase.QUIET)
	assert_eq(model.bite(0,true),0.0)
	assert_eq(model.offer(_sound(&"active_sonar",at),1,CombatBox.SWARM.hearing.maximum_range_units+1,at),ERR_UNAVAILABLE)
	assert_eq(model.phase,SwarmerState.Phase.QUIET)
	assert_eq(model.offer(_sound(&"explosion",at),1,100,at),OK)
	assert_eq(model.phase,SwarmerState.Phase.INVESTIGATE)
func test_telegraph_precedes_one_small_bite_and_stun_cancels_the_dash() -> void:
	var model: SwarmerState = _model()
	var at: Vector2 = CombatBox.DATA.swarm_spawns[0]
	model.sense(at,true)
	assert_eq(model.offer(_sound(&"active_sonar",at),1,0,at),OK)
	assert_eq(model.advance(0,at),OK)
	assert_eq(model.phase,SwarmerState.Phase.TELEGRAPH)
	assert_eq(model.speed(),0.0)
	assert_eq(model.bite(0,true),0.0)
	assert_eq(model.advance(model.profile.telegraph_seconds,at),OK)
	assert_eq(model.phase,SwarmerState.Phase.DASH)
	assert_eq(model.bite(0,true),model.profile.bite_damage)
	assert_eq(model.bite(0,true),0.0)
	assert_true(model.stun(2.0))
	assert_eq(model.bite(0,true),0.0)
	assert_eq(model.advance(1.0,at),OK)
	assert_eq(model.phase,SwarmerState.Phase.STUN)
	assert_eq(model.advance(1.0,at),OK)
	assert_eq(model.phase,SwarmerState.Phase.INVESTIGATE)
func test_arena_profiles_do_not_mutate_the_campaign_and_gate_is_playtest_export_only() -> void:
	assert_true(CombatBox.DATA.is_valid())
	assert_same(CombatHandling.WEIGHTY,load("res://resources/balance/expedition_motion.tres"))
	assert_gt(CombatHandling.RESPONSIVE.acceleration,CombatHandling.WEIGHTY.acceleration)
	assert_lt(CombatHandling.RESPONSIVE.damping,CombatHandling.WEIGHTY.damping)
	var old: RiftStalkerProfile = CombatBox.DATA.stalker_base
	var custom: RiftStalkerProfile = CombatBox.DATA.stalker_profile()
	assert_ne(custom.navigation_bounds,old.navigation_bounds)
	assert_eq(custom.contact_damage,old.contact_damage)
	assert_eq(custom.hearing.maximum_range_units,old.hearing.maximum_range_units)
	assert_eq(custom.stun_seconds,old.stun_seconds)
	var panel: PlaytestPanel = PlaytestPanel.new()
	add_child_autofree(panel)
	assert_null(panel.combat_button)
func test_resource_handling_calculations_match_pure_fixed_step_runs() -> void:
	for id: String in ["weighty","responsive"]:
		var motion: SubmarineMotion = CombatHandling.profile(id)
		var expected: Dictionary = CombatHandling.predicted(motion)
		var velocity: Vector2 = Vector2.ZERO
		var elapsed: float = 0
		var delta: float = 1.0/120
		while velocity.x<motion.maximum_speed*0.9:
			velocity = motion.next_velocity(velocity,Vector2.RIGHT,delta)
			elapsed += delta
		assert_almost_eq(elapsed,expected.to_90_seconds,delta+0.00001)
		velocity = Vector2.RIGHT*motion.maximum_speed
		elapsed = 0
		var distance: float = 0
		while velocity.length()>0:
			velocity = motion.next_velocity(velocity,Vector2.ZERO,delta)
			distance += velocity.x*delta
			elapsed += delta
		assert_almost_eq(elapsed,expected.stop_seconds,delta+0.00001)
		assert_almost_eq(distance,expected.stop_distance,motion.maximum_speed*delta)
		velocity = Vector2.RIGHT*motion.maximum_speed
		elapsed = 0
		while velocity.x>-motion.maximum_speed*0.9:
			velocity = motion.next_velocity(velocity,Vector2.LEFT,delta)
			elapsed += delta
		assert_almost_eq(elapsed,expected.turn_90_seconds,delta+0.00001)
		print("COMBAT_HANDLING_MODEL ",id," ",JSON.stringify(expected)," fixed120_stop=",distance)
func test_combat_recording_is_opt_in_bounded_and_old_report_shape_is_unchanged() -> void:
	var recorder: PlaytestRecorder = PlaytestRecorder.new()
	assert_eq(recorder.record("combat_torpedo","fired"),ERR_UNAVAILABLE)
	assert_true(recorder.snapshot().is_empty())
	assert_eq(recorder.begin(),OK)
	assert_eq(recorder.snapshot().schema_version,1)
	assert_false(recorder.snapshot().has("combat"))
	assert_eq(recorder.record("combat_torpedo","fired"),ERR_INVALID_PARAMETER)
	assert_true(PlaytestReport.valid(recorder.snapshot()))
	assert_eq(recorder.finish(),OK)
	assert_eq(recorder.begin("source",true),OK)
	assert_eq(recorder.advance(10,true),OK)
	assert_eq(recorder.record("combat_engage","swarm"),OK)
	assert_eq(recorder.record("combat_handling","responsive"),OK)
	assert_eq(recorder.advance(5,true),OK)
	for index: int in range(PlaytestReport.MAX_EVENTS+10): assert_eq(recorder.record("combat_collision","contact"),OK)
	assert_eq(recorder.record("sonar","active_ping"),OK)
	assert_eq(recorder.record("combat_death","collision"),OK)
	assert_eq(recorder.record("combat_rating","about_right"),OK)
	assert_eq(recorder.finish(),OK)
	var data: Dictionary = recorder.snapshot()
	assert_true(PlaytestReport.valid(data))
	assert_true(PlaytestReport.valid(JSON.parse_string(JSON.stringify(data))))
	assert_eq(data.combat.first_engage_active_seconds,10.0)
	assert_eq(data.combat.deaths_by_collision,1)
	assert_eq(data.combat.collisions,PlaytestReport.MAX_EVENTS+10)
	assert_eq(data.combat.rating,"about_right")
	assert_eq(data.combat.profile_active_seconds,{"weighty":10.0,"responsive":5.0})
	assert_eq(data.combat.pings,1)
	data.combat.player_name = "not permitted"
	assert_false(PlaytestReport.valid(data))
