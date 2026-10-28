extends GutTest
var game: ShelfPrototype
var viewport: SubViewport
var path: String
var archives: Array[String] = []
class FailureStore extends ExpeditionStore:
	func _atomic_write(_destination: String,_text: String) -> Error: return ERR_CANT_CREATE

func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://pr35-%d.json" % Time.get_ticks_usec()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	viewport.add_child(game)
	await wait_process_frames(3)

func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	for archive: String in archives:
		if not archive.begins_with("user://campaign-archive-"): continue
		var absolute: String = ProjectSettings.globalize_path(archive)
		for file: String in DirAccess.get_files_at(absolute): DirAccess.remove_absolute(absolute.path_join(file))
		DirAccess.remove_absolute(absolute)
	archives.clear()
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)

func launch() -> void:
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)

func test_new_game_archives_progress_resets_every_domain_and_preserves_preferences() -> void:
	launch()
	assert_eq(game.saves.save_current(),OK)
	game.settings.save_settings(path)
	var settings: Dictionary = game.settings.snapshot()
	var bytes: String = FileAccess.get_file_as_string(game.expedition_path)
	assert_eq(game.saves.begin_new_campaign(),OK)
	archives.append(game.saves.last_campaign_archive)
	var archive: String = ProjectSettings.globalize_path(archives[-1])
	var preserved: bool = false
	for file: String in DirAccess.get_files_at(archive): preserved = preserved or FileAccess.get_file_as_string(archive.path_join(file))==bytes
	assert_true(preserved)
	var fresh: Dictionary = game.saves.store.read_file(game.expedition_path).data
	assert_eq(fresh.story,StoryState.fresh())
	assert_eq(fresh.prototype.campaign,CampaignData.fresh())
	assert_eq(fresh.progress.research,[])
	assert_eq(fresh.progress.discoveries,[])
	assert_eq(fresh.terrain,[])
	assert_eq(fresh.player.hull,100.0)
	for mission: String in fresh.progress.missions: assert_eq(fresh.progress.missions[mission].state,"available")
	assert_eq(game.settings.snapshot(),settings)

func test_failed_new_game_rolls_back_byte_identical_campaign_and_keeps_live_state() -> void:
	launch()
	assert_eq(game.saves.save_current(),OK)
	var bytes: String = FileAccess.get_file_as_string(game.expedition_path)
	var live: Dictionary = game.story.snapshot()
	assert_ne(game.saves.begin_new_campaign(FailureStore.new()),OK)
	archives.append(game.saves.last_campaign_archive)
	assert_eq(FileAccess.get_file_as_string(game.expedition_path),bytes)
	assert_eq(game.story.snapshot(),live)
	assert_eq(game.saves.store.read_file(game.expedition_path).error,OK)

func test_new_game_confirmation_cancel_does_not_change_a_save() -> void:
	var button: Button = game.revision.ui.find_child("NewGame",true,false) as Button
	assert_not_null(button)
	button.pressed.emit()
	assert_true(game.revision.ui.radio_page.visible)
	assert_not_null(game.revision.ui.find_child("ConfirmNewGame",true,false))
	game.revision.ui._cancel_new_game()
	assert_true(game.revision.ui.title_page.visible)
	assert_false(FileAccess.file_exists(game.expedition_path))

func test_new_game_reload_cannot_reimport_archived_legacy_discoveries() -> void:
	launch()
	game.discoveries.discover(SunlitSurveyData.CLEARED,&"test")
	var legacy: DiscoveryStore = DiscoveryStore.new()
	legacy.path = game.discovery_store.path
	assert_eq(legacy.load_registry(game.discoveries),ERR_FILE_NOT_FOUND)
	assert_eq(legacy.save_registry(game.discoveries),OK)
	assert_eq(game.saves.save_current(),OK)
	assert_eq(game.saves.begin_new_campaign(),OK)
	archives.append(game.saves.last_campaign_archive)
	assert_false(FileAccess.file_exists(legacy.path))
	game.free()
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	viewport.add_child(game)
	await wait_process_frames(3)
	assert_eq(game.discoveries.discovered_ids().size(),0)
	assert_eq(game.story.snapshot(),StoryState.fresh())
	assert_eq(game.saves.continue_expedition(),OK)
	assert_false(game.chapter.guide.layout.passage_clear())

