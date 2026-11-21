extends GutTest
## DC-2: the flooded squeeze, the gated shortcut, saved cuts, the oxygen retune and the
## two hints. Rules and authored data only: every coordinate comes from DrownedCavesLayout or its
## tunnel profile. Torpedoes, the vessel capsule and collision are real.
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://dc2-%d.json" % Time.get_ticks_usec()
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
# ---------------------------------------------------------------- helpers
func _deploy() -> void:
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
func _study(id: StringName) -> void:
	game.submarine.global_position = game.research.definition(id).position-Vector2(90,0)
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(1)
	assert_eq(game.submarine.scanner.request_scan(id),OK)
	assert_eq(game.submarine.scanner.advance(5.0),OK)
	assert_true(game.research.is_completed(id))
	game.submarine.set_simulation_enabled(false)
func _descend() -> void:
	_deploy()
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]: await _study(id)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(TwilightShelfData.RELEASE),OK)
	game.revision.ui.radio_page.hide()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	assert_eq(game.saves.transfer_chapter("caves",true),OK)
	game.revision.ui.radio_page.hide()
	game.route_layer.hide()
func _profile() -> TunnelProfile:
	return DrownedCavesLayout.TUNNELS.systems[0] as TunnelProfile
func _gate() -> DestructibleRock:
	return game.excavation._rocks[_profile().gate_id] as DestructibleRock
## True when the real vessel capsule can travel the whole polyline.
func _path_clear(points: PackedVector2Array,shape: Shape2D = null) -> bool:
	var collision: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var space: PhysicsDirectSpaceState2D = game.submarine.get_world_2d().direct_space_state
	for index: int in range(points.size()-1):
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = shape if shape!=null else collision.shape
		query.transform = Transform2D(0,points[index])*(collision.transform if shape==null else Transform2D.IDENTITY)
		query.motion = points[index+1]-points[index]
		query.collision_mask = 1
		query.exclude = [game.submarine.get_rid()]
		if not space.intersect_shape(query).is_empty() or space.cast_motion(query)[0]<1.0: return false
	return true
