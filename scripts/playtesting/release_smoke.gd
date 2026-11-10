class_name ReleaseSmoke
extends Node
## Runs in the actual exported application when explicitly requested.
## Limited to the playtest export: ordinary builds ignore the flag entirely.
func _ready() -> void:
	if not OS.has_feature("playtest") or not OS.get_cmdline_user_args().has("--release-smoke"): return
	call_deferred("_verify")
## assert() is stripped from release exports, so prove the Twilight sonar and discovery
## registrations exist in this exact binary: every echo, the sentinel and the net contact.
func _verify_registration(game: ShelfPrototype) -> bool:
	var bus: AcousticBus = game.get_node_or_null("AcousticBus") as AcousticBus
	var expedition: TwilightExpedition = game.journey.expedition if game.journey!=null else null
	if bus==null or expedition==null or expedition.echoes().is_empty(): return false
	if OS.get_cmdline_user_args().has("--break-registration-wiring"):
		expedition.echoes()[0].bind_bus(null)
	for echo: SonarRevealTarget in expedition.echoes():
		if echo.receiver.get_bus()!=bus or not game.submarine.sonar.is_listening_to(echo) or not game.discoveries.is_sonar_bound(echo):
			push_error("RELEASE_REGISTRATION_WIRING_FAIL echo "+String(echo.target_id))
			return false
	if expedition.sentinel==null or expedition.sentinel.receiver.get_bus()!=bus:
		push_error("RELEASE_REGISTRATION_WIRING_FAIL sentinel")
		return false
	if expedition.contact==null or expedition.contact.emitter.get_bus()!=bus:
		push_error("RELEASE_REGISTRATION_WIRING_FAIL net contact")
		return false
	print("RELEASE_REGISTRATION_WIRING_PASS")
	return true
func _verify() -> void:
	var game: ShelfPrototype = get_parent() as ShelfPrototype
	if not _verify_registration(game):
		get_tree().quit(1)
		return
	var view: TwilightVisibility = game.journey.visibility
	if view!=null and OS.get_cmdline_user_args().has("--break-visibility-wiring"):
		game.submarine.sonar.pulse_emitted.disconnect(view._ping)
	if view==null or view.material==null or view.contours.get_child_count()<game.journey.layout.bodies.size() or not game.submarine.sonar.pulse_emitted.is_connected(view._ping):
		push_error("RELEASE_VISIBILITY_WIRING_FAIL")
		get_tree().quit(1)
		return
	if not game.journey.habitat.ambient.get_child_count()>0:
		get_tree().quit(1)
		return
	game.journey.prepare({"phase":"twilight","commissioned":true})
	# Continue and refitting reapply upgrade profiles after regional preparation.
	game.upgrades.reapply()
	if OS.get_cmdline_user_args().has("--break-resource-wiring"):
		game.submarine.sonar.set_battery_cost(game.journey._shallow_ping_cost)
		game.torpedoes.set_battery_cost(game.journey._shallow_torpedo_cost)
	var costs: ActionCostProfile = ChapterJourney.ACTION_COSTS
	if game.submarine.sonar.battery_cost()!=costs.ping_battery or game.torpedoes.battery_cost()!=costs.torpedo_battery:
		push_error("RELEASE_RESOURCE_WIRING_FAIL")
		get_tree().quit(1)
		return
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	(game.get_node("WorldRoot") as Node2D).show()
	game.submarine.set_simulation_enabled(true)
	var battery_before: float = game.submarine.resource_system.battery
	var emitted: Error = game.submarine.sonar.request_ping()
	if emitted!=OK or view.speeds[0]<=0:
		push_error("RELEASE_VISIBILITY_EMISSION_FAIL")
		get_tree().quit(1)
		return
	if not is_equal_approx(game.submarine.resource_system.battery,battery_before-costs.ping_battery):
		push_error("RELEASE_RESOURCE_WIRING_FAIL ping debit")
		get_tree().quit(1)
		return
	var fired: Error = game.torpedoes.request_fire()
	if fired!=OK or not is_equal_approx(game.submarine.resource_system.battery,battery_before-costs.ping_battery-costs.torpedo_battery):
		push_error("RELEASE_RESOURCE_WIRING_FAIL torpedo debit")
		get_tree().quit(1)
		return
	print("RELEASE_RESOURCE_WIRING_PASS")
	game.submarine.sonar.advance(0.25)
	view._process(0)
	if view.pings[0].z<0.24 or not view.veil.visible:
		push_error("RELEASE_VISIBILITY_CLOCK_FAIL")
		get_tree().quit(1)
		return
	print("RELEASE_VISIBILITY_WIRING_PASS")
	if not _verify_tunnels(game):
		get_tree().quit(1)
		return
	if not await _verify_stalker(game):
		get_tree().quit(1)
		return
	await _verify_depth_gate(game)

