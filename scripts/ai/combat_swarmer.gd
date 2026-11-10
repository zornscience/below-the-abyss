class_name CombatSwarmer
extends AcousticCreature
signal phase_changed(phase: int)
signal contact_damage_applied(amount: float)
var model: SwarmerState = SwarmerState.new()
var player: SubmarineController
var _phase_seen: int = -1
func _ready() -> void:
	brain = model
	super._ready()
func _clear(at: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position,at,1)).is_empty()
func _before_step(_delta: float) -> void:
	model.sense(_region.to_local(player.global_position),_clear(player.global_position))
func _after_step(_delta: float) -> void:
	var amount: float = model.bite(global_position.distance_to(player.global_position),_clear(player.global_position))
	if amount>0:
		var applied: float = player.hull_system.apply_damage(amount,&"combat-swarmer/contact")
		if applied>0: contact_damage_applied.emit(applied)
func _refresh() -> void:
	if not is_node_ready(): return
	if _phase_seen!=model.phase:
		_phase_seen = model.phase
		phase_changed.emit(model.phase)
	var caption: Label = $StateCaption
	caption.text = "! SWARMER / "+SwarmerState.Phase.keys()[model.phase]
	caption.visible = not _suspended and not _destroyed and model.phase not in [SwarmerState.Phase.QUIET,SwarmerState.Phase.INVESTIGATE]
	queue_redraw()
func _draw() -> void:
	super._draw()
	if model.phase in [SwarmerState.Phase.TELEGRAPH,SwarmerState.Phase.DASH,SwarmerState.Phase.STUN]:
		draw_arc(Vector2.ZERO,28,0,TAU,32,Color("f4dc94"),3)
		if model.phase==SwarmerState.Phase.TELEGRAPH:
			draw_line(Vector2.ZERO,to_local(_region.to_global(model.goal)).limit_length(90),Color("f4dc94"),3)
