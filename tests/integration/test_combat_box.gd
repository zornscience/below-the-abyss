extends GutTest
var box: CombatBox
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	box = preload("res://scenes/playtesting/combat_box.tscn").instantiate() as CombatBox
	view.add_child(box)
	await wait_physics_frames(3)
func test_box_is_independent_and_quiet_then_ping_stuns_only_near_swarmers() -> void:
	assert_null(box.get_node_or_null("SaveCoordinator"))
	assert_null(box.get_node_or_null("ResearchRegistry"))
	assert_eq(box.swarmers.size(),CombatBox.DATA.swarm_spawns.size())
	assert_false(box.observer.recorder.recording)
	assert_true(box.settings.snapshot().accessibility.reduced_flashing)
	assert_true(box.observer.recorder.snapshot().is_empty())
	box.resume()
	await wait_physics_frames(4)
	for actor: CombatSwarmer in box.swarmers: assert_eq(actor.model.phase,SwarmerState.Phase.QUIET)
	box.submarine.global_position = CombatBox.DATA.stun_probe
	var before: float = box.submarine.resource_system.battery
	assert_eq(box.submarine.sonar.request_ping(),OK)
	assert_eq(box.submarine.resource_system.battery,before-CombatBox.COSTS.ping_battery)
	assert_true((box.submarine.sonar._pulses[box.submarine.sonar._last_ping].get_ref() as SonarPulse).reduced_flashing)
	assert_eq(box.swarmers[0].model.phase,SwarmerState.Phase.STUN)
	assert_ne(box.stalker.hunt.phase,RiftStalkerState.Phase.STUN)
	assert_ne(box.swarmers[-1].model.phase,SwarmerState.Phase.STUN)
	assert_eq(box.stun.targets.size(),box.swarmers.size())
	for actor: CombatSwarmer in box.swarmers: assert_same(actor.receiver.get_bus(),box.bus)
	assert_same(box.stalker.receiver.get_bus(),box.bus)
	box.open_options()
	var clock: float = box.swarmers[0].model.clock
	await wait_physics_frames(4)
	assert_eq(box.swarmers[0].model.clock,clock)
func test_live_bite_uses_hull_api_and_one_torpedo_kills_without_rewards() -> void:
	box.resume()
	var actor: CombatSwarmer = box.swarmers[0]
	box.submarine.global_position = actor.global_position
	actor.model.phase = SwarmerState.Phase.DASH
	actor.model.bitten = false
	var hull: float = box.submarine.hull_system.hull
	actor._after_step(0)
	assert_eq(box.submarine.hull_system.hull,hull-CombatBox.SWARM.bite_damage)
	actor._after_step(0)
	assert_eq(box.submarine.hull_system.hull,hull-CombatBox.SWARM.bite_damage)
	assert_eq(box.health[0].apply_blast(&"combat/one-shot",actor.global_position,box.torpedoes._rules.radius,box.torpedoes._rules.damage),CombatBox.SWARM.maximum_health)
	assert_true(actor._destroyed)
	assert_false(actor.receiver.enabled)
	assert_false(box.observer.recorder.recording)
	assert_true(box.observer.recorder.snapshot().is_empty())
	box.stalker.set_destroyed(true)
	assert_false(box.stalker._destroyed)
	for child: Node in box.stalker.get_children(): assert_false(child is BlastReceiver)
func test_handling_selection_is_exact_and_hull_zero_returns_to_safe_refit() -> void:
	assert_eq(box.select_handling("responsive"),OK)
	assert_same(box.submarine.motion,CombatHandling.RESPONSIVE)
	assert_eq(box.select_handling("weighty"),OK)
	assert_same(box.submarine.motion,CombatHandling.WEIGHTY)
	box.submarine.global_position = CombatBox.DATA.chase_probe
	assert_eq(box.refit(),ERR_UNAVAILABLE)
	box.resume()
	box.submarine.hull_system.apply_damage(100,&"collision")
	await wait_physics_frames(4)
	assert_eq(box.submarine.global_position,CombatBox.DATA.refit)
	assert_eq(box.submarine.hull_system.hull,100.0)
	assert_true(box.options.visible)
	assert_eq(box.torpedoes.ammunition,10)
	assert_eq(box.stalker.collision_layer,8)
	assert_false(CombatBox.DATA.stalker_bounds.has_point(CombatBox.DATA.refit))
func test_stun_range_boundary_and_cooldown_are_the_normal_ping_rules() -> void:
	box.resume()
	var actor: CombatSwarmer = box.swarmers[0]
	var event: AcousticEvent = AcousticEvent.create(&"combat/range",&"neris-01/sonar",&"active_sonar",&"scientific",actor.global_position-Vector2.RIGHT*box.stun.profile.range_units,1,900,0)
	box.stun._ping(event)
	assert_eq(actor.model.phase,SwarmerState.Phase.STUN)
	actor.model.reset_session()
	event = AcousticEvent.create(&"combat/outside",&"neris-01/sonar",&"active_sonar",&"scientific",actor.global_position-Vector2.RIGHT*(box.stun.profile.range_units+1),1,900,0)
	box.stun._ping(event)
	assert_eq(actor.model.phase,SwarmerState.Phase.QUIET)
	assert_eq(box.submarine.sonar.request_ping(),OK)
	var before: float = box.submarine.resource_system.battery
	assert_eq(box.submarine.sonar.request_ping(),ERR_BUSY)
	assert_eq(box.submarine.resource_system.battery,before)
