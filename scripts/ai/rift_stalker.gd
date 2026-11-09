class_name RiftStalker
extends AcousticCreature
signal phase_changed(phase: int)
signal contact_damage_applied(amount: float)
var hunt: RiftStalkerState = RiftStalkerState.new()
var player: SubmarineController
var _phase_seen: int = -1
var _sense_check: float = 0.0
var _seen: bool = false
func _ready() -> void:
	brain = hunt
	damageable = false
	super._ready()
func _before_step(delta: float) -> void:
	var valid: bool = is_instance_valid(player)
	var at: Vector2 = _region.to_local(player.global_position) if valid else Vector2.ZERO
	var listening: bool = (hunt.phase==RiftStalkerState.Phase.INVESTIGATE or hunt.phase==RiftStalkerState.Phase.WARNING or hunt.phase==RiftStalkerState.Phase.PURSUE)
	_sense_check = maxf(0,_sense_check-delta)
	if listening and _sense_check<=0:
		_seen = valid and hunt.profile.center_bounds().has_point(at) and position.distance_to(at)<=hunt.profile.target_distance and navigation.segment_clear(position,at)
		_sense_check = hunt.profile.target_replan_seconds
	elif not listening:
		_seen = false
		_sense_check = 0
	hunt.sense(at,valid,_seen)
func _after_step(_delta: float) -> void:
	if not is_instance_valid(player) or hunt.phase!=RiftStalkerState.Phase.PURSUE: return
	var distance: float = global_position.distance_to(player.global_position)
	if not hunt.contact_ready(distance): return
	var cost: float = hunt.contact_cost(distance,distance<=hunt.profile.contact_radius and navigation.segment_clear(position,_region.to_local(player.global_position)))
	if cost>0:
		var applied: float = player.hull_system.apply_damage(cost,&"twilight-rift-stalker/contact")
		if applied>0: contact_damage_applied.emit(applied)
func set_destroyed(value: bool) -> void:
	if not value: super.set_destroyed(false)
func _refresh() -> void:
	if not is_node_ready(): return
	if _phase_seen!=hunt.phase:
		_phase_seen = hunt.phase
		($StateCaption as Label).text = "! RIFT STALKER / "+RiftStalkerState.Phase.keys()[hunt.phase]
		phase_changed.emit(hunt.phase)
		queue_redraw()
	($StateCaption as Label).visible = not _suspended and hunt.phase!=RiftStalkerState.Phase.QUIET and hunt.phase!=RiftStalkerState.Phase.RETURN
func _draw() -> void:
	super._draw()
	if hunt.phase==RiftStalkerState.Phase.WARNING or hunt.phase==RiftStalkerState.Phase.PURSUE or hunt.phase==RiftStalkerState.Phase.STUN or hunt.phase==RiftStalkerState.Phase.FLEE:
		draw_arc(Vector2.ZERO,32,0,TAU,32,Color("f4dc94"),3)
		draw_string(ThemeDB.fallback_font,Vector2(-4,-34),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
