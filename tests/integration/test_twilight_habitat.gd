extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta054-%d.json" % Time.get_ticks_usec()
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
	game.submarine.global_position = Vector2(1280,480)
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
func test_habitat_is_scoped_to_deep_region_and_preserves_existing_records() -> void:
	assert_false(game.journey.habitat.enabled)
	for animal: AcousticCreature in game.journey.habitat.fauna:
		assert_true(animal._suspended)
		assert_eq(animal.collision_layer,0)
	_deploy()
	assert_true(game.journey.habitat.enabled)
	assert_eq(game.journey.habitat.vents.size(),2)
	assert_eq(game.journey.habitat.fauna.size(),3)
	var records: Dictionary = game.saves.progress_snapshot()
	game.journey.habitat.reset_session()
	assert_eq(game.saves.progress_snapshot(),records)
func test_hot_plume_applies_bounded_hull_damage_with_clear_feedback_and_pause() -> void:
	_deploy()
	var habitat: TwilightHabitat = game.journey.habitat
	habitat.set_physics_process(false)
	var vent: ThermalVent = habitat.vents[1]
	game.submarine.global_position = vent.to_global(vent.configuration.plume.get_center())
	game.submarine.set_simulation_enabled(true)
	for tick: int in range(12): vent.advance(1)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_eq(vent.model.phase(),ThermalVentState.Phase.ERUPTING)
	for tick: int in range(3): vent.advance(1)
	assert_eq(game.submarine.hull_system.hull,88.0)
	assert_true(String(game.submarine.hull_system.last_damage_source).begins_with("thermal/"))
	assert_true((game.hud.get_node("%ImpactFeedback") as Label).text.contains("HEAT"))
	game.submarine.set_simulation_enabled(false)
	var clock: float = vent.model.clock
	vent.advance(1)
	assert_eq(vent.model.clock,clock)
	assert_eq(game.submarine.hull_system.hull,88.0)
func test_proximity_alone_never_damages_and_safe_corridor_stays_clear() -> void:
	_deploy()
	game.journey.habitat.set_physics_process(false)
	var vent: ThermalVent = game.journey.habitat.vents[1]
	game.submarine.global_position = vent.global_position+Vector2(-45,-650)
	assert_false(vent.exposes(game.submarine.global_position))
	game.submarine.set_simulation_enabled(true)
	for tick: int in range(40): vent.advance(1)
	assert_eq(game.submarine.hull_system.hull,100.0)
	assert_true(game.saves.position_clear(game.submarine.global_position,0))
func test_warning_range_boundaries_and_blocked_thermal_checkpoint() -> void:
	_deploy()
	var vent: ThermalVent = game.journey.habitat.vents[1]
	game.submarine.global_position = vent.to_global(vent.configuration.plume.get_center())
	for tick: int in range(8): vent.model.advance(1,false)
	assert_true(vent.prompt(game.submarine.global_position).contains("Eruption in"))
	assert_false(game.saves.safe_to_save())
	assert_eq(game.saves.save_current(),ERR_UNAVAILABLE)
	assert_eq(vent.prompt(vent.global_position+Vector2(651,0)),"")
	vent.reset_session()
	assert_true(game.saves.safe_to_save())
func test_wildlife_uses_acoustic_bus_once_and_passive_listening_is_silent() -> void:
	_deploy()
	var animal: AcousticCreature = game.journey.habitat.fauna[0]
	var bus: AcousticBus = game.get_node("AcousticBus") as AcousticBus
	game.submarine.global_position = animal.global_position+Vector2(100,0)
	game.submarine.set_simulation_enabled(true)
	watch_signals(animal.receiver)
	var before: int = bus.history_count()
	game.submarine.passive.advance(1)
	assert_eq(bus.history_count(),before)
	assert_eq(game.submarine.sonar.request_ping(&"test/twilight-ping"),OK)
	assert_signal_emit_count(animal.receiver,"event_received",1)
	var battery: float = game.submarine.resource_system.battery
	assert_ne(game.submarine.sonar.request_ping(&"test/twilight-ping"),OK)
	assert_eq(game.submarine.resource_system.battery,battery)
	assert_signal_emit_count(animal.receiver,"event_received",1)
	await wait_physics_frames(3)
	assert_eq(animal.brain.state,CreatureState.State.INVESTIGATE)
	assert_eq(game.submarine.collision_mask & animal.collision_layer,0)
func test_continue_preserves_damage_and_records_but_resets_transient_eruption() -> void:
	_deploy()
	game.submarine.hull_system.restore_snapshot(72)
	assert_eq(game.saves.save_current(),OK)
	var progress: Dictionary = game.saves.progress_snapshot()
	game.journey.habitat.vents[0].model.advance(1,false)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.hull_system.hull,72.0)
	assert_eq(game.saves.progress_snapshot(),progress)
	assert_eq(game.journey.habitat.vents[0].model.clock,0.0)
