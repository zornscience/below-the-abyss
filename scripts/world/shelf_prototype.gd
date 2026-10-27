class_name ShelfPrototype
extends MovementPrototype
## BTA-014 scene composition and ephemeral route-check telemetry.

@export var expedition_path: String = ""
@export var extended_expedition: bool = true
@export var revised_expedition: bool = true
@export var canonical_chapter: bool = true
var mission_tracker: MissionTracker
var chapter: SunlitShallows
var _station_failure: String = ""
var _station_failure_remaining: float = 0.0
var story: StoryState
var bloom: LightBloomEncounter
var revision: ExpeditionRevision
var excavation: ExcavationSystem
var torpedoes: TorpedoLauncher
var tutorial: TutorialDirector
var tutorial_card: TutorialCard
var help_panel: MechanicsHelp
var pilot_context: PilotContext
var extension: ShelfExpansion
var playtest_observer: PlaytestObserver
var playtest_panel: PlaytestPanel
var audio: SoundscapeMixer
var gameplay_audio: GameplayAudio
var audio_settings: AudioSettingsPanel
var input_context: InputContext
var accessibility_service: UiAccessibility
var accessibility_panel: AccessibilityPanel
var narrative: NarrativeService
var expedition_log: ExpeditionLog
var _story_from_station: bool = false
var saves: SaveCoordinator
var _expedition_started: bool = false
const MISSION_CATALOG: MissionCatalog = preload("res://resources/missions/shelf_missions.tres")
@export var mission_path: String = ""
var missions: MissionService
const UPGRADE_CATALOG: UpgradeCatalog = preload("res://resources/equipment/shelf_upgrades.tres")
@export var upgrade_path: String = ""
var upgrades: SubmarineUpgrades
const RESEARCH_CATALOG: ResearchCatalog = preload("res://resources/regions/shelf_research.tres")
@export var research_path: String = ""
var research: ResearchRegistry
var research_store: ResearchStore = ResearchStore.new()
@onready var research_log: ResearchLog = $MapLayer/ResearchLog
const DISCOVERY_CATALOG: DiscoveryCatalog = preload("res://resources/regions/shelf_discoveries.tres")
@export var discovery_path: String = ""
var discoveries: DiscoveryRegistry
var discovery_store: DiscoveryStore = DiscoveryStore.new()
var _map_from_route: bool = false
@onready var exploration_map: ExplorationMap = $MapLayer/ExplorationMap
var route_check: GrayboxRouteCheck = GrayboxRouteCheck.new()
@onready var region: ContinentalShelf = $WorldRoot/CurrentRegion
@onready var route_layer: CanvasLayer = $RouteLayer
@onready var route_menu: GrayboxRouteMenu = $RouteLayer/RouteMenu
@onready var station: ServiceStation = $WorldRoot/CurrentRegion/ServiceStation
@onready var station_menu: StationMenu = $StationLayer/StationMenu
@onready var predator: PredatorCreature = $WorldRoot/CurrentRegion/ShelfPredator
@onready var creature: AcousticCreature = $WorldRoot/CurrentRegion/HarmlessObserver
@onready var ambient: AmbientAcousticField = $WorldRoot/CurrentRegion/AmbientField


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--prototype-expedition"): canonical_chapter = false
	story = StoryState.new()
	add_child(story)
	if story.configure()!=OK: push_error("Invalid story choice catalog.")
	(route_menu.get_node("%HelpTutorial") as Button).visible = extended_expedition
	(route_menu.get_node("%HelpTutorial") as Button).disabled = not extended_expedition
	if extended_expedition:
		extension = ShelfExpansion.new()
		add_child(extension)
		excavation = extension.setup(region,revised_expedition)
	# Place the existing vessel before the shared orchestration samples depth.
	submarine.global_position = region.spawn.global_position
	region.configure_camera(submarine.get_node("Camera2D") as Camera2D)
	super._ready()
	var bus: AcousticBus = $AcousticBus
	if extension != null:
		for grazer: AcousticCreature in extension.wildlife:
			if grazer.bind_bus(bus) != OK: push_error("Outer wildlife receiver registration failed")
			submarine.simulation_enabled_changed.connect(func(enabled: bool) -> void: grazer.set_suspended(not enabled))
		for animal: AcousticCreature in [creature,predator]+extension.wildlife:
			(animal.get_node("StateCaption") as Label).hide()
	if creature.bind_bus(bus) != OK:
		push_error("Creature receiver registration failed.")
	submarine.simulation_enabled_changed.connect(func(enabled: bool) -> void: creature.set_suspended(not enabled))
	if predator.bind_bus(bus) != OK or predator.setup_player(submarine) != OK:
		push_error("Predator encounter setup failed.")
	submarine.simulation_enabled_changed.connect(func(enabled: bool) -> void: predator.set_suspended(not enabled))
	if submarine.sonar.setup(bus, submarine.resource_system, $WorldRoot/WorldEffects) != OK:
		push_error("Shelf active sonar setup failed.")
	for node: Node in region.get_node("SonarTargets").get_children():
		var target: SonarRevealTarget = node as SonarRevealTarget
		if target.bind_bus(bus) != OK or submarine.sonar.listen_to(target) != OK:
			push_error("Shelf sonar target registration failed.")
	discoveries = DiscoveryRegistry.new()
	add_child(discoveries)
	if discoveries.configure(ShelfChapterData.discoveries(revised_expedition) if extended_expedition else DISCOVERY_CATALOG) != OK:
		push_error("Invalid discovery catalog.")
	for node: Node in region.get_node("SonarTargets").get_children():
		var result: Error = discoveries.connect_sonar_target(node as SonarRevealTarget)
		if result != OK and result != ERR_DOES_NOT_EXIST:
			push_error("Discovery target binding failed.")
	discovery_store.path = discovery_path if not discovery_path.is_empty() else (
		DiscoveryStore.DEFAULT_PATH if settings_path == SettingsStore.DEFAULT_PATH else settings_path + ".discoveries.json")
	discovery_store.load_registry(discoveries)
	discoveries.point_discovered.connect(func(_id: StringName) -> void: discovery_store.save_registry(discoveries))
	exploration_map.setup(discoveries, discovery_store)
	exploration_map.close_requested.connect(close_map)
	research = ResearchRegistry.new()
	add_child(research)
	if research.configure(ShelfChapterData.research(revised_expedition) if extended_expedition else RESEARCH_CATALOG) != OK:
		push_error("Invalid research catalogue.")
	research_store.path = research_path if not research_path.is_empty() else (
		ResearchStore.DEFAULT_PATH if settings_path == SettingsStore.DEFAULT_PATH else settings_path + ".research.json")
	research_store.load_registry(research)
	research.scan_completed.connect(func(_id: StringName) -> void: research_store.save_registry(research))
	var targets: Array[ScientificScanTarget] = []
	var research_catalog: ResearchCatalog = ShelfChapterData.research(revised_expedition) if extended_expedition else RESEARCH_CATALOG
	for definition: ScanDefinition in research_catalog.targets:
		var target: ScientificScanTarget = ScientificScanTarget.new()
		target.name = String(definition.stable_id)
		target.target_id = definition.stable_id
		if extended_expedition and definition.stable_id == &"observer-ecology":
			creature.add_child(target)
			target.position = Vector2.ZERO
		else:
			region.add_child(target)
			target.position = definition.position
		targets.append(target)
	if submarine.scanner.setup(research, discoveries, targets) != OK:
		push_error("Scientific scanner setup failed.")
	submarine.scanner.state_changed.connect(_refresh_scan_status)
	research_log.setup(research, research_store)
	exploration_map.research_requested.connect(open_research)
	research_log.close_requested.connect(close_research)
	_refresh_scan_status()
	hud.bind_sonar(submarine.sonar)
	if submarine.passive.bind_bus(bus) != OK or ambient.bind_bus(bus) != OK:
		push_error("Shelf passive sonar setup failed.")
	hud.bind_passive(submarine.passive)
	hud.bind_threat(predator)
	($DevelopmentUI/Banner as Control).offset_top = 215.0
	route_menu.resume_requested.connect(_route_resume_requested)
	route_menu.settings_requested.connect(_route_settings_requested)
	route_menu.restart_requested.connect(restart_route)
	route_check.stage_changed.connect(func(_stage: int) -> void: _refresh_route_status())
	_refresh_route_status()
	upgrades = SubmarineUpgrades.new()
	add_child(upgrades)
	var upgrades_file: String = upgrade_path if not upgrade_path.is_empty() else (
		UpgradeStore.DEFAULT_PATH if settings_path == SettingsStore.DEFAULT_PATH else settings_path + ".upgrades.json")
	if upgrades.setup(UPGRADE_CATALOG, submarine.sonar, submarine.damage_system, upgrades_file) != OK:
		push_error("Submarine upgrade setup failed.")
	station.upgrades = upgrades
	missions = MissionService.new()
	add_child(missions)
	var missions_file: String = mission_path if not mission_path.is_empty() else (
		MissionStore.DEFAULT_PATH if settings_path == SettingsStore.DEFAULT_PATH else settings_path + ".missions.json")
	if missions.setup(SunlitShallowsData.missions() if extended_expedition and revised_expedition and canonical_chapter else (ShelfChapterData.missions() if extended_expedition else MISSION_CATALOG), discoveries, research, route_check, missions_file, story) != OK:
		push_error("Mission framework setup failed.")
	station.missions = missions
	missions.missions_changed.connect(_refresh_mission_status)
	missions.store.status_changed.connect(_refresh_mission_status)
	_refresh_mission_status()
	station_menu.close_requested.connect(close_station)
	route_menu.save_requested.connect(_manual_save)
	route_menu.recover_requested.connect(_recover_expedition)
	route_menu.new_expedition_requested.connect(_new_expedition)
	# Existing isolated component fixtures opt in by injecting an expedition path.
	if settings_path == SettingsStore.DEFAULT_PATH or not expedition_path.is_empty():
		saves = SaveCoordinator.new()
		add_child(saves)
		saves.status_changed.connect(_save_status)
		saves.setup(self, expedition_path if not expedition_path.is_empty() else ExpeditionStore.DEFAULT_PATH)
		_refresh_mission_status()
		station.service_applied.connect(func(_result: Dictionary) -> void: saves.save_current())
	else:
		_save_status()
	audio = SoundscapeMixer.new()
	add_child(audio)
	audio.bind_settings(settings)
	for gauge: ResourceGauge in [hud.hull_gauge, hud.battery_gauge, hud.oxygen_gauge]:
		gauge.low_warning_fraction = audio.configuration.low_resource_fraction
	gameplay_audio = GameplayAudio.new()
	add_child(gameplay_audio)
	gameplay_audio.setup(self, audio)
	audio_settings = AudioSettingsPanel.new()
	$SettingsLayer.add_child(audio_settings)
	audio_settings.close_requested.connect(open_route_menu)
	route_menu.audio_requested.connect(open_audio_settings)
	narrative = NarrativeService.new()
	add_child(narrative)
	narrative.extended_chapter = extended_expedition
	narrative.legacy_conclusion = saves != null and bool(saves._state.get("legacy_conclusion",false))
	if narrative.setup(ShelfChapterData.narrative(revised_expedition) if extended_expedition else preload("res://resources/narrative/shelf_chapter.tres"), missions, discoveries, research) != OK:
		push_error("Narrative chapter setup failed.")
	narrative.progress_guard = func() -> bool: return saves == null or saves.can_write()
	expedition_log = preload("res://scenes/ui/expedition_log.tscn").instantiate() as ExpeditionLog
	var story_layer: CanvasLayer = CanvasLayer.new()
	story_layer.layer = 50
	add_child(story_layer)
	story_layer.add_child(expedition_log)
	expedition_log.setup(narrative)
	expedition_log.close_requested.connect(close_story)
	route_menu.story_requested.connect(open_story)
	station_menu.story_requested.connect(open_station_story)
	narrative.log_changed.connect(_refresh_route_status)
	narrative.chapter_concluded.connect(func() -> void: audio.request(&"acknowledge"))
	var details: ShelfStoryDetails = ShelfStoryDetails.new()
	region.add_child(details)
	details.bind_story(narrative)
	# Concise skippable opening: read on the existing start/pause page, expand via log.
	(route_menu.get_node("%Brief") as Label).text = "NERIS / Shelf Base: a scientific expedition is missing.\nAn unexplained sequence still reaches the shelf receivers.\nPing the plate east of base, approach and Interact to scan.\nSurvey Twin Spires, return safely. Expedition log: full briefing."
	input_context = InputContext.new()
	add_child(input_context)
	input_context.setup(settings)
	input_context.method_changed.connect(_refresh_prompts)
	input_context.controller_lost.connect(_controller_lost)
	accessibility_panel = AccessibilityPanel.new()
	$SettingsLayer.add_child(accessibility_panel)
	accessibility_panel.close_requested.connect(func() -> void:
		open_route_menu()
		(route_menu.get_node("%Accessibility") as Button).grab_focus())
	route_menu.accessibility_requested.connect(open_accessibility)
	accessibility_service = UiAccessibility.new()
	add_child(accessibility_service)
	accessibility_service.setup(self)
	if OS.has_feature("playtest") or OS.get_cmdline_user_args().has("--playtest"):
		playtest_observer = PlaytestObserver.new()
		add_child(playtest_observer)
		playtest_observer.setup(self)
		playtest_panel = PlaytestPanel.new()
		$SettingsLayer.add_child(playtest_panel)
		playtest_panel.close_requested.connect(func() -> void:
			open_route_menu()
			(route_menu.get_node("%Playtest") as Button).grab_focus())
		route_menu.playtest_requested.connect(open_playtest)
	if extended_expedition:
		torpedoes = TorpedoLauncher.new()
		add_child(torpedoes)
		if torpedoes.setup(self) != OK:
			push_error("Invalid torpedo configuration")
	if extended_expedition:
		tutorial = TutorialDirector.new()
		add_child(tutorial)
		tutorial_card = TutorialCard.new()
		$UI.add_child(tutorial_card)
		tutorial.setup(self)
		tutorial.message_changed.connect(func(title: String,body: String) -> void:
			tutorial_card.display(title,body)
			_layout_tutorial.call_deferred())
		submarine.simulation_enabled_changed.connect(func(_enabled: bool) -> void: _layout_tutorial.call_deferred())
		help_panel = MechanicsHelp.new()
		$SettingsLayer.add_child(help_panel)
		help_panel.close_requested.connect(open_route_menu)
		route_menu.help_requested.connect(open_help)
		pilot_context = PilotContext.new()
		$UI.add_child(pilot_context)
		pilot_context.setup(self)
		hud.set_quiet_layout(true)
		station_menu.use_hub = true
		get_viewport().size_changed.connect(_layout_tutorial)
		tutorial_card.minimum_size_changed.connect(_layout_tutorial)
		hud.identity_container().minimum_size_changed.connect(_layout_tutorial)
		accessibility_service.queue_apply()
		($UI/RouteGuide as Control).hide()
		(route_menu.get_node("%Brief") as Label).text = "A survey submarine is missing on the outer shelf. Recover its trail, locate the wreck and bring back the recorder. Prepare at Shelf Base. Help & tutorials explains the instruments."
	_refresh_prompts()
	_refresh_route_status()
	open_route_menu()
	if extended_expedition and revised_expedition:
		revision = ExpeditionRevision.new()
		add_child(revision)
		revision.setup(self)
		bloom = LightBloomEncounter.new()
		add_child(bloom)
		bloom.setup(self)
		if canonical_chapter:
			chapter = SunlitShallows.new()
			add_child(chapter)
			chapter.setup(self)
	if extended_expedition:
		mission_tracker = MissionTracker.new()
		get_node("UI").add_child(mission_tracker)
		mission_tracker.setup(self)


