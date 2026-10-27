class_name MissionObjective
extends Resource

enum Kind { DISCOVERY, SCAN, ROUTE_RETURN, STORY_CHOICE, RETURN_AFTER_SCAN }
@export var stable_id: StringName = &""
@export var kind: Kind = Kind.DISCOVERY
@export var target_id: StringName = &""
@export var description: String = ""


func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and kind in Kind.values() \
		and PointOfInterest.valid_id(target_id) and not description.strip_edges().is_empty() and description.length() <= 160
