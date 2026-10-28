extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var scene: ShelfPrototype
var path: String
var viewport: SubViewport
func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://bta046-%d.json" % Time.get_ticks_usec()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	scene = _new_scene()
func _new_scene() -> ShelfPrototype:
	var game: ShelfPrototype = MAIN.instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	viewport.add_child(game)
	return game
func after_each() -> void:
	# UI replacement uses queue_free because a button may still be emitting pressed.
	await get_tree().process_frame
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".rejected", ".invalid"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
func _approach() -> void:
	scene.revision._defer_until = 100000.0
	scene.revision.start()
	scene.submarine.global_position = Vector2(1280,480)
	scene.submarine.velocity = Vector2.ZERO
	assert_eq(scene.submarine.sonar.request_ping(),OK)
	scene.submarine.sonar.advance(1.5)
	assert_true(scene.bloom.identified())
func _observe() -> void:
	_approach()
	assert_eq(scene.bloom.interact(),OK)
	assert_eq(scene.bloom.choose_observe(),OK)
	assert_true(scene.submarine.scanner.snapshot().active_id==LightBloomEncounter.SCAN)
	scene.submarine.scanner.advance(3.0)
func _collect() -> void:
	_approach()
	assert_eq(scene.bloom.interact(),OK)
	assert_eq(scene.bloom.choose_collect(),OK)
func test_fresh_main_and_sonar_discovery_alone_have_no_story_effects() -> void:
	assert_eq(scene.story.snapshot(),StoryState.fresh())
	_approach()
	assert_eq(scene.story.resonance(),0)
	assert_false(scene.story.resolved(LightBloomEncounter.ENCOUNTER))
func test_observation_uses_timed_scanner_and_commits_one_atomic_outcome() -> void:
	_approach()
	scene.bloom.interact()
	watch_signals(scene.story)
	watch_signals(scene.research)
	assert_eq(scene.bloom.choose_observe(),OK)
	scene.submarine.scanner.advance(2.99)
	assert_eq(scene.story.resonance(),0)
	scene.submarine.scanner.advance(0.01)
	assert_eq(scene.story.resonance(),15)
	assert_true(scene.research.is_completed(LightBloomEncounter.SCAN))
	assert_false(scene.bloom.visual.collected)
	assert_true(scene.bloom.visual.observed)
	assert_signal_emit_count(scene.story,"choice_applied",1)
	assert_signal_emit_count(scene.research,"scan_completed",1)
	var saved: Dictionary = scene.saves.store.read_file(path+".expedition.json").data
	assert_eq(saved.story,scene.story.snapshot())
	assert_has(saved.progress.research,String(LightBloomEncounter.SCAN))
func test_collection_removes_bloom_and_cannot_also_reward_a_scan() -> void:
	_collect()
	assert_eq(scene.story.resonance(),-15)
	assert_true(scene.bloom.visual.collected)
	assert_false(scene.bloom.target.scan_enabled)
	assert_false(scene.research.is_completed(LightBloomEncounter.SCAN))
	assert_eq(scene.story.apply_choice(LightBloomEncounter.OBSERVE),ERR_ALREADY_EXISTS)
	assert_ne(scene.research.complete_scan(LightBloomEncounter.SCAN),OK)
func test_cancel_and_interrupted_scan_leave_both_choices_available() -> void:
	_approach()
	scene.bloom.interact()
	scene.bloom.leave()
	assert_eq(scene.story.snapshot(),StoryState.fresh())
	scene.bloom.interact()
	scene.bloom.choose_observe()
	scene.submarine.scanner.advance(1.0)
	scene.submarine.global_position = Vector2(760,480)
	scene.submarine.scanner.advance(0.1)
	assert_eq(scene.story.resonance(),0)
	assert_false(scene.research.is_completed(LightBloomEncounter.SCAN))
	assert_false(scene.story.resolved(LightBloomEncounter.ENCOUNTER))
func test_failed_scan_checkpoint_has_no_partial_research_or_story_rewards() -> void:
	_approach()
	scene.bloom.interact()
	scene.bloom.choose_observe()
	scene.saves._ready_to_write = false
	scene.submarine.scanner.advance(3.0)
	assert_eq(scene.story.snapshot(),StoryState.fresh())
	assert_false(scene.research.is_completed(LightBloomEncounter.SCAN))
	assert_true(scene.submarine.scanner.snapshot().text.contains("NOT RECORDED"))
