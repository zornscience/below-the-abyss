extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var viewport: SubViewport
var path: String

class PrimaryFailureStore extends ExpeditionStore:
	var fail_primary_once: bool = true
	func _atomic_write(destination: String,text: String) -> Error:
		if destination==path and fail_primary_once:
			fail_primary_once = false
			return ERR_CANT_CREATE
		return super._atomic_write(destination,text)

func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://bta051-%d.json" % Time.get_ticks_usec()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	game = _create()
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_process_frames(5)

func _create() -> ShelfPrototype:
	var node: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	node.settings_path = path
	node.expedition_path = path+".expedition.json"
	viewport.add_child(node)
	return node

func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected", ".invalid"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)

func _query(at: Vector2) -> PhysicsShapeQueryParameters2D:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var collision: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	query.shape = collision.shape
	query.transform = Transform2D(0,at)*collision.transform
	query.collision_mask = 1
	return query

func _clear(from: Vector2,to: Vector2) -> bool:
	var query: PhysicsShapeQueryParameters2D = _query(from)
	query.motion = to-from
	var space: PhysicsDirectSpaceState2D = game.submarine.get_world_2d().direct_space_state
	return space.intersect_shape(query).is_empty() and space.cast_motion(query)[0]>=0.99999

func _at(at: Vector2) -> void:
	game.submarine.global_position = at
	game.submarine.velocity = Vector2.ZERO
	game.submarine.damage_system.advance(0,game.region.depth_at_world(at),game.submarine.hull_system)

func _identify(id: StringName) -> void:
	var definition: ScanDefinition = game.research.definition(id)
	_at(definition.position)
	game.submarine.sonar.advance(5)
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(3)
	assert_eq(game.discoveries.state_of(definition.required_poi_id),DiscoveryRegistry.State.DISCOVERED)

func _scan(id: StringName) -> void:
	_identify(id)
	game.submarine.scanner.set_suspended(false)
	assert_eq(game.submarine.scanner.request_scan(id),OK)
	game.submarine.scanner.advance(game.research.definition(id).duration)
	assert_true(game.research.is_completed(id))

func test_authored_main_route_is_shallow_and_whole_hull_clear_after_three_blasts() -> void:
	assert_eq(game.region.camera_bounds,SunlitSurveyData.CAMERA)
	assert_true(game.saves.position_clear(game.region.spawn.global_position,0))
	assert_false(_clear(Vector2(4300,480),Vector2(4900,480)))
	assert_false(game.chapter.guide.layout.passage_clear())
	for x: float in [4550.0,4690.0,4830.0]: assert_gt(game.excavation.excavate(Vector2(x,480),150),0)
	await wait_physics_frames(3)
	assert_true(game.chapter.guide.layout.passage_clear())
	var previous: Vector2 = game.region.spawn.global_position
	for point: Vector2 in SunlitSurveyData.MAIN_ROUTE:
		assert_true(_clear(previous,point),"Whole-hull continuous clearance %s -> %s" % [previous,point])
		assert_lte(game.region.depth_at_world(point),200.0)
		previous = point
	assert_eq(game.discoveries.state_of(SunlitSurveyData.CLEARED),DiscoveryRegistry.State.DISCOVERED)

func test_small_cut_or_blocked_shot_cannot_claim_traversal_but_off_center_hull_opening_counts() -> void:
	game.excavation.excavate(Vector2(4550,480),25)
	assert_false(game.chapter.guide.layout.passage_clear())
	assert_eq(game.discoveries.state_of(SunlitSurveyData.CLEARED),DiscoveryRegistry.State.HIDDEN)
	for x: float in [4550.0,4690.0,4830.0]: game.excavation.excavate(Vector2(x,650),150)
	await wait_physics_frames(3)
	assert_true(game.chapter.guide.layout.passage_clear())
	assert_true(_clear(Vector2(4300,650),Vector2(4900,650)))
	assert_eq(game.discoveries.state_of(SunlitSurveyData.CLEARED),DiscoveryRegistry.State.DISCOVERED)

