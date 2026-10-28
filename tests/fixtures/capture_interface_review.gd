extends SceneTree
## Staged native UI review matrix; progression is exercised separately by normal-input routes.
var game: ShelfPrototype
var output: String
var prefix: String
var expected_size: Vector2i
var metrics: Dictionary = {}


func frames(count: int = 8) -> void:
	for index: int in range(count): await process_frame


func shot(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	assert(root.size==expected_size,str(root.size,expected_size))
	assert(root.get_texture().get_image().get_size()==expected_size)
	assert(root.get_texture().get_image().save_png(output.path_join(prefix+name+".png"))==OK)
	var fonts: Dictionary = {}
	for node: Node in game.find_children("*","Control",true,false):
		if (node is Label or node is BaseButton) and (node as Control).is_visible_in_tree():
			var pixels: int = (node as Control).get_theme_font_size("font_size")
			fonts[str(pixels)] = int(fonts.get(str(pixels),0))+1
	var focus: Control = root.gui_get_focus_owner()
	metrics[prefix+name] = {"width":expected_size.x,"height":expected_size.y,"visible_font_counts":fonts,
		"focus":String(focus.name) if focus!=null else "none"}
	print("INTERFACE_CAPTURE ",prefix,name)


func hide_pages() -> void:
	game.revision.ui.title_page.hide()
	game.revision.ui.radio_page.hide()
	game.revision.ui.dock_page.hide()
	game.expedition_log.hide()
	game.research_log.hide()
	game.accessibility_panel.hide()
	game.help_panel.hide()


func mode(dimensions: Vector2i,large: bool) -> void:
	expected_size = dimensions
	game = load("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	game.settings_path = "user://bta049-ui-review-%d.json" % Time.get_ticks_usec()
	game.expedition_path = game.settings_path+".expedition.json"
	root.add_child(game)
	await frames(12)
	root.size = dimensions
	await frames(12)
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "large" if large else "standard"
	prefs.high_contrast = large
	prefs.reduced_motion = true
	prefs.reduced_particles = true
	prefs.reduced_flashing = true
	game.settings.set_accessibility(prefs)
	var audio: Dictionary = game.settings.snapshot().audio
	audio.muted = true
	game.settings.set_audio(audio)
	game.settings.set_onboarding({"enabled":false,"seen":[]})
	prefix = str(dimensions.x)+("-large-" if large else "-standard-")
	await shot("title")
	game.chapter.start()
	await shot("briefing")
	game.chapter.launch()
	game.submarine.global_position = Vector2(1280,480)
	(game.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2)
	game.bloom.interact()
	await shot("choice")
	assert(game.bloom.choose_collect()==OK)
	game.bloom.leave()
	game.submarine.global_position = Vector2(3500,620)
	game.submarine.velocity = Vector2.ZERO
	(game.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	game.submarine.sonar.advance(10)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2)
	game.submarine.scanner.request_scan(SunlitShallowsData.BUOY)
	game.submarine.scanner.advance(4)
	game.revision.ui.notifications.toggle()
	await shot("radio")
	game.revision.ui.notifications.collapse()
	game.submarine.set_simulation_enabled(false)
	game.research_log.present()
	await shot("research")
	game.research_log.hide()
	game.expedition_log.present()
	await shot("expedition-log")
	game.expedition_log.hide()
	game.submarine.global_position = game.region.spawn.position
	game.submarine.velocity = Vector2.ZERO
	(game.submarine.get_node("Camera2D") as Camera2D).reset_smoothing()
	game.route_check.sample(false,true,0)
	game.route_check.sample(true,false,0)
	assert(game.open_station()==OK)
	await shot("station")
	game.revision.ui.show_dock("technology")
	await shot("technology")
	game.revision.ui.show_dock()
	game.chapter.show_debrief()
	await shot("debrief")
	hide_pages()
	game.open_accessibility()
	await shot("settings")
	game.accessibility_panel.hide()
	game.open_help()
	await shot("help")
	hide_pages()
	game.queue_free()
	await frames(4)


func _initialize() -> void:
	output = OS.get_environment("BTA_EVIDENCE_DIR")
	assert(not output.is_empty())
	for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,800)]: await mode(dimensions,false)
	if not OS.get_cmdline_user_args().has("--baseline"):
		await mode(Vector2i(800,600),true)
		await mode(Vector2i(1920,1080),false)
	var report: FileAccess = FileAccess.open(output.path_join("native-metrics.json"),FileAccess.WRITE)
	assert(report!=null)
	report.store_string(JSON.stringify(metrics,"  ")+"\n")
	report.close()
	print("INTERFACE_REVIEW_CAPTURE_PASS")
	quit()
