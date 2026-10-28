extends GutTest
class ThreeContacts:
	extends PassiveReceiver
	func _ready() -> void: pass
	func status_text() -> String: return "LISTENING"
	func contacts_snapshot() -> Array[Dictionary]:
		return [{"classification":&"mechanical","bearing_degrees":-180.0,"signal_strength":0.8,"remaining_seconds":7.9},
			{"classification":&"geological","bearing_degrees":90.0,"signal_strength":0.6,"remaining_seconds":6.9},
			{"classification":&"marine_life","bearing_degrees":-45.0,"signal_strength":0.4,"remaining_seconds":5.9}]
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var viewport: SubViewport
var path: String
func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://bta048-%d.json" % Time.get_ticks_usec()
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
func _launch() -> void:
	game.chapter.start()
	game.chapter.launch()
func test_percentages_use_authoritative_capacity_and_exact_thirds_before_rounding() -> void:
	var gauge: ResourceGauge = game.hud.battery_gauge
	for percent: int in [100,67,66,34,33,1,0]:
		gauge.set_reading(percent*2.0,200)
		assert_eq((gauge.get_node("%Value") as Label).text,"%d%%" % percent)
		assert_eq(gauge.reading_color,Color("22c55e") if percent>=67 else (Color("eab308") if percent>=34 else Color("ef4444")))
	gauge.set_reading(2.0,3.0)
	assert_eq(gauge.reading_color,Color("22c55e"))
	gauge.set_reading(1.0,3.0)
	assert_eq(gauge.reading_color,Color("ef4444"))
	assert_false((gauge.get_node("%Bar") as Control).is_visible_in_tree())
func test_invalid_readings_fail_closed_and_clamp_without_nan() -> void:
	var gauge: ResourceGauge = game.hud.hull_gauge
	for pair: Vector2 in [Vector2(100,0),Vector2(10,-1),Vector2(NAN,100),Vector2(100,INF)]:
		gauge.set_reading(pair.x,pair.y)
		assert_eq((gauge.get_node("%Value") as Label).text,"0%")
		assert_eq(gauge.reading_color,Color("ef4444"))
		assert_true((gauge.get_node("%State") as Label).text.contains("INVALID"))
	gauge.set_reading(300,100)
	assert_eq((gauge.get_node("%Value") as Label).text,"100%")
	gauge.set_reading(-10,100)
	assert_eq((gauge.get_node("%Value") as Label).text,"0%")