func test_three_real_projectiles_open_passage_without_harming_wildlife_or_protected_objects() -> void:
	_at(Vector2(4300,480))
	game.submarine.facing = 1
	game.submarine.set_simulation_enabled(true)
	watch_signals(game.torpedoes)
	for shot: int in range(3):
		assert_eq(game.torpedoes.request_fire(),OK)
		await wait_physics_frames(90)
		assert_eq(game.chapter.guide.layout.passage_clear(),shot==2)
	game.submarine.set_simulation_enabled(false)
	assert_true(game.chapter.guide.layout.passage_clear())
	assert_signal_emit_count(game.torpedoes,"detonated",3)
	assert_eq(game.torpedoes.ammunition,7)
	assert_false(game.creature._destroyed)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_true(game.excavation.snapshot().any(func(cut: Dictionary) -> bool: return cut.rock=="sunlit-cavein"))
	for cut: Dictionary in game.excavation.snapshot(): assert_eq(cut.rock,"sunlit-cavein","Inactive prototype rocks cannot be excavated through the canonical scene.")

func test_empty_ammunition_preserves_a_clear_return_and_deliberate_station_rearms() -> void:
	_at(Vector2(4300,480))
	game.torpedoes.restore_ammunition(0)
	game.submarine.set_simulation_enabled(true)
	assert_eq(game.torpedoes.request_fire(),ERR_UNAVAILABLE)
	game.submarine.set_simulation_enabled(false)
	assert_false(game.chapter.guide.layout.passage_clear())
	assert_true(_clear(Vector2(4300,480),Vector2(1280,480)))
	assert_true(_clear(Vector2(1280,480),Vector2(420,480)))
	_at(game.region.spawn.global_position)
	assert_eq(game.open_station(),OK)
	assert_eq(game.torpedoes.ammunition,10)
	assert_false(game.chapter.guide.layout.passage_clear())

func test_hidden_buoy_has_no_sprite_prompt_map_marker_or_collision_until_wavefront() -> void:
	_at(SunlitSurveyData.BUOY)
	game.chapter._refresh()
	assert_false(game.chapter.buoy.visible)
	assert_false(game.submarine.scanner.eligible(SunlitShallowsData.BUOY))
	assert_true(game.chapter.buoy.find_children("*","CollisionObject2D",true,false).is_empty())
	game.open_map()
	assert_false(game.exploration_map.canvas.points.any(func(point: PointOfInterest) -> bool: return point.stable_id==SunlitShallowsData.POI))
	assert_ne(game.exploration_map.canvas.reported_position,SunlitSurveyData.BUOY)
	game.close_map()
	_at(SunlitSurveyData.BUOY-Vector2(1000,0))
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(5)
	assert_false(game.chapter.buoy.visible,"Out-of-range ping cannot reveal.")
	_at(SunlitSurveyData.BUOY-Vector2(400,0))
	assert_eq(game.submarine.sonar.request_ping(),OK)
	game.submarine.sonar.advance(0.3)
	assert_false(game.chapter.buoy.visible,"Receipt is not wavefront arrival.")
	game.submarine.sonar.advance(0.5)
	assert_true(game.chapter.buoy.visible)
	game.submarine.sonar.advance(30)
	assert_true(game.chapter.buoy.visible,"Permanent first echo outlives temporary brackets.")

func test_failed_sonar_energy_cost_never_reveals_or_starts_cooldown() -> void:
	_at(SunlitSurveyData.BUOY)
	game.submarine.resource_system.consume_battery(100)
	assert_eq(game.submarine.sonar.request_ping(),ERR_UNAVAILABLE)
	assert_eq(game.submarine.sonar.cooldown_remaining(),0.0)
	game.submarine.sonar.advance(10)
	assert_false(game.chapter.buoy.visible)
	assert_false(game.submarine.scanner.eligible(SunlitShallowsData.BUOY))

