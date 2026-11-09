extends GutTest
## Step-1 usability rules: quieter HUD, explained controls, dismissable radio and chapter guidance cards.
var game: ShelfPrototype
var path: String
var titles: Array[String] = []


func before_each() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.world_2d = World2D.new()
	add_child_autofree(view)
	game = preload("res://scenes/main/main.tscn").instantiate() as ShelfPrototype
	path = "user://guidance-%d.json" % Time.get_ticks_usec()
	game.settings_path = path
	game.expedition_path = path + ".expedition.json"
	view.add_child(game)
	game.chapter.start()
	game.chapter.launch()
	await wait_physics_frames(3)
	titles.clear()
	game.tutorial.message_changed.connect(func(title: String, _body: String) -> void: titles.append(title))


func after_each() -> void:
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + stem + suffix))


func _twilight() -> void:
	game.journey.prepare({"phase": "twilight", "commissioned": true})
	game.submarine.set_simulation_enabled(true)


func _cancel() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_full_ready_magazine_is_hidden_and_reappears_when_it_matters() -> void:
	var label: Label = game.revision._ammo_label
	game.torpedoes.restore_ammunition(TorpedoLauncher.CAPACITY)
	game.revision._refresh_ammo()
	assert_false(label.visible, "a full ready magazine is noise")
	game.torpedoes.restore_ammunition(4)
	game.revision._refresh_ammo()
	assert_true(label.visible)
	assert_string_contains(label.text, "4/%d" % TorpedoLauncher.CAPACITY)


func test_empty_passive_panel_hides_in_production_layout_and_shows_with_a_contact_rule() -> void:
	var panel: PassiveContactsPanel = game.hud.get_node("%PassiveContacts") as PassiveContactsPanel
	assert_true(panel.hide_when_empty)
	panel._refresh()
	assert_false(panel.visible)
	panel.hide_when_empty = false
	panel._refresh()
	assert_true(panel.visible, "legacy layouts keep their always-visible panel")


func test_radio_preview_explains_controls_and_escape_dismisses_without_losing_the_message() -> void:
	game.revision.ui.title_page.hide()
	game.route_layer.hide()
	game.submarine.set_simulation_enabled(true)
	game.revision.show_transmission("dispatch", true)
	await wait_physics_frames(3)
	var radio: RadioNotifications = game.revision.ui.notifications
	assert_true(radio.panel.visible)
	assert_string_contains(radio.hint.text, "Esc")
	assert_string_contains(radio.hint.text, "respond")
	radio._input(_cancel())
	await wait_physics_frames(2)
	assert_false(radio.panel.visible, "Esc dismisses the preview")
	assert_true(radio.contains_message("dispatch"), "dismissal never discards the unread message")
	assert_true(radio.badge.visible)


func test_dock_pages_name_what_back_does() -> void:
	game.revision.ui.show_dock()
	assert_string_contains((game.revision.ui._hints[game.revision.ui.dock_page] as Label).text, "depart station")
	game.revision.ui.show_dock("technology")
	assert_string_contains((game.revision.ui._hints[game.revision.ui.dock_page] as Label).text, "back to operations")


func test_cable_and_net_cards_appear_near_their_subjects_once_and_stop_when_scanned() -> void:
	_twilight()
	game.tutorial._current = ""
	game.submarine.global_position = TwilightShelfData.record(&"twilight-line-anchor").at
	game.tutorial._process(0.1)
	assert_true("Wick / the sensor line" in titles, "cable guidance near the line")
	game.tutorial._current = ""
	titles.clear()
	game.tutorial._process(0.1)
	assert_false("Wick / the sensor line" in titles, "shown once per session")
	game.tutorial._current = ""
	game.submarine.global_position = TwilightShelfData.NET
	game.tutorial._process(0.1)
	assert_true("Wick / living contact" in titles, "net guidance near the net")


func test_guidance_cards_stay_silent_outside_twilight_and_when_tutorials_are_off() -> void:
	game.submarine.set_simulation_enabled(true)
	game.submarine.global_position = TwilightShelfData.NET
	game.tutorial._current = ""
	game.tutorial._process(0.1)
	assert_false("Wick / living contact" in titles, "Sunlit Shallows never shows Twilight cards")
	_twilight()
	game.tutorial._current = ""
	var onboarding: Dictionary = game.settings.snapshot().onboarding
	onboarding.enabled = false
	game.settings.set_onboarding(onboarding)
	game.tutorial._process(0.1)
	assert_false("Wick / living contact" in titles, "the saved tutorial switch is respected")
