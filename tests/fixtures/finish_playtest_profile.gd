extends "res://tests/fixtures/drive_twilight_expedition.gd"
## Second half of tools/build_playtest_profile.py. Runs on the game's DEFAULT save paths, so the
## files it leaves are exactly the ones a release build reads. Continue from the Twilight checkpoint
## that drive_twilight_expedition.gd wrote, return to Halcyon at the tether with real controller
## input, and leave the last checkpoint at the dock with the Drowned Caves descent offered.
## Plain checks with push_error, not assert, so a failure is reported the same way in any build.


func _initialize() -> void:
	_keyboard = false
	_captures = ""
	_scene = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	_scene.settings_path = SettingsStore.DEFAULT_PATH
	_scene.expedition_path = ""
	root.add_child(_scene)
	root.size = Vector2i(1280,800)
	await _frames(10)
	if OS.get_cmdline_user_args().has("--check"):
		await _check_template()
		return
	if not _scene.saves.has_checkpoint() or _scene.journey.state.get("phase")!="twilight" or not _scene.journey.expedition.concluded():
		_fail("the default save path does not hold a concluded Twilight checkpoint")
		return
	await _activate(_control("Begin"))
	await _wait_transfer()
	if not _scene.journey.active():
		_fail("Continue did not resume the Twilight expedition")
		return
	await _move(TwilightShelfLayout.SPAWN)
	await _interact()
	await _activate(_control("ReturnHalcyon"))
	await _wait_transfer()
	if not _scene.journey.at_station() or not _scene.revision.ui.dock_page.visible:
		_fail("the tether return did not reach the Halcyon dock")
		return
	if not _scene.journey.caves_entry_available() or _control("CavesDescent")==null:
		_fail("the dock does not offer Descend to the Drowned Caves")
		return
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(ExpeditionStore.DEFAULT_PATH))
	if not stored is Dictionary or (stored as Dictionary).get("region_id")==ExpeditionJourneyState.TWILIGHT:
		_fail("the last checkpoint on disk is not at the dock")
		return
	var ranks: Dictionary = _scene.revision.campaign.ranks
	print("PLAYTEST_PROFILE_DOCK_PASS region=",stored.region_id," hull_rank=",int(ranks.hull)," sonar_rank=",int(ranks.sonar)," engine_rank=",int(ranks.engine))
	await _finish_process()


## --check, in a separate process on a throwaway copy: the facilitator's own check. Continue on the
## finished template must land at the dock with the descent offered.
func _check_template() -> void:
	if not _scene.saves.has_checkpoint() or _scene.journey.state.get("phase")!="refit":
		_fail("the template's checkpoint is not at the dock")
		return
	await _activate(_control("Begin"))
	await _wait_transfer()
	if not _scene.journey.at_station() or not _scene.revision.ui.dock_page.visible or _control("CavesDescent")==null:
		_fail("Continue on the template did not land at the dock with the descent offered")
		return
	print("PLAYTEST_PROFILE_CHECK_PASS")
	await _finish_process()


func _fail(reason: String) -> void:
	push_error("PLAYTEST_PROFILE_FAIL "+reason)
	quit(1)