func test_failed_collection_retains_colony_and_existing_progress() -> void:
	_approach()
	scene.bloom.interact()
	scene.saves._ready_to_write = false
	assert_ne(scene.bloom.choose_collect(),OK)
	assert_false(scene.bloom.visual.collected)
	assert_eq(scene.story.resonance(),0)
func test_reload_continue_and_repeated_interaction_cannot_farm() -> void:
	_observe()
	scene.bloom.leave()
	scene.open_route_menu()
	assert_eq(scene.saves.save_current(),OK)
	scene.free()
	scene = _new_scene()
	watch_signals(scene.story)
	watch_signals(scene.research)
	scene.revision.start()
	assert_eq(scene.story.resonance(),15)
	assert_true(scene.research.is_completed(LightBloomEncounter.SCAN))
	assert_eq(scene.bloom.visual.reaction,0.0)
	assert_signal_not_emitted(scene.story,"choice_applied")
	assert_signal_not_emitted(scene.research,"scan_completed")
	for repeat: int in range(5):
		assert_eq(scene.story.apply_choice(LightBloomEncounter.OBSERVE),ERR_ALREADY_EXISTS)
	assert_eq(scene.story.resonance(),15)
func test_collection_survives_restart_without_reviving_bloom_or_resetting_technology() -> void:
	_collect()
	scene.bloom.leave()
	var research: Dictionary = scene.revision.campaign.duplicate(true)
	scene.restart_route()
	assert_eq(scene.story.resonance(),-15)
	assert_true(scene.bloom.visual.collected)
	assert_eq(scene.revision.campaign,research)
func test_mute_and_comfort_modes_keep_explicit_text_and_static_feedback() -> void:
	var audio: Dictionary = scene.settings.snapshot().audio
	audio.muted = true
	scene.settings.set_audio(audio)
	var comfort: Dictionary = scene.settings.snapshot().accessibility
	comfort.reduced_motion = true
	comfort.reduced_flashing = true
	scene.settings.set_accessibility(comfort)
	_collect()
	assert_true(scene.bloom.modal())
	assert_eq(scene.bloom.visual.reaction,0.0)
	var text: String = ""
	for node: Node in scene.bloom.panel.body.get_children():
		if node is Label: text += node.text
	assert_true(text.contains("Wick:"))
	assert_true(text.contains("Okafor:"))
	assert_true(text.contains("Crane:"))
	assert_true(text.contains("BLOOM EXTINGUISHED"))
	assert_false(text.to_lower().contains("resonance"))
	assert_false(text.contains("-15"))
	assert_false(text.contains("+15"))
func test_old_checkpoint_migrates_with_zero_story_and_preserved_prototype_progress() -> void:
	var old: Dictionary = scene.saves.snapshot()
	old.schema_version = 4
	old.prototype.campaign.erase("science")
	old.erase("story")
	old.prototype.ammunition = 7
	var decoded: Dictionary = ExpeditionSchema.decode(old)
	assert_eq(decoded.error,OK)
	assert_eq(decoded.data.story,StoryState.fresh())
	assert_eq(decoded.data.prototype.ammunition,7)
	assert_eq(decoded.data.progress,old.progress)
func test_schema_rejects_orphan_research_without_its_atomic_story_decision() -> void:
	var data: Dictionary = scene.saves.snapshot()
	data.progress.research.append(String(LightBloomEncounter.SCAN))
	assert_ne(ExpeditionSchema.decode(data).error,OK)
func test_existing_technology_ordnance_services_and_acoustic_identity_are_unchanged() -> void:
	var before: Dictionary = scene.revision.campaign.duplicate(true)
	_collect()
	assert_eq(scene.revision.campaign,before)
	assert_eq(scene.torpedoes.ammunition,10)
	assert_eq(scene.submarine.resource_system.battery,96.0)
	assert_eq(scene.submarine.sonar.configuration.battery_cost,4.0)
	assert_eq(scene.submarine.sonar.configuration.cooldown_seconds,4.0)
