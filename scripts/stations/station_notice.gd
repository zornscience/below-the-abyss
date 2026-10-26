class_name StationNotice
extends Resource
## Authored information only: no objective, reward, accepted/completed state.

@export var stable_id: StringName
@export var title: String
@export_multiline var description: String


func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and not title.strip_edges().is_empty() \
		and title.length() <= 64 and not description.strip_edges().is_empty() and description.length() <= 2048