func open_help() -> void:
	if help_panel == null: return
	submarine.set_simulation_enabled(false)
	route_layer.hide()
	help_panel.present(self)


func open_playtest() -> void:
	if playtest_panel == null or not route_layer.visible:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	route_layer.hide()
	playtest_panel.present(playtest_observer)


func open_accessibility() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible or expedition_log.visible or audio_settings.visible:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	route_layer.hide()
	accessibility_panel.present(settings, settings_path)


func _controller_lost() -> void:
	if _menu != null:
		_menu.capturing = false
		_menu.status.text = "Controller disconnected. Keyboard recovery: arrows / Tab, Enter, Escape."
		(_menu.get_node("%Quit") as Button).grab_focus()
	elif submarine.is_physics_processing():
		open_route_menu()
	(route_menu.get_node("%Help") as Label).text = "Controller disconnected · Keyboard: arrows / Tab, Enter, Esc · Reconnect to use controller again"


func _refresh_prompts() -> void:
	(hud.get_node("%SettingsHint") as Label).text = "%s: sonar · %s: map · %s: pause" % [input_context.describe(&"sonar_ping"), input_context.describe(&"open_map"), input_context.describe(&"pause")]
	if extended_expedition:
		(hud.get_node("%SettingsHint") as Label).text = "%s ping · %s torpedo · %s map" % [input_context.describe(&"sonar_ping"),input_context.describe(&"fire_torpedo"),input_context.describe(&"open_map")]
	if revision!=null:
		var hints: Array[String] = []
		for action: StringName in [&"sonar_ping",&"fire_torpedo",&"open_map"]:
			hints.append(input_context.describe(action).get_slice(" / ",0).replace("Controller ",""))
		(hud.get_node("%SettingsHint") as Label).text = "%s ping · %s torpedo · %s map" % hints
	(route_menu.get_node("%ControlHints") as Label).text = "Move ← %s · → %s · ↑ %s · ↓ %s" % [input_context.describe(&"move_left").get_slice(" / ", 0), input_context.describe(&"move_right").get_slice(" / ", 0), input_context.describe(&"move_up").get_slice(" / ", 0), input_context.describe(&"move_down").get_slice(" / ", 0)]
	for node: Node in region.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text.contains("VESSEL CAN PASS THROUGH"):
			label.text = "OPTIONAL ↑→ / HARMLESS OBSERVER\n%s: sonar nearby · VESSEL CAN PASS THROUGH" % input_context.describe(&"sonar_ping")
	_refresh_scan_status()