func test_first_science_scan_commits_xp_and_record_atomically_and_repeat_only_reviews() -> void:
	var before: int = game.story.resonance()
	_scan(&"sunlit-silver-shoal")
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),20)
	assert_eq(game.story.resonance(),before)
	assert_true(game.chapter.guide.review_nearby())
	assert_eq(game.research.complete_scan(&"sunlit-silver-shoal"),ERR_ALREADY_EXISTS)
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),20)
	var disk: Dictionary = game.saves.store.read_file(game.expedition_path).data
	assert_eq(disk.prototype.campaign.science.credited,["sunlit-silver-shoal"])
	assert_true("sunlit-silver-shoal" in disk.progress.research)
	assert_eq(disk.schema_version,ExpeditionSchema.VERSION)

func test_failed_scan_write_has_no_record_xp_signal_or_popup() -> void:
	_identify(&"sunlit-mineral-terrace")
	var bytes: String = FileAccess.get_file_as_string(game.expedition_path)
	game.saves.store._writable = false
	watch_signals(game.research)
	game.submarine.scanner.set_suspended(false)
	assert_eq(game.submarine.scanner.request_scan(&"sunlit-mineral-terrace"),OK)
	game.submarine.scanner.advance(6)
	assert_false(game.research.is_completed(&"sunlit-mineral-terrace"))
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),0)
	assert_signal_not_emitted(game.research,"scan_completed")
	assert_true(game.chapter.guide.popup._queue.is_empty())
	assert_eq(FileAccess.get_file_as_string(game.expedition_path),bytes)

func test_clearance_xp_and_hidden_buoy_discovery_survive_restart_reload_and_no_signal_replay() -> void:
	for x: float in [4550.0,4690.0,4830.0]: game.excavation.excavate(Vector2(x,480),150)
	_scan(&"sunlit-silver-shoal")
	_identify(SunlitShallowsData.BUOY)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.save_current(),OK)
	var science: Dictionary = game.revision.campaign.science.duplicate(true)
	game.restart_route()
	assert_eq(game.revision.campaign.science,science)
	assert_true(game.chapter.guide.layout.passage_clear())
	game.queue_free()
	await wait_process_frames(4)
	game = _create()
	watch_signals(game.research)
	game.chapter.start()
	await wait_process_frames(5)
	assert_true(game.chapter.buoy.visible)
	assert_true(game.chapter.guide.layout.passage_clear())
	assert_eq(game.revision.campaign.science,science)
	assert_signal_not_emitted(game.research,"scan_completed")
	assert_true(game.chapter.guide.popup._queue.is_empty())

func test_real_depth_mapping_warns_then_damages_and_ascent_stops_damage_at_all_rates() -> void:
	for rating: float in [300.0,500.0]:
		var remaining: Array[float] = []
		for rate: int in [30,60,120]:
			game.submarine.hull_system.restore_snapshot(100)
			game.submarine.damage_system.configure(game.submarine.damage_system.configuration)
			game.submarine.damage_system.set_maximum_depth_m(rating)
			var position_in_shaft: Vector2 = Vector2(14000,(rating+20)/0.25)
			assert_true(SunlitSurveyData.VENT.has_point(position_in_shaft))
			var depth: float = game.region.depth_at_world(position_in_shaft)
			for step: int in range(rate*4): game.submarine.damage_system.advance(1.0/rate,depth,game.submarine.hull_system)
			assert_eq(game.submarine.damage_system.warning_state,SubmarineDamageSystem.WarningState.EXCEEDED)
			assert_lt(game.submarine.hull_system.hull,100.0)
			var damaged: float = game.submarine.hull_system.hull
			for step: int in range(rate*2): game.submarine.damage_system.advance(1.0/rate,200,game.submarine.hull_system)
			assert_eq(game.submarine.hull_system.hull,damaged)
			assert_eq(game.submarine.damage_system.warning_state,SubmarineDamageSystem.WarningState.SAFE)
			remaining.append(damaged)
		assert_almost_eq(remaining[0],remaining[1],0.00001)
		assert_almost_eq(remaining[0],remaining[2],0.00001)
	assert_true(_clear(Vector2(14000,2400),Vector2(14000,480)),"The optional shaft has a continuous ascent path.")

