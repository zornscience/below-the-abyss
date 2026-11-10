class_name CombatBoxObserver
extends PlaytestObserver
## Existing local recorder/store and wall-clock lifecycle, isolated from campaign signals.
var player: SubmarineController
func setup_box(vessel: SubmarineController,weapon: TorpedoLauncher) -> void:
	player = vessel
	process_mode = Node.PROCESS_MODE_ALWAYS
	var build: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/playtesting/build_info.json"))
	if build is Dictionary: _build_id = String(build.get("build_id","source"))
	_link(player.sonar.pulse_emitted,_ping)
	_link(weapon.fired,func(_id: StringName) -> void: observe("combat_torpedo","fired"))
	_link(player.hull_system.hull_changed,_hull_changed)
func _baseline() -> void:
	_hull = player.hull_system.hull
	_low = {}
func _restoring() -> bool:
	return false
func _resource(_kind: String,_value: float,_maximum: float) -> void:
	pass
func start() -> Error:
	var result: Error = recorder.begin(_build_id,true)
	if result!=OK: return result
	_baseline()
	_last_usec = Time.get_ticks_usec()
	_since_write = 0
	_active = player.is_physics_processing()
	return export_report()
func observe(kind: String,detail: String,amount: float = 0) -> void:
	_record(kind,detail,amount)
func _process(_delta: float) -> void:
	_tick()
	_active = player.is_physics_processing()
	if recorder.recording and _since_write>=15:
		_since_write = 0
		var result: Error = store.write_report(recorder.snapshot())
		if result!=OK:
			status = "Local checkpoint failed: "+error_string(result)
			status_changed.emit()

func _hull_changed(value: float,_maximum: float) -> void:
	if value<_hull:
		var source: String = String(player.hull_system.last_damage_source)
		_record("damage","impact" if source=="collision" else "creature",_hull-value)
	_hull = value
