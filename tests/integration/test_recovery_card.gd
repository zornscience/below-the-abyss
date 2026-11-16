extends GutTest
## Recovery card polish: the accept delay (real Space and gamepad A), held and echoed
## input, the footer, and the Twilight casualty retry before the recovery checkpoint.
## Public APIs only: no private members of other classes are called.
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var path: String
var pools: SubmarineResourceSystem
var flow: VesselRecoveryFlow
var _blocker: String = ""
## Longest frame seen since the failure was triggered (see the accept-delay test).
var _longest_frame_seconds: float = 0.0


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://recovery-card-%d.json" % Time.get_ticks_usec()
	game = MAIN.instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	pools = game.submarine.resource_system
	flow = game.journey.recovery


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
	await get_tree().process_frame
	if not _blocker.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(_blocker))
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))


# ---------------------------------------------------------------- helpers

func _hide_pages() -> void:
	game.revision.ui.title_page.hide()
	game.revision.ui.radio_page.hide()
	game.revision.ui.dock_page.hide()
	game.route_layer.hide()


func _space(pressed: bool, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	return event


func _button_a(pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Bounded wait: false (a test failure, never a hang) if the card is gone or never ready.
func _until_ready() -> bool:
	for frame: int in range(600):
		if flow.accept_ready(): return true
		if not flow.pending: return false
		await get_tree().process_frame
		_note_frame()
	return false


## The test resumes on process_frame before nodes process, so this is the delta the
## flow is about to add in the same frame.
func _note_frame() -> void:
	_longest_frame_seconds = maxf(_longest_frame_seconds,get_process_delta_time())


## Sunlit hull failure through the real damage path. Returns the trigger time in ms.
func _sunlit_hull_failure() -> int:
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = SunlitSurveyData.MAIN_ROUTE[0]
	game.submarine.velocity = Vector2.ZERO
	_hide_pages()
	game.resume_route()
	var started: int = Time.get_ticks_msec()
	_longest_frame_seconds = 0.0
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"collision")
	for frame: int in range(10):
		await get_tree().process_frame
		_note_frame()
		if flow.pending: break
	assert_true(flow.pending,"hull failure shows the recovery card")
	assert_true(flow.committed)
	return started


func _deploy_twilight_at_net() -> void:
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
	_hide_pages()
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	game.submarine.velocity = Vector2.ZERO
	assert_true(game.journey.active())


## A sentinel casualty whose save fails: the story writer refuses once.
func _failed_casualty(original: Callable) -> void:
	game.story.checkpoint_writer = func(_value: Dictionary,_choice: StringName) -> Error: return ERR_CANT_CREATE
	game.journey.expedition.health.apply_blast(&"test/unsaved-casualty",TwilightShelfData.NET,200,100)
	assert_true(game.journey.expedition.pending_loss,"the casualty record failed to save")
	assert_false(game.story.has_decision(TwilightShelfData.LOST))
	game.story.checkpoint_writer = original


## Life support expires through the real countdown, with hull intact.
func _expire_life_support() -> void:
	assert_eq(pools.restore_snapshot(pools.battery,0.0),OK)
	_hide_pages()
	game.resume_route()
	await wait_physics_frames(2)
	assert_true(flow.countdown.running,"precondition: countdown running")
	flow.countdown.advance(flow.countdown.remaining,0.0)
	assert_true(flow.pending,"expiry shows the recovery card")


# ---------------------------------------------------------------- accept delay

func test_space_and_gamepad_a_are_ignored_early_and_accepted_after_the_fade_plus_delay() -> void:
	assert_true(InputMap.event_is_action(_space(true),&"ui_accept"),"Space is ui_accept")
	assert_true(InputMap.event_is_action(_button_a(true),&"ui_accept"),"gamepad A is ui_accept")
	for controller: bool in [false,true]:
		var started: int = await _sunlit_hull_failure()
		await _wait(0.1)
		assert_false(flow.accept_ready(),"not ready at 0.1 s")
		await _send(_button_a(true) if controller else _space(true))
		await _send(_button_a(false) if controller else _space(false))
		assert_true(flow.pending,"accept at 0.1 s is ignored, controller=%s" % controller)
		assert_true(flow.panel.visible)
		assert_true(await _until_ready(),"card becomes ready for accept")
		var ready_ms: int = Time.get_ticks_msec()-started
		# The flow sums engine frame deltas. The first summed frame began before `started`
		# was read, so real time can trail the summed time by up to one frame. Allow the
		# longest frame actually measured (plus 1 ms tick rounding), not a guessed length.
		var slack_ms: int = ceili(_longest_frame_seconds*1000.0)+1
		assert_gte(ready_ms,int((VesselRecoveryFlow.FADE_SECONDS+VesselRecoveryFlow.ACCEPT_DELAY_SECONDS)*1000.0)-slack_ms,"ready only after the fade plus the delay: %d ms, longest frame %d ms" % [ready_ms,slack_ms-1])
		assert_eq(flow.backdrop.color.a,1.0,"the fade has finished before accept is allowed")
		await _send(_button_a(true) if controller else _space(true))
		assert_false(flow.pending,"accept after the delay continues, controller=%s" % controller)
		await _send(_button_a(false) if controller else _space(false))
		assert_true(game.submarine.is_physics_processing(),"piloting resumes at the Halcyon berth")


func test_held_and_echoed_accept_never_dismisses_the_card() -> void:
	await _sunlit_hull_failure()
	# Space pressed early and held: only key-repeat echoes follow, even after the delay.
	await _send(_space(true))
	assert_true(await _until_ready(),"card becomes ready for accept")
	await _send(_space(true,true))
	await _send(_space(true,true))
	assert_true(flow.pending,"echoes of a held key are ignored")
	await _send(_space(false))
	assert_true(flow.pending,"a release is not an accept")
	await _send(_space(true))
	assert_false(flow.pending,"a fresh press after the delay continues")
	await _send(_space(false))
	# Gamepad A held from before the card is ready: no new press, no dismissal.
	await _sunlit_hull_failure()
	await _send(_button_a(true))
	assert_true(await _until_ready(),"card becomes ready for accept")
	for frame: int in range(30): await get_tree().process_frame
	assert_true(flow.pending,"a held button does not dismiss the card")
	await _send(_button_a(false))
	await _send(_button_a(true))
	assert_false(flow.pending,"a fresh A press after the delay continues")
	await _send(_button_a(false))


func test_footer_shows_only_the_continue_hint() -> void:
	await _sunlit_hull_failure()
	assert_eq(flow.footer.text,"Enter / A: continue")
	assert_false(flow.footer.text.contains("Esc"))
	assert_eq(VesselRecoveryFlow.FOOTER_TEXT,"Enter / A: continue")


# ---------------------------------------------------------------- casualty retry before recovery

func test_failed_casualty_record_is_retried_before_the_recovery_checkpoint() -> void:
	_deploy_twilight_at_net()
	var original: Callable = game.story.checkpoint_writer
	_failed_casualty(original)
	# Record the order of the two writes: the casualty record, then the recovery checkpoint.
	var order: Array[String] = []
	game.story.checkpoint_writer = func(value: Dictionary,choice: StringName) -> Error:
		order.append("casualty")
		return original.call(value,choice)
	game.saves.status_changed.connect(func() -> void:
		if game.saves.status.begins_with("Halcyon recovery saved"): order.append("recovery"))
	await _expire_life_support()
	assert_eq(order,["casualty","recovery"],"casualty record first, then the recovery checkpoint")
	assert_true(flow.committed)
	assert_false(game.journey.expedition.pending_loss)
	assert_true(game.story.has_decision(TwilightShelfData.LOST),"the casualty is recorded")
	var saved: Dictionary = game.saves.store.read_file(game.saves.store.path)
	assert_eq(saved.error,OK)
	assert_true(String(TwilightShelfData.LOST) in saved.data.story.decisions,"the recovery checkpoint keeps the casualty")
	assert_eq(saved.data.journey.phase,"refit","recovered to the Halcyon refit")
	assert_eq(saved.data.player.oxygen,pools.max_oxygen)
	assert_false(flow.body.text.contains(VesselRecoveryFlow.RETRY_TEXT))


func test_recovery_write_failure_shows_retry_text_then_retry_records_casualty_and_recovers() -> void:
	_deploy_twilight_at_net()
	var original: Callable = game.story.checkpoint_writer
	_failed_casualty(original)
	var order: Array[String] = []
	game.story.checkpoint_writer = func(value: Dictionary,choice: StringName) -> Error:
		order.append("casualty")
		return original.call(value,choice)
	game.saves.status_changed.connect(func() -> void:
		if game.saves.status.begins_with("Halcyon recovery saved"): order.append("recovery"))
	# Block every checkpoint write: a regular file where the save directory should be.
	var saved_path: String = game.saves.store.path
	_blocker = "user://recovery-block-%d" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(_blocker,FileAccess.WRITE)
	file.store_string("blocks a directory")
	file.close()
	game.saves.store.path = _blocker+"/expedition.json"
	await _expire_life_support()
	assert_eq(order,["casualty"],"the casualty record is retried first, and fails")
	assert_false(flow.committed,"the recovery checkpoint cannot be written")
	assert_true(flow.body.text.ends_with(VesselRecoveryFlow.RETRY_TEXT),"retry text shown: "+flow.body.text)
	assert_true(flow.pending)
	assert_true(game.journey.expedition.pending_loss)
	assert_false(game.submarine.is_physics_processing(),"the card holds the simulation")
	# Storage recovers. Enter retries: casualty first, then the recovery checkpoint.
	game.saves.store.path = saved_path
	assert_true(await _until_ready(),"card becomes ready for accept")
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	await _send(enter)
	assert_eq(order,["casualty","casualty","recovery"],"retry records the casualty, then recovers")
	assert_true(flow.committed)
	assert_true(flow.pending,"the retry press saves. The next press continues.")
	assert_false(flow.body.text.contains(VesselRecoveryFlow.RETRY_TEXT),"retry line cleared after success")
	assert_true(game.story.has_decision(TwilightShelfData.LOST))
	enter.pressed = false
	await _send(enter)
	enter.pressed = true
	await _send(enter)
	assert_false(flow.pending)
	assert_true(game.journey.at_station())


# ---------------------------------------------------------------- casualty pending when the hull is destroyed

## Hull destruction in Twilight through the real damage path, with the card shown.
func _twilight_hull_failure() -> void:
	_hide_pages()
	game.resume_route()
	await wait_physics_frames(2)
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"collision")
	for frame: int in range(10):
		await get_tree().process_frame
		if flow.pending: break
	assert_true(flow.pending,"hull failure shows the recovery card")


