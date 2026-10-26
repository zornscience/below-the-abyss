class_name AmbientEmissionProfile
extends AcousticEmissionProfile

@export var first_delay: float = 2.0
@export var interval_seconds: float = 6.0
@export_range(1, 256) var maximum_events: int = 128


func _init() -> void:
	event_type = &"ambient"


func is_valid() -> bool:
	return super.is_valid() and event_type == &"ambient" \
		and is_finite(first_delay) and first_delay >= 0.0 and first_delay <= 60.0 \
		and is_finite(interval_seconds) and interval_seconds >= 0.25 and interval_seconds <= 60.0 \
		and maximum_events >= 1 and maximum_events <= 256