func _fire() -> void:
	var profile: TunnelProfile = _profile()
	game.submarine.global_position = profile.origin+profile.fire_from
	game.submarine.velocity = Vector2.ZERO
	game.submarine.set_simulation_enabled(true)
	game.torpedoes._cooldown = 0
	game.submarine.facing = signf((profile.shortcut[-1]-profile.shortcut[0]).x)
	assert_eq(game.torpedoes.request_fire(),OK)
	var shot: TorpedoProjectile = game.torpedoes._projectiles.back()
	for step: int in range(600):
		shot.advance(1.0/120.0)
		if shot.exploded: break
	assert_true(shot.exploded)
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(2)
# ---------------------------------------------------------------- authored data
func test_the_tunnel_data_is_valid_scaled_to_the_vessel_and_collides_with_nothing_else() -> void:
	var shape: CapsuleShape2D = (game.submarine.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	assert_true(TwilightTunnelCatalog.is_valid(shape.height,DrownedCavesLayout.TUNNELS,1))
	assert_false(TwilightTunnelCatalog.is_valid(shape.height,DrownedCavesLayout.TUNNELS,2),"one system, so the Twilight minimum of two still rejects it")
	var profile: TunnelProfile = _profile()
	assert_true(profile.is_valid(shape.height))
	assert_true(profile.payoff_id.is_empty(),"no scan record: records are DC-4")
	assert_false(profile.gate_id in ShelfChapterData.terrain_ids())
	for twilight: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		assert_ne(twilight.gate_id,profile.gate_id)
		assert_ne(twilight.stable_id,profile.stable_id)
	assert_eq(SunlitSurveyData._rect(DrownedCavesLayout.SHAPES[profile.replace_index]),SunlitSurveyData._rect(Rect2(profile.origin,Vector2(2000,2400))),"the carved mass is the shape the profile replaces")
	assert_gt(TunnelProfile.length(profile.long_path()),TunnelProfile.length(profile.shortcut))
	assert_gt(profile.normal_width,profile.squeeze_width)
	assert_between(profile.squeeze_width,shape.height*1.5,shape.height*2.0,"a squeeze is about twice the hull")
func test_twilight_tunnel_data_and_gate_lookup_are_unchanged_by_the_second_set() -> void:
	for twilight: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		assert_eq(TwilightTunnelCatalog.gate_profile(twilight.gate_id),twilight)
	assert_eq(TwilightTunnelCatalog.gate_profile(_profile().gate_id),_profile())
	assert_null(TwilightTunnelCatalog.gate_profile("no-such-gate"))
	assert_eq(TwilightTunnelCatalog.records().size(),2,"only the two Twilight payoff records exist")
# ---------------------------------------------------------------- navigation with real collision
func test_the_long_route_is_open_the_shortcut_is_closed_and_the_squeeze_rejects_a_wider_hull() -> void:
	await _descend()
	await wait_physics_frames(2)
	assert_true(_path_clear(DrownedCavesLayout.long_route()),"anchor to far chamber by the long route")
	assert_false(_path_clear(DrownedCavesLayout.shortcut_route()),"the plug closes the shortcut")
	var profile: TunnelProfile = _profile()
	var squeeze: PackedVector2Array = profile.world_path(profile.squeeze)
	var normal: PackedVector2Array = profile.world_path(PackedVector2Array([profile.main[5],profile.main[6]]))
	# A probe 30 units wider than the squeeze across the passage. The squeeze runs vertically and the
	# ordinary passage horizontally, so the probe's long side is perpendicular to each.
	var across: float = profile.squeeze_width+30.0
	var across_squeeze: RectangleShape2D = RectangleShape2D.new()
	across_squeeze.size = Vector2(across,16.0)
	var across_normal: RectangleShape2D = RectangleShape2D.new()
	across_normal.size = Vector2(16.0,across)
	assert_false(_path_clear(squeeze,across_squeeze),"a hull wider than the squeeze cannot pass it")
	assert_true(_path_clear(normal,across_normal),"the same width passes the ordinary passage")
	var narrow: RectangleShape2D = RectangleShape2D.new()
	narrow.size = Vector2(profile.squeeze_width-30.0,16.0)
	assert_true(_path_clear(squeeze,narrow),"a hull narrower than the squeeze passes it")
	assert_true(_path_clear(PackedVector2Array([DrownedCavesLayout.FAR_CHAMBER,DrownedCavesLayout.FAR_CHAMBER+Vector2(1300,0)])),"open water across the far chamber")
	var sealed: Vector2 = Vector2(float(DrownedCavesLayout.CAMERA.end.x)-50.0,DrownedCavesLayout.FAR_CHAMBER.y)
	assert_false(game.saves.position_clear(sealed,0.0),"the far chamber ends against rock")
func test_two_real_torpedoes_open_the_shortcut_and_one_does_not() -> void:
	await _descend()
	await wait_physics_frames(2)
	var shortcut: PackedVector2Array = _profile().world_path(_profile().shortcut)
	assert_false(_path_clear(shortcut))
	await _fire()
	assert_eq(game.excavation.snapshot().size(),1)
	assert_false(_path_clear(shortcut),"one shot is not enough")
	await _fire()
	assert_eq(game.excavation.snapshot().size(),2)
	assert_true(_path_clear(shortcut),"two shots open the shortcut")
	assert_true(_path_clear(DrownedCavesLayout.shortcut_route()),"the whole shortcut route is then flyable")
	assert_true(_path_clear(DrownedCavesLayout.long_route()),"the long route stays open")
func test_a_cave_cut_is_a_valid_checkpoint_replays_on_continue_and_survives_the_round_trip() -> void:
	await _descend()
	await wait_physics_frames(2)
	await _fire()
	await _fire()
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.save_current(),OK)
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
	assert_eq(written.terrain.size(),2)
	for cut: Dictionary in written.terrain: assert_eq(cut.rock,_profile().gate_id)
	assert_eq(ExpeditionSchema.decode(written).error,OK,"the schema accepts a caves gate cut")
	assert_true(ExcavationState.valid(written.terrain))
	var forged: Dictionary = written.duplicate(true)
	forged.terrain[0].at = [0,0]
	assert_false(ExcavationState.valid(forged.terrain),"a cave cut far from its gate is rejected")
	var cuts: Array[Dictionary] = game.excavation.snapshot()
	assert_eq(game.saves.continue_expedition(),OK)
	await wait_physics_frames(2)
	assert_eq(game.excavation.snapshot(),cuts)
	assert_true(_path_clear(_profile().world_path(_profile().shortcut)),"the cut replays after Continue")
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(_gate().collision_layer,0,"the gate is inert at Halcyon")
	assert_eq(game.excavation.snapshot(),cuts,"the cut journal is kept")
	assert_eq(game.saves.transfer_chapter("caves",true),OK)
	await wait_physics_frames(2)
	assert_eq(_gate().collision_layer,1)
	assert_true(_path_clear(_profile().world_path(_profile().shortcut)),"the cut is still open on re-entry")
