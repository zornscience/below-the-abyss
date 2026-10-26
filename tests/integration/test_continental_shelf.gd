extends GutTest

const SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const FIXTURE: PackedScene = preload("res://scenes/main/movement_prototype.tscn")
var _scene: ShelfPrototype
var _flight_steps: int = 0


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(), 0.25)
	_scene = SCENE.instantiate() as ShelfPrototype
	_scene.settings_path = "user://bta014-no-settings-%d.json" % Time.get_ticks_usec()
	add_child_autofree(_scene)
	await _frames(2)


func after_each() -> void:
	ShelfRouteDriver.release()
	InputBindings.apply(InputBindings.defaults(), 0.25)
	if FileAccess.file_exists(_scene.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scene.settings_path))


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _point(name: String) -> Vector2:
	return (_scene.region.get_node("RouteMarkers/" + name) as Marker2D).global_position


func _query_at(position: Vector2, margin: float = 2.0) -> PhysicsShapeQueryParameters2D:
	var shape: CollisionShape2D = _scene.submarine.get_node("CollisionShape2D") as CollisionShape2D
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = Transform2D(shape.global_rotation, position)
	query.collision_mask = 1
	query.margin = margin
	return query


func _clear_segment(start: Vector2, finish: Vector2) -> void:
	var space: PhysicsDirectSpaceState2D = _scene.submarine.get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = _query_at(start)
	assert_true(space.intersect_shape(query).is_empty(), "Full submarine shape clear at %s" % start)
	query.motion = finish - start
	assert_eq(space.cast_motion(query)[0], 1.0, "Continuous full-hull route clearance: %s → %s" % [start, finish])


func _fly_to(target: Vector2) -> void:
	for _index: int in range(1500):
		ShelfRouteDriver.steer(_scene.submarine.global_position, target)
		await get_tree().physics_frame
		_flight_steps += 1
		if _scene.submarine.global_position.distance_to(target) < 12.0 and _scene.submarine.velocity.length() < 30.0:
			ShelfRouteDriver.release()
			return
	ShelfRouteDriver.release()
	fail_test("Could not pilot to %s from %s" % [target, _scene.submarine.global_position])


func test_default_scene_spawn_and_fixture_remain_valid() -> void:
	assert_true(_scene.region is ContinentalShelf)
	assert_eq(_scene.submarine.global_position, _scene.region.spawn.global_position)
	assert_true(_scene.region.base_zone.contains_world_position(_scene.submarine.global_position))
	assert_true(_scene.submarine.get_world_2d().direct_space_state.intersect_shape(_query_at(_scene.submarine.global_position)).is_empty())
	assert_eq(_scene.submarine.damage_system.depth_m, 120.0)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.submarine.resource_system.battery, 100.0, "Briefing starts paused with full resources.")
	assert_true(_scene.route_layer.visible)
	assert_false(_scene.submarine.is_physics_processing())
	assert_eq(_scene.hud.hull_gauge.current_value, 100.0)
	var fixture: MovementPrototype = FIXTURE.instantiate() as MovementPrototype
	fixture.settings_path = "user://bta014-fixture-no-settings.json"
	add_child_autofree(fixture)
	assert_eq(fixture.submarine.position, Vector2(400, 520))
	assert_eq(fixture.submarine.damage_system.depth_m, 130.0)
	assert_true(fixture.submarine.is_physics_processing())
	(fixture.submarine.get_node("Camera2D") as Camera2D).enabled = false