func test_radio_arrival_and_expansion_leave_movement_and_initial_focus_untouched() -> void:
	game.revision.start()
	game.submarine.velocity = Vector2(70,0)
	var position: Vector2 = game.submarine.position
	var before: Control = viewport.gui_get_focus_owner()
	game.revision.show_transmission("dispatch",true)
	assert_eq(viewport.gui_get_focus_owner(),before)
	assert_eq(game.submarine.velocity,Vector2(70,0))
	assert_true(game.submarine.is_physics_processing())
	game.revision.ui.notifications.toggle()
	Input.action_press("move_right")
	await wait_physics_frames(15)
	assert_gt(game.submarine.position.x,position.x)
	assert_true(game.submarine.is_physics_processing())
	assert_eq(game.revision.campaign.messages,[])
	assert_eq(game.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
func test_radio_queue_deferral_ack_duplicate_and_continue_preserve_authorities() -> void:
	game.revision.start()
	var radio: RadioNotifications = game.revision.ui.notifications
	game.revision.show_transmission("dispatch",true)
	game.revision.show_transmission("dispatch",true)
	game.revision.show_transmission("relay")
	radio.replay("unknown-message","Invalid replay","Unknown")
	assert_eq(radio.pending,["dispatch","relay"])
	assert_false(radio.texts.has("unknown-message"))
	assert_false(radio.expanded)
	game.revision.defer_transmission()
	assert_eq(game.revision.campaign.messages,[])
	game.revision.accept_transmission("dispatch",true)
	assert_eq(game.revision.campaign.messages,["dispatch"])
	assert_ne(game.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
	game.revision.accept_transmission("dispatch",true)
	game.revision.show_transmission("dispatch",true)
	assert_eq(radio.pending,["relay"])
	assert_true(game.revision.archive_text().contains(ExpeditionRevision.TRANSMISSIONS.dispatch))
	assert_eq(game.saves.continue_expedition(),OK)
	game.revision.show_transmission("dispatch",true)
	assert_false(radio.contains_message("dispatch"))
func test_unread_badge_remains_after_preview_without_acknowledging() -> void:
	game.revision.start()
	var radio: RadioNotifications = game.revision.ui.notifications
	game.revision.show_transmission("dispatch",true)
	radio._process(20)
	assert_true(radio.badge.visible)
	assert_false(radio.panel.visible)
	assert_true(radio.contains_message("dispatch"))
	assert_eq(game.revision.campaign.messages,[])
	await wait_process_frames(4)
	var pointer: Vector2 = radio.badge.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	viewport.push_input(motion,true)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = pointer
	click.global_position = pointer
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	viewport.push_input(click,true)
	click.pressed = false
	viewport.push_input(click,true)
	assert_true(radio.expanded)
	assert_true(game.submarine.is_physics_processing())
func test_tracker_follows_bloom_recording_return_and_claim() -> void:
	_launch()
	assert_true(game.mission_tracker.detail.text.contains("light bloom"))
	game.submarine.global_position = Vector2(1280,480)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2)
	game.bloom.interact()
	assert_eq(game.bloom.choose_collect(),OK)
	game.bloom.leave()
	assert_true(game.mission_tracker.detail.text.contains("fractured passage"))
	game.excavation.excavate(Vector2(4560,480),150)
	assert_true(game.chapter.guide.layout.passage_clear())
	assert_true(game.mission_tracker.detail.text.contains("sonar search"))
	game.submarine.global_position = SunlitSurveyData.BUOY
	game.submarine.sonar.advance(10)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2)
	game.submarine.scanner.request_scan(SunlitShallowsData.BUOY)
	game.submarine.scanner.advance(4)
	assert_true(game.mission_tracker.detail.text.contains("Return to Halcyon"))
	game.route_check.sample(false,true,0)
	game.route_check.sample(true,false,0)
	assert_true(game.mission_tracker.detail.text.contains("debrief"))
	game.submarine.position = game.region.spawn.position
	game.submarine.velocity = Vector2.ZERO
	game.open_station()
	game.chapter.debrief(game.station)
	assert_true(game.mission_tracker.detail.text.contains("not yet playable"))
func test_old_custom_bindings_gain_collision_free_radio_and_retain_existing_keys() -> void:
	var old: Dictionary = InputBindings.defaults()
	old.erase("open_radio")
	old.move_right.append({"kind":"key","code":KEY_R})
	old.move_right.append({"kind":"button","code":JOY_BUTTON_LEFT_SHOULDER})
	var current: Dictionary = InputBindings.compatible_bindings(old)
	assert_true(InputBindings.valid_bindings(current))
	for action: String in old: assert_eq(current[action],old[action])
	assert_ne(current.open_radio[0].code,KEY_R)
func test_production_layout_fits_and_separates_top_instruments_at_all_sizes() -> void:
	_launch()
	var contacts: ThreeContacts = ThreeContacts.new()
	var receiver: AcousticReceiver = AcousticReceiver.new()
	receiver.name = "AcousticReceiver"
	contacts.add_child(receiver)
	viewport.add_child(contacts)
	game.hud.bind_passive(contacts)
	game.hud.bind_threat(null)
	var threat: Control = game.hud.get_node("%ThreatIndicator") as Control
	(threat.get_node("Content/Title") as Label).text = "PREDATOR ! PURSUE"
	(threat.get_node("Content/Hint") as Label).text = "RETREAT ↓ PAST 115 m"
	threat.show()
	game.hud._impact_applied(12,240)
	game.hud._pressure_applied(2)
	for large: bool in [false,true]:
		var preferences: Dictionary = SettingsStore.default_accessibility()
		preferences.ui_scale = "large" if large else "standard"
		preferences.high_contrast = large
		game.settings.set_accessibility(preferences)
		for dimensions: Vector2i in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
			viewport.size = dimensions
			await wait_process_frames(8)
			# Stage a warning after accessibility refresh; no threat source is bound in this layout fixture.
			threat.show()
			game.hud.compact_reflow()
			var bounds: Rect2 = Rect2(Vector2.ZERO,Vector2(dimensions))
			var resources: Control = game.hud.get_node("%InstrumentDeck") as Control
			var depth: Control = game.hud.get_node("%DepthPanel") as Control
			var tracker: Control = game.mission_tracker
			for control: Control in [resources,depth,tracker,game.hud.get_node("%PassiveContacts")]:
				assert_true(bounds.encloses(control.get_global_rect()),str(control.name,control.get_global_rect(),dimensions))
			assert_false(resources.get_global_rect().intersects(depth.get_global_rect()))
			assert_false(depth.get_global_rect().intersects(tracker.get_global_rect()))
			var passive: Control = game.hud.get_node("%PassiveContacts") as Control
			assert_true(bounds.encloses(threat.get_global_rect()))
			assert_false(threat.get_global_rect().intersects(passive.get_global_rect()))
			assert_false(threat.get_global_rect().intersects(tracker.get_global_rect()))
			if game.pilot_context.visible: assert_false(threat.get_global_rect().intersects(game.pilot_context.get_global_rect()))
			assert_true(threat.visible)
			assert_true((game.hud.get_node("%ImpactFeedback") as Label).text.contains("IMPACT"))