func test_all_previous_checkpoint_versions_migrate_with_zero_story_state() -> void:
	var source: Dictionary = scene.saves.snapshot()
	for version: int in [1,2,3,4]:
		var old: Dictionary = source.duplicate(true)
		old.schema_version = version
		old.prototype.campaign.erase("science")
		old.erase("story")
		if version<=3: old.erase("prototype")
		if version<=2:
			old.erase("terrain")
			old.erase("legacy_conclusion")
		if version==1:
			old.player.erase("rotation")
			old.player.erase("sonar_cooldown")
		var loaded: Dictionary = ExpeditionSchema.decode(old)
		assert_eq(loaded.error,OK)
		assert_eq(loaded.data.story,StoryState.fresh())
		assert_eq(loaded.data.progress,source.progress)
		assert_eq(loaded.data.player.battery,source.player.battery)
func test_recovery_merges_a_live_choice_into_an_older_backup_without_replay() -> void:
	assert_eq(scene.saves.save_current(),OK)
	var old: String = FileAccess.get_file_as_string(path+".expedition.json")
	_observe()
	var backup: FileAccess = FileAccess.open(path+".expedition.json.bak",FileAccess.WRITE)
	backup.store_string(old)
	backup.close()
	var corrupt: FileAccess = FileAccess.open(path+".expedition.json",FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	watch_signals(scene.story)
	assert_eq(scene.saves.recover_backup(),OK)
	assert_eq(scene.story.resonance(),15)
	assert_true(scene.research.is_completed(LightBloomEncounter.SCAN))
	assert_signal_not_emitted(scene.story,"choice_applied")
	assert_true(FileAccess.file_exists(path+".expedition.json.rejected"))
	assert_eq(scene.saves.store.read_file(path+".expedition.json").data.story,scene.story.snapshot())
func test_opposite_branch_backup_conflict_preserves_files_and_live_choice() -> void:
	_collect()
	var primary: String = FileAccess.get_file_as_string(path+".expedition.json")
	var opposite: StoryState = StoryState.new()
	add_child_autofree(opposite)
	opposite.configure()
	opposite.apply_choice(LightBloomEncounter.OBSERVE)
	var data: Dictionary = scene.saves.snapshot()
	data.story = opposite.snapshot()
	data.progress.research.append(String(LightBloomEncounter.SCAN))
	data.prototype.campaign.science = ResearchExperienceData.reconcile(data.prototype.campaign.science,data.progress.research)
	var file: FileAccess = FileAccess.open(path+".expedition.json.bak",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	assert_eq(scene.saves.recover_backup(),ERR_BUSY)
	assert_eq(FileAccess.get_file_as_string(path+".expedition.json"),primary)
	assert_false(FileAccess.file_exists(path+".expedition.json.rejected"))
	assert_eq(scene.story.resonance(),-15)
func test_stale_checkpoint_cannot_erase_a_durable_choice() -> void:
	var stale: Dictionary = scene.saves.snapshot()
	_collect()
	assert_eq(scene.saves.store.write_checkpoint(stale),ERR_BUSY)
	assert_eq(scene.saves.store.read_file(path+".expedition.json").data.story,scene.story.snapshot())
func test_small_large_text_choice_has_keyboard_controller_recovery_and_reading_controls() -> void:
	viewport.size = Vector2i(800,600)
	var prefs: Dictionary = scene.settings.snapshot().accessibility
	prefs.ui_scale = "large"
	scene.settings.set_accessibility(prefs)
	_approach()
	scene.bloom.interact()
	await wait_process_frames(8)
	var footer: Control = scene.bloom.panel.page.get_meta("footer") as Control
	assert_true(footer.is_visible_in_tree())
	assert_lte(footer.get_global_rect().end.y,600.0)
	var observe: Button = scene.bloom.panel.page.find_child("ObserveBloom",true,false) as Button
	var collect: Button = scene.bloom.panel.page.find_child("CollectBloom",true,false) as Button
	assert_false(observe.disabled)
	assert_false(collect.disabled)
	assert_eq(observe.get_node(observe.focus_next),collect)
	assert_true(collect.get_node(collect.focus_next).is_visible_in_tree())

func test_arrival_spirals_around_vessel_pauses_then_scatters_without_story_effects() -> void:
	var visual: LightBloomVisual = scene.bloom.visual
	var at: Vector2 = Vector2(1280,480)
	assert_eq(visual.global_position,Vector2(1330,590))
	visual.advance_arrival(0.0,at,true)
	assert_true(visual.arrival_active())
	assert_eq(visual.arrival_center,visual.to_local(at))
	visual.advance_arrival(1.0,at,true)
	var elapsed: float = visual.arrival_elapsed
	visual.advance_arrival(10.0,at,false)
	assert_eq(visual.arrival_elapsed,elapsed)
	visual.advance_arrival(3.2,at,true)
	assert_false(visual.arrival_active())
	assert_eq(visual.arrival_center,Vector2.ZERO)
	visual.advance_arrival(0.1,at,true)
	assert_false(visual.arrival_active())
	assert_eq(scene.story.snapshot(),StoryState.fresh())
func test_reduced_effects_and_restored_outcomes_never_replay_arrival() -> void:
	var visual: LightBloomVisual = scene.bloom.visual
	visual.reduced_effects = true
	visual.advance_arrival(0.1,Vector2(1280,480),true)
	assert_false(visual.arrival_active())
	assert_eq(visual.arrival_center,Vector2.ZERO)
	visual.reduced_effects = false
	visual.advance_arrival(1.0,Vector2(1280,480),true)
	assert_false(visual.arrival_active())
	visual.set_outcome(false,true)
	visual.advance_arrival(1.0,Vector2(1280,480),true)
	assert_false(visual.arrival_active())
	assert_eq(visual.reaction,0.0)
func test_bottled_plankton_is_extinguished_without_a_seabed_stump() -> void:
	_collect()
	assert_false(scene.bloom.visual.plankton_visible())
	assert_false(scene.bloom.visual.specimen_view)
	for node: Node in scene.bloom.panel.body.find_children("*","Node2D",true,false):
		if node is LightBloomVisual:
			assert_true(node.specimen_view)
			assert_false(node.plankton_visible())
	assert_eq(ExpeditionSchema.decode(scene.saves.snapshot()).error,OK)
	assert_eq(scene.story.definition(LightBloomEncounter.OBSERVE).resonance_delta,15)
	assert_eq(scene.story.definition(LightBloomEncounter.COLLECT).resonance_delta,-15)
func test_bloom_text_uses_character_roles_and_keeps_the_anomaly_unexplained() -> void:
	_approach()
	scene.bloom.interact()
	var text: String = ""
	for node: Node in scene.bloom.panel.body.get_children():
		if node is Label: text += node.text
	assert_true(text.contains("plankton"))
	assert_true(text.contains("spiral"))
	assert_true(text.contains("Dr. Okafor"))
	assert_true(text.contains("Director Crane"))
	text += scene.story.definition(LightBloomEncounter.OBSERVE).response_text
	text += scene.story.definition(LightBloomEncounter.COLLECT).response_text
	text += scene.research.definition(LightBloomEncounter.SCAN).description
	for secret: String in ["Vael","Hush","Deep Heart","betrayal","Lantern-1"]:
		assert_false(text.contains(secret))
func test_response_reading_layout_is_safe_when_the_viewport_has_no_focus() -> void:
	_collect()
	await wait_process_frames(4)
	viewport.gui_release_focus()
	assert_null(viewport.gui_get_focus_owner())
	scene.bloom.panel._reset_read_scroll()
	assert_true(scene.bloom.modal())

func test_pending_reading_reflow_is_disconnected_when_a_panel_is_destroyed() -> void:
	var transient: BloomChoicePanel = BloomChoicePanel.new()
	add_child(transient)
	transient.setup(scene.bloom)
	transient.show_response("Wick: Reading stored.")
	transient._queue_read_scroll()
	var callback: Callable = transient._reset_read_scroll
	assert_true(get_tree().process_frame.is_connected(callback))
	transient.free()
	assert_false(callback.is_valid())
	await wait_process_frames(4)
	assert_true(is_instance_valid(scene.bloom.panel))