func test_required_loop_and_optional_branches_have_continuous_hull_clearance() -> void:
	var start: Vector2 = _scene.region.spawn.global_position
	for name: String in ShelfRouteDriver.OUTBOUND + ShelfRouteDriver.RETURN:
		var finish: Vector2 = _point(name)
		_clear_segment(start, finish)
		assert_lt(_scene.region.depth_at_world(finish), 260.0, "Required loop remains below caution.")
		start = finish
	_clear_segment(start, _scene.region.spawn.global_position)
	start = _point("OverlookEntry")
	for name: String in ["OverlookWest", "OverlookTopWest", "OverlookTopEast", "OverlookExit"]:
		_clear_segment(start, _point(name))
		start = _point(name)
	_clear_segment(start, _point("Cave"))
	_clear_segment(_point("LowerEast"), _point("TrenchEntry"))
	_clear_segment(_point("TrenchEntry"), _point("TrenchBottom"))
	_clear_segment(_point("TrenchBottom"), _point("TrenchEntry"))


func test_terrain_visuals_and_collision_layers_are_exact_and_zones_are_not_solid() -> void:
	var terrain: Node = _scene.region.get_node("Terrain")
	assert_eq(terrain.get_child_count(), 10)
	for node: Node in terrain.get_children():
		var rock: GrayboxRock = node as GrayboxRock
		assert_eq((rock.get_node("Silhouette") as Polygon2D).polygon, rock.outline)
		assert_eq((rock.get_node("Boundary") as CollisionPolygon2D).polygon, rock.outline)
		assert_eq(rock.collision_layer, 1)
		assert_eq(rock.collision_mask, 2)
	assert_eq(_scene.submarine.collision_layer, 2)
	assert_eq(_scene.submarine.collision_mask, 1)
	assert_eq(_scene.region.base_zone.collision_layer, 4)
	assert_eq(_scene.region.point_of_interest_zone.collision_mask, 2)


func test_outer_boundaries_and_spires_block_swept_motion_without_penetration() -> void:
	var cases: Array[Vector4] = [
		Vector4(260, 900, -800, 0), Vector4(3900, 500, 800, 0),
		Vector4(1000, 400, 0, -800), Vector4(1000, 1000, 0, 800),
		Vector4(3080, 1500, 0, 800), Vector4(3470, 700, 0, 800)]
	for example: Vector4 in cases:
		_scene.submarine.global_position = Vector2(example.x, example.y)
		_scene.submarine.reset_physics_interpolation()
		var contact: KinematicCollision2D = _scene.submarine.move_and_collide(Vector2(example.z, example.w))
		assert_not_null(contact)
		assert_true(_scene.submarine.get_world_2d().direct_space_state.intersect_shape(
			_query_at(_scene.submarine.global_position, 0.0)).is_empty(), "Boundary sweep ends outside rock.")
		assert_true(Rect2(Vector2.ZERO, Vector2(4100, 1800)).has_point(_scene.submarine.global_position))


func test_authored_depth_datum_thresholds_and_region_transform_are_consistent() -> void:
	assert_eq(_scene.region.depth_at_world(_scene.region.get_node("WaterSurfaceReference").global_position), 0.0)
	assert_eq(_scene.region.depth_at_world(_point("CautionDepth")), 270.0)
	assert_eq(_scene.region.depth_at_world(_point("DangerDepth")), 320.0)
	_scene.submarine.damage_system.advance(0.0, 260.0, _scene.submarine.hull_system)
	assert_eq(_scene.submarine.damage_system.warning_state, SubmarineDamageSystem.WarningState.APPROACHING)
	_scene.submarine.damage_system.advance(0.0, 300.0, _scene.submarine.hull_system)
	assert_eq(_scene.submarine.damage_system.warning_state, SubmarineDamageSystem.WarningState.APPROACHING)
	_scene.submarine.damage_system.advance(0.0, 300.01, _scene.submarine.hull_system)
	assert_eq(_scene.submarine.damage_system.warning_state, SubmarineDamageSystem.WarningState.EXCEEDED)
	_scene.region.position = Vector2(700, -300)
	_scene.region.scale = Vector2(1.2, 1.1)
	assert_eq(_scene.region.depth_at_world(_point("DangerDepth")), 320.0)
	assert_true(_scene.region.base_zone.contains_world_position(_scene.region.spawn.global_position))


