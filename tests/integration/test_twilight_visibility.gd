extends GutTest
var game: ShelfPrototype
var path: String
func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(800,600)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://bta055-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	view.add_child(game)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.set_simulation_enabled(false)
	await wait_physics_frames(3)
func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func _deploy() -> void:
	game.journey.prepare({"phase":"twilight","commissioned":true})
	game.submarine.global_position = TwilightShelfLayout.SPAWN
func test_visibility_scopes_accepted_pings_pause_and_restore_without_discovering() -> void:
	var view: TwilightVisibility = game.journey.visibility
	assert_gte(view.contours.get_child_count(),game.journey.layout.bodies.size())
	game.submarine.sonar.pulse_emitted.emit(AcousticEvent.create(&"test/early",&"test/source",&"active_sonar",&"scientific",Vector2.ZERO,1,100,0))
	assert_eq(view.speeds[0],0.0)
	_deploy()
	game.submarine.global_position = TwilightShelfLayout.SPAWN
	var before: Dictionary = game.saves.progress_snapshot()
	assert_eq(game.submarine.sonar.request_ping(),OK)
	assert_gt(view.speeds[0],0.0)
	var old_speed: float = view.speeds[0]
	var changed: ActiveSonarProfile = game.submarine.sonar.configuration.duplicate() as ActiveSonarProfile
	changed.travel_speed *= 2
	assert_eq(game.submarine.sonar.configure(changed),OK)
	assert_eq(game.submarine.sonar.pulse_speed(game.submarine.sonar._last_ping),old_speed)
	var origin: Vector4 = view.pings[0]
	game.submarine.set_simulation_enabled(false)
	view._process(0.5)
	assert_eq(view.pings[0].z,0.0)
	assert_eq(game.saves.progress_snapshot(),before)
	assert_eq(view.pings[0].x,origin.x)
	view.clear_echoes()
	assert_eq(view.speeds[0],0.0)
