extends "res://tests/fixtures/capture_expedition_save.gd"
## Native, input-driven chapter. No vessel teleports, injected evidence or completion flags.
var _started: int
var _story_events: Array[StringName] = []


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/testing/bta-042-" + name + ".png") == OK)


func _spawn() -> void:
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta042-native.json"
	_scene.expedition_path = "user://bta042-native-expedition.json"
	root.add_child.call_deferred(_scene)
	await _frames(5)
	_scene.narrative.record_unlocked.connect(func(id: StringName) -> void:
		_story_events.append(id)
		print("BTA042_RECORD_UNLOCKED ", id))
	_scene.narrative.chapter_concluded.connect(func() -> void:
		_story_events.append(&"concluded")
		print("BTA042_CHAPTER_CONCLUDED"))


func _read(id: StringName) -> void:
	for index: int in range(_scene.narrative.available_entries().size()):
		if _scene.narrative.available_entries()[index].stable_id == id:
			(_scene.expedition_log.entry_list.get_child(index) as Button).grab_focus()
			await _tap_button(JOY_BUTTON_A)
			return
	push_error("Native walkthrough tried to read an unavailable record: " + String(id))
	quit(1)


func _open_log() -> void:
	await _tap_key(KEY_ESCAPE)
	(_scene.route_menu.get_node("%OpenStory") as Button).grab_focus()
	await _tap_key(KEY_ENTER)


func _back_to_pilot() -> void:
	await _tap_button(JOY_BUTTON_B)
	await _tap_key(KEY_ENTER)
	assert(_scene.submarine.is_physics_processing())


func _shutdown() -> void:
	_scene.submarine.set_simulation_enabled(false)
	_scene.audio.set_process(false)
	_scene.audio.stop_cues()
	for player: AudioStreamPlayer in _scene.audio._loops.values():
		player.stop()
		player.stream = null
	await create_timer(0.3).timeout
	quit()


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--continue-story"):
		var replayed: Array[StringName] = []
		var observe: Callable = func(node: Node) -> void:
			if node is NarrativeService:
				(node as NarrativeService).record_unlocked.connect(func(id: StringName) -> void: replayed.append(id))
				(node as NarrativeService).chapter_concluded.connect(func() -> void: replayed.append(&"concluded"))
		node_added.connect(observe)
		await _spawn()
		await _tap_button(JOY_BUTTON_A)
		_scene.open_route_menu()
		assert(_scene.narrative.is_concluded())
		assert(_scene.research.is_completed(NarrativeService.PLATE))
		assert(_scene.narrative.available_entries().size() == 7)
		assert(replayed.is_empty())
		_scene.open_story()
		await _capture("continued-log")
		assert(_scene.expedition_log.detail.text.contains("CHAPTER CONCLUDED"))
		await _back_to_pilot()
		var before: Vector2 = _scene.submarine.global_position
		Input.action_press("move_right")
		await _frames(12)
		Input.action_release("move_right")
		assert(_scene.submarine.global_position.x > before.x)
		print("BTA042_FRESH_PROCESS_CONTINUE_OK entries=7 concluded=true replayed_story_events=0 movement_after_load=true")
		await _shutdown()
		return
	for path: String in ["user://bta042-native.json", "user://bta042-native-expedition.json", "user://bta042-native.json.missions.json", "user://bta042-native.json.upgrades.json", "user://bta042-native.json.discoveries.json", "user://bta042-native.json.research.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".rejected"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	await _spawn()
	_started = Time.get_ticks_usec()
	await _capture("opening")
	(_scene.route_menu.get_node("%OpenStory") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	await _capture("briefing")
	_scene.expedition_log.begin_button.grab_focus()
	await _tap_button(JOY_BUTTON_A)
	assert(_scene.missions.snapshot()[String(NarrativeService.MAIN)].state == "accepted")
	await _back_to_pilot()
	await _fly_to(Vector2(760, 480))
	await _tap_key(KEY_F)
	await _frames(65)
	assert(_scene.discoveries.state_of(NarrativeService.MARKER) == DiscoveryRegistry.State.DISCOVERED)
	assert(not _scene.research.is_completed(NarrativeService.PLATE))
	assert(_scene.submarine.passive.contacts_snapshot().size() > 0)
	await _open_log()
	await _read(&"shelf-damaged-marker")
	await _capture("first-clue")
	await _back_to_pilot()
	await _tap_key(KEY_E)
	await _frames(190)
	assert(_scene.research.is_completed(NarrativeService.PLATE))
	await _capture("scan-recovered")
	await _open_log()
	await _read(&"shelf-expedition-field-record")
	await _capture("field-record")
	await _back_to_pilot()
	for name: String in ShelfRouteDriver.OUTBOUND:
		await _fly_to(_point(name))
	await _tap_key(KEY_F)
	await _frames(65)
	assert(_scene.discoveries.state_of(NarrativeService.SPIRES) == DiscoveryRegistry.State.DISCOVERED)
	assert(_scene.predator.threat.phase == PredatorState.Phase.QUIET)
	await _capture("spires")
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	assert(_scene.route_check.stage == GrayboxRouteCheck.Stage.COMPLETE)
	assert(_scene.narrative.can_debrief())
	await _tap_key(KEY_E)
	(_scene.station_menu.get_node("%OpenStationStory") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(not _scene.narrative.is_concluded())
	await _capture("return-review")
	_scene.expedition_log.debrief_button.grab_focus()
	await _tap_button(JOY_BUTTON_A)
	assert(_scene.narrative.is_concluded())
	var wall_seconds: float = (Time.get_ticks_usec() - _started) / 1000000.0
	await _capture("debrief")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("compact-log")
	(_scene.expedition_log.get_node("%StoryDown") as Button).grab_focus()
	for _index: int in range(5):
		await _tap_button(JOY_BUTTON_A)
	await _capture("compact-hook")
	root.size = Vector2i(1280, 800)
	await _tap_button(JOY_BUTTON_B)
	(_scene.station_menu.get_node("%ServiceAll") as Button).grab_focus()
	await _tap_button(JOY_BUTTON_A)
	await _tap_button(JOY_BUTTON_B)
	await _tap_key(KEY_ESCAPE)
	(_scene.route_menu.get_node("%SaveExpedition") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	assert(_scene.saves.status.begins_with("Expedition saved"))
	assert(_story_events.count(&"concluded") == 1)
	print("BTA042_NATIVE_CHAPTER_OK automated_wall_seconds=%.3f active_route_seconds=%.3f entries=%d chapter_events=%d predator_required=false direct_completion_flags=false" % [wall_seconds, _scene.route_check.elapsed_seconds, _scene.narrative.available_entries().size(), _story_events.count(&"concluded")])
	await _shutdown()