func test_blast_edge_still_kills_and_successful_stun_marks_first_engagement() -> void:
	var actor: CombatSwarmer = box.swarmers[0]
	assert_eq(box.health[0].apply_blast(&"combat/edge",actor.global_position+Vector2.RIGHT*box.torpedoes._rules.radius,box.torpedoes._rules.radius,box.torpedoes._rules.damage),CombatBox.SWARM.maximum_health)
	assert_true(actor._destroyed)
	box.submarine.global_position = CombatBox.DATA.refit
	assert_eq(box.refit(),OK)
	# Record in memory here; the ordinary start UI separately tests the local store.
	assert_eq(box.observer.recorder.begin("source",true),OK)
	box.resume()
	box.submarine.global_position = CombatBox.DATA.stun_probe
	assert_eq(box.submarine.sonar.request_ping(),OK)
	assert_not_null(box.observer.recorder.snapshot().combat.first_engage_active_seconds)
	assert_eq(box.observer.recorder.snapshot().combat.stun_uses,1)
	assert_eq(box.observer.recorder.finish(),OK)
	# Outside stun range but inside dash range, hearing can become TELEGRAPH
	# within one AI step. This must still establish the first engagement time.
	assert_eq(box.refit(),ERR_UNAVAILABLE)
	box.submarine.global_position = CombatBox.DATA.refit
	assert_eq(box.refit(),OK)
	box.stalker.set_suspended(true)
	for index: int in range(1,box.swarmers.size()): box.swarmers[index].set_suspended(true)
	assert_eq(box.observer.recorder.begin("source",true),OK)
	box.submarine.global_position = actor.global_position-Vector2.RIGHT*(box.stun.profile.range_units+CombatBox.SWARM.dash_range)*0.5
	assert_eq(box.submarine.sonar.request_ping(),OK)
	await wait_physics_frames(6)
	assert_eq(actor.model.phase,SwarmerState.Phase.TELEGRAPH)
	assert_not_null(box.observer.recorder.snapshot().combat.first_engage_active_seconds)
	assert_eq(box.observer.recorder.snapshot().combat.stun_uses,0)
	assert_eq(box.observer.recorder.finish(),OK)
func test_two_real_tunnel_mouths_fit_the_vessel_in_both_directions() -> void:
	var shape: CollisionShape2D = box.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var span: float = (shape.shape as CapsuleShape2D).height
	for index: int in range(CombatBox.DATA.mouths.size()):
		var mouth: Rect2 = CombatBox.DATA.mouths[index]
		var outside: Vector2 = Vector2(mouth.get_center().x,mouth.end.y+span) if index==0 else Vector2(mouth.get_center().x,mouth.position.y-span)
		var inside: Vector2 = Vector2(mouth.get_center().x,mouth.position.y+span*1.5) if index==0 else Vector2(mouth.get_center().x,mouth.end.y-span*1.5)
		for pair: Array in [[outside,inside],[inside,outside]]:
			var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			query.shape = shape.shape
			query.transform = Transform2D(0,pair[0])*shape.transform
			query.motion = pair[1]-pair[0]
			query.collision_mask = 1
			query.exclude = [box.submarine.get_rid()]
			var space: PhysicsDirectSpaceState2D = box.get_world_2d().direct_space_state
			assert_true(space.intersect_shape(query).is_empty())
			assert_eq(space.cast_motion(query)[0],1.0,"The authored mouth is an actual reversible passage")
func test_real_torpedo_contact_scares_invulnerable_stalker() -> void:
	box.resume()
	assert_eq(box.observer.recorder.begin("source",true),OK)
	box.stalker.set_physics_process(false)
	box.submarine.global_position = box.stalker.global_position-Vector2.RIGHT*box.stalker.hunt.profile.scare_radius*0.8
	box.submarine.facing = 1
	await wait_physics_frames(1)
	assert_eq(box.torpedoes.request_fire(),OK)
	var projectile: TorpedoProjectile = box.torpedoes._projectiles.back()
	for tick: int in range(240):
		projectile.advance(1.0/120)
		if projectile.exploded: break
	assert_true(projectile.exploded)
	assert_eq(box.stalker.hunt.phase,RiftStalkerState.Phase.STUN)
	assert_false(box.stalker._destroyed)
	assert_false(box.stalker.damageable)
	assert_not_null(box.observer.recorder.snapshot().combat.first_engage_active_seconds)
	assert_eq(box.observer.recorder.snapshot().combat.stalker_scared,1)
	assert_eq(box.observer.recorder.finish(),OK)
func test_controller_loss_reuses_input_context_release_and_pause() -> void:
	box.resume()
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	box.input_context.observe(event)
	Input.action_press("move_right")
	box.input_context.connection_changed(7,false)
	assert_false(Input.is_action_pressed("move_right"))
	assert_true(box.options.visible)
	assert_false(box.submarine.is_physics_processing())
func test_live_swarmer_resumes_after_stun_telegraphs_and_bites_through_hull_api() -> void:
	box.resume()
	box.stalker.set_suspended(true)
	for index: int in range(1,box.swarmers.size()): box.swarmers[index].set_suspended(true)
	box.submarine.global_position = CombatBox.DATA.stun_probe
	box.submarine.velocity = Vector2.ZERO
	var phases: Array[int] = []
	box.swarmers[0].phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	var hull: float = box.submarine.hull_system.hull
	assert_eq(box.submarine.sonar.request_ping(),OK)
	await wait_physics_frames(240)
	assert_true(SwarmerState.Phase.STUN in phases)
	assert_true(SwarmerState.Phase.TELEGRAPH in phases)
	assert_true(SwarmerState.Phase.DASH in phases)
	assert_eq(box.submarine.hull_system.hull,hull-CombatBox.SWARM.bite_damage)
	assert_eq(box.submarine.hull_system.last_damage_source,&"combat-swarmer/contact")
