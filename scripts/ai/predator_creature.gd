class_name PredatorCreature
extends AcousticCreature
## Reuses the complete BTA-030 motion/receiver adapter; no player-blocking collider.

signal threat_changed
signal contact_damage_applied(amount: float)
var threat: PredatorState = PredatorState.new()
var _player: WeakRef
var _hit_feedback: float = 0.0


func _ready() -> void:
	brain = threat
	super._ready()


func setup_player(player: SubmarineController) -> Error:
	if player == null or not player.is_inside_tree() or not _rules is PredatorProfile \
		or player.sonar.source_id != (_rules as PredatorProfile).trigger_source_id:
		return ERR_INVALID_PARAMETER
	_player = weakref(player)
	return OK


func _live_player() -> SubmarineController:
	var player: SubmarineController = _player.get_ref() as SubmarineController if _player != null else null
	return player if is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() else null


func _before_step(_delta: float) -> void:
	var player: SubmarineController = _live_player()
	threat.set_target(_region.to_local(player.global_position) if player != null else Vector2.ZERO, player != null)


func _after_step(delta: float) -> void:
	_hit_feedback = maxf(0.0, _hit_feedback - delta)
	var player: SubmarineController = _live_player()
	if player == null:
		return
	var at: Vector2 = _region.to_local(player.global_position)
	var profile: PredatorProfile = _rules as PredatorProfile
	if position.distance_to(at) <= profile.contact_radius:
		var cost: float = threat.contact_cost(position.distance_to(at), navigation.segment_clear(position, at))
		if cost > 0.0:
			var applied: float = player.hull_system.apply_damage(cost, StringName(String(creature_id) + "/contact"))
			if applied > 0.0:
				_hit_feedback = 1.5
				contact_damage_applied.emit(applied)


func reset_session() -> void:
	_hit_feedback = 0.0
	super.reset_session()


func _refresh() -> void:
	if not is_node_ready():
		return
	var phase_name: String = PredatorState.Phase.keys()[threat.phase]
	($StateCaption as Label).text = "PREDATOR / " + ("PAUSED" if _suspended else phase_name)
	queue_redraw()
	threat_changed.emit()


func hud_snapshot() -> Dictionary:
	if _destroyed: return {"visible":false,"title":"","hint":""}
	var player: SubmarineController = _live_player()
	var near: bool = player != null and _rules != null and _rules.navigation_bounds.grow(120).has_point(_region.to_local(player.global_position))
	var title: String = "PREDATOR / QUIET"
	var hint: String = "PING ALERTS · RETREAT ↓"
	if near and not _rules.center_bounds().has_point(_region.to_local(player.global_position)):
		title = "SAFE / MAIN PASSAGE"
		hint = "OPTIONAL ENCOUNTER ↑"
	var state: Dictionary = threat.snapshot()
	match threat.phase:
		PredatorState.Phase.ALERT:
			title = "! PREDATOR / WARNING %.1fs" % state.warning_remaining
			hint = (_rules as PredatorProfile).retreat_hint
		PredatorState.Phase.PURSUE:
			title = "! PREDATOR / PURSUIT %.1fs" % state.pursuit_remaining
			hint = (_rules as PredatorProfile).retreat_hint
		PredatorState.Phase.DISENGAGE:
			title = "SAFE / DISENGAGING"
			hint = "RETREAT ↓ TO MAIN PASSAGE"
	if _hit_feedback > 0.0:
		if threat.phase == PredatorState.Phase.DISENGAGE:
			title = "SAFE / DISENGAGING"
			hint = "RECENT HULL HIT · STAY ON PASSAGE"
		else:
			title = "! PREDATOR / HULL HIT"
	if _suspended:
		title += " / PAUSED"
	return {"visible": near, "title": title, "hint": hint}


func _draw() -> void:
	super._draw()
	var ink: Color = Color("f0b47d")
	draw_polyline(PackedVector2Array([Vector2(-11, -10), Vector2(-4, -21), Vector2(3, -10)]), ink, 3.0, true)
	if threat.phase == PredatorState.Phase.ALERT or threat.phase == PredatorState.Phase.PURSUE:
		draw_arc(Vector2.ZERO, 29, 0, TAU, 40, ink, 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-3, -31), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTypography.base(&"hud"), ink)