func _block_storage() -> String:
	var saved_path: String = game.saves.store.path
	_blocker = "user://recovery-block-%d" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(_blocker,FileAccess.WRITE)
	file.store_string("blocks a directory")
	file.close()
	game.saves.store.path = _blocker+"/expedition.json"
	return saved_path


func _press_enter() -> void:
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	await _send(enter)
	enter.pressed = false
	await _send(enter)


## Status lines of every checkpoint attempt, in order.
func _record_statuses() -> Array[String]:
	var statuses: Array[String] = []
	game.saves.status_changed.connect(func() -> void: statuses.append(game.saves.status))
	return statuses


func _count_prefix(statuses: Array[String],prefix: String) -> int:
	var count: int = 0
	for line: String in statuses:
		if line.begins_with(prefix): count += 1
	return count


## The deadlock this fixes: with the hull at zero the story writer refuses the casualty
## record, and the coordinator refuses every other write while the casualty is pending.
func test_unsaved_casualty_then_hull_destruction_recovers_in_one_checkpoint_with_the_casualty() -> void:
	_deploy_twilight_at_net()
	var original: Callable = game.story.checkpoint_writer
	_failed_casualty(original)
	var story_writes: Array[String] = []
	game.story.checkpoint_writer = func(value: Dictionary,choice: StringName) -> Error:
		story_writes.append("story")
		return original.call(value,choice)
	var statuses: Array[String] = _record_statuses()
	var saved_path: String = _block_storage()
	await _twilight_hull_failure()
	assert_eq(game.submarine.hull_system.hull,0.0,"the hull is destroyed and stays so while recovery cannot be saved")
	assert_false(flow.committed,"storage is down, so nothing is recorded")
	assert_true(flow.body.text.ends_with(VesselRecoveryFlow.RETRY_TEXT),"retry text shown: "+flow.body.text)
	assert_true(game.journey.expedition.pending_loss,"the casualty is still pending")
	assert_false(game.story.has_decision(TwilightShelfData.LOST))
	assert_eq(_count_prefix(statuses,"Halcyon recovery saved"),0)
	# Storage recovers. Enter after the accept delay saves once.
	game.saves.store.path = saved_path
	var before: Dictionary = game.saves.store.read_file(saved_path)
	var already_lost: bool = before.error==OK and String(TwilightShelfData.LOST) in before.data.story.decisions
	assert_false(already_lost,"precondition: no checkpoint holds the casualty yet")
	assert_true(await _until_ready(),"card becomes ready for accept")
	statuses.clear()
	story_writes.clear()
	await _press_enter()
	assert_true(flow.committed,"the retry press saved the recovery")
	assert_eq(_count_prefix(statuses,"Halcyon recovery saved"),1,"exactly one recovery checkpoint: %s" % str(statuses))
	assert_eq(_count_prefix(statuses,"Not saved"),0,"no failed write on the retry: %s" % str(statuses))
	assert_eq(_count_prefix(statuses,"Story decision saved"),0,"the casualty is not written on its own: %s" % str(statuses))
	assert_false(flow.body.text.contains(VesselRecoveryFlow.RETRY_TEXT),"retry line cleared after success")
	var saved: Dictionary = game.saves.store.read_file(game.saves.store.path)
	assert_eq(saved.error,OK)
	assert_true(String(TwilightShelfData.LOST) in saved.data.story.decisions,"the one checkpoint contains the casualty decision")
	assert_eq(saved.data.journey.phase,"refit","recovered at the Halcyon refit")
	assert_eq(saved.data.player.hull,game.submarine.hull_system.max_hull,"hull restocked")
	assert_eq(saved.data.player.oxygen,pools.max_oxygen)
	assert_true(game.story.has_decision(TwilightShelfData.LOST),"the live story state matches the checkpoint")
	assert_false(game.journey.expedition.pending_loss,"the pending casualty is cleared")
	assert_eq(saved.data.keys().size(),12,"schema still has twelve top-level fields")
	assert_false(game.revision.ui.notifications.texts.has("twilight-released-casualty"),"the LOST decision has no released-animal notice, as on the normal path")
	assert_true(flow.pending,"the retry press saves. The next press continues.")
	await _press_enter()
	assert_false(flow.pending)
	assert_true(game.journey.at_station())