func test_real_input_flight_completes_the_outbound_and_lower_return_with_reserves() -> void:
	_scene.resume_route()
	watch_signals(_scene.submarine)
	watch_signals(_scene.submarine.damage_system)
	assert_eq(_scene.open_station(), OK)
	assert_eq(_scene.station.mission_action(&"accept", &"shelf-expedition"), OK)
	assert_eq(_scene.station.mission_action(&"accept", &"shelf-calibration-study"), OK)
	_scene.close_station()
	# Existing sonar/scanner actions earn real domain evidence on the original route.
	await _fly_to(Vector2(760, 480))
	await _tap(_key(KEY_F))
	await _frames(65)
	await _tap(_key(KEY_E))
	await _frames(190)
	assert_true(_scene.research.is_completed(&"shelf-calibration-plate"))
	for name: String in ShelfRouteDriver.OUTBOUND:
		await _fly_to(_point(name))
	assert_eq(_scene.route_check.stage, GrayboxRouteCheck.Stage.RETURNING)
	await _tap(_key(KEY_F))
	await _frames(65)
	for name: String in ShelfRouteDriver.RETURN:
		await _fly_to(_point(name))
	await _fly_to(_scene.region.spawn.global_position)
	await _frames(2)
	assert_eq(_scene.route_check.stage, GrayboxRouteCheck.Stage.COMPLETE)
	assert_lt(_scene.route_check.elapsed_seconds, 100.0, "Well below the ten-minute acceptance limit.")
	assert_lt(float(_flight_steps) / Engine.physics_ticks_per_second, 100.0, "The entire flight to the exact spawn also fits the limit.")
	assert_gt(_scene.submarine.resource_system.battery, 15.0)
	assert_gt(_scene.submarine.resource_system.oxygen, 60.0)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_signal_not_emitted(_scene.submarine, "collision_occurred")
	assert_signal_not_emitted(_scene.submarine.damage_system, "pressure_damage_applied")
	assert_true((_scene.get_node("%RouteStatus") as Label).text.begins_with("LOOP COMPLETE"))
	assert_eq(_scene.hud.battery_gauge.current_value, _scene.submarine.resource_system.battery)
	# Returning is not a station repair/refill service.
	assert_lt(_scene.submarine.resource_system.battery, 90.0)
	gut.p("BTA014 route active_seconds=%.2f full_flight_seconds=%.2f battery=%.2f oxygen=%.2f hull=%.1f" % [
		_scene.route_check.elapsed_seconds, float(_flight_steps) / Engine.physics_ticks_per_second, _scene.submarine.resource_system.battery,
		_scene.submarine.resource_system.oxygen, _scene.submarine.hull_system.hull])

	# BTA-032 extends the existing real flight with explicit services, without
	# weakening the pre-service no-auto-refill/reserve/route assertions above.
	await _tap(_key(KEY_E))
	assert_true(_scene.station_menu.visible)
	var history: int = (_scene.get_node("AcousticBus") as AcousticBus).history_count()
	var elapsed: float = _scene.route_check.elapsed_seconds
	var position: Vector2 = _scene.submarine.global_position
	(_scene.station_menu.get_node("%ServiceAll") as Button).pressed.emit()
	assert_eq(_scene.submarine.resource_system.battery, 100.0)
	assert_eq(_scene.submarine.resource_system.oxygen, 100.0)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.route_check.stage, GrayboxRouteCheck.Stage.COMPLETE)
	assert_eq(_scene.route_check.elapsed_seconds, elapsed)
	assert_eq((_scene.get_node("AcousticBus") as AcousticBus).history_count(), history)
	assert_eq(_scene.submarine.global_position, position)
	assert_eq(_scene.missions.snapshot()["shelf-expedition"].state, "completed")
	assert_eq(_scene.missions.snapshot()["shelf-calibration-study"].state, "completed")
	assert_eq(_scene.station.mission_action(&"claim", &"shelf-expedition"), OK)
	assert_eq(_scene.station.mission_action(&"claim", &"shelf-calibration-study"), OK)
	assert_eq(_scene.station.mission_action(&"claim", &"shelf-expedition"), ERR_ALREADY_EXISTS)
	gut.p("BTA034 real-input accept-scan-discover-return-claim: two acknowledgements saved")
	_scene.close_station()
	assert_true(_scene.submarine.is_physics_processing())
	gut.p("BTA032 depart-explore-return-service loop: full resources, route/history retained")


