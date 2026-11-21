extends GutTest
## DC-3: the sentinel payoff. A released, living sentinel leaves optional guide lights along the
## always-open long route; a captured, lost or later-killed one leaves one text line and no lights.
## Nothing here is hostile and nothing is saved (availability is derived from story flags).
var game: ShelfPrototype
var path: String
var view: SubViewport
func before_each() -> void:
	view = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	path = "user://dc3-%d.json" % Time.get_ticks_usec()
	game = await _new_game()
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func _new_game() -> ShelfPrototype:
	var scene: ShelfPrototype = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	scene.settings_path = path
	scene.expedition_path = path+".expedition.json"
	view.add_child(scene)
	await wait_physics_frames(3)
	return scene
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
## Twilight evidence, the chosen sentinel outcome, the tether return, the claimed debrief and the descent.
func _descend(choice: StringName,then_killed: bool = false) -> void:
	_deploy()
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]: await _study(id)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.story.apply_choice(choice),OK)
	if then_killed: assert_eq(game.story.set_flag(&"zone2-released-sentinel-lost"),OK)
	game.revision.ui.radio_page.hide()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.missions.claim(TwilightShelfData.MISSION),OK)
	# The real descent, including its arrival notices.
	game.journey.caves_entry_enabled = true
	assert_true(game.journey.caves_entry_available())
	await game.journey.descend_caves()
	# Resume outside the camera_settled emission: a test that ends inside it frees the scene mid-signal.
	await wait_physics_frames(2)
	assert_true(game.journey.caves())
func _radio(id: String) -> String:
	return String(game.revision.ui.notifications.texts.get(id,""))
func _on_route(point: Vector2,route: PackedVector2Array) -> bool:
	for index: int in range(route.size()-1):
		if route[index].distance_to(route[index+1])<0.001: continue
		if Geometry2D.get_closest_point_to_segment(point,route[index],route[index+1]).distance_to(point)<1.0: return true
	return false
# ---------------------------------------------------------------- authored data
func test_the_lights_are_derived_from_the_always_open_long_route() -> void:
	var lights: PackedVector2Array = DrownedCavesGuide.waypoints()
	var route: PackedVector2Array = DrownedCavesLayout.long_route()
	assert_between(lights.size(),6,16,"a trail, not a carpet")
	for index: int in range(lights.size()):
		assert_true(_on_route(lights[index],route),"light %d lies on the long route" % index)
		if index>0: assert_lte(lights[index].distance_to(lights[index-1]),DrownedCavesGuide.SPACING*1.001,"no gap longer than the spacing")
	assert_lt(lights[-1].distance_to(DrownedCavesLayout.FAR_CHAMBER),DrownedCavesGuide.SPACING*0.3,"the trail ends in the far chamber")
	assert_lt(lights[0].distance_to(DrownedCavesLayout.SPAWN),DrownedCavesGuide.SPACING*1.001+450.0,"the first light is near the anchor")
	var plug: Rect2 = (DrownedCavesLayout.TUNNELS.systems[0] as TunnelProfile).world_gate().grow(60.0)
	for light: Vector2 in lights: assert_false(plug.has_point(light),"no light leads into the plug")
func test_every_variant_has_authored_text_and_none_is_hostile() -> void:
	var forbidden: Array[String] = ["attack","hostile","hunt","weapon","fire","fight","enemy","chase","kill"]
	assert_eq(DrownedCavesGuide.TEXT.size(),4)
	for key: StringName in DrownedCavesGuide.TEXT:
		var text: String = String(DrownedCavesGuide.TEXT[key]).to_lower()
		assert_false(text.is_empty())
		for word: String in forbidden: assert_false(text.contains(word),"%s contains %s" % [key,word])
	assert_eq(DrownedCavesGuide.variant(game.story),&"","no sentinel decision yet")
	assert_false(DrownedCavesGuide.available(game.story))
	assert_eq(DrownedCavesGuide.reaction(game.story),"")
# ---------------------------------------------------------------- each outcome
func test_a_released_living_sentinel_lights_the_way_and_says_so_in_text() -> void:
	await _descend(TwilightShelfData.RELEASE)
	assert_eq(DrownedCavesGuide.variant(game.story),&"guide")
	assert_true(game.journey.caves_guide.visible)
	assert_eq(game.journey.caves_guide.lights(),DrownedCavesGuide.waypoints())
	assert_eq(_radio("caves-sentinel"),DrownedCavesGuide.TEXT[&"guide"])
	assert_string_contains(game.journey.caves_guidance(),"lights")
	assert_string_contains(game.journey.caves_guidance(),"or not","following is optional")
func test_a_captured_sentinel_leaves_no_lights_and_one_quiet_line() -> void:
	await _descend(TwilightShelfData.CAPTURE)
	assert_true(game.story.has_flag(&"zone2-wardens-wary"))
	assert_eq(DrownedCavesGuide.variant(game.story),&"captured")
	assert_false(game.journey.caves_guide.visible)
	assert_eq(_radio("caves-sentinel"),DrownedCavesGuide.TEXT[&"captured"])
	assert_string_contains(game.journey.caves_guidance(),"Follow the passage east")
func test_a_lost_sentinel_leaves_no_lights_and_one_line() -> void:
	await _descend(TwilightShelfData.LOST)
	assert_eq(DrownedCavesGuide.variant(game.story),&"lost")
	assert_false(game.journey.caves_guide.visible)
	assert_eq(_radio("caves-sentinel"),DrownedCavesGuide.TEXT[&"lost"])