func test_upper_dead_end_and_lower_loop_are_clear_but_blind_wall_is_solid() -> void:
	launch()
	await wait_physics_frames(2)
	var collision: CollisionShape2D = game.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState2D = game.submarine.get_world_2d().direct_space_state
	var route: Array[Vector2] = [Vector2(6500,650),Vector2(7100,650),Vector2(7100,270),Vector2(6750,270),Vector2(7100,270),Vector2(7100,660)]
	for index: int in range(route.size()-1):
		query.transform = Transform2D(0,route[index])*collision.transform
		query.motion = route[index+1]-route[index]
		assert_true(space.intersect_shape(query).is_empty())
		assert_gte(space.cast_motion(query)[0],0.99999,"Full hull fits optional loop / blind alcove.")
	query.transform = Transform2D(0,Vector2(6750,270))*collision.transform
	query.motion = Vector2(-500,0)
	assert_lt(space.cast_motion(query)[0],1.0,"Blind end cannot be crossed.")

func test_old_cleared_gate_restores_as_open_without_reward_or_acoustic_replay() -> void:
	launch()
	game.excavation.excavate(Vector2(4550,480),150)
	assert_false(game.chapter.guide.layout.passage_clear())
	game.discoveries.discover(SunlitSurveyData.CLEARED,&"legacy-import")
	assert_eq(game.saves.save_current(),OK)
	var journal: Array[Dictionary] = game.excavation.snapshot()
	watch_signals(game.discoveries)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_true(game.chapter.guide.layout.passage_clear())
	assert_eq(game.excavation.snapshot(),journal,"Compatibility widening cannot exhaust the bounded journal.")
	assert_signal_not_emitted(game.discoveries,"point_discovered")

func test_hammerhead_sight_warning_pursuit_head_ram_and_safe_exit() -> void:
	launch()
	var shark: HammerheadCreature = game.chapter.guide.hammerhead
	game.submarine.global_position = Vector2(18880,910)
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(120)
	assert_eq(game.submarine.hull_system.hull,100.0,"Warning cannot damage.")
	assert_eq(shark.threat.phase,PredatorState.Phase.ALERT)
	await wait_physics_frames(160)
	game.submarine.set_simulation_enabled(false)
	assert_lt(game.submarine.hull_system.hull,100.0)
	assert_gte(game.submarine.hull_system.hull,88.0)
	assert_true(game.submarine.hull_system.last_damage_source.contains("sunlit-hammerhead"))
	var hull: float = game.submarine.hull_system.hull
	game.submarine.global_position = Vector2(18880,650)
	game.submarine.set_simulation_enabled(true)
	await wait_physics_frames(180)
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.submarine.hull_system.hull,hull)
	assert_ne(shark.threat.phase,PredatorState.Phase.PURSUE)

func test_hammerhead_pause_and_fauna_restart_preserve_permanent_records() -> void:
	launch()
	var shark: HammerheadCreature = game.chapter.guide.hammerhead
	var at: Vector2 = shark.position
	assert_eq(shark.advance_simulation(0.5),OK)
	assert_eq(shark.position,at)
	var story: Dictionary = game.story.snapshot()
	game.restart_route()
	assert_eq(game.story.snapshot(),story)
	assert_eq(shark.threat.phase,PredatorState.Phase.QUIET)
	assert_eq(game.chapter.guide.fauna.size(),3)

func test_radio_cue_only_for_new_delivery_respects_mute_and_never_emits_gameplay_sound() -> void:
	var settings: Dictionary = game.settings.snapshot().audio
	settings.muted = false
	game.settings.set_audio(settings)
	watch_signals(game.audio)
	var radio: RadioNotifications = game.revision.ui.notifications
	radio.enqueue("sunlit-map-guidance","Map test","Okafor")
	assert_signal_emitted_with_parameters(game.audio,"cue_played",[&"radio","UI"])
	var count: int = get_signal_emit_count(game.audio,"cue_played")
	radio.enqueue("sunlit-map-guidance","Duplicate","Okafor")
	assert_eq(get_signal_emit_count(game.audio,"cue_played"),count)
	settings.muted = true
	game.settings.set_audio(settings)
	radio.enqueue("sunlit-search-guidance","Silent but readable","Wick")
	assert_eq(get_signal_emit_count(game.audio,"cue_played"),count)
	assert_true(radio.contains_message("sunlit-search-guidance"))

