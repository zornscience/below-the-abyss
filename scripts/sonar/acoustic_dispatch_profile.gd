class_name AcousticDispatchProfile
extends Resource

enum Attenuation { NONE, LINEAR }
@export var attenuation: Attenuation = Attenuation.NONE
@export_range(1, 1000000) var maximum_event_history: int = 4096


func is_valid() -> bool:
	return attenuation in [Attenuation.NONE, Attenuation.LINEAR] and maximum_event_history > 0 \
		and maximum_event_history <= 1000000


func received_strength(event: AcousticEvent, distance: float) -> float:
	if attenuation == Attenuation.LINEAR and event.range_units > 0.0:
		return event.strength * clampf(1.0 - distance / event.range_units, 0.0, 1.0)
	return event.strength
