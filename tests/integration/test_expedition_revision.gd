extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var scene: ShelfPrototype
var path: String
func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://revision-two-%d.json" % Time.get_ticks_usec()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	scene = MAIN.instantiate() as ShelfPrototype
	scene.settings_path = path
	scene.expedition_path = path+".expedition.json"
	viewport.add_child(scene)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
func _start() -> void:
	scene.revision.start()
func _dock() -> void:
	assert_eq(scene.open_station(),OK)
func test_loading_opens_clean_title_with_paused_world_and_no_accepted_assignment() -> void:
	assert_true(scene.revision.ui.title_page.visible)
	assert_false(scene.submarine.is_physics_processing())
	assert_false(scene.route_layer.visible)
	assert_eq(scene.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
	assert_eq(scene.torpedoes.ammunition,10)
func test_title_keyboard_controller_focus_and_options_return_without_piloting() -> void:
	await wait_process_frames(3)
	var first: Control = scene.get_viewport().gui_get_focus_owner()
	assert_eq((first as Button).text,"Begin The Sunlit Shallows")
	assert_eq((first.get_node(first.focus_neighbor_right) as Button).text,"New Game")
	scene.revision.open_option("accessibility")
	assert_true(scene.accessibility_panel.visible)
	scene.accessibility_panel.close_requested.emit()
	assert_true(scene.revision.ui.title_page.visible)
	assert_false(scene.submarine.is_physics_processing())
func test_submarine_accelerates_gradually_and_rates_remain_consistent() -> void:
	assert_eq(scene.submarine.motion.acceleration,120.0)
	for rate: int in [30,60,120]:
		var velocity: Vector2 = Vector2.ZERO
		for step: int in range(rate): velocity = scene.submarine.motion.next_velocity(velocity,Vector2.RIGHT,1.0/rate)
		assert_almost_eq(velocity.x,120.0,0.0001)
		assert_lt(velocity.x,scene.submarine.motion.maximum_speed)
func test_torpedo_follows_visible_horizontal_facing_even_with_vertical_aim() -> void:
	_start()
	scene.submarine.facing = -1.0
	scene.torpedoes.aim = Vector2.UP
	assert_eq(scene.torpedoes.request_fire(),OK)
	var projectile: TorpedoProjectile = scene.torpedoes._projectiles[0]
	assert_eq(projectile.direction,Vector2.LEFT)
	assert_eq(scene.torpedoes.ammunition,9)
	assert_eq(projectile.speed,80.0)
	assert_eq(projectile.acceleration,500.0)
	assert_not_null(projectile.trail)
func test_ammunition_is_limited_and_failure_pause_and_cooldown_do_not_spend() -> void:
	_start()
	scene.torpedoes.restore_ammunition(1)
	assert_eq(scene.torpedoes.request_fire(),OK)
	assert_eq(scene.torpedoes.ammunition,0)
	var battery: float = scene.submarine.resource_system.battery
	assert_eq(scene.torpedoes.request_fire(),ERR_UNAVAILABLE)
	assert_eq(scene.submarine.resource_system.battery,battery)
	scene.torpedoes.restore_ammunition(10)
	assert_eq(scene.torpedoes.request_fire(),ERR_BUSY)
	assert_eq(scene.torpedoes.ammunition,10)
func test_actual_docking_automatically_refills_and_passing_base_does_not() -> void:
	_start()
	scene.submarine.resource_system.consume_battery(15)
	scene.submarine.hull_system.apply_damage(10,&"fixture")
	scene.torpedoes.restore_ammunition(3)
	assert_eq(scene.submarine.resource_system.battery,85.0)
	_dock()
	assert_eq(scene.submarine.resource_system.battery,100.0)
	assert_eq(scene.submarine.hull_system.hull,100.0)
	assert_eq(scene.torpedoes.ammunition,10)
	assert_true(scene.revision.ui.dock_page.visible)
	assert_false(scene.station_menu.visible)
	assert_false(scene.submarine.is_physics_processing())
func test_assign_refund_and_respec_use_finite_points_and_update_real_capabilities() -> void:
	_start()
	assert_eq(scene.revision.assign("hull",1),ERR_UNAVAILABLE)
	_dock()
	assert_eq(scene.revision.assign("hull",1),OK)
	assert_eq(scene.submarine.damage_system.get_maximum_depth_m(),400.0)
	assert_eq(scene.revision.assign("sonar",1),ERR_UNAVAILABLE)
	assert_eq(scene.revision.assign("hull",-1),OK)
	assert_eq(scene.revision.assign("sonar",1),OK)
	assert_eq(scene.submarine.sonar.maximum_radius(),1200.0)
	assert_eq(scene.revision.assign("sonar",1),ERR_UNAVAILABLE)
	assert_eq(scene.revision.respec(),OK)
	assert_eq(CampaignData.available(scene.revision.campaign),2)
	assert_eq(scene.submarine.damage_system.get_maximum_depth_m(),300.0)
	assert_eq(scene.submarine.sonar.maximum_radius(),900.0)
	assert_eq(scene.upgrades.install(&"sonar-range-1200"),ERR_UNAUTHORIZED)
func test_accepted_radio_assignment_marks_report_without_discovering_secret() -> void:
	_start()
	scene.revision.show_transmission("dispatch",true)
	assert_true(scene.submarine.is_physics_processing())
	scene.revision.accept_transmission("dispatch",true)
	assert_true(scene.submarine.is_physics_processing())
	assert_ne(scene.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
	assert_true(scene.exploration_map.canvas.has_report)
	assert_eq(scene.discoveries.state_of(NarrativeService.SPIRES),DiscoveryRegistry.State.HIDDEN)
	assert_eq(scene.revision.campaign.messages,["dispatch"])
func test_deferred_radio_does_not_accept_or_spend_and_can_be_reopened() -> void:
	_start()
	scene.revision.show_transmission("dispatch",true)
	scene.revision.defer_transmission()
	assert_eq(scene.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
	assert_true(scene.submarine.is_physics_processing())
	assert_eq(scene.revision.campaign.messages,[])
func test_wreck_scan_retrieves_encrypted_logs_and_docking_decodes_only_once() -> void:
	_start()
	scene.research.complete_scan(&"lost-expedition-blackbox")
	assert_false(scene.revision.campaign.decoded)
	assert_true(scene.revision.research_text(&"lost-expedition-blackbox","").contains("ENCRYPTED"))
	watch_signals(scene.revision)
	_dock()
	assert_true(scene.revision.campaign.decoded)
	assert_eq(CampaignData.earned(scene.revision.campaign),3)
	assert_signal_emit_count(scene.revision,"logs_decoded",1)
	scene.revision.undock()
	_dock()
	assert_eq(CampaignData.earned(scene.revision.campaign),3)
	assert_signal_emit_count(scene.revision,"logs_decoded",1)
	assert_true(scene.revision.decoded_text().contains("Twilight Reef"))
func test_survey_completion_awards_one_point_and_repeated_events_do_not_duplicate() -> void:
	_start()
	scene.narrative.begin_survey()
	scene.research.complete_scan(&"outer-hydrophone-record")
	scene.research.complete_scan(&"outer-vent-study")
	scene.revision._reward_survey()
	scene.revision._reward_survey()
	assert_eq(CampaignData.earned(scene.revision.campaign),3)
	assert_eq(scene.revision.campaign.awards,["commission","outer-survey"])
func test_save_continue_preserves_ammo_ranks_and_decoded_records() -> void:
	_start()
	_dock()
	scene.revision.assign("hull",1)
	scene.revision.undock()
	scene.torpedoes.restore_ammunition(4)
	scene.open_route_menu()
	assert_eq(scene.saves.save_current(),OK)
	scene.torpedoes.restore_ammunition(0)
	assert_eq(scene.saves.continue_expedition(),OK)
	assert_eq(scene.torpedoes.ammunition,4)
	assert_eq(scene.revision.campaign.ranks.hull,1)
	assert_eq(scene.submarine.damage_system.get_maximum_depth_m(),400.0)
func test_failed_research_write_preserves_previous_allocation() -> void:
	_start()
	_dock()
	var before: Dictionary = scene.revision.campaign.duplicate(true)
	scene.saves._ready_to_write = false
	assert_ne(scene.revision.assign("sonar",1),OK)
	assert_eq(scene.revision.campaign,before)
	assert_eq(scene.submarine.sonar.maximum_radius(),900.0)
func test_scavenger_flees_on_approach_and_pause_restart_are_safe() -> void:
	_start()
	var npc: WreckScavenger = scene.revision.scavenger
	scene.submarine.global_position = Vector2(21000,1220)
	npc._before_step(1.0/120.0)
	assert_eq(npc.brain.state,CreatureState.State.FLEE)
	assert_true(npc.encounter_started)
	npc.set_suspended(true)
	var at: Vector2 = npc.position
	npc.advance_simulation(1.0)
	assert_eq(npc.position,at)
	npc.reset_session()
	assert_false(npc.encounter_started)
	assert_eq(npc.brain.state,CreatureState.State.PATROL)
func test_exact_ten_rounds_cannot_be_bypassed_by_effect_reset_or_continue() -> void:
	_start()
	for shot: int in range(10):
		assert_eq(scene.torpedoes.request_fire(),OK)
		scene.torpedoes.reset_session()
	assert_eq(scene.torpedoes.ammunition,0)
	assert_eq(scene.torpedoes.request_fire(),ERR_UNAVAILABLE)
	assert_eq(scene.submarine.resource_system.battery,80.0)
	scene.open_route_menu()
	assert_eq(scene.saves.save_current(),OK)
	assert_eq(scene.saves.continue_expedition(),OK)
	assert_eq(scene.torpedoes.ammunition,0)
func test_paused_launch_never_spends_ammunition_or_energy() -> void:
	var battery: float = scene.submarine.resource_system.battery
	assert_eq(scene.torpedoes.request_fire(),ERR_BUSY)
	assert_eq(scene.torpedoes.ammunition,10)
	assert_eq(scene.submarine.resource_system.battery,battery)
func test_scavenger_flee_state_is_deterministic_at_30_60_120_steps() -> void:
	var destinations: Array[Vector2] = []
	for rate: int in [30,60,120]:
		var model: CreatureState = CreatureState.new()
		var rules: CreatureProfile = scene.revision.scavenger.configuration
		assert_eq(model.configure(rules),OK)
		assert_eq(model.request_flee(Vector2(22950,1120)),OK)
		var position: Vector2 = Vector2(21300,1220)
		for step: int in range(rate*4):
			model.advance(1.0/rate,position)
			position = position.move_toward(model.destination(),model.speed()/rate)
		destinations.append(position)
		assert_eq(model.state,CreatureState.State.FLEE)
	assert_almost_eq(destinations[0].x,destinations[2].x,0.1)
	assert_almost_eq(destinations[1].x,destinations[2].x,0.1)
func test_new_canonical_file_reloads_allocations_and_record_decoding_silently() -> void:
	_start()
	scene.research.complete_scan(&"lost-expedition-blackbox")
	_dock()
	scene.revision.assign("hull",1)
	scene.revision.assign("sonar",1)
	assert_eq(scene.saves.save_current(),OK)
	var restored: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	restored.settings_path = path
	restored.expedition_path = path+".expedition.json"
	add_child_autofree(restored)
	assert_true(restored.revision.campaign.decoded)
	assert_eq(restored.revision.campaign.ranks.hull,1)
	assert_eq(restored.revision.campaign.ranks.sonar,0)
	assert_eq(restored.submarine.damage_system.get_maximum_depth_m(),400.0)
	assert_eq(CampaignData.earned(restored.revision.campaign),3)
func test_corrupt_profile_blocks_research_and_recovery_preserves_awards() -> void:
	_start()
	_dock()
	scene.revision.assign("hull",1)
	var file: FileAccess = FileAccess.open(path+".expedition.json",FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var before: Dictionary = scene.revision.campaign.duplicate(true)
	assert_ne(scene.revision.assign("sonar",1),OK)
	assert_eq(scene.revision.campaign,before)
	assert_eq(scene.saves.recover_backup(),OK)
	assert_eq(scene.saves.continue_expedition(),OK)
	assert_eq(scene.revision.campaign.ranks.hull,1)
	assert_eq(CampaignData.earned(scene.revision.campaign),2)
func test_compact_large_station_has_reachable_fixed_text_scroll_controls() -> void:
	_start()
	_dock()
	scene.get_viewport().size = Vector2i(800,600)
	var prefs: Dictionary = scene.settings.snapshot().accessibility
	prefs.ui_scale = "large"
	scene.settings.set_accessibility(prefs)
	scene.revision.ui.show_dock("logs")
	await wait_process_frames(5)
	var reader: UiScrollReader = scene.revision.ui._scrolls[scene.revision.ui.dock_page] as UiScrollReader
	assert_true(reader.is_visible_in_tree())
	assert_lte(reader.get_global_rect().end.y,600.0)
	assert_eq(reader.focus_mode,Control.FOCUS_ALL)
	assert_null(scene.revision.ui.dock_page.find_child("TextDown",true,false))
	assert_false(scene.expedition_log.begin_button.visible)
func test_live_comfort_preferences_suppress_existing_wake_and_refraction() -> void:
	_start()
	scene.torpedoes.request_fire()
	var projectile: TorpedoProjectile = scene.torpedoes._projectiles[0]
	scene.torpedoes._impact(projectile,Vector2(19100,1100))
	var effect: BlastEffect = scene.torpedoes._effects[0]
	var prefs: Dictionary = scene.settings.snapshot().accessibility
	prefs.reduced_flashing = true
	prefs.reduced_particles = true
	prefs.reduced_motion = true
	scene.settings.set_accessibility(prefs)
	await wait_process_frames(4)
	assert_true(effect.reduced_effects)
	assert_false(effect._lens.visible)
	assert_true(projectile.trail.reduced)