func open_station_story() -> void:
	if not station_menu.visible:
		return
	_story_from_station = true
	station_menu.hide()
	expedition_log.present(station)


func open_story() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible or audio_settings.visible:
		return
	_story_from_station = false
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	route_layer.hide()
	expedition_log.present()


func close_story() -> void:
	expedition_log.hide()
	if _story_from_station:
		station_menu.show()
		if extended_expedition: station_menu.show_hub()
		else: station_menu.show_services()
	else:
		open_route_menu()


func open_audio_settings() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	route_layer.hide()
	audio_settings.present(settings, audio, settings_path)


func _unhandled_input(event: InputEvent) -> void:
	if bloom!=null and bloom.modal(): return
	if revision!=null and revision.ui.modal(): return
	if help_panel != null and help_panel.visible: return
	if playtest_panel != null and playtest_panel.visible:
		return
	if accessibility_panel != null and accessibility_panel.visible:
		return
	if expedition_log != null and expedition_log.visible:
		return
	if audio_settings != null and audio_settings.visible:
		return
	if exploration_map.visible or research_log.visible or station_menu.visible:
		return
	if _menu == null and not resource_panel.has_test_focus() and not event.is_echo() and event.is_action_pressed("open_map"):
		open_map()
		get_viewport().set_input_as_handled()
		return
	if _menu == null and not event.is_echo() \
		and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		if route_layer.visible:
			_route_resume_requested()
		else:
			open_route_menu()
		get_viewport().set_input_as_handled()
	elif not route_layer.visible:
		if not development_mode and _menu == null and not event.is_echo() and event.is_action_pressed("interact"):
			if station.is_in_range(submarine.global_position):
				open_station()
			elif chapter!=null and chapter.can_review_buoy():
				chapter.read_buoy()
			elif bloom!=null and bloom.in_range():
				bloom.interact()
			else:
				submarine.scanner.request_scan()
			get_viewport().set_input_as_handled()
		else:
			super._unhandled_input(event)


