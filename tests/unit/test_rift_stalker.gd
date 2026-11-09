extends GutTest
const PROFILE: RiftStalkerProfile = preload("res://resources/creatures/twilight_stalker.tres")
func model() -> RiftStalkerState:
	var state: RiftStalkerState = RiftStalkerState.new()
	assert_eq(state.configure(PROFILE),OK)
	return state
func event(type: StringName = &"active_sonar",id: StringName = &"test/ping") -> AcousticEvent:
	return AcousticEvent.create(id,&"neris-01/sonar" if type==&"active_sonar" else &"neris-01/torpedo",type,&"scientific" if type==&"active_sonar" else &"mechanical",PROFILE.patrol_points[0],1.0,PROFILE.hearing.maximum_range_units,0)
func test_filters_threshold_range_passive_and_receipt_clock_do_not_mutate_events() -> void:
	assert_true(PROFILE.is_valid())
	var state: RiftStalkerState = model()
	var ping: AcousticEvent = event()
	var point: Vector2 = PROFILE.patrol_points[0]
	assert_eq(state.offer(ping,0.19,10,point),ERR_UNAVAILABLE)
	assert_eq(state.offer(ping,1,PROFILE.hearing.maximum_range_units+1,point),ERR_UNAVAILABLE)
	assert_eq(state.offer(event(&"ambient"),1,10,point),ERR_UNAVAILABLE)
	state.advance(300,point)
	assert_eq(state.offer(ping,0.2,PROFILE.hearing.maximum_range_units,point),OK)
	assert_eq(ping.simulation_time,0.0)
	state.advance(0.01,point)
	assert_eq(state.phase,RiftStalkerState.Phase.INVESTIGATE)
func test_quiet_sensing_never_attacks_then_sound_warning_pursuit_escape_and_return() -> void:
	var state: RiftStalkerState = model()
	var point: Vector2 = PROFILE.patrol_points[0]
	state.sense(point,true,true)
	state.advance(30,point)
	assert_eq(state.phase,RiftStalkerState.Phase.QUIET)
	assert_eq(state.contact_cost(0,true),0.0)
	assert_eq(state.offer(event(),1,0,point),OK)
	state.advance(0.01,point)
	assert_eq(state.phase,RiftStalkerState.Phase.WARNING)
	assert_eq(state.contact_cost(0,true),0.0)
	state.advance(PROFILE.warning_seconds,point)
	assert_eq(state.phase,RiftStalkerState.Phase.PURSUE)
	assert_eq(state.contact_cost(0,true),PROFILE.contact_damage)
	assert_eq(state.contact_cost(0,true),0.0)
	state.sense(PROFILE.navigation_bounds.position-Vector2.ONE,true,true)
	state.advance(0.01,point)
	assert_eq(state.phase,RiftStalkerState.Phase.RETURN)
	assert_eq(state.contact_cost(0,true),0.0)
func test_scare_stuns_flees_and_recovers_without_damage_or_repeated_extension() -> void:
	var state: RiftStalkerState = model()
	var point: Vector2 = PROFILE.patrol_points[0]
	assert_eq(state.scare(point,point),OK)
	assert_eq(state.phase,RiftStalkerState.Phase.STUN)
	assert_eq(state.speed(),0.0)
	assert_eq(state.scare(point,point),ERR_BUSY)
	state.advance(PROFILE.stun_seconds,point)
	assert_eq(state.phase,RiftStalkerState.Phase.FLEE)
	assert_eq(state.contact_cost(0,true),0.0)
	state.advance(PROFILE.flee_seconds,point)
	assert_eq(state.phase,RiftStalkerState.Phase.RETURN)
	state.advance(PROFILE.recovery_seconds+0.1,state.destination())
	assert_eq(state.phase,RiftStalkerState.Phase.QUIET)
func test_blast_ambiguity_nearest_eligible_flees_other_hearer_investigates() -> void:
	var states: Array[RiftStalkerState] = [model(),model()]
	var point: Vector2 = PROFILE.patrol_points[0]
	var positions: PackedVector2Array = PackedVector2Array([point,point+Vector2(PROFILE.scare_radius*2,0)])
	var radii: PackedFloat32Array = PackedFloat32Array([PROFILE.scare_radius,PROFILE.scare_radius])
	for index: int in range(states.size()): assert_eq(states[index].offer(event(&"explosion"),1,positions[index].distance_to(point),point),OK)
	var nearest: int = TwilightHunt.nearest(positions,radii,point)
	assert_eq(nearest,0)
	assert_eq(states[nearest].scare(point,positions[nearest]),OK)
	for index: int in range(states.size()): states[index].advance(0.01,positions[index])
	assert_eq(states[0].phase,RiftStalkerState.Phase.STUN)
	assert_eq(states[1].phase,RiftStalkerState.Phase.INVESTIGATE)
