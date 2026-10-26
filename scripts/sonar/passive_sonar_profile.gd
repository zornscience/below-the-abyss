class_name PassiveSonarProfile
extends AcousticReceiverProfile

@export var contact_seconds: float = 8.0
@export_range(1, 8) var maximum_contacts: int = 3
@export var strength_reference: float = 1.0
@export_range(0.01, 1.0) var strength_quantum: float = 0.2
@export_range(1.0, 180.0) var bearing_quantum_degrees: float = 15.0
@export var distance_falloff: bool = true


func _init() -> void:
	accepted_event_types = [&"ambient"]
	maximum_range_units = 1400.0
	minimum_strength = 0.05


func is_valid() -> bool:
	return super.is_valid() and is_finite(contact_seconds) and contact_seconds > 0.0 \
		and contact_seconds <= 60.0 and maximum_contacts >= 1 and maximum_contacts <= 8 \
		and is_finite(strength_reference) and strength_reference > 0.0 \
		and is_finite(strength_quantum) and strength_quantum >= 0.01 and strength_quantum <= 1.0 \
		and is_finite(bearing_quantum_degrees) and bearing_quantum_degrees >= 1.0 and bearing_quantum_degrees <= 180.0


func approximate_strength(event: AcousticEvent, received: float, distance: float) -> float:
	var normalized: float = clampf(received / strength_reference, 0.0, 1.0)
	if distance_falloff and event.range_units > 0.0:
		normalized *= clampf(1.0 - distance / event.range_units, 0.0, 1.0)
	return clampf(roundf(normalized / strength_quantum) * strength_quantum, 0.0, 1.0)