func test_school_habitats_avoid_solids_and_use_one_batch_per_population() -> void:
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(4)
	game.submarine.set_simulation_enabled(false)
	for school: AmbientFishSchool in game.chapter.guide.schools:
		assert_true(school._habitat_clear,String(school.school_id))
		assert_gte(school.model.positions.size(),5)
		assert_lte(school.model.positions.size(),12)
		assert_eq(school._batch.multimesh.instance_count,school.configuration.population)
		assert_true(school.find_children("*","CollisionObject2D",true,false).is_empty())
	for animal: AcousticCreature in game.extension.wildlife: assert_true(animal._suspended,"Off-region prototype AI stays suspended during canonical piloting.")

func test_popup_is_nonblocking_bounded_and_yields_to_pressure_radio_and_pause() -> void:
	_scan(&"sunlit-silver-shoal")
	var popup: ScientificDiscoveryPopup = game.chapter.guide.popup
	assert_eq(popup.focus_mode,Control.FOCUS_NONE)
	assert_eq(popup.mouse_filter,Control.MOUSE_FILTER_IGNORE)
	game.settings.set_onboarding({"enabled":false,"seen":[]})
	game.tutorial_card.hide()
	game.revision.ui.notifications.collapse()
	game.revision.ui.notifications._remaining = 0
	game.revision.ui.notifications.selected = ""
	game.submarine.set_simulation_enabled(true)
	popup._process(0.1)
	assert_not_null(popup.image.texture)
	assert_true(popup.caption.text.contains("20 RESEARCH XP"))
	var remaining: float = popup.remaining
	game.submarine.set_simulation_enabled(false)
	popup._process(2)
	assert_eq(popup.remaining,remaining)
	assert_false(popup.visible)
	game.submarine.damage_system.advance(0,500,game.submarine.hull_system)
	game.submarine.set_simulation_enabled(true)
	popup._process(1)
	assert_false(popup.visible)
	assert_eq(popup.remaining,remaining)

func test_map_has_charted_unknown_and_reported_layers_and_focusable_zoom_controls() -> void:
	# Old prototype discoveries remain stored, but cannot become canonical wreck markers.
	assert_eq(game.discoveries.discover(&"lost-expedition-wreck",&"legacy-import"),OK)
	assert_eq(game.discoveries.state_of(&"lost-expedition-wreck"),DiscoveryRegistry.State.DISCOVERED)
	game.open_map()
	var canvas: ExplorationMapCanvas = game.exploration_map.canvas
	assert_true(canvas.survey_enabled)
	assert_true(canvas.has_report)
	assert_false(canvas.points.any(func(point: PointOfInterest) -> bool: return point.stable_id==&"lost-expedition-wreck"))
	assert_eq(canvas.charted.size(),1)
	assert_false(canvas.survey_polygons.is_empty())
	assert_eq(canvas.player_direction,game.submarine.facing_direction())
	assert_eq(game.exploration_map.survey_controls.size(),5)
	game.exploration_map._navigate(1)
	assert_eq(canvas.zoom,2.0)
	var center: float = canvas.center.x
	var edge: float = canvas._view().position.x
	game.exploration_map._navigate(2)
	assert_gt(canvas.center.x,center)
	assert_gt(canvas._view().position.x,edge,"First east pan must move the actual clamped view.")
	game.exploration_map._navigate(0)
	assert_eq(canvas.center,canvas.player_position)
	assert_false(canvas.points.any(func(point: PointOfInterest) -> bool: return point.stable_id==SunlitShallowsData.POI))

func test_small_large_text_ui_fits_and_muting_never_hides_field_information() -> void:
	viewport.size = Vector2i(800,600)
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "large"
	prefs.high_contrast = true
	prefs.reduced_motion = true
	prefs.reduced_particles = true
	game.settings.set_accessibility(prefs)
	await wait_process_frames(4)
	# Starting/returning to the chapter after Large Text has reparented map content.
	game.chapter._activate(false)
	game.chapter._activate(true)
	var audio: Dictionary = game.settings.snapshot().audio
	audio.muted = true
	game.settings.set_audio(audio)
	_at(Vector2(4300,480))
	game.submarine.set_simulation_enabled(true)
	game.chapter.guide._physics_process(0.1)
	assert_true(game.revision.ui.notifications.contains_message("sunlit-cavein-guidance"))
	assert_true(game.revision.ui.notifications.texts["sunlit-cavein-guidance"].contains(game.input_context.describe(&"fire_torpedo")))
	game.open_map()
	await wait_process_frames(6)
	for button: Button in game.exploration_map.survey_controls:
		assert_true(button.is_visible_in_tree())
		assert_lte(button.get_global_rect().end.x,800.0)

