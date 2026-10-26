extends GutTest

const SUBMARINE: PackedScene = preload("res://scenes/player/submarine.tscn")
const PROTOTYPE: PackedScene = preload("res://scenes/main/movement_prototype.tscn")
var _old_ticks: int
var _old_max_fps: int
var _path: String


func before_each() -> void:
	_old_ticks = Engine.physics_ticks_per_second
	_old_max_fps = Engine.max_fps
	Engine.physics_ticks_per_second = 60
	_path = "user://bta010-settings-%d.json" % Time.get_ticks_usec()
	InputBindings.apply(InputBindings.defaults(), 0.25)


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS:
		Input.action_release(action)
	Engine.physics_ticks_per_second = _old_ticks
	Engine.max_fps = _old_max_fps
	InputBindings.apply(InputBindings.defaults(), 0.25)
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _submarine() -> SubmarineController:
	var body: SubmarineController = SUBMARINE.instantiate() as SubmarineController
	body.motion = body.motion.duplicate() as SubmarineMotion
	(body.get_node("Camera2D") as Camera2D).enabled = false
	add_child_autofree(body)
	return body


func _wall(center: Vector2, size: Vector2) -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 2
	wall.position = center
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	wall.add_child(collision)
	add_child_autofree(wall)


func test_swept_collision_stops_at_a_wall_and_emits_contact() -> void:
	_wall(Vector2(200.0, 0.0), Vector2(12.0, 2000.0))
	var body: SubmarineController = _submarine()
	watch_signals(body)
	await _frames(2)
	Input.action_press("move_right")
	await _frames(90)
	assert_gt(body.position.x, 150.0)
	assert_lte(body.position.x, 162.1, "Wall near face 194 minus capsule half-width 32.")
	assert_almost_eq(body.velocity.x, 0.0, 0.01)
	assert_signal_emitted(body, "collision_occurred")
	var arguments: Array = get_signal_parameters(body, "collision_occurred")
	assert_almost_eq((arguments[0] as Vector2).x, -1.0, 0.01)
	assert_gt(float(arguments[1]), 0.0)


func test_diagonal_thrust_slides_along_a_wall_without_penetration() -> void:
	_wall(Vector2(200.0, 0.0), Vector2(12.0, 2000.0))
	var body: SubmarineController = _submarine()
	await _frames(2)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _frames(100)
	assert_lte(body.position.x, 162.1)
	assert_gt(body.position.y, 200.0, "Tangential movement continues along the wall.")
	assert_lte(body.velocity.x, 0.01, "No inward wall velocity; swept contacts can leave a small outward component.")
	assert_gt(body.velocity.x, -2.0)
	assert_gt(body.velocity.y, 0.0)


func test_thin_wall_is_not_tunnelled_at_high_speed_and_30_physics_ticks() -> void:
	Engine.physics_ticks_per_second = 30
	_wall(Vector2(200.0, 0.0), Vector2(12.0, 2000.0))
	var body: SubmarineController = _submarine()
	body.motion.acceleration = 6000.0
	body.motion.maximum_speed = 1200.0
	await _frames(2)
	Input.action_press("move_right")
	await _frames(40)
	assert_gt(body.position.x, 150.0)
	assert_lte(body.position.x, 162.1, "Swept hull must not cross a thin collider.")


func test_corner_blocks_both_axes() -> void:
	_wall(Vector2(200.0, 0.0), Vector2(12.0, 2000.0))
	_wall(Vector2(0.0, 200.0), Vector2(2000.0, 12.0))
	var body: SubmarineController = _submarine()
	await _frames(2)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _frames(110)
	assert_lte(body.position.x, 162.1)
	assert_lte(body.position.y, 178.1)
	assert_lt(body.velocity.length(), 0.1)


func test_fixed_physics_movement_matches_across_render_frame_caps() -> void:
	var distances: Array[float] = []
	for cap: int in [30, 60, 120]:
		Engine.max_fps = cap
		var body: SubmarineController = _submarine()
		await _frames(2)
		var start: Vector2 = body.position
		Input.action_press("move_right")
		await _frames(60)
		distances.append(body.position.x - start.x)
		Input.action_release("move_right")
		body.queue_free()
		await _frames(2)
	for distance: float in distances:
		assert_gt(distance, 170.0)
		assert_almost_eq(distance, distances[0], 5.0, "At most a physics-tick displacement difference.")


func test_authored_cave_spawn_and_boundary_are_collision_safe() -> void:
	var prototype: MovementPrototype = PROTOTYPE.instantiate() as MovementPrototype
	prototype.settings_path = _path
	add_child_autofree(prototype)
	await _frames(2)
	var body: SubmarineController = prototype.submarine
	var shape: CollisionShape2D = body.get_node("CollisionShape2D") as CollisionShape2D
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = 1
	assert_true(body.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Spawn does not overlap cave geometry.")
	Input.action_press("move_left")
	await _frames(100)
	assert_gte(body.position.x, 141.9, "Closed left wall remains solid.")
	assert_lt(body.position.x, 155.0)


func test_camera_smoothly_follows_in_the_interior() -> void:
	var prototype: MovementPrototype = PROTOTYPE.instantiate() as MovementPrototype
	prototype.settings_path = _path
	add_child_autofree(prototype)
	await _frames(2)
	var body: SubmarineController = prototype.submarine
	body.position = Vector2(1450.0, 400.0)
	body.reset_physics_interpolation()
	var camera: Camera2D = body.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _frames(2)
	var start: float = camera.get_screen_center_position().x
	Input.action_press("move_right")
	await _frames(20)
	assert_true(camera.position_smoothing_enabled)
	assert_gt(camera.get_screen_center_position().x, start)
	assert_lt(camera.get_screen_center_position().x, body.position.x, "Camera follows with bounded lag.")


func test_saved_bindings_load_and_embedded_settings_stop_the_motor() -> void:
	var settings: SettingsStore = SettingsStore.new()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_T
	assert_eq(settings.remap(&"move_right", key), OK)
	var pause_key: InputEventKey = InputEventKey.new()
	pause_key.physical_keycode = KEY_O
	assert_eq(settings.remap(&"pause", pause_key), OK)
	settings.set_deadzone(0.4)
	assert_eq(settings.save_settings(_path), OK)
	var prototype: MovementPrototype = PROTOTYPE.instantiate() as MovementPrototype
	prototype.settings_path = _path
	add_child_autofree(prototype)
	await _frames(2)
	assert_true(InputMap.action_has_event("move_right", key))
	assert_almost_eq(InputMap.action_get_deadzone("move_right"), 0.4, 0.001)
	prototype.submarine.velocity = Vector2(200.0, 0.0)
	var escape: InputEventKey = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	var released: InputEventKey = escape.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame
	var position: Vector2 = prototype.submarine.position
	await _frames(5)
	assert_false(prototype.submarine.is_physics_processing())
	assert_eq(prototype.submarine.position, position)
	assert_eq(prototype.submarine.velocity, Vector2.ZERO)
	var menu: InputTestMenu = prototype.settings_layer.get_node("InputTestMenu") as InputTestMenu
	assert_true(menu.embedded)
	(menu.get_node("%Quit") as Button).pressed.emit()
	await _frames(2)
	assert_true(prototype.submarine.is_physics_processing())
	assert_true(InputMap.action_has_event("move_right", key))
