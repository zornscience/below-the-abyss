class_name ShelfPrototype
extends MovementPrototype
## BTA-014 scene composition and ephemeral route-check telemetry.

var route_check: GrayboxRouteCheck = GrayboxRouteCheck.new()
@onready var region: ContinentalShelf = $WorldRoot/CurrentRegion
@onready var route_layer: CanvasLayer = $RouteLayer
@onready var route_menu: GrayboxRouteMenu = $RouteLayer/RouteMenu
@onready var ambient: AmbientAcousticField = $WorldRoot/CurrentRegion/AmbientField


func _ready() -> void:
	# Place the existing vessel before the shared orchestration samples depth.
	submarine.global_position = region.spawn.global_position
	region.configure_camera(submarine.get_node("Camera2D") as Camera2D)
	super._ready()
	var bus: AcousticBus = $AcousticBus
	if submarine.sonar.setup(bus, submarine.resource_system, $WorldRoot/WorldEffects) != OK:
		push_error("Shelf active sonar setup failed.")
	for node: Node in region.get_node("SonarTargets").get_children():
		var target: SonarRevealTarget = node as SonarRevealTarget
		if target.bind_bus(bus) != OK or submarine.sonar.listen_to(target) != OK:
			push_error("Shelf sonar target registration failed.")
	hud.bind_sonar(submarine.sonar)
	if submarine.passive.bind_bus(bus) != OK or ambient.bind_bus(bus) != OK:
		push_error("Shelf passive sonar setup failed.")
	hud.bind_passive(submarine.passive)
	($DevelopmentUI/Banner as Control).offset_top = 215.0
	route_menu.resume_requested.connect(resume_route)
	route_menu.settings_requested.connect(_route_settings_requested)
	route_menu.restart_requested.connect(restart_route)
	route_check.stage_changed.connect(func(_stage: int) -> void: _refresh_route_status())
	_refresh_route_status()
	open_route_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _menu == null and not event.is_echo() \
		and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		if route_layer.visible:
			resume_route()
		else:
			open_route_menu()
		get_viewport().set_input_as_handled()
	elif not route_layer.visible:
		super._unhandled_input(event)


func open_route_menu() -> void:
	if _menu != null:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_simulation_enabled(false)
	resource_panel.release_test_focus()
	route_layer.show()
	route_menu.focus_resume()


func resume_route() -> void:
	if _menu != null:
		return
	route_layer.hide()
	($DevelopmentUI/Banner as Control).show()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	submarine.set_simulation_enabled(true)


func _route_settings_requested() -> void:
	route_layer.hide()
	open_settings()


func restart_route() -> void:
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
	submarine.velocity = Vector2.ZERO
	submarine.global_position = region.spawn.global_position
	submarine.reset_physics_interpolation()
	submarine.resource_system.configure(submarine.resource_system.configuration)
	submarine.hull_system.configure(submarine.hull_system.configuration)
	submarine.damage_system.configure(submarine.damage_system.configuration)
	submarine.damage_system.advance(0.0, region.depth_at_world(submarine.global_position), submarine.hull_system)
	hud.bind_sources(submarine.resource_system, submarine.hull_system, submarine.damage_system)
	hud.bind_sonar(submarine.sonar)
	hud.bind_passive(submarine.passive)
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