func _verify_depth_gate(game: ShelfPrototype) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rank_before: int = game.revision.campaign.ranks.hull
	for rank: int in range(4):
		game.revision.campaign.ranks.hull = rank
		game.upgrades.reapply()
		if args.has("--break-depth-rating-wiring"): game.submarine.damage_system.set_maximum_depth_m(300)
		var expected: float = game.revision.tree.hull_ratings[rank]+ChapterJourney.PRESSURE_FIT.baseline_safe_depth_m-game.revision.tree.hull_ratings[0]
		if game.submarine.damage_system.get_maximum_depth_m()!=expected:
			push_error("RELEASE_DEPTH_RATING_WIRING_FAIL")
			get_tree().quit(1)
			return
	game.revision.campaign.ranks.hull = rank_before
	game.upgrades.reapply()
	var gate: DepthGateProfile = TwilightShelfLayout.DEPTH_GATE
	if args.has("--break-depth-section-wiring"): game.journey.layout.set_enabled(false)
	var registered: bool = game.submarine.scanner._known(&"twilight-deep-crust") and game.journey.layout.visible and Rect2(game.region.camera_bounds).has_point(gate.lower_left)
	for rock: GrayboxRock in game.journey.layout.bodies:
		registered = registered and rock.collision_layer==1
	if not registered:
		push_error("RELEASE_DEPTH_SECTION_WIRING_FAIL")
		get_tree().quit(1)
		return
	var flow: TwilightDepthGate = game.journey.depth_gate
	if args.has("--break-failure-wiring"): game.submarine.hull_system.vessel_destroyed.disconnect(flow._destroyed)
	if not game.submarine.hull_system.vessel_destroyed.is_connected(flow._destroyed):
		push_error("RELEASE_FAILURE_WIRING_FAIL")
		get_tree().quit(1)
		return
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"pressure")
	await get_tree().process_frame
	await get_tree().process_frame
	if not flow.pending or not flow.panel.visible or game.submarine.is_physics_processing():
		push_error("RELEASE_FAILURE_WIRING_FAIL presentation")
		get_tree().quit(1)
		return
	print("RELEASE_DEPTH_GATE_PASS")
	var proof: CombatBoxReleaseProof = CombatBoxReleaseProof.new()
	get_tree().root.add_child(proof)
	proof.start(game)

func _verify_stalker(game: ShelfPrototype) -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var hunt: TwilightHunt = game.journey.hunt
	if hunt==null or hunt.actors.size()!=1:
		push_error("RELEASE_STALKER_REGISTRATION_WIRING_FAIL actor")
		return false
	var actor: RiftStalker = hunt.actors[0]
	var bus: AcousticBus = game.get_node("AcousticBus") as AcousticBus
	if args.has("--break-stalker-registration-wiring"): actor.bind_bus(null)
	if actor.receiver.get_bus()!=bus or not hunt.enabled or actor.damageable or actor.collision_layer!=8:
		push_error("RELEASE_STALKER_REGISTRATION_WIRING_FAIL")
		return false
	for node: Node in actor.get_children():
		if node is BlastReceiver:
			push_error("RELEASE_STALKER_REGISTRATION_WIRING_FAIL damage receiver")
			return false
	if args.has("--break-stalker-passive-wiring"): hunt.passive.bind_bus(null)
	game.submarine.global_position = actor.global_position+Vector2(hunt.PROFILE.sense_radius*0.5,0)
	game.submarine.passive.reset_session()
	hunt._next_contact = 0
	hunt._physics_process(0.01)
	var heard: bool = false
	for contact: Dictionary in game.submarine.passive.contacts_snapshot():
		if contact.source_id==hunt.passive.source_id and contact.classification==&"marine_life": heard = true
	if hunt.passive.get_bus()!=bus or not heard:
		push_error("RELEASE_STALKER_PASSIVE_WIRING_FAIL")
		return false
	actor.set_physics_process(false)
	actor.hunt.reset_session()
	if args.has("--break-stalker-hearing-wiring"): actor.receiver.profile.accepted_event_types = [&"ambient"]
	game.submarine.sonar.reset_session()
	var ping: Error = game.submarine.sonar.request_ping()
	actor.hunt.advance(0.01,actor.position)
	if ping!=OK or actor.hunt.phase!=RiftStalkerState.Phase.INVESTIGATE:
		push_error("RELEASE_STALKER_HEARING_WIRING_FAIL ping")
		return false
	actor.hunt.reset_session()
	var far: TorpedoProjectile = TorpedoProjectile.new()
	far.event_id = &"release/stalker-far"
	game.get_node("WorldRoot/WorldEffects").add_child(far)
	game.torpedoes._impact(far,actor.global_position+Vector2(hunt.PROFILE.scare_radius*1.5,0))
	actor.hunt.advance(0.01,actor.position)
	if actor.hunt.phase!=RiftStalkerState.Phase.INVESTIGATE:
		push_error("RELEASE_STALKER_HEARING_WIRING_FAIL explosion")
		return false
	actor.hunt.reset_session()
	if args.has("--break-stalker-scare-wiring"): game.torpedoes.detonated.disconnect(hunt._blast)
	# Prove the real projectile reaches the invulnerable weapon-contact collider.
	game.submarine.global_position = actor.global_position-Vector2(hunt.PROFILE.scare_radius*0.8,0)
	await get_tree().physics_frame
	game.torpedoes._cooldown = 0
	var fired: Error = game.torpedoes.request_fire()
	if fired!=OK:
		push_error("RELEASE_STALKER_SCARE_WIRING_FAIL launch")
		return false
	var near: TorpedoProjectile = game.torpedoes._projectiles.back()
	for tick: int in range(240):
		near.advance(1.0/120.0)
		if near.exploded: break
	if not near.exploded or actor.hunt.phase!=RiftStalkerState.Phase.STUN or actor._destroyed:
		push_error("RELEASE_STALKER_SCARE_WIRING_FAIL")
		return false
	print("RELEASE_STALKER_WIRING_PASS")
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	return true

