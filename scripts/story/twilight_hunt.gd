class_name TwilightHunt
extends Node
## One opted-in threat. Existing wildlife and the launcher's single blast emission are untouched.
## Radio ids this node may queue; RadioNotifications.enqueue drops ids it does not know.
const RADIO_IDS: Array[String] = ["twilight-stalker-warning"]
const PROFILE: RiftStalkerProfile = preload("res://resources/creatures/twilight_stalker.tres")
var scene: ShelfPrototype
var actors: Array[RiftStalker] = []
var passive: AcousticEmitter
var enabled: bool = false
var _clock: float = 0.0
var _next_contact: float = 0.0
var _epoch: int = 0
var _sequence: int = 0
var _warned: bool = false
var _hint_attempted: bool = false
func setup(game: ShelfPrototype) -> void:
	scene = game
	var base: AcousticCreature = preload("res://scenes/creatures/acoustic_creature.tscn").instantiate() as AcousticCreature
	base.set_script(preload("res://scripts/ai/rift_stalker.gd"))
	var actor: RiftStalker = base as RiftStalker
	actor.creature_id = &"twilight-rift-stalker"
	actor.configuration = PROFILE
	actor.position = PROFILE.patrol_points[0]
	scene.journey.layout.add_child(actor)
	actor.player = scene.submarine
	actors.append(actor)
	var result: Error = actor.bind_bus(scene.get_node("AcousticBus") as AcousticBus)
	if result!=OK: push_error("Rift Stalker receiver registration failed")
	var paint: TwilightFaunaPaint = TwilightFaunaPaint.new()
	actor.add_child(paint)
	paint.setup(actor,scene,0)
	paint.sprite.modulate = Color("a3b7a2")
	actor.phase_changed.connect(_phase)
	actor.contact_damage_applied.connect(func(_amount: float) -> void: scene.hud.show_threat_notice("! STALKER / HULL CONTACT"))
	passive = AcousticEmitter.new()
	passive.source_id = &"twilight-rift-stalker/life"
	passive.profile = PROFILE.passive_emission
	scene.journey.layout.add_child(passive)
	if passive.bind_bus(scene.get_node("AcousticBus") as AcousticBus)!=OK: push_error("Rift Stalker passive registration failed")
	scene.torpedoes.detonated.connect(_blast)
	scene.submarine.simulation_enabled_changed.connect(_simulation)
	scene.saves.checkpoint_restored.connect(reset_session)
	scene.settings.settings_changed.connect(func() -> void: _hint_attempted = false)
	set_enabled(false)
static func nearest(points: PackedVector2Array,radii: PackedFloat32Array,origin: Vector2) -> int:
	var chosen: int = -1
	var best: float = INF
	if not origin.is_finite() or points.size()!=radii.size(): return -1
	for index: int in range(points.size()):
		var distance: float = points[index].distance_to(origin)
		if distance<=radii[index] and distance<best:
			best = distance
			chosen = index
	return chosen
func _blast(_event: StringName,origin: Vector2) -> void:
	if not enabled or not scene.submarine.is_physics_processing(): return
	var points: PackedVector2Array = PackedVector2Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for actor: RiftStalker in actors:
		points.append(actor.global_position)
		radii.append(actor.hunt.profile.scare_radius)
	var index: int = nearest(points,radii,origin)
	if index>=0:
		var actor: RiftStalker = actors[index]
		actor.hunt.scare(actor.get_parent().to_local(origin),actor.position)
func set_enabled(value: bool) -> void:
	var changed: bool = enabled!=value
	enabled = value
	if changed: reset_session()
	_simulation(scene.submarine.is_physics_processing())
func _simulation(value: bool) -> void:
	for actor: RiftStalker in actors:
		actor.set_suspended(not enabled or not value)
		actor.visible = enabled
		# Weapon-only layer; the vessel collides with terrain, not layer 8. No BlastReceiver.
		actor.collision_layer = 8 if enabled else 0
func reset_session() -> void:
	_epoch += 1
	_sequence = 0
	_clock = 0
	_next_contact = 0
	for actor: RiftStalker in actors: actor.reset_session()
	_simulation(scene.submarine.is_physics_processing())
func _phase(phase: int) -> void:
	if phase in [RiftStalkerState.Phase.WARNING,RiftStalkerState.Phase.PURSUE,RiftStalkerState.Phase.STUN,RiftStalkerState.Phase.FLEE]:
		scene.hud.show_threat_notice("! STALKER / "+RiftStalkerState.Phase.keys()[phase])
	if phase==RiftStalkerState.Phase.WARNING and not _warned:
		_warned = true
		scene.revision.ui.notifications.enqueue("twilight-stalker-warning","Wick: That living contact turned toward our sound. It is closing in. Quiet travel and distance give us a way out.","Wick")
func _physics_process(delta: float) -> void:
	if not enabled or not scene.submarine.is_physics_processing(): return
	_clock += delta
	if _clock>=_next_contact:
		_next_contact = _clock+PROFILE.contact_interval
		_sequence += 1
		passive.global_position = actors[0].global_position
		passive.emit_event(StringName("rift-stalker/life/%d/%d" % [_epoch,_sequence]),scene.submarine.passive._clock)
	if not _hint_attempted and scene.tutorial._current=="" and PROFILE.navigation_bounds.grow(PROFILE.hearing.maximum_range_units).has_point(scene.submarine.global_position):
		_hint_attempted = true
		scene.tutorial.show_hint("twilight-stalker")
