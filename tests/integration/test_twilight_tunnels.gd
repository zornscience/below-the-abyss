extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta061-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	view.add_child(game)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func _deploy() -> void:
	game.submarine.global_position = SunlitSurveyData.MAIN_ROUTE[0]
	assert_eq(game.story.apply_choice(LightBloomEncounter.COLLECT),OK)
	game.bloom.reset_session()
	assert_eq(game.discoveries.discover(SunlitShallowsData.POI,&"test/buoy"),OK)
	game.submarine.global_position = SunlitSurveyData.BUOY
	var records: Array[StringName] = game.research.completed_ids()
	records.append(SunlitShallowsData.BUOY)
	assert_eq(game.saves.commit_research_checkpoint(records),OK)
	game.research.restore_completed(records)
	game.missions.reconcile()
	assert_eq(game.saves.finish_sunlit_return(),OK)
	assert_eq(game.saves.transfer_chapter("twilight",true),OK)
func _path_clear(path: PackedVector2Array) -> bool:
	var collision: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var space: PhysicsDirectSpaceState2D = game.submarine.get_world_2d().direct_space_state
	for index: int in range(path.size()-1):
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = Transform2D(0,path[index])*collision.transform
		query.motion = path[index+1]-path[index]
		query.collision_mask = 1
		query.exclude = [game.submarine.get_rid()]
		if not space.intersect_shape(query).is_empty() or space.cast_motion(query)[0]<1.0: return false
	return true
func _fire(profile: TunnelProfile) -> void:
	game.submarine.global_position = profile.origin+profile.fire_from
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(true)
	game.torpedoes._cooldown = 0
	var direction: Vector2 = (profile.shortcut[-1]-profile.shortcut[0]).normalized()
	game.submarine.facing = direction.x
	assert_eq(game.torpedoes.request_fire(),OK)
	var shot: TorpedoProjectile = game.torpedoes._projectiles.back()
	for step: int in range(600):
		shot.advance(1.0/120.0)
		if shot.exploded: break
	assert_true(shot.exploded)
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(2)
func test_authored_reachability_and_widths_with_closed_gates_and_real_collision() -> void:
	_deploy()
	await wait_physics_frames(3)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		for path: PackedVector2Array in [profile.approach,profile.return_path,profile.world_path(profile.main),profile.world_path(profile.branch)]:
			assert_true(_path_clear(path),"Closed-gate reachability "+String(profile.stable_id)+" "+str(path))
		assert_false(_path_clear(profile.world_path(profile.shortcut)))
		var direction: Vector2 = (profile.squeeze[1]-profile.squeeze[0]).normalized().orthogonal()
		var narrowest: float = INF
		for fraction: float in [0.4,0.45,0.5,0.55,0.6]:
			var at: Vector2 = profile.origin+profile.squeeze[0].lerp(profile.squeeze[1],fraction)
			narrowest = minf(narrowest,_width(at,direction))
		var normal: float = _width(profile.origin+profile.normal_probe,Vector2.DOWN)
		print("TUNNEL_WIDTH ",profile.stable_id," squeeze=",narrowest," normal=",normal)
		var span: float = ((game.submarine.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D).height
		assert_gte(narrowest,span*1.5)
		assert_lte(narrowest,span*2.0)
		assert_gte(normal,span*2.5)
	assert_true(game.saves.position_clear(TwilightShelfLayout.SPAWN,0))
	assert_false(game.journey.unsafe_at(TwilightShelfLayout.SPAWN))
func _width(at: Vector2,direction: Vector2) -> float:
	var total: float = 0
	for side: float in [-1.0,1.0]:
		var hit: Dictionary = game.submarine.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(at,at+direction*side*500,1))
		assert_false(hit.is_empty())
		if hit.is_empty(): return INF
		total += at.distance_to(hit.position)
	return total
