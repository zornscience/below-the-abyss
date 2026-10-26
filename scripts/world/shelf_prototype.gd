class_name ShelfPrototype
extends MovementPrototype
## BTA-014 scene composition and ephemeral route-check telemetry.

@export var expedition_path: String = ""
var audio: SoundscapeMixer
var gameplay_audio: GameplayAudio
var audio_settings: AudioSettingsPanel
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
	# Place the existing vessel before the shared orchestration samples depth.
	submarine.global_position = region.spawn.global_position
	region.configure_camera(submarine.get_node("Camera2D") as Camera2D)
	super._ready()
	var bus: AcousticBus = $AcousticBus
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
	if discoveries.configure(DISCOVERY_CATALOG) != OK:
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
	if research.configure(RESEARCH_CATALOG) != OK:
		push_error("Invalid research catalogue.")
	research_store.path = research_path if not research_path.is_empty() else (
		ResearchStore.DEFAULT_PATH if settings_path == SettingsStore.DEFAULT_PATH else settings_path + ".research.json")
	research_store.load_registry(research)
	research.scan_completed.connect(func(_id: StringName) -> void: research_store.save_registry(research))
	var targets: Array[ScientificScanTarget] = []
	var research_catalog: ResearchCatalog = RESEARCH_CATALOG
	for definition: ScanDefinition in research_catalog.targets:
		var target: ScientificScanTarget = ScientificScanTarget.new()
		target.name = String(definition.stable_id)
		target.target_id = definition.stable_id
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
	if missions.setup(MISSION_CATALOG, discoveries, research, route_check, missions_file) != OK:
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
	open_route_menu()


func open_audio_settings() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	route_layer.hide()
	audio_settings.present(settings, audio, settings_path)


func _unhandled_input(event: InputEvent) -> void:
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
			else:
				submarine.scanner.request_scan()
			get_viewport().set_input_as_handled()
		else:
			super._unhandled_input(event)


func open_route_menu() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	resource_panel.release_test_focus()
	route_layer.show()
	_save_status()
	route_menu.focus_resume()


func resume_route() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible:
		return
	_expedition_started = true
	route_layer.hide()
	($DevelopmentUI/Banner as Control).show()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	submarine.set_simulation_enabled(true)


func _route_settings_requested() -> void:
	route_layer.hide()
	open_settings()


func open_map() -> void:
	if _menu != null or exploration_map.visible or research_log.visible or station_menu.visible or resource_panel.has_test_focus():
		return
	_map_from_route = route_layer.visible
	route_layer.hide()
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	exploration_map.present(region.to_local(submarine.global_position), InputBindings.describe(settings.snapshot()["bindings"], &"open_map"))


func open_research() -> void:
	if not exploration_map.visible:
		return
	exploration_map.hide()
	research_log.present()


func close_research() -> void:
	research_log.hide()
	exploration_map.present(region.to_local(submarine.global_position), InputBindings.describe(settings.snapshot()["bindings"], &"open_map"))


func open_station() -> Error:
	if _menu != null or route_layer.visible or exploration_map.visible or research_log.visible or station_menu.visible or resource_panel.has_test_focus():
		return ERR_BUSY
	var result: Error = station.interact(submarine)
	if result != OK:
		_refresh_scan_status()
		return result
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	station_menu.present(station)
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
	if station.end_interaction() != OK:
		return
	station_menu.hide()
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
	resource_panel.release_test_focus()
	resource_panel.reset_test_counts()
	_contact_time = 0.0
	submarine.set_simulation_enabled(false)
	submarine.sonar.reset_session()
	submarine.passive.reset_session()
	ambient.reset_session()
	creature.reset_session()
	predator.reset_session()
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


func _refresh_mission_status() -> void:
	(%MissionStatus as Label).text = missions.status_text() if missions.store.can_write() else "MISSIONS / SAVE BLOCKED · Open station mission board for recovery"


func _save_status() -> void:
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
	resume_route()


func _manual_save() -> void:
	if saves != null and not (saves.has_checkpoint() and not _expedition_started):
		saves.save_current()


func _recover_expedition() -> void:
	if saves != null:
		saves.recover_backup()


func _new_expedition() -> void:
	if saves != null and saves.new_expedition() == OK:
		resume_route()
