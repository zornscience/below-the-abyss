class_name PointOfInterest
extends Resource
## Authored metadata. Only discovered definitions may be presented to players.

@export var stable_id: StringName
@export var sonar_target_id: StringName
@export var display_name: String
@export var map_position: Vector2


static func valid_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty() or text.length() > 64:
		return false
	for character: String in text:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true


func is_valid() -> bool:
	return valid_id(stable_id) and valid_id(sonar_target_id) and not display_name.strip_edges().is_empty() \
		and display_name.length() <= 64 and map_position.is_finite()
