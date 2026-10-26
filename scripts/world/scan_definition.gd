class_name ScanDefinition
extends Resource
## Authored scientific placeholder; identity is independent of its sonar POI.

@export var stable_id: StringName
@export var required_poi_id: StringName
@export_enum("geological", "biological", "artificial") var classification: String = "geological"
@export var title: String
@export_multiline var description: String
@export var position: Vector2
@export var radius: float = 240.0
@export var duration: float = 3.0


func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and PointOfInterest.valid_id(required_poi_id) \
		and classification in ["geological", "biological", "artificial"] \
		and not title.strip_edges().is_empty() and title.length() <= 64 \
		and not description.strip_edges().is_empty() and description.length() <= 2048 \
		and position.is_finite() and is_finite(radius) and radius > 0.0 and radius <= 1000.0 \
		and is_finite(duration) and duration >= 0.25 and duration <= 60.0