func test_two_shot_shortcuts_replay_preserve_long_routes_and_refresh_visibility() -> void:
	_deploy()
	await wait_physics_frames(3)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var before: float = game.submarine.resource_system.battery
		await _fire(profile)
		assert_false(_path_clear(profile.world_path(profile.shortcut)),"One shot leaves a real plug")
		await _fire(profile)
		assert_true(_path_clear(profile.world_path(profile.shortcut)),"Two shots open the actual hull passage")
		assert_eq(game.submarine.resource_system.battery,before-ChapterJourney.ACTION_COSTS.torpedo_battery*2)
		assert_true(_path_clear(profile.world_path(profile.main)))
		assert_true(_path_clear(profile.return_path))
	var cuts: Array[Dictionary] = game.excavation.snapshot()
	assert_eq(cuts.size(),4)
	assert_eq(game.excavation.restore(cuts),OK)
	await wait_physics_frames(2)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems: assert_true(_path_clear(profile.world_path(profile.shortcut)))
	assert_eq(game.journey.visibility.contours.get_child_count(),game.journey.layout.find_children("*","CollisionPolygon2D",true,false).size())
func test_tunnel_vent_times_the_squeeze_and_keeps_existing_damage_and_pause_rules() -> void:
	_deploy()
	await wait_physics_frames(3)
	var vent: ThermalVent = game.journey.tunnels.vents[0]
	var profile: TunnelProfile = TwilightTunnelCatalog.DATA.systems[0] as TunnelProfile
	var at: Vector2 = profile.origin+profile.squeeze[1]
	assert_true(vent.exposes(at))
	assert_false(vent.exposes(TwilightShelfLayout.SPAWN))
	vent.reset_session()
	game.submarine.global_position = at
	game.submarine.set_simulation_enabled(true)
	vent.set_physics_process(false)
	for second: int in range(int(vent.configuration.quiet_seconds)): vent.model.advance(1.0,false)
	assert_true("Eruption in" in game.journey.hazard_prompt())
	assert_true(game.journey.unsafe_at(at))
	for second: int in range(int(vent.configuration.warning_seconds)): vent.model.advance(1.0,false)
	var before: float = game.submarine.hull_system.hull
	vent.advance(0.5)
	assert_eq(game.submarine.hull_system.hull,before-vent.configuration.hull_per_second*0.5)
	game.submarine.set_simulation_enabled(false)
	vent.advance(0.5)
	assert_eq(game.submarine.hull_system.hull,before-vent.configuration.hull_per_second*0.5)
func test_shared_journal_survives_continue_and_both_region_transfers_with_actual_supplies() -> void:
	assert_eq(game.torpedoes._emitter.profile.range_units,TwilightHunt.PROFILE.hearing.maximum_range_units)
	assert_eq((game.get_node("AcousticBus") as AcousticBus)._rules.attenuation,AcousticDispatchProfile.Attenuation.NONE)
	var shallow: DestructibleRock = game.chapter.guide.layout.gate
	assert_eq(game.excavation.excavate(SunlitSurveyData.GATE.get_center(),game.torpedoes._rules.radius),1)
	var shallow_pieces: Array[PackedVector2Array] = shallow.pieces.duplicate(true)
	_deploy()
	var profile: TunnelProfile = TwilightTunnelCatalog.DATA.systems[0] as TunnelProfile
	await _fire(profile)
	await _fire(profile)
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	game.submarine.resource_system.consume_oxygen(7)
	assert_eq(game.saves.save_current(),OK)
	var checkpoint: Dictionary = game.saves._state.duplicate(true)
	assert_eq(checkpoint.schema_version,10)
	assert_eq(checkpoint.size(),12)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.resource_system.battery,float(checkpoint.player.battery))
	assert_eq(game.submarine.resource_system.oxygen,float(checkpoint.player.oxygen))
	assert_eq(game.torpedoes.ammunition,int(checkpoint.prototype.ammunition))
	assert_eq(game.torpedoes.battery_cost(),ChapterJourney.ACTION_COSTS.torpedo_battery)
	assert_eq(game.excavation.snapshot(),checkpoint.terrain)
	assert_eq(shallow.pieces,shallow_pieces)
	await wait_physics_frames(2)
	assert_true(_path_clear(profile.world_path(profile.shortcut)))
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.excavation.snapshot(),checkpoint.terrain)
	assert_eq(shallow.pieces,shallow_pieces)
	assert_eq(game.excavation.excavate(SunlitSurveyData.GATE.position,game.torpedoes._rules.radius),1)
	var both: Array[Dictionary] = game.excavation.snapshot()
	var modified: Array[PackedVector2Array] = shallow.pieces.duplicate(true)
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_eq(game.excavation.snapshot(),both)
	assert_eq(shallow.pieces,modified)
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(2)
	assert_eq(game.excavation.snapshot(),both)
	assert_true(_path_clear(profile.world_path(profile.shortcut)))
