extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var scene: ShelfPrototype
var path: String
func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://feedback-%d.json" % Time.get_ticks_usec()
	scene = MAIN.instantiate() as ShelfPrototype
	scene.revised_expedition = false
	scene.settings_path = path
	scene.expedition_path = path+".expedition.json"
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	viewport.add_child(scene)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
func test_production_region_is_expanded_and_legacy_route_instructions_are_hidden() -> void:
	assert_eq(scene.region.camera_bounds.size.x,24000)
	assert_false((scene.region.get_node("Landmarks") as Node2D).visible)
	assert_not_null(scene.region.find_child("ExpeditionWreck",true,false))
	assert_eq(scene.missions.definitions().size(),5)
	assert_true(scene.hud.quiet)
	assert_false((scene.get_node("UI/RouteGuide") as Control).visible)
func test_starting_accepts_orders_and_tutorial_can_be_disabled_and_reloaded() -> void:
	scene._route_resume_requested()
	for id: StringName in scene.narrative.required_missions(): assert_ne(scene.missions.snapshot()[String(id)].state,"available")
	assert_true(scene.tutorial_card.visible)
	assert_eq(scene.tutorial.toggle(),OK)
	assert_false(scene.tutorial_card.visible)
	var settings: SettingsStore = SettingsStore.new()
	assert_eq(settings.load_settings(path),OK)
	assert_false(settings.snapshot().onboarding.enabled)
func test_station_opens_graphical_overview_and_services_do_not_apply_on_arrival() -> void:
	scene.resume_route()
	scene.submarine.resource_system.consume_battery(10)
	assert_eq(scene.open_station(),OK)
	assert_true(scene.station_menu._hub.visible)
	assert_false(scene.station_menu._services.visible)
	assert_eq(scene.submarine.resource_system.battery,90.0)
	scene.station_menu.show_services()
	assert_true(scene.station_menu._services.visible)
	assert_false(scene.station_menu._hub.visible)
	assert_true(scene.station_menu._service_back.is_visible_in_tree())
func test_old_short_survey_no_longer_concludes_fresh_extended_chapter() -> void:
	scene.narrative.begin_survey()
	scene.submarine.sonar.request_ping()
	scene.submarine.sonar.advance(0.6)
	scene.research.complete_scan(NarrativeService.PLATE)
	scene.discoveries.discover(NarrativeService.SPIRES,&"fixture")
	scene.route_check.sample(false,false,0.1)
	scene.route_check.sample(false,true,0.1)
	scene.route_check.sample(true,false,0.1)
	assert_false(scene.narrative.can_debrief())
	assert_false(scene.narrative.is_concluded())
func test_blast_damage_is_radial_bounded_and_suppressed_for_duplicate_ids() -> void:
	var receiver: BlastReceiver = scene.torpedoes._receivers[0]
	var at: Vector2 = scene.creature.global_position
	assert_eq(receiver.apply_blast(&"blast/1",at+Vector2(151,0),150,60),0.0)
	assert_gt(receiver.apply_blast(&"blast/2",at+Vector2(100,0),150,20),0.0)
	var health: float = receiver.health
	assert_eq(receiver.apply_blast(&"blast/2",at,150,60),0.0)
	assert_eq(receiver.health,health)
	receiver.apply_blast(&"blast/3",at,150,60)
	assert_eq(receiver.health,0.0)
	assert_false(scene.creature.visible)
	scene.restart_route()
	assert_eq(receiver.health,40.0)
	assert_true(scene.creature.visible)
func test_fire_requires_energy_and_pause_freezes_projectiles() -> void:
	scene.resume_route()
	assert_eq(scene.torpedoes.request_fire(),OK)
	assert_eq(scene.submarine.resource_system.battery,98.0)
	assert_eq(scene.torpedoes.request_fire(),ERR_BUSY)
	var p: TorpedoProjectile = scene.torpedoes._projectiles[0]
	var at: Vector2 = p.global_position
	scene.open_route_menu()
	scene.torpedoes._physics_process(1.0)
	assert_eq(p.global_position,at)
	scene.torpedoes.reset_session()
	scene.resume_route()
	scene.submarine.resource_system.consume_battery(100)
	assert_eq(scene.torpedoes.request_fire(),ERR_UNAVAILABLE)
	assert_true(scene.torpedoes._projectiles.is_empty())