## A released animal's casualty is a flag, not the LOST decision. A flag write carries no
## choice id, so the story writer does not refuse it at zero hull: it deadlocks only when the
## writer itself keeps failing while storage is fine. The recovery must still carry the flag.
func test_released_sentinel_casualty_with_a_failing_story_writer_records_the_flag_in_the_recovery() -> void:
	_deploy_twilight_at_net()
	var original: Callable = game.story.checkpoint_writer
	# The release itself is not under test: apply it without its position and survey gates.
	game.story.checkpoint_writer = func(_value: Dictionary,_choice: StringName) -> Error: return OK
	assert_eq(game.story.apply_choice(TwilightShelfData.RELEASE),OK)
	game.story.checkpoint_writer = original
	_failed_casualty(original)
	# The story writer keeps failing (the retry before recovery cannot record the casualty).
	game.story.checkpoint_writer = func(_value: Dictionary,_choice: StringName) -> Error: return ERR_CANT_CREATE
	assert_false(game.story.has_flag(&"zone2-released-sentinel-lost"))
	var statuses: Array[String] = _record_statuses()
	await _twilight_hull_failure()
	assert_true(flow.committed,"recovery saves with the casualty inside it")
	assert_eq(_count_prefix(statuses,"Halcyon recovery saved"),1,str(statuses))
	assert_eq(_count_prefix(statuses,"Not saved"),0,str(statuses))
	var saved: Dictionary = game.saves.store.read_file(game.saves.store.path)
	assert_eq(saved.error,OK)
	assert_true("zone2-released-sentinel-lost" in saved.data.story.flags,"the casualty flag is in the recovery checkpoint")
	assert_false(String(TwilightShelfData.LOST) in saved.data.story.decisions,"a released animal does not get the LOST decision")
	assert_false(game.journey.expedition.pending_loss)
	assert_true(game.revision.ui.notifications.texts.has("twilight-released-casualty"),"the player is told, as on the normal casualty path")
	assert_true(String(game.revision.ui.notifications.texts["twilight-released-casualty"]).begins_with("The released sentinel has been killed."))