func test_shared_cut_cap_leaves_both_long_routes_retreats_and_tether_available() -> void:
	_deploy()
	var cuts: Array[Dictionary] = []
	for index: int in range(ExcavationState.MAX_CUTS):
		cuts.append({"rock":game.chapter.guide.layout.gate.rock_id,"at":[SunlitSurveyData.GATE.get_center().x,SunlitSurveyData.GATE.get_center().y],"radius":game.torpedoes._rules.radius})
	assert_eq(game.excavation.restore(cuts),OK)
	await wait_physics_frames(2)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var gate: DestructibleRock = game.excavation._rocks[profile.gate_id]
		var before: Array[PackedVector2Array] = gate.pieces.duplicate(true)
		assert_eq(game.excavation.excavate(profile.world_gate().get_center(),game.torpedoes._rules.radius),0)
		assert_eq(gate.pieces,before)
		for path: PackedVector2Array in [profile.approach,profile.world_path(profile.main),profile.world_path(profile.branch),profile.return_path]:
			assert_true(_path_clear(path))
			var reverse: PackedVector2Array = path.duplicate()
			reverse.reverse()
			assert_true(_path_clear(reverse))
	assert_eq(game.excavation.snapshot(),cuts)
	cuts.append(cuts[0])
	assert_eq(game.excavation.restore(cuts),ERR_INVALID_DATA)
	assert_eq(game.excavation.snapshot().size(),ExcavationState.MAX_CUTS)
func test_optional_scans_reach_radio_and_map_without_xp_or_required_objectives() -> void:
	_deploy()
	var original: Dictionary = game.revision.campaign.science.duplicate(true)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		assert_false((StringName(String(profile.payoff_id)+"-poi") in game.discoveries.discovered_ids()))
		game.submarine.global_position = profile.origin+profile.branch[-1]
		game.submarine.velocity = Vector2.ZERO
		game.submarine.set_simulation_enabled(true)
		await wait_physics_frames(2)
		assert_eq(game.submarine.scanner.request_scan(profile.payoff_id),OK)
		assert_eq(game.submarine.scanner.advance(5.0),OK)
		assert_true(game.research.is_completed(profile.payoff_id))
		assert_true((StringName(String(profile.payoff_id)+"-poi") in game.discoveries.discovered_ids()))
		assert_true(game.revision.ui.notifications.contains_message(String(profile.payoff_id)))
		game.submarine.set_simulation_enabled(false)
	assert_eq(game.revision.campaign.science,original)
	assert_false(TwilightShelfData.ready(game.research,game.story))
func test_real_gate_detonations_are_heard_only_for_the_in_range_system() -> void:
	_deploy()
	await wait_physics_frames(2)
	var actor: RiftStalker = game.journey.hunt.actors[0]
	watch_signals(actor.receiver)
	var heard: int = 0
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		actor.hunt.reset_session()
		await _fire(profile)
		var distance: float = actor.global_position.distance_to(profile.world_gate().get_center())
		var within_range: bool = distance<TwilightHunt.PROFILE.hearing.maximum_range_units
		if within_range: heard += 1
		assert_signal_emit_count(actor.receiver,"event_received",heard)
		actor.hunt.advance(0.01,actor.position)
		assert_eq(actor.hunt.phase,RiftStalkerState.Phase.INVESTIGATE if within_range else RiftStalkerState.Phase.QUIET)
