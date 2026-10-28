extends GutTest
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var viewport: SubViewport
var path: String
func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://bta049-%d.json" % Time.get_ticks_usec()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	add_child_autofree(viewport)
	game = MAIN.instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	viewport.add_child(game)
func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))
func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	viewport.push_input(event,true)
	event.pressed = false
	viewport.push_input(event,true)
	await wait_process_frames(3)
func _joy(code: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	viewport.push_input(event,true)
	event.pressed = false
	viewport.push_input(event,true)
	await wait_process_frames(3)
func test_title_animation_is_isolated_from_gameplay_and_progress() -> void:
	var art: HalcyonDescent = game.revision.ui.title_art
	var state: Dictionary = game.saves._state.duplicate(true)
	var at: Vector2 = game.submarine.position
	game.submarine.velocity = Vector2(43,11)
	var previous: float = art.phase
	art._process(0.5)
	assert_gt(art.phase,previous)
	assert_eq(game.submarine.position,at)
	assert_eq(game.submarine.velocity,Vector2(43,11))
	assert_eq(game.saves._state,state)
	assert_false(game.submarine.is_physics_processing())
	assert_false((game.get_node("WorldRoot") as Node2D).visible)
	assert_eq(art.mouse_filter,Control.MOUSE_FILTER_IGNORE)
	assert_eq(art.focus_mode,Control.FOCUS_NONE)
func test_reduced_motion_freezes_all_title_animation_and_hidden_title_stops_processing() -> void:
	var art: HalcyonDescent = game.revision.ui.title_art
	var preferences: Dictionary = SettingsStore.default_accessibility()
	preferences.reduced_motion = true
	preferences.reduced_flashing = true
	preferences.reduced_particles = true
	game.settings.set_accessibility(preferences)
	await wait_process_frames(3)
	assert_eq(art.phase,0.0)
	art._process(9.0)
	assert_eq(art.phase,0.0)
	assert_false(art.is_processing())
	assert_true(art.reduced_effects)
	assert_true(art.reduced_particles)
	game.settings.set_accessibility(SettingsStore.default_accessibility())
	await wait_process_frames(3)
	game.revision.ui.title_page.hide()
	assert_false(art.visible)
	assert_false(art.is_processing())
	var before: float = art.phase
	art._process(9.0)
	assert_eq(art.phase,before)
func test_title_and_playable_vessel_share_master_without_changing_footprint_or_collisions() -> void:
	var sprite: Sprite2D = game.submarine.get_node("Visual/NerisIllustration") as Sprite2D
	assert_eq(sprite.texture,HalcyonDescent.VESSEL)
	assert_eq(sprite.texture.get_size()*sprite.scale,Vector2(80,48))
	var shape: CapsuleShape2D = (game.submarine.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	assert_eq(shape.radius,16.0)
	assert_eq(shape.height,64.0)
	assert_eq(HalcyonDeparture.STATION,HalcyonDescent.STATION)
	assert_eq(game.chapter.departure.get_child_count(),0,"Draw-only dressing cannot add collision or gameplay children.")
	assert_false(game.chapter.departure.visible)
	game.chapter.start()
	game.chapter.launch()
	assert_true(game.chapter.departure.visible)
	assert_true((game.get_node("WorldRoot") as Node2D).visible)
	for node: Node in game.region.get_children():
		if node is StationIllustration: assert_false(node.visible,"Canonical shared modules replace only the old decorative cutaway.")
func test_keyboard_and_controller_reach_options_and_return_without_starting_or_changing_state() -> void:
	await wait_process_frames(4)
	var before: Dictionary = game.saves._state.duplicate(true)
	await _key(KEY_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"NewGame")
	await _key(KEY_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"TitleOptions")
	await _key(KEY_ENTER)
	assert_eq((viewport.gui_get_focus_owner() as Button).text,"Input controls")
	await _joy(JOY_BUTTON_B)
	assert_eq(viewport.gui_get_focus_owner().name,&"Begin")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"NewGame")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"TitleOptions")
	await _joy(JOY_BUTTON_A)
	assert_eq((viewport.gui_get_focus_owner() as Button).text,"Input controls")
	await _key(KEY_ESCAPE)
	assert_eq(viewport.gui_get_focus_owner().name,&"Begin")
	assert_false(game.submarine.is_physics_processing())
	assert_eq(game.saves._state,before)
func test_mouse_options_and_intentional_begin_keep_existing_briefing_contract() -> void:
	await wait_process_frames(4)
	var options: Button = game.revision.ui.find_child("TitleOptions",true,false) as Button
	var at: Vector2 = options.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	viewport.push_input(motion,true)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	viewport.push_input(click,true)
	click.pressed = false
	viewport.push_input(click,true)
	await wait_process_frames(4)
	assert_eq((viewport.gui_get_focus_owner() as Button).text,"Input controls")
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	assert_false(game.revision.ui.title_page.visible)
	assert_false(game.revision.ui.title_art.visible)
	assert_true(game.revision.ui.radio_page.visible)
	assert_false(game.submarine.is_physics_processing())
	assert_eq(game.chapter.state(),"available")
func test_all_sizes_large_text_contrast_and_legacy_recovery_controls_remain_reachable() -> void:
	assert_eq(game.missions.accept(NarrativeService.MAIN),OK)
	game.saves._ready_to_write = false
	game.revision.ui.show_title()
	assert_not_null(game.revision.ui.find_child("PrototypeExpedition",true,false))
	assert_not_null(game.revision.ui.find_child("RecoverCheckpoint",true,false))
	for large: bool in [false,true]:
		var preferences: Dictionary = SettingsStore.default_accessibility()
		preferences.ui_scale = "large" if large else "standard"
		preferences.high_contrast = large
		game.settings.set_accessibility(preferences)
		for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
			viewport.size = dimensions
			await wait_process_frames(5)
			for button: Button in game.revision.ui._buttons:
				if button.disabled or not button.is_visible_in_tree(): continue
				button.grab_focus()
				await wait_process_frames(5)
				assert_true(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(button.get_global_rect()),str(button.text,button.get_global_rect(),dimensions))
				assert_gte(button.get_theme_font_size("font_size"),16)
				if large: assert_eq((button.get_theme_stylebox("focus") as StyleBoxFlat).border_width_left,4)
	assert_eq(game.missions.snapshot()[String(NarrativeService.MAIN)].state,"accepted")

func test_accessibility_cancel_from_title_keeps_focus_on_visible_title_controls() -> void:
	await wait_process_frames(4)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"TitleAccessibility")
	await _key(KEY_ENTER)
	assert_true(game.accessibility_panel.visible)
	await _joy(JOY_BUTTON_B)
	assert_false(game.accessibility_panel.visible)
	assert_true(game.revision.ui.title_page.visible)
	assert_eq(viewport.gui_get_focus_owner().name,&"Begin")
	assert_true(viewport.gui_get_focus_owner().is_visible_in_tree())
	await _joy(JOY_BUTTON_DPAD_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"NewGame")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	assert_eq(viewport.gui_get_focus_owner().name,&"TitleOptions")
	assert_false(game.submarine.is_physics_processing())