func test_camera_bounds_follow_the_region_and_smoothing_tracks_interior_movement() -> void:
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	assert_eq(camera.limit_right, 4100)
	assert_eq(camera.limit_bottom, 1800)
	_scene.submarine.global_position = _point("Cave")
	_scene.submarine.reset_physics_interpolation()
	camera.reset_smoothing()
	camera.force_update_scroll()
	_scene.resume_route()
	var start: float = camera.get_screen_center_position().x
	Input.action_press("move_right")
	await _frames(20)
	ShelfRouteDriver.release()
	assert_true(camera.position_smoothing_enabled)
	assert_gt(camera.get_screen_center_position().x, start)
	assert_lt(camera.get_screen_center_position().x, _scene.submarine.global_position.x)
	assert_gt(camera.get_screen_center_position().x, 640.0)
	assert_lt(camera.get_screen_center_position().x, 3460.0)


func test_pressure_hazard_pause_and_restart_restore_a_clean_test_session() -> void:
	_scene.resume_route()
	_scene.submarine.position = _point("DangerDepth")
	_scene.submarine.reset_physics_interpolation()
	await _frames(160)
	assert_lt(_scene.submarine.hull_system.hull, 100.0)
	assert_true((_scene.hud.get_node("%WarningState") as Label).text.begins_with("DANGER"))
	_scene.open_route_menu()
	var hull: float = _scene.submarine.hull_system.hull
	var elapsed: float = _scene.route_check.elapsed_seconds
	await _frames(10)
	assert_eq(_scene.submarine.hull_system.hull, hull)
	assert_eq(_scene.route_check.elapsed_seconds, elapsed)
	_scene.restart_route()
	assert_eq(_scene.submarine.position, _scene.region.spawn.position)
	assert_eq(_scene.submarine.velocity, Vector2.ZERO)
	assert_eq(_scene.submarine.hull_system.hull, 100.0)
	assert_eq(_scene.submarine.resource_system.battery, 100.0)
	assert_eq(_scene.submarine.resource_system.oxygen, 100.0)
	assert_eq(_scene.submarine.damage_system.depth_m, 120.0)
	assert_eq(_scene.submarine.damage_system.warning_state, SubmarineDamageSystem.WarningState.SAFE)
	assert_eq(_scene.route_check.stage, GrayboxRouteCheck.Stage.AT_BASE)
	assert_eq(_scene.route_check.elapsed_seconds, 0.0)
	assert_eq((_scene.hud.get_node("%PressureFeedback") as Label).text, "")
	assert_false(_scene.route_layer.visible)
	assert_null(get_viewport().gui_get_focus_owner())
	assert_true(_scene.submarine.is_physics_processing())


