extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta052-review-%d.json" % Time.get_ticks_usec()
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
func _at(at: Vector2) -> void:
	game.submarine.global_position = at
	game.submarine.velocity = Vector2.ZERO
func test_rounded_contours_triangulate_and_main_route_has_continuous_unblasted_hull_clearance() -> void:
	for polygon: PackedVector2Array in SunlitSurveyData.terrain(): assert_false(Geometry2D.triangulate_polygon(polygon).is_empty())
	var rounded: PackedVector2Array = SunlitSurveyData.rounded_contour(SunlitSurveyData._rect(Rect2(1000,400,300,200)))
	assert_gt(rounded.size(),4)
	var collision: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.collision_mask = 1
	var previous: Vector2 = SunlitSurveyData.SPAWN
	for at: Vector2 in SunlitSurveyData.MAIN_ROUTE:
		query.transform = Transform2D(0,previous)*collision.transform
		query.motion = at-previous
		assert_gte(game.submarine.get_world_2d().direct_space_state.cast_motion(query)[0],0.99999,str(previous," → ",at))
		previous = at
	assert_true(game.excavation.snapshot().is_empty())
func test_roof_and_baffles_prevent_drive_by_sonar_but_inside_angle_reveals_on_wavefront() -> void:
	_at(Vector2(20800,280))
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(4)
	assert_false(game.chapter.buoy.visible,"Roof occludes a nearby pulse.")
	_at(Vector2(19750,600))
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(4)
	assert_false(game.chapter.buoy.visible,"The entrance cannot skip the range and baffles.")
	_at(Vector2(20300,710))
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(4)
	assert_false(game.chapter.buoy.visible,"Even within receiver range the floor baffle occludes the buoy.")
	_at(Vector2(20600,560))
	var bus: AcousticBus = game.get_node("AcousticBus") as AcousticBus
	var count: int = bus.history_count()
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(0.3)
	assert_false(game.chapter.buoy.visible)
	game.submarine.sonar.advance(0.1)
	assert_true(game.chapter.buoy.visible)
	assert_eq(bus.history_count(),count+1,"No return emissions enter history.")
	assert_eq(game.submarine.resource_system.battery,84.0)
	var obstruction: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(20,80)
	shape.shape = rectangle
	obstruction.add_child(shape)
	game.add_child(obstruction)
	obstruction.global_position = Vector2(20760,620)
	await wait_physics_frames(2)
	_at(Vector2(20700,620))
	assert_false(game.submarine.scanner._in_range(SunlitShallowsData.BUOY),"Discovery cannot enable scanning through intervening terrain.")
	obstruction.queue_free()
	await wait_physics_frames(2)
	assert_true(game.submarine.scanner._in_range(SunlitShallowsData.BUOY))
func test_prior_buoy_discovery_stays_known_after_new_shelter_and_does_not_replay() -> void:
	game.discoveries.discover(SunlitShallowsData.POI,&"test/old-record")
	game.chapter._refresh()
	watch_signals(game.discoveries)
	game.chapter._activate(false)
	game.chapter._activate(true)
	assert_true(game.chapter.buoy.visible)
	assert_signal_not_emitted(game.discoveries,"point_discovered")
func test_old_map_overlook_and_predator_are_hidden_without_erasing_legacy_progress() -> void:
	game.discoveries.discover(&"shelf-overlook",&"test/legacy")
	game.exploration_map.refresh()
	assert_false(game.exploration_map.canvas.points.any(func(point: PointOfInterest) -> bool: return point.stable_id==&"shelf-overlook"))
	assert_eq(game.discoveries.state_of(&"shelf-overlook"),DiscoveryRegistry.State.DISCOVERED)
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(2)
	assert_false(game.predator.is_visible_in_tree())
	assert_true(game.predator._suspended)
	assert_false(game.creature._suspended,"Canonical observer must actually swim.")
	game.submarine.set_simulation_enabled(false)
	game.chapter._activate(false)
	assert_true(game.exploration_map.canvas.points.any(func(point: PointOfInterest) -> bool: return point.stable_id==&"shelf-overlook"))
func test_all_destructible_materials_are_warm_and_protected_geology_keeps_its_material() -> void:
	var dressing: SunlitRockDressing = game.chapter.dressing.rocks
	for rock: DestructibleRock in [game.chapter.guide.layout.gate]+game.chapter.guide.layout.tunnels:
		assert_eq(rock.material,dressing._fractured)
	assert_ne(dressing._fractured,dressing._paint)
	assert_eq(float(dressing._fractured.get_shader_parameter("friable")),1.0)