func open_route_menu() -> void:
	if revision!=null and revision.returning_to_title:
		revision.returning_to_title = false
		route_layer.hide()
		submarine.set_simulation_enabled(false)
		revision.ui.show_title()
		return
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	resource_panel.release_test_focus()
	route_layer.show()
	_save_status()
	route_menu.focus_resume()


func resume_route() -> void:
	if bloom!=null and bloom.modal(): return
	if revision!=null and revision.ui.modal(): return
	if help_panel != null and help_panel.visible: return
	if playtest_panel != null and playtest_panel.visible:
		return
	if accessibility_panel != null and accessibility_panel.visible:
		return
	if expedition_log != null and expedition_log.visible:
		return
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible:
		return
	_expedition_started = true
	route_layer.hide()
	($DevelopmentUI/Banner as Control).show()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	submarine.set_simulation_enabled(true)
	if tutorial != null: tutorial.show_hint("movement")


func _route_settings_requested() -> void:
	route_layer.hide()
	open_settings()


func open_map() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible or resource_panel.has_test_focus():
		return
	if revision!=null: revision._refresh_map_marker()
	_map_from_route = route_layer.visible
	route_layer.hide()
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	exploration_map.present(region.to_local(submarine.global_position), input_context.describe(&"open_map"))


func open_research() -> void:
	if not exploration_map.visible:
		return
	exploration_map.hide()
	research_log.present()


