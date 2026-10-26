class_name AcousticEmissionProfile
extends Resource
## Authored signal values, not cooldowns, energy costs or sonar behavior.

@export var event_type: StringName = &"test_impulse"
@export var classification: StringName = &"mechanical"
@export var strength: float = 1.0
@export var range_units: float = 1000.0


func is_valid() -> bool:
	return AcousticEvent.valid_token(event_type) and AcousticEvent.valid_token(classification) \
		and is_finite(strength) and strength >= 0.0 \
		and is_finite(range_units) and range_units >= 0.0