## The normal path is unchanged: a casualty that saves is written by the story writer on its
## own, and a later hull failure recovers without adding or duplicating it.
func test_saved_casualty_then_hull_destruction_writes_the_casualty_and_the_recovery_separately() -> void:
	_deploy_twilight_at_net()
	var statuses: Array[String] = _record_statuses()
	game.journey.expedition.health.apply_blast(&"test/saved-casualty",TwilightShelfData.NET,200,100)
	assert_false(game.journey.expedition.pending_loss,"the casualty saved immediately")
	assert_true(game.story.has_decision(TwilightShelfData.LOST))
	assert_eq(_count_prefix(statuses,"Story decision saved"),1,"the casualty is its own checkpoint: %s" % str(statuses))
	var decisions: Array = game.story.snapshot().decisions.duplicate()
	statuses.clear()
	await _twilight_hull_failure()
	assert_true(flow.committed)
	assert_eq(_count_prefix(statuses,"Halcyon recovery saved"),1,str(statuses))
	assert_eq(_count_prefix(statuses,"Story decision saved"),0,"recovery does not write the casualty again")
	var saved: Dictionary = game.saves.store.read_file(game.saves.store.path)
	assert_eq(saved.error,OK)
	assert_eq(saved.data.story.decisions,decisions,"decisions are unchanged, no duplicate casualty")
	assert_eq(saved.data.journey.phase,"refit")


## Recovery with nothing pending leaves the story snapshot exactly as it was.
func test_recovery_without_a_pending_casualty_does_not_touch_the_story() -> void:
	_deploy_twilight_at_net()
	var story_before: Dictionary = game.story.snapshot()
	assert_false(game.journey.expedition.pending_loss)
	assert_eq(game.journey.expedition.pending_casualty_story().error,ERR_DOES_NOT_EXIST,"nothing pending, nothing to prepare")
	await _twilight_hull_failure()
	assert_true(flow.committed)
	var saved: Dictionary = game.saves.store.read_file(game.saves.store.path)
	assert_eq(saved.error,OK)
	assert_eq(saved.data.story,story_before)
	assert_false(game.revision.ui.notifications.texts.has("twilight-released-casualty"),"no casualty, no casualty notice")