func test_pressure_radio_takes_priority_once_and_pause_does_not_advance_it() -> void:
	_at(Vector2(14000,1100))
	game.submarine.set_simulation_enabled(true)
	game.chapter.guide._physics_process(0.1)
	assert_eq(game.submarine.damage_system.warning_state,SubmarineDamageSystem.WarningState.APPROACHING)
	assert_eq(game.revision.ui.notifications.selected,"sunlit-pressure-guidance")
	var count: int = game.revision.ui.notifications.pending.size()
	for unused: int in range(60): game.chapter.guide._physics_process(1.0/60.0)
	assert_eq(game.revision.ui.notifications.pending.size(),count)
	game.submarine.set_simulation_enabled(false)
	game.chapter.guide._physics_process(10)
	assert_eq(game.revision.ui.notifications.pending.size(),count)

func test_primary_write_failure_recovers_record_and_xp_together_without_completion_replay() -> void:
	_identify(&"sunlit-silver-shoal")
	var primary: String = FileAccess.get_file_as_string(game.expedition_path)
	var broken: PrimaryFailureStore = PrimaryFailureStore.new()
	broken.path = game.expedition_path
	assert_eq(broken.load_checkpoint().error,OK)
	game.saves.store = broken
	watch_signals(game.research)
	game.submarine.scanner.set_suspended(false)
	assert_eq(game.submarine.scanner.request_scan(&"sunlit-silver-shoal"),OK)
	game.submarine.scanner.advance(5)
	assert_false(game.research.is_completed(&"sunlit-silver-shoal"))
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),0)
	assert_eq(FileAccess.get_file_as_string(game.expedition_path),primary)
	assert_eq(game.saves.recover_backup(),OK)
	assert_eq(game.saves.continue_expedition(),OK)
	for animal: AcousticCreature in game.extension.wildlife:
		assert_false(animal.visible,"Continue must not resurrect prototype visuals inside the canonical region.")
		assert_true(animal._suspended)
	assert_true(game.research.is_completed(&"sunlit-silver-shoal"))
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),20)
	assert_signal_not_emitted(game.research,"scan_completed")
	assert_true(game.chapter.guide.popup._queue.is_empty())

func test_depleted_hull_cannot_replace_safe_checkpoint_and_continue_preserves_science() -> void:
	_scan(&"sunlit-silver-shoal")
	var science: Dictionary = game.revision.campaign.science.duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(game.expedition_path)
	game.submarine.hull_system.apply_damage(100,&"pressure")
	assert_eq(game.submarine.hull_system.hull,0.0)
	assert_false(game.saves.safe_to_save())
	assert_ne(game.saves.save_current(),OK)
	assert_eq(FileAccess.get_file_as_string(game.expedition_path),bytes)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_gt(game.submarine.hull_system.hull,0.0)
	assert_eq(game.revision.campaign.science,science)
	assert_true(game.research.is_completed(&"sunlit-silver-shoal"))

func test_passive_ambient_contacts_cannot_reveal_buoy_startle_schools_or_award_xp() -> void:
	_at(Vector2(14000,1090))
	game.submarine.set_simulation_enabled(true)
	for school: AmbientFishSchool in game.chapter.guide.schools: school.model.startled = 0
	var battery: float = game.submarine.resource_system.battery
	game.chapter.guide.ambient.advance(3)
	game.submarine.passive.advance(3)
	assert_eq(game.submarine.resource_system.battery,battery)
	assert_false(game.chapter.buoy.visible)
	assert_eq(ResearchExperienceData.total(game.revision.campaign.science),0)
	for school: AmbientFishSchool in game.chapter.guide.schools: assert_eq(school.model.startled,0.0)