func test_a_released_sentinel_that_was_later_killed_leaves_no_guide() -> void:
	await _descend(TwilightShelfData.RELEASE,true)
	assert_true(game.story.has_flag(&"zone2-future-guide"),"the guide flag stays; the animal is gone")
	assert_eq(DrownedCavesGuide.variant(game.story),&"guide_lost")
	assert_false(game.journey.caves_guide.visible)
	assert_eq(_radio("caves-sentinel"),DrownedCavesGuide.TEXT[&"guide_lost"])
# ---------------------------------------------------------------- behaviour
func test_the_lights_are_in_open_water_and_the_trail_is_flyable_with_real_collision() -> void:
	await _descend(TwilightShelfData.RELEASE)
	for light: Vector2 in game.journey.caves_guide.lights():
		assert_true(game.saves.position_clear(light,0.0),"a light at %s sits in open water" % light)
	var collision: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var space: PhysicsDirectSpaceState2D = game.submarine.get_world_2d().direct_space_state
	var trail: PackedVector2Array = DrownedCavesLayout.long_route()
	for index: int in range(trail.size()-1):
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = Transform2D(0,trail[index])*collision.transform
		query.motion = trail[index+1]-trail[index]
		query.collision_mask = 1
		query.exclude = [game.submarine.get_rid()]
		assert_true(space.intersect_shape(query).is_empty() and space.cast_motion(query)[0]>=1.0,"the trail leg %d is open" % index)
func test_the_lights_exist_only_in_the_caves_and_return_after_a_round_trip() -> void:
	await _descend(TwilightShelfData.RELEASE)
	assert_true(game.journey.caves_guide.visible)
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_false(game.journey.caves_guide.visible,"hidden at Halcyon")
	assert_eq(game.saves.transfer_chapter("twilight",false),OK)
	assert_false(game.journey.caves_guide.visible,"hidden in Twilight")
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_eq(game.saves.transfer_chapter("caves",true),OK)
	assert_true(game.journey.caves_guide.visible,"back in the caves")
func test_a_fresh_launch_that_continues_in_the_caves_shows_the_lights() -> void:
	await _descend(TwilightShelfData.RELEASE)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.save_current(),OK)
	var reloaded: ShelfPrototype = await _new_game()
	assert_true(reloaded.saves.has_checkpoint())
	assert_eq(reloaded.saves.continue_expedition(),OK)
	assert_true(reloaded.journey.caves())
	assert_true(reloaded.story.has_flag(&"zone2-future-guide"))
	assert_true(reloaded.journey.caves_guide.visible)
	assert_string_contains(reloaded.journey.caves_guidance(),"lights")
## Continue prepares the journey phase and restores the story afterwards, so the guide is refreshed
## when the checkpoint is back rather than trusting the story as it was at prepare time. (A fresh
## scene loads its saved story at launch, so today both orders agree; this keeps them from drifting.)
func test_restoring_a_checkpoint_refreshes_the_guide_from_the_story() -> void:
	await _descend(TwilightShelfData.RELEASE)
	assert_true(game.saves.checkpoint_restored.is_connected(game.journey.refresh_caves_guide))
	game.journey.caves_guide.set_enabled(false)
	assert_false(game.journey.caves_guide.visible)
	game.saves.checkpoint_restored.emit()
	assert_true(game.journey.caves_guide.visible,"the restored story says the animal lives")
	game.journey.caves_guide.set_enabled(true)
	game.saves.checkpoint_restored.emit()
	assert_true(game.journey.caves_guide.visible)
func test_there_is_no_hostility_and_no_new_saved_state_in_any_variant() -> void:
	await _descend(TwilightShelfData.CAPTURE)
	game.submarine.set_simulation_enabled(false)
	assert_false(game.journey.hunt.enabled,"no Warden or Stalker hunt in the caves")
	assert_false(game.journey.habitat.enabled)
	assert_eq(game.submarine.hull_system.hull,game.submarine.hull_system.max_hull)
	game.submarine.global_position = DrownedCavesLayout.SPAWN
	assert_eq(game.saves.save_current(),OK)
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.saves.store.path))
	assert_eq(int(written.schema_version),ExpeditionSchema.VERSION)
	assert_eq(written.size(),12,"still twelve top-level fields")
	assert_eq(written.journey,{"phase":"caves","commissioned":true},"the journey stays two fields")
	assert_eq(ExpeditionSchema.decode(written).error,OK)
# ---------------------------------------------------------------- accessibility
func test_the_lights_swell_slowly_by_default_and_hold_steady_for_reduced_motion_or_flashing() -> void:
	await _descend(TwilightShelfData.RELEASE)
	var guide: DrownedCavesGuide = game.journey.caves_guide
	assert_false(guide.is_steady())
	var low: float = 2.0
	var high: float = 0.0
	for sample: int in range(40):
		await wait_physics_frames(3)
		low = minf(low,guide.modulate.a)
		high = maxf(high,guide.modulate.a)
	assert_gt(high-low,0.01,"a slow swell by default")
	assert_gte(low,0.7,"never dims below 70%")
	assert_lte(high,1.0)
	for key: String in ["reduced_motion","reduced_flashing"]:
		var settings: Dictionary = game.settings.snapshot().accessibility.duplicate(true)
		settings[key] = true
		assert_eq(game.settings.set_accessibility(settings),OK)
		assert_true(guide.is_steady(),key)
		for sample: int in range(5):
			await wait_physics_frames(3)
			assert_eq(guide.modulate.a,1.0,"%s holds the lights steady" % key)
		settings[key] = false
		assert_eq(game.settings.set_accessibility(settings),OK)
	assert_false(guide.is_steady())