func test_new_fauna_use_existing_blast_deduplication_and_restart_restores_health() -> void:
	launch()
	for animal: AcousticCreature in game.chapter.guide.fauna:
		var receiver: BlastReceiver
		for candidate: BlastReceiver in game.torpedoes._receivers:
			if candidate.stable_id==animal.creature_id: receiver = candidate
		assert_not_null(receiver)
		assert_eq(receiver.apply_blast(&"review/blast-1",animal.global_position,150,20),20.0)
		assert_eq(receiver.apply_blast(&"review/blast-1",animal.global_position,150,20),0.0)
		assert_eq(receiver.apply_blast(&"review/blast-2",animal.global_position,150,20),20.0)
		assert_true(animal._destroyed)
	game.restart_route()
	for animal: AcousticCreature in game.chapter.guide.fauna:
		assert_false(animal._destroyed)
		for receiver: BlastReceiver in game.torpedoes._receivers:
			if receiver.stable_id==animal.creature_id: assert_eq(receiver.health,receiver.maximum_health)

func test_bloom_swims_only_during_simulation_and_remains_removed_after_collection() -> void:
	var visual: LightBloomVisual = game.bloom.visual
	visual.advance_arrival(0.5,Vector2(1280,480),true)
	assert_gt(visual.swim_phase,0.0)
	var phase: float = visual.swim_phase
	visual.advance_arrival(1,Vector2(1280,480),false)
	assert_eq(visual.swim_phase,phase)
	visual.reduced_effects = true
	visual.advance_arrival(1,Vector2(1280,480),true)
	assert_eq(visual.swim_phase,phase)
	visual.set_outcome(true,false)
	visual.advance_arrival(1,Vector2(1280,480),true)
	assert_false(visual.plankton_visible())

func test_underwater_blast_is_bounded_and_comfort_removes_decorations() -> void:
	var blast: BlastEffect = BlastEffect.new()
	add_child_autofree(blast)
	assert_eq(blast._bubbles.multimesh.instance_count,28)
	blast.advance(1)
	assert_false(blast.is_queued_for_deletion())
	blast.advance(2)
	assert_true(blast.is_queued_for_deletion())
	var quiet: BlastEffect = BlastEffect.new()
	quiet.reduced_effects = true
	add_child_autofree(quiet)
	assert_null(quiet._bubbles)
	quiet.advance(0.7)
	assert_true(quiet.is_queued_for_deletion())

func _menu_event(key: Key,joy: JoyButton,controller: bool) -> void:
	var event: InputEvent
	if controller:
		var input: InputEventJoypadButton = InputEventJoypadButton.new()
		input.button_index = joy
		input.pressed = true
		event = input
	else:
		var input: InputEventKey = InputEventKey.new()
		input.keycode = key
		input.physical_keycode = key
		input.pressed = true
		event = input
	viewport.push_input(event,true)
	event = event.duplicate() as InputEvent
	if event is InputEventKey: event.pressed = false
	else: event.pressed = false
	viewport.push_input(event,true)
	await wait_process_frames(3)

func _new_game_input(controller: bool) -> void:
	await _menu_event(KEY_TAB,JOY_BUTTON_RIGHT_SHOULDER,controller)
	assert_eq(viewport.gui_get_focus_owner().name,&"NewGame")
	await _menu_event(KEY_ENTER,JOY_BUTTON_A,controller)
	assert_true(game.revision.ui.radio_page.visible)
	for unused: int in range(12):
		if viewport.gui_get_focus_owner()!=null and viewport.gui_get_focus_owner().name==&"ConfirmNewGame": break
		await _menu_event(KEY_TAB,JOY_BUTTON_RIGHT_SHOULDER,controller)
	assert_eq(viewport.gui_get_focus_owner().name,&"ConfirmNewGame")
	var coordinator: SaveCoordinator = game.saves
	coordinator.status_changed.connect(func() -> void:
		if not coordinator.last_campaign_archive.is_empty() and coordinator.last_campaign_archive not in archives: archives.append(coordinator.last_campaign_archive))
	await _menu_event(KEY_ENTER,JOY_BUTTON_A,controller)
	await wait_process_frames(4)
	for child: Node in viewport.get_children():
		if child is ShelfPrototype and not child.is_queued_for_deletion(): game = child
	assert_true(game.revision.ui.radio_page.visible)
	assert_eq(game.chapter.state(),"available")
	assert_not_null(game.revision.ui.find_child("LaunchSunlit",true,false))

func test_keyboard_can_confirm_new_game_and_reach_fresh_briefing() -> void:
	await _new_game_input(false)

func test_controller_can_confirm_new_game_and_reach_fresh_briefing() -> void:
	await _new_game_input(true)
