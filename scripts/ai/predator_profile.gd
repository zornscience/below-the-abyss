class_name PredatorProfile
extends CreatureProfile
## One optional encounter, not a creature species/progression pipeline.

@export var retreat_hint: String = "RETREAT ↓ PAST 115 m"
@export var warning_seconds: float = 2.5
@export var pursuit_seconds: float = 6.0
@export var pursuit_speed: float = 90.0
@export var pursuit_distance: float = 180.0
@export var target_distance: float = 220.0
@export var target_replan_seconds: float = 0.25
@export var contact_radius: float = 40.0
@export var contact_damage: float = 5.0
@export var damage_cooldown: float = 3.0
@export var trigger_source_id: StringName = &"neris-01/sonar"


func _init() -> void:
	patrol_speed = 35.0
	investigate_speed = 40.0
	return_speed = 65.0
	investigation_seconds = 10.5
	recovery_seconds = 4.0
	navigation_bounds = Rect2(3000, 300, 330, 145)
	patrol_points = PackedVector2Array([Vector2(3200, 350), Vector2(3280, 360), Vector2(3240, 400)])
	grid_spacing = 32.0
	hearing.accepted_event_types = [&"active_sonar", &"explosion"]
	hearing.maximum_range_units = 500.0
	hearing.minimum_strength = 0.2
	event_priorities = {&"active_sonar": 20, &"explosion": 30}


func is_valid() -> bool:
	if not super.is_valid() or not AcousticEvent.valid_token(trigger_source_id) or retreat_hint.is_empty() or retreat_hint.length() > 48:
		return false
	for value: float in [warning_seconds, pursuit_seconds, pursuit_speed, pursuit_distance,
		target_distance, target_replan_seconds, contact_radius, damage_cooldown]:
		if not is_finite(value) or value <= 0.0 or value > 1000.0:
			return false
	return warning_seconds >= 1.0 and investigation_seconds >= warning_seconds + pursuit_seconds \
		and damage_cooldown >= 1.0 and target_replan_seconds >= 1.0 / 120.0 \
		and is_finite(contact_damage) and contact_damage >= 0.0 and contact_damage <= 10.0