func test_docking_upgrades_reload_and_non_default_capacity_update_the_compact_readings() -> void:
	_launch()
	game.submarine.hull_system.apply_damage(8,&"test")
	game.submarine.resource_system.consume_battery(46)
	game.submarine.resource_system.consume_oxygen(72)
	assert_eq((game.hud.hull_gauge.get_node("%Value") as Label).text,"92%")
	assert_eq((game.hud.battery_gauge.get_node("%Value") as Label).text,"54%")
	assert_eq((game.hud.oxygen_gauge.get_node("%Value") as Label).text,"28%")
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.save_current(),OK)
	game.submarine.resource_system.consume_battery(10)
	assert_eq(game.saves.continue_expedition(),OK)
	assert_eq((game.hud.battery_gauge.get_node("%Value") as Label).text,"54%")
	assert_eq(game.open_station(),OK)
	for gauge: ResourceGauge in [game.hud.hull_gauge,game.hud.battery_gauge,game.hud.oxygen_gauge]: assert_eq((gauge.get_node("%Value") as Label).text,"100%")
	assert_eq(game.revision.assign("hull",1),OK)
	assert_true((game.hud.get_node("%SafeDepth") as Label).text.contains("400"))
	var pools: SubmarineResourceConfig = SubmarineResourceConfig.new()
	pools.max_battery = 250
	game.submarine.resource_system.configure(pools)
	game.submarine.resource_system.consume_battery(125)
	assert_eq((game.hud.battery_gauge.get_node("%Value") as Label).text,"50%")
func test_observed_bloom_and_tracker_restore_without_replaying_choice_or_exposing_later_objectives() -> void:
	_launch()
	game.submarine.global_position = Vector2(1280,480)
	game.submarine.sonar.request_ping()
	game.submarine.sonar.advance(2)
	game.bloom.interact()
	game.bloom.choose_observe()
	game.submarine.scanner.advance(3)
	game.bloom.leave()
	assert_true(game.mission_tracker.detail.text.contains("fractured passage"))
	assert_false(game.mission_tracker.detail.text.contains("Twilight"))
	game.submarine.set_simulation_enabled(false)
	assert_eq(game.saves.save_current(),OK)
	watch_signals(game.story)
	game.mission_tracker.detail.text = "stale"
	assert_eq(game.saves.continue_expedition(),OK)
	assert_true(game.mission_tracker.detail.text.contains("fractured passage"))
	assert_signal_not_emitted(game.story,"choice_applied")
func test_radio_failed_writes_leave_message_unread_and_do_not_accept_mission() -> void:
	game.revision.start()
	game.revision.show_transmission("dispatch",true)
	game.saves._ready_to_write = false
	game.revision.accept_transmission("dispatch",true)
	assert_eq(game.revision.campaign.messages,[])
	assert_eq(game.missions.snapshot()[String(ShelfChapterData.OUTER)].state,"available")
	assert_true(game.revision.ui.notifications.contains_message("dispatch"))
	assert_true(game.revision.ui.notifications.notice.contains("NOT SAVED"))
	assert_true(game.submarine.is_physics_processing())