func test_the_cave_gate_and_the_twilight_gates_never_collide_with_each_other() -> void:
	await _descend()
	for twilight: TunnelProfile in TwilightTunnelCatalog.DATA.systems:
		assert_eq((game.excavation._rocks[twilight.gate_id] as DestructibleRock).collision_layer,0,"Twilight gates are inert in the caves")
	assert_eq(_gate().collision_layer,1)
	assert_eq(game.journey.caves_tunnels.gates.size(),1)
	assert_true(game.journey.caves_tunnels.enabled)
	assert_false(game.journey.tunnels.enabled)
# ---------------------------------------------------------------- oxygen
func test_the_caves_use_their_own_oxygen_rate_and_twilight_keeps_its_own() -> void:
	await _descend()
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	assert_eq(pools.configuration,ChapterJourney.CAVES_RESOURCES)
	var twilight: SubmarineResourceConfig = preload("res://resources/balance/twilight_resources.tres")
	assert_gt(ChapterJourney.CAVES_RESOURCES.oxygen_drain_per_second,twilight.oxygen_drain_per_second*5.0,"oxygen is the main pressure")
	assert_eq(ChapterJourney.CAVES_RESOURCES.battery_idle_drain_per_second,twilight.battery_idle_drain_per_second,"only oxygen is retuned")
	assert_eq(ChapterJourney.CAVES_RESOURCES.battery_thrust_drain_per_second,twilight.battery_thrust_drain_per_second)
	assert_eq(ChapterJourney.CAVES_RESOURCES.max_oxygen,twilight.max_oxygen)
	var before: float = pools.oxygen
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(60)
	game.submarine.set_simulation_enabled(false)
	var drained: float = before-pools.oxygen
	var seconds: float = 60.0/float(Engine.physics_ticks_per_second)
	assert_almost_eq(drained,ChapterJourney.CAVES_RESOURCES.oxygen_drain_per_second*seconds,0.05,"the real physics step drains at the authored rate")
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_eq(pools.configuration,twilight,"Twilight returns to its own rate")
func test_a_full_tank_is_a_bounded_multiple_of_the_authored_round_trip() -> void:
	# A tuning hypothesis, not a measurement: enough that a first visit is not rushed,
	# little enough that detours and a missed squeeze are felt. Derived from the data.
	var tank: float = ChapterJourney.CAVES_RESOURCES.max_oxygen/ChapterJourney.CAVES_RESOURCES.oxygen_drain_per_second
	var motion: SubmarineMotion = preload("res://resources/balance/expedition_motion.tres")
	var round_trip: float = 2.0*TunnelProfile.length(DrownedCavesLayout.long_route())/motion.maximum_speed
	assert_between(tank/round_trip,2.0,4.0,"tank %.0f s, round trip at top speed %.0f s" % [tank,round_trip])
	var shorter: float = 2.0*TunnelProfile.length(DrownedCavesLayout.shortcut_route())/motion.maximum_speed
	assert_lt(shorter,round_trip,"the shortcut saves oxygen")
