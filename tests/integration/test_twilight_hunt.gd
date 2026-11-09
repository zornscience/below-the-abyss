extends GutTest
var game: ShelfPrototype
func before_each() -> void:
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta060-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.journey.prepare({"phase":"twilight","commissioned":true})
	game.revision.ui.title_page.hide()
	game.route_layer.hide()
	game.submarine.global_position = TwilightHunt.PROFILE.patrol_points[0]+Vector2(TwilightHunt.PROFILE.sense_radius*0.5,0)
	game.submarine.set_simulation_enabled(true)
func test_real_ping_passive_classification_and_no_damage_receiver_or_reward() -> void:
	var hunt: TwilightHunt = game.journey.hunt
	var actor: RiftStalker = hunt.actors[0]
	assert_true(actor.receiver.get_bus()==game.get_node("AcousticBus"))
	assert_false(actor.damageable)
	for node: Node in actor.get_children(): assert_false(node is BlastReceiver)
	for receiver: BlastReceiver in game.torpedoes._receivers: assert_ne(receiver.get_parent(),actor)
	actor.set_destroyed(true)
	assert_false(actor._destroyed)
	var campaign: Dictionary = game.revision.campaign.duplicate(true)
	assert_eq(game.submarine.sonar.request_ping(),OK)
	await wait_physics_frames(4)
	assert_eq(actor.hunt.phase,RiftStalkerState.Phase.WARNING)
	game.submarine.passive.reset_session()
	hunt._next_contact = 0
	hunt._physics_process(0.01)
	var heard: bool = false
	for contact: Dictionary in game.submarine.passive.contacts_snapshot():
		if contact.source_id==hunt.passive.source_id:
			heard = true
			assert_eq(contact.classification,&"marine_life")
	assert_true(heard)
	assert_eq(game.revision.campaign,campaign)
func test_actual_blast_emits_once_stuns_without_kill_and_contact_uses_hull_api() -> void:
	var hunt: TwilightHunt = game.journey.hunt
	var actor: RiftStalker = hunt.actors[0]
	actor.set_physics_process(false)
	assert_eq(actor.advance_simulation(0),OK)
	actor.hunt.sense(game.submarine.global_position,true,true)
	assert_eq(actor.hunt.offer(AcousticEvent.create(&"test/ping",&"neris-01/sonar",&"active_sonar",&"scientific",actor.position,1,1800,0),1,0,actor.position),OK)
	actor.hunt.advance(0.01,actor.position)
	actor.hunt.advance(actor.hunt.profile.warning_seconds,actor.position)
	game.submarine.global_position = actor.global_position
	watch_signals(game.submarine.hull_system)
	actor._after_step(0.01)
	assert_eq(game.submarine.hull_system.hull,95.0)
	assert_signal_emitted(game.submarine.hull_system,"hull_changed")
	var projectile: TorpedoProjectile = TorpedoProjectile.new()
	game.get_node("WorldRoot/WorldEffects").add_child(projectile)
	projectile.event_id = &"test/defence"
	projectile.blast_radius = game.torpedoes._rules.radius
	projectile.blast_damage = game.torpedoes._rules.damage
	watch_signals(game.torpedoes._emitter)
	game.torpedoes._impact(projectile,actor.global_position)
	assert_signal_emit_count(game.torpedoes._emitter,"event_emitted",1)
	assert_eq(actor.hunt.phase,RiftStalkerState.Phase.STUN)
	assert_false(actor._destroyed)
	actor.hunt.advance(actor.hunt.profile.stun_seconds,actor.position)
	assert_eq(actor.hunt.phase,RiftStalkerState.Phase.FLEE)
	actor._after_step(0.01)
	assert_eq(game.submarine.hull_system.hull,95.0)
func test_region_and_pause_reset_scope_and_quiet_travel_are_safe() -> void:
	var actor: RiftStalker = game.journey.hunt.actors[0]
	actor.set_physics_process(false)
	for tick: int in range(240): actor.advance_simulation(0.1)
	assert_eq(actor.hunt.phase,RiftStalkerState.Phase.QUIET)
	assert_eq(game.submarine.hull_system.hull,100.0)
	game.submarine.set_simulation_enabled(false)
	var time: float = actor.hunt._time
	actor.advance_simulation(1)
	assert_eq(actor.hunt._time,time)
	assert_true(game.saves.checkpoint_restored.is_connected(game.journey.hunt.reset_session))
	game.saves.checkpoint_restored.emit()
	assert_eq(actor.position,TwilightHunt.PROFILE.patrol_points[0])
	assert_eq(actor.hunt.phase,RiftStalkerState.Phase.QUIET)
	game.journey.prepare({"phase":"sunlit","commissioned":false})
	assert_false(game.journey.hunt.enabled)
	assert_false(actor.receiver.enabled)
	assert_false(actor.visible)

func test_real_fired_torpedo_hits_invulnerable_actor_once_and_pays_twilight_cost() -> void:
	var actor: RiftStalker = game.journey.hunt.actors[0]
	actor.set_physics_process(false)
	game.torpedoes.set_physics_process(false)
	game.submarine.global_position = actor.global_position-Vector2(200,0)
	await wait_physics_frames(2)
	var before: float = game.submarine.resource_system.battery
	watch_signals(game.torpedoes._emitter)
	assert_eq(game.torpedoes.request_fire(),OK)
	assert_eq(game.submarine.resource_system.battery,before-ChapterJourney.ACTION_COSTS.torpedo_battery)
	var projectile: TorpedoProjectile = game.torpedoes._projectiles.back()
	for tick: int in range(180):
		projectile.advance(1.0/120.0)
		if projectile.exploded: break
	assert_true(projectile.exploded)
	assert_eq(actor.hunt.phase,RiftStalkerState.Phase.STUN)
	assert_signal_emit_count(game.torpedoes._emitter,"event_emitted",1)
	assert_false(actor._destroyed)