func _tap(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release: InputEvent = event.duplicate() as InputEvent
	release.set("pressed", false)
	Input.parse_input_event(release)
	await get_tree().process_frame


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _button(code: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	return event


func test_keyboard_and_controller_can_resume_restart_and_open_existing_settings() -> void:
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.route_menu.get_node("%Resume"))
	await _tap(_key(KEY_DOWN))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.route_menu.get_node("%Settings"))
	await _tap(_key(KEY_ENTER))
	assert_not_null(_scene._menu)
	assert_false(_scene.submarine.is_physics_processing())
	assert_false(_scene.route_layer.visible)
	(_scene._menu.get_node("%Quit") as Button).pressed.emit()
	await _frames(2)
	assert_true(_scene.submarine.is_physics_processing())
	await _tap(_key(KEY_P))
	assert_true(_scene.route_layer.visible)
	await _tap(_key(KEY_UP))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.route_menu.get_node("%Restart"))
	await _tap(_key(KEY_ENTER))
	assert_false(_scene.route_layer.visible)
	assert_eq(_scene.submarine.position, _scene.region.spawn.position)
	await _tap(_button(JOY_BUTTON_START))
	assert_true(_scene.route_layer.visible)
	await _tap(_button(JOY_BUTTON_DPAD_DOWN))
	await _tap(_button(JOY_BUTTON_A))
	assert_not_null(_scene._menu)
	(_scene._menu.get_node("%Quit") as Button).pressed.emit()
	await _frames(2)
	await _tap(_button(JOY_BUTTON_START))
	await _tap(_button(JOY_BUTTON_DPAD_UP))
	assert_eq(get_viewport().gui_get_focus_owner(), _scene.route_menu.get_node("%Restart"))
	await _tap(_button(JOY_BUTTON_A))
	assert_false(_scene.route_layer.visible)
	assert_true(_scene.submarine.is_physics_processing())
	assert_null(get_viewport().gui_get_focus_owner())


func test_restart_preserves_saved_input_settings_and_camera_returns_to_base() -> void:
	var event: InputEventKey = _key(KEY_T)
	assert_eq(_scene.settings.remap(&"move_right", event), OK)
	assert_eq(_scene.settings.save_settings(_scene.settings_path), OK)
	_scene._route_settings_requested()
	_scene.close_settings()
	assert_true(InputMap.action_has_event("move_right", event))
	_scene.submarine.position = _point("TwinSpires")
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	_scene.restart_route()
	await _frames(2)
	assert_true(InputMap.action_has_event("move_right", event))
	assert_eq(_scene.submarine.position, _scene.region.spawn.position)
	assert_lt(camera.get_screen_center_position().x, 1000.0, "No long camera fly-back after restarting.")
	assert_eq(_scene.hud.hull_gauge.current_value, 100.0)


func test_camera_clamps_at_the_station_east_boundary_and_deep_trench() -> void:
	var camera: Camera2D = _scene.submarine.get_node("Camera2D") as Camera2D
	var half_view: Vector2 = _scene.submarine.get_viewport_rect().size * 0.5
	for position: Vector2 in [Vector2(420, 480), Vector2(3900, 500), Vector2(3080, 1500)]:
		_scene.submarine.position = position
		_scene.submarine.reset_physics_interpolation()
		camera.reset_smoothing()
		camera.force_update_scroll()
		await _frames(2)
		var center: Vector2 = camera.get_screen_center_position()
		assert_almost_eq(center.x, clampf(position.x, half_view.x, 4100.0 - half_view.x), 0.1)
		assert_almost_eq(center.y, clampf(position.y, half_view.y, 1800.0 - half_view.y), 0.1)


func _check_menu_bounds(node: Node, bounds: Rect2) -> void:
	if node is Control:
		assert_true(bounds.encloses((node as Control).get_global_rect()), "%s fits minimum window" % node.name)
	for child: Node in node.get_children():
		_check_menu_bounds(child, bounds)


func test_route_menu_fits_the_minimum_window_without_hiding_any_action() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var scene: ShelfPrototype = SCENE.instantiate() as ShelfPrototype
	scene.settings_path = "user://bta014-menu-layout-no-settings.json"
	viewport.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_menu_bounds(scene.route_menu, Rect2(Vector2.ZERO, Vector2(800, 600)))
	var guide: Control = scene.get_node("UI/RouteGuide") as Control
	assert_true(Rect2(Vector2.ZERO, Vector2(800, 600)).encloses(guide.get_global_rect()))
	assert_eq(guide.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for name: String in ["%Resume", "%Settings", "%Restart"]:
		assert_true((scene.route_menu.get_node(name) as Button).is_visible_in_tree())
