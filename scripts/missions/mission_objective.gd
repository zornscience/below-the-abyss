class_name MissionObjective
extends Resource

enum Kind { DISCOVERY, SCAN, ROUTE_RETURN }
@export var stable_id: StringName = &""
@export var kind: Kind = Kind.DISCOVERY
@export var target_id: StringName = &""
@export var description: String = ""


func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and kind in [Kind.DISCOVERY, Kind.SCAN, Kind.ROUTE_RETURN] \
		and PointOfInterest.valid_id(target_id) and not description.strip_edges().is_empty() and description.length() <= 160
