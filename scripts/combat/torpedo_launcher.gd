class_name TorpedoLauncher
extends Node
signal fired(event_id: StringName)
signal ammunition_changed(current: int, capacity: int)
const CAPACITY: int = 10
var ammunition: int = CAPACITY
var revised: bool = false
signal detonated(event_id: StringName, origin: Vector2)
@export var configuration: BlastProfile = preload("res://resources/balance/torpedo_profile.tres")
var _scene: ShelfPrototype
var _player: SubmarineController
var _world_effects: Node2D
var _settings: SettingsStore
var _excavation: ExcavationSystem
var _audio_request: Callable
var _rules: BlastProfile
var _projectiles: Array[TorpedoProjectile] = []
var _effects: Array[BlastEffect] = []
var _trails: Array[TorpedoTrail] = []
var _receivers: Array[BlastReceiver] = []
var _cooldown: float = 0.0
var _epoch: String
var _sequence: int = 0
var _clock: float = 0.0
var _armed: bool = false
var _emitter: AcousticEmitter
var aim: Vector2 = Vector2.RIGHT
func setup(scene: ShelfPrototype) -> Error:
	if configuration == null or not configuration.is_valid():
		return ERR_INVALID_PARAMETER
	_scene = scene
	var initialized: Error = setup_ports(scene.submarine,scene.get_node("WorldRoot/WorldEffects") as Node2D,scene.get_node("AcousticBus") as AcousticBus,scene.settings,scene.audio.request,scene.excavation,scene.revised_expedition)
	if initialized!=OK: return initialized
	for creature: AcousticCreature in [scene.creature, scene.predator]+scene.extension.wildlife:
		var receiver: BlastReceiver = BlastReceiver.new()
		creature.add_child(receiver)
		receiver.setup(creature)
		_receivers.append(receiver)
	return OK

func setup_ports(player: SubmarineController,effects: Node2D,bus: AcousticBus,preferences: SettingsStore,audio_request: Callable = Callable(),excavation: ExcavationSystem = null,modern: bool = true) -> Error:
	if player==null or effects==null or bus==null or preferences==null or configuration==null or not configuration.is_valid(): return ERR_INVALID_PARAMETER
	_player = player
	_world_effects = effects
	_settings = preferences
	_audio_request = audio_request
	_excavation = excavation
	revised = modern
	_player.simulation_enabled_changed.connect(func(_enabled: bool) -> void: _armed = false)
	_rules = configuration.duplicate(true) as BlastProfile
	_emitter = AcousticEmitter.new()
	_emitter.source_id = &"neris-01/torpedo"
	_emitter.profile = AcousticEmissionProfile.new()
	_emitter.profile.event_type = &"explosion"
	_emitter.profile.classification = &"mechanical"
	_emitter.profile.range_units = 1800.0
	_world_effects.add_child(_emitter)
	if _emitter.bind_bus(bus) != OK: return ERR_INVALID_PARAMETER
	_epoch = Crypto.new().generate_random_bytes(8).hex_encode()
	return OK
func battery_cost() -> float:
	return _rules.battery_cost

func set_battery_cost(cost: float) -> Error:
	if not is_finite(cost) or cost <= 0: return ERR_INVALID_PARAMETER
	_rules.battery_cost = cost
	return OK

func request_fire() -> Error:
	if revised:
		aim = _player.facing_direction()
		if ammunition <= 0: return ERR_UNAVAILABLE
	if not aim.is_finite() or aim.length_squared() < 0.000001: return ERR_INVALID_PARAMETER
	if _player == null or not _player.is_physics_processing() or _cooldown > 0.000000001 or _projectiles.size() >= 8:
		return ERR_BUSY
	if not _player.resource_system.try_consume_battery(_rules.battery_cost):
		return ERR_UNAVAILABLE
	_sequence += 1
	var projectile: TorpedoProjectile = TorpedoProjectile.new()
	projectile.direction = aim.normalized()
	projectile.blast_radius = _rules.radius
	projectile.blast_damage = _rules.damage
	projectile.speed = _rules.speed
	projectile.remaining = _rules.lifetime
	if revised:
		projectile.speed = _rules.launch_speed
		projectile.maximum_speed = _rules.cruise_speed
		projectile.acceleration = _rules.propulsion_acceleration
		projectile.remaining = _rules.powered_lifetime
		ammunition -= 1
		ammunition_changed.emit(ammunition,CAPACITY)
	projectile.event_id = StringName("torpedo/" + _epoch + "/" + str(_sequence))
	projectile.ignore = [_player.get_rid()]
	_world_effects.add_child(projectile)
	projectile.global_position = _player.global_position + (aim*48.0 if revised else Vector2.ZERO)
	if revised:
		var trail: TorpedoTrail = TorpedoTrail.new()
		trail.reduced = _settings.snapshot().accessibility.reduced_particles or _settings.snapshot().accessibility.reduced_motion
		_world_effects.add_child(trail)
		projectile.trail = trail
		_trails.append(trail)
	projectile.impact.connect(_impact)
	_projectiles.append(projectile)
	_cooldown = _rules.cooldown
	fired.emit(projectile.event_id)
	return OK
