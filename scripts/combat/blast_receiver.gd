class_name BlastReceiver
extends Node
## Local NPC health. No loot or mission rewards. Recreated on expedition restart/load.
signal health_changed(current: float, maximum: float)
signal destroyed
@export var maximum_health: float = 40.0
var health: float = 40.0
var enabled: bool = true
var stable_id: StringName
var _seen: Dictionary[StringName, bool] = {}
var _creature: AcousticCreature

func setup(creature: AcousticCreature) -> void:
	_creature = creature
	_creature.damageable = true
	stable_id = creature.creature_id
	reset_session()

func apply_blast(event_id: StringName, origin: Vector2, radius: float, damage: float) -> float:
	if not enabled or not is_instance_valid(_creature) or health <= 0.0 or not AcousticEvent.valid_token(event_id) \
		or not origin.is_finite() or not is_finite(radius) or radius <= 0.0 or not is_finite(damage) or damage < 0.0 \
		or _seen.has(event_id) or _seen.size() >= 2048:
		return 0.0
	var distance: float = _creature.global_position.distance_to(origin)
	if distance > radius:
		return 0.0
	_seen[event_id] = true
	var applied: float = minf(health, damage * (1.0 - 0.75 * distance / radius))
	health -= applied
	health_changed.emit(health, maximum_health)
	if health <= 0.0:
		_creature.set_destroyed(true)
		destroyed.emit()
	return applied

func reset_session() -> void:
	health = maximum_health
	_seen.clear()
	if is_instance_valid(_creature):
		_creature.set_destroyed(false)
	health_changed.emit(health, maximum_health)
