extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var viewport: SubViewport
var path: String

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(800,600)
	add_child_autofree(viewport)
	game = MAIN.instantiate() as ShelfPrototype
	path = "user://bta049-typography-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	viewport.add_child(game)
	await wait_process_frames(6)

func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))

func test_long_briefing_stays_bounded_and_controller_can_scroll_then_launch() -> void:
	game.chapter.start()
	var page: PanelContainer = game.revision.ui.radio_page
	var scroll: ScrollContainer = game.revision.ui._scrolls[page]
	game.revision.ui._label(game.revision.ui._radio_body,"Long accessible transcript. ".repeat(180))
	for scale_name: String in ["compact","standard","large"]:
		var prefs: Dictionary = SettingsStore.default_accessibility()
		prefs.ui_scale = scale_name
		prefs.high_contrast = scale_name=="large"
		game.settings.set_accessibility(prefs)
		await wait_process_frames(8)
		var bounds: Rect2 = Rect2(Vector2(24,32),Vector2(752,536))
		assert_true(bounds.encloses(page.get_global_rect()))
		assert_false(game.submarine.is_physics_processing())
		var down: UiScrollReader = scroll as UiScrollReader
		down.grab_focus()
		await wait_process_frames(4)
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_DPAD_DOWN
		event.pressed = true
		viewport.push_input(event,true)
		event.pressed = false
		viewport.push_input(event,true)
		await wait_process_frames(4)
		assert_gt(scroll.scroll_vertical,0)
		assert_true(page.get_global_rect().encloses(down.get_global_rect()))
		assert_null(page.find_child("TextDown",true,false))
	var launch: Button = game.revision.ui.find_child("LaunchSunlit",true,false) as Button
	launch.grab_focus()
	await wait_process_frames(6)
	assert_true(scroll.get_global_rect().encloses(launch.get_global_rect()),"Focus brings the launch control into the bounded scroll viewport.")

func test_logs_settings_and_story_choices_reflow_and_destroy_without_global_callbacks() -> void:
	game.chapter.start()
	game.chapter.launch()
	game.submarine.global_position = Vector2(1280,480)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2)
	game.bloom.interact()
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.ui_scale = "large"
	game.settings.set_accessibility(prefs)
	for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
		viewport.size = dimensions
		await wait_process_frames(8)
		var visible_bounds: Rect2 = Rect2(Vector2.ZERO,Vector2(dimensions))
		assert_true(visible_bounds.encloses(game.bloom.panel.page.get_global_rect()))
		assert_lte(game.bloom.panel.page.size.x,760.0)
		game.research_log.present()
		await wait_process_frames(5)
		assert_true(visible_bounds.encloses((game.research_log.get_node("DialogFrame") as Control).get_global_rect()))
		assert_true(visible_bounds.encloses((game.research_log.get_node("%DetailScroll") as Control).get_global_rect()))
		game.research_log.hide()
	game.queue_free()
	await wait_process_frames(5)
	# Destroying a dialog must remove all resize callbacks, even after a later resize.
	viewport.size = Vector2i(800,600)
	await wait_process_frames(5)
	assert_true(viewport.size_changed.get_connections().is_empty())
