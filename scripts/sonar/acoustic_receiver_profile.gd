class_name AcousticReceiverProfile
extends Resource
## Empty allow lists mean any; source exclusions always win.

@export var accepted_event_types: Array[StringName] = []
@export var accepted_classifications: Array[StringName] = []
@export var excluded_source_ids: Array[StringName] = []
@export var maximum_range_units: float = 1000.0
@export var minimum_strength: float = 0.0


func is_valid() -> bool:
	if not is_finite(maximum_range_units) or maximum_range_units < 0.0 \
		or not is_finite(minimum_strength) or minimum_strength < 0.0:
		return false
	for list: Array[StringName] in [accepted_event_types, accepted_classifications, excluded_source_ids]:
		for token: StringName in list:
			if not AcousticEvent.valid_token(token):
				return false
	return true


func accepts(event: AcousticEvent) -> bool:
	return not event.source_id in excluded_source_ids \
		and (accepted_event_types.is_empty() or event.event_type in accepted_event_types) \
		and (accepted_classifications.is_empty() or event.classification in accepted_classifications)