func close_research() -> void:
	research_log.hide()
	exploration_map.present(region.to_local(submarine.global_position), input_context.describe(&"open_map"))


func open_station() -> Error:
	if revision!=null and revision.ui.modal(): return ERR_BUSY
	if _menu != null or route_layer.visible or exploration_map.visible or research_log.visible or station_menu.visible or resource_panel.has_test_focus():
		return ERR_BUSY
	var result: Error = station.interact(submarine)
	if result != OK:
		_station_failure = station.docking_hint(submarine)
		_station_failure_remaining = 1.25
		_refresh_scan_status()
		return result
	_station_failure_remaining = 0.0
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	station_menu.present(station)
	if revision!=null: return revision.on_docked()
	if saves != null:
		saves.save_current()
	return OK


func close_station() -> void:
	if is_instance_valid(station) and station.end_interaction() != OK:
		return
	station_menu.hide()
	resume_route()


func _refresh_scan_status() -> void:
	if development_mode and station.is_in_range(submarine.global_position):
		(%ScanStatus as Label).text = "DEVELOPMENT / Interact: resource tools · Services use normal mode"
	else:
		(%ScanStatus as Label).text = station.docking_hint(submarine) if station.is_in_range(submarine.global_position) else String(submarine.scanner.snapshot().text)

	if _station_failure_remaining>0.0: (%ScanStatus as Label).text = _station_failure
	if input_context != null:
		var label: Label = %ScanStatus
		if accessibility_service != null and accessibility_service.tight_hud() and not station.is_in_range(submarine.global_position):
			var state: Dictionary = submarine.scanner.snapshot()
			label.text = "SCANNING %.0f%% · Interact: cancel" % (state.progress * 100.0) if state.active_id != &"" else label.text.get_slice(" / ", 0)
		label.text = "[%s] %s" % [input_context.describe(&"interact"), label.text]