func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_physics_processing():
		return
	_clock += delta
	var movement: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
	if not revised and movement.length_squared() > 0.01:
		aim = movement.normalized()
	_cooldown = maxf(0.0, _cooldown-delta)
	if not Input.is_action_pressed("fire_torpedo"): _armed = true
	if _armed and Input.is_action_just_pressed("fire_torpedo") and Input.is_action_pressed("fire_torpedo"):
		request_fire()
	for projectile: TorpedoProjectile in _projectiles.duplicate():
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile.advance(delta)
	_projectiles = _projectiles.filter(func(p: TorpedoProjectile) -> bool: return is_instance_valid(p) and not p.is_queued_for_deletion())
	for trail: TorpedoTrail in _trails.duplicate():
		if is_instance_valid(trail) and not trail.active: trail.sample(Vector2.ZERO,delta)
	_trails = _trails.filter(func(t: TorpedoTrail) -> bool: return is_instance_valid(t) and not t.is_queued_for_deletion())
	for effect: BlastEffect in _effects.duplicate():
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			effect.advance(delta)
	_effects = _effects.filter(func(e: BlastEffect) -> bool: return is_instance_valid(e) and not e.is_queued_for_deletion())
func _impact(projectile: TorpedoProjectile, at: Vector2) -> void:
	if projectile.has_meta("resolved"): return
	projectile.set_meta("resolved",true)
	# Snapshot receivers in authored-ID order; each receiver suppresses repeated blast IDs.
	_receivers.sort_custom(func(a: BlastReceiver,b: BlastReceiver) -> bool: return String(a.stable_id)<String(b.stable_id))
	for receiver: BlastReceiver in _receivers:
		if is_instance_valid(receiver):
			receiver.apply_blast(projectile.event_id, at, projectile.blast_radius, projectile.blast_damage)
	if _excavation != null:
		_excavation.excavate(at, projectile.blast_radius)
	var effect: BlastEffect = BlastEffect.new()
	effect.radius = projectile.blast_radius
	var comfort: Dictionary = _settings.snapshot().accessibility
	effect.reduced_effects = comfort.reduced_flashing or comfort.reduced_particles or comfort.reduced_motion
	effect.refractive = revised
	_world_effects.add_child(effect)
	effect.global_position = at
	_effects.append(effect)
	_emitter.global_position = at
	_emitter.emit_event(StringName(String(projectile.event_id)+"/blast"), _clock)
	if _audio_request.is_valid(): _audio_request.call(&"underwater_blast")
	detonated.emit(projectile.event_id, at)
func reset_session() -> void:
	for trail: TorpedoTrail in _trails:
		if is_instance_valid(trail): trail.queue_free()
	_trails.clear()
	for projectile: TorpedoProjectile in _projectiles:
		if is_instance_valid(projectile): projectile.queue_free()
	for effect: BlastEffect in _effects:
		if is_instance_valid(effect): effect.queue_free()
	_projectiles.clear()
	_effects.clear()
	_cooldown = 0.0
	for receiver: BlastReceiver in _receivers:
		receiver.reset_session()

func refill() -> void:
	ammunition = CAPACITY
	ammunition_changed.emit(ammunition,CAPACITY)
func restore_ammunition(value: int) -> void:
	ammunition = clampi(value,0,CAPACITY)
	ammunition_changed.emit(ammunition,CAPACITY)

func configure_capabilities(propulsion: float,blast_radius: float) -> Error:
	var profile: BlastProfile = configuration.duplicate(true) as BlastProfile
	profile.battery_cost = battery_cost() # Capability reapplication must preserve the selected regional cost.
	profile.propulsion_acceleration = propulsion
	profile.radius = blast_radius
	if not profile.is_valid(): return ERR_INVALID_PARAMETER
	_rules = profile
	return OK