func test_oxygen_exhaustion_in_the_caves_runs_the_countdown_and_recovers_at_halcyon() -> void:
	await _descend()
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(2)
	var flow: VesselRecoveryFlow = game.journey.recovery
	assert_true(flow.countdown.running,"zero oxygen starts the 60 s countdown")
	flow.countdown.advance(flow.countdown.remaining,0.0)
	assert_true(flow.pending)
	assert_true(flow.committed)
	assert_true(game.journey.at_station(),"recovered at Halcyon")
	assert_eq(pools.oxygen,pools.max_oxygen)
	flow.acknowledge()
	assert_false(flow.pending)
# ---------------------------------------------------------------- hints
func test_the_squeeze_hint_appears_once_near_the_squeeze_and_names_the_two_torpedoes() -> void:
	await _descend()
	game.tutorial._shown.clear()
	game.tutorial._current = ""
	var seen: Array[String] = []
	var bodies: Dictionary = {}
	game.tutorial.message_changed.connect(func(title: String,body: String) -> void:
		seen.append(title)
		bodies[title] = body)
	game.submarine.global_position = DrownedCavesLayout.PASSAGE_END-Vector2(300,0)
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(6)
	assert_has(seen,"Wick / the squeeze")
	assert_string_contains(bodies["Wick / the squeeze"],"two torpedoes")
	assert_string_contains(bodies["Wick / the squeeze"],"long way round is always open")
func test_the_oxygen_hint_states_the_authored_tank_time_once_oxygen_has_fallen() -> void:
	await _descend()
	game.tutorial._shown.clear()
	game.tutorial._current = ""
	var seen: Array[String] = []
	var bodies: Dictionary = {}
	game.tutorial.message_changed.connect(func(title: String,body: String) -> void:
		seen.append(title)
		bodies[title] = body)
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(6)
	assert_does_not_have(seen,"Wick / oxygen is the clock","not before oxygen has fallen")
	assert_eq(pools.restore_snapshot(pools.battery,pools.max_oxygen*0.7),OK)
	await wait_physics_frames(6)
	assert_has(seen,"Wick / oxygen is the clock")
	var minutes: String = "%.0f" % (ChapterJourney.CAVES_RESOURCES.max_oxygen/ChapterJourney.CAVES_RESOURCES.oxygen_drain_per_second/60.0)
	assert_string_contains(bodies["Wick / oxygen is the clock"],"about "+minutes+" minutes")
func test_the_cave_hints_appear_in_the_caves_and_not_in_twilight_at_the_same_spot() -> void:
	_deploy()
	# Clear the other hints out of the way: leaving the start point queues the sonar hint and a depth
	# warning queues the depth hint, and only one hint shows at a time, which would hide a wrongly
	# fired cave hint. A very high rating keeps the depth readout safe at the cave coordinates.
	game.tutorial.complete("movement")
	assert_eq(game.submarine.damage_system.set_maximum_depth_m(5000.0),OK)
	game.tutorial._shown.clear()
	game.tutorial._current = ""
	var seen: Array[String] = []
	game.tutorial.message_changed.connect(func(title: String,_body: String) -> void: seen.append(title))
	game.submarine.global_position = DrownedCavesLayout.PASSAGE_END
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(6)
	assert_true(game.journey.active())
	assert_does_not_have(seen,"Wick / the squeeze","Twilight at the same coordinates shows no cave hint")
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	game.tutorial._current = ""
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(pools.restore_snapshot(pools.battery,pools.max_oxygen*0.5),OK)
	await wait_physics_frames(6)
	assert_does_not_have(seen,"Wick / oxygen is the clock","Twilight never shows the cave oxygen hint")
	# Positive control: the same spot and hint slot, in the caves phase.
	game.journey.prepare({"phase":"caves","commissioned":true})
	game.upgrades.reapply()
	game.tutorial._current = ""
	game.submarine.global_position = DrownedCavesLayout.PASSAGE_END
	await wait_physics_frames(6)
	assert_has(seen,"Wick / the squeeze")