func test_repeated_cuts_decrease_rock_area_keep_every_return_clear_and_tether_safe_through_vent_cycle() -> void:
	_deploy()
	await wait_physics_frames(2)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var rock: DestructibleRock = game.excavation._rocks[profile.gate_id]
		var previous_area: float = _rock_area(rock.pieces)
		for offset: Vector2 in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			game.excavation.excavate(profile.world_gate().get_center()+offset*game.torpedoes._rules.radius*0.5,game.torpedoes._rules.radius)
			var area: float = _rock_area(rock.pieces)
			assert_lte(area,previous_area,"Every cut only removes rock area")
			previous_area = area
			await wait_physics_frames(1)
			for path: PackedVector2Array in [profile.world_path(profile.main),profile.world_path(profile.branch),profile.approach,profile.return_path]:
				assert_true(_path_clear(path),"Repeated cuts cannot seal any return edge")
	for vent: ThermalVent in game.journey.tunnels.vents:
		vent.reset_session()
		for second: int in range(int(vent.configuration.cycle_seconds())):
			vent.model.advance(1.0,false)
			assert_false(game.journey.unsafe_at(TwilightShelfLayout.SPAWN))
			assert_true(game.saves.position_clear(TwilightShelfLayout.SPAWN,0))

func _rock_area(pieces: Array[PackedVector2Array]) -> float:
	var result: float = 0
	for piece: PackedVector2Array in pieces:
		var area: float = 0
		# Translate before the shoelace sum to avoid large-world cancellation.
		for index: int in range(piece.size()): area += (piece[index]-piece[0]).cross(piece[(index+1)%piece.size()]-piece[0])
		result += absf(area)*0.5
	return result
func test_tunnel_echoes_require_an_open_sightline_without_changing_older_subjects() -> void:
	_deploy()
	await wait_physics_frames(2)
	for profile: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		var echo: SonarRevealTarget
		for candidate: SonarRevealTarget in game.journey.expedition.echoes():
			if candidate.target_id==StringName(String(profile.payoff_id)+"-echo"): echo = candidate
		assert_not_null(echo)
		assert_true(echo.requires_clear_path)
		game.submarine.global_position = _blocked_shelf_view(profile)
		assert_true(game.submarine.global_position.is_finite(),"A nearby shelf view is occluded by the tunnel wall")
		game.submarine.velocity = Vector2.ZERO
		game.submarine.set_simulation_enabled(true)
		game.submarine.sonar.reset_session()
		assert_eq(game.submarine.sonar.request_ping(),OK)
		for step: int in range(12): game.submarine.sonar.advance(0.25)
		assert_false(StringName(String(profile.payoff_id)+"-poi") in game.discoveries.discovered_ids(),"An actual intervening wall blocks discovery from the open shelf")
		game.submarine.global_position = profile.origin+profile.branch[0]
		game.submarine.sonar.reset_session()
		assert_eq(game.submarine.sonar.request_ping(),OK)
		for step: int in range(12): game.submarine.sonar.advance(0.25)
		assert_true(StringName(String(profile.payoff_id)+"-poi") in game.discoveries.discovered_ids(),"The branch sightline reveals its payoff normally")
		game.submarine.set_simulation_enabled(false)
	for echo: SonarRevealTarget in game.journey.expedition.echoes():
		if String(echo.target_id).trim_suffix("-echo") not in TwilightTunnelCatalog.payoff_ids(): assert_false(echo.requires_clear_path)

func _blocked_shelf_view(profile: TunnelProfile) -> Vector2:
	var target: Vector2 = profile.origin+profile.branch[-1]
	var span: float = ((game.submarine.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D).height
	for path: PackedVector2Array in [profile.approach,profile.return_path]:
		for index: int in range(path.size()-1):
			var steps: int = ceili(path[index].distance_to(path[index+1])/span)
			for step: int in range(steps+1):
				var at: Vector2 = path[index].lerp(path[index+1],float(step)/steps)
				if at.distance_to(target)>game.submarine.sonar.maximum_radius() or not game.saves.position_clear(at,0): continue
				var hit: Dictionary = game.submarine.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(at,target,1))
				if not hit.is_empty(): return at
	return Vector2.INF
