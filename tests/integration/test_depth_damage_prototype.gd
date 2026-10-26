extends GutTest

const PROTOTYPE: PackedScene = preload("res://scenes/main/main.tscn")
const SUBMARINE: PackedScene = preload("res://scenes/player/submarine.tscn")
var _old_fps: int


func before_each() -> void:
	_old_fps = Engine.max_fps
	InputBindings.apply(InputBindings.defaults(), 0.25)


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	Engine.max_fps = _old_fps
	InputBindings.apply(InputBindings.defaults(), 0.25)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _prototype() -> MovementPrototype:
	var scene: MovementPrototype = PROTOTYPE.instantiate() as MovementPrototype
	scene.development_mode = true
	scene.settings_path = "user://bta012-no-settings-%d.json" % Time.get_ticks_usec()
	add_child_autofree(scene)
	return scene


func _wall(center: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 2
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child_autofree(body)


func _body(position: Vector2) -> SubmarineController:
	var body: SubmarineController = SUBMARINE.instantiate() as SubmarineController
	body.position = position
	(body.get_node("Camera2D") as Camera2D).enabled = false
	add_child_autofree(body)
	return body


func test_authored_depth_warnings_and_exact_limit_keep_the_hull_safe() -> void:
	var scene: MovementPrototype = _prototype()
	var body: SubmarineController = scene.submarine
	assert_eq(body.damage_system.depth_m, 130.0, "Spawn mapping is initialized before the first tick.")
	body.position = Vector2(325.0, 1040.0)
	body.reset_physics_interpolation()
	await _frames(2)
	await get_tree().process_frame
	assert_eq(body.damage_system.warning_state, SubmarineDamageSystem.WarningState.APPROACHING)
	assert_true((scene.hud.get_node("%WarningState") as Label).text.contains("CAUTION"))
	body.position.y = 1200.0
	body.reset_physics_interpolation()
	await _frames(90)
	assert_eq(body.hull_system.hull, 100.0)
	assert_eq(body.damage_system.depth_m, 300.0)


func test_deep_shaft_can_be_reached_by_piloting_and_pressure_uses_hull_api() -> void:
	var scene: MovementPrototype = _prototype()
	var body: SubmarineController = scene.submarine
	body.position.x = 325.0
	body.reset_physics_interpolation()
	watch_signals(body)
	watch_signals(body.damage_system)
	Input.action_press("move_down")
	await _frames(360)
	Input.action_release("move_down")
	assert_gt(body.position.y, 1800.0)
	assert_lt(body.position.y, 2110.0)
	assert_gt(body.damage_system.depth_m, 450.0)
	assert_signal_not_emitted(body, "collision_occurred", "The marked shaft has a clear descent route.")
	assert_signal_emitted(body.damage_system, "pressure_damage_applied")
	assert_lt(body.hull_system.hull, 100.0)
	assert_gt(body.hull_system.hull, 90.0)
	assert_eq(body.hull_system.last_damage_source, &"pressure")
	assert_true((scene.hud.get_node("%WarningState") as Label).text.contains("DANGER"))


func test_settings_and_resource_checks_freeze_pressure_grace_and_damage() -> void:
	var scene: MovementPrototype = _prototype()
	var body: SubmarineController = scene.submarine
	body.position = Vector2(325.0, 1800.0)
	body.reset_physics_interpolation()
	await _frames(30)
	scene.open_settings()
	var grace: float = body.damage_system.grace_remaining_seconds
	var hull: float = body.hull_system.hull
	await _frames(30)
	assert_eq(body.damage_system.grace_remaining_seconds, grace)
	assert_eq(body.hull_system.hull, hull)
	scene.close_settings()
	await _frames(10)
	assert_lt(body.damage_system.grace_remaining_seconds, grace)
	scene.resource_panel.focus_test_controls()
	grace = body.damage_system.grace_remaining_seconds
	await _frames(30)
	assert_eq(body.damage_system.grace_remaining_seconds, grace)
	assert_eq(body.hull_system.hull, hull)


func test_grazing_and_insignificant_contacts_do_not_damage_hull() -> void:
	_wall(Vector2(200.0, 0.0), Vector2(12.0, 2000.0))
	var body: SubmarineController = _body(Vector2(160.0, 0.0))
	body.velocity = Vector2(20.0, 230.0)
	watch_signals(body)
	watch_signals(body.damage_system)
	await _frames(30)
	assert_signal_emitted(body, "collision_occurred")
	assert_signal_not_emitted(body.damage_system, "collision_damage_applied")
	assert_eq(body.hull_system.hull, 100.0, "Damage uses normal approach speed, not total speed.")
	Input.action_press("move_right")
	await _frames(120)
	assert_eq(body.hull_system.hull, 100.0, "Ordinary wall push/jitter never reaches the impact threshold.")


func test_corner_contacts_are_aggregated_to_one_bounded_hit() -> void:
	_wall(Vector2(200.0, 0.0), Vector2(12.0, 2000.0))
	_wall(Vector2(0.0, 200.0), Vector2(2000.0, 12.0))
	var body: SubmarineController = _body(Vector2(152.0, 168.0))
	body.velocity = Vector2(170.0, 170.0)
	watch_signals(body.damage_system)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _frames(60)
	assert_signal_emit_count(body.damage_system, "collision_damage_applied", 1)
	assert_gt(body.hull_system.hull, 96.0)
	assert_lt(body.hull_system.hull, 99.0)


func test_pressure_matches_at_actual_30_60_and_120_render_caps() -> void:
	var losses: Array[float] = []
	for cap: int in [30, 60, 120]:
		Engine.max_fps = cap
		var region: DepthRegion = DepthRegion.new()
		add_child_autofree(region)
		var body: SubmarineController = _body(Vector2(0.0, 1600.0))
		body.depth_region = region
		var profile: SubmarineDamageConfig = SubmarineDamageConfig.new()
		profile.pressure_grace_seconds = 0.0
		body.damage_system.configure(profile)
		await _frames(2)
		var start: float = body.hull_system.hull
		await _frames(60)
		losses.append(start - body.hull_system.hull)
		body.queue_free()
		region.queue_free()
		await _frames(2)
	for loss: float in losses:
		assert_almost_eq(loss, 4.0, 0.15, "One simulation second at four hull units/second.")