func _verify_tunnels(game: ShelfPrototype) -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var layout: TwilightShelfLayout = game.journey.layout
	var tunnels: TwilightTunnels = game.journey.tunnels
	if args.has("--break-tunnel-geometry-wiring") and not layout.tunnel_bodies.is_empty(): layout.tunnel_bodies[0].collision_layer = 0
	var expected: int = 0
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems: expected += profile.rock_polygons().size()
	if expected==0 or layout.tunnel_bodies.size()!=expected:
		push_error("RELEASE_TUNNEL_GEOMETRY_WIRING_FAIL count")
		return false
	for body: GrayboxRock in layout.tunnel_bodies:
		var covered: bool = false
		for child: Node in game.journey.visibility.contours.get_children():
			if child is Line2D and (child as Line2D).points==body.outline: covered = true
		if body.collision_layer!=1 or not covered or body.find_children("*","CollisionPolygon2D",true,false).is_empty():
			push_error("RELEASE_TUNNEL_GEOMETRY_WIRING_FAIL collision/visibility")
			return false
	if args.has("--break-tunnel-gates-wiring") and not tunnels.gates.is_empty(): game.excavation._rocks.erase(tunnels.gates[0].rock_id)
	if args.has("--break-tunnel-vents-wiring") and not tunnels.vents.is_empty():
		var removed: ThermalVent = tunnels.vents.pop_back()
		removed.enabled = false
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var rock: DestructibleRock = game.excavation._rocks.get(profile.gate_id) as DestructibleRock
		if rock==null or rock not in tunnels.gates or rock.collision_layer!=1 or rock.get_parent()!=tunnels:
			push_error("RELEASE_TUNNEL_GATES_WIRING_FAIL "+profile.gate_id)
			return false
		var covered: bool = false
		for child: Node in game.journey.visibility.contours.get_children():
			if child is Line2D and (child as Line2D).points==rock.original: covered = true
		if not covered or not game.excavation.geometry_changed.is_connected(game.journey.visibility.rebuild_contours):
			push_error("RELEASE_TUNNEL_GEOMETRY_WIRING_FAIL gate outlines")
			return false
		if profile.vent_id.is_empty(): continue
		var found: bool = false
		for vent: ThermalVent in tunnels.vents:
			if vent.stable_id==profile.vent_id and vent.enabled and vent._solid!=null and vent._solid.collision_layer==1 and vent.damage_applied.is_connected(game.hud.show_thermal_damage): found = true
		if not found or not tunnels.is_physics_processing():
			push_error("RELEASE_TUNNEL_VENTS_WIRING_FAIL "+String(profile.vent_id))
			return false
	print("RELEASE_TUNNEL_GEOMETRY_WIRING_PASS")
	print("RELEASE_TUNNEL_GATES_WIRING_PASS")
	print("RELEASE_TUNNEL_VENTS_WIRING_PASS")
	return true
