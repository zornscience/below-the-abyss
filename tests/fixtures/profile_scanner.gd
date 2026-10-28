extends SceneTree
## Isolated API workload, not an expedition walkthrough or frame-rate claim.
func _initialize() -> void:
	var game: ShelfPrototype = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta051-scanner-benchmark.json"
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child.call_deferred(game)
	for unused: int in range(6): await process_frame
	var known: Array[StringName] = []
	for point: Resource in game.discoveries._catalog.points: known.append(point.stable_id)
	game.discoveries.restore_discoveries(known)
	if OS.get_cmdline_user_args().has("--baseline-targets"):
		var control: Array[StringName] = [&"shelf-calibration-plate",&"shelf-overlook-formation",&"outer-hydrophone-record",&"outer-vent-study",&"lost-expedition-blackbox",&"observer-ecology",&"zone1-light-bloom-scan",&"sunlit-lantern1-buoy-record"]
		for id: StringName in game.submarine.scanner._targets.keys():
			if id not in control: game.submarine.scanner._targets.erase(id)
	var samples: Array[float] = []
	for batch: int in range(7):
		var start: int = Time.get_ticks_usec()
		for call_index: int in range(1000): game.submarine.scanner.snapshot()
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	print("SCANNER_BENCH ",JSON.stringify({"calls_per_batch":1000,"batches":7,"median_ms":samples[3],"samples_ms":samples,"targets":game.submarine.scanner._targets.size()}))
	game.queue_free()
	for unused: int in range(3): await process_frame
	quit()