func test_keyboard_and_controller_can_open_defer_scroll_cycle_and_accept_while_simulation_runs() -> void:
	game.revision.start()
	var radio: RadioNotifications = game.revision.ui.notifications
	game.revision.show_transmission("dispatch",true)
	game.revision.show_transmission("relay")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	radio._input(key)
	assert_true(radio.expanded)
	radio.next_message()
	assert_eq(radio.selected,"relay")
	assert_eq(game.revision.campaign.messages,[])
	radio.collapse()
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = true
	radio._input(event)
	assert_true(radio.expanded)
	radio.selected = "dispatch"
	radio.refresh()
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	radio._input(event)
	assert_eq(viewport.gui_get_focus_owner(),radio.later)
	event.button_index = JOY_BUTTON_A
	radio._input(event)
	assert_false(radio.expanded)
	assert_eq(game.revision.campaign.messages,[])
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	radio._input(event)
	event.button_index = JOY_BUTTON_A
	radio._input(event)
	assert_has(game.revision.campaign.messages,"dispatch")
	assert_true(game.submarine.is_physics_processing())
func test_radio_and_danger_warning_never_overlap_at_minimum_large_text_size() -> void:
	_launch()
	viewport.size = Vector2i(800,600)
	var preferences: Dictionary = SettingsStore.default_accessibility()
	preferences.ui_scale = "large"
	preferences.high_contrast = true
	preferences.reduced_motion = true
	game.settings.set_accessibility(preferences)
	game.submarine.damage_system.set_maximum_depth_m(100)
	game.revision.show_transmission("dispatch",true)
	var radio: RadioNotifications = game.revision.ui.notifications
	for expand: bool in [false,true]:
		if expand: radio.toggle()
		await wait_process_frames(12)
		var bounds: Rect2 = Rect2(Vector2.ZERO,Vector2(800,600))
		var danger: Control = game.hud.get_node("%DepthPanel") as Control
		assert_true((game.hud.get_node("%WarningState") as Label).text.contains("DANGER"))
		assert_true(bounds.encloses(radio.panel.get_global_rect()),str(radio.panel.get_global_rect()))
		assert_false(radio.panel.get_global_rect().intersects(danger.get_global_rect()))
		assert_false(radio.panel.get_global_rect().intersects(game.pilot_context.get_global_rect()))
		assert_false(radio.badge.get_global_rect().intersects(game.hud.identity_container().get_global_rect()))
func test_legacy_tracker_never_exposes_available_missions_and_preserves_optional_records() -> void:
	game.revision.start()
	game.mission_tracker.refresh()
	assert_false(game.mission_tracker.detail.text.contains("lost expedition"))
	assert_eq(game.missions.accept(NarrativeService.SCIENCE),OK)
	game.mission_tracker.refresh()
	assert_true(game.mission_tracker.detail.text.contains("Calibration"))
	assert_false(game.mission_tracker.detail.text.contains("wreck"))
	assert_eq(game.missions.snapshot()[String(ShelfChapterData.WRECK)].state,"available")
func test_radio_consumes_remapped_confirm_navigation_commands_without_losing_later_pings() -> void:
	game.revision.start()
	game.revision.show_transmission("dispatch",true)
	var radio: RadioNotifications = game.revision.ui.notifications
	radio.toggle()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	assert_eq(game.settings.remap(&"sonar_ping",key),OK)
	InputBindings.apply(game.settings.snapshot().bindings,0.25)
	radio.later.grab_focus()
	watch_signals(game.submarine.sonar)
	Input.action_press("sonar_ping")
	radio._input(key)
	await wait_physics_frames(2)
	assert_signal_not_emitted(game.submarine.sonar,"pulse_emitted")
	assert_true(game.submarine.is_physics_processing())
	Input.action_press("sonar_ping")
	await wait_physics_frames(2)
	Input.action_release("sonar_ping")
	assert_signal_emit_count(game.submarine.sonar,"pulse_emitted",1)
	radio.toggle()
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
	joy.pressed = true
	assert_eq(game.settings.remap(&"fire_torpedo",joy),OK)
	InputBindings.apply(game.settings.snapshot().bindings,0.25)
	watch_signals(game.torpedoes)
	Input.action_press("fire_torpedo")
	radio._input(joy)
	await wait_physics_frames(2)
	assert_signal_not_emitted(game.torpedoes,"fired")
	assert_eq(game.torpedoes.ammunition,10)
