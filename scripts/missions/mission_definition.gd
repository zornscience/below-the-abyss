class_name MissionDefinition
extends Resource

@export var stable_id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var optional: bool = false
@export var acknowledgement_id: StringName = &""
@export var acknowledgement: String = ""
@export var objectives: Array[MissionObjective] = []


func is_valid() -> bool:
	if not PointOfInterest.valid_id(stable_id) or not PointOfInterest.valid_id(acknowledgement_id) \
		or title.strip_edges().is_empty() or title.length() > 64 or description.strip_edges().is_empty() or description.length() > 512 \
		or acknowledgement.strip_edges().is_empty() or acknowledgement.length() > 256 or objectives.is_empty() or objectives.size() > 8:
		return false
	var seen: Array[StringName] = []
	for objective: MissionObjective in objectives:
		if objective == null or not objective.is_valid() or objective.stable_id in seen:
			return false
		seen.append(objective.stable_id)
	return true
