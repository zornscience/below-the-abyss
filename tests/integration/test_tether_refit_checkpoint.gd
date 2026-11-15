extends GutTest
## Regression guard for the voluntary ascent-tether return (Twilight -> Halcyon refit).
## The golden files were recorded on main at 93b6070, BEFORE the refit candidate was
## extracted into a helper shared with vessel recovery. The written checkpoint must stay
## byte-identical. Re-recording is only legitimate for an approved behaviour change:
## run with BTA_RECORD_REFIT_GOLDEN=1 (the test then fails on purpose) and review the diff.
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
const GOLDEN_DIR: String = "res://tests/fixtures/golden/"
var game: ShelfPrototype
var path: String


func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = MAIN.instantiate() as ShelfPrototype
	# Fixed file name: the checkpoint text must not depend on the test clock.
	path = "user://refit-golden.json"
	_remove_files()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	view.add_child(game)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)


func after_each() -> void:
	_remove_files()


func _remove_files() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))


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


## Deterministic depleted supplies at the tether, then the real voluntary return.
func _return_at_tether() -> String:
	game.submarine.set_simulation_enabled(false)
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	game.submarine.velocity = Vector2.ZERO
	var pools: SubmarineResourceSystem = game.submarine.resource_system
	assert_eq(pools.restore_snapshot(37.5,12.25),OK)
	assert_eq(game.submarine.hull_system.restore_snapshot(41.0),OK)
	game.torpedoes.ammunition = 3
	assert_true(game.journey.near_tether())
	assert_eq(game.saves.transfer_chapter("refit",true),OK)
	assert_true(game.journey.at_station())
	return FileAccess.get_file_as_string(game.saves.store.path)


func _match_golden(name: String, written: String) -> void:
	assert_false(written.is_empty(),"refit wrote a checkpoint file")
	var golden: String = GOLDEN_DIR+name
	if OS.get_environment("BTA_RECORD_REFIT_GOLDEN")=="1":
		var file: FileAccess = FileAccess.open(golden,FileAccess.WRITE)
		file.store_string(written)
		file.close()
		fail_test("Recorded "+golden+". Review the diff, then run without BTA_RECORD_REFIT_GOLDEN.")
		return
	assert_true(FileAccess.file_exists(golden),"golden file present: "+golden)
	assert_eq(written,FileAccess.get_file_as_string(golden),"voluntary tether return writes the same checkpoint as before the refit-helper extraction")


func test_voluntary_tether_return_before_mission_resolution_writes_unchanged_checkpoint() -> void:
	_deploy()
	watch_signals(game.missions)
	var written: String = _return_at_tether()
	assert_eq(game.missions.snapshot()[String(TwilightShelfData.MISSION)].state,"accepted")
	assert_signal_not_emitted(game.missions,"mission_completed")
	_match_golden("tether_refit_accepted.json",written)


func test_voluntary_tether_return_with_all_evidence_writes_unchanged_completing_checkpoint() -> void:
	_deploy()
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]:
		await _study(id)
	game.submarine.global_position = TwilightShelfData.NET-Vector2(90,0)
	assert_eq(game.story.apply_choice(TwilightShelfData.RELEASE),OK)
	game.revision.ui.radio_page.hide()
	watch_signals(game.missions)
	var written: String = _return_at_tether()
	assert_eq(game.missions.snapshot()[String(TwilightShelfData.MISSION)].state,"completed")
	assert_signal_emit_count(game.missions,"mission_completed",1)
	_match_golden("tether_refit_completed.json",written)
