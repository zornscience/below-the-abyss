class_name CreatureProfile
extends Resource
## All positions/bounds are relative to the creature's region parent.

@export var patrol_speed: float = 55.0
@export var investigate_speed: float = 85.0
@export var return_speed: float = 65.0
@export var investigation_seconds: float = 6.0
@export var recovery_seconds: float = 2.0
@export var unreachable_seconds: float = 1.5
@export var sound_memory_seconds: float = 2.0
@export var arrival_radius: float = 12.0
@export var body_radius: float = 16.0
@export var grid_spacing: float = 40.0
@export var navigation_bounds: Rect2 = Rect2(1380, 210, 620, 250)
@export var patrol_points: PackedVector2Array = PackedVector2Array([Vector2(1510, 420), Vector2(1510, 250), Vector2(1890, 250), Vector2(1890, 420)])
@export var hearing: AcousticReceiverProfile = AcousticReceiverProfile.new()
@export var event_priorities: Dictionary[StringName, int] = {&"active_sonar": 20, &"ambient": 10, &"explosion": 30}


func _init() -> void:
	hearing.accepted_event_types = [&"active_sonar", &"ambient", &"explosion"]
	hearing.maximum_range_units = 650.0
	hearing.minimum_strength = 0.2


func center_bounds() -> Rect2:
	return navigation_bounds.grow(-body_radius)


func is_valid() -> bool:
	for value: float in [patrol_speed, investigate_speed, return_speed, investigation_seconds,
		recovery_seconds, unreachable_seconds, sound_memory_seconds, arrival_radius, body_radius, grid_spacing]:
		if not is_finite(value) or value <= 0.0 or value > 1000.0:
			return false
	if hearing == null or not hearing.is_valid() or event_priorities.is_empty() or event_priorities.size() > 16 \
		or not navigation_bounds.position.is_finite() or not navigation_bounds.size.is_finite() \
		or navigation_bounds.size.x <= body_radius * 2.0 or navigation_bounds.size.y <= body_radius * 2.0 \
		or navigation_bounds.size.x * navigation_bounds.size.y / (grid_spacing * grid_spacing) > 1024.0 \
		or patrol_points.is_empty() or patrol_points.size() > 32:
		return false
	var columns: float = ceilf(center_bounds().size.x / grid_spacing)
	var rows: float = ceilf(center_bounds().size.y / grid_spacing)
	if columns > 1024.0 or rows > 1024.0 or columns * rows > 1024.0:
		return false
	for point: Vector2 in patrol_points:
		if not point.is_finite() or not center_bounds().has_point(point):
			return false
	for type: StringName in event_priorities:
		if not AcousticEvent.valid_token(type) or event_priorities[type] < 0 or event_priorities[type] > 1000:
			return false
	return true