func test_radio_source_portraits_follow_explicit_speakers_and_keep_text_and_focus() -> void:
	assert_eq(RadioPortraits.identity("Wick / Mara’s buoy"),&"mara")
	assert_eq(RadioPortraits.identity("Crane"),&"crane")
	assert_eq(RadioPortraits.identity("Okafor"),&"okafor")
	assert_eq(RadioPortraits.identity("Wick"),&"wick")
	var radio: RadioNotifications = game.revision.ui.notifications
	radio.enqueue("sunlit-map-guidance","An ordinary field message.","Okafor")
	assert_not_null(radio.portrait.texture)
	assert_true(radio.speaker.text.contains("Okafor"))
	radio.enqueue("sunlit-bloom-response","Specimen secured.","Crane")
	radio.expanded = true
	radio.next_message()
	assert_true(radio.speaker.text.contains("Crane"))
	assert_eq((radio.portrait.texture as AtlasTexture).region,RadioPortraits.portrait("Crane").region)
	assert_eq(radio.portrait.focus_mode,Control.FOCUS_NONE)
	game.submarine.set_simulation_enabled(true)
	for scale: String in ["standard","large"]:
		var prefs: Dictionary = SettingsStore.default_accessibility()
		prefs.ui_scale = scale
		prefs.high_contrast = scale=="large"
		game.settings.set_accessibility(prefs)
		await wait_process_frames(12)
		radio._process(0)
		var deck: Control = game.hud.get_node("%InstrumentDeck") as Control
		assert_gte(radio.panel.get_global_rect().position.y,deck.get_global_rect().end.y+7.0)
		assert_lte(radio.panel.get_global_rect().end.y,600.0)
	game.submarine.set_simulation_enabled(false)
func test_animation_is_propulsion_driven_and_stops_with_pause_and_reduced_motion() -> void:
	var body: AcousticCreature = game.chapter.guide.fauna[0]
	var paint: MarineAnimalPaint
	for child: Node in body.get_children():
		if child is MarineAnimalPaint: paint = child
	body.set_suspended(false)
	body.velocity = Vector2(40,30)
	paint._process(0.5)
	assert_gt(paint.phase,0.0)
	assert_gt(paint.sprite.rotation,0.0)
	var phase: float = paint.phase
	body.set_suspended(true)
	paint._process(2)
	assert_eq(paint.phase,phase)
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.reduced_motion = true
	game.settings.set_accessibility(prefs)
	assert_eq(float(paint._swim.get_shader_parameter("amount")),0.0)
func test_larger_hammerhead_has_warning_bounded_pursuit_and_rate_consistent_damage_cooldown() -> void:
	var rules: PredatorProfile = preload("res://resources/creatures/sunlit_hammerhead.tres")
	assert_true(rules.is_valid())
	assert_gt(rules.navigation_bounds.size.y,170.0)
	assert_gt(rules.proximity_alert_radius,220.0)
	assert_gt(rules.pursuit_speed,240.0)
	for rate: int in [30,60,120]:
		var state: PredatorState = PredatorState.new()
		state.configure(rules)
		state.set_target(Vector2(18880,700),true,true)
		state.advance(0,Vector2(18800,910))
		assert_eq(state.phase,PredatorState.Phase.ALERT)
		assert_eq(state.contact_cost(30,true),0.0)
		for step: int in range(rate*3): state.advance(1.0/rate,Vector2(18800,910))
		assert_eq(state.phase,PredatorState.Phase.PURSUE)
		assert_eq(state.contact_cost(30,true),6.0)
		assert_eq(state.contact_cost(30,true),0.0)
		state.set_target(Vector2(18880,400),true,true)
		state.advance(1.0/rate,Vector2(18800,910))
		assert_eq(state.phase,PredatorState.Phase.DISENGAGE)
func test_old_obstructed_search_pose_recovers_at_base_without_resetting_resources_or_evidence() -> void:
	var saved: Dictionary = game.saves.snapshot()
	saved.player.position = [20000,480]
	saved.player.hull = 74.0
	saved.player.battery = 62.0
	saved.player.oxygen = 81.0
	var progress: Dictionary = saved.progress.duplicate(true)
	assert_eq(game.saves.store.write_checkpoint(saved),OK)
	assert_eq(game.saves.setup(game,path+".expedition.json"),OK)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.global_position,SunlitSurveyData.SPAWN)
	assert_eq(game.submarine.hull_system.hull,74.0)
	assert_eq(game.submarine.resource_system.battery,62.0)
	assert_eq(game.submarine.resource_system.oxygen,81.0)
	assert_eq(game.saves._state.progress,progress)
