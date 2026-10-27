class_name AcousticCreature
extends CharacterBody2D
## Harmless terrain-only body. Motion uses swept collisions, never positional warps.

const STEP: float = 1.0 / 120.0
@export var creature_id: StringName = &"shelf-observer"
@export var configuration: CreatureProfile = CreatureProfile.new()
var brain: CreatureState = CreatureState.new()
var navigation: CreatureNavigation = CreatureNavigation.new()
var _rules: CreatureProfile
var _region: Node2D
var _spawn: Vector2
var _suspended: bool = true
var _destroyed: bool = false
var damageable: bool = false
var _remainder: float = 0.0
var _nav_ready: bool = false
var _blocked: bool = false
var _path: PackedVector2Array = PackedVector2Array()
var _goal: Vector2 = Vector2(INF, INF)
var _replan: float = 0.0
@onready var receiver: AcousticReceiver = $AcousticReceiver


func _ready() -> void:
	_region = get_parent() as Node2D
	_spawn = position
	if configuration == null or not configuration.is_valid() or _region == null \
		or not configuration.center_bounds().has_point(position) or not AcousticEvent.valid_token(creature_id):
		push_error("Invalid acoustic creature configuration/spawn.")
		set_physics_process(false)
		return
	_rules = configuration.duplicate(true) as CreatureProfile
	brain.configure(_rules)
	receiver.receiver_id = StringName("creature/" + String(creature_id))
	receiver.profile = _rules.hearing.duplicate(true) as AcousticReceiverProfile
	receiver.enabled = false
	receiver.event_received.connect(_received)
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _rules.body_radius
	($CollisionShape2D as CollisionShape2D).shape = shape
	_refresh()


func bind_bus(bus: AcousticBus) -> Error:
	return receiver.bind_bus(bus)


func set_suspended(value: bool) -> void:
	_suspended = value
	receiver.enabled = not value and not _destroyed
	_refresh()


func _received(event: AcousticEvent, strength: float, distance: float) -> void:
	if not _suspended:
		brain.offer(event, strength, distance, _region.to_local(event.origin))


func _physics_process(delta: float) -> void:
	advance_simulation(delta)


func advance_simulation(delta: float) -> Error:
	if not is_finite(delta) or delta < 0.0 or delta > 1.0:
		return ERR_INVALID_PARAMETER
	if _suspended or _destroyed or _rules == null:
		return OK
	if not _nav_ready:
		var result: Error = navigation.build(_rules, _region)
		if result != OK:
			return result
		_nav_ready = true
	_remainder += delta
	while _remainder + 0.000000001 >= STEP:
		_remainder = maxf(0.0, _remainder - STEP)
		_before_step(STEP)
		brain.advance(STEP, position, _blocked)
		var goal: Vector2 = brain.destination()
		_replan = maxf(0.0, _replan - STEP)
		if not goal.is_equal_approx(_goal) or (_path.is_empty() and _replan <= 0.0):
			_goal = goal
			_path = navigation.route(position, goal)
			_replan = 0.5
		while not _path.is_empty() and position.distance_to(_path[0]) <= 0.1:
			_path.remove_at(0)
		_blocked = _path.is_empty() and position.distance_to(goal) > _rules.arrival_radius
		velocity = Vector2.ZERO
		if not _path.is_empty():
			var next: Vector2 = position.move_toward(_path[0], brain.speed() * STEP)
			var motion: Vector2 = _region.to_global(next) - global_position
			var previous: Vector2 = global_position
			move_and_collide(motion)
			velocity = (global_position - previous) / STEP
			_blocked = motion.length() > 0.01 and global_position.distance_to(previous) < 0.001
		_after_step(STEP)
	_refresh()
	return OK


func _before_step(_delta: float) -> void:
	pass


func _after_step(_delta: float) -> void:
	pass


func reset_session() -> void:
	set_destroyed(false)
	# Explicit test-route reset only; ordinary navigation never assigns position.
	position = _spawn
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	brain.reset_session()
	_remainder = 0.0
	_blocked = false
	_path.clear()
	_goal = Vector2(INF, INF)
	_replan = 0.0
	_nav_ready = false
	_refresh()


func _refresh() -> void:
	var caption: Label = $StateCaption
	var state_name: String = CreatureState.State.keys()[brain.state]
	caption.text = "HARMLESS / " + ("PAUSED" if _suspended else state_name)
	queue_redraw()


func _draw() -> void:
	var ink: Color = Color("92c9d8")
	draw_colored_polygon(PackedVector2Array([Vector2(-17, 0), Vector2(-8, -11), Vector2(14, -7), Vector2(19, 0), Vector2(14, 7), Vector2(-8, 11)]), ink)
	draw_circle(Vector2(10, -2), 2.0, Color("102938"))
	draw_line(Vector2(-14, 0), Vector2(-23, -8), ink, 3.0, true)
	draw_line(Vector2(-14, 0), Vector2(-23, 8), ink, 3.0, true)
	if brain.state == CreatureState.State.INVESTIGATE:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 32, Color("f4dc94"), 2.0, true)


func set_destroyed(value: bool) -> void:
	_destroyed = value
	for child: Node in get_children():
		if child is ScientificScanTarget: (child as ScientificScanTarget).scan_enabled = not value
	visible = not value
	collision_layer = 8 if damageable and not value else 0
	if is_instance_valid(receiver):
		receiver.enabled = not value and not _suspended
	velocity = Vector2.ZERO