func close_map() -> void:
	exploration_map.hide()
	if _map_from_route:
		open_route_menu()
	else:
		resume_route()


func open_settings() -> void:
	if not exploration_map.visible and not research_log.visible and not station_menu.visible:
		super.open_settings()


func restart_route() -> void:
	if bloom!=null: bloom.reset_session()
	if station.end_interaction() != OK:
		return
	station_menu.hide()
	if expedition_log != null:
		expedition_log.hide()
	if gameplay_audio != null:
		gameplay_audio.reset_session()
	# Discoveries and their store intentionally survive all test-route resets.
	exploration_map.hide()
	research_log.hide()
	submarine.scanner.reset_session()
	# A complete test-session reset, never a station-entry repair/refill service.
	# Keep component identities so existing HUD/debug signal subscriptions survive.
	if _menu != null:
		close_settings()
	if torpedoes != null:
		torpedoes.reset_session()
	resource_panel.release_test_focus()
	resource_panel.reset_test_counts()
	_contact_time = 0.0
	submarine.set_simulation_enabled(false)
	submarine.sonar.reset_session()
	submarine.passive.reset_session()
	ambient.reset_session()
	creature.reset_session()
	predator.reset_session()
	if extension != null:
		for grazer: AcousticCreature in extension.wildlife: grazer.reset_session()
	submarine.velocity = Vector2.ZERO
	submarine.global_position = region.spawn.global_position
	submarine.reset_physics_interpolation()
	submarine.resource_system.configure(submarine.resource_system.configuration)
	submarine.hull_system.configure(submarine.hull_system.configuration)
	submarine.damage_system.configure(submarine.damage_system.configuration)
	upgrades.reapply()
	submarine.damage_system.advance(0.0, region.depth_at_world(submarine.global_position), submarine.hull_system)
	hud.bind_sources(submarine.resource_system, submarine.hull_system, submarine.damage_system)
	hud.bind_sonar(submarine.sonar)
	hud.bind_passive(submarine.passive)
	hud.bind_threat(predator)
	if gameplay_audio != null:
		gameplay_audio.reset_session()
	route_check.reset()
	var camera: Camera2D = submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	resume_route()