func test_comfort_modes_keep_warning_legible_without_motion_or_particles() -> void:
	_deploy()
	var prefs: Dictionary = game.settings.snapshot().accessibility
	for key: String in ["reduced_motion","reduced_flashing","reduced_particles","high_contrast"]: prefs[key] = true
	prefs.ui_scale = "large"
	assert_eq(game.settings.set_accessibility(prefs),OK)
	var vent: ThermalVent = game.journey.habitat.vents[1]
	game.submarine.global_position = vent.to_global(vent.configuration.plume.get_center())
	game.submarine.set_simulation_enabled(true)
	for tick: int in range(8): vent.advance(1)
	assert_true(vent.prompt(game.submarine.global_position).contains("Eruption in"))
	vent.advance(NAN)
	assert_eq(vent._visual_clock,0.0)
	assert_false(game.journey.habitat.dressing._snow.visible)
	assert_eq(vent._plume.skew,0.0)
	await wait_process_frames(6)
	assert_gt(game.mission_tracker.title.size.y,0.0)
	assert_gt(game.mission_tracker.detail.size.y,0.0)
	assert_gt(game.mission_tracker.get_global_rect().intersection(game.mission_tracker.title.get_global_rect()).get_area(),0.0)
func test_refit_and_restart_cleanup_do_not_erase_permanent_progress() -> void:
	_deploy()
	var records: Dictionary = game.saves.progress_snapshot()
	var animal: AcousticCreature = game.journey.habitat.fauna[0]
	var receiver: BlastReceiver = animal.get_child(animal.get_child_count()-1) as BlastReceiver
	assert_gt(receiver.apply_blast(&"test/blast",animal.global_position,100,100),0.0)
	assert_true(animal._destroyed)
	game.journey.habitat.reset_session()
	assert_false(animal._destroyed)
	assert_almost_eq(receiver.health,40.0,0.00001)
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_false(game.journey.habitat.enabled)
	for vent: ThermalVent in game.journey.habitat.vents: assert_eq(vent._solid.collision_layer,0)
	assert_eq(game.saves.progress_snapshot(),records)
func test_jet_boundaries_and_terrain_occlusion_are_conservative() -> void:
	_deploy()
	var vent: ThermalVent = game.journey.habitat.vents[1]
	assert_false(vent.exposes(Vector2(NAN,0)))
	assert_false(vent.exposes(vent.global_position,INF))
	assert_true(vent.exposes(vent.to_global(Vector2(-168,-400))))
	assert_false(vent.exposes(vent.to_global(Vector2(-168.01,-400))))
	assert_false(vent.exposes(vent.to_global(Vector2(78,-400))))
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	var collision: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(250,20)
	collision.shape = box
	wall.add_child(collision)
	game.region.add_child(wall)
	wall.global_position = vent.to_global(Vector2(-45,-420))
	await wait_physics_frames(2)
	assert_false(vent.exposes(vent.to_global(Vector2(-45,-500))))
func test_thermal_depletion_clamps_and_destruction_emits_once() -> void:
	_deploy()
	game.journey.habitat.set_physics_process(false)
	var vent: ThermalVent = game.journey.habitat.vents[1]
	game.submarine.global_position = vent.to_global(vent.configuration.plume.get_center())
	game.submarine.hull_system.restore_snapshot(5)
	watch_signals(game.submarine.hull_system)
	game.submarine.set_simulation_enabled(true)
	for tick: int in range(15): vent.advance(1)
	assert_eq(game.submarine.hull_system.hull,0.0)
	assert_signal_emit_count(game.submarine.hull_system,"vessel_destroyed",1)
func test_historical_deep_pose_inside_new_chimney_uses_existing_safe_fallback() -> void:
	_deploy()
	assert_eq(game.saves.save_current(),OK)
	var saved: Dictionary = game.saves._state.duplicate(true)
	var at: Vector2 = game.journey.habitat.vents[0].global_position+Vector2(-43,-150)
	saved.player.position = [at.x,at.y]
	saved.player.hull = 61.0
	saved.player.battery = 62.0
	assert_eq(game.saves.store.write_checkpoint(saved),OK)
	game.saves._state = saved
	await wait_physics_frames(2)
	assert_false(game.saves.position_clear(at,0))
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq(game.submarine.global_position,TwilightShelfLayout.SPAWN)
	assert_eq(game.submarine.hull_system.hull,61.0)
	assert_eq(game.submarine.resource_system.battery,62.0)

func test_both_canonical_regions_hide_prototype_ridges_and_prototype_restores_them() -> void:
	var atmosphere: CanvasItem = game.region.get_node("Atmosphere") as CanvasItem
	assert_false(atmosphere.visible)
	_deploy()
	assert_false(atmosphere.visible)
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_false(atmosphere.visible)
	assert_eq(game.saves.transfer_prototype(),OK)
	assert_eq(atmosphere.visible,game.chapter.dressing._legacy_visible)

func test_only_active_regional_ambience_uses_existing_marine_life_contract() -> void:
	_deploy()
	game.submarine.set_simulation_enabled(true)
	var bus: AcousticBus = game.get_node("AcousticBus") as AcousticBus
	var before: int = bus.history_count()
	var original_clock: float = game.ambient._clock
	for tick: int in range(3): game._physics_process(1)
	assert_eq(game.ambient._clock,original_clock)
	assert_eq(bus.history_count(),before,"Inactive prototype ambience must not consume the deep event history")
	var records: Dictionary = game.saves.progress_snapshot()
	game.submarine.global_position = Vector2(37900,1800)
	game.submarine.passive.advance(2)
	assert_eq(game.journey.habitat.ambient.advance(2),OK)
	var contacts: Array[Dictionary] = game.submarine.passive.contacts_snapshot()
	assert_eq(contacts.size(),1)
	assert_eq(contacts[0].classification,&"marine_life")
	assert_eq(PassiveContactsPanel.CLASS_LABELS.get(contacts[0].classification),"MARINE LIFE")
	assert_eq(GameplayAudio.contact_cue(&"marine_life"),&"biological")
	assert_eq(game.saves.progress_snapshot(),records)
