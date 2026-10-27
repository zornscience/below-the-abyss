extends SceneTree
## Staged native UI comparisons, not a substitute for the input-driven chapter route.
var game: ShelfPrototype
var directory: String
var modern: bool
func frames(count: int = 8) -> void:
	for index: int in range(count): await physics_frame
func shot(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join(name+".png"))==OK)
	var deck: Control = game.hud.get_node("%InstrumentDeck") as Control
	print("HUD_CAPTURE ",name," viewport=",root.size," resources_rect=",deck.get_global_rect()," resource_area_percent=",deck.size.x*deck.size.y/(root.size.x*root.size.y)*100.0)
func _initialize() -> void:
	directory = OS.get_environment("BTA_EVIDENCE_DIR")
	assert(not directory.is_empty())
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta048-capture-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child.call_deferred(game)
	await frames()
	modern = game.hud.has_method("identity_container")
	root.size = Vector2i(1280,800)
	game.settings.set_onboarding({"enabled":false,"seen":[]})
	var audio: Dictionary = game.settings.snapshot().audio
	audio.muted = true
	game.settings.set_audio(audio)
	game.chapter.start()
	game.chapter.launch()
	game.submarine.global_position = Vector2(1280,480)
	(game.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	await shot("after-normal-1280" if modern else "before-normal-1280")
	game.submarine.hull_system.apply_damage(8,&"capture")
	game.submarine.resource_system.consume_battery(46)
	game.submarine.resource_system.consume_oxygen(72)
	await shot("after-colors-1280" if modern else "before-colors-1280")
	if modern:
		game.submarine.sonar.request_ping()
		game.submarine.sonar.advance(2)
		game.bloom.interact()
		game.bloom.choose_observe()
		game.submarine.scanner.advance(3)
		game.bloom.leave()
		game.submarine.sonar.advance(10)
		game.submarine.global_position = Vector2(3500,620)
		(game.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
		game.submarine.sonar.request_ping()
		game.submarine.sonar.advance(2)
		game.submarine.scanner.request_scan(SunlitShallowsData.BUOY)
		game.submarine.scanner.advance(4)
		var before: float = game.submarine.position.x
		Input.action_press("move_right")
		await frames(15)
		assert(game.submarine.position.x>before)
		assert(game.submarine.is_physics_processing())
		await shot("after-incoming-radio-1280")
		Input.action_release("move_right")
		game.revision.ui.get("notifications").toggle()
		await shot("after-transcript-1280")
		game.revision.ui.get("notifications").collapse()
		root.size = Vector2i(800,600)
		var preferences: Dictionary = SettingsStore.default_accessibility()
		preferences.ui_scale = "large"
		preferences.high_contrast = true
		preferences.reduced_motion = true
		preferences.reduced_flashing = true
		game.settings.set_accessibility(preferences)
		game.submarine.damage_system.set_maximum_depth_m(120)
		await shot("after-large-contrast-800")
		game.revision.ui.get("notifications").toggle()
		game.revision.ui.get("notifications").scroll.scroll_vertical = 100
		await shot("after-transcript-large-800")
		game.revision.ui.get("notifications").collapse()
		root.size = Vector2i(1920,1080)
		game.settings.set_accessibility(SettingsStore.default_accessibility())
		await shot("after-wide-1920")
	else:
		root.size = Vector2i(800,600)
		var preferences: Dictionary = SettingsStore.default_accessibility()
		preferences.ui_scale = "large"
		preferences.high_contrast = true
		game.settings.set_accessibility(preferences)
		await shot("before-large-contrast-800")
	game.queue_free()
	await frames(4)
	print("COMPACT_CAPTURE_PASS baseline=",not modern)
	quit()