func test_excavation_persists_through_save_continue_and_new_expedition() -> void:
	var changed: int = scene.excavation.excavate(Vector2(19400,1100),150)
	assert_gt(changed,0)
	var cuts: Array[Dictionary] = scene.excavation.snapshot()
	assert_eq(scene.saves.save_current(),OK)
	scene.extension.wildlife[0].position += Vector2(70,0)
	assert_eq(scene.saves.continue_expedition(),OK)
	assert_eq(scene.extension.wildlife[0].position,scene.extension.wildlife[0]._spawn)
	assert_eq(scene.excavation.snapshot(),cuts)
	assert_eq(scene.saves.new_expedition(),OK)
	assert_eq(scene.excavation.snapshot(),cuts)
func test_cooldown_cost_and_pause_are_consistent_at_30_60_120_steps() -> void:
	for rate: int in [30,60,120]:
		scene.restart_route()
		assert_eq(scene.torpedoes.request_fire(),OK)
		for step: int in range(int(rate*1.2)-1): scene.torpedoes._physics_process(1.0/rate)
		assert_eq(scene.torpedoes.request_fire(),ERR_BUSY)
		scene.torpedoes._physics_process(1.0/rate)
		assert_eq(scene.torpedoes.request_fire(),OK)
		assert_almost_eq(scene.submarine.resource_system.battery,96.0,0.000001)
func test_invalid_aim_does_not_charge_and_duplicate_impact_is_idempotent() -> void:
	scene.resume_route()
	scene.torpedoes.aim = Vector2.ZERO
	assert_eq(scene.torpedoes.request_fire(),ERR_INVALID_PARAMETER)
	assert_eq(scene.submarine.resource_system.battery,100.0)
	scene.torpedoes.aim = Vector2.RIGHT
	assert_eq(scene.torpedoes.request_fire(),OK)
	var projectile: TorpedoProjectile = scene.torpedoes._projectiles[0]
	watch_signals(scene.torpedoes)
	scene.torpedoes._impact(projectile,Vector2(19400,1100))
	var cuts: Array[Dictionary] = scene.excavation.snapshot()
	scene.torpedoes._impact(projectile,Vector2(19400,1100))
	assert_signal_emit_count(scene.torpedoes,"detonated",1)
	assert_eq(scene.excavation.snapshot(),cuts)
func test_killed_wildlife_cannot_be_scanned_and_passive_listening_has_no_blast() -> void:
	var receiver: BlastReceiver = scene.torpedoes._receivers[0]
	receiver.apply_blast(&"blast/death",scene.creature.global_position,150,60)
	assert_null(scene.submarine.scanner._target(&"observer-ecology"))
	assert_false(scene.creature.receiver.enabled)
	assert_true(scene.torpedoes._projectiles.is_empty())
	assert_true(scene.torpedoes._effects.is_empty())
func test_clearance_uses_excavated_shapes_and_rejects_protected_bedrock() -> void:
	await wait_physics_frames(2)
	assert_false(scene.saves.position_clear(Vector2(19500,1100),0.0))
	assert_gt(scene.excavation.excavate(Vector2(19500,1100),150),0)
	await wait_physics_frames(2)
	assert_true(scene.saves.position_clear(Vector2(19500,1100),0.0))
	assert_false(scene.saves.position_clear(Vector2(23980,1100),0.0))
func test_station_keyboard_and_controller_focus_stays_on_the_current_page() -> void:
	scene.resume_route()
	assert_eq(scene.open_station(),OK)
	for control: Control in [scene.station_menu._hub_service,scene.station_menu.get_node("%OpenUpgrades"),scene.station_menu.get_node("%OpenBoard"),scene.station_menu.get_node("%Undock")]:
		assert_true(control.is_visible_in_tree())
		assert_true(control.get_node(control.focus_next).is_visible_in_tree())
	assert_eq(scene.station_menu._hub_service.get_node(scene.station_menu._hub_service.focus_neighbor_bottom),scene.station_menu.get_node("%OpenUpgrades"))
	scene.station_menu.show_services()
	assert_eq(scene.get_viewport().gui_get_focus_owner(),scene.station_menu._service_back)
	scene.station_menu.show_hub()
	assert_eq(scene.get_viewport().gui_get_focus_owner(),scene.station_menu._hub_service)
func test_legacy_conclusion_is_preserved_without_requiring_new_outer_objectives() -> void:
	scene.narrative.begin_survey()
	scene.research.complete_scan(NarrativeService.PLATE)
	scene.discoveries.discover(NarrativeService.SPIRES,&"fixture")
	scene.route_check.sample(false,false,0.1)
	scene.route_check.sample(false,true,0.1)
	scene.route_check.sample(true,false,0.1)
	assert_eq(scene.missions.claim(NarrativeService.MAIN),OK)
	assert_eq(scene.missions.claim(NarrativeService.SCIENCE),OK)
	assert_false(scene.narrative.is_concluded())
	scene.narrative.legacy_conclusion = true
	assert_true(scene.narrative.is_concluded())