func _physics_process(delta: float) -> void:
	if submarine.is_physics_processing():
		_station_failure_remaining = maxf(0.0,_station_failure_remaining-delta)
		ambient.advance(delta)
		route_check.sample(region.base_zone.contains_world_position(submarine.global_position),
			region.point_of_interest_zone.contains_world_position(submarine.global_position), delta)
		_refresh_route_status()


func _refresh_route_status() -> void:
	var status: Label = %RouteStatus
	match route_check.stage:
		GrayboxRouteCheck.Stage.AT_BASE:
			status.text = "TEST LOOP / Leave 01 Base → 02 Cave → 03 Twin Spires"
		GrayboxRouteCheck.Stage.OUTBOUND:
			status.text = "TEST LOOP / Follow 02 Cave → 03 Twin Spires"
		GrayboxRouteCheck.Stage.RETURNING:
			status.text = "LANDMARK REACHED / Follow BASE arrows west via lower passage"
		GrayboxRouteCheck.Stage.COMPLETE:
			status.text = "LOOP COMPLETE / %.1f s active piloting · Pause / Start to restart" % route_check.elapsed_seconds

	if narrative != null:
		status.text = narrative.guidance() if route_check.stage != GrayboxRouteCheck.Stage.COMPLETE else (
			"LOOP COMPLETE / CHAPTER CONCLUDED · Pause: expedition log" if narrative.is_concluded() else "LOOP COMPLETE / " + narrative.guidance().get_slice(" / ", 1))


func _refresh_mission_status() -> void:
	(%MissionStatus as Label).text = missions.status_text() if missions.store.can_write() else "MISSIONS / SAVE BLOCKED · Open station mission board for recovery"

	if accessibility_service != null and accessibility_service.tight_hud() and missions.store.can_write():
		var records: Dictionary = missions.snapshot()
		(%MissionStatus as Label).text = "MISSIONS / Survey %s %d/2 · Study %s %d/1" % [String(records["shelf-expedition"].state).to_upper(), records["shelf-expedition"].objectives.size(), String(records["shelf-calibration-study"].state).to_upper(), records["shelf-calibration-study"].objectives.size()]


func _save_status() -> void:
	if narrative != null:
		narrative.log_changed.emit()
	if saves == null:
		route_menu.configure_save_ui(false, _expedition_started, false, "Expedition saving not configured for this development fixture.")
	else:
		route_menu.configure_save_ui(saves.has_checkpoint(), _expedition_started, saves.can_write(), saves.status)
		(%MissionStatus as Label).tooltip_text = saves.status
		var checkpoint_label: Label = station_menu.get_node("%CheckpointStatus") as Label
		checkpoint_label.show()
		checkpoint_label.text = saves.status


func _route_resume_requested() -> void:
	if saves != null and not saves.can_write():
		return
	if saves != null and saves.has_checkpoint() and not _expedition_started:
		if saves.continue_expedition() != OK:
			return
	if extended_expedition and narrative != null and revision==null: narrative.begin_survey()
	resume_route()


func _manual_save() -> void:
	if saves != null and not (saves.has_checkpoint() and not _expedition_started):
		saves.save_current()


func _recover_expedition() -> void:
	if saves != null:
		saves.recover_backup()


func _new_expedition() -> void:
	if saves != null and saves.new_expedition() == OK:
		if extended_expedition and revision==null: narrative.begin_survey()
		resume_route()


func _layout_tutorial() -> void:
	if tutorial_card == null: return
	var width: float = get_viewport().get_visible_rect().size.x
	tutorial_card.size = Vector2(minf(340.0,width*0.32),0.0)
	tutorial_card.custom_minimum_size.x = minf(280.0,width*0.32)
	tutorial_card.position = Vector2(24,(hud.get_node("%InstrumentDeck") as Control).get_global_rect().end.y+50.0+12)
	tutorial_card.visible = not tutorial_card.title_label.text.is_empty() and submarine.is_physics_processing() and (revision==null or not revision.ui.notifications.visible or not revision.ui.notifications.panel.visible)

func close_settings() -> void:
	super.close_settings()
	if revision!=null and revision.returning_to_title: open_route_menu()
