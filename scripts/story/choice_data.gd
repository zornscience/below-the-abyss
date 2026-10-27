class_name ChoiceData
extends Resource
## Stable authored decision, mutually exclusive within an encounter.
@export var stable_id: StringName
@export var encounter_id: StringName
@export_range(-25, 25) var resonance_delta: int = 0
@export var exceptional_weight: bool = false
@export var flags: Array[StringName] = []
@export var research_record_id: StringName
@export var action_text: String
@export_multiline var response_text: String
func is_valid() -> bool:
	if not PointOfInterest.valid_id(stable_id) or not PointOfInterest.valid_id(encounter_id):
		return false
	if absi(resonance_delta) > (25 if exceptional_weight else 15) or flags.size() > 16:
		return false
	if research_record_id != &"" and not PointOfInterest.valid_id(research_record_id):
		return false
	if action_text.is_empty() or action_text.length() > 100 or response_text.is_empty() or response_text.length() > 2048:
		return false
	var seen: Array[StringName] = []
	for flag: StringName in flags:
		if not PointOfInterest.valid_id(flag) or flag in seen:
			return false
		seen.append(flag)
	return true