func test_tutorial_and_context_fit_without_covering_instruments() -> void:
	scene.resume_route()
	await wait_process_frames(8)
	assert_lt(scene.tutorial_card.size.y,scene.get_viewport().get_visible_rect().size.y*0.5)
	assert_false(scene.pilot_context.get_global_rect().intersects((scene.hud.get_node("%InstrumentDeck") as Control).get_global_rect()))
	assert_lt(scene.pilot_context.size.y,100.0)
func test_ui_confirm_held_during_resume_cannot_fire_until_released() -> void:
	scene.resume_route()
	Input.action_press("fire_torpedo")
	scene.torpedoes._physics_process(0.01)
	assert_true(scene.torpedoes._projectiles.is_empty())
	Input.action_release("fire_torpedo")
	scene.torpedoes._physics_process(0.01)
	Input.action_press("fire_torpedo")
	scene.torpedoes._physics_process(0.01)
	assert_eq(scene.torpedoes._projectiles.size(),1)
func test_blast_uses_existing_acoustic_bus_and_history_identity_contract() -> void:
	scene.resume_route()
	var bus: AcousticBus = scene.get_node("AcousticBus") as AcousticBus
	watch_signals(scene.creature.receiver)
	assert_eq(scene.torpedoes.request_fire(),OK)
	var p: TorpedoProjectile = scene.torpedoes._projectiles[0]
	scene.torpedoes._impact(p,scene.creature.global_position+Vector2(200,0))
	assert_signal_emit_count(scene.creature.receiver,"event_received",1)
	scene.torpedoes._impact(p,scene.creature.global_position+Vector2(200,0))
	assert_signal_emit_count(scene.creature.receiver,"event_received",1)
	assert_true(bus.history_count()<=bus.configuration.maximum_event_history)
func test_two_real_projectiles_open_a_collision_accurate_passage() -> void:
	scene.resume_route()
	scene.submarine.global_position = Vector2(19150,1100)
	scene.submarine.velocity = Vector2.ZERO
	scene.torpedoes.aim = Vector2.RIGHT
	await wait_physics_frames(3)
	assert_false(scene.saves.position_clear(Vector2(19500,1100),0.0))
	for shot: int in range(2):
		assert_eq(scene.torpedoes.request_fire(),OK)
		await wait_physics_frames(90)
	assert_true(scene.saves.position_clear(Vector2(19500,1100),0.0))
	assert_eq(scene.excavation.snapshot().size(),2)
func test_pre_checkpoint_legacy_profile_retains_earned_chapter_ending() -> void:
	var legacy: String = path+".old"
	var points: DiscoveryRegistry = DiscoveryRegistry.new()
	add_child_autofree(points)
	points.configure(ShelfPrototype.DISCOVERY_CATALOG)
	var point_store: DiscoveryStore = DiscoveryStore.new()
	point_store.path = legacy+".discoveries.json"
	point_store.load_registry(points)
	points.restore_discoveries([NarrativeService.SPIRES])
	assert_eq(point_store.save_registry(points),OK)
	var science: ResearchRegistry = ResearchRegistry.new()
	add_child_autofree(science)
	science.configure(ShelfPrototype.RESEARCH_CATALOG)
	var science_store: ResearchStore = ResearchStore.new()
	science_store.path = legacy+".research.json"
	science_store.load_registry(science)
	science.restore_completed([NarrativeService.PLATE])
	assert_eq(science_store.save_registry(science),OK)
	var mission_store: MissionStore = MissionStore.new()
	mission_store.path = legacy+".missions.json"
	mission_store.load_records(ShelfPrototype.MISSION_CATALOG)
	var records: Dictionary = {
		"shelf-expedition":{"state":"claimed","objectives":["identify-spires","return-to-base"]},
		"shelf-calibration-study":{"state":"claimed","objectives":["scan-calibration-plate"]}}
	assert_eq(mission_store.save_records(records,ShelfPrototype.MISSION_CATALOG),OK)
	var restored: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	restored.revised_expedition = false
	restored.settings_path = legacy
	restored.expedition_path = legacy+".expedition.json"
	add_child_autofree(restored)
	assert_true(restored.narrative.legacy_conclusion)
	assert_true(restored.narrative.is_concluded())
	assert_eq(restored.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy+stem+suffix))
